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
      : url = json['securitiesAccount']?['accountNumber'] ?? '',
        account = json['securitiesAccount']?['accountNumber'] ?? '',
        startDate = null,
        marketValue = (parseDouble(json['securitiesAccount']?['currentBalances']
                    ?['longOptionMarketValue']) ??
                0) +
            (parseDouble(json['securitiesAccount']?['currentBalances']
                        ?['longMarketValue'] ??
                    json['securitiesAccount']?['currentBalances']
                        ?['marketValue']) ??
                0) +
            (parseDouble(json['securitiesAccount']?['currentBalances']
                    ?['mutualFundValue']) ??
                0) +
            (parseDouble(json['securitiesAccount']?['currentBalances']
                    ?['bondValue']) ??
                0),
        equity = parseDouble(json['securitiesAccount']?['currentBalances']
                ?['liquidationValue']) ??
            parseDouble(
                json['aggregatedBalance']?['currentLiquidationValue']) ??
            parseDouble(json['aggregatedBalance']?['liquidationValue']) ??
            parseDouble(json['securitiesAccount']?['initialBalances']
                ?['liquidationValue']) ??
            parseDouble(
                json['securitiesAccount']?['initialBalances']?['accountValue']),
        extendedHoursMarketValue = null,
        extendedHoursEquity = null,
        extendedHoursPortfolioEquity = null,
        lastCoreMarketValue = null,
        lastCoreEquity = null,
        lastCorePortfolioEquity = null,
        excessMargin = parseDouble(json['securitiesAccount']?['currentBalances']
                ?['excessMargin']) ??
            parseDouble(json['securitiesAccount']?['currentBalances']
                ?['availableFunds']) ??
            parseDouble(
                json['securitiesAccount']?['currentBalances']?['buyingPower']),
        excessMaintenance = parseDouble(json['securitiesAccount']
            ?['currentBalances']?['availableFundsNonMarginableTrade']),
        excessMarginWithUnclearedDeposits = null,
        excessMaintenanceWithUnclearedDeposits = null,
        equityPreviousClose = parseDouble(json['securitiesAccount']
                ?['initialBalances']?['liquidationValue']) ??
            parseDouble(json['securitiesAccount']?['initialBalances']
                ?['accountValue']) ??
            parseDouble(
                json['securitiesAccount']?['initialBalances']?['equity']),
        portfolioEquityPreviousClose = parseDouble(json['securitiesAccount']
                ?['initialBalances']?['liquidationValue']) ??
            parseDouble(json['securitiesAccount']?['initialBalances']
                ?['accountValue']) ??
            parseDouble(
                json['securitiesAccount']?['initialBalances']?['equity']),
        adjustedEquityPreviousClose = parseDouble(json['securitiesAccount']
                ?['initialBalances']?['liquidationValue']) ??
            parseDouble(json['securitiesAccount']?['initialBalances']
                ?['accountValue']) ??
            parseDouble(
                json['securitiesAccount']?['initialBalances']?['equity']),
        adjustedPortfolioEquityPreviousClose = parseDouble(
                json['securitiesAccount']?['initialBalances']
                    ?['liquidationValue']) ??
            parseDouble(json['securitiesAccount']?['initialBalances']
                ?['accountValue']) ??
            parseDouble(
                json['securitiesAccount']?['initialBalances']?['equity']),
        withdrawableAmount = parseDouble(json['securitiesAccount']
                ?['currentBalances']?['availableFunds']) ??
            parseDouble(
                json['securitiesAccount']?['currentBalances']?['cashBalance']),
        unwithdrawableDeposits = null,
        unwithdrawableGrants = null,
        updatedAt = DateTime.now();

  Map<String, dynamic> toJson() => {
        'url': url,
        'account': account,
        'start_date': startDate?.toIso8601String(),
        'market_value': marketValue,
        'equity': equity,
        'extended_hours_market_value': extendedHoursMarketValue,
        'extended_hours_equity': extendedHoursEquity,
        'extended_hours_portfolio_equity': extendedHoursPortfolioEquity,
        'last_core_market_value': lastCoreMarketValue,
        'last_core_equity': lastCoreEquity,
        'last_core_portfolio_equity': lastCorePortfolioEquity,
        'excess_margin': excessMargin,
        'excess_maintenance': excessMaintenance,
        'excess_margin_with_uncleared_deposits':
            excessMarginWithUnclearedDeposits,
        'excess_maintenance_with_uncleared_deposits':
            excessMaintenanceWithUnclearedDeposits,
        'equity_previous_close': equityPreviousClose,
        'portfolio_equity_previous_close': portfolioEquityPreviousClose,
        'adjusted_equity_previous_close': adjustedEquityPreviousClose,
        'adjusted_portfolio_equity_previous_close':
            adjustedPortfolioEquityPreviousClose,
        'withdrawable_amount': withdrawableAmount,
        'unwithdrawable_deposits': unwithdrawableDeposits,
        'unwithdrawable_grants': unwithdrawableGrants,
        'updated_at': updatedAt?.toIso8601String(),
      };
}
