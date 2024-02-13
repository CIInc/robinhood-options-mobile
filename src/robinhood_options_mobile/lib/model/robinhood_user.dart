import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/forex_holding.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/user_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum OptionsView { grouped, list }

enum DisplayValue {
  marketValue,
  lastPrice,
  todayReturnPercent,
  todayReturn,
  totalReturnPercent,
  totalReturn
}

enum Source { robinhood, tdAmeritrade }

final formatCurrency = NumberFormat.simpleCurrency();
final formatPercentage = NumberFormat.decimalPercentPattern(decimalDigits: 2);

//@immutable
class RobinhoodUser {
  final String id = DateTime.now().microsecondsSinceEpoch.toString();
  final Source source;
  late String? userName;
  final String? credentials;
  oauth2.Client? oauth2Client;
  bool defaultUser = true;
  bool refreshEnabled = false;
  OptionsView optionsView = OptionsView.grouped;
  DisplayValue? displayValue = DisplayValue.marketValue;
  bool showPositionDetails = true;
  // UserInfo? userInfo;

  RobinhoodUser(
      this.source, this.userName, this.credentials, this.oauth2Client);

  RobinhoodUser.fromJson(Map<String, dynamic> json)
      : source = json['source'] == 'Source.robinhood'
            ? Source.robinhood
            : Source.tdAmeritrade,
        userName = json['userName'],
        credentials = json['credentials'],
        refreshEnabled = json['refreshEnabled'] ?? false,
        optionsView =
            json['optionsView'] == null || json['optionsView'] == 'View.list'
                ? OptionsView.list
                : OptionsView.grouped,
        displayValue = parseDisplayValue(json['displayValue']),
        showPositionDetails = json['showPositionDetails'] ?? true;

  Map<String, dynamic> toJson() => {
        'source': source.toString(),
        'userName': userName,
        'credentials': credentials,
        'refreshEnabled': refreshEnabled,
        'optionsView': optionsView.toString(),
        'displayValue': displayValue.toString(),
        'showPositionDetails': showPositionDetails,
      };

  Future save(UserStore store) async {
    store.addOrUpdate(this);
    var contents = jsonEncode(store.items); //this
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(Constants.preferencesUserKey, contents);
    //await Store.writeFile(Constants.cacheFilename, contents);
  }

  static Future<List<RobinhoodUser>> loadUserIntoStore(UserStore store) async {
    // await Store.deleteFile(Constants.cacheFilename);
    debugPrint('Loading cache.');

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? contents = prefs.getString(Constants.preferencesUserKey);
    //String? contents = await Store.readFile(Constants.cacheFilename);
    if (contents == null) {
      debugPrint('No cache file found.');
      return [];
    }
    try {
      store.removeAll();
      var users = jsonDecode(contents) as List<dynamic>;
      for (Map<String, dynamic> userMap in users) {
        var user = RobinhoodUser.fromJson(userMap);
        var credentials =
            oauth2.Credentials.fromJson(user.credentials as String);
        var client =
            oauth2.Client(credentials, identifier: Constants.rhClientId);
        user.oauth2Client = client;
        debugPrint('Loaded cache.');
        store.add(user);
      }
      return store.items;
    } on FormatException catch (e) {
      debugPrint(
          'Cache provided is not valid JSON.\nError: $e\nContents: $contents');
      return [];
    }
  }
  /* Deprecated for save()
  static Future writeUserToStore(RobinhoodUser user) async {
    var contents = jsonEncode(user);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(Constants.preferencesUserKey, contents);
    //await Store.writeFile(Constants.cacheFilename, contents);
  }
  */

  Future clearUserFromStore(UserStore store) async {
    debugPrint("Cleared user from store.");

    //await Store.deleteFile(Constants.cacheFilename);
    store.remove(this);

    var contents = jsonEncode(store.items); //this
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(Constants.preferencesUserKey, contents);
  }

  static String displayValueText(DisplayValue displayValue) {
    switch (displayValue) {
      case DisplayValue.lastPrice:
        return 'Last Price';
      case DisplayValue.marketValue:
        return 'Market Value';
      case DisplayValue.todayReturn:
        return 'Return Today';
      case DisplayValue.todayReturnPercent:
        return 'Return % Today';
      case DisplayValue.totalReturn:
        return 'Total Return';
      case DisplayValue.totalReturnPercent:
        return 'Total Return %';
      default:
        throw Exception('Not a valid display value.');
    }
  }

  static DisplayValue parseDisplayValue(String? optionsView) {
    if (optionsView == null) {
      return DisplayValue.marketValue;
    }
    switch (optionsView) {
      case 'DisplayValue.lastPrice':
        return DisplayValue.lastPrice;
      case 'DisplayValue.marketValue':
        return DisplayValue.marketValue;
      case 'DisplayValue.todayReturn':
        return DisplayValue.todayReturn;
      case 'DisplayValue.todayReturnPercent':
        return DisplayValue.todayReturnPercent;
      case 'DisplayValue.totalReturn':
        return DisplayValue.totalReturn;
      case 'DisplayValue.totalReturnPercent':
        return DisplayValue.totalReturnPercent;
      default:
        return DisplayValue.marketValue;
    }
  }

