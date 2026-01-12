import 'package:collection/collection.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/chart_selection_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals_store.dart';
import 'package:robinhood_options_mobile/widgets/chart_time_series_widget.dart';
import 'package:robinhood_options_mobile/widgets/home/full_screen_performance_chart_widget.dart';

class PerformanceChartWidget extends StatefulWidget {
  final Future<dynamic>? futureMarketIndexHistoricalsSp500;
  final Future<dynamic>? futureMarketIndexHistoricalsNasdaq;
  final Future<dynamic>? futureMarketIndexHistoricalsDow;
  final Future<dynamic>? futureMarketIndexHistoricalsRussell2000;
  final Future<PortfolioHistoricals>? futurePortfolioHistoricalsYear;
  final ChartDateSpan benchmarkChartDateSpanFilter;
  final Function(ChartDateSpan) onFilterChanged;
  final bool isFullScreen;

  const PerformanceChartWidget({
    super.key,
    required this.futureMarketIndexHistoricalsSp500,
    required this.futureMarketIndexHistoricalsNasdaq,
    required this.futureMarketIndexHistoricalsDow,
    this.futureMarketIndexHistoricalsRussell2000,
    required this.futurePortfolioHistoricalsYear,
    required this.benchmarkChartDateSpanFilter,
    required this.onFilterChanged,
    this.isFullScreen = false,
  });

  @override
  State<PerformanceChartWidget> createState() => _PerformanceChartWidgetState();
}

