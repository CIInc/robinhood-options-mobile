import 'package:flutter/material.dart';

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

/// Normalizes a percentage or ratio to a 0.0 - 100.0 range.
double _normalizePercentage(double val) {
  if (val > 0 && val <= 1.0) {
    return val * 100.0;
  }
  return val;
}

/// Represents a historical snapshot of retail order flow for a single trading day
/// as returned by Robinhood `/marketdata/equities/summary/robinhood/{instrument_id}/`.
@immutable
class RetailOrderFlowPoint {
  final DateTime? date;
  final double buyPercentage;
  final double sellPercentage;
  final double netBuyPercentage;
  final double? netSellPercentage;
  final double? buyVolumeChangePercentage;
  final double? sellVolumeChangePercentage;
  final double? volumeChangePercentage;
  final num? numBuyOrders;
  final num? numSellOrders;

  const RetailOrderFlowPoint({
    this.date,
    required this.buyPercentage,
    required this.sellPercentage,
    required this.netBuyPercentage,
    this.netSellPercentage,
    this.buyVolumeChangePercentage,
    this.sellVolumeChangePercentage,
    this.volumeChangePercentage,
    this.numBuyOrders,
    this.numSellOrders,
  });

  factory RetailOrderFlowPoint.fromJson(Map<String, dynamic> json) {
    // 1. Parse date
    DateTime? date;
    final dateStr =
        (json['date'] ?? json['timestamp'] ?? json['updated_at'])?.toString();
    if (dateStr != null && dateStr.isNotEmpty) {
      try {
        date = DateTime.parse(dateStr);
      } catch (_) {}
    }

    // 2. Parse net buy/sell percentage
    // In Robinhood API: {"net_buy_percentage": 6.733, "net_sell_percentage": -6.733}
    double? rawNetBuy = _parseDouble(json['net_buy_percentage'] ??
        json['net_buy_pct'] ??
        json['net_buyers_percentage'] ??
        json['net_buy']);
    double? rawNetSell = _parseDouble(json['net_sell_percentage'] ??
        json['net_sell_pct'] ??
        json['net_sellers_percentage'] ??
        json['net_sell']);

    // 3. Parse explicit buy/sell percentage if available
    double? explicitBuy = _parseDouble(json['buy_percentage'] ??
        json['buy_pct'] ??
        json['buy_ratio'] ??
        json['num_buy_orders_percentage'] ??
        json['pct_buy']);
    double? explicitSell = _parseDouble(json['sell_percentage'] ??
        json['sell_pct'] ??
        json['sell_ratio'] ??
        json['num_sell_orders_percentage'] ??
        json['pct_sell']);

    double buy;
    double sell;
    double netBuy;
    double netSell;

    if (explicitBuy != null) {
      buy = _normalizePercentage(explicitBuy);
      sell = explicitSell != null
          ? _normalizePercentage(explicitSell)
          : (100.0 - buy).clamp(0.0, 100.0);
      netBuy = rawNetBuy != null
          ? ((rawNetBuy.abs() > 0 && rawNetBuy.abs() <= 1.0)
              ? rawNetBuy * 100.0
              : rawNetBuy)
          : (buy - sell);
      netSell = rawNetSell != null
          ? ((rawNetSell.abs() > 0 && rawNetSell.abs() <= 1.0)
              ? rawNetSell * 100.0
              : rawNetSell)
          : -netBuy;
    } else if (rawNetBuy != null) {
      // Scale if passed as decimal fraction between -1.0 and 1.0
      netBuy = (rawNetBuy.abs() > 0 && rawNetBuy.abs() <= 1.0)
          ? rawNetBuy * 100.0
          : rawNetBuy;
      netSell = rawNetSell != null
          ? ((rawNetSell.abs() > 0 && rawNetSell.abs() <= 1.0)
              ? rawNetSell * 100.0
              : rawNetSell)
          : -netBuy;

      // Derived buy/sell split: netBuy = buy - sell, buy + sell = 100 => buy = 50 + netBuy/2
      buy = (50.0 + (netBuy / 2.0)).clamp(0.0, 100.0);
      sell = (100.0 - buy).clamp(0.0, 100.0);
    } else {
      buy = 50.0;
      sell = 50.0;
      netBuy = 0.0;
      netSell = 0.0;
    }

    // 4. Volume percentage changes:
    // "buy_volume_percentage_change": -34.7056, "sell_volume_percentage_change": -28.6118
    double? buyVol = _parseDouble(json['buy_volume_percentage_change'] ??
        json['buy_volume_pct_change'] ??
        json['buy_volume_change']);
    double? sellVol = _parseDouble(json['sell_volume_percentage_change'] ??
        json['sell_volume_pct_change'] ??
        json['sell_volume_change']);

    double? volChange = _parseDouble(json['volume_change_percentage'] ??
        json['volume_change_pct'] ??
        json['volume_change_24h'] ??
        json['volume_percentage_change'] ??
        json['volume_growth']);

    // Normalize decimal ratios if given as small decimals
    if (buyVol != null && buyVol.abs() > 0 && buyVol.abs() <= 1.0) {
      buyVol = buyVol * 100.0;
    }
    if (sellVol != null && sellVol.abs() > 0 && sellVol.abs() <= 1.0) {
      sellVol = sellVol * 100.0;
    }
    if (volChange != null && volChange.abs() > 0 && volChange.abs() <= 1.0) {
      volChange = volChange * 100.0;
    } else {
      volChange ??= buyVol;
    }

    return RetailOrderFlowPoint(
      date: date,
      buyPercentage: buy,
      sellPercentage: sell,
      netBuyPercentage: netBuy,
      netSellPercentage: netSell,
      buyVolumeChangePercentage: buyVol,
      sellVolumeChangePercentage: sellVol,
      volumeChangePercentage: volChange,
      numBuyOrders: _parseNum(json['num_buy_orders'] ?? json['buy_orders']),
      numSellOrders: _parseNum(json['num_sell_orders'] ?? json['sell_orders']),
    );
  }

