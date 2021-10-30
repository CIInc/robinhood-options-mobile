import 'package:robinhood_options_mobile/model/instrument_historical.dart';

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
        instrument = json['instrument'],
        instrumentId = json['InstrumentID'],
        historicals = InstrumentHistorical.fromJsonArray(json['historicals']);
}
