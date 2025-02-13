import 'package:cloud_firestore/cloud_firestore.dart';

class InstrumentHistorical {
  final DateTime? beginsAt;
  final double? openPrice;
  final double? closePrice;
  final double? highPrice;
  final double? lowPrice;
  final int volume;
  final String session;
  final bool interpolated;

  InstrumentHistorical(
      this.beginsAt,
      this.openPrice,
      this.closePrice,
      this.highPrice,
      this.lowPrice,
      this.volume,
      this.session,
      this.interpolated);

  InstrumentHistorical.fromJson(dynamic json)
      : beginsAt = json['begins_at'] is Timestamp
            ? (json['begins_at'] as Timestamp).toDate()
            : DateTime.tryParse(json['begins_at']),
        openPrice = json['open_price'] is double
            ? json['open_price']
            : double.tryParse(json['open_price']),
        closePrice = json['close_price'] is double
            ? json['close_price']
            : double.tryParse(json['close_price']),
        highPrice = json['high_price'] is double
            ? json['high_price']
            : double.tryParse(json['high_price']),
        lowPrice = json['low_price'] is double
            ? json['low_price']
            : double.tryParse(json['low_price']),
        volume = json['volume'] ?? 0,
        session = json['session'],
        interpolated = json['interpolated'];

  Map<String, dynamic> toJson() => {
        'begins_at': beginsAt, //?.toIso8601String(),
        'open_price': openPrice,
        'close_price': closePrice,
        'high_price': highPrice,
        'low_price': lowPrice,
        'volume': volume,
        'session': session,
        'interpolated': interpolated
      };

  static List<InstrumentHistorical> fromJsonArray(dynamic json) {
    List<InstrumentHistorical> list = [];
    for (int i = 0; i < json.length; i++) {
      var historical = InstrumentHistorical.fromJson(json[i]);
      list.add(historical);
    }
    return list;
  }
}
