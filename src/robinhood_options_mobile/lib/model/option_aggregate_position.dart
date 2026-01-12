import 'dart:io';

import 'package:csv/csv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:robinhood_options_mobile/utils/json.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/option_leg.dart';
//import 'package:robinhood_options_mobile/model/option_marketdata.dart';

//@immutable
class OptionAggregatePosition {
  final String id;
  final String chain;
  final String account;
  final String symbol;
  final String strategy;
  final double? averageOpenPrice;
  List<OptionLeg> legs;
  final double? quantity;
  final double? intradayAverageOpenPrice;
  final double? intradayQuantity;
  final String direction;
  final String intradayDirection;
  final double? tradeValueMultiplier;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String strategyCode;

  OptionInstrument? optionInstrument;
  // Redundant with this.optionInstrument.marketData
  //OptionMarketData? marketData;
  Instrument? instrumentObj;
  String? logoUrl;

  OptionAggregatePosition(
      this.id,
      this.chain,
      this.account,
      this.symbol,
      this.strategy,
      this.averageOpenPrice,
      this.legs,
      this.quantity,
      this.intradayAverageOpenPrice,
      this.intradayQuantity,
      this.direction,
      this.intradayDirection,
      this.tradeValueMultiplier,
      this.createdAt,
      this.updatedAt,
      this.strategyCode);

  OptionAggregatePosition.fromJson(dynamic json)
      : id = json['id'],
        chain = json['chain'],
        account = json['account'],
        symbol = json['symbol'],
        strategy = json['strategy'],
        averageOpenPrice = parseDouble(json['average_open_price']),
        legs = OptionLeg.fromJsonArray(json['legs']),
        quantity = parseDouble(json['quantity']),
        intradayAverageOpenPrice =
            parseDouble(json['intraday_average_open_price']),
        intradayQuantity = parseDouble(json['intraday_quantity']),
        direction = json['direction'],
        intradayDirection = json['intraday_direction'],
        tradeValueMultiplier = parseDouble(json['trade_value_multiplier']),
        createdAt = json['created_at'] is Timestamp
            ? (json['created_at'] as Timestamp).toDate()
            : (json['created_at'] is String
                ? DateTime.tryParse(json['created_at'])
                : null),
        updatedAt = json['updated_at'] is Timestamp
            ? (json['updated_at'] as Timestamp).toDate()
            : (json['updated_at'] is String
                ? DateTime.tryParse(json['updated_at'])
                : null),
        strategyCode = json['strategy_code'];

