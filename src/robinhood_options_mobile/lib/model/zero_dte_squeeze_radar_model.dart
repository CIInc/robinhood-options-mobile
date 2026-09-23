import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/gamma_exposure_model.dart';

/// Risk classification for Gamma Squeeze likelihood.
enum GammaSqueezeRiskLevel {
  low,
  elevated,
  high,
  extreme,
}

extension GammaSqueezeRiskLevelX on GammaSqueezeRiskLevel {
  String get label {
    switch (this) {
      case GammaSqueezeRiskLevel.low:
        return 'Low Squeeze Risk';
      case GammaSqueezeRiskLevel.elevated:
        return 'Elevated Squeeze Activity';
      case GammaSqueezeRiskLevel.high:
        return 'High Squeeze Probability';
      case GammaSqueezeRiskLevel.extreme:
        return 'Critical Squeeze Imminent';
    }
  }

  String get shortLabel {
    switch (this) {
      case GammaSqueezeRiskLevel.low:
        return 'Low';
      case GammaSqueezeRiskLevel.elevated:
        return 'Elevated';
      case GammaSqueezeRiskLevel.high:
        return 'High';
      case GammaSqueezeRiskLevel.extreme:
        return 'Extreme';
    }
  }

  String get description {
    switch (this) {
      case GammaSqueezeRiskLevel.low:
        return 'Dealer positioning is stable with balanced flow or deep long gamma pinning. Rapid upside acceleration is unlikely.';
      case GammaSqueezeRiskLevel.elevated:
        return '0DTE call flow velocity is rising and spot is testing dealer thresholds. Watch for acceleration if resistance breaks.';
      case GammaSqueezeRiskLevel.high:
        return 'Aggressive 0DTE call sweep velocity combined with negative dealer gamma or flip proximity. Market makers forced to buy into rallies.';
      case GammaSqueezeRiskLevel.extreme:
        return 'Extreme call volume exceeding open interest, negative dealer gamma flip breach, and parabolic velocity. Cascading hedging feedback loop.';
    }
  }

  Color color(BuildContext context) {
    switch (this) {
      case GammaSqueezeRiskLevel.low:
        return Colors.green;
      case GammaSqueezeRiskLevel.elevated:
        return Colors.amber.shade700;
      case GammaSqueezeRiskLevel.high:
        return Colors.deepOrange;
      case GammaSqueezeRiskLevel.extreme:
        return Theme.of(context).colorScheme.error;
    }
  }

  IconData get icon {
    switch (this) {
      case GammaSqueezeRiskLevel.low:
        return Icons.check_circle_outline_rounded;
      case GammaSqueezeRiskLevel.elevated:
        return Icons.info_outline_rounded;
      case GammaSqueezeRiskLevel.high:
        return Icons.warning_amber_rounded;
      case GammaSqueezeRiskLevel.extreme:
        return Icons.bolt_rounded;
    }
  }

  bool get isActionable =>
      this == GammaSqueezeRiskLevel.high ||
      this == GammaSqueezeRiskLevel.extreme;
}

/// Aggregate metrics for 0DTE (same-day expiration) call and put flow.
class ZeroDteFlowSummary {
  final int totalCallVolume;
  final int totalPutVolume;
  final double totalCallPremium;
  final double totalPutPremium;
  final double callPutVolumeRatio; // 0.0 to 1.0 (calls / total)
  final double callPutPremiumRatio; // 0.0 to 1.0 (calls / total)
  final double callVelocity; // contracts per minute
  final double putVelocity;
  final double netVelocity; // callVelocity - putVelocity
  final int sweepCount;
  final double unusualVolumeOiRatio;

  const ZeroDteFlowSummary({
    required this.totalCallVolume,
    required this.totalPutVolume,
    required this.totalCallPremium,
    required this.totalPutPremium,
    required this.callPutVolumeRatio,
    required this.callPutPremiumRatio,
    required this.callVelocity,
    required this.putVelocity,
    required this.netVelocity,
    required this.sweepCount,
    required this.unusualVolumeOiRatio,
  });

