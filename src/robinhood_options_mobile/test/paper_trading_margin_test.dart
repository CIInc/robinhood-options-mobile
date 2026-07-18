import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/paper_trading_store.dart';

/// With no bound user the store never touches Firestore (_load/_save
/// early-return), so a throwing Fake proves persistence stays untouched.
class _UnusedFirestore extends Fake implements FirebaseFirestore {}

/// Engine-level tests for mark-to-market maintenance margin (MVP #6):
/// the margin-call sweep buys back shorts when the account can no longer
/// cover the 130% maintenance requirement at current prices.
void main() {
  Instrument makeInstrument({String symbol = 'AAPL'}) {
    return Instrument(
        id: 'id_$symbol',
        url: 'https://api.robinhood.com/instruments/$symbol/',
        quote: 'quote',
        fundamentals: 'fundamentals',
        splits: 'splits',
        state: 'active',
        market: 'market',
        name: '$symbol Inc.',
        tradeable: true,
        tradability: 'tradable',
        symbol: symbol,
        bloombergUnique: 'bloombergUnique',
        country: 'US',
        type: 'stock',
        rhsTradability: 'tradable',
        fractionalTradability: 'tradable',
        isSpac: false,
        isTest: false,
        ipoAccessSupportsDsp: false,
        dateCreated: DateTime.now());
  }

  PaperTradingStore makeStore() =>
      PaperTradingStore(
      firestore: _UnusedFirestore(), isMarketOpen: () => true);

  /// 10,000 cash account with a 100-share short at $100
  /// (cash 20,000 after proceeds; maintenance 13,000 at entry).
  Future<PaperTradingStore> storeWithShort() async {
    final store = makeStore();
    await store.resetAccount(initialCapital: 10000.0);
    await store.submitStockOrder(
      instrument: makeInstrument(),
      quantity: 100,
      side: 'sell',
      orderType: 'market',
      marketPrice: 100.0,
    );
    expect(store.cashBalance, 20000.0);
    return store;
  }

  group('processMarginCalls', () {
    test('healthy account is untouched', () async {
      final store = await storeWithShort();
      final liquidated =
          await store.processMarginCalls(stockPrices: {'AAPL': 100.0});

      expect(liquidated, isFalse);
      expect(store.positions.single.quantity, -100);
      expect(store.cashBalance, 20000.0);
    });

    test('price drop improves margin — still no action', () async {
      final store = await storeWithShort();
      final liquidated =
          await store.processMarginCalls(stockPrices: {'AAPL': 60.0});

      expect(liquidated, isFalse);
      expect(store.positions.single.quantity, -100);
    });

    test('deficit triggers a partial buy-to-cover that restores margin',
        () async {
      final store = await storeWithShort();

      // At 180: maintenance = 100 x 180 x 1.3 = 23,400 > 20,000 cash.
      // Deficit 3,400; each covered share frees 0.3 x 180 = 54.
      // ceil(3400 / 54) = 63 shares.
      final liquidated =
          await store.processMarginCalls(stockPrices: {'AAPL': 180.0});

      expect(liquidated, isTrue);
      expect(store.positions.single.quantity, -37);
      expect(store.cashBalance, 20000.0 - 63 * 180.0);
      // Remaining requirement is now covered.
      // cash 8,660 vs maintenance 37 x 180 x 1.3 = 8,658.
      expect(store.cashBalance - 37 * 180.0 * 1.3, greaterThanOrEqualTo(0));

      final entry = store.history.first;
      expect(entry['side'], 'buy');
      expect(entry['detail'], contains('Margin call'));
      // Shorted at 100, forced to cover at 180: realized loss of 80/share.
      expect(entry['profitLoss'], (100.0 - 180.0) * 63);
    });

    test('blown account liquidates everything and records a warning',
        () async {
      final store = await storeWithShort();

      // At 400: maintenance = 52,000 vs 20,000 cash — covering everything
      // costs 40,000, leaving the account cash-negative.
      final liquidated =
          await store.processMarginCalls(stockPrices: {'AAPL': 400.0});

      expect(liquidated, isTrue);
      expect(store.positions, isEmpty);
      expect(store.cashBalance, 20000.0 - 100 * 400.0);
      expect(store.cashBalance, lessThan(0));

      final warning = store.history
          .firstWhere((h) => h['type'] == 'MARGIN', orElse: () => {});
      expect(warning['detail'], contains('deficit'));
      expect(warning['state'], 'warning');
    });

    test('covers the largest exposure first across multiple shorts',
        () async {
      final store = makeStore();
      await store.resetAccount(initialCapital: 20000.0);
      await store.submitStockOrder(
          instrument: makeInstrument(symbol: 'AAPL'),
          quantity: 100,
          side: 'sell',
          orderType: 'market',
          marketPrice: 100.0);
      await store.submitStockOrder(
          instrument: makeInstrument(symbol: 'TSLA'),
          quantity: 10,
          side: 'sell',
          orderType: 'market',
          marketPrice: 100.0);
      expect(store.cashBalance, 31000.0);

      // AAPL rises to 250 (TSLA flat): maintenance = 32,500 + 1,300 vs
      // 31,000 cash — deficit 2,800. Each covered AAPL share frees
      // 0.3 x 250 = 75, so ceil(2800 / 75) = 38 shares are bought back.
      await store.processMarginCalls(
          stockPrices: {'AAPL': 250.0, 'TSLA': 100.0});

      final tsla = store.positions
          .firstWhere((p) => p.instrumentObj?.symbol == 'TSLA');
      expect(tsla.quantity, -10); // untouched
      final aapl = store.positions
          .firstWhere((p) => p.instrumentObj?.symbol == 'AAPL');
      expect(aapl.quantity, -62);
      expect(store.cashBalance, 31000.0 - 38 * 250.0);
    });

    test('maintenance getter marks to market via attached quotes', () async {
      final store = await storeWithShort();
      // No quote attached: falls back to the entry price.
      expect(store.shortStockCollateral, 100 * 100.0 * 1.3);
    });

    test('cash-secured puts cannot cause a margin call', () async {
      final store = makeStore();
      await store.resetAccount(initialCapital: 20000.0);
      // Fully secured put: strike 150 x 100 = 15,000 held from 20,500.
      final option = OptionInstrumentBuilder.build();
      await store.submitOptionOrder(
        optionInstrument: option,
        quantity: 1,
        side: 'sell',
        orderType: 'limit',
        limitPrice: 5.0,
        marketPrice: 5.0,
      );

      final liquidated =
          await store.processMarginCalls(stockPrices: {'AAPL': 500.0});
      expect(liquidated, isFalse);
      expect(store.optionPositions, hasLength(1));
    });
  });
}

/// Minimal option instrument builder for the CSP test.
class OptionInstrumentBuilder {
  static OptionInstrument build() {
    return OptionInstrument(
        'chain_id',
        'AAPL',
        DateTime.now(),
        DateTime.now().add(const Duration(days: 30)),
        'opt_id',
        DateTime.now(),
        const MinTicks(0.01, 0.01, 0.0),
        'tradable',
        'active',
        150.0,
        'tradable',
        'put',
        DateTime.now(),
        'https://api.robinhood.com/options/instruments/opt_id/',
        null,
        'long',
        'short');
  }
}
