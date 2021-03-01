import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';

/*
// "instrument" -> "https://api.robinhood.com/instruments/b1d51de1-b1b7-42eb-87c3-6d383091cb3b/"
// "created_at" -> "2015-02-11T18:22:53.825192Z"
// "watchlist" -> "https://api.robinhood.com/watchlists/Default/"
// "url" -> "https://api.robinhood.com/watchlists/Default/b1d51de1-b1b7-42eb-87c3-6d383091cb3b/"
*/
//@immutable
class WatchlistItem {
  final String instrumentUrl;
  final DateTime createdAt;
  final String watchlist;
  final String url;
  Instrument instrument;

  WatchlistItem(this.instrumentUrl, this.createdAt, this.watchlist, this.url);

  WatchlistItem.fromJson(dynamic json)
      : instrumentUrl = json['instrument'],
        createdAt = DateTime.tryParse(json['created_at']),
        watchlist = json['watchlist'],
        url = json['url'];
}
