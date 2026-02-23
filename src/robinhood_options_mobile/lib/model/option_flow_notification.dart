import 'package:cloud_firestore/cloud_firestore.dart';

class OptionFlowNotification {
  final String id;
  final String symbol;
  final String sentiment;
  final double? premium;
  final int? volume;
  final String? expirationDate;
  final String? type;
  final String? flowType;
  final List<String> flags;
  final String title;
  final String body;
  final bool read;
  final DateTime timestamp;
  final Map<String, dynamic>? data;

  OptionFlowNotification({
    required this.id,
    required this.symbol,
    required this.sentiment,
    this.premium,
    this.volume,
    this.expirationDate,
    this.type,
    this.flowType,
    this.flags = const [],
    required this.title,
    required this.body,
    required this.read,
    required this.timestamp,
    this.data,
  });

  factory OptionFlowNotification.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawFlags = data['flags'];
    final parsedFlags = rawFlags is List
        ? rawFlags.map((e) => e.toString()).toList()
        : <String>[];

    return OptionFlowNotification(
      id: doc.id,
      symbol: data['symbol'] ?? '',
      sentiment: data['sentiment'] ?? '',
      premium: (data['premium'] as num?)?.toDouble(),
      volume: (data['volume'] as num?)?.toInt(),
      expirationDate: data['expirationDate'] as String?,
      type: data['type'] as String?,
      flowType: data['flowType'] as String?,
      flags: parsedFlags,
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      read: data['read'] ?? false,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      data: data['data'] as Map<String, dynamic>?,
    );
  }
}
