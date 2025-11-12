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

  bool get isAgenticTradingEnabled => _isAgenticTradingEnabled;
  Map<String, dynamic> get config => _config;
  String get tradeProposalMessage => _tradeProposalMessage;
  Map<String, dynamic>? get lastTradeProposal => _lastTradeProposal;
  Map<String, dynamic>? get lastAssessment => _lastAssessment;
  bool get isTradeInProgress => _isTradeInProgress;
  Map<String, dynamic>? get tradeSignal => _tradeSignal;
  List<Map<String, dynamic>> get tradeSignals => _tradeSignals;

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

  Future<void> fetchTradeSignal(String symbol) async {
    try {
      if (symbol.isEmpty) {
        _tradeSignal = null;
        notifyListeners();
        return;
      }
      final doc = await FirebaseFirestore.instance
          .collection('agentic_trading')
          .doc('signals_$symbol')
          .get();
      if (doc.exists && doc.data() != null) {
        _tradeSignal = doc.data();
      } else {
        _tradeSignal = null;
      }
      notifyListeners();
    } catch (e) {
      _tradeSignal = null;
      _tradeProposalMessage = 'Failed to fetch trade signal: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<void> fetchAllTradeSignals() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('agentic_trading').get();
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
      _tradeSignals.sort((a, b) {
        final aTimestamp = a['timestamp'] as int? ?? 0;
        final bTimestamp = b['timestamp'] as int? ?? 0;
        return bTimestamp.compareTo(aTimestamp);
      });
      notifyListeners();
    } catch (e) {
      _tradeSignals = [];
      _tradeProposalMessage = 'Failed to fetch trade signals: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<void> initiateTradeProposal({
    required String symbol,
    required double currentPrice,
    required Map<String, dynamic> portfolioState,
  }) async {
    _isTradeInProgress = true;
    _tradeProposalMessage = 'Initiating trade proposal...';
    notifyListeners();

    final payload = {
      'symbol': symbol,
      'currentPrice': currentPrice,
      'portfolioState': portfolioState,
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
      if (status == 'approved') {
        final trade = Map<String, dynamic>.from(data['proposal'] as Map? ?? {});
        _lastTradeProposal = trade;
        final assessment =
            Map<String, dynamic>.from(data['assessment'] as Map? ?? {});
        _lastAssessment = assessment;
        final reasonMsg =
            (reason != null && reason.isNotEmpty) ? '\n$reason' : '';
        _tradeProposalMessage =
            'Trade proposal approved for $symbol.\n${trade['action']} ${trade['quantity']} of ${trade['symbol']}$reasonMsg';
        _analytics.logEvent(name: 'agentic_trading_trade_approved');
      } else {
        _lastTradeProposal = null;
        _lastAssessment = null;
        final message = data['message']?.toString() ?? 'Rejected by agent';
        final reasonMsg =
            (reason != null && reason.isNotEmpty) ? '\n$reason' : '';
        _tradeProposalMessage =
            'Trade proposal rejected for $symbol.\n$message\n$reasonMsg';
        _analytics.logEvent(
            name: 'agentic_trading_trade_rejected',
            parameters: {'reason': reason ?? message});
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
