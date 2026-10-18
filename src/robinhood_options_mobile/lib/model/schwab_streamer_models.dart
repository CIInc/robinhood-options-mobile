import 'package:flutter/foundation.dart';
import 'package:robinhood_options_mobile/utils/json.dart';

enum SchwabStreamerState {
  disconnected,
  connecting,
  authenticating,
  connected,
  error,
}

@immutable
class SchwabEquityQuoteUpdate {
  final String symbol;
  final double? bidPrice;
  final double? askPrice;
  final double? lastPrice;
  final int? bidSize;
  final int? askSize;
  final int? totalVolume;
  final int? lastSize;
  final double? highPrice;
  final double? lowPrice;
  final double? closePrice;
  final double? netChange;
  final double? percentChange;
  final double? week52High;
  final double? week52Low;
  final double? openPrice;
  final DateTime? quoteTime;
  final Map<String, dynamic> rawFields;

  const SchwabEquityQuoteUpdate({
    required this.symbol,
    this.bidPrice,
    this.askPrice,
    this.lastPrice,
    this.bidSize,
    this.askSize,
    this.totalVolume,
    this.lastSize,
    this.highPrice,
    this.lowPrice,
    this.closePrice,
    this.netChange,
    this.percentChange,
    this.week52High,
    this.week52Low,
    this.openPrice,
    this.quoteTime,
    required this.rawFields,
  });

  factory SchwabEquityQuoteUpdate.fromStreamContent(Map<String, dynamic> json) {
    final symbol = (json['key'] ?? json['0'] ?? '').toString();
    final quoteTimeMs = json['quoteTime'] ?? json['tradeTime'] ?? json['50'];
    final parsedTime = quoteTimeMs is num
        ? DateTime.fromMillisecondsSinceEpoch(quoteTimeMs.toInt(), isUtc: true)
        : DateTime.now();

    return SchwabEquityQuoteUpdate(
      symbol: symbol,
      bidPrice: parseDouble(json['1'] ?? json['bidPrice']),
      askPrice: parseDouble(json['2'] ?? json['askPrice']),
      lastPrice: parseDouble(
          json['3'] ?? json['lastPrice'] ?? json['regularMarketLastPrice']),
      bidSize: (json['4'] ?? json['bidSize'] as num?)?.toInt(),
      askSize: (json['5'] ?? json['askSize'] as num?)?.toInt(),
      totalVolume: (json['8'] ?? json['totalVolume'] as num?)?.toInt(),
      lastSize: (json['9'] ?? json['lastSize'] as num?)?.toInt(),
      highPrice: parseDouble(json['10'] ?? json['highPrice']),
      lowPrice: parseDouble(json['11'] ?? json['lowPrice']),
      closePrice: parseDouble(json['12'] ?? json['closePrice']),
      netChange: parseDouble(json['14'] ?? json['netChange']),
      percentChange: parseDouble(
          json['15'] ?? json['percentChange'] ?? json['netPercentChange']),
      week52High: parseDouble(json['24'] ?? json['52WeekHigh']),
      week52Low: parseDouble(json['25'] ?? json['52WeekLow']),
      openPrice: parseDouble(json['28'] ?? json['openPrice']),
      quoteTime: parsedTime,
      rawFields: json,
    );
  }
}

@immutable
class SchwabOptionQuoteUpdate {
  final String symbol;
  final String? description;
  final double? bidPrice;
  final double? askPrice;
  final double? lastPrice;
  final int? totalVolume;
  final int? openInterest;
  final double? volatility;
  final double? delta;
  final double? gamma;
  final double? theta;
  final double? vega;
  final double? rho;
  final DateTime? quoteTime;
  final Map<String, dynamic> rawFields;

  const SchwabOptionQuoteUpdate({
    required this.symbol,
    this.description,
    this.bidPrice,
    this.askPrice,
    this.lastPrice,
    this.totalVolume,
    this.openInterest,
    this.volatility,
    this.delta,
    this.gamma,
    this.theta,
    this.vega,
    this.rho,
    this.quoteTime,
    required this.rawFields,
  });

