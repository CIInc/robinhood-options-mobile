import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/extension_methods.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/option_event.dart';
import 'package:robinhood_options_mobile/widgets/chart_widget.dart';
import 'package:robinhood_options_mobile/widgets/disclaimer_widget.dart';
import 'package:robinhood_options_mobile/widgets/instrument_option_chain_widget.dart';
import 'package:robinhood_options_mobile/widgets/list_widget.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:charts_flutter/flutter.dart' as charts;

import 'package:robinhood_options_mobile/model/fundamentals.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_historical.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
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
final formatLongDate = DateFormat("EEEE MMMM d, y hh:mm:ss a");
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
  Future<List<dynamic>>? futureNews;
  Future<List<dynamic>>? futureLists;
  Future<dynamic>? futureRatings;
  Future<dynamic>? futureRatingsOverview;
  Future<dynamic>? futureEarnings;
  Future<List<dynamic>>? futureSimilar;
  Future<List<dynamic>>? futureSplits;
  Future<List<PositionOrder>>? futureInstrumentOrders;
  Future<List<OptionOrder>>? futureOptionOrders;
  Future<List<OptionEvent>>? futureOptionEvents;

  //charts.TimeSeriesChart? chart;
  Chart? chart;
  ChartDateSpan chartDateSpanFilter = ChartDateSpan.day;
  Bounds chartBoundsFilter = Bounds.regular;
  InstrumentHistorical? selection;

  final List<String> optionFilters = <String>[];
  final List<String> positionFilters = <String>[];

  final List<bool> hasQuantityFilters = [true, false];

  final List<String> orderFilters = <String>["confirmed", "filled"];

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
                (e.averagePrice != null ? e.averagePrice! * e.quantity! : 0.0) *
                (e.side == "buy" ? 1 : -1))
            .reduce((a, b) => a + b)
        : 0.0;
  }

