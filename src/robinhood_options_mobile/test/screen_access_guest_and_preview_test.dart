import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/paper_trading_store.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';
import 'package:robinhood_options_mobile/model/trade_signal_notifications_store.dart';
import 'package:robinhood_options_mobile/model/trade_signals_provider.dart';
import 'package:robinhood_options_mobile/model/user.dart' as app_user;
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/offline_sync_service.dart';
import 'package:robinhood_options_mobile/widgets/trade_signals_page.dart';
import 'package:robinhood_options_mobile/widgets/welcome_widget.dart';
import 'firebase_mocks.dart';

class _UnusedFirestore extends Fake implements FirebaseFirestore {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Instrument makeInstrument({String symbol = 'AAPL'}) {
    return Instrument(
        id: 'id_$symbol',
        url: 'https://api.robinhood.com/instruments/$symbol/',
        quote: 'quote',
        fundamentals: 'fundamentals',
        splits: 'splits',
        state: 'active',
        market: 'market',
        name: '$symbol Inc.',
        tradeable: true,
        tradability: 'tradable',
        symbol: symbol,
        bloombergUnique: 'bloombergUnique',
        country: 'US',
        type: 'stock',
        rhsTradability: 'tradable',
        fractionalTradability: 'tradable',
        isSpac: false,
        isTest: false,
        ipoAccessSupportsDsp: false,
        dateCreated: DateTime.now());
  }

  PaperTradingStore makeStore() => PaperTradingStore(
      firestore: _UnusedFirestore(), isMarketOpen: () => true);

  group('Guest Paper Trading Local Persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('saves and restores guest paper trading state to SharedPreferences',
        () async {
      final store1 = makeStore();
      await store1.ensureLoaded(null);

      expect(store1.cashBalance, 100000.0);
      expect(store1.positions, isEmpty);

      // Submit an order in guest mode
      await store1.submitStockOrder(
        instrument: makeInstrument(symbol: 'TSLA'),
        quantity: 5,
        side: 'buy',
        orderType: 'market',
        marketPrice: 200.0,
      );

      expect(store1.positions.length, 1);
      expect(store1.positions.first.instrumentObj?.symbol, 'TSLA');
      expect(store1.positions.first.quantity, 5);
      expect(store1.cashBalance, 100000.0 - 1000.0);

      // Verify second store instance loads the persisted guest account
      final store2 = makeStore();
      await store2.ensureLoaded(null);

      expect(store2.cashBalance, 99000.0);
      expect(store2.positions.length, 1);
      expect(store2.positions.first.instrumentObj?.symbol, 'TSLA');
      expect(store2.positions.first.quantity, 5);
      expect(store2.history.length, 1);
    });

