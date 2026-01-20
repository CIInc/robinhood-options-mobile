import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:candlesticks/candlesticks.dart';
import 'package:collection/collection.dart';
import 'package:community_charts_common/community_charts_common.dart' as common;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_historical.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals_selection_store.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals_store.dart';
import 'package:robinhood_options_mobile/widgets/chart_time_series_widget.dart';
import 'package:robinhood_options_mobile/widgets/full_screen_instrument_chart_widget.dart';
import 'package:robinhood_options_mobile/utils/technical_indicators.dart';

const String _indicatorRendererId = 'indicatorLine';

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
  bool _showVolume = true;
  final Set<_OverlayIndicator> _activeIndicators = {
    _OverlayIndicator.sma20,
    _OverlayIndicator.sma50,
  };
  bool _showIndicatorLegend = true;
  bool _showTechnicalSummary = true;

  // Cached indicator values
  final Map<_OverlayIndicator, List<double?>> _indicatorValues = {};
  final Map<_OverlayIndicator, List<_IndicatorPoint>> _indicatorPoints = {};

  // Cached Bollinger Bands (dual line)
  List<double?> _bbUpperValues = [];
  List<double?> _bbLowerValues = [];
  List<_IndicatorPoint> _bbUpperPoints = [];
  List<_IndicatorPoint> _bbLowerPoints = [];

  InstrumentHistoricals? _cachedHistoricals;

  @override
  void initState() {
    super.initState();
    _loadIndicatorPreferences();
  }

  Future<void> _loadIndicatorPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _showCandles = prefs.getBool('chart_show_candles') ?? false;
        _showVolume = prefs.getBool('chart_show_volume') ?? true;
        _showIndicatorLegend = prefs.getBool('chart_show_legend') ?? true;
        _showTechnicalSummary = prefs.getBool('chart_show_summary') ?? true;

        final savedIndicators = prefs.getStringList('chart_active_indicators');
        if (savedIndicators != null) {
          _activeIndicators.clear();
          for (final ind in savedIndicators) {
            try {
              final indicator = _OverlayIndicator.values.firstWhere(
                  (e) => e.toString() == ind,
                  orElse: () => _OverlayIndicator.sma20);
              _activeIndicators.add(indicator);
            } catch (_) {}
          }
        }
      });
    } catch (e) {
      debugPrint('Error loading preferences: $e');
    }
  }

  Future<void> _saveIndicatorPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('chart_show_candles', _showCandles);
      await prefs.setBool('chart_show_volume', _showVolume);
      await prefs.setBool('chart_show_legend', _showIndicatorLegend);
      await prefs.setBool('chart_show_summary', _showTechnicalSummary);

      final indicatorsList =
          _activeIndicators.map((e) => e.toString()).toList();
      await prefs.setStringList('chart_active_indicators', indicatorsList);
    } catch (e) {
      debugPrint('Error saving preferences: $e');
    }
  }

  void _calculateIndicators(List<InstrumentHistorical> historicals) {
    if (_cachedHistoricals == _lastValidHistoricals) return;

    _indicatorValues.clear();
    _indicatorPoints.clear();
    _bbUpperValues = [];
    _bbLowerValues = [];
    _bbUpperPoints = [];
    _bbLowerPoints = [];

    if (historicals.isEmpty) {
      _cachedHistoricals = _lastValidHistoricals;
      return;
    }

    final candles = _historicalsToCandles(historicals);

    void cache(_OverlayIndicator indicator, List<double?> values) {
      _indicatorValues[indicator] = values;
      _indicatorPoints[indicator] = _buildIndicatorPoints(historicals, values);
    }

    cache(
        _OverlayIndicator.sma10, TechnicalIndicators.calculateSMA(candles, 10));
    cache(
        _OverlayIndicator.sma20, TechnicalIndicators.calculateSMA(candles, 20));
    cache(
        _OverlayIndicator.sma50, TechnicalIndicators.calculateSMA(candles, 50));
    cache(_OverlayIndicator.sma200,
        TechnicalIndicators.calculateSMA(candles, 200));
    cache(
        _OverlayIndicator.ema12, TechnicalIndicators.calculateEMA(candles, 12));
    cache(
        _OverlayIndicator.ema26, TechnicalIndicators.calculateEMA(candles, 26));
    cache(_OverlayIndicator.vwap, TechnicalIndicators.calculateVWAP(candles));

    final bb = TechnicalIndicators.calculateBollingerBands(candles);
    _bbUpperValues = bb['upper'] ?? <double?>[];
    _bbLowerValues = bb['lower'] ?? <double?>[];

    _bbUpperPoints = _buildIndicatorPoints(historicals, _bbUpperValues);
    _bbLowerPoints = _buildIndicatorPoints(historicals, _bbLowerValues);

    _cachedHistoricals = _lastValidHistoricals;
  }

  String _getPeriodLabel(ChartDateSpan span) {
    switch (span) {
      case ChartDateSpan.hour:
        return "Past Hour";
      case ChartDateSpan.day:
        return "Today";
      case ChartDateSpan.week:
        return "Past Week";
      case ChartDateSpan.month:
        return "Past Month";
      case ChartDateSpan.month_3:
        return "Past 3 Months";
      case ChartDateSpan.ytd:
        return "YTD";
      case ChartDateSpan.year:
        return "Past Year";
      case ChartDateSpan.year_2:
        return "Past 2 Years";
      case ChartDateSpan.year_3:
        return "Past 3 Years";
      case ChartDateSpan.year_5:
        return "Past 5 Years";
      case ChartDateSpan.all:
        return "All Time";
    }
  }

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

          final historicals = _lastValidHistoricals!.historicals;
          // Calculate indicators if needed
          _calculateIndicators(historicals);

          final maxVolume =
              historicals.map((e) => e.volume).reduce(math.max).toDouble();

          final List<charts.Series<dynamic, DateTime>> seriesList = [
            charts.Series<InstrumentHistorical, DateTime>(
              id: 'Price',
              colorFn: (_, __) => charts.ColorUtil.fromDartColor(
                  Theme.of(context).colorScheme.primary),
              domainFn: (InstrumentHistorical history, _) => history.beginsAt!,
              measureFn: (InstrumentHistorical history, _) =>
                  history.closePrice ?? history.openPrice,
              data: historicals,
            )..setAttribute(charts.rendererIdKey, 'area'),
          ];

          if (_showVolume) {
            seriesList.add(charts.Series<InstrumentHistorical, DateTime>(
              id: 'Volume',
              domainFn: (InstrumentHistorical history, _) => history.beginsAt!,
              measureFn: (InstrumentHistorical history, _) => history.volume,
              data: historicals,
              colorFn: (_, __) => charts.ColorUtil.fromDartColor(
                  Theme.of(context).colorScheme.primary.withOpacity(0.2)),
            )
              ..setAttribute(charts.rendererIdKey, 'volume')
              ..setAttribute(
                  charts.measureAxisIdKey, charts.Axis.secondaryMeasureAxisId));
          }

          final List<double> extentValues = historicals
              .map((e) => e.closePrice ?? e.openPrice)
              .whereType<double>()
              .toList();

          void addIndicatorValues(List<_IndicatorPoint> points) {
            extentValues.addAll(
                points.map((p) => p.value).whereType<double>().toList());
          }

          List<charts.Series<dynamic, DateTime>> indicatorSeries = [];

          for (final indicator in _activeIndicators) {
            if (indicator == _OverlayIndicator.bollinger) continue;

            final points = _indicatorPoints[indicator];
            if (points != null && points.isNotEmpty) {
              indicatorSeries.add(_createIndicatorSeries(
                  label: _indicatorLabel(indicator),
                  points: points,
                  color: _indicatorColor(indicator, context)));
              addIndicatorValues(points);
            }
          }

          if (_activeIndicators.contains(_OverlayIndicator.bollinger)) {
            indicatorSeries.add(_createIndicatorSeries(
                label: 'BB Upper',
                dashPattern: const [4, 2],
                points: _bbUpperPoints,
                color: _indicatorColor(_OverlayIndicator.bollinger, context)));
            indicatorSeries.add(_createIndicatorSeries(
                label: 'BB Lower',
                dashPattern: const [4, 2],
                points: _bbLowerPoints,
                color: _indicatorColor(_OverlayIndicator.bollinger, context)));
            addIndicatorValues(_bbUpperPoints);
            addIndicatorValues(_bbLowerPoints);
          }

          seriesList.addAll(indicatorSeries);

          var extents = _calculateChartExtents(extentValues);
          var provider = Provider.of<InstrumentHistoricalsSelectionStore>(
              context,
              listen: false);

          chart = TimeSeriesChart(seriesList,
              key: ValueKey('chart_${_showVolume}_${_activeIndicators.length}'),
              open: open,
              close: close,
              animate: true,
              behaviors: [
                charts.SelectNearest(
                    eventTrigger: charts.SelectionTrigger.tapAndDrag,
                    selectionMode: common.SelectionMode.expandToDomain),
                charts.LinePointHighlighter(
                    showVerticalFollowLine:
                        charts.LinePointHighlighterFollowLineType.nearest,
                    drawFollowLinesAcrossChart: true,
                    symbolRenderer: TextSymbolRenderer(
                      () {
                        return provider.selection != null
                            ? formatCompactDateTimeWithHour.format(
                                (provider.selection as InstrumentHistorical)
                                    .beginsAt!
                                    .toLocal())
                            : '0';
                      },
                      marginBottom: 16,
                      backgroundColor:
                          Theme.of(context).colorScheme.inverseSurface,
                      textColor: Theme.of(context).colorScheme.onInverseSurface,
                    )),
                if (_showIndicatorLegend && _activeIndicators.isNotEmpty)
                  charts.SeriesLegend(
                    position: charts.BehaviorPosition.top,
                    outsideJustification: charts.OutsideJustification.start,
                    horizontalFirst: false,
                    desiredMaxRows: 1,
                    cellPadding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    entryTextStyle: charts.TextStyleSpec(
                        fontSize: 11,
                        color: charts.ColorUtil.fromDartColor(
                            Theme.of(context).colorScheme.onSurface)),
                  ),
                if (open != 0 && close != 0)
                  charts.RangeAnnotation([
                    charts.RangeAnnotationSegment(
                        open <= close ? open : close,
                        open <= close ? close : open,
                        charts.RangeAnnotationAxisType.measure,
                        startLabel: open <= close
                            ? 'open ${formatCurrency.format(open)}'
                            : 'close ${formatCurrency.format(close)}',
                        endLabel: open <= close
                            ? 'close ${formatCurrency.format(close)}'
                            : 'open ${formatCurrency.format(open)}',
                        labelStyleSpec: charts.TextStyleSpec(
                            fontSize: 14,
                            color: charts.ColorUtil.fromDartColor(
                                Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant)),
                        color: charts.ColorUtil.fromDartColor(Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withOpacity(0.3)))
                  ])
              ],
              selectionMode: common.SelectionMode.expandToDomain,
              showVerticalFollowLine:
                  charts.LinePointHighlighterFollowLineType.nearest,
              drawFollowLinesAcrossChart: true,
              customSeriesRenderers: [
                charts.LineRendererConfig<DateTime>(
                    customRendererId: 'area',
                    includeArea: true,
                    strokeWidthPx: 2.0),
                charts.LineRendererConfig<DateTime>(
                    customRendererId: _indicatorRendererId,
                    includeArea: false,
                    strokeWidthPx: 1.5,
                    symbolRenderer: CustomLineSymbolRenderer()),
                if (_showVolume)
                  charts.BarRendererConfig<DateTime>(
                      customRendererId: 'volume',
                      groupingType: charts.BarGroupingType.grouped)
              ],
              primaryMeasureAxis: charts.NumericAxisSpec(
                tickFormatterSpec:
                    charts.BasicNumericTickFormatterSpec.fromNumberFormat(
                        formatCompactCurrency),
                tickProviderSpec: const charts.BasicNumericTickProviderSpec(
                  zeroBound: false,
                  dataIsInWholeNumbers: false,
                ),
                renderSpec: charts.GridlineRendererSpec(
                    labelStyle: charts.TextStyleSpec(
                        color: charts.ColorUtil.fromDartColor(
                            Theme.of(context).colorScheme.onSurface))),
              ),
              secondaryMeasureAxis: _showVolume
                  ? charts.NumericAxisSpec(
                      tickProviderSpec:
                          const charts.BasicNumericTickProviderSpec(
                              zeroBound: true),
                      renderSpec: charts.NoneRenderSpec(),
                      viewport: charts.NumericExtents(0, maxVolume * 5))
                  : null,
              seriesLegend: null,
              onSelected: (charts.SelectionModel<DateTime>? historical) {
            final selectedHistorical = historical?.selectedDatum
                .firstWhereOrNull(
                    (element) => element.datum is InstrumentHistorical)
                ?.datum as InstrumentHistorical?;
            if (selectedHistorical != provider.selection) {
              HapticFeedback.selectionClick();
              provider.selectionChanged(selectedHistorical);
            }
          },
              symbolRenderer: null,
              zeroBound: false,
              dataIsInWholeNumbers: false,
              viewport: extents);

          return Column(
            children: [
              Consumer<InstrumentHistoricalsSelectionStore>(
                  builder: (context, value, child) {
                selection = value.selection;
                int selectedIndex = -1;
                if (selection != null) {
                  selectedIndex = historicals
                      .indexWhere((h) => h.beginsAt == selection!.beginsAt);
                }

                if (selectedIndex == -1) {
                  selection = null;
                }

                if (selection != null) {
                  changeInPeriod = selection!.closePrice! - open;
                  changePercentInPeriod = selection!.closePrice! / open - 1;
                } else {
                  changeInPeriod = close - open;
                  changePercentInPeriod = close / open - 1;
                }

                // Get indicator values at selected point
                selectedIndex =
                    selection != null ? selectedIndex : historicals.length - 1;

                return SizedBox(
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 4.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formatCurrency.format(selection != null
                                ? selection!.closePrice
                                : close),
                            style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                                height: 1.1,
                                fontFeatures: [
                                  ui.FontFeature.tabularFigures()
                                ]),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                "${changeInPeriod > 0 ? "+" : changeInPeriod < 0 ? "-" : ""}${formatCurrency.format(changeInPeriod.abs())} (${formatPercentage.format(changePercentInPeriod.abs())})",
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: changeInPeriod > 0
                                        ? Colors.green
                                        : (changeInPeriod < 0
                                            ? Colors.red
                                            : textColor),
                                    fontFeatures: [
                                      ui.FontFeature.tabularFigures()
                                    ]),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: Row(
                                    key: ValueKey(selection?.beginsAt ??
                                        widget.chartDateSpanFilter),
                                    children: [
                                      Icon(
                                        selection != null
                                            ? Icons.access_time
                                            : Icons.calendar_today,
                                        size: 14,
                                        color: textColor.withOpacity(0.5),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          selection != null
                                              ? formatMediumDateTime.format(
                                                  selection!.beginsAt!
                                                      .toLocal())
                                              : _getPeriodLabel(
                                                  widget.chartDateSpanFilter),
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: textColor.withOpacity(0.7),
                                              fontFeatures: [
                                                ui.FontFeature.tabularFigures()
                                              ]),
                                          overflow: TextOverflow.fade,
                                          maxLines: 1,
                                          softWrap: false,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (!_showCandles &&
                              (_activeIndicators.isNotEmpty || _showVolume) &&
                              selectedIndex >= 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 6.0),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: _buildIndicatorValueChips(
                                          selectedIndex, context, textColor)
                                      .map((w) => Padding(
                                          padding:
                                              const EdgeInsets.only(right: 6),
                                          child: w))
                                      .toList(),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ));
              }),
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
                            child: Row(
                              children: [
                                if (!_showCandles &&
                                    _activeIndicators.isNotEmpty)
                                  IconButton(
                                    icon: Icon(_showIndicatorLegend
                                        ? Icons.legend_toggle
                                        : Icons.legend_toggle_outlined),
                                    tooltip: 'Toggle Legend',
                                    onPressed: () {
                                      setState(() {
                                        _showIndicatorLegend =
                                            !_showIndicatorLegend;
                                        _saveIndicatorPreferences();
                                      });
                                    },
                                  ),
                                IconButton(
                                  icon: Icon(_showCandles
                                      ? Icons.show_chart
                                      : Icons.candlestick_chart),
                                  tooltip: _showCandles
                                      ? 'Line Chart'
                                      : 'Candlestick Chart',
                                  onPressed: () {
                                    setState(() {
                                      _showCandles = !_showCandles;
                                      _saveIndicatorPreferences();
                                    });
                                  },
                                ),
                              ],
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
                              child: _showCandles
                                  ? Candlesticks(
                                      candles: _generateCandles(
                                          _lastValidHistoricals!.historicals),
                                    )
                                  : chart!,
                            )),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!_showCandles && _activeIndicators.isNotEmpty)
                                IconButton(
                                  icon: Icon(_showIndicatorLegend
                                      ? Icons.legend_toggle
                                      : Icons.legend_toggle_outlined),
                                  tooltip: 'Toggle Legend',
                                  onPressed: () {
                                    setState(() {
                                      _showIndicatorLegend =
                                          !_showIndicatorLegend;
                                      _saveIndicatorPreferences();
                                    });
                                  },
                                ),
                              IconButton(
                                icon: Icon(_showCandles
                                    ? Icons.show_chart
                                    : Icons.candlestick_chart),
                                tooltip: _showCandles
                                    ? 'Line Chart'
                                    : 'Candlestick Chart',
                                onPressed: () {
                                  setState(() {
                                    _showCandles = !_showCandles;
                                    _saveIndicatorPreferences();
                                  });
                                },
                              ),
                              IconButton(
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
                                        chartBoundsFilter:
                                            widget.chartBoundsFilter,
                                        onFilterChanged: widget.onFilterChanged,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
              if (!_showCandles) _buildChartControls(),
              _buildDateFilters(),
              // Add inline technical analysis summary
              _buildInlineTechnicalAnalysis(context),
              if (widget.isFullScreen) const SizedBox(height: 25),
            ],
          );
        }
        return Column(
          children: [
            SizedBox(
                height: 340,
                child: Center(
                    child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator.adaptive(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.7)),
                        )),
                    const SizedBox(height: 20),
                    Text(
                      "Loading chart data...",
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  ],
                ))),
            _buildDateFilters(),
            if (widget.isFullScreen) const SizedBox(height: 25),
          ],
        );
      },
    );
  }

  List<Widget> _buildIndicatorValueChips(
      int index, BuildContext context, Color textColor) {
    final chips = <Widget>[];

    Widget buildChip(String label, double? value, Color color) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: textColor.withOpacity(0.9),
                    fontFeatures: [ui.FontFeature.tabularFigures()])),
            const SizedBox(width: 4),
            Text(
                value != null
                    ? (label == 'Vol'
                        ? formatCompactNumber.format(value)
                        : formatCurrency.format(value))
                    : '-',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontFeatures: [ui.FontFeature.tabularFigures()])),
          ],
        ),
      );
    }

    if (_showVolume &&
        _lastValidHistoricals != null &&
        index < _lastValidHistoricals!.historicals.length) {
      chips.add(buildChip(
          'Vol',
          _lastValidHistoricals!.historicals[index].volume.toDouble(),
          Theme.of(context).colorScheme.primary));
    }

    for (final indicator in _activeIndicators) {
      if (indicator == _OverlayIndicator.bollinger) continue;
      final values = _indicatorValues[indicator];
      if (values != null) {
        chips.add(buildChip(
            _indicatorLabel(indicator),
            values.elementAtOrNull(index),
            _indicatorColor(indicator, context)));
      }
    }

    if (_activeIndicators.contains(_OverlayIndicator.bollinger)) {
      final color = _indicatorColor(_OverlayIndicator.bollinger, context);
      chips.add(buildChip('BB↑', _bbUpperValues.elementAtOrNull(index), color));
      chips.add(buildChip('BB↓', _bbLowerValues.elementAtOrNull(index), color));
    }

    return chips;
  }

  Widget _buildIndicatorChip(
      _OverlayIndicator indicator, BuildContext context) {
    final selected = _activeIndicators.contains(indicator);
    final color = _indicatorColor(indicator, context);
    return GestureDetector(
      onLongPress: () {
        // Long press: toggle only this indicator
        setState(() {
          _activeIndicators.clear();
          if (!selected) {
            _activeIndicators.add(indicator);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(selected
                ? 'All indicators cleared'
                : 'Showing only ${_indicatorLabel(indicator)}'),
            duration: const Duration(milliseconds: 1500),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: FilterChip(
          avatar: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: selected ? color : color.withOpacity(0.3),
              shape: BoxShape.circle,
              border: Border.all(
                color: color,
                width: selected ? 2 : 1,
              ),
            ),
          ),
          label: Text(_indicatorLabel(indicator)),
          labelStyle: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
          selected: selected,
          showCheckmark: false,
          onSelected: (_) {
            setState(() {
              if (selected) {
                _activeIndicators.remove(indicator);
              } else {
                _activeIndicators.add(indicator);
              }
              _saveIndicatorPreferences();
            });
          },
        ),
      ),
    );
  }

  String _indicatorLabel(_OverlayIndicator indicator) {
    switch (indicator) {
      case _OverlayIndicator.sma10:
        return 'SMA 10';
      case _OverlayIndicator.sma20:
        return 'SMA 20';
      case _OverlayIndicator.sma50:
        return 'SMA 50';
      case _OverlayIndicator.sma200:
        return 'SMA 200';
      case _OverlayIndicator.ema12:
        return 'EMA 12';
      case _OverlayIndicator.ema26:
        return 'EMA 26';
      case _OverlayIndicator.vwap:
        return 'VWAP';
      case _OverlayIndicator.bollinger:
        return 'Bollinger';
    }
  }

  Color _indicatorColor(_OverlayIndicator indicator, BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (indicator) {
      case _OverlayIndicator.sma10:
        return isDark ? Colors.pink.shade300 : Colors.pink.shade700;
      case _OverlayIndicator.sma20:
        return isDark ? Colors.orange.shade400 : Colors.orange.shade700;
      case _OverlayIndicator.sma50:
        return scheme.secondary;
      case _OverlayIndicator.sma200:
        return isDark ? Colors.red.shade400 : Colors.red.shade700;
      case _OverlayIndicator.ema12:
        return isDark ? Colors.purple.shade300 : Colors.purple.shade700;
      case _OverlayIndicator.ema26:
        return isDark ? Colors.indigo.shade300 : Colors.indigo.shade700;
      case _OverlayIndicator.vwap:
        return isDark ? Colors.teal.shade300 : Colors.teal.shade700;
      case _OverlayIndicator.bollinger:
        return isDark ? Colors.amber.shade400 : Colors.amber.shade700;
    }
  }

  List<_IndicatorPoint> _buildIndicatorPoints(
      List<InstrumentHistorical> historicals, List<double?> values) {
    final points = <_IndicatorPoint>[];
    final length = math.min(historicals.length, values.length);

    for (int i = 0; i < length; i++) {
      final time = historicals[i].beginsAt;
      if (time == null) continue;
      points.add(_IndicatorPoint(time: time, value: values[i]));
    }

    return points;
  }

  charts.Series<_IndicatorPoint, DateTime> _createIndicatorSeries(
      {required String label,
      required List<_IndicatorPoint> points,
      required Color color,
      List<int>? dashPattern}) {
    final adjustedColor = color.withOpacity(0.85);
    return charts.Series<_IndicatorPoint, DateTime>(
      id: label,
      colorFn: (_, __) => charts.ColorUtil.fromDartColor(adjustedColor),
      dashPatternFn: dashPattern == null ? null : (_, __) => dashPattern,
      domainFn: (point, _) => point.time,
      measureFn: (point, _) => point.value,
      data: points,
    )..setAttribute(charts.rendererIdKey, _indicatorRendererId);
  }

  charts.NumericExtents _calculateChartExtents(List<double> values) {
    if (values.isEmpty) {
      return const charts.NumericExtents(0, 1);
    }

    final extents = charts.NumericExtents.fromValues(values);
    final padding = extents.width == 0
        ? (extents.min.abs() * 0.05) + 1
        : extents.width * 0.1;

    return charts.NumericExtents(extents.min - padding, extents.max + padding);
  }

  Widget _buildChartControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _OverlayIndicator.values.map((indicator) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: _buildIndicatorChip(indicator, context),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Tools
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  _showVolume ? Icons.bar_chart : Icons.bar_chart_outlined,
                  size: 20,
                  color: _showVolume
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                tooltip: 'Toggle Volume',
                onPressed: () {
                  setState(() {
                    _showVolume = !_showVolume;
                    _saveIndicatorPreferences();
                  });
                },
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: const EdgeInsets.all(8),
              ),
              IconButton(
                icon: const Icon(Icons.help_outline, size: 20),
                tooltip: 'Indicator Help',
                onPressed: _showIndicatorHelp,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: const EdgeInsets.all(8),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.bookmarks_outlined, size: 20),
                tooltip: 'Indicator Presets',
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: const EdgeInsets.all(8),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'trend',
                    child: Row(children: [
                      Icon(Icons.trending_up, size: 18),
                      SizedBox(width: 8),
                      Text('Trend Following')
                    ]),
                  ),
                  const PopupMenuItem(
                    value: 'momentum',
                    child: Row(children: [
                      Icon(Icons.speed, size: 18),
                      SizedBox(width: 8),
                      Text('Momentum')
                    ]),
                  ),
                  const PopupMenuItem(
                    value: 'volatility',
                    child: Row(children: [
                      Icon(Icons.import_export, size: 18),
                      SizedBox(width: 8),
                      Text('Volatility')
                    ]),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'all',
                    child: Text('Add All'),
                  ),
                  const PopupMenuItem(
                    value: 'clear',
                    child:
                        Text('Clear All', style: TextStyle(color: Colors.red)),
                  ),
                ],
                onSelected: (value) {
                  setState(() {
                    if (value == 'clear') {
                      _activeIndicators.clear();
                    } else {
                      _activeIndicators.clear();
                      switch (value) {
                        case 'trend':
                          _activeIndicators.addAll([
                            _OverlayIndicator.sma20,
                            _OverlayIndicator.sma50,
                            _OverlayIndicator.sma200,
                          ]);
                          break;
                        case 'momentum':
                          _activeIndicators.addAll([
                            _OverlayIndicator.ema12,
                            _OverlayIndicator.ema26,
                            _OverlayIndicator.vwap,
                          ]);
                          break;
                        case 'volatility':
                          _activeIndicators.add(_OverlayIndicator.bollinger);
                          break;
                        case 'all':
                          _activeIndicators.addAll(_OverlayIndicator.values);
                          break;
                      }
                    }
                    _saveIndicatorPreferences();
                  });
                },
              ),
              IconButton(
                icon: Icon(
                  _showTechnicalSummary
                      ? Icons.analytics
                      : Icons.analytics_outlined,
                  size: 20,
                  color: _showTechnicalSummary
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                tooltip: 'Toggle Technical Analysis',
                onPressed: () {
                  setState(() {
                    _showTechnicalSummary = !_showTechnicalSummary;
                    _saveIndicatorPreferences();
                  });
                },
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: const EdgeInsets.all(8),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilters() {
    return Container(
      height: 36,
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
      child: ListView(
        key: const PageStorageKey<String>('instrumentChartFilters'),
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        scrollDirection: Axis.horizontal,
        children: [
          Row(
            children: {
              ChartDateSpan.day: '1D',
              ChartDateSpan.week: '1W',
              ChartDateSpan.month: '1M',
              ChartDateSpan.month_3: '3M',
              ChartDateSpan.year: '1Y',
              ChartDateSpan.year_5: '5Y',
            }.entries.map((e) => _buildDateSpanChip(e.key, e.value)).toList(),
          )
        ],
      ),
    );
  }

  Widget _buildDateSpanChip(ChartDateSpan span, String label) {
    final bool isSelected = widget.chartDateSpanFilter == span;
    return GestureDetector(
      onTap: () => widget.onFilterChanged(span, widget.chartBoundsFilter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 2.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.surface
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  List<Candle> _generateCandles(List<InstrumentHistorical> historicals,
      {bool fullResolution = false}) {
    if (historicals.isEmpty) return [];

    // Determine bucket size based on total points to get roughly 60 candles
    // unless full resolution is requested (e.g. for specialized calculations)
    int bucketSize = 1;
    if (!fullResolution) {
      bucketSize = (historicals.length / 60).ceil();
      if (bucketSize < 1) {
        bucketSize = 1;
      }
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

  List<Candle> _historicalsToCandles(List<InstrumentHistorical> historicals) {
    if (historicals.isEmpty) return [];

    const double minPrice = 0.01;

    return historicals.map((h) {
      final open = (h.openPrice ?? h.closePrice ?? minPrice)
          .clamp(minPrice, double.infinity)
          .toDouble();
      final close = (h.closePrice ?? h.openPrice ?? minPrice)
          .clamp(minPrice, double.infinity)
          .toDouble();
      final high = math
          .max(h.highPrice ?? open, math.max(open, close))
          .clamp(minPrice, double.infinity)
          .toDouble();
      final low = math
          .min(h.lowPrice ?? open, math.min(open, close))
          .clamp(minPrice, double.infinity)
          .toDouble();

      return Candle(
        date: h.beginsAt ?? DateTime.now(),
        high: high,
        low: low,
        open: open,
        close: close,
        volume: h.volume.toDouble(),
      );
    }).toList();
  }

  void _showIndicatorHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Technical Indicators'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHelpItem('SMA', 'Simple Moving Average',
                  'Average price over a period. Helps identify trends.'),
              _buildHelpItem('EMA', 'Exponential Moving Average',
                  'Weighted average giving more weight to recent prices.'),
              _buildHelpItem('VWAP', 'Volume Weighted Average Price',
                  'Average price weighted by volume. Intraday benchmark.'),
              _buildHelpItem('Bollinger Bands', 'Volatility Bands',
                  'Shows price volatility. Price near upper band = overbought, near lower = oversold.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(String title, String subtitle, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Text(subtitle,
              style: TextStyle(
                  fontSize: 12, color: Colors.grey.shade600, height: 1.2)),
          const SizedBox(height: 4),
          Text(description, style: const TextStyle(fontSize: 12, height: 1.3)),
        ],
      ),
    );
  }

  Widget _buildInlineTechnicalAnalysis(BuildContext context) {
    if (_lastValidHistoricals == null ||
        _lastValidHistoricals!.historicals.isEmpty) {
      return const SizedBox.shrink();
    }

    // Generate Candles (reused logic efficiently)
    // Use fullResolution=true to get all available data points for accurate indicator calculation (especially SMA 200)
    final candles = _generateCandles(_lastValidHistoricals!.historicals,
        fullResolution: true);
    // Sort oldest first for calculation
    final sortedCandles = candles.reversed.toList();

    // Calculate key indicators for the latest candle
    // SMA
    var sma10 = TechnicalIndicators.calculateSMA(sortedCandles, 10).last;
    var sma20 = TechnicalIndicators.calculateSMA(sortedCandles, 20).last;
    var sma50 = TechnicalIndicators.calculateSMA(sortedCandles, 50).last;
    var sma200 = TechnicalIndicators.calculateSMA(sortedCandles, 200).last;

    // EMA
    var ema12 = TechnicalIndicators.calculateEMA(sortedCandles, 12).last;
    var ema26 = TechnicalIndicators.calculateEMA(sortedCandles, 26).last;

    // RSI
    var rsi = TechnicalIndicators.calculateRSI(sortedCandles, 14).last;

    // MACD
    var macdData = TechnicalIndicators.calculateMACD(sortedCandles);
    var macd = macdData['macd']!.last;
    var signal = macdData['signal']!.last;

    // VWAP
    var vwap = TechnicalIndicators.calculateVWAP(sortedCandles).last;

    // Stochastic
    var stochastic = TechnicalIndicators.calculateStochastic(sortedCandles);
    var stochK = stochastic['k']!.last;
    var stochD = stochastic['d']!.last;

    // CCI
    var cci = TechnicalIndicators.calculateCCI(sortedCandles).last;

    // Williams R
    var williamsR = TechnicalIndicators.calculateWilliamsR(sortedCandles).last;

    // Current Price
    double currentPrice = sortedCandles.last.close;

    // Calculate Summary
    int bullishVotes = 0;
    int bearishVotes = 0;

    void vote(bool isBullish) {
      if (isBullish) {
        bullishVotes++;
      } else {
        bearishVotes++;
      }
    }

    // MA Votes
    if (sma10 != null) vote(currentPrice > sma10);
    if (sma20 != null) vote(currentPrice > sma20);
    if (sma50 != null) vote(currentPrice > sma50);
    if (sma200 != null) vote(currentPrice > sma200);
    if (ema12 != null) vote(currentPrice > ema12);
    if (ema26 != null) vote(currentPrice > ema26);
    if (vwap != null) vote(currentPrice > vwap);

    // Oscillator Votes
    if (rsi != null) {
      if (rsi < 30) {
        vote(true); // Oversold -> Buy
      } else if (rsi > 70) vote(false); // Overbought -> Sell
    }
    if (stochK != null && stochD != null) {
      if (stochK < 20 && stochK > stochD) {
        vote(true); // Oversold crossover
      } else if (stochK > 80 && stochK < stochD)
        vote(false); // Overbought crossover
    }
    if (cci != null) {
      if (cci < -100) {
        vote(true);
      } else if (cci > 100) vote(false);
    }
    if (williamsR != null) {
      if (williamsR < -80) {
        vote(true);
      } else if (williamsR > -20) vote(false);
    }
    if (macd != null && signal != null) {
      vote(macd > signal);
    }

    String summaryText = "Neutral";
    Color summaryColor = Colors.grey;
    IconData summaryIcon = Icons.remove;

    if (bullishVotes > bearishVotes + 2) {
      summaryText = "Strong Buy";
      summaryColor = Colors.green;
      summaryIcon = Icons.stars;
    } else if (bullishVotes > bearishVotes) {
      summaryText = "Buy";
      summaryColor = Colors.green.shade400;
      summaryIcon = Icons.arrow_upward;
    } else if (bearishVotes > bullishVotes + 2) {
      summaryText = "Strong Sell";
      summaryColor = Colors.red;
      summaryIcon = Icons.warning;
    } else if (bearishVotes > bullishVotes) {
      summaryText = "Sell";
      summaryColor = Colors.red.shade400;
      summaryIcon = Icons.arrow_downward;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: _showTechnicalSummary ? null : 0,
      margin: _showTechnicalSummary
          ? const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0)
          : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        gradient: LinearGradient(
          colors: [
            summaryColor.withOpacity(0.05),
            Theme.of(context).cardColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: summaryColor.withOpacity(0.3), width: 1),
        boxShadow: [
          if (_showTechnicalSummary)
            BoxShadow(
              color: summaryColor.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
        ],
      ),
      child: _showTechnicalSummary
          ? Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _showTechnicalAnalysis,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: summaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: summaryColor.withOpacity(0.3)),
                            ),
                            child: Icon(summaryIcon,
                                color: summaryColor, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  summaryText,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: summaryColor,
                                  ),
                                ),
                                Text(
                                  'Based on ${sortedCandles.length} periods',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                textBaseline: TextBaseline.alphabetic,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                children: [
                                  if (bullishVotes > 0) ...[
                                    Text(
                                      '$bullishVotes',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade400,
                                          fontSize: 13),
                                    ),
                                    Text(
                                      ' Buy',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.green.shade400
                                              .withOpacity(0.8),
                                          fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  if (bearishVotes > 0) ...[
                                    Text(
                                      '$bearishVotes',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red.shade400,
                                          fontSize: 13),
                                    ),
                                    Text(
                                      ' Sell',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.red.shade400
                                              .withOpacity(0.8),
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                  if (bullishVotes == 0 && bearishVotes == 0)
                                    Text(
                                      'No Signals',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: 80,
                                height: 4,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: Row(
                                    children: [
                                      if (bullishVotes > 0)
                                        Expanded(
                                          flex: bullishVotes,
                                          child: Container(
                                              color: Colors.green.shade400),
                                        ),
                                      if (bearishVotes > 0)
                                        Expanded(
                                          flex: bearishVotes,
                                          child: Container(
                                              color: Colors.red.shade400),
                                        ),
                                      if (bullishVotes == 0 &&
                                          bearishVotes == 0)
                                        Expanded(
                                            child: Container(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .surfaceContainerHighest)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right,
                            size: 20,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                      if (_showTechnicalSummary) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildQuickMetric('RSI', rsi, (v) {
                              return v.toStringAsFixed(1);
                            }, (v) {
                              if (v > 70) return Colors.red;
                              if (v < 30) return Colors.green;
                              return Theme.of(context).colorScheme.onSurface;
                            }),
                            _buildQuickMetric('MACD', macd, (v) {
                              if (signal == null) return 'N/A';
                              // Using simple diff string
                              final diff = v - signal;
                              return '${diff > 0 ? '+' : ''}${diff.toStringAsFixed(2)}';
                            }, (v) {
                              if (signal == null) return Colors.grey;
                              return v > signal ? Colors.green : Colors.red;
                            }),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildQuickMetric(
      String label,
      double? value,
      String Function(double) textProvider,
      Color Function(double) colorProvider) {
    if (value == null) return const SizedBox.shrink();

    final text = textProvider(value);
    final color = colorProvider(value);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showTechnicalAnalysis() {
    if (_lastValidHistoricals == null ||
        _lastValidHistoricals!.historicals.isEmpty) {
      return;
    }

    // Generate Candles (reused logic efficiently)
    // Use fullResolution=true to get all available data points for accurate indicator calculation (especially SMA 200)
    final candles = _generateCandles(_lastValidHistoricals!.historicals,
        fullResolution: true);
    // Sort oldest first for calculation
    final sortedCandles = candles.reversed.toList();

    // Calculate key indicators for the latest candle
    // SMA
    var sma10 = TechnicalIndicators.calculateSMA(sortedCandles, 10).last;
    var sma20 = TechnicalIndicators.calculateSMA(sortedCandles, 20).last;
    var sma50 = TechnicalIndicators.calculateSMA(sortedCandles, 50).last;
    var sma200 = TechnicalIndicators.calculateSMA(sortedCandles, 200).last;

    // EMA
    var ema12 = TechnicalIndicators.calculateEMA(sortedCandles, 12).last;
    var ema26 = TechnicalIndicators.calculateEMA(sortedCandles, 26).last;

    // RSI
    var rsi = TechnicalIndicators.calculateRSI(sortedCandles, 14).last;

    // MACD
    var macdData = TechnicalIndicators.calculateMACD(sortedCandles);
    var macd = macdData['macd']!.last;
    var signal = macdData['signal']!.last;

    // Bollinger
    var bb = TechnicalIndicators.calculateBollingerBands(sortedCandles);
    var upper = bb['upper']!.last;
    var lower = bb['lower']!.last;

    // VWAP
    var vwap = TechnicalIndicators.calculateVWAP(sortedCandles).last;

    // Stochastic
    var stochastic = TechnicalIndicators.calculateStochastic(sortedCandles);
    var stochK = stochastic['k']!.last;
    var stochD = stochastic['d']!.last;

    // ATR
    var atr = TechnicalIndicators.calculateATR(sortedCandles).last;

    // CCI
    var cci = TechnicalIndicators.calculateCCI(sortedCandles).last;

    // ADX
    var adxData = TechnicalIndicators.calculateADX(sortedCandles);
    var adx = adxData['adx']!.last;

    // Williams R
    var williamsR = TechnicalIndicators.calculateWilliamsR(sortedCandles).last;

    // OBV
    var obv = TechnicalIndicators.calculateOBV(sortedCandles).last;

    // Current Price
    double currentPrice = sortedCandles.last.close;

    // Calculate Summary
    int bullishVotes = 0;
    int bearishVotes = 0;

    void vote(bool isBullish) {
      if (isBullish) {
        bullishVotes++;
      } else {
        bearishVotes++;
      }
    }

    // MA Votes
    if (sma10 != null) vote(currentPrice > sma10);
    if (sma20 != null) vote(currentPrice > sma20);
    if (sma50 != null) vote(currentPrice > sma50);
    if (sma200 != null) vote(currentPrice > sma200);
    if (ema12 != null) vote(currentPrice > ema12);
    if (ema26 != null) vote(currentPrice > ema26);
    if (vwap != null) vote(currentPrice > vwap);

    // Oscillator Votes
    if (rsi != null) {
      if (rsi < 30) {
        vote(true); // Oversold -> Buy
      } else if (rsi > 70) vote(false); // Overbought -> Sell
    }
    if (stochK != null && stochD != null) {
      if (stochK < 20 && stochK > stochD) {
        vote(true); // Oversold crossover
      } else if (stochK > 80 && stochK < stochD)
        vote(false); // Overbought crossover
    }
    if (cci != null) {
      if (cci < -100) {
        vote(true);
      } else if (cci > 100) vote(false);
    }
    if (williamsR != null) {
      if (williamsR < -80) {
        vote(true);
      } else if (williamsR > -20) vote(false);
    }
    if (macd != null && signal != null) {
      vote(macd > signal);
    }

    String summaryText = "Neutral";
    Color summaryColor = Colors.grey;
    if (bullishVotes > bearishVotes + 2) {
      summaryText = "Strong Buy";
      summaryColor = Colors.green;
    } else if (bullishVotes > bearishVotes) {
      summaryText = "Buy";
      summaryColor = Colors.green.shade300;
    } else if (bearishVotes > bullishVotes + 2) {
      summaryText = "Strong Sell";
      summaryColor = Colors.red;
    } else if (bearishVotes > bullishVotes) {
      summaryText = "Sell";
      summaryColor = Colors.red.shade300;
    }

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
              return Container(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                      controller: scrollController,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Center(
                              child: Container(
                                width: 32,
                                height: 4,
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant
                                      .withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Technical Analysis",
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall),
                                IconButton(
                                    onPressed: () => Navigator.pop(context),
                                    icon: const Icon(Icons.close))
                              ],
                            ),
                            Text(
                                "Based on latest candle close: ${formatCurrency.format(currentPrice)}",
                                style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(height: 16),

                            // Summary Card
                            Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                    color: summaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: summaryColor)),
                                child: Column(children: [
                                  Text(summaryText,
                                      style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: summaryColor)),
                                  const SizedBox(height: 4),
                                  Text(
                                      "Bullish: $bullishVotes  Bearish: $bearishVotes",
                                      style: const TextStyle(fontSize: 12))
                                ])),
                            const SizedBox(height: 16),

                            _buildSectionHeader(
                                context, "Momentum & Oscillators"),
                            _buildIndicatorWithSignal("RSI (14)", rsi, (v) {
                              if (v > 70) {
                                return const Signal(
                                    text: "Overbought", color: Colors.red);
                              }
                              if (v < 30) {
                                return const Signal(
                                    text: "Oversold", color: Colors.green);
                              }
                              return const Signal(
                                  text: "Neutral", color: Colors.grey);
                            }),
                            _buildIndicatorWithSignal(
                                "Stochastic (14, 3)", stochK, (v) {
                              if (v > 80) {
                                return const Signal(
                                    text: "Overbought", color: Colors.red);
                              }
                              if (v < 20) {
                                return const Signal(
                                    text: "Oversold", color: Colors.green);
                              }
                              return const Signal(
                                  text: "Neutral", color: Colors.grey);
                            },
                                valueText:
                                    "K: ${stochK?.toStringAsFixed(2)} D: ${stochD?.toStringAsFixed(2)}"),
                            _buildIndicatorWithSignal("CCI (20)", cci, (v) {
                              if (v > 100) {
                                return const Signal(
                                    text: "Overbought", color: Colors.red);
                              }
                              if (v < -100) {
                                return const Signal(
                                    text: "Oversold", color: Colors.green);
                              }
                              return const Signal(
                                  text: "Neutral", color: Colors.grey);
                            }),
                            _buildIndicatorWithSignal(
                                "Williams %R (14)", williamsR, (v) {
                              if (v > -20) {
                                return const Signal(
                                    text: "Overbought", color: Colors.red);
                              }
                              if (v < -80) {
                                return const Signal(
                                    text: "Oversold", color: Colors.green);
                              }
                              return const Signal(
                                  text: "Neutral", color: Colors.grey);
                            }),
                            _buildIndicatorWithSignal("MACD (12, 26, 9)", macd,
                                (v) {
                              if (signal == null) {
                                return const Signal(
                                    text: "N/A", color: Colors.grey);
                              }
                              if (v > signal) {
                                return const Signal(
                                    text: "Bullish", color: Colors.green);
                              }
                              return const Signal(
                                  text: "Bearish", color: Colors.red);
                            }, valueText: "${macd?.toStringAsFixed(2)}"),

                            const Divider(),
                            _buildSectionHeader(context, "Trend Strength"),
                            _buildIndicatorWithSignal("ADX (14)", adx, (v) {
                              if (v > 25) {
                                return const Signal(
                                    text: "Strong Trend", color: Colors.blue);
                              }
                              return const Signal(
                                  text: "Weak Trend", color: Colors.grey);
                            }),

                            const Divider(),
                            _buildSectionHeader(context, "Moving Averages"),
                            _buildIndicatorWithSignal("SMA 10", sma10,
                                (v) => _comparePrice(currentPrice, v)),
                            _buildIndicatorWithSignal("SMA 20", sma20,
                                (v) => _comparePrice(currentPrice, v)),
                            _buildIndicatorWithSignal("SMA 50", sma50,
                                (v) => _comparePrice(currentPrice, v)),
                            _buildIndicatorWithSignal("SMA 200", sma200,
                                (v) => _comparePrice(currentPrice, v)),
                            _buildIndicatorWithSignal("EMA 12", ema12,
                                (v) => _comparePrice(currentPrice, v)),
                            _buildIndicatorWithSignal("EMA 26", ema26,
                                (v) => _comparePrice(currentPrice, v)),
                            _buildIndicatorWithSignal("VWAP", vwap,
                                (v) => _comparePrice(currentPrice, v)),
                            const Divider(),
                            _buildSectionHeader(context, "Volatility & Volume"),
                            _buildIndicatorWithSignal(
                                "ATR (14)",
                                atr,
                                (v) => const Signal(
                                    text: "Volatility", color: Colors.grey)),
                            _buildIndicatorWithSignal(
                                "OBV",
                                obv,
                                (v) => const Signal(
                                    text: "Volume", color: Colors.grey),
                                valueText: formatCompactCurrency
                                    .format(obv)
                                    .replaceAll('\$', '')),
                            _buildIndicatorWithSignal("Bollinger Bands", null,
                                (v) {
                              if (upper != null && currentPrice > upper) {
                                return const Signal(
                                    text: "Above Upper", color: Colors.red);
                              }
                              if (lower != null && currentPrice < lower) {
                                return const Signal(
                                    text: "Below Lower", color: Colors.green);
                              }
                              return const Signal(
                                  text: "Within Bands", color: Colors.grey);
                            },
                                valueText:
                                    "U: ${upper?.toStringAsFixed(2)} / L: ${lower?.toStringAsFixed(2)}"),
                          ])));
            },
          );
        });
  }

  Signal _comparePrice(double price, double indicatorValue) {
    if (price > indicatorValue) {
      return const Signal(text: "Bullish", color: Colors.green);
    }
    if (price < indicatorValue) {
      return const Signal(text: "Bearish", color: Colors.red);
    }
    return const Signal(text: "Neutral", color: Colors.grey);
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary)),
    );
  }

  Widget _buildIndicatorWithSignal(
      String label, double? value, Signal Function(double) getSignal,
      {String? valueText}) {
    Signal signal = const Signal(text: "N/A", color: Colors.grey);
    if (value != null) {
      signal = getSignal(value);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Row(children: [
            Text(valueText ?? value?.toStringAsFixed(2) ?? "N/A",
                style: const TextStyle(fontWeight: FontWeight.w400)),
            const SizedBox(width: 8),
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: signal.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: signal.color.withOpacity(0.5))),
                child: Text(signal.text,
                    style: TextStyle(
                        color: signal.color,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)))
          ])
        ],
      ),
    );
  }
}

class Signal {
  final String text;
  final Color color;
  const Signal({required this.text, required this.color});
}

class _IndicatorPoint {
  final DateTime time;
  final double? value;

  const _IndicatorPoint({required this.time, required this.value});
}

enum _OverlayIndicator {
  sma10,
  sma20,
  sma50,
  sma200,
  ema12,
  ema26,
  vwap,
  bollinger
}
