import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AgenticTradingProvider with ChangeNotifier {
  /// Returns documentation for a given indicator key.
  /// Returns a Map with 'title' and 'documentation' keys.
  static Map<String, String> indicatorDocumentation(String key) {
    switch (key) {
      case 'priceMovement':
        return {
          'title': 'Price Movement',
          'documentation':
              'Analyzes recent price trends and chart patterns to identify bullish or bearish momentum. '
                  'Uses moving averages and price action to determine if the stock is in an uptrend (BUY), '
                  'downtrend (SELL), or sideways movement (HOLD).'
        };
      case 'momentum':
        return {
          'title': 'Momentum (RSI)',
          'documentation':
              'Relative Strength Index (RSI) measures the speed and magnitude of price changes. '
                  'Values above 70 indicate overbought conditions (potential SELL), while values below 30 '
                  'indicate oversold conditions (potential BUY). RSI between 30-70 suggests neutral momentum.'
        };
      case 'marketDirection':
        return {
          'title': 'Market Direction',
          'documentation':
              'Evaluates the overall market trend using moving averages on major indices (SPY/QQQ). '
                  'When the market index is trending up (fast MA > slow MA), stocks tend to perform better (BUY). '
                  'When the market is trending down, it suggests caution (SELL/HOLD).'
        };
      case 'volume':
        return {
          'title': 'Volume',
          'documentation':
              'Confirms price movements with trading volume. Strong price moves with high volume are more '
                  'reliable. BUY signals require increasing volume on up days, SELL signals require volume on down days. '
                  'Low volume suggests weak conviction and generates HOLD signals.'
        };
      case 'macd':
        return {
          'title': 'MACD',
          'documentation':
              'Moving Average Convergence Divergence (MACD) shows the relationship between two moving averages. '
                  'When the MACD line crosses above the signal line, it generates a BUY signal. When MACD crosses below the signal line, '
                  'it generates a SELL signal. The histogram shows the strength of the trend.'
        };
      case 'bollingerBands':
        return {
          'title': 'Bollinger Bands',
          'documentation':
              'Volatility indicator using standard deviations around a moving average. Price near the lower band '
                  'suggests oversold conditions (potential BUY), while price near the upper band suggests overbought (potential SELL). '
                  'Price in the middle suggests neutral conditions. Band width indicates volatility levels.'
        };
      case 'stochastic':
        return {
          'title': 'Stochastic',
          'documentation':
              'Stochastic Oscillator compares the closing price to its price range over a period. Values above 80 indicate '
                  'overbought conditions (potential SELL), below 20 indicates oversold (potential BUY). Crossovers of %K and %D '
                  'lines provide additional signals. Works best in ranging markets.'
        };
      case 'atr':
        return {
          'title': 'ATR (Volatility)',
          'documentation':
              'Average True Range (ATR) measures market volatility. High ATR indicates large price swings and increased risk. '
                  'Rising ATR suggests strong trending conditions, while falling ATR indicates consolidation. Used to set stop-loss '
                  'levels and position sizing based on current market conditions.'
        };
      case 'obv':
        return {
          'title': 'OBV (On-Balance Volume)',
          'documentation':
              'On-Balance Volume (OBV) tracks cumulative volume flow. Rising OBV confirms uptrends (BUY), falling OBV confirms '
                  'downtrends (SELL). Divergences between OBV and price can signal potential reversals. Volume precedes price, making '
                  'OBV a leading indicator for trend confirmation.'
        };
      default:
        return {
          'title': 'Technical Indicator',
          'documentation':
              'Technical indicator used to analyze market conditions and generate trading signals.'
        };
    }
  }

  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // Constants
  static const int _tradeDelaySeconds = 2; // Delay between auto-trades to avoid rate limiting

  bool _isAgenticTradingEnabled = false;
  Map<String, dynamic> _config = {};
  String _tradeProposalMessage = '';
  Map<String, dynamic>? _lastTradeProposal;
  Map<String, dynamic>? _lastAssessment;
  bool _isTradeInProgress = false;
  Map<String, dynamic>? _tradeSignal;
  List<Map<String, dynamic>> _tradeSignals = [];
  
  // Auto-trade state tracking
  bool _isAutoTrading = false;
  DateTime? _lastAutoTradeTime;
  int _dailyTradeCount = 0;
  DateTime? _dailyTradeCountResetDate;
  bool _emergencyStopActivated = false;
  List<Map<String, dynamic>> _autoTradeHistory = [];

  // Firestore listener for real-time trade signal updates
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _tradeSignalsSubscription;
  List<String>? _currentSymbols;
  int _currentLimit = 50;
  bool _hasReceivedServerData = false;
  String? _selectedInterval; // Will be auto-set based on market hours

  bool get isAgenticTradingEnabled => _isAgenticTradingEnabled;
  Map<String, dynamic> get config => _config;
  String get tradeProposalMessage => _tradeProposalMessage;
  Map<String, dynamic>? get lastTradeProposal => _lastTradeProposal;
  Map<String, dynamic>? get lastAssessment => _lastAssessment;
  bool get isTradeInProgress => _isTradeInProgress;
  Map<String, dynamic>? get tradeSignal => _tradeSignal;
  List<Map<String, dynamic>> get tradeSignals => _tradeSignals;
  String get selectedInterval {
    final interval = _selectedInterval ?? _getDefaultInterval();
    debugPrint(
        '🎯 selectedInterval getter called: $_selectedInterval (default: ${_getDefaultInterval()}) -> returning: $interval');
    return interval;
  }
  
  // Auto-trade getters
  bool get isAutoTrading => _isAutoTrading;
  DateTime? get lastAutoTradeTime => _lastAutoTradeTime;
  int get dailyTradeCount => _dailyTradeCount;
  bool get emergencyStopActivated => _emergencyStopActivated;
  List<Map<String, dynamic>> get autoTradeHistory => _autoTradeHistory;

  AgenticTradingProvider();

  // Get default interval based on market hours
  String _getDefaultInterval() {
    return _isMarketOpen() ? '1h' : '1d';
  }

  @override
  void dispose() {
    debugPrint('🧹 Disposing AgenticTradingProvider - cancelling subscription');
    _tradeSignalsSubscription?.cancel();
    super.dispose();
  }

  // Debug method to check subscription status
  bool get hasActiveSubscription => _tradeSignalsSubscription != null;

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

  Future<void> fetchTradeSignal(String symbol, {String? interval}) async {
    try {
      if (symbol.isEmpty) {
        _tradeSignal = null;
        notifyListeners();
        return;
      }

      // Ensure we always have a valid interval (default if none selected yet)
      final effectiveInterval =
          interval ?? _selectedInterval ?? _getDefaultInterval();
      final docId = effectiveInterval == '1d'
          ? 'signals_$symbol'
          : 'signals_${symbol}_$effectiveInterval';

      final doc = await FirebaseFirestore.instance
          .collection('agentic_trading')
          .doc(docId)
          .get(const GetOptions(source: Source.server));
      if (doc.exists && doc.data() != null) {
        _tradeSignal = doc.data();

        // Also update the signal in the _tradeSignals list
        final signalData = doc.data()!;
        final index = _tradeSignals.indexWhere((s) =>
            s['symbol'] == symbol &&
            (s['interval'] ?? '1d') == effectiveInterval);
        if (index != -1) {
          // Update existing signal in the list
          _tradeSignals[index] = signalData;
        } else {
          // Add new signal to the list
          _tradeSignals.insert(0, signalData);
        }
        // Re-sort by timestamp
        _tradeSignals.sort((a, b) {
          final aTimestamp = a['timestamp'] as int? ?? 0;
          final bTimestamp = b['timestamp'] as int? ?? 0;
          return bTimestamp.compareTo(aTimestamp);
        });
      } else {
        _tradeSignal = null;
        // Remove signal from list if it no longer exists
        _tradeSignals.removeWhere((s) =>
            s['symbol'] == symbol &&
            (s['interval'] ?? '1d') == effectiveInterval);
      }
      notifyListeners();
    } catch (e) {
      _tradeSignal = null;
      _tradeProposalMessage = 'Failed to fetch trade signal: ${e.toString()}';
      notifyListeners();
    }
  }

  // Debug method to test real-time updates by adding a test signal
  Future<void> fetchAllTradeSignals({
    String? signalType, // Filter by 'BUY', 'SELL', or 'HOLD'
    List<String>?
        indicators, // Filter by specific indicators from multiIndicatorResult.indicators
    DateTime? startDate, // Filter signals after this date
    DateTime? endDate, // Filter signals before this date
    List<String>?
        symbols, // Filter by specific symbols (max 30 due to Firestore 'whereIn' limit)
    int? limit, // Limit number of results (default: 50)
    String? interval, // Filter by interval (1d, 1h, 30m, 15m)
  }) async {
    // Cancel existing subscription and create a new one
    if (_tradeSignalsSubscription != null) {
      debugPrint('🛑 Cancelling existing trade signals subscription');
      _tradeSignalsSubscription!.cancel();
      _tradeSignalsSubscription = null;
    }

    // Reset server data flag when starting new subscription
    _hasReceivedServerData = false;

    // Store current filters for future reference
    _currentSymbols = symbols;
    _currentLimit = limit ?? 50;

    debugPrint('🚀 Setting up new trade signals subscription with filters:');
    debugPrint('   Signal type: $signalType');
    debugPrint('   Indicators: ${indicators?.join(", ") ?? "all"}');
    debugPrint('   Start date: $startDate');
    debugPrint('   End date: $endDate');
    debugPrint('   Symbols: ${symbols?.length ?? 0} symbols');
    debugPrint('   Limit: $_currentLimit');

    try {
      Query<Map<String, dynamic>> query =
          FirebaseFirestore.instance.collection('agentic_trading');

      // Apply interval filter - use provided interval or selected interval or default
      final effectiveInterval = interval ?? selectedInterval;

      // Apply signal type filter (top-level signal only if no indicators selected)
      if (signalType != null && signalType.isNotEmpty) {
        if (indicators == null || indicators.isEmpty) {
          // No indicators selected: filter by overall signal
          query = query.where('signal', isEqualTo: signalType);
        } else {
          // Indicators selected: filter by each indicator's signal server-side
          for (final indicator in indicators) {
            query = query.where(
                'multiIndicatorResult.indicators.$indicator.signal',
                isEqualTo: signalType);
          }
        }
      }

      // Apply interval filter (server-side when possible)
      query = query.where('interval', isEqualTo: effectiveInterval);

      // Use higher limit to ensure we get both interval and base signals
      // For '1d', use a much higher limit since we can't filter server-side
      // and need to fetch enough documents to find all matching signals
      // Client-side filtering will handle market hours logic
      final queryLimit = 200;

      debugPrint(
          '⏰ Query will fetch up to $queryLimit docs, client-side filter for market hours');

      // Apply date range filters
      if (startDate != null) {
        query = query.where('timestamp',
            isGreaterThanOrEqualTo: startDate.millisecondsSinceEpoch);
      }
      if (endDate != null) {
        query = query.where('timestamp',
            isLessThanOrEqualTo: endDate.millisecondsSinceEpoch);
      }

      // Apply symbols filter (Firestore whereIn limit is 30)
      if (symbols != null && symbols.isNotEmpty) {
        if (symbols.length <= 30) {
          query = query.where('symbol', whereIn: symbols);
        }
      }

      // Apply ordering and limit
      query = query.orderBy('timestamp', descending: true);
      query = query.limit(queryLimit);

      // Do an initial server fetch to ensure fresh data, then set up listener
      query
          .get(const GetOptions(source: Source.server))
          .then((initialSnapshot) {
        if (!_hasReceivedServerData) {
          debugPrint(
              '📥 Initial server fetch completed: ${initialSnapshot.docs.length} docs');
          _hasReceivedServerData = true;
          _updateTradeSignalsFromSnapshot(
              initialSnapshot, _currentSymbols, effectiveInterval);
        }
      }).catchError((e) {
        debugPrint('⚠️ Initial server fetch failed: $e');
      });

      // Set up real-time listener for ongoing updates
      _tradeSignalsSubscription = query.snapshots().listen(
        (snapshot) {
          final timestamp = DateTime.now().toString().substring(11, 23);
          debugPrint(
              '🔔 [$timestamp] Firestore snapshot received: ${snapshot.docs.length} documents');
          debugPrint(
              '🔍 [$timestamp] Snapshot metadata - fromCache: ${snapshot.metadata.isFromCache}, hasPendingWrites: ${snapshot.metadata.hasPendingWrites}');

          // Always process the first snapshot (even if from cache) after a delay,
          // but prefer server data if it arrives first
          if (!_hasReceivedServerData) {
            if (!snapshot.metadata.isFromCache) {
              // First server snapshot - use it immediately
              _hasReceivedServerData = true;
              debugPrint(
                  '📡 [$timestamp] First server snapshot - processing immediately');
            } else if (snapshot.metadata.hasPendingWrites) {
              // Has pending writes - process immediately
              debugPrint(
                  '📝 [$timestamp] Processing cached snapshot with pending writes');
            } else {
              // Cached snapshot - use it after waiting for server data
              Future.delayed(const Duration(milliseconds: 1000), () {
                if (!_hasReceivedServerData) {
                  debugPrint(
                      '⏱️ Using cached snapshot (server data didn\'t arrive within 1s)');
                  _hasReceivedServerData = true;
                  _updateTradeSignalsFromSnapshot(
                      snapshot, _currentSymbols, effectiveInterval);
                }
              });
              return;
            }
          }

          // Mark that we've received server data
          if (!snapshot.metadata.isFromCache) {
            _hasReceivedServerData = true;
            debugPrint('📡 [$timestamp] Received data from server');
          }

          debugPrint('📋 [$timestamp] Document IDs in snapshot:');
          for (var doc in snapshot.docs) {
            final data = doc.data();
            debugPrint(
                '   📄 ${doc.id}: signal=${data['signal']}, symbol=${data['symbol']}, timestamp=${data['timestamp']}');
          }

          final beforeCount = _tradeSignals.length;
          _updateTradeSignalsFromSnapshot(
              snapshot, _currentSymbols, effectiveInterval);
          final afterCount = _tradeSignals.length;

          debugPrint(
              '✅ [$timestamp] Processed $afterCount trade signals (was $beforeCount)');
          if (_tradeSignals.isNotEmpty) {
            debugPrint(
                '   Current signals: ${_tradeSignals.map((s) => s['symbol']).take(5).join(', ')}${_tradeSignals.length > 5 ? '...' : ''}');
          }
          debugPrint('📢 [$timestamp] Called notifyListeners()');
        },
        onError: (error) {
          debugPrint('❌ Firestore subscription error: $error');
          _tradeSignals = [];
          _tradeProposalMessage =
              'Failed to fetch trade signals: ${error.toString()}';
          notifyListeners();
        },
      );
    } catch (e) {
      _tradeSignals = [];
      _tradeProposalMessage = 'Failed to fetch trade signals: ${e.toString()}';
      notifyListeners();
    }
  }

  // Helper method to check if market is currently open (US Eastern Time)
  bool _isMarketOpen() {
    final now = DateTime.now().toUtc();

    // Determine if we're in EDT (summer) or EST (winter)
    // DST in US: Second Sunday in March to First Sunday in November
    final year = now.year;
    final isDST = _isDaylightSavingTime(now, year);
    final offset = isDST ? 4 : 5; // EDT is UTC-4, EST is UTC-5

    final etTime = now.subtract(Duration(hours: offset));

    debugPrint('🕐 Market hours check:');
    debugPrint('   UTC time: $now');
    debugPrint('   DST active: $isDST (offset: -$offset hours)');
    debugPrint('   ET time: $etTime');
    debugPrint('   Day of week: ${etTime.weekday} (${[
      '',
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun'
    ][etTime.weekday]})');

    // Market is closed on weekends
    if (etTime.weekday == DateTime.saturday ||
        etTime.weekday == DateTime.sunday) {
      debugPrint('   ❌ Weekend - market closed');
      return false;
    }

    // Market hours: 9:30 AM - 4:00 PM ET
    // Create times in UTC to match etTime (which is also UTC)
    final marketOpen =
        DateTime.utc(etTime.year, etTime.month, etTime.day, 9, 30);
    final marketClose =
        DateTime.utc(etTime.year, etTime.month, etTime.day, 16, 0);

    final isOpen = etTime.isAfter(marketOpen) && etTime.isBefore(marketClose);
    debugPrint('   Market open: $marketOpen');
    debugPrint('   Market close: $marketClose');
    debugPrint(
        '   Current ET: ${etTime.hour}:${etTime.minute.toString().padLeft(2, '0')}');
    debugPrint(
        '   isAfter(open)=${etTime.isAfter(marketOpen)}, isBefore(close)=${etTime.isBefore(marketClose)}');
    debugPrint('   ${isOpen ? "✅ MARKET OPEN" : "❌ MARKET CLOSED"}');

    return isOpen;
  }

  // Helper to determine if a given UTC time falls within Daylight Saving Time
  bool _isDaylightSavingTime(DateTime utcTime, int year) {
    // DST starts: Second Sunday in March at 2:00 AM local time (7:00 AM UTC during EST)
    // DST ends: First Sunday in November at 2:00 AM local time (6:00 AM UTC during EDT)

    // Find second Sunday in March
    DateTime marchFirst = DateTime.utc(year, 3, 1);
    // Calculate days to first Sunday
    int daysToFirstSunday = (DateTime.sunday - marchFirst.weekday) % 7;
    // Second Sunday is 7 days after first Sunday
    DateTime secondSundayMarch =
        DateTime.utc(year, 3, 1 + daysToFirstSunday + 7, 7); // 7 AM UTC

    // Find first Sunday in November
    DateTime novemberFirst = DateTime.utc(year, 11, 1);
    int daysToFirstSundayNov = (DateTime.sunday - novemberFirst.weekday) % 7;
    DateTime firstSundayNovember =
        DateTime.utc(year, 11, 1 + daysToFirstSundayNov, 6); // 6 AM UTC

    debugPrint('   DST period: $secondSundayMarch to $firstSundayNovember');
    debugPrint('   Current UTC: $utcTime');

    return utcTime.isAfter(secondSundayMarch) &&
        utcTime.isBefore(firstSundayNovember);
  }

  // Public getter for market status
  bool get isMarketOpen => _isMarketOpen();

  // Helper method to process snapshot data
  void _updateTradeSignalsFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    List<String>? symbols,
    String effectiveInterval,
  ) {
    final isMarketOpen = _isMarketOpen();

    debugPrint('📊 Processing ${snapshot.docs.length} documents');
    debugPrint('   Market status: ${isMarketOpen ? "OPEN" : "CLOSED"}');
    debugPrint('   Selected interval: $effectiveInterval');

    // Filter by the selected interval (respect user's choice)
    _tradeSignals = snapshot.docs
        .where((doc) {
          final data = doc.data();
          final interval = data['interval'] as String?;

          // Match the selected interval
          // For '1d', include both null (legacy signals) and '1d'
          final include = effectiveInterval == '1d'
              ? (interval == null || interval == '1d')
              : (interval == effectiveInterval);

          if (include) {
            debugPrint(
                '   ✅ ${doc.id}: interval=$interval matches selected $effectiveInterval');
          }
          return include;
        })
        .map((doc) {
          final data = doc.data();
          // Ensure data has required fields
          if (data.containsKey('timestamp')) {
            return data;
          }
          return null;
        })
        .where((data) => data != null)
        .cast<Map<String, dynamic>>()
        .toList();

    // Client-side filtering for symbols if list > 30 (Firestore limit)
    if (symbols != null && symbols.isNotEmpty && symbols.length > 30) {
      _tradeSignals = _tradeSignals
          .where((signal) => symbols.contains(signal['symbol']))
          .toList();
    }

    notifyListeners();
  }

  void setSelectedInterval(String interval) {
    _selectedInterval = interval;
    notifyListeners();
  }

  Future<void> initiateTradeProposal({
    required String symbol,
    required double currentPrice,
    required Map<String, dynamic> portfolioState,
    String? interval,
  }) async {
    _isTradeInProgress = true;
    _tradeProposalMessage = 'Initiating trade proposal...';
    notifyListeners();

    final effectiveInterval = interval ?? selectedInterval;
    final payload = {
      'symbol': symbol,
      'currentPrice': currentPrice,
      'portfolioState': portfolioState,
      'interval': effectiveInterval,
      'smaPeriodFast': _config['smaPeriodFast'],
      'smaPeriodSlow': _config['smaPeriodSlow'],
      'tradeQuantity': _config['tradeQuantity'],
      'maxPositionSize': _config['maxPositionSize'],
      'maxPortfolioConcentration': _config['maxPortfolioConcentration'],
    };

    try {
      final result =
          await _functions.httpsCallable('initiateTradeProposal').call(payload);
      final data = result.data as Map<String, dynamic>?;
      if (data == null) throw Exception('Empty response from function');

      final status = data['status'] as String? ?? 'error';
      final reason = data['reason']?.toString();
      final intervalLabel = effectiveInterval == '1d'
          ? 'Daily'
          : effectiveInterval == '1h'
              ? 'Hourly'
              : effectiveInterval == '30m'
                  ? '30-min'
                  : effectiveInterval == '15m'
                      ? '15-min'
                      : effectiveInterval;
      if (status == 'approved') {
        final proposal =
            Map<String, dynamic>.from(data['proposal'] as Map? ?? {});
        _lastTradeProposal = proposal;
        final assessment =
            Map<String, dynamic>.from(data['assessment'] as Map? ?? {});
        _lastAssessment = assessment;
        final reasonMsg =
            (reason != null && reason.isNotEmpty) ? '\n$reason' : '';
        _tradeProposalMessage =
            'Trade proposal approved for $symbol ($intervalLabel).\n${proposal['action']} ${proposal['quantity']} of ${proposal['symbol']}$reasonMsg';
        _analytics.logEvent(
            name: 'agentic_trading_trade_approved',
            parameters: {'interval': effectiveInterval});
      } else {
        _lastTradeProposal = null;
        _lastAssessment = null;
        final message = data['message']?.toString() ?? 'Rejected by agent';
        final reasonMsg =
            (reason != null && reason.isNotEmpty) ? '\n$reason' : '';
        _tradeProposalMessage =
            'Trade proposal rejected for $symbol ($intervalLabel).\n$message\n$reasonMsg';
        _analytics.logEvent(
            name: 'agentic_trading_trade_rejected',
            parameters: {
              'reason': reason ?? message,
              'interval': effectiveInterval
            });
      }
    } catch (e) {
      // Fallback to local simulation if function call fails
      _tradeProposalMessage =
          'Function call failed, falling back to local simulation: ${e.toString()}';
      // Local simulation
      await Future.delayed(const Duration(seconds: 1));
      final simulatedTradeProposal = {
        'symbol': symbol,
        'action': 'BUY',
        'quantity': _config['tradeQuantity'],
        'price': currentPrice,
      };
      _lastTradeProposal = Map<String, dynamic>.from(simulatedTradeProposal);
      _tradeProposalMessage =
          'Trade proposal (simulated): ${_lastTradeProposal!['action']} ${_lastTradeProposal!['quantity']} of ${_lastTradeProposal!['symbol']}';
      _analytics.logEvent(
          name: 'agentic_trading_trade_approved_simulated',
          parameters: {'error': e.toString()});
    }

    _isTradeInProgress = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> assessTradeRisk({
    required Map<String, dynamic> proposal,
    required Map<String, dynamic> portfolioState,
  }) async {
    try {
      final result = await _functions.httpsCallable('riskguardTask').call({
        'proposal': proposal,
        'portfolioState': portfolioState,
        'config': _config,
      });
      notifyListeners();
      if (result.data is Map<String, dynamic>) {
        return Map<String, dynamic>.from(result.data);
      } else {
        return {'approved': false, 'reason': 'Unexpected response format'};
      }
    } catch (e) {
      return {'approved': false, 'reason': 'Error: ${e.toString()}'};
    }
  }

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
    if (!_isMarketOpen()) {
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
        debugPrint(
            '⏰ Cooldown active: $remainingMinutes minutes remaining');
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
    required Map<String, dynamic> portfolioState,
    required dynamic brokerageUser,
    required dynamic account,
    required dynamic brokerageService,
    required dynamic instrumentStore,
  }) async {
    _isAutoTrading = true;
    notifyListeners();

    try {
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

      // Get current signals - filter for BUY signals only
      final buySignals = _tradeSignals.where((signal) {
        final signalType = signal['signal'] as String?;
        return signalType == 'BUY';
      }).toList();

      if (buySignals.isEmpty) {
        debugPrint('📭 No BUY signals available for auto-trade');
        _isAutoTrading = false;
        notifyListeners();
        return {
          'success': false,
          'tradesExecuted': 0,
          'message': 'No BUY signals available',
          'trades': [],
        };
      }

      debugPrint('🎯 Found ${buySignals.length} BUY signals for auto-trade');

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

          // Initiate trade proposal
          await initiateTradeProposal(
            symbol: symbol,
            currentPrice: currentPrice,
            portfolioState: portfolioState,
            interval: signal['interval'] as String?,
          );

          // If proposal was approved, execute the order
          if (_lastTradeProposal != null) {
            final action = _lastTradeProposal!['action'] as String?;
            final quantity = _lastTradeProposal!['quantity'] as int?;
            
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
                debugPrint('⚠️ Could not find instrument for $symbol, skipping');
                continue;
              }
            } catch (e) {
              debugPrint('⚠️ Error fetching instrument for $symbol: $e');
              continue;
            }

            // Execute the order through brokerage service
            try {
              debugPrint('📤 Placing order: $action $quantity shares of $symbol at \$$currentPrice');
              
              final orderResponse = await brokerageService.placeInstrumentOrder(
                brokerageUser,
                account,
                instrument,
                symbol,
                action.toLowerCase(), // 'buy' or 'sell'
                currentPrice,
                quantity,
              );

              // Check if order was successful
              if (orderResponse.statusCode == 200 || orderResponse.statusCode == 201) {
                final tradeRecord = {
                  'timestamp': DateTime.now().toIso8601String(),
                  'symbol': symbol,
                  'action': action,
                  'quantity': quantity,
                  'price': currentPrice,
                  'proposal': Map<String, dynamic>.from(_lastTradeProposal!),
                  'assessment': _lastAssessment != null
                      ? Map<String, dynamic>.from(_lastAssessment!)
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

                _analytics.logEvent(
                  name: 'agentic_trading_auto_executed',
                  parameters: {
                    'symbol': symbol,
                    'daily_count': _dailyTradeCount,
                    'action': action,
                    'quantity': quantity,
                  },
                );

                debugPrint('✅ Order executed for $symbol: $action $quantity shares at \$$currentPrice ($_dailyTradeCount/$dailyLimit today)');
              } else {
                debugPrint('❌ Order failed for $symbol: ${orderResponse.statusCode} - ${orderResponse.body}');
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
}
