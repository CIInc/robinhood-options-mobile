import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Type of leg within the delta-neutral position builder.
enum DeltaLegType {
  stock,
  call,
  put,
}

extension DeltaLegTypeDisplay on DeltaLegType {
  String get label {
    switch (this) {
      case DeltaLegType.stock:
        return 'Stock (Shares)';
      case DeltaLegType.call:
        return 'Call Option';
      case DeltaLegType.put:
        return 'Put Option';
    }
  }

  IconData get icon {
    switch (this) {
      case DeltaLegType.stock:
        return Icons.show_chart_rounded;
      case DeltaLegType.call:
        return Icons.trending_up_rounded;
      case DeltaLegType.put:
        return Icons.trending_down_rounded;
    }
  }
}

/// Long vs Short position side.
enum PositionSide {
  long,
  short,
}

extension PositionSideDisplay on PositionSide {
  String get label => this == PositionSide.long ? 'Long' : 'Short';

  Color color(BuildContext context) {
    return this == PositionSide.long ? Colors.green : Colors.red;
  }
}

/// Strategy or vehicle used to neutralize delta exposure.
enum DeltaNeutralHedgingType {
  underlyingShares,
  callOption,
  putOption,
  straddleStrangle,
  collarSpread,
  ratioSpread,
}

extension DeltaNeutralHedgingTypeDisplay on DeltaNeutralHedgingType {
  String get title {
    switch (this) {
      case DeltaNeutralHedgingType.underlyingShares:
        return 'Underlying Shares Rebalancing';
      case DeltaNeutralHedgingType.callOption:
        return 'Call Option Delta Offset';
      case DeltaNeutralHedgingType.putOption:
        return 'Put Option Delta Offset';
      case DeltaNeutralHedgingType.straddleStrangle:
        return 'Delta-Neutral Straddle / Strangle';
      case DeltaNeutralHedgingType.collarSpread:
        return 'Covered Collar Neutralization';
      case DeltaNeutralHedgingType.ratioSpread:
        return 'Ratio Spread Neutralization';
    }
  }

  IconData get icon {
    switch (this) {
      case DeltaNeutralHedgingType.underlyingShares:
        return Icons.swap_horizontal_circle_outlined;
      case DeltaNeutralHedgingType.callOption:
        return Icons.call_made_rounded;
      case DeltaNeutralHedgingType.putOption:
        return Icons.call_received_rounded;
      case DeltaNeutralHedgingType.straddleStrangle:
        return Icons.compare_arrows_rounded;
      case DeltaNeutralHedgingType.collarSpread:
        return Icons.shield_outlined;
      case DeltaNeutralHedgingType.ratioSpread:
        return Icons.tune_rounded;
    }
  }
}

/// Severity classification of the delta drift against tolerance.
enum DeltaDriftStatus {
  neutral,
  mildDrift,
  severeDrift,
}

extension DeltaDriftStatusDisplay on DeltaDriftStatus {
  String get label {
    switch (this) {
      case DeltaDriftStatus.neutral:
        return 'Delta Neutral';
      case DeltaDriftStatus.mildDrift:
        return 'Mild Delta Drift';
      case DeltaDriftStatus.severeDrift:
        return 'Severe Delta Drift';
    }
  }

  Color color(BuildContext context) {
    switch (this) {
      case DeltaDriftStatus.neutral:
        return Colors.green;
      case DeltaDriftStatus.mildDrift:
        return Colors.orange;
      case DeltaDriftStatus.severeDrift:
        return Theme.of(context).colorScheme.error;
    }
  }

  IconData get icon {
    switch (this) {
      case DeltaDriftStatus.neutral:
        return Icons.check_circle_rounded;
      case DeltaDriftStatus.mildDrift:
        return Icons.warning_amber_rounded;
      case DeltaDriftStatus.severeDrift:
        return Icons.error_rounded;
    }
  }
}

