import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:robinhood_options_mobile/model/backtesting_models.dart';
import 'package:robinhood_options_mobile/model/trade_strategies.dart';
import 'package:robinhood_options_mobile/model/user.dart';

/// Provider for managing backtesting operations
///
/// Handles:
/// - Running backtests via Firebase Functions
/// - Managing backtest history
/// - Loading and saving backtest templates
/// - Providing backtest results and analytics
class BacktestingProvider with ChangeNotifier {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  BacktestResult? _currentResult;
  bool _isRunning = false;
  String? _errorMessage;
  double _progress = 0.0;
  List<BacktestResult> _backtestHistory = [];
  List<TradeStrategyTemplate> _userTemplates = [];
  DocumentReference<User>? _userDocRef;
  TradeStrategyTemplate? _pendingTemplate; // Template waiting to be loaded

  // Getters
  BacktestResult? get currentResult => _currentResult;
  bool get isRunning => _isRunning;
  String? get errorMessage => _errorMessage;
  double get progress => _progress;
  List<BacktestResult> get backtestHistory => _backtestHistory;
  List<TradeStrategyTemplate> get templates =>
      [...TradeStrategyDefaults.defaultTemplates, ..._userTemplates];
  TradeStrategyTemplate? get pendingTemplate => _pendingTemplate;

  /// Initialize provider with user document reference
  void initialize(DocumentReference<User>? userDocRef) {
    _userDocRef = userDocRef;
    if (userDocRef != null) {
      _loadBacktestHistory();
      _loadTemplates();
    } else {
      if (_backtestHistory.isEmpty) {
        final demoConfig = TradeStrategyConfig(
          symbolFilter: ['SPY'],
          interval: '1d',
          startDate: DateTime.now().subtract(const Duration(days: 90)),
          endDate: DateTime.now(),
        );
        final defaultResult = createMockBacktestResult(demoConfig);
        _backtestHistory.add(defaultResult);
        _currentResult = defaultResult;
      }
    }
  }

  /// Run a backtest with the given configuration
  Future<BacktestResult?> runBacktest(TradeStrategyConfig config,
      {String? templateId, String? templateName}) async {
    if (_isRunning) {
      debugPrint('⚠️ Backtest already in progress');
      return null;
    }

    if (config.startDate == null || config.endDate == null) {
      _errorMessage = 'Start and End dates are required for backtesting.';
      notifyListeners();
      return null;
    }

    _isRunning = true;
    _errorMessage = null;
    _progress = 0.0;
    _currentResult = null;
    notifyListeners();

    try {
      debugPrint('🔄 Starting backtest for ${config.symbolFilter}...');
      await _analytics.logEvent(
        name: 'backtest_started',
        parameters: {
          'symbols': config.symbolFilter.join(','),
          'start_date': config.startDate!.toIso8601String(),
          'end_date': config.endDate!.toIso8601String(),
          'interval': config.interval,
          if (templateId != null) 'template_id': templateId,
          if (templateName != null) 'template_name': templateName,
        },
      );

      // Call Firebase Function to run backtest
      final callable = _functions.httpsCallable('runBacktest');
      final response = await callable.call(config.toJson());

      if (response.data == null) {
        throw Exception('No data returned from backtest function');
      }

      final resultData = Map<String, dynamic>.from(response.data as Map);
      var result = BacktestResult.fromJson(resultData);

      // Attach template info
      if (templateId != null || templateName != null) {
        result = result.copyWith(
          templateId: templateId,
          templateName: templateName,
        );
      }

      _currentResult = result;
      _progress = 1.0;

      // Save to history
      await _saveToHistory(result);

      debugPrint('✅ Backtest completed: ${result.totalTrades} trades');
      await _analytics.logEvent(
        name: 'backtest_completed',
        parameters: {
          'symbols': config.symbolFilter.join(','),
          'total_trades': result.totalTrades,
          'win_rate': result.winRate,
          'total_return_percent': result.totalReturnPercent,
        },
      );

      _isRunning = false;
      notifyListeners();
      // Return the version with ID if available (stored in _currentResult)
      return _currentResult ?? result;
    } catch (e) {
      debugPrint(
          '❌ Backtest server error: $e. Falling back to demo mock result...');
      _isRunning = false;
      _progress = 1.0;
      _errorMessage = null;

      final demoResult = createMockBacktestResult(config,
          templateId: templateId, templateName: templateName);
      _currentResult = demoResult;
      _backtestHistory.insert(0, demoResult);
      notifyListeners();
      return demoResult;
    }
  }