/*
  // scopes: [acats, balances, document_upload, edocs, funding:all:read, funding:ach:read, funding:ach:write, funding:wire:read, funding:wire:write, internal, investments, margin, read, signup, trade, watchlist, web_limited])
  Request to https://api.robinhood.com/marketdata/options/?instruments=942d3704-7247-454f-9fb6-1f98f5d41702 failed with status 400: Bad Request.
  */

  @override
  Widget build(BuildContext context) {
    var instrument = widget.instrument;
    var user = widget.user;

    if (widget.instrument.logoUrl == null &&
        RobinhoodService.logoUrls.containsKey(widget.instrument.symbol)) {
      widget.instrument.logoUrl =
          RobinhoodService.logoUrls[widget.instrument.symbol];
    }

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

    futureNews ??= RobinhoodService.getNews(user, instrument.symbol);

    futureLists ??= RobinhoodService.getLists(user, instrument.id);

    futureRatings ??= RobinhoodService.getRatings(user, instrument.id);
    futureRatingsOverview ??=
        RobinhoodService.getRatingsOverview(user, instrument.id);

    futureEarnings ??= RobinhoodService.getEarnings(user, instrument.id);

    futureSimilar ??= RobinhoodService.getSimilar(user, instrument.id);

    futureSplits ??= RobinhoodService.getSplits(user, instrument);

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

    futureOptionEvents ??= RobinhoodService.getOptionEventsByInstrumentUrl(
        widget.user, instrument.url);

    return Scaffold(
        body: FutureBuilder(
      future: Future.wait([
        futureQuote as Future,
        futureFundamentals as Future,
        futureHistoricals as Future,
        futureNews as Future,
        futureLists as Future,
        futureRatings as Future,
        futureRatingsOverview as Future,
        futureInstrumentOrders as Future,
        futureOptionOrders as Future,
        futureOptionEvents as Future,
        futureEarnings as Future,
        futureSimilar as Future,
        futureSplits as Future
      ]),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          List<dynamic> data = snapshot.data as List<dynamic>;
          instrument.quoteObj = data.isNotEmpty ? data[0] : null;
          instrument.fundamentalsObj = data.length > 1 ? data[1] : null;

          if (instrument.instrumentHistoricalsObj == null ||
              data[2].bounds != instrument.instrumentHistoricalsObj!.bounds ||
              data[2].span != instrument.instrumentHistoricalsObj!.span) {
            chart = null;
          }

          instrument.instrumentHistoricalsObj =
              data.length > 2 ? data[2] : null;
          instrument.newsObj = data.length > 3 ? data[3] : null;
          instrument.listsObj = data.length > 4 ? data[4] : null;
          instrument.ratingsObj = data.length > 5 ? data[5] : null;
          instrument.ratingsOverviewObj = data.length > 6 ? data[6] : null;
          instrument.positionOrders = data.length > 7 ? data[7] : null;
          instrument.optionOrders = data.length > 8 ? data[8] : null;
          instrument.optionEvents = data.length > 9 ? data[9] : null;
          instrument.earningsObj = data.length > 10 ? data[10] : null;
          instrument.similarObj = data.length > 11 ? data[11] : null;
          instrument.splitsObj = data.length > 12 ? data[12] : null;

          positionOrders = instrument.positionOrders!;
          _calculatePositionOrderBalance();
          optionOrders = instrument.optionOrders!;
          _calculateOptionOrderBalance();

          return buildScrollView(instrument,
              position: widget.position,
              done: snapshot.connectionState == ConnectionState.done);
        } else if (snapshot.hasError) {
          debugPrint("${snapshot.error}");
          return Text("${snapshot.error}");
        }
        return buildScrollView(instrument,
            position: widget.position,
            done: snapshot.connectionState == ConnectionState.done);
      },
    ));
  }

  buildScrollView(Instrument instrument,
      {List<OptionInstrument>? optionInstruments,
      Position? position,
      bool done = false}) {
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
                child: instrument.logoUrl != null
                    ? Image.network(
                        instrument.logoUrl!,
                        fit: BoxFit.none,
                        errorBuilder: (BuildContext context, Object exception,
                            StackTrace? stackTrace) {
                          return const
                              //CircleAvatar(child: Text(""));
                              SizedBox(width: 56, height: 56);
                          //const Icon(Icons.error); //Text('Your error widget...');
                        },
                      )
                    : Image.network(
                        Constants.flexibleSpaceBarBackground,
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

      if (selection != null) {
// portfolios![0].equityPreviousClose!;
      }

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
        chart = Chart(seriesList,
            open: open,
            close: close,
            hiddenSeries: const ["Close", "Volume", "Low", "High"],
            onSelected: _onChartSelection);
      }

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
              height: 420,
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

    if (instrument.ratingsObj != null &&
        instrument.ratingsObj["summary"] != null) {
      slivers.add(const SliverToBoxAdapter(
          child: SizedBox(
        height: 25.0,
      )));
      slivers.add(_buildRatingsWidget(instrument));
    }

    if (instrument.ratingsOverviewObj != null) {
      slivers.add(const SliverToBoxAdapter(
          child: SizedBox(
        height: 25.0,
      )));
      slivers.add(_buildRatingsOverviewWidget(instrument));
    }

    if (instrument.earningsObj != null) {
      slivers.add(const SliverToBoxAdapter(
          child: SizedBox(
        height: 25.0,
      )));
      slivers.add(_buildEarningsWidget(instrument));
    }

    if (instrument.splitsObj != null && instrument.splitsObj!.isNotEmpty) {
      slivers.add(const SliverToBoxAdapter(
          child: SizedBox(
        height: 25.0,
      )));
      slivers.add(_buildSplitsWidget(instrument));
    }

    if (instrument.newsObj != null) {
      slivers.add(const SliverToBoxAdapter(
          child: SizedBox(
        height: 25.0,
      )));
      slivers.add(_buildNewsWidget(instrument));
    }

    if (instrument.similarObj != null) {
      slivers.add(const SliverToBoxAdapter(
          child: SizedBox(
        height: 25.0,
      )));
      slivers.add(_buildSimilarWidget(instrument));
    }

    if (instrument.listsObj != null) {
      slivers.add(const SliverToBoxAdapter(
          child: SizedBox(
        height: 25.0,
      )));
      slivers.add(_buildListsWidget(instrument));
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
      futureFundamentals = null;
      futureHistoricals = null;
      futureNews = null;
      //futureInstrumentOrders = null;
      //futureOptionOrders = null;
    });
  }

  _onChartSelection(dynamic historical) {
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
            const SizedBox(width: 8),
            TextButton(
              child: const Text('OPTION CHAIN'),
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => InstrumentOptionChainWidget(
                            widget.user, widget.account, instrument)));
              },
            ),
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

  Widget _buildRatingsWidget(Instrument instrument) {
    return SliverStickyHeader(
      header: Material(
          elevation: 2,
          child: Container(
              //height: 208.0, //60.0,
              //padding: EdgeInsets.symmetric(horizontal: 16.0),
              alignment: Alignment.centerLeft,
              child: const ListTile(
                title: Text(
                  "Ratings",
                  style: TextStyle(fontSize: 19.0),
                ),
              ))),
      sliver: SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 150.0,
                //mainAxisSpacing: 6.0,
                crossAxisSpacing: 2.0,
                childAspectRatio: 1.3),
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) {
                switch (index) {
                  case 0:
                    return Card(
                        child: InkWell(
                      child: Center(
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                  formatCompactNumber.format(
                                      instrument.ratingsObj["summary"]
                                          ["num_buy_ratings"]),
                                  style: const TextStyle(fontSize: 21.0)),
                              Container(
                                height: 5,
                              ),
                              const Text("Buy",
                                  style: TextStyle(fontSize: 17.0)),
                              //const Text("Delta",
                              //    style: TextStyle(fontSize: 10.0)),
                            ]),
                      ),
                      onTap: () {
                        showDialog<String>(
                          context: context,
                          builder: (BuildContext context) => AlertDialog(
                            title: const Text('Buy Ratings'),
                            content: SingleChildScrollView(
                                child: Column(children: [
                              for (var rating
                                  in instrument.ratingsObj["ratings"]) ...[
                                if (rating["type"] == "buy") ...[
                                  Text("${rating["text"]}\n"),
                                  Text(
                                      "${formatLongDate.format(DateTime.parse(rating["published_at"]))}\n",
                                      style: const TextStyle(fontSize: 11.0)),
                                ]
                              ]
                            ])),
                            actions: <Widget>[
                              TextButton(
                                onPressed: () => Navigator.pop(context, 'OK'),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                      },
                    ));
                  case 1:
                    return Card(
                      child: Center(
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                  formatCompactNumber.format(
                                      instrument.ratingsObj["summary"]
                                          ["num_hold_ratings"]),
                                  style: const TextStyle(fontSize: 21.0)),
                              Container(
                                height: 5,
                              ),
                              const Text("Hold",
                                  style: TextStyle(fontSize: 17.0)),
                              //const Text("Gamma",
                              //    style: TextStyle(fontSize: 10.0)),
                            ]),
                      ),
                    );
                  case 2:
                    return Card(
                        child: InkWell(
                      child: Center(
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                  formatCompactNumber.format(
                                      instrument.ratingsObj["summary"]
                                          ["num_sell_ratings"]),
                                  style: const TextStyle(fontSize: 21.0)),
                              Container(
                                height: 5,
                              ),
                              const Text("Sell",
                                  style: TextStyle(fontSize: 17.0)),
                              //const Text("Theta",
                              //    style: TextStyle(fontSize: 10.0)),
                            ]),
                      ),
                      onTap: () {
                        showDialog<String>(
                          context: context,
                          builder: (BuildContext context) => AlertDialog(
                            title: const Text('Sell Ratings'),
                            content: SingleChildScrollView(
                                child: Column(children: [
                              for (var rating
                                  in instrument.ratingsObj["ratings"]) ...[
                                if (rating["type"] == "sell") ...[
                                  Text("${rating["text"]}\n"),
                                  Text(
                                      "${formatLongDate.format(DateTime.parse(rating["published_at"]))}\n",
                                      style: const TextStyle(fontSize: 11.0)),
                                ]
                              ]
                            ])),
                            actions: <Widget>[
                              TextButton(
                                onPressed: () => Navigator.pop(context, 'OK'),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                      },
                    ));

                  default:
                }
              },
              childCount: 3,
            ),
          )),
      /*
      SliverToBoxAdapter(
          child: Align(
              alignment: Alignment.center,
              child: Card(
                  child: Column(
                      mainAxisSize: MainAxisSize.min, children: <Widget>[
                        Row()
                      ])))),
                      */
    );
  }

  Widget _buildRatingsOverviewWidget(Instrument instrument) {
    if (instrument.ratingsOverviewObj == null) {
      return Container();
    }
    return SliverStickyHeader(
        header: Material(
            elevation: 2,
            child: Container(
                //height: 208.0, //60.0,
                //padding: EdgeInsets.symmetric(horizontal: 16.0),
                alignment: Alignment.centerLeft,
                child: const ListTile(
                  title: Text(
                    "Research",
                    style: TextStyle(fontSize: 19.0),
                  ),
                ))),
        sliver: SliverToBoxAdapter(
            child: Card(
                child:
                    Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          const SizedBox(height: 15),
          ListTile(
            title: Text(
              instrument.ratingsOverviewObj!["report_title"],
              style: const TextStyle(fontSize: 18.0),
              //overflow: TextOverflow.visible
            ),
            subtitle: Text(
                instrument.ratingsOverviewObj!["report_updated_at"] != null
                    ? "Updated ${formatDate.format(DateTime.parse(instrument.ratingsOverviewObj!["report_updated_at"]))} by ${instrument.ratingsOverviewObj!["source"].toString().capitalize()}"
                    : "Published ${formatDate.format(DateTime.parse(instrument.ratingsOverviewObj!["report_published_at"]))} by ${instrument.ratingsOverviewObj!["source"].toString().capitalize()}",
                style: const TextStyle(fontSize: 14)),
          ),
          if (instrument.ratingsOverviewObj!["fair_value"] != null) ...[
            ListTile(
              title: const Text("Fair Value"),
              trailing: Text(
                  formatCurrency.format(double.parse(
                      instrument.ratingsOverviewObj!["fair_value"]["value"])),
                  style: const TextStyle(fontSize: 18)),
            ),
          ],
          ListTile(
            title: const Text("Economic Moat"),
            trailing: Text(
                instrument.ratingsOverviewObj!["economic_moat"]
                    .toString()
                    .capitalize(),
                style: const TextStyle(fontSize: 18)),
          ),
          if (instrument.ratingsOverviewObj!["star_rating"] != null) ...[
            ListTile(
                title: const Text("Star Rating"),
                trailing: Wrap(
                  children: [
                    for (var i = 0;
                        i <
                            int.parse(
                                instrument.ratingsOverviewObj!["star_rating"]);
                        i++) ...[
                      const Icon(Icons.star),
                    ]
                  ],
                )
                /*
            Text(
                instrument.ratingsOverviewObj!["star_rating"]
                    .toString()
                    .capitalize(),
                style: const TextStyle(fontSize: 18)),
                */
                ),
          ],
          ListTile(
            title: const Text("Stewardship"),
            trailing: Text(
                instrument.ratingsOverviewObj!["stewardship"]
                    .toString()
                    .capitalize(),
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Uncertainty"),
            trailing: Text(
                instrument.ratingsOverviewObj!["uncertainty"]
                    .toString()
                    .capitalize(),
                style: const TextStyle(fontSize: 18)),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: <Widget>[
            TextButton(
              child: const Text('DOWNLOAD REPORT'),
              onPressed: () async {
                var _url = instrument.ratingsOverviewObj!["download_url"];
                await canLaunch(_url)
                    ? await launch(_url)
                    : throw 'Could not launch $_url';
              },
            ),
          ])
        ]))));
  }

  Widget _buildEarningsWidget(Instrument instrument) {
    var futureEarning =
        instrument.earningsObj![instrument.earningsObj!.length - 1];
    var pastEarning =
        instrument.earningsObj![instrument.earningsObj!.length - 2];
    return SliverStickyHeader(
        header: Material(
            elevation: 2,
            child: Container(
                //height: 208.0, //60.0,
                //padding: EdgeInsets.symmetric(horizontal: 16.0),
                alignment: Alignment.centerLeft,
                child: const ListTile(
                  title: Text(
                    "Earnings",
                    style: TextStyle(fontSize: 19.0),
                  ),
                ))),
        sliver: SliverToBoxAdapter(
            child: Card(
                child:
                    Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          for (var earning in instrument.earningsObj!) ...[
            ListTile(
                title: Text(
                  "${earning!["year"]} Q${earning!["quarter"]}",
                  style: const TextStyle(fontSize: 18.0),
                  //overflow: TextOverflow.visible
                ),
                subtitle: Text(
                    "Report${earning!["report"]["verified"] ? "ed" : "ing"} ${formatDate.format(DateTime.parse(earning!["report"]["date"]))} ${earning!["report"]["timing"]}",
                    style: const TextStyle(fontSize: 14)),
                trailing: (earning!["eps"]["estimate"] != null ||
                        earning!["eps"]["actual"] != null)
                    ? Wrap(spacing: 10.0, children: [
                        if (earning!["eps"]["estimate"] != null) ...[
                          Column(
                            children: [
                              const Text("Estimate",
                                  style: TextStyle(fontSize: 11)),
                              Text(
                                  formatCurrency.format(double.parse(
                                      earning!["eps"]["estimate"])),
                                  style: const TextStyle(fontSize: 18)),
                            ],
                          )
                        ],
                        if (earning!["eps"]["actual"] != null) ...[
                          Column(children: [
                            const Text("Actual",
                                style: TextStyle(fontSize: 11)),
                            Text(
                                formatCurrency.format(
                                    double.parse(earning!["eps"]["actual"])),
                                style: const TextStyle(fontSize: 18))
                          ])
                        ]
                      ])
                    : null),
            if (earning!["call"] != null &&
                ((pastEarning["year"] == earning!["year"] &&
                        pastEarning["quarter"] == earning!["quarter"]) ||
                    (futureEarning["year"] == earning!["year"] &&
                        futureEarning["quarter"] == earning!["quarter"]))) ...[
              if (!earning!["report"]["verified"]) ...[
                ListTile(
                  title: Text(
                      "Report${earning!["report"]["verified"] ? "ed" : "ing"} ${formatDate.format(DateTime.parse(earning!["report"]["date"]))} ${earning!["report"]["timing"]}",
                      style: const TextStyle(fontSize: 18)),
                  subtitle: Text(
                      formatLongDate.format(DateTime.parse(earning!["call"]
                          ["datetime"])), // ${earning!["report"]["timing"]}",
                      style: const TextStyle(fontSize: 16)),
                ),
              ],
              Row(mainAxisAlignment: MainAxisAlignment.end, children: <Widget>[
                if (earning!["call"]["replay_url"] != null) ...[
                  TextButton(
                    child: const Text('LISTEN TO REPLAY'),
                    onPressed: () async {
                      var _url = earning!["call"]["replay_url"];
                      await canLaunch(_url)
                          ? await launch(_url)
                          : throw 'Could not launch $_url';
                    },
                  ),
                ],
                if (earning!["call"]["broadcast_url"] != null) ...[
                  Container(width: 50),
                  TextButton(
                    child: const Text('LISTEN TO BROADCAST'),
                    onPressed: () async {
                      var _url = earning!["call"]["broadcast_url"];
                      await canLaunch(_url)
                          ? await launch(_url)
                          : throw 'Could not launch $_url';
                    },
                  ),
                ],
              ])
            ],
          ],
        ]))));
  }

  Widget _buildSplitsWidget(Instrument instrument) {
    return SliverStickyHeader(
        header: Material(
            elevation: 2,
            child: Container(
                //height: 208.0, //60.0,
                //padding: EdgeInsets.symmetric(horizontal: 16.0),
                alignment: Alignment.centerLeft,
                child: const ListTile(
                  title: Text(
                    "Splits",
                    style: TextStyle(fontSize: 19.0),
                  ),
                ))),
        sliver: SliverToBoxAdapter(
            child: Card(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const <Widget>[
              /*
          for (var split in instrument.splitsObj!) ...[
            ListTile(
                title: Text(
                  "${earning!["year"]} Q${earning!["quarter"]}",
                  style: const TextStyle(fontSize: 18.0),
                  //overflow: TextOverflow.visible
                ),
                subtitle: Text(
                    "Report${earning!["report"]["verified"] ? "ed" : "ing"} ${formatDate.format(DateTime.parse(earning!["report"]["date"]))} ${earning!["report"]["timing"]}",
                    style: const TextStyle(fontSize: 14)),
                trailing: (earning!["eps"]["estimate"] != null ||
                        earning!["eps"]["actual"] != null)
                    ? Wrap(spacing: 10.0, children: [
                        if (earning!["eps"]["estimate"] != null) ...[
                          Column(
                            children: [
                              const Text("Estimate",
                                  style: TextStyle(fontSize: 11)),
                              Text(
                                  formatCurrency.format(double.parse(
                                      earning!["eps"]["estimate"])),
                                  style: const TextStyle(fontSize: 18)),
                            ],
                          )
                        ],
                        if (earning!["eps"]["actual"] != null) ...[
                          Column(children: [
                            const Text("Actual",
                                style: TextStyle(fontSize: 11)),
                            Text(
                                formatCurrency.format(
                                    double.parse(earning!["eps"]["actual"])),
                                style: const TextStyle(fontSize: 18))
                          ])
                        ]
                      ])
                    : null),
            if (earning!["call"] != null &&
                ((pastEarning["year"] == earning!["year"] &&
                        pastEarning["quarter"] == earning!["quarter"]) ||
                    (futureEarning["year"] == earning!["year"] &&
                        futureEarning["quarter"] == earning!["quarter"]))) ...[
              if (!earning!["report"]["verified"]) ...[
                ListTile(
                  title: Text(
                      "Report${earning!["report"]["verified"] ? "ed" : "ing"} ${formatDate.format(DateTime.parse(earning!["report"]["date"]))} ${earning!["report"]["timing"]}",
                      style: const TextStyle(fontSize: 18)),
                  subtitle: Text(
                      formatLongDate.format(DateTime.parse(earning!["call"]
                          ["datetime"])), // ${earning!["report"]["timing"]}",
                      style: const TextStyle(fontSize: 16)),
                ),
              ],
              Row(mainAxisAlignment: MainAxisAlignment.end, children: <Widget>[
                if (earning!["call"]["replay_url"] != null) ...[
                  TextButton(
                    child: const Text('LISTEN TO REPLAY'),
                    onPressed: () async {
                      var _url = earning!["call"]["replay_url"];
                      await canLaunch(_url)
                          ? await launch(_url)
                          : throw 'Could not launch $_url';
                    },
                  ),
                ],
                if (earning!["call"]["broadcast_url"] != null) ...[
                  Container(width: 50),
                  TextButton(
                    child: const Text('LISTEN TO BROADCAST'),
                    onPressed: () async {
                      var _url = earning!["call"]["broadcast_url"];
                      await canLaunch(_url)
                          ? await launch(_url)
                          : throw 'Could not launch $_url';
                    },
                  ),
                ],
              ])
            ],
          ],
              */
            ]))));
  }

  Widget _buildSimilarWidget(Instrument instrument) {
    return SliverStickyHeader(
        header: Material(
            elevation: 2,
            child: Container(
                //height: 208.0, //60.0,
                //padding: EdgeInsets.symmetric(horizontal: 16.0),
                alignment: Alignment.centerLeft,
                child: const ListTile(
                  title: Text(
                    "Similar",
                    style: TextStyle(fontSize: 19.0),
                  ),
                ))),
        sliver: SliverList(
          // delegate: SliverChildListDelegate(widgets),
          delegate:
              SliverChildBuilderDelegate((BuildContext context, int index) {
            return Card(
                child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  leading: instrument.similarObj![index]["logo_url"] != null
                      ? Image.network(
                          instrument.similarObj![index]["logo_url"]
                              .toString()
                              .replaceAll("https:////", "https://"),
                          width: 56,
                          height: 56,
                          errorBuilder: (BuildContext context, Object exception,
                              StackTrace? stackTrace) {
                            return const
                                //CircleAvatar(child: Text(""));
                                SizedBox(width: 56, height: 56);
                            //const Icon(Icons.error); //Text('Your error widget...');
                          },
                        )
                      : const SizedBox(width: 56, height: 56),
                  title: Text(
                    "${instrument.similarObj![index]["symbol"]}",
                  ), //style: TextStyle(fontSize: 17.0)),
                  subtitle: Text("${instrument.similarObj![index]["name"]}"),
                  // ["tags"][0]["name"]
                  /*
                  trailing: Text(instrument.similarObj![index]["extraData"]
                      ["popularityFraction"]), // ["boostFraction"]
                      */
                  //isThreeLine: true,
                  onTap: () async {
                    var similarInstruments =
                        await RobinhoodService.getInstrumentsByIds(widget.user,
                            [instrument.similarObj![index]["instrument_id"]]);
                    similarInstruments[0].logoUrl = instrument
                        .similarObj![index]["logo_url"]
                        .toString()
                        .replaceAll("https:////", "https://");
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => InstrumentWidget(widget.user,
                                widget.account, similarInstruments[0])));
                  },
                ),
              ],
            ));

            //if (positionOrders.length > index) {
            //}
          }, childCount: instrument.similarObj!.length),
        ));
  }

  Widget _buildListsWidget(Instrument instrument) {
    return SliverStickyHeader(
      header: Material(
          elevation: 2,
          child: Container(
              //height: 208.0, //60.0,
              //padding: EdgeInsets.symmetric(horizontal: 16.0),
              alignment: Alignment.centerLeft,
              child: const ListTile(
                title: Text(
                  "Lists",
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
                leading: instrument.listsObj![index]["image_urls"] != null
                    ? Image.network(instrument.listsObj![index]["image_urls"]
                        ["circle_64:3"]) //,width: 96, height: 56
                    : Container(), //SizedBox(width: 96, height: 56),
                title: Text(
                  "${instrument.listsObj![index]["display_name"]} - ${instrument.listsObj![index]["item_count"]} items",
                ), //style: TextStyle(fontSize: 17.0)),
                subtitle: Text(
                    "${instrument.listsObj![index]["display_description"]}"),
                /*
                  trailing: Image.network(
                      instrument.newsObj![index]["preview_image_url"])
                      */
                isThreeLine: true,
                onTap: () async {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ListWidget(
                              widget.user,
                              widget.account,
                              instrument.listsObj![index]["id"].toString())));
                },
              ),
            ],
          ));

          //if (positionOrders.length > index) {
          //}
        }, childCount: instrument.listsObj!.length),
      ),
    );
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
                  (e.averagePrice != null
                      ? e.averagePrice! * e.quantity!
                      : 0.0) *
                  (e.side == "sell" ? 1 : -1))
              .reduce((a, b) => a + b);

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
                    "${positionOrders[index].side == "buy" ? "Buy" : positionOrders[index].side == "sell" ? "Sell" : positionOrders[index].side} ${positionOrders[index].quantity} at \$${positionOrders[index].averagePrice != null ? formatCompactNumber.format(positionOrders[index].averagePrice) : ""}"), // , style: TextStyle(fontSize: 18.0)),
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

  Widget headerTitle(Instrument instrument) {
    return Wrap(
        crossAxisAlignment: WrapCrossAlignment.end,
        //runAlignment: WrapAlignment.end,
        //alignment: WrapAlignment.end,
        spacing: 20,
        //runSpacing: 5,
        children: [
          Text(
            instrument.symbol, // ${optionPosition.strategy.split('_').first}
            //style: const TextStyle(fontSize: 20.0)
          ),
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
        ]);
  }

  Iterable<Widget> get headerWidgets sync* {
    var instrument = widget.instrument;
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
                child: Text(
                  '${instrument.name != "" ? instrument.name : instrument.simpleName}',
                  //instrument.simpleName ?? instrument.name,
                  style: const TextStyle(fontSize: 16.0),
                  textAlign: TextAlign.left,
                  //overflow: TextOverflow.ellipsis
                ))
          ]),
          Container(
            width: 10,
          ),
        ]);
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
      /*
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
          */
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
}
