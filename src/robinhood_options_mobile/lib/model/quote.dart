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
      this.askPrice,
      this.askSize,
      this.bidPrice,
      this.bidSize,
      this.lastTradePrice,
      this.lastExtendedHoursTradePrice,
      this.previousClose,
      this.adjustedPreviousClose,
      this.previousCloseDate,
      this.symbol,
      this.tradingHalted,
      this.hasTraded,
      this.lastTradePriceSource,
      this.updatedAt,
      this.instrument,
      this.instrumentId);

  Quote.fromJson(dynamic json)
      : askPrice = double.tryParse(json['ask_price']),
        askSize = json['ask_size'],
        bidPrice = double.tryParse(json['bid_price']),
        bidSize = json['bid_size'],
        lastTradePrice = double.tryParse(json['last_trade_price']),
        lastExtendedHoursTradePrice =
            json['last_extended_hours_trade_price'] != null
                ? double.tryParse(json['last_extended_hours_trade_price'])
                : null,
        previousClose = double.tryParse(json['previous_close']),
        adjustedPreviousClose =
            double.tryParse(json['adjusted_previous_close']),
        previousCloseDate = DateTime.tryParse(json['previous_close_date']),
        symbol = json['symbol'],
        tradingHalted =
            json['trading_halted'].toString().toLowerCase() == 'true',
        hasTraded = json['has_traded'].toString().toLowerCase() == 'true',
        lastTradePriceSource = json['last_trade_price_source'],
        updatedAt = DateTime.tryParse(json['updated_at']),
        instrument = json['instrument'],
        instrumentId = json['instrument_id'];

  double get changeToday {
    return lastTradePrice! - adjustedPreviousClose!;
  }

  double get extendedHoursChangeToday {
    return lastExtendedHoursTradePrice! - adjustedPreviousClose!;
  }

  double get changeTodayPercent {
    return changeToday / adjustedPreviousClose!;
  }

  double get extendedHoursChangeTodayPercent {
    return extendedHoursChangeToday / adjustedPreviousClose!;
  }
}
