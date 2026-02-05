import 'package:cloud_firestore/cloud_firestore.dart';

class OptionEvent {
  final String account;
  final String? cashComponent;
  final String chainId;
  final DateTime? createdAt;
  final String direction;
  final List<String> equityComponents;
  final DateTime? eventDate;
  final String id;
  final String option;
  final String position;
  final double? quantity;
  final String? sourceRefId;
  final String state;
  final double? totalCashAmount;
  final String type;
  final double? underlyingPrice;
  final DateTime? updatedAt;

  OptionEvent(
      this.account,
      this.cashComponent,
      this.chainId,
      this.createdAt,
      this.direction,
      this.equityComponents,
      this.eventDate,
      this.id,
      this.option,
      this.position,
      this.quantity,
      this.sourceRefId,
      this.state,
      this.totalCashAmount,
      this.type,
      this.underlyingPrice,
      this.updatedAt);

  OptionEvent.fromJson(dynamic json)
      : account = json['account'],
        cashComponent = json['cash_component'],
        chainId = json['chain_id'],
        createdAt = json['created_at'] is Timestamp
            ? (json['created_at'] as Timestamp).toDate()
            : (json['created_at'] is String
                ? DateTime.tryParse(json['created_at'])
                : null),
        direction = json['direction'],
        equityComponents =
            List<String>.from(json['equity_components']?.map((e) => e.toString()) ?? []),
        eventDate = json['event_date'] is Timestamp
            ? (json['event_date'] as Timestamp).toDate()
            : (json['event_date'] is String
                ? DateTime.tryParse(json['event_date'])
                : null),
        id = json['id'],
        option = json['option'],
        position = json['position'],
        quantity = json['quantity'] is num
            ? (json['quantity'] as num).toDouble()
            : double.tryParse(json['quantity'] ?? ''),
        sourceRefId = json['source_ref_id'],
        state = json['state'],
        totalCashAmount = json['total_cash_amount'] is num
             ? (json['total_cash_amount'] as num).toDouble()
             : double.tryParse(json['total_cash_amount'] ?? ''),
        type = json['type'],
        underlyingPrice = json['underlying_price'] is num
            ? (json['underlying_price'] as num).toDouble()
            : (json['underlying_price'] != null
                ? double.tryParse(json['underlying_price'])
                : null),
        updatedAt = json['updated_at'] is Timestamp
            ? (json['updated_at'] as Timestamp).toDate()
            : (json['updated_at'] is String
                ? DateTime.tryParse(json['updated_at'])
                : null);

  Map<String, dynamic> toJson() => {
        'account': account,
        'cash_component': cashComponent,
        'chain_id': chainId,
        'created_at': createdAt,
        'direction': direction,
        'equity_components': equityComponents,
        'event_date': eventDate,
        'id': id,
        'option': option,
        'position': position,
        'quantity': quantity,
        'source_ref_id': sourceRefId,
        'state': state,
        'total_cash_amount': totalCashAmount,
        'type': type,
        'underlying_price': underlyingPrice,
        'updated_at': updatedAt
      };
}
