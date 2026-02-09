import 'package:cloud_firestore/cloud_firestore.dart';

enum AlertType { price, volume, volatility, moving_average, rsi, custom }

enum AlertCondition { above, below, spike, drop, percent_change }

class CustomAlert {
  final String id;
  final String userId;
  final String symbol;
  final AlertType type;
  final AlertCondition condition;
  final double value; // Threshold value
  final int?
      period; // Period for technical indicators (e.g. 50 for SMA, 14 for RSI)
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
    this.active = true,
    this.lastTriggered,
    required this.createdAt,
    this.deviceToken,
  });

  factory CustomAlert.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
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
      'active': active,
      'lastTriggered':
          lastTriggered != null ? Timestamp.fromDate(lastTriggered!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'deviceToken': deviceToken,
    };
  }
}
