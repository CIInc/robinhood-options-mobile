import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:robinhood_options_mobile/utils/market_hours.dart';

class TradeSignalsProvider with ChangeNotifier {
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

  List<Map<String, dynamic>> _tradeSignals = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _tradeSignalsSubscription;
  List<String>? _currentSymbols;
  int _currentLimit = 50;
  bool _hasReceivedServerData = false;
  String? _selectedInterval; // Will be auto-set based on market hours

  String? _tradeProposalMessage;
  Map<String, dynamic>? _lastTradeProposal;
  Map<String, dynamic>? _lastAssessment;
  bool _isTradeInProgress = false;
  Map<String, dynamic>? _tradeSignal;

  List<Map<String, dynamic>> get tradeSignals => _tradeSignals;
  String? get tradeProposalMessage => _tradeProposalMessage;
  Map<String, dynamic>? get lastTradeProposal => _lastTradeProposal;
  Map<String, dynamic>? get lastAssessment => _lastAssessment;
  bool get isTradeInProgress => _isTradeInProgress;
  Map<String, dynamic>? get tradeSignal => _tradeSignal;
  String get selectedInterval {
    final interval = _selectedInterval ?? _getDefaultInterval();
    debugPrint(
        '🎯 selectedInterval getter called: $_selectedInterval (default: ${_getDefaultInterval()}) -> returning: $interval');
    return interval;
  }

  TradeSignalsProvider();

  String _getDefaultInterval() {
    return MarketHours.isMarketOpen() ? '1h' : '1d';
  }

  @override
  void dispose() {
    debugPrint('🧹 Disposing TradeSignalsProvider - cancelling subscription');
    _tradeSignalsSubscription?.cancel();
    super.dispose();
  }

  bool get hasActiveSubscription => _tradeSignalsSubscription != null;

  Future<void> fetchTradeSignal(String symbol, {String? interval}) async {
    try {
      if (symbol.isEmpty) {
        _tradeSignal = null;
        notifyListeners();
        return;
      }

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

  Future<void> fetchAllTradeSignals({
    String? signalType,
    List<String>? indicators,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? symbols,
    int? limit,
    String? interval,
  }) async {
    if (_tradeSignalsSubscription != null) {
      debugPrint('🛑 Cancelling existing trade signals subscription');
      _tradeSignalsSubscription!.cancel();
      _tradeSignalsSubscription = null;
    }

    _hasReceivedServerData = false;
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

      final effectiveInterval = interval ?? selectedInterval;

      if (signalType != null && signalType.isNotEmpty) {
        if (indicators == null || indicators.isEmpty) {
          query = query.where('signal', isEqualTo: signalType);
        } else {
          for (final indicator in indicators) {
            query = query.where(
                'multiIndicatorResult.indicators.$indicator.signal',
                isEqualTo: signalType);
          }
        }
      }

      query = query.where('interval', isEqualTo: effectiveInterval);

      final queryLimit = 200;

      debugPrint(
          '⏰ Query will fetch up to $queryLimit docs, client-side filter for market hours');

      if (startDate != null) {
        query = query.where('timestamp',
            isGreaterThanOrEqualTo: startDate.millisecondsSinceEpoch);
      }
      if (endDate != null) {
        query = query.where('timestamp',
            isLessThanOrEqualTo: endDate.millisecondsSinceEpoch);
      }

      if (symbols != null && symbols.isNotEmpty) {
        if (symbols.length <= 30) {
          query = query.where('symbol', whereIn: symbols);
        }
      }

      query = query.orderBy('timestamp', descending: true);
      query = query.limit(queryLimit);

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

      _tradeSignalsSubscription = query.snapshots().listen(
        (snapshot) {
          final timestamp = DateTime.now().toString().substring(11, 23);
          debugPrint(
              '🔔 [$timestamp] Firestore snapshot received: ${snapshot.docs.length} documents');
          debugPrint(
              '🔍 [$timestamp] Snapshot metadata - fromCache: ${snapshot.metadata.isFromCache}, hasPendingWrites: ${snapshot.metadata.hasPendingWrites}');

          if (!_hasReceivedServerData) {
            if (!snapshot.metadata.isFromCache) {
              _hasReceivedServerData = true;
              debugPrint(
                  '📡 [$timestamp] First server snapshot - processing immediately');
            } else if (snapshot.metadata.hasPendingWrites) {
              debugPrint(
                  '📝 [$timestamp] Processing cached snapshot with pending writes');
            } else {
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

  void _updateTradeSignalsFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    List<String>? symbols,
    String effectiveInterval,
  ) {
    final isMarketOpen = MarketHours.isMarketOpen();

    debugPrint('📊 Processing ${snapshot.docs.length} documents');
    debugPrint('   Market status: ${isMarketOpen ? "OPEN" : "CLOSED"}');
    debugPrint('   Selected interval: $effectiveInterval');

    _tradeSignals = snapshot.docs
        .where((doc) {
          final data = doc.data();
          final interval = data['interval'] as String?;

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
          if (data.containsKey('timestamp')) {
            return data;
          }
          return null;
        })
        .where((data) => data != null)
        .cast<Map<String, dynamic>>()
        .toList();

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
    required Map<String, dynamic> config,
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
      'smaPeriodFast': config['smaPeriodFast'],
      'smaPeriodSlow': config['smaPeriodSlow'],
      'tradeQuantity': config['tradeQuantity'],
      'maxPositionSize': config['maxPositionSize'],
      'maxPortfolioConcentration': config['maxPortfolioConcentration'],
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
            name: 'trade_signals_trade_approved',
            parameters: {'interval': effectiveInterval});
      } else {
        _lastTradeProposal = null;
        _lastAssessment = null;
        final message = data['message']?.toString() ?? 'Rejected by agent';
        final reasonMsg =
            (reason != null && reason.isNotEmpty) ? '\n$reason' : '';
        _tradeProposalMessage =
            'Trade proposal rejected for $symbol ($intervalLabel).\n$message\n$reasonMsg';
        _analytics.logEvent(name: 'trade_signals_trade_rejected', parameters: {
          'reason': reason ?? message,
          'interval': effectiveInterval
        });
      }
    } catch (e) {
      _tradeProposalMessage =
          'Function call failed, falling back to local simulation: ${e.toString()}';
      await Future.delayed(const Duration(seconds: 1));
      final simulatedTradeProposal = {
        'symbol': symbol,
        'action': 'BUY',
        'quantity': config['tradeQuantity'],
        'price': currentPrice,
      };
      _lastTradeProposal = Map<String, dynamic>.from(simulatedTradeProposal);
      _tradeProposalMessage =
          'Trade proposal (simulated): ${_lastTradeProposal!['action']} ${_lastTradeProposal!['quantity']} of ${_lastTradeProposal!['symbol']}';
      _analytics.logEvent(
          name: 'trade_signals_trade_approved_simulated',
          parameters: {'error': e.toString()});
    }

    _isTradeInProgress = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> assessTradeRisk({
    required Map<String, dynamic> proposal,
    required Map<String, dynamic> portfolioState,
    required Map<String, dynamic> config,
  }) async {
    try {
      final result = await _functions.httpsCallable('riskguardTask').call({
        'proposal': proposal,
        'portfolioState': portfolioState,
        'config': config,
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
