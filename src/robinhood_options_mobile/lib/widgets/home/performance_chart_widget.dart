import 'package:collection/collection.dart';
import 'package:community_charts_common/community_charts_common.dart' as common;
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

class PerformanceChartWidget extends StatefulWidget {
  final Future<dynamic>? futureMarketIndexHistoricalsSp500;
  final Future<dynamic>? futureMarketIndexHistoricalsNasdaq;
  final Future<dynamic>? futureMarketIndexHistoricalsDow;
  final Future<dynamic>? futureMarketIndexHistoricalsRussell2000;
  final Future<PortfolioHistoricals>? futurePortfolioHistoricalsYear;
  final ChartDateSpan benchmarkChartDateSpanFilter;
  final Function(ChartDateSpan) onFilterChanged;
  final bool isFullScreen;
  final String? selectedBenchmark;
  final Future<dynamic>? futureCustomBenchmark;
  final String? customBenchmarkSymbol;

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
    this.selectedBenchmark,
    this.futureCustomBenchmark,
    this.customBenchmarkSymbol,
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
            : Future.value(null),
        widget.futureCustomBenchmark != null
            ? widget.futureCustomBenchmark as Future
            : Future.value(null),
      ]),
      builder: (context, snapshot) {
        if (snapshot.hasData &&
            snapshot.connectionState == ConnectionState.done) {
          var sp500 = snapshot.data![0];
          var nasdaq = snapshot.data![1];
          var dow = snapshot.data![2];
          var russell2000 = snapshot.data![3];
          var portfolioHistoricals = snapshot.data![4] as PortfolioHistoricals?;
          var customBenchmarkData = snapshot.data![5];
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

            Map<String, dynamic>? chartResult(dynamic data) {
              final chart = data is Map ? data['chart'] : null;
              final results = chart is Map ? chart['result'] : null;
              if (results is List &&
                results.isNotEmpty &&
                results.first is Map) {
              return Map<String, dynamic>.from(results.first as Map);
              }
              return null;
            }

            final sp500Result = chartResult(sp500);
            final nasdaqResult = chartResult(nasdaq);
            final dowResult = chartResult(dow);
            final russellResult = chartResult(russell2000);
            final customResult = chartResult(customBenchmarkData);

            final regularsp500 =
              sp500Result?['meta']?['currentTradingPeriod']?['regular'];
            final sp500PreviousClose =
              (sp500Result?['meta']?['chartPreviousClose'] as num?)?.toDouble() ??
                0.0;
            final nasdaqPreviousClose =
              (nasdaqResult?['meta']?['chartPreviousClose'] as num?)?.toDouble() ??
                0.0;
            final dowPreviousClose =
              (dowResult?['meta']?['chartPreviousClose'] as num?)?.toDouble() ??
                0.0;
            var russell2000PreviousClose = russell2000 != null
              ? (russellResult?['meta']?['chartPreviousClose'] as num?)
                ?.toDouble()
                : null;
            var customBenchmarkPreviousClose = customBenchmarkData != null
              ? (customResult?['meta']?['chartPreviousClose'] as num?)
                ?.toDouble()
                : null;

            final regularStart =
              (regularsp500?['start'] as num?)?.toInt() ?? 0;
            final regularEnd =
              (regularsp500?['end'] as num?)?.toInt() ?? 0;
            var enddiffsp500 = regularEnd - regularStart;

            DateTime? cutoff;
            switch (widget.benchmarkChartDateSpanFilter) {
              case ChartDateSpan.hour:
                cutoff = now.subtract(const Duration(hours: 1));
                break;
              case ChartDateSpan.day:
                cutoff = now.subtract(const Duration(days: 1));
                break;
              case ChartDateSpan.week:
                cutoff = now.subtract(const Duration(days: 7));
                break;
              case ChartDateSpan.month:
              case ChartDateSpan.rolling_30:
                cutoff = now.subtract(const Duration(days: 30));
                break;
              case ChartDateSpan.rolling_60:
                cutoff = now.subtract(const Duration(days: 60));
                break;
              case ChartDateSpan.month_3:
              case ChartDateSpan.rolling_90:
                cutoff = now.subtract(const Duration(days: 90));
                break;
              case ChartDateSpan.ytd:
                cutoff = newYearsDay.subtract(const Duration(milliseconds: 1));
                break;
              case ChartDateSpan.year:
                cutoff = now.subtract(const Duration(days: 365));
                break;
              case ChartDateSpan.year_2:
                cutoff = now.subtract(const Duration(days: 365 * 2));
                break;
              case ChartDateSpan.year_3:
                cutoff = now.subtract(const Duration(days: 365 * 3));
                break;
              case ChartDateSpan.year_5:
                cutoff = now.subtract(const Duration(days: 365 * 5));
                break;
              case ChartDateSpan.all:
                cutoff = null;
                break;
            }

            List<Map<String, dynamic>> processMarketData(
                dynamic data, double previousClose) {
              if (data == null ||
                  data['chart'] == null ||
                  data['chart']['result'] == null ||
                  (data['chart']['result'] as List).isEmpty) {
                return <Map<String, dynamic>>[];
              }
              var result0 = data['chart']['result'][0];
              if (result0['timestamp'] == null ||
                  result0['indicators']?['adjclose'] == null ||
                  (result0['indicators']['adjclose'] as List).isEmpty ||
                  result0['indicators']['adjclose'][0]['adjclose'] == null) {
                return <Map<String, dynamic>>[];
              }
              var timestamps = (result0['timestamp'] as List);
              var adjcloses =
                  (result0['indicators']['adjclose'][0]['adjclose'] as List);

              var list = <Map<String, dynamic>>[];
              for (var index = 0;
                  index < timestamps.length && index < adjcloses.length;
                  index++) {
                final numerator = adjcloses[index];
                final close = (numerator as num?)?.toDouble();
                if (close != null) {
                  list.add({
                    'date': DateTime.fromMillisecondsSinceEpoch(
                        (((timestamps[index] as num) + enddiffsp500) * 1000)
                            .toInt()),
                    'close': close
                  });
                }
              }

              if (cutoff != null) {
                list = list
                    .where((e) => (e['date'] as DateTime).isAfter(cutoff!))
                    .toList();
              }

              if (list.isEmpty) return <Map<String, dynamic>>[];

              double basePrice = previousClose;
              if (cutoff != null && list.isNotEmpty) {
                basePrice = list.first['close'] as double;
              }

              var result = list.map((e) {
                var close = e['close'] as double?;
                return {
                  'date': e['date'],
                  'value': close == null || basePrice == 0.0
                      ? 0.0
                      : (close / basePrice) - 1.0,
                };
              }).toList();

              if (widget.benchmarkChartDateSpanFilter == ChartDateSpan.ytd &&
                  result.isNotEmpty) {
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
            var seriesDataCustom = customBenchmarkData != null &&
                    customBenchmarkPreviousClose != null
                ? processMarketData(
                    customBenchmarkData, customBenchmarkPreviousClose)
                : <Map<String, dynamic>>[];

            var equityList = portfolioHistoricals.equityHistoricals
                .where((e) =>
                    e.beginsAt != null &&
                    (e.adjustedCloseEquity != null || e.closeEquity != null))
                .toList();

            if (cutoff != null) {
              equityList = equityList
                  .where((e) => e.beginsAt!.isAfter(cutoff!))
                  .toList();
            }

            double seriesOpenportfolio = 0.0;
            if (equityList.isNotEmpty) {
              seriesOpenportfolio = equityList.first.adjustedOpenEquity ??
                  equityList.first.openEquity ??
                  equityList.first.adjustedCloseEquity ??
                  equityList.first.closeEquity ??
                  0.0;
              if (seriesOpenportfolio == 0.0) {
                seriesOpenportfolio = equityList.first.adjustedCloseEquity ??
                    equityList.first.closeEquity ??
                    1.0;
              }
            }

            var seriesDataportfolio = equityList
                .map((e) {
                  final close = e.adjustedCloseEquity ?? e.closeEquity ?? 0.0;
                  return {
                    'date': e.beginsAt,
                    'value': seriesOpenportfolio > 0.0
                        ? (close / seriesOpenportfolio) - 1.0
                        : 0.0,
                  };
                })
                .toList();

            if (widget.benchmarkChartDateSpanFilter == ChartDateSpan.ytd &&
                seriesDataportfolio.isNotEmpty) {
              seriesDataportfolio.insert(0, {'date': newYearsDay, 'value': 0.0});
            }

            final allValues = <double>[
              ...seriesDatasp500
                  .map((e) => (e['value'] as num?)?.toDouble() ?? 0.0),
              ...seriesDatanasdaq
                  .map((e) => (e['value'] as num?)?.toDouble() ?? 0.0),
              ...seriesDatadow
                  .map((e) => (e['value'] as num?)?.toDouble() ?? 0.0),
              ...seriesDatarussell2000
                  .map((e) => (e['value'] as num?)?.toDouble() ?? 0.0),
              ...seriesDataCustom
                  .map((e) => (e['value'] as num?)?.toDouble() ?? 0.0),
              ...seriesDataportfolio
                  .map((e) => (e['value'] as num?)?.toDouble() ?? 0.0),
            ];
            var extents = allValues.isNotEmpty
                ? charts.NumericExtents.fromValues(allValues)
                : const charts.NumericExtents(-0.1, 0.1);
            extents = charts.NumericExtents(extents.min - (extents.width * 0.1),
                extents.max + (extents.width * 0.1));
            var brightness = Theme.of(context).brightness;
            var axisLabelColor = charts.MaterialPalette.gray.shade500;
            if (brightness == Brightness.light) {
              axisLabelColor = charts.MaterialPalette.gray.shade700;
            }
            var chartSelectionStore =
                Provider.of<ChartSelectionStore>(context, listen: false);

            if (seriesDataportfolio.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                chartSelectionStore.selectionChanged(MapEntry(
                    seriesDataportfolio.last['date'] as DateTime,
                    seriesDataportfolio.last['value'] as double));
              });
            }

            final benchmarkMap = {
              'SPY': 'S&P 500',
              'QQQ': 'Nasdaq',
              'DIA': 'Dow 30',
              'IWM': 'Russell 2000',
            };
            var selectedSeriesId = widget.selectedBenchmark != null
                ? benchmarkMap[widget.selectedBenchmark]
                : null;
            if (widget.selectedBenchmark != null &&
                widget.customBenchmarkSymbol == widget.selectedBenchmark) {
              selectedSeriesId = widget.customBenchmarkSymbol;
            }

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
                if (selectedSeriesId == null || selectedSeriesId == 'S&P 500')
                  charts.Series<dynamic, DateTime>(
                    id: 'S&P 500',
                    colorFn: (_, index) => charts.ColorUtil.fromDartColor(
                        Colors.accents[4 % Colors.accents.length]),
                    domainFn: (dynamic data, _) => data['date'],
                    measureFn: (dynamic data, index) => data['value'],
                    data: seriesDatasp500,
                  ),
                if (selectedSeriesId == null || selectedSeriesId == 'Nasdaq')
                  charts.Series<dynamic, DateTime>(
                    id: 'Nasdaq',
                    colorFn: (_, index) => charts.ColorUtil.fromDartColor(
                        Colors.accents[2 % Colors.accents.length]),
                    domainFn: (dynamic data, _) => data['date'],
                    measureFn: (dynamic data, index) => data['value'],
                    data: seriesDatanasdaq,
                  ),
                if (selectedSeriesId == null || selectedSeriesId == 'Dow 30')
                  charts.Series<dynamic, DateTime>(
                    id: 'Dow 30',
                    colorFn: (_, index) => charts.ColorUtil.fromDartColor(
                        Colors.accents[6 % Colors.accents.length]),
                    domainFn: (dynamic data, _) => data['date'],
                    measureFn: (dynamic data, index) => data['value'],
                    data: seriesDatadow,
                  ),
                if (seriesDatarussell2000.isNotEmpty &&
                    (selectedSeriesId == null ||
                        selectedSeriesId == 'Russell 2000'))
                  charts.Series<dynamic, DateTime>(
                    id: 'Russell 2000',
                    colorFn: (_, index) => charts.ColorUtil.fromDartColor(
                        brightness == Brightness.light
                            ? Colors.accents[
                                5 % Colors.accents.length] // Colors.brown
                            : Colors.accents[8 % Colors.accents.length]),
                    domainFn: (dynamic data, _) => data['date'],
                    measureFn: (dynamic data, index) => data['value'],
                    data: seriesDatarussell2000,
                  ),
                if (seriesDataCustom.isNotEmpty &&
                    (selectedSeriesId == null ||
                        selectedSeriesId == widget.customBenchmarkSymbol))
                  charts.Series<dynamic, DateTime>(
                    id: widget.customBenchmarkSymbol!,
                    colorFn: (_, index) => charts.ColorUtil.fromDartColor(
                        brightness == Brightness.light
                            ? Colors.accents[
                                10 % Colors.accents.length] // Another color
                            : Colors.accents[3 % Colors.accents.length]),
                    domainFn: (dynamic data, _) => data['date'],
                    measureFn: (dynamic data, index) => data['value'],
                    data: seriesDataCustom,
                  ),
              ],
              animate: animateChart,
              zeroBound: false,
              selectionMode: common.SelectionMode.selectOverlapping,
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
                if (seriesDataportfolio.isNotEmpty)
                  charts.SeriesDatumConfig<DateTime>(
                      'Portfolio', seriesDataportfolio.last['date'] as DateTime),
                if ((selectedSeriesId == null || selectedSeriesId == 'S&P 500') &&
                    seriesDatasp500.isNotEmpty)
                  charts.SeriesDatumConfig<DateTime>(
                      'S&P 500', seriesDatasp500.last['date'] as DateTime),
                if ((selectedSeriesId == null || selectedSeriesId == 'Nasdaq') &&
                    seriesDatanasdaq.isNotEmpty)
                  charts.SeriesDatumConfig<DateTime>(
                      'Nasdaq', seriesDatanasdaq.last['date'] as DateTime),
                if ((selectedSeriesId == null || selectedSeriesId == 'Dow 30') &&
                    seriesDatadow.isNotEmpty)
                  charts.SeriesDatumConfig<DateTime>(
                      'Dow 30', seriesDatadow.last['date'] as DateTime),
                if (seriesDatarussell2000.isNotEmpty &&
                    (selectedSeriesId == null ||
                        selectedSeriesId == 'Russell 2000'))
                  charts.SeriesDatumConfig<DateTime>('Russell 2000',
                      seriesDatarussell2000.last['date'] as DateTime),
                if (seriesDataCustom.isNotEmpty &&
                    (selectedSeriesId == null ||
                        selectedSeriesId == widget.customBenchmarkSymbol))
                  charts.SeriesDatumConfig<DateTime>(
                      widget.customBenchmarkSymbol!,
                      seriesDataCustom.last['date'] as DateTime),
              ], shouldPreserveSelectionOnDraw: true),
              symbolRenderer: TextSymbolRenderer(() {
                return chartSelectionStore.selection != null
                    ? formatCompactDateTimeWithHour.format(
                        (chartSelectionStore.selection as MapEntry)
                            .key
                            .toLocal())
                    : '';
              },
                  marginBottom: 16,
                  backgroundColor: Theme.of(context).colorScheme.inverseSurface,
                  textColor: Theme.of(context).colorScheme.onInverseSurface),
            );
            return widget.isFullScreen
                ? Expanded(
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 10.0),
                      child: marketIndicesChart,
                    ),
                  )
                : SizedBox(
                    height: 380,
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 10.0),
                      child: marketIndicesChart,
                    ));
          }
        }
        debugPrint("${snapshot.error}");

        return const SizedBox();
      },
    );
  }
}
