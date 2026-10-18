import 'package:flutter/foundation.dart';
import 'package:robinhood_options_mobile/model/instrument_historical.dart';

import 'package:robinhood_options_mobile/utils/json.dart';

@immutable
class Leg {
  final String id;
  final String ratio;
  final String? type;
  const Leg(this.id, this.ratio, this.type);

  Leg.fromJson(dynamic json)
      : id = json['id'],
        ratio = json['ratio'],
        type = json['type'];

  static List<Leg> fromJsonArray(dynamic json) {
    List<Leg> legs = [];
    for (int i = 0; i < json.length; i++) {
      var leg = Leg.fromJson(json[i]);
      legs.add(leg);
    }
    return legs;
  }
}

class OptionHistoricals {
  final String bounds;
  final String interval;
  final String span;
  //final String symbol;
  //final String id;
  final List<Leg> legs;
  final double? previousClosePrice;
  final DateTime? previousCloseTime;
  final double? openPrice;
  final DateTime? openTime;

  List<InstrumentHistorical> historicals;

  OptionHistoricals(
      this.bounds,
      this.interval,
      this.span,
      this.legs,
      //this.symbol,
      //this.id,
      this.previousClosePrice,
      this.previousCloseTime,
      this.openPrice,
      this.openTime,
      this.historicals);

  OptionHistoricals.fromJson(dynamic json)
      : bounds = json['bounds'],
        interval = json['interval'],
        span = json['span'],
        legs = Leg.fromJsonArray(json['legs']),
        //symbol = json['symbol'],
        //id = json['id'],
        previousClosePrice = parseDouble(json['previous_close_price']),
        previousCloseTime =
            DateTime.tryParse(json['previous_close_time'] ?? ''),
        openPrice = parseDouble(json['open_price']),
        openTime = DateTime.tryParse(json['open_time'] ?? ''),
        historicals = InstrumentHistorical.fromJsonArray(json['data_points']);
}
