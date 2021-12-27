import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/forex_holding.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/position.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum View { grouped, list }
enum DisplayValue {
  marketValue,
  lastPrice,
  todayReturnPercent,
  todayReturn,
  totalReturnPercent,
  totalReturn
}
final formatCurrency = NumberFormat.simpleCurrency();
final formatPercentage = NumberFormat.decimalPercentPattern(decimalDigits: 2);

//@immutable
class RobinhoodUser {
  final String? userName;
  final String? credentials;
  oauth2.Client? oauth2Client;
  bool refreshEnabled = true;
  View optionsView = View.list;
  DisplayValue? displayValue = DisplayValue.marketValue;
  bool showGreeks = false;

  RobinhoodUser(this.userName, this.credentials, this.oauth2Client);

  RobinhoodUser.fromJson(Map<String, dynamic> json)
      : userName = json['userName'],
        credentials = json['credentials'],
        refreshEnabled = json['refreshEnabled'] ?? true,
        optionsView =
            json['optionsView'] == null || json['optionsView'] == 'View.list'
                ? View.list
                : View.grouped,
        displayValue = parseDisplayValue(json['displayValue']),
        showGreeks = json['showGreeks'] ?? true;

  Map<String, dynamic> toJson() => {
        'userName': userName,
        'credentials': credentials,
        'refreshEnabled': refreshEnabled,
        'optionsView': optionsView.toString(),
        'displayValue': displayValue.toString(),
        'showGreeks': showGreeks,
      };

  Future save() async {
    var contents = jsonEncode(this);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(Constants.preferencesUserKey, contents);
    //await Store.writeFile(Constants.cacheFilename, contents);
  }

  static Future<RobinhoodUser> loadUserFromStore() async {
    // await Store.deleteFile(Constants.cacheFilename);
    debugPrint('Loading cache.');

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? contents = prefs.getString(Constants.preferencesUserKey);
    //String? contents = await Store.readFile(Constants.cacheFilename);
    if (contents == null) {
      debugPrint('No cache file found.');
      return RobinhoodUser(null, null, null);
    }
    try {
      var userMap = jsonDecode(contents) as Map<String, dynamic>;
      var user = RobinhoodUser.fromJson(userMap);
      var credentials = oauth2.Credentials.fromJson(user.credentials as String);
      var client = oauth2.Client(credentials, identifier: Constants.identifier);
      user.oauth2Client = client;
      debugPrint('Loaded cache.');
      return user;
    } on FormatException catch (e) {
      debugPrint(
          'Cache provided is not valid JSON.\nError: $e\nContents: $contents');
      return RobinhoodUser(null, null, null);
    }
  }

  static Future writeUserToStore(RobinhoodUser user) async {
    var contents = jsonEncode(user);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(Constants.preferencesUserKey, contents);
    //await Store.writeFile(Constants.cacheFilename, contents);
  }

  static Future clearUserFromStore() async {
    debugPrint("Cleared user from store.");
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(Constants.preferencesUserKey);
    //await Store.deleteFile(Constants.cacheFilename);
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

  double? getAggregateDisplayValue(List<OptionAggregatePosition> ops) {
    double value = 0;
    switch (displayValue) {
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
            .map((OptionAggregatePosition e) =>
                e.legs.first.positionType == "long"
                    ? e.marketValue
                    : e.marketValue)
            .reduce((a, b) => a + b);
        break;
      case DisplayValue.todayReturn:
        value = ops
            .map((OptionAggregatePosition e) => e.changeToday)
            .reduce((a, b) => a + b);
        break;
      case DisplayValue.todayReturnPercent:
        var numerator = ops
            .map((OptionAggregatePosition e) =>
                e.changePercentToday * e.totalCost)
            .reduce((a, b) => a + b);
        var denominator = ops
            .map((OptionAggregatePosition e) => e.totalCost)
            .reduce((a, b) => a + b);
        value = numerator / denominator;
        /*
        value = ops
            .map((OptionAggregatePosition e) =>
                e.changePercentToday * e.marketValue)
            .reduce((a, b) => a + b);
            */
        break;
      case DisplayValue.totalReturn:
        value = ops
            .map((OptionAggregatePosition e) => e.gainLoss)
            .reduce((a, b) => a + b);
        break;
      case DisplayValue.totalReturnPercent:
        var numerator = ops
            .map((OptionAggregatePosition e) => e.gainLossPercent * e.totalCost)
            .reduce((a, b) => a + b);
        var denominator = ops
            .map((OptionAggregatePosition e) => e.totalCost)
            .reduce((a, b) => a + b);
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

  double? getPositionAggregateDisplayValue(List<Position> ops) {
    double value = 0;
    switch (displayValue) {
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
        value = ops.map((Position e) => e.marketValue).reduce((a, b) => a + b);
        break;
      case DisplayValue.todayReturn:
        value =
            ops.map((Position e) => e.gainLossToday).reduce((a, b) => a + b);
        break;
      case DisplayValue.todayReturnPercent:
        var numerator = ops
            .map((Position e) => e.gainLossPercentToday * e.totalCost)
            .reduce((a, b) => a + b);
        var denominator =
            ops.map((Position e) => e.totalCost).reduce((a, b) => a + b);
        value = numerator / denominator;
        /*
        value = ops
            .map((OptionAggregatePosition e) =>
                e.changePercentToday * e.marketValue)
            .reduce((a, b) => a + b);
            */
        break;
      case DisplayValue.totalReturn:
        value = ops.map((Position e) => e.gainLoss).reduce((a, b) => a + b);
        break;
      case DisplayValue.totalReturnPercent:
        var numerator = ops
            .map((Position e) => e.gainLossPercent * e.totalCost)
            .reduce((a, b) => a + b);
        var denominator =
            ops.map((Position e) => e.totalCost).reduce((a, b) => a + b);
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

  double? getCryptoAggregateDisplayValue(List<ForexHolding> ops) {
    double value = 0;
    switch (displayValue) {
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

  double getPositionDisplayValue(Position op) {
    double value = 0;
    switch (displayValue) {
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

  double getCryptoDisplayValue(ForexHolding op) {
    double value = 0;
    switch (displayValue) {
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

  Icon? getDisplayIcon(double value) {
    if (displayValue == DisplayValue.lastPrice ||
        displayValue == DisplayValue.marketValue) {
      return null;
    }
    var icon = Icon(
        value > 0
            ? Icons.trending_up
            : (value < 0 ? Icons.trending_down : Icons.trending_flat),
        color: (value > 0
            ? Colors.green
            : (value < 0 ? Colors.red : Colors.grey)));
    return icon;
  }

  String getDisplayText(double value) {
    String opTrailingText = '';
    switch (displayValue) {
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

  double getDisplayValue(OptionAggregatePosition op) {
    double value = 0;
    switch (displayValue) {
      case DisplayValue.lastPrice:
        value = op.marketData != null ? op.marketData!.markPrice! : 0;
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
