import 'dart:async';
import 'dart:ui' show DartPluginRegistrant;

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/extensions.dart';
import 'package:robinhood_options_mobile/firebase_options.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_config.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/option_instrument_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/paper_trading_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_store.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';
import 'package:robinhood_options_mobile/model/trade_signals_provider.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/agentic_trading_brokerage_service_factory.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
import 'package:robinhood_options_mobile/services/agentic_trading_run_journal.dart';
import 'package:robinhood_options_mobile/utils/market_hours.dart';
import 'package:workmanager/workmanager.dart';

class AgenticTradingBackgroundService {
  static const taskName = 'com.cidevelop.robinhoodOptionsMobile.agenticTrading';
  static const frequency = Duration(minutes: 15);
  static String? _activeCycleDiagnosticId;
  static final _scheduleCoordinator = BackgroundTaskScheduleCoordinator(
    registerTask: _registerPeriodicTask,
    cancelTask: _cancelPeriodicTask,
  );

  static Future<void> _recordLocalEvent({
    required String event,
    String? reason,
    String? phase,
    String? cycleId,
    List<String>? brokerageSources,
  }) async {
    try {
      await AgenticTradingRunJournal.record(
        event: event,
        trigger: 'background',
        reason: reason,
        phase: phase,
        cycleId: cycleId,
        brokerageSources: brokerageSources,
      );
    } catch (error) {
      debugPrint(
          'Could not persist background diagnostic: ${error.runtimeType}');
    }
  }

  @visibleForTesting
  static IBrokerageService? brokerageServiceForSource(
    BrokerageSource source, {
    IBrokerageService Function()? robinhoodFactory,
    IBrokerageService Function()? schwabFactory,
  }) =>
      AgenticTradingBrokerageServiceFactory.forSource(
        source,
        robinhoodFactory: robinhoodFactory,
        schwabFactory: schwabFactory,
      );

  static Future<void> initialize() async {
    if (!_isSupportedPlatform) return;
    await Workmanager().initialize(agenticTradingBackgroundDispatcher);
  }

  static Future<void> syncScheduling({
    required bool enabled,
    bool force = false,
  }) {
    if (!_isSupportedPlatform) return Future<void>.value();
    return _scheduleCoordinator.sync(enabled: enabled, force: force);
  }

  static Future<void> _registerPeriodicTask() async {
    try {
      await Workmanager().registerPeriodicTask(
        taskName,
        taskName,
        frequency: frequency,
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        constraints: Constraints(networkType: NetworkType.connected),
      );
      await _recordLocalEvent(event: 'schedule_registered');
    } catch (error) {
      await _recordLocalEvent(
        event: 'schedule_failed',
        reason: error.runtimeType.toString(),
      );
      rethrow;
    }
  }

  static Future<void> _cancelPeriodicTask() async {
    await Workmanager().cancelByUniqueName(taskName);
    await _recordLocalEvent(event: 'schedule_cancelled');
  }

  static bool get _isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  static bool shouldRegisterPeriodicTask({
    required bool hasUserDocument,
    required bool autoTradeEnabled,
  }) =>
      hasUserDocument && autoTradeEnabled;

  @visibleForTesting
  static bool isFreshQuote({
    required DateTime? updatedAt,
    required double? price,
    DateTime? now,
  }) {
    if (updatedAt == null || price == null || price <= 0) return false;
    final age = (now ?? DateTime.now()).difference(updatedAt);
    return age >= Duration.zero && age <= const Duration(minutes: 5);
  }

  static Future<bool> runOnce() async {
    _activeCycleDiagnosticId = null;
    await _recordLocalEvent(event: 'run_started');
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    await _recordLocalEvent(event: 'firebase_ready');
    if (!kIsWeb && !kDebugMode) {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: const AndroidPlayIntegrityProvider(),
        providerApple: const AppleDeviceCheckProvider(),
      );
    }
    await _recordLocalEvent(event: 'app_check_ready');

    await _recordLocalEvent(event: 'auth_wait_started');
    final firebaseUser = await FirebaseAuth.instance
        .authStateChanges()
        .first
        .timeout(const Duration(seconds: 10));
    if (firebaseUser == null) {
      await _recordLocalEvent(event: 'auth_missing', reason: 'signed_out');
      await syncScheduling(enabled: false);
      return true;
    }
    await _recordLocalEvent(event: 'auth_restored');

