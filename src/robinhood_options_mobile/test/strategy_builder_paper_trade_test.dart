import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/option_instrument_store.dart';
import 'package:robinhood_options_mobile/model/paper_trading_store.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';
import 'package:robinhood_options_mobile/model/option_chain.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/option_marketdata.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/strategy_builder_widget.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/enums.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/generative_provider.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'dart:collection';

// Mock Firestore to avoid initialization error
class FakeFirebaseFirestore extends Fake implements FirebaseFirestore {}

// Mock Service using Fake
class MockBrokerageService extends Fake implements IBrokerageService {
  Future<dynamic> getOptionChain(
      BrokerageUser user, String symbol, String strategy) async {
    return {
      'expiration_dates': ['2023-01-01'],
      'trade_value_multiplier': 100.0,
      'underlying_instruments': [
        {'id': 'test', 'symbol': 'TEST'}
      ]
    };
  }

  @override
  Future<OptionChain> getOptionChains(BrokerageUser user, String id) async {
    return OptionChain.fromJson({
      'id': 'chain_id',
      'symbol': 'TEST',
      'can_open_position': true,
      'cash_component': 0.0,
      'expiration_dates': ['2023-01-01'],
      'trade_value_multiplier': 100.0,
      'underlying_instruments': [
        {'id': 'test', 'symbol': 'TEST'}
      ],
      'min_ticks': {'above_tick': 0.05, 'below_tick': 0.01, 'cutoff_price': 0.0}
    });
  }

  @override
  Stream<List<OptionInstrument>> streamOptionInstruments(
      BrokerageUser user,
      OptionInstrumentStore store,
      Instrument instrument,
      String? expirationDates,
      String? type,
      {String? state = "active",
      bool includeMarketData = false}) {
    final option = OptionInstrument(
        'chain_id', // chainId
        'TEST', // chainSymbol
        DateTime.now(), // createdAt
        DateTime(2023, 1, 1), // expirationDate
        'opt_1', // id
        DateTime.now(), // issueDate
        const MinTicks(0.05, 0.01, 0.0), // minTicks
        'tradable', // rhsTradability
        'active', // state
        100.0, // strikePrice
        'tradable', // tradability
        'call', // type
        DateTime.now(), // updatedAt
        'http://url', // url
        null, // selloutDateTime
        'long_code', // longStrategyCode
        'short_code' // shortStrategyCode
        );
    // Mutate optionMarketData manually
    option.optionMarketData = OptionMarketData(
        1.0, // adjustedMarkPrice
        1.1, // askPrice
        10, // askSize
        0.9, // bidPrice
        10, // bidSize
        101.0, // breakEvenPrice
        1.2, // highPrice
        'opt_1', // instrument
        'opt_1', // instrumentId
        1.0, // lastTradePrice
        5, // lastTradeSize
        0.8, // lowPrice
        1.0, // markPrice
        100, // openInterest
        DateTime.now().subtract(const Duration(days: 1)), // previousCloseDate
        0.95, // previousClosePrice
        50, // volume
        'TEST', // symbol
        'TEST...C...', // occSymbol
        0.5, // chanceOfProfitLong
        0.4, // chanceOfProfitShort
        0.5, // delta
        0.1, // gamma
        0.2, // impliedVolatility
        0.01, // rho
        -0.05, // theta
        0.1, // vega
        null, // highFillRateBuyPrice
        null, // highFillRateSellPrice
        null, // lowFillRateBuyPrice
        null, // lowFillRateSellPrice
        DateTime.now() // updatedAt
        );

    return Stream.value([option]);
  }

  @override
  Future<Quote> getQuote(
      BrokerageUser user, QuoteStore store, String symbol) async {
    return Quote(
        adjustedPreviousClose: 100.0,
        askPrice: 100.1,
        askSize: 10,
        bidPrice: 99.9,
        bidSize: 10,
        lastExtendedHoursTradePrice: 100.0,
        lastTradePrice: 100.0,
        previousClose: 100.0,
        previousCloseDate: DateTime.now().subtract(const Duration(days: 1)),
        symbol: symbol,
        tradingHalted: false,
        hasTraded: true,
        updatedAt: DateTime.now(),
        instrument: 'test_id',
        lastTradePriceSource: 'consolidated',
        instrumentId: 'test_id');
  }
}

class MockAccountStore extends AccountStore {
  @override
  UnmodifiableListView<Account> get items => UnmodifiableListView([]);
}

class MockOptionPositionStore extends OptionPositionStore {
  @override
  UnmodifiableListView<OptionAggregatePosition> get items =>
      UnmodifiableListView([]);
}

// Mock Store extending the real one to keep ChangeNotifier behavior but overriding logic
class MockPaperTradingStore extends PaperTradingStore {
  bool complexStrategyExecuted = false;

  // Pass fake firestore to super to avoid Firebase.initializeApp check
  MockPaperTradingStore() : super(firestore: FakeFirebaseFirestore());

  double get portfolioValue => 100000.0;

  double get buyingPower => 100000.0;

  Future<void> initialize(User? user) async {
    // No-op for test
  }

  @override
  Future<void> executeComplexOptionStrategy({
    required double price,
    required double quantity,
    required String strategyName,
    required String direction,
    required List<Map<String, dynamic>> legsData,
  }) async {
    complexStrategyExecuted = true;
    notifyListeners();
  }
}

