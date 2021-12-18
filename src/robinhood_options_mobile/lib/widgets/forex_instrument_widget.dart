import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/forex_holding.dart';
import 'package:robinhood_options_mobile/model/forex_quote.dart';
import 'package:robinhood_options_mobile/widgets/chart_time_series_widget.dart';
import 'package:robinhood_options_mobile/widgets/disclaimer_widget.dart';
import 'package:robinhood_options_mobile/model/instrument_historical.dart';
import 'package:robinhood_options_mobile/model/robinhood_user.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';

final formatDate = DateFormat.yMMMEd(); //.yMEd(); //("yMMMd");
final formatExpirationDate = DateFormat('yyyy-MM-dd');
final formatCompactDate = DateFormat("MMMd");
final formatLongDate = DateFormat("EEEE MMMM d, y hh:mm:ss a");
final formatCurrency = NumberFormat.simpleCurrency();
final formatPercentage = NumberFormat.decimalPercentPattern(decimalDigits: 2);
final formatCompactNumber = NumberFormat.compact();

class ForexInstrumentWidget extends StatefulWidget {
  final RobinhoodUser user;
  final Account account;
  final ForexHolding holding;
  //final OptionAggregatePosition? optionPosition;
  const ForexInstrumentWidget(this.user, this.account, this.holding, {Key? key})
      : super(key: key);

  @override
  _ForexInstrumentWidgetState createState() => _ForexInstrumentWidgetState();
}

class _ForexInstrumentWidgetState extends State<ForexInstrumentWidget> {
  Future<dynamic>? futureQuote;
  Future<dynamic>? futureHistoricals;

  //charts.TimeSeriesChart? chart;
  TimeSeriesChart? chart;
  ChartDateSpan chartDateSpanFilter = ChartDateSpan.day;
  Bounds chartBoundsFilter = Bounds.regular;
  InstrumentHistorical? selection;

  //final dataKey = GlobalKey();

  _ForexInstrumentWidgetState();

  @override
  void initState() {
    super.initState();

    //var fut = RobinhoodService.getOptionOrders(user); // , instrument);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.holding.quoteObj == null) {
      var forexPair = RobinhoodService.forexPairs.singleWhere((element) =>
          element['asset_currency']['id'] == widget.holding.currencyId);
      futureQuote ??=
          RobinhoodService.getForexQuote(widget.user, forexPair['id']);
    } else {
      futureQuote ??= Future.value(widget.holding.quoteObj);
    }