    final cycleId = AgenticTradingProvider.createCycleDiagnosticId();
    _activeCycleDiagnosticId = cycleId;
    Future<void> reportCycle({
      required String phase,
      required String reason,
      AgenticTradingConfig? config,
    }) =>
        AgenticTradingProvider.logCycleDiagnostic(
          cycleId: cycleId,
          phase: phase,
          trigger: 'background',
          reason: reason,
          paperMode: config?.paperTradingMode,
          tradingMode: config?.tradingMode.name,
          quoteSource: config?.paperQuoteSource.name,
        );

    await _recordLocalEvent(
      event: 'cycle_started',
      phase: 'started',
      reason: 'cycle_started',
      cycleId: cycleId,
    );

    final userDocRef = FirestoreService().userCollection.doc(firebaseUser.uid);
    final userSnapshot = await userDocRef.get();
    final user = userSnapshot.data();
    final config = user?.agenticTradingConfig;
    if (config == null || !config.autoTradeEnabled) {
      await _recordLocalEvent(
        event: 'cycle_blocked',
        reason: config == null ? 'config_missing' : 'auto_trade_disabled',
        cycleId: cycleId,
      );
      await reportCycle(
        phase: 'blocked',
        reason: config == null ? 'config_missing' : 'auto_trade_disabled',
        config: config,
      );
      await syncScheduling(enabled: false);
      return true;
    }

    final brokerageUserStore = BrokerageUserStore([], 0);
    await brokerageUserStore.load();
    await _recordLocalEvent(
      event: 'brokerage_store_loaded',
      reason: 'entries_${brokerageUserStore.items.length}',
      cycleId: cycleId,
      brokerageSources: brokerageUserStore.items
          .map((user) => user.source.enumValue())
          .toSet()
          .toList(),
    );
    final brokerageUser = config.paperTradingMode
        ? AgenticTradingProvider.resolvePaperQuoteUser(
            userStore: brokerageUserStore,
            source: config.paperQuoteSource,
          )
        : brokerageUserStore.currentUser;
    if (brokerageUser == null) {
      await _recordLocalEvent(
        event: 'cycle_blocked',
        reason: config.paperTradingMode
            ? 'quote_source_unavailable'
            : 'account_unavailable',
        cycleId: cycleId,
      );
      await reportCycle(
        phase: 'blocked',
        reason: config.paperTradingMode
            ? 'quote_source_unavailable'
            : 'account_unavailable',
        config: config,
      );
      return true;
    }
    await _recordLocalEvent(event: 'quote_source_resolved', cycleId: cycleId);
    final brokerageService = brokerageServiceForSource(brokerageUser.source);
    if (brokerageService == null) {
      await _recordLocalEvent(
        event: 'cycle_blocked',
        reason: 'quote_service_unavailable',
        cycleId: cycleId,
      );
      await reportCycle(
        phase: 'blocked',
        reason: 'quote_service_unavailable',
        config: config,
      );
      return true;
    }
    brokerageUser.ensureOAuth2Client();
    if (brokerageUser.oauth2Client == null) {
      await _recordLocalEvent(
        event: 'cycle_blocked',
        reason: 'oauth_unavailable',
        cycleId: cycleId,
      );
      await reportCycle(
        phase: 'blocked',
        reason: 'oauth_unavailable',
        config: config,
      );
      return false;
    }

    final accountStore = AccountStore();
    final portfolioStore = PortfolioStore();
    final instrumentStore = InstrumentStore();
    final instrumentPositionStore = InstrumentPositionStore();
    final optionPositionStore = OptionPositionStore();
    final quoteStore = QuoteStore();
    final paperStore = PaperTradingStore();
    final tradeSignalsProvider = TradeSignalsProvider();

    final accountSelectionKey = AccountStore.selectionStorageKey(
      source: brokerageUser.source.enumValue(),
      userName: brokerageUser.userName,
    );
    await accountStore.loadSelectedAccountNumber(accountSelectionKey);

