import 'package:flutter/material.dart';

/// Standard time horizon tenors (in calendar/trading days) for volatility evaluation.
enum VolatilityTenor {
  d10(10, '10D'),
  d20(20, '20D'),
  d30(30, '30D'),
  d60(60, '60D'),
  d90(90, '90D'),
  d180(180, '180D'),
  d252(252, '1Y');

  final int days;
  final String label;
  const VolatilityTenor(this.days, this.label);

  static VolatilityTenor? fromDays(int days) {
    for (final tenor in values) {
      if (tenor.days == days) return tenor;
    }
    return null;
  }
}

/// A single tenor point on the Volatility Cone showing historical Realized Volatility
/// distribution (Min, 25%, Median, 75%, Max) alongside Current RV and Current IV.
class VolatilityConePoint {
  final int days;
  final String label;
  final double minRv;
  final double p25Rv;
  final double medianRv;
  final double p75Rv;
  final double maxRv;
  final double currentRv;
  final double? currentIv;

  const VolatilityConePoint({
    required this.days,
    required this.label,
    required this.minRv,
    required this.p25Rv,
    required this.medianRv,
    required this.p75Rv,
    required this.maxRv,
    required this.currentRv,
    this.currentIv,
  });

  /// Whether current IV is in the upper quartile of historical realized volatility.
  bool get isIvExpensive => currentIv != null && currentIv! >= p75Rv;

  /// Whether current IV is in the lower quartile of historical realized volatility.
  bool get isIvCheap => currentIv != null && currentIv! <= p25Rv;

  /// Volatility Risk Premium for this specific tenor: IV - RV.
  double? get vrp => currentIv != null ? currentIv! - currentRv : null;

  Map<String, dynamic> toJson() => {
        'days': days,
        'label': label,
        'min_rv': minRv,
        'p25_rv': p25Rv,
        'median_rv': medianRv,
        'p75_rv': p75Rv,
        'max_rv': maxRv,
        'current_rv': currentRv,
        'current_iv': currentIv,
      };

  factory VolatilityConePoint.fromJson(Map<String, dynamic> json) {
    return VolatilityConePoint(
      days: json['days'] as int? ?? 30,
      label: json['label'] as String? ?? '30D',
      minRv: (json['min_rv'] as num?)?.toDouble() ?? 0.0,
      p25Rv: (json['p25_rv'] as num?)?.toDouble() ?? 0.0,
      medianRv: (json['median_rv'] as num?)?.toDouble() ?? 0.0,
      p75Rv: (json['p75_rv'] as num?)?.toDouble() ?? 0.0,
      maxRv: (json['max_rv'] as num?)?.toDouble() ?? 0.0,
      currentRv: (json['current_rv'] as num?)?.toDouble() ?? 0.0,
      currentIv: (json['current_iv'] as num?)?.toDouble(),
    );
  }
}

/// Multi-timeframe Implied Volatility metrics (IV Rank and IV Percentile) over a given lookback.
class IvRankPercentileMetrics {
  final int tenorDays;
  final String label;
  final double currentIv;
  final double ivRank; // 0.0 - 100.0%
  final double ivPercentile; // 0.0 - 100.0%
  final double high52Week;
  final double low52Week;

  const IvRankPercentileMetrics({
    required this.tenorDays,
    required this.label,
    required this.currentIv,
    required this.ivRank,
    required this.ivPercentile,
    required this.high52Week,
    required this.low52Week,
  });

  Map<String, dynamic> toJson() => {
        'tenor_days': tenorDays,
        'label': label,
        'current_iv': currentIv,
        'iv_rank': ivRank,
        'iv_percentile': ivPercentile,
        'high_52_week': high52Week,
        'low_52_week': low52Week,
      };

