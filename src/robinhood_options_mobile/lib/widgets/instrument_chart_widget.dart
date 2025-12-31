import 'dart:math' as math;
import 'package:candlesticks/candlesticks.dart';
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
import 'package:robinhood_options_mobile/widgets/full_screen_instrument_chart_widget.dart';

class InstrumentChartWidget extends StatefulWidget {
  final Instrument instrument;
  final ChartDateSpan chartDateSpanFilter;
  final Bounds chartBoundsFilter;
  final Function(ChartDateSpan, Bounds) onFilterChanged;
  final bool isFullScreen;

  const InstrumentChartWidget({
    super.key,
    required this.instrument,
    required this.chartDateSpanFilter,
    required this.chartBoundsFilter,
    required this.onFilterChanged,
    this.isFullScreen = false,
  });

  @override
  State<InstrumentChartWidget> createState() => _InstrumentChartWidgetState();
}

class _InstrumentChartWidgetState extends State<InstrumentChartWidget> {
  TimeSeriesChart? chart;
  InstrumentHistorical? selection;
  InstrumentHistoricals? _lastValidHistoricals;
  bool _showCandles = false;

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
          ];
          var extents = charts.NumericExtents.fromValues(
              seriesList[0].data.map((e) => e.openPrice!));
          extents = charts.NumericExtents(extents.min - (extents.width * 0.1),
              extents.max + (extents.width * 0.1));
          var provider = Provider.of<InstrumentHistoricalsSelectionStore>(
              context,
              listen: false);

          chart = TimeSeriesChart(seriesList, open: open, close: close,
              onSelected: (charts.SelectionModel<DateTime>? historical) {
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

          return Column(
            children: [
              widget.isFullScreen
                  ? Expanded(
                      child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Stack(
                        children: [
                          _showCandles
                              ? Candlesticks(
                                  candles: _generateCandles(
                                      _lastValidHistoricals!.historicals),
                                )
                              : chart!,
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
                            height: 340,
                            child: Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: chart,
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
                                      FullScreenInstrumentChartWidget(
                                    instrument: widget.instrument,
                                    chartDateSpanFilter:
                                        widget.chartDateSpanFilter,
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
          );
        }
        return Column(
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
        );
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

  List<Candle> _generateCandles(List<InstrumentHistorical> historicals) {
    if (historicals.isEmpty) return [];

    // Determine bucket size based on total points to get roughly 60 candles
    int bucketSize = (historicals.length / 60).ceil();
    if (bucketSize < 1) {
      bucketSize = 1;
    }

    List<Candle> candles = [];
    for (int i = 0; i < historicals.length; i += bucketSize) {
      int end = (i + bucketSize < historicals.length)
          ? i + bucketSize
          : historicals.length;
      var chunk = historicals.sublist(i, end);

      double open = chunk.first.openPrice ?? 0;
      double close = chunk.last.closePrice ?? 0;

      // Calculate High/Low from the chunk
      double high = chunk
          .map((e) => math.max(e.highPrice ?? 0, e.openPrice ?? 0))
          .reduce(math.max);
      double low = chunk
          .map((e) => math.min(e.lowPrice ?? 0, e.openPrice ?? 0))
          .reduce(math.min);
      double volume =
          chunk.map((e) => e.volume.toDouble()).reduce((a, b) => a + b);

      // Ensure values are positive to avoid log10(0) errors in candlesticks package
      const double minPrice = 0.01;
      if (high < minPrice) high = minPrice;
      if (low < minPrice) low = minPrice;
      if (open < minPrice) open = minPrice;
      if (close < minPrice) close = minPrice;

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