    final accounts = await brokerageService.getAccounts(
      brokerageUser,
      accountStore,
      portfolioStore,
      optionPositionStore,
      instrumentPositionStore: instrumentPositionStore,
    );
    if (accounts.isEmpty) {
      await _recordLocalEvent(
        event: 'cycle_blocked',
        reason: 'account_unavailable',
        cycleId: cycleId,
      );
      await reportCycle(
        phase: 'blocked',
        reason: 'account_unavailable',
        config: config,
      );
      return false;
    }
    brokerageUser.accounts = accounts;
    if (accountStore.selectedAccountNumber == null ||
        !accounts.any((account) =>
            account.accountNumber == accountStore.selectedAccountNumber)) {
      accountStore.setSelectedAccountNumber(accounts.first.accountNumber);
      await accountStore.saveSelectedAccountNumber(accountSelectionKey);
    }

    final provider = AgenticTradingProvider();
    provider.loadConfigFromUser(config);
    await Future.wait([
      provider.loadAutomatedBuyTradesFromFirestore(userDocRef),
      provider.loadAutoTradeHistoryFromFirestore(userDocRef),
      provider.loadPendingOrdersFromFirestore(userDocRef),
      provider.loadLatestMarketCloseExitStatus(userDocRef),
    ]);

    if (!MarketHours.isTradingSessionAllowed(
      allowPreMarket: config.allowPreMarketTrading,
      allowAfterHours: config.allowAfterHoursTrading,
    )) {
      if (config.strategyConfig.marketCloseExitEnabled) {
        late final List<InstrumentPosition> positions;
        if (config.paperTradingMode) {
          await paperStore.ensureLoaded(firebaseUser);
          positions = paperStore.positions;
        } else {
          if (brokerageService is RobinhoodService) {
            await brokerageService.getStockPositionStore(
              brokerageUser,
              instrumentPositionStore,
              instrumentStore,
              quoteStore,
              fetchQuotes: false,
              userDoc: userDocRef,
            );
          } else {
            await brokerageService.getStockPositionStore(
              brokerageUser,
              instrumentPositionStore,
              instrumentStore,
              quoteStore,
              userDoc: userDocRef,
            );
          }
          positions = instrumentPositionStore.items;
        }
        await provider.reconcileMissedMarketCloseExits(
          positions: positions,
          userDocRef: userDocRef,
        );
      }
      provider.dispose();
      brokerageUserStore.dispose();
      accountStore.dispose();
      portfolioStore.dispose();
      instrumentStore.dispose();
      instrumentPositionStore.dispose();
      optionPositionStore.dispose();
      quoteStore.dispose();
      paperStore.dispose();
      tradeSignalsProvider.dispose();
      await reportCycle(
        phase: 'blocked',
        reason: 'market_closed',
        config: config,
      );
      await _recordLocalEvent(
        event: 'cycle_blocked',
        reason: 'market_closed',
        cycleId: cycleId,
      );
      return true;
    }

    if (brokerageUser.source == BrokerageSource.robinhood) {
      await brokerageService.getPortfolios(brokerageUser, portfolioStore);
    }
    await brokerageService.getOptionPositionStore(
      brokerageUser,
      optionPositionStore,
      instrumentStore,
      userDoc: userDocRef,
    );
    await brokerageService.getStockPositionStore(
      brokerageUser,
      instrumentPositionStore,
      instrumentStore,
      quoteStore,
      userDoc: userDocRef,
    );

    if (config.paperTradingMode) {
      await paperStore.ensureLoaded(firebaseUser);
      await paperStore.refreshQuotes(
        brokerageService,
        quoteStore,
        OptionInstrumentStore(),
        brokerageUser,
      );
      for (final position in paperStore.positions) {
        if ((position.quantity ?? 0) == 0) continue;
        final quote = position.instrumentObj?.quoteObj;
        if (!isFreshQuote(
          updatedAt: quote?.updatedAt,
          price: quote?.lastTradePrice ?? quote?.lastExtendedHoursTradePrice,
        )) {
          await _recordLocalEvent(
            event: 'cycle_blocked',
            reason: 'stale_quote',
            cycleId: cycleId,
          );
          await reportCycle(
            phase: 'blocked',
            reason: 'stale_quote',
            config: config,
          );
          return false;
        }
      }
    } else {
      for (final position in instrumentPositionStore.items) {
        if ((position.quantity ?? 0) == 0) continue;
        final quote = position.instrumentObj?.quoteObj;
        if (!isFreshQuote(
          updatedAt: quote?.updatedAt,
          price: quote?.lastTradePrice ?? quote?.lastExtendedHoursTradePrice,
        )) {
          await _recordLocalEvent(
            event: 'cycle_blocked',
            reason: 'stale_quote',
            cycleId: cycleId,
          );
          await reportCycle(
            phase: 'blocked',
            reason: 'stale_quote',
            config: config,
          );
          return false;
        }
      }
    }

