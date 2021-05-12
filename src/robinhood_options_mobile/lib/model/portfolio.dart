/*
[
  {
    url: https://api.robinhood.com/portfolios/5QR24141/, 
    account: https://api.robinhood.com/accounts/5QR24141/, 
    start_date: 2015-02-23, 
    market_value: 8867.8329, 
    equity: 12150.8729, 
    extended_hours_market_value: 8860.8205, 
    extended_hours_equity: 12143.8605, 
    extended_hours_portfolio_equity: 12143.8605, 
    last_core_market_value: 8867.8329, 
    last_core_equity: 12150.8729, 
    last_core_portfolio_equity: 12150.8729, 
    excess_margin: 5684.1935, 
    excess_maintenance: 6871.4547, 
    excess_margin_with_uncleared_deposits: 5684.1935, 
    excess_maintenance_with_uncleared_deposits: 6871.4547, 
    equity_previous_close: 11876.6061, 
    portfolio_equity_previous_close: 11876.6061, 
    adjusted_equity_previous_close: 11876.6061, 
    adjusted_portfolio_equity_previous_close: 11876.6061, 
    withdrawable_amount: 3283.0400, 
    unwithdrawable_deposits: 0.0000, 
    unwithdrawable_grants: 0.0000
    }
    ]
*/
class Portfolio {
  final String url;
  final String account;
  final DateTime? startDate;
  final double? marketValue;
  final double? equity;
  final double? extendedHoursMarketValue;
  final double? extendedHoursEquity;
  final double? extendedHoursPortfolioEquity;
  final double? lastCoreMarketValue;
  final double? lastCoreEquity;
  final double? lastCorePortfolioEquity;
  final double? excessMargin;
  final double? excessMaintenance;
  final double? excessMarginWithUnclearedDeposits;
  final double? excessMaintenanceWithUnclearedDeposits;
  final double? equityPreviousClose;
  final double? portfolioEquityPreviousClose;
  final double? adjustedEquityPreviousClose;
  final double? adjustedPortfolioEquityPreviousClose;
  final double? withdrawableAmount;
  final double? unwithdrawableDeposits;
  final double? unwithdrawableGrants;

  Portfolio(
      this.url,
      this.account,
      this.startDate,
      this.marketValue,
      this.equity,
      this.extendedHoursMarketValue,
      this.extendedHoursEquity,
      this.extendedHoursPortfolioEquity,
      this.lastCoreMarketValue,
      this.lastCoreEquity,
      this.lastCorePortfolioEquity,
      this.excessMargin,
      this.excessMaintenance,
      this.excessMarginWithUnclearedDeposits,
      this.excessMaintenanceWithUnclearedDeposits,
      this.equityPreviousClose,
      this.portfolioEquityPreviousClose,
      this.adjustedEquityPreviousClose,
      this.adjustedPortfolioEquityPreviousClose,
      this.withdrawableAmount,
      this.unwithdrawableDeposits,
      this.unwithdrawableGrants);

  Portfolio.fromJson(dynamic json)
      : url = json['url'],
        account = json['account'],
        startDate = DateTime.tryParse(json['start_date']),
        marketValue = double.tryParse(json['market_value']),
        equity = double.tryParse(json['equity']),
        extendedHoursMarketValue = json['extended_hours_market_value'] != null
            ? double.tryParse(json['extended_hours_market_value'])
            : null,
        extendedHoursEquity = json['extended_hours_equity'] != null
            ? double.tryParse(json['extended_hours_equity'])
            : null,
        extendedHoursPortfolioEquity =
            json['extended_hours_portfolio_equity'] != null
                ? double.tryParse(json['extended_hours_portfolio_equity'])
                : null,
        lastCoreMarketValue = double.tryParse(json['last_core_market_value']),
        lastCoreEquity = double.tryParse(json['last_core_equity']),
        lastCorePortfolioEquity =
            double.tryParse(json['last_core_portfolio_equity']),
        excessMargin = double.tryParse(json['excess_margin']),
        excessMaintenance = double.tryParse(json['excess_maintenance']),
        excessMarginWithUnclearedDeposits =
            double.tryParse(json['excess_margin_with_uncleared_deposits']),
        excessMaintenanceWithUnclearedDeposits =
            double.tryParse(json['excess_maintenance_with_uncleared_deposits']),
        equityPreviousClose = double.tryParse(json['equity_previous_close']),
        portfolioEquityPreviousClose =
            double.tryParse(json['portfolio_equity_previous_close']),
        adjustedEquityPreviousClose =
            double.tryParse(json['adjusted_equity_previous_close']),
        adjustedPortfolioEquityPreviousClose =
            double.tryParse(json['adjusted_portfolio_equity_previous_close']),
        withdrawableAmount = double.tryParse(json['withdrawable_amount']),
        unwithdrawableDeposits =
            double.tryParse(json['unwithdrawable_deposits']),
        unwithdrawableGrants = double.tryParse(json['unwithdrawable_grants']);
  // 2021-02-09T18:01:28.135813Z
}
