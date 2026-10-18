import 'package:cloud_firestore/cloud_firestore.dart';

class InstrumentNote {
  final String symbol;
  final String note;
  final DateTime createdAt;
  final DateTime updatedAt;

  InstrumentNote({
    required this.symbol,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  factory InstrumentNote.fromJson(Map<String, dynamic> json) {
    return InstrumentNote(
      symbol: json['symbol'] as String,
      note: json['note'] as String,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'note': note,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