  double? getAggregateDisplayValue(List<OptionAggregatePosition> ops,
      {DisplayValue? displayValue}) {
    double value = 0;
    if (ops.isEmpty) {
      return value;
    }
    switch (displayValue ?? this.displayValue) {
      case DisplayValue.lastPrice:
        return null;
      /*
        value = ops
            .map((OptionAggregatePosition e) => e.marketData!.lastTradePrice!)
            .reduce((a, b) => a + b);
        break;
            */
      case DisplayValue.marketValue:
        value = ops
            .map((OptionAggregatePosition e) => e.marketValue)
            /*
                e.legs.first.positionType == "long"
                    ? e.marketValue
                    : e.marketValue)
                    */
            .reduce((a, b) => a + b);
        break;
      case DisplayValue.todayReturn:
        value = ops
            .map((OptionAggregatePosition e) => e.changeToday)
            .reduce((a, b) => a + b);
        break;
      case DisplayValue.todayReturnPercent:
        var numerator = ops
            .map((OptionAggregatePosition e) => e.changeToday)
            .reduce((a, b) => a + b);
        var denominator = ops
            .map((OptionAggregatePosition e) => e.marketValue - e.changeToday)
            .reduce((a, b) => a + b);
        /*
        var numerator = ops
            .map((OptionAggregatePosition e) =>
                e.changePercentToday * e.totalCost)
            .reduce((a, b) => a + b);
        var denominator = ops
            .map((OptionAggregatePosition e) => e.totalCost)
            .reduce((a, b) => a + b);
            */
        value = numerator / denominator;
        break;
      case DisplayValue.totalReturn:
        value = ops
            .map((OptionAggregatePosition e) => e.gainLoss)
            .reduce((a, b) => a + b);
        break;
      case DisplayValue.totalReturnPercent:
        var numerator = ops
            .map((OptionAggregatePosition e) => e.gainLoss)
            .reduce((a, b) => a + b);
        var denominator = ops
            .map((OptionAggregatePosition e) => e.totalCost)
            .reduce((a, b) => a + b);
        /*
        var numerator = ops
            .map((OptionAggregatePosition e) => e.gainLossPercent * e.totalCost)
            .reduce((a, b) => a + b);
        var denominator = ops
            .map((OptionAggregatePosition e) => e.totalCost)
            .reduce((a, b) => a + b);
            */
        value = numerator / denominator;
        /*
        value = ops
            .map((OptionAggregatePosition e) => e.gainLossPercent)
            .reduce((a, b) => a + b);
            */
        break;
      default:
    }
    return value;
  }

  double? getPositionAggregateDisplayValue(List<InstrumentPosition> ops,
      {DisplayValue? displayValue}) {
    double value = 0;
    if (ops.isEmpty) {
      return value;
    }
    switch (displayValue ?? this.displayValue) {
      case DisplayValue.lastPrice:
        return null;
      /*
        value = ops
            .map((Position e) =>
                e.instrumentObj!.quoteObj!.lastExtendedHoursTradePrice ??
                e.instrumentObj!.quoteObj!.lastTradePrice!)
            .reduce((a, b) => a + b);
        break;
        */
      case DisplayValue.marketValue:
        value =
            ops.map((InstrumentPosition e) => e.marketValue).reduce((a, b) => a + b);
        break;
      case DisplayValue.todayReturn:
        value = ops
            .map((InstrumentPosition e) => e.gainLossToday)
            .reduce((a, b) => a + b);
        break;
      case DisplayValue.todayReturnPercent:
        var numerator = ops
            .map((InstrumentPosition e) => e.gainLossPercentToday * e.totalCost)
            .reduce((a, b) => a + b);
        var denominator =
            ops.map((InstrumentPosition e) => e.totalCost).reduce((a, b) => a + b);
        value = numerator / denominator;
        /*
        value = ops
            .map((OptionAggregatePosition e) =>
                e.changePercentToday * e.marketValue)
            .reduce((a, b) => a + b);
            */
        break;
      case DisplayValue.totalReturn:
        value =
            ops.map((InstrumentPosition e) => e.gainLoss).reduce((a, b) => a + b);
        break;
      case DisplayValue.totalReturnPercent:
        var numerator = ops
            .map((InstrumentPosition e) => e.gainLossPercent * e.totalCost)
            .reduce((a, b) => a + b);
        var denominator =
            ops.map((InstrumentPosition e) => e.totalCost).reduce((a, b) => a + b);
        value = numerator / denominator;
        /*
        value = ops
            .map((OptionAggregatePosition e) => e.gainLossPercent)
            .reduce((a, b) => a + b);
            */
        break;
      default:
    }
    return value;
  }

