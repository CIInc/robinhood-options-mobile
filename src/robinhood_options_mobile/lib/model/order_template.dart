import 'package:cloud_firestore/cloud_firestore.dart';

class OrderTemplate {
  final String id;
  final String userId;
  final String name;
  final String? symbol; // Optional, if null, applies to any
  final String positionType; // Buy/Sell
  final String orderType; // Market, Limit, etc.
  final String timeInForce;
  final String? trailingType;
  final double? quantity;
  final double? price;
  final double? stopPrice;
  final double? trailingAmount;
  final DateTime createdAt;
  final DateTime updatedAt;

  OrderTemplate({
    required this.id,
    required this.userId,
    required this.name,
    this.symbol,
    required this.positionType,
    required this.orderType,
    required this.timeInForce,
    this.trailingType,
    this.quantity,
    this.price,
    this.stopPrice,
    this.trailingAmount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OrderTemplate.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return OrderTemplate(
      id: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      symbol: data['symbol'],
      positionType: data['positionType'] ?? 'Buy',
      orderType: data['orderType'] ?? 'Market',
      timeInForce: data['timeInForce'] ?? 'gtc',
      trailingType: data['trailingType'],
      quantity: data['quantity']?.toDouble(),
      price: data['price']?.toDouble(),
      stopPrice: data['stopPrice']?.toDouble(),
      trailingAmount: data['trailingAmount']?.toDouble(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'symbol': symbol,
      'positionType': positionType,
      'orderType': orderType,
      'timeInForce': timeInForce,
      'trailingType': trailingType,
      'quantity': quantity,
      'price': price,
      'stopPrice': stopPrice,
      'trailingAmount': trailingAmount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
