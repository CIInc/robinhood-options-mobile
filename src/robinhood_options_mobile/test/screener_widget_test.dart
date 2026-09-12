import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/screener_preset.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/widgets/screener_widget.dart';
import 'firebase_mocks.dart';

class FakeFirebaseAnalytics extends Fake implements FirebaseAnalytics {
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
  setUpAll(() async {
    await setupFirebaseMocks();
  });

  testWidgets(
      'ScreenerWidget with initialPreset renders Active Preset Banner and details prominently',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final brokerageUser =
        BrokerageUser(BrokerageSource.demo, 'demo_user', null, null);
    final service = DemoService();

    const preset = RobinhoodScreenerPreset(
      id: '834ca4dc-7d82-4cfc-b95b-ccd9d85db5c0',
      name: 'Highest dividend yield',
      description: 'Stocks with dividend yield above 5%',
      category: 'Dividends',
      iconEmoji: '💡',
      sortBy: 'dividend_yield',
      sortDirection: 'DESC',
      itemCount: 42,
      sampleSymbols: ['JNJ', 'PG', 'KO'],
      criteria: [
        ScreenerPresetCriterion(
          field: 'dividend_yield',
          operator: 'gte',
          minValue: 5.0,
        ),
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<InstrumentStore>(
            create: (_) => InstrumentStore(),
          ),
        ],
        child: MaterialApp(
          home: ScreenerWidget(
            brokerageUser,
            service,
            analytics: FakeFirebaseAnalytics(),
            observer: FakeFirebaseAnalyticsObserver(),
            generativeService: FakeGenerativeService(),
            user: null,
            userDocRef: null,
            initialPreset: preset,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify AppBar shows active preset title and subtitle
    expect(find.text('Highest dividend yield'), findsWidgets);
    expect(find.text('Curated Screener • Dividends'), findsOneWidget);

    // Verify Active Preset Hero Card
    expect(find.text('ACTIVE CURATED SCREENER: DIVIDENDS'), findsOneWidget);
    expect(find.text('Stocks with dividend yield above 5%'), findsOneWidget);
    expect(find.text('Div Yield ≥ 5.0%'), findsWidgets);
    expect(find.text('Switch'), findsOneWidget);

    // Verify collapsed filter bar is shown initially to conserve screen space
    expect(find.textContaining('Filter Criteria'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);

    // Tap "Edit" to expand filters
    await tester.tap(find.text('Edit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify full filters are now expanded
    expect(find.text('Quick Presets'), findsOneWidget);
    expect(find.text('High Dividend'), findsOneWidget);
    expect(find.text('Sector'), findsOneWidget);
  });

  testWidgets('ScreenerWidget allows toggling between Grid view and List view',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final brokerageUser =
        BrokerageUser(BrokerageSource.demo, 'demo_user', null, null);
    final service = DemoService();

    final testInstruments = List.generate(
      120,
      (i) => Instrument(
        id: 'inst_$i',
        url: 'https://api.robinhood.com/instruments/inst_$i/',
        quote: 'https://api.robinhood.com/quotes/SYM$i/',
        fundamentals: 'https://api.robinhood.com/fundamentals/SYM$i/',
        splits: 'https://api.robinhood.com/instruments/inst_$i/splits/',
        state: 'active',
        market: 'https://api.robinhood.com/markets/XNAS/',
        name: 'Company $i Inc.',
        simpleName: 'Company $i',
        symbol: 'SYM$i',
        bloombergUnique: 'EQ$i',
        country: 'US',
        type: 'stock',
        tradeable: true,
        tradability: 'tradable',
        rhsTradability: 'tradable',
        fractionalTradability: 'tradable',
        isSpac: false,
        isTest: false,
        ipoAccessSupportsDsp: false,
        dateCreated: DateTime(2020, 1, 1),
      ),
    );

    const preset = RobinhoodScreenerPreset(
      id: 'daily-jumps',
      name: 'Daily price jumps',
      description: 'Stocks with biggest price increases',
      category: 'Movers',
    );

    final screenerKey = GlobalKey();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<InstrumentStore>(
            create: (_) => InstrumentStore(),
          ),
        ],
        child: MaterialApp(
          home: ScreenerWidget(
            brokerageUser,
            service,
            key: screenerKey,
            analytics: FakeFirebaseAnalytics(),
            observer: FakeFirebaseAnalyticsObserver(),
            generativeService: FakeGenerativeService(),
            user: null,
            userDocRef: null,
            initialPreset: preset,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Directly supply results to test rendering of 120+ items
    final state = tester.state(find.byType(ScreenerWidget)) as dynamic;
    state.setState(() {
      state.screenerResults = testInstruments;
      state.sortedResults = testInstruments;
      state.screenerLoading = false;
    });

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify Sticky Results Header displays result count and active preset badge
    expect(find.text('Results (120)'), findsOneWidget);
    expect(find.text('Daily price jumps'), findsWidgets);

    // Verify Grid view icon toggle exists
    expect(find.byIcon(Icons.view_list), findsOneWidget);

    // Switch to List view
    await tester.tap(find.byIcon(Icons.view_list));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify List view toggle now shows Grid view icon
    expect(find.byIcon(Icons.grid_view), findsOneWidget);
    expect(find.text('Results (120)'), findsOneWidget);
  });
}
