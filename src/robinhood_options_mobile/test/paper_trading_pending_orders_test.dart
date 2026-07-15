import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/paper_trading_store.dart';

/// With no bound user the store never touches Firestore (_load/_save
/// early-return), so a throwing Fake proves persistence stays untouched.
class _UnusedFirestore extends Fake implements FirebaseFirestore {}

/// Engine-level tests for the paper trading resting-order engine.
///
/// The store is constructed with an unused Firestore fake and no bound user,
/// so all state stays in memory and the order/position/cash math can be
/// asserted directly.
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

  OptionInstrument makeOptionInstrument({String id = 'opt_id'}) {
    return OptionInstrument(
        'chain_id',
        'AAPL',
        DateTime.now(),
        DateTime.now().add(const Duration(days: 30)),
        id,
        DateTime.now(),
        const MinTicks(0.01, 0.01, 0.0),
        'tradable',
        'active',
        150.0,
        'tradable',
        'call',
        DateTime.now(),
        'https://api.robinhood.com/options/instruments/$id/',
        null,
        'long',
        'short');
  }

  PaperTradingStore makeStore() =>
      PaperTradingStore(firestore: _UnusedFirestore());

  group('immediate fills', () {
    test('market buy fills immediately at market price', () async {
      final store = makeStore();
      final result = await store.submitStockOrder(
        instrument: makeInstrument(),
        quantity: 10,
        side: 'buy',
        orderType: 'market',
        marketPrice: 150.0,
      );

      expect(result.state, 'filled');
      expect(store.pendingOrders, isEmpty);
      expect(store.positions, hasLength(1));
      expect(store.positions.first.quantity, 10);
      expect(store.cashBalance, 100000.0 - 1500.0);
    });

    test('marketable limit buy (limit above market) fills immediately',
        () async {
      final store = makeStore();
      final result = await store.submitStockOrder(
        instrument: makeInstrument(),
        quantity: 10,
        side: 'buy',
        orderType: 'limit',
        limitPrice: 155.0,
        marketPrice: 150.0,
      );

      expect(result.state, 'filled');
      expect(store.pendingOrders, isEmpty);
      // Fills at the market price, not the (worse) limit price.
      expect(store.cashBalance, 100000.0 - 1500.0);
    });

    test('market order without a market price is rejected', () async {
      final store = makeStore();
      expect(
          () => store.submitStockOrder(
                instrument: makeInstrument(),
                quantity: 10,
                side: 'buy',
                orderType: 'market',
              ),
          throwsException);
    });

    test('unsupported order types are rejected with a clear error', () async {
      final store = makeStore();
      expect(
          () => store.submitStockOrder(
                instrument: makeInstrument(),
                quantity: 10,
                side: 'buy',
                orderType: 'trailing_stop',
                marketPrice: 150.0,
              ),
          throwsException);
    });
  });

  group('resting limit orders', () {
    test('limit buy below market rests and reserves buying power', () async {
      final store = makeStore();
      final result = await store.submitStockOrder(
        instrument: makeInstrument(),
        quantity: 10,
        side: 'buy',
        orderType: 'limit',
        limitPrice: 140.0,
        marketPrice: 150.0,
      );

      expect(result.state, 'confirmed');
      expect(store.pendingOrders, hasLength(1));
      expect(store.cashBalance, 100000.0); // cash untouched while resting
      expect(store.reservedCash, 1400.0);
      expect(store.availableBuyingPower, 100000.0 - 1400.0);
      expect(store.positions, isEmpty);
    });

    test('resting limit buy fills when the price drops to the limit',
        () async {
      final store = makeStore();
      await store.submitStockOrder(
        instrument: makeInstrument(),
        quantity: 10,
        side: 'buy',
        orderType: 'limit',
        limitPrice: 140.0,
        marketPrice: 150.0,
      );

      // Price still above the limit: nothing happens.
      await store.evaluatePendingOrders(stockPrices: {'AAPL': 145.0});
      expect(store.pendingOrders, hasLength(1));
      expect(store.positions, isEmpty);

      // Price crosses the limit: fills at the observed market price.
      await store.evaluatePendingOrders(stockPrices: {'AAPL': 139.0});
      expect(store.pendingOrders, isEmpty);
      expect(store.positions, hasLength(1));
      expect(store.positions.first.averageBuyPrice, 139.0);
      expect(store.cashBalance, 100000.0 - 1390.0);
      expect(store.history.first['state'], 'filled');
      expect(store.history.first['order_type'], 'limit');
    });

    test('resting limit sell fills when the price rises to the limit',
        () async {
      final store = makeStore();
      final instrument = makeInstrument();
      await store.submitStockOrder(
          instrument: instrument,
          quantity: 10,
          side: 'buy',
          orderType: 'market',
          marketPrice: 150.0);

      final result = await store.submitStockOrder(
        instrument: instrument,
        quantity: 10,
        side: 'sell',
        orderType: 'limit',
        limitPrice: 160.0,
        marketPrice: 150.0,
      );
      expect(result.state, 'confirmed');

      await store.evaluatePendingOrders(stockPrices: {'AAPL': 161.0});
      expect(store.pendingOrders, isEmpty);
      expect(store.positions, isEmpty);
      expect(store.cashBalance, 100000.0 - 1500.0 + 1610.0);
    });
  });

  group('stop and stop-limit orders', () {
    test('stop-loss sell triggers when the price falls to the stop',
        () async {
      final store = makeStore();
      final instrument = makeInstrument();
      await store.submitStockOrder(
          instrument: instrument,
          quantity: 10,
          side: 'buy',
          orderType: 'market',
          marketPrice: 150.0);

      final result = await store.submitStockOrder(
        instrument: instrument,
        quantity: 10,
        side: 'sell',
        orderType: 'stop',
        stopPrice: 140.0,
        marketPrice: 150.0,
      );
      expect(result.state, 'confirmed');

      // Above the stop: keeps resting.
      await store.evaluatePendingOrders(stockPrices: {'AAPL': 145.0});
      expect(store.pendingOrders, hasLength(1));

      // Breaches the stop: fills at the observed market price.
      await store.evaluatePendingOrders(stockPrices: {'AAPL': 138.0});
      expect(store.pendingOrders, isEmpty);
      expect(store.positions, isEmpty);
      expect(store.cashBalance, 100000.0 - 1500.0 + 1380.0);
    });

    test('stop-limit sell triggers on the stop, then fills on the limit',
        () async {
      final store = makeStore();
      final instrument = makeInstrument();
      await store.submitStockOrder(
          instrument: instrument,
          quantity: 10,
          side: 'buy',
          orderType: 'market',
          marketPrice: 150.0);

      await store.submitStockOrder(
        instrument: instrument,
        quantity: 10,
        side: 'sell',
        orderType: 'stop_limit',
        stopPrice: 140.0,
        limitPrice: 141.0,
        marketPrice: 150.0,
      );

      // Stop not breached yet.
      await store.evaluatePendingOrders(stockPrices: {'AAPL': 142.0});
      expect(store.pendingOrders, hasLength(1));
      expect(store.pendingOrders.first.triggered, isFalse);

      // Stop breached, but limit (141) not marketable at 140.
      await store.evaluatePendingOrders(stockPrices: {'AAPL': 140.0});
      expect(store.pendingOrders, hasLength(1));
      expect(store.pendingOrders.first.triggered, isTrue);

      // Price recovers past the limit: fills.
      await store.evaluatePendingOrders(stockPrices: {'AAPL': 141.5});
      expect(store.pendingOrders, isEmpty);
      expect(store.positions, isEmpty);
      expect(store.cashBalance, 100000.0 - 1500.0 + 1415.0);
    });
  });

  group('reservations', () {
    test('rejects a buy that exceeds available (unreserved) buying power',
        () async {
      final store = makeStore();
      await store.submitStockOrder(
        instrument: makeInstrument(symbol: 'MSFT'),
        quantity: 300,
        side: 'buy',
        orderType: 'limit',
        limitPrice: 300.0, // reserves 90,000
        marketPrice: 400.0,
      );

      expect(
          () => store.submitStockOrder(
                instrument: makeInstrument(symbol: 'GOOG'),
                quantity: 100,
                side: 'buy',
                orderType: 'limit',
                limitPrice: 200.0, // needs 20,000 > 10,000 available
                marketPrice: 250.0,
              ),
          throwsException);
    });

    test('rejects sells whose quantity is already reserved by working orders',
        () async {
      final store = makeStore();
      final instrument = makeInstrument();
      await store.submitStockOrder(
          instrument: instrument,
          quantity: 10,
          side: 'buy',
          orderType: 'market',
          marketPrice: 150.0);

      await store.submitStockOrder(
          instrument: instrument,
          quantity: 6,
          side: 'sell',
          orderType: 'limit',
          limitPrice: 200.0,
          marketPrice: 150.0);

      // Only 4 shares remain unreserved.
      expect(
          () => store.submitStockOrder(
                instrument: instrument,
                quantity: 6,
                side: 'sell',
                orderType: 'limit',
                limitPrice: 210.0,
                marketPrice: 150.0,
              ),
          throwsException);
    });

    test('cancel releases the reservation', () async {
      final store = makeStore();
      final result = await store.submitStockOrder(
        instrument: makeInstrument(),
        quantity: 10,
        side: 'buy',
        orderType: 'limit',
        limitPrice: 140.0,
        marketPrice: 150.0,
      );
      expect(store.availableBuyingPower, 100000.0 - 1400.0);

      final cancelled = await store.cancelPendingOrder(result.id);
      expect(cancelled, isTrue);
      expect(store.pendingOrders, isEmpty);
      expect(store.availableBuyingPower, 100000.0);

      // Cancelling again reports not found.
      expect(await store.cancelPendingOrder(result.id), isFalse);
    });

    test('order that cannot be funded at trigger time is rejected, not retried',
        () async {
      final store = makeStore();
      // Reserve 50,000 with a resting order.
      await store.submitStockOrder(
        instrument: makeInstrument(symbol: 'MSFT'),
        quantity: 100,
        side: 'buy',
        orderType: 'limit',
        limitPrice: 500.0,
        marketPrice: 600.0,
      );
      // Immediate fill consumes 90,000 of the 100,000 cash (market orders
      // check raw cash, not net-of-reservation buying power).
      await store.submitStockOrder(
        instrument: makeInstrument(symbol: 'AAPL'),
        quantity: 600,
        side: 'buy',
        orderType: 'market',
        marketPrice: 150.0,
      );
      expect(store.cashBalance, 10000.0);

      // The resting order triggers but can no longer be funded.
      await store.evaluatePendingOrders(stockPrices: {'MSFT': 499.0});
      expect(store.pendingOrders, isEmpty);
      expect(store.history.first['state'], 'rejected');
    });
  });

  group('time in force', () {
    test('GFD orders expire after their trading day', () async {
      final store = makeStore();
      await store.submitStockOrder(
        instrument: makeInstrument(),
        quantity: 10,
        side: 'buy',
        orderType: 'limit',
        limitPrice: 140.0,
        marketPrice: 150.0,
        timeInForce: 'gfd',
      );

      // Same day: still working (price not met).
      await store.evaluatePendingOrders(stockPrices: {'AAPL': 150.0});
      expect(store.pendingOrders, hasLength(1));

      // Next day: expired without filling.
      await store.evaluatePendingOrders(
          stockPrices: {'AAPL': 139.0},
          now: DateTime.now().add(const Duration(days: 1)));
      expect(store.pendingOrders, isEmpty);
      expect(store.positions, isEmpty);
      expect(store.history.first['state'], 'cancelled');
    });

    test('GTC orders survive into later days', () async {
      final store = makeStore();
      await store.submitStockOrder(
        instrument: makeInstrument(),
        quantity: 10,
        side: 'buy',
        orderType: 'limit',
        limitPrice: 140.0,
        marketPrice: 150.0,
        timeInForce: 'gtc',
      );

      await store.evaluatePendingOrders(
          stockPrices: {'AAPL': 139.0},
          now: DateTime.now().add(const Duration(days: 5)));
      expect(store.positions, hasLength(1));
      expect(store.pendingOrders, isEmpty);
    });
  });

  group('option orders', () {
    test('resting option limit buy fills on the option mark', () async {
      final store = makeStore();
      final option = makeOptionInstrument();
      final result = await store.submitOptionOrder(
        optionInstrument: option,
        quantity: 2,
        side: 'buy',
        orderType: 'limit',
        limitPrice: 5.0,
        marketPrice: 6.0,
      );
      expect(result.state, 'confirmed');
      // Options reserve at the 100x contract multiplier.
      expect(store.reservedCash, 2 * 5.0 * 100);

      await store.evaluatePendingOrders(
          stockPrices: {}, optionMarks: {'opt_id': 4.5});
      expect(store.pendingOrders, isEmpty);
      expect(store.optionPositions, hasLength(1));
      expect(store.optionPositions.first.quantity, 2);
      expect(store.cashBalance, 100000.0 - (4.5 * 100 * 2));
    });
  });

  group('account lifecycle', () {
    test('resetAccount clears working orders and custom capital sticks',
        () async {
      final store = makeStore();
      await store.submitStockOrder(
        instrument: makeInstrument(),
        quantity: 10,
        side: 'buy',
        orderType: 'limit',
        limitPrice: 140.0,
        marketPrice: 150.0,
      );
      expect(store.pendingOrders, hasLength(1));

      await store.resetAccount(initialCapital: 25000.0);
      expect(store.pendingOrders, isEmpty);
      expect(store.cashBalance, 25000.0);
      expect(store.initialCapital, 25000.0);
      expect(store.availableBuyingPower, 25000.0);
    });

    test('pending orders round-trip through JSON', () {
      final order = PendingPaperOrder(
        id: 'paper_1',
        assetType: 'stock',
        symbol: 'AAPL',
        side: 'buy',
        orderType: 'stop_limit',
        limitPrice: 141.0,
        stopPrice: 140.0,
        quantity: 10,
        timeInForce: 'gfd',
        createdAt: DateTime(2026, 7, 15, 9, 30),
        triggered: true,
        instrumentJson: {'url': 'https://x/', 'id': 'id_AAPL'},
      );

      final restored = PendingPaperOrder.fromJson(order.toJson());
      expect(restored.id, order.id);
      expect(restored.assetType, order.assetType);
      expect(restored.orderType, order.orderType);
      expect(restored.limitPrice, order.limitPrice);
      expect(restored.stopPrice, order.stopPrice);
      expect(restored.quantity, order.quantity);
      expect(restored.timeInForce, order.timeInForce);
      expect(restored.createdAt, order.createdAt);
      expect(restored.triggered, isTrue);
      expect(restored.assetUrl, 'https://x/');
      expect(restored.priceKey, 'AAPL');
    });
  });
}