  int get totalVolume => totalCallVolume + totalPutVolume;
  double get totalPremium => totalCallPremium + totalPutPremium;
  double get netCallPremium => totalCallPremium - totalPutPremium;

  factory ZeroDteFlowSummary.fromJson(Map<String, dynamic> json) =>
      ZeroDteFlowSummary(
        totalCallVolume: json['totalCallVolume'] as int? ?? 0,
        totalPutVolume: json['totalPutVolume'] as int? ?? 0,
        totalCallPremium: (json['totalCallPremium'] as num?)?.toDouble() ?? 0.0,
        totalPutPremium: (json['totalPutPremium'] as num?)?.toDouble() ?? 0.0,
        callPutVolumeRatio:
            (json['callPutVolumeRatio'] as num?)?.toDouble() ?? 0.5,
        callPutPremiumRatio:
            (json['callPutPremiumRatio'] as num?)?.toDouble() ?? 0.5,
        callVelocity: (json['callVelocity'] as num?)?.toDouble() ?? 0.0,
        putVelocity: (json['putVelocity'] as num?)?.toDouble() ?? 0.0,
        netVelocity: (json['netVelocity'] as num?)?.toDouble() ?? 0.0,
        sweepCount: json['sweepCount'] as int? ?? 0,
        unusualVolumeOiRatio:
            (json['unusualVolumeOiRatio'] as num?)?.toDouble() ?? 1.0,
      );

  Map<String, dynamic> toJson() => {
        'totalCallVolume': totalCallVolume,
        'totalPutVolume': totalPutVolume,
        'totalCallPremium': totalCallPremium,
        'totalPutPremium': totalPutPremium,
        'callPutVolumeRatio': callPutVolumeRatio,
        'callPutPremiumRatio': callPutPremiumRatio,
        'callVelocity': callVelocity,
        'putVelocity': putVelocity,
        'netVelocity': netVelocity,
        'sweepCount': sweepCount,
        'unusualVolumeOiRatio': unusualVolumeOiRatio,
      };
}

/// Proximity and velocity metrics relative to dealer gamma flip and key walls.
class DealerGammaFlipMetrics {
  final double spotPrice;
  final double? gammaFlip;
  final double? distanceToFlip; // spotPrice - gammaFlip
  final double? distanceToFlipPercent; // (spotPrice - gammaFlip) / spotPrice
  final double? callWall;
  final double? putWall;
  final DealerPositioning dealerPositioning;
  final double approachVelocity; // rate at which spot is closing in on flip
  final bool isNearFlip; // within 1.0% of flip
  final bool inShortGammaZone;

  const DealerGammaFlipMetrics({
    required this.spotPrice,
    this.gammaFlip,
    this.distanceToFlip,
    this.distanceToFlipPercent,
    this.callWall,
    this.putWall,
    required this.dealerPositioning,
    required this.approachVelocity,
    required this.isNearFlip,
    required this.inShortGammaZone,
  });

