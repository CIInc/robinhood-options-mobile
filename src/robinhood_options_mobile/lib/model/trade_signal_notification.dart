import 'package:cloud_firestore/cloud_firestore.dart';

class TradeSignalNotification {
  final String id;
  final String symbol;
  final String signal; // BUY, SELL, HOLD
  final String interval;
  final double? price;
  final double? confidence;
  final DateTime timestamp;
  final String title;
  final String body;
  final bool read;
  final Map<String, dynamic>? indicators;

  TradeSignalNotification({
    required this.id,
    required this.symbol,
    required this.signal,
    required this.interval,
    this.price,
    this.confidence,
    required this.timestamp,
    required this.title,
    required this.body,
    required this.read,
    this.indicators,
  });

  factory TradeSignalNotification.fromDocument(DocumentSnapshot doc) {
    // print(doc.data());
    final data = doc.data() as Map<String, dynamic>;
    return TradeSignalNotification(
      id: doc.id,
      symbol: data['symbol'] ?? '',
      signal: data['signal'] ?? '',
      interval: data['interval'] ?? '1d',
      price: (data['price'] as num?)?.toDouble(),
      confidence: (data['confidence'] as num?)?.toDouble(),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      read: data['read'] ?? false,
      indicators: data['indicators'] as Map<String, dynamic>?,
    );
  }
}
