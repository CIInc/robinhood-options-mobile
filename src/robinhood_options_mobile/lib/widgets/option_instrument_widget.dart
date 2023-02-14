import 'dart:async';
import 'dart:math' as math;
import 'package:collection/collection.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/enums.dart';

import 'package:robinhood_options_mobile/model/instrument_historical.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals_selection_store.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/option_historicals.dart';
import 'package:robinhood_options_mobile/model/option_historicals_store.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/option_instrument_store.dart';
import 'package:robinhood_options_mobile/model/option_order.dart';
import 'package:robinhood_options_mobile/model/option_order_store.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';

import 'package:robinhood_options_mobile/model/robinhood_user.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
import 'package:robinhood_options_mobile/widgets/chart_bar_widget.dart';
import 'package:robinhood_options_mobile/widgets/chart_time_series_widget.dart';
import 'package:robinhood_options_mobile/widgets/disclaimer_widget.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';
import 'package:robinhood_options_mobile/widgets/option_orders_widget.dart';
import 'package:robinhood_options_mobile/widgets/trade_option_widget.dart';

final formatDate = DateFormat("yMMMd");
final formatCurrency = NumberFormat.simpleCurrency();
final formatPercentage = NumberFormat.decimalPercentPattern(decimalDigits: 2);
final formatNumber = NumberFormat("0.####");
final formatCompactNumber = NumberFormat.compact();

class OptionInstrumentWidget extends StatefulWidget {
  const OptionInstrumentWidget(
      this.user,
      //this.account,
      this.optionInstrument,
      {Key? key,
      required this.analytics,
      required this.observer,
      this.optionPosition,
      this.heroTag})
      : super(key: key);

  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final RobinhoodUser user;
  //final Account account;
  final OptionInstrument optionInstrument;
  final OptionAggregatePosition? optionPosition;
  final String? heroTag;

  @override
  State<OptionInstrumentWidget> createState() => _OptionInstrumentWidgetState();
}

class _OptionInstrumentWidgetState extends State<OptionInstrumentWidget> {
  Future<Quote>? futureQuote;
  Future<Instrument>? futureInstrument;
  Future<List<OptionOrder>>? futureOptionOrders;
  Future<OptionHistoricals>? futureHistoricals;

  ChartDateSpan chartDateSpanFilter = ChartDateSpan.day;
  Bounds chartBoundsFilter = Bounds.regular;
  InstrumentHistorical? selection;

  Timer? refreshTriggerTime;
  //QuoteStore? quoteStore;

  _OptionInstrumentWidgetState();

  @override
  void initState() {
    super.initState();

    _startRefreshTimer();
    widget.analytics.setCurrentScreen(
      screenName:
          'OptionInstrument/${widget.optionInstrument.chainSymbol}/${widget.optionPosition!.strategy.split('_').first}/${widget.optionInstrument.type}/${widget.optionInstrument.strikePrice}/${widget.optionInstrument.expirationDate}',
    );
  }

  @override
  void dispose() {
    _stopRefreshTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var optionOrderStore =
        Provider.of<OptionOrderStore>(context, listen: false);
    var optionOrders = optionOrderStore.items
        .where((element) => element.chainId == widget.optionInstrument.chainId)
        .toList();
    if (optionOrders.isNotEmpty) {
      futureOptionOrders = Future.value(optionOrders);
    } else {
      futureOptionOrders = RobinhoodService.getOptionOrders(
          widget.user, optionOrderStore, widget.optionInstrument.chainId);
    }

    var quoteStore = Provider.of<QuoteStore>(context, listen: false);
    var cachedQuotes = quoteStore.items.where(
        (element) => element.symbol == widget.optionInstrument.chainSymbol);
    if (cachedQuotes.isNotEmpty) {
      futureQuote = Future.value(cachedQuotes.first);
    } else {
      futureQuote ??= RobinhoodService.getQuote(
          widget.user, quoteStore, widget.optionInstrument.chainSymbol);
    }

    futureHistoricals ??= RobinhoodService.getOptionHistoricals(
        widget.user,
        Provider.of<OptionHistoricalsStore>(context, listen: false),
        [widget.optionInstrument.id],
        chartBoundsFilter: chartBoundsFilter,
        chartDateSpanFilter: chartDateSpanFilter);

    return Scaffold(
      body: FutureBuilder(
          future: futureQuote,
          builder: (context, AsyncSnapshot<Quote> quoteSnapshot) {
            if (quoteSnapshot.hasData) {
              var quote = quoteSnapshot.data!;
              futureInstrument ??= RobinhoodService.getInstrument(
                  widget.user,
                  Provider.of<InstrumentStore>(context, listen: false),
                  quote.instrument);

              return FutureBuilder(
                  future: futureInstrument,
                  builder: (context1, instrumentSnapshot) {
                    if (instrumentSnapshot.hasData) {
                      var instrument = instrumentSnapshot.data!;
                      instrument.quoteObj = quote;

                      return FutureBuilder(
                          future: futureOptionOrders,
                          builder: (context2, ordersSnapshot) {
                            if (ordersSnapshot.hasData) {
                              return _buildPage(widget.optionInstrument,
                                  instrument: instrument,
                                  optionPosition: widget.optionPosition,
                                  optionOrders: ordersSnapshot.data!,
                                  done: instrumentSnapshot.connectionState ==
                                          ConnectionState.done &&
                                      quoteSnapshot.connectionState ==
                                          ConnectionState.done);
                            } else {
                              return _buildPage(widget.optionInstrument,
                                  instrument: instrument,
                                  optionPosition: widget.optionPosition,
                                  done: instrumentSnapshot.connectionState ==
                                          ConnectionState.done &&
                                      quoteSnapshot.connectionState ==
                                          ConnectionState.done);
                            }
                          });
                    } else {
                      return _buildPage(widget.optionInstrument,
                          done: instrumentSnapshot.connectionState ==
                                  ConnectionState.done &&
                              quoteSnapshot.connectionState ==
                                  ConnectionState.done);
                    }
                  });
            } else if (quoteSnapshot.hasError) {
              debugPrint("${quoteSnapshot.error}");
              // return Text("${quoteSnapshot.error}");
            }
            return _buildPage(widget.optionInstrument,
                done: quoteSnapshot.connectionState == ConnectionState.done);
          }),
      /*
        floatingActionButton: (user != null && user.userName != null)
            ? FloatingActionButton(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => TradeOptionWidget(user,
                            optionInstrument: optionInstrument))),
                tooltip: 'Trade',
                child: const Icon(Icons.shopping_cart),
              )
            : null*/
    );
  }

