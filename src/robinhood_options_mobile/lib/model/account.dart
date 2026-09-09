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
  final bool isAgentic;
  final bool dayTradesProtection;
  final double? dayTradeBuyingPower;
  final double? dayTradeRatio;
  final DateTime? markedPatternDayTraderDate;
  final DateTime? patternDayTraderExpiryDate;
  final bool isPdtForever;

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
      this.settledAmountBorrowed,
      {this.isAgentic = false,
      this.dayTradesProtection = true,
      this.dayTradeBuyingPower,
      this.dayTradeRatio,
      this.markedPatternDayTraderDate,
      this.patternDayTraderExpiryDate,
      this.isPdtForever = false});

  Account.fromJson(dynamic json) //, BrokerageUser user
      : // userId = user.id,
        url = json['url'] ?? '',
        portfolioCash = parseDouble(json['portfolio_cash']),
        accountNumber = json['account_number'] ?? '',
        type = json['type'] ?? '',
        buyingPower = parseDouble(json['buying_power']),
        optionLevel = json['option_level'] ?? '',
        cashHeldForOptionsCollateral =
            parseDouble(json['cash_held_for_options_collateral']),
        unsettledDebit = parseDouble(json['unsettled_debit']),
        settledAmountBorrowed = json['margin_balances'] != null
            ? parseDouble(json['margin_balances']['settled_amount_borrowed'])
            : parseDouble(json['settled_amount_borrowed']),
        isAgentic = json['is_agentic'] ??
            json['agentic_allowed'] ??
            (json['type'] == 'agentic') ??
            false,
        dayTradesProtection = json['margin_balances'] != null &&
                json['margin_balances']['day_trades_protection'] != null
            ? json['margin_balances']['day_trades_protection'] == true
            : (json['day_trades_protection'] ?? true),
        dayTradeBuyingPower = json['margin_balances'] != null
            ? parseDouble(json['margin_balances']['day_trade_buying_power'])
            : parseDouble(json['day_trade_buying_power']),
        dayTradeRatio = json['margin_balances'] != null
            ? parseDouble(json['margin_balances']['day_trade_ratio'])
            : parseDouble(json['day_trade_ratio']),
        markedPatternDayTraderDate = json['margin_balances'] != null &&
                json['margin_balances']['marked_pattern_day_trader_date'] !=
                    null
            ? DateTime.tryParse(json['margin_balances']
                    ['marked_pattern_day_trader_date']
                .toString())
            : (json['marked_pattern_day_trader_date'] != null
                ? DateTime.tryParse(
                    json['marked_pattern_day_trader_date'].toString())
                : null),
        patternDayTraderExpiryDate = json['margin_balances'] != null &&
                json['margin_balances']['pattern_day_trader_expiry_date'] !=
                    null
            ? DateTime.tryParse(json['margin_balances']
                    ['pattern_day_trader_expiry_date']
                .toString())
            : (json['pattern_day_trader_expiry_date'] != null
                ? DateTime.tryParse(
                    json['pattern_day_trader_expiry_date'].toString())
                : null),
        isPdtForever = json['margin_balances'] != null &&
                json['margin_balances']['is_pdt_forever'] != null
            ? json['margin_balances']['is_pdt_forever'] == true
            : (json['is_pdt_forever'] ?? false);

  Account.fromSchwabJson(dynamic json) //, BrokerageUser user
      : // userId = user.id,
        url = json['securitiesAccount']['accountNumber'],
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
        settledAmountBorrowed = 0.0,
        isAgentic = false,
        dayTradesProtection = true,
        dayTradeBuyingPower = null,
        dayTradeRatio = null,
        markedPatternDayTraderDate = null,
        patternDayTraderExpiryDate = null,
        isPdtForever = false; // TODO

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
        settledAmountBorrowed = 0.0,
        isAgentic = false,
        dayTradesProtection = true,
        dayTradeBuyingPower = null,
        dayTradeRatio = null,
        markedPatternDayTraderDate = null,
        patternDayTraderExpiryDate = null,
        isPdtForever = false; // TODO

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
      'settled_amount_borrowed': settledAmountBorrowed,
      'is_agentic': isAgentic,
      'day_trades_protection': dayTradesProtection,
      'day_trade_buying_power': dayTradeBuyingPower,
      'day_trade_ratio': dayTradeRatio,
      'marked_pattern_day_trader_date':
          markedPatternDayTraderDate?.toIso8601String(),
      'pattern_day_trader_expiry_date':
          patternDayTraderExpiryDate?.toIso8601String(),
      'is_pdt_forever': isPdtForever,
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
