import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/option_marketdata.dart';
import 'package:robinhood_options_mobile/model/paper_trading_store.dart';
import 'package:robinhood_options_mobile/widgets/trade_instrument_widget.dart';
import 'package:robinhood_options_mobile/widgets/trade_option_widget.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';
import 'package:robinhood_options_mobile/model/option_instrument_store.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
// import 'package:robinhood_options_mobile/model/user.dart' as model_user;
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:robinhood_options_mobile/model/order_template_store.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_config.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;

import 'package:robinhood_options_mobile/model/order_template.dart';

import 'package:firebase_core/firebase_core.dart';

import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';

// Mocks
class MockFirebasePlatform extends FirebasePlatform {
  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) {
    return FirebaseAppPlatform(
        name,
        const FirebaseOptions(
          apiKey: 'fakeApiKey',
          appId: 'fakeAppId',
          messagingSenderId: 'fakeSenderId',
          projectId: 'fakeProjectId',
        ));
  }

  @override
  Future<FirebaseAppPlatform> initializeApp(
      {String? name, FirebaseOptions? options}) async {
    return FirebaseAppPlatform(
      name ?? defaultFirebaseAppName,
      options ??
          const FirebaseOptions(
            apiKey: 'fakeApiKey',
            appId: 'fakeAppId',
            messagingSenderId: 'fakeSenderId',
            projectId: 'fakeProjectId',
          ),
    );
  }
}

class MockBrokerageService extends Fake implements IBrokerageService {}

class MockAgenticTradingProvider extends Fake
    implements AgenticTradingProvider {
  @override
  AgenticTradingConfig get config =>
      AgenticTradingConfig(strategyConfig: TradeStrategyConfig());
}

class MockOrderTemplateStore extends ChangeNotifier
    implements OrderTemplateStore {
  @override
  List<OrderTemplate> get templates => [];

  @override
  Future<void> loadTemplates(String userId) async {}

  @override
  Future<void> addTemplate(OrderTemplate template) async {}

  @override
  Future<void> deleteTemplate(String id) async {}

  @override
  OrderTemplate? getTemplateByName(String name) => null;
}

class MockAnalytics extends Fake implements FirebaseAnalytics {
  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object?>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {}

  @override
  Future<void> logScreenView({
    String? screenClass,
    String? screenName,
    AnalyticsCallOptions? callOptions,
    Map<String, Object?>? parameters,
  }) async {}
}

class MockObserver extends Fake implements FirebaseAnalyticsObserver {}

