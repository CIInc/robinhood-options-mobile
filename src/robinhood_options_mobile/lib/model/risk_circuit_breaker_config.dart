import 'package:cloud_firestore/cloud_firestore.dart';

/// Configuration and state for Autonomous Account Risk Circuit Breakers & Tilt Guardrails.
class RiskCircuitBreakerConfig {
  /// Master toggle for risk circuit breakers
  bool enabled;

  /// Maximum allowed dollar loss in a single trading day (e.g. $500)
  double? maxDailyLossAmount;

  /// Maximum allowed percentage loss of portfolio in a single trading day (e.g. 3.0 for 3%)
  double? maxDailyLossPercent;

  /// Maximum allowed peak-to-trough trailing drawdown percentage (e.g. 10.0 for 10%)
  double? maxDrawdownPercent;

  /// Maximum number of consecutive losing trades allowed before triggering lockout (e.g. 3)
  int? maxConsecutiveLosses;

  /// Minimum margin buffer / cushion percentage required to allow new orders (e.g. 15.0 for 15%)
  double? minMarginBufferPercent;

  /// Mandatory cooling-off duration in minutes when a circuit breaker trips (e.g. 60)
  int coolingOffDurationMinutes;

  /// When active, timestamp until which order execution is suspended
  DateTime? coolingOffUntil;

  /// Whether the circuit breaker is currently tripped
  bool isTripped;

  /// The reason why the circuit breaker was triggered
  String? tripReason;

  /// Timestamp when the circuit breaker was triggered
  DateTime? trippedAt;

  /// Highest portfolio equity recorded, used to measure peak-to-trough drawdown
  double? peakPortfolioEquity;

  /// Current rolling count of consecutive losing trades
  int currentConsecutiveLosses;

  /// Last trade result timestamp
  DateTime? lastTradeDate;

  RiskCircuitBreakerConfig({
    this.enabled = false,
    this.maxDailyLossAmount,
    this.maxDailyLossPercent = 3.0,
    this.maxDrawdownPercent = 10.0,
    this.maxConsecutiveLosses = 3,
    this.minMarginBufferPercent = 15.0,
    this.coolingOffDurationMinutes = 60,
    this.coolingOffUntil,
    this.isTripped = false,
    this.tripReason,
    this.trippedAt,
    this.peakPortfolioEquity,
    this.currentConsecutiveLosses = 0,
    this.lastTradeDate,
  });

  /// Check whether the circuit breaker is currently in an active cooling-off suspension
  bool get isInCoolingOff {
    if (coolingOffUntil == null) return false;
    return DateTime.now().isBefore(coolingOffUntil!);
  }