  factory IvRankPercentileMetrics.fromJson(Map<String, dynamic> json) {
    return IvRankPercentileMetrics(
      tenorDays: json['tenor_days'] as int? ?? 30,
      label: json['label'] as String? ?? '30D',
      currentIv: (json['current_iv'] as num?)?.toDouble() ?? 0.0,
      ivRank: (json['iv_rank'] as num?)?.toDouble() ?? 0.0,
      ivPercentile: (json['iv_percentile'] as num?)?.toDouble() ?? 0.0,
      high52Week: (json['high_52_week'] as num?)?.toDouble() ?? 0.0,
      low52Week: (json['low_52_week'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Represents an individual strike point along the volatility skew / smile curve.
class VolatilitySkewPoint {
  final double strike;
  final double moneyness; // strike / spotPrice
  final double? delta;
  final double? callIv;
  final double? putIv;
  final double blendedIv;
  final String optionType; // 'call', 'put', 'atm'

  const VolatilitySkewPoint({
    required this.strike,
    required this.moneyness,
    this.delta,
    this.callIv,
    this.putIv,
    required this.blendedIv,
    required this.optionType,
  });

  Map<String, dynamic> toJson() => {
        'strike': strike,
        'moneyness': moneyness,
        'delta': delta,
        'call_iv': callIv,
        'put_iv': putIv,
        'blended_iv': blendedIv,
        'option_type': optionType,
      };

  factory VolatilitySkewPoint.fromJson(Map<String, dynamic> json) {
    return VolatilitySkewPoint(
      strike: (json['strike'] as num?)?.toDouble() ?? 0.0,
      moneyness: (json['moneyness'] as num?)?.toDouble() ?? 1.0,
      delta: (json['delta'] as num?)?.toDouble(),
      callIv: (json['call_iv'] as num?)?.toDouble(),
      putIv: (json['put_iv'] as num?)?.toDouble(),
      blendedIv: (json['blended_iv'] as num?)?.toDouble() ?? 0.0,
      optionType: json['option_type'] as String? ?? 'atm',
    );
  }
}

/// Volatility Skew Regime classification.
enum VolatilitySkewRegime {
  steepPutSkew,
  balancedSmile,
  callSkewSqueeze,
  flat,
}

extension VolatilitySkewRegimeX on VolatilitySkewRegime {
  String get label {
    switch (this) {
      case VolatilitySkewRegime.steepPutSkew:
        return 'Steep Put Skew';
      case VolatilitySkewRegime.balancedSmile:
        return 'Balanced Smile';
      case VolatilitySkewRegime.callSkewSqueeze:
        return 'Call Skew / Squeeze';
      case VolatilitySkewRegime.flat:
        return 'Flat Volatility Skew';
    }
  }

  String get description {
    switch (this) {
      case VolatilitySkewRegime.steepPutSkew:
        return 'High institutional demand for downside put protection. OTM puts trade at a steep premium to calls (25Δ Risk Reversal is high).';
      case VolatilitySkewRegime.balancedSmile:
        return 'Symmetric pricing around ATM strikes. Normal volatility smile with balanced tail hedging.';
      case VolatilitySkewRegime.callSkewSqueeze:
        return 'OTM call IV exceeds put IV, signaling aggressive retail call buying or upside squeeze positioning.';
      case VolatilitySkewRegime.flat:
        return 'Minimal variation in implied volatility across strikes.';
    }
  }

  Color color(BuildContext context) {
    switch (this) {
      case VolatilitySkewRegime.steepPutSkew:
        return Colors.orange.shade800;
      case VolatilitySkewRegime.balancedSmile:
        return Colors.blue.shade600;
      case VolatilitySkewRegime.callSkewSqueeze:
        return Colors.green.shade600;
      case VolatilitySkewRegime.flat:
        return Theme.of(context).colorScheme.outline;
    }
  }
}

/// Complete Volatility Skew Surface analysis for the active expiration.
class VolatilitySkewAnalysis {
  final DateTime expirationDate;
  final int daysToExpiration;
  final double atmIv;
  final double putSkew25Delta; // IV(25Δ Put) - ATM IV
  final double callSkew25Delta; // IV(25Δ Call) - ATM IV
  final double riskReversal25Delta; // IV(25Δ Put) - IV(25Δ Call)
  final VolatilitySkewRegime skewRegime;
  final List<VolatilitySkewPoint> points;

  const VolatilitySkewAnalysis({
    required this.expirationDate,
    required this.daysToExpiration,
    required this.atmIv,
    required this.putSkew25Delta,
    required this.callSkew25Delta,
    required this.riskReversal25Delta,
    required this.skewRegime,
    required this.points,
  });

  Map<String, dynamic> toJson() => {
        'expiration_date': expirationDate.toIso8601String(),
        'days_to_expiration': daysToExpiration,
        'atm_iv': atmIv,
        'put_skew_25_delta': putSkew25Delta,
        'call_skew_25_delta': callSkew25Delta,
        'risk_reversal_25_delta': riskReversal25Delta,
        'skew_regime': skewRegime.name,
        'points': points.map((p) => p.toJson()).toList(),
      };

  factory VolatilitySkewAnalysis.fromJson(Map<String, dynamic> json) {
    return VolatilitySkewAnalysis(
      expirationDate:
          DateTime.tryParse(json['expiration_date'] as String? ?? '') ??
              DateTime.now(),
      daysToExpiration: json['days_to_expiration'] as int? ?? 30,
      atmIv: (json['atm_iv'] as num?)?.toDouble() ?? 0.0,
      putSkew25Delta: (json['put_skew_25_delta'] as num?)?.toDouble() ?? 0.0,
      callSkew25Delta: (json['call_skew_25_delta'] as num?)?.toDouble() ?? 0.0,
      riskReversal25Delta:
          (json['risk_reversal_25_delta'] as num?)?.toDouble() ?? 0.0,
      skewRegime: VolatilitySkewRegime.values.firstWhere(
        (r) => r.name == json['skew_regime'],
        orElse: () => VolatilitySkewRegime.balancedSmile,
      ),
      points: (json['points'] as List<dynamic>?)
              ?.map((p) =>
                  VolatilitySkewPoint.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Expiration tenor point for term structure curve.
class TermStructurePoint {
  final DateTime? expirationDate;
  final int dte;
  final double atmIv;

  const TermStructurePoint({
    this.expirationDate,
    required this.dte,
    required this.atmIv,
  });

  Map<String, dynamic> toJson() => {
        'expiration_date': expirationDate?.toIso8601String(),
        'dte': dte,
        'atm_iv': atmIv,
      };

  factory TermStructurePoint.fromJson(Map<String, dynamic> json) {
    return TermStructurePoint(
      expirationDate:
          DateTime.tryParse(json['expiration_date'] as String? ?? '') ??
              DateTime.now(),
      dte: json['dte'] as int? ?? 0,
      atmIv: (json['atm_iv'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Volatility Term Structure Regime.
enum TermStructureRegime {
  contango,
  backwardation,
  flat,
}

extension TermStructureRegimeX on TermStructureRegime {
  String get label {
    switch (this) {
      case TermStructureRegime.contango:
        return 'Contango (Normal)';
      case TermStructureRegime.backwardation:
        return 'Backwardation (Inverted)';
      case TermStructureRegime.flat:
        return 'Flat Term Structure';
    }
  }

  String get description {
    switch (this) {
      case TermStructureRegime.contango:
        return 'Longer-dated options trade at higher IV than front-month options. Typical calm, healthy market environment.';
      case TermStructureRegime.backwardation:
        return 'Front-month IV is sharply higher than back-month IV. Signals near-term event hazard, earnings, or panic hedging.';
      case TermStructureRegime.flat:
        return 'Implied volatility is uniform across near and distant expiration cycles.';
    }
  }

  Color color(BuildContext context) {
    switch (this) {
      case TermStructureRegime.contango:
        return Colors.green.shade700;
      case TermStructureRegime.backwardation:
        return Colors.red.shade700;
      case TermStructureRegime.flat:
        return Colors.blueGrey;
    }
  }
}

/// Complete Term Structure curve across available option expiries.
class VolatilityTermStructure {
  final List<TermStructurePoint> points;
  final TermStructureRegime regime;
  final double frontToBackSlope; // (Back IV - Front IV) / Days Delta

  const VolatilityTermStructure({
    required this.points,
    required this.regime,
    required this.frontToBackSlope,
  });

  Map<String, dynamic> toJson() => {
        'points': points.map((p) => p.toJson()).toList(),
        'regime': regime.name,
        'front_to_back_slope': frontToBackSlope,
      };

  factory VolatilityTermStructure.fromJson(Map<String, dynamic> json) {
    return VolatilityTermStructure(
      points: (json['points'] as List<dynamic>?)
              ?.map(
                  (p) => TermStructurePoint.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      regime: TermStructureRegime.values.firstWhere(
        (r) => r.name == json['regime'],
        orElse: () => TermStructureRegime.contango,
      ),
      frontToBackSlope:
          (json['front_to_back_slope'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Volatility Risk Premium (VRP) metrics.
class VolatilityRiskPremium {
  final double vrp30d; // IV30 - RV30
  final double vrpRatio; // IV30 / RV30
  final bool isRich; // IV > RV
  final double historicalVrpAvg;

  const VolatilityRiskPremium({
    required this.vrp30d,
    required this.vrpRatio,
    required this.isRich,
    required this.historicalVrpAvg,
  });

  Map<String, dynamic> toJson() => {
        'vrp_30d': vrp30d,
        'vrp_ratio': vrpRatio,
        'is_rich': isRich,
        'historical_vrp_avg': historicalVrpAvg,
      };

  factory VolatilityRiskPremium.fromJson(Map<String, dynamic> json) {
    return VolatilityRiskPremium(
      vrp30d: (json['vrp_30d'] as num?)?.toDouble() ?? 0.0,
      vrpRatio: (json['vrp_ratio'] as num?)?.toDouble() ?? 1.0,
      isRich: json['is_rich'] as bool? ?? true,
      historicalVrpAvg:
          (json['historical_vrp_avg'] as num?)?.toDouble() ?? 0.03,
    );
  }
}

/// Overall Volatility Valuation Regime based on IV Rank, Percentile, and Cone location.
enum VolatilityRegime {
  cheap,
  fair,
  expensive,
  extreme,
}

extension VolatilityRegimeX on VolatilityRegime {
  String get label {
    switch (this) {
      case VolatilityRegime.cheap:
        return 'Cheap (Low Volatility)';
      case VolatilityRegime.fair:
        return 'Fair Value Volatility';
      case VolatilityRegime.expensive:
        return 'Expensive (High Volatility)';
      case VolatilityRegime.extreme:
        return 'Extreme Volatility Surge';
    }
  }

  String get shortLabel {
    switch (this) {
      case VolatilityRegime.cheap:
        return 'Cheap';
      case VolatilityRegime.fair:
        return 'Fair';
      case VolatilityRegime.expensive:
        return 'Expensive';
      case VolatilityRegime.extreme:
        return 'Extreme';
    }
  }

  String get guidance {
    switch (this) {
      case VolatilityRegime.cheap:
        return 'Options premiums are historically underpriced. Favors option buying strategies (Long Calls/Puts, Debit Spreads, Long Calendars).';
      case VolatilityRegime.fair:
        return 'Implied volatility aligns with median historical movement. Balanced edge for both directional spreads and defined risk selling.';
      case VolatilityRegime.expensive:
        return 'Options premiums are statistically overpriced. Strong statistical edge for premium sellers (Credit Spreads, Iron Condors, Covered Calls).';
      case VolatilityRegime.extreme:
        return 'IV is near 52-week highs and far above historical realized movement. High risk of volatility collapse / crush. Selling defined-risk premium recommended.';
    }
  }

  Color color(BuildContext context) {
    switch (this) {
      case VolatilityRegime.cheap:
        return Colors.green.shade600;
      case VolatilityRegime.fair:
        return Colors.blue.shade600;
      case VolatilityRegime.expensive:
        return Colors.orange.shade800;
      case VolatilityRegime.extreme:
        return Theme.of(context).colorScheme.error;
    }
  }

  IconData get icon {
    switch (this) {
      case VolatilityRegime.cheap:
        return Icons.arrow_downward_rounded;
      case VolatilityRegime.fair:
        return Icons.horizontal_rule_rounded;
      case VolatilityRegime.expensive:
        return Icons.arrow_upward_rounded;
      case VolatilityRegime.extreme:
        return Icons.warning_amber_rounded;
    }
  }
}

/// Actionable options strategy recommendation generated from Volatility Cone & Skew analysis.
class VolatilityTacticalRecommendation {
  final String title;
  final String
      strategyType; // 'Net Credit', 'Net Debit', 'Neutral / Range', 'Directional'
  final String description;
  final String rationale;
  final IconData icon;
  final bool isRecommended;

  const VolatilityTacticalRecommendation({
    required this.title,
    required this.strategyType,
    required this.description,
    required this.rationale,
    required this.icon,
    required this.isRecommended,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'strategy_type': strategyType,
        'description': description,
        'rationale': rationale,
        'is_recommended': isRecommended,
      };

  factory VolatilityTacticalRecommendation.fromJson(Map<String, dynamic> json) {
    return VolatilityTacticalRecommendation(
      title: json['title'] as String? ?? '',
      strategyType: json['strategy_type'] as String? ?? 'Neutral',
      description: json['description'] as String? ?? '',
      rationale: json['rationale'] as String? ?? '',
      icon: Icons.trending_up,
      isRecommended: json['is_recommended'] as bool? ?? false,
    );
  }
}

/// Pre-earnings IV crush warning indicators if earnings are imminent.
class PreEarningsCrushIndicator {
  final int daysToEarnings;
  final double currentIv;
  final double baselineIv;
  final double ivElevationPct; // (currentIv - baselineIv) / baselineIv
  final bool isCrushImminent;

  const PreEarningsCrushIndicator({
    required this.daysToEarnings,
    required this.currentIv,
    required this.baselineIv,
    required this.ivElevationPct,
    required this.isCrushImminent,
  });

  Map<String, dynamic> toJson() => {
        'days_to_earnings': daysToEarnings,
        'current_iv': currentIv,
        'baseline_iv': baselineIv,
        'iv_elevation_pct': ivElevationPct,
        'is_crush_imminent': isCrushImminent,
      };

  factory PreEarningsCrushIndicator.fromJson(Map<String, dynamic> json) {
    return PreEarningsCrushIndicator(
      daysToEarnings: json['days_to_earnings'] as int? ?? 0,
      currentIv: (json['current_iv'] as num?)?.toDouble() ?? 0.0,
      baselineIv: (json['baseline_iv'] as num?)?.toDouble() ?? 0.0,
      ivElevationPct: (json['iv_elevation_pct'] as num?)?.toDouble() ?? 0.0,
      isCrushImminent: json['is_crush_imminent'] as bool? ?? false,
    );
  }
}

/// Comprehensive analysis aggregating the Volatility Cone, multi-timeframe IV metrics,
/// strike skew surface, term structure, and strategy playbook.
class VolatilityConeAnalysis {
  final String symbol;
  final double spotPrice;
  final List<VolatilityConePoint> conePoints;
  final IvRankPercentileMetrics metrics30d;
  final IvRankPercentileMetrics metrics60d;
  final IvRankPercentileMetrics metrics90d;
  final VolatilitySkewAnalysis? skewAnalysis;
  final VolatilityTermStructure? termStructure;
  final VolatilityRiskPremium vrp;
  final VolatilityRegime overallRegime;
  final List<VolatilityTacticalRecommendation> recommendations;
  final PreEarningsCrushIndicator? preEarningsIndicator;
  final DateTime calculatedAt;

  const VolatilityConeAnalysis({
    required this.symbol,
    required this.spotPrice,
    required this.conePoints,
    required this.metrics30d,
    required this.metrics60d,
    required this.metrics90d,
    this.skewAnalysis,
    this.termStructure,
    required this.vrp,
    required this.overallRegime,
    required this.recommendations,
    this.preEarningsIndicator,
    required this.calculatedAt,
  });

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'spot_price': spotPrice,
        'cone_points': conePoints.map((p) => p.toJson()).toList(),
        'metrics_30d': metrics30d.toJson(),
        'metrics_60d': metrics60d.toJson(),
        'metrics_90d': metrics90d.toJson(),
        'skew_analysis': skewAnalysis?.toJson(),
        'term_structure': termStructure?.toJson(),
        'vrp': vrp.toJson(),
        'overall_regime': overallRegime.name,
        'recommendations': recommendations.map((r) => r.toJson()).toList(),
        'pre_earnings_indicator': preEarningsIndicator?.toJson(),
        'calculated_at': calculatedAt.toIso8601String(),
      };

  factory VolatilityConeAnalysis.fromJson(Map<String, dynamic> json) {
    return VolatilityConeAnalysis(
      symbol: json['symbol'] as String? ?? '',
      spotPrice: (json['spot_price'] as num?)?.toDouble() ?? 0.0,
      conePoints: (json['cone_points'] as List<dynamic>?)
              ?.map((p) =>
                  VolatilityConePoint.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      metrics30d: IvRankPercentileMetrics.fromJson(
          json['metrics_30d'] as Map<String, dynamic>? ?? {}),
      metrics60d: IvRankPercentileMetrics.fromJson(
          json['metrics_60d'] as Map<String, dynamic>? ?? {}),
      metrics90d: IvRankPercentileMetrics.fromJson(
          json['metrics_90d'] as Map<String, dynamic>? ?? {}),
      skewAnalysis: json['skew_analysis'] != null
          ? VolatilitySkewAnalysis.fromJson(
              json['skew_analysis'] as Map<String, dynamic>)
          : null,
      termStructure: json['term_structure'] != null
          ? VolatilityTermStructure.fromJson(
              json['term_structure'] as Map<String, dynamic>)
          : null,
      vrp: VolatilityRiskPremium.fromJson(
          json['vrp'] as Map<String, dynamic>? ?? {}),
      overallRegime: VolatilityRegime.values.firstWhere(
        (r) => r.name == json['overall_regime'],
        orElse: () => VolatilityRegime.fair,
      ),
      recommendations: (json['recommendations'] as List<dynamic>?)
              ?.map((r) => VolatilityTacticalRecommendation.fromJson(
                  r as Map<String, dynamic>))
              .toList() ??
          [],
      preEarningsIndicator: json['pre_earnings_indicator'] != null
          ? PreEarningsCrushIndicator.fromJson(
              json['pre_earnings_indicator'] as Map<String, dynamic>)
          : null,
      calculatedAt: DateTime.tryParse(json['calculated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
