import 'package:flutter/material.dart';
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:oauth2/oauth2.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/forex_holding.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/user_info.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/services/plaid_service.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
import 'package:robinhood_options_mobile/services/schwab_service.dart';

//@immutable
class BrokerageUser {
  // final String id = DateTime.now().microsecondsSinceEpoch.toString();
  final BrokerageSource source;
  late String? userName;
  String? credentials;
  oauth2.Client? oauth2Client;
  // bool defaultUser = true;
  bool refreshEnabled = false;
  OptionsView optionsView = OptionsView.grouped;
  DisplayValue? displayValue = DisplayValue.marketValue;
  DisplayValue? sortOptions = DisplayValue.marketValue;
  SortDirection? sortDirection = SortDirection.desc;
  bool showPositionDetails = true;
  UserInfo? userInfo;
  bool persistToFirebase = true;

  BrokerageUser(
      this.source, this.userName, this.credentials, this.oauth2Client);

  BrokerageUser.fromJson(Map<String, dynamic> json)
      : source = json['source'] == BrokerageSource.robinhood.toString()
            ? BrokerageSource.robinhood
            : json['source'] == BrokerageSource.schwab.toString()
                ? BrokerageSource.schwab
                : json['source'] == BrokerageSource.plaid.toString()
                    ? BrokerageSource.plaid
                    : BrokerageSource.demo,
        userName = json['userName'],
        credentials = json['credentials'],
        refreshEnabled = json['refreshEnabled'] ?? false,
        optionsView =
            json['optionsView'] == null || json['optionsView'] == 'View.list'
                ? OptionsView.list
                : OptionsView.grouped,
        displayValue = parseDisplayValue(json['displayValue']),
        sortOptions = parseDisplayValue(json['sortOptions']),
        sortDirection = json['sortDirection'] != null
            ? json['sortDirection'] == 'asc'
                ? SortDirection.asc
                : SortDirection.desc
            : null,
        showPositionDetails = json['showPositionDetails'] ?? true,
        userInfo = json['userInfo'] != null
            ? UserInfo.fromJson(json['userInfo'])
            : null,
        persistToFirebase = json['persistToFirebase'] ?? true;

  Map<String, dynamic> toJson() => {
        'source': source.toString(),
        'userName': userName,
        'credentials': credentials,
        'refreshEnabled': refreshEnabled,
        'optionsView': optionsView.toString(),
        'sortOptions': sortOptions.toString(),
        'sortDirection': sortDirection.toString(),
        'displayValue': displayValue.toString(),
        'showPositionDetails': showPositionDetails,
        'userInfo': userInfo?.toJson(),
        'persistToFirebase': persistToFirebase
      };

  static List<BrokerageUser> fromJsonArray(dynamic json) {
    List<BrokerageUser> list = [];
    if (json == null) {
      return list;
    }
    for (int i = 0; i < json.length; i++) {
      var user = BrokerageUser.fromJson(json[i]);
      if (user.credentials != null) {
        var credentials = Credentials.fromJson(user.credentials as String);
        var service = user.source == BrokerageSource.robinhood
            ? RobinhoodService()
            : user.source == BrokerageSource.schwab
                ? SchwabService()
                : user.source == BrokerageSource.plaid
                    ? PlaidService()
                    : DemoService();

        var client = Client(credentials, identifier: service.clientId);
        user.oauth2Client = client;
      }
      list.add(user);
    }
    return list;
  }

