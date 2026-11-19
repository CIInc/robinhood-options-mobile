import 'dart:async';
import 'dart:ui' show DartPluginRegistrant;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
import 'package:robinhood_options_mobile/model/user.dart' as app_user;
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/agentic_trading_brokerage_service_factory.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
import 'package:robinhood_options_mobile/services/agentic_trading_run_journal.dart';
import 'package:robinhood_options_mobile/utils/market_hours.dart';
import 'package:workmanager/workmanager.dart';

/// OS-level readiness snapshot for periodic background auto-trading wakeups.
class BackgroundExecutionReadiness {
  final String platform;
  final bool isReady;
  final bool bgTaskIdentifierRegistered;
  final bool fetchModeEnabled;
  final String? backgroundRefreshStatus;
  final bool lowPowerMode;
  final bool ignoringBatteryOptimizations;
  final bool powerSaveMode;
  final bool backgroundRestricted;
  final String? manufacturer;
  final String? model;
  final List<String> warnings;
  final String? remediationHint;
  final bool canOpenSettings;
  final String statusSummary;

  const BackgroundExecutionReadiness({
    required this.platform,
    required this.isReady,
    this.bgTaskIdentifierRegistered = false,
    this.fetchModeEnabled = false,
    this.backgroundRefreshStatus,
    this.lowPowerMode = false,
    this.ignoringBatteryOptimizations = true,
    this.powerSaveMode = false,
    this.backgroundRestricted = false,
    this.manufacturer,
    this.model,
    this.warnings = const [],
    this.remediationHint,
    this.canOpenSettings = false,
    required this.statusSummary,
  });

  /// Constructs an unavailable/unsupported readiness state without failing.
  factory BackgroundExecutionReadiness.unsupported({String? reason}) {
    final trimmed = reason?.trim();
    return BackgroundExecutionReadiness(
      platform: 'unsupported',
      isReady: false,
      warnings: [
        if (trimmed != null && trimmed.isNotEmpty) trimmed,
      ],
      statusSummary: trimmed != null && trimmed.isNotEmpty
          ? trimmed
          : 'Background readiness check is only available on iOS and Android.',
    );
  }

  /// Parses the native `com.realizealpha.background_execution` channel payload.
  factory BackgroundExecutionReadiness.fromChannelMap(
    Map<dynamic, dynamic> raw, {
    TargetPlatform? targetPlatform,
  }) {
    final normalizedPlatform = ((raw['platform'] as String?) ??
            switch (targetPlatform) {
              TargetPlatform.iOS => 'ios',
              TargetPlatform.android => 'android',
              _ => 'unsupported',
            })
        .toLowerCase();

    if (normalizedPlatform == 'ios') {
      return _fromIosMap(raw);
    }
    if (normalizedPlatform == 'android') {
      return _fromAndroidMap(raw);
    }
    return BackgroundExecutionReadiness.unsupported();
  }

  static BackgroundExecutionReadiness _fromIosMap(Map<dynamic, dynamic> raw) {
    final bgTaskRegistered = raw['bgTaskIdentifierRegistered'] == true;
    final fetchEnabled = raw['fetchModeEnabled'] == true;
    final refreshStatus =
        (raw['backgroundRefreshStatus'] as String?) ?? 'unknown';
    final lowPower = raw['lowPowerMode'] == true;
    final canOpen = raw['canOpenSettings'] == true;
    final warnings = <String>[];

    if (!bgTaskRegistered) {
      warnings.add(
        'BGTaskScheduler identifier is missing from Info.plist.',
      );
    }
    if (!fetchEnabled) {
      warnings.add('UIBackgroundModes fetch capability is disabled.');
    }
    if (refreshStatus == 'denied') {
      warnings.add(
        'iOS Background App Refresh is turned off for RealizeAlpha or globally.',
      );
    } else if (refreshStatus == 'restricted') {
      warnings.add('iOS Background App Refresh is restricted on this device.');
    } else if (refreshStatus != 'available') {
      warnings.add(
        'iOS Background App Refresh status could not be confirmed ($refreshStatus).',
      );
    }
    if (lowPower) {
      warnings.add(
        'iOS Low Power Mode is enabled, which defers BGTaskScheduler wakeups.',
      );
    }

    final isReady = bgTaskRegistered &&
        fetchEnabled &&
        refreshStatus == 'available' &&
        !lowPower;

    String? remediation;
    if (!bgTaskRegistered || !fetchEnabled) {
      remediation =
          'Rebuild the iOS app with BGTaskSchedulerPermittedIdentifiers and UIBackgroundModes fetch enabled.';
    } else if (refreshStatus != 'available') {
      remediation =
          'Enable Settings -> General -> Background App Refresh for RealizeAlpha so iOS can schedule BGTaskScheduler wakeups.';
    } else if (lowPower) {
      remediation =
          'Disable Low Power Mode during market hours for more consistent iOS BGTaskScheduler wakeups.';
    }

    return BackgroundExecutionReadiness(
      platform: 'ios',
      isReady: isReady,
      bgTaskIdentifierRegistered: bgTaskRegistered,
      fetchModeEnabled: fetchEnabled,
      backgroundRefreshStatus: refreshStatus,
      lowPowerMode: lowPower,
      canOpenSettings: canOpen,
      warnings: warnings,
      remediationHint: remediation,
      statusSummary: isReady
          ? 'iOS BGTaskScheduler ready (Background App Refresh enabled)'
          : 'iOS BGTaskScheduler restricted',
    );
  }

