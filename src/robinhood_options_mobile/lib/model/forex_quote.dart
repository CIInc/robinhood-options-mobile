import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:robinhood_options_mobile/utils/json.dart';

/*
 {
   "ask_price":"140.000000",
   "ask_size":200,
   "bid_price":"101.000000",
   "bid_size":500,
   "last_trade_price":"121.050000",
   "last_extended_hours_trade_price":"107.100000",
   "previous_close":"112.460000",
   "adjusted_previous_close":"112.460000",
   "previous_close_date":"2021-02-26",
   "symbol":"AI",
   "trading_halted":false,
   "has_traded":true,
   "last_trade_price_source":"consolidated",
   "updated_at":"2021-03-02T01:00:00Z",
   "instrument":"https://api.robinhood.com/instruments/bd0a173e-b04e-48eb-a2a0-ce99536e7850/",
   "instrument_id":"bd0a173e-b04e-48eb-a2a0-ce99536e7850"
   }
*/
@immutable
class ForexQuote {
  final double? askPrice;
  final double? bidPrice;
  final double? markPrice;
  final double? highPrice;
  final double? lowPrice;
  final double? openPrice;
  final String symbol;
  final String id;
  final double? volume;
  final DateTime? updatedAt;

  const ForexQuote(
      this.askPrice,
      this.bidPrice,
      this.markPrice,
      this.highPrice,
      this.lowPrice,
      this.openPrice,
      this.symbol,
      this.id,
      this.volume,
      this.updatedAt);

  ForexQuote.fromJson(dynamic json)
      : askPrice = parseDouble(json['ask_price']),
        bidPrice = parseDouble(json['bid_price']),
        markPrice = parseDouble(json['mark_price']),
        highPrice = parseDouble(json['high_price']),
        lowPrice = parseDouble(json['low_price']),
        openPrice = parseDouble(json['open_price']),
        symbol = json['symbol'],
        id = json['id'],
        volume = parseDouble(json['volume']),
        updatedAt = json['updated_at'] is Timestamp
            ? (json['updated_at'] as Timestamp).toDate()
            : (json['updated_at'] is String
                ? DateTime.tryParse(json['updated_at'])
                : null);

  Map<String, dynamic> toJson() => {
        'ask_price': askPrice,
        'bid_price': bidPrice,
        'mark_price': markPrice,
        'high_price': highPrice,
        'low_price': lowPrice,
        'open_price': openPrice,
        'symbol': symbol,
        'id': id,
        'volume': volume,
        'updated_at': updatedAt, //?.toIso8601String(),
      };

  double get changeToday {
    return markPrice! - openPrice!;
  }

  double get changePercentToday {
    return changeToday / openPrice!;
  }
}