  double? getCryptoAggregateDisplayValue(List<ForexHolding> ops,
      {DisplayValue? displayValue}) {
    double value = 0;
    if (ops.isEmpty) {
      return value;
    }
    switch (displayValue ?? this.displayValue) {
      case DisplayValue.lastPrice:
        return null;
      /*
        value = ops
            .map((Position e) =>
                e.instrumentObj!.quoteObj!.lastExtendedHoursTradePrice ??
                e.instrumentObj!.quoteObj!.lastTradePrice!)
            .reduce((a, b) => a + b);
        break;
        */
      case DisplayValue.marketValue:
        value =
            ops.map((ForexHolding e) => e.marketValue).reduce((a, b) => a + b);
        break;
      case DisplayValue.todayReturn:
        value = ops
            .map((ForexHolding e) => e.gainLossToday)
            .reduce((a, b) => a + b);
        break;
      case DisplayValue.todayReturnPercent:
        var numerator = ops
            .map((ForexHolding e) => e.gainLossPercentToday * e.totalCost)
            .reduce((a, b) => a + b);
        var denominator =
            ops.map((ForexHolding e) => e.totalCost).reduce((a, b) => a + b);
        value = numerator / denominator;
        /*
        value = ops
            .map((OptionAggregatePosition e) =>
                e.changePercentToday * e.marketValue)
            .reduce((a, b) => a + b);
            */
        break;
      case DisplayValue.totalReturn:
        value = ops.map((ForexHolding e) => e.gainLoss).reduce((a, b) => a + b);
        break;
      case DisplayValue.totalReturnPercent:
        var numerator = ops
            .map((ForexHolding e) => e.gainLossPercent * e.totalCost)
            .reduce((a, b) => a + b);
        var denominator =
            ops.map((ForexHolding e) => e.totalCost).reduce((a, b) => a + b);
        value = numerator / denominator;
        /*
        value = ops
            .map((OptionAggregatePosition e) => e.gainLossPercent)
            .reduce((a, b) => a + b);
            */
        break;
      default:
    }
    return value;
  }

  double getPositionDisplayValue(InstrumentPosition op, {DisplayValue? displayValue}) {
    double value = 0;
    switch (displayValue ?? this.displayValue) {
      case DisplayValue.lastPrice:
        value = op.instrumentObj != null && op.instrumentObj!.quoteObj != null
            ? op.instrumentObj!.quoteObj!.lastExtendedHoursTradePrice ??
                op.instrumentObj!.quoteObj!.lastTradePrice!
            : 0;
        break;
      case DisplayValue.marketValue:
        value = op.marketValue;
        break;
      case DisplayValue.todayReturn:
        value = op.gainLossToday;
        break;
      case DisplayValue.todayReturnPercent:
        value = op.gainLossPercentToday;
        break;
      case DisplayValue.totalReturn:
        value = op.gainLoss;
        break;
      case DisplayValue.totalReturnPercent:
        value = op.gainLossPercent;
        break;
      default:
    }
    return value;
  }

  double getCryptoDisplayValue(ForexHolding op, {DisplayValue? displayValue}) {
    double value = 0;
    switch (displayValue ?? this.displayValue) {
      case DisplayValue.lastPrice:
        value = op.quoteObj!.markPrice!;
        break;
      case DisplayValue.marketValue:
        value = op.marketValue;
        break;
      case DisplayValue.todayReturn:
        value = op.gainLossToday;
        break;
      case DisplayValue.todayReturnPercent:
        value = op.gainLossPercentToday;
        break;
      case DisplayValue.totalReturn:
        value = op.gainLoss;
        break;
      case DisplayValue.totalReturnPercent:
        value = op.gainLossPercent;
        break;
      default:
    }
    return value;
  }

  Icon getDisplayIcon(double value, {double? size}) {
    var icon = Icon(
      value > 0
          ? Icons.trending_up
          : (value < 0 ? Icons.trending_down : Icons.trending_flat),
      color:
          (value > 0 ? Colors.green : (value < 0 ? Colors.red : Colors.grey)),
      size: size,
    );
    return icon;
  }

  String getDisplayText(double value, {DisplayValue? displayValue}) {
    String opTrailingText = '';
    switch (displayValue ?? this.displayValue) {
      case DisplayValue.lastPrice:
      case DisplayValue.marketValue:
      case DisplayValue.todayReturn:
      case DisplayValue.totalReturn:
        opTrailingText = formatCurrency.format(value);
        break;
      case DisplayValue.todayReturnPercent:
      case DisplayValue.totalReturnPercent:
        opTrailingText = formatPercentage.format(value);
        break;
      default:
    }
    return opTrailingText;
  }

  double getDisplayValue(OptionAggregatePosition op,
      {DisplayValue? displayValue}) {
    double value = 0;
    switch (displayValue ?? this.displayValue) {
      case DisplayValue.lastPrice:
        value = op.optionInstrument != null &&
                op.optionInstrument!.optionMarketData != null
            ? op.optionInstrument!.optionMarketData!.markPrice!
            : 0;
        break;
      case DisplayValue.marketValue:
        value = op.marketValue;
        break;
      case DisplayValue.todayReturn:
        value = op.changeToday;
        break;
      case DisplayValue.todayReturnPercent:
        value = op.changePercentToday;
        break;
      case DisplayValue.totalReturn:
        value = op.gainLoss;
        break;
      case DisplayValue.totalReturnPercent:
        value = op.gainLossPercent;
        break;
      default:
    }
    return value;
  }
}
