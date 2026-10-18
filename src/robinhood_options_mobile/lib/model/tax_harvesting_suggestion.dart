class CorrelatedReplacement {
  final String symbol;
  final String name;
  final String assetType; // 'etf' or 'stock'
  final double correlation; // e.g. 0.98
  final String rationale;
  final bool isSubstantiallyIdenticalWarning;

  const CorrelatedReplacement({
    required this.symbol,
    required this.name,
    this.assetType = 'etf',
    required this.correlation,
    required this.rationale,
    this.isSubstantiallyIdenticalWarning = false,
  });

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'name': name,
        'assetType': assetType,
        'correlation': correlation,
        'rationale': rationale,
        'isSubstantiallyIdenticalWarning': isSubstantiallyIdenticalWarning,
      };

  factory CorrelatedReplacement.fromJson(Map<String, dynamic> json) =>
      CorrelatedReplacement(
        symbol: json['symbol'] as String,
        name: json['name'] as String,
        assetType: json['assetType'] as String? ?? 'etf',
        correlation: (json['correlation'] as num).toDouble(),
        rationale: json['rationale'] as String,
        isSubstantiallyIdenticalWarning:
            json['isSubstantiallyIdenticalWarning'] as bool? ?? false,
      );
}

class TaxHarvestingSuggestion {
  final String symbol;
  final String name;
  final double quantity;
  final double averageBuyPrice;
  final double currentPrice;
  final double estimatedLoss;
  final double totalCost;
  final String type; // 'stock' or 'option'
  final dynamic position; // InstrumentPosition or OptionAggregatePosition
  final List<CorrelatedReplacement> replacements;
  final double? taxSavingsEstimate;
  final String? holdingPeriod; // 'short_term', 'long_term'
  final double lossPercentage;

  TaxHarvestingSuggestion({
    required this.symbol,
    required this.name,
    required this.quantity,
    required this.averageBuyPrice,
    required this.currentPrice,
    required this.estimatedLoss,
    required this.totalCost,
    required this.type,
    required this.position,
    this.replacements = const [],
    this.taxSavingsEstimate,
    this.holdingPeriod,
    double? lossPercentage,
  }) : lossPercentage = lossPercentage ??
            (totalCost > 0 ? (estimatedLoss.abs() / totalCost) : 0.0);
}

class TaxHarvestingScanResult {
  final double totalUnrealizedLoss;
  final double realizedCapitalGains;
  final double netGainsAfterHarvest;
  final double capitalLossDeductionUsed; // Up to $3,000 against ordinary income
  final double capitalLossCarryforward;
  final double estimatedTaxSavings;
  final double effectiveTaxRate; // e.g. 0.29 (29%)
  final List<TaxHarvestingSuggestion> suggestions;
  final int totalScannedPositions;

  TaxHarvestingScanResult({
    required this.totalUnrealizedLoss,
    required this.realizedCapitalGains,
    required this.netGainsAfterHarvest,
    required this.capitalLossDeductionUsed,
    required this.capitalLossCarryforward,
    required this.estimatedTaxSavings,
    this.effectiveTaxRate = 0.29,
    required this.suggestions,
    required this.totalScannedPositions,
  });

  bool get hasHarvestableOpportunities => suggestions.isNotEmpty;
  bool get canOffsetGains =>
      realizedCapitalGains > 0 && totalUnrealizedLoss < 0;
}
