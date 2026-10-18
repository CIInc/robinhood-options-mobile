import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
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
    required InstrumentPositionStore instrumentStore,
    int initialTabIndex = 2,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: instrumentStore),
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
          initialTabIndex: initialTabIndex,
        ),
      ),
    );
  }

  group('TaxOptimizationWidget Capital Gains Tab Tests', () {
    testWidgets('renders all 3 tabs including Capital Gains', (tester) async {
      final store = InstrumentPositionStore();

      await tester.pumpWidget(createWidgetUnderTest(
        instrumentStore: store,
        initialTabIndex: 0,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Loss Harvesting'), findsOneWidget);
      expect(find.text('Wash Sales'), findsOneWidget);
      expect(find.text('Capital Gains'), findsOneWidget);
    });

    testWidgets(
        'renders Capital Gains summary card with Short-Term and Long-Term breakdown',
        (tester) async {
      final store = InstrumentPositionStore();
      final now = DateTime.now();

      // Long term position: created 400 days ago
      final inst1 = Instrument(
        id: 'inst_1',
        url: '',
        quote: '',
        fundamentals: '',
        splits: '',
        state: '',
        market: '',
        name: 'Apple Inc.',
        tradeable: true,
        tradability: '',
        symbol: 'AAPL',
        bloombergUnique: '',
        country: '',
        type: 'stock',
        rhsTradability: '',
        fractionalTradability: '',
        isSpac: false,
        isTest: false,
        ipoAccessSupportsDsp: false,
        dateCreated: DateTime(2020, 1, 1),
      );
      inst1.quoteObj = Quote(
        symbol: 'AAPL',
        askPrice: 200.0,
        askSize: 100,
        bidPrice: 200.0,
        bidSize: 100,
        lastTradePrice: 200.0,
        lastExtendedHoursTradePrice: null,
        previousClose: 195.0,
        adjustedPreviousClose: 195.0,
        previousCloseDate: null,
        tradingHalted: false,
        hasTraded: true,
        lastTradePriceSource: '',
        updatedAt: now,
        instrument: '',
        instrumentId: 'inst_1',
      );

      final pos1 = InstrumentPosition(
        '',
        '/instruments/inst_1/',
        '',
        'acc_1',
        150.0,
        150.0,
        10.0, // gain: $500
        0,
        0,
        10,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        false,
        now,
        now.subtract(const Duration(days: 400)),
      );
      pos1.instrumentObj = inst1;
      store.addOrUpdate(pos1);

      // Approaching long term position: created 330 days ago (~36 days left)
      final inst2 = Instrument(
        id: 'inst_2',
        url: '',
        quote: '',
        fundamentals: '',
        splits: '',
        state: '',
        market: '',
        name: 'NVIDIA Corp',
        tradeable: true,
        tradability: '',
        symbol: 'NVDA',
        bloombergUnique: '',
        country: '',
        type: 'stock',
        rhsTradability: '',
        fractionalTradability: '',
        isSpac: false,
        isTest: false,
        ipoAccessSupportsDsp: false,
        dateCreated: DateTime(2020, 1, 1),
      );
      inst2.quoteObj = Quote(
        symbol: 'NVDA',
        askPrice: 130.0,
        askSize: 100,
        bidPrice: 130.0,
        bidSize: 100,
        lastTradePrice: 130.0,
        lastExtendedHoursTradePrice: null,
        previousClose: 125.0,
        adjustedPreviousClose: 125.0,
        previousCloseDate: null,
        tradingHalted: false,
        hasTraded: true,
        lastTradePriceSource: '',
        updatedAt: now,
        instrument: '',
        instrumentId: 'inst_2',
      );

      final pos2 = InstrumentPosition(
        '',
        '/instruments/inst_2/',
        '',
        'acc_1',
        100.0,
        100.0,
        20.0, // gain: $600
        0,
        0,
        20,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        false,
        now,
        now.subtract(const Duration(days: 330)),
      );
      pos2.instrumentObj = inst2;
      store.addOrUpdate(pos2);

      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest(
        instrumentStore: store,
        initialTabIndex: 2,
      ));
      await tester.pumpAndSettle();

      // Summary Card
      expect(find.text('Capital Gains & Tax Projection'), findsOneWidget);
      expect(find.text('Short-Term'), findsOneWidget);
      expect(find.text('Long-Term'), findsOneWidget);
      expect(find.text('Total Projected Tax Liability:'), findsOneWidget);

      // Approaching banner
      expect(find.textContaining('nearing Long-Term status'), findsOneWidget);
      expect(find.textContaining('NVDA:'), findsOneWidget);

      // Position Cards
      expect(find.text('Apple Inc.'), findsOneWidget);
      expect(find.text('NVIDIA Corp'), findsOneWidget);
      expect(find.textContaining('Long-Term ('), findsWidgets);
      expect(find.textContaining('to Long-Term'), findsWidgets);
    });

    testWidgets('filters positions when FilterChips are tapped',
        (tester) async {
      final store = InstrumentPositionStore();
      final now = DateTime.now();

      final inst = Instrument(
        id: 'inst_1',
        url: '',
        quote: '',
        fundamentals: '',
        splits: '',
        state: '',
        market: '',
        name: 'Apple Inc.',
        tradeable: true,
        tradability: '',
        symbol: 'AAPL',
        bloombergUnique: '',
        country: '',
        type: 'stock',
        rhsTradability: '',
        fractionalTradability: '',
        isSpac: false,
        isTest: false,
        ipoAccessSupportsDsp: false,
        dateCreated: DateTime(2020, 1, 1),
      );
      inst.quoteObj = Quote(
        symbol: 'AAPL',
        askPrice: 200.0,
        askSize: 100,
        bidPrice: 200.0,
        bidSize: 100,
        lastTradePrice: 200.0,
        lastExtendedHoursTradePrice: null,
        previousClose: 195.0,
        adjustedPreviousClose: 195.0,
        previousCloseDate: null,
        tradingHalted: false,
        hasTraded: true,
        lastTradePriceSource: '',
        updatedAt: now,
        instrument: '',
        instrumentId: 'inst_1',
      );

      final pos = InstrumentPosition(
        '',
        '/instruments/inst_1/',
        '',
        'acc_1',
        150.0,
        150.0,
        10.0,
        0,
        0,
        10,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        false,
        now,
        now.subtract(const Duration(days: 400)), // Long-Term
      );
      pos.instrumentObj = inst;
      store.addOrUpdate(pos);

      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest(
        instrumentStore: store,
        initialTabIndex: 2,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Apple Inc.'), findsOneWidget);

      // Tap 'Short-Term (0)' filter
      await tester.tap(find.text('Short-Term (0)'));
      await tester.pumpAndSettle();

      expect(find.text('No positions found'), findsOneWidget);

      // Tap 'Long-Term (1)' filter
      await tester.tap(find.text('Long-Term (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Apple Inc.'), findsOneWidget);
    });

    testWidgets('opens tax bracket configuration dialog', (tester) async {
      final store = InstrumentPositionStore();

      await tester.pumpWidget(createWidgetUnderTest(
        instrumentStore: store,
        initialTabIndex: 2,
      ));
      await tester.pumpAndSettle();

      // Tap Tune button
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      expect(find.text('Estimated Tax Brackets'), findsOneWidget);
      expect(find.textContaining('Short-Term Rate:'), findsOneWidget);
      expect(find.textContaining('Long-Term Rate:'), findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Estimated Tax Brackets'), findsNothing);
    });
  });
}
