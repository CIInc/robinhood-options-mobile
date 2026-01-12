import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:robinhood_options_mobile/utils/json.dart';

class CopyTradeLeg {
  final DateTime? expirationDate;
  final double? strikePrice;
  final String? optionType;
  final String? side;
  final String? positionEffect;
  final double? ratioQuantity;

  CopyTradeLeg({
    this.expirationDate,
    this.strikePrice,
    this.optionType,
    this.side,
    this.positionEffect,
    this.ratioQuantity,
  });

  CopyTradeLeg.fromJson(Map<String, dynamic> json)
      : expirationDate = json['expirationDate'] != null
            ? (json['expirationDate'] is Timestamp
                ? (json['expirationDate'] as Timestamp).toDate()
                : (json['expirationDate'] is String
                    ? DateTime.tryParse(json['expirationDate'])
                    : null))
            : null,
        strikePrice = parseDouble(json['strikePrice']),
        optionType = json['optionType'],
        side = json['side'],
        positionEffect = json['positionEffect'],
        ratioQuantity = parseDouble(json['ratioQuantity']);
}

class CopyTradeRecord {
  final String id;
  final String sourceUserId;
  final String targetUserId;
  final String groupId;
  final String orderType;
  final String originalOrderId;
  final String symbol;
  final String side;
  final double originalQuantity;
  final double copiedQuantity;
  final double price;
  final String? strategy;
  final List<CopyTradeLeg>? legs;
  final DateTime timestamp;
  final bool executed;
  final String? executionResult;
  final String? error;
  final String status; // pending_approval, approved, rejected
  final bool isInverse;

  CopyTradeRecord({
    required this.id,
    required this.sourceUserId,
    required this.targetUserId,
    required this.groupId,
    required this.orderType,
    required this.originalOrderId,
    required this.symbol,
    required this.side,
    required this.originalQuantity,
    required this.copiedQuantity,
    required this.price,
    this.strategy,
    this.legs,
    required this.timestamp,
    required this.executed,
    this.executionResult,
    this.error,
    this.status = 'approved',
    this.isInverse = false,
  });

  CopyTradeRecord.fromDocument(DocumentSnapshot doc)
      : this.fromJson(doc.data() as Map<String, dynamic>, doc.id);

  CopyTradeRecord.fromJson(Map<String, dynamic> json, String id)
      : id = id,
        sourceUserId = json['sourceUserId'],
        targetUserId = json['targetUserId'],
        groupId = json['groupId'],
        orderType = json['orderType'],
        originalOrderId = json['originalOrderId'],
        symbol = json['symbol'],
        side = json['side'],
        originalQuantity = (json['originalQuantity'] as num).toDouble(),
        copiedQuantity = (json['copiedQuantity'] as num).toDouble(),
        price = (json['price'] as num).toDouble(),
        strategy = json['strategy'],
        legs = json['legs'] != null
            ? (json['legs'] as List)
                .map((e) => CopyTradeLeg.fromJson(e))
                .toList()
            : null,
        timestamp = (json['timestamp'] as Timestamp).toDate(),
        executed = json['executed'] ?? false,
        executionResult = json['executionResult'],
        error = json['error'],
        status = json['status'] ?? 'approved',
        isInverse = json['isInverse'] ?? false;
}
