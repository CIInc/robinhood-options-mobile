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
import 'package:robinhood_options_mobile/utils/technical_indicators.dart';

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
                            child: Row(
                              children: [
                                if (_showCandles)
                                  IconButton(
                                    icon: const Icon(Icons.analytics),
                                    onPressed: _showTechnicalAnalysis,
                                  ),
                                IconButton(
                                  icon: Icon(_showCandles
                                      ? Icons.show_chart
                                      : Icons.candlestick_chart),
                                  onPressed: () {
                                    setState(() {
                                      _showCandles = !_showCandles;
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
                  )),
              if (widget.isFullScreen) const SizedBox(height: 25),
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
                )),
            if (widget.isFullScreen) const SizedBox(height: 25),
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
    var histogram = macdData['histogram']!.last;

    // Bollinger
    var bb = TechnicalIndicators.calculateBollingerBands(sortedCandles);
    var upper = bb['upper']!.last;
    var lower = bb['lower']!.last;
    var middle = bb['middle']!.last;

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
      if (rsi < 30)
        vote(true); // Oversold -> Buy
      else if (rsi > 70) vote(false); // Overbought -> Sell
    }
    if (stochK != null && stochD != null) {
      if (stochK < 20 && stochK > stochD)
        vote(true); // Oversold crossover
      else if (stochK > 80 && stochK < stochD)
        vote(false); // Overbought crossover
    }
    if (cci != null) {
      if (cci < -100)
        vote(true);
      else if (cci > 100) vote(false);
    }
    if (williamsR != null) {
      if (williamsR < -80)
        vote(true);
      else if (williamsR > -20) vote(false);
    }
    if (macd != null && signal != null) {
      vote(macd > signal!);
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
        builder: (context) {
          return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Technical Analysis",
                            style: Theme.of(context).textTheme.headlineSmall),
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
                          Text("Bullish: $bullishVotes  Bearish: $bearishVotes",
                              style: const TextStyle(fontSize: 12))
                        ])),
                    const SizedBox(height: 16),

                    _buildSectionHeader(context, "Momentum & Oscillators"),
                    _buildIndicatorWithSignal("RSI (14)", rsi, (v) {
                      if (v > 70)
                        return const Signal(
                            text: "Overbought", color: Colors.red);
                      if (v < 30)
                        return const Signal(
                            text: "Oversold", color: Colors.green);
                      return const Signal(text: "Neutral", color: Colors.grey);
                    }),
                    _buildIndicatorWithSignal("Stochastic (14, 3)", stochK,
                        (v) {
                      if (v > 80)
                        return const Signal(
                            text: "Overbought", color: Colors.red);
                      if (v < 20)
                        return const Signal(
                            text: "Oversold", color: Colors.green);
                      return const Signal(text: "Neutral", color: Colors.grey);
                    },
                        valueText:
                            "K: ${stochK?.toStringAsFixed(2)} D: ${stochD?.toStringAsFixed(2)}"),
                    _buildIndicatorWithSignal("CCI (20)", cci, (v) {
                      if (v > 100)
                        return const Signal(
                            text: "Overbought", color: Colors.red);
                      if (v < -100)
                        return const Signal(
                            text: "Oversold", color: Colors.green);
                      return const Signal(text: "Neutral", color: Colors.grey);
                    }),
                    _buildIndicatorWithSignal("Williams %R (14)", williamsR,
                        (v) {
                      if (v > -20)
                        return const Signal(
                            text: "Overbought", color: Colors.red);
                      if (v < -80)
                        return const Signal(
                            text: "Oversold", color: Colors.green);
                      return const Signal(text: "Neutral", color: Colors.grey);
                    }),
                    _buildIndicatorWithSignal("MACD (12, 26, 9)", macd, (v) {
                      if (signal == null)
                        return const Signal(text: "N/A", color: Colors.grey);
                      if (v > signal!)
                        return const Signal(
                            text: "Bullish", color: Colors.green);
                      return const Signal(text: "Bearish", color: Colors.red);
                    }, valueText: "${macd?.toStringAsFixed(2)}"),

                    const Divider(),
                    _buildSectionHeader(context, "Trend Strength"),
                    _buildIndicatorWithSignal("ADX (14)", adx, (v) {
                      if (v > 25)
                        return const Signal(
                            text: "Strong Trend", color: Colors.blue);
                      return const Signal(
                          text: "Weak Trend", color: Colors.grey);
                    }),

                    const Divider(),
                    _buildSectionHeader(context, "Moving Averages"),
                    _buildIndicatorWithSignal(
                        "SMA 10", sma10, (v) => _comparePrice(currentPrice, v)),
                    _buildIndicatorWithSignal(
                        "SMA 20", sma20, (v) => _comparePrice(currentPrice, v)),
                    _buildIndicatorWithSignal(
                        "SMA 50", sma50, (v) => _comparePrice(currentPrice, v)),
                    _buildIndicatorWithSignal("SMA 200", sma200,
                        (v) => _comparePrice(currentPrice, v)),
                    _buildIndicatorWithSignal(
                        "EMA 12", ema12, (v) => _comparePrice(currentPrice, v)),
                    _buildIndicatorWithSignal(
                        "EMA 26", ema26, (v) => _comparePrice(currentPrice, v)),
                    _buildIndicatorWithSignal(
                        "VWAP", vwap, (v) => _comparePrice(currentPrice, v)),
                    const Divider(),
                    _buildSectionHeader(context, "Volatility & Volume"),
                    _buildIndicatorWithSignal(
                        "ATR (14)",
                        atr,
                        (v) => const Signal(
                            text: "Volatility", color: Colors.grey)),
                    _buildIndicatorWithSignal("OBV", obv,
                        (v) => const Signal(text: "Volume", color: Colors.grey),
                        valueText: formatCompactCurrency
                            .format(obv)
                            .replaceAll('\$', '')),
                    _buildIndicatorWithSignal("Bollinger Bands", null, (v) {
                      if (upper != null && currentPrice > upper!)
                        return const Signal(
                            text: "Above Upper", color: Colors.red);
                      if (lower != null && currentPrice < lower!)
                        return const Signal(
                            text: "Below Lower", color: Colors.green);
                      return const Signal(
                          text: "Within Bands", color: Colors.grey);
                    },
                        valueText:
                            "U: ${upper?.toStringAsFixed(2)} / L: ${lower?.toStringAsFixed(2)}"),
                  ])));
        });
  }

  Signal _comparePrice(double price, double indicatorValue) {
    if (price > indicatorValue)
      return const Signal(text: "Bullish", color: Colors.green);
    if (price < indicatorValue)
      return const Signal(text: "Bearish", color: Colors.red);
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

  Widget _buildIndicatorRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value ?? "N/A"),
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
