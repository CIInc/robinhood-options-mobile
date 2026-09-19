import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:robinhood_options_mobile/model/risk_circuit_breaker_config.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';

/// Service responsible for managing Autonomous Account Risk Circuit Breakers & Tilt Guardrails.
class RiskCircuitBreakerService {
  static const String _prefsKey = 'risk_circuit_breaker_config';
  RiskCircuitBreakerConfig _config = RiskCircuitBreakerConfig();

  RiskCircuitBreakerConfig get config => _config;

  RiskCircuitBreakerService({RiskCircuitBreakerConfig? initialConfig}) {
    if (initialConfig != null) {
      _config = initialConfig;
    }
  }

  /// Initialize and load stored configuration from local storage
  Future<RiskCircuitBreakerConfig> loadConfig({User? user}) async {
    // 1. If user already has a configured profile, prefer it
    if (user?.riskCircuitBreakerConfig != null) {
      _config = user!.riskCircuitBreakerConfig!;
      await saveToLocal();
      return _config;
    }

    // 2. Otherwise load from local SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefsKey);
      if (jsonStr != null) {
        final Map<String, dynamic> data = jsonDecode(jsonStr);
        _config = RiskCircuitBreakerConfig.fromJson(data);
      }
    } catch (e) {
      debugPrint('Error loading RiskCircuitBreakerConfig: $e');
    }

