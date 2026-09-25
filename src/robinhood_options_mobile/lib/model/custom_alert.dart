// ignore_for_file: constant_identifier_names

import 'package:cloud_firestore/cloud_firestore.dart';

enum AlertType {
  price,
  volume,
  volatility,
  moving_average,
  rsi,
  gex,
  gamma_squeeze,
  earnings_iv_crush,
  volatility_cone,
  iv_surface,
  delta_neutral,
  dynamic_threshold,
  earnings_calendar,
  dividend_payment,
  news,
  unusual_activity,
  custom
}

enum AlertCondition {
  above,
  below,
  spike,
  drop,
  percent_change,
  above_call_wall,
  below_put_wall,
  above_gamma_flip,
  below_gamma_flip,
  above_crush_probability,
  above_implied_move,
  above_iv_rank,
  below_iv_rank,
  above_vrp,
  surface_inversion,
  above_surface_skew,
  arbitrage_detected,
  delta_drift_exceeded,
  delta_rebalance_required,
  above_band,
  below_band,
  earnings_today,
  earnings_tomorrow,
  earnings_imminent,
  days_until_earnings,
  ex_dividend_today,
  ex_dividend_tomorrow,
  ex_dividend_imminent,
  dividend_payable_today,
  dividend_payable_upcoming,
  days_until_ex_dividend,
  days_until_dividend_payable,
  high_impact_news,
  sentiment_bearish,
  sentiment_bullish,
  sentiment_drop_24h,
  sentiment_surge_24h,
  unusual_volume,
  unusual_options_volume,
  price_spike,
  price_drop,
  volume_spike
}

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
                SmartAlertRule.fromMap(Map<String, dynamic>.from(rule)))
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
