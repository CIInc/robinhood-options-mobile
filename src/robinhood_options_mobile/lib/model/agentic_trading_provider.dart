import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:robinhood_options_mobile/utils/market_hours.dart';

class AgenticTradingProvider with ChangeNotifier {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // Constants
  static const int _tradeDelaySeconds =
      2; // Delay between auto-trades to avoid rate limiting

  bool _isAgenticTradingEnabled = false;
  Map<String, dynamic> _config = {};

  // Auto-trade state tracking
  bool _isAutoTrading = false;
  DateTime? _lastAutoTradeTime;
  int _dailyTradeCount = 0;
  DateTime? _dailyTradeCountResetDate;
  bool _emergencyStopActivated = false;
  List<Map<String, dynamic>> _autoTradeHistory = [];
  // Track automated BUY trades for TP/SL monitoring (with quantity and entry price)
  // Each entry: {symbol, quantity, entryPrice, timestamp}
  List<Map<String, dynamic>> _automatedBuyTrades = [];

  // Auto-trade timer countdown
  DateTime? _nextAutoTradeTime;
  int _autoTradeCountdownSeconds = 0;

  // Last auto-trade execution result
  Map<String, dynamic>? _lastAutoTradeResult;

  bool get isAgenticTradingEnabled => _isAgenticTradingEnabled;
  Map<String, dynamic> get config => _config;

  // Auto-trade getters
  bool get isAutoTrading => _isAutoTrading;
  DateTime? get lastAutoTradeTime => _lastAutoTradeTime;
  int get dailyTradeCount => _dailyTradeCount;
  bool get emergencyStopActivated => _emergencyStopActivated;
  List<Map<String, dynamic>> get autoTradeHistory => _autoTradeHistory;
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
    super.dispose();
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
  bool get isMarketOpen => MarketHours.isMarketOpen();

  /// Activates emergency stop to halt all auto-trading
  void activateEmergencyStop() {
    _emergencyStopActivated = true;
    _analytics.logEvent(
      name: 'agentic_trading_emergency_stop',
      parameters: {'reason': 'manual_activation'},
    );
    notifyListeners();
  }

  /// Deactivates emergency stop to resume auto-trading
  void deactivateEmergencyStop() {
    _emergencyStopActivated = false;
    _analytics.logEvent(name: 'agentic_trading_emergency_stop_deactivated');
    notifyListeners();
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

    // Check if market is open
    if (!MarketHours.isMarketOpen()) {
      debugPrint('🏦 Market is closed');
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
    notifyListeners();

    try {
      // Validate required parameters
      if (brokerageUser == null ||
          account == null ||
          brokerageService == null ||
          instrumentStore == null) {
        debugPrint('❌ Missing required parameters for auto-trade');
        _isAutoTrading = false;
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

              debugPrint(
                  '📤 Placing order: $action $quantity shares of $symbol at \$$currentPrice');

              final orderResponse = await brokerageService.placeInstrumentOrder(
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
                    'entryPrice': currentPrice,
                    'timestamp': DateTime.now().toIso8601String(),
                  });
                  debugPrint(
                      '📝 Added automated BUY trade: $symbol x$quantity @ \$$currentPrice for TP/SL tracking');

                  // Save to Firestore
                  await _saveAutomatedBuyTradesToFirestore(userDocRef);
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
      notifyListeners();

      _analytics.logEvent(
        name: 'agentic_trading_auto_failed',
        parameters: {'error': e.toString()},
      );

      return {
        'success': false,
        'tradesExecuted': 0,
        'message': 'Auto-trade failed: ${e.toString()}',
        'trades': [],
      };
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
                  '📤 Placing exit order: SELL $buyQuantity shares of $symbol at \$$currentPrice ($exitReason)');

              final orderResponse = await brokerageService.placeInstrumentOrder(
                brokerageUser,
                account,
                instrument,
                symbol,
                'sell',
                currentPrice,
                buyQuantity,
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
                  'quantity': buyQuantity,
                  'entryPrice': entryPrice,
                  'exitPrice': currentPrice,
                  'profitLossPercent': profitLossPercent,
                  'reason': exitReason,
                  'orderResponse': orderResponse.body,
                };

                executedExits.add(exitRecord);
                _autoTradeHistory.insert(0, exitRecord);

                // Keep only last 100 trades in history
                if (_autoTradeHistory.length > 100) {
                  _autoTradeHistory.removeRange(100, _autoTradeHistory.length);
                }

                // Mark this automated buy trade for removal
                tradesToRemove.add(buyTrade);
                debugPrint(
                    '📝 Marked automated buy trade for removal: $symbol x$buyQuantity after TP/SL exit');

                _analytics.logEvent(
                  name: 'agentic_trading_exit_executed',
                  parameters: {
                    'symbol': symbol,
                    'reason': exitReason,
                    'profit_loss_percent': profitLossPercent,
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
}
