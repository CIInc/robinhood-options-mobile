import 'dart:math' as math;
import 'package:candlesticks/candlesticks.dart';
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
import 'package:robinhood_options_mobile/widgets/home/full_screen_portfolio_chart_widget.dart';

class PortfolioChartWidget extends StatefulWidget {
  final BrokerageUser brokerageUser;
  final ChartDateSpan chartDateSpanFilter;
  final Bounds chartBoundsFilter;
  final Function(ChartDateSpan, Bounds) onFilterChanged;
  final bool isFullScreen;

  const PortfolioChartWidget({
    super.key,
    required this.brokerageUser,
    required this.chartDateSpanFilter,
    required this.chartBoundsFilter,
    required this.onFilterChanged,
    this.isFullScreen = false,
  });

  @override
  State<PortfolioChartWidget> createState() => _PortfolioChartWidgetState();
}

class _PortfolioChartWidgetState extends State<PortfolioChartWidget> {
  PortfolioHistoricals? _previousPortfolioHistoricals;
  late ChartDateSpan _chartDateSpanFilter;
  late Bounds _chartBoundsFilter;
  bool _showCandles = false;

  @override
  void initState() {
    super.initState();
    _chartDateSpanFilter = widget.chartDateSpanFilter;
    _chartBoundsFilter = widget.chartBoundsFilter;
  }

