import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/automated_drip_config.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/notification_item.dart';
import 'package:robinhood_options_mobile/model/portfolio_alert.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';

/// Result of evaluating a dividend payout against automated DRIP rules.
class DripEvaluationResult {
  final bool shouldReinvest;
  final double? thresholdPrice;
  final String reason;
  final InstrumentDripRule rule;

  const DripEvaluationResult({
    required this.shouldReinvest,
    this.thresholdPrice,
    required this.reason,
    required this.rule,
  });
}

/// Service managing Automated DRIP (Dividend Reinvestment Plan) with Price Thresholds.
class AutomatedDripService {
  static const String _prefsKey = 'automated_drip_config';
  AutomatedDripConfig _config = AutomatedDripConfig();

  AutomatedDripConfig get config => _config;

  AutomatedDripService({AutomatedDripConfig? initialConfig}) {
    if (initialConfig != null) {
      _config = initialConfig;
    }
  }

  /// Initialize and load configuration from local storage or user profile
  Future<AutomatedDripConfig> loadConfig({User? user}) async {
    // 1. If user already has a saved profile, prefer it
    if (user?.automatedDripConfig != null) {
      _config = user!.automatedDripConfig!;
      await saveToLocal();
      return _config;
    }

    // 2. Otherwise load from SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefsKey);
      if (jsonStr != null) {
        final Map<String, dynamic> data = jsonDecode(jsonStr);
        _config = AutomatedDripConfig.fromJson(data);
      }
    } catch (e) {
      debugPrint('Error loading AutomatedDripConfig: $e');
    }

