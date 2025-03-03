// import 'package:robinhood_options_mobile/model/brokerage_user.dart';

class Account {
  // final String userId;
  final String url;
  final double? portfolioCash;
  final String accountNumber;
  final String type;
  final double? buyingPower;
  final String optionLevel;
  final double? cashHeldForOptionsCollateral;

  Account(
      // this.userId,
      this.url,
      this.portfolioCash,
      this.accountNumber,
      this.type,
      this.buyingPower,
      this.optionLevel,
      this.cashHeldForOptionsCollateral);

  Account.fromJson(dynamic json) //, BrokerageUser user
      : // userId = user.id,
        url = json['url'],
        portfolioCash = json['portfolio_cash'] is double
            ? json['portfolio_cash']
            : double.tryParse(json['portfolio_cash']),
        accountNumber = json['account_number'],
        type = json['type'],
        buyingPower = json['buying_power'] is double
            ? json['buying_power']
            : double.tryParse(json['buying_power']),
        optionLevel = json['option_level'],
        cashHeldForOptionsCollateral =
            json['cash_held_for_options_collateral'] is double
                ? json['cash_held_for_options_collateral']
                : double.tryParse(json['cash_held_for_options_collateral']);

  Account.fromSchwabJson(dynamic json) //, BrokerageUser user
      : // userId = user.id,
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

  Account.fromPlaidJson(dynamic json) //, BrokerageUser user
      : // userId = user.id,
        url = '',
        portfolioCash = json['accounts'][0]['balances']['current'] as double,
        accountNumber = json['accounts'][0]['mask'],
        type = json['accounts'][0]['type'],
        buyingPower = json['accounts'][0]['balances']['current'] as double,
        optionLevel =
            '', // TODO: From getUser() /userprincipals/. Use .authorizations.optionTradingLevel
        cashHeldForOptionsCollateral = 0.0; // TODO

  Map<String, Object?> toJson() {
    return {
      // 'userId': userId,
      'url': url,
      'portfolio_cash': portfolioCash,
      'account_number': accountNumber,
      'type': type,
      'buying_power': buyingPower,
      'option_level': optionLevel,
      'cash_held_for_options_collateral': cashHeldForOptionsCollateral
    };
  }

  static List<Account> fromJsonArray(dynamic json) {
    List<Account> list = [];
    for (int i = 0; i < json.length; i++) {
      list.add(Account.fromJson(json[i]));
    }
    return list;
  }
}
