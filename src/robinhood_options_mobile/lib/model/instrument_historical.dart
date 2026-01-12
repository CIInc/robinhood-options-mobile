import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:robinhood_options_mobile/utils/json.dart';

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
            : (json['begins_at'] is String
                ? DateTime.tryParse(json['begins_at'])
                : null),
        openPrice = parseDouble(json['open_price']),
        closePrice = parseDouble(json['close_price']),
        highPrice = parseDouble(json['high_price']),
        lowPrice = parseDouble(json['low_price']),
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
