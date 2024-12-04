import 'package:robinhood_options_mobile/model/brokerage_user.dart';

class Account {
  final String userId;
  final String url;
  final double? portfolioCash;
  final String accountNumber;
  final String type;
  final double? buyingPower;
  final String optionLevel;
  final double? cashHeldForOptionsCollateral;

  Account(
      this.userId,
      this.url,
      this.portfolioCash,
      this.accountNumber,
      this.type,
      this.buyingPower,
      this.optionLevel,
      this.cashHeldForOptionsCollateral);

  Account.fromJson(dynamic json, BrokerageUser user)
      : userId = user.id,
        url = json['url'],
        portfolioCash = double.tryParse(json['portfolio_cash']),
        accountNumber = json['account_number'],
        type = json['type'],
        buyingPower = double.tryParse(json['buying_power']),
        optionLevel = json['option_level'],
        cashHeldForOptionsCollateral =
            double.tryParse(json['cash_held_for_options_collateral']);

  Account.fromSchwabJson(dynamic json, BrokerageUser user)
      : userId = user.id,
        url = '',
        portfolioCash = double.tryParse(json['securitiesAccount']
                ['currentBalances']['cashBalance']
            .toString()),
        accountNumber = json['securitiesAccount']['accountNumber'],
        type = json['securitiesAccount']['type'],
        buyingPower = double.tryParse(json['securitiesAccount']
                ['currentBalances']['buyingPower']
            .toString()),
        optionLevel =
            '', // TODO: From getUser() /userprincipals/. Use .authorizations.optionTradingLevel
        cashHeldForOptionsCollateral = 0.0; // TODO

  Account.fromPlaidJson(dynamic json, BrokerageUser user)
      : userId = user.id,
        url = '',
        portfolioCash = json['accounts'][0]['balances']['current'] as double,
        accountNumber = json['accounts'][0]['mask'],
        type = json['accounts'][0]['type'],
        buyingPower = json['accounts'][0]['balances']['current'] as double,
        optionLevel =
            '', // TODO: From getUser() /userprincipals/. Use .authorizations.optionTradingLevel
        cashHeldForOptionsCollateral = 0.0; // TODO
}
