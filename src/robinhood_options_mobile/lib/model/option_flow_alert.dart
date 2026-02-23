import 'package:cloud_firestore/cloud_firestore.dart';

class OptionFlowAlert {
  final String id;
  final String uid;
  final String symbol;
  final double minPremium;
  final int? minVolume;
  final String sentiment; // 'bullish', 'bearish', 'any'
  final String condition; // 'above', 'below'
  final String expirationRange; // 'any', '0-7', '8-30', '30+'
  final List<String> flags;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  double get targetPremium => minPremium;

  OptionFlowAlert({
    required this.id,
    required this.uid,
    required this.symbol,
    required this.minPremium,
    this.minVolume,
    this.sentiment = 'any',
    this.condition = 'above',
    this.expirationRange = 'any',
    this.flags = const [],
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  factory OptionFlowAlert.fromMap(String id, Map<String, dynamic> map) {
    return OptionFlowAlert(
      id: id,
      uid: map['uid'] as String? ?? '',
      symbol: map['symbol'] as String? ?? '',
      minPremium: (map['minPremium'] as num?)?.toDouble() ??
          (map['targetPremium'] as num?)?.toDouble() ??
          50000.0,
      minVolume: (map['minVolume'] as num?)?.toInt(),
      sentiment: map['sentiment'] as String? ?? 'any',
      condition: map['condition'] as String? ?? 'above',
      expirationRange: map['expirationRange'] as String? ?? 'any',
      flags:
          (map['flags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
              const [],
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
      'minPremium': minPremium,
      'targetPremium': minPremium,
      'minVolume': minVolume,
      'sentiment': sentiment,
      'condition': condition,
      'expirationRange': expirationRange,
      'flags': flags,
      'isActive': isActive,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
