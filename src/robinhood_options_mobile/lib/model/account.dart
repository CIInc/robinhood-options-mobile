class Account {
  final String url;
  final double? portfolioCash;
  final String accountNumber;
  final String type;
  final double? buyingPower;
  final String optionLevel;
  final double? cashHeldForOptionsCollateral;

  Account(this.url, this.portfolioCash, this.accountNumber, this.type,
      this.buyingPower, this.optionLevel, this.cashHeldForOptionsCollateral);

  Account.fromJson(dynamic json)
      : url = json['url'],
        portfolioCash = double.tryParse(json['portfolio_cash']),
        accountNumber = json['account_number'],
        type = json['type'],
        buyingPower = double.tryParse(json['buying_power']),
        optionLevel = json['option_level'],
        cashHeldForOptionsCollateral =
            double.tryParse(json['cash_held_for_options_collateral']);
}
