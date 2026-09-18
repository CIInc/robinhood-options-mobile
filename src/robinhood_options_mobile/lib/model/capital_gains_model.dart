import 'dart:math';

/// Represents an individual asset position (stock or option) evaluated for
/// short-term vs. long-term capital gains tax treatment.
class CapitalGainPosition {
  final String id;
  final String symbol;
  final String name;
  final double quantity;
  final double averageCostPrice;
  final double totalCost;
  final double currentPrice;
  final double marketValue;
  final double gainLoss;
  final double gainLossPercent;
  final String type; // 'stock' or 'option'
  final DateTime acquiredDate;
  final int holdingDays;
  final bool isLongTerm;
  final int daysUntilLongTerm;
  final bool qualifiesForLongTermSoon;
  final double estimatedShortTermTax;
  final double estimatedLongTermTax;
  final double potentialTaxSavingsIfHeld;
  final dynamic underlyingPosition;

  const CapitalGainPosition({
    required this.id,
    required this.symbol,
    required this.name,
    required this.quantity,
    required this.averageCostPrice,
    required this.totalCost,
    required this.currentPrice,
    required this.marketValue,
    required this.gainLoss,
    required this.gainLossPercent,
    required this.type,
    required this.acquiredDate,
    required this.holdingDays,
    required this.isLongTerm,
    required this.daysUntilLongTerm,
    required this.qualifiesForLongTermSoon,
    required this.estimatedShortTermTax,
    required this.estimatedLongTermTax,
    required this.potentialTaxSavingsIfHeld,
    this.underlyingPosition,
  });

  /// Factory constructor calculating holding periods, classifications, and tax projections.
  factory CapitalGainPosition.create({
    required String id,
    required String symbol,
    required String name,
    required double quantity,
    required double averageCostPrice,
    required double totalCost,
    required double currentPrice,
    required double marketValue,
    required double gainLoss,
    required double gainLossPercent,
    required String type,
    required DateTime acquiredDate,
    DateTime? asOf,
    double shortTermTaxRate = 0.24,
    double longTermTaxRate = 0.15,
    dynamic underlyingPosition,
  }) {
    final now = asOf ?? DateTime.now();
    final holdingDuration = now.difference(acquiredDate);
    final days = max(0, holdingDuration.inDays);
    // Under IRS rules, long-term capital gain treatment requires holding > 1 year (> 365 days).
    final isLong = days > 365;
    final daysUntilLong = isLong ? 0 : max(0, 366 - days);
    final qualifiesSoon = !isLong && daysUntilLong <= 60 && gainLoss > 0;

    final shortTax = gainLoss > 0 ? gainLoss * shortTermTaxRate : 0.0;
    final longTax = gainLoss > 0 ? gainLoss * longTermTaxRate : 0.0;
    final savings = gainLoss > 0 ? max(0.0, shortTax - longTax) : 0.0;

    return CapitalGainPosition(
      id: id,
      symbol: symbol,
      name: name,
      quantity: quantity,
      averageCostPrice: averageCostPrice,
      totalCost: totalCost,
      currentPrice: currentPrice,
      marketValue: marketValue,
      gainLoss: gainLoss,
      gainLossPercent: gainLossPercent,
      type: type,
      acquiredDate: acquiredDate,
      holdingDays: days,
      isLongTerm: isLong,
      daysUntilLongTerm: daysUntilLong,
      qualifiesForLongTermSoon: qualifiesSoon,
      estimatedShortTermTax: shortTax,
      estimatedLongTermTax: longTax,
      potentialTaxSavingsIfHeld: savings,
      underlyingPosition: underlyingPosition,
    );
  }

  String get formattedHoldingPeriod {
    if (holdingDays >= 365) {
      final years = holdingDays / 365.25;
      return '${years.toStringAsFixed(1)}y (${holdingDays}d)';
    } else if (holdingDays >= 30) {
      final months = (holdingDays / 30.4).floor();
      return '${months}mo (${holdingDays}d)';
    } else {
      return '${holdingDays}d';
    }
  }

