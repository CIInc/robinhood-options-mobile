import 'package:flutter/material.dart';

/// Performance vs consensus expectations for a reported quarter.
enum EarningsBeatMiss {
  beat,
  miss,
  inline,
}

extension EarningsBeatMissX on EarningsBeatMiss {
  String get label {
    switch (this) {
      case EarningsBeatMiss.beat:
        return 'Beat';
      case EarningsBeatMiss.miss:
        return 'Miss';
      case EarningsBeatMiss.inline:
        return 'In-Line';
    }
  }

  Color color(BuildContext context) {
    switch (this) {
      case EarningsBeatMiss.beat:
        return Colors.green;
      case EarningsBeatMiss.miss:
        return Theme.of(context).colorScheme.error;
      case EarningsBeatMiss.inline:
        return Colors.amber.shade700;
    }
  }
}

/// Categorization of how severe the IV crush is anticipated to be.
enum EarningsIvCrushRiskTier {
  low,
  moderate,
  high,
  extreme,
}

extension EarningsIvCrushRiskTierX on EarningsIvCrushRiskTier {
  String get label {
    switch (this) {
      case EarningsIvCrushRiskTier.low:
        return 'Low Crush Risk';
      case EarningsIvCrushRiskTier.moderate:
        return 'Moderate IV Crush';
      case EarningsIvCrushRiskTier.high:
        return 'High IV Crush';
      case EarningsIvCrushRiskTier.extreme:
        return 'Extreme IV Crush Imminent';
    }
  }

  String get shortLabel {
    switch (this) {
      case EarningsIvCrushRiskTier.low:
        return 'Low';
      case EarningsIvCrushRiskTier.moderate:
        return 'Moderate';
      case EarningsIvCrushRiskTier.high:
        return 'High';
      case EarningsIvCrushRiskTier.extreme:
        return 'Extreme';
    }
  }

  String get description {
    switch (this) {
      case EarningsIvCrushRiskTier.low:
        return 'Options implied volatility is near baseline historical levels. Post-earnings IV drop is projected to be mild (<30%).';
      case EarningsIvCrushRiskTier.moderate:
        return 'Moderate IV elevation ahead of earnings. Expect typical post-earnings IV contraction of 30%–45%.';
      case EarningsIvCrushRiskTier.high:
        return 'Significant IV run-up ahead of release. Expect steep post-announcement IV collapse of 45%–60%. Holding long unhedged options carries high volatility decay risk.';
      case EarningsIvCrushRiskTier.extreme:
        return 'Massive volatility premium priced in (>60% drop expected). Implied moves historically exceed actual results, favoring premium selling strategies.';
    }
  }

  Color color(BuildContext context) {
    switch (this) {
      case EarningsIvCrushRiskTier.low:
        return Colors.green;
      case EarningsIvCrushRiskTier.moderate:
        return Colors.amber.shade700;
      case EarningsIvCrushRiskTier.high:
        return Colors.deepOrange;
      case EarningsIvCrushRiskTier.extreme:
        return Theme.of(context).colorScheme.error;
    }
  }

  IconData get icon {
    switch (this) {
      case EarningsIvCrushRiskTier.low:
        return Icons.check_circle_outline_rounded;
      case EarningsIvCrushRiskTier.moderate:
        return Icons.info_outline_rounded;
      case EarningsIvCrushRiskTier.high:
        return Icons.warning_amber_rounded;
      case EarningsIvCrushRiskTier.extreme:
        return Icons.bolt_rounded;
    }
  }
}

/// Tactical recommendation for trading the earnings event based on the straddle pricing and historical distribution.
enum StraddleStrategyRecommendation {
  sellStraddleOrSpread,
  buyStraddleOrStrangle,
  neutralWait,
}

extension StraddleStrategyRecommendationX on StraddleStrategyRecommendation {
  String get label {
    switch (this) {
      case StraddleStrategyRecommendation.sellStraddleOrSpread:
        return 'Sell Premium / Iron Condor';
      case StraddleStrategyRecommendation.buyStraddleOrStrangle:
        return 'Buy Straddle / Long Volatility';
      case StraddleStrategyRecommendation.neutralWait:
        return 'Neutral / Directional Play';
    }
  }

