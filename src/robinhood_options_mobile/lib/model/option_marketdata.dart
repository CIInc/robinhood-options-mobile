import 'package:cloud_firestore/cloud_firestore.dart';
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
  final DateTime? updatedAt;

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
      this.lowFillRateSellPrice,
      this.updatedAt);

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
            : null,
        updatedAt = json['updated_at'] is Timestamp
            ? (json['updated_at'] as Timestamp).toDate()
            : DateTime.tryParse(json['updated_at']);

  // toMarkdownTable generates a markdown table from a list of OptionMarketData populating the table with all properties of the class
  static String toMarkdownTable(List<OptionMarketData> data) {
    String table = '| Adjusted Mark Price | Ask Price | Ask Size | Bid Price | Bid Size | Break Even Price | High Price | Instrument | Instrument ID | Last Trade Price | Last Trade Size | Low Price | Mark Price | Open Interest | Previous Close Date | Previous Close Price | Volume | Symbol | OCC Symbol | Chance of Profit Long | Chance of Profit Short | Delta | Gamma | Implied Volatility | Rho | Theta | Vega | High Fill Rate Buy Price | High Fill Rate Sell Price | Low Fill Rate Buy Price | Low Fill Rate Sell Price |\n';
    table += '|---------------------|-----------|----------|-----------|----------|------------------|------------|------------|---------------|------------------|-----------------|-----------|------------|----------------|----------------------|----------------------|--------|--------|------------|---------------------|---------------------|-------|-------|-------------------|-----|-------|------|-------------------------|-------------------------|-----------------------|-----------------------|\n';
    for (var item in data) {
      table += '| ${item.adjustedMarkPrice}  ' +
          '| ${item.askPrice}  ' +
          '| ${item.askSize}  ' +
          '| ${item.bidPrice}  ' +
          '| ${item.bidSize}  ' +
          '| ${item.breakEvenPrice}  ' +
          '| ${item.highPrice}  ' +
          '| ${item.instrument}  ' +
          '| ${item.instrumentId}  ' +
          '| ${item.lastTradePrice}  ' +
          '| ${item.lastTradeSize}  ' +
          '| ${item.lowPrice}  ' +
          '| ${item.markPrice}  ' +
          '| ${item.openInterest}  ' +
          '| ${item.previousCloseDate?.toIso8601String()}  ' +
          '| ${item.previousClosePrice}  ' +
          '| ${item.volume}  ' +
          '| ${item.symbol}  ' +
          '| ${item.occSymbol}  ' +
          '| ${item.chanceOfProfitLong}  ' +
          '| ${item.chanceOfProfitShort}  ' +
          '| ${item.delta}  ' +
          '| ${item.gamma}  ' +
          '| ${item.impliedVolatility}  ' +
          '| ${item.rho}  ' +
          '| ${item.theta}  ' +
          '| ${item.vega}  ' +
          '| ${item.highFillRateBuyPrice}  ' +
          '| ${item.highFillRateSellPrice}  ' +
          '| ${item.lowFillRateBuyPrice}  ' +
          '| ${item.lowFillRateSellPrice}  ' +
          '| ${item.updatedAt?.toIso8601String()}  ' +
          '|\n';
    }
    return table;
  }
  // toMarkdownTableHeader generates a markdown table header from the class properties
  static String toMarkdownTableHeader() {
    return '| Adjusted Mark Price | Ask Price | Ask Size | Bid Price | Bid Size | Break Even Price | High Price | Instrument | Instrument ID | Last Trade Price | Last Trade Size | Low Price | Mark Price | Open Interest | Previous Close Date | Previous Close Price | Volume | Symbol | OCC Symbol | Chance of Profit Long | Chance of Profit Short | Delta | Gamma | Implied Volatility | Rho | Theta | Vega | High Fill Rate Buy Price | High Fill Rate Sell Price | Low Fill Rate Buy Price | Low Fill Rate Sell Price |\n' '|---------------------|-----------|----------|-----------|----------|------------------|------------|------------|---------------|------------------|-----------------|-----------|------------|----------------|----------------------|----------------------|--------|--------|------------|---------------------|---------------------|-------|-------|-------------------|-----|-------|------|-------------------------|-------------------------|-----------------------|-----------------------|\n';
  }

  // Returns a list of strings representing the row for markdown table
  List<String> toMarkdownTableRow() {
    return [
      adjustedMarkPrice?.toString() ?? '',
      askPrice?.toString() ?? '',
      askSize.toString(),
      bidPrice?.toString() ?? '',
      bidSize.toString(),
      breakEvenPrice?.toString() ?? '',
      highPrice?.toString() ?? '',
      instrument,
      instrumentId,
      lastTradePrice?.toString() ?? '',
      lastTradeSize.toString(),
      lowPrice?.toString() ?? '',
      markPrice?.toString() ?? '',
      openInterest.toString(),
      previousCloseDate?.toIso8601String() ?? '',
      previousClosePrice?.toString() ?? '',
      volume.toString(),
      symbol,
      occSymbol,
      chanceOfProfitLong?.toString() ?? '',
      chanceOfProfitShort?.toString() ?? '',
      delta?.toString() ?? '',
      gamma?.toString() ?? '',
      impliedVolatility?.toString() ?? '',
      rho?.toString() ?? '',
      theta?.toString() ?? '',
      vega?.toString() ?? '',
      highFillRateBuyPrice?.toString() ?? '',
      highFillRateSellPrice?.toString() ?? '',
      lowFillRateBuyPrice?.toString() ?? '',
      lowFillRateSellPrice?.toString() ?? '',
      updatedAt?.toIso8601String() ?? '',
    ];
  }
    
  // toJson to support Firestore  
  Map<String, dynamic> toJson() {
    return {
      'adjusted_mark_price': adjustedMarkPrice,
      'ask_price': askPrice,
      'ask_size': askSize,
      'bid_price': bidPrice,
      'bid_size': bidSize,
      'break_even_price': breakEvenPrice,
      'high_price': highPrice,
      'instrument': instrument,
      'instrument_id': instrumentId,
      'last_trade_price': lastTradePrice,
      'last_trade_size': lastTradeSize,
      'low_price': lowPrice,
      'mark_price': markPrice,
      'open_interest': openInterest,
      'previous_close_date': previousCloseDate, //?.toIso8601String(),
      'previous_close_price': previousClosePrice,
      'volume': volume,
      'symbol': symbol,
      'occ_symbol': occSymbol,
      'chance_of_profit_long': chanceOfProfitLong,
      'chance_of_profit_short': chanceOfProfitShort,
      'delta': delta,
      'gamma': gamma,
      'implied_volatility': impliedVolatility,
      'rho': rho,
      'theta': theta,
      'vega': vega,
      'high_fill_rate_buy_price': highFillRateBuyPrice,
      'high_fill_rate_sell_price': highFillRateSellPrice,
      'low_fill_rate_buy_price': lowFillRateBuyPrice,
      'low_fill_rate_sell_price': lowFillRateSellPrice,
      'updated_at': updatedAt, //?.toIso8601String(),
    };
  }

  /*
{"putCall":"CALL","symbol":"AMAT  241115C00210000","description":"AMAT 11/15/2024 210.00 C",
"exchangeName":"OPR","bid":1.72,"ask":1.9,"last":1.88,"mark":1.81,"bidSize":22,
"askSize":61,"bidAskSize":"22X61","lastSize":0,"highPrice":2.25,"lowPrice":1.8,
"openPrice":0.0,"closePrice":1.57,"totalVolume":310,"tradeTimeInLong":1729884786730,
"quoteTimeInLong":1729886399500,"netChange":0.31,"volatility":47.215,"delta":0.169,
"gamma":0.012,"theta":-0.13,"vega":0.113,"rho":0.017,"openInterest":1704,"timeValue":1.88,
"theoreticalOptionValue":1.81,"theoreticalVolatility":29.0,
"optionDeliverablesList":[{"symbol":"AMAT","assetType":"STOCK","deliverableUnits":100.0}],
"strikePrice":210.0,"expirationDate":"2024-11-15T21:00:00.000+00:00","daysToExpiration":21,
"expirationType":"S","lastTradingDay":1731718800000,"multiplier":100.0,
"settlementType":"P","deliverableNote":"100 AMAT","percentChange":19.79,
"markChange":0.24,"markPercentChange":15.57,"intrinsicValue":-23.48,
"extrinsicValue":25.36,"optionRoot":"AMAT","exerciseType":"A","high52Week":50.85,
"low52Week":1.45,"nonStandard":false,"pennyPilot":true,"inTheMoney":false,"mini":false}
*/
  OptionMarketData.fromSchwabJson(dynamic json)
      : adjustedMarkPrice = json['mark'] as double,
        askPrice = json['ask'] as double,
        askSize = json['askSize'] as int,
        bidPrice = json['bid'] as double,
        bidSize = json['bidSize'] as int,
        breakEvenPrice = null,
        highPrice = json['highPrice'] as double,
        instrument = '', // TODO
        instrumentId = '', // TODO
        lastTradePrice = json['last'] as double,
        lastTradeSize = json['lastSize'] as int,
        lowPrice = json['lowPrice'] as double,
        markPrice = json['mark'] as double,
        openInterest = json['openInterest'] as int,
        previousCloseDate = null, // TODO
        previousClosePrice =
            (json['mark'] as double) - (json['markChange'] as double),
        volume = json['totalVolume'] as int,
        symbol = json['optionRoot'],
        occSymbol = json['optionRoot'], // TODO
        chanceOfProfitLong = null, // TODO
        chanceOfProfitShort = null, // TODO
        delta = json['delta'] as double,
        gamma = json['gamma'] as double,
        impliedVolatility = json['volatility'] as double,
        rho = json['rho'] as double,
        theta = json['theta'] as double,
        vega = json['vega'] as double,
        highFillRateBuyPrice = null, // TODO
        highFillRateSellPrice = null, // TODO
        lowFillRateBuyPrice = null, // TODO
        lowFillRateSellPrice = null, // TODO
        updatedAt = DateTime.now();

  double get changeToday {
    return previousClosePrice != null
        ? adjustedMarkPrice! - previousClosePrice!
        : 0;
  }

  double get changePercentToday {
    return changeToday / previousClosePrice!;
  }
}
