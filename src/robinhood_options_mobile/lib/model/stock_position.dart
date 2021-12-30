//import 'package:flutter/material.dart';

// import 'package:robinhood_options_mobile/model/option_instrument.dart';

//@immutable
/*
{
  url: https://api.robinhood.com/positions/1AB23456/6a256052-716b-4521-a324-447dc13c0fe3/, 
  instrument: https://api.robinhood.com/instruments/6a256052-716b-4521-a324-447dc13c0fe3/, 
  account: https://api.robinhood.com/accounts/1AB23456/, 
  account_number: 1AB23456, 
  average_buy_price: 0.0000, 
  pending_average_buy_price: 0.0000, 
  quantity: 0.00000000, 
  intraday_average_buy_price: 0.0000, 
  intraday_quantity: 0.00000000, 
  shares_available_for_exercise: 0.00000000, 
  shares_held_for_buys: 0.00000000, 
  shares_held_for_sells: 0.00000000, 
  shares_held_for_stock_grants: 0.00000000, 
  shares_held_for_options_collateral: 0.00000000, 
  shares_held_for_options_events: 0.00000000, 
  shares_pending_from_options_events: 0.00000000, 
  shares_available_for_closing_short_position: 0.00000000, 
  ipo_allocated_quantity: 0.00000000, 
  avg_cost_affected: false, 
  updated_at: 2020-12-08T21:57:47.461099Z, 
  created_at: 2020-10-27T02:17:16.575685Z
}
*/
import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';

class StockPosition {
  final String url;
  final String instrument;
  final String account;
  final String accountNumber;
  final double? averageBuyPrice;
  final double? pendingAverageBuyPrice;
  final double? quantity;
  final double? intradayAverageBuyPrice;
  final double? intradayQuantity;
  final double? sharesAvailableForExercise;
  final double? sharesHeldForBuys;
  final double? sharesHeldForSells;
  final double? sharesHeldForStockGrants;
  final double? sharesHeldForOptionsCollateral;
  final double? sharesHeldForOptionsEvents;
  final double? sharesPendingFromOptionsEvents;
  final double? sharesAvailableForClosingShortPosition;
  final bool averageCostAffected;
  final DateTime? updatedAt;
  final DateTime? createdAt;

  Instrument? instrumentObj;

  StockPosition(
      this.url,
      this.instrument,
      this.account,
      this.accountNumber,
      this.averageBuyPrice,
      this.pendingAverageBuyPrice,
      this.quantity,
      this.intradayAverageBuyPrice,
      this.intradayQuantity,
      this.sharesAvailableForExercise,
      this.sharesHeldForBuys,
      this.sharesHeldForSells,
      this.sharesHeldForStockGrants,
      this.sharesHeldForOptionsCollateral,
      this.sharesHeldForOptionsEvents,
      this.sharesPendingFromOptionsEvents,
      this.sharesAvailableForClosingShortPosition,
      this.averageCostAffected,
      this.updatedAt,
      this.createdAt);

  StockPosition.fromJson(dynamic json)
      : url = json['url'],
        instrument = json['instrument'],
        account = json['account'],
        accountNumber = json['account_number'],
        averageBuyPrice = double.tryParse(json['average_buy_price']),
        pendingAverageBuyPrice =
            double.tryParse(json['pending_average_buy_price']),
        quantity = double.tryParse(json['quantity']),
        intradayAverageBuyPrice =
            double.tryParse(json['intraday_average_buy_price']),
        intradayQuantity = double.tryParse(json['intraday_quantity']),
        sharesAvailableForExercise =
            double.tryParse(json['shares_available_for_exercise']),
        sharesHeldForBuys = double.tryParse(json['shares_held_for_buys']),
        sharesHeldForSells = double.tryParse(json['shares_held_for_sells']),
        sharesHeldForStockGrants =
            double.tryParse(json['shares_held_for_stock_grants']),
        sharesHeldForOptionsCollateral =
            double.tryParse(json['shares_held_for_options_collateral']),
        sharesHeldForOptionsEvents =
            double.tryParse(json['shares_held_for_options_events']),
        sharesPendingFromOptionsEvents =
            double.tryParse(json['shares_pending_from_options_events']),
        sharesAvailableForClosingShortPosition = double.tryParse(
            json['shares_available_for_closing_short_position']),
        averageCostAffected = json['avg_cost_affected'],
        updatedAt =
            //DateFormat('y-M-dTH:m:s.SZ').parse(json['updated_at'].toString()),
            DateTime.tryParse(json['updated_at']),
        // 2021-02-09T18:01:28.135813Z
        createdAt =
            //DateFormat('y-M-dTH:m:s.SZ').parse(json['created_at'].toString()),
            DateTime.tryParse(json['created_at']);

