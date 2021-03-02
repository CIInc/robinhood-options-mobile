//import 'package:flutter/material.dart';

// import 'package:robinhood_options_mobile/model/option_instrument.dart';

//@immutable
import 'package:robinhood_options_mobile/model/instrument.dart';

class Position {
  final String url;
  final String instrument;
  final String account;
  final String accountNumber;
  final double averageBuyPrice;
  final double pendingAverageBuyPrice;
  final double quantity;
  final double intradayAverageBuyPrice;
  final double intradayQuantity;
  final double sharesAvailableForExercise;
  final double sharesHeldForBuys;
  final double sharesHeldForSells;
  final double sharesHeldForStockGrants;
  final double sharesHeldForOptionsCollateral;
  final double sharesHeldForOptionsEvents;
  final double sharesPendingFromOptionsEvents;
  final double sharesAvailableForClosingShortPosition;
  final DateTime updatedAt;
  final DateTime createdAt;

  Instrument instrumentObj;

  Position(
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
      this.updatedAt,
      this.createdAt);

  Position.fromJson(dynamic json)
      : url = json['url'],
        instrument = json['instrument'],
        account = json['account'],
        accountNumber = json['accountNumber'],
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
        updatedAt =
            //DateFormat('y-M-dTH:m:s.SZ').parse(json['updated_at'].toString()),
            DateTime.tryParse(json['updated_at']),
        // 2021-02-09T18:01:28.135813Z
        createdAt =
            //DateFormat('y-M-dTH:m:s.SZ').parse(json['created_at'].toString()),
            DateTime.tryParse(json['created_at']);
}
