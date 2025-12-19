import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:robinhood_options_mobile/utils/market_hours.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_store.dart';
import 'package:robinhood_options_mobile/model/trade_signals_provider.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_config.dart';

class AgenticTradingProvider with ChangeNotifier {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

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

  bool _isAgenticTradingEnabled = false;
  Map<String, dynamic> _config = {};

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

  bool get isAgenticTradingEnabled => _isAgenticTradingEnabled;
  Map<String, dynamic> get config => _config;

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

  AgenticTradingProvider();

  /// Initialize the timer's next trade time (called from navigation widget when timer starts)
  void initializeAutoTradeTimer() {
    _nextAutoTradeTime = DateTime.now().add(const Duration(minutes: 5));
    _autoTradeCountdownSeconds = 5 * 60;
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
    _nextAutoTradeTime = DateTime.now().add(const Duration(minutes: 5));
    _autoTradeCountdownSeconds = 5 * 60;
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
    _lastAutoTradeResult = result;
    notifyListeners();
  }

  @override
  void dispose() {
    debugPrint('🧹 Disposing AgenticTradingProvider');
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
      debugPrint('🤖 Auto-trade timer already running, skipping start');
      return;
    }

    _autoTradeTimer?.cancel();

    // Initialize countdown
    initializeAutoTradeTimer();

    _autoTradeTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final countdownReachedZero = tickAutoTradeCountdown();
      if (!countdownReachedZero) return;

