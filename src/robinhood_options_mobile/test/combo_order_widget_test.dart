import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/combo_order.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';
import 'package:robinhood_options_mobile/widgets/combo_order_widget.dart';
import 'package:robinhood_options_mobile/widgets/combo_orders_widget.dart';

class FakeFirebaseAnalytics extends Fake implements FirebaseAnalytics {
  @override
  Future<void> logScreenView({
    String? screenClass,
    String? screenName,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {}

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
    List<AnalyticsEventItem>? items,
    AnalyticsCallOptions? callOptions,
  }) async {}
}

class FakeFirebaseAnalyticsObserver extends Fake
    implements FirebaseAnalyticsObserver {}

class FakeGenerativeService extends Fake implements GenerativeService {}

void main() {
  final testUser = BrokerageUser(
    BrokerageSource.demo,
    'test_trader',
    null,
    null,
  );

  final testService = DemoService();
  final testAnalytics = FakeFirebaseAnalytics();
  final testObserver = FakeFirebaseAnalyticsObserver();
  final testGenService = FakeGenerativeService();

  final filledOrder = ComboOrder(
    id: 'combo_test_1',
    refId: 'ref_1',
    account: 'ACCT_101',
    state: 'filled',
    direction: 'credit',
    openingStrategy: 'covered_call',
    price: 182.50,
    quantity: 1.0,
    processedQuantity: 1.0,
    createdAt: DateTime(2026, 3, 15, 10, 0),
    legs: [
      ComboLeg(
        id: 'leg_stock_1',
        legType: ComboLegType.equity,
        symbol: 'AAPL',
        side: 'buy',
        positionEffect: 'open',
        ratioQuantity: 100,
        executions: [
          ComboLegExecution(
            id: 'exec_s1',
            price: 185.00,
            quantity: 100,
            settlementDate: '2026-03-20',
            timestamp: DateTime(2026, 3, 15, 10, 0),
          ),
        ],
      ),
      ComboLeg(
        id: 'leg_opt_1',
        legType: ComboLegType.option,
        symbol: 'AAPL',
        side: 'sell',
        positionEffect: 'open',
        ratioQuantity: 1,
        strikePrice: 190.0,
        expirationDate: DateTime(2026, 4, 17),
        optionType: 'call',
        executions: [
          ComboLegExecution(
            id: 'exec_o1',
            price: 2.50,
            quantity: 1,
            settlementDate: '2026-03-20',
            timestamp: DateTime(2026, 3, 15, 10, 0),
          ),
        ],
      ),
    ],
  );

  final queuedOrder = ComboOrder(
    id: 'combo_test_2',
    refId: 'ref_2',
    account: 'ACCT_101',
    state: 'queued',
    direction: 'debit',
    openingStrategy: 'collar',
    price: 240.00,
    quantity: 1.0,
    createdAt: DateTime(2026, 3, 15, 11, 0),
    cancelUrl: 'https://api.robinhood.com/combo/orders/combo_test_2/cancel/',
    legs: [
      ComboLeg(
        id: 'leg_tsla_stock',
        legType: ComboLegType.equity,
        symbol: 'TSLA',
        side: 'buy',
        positionEffect: 'open',
        ratioQuantity: 100,
      ),
      ComboLeg(
        id: 'leg_tsla_opt_call',
        legType: ComboLegType.option,
        symbol: 'TSLA',
        side: 'sell',
        positionEffect: 'open',
        ratioQuantity: 1,
        strikePrice: 260.0,
        expirationDate: DateTime(2026, 4, 17),
        optionType: 'call',
      ),
      ComboLeg(
        id: 'leg_tsla_opt_put',
        legType: ComboLegType.option,
        symbol: 'TSLA',
        side: 'buy',
        positionEffect: 'open',
        ratioQuantity: 1,
        strikePrice: 220.0,
        expirationDate: DateTime(2026, 4, 17),
        optionType: 'put',
      ),
    ],
  );

  group('ComboOrdersWidget Tests', () {
    testWidgets('renders list and header correctly', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                ComboOrdersWidget(
                  testUser,
                  testService,
                  [filledOrder, queuedOrder],
                  const [],
                  analytics: testAnalytics,
                  observer: testObserver,
                  generativeService: testGenService,
                  authUser: null,
                  userDocRef: null,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check header and titles
      expect(find.text('Combo Orders'), findsOneWidget);
      expect(find.text('AAPL'), findsOneWidget);
      expect(find.text('Covered Call'), findsOneWidget);
      expect(find.text('TSLA'), findsOneWidget);
      expect(find.text('Collar'), findsOneWidget);

      // Check chips
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Filled'), findsOneWidget);
      expect(find.text('Queued / Open'), findsOneWidget);

      // Filter by 'filled'
      await tester.tap(find.text('Filled'));
      await tester.pumpAndSettle();

      expect(find.text('AAPL'), findsOneWidget);
      expect(find.text('Covered Call'), findsOneWidget);
      expect(find.text('TSLA'), findsNothing);
      expect(find.text('Collar'), findsNothing);
    });
  });

  group('ComboOrderWidget Detail Tests', () {
    testWidgets('renders filled order details and legs breakdown', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => QuoteStore()),
            ChangeNotifierProvider(create: (_) => InstrumentStore()),
          ],
          child: MaterialApp(
            home: ComboOrderWidget(
              testUser,
              testService,
              filledOrder,
              analytics: testAnalytics,
              observer: testObserver,
              generativeService: testGenService,
              user: null,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check app bar title or header
      expect(find.text('AAPL Combo Order'), findsOneWidget);
      expect(find.text('Covered Call'), findsOneWidget);

      // Check status badge
      expect(find.text('FILLED'), findsWidgets);

      // Check legs breakdown
      expect(find.text('Package Legs (2)'), findsOneWidget);
      expect(find.text('Stock Leg'), findsOneWidget);
      expect(find.text('CALL Leg'), findsOneWidget);
      expect(find.text('Buy to Open'), findsOneWidget);
      expect(find.text('Sell to Open'), findsOneWidget);

      // Filled order is not cancelable, should not show cancel button
      expect(find.text('Cancel Combo Order'), findsNothing);

      // Drain any delayed futures/timers from service quote/instrument lookup
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
    });

    testWidgets('shows cancel button for queued order and handles dialog', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => QuoteStore()),
            ChangeNotifierProvider(create: (_) => InstrumentStore()),
          ],
          child: MaterialApp(
            home: ComboOrderWidget(
              testUser,
              testService,
              queuedOrder,
              analytics: testAnalytics,
              observer: testObserver,
              generativeService: testGenService,
              user: null,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('TSLA Combo Order'), findsOneWidget);
      expect(find.text('Collar'), findsOneWidget);
      expect(find.text('Package Legs (3)'), findsOneWidget);

      // Find cancel button
      final cancelButton = find.text('Cancel Combo Order');
      expect(cancelButton, findsOneWidget);

      // Tap cancel button to open confirmation dialog
      await tester.tap(cancelButton);
      await tester.pumpAndSettle();

      expect(find.text('Cancel Combo Order?'), findsOneWidget);
      expect(find.text('Keep Order'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('Keep Order'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel Combo Order?'), findsNothing);

      // Drain any delayed futures/timers from service quote/instrument lookup
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
    });
  });
}
