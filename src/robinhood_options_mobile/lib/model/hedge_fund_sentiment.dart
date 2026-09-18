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

/// Represents an individual quarterly hedge fund holding or transaction record
@immutable
class HedgeFundTransactionRecord {
  final String managerName;
  final String? fundName;
  final String? quarter; // e.g. "Q2 2026" or "2026-06-30"
  final DateTime? reportDate;
  final String
      transactionType; // "Buy", "Sell", "New Position", "Sold Out", "Hold"
  final num sharesHeld;
  final num? shareChange;
  final double? percentChange;
  final double? value;
  final double? portfolioPercent; // % of fund portfolio
  final String? sourceUrl;

  const HedgeFundTransactionRecord({
    required this.managerName,
    this.fundName,
    this.quarter,
    this.reportDate,
    required this.transactionType,
    required this.sharesHeld,
    this.shareChange,
    this.percentChange,
    this.value,
    this.portfolioPercent,
    this.sourceUrl,
  });

  bool get isBuy {
    final t = transactionType.toLowerCase();
    return t.contains('buy') ||
        t.contains('new') ||
        t.contains('addition') ||
        t.contains('increase') ||
        (shareChange != null && shareChange! > 0);
  }

  bool get isSell {
    final t = transactionType.toLowerCase();
    return t.contains('sell') ||
        t.contains('sold') ||
        t.contains('reduction') ||
        t.contains('decrease') ||
        (shareChange != null && shareChange! < 0);
  }

  bool get isNewPosition {
    final t = transactionType.toLowerCase();
    return t.contains('new');
  }

  bool get isSoldOut {
    final t = transactionType.toLowerCase();
    return t.contains('sold out') || t.contains('liquidat') || sharesHeld == 0;
  }

  String get displayType {
    if (isNewPosition) return 'New Position';
    if (isSoldOut) return 'Sold Out';
    if (isBuy) return 'Increased';
    if (isSell) return 'Decreased';
    if (transactionType.toLowerCase() == 'hold') return 'Held';
    return transactionType.isNotEmpty ? transactionType : 'Held';
  }

  Color get typeColor {
    if (isNewPosition) return Colors.green.shade700;
    if (isBuy) return Colors.green;
    if (isSoldOut) return Colors.red.shade700;
    if (isSell) return Colors.red;
    return Colors.grey;
  }

  IconData get typeIcon {
    if (isNewPosition) return Icons.add_circle_outline;
    if (isBuy) return Icons.trending_up;
    if (isSoldOut) return Icons.remove_circle_outline;
    if (isSell) return Icons.trending_down;
    return Icons.swap_horiz;
  }

  factory HedgeFundTransactionRecord.fromJson(Map<String, dynamic> json) {
    final manager = (json['manager_name'] ??
            json['managerName'] ??
            json['name'] ??
            json['institution_name'] ??
            json['institution'] ??
            '')
        .toString();
    final fund = (json['institution_name'] ??
            json['fund_name'] ??
            json['fundName'] ??
            json['firm_name'] ??
            json['firm'])
        ?.toString();
    final qtr = (json['quarter'] ?? json['report_period'])?.toString();
    final rDate = _parseDate(json['report_date'] ??
        json['date'] ??
        json['filing_date'] ??
        json['reportDate']);

    final type =
        (json['action'] ?? json['transaction_type'] ?? json['type'] ?? '')
            .toString();

    final shares = _parseNum(json['total_shares'] ??
            json['shares_held'] ??
            json['sharesHeld'] ??
            json['shares'] ??
            json['share_count']) ??
        0;

    final change = _parseNum(json['shares_traded'] ??
        json['share_change'] ??
        json['shareChange'] ??
        json['change_in_shares'] ??
        json['change']);

    final pctChange = _parseDouble(json['change_percentage'] ??
        json['percent_change'] ??
        json['percentChange'] ??
        json['percentage_change']);

    final val = _parseDouble(json['market_value'] ??
        json['value'] ??
        json['position_value'] ??
        json['total_value']);

    final portPct = _parseDouble(json['portfolio_percentage'] ??
        json['portfolio_percent'] ??
        json['portfolioPercent'] ??
        json['weight']);

    final url =
        (json['source_url'] ?? json['sec_url'] ?? json['url'])?.toString();

    return HedgeFundTransactionRecord(
      managerName: manager,
      fundName: fund,
      quarter: qtr,
      reportDate: rDate,
      transactionType: type,
      sharesHeld: shares,
      shareChange: change,
      percentChange: pctChange,
      value: val,
      portfolioPercent: portPct,
      sourceUrl: url,
    );
  }
}

