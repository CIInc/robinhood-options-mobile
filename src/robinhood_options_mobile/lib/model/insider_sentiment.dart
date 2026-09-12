import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

num? _parseNum(dynamic value) {
  if (value == null) return null;
  if (value is num) return value;
  return num.tryParse(value.toString());
}

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  final str = value.toString().trim();
  if (str.isEmpty) return null;
  try {
    return DateTime.parse(str);
  } catch (_) {
    try {
      return DateFormat('yyyy-MM-dd').parse(str);
    } catch (_) {
      return null;
    }
  }
}

/// Represents a single monthly aggregate record of insider buying and selling
@immutable
class MonthlyInsiderActivity {
  final String month; // e.g. "2026-08"
  final DateTime? monthDate;
  final num buyShares;
  final num sellShares;
  final double buyValue;
  final double sellValue;
  final num netShares;
  final double netValue;
  final int buyCount;
  final int sellCount;
  final String netSentiment; // "positive", "negative", "neutral"

  const MonthlyInsiderActivity({
    required this.month,
    this.monthDate,
    required this.buyShares,
    required this.sellShares,
    required this.buyValue,
    required this.sellValue,
    required this.netShares,
    required this.netValue,
    required this.buyCount,
    required this.sellCount,
    required this.netSentiment,
  });

  factory MonthlyInsiderActivity.fromJson(Map<String, dynamic> json) {
    final monthStr = (json['month'] ?? json['date'] ?? '').toString();
    DateTime? mDate;
    if (monthStr.isNotEmpty) {
      try {
        if (monthStr.length == 7) {
          mDate = DateFormat('yyyy-MM').parse(monthStr);
        } else {
          mDate = DateTime.tryParse(monthStr);
        }
      } catch (_) {}
    }

    final buyShares = _parseNum(json['buy_shares'] ?? json['buyShares']) ?? 0;
    final sellShares =
        _parseNum(json['sell_shares'] ?? json['sellShares']) ?? 0;
    final buyVal = _parseDouble(json['buy_value'] ?? json['buyValue']) ?? 0.0;
    final sellVal =
        _parseDouble(json['sell_value'] ?? json['sellValue']) ?? 0.0;
    final netSh = _parseNum(json['net_shares'] ?? json['netShares']) ??
        (buyShares - sellShares);
    final netVal = _parseDouble(json['net_value'] ?? json['netValue']) ??
        (buyVal - sellVal);
    final bCount = _parseInt(json['buy_count'] ?? json['buyCount']) ?? 0;
    final sCount = _parseInt(json['sell_count'] ?? json['sellCount']) ?? 0;

    String sentiment = (json['net_sentiment'] ??
            json['sentiment'] ??
            json['netSentiment'] ??
            '')
        .toString()
        .toLowerCase();
    if (sentiment.isEmpty) {
      if (netVal > 0 || netSh > 0) {
        sentiment = 'positive';
      } else if (netVal < 0 || netSh < 0) {
        sentiment = 'negative';
      } else {
        sentiment = 'neutral';
      }
    }

    return MonthlyInsiderActivity(
      month: monthStr,
      monthDate: mDate,
      buyShares: buyShares,
      sellShares: sellShares,
      buyValue: buyVal,
      sellValue: sellVal,
      netShares: netSh,
      netValue: netVal,
      buyCount: bCount,
      sellCount: sCount,
      netSentiment: sentiment,
    );
  }

  String get formattedMonth {
    if (monthDate != null) {
      return DateFormat('MMM yyyy').format(monthDate!);
    }
    return month;
  }
}

/// Represents an individual SEC Form 4 insider transaction
@immutable
class InsiderTransactionRecord {
  final String filerName;
  final String relationship; // e.g. "Chief Executive Officer", "Director"
  final DateTime? transactionDate;
  final DateTime? filingDate;
  final String
      transactionType; // "Purchase", "Sale", "Option Exercise", "Grant"
  final String transactionCode; // "P", "S", "M", "A", etc.
  final num shares;
  final double? price;
  final double? value;
  final num? sharesHeldAfter;
  final bool isDirect;
  final String? secForm4Url;

