import 'dart:async';
import 'dart:math' as math;
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
//import 'package:charts_flutter/flutter.dart' as charts;
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/forex_historicals.dart';
import 'package:robinhood_options_mobile/model/forex_holding.dart';
import 'package:robinhood_options_mobile/model/forex_quote.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/chart_time_series_widget.dart';
import 'package:robinhood_options_mobile/widgets/disclaimer_widget.dart';
import 'package:robinhood_options_mobile/model/instrument_historical.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';

final formatDate = DateFormat.yMMMEd(); //.yMEd(); //("yMMMd");
final formatMediumDate = DateFormat("EEE MMM d, y hh:mm:ss a");
final formatLongDate = DateFormat("EEEE MMMM d, y hh:mm:ss a");
final formatCompactDate = DateFormat("MMMd");
final formatCurrency = NumberFormat.simpleCurrency();
final formatPercentage = NumberFormat.decimalPercentPattern(decimalDigits: 2);
final formatCompactNumber = NumberFormat.compact();

class ForexInstrumentWidget extends StatefulWidget {
  const ForexInstrumentWidget(
    this.user,
    this.service,
    //this.account,
    this.holding, {
    super.key,
    required this.analytics,
    required this.observer,
  });

  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser user;
  final IBrokerageService service;
  //final Account account;
  final ForexHolding holding;
  //final OptionAggregatePosition? optionPosition;

  @override
  State<ForexInstrumentWidget> createState() => _ForexInstrumentWidgetState();
}