/// Represents a single leg (stock shares or option contract) in the strategy builder.
class DeltaPositionLeg {
  final String id;
  final String symbol;
  final DeltaLegType legType;
  final PositionSide side;
  final double quantity; // shares for stock, contracts for options
  final double? strike;
  final DateTime? expirationDate;
  final double unitDelta; // +1.0 for stock, -1 to +1 for options
  final double unitGamma;
  final double unitTheta;
  final double unitVega;
  final double? impliedVolatility;
  final double markPrice;

  const DeltaPositionLeg({
    required this.id,
    required this.symbol,
    required this.legType,
    required this.side,
    required this.quantity,
    this.strike,
    this.expirationDate,
    required this.unitDelta,
    this.unitGamma = 0.0,
    this.unitTheta = 0.0,
    this.unitVega = 0.0,
    this.impliedVolatility,
    required this.markPrice,
  });

  /// True multiplier per unit (1 for shares, 100 for standard option contracts).
  double get multiplier => legType == DeltaLegType.stock ? 1.0 : 100.0;

  /// Effective side factor (+1 for long, -1 for short).
  double get sideMultiplier => side == PositionSide.long ? 1.0 : -1.0;

  /// Net delta contributed by this leg in share-equivalents.
  /// For stock: unitDelta (1.0) * quantity * sideMultiplier
  /// For call: unitDelta (>0) * 100 * quantity * sideMultiplier
  /// For put: unitDelta (<0) * 100 * quantity * sideMultiplier
  double get totalDelta {
    if (legType == DeltaLegType.stock) {
      return 1.0 * quantity * sideMultiplier;
    }
    return unitDelta * multiplier * quantity * sideMultiplier;
  }

  /// Net gamma contributed by this leg in share-equivalents.
  double get totalGamma {
    if (legType == DeltaLegType.stock) return 0.0;
    return unitGamma * multiplier * quantity * sideMultiplier;
  }

  /// Net theta contributed by this leg in dollar/day.
  double get totalTheta {
    if (legType == DeltaLegType.stock) return 0.0;
    return unitTheta * multiplier * quantity * sideMultiplier;
  }

  /// Net vega contributed by this leg in dollar/1% IV shift.
  double get totalVega {
    if (legType == DeltaLegType.stock) return 0.0;
    return unitVega * multiplier * quantity * sideMultiplier;
  }

  /// Total current market value of this leg.
  double get marketValue => markPrice * quantity * multiplier;

  /// Descriptive label (e.g. "Long 100 Shares" or "Short 1x $150 Call (Oct 24)").
  String get description {
    final qtyStr = quantity % 1 == 0
        ? quantity.toInt().toString()
        : quantity.toStringAsFixed(1);
    final sideStr = side == PositionSide.long ? 'Long' : 'Short';
    if (legType == DeltaLegType.stock) {
      return '$sideStr $qtyStr Shares';
    }
    final expStr = expirationDate != null
        ? DateFormat('MMM d').format(expirationDate!)
        : '';
    final typeStr = legType == DeltaLegType.call ? 'Call' : 'Put';
    final strikeStr = strike != null ? '\$${strike!.toStringAsFixed(1)}' : '';
    return '$sideStr ${qtyStr}x $strikeStr $typeStr ($expStr)';
  }