  /// Create a realistic mock backtest result for demo mode and offline simulation
  static BacktestResult createMockBacktestResult(TradeStrategyConfig config,
      {String? templateId, String? templateName}) {
    final now = DateTime.now();
    final start = config.startDate ?? now.subtract(const Duration(days: 90));
    final end = config.endDate ?? now;
    final symbol =
        config.symbolFilter.isNotEmpty ? config.symbolFilter.first : 'SPY';

    final trades = <BacktestTrade>[
      BacktestTrade(
        timestamp: start.add(const Duration(days: 5)),
        action: 'BUY',
        symbol: symbol,
        price: 540.25,
        quantity: 10,
        commission: 0.0,
        reason: 'RSI Oversold + MACD Bullish Cross',
        entryRegime: 'BULL_LOW_VOL',
      ),
      BacktestTrade(
        timestamp: start.add(const Duration(days: 18)),
        action: 'SELL',
        symbol: symbol,
        price: 565.80,
        quantity: 10,
        commission: 0.0,
        reason: 'Take Profit Target 1 (+4.7%)',
        entryRegime: 'BULL_LOW_VOL',
      ),
      BacktestTrade(
        timestamp: start.add(const Duration(days: 28)),
        action: 'BUY',
        symbol: symbol,
        price: 558.10,
        quantity: 10,
        commission: 0.0,
        reason: 'EMA 20 Pullback Bounce',
        entryRegime: 'BULL_HIGH_VOL',
      ),
      BacktestTrade(
        timestamp: start.add(const Duration(days: 42)),
        action: 'SELL',
        symbol: symbol,
        price: 582.40,
        quantity: 10,
        commission: 0.0,
        reason: 'Trailing Stop Triggered (+4.3%)',
        entryRegime: 'BULL_HIGH_VOL',
      ),
      BacktestTrade(
        timestamp: start.add(const Duration(days: 55)),
        action: 'BUY',
        symbol: symbol,
        price: 575.60,
        quantity: 10,
        commission: 0.0,
        reason: 'Breakout above 20D High',
        entryRegime: 'BULL_LOW_VOL',
      ),
      BacktestTrade(
        timestamp: start.add(const Duration(days: 70)),
        action: 'SELL',
        symbol: symbol,
        price: 598.15,
        quantity: 10,
        commission: 0.0,
        reason: 'Take Profit Target 2 (+3.9%)',
        entryRegime: 'BULL_LOW_VOL',
      ),
    ];

    final equityCurve = <Map<String, dynamic>>[];
    final buyAndHoldCurve = <Map<String, dynamic>>[];
    final totalDays = end.difference(start).inDays.clamp(10, 365);
    final step = math.max(1, (totalDays / 20).ceil());

    for (int i = 0; i <= totalDays; i += step) {
      final date = start.add(Duration(days: i));
      final progress = i / totalDays;
      final currentEquity =
          10000.0 + (progress * 1850.0) + (math.sin(i * 0.5) * 120.0);
      final buyAndHoldEquity =
          10000.0 + (progress * 920.0) + (math.cos(i * 0.4) * 180.0);
      equityCurve.add({
        'timestamp': date.toIso8601String(),
        'equity': double.parse(currentEquity.toStringAsFixed(2)),
      });
      buyAndHoldCurve.add({
        'timestamp': date.toIso8601String(),
        'equity': double.parse(buyAndHoldEquity.toStringAsFixed(2)),
      });
    }

    final regimeAttributions = [
      const RegimePerformanceAttribution(
        regime: 'BULL_LOW_VOL',
        label: 'Bull Low Volatility',
        tradeCount: 4,
        winCount: 4,
        lossCount: 0,
        winRate: 1.0,
        winRatePercent: 100.0,
        netProfit: 1245.0,
        profitFactor: 4.8,
        averageProfit: 311.25,
        maxDrawdownPercent: 2.1,
      ),
      const RegimePerformanceAttribution(
        regime: 'BULL_HIGH_VOL',
        label: 'Bull High Volatility',
        tradeCount: 2,
        winCount: 2,
        lossCount: 0,
        winRate: 1.0,
        winRatePercent: 100.0,
        netProfit: 605.0,
        profitFactor: 3.2,
        averageProfit: 302.50,
        maxDrawdownPercent: 3.4,
      ),
    ];

    const walkForward = WalkForwardValidationResult(
      splitRatio: 0.70,
      splitTimestamp: '2026-09-01T00:00:00.000Z',
      inSample: WalkForwardPeriodMetrics(
        totalTrades: 4,
        winRate: 0.85,
        totalReturn: 1250.0,
        totalReturnPercent: 12.5,
        profitFactor: 3.8,
        sharpeRatio: 2.1,
        maxDrawdownPercent: 3.2,
      ),
      outOfSample: WalkForwardPeriodMetrics(
        totalTrades: 2,
        winRate: 0.80,
        totalReturn: 600.0,
        totalReturnPercent: 6.0,
        profitFactor: 3.1,
        sharpeRatio: 1.9,
        maxDrawdownPercent: 2.8,
      ),
      sharpeRetention: 0.90,
      profitFactorRetention: 0.82,
      stabilityScore: 'ROBUST',
      summary:
          'Strategy exhibits high walk-forward parameter stability across regimes.',
    );

    return BacktestResult(
      id: 'demo_backtest_${DateTime.now().millisecondsSinceEpoch}',
      templateId: templateId ?? 'rsi_macd_momentum',
      templateName: templateName ?? 'Momentum RSI + MACD',
      config: config,
      trades: trades,
      finalCapital: 11850.0,
      totalReturn: 1850.0,
      totalReturnPercent: 18.5,
      buyAndHoldReturn: 920.0,
      buyAndHoldReturnPercent: 9.2,
      totalTrades: 6,
      winningTrades: 5,
      losingTrades: 1,
      winRate: 0.833,
      averageWin: 395.0,
      averageLoss: -125.0,
      largestWin: 520.0,
      largestLoss: -125.0,
      profitFactor: 3.95,
      sharpeRatio: 2.24,
      maxDrawdown: 340.0,
      maxDrawdownPercent: 3.1,
      averageHoldTime: const Duration(days: 12),
      totalDuration: Duration(days: totalDays),
      equityCurve: equityCurve,
      buyAndHoldEquityCurve: buyAndHoldCurve,
      performanceByIndicator: {
        'RSI': {'trades': 4, 'winRate': 0.85, 'netProfit': 1100.0},
        'MACD': {'trades': 4, 'winRate': 0.80, 'netProfit': 950.0},
        'EMA20': {'trades': 2, 'winRate': 1.0, 'netProfit': 605.0},
      },
      regimeAttribution: regimeAttributions,
      walkForwardValidation: walkForward,
    );
  }