  Color color(BuildContext context) {
    switch (this) {
      case StraddleStrategyRecommendation.sellStraddleOrSpread:
        return Colors.purple;
      case StraddleStrategyRecommendation.buyStraddleOrStrangle:
        return Colors.teal;
      case StraddleStrategyRecommendation.neutralWait:
        return Theme.of(context).colorScheme.primary;
    }
  }

  IconData get icon {
    switch (this) {
      case StraddleStrategyRecommendation.sellStraddleOrSpread:
        return Icons.compress_rounded;
      case StraddleStrategyRecommendation.buyStraddleOrStrangle:
        return Icons.expand_rounded;
      case StraddleStrategyRecommendation.neutralWait:
        return Icons.horizontal_rule_rounded;
    }
  }
}

/// A historical quarter report record comparing pre-earnings implied move vs actual move.
class EarningsQuarterRecord {
  final String quarterLabel;
  final DateTime reportDate;
  final double? epsEstimate;
  final double? epsActual;
  final double? epsSurprisePct;
  final double preEarningsIv; // e.g. 0.85 (85%)
  final double postEarningsIv; // e.g. 0.42 (42%)
  final double ivCrushPct; // e.g. 50.58% drop
  final double impliedMovePct; // e.g. 7.5%
  final double actualMovePct; // e.g. 3.8% (absolute magnitude)
  final double moveDirection; // e.g. +3.8% or -3.8% (signed)
  final bool impliedOverpriced; // true if impliedMovePct >= actualMovePct
  final EarningsBeatMiss beatMiss;

  const EarningsQuarterRecord({
    required this.quarterLabel,
    required this.reportDate,
    this.epsEstimate,
    this.epsActual,
    this.epsSurprisePct,
    required this.preEarningsIv,
    required this.postEarningsIv,
    required this.ivCrushPct,
    required this.impliedMovePct,
    required this.actualMovePct,
    required this.moveDirection,
    required this.impliedOverpriced,
    required this.beatMiss,
  });