      try {
        // Gather required providers from context lazily
        final userStore =
            Provider.of<BrokerageUserStore>(context, listen: false);
        final accountStore = Provider.of<AccountStore>(context, listen: false);
        final instrumentStore =
            Provider.of<InstrumentStore>(context, listen: false);
        final portfolioStore =
            Provider.of<PortfolioStore>(context, listen: false);
        final tradeSignalsProvider =
            Provider.of<TradeSignalsProvider>(context, listen: false);

        // Check auto-trade enabled
        final autoTradeEnabled = _config['autoTradeEnabled'] as bool? ?? false;
        if (!autoTradeEnabled) {
          debugPrint('🤖 Auto-trade check: disabled in config');
          return;
        }

        // Validate user/account
        if (userStore.items.isEmpty ||
            userStore.currentUser == null ||
            accountStore.items.isEmpty) {
          debugPrint('🤖 Auto-trade check: missing user or account data');
          return;
        }

        final currentUser = userStore.currentUser;
        final firstAccount = accountStore.items.first;
        if (currentUser == null) {
          debugPrint('🤖 Auto-trade check: currentUser is null');
          return;
        }

        // Build portfolio state
        final portfolioState = {
          'portfolioValue': portfolioStore.items.isNotEmpty
              ? portfolioStore.items.first.equity
              : 0.0,
          'cashAvailable': firstAccount.portfolioCash,
          'positions': portfolioStore.items.length,
        };

        debugPrint('🤖 Auto-trade check: executing auto-trade...');

        final tradeSignals = tradeSignalsProvider.tradeSignals;

        final result = await autoTrade(
          tradeSignals: tradeSignals,
          tradeSignalsProvider: tradeSignalsProvider,
          portfolioState: portfolioState,
          brokerageUser: currentUser,
          account: firstAccount,
          brokerageService: brokerageService,
          instrumentStore: instrumentStore,
          userDocRef: userDocRef,
        );

        updateLastAutoTradeResult(result);

        // Monitor TP/SL when positions exist
        final instrumentPositionStore =
            Provider.of<InstrumentPositionStore>(context, listen: false);
        if (instrumentPositionStore.items.isNotEmpty) {
          debugPrint(
              '📊 Monitoring ${instrumentPositionStore.items.length} positions for TP/SL...');
          final tpSlResult = await monitorTakeProfitStopLoss(
            positions: instrumentPositionStore.items,
            brokerageUser: currentUser,
            account: firstAccount,
            brokerageService: brokerageService,
            instrumentStore: instrumentStore,
            userDocRef: userDocRef,
          );
          debugPrint(
              '📊 TP/SL result: ${tpSlResult['success']}, exits: ${tpSlResult['exitsExecuted']}, message: ${tpSlResult['message']}');
        } else {
          debugPrint('📊 No positions to monitor for TP/SL');
        }
      } catch (e) {
        debugPrint('❌ Auto-trade timer error: $e');
      }
    });

    debugPrint(
        '🤖 Auto-trade timer started (provider-owned, 5-minute cadence)');
  }

  void toggleAgenticTrading(bool? value) {
    _isAgenticTradingEnabled = value ?? false;
    _config['enabled'] = _isAgenticTradingEnabled;
    _analytics.logEvent(
      name: 'agentic_trading_toggled',
      parameters: {'enabled': _isAgenticTradingEnabled.toString()},
    );
    notifyListeners();
  }

  /// Load configuration from User model
  void loadConfigFromUser(dynamic agenticTradingConfig) {
    if (agenticTradingConfig != null) {
      _config = agenticTradingConfig.toJson();
      _isAgenticTradingEnabled = agenticTradingConfig.enabled;
      _analytics.logEvent(name: 'agentic_trading_config_loaded_from_user');
    } else {
      _config = {
        'enabled': false,
        'smaPeriodFast': 10,
        'smaPeriodSlow': 30,
        'tradeQuantity': 1,
        'maxPositionSize': 100,
        'maxPortfolioConcentration': 0.5,
        'rsiPeriod': 14,
        'marketIndexSymbol': 'SPY',
        'autoTradeEnabled': false,
        'dailyTradeLimit': 5,
        'autoTradeCooldownMinutes': 60,
        'maxDailyLossPercent': 2.0,
        'enabledIndicators': {
          'priceMovement': true,
          'momentum': true,
          'marketDirection': true,
          'volume': true,
          'macd': true,
          'bollingerBands': true,
          'stochastic': true,
          'atr': true,
          'obv': true,
        },
        'paperTradingMode': false,
        'timeBasedExitEnabled': false,
        'timeBasedExitMinutes': 0,
      };
      _isAgenticTradingEnabled = false;
      _analytics.logEvent(name: 'agentic_trading_config_loaded_defaults');
    }
    notifyListeners();
  }

  /// Update configuration and save to User document
  Future<void> updateConfig(
    Map<String, dynamic> newConfig,
    DocumentReference userDocRef,
  ) async {
    _config = newConfig;
    try {
      await userDocRef.update({'agenticTradingConfig': newConfig});
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
      debugPrint('⚠️ Cannot save automated buy trades: userDocRef is null');
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

      debugPrint(
          '💾 Saved ${_automatedBuyTrades.length} automated buy trades to Firestore');
      _analytics.logEvent(
        name: 'agentic_trading_trades_saved',
        parameters: {'count': _automatedBuyTrades.length},
      );
    } catch (e) {
      debugPrint('❌ Failed to save automated buy trades to Firestore: $e');
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
      debugPrint('⚠️ Cannot load automated buy trades: userDocRef is null');
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

      debugPrint(
          '📥 Loaded ${_automatedBuyTrades.length} automated buy trades from Firestore');
      if (_automatedBuyTrades.isNotEmpty) {
        final symbols = _automatedBuyTrades
            .map((t) => '${t['symbol']} x${t['quantity']}')
            .join(', ');
        debugPrint('📝 Automated buy trades: $symbols');
      }

      _analytics.logEvent(
        name: 'agentic_trading_trades_loaded',
        parameters: {'count': _automatedBuyTrades.length},
      );

      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to load automated buy trades from Firestore: $e');
      _analytics.logEvent(
        name: 'agentic_trading_trades_load_failed',
        parameters: {'error': e.toString()},
      );
    }
  }

  // Public getter for market status (delegates to utility)
  bool get isMarketOpen {
    final allowPreMarket = _config['allowPreMarketTrading'] as bool? ?? false;
    final allowAfterHours = _config['allowAfterHoursTrading'] as bool? ?? false;
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
    if (_config['notifyOnEmergencyStop'] as bool? ?? true) {
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
    if (!(_config['notifyDailySummary'] as bool? ?? false)) {
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
      final profitLoss = trade['profitLoss'] as double?; // may be null
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
      debugPrint('🔄 Reset daily trade counters for $today');
    }
  }

  /// Checks if auto-trading can proceed based on configured limits
  bool _canAutoTrade() {
    // Reset daily counters if needed
    _resetDailyCounters();

    // Check if auto-trade is enabled
    final autoTradeEnabled = _config['autoTradeEnabled'] as bool? ?? false;
    if (!autoTradeEnabled) {
      debugPrint('❌ Auto-trade not enabled in config');
      return false;
    }

    // Check emergency stop
    if (_emergencyStopActivated) {
      debugPrint('🛑 Emergency stop activated');
      return false;
    }

    // Check if market is open (including extended hours if enabled)
    final allowPreMarket = _config['allowPreMarketTrading'] as bool? ?? false;
    final allowAfterHours = _config['allowAfterHoursTrading'] as bool? ?? false;
    final includeExtended = allowPreMarket || allowAfterHours;

    if (!MarketHours.isMarketOpen(includeExtendedHours: includeExtended)) {
      debugPrint(
          '🏦 Market is closed (Extended hours enabled: $includeExtended)');
      return false;
    }

    // Check daily trade limit
    final dailyLimit = _config['dailyTradeLimit'] as int? ?? 5;
    if (_dailyTradeCount >= dailyLimit) {
      debugPrint('📊 Daily trade limit reached: $_dailyTradeCount/$dailyLimit');
      return false;
    }

    // Check cooldown period
    if (_lastAutoTradeTime != null) {
      final cooldownMinutes = _config['autoTradeCooldownMinutes'] as int? ?? 60;
      final cooldownDuration = Duration(minutes: cooldownMinutes);
      final timeSinceLastTrade = DateTime.now().difference(_lastAutoTradeTime!);

      if (timeSinceLastTrade < cooldownDuration) {
        final remainingMinutes =
            (cooldownDuration - timeSinceLastTrade).inMinutes;
        debugPrint('⏰ Cooldown active: $remainingMinutes minutes remaining');
        return false;
      }
    }

    return true;
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
  }) async {
    _isAutoTrading = true;
    _showAutoTradingVisual = true;
    _autoTradingVisualTimer?.cancel(); // Cancel any existing timer
    notifyListeners();

    try {
      // Validate required parameters
      if (brokerageUser == null ||
          account == null ||
          brokerageService == null ||
          instrumentStore == null) {
        debugPrint('❌ Missing required parameters for auto-trade');
        _isAutoTrading = false;
        _scheduleVisualStateReset();
        notifyListeners();
        return {
          'success': false,
          'tradesExecuted': 0,
          'message':
              'Missing required parameters (brokerageUser, account, service, or store)',
          'trades': [],
        };
      }

      // Check if auto-trading can proceed
      if (!_canAutoTrade()) {
        _isAutoTrading = false;
        _scheduleVisualStateReset();
        notifyListeners();
        return {
          'success': false,
          'tradesExecuted': 0,
          'message': 'Auto-trade conditions not met',
          'trades': [],
        };
      }

      // Get enabled indicators from config
      final enabledIndicators =
          _config['enabledIndicators'] as Map<String, dynamic>? ?? {};
      final activeIndicators = enabledIndicators.entries
          .where((entry) => entry.value == true)
          .map((entry) => entry.key)
          .toList();

      debugPrint(
          '📊 Active indicators for auto-trade filtering: $activeIndicators');

      // Get current signals - filter for BUY signals that pass enabled indicators
      final buySignals = tradeSignals.where((signal) {
        // final signalType = signal['signal'] as String?;
        // if (signalType != 'BUY') return false;

        // If no indicators are enabled, don't accept any BUY signals
        if (activeIndicators.isEmpty) {
          return false;
        }

        // Check if all enabled indicators agree with BUY signal
        final multiIndicatorResult =
            signal['multiIndicatorResult'] as Map<String, dynamic>?;
        if (multiIndicatorResult == null) {
          return false;
        }

        final indicators =
            multiIndicatorResult['indicators'] as Map<String, dynamic>?;
        if (indicators == null || indicators.isEmpty) {
          return false;
        }

        // Verify that all enabled indicators have BUY signals
        for (final indicator in activeIndicators) {
          final indicatorData = indicators[indicator] as Map<String, dynamic>?;
          if (indicatorData == null) {
            debugPrint('⚠️ Indicator $indicator not found in signal');
            return false;
          }
          final indicatorSignal = indicatorData['signal'] as String?;
          if (indicatorSignal != 'BUY') {
            return false;
          }
        }

        return true;
      }).toList();

      if (buySignals.isEmpty) {
        debugPrint('📭 No BUY signals available matching enabled indicators');
        _isAutoTrading = false;
        _scheduleVisualStateReset();
        notifyListeners();
        return {
          'success': false,
          'tradesExecuted': 0,
          'message': 'No BUY signals matching enabled indicators',
          'trades': [],
        };
      }

      debugPrint(
          '🎯 Found ${buySignals.length} BUY signals matching enabled indicators for auto-trade');

      final executedTrades = <Map<String, dynamic>>[];
      final dailyLimit = _config['dailyTradeLimit'] as int? ?? 5;

      // Process each signal (respecting daily limit)
      for (final signal in buySignals) {
        // Check if we've hit the limit
        if (_dailyTradeCount >= dailyLimit) {
          debugPrint('⚠️ Reached daily trade limit during execution');
          break;
        }

        final symbol = signal['symbol'] as String?;
        if (symbol == null || symbol.isEmpty) continue;

        try {
          // Get current price from signal
          final currentPrice = signal['currentPrice'] as double? ?? 0.0;
          if (currentPrice <= 0) {
            debugPrint('⚠️ Invalid price for $symbol, skipping');
            continue;
          }

          debugPrint('🤖 Auto-trading $symbol at \$$currentPrice');

          // Initiate trade proposal via TradeSignalsProvider
          await tradeSignalsProvider.initiateTradeProposal(
            symbol: symbol,
            currentPrice: currentPrice,
            portfolioState: portfolioState,
            config: _config,
            interval: signal['interval'] as String?,
          );

          // If proposal was approved, execute the order
          if (tradeSignalsProvider.lastTradeProposal != null) {
            final action =
                tradeSignalsProvider.lastTradeProposal!['action'] as String?;
            final quantity =
                tradeSignalsProvider.lastTradeProposal!['quantity'] as int?;

            if (action == null || quantity == null || quantity <= 0) {
              debugPrint('⚠️ Invalid proposal for $symbol, skipping execution');
              continue;
            }

            // Get instrument from store
            dynamic instrument;
            try {
              // Get instrument by symbol
              instrument = await brokerageService.getInstrumentBySymbol(
                brokerageUser,
                instrumentStore,
                symbol,
              );
              if (instrument == null) {
                debugPrint(
                    '⚠️ Could not find instrument for $symbol, skipping');
                continue;
              }
            } catch (e) {
              debugPrint('⚠️ Error fetching instrument for $symbol: $e');
              continue;
            }

            // Execute the order through brokerage service
            try {
              // Validate action is BUY or SELL
              final normalizedAction = action.toUpperCase();
              if (normalizedAction != 'BUY' && normalizedAction != 'SELL') {
                debugPrint('⚠️ Invalid action "$action" for $symbol, skipping');
                continue;
              }

              final side = normalizedAction == 'BUY' ? 'buy' : 'sell';

              final isPaperMode = _config['paperTradingMode'] as bool? ?? false;
              final requireApproval =
                  _config['requireApproval'] as bool? ?? false;

              if (requireApproval) {
                final pendingOrder = {
                  'id': DateTime.now().millisecondsSinceEpoch.toString(),
                  'timestamp': DateTime.now().toIso8601String(),
                  'symbol': symbol,
                  'action': normalizedAction,
                  'quantity': quantity,
                  'price': currentPrice,
                  'instrument': instrument,
                  'status': 'pending',
                  'reason': 'Auto-trade signal',
                };
                _pendingOrders.add(pendingOrder);
                notifyListeners();
                debugPrint('📝 Order added to pending approval: $symbol');
                continue;
              }

              debugPrint(
                  '${isPaperMode ? '📝 PAPER' : '📤'} Placing order: $action $quantity shares of $symbol at \$$currentPrice');

              // In paper trading mode, simulate order without calling broker API
              final orderResponse = isPaperMode
                  ? _simulatePaperOrder(
                      normalizedAction, symbol, quantity, currentPrice)
                  : await brokerageService.placeInstrumentOrder(
                      brokerageUser,
                      account,
                      instrument,
                      symbol,
                      side,
                      currentPrice,
                      quantity,
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
                  'proposal': Map<String, dynamic>.from(
                      tradeSignalsProvider.lastTradeProposal!),
                  'assessment': tradeSignalsProvider.lastAssessment != null
                      ? Map<String, dynamic>.from(
                          tradeSignalsProvider.lastAssessment!)
                      : null,
                  'orderResponse': orderResponse.body,
                };

                executedTrades.add(tradeRecord);
                _autoTradeHistory.insert(0, tradeRecord);

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
                      (_config['enabledIndicators'] as Map<String, dynamic>? ??
                              {})
                          .entries
                          .where((e) => e.value == true)
                          .map((e) => e.key),
                    ),
                  });
                  debugPrint(
                      '📝 Added automated BUY trade: $symbol x$quantity @ \$$currentPrice for TP/SL tracking');

                  // Save to Firestore
                  await _saveAutomatedBuyTradesToFirestore(userDocRef);

                  // Send notification if enabled
                  if (_config['notifyOnBuy'] as bool? ?? true) {
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

                debugPrint(
                    '✅ Order executed for $symbol: $action $quantity shares at \$$currentPrice ($_dailyTradeCount/$dailyLimit today)');
              } else {
                debugPrint(
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
              debugPrint('❌ Error placing order for $symbol: $e');
              _analytics.logEvent(
                name: 'agentic_trading_order_error',
                parameters: {
                  'symbol': symbol,
                  'error': e.toString(),
                },
              );
            }
          } else {
            debugPrint('❌ Trade proposal rejected for $symbol');
          }

          // Delay between trades to avoid rate limiting
          await Future.delayed(const Duration(seconds: _tradeDelaySeconds));
        } catch (e) {
          debugPrint('❌ Error auto-trading $symbol: $e');
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

      return {
        'success': executedTrades.isNotEmpty,
        'tradesExecuted': executedTrades.length,
        'message': message,
        'trades': executedTrades,
      };
    } catch (e) {
      _isAutoTrading = false;
      _scheduleVisualStateReset();
      notifyListeners();
      debugPrint('❌ Error in auto-trade execution: $e');
      return {
        'success': false,
        'tradesExecuted': 0,
        'message': 'Error: $e',
        'trades': [],
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
  }) async {
    if (!_pendingOrders.contains(order)) {
      debugPrint('❌ Order not found in pending list');
      return;
    }

    final symbol = order['symbol'] as String;
    final action = order['action'] as String;
    final quantity = order['quantity'] as int;
    final price = order['price'] as double;
    final instrument = order['instrument'];

    try {
      final side = action.toLowerCase() == 'buy' ? 'buy' : 'sell';
      final isPaperMode = _config['paperTradingMode'] as bool? ?? false;

      debugPrint(
          '${isPaperMode ? '📝 PAPER' : '📤'} Approving order: $action $quantity shares of $symbol at \$$price');

      // Execute order
      final orderResponse = isPaperMode
          ? _simulatePaperOrder(action, symbol, quantity, price)
          : await brokerageService.placeInstrumentOrder(
              brokerageUser,
              account,
              instrument,
              symbol,
              side,
              price,
              quantity,
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
              (_config['enabledIndicators'] as Map<String, dynamic>? ?? {})
                  .entries
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
        notifyListeners();

        debugPrint('✅ Approved order executed for $symbol');
      } else {
        debugPrint(
            '❌ Approved order failed for $symbol: ${orderResponse.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error executing approved order for $symbol: $e');
    }
  }

  /// Rejects a pending order
  void rejectOrder(Map<String, dynamic> order) {
    if (_pendingOrders.contains(order)) {
      _pendingOrders.remove(order);
      notifyListeners();
      debugPrint('🚫 Order rejected: ${order['symbol']}');
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
    required List<dynamic> positions,
    required dynamic brokerageUser,
    required dynamic account,
    required dynamic brokerageService,
    required dynamic instrumentStore,
    DocumentReference? userDocRef,
  }) async {
    try {
      // Validate required parameters
      if (brokerageUser == null ||
          account == null ||
          brokerageService == null ||
          instrumentStore == null) {
        debugPrint(
            '❌ Missing required parameters for take profit/stop loss monitoring');
        return {
          'success': false,
          'exitsExecuted': 0,
          'message': 'Missing required parameters',
          'exits': [],
        };
      }

      // Get take profit and stop loss percentages from config
      final takeProfitPercent = _config['takeProfitPercent'] as double? ?? 10.0;
      final stopLossPercent = _config['stopLossPercent'] as double? ?? 5.0;

      // Get partial exit config
      final enablePartialExits =
          _config['enablePartialExits'] as bool? ?? false;
      final exitStages = (_config['exitStages'] as List<dynamic>?)
              ?.map((e) => ExitStage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];

      debugPrint(
          '📊 Monitoring ${positions.length} total positions, ${_automatedBuyTrades.length} automated buy trades for TP: $takeProfitPercent%, SL: $stopLossPercent%');
      if (_automatedBuyTrades.isNotEmpty) {
        final symbols = _automatedBuyTrades
            .map((t) => '${t['symbol']} x${t['quantity']}')
            .join(', ');
        debugPrint('📝 Automated buy trades: $symbols');
      }

      final executedExits = <Map<String, dynamic>>[];
      final tradesToRemove = <Map<String, dynamic>>[];

      // Check each automated buy trade
      for (final buyTrade in _automatedBuyTrades) {
        try {
          final symbol = buyTrade['symbol'] as String?;
          final buyQuantity = buyTrade['quantity'] as int?;
          final entryPrice = buyTrade['entryPrice'] as double?;
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
          dynamic position;
          try {
            position = positions.firstWhere((p) => p.symbol == symbol);
          } catch (e) {
            position = null;
          }

          if (position == null) {
            // Position no longer exists (might have been manually closed)
            debugPrint(
                '⚠️ Automated buy trade for $symbol not found in positions, removing from tracking');
            tradesToRemove.add(buyTrade);
            continue;
          }

          final currentPrice = position.quote?.lastTradePrice as double? ??
              position.quote?.lastExtendedHoursTradePrice as double?;

          if (currentPrice == null) {
            debugPrint(
                '⚠️ No current price available for $symbol, skipping TP/SL check');
            continue;
          }

          // Calculate profit/loss percentage based on automated trade entry price
          final profitLossPercent =
              ((currentPrice - entryPrice) / entryPrice) * 100;

          debugPrint(
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
              debugPrint(
                  '💰 $symbol hit take profit threshold: ${profitLossPercent.toStringAsFixed(2)}% >= $takeProfitPercent%');
            }
            // Check stop loss
            else if (profitLossPercent <= -stopLossPercent) {
              shouldExit = true;
              exitReason = 'Stop Loss ($stopLossPercent%)';
              debugPrint(
                  '🛑 $symbol hit stop loss threshold: ${profitLossPercent.toStringAsFixed(2)}% <= -$stopLossPercent%');
            }
          }

          // Trailing Stop Loss: exit if price drops by trailingStopPercent
          if (!shouldExit &&
              (_config['trailingStopEnabled'] as bool? ?? false)) {
            final trailPercent =
                _config['trailingStopPercent'] as double? ?? 3.0;
            final prevHighest =
                (buyTrade['highestPrice'] as double?) ?? entryPrice;
            final newHighest =
                currentPrice > prevHighest ? currentPrice : prevHighest;
            if (newHighest != prevHighest) {
              buyTrade['highestPrice'] = newHighest;
              debugPrint(
                  '🔼 $symbol new highest price since entry: $newHighest');
            }
            final trailStopPrice = newHighest * (1 - trailPercent / 100.0);
            if (currentPrice <= trailStopPrice && currentPrice > entryPrice) {
              shouldExit = true;
              exitReason = 'Trailing Stop ($trailPercent%)';
              quantityToSell = buyQuantity; // Sell remaining
              debugPrint(
                  '🟡 $symbol trailing stop triggered: current $currentPrice <= trail $trailStopPrice (highest $newHighest)');
            }
          }

          // Time-Based Exit
          if (!shouldExit &&
              (_config['timeBasedExitEnabled'] as bool? ?? false)) {
            final exitMinutes = _config['timeBasedExitMinutes'] as int? ?? 0;
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
                    debugPrint(
                        '⏱️ $symbol time-based exit triggered: ${duration.inMinutes} min >= $exitMinutes min');
                  }
                }
              }
            }
          }

          // Market Close Exit
          if (!shouldExit &&
              (_config['marketCloseExitEnabled'] as bool? ?? false)) {
            final exitMinutes = _config['marketCloseExitMinutes'] as int? ?? 15;
            final minutesUntilClose = MarketHours.minutesUntilMarketClose();
            if (minutesUntilClose != null &&
                minutesUntilClose <= exitMinutes &&
                minutesUntilClose > 0) {
              shouldExit = true;
              exitReason =
                  'Market Close Exit ($minutesUntilClose min remaining)';
              quantityToSell = buyQuantity;
              debugPrint(
                  '🌅 $symbol market close exit triggered: $minutesUntilClose min remaining <= $exitMinutes min');
            }
          }

          if (shouldExit) {
            // Get instrument data
            dynamic instrument;
            try {
              instrument = await brokerageService.getInstrumentBySymbol(
                brokerageUser,
                instrumentStore,
                symbol,
              );
              if (instrument == null) {
                debugPrint('⚠️ Could not find instrument for $symbol');
                continue;
              }
            } catch (e) {
              debugPrint('⚠️ Error fetching instrument for $symbol: $e');
              continue;
            }

            // Execute sell order for the automated buy quantity
            try {
              debugPrint(
                  '📤 Placing exit order: SELL $quantityToSell shares of $symbol at \$$currentPrice ($exitReason)');

              final orderResponse = await brokerageService.placeInstrumentOrder(
                brokerageUser,
                account,
                instrument,
                symbol,
                'sell',
                currentPrice,
                quantityToSell,
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
                    debugPrint(
                        '📝 Marked automated buy trade for removal: $symbol (all stages executed)');
                  } else {
                    debugPrint(
                        '📝 Updated automated buy trade: $symbol remaining ${buyTrade['quantity']}');
                    // Save updated list to Firestore immediately to persist partial state
                    if (userDocRef != null) {
                      await _saveAutomatedBuyTradesToFirestore(userDocRef);
                    }
                  }
                } else {
                  // Full exit (Stop Loss, Trailing Stop, or Legacy TP)
                  tradesToRemove.add(buyTrade);
                  debugPrint(
                      '📝 Marked automated buy trade for removal: $symbol x$buyQuantity after TP/SL exit');
                }

                // Send notification based on exit type
                final isTakeProfit = exitReason.contains('Take Profit');
                if (isTakeProfit &&
                    (_config['notifyOnTakeProfit'] as bool? ?? true)) {
                  _sendTradeNotification(
                    userDocRef,
                    'take_profit',
                    symbol: symbol,
                    quantity: quantityToSell,
                    price: currentPrice,
                    profitLoss: (currentPrice - entryPrice) * quantityToSell,
                  );
                } else if (!isTakeProfit &&
                    (_config['notifyOnStopLoss'] as bool? ?? true)) {
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

                debugPrint(
                    '✅ Exit order executed for $symbol: $exitReason, P/L: ${profitLossPercent.toStringAsFixed(2)}%');
              } else {
                debugPrint(
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
              debugPrint('❌ Error placing exit order for $symbol: $e');
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
          debugPrint('❌ Error processing position: $e');
        }
      }

      // Remove completed/closed trades from tracking (use removeWhere for efficiency)
      if (tradesToRemove.isNotEmpty) {
        _automatedBuyTrades
            .removeWhere((trade) => tradesToRemove.contains(trade));
        debugPrint(
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
      debugPrint('❌ Take profit/stop loss monitoring failed: $e');
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
      debugPrint('📲 Notification sent: $type for $symbol');
    } catch (e) {
      debugPrint('❌ Failed to send notification: $e');
      // Don't throw - notifications are non-critical
    }
  }
}
