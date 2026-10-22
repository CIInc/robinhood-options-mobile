import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/utils/market_hours.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_store.dart';
import 'package:robinhood_options_mobile/model/trade_signals_provider.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/paper_trading_store.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_config.dart';
import 'package:robinhood_options_mobile/model/macro_assessment.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AgenticTradingProvider with ChangeNotifier {
  final FirebaseAnalytics _analytics;

  AgenticTradingProvider({FirebaseAnalytics? analytics})
      : _analytics = analytics ?? FirebaseAnalytics.instance {
    loadCachedMacroAssessment();
  }

  // Constants
  static const int _tradeDelaySeconds =
      2; // Delay between auto-trades to avoid rate limiting

  /// Simulate paper order without calling broker API
  http.Response _simulatePaperOrder(
    String action,
    String symbol,
    int quantity,
    double price,
  ) {
    // Simulate successful order response
    final simulatedResponse = {
      'id': 'paper_${DateTime.now().millisecondsSinceEpoch}',
      'symbol': symbol,
      'side': action.toLowerCase(),
      'quantity': quantity,
      'price': price,
      'state': 'filled',
      'type': 'market',
      'time_in_force': 'gtc',
      'executions': [
        {
          'price': price.toString(),
          'quantity': quantity.toString(),
          'timestamp': DateTime.now().toIso8601String(),
        }
      ],
    };

    return http.Response(
      jsonEncode(simulatedResponse),
      200,
      headers: {'content-type': 'application/json'},
    );
  }

  AgenticTradingConfig _config =
      AgenticTradingConfig(strategyConfig: TradeStrategyConfig());

  // Auto-trade state tracking
  bool _isAutoTrading = false;
  bool _showAutoTradingVisual =
      false; // Extended visual state (persists for 3s)
  Timer? _autoTradingVisualTimer;
  Timer? _autoTradeTimer;
  DocumentReference? _autoTradeUserDocRef;
  bool _isMonitoringExits = false;
  DateTime? _lastAutoTradeTime;
  int _dailyTradeCount = 0;
  DateTime? _dailyTradeCountResetDate;
  bool _emergencyStopActivated = false;
  final List<Map<String, dynamic>> _autoTradeHistory = [];
  String? _loadingAutoTradeHistoryPath;
  String? _loadedAutoTradeHistoryPath;
  // Track automated BUY trades for TP/SL monitoring (with quantity and entry price)
  // Each entry: {symbol, quantity, entryPrice, timestamp}
  List<Map<String, dynamic>> _automatedBuyTrades = [];
  // Pending orders requiring approval
  final List<Map<String, dynamic>> _pendingOrders = [];

  // Auto-trade timer countdown
  DateTime? _nextAutoTradeTime;
  int _autoTradeCountdownSeconds = 0;

  // Last auto-trade execution result
  Map<String, dynamic>? _lastAutoTradeResult;
  List<Map<String, dynamic>> _signalProcessingHistory = [];

  // Signal processing tracking
  final Map<String, int> _processedSignalTimestamps = {};

  // Activity Log
  final List<String> _activityLog = [];
  final Map<String, DateTime> _recentActivityMessages = {};
  List<String> get activityLog => _activityLog;

  // Macro Assessment
  MacroAssessment? _macroAssessment;
  MacroAssessment? get macroAssessment => _macroAssessment;
  MacroAssessment? _previousMacroAssessment;
  MacroAssessment? get previousMacroAssessment => _previousMacroAssessment;
  List<MacroAssessment> _macroHistory = [];
  List<MacroAssessment> get macroHistory => _macroHistory;
  bool _isAiAnalysisLoading = false;
  bool get isAiAnalysisLoading => _isAiAnalysisLoading;

  Future<void> fetchMacroAssessment({
    bool forceRefresh = false,
    bool includeAiAnalysis = false,
  }) async {
    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('getMacroAssessment');
      final result = await callable.call({
        'forceRefresh': forceRefresh,
        'includeAiAnalysis': includeAiAnalysis,
      });
      if (result.data != null) {
        if (_macroAssessment != null) {
          _previousMacroAssessment = _macroAssessment;
        }
        final dataMap = Map<String, dynamic>.from(result.data);
        _macroAssessment = MacroAssessment.fromMap(dataMap);
        notifyListeners();
        _log(
            "Macro assessment updated: ${_macroAssessment?.status}${forceRefresh ? ' (Refreshed)' : ''}");

        // Cache locally for instant startup display
        _persistCachedMacroAssessment(dataMap);

        // Also fetch history
        await fetchMacroHistory();

        // If AI analysis is not yet present, fetch it asynchronously in the background
        if (_macroAssessment != null &&
            (_macroAssessment!.aiAnalysis == null ||
                _macroAssessment!.aiAnalysis!.isEmpty)) {
          fetchMacroAiAnalysis(forceRefresh: forceRefresh);
        }
      }
    } catch (e) {
      _log("Error fetching macro assessment: $e");
    }
  }

  Future<void> fetchMacroAiAnalysis({bool forceRefresh = false}) async {
    if (_isAiAnalysisLoading) return;
    _isAiAnalysisLoading = true;
    notifyListeners();
    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('getMacroAiAnalysis');
      final result = await callable.call({'forceRefresh': forceRefresh});
      if (result.data != null && result.data['aiAnalysis'] != null) {
        final aiText = result.data['aiAnalysis'] as String;
        if (aiText.isNotEmpty && _macroAssessment != null) {
          _macroAssessment = _macroAssessment!.copyWith(aiAnalysis: aiText);
          notifyListeners();
          _log("Macro AI analysis updated.");
        }
      }
    } catch (e) {
      _log("Error fetching macro AI analysis: $e");
    } finally {
      _isAiAnalysisLoading = false;
      notifyListeners();
    }
  }

  Future<void> _persistCachedMacroAssessment(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_macro_assessment', jsonEncode(data));
    } catch (e) {
      // Ignore local storage error
    }
  }

  Future<void> loadCachedMacroAssessment() async {
    try {
      if (_macroAssessment != null) return;
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('cached_macro_assessment');
      if (cachedJson != null) {
        final data = jsonDecode(cachedJson) as Map<String, dynamic>;
        _macroAssessment = MacroAssessment.fromMap(data);
        notifyListeners();
      }
    } catch (e) {
      // Ignore cache decode error
    }
  }

  Future<void> fetchMacroHistory({int limit = 30}) async {
    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('getMacroHistory');
      final result = await callable.call({'limit': limit});
      if (result.data != null && result.data is List) {
        _macroHistory = (result.data as List)
            .map((item) =>
                MacroAssessment.fromMap(Map<String, dynamic>.from(item)))
            .toList();

        // Set previous assessment from history if not already set by session
        if (_previousMacroAssessment == null && _macroHistory.length > 1) {
          _previousMacroAssessment = _macroHistory[1];
        }

        notifyListeners();
      }
    } catch (e) {
      _log("Error fetching macro history: $e");
    }
  }

  void _log(String message) {
    debugPrint(message);
    final now = DateTime.now();
    _recentActivityMessages.removeWhere(
      (_, loggedAt) => now.difference(loggedAt) >= const Duration(seconds: 5),
    );
    if (_recentActivityMessages.containsKey(message)) {
      return;
    }
    _recentActivityMessages[message] = now;
    final timeStr =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    _activityLog.insert(0, '[$timeStr] $message');
    // Keep log manageable
    if (_activityLog.length > 200) {
      _activityLog.removeLast();
    }
    notifyListeners();
  }

  void clearLog() {
    _activityLog.clear();
    _recentActivityMessages.clear();
    _processedSignalTimestamps.clear();
    notifyListeners();
  }

  AgenticTradingConfig get config => _config;

  // Auto-trade getters
  bool get isAutoTrading => _isAutoTrading;
  bool get showAutoTradingVisual =>
      _showAutoTradingVisual; // Visual persists 3s after trade
  DateTime? get lastAutoTradeTime => _lastAutoTradeTime;
  int get dailyTradeCount => _dailyTradeCount;

  int _executedOrderCount = 0;

  /// Bumps for every order the auto-trader executes (entries, approvals, exits) so screens can refetch orders.
  int get executedOrderCount => _executedOrderCount;
  bool get emergencyStopActivated => _emergencyStopActivated;
  List<Map<String, dynamic>> get autoTradeHistory => _autoTradeHistory;
  List<Map<String, dynamic>> get pendingOrders => _pendingOrders;
  DateTime? get nextAutoTradeTime => _nextAutoTradeTime;
  int get autoTradeCountdownSeconds => _autoTradeCountdownSeconds;
  // Is this property needed if we have autoTradeHistory?
  Map<String, dynamic>? get lastAutoTradeResult => _lastAutoTradeResult;
  List<Map<String, dynamic>> get signalProcessingHistory =>
      _signalProcessingHistory;

  /// Initialize the timer's next trade time (called from navigation widget when timer starts)
  void initializeAutoTradeTimer() {
    final interval = _config.checkIntervalMinutes;
    _nextAutoTradeTime = DateTime.now().add(Duration(minutes: interval));
    _autoTradeCountdownSeconds = interval * 60;
    notifyListeners();
  }

  /// Tick the countdown and check if it's time to reset
  /// Returns true if countdown reached 0 and should be reset
  bool tickAutoTradeCountdown() {
    if (_nextAutoTradeTime == null) return false;

    final now = DateTime.now();
    final remaining = _nextAutoTradeTime!.difference(now).inSeconds;

    if (remaining <= 0) {
      // Time to reset for next cycle
      resetAutoTradeCountdownForNextCycle();
      return true;
    }

    // Update countdown
    _autoTradeCountdownSeconds = remaining;
    notifyListeners();
    return false;
  }

  /// Reset countdown for the next 5-minute cycle
  void resetAutoTradeCountdownForNextCycle() {
    final interval = _config.checkIntervalMinutes;
    _nextAutoTradeTime = DateTime.now().add(Duration(minutes: interval));
    _autoTradeCountdownSeconds = interval * 60;
    notifyListeners();
  }

  /// Update the auto-trade countdown (called from settings widget to manually set countdown)
  void updateAutoTradeCountdown(DateTime nextTime, int secondsRemaining) {
    _nextAutoTradeTime = nextTime;
    _autoTradeCountdownSeconds = secondsRemaining;
    notifyListeners();
  }

  /// Update the last auto-trade execution result
  void updateLastAutoTradeResult(Map<String, dynamic> result) {
    _lastAutoTradeResult = Map<String, dynamic>.from(result);
    if (!_lastAutoTradeResult!.containsKey('timestamp')) {
      _lastAutoTradeResult!['timestamp'] = DateTime.now().toIso8601String();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _log('🧹 Disposing AgenticTradingProvider');
    _autoTradingVisualTimer?.cancel();
    _autoTradeTimer?.cancel();
    super.dispose();
  }

  /// Schedules the visual state to reset after 3 seconds
  void _scheduleVisualStateReset() {
    _autoTradingVisualTimer?.cancel();
    _autoTradingVisualTimer = Timer(const Duration(seconds: 3), () {
      _showAutoTradingVisual = false;
      notifyListeners();
    });
  }

  /// Starts the auto-trade timer that periodically checks for and executes auto-trades
  void startAutoTradeTimer({
    required BuildContext context,
    required dynamic brokerageService,
    DocumentReference? userDocRef,
  }) {
    // The timer outlives the first call, which can happen before the user doc loads.
    _autoTradeUserDocRef = userDocRef;

    // Prevent duplicate timers
    if (_autoTradeTimer != null && _autoTradeTimer!.isActive) {
      // _log('🤖 Auto-trade timer already running, skipping start');
      return;
    }

    _autoTradeTimer?.cancel();

    // Initialize countdown
    initializeAutoTradeTimer();

    _autoTradeTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final countdownReachedZero = tickAutoTradeCountdown();
      if (!countdownReachedZero) return;

      await runAutoTradeCycle(
        context: context,
        brokerageService: brokerageService,
        userDocRef: _autoTradeUserDocRef,
      );
    });

    _log('🤖 Auto-trade timer started'); // (provider-owned, 5-minute cadence)
  }

  /// Manually triggers an auto-trade cycle
  Future<void> runAutoTradeCycle({
    required BuildContext context,
    required dynamic brokerageService,
    DocumentReference? userDocRef,
  }) async {
    if (_isAutoTrading) {
      _log('⚠️ Auto-trade cycle already in progress');
      return;
    }

    try {
      _log('🤖 Starting auto-trade cycle...');
      // Gather required providers from context lazily
      final userStore = Provider.of<BrokerageUserStore>(context, listen: false);
      final accountStore = Provider.of<AccountStore>(context, listen: false);
      final instrumentStore =
          Provider.of<InstrumentStore>(context, listen: false);
      final portfolioStore =
          Provider.of<PortfolioStore>(context, listen: false);
      final tradeSignalsProvider =
          Provider.of<TradeSignalsProvider>(context, listen: false);
      final instrumentPositionStore =
          Provider.of<InstrumentPositionStore>(context, listen: false);
      final optionPositionStore =
          Provider.of<OptionPositionStore>(context, listen: false);
      final paperTradingStore =
          Provider.of<PaperTradingStore>(context, listen: false);

      // Check auto-trade enabled
      final autoTradeEnabled = _config.autoTradeEnabled;
      if (!autoTradeEnabled) {
        _log('🤖 Auto-trade check: disabled in config');
        return;
      }

      final isPaperMode = _config.paperTradingMode;
      final executedBeforeCycle = _executedOrderCount;
      final quoteStore = Provider.of<QuoteStore>(context, listen: false);

      // Validate user/account
      if (!isPaperMode &&
          (userStore.items.isEmpty ||
              userStore.currentUser == null ||
              accountStore.items.isEmpty)) {
        _log('❌ Auto-trade check: missing user or account data');
        return;
      }

      final currentUser = userStore.currentUser;
      final firstAccount =
          accountStore.items.isNotEmpty ? accountStore.items.first : null;
      if (!isPaperMode && currentUser == null) {
        _log('❌ Auto-trade check: currentUser is null');
        return;
      }

      // Build portfolio state
      final Map<String, dynamic> portfolioState = isPaperMode
          ? {
              'portfolioValue': paperTradingStore.equity,
              'buyingPower': paperTradingStore.cashBalance,
              'cashAvailable': paperTradingStore.cashBalance,
              'positions': paperTradingStore.positions.length +
                  paperTradingStore.optionPositions.length,
            }
          : {
              'portfolioValue': portfolioStore.items.isNotEmpty
                  ? portfolioStore.items.first.equity
                  : 0.0,
              'buyingPower': firstAccount?.buyingPower ?? 0.0,
              'cashAvailable': firstAccount?.portfolioCash ?? 0.0,
              'positions': portfolioStore.items.length,
            };

      // Add stock positions
      final stockPositions = isPaperMode
          ? paperTradingStore.positions
          : instrumentPositionStore.items;
      for (var pos in stockPositions) {
        if (pos.instrumentObj != null &&
            pos.quantity != null &&
            pos.quantity! != 0) {
          double? price = pos.instrumentObj!.quoteObj?.lastTradePrice ??
              pos.averageBuyPrice;
          if (price != null) {
            portfolioState[pos.instrumentObj!.symbol] = {
              'quantity': pos.quantity,
              'price': price
            };
          }
        }
      }

      // Add option positions
      final optionPositions = isPaperMode
          ? paperTradingStore.optionPositions
          : optionPositionStore.items;
      for (var pos in optionPositions) {
        if (pos.optionInstrument != null &&
            pos.quantity != null &&
            pos.quantity! != 0) {
          double? price =
              pos.optionInstrument!.optionMarketData?.adjustedMarkPrice ??
                  pos.averageOpenPrice;
          if (price != null) {
            // Use position ID as key since we don't have a simple option symbol
            // and we want to ensure uniqueness and inclusion in total value
            portfolioState[pos.id] = {
              'quantity':
                  (pos.quantity ?? 0) * 100, // Adjust for contract multiplier
              'price': price
            };
          }
        }
      }

      final minSignalStrength =
          _config.strategyConfig.minSignalStrength.toInt();

      int minStrengthFilter = minSignalStrength;

      // Determine start date for signal fetch (since last run or recent window)
      // Default to 60 minutes lookback on first run to avoid processing ancient signals
      // final startDate = _lastSignalCheckTime ??
      //     DateTime.now().subtract(const Duration(minutes: 60));
      final startDate = DateTime.now().subtract(const Duration(days: 5));

      _log(
          '📡 Fetching signals since ${startDate.month}/${startDate.day} ${startDate.hour}:${startDate.minute}');

      // Filter by symbol whitelist if configured
      final symbolFilter = _config.strategyConfig.symbolFilter;
      List<String>? symbols;
      if (symbolFilter.isNotEmpty) {
        symbols = symbolFilter.map((e) => e.toString().toUpperCase()).toList();
        // _log('🤖 Auto-trade check: filtering for allowed symbols: $symbols');
        _log('🔍 Filtering for allowed symbols: ${symbols.length}');
      }

      List<Map<String, dynamic>> tradeSignals;

      // In Reasoning mode, we're more lenient with initial signal fetching
      // to allow the AI to "discover" opportunities the deterministic algo might have missed
      // or marked as HOLD but with high confidence.
      final isReasoningMode = _config.tradingMode == TradingMode.reasoning;

      final enabledIndicatorMap = _config.strategyConfig.enabledIndicators;
      final activeIndicatorKeys = enabledIndicatorMap.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();
      // Stored signals are scored with every default indicator, so a custom indicator subset can't be matched on the overall signal or strength.
      final matchByIndicators = !isReasoningMode &&
          activeIndicatorKeys.isNotEmpty &&
          activeIndicatorKeys.length < enabledIndicatorMap.length;

      if (matchByIndicators) {
        tradeSignals = await tradeSignalsProvider.fetchSignals(
          indicatorFilters: activeIndicatorKeys.length == 1
              ? {activeIndicatorKeys.first: 'BUY'}
              : null,
          sortBy: 'signalStrength',
          interval: _config.strategyConfig.interval,
        );
        // fetchSignals reads at most 200 docs, so a full page may hide matching signals.
        if (tradeSignals.length >= 200) {
          _log(
              '\u26a0\ufe0f Signal query hit its 200-document cap; some signals matching the enabled indicators may be missing');
        }
        final cutoffMs = startDate.millisecondsSinceEpoch;
        tradeSignals = tradeSignals.where((s) {
          final ts = (s['timestamp'] as num?)?.toInt();
          if (ts == null || ts < cutoffMs) return false;
          return symbols == null ||
              symbols.contains((s['symbol'] as String?)?.toUpperCase());
        }).toList();
      } else if (symbols != null && symbols.isNotEmpty) {
        tradeSignals = await tradeSignalsProvider.fetchSignals(
          signalType: isReasoningMode ? null : 'BUY',
          minSignalStrength: isReasoningMode ? 40 : minStrengthFilter,
          sortBy: 'signalStrength',
          startDate: startDate,
          symbols: symbols,
          interval: _config.strategyConfig.interval,
        );
      } else {
        tradeSignals = await tradeSignalsProvider.fetchSignals(
          signalType: isReasoningMode ? null : 'BUY',
          minSignalStrength: isReasoningMode ? 40 : minStrengthFilter,
          // Used to sort by timestamp, consider the implications of such a decision, the latest signals may not get picked up
          // sortBy: 'timestamp',
          sortBy: 'signalStrength',
          startDate: startDate,
          interval: _config.strategyConfig.interval,
        );
      }

      final fetchError = tradeSignalsProvider.lastFetchSignalsError;
      if (fetchError != null) {
        _log('❌ Signal query failed: $fetchError');
      }
      _log(
          '📡 Fetched ${tradeSignals.length} signals (${matchByIndicators ? "by enabled indicators" : "overall BUY"})');

      // Filter out already processed signals (deduplication)
      final originalCount = tradeSignals.length;
      tradeSignals = tradeSignals.where((s) {
        final symbol = s['symbol'] as String?;
        final timestamp = s['timestamp'] as int?;
        if (symbol == null || timestamp == null) return false;

        final signalId = '${symbol}_$timestamp';
        return !_processedSignalTimestamps.containsKey(signalId);
      }).toList();

      if (originalCount != tradeSignals.length) {
        _log(
            '🗑️ Filtered ${originalCount - tradeSignals.length} duplicate signals');
      }

      _log('📥 Processing ${tradeSignals.length} new signals');

      final result = await autoTrade(
        tradeSignals: tradeSignals,
        tradeSignalsProvider: tradeSignalsProvider,
        portfolioState: portfolioState,
        brokerageUser: currentUser,
        account: firstAccount,
        brokerageService: brokerageService,
        instrumentStore: instrumentStore,
        paperTradingStore: paperTradingStore,
        userDocRef: userDocRef,
        quoteStore: quoteStore,
      );

      // A blocked cycle (market closed, daily limit, cooldown) never evaluated
      // these signals, so they must stay eligible for the next cycle.
      rememberProcessedSignals(tradeSignals, result);

      if (result['tradesExecuted'] > 0) {
        final count = result['tradesExecuted'];
        final symbols = (result['trades'] as List)
            .map((t) => t['symbol'])
            .toSet()
            .join(', ');
        final msg =
            result['message'] ?? 'Executed $count auto-trades: $symbols';
        _log('✅ $msg');
      } else if (tradeSignals.isNotEmpty) {
        _log('ℹ️ No trades executed from ${tradeSignals.length} signals');
      }

      updateLastAutoTradeResult(result);

      // Prune processed signals older than 24 hours
      final cutoff = DateTime.now()
          .subtract(const Duration(hours: 24))
          .millisecondsSinceEpoch;
      _processedSignalTimestamps.removeWhere((_, ts) => ts < cutoff);

      // Monitor TP/SL when positions exist
      // final instrumentPositionStore =
      //    Provider.of<InstrumentPositionStore>(context, listen: false);

      final positionsToMonitor = isPaperMode
          ? paperTradingStore.positions
          : instrumentPositionStore.items;

      if (positionsToMonitor.isNotEmpty) {
        // _log('📊 Monitoring ${positionsToMonitor.length} positions for TP/SL');
        final tpSlResult = await monitorTakeProfitStopLoss(
          positions: positionsToMonitor,
          brokerageUser: currentUser,
          account: firstAccount,
          brokerageService: brokerageService,
          instrumentStore: instrumentStore,
          paperTradingStore: paperTradingStore,
          userDocRef: userDocRef,
        );
        // _log(
        //     '📊 TP/SL result: ${tpSlResult['success']}, exits: ${tpSlResult['exitsExecuted']}, message: ${tpSlResult['message']}');
        if (tpSlResult['exitsExecuted'] > 0) {
          _log('📊 TP/SL result: ${tpSlResult['message']}');

          // Merge exits into result for Last Execution display
          final exits = tpSlResult['exits'] as List;
          final currentTrades = result['trades'] as List? ?? [];
          final allTrades = [...currentTrades, ...exits];

          result['trades'] = allTrades;
          result['tradesExecuted'] = (result['tradesExecuted'] as int? ?? 0) +
              (tpSlResult['exitsExecuted'] as int);

          if (tpSlResult['message'] != null &&
              tpSlResult['message'] != 'No exits required') {
            result['message'] =
                "${result['message']} | ${tpSlResult['message']}";
          }
          result['success'] = true; // Mark as success since action was taken

          updateLastAutoTradeResult(result);
        }
      } else {
        _log('📊 No positions to monitor for TP/SL');
      }

      if (!isPaperMode &&
          currentUser != null &&
          _executedOrderCount != executedBeforeCycle) {
        await _refreshStockPositions(
          brokerageService: brokerageService,
          brokerageUser: currentUser,
          store: instrumentPositionStore,
          instrumentStore: instrumentStore,
          quoteStore: quoteStore,
        );
      }
      _log('✅ Auto-trade cycle complete.');
    } catch (e) {
      _log('❌ Auto-trade error: $e');
    }
  }

  bool _hasLoadedConfig = false;

  /// True once a config came from the user document or a settings save.
  bool get hasLoadedConfig => _hasLoadedConfig;

  /// Load configuration from User model
  void loadConfigFromUser(AgenticTradingConfig? agenticTradingConfig) {
    _hasLoadedConfig = true;
    if (agenticTradingConfig != null) {
      _config = agenticTradingConfig;
      _analytics.logEvent(name: 'agentic_trading_config_loaded_from_user');
    } else {
      _config = AgenticTradingConfig(strategyConfig: TradeStrategyConfig());
      _analytics.logEvent(name: 'agentic_trading_config_loaded_defaults');
    }
    _forgetProcessedSignalsIfRulesChanged();
    notifyListeners();
  }

  String? _signalRulesSignature;

  /// Marks [signals] processed unless the cycle was blocked before evaluating them.
  @visibleForTesting
  void rememberProcessedSignals(
      List<Map<String, dynamic>> signals, Map<String, dynamic> result) {
    if (result['blocked'] == true) return;
    for (final signal in signals) {
      final symbol = signal['symbol'] as String?;
      final timestamp = signal['timestamp'] as int?;
      if (symbol != null && timestamp != null) {
        _processedSignalTimestamps['${symbol}_$timestamp'] = timestamp;
      }
    }
  }

  @visibleForTesting
  bool hasProcessedSignal(String symbol, int timestamp) =>
      _processedSignalTimestamps.containsKey('${symbol}_$timestamp');

  /// Signals rejected under old entry rules must be re-evaluated under new ones.
  void _forgetProcessedSignalsIfRulesChanged() {
    final s = _config.strategyConfig;
    final signature = [
      s.enabledIndicators.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList()
        ..sort(),
      s.requireAllIndicatorsGreen,
      s.minSignalStrength,
      s.interval,
      s.symbolFilter,
      s.customIndicators.map((c) => c.id).toList(),
      _config.tradingMode,
      _config.requireApproval,
    ].join('|');
    if (_signalRulesSignature != null && _signalRulesSignature != signature) {
      _processedSignalTimestamps.clear();
    }
    _signalRulesSignature = signature;
  }

  /// Queued approvals came from the old setting; the next cycle re-proposes qualified signals and executes them directly.
  Future<void> _discardPendingApprovals(DocumentReference userDocRef) async {
    _pendingOrders.clear();
    try {
      final snapshot = await userDocRef.collection('pending_orders').get();
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
      if (snapshot.docs.isNotEmpty) {
        _log(
            '🧹 Cleared ${snapshot.docs.length} pending approvals: Require Approval is off');
      }
    } catch (e) {
      _log('❌ Failed to clear pending approvals: $e');
    }
  }

  /// Update configuration and save to User document
  Future<void> updateConfig(
    AgenticTradingConfig newConfig,
    DocumentReference userDocRef,
  ) async {
    final approvalTurnedOff =
        _config.requireApproval && !newConfig.requireApproval;
    _config = newConfig;
    _hasLoadedConfig = true;
    _forgetProcessedSignalsIfRulesChanged();

    try {
      await userDocRef.update({'agenticTradingConfig': newConfig.toJson()});
      _analytics.logEvent(name: 'agentic_trading_config_updated');
    } catch (e) {
      _log('❌ Failed to save auto-trade settings: $e');
      _analytics.logEvent(
        name: 'agentic_trading_config_update_failed',
        parameters: {'error': e.toString()},
      );
    }
    if (approvalTurnedOff) await _discardPendingApprovals(userDocRef);
    notifyListeners();
  }

  /// Save automated buy trades to Firestore
  // Saves run one at a time; overlapping delete-then-add cycles duplicated every tracked trade.
  Future<void> _tradesSaveQueue = Future.value();
  int _pendingTradeSaves = 0;

  Future<void> _saveAutomatedBuyTradesToFirestore(
      DocumentReference? userDocRef) {
    _pendingTradeSaves++;
    final write =
        _tradesSaveQueue.then((_) => _writeAutomatedBuyTrades(userDocRef));
    // The caller stops waiting early, but the queue only advances once the write
    // ends (or a long cap), so a slow write never overlaps the next one.
    _tradesSaveQueue = write
        .timeout(const Duration(minutes: 2))
        .catchError((_) {})
        .whenComplete(() {
      _pendingTradeSaves--;
    });
    return write.timeout(const Duration(seconds: 20),
        onTimeout: () => _log('⏱️ Saving automated buy trades timed out'));
  }

  /// Stable document id for a tracked trade, so saves upsert instead of re-adding.
  static String automatedTradeDocId(Map<String, dynamic> trade) {
    final raw = '${trade['symbol']}_${trade['timestamp']}_'
        '${trade['initialQuantity'] ?? trade['quantity']}_${trade['entryPrice']}';
    return raw.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  }

  List<Map<String, dynamic>> get automatedBuyTrades => _automatedBuyTrades;

  @visibleForTesting
  Future<void> saveAutomatedBuyTrades(DocumentReference? userDocRef) =>
      _saveAutomatedBuyTradesToFirestore(userDocRef);

  Future<void> _writeAutomatedBuyTrades(DocumentReference? userDocRef) async {
    if (userDocRef == null) {
      _log('⚠️ Cannot save automated buy trades: userDocRef is null');
      return;
    }

    try {
      // Store in a subcollection under the user document
      final tradesCollection = userDocRef.collection('automated_buy_trades');
      final firestore = userDocRef.firestore;

      // Upsert by stable id, then delete what is no longer tracked. Writing
      // before deleting means an interrupted save can leave a stale trade
      // behind but never loses a tracked one.
      final timer = Stopwatch()..start();
      final existingDocs = await tradesCollection.get();
      _log(
          '🔎 automated_buy_trades: ${existingDocs.docs.length} stored docs read in ${timer.elapsedMilliseconds}ms');
      final desired = <String, Map<String, dynamic>>{
        for (final trade in List<Map<String, dynamic>>.of(_automatedBuyTrades))
          automatedTradeDocId(trade): trade,
      };
      var batch = firestore.batch();
      var operations = 0;
      Future<void> flush() async {
        if (operations == 0) return;
        await batch.commit();
        batch = firestore.batch();
        operations = 0;
      }

      for (final entry in desired.entries) {
        batch.set(tradesCollection.doc(entry.key), entry.value);
        if (++operations >= 400) await flush();
      }
      for (final doc in existingDocs.docs) {
        if (desired.containsKey(doc.id)) continue;
        batch.delete(doc.reference);
        if (++operations >= 400) await flush();
      }
      await flush();

      _log(
          '💾 Saved ${_automatedBuyTrades.length} automated buy trades to Firestore in ${timer.elapsedMilliseconds}ms');
      _analytics.logEvent(
        name: 'agentic_trading_trades_saved',
        parameters: {'count': _automatedBuyTrades.length},
      );
    } catch (e) {
      _log('❌ Failed to save automated buy trades to Firestore: $e');
      _analytics.logEvent(
        name: 'agentic_trading_trades_save_failed',
        parameters: {'error': e.toString()},
      );
    }
  }

  /// Load automated buy trades from Firestore
  Future<void> loadAutomatedBuyTradesFromFirestore(
      DocumentReference? userDocRef) async {
    if (userDocRef == null) {
      _log('⚠️ Cannot load automated buy trades: userDocRef is null');
      return;
    }
    // A reload would overwrite in-memory changes the server hasn't acknowledged yet.
    if (_pendingTradeSaves > 0) return;

    try {
      final tradesCollection = userDocRef.collection('automated_buy_trades');
      final snapshot = await tradesCollection.get();

      _automatedBuyTrades =
          snapshot.docs.map((doc) => doc.data()).where((trade) {
        // Validate required fields exist and have correct types
        return trade.containsKey('symbol') &&
            trade['symbol'] is String &&
            trade.containsKey('quantity') &&
            trade['quantity'] is int &&
            trade.containsKey('entryPrice') &&
            trade['entryPrice'] is double &&
            trade.containsKey('timestamp') &&
            trade['timestamp'] is String;
      }).toList();
      // Stored copies can briefly coexist (legacy random ids and stable ids).
      final seenIds = <String>{};
      _automatedBuyTrades
          .removeWhere((trade) => !seenIds.add(automatedTradeDocId(trade)));

      // _log(
      //     '📥 Loaded ${_automatedBuyTrades.length} automated buy trades from Firestore');
      if (_automatedBuyTrades.isNotEmpty) {
        final symbols = _automatedBuyTrades
            .map((t) => '${t['symbol']} x${t['quantity']}')
            .join(', ');
        _log('📝 Automated buy trades: $symbols');
      }

      _analytics.logEvent(
        name: 'agentic_trading_trades_loaded',
        parameters: {'count': _automatedBuyTrades.length},
      );

      notifyListeners();
    } catch (e) {
      _log('❌ Failed to load automated buy trades from Firestore: $e');
      _analytics.logEvent(
        name: 'agentic_trading_trades_load_failed',
        parameters: {'error': e.toString()},
      );
    }
  }

  /// Load auto-trade history from Firestore
  Future<void> loadAutoTradeHistoryFromFirestore(
      DocumentReference? userDocRef) async {
    if (userDocRef == null) {
      _log('⚠️ Cannot load auto-trade history: userDocRef is null');
      return;
    }

    final userPath = userDocRef.path;
    if (_loadingAutoTradeHistoryPath == userPath ||
        _loadedAutoTradeHistoryPath == userPath) {
      return;
    }
    _loadingAutoTradeHistoryPath = userPath;

    try {
      final historyCollection = userDocRef.collection('auto_trade_history');
      final snapshot = await historyCollection
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      _autoTradeHistory.clear();
      _autoTradeHistory.addAll(
        snapshot.docs.map((doc) => withDerivedProfitLoss(doc.data())),
      );

      _loadedAutoTradeHistoryPath = userPath;
      _log('📖 Loaded ${_autoTradeHistory.length} trade history records');
      notifyListeners();
    } catch (e) {
      _log('❌ Failed to load auto-trade history: $e');
    } finally {
      if (_loadingAutoTradeHistoryPath == userPath) {
        _loadingAutoTradeHistoryPath = null;
      }
    }
  }

  /// Add a single trade to Firestore history
  Future<void> _addTradeToHistoryFirestore(
      Map<String, dynamic> tradeRecord, DocumentReference? userDocRef) async {
    if (userDocRef == null) return;

    try {
      await userDocRef.collection('auto_trade_history').add(tradeRecord);
    } catch (e) {
      _log('❌ Failed to save trade to history: $e');
    }
  }

  /// Add a single pending order to Firestore
  Future<void> _addPendingOrderToFirestore(
      DocumentReference userDocRef, Map<String, dynamic> order) async {
    try {
      final ordersCollection = userDocRef.collection('pending_orders');
      final orderToSave = Map<String, dynamic>.from(order);

      // Remove UI-specific or complex objects before saving
      if (orderToSave.containsKey('instrument') &&
          orderToSave['instrument'] is! String &&
          orderToSave['instrument'] is! Map) {
        orderToSave.remove('instrument');
      }
      // Remove internal ID if present to avoid confusion, or keep it.
      // Firestore will generate its own ID, which we'll store in 'firestoreId'

      final docRef = await ordersCollection.add(orderToSave);
      order['firestoreId'] = docRef.id;

      _log('💾 Added pending order to Firestore: ${docRef.id}');
    } catch (e) {
      _log('❌ Failed to add pending order to Firestore: $e');
    }
  }

  /// Update an existing pending order in Firestore
  Future<void> _updatePendingOrderInFirestore(
      DocumentReference userDocRef, Map<String, dynamic> order) async {
    try {
      final firestoreId = order['firestoreId'] as String?;
      if (firestoreId == null) {
        await _addPendingOrderToFirestore(userDocRef, order);
        return;
      }

      final ordersCollection = userDocRef.collection('pending_orders');
      final orderToSave = Map<String, dynamic>.from(order);

      // Remove UI-specific or complex objects before saving
      if (orderToSave.containsKey('instrument') &&
          orderToSave['instrument'] is! String &&
          orderToSave['instrument'] is! Map) {
        orderToSave.remove('instrument');
      }

      await ordersCollection.doc(firestoreId).update(orderToSave);
      _log('💾 Updated pending order in Firestore: $firestoreId');
    } catch (e) {
      _log('❌ Failed to update pending order in Firestore: $e');
    }
  }

  /// Remove a single pending order from Firestore
  Future<void> _removePendingOrderFromFirestore(
      DocumentReference userDocRef, Map<String, dynamic> order) async {
    try {
      final firestoreId = order['firestoreId'] as String?;
      if (firestoreId == null) {
        _log('⚠️ Cannot remove pending order: missing firestoreId');
        // Fallback: try to find by internal ID if available, or just return
        // For now, we assume firestoreId is present if loaded/saved correctly
        return;
      }

      final ordersCollection = userDocRef.collection('pending_orders');
      await ordersCollection.doc(firestoreId).delete();

      _log('🗑️ Removed pending order from Firestore: $firestoreId');
    } catch (e) {
      _log('❌ Failed to remove pending order from Firestore: $e');
    }
  }

  /// Load pending orders from Firestore
  Future<void> loadPendingOrdersFromFirestore(
      DocumentReference? userDocRef) async {
    if (userDocRef == null) {
      _log('⚠️ Cannot load pending orders: userDocRef is null');
      return;
    }

    try {
      final ordersCollection = userDocRef.collection('pending_orders');
      final snapshot = await ordersCollection.get();

      _pendingOrders.clear();

      for (final doc in snapshot.docs) {
        final order = doc.data();
        // Basic validation
        if (order.containsKey('symbol') &&
            order.containsKey('quantity') &&
            order.containsKey('action')) {
          // Store the Firestore document ID for future updates/deletes
          order['firestoreId'] = doc.id;
          final symbol = (order['symbol'] as String?)?.toUpperCase();
          final action = (order['action'] as String?)?.toUpperCase();

          final existingIndex = _pendingOrders.indexWhere((o) =>
              (o['symbol'] as String?)?.toUpperCase() == symbol &&
              (o['action'] as String?)?.toUpperCase() == action);

          if (existingIndex != -1) {
            // Duplicate detected from Firestore collection
            final existingOrder = _pendingOrders[existingIndex];
            final existingTime = DateTime.tryParse(
                    existingOrder['timestamp'] as String? ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final orderTime =
                DateTime.tryParse(order['timestamp'] as String? ?? '') ??
                    DateTime.fromMillisecondsSinceEpoch(0);

            if (orderTime.isAfter(existingTime)) {
              // Delete older duplicate from Firestore
              final oldFirestoreId = existingOrder['firestoreId'] as String?;
              if (oldFirestoreId != null) {
                ordersCollection.doc(oldFirestoreId).delete().catchError((e) {
                  _log('❌ Failed to delete duplicate pending order: $e');
                });
              }
              _pendingOrders[existingIndex] = order;
            } else {
              // Current doc is older duplicate; delete it
              doc.reference.delete().catchError((e) {
                _log('❌ Failed to delete duplicate pending order: $e');
              });
            }
          } else {
            _pendingOrders.add(order);
          }
        }
      }

      // _log('📥 Loaded ${_pendingOrders.length} pending orders from Firestore');

      _analytics.logEvent(
        name: 'agentic_trading_pending_orders_loaded',
        parameters: {'count': _pendingOrders.length},
      );

      notifyListeners();
    } catch (e) {
      _log('❌ Failed to load pending orders from Firestore: $e');
      _analytics.logEvent(
        name: 'agentic_trading_pending_orders_load_failed',
        parameters: {'error': e.toString()},
      );
    }
  }

  // Public getter for market status (delegates to utility)
  bool get isMarketOpen {
    final allowPreMarket = _config.allowPreMarketTrading;
    final allowAfterHours = _config.allowAfterHoursTrading;
    final includeExtended = allowPreMarket || allowAfterHours;
    return MarketHours.isMarketOpen(includeExtendedHours: includeExtended);
  }

  /// Activates emergency stop to halt all auto-trading
  void activateEmergencyStop({DocumentReference? userDocRef}) {
    _emergencyStopActivated = true;
    _analytics.logEvent(
      name: 'agentic_trading_emergency_stop',
      parameters: {'reason': 'manual_activation'},
    );
    // Send push notification if enabled
    if (_config.notifyOnEmergencyStop) {
      _sendTradeNotification(userDocRef, 'emergency_stop');
    }
    notifyListeners();
  }

  /// Deactivates emergency stop to resume auto-trading
  void deactivateEmergencyStop() {
    _emergencyStopActivated = false;
    _analytics.logEvent(name: 'agentic_trading_emergency_stop_deactivated');
    notifyListeners();
  }

  /// Sends a daily summary notification using current trade history
  Future<void> sendDailySummary(DocumentReference? userDocRef) async {
    if (!_config.notifyDailySummary) {
      return;
    }

    // Aggregate simple stats from today's trades
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int totalTrades = 0;
    int wins = 0;
    int losses = 0;
    double totalPnL = 0.0;

    for (final trade in _autoTradeHistory) {
      final ts = trade['timestamp'];
      DateTime? dt;
      if (ts is String) {
        dt = DateTime.tryParse(ts);
      } else if (ts is int) {
        dt = DateTime.fromMillisecondsSinceEpoch(ts);
      }
      if (dt == null) continue;
      final dkey = DateTime(dt.year, dt.month, dt.day);
      if (dkey != today) continue;

      totalTrades += 1;
      final profitLoss =
          (trade['profitLoss'] as num?)?.toDouble(); // may be null
      if (profitLoss != null) {
        totalPnL += profitLoss;
        if (profitLoss > 0) {
          wins += 1;
        } else if (profitLoss < 0) {
          losses += 1;
        }
      }
    }

    await _sendTradeNotification(
      userDocRef,
      'daily_summary',
      dailyStats: {
        'totalTrades': totalTrades,
        'wins': wins,
        'losses': losses,
        'totalPnL': totalPnL,
      },
    );
  }

  /// getStockPositionStore only adds or updates, so load a scratch store and
  /// prune the sold-out positions from the shared one.
  Future<void> _refreshStockPositions({
    required dynamic brokerageService,
    required dynamic brokerageUser,
    required InstrumentPositionStore store,
    required InstrumentStore instrumentStore,
    required QuoteStore quoteStore,
  }) async {
    try {
      final fresh = await brokerageService.getStockPositionStore(brokerageUser,
          InstrumentPositionStore(), instrumentStore, quoteStore);
      final accountNumbers = <String>{
        for (final account in brokerageUser.accounts) account.accountNumber,
      };
      syncPositions(store, fresh.items, accountNumbers);
      _log('🔄 Refreshed stock positions after executed orders');
    } catch (e) {
      _log('⚠️ Could not refresh stock positions: $e');
    }
  }

  /// Replaces [store] contents for [accountNumbers] with [fresh]; other accounts stay untouched.
  static void syncPositions(InstrumentPositionStore store,
      Iterable<InstrumentPosition> fresh, Set<String> accountNumbers) {
    final keep = {
      for (final p in fresh) '${p.accountNumber}|${p.instrumentId}',
    };
    store.removeWhere((p) =>
        accountNumbers.contains(p.accountNumber) &&
        !keep.contains('${p.accountNumber}|${p.instrumentId}'));
    for (final p in fresh) {
      store.addOrUpdate(p);
    }
  }

  /// Counts history records executed on [day] (local time); unlike
  /// [dailyTradeCount] it survives restarts and includes exits.
  static int countTradesOn(
      Iterable<Map<String, dynamic>> history, DateTime day) {
    var count = 0;
    for (final trade in history) {
      final ts = trade['timestamp'];
      final DateTime? dt = switch (ts) {
        String s => DateTime.tryParse(s)?.toLocal(),
        int ms => DateTime.fromMillisecondsSinceEpoch(ms),
        Timestamp t => t.toDate(),
        _ => null,
      };
      if (dt != null &&
          dt.year == day.year &&
          dt.month == day.month &&
          dt.day == day.day) {
        count++;
      }
    }
    return count;
  }

  /// Older exit records stored only prices; derive their dollar P&L.
  static Map<String, dynamic> withDerivedProfitLoss(
      Map<String, dynamic> trade) {
    if (trade['profitLoss'] != null) return trade;
    final entry = trade['entryPrice'];
    final exit = trade['exitPrice'];
    final quantity = trade['quantity'];
    if (entry is! num || exit is! num || quantity is! num) return trade;
    return {...trade, 'profitLoss': ((exit - entry) * quantity).toDouble()};
  }

  /// Resets daily trade counters (called at start of new trading day)
  void _resetDailyCounters() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_dailyTradeCountResetDate == null ||
        _dailyTradeCountResetDate!.isBefore(today)) {
      _dailyTradeCount = 0;
      _dailyTradeCountResetDate = today;
      _log('🔄 Reset daily trade counters for $today');
    }
  }

  /// Checks if auto-trading can proceed based on configured limits
  /// Returns null if allowed, or a reason string if not allowed
  String? _checkAutoTradeConditions() {
    // Reset daily counters if needed
    _resetDailyCounters();

    // Check if auto-trade is enabled
    final autoTradeEnabled = _config.autoTradeEnabled;
    if (!autoTradeEnabled) {
      _log('❌ Auto-trade not enabled in config');
      return 'Auto-trade disabled in settings';
    }

    // Check emergency stop
    if (_emergencyStopActivated) {
      _log('🛑 Emergency stop activated');
      return 'Emergency stop is activated';
    }

    // Check if market is open (including extended hours if enabled)
    final allowPreMarket = _config.allowPreMarketTrading;
    final allowAfterHours = _config.allowAfterHoursTrading;
    final includeExtended = allowPreMarket || allowAfterHours;

    if (!MarketHours.isMarketOpen(includeExtendedHours: includeExtended)) {
      // _log('🏦 Market is closed (Extended hours enabled: $includeExtended)');
      return 'Market is closed';
    }

    // Check daily trade limit
    final dailyLimit = _config.strategyConfig.dailyTradeLimit;
    if (_dailyTradeCount >= dailyLimit) {
      // _log('📊 Daily trade limit reached: $_dailyTradeCount/$dailyLimit');
      return 'Daily trade limit reached ($_dailyTradeCount/$dailyLimit)';
    }

    // Check cooldown period
    if (_lastAutoTradeTime != null) {
      final cooldownMinutes = _config.autoTradeCooldownMinutes;
      final cooldownDuration = Duration(minutes: cooldownMinutes);
      final timeSinceLastTrade = DateTime.now().difference(_lastAutoTradeTime!);

      if (timeSinceLastTrade < cooldownDuration) {
        final remainingMinutes =
            (cooldownDuration - timeSinceLastTrade).inMinutes;
        // _log('⏰ Cooldown active: $remainingMinutes minutes remaining');
        return 'Cooldown active ($remainingMinutes min remaining)';
      }
    }

    return null;
  }

  /// Helper to fetch instrument safely
  Future<dynamic> _getInstrument(
    dynamic brokerageService,
    dynamic brokerageUser,
    dynamic instrumentStore,
    String symbol,
  ) async {
    if (brokerageService == null || brokerageUser == null) return null;
    try {
      return await brokerageService.getInstrumentBySymbol(
        brokerageUser,
        instrumentStore,
        symbol,
      );
    } catch (e) {
      _log('⚠️ Error fetching instrument for $symbol: $e');
      return null;
    }
  }

  /// Widest gap between a stored price and the live quote that still allows an entry.
  static const double maxEntryPriceDeviation = 0.03;

  @visibleForTesting
  static bool isEntryPriceStale(double price, double livePrice) =>
      livePrice > 0 &&
      (price - livePrice).abs() / livePrice > maxEntryPriceDeviation;

  /// Returns the live price to enter at, or null when the entry must be skipped.
  /// Without a quote source the stored [price] is returned unchanged.
  Future<double?> _confirmEntryPrice({
    required dynamic brokerageService,
    required dynamic brokerageUser,
    required dynamic quoteStore,
    required String symbol,
    required double price,
  }) async {
    if (brokerageService == null ||
        brokerageUser == null ||
        quoteStore == null) {
      return price;
    }
    double? live;
    try {
      final quote =
          await brokerageService.getQuote(brokerageUser, quoteStore, symbol);
      live = quote.lastTradePrice ?? quote.lastExtendedHoursTradePrice;
    } catch (e) {
      _log('⏭️ Skipping BUY for $symbol: could not confirm live price ($e)');
      return null;
    }
    if (live == null || live <= 0) {
      _log('⏭️ Skipping BUY for $symbol: no live price available');
      return null;
    }
    if (isEntryPriceStale(price, live)) {
      _log(
          '⏭️ Skipping BUY for $symbol: stored price \$$price is stale vs live \$$live');
      return null;
    }
    return live;
  }

  /// Helper to execute order (handles paper vs real)
  Future<http.Response> _executeOrder({
    required dynamic brokerageService,
    required dynamic brokerageUser,
    required dynamic account,
    required dynamic instrument,
    required String symbol,
    required String action,
    required double price,
    required int quantity,
    required bool isPaperMode,
    PaperTradingStore? paperTradingStore,
  }) async {
    if (isPaperMode) {
      if (paperTradingStore != null && instrument != null) {
        try {
          // Assume stock order for now as agentic trading focuses on stocks
          // Cast instrument to required type if possible, or rely on dynamic dispatch
          await paperTradingStore.executeStockOrder(
            instrument: instrument,
            quantity: quantity.toDouble(),
            price: price,
            side: action.toLowerCase(),
            orderType: 'market',
          );
        } catch (e) {
          _log('❌ Error persisting paper trade: $e');
          // Start simulation anyway so the loop continues, or fail?
          // If persistence fails, maybe we should fail the order.
          return http.Response('Error persisting paper trade: $e', 400);
        }
      }
      return _simulatePaperOrder(action, symbol, quantity, price);
    }
    return await brokerageService.placeInstrumentOrder(
      brokerageUser,
      account,
      instrument,
      symbol,
      action.toLowerCase(),
      price,
      quantity,
    );
  }

  /// Executes automatic trading based on current signals
  ///
  /// This method:
  /// 1. Checks if auto-trading can proceed (limits, cooldowns, etc.)
  /// 2. Fetches current trade signals
  /// 3. Filters for BUY signals that pass all enabled indicators
  /// 4. Initiates trade proposals for qualified signals
  /// 5. Executes approved orders through brokerage service
  /// 6. Tracks executed trades and updates counters
  ///
  /// Returns a map with:
  /// - 'success': bool indicating if any trades were executed
  /// - 'tradesExecuted': number of trades executed
  /// - 'message': status message
  /// - 'trades': list of executed trade details
  Future<Map<String, dynamic>> autoTrade({
    required List<Map<String, dynamic>> tradeSignals,
    required Map<String, dynamic> portfolioState,
    required dynamic brokerageUser,
    required dynamic account,
    required dynamic brokerageService,
    required dynamic instrumentStore,
    required dynamic tradeSignalsProvider,
    DocumentReference? userDocRef,
    PaperTradingStore? paperTradingStore,
    dynamic quoteStore,
  }) async {
    _isAutoTrading = true;
    _showAutoTradingVisual = true;
    _autoTradingVisualTimer?.cancel(); // Cancel any existing timer
    notifyListeners();

    final processedSignals = <Map<String, dynamic>>[];

    try {
      final isPaperMode = _config.paperTradingMode;

      // Validate required parameters
      if ((!isPaperMode &&
              (brokerageUser == null ||
                  account == null ||
                  brokerageService == null)) ||
          instrumentStore == null) {
        _log('❌ Missing required parameters for auto-trade');
        _isAutoTrading = false;
        _scheduleVisualStateReset();
        notifyListeners();
        return {
          'success': false,
          'tradesExecuted': 0,
          'message':
              'Missing required parameters (brokerageUser, account, service, or store)',
          'trades': [],
          'blocked': true,
          'processedSignals': processedSignals,
        };
      }

      // Check if auto-trading can proceed
      final conditionCheck = _checkAutoTradeConditions();
      if (conditionCheck != null) {
        _isAutoTrading = false;
        _scheduleVisualStateReset();
        _log('❌ Conditions not met: $conditionCheck');
        notifyListeners();
        return {
          'success': false,
          'tradesExecuted': 0,
          'message': 'Auto-trade conditions not met: $conditionCheck',
          'trades': [],
          'blocked': true,
          'processedSignals': processedSignals,
        };
      }

      // Pending BUYs queued before a position opened would stack a second entry.
      final staleBuys = _pendingOrders
          .where((o) =>
              (o['action'] as String?)?.toUpperCase() == 'BUY' &&
              ((portfolioState[o['symbol']]?['quantity'] as num?) ?? 0) > 0)
          .toList();
      for (final stale in staleBuys) {
        _log(
            '\u23ed\ufe0f Dropped pending BUY for ${stale['symbol']}: position already held');
        _pendingOrders.remove(stale);
        if (userDocRef != null) {
          unawaited(_removePendingOrderFromFirestore(userDocRef, stale));
        }
      }
      if (staleBuys.isNotEmpty) notifyListeners();

      // Get enabled indicators from config
      final enabledIndicators = _config.strategyConfig.enabledIndicators;
      final activeIndicators = enabledIndicators.entries
          .where((entry) => entry.value == true)
          .map((entry) => entry.key)
          .toList();

      final requireAllIndicatorsGreen =
          _config.strategyConfig.requireAllIndicatorsGreen;
      final minSignalStrength = _config.strategyConfig.minSignalStrength;
      final isReasoningMode = _config.tradingMode == TradingMode.reasoning;

      // _log('📊 Active indicators for auto-trade filtering: $activeIndicators');
      // _log(
      //     '📊 Strategy: ${requireAllIndicatorsGreen ? "All Indicators Green" : "Min Signal Strength ($minSignalStrength)"}');

      // Get current signals - filter for BUY signals that pass enabled indicators
      // processedSignals is defined at the top of the method

      final buySignals = <Map<String, dynamic>>[];

      for (final signal in tradeSignals) {
        String? rejectionReason;
        bool isAccepted = false;

        // In Reasoning mode, we bypass systematic filtering and let the AI decide,
        // as long as the signal has basic technical merit (already filtered by fetchSignals)
        if (isReasoningMode) {
          isAccepted = true;
        } else if (signal['signal']?.toString().toUpperCase() == 'SELL') {
          // HOLD is allowed: stored signals are scored with default indicators, not the user's.
          rejectionReason = 'Signal is SELL, not BUY';
        } else {
          // Check if all enabled indicators agree with BUY signal
          final multiIndicatorResult =
              signal['multiIndicatorResult'] as Map<String, dynamic>?;

          if (multiIndicatorResult == null) {
            rejectionReason = 'Missing multi-indicator result';
          } else {
            final indicators =
                multiIndicatorResult['indicators'] as Map<String, dynamic>?;
            final indicatorResults = indicators ?? const <String, dynamic>{};
            final customIndicatorsResult =
                multiIndicatorResult['customIndicators']
                    as Map<String, dynamic>?;

            if (activeIndicators.isNotEmpty &&
                (indicators == null || indicators.isEmpty)) {
              rejectionReason = 'No indicators data';
            } else if (indicatorResults.isEmpty &&
                (customIndicatorsResult == null ||
                    customIndicatorsResult.isEmpty)) {
              rejectionReason = 'No indicators data';
            } else if (activeIndicators.isEmpty &&
                (customIndicatorsResult == null ||
                    customIndicatorsResult.isEmpty)) {
              rejectionReason = 'No active indicators configured';
            } else {
              if (requireAllIndicatorsGreen) {
                // Verify that all enabled indicators have BUY signals
                for (final indicator in activeIndicators) {
                  final indicatorData =
                      indicatorResults[indicator] as Map<String, dynamic>?;
                  if (indicatorData == null) {
                    rejectionReason = 'Indicator $indicator missing';
                    break;
                  }
                  final indicatorSignal = indicatorData['signal'] as String?;
                  if (indicatorSignal != 'BUY') {
                    rejectionReason =
                        '$indicator is ${indicatorSignal ?? "Neutral"}';
                    break;
                  }
                }
                if (rejectionReason == null && customIndicatorsResult != null) {
                  for (final entry in customIndicatorsResult.entries) {
                    final indicatorData = entry.value as Map<String, dynamic>?;
                    if (indicatorData == null) {
                      rejectionReason = 'Custom indicator ${entry.key} missing';
                      break;
                    }
                    final indicatorSignal = indicatorData['signal'] as String?;
                    if (indicatorSignal != 'BUY') {
                      rejectionReason =
                          'Custom indicator ${entry.key} is ${indicatorSignal ?? "Neutral"}';
                      break;
                    }
                  }
                }
                if (rejectionReason == null) {
                  isAccepted = true;
                }
              } else {
                // Calculate signal strength based on enabled indicators
                int buyCount = 0;
                int sellCount = 0;
                int totalEnabled = 0;

                // Standard indicators
                for (final indicator in activeIndicators) {
                  final indicatorData =
                      indicatorResults[indicator] as Map<String, dynamic>?;
                  if (indicatorData != null) {
                    totalEnabled++;
                    final signal = indicatorData['signal'] as String?;
                    if (signal == 'BUY') {
                      buyCount++;
                    } else if (signal == 'SELL') {
                      sellCount++;
                    }
                  }
                }

                // Custom indicators
                if (customIndicatorsResult != null) {
                  for (final key in customIndicatorsResult.keys) {
                    final indicatorData =
                        customIndicatorsResult[key] as Map<String, dynamic>?;
                    if (indicatorData != null) {
                      totalEnabled++;
                      final signal = indicatorData['signal'] as String?;
                      if (signal == 'BUY') {
                        buyCount++;
                      } else if (signal == 'SELL') {
                        sellCount++;
                      }
                    }
                  }
                }

                if (totalEnabled == 0) {
                  rejectionReason = 'No enabled indicators found in signal';
                } else {
                  final calculatedStrength =
                      ((buyCount - sellCount + totalEnabled) /
                              (2 * totalEnabled)) *
                          100;

                  if (calculatedStrength < minSignalStrength) {
                    rejectionReason =
                        'Strength ${calculatedStrength.toStringAsFixed(1)}% < $minSignalStrength%';
                  } else {
                    isAccepted = true;
                  }
                }
              }
            }
          }
        }

        // Create a copy of the signal with processing info
        final processedSignal = Map<String, dynamic>.from(signal);
        processedSignal['processedStatus'] =
            isAccepted ? 'Accepted' : 'Rejected';
        if (rejectionReason != null) {
          processedSignal['rejectionReason'] = rejectionReason;
        }
        processedSignals.add(processedSignal);

        if (isAccepted) {
          buySignals.add(signal);
        }
      }

      // Update history (keep last 50)
      _signalProcessingHistory.insertAll(0, processedSignals);
      if (_signalProcessingHistory.length > 50) {
        _signalProcessingHistory = _signalProcessingHistory.sublist(0, 50);
      }

      if (buySignals.isEmpty) {
        // _log('📭 No BUY signals available matching enabled indicators');
        _log('📭 No BUY signals matching criteria');
        final reasonCounts = <String, int>{};
        for (final s in processedSignals) {
          final reason = (s['rejectionReason'] as String?)
              ?.replaceAll(RegExp(r'\d+(\.\d+)?'), '#');
          if (reason != null) {
            reasonCounts[reason] = (reasonCounts[reason] ?? 0) + 1;
          }
        }
        final topReasons = reasonCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        if (topReasons.isNotEmpty) {
          _log(
              '🔍 Rejected: ${topReasons.take(3).map((e) => '${e.value}× ${e.key}').join('; ')}');
        }
        _isAutoTrading = false;
        _scheduleVisualStateReset();
        notifyListeners();
        return {
          'success': false,
          'tradesExecuted': 0,
          'message': 'No BUY signals matching enabled indicators',
          'trades': [],
          'processedSignals': processedSignals,
        };
      }

      // Cap the number of signals to process in Reasoning Mode to avoid
      // excessive Cloud Function calls and costs.
      if (isReasoningMode && buySignals.length > 15) {
        _log(
            '🤖 Capping analysis to top 15 highest-strength signals (out of ${buySignals.length})');
        buySignals.removeRange(15, buySignals.length);
      }

      // _log(
      //     '🎯 Found ${buySignals.length} BUY signals matching enabled indicators for auto-trade');
      _log('🎯 Found ${buySignals.length} qualified BUY signals');

      final executedTrades = <Map<String, dynamic>>[];
      final dailyLimit = _config.strategyConfig.dailyTradeLimit;

      // Process each signal (respecting daily limit)
      // Parallelize proposal generation to speed up the cycle
      if (buySignals.isNotEmpty) {
        _log(
            '🤖 Initiating ${buySignals.length} trade proposals in parallel...');
      }

      final proposalFutures = buySignals.map((signal) async {
        final symbol = signal['symbol'] as String?;
        if (symbol == null || symbol.isEmpty) return null;

        final currentPrice =
            (signal['currentPrice'] as num?)?.toDouble() ?? 0.0;
        if (currentPrice <= 0) return null;

        try {
          final result = await tradeSignalsProvider.initiateTradeProposal(
            symbol: symbol,
            currentPrice: currentPrice,
            portfolioState: portfolioState,
            config: _config,
            interval: signal['interval'] as String?,
            skipSignalUpdate: true,
          );
          return {
            'signal': signal,
            'result': result,
            'symbol': symbol,
            'currentPrice': currentPrice
          };
        } catch (e) {
          _log('❌ Error initiating proposal for $symbol: $e');
          return null;
        }
      });

      final proposalResults = await Future.wait(proposalFutures);
      final validProposals = proposalResults.where((r) => r != null).toList();

      // Track available funds locally to handle parallel approvals
      double estimatedBuyingPower =
          (portfolioState['buyingPower'] as num?)?.toDouble() ?? 0.0;

      // One entry per symbol: signals exist per interval and may repeat a symbol.
      final buySymbolsThisCycle = <String>{};

      for (final item in validProposals) {
        if (item == null) continue;

        // Check if we've hit the limit
        if (_dailyTradeCount >= dailyLimit) {
          _log(
              '⚠️ Reached daily trade limit during execution ($_dailyTradeCount/$dailyLimit)');
          break;
        }

        final signal = item['signal'] as Map<String, dynamic>;
        final symbol = item['symbol'] as String;
        var currentPrice = item['currentPrice'] as double;
        final proposalResult = item['result'] as Map<String, dynamic>;

        try {
          _log('🤖 Processing proposal for $symbol at \$$currentPrice');

          // Configured result available from parallel fetch
          // final proposalResult = ... (already fetched)

          final proposalStatus = proposalResult['status'] as String?;
          final proposal = proposalResult['proposal'] != null
              ? Map<String, dynamic>.from(proposalResult['proposal'] as Map)
              : null;
          final assessment = proposalResult['assessment'] != null
              ? Map<String, dynamic>.from(proposalResult['assessment'] as Map)
              : null;

          // If proposal was approved, execute the order
          if (proposal != null && proposalStatus == 'approved') {
            final action = proposal['action'] as String?;
            final quantity = proposal['quantity'] as int?;

            if (action == null || quantity == null || quantity <= 0) {
              _log(
                  '⚠️ Invalid proposal for $symbol: Action=$action, Quantity=$quantity');
              continue;
            }

            // RiskGuard treats a SELL as a short, so only sell what is actually held.
            if (action.toUpperCase() == 'SELL') {
              final heldQuantity =
                  (portfolioState[symbol]?['quantity'] as num?) ?? 0;
              if (heldQuantity <= 0) {
                _log('⏭️ Skipping SELL for $symbol: no position held');
                continue;
              }
            }

            // Never stack a new entry on top of an open position.
            if (action.toUpperCase() == 'BUY') {
              final heldQuantity =
                  (portfolioState[symbol]?['quantity'] as num?) ?? 0;
              if (heldQuantity > 0) {
                _log('⏭️ Skipping BUY for $symbol: position already held');
                continue;
              }
              if (!buySymbolsThisCycle.add(symbol.toUpperCase())) {
                _log(
                    '⏭️ Skipping BUY for $symbol: already proposed this cycle');
                continue;
              }

              final confirmedPrice = await _confirmEntryPrice(
                brokerageService: brokerageService,
                brokerageUser: brokerageUser,
                quoteStore: quoteStore,
                symbol: symbol,
                price: currentPrice,
              );
              if (confirmedPrice == null) continue;
              currentPrice = confirmedPrice;
            }

            // Check buying power for parallel execution safety
            if (action.toUpperCase() == 'BUY' && !isPaperMode) {
              final cost = quantity * currentPrice;
              if (cost > estimatedBuyingPower) {
                _log(
                    '⚠️ Insufficient buying power for $symbol (Cost: \$${cost.toStringAsFixed(2)}, Avail: \$${estimatedBuyingPower.toStringAsFixed(2)})');
                continue;
              }
              estimatedBuyingPower -= cost;
            }

            // Get instrument from store
            dynamic instrument = await _getInstrument(
                brokerageService, brokerageUser, instrumentStore, symbol);

            if (instrument == null) {
              if (!isPaperMode) {
                _log(
                    '⚠️ Could not find instrument for $symbol (or service missing), skipping real trade');
                continue;
              }
              // In paper mode, we can proceed without instrument object if needed,
              // but usually it's better to have it. The original code allowed proceeding.
            }

            // Execute the order through brokerage service
            try {
              // Validate action is BUY or SELL
              final normalizedAction = action.toUpperCase();
              if (normalizedAction != 'BUY' && normalizedAction != 'SELL') {
                _log('⚠️ Invalid action "$action" for $symbol, skipping');
                continue;
              }

              final side = normalizedAction == 'BUY' ? 'buy' : 'sell';

              final isPaperMode = _config.paperTradingMode;
              final requireApproval = _config.requireApproval;

              if (requireApproval) {
                final strength = signal['signalStrength'];
                final interval = signal['interval'];
                var reason = 'Auto-trade signal';

                // Use the reasoning from the agent if available
                final agentReason = proposal['reason'];
                final agentConfidence = proposalResult['analysis'] != null
                    ? proposalResult['analysis']['score']
                    : null;

                if (agentReason != null && agentReason.toString().isNotEmpty) {
                  reason = agentReason.toString();
                } else {
                  if (strength != null) {
                    reason += ' (${strength.toString()}%)';
                  }
                  if (interval != null) {
                    reason += ' • $interval';
                  }
                }

                // Check for existing pending approval for the same recommendation
                final existingIndex = _pendingOrders.indexWhere((o) =>
                    (o['symbol'] as String?)?.toUpperCase() ==
                        symbol.toUpperCase() &&
                    (o['action'] as String?)?.toUpperCase() ==
                        normalizedAction);

                if (existingIndex != -1) {
                  final existingOrder = _pendingOrders[existingIndex];
                  final existingPrice =
                      (existingOrder['price'] as num?)?.toDouble();
                  final existingQuantity = existingOrder['quantity'];
                  final existingReason = existingOrder['reason'];
                  final existingConfidence = existingOrder['confidence'];

                  final bool needsUpdate = existingPrice != currentPrice ||
                      existingQuantity != quantity ||
                      existingReason != reason ||
                      existingConfidence != agentConfidence;

                  if (needsUpdate) {
                    existingOrder['price'] = currentPrice;
                    existingOrder['quantity'] = quantity;
                    existingOrder['reason'] = reason;
                    existingOrder['confidence'] = agentConfidence;
                    existingOrder['signal'] = signal;
                    existingOrder['proposal'] = proposal;
                    existingOrder['assessment'] = assessment;
                    existingOrder['timestamp'] =
                        DateTime.now().toIso8601String();
                    if (instrument != null) {
                      existingOrder['instrument'] = instrument;
                    }

                    if (userDocRef != null) {
                      await _updatePendingOrderInFirestore(
                          userDocRef, existingOrder);
                    }
                    notifyListeners();
                    _log(
                        '📝 Updated pending approval: $symbol ($normalizedAction $quantity @ \$$currentPrice)');
                  } else {
                    _log(
                        'ℹ️ Pending approval for $symbol is up to date, skipping duplicate');
                  }
                  continue;
                }

                final pendingOrder = {
                  'id': DateTime.now().millisecondsSinceEpoch.toString(),
                  'timestamp': DateTime.now().toIso8601String(),
                  'symbol': symbol,
                  'action': normalizedAction,
                  'quantity': quantity,
                  'price': currentPrice,
                  'instrument': instrument,
                  'status': 'pending',
                  'reason': reason,
                  'confidence': agentConfidence,
                  'signal': signal,
                  'proposal': proposal,
                  'assessment': assessment,
                };
                _pendingOrders.add(pendingOrder);
                if (userDocRef != null) {
                  await _addPendingOrderToFirestore(userDocRef, pendingOrder);
                }
                notifyListeners();
                _log('📝 Order added to pending approval: $symbol');
                continue;
              }

              _log(
                  '${isPaperMode ? '📝 PAPER' : '📤'} Placing order: $action $quantity shares of $symbol at \$$currentPrice');

              final orderResponse = await _executeOrder(
                brokerageService: brokerageService,
                brokerageUser: brokerageUser,
                account: account,
                instrument: instrument,
                symbol: symbol,
                action: side,
                price: currentPrice,
                quantity: quantity,
                isPaperMode: isPaperMode,
                paperTradingStore: paperTradingStore,
              );

              // Check if order was successful (HTTP 200 OK or 201 Created)
              const httpOk = 200;
              const httpCreated = 201;
              if (orderResponse.statusCode == httpOk ||
                  orderResponse.statusCode == httpCreated) {
                final tradeRecord = {
                  'timestamp': DateTime.now().toIso8601String(),
                  'symbol': symbol,
                  'action': action,
                  'quantity': quantity,
                  'price': currentPrice,
                  'paperMode': isPaperMode,
                  'proposal': Map<String, dynamic>.from(proposal),
                  'assessment': assessment != null
                      ? Map<String, dynamic>.from(assessment)
                      : null,
                  'orderResponse': orderResponse.body,
                };

                executedTrades.add(tradeRecord);
                _autoTradeHistory.insert(0, tradeRecord);
                _addTradeToHistoryFirestore(tradeRecord, userDocRef);

                // Keep only last 100 trades in history
                if (_autoTradeHistory.length > 100) {
                  _autoTradeHistory.removeRange(100, _autoTradeHistory.length);
                }

                _dailyTradeCount++;
                _executedOrderCount++;
                _lastAutoTradeTime = DateTime.now();

                // Track this trade for TP/SL monitoring (only if it's a BUY)
                if (normalizedAction == 'BUY') {
                  _automatedBuyTrades.add({
                    'symbol': symbol,
                    'quantity': quantity,
                    'initialQuantity': quantity,
                    'executedStages': <int>[],
                    'entryPrice': currentPrice,
                    'highestPrice': currentPrice,
                    'paperMode': isPaperMode,
                    'timestamp': DateTime.now().toIso8601String(),
                    'enabledIndicators': List<String>.from(
                      _config.strategyConfig.enabledIndicators.entries
                          .where((e) => e.value == true)
                          .map((e) => e.key),
                    ),
                  });
                  _log(
                      '📝 Added automated BUY trade: $symbol x$quantity @ \$$currentPrice for TP/SL tracking');

                  // Save to Firestore
                  await _saveAutomatedBuyTradesToFirestore(userDocRef);

                  // Send notification if enabled
                  if (_config.notifyOnBuy) {
                    _sendTradeNotification(
                      userDocRef,
                      'buy',
                      symbol: symbol,
                      quantity: quantity,
                      price: currentPrice,
                    );
                  }
                }

                _analytics.logEvent(
                  name: 'agentic_trading_auto_executed',
                  parameters: {
                    'symbol': symbol,
                    'daily_count': _dailyTradeCount,
                    'action': action,
                    'quantity': quantity,
                  },
                );

                _log(
                    '✅ Order executed for $symbol: $action $quantity shares at \$$currentPrice ($_dailyTradeCount/$dailyLimit today)');
              } else {
                _log(
                    '❌ Order failed for $symbol: ${orderResponse.statusCode} - ${orderResponse.body}');
                _analytics.logEvent(
                  name: 'agentic_trading_order_failed',
                  parameters: {
                    'symbol': symbol,
                    'status_code': orderResponse.statusCode,
                    'error': orderResponse.body,
                  },
                );
              }
            } catch (e) {
              _log('❌ Error placing order for $symbol: $e');
              _analytics.logEvent(
                name: 'agentic_trading_order_error',
                parameters: {
                  'symbol': symbol,
                  'error': e.toString(),
                },
              );
            }
          } else {
            String? assessmentReason;
            // Update processedSignals with the rejection reason from assessment
            if (assessment != null && assessment['approved'] == false) {
              assessmentReason = assessment['reason'] as String?;
              if (assessmentReason != null) {
                final processedSignalIndex =
                    processedSignals.indexWhere((s) => s['symbol'] == symbol);
                if (processedSignalIndex != -1) {
                  processedSignals[processedSignalIndex]['processedStatus'] =
                      'Rejected';
                  processedSignals[processedSignalIndex]['rejectionReason'] =
                      assessmentReason;
                }
              }
            }
            final reasonToLog = assessmentReason ??
                (proposalResult['message'] as String?) ??
                'Rejected by agent';
            _log('❌ Trade proposal rejected for $symbol: $reasonToLog');
          }

          // Delay between trades to avoid rate limiting
          await Future.delayed(const Duration(seconds: _tradeDelaySeconds));
        } catch (e) {
          _log('❌ Error auto-trading $symbol: $e');
          _analytics.logEvent(
            name: 'agentic_trading_auto_error',
            parameters: {
              'symbol': symbol,
              'error': e.toString(),
            },
          );
        }
      }

      _isAutoTrading = false;
      _scheduleVisualStateReset();
      notifyListeners();

      final message = executedTrades.isEmpty
          ? 'No trades executed'
          : 'Executed ${executedTrades.length} trade(s)';

      _log(
          '📊 Auto-trade summary: ${executedTrades.length} executed, ${processedSignals.length} processed');

      return {
        'success': executedTrades.isNotEmpty,
        'tradesExecuted': executedTrades.length,
        'message': message,
        'trades': executedTrades,
        'processedSignals': processedSignals,
      };
    } catch (e) {
      _isAutoTrading = false;
      _scheduleVisualStateReset();
      notifyListeners();
      _log('❌ Error in auto-trade execution: $e');
      return {
        'success': false,
        'tradesExecuted': 0,
        'message': 'Error: $e',
        'trades': [],
        'processedSignals': processedSignals,
      };
    }
  }

  /// Pending orders are rebuilt from Firestore on reload, so a UI-held map can be stale.
  Map<String, dynamic>? _findPendingOrder(Map<String, dynamic> order) {
    if (_pendingOrders.contains(order)) return order;
    final firestoreId = order['firestoreId'];
    final symbol = (order['symbol'] as String?)?.toUpperCase();
    final action = (order['action'] as String?)?.toUpperCase();
    if (firestoreId != null) {
      for (final o in _pendingOrders) {
        if (o['firestoreId'] == firestoreId) return o;
      }
    }
    for (final o in _pendingOrders) {
      if ((o['symbol'] as String?)?.toUpperCase() == symbol &&
          (o['action'] as String?)?.toUpperCase() == action) {
        return o;
      }
    }
    return null;
  }

  /// Approves a pending order and executes it. Returns true if it was executed.
  /// [heldQuantity] is the caller's current holding of the order's symbol; a BUY
  /// for a symbol already held is dropped instead of stacking a second entry.
  Future<bool> approveOrder(
    Map<String, dynamic> staleOrder, {
    required dynamic brokerageUser,
    required dynamic account,
    required dynamic brokerageService,
    DocumentReference? userDocRef,
    PaperTradingStore? paperTradingStore,
    double? heldQuantity,
    dynamic quoteStore,
  }) async {
    final order = _findPendingOrder(staleOrder);
    if (order == null) {
      _log('❌ Order not found in pending list');
      return false;
    }

    if ((order['action'] as String?)?.toUpperCase() == 'BUY' &&
        (heldQuantity ?? 0) > 0) {
      _log(
          '⏭️ Dropped pending BUY for ${order['symbol']}: position already held');
      _pendingOrders.remove(order);
      if (userDocRef != null) {
        unawaited(_removePendingOrderFromFirestore(userDocRef, order));
      }
      notifyListeners();
      return false;
    }

    final symbol = order['symbol'] as String;
    final action = order['action'] as String;
    final quantity = order['quantity'] as int;
    var price = (order['price'] as num).toDouble();
    final instrument = order['instrument'];

    // A queued price can be hours old; never fill an entry far from the market.
    if (action.toUpperCase() == 'BUY') {
      final confirmedPrice = await _confirmEntryPrice(
        brokerageService: brokerageService,
        brokerageUser: brokerageUser,
        quoteStore: quoteStore,
        symbol: symbol,
        price: price,
      );
      if (confirmedPrice == null) {
        _pendingOrders.remove(order);
        if (userDocRef != null) {
          unawaited(_removePendingOrderFromFirestore(userDocRef, order));
        }
        notifyListeners();
        return false;
      }
      price = confirmedPrice;
    }

    try {
      final side = action.toLowerCase() == 'buy' ? 'buy' : 'sell';
      final isPaperMode = _config.paperTradingMode;

      if (!isPaperMode && brokerageService == null) {
        _log('❌ Cannot approve real order without brokerage service');
        return false;
      }

      _log(
          '${isPaperMode ? '📝 PAPER' : '📤'} Approving order: $action $quantity shares of $symbol at \$$price');

      // Execute order
      final orderResponse = await _executeOrder(
        brokerageService: brokerageService,
        brokerageUser: brokerageUser,
        account: account,
        instrument: instrument,
        symbol: symbol,
        action: side,
        price: price,
        quantity: quantity,
        isPaperMode: isPaperMode,
        paperTradingStore: paperTradingStore,
      );

      const httpOk = 200;
      const httpCreated = 201;
      if (orderResponse.statusCode == httpOk ||
          orderResponse.statusCode == httpCreated) {
        // Add to history
        final tradeRecord = {
          'timestamp': DateTime.now().toIso8601String(),
          'symbol': symbol,
          'action': action,
          'quantity': quantity,
          'price': price,
          'paperMode': isPaperMode,
          'orderResponse': orderResponse.body,
          'approved': true,
        };

        _autoTradeHistory.insert(0, tradeRecord);
        _addTradeToHistoryFirestore(tradeRecord, userDocRef);
        if (_autoTradeHistory.length > 100) {
          _autoTradeHistory.removeRange(100, _autoTradeHistory.length);
        }

        _dailyTradeCount++;
        _executedOrderCount++;
        _lastAutoTradeTime = DateTime.now();

        // Track BUY trades
        if (action.toUpperCase() == 'BUY') {
          _automatedBuyTrades.add({
            'symbol': symbol,
            'quantity': quantity,
            'initialQuantity': quantity,
            'executedStages': <int>[],
            'entryPrice': price,
            'highestPrice': price,
            'paperMode': isPaperMode,
            'timestamp': DateTime.now().toIso8601String(),
            'enabledIndicators': List<String>.from(
              _config.strategyConfig.enabledIndicators.entries
                  .where((e) => e.value == true)
                  .map((e) => e.key),
            ),
          });
          if (userDocRef != null) {
            // Firestore queues the write locally; waiting for the server ack stalls the UI.
            unawaited(_saveAutomatedBuyTradesToFirestore(userDocRef));
          }
        }

        // Remove from pending
        _pendingOrders.remove(order);
        if (userDocRef != null) {
          unawaited(_removePendingOrderFromFirestore(userDocRef, order));
        }
        notifyListeners();

        _log('✅ Approved order executed for $symbol');
        return true;
      } else {
        _log(
            '❌ Approved order failed for $symbol: ${orderResponse.statusCode}');
      }
    } catch (e) {
      _log('❌ Error executing approved order for $symbol: $e');
    }
    return false;
  }

  /// Rejects a pending order
  Future<void> rejectOrder(Map<String, dynamic> staleOrder,
      {DocumentReference? userDocRef}) async {
    final order = _findPendingOrder(staleOrder);
    if (order != null) {
      _pendingOrders.remove(order);
      if (userDocRef != null) {
        await _removePendingOrderFromFirestore(userDocRef, order);
      }
      notifyListeners();
      _log('🚫 Order manually rejected for ${order['symbol']}');
    }
  }

  /// Monitors positions and executes take profit or stop loss orders
  ///
  /// This method:
  /// 1. Checks current positions against entry prices
  /// 2. Calculates profit/loss percentage for each position
  /// 3. Executes sell orders for positions that hit take profit or stop loss thresholds
  /// 4. Tracks executed exit orders
  ///
  /// Returns a map with:
  /// - 'success': bool indicating if any exits were executed
  /// - 'exitsExecuted': number of exit orders placed
  /// - 'message': status message
  /// - 'exits': list of executed exit details
  Future<Map<String, dynamic>> monitorTakeProfitStopLoss({
    required List<InstrumentPosition> positions,
    required dynamic brokerageUser,
    required dynamic account,
    required dynamic brokerageService,
    required dynamic instrumentStore,
    DocumentReference? userDocRef,
    PaperTradingStore? paperTradingStore,
  }) async {
    // Overlapping runs would both see the same tracked trade and exit it twice.
    if (_isMonitoringExits) {
      _log('⏭️ Exit monitor already running, skipping');
      return {
        'success': false,
        'exitsExecuted': 0,
        'message': 'Exit monitor already running',
        'exits': [],
      };
    }
    _isMonitoringExits = true;
    try {
      // Validate required parameters
      if (brokerageUser == null ||
          account == null ||
          brokerageService == null ||
          instrumentStore == null) {
        _log(
            '❌ Missing required parameters for take profit/stop loss monitoring');
        return {
          'success': false,
          'exitsExecuted': 0,
          'message': 'Missing required parameters',
          'exits': [],
        };
      }

      // Get take profit and stop loss percentages from config
      final takeProfitPercent = _config.strategyConfig.takeProfitPercent;
      final stopLossPercent = _config.strategyConfig.stopLossPercent;

      // Get partial exit config
      final enablePartialExits = _config.strategyConfig.enablePartialExits;
      final exitStages = _config.strategyConfig.exitStages;

      // _log(
      //     '📊 Monitoring ${positions.length} total positions, ${_automatedBuyTrades.length} automated buy trades for TP: $takeProfitPercent%, SL: $stopLossPercent%');
      /*
      if (_automatedBuyTrades.isNotEmpty) {
        final symbols = _automatedBuyTrades
            .map((t) => '${t['symbol']} x${t['quantity']}')
            .join(', ');
        _log('📝 Automated buy trades: $symbols');
      }
      */

      final executedExits = <Map<String, dynamic>>[];
      final tradesToRemove = <Map<String, dynamic>>[];
      // Shares still held per symbol, shared by every tracked lot of that symbol.
      final remainingBySymbol = <String, int>{};
      final exitSummaries = <String, Map<String, dynamic>>{};

      // Create a map for faster position lookup
      final positionMap = {for (var p in positions) p.instrumentObj?.symbol: p};

      // Pre-fetch signals for all relevant symbols in parallel to avoid sequential waits
      final technicalExitEnabled = _config.strategyConfig.rsiExitEnabled ||
          _config.strategyConfig.signalStrengthExitEnabled ||
          _config.strategyConfig.gexExitEnabled ||
          _config.strategyConfig.enableGexStructuralStops ||
          _config.strategyConfig.enableMacroRegimeStop;
      final Map<String, Map<String, dynamic>> fetchedSignals = {};

      if (technicalExitEnabled && _automatedBuyTrades.isNotEmpty) {
        final symbolsToFetch = _automatedBuyTrades
            .map((t) => t['symbol'] as String?)
            .where((s) => s != null && s.isNotEmpty)
            .where((s) =>
                positionMap.containsKey(s)) // Only fetch if position exists
            .toSet()
            .toList();

        if (symbolsToFetch.isNotEmpty) {
          // _log('📡 Pre-fetching signals for ${symbolsToFetch.length} positions');
          final interval = _config.strategyConfig.interval;
          // Use Future.wait to fetch all signals in parallel
          await Future.wait(symbolsToFetch.map((symbol) async {
            try {
              final docId = interval == '1d' ? symbol : '${symbol}_$interval';

              final doc = await FirebaseFirestore.instance
                  .collection('signals')
                  .doc(docId!)
                  .get();
              if (doc.exists && doc.data() != null) {
                fetchedSignals[symbol!] = doc.data()!;
              }
            } catch (e) {
              // Ignore individual fetch errors
            }
          }));
        }
      }

      // Check each automated buy trade (copy: other cycles add trades while this awaits)
      for (final buyTrade in List.of(_automatedBuyTrades)) {
        try {
          final symbol = buyTrade['symbol'] as String?;
          final buyQuantity = buyTrade['quantity'] as int?;
          final entryPrice = (buyTrade['entryPrice'] as num?)?.toDouble();
          final initialQuantity =
              buyTrade['initialQuantity'] as int? ?? buyQuantity;
          final executedStages =
              (buyTrade['executedStages'] as List<dynamic>?)?.cast<int>() ??
                  <int>[];

          if (symbol == null ||
              buyQuantity == null ||
              entryPrice == null ||
              entryPrice <= 0) {
            continue;
          }

          // Strict mode check: prevent processing or removing trades from wrong mode
          final tradePaperMode = buyTrade['paperMode'] as bool?;
          final currentMode = _config.paperTradingMode;
          if (tradePaperMode != null && tradePaperMode != currentMode) {
            continue;
          }

          // Find the corresponding position in the portfolio
          final position = positionMap[symbol];

          if (position == null) {
            // Position no longer exists (might have been manually closed)
            _log(
                '⚠️ Automated buy trade for $symbol not found in positions, removing from tracking');
            tradesToRemove.add(buyTrade);
            continue;
          }

          final currentPrice =
              position.instrumentObj?.quoteObj?.lastTradePrice ??
                  position.instrumentObj?.quoteObj?.lastExtendedHoursTradePrice;

          if (currentPrice == null) {
            _log(
                '⚠️ No current price available for $symbol, skipping TP/SL check');
            continue;
          }

          // Calculate profit/loss percentage based on automated trade entry price
          final profitLossPercent =
              ((currentPrice - entryPrice) / entryPrice) * 100;

          _log(
              '📈 $symbol (automated): Entry=\$$entryPrice, Current=\$$currentPrice, P/L=${profitLossPercent.toStringAsFixed(2)}%');

          bool shouldExit = false;
          String exitReason = '';
          int quantityToSell = buyQuantity;
          int? stageIndexToMark;

          final signalData = fetchedSignals[symbol];
          final gexData =
              signalData?['gammaExposureResult'] as Map<String, dynamic>? ??
                  signalData?['gexData'] as Map<String, dynamic>?;
          final nTrans = (gexData?['nTrans'] as num?)?.toDouble();
          final plusGex = (gexData?['plusGex'] as num?)?.toDouble();
          final macroData =
              signalData?['macroAssessment'] as Map<String, dynamic>?;
          final macroStatus = macroData?['status'] as String?;

          // Track highest price and profit percentage for trailing stops
          final prevHighestPrice =
              (buyTrade['highestPrice'] as num?)?.toDouble() ?? entryPrice;
          final newHighestPrice =
              currentPrice > prevHighestPrice ? currentPrice : prevHighestPrice;
          if (newHighestPrice != prevHighestPrice) {
            buyTrade['highestPrice'] = newHighestPrice;
            _log('🔼 $symbol new highest price since entry: $newHighestPrice');
          }

          final prevHighestProfit =
              (buyTrade['highestProfitPercent'] as num?)?.toDouble() ??
                  profitLossPercent;
          final newHighestProfit = profitLossPercent > prevHighestProfit
              ? profitLossPercent
              : prevHighestProfit;
          if (newHighestProfit != prevHighestProfit) {
            buyTrade['highestProfitPercent'] = newHighestProfit;
          }

          // =========================================================================
          // 🛡️ 5-TIER SEQUENTIAL EXIT STOP PRIORITY QUEUE (GEX Orchestrator Parity)
          // Defensive and protective halts take absolute precedence over profit targets
          // =========================================================================

          // --- STOP 1: Structural Stop (Close below nTrans / Secondary Support) ---
          if (!shouldExit &&
              _config.strategyConfig.enableGexStructuralStops &&
              nTrans != null &&
              currentPrice < nTrans) {
            shouldExit = true;
            exitReason =
                'Stop 1: Structural Stop (Spot \$$currentPrice < nTrans \$$nTrans)';
            quantityToSell = buyQuantity;
            _log('🚨 $symbol triggered Stop 1 Structural Stop: $exitReason');
          }

          // --- STOP 2: Trailing Volatility / Peak Profit Drawdown Stop ---
          if (!shouldExit && _config.strategyConfig.enableTrailingPeakStop) {
            final trailPeakPercent =
                _config.strategyConfig.trailingPeakStopPercent;
            if (newHighestProfit >= 5.0) {
              final giveback = newHighestProfit - profitLossPercent;
              if (giveback >= trailPeakPercent) {
                shouldExit = true;
                exitReason =
                    'Stop 2: Trailing Peak Drawdown ($trailPeakPercent% giveback from peak +${newHighestProfit.toStringAsFixed(1)}%)';
                quantityToSell = buyQuantity;
                _log(
                    '📉 $symbol triggered Stop 2 Trailing Peak Stop: $exitReason');
              }
            }
          }

          // Also check standard trailing stop price if configured
          if (!shouldExit && _config.strategyConfig.trailingStopEnabled) {
            final trailPercent = _config.strategyConfig.trailingStopPercent;
            final trailStopPrice = newHighestPrice * (1 - trailPercent / 100.0);
            if (currentPrice <= trailStopPrice && currentPrice > entryPrice) {
              shouldExit = true;
              exitReason = 'Trailing Stop ($trailPercent%)';
              quantityToSell = buyQuantity;
              _log(
                  '🟡 $symbol trailing stop triggered: current $currentPrice <= trail $trailStopPrice (highest $newHighestPrice)');
            }
          }

          // --- STOP 3: Time Stop / Theta Gate ---
          if (!shouldExit && _config.strategyConfig.enableTimeThetaStop) {
            final tradeTimestamp = buyTrade['timestamp'] as String?;
            if (tradeTimestamp != null) {
              final tradeTime = DateTime.tryParse(tradeTimestamp);
              if (tradeTime != null) {
                final daysOpen = DateTime.now().difference(tradeTime).inDays;
                if (daysOpen >=
                        _config.strategyConfig.stalledSessionsStopLimit &&
                    profitLossPercent.abs() < 2.0) {
                  shouldExit = true;
                  exitReason =
                      'Stop 3: Momentum Stalled Stop ($daysOpen sessions with stalled progress)';
                  quantityToSell = buyQuantity;
                  _log('⏱️ $symbol triggered Stop 3 Stalled Stop: $exitReason');
                }
              }
            }

            // Check DTE expiration cutoff if position has an expiration date
            if (!shouldExit) {
              final expirationStr = buyTrade['expirationDate'] as String?;
              if (expirationStr != null) {
                final expDate = DateTime.tryParse(expirationStr);
                if (expDate != null) {
                  final dte = expDate.difference(DateTime.now()).inDays;
                  if (dte <= _config.strategyConfig.minDteStopDays) {
                    shouldExit = true;
                    exitReason =
                        'Stop 3: Theta Expiry Stop (DTE $dte <= ${_config.strategyConfig.minDteStopDays} days)';
                    quantityToSell = buyQuantity;
                    _log('⏱️ $symbol triggered Stop 3 DTE Stop: $exitReason');
                  }
                }
              }
            }
          }

          // --- STOP 4: Macro / Regime Stop (Bearish / Defensive Shift) ---
          if (!shouldExit &&
              _config.strategyConfig.enableMacroRegimeStop &&
              macroStatus != null) {
            final isBearish = macroStatus == 'DEFENSIVE' ||
                macroStatus == 'BEARISH' ||
                macroStatus == 'RISK_OFF';
            if (isBearish) {
              shouldExit = true;
              exitReason = 'Stop 4: Macro Regime Stop ($macroStatus)';
              quantityToSell = buyQuantity;
              _log(
                  '🌍 $symbol triggered Stop 4 Macro Regime Stop: $exitReason');
            }
          }

          // --- STOP 5: Catastrophic Risk Stop (Hard -50% floor) ---
          if (!shouldExit && _config.strategyConfig.enableCatastrophicStop) {
            final catLimit = _config.strategyConfig.catastrophicStopPercent;
            if (profitLossPercent <= -catLimit) {
              shouldExit = true;
              exitReason =
                  'Stop 5: Catastrophic Stop (${profitLossPercent.toStringAsFixed(1)}% <= -$catLimit%)';
              quantityToSell = buyQuantity;
              _log(
                  '🛑 $symbol triggered Stop 5 Catastrophic Stop: $exitReason');
            }
          }

          // --- Standard Stop Loss Fallback ---
          if (!shouldExit && profitLossPercent <= -stopLossPercent) {
            shouldExit = true;
            exitReason = 'Stop Loss ($stopLossPercent%)';
            quantityToSell = buyQuantity;
            _log(
                '🛑 $symbol hit standard stop loss threshold: ${profitLossPercent.toStringAsFixed(2)}% <= -$stopLossPercent%');
          }

          // --- Take Profit Targets (Only reached if NO protective stop was hit) ---
          if (!shouldExit) {
            // Check +GEX Target (T1 Target Reach)
            if (plusGex != null &&
                currentPrice >= plusGex &&
                profitLossPercent > 0) {
              shouldExit = true;
              exitReason = 'Target Met: +GEX Strike Reached (\$$plusGex)';
              quantityToSell = buyQuantity;
              _log('🎯 $symbol hit +GEX target strike: $exitReason');
            }
            // Check Partial Exits
            else if (enablePartialExits && exitStages.isNotEmpty) {
              for (int i = 0; i < exitStages.length; i++) {
                if (executedStages.contains(i)) continue;

                final stage = exitStages[i];
                if (profitLossPercent >= stage.profitTargetPercent) {
                  shouldExit = true;
                  exitReason =
                      'Partial Take Profit ${i + 1} (${stage.profitTargetPercent}%)';

                  int stageQty =
                      (initialQuantity! * stage.quantityPercent).round();
                  if (stageQty < 1) stageQty = 1;
                  if (stageQty > buyQuantity) stageQty = buyQuantity;

                  quantityToSell = stageQty;
                  stageIndexToMark = i;
                  break;
                }
              }
            }
            // Check Standard Take Profit
            else if (profitLossPercent >= takeProfitPercent) {
              shouldExit = true;
              exitReason = 'Take Profit ($takeProfitPercent%)';
              _log(
                  '💰 $symbol hit take profit threshold: ${profitLossPercent.toStringAsFixed(2)}% >= $takeProfitPercent%');
            }
          }

          // Time-Based Exit
          if (!shouldExit && _config.strategyConfig.timeBasedExitEnabled) {
            final exitMinutes = _config.strategyConfig.timeBasedExitMinutes;
            if (exitMinutes > 0) {
              final tradeTimestamp = buyTrade['timestamp'] as String?;
              if (tradeTimestamp != null) {
                final tradeTime = DateTime.tryParse(tradeTimestamp);
                if (tradeTime != null) {
                  final duration = DateTime.now().difference(tradeTime);
                  if (duration.inMinutes >= exitMinutes) {
                    shouldExit = true;
                    exitReason = 'Time-Based Exit ($exitMinutes min)';
                    quantityToSell = buyQuantity;
                    _log(
                        '⏱️ $symbol time-based exit triggered: ${duration.inMinutes} min >= $exitMinutes min');
                  }
                }
              }
            }
          }

          // Market Close Exit
          if (!shouldExit && _config.strategyConfig.marketCloseExitEnabled) {
            final exitMinutes = _config.strategyConfig.marketCloseExitMinutes;
            final minutesUntilClose = MarketHours.minutesUntilMarketClose();
            if (minutesUntilClose != null &&
                minutesUntilClose <= exitMinutes &&
                minutesUntilClose > 0) {
              shouldExit = true;
              exitReason =
                  'Market Close Exit ($minutesUntilClose min remaining)';
              quantityToSell = buyQuantity;
              _log(
                  '🌅 $symbol market close exit triggered: $minutesUntilClose min remaining <= $exitMinutes min');
            }
          }

          // Technical Exits (RSI & Signal Strength)
          if (!shouldExit &&
              (_config.strategyConfig.rsiExitEnabled ||
                  _config.strategyConfig.signalStrengthExitEnabled)) {
            try {
              // Use pre-fetched signal based on current interval
              final data = fetchedSignals[symbol];

              if (data != null) {
                final multiIndicatorResult =
                    data['multiIndicatorResult'] as Map<String, dynamic>?;

                // Check RSI Exit
                if (!shouldExit && _config.strategyConfig.rsiExitEnabled) {
                  final rsiThreshold = _config.strategyConfig.rsiExitThreshold;
                  if (multiIndicatorResult != null) {
                    final indicators = multiIndicatorResult['indicators']
                        as Map<String, dynamic>?;
                    final rsi = indicators?['rsi'] as Map<String, dynamic>?;
                    final rsiValue = (rsi?['value'] as num?)?.toDouble();

                    if (rsiValue != null && rsiValue >= rsiThreshold) {
                      shouldExit = true;
                      exitReason =
                          'RSI Overbought (RSI ${rsiValue.toStringAsFixed(1)} >= $rsiThreshold)';
                      quantityToSell = buyQuantity *
                          1; // Explicitly cast to int? No buyQuantity is int?
                      quantityToSell = buyQuantity;
                      _log('📈 $symbol RSI exit triggered: $exitReason');
                    }
                  }
                }

                // Check Signal Strength Exit
                if (!shouldExit &&
                    _config.strategyConfig.signalStrengthExitEnabled) {
                  final strengthThreshold =
                      _config.strategyConfig.signalStrengthExitThreshold;
                  final optimization =
                      data['optimization'] as Map<String, dynamic>?;

                  if (optimization != null) {
                    final confidence =
                        (optimization['confidenceScore'] as num?)?.toDouble() ??
                            0.0;
                    if (confidence < strengthThreshold) {
                      shouldExit = true;
                      exitReason =
                          'Weak Signal (Strength ${confidence.toStringAsFixed(1)} < $strengthThreshold)';
                      quantityToSell = buyQuantity;
                      _log(
                          '📉 $symbol Signal Strength exit triggered: $exitReason');
                    }
                  }
                }

                // Check GEX Exit
                if (!shouldExit && _config.strategyConfig.gexExitEnabled) {
                  final gexThreshold = _config.strategyConfig.gexExitThreshold;
                  if (multiIndicatorResult != null) {
                    final indicators = multiIndicatorResult['indicators']
                        as Map<String, dynamic>?;
                    final gexIndicator =
                        indicators?['gammaExposure'] as Map<String, dynamic>?;
                    final gexValue =
                        (gexIndicator?['value'] as num?)?.toDouble();

                    if (gexValue != null && gexValue < gexThreshold) {
                      shouldExit = true;
                      exitReason =
                          'Negative GEX (GEX \$${(gexValue / 1e6).toStringAsFixed(1)}M < \$${(gexThreshold / 1e6).toStringAsFixed(1)}M)';
                      quantityToSell = buyQuantity;
                      _log('📉 $symbol GEX exit triggered: $exitReason');
                    }
                  }
                }
              }
            } catch (e) {
              _log('⚠️ Error checking technical exits for $symbol: $e');
            }
          }

          if (shouldExit) {
            // Never sell more than the position still holds.
            final heldQuantity = remainingBySymbol.putIfAbsent(
                symbol, () => (position.quantity ?? 0).floor());
            if (heldQuantity <= 0) {
              tradesToRemove.add(buyTrade);
              continue;
            }
            if (quantityToSell > heldQuantity) quantityToSell = heldQuantity;

            // Get instrument data
            final instrument = await _getInstrument(
                brokerageService, brokerageUser, instrumentStore, symbol);

            if (instrument == null) {
              _log('⚠️ Could not find instrument for $symbol, skipping exit');
              continue;
            }

            // Execute sell order for the automated buy quantity
            try {
              final isPaperMode = _config.paperTradingMode;
              _log(
                  '${isPaperMode ? '📝 PAPER' : '📤'} Placing exit order: SELL $quantityToSell shares of $symbol at \$$currentPrice ($exitReason)');

              final orderResponse = await _executeOrder(
                brokerageService: brokerageService,
                brokerageUser: brokerageUser,
                account: account,
                instrument: instrument,
                symbol: symbol,
                action: 'sell',
                price: currentPrice,
                quantity: quantityToSell,
                isPaperMode: isPaperMode,
                paperTradingStore: paperTradingStore,
              );

              // Check if order was successful
              const httpOk = 200;
              const httpCreated = 201;
              if (orderResponse.statusCode == httpOk ||
                  orderResponse.statusCode == httpCreated) {
                final exitRecord = {
                  'timestamp': DateTime.now().toIso8601String(),
                  'symbol': symbol,
                  'action': 'SELL',
                  'quantity': quantityToSell,
                  'entryPrice': entryPrice,
                  'exitPrice': currentPrice,
                  'profitLoss': (currentPrice - entryPrice) * quantityToSell,
                  'profitLossPercent': profitLossPercent,
                  'reason': exitReason,
                  'orderResponse': orderResponse.body,
                  'enabledIndicators': buyTrade['enabledIndicators'] ?? [],
                };

                executedExits.add(exitRecord);
                _executedOrderCount++;
                remainingBySymbol[symbol] = heldQuantity - quantityToSell;
                _autoTradeHistory.insert(0, exitRecord);
                _addTradeToHistoryFirestore(exitRecord, userDocRef);

                // Keep only last 100 trades in history
                if (_autoTradeHistory.length > 100) {
                  _autoTradeHistory.removeRange(100, _autoTradeHistory.length);
                }

                // Update trade state
                if (stageIndexToMark != null) {
                  executedStages.add(stageIndexToMark);
                  buyTrade['executedStages'] = executedStages;

                  // Ensure initialQuantity is set if it wasn't (for legacy trades)
                  if (buyTrade['initialQuantity'] == null) {
                    buyTrade['initialQuantity'] = buyQuantity;
                  }

                  buyTrade['quantity'] = buyQuantity - quantityToSell;

                  if (buyTrade['quantity'] <= 0) {
                    tradesToRemove.add(buyTrade);
                    _log(
                        '📝 Marked automated buy trade for removal: $symbol (all stages executed)');
                  } else {
                    _log(
                        '📝 Updated automated buy trade: $symbol remaining ${buyTrade['quantity']}');
                    // Save updated list to Firestore immediately to persist partial state
                    if (userDocRef != null) {
                      await _saveAutomatedBuyTradesToFirestore(userDocRef);
                    }
                  }
                } else {
                  // Full exit (Stop Loss, Trailing Stop, or Legacy TP)
                  tradesToRemove.add(buyTrade);
                  _log(
                      '📝 Marked automated buy trade for removal: $symbol x$buyQuantity after TP/SL exit');
                }

                // Batch exits per symbol so many lots send one notification
                final type = exitReason.contains('Take Profit')
                    ? 'take_profit'
                    : (exitReason.startsWith('Stop Loss') ||
                            exitReason.startsWith('Trailing Stop'))
                        ? 'stop_loss'
                        : 'other';
                final notifyEnabled = switch (type) {
                  'take_profit' => _config.notifyOnTakeProfit,
                  'stop_loss' => _config.notifyOnStopLoss,
                  _ => _config.notifyOnTakeProfit || _config.notifyOnStopLoss,
                };
                if (notifyEnabled) {
                  final summary = exitSummaries.putIfAbsent(
                      '${type}_$symbol',
                      () => {
                            'type': type,
                            'symbol': symbol,
                            'quantity': 0,
                            'profitLoss': 0.0,
                            'lots': 0,
                            'winningLots': 0,
                            'price': currentPrice,
                          });
                  final lotPnL = (currentPrice - entryPrice) * quantityToSell;
                  summary['quantity'] =
                      (summary['quantity'] as int) + quantityToSell;
                  summary['profitLoss'] =
                      (summary['profitLoss'] as double) + lotPnL;
                  summary['lots'] = (summary['lots'] as int) + 1;
                  if (lotPnL >= 0) {
                    summary['winningLots'] =
                        (summary['winningLots'] as int) + 1;
                  }
                }

                _analytics.logEvent(
                  name: 'agentic_trading_exit_executed',
                  parameters: {
                    'symbol': symbol,
                    'reason': exitReason,
                    'profit_loss_percent': profitLossPercent,
                    'quantity': quantityToSell,
                  },
                );

                _log(
                    '✅ Exit order executed for $symbol: $exitReason, P/L: ${profitLossPercent.toStringAsFixed(2)}%');
              } else {
                _log(
                    '❌ Exit order failed for $symbol: ${orderResponse.statusCode} - ${orderResponse.body}');
                _analytics.logEvent(
                  name: 'agentic_trading_exit_failed',
                  parameters: {
                    'symbol': symbol,
                    'status_code': orderResponse.statusCode,
                    'error': orderResponse.body,
                  },
                );
              }
            } catch (e) {
              _log('❌ Error placing exit order for $symbol: $e');
              _analytics.logEvent(
                name: 'agentic_trading_exit_error',
                parameters: {
                  'symbol': symbol,
                  'error': e.toString(),
                },
              );
            }

            // Small delay between orders to avoid rate limiting
            await Future.delayed(const Duration(seconds: _tradeDelaySeconds));
          }
        } catch (e) {
          _log('❌ Error processing position: $e');
        }
      }

      // Few stop-loss/take-profit exits get their own push; market-close,
      // time-based and technical exits, or a large batch, become one summary.
      const maxIndividualPushes = 3;
      final summaries = exitSummaries.values.toList();
      final individual = summaries.where((s) => s['type'] != 'other').toList();
      final sendIndividually = individual.length <= maxIndividualPushes;
      final grouped = sendIndividually
          ? summaries.where((s) => s['type'] == 'other')
          : summaries;

      if (sendIndividually) {
        for (final summary in individual) {
          _sendTradeNotification(
            userDocRef,
            summary['type'] as String,
            symbol: summary['symbol'] as String,
            quantity: summary['quantity'] as int,
            price: summary['price'] as double,
            profitLoss: summary['profitLoss'] as double,
          );
        }
      }
      if (grouped.isNotEmpty) {
        final pnl = grouped.fold<double>(
            0, (total, s) => total + (s['profitLoss'] as double));
        final trades =
            grouped.fold<int>(0, (total, s) => total + (s['lots'] as int));
        final wins = grouped.fold<int>(
            0, (total, s) => total + (s['winningLots'] as int));
        _sendTradeNotification(
          userDocRef,
          'daily_summary',
          dailyStats: {
            'totalTrades': trades,
            'wins': wins,
            'losses': trades - wins,
            'totalPnL': pnl,
          },
        );
      }

      if (tradesToRemove.isNotEmpty) {
        _automatedBuyTrades
            .removeWhere((trade) => tradesToRemove.contains(trade));
        _log(
            '📝 Removed ${tradesToRemove.length} automated buy trade(s) from tracking');

        // Save updated list to Firestore
        await _saveAutomatedBuyTradesToFirestore(userDocRef);
      }

      final message = executedExits.isEmpty
          ? 'No exits triggered'
          : 'Executed ${executedExits.length} exit(s)';

      return {
        'success': executedExits.isNotEmpty,
        'exitsExecuted': executedExits.length,
        'message': message,
        'exits': executedExits,
      };
    } catch (e) {
      _log('❌ Take profit/stop loss monitoring failed: $e');
      _analytics.logEvent(
        name: 'agentic_trading_tp_sl_failed',
        parameters: {'error': e.toString()},
      );

      return {
        'success': false,
        'exitsExecuted': 0,
        'message': 'Monitoring failed: ${e.toString()}',
        'exits': [],
      };
    } finally {
      _isMonitoringExits = false;
    }
  }

  /// Send trade notification via Cloud Function
  ///
  /// Calls the sendAgenticTradeNotification Cloud Function to send
  /// push notifications to the user's devices.
  Future<void> _sendTradeNotification(
    DocumentReference? userDocRef,
    String type, {
    String? symbol,
    int? quantity,
    double? price,
    double? profitLoss,
    Map<String, dynamic>? dailyStats,
  }) async {
    if (userDocRef == null) return;

    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('sendAgenticTradeNotification');

      final data = {
        'userId': userDocRef.id,
        'type': type,
        'isPaperTrade': _config.paperTradingMode,
        if (symbol != null) 'symbol': symbol,
        if (quantity != null) 'quantity': quantity,
        if (price != null) 'price': price,
        if (profitLoss != null) 'profitLoss': profitLoss,
        if (dailyStats != null) 'dailyStats': dailyStats,
      };

      await callable.call(data);
      _log('📲 Notification sent: $type for $symbol');
    } catch (e) {
      _log('❌ Failed to send notification: $e');
      // Don't throw - notifications are non-critical
    }
  }
}