  static BackgroundExecutionReadiness _fromAndroidMap(
    Map<dynamic, dynamic> raw,
  ) {
    final ignoringOpt = raw['ignoringBatteryOptimizations'] == true;
    final powerSave = raw['powerSaveMode'] == true;
    final bgRestricted = raw['backgroundRestricted'] == true;
    final manufacturer = (raw['manufacturer'] as String?)?.trim();
    final model = (raw['model'] as String?)?.trim();
    final canOpen = raw['canOpenSettings'] == true;
    final warnings = <String>[];

    if (bgRestricted) {
      warnings.add(
        'Android Background Restriction is enabled; WorkManager tasks are blocked while backgrounded.',
      );
    }
    if (!ignoringOpt) {
      warnings.add(
        'Android Battery Optimization (Doze) is active and may defer 15-minute WorkManager wakeups.',
      );
    }
    if (powerSave) {
      warnings.add(
        'Android Battery Saver is enabled and throttles background WorkManager jobs.',
      );
    }

    final isReady = ignoringOpt && !bgRestricted && !powerSave;
    final remediation = isReady
        ? null
        : _androidOemRemediationHint(
            manufacturer: manufacturer,
            ignoringBatteryOptimizations: ignoringOpt,
            backgroundRestricted: bgRestricted,
            powerSaveMode: powerSave,
          );

    return BackgroundExecutionReadiness(
      platform: 'android',
      isReady: isReady,
      ignoringBatteryOptimizations: ignoringOpt,
      powerSaveMode: powerSave,
      backgroundRestricted: bgRestricted,
      manufacturer: manufacturer,
      model: model,
      canOpenSettings: canOpen,
      warnings: warnings,
      remediationHint: remediation,
      statusSummary: isReady
          ? 'Android WorkManager ready (Unrestricted battery policy)'
          : (bgRestricted
              ? 'Android background execution restricted'
              : 'Android battery optimization active'),
    );
  }

  static String _androidOemRemediationHint({
    String? manufacturer,
    required bool ignoringBatteryOptimizations,
    required bool backgroundRestricted,
    required bool powerSaveMode,
  }) {
    final normalized = (manufacturer ?? '').toLowerCase();
    final deviceHint = () {
      if (normalized.contains('samsung')) {
        return 'Samsung One UI: Set App Battery Usage to Unrestricted and exclude RealizeAlpha from Sleeping / Deep Sleeping apps in Device Care.';
      }
      if (normalized.contains('xiaomi') ||
          normalized.contains('redmi') ||
          normalized.contains('poco')) {
        return 'Xiaomi / MIUI / HyperOS: Set Battery Saver to No restrictions and enable Autostart for RealizeAlpha.';
      }
      if (normalized.contains('oneplus') ||
          normalized.contains('oppo') ||
          normalized.contains('realme')) {
        return 'OnePlus / OPPO / Realme: Allow background activity and set Battery Optimization to Don\'t optimize.';
      }
      if (normalized.contains('huawei') || normalized.contains('honor')) {
        return 'Huawei / Honor: Disable automatic App Launch management and allow Run in background in Battery settings.';
      }
      if (normalized.contains('google')) {
        return 'Google Pixel: Set App Battery Usage to Unrestricted so Adaptive Battery and Doze do not defer market-hours checks.';
      }
      final label = (manufacturer != null && manufacturer.isNotEmpty)
          ? manufacturer
          : 'Android';
      return '$label: Set App Battery Usage to Unrestricted and disable background restrictions during market hours.';
    }();
    if (powerSaveMode &&
        ignoringBatteryOptimizations &&
        !backgroundRestricted) {
      return 'Turn off Battery Saver during market hours; $deviceHint';
    }
    return deviceHint;
  }
}

