import 'package:flutter/material.dart';

enum CongressChamber {
  house,
  senate,
  unknown;

  static CongressChamber fromString(String? value) {
    if (value == null) return CongressChamber.unknown;
    final lower = value.trim().toLowerCase();
    if (lower == 'house' || lower.contains('representative')) {
      return CongressChamber.house;
    }
    if (lower == 'senate' || lower.contains('senat')) {
      return CongressChamber.senate;
    }
    return CongressChamber.unknown;
  }

  String get displayName {
    switch (this) {
      case CongressChamber.house:
        return 'House';
      case CongressChamber.senate:
        return 'Senate';
      case CongressChamber.unknown:
        return 'Congress';
    }
  }

  String get titlePrefix {
    switch (this) {
      case CongressChamber.house:
        return 'Rep.';
      case CongressChamber.senate:
        return 'Sen.';
      case CongressChamber.unknown:
        return 'Hon.';
    }
  }
}

enum CongressParty {
  democrat,
  republican,
  independent,
  other;

  static CongressParty fromString(String? value) {
    if (value == null) return CongressParty.other;
    final lower = value.trim().toLowerCase();
    if (lower == 'democrat' || lower == 'd') {
      return CongressParty.democrat;
    }
    if (lower == 'republican' || lower == 'r') {
      return CongressParty.republican;
    }
    if (lower == 'independent' || lower == 'i') {
      return CongressParty.independent;
    }
    return CongressParty.other;
  }

  String get shortCode {
    switch (this) {
      case CongressParty.democrat:
        return 'D';
      case CongressParty.republican:
        return 'R';
      case CongressParty.independent:
        return 'I';
      case CongressParty.other:
        return 'O';
    }
  }

  String get displayName {
    switch (this) {
      case CongressParty.democrat:
        return 'Democrat';
      case CongressParty.republican:
        return 'Republican';
      case CongressParty.independent:
        return 'Independent';
      case CongressParty.other:
        return 'Other';
    }
  }

  Color get color {
    switch (this) {
      case CongressParty.democrat:
        return Colors.blue;
      case CongressParty.republican:
        return Colors.red;
      case CongressParty.independent:
        return Colors.purple;
      case CongressParty.other:
        return Colors.grey;
    }
  }
}

enum CongressTransactionType {
  purchase,
  sale,
  salePartial,
  exchange,
  unknown;

  static CongressTransactionType fromString(String? value) {
    if (value == null) return CongressTransactionType.unknown;
    final lower = value.trim().toLowerCase();
    if (lower == 'purchase' || lower == 'buy') {
      return CongressTransactionType.purchase;
    }
    if (lower == 'sale (partial)' || lower == 'partial sale') {
      return CongressTransactionType.salePartial;
    }
    if (lower == 'sale' || lower == 'sell') {
      return CongressTransactionType.sale;
    }
    if (lower == 'exchange') {
      return CongressTransactionType.exchange;
    }
    return CongressTransactionType.unknown;
  }

  String get displayName {
    switch (this) {
      case CongressTransactionType.purchase:
        return 'Purchase';
      case CongressTransactionType.sale:
        return 'Sale';
      case CongressTransactionType.salePartial:
        return 'Sale (Partial)';
      case CongressTransactionType.exchange:
        return 'Exchange';
      case CongressTransactionType.unknown:
        return 'Trade';
    }
  }

  bool get isPurchase => this == CongressTransactionType.purchase;

  bool get isSale =>
      this == CongressTransactionType.sale ||
      this == CongressTransactionType.salePartial;

  Color get color {
    if (isPurchase) return Colors.green;
    if (isSale) return Colors.red;
    return Colors.amber;
  }
}

class CongressTrade {
  final String id;
  final String politicianName;
  final CongressChamber chamber;
  final CongressParty party;
  final String state;
  final String? district;
  final String symbol;
  final String assetDescription;
  final CongressTransactionType transactionType;
  final String amount;
  final double amountMin;
  final double? amountMax;
  final DateTime transactionDate;
  final DateTime disclosureDate;
  final String owner;
  final String sourceUrl;
  final String? comment;
  final bool isOverdue;
  final int filingLagDays;

  const CongressTrade({
    required this.id,
    required this.politicianName,
    required this.chamber,
    required this.party,
    required this.state,
    this.district,
    required this.symbol,
    required this.assetDescription,
    required this.transactionType,
    required this.amount,
    required this.amountMin,
    this.amountMax,
    required this.transactionDate,
    required this.disclosureDate,
    required this.owner,
    required this.sourceUrl,
    this.comment,
    required this.isOverdue,
    required this.filingLagDays,
  });

  String get politicianTitle => '${chamber.titlePrefix} $politicianName';

  String get politicalAffiliation {
    if (district != null && district!.isNotEmpty) {
      return '${party.shortCode}-$district';
    }
    return '${party.shortCode}-$state';
  }

