import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_config.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
import 'package:robinhood_options_mobile/model/chart_selection_store.dart';
import 'package:robinhood_options_mobile/model/combo_order.dart';
import 'package:robinhood_options_mobile/model/combo_order_store.dart';
import 'package:robinhood_options_mobile/model/dividend_store.dart';
import 'package:robinhood_options_mobile/model/forex_holding_store.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_order.dart';
import 'package:robinhood_options_mobile/model/instrument_order_store.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/interest_store.dart';
import 'package:robinhood_options_mobile/model/option_event.dart';
import 'package:robinhood_options_mobile/model/option_event_store.dart';
import 'package:robinhood_options_mobile/model/option_order.dart';
import 'package:robinhood_options_mobile/model/option_order_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_store.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/history_widget.dart';
import 'package:robinhood_options_mobile/widgets/instrument_historical_positions_widget.dart';

import 'firebase_mocks.dart';

class LocalFakeAnalytics extends Fake implements FirebaseAnalytics {
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

class FakeAnalyticsObserver extends Fake implements FirebaseAnalyticsObserver {}

class FakeGenerativeService extends Fake implements GenerativeService {}

class MockAgenticTradingProvider extends ChangeNotifier
    implements AgenticTradingProvider {
  @override
  AgenticTradingConfig config = AgenticTradingConfig(
    strategyConfig: TradeStrategyConfig(),
    autoTradeEnabled: false,
  );

  @override
  bool showAutoTradingVisual = false;

  @override
  bool emergencyStopActivated = false;

  @override
  int dailyTradeCount = 0;

  @override
  int autoTradeCountdownSeconds = 300;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockBrokerageService extends Fake implements IBrokerageService {
  final List<InstrumentOrder> positionOrders;
  final List<OptionOrder> optionOrders;
  final List<OptionEvent> optionEvents;

  MockBrokerageService({
    this.positionOrders = const [],
    this.optionOrders = const [],
    this.optionEvents = const [],
  });

  @override
  Stream<List<InstrumentOrder>> streamPositionOrders(
    BrokerageUser user,
    InstrumentOrderStore orderStore,
    InstrumentStore instrumentStore, {
    DocumentReference? userDoc,
  }) =>
      Stream.value(positionOrders);

  @override
  Stream<List<OptionOrder>> streamOptionOrders(
    BrokerageUser user,
    OptionOrderStore orderStore, {
    DocumentReference? userDoc,
  }) =>
      Stream.value(optionOrders);

  @override
  Stream<List<OptionEvent>> streamOptionEvents(
    BrokerageUser user,
    OptionEventStore store, {
    int pageSize = 20,
    DocumentReference? userDoc,
  }) =>
      Stream.value(optionEvents);

  @override
  Stream<List<dynamic>> streamDividends(
    BrokerageUser user,
    InstrumentStore instrumentStore, {
    DocumentReference? userDoc,
  }) =>
      Stream.value([]);

  @override
  Stream<List<dynamic>> streamInterests(
    BrokerageUser user,
    InstrumentStore instrumentStore, {
    DocumentReference? userDoc,
  }) =>
      Stream.value([]);

  @override
  Stream<List<ComboOrder>> streamComboOrders(
    BrokerageUser user,
    ComboOrderStore store, {
    DocumentReference? userDoc,
    String? symbol,
    String? accountNumber,
  }) =>
      Stream.value([]);
}

InstrumentOrder _makeOrder({
  required String id,
  required String side,
  required double quantity,
  required double price,
  required DateTime date,
  String symbol = 'AAPL',
}) {
  final inst = Instrument.fromSchwabJson({
    'symbol': symbol,
    'description': '$symbol Inc.',
    'cusip': 'inst_$symbol',
  });

  final order = InstrumentOrder(
    id,
    'ref_$id',
    'https://api.robinhood.com/orders/$id/',
    'https://api.robinhood.com/accounts/ACC123/',
    'https://api.robinhood.com/positions/ACC123/inst_$symbol/',
    null,
    'https://api.robinhood.com/instruments/inst_$symbol/',
    'inst_$symbol',
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
  order.instrumentObj = inst;
  return order;
}

void main() {
  setUpAll(() async {
    await setupFirebaseMocks();
  });

  Widget buildWidget({
    required IBrokerageService service,
    BrokerageUser? user,
  }) {
    final brokerageUser =
        user ?? BrokerageUser(BrokerageSource.demo, 'demo_user', null, null);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => BrokerageUserStore([brokerageUser], 0)),
        ChangeNotifierProvider(create: (_) => AccountStore()),
        ChangeNotifierProvider(create: (_) => InstrumentPositionStore()),
        ChangeNotifierProvider(create: (_) => OptionPositionStore()),
        ChangeNotifierProvider(create: (_) => InstrumentOrderStore()),
        ChangeNotifierProvider(create: (_) => OptionOrderStore()),
        ChangeNotifierProvider(create: (_) => InstrumentStore()),
        ChangeNotifierProvider(create: (_) => OptionEventStore()),
        ChangeNotifierProvider(create: (_) => DividendStore()),
        ChangeNotifierProvider(create: (_) => ChartSelectionStore()),
        ChangeNotifierProvider(create: (_) => InterestStore()),
        ChangeNotifierProvider(create: (_) => ComboOrderStore()),
        ChangeNotifierProvider(create: (_) => PortfolioStore()),
        ChangeNotifierProvider(create: (_) => PortfolioHistoricalsStore()),
        ChangeNotifierProvider(create: (_) => ForexHoldingStore()),
        ChangeNotifierProvider<AgenticTradingProvider>(
            create: (_) => MockAgenticTradingProvider()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: HistoryPage(
            brokerageUser,
            service,
            analytics: LocalFakeAnalytics(),
            observer: FakeAnalyticsObserver(),
            generativeService: FakeGenerativeService(),
            user: null,
            userDoc: null,
          ),
        ),
      ),
    );
  }

