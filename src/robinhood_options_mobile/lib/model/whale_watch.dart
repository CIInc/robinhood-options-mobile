import 'package:cloud_firestore/cloud_firestore.dart';

class WhaleWatchTransaction {
  final String symbol;
  final String filerName;
  final String filerRelation;
  final String transactionText;
  final num shares;
  final double value;
  final DateTime date;
  final String ownership;
  final bool isBuy;
  final bool isSale;
  final bool isOptionExercise;

  WhaleWatchTransaction({
    required this.symbol,
    required this.filerName,
    required this.filerRelation,
    required this.transactionText,
    required this.shares,
    required this.value,
    required this.date,
    required this.ownership,
    required this.isBuy,
    required this.isSale,
    required this.isOptionExercise,
  });

  factory WhaleWatchTransaction.fromJson(Map<String, dynamic> json) {
    return WhaleWatchTransaction(
      symbol: json['symbol'] ?? '',
      filerName: json['filerName'] ?? 'Unknown',
      filerRelation: json['filerRelation'] ?? 'Unknown',
      transactionText: json['transactionText'] ?? '',
      shares: json['shares'] ?? 0,
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      date:
          json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      ownership: json['ownership'] ?? '',
      isBuy: json['isBuy'] ?? false,
      isSale: json['isSale'] ?? false,
      isOptionExercise: json['isOptionExercise'] ?? false,
    );
  }
}

class InstitutionalAccumulation {
  final String symbol;
  final String institutionName;
  final num sharesHeld;
  final num changeInShares;
  final double percentChange;
  final double positionValue;
  final DateTime reportDate;

  InstitutionalAccumulation({
    required this.symbol,
    required this.institutionName,
    required this.sharesHeld,
    required this.changeInShares,
    required this.percentChange,
    required this.positionValue,
    required this.reportDate,
  });

  factory InstitutionalAccumulation.fromJson(Map<String, dynamic> json) {
    return InstitutionalAccumulation(
      symbol: json['symbol'] ?? '',
      institutionName: json['institutionName'] ?? 'Unknown',
      sharesHeld: json['sharesHeld'] ?? 0,
      changeInShares: json['changeInShares'] ?? 0,
      percentChange: (json['percentChange'] as num?)?.toDouble() ?? 0.0,
      positionValue: (json['positionValue'] as num?)?.toDouble() ?? 0.0,
      reportDate: json['reportDate'] != null
          ? DateTime.parse(json['reportDate'])
          : DateTime.now(),
    );
  }
}

class WhaleWatchAggregate {
  final double buyTotal;
  final double sellTotal;
  final int buyCount;
  final int sellCount;
  final List<TopAccumulatedSymbol> topAccumulatedSymbols;
  final List<WhaleWatchTransaction> recentLargeTransactions;
  final DateTime timestamp;

  WhaleWatchAggregate({
    required this.buyTotal,
    required this.sellTotal,
    required this.buyCount,
    required this.sellCount,
    required this.topAccumulatedSymbols,
    required this.recentLargeTransactions,
    required this.timestamp,
  });

  factory WhaleWatchAggregate.fromSnapshot(
      DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? {};
    return WhaleWatchAggregate(
      buyTotal: (data['buyTotal'] as num?)?.toDouble() ?? 0.0,
      sellTotal: (data['sellTotal'] as num?)?.toDouble() ?? 0.0,
      buyCount: data['buyCount'] ?? 0,
      sellCount: data['sellCount'] ?? 0,
      topAccumulatedSymbols: (data['topAccumulatedSymbols'] as List?)
              ?.map((e) => TopAccumulatedSymbol.fromJson(e))
              .toList() ??
          [],
      recentLargeTransactions: (data['recentLargeTransactions'] as List?)
              ?.map((e) => WhaleWatchTransaction.fromJson(e))
              .toList() ??
          [],
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class TopAccumulatedSymbol {
  final String symbol;
  final num score;

  TopAccumulatedSymbol({required this.symbol, required this.score});

  factory TopAccumulatedSymbol.fromJson(Map<String, dynamic> json) {
    return TopAccumulatedSymbol(
      symbol: json['symbol'] ?? '',
      score: json['score'] ?? 0,
    );
  }
}