  factory CongressTrade.fromJson(Map<String, dynamic> json) {
    final txDateStr = (json['transactionDate'] ?? '').toString();
    final discDateStr = (json['disclosureDate'] ?? '').toString();

    final txDate = DateTime.tryParse(txDateStr) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final discDate = DateTime.tryParse(discDateStr) ??
        DateTime.fromMillisecondsSinceEpoch(0);

    final rawAmountMin = json['amountMin'];
    final rawAmountMax = json['amountMax'];
    final minVal = rawAmountMin is num
        ? rawAmountMin.toDouble()
        : double.tryParse(rawAmountMin?.toString() ?? '') ?? 0.0;
    final maxVal = rawAmountMax is num
        ? rawAmountMax.toDouble()
        : double.tryParse(rawAmountMax?.toString() ?? '');

    final lag = json['filingLagDays'] is int
        ? json['filingLagDays'] as int
        : (discDate.difference(txDate).inDays > 0
            ? discDate.difference(txDate).inDays
            : 0);

    return CongressTrade(
      id: (json['id'] ?? '').toString(),
      politicianName: (json['politicianName'] ?? '').toString(),
      chamber: CongressChamber.fromString((json['chamber'] ?? '').toString()),
      party: CongressParty.fromString((json['party'] ?? '').toString()),
      state: (json['state'] ?? '').toString(),
      district: json['district']?.toString(),
      symbol: (json['symbol'] ?? '').toString().toUpperCase(),
      assetDescription: (json['assetDescription'] ?? '').toString(),
      transactionType: CongressTransactionType.fromString(
          (json['transactionType'] ?? '').toString()),
      amount: (json['amount'] ?? '').toString(),
      amountMin: minVal,
      amountMax: maxVal,
      transactionDate: txDate,
      disclosureDate: discDate,
      owner: (json['owner'] ?? 'Self').toString(),
      sourceUrl: (json['sourceUrl'] ?? '').toString(),
      comment: json['comment']?.toString(),
      isOverdue: json['isOverdue'] == true || lag > 45,
      filingLagDays: lag,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'politicianName': politicianName,
      'chamber': chamber.displayName,
      'party': party.displayName,
      'state': state,
      'district': district,
      'symbol': symbol,
      'assetDescription': assetDescription,
      'transactionType': transactionType.displayName,
      'amount': amount,
      'amountMin': amountMin,
      'amountMax': amountMax,
      'transactionDate': transactionDate.toIso8601String().split('T')[0],
      'disclosureDate': disclosureDate.toIso8601String().split('T')[0],
      'owner': owner,
      'sourceUrl': sourceUrl,
      'comment': comment,
      'isOverdue': isOverdue,
      'filingLagDays': filingLagDays,
    };
  }
}

class CongressTradingSnapshot {
  final String? symbol;
  final List<CongressTrade> trades;
  final bool portfolioOverlap;
  final List<String> overlappingSymbols;
  final int totalTrades;
  final double totalPurchases;
  final double totalSales;
  final double netPurchases;
  final DateTime updatedAt;

  const CongressTradingSnapshot({
    this.symbol,
    required this.trades,
    required this.portfolioOverlap,
    required this.overlappingSymbols,
    required this.totalTrades,
    required this.totalPurchases,
    required this.totalSales,
    required this.netPurchases,
    required this.updatedAt,
  });

  factory CongressTradingSnapshot.fromJson(Map<String, dynamic> json) {
    final rawTrades = json['trades'];
    final parsedTrades = <CongressTrade>[];
    if (rawTrades is List) {
      for (final item in rawTrades) {
        if (item is Map) {
          parsedTrades.add(
            CongressTrade.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    final rawSymbols = json['overlappingSymbols'];
    final symbols = <String>[];
    if (rawSymbols is List) {
      for (final s in rawSymbols) {
        if (s != null) symbols.add(s.toString().toUpperCase());
      }
    }

    final updated = DateTime.tryParse((json['updatedAt'] ?? '').toString()) ??
        DateTime.now();

    final totPurchases = json['totalPurchases'] is num
        ? (json['totalPurchases'] as num).toDouble()
        : double.tryParse(json['totalPurchases']?.toString() ?? '') ?? 0.0;

    final totSales = json['totalSales'] is num
        ? (json['totalSales'] as num).toDouble()
        : double.tryParse(json['totalSales']?.toString() ?? '') ?? 0.0;

    final netP = json['netPurchases'] is num
        ? (json['netPurchases'] as num).toDouble()
        : double.tryParse(json['netPurchases']?.toString() ?? '') ??
            (totPurchases - totSales);

    return CongressTradingSnapshot(
      symbol: json['symbol']?.toString().toUpperCase(),
      trades: parsedTrades,
      portfolioOverlap: json['portfolioOverlap'] == true,
      overlappingSymbols: symbols,
      totalTrades: json['totalTrades'] is int
          ? json['totalTrades'] as int
          : parsedTrades.length,
      totalPurchases: totPurchases,
      totalSales: totSales,
      netPurchases: netP,
      updatedAt: updated,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'trades': trades.map((t) => t.toJson()).toList(),
      'portfolioOverlap': portfolioOverlap,
      'overlappingSymbols': overlappingSymbols,
      'totalTrades': totalTrades,
      'totalPurchases': totalPurchases,
      'totalSales': totalSales,
      'netPurchases': netPurchases,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
