/*
Robinhood Crypto Quote API Response Format:
{
    "ask_price": "64500.0000",
    "bid_price": "64498.5000",
    "mark_price": "64499.2500",
    "high_price": "65200.0000",
    "low_price": "63800.0000",
    "open_price": "64100.0000",
    "symbol": "BTC-USD",
    "id": "3d961844-d360-45fc-989b-f6fca761d511",
    "volume": "1234567.8900000000"
}
*/

class CryptoQuote {
  final String id;
  final String symbol;
  final double? askPrice;
  final double? bidPrice;
  final double? markPrice;
  final double? highPrice;
  final double? lowPrice;
  final double? openPrice;
  final double? volume;
  DateTime? updatedAt;

  CryptoQuote(
    this.id,
    this.symbol,
    this.askPrice,
    this.bidPrice,
    this.markPrice,
    this.highPrice,
    this.lowPrice,
    this.openPrice,
    this.volume,
    this.updatedAt,
  );

  CryptoQuote.fromJson(dynamic json)
      : id = json['id'] ?? '',
        symbol = json['symbol'] ?? '',
        askPrice = double.tryParse(json['ask_price']?.toString() ?? '0'),
        bidPrice = double.tryParse(json['bid_price']?.toString() ?? '0'),
        markPrice = double.tryParse(json['mark_price']?.toString() ?? '0'),
        highPrice = double.tryParse(json['high_price']?.toString() ?? '0'),
        lowPrice = double.tryParse(json['low_price']?.toString() ?? '0'),
        openPrice = double.tryParse(json['open_price']?.toString() ?? '0'),
        volume = double.tryParse(json['volume']?.toString() ?? '0'),
        updatedAt = DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'ask_price': askPrice,
        'bid_price': bidPrice,
        'mark_price': markPrice,
        'high_price': highPrice,
        'low_price': lowPrice,
        'open_price': openPrice,
        'volume': volume,
        'updated_at': updatedAt?.toIso8601String(),
      };

  double get spread {
    if (askPrice == null || bidPrice == null) {
      return 0.0;
    }
    return askPrice! - bidPrice!;
  }

  double get changeFromOpen {
    if (markPrice == null || openPrice == null) {
      return 0.0;
    }
    return markPrice! - openPrice!;
  }

  double get changePercentFromOpen {
    if (openPrice == null || openPrice! <= 0) {
      return 0.0;
    }
    return (changeFromOpen / openPrice!) * 100;
  }

  double get dayRange {
    if (highPrice == null || lowPrice == null) {
      return 0.0;
    }
    return highPrice! - lowPrice!;
  }
}