  const InsiderTransactionRecord({
    required this.filerName,
    required this.relationship,
    this.transactionDate,
    this.filingDate,
    required this.transactionType,
    required this.transactionCode,
    required this.shares,
    this.price,
    this.value,
    this.sharesHeldAfter,
    this.isDirect = true,
    this.secForm4Url,
  });

  bool get isBuy {
    final code = transactionCode.toUpperCase();
    final type = transactionType.toLowerCase();
    return code == 'P' ||
        type.contains('purchase') ||
        type.contains('buy') ||
        type.contains('acquisition');
  }

  bool get isSale {
    final code = transactionCode.toUpperCase();
    final type = transactionType.toLowerCase();
    return code == 'S' ||
        type.contains('sale') ||
        type.contains('sell') ||
        type.contains('disposition');
  }

  bool get isOption {
    final code = transactionCode.toUpperCase();
    final type = transactionType.toLowerCase();
    return code == 'M' || type.contains('option') || type.contains('exercise');
  }

  bool get isGrant {
    final code = transactionCode.toUpperCase();
    final type = transactionType.toLowerCase();
    return code == 'A' || type.contains('grant') || type.contains('award');
  }

  String get displayType {
    if (isBuy) return 'Purchase';
    if (isSale) return 'Sale';
    if (isOption) return 'Option Exercise';
    if (isGrant) return 'Grant / Award';
    return transactionType.isNotEmpty ? transactionType : 'Transaction';
  }

  Color get typeColor {
    if (isBuy) return Colors.green;
    if (isSale) return Colors.red;
    if (isOption) return Colors.orange;
    if (isGrant) return Colors.blue;
    return Colors.grey;
  }

  IconData get typeIcon {
    if (isBuy) return Icons.trending_up;
    if (isSale) return Icons.trending_down;
    if (isOption) return Icons.timelapse;
    if (isGrant) return Icons.card_giftcard;
    return Icons.swap_horiz;
  }

  factory InsiderTransactionRecord.fromJson(Map<String, dynamic> json) {
    // 1. Filer & role
    final filer = (json['filer_name'] ??
            json['filerName'] ??
            json['name'] ??
            json['insider_name'] ??
            '')
        .toString();
    final role = (json['relationship'] ??
            json['filerRelation'] ??
            json['title'] ??
            json['role'] ??
            '')
        .toString();

    // 2. Dates
    final tDate = _parseDate(json['transaction_date'] ??
        json['startDate'] ??
        json['date'] ??
        json['trans_date']);
    final fDate = _parseDate(
        json['filing_date'] ?? json['reported_date'] ?? json['file_date']);

    // 3. Codes & types
    final code =
        (json['transaction_code'] ?? json['code'] ?? json['trans_code'] ?? '')
            .toString()
            .trim();
    final type = (json['transaction_type'] ??
            json['transactionText'] ??
            json['type'] ??
            '')
        .toString()
        .trim();

    // 4. Shares, price, value
    num shares = 0;
    if (json['shares'] is Map && json['shares']['raw'] != null) {
      shares = (json['shares']['raw'] as num);
    } else {
      shares = _parseNum(json['shares'] ??
              json['shares_transacted'] ??
              json['sharesValue'] ??
              json['share_count']) ??
          0;
    }

    double? price;
    if (json['price'] != null) {
      price = _parseDouble(json['price'] ?? json['price_per_share']);
    }

    double? value;
    if (json['value'] is Map && json['value']['raw'] != null) {
      value = (json['value']['raw'] as num).toDouble();
    } else if (json['value'] != null) {
      value = _parseDouble(json['value'] ?? json['total_value']);
    }

    if (value == null && price != null && shares > 0) {
      value = price * shares;
    } else if (price == null && value != null && shares > 0) {
      price = value / shares;
    }

    final heldAfter = _parseNum(json['shares_held_after'] ??
        json['shares_held'] ??
        json['post_shares']);

    final ownership =
        (json['ownership'] ?? json['is_direct'] ?? '').toString().toUpperCase();
    final isDirect = ownership != 'I' && ownership != 'FALSE';

    final url = (json['sec_form4_url'] ??
            json['form4_url'] ??
            json['filerUrl'] ??
            json['url'])
        ?.toString();

    return InsiderTransactionRecord(
      filerName: filer,
      relationship: role,
      transactionDate: tDate,
      filingDate: fDate,
      transactionType: type,
      transactionCode: code,
      shares: shares,
      price: price,
      value: value,
      sharesHeldAfter: heldAfter,
      isDirect: isDirect,
      secForm4Url: url,
    );
  }
}