/// Optional dependency overrides allowing deterministic testing of [AgenticTradingBackgroundService.runOnce].
@visibleForTesting
class AgenticTradingBackgroundHarness {
  final Future<void> Function()? ensureFirebaseInitialized;
  final Future<User?> Function()? loadFirebaseUser;
  final Future<void> Function({required bool enabled})? syncScheduling;
  final FirebaseFirestore? firestore;
  final Future<BrokerageUserStore> Function()? loadBrokerageUserStore;
  final IBrokerageService? Function(BrokerageSource source)?
      brokerageServiceFactory;
  final PaperTradingStore Function()? createPaperTradingStore;
  final AgenticTradingProvider Function()? createProvider;
  final Future<void> Function({
    required AgenticTradingProvider provider,
    required IBrokerageService brokerageService,
    required DocumentReference<app_user.User> userDocRef,
    required AgenticTradingCycleDependencies dependencies,
    required String cycleId,
  })? runAutoTradeCycle;
  final DateTime Function()? nowProvider;

  const AgenticTradingBackgroundHarness({
    this.ensureFirebaseInitialized,
    this.loadFirebaseUser,
    this.syncScheduling,
    this.firestore,
    this.loadBrokerageUserStore,
    this.brokerageServiceFactory,
    this.createPaperTradingStore,
    this.createProvider,
    this.runAutoTradeCycle,
    this.nowProvider,
  });
}

class AgenticTradingBackgroundService {
  static const taskName = 'com.cidevelop.robinhoodOptionsMobile.agenticTrading';
  static const frequency = Duration(minutes: 15);
  static const backgroundChannelName = 'com.realizealpha.background_execution';
  static const MethodChannel backgroundExecutionChannel = MethodChannel(
    backgroundChannelName,
  );
  static String? _activeCycleDiagnosticId;
  static final _scheduleCoordinator = BackgroundTaskScheduleCoordinator(
    registerTask: _registerPeriodicTask,
    cancelTask: _cancelPeriodicTask,
  );

  /// Queries iOS `BGTaskScheduler` / Background App Refresh or Android battery
  /// optimization readiness over [backgroundExecutionChannel].
  static Future<BackgroundExecutionReadiness> inspectPlatformReadiness({
    MethodChannel? channel,
    TargetPlatform? platformOverride,
    bool recordJournal = false,
  }) async {
    final effectivePlatform = platformOverride ?? defaultTargetPlatform;
    if (kIsWeb ||
        (effectivePlatform != TargetPlatform.iOS &&
            effectivePlatform != TargetPlatform.android)) {
      return BackgroundExecutionReadiness.unsupported();
    }
    final targetChannel = channel ?? backgroundExecutionChannel;
    try {
      final raw = await targetChannel
          .invokeMapMethod<dynamic, dynamic>('getPlatformReadiness');
      if (raw == null) {
        return BackgroundExecutionReadiness.unsupported(
          reason: 'Platform returned no background readiness metadata.',
        );
      }
      final readiness = BackgroundExecutionReadiness.fromChannelMap(
        raw,
        targetPlatform: effectivePlatform,
      );
      if (recordJournal) {
        await _recordLocalEvent(
          event: readiness.isReady
              ? 'platform_readiness_checked'
              : 'platform_readiness_warning',
          reason: readiness.isReady
              ? '${readiness.platform}_ready'
              : '${readiness.platform}_restricted',
        );
      }
      return readiness;
    } on MissingPluginException {
      return BackgroundExecutionReadiness.unsupported(
        reason: 'Native background readiness channel unavailable.',
      );
    } on PlatformException catch (error) {
      return BackgroundExecutionReadiness.unsupported(
        reason: 'Background readiness check failed: ${error.code}',
      );
    }
  }

