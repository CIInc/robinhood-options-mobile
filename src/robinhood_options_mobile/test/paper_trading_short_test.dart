import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/paper_trading_store.dart';

/// With no bound user the store never touches Firestore (_load/_save
/// early-return), so a throwing Fake proves persistence stays untouched.
class _UnusedFirestore extends Fake implements FirebaseFirestore {}

/// Engine-level tests for short selling and option writing (MVP #3):
/// short stock with 150% collateral, cash-secured puts, covered calls,
/// buy-to-close, and expiration/assignment.
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

  OptionInstrument makeOption({
    String id = 'opt_id',
    String type = 'call',
    double strike = 150.0,
    String chainSymbol = 'AAPL',
    DateTime? expiration,
  }) {
    return OptionInstrument(
        'chain_id',
        chainSymbol,
        DateTime.now(),
        expiration ?? DateTime.now().add(const Duration(days: 30)),
        id,
        DateTime.now(),
        const MinTicks(0.01, 0.01, 0.0),
        'tradable',
        'active',
        strike,
        'tradable',
        type,
        DateTime.now(),
        'https://api.robinhood.com/options/instruments/$id/',
        null,
        'long',
        'short');
  }

  PaperTradingStore makeStore() =>
      PaperTradingStore(
      firestore: _UnusedFirestore(), isMarketOpen: () => true);

  group('short stock', () {
    test(
        'sell with no position opens a short (150% initial check, '
        '130% maintenance held)', () async {
      final store = makeStore();
      await store.submitStockOrder(
        instrument: makeInstrument(),
        quantity: 10,
        side: 'sell',
        orderType: 'market',
        marketPrice: 150.0,
      );

      expect(store.positions, hasLength(1));
      expect(store.positions.first.quantity, -10);
      expect(store.positions.first.averageBuyPrice, 150.0);
      expect(store.cashBalance, 100000.0 + 1500.0); // proceeds credited
      // Maintenance requirement is 130% of market value (entry fallback).
      expect(store.shortStockCollateral, 1500.0 * 1.3);
      expect(store.availableBuyingPower, 100000.0 + 1500.0 - 1950.0);
      expect(store.equity, 100000.0); // proceeds offset the liability
    });

    test('short open is rejected without collateral capacity', () async {
      final store = makeStore();
      await store.resetAccount(initialCapital: 1000.0);
      expect(
          () => store.submitStockOrder(
                instrument: makeInstrument(),
                quantity: 100,
                side: 'sell',
                orderType: 'market',
                marketPrice: 150.0, // needs 7,500 extra margin > 1,000
              ),
          throwsException);
      expect(store.positions, isEmpty);
    });

    test('extending a short re-averages the entry price', () async {
      final store = makeStore();
      final instrument = makeInstrument();
      await store.submitStockOrder(
          instrument: instrument,
          quantity: 10,
          side: 'sell',
          orderType: 'market',
          marketPrice: 150.0);
      await store.submitStockOrder(
          instrument: instrument,
          quantity: 10,
          side: 'sell',
          orderType: 'market',
          marketPrice: 160.0);

      expect(store.positions.first.quantity, -20);
      expect(store.positions.first.averageBuyPrice, 155.0);
    });

    test('buy-to-cover realizes P&L and releases collateral', () async {
      final store = makeStore();
      final instrument = makeInstrument();
      await store.submitStockOrder(
          instrument: instrument,
          quantity: 10,
          side: 'sell',
          orderType: 'market',
          marketPrice: 150.0);

      await store.submitStockOrder(
          instrument: instrument,
          quantity: 10,
          side: 'buy',
          orderType: 'market',
          marketPrice: 140.0);

      expect(store.positions, isEmpty);
      expect(store.shortStockCollateral, 0.0);
      // 100,000 + 1,500 (short proceeds) - 1,400 (cover) = 100,100
      expect(store.cashBalance, 100100.0);
      expect(store.history.first['profitLoss'], 100.0);
    });

    test('partial cover keeps the entry average', () async {
      final store = makeStore();
      final instrument = makeInstrument();
      await store.submitStockOrder(
          instrument: instrument,
          quantity: 20,
          side: 'sell',
          orderType: 'market',
          marketPrice: 150.0);
      await store.submitStockOrder(
          instrument: instrument,
          quantity: 5,
          side: 'buy',
          orderType: 'market',
          marketPrice: 140.0);

      expect(store.positions.first.quantity, -15);
      expect(store.positions.first.averageBuyPrice, 150.0);
    });

    test('buying past the short into a long is rejected', () async {
      final store = makeStore();
      final instrument = makeInstrument();
      await store.submitStockOrder(
          instrument: instrument,
          quantity: 10,
          side: 'sell',
          orderType: 'market',
          marketPrice: 150.0);
      expect(
          () => store.submitStockOrder(
                instrument: instrument,
                quantity: 15,
                side: 'buy',
                orderType: 'market',
                marketPrice: 150.0,
              ),
          throwsException);
    });

    test('selling more than a long position is rejected (no silent flip)',
        () async {
      final store = makeStore();
      final instrument = makeInstrument();
      await store.submitStockOrder(
          instrument: instrument,
          quantity: 10,
          side: 'buy',
          orderType: 'market',
          marketPrice: 150.0);
      expect(
          () => store.submitStockOrder(
                instrument: instrument,
                quantity: 15,
                side: 'sell',
                orderType: 'market',
                marketPrice: 150.0,
              ),
          throwsException);
    });

    test('resting short entry (sell stop) fills on trigger', () async {
      final store = makeStore();
      final result = await store.submitStockOrder(
        instrument: makeInstrument(),
        quantity: 10,
        side: 'sell',
        orderType: 'stop',
        stopPrice: 140.0,
        marketPrice: 150.0,
      );
      expect(result.state, 'confirmed');

      await store.evaluatePendingOrders(stockPrices: {'AAPL': 139.0});
      expect(store.pendingOrders, isEmpty);
      expect(store.positions.first.quantity, -10);
      expect(store.cashBalance, 100000.0 + 1390.0);
    });
  });

  group('cash-secured puts', () {
    test('sell-to-open a put reserves strike x 100 and credits the premium',
        () async {
      final store = makeStore();
      final put = makeOption(type: 'put', strike: 150.0);
      await store.submitOptionOrder(
        optionInstrument: put,
        quantity: 1,
        side: 'sell',
        orderType: 'limit',
        limitPrice: 5.0,
        marketPrice: 5.0,
      );

      expect(store.optionPositions, hasLength(1));
      expect(store.optionPositions.first.direction, 'credit');
      expect(store.optionPositions.first.quantity, 1);
      expect(store.cashBalance, 100000.0 + 500.0);
      expect(store.shortPutCollateral, 15000.0);
      expect(store.availableBuyingPower, 100000.0 + 500.0 - 15000.0);
      // The written option is a liability, so equity is unchanged at open.
      expect(store.equity, 100000.0);
    });

    test('put write is rejected without the cash to secure it', () async {
      final store = makeStore();
      await store.resetAccount(initialCapital: 10000.0);
      expect(
          () => store.submitOptionOrder(
                optionInstrument: makeOption(type: 'put', strike: 150.0),
                quantity: 1,
                side: 'sell',
                orderType: 'limit',
                limitPrice: 5.0,
                marketPrice: 5.0,
              ),
          throwsException);
      expect(store.optionPositions, isEmpty);
    });

    test('buy-to-close realizes premium P&L and releases collateral',
        () async {
      final store = makeStore();
      final put = makeOption(type: 'put', strike: 150.0);
      await store.submitOptionOrder(
          optionInstrument: put,
          quantity: 1,
          side: 'sell',
          orderType: 'limit',
          limitPrice: 5.0,
          marketPrice: 5.0);

      await store.submitOptionOrder(
          optionInstrument: put,
          quantity: 1,
          side: 'buy',
          orderType: 'limit',
          limitPrice: 3.0,
          marketPrice: 3.0,
          positionEffect: 'close');

      expect(store.optionPositions, isEmpty);
      expect(store.shortPutCollateral, 0.0);
      expect(store.cashBalance, 100000.0 + 500.0 - 300.0);
      expect(store.history.first['profitLoss'], 200.0);
    });

    test('assignment: expired ITM put buys the shares at the strike',
        () async {
      final store = makeStore();
      final put = makeOption(
          type: 'put',
          strike: 150.0,
          expiration: DateTime.now().subtract(const Duration(days: 1)));
      await store.submitOptionOrder(
          optionInstrument: put,
          quantity: 1,
          side: 'sell',
          orderType: 'limit',
          limitPrice: 5.0,
          marketPrice: 5.0);

      final settled = store.processExpiredOptions(
          underlyingPrices: {'AAPL': 140.0});

      expect(settled, hasLength(1));
      expect(store.optionPositions, isEmpty);
      expect(store.positions, hasLength(1));
      expect(store.positions.first.quantity, 100);
      expect(store.positions.first.averageBuyPrice, 150.0);
      // 100,000 + 500 premium - 15,000 assignment
      expect(store.cashBalance, 100000.0 + 500.0 - 15000.0);
      expect(store.history.first['action'], 'ASSIGNMENT');
    });

    test('expired OTM put keeps the premium', () async {
      final store = makeStore();
      final put = makeOption(
          type: 'put',
          strike: 150.0,
          expiration: DateTime.now().subtract(const Duration(days: 1)));
      await store.submitOptionOrder(
          optionInstrument: put,
          quantity: 1,
          side: 'sell',
          orderType: 'limit',
          limitPrice: 5.0,
          marketPrice: 5.0);

      store.processExpiredOptions(underlyingPrices: {'AAPL': 160.0});

      expect(store.optionPositions, isEmpty);
      expect(store.positions, isEmpty);
      expect(store.cashBalance, 100000.0 + 500.0);
      expect(store.shortPutCollateral, 0.0);
    });
  });

  group('covered calls', () {
    test('writing a call requires 100 unpledged shares per contract',
        () async {
      final store = makeStore();
      final instrument = makeInstrument();
      final call = makeOption(type: 'call', strike: 160.0);

      // Naked: no shares held.
      expect(
          () => store.submitOptionOrder(
                optionInstrument: call,
                quantity: 1,
                side: 'sell',
                orderType: 'limit',
                limitPrice: 3.0,
                marketPrice: 3.0,
              ),
          throwsException);

      // Covered: buy 100 shares first.
      await store.submitStockOrder(
          instrument: instrument,
          quantity: 100,
          side: 'buy',
          orderType: 'market',
          marketPrice: 150.0);
      await store.submitOptionOrder(
          optionInstrument: call,
          quantity: 1,
          side: 'sell',
          orderType: 'limit',
          limitPrice: 3.0,
          marketPrice: 3.0);

      expect(store.optionPositions.first.direction, 'credit');
      expect(store.coveredCallShares('AAPL'), 100.0);

      // A second contract is no longer covered.
      expect(
          () => store.submitOptionOrder(
                optionInstrument: makeOption(
                    id: 'opt_id2', type: 'call', strike: 165.0),
                quantity: 1,
                side: 'sell',
                orderType: 'limit',
                limitPrice: 2.0,
                marketPrice: 2.0,
              ),
          throwsException);
    });

    test('pledged shares cannot be sold out from under the call', () async {
      final store = makeStore();
      final instrument = makeInstrument();
      await store.submitStockOrder(
          instrument: instrument,
          quantity: 100,
          side: 'buy',
          orderType: 'market',
          marketPrice: 150.0);
      await store.submitOptionOrder(
          optionInstrument: makeOption(type: 'call', strike: 160.0),
          quantity: 1,
          side: 'sell',
          orderType: 'limit',
          limitPrice: 3.0,
          marketPrice: 3.0);

      expect(
          () => store.submitStockOrder(
                instrument: instrument,
                quantity: 100,
                side: 'sell',
                orderType: 'market',
                marketPrice: 155.0,
              ),
          throwsException);
    });

    test('assignment: expired ITM call calls the shares away at the strike',
        () async {
      final store = makeStore();
      final instrument = makeInstrument();
      await store.submitStockOrder(
          instrument: instrument,
          quantity: 100,
          side: 'buy',
          orderType: 'market',
          marketPrice: 140.0);
      await store.submitOptionOrder(
          optionInstrument: makeOption(
              type: 'call',
              strike: 150.0,
              expiration: DateTime.now().subtract(const Duration(days: 1))),
          quantity: 1,
          side: 'sell',
          orderType: 'limit',
          limitPrice: 3.0,
          marketPrice: 3.0);

      store.processExpiredOptions(underlyingPrices: {'AAPL': 160.0});

      expect(store.optionPositions, isEmpty);
      expect(store.positions, isEmpty); // shares called away
      // 100,000 - 14,000 (buy) + 300 (premium) + 15,000 (called at strike)
      expect(store.cashBalance, 100000.0 - 14000.0 + 300.0 + 15000.0);
      expect(store.history.first['action'], 'ASSIGNMENT');
      expect(store.history.first['profitLoss'], 1000.0); // (150-140)x100
    });

    test('expired OTM call releases the pledged shares', () async {
      final store = makeStore();
      final instrument = makeInstrument();
      await store.submitStockOrder(
          instrument: instrument,
          quantity: 100,
          side: 'buy',
          orderType: 'market',
          marketPrice: 140.0);
      await store.submitOptionOrder(
          optionInstrument: makeOption(
              type: 'call',
              strike: 150.0,
              expiration: DateTime.now().subtract(const Duration(days: 1))),
          quantity: 1,
          side: 'sell',
          orderType: 'limit',
          limitPrice: 3.0,
          marketPrice: 3.0);

      store.processExpiredOptions(underlyingPrices: {'AAPL': 145.0});

      expect(store.optionPositions, isEmpty);
      expect(store.positions.first.quantity, 100); // shares kept
      expect(store.coveredCallShares('AAPL'), 0.0);
      expect(store.cashBalance, 100000.0 - 14000.0 + 300.0);
    });
  });

  group('long option lifecycle unchanged', () {
    test('long expiration still cash-settles intrinsic value', () async {
      final store = makeStore();
      final call = makeOption(
          type: 'call',
          strike: 150.0,
          expiration: DateTime.now().subtract(const Duration(days: 1)));
      await store.submitOptionOrder(
          optionInstrument: call,
          quantity: 1,
          side: 'buy',
          orderType: 'limit',
          limitPrice: 5.0,
          marketPrice: 5.0);

      store.processExpiredOptions(underlyingPrices: {'AAPL': 160.0});

      expect(store.optionPositions, isEmpty);
      // 100,000 - 500 premium + 1,000 intrinsic
      expect(store.cashBalance, 100000.0 - 500.0 + 1000.0);
    });

    test('shorting does not disturb an existing long in another contract',
        () async {
      final store = makeStore();
      final longCall = makeOption(id: 'opt_long', type: 'call');
      await store.submitOptionOrder(
          optionInstrument: longCall,
          quantity: 1,
          side: 'buy',
          orderType: 'limit',
          limitPrice: 5.0,
          marketPrice: 5.0);
      await store.submitOptionOrder(
          optionInstrument: makeOption(id: 'opt_put', type: 'put', strike: 90),
          quantity: 1,
          side: 'sell',
          orderType: 'limit',
          limitPrice: 2.0,
          marketPrice: 2.0);

      expect(store.optionPositions, hasLength(2));
      expect(
          store.optionPositions.map((p) => p.direction).toSet(),
          {'debit', 'credit'});
    });
  });
}
