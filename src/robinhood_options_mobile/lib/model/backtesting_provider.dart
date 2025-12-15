import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:robinhood_options_mobile/model/backtesting_models.dart';
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
  List<BacktestTemplate> _templates = [];
  DocumentReference<User>? _userDocRef;
  BacktestTemplate? _pendingTemplate; // Template waiting to be loaded

  // Getters
  BacktestResult? get currentResult => _currentResult;
  bool get isRunning => _isRunning;
  String? get errorMessage => _errorMessage;
  double get progress => _progress;
  List<BacktestResult> get backtestHistory => _backtestHistory;
  List<BacktestTemplate> get templates => _templates;
  BacktestTemplate? get pendingTemplate => _pendingTemplate;

  /// Initialize provider with user document reference
  void initialize(DocumentReference<User>? userDocRef) {
    _userDocRef = userDocRef;
    if (userDocRef != null) {
      _loadBacktestHistory();
      _loadTemplates();
    }
  }

  /// Run a backtest with the given configuration
  Future<BacktestResult?> runBacktest(BacktestConfig config) async {
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
      debugPrint('🔄 Starting backtest for ${config.symbol}...');
      await _analytics.logEvent(
        name: 'backtest_started',
        parameters: {
          'symbol': config.symbol,
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
          'symbol': config.symbol,
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
          'symbol': config.symbol,
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
  Future<void> saveTemplate(BacktestTemplate template) async {
    if (_userDocRef == null) return;

    try {
      await _firestore
          .collection('user')
          .doc(_userDocRef!.id)
          .collection('backtest_templates')
          .doc(template.id)
          .set(template.toJson());

      _templates.add(template);
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
  Future<void> saveConfigAsTemplate({
    required String name,
    required String description,
    required BacktestConfig config,
  }) async {
    final template = BacktestTemplate(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      description: description,
      config: config,
      createdAt: DateTime.now(),
    );

    await saveTemplate(template);
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

      _templates = snapshot.docs
          .map((doc) => BacktestTemplate.fromJson(
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
    if (_userDocRef == null) return;

    try {
      await _firestore
          .collection('user')
          .doc(_userDocRef!.id)
          .collection('backtest_templates')
          .doc(templateId)
          .delete();

      _templates.removeWhere((t) => t.id == templateId);
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
    if (_userDocRef == null) return;

    try {
      final now = DateTime.now();
      await _firestore
          .collection('user')
          .doc(_userDocRef!.id)
          .collection('backtest_templates')
          .doc(templateId)
          .update({'lastUsedAt': now.toIso8601String()});

      final index = _templates.indexWhere((t) => t.id == templateId);
      if (index != -1) {
        final template = _templates[index];
        _templates[index] = BacktestTemplate(
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
  void setPendingTemplate(BacktestTemplate template) {
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
      final snapshot = await _firestore
          .collection('user')
          .doc(_userDocRef!.id)
          .collection('backtest_history')
          .where('result.config.symbol', isEqualTo: result.config.symbol)
          .where('result.config.startDate',
              isEqualTo: result.config.startDate.toIso8601String())
          .limit(1)
          .get();

      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }

      _backtestHistory.removeAt(index);
      notifyListeners();

      await _analytics.logEvent(
        name: 'backtest_deleted_from_history',
        parameters: {'symbol': result.config.symbol},
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