  String get buyFormatted => '${buyPercentage.toStringAsFixed(1)}%';
  String get sellFormatted => '${sellPercentage.toStringAsFixed(1)}%';

  String get netBuyFormatted {
    final sign = netBuyPercentage >= 0 ? '+' : '';
    return '$sign${netBuyPercentage.toStringAsFixed(1)}%';
  }

  String get netSellFormatted {
    final val = netSellPercentage ?? -netBuyPercentage;
    final sign = val >= 0 ? '+' : '';
    return '$sign${val.toStringAsFixed(1)}%';
  }

  String get volumeChangeFormatted {
    if (volumeChangePercentage == null) return 'N/A';
    final sign = volumeChangePercentage! >= 0 ? '+' : '';
    return '$sign${volumeChangePercentage!.toStringAsFixed(1)}%';
  }

  String get buyVolumeChangeFormatted {
    if (buyVolumeChangePercentage == null) return 'N/A';
    final sign = buyVolumeChangePercentage! >= 0 ? '+' : '';
    return '$sign${buyVolumeChangePercentage!.toStringAsFixed(1)}%';
  }

  String get sellVolumeChangeFormatted {
    if (sellVolumeChangePercentage == null) return 'N/A';
    final sign = sellVolumeChangePercentage! >= 0 ? '+' : '';
    return '$sign${sellVolumeChangePercentage!.toStringAsFixed(1)}%';
  }
}

/// Represents first-party Robinhood retail order flow and customer sentiment summary
/// derived from `/marketdata/equities/summary/robinhood/{instrument_id}/`.
@immutable
class RetailOrderFlow {
  final String instrumentId;
  final String? symbol;
  final DateTime? updatedAt;
  final double buyPercentage;
  final double sellPercentage;
  final double netBuyPercentage;
  final double? netSellPercentage;
  final double? buyVolumeChangePercentage;
  final double? sellVolumeChangePercentage;
  final double? volumeChangePercentage;
  final num? numBuyOrders;
  final num? numSellOrders;
  final String? direction;
  final List<RetailOrderFlowPoint> history;

  const RetailOrderFlow({
    required this.instrumentId,
    this.symbol,
    this.updatedAt,
    required this.buyPercentage,
    required this.sellPercentage,
    required this.netBuyPercentage,
    this.netSellPercentage,
    this.buyVolumeChangePercentage,
    this.sellVolumeChangePercentage,
    this.volumeChangePercentage,
    this.numBuyOrders,
    this.numSellOrders,
    this.direction,
    this.history = const [],
  });

