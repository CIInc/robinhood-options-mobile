/*
[
  {
    url: https://api.robinhood.com/portfolios/1AB23456/, 
    account: https://api.robinhood.com/accounts/1AB23456/, 
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
import 'package:robinhood_options_mobile/utils/json.dart';

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
  final DateTime? updatedAt;

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
      this.unwithdrawableGrants,
      this.updatedAt);

  Portfolio.fromJson(dynamic json)
      : url = json['url'],
        account = json['account'],
        startDate = DateTime.tryParse(json['start_date'] ?? ''),
        marketValue = parseDouble(json['market_value']),
        equity = parseDouble(json['equity']),
        extendedHoursMarketValue =
            parseDouble(json['extended_hours_market_value']),
        extendedHoursEquity = parseDouble(json['extended_hours_equity']),
        extendedHoursPortfolioEquity =
            parseDouble(json['extended_hours_portfolio_equity']),
        lastCoreMarketValue = parseDouble(json['last_core_market_value']),
        lastCoreEquity = parseDouble(json['last_core_equity']),
        lastCorePortfolioEquity =
            parseDouble(json['last_core_portfolio_equity']),
        excessMargin = parseDouble(json['excess_margin']),
        excessMaintenance = parseDouble(json['excess_maintenance']),
        excessMarginWithUnclearedDeposits =
            parseDouble(json['excess_margin_with_uncleared_deposits']),
        excessMaintenanceWithUnclearedDeposits =
            parseDouble(json['excess_maintenance_with_uncleared_deposits']),
        equityPreviousClose = parseDouble(json['equity_previous_close']),
        portfolioEquityPreviousClose =
            parseDouble(json['portfolio_equity_previous_close']),
        adjustedEquityPreviousClose =
            parseDouble(json['adjusted_equity_previous_close']),
        adjustedPortfolioEquityPreviousClose =
            parseDouble(json['adjusted_portfolio_equity_previous_close']),
        withdrawableAmount = parseDouble(json['withdrawable_amount']),
        unwithdrawableDeposits = parseDouble(json['unwithdrawable_deposits']),
        unwithdrawableGrants = parseDouble(json['unwithdrawable_grants']),
        updatedAt = DateTime.now();
  // 2021-02-09T18:01:28.135813Z

  Portfolio.fromSchwabJson(dynamic json)
      : url = '',
        account = json['securitiesAccount']['accountNumber'],
        startDate = null, //DateTime.tryParse(json['start_date']),
        marketValue = (parseDouble(json['securitiesAccount']['currentBalances']
                    ['longOptionMarketValue']) ??
                0) +
            (parseDouble(json['securitiesAccount']['currentBalances']
                    ['longMarketValue']) ??
                0),
        equity = parseDouble(json['securitiesAccount']['currentBalances']
            ['liquidationValue']), //double.tryParse(json['equity']),
        extendedHoursMarketValue =
            null, // json['extended_hours_market_value'] != null ? double.tryParse(json['extended_hours_market_value']) : null,
        extendedHoursEquity =
            null, // json['extended_hours_equity'] != null ? double.tryParse(json['extended_hours_equity']) : null,
        extendedHoursPortfolioEquity =
            null, // json['extended_hours_portfolio_equity'] != null ? double.tryParse(json['extended_hours_portfolio_equity']) : null,
        lastCoreMarketValue =
            null, // double.tryParse(json['last_core_market_value']),
        lastCoreEquity = null, // double.tryParse(json['last_core_equity']),
        lastCorePortfolioEquity =
            null, // double.tryParse(json['last_core_portfolio_equity']),
        excessMargin = null, // double.tryParse(json['excess_margin']),
        excessMaintenance =
            null, // double.tryParse(json['excess_maintenance']),
        excessMarginWithUnclearedDeposits =
            null, // double.tryParse(json['excess_margin_with_uncleared_deposits']),
        excessMaintenanceWithUnclearedDeposits =
            null, // double.tryParse(json['excess_maintenance_with_uncleared_deposits']),
        equityPreviousClose =
            null, // double.tryParse(json['securitiesAccount']['initialBalances']['longOptionMarketValue'].toString())! + double.tryParse(json['securitiesAccount']['initialBalances']['longStockValue'].toString())!,
        portfolioEquityPreviousClose =
            null, // double.tryParse(json['portfolio_equity_previous_close']),
        adjustedEquityPreviousClose =
            null, // double.tryParse(json['adjusted_equity_previous_close']),
        adjustedPortfolioEquityPreviousClose =
            null, // double.tryParse(json['adjusted_portfolio_equity_previous_close']),
        withdrawableAmount =
            null, // double.tryParse(json['withdrawable_amount']),
        unwithdrawableDeposits =
            null, // double.tryParse(json['unwithdrawable_deposits']),
        unwithdrawableGrants =
            null, // double.tryParse(json['unwithdrawable_grants']),
        updatedAt = DateTime.now();
}
