import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/delta_neutral_model.dart';

/// Severity level of a risk vector or overall copilot status.
enum RiskCopilotSeverity {
  normal,
  elevated,
  high,
  critical,
}

extension RiskCopilotSeverityExtension on RiskCopilotSeverity {
  String get label {
    switch (this) {
      case RiskCopilotSeverity.normal:
        return 'Normal';
      case RiskCopilotSeverity.elevated:
        return 'Elevated';
      case RiskCopilotSeverity.high:
        return 'High';
      case RiskCopilotSeverity.critical:
        return 'Critical';
    }
  }

  Color color(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (this) {
      case RiskCopilotSeverity.normal:
        return Colors.green;
      case RiskCopilotSeverity.elevated:
        return Colors.amber.shade700;
      case RiskCopilotSeverity.high:
        return Colors.orange.shade800;
      case RiskCopilotSeverity.critical:
        return scheme.error;
    }
  }
}

/// Hazard category for earnings events.
enum EarningsHazardType {
  ivCrush,
  gammaTailRisk,
  earningsGap,
}

extension EarningsHazardTypeExtension on EarningsHazardType {
  String get label {
    switch (this) {
      case EarningsHazardType.ivCrush:
        return 'IV Crush Hazard';
      case EarningsHazardType.gammaTailRisk:
        return 'Gamma Tail Risk';
      case EarningsHazardType.earningsGap:
        return 'Earnings Gap Risk';
    }
  }
}

/// Assessment of overnight and weekend gap risk for a specific position.
class GapRiskAssessment {
  final String symbol;
  final double notionalValue;
  final double beta;
  final double estimatedGapPercent;
  final double potentialDollarLoss;
  final bool isLeveragedOrVolatile;
  final bool hasShortOptionRisk;
  final RiskCopilotSeverity severity;
  final String warningMessage;
  final String mitigationAction;

  const GapRiskAssessment({
    required this.symbol,
    required this.notionalValue,
    required this.beta,
    required this.estimatedGapPercent,
    required this.potentialDollarLoss,
    this.isLeveragedOrVolatile = false,
    this.hasShortOptionRisk = false,
    required this.severity,
    required this.warningMessage,
    required this.mitigationAction,
  });

  factory GapRiskAssessment.fromJson(Map<String, dynamic> json) {
    return GapRiskAssessment(
      symbol: json['symbol'] as String? ?? '',
      notionalValue: (json['notional_value'] as num?)?.toDouble() ?? 0.0,
      beta: (json['beta'] as num?)?.toDouble() ?? 1.0,
      estimatedGapPercent:
          (json['estimated_gap_percent'] as num?)?.toDouble() ?? 0.0,
      potentialDollarLoss:
          (json['potential_dollar_loss'] as num?)?.toDouble() ?? 0.0,
      isLeveragedOrVolatile: json['is_leveraged_or_volatile'] as bool? ?? false,
      hasShortOptionRisk: json['has_short_option_risk'] as bool? ?? false,
      severity: RiskCopilotSeverity.values.firstWhere(
        (e) => e.name == json['severity'],
        orElse: () => RiskCopilotSeverity.normal,
      ),
      warningMessage: json['warning_message'] as String? ?? '',
      mitigationAction: json['mitigation_action'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'notional_value': notionalValue,
      'beta': beta,
      'estimated_gap_percent': estimatedGapPercent,
      'potential_dollar_loss': potentialDollarLoss,
      'is_leveraged_or_volatile': isLeveragedOrVolatile,
      'has_short_option_risk': hasShortOptionRisk,
      'severity': severity.name,
      'warning_message': warningMessage,
      'mitigation_action': mitigationAction,
    };
  }
}

/// Assessment of upcoming earnings event hazards for held positions.
class EarningsHazardAssessment {
  final String symbol;
  final DateTime earningsDate;
  final int daysUntilEarnings;
  final double sharesCount;
  final int optionsCount;
  final bool isLongOptionHolding;
  final bool isShortOptionHolding;
  final double expectedMovePercent;
  final double crushProbability;
  final EarningsHazardType hazardType;
  final RiskCopilotSeverity severity;
  final String warningMessage;
  final String mitigationAction;

  const EarningsHazardAssessment({
    required this.symbol,
    required this.earningsDate,
    required this.daysUntilEarnings,
    this.sharesCount = 0.0,
    this.optionsCount = 0,
    this.isLongOptionHolding = false,
    this.isShortOptionHolding = false,
    required this.expectedMovePercent,
    required this.crushProbability,
    required this.hazardType,
    required this.severity,
    required this.warningMessage,
    required this.mitigationAction,
  });

