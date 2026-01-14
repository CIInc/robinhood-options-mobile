import 'dart:async';
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
    }
  }

  /// Run a backtest with the given configuration
  Future<BacktestResult?> runBacktest(TradeStrategyConfig config) async {
    if (_isRunning) {
      debugPrint('⚠️ Backtest already in progress');
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
          'start_date': config.startDate.toIso8601String(),
          'end_date': config.endDate.toIso8601String(),
          'interval': config.interval,
        },
      );

      // Call Firebase Function to run backtest
      final callable = _functions.httpsCallable('runBacktest');
      final response = await callable.call(config.toJson());

      if (response.data == null) {
        throw Exception('No data returned from backtest function');
      }

      final resultData = Map<String, dynamic>.from(response.data as Map);
      final result = BacktestResult.fromJson(resultData);

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
      return result;
    } catch (e) {
      debugPrint('❌ Backtest error: $e');
      _errorMessage = e.toString();
      _isRunning = false;
      _progress = 0.0;

      await _analytics.logEvent(
        name: 'backtest_error',
        parameters: {
          'symbols': config.symbolFilter.join(','),
          'error': e.toString(),
        },
      );

      notifyListeners();
      return null;
    }
  }

  /// Save backtest result to history
  Future<void> _saveToHistory(BacktestResult result) async {
    if (_userDocRef == null) return;

    try {
      await _firestore
          .collection('user')
          .doc(_userDocRef!.id)
          .collection('backtest_history')
          .add({
        'result': result.toJson(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      _backtestHistory.insert(0, result);
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
        return BacktestResult.fromJson(data['result'] as Map<String, dynamic>);
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

      // Find and delete from Firestore
      // Use query based on available fields. If symbolFilter is present in object, query it.
      // If object is old and has no symbolFilter, this query might fail to find it if we rely on symbolFilter.
      // But we can try to delete by ID if we had it, but we don't store ID in result object.
      // Best effort: query for symbolFilter containing first symbol if available.
      if (result.config.symbolFilter.isNotEmpty) {
        final snapshot = await _firestore
            .collection('user')
            .doc(_userDocRef!.id)
            .collection('backtest_history')
            .where('result.config.symbolFilter',
                arrayContains: result.config.symbolFilter.first)
            .where('result.config.startDate',
                isEqualTo: result.config.startDate.toIso8601String())
            .limit(1)
            .get();

        for (final doc in snapshot.docs) {
          await doc.reference.delete();
        }
      } else {
        // Fallback for old records without symbolFilter (if we can infer they are old)
        // But we removed `symbol` field from local object so we can't query by it easily
        // unless we kept it around. Since we didn't, we can try to query by date only?
        // That might be too broad.
        // For now, let's just log warning.
        debugPrint(
            '⚠️ Cannot delete backtest with empty symbolFilter (legacy record)');
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
