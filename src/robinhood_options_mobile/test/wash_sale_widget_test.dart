import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/wash_sale_record.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/widgets/tax_optimization_widget.dart';

class FakeFirebaseAnalytics extends Fake implements FirebaseAnalytics {
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

  Widget createWidgetUnderTest({
    List<WashSaleRecord>? initialWashSales,
    int initialTabIndex = 1,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => InstrumentPositionStore()),
        ChangeNotifierProvider(create: (_) => OptionPositionStore()),
        ChangeNotifierProvider(create: (_) => InstrumentStore()),
      ],
      child: MaterialApp(
        home: TaxOptimizationWidget(
          user: testUser,
          service: testService,
          analytics: testAnalytics,
          observer: testObserver,
          generativeService: testGenService,
          appUser: null,
          userDocRef: null,
          initialWashSales: initialWashSales,
          initialTabIndex: initialTabIndex,
        ),
      ),
    );
  }

  testWidgets('renders empty wash sale tracker state with green confirmation',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createWidgetUnderTest(initialWashSales: []));
    await tester.pumpAndSettle();

    expect(find.text('30-Day Wash Sale Tracker'), findsOneWidget);
    expect(find.text('IRS Section 1091 Real-Time Monitoring'), findsOneWidget);
    expect(find.textContaining('No active wash sale restrictions'), findsOneWidget);
  });

  testWidgets('renders active window countdown and disallowed wash sale records',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final now = DateTime.now();
    final testRecords = [
      WashSaleRecord(
        id: 'ws_tsla',
        symbol: 'TSLA',
        name: 'Tesla, Inc.',
        assetType: 'stock',
        saleDate: now.subtract(const Duration(days: 10)),
        salePrice: 220.0,
        quantitySold: 10.0,
        realizedLoss: -450.0,
        windowStartDate: now.subtract(const Duration(days: 40)),
        windowEndDate: now.subtract(const Duration(days: 10)).add(const Duration(days: 30)),
        status: WashSaleStatus.activeWindow,
      ),
      WashSaleRecord(
        id: 'ws_nvda',
        symbol: 'NVDA',
        name: 'NVIDIA Corporation',
        assetType: 'stock',
        saleDate: now.subtract(const Duration(days: 20)),
        salePrice: 115.0,
        quantitySold: 20.0,
        realizedLoss: -320.0,
        windowStartDate: now.subtract(const Duration(days: 50)),
        windowEndDate: now.subtract(const Duration(days: 20)).add(const Duration(days: 30)),
        status: WashSaleStatus.disallowed,
        replacementDate: now.subtract(const Duration(days: 15)),
        replacementPrice: 120.0,
        replacementQuantity: 20.0,
        replacementAssetType: 'stock',
        disallowedLoss: 320.0,
        adjustedCostBasis: (120.0 * 20.0) + 320.0,
      ),
    ];

    await tester.pumpWidget(createWidgetUnderTest(initialWashSales: testRecords));
    await tester.pumpAndSettle();

    // Verify filter chips
    expect(find.text('All (2)'), findsOneWidget);
    expect(find.text('1 Active Window'), findsOneWidget);
    expect(find.text('1 Disallowed'), findsOneWidget);

    // Verify symbols and labels
    expect(find.text('TSLA'), findsOneWidget);
    expect(find.text('NVDA'), findsOneWidget);
    expect(find.textContaining('days left'), findsOneWidget);
    expect(find.text('Loss Disallowed'), findsOneWidget);
    expect(find.text('Safe Repurchase Date:'), findsOneWidget);
    expect(find.text('Deferred Basis Adjustment:'), findsOneWidget);
  });

  testWidgets('opens IRS Section 1091 Wash Sale Rule bottom sheet on info icon click',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createWidgetUnderTest(initialWashSales: []));
    await tester.pumpAndSettle();

    final infoButton = find.byTooltip('IRS Rule 1091 Guide');
    expect(infoButton, findsOneWidget);

    await tester.tap(infoButton);
    await tester.pumpAndSettle();

    expect(find.text('IRS Section 1091 Wash Sale Rule'), findsOneWidget);
    expect(find.text('61-Day Window'), findsOneWidget);
    expect(find.text('Substantially Identical Contracts'), findsOneWidget);
    expect(find.text('Loss Is Deferred, Not Lost'), findsOneWidget);
    expect(find.text('Understood'), findsOneWidget);

    await tester.tap(find.text('Understood'));
    await tester.pumpAndSettle();

    expect(find.text('IRS Section 1091 Wash Sale Rule'), findsNothing);
  });

  testWidgets('renders Loss Harvesting tab on initialTabIndex 0 and switches to Wash Sales tab',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createWidgetUnderTest(
      initialWashSales: [],
      initialTabIndex: 0,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Taxes'), findsOneWidget);
    expect(find.text('Loss Harvesting'), findsOneWidget);
    expect(find.text('Wash Sales'), findsOneWidget);
    expect(find.text('Total Potential Tax Loss'), findsOneWidget);

    // Switch to Wash Sales tab
    await tester.tap(find.text('Wash Sales'));
    await tester.pumpAndSettle();

    expect(find.text('30-Day Wash Sale Tracker'), findsOneWidget);
    expect(find.text('IRS Section 1091 Real-Time Monitoring'), findsOneWidget);
  });
}
