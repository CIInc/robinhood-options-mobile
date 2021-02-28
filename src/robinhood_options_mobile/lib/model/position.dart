import 'package:flutter/material.dart';

// import 'package:robinhood_options_mobile/model/option_instrument.dart';

//@immutable
class Position {
  // "url" -> "https://api.robinhood.com/positions/5QR24141/6a256052-716b-4521-a324-447dc13c0fe3/"
  final String url;
  // "instrument" -> "https://api.robinhood.com/instruments/6a256052-716b-4521-a324-447dc13c0fe3/"
  final String instrument;
  // "account" -> "https://api.robinhood.com/accounts/5QR24141/"
  final String account;
  // "account_number" -> "5QR24141"
  final String accountNumber;
  // "average_buy_price" -> "0.0000"
  final double averageBuyPrice;
  // "pending_average_buy_price" -> "0.0000"
  final double pendingAverageBuyPrice;
  // "quantity" -> "0.00000000"
  final double quantity;
  // "intraday_average_buy_price" -> "0.0000"
  final double intradayAverageBuyPrice;
  // "intraday_quantity" -> "0.00000000"
  final double intradayQuantity;
  // "shares_available_for_exercise" -> "0.00000000"
  final double sharesAvailableForExercise;
  // "shares_held_for_buys" -> "0.00000000"
  final double sharesHeldForBuys;
  // "shares_held_for_sells" -> "0.00000000"
  final double sharesHeldForSells;
  // "shares_held_for_stock_grants" -> "0.00000000"
  final double sharesHeldForStockGrants;
  // "shares_held_for_options_collateral" -> "0.00000000"
  final double sharesHeldForOptionsCollateral;
  // "shares_held_for_options_events" -> "0.00000000"
  final double sharesHeldForOptionsEvents;
  // "shares_pending_from_options_events" -> "0.00000000"
  final double sharesPendingFromOptionsEvents;
  // "shares_available_for_closing_short_position" -> "0.00000000"
  final double sharesAvailableForClosingShortPosition;
  // "updated_at" -> "2020-12-08T21:57:47.461099Z"
  final DateTime updatedAt;
  // "created_at" -> "2020-10-27T02:17:16.575685Z"
  final DateTime createdAt;

  //OptionInstrument optionInstrument;

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
