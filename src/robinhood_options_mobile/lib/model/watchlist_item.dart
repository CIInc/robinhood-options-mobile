import 'package:robinhood_options_mobile/model/forex_quote.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';

class WatchlistItem {
  final String instrument;
  final DateTime? createdAt;
  final String watchlist;
  final String url;
  Instrument? instrumentObj;
  ForexQuote? forexObj;
  OptionInstrument? optionInstrumentObj;

  WatchlistItem(this.instrument, this.createdAt, this.watchlist, this.url);

  WatchlistItem.fromJson(dynamic json)
      : instrument = json['instrument'],
        createdAt = DateTime.tryParse(json['created_at']),
        watchlist = json['watchlist'],
        url = json['url'];
}
