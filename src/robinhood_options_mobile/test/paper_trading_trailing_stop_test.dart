import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/paper_trading_store.dart';

/// With no bound user the store never touches Firestore (_load/_save
/// early-return), so a throwing Fake proves persistence stays untouched.
class _UnusedFirestore extends Fake implements FirebaseFirestore {}

/// Engine-level tests for trailing stop orders (MVP #5): watermark ratchet,
/// amount and percentage trails, buy-side (cover) trails, reservations, and
/// serialization.
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
      PaperTradingStore(firestore: _UnusedFirestore());

  Future<PaperTradingStore> storeWithLong(
      {double quantity = 10, double price = 150.0}) async {
    final store = makeStore();
    await store.submitStockOrder(
        instrument: makeInstrument(),
        quantity: quantity,
        side: 'buy',
        orderType: 'market',
        marketPrice: price);
    return store;
  }

  group('trailing stop sell (dollar amount)', () {
    test('rests with the watermark anchored at the submit price', () async {
      final store = await storeWithLong();
      final result = await store.submitStockOrder(
        instrument: makeInstrument(),
        quantity: 10,
        side: 'sell',
        orderType: 'trailing_stop',
        trailType: 'amount',
        trailValue: 5.0,
        marketPrice: 150.0,
      );

      expect(result.state, 'confirmed');
      final order = store.pendingOrders.single;
      expect(order.watermark, 150.0);
      expect(order.effectiveStopPrice, 145.0);
    });

    test('watermark ratchets up and the stop follows', () async {
      final store = await storeWithLong();
      await store.submitStockOrder(
        instrument: makeInstrument(),
        quantity: 10,
        side: 'sell',
        orderType: 'trailing_stop',
        trailType: 'amount',
        trailValue: 5.0,
        marketPrice: 150.0,
      );

      await store.evaluatePendingOrders(stockPrices: {'AAPL': 160.0});
      expect(store.pendingOrders.single.watermark, 160.0);
      expect(store.pendingOrders.single.effectiveStopPrice, 155.0);

      // A pullback that stays above the stop keeps the watermark.
      await store.evaluatePendingOrders(stockPrices: {'AAPL': 156.0});
      expect(store.pendingOrders.single.watermark, 160.0);
      expect(store.positions.single.quantity, 10); // still held
    });

    test('fills when the price retraces by the trail amount', () async {
      final store = await storeWithLong();
      await store.submitStockOrder(
        instrument: makeInstrument(),
        quantity: 10,
        side: 'sell',
        orderType: 'trailing_stop',
        trailType: 'amount',
        trailValue: 5.0,
        marketPrice: 150.0,
      );

      await store.evaluatePendingOrders(stockPrices: {'AAPL': 160.0});
      await store.evaluatePendingOrders(stockPrices: {'AAPL': 154.5});

      expect(store.pendingOrders, isEmpty);
      expect(store.positions, isEmpty);
      // Bought 10 @ 150, sold 10 @ 154.50.
      expect(store.cashBalance, 100000.0 - 1500.0 + 1545.0);
      expect(store.history.first['order_type'], 'trailing stop');
    });

    test('triggers immediately if already retraced past the trail at submit',
        () async {
      final store = await storeWithLong();
      // Trail of $5 anchored at 150; a first tick at 144 breaches it.
      await store.submitStockOrder(
        instrument: makeInstrument(),
        quantity: 10,
        side: 'sell',
        orderType: 'trailing_stop',
        trailType: 'amount',
        trailValue: 5.0,
        marketPrice: 150.0,
      );
      await store.evaluatePendingOrders(stockPrices: {'AAPL': 144.0});
      expect(store.positions, isEmpty);
      expect(store.cashBalance, 100000.0 - 1500.0 + 1440.0);
    });
  });

  group('trailing stop sell (percentage)', () {
    test('percentage trail computes the stop from the watermark', () async {
      final store = await storeWithLong();
      await store.submitStockOrder(
        instrument: makeInstrument(),
        quantity: 10,
        side: 'sell',
        orderType: 'trailing_stop',
        trailType: 'percentage',
        trailValue: 10.0,
        marketPrice: 150.0,
      );
      expect(store.pendingOrders.single.effectiveStopPrice, 135.0);

      await store.evaluatePendingOrders(stockPrices: {'AAPL': 200.0});
      expect(store.pendingOrders.single.effectiveStopPrice, 180.0);

      await store.evaluatePendingOrders(stockPrices: {'AAPL': 181.0});
      expect(store.pendingOrders, hasLength(1)); // above the stop

      await store.evaluatePendingOrders(stockPrices: {'AAPL': 179.0});
      expect(store.pendingOrders, isEmpty);
      expect(store.positions, isEmpty);
    });
  });

  group('trailing stop buy', () {
    test('trails the low and covers a short on the rebound', () async {
      final store = makeStore();
      final instrument = makeInstrument();
      // Open a short at 150.
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
        orderType: 'trailing_stop',
        trailType: 'amount',
        trailValue: 5.0,
        marketPrice: 150.0,
      );
      expect(store.pendingOrders.single.effectiveStopPrice, 155.0);

      // Price falls: watermark follows down, stop tightens.
      await store.evaluatePendingOrders(stockPrices: {'AAPL': 140.0});
      expect(store.pendingOrders.single.watermark, 140.0);
      expect(store.pendingOrders.single.effectiveStopPrice, 145.0);

      // Rebound past the trail: buy-to-cover fills.
      await store.evaluatePendingOrders(stockPrices: {'AAPL': 145.5});
      expect(store.pendingOrders, isEmpty);
      expect(store.positions, isEmpty);
      // Short proceeds 1,500; covered at 145.50 for 1,455.
      expect(store.cashBalance, 100000.0 + 1500.0 - 1455.0);
    });

    test('buy reservation uses the moving effective stop', () async {
      final store = makeStore();
      await store.submitStockOrder(
        instrument: makeInstrument(),
        quantity: 10,
        side: 'buy',
        orderType: 'trailing_stop',
        trailType: 'amount',
        trailValue: 5.0,
        marketPrice: 150.0,
      );
      // Reserves at the current effective stop (155).
      expect(store.reservedCash, 10 * 155.0);

      await store.evaluatePendingOrders(stockPrices: {'AAPL': 140.0});
      expect(store.reservedCash, 10 * 145.0);
    });
  });

  group('validation and serialization', () {
    test('requires a positive trail value and a market anchor', () async {
      final store = await storeWithLong();
      expect(
          () => store.submitStockOrder(
                instrument: makeInstrument(),
                quantity: 10,
                side: 'sell',
                orderType: 'trailing_stop',
                trailType: 'amount',
                marketPrice: 150.0,
              ),
          throwsException); // no trail value
      expect(
          () => store.submitStockOrder(
                instrument: makeInstrument(),
                quantity: 10,
                side: 'sell',
                orderType: 'trailing_stop',
                trailType: 'percentage',
                trailValue: 150.0,
                marketPrice: 150.0,
              ),
          throwsException); // >= 100 percent
      expect(
          () => store.submitStockOrder(
                instrument: makeInstrument(),
                quantity: 10,
                side: 'sell',
                orderType: 'trailing_stop',
                trailType: 'amount',
                trailValue: 5.0,
              ),
          throwsException); // no market price to anchor the watermark
    });

    test('trail fields and watermark round-trip through JSON', () {
      final order = PendingPaperOrder(
        id: 'paper_1',
        assetType: 'stock',
        symbol: 'AAPL',
        side: 'sell',
        orderType: 'trailing_stop',
        trailType: 'percentage',
        trailValue: 7.5,
        watermark: 163.21,
        quantity: 10,
        timeInForce: 'gtc',
        createdAt: DateTime(2026, 7, 15, 9, 30),
        instrumentJson: {'url': 'https://x/', 'id': 'id_AAPL'},
      );

      final restored = PendingPaperOrder.fromJson(order.toJson());
      expect(restored.trailType, 'percentage');
      expect(restored.trailValue, 7.5);
      expect(restored.watermark, 163.21);
      expect(restored.effectiveStopPrice, closeTo(163.21 * 0.925, 1e-9));
    });

    test('GFD trailing stop expires unfilled like other resting orders',
        () async {
      final store = await storeWithLong();
      await store.submitStockOrder(
        instrument: makeInstrument(),
        quantity: 10,
        side: 'sell',
        orderType: 'trailing_stop',
        trailType: 'amount',
        trailValue: 5.0,
        marketPrice: 150.0,
        timeInForce: 'gfd',
      );

      await store.evaluatePendingOrders(
          stockPrices: {'AAPL': 149.0},
          now: DateTime.now().add(const Duration(days: 1)));
      expect(store.pendingOrders, isEmpty);
      expect(store.positions.single.quantity, 10); // never sold
      expect(store.history.first['state'], 'cancelled');
    });
  });
}
