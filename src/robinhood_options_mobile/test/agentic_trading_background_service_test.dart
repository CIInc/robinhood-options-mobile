import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_config.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_store.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';
import 'package:robinhood_options_mobile/model/user.dart' as app_user;
import 'package:robinhood_options_mobile/services/agentic_trading_background_service.dart';
import 'package:robinhood_options_mobile/services/agentic_trading_run_journal.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/utils/market_hours.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_mocks.dart';

class _FakeFirebaseAnalytics extends Fake implements FirebaseAnalytics {
  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
    List<AnalyticsEventItem>? items,
    AnalyticsCallOptions? callOptions,
  }) async {}
}

class _FakeFirebaseUser extends Fake implements firebase_auth.User {
  @override
  final String uid;

  _FakeFirebaseUser(this.uid);
}

class _FakeOAuth2Client extends Fake implements oauth2.Client {}

class _FakeBackgroundBrokerageService extends Fake
    implements IBrokerageService {
  final List<Account> accountsToReturn;
  final List<InstrumentPosition> stockPositionsToReturn;
  final List<String> placedOrderSymbols = [];

  _FakeBackgroundBrokerageService({
    required this.accountsToReturn,
    this.stockPositionsToReturn = const [],
  });

  @override
  Future<List<Account>> getAccounts(
    BrokerageUser user,
    AccountStore store,
    PortfolioStore? portfolioStore,
    OptionPositionStore? optionPositionStore, {
    InstrumentPositionStore? instrumentPositionStore,
    DocumentReference? userDoc,
  }) async {
    return accountsToReturn;
  }

  @override
  Future<OptionPositionStore> getOptionPositionStore(
    BrokerageUser user,
    OptionPositionStore store,
    InstrumentStore instrumentStore, {
    bool nonzero = true,
    DocumentReference? userDoc,
  }) async {
    return store;
  }

  @override
  Future<InstrumentPositionStore> getStockPositionStore(
    BrokerageUser user,
    InstrumentPositionStore store,
    InstrumentStore instrumentStore,
    QuoteStore quoteStore, {
    bool nonzero = true,
    DocumentReference? userDoc,
  }) async {
    for (final position in stockPositionsToReturn) {
      store.addOrUpdate(position);
    }
    return store;
  }

  @override
  Future<List<Quote>> getQuoteByIds(
    BrokerageUser user,
    QuoteStore store,
    List<String> symbols, {
    bool fromCache = true,
  }) async {
    return [];
  }

  @override
  Future<dynamic> placeInstrumentOrder(
    BrokerageUser user,
    Account account,
    Instrument instrument,
    String symbol,
    String side,
    double? price,
    int quantity, {
    String type = 'limit',
    String trigger = 'immediate',
    double? stopPrice,
    String timeInForce = 'gtc',
    Map<String, dynamic>? trailingPeg,
    String? taxLotSelectionType,
    List<Map<String, dynamic>>? taxLots,
  }) async {
    placedOrderSymbols.add(symbol);
    return {'id': 'unexpected-order'};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Account buildAccount() => Account(
        'https://api.schwabapi.com/accounts/SCHWAB-123',
        25000.0,
        'SCHWAB-123',
        'margin',
        25000.0,
        'tier_2',
        0.0,
        0.0,
        0.0,
      );

  Quote buildQuote({
    required String symbol,
    required double price,
    required DateTime updatedAt,
  }) =>
      Quote(
        askPrice: price,
        askSize: 100,
        bidPrice: price,
        bidSize: 100,
        lastTradePrice: price,
        lastExtendedHoursTradePrice: price,
        previousClose: price,
        adjustedPreviousClose: price,
        previousCloseDate: updatedAt,
        symbol: symbol,
        tradingHalted: false,
        hasTraded: true,
        lastTradePriceSource: 'schwab',
        updatedAt: updatedAt,
        instrument: 'https://api.schwabapi.com/instruments/$symbol',
        instrumentId: symbol,
      );

  InstrumentPosition buildStockPosition({
    required String symbol,
    required double price,
    required DateTime updatedAt,
  }) {
    final position = InstrumentPosition.fromJson({
      'url': 'https://api.schwabapi.com/positions/SCHWAB-123/$symbol',
      'instrument': 'https://api.schwabapi.com/instruments/$symbol',
      'account': 'https://api.schwabapi.com/accounts/SCHWAB-123',
      'account_number': 'SCHWAB-123',
      'quantity': '5.0000',
      'average_buy_price': '145.0000',
      'avg_cost_affected': false,
    });
    position.instrumentObj = Instrument.forSymbol(
      symbol,
      instrumentUrl: 'https://api.schwabapi.com/instruments/$symbol',
    )..quoteObj =
        buildQuote(symbol: symbol, price: price, updatedAt: updatedAt);
    return position;
  }

  Map<String, dynamic> buildPaperPositionJson({
    required String symbol,
  }) =>
      {
        'url': 'https://api.schwabapi.com/positions/paper/$symbol',
        'instrument': 'https://api.schwabapi.com/instruments/$symbol',
        'account': 'paper',
        'account_number': 'paper',
        'quantity': '5.0',
        'average_buy_price': '145.0',
        'avg_cost_affected': false,
        'instrumentObj': {
          'id': symbol,
          'url': 'https://api.schwabapi.com/instruments/$symbol',
          'symbol': symbol,
          'name': symbol,
          'type': 'stock',
        },
      };

  setUpAll(() async {
    await setupFirebaseMocks();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AgenticTradingRunJournal.clear();
  });

  tearDown(() {
    MarketHours.testTime = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      AgenticTradingBackgroundService.backgroundExecutionChannel,
      null,
    );
  });

  group('BackgroundExecutionReadiness & native platform channel (#282)', () {
    test('parses ready iOS BGTaskScheduler state and records journal entry',
        () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        AgenticTradingBackgroundService.backgroundExecutionChannel,
        (call) async {
          calls.add(call);
          if (call.method == 'getPlatformReadiness') {
            return {
              'platform': 'ios',
              'bgTaskIdentifierRegistered': true,
              'fetchModeEnabled': true,
              'backgroundRefreshStatus': 'available',
              'lowPowerMode': false,
              'canOpenSettings': true,
            };
          }
          return null;
        },
      );

      final readiness =
          await AgenticTradingBackgroundService.inspectPlatformReadiness(
        platformOverride: TargetPlatform.iOS,
        recordJournal: true,
      );

      expect(calls.map((c) => c.method), ['getPlatformReadiness']);
      expect(readiness.platform, 'ios');
      expect(readiness.isReady, isTrue);
      expect(readiness.bgTaskIdentifierRegistered, isTrue);
      expect(readiness.fetchModeEnabled, isTrue);
      expect(readiness.backgroundRefreshStatus, 'available');
      expect(readiness.lowPowerMode, isFalse);
      expect(readiness.warnings, isEmpty);
      expect(readiness.remediationHint, isNull);
      expect(readiness.statusSummary, contains('BGTaskScheduler ready'));

      final journal = await AgenticTradingRunJournal.recent(limit: 5);
      expect(journal.first['event'], 'platform_readiness_checked');
      expect(journal.first['reason'], 'ios_ready');
    });

    test(
        'flags iOS BGTaskScheduler/Background Refresh/Low Power warnings and opens iOS settings',
        () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        AgenticTradingBackgroundService.backgroundExecutionChannel,
        (call) async {
          calls.add(call);
          if (call.method == 'getPlatformReadiness') {
            return {
              'platform': 'ios',
              'bgTaskIdentifierRegistered': false,
              'fetchModeEnabled': true,
              'backgroundRefreshStatus': 'denied',
              'lowPowerMode': true,
              'canOpenSettings': true,
            };
          }
          if (call.method == 'openBackgroundSettings') {
            return true;
          }
          return null;
        },
      );

      final readiness =
          await AgenticTradingBackgroundService.inspectPlatformReadiness(
        platformOverride: TargetPlatform.iOS,
        recordJournal: true,
      );

      expect(readiness.isReady, isFalse);
      expect(
        readiness.warnings,
        containsAll([
          contains('BGTaskScheduler'),
          contains('Background App Refresh'),
          contains('Low Power Mode'),
        ]),
      );
      expect(readiness.remediationHint,
          contains('BGTaskSchedulerPermittedIdentifiers'));

      final opened =
          await AgenticTradingBackgroundService.openPlatformBackgroundSettings(
        platformOverride: TargetPlatform.iOS,
      );
      expect(opened, isTrue);
      expect(
        calls.map((c) => c.method),
        ['getPlatformReadiness', 'openBackgroundSettings'],
      );

      final journal = await AgenticTradingRunJournal.recent(limit: 5);
      expect(journal.first['event'], 'platform_readiness_warning');
      expect(journal.first['reason'], 'ios_restricted');
    });

    test(
        'parses Android ready state, restricted OEM hints, and opens battery optimization settings',
        () async {
      final calls = <MethodCall>[];
      Map<String, dynamic> nextResponse = {
        'platform': 'android',
        'ignoringBatteryOptimizations': true,
        'powerSaveMode': false,
        'backgroundRestricted': false,
        'manufacturer': 'Google',
        'model': 'Pixel 9',
        'canOpenSettings': true,
      };
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        AgenticTradingBackgroundService.backgroundExecutionChannel,
        (call) async {
          calls.add(call);
          if (call.method == 'getPlatformReadiness') {
            return nextResponse;
          }
          if (call.method == 'openBatteryOptimizationSettings') {
            return true;
          }
          return null;
        },
      );

      final ready =
          await AgenticTradingBackgroundService.inspectPlatformReadiness(
        platformOverride: TargetPlatform.android,
      );
      expect(ready.isReady, isTrue);
      expect(ready.warnings, isEmpty);
      expect(ready.statusSummary, contains('WorkManager ready'));

      for (final oemCase in [
        ('Samsung', 'Samsung One UI'),
        ('Xiaomi', 'Xiaomi / MIUI / HyperOS'),
        ('OnePlus', 'OnePlus / OPPO / Realme'),
        ('Google', 'Google Pixel'),
      ]) {
        nextResponse = {
          'platform': 'android',
          'ignoringBatteryOptimizations': false,
          'powerSaveMode': true,
          'backgroundRestricted': true,
          'manufacturer': oemCase.$1,
          'model': 'TestModel',
          'canOpenSettings': true,
        };
        final restricted =
            await AgenticTradingBackgroundService.inspectPlatformReadiness(
          platformOverride: TargetPlatform.android,
        );
        expect(restricted.isReady, isFalse);
        expect(restricted.statusSummary,
            'Android background execution restricted');
        expect(
          restricted.warnings,
          containsAll([
            contains('Background Restriction'),
            contains('Battery Optimization'),
            contains('Battery Saver'),
          ]),
        );
        expect(restricted.remediationHint, contains(oemCase.$2));
      }

      final opened =
          await AgenticTradingBackgroundService.openPlatformBackgroundSettings(
        platformOverride: TargetPlatform.android,
      );
      expect(opened, isTrue);
      expect(calls.last.method, 'openBatteryOptimizationSettings');
    });

    test('falls back safely when native channel is missing', () async {
      final readiness =
          await AgenticTradingBackgroundService.inspectPlatformReadiness(
        platformOverride: TargetPlatform.android,
      );

      expect(readiness.platform, 'unsupported');
      expect(readiness.isReady, isFalse);
      expect(readiness.statusSummary, contains('unavailable'));
    });
  });

  group(
      'AgenticTradingBackgroundService.runOnce lifecycle & EOD acceptance (#282)',
      () {
    test('records auth_missing and disables schedule when user is signed out',
        () async {
      final schedulingCalls = <bool>[];
      final result = await AgenticTradingBackgroundService.runOnce(
        harness: AgenticTradingBackgroundHarness(
          ensureFirebaseInitialized: () async {},
          loadFirebaseUser: () async => null,
          syncScheduling: ({required bool enabled}) async {
            schedulingCalls.add(enabled);
          },
        ),
      );

      expect(result, isTrue);
      expect(schedulingCalls, [false]);
      final journal = await AgenticTradingRunJournal.recent(limit: 10);
      expect(
        journal.any(
            (e) => e['event'] == 'auth_missing' && e['reason'] == 'signed_out'),
        isTrue,
      );
    });

    test(
        'records auto_trade_disabled and cancels schedule when disabled in config',
        () async {
      final firestore = FakeFirebaseFirestore();
      final user = app_user.User(
        devices: [],
        dateCreated: DateTime.utc(2025, 11, 26),
        brokerageUsers: [],
        agenticTradingConfig: AgenticTradingConfig(
          autoTradeEnabled: false,
          strategyConfig: TradeStrategyConfig(),
        ),
      );
      await firestore.collection('user').doc('u1').set(user.toJson());

      final schedulingCalls = <bool>[];
      final result = await AgenticTradingBackgroundService.runOnce(
        harness: AgenticTradingBackgroundHarness(
          ensureFirebaseInitialized: () async {},
          loadFirebaseUser: () async => _FakeFirebaseUser('u1'),
          firestore: firestore,
          syncScheduling: ({required bool enabled}) async {
            schedulingCalls.add(enabled);
          },
        ),
      );

      expect(result, isTrue);
      expect(schedulingCalls, [false]);
      final journal = await AgenticTradingRunJournal.recent(limit: 10);
      expect(
        journal.any((e) =>
            e['event'] == 'cycle_blocked' &&
            e['reason'] == 'auto_trade_disabled'),
        isTrue,
      );
    });

    test(
        'reconciles missed Schwab Live EOD exit when market is closed without placing after-hours orders',
        () async {
      final firestore = FakeFirebaseFirestore();
      final userRef = firestore.collection('user').doc('schwab-u1');
      final config = AgenticTradingConfig(
        autoTradeEnabled: true,
        paperTradingMode: false,
        strategyConfig: TradeStrategyConfig(
          marketCloseExitEnabled: true,
          marketCloseExitMinutes: 15,
        ),
      );
      await userRef.set(
        app_user.User(
          devices: [],
          dateCreated: DateTime.utc(2025, 11, 26),
          brokerageUsers: [],
          agenticTradingConfig: config,
        ).toJson(),
      );
      final overdueTrade = {
        'symbol': 'AAPL',
        'quantity': 5,
        'entryPrice': 145.0,
        'paperMode': false,
        'timestamp': '2025-11-26T15:00:00.000Z',
      };
      await userRef
          .collection('automated_buy_trades')
          .doc(AgenticTradingProvider.automatedTradeDocId(overdueTrade))
          .set(overdueTrade);

      // Wednesday Nov 26, 2025 at 16:05 EST (21:05 UTC): regular market closed
      final now = DateTime.utc(2025, 11, 26, 21, 5);
      MarketHours.testTime = now;

      final fakeService = _FakeBackgroundBrokerageService(
        accountsToReturn: [buildAccount()],
        stockPositionsToReturn: [
          buildStockPosition(symbol: 'AAPL', price: 150.0, updatedAt: now),
        ],
      );

      final result = await AgenticTradingBackgroundService.runOnce(
        harness: AgenticTradingBackgroundHarness(
          ensureFirebaseInitialized: () async {},
          loadFirebaseUser: () async => _FakeFirebaseUser('schwab-u1'),
          firestore: firestore,
          loadBrokerageUserStore: () async => BrokerageUserStore([
            BrokerageUser(
              BrokerageSource.schwab,
              'schwab-user',
              null,
              _FakeOAuth2Client(),
            ),
          ], 0),
          brokerageServiceFactory: (_) => fakeService,
          createProvider: () =>
              AgenticTradingProvider(analytics: _FakeFirebaseAnalytics()),
          nowProvider: () => now,
        ),
      );

      expect(result, isTrue);
      expect(fakeService.placedOrderSymbols, isEmpty);

      final statusId = AgenticTradingProvider.marketCloseExitStatusDocId(
        overdueTrade,
        DateTime.utc(2025, 11, 26),
      );
      final statusDoc = await userRef
          .collection('agentic_trading_exit_status')
          .doc(statusId)
          .get();
      expect(statusDoc.data()?['status'], 'missed');

      final journal = await AgenticTradingRunJournal.recent(limit: 15);
      expect(
        journal.any((e) =>
            e['event'] == 'cycle_blocked' && e['reason'] == 'market_closed'),
        isTrue,
      );
    });

    test(
        'reconciles missed Paper EOD exit after 1:00 PM ET early close without live orders',
        () async {
      final firestore = FakeFirebaseFirestore();
      final userRef = firestore.collection('user').doc('paper-u1');
      final config = AgenticTradingConfig(
        autoTradeEnabled: true,
        paperTradingMode: true,
        paperQuoteSource: PaperQuoteSource.schwab,
        strategyConfig: TradeStrategyConfig(
          marketCloseExitEnabled: true,
          marketCloseExitMinutes: 15,
        ),
      );
      await userRef.set(
        app_user.User(
          devices: [],
          dateCreated: DateTime.utc(2025, 11, 28),
          brokerageUsers: [],
          agenticTradingConfig: config,
        ).toJson(),
      );
      await userRef.collection('paper_account').doc('main').set({
        'initialCapital': 100000.0,
        'cashBalance': 99275.0,
        'positions': [buildPaperPositionJson(symbol: 'AAPL')],
      });
      final overduePaperTrade = {
        'symbol': 'AAPL',
        'quantity': 5,
        'entryPrice': 145.0,
        'paperMode': true,
        'timestamp': '2025-11-28T15:00:00.000Z',
      };
      await userRef
          .collection('automated_buy_trades')
          .doc(AgenticTradingProvider.automatedTradeDocId(overduePaperTrade))
          .set(overduePaperTrade);

      // Friday Nov 28, 2025 (Day After Thanksgiving) at 13:05 EST (18:05 UTC)
      final now = DateTime.utc(2025, 11, 28, 18, 5);
      MarketHours.testTime = now;

      final fakeService = _FakeBackgroundBrokerageService(
        accountsToReturn: [buildAccount()],
      );

      final result = await AgenticTradingBackgroundService.runOnce(
        harness: AgenticTradingBackgroundHarness(
          ensureFirebaseInitialized: () async {},
          loadFirebaseUser: () async => _FakeFirebaseUser('paper-u1'),
          firestore: firestore,
          loadBrokerageUserStore: () async => BrokerageUserStore([
            BrokerageUser(
              BrokerageSource.schwab,
              'schwab-user',
              null,
              _FakeOAuth2Client(),
            ),
          ], 0),
          brokerageServiceFactory: (_) => fakeService,
          createProvider: () =>
              AgenticTradingProvider(analytics: _FakeFirebaseAnalytics()),
          nowProvider: () => now,
        ),
      );

      expect(result, isTrue);
      expect(fakeService.placedOrderSymbols, isEmpty);

      final statusId = AgenticTradingProvider.marketCloseExitStatusDocId(
        overduePaperTrade,
        DateTime.utc(2025, 11, 28),
      );
      final statusDoc = await userRef
          .collection('agentic_trading_exit_status')
          .doc(statusId)
          .get();
      expect(statusDoc.data()?['status'], 'missed');
    });

    test(
        'requests Workmanager retry (returns false) when position quote is stale during market hours',
        () async {
      final firestore = FakeFirebaseFirestore();
      final userRef = firestore.collection('user').doc('stale-u1');
      final config = AgenticTradingConfig(
        autoTradeEnabled: true,
        paperTradingMode: false,
        strategyConfig: TradeStrategyConfig(),
      );
      await userRef.set(
        app_user.User(
          devices: [],
          dateCreated: DateTime.utc(2025, 11, 26),
          brokerageUsers: [],
          agenticTradingConfig: config,
        ).toJson(),
      );

      // Wednesday Nov 26, 2025 at 11:00 EST (16:00 UTC): regular market open
      final now = DateTime.utc(2025, 11, 26, 16, 0);
      MarketHours.testTime = now;

      final fakeService = _FakeBackgroundBrokerageService(
        accountsToReturn: [buildAccount()],
        stockPositionsToReturn: [
          buildStockPosition(
            symbol: 'AAPL',
            price: 150.0,
            updatedAt: now.subtract(const Duration(minutes: 10)),
          ),
        ],
      );
      var cycleInvoked = false;

      final result = await AgenticTradingBackgroundService.runOnce(
        harness: AgenticTradingBackgroundHarness(
          ensureFirebaseInitialized: () async {},
          loadFirebaseUser: () async => _FakeFirebaseUser('stale-u1'),
          firestore: firestore,
          loadBrokerageUserStore: () async => BrokerageUserStore([
            BrokerageUser(
              BrokerageSource.schwab,
              'schwab-user',
              null,
              _FakeOAuth2Client(),
            ),
          ], 0),
          brokerageServiceFactory: (_) => fakeService,
          createProvider: () =>
              AgenticTradingProvider(analytics: _FakeFirebaseAnalytics()),
          runAutoTradeCycle: ({
            required AgenticTradingProvider provider,
            required IBrokerageService brokerageService,
            required DocumentReference<app_user.User> userDocRef,
            required AgenticTradingCycleDependencies dependencies,
            required String cycleId,
          }) async {
            cycleInvoked = true;
          },
          nowProvider: () => now,
        ),
      );

      expect(result, isFalse);
      expect(cycleInvoked, isFalse);
      final journal = await AgenticTradingRunJournal.recent(limit: 15);
      expect(
        journal.any((e) =>
            e['event'] == 'cycle_blocked' && e['reason'] == 'stale_quote'),
        isTrue,
      );
    });

    test(
        'invokes cycle with requireFreshQuotes when position quotes are fresh during market hours',
        () async {
      final firestore = FakeFirebaseFirestore();
      final userRef = firestore.collection('user').doc('fresh-u1');
      final config = AgenticTradingConfig(
        autoTradeEnabled: true,
        paperTradingMode: false,
        strategyConfig: TradeStrategyConfig(),
      );
      await userRef.set(
        app_user.User(
          devices: [],
          dateCreated: DateTime.utc(2025, 11, 26),
          brokerageUsers: [],
          agenticTradingConfig: config,
        ).toJson(),
      );

      final now = DateTime.utc(2025, 11, 26, 16, 0);
      MarketHours.testTime = now;

      final fakeService = _FakeBackgroundBrokerageService(
        accountsToReturn: [buildAccount()],
        stockPositionsToReturn: [
          buildStockPosition(
            symbol: 'AAPL',
            price: 150.0,
            updatedAt: now.subtract(const Duration(minutes: 2)),
          ),
        ],
      );
      bool? capturedRequireFreshQuotes;

      final result = await AgenticTradingBackgroundService.runOnce(
        harness: AgenticTradingBackgroundHarness(
          ensureFirebaseInitialized: () async {},
          loadFirebaseUser: () async => _FakeFirebaseUser('fresh-u1'),
          firestore: firestore,
          loadBrokerageUserStore: () async => BrokerageUserStore([
            BrokerageUser(
              BrokerageSource.schwab,
              'schwab-user',
              null,
              _FakeOAuth2Client(),
            ),
          ], 0),
          brokerageServiceFactory: (_) => fakeService,
          createProvider: () =>
              AgenticTradingProvider(analytics: _FakeFirebaseAnalytics()),
          runAutoTradeCycle: ({
            required AgenticTradingProvider provider,
            required IBrokerageService brokerageService,
            required DocumentReference<app_user.User> userDocRef,
            required AgenticTradingCycleDependencies dependencies,
            required String cycleId,
          }) async {
            capturedRequireFreshQuotes = dependencies.requireFreshQuotes;
          },
          nowProvider: () => now,
        ),
      );

      expect(result, isTrue);
      expect(capturedRequireFreshQuotes, isTrue);
      final journal = await AgenticTradingRunJournal.recent(limit: 20);
      expect(journal.any((e) => e['event'] == 'cycle_invoked'), isTrue);
      expect(journal.any((e) => e['event'] == 'cycle_returned'), isTrue);
    });
  });
}
