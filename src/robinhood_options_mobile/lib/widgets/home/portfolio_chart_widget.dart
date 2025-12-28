import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/equity_historical.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals_selection_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals_store.dart';
import 'package:robinhood_options_mobile/widgets/animated_price_text.dart';
import 'package:robinhood_options_mobile/widgets/chart_time_series_widget.dart';
import 'package:robinhood_options_mobile/widgets/pnl_badge.dart';

class PortfolioChartWidget extends StatefulWidget {
  final BrokerageUser brokerageUser;
  final ChartDateSpan chartDateSpanFilter;
  final Bounds chartBoundsFilter;
  final Function(ChartDateSpan, Bounds) onFilterChanged;

  const PortfolioChartWidget({
    super.key,
    required this.brokerageUser,
    required this.chartDateSpanFilter,
    required this.chartBoundsFilter,
    required this.onFilterChanged,
  });

  @override
  State<PortfolioChartWidget> createState() => _PortfolioChartWidgetState();
}

class _PortfolioChartWidgetState extends State<PortfolioChartWidget> {
  PortfolioHistoricals? _previousPortfolioHistoricals;
  bool animateChart = true;

  @override
  Widget build(BuildContext context) {
    return Selector<PortfolioHistoricalsStore, PortfolioHistoricals?>(
      selector: (context, store) {
        final baseData = store.items.firstWhereOrNull((element) =>
            element.span == convertChartSpanFilter(widget.chartDateSpanFilter));

        // Append hour data if available for fresher updates on all date filters
        if (baseData != null) {
          final hourData = store.items.firstWhereOrNull((element) =>
              element.span == convertChartSpanFilter(ChartDateSpan.hour));

          if (hourData != null && hourData.equityHistoricals.isNotEmpty) {
            // Find the latest timestamp in base data
            final baseMaxDate = baseData.equityHistoricals.isNotEmpty
                ? baseData.equityHistoricals
                    .map((e) => e.beginsAt!)
                    .reduce((a, b) => a.isAfter(b) ? a : b)
                : DateTime(2000);

            // Append hour data points that are newer than base data
            final newerHourData = hourData.equityHistoricals
                .where((element) => element.beginsAt!.isAfter(baseMaxDate))
                .toList();

            if (newerHourData.isNotEmpty) {
              // Create a new merged PortfolioHistoricals
              final mergedData = PortfolioHistoricals(
                baseData.adjustedOpenEquity,
                baseData.adjustedPreviousCloseEquity,
                baseData.openEquity,
                baseData.previousCloseEquity,
                baseData.openTime,
                baseData.interval,
                baseData.span,
                baseData.bounds,
                baseData.totalReturn,
                [...baseData.equityHistoricals, ...newerHourData],
                baseData.useNewHp,
              );

              // Only disable animation if we had previous data and are appending
              if (_previousPortfolioHistoricals != null &&
                  _previousPortfolioHistoricals!.equityHistoricals.isNotEmpty) {
                animateChart = false;
              } else {
                animateChart = true;
              }

              _previousPortfolioHistoricals = mergedData;
              return mergedData;
            }
          }
        }

        // Check if this is truly new data or just a rebuild
        if (baseData != null && _previousPortfolioHistoricals != null) {
          // If data length changed, it's new data - disable animation for smooth append
          if (baseData.equityHistoricals.length >
              _previousPortfolioHistoricals!.equityHistoricals.length) {
            animateChart = false;
          } else if (baseData.equityHistoricals.length ==
              _previousPortfolioHistoricals!.equityHistoricals.length) {
            // Same length - check if last timestamp changed
            final currentLast = baseData.equityHistoricals.isNotEmpty
                ? baseData.equityHistoricals.last.beginsAt
                : null;
            final previousLast = _previousPortfolioHistoricals!
                    .equityHistoricals.isNotEmpty
                ? _previousPortfolioHistoricals!.equityHistoricals.last.beginsAt
                : null;
            if (currentLast != null &&
                previousLast != null &&
                currentLast.isAfter(previousLast)) {
              animateChart = false;
            } else {
              animateChart = true;
            }
          } else {
            // Data got shorter - full refresh
            animateChart = true;
          }
        } else {
          // First load or no previous data
          animateChart = true;
        }

        _previousPortfolioHistoricals = baseData;
        return baseData;
      },
      builder: (context, portfolioHistoricals, child) {
        if (portfolioHistoricals == null) {
          return SizedBox(
            height: 300,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Loading portfolio data...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7),
                        ),
                  ),
                ],
              ),
            ),
          );
        }

        EquityHistorical? firstHistorical;
        EquityHistorical? lastHistorical;
        double open = 0;
        double close = 0;
        double changeInPeriod = 0;
        double changePercentInPeriod = 0;

        firstHistorical = portfolioHistoricals.equityHistoricals.first;
        lastHistorical = portfolioHistoricals.equityHistoricals.last;
        var allHistoricals = portfolioHistoricals.equityHistoricals;

        open = firstHistorical.adjustedOpenEquity!;
        close = lastHistorical.adjustedCloseEquity!;

        changeInPeriod = close - open;
        changePercentInPeriod = (close / open) - 1;

        var provider = Provider.of<PortfolioHistoricalsSelectionStore>(context,
            listen: false);
        TimeSeriesChart historicalChart = TimeSeriesChart(
          [
            charts.Series<EquityHistorical, DateTime>(
              id: 'Adjusted Equity',
              colorFn: (_, __) => charts.ColorUtil.fromDartColor(
                  Theme.of(context).colorScheme.primary),
              domainFn: (EquityHistorical history, _) => history.beginsAt!,
              measureFn: (EquityHistorical history, index) =>
                  history.adjustedOpenEquity,
              labelAccessorFn: (EquityHistorical history, index) =>
                  formatCompactNumber.format((history.adjustedOpenEquity)),
              data: allHistoricals,
            ),
            charts.Series<EquityHistorical, DateTime>(
                id: 'Equity',
                colorFn: (_, __) => charts.MaterialPalette.green.shadeDefault,
                domainFn: (EquityHistorical history, _) => history.beginsAt!,
                measureFn: (EquityHistorical history, index) =>
                    history.openEquity,
                data: allHistoricals),
            charts.Series<EquityHistorical, DateTime>(
                id: 'Market Value',
                colorFn: (_, __) => charts.MaterialPalette.red.shadeDefault,
                domainFn: (EquityHistorical history, _) => history.beginsAt!,
                measureFn: (EquityHistorical history, index) =>
                    history.openMarketValue,
                data: allHistoricals),
          ],
          animate: animateChart,
          zeroBound: false,
          open: open,
          close: close,
          seriesLegend: charts.SeriesLegend(
            horizontalFirst: true,
            position: charts.BehaviorPosition.top,
            defaultHiddenSeries: const ['Equity', 'Market Value'],
            showMeasures: false,
            measureFormatter: (measure) =>
                measure != null ? formatPercentage.format(measure) : '',
          ),
          onSelected: (charts.SelectionModel<dynamic>? model) {
            provider.selectionChanged(model?.selectedDatum.first.datum);
          },
          symbolRenderer: TextSymbolRenderer(() {
            firstHistorical = portfolioHistoricals.equityHistoricals[0];
            open = firstHistorical!.adjustedOpenEquity!;
            if (provider.selection != null) {
              changeInPeriod = provider.selection!.adjustedCloseEquity! - open;
              changePercentInPeriod =
                  provider.selection!.adjustedCloseEquity! / open - 1;
            } else {
              changeInPeriod = close - open;
              changePercentInPeriod = (close / open) - 1;
            }
            return "${formatCurrency.format(provider.selection != null ? provider.selection!.adjustedCloseEquity : close)}\n${formatCompactDateTimeWithHour.format(provider.selection != null ? provider.selection!.beginsAt!.toLocal() : lastHistorical!.beginsAt!.toLocal())}";
          }, marginBottom: 16),
        );

        return Column(children: [
          Consumer<PortfolioHistoricalsSelectionStore>(
              builder: (context, value, child) {
            var selection = value.selection;
            if (selection != null) {
              changeInPeriod = selection.adjustedCloseEquity! - open;
              changePercentInPeriod = selection.adjustedCloseEquity! / open - 1;
            } else {
              changeInPeriod = close - open;
              changePercentInPeriod = close / open - 1;
            }
            String? returnText = widget.brokerageUser.getDisplayText(
                changeInPeriod,
                displayValue: DisplayValue.totalReturn);
            String? returnPercentText = widget.brokerageUser.getDisplayText(
                changePercentInPeriod,
                displayValue: DisplayValue.totalReturnPercent);

            return SizedBox(
                child: Column(
              children: [
                SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(summaryEgdeInset),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      PnlBadge(
                                          child: AnimatedPriceText(
                                              price: selection != null
                                                  ? selection
                                                      .adjustedCloseEquity!
                                                  : close,
                                              format: formatCurrency,
                                              style: TextStyle(
                                                  fontSize:
                                                      summaryValueFontSize,
                                                  fontWeight: FontWeight.w600,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant)),
                                          neutral: true),
                                      Text(
                                          formatMediumDateTime.format(
                                              selection != null
                                                  ? selection.beginsAt!
                                                      .toLocal()
                                                  : lastHistorical!.beginsAt!
                                                      .toLocal()),
                                          style: const TextStyle(
                                              fontSize: summaryLabelFontSize)),
                                    ]),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(summaryEgdeInset),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      PnlBadge(
                                          text: returnText,
                                          value: changeInPeriod,
                                          fontSize: summaryValueFontSize),
                                      const Text("Change",
                                          style: TextStyle(
                                              fontSize: summaryLabelFontSize)),
                                    ]),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(summaryEgdeInset),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      PnlBadge(
                                          text: returnPercentText,
                                          value: changePercentInPeriod,
                                          fontSize: summaryValueFontSize),
                                      const Text("Change %",
                                          style: TextStyle(
                                              fontSize: summaryLabelFontSize)),
                                    ]),
                              ),
                            ])))
              ],
            ));
          }),
          SizedBox(
              height: 460,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10.0, 0.0, 10.0, 10.0),
                child: historicalChart,
              )),
          SizedBox(
              height: 56,
              child: ListView.builder(
                padding: const EdgeInsets.all(5.0),
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  return Row(children: [
                    _buildChip('1H', ChartDateSpan.hour),
                    _buildChip('1D', ChartDateSpan.day),
                    _buildChip('1W', ChartDateSpan.week),
                    _buildChip('1M', ChartDateSpan.month),
                    _buildChip('3M', ChartDateSpan.month_3),
                    _buildChip('YTD', ChartDateSpan.ytd),
                    _buildChip('1Y', ChartDateSpan.year),
                    _buildChip('All', ChartDateSpan.all),
                    Container(width: 10),
                    _buildBoundsChip('Regular Hours', Bounds.regular),
                    _buildBoundsChip('24/7 Hours', Bounds.t24_7),
                  ]);
                },
                itemCount: 1,
              )),
        ]);
      },
    );
  }

  Widget _buildChip(String label, ChartDateSpan span) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: ChoiceChip(
        label: Text(label),
        selected: widget.chartDateSpanFilter == span,
        onSelected: (bool value) {
          if (value) {
            widget.onFilterChanged(span, widget.chartBoundsFilter);
          }
        },
      ),
    );
  }

  Widget _buildBoundsChip(String label, Bounds bounds) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: ChoiceChip(
        label: Text(label),
        selected: widget.chartBoundsFilter == bounds,
        onSelected: (bool value) {
          if (value) {
            widget.onFilterChanged(widget.chartDateSpanFilter, bounds);
          }
        },
      ),
    );
  }
}