  /// Remaining duration of the cooling-off period, if active
  Duration? get remainingCoolingOff {
    if (!isInCoolingOff || coolingOffUntil == null) return null;
    final diff = coolingOffUntil!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Check whether trading execution is blocked
  bool get isExecutionBlocked {
    if (!enabled) return false;
    return isTripped || isInCoolingOff;
  }

  RiskCircuitBreakerConfig.fromJson(Map<String, dynamic> json)
      : enabled = (json['enabled'] as bool?) ?? false,
        maxDailyLossAmount = (json['maxDailyLossAmount'] as num?)?.toDouble(),
        maxDailyLossPercent =
            (json['maxDailyLossPercent'] as num?)?.toDouble() ?? 3.0,
        maxDrawdownPercent =
            (json['maxDrawdownPercent'] as num?)?.toDouble() ?? 10.0,
        maxConsecutiveLosses =
            (json['maxConsecutiveLosses'] as num?)?.toInt() ?? 3,
        minMarginBufferPercent =
            (json['minMarginBufferPercent'] as num?)?.toDouble() ?? 15.0,
        coolingOffDurationMinutes =
            (json['coolingOffDurationMinutes'] as num?)?.toInt() ?? 60,
        coolingOffUntil = json['coolingOffUntil'] != null
            ? (json['coolingOffUntil'] is Timestamp
                ? (json['coolingOffUntil'] as Timestamp).toDate()
                : DateTime.tryParse(json['coolingOffUntil'].toString()))
            : null,
        isTripped = (json['isTripped'] as bool?) ?? false,
        tripReason = json['tripReason'] as String?,
        trippedAt = json['trippedAt'] != null
            ? (json['trippedAt'] is Timestamp
                ? (json['trippedAt'] as Timestamp).toDate()
                : DateTime.tryParse(json['trippedAt'].toString()))
            : null,
        peakPortfolioEquity = (json['peakPortfolioEquity'] as num?)?.toDouble(),
        currentConsecutiveLosses =
            (json['currentConsecutiveLosses'] as num?)?.toInt() ?? 0,
        lastTradeDate = json['lastTradeDate'] != null
            ? (json['lastTradeDate'] is Timestamp
                ? (json['lastTradeDate'] as Timestamp).toDate()
                : DateTime.tryParse(json['lastTradeDate'].toString()))
            : null;

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'maxDailyLossAmount': maxDailyLossAmount,
      'maxDailyLossPercent': maxDailyLossPercent,
      'maxDrawdownPercent': maxDrawdownPercent,
      'maxConsecutiveLosses': maxConsecutiveLosses,
      'minMarginBufferPercent': minMarginBufferPercent,
      'coolingOffDurationMinutes': coolingOffDurationMinutes,
      'coolingOffUntil': coolingOffUntil?.toIso8601String(),
      'isTripped': isTripped,
      'tripReason': tripReason,
      'trippedAt': trippedAt?.toIso8601String(),
      'peakPortfolioEquity': peakPortfolioEquity,
      'currentConsecutiveLosses': currentConsecutiveLosses,
      'lastTradeDate': lastTradeDate?.toIso8601String(),
    };
  }

  RiskCircuitBreakerConfig copyWith({
    bool? enabled,
    double? maxDailyLossAmount,
    double? maxDailyLossPercent,
    double? maxDrawdownPercent,
    int? maxConsecutiveLosses,
    double? minMarginBufferPercent,
    int? coolingOffDurationMinutes,
    DateTime? coolingOffUntil,
    bool? isTripped,
    String? tripReason,
    DateTime? trippedAt,
    double? peakPortfolioEquity,
    int? currentConsecutiveLosses,
    DateTime? lastTradeDate,
  }) {
    return RiskCircuitBreakerConfig(
      enabled: enabled ?? this.enabled,
      maxDailyLossAmount: maxDailyLossAmount ?? this.maxDailyLossAmount,
      maxDailyLossPercent: maxDailyLossPercent ?? this.maxDailyLossPercent,
      maxDrawdownPercent: maxDrawdownPercent ?? this.maxDrawdownPercent,
      maxConsecutiveLosses: maxConsecutiveLosses ?? this.maxConsecutiveLosses,
      minMarginBufferPercent:
          minMarginBufferPercent ?? this.minMarginBufferPercent,
      coolingOffDurationMinutes:
          coolingOffDurationMinutes ?? this.coolingOffDurationMinutes,
      coolingOffUntil: coolingOffUntil ?? this.coolingOffUntil,
      isTripped: isTripped ?? this.isTripped,
      tripReason: tripReason ?? this.tripReason,
      trippedAt: trippedAt ?? this.trippedAt,
      peakPortfolioEquity: peakPortfolioEquity ?? this.peakPortfolioEquity,
      currentConsecutiveLosses:
          currentConsecutiveLosses ?? this.currentConsecutiveLosses,
      lastTradeDate: lastTradeDate ?? this.lastTradeDate,
    );
  }
}

/// Evaluation result returned by the Risk Circuit Breaker guardrails before order placement
class RiskEvaluationResult {
  final bool allowed;
  final String? reason;
  final bool isCoolingOff;
  final Duration? remainingCoolingOff;
  final String? triggerType;

  const RiskEvaluationResult({
    required this.allowed,
    this.reason,
    this.isCoolingOff = false,
    this.remainingCoolingOff,
    this.triggerType,
  });

  static const RiskEvaluationResult ok = RiskEvaluationResult(allowed: true);
}