/// Quarterly aggregate sentiment summary across top institutional hedge funds
@immutable
class QuarterlyHedgeFundActivity {
  final String quarter; // e.g. "Q2 2026" or "2026-Q2"
  final DateTime? quarterDate;
  final num buyShares;
  final num sellShares;
  final double buyValue;
  final double sellValue;
  final int buyingManagersCount;
  final int sellingManagersCount;
  final int holdingManagersCount;
  final int newPositionsCount;
  final int soldOutPositionsCount;
  final String netSentiment; // "positive", "negative", "neutral"

  const QuarterlyHedgeFundActivity({
    required this.quarter,
    this.quarterDate,
    required this.buyShares,
    required this.sellShares,
    required this.buyValue,
    required this.sellValue,
    required this.buyingManagersCount,
    required this.sellingManagersCount,
    required this.holdingManagersCount,
    this.newPositionsCount = 0,
    this.soldOutPositionsCount = 0,
    required this.netSentiment,
  });

  factory QuarterlyHedgeFundActivity.fromJson(Map<String, dynamic> json) {
    final qStr =
        (json['quarter'] ?? json['date'] ?? json['period'] ?? '').toString();
    DateTime? qDate;
    if (qStr.isNotEmpty) {
      try {
        qDate = DateTime.tryParse(qStr);
      } catch (_) {}
    }

    String quarterLabel = qStr;
    if (qDate != null) {
      final quarterNum = ((qDate.month - 1) ~/ 3) + 1;
      quarterLabel = 'Q$quarterNum ${qDate.year}';
    }

    final buyShares = _parseNum(
            json['shares_bought'] ?? json['buy_shares'] ?? json['buyShares']) ??
        0;
    final sellShares = _parseNum(
            json['shares_sold'] ?? json['sell_shares'] ?? json['sellShares']) ??
        0;
    final buyVal = _parseDouble(json['buy_value'] ?? json['buyValue']) ?? 0.0;
    final sellVal =
        _parseDouble(json['sell_value'] ?? json['sellValue']) ?? 0.0;
    final bManagers = _parseInt(json['buying_managers_count'] ??
            json['buyingManagersCount'] ??
            json['buyers_count']) ??
        0;
    final sManagers = _parseInt(json['selling_managers_count'] ??
            json['sellingManagersCount'] ??
            json['sellers_count']) ??
        0;
    final hManagers = _parseInt(json['holding_managers_count'] ??
            json['holdingManagersCount'] ??
            json['holders_count']) ??
        0;
    final newPos = _parseInt(json['new_positions_count'] ??
            json['newPositionsCount'] ??
            json['new_positions']) ??
        0;
    final soldOut = _parseInt(json['sold_out_positions_count'] ??
            json['soldOutPositionsCount'] ??
            json['sold_out']) ??
        0;

    String sentiment = (json['net_sentiment'] ??
            json['sentiment'] ??
            json['netSentiment'] ??
            '')
        .toString()
        .toLowerCase();
    if (sentiment.isEmpty) {
      if (bManagers > sManagers || buyVal > sellVal || buyShares > sellShares) {
        sentiment = 'positive';
      } else if (sManagers > bManagers ||
          sellVal > buyVal ||
          sellShares > buyShares) {
        sentiment = 'negative';
      } else {
        sentiment = 'neutral';
      }
    }

    return QuarterlyHedgeFundActivity(
      quarter: quarterLabel,
      quarterDate: qDate,
      buyShares: buyShares,
      sellShares: sellShares,
      buyValue: buyVal,
      sellValue: sellVal,
      buyingManagersCount: bManagers,
      sellingManagersCount: sManagers,
      holdingManagersCount: hManagers,
      newPositionsCount: newPos,
      soldOutPositionsCount: soldOut,
      netSentiment: sentiment,
    );
  }
}

