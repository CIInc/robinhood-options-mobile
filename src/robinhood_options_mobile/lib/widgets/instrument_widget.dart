import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/extension_methods.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/widgets/chart_widget.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:charts_flutter/flutter.dart' as charts;

import 'package:robinhood_options_mobile/model/fundamentals.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_historical.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_chain.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/option_order.dart';
import 'package:robinhood_options_mobile/model/position.dart';
import 'package:robinhood_options_mobile/model/position_order.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/robinhood_user.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
import 'package:robinhood_options_mobile/widgets/option_instrument_widget.dart';
import 'package:robinhood_options_mobile/widgets/option_order_widget.dart';

final formatDate = DateFormat.yMMMEd(); //.yMEd(); //("yMMMd");
final formatExpirationDate = DateFormat('yyyy-MM-dd');
final formatCompactDate = DateFormat("MMMd");
final formatCurrency = NumberFormat.simpleCurrency();
final formatPercentage = NumberFormat.decimalPercentPattern(decimalDigits: 2);
final formatCompactNumber = NumberFormat.compact();

class InstrumentWidget extends StatefulWidget {
  final RobinhoodUser user;
  final Account account;
  final Instrument instrument;
  final Position? position;
  final OptionAggregatePosition? optionPosition;
  const InstrumentWidget(this.user, this.account, this.instrument,
      {Key? key, this.position, this.optionPosition})
      : super(key: key);

  @override
  _InstrumentWidgetState createState() => _InstrumentWidgetState();
}

class _InstrumentWidgetState extends State<InstrumentWidget> {
  Future<Quote?>? futureQuote;
  Future<Fundamentals?>? futureFundamentals;
  Future<InstrumentHistoricals?>? futureHistoricals;
  Future<OptionChain>? futureOptionChain;
  Future<List<dynamic>>? futureNews;
  Future<List<PositionOrder>>? futureInstrumentOrders;
  Future<List<OptionOrder>>? futureOptionOrders;

  Stream<List<OptionInstrument>>? optionInstrumentStream;
  List<OptionInstrument>? optionInstruments;

  //charts.TimeSeriesChart? chart;
  Chart? chart;
  ChartDateSpan chartDateSpanFilter = ChartDateSpan.day;
  Bounds chartBoundsFilter = Bounds.regular;
  InstrumentHistorical? selection;

  final List<String> optionFilters = <String>[];
  final List<String> positionFilters = <String>[];

  final List<bool> hasQuantityFilters = [true, false];

  final List<String> orderFilters = <String>["confirmed", "filled"];

  List<DateTime>? expirationDates;
  DateTime? expirationDateFilter;
  String? actionFilter = "Buy";
  String? typeFilter = "Call";

  final List<bool> isSelected = [true, false];

  List<OptionAggregatePosition> optionPositions = [];
  List<OptionOrder> optionOrders = [];
  double optionOrdersPremiumBalance = 0;
  List<PositionOrder> positionOrders = [];
  double positionOrdersBalance = 0;

  //final dataKey = GlobalKey();

  _InstrumentWidgetState();

  @override
  void initState() {
    super.initState();

    if (RobinhoodService.optionOrders != null) {
      var cachedOptionOrders = RobinhoodService.optionOrders!
          .where((element) => element.chainSymbol == widget.instrument.symbol)
          .toList();
      futureOptionOrders = Future.value(cachedOptionOrders);
    } else {
      futureOptionOrders = RobinhoodService.getOptionOrders(
          widget.user, widget.instrument.tradeableChainId!);
    }

    if (RobinhoodService.optionPositions != null) {
      optionPositions = RobinhoodService.optionPositions!
          .where((e) => e.symbol == widget.instrument.symbol)
          .toList();
    }

    if (RobinhoodService.positionOrders != null) {
      var cachedPositionOrders = RobinhoodService.positionOrders!
          .where((element) => element.instrumentId == widget.instrument.id)
          .toList();
      futureInstrumentOrders = Future.value(cachedPositionOrders);
    } else {
      futureInstrumentOrders = RobinhoodService.getInstrumentOrders(
          widget.user, [widget.instrument.url]);
    }

    //var fut = RobinhoodService.getOptionOrders(user); // , instrument);
  }

  void _calculateOptionOrderBalance() {
    optionOrdersPremiumBalance = optionOrders.isNotEmpty
        ? optionOrders
            .map((e) =>
                (e.processedPremium != null ? e.processedPremium! : 0) *
                (e.direction == "credit" ? 1 : -1))
            .reduce((a, b) => a + b) as double
        : 0;
  }

  void _calculatePositionOrderBalance() {
    positionOrdersBalance = positionOrders.isNotEmpty
        ? positionOrders
            .map((e) =>
                (e.averagePrice != null ? e.averagePrice! * e.quantity! : 0) *
                (e.side == "buy" ? 1 : -1))
            .reduce((a, b) => a + b) as double
        : 0;
  }

/*
  // scopes: [acats, balances, document_upload, edocs, funding:all:read, funding:ach:read, funding:ach:write, funding:wire:read, funding:wire:write, internal, investments, margin, read, signup, trade, watchlist, web_limited])
  Request to https://api.robinhood.com/marketdata/options/?instruments=942d3704-7247-454f-9fb6-1f98f5d41702 failed with status 400: Bad Request.
  */

