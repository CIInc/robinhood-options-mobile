import 'package:flutter/material.dart';

/*
{
  "adjusted_mark_price":"2.360000",
  "ask_price":"2.500000",
  "ask_size":8,
  "bid_price":"2.220000",
  "bid_size":18,
  "break_even_price":"257.360000",
  "high_price":"2.790000",
  "instrument":"https://api.robinhood.com/options/instruments/f48cc8d3-cb4f-42bb-8c89-4f53ce43aebc/",
  "instrument_id":"f48cc8d3-cb4f-42bb-8c89-4f53ce43aebc",
  "last_trade_price":"2.320000",
  "last_trade_size":1,
  "low_price":"2.160000",
  "mark_price":"2.360000",
  "open_interest":8717,
  "previous_close_date":"2021-02-26",
  "previous_close_price":"2.130000",
  "volume":904,
  "symbol":"MSFT",
  "occ_symbol":"MSFT  210416C00255000",
  "chance_of_profit_long":"0.159839",
  "chance_of_profit_short":"0.840161",
  "delta":"0.211231",
  "gamma":"0.014084",
  "implied_volatility":"0.244214",
  "rho":"0.060047",
  "theta":"-0.064797",
  "vega":"0.243142",
  "high_fill_rate_buy_price":"2.450000",
  "high_fill_rate_sell_price":"2.260000",
  "low_fill_rate_buy_price":"2.340000",
  "low_fill_rate_sell_price":"2.370000"
}
*/

@immutable
class OptionMarketData {
  final double? adjustedMarkPrice;
  final double? askPrice;
  final int askSize;
  final double? bidPrice;
  final int bidSize;
  final double? breakEvenPrice;
  final double? highPrice;
  final String instrument;
  final String instrumentId;
  final double? lastTradePrice;
  final int lastTradeSize;
  final double? lowPrice;
  final double? markPrice;
  final int openInterest;
  final DateTime? previousCloseDate;
  final double? previousClosePrice;
  final int volume;
  final String symbol;
  final String occSymbol;
  final double? chanceOfProfitLong;
  final double? chanceOfProfitShort;
  final double? delta;
  final double? gamma;
  final double? impliedVolatility;
  final double? rho;
  final double? theta;
  final double? vega;
  final double? highFillRateBuyPrice;
  final double? highFillRateSellPrice;
  final double? lowFillRateBuyPrice;
  final double? lowFillRateSellPrice;

  const OptionMarketData(
      this.adjustedMarkPrice,
      this.askPrice,
      this.askSize,
      this.bidPrice,
      this.bidSize,
      this.breakEvenPrice,
      this.highPrice,
      this.instrument,
      this.instrumentId,
      this.lastTradePrice,
      this.lastTradeSize,
      this.lowPrice,
      this.markPrice,
      this.openInterest,
      this.previousCloseDate,
      this.previousClosePrice,
      this.volume,
      this.symbol,
      this.occSymbol,
      this.chanceOfProfitLong,
      this.chanceOfProfitShort,
      this.delta,
      this.gamma,
      this.impliedVolatility,
      this.rho,
      this.theta,
      this.vega,
      this.highFillRateBuyPrice,
      this.highFillRateSellPrice,
      this.lowFillRateBuyPrice,
      this.lowFillRateSellPrice);

  OptionMarketData.fromJson(dynamic json)
      : adjustedMarkPrice = double.tryParse(json['adjusted_mark_price']),
        askPrice = double.tryParse(json['ask_price']),
        askSize = json['ask_size'],
        bidPrice = double.tryParse(json['bid_price']),
        bidSize = json['bid_size'],
        breakEvenPrice = double.tryParse(json['break_even_price']),
        highPrice = json['high_price'] != null
            ? double.tryParse(json['high_price'])
            : null,
        instrument = json['instrument'],
        instrumentId = json['instrument_id'],
        lastTradePrice = double.tryParse(json['last_trade_price'].toString()),
        lastTradeSize = json['last_trade_size'] ?? 0,
        lowPrice = json['low_price'] != null
            ? double.tryParse(json['low_price'])
            : null,
        markPrice = double.tryParse(json['mark_price']),
        openInterest = json['open_interest'],
        previousCloseDate = DateTime.tryParse(json['previous_close_date']),
        previousClosePrice = double.tryParse(json['previous_close_price']),
        volume = json['volume'],
        symbol = json['symbol'],
        occSymbol = json['occ_symbol'],
        chanceOfProfitLong = json['chance_of_profit_long'] != null
            ? double.tryParse(json['chance_of_profit_long'])
            : null,
        chanceOfProfitShort = json['chance_of_profit_short'] != null
            ? double.tryParse(json['chance_of_profit_short'])
            : null,
        delta = json['delta'] != null ? double.tryParse(json['delta']) : null,
        gamma = json['gamma'] != null ? double.tryParse(json['gamma']) : null,
        impliedVolatility = json['implied_volatility'] != null
            ? double.tryParse(json['implied_volatility'])
            : null,
        rho = json['rho'] != null ? double.tryParse(json['rho']) : null,
        theta = json['theta'] != null ? double.tryParse(json['theta']) : null,
        vega = json['vega'] != null ? double.tryParse(json['vega']) : null,
        highFillRateBuyPrice = json['high_fill_rate_buy_price'] != null
            ? double.tryParse(json['high_fill_rate_buy_price'])
            : null,
        highFillRateSellPrice = json['high_fill_rate_sell_price'] != null
            ? double.tryParse(json['high_fill_rate_sell_price'])
            : null,
        lowFillRateBuyPrice = json['low_fill_rate_buy_price'] != null
            ? double.tryParse(json['low_fill_rate_buy_price'])
            : null,
        lowFillRateSellPrice = json['low_fill_rate_sell_price'] != null
            ? double.tryParse(json['low_fill_rate_sell_price'])
            : null;
}