/// Comprehensive aggregate hedge fund sentiment and quarterly manager transactions
@immutable
class HedgeFundSummary {
  final String instrumentId;
  final String? symbol;
  final String netSentiment; // "positive", "negative", "neutral"
  final double? sentimentScore; // -100 to +100
  final num totalSharesHeld;
  final double? totalValueHeld;
  final double? institutionalOwnershipPercentage;
  final int totalManagersCount;
  final int buyingManagersCount;
  final int sellingManagersCount;
  final int holdingManagersCount;
  final int newPositionsCount;
  final int soldOutCount;
  final num netSharesChanged;
  final double netValueChanged;
  final List<QuarterlyHedgeFundActivity> quarterlySummary;
  final List<HedgeFundTransactionRecord> transactions;
  final DateTime? updatedAt;

  const HedgeFundSummary({
    required this.instrumentId,
    this.symbol,
    required this.netSentiment,
    this.sentimentScore,
    required this.totalSharesHeld,
    this.totalValueHeld,
    this.institutionalOwnershipPercentage,
    required this.totalManagersCount,
    required this.buyingManagersCount,
    required this.sellingManagersCount,
    required this.holdingManagersCount,
    this.newPositionsCount = 0,
    this.soldOutCount = 0,
    required this.netSharesChanged,
    required this.netValueChanged,
    this.quarterlySummary = const [],
    this.transactions = const [],
    this.updatedAt,
  });

  bool get isBullish =>
      netSentiment == 'positive' ||
      netSentiment == 'bullish' ||
      (sentimentScore != null && sentimentScore! > 5.0) ||
      (buyingManagersCount > sellingManagersCount && netValueChanged >= 0);

  bool get isBearish =>
      netSentiment == 'negative' ||
      netSentiment == 'bearish' ||
      (sentimentScore != null && sentimentScore! < -5.0) ||
      (sellingManagersCount > buyingManagersCount && netValueChanged <= 0);

  bool get isNeutral => !isBullish && !isBearish;

  String get sentimentBadge {
    if (isBullish) return 'Accumulation';
    if (isBearish) return 'Distribution';
    return 'Neutral';
  }

  Color get sentimentColor {
    if (isBullish) return Colors.green;
    if (isBearish) return Colors.red;
    return Colors.grey;
  }

  double get buyersPercentage {
    final active = buyingManagersCount + sellingManagersCount;
    if (active <= 0) return 50.0;
    return (buyingManagersCount / active) * 100.0;
  }

  double get sellersPercentage {
    final active = buyingManagersCount + sellingManagersCount;
    if (active <= 0) return 50.0;
    return (sellingManagersCount / active) * 100.0;
  }

  String get formattedNetValue {
    final fmt = NumberFormat.compactSimpleCurrency();
    final sign = netValueChanged > 0 ? '+' : '';
    return '$sign${fmt.format(netValueChanged)}';
  }

  String get formattedTotalValueHeld {
    if (totalValueHeld == null) return '-';
    return NumberFormat.compactSimpleCurrency().format(totalValueHeld);
  }

  String get formattedSharesHeld {
    return NumberFormat.compact().format(totalSharesHeld);
  }

  String get formattedNetSharesChanged {
    final fmt = NumberFormat.compact();
    final sign = netSharesChanged > 0 ? '+' : '';
    return '$sign${fmt.format(netSharesChanged)}';
  }

