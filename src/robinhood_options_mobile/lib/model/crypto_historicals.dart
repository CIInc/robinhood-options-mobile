/*
Robinhood Crypto Historicals API Response Format:
{
    "bounds": "24_7",
    "interval": "5minute",
    "span": "day",
    "symbol": "BTC-USD",
    "id": "3d961844-d360-45fc-989b-f6fca761d511",
    "data_points": [
        {
            "begins_at": "2024-12-03T00:00:00Z",
            "open_price": "64100.0000",
            "close_price": "64250.0000",
            "high_price": "64300.0000",
            "low_price": "64050.0000",
            "volume": "123.4567",
            "session": "24_7",
            "interpolated": false
        }
    ]
}
*/

class CryptoHistoricals {
  final String id;
  final String symbol;
  final String bounds;
  final String interval;
  final String span;
  final List<CryptoDataPoint> dataPoints;

  CryptoHistoricals(
    this.id,
    this.symbol,
    this.bounds,
    this.interval,
    this.span,
    this.dataPoints,
  );

  CryptoHistoricals.fromJson(dynamic json)
      : id = json['id'] ?? '',
        symbol = json['symbol'] ?? '',
        bounds = json['bounds'] ?? '',
        interval = json['interval'] ?? '',
        span = json['span'] ?? '',
        dataPoints = json['data_points'] != null
            ? (json['data_points'] as List)
                .map((e) => CryptoDataPoint.fromJson(e))
                .toList()
            : [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'bounds': bounds,
        'interval': interval,
        'span': span,
        'data_points': dataPoints.map((e) => e.toJson()).toList(),
      };
}

class CryptoDataPoint {
  final DateTime beginsAt;
  final double? openPrice;
  final double? closePrice;
  final double? highPrice;
  final double? lowPrice;
  final double? volume;
  final String? session;
  final bool? interpolated;

  CryptoDataPoint(
    this.beginsAt,
    this.openPrice,
    this.closePrice,
    this.highPrice,
    this.lowPrice,
    this.volume,
    this.session,
    this.interpolated,
  );

  CryptoDataPoint.fromJson(dynamic json)
      : beginsAt = DateTime.parse(json['begins_at']),
        openPrice = double.tryParse(json['open_price']?.toString() ?? '0'),
        closePrice = double.tryParse(json['close_price']?.toString() ?? '0'),
        highPrice = double.tryParse(json['high_price']?.toString() ?? '0'),
        lowPrice = double.tryParse(json['low_price']?.toString() ?? '0'),
        volume = double.tryParse(json['volume']?.toString() ?? '0'),
        session = json['session'],
        interpolated = json['interpolated'];

  Map<String, dynamic> toJson() => {
        'begins_at': beginsAt.toIso8601String(),
        'open_price': openPrice,
        'close_price': closePrice,
        'high_price': highPrice,
        'low_price': lowPrice,
        'volume': volume,
        'session': session,
        'interpolated': interpolated,
      };
}