  String get instrumentId {
    var splits = instrument.split("/");
    return splits[splits.length - 2];
  }

  double get marketValue {
    if (instrumentObj == null ||
        instrumentObj!.quoteObj == null ||
        quantity == 0) {
      return 0;
    }
    return instrumentObj!.quoteObj!.lastTradePrice! * quantity!;
  }

  double get extendedHoursMarketValue {
    if (instrumentObj == null || instrumentObj!.quoteObj == null) {
      return 0;
    }

    return instrumentObj!.quoteObj!.lastExtendedHoursTradePrice! * quantity!;
  }

  double get totalCost {
    return averageBuyPrice! * quantity!;
  }

  double get gainLoss {
    return marketValue - totalCost;
  }

  double get gainLossPerShare {
    return gainLoss / quantity!;
  }

  double get gainLossPercent {
    return gainLoss / totalCost;
  }

  double get gainLossToday {
    return instrumentObj != null && instrumentObj!.quoteObj != null
        ? (instrumentObj!.quoteObj!.lastTradePrice! -
                instrumentObj!.quoteObj!.adjustedPreviousClose!) *
            quantity!
        : 0;
  }

  double get gainLossPercentToday {
    return instrumentObj != null && instrumentObj!.quoteObj != null
        ? gainLossToday /
            (instrumentObj!.quoteObj!.adjustedPreviousClose! * quantity!)
        : 0;
  }
/*
  double get changeToday {    
    return optionInstrument!.optionMarketData!.gainLossToday * quantity! * 100;
  }

  double get changePercentToday {
    return optionInstrument!.optionMarketData!.gainLossPercentToday;
  }
  */

  Icon get trendingIcon {
    return Icon(
            gainLoss > 0
                ? Icons.trending_up
                : (gainLoss < 0 ? Icons.trending_down : Icons.trending_flat),
            color: (gainLoss > 0
                ? Colors.green
                : (gainLoss < 0 ? Colors.red : Colors.grey)))
        /*: Icon(
            gainLoss < 0
                ? Icons.trending_up
                : (gainLoss > 0
                    ? Icons.trending_down
                    : Icons.trending_flat),
            color: (gainLoss < 0
                ? Colors.lightGreenAccent
                : (gainLoss > 0 ? Colors.red : Colors.grey)),
            size: 14.0)*/
        ;
  }

  Icon get trendingIconToday {
    return Icon(
            gainLossToday > 0
                ? Icons.trending_up
                : (gainLossToday < 0
                    ? Icons.trending_down
                    : Icons.trending_flat),
            color: (gainLossToday > 0
                ? Colors.green
                : (gainLossToday < 0 ? Colors.red : Colors.grey)))
        /*: Icon(
            gainLossToday < 0
                ? Icons.trending_up
                : (gainLossToday > 0 ? Icons.trending_down : Icons.trending_flat),
            color: (gainLossToday < 0
                ? Colors.lightGreenAccent
                : (gainLossToday > 0 ? Colors.red : Colors.grey)),
            size: 14.0)*/
        ;
  }
}
