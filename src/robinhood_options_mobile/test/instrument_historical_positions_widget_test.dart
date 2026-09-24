import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/instrument_historical_position.dart';
import 'package:robinhood_options_mobile/model/instrument_order.dart';
import 'package:robinhood_options_mobile/widgets/instrument_historical_positions_widget.dart';

InstrumentOrder _makeOrder({
  required String id,
  required String side,
  required double quantity,
  required double price,
  required DateTime date,
}) {
  return InstrumentOrder(
    id,
    'ref_$id',
    'https://api.robinhood.com/orders/$id/',
    'https://api.robinhood.com/accounts/ACC123/',
    'https://api.robinhood.com/positions/ACC123/inst_123/',
    null,
    'https://api.robinhood.com/instruments/inst_123/',
    'inst_123',
    quantity,
    price,
    0.0,
    'filled',
    null,
    'market',
    side,
    'gtc',
    'immediate',
    price,
    null,
    quantity,
    null,
    date,
    date,
    null,
  );
}

void main() {
  group('InstrumentHistoricalPositionsWidget Tests', () {
    testWidgets('renders nothing (SizedBox.shrink) when there is no history',
        (WidgetTester tester) async {
      final summary = InstrumentCostBasisLookbackSummary.fromOrders([]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InstrumentHistoricalPositionsWidget(summary: summary),
          ),
        ),
      );

      expect(find.byType(Card), findsNothing);
      expect(find.text('Previous Positions'), findsNothing);
    });

    testWidgets('renders previous positions card with metrics and cycles',
        (WidgetTester tester) async {
      final d1 = DateTime(2025, 1, 10);
      final d2 = DateTime(2025, 1, 25);
      final orders = [
        _makeOrder(id: 'o1', side: 'buy', quantity: 10, price: 100, date: d1),
        _makeOrder(id: 'o2', side: 'sell', quantity: 10, price: 130, date: d2),
      ];

      final summary = InstrumentCostBasisLookbackSummary.fromOrders(
        orders,
        symbol: 'AAPL',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: InstrumentHistoricalPositionsWidget(summary: summary),
            ),
          ),
        ),
      );

      // Verify Header
      expect(find.text('Previous Positions'), findsOneWidget);
      expect(find.textContaining('1 round trip'), findsOneWidget);
      expect(find.textContaining(r'+$300.00'), findsWidgets);

      // Verify Metric Badges
      expect(find.text('Win Rate'), findsOneWidget);
      expect(find.text('100% (1/1)'), findsOneWidget);
      expect(find.text('Avg Hold'), findsOneWidget);
      expect(find.text('Avg Buy'), findsOneWidget);
      expect(find.text('Avg Sell'), findsOneWidget);

      // Verify Spread visualizer
      expect(find.text('Historical Execution Spread'), findsOneWidget);
      expect(find.textContaining(r'+$30.00'), findsOneWidget);

      // Verify Cycle list item
      expect(find.text('Historical Cycles'), findsOneWidget);
      expect(find.textContaining('10 shares'), findsOneWidget);
    });

    testWidgets('taps on cycle to open round-trip details bottom sheet',
        (WidgetTester tester) async {
      final d1 = DateTime(2025, 2, 1, 10, 0);
      final d2 = DateTime(2025, 2, 10, 15, 0);
      final orders = [
        _makeOrder(id: 'b1', side: 'buy', quantity: 20, price: 150, date: d1),
        _makeOrder(id: 's1', side: 'sell', quantity: 20, price: 180, date: d2),
      ];

      final summary = InstrumentCostBasisLookbackSummary.fromOrders(orders);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: InstrumentHistoricalPositionsWidget(summary: summary),
            ),
          ),
        ),
      );

      // Tap the cycle list tile
      await tester.tap(find.byType(ListTile).first);
      await tester.pumpAndSettle();

      // Verify Bottom Sheet opens
      expect(find.text('Round-Trip Execution Details'), findsOneWidget);
      expect(find.text('Holding Period'), findsOneWidget);
      expect(find.text('Average Buy Price'), findsOneWidget);
      expect(find.text('Average Sell Price'), findsOneWidget);
      expect(find.text('Total Cost Basis'), findsOneWidget);
      expect(find.text('Orders in this Cycle (2)'), findsOneWidget);
      expect(find.textContaining('BUY 20 shares'), findsOneWidget);
      expect(find.textContaining('SELL 20 shares'), findsOneWidget);
    });

    testWidgets('renders cleanly without overflow on narrow 320px viewport',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final d1 = DateTime(2025, 1, 10);
      final d2 = DateTime(2025, 1, 25);
      final orders = [
        _makeOrder(
            id: 'o1', side: 'buy', quantity: 15, price: 165.50, date: d1),
        _makeOrder(
            id: 'o2', side: 'sell', quantity: 15, price: 188.50, date: d2),
      ];

      final summary = InstrumentCostBasisLookbackSummary.fromOrders(
        orders,
        symbol: 'AAPL',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: InstrumentHistoricalPositionsWidget(summary: summary),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Previous Positions'), findsOneWidget);
    });

    testWidgets('opens bottom sheet on narrow 320px viewport without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final d1 = DateTime(2025, 2, 1, 10, 30);
      final d2 = DateTime(2025, 2, 10, 15, 45);
      final orders = [
        _makeOrder(
            id: 'b1',
            side: 'buy',
            quantity: 0.30539123,
            price: 3274.55,
            date: d1),
        _makeOrder(
            id: 's1',
            side: 'sell',
            quantity: 0.30539123,
            price: 3450.12,
            date: d2),
      ];

      final summary = InstrumentCostBasisLookbackSummary.fromOrders(orders);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: InstrumentHistoricalPositionsWidget(summary: summary),
            ),
          ),
        ),
      );

      // Tap cycle to open bottom sheet
      await tester.tap(find.byType(ListTile).first);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Round-Trip Execution Details'), findsOneWidget);
      expect(find.text('Orders in this Cycle (2)'), findsOneWidget);
    });

    testWidgets('respects showHeader parameter', (WidgetTester tester) async {
      final d1 = DateTime(2025, 2, 1);
      final d2 = DateTime(2025, 2, 10);
      final orders = [
        _makeOrder(id: 'b1', side: 'buy', quantity: 10, price: 100, date: d1),
        _makeOrder(id: 's1', side: 'sell', quantity: 10, price: 120, date: d2),
      ];
      final summary = InstrumentCostBasisLookbackSummary.fromOrders(orders);

      // showHeader: false
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: InstrumentHistoricalPositionsWidget(
                summary: summary,
                showHeader: false,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Previous Positions'), findsNothing);
      expect(find.text('Historical Cycles'), findsOneWidget);

      // showHeader: true (default)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: InstrumentHistoricalPositionsWidget(
                summary: summary,
                showHeader: true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Previous Positions'), findsOneWidget);
      expect(find.byIcon(Icons.history_toggle_off_rounded), findsOneWidget);
      expect(find.text('Historical Cycles'), findsOneWidget);
    });

    testWidgets('renders split badge and bottom sheet corporate action details',
        (WidgetTester tester) async {
      final buyDate = DateTime(2024, 5, 1);
      final splitDate = DateTime(2024, 6, 10);
      final sellDate = DateTime(2024, 7, 1);

      final orders = [
        _makeOrder(
            id: 'b1', side: 'buy', quantity: 10, price: 1000, date: buyDate),
        _makeOrder(
            id: 's1', side: 'sell', quantity: 100, price: 120, date: sellDate),
      ];

      final splits = [
        StockSplit(
          executionDate: splitDate,
          multiplier: 10.0,
          divisor: 1.0,
        ),
      ];

      final summary = InstrumentCostBasisLookbackSummary.fromOrders(
        orders,
        symbol: 'NVDA',
        splits: splits,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: InstrumentHistoricalPositionsWidget(summary: summary),
            ),
          ),
        ),
      );

      // Verify Split Chip on Cycle Card
      expect(find.text('10:1 Split'), findsOneWidget);
      expect(find.byIcon(Icons.call_split), findsOneWidget);

      // Tap cycle to open bottom sheet
      await tester.tap(find.byType(ListTile).first);
      await tester.pumpAndSettle();

      // Verify Bottom Sheet displays Corporate Actions section & split-adjusted labels
      expect(find.text('Corporate Actions / Stock Splits (1)'), findsOneWidget);
      expect(find.text('10 for 1 Split'), findsOneWidget);
      expect(find.textContaining('split-adjusted'), findsWidgets);
    });

    testWidgets('respects custom title parameter',
        (WidgetTester tester) async {
      final orders = [
        _makeOrder(id: 'o1', side: 'buy', quantity: 5, price: 50, date: DateTime(2025, 1, 1)),
        _makeOrder(id: 'o2', side: 'sell', quantity: 5, price: 60, date: DateTime(2025, 1, 10)),
      ];
      final summary = InstrumentCostBasisLookbackSummary.fromOrders(orders, symbol: 'TSLA');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: InstrumentHistoricalPositionsWidget(
                summary: summary,
                title: 'TSLA Past Positions',
              ),
            ),
          ),
        ),
      );

      expect(find.text('TSLA Past Positions'), findsOneWidget);
      expect(find.text('Previous Positions'), findsNothing);
    });

    testWidgets('invokes onTapOrder callback when order tapped in bottom sheet',
        (WidgetTester tester) async {
      InstrumentOrder? tappedOrder;
      final orders = [
        _makeOrder(id: 'ord_buy_1', side: 'buy', quantity: 10, price: 100, date: DateTime(2025, 1, 1)),
        _makeOrder(id: 'ord_sell_1', side: 'sell', quantity: 10, price: 120, date: DateTime(2025, 1, 5)),
      ];
      final summary = InstrumentCostBasisLookbackSummary.fromOrders(orders, symbol: 'AAPL');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: InstrumentHistoricalPositionsWidget(
                summary: summary,
                onTapOrder: (order) {
                  tappedOrder = order;
                },
              ),
            ),
          ),
        ),
      );

      // Open bottom sheet
      await tester.tap(find.byType(ListTile).first);
      await tester.pumpAndSettle();

      // Tap buy order in bottom sheet
      final buyOrderFinder = find.textContaining('BUY 10 shares');
      expect(buyOrderFinder, findsOneWidget);
      await tester.ensureVisible(buyOrderFinder);
      await tester.pumpAndSettle();
      await tester.tap(buyOrderFinder);
      await tester.pumpAndSettle();

      expect(tappedOrder, isNotNull);
      expect(tappedOrder!.id, 'ord_buy_1');
    });
  });
}
