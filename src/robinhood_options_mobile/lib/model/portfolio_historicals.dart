import 'package:robinhood_options_mobile/model/equity_historical.dart';

class PortfolioHistoricals {
  final double? adjustedOpenEquity;
  final double? adjustedPreviousCloseEquity;
  final double? openEquity;
  final double? previousCloseEquity;
  final String? openTime;
  final String interval;
  final String span;
  final String bounds;
  final double? totalReturn;
  final List<EquityHistorical> equityHistoricals;
  final bool useNewHp;

  PortfolioHistoricals(
      this.adjustedOpenEquity,
      this.adjustedPreviousCloseEquity,
      this.openEquity,
      this.previousCloseEquity,
      this.openTime,
      this.interval,
      this.span,
      this.bounds,
      this.totalReturn,
      this.equityHistoricals,
      this.useNewHp);

  PortfolioHistoricals.fromJson(dynamic json)
      : adjustedOpenEquity = json['adjusted_open_equity'] != null
            ? double.tryParse(json['adjusted_open_equity'])
            : null,
        adjustedPreviousCloseEquity =
            json['adjusted_previous_close_equity'] != null
                ? double.tryParse(json['adjusted_previous_close_equity'])
                : null,
        openEquity = json['open_equity'] != null
            ? double.tryParse(json['open_equity'])
            : null,
        previousCloseEquity = json['previous_close_equity'] != null
            ? double.tryParse(json['previous_close_equity'])
            : null,
        openTime = json['open_time'],
        interval = json['interval'],
        span = json['span'],
        bounds = json['bounds'],
        totalReturn = double.tryParse(json['total_return']),
        equityHistoricals =
            EquityHistorical.fromJsonArray(json['equity_historicals']),
        useNewHp = json['use_new_hp'];
}