  factory RetailOrderFlow.fromJson(
    Map<String, dynamic> json, {
    String? fallbackInstrumentId,
    String? fallbackSymbol,
  }) {
    Map<String, dynamic> data = json;

    // Handle nested response wrapping: {"status": "SUCCESS", "data": {...}} or {"results": [...]}
    if (json['data'] is Map<String, dynamic>) {
      data = json['data'] as Map<String, dynamic>;
    } else if (json['data'] is List && (json['data'] as List).isNotEmpty) {
      final first = (json['data'] as List).first;
      if (first is Map<String, dynamic>) {
        if (first['data'] is Map<String, dynamic>) {
          data = first['data'] as Map<String, dynamic>;
        } else {
          data = first;
        }
      }
    } else if (json['results'] is List &&
        (json['results'] as List).isNotEmpty) {
      final first = (json['results'] as List).first;
      if (first is Map<String, dynamic>) {
        data = first;
      }
    } else if (json['results'] is Map<String, dynamic>) {
      data = json['results'] as Map<String, dynamic>;
    }

    final id =
        (data['instrument_id'] ?? data['id'] ?? fallbackInstrumentId ?? '')
            .toString();
    final sym = (data['symbol'] ?? fallbackSymbol)?.toString();

    // Parse history if present: "daily_transactions", "history", "daily_sentiment", "daily_data", "historical_sentiment"
    List<RetailOrderFlowPoint> historyPoints = [];
    final histRaw = data['daily_transactions'] ??
        data['history'] ??
        data['daily_sentiment'] ??
        data['daily_data'] ??
        data['historical_sentiment'];

    if (histRaw is List && histRaw.isNotEmpty) {
      historyPoints = histRaw
          .whereType<Map<String, dynamic>>()
          .map((item) => RetailOrderFlowPoint.fromJson(item))
          .toList();
      historyPoints.sort((a, b) {
        if (a.date == null && b.date == null) return 0;
        if (a.date == null) return -1;
        if (b.date == null) return 1;
        return a.date!.compareTo(b.date!);
      });
    }

    // Extract latest day snapshot if history is available
    final latestPoint = historyPoints.isNotEmpty ? historyPoints.last : null;

    DateTime? updated;
    final updatedStr = (data['updated_at'] ??
            data['timestamp'] ??
            data['date'] ??
            data['last_updated'])
        ?.toString();
    if (updatedStr != null && updatedStr.isNotEmpty) {
      try {
        updated = DateTime.parse(updatedStr);
      } catch (_) {}
    }
    updated ??= latestPoint?.date;

    double? rawExplicitBuy = _parseDouble(data['buy_percentage'] ??
        data['buy_pct'] ??
        data['buy_ratio'] ??
        data['num_buy_orders_percentage'] ??
        data['pct_buy']);
    double? rawExplicitSell = _parseDouble(data['sell_percentage'] ??
        data['sell_pct'] ??
        data['sell_ratio'] ??
        data['num_sell_orders_percentage'] ??
        data['pct_sell']);

    double? rawNet = _parseDouble(data['net_buy_percentage'] ??
        data['net_buy_pct'] ??
        data['net_buyers_percentage'] ??
        data['net_buy']);
    double? rawNetSell = _parseDouble(data['net_sell_percentage'] ??
        data['net_sell_pct'] ??
        data['net_sellers_percentage'] ??
        data['net_sell']);

    double buy;
    double sell;
    double netBuy;
    double? netSell;

    if (rawExplicitBuy != null) {
      buy = _normalizePercentage(rawExplicitBuy);
      sell = rawExplicitSell != null
          ? _normalizePercentage(rawExplicitSell)
          : (100.0 - buy).clamp(0.0, 100.0);
      netBuy = rawNet != null
          ? ((rawNet.abs() > 0 && rawNet.abs() <= 1.0)
              ? rawNet * 100.0
              : rawNet)
          : (buy - sell);
      netSell = rawNetSell != null
          ? ((rawNetSell.abs() > 0 && rawNetSell.abs() <= 1.0)
              ? rawNetSell * 100.0
              : rawNetSell)
          : -netBuy;
    } else if (rawNet != null) {
      netBuy =
          (rawNet.abs() > 0 && rawNet.abs() <= 1.0) ? rawNet * 100.0 : rawNet;
      netSell = rawNetSell != null
          ? ((rawNetSell.abs() > 0 && rawNetSell.abs() <= 1.0)
              ? rawNetSell * 100.0
              : rawNetSell)
          : -netBuy;
      buy = (50.0 + (netBuy / 2.0)).clamp(0.0, 100.0);
      sell = (100.0 - buy).clamp(0.0, 100.0);
    } else if (latestPoint != null) {
      buy = latestPoint.buyPercentage;
      sell = latestPoint.sellPercentage;
      netBuy = latestPoint.netBuyPercentage;
      netSell = latestPoint.netSellPercentage ?? -latestPoint.netBuyPercentage;
    } else {
      buy = 50.0;
      sell = 50.0;
      netBuy = 0.0;
      netSell = 0.0;
    }

    double? buyVol = _parseDouble(
        data['buy_volume_percentage_change'] ?? data['buy_volume_pct_change']);
    double? sellVol = _parseDouble(data['sell_volume_percentage_change'] ??
        data['sell_volume_pct_change']);

    double? volChange = _parseDouble(data['volume_change_percentage'] ??
        data['volume_change_pct'] ??
        data['volume_change_24h'] ??
        data['volume_percentage_change'] ??
        data['volume_growth']);

    if (buyVol != null && buyVol.abs() > 0 && buyVol.abs() <= 1.0) {
      buyVol = buyVol * 100.0;
    }
    if (sellVol != null && sellVol.abs() > 0 && sellVol.abs() <= 1.0) {
      sellVol = sellVol * 100.0;
    }
    if (volChange != null && volChange.abs() > 0 && volChange.abs() <= 1.0) {
      volChange = volChange * 100.0;
    } else {
      volChange ??= buyVol;
    }

    if (buyVol == null && latestPoint != null) {
      buyVol = latestPoint.buyVolumeChangePercentage;
    }
    if (sellVol == null && latestPoint != null) {
      sellVol = latestPoint.sellVolumeChangePercentage;
    }
    if (volChange == null && latestPoint != null) {
      volChange = latestPoint.volumeChangePercentage;
    }

    final numBuy = _parseNum(data['num_buy_orders'] ?? data['buy_orders']);
    final numSell = _parseNum(data['num_sell_orders'] ?? data['sell_orders']);
    final dir =
        (data['sentiment_direction'] ?? data['direction'] ?? data['sentiment'])
            ?.toString();

    return RetailOrderFlow(
      instrumentId: id,
      symbol: sym,
      updatedAt: updated,
      buyPercentage: buy,
      sellPercentage: sell,
      netBuyPercentage: netBuy,
      netSellPercentage: netSell,
      buyVolumeChangePercentage: buyVol,
      sellVolumeChangePercentage: sellVol,
      volumeChangePercentage: volChange,
      numBuyOrders: numBuy ?? latestPoint?.numBuyOrders,
      numSellOrders: numSell ?? latestPoint?.numSellOrders,
      direction: dir,
      history: historyPoints,
    );
  }