/// Comprehensive aggregate insider sentiment and transaction history summary
@immutable
class InsiderSentimentSummary {
  final String instrumentId;
  final String? symbol;
  final String netSentiment; // "positive", "negative", "neutral"
  final double? sentimentScore; // numeric score -100 to +100
  final num totalBuyShares;
  final num totalSellShares;
  final double totalBuyValue;
  final double totalSellValue;
  final int buyCount;
  final int sellCount;
  final num netShares;
  final double netValue;
  final List<MonthlyInsiderActivity> monthlySummary;
  final List<InsiderTransactionRecord> transactions;
  final DateTime? updatedAt;

  const InsiderSentimentSummary({
    required this.instrumentId,
    this.symbol,
    required this.netSentiment,
    this.sentimentScore,
    required this.totalBuyShares,
    required this.totalSellShares,
    required this.totalBuyValue,
    required this.totalSellValue,
    required this.buyCount,
    required this.sellCount,
    required this.netShares,
    required this.netValue,
    this.monthlySummary = const [],
    this.transactions = const [],
    this.updatedAt,
  });

  bool get isBullish =>
      netSentiment == 'positive' ||
      netSentiment == 'bullish' ||
      (sentimentScore != null && sentimentScore! > 5.0) ||
      (netValue > 0 && buyCount > sellCount);

  bool get isBearish =>
      netSentiment == 'negative' ||
      netSentiment == 'bearish' ||
      (sentimentScore != null && sentimentScore! < -5.0) ||
      (netValue < 0 && sellCount > buyCount);

  bool get isNeutral => !isBullish && !isBearish;

  String get sentimentBadge {
    if (isBullish) return 'Net Buying';
    if (isBearish) return 'Net Selling';
    return 'Neutral';
  }

  Color get sentimentColor {
    if (isBullish) return Colors.green;
    if (isBearish) return Colors.red;
    return Colors.grey;
  }

  double get buyPercentage {
    final total = totalBuyShares + totalSellShares;
    if (total <= 0) {
      final totalVal = totalBuyValue + totalSellValue;
      if (totalVal <= 0) return 50.0;
      return (totalBuyValue / totalVal) * 100.0;
    }
    return (totalBuyShares / total) * 100.0;
  }

  double get sellPercentage {
    final total = totalBuyShares + totalSellShares;
    if (total <= 0) {
      final totalVal = totalBuyValue + totalSellValue;
      if (totalVal <= 0) return 50.0;
      return (totalSellValue / totalVal) * 100.0;
    }
    return (totalSellShares / total) * 100.0;
  }

  String get formattedNetValue {
    final fmt = NumberFormat.compactSimpleCurrency();
    final sign = netValue > 0 ? '+' : '';
    return '$sign${fmt.format(netValue)}';
  }

  String get formattedTotalBuyValue {
    return NumberFormat.compactSimpleCurrency().format(totalBuyValue);
  }

  String get formattedTotalSellValue {
    return NumberFormat.compactSimpleCurrency().format(totalSellValue);
  }