  static String displayValueText(DisplayValue displayValue) {
    switch (displayValue) {
      case DisplayValue.lastPrice:
        return 'Last Price';
      case DisplayValue.marketValue:
        return 'Market Value';
      case DisplayValue.totalCost:
        return 'Total Cost';
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
      case 'DisplayValue.totalCost':
        return DisplayValue.totalCost;
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

  double? getDisplayValueOptionAggregatePosition(
      List<OptionAggregatePosition> ops,
      {DisplayValue? displayValue}) {
    double value = 0;
    if (ops.isEmpty) {
      return value;
    }
    switch (displayValue ?? this.displayValue) {
      case DisplayValue.lastPrice:
        value = ops
            .map((OptionAggregatePosition e) => e.optionInstrument != null &&
                    e.optionInstrument!.optionMarketData != null
                ? e.optionInstrument!.optionMarketData!.adjustedMarkPrice!
                : 0.0)
            .reduce((a, b) => a + b);
        break;
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
      case DisplayValue.totalCost:
        value = ops
            .map((OptionAggregatePosition e) => e.totalCost)
            .reduce((a, b) => a + b);
        break;
      case DisplayValue.todayReturn:
        value = ops
            .map((OptionAggregatePosition e) => e.changeToday)
            .reduce((a, b) => a + b);
        break;
      case DisplayValue.todayReturnPercent:
        var numerator = ops
            .map((OptionAggregatePosition e) => e.marketValue)
            .reduce((a, b) => a + b);
        var denominator = ops
            .map((OptionAggregatePosition e) => e.marketValue - e.changeToday)
            .reduce((a, b) => a + b);
        value = numerator / denominator - 1;
        break;
      case DisplayValue.totalReturn:
        value = ops
            .map((OptionAggregatePosition e) => e.gainLoss)
            .reduce((a, b) => a + b);
        break;
      case DisplayValue.totalReturnPercent:
        var numerator = ops
            .map((OptionAggregatePosition e) => e.marketValue)
            .reduce((a, b) => a + b);
        var denominator = ops
            .map((OptionAggregatePosition e) => e.totalCost)
            .reduce((a, b) => a + b);
        value = numerator / denominator - 1;
        break;
      default:
    }
    return value;
  }

  double? getDisplayValueInstrumentPositions(List<InstrumentPosition> ops,
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
        value = ops
            .map((InstrumentPosition e) => e.marketValue)
            .reduce((a, b) => a + b);
        break;
      case DisplayValue.totalCost:
        value = ops
            .map((InstrumentPosition e) => e.totalCost)
            .reduce((a, b) => a + b);
        break;
      case DisplayValue.todayReturn:
        value = ops
            .map((InstrumentPosition e) => e.gainLossToday)
            .reduce((a, b) => a + b);
        break;
      case DisplayValue.todayReturnPercent:
        var numerator = ops
            .map((InstrumentPosition e) => e.marketValue)
            .reduce((a, b) => a + b);
        var denominator = ops
            .map((InstrumentPosition e) => e.marketValue - e.gainLossToday)
            .reduce((a, b) => a + b);
        value = numerator / denominator - 1;
        break;
      case DisplayValue.totalReturn:
        value = ops
            .map((InstrumentPosition e) => e.gainLoss)
            .reduce((a, b) => a + b);
        break;
      case DisplayValue.totalReturnPercent:
        var numerator = ops
            .map((InstrumentPosition e) => e.marketValue)
            .reduce((a, b) => a + b);
        var denominator = ops
            .map((InstrumentPosition e) => e.totalCost)
            .reduce((a, b) => a + b);
        value = numerator / denominator - 1;
        break;
      default:
    }
    return value;
  }

  double? getDisplayValueForexHoldings(List<ForexHolding> ops,
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
      case DisplayValue.totalCost:
        value =
            ops.map((ForexHolding e) => e.totalCost).reduce((a, b) => a + b);
        break;
      case DisplayValue.todayReturn:
        value = ops
            .map((ForexHolding e) => e.gainLossToday)
            .reduce((a, b) => a + b);
        break;
      case DisplayValue.todayReturnPercent:
        var numerator =
            ops.map((ForexHolding e) => e.marketValue).reduce((a, b) => a + b);
        var denominator = ops
            .map((ForexHolding e) => e.marketValue - e.gainLossToday)
            .reduce((a, b) => a + b);
        value = numerator / denominator - 1;
        break;
      case DisplayValue.totalReturn:
        value = ops.map((ForexHolding e) => e.gainLoss).reduce((a, b) => a + b);
        break;
      case DisplayValue.totalReturnPercent:
        var numerator =
            ops.map((ForexHolding e) => e.marketValue).reduce((a, b) => a + b);
        var denominator =
            ops.map((ForexHolding e) => e.totalCost).reduce((a, b) => a + b);
        value = numerator / denominator - 1;
        break;
      default:
    }
    return value;
  }

  double getDisplayValueInstrumentPosition(InstrumentPosition op,
      {DisplayValue? displayValue}) {
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
      case DisplayValue.totalCost:
        value = op.totalCost;
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

  double getDisplayValueForexHolding(ForexHolding op,
      {DisplayValue? displayValue}) {
    double value = 0;
    switch (displayValue ?? this.displayValue) {
      case DisplayValue.lastPrice:
        value = op.quoteObj!.markPrice!;
        break;
      case DisplayValue.marketValue:
        value = op.marketValue;
        break;
      case DisplayValue.totalCost:
        value = op.totalCost;
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
    return value.isInfinite ? 0 : value;
  }

  Icon getDisplayIcon(double value, {double? size = 26.0}) {
    var icon = Icon(
      value > 0
          ? Icons.arrow_drop_up // Icons.trending_up
          : (value < 0
              ? Icons.arrow_drop_down
              : Icons.trending_flat), // Icons.trending_down
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
      case DisplayValue.totalCost:
      case DisplayValue.todayReturn:
      case DisplayValue.totalReturn:
        opTrailingText = value.abs() != 0.0 && value.abs() < 0.00005
            ? formatPrecise8Currency.format(value)
            : (value.abs() != 0.0 && value.abs() < 0.005
                ? formatPrecise4Currency.format(value)
                : formatCurrency.format(value));
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
            ? op.optionInstrument!.optionMarketData!.adjustedMarkPrice!
            : 0;
        break;
      case DisplayValue.marketValue:
        value = op.marketValue;
        break;
      case DisplayValue.totalCost:
        value = op.totalCost;
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