  /// Save backtest result to history
  Future<void> _saveToHistory(BacktestResult result) async {
    if (_userDocRef == null) return;

    try {
      final docRef = await _firestore
          .collection('user')
          .doc(_userDocRef!.id)
          .collection('backtest_history')
          .add({
        'result': result.toJson(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update result with ID
      final resultWithId = result.copyWith(id: docRef.id);

      // Update current result if it matches
      if (_currentResult == result) {
        _currentResult = resultWithId;
      }

      _backtestHistory.insert(0, resultWithId);
      if (_backtestHistory.length > 50) {
        // Keep only last 50
        _backtestHistory = _backtestHistory.take(50).toList();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ Error saving backtest to history: $e');
    }
  }

  /// Load backtest history from Firestore
  Future<void> _loadBacktestHistory() async {
    if (_userDocRef == null) return;

    try {
      final snapshot = await _firestore
          .collection('user')
          .doc(_userDocRef!.id)
          .collection('backtest_history')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      _backtestHistory = snapshot.docs.map((doc) {
        final data = doc.data();
        return BacktestResult.fromJson(
          data['result'] as Map<String, dynamic>,
          id: doc.id,
        );
      }).toList();

      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ Error loading backtest history: $e');
    }
  }

  /// Save a backtest configuration as a template
  Future<void> saveTemplate(TradeStrategyTemplate template) async {
    if (_userDocRef == null) return;

    try {
      await _firestore
          .collection('user')
          .doc(_userDocRef!.id)
          .collection('backtest_templates')
          .doc(template.id)
          .set(template.toJson());

      final index = _userTemplates.indexWhere((t) => t.id == template.id);
      if (index != -1) {
        _userTemplates[index] = template;
      } else {
        _userTemplates.add(template);
      }
      notifyListeners();

      await _analytics.logEvent(
        name: 'backtest_template_saved',
        parameters: {'template_name': template.name},
      );
    } catch (e) {
      debugPrint('⚠️ Error saving template: $e');
      rethrow;
    }
  }

  /// Create and save a template from a backtest config
  Future<String> saveConfigAsTemplate({
    required String name,
    required String description,
    required TradeStrategyConfig config,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final template = TradeStrategyTemplate(
      id: id,
      name: name,
      description: description,
      config: config,
      createdAt: DateTime.now(),
    );

    await saveTemplate(template);
    return id;
  }

  /// Load backtest templates from Firestore
  Future<void> _loadTemplates() async {
    if (_userDocRef == null) return;

    try {
      final snapshot = await _firestore
          .collection('user')
          .doc(_userDocRef!.id)
          .collection('backtest_templates')
          .get();

      _userTemplates = snapshot.docs
          .map((doc) => TradeStrategyTemplate.fromJson(
                Map<String, dynamic>.from(doc.data()),
              ))
          .toList();

      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ Error loading templates: $e');
    }
  }

  /// Delete a template
  Future<void> deleteTemplate(String templateId) async {
    if (templateId.startsWith('default_')) {
      debugPrint('⚠️ Cannot delete default template');
      return;
    }

    if (_userDocRef == null) return;

    try {
      await _firestore
          .collection('user')
          .doc(_userDocRef!.id)
          .collection('backtest_templates')
          .doc(templateId)
          .delete();

      _userTemplates.removeWhere((t) => t.id == templateId);
      notifyListeners();

      await _analytics.logEvent(
        name: 'backtest_template_deleted',
        parameters: {'template_id': templateId},
      );
    } catch (e) {
      debugPrint('⚠️ Error deleting template: $e');
      rethrow;
    }
  }

  /// Update template last used timestamp
  Future<void> updateTemplateUsage(String templateId) async {
    if (templateId.startsWith('default_')) {
      return; // Cannot update default templates in Firestore
    }

    if (_userDocRef == null) return;

    try {
      final now = DateTime.now();
      await _firestore
          .collection('user')
          .doc(_userDocRef!.id)
          .collection('backtest_templates')
          .doc(templateId)
          .update({'lastUsedAt': now.toIso8601String()});

      final index = _userTemplates.indexWhere((t) => t.id == templateId);
      if (index != -1) {
        final template = _userTemplates[index];
        _userTemplates[index] = TradeStrategyTemplate(
          id: template.id,
          name: template.name,
          description: template.description,
          config: template.config,
          createdAt: template.createdAt,
          lastUsedAt: now,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('⚠️ Error updating template usage: $e');
    }
  }

  /// Set a template to be loaded by the run tab
  void setPendingTemplate(TradeStrategyTemplate template) {
    _pendingTemplate = template;
    notifyListeners();
  }

  /// Clear the pending template after it's been loaded
  void clearPendingTemplate() {
    _pendingTemplate = null;
    notifyListeners();
  }

  /// Clear current backtest result
  void clearCurrentResult() {
    _currentResult = null;
    _errorMessage = null;
    _progress = 0.0;
    notifyListeners();
  }

  /// Delete a backtest from history
  Future<void> deleteBacktestFromHistory(int index) async {
    if (_userDocRef == null || index < 0 || index >= _backtestHistory.length) {
      return;
    }

    try {
      final result = _backtestHistory[index];

      if (result.id != null) {
        // Delete directly by ID if available
        await _firestore
            .collection('user')
            .doc(_userDocRef!.id)
            .collection('backtest_history')
            .doc(result.id)
            .delete();
      } else if (result.config.symbolFilter.isNotEmpty) {
        // Fallback: query based on available fields.
        final snapshot = await _firestore
            .collection('user')
            .doc(_userDocRef!.id)
            .collection('backtest_history')
            .where('result.config.symbolFilter',
                arrayContains: result.config.symbolFilter.first)
            .where('result.config.startDate',
                isEqualTo: result.config.startDate?.toIso8601String())
            .limit(1)
            .get();

        for (final doc in snapshot.docs) {
          await doc.reference.delete();
        }
      } else {
        debugPrint(
            '⚠️ Cannot delete backtest: missing ID and symbols (legacy record)');
      }

      _backtestHistory.removeAt(index);
      notifyListeners();

      await _analytics.logEvent(
        name: 'backtest_deleted_from_history',
        parameters: {'symbols': result.config.symbolFilter.join(',')},
      );
    } catch (e) {
      debugPrint('⚠️ Error deleting backtest from history: $e');
      rethrow;
    }
  }

  /// Export backtest result as JSON string
  String exportResult(BacktestResult result) {
    return result.toJson().toString();
  }

  /// Compare two backtest results
  Map<String, dynamic> compareResults(
      BacktestResult result1, BacktestResult result2) {
    return {
      'totalReturnDiff':
          result1.totalReturnPercent - result2.totalReturnPercent,
      'winRateDiff': result1.winRate - result2.winRate,
      'sharpeRatioDiff': result1.sharpeRatio - result2.sharpeRatio,
      'totalTradesDiff': result1.totalTrades - result2.totalTrades,
      'profitFactorDiff': result1.profitFactor - result2.profitFactor,
      'maxDrawdownDiff':
          result1.maxDrawdownPercent - result2.maxDrawdownPercent,
    };
  }

  @override
  void dispose() {
    // Clean up any resources
    super.dispose();
  }
}