  String get formattedNetShares {
    final fmt = NumberFormat.compact();
    final sign = netShares > 0 ? '+' : '';
    return '$sign${fmt.format(netShares)} shares';
  }

  factory InsiderSentimentSummary.fromResponses({
    dynamic summaryResponse,
    dynamic transactionsResponse,
    String? instrumentId,
    String? symbol,
  }) {
    // 1. Unwrap summary map if wrapped in { "status": "SUCCESS", "data": ... }
    Map<String, dynamic> summaryMap = {};
    if (summaryResponse is Map<String, dynamic>) {
      if (summaryResponse['data'] is Map<String, dynamic>) {
        summaryMap = summaryResponse['data'] as Map<String, dynamic>;
      } else {
        summaryMap = summaryResponse;
      }
    } else if (summaryResponse is Map) {
      summaryMap = Map<String, dynamic>.from(summaryResponse);
      if (summaryMap['data'] is Map) {
        summaryMap = Map<String, dynamic>.from(summaryMap['data'] as Map);
      }
    }

    // 2. Unwrap transactions list
    List<dynamic> rawTxList = [];
    if (transactionsResponse is List) {
      rawTxList = transactionsResponse;
    } else if (transactionsResponse is Map) {
      final txMap = Map<String, dynamic>.from(transactionsResponse);
      if (txMap['data'] is Map && (txMap['data'] as Map)['results'] is List) {
        rawTxList = (txMap['data'] as Map)['results'] as List;
      } else if (txMap['data'] is List) {
        rawTxList = txMap['data'] as List;
      } else if (txMap['results'] is List) {
        rawTxList = txMap['results'] as List;
      } else if (txMap['transactions'] is List) {
        rawTxList = txMap['transactions'] as List;
      }
    }

    final parsedTransactions = rawTxList
        .whereType<Map>()
        .map((e) =>
            InsiderTransactionRecord.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    // Sort transactions descending by date
    parsedTransactions.sort((a, b) {
      if (a.transactionDate == null && b.transactionDate == null) return 0;
      if (a.transactionDate == null) return 1;
      if (b.transactionDate == null) return -1;
      return b.transactionDate!.compareTo(a.transactionDate!);
    });

    // 3. Extract or compute summary values
    final resolvedInstrumentId = (summaryMap['instrument_id'] ??
            summaryMap['instrumentId'] ??
            instrumentId ??
            '')
        .toString();
    final resolvedSymbol = (summaryMap['symbol'] ?? symbol)?.toString();

    num buyShares = _parseNum(summaryMap['total_buy_shares'] ??
            summaryMap['buy_shares'] ??
            summaryMap['totalBuyShares']) ??
        0;
    num sellShares = _parseNum(summaryMap['total_sell_shares'] ??
            summaryMap['sell_shares'] ??
            summaryMap['totalSellShares']) ??
        0;
    double buyValue = _parseDouble(summaryMap['total_buy_value'] ??
            summaryMap['buy_value'] ??
            summaryMap['totalBuyValue']) ??
        0.0;
    double sellValue = _parseDouble(summaryMap['total_sell_value'] ??
            summaryMap['sell_value'] ??
            summaryMap['totalSellValue']) ??
        0.0;
    int bCount = _parseInt(summaryMap['buy_count'] ??
            summaryMap['buyCount'] ??
            summaryMap['num_buys']) ??
        0;
    int sCount = _parseInt(summaryMap['sell_count'] ??
            summaryMap['sellCount'] ??
            summaryMap['num_sells']) ??
        0;

    // If summary values are missing but we have transactions, calculate them:
    if (buyShares == 0 &&
        sellShares == 0 &&
        buyValue == 0.0 &&
        sellValue == 0.0 &&
        parsedTransactions.isNotEmpty) {
      for (final tx in parsedTransactions) {
        if (tx.isBuy) {
          buyShares += tx.shares;
          buyValue += (tx.value ?? 0.0);
          bCount++;
        } else if (tx.isSale) {
          sellShares += tx.shares;
          sellValue += (tx.value ?? 0.0);
          sCount++;
        }
      }
    }

    final netSh =
        _parseNum(summaryMap['net_shares'] ?? summaryMap['netShares']) ??
            (buyShares - sellShares);
    final netVal =
        _parseDouble(summaryMap['net_value'] ?? summaryMap['netValue']) ??
            (buyValue - sellValue);

    final score = _parseDouble(summaryMap['sentiment_score'] ??
        summaryMap['sentimentScore'] ??
        summaryMap['score']);

    String sentiment = (summaryMap['net_sentiment'] ??
            summaryMap['sentiment'] ??
            summaryMap['netSentiment'] ??
            '')
        .toString()
        .toLowerCase();
    if (sentiment.isEmpty) {
      if (netVal > 0 || netSh > 0 || (score != null && score > 0)) {
        sentiment = 'positive';
      } else if (netVal < 0 || netSh < 0 || (score != null && score < 0)) {
        sentiment = 'negative';
      } else {
        sentiment = 'neutral';
      }
    }

    // 4. Monthly breakdown
    List<MonthlyInsiderActivity> monthlyList = [];
    if (summaryMap['monthly_summary'] is List) {
      monthlyList = (summaryMap['monthly_summary'] as List)
          .whereType<Map>()
          .map((m) =>
              MonthlyInsiderActivity.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } else if (summaryMap['monthly'] is List) {
      monthlyList = (summaryMap['monthly'] as List)
          .whereType<Map>()
          .map((m) =>
              MonthlyInsiderActivity.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } else if (parsedTransactions.isNotEmpty) {
      // Derive monthly breakdown from transactions if not present
      final Map<String, List<InsiderTransactionRecord>> byMonth = {};
      for (final tx in parsedTransactions) {
        if (tx.transactionDate != null) {
          final mKey = DateFormat('yyyy-MM').format(tx.transactionDate!);
          byMonth.putIfAbsent(mKey, () => []).add(tx);
        }
      }

      final sortedMonths = byMonth.keys.toList()
        ..sort((a, b) => b.compareTo(a));
      for (final m in sortedMonths) {
        final txs = byMonth[m]!;
        num mBuySh = 0;
        num mSellSh = 0;
        double mBuyVal = 0;
        double mSellVal = 0;
        int mBCount = 0;
        int mSCount = 0;
        for (final t in txs) {
          if (t.isBuy) {
            mBuySh += t.shares;
            mBuyVal += (t.value ?? 0);
            mBCount++;
          } else if (t.isSale) {
            mSellSh += t.shares;
            mSellVal += (t.value ?? 0);
            mSCount++;
          }
        }
        monthlyList.add(MonthlyInsiderActivity(
          month: m,
          monthDate: DateFormat('yyyy-MM').parse(m),
          buyShares: mBuySh,
          sellShares: mSellSh,
          buyValue: mBuyVal,
          sellValue: mSellVal,
          netShares: mBuySh - mSellSh,
          netValue: mBuyVal - mSellVal,
          buyCount: mBCount,
          sellCount: mSCount,
          netSentiment: (mBuyVal > mSellVal)
              ? 'positive'
              : (mSellVal > mBuyVal ? 'negative' : 'neutral'),
        ));
      }
    }

    final updated = _parseDate(summaryMap['updated_at'] ??
        summaryMap['updatedAt'] ??
        summaryMap['timestamp']);

    return InsiderSentimentSummary(
      instrumentId: resolvedInstrumentId,
      symbol: resolvedSymbol,
      netSentiment: sentiment,
      sentimentScore: score,
      totalBuyShares: buyShares,
      totalSellShares: sellShares,
      totalBuyValue: buyValue,
      totalSellValue: sellValue,
      buyCount: bCount,
      sellCount: sCount,
      netShares: netSh,
      netValue: netVal,
      monthlySummary: monthlyList,
      transactions: parsedTransactions,
      updatedAt: updated,
    );
  }
}
