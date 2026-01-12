import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:robinhood_options_mobile/model/instrument_historical.dart';
import 'package:robinhood_options_mobile/utils/json.dart';

class InstrumentHistoricals {
  final String quote;
  final String symbol;
  final String interval;
  final String span;
  final String bounds;
  final double? previousClosePrice;
  final DateTime? previousCloseTime;
  final double? openPrice;
  final DateTime? openTime;
  final String instrument;
  final String? instrumentId;

  final List<InstrumentHistorical> historicals;

  InstrumentHistoricals(
      this.quote,
      this.symbol,
      this.interval,
      this.span,
      this.bounds,
      this.previousClosePrice,
      this.previousCloseTime,
      this.openPrice,
      this.openTime,
      this.instrument,
      this.instrumentId,
      this.historicals);

  InstrumentHistoricals.fromJson(dynamic json)
      : quote = json['quote'],
        symbol = json['symbol'],
        interval = json['interval'],
        span = json['span'],
        bounds = json['bounds'],
        previousClosePrice = parseDouble(json['previous_close_price']),
        previousCloseTime = json['previous_close_time'] != null
            ? (json['previous_close_time'] is Timestamp
                ? (json['previous_close_time'] as Timestamp).toDate()
                : (json['previous_close_time'] is String
                    ? DateTime.tryParse(json['previous_close_time'])
                    : null))
            : null,
        openPrice = parseDouble(json['open_price']),
        openTime = json['open_time'] != null
            ? (json['open_time'] is Timestamp
                ? (json['open_time'] as Timestamp).toDate()
                : (json['open_time'] is String
                    ? DateTime.tryParse(json['open_time'])
                    : null))
            : null,
        instrument = json['instrument'],
        instrumentId = json['InstrumentID'],
        historicals = InstrumentHistorical.fromJsonArray(json['historicals']);

  Map<String, dynamic> toJson() => {
        'quote': quote,
        'symbol': symbol,
        'interval': interval,
        'span': span,
        'bounds': bounds,
        'previous_close_price': previousClosePrice,
        'previous_close_time': previousCloseTime, //?.toIso8601String(),
        'open_price': openPrice,
        'open_time': openTime, //?.toIso8601String(),
        'instrument': instrument,
        'InstrumentID': instrumentId,
        'historicals': historicals.map((e) => e.toJson()).toList()
        //InstrumentHistorical.toJsonArray(historicals),
      };
}