  /// Sentiment categorization based on buy percentage
  String get sentimentLabel {
    if (buyPercentage >= 70.0) return 'Strong Bullish';
    if (buyPercentage >= 55.0) return 'Bullish';
    if (buyPercentage <= 30.0) return 'Strong Bearish';
    if (buyPercentage <= 45.0) return 'Bearish';
    return 'Neutral';
  }

  bool get isBullish => buyPercentage >= 55.0;
  bool get isBearish => buyPercentage <= 45.0;
  bool get isNeutral => !isBullish && !isBearish;

  String get buyRatioFormatted => '${buyPercentage.toStringAsFixed(1)}%';
  String get sellRatioFormatted => '${sellPercentage.toStringAsFixed(1)}%';

  String get netBuyFormatted {
    final sign = netBuyPercentage >= 0 ? '+' : '';
    return '$sign${netBuyPercentage.toStringAsFixed(1)}%';
  }

  String get netSellFormatted {
    final val = netSellPercentage ?? -netBuyPercentage;
    final sign = val >= 0 ? '+' : '';
    return '$sign${val.toStringAsFixed(1)}%';
  }

  String get volumeChangeFormatted {
    if (volumeChangePercentage == null) return 'N/A';
    final sign = volumeChangePercentage! >= 0 ? '+' : '';
    return '$sign${volumeChangePercentage!.toStringAsFixed(1)}%';
  }

  String get buyVolumeChangeFormatted {
    if (buyVolumeChangePercentage == null) return 'N/A';
    final sign = buyVolumeChangePercentage! >= 0 ? '+' : '';
    return '$sign${buyVolumeChangePercentage!.toStringAsFixed(1)}%';
  }

  String get sellVolumeChangeFormatted {
    if (sellVolumeChangePercentage == null) return 'N/A';
    final sign = sellVolumeChangePercentage! >= 0 ? '+' : '';
    return '$sign${sellVolumeChangePercentage!.toStringAsFixed(1)}%';
  }

  Color get sentimentColor {
    if (isBullish) return Colors.green;
    if (isBearish) return Colors.red;
    return Colors.grey;
  }
}