  factory DealerGammaFlipMetrics.fromJson(Map<String, dynamic> json) {
    DealerPositioning positioning;
    switch (json['dealerPositioning'] as String?) {
      case 'long_gamma':
        positioning = DealerPositioning.longGamma;
        break;
      case 'short_gamma':
        positioning = DealerPositioning.shortGamma;
        break;
      default:
        positioning = DealerPositioning.neutral;
    }

    return DealerGammaFlipMetrics(
      spotPrice: (json['spotPrice'] as num?)?.toDouble() ?? 0.0,
      gammaFlip: (json['gammaFlip'] as num?)?.toDouble(),
      distanceToFlip: (json['distanceToFlip'] as num?)?.toDouble(),
      distanceToFlipPercent:
          (json['distanceToFlipPercent'] as num?)?.toDouble(),
      callWall: (json['callWall'] as num?)?.toDouble(),
      putWall: (json['putWall'] as num?)?.toDouble(),
      dealerPositioning: positioning,
      approachVelocity: (json['approachVelocity'] as num?)?.toDouble() ?? 0.0,
      isNearFlip: json['isNearFlip'] as bool? ?? false,
      inShortGammaZone: json['inShortGammaZone'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'spotPrice': spotPrice,
        if (gammaFlip != null) 'gammaFlip': gammaFlip,
        if (distanceToFlip != null) 'distanceToFlip': distanceToFlip,
        if (distanceToFlipPercent != null)
          'distanceToFlipPercent': distanceToFlipPercent,
        if (callWall != null) 'callWall': callWall,
        if (putWall != null) 'putWall': putWall,
        'dealerPositioning': dealerPositioning == DealerPositioning.longGamma
            ? 'long_gamma'
            : dealerPositioning == DealerPositioning.shortGamma
                ? 'short_gamma'
                : 'neutral',
        'approachVelocity': approachVelocity,
        'isNearFlip': isNearFlip,
        'inShortGammaZone': inShortGammaZone,
      };
}

/// A specific contributing factor toward the overall squeeze probability score.
class SqueezeFactor {
  final String title;
  final String description;
  final double score; // contribution points
  final double maxScore; // maximum possible points for this factor
  final bool isTriggered;

  const SqueezeFactor({
    required this.title,
    required this.description,
    required this.score,
    required this.maxScore,
    required this.isTriggered,
  });

  double get ratio => maxScore > 0 ? (score / maxScore).clamp(0.0, 1.0) : 0.0;

  factory SqueezeFactor.fromJson(Map<String, dynamic> json) => SqueezeFactor(
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        score: (json['score'] as num?)?.toDouble() ?? 0.0,
        maxScore: (json['maxScore'] as num?)?.toDouble() ?? 25.0,
        isTriggered: json['isTriggered'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'score': score,
        'maxScore': maxScore,
        'isTriggered': isTriggered,
      };
}

/// Comprehensive analysis output for 0DTE flow and gamma squeeze likelihood.
class ZeroDteSqueezeRadarResult {
  final String symbol;
  final double spotPrice;
  final double squeezeProbability; // 0.0 to 100.0
  final GammaSqueezeRiskLevel riskLevel;
  final String summary;
  final ZeroDteFlowSummary flowSummary;
  final DealerGammaFlipMetrics flipMetrics;
  final List<SqueezeFactor> factors;
  final DateTime updatedAt;

  const ZeroDteSqueezeRadarResult({
    required this.symbol,
    required this.spotPrice,
    required this.squeezeProbability,
    required this.riskLevel,
    required this.summary,
    required this.flowSummary,
    required this.flipMetrics,
    required this.factors,
    required this.updatedAt,
  });

  factory ZeroDteSqueezeRadarResult.fromJson(Map<String, dynamic> json) {
    GammaSqueezeRiskLevel risk;
    switch (json['riskLevel'] as String?) {
      case 'extreme':
        risk = GammaSqueezeRiskLevel.extreme;
        break;
      case 'high':
        risk = GammaSqueezeRiskLevel.high;
        break;
      case 'elevated':
        risk = GammaSqueezeRiskLevel.elevated;
        break;
      default:
        risk = GammaSqueezeRiskLevel.low;
    }

    return ZeroDteSqueezeRadarResult(
      symbol: json['symbol'] as String? ?? '',
      spotPrice: (json['spotPrice'] as num?)?.toDouble() ?? 0.0,
      squeezeProbability:
          (json['squeezeProbability'] as num?)?.toDouble() ?? 0.0,
      riskLevel: risk,
      summary: json['summary'] as String? ?? '',
      flowSummary: ZeroDteFlowSummary.fromJson(
          Map<String, dynamic>.from(json['flowSummary'] as Map? ?? {})),
      flipMetrics: DealerGammaFlipMetrics.fromJson(
          Map<String, dynamic>.from(json['flipMetrics'] as Map? ?? {})),
      factors: (json['factors'] as List<dynamic>?)
              ?.map((e) =>
                  SqueezeFactor.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      updatedAt: json['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'spotPrice': spotPrice,
        'squeezeProbability': squeezeProbability,
        'riskLevel': riskLevel.name,
        'summary': summary,
        'flowSummary': flowSummary.toJson(),
        'flipMetrics': flipMetrics.toJson(),
        'factors': factors.map((e) => e.toJson()).toList(),
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };
}
