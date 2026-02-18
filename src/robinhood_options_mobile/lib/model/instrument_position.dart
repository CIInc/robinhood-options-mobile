//import 'package:flutter/material.dart';

// import 'package:robinhood_options_mobile/model/option_instrument.dart';

import 'package:robinhood_options_mobile/utils/json.dart';

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
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';

class InstrumentPosition {
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
  // DocumentReference<Instrument>? instrumentDocRef;

  /// Parses instrument_obj (snake_case) or instrumentObj (camelCase) from JSON.
  /// Firestore/PaperTradingStore saves camelCase; PaperService creates snake_case.
  static Instrument? _parseInstrumentObj(dynamic json) {
    final obj = json['instrument_obj'] ?? json['instrumentObj'];
    return obj != null ? Instrument.fromJson(obj) : null;
  }

  InstrumentPosition(
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

  InstrumentPosition.fromJson(dynamic json)
      : url = json['url'],
        instrument = json['instrument'],
        account = json['account'],
        accountNumber = json['account_number'],
        averageBuyPrice = parseDouble(json['average_buy_price']),
        pendingAverageBuyPrice = parseDouble(json['pending_average_buy_price']),
        quantity = parseDouble(json['quantity']),
        intradayAverageBuyPrice =
            parseDouble(json['intraday_average_buy_price']),
        intradayQuantity = parseDouble(json['intraday_quantity']),
        sharesAvailableForExercise =
            parseDouble(json['shares_available_for_exercise']),
        sharesHeldForBuys = parseDouble(json['shares_held_for_buys']),
        sharesHeldForSells = parseDouble(json['shares_held_for_sells']),
        sharesHeldForStockGrants =
            parseDouble(json['shares_held_for_stock_grants']),
        sharesHeldForOptionsCollateral =
            parseDouble(json['shares_held_for_options_collateral']),
        sharesHeldForOptionsEvents =
            parseDouble(json['shares_held_for_options_events']),
        sharesPendingFromOptionsEvents =
            parseDouble(json['shares_pending_from_options_events']),
        sharesAvailableForClosingShortPosition =
            parseDouble(json['shares_available_for_closing_short_position']),
        averageCostAffected = json['avg_cost_affected'],
        updatedAt =
            //DateFormat('y-M-dTH:m:s.SZ').parse(json['updated_at'].toString()),
            json['updated_at'] is Timestamp
                ? (json['updated_at'] as Timestamp).toDate()
                : DateTime.tryParse(json['updated_at']),
        // 2021-02-09T18:01:28.135813Z
        createdAt =
            //DateFormat('y-M-dTH:m:s.SZ').parse(json['created_at'].toString()),
            json['created_at'] is Timestamp
                ? (json['created_at'] as Timestamp).toDate()
                : DateTime.tryParse(json['created_at']),
        instrumentObj = _parseInstrumentObj(json);
  // instrumentDocRef = json['instrumentDocRef'] != null
  //     ? json['instrumentDocRef'] as DocumentReference<Instrument>
  //     : null;

  InstrumentPosition.fromSchwabJson(dynamic json)
      : url = '', // json['url'],
        instrument = '/${json['instrument']['cusip']}/', // json['instrument'],
        account = '', // json['account'],
        accountNumber = '', // json['account_number'],
        averageBuyPrice = json['averagePrice'] as double,
        pendingAverageBuyPrice = json['averagePrice'] as double,
        quantity = json['longQuantity'] as double,
        intradayAverageBuyPrice = json['averagePrice'] as double,
        intradayQuantity = json['longQuantity'] as double,
        sharesAvailableForExercise = 0,
        sharesHeldForBuys = 0,
        sharesHeldForSells = 0,
        sharesHeldForStockGrants = 0,
        sharesHeldForOptionsCollateral = 0,
        sharesHeldForOptionsEvents = 0,
        sharesPendingFromOptionsEvents = 0,
        sharesAvailableForClosingShortPosition = 0,
        averageCostAffected = false,
        updatedAt = DateTime.now(),
        createdAt = DateTime.now(),
        instrumentObj = Instrument(
            id: json['instrument']['cusip'],
            url: '',
            quote: '',
            fundamentals: '',
            splits: '',
            state: '',
            market: '',
            name: json['instrument']['description'],
            tradeable: true,
            tradability: '',
            symbol: json['instrument']['symbol'],
            bloombergUnique: '',
            country: '',
            type: json['instrument']['type'],
            rhsTradability: '',
            fractionalTradability: '',
            isSpac: false,
            isTest: false,
            ipoAccessSupportsDsp: false,
            dateCreated: DateTime.now());

  InstrumentPosition.fromPlaidJson(dynamic json)
      : url = '', // json['url'],
        instrument = '/${json['instrument']['cusip']}/', // json['instrument'],
        account = '', // json['account'],
        accountNumber = '', // json['account_number'],
        averageBuyPrice = json['averagePrice'] as double,
        pendingAverageBuyPrice = json['averagePrice'] as double,
        quantity = json['longQuantity'] as double,
        intradayAverageBuyPrice = json['averagePrice'] as double,
        intradayQuantity = json['longQuantity'] as double,
        sharesAvailableForExercise = 0,
        sharesHeldForBuys = 0,
        sharesHeldForSells = 0,
        sharesHeldForStockGrants = 0,
        sharesHeldForOptionsCollateral = 0,
        sharesHeldForOptionsEvents = 0,
        sharesPendingFromOptionsEvents = 0,
        sharesAvailableForClosingShortPosition = 0,
        averageCostAffected = false,
        updatedAt = DateTime.now(),
        createdAt = DateTime.now(),
        instrumentObj = Instrument(
            id: json['instrument']['cusip'],
            url: '',
            quote: '',
            fundamentals: '',
            splits: '',
            state: '',
            market: '',
            name: json['instrument']['description'],
            tradeable: true,
            tradability: '',
            symbol: json['instrument']['symbol'],
            bloombergUnique: '',
            country: '',
            type: json['instrument']['type'],
            rhsTradability: '',
            fractionalTradability: '',
            isSpac: false,
            isTest: false,
            ipoAccessSupportsDsp: false,
            dateCreated: DateTime.now());

  Map<String, dynamic> toJson() => {
        'url': url,
        'instrument': instrument,
        'account': account,
        'account_number': accountNumber,
        'average_buy_price': averageBuyPrice,
        'pending_average_buy_price': pendingAverageBuyPrice,
        'quantity': quantity,
        'intraday_average_buy_price': intradayAverageBuyPrice,
        'intraday_quantity': intradayQuantity,
        'shares_available_for_exercise': sharesAvailableForExercise,
        'shares_held_for_buys': sharesHeldForBuys,
        'shares_held_for_sells': sharesHeldForSells,
        'shares_held_for_stock_grants': sharesHeldForStockGrants,
        'shares_held_for_options_collateral': sharesHeldForOptionsCollateral,
        'shares_held_for_options_events': sharesHeldForOptionsEvents,
        'shares_pending_from_options_events': sharesPendingFromOptionsEvents,
        'shares_available_for_closing_short_position':
            sharesAvailableForClosingShortPosition,
        'avg_cost_affected': averageCostAffected,
        'updated_at': updatedAt,
        'created_at': createdAt,
        'instrument_obj': instrumentObj?.toJson(),
        // 'instrumentDocRef': instrumentDocRef
      };

  String get instrumentId {
    var splits = instrument.split("/").where((s) => s.isNotEmpty).toList();
    return splits.isNotEmpty ? splits.last : '';
  }

  double get marketValue {
    if (instrumentObj == null ||
        instrumentObj!.quoteObj == null ||
        quantity == 0) {
      return 0;
    }
    return (instrumentObj!.quoteObj!.lastExtendedHoursTradePrice ??
            instrumentObj!.quoteObj!.lastTradePrice!) *
        quantity!;
  }

  // Deprecated for marketValue which automatically uses extended hours when available.
  // double get extendedHoursMarketValue {
  //   if (instrumentObj == null || instrumentObj!.quoteObj == null) {
  //     return 0;
  //   }

  //   return instrumentObj!.quoteObj!.lastExtendedHoursTradePrice! * quantity!;
  // }

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
        ? ((instrumentObj!.quoteObj!.lastExtendedHoursTradePrice ??
                    instrumentObj!.quoteObj!.lastTradePrice!) -
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