  factory SchwabOptionQuoteUpdate.fromStreamContent(Map<String, dynamic> json) {
    final symbol = (json['key'] ?? json['0'] ?? '').toString();
    final quoteTimeMs = json['quoteTime'] ?? json['tradeTime'] ?? json['39'];
    final parsedTime = quoteTimeMs is num
        ? DateTime.fromMillisecondsSinceEpoch(quoteTimeMs.toInt(), isUtc: true)
        : DateTime.now();

    return SchwabOptionQuoteUpdate(
      symbol: symbol,
      description: (json['1'] ?? json['description'])?.toString(),
      bidPrice: parseDouble(json['2'] ?? json['bidPrice']),
      askPrice: parseDouble(json['3'] ?? json['askPrice']),
      lastPrice: parseDouble(json['4'] ?? json['lastPrice']),
      totalVolume: (json['7'] ?? json['totalVolume'] as num?)?.toInt(),
      openInterest: (json['8'] ?? json['openInterest'] as num?)?.toInt(),
      volatility: parseDouble(
          json['9'] ?? json['volatility'] ?? json['impliedVolatility']),
      delta: parseDouble(json['16'] ?? json['delta']),
      gamma: parseDouble(json['17'] ?? json['gamma']),
      theta: parseDouble(json['18'] ?? json['theta']),
      vega: parseDouble(json['19'] ?? json['vega']),
      rho: parseDouble(json['20'] ?? json['rho']),
      quoteTime: parsedTime,
      rawFields: json,
    );
  }
}

@immutable
class SchwabAccountActivity {
  final String subscriptionKey;
  final String accountNumber;
  final String messageType;
  final dynamic messageData;
  final DateTime timestamp;
  final Map<String, dynamic> rawContent;

  const SchwabAccountActivity({
    required this.subscriptionKey,
    required this.accountNumber,
    required this.messageType,
    required this.messageData,
    required this.timestamp,
    required this.rawContent,
  });

  factory SchwabAccountActivity.fromStreamContent(Map<String, dynamic> json) {
    final subKey =
        (json['0'] ?? json['subscriptionKey'] ?? json['key'] ?? '').toString();
    final acctNum = (json['1'] ?? json['accountNumber'] ?? '').toString();
    final msgType =
        (json['2'] ?? json['messageType'] ?? 'AccountActivity').toString();
    final msgData = json['3'] ?? json['messageData'] ?? json['content'] ?? json;
    final timeMs = json['timestamp'] ?? json['time'];
    final parsedTime = timeMs is num
        ? DateTime.fromMillisecondsSinceEpoch(timeMs.toInt(), isUtc: true)
        : DateTime.now();

    return SchwabAccountActivity(
      subscriptionKey: subKey,
      accountNumber: acctNum,
      messageType: msgType,
      messageData: msgData,
      timestamp: parsedTime,
      rawContent: json,
    );
  }
}

@immutable
class SchwabChartBarUpdate {
  final String symbol;
  final double? openPrice;
  final double? highPrice;
  final double? lowPrice;
  final double? closePrice;
  final int? volume;
  final int? sequence;
  final DateTime? chartTime;
  final Map<String, dynamic> rawFields;

  const SchwabChartBarUpdate({
    required this.symbol,
    this.openPrice,
    this.highPrice,
    this.lowPrice,
    this.closePrice,
    this.volume,
    this.sequence,
    this.chartTime,
    required this.rawFields,
  });