  DeltaPositionLeg copyWith({
    String? id,
    String? symbol,
    DeltaLegType? legType,
    PositionSide? side,
    double? quantity,
    double? strike,
    DateTime? expirationDate,
    double? unitDelta,
    double? unitGamma,
    double? unitTheta,
    double? unitVega,
    double? impliedVolatility,
    double? markPrice,
  }) {
    return DeltaPositionLeg(
      id: id ?? this.id,
      symbol: symbol ?? this.symbol,
      legType: legType ?? this.legType,
      side: side ?? this.side,
      quantity: quantity ?? this.quantity,
      strike: strike ?? this.strike,
      expirationDate: expirationDate ?? this.expirationDate,
      unitDelta: unitDelta ?? this.unitDelta,
      unitGamma: unitGamma ?? this.unitGamma,
      unitTheta: unitTheta ?? this.unitTheta,
      unitVega: unitVega ?? this.unitVega,
      impliedVolatility: impliedVolatility ?? this.impliedVolatility,
      markPrice: markPrice ?? this.markPrice,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'leg_type': legType.name,
        'side': side.name,
        'quantity': quantity,
        'strike': strike,
        'expiration_date': expirationDate?.toIso8601String(),
        'unit_delta': unitDelta,
        'unit_gamma': unitGamma,
        'unit_theta': unitTheta,
        'unit_vega': unitVega,
        'implied_volatility': impliedVolatility,
        'mark_price': markPrice,
        'total_delta': totalDelta,
        'total_gamma': totalGamma,
        'total_theta': totalTheta,
        'total_vega': totalVega,
        'market_value': marketValue,
      };

  factory DeltaPositionLeg.fromJson(Map<String, dynamic> json) {
    return DeltaPositionLeg(
      id: json['id'] as String? ??
          'leg_${DateTime.now().millisecondsSinceEpoch}',
      symbol: json['symbol'] as String? ?? '',
      legType: DeltaLegType.values.firstWhere(
        (e) => e.name == json['leg_type'],
        orElse: () => DeltaLegType.stock,
      ),
      side: PositionSide.values.firstWhere(
        (e) => e.name == json['side'],
        orElse: () => PositionSide.long,
      ),
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      strike: (json['strike'] as num?)?.toDouble(),
      expirationDate: json['expiration_date'] != null
          ? DateTime.tryParse(json['expiration_date'] as String)
          : null,
      unitDelta: (json['unit_delta'] as num?)?.toDouble() ?? 0.0,
      unitGamma: (json['unit_gamma'] as num?)?.toDouble() ?? 0.0,
      unitTheta: (json['unit_theta'] as num?)?.toDouble() ?? 0.0,
      unitVega: (json['unit_vega'] as num?)?.toDouble() ?? 0.0,
      impliedVolatility: (json['implied_volatility'] as num?)?.toDouble(),
      markPrice: (json['mark_price'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// An actionable recommendation to rebalance a position towards target delta neutrality.
class DeltaOffsetRecommendation {
  final DeltaNeutralHedgingType hedgingType;
  final String action; // 'buy' or 'sell'
  final String instrumentType; // 'shares', 'call', 'put'
  final double quantity; // number of shares or option contracts
  final double? strike;
  final DateTime? expirationDate;
  final double? contractUnitDelta;
  final double resultingNetDelta;
  final double
      estimatedCashFlow; // positive for cost/debit, negative for credit
  final String description;
  final String rationale;

  const DeltaOffsetRecommendation({
    required this.hedgingType,
    required this.action,
    required this.instrumentType,
    required this.quantity,
    this.strike,
    this.expirationDate,
    this.contractUnitDelta,
    required this.resultingNetDelta,
    required this.estimatedCashFlow,
    required this.description,
    required this.rationale,
  });

  Map<String, dynamic> toJson() => {
        'hedging_type': hedgingType.name,
        'action': action,
        'instrument_type': instrumentType,
        'quantity': quantity,
        'strike': strike,
        'expiration_date': expirationDate?.toIso8601String(),
        'contract_unit_delta': contractUnitDelta,
        'resulting_net_delta': resultingNetDelta,
        'estimated_cash_flow': estimatedCashFlow,
        'description': description,
        'rationale': rationale,
      };

  factory DeltaOffsetRecommendation.fromJson(Map<String, dynamic> json) {
    return DeltaOffsetRecommendation(
      hedgingType: DeltaNeutralHedgingType.values.firstWhere(
        (e) => e.name == json['hedging_type'],
        orElse: () => DeltaNeutralHedgingType.underlyingShares,
      ),
      action: json['action'] as String? ?? 'buy',
      instrumentType: json['instrument_type'] as String? ?? 'shares',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      strike: (json['strike'] as num?)?.toDouble(),
      expirationDate: json['expiration_date'] != null
          ? DateTime.tryParse(json['expiration_date'] as String)
          : null,
      contractUnitDelta: (json['contract_unit_delta'] as num?)?.toDouble(),
      resultingNetDelta:
          (json['resulting_net_delta'] as num?)?.toDouble() ?? 0.0,
      estimatedCashFlow:
          (json['estimated_cash_flow'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] as String? ?? '',
      rationale: json['rationale'] as String? ?? '',
    );
  }
}

/// Simulated coordinate point on the spot-shift delta drift curve.
class DeltaScenarioPoint {
  final double spotPrice;
  final double percentageShift; // e.g. -0.10 for -10%
  final double projectedNetDelta;
  final double projectedPnL;
  final bool isInTolerance;

  const DeltaScenarioPoint({
    required this.spotPrice,
    required this.percentageShift,
    required this.projectedNetDelta,
    required this.projectedPnL,
    required this.isInTolerance,
  });

  Map<String, dynamic> toJson() => {
        'spot_price': spotPrice,
        'percentage_shift': percentageShift,
        'projected_net_delta': projectedNetDelta,
        'projected_pnl': projectedPnL,
        'is_in_tolerance': isInTolerance,
      };

  factory DeltaScenarioPoint.fromJson(Map<String, dynamic> json) {
    return DeltaScenarioPoint(
      spotPrice: (json['spot_price'] as num?)?.toDouble() ?? 0.0,
      percentageShift: (json['percentage_shift'] as num?)?.toDouble() ?? 0.0,
      projectedNetDelta:
          (json['projected_net_delta'] as num?)?.toDouble() ?? 0.0,
      projectedPnL: (json['projected_pnl'] as num?)?.toDouble() ?? 0.0,
      isInTolerance: json['is_in_tolerance'] as bool? ?? true,
    );
  }
}

/// Dynamic rebalance suggestions container.
class DeltaNeutralRebalanceSuggestion {
  final double currentNetDelta;
  final double targetDelta;
  final double toleranceBand;
  final double deltaDrift;
  final DeltaDriftStatus driftStatus;
  final DeltaOffsetRecommendation? primaryShareHedge;
  final DeltaOffsetRecommendation? primaryOptionHedge;
  final List<DeltaOffsetRecommendation> alternativeHedges;
  final String summaryText;

  const DeltaNeutralRebalanceSuggestion({
    required this.currentNetDelta,
    required this.targetDelta,
    required this.toleranceBand,
    required this.deltaDrift,
    required this.driftStatus,
    this.primaryShareHedge,
    this.primaryOptionHedge,
    this.alternativeHedges = const [],
    required this.summaryText,
  });

  Map<String, dynamic> toJson() => {
        'current_net_delta': currentNetDelta,
        'target_delta': targetDelta,
        'tolerance_band': toleranceBand,
        'delta_drift': deltaDrift,
        'drift_status': driftStatus.name,
        'primary_share_hedge': primaryShareHedge?.toJson(),
        'primary_option_hedge': primaryOptionHedge?.toJson(),
        'alternative_hedges': alternativeHedges.map((e) => e.toJson()).toList(),
        'summary_text': summaryText,
      };

  factory DeltaNeutralRebalanceSuggestion.fromJson(Map<String, dynamic> json) {
    return DeltaNeutralRebalanceSuggestion(
      currentNetDelta: (json['current_net_delta'] as num?)?.toDouble() ?? 0.0,
      targetDelta: (json['target_delta'] as num?)?.toDouble() ?? 0.0,
      toleranceBand: (json['tolerance_band'] as num?)?.toDouble() ?? 10.0,
      deltaDrift: (json['delta_drift'] as num?)?.toDouble() ?? 0.0,
      driftStatus: DeltaDriftStatus.values.firstWhere(
        (e) => e.name == json['drift_status'],
        orElse: () => DeltaDriftStatus.neutral,
      ),
      primaryShareHedge: json['primary_share_hedge'] != null
          ? DeltaOffsetRecommendation.fromJson(
              json['primary_share_hedge'] as Map<String, dynamic>)
          : null,
      primaryOptionHedge: json['primary_option_hedge'] != null
          ? DeltaOffsetRecommendation.fromJson(
              json['primary_option_hedge'] as Map<String, dynamic>)
          : null,
      alternativeHedges: (json['alternative_hedges'] as List<dynamic>?)
              ?.map((e) =>
                  DeltaOffsetRecommendation.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      summaryText: json['summary_text'] as String? ?? '',
    );
  }
}

/// Comprehensive delta-neutral strategy analysis container.
class DeltaNeutralAnalysis {
  final String symbol;
  final double spotPrice;
  final double targetDelta;
  final double toleranceBand;
  final List<DeltaPositionLeg> legs;
  final double netDelta;
  final double netGamma;
  final double netTheta;
  final double netVega;
  final double dollarDeltaPerOnePercent;
  final DeltaDriftStatus driftStatus;
  final DeltaNeutralRebalanceSuggestion rebalanceSuggestion;
  final List<DeltaScenarioPoint> scenarioPoints;
  final DateTime calculatedAt;

  const DeltaNeutralAnalysis({
    required this.symbol,
    required this.spotPrice,
    required this.targetDelta,
    required this.toleranceBand,
    required this.legs,
    required this.netDelta,
    required this.netGamma,
    required this.netTheta,
    required this.netVega,
    required this.dollarDeltaPerOnePercent,
    required this.driftStatus,
    required this.rebalanceSuggestion,
    required this.scenarioPoints,
    required this.calculatedAt,
  });

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'spot_price': spotPrice,
        'target_delta': targetDelta,
        'tolerance_band': toleranceBand,
        'legs': legs.map((e) => e.toJson()).toList(),
        'net_delta': netDelta,
        'net_gamma': netGamma,
        'net_theta': netTheta,
        'net_vega': netVega,
        'dollar_delta_per_one_percent': dollarDeltaPerOnePercent,
        'drift_status': driftStatus.name,
        'rebalance_suggestion': rebalanceSuggestion.toJson(),
        'scenario_points': scenarioPoints.map((e) => e.toJson()).toList(),
        'calculated_at': calculatedAt.toIso8601String(),
      };

  factory DeltaNeutralAnalysis.fromJson(Map<String, dynamic> json) {
    return DeltaNeutralAnalysis(
      symbol: json['symbol'] as String? ?? '',
      spotPrice: (json['spot_price'] as num?)?.toDouble() ?? 0.0,
      targetDelta: (json['target_delta'] as num?)?.toDouble() ?? 0.0,
      toleranceBand: (json['tolerance_band'] as num?)?.toDouble() ?? 10.0,
      legs: (json['legs'] as List<dynamic>?)
              ?.map((e) => DeltaPositionLeg.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      netDelta: (json['net_delta'] as num?)?.toDouble() ?? 0.0,
      netGamma: (json['net_gamma'] as num?)?.toDouble() ?? 0.0,
      netTheta: (json['net_theta'] as num?)?.toDouble() ?? 0.0,
      netVega: (json['net_vega'] as num?)?.toDouble() ?? 0.0,
      dollarDeltaPerOnePercent:
          (json['dollar_delta_per_one_percent'] as num?)?.toDouble() ?? 0.0,
      driftStatus: DeltaDriftStatus.values.firstWhere(
        (e) => e.name == json['drift_status'],
        orElse: () => DeltaDriftStatus.neutral,
      ),
      rebalanceSuggestion: json['rebalance_suggestion'] != null
          ? DeltaNeutralRebalanceSuggestion.fromJson(
              json['rebalance_suggestion'] as Map<String, dynamic>)
          : const DeltaNeutralRebalanceSuggestion(
              currentNetDelta: 0.0,
              targetDelta: 0.0,
              toleranceBand: 10.0,
              deltaDrift: 0.0,
              driftStatus: DeltaDriftStatus.neutral,
              summaryText: 'Neutral',
            ),
      scenarioPoints: (json['scenario_points'] as List<dynamic>?)
              ?.map(
                  (e) => DeltaScenarioPoint.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      calculatedAt: json['calculated_at'] != null
          ? DateTime.tryParse(json['calculated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
