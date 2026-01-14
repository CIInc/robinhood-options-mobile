enum IndicatorType {
  SMA,
  EMA,
  RSI,
  MACD,
  Bollinger,
  Stochastic,
  ATR,
  OBV,
  WilliamsR
}

enum SignalCondition { GreaterThan, LessThan, CrossOverAbove, CrossOverBelow }

class CustomIndicatorConfig {
  String id;
  String name;
  IndicatorType type;
  Map<String, dynamic> parameters;
  SignalCondition condition;
  double? threshold;
  bool compareToPrice;

  CustomIndicatorConfig({
    required this.id,
    required this.name,
    required this.type,
    required this.parameters,
    required this.condition,
    this.threshold,
    this.compareToPrice = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.toString().split('.').last,
        'parameters': parameters,
        'condition': condition.toString().split('.').last,
        'threshold': threshold,
        'compareToPrice': compareToPrice,
      };

  factory CustomIndicatorConfig.fromJson(Map<String, dynamic> json) =>
      CustomIndicatorConfig(
        id: json['id'] as String,
        name: json['name'] as String,
        type: IndicatorType.values.firstWhere(
            (e) => e.toString().split('.').last == json['type'],
            orElse: () => IndicatorType.SMA),
        parameters: json['parameters'] as Map<String, dynamic>,
        condition: SignalCondition.values.firstWhere(
            (e) => e.toString().split('.').last == json['condition'],
            orElse: () => SignalCondition.GreaterThan),
        threshold: (json['threshold'] as num?)?.toDouble(),
        compareToPrice: json['compareToPrice'] as bool? ?? false,
      );
}