    final dependencies = AgenticTradingCycleDependencies(
      userStore: brokerageUserStore,
      accountStore: accountStore,
      instrumentStore: instrumentStore,
      portfolioStore: portfolioStore,
      tradeSignalsProvider: tradeSignalsProvider,
      instrumentPositionStore: instrumentPositionStore,
      optionPositionStore: optionPositionStore,
      paperTradingStore: paperStore,
      quoteStore: quoteStore,
      requireFreshQuotes: true,
    );
    await _recordLocalEvent(event: 'cycle_invoked', cycleId: cycleId);
    await provider.runAutoTradeCycle(
      brokerageService: brokerageService,
      userDocRef: userDocRef,
      dependencies: dependencies,
      trigger: 'background',
      cycleId: cycleId,
      logStarted: false,
    );
    provider.dispose();
    brokerageUserStore.dispose();
    accountStore.dispose();
    portfolioStore.dispose();
    instrumentStore.dispose();
    instrumentPositionStore.dispose();
    optionPositionStore.dispose();
    quoteStore.dispose();
    paperStore.dispose();
    tradeSignalsProvider.dispose();
    await _recordLocalEvent(event: 'cycle_returned', cycleId: cycleId);
    return true;
  }
}

@pragma('vm:entry-point')
void agenticTradingBackgroundDispatcher() {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName != AgenticTradingBackgroundService.taskName) {
      await AgenticTradingBackgroundService._recordLocalEvent(
        event: 'task_ignored',
      );
      return true;
    }
    await AgenticTradingBackgroundService._recordLocalEvent(
      event: 'task_received',
    );
    try {
      final result = await AgenticTradingBackgroundService.runOnce();
      await AgenticTradingBackgroundService._recordLocalEvent(
        event: 'task_finished',
        reason: result ? 'success' : 'retry_requested',
        cycleId: AgenticTradingBackgroundService._activeCycleDiagnosticId,
      );
      return result;
    } catch (error) {
      final cycleId = AgenticTradingBackgroundService._activeCycleDiagnosticId;
      await AgenticTradingBackgroundService._recordLocalEvent(
        event: 'task_failed',
        reason: error.runtimeType.toString(),
        cycleId: cycleId,
      );
      if (cycleId != null) {
        await AgenticTradingProvider.logCycleDiagnostic(
          cycleId: cycleId,
          phase: 'failed',
          trigger: 'background',
          reason: 'cycle_error',
        );
      }
      debugPrint('Agentic background cycle failed: $error');
      return false;
    }
  });
}

class BackgroundTaskScheduleCoordinator {
  BackgroundTaskScheduleCoordinator({
    required Future<void> Function() registerTask,
    required Future<void> Function() cancelTask,
  })  : _registerTask = registerTask,
        _cancelTask = cancelTask;

  final Future<void> Function() _registerTask;
  final Future<void> Function() _cancelTask;
  Future<void> _pendingChanges = Future<void>.value();
  bool? _appliedEnabledState;

  Future<void> sync({required bool enabled, bool force = false}) {
    final completer = Completer<void>();
    _pendingChanges = _pendingChanges.catchError((Object _) {}).then((_) async {
      if (!force && _appliedEnabledState == enabled) return;
      if (enabled) {
        await _registerTask();
      } else {
        await _cancelTask();
      }
      _appliedEnabledState = enabled;
    }).then<void>(
      (_) => completer.complete(),
      onError: (Object error, StackTrace stackTrace) =>
          completer.completeError(error, stackTrace),
    );
    return completer.future;
  }
}