class _PerformanceChartWidgetState extends State<PerformanceChartWidget> {
  bool animateChart = true;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.wait([
        widget.futureMarketIndexHistoricalsSp500 as Future,
        widget.futureMarketIndexHistoricalsNasdaq as Future,
        widget.futureMarketIndexHistoricalsDow as Future,
        widget.futureMarketIndexHistoricalsRussell2000 != null
            ? widget.futureMarketIndexHistoricalsRussell2000 as Future
            : Future.value(null),
        widget.futurePortfolioHistoricalsYear != null
            ? widget.futurePortfolioHistoricalsYear as Future
            : Future.value(null)
      ]),
      builder: (context, snapshot) {
        if (snapshot.hasData &&
            snapshot.connectionState == ConnectionState.done) {
          var sp500 = snapshot.data![0];
          var nasdaq = snapshot.data![1];
          var dow = snapshot.data![2];
          var russell2000 = snapshot.data![3];
          var portfolioHistoricals = snapshot.data![4] as PortfolioHistoricals?;
          if (portfolioHistoricals != null) {
            final DateTime now = DateTime.now();
            final DateTime newYearsDay = DateTime(now.year, 1, 1);

            var portfolioHistoricalsStore =
                Provider.of<PortfolioHistoricalsStore>(context, listen: true);
            var dayHistoricals = portfolioHistoricalsStore.items
                .singleWhereOrNull((e) => e.span == 'day');
            if (dayHistoricals != null &&
                !portfolioHistoricals.equityHistoricals.any((e) =>
                    e.beginsAt ==
                    dayHistoricals.equityHistoricals.last.beginsAt)) {
              portfolioHistoricals.equityHistoricals
                  .add(dayHistoricals.equityHistoricals.last);
            }

            var regularsp500 = sp500['chart']['result'][0]['meta']
                ['currentTradingPeriod']['regular'];
            var sp500PreviousClose =
                sp500['chart']['result'][0]['meta']['chartPreviousClose'];
            var nasdaqPreviousClose =
                nasdaq['chart']['result'][0]['meta']['chartPreviousClose'];
            var dowPreviousClose =
                dow['chart']['result'][0]['meta']['chartPreviousClose'];
            var russell2000PreviousClose = russell2000 != null
                ? russell2000['chart']['result'][0]['meta']
                    ['chartPreviousClose']
                : null;
            var enddiffsp500 = regularsp500['end'] - regularsp500['start'];

            DateTime? cutoff;
            if (widget.benchmarkChartDateSpanFilter == ChartDateSpan.year_2) {
              cutoff = DateTime.now().subtract(const Duration(days: 365 * 2));
            } else if (widget.benchmarkChartDateSpanFilter ==
                ChartDateSpan.year_3) {
              cutoff = DateTime.now().subtract(const Duration(days: 365 * 3));
            } else if (widget.benchmarkChartDateSpanFilter ==
                ChartDateSpan.year_5) {
              cutoff = DateTime.now().subtract(const Duration(days: 365 * 5));
            } else if (widget.benchmarkChartDateSpanFilter ==
                ChartDateSpan.ytd) {
              cutoff = newYearsDay.subtract(const Duration(milliseconds: 1));
            }

            List<Map<String, dynamic>> processMarketData(
                dynamic data, double previousClose) {
              var timestamps =
                  (data['chart']['result'][0]['timestamp'] as List);
              var adjcloses = (data['chart']['result'][0]['indicators']
                  ['adjclose'][0]['adjclose'] as List);

              var list = timestamps.mapIndexed((index, e) {
                final numerator = adjcloses[index];
                final close = (numerator as num?)?.toDouble();
                return {
                  'date': DateTime.fromMillisecondsSinceEpoch(
                      (e + enddiffsp500) * 1000),
                  'close': close
                };
              }).toList();

              // Update the processMarketData function to correctly calculate the base price for YTD performance. It now attempts to find the closing price of the last trading day of the previous year to use as the baseline, ensuring accurate percentage change calculations relative to the start of the year.
              // Ensure that for YTD charts, the data is filtered to start from the beginning of the year, but the baseline price is preserved (or derived from previous year data) instead of resetting to the first visible data point.
              // double basePrice = previousClose;
              // if (widget.benchmarkChartDateSpanFilter == ChartDateSpan.ytd) {
              //   var lastYearData = list.lastWhereOrNull(
              //       (e) => (e['date'] as DateTime).isBefore(newYearsDay));
              //   if (lastYearData != null) {
              //     basePrice = lastYearData['close'] as double;
              //   }
              // }

              if (cutoff != null) {
                list = list
                    .where((e) => (e['date'] as DateTime).isAfter(cutoff!))
                    .toList();
              }

              double basePrice = previousClose;
              // if (cutoff != null &&
              //     list.isNotEmpty &&
              //     widget.benchmarkChartDateSpanFilter != ChartDateSpan.ytd) {
              if (cutoff != null && list.isNotEmpty) {
                basePrice = list.first['close'] as double;
              }

              var result = list.map((e) {
                var close = e['close'] as double?;
                return {
                  'date': e['date'],
                  'value': close == null ? 0.0 : (close / basePrice) - 1.0,
                };
              }).toList();

              if (widget.benchmarkChartDateSpanFilter == ChartDateSpan.ytd) {
                result.insert(0, {'date': newYearsDay, 'value': 0.0});
              }
              return result;
            }

            var seriesDatasp500 = processMarketData(sp500, sp500PreviousClose);
            var seriesDatanasdaq =
                processMarketData(nasdaq, nasdaqPreviousClose);
            var seriesDatadow = processMarketData(dow, dowPreviousClose);
            var seriesDatarussell2000 =
                russell2000 != null && russell2000PreviousClose != null
                    ? processMarketData(russell2000, russell2000PreviousClose)
                    : <Map<String, dynamic>>[];

            var seriesOpenportfolio =
                portfolioHistoricals.equityHistoricals[0].adjustedOpenEquity;
            var seriesDataportfolio = portfolioHistoricals.equityHistoricals
                .mapIndexed((index, e) => {
                      'date': e.beginsAt,
                      'value': e.adjustedCloseEquity! / seriesOpenportfolio! - 1
                    })
                .toList();

            final allValues = <double>[
              ...seriesDatasp500
                  .map((e) => (e['value'] as num?)?.toDouble() ?? 0.0),
              ...seriesDatanasdaq
                  .map((e) => (e['value'] as num?)?.toDouble() ?? 0.0),
              ...seriesDatadow
                  .map((e) => (e['value'] as num?)?.toDouble() ?? 0.0),
              ...seriesDatarussell2000
                  .map((e) => (e['value'] as num?)?.toDouble() ?? 0.0),
              ...seriesDataportfolio
                  .map((e) => (e['value'] as num?)?.toDouble() ?? 0.0),
            ];
            var extents = charts.NumericExtents.fromValues(allValues);
            extents = charts.NumericExtents(extents.min - (extents.width * 0.1),
                extents.max + (extents.width * 0.1));
            var brightness = MediaQuery.of(context).platformBrightness;
            var axisLabelColor = charts.MaterialPalette.gray.shade500;
            if (brightness == Brightness.light) {
              axisLabelColor = charts.MaterialPalette.gray.shade700;
            }
            var chartSelectionStore =
                Provider.of<ChartSelectionStore>(context, listen: false);

            WidgetsBinding.instance.addPostFrameCallback((_) {
              chartSelectionStore.selectionChanged(MapEntry(
                  seriesDataportfolio.last['date'] as DateTime,
                  seriesDataportfolio.last['value'] as double));
            });
            TimeSeriesChart marketIndicesChart = TimeSeriesChart(
              [
                charts.Series<dynamic, DateTime>(
                  id: 'Portfolio',
                  colorFn: (_, index) => charts.ColorUtil.fromDartColor(
                      Colors.accents[0 % Colors.accents.length]),
                  domainFn: (dynamic data, _) => data['date'],
                  measureFn: (dynamic data, index) => data['value'],
                  data: seriesDataportfolio,
                ),
                charts.Series<dynamic, DateTime>(
                  id: 'S&P 500',
                  colorFn: (_, index) => charts.ColorUtil.fromDartColor(
                      Colors.accents[4 % Colors.accents.length]),
                  domainFn: (dynamic data, _) => data['date'],
                  measureFn: (dynamic data, index) => data['value'],
                  data: seriesDatasp500,
                ),
                charts.Series<dynamic, DateTime>(
                  id: 'Nasdaq',
                  colorFn: (_, index) => charts.ColorUtil.fromDartColor(
                      Colors.accents[2 % Colors.accents.length]),
                  domainFn: (dynamic data, _) => data['date'],
                  measureFn: (dynamic data, index) => data['value'],
                  data: seriesDatanasdaq,
                ),
                charts.Series<dynamic, DateTime>(
                  id: 'Dow 30',
                  colorFn: (_, index) => charts.ColorUtil.fromDartColor(
                      Colors.accents[6 % Colors.accents.length]),
                  domainFn: (dynamic data, _) => data['date'],
                  measureFn: (dynamic data, index) => data['value'],
                  data: seriesDatadow,
                ),
                if (seriesDatarussell2000.isNotEmpty)
                  charts.Series<dynamic, DateTime>(
                    id: 'Russell 2000',
                    colorFn: (_, index) => charts.ColorUtil.fromDartColor(
                        Colors.accents[8 % Colors.accents.length]),
                    domainFn: (dynamic data, _) => data['date'],
                    measureFn: (dynamic data, index) => data['value'],
                    data: seriesDatarussell2000,
                  ),
              ],
              animate: animateChart,
              zeroBound: false,
              primaryMeasureAxis: charts.PercentAxisSpec(
                  viewport: extents,
                  renderSpec: charts.GridlineRendererSpec(
                      labelStyle: charts.TextStyleSpec(color: axisLabelColor))),
              seriesLegend: charts.SeriesLegend(
                horizontalFirst: true,
                desiredMaxColumns: 2,
                cellPadding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                position: charts.BehaviorPosition.top,
                showMeasures: true,
                measureFormatter: (measure) =>
                    measure != null ? formatPercentage.format(measure) : '',
              ),
              onSelected: (charts.SelectionModel? model) {
                chartSelectionStore.selectionChanged(model != null
                    ? MapEntry(model.selectedDatum.first.datum['date'],
                        model.selectedDatum.first.datum['value'])
                    : null);
              },
              initialSelection: charts.InitialSelection(selectedDataConfig: [
                charts.SeriesDatumConfig<DateTime>(
                    'Portfolio', seriesDataportfolio.last['date'] as DateTime),
                charts.SeriesDatumConfig<DateTime>(
                    'S&P 500', seriesDatasp500.last['date'] as DateTime),
                charts.SeriesDatumConfig<DateTime>(
                    'Nasdaq', seriesDatanasdaq.last['date'] as DateTime),
                charts.SeriesDatumConfig<DateTime>(
                    'Dow 30', seriesDatadow.last['date'] as DateTime),
                if (seriesDatarussell2000.isNotEmpty)
                  charts.SeriesDatumConfig<DateTime>('Russell 2000',
                      seriesDatarussell2000.last['date'] as DateTime)
              ], shouldPreserveSelectionOnDraw: true),
              symbolRenderer: TextSymbolRenderer(() {
                return chartSelectionStore.selection != null
                    ? formatCompactDateTimeWithHour.format(
                        (chartSelectionStore.selection as MapEntry)
                            .key
                            .toLocal())
                    : '';
              }, marginBottom: 16),
            );
            return Column(
              children: [
                ListTile(
                  title: const Text(
                    "Performance",
                    style:
                        TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "Compare market indices and benchmarks (${convertChartSpanFilter(widget.benchmarkChartDateSpanFilter).toUpperCase()})",
                  ),
                ),
                SizedBox(
                    height: 56,
                    child: ListView(
                      padding: const EdgeInsets.all(5.0),
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildChip('YTD', ChartDateSpan.ytd),
                        _buildChip('1Y', ChartDateSpan.year),
                        _buildChip('2Y', ChartDateSpan.year_2),
                        _buildChip('3Y', ChartDateSpan.year_3),
                        _buildChip('5Y', ChartDateSpan.year_5),
                      ],
                    )),
                widget.isFullScreen
                    ? Expanded(
                        child: Padding(
                          padding:
                              const EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 10.0),
                          child: marketIndicesChart,
                        ),
                      )
                    : Stack(
                        children: [
                          SizedBox(
                              height: 380,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    10.0, 10.0, 10.0, 10.0),
                                child: marketIndicesChart,
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
                                        FullScreenPerformanceChartWidget(
                                      futureMarketIndexHistoricalsSp500: widget
                                          .futureMarketIndexHistoricalsSp500,
                                      futureMarketIndexHistoricalsNasdaq: widget
                                          .futureMarketIndexHistoricalsNasdaq,
                                      futureMarketIndexHistoricalsDow: widget
                                          .futureMarketIndexHistoricalsDow,
                                      futureMarketIndexHistoricalsRussell2000:
                                          widget
                                              .futureMarketIndexHistoricalsRussell2000,
                                      futurePortfolioHistoricalsYear:
                                          widget.futurePortfolioHistoricalsYear,
                                      benchmarkChartDateSpanFilter:
                                          widget.benchmarkChartDateSpanFilter,
                                      onFilterChanged: widget.onFilterChanged,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
              ],
            );
          }
        }
        debugPrint("${snapshot.error}");

        return const SizedBox();
      },
    );
  }

  Widget _buildChip(String label, ChartDateSpan span) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: ChoiceChip(
        label: Text(label),
        selected: widget.benchmarkChartDateSpanFilter == span,
        onSelected: (bool value) {
          if (value) {
            widget.onFilterChanged(span);
          }
        },
      ),
    );
  }
}