class _ForexInstrumentWidgetState extends State<ForexInstrumentWidget>
    with AutomaticKeepAliveClientMixin<ForexInstrumentWidget> {
  Future<dynamic>? futureQuote;
  Future<ForexHistoricals>? futureHistoricals;

  //charts.TimeSeriesChart? chart;
  TimeSeriesChart? chart;
  ChartDateSpan chartDateSpanFilter = ChartDateSpan.day;
  Bounds chartBoundsFilter = Bounds.t24_7; //regular
  InstrumentHistorical? selection;

  //final dataKey = GlobalKey();

  //_ForexInstrumentWidgetState();
  Timer? refreshTriggerTime;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    _startRefreshTimer();
    widget.analytics.logScreenView(
        screenName: 'ForexInstrument/${widget.holding.currencyId}');
  }

  @override
  void dispose() {
    _stopRefreshTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.holding.quoteObj == null) {
      var forexPair = RobinhoodService.forexPairs.singleWhere((element) =>
          element['asset_currency']['id'] == widget.holding.currencyId);
      futureQuote ??=
          widget.service.getForexQuote(widget.user, forexPair['id']);
    } else {
      futureQuote ??= Future.value(widget.holding.quoteObj);
    }

    return Scaffold(
        body: FutureBuilder(
      future: futureQuote,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          widget.holding.quoteObj = snapshot.data! as ForexQuote;

          futureHistoricals ??= widget.service.getForexHistoricals(
              widget.user, widget.holding.quoteObj!.id,
              chartBoundsFilter: chartBoundsFilter,
              chartDateSpanFilter: chartDateSpanFilter);

          return FutureBuilder<ForexHistoricals>(
              future: futureHistoricals,
              builder: (context11, historicalsSnapshot) {
                if (historicalsSnapshot.hasData) {
                  var data = historicalsSnapshot.data!;
                  if (widget.holding.historicalsObj == null ||
                      data.bounds != widget.holding.historicalsObj!.bounds ||
                      data.span != widget.holding.historicalsObj!.span) {
                    chart = null;

                    if (data.span == "day") {
                      final DateTime now = DateTime.now();
                      final DateTime today =
                          DateTime(now.year, now.month, now.day);

                      data.historicals = data.historicals
                          .where((element) =>
                              element.beginsAt!.compareTo(today) >= 0)
                          .toList();
                    }
                    widget.holding.historicalsObj = data;
                  }
                }
                return buildScrollView(widget.holding,
                    done: snapshot.connectionState == ConnectionState.done &&
                        historicalsSnapshot.connectionState ==
                            ConnectionState.done);
              });
        }
        /* else if (snapshot.hasError) {
          debugPrint("${snapshot.error}");
          return Text("${snapshot.error}");
        }*/
        return buildScrollView(widget.holding,
            done: snapshot.connectionState == ConnectionState.done);
      },
    ));
  }

  void resetChart(ChartDateSpan span, Bounds bounds) {
    setState(() {
      chartDateSpanFilter = span;
      chartBoundsFilter = bounds;
      futureHistoricals = null;
    });
  }

  buildScrollView(ForexHolding holding, {bool done = false}) {
    InstrumentHistorical? firstHistorical;
    InstrumentHistorical? lastHistorical;
    double open = 0;
    double close = 0;
    double changeInPeriod = 0;
    double changePercentInPeriod = 0;

    if (holding.historicalsObj != null) {
      firstHistorical = holding.historicalsObj!.historicals[0];
      lastHistorical = holding.historicalsObj!
          .historicals[holding.historicalsObj!.historicals.length - 1];
      open = firstHistorical.openPrice!;
      close = lastHistorical.closePrice!;
      changeInPeriod = close - open;
      changePercentInPeriod = close / open - 1; // changeInPeriod / close;

      if (selection != null) {
        changeInPeriod = selection!.closePrice! -
            open; // portfolios![0].equityPreviousClose!;
        changePercentInPeriod = selection!.closePrice! / open -
            1; // changeInPeriod / selection!.closePrice!;
      }

      if (chart == null) {
        List<charts.Series<dynamic, DateTime>> seriesList = [
          charts.Series<InstrumentHistorical, DateTime>(
            id: 'Open',
            colorFn: (_, __) => charts.ColorUtil.fromDartColor(
                Theme.of(context).colorScheme.primary),
            //colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
            domainFn: (InstrumentHistorical history, _) => history.beginsAt!,
            measureFn: (InstrumentHistorical history, _) => history.openPrice,
            data: holding.historicalsObj!.historicals,
          ),
          charts.Series<InstrumentHistorical, DateTime>(
            id: 'Close',
            colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
            domainFn: (InstrumentHistorical history, _) => history.beginsAt!,
            measureFn: (InstrumentHistorical history, _) => history.closePrice,
            data: holding.historicalsObj!.historicals,
          ),
          charts.Series<InstrumentHistorical, DateTime>(
              id: 'Volume',
              colorFn: (_, __) => charts.MaterialPalette.cyan.shadeDefault,
              domainFn: (InstrumentHistorical history, _) => history.beginsAt!,
              measureFn: (InstrumentHistorical history, _) => history.volume,
              data: holding.historicalsObj!.historicals),
          charts.Series<InstrumentHistorical, DateTime>(
            id: 'Low',
            colorFn: (_, __) => charts.MaterialPalette.red.shadeDefault,
            domainFn: (InstrumentHistorical history, _) => history.beginsAt!,
            measureFn: (InstrumentHistorical history, _) => history.lowPrice,
            data: holding.historicalsObj!.historicals,
          ),
          charts.Series<InstrumentHistorical, DateTime>(
            id: 'High',
            colorFn: (_, __) => charts.MaterialPalette.green.shadeDefault,
            domainFn: (InstrumentHistorical history, _) => history.beginsAt!,
            measureFn: (InstrumentHistorical history, _) => history.highPrice,
            data: holding.historicalsObj!.historicals,
          ),
        ];
        var open = holding.historicalsObj!.historicals[0].openPrice!;
        var close = holding
            .historicalsObj!
            .historicals[holding.historicalsObj!.historicals.length - 1]
            .closePrice!;
        chart = TimeSeriesChart(seriesList,
            open: open,
            close: close,
            hiddenSeries: const ["Close", "Volume", "Low", "High"],
            zeroBound: false,
            dataIsInWholeNumbers: open > 2,
            onSelected: _onChartSelection);
      }
    }

    var slivers = <Widget>[];
    slivers.add(SliverAppBar(
        title: headerTitle(holding),
        //expandedHeight: 160,
        expandedHeight: 120.0,
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
              //titlePadding:
              //    const EdgeInsets.only(top: kToolbarHeight * 2, bottom: 15),
              //background: const FlutterLogo(),
              title: Opacity(
            //duration: Duration(milliseconds: 300),
            opacity: opacity, //top > kToolbarHeight * 3 ? 1.0 : 0.0,
            child: SingleChildScrollView(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: headerWidgets.toList())),
            /*
          ListTile(
            title: Text('${instrument.simpleName}'),
            subtitle: Text(instrument.name),
          )*/
          ));
        })));

    slivers.add(
      SliverToBoxAdapter(
          child: Align(
              alignment: Alignment.center,
              child: Stack(children: [
                if (done == false) ...[
                  SizedBox(
                    height: 3, //150.0,
                    child: Center(
                        child: LinearProgressIndicator(
                            //value: controller.value,
                            //semanticsLabel: 'Linear progress indicator',
                            ) //CircularProgressIndicator(),
                        ),
                  ),
                ],
                buildOverview(holding)
              ]))),
    );

    if (holding.historicalsObj != null) {
      var brightness = MediaQuery.of(context).platformBrightness;
      var textColor = Theme.of(context).colorScheme.surface;
      if (brightness == Brightness.dark) {
        textColor = Colors.grey.shade200;
      } else {
        textColor = Colors.grey.shade800;
      }

      slivers.add(const SliverToBoxAdapter(
          child: SizedBox(
        height: 12.0,
      )));

      slivers.add(SliverToBoxAdapter(
          child: SizedBox(
              height: 43,
              child: Center(
                  child: Column(
                children: [
                  Wrap(
                    children: [
                      Text(
                          close < 0.001
                              ? NumberFormat.simpleCurrency(decimalDigits: 8)
                                  .format(close)
                              : formatCurrency.format(close),
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
                            : (changeInPeriod < 0 ? Colors.red : Colors.grey)),
                        //size: 16.0
                      ),
                      Container(
                        width: 2,
                      ),
                      Text(
                          formatPercentage
                              //.format(selection!.netReturn!.abs()),
                              .format(changePercentInPeriod.abs()),
                          style: TextStyle(fontSize: 20.0, color: textColor)),
                      Container(
                        width: 10,
                      ),
                      Text(
                          "${changeInPeriod > 0 ? "+" : changeInPeriod < 0 ? "-" : ""}${close < 0.001 ? NumberFormat.simpleCurrency(decimalDigits: 8).format(changeInPeriod.abs()) : formatCurrency.format(changeInPeriod.abs())}",
                          style: TextStyle(fontSize: 20.0, color: textColor)),
                    ],
                  ),
                  Text(
                      '${formatMediumDate.format(firstHistorical!.beginsAt!.toLocal())} - ${formatMediumDate.format(selection != null ? selection!.beginsAt!.toLocal() : lastHistorical!.beginsAt!.toLocal())}',
                      style: TextStyle(fontSize: 10, color: textColor)),
                ],
              )))));

      slivers.add(SliverToBoxAdapter(
          child: SizedBox(
              height: 240,
              child: Padding(
                //padding: EdgeInsets.symmetric(horizontal: 12.0),
                padding: const EdgeInsets.all(10.0),
                child: chart,
              ))));
      //child: StackedAreaLineChart.withSampleData()))));
      slivers.add(SliverToBoxAdapter(
          child: SizedBox(
              height: 56,
              child: ListView.builder(
                key: const PageStorageKey<String>('forexChartFilters'),
                padding: const EdgeInsets.all(5.0),
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  return Row(children: [
                    Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: ChoiceChip(
                        //avatar: const Icon(Icons.history_outlined),
                        //avatar: CircleAvatar(child: Text(optionCount.toString())),
                        label: const Text('Hour'),
                        selected: chartDateSpanFilter == ChartDateSpan.hour,
                        onSelected: (bool value) {
                          if (value) {
                            resetChart(ChartDateSpan.hour, chartBoundsFilter);
                          }
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: ChoiceChip(
                        //avatar: const Icon(Icons.history_outlined),
                        //avatar: CircleAvatar(child: Text(optionCount.toString())),
                        //selectedColor: Theme.of(context).colorScheme.primaryContainer,
                        //labelStyle: TextStyle(color: Theme.of(context).colorScheme.background),
                        label: const Text('Day'),
                        selected: chartDateSpanFilter == ChartDateSpan.day,
                        onSelected: (bool value) {
                          if (value) {
                            resetChart(ChartDateSpan.day, chartBoundsFilter);
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
                        selected: chartDateSpanFilter == ChartDateSpan.week,
                        onSelected: (bool value) {
                          if (value) {
                            resetChart(ChartDateSpan.week, chartBoundsFilter);
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
                        selected: chartDateSpanFilter == ChartDateSpan.month,
                        onSelected: (bool value) {
                          if (value) {
                            resetChart(ChartDateSpan.month, chartBoundsFilter);
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
                        selected: chartDateSpanFilter == ChartDateSpan.month_3,
                        onSelected: (bool value) {
                          if (value) {
                            resetChart(
                                ChartDateSpan.month_3, chartBoundsFilter);
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
                        selected: chartDateSpanFilter == ChartDateSpan.year,
                        onSelected: (bool value) {
                          if (value) {
                            resetChart(ChartDateSpan.year, chartBoundsFilter);
                          }
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: ChoiceChip(
                        //avatar: const Icon(Icons.history_outlined),
                        //avatar: CircleAvatar(child: Text(optionCount.toString())),
                        label: const Text('5 Year'),
                        selected: chartDateSpanFilter == ChartDateSpan.year_5,
                        onSelected: (bool value) {
                          if (value) {
                            resetChart(ChartDateSpan.year_5, chartBoundsFilter);
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
                            resetChart(chartDateSpanFilter, Bounds.regular);
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
                            resetChart(chartDateSpanFilter, Bounds.t24_7);
                          }
                        },
                      ),
                    ),
                    */
                  ]);
                },
                itemCount: 1,
              ))));
    }
    //if (holding != null) {
    slivers.add(const SliverToBoxAdapter(
        child: SizedBox(
      height: 25.0,
    )));
    slivers.add(SliverToBoxAdapter(
        child: Card(
            child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      const ListTile(title: Text("Position", style: TextStyle(fontSize: 20))),
      ListTile(
        minTileHeight: 10,
        title: const Text("Quantity"),
        trailing: Text(
            holding.quantity!
                .toString(), //formatCompactNumber.format(holding.quantity!)
            style: const TextStyle(fontSize: 18)),
      ),
      ListTile(
        minTileHeight: 10,
        title: const Text("Average Cost"),
        trailing: Text(
            holding.averageCost < 0.001
                ? NumberFormat.simpleCurrency(decimalDigits: 8)
                    .format(holding.averageCost)
                : formatCurrency.format(holding.averageCost),
            style: const TextStyle(fontSize: 18)),
      ),
      ListTile(
        minTileHeight: 10,
        title: const Text("Total Cost"),
        trailing: Text(formatCurrency.format(holding.totalCost),
            style: const TextStyle(fontSize: 18)),
      ),
      ListTile(
        minTileHeight: 10,
        title: const Text("Market Value"),
        trailing: Text(formatCurrency.format(holding.marketValue),
            style: const TextStyle(fontSize: 18)),
      ),
      ListTile(
          minTileHeight: 10,
          title: const Text("Return"),
          trailing: Wrap(children: [
            holding.trendingIcon,
            Container(
              width: 2,
            ),
            Text(formatCurrency.format(holding.gainLoss.abs()),
                style: const TextStyle(fontSize: 18)),
          ])

          /*
          trailing: Text(formatCurrency.format(position!.gainLoss),
              style: const TextStyle(fontSize: 18)),
              */
          ),
      ListTile(
        minTileHeight: 10,
        title: const Text("Return %"),
        trailing: Text(formatPercentage.format(holding.gainLossPercent),
            style: const TextStyle(fontSize: 18)),
      ),
      ListTile(
        minTileHeight: 10,
        title: const Text("Created"),
        trailing: Text(formatDate.format(holding.createdAt!),
            style: const TextStyle(fontSize: 18)),
      ),
      ListTile(
        minTileHeight: 10,
        title: const Text("Updated"),
        trailing: Text(formatDate.format(holding.updatedAt!),
            style: const TextStyle(fontSize: 18)),
      ),
    ]))));
    //}

    if (holding.quoteObj != null) {
      slivers.add(const SliverToBoxAdapter(
          child: SizedBox(
        height: 25.0,
      )));
      slivers.add(const SliverToBoxAdapter(
          child: ListTile(
        title: Text(
          "Quote",
          style: TextStyle(fontSize: 19.0),
        ),
      )));
      slivers.add(quoteWidget(holding));
    }

    slivers.add(const SliverToBoxAdapter(
        child: SizedBox(
      height: 25.0,
    )));
    slivers.add(const SliverToBoxAdapter(child: DisclaimerWidget()));

    return RefreshIndicator(
        onRefresh: _pullRefresh, child: CustomScrollView(slivers: slivers));
  }

  Future<void> _pullRefresh() async {
    setState(() {
      futureQuote = null;
      futureHistoricals = null;
    });
  }

  void _startRefreshTimer() {
    // Start listening to clipboard
    refreshTriggerTime = Timer.periodic(
      const Duration(milliseconds: 15000),
      (timer) async {
        if (widget.user.refreshEnabled) {
          if (widget.holding.historicalsObj != null) {
            setState(() {
              widget.holding.historicalsObj = null;
              futureHistoricals = null;
            });
          }
          /*
          var refreshForex = await widget.service.refreshNummusHoldings(
              widget.user, nummusHoldings!);
          setState(() {
            nummusHoldings = refreshForex;
          });
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

  _onChartSelection(dynamic historical) {
    if (selection != historical) {
      setState(() {
        selection = historical;
      });
    }
    if (historical != null) {
      if (selection != historical as InstrumentHistorical) {
        setState(() {
          selection = historical;
        });
      }
    } else {
      if (selection != null) {
        setState(() {
          selection = null;
        });
      }
    }
  }

  Card buildOverview(ForexHolding holding) {
    if (holding.quoteObj == null) {
      return const Card();
    }
    return Card(
        child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            const SizedBox(width: 8),
            const Expanded(child: SizedBox()),
            //const SizedBox(width: 8),
            TextButton(
              child: const Text('BUY'),
              onPressed: () => showDialog<String>(
                context: context,
                builder: (BuildContext context) => AlertDialog(
                  title: const Text('Alert'),
                  content: const Text('This feature is not implemented.'),
                  actions: <Widget>[
                    /*
                    TextButton(
                      onPressed: () => Navigator.pop(context, 'Cancel'),
                      child: const Text('Cancel'),
                    ),
                    */
                    TextButton(
                      onPressed: () => Navigator.pop(context, 'OK'),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              child: const Text('SELL'),
              onPressed: () => showDialog<String>(
                context: context,
                builder: (BuildContext context) => AlertDialog(
                  title: const Text('Alert'),
                  content: const Text('This feature is not implemented.'),
                  actions: <Widget>[
                    /*
                    TextButton(
                      onPressed: () => Navigator.pop(context, 'Cancel'),
                      child: const Text('Cancel'),
                    ),
                    */
                    TextButton(
                      onPressed: () => Navigator.pop(context, 'OK'),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ],
    ));
  }

  Widget quoteWidget(ForexHolding holding) {
    return SliverToBoxAdapter(
        child: Card(
            child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      ListTile(
          minTileHeight: 10,
          title: const Text("Last Trade Price"),
          trailing: Wrap(spacing: 8, children: [
            Icon(
                holding.quoteObj!.changeToday > 0
                    ? Icons.trending_up
                    : (holding.quoteObj!.changeToday < 0
                        ? Icons.trending_down
                        : Icons.trending_flat),
                color: (holding.quoteObj!.changeToday > 0
                    ? Colors.green
                    : (holding.quoteObj!.changeToday < 0
                        ? Colors.red
                        : Colors.grey))),
            Text(
              holding.quoteObj!.markPrice! < 0.001
                  ? NumberFormat.simpleCurrency(decimalDigits: 8)
                      .format(holding.quoteObj!.markPrice)
                  : formatCurrency.format(holding.quoteObj!.markPrice),
              style: const TextStyle(fontSize: 18.0),
              textAlign: TextAlign.right,
            ),
          ])),
      ListTile(
        minTileHeight: 10,
        title: const Text("Open Price"),
        trailing: Text(
            holding.quoteObj!.openPrice! < 0.001
                ? NumberFormat.simpleCurrency(decimalDigits: 8)
                    .format(holding.quoteObj!.openPrice)
                : formatCurrency.format(holding.quoteObj!.openPrice),
            style: const TextStyle(fontSize: 18)),
      ),
      ListTile(
        minTileHeight: 10,
        title: const Text("Change Today"),
        trailing: Text(formatCurrency.format(holding.quoteObj!.changeToday),
            style: const TextStyle(fontSize: 18)),
      ),
      ListTile(
        minTileHeight: 10,
        title: const Text("Change Today %"),
        trailing: Text(
            formatPercentage.format(holding.quoteObj!.changePercentToday),
            style: const TextStyle(fontSize: 18)),
      ),
      ListTile(
        minTileHeight: 10,
        title: const Text("Bid Price"),
        trailing: Text(
            holding.quoteObj!.bidPrice! < 0.001
                ? NumberFormat.simpleCurrency(decimalDigits: 8)
                    .format(holding.quoteObj!.bidPrice)
                : formatCurrency.format(holding.quoteObj!.bidPrice),
            style: const TextStyle(fontSize: 18)),
      ),
      ListTile(
        minTileHeight: 10,
        title: const Text("Ask Price"),
        trailing: Text(
            holding.quoteObj!.askPrice! < 0.001
                ? NumberFormat.simpleCurrency(decimalDigits: 8)
                    .format(holding.quoteObj!.askPrice)
                : formatCurrency.format(holding.quoteObj!.askPrice),
            style: const TextStyle(fontSize: 18)),
      ),
      Container(
        height: 10,
      )
    ])));
  }

  Widget headerTitle(ForexHolding holding) {
    return Wrap(
        crossAxisAlignment: WrapCrossAlignment.end,
        //runAlignment: WrapAlignment.end,
        //alignment: WrapAlignment.end,
        spacing: 20,
        //runSpacing: 5,
        children: [
          Text(
            holding.currencyCode, // ${optionPosition.strategy.split('_').first}
            //style: const TextStyle(fontSize: 20.0)
          ),
          /*
          if (instrument.quoteObj != null) ...[
            Wrap(spacing: 10, children: [
              Text(formatCurrency.format(instrument.quoteObj!.lastTradePrice),
                  //style: const TextStyle(fontSize: 15.0)
                  style:
                      const TextStyle(fontSize: 16.0, color: Colors.white70)),
              Wrap(children: [
                Icon(
                    instrument.quoteObj!.changeToday > 0
                        ? Icons.trending_up
                        : (instrument.quoteObj!.changeToday < 0
                            ? Icons.trending_down
                            : Icons.trending_flat),
                    color: (instrument.quoteObj!.changeToday > 0
                        ? Colors.lightGreenAccent
                        : (instrument.quoteObj!.changeToday < 0
                            ? Colors.red
                            : Colors.grey)),
                    size: 20.0),
                Container(
                  width: 2,
                ),
                Text(
                    formatPercentage
                        .format(instrument.quoteObj!.changePercentToday),
                    //style: const TextStyle(fontSize: 15.0)
                    style:
                        const TextStyle(fontSize: 16.0, color: Colors.white70)),
              ]),
              Text(
                  "${instrument.quoteObj!.changeToday > 0 ? "+" : instrument.quoteObj!.changeToday < 0 ? "-" : ""}${formatCurrency.format(instrument.quoteObj!.changeToday.abs())}",
                  //style: const TextStyle(fontSize: 12.0),
                  style: const TextStyle(fontSize: 16.0, color: Colors.white70),
                  textAlign: TextAlign.right)
            ])
          ],
          */
        ]);
  }

  Iterable<Widget> get headerWidgets sync* {
    var holding = widget.holding;
    // yield Row(children: const [SizedBox(height: 70)]);
    yield Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Container(
            width: 10,
          ),
          Column(mainAxisAlignment: MainAxisAlignment.start, children: [
            SizedBox(
                width: 190,
                child: Hero(
                    tag: 'logo_crypto_${holding.currencyCode}',
                    child: Text(
                      holding.currencyName,
                      //instrument.simpleName ?? instrument.name,
                      style: TextStyle(
                          fontSize: 16.0,
                          color: Theme.of(context).appBarTheme.foregroundColor),
                      textAlign: TextAlign.left,
                      //overflow: TextOverflow.ellipsis
                    )))
          ]),
          Container(
            width: 10,
          ),
        ]);
  }
}