  /*
  {shortQuantity: 0.0, averagePrice: 3.8266, currentDayProfitLoss: -83.0, currentDayProfitLossPercentage: -22.93, longQuantity: 2.0, settledLongQuantity: 2.0, settledShortQuantity: 0.0, instrument: {assetType: OPTION, cusip: 0AMAT.KF40210000, symbol: AMAT  241115C00210000, description: APPLIED MATLS INC 11/15/2024 $210 Call, netChange: -0.41, type: VANILLA, putCall: CALL, underlyingSymbol: AMAT}, marketValue: 279.0, maintenanceRequirement: 0.0, averageLongPrice: 3.82, taxLotAverageLongPrice: 3.8266, longOpenProfitLoss: -486.32, previousSessionLongQuantity: 2.0, currentDayCost: 0.0}
  */
  OptionAggregatePosition.fromSchwabJson(dynamic json, Account acct)
      : id = json['instrument']['cusip'],
        chain = '', // json['chain'],
        account = acct.accountNumber, // json['account'],
        symbol = json['instrument']['underlyingSymbol'], // json['symbol'],
        strategy = json['instrument']['putCall'], // json['strategy'],
        averageOpenPrice = json['averagePrice'] *
            100, // Multiplied Schwab's average price which is per share, not per contract like Robinhood.
        legs = [
          OptionLeg(
              '', // id
              null, // position,
              json["longQuantity"] > 0 ? 'long' : 'short', // positionType,
              '', // option,
              null, // positionEffect,
              0, // ratioQuantity,
              null, // side,
              DateFormat("MM/dd/yyyy").tryParse(json['instrument']
                      ['description']
                  .toString()
                  .split(' ')
                  .reversed
                  .skip(2)
                  .first), // expirationDate,
              double.tryParse(json['instrument']['description']
                  .toString()
                  .split(' ')
                  .reversed
                  .skip(1)
                  .first
                  .replaceFirst('\$', '')), // strikePrice
              json['instrument']['putCall'],
              [] // executions
              )
        ], // OptionLeg.fromJsonArray(json['legs']),
        quantity = json['longQuantity'] > 0
            ? json['longQuantity']
            : json['shortQuantity'],
        intradayAverageOpenPrice =
            null, // double.tryParse(json['intraday_average_open_price']),
        intradayQuantity = null, // double.tryParse(json['intraday_quantity']),
        direction = json['shortQuantity'] > 0
            ? 'credit'
            : 'debit', // json['direction'], //  json['instrument']['putCall']
        intradayDirection = '', // json['intraday_direction'],
        tradeValueMultiplier =
            null, // double.tryParse(json['trade_value_multiplier']),
        createdAt = null, // DateTime.tryParse(json['created_at']),
        updatedAt = null, // DateTime.tryParse(json['updated_at']),
        strategyCode = '', //json['strategy_code'];
        optionInstrument = OptionInstrument(
            json['instrument']['cusip'],
            json['instrument']['underlyingSymbol'],
            null,
            DateFormat("MM/dd/yyyy").tryParse(json['instrument']['description']
                .toString()
                .split(' ')
                .reversed
                .skip(2)
                .first), // expirationDate
            json['instrument']['cusip'],
            null,
            MinTicks(0, 0, 0),
            '',
            '',
            double.tryParse(json['instrument']['description']
                .toString()
                .split(' ')
                .reversed
                .skip(1)
                .first
                .replaceFirst('\$', '')), // strikePrice
            '',
            json['instrument']['putCall'], // type,
            null,
            '',
            null,
            '', // longStrategyCode,
            ''),
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

  OptionAggregatePosition.fromPlaidJson(
      dynamic json, dynamic json2, Account acct)
      : id = json2['security_id'],
        chain = '', // json['chain'],
        account = acct.accountNumber, // json['account'],
        symbol = json2['option_contract']?['underlying_security_ticker'] ??
            '', // json['symbol'],
        strategy = json2['option_contract']?['contract_type'] ??
            '', // json['strategy'],
        averageOpenPrice = json['cost_basis'] *
            100, // Multiplied Schwab's average price which is per share, not per contract like Robinhood.
        legs = [
          OptionLeg(
              '', // id
              null, // position,
              null, // json["longQuantity"] > 0 ? 'long' : 'short', // positionType,
              '', // option,
              null, // positionEffect,
              0, // ratioQuantity,
              null, // side,
              json2['option_contract'] != null
                  ? DateFormat("yyyy-MM-dd") // DateFormat("yyyy-MM-dd")
                      .tryParse(json2['option_contract']['expiration_date'])
                  : null, // expirationDate,
              json2['option_contract'] != null
                  ? (json2['option_contract']['strike_price']).toDouble()
                  : null, // strikePrice
              json2['option_contract'] != null
                  ? json2['option_contract']['contract_type']
                  : '', // optionType
              [] // executions
              )
        ], // OptionLeg.fromJsonArray(json['legs']),
        quantity = json['quantity'].toDouble(),
        intradayAverageOpenPrice =
            null, // double.tryParse(json['intraday_average_open_price']),
        intradayQuantity = null, // double.tryParse(json['intraday_quantity']),
        direction = json2['option_contract']?['contract_type'] ??
            '', // json['direction'],
        intradayDirection = '', // json['intraday_direction'],
        tradeValueMultiplier =
            null, // double.tryParse(json['trade_value_multiplier']),
        createdAt = null, // DateTime.tryParse(json['created_at']),
        updatedAt = null, // DateTime.tryParse(json['updated_at']),
        strategyCode = '', //json['strategy_code'];
        optionInstrument = OptionInstrument(
            json2['security_id'],
            json2['option_contract']?['underlying_security_ticker'] ?? '',
            null,
            json2['option_contract'] != null
                ? DateFormat("yyyy-MM-dd")
                    .tryParse(json2['option_contract']['expiration_date'])
                : null, // expirationDate,
            json2['security_id'],
            null,
            MinTicks(0, 0, 0),
            '',
            '',
            json2['option_contract'] != null
                ? (json2['option_contract']['strike_price']).toDouble()
                : null, // strikePrice
            '',
            json2['option_contract']?['contract_type'] ?? '', // type,
            null,
            '',
            null,
            '', // longStrategyCode,
            ''); //shortStrategyCode);

