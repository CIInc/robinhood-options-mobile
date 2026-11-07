import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
import 'package:robinhood_options_mobile/model/chart_selection_store.dart';
import 'package:robinhood_options_mobile/model/combo_order_store.dart';
import 'package:robinhood_options_mobile/model/dividend_store.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals_store.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals_selection_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_store.dart';
import 'package:robinhood_options_mobile/model/instrument_order_store.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/option_order_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';
import 'package:robinhood_options_mobile/model/trade_signal_notifications_store.dart';
import 'package:robinhood_options_mobile/model/trade_signals_provider.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/offline_sync_service.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';
import 'package:robinhood_options_mobile/widgets/trade_signals_page.dart';
import 'firebase_mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupFirebaseMocks();
  });

  List<SingleChildWidget> buildProviders({
    required BrokerageUserStore userStore,
    required TradeSignalsProvider tradeSignalsProvider,
    required FakeFirebaseAnalytics fakeAnalytics,
  }) {
    return [
      ChangeNotifierProvider.value(value: userStore),
      ChangeNotifierProvider.value(value: AccountStore()),
      ChangeNotifierProvider.value(value: PortfolioStore()),
      ChangeNotifierProvider<OfflineSyncService>.value(
          value: OfflineSyncService()),
      ChangeNotifierProvider.value(
          value: AgenticTradingProvider(analytics: fakeAnalytics)),
      ChangeNotifierProvider.value(value: TradeSignalNotificationsStore()),
      ChangeNotifierProvider.value(value: tradeSignalsProvider),
      ChangeNotifierProvider.value(value: QuoteStore()),
      ChangeNotifierProvider.value(value: InstrumentPositionStore()),
      ChangeNotifierProvider.value(value: InstrumentStore()),
      ChangeNotifierProvider.value(value: OptionPositionStore()),
      ChangeNotifierProvider.value(value: OptionOrderStore()),
      ChangeNotifierProvider.value(value: ComboOrderStore()),
      ChangeNotifierProvider.value(value: InstrumentOrderStore()),
      ChangeNotifierProvider.value(value: DividendStore()),
      ChangeNotifierProvider.value(value: InstrumentHistoricalsStore()),
      ChangeNotifierProvider.value(
          value: InstrumentHistoricalsSelectionStore()),
      ChangeNotifierProvider.value(value: ChartSelectionStore()),
    ];
  }

  testWidgets(
      'Clicking on Signal entry in demo account navigates to InstrumentWidget',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final fakeAnalytics = FakeFirebaseAnalytics();
    final observer = FirebaseAnalyticsObserver(analytics: fakeAnalytics);
    final demoUser =
        BrokerageUser(BrokerageSource.demo, "Demo Account", null, null);
    final userStore = BrokerageUserStore([demoUser], 0);

    final tradeSignalsProvider = TradeSignalsProvider();
    final now = DateTime.now();
    final signals = [
      {
        'symbol': 'AAPL',
        'signal': 'BUY',
        'timestamp': now,
        'multiIndicatorResult': {
          'signalStrength': 85,
          'indicators': {
            'priceMovement': {'signal': 'BUY', 'value': 225.50},
          },
        },
      },
    ];
    tradeSignalsProvider.setTradeSignalsForTesting(signals);

    await tester.pumpWidget(
      MultiProvider(
        providers: buildProviders(
          userStore: userStore,
          tradeSignalsProvider: tradeSignalsProvider,
          fakeAnalytics: fakeAnalytics,
        ),
        child: MaterialApp(
          home: TradeSignalsPage(
            user: null,
            userDocRef: null,
            brokerageUser: demoUser,
            service: DemoService(),
            analytics: fakeAnalytics,
            observer: observer,
            generativeService: GenerativeService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify AAPL signal card is rendered
    expect(find.text('AAPL'), findsOneWidget);

    // Tap on the AAPL signal card
    await tester.tap(find.text('AAPL'));
    await tester.pumpAndSettle();

    // Verify navigation to InstrumentWidget succeeded
    expect(find.byType(InstrumentWidget), findsOneWidget);
  });

  testWidgets(
      'Clicking on Signal entry with null service/brokerageUser in demo mode falls back to demo account and navigates',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final fakeAnalytics = FakeFirebaseAnalytics();
    final observer = FirebaseAnalyticsObserver(analytics: fakeAnalytics);
    final demoUser =
        BrokerageUser(BrokerageSource.demo, "Demo Account", null, null);
    final userStore = BrokerageUserStore([demoUser], 0);

    final tradeSignalsProvider = TradeSignalsProvider();
    final now = DateTime.now();
    final signals = [
      {
        'symbol': 'NVDA',
        'signal': 'BUY',
        'timestamp': now,
        'multiIndicatorResult': {
          'signalStrength': 90,
          'indicators': {
            'priceMovement': {'signal': 'BUY', 'value': 120.0},
          },
        },
      },
    ];
    tradeSignalsProvider.setTradeSignalsForTesting(signals);

    // Instantiate with null brokerageUser and null service to test fallback resolution
    await tester.pumpWidget(
      MultiProvider(
        providers: buildProviders(
          userStore: userStore,
          tradeSignalsProvider: tradeSignalsProvider,
          fakeAnalytics: fakeAnalytics,
        ),
        child: MaterialApp(
          home: TradeSignalsPage(
            user: null,
            userDocRef: null,
            brokerageUser: null,
            service: null,
            analytics: fakeAnalytics,
            observer: observer,
            generativeService: GenerativeService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify NVDA signal card is rendered
    expect(find.text('NVDA'), findsOneWidget);

    // Tap on the NVDA signal card
    await tester.tap(find.text('NVDA'));
    await tester.pumpAndSettle();

    // Verify navigation to InstrumentWidget succeeded
    expect(find.byType(InstrumentWidget), findsOneWidget);
  });
}