  group('HistoryPage Past Positions Tab Tests', () {
    testWidgets('renders all 7 tabs with Past Positions as the 1st tab',
        (tester) async {
      final service = MockBrokerageService();

      await tester.pumpWidget(buildWidget(service: service));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(Tab, 'Past Positions'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Stocks'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Options'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Combos'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Dividends'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Interests'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Activity'), findsOneWidget);
    });

    testWidgets('shows empty state by default when there are no past positions',
        (tester) async {
      final service = MockBrokerageService(positionOrders: []);

      await tester.pumpWidget(buildWidget(service: service));
      await tester.pumpAndSettle();

      // Past Positions is 1st and active by default
      expect(find.text('No past positions found.'), findsOneWidget);
      expect(find.byType(InstrumentHistoricalPositionsWidget), findsNothing);
    });

    testWidgets(
        'renders closed round-trip cycles and metrics by default when positions exist',
        (tester) async {
      final now = DateTime.now();
      final d1 = now.subtract(const Duration(days: 10));
      final d2 = now.subtract(const Duration(days: 2));

      final orders = [
        _makeOrder(
          id: 'o1',
          side: 'buy',
          quantity: 10,
          price: 100,
          date: d1,
          symbol: 'AAPL',
        ),
        _makeOrder(
          id: 'o2',
          side: 'sell',
          quantity: 10,
          price: 130,
          date: d2,
          symbol: 'AAPL',
        ),
      ];

      final service = MockBrokerageService(positionOrders: orders);

      await tester.pumpWidget(buildWidget(service: service));
      await tester.pumpAndSettle();

      // Past Positions is active by default
      expect(find.text('AAPL Past Positions'), findsOneWidget);
      expect(find.text('Win Rate'), findsWidgets);
      expect(find.text('100% (1/1)'), findsWidgets);
      expect(find.textContaining(r'+$300.00'), findsWidgets);
      expect(find.byType(InstrumentHistoricalPositionsWidget), findsOneWidget);
    });

    testWidgets('filters past positions using date filter selection',
        (tester) async {
      // Order closed 90 days ago (outside 'Past Month')
      final now = DateTime.now();
      final d1 = now.subtract(const Duration(days: 100));
      final d2 = now.subtract(const Duration(days: 90));

      final orders = [
        _makeOrder(
          id: 'o1',
          side: 'buy',
          quantity: 10,
          price: 100,
          date: d1,
          symbol: 'TSLA',
        ),
        _makeOrder(
          id: 'o2',
          side: 'sell',
          quantity: 10,
          price: 150,
          date: d2,
          symbol: 'TSLA',
        ),
      ];

      final service = MockBrokerageService(positionOrders: orders);

      await tester.pumpWidget(buildWidget(service: service));
      await tester.pumpAndSettle();

      // Default filter is 'Past Month', so 90-day-old cycle should be filtered out
      expect(find.text('No past positions found.'), findsOneWidget);

      // Open the filter bottom sheet
      final filterButton = find.byIcon(Icons.filter_list);
      expect(filterButton, findsOneWidget);
      await tester.tap(filterButton);
      await tester.pumpAndSettle();

      // Select 'Past Year' chip
      final pastYearChip = find.widgetWithText(ChoiceChip, 'Past Year');
      expect(pastYearChip, findsOneWidget);
      await tester.ensureVisible(pastYearChip);
      await tester.pumpAndSettle();
      await tester.tap(pastYearChip);
      await tester.pumpAndSettle();

      // Tap 'Apply Filters' to dismiss bottom sheet and trigger rebuild
      final applyButton = find.text('Apply Filters');
      expect(applyButton, findsOneWidget);
      await tester.tap(applyButton);
      await tester.pumpAndSettle();

      // Now the cycle should be visible!
      expect(find.text('TSLA Past Positions'), findsOneWidget);
      expect(find.textContaining(r'+$500.00'), findsWidgets);
    });

    testWidgets('renders cleanly on narrow 320px viewport without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final now = DateTime.now();
      final orders = [
        _makeOrder(
          id: 'o1',
          side: 'buy',
          quantity: 100,
          price: 1000.50,
          date: now.subtract(const Duration(days: 10)),
          symbol: 'AAPL',
        ),
        _makeOrder(
          id: 'o2',
          side: 'sell',
          quantity: 100,
          price: 1414.85,
          date: now.subtract(const Duration(days: 2)),
          symbol: 'AAPL',
        ),
      ];

      final service = MockBrokerageService(positionOrders: orders);

      await tester.pumpWidget(buildWidget(service: service));
      await tester.pumpAndSettle();

      // Verify no overflow occurred
      expect(tester.takeException(), isNull);
      expect(find.text('Past Positions'), findsWidgets);
      expect(find.byIcon(Icons.filter_list), findsOneWidget);
    });
  });
}