class FakePaperTradingStore extends ChangeNotifier
    implements PaperTradingStore {
  bool executedStock = false;
  bool executedOption = false;

  @override
  double get cashBalance => 100000.0;

  @override
  double get equity => 100000.0;

  @override
  List<Map<String, dynamic>> get history => [];

  @override
  bool get isLoading => false;

  @override
  List<OptionAggregatePosition> get optionPositions => [];

  @override
  List<InstrumentPosition> get positions => [];

  @override
  Future<void> executeStockOrder({
    required Instrument instrument,
    required double quantity,
    required double price,
    required String side,
    String? orderType,
  }) async {
    print("EXECUTED STOCK ORDER IN FAKE STORE - Side: $side, Qty: $quantity");
    executedStock = true;
    notifyListeners();
  }

  @override
  Future<void> executeOptionOrder({
    required OptionInstrument optionInstrument,
    required double quantity,
    required double price,
    required String side,
    String? orderType,
  }) async {
    print("EXECUTED OPTION ORDER IN FAKE STORE");
    executedOption = true;
    notifyListeners();
  }

  @override
  void setUser(auth.User? user) {}

  @override
  Future<void> resetAccount() async {}

  @override
  Future<void> executeComplexOptionStrategy({
    required double price,
    required double quantity,
    required String strategyName,
    required String direction,
    required List<Map<String, dynamic>> legsData,
  }) async {}

  @override
  Future<void> refreshQuotes(IBrokerageService service, QuoteStore quoteStore,
      OptionInstrumentStore optionInstrumentStore, BrokerageUser user) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Install the mock
  FirebasePlatform.instance = MockFirebasePlatform();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  Provider.debugCheckInvalidValueType = null;

  testWidgets('Full Paper Trading Test - Stock', (WidgetTester tester) async {
    final fakePaperStore = FakePaperTradingStore();
    final mockService = MockBrokerageService();
    final mockAnalytics = MockAnalytics();
    final mockObserver = MockObserver();

    final instrument = Instrument(
        id: 'id',
        url: 'https://api.robinhood.com/instruments/test/',
        quote: 'quote',
        fundamentals: 'fundamentals',
        splits: 'splits',
        state: 'active',
        market: 'market',
        name: 'Apple Inc.',
        tradeable: true,
        tradability: 'tradable',
        symbol: 'AAPL',
        bloombergUnique: 'bloombergUnique',
        country: 'US',
        type: 'stock',
        rhsTradability: 'tradable',
        fractionalTradability: 'tradable',
        isSpac: false,
        isTest: false,
        ipoAccessSupportsDsp: false,
        quoteObj: Quote(
            lastTradePrice: 150.0,
            lastExtendedHoursTradePrice: 150.0,
            adjustedPreviousClose: 145.0,
            symbol: 'AAPL',
            askSize: 100,
            bidSize: 100,
            tradingHalted: false,
            hasTraded: true,
            lastTradePriceSource: 'consolidated',
            instrument: 'https://api.robinhood.com/instruments/id/',
            instrumentId: 'id'),
        dateCreated: DateTime.now());

    /*
    final optionInstrument = OptionInstrument(
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
        'call', 
        DateTime.now(), 
        'https://api.robinhood.com/options/test/', 
        null, 
        'long', 
        'short'
    );
    */

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PaperTradingStore>.value(
              value: fakePaperStore),
          ChangeNotifierProvider<AccountStore>.value(value: AccountStore()),
          ChangeNotifierProvider<OrderTemplateStore>.value(
              value: MockOrderTemplateStore()),
          Provider<AgenticTradingProvider>.value(
              value: MockAgenticTradingProvider()),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => Scaffold(
                            body: TradeInstrumentWidget(
                              BrokerageUser.fromJson({'username': 'test'}),
                              mockService,
                              instrument: instrument,
                              analytics: mockAnalytics,
                              observer: mockObserver,
                            ),
                          ),
                        ),
                      );
                    },
                    child: const Text("Push Widget"),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text("Push Widget"));
    await tester.pumpAndSettle();

    // 1. Test Stock Trading
    expect(find.text('Paper Trade'), findsOneWidget);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect((tester.widget(find.byType(SwitchListTile)) as SwitchListTile).value,
        isTrue,
        reason: "Paper Trade switch should be ON");

    await tester.enterText(find.widgetWithText(TextFormField, 'Shares'), '10');
    await tester.pump();

    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();

    // Tap Preview Order to see the Slider
    await tester.tap(find.text('Preview Order'));
    await tester.pumpAndSettle();

    // Scroll down in Preview
    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('Preview Order'), findsNothing,
        reason: "Should have switched to Preview mode");

    expect(find.text('Slide to Buy'), findsOneWidget);
    //final sliderFinder = find.byIcon(Icons.arrow_forward);

    // Bypass gesture and call onConfirmed directly
    final dynamic sliderWidget = tester.widget(find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == 'SlideToConfirm'));
    sliderWidget.onConfirmed();

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Check for success or error
    if (find.textContaining("Error").evaluate().isNotEmpty) {
      debugPrint("TEST FAILURE: Found Error SnackBar");
    }

    expect(find.text("Paper Order placed successfully!"), findsOneWidget,
        reason: "Success snackbar not found (Stock)");

    expect(fakePaperStore.executedStock, isTrue);
  });

  testWidgets('Full Paper Trading Test - Option', (WidgetTester tester) async {
    final fakePaperStore = FakePaperTradingStore();
    final mockService = MockBrokerageService();
    final mockAnalytics = MockAnalytics();
    final mockObserver = MockObserver();

    final optionInstrument = OptionInstrument(
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
        'call',
        DateTime.now(),
        'https://api.robinhood.com/options/test/',
        null,
        'long',
        'short');

    // Assign market data so markPrice is available
    optionInstrument.optionMarketData = OptionMarketData(
        150.0,
        150.1,
        100,
        149.9,
        100,
        155.0,
        152.0,
        'url',
        'id',
        150.0,
        10,
        148.0,
        150.0,
        500,
        DateTime(2023, 1, 1),
        145.0,
        1000,
        'AAPL',
        'occ',
        0.5,
        0.5,
        0.5,
        0.1,
        0.2,
        0.01,
        -0.05,
        0.1,
        150.1,
        149.9,
        150.0,
        150.0,
        null);

    // 2. Test Option Trading
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PaperTradingStore>.value(
              value: fakePaperStore),
          ChangeNotifierProvider<AccountStore>.value(value: AccountStore()),
          ChangeNotifierProvider<OrderTemplateStore>.value(
              value: MockOrderTemplateStore()),
          Provider<AgenticTradingProvider>.value(
              value: MockAgenticTradingProvider()),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => Scaffold(
                            body: TradeOptionWidget(
                              BrokerageUser.fromJson({'username': 'test'}),
                              mockService,
                              optionInstrument: optionInstrument,
                              analytics: mockAnalytics,
                              observer: mockObserver,
                            ),
                          ),
                        ),
                      );
                    },
                    child: const Text("Push Option Widget"),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text("Push Option Widget"));
    await tester.pumpAndSettle();

    expect(find.text('Paper Trade'), findsOneWidget);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Contracts'), '1');
    await tester.pump();

    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();

    // Tap Preview Order
    await tester.tap(find.text('Preview Order'));
    await tester.pumpAndSettle();

    // Scroll down in Preview
    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('Slide to Buy'), findsOneWidget);
    //final optionSliderFinder = find.byIcon(Icons.arrow_forward);
    // Bypass gesture
    final dynamic optionSliderWidget = tester.widget(find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == 'SlideToConfirm'));
    optionSliderWidget.onConfirmed();

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text("Paper Order placed successfully!"), findsOneWidget,
        reason: "Success snackbar not found (Option)");

    expect(fakePaperStore.executedOption, isTrue);
  });
}
