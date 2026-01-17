class PriceTargetLevel {
  final double price;
  final String description;

  PriceTargetLevel({required this.price, required this.description});

  factory PriceTargetLevel.fromJson(Map<String, dynamic> json) {
    return PriceTargetLevel(
      price: (json['price'] as num).toDouble(),
      description: json['description'] ?? '',
    );
  }
}

class FairValueAnalysis {
  final double price;
  final double high;
  final double low;
  final String method;
  final String currency;

  FairValueAnalysis({
    required this.price,
    required this.high,
    required this.low,
    required this.method,
    required this.currency,
  });

  factory FairValueAnalysis.fromJson(Map<String, dynamic> json) {
    return FairValueAnalysis(
      price: (json['price'] as num).toDouble(),
      high: (json['high'] as num).toDouble(),
      low: (json['low'] as num).toDouble(),
      method: json['method'] ?? '',
      currency: json['currency'] ?? 'USD',
    );
  }
}

class PriceTargetAnalysis {
  final List<PriceTargetLevel> supportLevels;
  final List<PriceTargetLevel> resistanceLevels;
  final PriceTargetLevel? bullishTarget;
  final PriceTargetLevel? bearishTarget;
  final String summary;
  final DateTime? lastUpdated;
  final double? confidenceScore;
  final String? investmentHorizon;
  final List<String> keyRisks;
  final FairValueAnalysis? fairValue;

  PriceTargetAnalysis({
    required this.supportLevels,
    required this.resistanceLevels,
    this.bullishTarget,
    this.bearishTarget,
    required this.summary,
    this.lastUpdated,
    this.confidenceScore,
    this.investmentHorizon,
    this.keyRisks = const [],
    this.fairValue,
  });

  factory PriceTargetAnalysis.fromJson(Map<String, dynamic> json) {
    return PriceTargetAnalysis(
      supportLevels: (json['support_levels'] as List<dynamic>?)
              ?.map((e) => PriceTargetLevel.fromJson(e))
              .toList() ??
          [],
      resistanceLevels: (json['resistance_levels'] as List<dynamic>?)
              ?.map((e) => PriceTargetLevel.fromJson(e))
              .toList() ??
          [],
      bullishTarget: json['bullish_target'] != null
          ? PriceTargetLevel.fromJson(json['bullish_target'])
          : null,
      bearishTarget: json['bearish_target'] != null
          ? PriceTargetLevel.fromJson(json['bearish_target'])
          : null,
      summary: json['summary'] ?? '',
      lastUpdated: json['last_updated'] != null
          ? DateTime.tryParse(json['last_updated'])
          : null,
      confidenceScore: (json['confidence_score'] as num?)?.toDouble(),
      investmentHorizon: json['investment_horizon'],
      keyRisks: (json['key_risks'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      fairValue: json['fair_value'] != null
          ? FairValueAnalysis.fromJson(json['fair_value'])
          : null,
    );
  }
}