  Map<String, dynamic> toJson() => {
        'id': id,
        'chain': chain,
        'account': account,
        'symbol': symbol,
        'strategy': strategy,
        'average_open_price': averageOpenPrice,
        'legs': legs.map((leg) => leg.toJson()).toList(),
        'quantity': quantity,
        'intraday_average_open_price': intradayAverageOpenPrice,
        'intraday_quantity': intradayQuantity,
        'direction': direction,
        'intraday_direction': intradayDirection,
        'trade_value_multiplier': tradeValueMultiplier,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'strategy_code': strategyCode
      };

  // Helpers
  double get marketValue {
    if (optionInstrument == null ||
        optionInstrument!.optionMarketData == null) {
      return 0;
    }
    return (optionInstrument!.optionMarketData!.adjustedMarkPrice ??
            optionInstrument!.optionMarketData!.markPrice!) *
        quantity! *
        100;
  }

  double get totalCost {
    return averageOpenPrice! * quantity!;
  }

  double get gainLoss {
    return marketValue - totalCost;
  }

  double get gainLossPerContract {
    return gainLoss / quantity!;
  }

  double get gainLossPercent {
    return gainLoss / totalCost;
  }

  Icon get trendingIcon {
    return direction == "debit"
        ? Icon(
            gainLossPerContract > 0
                ? Icons.trending_up
                : (gainLossPerContract < 0
                    ? Icons.trending_down
                    : Icons.trending_flat),
            color: (gainLossPerContract > 0
                ? Colors.lightGreenAccent
                : (gainLossPerContract < 0 ? Colors.red : Colors.grey)),
            size: 14.0)
        : Icon(
            gainLossPerContract < 0
                ? Icons.trending_up
                : (gainLossPerContract > 0
                    ? Icons.trending_down
                    : Icons.trending_flat),
            color: (gainLossPerContract < 0
                ? Colors.lightGreenAccent
                : (gainLossPerContract > 0 ? Colors.red : Colors.grey)),
            size: 14.0);
  }

  Icon get trendingIconToday {
    return direction == "debit"
        ? Icon(
            changeToday > 0
                ? Icons.trending_up
                : (changeToday < 0 ? Icons.trending_down : Icons.trending_flat),
            color: (changeToday > 0
                ? Colors.lightGreenAccent
                : (changeToday < 0 ? Colors.red : Colors.grey)),
            size: 14.0)
        : Icon(
            changeToday < 0
                ? Icons.trending_up
                : (changeToday > 0 ? Icons.trending_down : Icons.trending_flat),
            color: (changeToday < 0
                ? Colors.lightGreenAccent
                : (changeToday > 0 ? Colors.red : Colors.grey)),
            size: 14.0);
  }

  double get shortCollateral {
    return legs.first.strikePrice! * 100 * quantity!;
  }

  double get collateralReturn {
    return totalCost / shortCollateral;
  }

  /* See marketValue
  double get equity {
    return optionInstrument!.optionMarketData!.adjustedMarkPrice! *
        quantity! *
        100;
  }
  */

