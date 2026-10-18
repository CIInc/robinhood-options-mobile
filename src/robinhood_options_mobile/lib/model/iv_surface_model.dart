import 'package:flutter/material.dart';

/// Single market observation or interpolated coordinate on an Implied Volatility Surface.
class IvSurfacePoint {
  final double strike;
  final int dte;
  final double moneyness; // K / Spot
  final double iv; // Annualized implied volatility (e.g. 0.35 = 35%)
  final String optionType; // 'call' or 'put'
  final double? delta;
  final double? bid;
  final double? ask;
  final int? volume;
  final int? openInterest;

  const IvSurfacePoint({
    required this.strike,
    required this.dte,
    required this.moneyness,
    required this.iv,
    this.optionType = 'call',
    this.delta,
    this.bid,
    this.ask,
    this.volume,
    this.openInterest,
  });

  Map<String, dynamic> toJson() => {
        'strike': strike,
        'dte': dte,
        'moneyness': moneyness,
        'iv': iv,
        'option_type': optionType,
        'delta': delta,
        'bid': bid,
        'ask': ask,
        'volume': volume,
        'open_interest': openInterest,
      };

  factory IvSurfacePoint.fromJson(Map<String, dynamic> json) {
    return IvSurfacePoint(
      strike: (json['strike'] as num?)?.toDouble() ?? 0.0,
      dte: json['dte'] as int? ?? 0,
      moneyness: (json['moneyness'] as num?)?.toDouble() ?? 1.0,
      iv: (json['iv'] as num?)?.toDouble() ?? 0.0,
      optionType: json['option_type'] as String? ?? 'call',
      delta: (json['delta'] as num?)?.toDouble(),
      bid: (json['bid'] as num?)?.toDouble(),
      ask: (json['ask'] as num?)?.toDouble(),
      volume: json['volume'] as int?,
      openInterest: json['open_interest'] as int?,
    );
  }
}

/// Regularized 2D matrix representing the 3D surface mesh over strikes/moneyness and DTEs.
class IvSurfaceGrid {
  final List<double> strikes;
  final List<double> moneynessValues;
  final List<int> dtes;

  /// ivMatrix[strikeIndex][dteIndex]
  final List<List<double>> ivMatrix;

  /// Local volatility matrix computed via Dupire formula: localVolMatrix[strikeIndex][dteIndex]
  final List<List<double>> localVolMatrix;

  const IvSurfaceGrid({
    required this.strikes,
    required this.moneynessValues,
    required this.dtes,
    required this.ivMatrix,
    required this.localVolMatrix,
  });

  int get strikeCount => strikes.length;
  int get dteCount => dtes.length;

  double getIv(int strikeIdx, int dteIdx) {
    if (strikeIdx < 0 || strikeIdx >= strikes.length) return 0.0;
    if (dteIdx < 0 || dteIdx >= dtes.length) return 0.0;
    return ivMatrix[strikeIdx][dteIdx];
  }

  double getLocalVol(int strikeIdx, int dteIdx) {
    if (strikeIdx < 0 || strikeIdx >= strikes.length) return 0.0;
    if (dteIdx < 0 || dteIdx >= dtes.length) return 0.0;
    return localVolMatrix[strikeIdx][dteIdx];
  }

  Map<String, dynamic> toJson() => {
        'strikes': strikes,
        'moneyness_values': moneynessValues,
        'dtes': dtes,
        'iv_matrix': ivMatrix,
        'local_vol_matrix': localVolMatrix,
      };