class FakeFirebaseAnalytics extends Fake implements FirebaseAnalytics {
  @override
  Future<void> logScreenView({
    String? screenClass,
    String? screenName,
    Map<String, Object?>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {}

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object?>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {}
}

class FakeFirebaseAnalyticsObserver extends Fake
    implements FirebaseAnalyticsObserver {}

class FakeGenerativeService extends Fake implements GenerativeService {}

class FakeOptionInstrumentStore extends Fake implements OptionInstrumentStore {}

void main() {
  testWidgets('StrategyBuilderWidget Paper Trade Toggle test',
      (WidgetTester tester) async {
    final mockService = MockBrokerageService();
    final mockPaperStore = MockPaperTradingStore();
    final mockAccountStore = MockAccountStore(); // Added
    final mockOptionPositionStore = MockOptionPositionStore();
    final mockOptionInstrumentStore =
        OptionInstrumentStore(); // Use real store as it is simple ChangeNotifier

    final user =
        BrokerageUser(BrokerageSource.robinhood, 'test_user', '123', null);

    final quote = Quote(
      adjustedPreviousClose: 100.0,
      askPrice: 100.1,
      askSize: 10,
      bidPrice: 99.9,
      bidSize: 10,
      lastExtendedHoursTradePrice: 100.0,
      lastTradePrice: 100.0,
      lastTradePriceSource: 'consolidated',
      previousClose: 100.0,
      previousCloseDate: DateTime.now().subtract(const Duration(days: 1)),
      symbol: 'TEST',
      tradingHalted: false,
      hasTraded: true,
      updatedAt: DateTime.now(),
      instrument: 'test_id',
      instrumentId: 'test_id',
    );

    final instrument = Instrument(
        id: 'test_id',
        url: 'http://test',
        quote: 'http://quote',
        fundamentals: 'http://fund',
        splits: 'http://splits',
        state: 'active',
        market: 'test_market',
        simpleName: 'Test',
        name: 'Test Corp',
        tradeable: true,
        tradability: 'tradable',
        rhsTradability: 'tradable',
        fractionalTradability: 'tradable',
        isSpac: false,
        isTest: false,
        ipoAccessSupportsDsp: false,
        symbol: 'TEST',
        bloombergUnique: '123',
        marginInitialRatio: 0.5,
        maintenanceRatio: 0.25,
        country: 'US',
        dayTradeRatio: 0.25,
        listDate: DateTime.now(),
        minTickSize: 0.01,
        type: 'stock',
        dateCreated: DateTime.now(),
        quoteObj: quote);

    final appUser = User(
      devices: [],
      dateCreated: DateTime.now(),
      brokerageUsers: [],
    );

    // Need screen size for layout
    tester.view.physicalSize =
        const Size(30000, 30000); // Huge screen to avoid overflows
    tester.view.devicePixelRatio = 3.0;

    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PaperTradingStore>.value(
              value: mockPaperStore),
          ChangeNotifierProvider<OptionInstrumentStore>.value(
              value: mockOptionInstrumentStore),
          ChangeNotifierProvider<OptionPositionStore>.value(
              value: mockOptionPositionStore),
          ChangeNotifierProvider<AccountStore>.value(
              value: mockAccountStore), // Added
          ChangeNotifierProvider<GenerativeProvider>(
              create: (_) => GenerativeProvider()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: StrategyBuilderWidget(
              user: user,
              service: mockService,
              instrument: instrument,
              analytics: FakeFirebaseAnalytics(),
              observer: FakeFirebaseAnalyticsObserver(),
              generativeService: FakeGenerativeService(),
              appUser: appUser,
              userDocRef: null,
            ),
          ),
        ),
      ),
    );

    // Initial pump
    await tester.pumpAndSettle();

    // 1. Open Strategy Picker
    final strategyTextFinder = find.text('Strategy');
    expect(strategyTextFinder, findsOneWidget);
    await tester.tap(strategyTextFinder);
    await tester.pumpAndSettle();

    // 2. Select "Single Option" strategy
    final longCallFinder = find.text('Single Option');
    // Expect at least one
    expect(longCallFinder, findsAtLeastNWidgets(1));
    await tester.tap(longCallFinder.first);
    await tester.pumpAndSettle();

    // 3. Select Leg
    // For single option, the leg name might be displayed or just "Tap to select option"
    final selectLegFinder = find.text('Tap to select option');
    expect(selectLegFinder, findsOneWidget);
    await tester.tap(selectLegFinder);
    await tester.pumpAndSettle();

    // 4. In Option Chain, select the option
    // It should render "$100" and "CALL" separately.
    // We mocked streamOptionInstruments to return a $100 call.
    final optionFinder = find.text('\$100'); // compact format
    if (optionFinder.evaluate().isNotEmpty) {
      await tester.tap(optionFinder.first);
    } else {
      // Debugging what is on screen
      debugPrint("Could not find Option to select. Dumping widget tree...");
      // debugDumpApp();
    }
    await tester.pumpAndSettle();

    // 5. Back in Strategy Builder, Review Order should be enabled.
    final reviewFinder = find.text('Review Order');
    expect(reviewFinder, findsOneWidget);
    await tester.tap(reviewFinder);
    await tester.pumpAndSettle();

    // 6. Verify "Paper Trade" switch exists
    final switchFinder = find.byType(Switch);
    final paperTradeTextFinder = find.text('Paper Trade');

    expect(paperTradeTextFinder, findsOneWidget);
    expect(switchFinder, findsAtLeastNWidgets(1));

    // Toggle the switch
    await tester.tap(switchFinder.first);
    await tester.pumpAndSettle();

    // Verify Value
    expect(tester.widget<Switch>(switchFinder.first).value, true);

    // Clean up
    addTearDown(tester.view.resetPhysicalSize);
  });
}
