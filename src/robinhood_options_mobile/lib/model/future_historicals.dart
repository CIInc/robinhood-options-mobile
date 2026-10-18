import 'package:robinhood_options_mobile/model/instrument_historical.dart';

class FutureHistoricals {
  final String instrumentId;
  final String symbol;
  final String interval;
  final String span;
  final String bounds;
  final List<InstrumentHistorical> historicals;

  FutureHistoricals(this.instrumentId, this.symbol, this.interval, this.span,
      this.bounds, this.historicals);

  /*
{
    "status": "SUCCESS",
    "data": [
        {
            "status": "SUCCESS",
            "data": {
                "start_time": "2026-01-28T06:00:00Z",
                "end_time": "2026-01-29T02:52:02Z",
                "interval": "5minute",
                "data_points": [
                    {
                        "begins_at": "2026-01-28T06:00:00Z",
                        "open_price": "5.992",
                        "close_price": "5.988",
                        "high_price": "5.9955",
                        "low_price": "5.986",
                        "volume": 117,
                        "interpolated": false,
                        "is_market_open": true,
                        "contract_id": "b4daeb2e-ab77-4f22-b49e-ad0db4b14d40"
                    }
                ],
                "symbol": "/MHGH26:XCEC",
                "instrument_id": "b4daeb2e-ab77-4f22-b49e-ad0db4b14d40"
            }
        }
    ]
}
  */
  FutureHistoricals.fromJson(dynamic json)
      : instrumentId = json['instrument_id'] ?? '',
        symbol = json['symbol'] ?? '',
        interval = json['interval'] ?? '',
        span = json['span'] ?? '',
        bounds = json['bounds'] ?? '',
        historicals = (json['data_points'] as List<dynamic>?)
                ?.map((e) => InstrumentHistorical.fromJson(e))
                .toList() ??
            [];
}
