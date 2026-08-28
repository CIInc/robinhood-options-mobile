import 'package:cloud_firestore/cloud_firestore.dart';

enum AlertType { price, volume, volatility, moving_average, rsi, custom }

enum AlertCondition { above, below, spike, drop, percent_change }

enum AlertLogic { all, any }

class SmartAlertRule {
  final AlertType type;
  final AlertCondition condition;
  final double value;
  final int? period;

  const SmartAlertRule({
    required this.type,
    required this.condition,
    required this.value,
    this.period,
  });

  factory SmartAlertRule.fromMap(Map<String, dynamic> map) {
    return SmartAlertRule(
      type: AlertType.values.firstWhere(
        (e) => e.name == (map['type'] ?? 'price'),
        orElse: () => AlertType.price,
      ),
      condition: AlertCondition.values.firstWhere(
        (e) => e.name == (map['condition'] ?? 'above'),
        orElse: () => AlertCondition.above,
      ),
      value: (map['value'] ?? 0).toDouble(),
      period: map['period'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'condition': condition.name,
      'value': value,
      'period': period,
    };
  }
}

class CustomAlert {
  final String id;
  final String userId;
  final String symbol;
  final AlertType type;
  final AlertCondition condition;
  final double value; // Threshold value
  final int?
      period; // Period for technical indicators (e.g. 50 for SMA, 14 for RSI)
  final AlertLogic logic;
  final List<SmartAlertRule> rules;
  final bool active;
  final DateTime? lastTriggered;
  final DateTime createdAt;
  final String? deviceToken; // Optional: specific device

  CustomAlert({
    required this.id,
    required this.userId,
    required this.symbol,
    required this.type,
    required this.condition,
    required this.value,
    this.period,
    this.logic = AlertLogic.all,
    this.rules = const [],
    this.active = true,
    this.lastTriggered,
    required this.createdAt,
    this.deviceToken,
  });

  factory CustomAlert.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    final rulesData = data['rules'];
    final rules = (rulesData is List)
        ? rulesData
            .whereType<Map>()
            .map((rule) =>
                SmartAlertRule.fromMap(Map<String, dynamic>.from(rule as Map)))
            .toList()
        : <SmartAlertRule>[];

    return CustomAlert(
      id: doc.id,
      userId: data['userId'] ?? '',
      symbol: data['symbol'] ?? '',
      type: AlertType.values.firstWhere(
        (e) => e.name == (data['type'] ?? 'price'),
        orElse: () => AlertType.price,
      ),
      condition: AlertCondition.values.firstWhere(
        (e) => e.name == (data['condition'] ?? 'above'),
        orElse: () => AlertCondition.above,
      ),
      value: (data['value'] ?? 0).toDouble(),
      period: data['period'],
      logic: AlertLogic.values.firstWhere(
        (e) => e.name == (data['logic'] ?? 'all'),
        orElse: () => AlertLogic.all,
      ),
      rules: rules,
      active: data['active'] ?? true,
      lastTriggered: data['lastTriggered'] != null
          ? (data['lastTriggered'] as Timestamp).toDate()
          : null,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      deviceToken: data['deviceToken'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'symbol': symbol,
      'type': type.name,
      'condition': condition.name,
      'value': value,
      'period': period,
      'logic': logic.name,
      'rules': rules.map((rule) => rule.toMap()).toList(),
      'active': active,
      'lastTriggered':
          lastTriggered != null ? Timestamp.fromDate(lastTriggered!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'deviceToken': deviceToken,
    };
  }
}