  double get changeToday {
    return optionInstrument != null &&
            optionInstrument!.optionMarketData != null
        ? optionInstrument!.optionMarketData!.changeToday * quantity! * 100
        : 0;
  }

  double get changePercentToday {
    return optionInstrument != null &&
            optionInstrument!.optionMarketData != null
        ? optionInstrument!.optionMarketData!.changePercentToday
        : 0;
  }

  /* CSV Generation */

  List<dynamic> convertToDynamic() {
    List<dynamic> row = [];
    row.add(id);
    row.add(chain);
    row.add(account);
    row.add(symbol);
    row.add(strategy);
    row.add(averageOpenPrice);
    row.add(legs);
    row.add(quantity);
    row.add(intradayAverageOpenPrice);
    row.add(intradayQuantity);
    row.add(direction);
    row.add(intradayDirection);
    row.add(tradeValueMultiplier);
    row.add(createdAt);
    row.add(updatedAt);
    row.add(strategyCode);
    //row.add(optionId);
    //row.add(option);
    row.add(optionInstrument!.id);
    row.add(optionInstrument!.url);
    //row.add(optionInstrument!.chainId);
    //row.add(optionInstrument!.chainSymbol);
    row.add(optionInstrument!.createdAt);
    row.add(optionInstrument!.expirationDate);
    row.add(optionInstrument!.issueDate);
    row.add(optionInstrument!.minTicks.aboveTick);
    row.add(optionInstrument!.minTicks.belowTick);
    row.add(optionInstrument!.minTicks.cutoffPrice);
    row.add(optionInstrument!.rhsTradability);
    row.add(optionInstrument!.selloutDateTime);
    row.add(optionInstrument!.state);
    row.add(optionInstrument!.strikePrice);
    row.add(optionInstrument!.tradability);
    row.add(optionInstrument!.type);
    row.add(optionInstrument!.updatedAt);
    //row.add(optionInstrument!.optionMarketData!.instrument);
    //row.add(optionInstrument!.optionMarketData!.instrumentId);
    row.add(optionInstrument!.optionMarketData!.adjustedMarkPrice);
    row.add(optionInstrument!.optionMarketData!.askPrice);
    row.add(optionInstrument!.optionMarketData!.askSize);
    row.add(optionInstrument!.optionMarketData!.bidPrice);
    row.add(optionInstrument!.optionMarketData!.bidSize);
    row.add(optionInstrument!.optionMarketData!.breakEvenPrice);
    row.add(optionInstrument!.optionMarketData!.chanceOfProfitLong);
    row.add(optionInstrument!.optionMarketData!.chanceOfProfitShort);
    row.add(optionInstrument!.optionMarketData!.delta);
    row.add(optionInstrument!.optionMarketData!.gamma);
    row.add(optionInstrument!.optionMarketData!.highFillRateBuyPrice);
    row.add(optionInstrument!.optionMarketData!.highFillRateSellPrice);
    row.add(optionInstrument!.optionMarketData!.highPrice);
    row.add(optionInstrument!.optionMarketData!.impliedVolatility);
    row.add(optionInstrument!.optionMarketData!.lastTradePrice);
    row.add(optionInstrument!.optionMarketData!.lastTradeSize);
    row.add(optionInstrument!.optionMarketData!.lowFillRateBuyPrice);
    row.add(optionInstrument!.optionMarketData!.lowFillRateSellPrice);
    row.add(optionInstrument!.optionMarketData!.lowPrice);
    row.add(optionInstrument!.optionMarketData!.markPrice);
    row.add(optionInstrument!.optionMarketData!.occSymbol);
    row.add(optionInstrument!.optionMarketData!.openInterest);
    row.add(optionInstrument!.optionMarketData!.previousCloseDate);
    row.add(optionInstrument!.optionMarketData!.previousClosePrice);
    row.add(optionInstrument!.optionMarketData!.rho);
    row.add(optionInstrument!.optionMarketData!.symbol);
    row.add(optionInstrument!.optionMarketData!.theta);
    row.add(optionInstrument!.optionMarketData!.volume);
    //row.add(jsonEncode(this));
    return row;
  }

