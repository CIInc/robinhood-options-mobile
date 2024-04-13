import 'package:robinhood_options_mobile/model/forex_quote.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';

class WatchlistItem {
  final String objectType;
  final String objectId;
  final String instrument;
  final DateTime? createdAt;
  final String watchlist;
  final String url;

  Instrument? instrumentObj;
  ForexQuote? forexObj;
  OptionInstrument? optionInstrumentObj;

  WatchlistItem(this.objectType, this.objectId, this.instrument, this.createdAt,
      this.watchlist, this.url);

  WatchlistItem.fromJson(dynamic json)
      : objectType = json['object_type'],
        objectId = json['object_id'],
        instrument = json['instrument'] ?? '',
        createdAt = DateTime.tryParse(json['created_at']),
        watchlist = json['watchlist'] ?? '',
        url = json['url'] ?? '';
}
/*
0:"created_at" -> "2021-12-30T10:00:53.039890Z"
1:"id" -> "fbdcf48b-2d52-4728-8579-5c871272272b"
2:"list_id" -> "d2c090b9-6278-4fcc-a7d6-8b7b69ced8bf"
3:"object_id" -> "31f1745b-6060-49c4-a728-3be519f31315"
4:"object_type" -> "instrument"
5:"owner_type" -> "robinhood"
6:"updated_at" -> "2021-12-30T10:00:53.039895Z"
7:"weight" -> "1.00000"
8:"open_price" -> null
9:"open_price_direction" -> null
10:"market_cap" -> 119909436100.0
11:"name" -> "Citigroup"
12:"open_positions" -> 0
13:"symbol" -> "C"
14:"uk_tradability" -> "tradable"
15:"us_tradability" -> "tradable"
16:"state" -> "active"
17:"ipo_access_status" -> null
18:"one_day_dollar_change" -> -0.11
19:"one_day_percent_change" -> -0.18169805087545424
20:"one_day_rolling_dollar_change" -> -0.11
21:"one_day_rolling_percent_change" -> -0.18169805087545424
22:"price" -> 60.43
23:"total_return_percentage" -> null
24:"holdings" -> true
*/
