import 'package:robinhood_options_mobile/utils/json.dart';

class Account {
  // final String userId;
  final String url;
  final double? portfolioCash;
  final String accountNumber;
  final String type;
  final double? buyingPower;
  final String optionLevel;
  final double? cashHeldForOptionsCollateral;
  final double? unsettledDebit;
  final double? settledAmountBorrowed;

  Account(
      // this.userId,
      this.url,
      this.portfolioCash,
      this.accountNumber,
      this.type,
      this.buyingPower,
      this.optionLevel,
      this.cashHeldForOptionsCollateral,
      this.unsettledDebit,
      this.settledAmountBorrowed);

  Account.fromJson(dynamic json) //, BrokerageUser user
      : // userId = user.id,
        url = json['url'],
        portfolioCash = parseDouble(json['portfolio_cash']),
        accountNumber = json['account_number'],
        type = json['type'],
        buyingPower = parseDouble(json['buying_power']),
        optionLevel = json['option_level'],
        cashHeldForOptionsCollateral =
            parseDouble(json['cash_held_for_options_collateral']),
        unsettledDebit = parseDouble(json['unsettled_debit']),
        settledAmountBorrowed = json['margin_balances'] != null
            ? parseDouble(json['margin_balances']['settled_amount_borrowed'])
            : parseDouble(json['settled_amount_borrowed']);

  Account.fromSchwabJson(dynamic json) //, BrokerageUser user
      : // userId = user.id,
        url = '',
        portfolioCash = json['securitiesAccount']['currentBalances'] != null
            ? parseDouble(
                json['securitiesAccount']['currentBalances']['cashBalance'])
            : null,
        accountNumber = json['securitiesAccount']['accountNumber'],
        type = json['securitiesAccount']['type'] ?? '',
        buyingPower = json['securitiesAccount']['currentBalances'] != null
            ? parseDouble(
                json['securitiesAccount']['currentBalances']['buyingPower'])
            : null,
        optionLevel =
            '', // TODO: From getUser() /userprincipals/. Use .authorizations.optionTradingLevel
        cashHeldForOptionsCollateral = 0.0,
        unsettledDebit = 0.0,
        settledAmountBorrowed = 0.0; // TODO

  Account.fromPlaidJson(dynamic json) //, BrokerageUser user
      : // userId = user.id,
        url = '',
        portfolioCash = parseDouble(json['accounts'][0]['balances']['current']),
        accountNumber = json['accounts'][0]['mask'],
        type = json['accounts'][0]['type'],
        buyingPower = parseDouble(json['accounts'][0]['balances']['current']),
        optionLevel =
            '', // TODO: From getUser() /userprincipals/. Use .authorizations.optionTradingLevel
        cashHeldForOptionsCollateral = 0.0,
        unsettledDebit = 0.0,
        settledAmountBorrowed = 0.0; // TODO

  Map<String, Object?> toJson() {
    return {
      // 'userId': userId,
      'url': url,
      'portfolio_cash': portfolioCash,
      'account_number': accountNumber,
      'type': type,
      'buying_power': buyingPower,
      'option_level': optionLevel,
      'cash_held_for_options_collateral': cashHeldForOptionsCollateral,
      'unsettled_debit': unsettledDebit,
      'settled_amount_borrowed': settledAmountBorrowed
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
