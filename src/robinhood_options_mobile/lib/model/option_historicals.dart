import 'package:flutter/foundation.dart';
import 'package:robinhood_options_mobile/model/instrument_historical.dart';

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
        previousClosePrice = json['previous_close_price'] != null
            ? double.tryParse(json['previous_close_price'])
            : null,
        previousCloseTime = json['previous_close_time'] != null
            ? DateTime.tryParse(json['previous_close_time'])
            : null,
        openPrice = json['open_price'] != null
            ? double.tryParse(json['open_price'])
            : null,
        openTime = json['open_time'] != null
            ? DateTime.tryParse(json['open_time'])
            : null,
        historicals = InstrumentHistorical.fromJsonArray(json['data_points']);
}