  factory HedgeFundSummary.fromResponses({
    dynamic summaryResponse,
    dynamic transactionsResponse,
    String? instrumentId,
    String? symbol,
  }) {
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

    List<dynamic> rawTxList = [];
    if (transactionsResponse is List) {
      rawTxList = transactionsResponse;
    } else if (transactionsResponse is Map) {
      final txMap = Map<String, dynamic>.from(transactionsResponse);
      if (txMap['detailed_transactions'] is List) {
        rawTxList = txMap['detailed_transactions'] as List;
      } else if (txMap['data'] is Map &&
          (txMap['data'] as Map)['results'] is List) {
        rawTxList = (txMap['data'] as Map)['results'] as List;
      } else if (txMap['data'] is Map &&
          (txMap['data'] as Map)['detailed_transactions'] is List) {
        rawTxList = (txMap['data'] as Map)['detailed_transactions'] as List;
      } else if (txMap['data'] is List) {
        rawTxList = txMap['data'] as List;
      } else if (txMap['results'] is List) {
        rawTxList = txMap['results'] as List;
      }
    }

    final instId = (summaryMap['instrument_id'] ??
            summaryMap['instrumentId'] ??
            instrumentId ??
            '')
        .toString();
    final sym = (summaryMap['symbol'] ?? symbol)?.toString();

    // Check sentiment_score if it's a string like "Positive Sentiment" or numeric
    String netSent = 'neutral';
    double? score;
    final rawScore = summaryMap['sentiment_score'] ??
        summaryMap['sentimentScore'] ??
        summaryMap['score'];
    if (rawScore is num) {
      score = rawScore.toDouble();
      if (score > 5.0) {
        netSent = 'positive';
      } else if (score < -5.0) {
        netSent = 'negative';
      }
    } else if (rawScore is String) {
      final sLower = rawScore.toLowerCase();
      if (sLower.contains('positive') || sLower.contains('bull')) {
        netSent = 'positive';
        score = 25.0;
      } else if (sLower.contains('negative') || sLower.contains('bear')) {
        netSent = 'negative';
        score = -25.0;
      }
    }

    final explicitSent = (summaryMap['net_sentiment'] ??
            summaryMap['sentiment'] ??
            summaryMap['netSentiment'])
        ?.toString()
        .toLowerCase();
    if (explicitSent != null && explicitSent.isNotEmpty) {
      netSent = explicitSent;
    }

    // Parse quarterly summary if present
    List<QuarterlyHedgeFundActivity> quarters = [];
    final rawQuarters = summaryMap['quarterly_aggregate_transactions'] ??
        summaryMap['quarterly_summary'] ??
        summaryMap['quarterlySummary'] ??
        summaryMap['quarters'];
    if (rawQuarters is List) {
      quarters = rawQuarters
          .whereType<Map>()
          .map((m) =>
              QuarterlyHedgeFundActivity.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    }

    // Default total shares held / change from quarterly if available
    num totalShares = _parseNum(summaryMap['total_shares_held'] ??
            summaryMap['totalSharesHeld'] ??
            summaryMap['shares_held']) ??
        0;
    if (totalShares == 0 && quarters.isNotEmpty) {
      totalShares = quarters.last.buyShares > 0 && quarters.last.sellShares == 0
          ? quarters.last.buyShares
          : (quarters.last.buyShares + quarters.last.sellShares);
    }
    final rawTotalSharesInQuarters =
        rawQuarters is List && rawQuarters.isNotEmpty && rawQuarters.last is Map
            ? _parseNum((rawQuarters.last as Map)['total_shares_held'])
            : null;
    if (rawTotalSharesInQuarters != null && rawTotalSharesInQuarters > 0) {
      totalShares = rawTotalSharesInQuarters;
    }

    final totalVal = _parseDouble(summaryMap['total_value_held'] ??
        summaryMap['totalValueHeld'] ??
        summaryMap['value_held']);
    final ownPct = _parseDouble(
        summaryMap['institutional_ownership_percentage'] ??
            summaryMap['institutionalOwnershipPercentage'] ??
            summaryMap['percentage_held'] ??
            summaryMap['ownership_percent']);

    int totalMgrs = _parseInt(summaryMap['total_managers_count'] ??
            summaryMap['totalManagersCount'] ??
            summaryMap['total_managers']) ??
        0;
    int buyingMgrs = _parseInt(summaryMap['buying_managers_count'] ??
            summaryMap['buyingManagersCount'] ??
            summaryMap['buyers_count']) ??
        0;
    int sellingMgrs = _parseInt(summaryMap['selling_managers_count'] ??
            summaryMap['sellingManagersCount'] ??
            summaryMap['sellers_count']) ??
        0;
    int holdingMgrs = _parseInt(summaryMap['holding_managers_count'] ??
            summaryMap['holdingManagersCount'] ??
            summaryMap['holders_count']) ??
        0;
    int newPos = _parseInt(summaryMap['new_positions_count'] ??
            summaryMap['newPositionsCount'] ??
            summaryMap['new_positions']) ??
        0;
    int soldOut = _parseInt(summaryMap['sold_out_count'] ??
            summaryMap['soldOutCount'] ??
            summaryMap['sold_out']) ??
        0;

    num netSh = _parseNum(summaryMap['net_shares_changed'] ??
            summaryMap['netSharesChanged'] ??
            summaryMap['net_shares']) ??
        0;
    double netVal = _parseDouble(summaryMap['net_value_changed'] ??
            summaryMap['netValueChanged'] ??
            summaryMap['net_value']) ??
        0.0;

    final txs = rawTxList
        .whereType<Map>()
        .map((m) =>
            HedgeFundTransactionRecord.fromJson(Map<String, dynamic>.from(m)))
        .toList();

    // If counts are 0 but detailed_transactions are present, compute them from transactions!
    if (txs.isNotEmpty) {
      if (totalMgrs == 0) totalMgrs = txs.length;
      if (buyingMgrs == 0 && sellingMgrs == 0) {
        for (var t in txs) {
          if (t.isNewPosition) {
            newPos++;
            buyingMgrs++;
          } else if (t.isSoldOut) {
            soldOut++;
            sellingMgrs++;
          } else if (t.isBuy) {
            buyingMgrs++;
          } else if (t.isSell) {
            sellingMgrs++;
          } else {
            holdingMgrs++;
          }
          if (t.shareChange != null) {
            netSh += t.shareChange!;
          }
          if (t.value != null && t.shareChange != null && t.sharesHeld > 0) {
            netVal += (t.value! / t.sharesHeld) * t.shareChange!;
          }
        }
      }
    }

    if (netSent == 'neutral' && quarters.isNotEmpty) {
      final latestQ = quarters.last;
      if (latestQ.buyShares > latestQ.sellShares) {
        netSent = 'positive';
      } else if (latestQ.sellShares > latestQ.buyShares) {
        netSent = 'negative';
      }
    }

    DateTime? upAt =
        _parseDate(summaryMap['updated_at'] ?? summaryMap['updatedAt']);

    return HedgeFundSummary(
      instrumentId: instId,
      symbol: sym,
      netSentiment: netSent,
      sentimentScore: score,
      totalSharesHeld: totalShares,
      totalValueHeld: totalVal,
      institutionalOwnershipPercentage: ownPct,
      totalManagersCount: totalMgrs,
      buyingManagersCount: buyingMgrs,
      sellingManagersCount: sellingMgrs,
      holdingManagersCount: holdingMgrs,
      newPositionsCount: newPos,
      soldOutCount: soldOut,
      netSharesChanged: netSh,
      netValueChanged: netVal,
      quarterlySummary: quarters,
      transactions: txs,
      updatedAt: upAt,
    );
  }
}