  factory EarningsHazardAssessment.fromJson(Map<String, dynamic> json) {
    return EarningsHazardAssessment(
      symbol: json['symbol'] as String? ?? '',
      earningsDate: json['earnings_date'] != null
          ? DateTime.tryParse(json['earnings_date'] as String) ??
              DateTime.now()
          : DateTime.now(),
      daysUntilEarnings: json['days_until_earnings'] as int? ?? 0,
      sharesCount: (json['shares_count'] as num?)?.toDouble() ?? 0.0,
      optionsCount: json['options_count'] as int? ?? 0,
      isLongOptionHolding: json['is_long_option_holding'] as bool? ?? false,
      isShortOptionHolding: json['is_short_option_holding'] as bool? ?? false,
      expectedMovePercent:
          (json['expected_move_percent'] as num?)?.toDouble() ?? 0.0,
      crushProbability: (json['crush_probability'] as num?)?.toDouble() ?? 0.0,
      hazardType: EarningsHazardType.values.firstWhere(
        (e) => e.name == json['hazard_type'],
        orElse: () => EarningsHazardType.ivCrush,
      ),
      severity: RiskCopilotSeverity.values.firstWhere(
        (e) => e.name == json['severity'],
        orElse: () => RiskCopilotSeverity.normal,
      ),
      warningMessage: json['warning_message'] as String? ?? '',
      mitigationAction: json['mitigation_action'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'earnings_date': earningsDate.toIso8601String(),
      'days_until_earnings': daysUntilEarnings,
      'shares_count': sharesCount,
      'options_count': optionsCount,
      'is_long_option_holding': isLongOptionHolding,
      'is_short_option_holding': isShortOptionHolding,
      'expected_move_percent': expectedMovePercent,
      'crush_probability': crushProbability,
      'hazard_type': hazardType.name,
      'severity': severity.name,
      'warning_message': warningMessage,
      'mitigation_action': mitigationAction,
    };
  }
}

/// Suggested delta hedge recommendation for a symbol or the entire portfolio.
class DeltaHedgeAssessment {
  final String symbol;
  final double netDelta;
  final double targetDelta;
  final double dollarDeltaPerOnePercent;
  final DeltaDriftStatus driftStatus;
  final double suggestedSharesHedge;
  final String suggestedOptionHedge;
  final String hedgeRationale;
  final RiskCopilotSeverity severity;
  final DeltaOffsetRecommendation? primaryShareHedge;
  final DeltaOffsetRecommendation? primaryOptionHedge;

  const DeltaHedgeAssessment({
    required this.symbol,
    required this.netDelta,
    this.targetDelta = 0.0,
    required this.dollarDeltaPerOnePercent,
    required this.driftStatus,
    required this.suggestedSharesHedge,
    required this.suggestedOptionHedge,
    required this.hedgeRationale,
    required this.severity,
    this.primaryShareHedge,
    this.primaryOptionHedge,
  });

