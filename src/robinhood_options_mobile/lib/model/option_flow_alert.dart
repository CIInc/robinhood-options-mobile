import 'package:cloud_firestore/cloud_firestore.dart';

class OptionFlowAlert {
  final String id;
  final String uid;
  final String symbol;
  final double targetPremium;
  final String sentiment; // 'bullish', 'bearish', 'any'
  final String condition; // 'above', 'below'
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  OptionFlowAlert({
    required this.id,
    required this.uid,
    required this.symbol,
    required this.targetPremium,
    this.sentiment = 'any',
    this.condition = 'above',
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  factory OptionFlowAlert.fromMap(String id, Map<String, dynamic> map) {
    return OptionFlowAlert(
      id: id,
      uid: map['uid'] as String? ?? '',
      symbol: map['symbol'] as String? ?? '',
      targetPremium: (map['targetPremium'] as num?)?.toDouble() ?? 50000.0,
      sentiment: map['sentiment'] as String? ?? 'any',
      condition: map['condition'] as String? ?? 'above',
      isActive: map['isActive'] as bool? ?? true,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'symbol': symbol,
      'targetPremium': targetPremium,
      'sentiment': sentiment,
      'condition': condition,
      'isActive': isActive,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
