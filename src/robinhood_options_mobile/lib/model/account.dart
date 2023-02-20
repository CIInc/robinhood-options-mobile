import 'package:robinhood_options_mobile/model/robinhood_user.dart';

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

  Account.fromJson(dynamic json, RobinhoodUser user)
      : userId = user.id,
        url = json['url'],
        portfolioCash = double.tryParse(json['portfolio_cash']),
        accountNumber = json['account_number'],
        type = json['type'],
        buyingPower = double.tryParse(json['buying_power']),
        optionLevel = json['option_level'],
        cashHeldForOptionsCollateral =
            double.tryParse(json['cash_held_for_options_collateral']);

  Account.fromTdAmeritradeJson(dynamic json, RobinhoodUser user)
      : userId = user.id,
        url = '',
        portfolioCash = double.tryParse(json['securitiesAccount']
                ['currentBalances']['cashBalance']
            .toString()),
        accountNumber = json['securitiesAccount']['accountId'],
        type = json['securitiesAccount']['type'],
        buyingPower = double.tryParse(json['securitiesAccount']
                ['currentBalances']['buyingPower']
            .toString()),
        optionLevel =
            '', // TODO: From getUser() /userprincipals/. Use .authorizations.optionTradingLevel
        cashHeldForOptionsCollateral = 0.0; // TODO
}
