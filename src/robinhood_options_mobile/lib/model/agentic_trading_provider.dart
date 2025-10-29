import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class AgenticTradingProvider with ChangeNotifier {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  bool _isAgenticTradingEnabled = false;
  Map<String, dynamic> _config = {};
  String _tradeProposalMessage = '';
  Map<String, dynamic>? _lastTradeProposal;
  bool _isTradeInProgress = false;

  bool get isAgenticTradingEnabled => _isAgenticTradingEnabled;
  Map<String, dynamic> get config => _config;
  String get tradeProposalMessage => _tradeProposalMessage;
  Map<String, dynamic>? get lastTradeProposal => _lastTradeProposal;
  bool get isTradeInProgress => _isTradeInProgress;

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
        final trade = Map<String, dynamic>.from(data['trade'] as Map? ?? {});
        _lastTradeProposal = trade;
        final reasonMsg =
            (reason != null && reason.isNotEmpty) ? '\n$reason' : '';
        _tradeProposalMessage =
            'Trade proposal approved for $symbol.\n${trade['action']} ${trade['quantity']} of ${trade['symbol']}$reasonMsg';
        _analytics.logEvent(name: 'agentic_trading_trade_approved');
      } else {
        _lastTradeProposal = null;
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
}
