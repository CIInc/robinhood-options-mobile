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
  final DateTime? executionTime;
  final double? executedPrice;
  final int? fillLatencyMs;
  final double? priceSlippage;
  final double? slippageBps;
  final double? leaderReturnPct;
  final double? followerReturnPct;
  final double? returnDivergencePct;

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
    this.executionTime,
    this.executedPrice,
    this.fillLatencyMs,
    this.priceSlippage,
    this.slippageBps,
    this.leaderReturnPct,
    this.followerReturnPct,
    this.returnDivergencePct,
  });

  CopyTradeRecord.fromDocument(DocumentSnapshot doc)
      : this.fromJson(doc.data() as Map<String, dynamic>, doc.id);

  CopyTradeRecord.fromJson(Map<String, dynamic> json, this.id)
      : sourceUserId = json['sourceUserId'],
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
        timestamp = json['timestamp'] is Timestamp
            ? (json['timestamp'] as Timestamp).toDate()
            : (json['timestamp'] is String
                ? DateTime.tryParse(json['timestamp']) ?? DateTime.now()
                : DateTime.now()),
        executed = json['executed'] ?? false,
        executionResult = json['executionResult'],
        error = json['error'],
        status = json['status'] ?? 'approved',
        isInverse = json['isInverse'] ?? false,
        executionTime = json['executionTime'] != null
            ? (json['executionTime'] is Timestamp
                ? (json['executionTime'] as Timestamp).toDate()
                : (json['executionTime'] is String
                    ? DateTime.tryParse(json['executionTime'])
                    : null))
            : null,
        executedPrice = parseDouble(json['executedPrice']),
        fillLatencyMs = json['fillLatencyMs'] is num
            ? (json['fillLatencyMs'] as num).toInt()
            : null,
        priceSlippage = parseDouble(json['priceSlippage']),
        slippageBps = parseDouble(json['slippageBps']),
        leaderReturnPct = parseDouble(json['leaderReturnPct']),
        followerReturnPct = parseDouble(json['followerReturnPct']),
        returnDivergencePct = parseDouble(json['returnDivergencePct']);

  Map<String, dynamic> toJson() {
    return {
      'sourceUserId': sourceUserId,
      'targetUserId': targetUserId,
      'groupId': groupId,
      'orderType': orderType,
      'originalOrderId': originalOrderId,
      'symbol': symbol,
      'side': side,
      'originalQuantity': originalQuantity,
      'copiedQuantity': copiedQuantity,
      'price': price,
      if (strategy != null) 'strategy': strategy,
      if (legs != null)
        'legs': legs!
            .map((e) => {
                  'expirationDate': e.expirationDate?.toIso8601String(),
                  'strikePrice': e.strikePrice,
                  'optionType': e.optionType,
                  'side': e.side,
                  'positionEffect': e.positionEffect,
                  'ratioQuantity': e.ratioQuantity,
                })
            .toList(),
      'timestamp': Timestamp.fromDate(timestamp),
      'executed': executed,
      if (executionResult != null) 'executionResult': executionResult,
      if (error != null) 'error': error,
      'status': status,
      'isInverse': isInverse,
      if (executionTime != null)
        'executionTime': Timestamp.fromDate(executionTime!),
      if (executedPrice != null) 'executedPrice': executedPrice,
      if (fillLatencyMs != null) 'fillLatencyMs': fillLatencyMs,
      if (priceSlippage != null) 'priceSlippage': priceSlippage,
      if (slippageBps != null) 'slippageBps': slippageBps,
      if (leaderReturnPct != null) 'leaderReturnPct': leaderReturnPct,
      if (followerReturnPct != null) 'followerReturnPct': followerReturnPct,
      if (returnDivergencePct != null)
        'returnDivergencePct': returnDivergencePct,
    };
  }

  /// Follower's executed fill price, falling back to original price if missing.
  double get effectiveExecutedPrice => executedPrice ?? price;

  /// Effective latency in milliseconds from leader signal to follower execution.
  int? get effectiveFillLatencyMs {
    if (fillLatencyMs != null) return fillLatencyMs;
    if (executionTime != null) {
      final delta = executionTime!.difference(timestamp).inMilliseconds;
      return delta >= 0 ? delta : 0;
    }
    return null;
  }

  /// Dollar slippage per unit/share:
  /// For Buy: executedPrice - price (positive = unfavorable / paid premium)
  /// For Sell: price - executedPrice (positive = unfavorable / sold at discount)
  double get dollarSlippage {
    if (priceSlippage != null) return priceSlippage!;
    if (executedPrice == null) return 0.0;
    final isBuy = side.toLowerCase().contains('buy');
    return isBuy ? (executedPrice! - price) : (price - executedPrice!);
  }

  /// Slippage in basis points relative to leader price.
  double get effectiveSlippageBps {
    if (slippageBps != null) return slippageBps!;
    if (price <= 0) return 0.0;
    return (dollarSlippage / price) * 10000.0;
  }

  /// Returns true if execution achieved a better fill price than the leader.
  bool get isFavorableSlippage => dollarSlippage < -0.0001;

  /// Returns true if execution suffered a worse fill price than the leader.
  bool get isUnfavorableSlippage => dollarSlippage > 0.0001;

  /// Returns true if execution matched the leader's price within sub-cent tolerance.
  bool get isZeroSlippage => !isFavorableSlippage && !isUnfavorableSlippage;

  /// Effective net return divergence between follower and leader.
  double? get effectiveReturnDivergencePct {
    if (returnDivergencePct != null) return returnDivergencePct;
    if (followerReturnPct != null && leaderReturnPct != null) {
      return followerReturnPct! - leaderReturnPct!;
    }
    return null;
  }

  /// Returns true if the copy trade was aborted by Risk Guardian or safety limits.
  bool get isAborted =>
      status == 'aborted' ||
      (executionResult != null && executionResult!.startsWith('aborted'));

  /// Returns true if aborted specifically due to excessive price slippage.
  bool get isAbortedMaxSlippage => executionResult == 'aborted_max_slippage';

  /// Returns true if aborted specifically due to capital allocation limits.
  bool get isAbortedAllocation =>
      executionResult == 'aborted_allocation_limit' ||
      executionResult == 'aborted_min_allocation';

  /// Returns true if aborted because the Risk Guardian circuit breaker was tripped.
  bool get isAbortedRiskGuardian =>
      executionResult == 'aborted_risk_guardian_tripped';
}
