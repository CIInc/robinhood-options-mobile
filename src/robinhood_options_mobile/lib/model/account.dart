class Account {
  final String url;
  final double? portfolioCash;
  final String accountNumber;
  final String type;

  Account(this.url, this.portfolioCash, this.accountNumber, this.type);

  Account.fromJson(dynamic json)
      : url = json['url'],
        portfolioCash = double.tryParse(json['portfolio_cash']),
        accountNumber = json['account_number'],
        type = json['type'];
}