  factory EarningsQuarterRecord.fromJson(Map<String, dynamic> json) {
    return EarningsQuarterRecord(
      quarterLabel: json['quarterLabel'] as String,
      reportDate: DateTime.parse(json['reportDate'] as String),
      epsEstimate: (json['epsEstimate'] as num?)?.toDouble(),
      epsActual: (json['epsActual'] as num?)?.toDouble(),
      epsSurprisePct: (json['epsSurprisePct'] as num?)?.toDouble(),
      preEarningsIv: (json['preEarningsIv'] as num).toDouble(),
      postEarningsIv: (json['postEarningsIv'] as num).toDouble(),
      ivCrushPct: (json['ivCrushPct'] as num).toDouble(),
      impliedMovePct: (json['impliedMovePct'] as num).toDouble(),
      actualMovePct: (json['actualMovePct'] as num).toDouble(),
      moveDirection: (json['moveDirection'] as num).toDouble(),
      impliedOverpriced: json['impliedOverpriced'] as bool? ?? false,
      beatMiss: EarningsBeatMiss.values.firstWhere(
        (e) => e.name == json['beatMiss'],
        orElse: () => EarningsBeatMiss.inline,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'quarterLabel': quarterLabel,
        'reportDate': reportDate.toIso8601String(),
        'epsEstimate': epsEstimate,
        'epsActual': epsActual,
        'epsSurprisePct': epsSurprisePct,
        'preEarningsIv': preEarningsIv,
        'postEarningsIv': postEarningsIv,
        'ivCrushPct': ivCrushPct,
        'impliedMovePct': impliedMovePct,
        'actualMovePct': actualMovePct,
        'moveDirection': moveDirection,
        'impliedOverpriced': impliedOverpriced,
        'beatMiss': beatMiss.name,
      };
}

/// Aggregate 12-quarter quantitative statistics for earnings move and IV crush.
class EarningsIvCrushSummary {
  final int quartersAnalyzed;
  final double averageImpliedMovePct;
  final double averageActualMovePct;
  final double impliedVsActualSpread; // averageImplied - averageActual
  final double overpricingRatePct; // % quarters where implied > actual
  final double averageIvCrushPct; // average % drop in IV
  final double crushProbabilityScore; // 0-100 score
  final EarningsIvCrushRiskTier riskTier;
  final double maxHistoricalMovePct;
  final double minHistoricalMovePct;
  final int upMovesCount;
  final int downMovesCount;

  const EarningsIvCrushSummary({
    required this.quartersAnalyzed,
    required this.averageImpliedMovePct,
    required this.averageActualMovePct,
    required this.impliedVsActualSpread,
    required this.overpricingRatePct,
    required this.averageIvCrushPct,
    required this.crushProbabilityScore,
    required this.riskTier,
    required this.maxHistoricalMovePct,
    required this.minHistoricalMovePct,
    required this.upMovesCount,
    required this.downMovesCount,
  });

  factory EarningsIvCrushSummary.fromJson(Map<String, dynamic> json) {
    return EarningsIvCrushSummary(
      quartersAnalyzed: json['quartersAnalyzed'] as int,
      averageImpliedMovePct: (json['averageImpliedMovePct'] as num).toDouble(),
      averageActualMovePct: (json['averageActualMovePct'] as num).toDouble(),
      impliedVsActualSpread: (json['impliedVsActualSpread'] as num).toDouble(),
      overpricingRatePct: (json['overpricingRatePct'] as num).toDouble(),
      averageIvCrushPct: (json['averageIvCrushPct'] as num).toDouble(),
      crushProbabilityScore: (json['crushProbabilityScore'] as num).toDouble(),
      riskTier: EarningsIvCrushRiskTier.values.firstWhere(
        (e) => e.name == json['riskTier'],
        orElse: () => EarningsIvCrushRiskTier.moderate,
      ),
      maxHistoricalMovePct: (json['maxHistoricalMovePct'] as num).toDouble(),
      minHistoricalMovePct: (json['minHistoricalMovePct'] as num).toDouble(),
      upMovesCount: json['upMovesCount'] as int? ?? 0,
      downMovesCount: json['downMovesCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'quartersAnalyzed': quartersAnalyzed,
        'averageImpliedMovePct': averageImpliedMovePct,
        'averageActualMovePct': averageActualMovePct,
        'impliedVsActualSpread': impliedVsActualSpread,
        'overpricingRatePct': overpricingRatePct,
        'averageIvCrushPct': averageIvCrushPct,
        'crushProbabilityScore': crushProbabilityScore,
        'riskTier': riskTier.name,
        'maxHistoricalMovePct': maxHistoricalMovePct,
        'minHistoricalMovePct': minHistoricalMovePct,
        'upMovesCount': upMovesCount,
        'downMovesCount': downMovesCount,
      };
}

/// Front-month At-The-Money (ATM) straddle pricing and expected value estimation.
class StraddlePricingEstimate {
  final double spotPrice;
  final double atmStrike;
  final double callPrice;
  final double putPrice;
  final double straddleCost;
  final double straddleCostPct; // (straddleCost / spotPrice) * 100
  final double impliedMovePct; // from ATM straddle
  final double upperBreakeven;
  final double lowerBreakeven;
  final double expectedPostEarningsIv;
  final double longStraddleEv; // dollar expected return for long straddle
  final double shortStraddleEv; // dollar expected return for short straddle
  final double sellerWinProbability; // % of quarters where move < implied
  final double buyerWinProbability; // % of quarters where move > implied
  final StraddleStrategyRecommendation recommendedStrategy;
  final String recommendationReason;

  const StraddlePricingEstimate({
    required this.spotPrice,
    required this.atmStrike,
    required this.callPrice,
    required this.putPrice,
    required this.straddleCost,
    required this.straddleCostPct,
    required this.impliedMovePct,
    required this.upperBreakeven,
    required this.lowerBreakeven,
    required this.expectedPostEarningsIv,
    required this.longStraddleEv,
    required this.shortStraddleEv,
    required this.sellerWinProbability,
    required this.buyerWinProbability,
    required this.recommendedStrategy,
    required this.recommendationReason,
  });

  factory StraddlePricingEstimate.fromJson(Map<String, dynamic> json) {
    return StraddlePricingEstimate(
      spotPrice: (json['spotPrice'] as num).toDouble(),
      atmStrike: (json['atmStrike'] as num).toDouble(),
      callPrice: (json['callPrice'] as num).toDouble(),
      putPrice: (json['putPrice'] as num).toDouble(),
      straddleCost: (json['straddleCost'] as num).toDouble(),
      straddleCostPct: (json['straddleCostPct'] as num).toDouble(),
      impliedMovePct: (json['impliedMovePct'] as num).toDouble(),
      upperBreakeven: (json['upperBreakeven'] as num).toDouble(),
      lowerBreakeven: (json['lowerBreakeven'] as num).toDouble(),
      expectedPostEarningsIv:
          (json['expectedPostEarningsIv'] as num).toDouble(),
      longStraddleEv: (json['longStraddleEv'] as num).toDouble(),
      shortStraddleEv: (json['shortStraddleEv'] as num).toDouble(),
      sellerWinProbability: (json['sellerWinProbability'] as num).toDouble(),
      buyerWinProbability: (json['buyerWinProbability'] as num).toDouble(),
      recommendedStrategy: StraddleStrategyRecommendation.values.firstWhere(
        (e) => e.name == json['recommendedStrategy'],
        orElse: () => StraddleStrategyRecommendation.sellStraddleOrSpread,
      ),
      recommendationReason: json['recommendationReason'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'spotPrice': spotPrice,
        'atmStrike': atmStrike,
        'callPrice': callPrice,
        'putPrice': putPrice,
        'straddleCost': straddleCost,
        'straddleCostPct': straddleCostPct,
        'impliedMovePct': impliedMovePct,
        'upperBreakeven': upperBreakeven,
        'lowerBreakeven': lowerBreakeven,
        'expectedPostEarningsIv': expectedPostEarningsIv,
        'longStraddleEv': longStraddleEv,
        'shortStraddleEv': shortStraddleEv,
        'sellerWinProbability': sellerWinProbability,
        'buyerWinProbability': buyerWinProbability,
        'recommendedStrategy': recommendedStrategy.name,
        'recommendationReason': recommendationReason,
      };
}

/// Comprehensive analysis object containing 12-quarter history, summary metrics, and straddle estimation.
class EarningsIvCrushAnalysis {
  final String symbol;
  final double spotPrice;
  final DateTime? nextEarningsDate;
  final int? daysToEarnings;
  final double currentIv;
  final double postEarningsEstimatedIv;
  final EarningsIvCrushSummary summary;
  final List<EarningsQuarterRecord> quarters;
  final StraddlePricingEstimate? straddleEstimate;
  final DateTime updatedAt;

  const EarningsIvCrushAnalysis({
    required this.symbol,
    required this.spotPrice,
    this.nextEarningsDate,
    this.daysToEarnings,
    required this.currentIv,
    required this.postEarningsEstimatedIv,
    required this.summary,
    required this.quarters,
    this.straddleEstimate,
    required this.updatedAt,
  });

  factory EarningsIvCrushAnalysis.fromJson(Map<String, dynamic> json) {
    return EarningsIvCrushAnalysis(
      symbol: json['symbol'] as String,
      spotPrice: (json['spotPrice'] as num).toDouble(),
      nextEarningsDate: json['nextEarningsDate'] != null
          ? DateTime.parse(json['nextEarningsDate'] as String)
          : null,
      daysToEarnings: json['daysToEarnings'] as int?,
      currentIv: (json['currentIv'] as num).toDouble(),
      postEarningsEstimatedIv:
          (json['postEarningsEstimatedIv'] as num).toDouble(),
      summary: EarningsIvCrushSummary.fromJson(
          json['summary'] as Map<String, dynamic>),
      quarters: (json['quarters'] as List<dynamic>)
          .map((e) => EarningsQuarterRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
      straddleEstimate: json['straddleEstimate'] != null
          ? StraddlePricingEstimate.fromJson(
              json['straddleEstimate'] as Map<String, dynamic>)
          : null,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'spotPrice': spotPrice,
        'nextEarningsDate': nextEarningsDate?.toIso8601String(),
        'daysToEarnings': daysToEarnings,
        'currentIv': currentIv,
        'postEarningsEstimatedIv': postEarningsEstimatedIv,
        'summary': summary.toJson(),
        'quarters': quarters.map((e) => e.toJson()).toList(),
        'straddleEstimate': straddleEstimate?.toJson(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}