    return _config;
  }

  /// Update the current configuration and persist
  Future<void> updateConfig(
    RiskCircuitBreakerConfig newConfig, {
    User? user,
    FirestoreService? firestoreService,
  }) async {
    _config = newConfig;
    await saveToLocal();

    if (user != null && firestoreService != null) {
      user.riskCircuitBreakerConfig = newConfig;
      try {
        final docRef =
            firestoreService.userCollection.doc(user.email ?? user.name);
        await firestoreService.updateUser(docRef, user);
      } catch (e) {
        debugPrint(
            'Error updating user RiskCircuitBreakerConfig in Firestore: $e');
      }
    }
  }

  /// Save current configuration to local SharedPreferences
  Future<void> saveToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_config.toJson()));
    } catch (e) {
      debugPrint('Error saving RiskCircuitBreakerConfig to prefs: $e');
    }
  }

  /// Update peak portfolio equity for high-water mark drawdown calculations
  void updatePeakEquity(double currentEquity) {
    if (currentEquity <= 0) return;
    final currentPeak = _config.peakPortfolioEquity ?? 0.0;
    if (currentEquity > currentPeak) {
      _config.peakPortfolioEquity = currentEquity;
      saveToLocal();
    }
  }

  /// Evaluate portfolio risk metrics against configured safety thresholds
  RiskEvaluationResult evaluateRisk({
    required double equity,
    required double dayPnL,
    required double dayPnLPercent,
    double? marginBufferPercent,
  }) {
    if (!_config.enabled) {
      return RiskEvaluationResult.ok;
    }

    // 1. Check if cooling-off period is currently active
    if (_config.isInCoolingOff) {
      return RiskEvaluationResult(
        allowed: false,
        isCoolingOff: true,
        remainingCoolingOff: _config.remainingCoolingOff,
        reason:
            'Cooling-off lock active. Trading suspended until ${_formatDateTime(_config.coolingOffUntil)} to prevent emotional trading.',
        triggerType: 'cooling_off',
      );
    }

    // 2. Check if circuit breaker was already tripped
    if (_config.isTripped) {
      return RiskEvaluationResult(
        allowed: false,
        reason: _config.tripReason ??
            'Circuit breaker tripped. Order execution locked.',
        triggerType: 'tripped',
      );
    }

    // Update peak equity if equity is positive
    if (equity > 0) {
      final currentPeak = _config.peakPortfolioEquity ?? equity;
      if (equity > currentPeak) {
        _config.peakPortfolioEquity = equity;
      }
    }

    // 3. Max Daily Dollar Loss Breach
    if (_config.maxDailyLossAmount != null && _config.maxDailyLossAmount! > 0) {
      if (dayPnL < 0 && dayPnL.abs() >= _config.maxDailyLossAmount!) {
        _tripCircuitBreaker(
          'Daily loss limit reached (-\$${dayPnL.abs().toStringAsFixed(2)} >= \$${_config.maxDailyLossAmount!.toStringAsFixed(2)} threshold). Execution suspended to protect capital.',
          triggerType: 'daily_loss_amount',
        );
        return RiskEvaluationResult(
          allowed: false,
          isCoolingOff: true,
          remainingCoolingOff: _config.remainingCoolingOff,
          reason: _config.tripReason,
          triggerType: 'daily_loss_amount',
        );
      }
    }

    // 4. Max Daily Percentage Loss Breach
    if (_config.maxDailyLossPercent != null &&
        _config.maxDailyLossPercent! > 0) {
      if (dayPnLPercent < 0 &&
          dayPnLPercent.abs() >= _config.maxDailyLossPercent!) {
        _tripCircuitBreaker(
          'Daily portfolio loss limit reached (-${dayPnLPercent.abs().toStringAsFixed(2)}% >= ${_config.maxDailyLossPercent!.toStringAsFixed(2)}% threshold). Execution suspended to protect capital.',
          triggerType: 'daily_loss_percent',
        );
        return RiskEvaluationResult(
          allowed: false,
          isCoolingOff: true,
          remainingCoolingOff: _config.remainingCoolingOff,
          reason: _config.tripReason,
          triggerType: 'daily_loss_percent',
        );
      }
    }

    // 5. Max Drawdown Breach (Peak-to-Trough)
    if (_config.maxDrawdownPercent != null &&
        _config.maxDrawdownPercent! > 0 &&
        equity > 0) {
      final peak = _config.peakPortfolioEquity ?? equity;
      if (peak > 0 && equity < peak) {
        final currentDrawdown = ((peak - equity) / peak) * 100.0;
        if (currentDrawdown >= _config.maxDrawdownPercent!) {
          _tripCircuitBreaker(
            'Maximum portfolio drawdown reached (-${currentDrawdown.toStringAsFixed(2)}% >= ${_config.maxDrawdownPercent!.toStringAsFixed(2)}% from peak of \$${peak.toStringAsFixed(2)}). Execution locked.',
            triggerType: 'drawdown',
          );
          return RiskEvaluationResult(
            allowed: false,
            isCoolingOff: true,
            remainingCoolingOff: _config.remainingCoolingOff,
            reason: _config.tripReason,
            triggerType: 'drawdown',
          );
        }
      }
    }

    // 6. Minimum Margin Buffer Breach
    if (_config.minMarginBufferPercent != null &&
        _config.minMarginBufferPercent! > 0 &&
        marginBufferPercent != null) {
      if (marginBufferPercent <= _config.minMarginBufferPercent!) {
        return RiskEvaluationResult(
          allowed: false,
          reason:
              'Margin buffer too low (${marginBufferPercent.toStringAsFixed(1)}% <= ${_config.minMarginBufferPercent!.toStringAsFixed(1)}% requirement). New orders blocked to prevent margin calls.',
          triggerType: 'margin_buffer',
        );
      }
    }

    return RiskEvaluationResult.ok;
  }

  /// Record outcome of a completed trade to monitor consecutive loss streaks
  void recordTradeOutcome({required bool isWin, double? pnl}) {
    if (!_config.enabled) return;

    final now = DateTime.now();
    _config.lastTradeDate = now;

    if (!isWin) {
      _config.currentConsecutiveLosses += 1;

      // Check if consecutive loss limit exceeded
      if (_config.maxConsecutiveLosses != null &&
          _config.maxConsecutiveLosses! > 0 &&
          _config.currentConsecutiveLosses >= _config.maxConsecutiveLosses!) {
        _tripCircuitBreaker(
          'Consecutive loss limit reached (${_config.currentConsecutiveLosses} consecutive losing trades >= ${_config.maxConsecutiveLosses} limit). Mandatory cooling-off activated to prevent tilt.',
          triggerType: 'consecutive_losses',
        );
      }
    } else {
      // Reset streak on win
      _config.currentConsecutiveLosses = 0;
    }

    saveToLocal();
  }

  /// Internal helper to trip the circuit breaker and initiate cooling-off
  void _tripCircuitBreaker(String reason, {required String triggerType}) {
    _config.isTripped = true;
    _config.tripReason = reason;
    _config.trippedAt = DateTime.now();

    final minutes = max(1, _config.coolingOffDurationMinutes);
    _config.coolingOffUntil = DateTime.now().add(Duration(minutes: minutes));

    saveToLocal();
  }

  /// Manually trip the circuit breaker (e.g. for testing or emergency user lock)
  void tripManually({String? reason, int? durationMinutes}) {
    final dur = durationMinutes ?? _config.coolingOffDurationMinutes;
    _config.isTripped = true;
    _config.tripReason =
        reason ?? 'Manual risk circuit breaker triggered by trader.';
    _config.trippedAt = DateTime.now();
    _config.coolingOffUntil = DateTime.now().add(Duration(minutes: dur));
    saveToLocal();
  }

  /// Reset the circuit breaker and lift cooling-off suspension
  Future<void> resetCircuitBreaker(
      {User? user, FirestoreService? firestoreService}) async {
    _config.isTripped = false;
    _config.tripReason = null;
    _config.coolingOffUntil = null;
    _config.currentConsecutiveLosses = 0;

    await saveToLocal();

    if (user != null && firestoreService != null) {
      user.riskCircuitBreakerConfig = _config;
      try {
        final docRef =
            firestoreService.userCollection.doc(user.email ?? user.name);
        await firestoreService.updateUser(docRef, user);
      } catch (e) {
        debugPrint(
            'Error updating user RiskCircuitBreakerConfig in Firestore: $e');
      }
    }
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '';
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }
}
