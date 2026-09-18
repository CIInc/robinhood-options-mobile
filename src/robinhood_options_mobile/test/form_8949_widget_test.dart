import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/form_8949_model.dart';
import 'package:robinhood_options_mobile/model/instrument_order_store.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/option_order_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
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

  @override
  Future<void> logScreenView({
    String? screenClass,
    String? screenName,
    Map<String, Object>? parameters,
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
    List<Form8949Entry>? initialEntries,
    int initialTabIndex = 3,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => InstrumentPositionStore()),
        ChangeNotifierProvider(create: (_) => OptionPositionStore()),
        ChangeNotifierProvider(create: (_) => InstrumentOrderStore()),
        ChangeNotifierProvider(create: (_) => OptionOrderStore()),
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
          initialTabIndex: initialTabIndex,
          initialForm8949Entries: initialEntries,
        ),
      ),
    );
  }

  group('TaxOptimizationWidget Form 8949 Tab Tests', () {
    testWidgets('renders all 4 tabs including Form 8949', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(initialTabIndex: 0));
      await tester.pumpAndSettle();

      expect(find.text('Loss Harvesting'), findsOneWidget);
      expect(find.text('Wash Sales'), findsOneWidget);
      expect(find.text('Capital Gains'), findsOneWidget);
      expect(find.text('Form 8949'), findsOneWidget);
    });

    testWidgets('renders Form 8949 tab directly with summary card and export button',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final now = DateTime.now();
      final sampleEntries = [
        Form8949Entry.create(
          id: 'test_1',
          description: '10 sh. AAPL',
          symbol: 'AAPL',
          assetType: 'stock',
          quantity: 10,
          acquiredDate: now.subtract(const Duration(days: 60)),
          soldDate: now.subtract(const Duration(days: 10)),
          proceeds: 2200.0,
          costBasis: 1800.0, // Gain = +$400
        ),
        Form8949Entry.create(
          id: 'test_2',
          description: '20 sh. NVDA',
          symbol: 'NVDA',
          assetType: 'stock',
          quantity: 20,
          acquiredDate: now.subtract(const Duration(days: 80)),
          soldDate: now.subtract(const Duration(days: 20)),
          proceeds: 1500.0,
          costBasis: 1900.0,
          adjustmentCode: 'W',
          adjustmentAmount: 400.0, // Wash sale disallowed $400 -> Net $0.00
        ),
        Form8949Entry.create(
          id: 'test_3',
          description: '30 sh. MSFT',
          symbol: 'MSFT',
          assetType: 'stock',
          quantity: 30,
          acquiredDate: now.subtract(const Duration(days: 500)), // Long-term
          soldDate: now.subtract(const Duration(days: 5)),
          proceeds: 12000.0,
          costBasis: 9000.0, // Gain = +$3,000
        ),
      ];

      await tester.pumpWidget(createWidgetUnderTest(
        initialEntries: sampleEntries,
        initialTabIndex: 3,
      ));
      await tester.pumpAndSettle();

      // Verify Header and Title
      expect(find.text('IRS Form 8949 & Schedule D'), findsOneWidget);
      expect(find.text('Export Form 8949 CSV'), findsOneWidget);

      // Verify Summary Card
      expect(find.text('Reconciliation Summary'), findsOneWidget);
      expect(find.text('Part I: Short-Term'), findsOneWidget);
      expect(find.text('Part II: Long-Term'), findsOneWidget);
      expect(find.text('Wash Sale Disallowed'), findsOneWidget);
      expect(find.text('Schedule D Net Gain/Loss'), findsOneWidget);

      // Verify Dispositions List
      expect(find.text('10 sh. AAPL'), findsOneWidget);
      expect(find.text('20 sh. NVDA'), findsOneWidget);
      expect(find.text('30 sh. MSFT'), findsOneWidget);

      // Verify Wash sale code W badge
      expect(find.text('Code W: +\$400.00'), findsOneWidget);
      expect(find.text('Part I (Short-Term)'), findsNWidgets(2));
      expect(find.text('Part II (Long-Term)'), findsOneWidget);
    });

    testWidgets('filters dispositions by chip selection (Short-Term, Long-Term, Wash Sales)',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final now = DateTime.now();
      final sampleEntries = [
        Form8949Entry.create(
          id: 'test_st',
          description: '10 sh. AAPL',
          symbol: 'AAPL',
          assetType: 'stock',
          quantity: 10,
          acquiredDate: now.subtract(const Duration(days: 50)),
          soldDate: now.subtract(const Duration(days: 10)),
          proceeds: 2000.0,
          costBasis: 1500.0,
        ),
        Form8949Entry.create(
          id: 'test_lt',
          description: '50 sh. MSFT',
          symbol: 'MSFT',
          assetType: 'stock',
          quantity: 50,
          acquiredDate: now.subtract(const Duration(days: 450)),
          soldDate: now.subtract(const Duration(days: 15)),
          proceeds: 15000.0,
          costBasis: 10000.0,
        ),
        Form8949Entry.create(
          id: 'test_ws',
          description: '15 sh. TSLA',
          symbol: 'TSLA',
          assetType: 'stock',
          quantity: 15,
          acquiredDate: now.subtract(const Duration(days: 40)),
          soldDate: now.subtract(const Duration(days: 5)),
          proceeds: 3000.0,
          costBasis: 3500.0,
          adjustmentCode: 'W',
          adjustmentAmount: 500.0,
        ),
      ];

      await tester.pumpWidget(createWidgetUnderTest(
        initialEntries: sampleEntries,
        initialTabIndex: 3,
      ));
      await tester.pumpAndSettle();

      expect(find.text('10 sh. AAPL'), findsOneWidget);
      expect(find.text('50 sh. MSFT'), findsOneWidget);
      expect(find.text('15 sh. TSLA'), findsOneWidget);

      // Filter: Short-Term Part I
      await tester.tap(find.widgetWithText(FilterChip, 'Short-Term (2)'));
      await tester.pumpAndSettle();

      expect(find.text('10 sh. AAPL'), findsOneWidget);
      expect(find.text('15 sh. TSLA'), findsOneWidget);
      expect(find.text('50 sh. MSFT'), findsNothing);

      // Filter: Long-Term Part II
      await tester.tap(find.widgetWithText(FilterChip, 'Long-Term (1)'));
      await tester.pumpAndSettle();

      expect(find.text('50 sh. MSFT'), findsOneWidget);
      expect(find.text('10 sh. AAPL'), findsNothing);
      expect(find.text('15 sh. TSLA'), findsNothing);

      // Filter: Wash Sales
      await tester.tap(find.widgetWithText(FilterChip, 'Wash Sales (1)'));
      await tester.pumpAndSettle();

      expect(find.text('15 sh. TSLA'), findsOneWidget);
      expect(find.text('10 sh. AAPL'), findsNothing);
      expect(find.text('50 sh. MSFT'), findsNothing);
    });

    testWidgets('renders empty state when no dispositions exist for filtered year',
        (tester) async {
      // Empty entries
      await tester.pumpWidget(createWidgetUnderTest(
        initialEntries: const [],
        initialTabIndex: 3,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Dispositions (0)'), findsOneWidget);
      expect(find.byIcon(Icons.description_outlined), findsWidgets);
    });

    testWidgets('does not overflow on narrow mobile screens (360px width)',
        (tester) async {
      // Test constrained narrow screen width where overflow previously occurred (360x800)
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final now = DateTime.now();
      final sampleEntries = [
        Form8949Entry.create(
          id: 'test_nvda',
          description: '100 sh. NVDA NVIDIA Corporation',
          symbol: 'NVDA',
          assetType: 'stock',
          quantity: 100,
          acquiredDate: now.subtract(const Duration(days: 120)),
          soldDate: now.subtract(const Duration(days: 15)),
          proceeds: 15400.0,
          costBasis: 18200.0,
          adjustmentCode: 'W',
          adjustmentAmount: 2800.0,
        ),
      ];

      await tester.pumpWidget(createWidgetUnderTest(
        initialEntries: sampleEntries,
        initialTabIndex: 3,
      ));
      await tester.pumpAndSettle();

      // Ensure no layout overflow exceptions were caught
      expect(tester.takeException(), isNull);

      // Verify header and chip are present
      expect(find.text('Reconciliation Summary'), findsOneWidget);
      expect(find.text('Boxes A & D Covered'), findsOneWidget);

      // Scroll down to verify the wash sale disposition entry card
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Code W: +\$2,800.00'), findsOneWidget);
    });
  });
}