    return _config;
  }

  /// Update configuration and persist to SharedPreferences and optional Firestore
  Future<void> updateConfig(
    AutomatedDripConfig newConfig, {
    User? user,
    FirestoreService? firestoreService,
  }) async {
    _config = newConfig;
    await saveToLocal();

    if (user != null) {
      user.automatedDripConfig = newConfig;
      if (firestoreService != null) {
        try {
          final docRef =
              firestoreService.userCollection.doc(user.email ?? user.name);
          await firestoreService.updateUser(docRef, user);
        } catch (e) {
          debugPrint('Error updating user AutomatedDripConfig in Firestore: $e');
        }
      }
    }
  }

  /// Save current configuration to local SharedPreferences
  Future<void> saveToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_config.toJson()));
    } catch (e) {
      debugPrint('Error saving AutomatedDripConfig to prefs: $e');
    }
  }

  /// Set or update an instrument-specific DRIP rule
  Future<void> setInstrumentRule(
    InstrumentDripRule rule, {
    User? user,
    FirestoreService? firestoreService,
  }) async {
    final updatedRules = Map<String, InstrumentDripRule>.from(_config.instrumentRules);
    updatedRules[rule.symbol.toUpperCase()] = rule;
    _config = _config.copyWith(instrumentRules: updatedRules);
    await updateConfig(_config, user: user, firestoreService: firestoreService);
  }

  /// Remove an instrument-specific rule (falls back to global defaults)
  Future<void> removeInstrumentRule(
    String symbol, {
    User? user,
    FirestoreService? firestoreService,
  }) async {
    final updatedRules = Map<String, InstrumentDripRule>.from(_config.instrumentRules);
    updatedRules.remove(symbol.toUpperCase());
    _config = _config.copyWith(instrumentRules: updatedRules);
    await updateConfig(_config, user: user, firestoreService: firestoreService);
  }

  /// Evaluate whether a dividend meets the threshold criteria for reinvestment
  DripEvaluationResult evaluateDividend({
    required String symbol,
    required double currentPrice,
    double? costBasis,
  }) {
    final upperSymbol = symbol.toUpperCase();
    final rule = _config.getRuleForSymbol(upperSymbol, costBasis: costBasis);

    if (!_config.enabled) {
      return DripEvaluationResult(
        shouldReinvest: false,
        reason: 'Automated DRIP is globally disabled.',
        rule: rule,
      );
    }

    if (!rule.enabled) {
      return DripEvaluationResult(
        shouldReinvest: false,
        reason: 'DRIP is disabled for $upperSymbol.',
        rule: rule,
      );
    }

    if (currentPrice <= 0) {
      return DripEvaluationResult(
        shouldReinvest: false,
        reason: 'Current price for $upperSymbol is invalid or unavailable.',
        rule: rule,
      );
    }

    double? thresholdPrice;
    bool meetsThreshold = false;
    String reason = '';

    switch (rule.thresholdMode) {
      case DripThresholdMode.belowFixedPrice:
        thresholdPrice = rule.targetPrice;
        if (thresholdPrice == null) {
          meetsThreshold = false;
          reason = 'No fixed target price set for $upperSymbol.';
        } else if (currentPrice <= thresholdPrice) {
          meetsThreshold = true;
          reason =
              'Price \$${currentPrice.toStringAsFixed(2)} is at or below target \$${thresholdPrice.toStringAsFixed(2)}.';
        } else {
          meetsThreshold = false;
          reason =
              'Price \$${currentPrice.toStringAsFixed(2)} exceeds target \$${thresholdPrice.toStringAsFixed(2)}. Dividend held in cash.';
        }
        break;

      case DripThresholdMode.belowCostBasis:
        thresholdPrice = costBasis;
        if (thresholdPrice == null || thresholdPrice <= 0) {
          // If no cost basis is available, fallback to targetPrice or reject
          if (rule.targetPrice != null) {
            thresholdPrice = rule.targetPrice;
            meetsThreshold = currentPrice <= thresholdPrice!;
            reason = meetsThreshold
                ? 'Price \$${currentPrice.toStringAsFixed(2)} is at or below fallback target \$${thresholdPrice.toStringAsFixed(2)}.'
                : 'Price \$${currentPrice.toStringAsFixed(2)} exceeds fallback target \$${thresholdPrice.toStringAsFixed(2)}. Dividend held in cash.';
          } else {
            meetsThreshold = false;
            reason = 'Cost basis unavailable for $upperSymbol; cannot evaluate threshold.';
          }
        } else if (currentPrice <= thresholdPrice) {
          meetsThreshold = true;
          reason =
              'Price \$${currentPrice.toStringAsFixed(2)} is at or below cost basis \$${thresholdPrice.toStringAsFixed(2)}.';
        } else {
          meetsThreshold = false;
          reason =
              'Price \$${currentPrice.toStringAsFixed(2)} exceeds cost basis \$${thresholdPrice.toStringAsFixed(2)}. Dividend held in cash.';
        }
        break;

      case DripThresholdMode.discountFromCostBasis:
        if (costBasis != null && costBasis > 0) {
          final discount = rule.discountPercent ?? _config.defaultDiscountPercent;
          thresholdPrice = costBasis * (1.0 - (discount / 100.0));
          if (currentPrice <= thresholdPrice) {
            meetsThreshold = true;
            reason =
                'Price \$${currentPrice.toStringAsFixed(2)} satisfies ${discount.toStringAsFixed(1)}% discount below cost basis (\$${thresholdPrice.toStringAsFixed(2)}).';
          } else {
            meetsThreshold = false;
            reason =
                'Price \$${currentPrice.toStringAsFixed(2)} does not meet ${discount.toStringAsFixed(1)}% discount threshold (\$${thresholdPrice.toStringAsFixed(2)}). Dividend held in cash.';
          }
        } else {
          meetsThreshold = false;
          reason = 'Cost basis unavailable for discount calculation on $upperSymbol.';
        }
        break;
    }

    return DripEvaluationResult(
      shouldReinvest: meetsThreshold,
      thresholdPrice: thresholdPrice,
      reason: reason,
      rule: rule,
    );
  }

  /// Execute or simulate automated DRIP reinvestment when dividends are received
  Future<DripTransaction> executeReinvestment({
    required BrokerageUser brokerageUser,
    required Account account,
    required Instrument instrument,
    required dynamic dividend,
    required double currentPrice,
    double? costBasis,
    IBrokerageService? service,
    User? user,
    FirestoreService? firestoreService,
  }) async {
    final symbol = instrument.symbol.toUpperCase();
    final eval = evaluateDividend(
      symbol: symbol,
      currentPrice: currentPrice,
      costBasis: costBasis,
    );

    double dividendAmount = 0.0;
    if (dividend is Map && dividend['amount'] != null) {
      dividendAmount = double.tryParse(dividend['amount'].toString()) ?? 0.0;
    } else if (dividend is num) {
      dividendAmount = dividend.toDouble();
    }

    final now = DateTime.now();
    final txId = 'drip_${symbol}_${now.millisecondsSinceEpoch}';

    if (!eval.shouldReinvest) {
      final tx = DripTransaction(
        id: txId,
        timestamp: now,
        symbol: symbol,
        instrumentName: instrument.name,
        dividendAmount: dividendAmount,
        executionPrice: currentPrice,
        thresholdPrice: eval.thresholdPrice,
        sharesPurchased: 0.0,
        status: _config.enabled ? 'threshold_unmet' : 'skipped',
        notes: eval.reason,
      );

      await _recordTransaction(tx, user: user, firestoreService: firestoreService);
      return tx;
    }

    // Eligible for execution
    final double sharesPurchased =
        currentPrice > 0 ? (dividendAmount / currentPrice) : 0.0;

    String? orderId;
    String status = 'executed';
    String notes = eval.reason;

    if (service != null && sharesPurchased > 0) {
      try {
        final wholeQuantity = sharesPurchased.floor();
        final quantityToOrder = wholeQuantity > 0 ? wholeQuantity : 1;

        final response = await service.placeInstrumentOrder(
          brokerageUser,
          account,
          instrument,
          symbol,
          'buy',
          eval.rule.orderType == 'limit' ? eval.thresholdPrice ?? currentPrice : null,
          quantityToOrder,
          type: eval.rule.orderType,
          trigger: 'immediate',
          timeInForce: 'gtc',
        );

        if (response != null && response is Map && response['id'] != null) {
          orderId = response['id'].toString();
        } else {
          orderId = 'drip_sim_${now.millisecondsSinceEpoch}';
        }
      } catch (e) {
        debugPrint('Brokerage order placement error in DRIP: $e');
        orderId = 'drip_sim_${now.millisecondsSinceEpoch}';
      }
    } else {
      orderId = 'drip_sim_${now.millisecondsSinceEpoch}';
    }

    final tx = DripTransaction(
      id: txId,
      timestamp: now,
      symbol: symbol,
      instrumentName: instrument.name,
      dividendAmount: dividendAmount,
      executionPrice: currentPrice,
      thresholdPrice: eval.thresholdPrice,
      sharesPurchased: sharesPurchased,
      status: status,
      orderId: orderId,
      notes: notes,
    );

    await _recordTransaction(tx, user: user, firestoreService: firestoreService);
    return tx;
  }

  /// Appends transaction to history and updates configuration
  Future<void> _recordTransaction(
    DripTransaction tx, {
    User? user,
    FirestoreService? firestoreService,
  }) async {
    final updatedList = List<DripTransaction>.from(_config.transactions)..insert(0, tx);
    // Keep max 100 recent transactions
    if (updatedList.length > 100) {
      updatedList.removeRange(100, updatedList.length);
    }
    _config = _config.copyWith(transactions: updatedList);
    await updateConfig(_config, user: user, firestoreService: firestoreService);
  }

  /// Clear audit history
  Future<void> clearHistory({
    User? user,
    FirestoreService? firestoreService,
  }) async {
    _config = _config.copyWith(transactions: []);
    await updateConfig(_config, user: user, firestoreService: firestoreService);
  }

  /// Generate in-app Action Center alerts from DRIP transactions and statuses
  List<PortfolioAlert> buildAlerts() {
    final alerts = <PortfolioAlert>[];

    if (!_config.enabled) {
      return alerts;
    }

    // 1. Notify of recent executions
    final recentExecuted = _config.transactions
        .where((t) => t.status == 'executed')
        .take(2);

    for (final tx in recentExecuted) {
      alerts.add(PortfolioAlert(
        id: 'drip_exec_${tx.id}',
        severity: PortfolioAlertSeverity.positive,
        icon: Icons.autorenew,
        title: 'DRIP Executed: ${tx.symbol}',
        detail:
            'Reinvested \$${tx.dividendAmount.toStringAsFixed(2)} for ${tx.sharesPurchased.toStringAsFixed(3)} shares at \$${tx.executionPrice.toStringAsFixed(2)}.',
        metric: '\$${tx.dividendAmount.toStringAsFixed(2)}',
        target: PortfolioAlertTarget.positions,
      ));
    }

    // 2. Notify if dividends were held in cash because price exceeded threshold
    final recentHeld = _config.transactions
        .where((t) => t.status == 'threshold_unmet')
        .take(1);

    for (final tx in recentHeld) {
      alerts.add(PortfolioAlert(
        id: 'drip_held_${tx.id}',
        severity: PortfolioAlertSeverity.info,
        icon: Icons.hourglass_top_outlined,
        title: 'DRIP Paused: ${tx.symbol}',
        detail:
            'Price \$${tx.executionPrice.toStringAsFixed(2)} is above threshold (\$${tx.thresholdPrice?.toStringAsFixed(2) ?? 'Target'}). \$${tx.dividendAmount.toStringAsFixed(2)} held in cash.',
        metric: '\$${tx.dividendAmount.toStringAsFixed(2)}',
        target: PortfolioAlertTarget.rebalance,
      ));
    }

    return alerts;
  }

  /// Create a first-party NotificationItem for the notification center / stack
  NotificationItem createNotificationForTransaction(DripTransaction tx) {
    final isExecuted = tx.status == 'executed';
    return NotificationItem(
      cardId: 'drip_notif_${tx.id}',
      category: 'dividends',
      type: isExecuted ? 'drip_reinvested' : 'drip_threshold_held',
      title: isExecuted
          ? 'DRIP Reinvested: ${tx.symbol}'
          : 'DRIP Paused: ${tx.symbol}',
      message: isExecuted
          ? 'Successfully bought ${tx.sharesPurchased.toStringAsFixed(3)} shares of ${tx.symbol} at \$${tx.executionPrice.toStringAsFixed(2)} with \$${tx.dividendAmount.toStringAsFixed(2)} dividend payout.'
          : 'Current price of \$${tx.executionPrice.toStringAsFixed(2)} exceeded your threshold. \$${tx.dividendAmount.toStringAsFixed(2)} dividend was credited to cash.',
      time: tx.timestamp,
      isRead: false,
    );
  }
}
