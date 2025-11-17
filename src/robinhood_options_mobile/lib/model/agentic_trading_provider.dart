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
  String _selectedInterval = '1d'; // Default to daily signals

  bool get isAgenticTradingEnabled => _isAgenticTradingEnabled;
  Map<String, dynamic> get config => _config;
  String get tradeProposalMessage => _tradeProposalMessage;
  Map<String, dynamic>? get lastTradeProposal => _lastTradeProposal;
  Map<String, dynamic>? get lastAssessment => _lastAssessment;
  bool get isTradeInProgress => _isTradeInProgress;
  Map<String, dynamic>? get tradeSignal => _tradeSignal;
  List<Map<String, dynamic>> get tradeSignals => _tradeSignals;
  String get selectedInterval => _selectedInterval;

  AgenticTradingProvider() {
    _loadConfig();
  }

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

  Future<void> fetchAllTradeSignals({
    String? signalType,        // Filter by 'BUY', 'SELL', or 'HOLD'
    DateTime? startDate,       // Filter signals after this date
    DateTime? endDate,         // Filter signals before this date
    List<String>? symbols,     // Filter by specific symbols (max 30 due to Firestore 'whereIn' limit)
    int? limit,                // Limit number of results (default: 50)
    String? interval,          // Filter by interval (1d, 1h, 30m, 15m)
  }) async {
    try {
      Query<Map<String, dynamic>> query =
          FirebaseFirestore.instance.collection('agentic_trading');

      // Apply interval filter
      final effectiveInterval = interval ?? _selectedInterval;
      
      // Apply signal type filter
      if (signalType != null && signalType.isNotEmpty) {
        query = query.where('signal', isEqualTo: signalType);
      }

      // Apply interval filter
      if (effectiveInterval != 'all') {
        query = query.where('interval', isEqualTo: effectiveInterval);
      }

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
      if (limit != null && limit > 0) {
        query = query.limit(limit);
      } else {
        query = query.limit(50); // Default limit
      }

      final snapshot = await query.get();
      
      _tradeSignals = snapshot.docs
          .where((doc) => doc.id.startsWith('signals_'))
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
    } catch (e) {
      _tradeSignals = [];
      _tradeProposalMessage = 'Failed to fetch trade signals: ${e.toString()}';
      notifyListeners();
    }
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

    final effectiveInterval = interval ?? _selectedInterval;
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
