import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AgenticTradingProvider with ChangeNotifier {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  bool _isAgenticTradingEnabled = false;
  Map<String, dynamic> _config = {};
  String _tradeProposalMessage = '';
  Map<String, dynamic>? _lastTradeProposal;
  Map<String, dynamic>? _lastAssessment;
  bool _isTradeInProgress = false;
  Map<String, dynamic>? _tradeSignal;
  List<Map<String, dynamic>> _tradeSignals = [];
  
  // Firestore listener for real-time trade signal updates
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _tradeSignalsSubscription;
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
    debugPrint('🎯 selectedInterval getter called: $_selectedInterval (default: ${_getDefaultInterval()}) -> returning: $interval');
    return interval;
  }

  AgenticTradingProvider() {
    _loadConfig();
  }

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
    _analytics.logEvent(
      name: 'agentic_trading_toggled',
      parameters: {'enabled': _isAgenticTradingEnabled.toString()},
    );
    notifyListeners();
  }

  Future<void> _loadConfig() async {
    try {
      final result =
          await _functions.httpsCallable('getAgenticTradingConfig').call();
      final data = result.data;
      if (data != null && data['config'] != null) {
        _config = Map<String, dynamic>.from(data['config']);
      } else if (data != null &&
          data is Map &&
          data.containsKey('smaPeriodFast')) {
        // support older shape where config fields are at top level
        _config = Map<String, dynamic>.from(data);
      } else {
        // fallback defaults
        _config = {
          'smaPeriodFast': 10,
          'smaPeriodSlow': 30,
          'tradeQuantity': 1,
          'maxPositionSize': 100,
          'maxPortfolioConcentration': 0.5,
          'rsiPeriod': 14,
          'marketIndexSymbol': 'SPY',
        };
      }
      _analytics.logEvent(name: 'agentic_trading_config_loaded');
    } catch (e) {
      // If functions are not available or call fails, fallback to local defaults
      _config = {
        'smaPeriodFast': 10,
        'smaPeriodSlow': 30,
        'tradeQuantity': 1,
        'maxPositionSize': 100,
        'maxPortfolioConcentration': 0.5,
        'rsiPeriod': 14,
        'marketIndexSymbol': 'SPY',
      };
      _tradeProposalMessage = 'Loaded local defaults (functions unavailable)';
      _analytics.logEvent(
        name: 'agentic_trading_config_loaded_local_fallback',
        parameters: {'error': e.toString()},
      );
    }
    notifyListeners();
  }

  Future<void> updateConfig(Map<String, dynamic> newConfig) async {
    _config = newConfig;
    try {
      // Optionally persist to backend in future via HTTPS Callable
      await _functions.httpsCallable('setAgenticTradingConfig').call(_config);
      _analytics.logEvent(name: 'agentic_trading_config_updated_remote');
    } catch (_) {
      // If backend not available, keep local and log
      _analytics.logEvent(name: 'agentic_trading_config_updated_local');
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
      
      final effectiveInterval = interval ?? _selectedInterval;
      final docId = effectiveInterval == '1d' 
          ? 'signals_$symbol' 
          : 'signals_${symbol}_$effectiveInterval';
      
      final doc = await FirebaseFirestore.instance
          .collection('agentic_trading')
          .doc(docId)
          .get();
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
    String? signalType,        // Filter by 'BUY', 'SELL', or 'HOLD'
    DateTime? startDate,       // Filter signals after this date
    DateTime? endDate,         // Filter signals before this date
    List<String>? symbols,     // Filter by specific symbols (max 30 due to Firestore 'whereIn' limit)
    int? limit,                // Limit number of results (default: 50)
    String? interval,          // Filter by interval (1d, 1h, 30m, 15m)
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
    debugPrint('   Start date: $startDate');
    debugPrint('   End date: $endDate');
    debugPrint('   Symbols: ${symbols?.length ?? 0} symbols');
    debugPrint('   Limit: $_currentLimit');

    try {
      Query<Map<String, dynamic>> query =
          FirebaseFirestore.instance.collection('agentic_trading');

      // Apply interval filter - use provided interval or selected interval or default
      final effectiveInterval = interval ?? selectedInterval;
      
      // Apply signal type filter
      if (signalType != null && signalType.isNotEmpty) {
        query = query.where('signal', isEqualTo: signalType);
      }

      // Apply interval filter (server-side when possible)
      // Note: Only filter server-side for intraday signals to maintain backward
      // compatibility with legacy daily signals that lack the interval field
      if (effectiveInterval != 'all' && effectiveInterval != '1d') {
        query = query.where('interval', isEqualTo: effectiveInterval);
      }
      
      // Use higher limit to ensure we get both interval and base signals
      // Client-side filtering will handle market hours logic
      final queryLimit = 200;
      
      debugPrint('⏰ Query will fetch up to $queryLimit docs, client-side filter for market hours');
      
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
      query.get(const GetOptions(source: Source.server)).then((initialSnapshot) {
        if (!_hasReceivedServerData) {
          debugPrint('📥 Initial server fetch completed: ${initialSnapshot.docs.length} docs');
          _hasReceivedServerData = true;
          _updateTradeSignalsFromSnapshot(initialSnapshot, _currentSymbols, effectiveInterval);
        }
      }).catchError((e) {
        debugPrint('⚠️ Initial server fetch failed: $e');
      });

      // Set up real-time listener for ongoing updates
      _tradeSignalsSubscription = query.snapshots().listen(
        (snapshot) {
          final timestamp = DateTime.now().toString().substring(11, 23);
          debugPrint('🔔 [$timestamp] Firestore snapshot received: ${snapshot.docs.length} documents');
          debugPrint('🔍 [$timestamp] Snapshot metadata - fromCache: ${snapshot.metadata.isFromCache}, hasPendingWrites: ${snapshot.metadata.hasPendingWrites}');
          
          // Always process the first snapshot (even if from cache) after a delay,
          // but prefer server data if it arrives first
          if (!_hasReceivedServerData) {
            if (!snapshot.metadata.isFromCache) {
              // First server snapshot - use it immediately
              _hasReceivedServerData = true;
              debugPrint('📡 [$timestamp] First server snapshot - processing immediately');
            } else if (snapshot.metadata.hasPendingWrites) {
              // Has pending writes - process immediately  
              debugPrint('📝 [$timestamp] Processing cached snapshot with pending writes');
            } else {
              // Cached snapshot - use it after waiting for server data
              Future.delayed(const Duration(milliseconds: 1000), () {
                if (!_hasReceivedServerData) {
                  debugPrint('⏱️ Using cached snapshot (server data didn\'t arrive within 1s)');
                  _hasReceivedServerData = true;
                  _updateTradeSignalsFromSnapshot(snapshot, _currentSymbols, effectiveInterval);
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
          snapshot.docs.forEach((doc) {
            final data = doc.data();
            debugPrint('   📄 ${doc.id}: signal=${data['signal']}, symbol=${data['symbol']}, timestamp=${data['timestamp']}');
          });

          final beforeCount = _tradeSignals.length;
          _updateTradeSignalsFromSnapshot(snapshot, _currentSymbols, effectiveInterval);
          final afterCount = _tradeSignals.length;
          
          debugPrint('✅ [$timestamp] Processed ${afterCount} trade signals (was ${beforeCount})');
          if (_tradeSignals.isNotEmpty) {
            debugPrint('   Current signals: ${_tradeSignals.map((s) => s['symbol']).take(5).join(', ')}${_tradeSignals.length > 5 ? '...' : ''}');
          }
          debugPrint('📢 [$timestamp] Called notifyListeners()');
        },
        onError: (error) {
          debugPrint('❌ Firestore subscription error: $error');
          _tradeSignals = [];
          _tradeProposalMessage = 'Failed to fetch trade signals: ${error.toString()}';
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
    debugPrint('   Day of week: ${etTime.weekday} (${['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][etTime.weekday]})');
    
    // Market is closed on weekends
    if (etTime.weekday == DateTime.saturday || etTime.weekday == DateTime.sunday) {
      debugPrint('   ❌ Weekend - market closed');
      return false;
    }
    
    // Market hours: 9:30 AM - 4:00 PM ET
    // Create times in UTC to match etTime (which is also UTC)
    final marketOpen = DateTime.utc(etTime.year, etTime.month, etTime.day, 9, 30);
    final marketClose = DateTime.utc(etTime.year, etTime.month, etTime.day, 16, 0);
    
    final isOpen = etTime.isAfter(marketOpen) && etTime.isBefore(marketClose);
    debugPrint('   Market open: $marketOpen');
    debugPrint('   Market close: $marketClose');
    debugPrint('   Current ET: ${etTime.hour}:${etTime.minute.toString().padLeft(2, '0')}');
    debugPrint('   isAfter(open)=${etTime.isAfter(marketOpen)}, isBefore(close)=${etTime.isBefore(marketClose)}');
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
    DateTime secondSundayMarch = DateTime.utc(year, 3, 1 + daysToFirstSunday + 7, 7); // 7 AM UTC
    
    // Find first Sunday in November
    DateTime novemberFirst = DateTime.utc(year, 11, 1);
    int daysToFirstSundayNov = (DateTime.sunday - novemberFirst.weekday) % 7;
    DateTime firstSundayNovember = DateTime.utc(year, 11, 1 + daysToFirstSundayNov, 6); // 6 AM UTC
    
    debugPrint('   DST period: $secondSundayMarch to $firstSundayNovember');
    debugPrint('   Current UTC: $utcTime');
    
    return utcTime.isAfter(secondSundayMarch) && utcTime.isBefore(firstSundayNovember);
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
            debugPrint('   ✅ ${doc.id}: interval=$interval matches selected $effectiveInterval');
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

    // Client-side interval filtering for '1d' (handles legacy signals without interval field)
    if (effectiveInterval == '1d') {
      _tradeSignals = _tradeSignals.where((signal) {
        final signalInterval = signal['interval'] ?? '1d';
        return signalInterval == '1d';
      }).toList();
    }

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
      final intervalLabel = effectiveInterval == '1d' ? 'Daily' :
                           effectiveInterval == '1h' ? 'Hourly' :
                           effectiveInterval == '30m' ? '30-min' :
                           effectiveInterval == '15m' ? '15-min' : effectiveInterval;
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
        _analytics.logEvent(name: 'agentic_trading_trade_approved',
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
            parameters: {'reason': reason ?? message, 'interval': effectiveInterval});
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
}