  Widget _buildPage(OptionInstrument optionInstrument,
      {Instrument? instrument,
      OptionAggregatePosition? optionPosition,
      List<OptionOrder>? optionOrders,
      bool done = false}) {
    List<OptionOrder>? optionInstrumentOrders;
    if (optionOrders != null) {
      optionInstrumentOrders = optionOrders
          .where((element) =>
              element.legs.first.option == widget.optionInstrument.url)
          .toList();
    }

    final DateTime today =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final int dte = optionInstrument.expirationDate!.difference(today).inDays;
    int originalDte = 0;
    DateTime createdAt = DateTime(optionInstrument.createdAt!.year,
        optionInstrument.createdAt!.month, optionInstrument.createdAt!.day);
    if (optionPosition != null) {
      createdAt = DateTime(optionPosition.createdAt!.year,
          optionPosition.createdAt!.month, optionPosition.createdAt!.day);
    }
    originalDte = optionInstrument.expirationDate!.difference(createdAt).inDays;
    List<charts.Series<dynamic, String>> seriesList = [
      charts.Series<dynamic, String>(
        id: 'Days to Expiration',
        data: [
          {'label': 'DTE', 'dte': dte}
        ],
        domainFn: (var d, _) => d['label'],
        measureFn: (var d, _) => d['dte'],
        labelAccessorFn: (d, _) => '${d['dte'].toString()} days',
      ),
      charts.Series<dynamic, String>(
          id: 'Days to Expiration',
          data: [
            {'label': 'DTE', 'dte': originalDte}
          ],
          domainFn: (var d, _) => d['label'],
          measureFn: (var d, _) => d['dte'])
        ..setAttribute(charts.rendererIdKey, "customTargetLine")
    ];
    var brightness = MediaQuery.of(context).platformBrightness;
    var axisLabelColor = charts.MaterialPalette.gray.shade500;
    if (brightness == Brightness.light) {
      axisLabelColor = charts.MaterialPalette.gray.shade700;
    }
    BarChart chart = BarChart(seriesList,
        renderer: charts.BarRendererConfig(
            barRendererDecorator: charts.BarLabelDecorator<String>(),
            cornerStrategy: const charts.ConstCornerStrategy(10)),
        domainAxis:
            const charts.OrdinalAxisSpec(renderSpec: charts.NoneRenderSpec()),
        primaryMeasureAxis: charts.NumericAxisSpec(
          //showAxisLine: true,
          //renderSpec: charts.GridlineRendererSpec(),
          renderSpec: charts.GridlineRendererSpec(
              labelStyle: charts.TextStyleSpec(color: axisLabelColor)),
          //renderSpec: charts.NoneRenderSpec(),
          //tickProviderSpec: charts.BasicNumericTickProviderSpec(),
          //tickProviderSpec: charts.NumericEndPointsTickProviderSpec(),
          //tickProviderSpec:
          //    charts.StaticNumericTickProviderSpec(widget.staticNumericTicks!),
          //viewport: charts.NumericExtents(0, widget.staticNumericTicks![widget.staticNumericTicks!.length - 1].value + 1)
        ),
        customRendererId: 'customTargetLine',
        onSelected: (_) {});
    return RefreshIndicator(
        onRefresh: _pullRefresh,
        child: CustomScrollView(slivers: [
          Consumer<OptionInstrumentStore>(
            builder: (context, optionInstrumentStore, child) {
              return _buildSliverAppBar(
                  optionInstrumentStore, optionPosition, instrument);
            },
          ),
          if (done == false) ...[
            const SliverToBoxAdapter(
                child: SizedBox(
              height: 3, //150.0,
              child: Align(
                  alignment: Alignment.center,
                  child: Center(
                      child: LinearProgressIndicator(
                          //value: controller.value,
                          //semanticsLabel: 'Linear progress indicator',
                          ) //CircularProgressIndicator(),
                      )),
            ))
          ],
          if (instrument != null) ...[
            SliverToBoxAdapter(
                child: Align(
                    alignment: Alignment.center,
                    child: buildOverview(
                        widget.user, optionInstrument, instrument,
                        optionPosition: optionPosition))),
          ],
          Consumer<OptionHistoricalsStore>(
              builder: (context, optionHistoricalsStore, child) {
            var optionInstrumentHistoricalsObj = optionHistoricalsStore.items
                .firstWhereOrNull((element) =>
                        element.legs.first.id == optionInstrument.id &&
                        element.span ==
                            RobinhoodService.convertChartSpanFilter(
                                chartDateSpanFilter) &&
                        element.bounds ==
                            RobinhoodService.convertChartBoundsFilter(
                                chartBoundsFilter)
                    //&& element.interval == element.interval
                    );
            debugPrint(
                '${optionInstrumentHistoricalsObj != null ? 'Found' : 'Not found'} optionInstrumentHistoricals for span: ${RobinhoodService.convertChartSpanFilter(chartDateSpanFilter)}, bounds: ${RobinhoodService.convertChartBoundsFilter(chartBoundsFilter)}');
            if (optionInstrumentHistoricalsObj != null) {
              InstrumentHistorical? firstHistorical;
              InstrumentHistorical? lastHistorical;
              double open = 0;
              double close = 0;
              double changeInPeriod = 0;
              double changePercentInPeriod = 0;

              firstHistorical =
                  optionInstrumentHistoricalsObj.historicals.first;
              lastHistorical = optionInstrumentHistoricalsObj.historicals.last;
              open = firstHistorical.openPrice!;
              close = lastHistorical.closePrice!;
              changeInPeriod = close - open;
              changePercentInPeriod = changeInPeriod / close;

              if (selection != null) {
                changeInPeriod = selection!.closePrice! - open;
                changePercentInPeriod = changeInPeriod / selection!.closePrice!;
              }

              var brightness = MediaQuery.of(context).platformBrightness;
              var textColor = Theme.of(context).colorScheme.background;
              if (brightness == Brightness.dark) {
                textColor = Colors.grey.shade200;
              } else {
                textColor = Colors.grey.shade800;
              }
              /*
              if (historicalChart == null ||
                  optionInstrumentHistoricalsObj.bounds !=
                      chartBoundsFilter
                          .toString()
                          .replaceAll("Bounds.", "")
                          .replaceAll("t24_7", "24_7") ||
                  optionInstrumentHistoricalsObj.span !=
                      chartDateSpanFilter
                          .toString()
                          .replaceAll("ChartDateSpan.", "")) {
                            */
              TimeSeriesChart historicalChart = TimeSeriesChart(
                  [
                    charts.Series<InstrumentHistorical, DateTime>(
                      id: 'Open',
                      colorFn: (_, __) =>
                          charts.MaterialPalette.blue.shadeDefault,
                      domainFn: (InstrumentHistorical history, _) =>
                          history.beginsAt!,
                      measureFn: (InstrumentHistorical history, _) =>
                          history.openPrice,
                      data: optionInstrumentHistoricalsObj.historicals,
                    ),
                    charts.Series<InstrumentHistorical, DateTime>(
                      id: 'Close',
                      colorFn: (_, __) =>
                          charts.MaterialPalette.blue.shadeDefault,
                      domainFn: (InstrumentHistorical history, _) =>
                          history.beginsAt!,
                      measureFn: (InstrumentHistorical history, _) =>
                          history.closePrice,
                      data: optionInstrumentHistoricalsObj.historicals,
                    ),
                    charts.Series<InstrumentHistorical, DateTime>(
                      id: 'Low',
                      colorFn: (_, __) =>
                          charts.MaterialPalette.red.shadeDefault,
                      domainFn: (InstrumentHistorical history, _) =>
                          history.beginsAt!,
                      measureFn: (InstrumentHistorical history, _) =>
                          history.lowPrice,
                      data: optionInstrumentHistoricalsObj.historicals,
                    ),
                    charts.Series<InstrumentHistorical, DateTime>(
                      id: 'High',
                      colorFn: (_, __) =>
                          charts.MaterialPalette.green.shadeDefault,
                      domainFn: (InstrumentHistorical history, _) =>
                          history.beginsAt!,
                      measureFn: (InstrumentHistorical history, _) =>
                          history.highPrice,
                      data: optionInstrumentHistoricalsObj.historicals,
                    ),
                  ],
                  open:
                      optionInstrumentHistoricalsObj.historicals[0].openPrice!,
                  close: optionInstrumentHistoricalsObj
                      .historicals[
                          optionInstrumentHistoricalsObj.historicals.length - 1]
                      .closePrice!,
                  hiddenSeries: const ["Close", "Low", "High"],
                  onSelected: (dynamic historical) {
                var provider = Provider.of<InstrumentHistoricalsSelectionStore>(
                    context,
                    listen: false);
                provider.selectionChanged(historical);
                /*
                if (selection != historical) {
                  setState(() {
                    selection = historical;
                  });
                }
                */
              });
              //}

              return SliverToBoxAdapter(
                  child: Column(
                children: [
                  Consumer<InstrumentHistoricalsSelectionStore>(
                      builder: (context, value, child) {
                    selection = value.selection;

                    return SizedBox(
                        height: 36,
                        child: Center(
                            child: Column(
                          children: [
                            Wrap(
                              children: [
                                Text(
                                    formatCurrency.format(selection != null
                                        ? selection!.closePrice
                                        : close),
                                    style: TextStyle(
                                        fontSize: 20, color: textColor)),
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
                                  //size: 16.0
                                ),
                                Container(
                                  width: 2,
                                ),
                                Text(
                                    formatPercentage
                                        //.format(selection!.netReturn!.abs()),
                                        .format(changePercentInPeriod.abs()),
                                    style: TextStyle(
                                        fontSize: 20.0, color: textColor)),
                                Container(
                                  width: 10,
                                ),
                                Text(
                                    "${changeInPeriod > 0 ? "+" : changeInPeriod < 0 ? "-" : ""}${formatCurrency.format(changeInPeriod.abs())}",
                                    style: TextStyle(
                                        fontSize: 20.0, color: textColor)),
                              ],
                            ),
                            Text(
                                '${formatMediumDate.format(firstHistorical!.beginsAt!.toLocal())} - ${formatMediumDate.format(selection != null ? selection!.beginsAt!.toLocal() : lastHistorical!.beginsAt!.toLocal())}',
                                style:
                                    TextStyle(fontSize: 10, color: textColor)),
                          ],
                        )));
                  }),
                  SizedBox(
                      height: 240,
                      child: Padding(
                        //padding: EdgeInsets.symmetric(horizontal: 12.0),
                        padding: const EdgeInsets.all(10.0),
                        child: historicalChart,
                      )),
                  SizedBox(
                      height: 56,
                      child: ListView.builder(
                        key: const PageStorageKey<String>(
                            'instrumentChartFilters'),
                        padding: const EdgeInsets.all(5.0),
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (context, index) {
                          return Row(children: [
                            Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: ChoiceChip(
                                //avatar: const Icon(Icons.history_outlined),
                                //avatar: CircleAvatar(child: Text(optionCount.toString())),
                                label: const Text('Day'),
                                selected:
                                    chartDateSpanFilter == ChartDateSpan.day,
                                onSelected: (bool value) {
                                  if (value) {
                                    resetChart(
                                        ChartDateSpan.day, chartBoundsFilter);
                                  }
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: ChoiceChip(
                                //avatar: const Icon(Icons.history_outlined),
                                //avatar: CircleAvatar(child: Text(optionCount.toString())),
                                label: const Text('Week'),
                                selected:
                                    chartDateSpanFilter == ChartDateSpan.week,
                                onSelected: (bool value) {
                                  if (value) {
                                    resetChart(
                                        ChartDateSpan.week, chartBoundsFilter);
                                  }
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: ChoiceChip(
                                //avatar: const Icon(Icons.history_outlined),
                                //avatar: CircleAvatar(child: Text(optionCount.toString())),
                                label: const Text('Month'),
                                selected:
                                    chartDateSpanFilter == ChartDateSpan.month,
                                onSelected: (bool value) {
                                  if (value) {
                                    resetChart(
                                        ChartDateSpan.month, chartBoundsFilter);
                                  }
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: ChoiceChip(
                                //avatar: const Icon(Icons.history_outlined),
                                //avatar: CircleAvatar(child: Text(optionCount.toString())),
                                label: const Text('3 Months'),
                                selected: chartDateSpanFilter ==
                                    ChartDateSpan.month_3,
                                onSelected: (bool value) {
                                  if (value) {
                                    resetChart(ChartDateSpan.month_3,
                                        chartBoundsFilter);
                                  }
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: ChoiceChip(
                                //avatar: const Icon(Icons.history_outlined),
                                //avatar: CircleAvatar(child: Text(optionCount.toString())),
                                label: const Text('Year'),
                                selected:
                                    chartDateSpanFilter == ChartDateSpan.year,
                                onSelected: (bool value) {
                                  if (value) {
                                    resetChart(
                                        ChartDateSpan.year, chartBoundsFilter);
                                  }
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: ChoiceChip(
                                //avatar: const Icon(Icons.history_outlined),
                                //avatar: CircleAvatar(child: Text(optionCount.toString())),
                                label: const Text('5 Years'),
                                selected:
                                    chartDateSpanFilter == ChartDateSpan.year_5,
                                onSelected: (bool value) {
                                  if (value) {
                                    resetChart(ChartDateSpan.year_5,
                                        chartBoundsFilter);
                                  }
                                },
                              ),
                            ),
                            /*
                            Container(
                              width: 10,
                            ),
                            Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: ChoiceChip(
                                //avatar: const Icon(Icons.history_outlined),
                                //avatar: CircleAvatar(child: Text(optionCount.toString())),
                                label: const Text('Regular Hours'),
                                selected: chartBoundsFilter == Bounds.regular,
                                onSelected: (bool value) {
                                  if (value) {
                                    resetChart(
                                        chartDateSpanFilter, Bounds.regular);
                                  }
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: ChoiceChip(
                                //avatar: const Icon(Icons.history_outlined),
                                //avatar: CircleAvatar(child: Text(optionCount.toString())),
                                label: const Text('24/7 Hours'),
                                selected: chartBoundsFilter == Bounds.t24_7,
                                onSelected: (bool value) {
                                  if (value) {
                                    resetChart(
                                        chartDateSpanFilter, Bounds.t24_7);
                                  }
                                },
                              ),
                            ),
                            */
                          ]);
                        },
                        itemCount: 1,
                      ))
                ],
              ));
            }
            return SliverToBoxAdapter(child: Container());
          }),
          SliverToBoxAdapter(
            child: ListTile(
              title: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text("Greeks & Market Data",
                        style: TextStyle(fontSize: 20.0)),
                    Container(
                      width: 5,
                    ),
                    IconButton(
                        icon: const Icon(Icons.info_outline),
                        tooltip: "Greeks Help",
                        onPressed: () => showDialog<String>(
                              context: context,
                              builder: (BuildContext context) => AlertDialog(
                                title: const Text('Greeks'),
                                content: SingleChildScrollView(
                                    child: Column(children: const [
                                  Text(
                                      "Delta, Δ, measures the rate of change of the theoretical option value with respect to changes in the underlying asset's price.\n"),
                                  //Another way of thinking about the metric is that it can give an idea of whether an option will end up in the money at the expiration date. As an option moves further into the money, the delta value will head away from 0. For a call option, it will head toward a value of 1, while a put option will head toward a value of -1. As the option moves further out of the money, the delta value will head towards 0.
                                  Text(
                                      "Gamma, Γ, measures the rate of change in the delta with respect to changes in the underlying price.\n"),
                                  Text(
                                      "Theta, Θ, measures the sensitivity of the value of the derivative to the passage of time.\n"),
                                  Text(
                                      "Vega, v, measures sensitivity to volatility.\n"),
                                  Text(
                                      "Rho, p, measures sensitivity to the interest rate."),
                                ])),
                                actions: <Widget>[
                                  /*
                    TextButton(
                      onPressed: () => Navigator.pop(context, 'Cancel'),
                      child: const Text('Cancel'),
                    ),
                    */
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, 'OK'),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            ))
                  ]),
            ),
          ),
          SliverToBoxAdapter(
              child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (optionInstrument.optionMarketData!.delta !=
                                null) ...[
                              Card(
                                  child: Padding(
                                padding: const EdgeInsets.all(
                                    6), //.symmetric(horizontal: 6),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Text(
                                          formatNumber.format(optionInstrument
                                              .optionMarketData!.delta),
                                          style:
                                              const TextStyle(fontSize: 17.0)),
                                      Container(
                                        height: 5,
                                      ),
                                      const Text("Δ",
                                          style: TextStyle(fontSize: 17.0)),
                                      const Text("Delta",
                                          style: TextStyle(fontSize: 10.0)),
                                    ]),
                              )),
                            ],
                            if (optionInstrument.optionMarketData!.gamma !=
                                null) ...[
                              Card(
                                  child: Padding(
                                padding: const EdgeInsets.all(
                                    6), //.symmetric(horizontal: 6),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Text(
                                          formatNumber.format(optionInstrument
                                              .optionMarketData!.gamma!),
                                          style:
                                              const TextStyle(fontSize: 17.0)),
                                      Container(
                                        height: 5,
                                      ),
                                      const Text("Γ",
                                          style: TextStyle(fontSize: 17.0)),
                                      const Text("Gamma",
                                          style: TextStyle(fontSize: 10.0)),
                                    ]),
                              )),
                            ],
                            if (optionInstrument.optionMarketData!.theta !=
                                null) ...[
                              Card(
                                  child: Padding(
                                padding: const EdgeInsets.all(
                                    6), //.symmetric(horizontal: 6),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Text(
                                          formatNumber.format(optionInstrument
                                              .optionMarketData!.theta!),
                                          style:
                                              const TextStyle(fontSize: 17.0)),
                                      Container(
                                        height: 5,
                                      ),
                                      const Text("Θ",
                                          style: TextStyle(fontSize: 17.0)),
                                      const Text("Theta",
                                          style: TextStyle(fontSize: 10.0)),
                                    ]),
                              )),
                            ],
                            if (optionInstrument.optionMarketData!.vega !=
                                null) ...[
                              Card(
                                  child: Padding(
                                padding: const EdgeInsets.all(
                                    6), //.symmetric(horizontal: 6),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Text(
                                          formatNumber.format(optionInstrument
                                              .optionMarketData!.vega!),
                                          style:
                                              const TextStyle(fontSize: 17.0)),
                                      Container(
                                        height: 5,
                                      ),
                                      const Text("v",
                                          style: TextStyle(fontSize: 17.0)),
                                      const Text("Vega",
                                          style: TextStyle(fontSize: 10.0)),
                                    ]),
                              )),
                            ],
                            if (optionInstrument.optionMarketData!.rho !=
                                null) ...[
                              Card(
                                  child: Padding(
                                padding: const EdgeInsets.all(
                                    6), //.symmetric(horizontal: 6),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Text(
                                          formatNumber.format(optionInstrument
                                              .optionMarketData!.rho!),
                                          style:
                                              const TextStyle(fontSize: 17.0)),
                                      Container(
                                        height: 5,
                                      ),
                                      const Text("p",
                                          style: TextStyle(fontSize: 17.0)),
                                      const Text("Rho",
                                          style: TextStyle(fontSize: 10.0)),
                                    ]),
                              )),
                            ],
                            if (optionInstrument
                                    .optionMarketData!.impliedVolatility !=
                                null) ...[
                              Card(
                                  child: Padding(
                                padding: const EdgeInsets.all(
                                    6), //.symmetric(horizontal: 6),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Text(
                                          formatPercentage.format(
                                              optionInstrument.optionMarketData!
                                                  .impliedVolatility),
                                          style:
                                              const TextStyle(fontSize: 17.0)),
                                      Container(
                                        height: 5,
                                      ),
                                      const Text("IV",
                                          style: TextStyle(fontSize: 17.0)),
                                      const Text("Impl. Vol.",
                                          style: TextStyle(fontSize: 10.0)),
                                    ]),
                              )),
                            ],
                            if (optionInstrument
                                    .optionMarketData!.chanceOfProfitLong !=
                                null) ...[
                              Card(
                                  child: Padding(
                                padding: const EdgeInsets.all(
                                    6), //.symmetric(horizontal: 6),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Text(
                                          formatPercentage.format(
                                              optionInstrument.optionMarketData!
                                                  .chanceOfProfitLong),
                                          style:
                                              const TextStyle(fontSize: 17.0)),
                                      Container(
                                        height: 5,
                                      ),
                                      const Text("%",
                                          style: TextStyle(fontSize: 17.0)),
                                      const Text("Chance Long",
                                          style: TextStyle(fontSize: 10.0)),
                                    ]),
                              )),
                            ],
                            if (optionInstrument
                                    .optionMarketData!.chanceOfProfitShort !=
                                null) ...[
                              Card(
                                  child: Padding(
                                padding: const EdgeInsets.all(
                                    6), //.symmetric(horizontal: 6),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Text(
                                          formatPercentage.format(
                                              optionInstrument.optionMarketData!
                                                  .chanceOfProfitShort),
                                          style:
                                              const TextStyle(fontSize: 17.0)),
                                      Container(
                                        height: 5,
                                      ),
                                      const Text("%",
                                          style: TextStyle(fontSize: 17.0)),
                                      const Text("Chance Short",
                                          style: TextStyle(fontSize: 10.0)),
                                    ]),
                              )),
                            ],
                            Card(
                                child: Padding(
                              padding: const EdgeInsets.all(
                                  6), //.symmetric(horizontal: 6),
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Text(
                                        formatCompactNumber.format(
                                            optionInstrument.optionMarketData!
                                                .openInterest),
                                        style: const TextStyle(fontSize: 17.0)),
                                    Container(
                                      height: 5,
                                    ),
                                    const Text("#",
                                        style: TextStyle(fontSize: 17.0)),
                                    const Text("Open Interest",
                                        style: TextStyle(fontSize: 10.0)),
                                  ]),
                            ))
                          ])))),
          /*
          SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 97.0),
                delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) {
                    switch (index) {
                      case 0:
                        return Card(
                            child: Padding(
                          padding: const EdgeInsets.all(
                              6), //.symmetric(horizontal: 6),
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                    formatNumber.format(optionInstrument
                                        .optionMarketData!.delta),
                                    style: const TextStyle(fontSize: 17.0)),
                                Container(
                                  height: 5,
                                ),
                                const Text("Δ",
                                    style: TextStyle(fontSize: 17.0)),
                                const Text("Delta",
                                    style: TextStyle(fontSize: 10.0)),
                              ]),
                        ));
                      case 1:
                        return Card(
                            child: Padding(
                          padding: const EdgeInsets.all(
                              6), //.symmetric(horizontal: 6),
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                    formatNumber.format(optionInstrument
                                        .optionMarketData!.gamma!),
                                    style: const TextStyle(fontSize: 17.0)),
                                Container(
                                  height: 5,
                                ),
                                const Text("Γ",
                                    style: TextStyle(fontSize: 17.0)),
                                const Text("Gamma",
                                    style: TextStyle(fontSize: 10.0)),
                              ]),
                        ));
                      case 2:
                        return Card(
                            child: Padding(
                          padding: const EdgeInsets.all(
                              6), //.symmetric(horizontal: 6),
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                    formatNumber.format(optionInstrument
                                        .optionMarketData!.theta!),
                                    style: const TextStyle(fontSize: 17.0)),
                                Container(
                                  height: 5,
                                ),
                                const Text("Θ",
                                    style: TextStyle(fontSize: 17.0)),
                                const Text("Theta",
                                    style: TextStyle(fontSize: 10.0)),
                              ]),
                        ));
                      case 3:
                        return Card(
                            child: Padding(
                          padding: const EdgeInsets.all(
                              6), //.symmetric(horizontal: 6),
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                    formatNumber.format(optionInstrument
                                        .optionMarketData!.vega!),
                                    style: const TextStyle(fontSize: 17.0)),
                                Container(
                                  height: 5,
                                ),
                                const Text("v",
                                    style: TextStyle(fontSize: 17.0)),
                                const Text("Vega",
                                    style: TextStyle(fontSize: 10.0)),
                              ]),
                        ));
                      case 4:
                        return Card(
                            child: Padding(
                          padding: const EdgeInsets.all(
                              6), //.symmetric(horizontal: 6),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: <
                                  Widget>[
                            Text(
                                formatNumber.format(
                                    optionInstrument.optionMarketData!.rho!),
                                style: const TextStyle(fontSize: 17.0)),
                            Container(
                              height: 5,
                            ),
                            const Text("p", style: TextStyle(fontSize: 17.0)),
                            const Text("Rho", style: TextStyle(fontSize: 10.0)),
                          ]),
                        ));
                      case 5:
                        return Card(
                            child: Padding(
                          padding: const EdgeInsets.all(
                              6), //.symmetric(horizontal: 6),
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                    formatNumber.format(optionInstrument
                                        .optionMarketData!.impliedVolatility),
                                    style: const TextStyle(fontSize: 17.0)),
                                Container(
                                  height: 5,
                                ),
                                const Text("IV",
                                    style: TextStyle(fontSize: 17.0)),
                                const Text("Implied Volatility",
                                    style: TextStyle(fontSize: 10.0)),
                              ]),
                        ));
                      case 6:
                        return Card(
                            child: Padding(
                          padding: const EdgeInsets.all(
                              6), //.symmetric(horizontal: 6),
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                    formatPercentage.format(optionInstrument
                                        .optionMarketData!.chanceOfProfitLong),
                                    style: const TextStyle(fontSize: 17.0)),
                                Container(
                                  height: 5,
                                ),
                                const Text("p",
                                    style: TextStyle(fontSize: 17.0)),
                                const Text("Change long",
                                    style: TextStyle(fontSize: 10.0)),
                              ]),
                        ));
                      case 7:
                        return Card(
                            child: Padding(
                          padding: const EdgeInsets.all(
                              6), //.symmetric(horizontal: 6),
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                    formatPercentage.format(optionInstrument
                                        .optionMarketData!.chanceOfProfitShort),
                                    style: const TextStyle(fontSize: 17.0)),
                                Container(
                                  height: 5,
                                ),
                                const Text("",
                                    style: TextStyle(fontSize: 17.0)),
                                const Text("Change short",
                                    style: TextStyle(fontSize: 10.0)),
                              ]),
                        ));
                      default:
                    }
                    /*
          return Container(
            alignment: Alignment.center,
            color: Colors.teal[100 * (index % 9)],
            child: Text('grid item $index'),
          );
          */
                  },
                  childCount: 8,
                ),
              )),
              */
          const SliverToBoxAdapter(
              child: SizedBox(
            height: 10.0,
          )),
          SliverToBoxAdapter(
              child: ListTile(
                  title: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                const Text("Days to Expiration",
                    style: TextStyle(fontSize: 20.0)),
                Container(
                  width: 5,
                ),
                SizedBox(
                    height: 75,
                    child: Padding(
                      padding: EdgeInsets.zero, // EdgeInsets.all(10.0),
                      child: chart,
                    ))

                //Chart(seriesList, onSelected: onSelected)
              ]))),
          SliverToBoxAdapter(
              child: Card(
                  child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const ListTile(
                  title: Text("Market Data", style: TextStyle(fontSize: 20))),
              ListTile(
                title: const Text("Break Even Price"),
                trailing: Text(
                    formatCurrency.format(
                        optionInstrument.optionMarketData!.breakEvenPrice),
                    style: const TextStyle(fontSize: 18)),
              ),
              ListTile(
                title: const Text("Bid - Mark - Ask"),
                trailing: Text(
                    "${formatCurrency.format(optionInstrument.optionMarketData!.bidPrice)} - ${formatCurrency.format(optionInstrument.optionMarketData!.markPrice)} - ${formatCurrency.format(optionInstrument.optionMarketData!.askPrice)}",
                    style: const TextStyle(fontSize: 18)),
              ),
              ListTile(
                title: const Text("Bid Size - Ask Size"),
                trailing: Text(
                    "${formatCompactNumber.format(optionInstrument.optionMarketData!.bidSize)} - ${formatCompactNumber.format(optionInstrument.optionMarketData!.askSize)}",
                    style: const TextStyle(fontSize: 18)),
              ),
              ListTile(
                title: const Text("Adjusted Mark Price"),
                trailing: Text(
                    formatCurrency.format(
                        optionInstrument.optionMarketData!.adjustedMarkPrice),
                    style: const TextStyle(fontSize: 18)),
              ),
              ListTile(
                title: const Text("Last Trade"),
                trailing: Text(
                    "${formatCurrency.format(optionInstrument.optionMarketData!.lastTradePrice)} x ${formatCompactNumber.format(optionInstrument.optionMarketData!.lastTradeSize)}",
                    style: const TextStyle(fontSize: 18)),
              ),
              ListTile(
                title: const Text("Low Price - High Price"),
                trailing: Text(
                    optionInstrument.optionMarketData!.lowPrice != null &&
                            optionInstrument.optionMarketData!.highPrice != null
                        ? "${formatCurrency.format(optionInstrument.optionMarketData!.lowPrice)} - ${formatCurrency.format(optionInstrument.optionMarketData!.highPrice)}"
                        : "-",
                    style: const TextStyle(fontSize: 18)),
              ),
              ListTile(
                title: Text(
                    "Previous Close (${formatDate.format(optionInstrument.optionMarketData!.previousCloseDate!)})"),
                trailing: Text(
                    formatCurrency.format(
                        optionInstrument.optionMarketData!.previousClosePrice),
                    style: const TextStyle(fontSize: 18)),
              ),
              ListTile(
                title: const Text("Volume"),
                trailing: Text(
                    formatCompactNumber
                        .format(optionInstrument.optionMarketData!.volume),
                    style: const TextStyle(fontSize: 18)),
              ),
              /*
              ListTile(
                title: const Text("Open Interest"),
                trailing: Text(
                    formatCompactNumber.format(
                        optionInstrument.optionMarketData!.openInterest),
                    style: const TextStyle(fontSize: 18)),
              ),
              ListTile(
                title: const Text("Implied Volatility"),
                trailing: Text(
                    formatPercentage.format(
                        optionInstrument.optionMarketData!.impliedVolatility),
                    style: const TextStyle(fontSize: 18)),
              ),
              ListTile(
                title: const Text("Chance of Profit (Long)"),
                trailing: Text(
                    formatPercentage.format(
                        optionInstrument.optionMarketData!.chanceOfProfitLong),
                    style: const TextStyle(fontSize: 18)),
              ),
              ListTile(
                title: const Text("Chance of Profit (Short)"),
                trailing: Text(
                    formatPercentage.format(
                        optionInstrument.optionMarketData!.chanceOfProfitShort),
                    style: const TextStyle(fontSize: 18)),
              ),
              */
              /*
          ListTile(
            title: const Text("Delta"),
            trailing: Text(
                "${optionInstrument.optionMarketData!.delta}",
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Gamma"),
            trailing: Text(
                "${optionInstrument.optionMarketData!.gamma}",
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Theta"),
            trailing: Text(
                "${optionInstrument.optionMarketData!.theta}",
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Vega"),
            trailing: Text(
                "${optionInstrument.optionMarketData!.vega}",
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Rho"),
            trailing: Text(
                "${optionInstrument.optionMarketData!.rho}",
                style: const TextStyle(fontSize: 18)),
          ),
          */
            ],
          ))),
          SliverToBoxAdapter(
              child: Card(
                  child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const ListTile(
                title: Text("Option", style: TextStyle(fontSize: 20)),
                /*
              trailing: Wrap(children: [
                IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Buy',
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => TradeOptionWidget(user,
                                optionPosition: optionPosition,
                                positionType: "Buy")))),
                IconButton(
                    icon: const Icon(Icons.remove),
                    tooltip: 'Sell',
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => TradeOptionWidget(
                                  user,
                                  optionPosition: optionPosition,
                                  positionType: "Sell",
                                ))))
              ])*/
              ),
              if (optionPosition != null) ...[
                ListTile(
                  title: const Text("Contracts"),
                  trailing: Text(
                      "${optionPosition.quantity!.round()} ${optionPosition.legs.first.positionType} ${optionPosition.legs.first.optionType}",
                      style: const TextStyle(fontSize: 18)),
                ),
              ],
              ListTile(
                title: const Text("Strike"),
                trailing: Text(
                    formatCurrency.format(optionInstrument.strikePrice),
                    style: const TextStyle(fontSize: 18)),
              ),
              ListTile(
                title: const Text("Expiration"),
                trailing: Text(
                    formatDate.format(optionInstrument.expirationDate!),
                    style: const TextStyle(fontSize: 18)),
              ),
              if (optionPosition != null) ...[
                if (optionPosition.legs.first.positionType == "long") ...[
                  ListTile(
                      title: const Text("Average Open Price"),
                      trailing: Text(
                          formatCurrency
                              .format(optionPosition.averageOpenPrice),
                          style: const TextStyle(fontSize: 18))),
                  ListTile(
                    title: const Text("Total Cost"),
                    trailing: Text(
                        formatCurrency.format(optionPosition.totalCost),
                        style: const TextStyle(fontSize: 18)),
                  )
                ] else ...[
                  ListTile(
                    title: const Text("Credit"),
                    trailing: Text(
                        formatCurrency.format(optionPosition.averageOpenPrice),
                        style: const TextStyle(fontSize: 18)),
                  ),
                  ListTile(
                    title: const Text("Short Collateral"),
                    trailing: Text(
                        formatCurrency.format(optionPosition.shortCollateral),
                        style: const TextStyle(fontSize: 18)),
                  ),
                  ListTile(
                    title: const Text("Credit to Collateral"),
                    trailing: Text(
                        formatPercentage
                            .format(optionPosition.collateralReturn),
                        style: const TextStyle(fontSize: 18)),
                  ),
                ],
                ListTile(
                  title: const Text("Market Value"), //Equity
                  trailing: Text(
                      formatCurrency.format(optionPosition.marketValue),
                      style: const TextStyle(fontSize: 18)),
                ),
                ListTile(
                    title: const Text("Return"),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        Icon(
                          optionPosition.gainLossPerContract > 0
                              ? Icons.trending_up
                              : (optionPosition.gainLossPerContract < 0
                                  ? Icons.trending_down
                                  : Icons.trending_flat),
                          color: (optionPosition.gainLossPerContract > 0
                              ? Colors.green
                              : (optionPosition.gainLossPerContract < 0
                                  ? Colors.red
                                  : Colors.grey)),
                        ), //size: 18.0
                        Text(
                          formatCurrency.format(optionPosition.gainLoss),
                          style: const TextStyle(fontSize: 18.0),
                          textAlign: TextAlign.right,
                        ),
                      ],
                    )
                    /*
            Text("${formatCurrency.format(optionPosition!.gainLoss)}",
                style: const TextStyle(fontSize: 18)),
                */
                    ),
                ListTile(
                  title: const Text("Return %"),
                  trailing: Text(
                      formatPercentage.format(optionPosition.gainLossPercent),
                      style: const TextStyle(fontSize: 18)),
                ),
                ListTile(
                  title: const Text("Created"),
                  trailing: Text(formatDate.format(optionPosition.createdAt!),
                      style: const TextStyle(fontSize: 18)),
                ),
                ListTile(
                  title: const Text("Updated"),
                  trailing: Text(formatDate.format(optionPosition.updatedAt!),
                      style: const TextStyle(fontSize: 18)),
                ),
              ],
              ListTile(
                title: const Text("Days to Expiration"),
                trailing: Text("${dte.isNegative ? 0 : dte} of $originalDte",
                    style: const TextStyle(fontSize: 18)),
              ),
            ],
          ))),
          if (optionPosition != null && optionPosition.legs.length > 1) ...[
            SliverToBoxAdapter(
                child: Card(
                    child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _buildLegs(optionPosition).toList(),
            ))),
          ],
          if (optionInstrumentOrders != null &&
              optionInstrumentOrders.isNotEmpty) ...[
            const SliverToBoxAdapter(
                child: SizedBox(
              height: 25.0,
            )),
            OptionOrdersWidget(
              widget.user,
              //widget.account,
              optionInstrumentOrders,
              const ["confirmed", "filled"],
              analytics: widget.analytics,
              observer: widget.observer,
            )
          ],
          const SliverToBoxAdapter(
              child: SizedBox(
            height: 25.0,
          )),
          const SliverToBoxAdapter(child: DisclaimerWidget())
        ]));
  }

  SliverAppBar _buildSliverAppBar(OptionInstrumentStore optionInstrumentStore,
      OptionAggregatePosition? optionPosition, Instrument? instrument) {
    var optionInstrument = optionInstrumentStore.items.firstWhereOrNull(
        (element) => element.id == widget.optionInstrument.id);
    optionInstrument ??= widget.optionInstrument;
    //if (optionInstrument != null) {
    return SliverAppBar(
        title: Wrap(spacing: 20, children: [
          Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              //runAlignment: WrapAlignment.end,
              //alignment: WrapAlignment.end,
              spacing: 10,
              //runSpacing: 5,
              children: [
                Text(optionInstrument.chainSymbol),
                Text("\$${optionInstrument.strikePrice}"),
                Text(optionInstrument.type.toUpperCase()),
                Text(formatDate.format(optionInstrument.expirationDate!)),
              ]),
          if (optionInstrument.optionMarketData != null) ...[
            Wrap(spacing: 10, children: [
              Text(
                  formatCurrency.format(optionInstrument
                      .optionMarketData!.adjustedMarkPrice), //lastTradePrice
                  //style: const TextStyle(fontSize: 15.0)
                  style:
                      const TextStyle(fontSize: 16.0, color: Colors.white70)),
              Wrap(children: [
                Icon(
                    optionInstrument.optionMarketData!.changeToday > 0
                        ? Icons.trending_up
                        : (optionInstrument.optionMarketData!.changeToday < 0
                            ? Icons.trending_down
                            : Icons.trending_flat),
                    color: (optionInstrument.optionMarketData!.changeToday > 0
                        ? Colors.lightGreenAccent
                        : (optionInstrument.optionMarketData!.changeToday < 0
                            ? Colors.red
                            : Colors.grey)),
                    size: 20.0),
                Container(
                  width: 2,
                ),
                Text(
                    formatPercentage.format(
                        optionInstrument.optionMarketData!.changePercentToday),
                    //style: const TextStyle(fontSize: 15.0)
                    style:
                        const TextStyle(fontSize: 16.0, color: Colors.white70)),
              ]),
              Text(
                  "${optionInstrument.optionMarketData!.changeToday > 0 ? "+" : optionInstrument.optionMarketData!.changeToday < 0 ? "-" : ""}${formatCurrency.format(optionInstrument.optionMarketData!.changeToday.abs())}",
                  //style: const TextStyle(fontSize: 12.0),
                  style: const TextStyle(fontSize: 16.0, color: Colors.white70),
                  textAlign: TextAlign.right)
            ])
          ],
        ]),
        expandedHeight: optionPosition != null ? 240 : 160,
        floating: false,
        pinned: true,
        snap: false,
        flexibleSpace: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
          //var top = constraints.biggest.height;
          //debugPrint(top.toString());
          //debugPrint(kToolbarHeight.toString());

          final settings = context
              .dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
          final deltaExtent = settings!.maxExtent - settings.minExtent;
          final t = (1.0 -
                  (settings.currentExtent - settings.minExtent) / deltaExtent)
              .clamp(0.0, 1.0);
          final fadeStart = math.max(0.0, 1.0 - kToolbarHeight / deltaExtent);
          const fadeEnd = 1.0;
          final opacity = 1.0 - Interval(fadeStart, fadeEnd).transform(t);
          return FlexibleSpaceBar(
              background: Hero(
                  tag: widget.heroTag != null
                      ? '${widget.heroTag}'
                      : 'logo_${widget.optionInstrument.chainSymbol}',
                  child: SizedBox(
                      width: double.infinity,
                      child: instrument != null && instrument.logoUrl != null
                          ? Image.network(
                              instrument.logoUrl!,
                              fit: BoxFit.none,
                              errorBuilder: (BuildContext context,
                                  Object exception, StackTrace? stackTrace) {
                                return Text(instrument.symbol);
                              },
                            )
                          : Container()) //const FlutterLogo()
                  /*Image.network(
                              Constants.flexibleSpaceBarBackground,
                              fit: BoxFit.cover,
                            ),*/
                  ),
              title: Opacity(
                  //duration: Duration(milliseconds: 300),
                  opacity: opacity, //top > kToolbarHeight * 3 ? 1.0 : 0.0,
                  child: SingleChildScrollView(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        if (optionPosition != null) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Container(
                                width: 10,
                              ),
                              Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: const [
                                    SizedBox(
                                      width: 70,
                                      child: Text(
                                        "Strategy",
                                        style: TextStyle(fontSize: 10.0),
                                      ),
                                    )
                                  ]),
                              Container(
                                width: 5,
                              ),
                              SizedBox(
                                  width: 115,
                                  child: Text(
                                      "${optionPosition.strategy.split('_').first} ${optionPosition.optionInstrument!.type}",
                                      style: const TextStyle(fontSize: 12.0),
                                      textAlign: TextAlign.right)),
                              Container(
                                width: 10,
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Container(
                                width: 10,
                              ),
                              Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: const [
                                    SizedBox(
                                      width: 70,
                                      child: Text(
                                        "Contracts",
                                        style: TextStyle(fontSize: 10.0),
                                      ),
                                    )
                                  ]),
                              Container(
                                width: 5,
                              ),
                              SizedBox(
                                  width: 115,
                                  child: Text(
                                      "${optionPosition.direction == "debit" ? "+" : "-"}${formatCompactNumber.format(optionPosition.quantity)}",
                                      style: const TextStyle(fontSize: 12.0),
                                      textAlign: TextAlign.right)),
                              Container(
                                width: 10,
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Container(
                                width: 10,
                              ),
                              Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 70,
                                      child: Text(
                                        optionPosition
                                                    .legs.first.positionType ==
                                                "long"
                                            ? "Cost"
                                            : "Credit",
                                        style: const TextStyle(fontSize: 10.0),
                                      ),
                                    )
                                  ]),
                              Container(
                                width: 5,
                              ),
                              Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: const [
                                    SizedBox(
                                        width: 40,
                                        child: Text(
                                            "", //${formatPercentage.format(1)}
                                            style: TextStyle(fontSize: 10.0),
                                            textAlign: TextAlign.right))
                                  ]),
                              Container(
                                width: 5,
                              ),
                              SizedBox(
                                  width: 70,
                                  child: Text(
                                      formatCurrency
                                          .format(optionPosition.totalCost),
                                      style: const TextStyle(fontSize: 12.0),
                                      textAlign: TextAlign.right)),
                              Container(
                                width: 10,
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Container(
                                width: 10,
                              ),
                              Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: const [
                                    SizedBox(
                                      width: 70,
                                      child: Text(
                                        "Market Value",
                                        style: TextStyle(fontSize: 10.0),
                                      ),
                                    )
                                  ]),
                              Container(
                                width: 5,
                              ),
                              Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: const [
                                    SizedBox(
                                        width: 40,
                                        child: Text(
                                            "", //${formatPercentage.format(1)}
                                            style: TextStyle(fontSize: 10.0),
                                            textAlign: TextAlign.right))
                                  ]),
                              Container(
                                width: 5,
                              ),
                              SizedBox(
                                  width: 70,
                                  child: Text(
                                      formatCurrency
                                          .format(optionPosition.marketValue),
                                      style: const TextStyle(fontSize: 12.0),
                                      textAlign: TextAlign.right)),
                              Container(
                                width: 10,
                              ),
                            ],
                          ),
                          Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Container(
                                  width: 10,
                                ),
                                Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: const [
                                      SizedBox(
                                        width: 55,
                                        child: Text(
                                          "Today",
                                          style: TextStyle(fontSize: 10.0),
                                        ),
                                      )
                                    ]),
                                Container(
                                  width: 5,
                                ),
                                Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                          width: 65,
                                          child: Wrap(
                                              alignment: WrapAlignment.end,
                                              children: [
                                                optionPosition
                                                    .trendingIconToday,
                                                Container(
                                                  width: 2,
                                                ),
                                                Text(
                                                    formatPercentage.format(
                                                        optionPosition
                                                            .changePercentToday
                                                            .abs()),
                                                    style: const TextStyle(
                                                        fontSize: 12.0),
                                                    textAlign: TextAlign.right),
                                              ]))
                                    ]),
                                Container(
                                  width: 5,
                                ),
                                SizedBox(
                                    width: 60,
                                    child: Text(
                                        "${optionPosition.changeToday > 0 ? "+" : optionPosition.changeToday < 0 ? "-" : ""}${formatCurrency.format(optionPosition.changeToday.abs())}",
                                        style: const TextStyle(fontSize: 12.0),
                                        textAlign: TextAlign.right)),
                                Container(
                                  width: 10,
                                ),
                              ]),
                          Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Container(
                                  width: 10,
                                ),
                                Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: const [
                                      SizedBox(
                                        width: 55,
                                        child: Text(
                                          "Return",
                                          style: TextStyle(fontSize: 10.0),
                                        ),
                                      )
                                    ]),
                                Container(
                                  width: 5,
                                ),
                                Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                          width: 65,
                                          child: Wrap(
                                              alignment: WrapAlignment.end,
                                              children: [
                                                optionPosition.trendingIcon,
                                                Container(
                                                  width: 2,
                                                ),
                                                Text(
                                                    formatPercentage.format(
                                                        optionPosition
                                                            .gainLossPercent
                                                            .abs()),
                                                    style: const TextStyle(
                                                        fontSize: 12.0),
                                                    textAlign: TextAlign.right),
                                              ]))
                                    ]),
                                Container(
                                  width: 5,
                                ),
                                SizedBox(
                                    width: 60,
                                    child: Text(
                                        "${optionPosition.gainLoss > 0 ? "+" : optionPosition.gainLoss < 0 ? "-" : ""}${formatCurrency.format(optionPosition.gainLoss.abs())}",
                                        style: const TextStyle(fontSize: 12.0),
                                        textAlign: TextAlign.right)),
                                Container(
                                  width: 10,
                                ),
                              ]),
                        ],
                      ]))));
          /*
        actions: <Widget>[
          IconButton(
              icon: const Icon(Icons.shopping_cart),
              tooltip: 'Trade',
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => TradeOptionWidget(user,
                          optionInstrument: optionInstrument)))),
        ]*/
        }));
    /*} else {
      return const SliverAppBar();
    }*/
  }

  void _startRefreshTimer() {
    // Start listening to clipboard
    refreshTriggerTime = Timer.periodic(
      const Duration(milliseconds: 15000),
      (timer) async {
        if (widget.user.refreshEnabled) {
          await RobinhoodService.getOptionHistoricals(
              widget.user,
              Provider.of<OptionHistoricalsStore>(context, listen: false),
              [widget.optionInstrument.id],
              chartBoundsFilter: chartBoundsFilter,
              chartDateSpanFilter: chartDateSpanFilter);
          /*
          if (futureHistoricals != null) {
            setState(() {
              futureHistoricals = null;
            });
          }
          */
        }
      },
    );
  }

  void _stopRefreshTimer() {
    if (refreshTriggerTime != null) {
      refreshTriggerTime!.cancel();
    }
  }

  void resetChart(ChartDateSpan span, Bounds bounds) {
    setState(() {
      chartDateSpanFilter = span;
      chartBoundsFilter = bounds;
      futureHistoricals = null;
    });
  }

  Future<void> _pullRefresh() async {
    var quoteStore = Provider.of<QuoteStore>(context, listen: false);

    var quote = await RobinhoodService.getQuote(
        widget.user, quoteStore, widget.optionInstrument.chainSymbol);

    setState(() {
      futureQuote = null;
      futureInstrument = null;
      futureQuote = Future.value(quote);
    });
  }

  Iterable<Widget> _buildLegs(OptionAggregatePosition optionPosition) sync* {
    for (int i = 0; i < optionPosition.legs.length; i++) {
      var leg = optionPosition.legs[i];
      yield ListTile(
          title: Text("Leg ${i + 1}", style: const TextStyle(fontSize: 20)));
      // yield Text("Leg ${i + 1}", style: TextStyle(fontSize: 20));
      yield ListTile(
        title: const Text("Expiration Date"),
        trailing: Text(formatDate.format(leg.expirationDate!),
            style: const TextStyle(fontSize: 18)),
      );
      yield ListTile(
        title: const Text("Position Type"),
        trailing:
            Text("${leg.positionType}", style: const TextStyle(fontSize: 18)),
      );
      yield ListTile(
        title: const Text("Position Effect"),
        trailing:
            Text("${leg.positionEffect}", style: const TextStyle(fontSize: 18)),
      );
      yield ListTile(
        title: const Text("Option Type"),
        trailing: Text(leg.optionType, style: const TextStyle(fontSize: 18)),
      );
      yield ListTile(
        title: const Text("Strike Price"),
        trailing: Text(formatCurrency.format(leg.strikePrice),
            style: const TextStyle(fontSize: 18)),
      );
      yield ListTile(
        title: const Text("Ratio Quantity"),
        trailing:
            Text("${leg.ratioQuantity}", style: const TextStyle(fontSize: 18)),
      );
    }
  }

  Card buildOverview(RobinhoodUser user, OptionInstrument optionInstrument,
      Instrument instrument,
      {OptionAggregatePosition? optionPosition}) {
    return Card(
        child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ListTile(
          // leading: const Icon(Icons.album),
          title: Text('${instrument.simpleName}'),
          subtitle: Text(instrument.name),
          trailing: Wrap(
            spacing: 8,
            children: [
              Icon(
                  instrument.quoteObj!.changeToday > 0
                      ? Icons.trending_up
                      : (instrument.quoteObj!.changeToday < 0
                          ? Icons.trending_down
                          : Icons.trending_flat),
                  color: (instrument.quoteObj!.changeToday > 0
                      ? Colors.green
                      : (instrument.quoteObj!.changeToday < 0
                          ? Colors.red
                          : Colors.grey))),
              Text(
                formatCurrency.format(instrument.quoteObj!.lastTradePrice),
                style: const TextStyle(fontSize: 18.0),
                textAlign: TextAlign.right,
              ),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            TextButton(
              child: const Text('VIEW STOCK'),
              onPressed: () {
                /*
                _navKey.currentState!.push(
                  MaterialPageRoute(
                    builder: (_) => SubSecondPage(),
                  ),
                );
                */
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => InstrumentWidget(
                              user,
                              //widget.account,
                              instrument,
                              //optionPosition: optionPosition
                              analytics: widget.analytics,
                              observer: widget.observer,
                            )));
              },
            ),
            if (optionPosition != null) ...[
              Container(width: 50),
              TextButton(
                  child: Text(optionPosition.direction == "debit"
                      ? "BUY TO OPEN"
                      : "BUY TO CLOSE"),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => TradeOptionWidget(
                                user,
                                //widget.account,
                                optionPosition: optionPosition,
                                optionInstrument: optionInstrument,
                                positionType: "Buy",
                                analytics: widget.analytics,
                                observer: widget.observer,
                              )))),
              TextButton(
                  child: Text(optionPosition.direction == "debit"
                      ? "SELL TO CLOSE"
                      : "SELL TO OPEN"),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => TradeOptionWidget(
                                user,
                                //widget.account,
                                optionPosition: optionPosition,
                                optionInstrument: optionInstrument,
                                positionType: "Sell",
                                analytics: widget.analytics,
                                observer: widget.observer,
                              )))),
            ] else ...[
              TextButton(
                  child: const Text('TRADE'),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => TradeOptionWidget(
                                user,
                                //widget.account,
                                optionInstrument: optionInstrument,
                                analytics: widget.analytics,
                                observer: widget.observer,
                              )))),
            ],
            const SizedBox(width: 8),
          ],
        ),
      ],
    ));
  }
}