  factory SchwabChartBarUpdate.fromStreamContent(Map<String, dynamic> json) {
    final symbol = (json['key'] ?? json['0'] ?? '').toString();
    final timeMs = json['7'] ?? json['chartTime'] ?? json['timestamp'];
    final parsedTime = timeMs is num
        ? DateTime.fromMillisecondsSinceEpoch(timeMs.toInt(), isUtc: true)
        : DateTime.now();

    return SchwabChartBarUpdate(
      symbol: symbol,
      openPrice: parseDouble(json['1'] ?? json['openPrice']),
      highPrice: parseDouble(json['2'] ?? json['highPrice']),
      lowPrice: parseDouble(json['3'] ?? json['lowPrice']),
      closePrice: parseDouble(json['4'] ?? json['closePrice']),
      volume: (json['5'] ?? json['volume'] as num?)?.toInt(),
      sequence: (json['6'] ?? json['sequence'] as num?)?.toInt(),
      chartTime: parsedTime,
      rawFields: json,
    );
  }
}

@immutable
class SchwabFuturesQuoteUpdate {
  final String symbol;
  final double? bidPrice;
  final double? askPrice;
  final double? lastPrice;
  final int? bidSize;
  final int? askSize;
  final int? totalVolume;
  final double? highPrice;
  final double? lowPrice;
  final double? closePrice;
  final DateTime? quoteTime;

  const SchwabFuturesQuoteUpdate({
    required this.symbol,
    this.bidPrice,
    this.askPrice,
    this.lastPrice,
    this.bidSize,
    this.askSize,
    this.totalVolume,
    this.highPrice,
    this.lowPrice,
    this.closePrice,
    this.quoteTime,
  });

  factory SchwabFuturesQuoteUpdate.fromStreamContent(
      Map<String, dynamic> json) {
    final symbol = (json['key'] ?? json['0'] ?? '').toString();
    final timeMs = json['quoteTime'] ?? json['tradeTime'];
    final parsedTime = timeMs is num
        ? DateTime.fromMillisecondsSinceEpoch(timeMs.toInt(), isUtc: true)
        : DateTime.now();

    return SchwabFuturesQuoteUpdate(
      symbol: symbol,
      bidPrice: parseDouble(json['1'] ?? json['bidPrice']),
      askPrice: parseDouble(json['2'] ?? json['askPrice']),
      lastPrice: parseDouble(json['3'] ?? json['lastPrice']),
      bidSize: (json['4'] ?? json['bidSize'] as num?)?.toInt(),
      askSize: (json['5'] ?? json['askSize'] as num?)?.toInt(),
      totalVolume: (json['7'] ?? json['totalVolume'] as num?)?.toInt(),
      highPrice: parseDouble(json['8'] ?? json['highPrice']),
      lowPrice: parseDouble(json['9'] ?? json['lowPrice']),
      closePrice: parseDouble(json['10'] ?? json['closePrice']),
      quoteTime: parsedTime,
    );
  }
}

@immutable
class SchwabForexQuoteUpdate {
  final String symbol;
  final double? bidPrice;
  final double? askPrice;
  final double? lastPrice;
  final int? bidSize;
  final int? askSize;
  final DateTime? quoteTime;

  const SchwabForexQuoteUpdate({
    required this.symbol,
    this.bidPrice,
    this.askPrice,
    this.lastPrice,
    this.bidSize,
    this.askSize,
    this.quoteTime,
  });

  factory SchwabForexQuoteUpdate.fromStreamContent(Map<String, dynamic> json) {
    final symbol = (json['key'] ?? json['0'] ?? '').toString();
    final timeMs = json['quoteTime'] ?? json['tradeTime'];
    final parsedTime = timeMs is num
        ? DateTime.fromMillisecondsSinceEpoch(timeMs.toInt(), isUtc: true)
        : DateTime.now();

    return SchwabForexQuoteUpdate(
      symbol: symbol,
      bidPrice: parseDouble(json['1'] ?? json['bidPrice']),
      askPrice: parseDouble(json['2'] ?? json['askPrice']),
      lastPrice: parseDouble(json['3'] ?? json['lastPrice']),
      bidSize: (json['4'] ?? json['bidSize'] as num?)?.toInt(),
      askSize: (json['5'] ?? json['askSize'] as num?)?.toInt(),
      quoteTime: parsedTime,
    );
  }
}