  String get holdingTimerText {
    if (isLongTerm) {
      return 'Long-Term (Preferential rate)';
    } else if (qualifiesForLongTermSoon) {
      return '$daysUntilLongTerm days until Long-Term';
    } else {
      return '$daysUntilLongTerm days to Long-Term';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'name': name,
        'quantity': quantity,
        'averageCostPrice': averageCostPrice,
        'totalCost': totalCost,
        'currentPrice': currentPrice,
        'marketValue': marketValue,
        'gainLoss': gainLoss,
        'gainLossPercent': gainLossPercent,
        'type': type,
        'acquiredDate': acquiredDate.toIso8601String(),
        'holdingDays': holdingDays,
        'isLongTerm': isLongTerm,
        'daysUntilLongTerm': daysUntilLongTerm,
        'qualifiesForLongTermSoon': qualifiesForLongTermSoon,
        'estimatedShortTermTax': estimatedShortTermTax,
        'estimatedLongTermTax': estimatedLongTermTax,
        'potentialTaxSavingsIfHeld': potentialTaxSavingsIfHeld,
      };
}

/// Aggregated capital gains summary representing portfolio-wide Short-Term vs.
/// Long-Term breakdown, holding period duration timers, and tax liability projections.
class CapitalGainsSummary {
  final List<CapitalGainPosition> allPositions;
  final List<CapitalGainPosition> shortTermPositions;
  final List<CapitalGainPosition> longTermPositions;
  final List<CapitalGainPosition> approachingLongTermPositions;

  final double shortTermGains;
  final double shortTermLosses;
  final double shortTermNet;

  final double longTermGains;
  final double longTermLosses;
  final double longTermNet;

  final double totalUnrealizedGains;
  final double totalUnrealizedLosses;
  final double totalNetGainLoss;

  final double shortTermTaxRate;
  final double longTermTaxRate;

  final double estimatedShortTermTaxLiability;
  final double estimatedLongTermTaxLiability;
  final double totalEstimatedTaxLiability;
  final double potentialTaxSavingsFromHolding;

  const CapitalGainsSummary({
    required this.allPositions,
    required this.shortTermPositions,
    required this.longTermPositions,
    required this.approachingLongTermPositions,
    required this.shortTermGains,
    required this.shortTermLosses,
    required this.shortTermNet,
    required this.longTermGains,
    required this.longTermLosses,
    required this.longTermNet,
    required this.totalUnrealizedGains,
    required this.totalUnrealizedLosses,
    required this.totalNetGainLoss,
    required this.shortTermTaxRate,
    required this.longTermTaxRate,
    required this.estimatedShortTermTaxLiability,
    required this.estimatedLongTermTaxLiability,
    required this.totalEstimatedTaxLiability,
    required this.potentialTaxSavingsFromHolding,
  });

  factory CapitalGainsSummary.fromPositions({
    required List<CapitalGainPosition> positions,
    double shortTermTaxRate = 0.24,
    double longTermTaxRate = 0.15,
  }) {
    final shortTerm = positions.where((p) => !p.isLongTerm).toList();
    final longTerm = positions.where((p) => p.isLongTerm).toList();
    final approaching =
        positions.where((p) => p.qualifiesForLongTermSoon).toList();

    // Sort approaching positions by fewest days remaining until long-term
    approaching
        .sort((a, b) => a.daysUntilLongTerm.compareTo(b.daysUntilLongTerm));

    double stGains = 0;
    double stLosses = 0;
    for (var p in shortTerm) {
      if (p.gainLoss >= 0) {
        stGains += p.gainLoss;
      } else {
        stLosses += p.gainLoss;
      }
    }
    final stNet = stGains + stLosses;

    double ltGains = 0;
    double ltLosses = 0;
    for (var p in longTerm) {
      if (p.gainLoss >= 0) {
        ltGains += p.gainLoss;
      } else {
        ltLosses += p.gainLoss;
      }
    }
    final ltNet = ltGains + ltLosses;

    final totGains = stGains + ltGains;
    final totLosses = stLosses + ltLosses;
    final totNet = stNet + ltNet;

    // Projected liabilities based on net gains (losses offset gains within each basket)
    final stLiability = stNet > 0 ? stNet * shortTermTaxRate : 0.0;
    final ltLiability = ltNet > 0 ? ltNet * longTermTaxRate : 0.0;
    final totLiability = stLiability + ltLiability;

    double potentialSavings = 0;
    for (var p in approaching) {
      potentialSavings += p.potentialTaxSavingsIfHeld;
    }

    return CapitalGainsSummary(
      allPositions: positions,
      shortTermPositions: shortTerm,
      longTermPositions: longTerm,
      approachingLongTermPositions: approaching,
      shortTermGains: stGains,
      shortTermLosses: stLosses,
      shortTermNet: stNet,
      longTermGains: ltGains,
      longTermLosses: ltLosses,
      longTermNet: ltNet,
      totalUnrealizedGains: totGains,
      totalUnrealizedLosses: totLosses,
      totalNetGainLoss: totNet,
      shortTermTaxRate: shortTermTaxRate,
      longTermTaxRate: longTermTaxRate,
      estimatedShortTermTaxLiability: stLiability,
      estimatedLongTermTaxLiability: ltLiability,
      totalEstimatedTaxLiability: totLiability,
      potentialTaxSavingsFromHolding: potentialSavings,
    );
  }
}