  @override
  void didUpdateWidget(PortfolioChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.chartDateSpanFilter != oldWidget.chartDateSpanFilter) {
      _chartDateSpanFilter = widget.chartDateSpanFilter;
    }
    if (widget.chartBoundsFilter != oldWidget.chartBoundsFilter) {
      _chartBoundsFilter = widget.chartBoundsFilter;
    }
    if (widget.brokerageUser.userName != oldWidget.brokerageUser.userName) {
      _previousPortfolioHistoricals = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Selector<PortfolioHistoricalsStore, PortfolioHistoricals?>(
      selector: (context, store) {
        final baseData = store.items.firstWhereOrNull((element) =>
            element.span == convertChartSpanFilter(_chartDateSpanFilter));

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
              return mergedData;
            }
          }
        }
        return baseData;
      },
      builder: (context, portfolioHistoricals, child) {
        var dataToShow = portfolioHistoricals ?? _previousPortfolioHistoricals;

        if (dataToShow == null) {
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
                              .withValues(alpha: 0.7),
                        ),
                  ),
                ],
              ),
            ),
          );
        }

        // Determine animation state
        bool shouldAnimate = true;
        if (portfolioHistoricals != null &&
            _previousPortfolioHistoricals != null) {
          if (portfolioHistoricals.span !=
              _previousPortfolioHistoricals!.span) {
            shouldAnimate = true;
          } else if (portfolioHistoricals.equityHistoricals.length >
              _previousPortfolioHistoricals!.equityHistoricals.length) {
            shouldAnimate = false;
          } else if (portfolioHistoricals.equityHistoricals.length ==
              _previousPortfolioHistoricals!.equityHistoricals.length) {
            // Same length - check if last timestamp changed
            final currentLast =
                portfolioHistoricals.equityHistoricals.isNotEmpty
                    ? portfolioHistoricals.equityHistoricals.last.beginsAt
                    : null;
            final previousLast = _previousPortfolioHistoricals!
                    .equityHistoricals.isNotEmpty
                ? _previousPortfolioHistoricals!.equityHistoricals.last.beginsAt
                : null;
            final currentFirst =
                portfolioHistoricals.equityHistoricals.isNotEmpty
                    ? portfolioHistoricals.equityHistoricals.first.beginsAt
                    : null;
            final previousFirst =
                _previousPortfolioHistoricals!.equityHistoricals.isNotEmpty
                    ? _previousPortfolioHistoricals!
                        .equityHistoricals.first.beginsAt
                    : null;

            if (currentLast != null &&
                previousLast != null &&
                currentLast.isAfter(previousLast) &&
                currentFirst == previousFirst) {
              shouldAnimate = false;
            } else {
              shouldAnimate = false;
            }
          } else {
            // Data got shorter - full refresh
            shouldAnimate = true;
          }
        } else if (portfolioHistoricals == null) {
          // Showing old data while loading new data - don't re-animate static chart
          shouldAnimate = false;
        } else {
          // First load
          shouldAnimate = true;
        }

        if (portfolioHistoricals != null) {
          _previousPortfolioHistoricals = portfolioHistoricals;
        }

        EquityHistorical? firstHistorical;
        EquityHistorical? lastHistorical;
        double open = 0;
        double close = 0;
        double changeInPeriod = 0;
        double changePercentInPeriod = 0;

        firstHistorical = dataToShow.equityHistoricals.first;
        lastHistorical = dataToShow.equityHistoricals.last;
        var allHistoricals = dataToShow.equityHistoricals;

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
            if (allHistoricals.any((element) => element.openEquity! > 0)) ...[
              charts.Series<EquityHistorical, DateTime>(
                  id: 'Equity',
                  colorFn: (_, __) => charts.MaterialPalette.green.shadeDefault,
                  domainFn: (EquityHistorical history, _) => history.beginsAt!,
                  measureFn: (EquityHistorical history, index) =>
                      history.openEquity,
                  data: allHistoricals),
            ],
            if (allHistoricals
                .any((element) => element.openMarketValue! > 0)) ...[
              charts.Series<EquityHistorical, DateTime>(
                  id: 'Market Value',
                  colorFn: (_, __) => charts.MaterialPalette.red.shadeDefault,
                  domainFn: (EquityHistorical history, _) => history.beginsAt!,
                  measureFn: (EquityHistorical history, index) =>
                      history.openMarketValue,
                  data: allHistoricals),
            ]
          ],
          animate: shouldAnimate,
          zeroBound: false,
          open: open,
          close: close,
          seriesLegend: (allHistoricals
                      .any((element) => element.openEquity! > 0) ||
                  allHistoricals.any((element) => element.openMarketValue! > 0))
              ? charts.SeriesLegend(
                  horizontalFirst: true,
                  position: charts.BehaviorPosition.top,
                  defaultHiddenSeries: const ['Equity', 'Market Value'],
                  showMeasures: false,
                  measureFormatter: (measure) =>
                      measure != null ? formatPercentage.format(measure) : '',
                )
              : null,
          onSelected: (charts.SelectionModel<dynamic>? model) {
            provider.selectionChanged(model?.selectedDatum.first.datum);
          },
          symbolRenderer: TextSymbolRenderer(() {
            firstHistorical = dataToShow.equityHistoricals[0];
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
          },
              marginBottom: 16,
              backgroundColor: Theme.of(context).colorScheme.inverseSurface,
              textColor: Theme.of(context).colorScheme.onInverseSurface),
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

            if (widget.isFullScreen) {
              // Compact single-line header for full screen with some styling
              final primary = Theme.of(context).colorScheme.primary;
              final positive = Colors.green;
              final negative = Colors.red;
              final neutralColor =
                  Theme.of(context).colorScheme.onSurfaceVariant;

              final changeColor = changeInPeriod > 0
                  ? positive
                  : (changeInPeriod < 0 ? negative : neutralColor);
              final changePercentColor = changePercentInPeriod > 0
                  ? positive
                  : (changePercentInPeriod < 0 ? negative : neutralColor);

              return SizedBox(
                height: 52,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Portfolio Value Badge
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                primary.withValues(alpha: 0.12),
                                Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: primary.withValues(alpha: 0.3)),
                            boxShadow: [
                              BoxShadow(
                                color: primary.withValues(alpha: 0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(7),
                                  border: Border.all(
                                      color: primary.withValues(alpha: 0.3)),
                                ),
                                child: Icon(
                                    Icons.account_balance_wallet_rounded,
                                    size: 14,
                                    color: primary),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'PORTFOLIO',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.3,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                    ),
                                    AnimatedPriceText(
                                      price: selection != null
                                          ? selection.adjustedCloseEquity!
                                          : close,
                                      format: formatCurrency,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Change Badge
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                changeColor.withValues(alpha: 0.12),
                                Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: changeColor.withValues(alpha: 0.3)),
                            boxShadow: [
                              BoxShadow(
                                color: changeColor.withValues(alpha: 0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CHANGE',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    changeInPeriod >= 0
                                        ? Icons.trending_up_rounded
                                        : Icons.trending_down_rounded,
                                    size: 12,
                                    color: changeColor,
                                  ),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(
                                      returnText,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: changeColor,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Change % Badge
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                changePercentColor.withValues(alpha: 0.12),
                                Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color:
                                    changePercentColor.withValues(alpha: 0.3)),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    changePercentColor.withValues(alpha: 0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CHANGE %',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    changePercentInPeriod >= 0
                                        ? Icons.percent_rounded
                                        : Icons.percent_outlined,
                                    size: 12,
                                    color: changePercentColor,
                                  ),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(
                                      returnPercentText,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: changePercentColor,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return SizedBox(
                child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: LayoutBuilder(builder: (context, constraints) {
                    final primary = Theme.of(context).colorScheme.primary;
                    final positive = Colors.green;
                    final negative = Colors.red;
                    final neutralColor =
                        Theme.of(context).colorScheme.onSurfaceVariant;

                    final changeColor = changeInPeriod > 0
                        ? positive
                        : (changeInPeriod < 0 ? negative : neutralColor);
                    final changePercentColor = changePercentInPeriod > 0
                        ? positive
                        : (changePercentInPeriod < 0 ? negative : neutralColor);

                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildMetricBadge(
                          context: context,
                          label: 'Portfolio value',
                          icon: Icons.account_balance_wallet_rounded,
                          accent: primary,
                          minWidth: math.min(constraints.maxWidth, 360),
                          value: AnimatedPriceText(
                            price: selection != null
                                ? selection.adjustedCloseEquity!
                                : close,
                            format: formatCurrency,
                            style: TextStyle(
                              fontSize: portfolioValueFontSize,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          footnote: formatMediumDateTime.format(
                            selection != null
                                ? selection.beginsAt!.toLocal()
                                : lastHistorical!.beginsAt!.toLocal(),
                          ),
                        ),
                        _buildMetricBadge(
                          context: context,
                          label: 'Change',
                          icon: changeInPeriod >= 0
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          accent: changeColor,
                          minWidth: 180,
                          value: Text(
                            returnText,
                            style: TextStyle(
                              fontSize: portfolioValueFontSize,
                              fontWeight: FontWeight.w700,
                              color: changeColor,
                            ),
                          ),
                          footnote: 'Since period start',
                        ),
                        _buildMetricBadge(
                          context: context,
                          label: 'Change %',
                          icon: changePercentInPeriod >= 0
                              ? Icons.percent_rounded
                              : Icons.percent_outlined,
                          accent: changePercentColor,
                          minWidth: 170,
                          value: Text(
                            returnPercentText,
                            style: TextStyle(
                              fontSize: portfolioValueFontSize,
                              fontWeight: FontWeight.w700,
                              color: changePercentColor,
                            ),
                          ),
                          footnote: 'Performance',
                        ),
                      ],
                    );
                  }),
                )
              ],
            ));
          }),
          widget.isFullScreen
              ? Expanded(
                  child: Padding(
                  padding: const EdgeInsets.fromLTRB(10.0, 0.0, 10.0, 10.0),
                  child: Stack(
                    children: [
                      _showCandles
                          ? Candlesticks(
                              candles: _generateCandles(allHistoricals),
                            )
                          : historicalChart,
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton(
                          icon: Icon(_showCandles
                              ? Icons.show_chart
                              : Icons.candlestick_chart),
                          onPressed: () {
                            setState(() {
                              _showCandles = !_showCandles;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ))
              : Stack(
                  children: [
                    SizedBox(
                        height: 460,
                        child: Padding(
                          padding:
                              const EdgeInsets.fromLTRB(10.0, 0.0, 10.0, 10.0),
                          child: historicalChart,
                        )),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton(
                        icon: const Icon(Icons.fullscreen),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  FullScreenPortfolioChartWidget(
                                brokerageUser: widget.brokerageUser,
                                chartDateSpanFilter: widget.chartDateSpanFilter,
                                chartBoundsFilter: widget.chartBoundsFilter,
                                onFilterChanged: widget.onFilterChanged,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
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
          if (widget.isFullScreen) const SizedBox(height: 25),
        ]);
      },
    );
  }

  Widget _buildMetricBadge({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color accent,
    required Widget value,
    double? minWidth,
    String? footnote,
  }) {
    final background = [
      accent.withValues(alpha: 0.22),
      Theme.of(context).colorScheme.surfaceContainerHighest,
    ];

    return Container(
      constraints: BoxConstraints(
        minWidth: minWidth ?? 160,
        maxWidth: math.max(minWidth ?? 160, 260),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: background,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accent.withValues(alpha: 0.4)),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              value,
              if (footnote != null) ...[
                const SizedBox(height: 4),
                Text(
                  footnote,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.85),
                  ),
                ),
              ]
            ],
          )
        ],
      ),
    );
  }

  Widget _buildChip(String label, ChartDateSpan span) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: ChoiceChip(
        label: Text(label),
        selected: _chartDateSpanFilter == span,
        onSelected: (bool value) {
          if (value) {
            setState(() {
              _chartDateSpanFilter = span;
            });
            widget.onFilterChanged(span, _chartBoundsFilter);
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
        selected: _chartBoundsFilter == bounds,
        onSelected: (bool value) {
          if (value) {
            setState(() {
              _chartBoundsFilter = bounds;
            });
            widget.onFilterChanged(_chartDateSpanFilter, bounds);
          }
        },
      ),
    );
  }

  List<Candle> _generateCandles(List<EquityHistorical> historicals) {
    if (historicals.isEmpty) return [];

    // Determine bucket size based on total points to get roughly 60 candles
    int bucketSize = (historicals.length / 60).ceil();
    if (bucketSize < 2) {
      bucketSize = 2; // Ensure at least 2 points to have some High/Low diff
    }

    List<Candle> candles = [];
    for (int i = 0; i < historicals.length; i += bucketSize) {
      int end = (i + bucketSize < historicals.length)
          ? i + bucketSize
          : historicals.length;
      var chunk = historicals.sublist(i, end);

      double open = chunk.first.adjustedOpenEquity ?? 0;
      double close = chunk.last.adjustedCloseEquity ?? 0;

      // Calculate High/Low from the chunk
      double high = chunk
          .map((e) =>
              math.max(e.adjustedOpenEquity ?? 0, e.adjustedCloseEquity ?? 0))
          .reduce(math.max);
      double low = chunk
          .map((e) =>
              math.min(e.adjustedOpenEquity ?? 0, e.adjustedCloseEquity ?? 0))
          .reduce(math.min);

      // Ensure values are positive to avoid log10(0) errors in candlesticks package
      const double minPrice = 0.01;
      if (high < minPrice) high = minPrice;
      if (low < minPrice) low = minPrice;
      if (open < minPrice) open = minPrice;
      if (close < minPrice) close = minPrice;

      // Ensure high > low to prevent log10(0) error when range is zero
      if (high <= low) {
        high = low + 0.0001;
      }


      // Volume is not available in EquityHistorical, set to 1 to avoid log10(0) error
      double volume = 1;

      candles.add(Candle(
        date: chunk.first.beginsAt!,
        high: high,
        low: low,
        open: open,
        close: close,
        volume: volume,
      ));
    }
    // Candlesticks package expects newest first
    return candles.reversed.toList();
  }
}