  factory DeltaHedgeAssessment.fromJson(Map<String, dynamic> json) {
    return DeltaHedgeAssessment(
      symbol: json['symbol'] as String? ?? '',
      netDelta: (json['net_delta'] as num?)?.toDouble() ?? 0.0,
      targetDelta: (json['target_delta'] as num?)?.toDouble() ?? 0.0,
      dollarDeltaPerOnePercent:
          (json['dollar_delta_per_one_percent'] as num?)?.toDouble() ?? 0.0,
      driftStatus: DeltaDriftStatus.values.firstWhere(
        (e) => e.name == json['drift_status'],
        orElse: () => DeltaDriftStatus.neutral,
      ),
      suggestedSharesHedge:
          (json['suggested_shares_hedge'] as num?)?.toDouble() ?? 0.0,
      suggestedOptionHedge: json['suggested_option_hedge'] as String? ?? '',
      hedgeRationale: json['hedge_rationale'] as String? ?? '',
      severity: RiskCopilotSeverity.values.firstWhere(
        (e) => e.name == json['severity'],
        orElse: () => RiskCopilotSeverity.normal,
      ),
      primaryShareHedge: json['primary_share_hedge'] != null
          ? DeltaOffsetRecommendation.fromJson(
              json['primary_share_hedge'] as Map<String, dynamic>)
          : null,
      primaryOptionHedge: json['primary_option_hedge'] != null
          ? DeltaOffsetRecommendation.fromJson(
              json['primary_option_hedge'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'net_delta': netDelta,
      'target_delta': targetDelta,
      'dollar_delta_per_one_percent': dollarDeltaPerOnePercent,
      'drift_status': driftStatus.name,
      'suggested_shares_hedge': suggestedSharesHedge,
      'suggested_option_hedge': suggestedOptionHedge,
      'hedge_rationale': hedgeRationale,
      'severity': severity.name,
      'primary_share_hedge': primaryShareHedge?.toJson(),
      'primary_option_hedge': primaryOptionHedge?.toJson(),
    };
  }
}

/// A specific, actionable mitigation recommendation produced by the Risk Copilot.
class RiskCopilotMitigationAction {
  final String id;
  final String symbol;
  final String title;
  final String description;
  final RiskCopilotSeverity severity;
  final String actionLabel;
  final String targetRoute; // 'delta_neutral', 'earnings_crush', 'options', 'instrument'

  const RiskCopilotMitigationAction({
    required this.id,
    required this.symbol,
    required this.title,
    required this.description,
    required this.severity,
    required this.actionLabel,
    required this.targetRoute,
  });

  factory RiskCopilotMitigationAction.fromJson(Map<String, dynamic> json) {
    return RiskCopilotMitigationAction(
      id: json['id'] as String? ?? '',
      symbol: json['symbol'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      severity: RiskCopilotSeverity.values.firstWhere(
        (e) => e.name == json['severity'],
        orElse: () => RiskCopilotSeverity.normal,
      ),
      actionLabel: json['action_label'] as String? ?? '',
      targetRoute: json['target_route'] as String? ?? 'instrument',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'symbol': symbol,
      'title': title,
      'description': description,
      'severity': severity.name,
      'action_label': actionLabel,
      'target_route': targetRoute,
    };
  }
}

/// Comprehensive analysis report generated by the Autonomous Agentic Risk Copilot.
class RiskCopilotReport {
  final DateTime generatedAt;
  final RiskCopilotSeverity overallSeverity;
  final double overallScore; // 0 (extreme hazard) to 100 (maximum safety)
  final String statusHeadline;
  final String summary;
  final List<GapRiskAssessment> gapRisks;
  final List<EarningsHazardAssessment> earningsHazards;
  final List<DeltaHedgeAssessment> deltaHedges;
  final List<RiskCopilotMitigationAction> topMitigations;
  final double totalOvernightGapExposure;
  final bool hasImminentEarnings;
  final double portfolioNetDelta;

  const RiskCopilotReport({
    required this.generatedAt,
    required this.overallSeverity,
    required this.overallScore,
    required this.statusHeadline,
    required this.summary,
    this.gapRisks = const [],
    this.earningsHazards = const [],
    this.deltaHedges = const [],
    this.topMitigations = const [],
    this.totalOvernightGapExposure = 0.0,
    this.hasImminentEarnings = false,
    this.portfolioNetDelta = 0.0,
  });

  factory RiskCopilotReport.fromJson(Map<String, dynamic> json) {
    return RiskCopilotReport(
      generatedAt: json['generated_at'] != null
          ? DateTime.tryParse(json['generated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      overallSeverity: RiskCopilotSeverity.values.firstWhere(
        (e) => e.name == json['overall_severity'],
        orElse: () => RiskCopilotSeverity.normal,
      ),
      overallScore: (json['overall_score'] as num?)?.toDouble() ?? 100.0,
      statusHeadline: json['status_headline'] as String? ?? 'Protected & Balanced',
      summary: json['summary'] as String? ?? '',
      gapRisks: (json['gap_risks'] as List<dynamic>?)
              ?.map((e) => GapRiskAssessment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      earningsHazards: (json['earnings_hazards'] as List<dynamic>?)
              ?.map((e) =>
                  EarningsHazardAssessment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      deltaHedges: (json['delta_hedges'] as List<dynamic>?)
              ?.map((e) =>
                  DeltaHedgeAssessment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      topMitigations: (json['top_mitigations'] as List<dynamic>?)
              ?.map((e) => RiskCopilotMitigationAction.fromJson(
                  e as Map<String, dynamic>))
              .toList() ??
          const [],
      totalOvernightGapExposure:
          (json['total_overnight_gap_exposure'] as num?)?.toDouble() ?? 0.0,
      hasImminentEarnings: json['has_imminent_earnings'] as bool? ?? false,
      portfolioNetDelta:
          (json['portfolio_net_delta'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'generated_at': generatedAt.toIso8601String(),
      'overall_severity': overallSeverity.name,
      'overall_score': overallScore,
      'status_headline': statusHeadline,
      'summary': summary,
      'gap_risks': gapRisks.map((e) => e.toJson()).toList(),
      'earnings_hazards': earningsHazards.map((e) => e.toJson()).toList(),
      'delta_hedges': deltaHedges.map((e) => e.toJson()).toList(),
      'top_mitigations': topMitigations.map((e) => e.toJson()).toList(),
      'total_overnight_gap_exposure': totalOvernightGapExposure,
      'has_imminent_earnings': hasImminentEarnings,
      'portfolio_net_delta': portfolioNetDelta,
    };
  }

  /// Whether the copilot identifies any elevated, high, or critical risks.
  bool get hasElevatedRisk => overallSeverity != RiskCopilotSeverity.normal;
}