    test('resetAccount cleans guest local storage state', () async {
      final store = makeStore();
      await store.ensureLoaded(null);

      await store.submitStockOrder(
        instrument: makeInstrument(symbol: 'NVDA'),
        quantity: 10,
        side: 'buy',
        orderType: 'market',
        marketPrice: 120.0,
      );
      expect(store.positions.length, 1);

      await store.resetAccount(initialCapital: 50000.0);
      expect(store.cashBalance, 50000.0);
      expect(store.positions, isEmpty);

      // Restored state in new store should reflect reset
      final restoredStore = makeStore();
      await restoredStore.ensureLoaded(null);
      expect(restoredStore.cashBalance, 50000.0);
      expect(restoredStore.positions, isEmpty);
    });
  });

  group('WelcomeWidget Demo Mode Action', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets(
        'renders Explore Demo / Paper Mode button and triggers callback',
        (tester) async {
      bool demoTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WelcomeWidget(
              onLogin: () {},
              onExploreDemo: () {
                demoTriggered = true;
              },
            ),
          ),
        ),
      );

      final demoButtonFinder = find.text('Explore Demo / Paper Mode');
      expect(demoButtonFinder, findsOneWidget);

      await tester.ensureVisible(demoButtonFinder);
      await tester.tap(demoButtonFinder);
      await tester.pumpAndSettle();

      expect(demoTriggered, isTrue);
    });

    testWidgets('Explore Demo callback adds demo user to BrokerageUserStore',
        (tester) async {
      final userStore = BrokerageUserStore([], -1);

      await tester.pumpWidget(
        ChangeNotifierProvider<BrokerageUserStore>.value(
          value: userStore,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return WelcomeWidget(
                    onLogin: () {},
                    onExploreDemo: () async {
                      final user = BrokerageUser(
                          BrokerageSource.demo, "Demo Account", null, null);
                      final store = Provider.of<BrokerageUserStore>(context,
                          listen: false);
                      store.addOrUpdate(user);
                      store.setCurrentUserIndex(store.items.indexOf(user));
                      await store.save();
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(userStore.items, isEmpty);

      final demoButtonFinder = find.text('Explore Demo / Paper Mode');
      await tester.ensureVisible(demoButtonFinder);
      await tester.tap(demoButtonFinder);
      await tester.pumpAndSettle();

      expect(userStore.items.length, 1);
      expect(userStore.currentUser?.source, BrokerageSource.demo);
      expect(userStore.currentUser?.userName, "Demo Account");
    });
  });

  group('TradeSignalsPage Freemium Preview', () {
    setUpAll(() async {
      await setupFirebaseMocks();
    });

    testWidgets(
        'renders RealizeAlpha Pro Preview banner for guests instead of lock screen',
        (tester) async {
      final fakeAnalytics = FakeFirebaseAnalytics();
      final observer = FirebaseAnalyticsObserver(analytics: fakeAnalytics);
      final notificationsStore = TradeSignalNotificationsStore();
      final tradeSignalsProvider = TradeSignalsProvider();
      final quoteStore = QuoteStore();
      final positionStore = InstrumentPositionStore();

      final userStore = BrokerageUserStore([], -1);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: userStore),
            ChangeNotifierProvider.value(value: AccountStore()),
            ChangeNotifierProvider<OfflineSyncService>.value(
                value: OfflineSyncService()),
            ChangeNotifierProvider.value(
                value: AgenticTradingProvider(analytics: fakeAnalytics)),
            ChangeNotifierProvider.value(value: notificationsStore),
            ChangeNotifierProvider.value(value: tradeSignalsProvider),
            ChangeNotifierProvider.value(value: quoteStore),
            ChangeNotifierProvider.value(value: positionStore),
          ],
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
      await tester.pump();

      expect(find.text('RealizeAlpha Pro Preview'), findsOneWidget);
      expect(find.text('PREVIEW'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsNothing);
      expect(find.text('Sign in to access Trade Signals'), findsNothing);
    });

    testWidgets(
        'renders RealizeAlpha Pro Preview banner with Unlock Pro button for signed-in unsubscribed user',
        (tester) async {
      final fakeAnalytics = FakeFirebaseAnalytics();
      final observer = FirebaseAnalyticsObserver(analytics: fakeAnalytics);
      final notificationsStore = TradeSignalNotificationsStore();
      final tradeSignalsProvider = TradeSignalsProvider();
      final quoteStore = QuoteStore();
      final positionStore = InstrumentPositionStore();
      final userStore = BrokerageUserStore([], -1);

      final unsubscribedUser = app_user.User(
        name: 'Test User',
        email: 'test@example.com',
        devices: [],
        dateCreated: DateTime.now(),
        brokerageUsers: [],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: userStore),
            ChangeNotifierProvider.value(value: AccountStore()),
            ChangeNotifierProvider<OfflineSyncService>.value(
                value: OfflineSyncService()),
            ChangeNotifierProvider.value(
                value: AgenticTradingProvider(analytics: fakeAnalytics)),
            ChangeNotifierProvider.value(value: notificationsStore),
            ChangeNotifierProvider.value(value: tradeSignalsProvider),
            ChangeNotifierProvider.value(value: quoteStore),
            ChangeNotifierProvider.value(value: positionStore),
          ],
          child: MaterialApp(
            home: TradeSignalsPage(
              user: unsubscribedUser,
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
      await tester.pump();

      expect(find.text('RealizeAlpha Pro Preview'), findsOneWidget);
      expect(find.text('PREVIEW'), findsOneWidget);
      expect(find.text('Unlock Pro'), findsOneWidget);
      expect(find.text('Sign In'), findsNothing);
    });

    testWidgets(
        'renders RealizeAlpha Pro Preview banner without overflow on narrow screens',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeAnalytics = FakeFirebaseAnalytics();
      final observer = FirebaseAnalyticsObserver(analytics: fakeAnalytics);
      final notificationsStore = TradeSignalNotificationsStore();
      final tradeSignalsProvider = TradeSignalsProvider();
      final quoteStore = QuoteStore();
      final positionStore = InstrumentPositionStore();
      final userStore = BrokerageUserStore([], -1);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: userStore),
            ChangeNotifierProvider.value(value: AccountStore()),
            ChangeNotifierProvider<OfflineSyncService>.value(
                value: OfflineSyncService()),
            ChangeNotifierProvider.value(
                value: AgenticTradingProvider(analytics: fakeAnalytics)),
            ChangeNotifierProvider.value(value: notificationsStore),
            ChangeNotifierProvider.value(value: tradeSignalsProvider),
            ChangeNotifierProvider.value(value: quoteStore),
            ChangeNotifierProvider.value(value: positionStore),
          ],
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
      await tester.pump();

      expect(find.text('RealizeAlpha Pro Preview'), findsOneWidget);
      expect(find.text('PREVIEW'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'restricts signals to 3 samples and shows Pro locked card for non-subscribers',
        (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final fakeAnalytics = FakeFirebaseAnalytics();
      final observer = FirebaseAnalyticsObserver(analytics: fakeAnalytics);
      final notificationsStore = TradeSignalNotificationsStore();
      final tradeSignalsProvider = TradeSignalsProvider();
      final quoteStore = QuoteStore();
      final positionStore = InstrumentPositionStore();
      final userStore = BrokerageUserStore([], -1);

      final now = DateTime.now().millisecondsSinceEpoch;
      final signals = [
        {
          'symbol': 'AAPL',
          'signal': 'BUY',
          'timestamp': now,
          'multiIndicatorResult': {
            'signalStrength': 85,
            'indicators': {
              'priceMovement': {'signal': 'BUY', 'value': 150.0},
              'volume': {'signal': 'BUY', 'value': 2500000},
              'momentum': {'signal': 'BUY', 'value': 65.0},
              'macd': {'signal': 'BUY', 'value': 1.25},
              'bollingerBands': {'signal': 'BUY', 'value': 148.0},
              'stochastic': {'signal': 'BUY', 'value': 70.0},
              'vwap': {'signal': 'BUY', 'value': 152.0},
            },
          },
        },
        {
          'symbol': 'MSFT',
          'signal': 'BUY',
          'timestamp': now,
          'multiIndicatorResult': {
            'signalStrength': 80,
            'indicators': {
              'priceMovement': {'signal': 'BUY', 'value': 400.0},
            },
          },
        },
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
        {
          'symbol': 'AMZN',
          'signal': 'SELL',
          'timestamp': now,
          'multiIndicatorResult': {
            'signalStrength': 75,
            'indicators': {
              'priceMovement': {'signal': 'SELL', 'value': 180.0},
            },
          },
        },
        {
          'symbol': 'GOOG',
          'signal': 'HOLD',
          'timestamp': now,
          'multiIndicatorResult': {
            'signalStrength': 50,
            'indicators': {
              'priceMovement': {'signal': 'HOLD', 'value': 170.0},
            },
          },
        },
      ];
      tradeSignalsProvider.setTradeSignalsForTesting(signals);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: userStore),
            ChangeNotifierProvider.value(value: AccountStore()),
            ChangeNotifierProvider<OfflineSyncService>.value(
                value: OfflineSyncService()),
            ChangeNotifierProvider.value(
                value: AgenticTradingProvider(analytics: fakeAnalytics)),
            ChangeNotifierProvider.value(value: notificationsStore),
            ChangeNotifierProvider.value(value: tradeSignalsProvider),
            ChangeNotifierProvider.value(value: quoteStore),
            ChangeNotifierProvider.value(value: positionStore),
          ],
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
      await tester.pump();

      // Top 3 sample signals should be rendered
      expect(find.text('AAPL'), findsOneWidget);
      expect(find.text('MSFT'), findsOneWidget);
      expect(find.text('NVDA'), findsOneWidget);

      // Remaining signals should NOT be rendered (preventing Pro value leakage)
      expect(find.text('AMZN'), findsNothing);
      expect(find.text('GOOG'), findsNothing);

      // Sample badges are present on displayed signals
      expect(find.text('SAMPLE'), findsNWidgets(3));

      // Pro locked teaser card is displayed
      expect(find.text('Unlock 2+ More Real-Time Signals'), findsOneWidget);
      expect(find.text('Sign In to Unlock Pro'), findsOneWidget);

      // Pro indicators chip is shown on AAPL (which has 7 indicators > 4)
      expect(find.text('+3 Pro Indicators'), findsOneWidget);
    });

    testWidgets(
        'renders all signals and all indicators for subscribed Pro users',
        (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeAnalytics = FakeFirebaseAnalytics();
      final observer = FirebaseAnalyticsObserver(analytics: fakeAnalytics);
      final notificationsStore = TradeSignalNotificationsStore();
      final tradeSignalsProvider = TradeSignalsProvider();
      final quoteStore = QuoteStore();
      final positionStore = InstrumentPositionStore();
      final userStore = BrokerageUserStore([], -1);

      final now = DateTime.now().millisecondsSinceEpoch;
      final signals = [
        {
          'symbol': 'AAPL',
          'signal': 'BUY',
          'timestamp': now,
          'multiIndicatorResult': {
            'signalStrength': 85,
            'indicators': {
              'priceMovement': {'signal': 'BUY', 'value': 150.0},
              'volume': {'signal': 'BUY', 'value': 2500000},
              'momentum': {'signal': 'BUY', 'value': 65.0},
              'macd': {'signal': 'BUY', 'value': 1.25},
              'bollingerBands': {'signal': 'BUY', 'value': 148.0},
              'stochastic': {'signal': 'BUY', 'value': 70.0},
              'vwap': {'signal': 'BUY', 'value': 152.0},
            },
          },
        },
        {
          'symbol': 'MSFT',
          'signal': 'BUY',
          'timestamp': now,
          'multiIndicatorResult': {
            'signalStrength': 80,
            'indicators': {
              'priceMovement': {'signal': 'BUY', 'value': 400.0},
            },
          },
        },
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
        {
          'symbol': 'AMZN',
          'signal': 'SELL',
          'timestamp': now,
          'multiIndicatorResult': {
            'signalStrength': 75,
            'indicators': {
              'priceMovement': {'signal': 'SELL', 'value': 180.0},
            },
          },
        },
        {
          'symbol': 'GOOG',
          'signal': 'HOLD',
          'timestamp': now,
          'multiIndicatorResult': {
            'signalStrength': 50,
            'indicators': {
              'priceMovement': {'signal': 'HOLD', 'value': 170.0},
            },
          },
        },
      ];
      tradeSignalsProvider.setTradeSignalsForTesting(signals);

      // User with active subscription (subscriptionExpiration in the future)
      final subscribedUser = app_user.User(
        name: 'Pro User',
        email: 'pro@example.com',
        devices: [],
        dateCreated: DateTime.now(),
        brokerageUsers: [],
        subscriptionStatus: 'active',
        subscriptionExpiryDate: DateTime.now().add(const Duration(days: 30)),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: userStore),
            ChangeNotifierProvider.value(value: AccountStore()),
            ChangeNotifierProvider<OfflineSyncService>.value(
                value: OfflineSyncService()),
            ChangeNotifierProvider.value(
                value: AgenticTradingProvider(analytics: fakeAnalytics)),
            ChangeNotifierProvider.value(value: notificationsStore),
            ChangeNotifierProvider.value(value: tradeSignalsProvider),
            ChangeNotifierProvider.value(value: quoteStore),
            ChangeNotifierProvider.value(value: positionStore),
          ],
          child: MaterialApp(
            home: TradeSignalsPage(
              user: subscribedUser,
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
      await tester.pump();

      // All 5 signals should be rendered for Pro user
      expect(find.text('AAPL'), findsOneWidget);
      expect(find.text('MSFT'), findsOneWidget);
      expect(find.text('NVDA'), findsOneWidget);
      expect(find.text('AMZN'), findsOneWidget);
      expect(find.text('GOOG'), findsOneWidget);

      // No sample badges for Pro user
      expect(find.text('SAMPLE'), findsNothing);

      // No Pro locked card for Pro user
      expect(find.text('Unlock 2+ More Real-Time Signals'), findsNothing);
      expect(find.text('RealizeAlpha Pro Preview'), findsNothing);

      // All indicators rendered, no locked indicator chip
      expect(find.text('+3 Pro Indicators'), findsNothing);
    });
  });
}
