import 'package:robinhood_options_mobile/model/instrument.dart';

class WatchlistItem {
  final String instrument;
  final DateTime? createdAt;
  final String watchlist;
  final String url;
  Instrument? instrumentObj;
  dynamic forexObj;

  WatchlistItem(this.instrument, this.createdAt, this.watchlist, this.url);

  WatchlistItem.fromJson(dynamic json)
      : instrument = json['instrument'],
        createdAt = DateTime.tryParse(json['created_at']),
        watchlist = json['watchlist'],
        url = json['url'];
}
