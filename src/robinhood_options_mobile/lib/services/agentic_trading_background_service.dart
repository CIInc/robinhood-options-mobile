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
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
import 'package:robinhood_options_mobile/services/schwab_service.dart';
import 'package:robinhood_options_mobile/utils/market_hours.dart';
import 'package:workmanager/workmanager.dart';

class AgenticTradingBackgroundService {
  static const taskName = 'com.cidevelop.robinhoodOptionsMobile.agenticTrading';
  static const frequency = Duration(minutes: 15);

  @visibleForTesting
  static IBrokerageService? brokerageServiceForSource(
    BrokerageSource source, {
    IBrokerageService Function()? robinhoodFactory,
    IBrokerageService Function()? schwabFactory,
  }) =>
      switch (source) {
        BrokerageSource.robinhood =>
          (robinhoodFactory ?? RobinhoodService.new)(),
        BrokerageSource.schwab => (schwabFactory ?? SchwabService.new)(),
        _ => null,
      };

  static Future<void> initialize() async {
    if (!_isSupportedPlatform) return;
    await Workmanager().initialize(agenticTradingBackgroundDispatcher);
  }

  static Future<void> syncScheduling({required bool enabled}) async {
    if (!_isSupportedPlatform) return;
    if (!enabled) {
      await Workmanager().cancelByUniqueName(taskName);
      return;
    }
    await Workmanager().registerPeriodicTask(
      taskName,
      taskName,
      frequency: frequency,
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  static bool get _isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

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
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    if (!kIsWeb && !kDebugMode) {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: const AndroidPlayIntegrityProvider(),
        providerApple: const AppleDeviceCheckProvider(),
      );
    }

    final firebaseUser = await FirebaseAuth.instance
        .authStateChanges()
        .first
        .timeout(const Duration(seconds: 10));
    if (firebaseUser == null) return true;

    final userDocRef = FirestoreService().userCollection.doc(firebaseUser.uid);
    final userSnapshot = await userDocRef.get();
    final user = userSnapshot.data();
    final config = user?.agenticTradingConfig;
    if (config == null || !config.autoTradeEnabled) {
      await syncScheduling(enabled: false);
      return true;
    }

    final brokerageUserStore = BrokerageUserStore([], 0);
    await brokerageUserStore.load();
    final brokerageUser = brokerageUserStore.currentUser;
    if (brokerageUser == null) {
      await syncScheduling(enabled: false);
      return true;
    }
    final brokerageService = brokerageServiceForSource(brokerageUser.source);
    if (brokerageService == null) {
      await syncScheduling(enabled: false);
      return true;
    }
    brokerageUser.ensureOAuth2Client();
    if (brokerageUser.oauth2Client == null) return false;

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
    if (accounts.isEmpty) return false;
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
    await provider.runAutoTradeCycle(
      brokerageService: brokerageService,
      userDocRef: userDocRef,
      dependencies: dependencies,
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
    return true;
  }
}

@pragma('vm:entry-point')
void agenticTradingBackgroundDispatcher() {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName != AgenticTradingBackgroundService.taskName) return true;
    try {
      return await AgenticTradingBackgroundService.runOnce();
    } catch (error) {
      debugPrint('Agentic background cycle failed: $error');
      return false;
    }
  });
}