  @override
  Widget build(BuildContext context) {
    var instrument = widget.instrument;
    var user = widget.user;

    if (instrument.quoteObj == null) {
      futureQuote ??= RobinhoodService.getQuote(user, instrument.symbol);
    } else {
      futureQuote ??= Future.value(instrument.quoteObj);
    }

    if (instrument.fundamentalsObj == null) {
      futureFundamentals ??= RobinhoodService.getFundamentals(user, instrument);
    } else {
      futureFundamentals ??= Future.value(instrument.fundamentalsObj);
    }

    futureOptionChain ??= RobinhoodService.getOptionChains(user, instrument.id);

    futureNews ??= RobinhoodService.getNews(user, instrument.symbol);

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
    futureHistoricals ??= RobinhoodService.getInstrumentHistoricals(
        user, instrument.symbol,
        interval: interval, span: span, bounds: bounds);

    return Scaffold(
        body: FutureBuilder(
      future: Future.wait([
        futureQuote as Future,
        futureFundamentals as Future,
        futureHistoricals as Future,
        futureOptionChain as Future,
        futureNews as Future,
        futureInstrumentOrders as Future,
        futureOptionOrders as Future
      ]),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          List<dynamic> data = snapshot.data as List<dynamic>;
          instrument.quoteObj = data.isNotEmpty ? data[0] : null;
          instrument.fundamentalsObj = data.length > 1 ? data[1] : null;
          instrument.instrumentHistoricalsObj =
              data.length > 2 ? data[2] : null;
          instrument.optionChainObj = data.length > 3 ? data[3] : null;
          instrument.newsObj = data.length > 4 ? data[4] : null;
          instrument.positionOrders = data.length > 5 ? data[5] : null;
          instrument.optionOrders = data.length > 6 ? data[6] : null;

          positionOrders = instrument.positionOrders!;
          _calculatePositionOrderBalance();
          optionOrders = instrument.optionOrders!;
          _calculateOptionOrderBalance();

          chart = null;

          expirationDates = instrument.optionChainObj!.expirationDates;
          expirationDates!.sort((a, b) => a.compareTo(b));
          if (expirationDates!.isNotEmpty) {
            expirationDateFilter ??= expirationDates!.first;
          }

          optionInstrumentStream ??= RobinhoodService.streamOptionInstruments(
              user,
              instrument,
              expirationDateFilter != null
                  ? formatExpirationDate.format(expirationDateFilter!)
                  : null,
              null); // 'call'

          return StreamBuilder<List<OptionInstrument>>(
              stream: optionInstrumentStream,
              builder: (BuildContext context,
                  AsyncSnapshot<List<OptionInstrument>> snapshot) {
                if (snapshot.hasData) {
                  optionInstruments = snapshot.data!;

                  /*
                  expirationDates = optionInstruments!
                      .map((e) => e.expirationDate!)
                      .toSet()
                      .toList();
                  expirationDates!.sort((a, b) => a.compareTo(b));
                  if (expirationDates!.isNotEmpty) {
                    expirationDateFilter ??= expirationDates!.first;
                  }
                  */

                  return buildScrollView(instrument,
                      optionInstruments: optionInstruments,
                      position: widget.position);
                } else if (snapshot.hasError) {
                  debugPrint("${snapshot.error}");
                  return Text("${snapshot.error}");
                }
                return buildScrollView(instrument, position: widget.position);
              });
        } else if (snapshot.hasError) {
          debugPrint("${snapshot.error}");
          return Text("${snapshot.error}");
        }
        return buildScrollView(instrument, position: widget.position);
      },
    ));
  }

  buildScrollView(Instrument instrument,
      {List<OptionInstrument>? optionInstruments, Position? position}) {
    var slivers = <Widget>[];
    slivers.add(SliverAppBar(
        title: headerTitle(instrument),
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
              background: SizedBox(
                width: double.infinity,
                child: Image.network(
                  'https://source.unsplash.com/daily?code',
                  fit: BoxFit.cover,
                ),
              ),
              //const FlutterLogo(),
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
              alignment: Alignment.center, child: buildOverview(instrument))),
    );

    if (instrument.instrumentHistoricalsObj != null) {
      /*
        var filteredInstrumentHistoricals = portfolioHistoricals.equityHistoricals
            .where((element) =>
                days == 0 ||
                element.beginsAt!
                        .compareTo(DateTime.now().add(Duration(days: -days))) >
                    0)
            .toList();
            */
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
        chart = Chart(seriesList,
            open: open,
            close: close,
            hiddenSeries: const ["Volume", "Open", "Low", "High"],
            onSelected: _onChartSelection);
        /*
        chart = charts.TimeSeriesChart(
          seriesList,
          defaultRenderer:
              charts.LineRendererConfig(includeArea: true, stacked: false),
          animate: true,
          primaryMeasureAxis: const charts.NumericAxisSpec(
              tickProviderSpec:
                  charts.BasicNumericTickProviderSpec(zeroBound: false)),
          selectionModels: [
            charts.SelectionModelConfig(
              type: charts.SelectionModelType.info,
              changedListener: (charts.SelectionModel model) {
                if (model.hasDatumSelection) {
                  var selected =
                      model.selectedDatum[0].datum as InstrumentHistorical;
                  setState(() {
                    selection = selected;
                  });
                }
              },
            )
          ],
          behaviors: [
            charts.SeriesLegend(
                defaultHiddenSeries: const ["Volume", "Open", "Low", "High"])
          ],
        );
        */
      }
      slivers.add(SliverToBoxAdapter(
          child: SizedBox(
              height: 320,
              child: Padding(
                //padding: EdgeInsets.symmetric(horizontal: 12.0),
                padding: const EdgeInsets.all(10.0),
                child: chart,
              ))));
      if (selection != null) {
        slivers.add(SliverToBoxAdapter(
            child: SizedBox(
                height: 24,
                child: Center(
                    child: Wrap(
                  spacing: 8,
                  children: [
                    Text(formatDate.format(selection!.beginsAt!),
                        style: const TextStyle(fontSize: 11)),
                    Text(
                        "Open/Close Price ${formatCurrency.format(selection!.openPrice)}, ${formatCurrency.format(selection!.closePrice)}",
                        style: const TextStyle(fontSize: 11)),
                    Text(
                        "Low/High Price ${formatCurrency.format(selection!.lowPrice)}, ${formatCurrency.format(selection!.highPrice)}",
                        style: const TextStyle(fontSize: 11)),
                    Text(
                        "Volume ${formatCompactNumber.format(selection!.volume)}",
                        style: const TextStyle(fontSize: 11))
                  ],
                )))));
      }
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
                          setState(() {
                            if (value) {
                              chartDateSpanFilter = ChartDateSpan.day;
                              selection = null;
                              futureHistoricals = null;
                            }
                          });
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
                          setState(() {
                            if (value) {
                              chartDateSpanFilter = ChartDateSpan.week;
                              selection = null;
                              futureHistoricals = null;
                            }
                          });
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
                          setState(() {
                            if (value) {
                              chartDateSpanFilter = ChartDateSpan.month;
                              selection = null;
                              futureHistoricals = null;
                            }
                          });
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
                          setState(() {
                            if (value) {
                              chartDateSpanFilter = ChartDateSpan.month_3;
                              selection = null;
                              futureHistoricals = null;
                            }
                          });
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
                          setState(() {
                            if (value) {
                              chartDateSpanFilter = ChartDateSpan.year;
                              selection = null;
                              futureHistoricals = null;
                            }
                          });
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
                          setState(() {
                            if (value) {
                              chartDateSpanFilter = ChartDateSpan.year_5;
                              selection = null;
                              futureHistoricals = null;
                            }
                          });
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
                          setState(() {
                            if (value) {
                              chartBoundsFilter = Bounds.regular;
                              selection = null;
                              futureHistoricals = null;
                            }
                          });
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
                          setState(() {
                            if (value) {
                              chartBoundsFilter = Bounds.trading;
                              selection = null;
                              futureHistoricals = null;
                            }
                          });
                        },
                      ),
                    ),
                  ]);
                },
                itemCount: 1,
              ))));
    }

    if (position != null) {
      slivers.add(const SliverToBoxAdapter(
          child: SizedBox(
        height: 25.0,
      )));
      slivers.add(SliverToBoxAdapter(
          child: Card(
              child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
        const ListTile(
            title: Text("Stock Position", style: TextStyle(fontSize: 20))),
        ListTile(
          title: const Text("Quantity"),
          trailing: Text(formatCompactNumber.format(position.quantity!),
              style: const TextStyle(fontSize: 18)),
        ),
        ListTile(
          title: const Text("Average Cost"),
          trailing: Text(formatCurrency.format(position.averageBuyPrice),
              style: const TextStyle(fontSize: 18)),
        ),
        ListTile(
          title: const Text("Total Cost"),
          trailing: Text(formatCurrency.format(position.totalCost),
              style: const TextStyle(fontSize: 18)),
        ),
        ListTile(
          title: const Text("Market Value"),
          trailing: Text(formatCurrency.format(position.marketValue),
              style: const TextStyle(fontSize: 18)),
        ),
        ListTile(
            title: const Text("Return"),
            trailing: Wrap(children: [
              position.trendingIcon,
              Container(
                width: 2,
              ),
              Text(formatCurrency.format(position.gainLoss.abs()),
                  style: const TextStyle(fontSize: 18)),
            ])

            /*
          trailing: Text(formatCurrency.format(position!.gainLoss),
              style: const TextStyle(fontSize: 18)),
              */
            ),
        ListTile(
          title: const Text("Return %"),
          trailing: Text(formatPercentage.format(position.gainLossPercent),
              style: const TextStyle(fontSize: 18)),
        ),
        ListTile(
          title: const Text("Created"),
          trailing: Text(formatDate.format(position.createdAt!),
              style: const TextStyle(fontSize: 18)),
        ),
        ListTile(
          title: const Text("Updated"),
          trailing: Text(formatDate.format(position.updatedAt!),
              style: const TextStyle(fontSize: 18)),
        ),
      ]))));
    }
    if (optionPositions.isNotEmpty) {
      var filteredOptionPositions = optionPositions
          .where((e) =>
              (hasQuantityFilters[0] && hasQuantityFilters[1]) ||
              (!hasQuantityFilters[0] || e.quantity! > 0) &&
                  (!hasQuantityFilters[1] || e.quantity! <= 0))
          .toList();
      double optionEquity = 0;
      if (filteredOptionPositions.isNotEmpty) {
        optionEquity = filteredOptionPositions
            .map((e) => e.legs.first.positionType == "long"
                ? e.marketValue
                : e.marketValue)
            .reduce((a, b) => a + b);

        slivers.add(const SliverToBoxAdapter(
            child: SizedBox(
          height: 25.0,
        )));
        slivers
            .add(optionPositionsWidget(filteredOptionPositions, optionEquity));
      }
    }

    if (instrument.fundamentalsObj != null) {
      slivers.add(const SliverToBoxAdapter(
          child: SizedBox(
        height: 25.0,
      )));
      slivers.add(fundamentalsWidget(instrument));
    }

    if (instrument.newsObj != null) {
      slivers.add(const SliverToBoxAdapter(
          child: SizedBox(
        height: 25.0,
      )));
      slivers.add(_buildNewsWidget(instrument));
    }

    if (positionOrders.isNotEmpty) {
      slivers.add(const SliverToBoxAdapter(
          child: SizedBox(
        height: 25.0,
      )));
      slivers.add(positionOrdersWidget);
    }

    if (optionOrders.isNotEmpty) {
      slivers.add(const SliverToBoxAdapter(
          child: SizedBox(
        height: 25.0,
      )));
      slivers.add(optionOrdersWidget);
    }

    if (optionInstruments != null) {
      slivers.add(const SliverToBoxAdapter(
          child: SizedBox(
        height: 25.0,
      )));
      slivers.add(SliverStickyHeader(
          header: Material(
              elevation: 2,
              child: Container(
                  //height: 208.0, //60.0,
                  //padding: EdgeInsets.symmetric(horizontal: 16.0),
                  alignment: Alignment.centerLeft,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          //height: 40,
                          padding:
                              const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 0),
                          //const EdgeInsets.all(4.0),
                          //EdgeInsets.symmetric(horizontal: 16.0),
                          child: const Text(
                            "Option Chain",
                            style: TextStyle(fontSize: 19.0),
                          )),
                      optionChainFilterWidget
                    ],
                  ))),
          sliver: optionInstrumentsWidget(optionInstruments, instrument,
              optionPosition: widget.optionPosition)));
    }

    return RefreshIndicator(
        onRefresh: _pullRefresh, child: CustomScrollView(slivers: slivers));
  }

  Future<void> _pullRefresh() async {
    setState(() {
      futureQuote = null;
      futureFundamentals = null;
      futureHistoricals = null;
      futureOptionChain = null;
      futureNews = null;
      //futureInstrumentOrders = null;
      //futureOptionOrders = null;
      optionInstrumentStream = null;
    });
  }

  _onChartSelection(dynamic historical) {
    setState(() {
      if (historical != null) {
        selection = historical as InstrumentHistorical;
      } else {
        selection = null;
      }
    });
  }

  Card buildOverview(Instrument instrument) {
    if (instrument.quoteObj == null) {
      return const Card();
    }
    return Card(
        child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        /*
        ListTile(
            title: Text("Last Trade Price"),
            trailing: Wrap(spacing: 8, children: [
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
                "${formatCurrency.format(instrument.quoteObj!.lastTradePrice)}",
                style: const TextStyle(fontSize: 18.0),
                textAlign: TextAlign.right,
              ),
            ])),
        ListTile(
          title: Text("Adjusted Previous Close"),
          trailing: Text(
              "${formatCurrency.format(instrument.quoteObj!.adjustedPreviousClose)}",
              style: const TextStyle(fontSize: 18)),
        ),
        ListTile(
          title: Text("Change Today"),
          trailing: Text(
              "${formatCurrency.format(instrument.quoteObj!.changeToday)}",
              style: const TextStyle(fontSize: 18)),
        ),
        ListTile(
          title: Text("Change Today %"),
          trailing: Text(
              "${formatPercentage.format(instrument.quoteObj!.changePercentToday)}",
              style: const TextStyle(fontSize: 18)),
        ),
        ListTile(
          title: Text("Bid - Ask Price"),
          trailing: Text(
              "${formatCurrency.format(instrument.quoteObj!.bidPrice)} - ${formatCurrency.format(instrument.quoteObj!.askPrice)}",
              style: const TextStyle(fontSize: 18)),
        ),
        ListTile(
          title: Text("Bid - Ask Size"),
          trailing: Text(
              "${formatCompactNumber.format(instrument.quoteObj!.bidSize)} - ${formatCompactNumber.format(instrument.quoteObj!.askSize)}",
              style: const TextStyle(fontSize: 18)),
        ),
        ListTile(
          title: Text("Last Extended Hours Trade Price"),
          trailing: Text(
              "${formatCurrency.format(instrument.quoteObj!.lastExtendedHoursTradePrice)}",
              style: const TextStyle(fontSize: 18)),
        ),
        */
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
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

  Widget fundamentalsWidget(Instrument instrument) {
    return SliverStickyHeader(
        header: Material(
            elevation: 2,
            child: Container(
                //height: 208.0, //60.0,
                //padding: EdgeInsets.symmetric(horizontal: 16.0),
                alignment: Alignment.centerLeft,
                child: const ListTile(
                  title: Text(
                    "Fundamentals",
                    style: TextStyle(fontSize: 19.0),
                  ),
                ))),
        sliver: SliverToBoxAdapter(
            child: Card(
                child:
                    Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          /*
          ListTile(
              title:
                  const Text("Fundamentals", style: TextStyle(fontSize: 20))),
                  */
          ListTile(
            title: const Text("Volume"),
            trailing: Text(
                formatCompactNumber.format(instrument.fundamentalsObj!.volume!),
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Average Volume"),
            trailing: Text(
                formatCompactNumber
                    .format(instrument.fundamentalsObj!.averageVolume!),
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Average Volume (2 weeks)"),
            trailing: Text(
                formatCompactNumber
                    .format(instrument.fundamentalsObj!.averageVolume2Weeks!),
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("52 Week High"),
            trailing: Text(
                formatCurrency.format(instrument.fundamentalsObj!.high52Weeks!),
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("52 Week Low"),
            trailing: Text(
                formatCurrency.format(instrument.fundamentalsObj!.low52Weeks!),
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Dividend Yield"),
            trailing: Text(
                instrument.fundamentalsObj!.dividendYield != null
                    ? formatCompactNumber
                        .format(instrument.fundamentalsObj!.dividendYield!)
                    : "-",
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Market Cap"),
            trailing: Text(
                formatCompactNumber
                    .format(instrument.fundamentalsObj!.marketCap!),
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Shares Outstanding"),
            trailing: Text(
                formatCompactNumber
                    .format(instrument.fundamentalsObj!.sharesOutstanding!),
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("P/E Ratio"),
            trailing: Text(
                instrument.fundamentalsObj!.peRatio != null
                    ? formatCompactNumber
                        .format(instrument.fundamentalsObj!.peRatio!)
                    : "-",
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Sector"),
            trailing: Text(instrument.fundamentalsObj!.sector,
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Industry"),
            trailing: Text(instrument.fundamentalsObj!.industry,
                style: const TextStyle(fontSize: 17)),
          ),
          ListTile(
            title: const Text("Headquarters"),
            trailing: Text(
                "${instrument.fundamentalsObj!.headquartersCity}${instrument.fundamentalsObj!.headquartersCity.isNotEmpty ? "," : ""} ${instrument.fundamentalsObj!.headquartersState}",
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("CEO"),
            trailing: Text(instrument.fundamentalsObj!.ceo,
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Number of Employees"),
            trailing: Text(
                instrument.fundamentalsObj!.numEmployees != null
                    ? formatCompactNumber
                        .format(instrument.fundamentalsObj!.numEmployees!)
                    : "",
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Year Founded"),
            trailing: Text("${instrument.fundamentalsObj!.yearFounded ?? ""}",
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text(
              "Name",
              style: TextStyle(fontSize: 18.0),
              //overflow: TextOverflow.visible
            ),
            subtitle:
                Text(instrument.name, style: const TextStyle(fontSize: 16)),
          ),
          ListTile(
            title: const Text(
              "Description",
              style: TextStyle(fontSize: 18.0),
              //overflow: TextOverflow.visible
            ),
            subtitle: Text(instrument.fundamentalsObj!.description,
                style: const TextStyle(fontSize: 16)),
          ),
          Container(
            height: 25,
          )
        ]))));
  }

  Widget _buildNewsWidget(Instrument instrument) {
    return SliverStickyHeader(
      header: Material(
          elevation: 2,
          child: Container(
              //height: 208.0, //60.0,
              //padding: EdgeInsets.symmetric(horizontal: 16.0),
              alignment: Alignment.centerLeft,
              child: const ListTile(
                title: Text(
                  "News",
                  style: TextStyle(fontSize: 19.0),
                ),
              ))),
      sliver: SliverList(
        // delegate: SliverChildListDelegate(widgets),
        delegate: SliverChildBuilderDelegate((BuildContext context, int index) {
          return Card(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading:
                    instrument.newsObj![index]["preview_image_url"] != null &&
                            instrument.newsObj![index]["preview_image_url"]
                                .toString()
                                .isNotEmpty
                        ? Image.network(
                            instrument.newsObj![index]["preview_image_url"],
                            width: 96,
                            height: 56)
                        : const SizedBox(width: 96, height: 56),
                title: Text(
                  "${instrument.newsObj![index]["title"]}",
                ), //style: TextStyle(fontSize: 17.0)),
                subtitle: Text(
                    "Published ${formatDate.format(DateTime.parse(instrument.newsObj![index]["published_at"]!))} by ${instrument.newsObj![index]["source"]}"),
                /*
                  trailing: Image.network(
                      instrument.newsObj![index]["preview_image_url"])
                      */
                isThreeLine: true,
                onTap: () async {
                  var _url = instrument.newsObj![index]["url"];
                  await canLaunch(_url)
                      ? await launch(_url)
                      : throw 'Could not launch $_url';
                },
              ),
            ],
          ));

          //if (positionOrders.length > index) {
          //}
        }, childCount: instrument.newsObj!.length),
      ),
    );
  }

  Widget get optionChainFilterWidget {
    return Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      /*
      const ListTile(
          title: Text("Option Chain", style: TextStyle(fontSize: 20))),
          */
      SizedBox(
          height: 56,
          child: ListView.builder(
            padding: const EdgeInsets.all(5.0),
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) {
              return Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: ChoiceChip(
                      label: const Text('Buy'),
                      selected: actionFilter == "Buy",
                      onSelected: (bool selected) {
                        setState(() {
                          actionFilter = selected ? "Buy" : null;
                        });
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: ChoiceChip(
                      label: const Text('Sell'),
                      selected: actionFilter == "Sell",
                      onSelected: (bool selected) {
                        setState(() {
                          actionFilter = selected ? "Sell" : null;
                        });
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: ChoiceChip(
                      label: const Text('Call'),
                      selected: typeFilter == "Call",
                      onSelected: (bool selected) {
                        setState(() {
                          typeFilter = selected ? "Call" : null;
                        });
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: ChoiceChip(
                      //avatar: const Icon(Icons.history_outlined),
                      //avatar: CircleAvatar(child: Text(optionCount.toString())),
                      label: const Text('Put'),
                      selected: typeFilter == "Put",
                      onSelected: (bool selected) {
                        setState(() {
                          typeFilter = selected ? "Put" : null;
                        });
                      },
                    ),
                  )
                ],
              );
            },
            itemCount: 1,
          )),
      SizedBox(
          height: 56,
          child: ListView.builder(
            padding: const EdgeInsets.all(5.0),
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) {
              return Row(children: expirationDateWidgets.toList());
            },
            itemCount: 1,
          )),
      /*
      ActionChip(
          avatar: CircleAvatar(
            backgroundColor: Colors.grey.shade800,
            child: const Text('AB'),
          ),
          label: const Text('Scroll to current price'),
          onPressed: () {
            //_animateToIndex(20);
            if (dataKey.currentContext != null) {
              Scrollable.ensureVisible(dataKey.currentContext!);
            }
            //print('If you stand for nothing, Burr, what’ll you fall for?');
          })
          */
    ]);
  }

  Widget get positionOrdersWidget {
    return SliverStickyHeader(
      header: Material(
          elevation: 2,
          child: Container(
            //height: 208.0, //60.0,
            //padding: EdgeInsets.symmetric(horizontal: 16.0),
            alignment: Alignment.centerLeft,
            child: ListTile(
                title: const Text(
                  "Position Orders",
                  style: TextStyle(fontSize: 19.0),
                ),
                subtitle: Text(
                    "${formatCompactNumber.format(positionOrders.length)} orders - balance: ${positionOrdersBalance > 0 ? "+" : positionOrdersBalance < 0 ? "-" : ""}${formatCurrency.format(positionOrdersBalance.abs())}"),
                trailing: IconButton(
                    icon: const Icon(Icons.filter_list),
                    onPressed: () {
                      showModalBottomSheet<void>(
                        context: context,
                        constraints: const BoxConstraints(maxHeight: 260),
                        builder: (BuildContext context) {
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                tileColor:
                                    Theme.of(context).colorScheme.primary,
                                leading: const Icon(Icons.filter_list),
                                title: const Text(
                                  "Filter Position Orders",
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 19.0),
                                ),
                                /*
                                  trailing: TextButton(
                                      child: const Text("APPLY"),
                                      onPressed: () => Navigator.pop(context))*/
                              ),
                              orderFilterWidget,
                            ],
                          );
                        },
                      );
                    })),
          )),
      sliver: SliverList(
        // delegate: SliverChildListDelegate(widgets),
        delegate: SliverChildBuilderDelegate((BuildContext context, int index) {
          if ( //positionOrders[index] == null ||
              (orderFilters.isNotEmpty &&
                  !orderFilters.contains(positionOrders[index].state))) {
            return Container();
          }

          positionOrdersBalance = positionOrders
              .map((e) =>
                  (e.averagePrice != null ? e.averagePrice! * e.quantity! : 0) *
                  (e.side == "sell" ? 1 : -1))
              .reduce((a, b) => a + b) as double;

          return Card(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: CircleAvatar(
                    //backgroundImage: AssetImage(user.profilePicture),
                    child: Text('${positionOrders[index].quantity!.round()}',
                        style: const TextStyle(fontSize: 18))),
                title: Text(
                    "${positionOrders[index].side == "buy" ? "Buy" : positionOrders[index].side == "sell" ? "Sell" : positionOrders[index].side} ${positionOrders[index].quantity} at \$${formatCompactNumber.format(positionOrders[index].averagePrice)}"), // , style: TextStyle(fontSize: 18.0)),
                subtitle: Text(
                    "${positionOrders[index].state} ${formatDate.format(positionOrders[index].updatedAt!)}"),
                trailing: Wrap(spacing: 8, children: [
                  Text(
                    (positionOrders[index].side == "sell" ? "+" : "-") +
                        (positionOrders[index].averagePrice != null
                            ? formatCurrency.format(
                                positionOrders[index].averagePrice! *
                                    positionOrders[index].quantity!)
                            : ""),
                    style: const TextStyle(fontSize: 18.0),
                    textAlign: TextAlign.right,
                  )
                ]),

                /*Wrap(
            spacing: 12,
            children: [
              Column(children: [
                Text(
                  "${formatCurrency.format(gainLoss)}\n${formatPercentage.format(gainLossPercent)}",
                  style: const TextStyle(fontSize: 15.0),
                  textAlign: TextAlign.right,
                ),
                Icon(
                    gainLossPerContract > 0
                        ? Icons.trending_up
                        : (gainLossPerContract < 0
                            ? Icons.trending_down
                            : Icons.trending_flat),
                    color: (gainLossPerContract > 0
                        ? Colors.green
                        : (gainLossPerContract < 0 ? Colors.red : Colors.grey)))
              ]),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "${formatCurrency.format(marketValue)}",
                    style: const TextStyle(fontSize: 18.0),
                    textAlign: TextAlign.right,
                  ),
                ],
              )
            ],
          ),*/
                //isThreeLine: true,
                /*
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              PositionOrderWidget(user, positionOrders[index])));
                },
                */
              ),
            ],
          ));

          //if (positionOrders.length > index) {
          //}
        }, childCount: positionOrders.length),
      ),
    );
  }

  Widget optionPositionsWidget(
      List<OptionAggregatePosition> filteredOptionPositions,
      double optionEquity) {
    return SliverStickyHeader(
      header: Material(
          elevation: 2,
          child: Container(
              //height: 208.0, //60.0,
              //padding: EdgeInsets.symmetric(horizontal: 16.0),
              alignment: Alignment.centerLeft,
              child: ListTile(
                title: const Text(
                  "Options",
                  style: TextStyle(fontSize: 19.0),
                ),
                subtitle: Text(
                    "${formatCompactNumber.format(filteredOptionPositions.length)} of ${formatCompactNumber.format(optionPositions.length)} positions - value: ${formatCurrency.format(optionEquity)}"),
                trailing: IconButton(
                    icon: const Icon(Icons.filter_list),
                    onPressed: () {
                      showModalBottomSheet<void>(
                        context: context,
                        //constraints: BoxConstraints(maxHeight: 260),
                        builder: (BuildContext context) {
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                tileColor:
                                    Theme.of(context).colorScheme.primary,
                                leading: const Icon(Icons.filter_list),
                                title: const Text(
                                  "Filter Options",
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 19.0),
                                ),
                                /*
                                  trailing: TextButton(
                                      child: const Text("APPLY"),
                                      onPressed: () => Navigator.pop(context))*/
                              ),
                              const ListTile(
                                title: Text("Position & Option Type"),
                              ),
                              openClosedFilterWidget,
                              optionTypeFilterWidget,
                            ],
                          );
                        },
                      );
                    }),
              ))),
      sliver: SliverList(
        // delegate: SliverChildListDelegate(widgets),
        delegate: SliverChildBuilderDelegate((BuildContext context, int index) {
          return _buildOptionPositionRow(
              filteredOptionPositions[index], widget.user);
        }, childCount: filteredOptionPositions.length),
      ),
    );
  }

  Widget get openClosedFilterWidget {
    return SizedBox(
        height: 56,
        child: ListView.builder(
          padding: const EdgeInsets.all(4.0),
          scrollDirection: Axis.horizontal,
          itemBuilder: (context, index) {
            return Row(children: [
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: FilterChip(
                  //avatar: const Icon(Icons.new_releases_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('Open'),
                  selected: hasQuantityFilters[0],
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        hasQuantityFilters[0] = true;
                      } else {
                        hasQuantityFilters[0] = false;
                      }
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: FilterChip(
                  //avatar: Container(),
                  //avatar: const Icon(Icons.history_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('Closed'),
                  selected: hasQuantityFilters[1],
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        hasQuantityFilters[1] = true;
                      } else {
                        hasQuantityFilters[1] = false;
                      }
                    });
                  },
                ),
              ),
              /*
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: FilterChip(
                  //avatar: const Icon(Icons.history_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('Long'),
                  selected: positionFilters.contains("long"),
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        positionFilters.add("long");
                      } else {
                        positionFilters.removeWhere((String name) {
                          return name == "long";
                        });
                      }
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: FilterChip(
                  //avatar: const Icon(Icons.history_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('Short'),
                  selected: positionFilters.contains("short"),
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        positionFilters.add("short");
                      } else {
                        positionFilters.removeWhere((String name) {
                          return name == "short";
                        });
                      }
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: FilterChip(
                  //avatar: const Icon(Icons.history_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('Call'),
                  selected: optionFilters.contains("call"),
                  //selected: optionFilters[0],
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        optionFilters.add("call");
                      } else {
                        optionFilters.removeWhere((String name) {
                          return name == "call";
                        });
                      }
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: FilterChip(
                  //avatar: const Icon(Icons.history_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('Put'),
                  selected: optionFilters.contains("put"),
                  //selected: optionFilters[1],
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        optionFilters.add("put");
                      } else {
                        optionFilters.removeWhere((String name) {
                          return name == "put";
                        });
                      }
                    });
                  },
                ),
              )
              */
            ]);
          },
          itemCount: 1,
        ));
  }

  Widget get optionTypeFilterWidget {
    return SizedBox(
        height: 56,
        child: ListView.builder(
          padding: const EdgeInsets.all(4.0),
          scrollDirection: Axis.horizontal,
          itemBuilder: (context, index) {
            return Row(
              children: [
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: FilterChip(
                    //avatar: const Icon(Icons.history_outlined),
                    //avatar: CircleAvatar(child: Text(optionCount.toString())),
                    label: const Text('Long'), // Positions
                    selected: positionFilters.contains("long"),
                    onSelected: (bool value) {
                      setState(() {
                        if (value) {
                          positionFilters.add("long");
                        } else {
                          positionFilters.removeWhere((String name) {
                            return name == "long";
                          });
                        }
                      });
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: FilterChip(
                    //avatar: const Icon(Icons.history_outlined),
                    //avatar: CircleAvatar(child: Text(optionCount.toString())),
                    label: const Text('Short'), // Positions
                    selected: positionFilters.contains("short"),
                    onSelected: (bool value) {
                      setState(() {
                        if (value) {
                          positionFilters.add("short");
                        } else {
                          positionFilters.removeWhere((String name) {
                            return name == "short";
                          });
                        }
                      });
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: FilterChip(
                    //avatar: const Icon(Icons.history_outlined),
                    //avatar: CircleAvatar(child: Text(optionCount.toString())),
                    label: const Text('Call'), // Options
                    selected: optionFilters.contains("call"),
                    onSelected: (bool value) {
                      setState(() {
                        if (value) {
                          optionFilters.add("call");
                        } else {
                          optionFilters.removeWhere((String name) {
                            return name == "call";
                          });
                        }
                      });
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: FilterChip(
                    //avatar: const Icon(Icons.history_outlined),
                    //avatar: CircleAvatar(child: Text(optionCount.toString())),
                    label: const Text('Put'), // Options
                    selected: optionFilters.contains("put"),
                    onSelected: (bool value) {
                      setState(() {
                        if (value) {
                          optionFilters.add("put");
                        } else {
                          optionFilters.removeWhere((String name) {
                            return name == "put";
                          });
                        }
                      });
                    },
                  ),
                )
              ],
            );
          },
          itemCount: 1,
        ));
  }

  Widget _buildOptionPositionRow(OptionAggregatePosition op, RobinhoodUser ru) {
    /*
    if (optionsPositions[index].optionInstrument == null ||
        (chainSymbolFilters.isNotEmpty &&
            !chainSymbolFilters.contains(optionsPositions[index].symbol)) ||
        (positionFilters.isNotEmpty &&
            !positionFilters
                .contains(optionsPositions[index].strategy.split("_").first)) ||
        (optionFilters.isNotEmpty &&
            !optionFilters
                .contains(optionsPositions[index].optionInstrument!.type))) {
      return Container();
    }
    */

    return Card(
        child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ListTile(
          leading: CircleAvatar(
              //backgroundImage: AssetImage(user.profilePicture),
              /*
              backgroundColor:
                  optionsPositions[index].optionInstrument!.type == 'call'
                      ? Colors.green
                      : Colors.amber,
              child: optionsPositions[index].optionInstrument!.type == 'call'
                  ? const Text('Call')
                  : const Text('Put')),
                      */
              child: Text('${op.quantity!.round()}',
                  style: const TextStyle(fontSize: 18))),
          title: Text(
              '${op.symbol} \$${formatCompactNumber.format(op.legs.first.strikePrice)} ${op.legs.first.positionType} ${op.legs.first.optionType}'),
          subtitle: Text(
              '${op.legs.first.expirationDate!.compareTo(DateTime.now()) > 0 ? "Expires" : "Expired"} ${formatDate.format(op.legs.first.expirationDate!)}'),
          trailing: Wrap(spacing: 8, children: [
            Icon(
                op.gainLossPerContract > 0
                    ? Icons.trending_up
                    : (op.gainLossPerContract < 0
                        ? Icons.trending_down
                        : Icons.trending_flat),
                color: (op.gainLossPerContract > 0
                    ? Colors.green
                    : (op.gainLossPerContract < 0 ? Colors.red : Colors.grey))),
            Text(
              formatCurrency.format(op.marketValue),
              style: const TextStyle(fontSize: 18.0),
              textAlign: TextAlign.right,
            )
          ]),

          /*Wrap(
            spacing: 12,
            children: [
              Column(children: [
                Text(
                  "${formatCurrency.format(gainLoss)}\n${formatPercentage.format(gainLossPercent)}",
                  style: const TextStyle(fontSize: 15.0),
                  textAlign: TextAlign.right,
                ),
                Icon(
                    gainLossPerContract > 0
                        ? Icons.trending_up
                        : (gainLossPerContract < 0
                            ? Icons.trending_down
                            : Icons.trending_flat),
                    color: (gainLossPerContract > 0
                        ? Colors.green
                        : (gainLossPerContract < 0 ? Colors.red : Colors.grey)))
              ]),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "${formatCurrency.format(marketValue)}",
                    style: const TextStyle(fontSize: 18.0),
                    textAlign: TextAlign.right,
                  ),
                ],
              )
            ],
          ),*/
          //isThreeLine: true,
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => OptionInstrumentWidget(
                        ru, widget.account, op.optionInstrument!,
                        optionPosition: op)));
          },
        ),
      ],
    ));
  }

  Widget get optionOrdersWidget {
    return SliverStickyHeader(
      header: Material(
          elevation: 2,
          child: Container(
              //height: 208.0, //60.0,
              //padding: EdgeInsets.symmetric(horizontal: 16.0),
              alignment: Alignment.centerLeft,
              child: ListTile(
                title: const Text(
                  "Option Orders",
                  style: TextStyle(fontSize: 19.0),
                ),
                subtitle: Text(
                    "${formatCompactNumber.format(optionOrders.length)} orders - balance: ${optionOrdersPremiumBalance > 0 ? "+" : optionOrdersPremiumBalance < 0 ? "-" : ""}${formatCurrency.format(optionOrdersPremiumBalance.abs())}"),
                trailing: IconButton(
                    icon: const Icon(Icons.filter_list),
                    onPressed: () {
                      showModalBottomSheet<void>(
                        context: context,
                        constraints: const BoxConstraints(maxHeight: 260),
                        builder: (BuildContext context) {
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                tileColor:
                                    Theme.of(context).colorScheme.primary,
                                leading: const Icon(Icons.filter_list),
                                title: const Text(
                                  "Filter Option Orders",
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 19.0),
                                ),
                                /*
                                  trailing: TextButton(
                                      child: const Text("APPLY"),
                                      onPressed: () => Navigator.pop(context))*/
                              ),
                              orderFilterWidget,
                            ],
                          );
                        },
                      );
                    }),
              ))),
      sliver: SliverList(
        // delegate: SliverChildListDelegate(widgets),
        delegate: SliverChildBuilderDelegate((BuildContext context, int index) {
          if ( //optionOrders[index] == null ||
              (orderFilters.isNotEmpty &&
                  !orderFilters.contains(optionOrders[index].state))) {
            return Container();
          }
          var optionOrder = optionOrders[index];
          var subtitle =
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                "${optionOrder.state.capitalize()} ${formatDate.format(optionOrder.updatedAt!)}"),
            if (optionOrder.optionEvents != null) ...[
              Text(
                "${optionOrder.optionEvents!.first.type == "expiration" ? "Expired" : (optionOrder.optionEvents!.first.type == "assignment" ? "Assigned" : (optionOrder.optionEvents!.first.type == "exercise" ? "Exercised" : optionOrder.optionEvents!.first.type))} ${formatCompactDate.format(optionOrder.optionEvents!.first.eventDate!)} at ${optionOrder.optionEvents!.first.underlyingPrice != null ? formatCurrency.format(optionOrder.optionEvents!.first.underlyingPrice) : ""}",
                //style: TextStyle(fontSize: 16.0)
              )
            ]
          ]);

          return Card(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: CircleAvatar(
                    //backgroundImage: AssetImage(user.profilePicture),
                    /*
                    backgroundColor: optionOrder.optionEvents != null
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.secondary,
                        */
                    child: optionOrder.optionEvents != null
                        ? const Icon(Icons.check)
                        : Text('${optionOrder.quantity!.round()}',
                            style: const TextStyle(fontSize: 17))),
                title: Text(
                    "${optionOrders[index].chainSymbol} \$${formatCompactNumber.format(optionOrders[index].legs.first.strikePrice)} ${optionOrders[index].strategy} ${formatCompactDate.format(optionOrders[index].legs.first.expirationDate!)}"), // , style: TextStyle(fontSize: 18.0)),
                subtitle: subtitle,
                trailing: Wrap(spacing: 8, children: [
                  Text(
                    (optionOrders[index].direction == "credit" ? "+" : "-") +
                        (optionOrders[index].processedPremium != null
                            ? formatCurrency
                                .format(optionOrders[index].processedPremium)
                            : ""),
                    style: const TextStyle(fontSize: 18.0),
                    textAlign: TextAlign.right,
                  )
                ]),

                /*Wrap(
            spacing: 12,
            children: [
              Column(children: [
                Text(
                  "${formatCurrency.format(gainLoss)}\n${formatPercentage.format(gainLossPercent)}",
                  style: const TextStyle(fontSize: 15.0),
                  textAlign: TextAlign.right,
                ),
                Icon(
                    gainLossPerContract > 0
                        ? Icons.trending_up
                        : (gainLossPerContract < 0
                            ? Icons.trending_down
                            : Icons.trending_flat),
                    color: (gainLossPerContract > 0
                        ? Colors.green
                        : (gainLossPerContract < 0 ? Colors.red : Colors.grey)))
              ]),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "${formatCurrency.format(marketValue)}",
                    style: const TextStyle(fontSize: 18.0),
                    textAlign: TextAlign.right,
                  ),
                ],
              )
            ],
          ),*/
                isThreeLine: optionOrder.optionEvents != null,
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => OptionOrderWidget(widget.user,
                              widget.account, optionOrders[index])));
                },
              ),
            ],
          ));
        }, childCount: optionOrders.length),
      ),
    );
  }

  Widget get orderFilterWidget {
    return SizedBox(
        height: 56,
        child: ListView.builder(
          padding: const EdgeInsets.all(4.0),
          scrollDirection: Axis.horizontal,
          itemBuilder: (context, index) {
            return Row(children: [
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: FilterChip(
                  //avatar: const Icon(Icons.history_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('Confirmed'),
                  selected: orderFilters.contains("confirmed"),
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        orderFilters.add("confirmed");
                      } else {
                        orderFilters.removeWhere((String name) {
                          return name == "confirmed";
                        });
                      }
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: FilterChip(
                  //avatar: const Icon(Icons.history_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('Filled'),
                  selected: orderFilters.contains("filled"),
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        orderFilters.add("filled");
                      } else {
                        orderFilters.removeWhere((String name) {
                          return name == "filled";
                        });
                      }
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: FilterChip(
                  //avatar: const Icon(Icons.history_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('Cancelled'),
                  selected: orderFilters.contains("cancelled"),
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        orderFilters.add("cancelled");
                      } else {
                        orderFilters.removeWhere((String name) {
                          return name == "cancelled";
                        });
                      }
                    });
                  },
                ),
              ),
            ]);
          },
          itemCount: 1,
        ));
  }

  Widget optionInstrumentsWidget(
      List<OptionInstrument> optionInstruments, Instrument instrument,
      {OptionAggregatePosition? optionPosition}) {
    return SliverList(
      // delegate: SliverChildListDelegate(widgets),
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) {
          if (optionInstruments.length > index) {
            if (typeFilter!.toLowerCase() !=
                    optionInstruments[index].type.toLowerCase() ||
                expirationDateFilter == null ||
                !expirationDateFilter!.isAtSameMomentAs(
                    optionInstruments[index].expirationDate!)) {
              return Container();
            }
            // TODO: Optimize to batch calls for market data.
            if (optionInstruments[index].optionMarketData == null) {
              RobinhoodService.getOptionMarketData(
                      widget.user, optionInstruments[index])
                  .then((value) => setState(() {
                        optionInstruments[index].optionMarketData = value;
                      }));
            }
            var optionPositionsMatchingInstrument = optionPositions.where(
                (e) => e.optionInstrument!.id == optionInstruments[index].id);
            var optionInstrumentQuantity =
                optionPositionsMatchingInstrument.isNotEmpty
                    ? optionPositionsMatchingInstrument
                        .map((e) => e.quantity ?? 0)
                        .reduce((a, b) => a + b)
                    : 0;
            return Card(
                child:
                    Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
              ListTile(
                //key: index == 0 ? dataKey : null,
                /*optionInstruments[index].id ==
                          firstOptionsInstrumentsSorted.id
                      ? dataKey
                      : null,
                      */
                /*
                  leading: CircleAvatar(
                      backgroundColor: optionInstruments[index].type == 'call'
                          ? Colors.green
                          : Colors.amber,
                      //backgroundImage: AssetImage(user.profilePicture),
                      child: optionInstruments[index].type == 'call'
                          ? const Text('Call')
                          : const Text('Put')),
                          */
                /*
                leading: CircleAvatar(
                    //backgroundImage: AssetImage(user.profilePicture),
                    child: Text('${optionOrders[index].quantity!.round()}',
                        style: const TextStyle(fontSize: 18))),
                leading: Icon(Icons.ac_unit),
                */
                leading: optionInstrumentQuantity > 0
                    ? CircleAvatar(
                        //backgroundImage: AssetImage(user.profilePicture),
                        child: Text(
                            formatCompactNumber
                                .format(optionInstrumentQuantity),
                            style: const TextStyle(fontSize: 18)))
                    : null, //Icon(Icons.ac_unit),
                title: Text(//${optionInstruments[index].chainSymbol}
                    '\$${formatCompactNumber.format(optionInstruments[index].strikePrice)} ${optionInstruments[index].type}'), // , style: TextStyle(fontSize: 18.0)),
                subtitle: Text(optionInstruments[index].optionMarketData != null
                    //? "Breakeven ${formatCurrency.format(optionInstruments[index].optionMarketData!.breakEvenPrice)}\nChance Long: ${optionInstruments[index].optionMarketData!.chanceOfProfitLong != null ? formatPercentage.format(optionInstruments[index].optionMarketData!.chanceOfProfitLong) : "-"} Short: ${optionInstruments[index].optionMarketData!.chanceOfProfitLong != null ? formatPercentage.format(optionInstruments[index].optionMarketData!.chanceOfProfitShort) : "-"}"
                    ? "Breakeven ${formatCurrency.format(optionInstruments[index].optionMarketData!.breakEvenPrice)}"
                    : ""),
                //'Issued ${dateFormat.format(optionInstruments[index].issueDate as DateTime)}'),
                trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      optionInstruments[index].optionMarketData != null
                          ? Text(
                              formatCurrency.format(optionInstruments[index]
                                  .optionMarketData!
                                  .markPrice),
                              //"${formatCurrency.format(optionInstruments[index].optionMarketData!.bidPrice)} - ${formatCurrency.format(optionInstruments[index].optionMarketData!.markPrice)} - ${formatCurrency.format(optionInstruments[index].optionMarketData!.askPrice)}",
                              style: const TextStyle(fontSize: 18))
                          : const Text(""),
                      Wrap(spacing: 8, children: [
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
                                    : Colors.grey)),
                            size: 16),
                        Text(
                          optionInstruments[index].optionMarketData != null
                              ? formatPercentage.format(optionInstruments[index]
                                  .optionMarketData!
                                  .gainLossPercentToday)
                              : "-",
                          //style: TextStyle(fontSize: 16),
                        )
                      ]),
                    ]),
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => OptionInstrumentWidget(
                                widget.user,
                                widget.account,
                                optionInstruments[index],
                                optionPosition: optionInstrumentQuantity > 0
                                    ? optionPosition
                                    : null,
                              )));
                },
              )
            ]));

            //return Text('\$${optionInstruments[index].strikePrice}');
          }
          return null;
          // To convert this infinite list to a list with three items,
          // uncomment the following line:
          // if (index > 3) return null;
        },
        // Or, uncomment the following line:
        // childCount: widgets.length + 10,
      ),
    );
  }

  Widget headerTitle(Instrument instrument) {
    return Wrap(
        crossAxisAlignment: WrapCrossAlignment.start,
        //runAlignment: WrapAlignment.end,
        //alignment: WrapAlignment.end,
        spacing: 10,
        //runSpacing: 5,
        children: [
          Text(
            instrument.symbol, // ${optionPosition.strategy.split('_').first}
            //style: const TextStyle(fontSize: 20.0)
          ),
          if (instrument.quoteObj != null) ...[
            Text(
              formatCurrency.format(instrument.quoteObj!.lastTradePrice),
              //style: const TextStyle(fontSize: 15.0)
            ),
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
                //size: 15.0
              ),
              Container(
                width: 2,
              ),
              Text(
                formatPercentage
                    .format(instrument.quoteObj!.changePercentToday),
                //style: const TextStyle(fontSize: 15.0)
              ),
            ]),
            Text(
                "${instrument.quoteObj!.changeToday > 0 ? "+" : instrument.quoteObj!.changeToday < 0 ? "-" : ""}${formatCurrency.format(instrument.quoteObj!.changeToday.abs())}",
                //style: const TextStyle(fontSize: 12.0),
                textAlign: TextAlign.right)
          ],
        ]);
  }

  Iterable<Widget> get headerWidgets sync* {
    var instrument = widget.instrument;
    // yield Row(children: const [SizedBox(height: 70)]);
    if (instrument.simpleName != null) {
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
                  child: Text(
                    '${instrument.simpleName}',
                    style: const TextStyle(fontSize: 16.0),
                    textAlign: TextAlign.left,
                    //overflow: TextOverflow.ellipsis
                  ))
            ]),
            Container(
              width: 10,
            ),
          ]);
    } else {
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
                  child: Text(
                    '$instrument.name',
                    style: const TextStyle(fontSize: 14.0),
                    textAlign: TextAlign.left,
                    //overflow: TextOverflow.ellipsis
                  ))
            ]),
            Container(
              width: 10,
            ),
          ]);
    }
    /*
    yield Row(children: const [SizedBox(height: 10)]);
    */
    if (instrument.quoteObj != null) {
      /*
      yield Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Container(
              width: 10,
            ),
            Column(mainAxisAlignment: MainAxisAlignment.start, children: const [
              SizedBox(
                width: 60,
                child: Text(
                  "Today",
                  style: TextStyle(fontSize: 10.0),
                ),
              )
            ]),
            Container(
              width: 5,
            ),
            Column(mainAxisAlignment: MainAxisAlignment.start, children: [
              SizedBox(
                  width: 60,
                  child: Wrap(children: [
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
                        size: 14.0),
                    Container(
                      width: 2,
                    ),
                    Text(
                        formatPercentage
                            .format(instrument.quoteObj!.changePercentToday),
                        style: const TextStyle(fontSize: 12.0)),
                  ]))
            ]),
            Container(
              width: 5,
            ),
            SizedBox(
                width: 60,
                child: Text(
                    "${instrument.quoteObj!.changeToday > 0 ? "+" : instrument.quoteObj!.changeToday < 0 ? "-" : ""}${formatCurrency.format(instrument.quoteObj!.changeToday.abs())}",
                    style: const TextStyle(fontSize: 12.0),
                    textAlign: TextAlign.right)),
            Container(
              width: 10,
            ),
          ]);
      yield Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Container(
              width: 10,
            ),
            Column(mainAxisAlignment: MainAxisAlignment.start, children: const [
              SizedBox(
                width: 70,
                child: Text(
                  "Last Price",
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
                    formatCurrency.format(instrument.quoteObj!.lastTradePrice),
                    style: const TextStyle(fontSize: 12.0),
                    textAlign: TextAlign.right)),
            Container(
              width: 10,
            ),
          ]);
          */
      if (instrument.quoteObj!.lastExtendedHoursTradePrice != null) {
        yield Row(
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
                        "After Hours",
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
                      formatCurrency.format(
                          instrument.quoteObj!.lastExtendedHoursTradePrice),
                      style: const TextStyle(fontSize: 12.0),
                      textAlign: TextAlign.right)),
              Container(
                width: 10,
              ),
            ]);
      }
      yield Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Container(
              width: 10,
            ),
            Column(mainAxisAlignment: MainAxisAlignment.start, children: const [
              SizedBox(
                width: 70,
                child: Text(
                  "Bid",
                  style: TextStyle(fontSize: 10.0),
                ),
              )
            ]),
            Container(
              width: 5,
            ),
            SizedBox(
                width: 115,
                child: //Wrap(children: [
                    Text(
                        "${formatCurrency.format(instrument.quoteObj!.bidPrice)} x ${formatCompactNumber.format(instrument.quoteObj!.bidSize)}",
                        style: const TextStyle(fontSize: 12.0),
                        textAlign: TextAlign.right)
                //]),
                ),
            Container(
              width: 10,
            ),
          ]);
      yield Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Container(
              width: 10,
            ),
            Column(mainAxisAlignment: MainAxisAlignment.start, children: const [
              SizedBox(
                width: 70,
                child: Text(
                  "Ask",
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
                    "${formatCurrency.format(instrument.quoteObj!.askPrice)} x ${formatCompactNumber.format(instrument.quoteObj!.askSize)}",
                    style: const TextStyle(fontSize: 12.0),
                    textAlign: TextAlign.right)),
            Container(
              width: 10,
            ),
          ]);
      yield Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Container(
              width: 10,
            ),
            Column(mainAxisAlignment: MainAxisAlignment.start, children: const [
              SizedBox(
                width: 70,
                child: Text(
                  "Previous Close",
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
                    formatCurrency
                        .format(instrument.quoteObj!.adjustedPreviousClose),
                    style: const TextStyle(fontSize: 12.0),
                    textAlign: TextAlign.right)),
            Container(
              width: 10,
            ),
          ]);
    }
    /*
    yield Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Container(
            width: 10,
          ),
          Column(mainAxisAlignment: MainAxisAlignment.start, children: [
            const SizedBox(
              width: 70,
              child: Text(
                "Extended Hours Price",
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
                  "${formatCurrency.format(instrument.quoteObj!.lastExtendedHoursTradePrice)}",
                  style: const TextStyle(fontSize: 12.0),
                  textAlign: TextAlign.right)),
          Container(
            width: 10,
          ),
        ]);
        */
    /*
      Row(children: [
        Text(
            '${optionPosition.strategy.split('_').first} ${optionPosition.optionInstrument!.type.toUpperCase()}',
            style: const TextStyle(fontSize: 17.0)),
      ])
      */
  }

  Iterable<Widget> get expirationDateWidgets sync* {
    if (expirationDates != null) {
      for (var expirationDate in expirationDates!) {
        yield Padding(
          padding: const EdgeInsets.all(4.0),
          child: ChoiceChip(
            //avatar: CircleAvatar(child: Text(contractCount.toString())),
            label: Text(formatDate.format(expirationDate)),
            selected: expirationDateFilter! == expirationDate,
            onSelected: (bool selected) {
              setState(() {
                expirationDateFilter = selected ? expirationDate : null;
              });
              optionInstrumentStream = null;
            },
          ),
        );
        /*        
        Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              children: [
                //Icon(Icons.trending_up),
                SizedBox(width: 10),
                Text(
                  "${dateFormat.format(expirationDate)}",
                  style: TextStyle(fontSize: 16),
                )
              ],
            ));
            */
      }
    }
  }

  Card buildOptions() {
    return Card(
        child: ToggleButtons(
      children: <Widget>[
        Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              children: const [
                CircleAvatar(child: Text("C", style: TextStyle(fontSize: 18))),
                //Icon(Icons.trending_up),
                SizedBox(width: 10),
                Text(
                  'Call',
                  style: TextStyle(fontSize: 16),
                )
              ],
            )),
        Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: const [
              CircleAvatar(child: Text("P", style: TextStyle(fontSize: 18))),
              // Icon(Icons.trending_down),
              SizedBox(width: 10),
              Text(
                'Put',
                style: TextStyle(fontSize: 16),
              )
            ],
          ),
        ),
        //Icon(Icons.ac_unit),
        //Icon(Icons.call),
        //Icon(Icons.cake),
      ],
      onPressed: (int index) {
        setState(() {
          for (int buttonIndex = 0;
              buttonIndex < isSelected.length;
              buttonIndex++) {
            if (buttonIndex == index) {
              isSelected[buttonIndex] = true;
            } else {
              isSelected[buttonIndex] = false;
            }
          }
          /*
          if (index == 0 && futureCallOptionInstruments == null) {
            futureCallOptionInstruments =
                RobinhoodService.downloadOptionInstruments(
                    user, instrument, null, 'call');
          } else if (index == 1 && futurePutOptionInstruments == null) {
            futurePutOptionInstruments =
                RobinhoodService.downloadOptionInstruments(
                    user, instrument, null, 'put');
          }
          */
        });
      },
      isSelected: isSelected,
    ));
  }
}