  static Future<File> generateCsv(
      List<OptionAggregatePosition> optionPositions) async {
    List<List<dynamic>> rows = [];
    List<dynamic> row = [];
    row.add("id");
    row.add("chain");
    row.add("account");
    row.add("symbol");
    row.add("strategy");
    row.add("averageOpenPrice");
    row.add("legs");
    row.add("quantity");
    row.add("intradayAverageOpenPrice");
    row.add("intradayQuantity");
    row.add("direction");
    row.add("intradayDirection");
    row.add("tradeValueMultiplier");
    row.add("createdAt");
    row.add("updatedAt");
    row.add("strategyCode");
    //row.add("optionId");
    //row.add("option");
    row.add("id (Instrument)");
    row.add("url (Instrument)");
    //row.add("chainId (Instrument)");
    //row.add("chainSymbol  (Instrument)");
    row.add("createdAt (Instrument)");
    row.add("expirationDate (Instrument)");
    row.add("issueDate (Instrument)");
    row.add("minTicks.aboveTick (Instrument)");
    row.add("minTicks.belowTick (Instrument)");
    row.add("minTicks.cutoffPrice (Instrument)");
    row.add("rhsTradability (Instrument)");
    row.add("selloutDateTime (Instrument)");
    row.add("state (Instrument)");
    row.add("strikePrice (Instrument)");
    row.add("tradability (Instrument)");
    row.add("type (Instrument)");
    row.add("updatedAt (Instrument)");
    //row.add("instrument (MarketData)");
    //row.add("instrumentId (MarketData)");
    row.add("adjustedMarkPrice (MarketData)");
    row.add("askPrice (MarketData)");
    row.add("askSize (MarketData)");
    row.add("bidPrice (MarketData)");
    row.add("bidSize (MarketData)");
    row.add("breakEvenPrice (MarketData)");
    row.add("chanceOfProfitLong (MarketData)");
    row.add("chanceOfProfitShort (MarketData)");
    row.add("delta (MarketData)");
    row.add("gamma (MarketData)");
    row.add("highFillRateBuyPrice (MarketData)");
    row.add("highFillRateSellPrice (MarketData)");
    row.add("highPrice (MarketData)");
    row.add("impliedVolatility (MarketData)");
    row.add("lastTradePrice (MarketData)");
    row.add("lastTradeSize (MarketData)");
    row.add("lowFillRateBuyPrice (MarketData)");
    row.add("lowFillRateSellPrice (MarketData)");
    row.add("lowPrice (MarketData)");
    row.add("markPrice (MarketData)");
    row.add("occSymbol (MarketData)");
    row.add("openInterest (MarketData)");
    row.add("previousCloseDate (MarketData)");
    row.add("previousClosePrice (MarketData)");
    row.add("rho (MarketData)");
    row.add("symbol (MarketData)");
    row.add("theta (MarketData)");
    row.add("volume (MarketData)");

    //row.add("jsonEncode");
    rows.add(row);
    for (int i = 0; i < optionPositions.length; i++) {
      rows.add(optionPositions[i].convertToDynamic());
    }

    String csv = const ListToCsvConverter().convert(rows);

    // storage permission ask
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
    }

    //final dir = await getApplicationDocumentsDirectory();
    //final dir = await getDownloadsDirectory();
    //final dir = await getExternalStorageDirectory();
    // _${snapshotUser.userName}

    /*
    final dir =
        await getExternalStorageDirectories(type: StorageDirectory.downloads);
    final file = File('${dir![0].path}/RobinhoodOptions.csv');
    await file.writeAsString(csv);
    return file;
    */
    final file2 = File('/storage/emulated/0/Download/RobinhoodOptions.csv');
    await file2.writeAsString(csv);
    return file2;
  }
}
