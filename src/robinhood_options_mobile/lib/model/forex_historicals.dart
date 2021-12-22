import 'package:robinhood_options_mobile/model/instrument_historical.dart';

class ForexHistoricals {
  final String bounds;
  final String interval;
  final String span;
  final String symbol;
  final String id;
  final double? previousClosePrice;
  final DateTime? previousCloseTime;
  final double? openPrice;
  final DateTime? openTime;

  final List<InstrumentHistorical> historicals;

  ForexHistoricals(
      this.bounds,
      this.interval,
      this.span,
      this.symbol,
      this.id,
      this.previousClosePrice,
      this.previousCloseTime,
      this.openPrice,
      this.openTime,
      this.historicals);

  ForexHistoricals.fromJson(dynamic json)
      : bounds = json['bounds'],
        interval = json['interval'],
        span = json['span'],
        symbol = json['symbol'],
        id = json['id'],
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