  /// Opens native iOS App Settings or Android Battery Optimization Settings.
  static Future<bool> openPlatformBackgroundSettings({
    MethodChannel? channel,
    TargetPlatform? platformOverride,
  }) async {
    final effectivePlatform = platformOverride ?? defaultTargetPlatform;
    if (kIsWeb ||
        (effectivePlatform != TargetPlatform.iOS &&
            effectivePlatform != TargetPlatform.android)) {
      return false;
    }
    final targetChannel = channel ?? backgroundExecutionChannel;
    final methodName = effectivePlatform == TargetPlatform.android
        ? 'openBatteryOptimizationSettings'
        : 'openBackgroundSettings';
    try {
      final opened = await targetChannel.invokeMethod<bool>(methodName);
      return opened ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

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
  static String diagnosticFailureReason(Object error) {
    if (error is PlatformException) {
      return '${error.runtimeType}:${error.code}';
    }
    return error.runtimeType.toString();
  }

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

  static Future<bool> runOnce({
    @visibleForTesting AgenticTradingBackgroundHarness? harness,
  }) async {
    _activeCycleDiagnosticId = null;
    await _recordLocalEvent(event: 'run_started');
    if (harness?.ensureFirebaseInitialized != null) {
      await harness!.ensureFirebaseInitialized!();
    } else if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    await _recordLocalEvent(event: 'firebase_ready');
    if (harness == null && !kIsWeb && !kDebugMode) {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: const AndroidPlayIntegrityProvider(),
        providerApple: const AppleDeviceCheckProvider(),
      );
    }
    await _recordLocalEvent(event: 'app_check_ready');

    Future<void> disableScheduling() async {
      if (harness?.syncScheduling != null) {
        await harness!.syncScheduling!(enabled: false);
      } else {
        await syncScheduling(enabled: false);
      }
    }

    await _recordLocalEvent(event: 'auth_wait_started');
    final firebaseUser = harness?.loadFirebaseUser != null
        ? await harness!.loadFirebaseUser!()
        : await FirebaseAuth.instance
            .authStateChanges()
            .first
            .timeout(const Duration(seconds: 10));
    if (firebaseUser == null) {
      await _recordLocalEvent(event: 'auth_missing', reason: 'signed_out');
      await disableScheduling();
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

    final firestoreService = FirestoreService(firestore: harness?.firestore);
    final userDocRef = firestoreService.userCollection.doc(firebaseUser.uid);
    await _recordLocalEvent(
      event: 'user_document_read_started',
      cycleId: cycleId,
    );
    final userSnapshot = await userDocRef.get();
    await _recordLocalEvent(
      event: 'user_document_read_completed',
      cycleId: cycleId,
    );
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
      await disableScheduling();
      return true;
    }

    final brokerageUserStore = harness?.loadBrokerageUserStore != null
        ? await harness!.loadBrokerageUserStore!()
        : BrokerageUserStore([], 0);
    if (harness?.loadBrokerageUserStore == null) {
      await brokerageUserStore.load();
    }
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
      brokerageUserStore.dispose();
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
    final brokerageService =
        (harness?.brokerageServiceFactory ?? brokerageServiceForSource)(
      brokerageUser.source,
    );
    if (brokerageService == null) {
      brokerageUserStore.dispose();
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
      brokerageUserStore.dispose();
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
    final paperStore = harness?.createPaperTradingStore != null
        ? harness!.createPaperTradingStore!()
        : PaperTradingStore(firestore: harness?.firestore);
    final tradeSignalsProvider = TradeSignalsProvider();
    AgenticTradingProvider? provider;

    void disposeResources() {
      provider?.dispose();
      brokerageUserStore.dispose();
      accountStore.dispose();
      portfolioStore.dispose();
      instrumentStore.dispose();
      instrumentPositionStore.dispose();
      optionPositionStore.dispose();
      quoteStore.dispose();
      paperStore.dispose();
      tradeSignalsProvider.dispose();
    }

    try {
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

      provider = harness?.createProvider != null
          ? harness!.createProvider!()
          : AgenticTradingProvider();
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
            now: harness?.nowProvider?.call(),
          );
        }
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

      final evaluationNow = harness?.nowProvider?.call();
      if (config.paperTradingMode) {
        await paperStore.ensureLoaded(firebaseUser);
        final paperOptionStore = OptionInstrumentStore();
        try {
          await paperStore.refreshQuotes(
            brokerageService,
            quoteStore,
            paperOptionStore,
            brokerageUser,
          );
        } finally {
          paperOptionStore.dispose();
        }
        for (final position in paperStore.positions) {
          if ((position.quantity ?? 0) == 0) continue;
          final quote = position.instrumentObj?.quoteObj;
          if (!isFreshQuote(
            updatedAt: quote?.updatedAt,
            price: quote?.lastTradePrice ?? quote?.lastExtendedHoursTradePrice,
            now: evaluationNow,
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
            now: evaluationNow,
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
      if (harness?.runAutoTradeCycle != null) {
        await harness!.runAutoTradeCycle!(
          provider: provider,
          brokerageService: brokerageService,
          userDocRef: userDocRef,
          dependencies: dependencies,
          cycleId: cycleId,
        );
      } else {
        await provider.runAutoTradeCycle(
          brokerageService: brokerageService,
          userDocRef: userDocRef,
          dependencies: dependencies,
          trigger: 'background',
          cycleId: cycleId,
          logStarted: false,
        );
      }
      await _recordLocalEvent(event: 'cycle_returned', cycleId: cycleId);
      return true;
    } finally {
      disposeResources();
    }
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
        reason: AgenticTradingBackgroundService.diagnosticFailureReason(error),
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
