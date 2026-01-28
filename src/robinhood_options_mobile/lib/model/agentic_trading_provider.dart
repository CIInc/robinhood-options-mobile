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
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/paper_trading_store.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_config.dart';
import 'package:robinhood_options_mobile/model/macro_assessment.dart';

class AgenticTradingProvider with ChangeNotifier {
  final FirebaseAnalytics _analytics;

  AgenticTradingProvider({FirebaseAnalytics? analytics})
      : _analytics = analytics ?? FirebaseAnalytics.instance;

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
  DateTime? _lastAutoTradeTime;
  int _dailyTradeCount = 0;
  DateTime? _dailyTradeCountResetDate;
  bool _emergencyStopActivated = false;
  final List<Map<String, dynamic>> _autoTradeHistory = [];
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
  DateTime? _lastSignalCheckTime;
  final Map<String, int> _processedSignalTimestamps = {};

  // Activity Log
  final List<String> _activityLog = [];
  List<String> get activityLog => _activityLog;

  // Macro Assessment
  MacroAssessment? _macroAssessment;
  MacroAssessment? get macroAssessment => _macroAssessment;

  Future<void> fetchMacroAssessment() async {
    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('getMacroAssessment');
      final result = await callable.call();
      if (result.data != null) {
        _macroAssessment =
            MacroAssessment.fromMap(Map<String, dynamic>.from(result.data));
        notifyListeners();
        _log("Macro assessment updated: ${_macroAssessment?.status}");
      }
    } catch (e) {
      _log("Error fetching macro assessment: $e");
    }
  }

  void _log(String message) {
    debugPrint(message);
    final now = DateTime.now();
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
  bool get emergencyStopActivated => _emergencyStopActivated;
  List<Map<String, dynamic>> get autoTradeHistory => _autoTradeHistory;
  List<Map<String, dynamic>> get pendingOrders => _pendingOrders;
  DateTime? get nextAutoTradeTime => _nextAutoTradeTime;
  int get autoTradeCountdownSeconds => _autoTradeCountdownSeconds;
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
        userDocRef: userDocRef,
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
      final Map<String, dynamic> portfolioState = {
        'portfolioValue': portfolioStore.items.isNotEmpty
            ? portfolioStore.items.first.equity
            : 0.0,
        'buyingPower': firstAccount?.buyingPower ?? 0.0,
        'cashAvailable': firstAccount?.portfolioCash ?? 0.0,
        'positions': portfolioStore.items.length,
      };

      // Add stock positions
      for (var pos in instrumentPositionStore.items) {
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
      for (var pos in optionPositionStore.items) {
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

      // Capture start time for next cycle's reference
      final cycleStartTime = DateTime.now();

      // Fetch recent signals based on strategy
      final enabledIndicators = _config.strategyConfig.enabledIndicators;
      final activeIndicators = enabledIndicators.entries
          .where((entry) => entry.value == true)
          .map((entry) => entry.key)
          .toList();

      final requireAllIndicatorsGreen =
          _config.strategyConfig.requireAllIndicatorsGreen;
      final minSignalStrength =
          _config.strategyConfig.minSignalStrength.toInt();

      Map<String, String>? indicatorFilters;
      int minStrengthFilter = minSignalStrength;

      if (activeIndicators.isNotEmpty) {
        indicatorFilters = {for (var i in activeIndicators) i: 'BUY'};
      }

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

      if (symbols != null && symbols.isNotEmpty) {
        tradeSignals = await tradeSignalsProvider.fetchSignals(
          sortBy: 'timestamp',
          startDate: startDate,
          symbols: symbols,
          interval: _config.strategyConfig.interval,
        );

        // Apply strength of selected indicators
        if (activeIndicators.isNotEmpty) {
          tradeSignals = tradeSignals.where((s) {
            final indicators = s['multiIndicatorResult']?['indicators'];
            if (indicators is! Map) return false;
            int buys = 0;
            for (var ind in activeIndicators) {
              if (indicators[ind]?['signal'] == 'BUY') buys++;
            }
            return (buys / activeIndicators.length) * 100 >= minStrengthFilter;
          }).toList();
        }
      } else {
        tradeSignals = await tradeSignalsProvider.fetchSignals(
          indicatorFilters: indicatorFilters,
          minSignalStrength: minStrengthFilter,
          sortBy: 'timestamp',
          // startDate: startDate,
          interval: _config.strategyConfig.interval,
        );
      }

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

      // Mark signals as processed to prevent duplicates
      for (final signal in tradeSignals) {
        final symbol = signal['symbol'] as String?;
        final timestamp = signal['timestamp'] as int?;
        if (symbol != null && timestamp != null) {
          final signalId = '${symbol}_$timestamp';
          _processedSignalTimestamps[signalId] = timestamp;
        }
      }

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
      );

      updateLastAutoTradeResult(result);

      // Update last check time and prune processed history
      _lastSignalCheckTime = cycleStartTime;

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
        _log('📊 Monitoring ${positionsToMonitor.length} positions for TP/SL');
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
        }
      } else {
        _log('📊 No positions to monitor for TP/SL');
      }
      _log('✅ Auto-trade cycle complete.');
    } catch (e) {
      _log('❌ Auto-trade error: $e');
    }
  }

  /// Load configuration from User model
  void loadConfigFromUser(AgenticTradingConfig? agenticTradingConfig) {
    if (agenticTradingConfig != null) {
      _config = agenticTradingConfig;
      _analytics.logEvent(name: 'agentic_trading_config_loaded_from_user');
    } else {
      _config = AgenticTradingConfig(strategyConfig: TradeStrategyConfig());
      _analytics.logEvent(name: 'agentic_trading_config_loaded_defaults');
    }
    notifyListeners();
  }

  /// Update configuration and save to User document
  Future<void> updateConfig(
    AgenticTradingConfig newConfig,
    DocumentReference userDocRef,
  ) async {
    _config = newConfig;

    try {
      await userDocRef.update({'agenticTradingConfig': newConfig.toJson()});
      _analytics.logEvent(name: 'agentic_trading_config_updated');
    } catch (e) {
      _analytics.logEvent(
        name: 'agentic_trading_config_update_failed',
        parameters: {'error': e.toString()},
      );
    }
    notifyListeners();
  }

  /// Save automated buy trades to Firestore
  Future<void> _saveAutomatedBuyTradesToFirestore(
      DocumentReference? userDocRef) async {
    if (userDocRef == null) {
      _log('⚠️ Cannot save automated buy trades: userDocRef is null');
      return;
    }

    try {
      // Store in a subcollection under the user document
      final tradesCollection = userDocRef.collection('automated_buy_trades');

      // Clear existing trades first (we'll replace with current state)
      final existingDocs = await tradesCollection.get();
      for (final doc in existingDocs.docs) {
        await doc.reference.delete();
      }

      // Save current automated buy trades
      for (final trade in _automatedBuyTrades) {
        await tradesCollection.add(trade);
      }

      _log(
          '💾 Saved ${_automatedBuyTrades.length} automated buy trades to Firestore');
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

      // _log(
      //     '📥 Loaded ${_automatedBuyTrades.length} automated buy trades from Firestore');
      if (_automatedBuyTrades.isNotEmpty) {
        final symbols = _automatedBuyTrades
            .map((t) => '${t['symbol']} x${t['quantity']}')
            .join(', ');
        // _log('📝 Automated buy trades: $symbols');
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

    try {
      final historyCollection = userDocRef.collection('auto_trade_history');
      final snapshot = await historyCollection
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      _autoTradeHistory.clear();
      _autoTradeHistory.addAll(
        snapshot.docs.map((doc) => doc.data()),
      );

      _log('📖 Loaded ${_autoTradeHistory.length} trade history records');
      notifyListeners();
    } catch (e) {
      _log('❌ Failed to load auto-trade history: $e');
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
          _pendingOrders.add(order);
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
          'processedSignals': processedSignals,
        };
      }

      // Get enabled indicators from config
      final enabledIndicators = _config.strategyConfig.enabledIndicators;
      final activeIndicators = enabledIndicators.entries
          .where((entry) => entry.value == true)
          .map((entry) => entry.key)
          .toList();

      final requireAllIndicatorsGreen =
          _config.strategyConfig.requireAllIndicatorsGreen;
      final minSignalStrength = _config.strategyConfig.minSignalStrength;

      // _log('📊 Active indicators for auto-trade filtering: $activeIndicators');
      // _log(
      //     '📊 Strategy: ${requireAllIndicatorsGreen ? "All Indicators Green" : "Min Signal Strength ($minSignalStrength)"}');

      // Get current signals - filter for BUY signals that pass enabled indicators
      // processedSignals is defined at the top of the method

      final buySignals = <Map<String, dynamic>>[];

      for (final signal in tradeSignals) {
        // final signalType = signal['signal'] as String?;
        // if (signalType != 'BUY') continue;

        String? rejectionReason;
        bool isAccepted = false;

        // Check if all enabled indicators agree with BUY signal
        final multiIndicatorResult =
            signal['multiIndicatorResult'] as Map<String, dynamic>?;

        if (multiIndicatorResult == null) {
          rejectionReason = 'Missing multi-indicator result';
        } else {
          final indicators =
              multiIndicatorResult['indicators'] as Map<String, dynamic>?;

          if (indicators == null || indicators.isEmpty) {
            rejectionReason = 'No indicators data';
          } else if (activeIndicators.isEmpty) {
            rejectionReason = 'No active indicators configured';
          } else {
            if (requireAllIndicatorsGreen) {
              // Verify that all enabled indicators have BUY signals
              for (final indicator in activeIndicators) {
                final indicatorData =
                    indicators[indicator] as Map<String, dynamic>?;
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
                    indicators[indicator] as Map<String, dynamic>?;
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
              final customIndicatorsResult =
                  multiIndicatorResult['customIndicators']
                      as Map<String, dynamic>?;
              if (customIndicatorsResult != null) {
                for (final key in customIndicatorsResult.keys) {
                  totalEnabled++;
                  final indicatorData =
                      customIndicatorsResult[key] as Map<String, dynamic>?;
                  if (indicatorData != null) {
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

      // _log(
      //     '🎯 Found ${buySignals.length} BUY signals matching enabled indicators for auto-trade');
      _log('🎯 Found ${buySignals.length} qualified BUY signals');

      final executedTrades = <Map<String, dynamic>>[];
      final dailyLimit = _config.strategyConfig.dailyTradeLimit;

      // Process each signal (respecting daily limit)
      for (final signal in buySignals) {
        // Check if we've hit the limit
        if (_dailyTradeCount >= dailyLimit) {
          _log(
              '⚠️ Reached daily trade limit during execution ($_dailyTradeCount/$dailyLimit)');
          break;
        }

        final symbol = signal['symbol'] as String?;
        if (symbol == null || symbol.isEmpty) continue;

        try {
          // Get current price from signal
          final currentPrice =
              (signal['currentPrice'] as num?)?.toDouble() ?? 0.0;
          if (currentPrice <= 0) {
            _log('⚠️ Invalid price for $symbol ($currentPrice), skipping');
            continue;
          }

          _log('🤖 Auto-trading $symbol at \$$currentPrice');

          // Initiate trade proposal via TradeSignalsProvider
          final proposalResult =
              await tradeSignalsProvider.initiateTradeProposal(
            symbol: symbol,
            currentPrice: currentPrice,
            portfolioState: portfolioState,
            config: _config,
            interval: signal['interval'] as String?,
            skipSignalUpdate: true,
          );

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
                if (strength != null) {
                  reason += ' (${strength.toString()}%)';
                }
                if (interval != null) {
                  reason += ' • $interval';
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
                  'signal': signal,
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
            final reasonToLog =
                assessmentReason ?? (proposalResult['message'] as String?);
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

  /// Approves a pending order and executes it
  Future<void> approveOrder(
    Map<String, dynamic> order, {
    required dynamic brokerageUser,
    required dynamic account,
    required dynamic brokerageService,
    DocumentReference? userDocRef,
    PaperTradingStore? paperTradingStore,
  }) async {
    if (!_pendingOrders.contains(order)) {
      _log('❌ Order not found in pending list');
      return;
    }

    final symbol = order['symbol'] as String;
    final action = order['action'] as String;
    final quantity = order['quantity'] as int;
    final price = (order['price'] as num).toDouble();
    final instrument = order['instrument'];

    try {
      final side = action.toLowerCase() == 'buy' ? 'buy' : 'sell';
      final isPaperMode = _config.paperTradingMode;

      if (!isPaperMode && brokerageService == null) {
        _log('❌ Cannot approve real order without brokerage service');
        return;
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
            'timestamp': DateTime.now().toIso8601String(),
            'enabledIndicators': List<String>.from(
              _config.strategyConfig.enabledIndicators.entries
                  .where((e) => e.value == true)
                  .map((e) => e.key),
            ),
          });
          if (userDocRef != null) {
            await _saveAutomatedBuyTradesToFirestore(userDocRef);
          }
        }

        // Remove from pending
        _pendingOrders.remove(order);
        if (userDocRef != null) {
          await _removePendingOrderFromFirestore(userDocRef, order);
        }
        notifyListeners();

        _log('✅ Approved order executed for $symbol');
      } else {
        _log(
            '❌ Approved order failed for $symbol: ${orderResponse.statusCode}');
      }
    } catch (e) {
      _log('❌ Error executing approved order for $symbol: $e');
    }
  }

  /// Rejects a pending order
  Future<void> rejectOrder(Map<String, dynamic> order,
      {DocumentReference? userDocRef}) async {
    if (_pendingOrders.contains(order)) {
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
      if (_automatedBuyTrades.isNotEmpty) {
        final symbols = _automatedBuyTrades
            .map((t) => '${t['symbol']} x${t['quantity']}')
            .join(', ');
        _log('📝 Automated buy trades: $symbols');
      }

      final executedExits = <Map<String, dynamic>>[];
      final tradesToRemove = <Map<String, dynamic>>[];

      // Create a map for faster position lookup
      final positionMap = {for (var p in positions) p.instrumentObj?.symbol: p};

      // Check each automated buy trade
      for (final buyTrade in _automatedBuyTrades) {
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

          if (enablePartialExits && exitStages.isNotEmpty) {
            // Check stages
            for (int i = 0; i < exitStages.length; i++) {
              if (executedStages.contains(i)) continue;

              final stage = exitStages[i];
              if (profitLossPercent >= stage.profitTargetPercent) {
                shouldExit = true;
                exitReason =
                    'Partial Take Profit ${i + 1} (${stage.profitTargetPercent}%)';

                // Calculate quantity
                int stageQty =
                    (initialQuantity! * stage.quantityPercent).round();
                if (stageQty < 1) stageQty = 1;
                if (stageQty > buyQuantity) stageQty = buyQuantity;

                quantityToSell = stageQty;
                stageIndexToMark = i;
                break; // Execute one stage at a time
              }
            }

            // If no stage hit, check stop loss (full exit)
            if (!shouldExit && profitLossPercent <= -stopLossPercent) {
              shouldExit = true;
              exitReason = 'Stop Loss ($stopLossPercent%)';
              quantityToSell = buyQuantity;
            }
          } else {
            // Check take profit
            if (profitLossPercent >= takeProfitPercent) {
              shouldExit = true;
              exitReason = 'Take Profit ($takeProfitPercent%)';
              _log(
                  '💰 $symbol hit take profit threshold: ${profitLossPercent.toStringAsFixed(2)}% >= $takeProfitPercent%');
            }
            // Check stop loss
            else if (profitLossPercent <= -stopLossPercent) {
              shouldExit = true;
              exitReason = 'Stop Loss ($stopLossPercent%)';
              _log(
                  '🛑 $symbol hit stop loss threshold: ${profitLossPercent.toStringAsFixed(2)}% <= -$stopLossPercent%');
            }
          }

          // Trailing Stop Loss: exit if price drops by trailingStopPercent
          if (!shouldExit && _config.strategyConfig.trailingStopEnabled) {
            final trailPercent = _config.strategyConfig.trailingStopPercent;
            final prevHighest =
                (buyTrade['highestPrice'] as num?)?.toDouble() ?? entryPrice;
            final newHighest =
                currentPrice > prevHighest ? currentPrice : prevHighest;
            if (newHighest != prevHighest) {
              buyTrade['highestPrice'] = newHighest;
              _log('🔼 $symbol new highest price since entry: $newHighest');
            }
            final trailStopPrice = newHighest * (1 - trailPercent / 100.0);
            if (currentPrice <= trailStopPrice && currentPrice > entryPrice) {
              shouldExit = true;
              exitReason = 'Trailing Stop ($trailPercent%)';
              quantityToSell = buyQuantity; // Sell remaining
              _log(
                  '🟡 $symbol trailing stop triggered: current $currentPrice <= trail $trailStopPrice (highest $newHighest)');
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
              // Fetch latest signal based on current interval
              final interval = _config.strategyConfig.interval;
              final docId = interval == '1d'
                  ? 'signals_$symbol'
                  : 'signals_${symbol}_$interval';

              final signalSnapshot = await FirebaseFirestore.instance
                  .collection('agentic_trading')
                  .doc(docId)
                  .get();

              if (signalSnapshot.exists && signalSnapshot.data() != null) {
                final data = signalSnapshot.data()!;
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
              }
            } catch (e) {
              _log('⚠️ Error checking technical exits for $symbol: $e');
            }
          }

          if (shouldExit) {
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
                  'profitLossPercent': profitLossPercent,
                  'reason': exitReason,
                  'orderResponse': orderResponse.body,
                  'enabledIndicators': buyTrade['enabledIndicators'] ?? [],
                };

                executedExits.add(exitRecord);
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

                // Send notification based on exit type
                final isTakeProfit = exitReason.contains('Take Profit');
                if (isTakeProfit && _config.notifyOnTakeProfit) {
                  _sendTradeNotification(
                    userDocRef,
                    'take_profit',
                    symbol: symbol,
                    quantity: quantityToSell,
                    price: currentPrice,
                    profitLoss: (currentPrice - entryPrice) * quantityToSell,
                  );
                } else if (!isTakeProfit && _config.notifyOnStopLoss) {
                  _sendTradeNotification(
                    userDocRef,
                    'stop_loss',
                    symbol: symbol,
                    quantity: quantityToSell,
                    price: currentPrice,
                    profitLoss: (currentPrice - entryPrice) * quantityToSell,
                  );
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

      // Remove completed/closed trades from tracking (use removeWhere for efficiency)
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