    return Scaffold(
        body: FutureBuilder(
      future: futureQuote,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          //var quoteObj = CryptoQuote.fromJson(snapshot.data!);
          widget.holding.quoteObj = snapshot.data! as ForexQuote;
          /*
          String? bounds;
          String? interval;
          String? span;
          switch (chartBoundsFilter) {
            case Bounds.regular:
              bounds = "regular";
              break;
            case Bounds.trading:
              bounds = "trading";
              break;
            default:
              bounds = "regular";
              break;
          }
          switch (chartDateSpanFilter) {
            case ChartDateSpan.day:
              interval = "5minute";
              span = "day";
              bounds = "trading";
              break;
            case ChartDateSpan.week:
              interval = "10minute";
              span = "week";
              // bounds = "24_7"; // Does not look good with regular?!
              break;
            case ChartDateSpan.month:
              interval = "hour";
              span = "month";
              // bounds = "24_7"; // Does not look good with regular?!
              break;
            case ChartDateSpan.month_3:
              interval = "day";
              span = "3month";
              break;
            case ChartDateSpan.year:
              interval = "day";
              span = "year";
              break;
            case ChartDateSpan.year_5:
              interval = "day";
              span = "5year";
              break;
            default:
              interval = "5minute";
              span = "day";
              bounds = "trading";
              break;
          }
          futureHistoricals ??= RobinhoodService.getForexHistoricals(
              widget.user, widget.holding.quoteObj['id'],
              //interval: interval, span: span, bounds: bounds
          );

          return FutureBuilder<InstrumentHistoricals>(
              future: futureHistoricals,
              builder: (context11, historicalsSnapshot) {
                if (historicalsSnapshot.hasData) {
                  if (instrument.instrumentHistoricalsObj == null ||
                      historicalsSnapshot.data!.bounds !=
                          instrument.instrumentHistoricalsObj!.bounds ||
                      historicalsSnapshot.data!.span !=
                          instrument.instrumentHistoricalsObj!.span) {
                    chart = null;
                  }

                  instrument.instrumentHistoricalsObj =
                      historicalsSnapshot.data!;
                }
                return buildScrollView(instrument,
                    position: widget.position,
                    done: historicalsSnapshot.connectionState ==
                        ConnectionState.done);
              });
          */
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
    /*
    if (holding.instrumentHistoricalsObj != null) {
      if (chart == null) {
        List<charts.Series<dynamic, DateTime>> seriesList = [
          charts.Series<InstrumentHistorical, DateTime>(
            id: 'Open',
            colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
            domainFn: (InstrumentHistorical history, _) => history.beginsAt!,
            measureFn: (InstrumentHistorical history, _) => history.openPrice,
            data: instrument.instrumentHistoricalsObj!.historicals,
          ),
          charts.Series<InstrumentHistorical, DateTime>(
            id: 'Close',
            colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
            domainFn: (InstrumentHistorical history, _) => history.beginsAt!,
            measureFn: (InstrumentHistorical history, _) => history.closePrice,
            data: instrument.instrumentHistoricalsObj!.historicals,
          ),
          charts.Series<InstrumentHistorical, DateTime>(
              id: 'Volume',
              colorFn: (_, __) => charts.MaterialPalette.cyan.shadeDefault,
              domainFn: (InstrumentHistorical history, _) => history.beginsAt!,
              measureFn: (InstrumentHistorical history, _) => history.volume,
              data: instrument.instrumentHistoricalsObj!.historicals),
          charts.Series<InstrumentHistorical, DateTime>(
            id: 'Low',
            colorFn: (_, __) => charts.MaterialPalette.red.shadeDefault,
            domainFn: (InstrumentHistorical history, _) => history.beginsAt!,
            measureFn: (InstrumentHistorical history, _) => history.lowPrice,
            data: instrument.instrumentHistoricalsObj!.historicals,
          ),
          charts.Series<InstrumentHistorical, DateTime>(
            id: 'High',
            colorFn: (_, __) => charts.MaterialPalette.green.shadeDefault,
            domainFn: (InstrumentHistorical history, _) => history.beginsAt!,
            measureFn: (InstrumentHistorical history, _) => history.highPrice,
            data: instrument.instrumentHistoricalsObj!.historicals,
          ),
        ];
        var open =
            instrument.instrumentHistoricalsObj!.historicals[0].openPrice!;
        var close = instrument
            .instrumentHistoricalsObj!
            .historicals[
                instrument.instrumentHistoricalsObj!.historicals.length - 1]
            .closePrice!;
        chart = TimeSeriesChart(seriesList,
            open: open,
            close: close,
            hiddenSeries: const ["Close", "Volume", "Low", "High"],
            onSelected: _onChartSelection);
      }
    }
    */
    var slivers = <Widget>[];
    slivers.add(SliverAppBar(
        title: headerTitle(holding),
        //expandedHeight: 160,
        expandedHeight: 240, // 280.0,
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

    if (done == false) {
      slivers.add(const SliverToBoxAdapter(
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
      )));
    }

    slivers.add(
      SliverToBoxAdapter(
          child: Align(
              alignment: Alignment.center, child: buildOverview(holding))),
    );
    /*
    if (instrument.instrumentHistoricalsObj != null) {
      var brightness = MediaQuery.of(context).platformBrightness;
      var textColor = Theme.of(context).colorScheme.background;
      if (brightness == Brightness.dark) {
        textColor = Colors.grey.shade500;
      } else {
        textColor = Colors.grey.shade700;
      }
      var open = instrument.instrumentHistoricalsObj!.historicals[0].openPrice!;
      var close = instrument
          .instrumentHistoricalsObj!
          .historicals[
              instrument.instrumentHistoricalsObj!.historicals.length - 1]
          .closePrice!;
      double changeToday = close - open;
      double changePercentToday = changeToday / close;

      slivers.add(const SliverToBoxAdapter(
          child: SizedBox(
        height: 25.0,
      )));

      slivers.add(SliverToBoxAdapter(
          child: SizedBox(
              height: 36,
              child: Center(
                  child: Column(children: [
                if (selection != null) ...[
                  Wrap(
                    //spacing: 8,
                    children: [
                      Text(
                          "O ${formatCurrency.format(selection!.openPrice)} H ${formatCurrency.format(selection!.highPrice)} L ${formatCurrency.format(selection!.lowPrice)} C ${formatCurrency.format(selection!.closePrice)}",
                          style: const TextStyle(fontSize: 14)),
                      /*
                            Text(
                                "Volume ${formatCompactNumber.format(selection!.volume)}",
                                style: const TextStyle(fontSize: 11))
                                */
                    ],
                  ),
                  Text(formatLongDate.format(selection!.beginsAt!.toLocal()),
                      style: TextStyle(fontSize: 10, color: textColor)),
                ] else ...[
                  Wrap(children: [
                    Text(formatCurrency.format(close),
                        style: TextStyle(fontSize: 20, color: textColor)),
                    Container(
                      width: 10,
                    ),
                    Icon(
                      changeToday > 0
                          ? Icons.trending_up
                          : (changeToday < 0
                              ? Icons.trending_down
                              : Icons.trending_flat),
                      color: (changeToday > 0
                          ? Colors.green
                          : (changeToday < 0 ? Colors.red : Colors.grey)),
                      //size: 16.0
                    ),
                    Container(
                      width: 2,
                    ),
                    Text(formatPercentage.format(changePercentToday.abs()),
                        style: TextStyle(fontSize: 20.0, color: textColor)),
                    Container(
                      width: 10,
                    ),
                    Text(
                        "${changeToday > 0 ? "+" : changeToday < 0 ? "-" : ""}${formatCurrency.format(changeToday.abs())}",
                        style: TextStyle(fontSize: 20.0, color: textColor)),
                  ]),
                  Text(
                      formatLongDate.format(instrument
                          .instrumentHistoricalsObj!
                          .historicals[instrument.instrumentHistoricalsObj!
                                  .historicals.length -
                              1]
                          .beginsAt!
                          .toLocal()),
                      style: TextStyle(fontSize: 10, color: textColor)),
                ]
              ])))));
      slivers.add(SliverToBoxAdapter(
          child: SizedBox(
              height: 400,
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
                        label: const Text('5 Years'),
                        selected: chartDateSpanFilter == ChartDateSpan.year_5,
                        onSelected: (bool value) {
                          if (value) {
                            resetChart(ChartDateSpan.year_5, chartBoundsFilter);
                          }
                        },
                      ),
                    ),
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
                        label: const Text('Trading Hours'),
                        selected: chartBoundsFilter == Bounds.trading,
                        onSelected: (bool value) {
                          if (value) {
                            resetChart(chartDateSpanFilter, Bounds.trading);
                          }
                        },
                      ),
                    ),
                  ]);
                },
                itemCount: 1,
              ))));
    }
    */

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
        title: const Text("Quantity"),
        trailing: Text(
            holding.quantity!
                .toString(), //formatCompactNumber.format(holding.quantity!)
            style: const TextStyle(fontSize: 18)),
      ),
      ListTile(
        title: const Text("Average Cost"),
        trailing: Text(formatCurrency.format(holding.averageCost),
            style: const TextStyle(fontSize: 18)),
      ),
      ListTile(
        title: const Text("Total Cost"),
        trailing: Text(formatCurrency.format(holding.totalCost),
            style: const TextStyle(fontSize: 18)),
      ),
      ListTile(
        title: const Text("Market Value"),
        trailing: Text(formatCurrency.format(holding.marketValue),
            style: const TextStyle(fontSize: 18)),
      ),
      ListTile(
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
        title: const Text("Return %"),
        trailing: Text(formatPercentage.format(holding.gainLossPercent),
            style: const TextStyle(fontSize: 18)),
      ),
      ListTile(
        title: const Text("Created"),
        trailing: Text(formatDate.format(holding.createdAt!),
            style: const TextStyle(fontSize: 18)),
      ),
      ListTile(
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

  /*
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
    */

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
    return SliverStickyHeader(
        header: Material(
            //elevation: 2,
            child: Container(
                //height: 208.0, //60.0,
                //padding: EdgeInsets.symmetric(horizontal: 16.0),
                alignment: Alignment.centerLeft,
                child: const ListTile(
                  title: Text(
                    "Quote",
                    style: TextStyle(fontSize: 19.0),
                  ),
                ))),
        sliver: SliverToBoxAdapter(
            child: Card(
                child:
                    Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          ListTile(
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
                  formatCurrency.format(holding.quoteObj!.markPrice),
                  style: const TextStyle(fontSize: 18.0),
                  textAlign: TextAlign.right,
                ),
              ])),
          ListTile(
            title: const Text("Open Price"),
            trailing: Text(formatCurrency.format(holding.quoteObj!.openPrice),
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Change Today"),
            trailing: Text(formatCurrency.format(holding.quoteObj!.changeToday),
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Change Today %"),
            trailing: Text(
                formatPercentage.format(holding.quoteObj!.changePercentToday),
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Bid - Ask Price"),
            trailing: Text(
                "${formatCurrency.format(holding.quoteObj!.bidPrice)} - ${formatCurrency.format(holding.quoteObj!.askPrice)}",
                style: const TextStyle(fontSize: 18)),
          ),
          Container(
            height: 25,
          )
        ]))));
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
                      style: const TextStyle(fontSize: 16.0),
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
