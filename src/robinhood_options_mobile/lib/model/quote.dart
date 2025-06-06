import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
class Quote {
  final double? askPrice;
  final int askSize;
  final double? bidPrice;
  final int bidSize;
  final double? lastTradePrice;
  final double? lastExtendedHoursTradePrice;
  final double? previousClose;
  final double? adjustedPreviousClose;
  final DateTime? previousCloseDate;
  final String symbol;
  final bool tradingHalted;
  final bool hasTraded;
  final String lastTradePriceSource;
  final DateTime? updatedAt;
  final String instrument;
  final String instrumentId;

  const Quote(
      {this.askPrice,
      required this.askSize,
      this.bidPrice,
      required this.bidSize,
      this.lastTradePrice,
      this.lastExtendedHoursTradePrice,
      this.previousClose,
      this.adjustedPreviousClose,
      this.previousCloseDate,
      required this.symbol,
      required this.tradingHalted,
      required this.hasTraded,
      required this.lastTradePriceSource,
      this.updatedAt,
      required this.instrument,
      required this.instrumentId});

  Quote.fromJson(dynamic json)
      : askPrice = json['ask_price'] is double
            ? json['ask_price']
            : double.tryParse(json['ask_price']),
        askSize = json['ask_size'],
        bidPrice = json['bid_price'] is double
            ? json['bid_price']
            : double.tryParse(json['bid_price']),
        bidSize = json['bid_size'],
        lastTradePrice = json['last_trade_price'] is double
            ? json['last_trade_price']
            : double.tryParse(json['last_trade_price']),
        lastExtendedHoursTradePrice =
            json['last_extended_hours_trade_price'] != null
                ? (json['last_extended_hours_trade_price'] is double
                    ? json['last_extended_hours_trade_price']
                    : double.tryParse(json['last_extended_hours_trade_price']))
                : null,
        previousClose = json['previous_close'] is double
            ? json['previous_close']
            : double.tryParse(json['previous_close']),
        adjustedPreviousClose = json['adjusted_previous_close'] is double
            ? json['adjusted_previous_close']
            : double.tryParse(json['adjusted_previous_close']),
        previousCloseDate = json['previous_close_date'] is Timestamp
            ? (json['previous_close_date'] as Timestamp).toDate()
            : DateTime.tryParse(json['previous_close_date']),
        symbol = json['symbol'],
        tradingHalted =
            json['trading_halted'].toString().toLowerCase() == 'true',
        hasTraded = json['has_traded'].toString().toLowerCase() == 'true',
        lastTradePriceSource = json['last_trade_price_source'],
        updatedAt = json['updated_at'] is Timestamp
            ? (json['updated_at'] as Timestamp).toDate()
            : DateTime.tryParse(json['updated_at']),
        instrument = json['instrument'],
        instrumentId = json['instrument_id'];

  Quote.fromSchwabJson(dynamic json)
      : askPrice = json['quote']['askPrice'] as double,
        askSize = json['quote']['askSize'] as int,
        bidPrice = json['quote']['bidPrice'] as double,
        bidSize = json['quote']['bidSize'] as int,
        lastTradePrice = json['quote']['lastPrice'] as double,
        // TODO
        lastExtendedHoursTradePrice = null,
        // TODO: open price is not the same as previous close.
        previousClose = json['quote']['openPrice'] as double,
        // TODO: open price is not the same as adjusted previous close.
        adjustedPreviousClose = json['quote']['openPrice'] as double,
        // TODO
        previousCloseDate = null,
        symbol = json['symbol'],
        // TODO
        tradingHalted = false,
        // TODO
        hasTraded = true,
        lastTradePriceSource = json['quote']['lastMICId'] ?? '',
        updatedAt = DateTime.fromMillisecondsSinceEpoch(
            json['quote']['quoteTime'] as int,
            isUtc: true),
        // TODO
        instrument = '', // json['instrument'],
        // TODO
        instrumentId = json['reference']['cusip'];

  Map<String, dynamic> toJson() => {
        'ask_price': askPrice,
        'ask_size': askSize,
        'bid_price': bidPrice,
        'bid_size': bidSize,
        'last_trade_price': lastTradePrice,
        'last_extended_hours_trade_price': lastExtendedHoursTradePrice,
        'previous_close': previousClose,
        'adjusted_previous_close': adjustedPreviousClose,
        'previous_close_date': previousCloseDate, //!.toIso8601String(),
        'symbol': symbol,
        'trading_halted': tradingHalted,
        'has_traded': hasTraded,
        'last_trade_price_source': lastTradePriceSource,
        'updated_at': updatedAt, //!.toIso8601String(),
        'instrument': instrument,
        'instrument_id': instrumentId,
      };

  double get changeToday {
    return (lastExtendedHoursTradePrice ?? lastTradePrice!) -
        adjustedPreviousClose!;
  }

  // double get extendedHoursChangeToday {
  //   return lastExtendedHoursTradePrice! - adjustedPreviousClose!;
  // }

  double get changePercentToday {
    return changeToday / adjustedPreviousClose!;
  }

  // double get extendedHoursChangePercentToday {
  //   return extendedHoursChangeToday / adjustedPreviousClose!;
  // }
}
