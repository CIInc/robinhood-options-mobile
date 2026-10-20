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
  int executedOrderCount = 0;

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
    ComboOrderStore comboOrderStore, {
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

Widget _buildWidget({required IBrokerageService service}) {
  final brokerageUser =
      BrokerageUser(BrokerageSource.demo, 'demo_user', null, null);
  final autoTradeProvider = MockAgenticTradingProvider();

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
      ChangeNotifierProvider<AgenticTradingProvider>.value(
          value: autoTradeProvider),
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

void main() {
  setUpAll(() async {
    await setupFirebaseMocks();
  });

  testWidgets(
      'History tab > Stocks sub-tab leading icon scales down 0.00692 without overflowing',
      (tester) async {
    final now = DateTime.now();
    final orders = [
      _makeOrder(
        id: 'order_fractional',
        side: 'buy',
        quantity: 0.00692,
        price: 150.0,
        date: now,
        symbol: 'NVDA',
      ),
    ];

    final service = MockBrokerageService(positionOrders: orders);

    await tester.pumpWidget(_buildWidget(service: service));
    await tester.pumpAndSettle();

    // Switch to 'Stocks' tab
    await tester.tap(find.widgetWithText(Tab, 'Stocks'));
    await tester.pumpAndSettle();

    // Verify NVDA order tile is displayed
    expect(find.text('NVDA'), findsOneWidget);
    expect(find.text('0.00692'), findsOneWidget);

    // Verify CircleAvatar and FittedBox bounds
    final circleAvatarFinder = find.byType(CircleAvatar);
    expect(circleAvatarFinder, findsOneWidget);

    final fittedBoxFinder = find.descendant(
      of: circleAvatarFinder,
      matching: find.byType(FittedBox),
    );
    expect(fittedBoxFinder, findsOneWidget);

    final avatarRect = tester.getRect(circleAvatarFinder);
    final fittedBoxRect = tester.getRect(fittedBoxFinder);

    // The FittedBox must be fully inside the CircleAvatar
    expect(fittedBoxRect.left, greaterThanOrEqualTo(avatarRect.left));
    expect(fittedBoxRect.right, lessThanOrEqualTo(avatarRect.right));
    expect(fittedBoxRect.top, greaterThanOrEqualTo(avatarRect.top));
    expect(fittedBoxRect.bottom, lessThanOrEqualTo(avatarRect.bottom));
  });
}
