import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_historical.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals_selection_store.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals_store.dart';
import 'package:robinhood_options_mobile/widgets/chart_time_series_widget.dart';

class InstrumentChartWidget extends StatefulWidget {
  final Instrument instrument;
  final ChartDateSpan chartDateSpanFilter;
  final Bounds chartBoundsFilter;
  final Function(ChartDateSpan, Bounds) onFilterChanged;

  const InstrumentChartWidget({
    super.key,
    required this.instrument,
    required this.chartDateSpanFilter,
    required this.chartBoundsFilter,
    required this.onFilterChanged,
  });

  @override
  State<InstrumentChartWidget> createState() => _InstrumentChartWidgetState();
}

class _InstrumentChartWidgetState extends State<InstrumentChartWidget> {
  TimeSeriesChart? chart;
  InstrumentHistorical? selection;
  InstrumentHistoricals? _lastValidHistoricals;

  @override
  Widget build(BuildContext context) {
    return Consumer<InstrumentHistoricalsStore>(
      builder: (context, instrumentHistoricalsStore, child) {
        var currentHistoricals = instrumentHistoricalsStore.items
            .firstWhereOrNull((element) =>
                element.symbol == widget.instrument.symbol &&
                element.span ==
                    convertChartSpanFilter(widget.chartDateSpanFilter) &&
                element.bounds ==
                    convertChartBoundsFilter(widget.chartBoundsFilter));

        if (currentHistoricals != null) {
          widget.instrument.instrumentHistoricalsObj = currentHistoricals;
          _lastValidHistoricals = currentHistoricals;
        } else if (_lastValidHistoricals != null &&
            _lastValidHistoricals!.symbol != widget.instrument.symbol) {
          _lastValidHistoricals = null;
        }

        if (_lastValidHistoricals != null &&
            _lastValidHistoricals!.historicals.isNotEmpty) {
          InstrumentHistorical? firstHistorical;
          InstrumentHistorical? lastHistorical;
          double open = 0;
          double close = 0;
          double changeInPeriod = 0;
          double changePercentInPeriod = 0;

          firstHistorical = _lastValidHistoricals!.historicals[0];
          lastHistorical = _lastValidHistoricals!
              .historicals[_lastValidHistoricals!.historicals.length - 1];
          open = firstHistorical.openPrice!;
          close = lastHistorical.closePrice!;
          changeInPeriod = close - open;
          changePercentInPeriod = close / open - 1;

          var brightness = MediaQuery.of(context).platformBrightness;
          var textColor = Theme.of(context).colorScheme.surface;
          if (brightness == Brightness.dark) {
            textColor = Colors.grey.shade200;
          } else {
            textColor = Colors.grey.shade800;
          }

          List<charts.Series<InstrumentHistorical, DateTime>> seriesList = [
            charts.Series<InstrumentHistorical, DateTime>(
              id: 'Open',
              colorFn: (_, __) => charts.ColorUtil.fromDartColor(
                  Theme.of(context).colorScheme.primary),
              domainFn: (InstrumentHistorical history, _) => history.beginsAt!,
              measureFn: (InstrumentHistorical history, _) => history.openPrice,
              data: _lastValidHistoricals!.historicals,
            ),
            charts.Series<InstrumentHistorical, DateTime>(
              id: 'Close',
              colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
              domainFn: (InstrumentHistorical history, _) => history.beginsAt!,
              measureFn: (InstrumentHistorical history, _) =>
                  history.closePrice,
              data: _lastValidHistoricals!.historicals,
            ),
            charts.Series<InstrumentHistorical, DateTime>(
                id: 'Volume',
                colorFn: (_, __) => charts.MaterialPalette.cyan.shadeDefault,
                domainFn: (InstrumentHistorical history, _) =>
                    history.beginsAt!,
                measureFn: (InstrumentHistorical history, _) => history.volume,
                data: _lastValidHistoricals!.historicals),
            charts.Series<InstrumentHistorical, DateTime>(
              id: 'Low',
              colorFn: (_, __) => charts.MaterialPalette.red.shadeDefault,
              domainFn: (InstrumentHistorical history, _) => history.beginsAt!,
              measureFn: (InstrumentHistorical history, _) => history.lowPrice,
              data: _lastValidHistoricals!.historicals,
            ),
            charts.Series<InstrumentHistorical, DateTime>(
              id: 'High',
              colorFn: (_, __) => charts.MaterialPalette.green.shadeDefault,
              domainFn: (InstrumentHistorical history, _) => history.beginsAt!,
              measureFn: (InstrumentHistorical history, _) => history.highPrice,
              data: _lastValidHistoricals!.historicals,
            ),
          ];
          var extents = charts.NumericExtents.fromValues(
              seriesList[0].data.map((e) => e.openPrice!));
          extents = charts.NumericExtents(extents.min - (extents.width * 0.1),
              extents.max + (extents.width * 0.1));
          var provider = Provider.of<InstrumentHistoricalsSelectionStore>(
              context,
              listen: false);

          chart = TimeSeriesChart(seriesList,
              open: open,
              close: close,
              seriesLegend: charts.SeriesLegend(
                horizontalFirst: true,
                position: charts.BehaviorPosition.top,
                defaultHiddenSeries: const ["Close", "Volume", "Low", "High"],
                showMeasures: true,
                measureFormatter: (measure) =>
                    measure != null ? formatCurrency.format(measure) : '',
              ), onSelected: (charts.SelectionModel<DateTime>? historical) {
            provider.selectionChanged(historical?.selectedDatum.first.datum);
          },
              symbolRenderer: TextSymbolRenderer(() {
                return provider.selection != null
                    ? formatCompactDateTimeWithHour.format(
                        (provider.selection as InstrumentHistorical)
                            .beginsAt!
                            .toLocal())
                    : '0';
              }, marginBottom: 16),
              zeroBound: false,
              viewport: extents);

          return SliverToBoxAdapter(
              child: Column(
            children: [
              SizedBox(
                  height: 340,
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: chart,
                  )),
              Consumer<InstrumentHistoricalsSelectionStore>(
                  builder: (context, value, child) {
                selection = value.selection;
                if (selection != null) {
                  changeInPeriod = selection!.closePrice! - open;
                  changePercentInPeriod = selection!.closePrice! / open - 1;
                } else {
                  changeInPeriod = close - open;
                  changePercentInPeriod = close / open - 1;
                }
                return SizedBox(
                    child: Center(
                        child: Padding(
                  padding: const EdgeInsets.all(summaryEgdeInset),
                  child: Column(
                    children: [
                      Wrap(
                        children: [
                          Text(
                              formatCurrency.format(selection != null
                                  ? selection!.closePrice
                                  : close),
                              style: TextStyle(fontSize: 20, color: textColor)),
                          Container(
                            width: 10,
                          ),
                          Icon(
                            changeInPeriod > 0
                                ? Icons.trending_up
                                : (changeInPeriod < 0
                                    ? Icons.trending_down
                                    : Icons.trending_flat),
                            color: (changeInPeriod > 0
                                ? Colors.green
                                : (changeInPeriod < 0
                                    ? Colors.red
                                    : Colors.grey)),
                          ),
                          Container(
                            width: 2,
                          ),
                          Text(
                              formatPercentage
                                  .format(changePercentInPeriod.abs()),
                              style:
                                  TextStyle(fontSize: 20.0, color: textColor)),
                          Container(
                            width: 10,
                          ),
                          Text(
                              "${changeInPeriod > 0 ? "+" : changeInPeriod < 0 ? "-" : ""}${formatCurrency.format(changeInPeriod.abs())}",
                              style:
                                  TextStyle(fontSize: 20.0, color: textColor)),
                        ],
                      ),
                      Text(
                        '${formatMediumDateTime.format(firstHistorical!.beginsAt!.toLocal())} - ${formatMediumDateTime.format(selection != null ? selection!.beginsAt!.toLocal() : lastHistorical!.beginsAt!.toLocal())}',
                        style: TextStyle(fontSize: 10, color: textColor),
                      ),
                    ],
                  ),
                )));
              }),
              SizedBox(
                  height: 56,
                  child: ListView.builder(
                    key: const PageStorageKey<String>('instrumentChartFilters'),
                    padding: const EdgeInsets.all(5.0),
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      return Row(children: [
                        _buildDateSpanChip(ChartDateSpan.day, '1D'),
                        _buildDateSpanChip(ChartDateSpan.week, '1W'),
                        _buildDateSpanChip(ChartDateSpan.month, '1M'),
                        _buildDateSpanChip(ChartDateSpan.month_3, '3M'),
                        _buildDateSpanChip(ChartDateSpan.year, '1Y'),
                        _buildDateSpanChip(ChartDateSpan.year_5, '5Y'),
                        // Container(width: 10),
                        // _buildBoundsChip(Bounds.regular, 'Regular Hours'),
                        // _buildBoundsChip(Bounds.trading, 'Trading Hours'),
                      ]);
                    },
                    itemCount: 1,
                  ))
            ],
          ));
        }
        return SliverToBoxAdapter(
            child: Column(
          children: [
            const SizedBox(
                height: 340,
                child: Center(child: CircularProgressIndicator.adaptive())),
            SizedBox(
                height: 56,
                child: ListView.builder(
                  key: const PageStorageKey<String>('instrumentChartFilters'),
                  padding: const EdgeInsets.all(5.0),
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (context, index) {
                    return Row(children: [
                      _buildDateSpanChip(ChartDateSpan.day, '1D'),
                      _buildDateSpanChip(ChartDateSpan.week, '1W'),
                      _buildDateSpanChip(ChartDateSpan.month, '1M'),
                      _buildDateSpanChip(ChartDateSpan.month_3, '3M'),
                      _buildDateSpanChip(ChartDateSpan.year, '1Y'),
                      _buildDateSpanChip(ChartDateSpan.year_5, '5Y'),
                      // Container(width: 10),
                      // _buildBoundsChip(Bounds.regular, 'Regular Hours'),
                      // _buildBoundsChip(Bounds.trading, 'Trading Hours'),
                    ]);
                  },
                  itemCount: 1,
                ))
          ],
        ));
      },
    );
  }

  Widget _buildDateSpanChip(ChartDateSpan span, String label) {
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

  Widget _buildBoundsChip(Bounds bounds, String label) {
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