  factory IvSurfaceGrid.fromJson(Map<String, dynamic> json) {
    final strikesList = (json['strikes'] as List<dynamic>?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        [];
    final moneynessList = (json['moneyness_values'] as List<dynamic>?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        [];
    final dtesList =
        (json['dtes'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [];

    final ivMat = (json['iv_matrix'] as List<dynamic>?)
            ?.map((row) => (row as List<dynamic>)
                .map((e) => (e as num).toDouble())
                .toList())
            .toList() ??
        [];

    final localVolMat = (json['local_vol_matrix'] as List<dynamic>?)
            ?.map((row) => (row as List<dynamic>)
                .map((e) => (e as num).toDouble())
                .toList())
            .toList() ??
        [];

    return IvSurfaceGrid(
      strikes: strikesList,
      moneynessValues: moneynessList,
      dtes: dtesList,
      ivMatrix: ivMat,
      localVolMatrix: localVolMat,
    );
  }
}

/// Type of 2D cross-sectional slice across the 3D surface.
enum SliceType { smileByDte, termStructureByMoneyness }

/// 2D cross-section slice (e.g. Volatility Smile across strikes for a given DTE,
/// or Term Structure across DTEs for a given moneyness).
class IvSurfaceSlice {
  final SliceType sliceType;
  final double paramValue; // DTE for smile, moneyness for term structure
  final String
      paramLabel; // e.g. '30 DTE', 'ATM (1.00x)', '10% OTM Put (0.90x)'
  final List<double> xValues; // Strike prices or DTE days
  final List<String> xLabels;
  final List<double> ivValues;

  const IvSurfaceSlice({
    required this.sliceType,
    required this.paramValue,
    required this.paramLabel,
    required this.xValues,
    required this.xLabels,
    required this.ivValues,
  });

  Map<String, dynamic> toJson() => {
        'slice_type': sliceType.name,
        'param_value': paramValue,
        'param_label': paramLabel,
        'x_values': xValues,
        'x_labels': xLabels,
        'iv_values': ivValues,
      };

  factory IvSurfaceSlice.fromJson(Map<String, dynamic> json) {
    return IvSurfaceSlice(
      sliceType: SliceType.values.firstWhere(
        (e) => e.name == json['slice_type'],
        orElse: () => SliceType.smileByDte,
      ),
      paramValue: (json['param_value'] as num?)?.toDouble() ?? 0.0,
      paramLabel: json['param_label'] as String? ?? '',
      xValues: (json['x_values'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      xLabels: (json['x_labels'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      ivValues: (json['iv_values'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
    );
  }
}

/// Category of arbitrage pricing anomaly detected on the surface.
enum ArbitrageType {
  calendarArbitrage, // Total implied variance decreases with time (dw/dt < 0)
  butterflyArbitrage, // Convexity violation in strike space (negative digital density)
}

/// Description of an arbitrage condition or pricing distortion identified on the surface.
class ArbitrageViolation {
  final ArbitrageType type;
  final double strike;
  final int dte;
  final String description;
  final String severity; // 'low', 'medium', 'critical'
  final double discrepancy; // Magnitude of violation

  const ArbitrageViolation({
    required this.type,
    required this.strike,
    required this.dte,
    required this.description,
    required this.severity,
    required this.discrepancy,
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'strike': strike,
        'dte': dte,
        'description': description,
        'severity': severity,
        'discrepancy': discrepancy,
      };

  factory ArbitrageViolation.fromJson(Map<String, dynamic> json) {
    return ArbitrageViolation(
      type: ArbitrageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ArbitrageType.calendarArbitrage,
      ),
      strike: (json['strike'] as num?)?.toDouble() ?? 0.0,
      dte: json['dte'] as int? ?? 0,
      description: json['description'] as String? ?? '',
      severity: json['severity'] as String? ?? 'low',
      discrepancy: (json['discrepancy'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Overarching surface regime classification.
enum IvSurfaceRegime {
  contango, // Upward sloping term structure (long-term IV > short-term IV)
  backwardation, // Inverted term structure (short-term IV > long-term IV, event/panic)
  extremePutSkew, // Steep downside skew (high crash protection demand)
  callSkew, // Upside call skew (speculative call squeeze)
  flat, // Uniform volatility distribution
}

extension IvSurfaceRegimeDisplay on IvSurfaceRegime {
  String get displayName {
    switch (this) {
      case IvSurfaceRegime.contango:
        return 'Contango (Normal)';
      case IvSurfaceRegime.backwardation:
        return 'Backwardation (Inverted)';
      case IvSurfaceRegime.extremePutSkew:
        return 'Extreme Put Skew';
      case IvSurfaceRegime.callSkew:
        return 'Call Skew / Squeeze';
      case IvSurfaceRegime.flat:
        return 'Flat Surface';
    }
  }

  Color get badgeColor {
    switch (this) {
      case IvSurfaceRegime.contango:
        return Colors.green;
      case IvSurfaceRegime.backwardation:
        return Colors.red;
      case IvSurfaceRegime.extremePutSkew:
        return Colors.orange;
      case IvSurfaceRegime.callSkew:
        return Colors.deepPurple;
      case IvSurfaceRegime.flat:
        return Colors.blueGrey;
    }
  }

  IconData get icon {
    switch (this) {
      case IvSurfaceRegime.contango:
        return Icons.trending_up_rounded;
      case IvSurfaceRegime.backwardation:
        return Icons.warning_amber_rounded;
      case IvSurfaceRegime.extremePutSkew:
        return Icons.shield_rounded;
      case IvSurfaceRegime.callSkew:
        return Icons.rocket_launch_rounded;
      case IvSurfaceRegime.flat:
        return Icons.horizontal_rule_rounded;
    }
  }
}

/// Quantitative metrics summarizing the geometry and features of the surface.
class IvSurfaceMetrics {
  final double minIv;
  final double maxIv;
  final double meanIv;
  final double atmShortTermIv; // ~30D ATM IV
  final double atmLongTermIv; // ~180D ATM IV
  final double termSlope; // (Long IV - Short IV) / dt
  final double riskReversal25D; // IV(25D Put) - IV(25D Call)
  final double butterflySkew; // IV(25D Put) + IV(25D Call) - 2*IV(ATM)
  final IvSurfaceRegime regime;
  final String regimeDescription;
  final bool hasArbitrage;
  final int arbitrageCount;

  const IvSurfaceMetrics({
    required this.minIv,
    required this.maxIv,
    required this.meanIv,
    required this.atmShortTermIv,
    required this.atmLongTermIv,
    required this.termSlope,
    required this.riskReversal25D,
    required this.butterflySkew,
    required this.regime,
    required this.regimeDescription,
    required this.hasArbitrage,
    required this.arbitrageCount,
  });

  Map<String, dynamic> toJson() => {
        'min_iv': minIv,
        'max_iv': maxIv,
        'mean_iv': meanIv,
        'atm_short_term_iv': atmShortTermIv,
        'atm_long_term_iv': atmLongTermIv,
        'term_slope': termSlope,
        'risk_reversal_25d': riskReversal25D,
        'butterfly_skew': butterflySkew,
        'regime': regime.name,
        'regime_description': regimeDescription,
        'has_arbitrage': hasArbitrage,
        'arbitrage_count': arbitrageCount,
      };

  factory IvSurfaceMetrics.fromJson(Map<String, dynamic> json) {
    return IvSurfaceMetrics(
      minIv: (json['min_iv'] as num?)?.toDouble() ?? 0.0,
      maxIv: (json['max_iv'] as num?)?.toDouble() ?? 0.0,
      meanIv: (json['mean_iv'] as num?)?.toDouble() ?? 0.0,
      atmShortTermIv: (json['atm_short_term_iv'] as num?)?.toDouble() ?? 0.0,
      atmLongTermIv: (json['atm_long_term_iv'] as num?)?.toDouble() ?? 0.0,
      termSlope: (json['term_slope'] as num?)?.toDouble() ?? 0.0,
      riskReversal25D: (json['risk_reversal_25d'] as num?)?.toDouble() ?? 0.0,
      butterflySkew: (json['butterfly_skew'] as num?)?.toDouble() ?? 0.0,
      regime: IvSurfaceRegime.values.firstWhere(
        (e) => e.name == json['regime'],
        orElse: () => IvSurfaceRegime.contango,
      ),
      regimeDescription: json['regime_description'] as String? ?? '',
      hasArbitrage: json['has_arbitrage'] as bool? ?? false,
      arbitrageCount: json['arbitrage_count'] as int? ?? 0,
    );
  }
}

/// Root data model encapsulating a full Implied Volatility Surface analysis.
class IvSurfaceAnalysis {
  final String symbol;
  final double spotPrice;
  final DateTime timestamp;
  final IvSurfaceGrid grid;
  final List<IvSurfacePoint> rawPoints;
  final IvSurfaceMetrics metrics;
  final List<ArbitrageViolation> arbitrageViolations;
  final List<IvSurfaceSlice> smileSlices;
  final List<IvSurfaceSlice> termSlices;

  const IvSurfaceAnalysis({
    required this.symbol,
    required this.spotPrice,
    required this.timestamp,
    required this.grid,
    required this.rawPoints,
    required this.metrics,
    required this.arbitrageViolations,
    required this.smileSlices,
    required this.termSlices,
  });

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'spot_price': spotPrice,
        'timestamp': timestamp.toIso8601String(),
        'grid': grid.toJson(),
        'raw_points': rawPoints.map((p) => p.toJson()).toList(),
        'metrics': metrics.toJson(),
        'arbitrage_violations':
            arbitrageViolations.map((a) => a.toJson()).toList(),
        'smile_slices': smileSlices.map((s) => s.toJson()).toList(),
        'term_slices': termSlices.map((s) => s.toJson()).toList(),
      };

  factory IvSurfaceAnalysis.fromJson(Map<String, dynamic> json) {
    return IvSurfaceAnalysis(
      symbol: json['symbol'] as String? ?? '',
      spotPrice: (json['spot_price'] as num?)?.toDouble() ?? 0.0,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      grid: json['grid'] != null
          ? IvSurfaceGrid.fromJson(json['grid'] as Map<String, dynamic>)
          : const IvSurfaceGrid(
              strikes: [],
              moneynessValues: [],
              dtes: [],
              ivMatrix: [],
              localVolMatrix: [],
            ),
      rawPoints: (json['raw_points'] as List<dynamic>?)
              ?.map((p) => IvSurfacePoint.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      metrics: json['metrics'] != null
          ? IvSurfaceMetrics.fromJson(json['metrics'] as Map<String, dynamic>)
          : const IvSurfaceMetrics(
              minIv: 0,
              maxIv: 0,
              meanIv: 0,
              atmShortTermIv: 0,
              atmLongTermIv: 0,
              termSlope: 0,
              riskReversal25D: 0,
              butterflySkew: 0,
              regime: IvSurfaceRegime.contango,
              regimeDescription: '',
              hasArbitrage: false,
              arbitrageCount: 0,
            ),
      arbitrageViolations: (json['arbitrage_violations'] as List<dynamic>?)
              ?.map(
                  (a) => ArbitrageViolation.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
      smileSlices: (json['smile_slices'] as List<dynamic>?)
              ?.map((s) => IvSurfaceSlice.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      termSlices: (json['term_slices'] as List<dynamic>?)
              ?.map((s) => IvSurfaceSlice.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
