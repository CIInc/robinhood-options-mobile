import 'dart:async';
import 'dart:math' as math;
import 'package:collection/collection.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/extension_methods.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals_selection_store.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals_store.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/option_event.dart';
import 'package:robinhood_options_mobile/model/option_order_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';
import 'package:robinhood_options_mobile/model/stock_order_store.dart';
import 'package:robinhood_options_mobile/model/stock_position_store.dart';
import 'package:robinhood_options_mobile/widgets/chart_time_series_widget.dart';
import 'package:robinhood_options_mobile/widgets/disclaimer_widget.dart';
import 'package:robinhood_options_mobile/widgets/instrument_option_chain_widget.dart';
import 'package:robinhood_options_mobile/widgets/list_widget.dart';
import 'package:robinhood_options_mobile/widgets/more_menu_widget.dart';
import 'package:robinhood_options_mobile/widgets/option_orders_widget.dart';
import 'package:robinhood_options_mobile/widgets/option_positions_row_widget.dart';
import 'package:url_launcher/url_launcher.dart';
//import 'package:charts_flutter/flutter.dart' as charts;
import 'package:community_charts_flutter/community_charts_flutter.dart' as charts;

import 'package:robinhood_options_mobile/model/fundamentals.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_historical.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/option_order.dart';
import 'package:robinhood_options_mobile/model/stock_order.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/robinhood_user.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';

final formatDate = DateFormat.yMMMEd(); //.yMEd(); //("yMMMd");
final formatExpirationDate = DateFormat('yyyy-MM-dd');
final formatCompactDate = DateFormat("MMMd");
final formatMediumDate = DateFormat("EEE MMM d, y hh:mm:ss a");
final formatLongDate = DateFormat("EEEE MMMM d, y hh:mm:ss a");
final formatCurrency = NumberFormat.simpleCurrency();
final formatPercentage = NumberFormat.decimalPercentPattern(decimalDigits: 2);
final formatNumber = NumberFormat("0.####");
final formatCompactNumber = NumberFormat.compact();

class InstrumentWidget extends StatefulWidget {
  const InstrumentWidget(
      this.user,
      //this.account,
      this.instrument,
      {Key? key,
      required this.analytics,
      required this.observer,
      this.heroTag})
      : super(key: key);

  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final RobinhoodUser user;
  //final Account account;
  final Instrument instrument;
  final String? heroTag;

  @override
  State<InstrumentWidget> createState() => _InstrumentWidgetState();
}

class _InstrumentWidgetState extends State<InstrumentWidget> {
  Future<Quote?>? futureQuote;
  Future<Fundamentals?>? futureFundamentals;
  Future<InstrumentHistoricals>? futureHistoricals;
  Future<InstrumentHistoricals>? futureRsiHistoricals;
  Future<List<dynamic>>? futureNews;
  Future<List<dynamic>>? futureLists;
  Future<dynamic>? futureRatings;
  Future<dynamic>? futureRatingsOverview;
  Future<dynamic>? futureEarnings;
  Future<List<dynamic>>? futureSimilar;
  Future<List<dynamic>>? futureSplits;
  Future<List<StockOrder>>? futureInstrumentOrders;
  Future<List<OptionOrder>>? futureOptionOrders;
  Future<List<OptionEvent>>? futureOptionEvents;

  //charts.TimeSeriesChart? chart;
  TimeSeriesChart? chart;
  ChartDateSpan chartDateSpanFilter = ChartDateSpan.day;
  Bounds chartBoundsFilter = Bounds.regular;
  InstrumentHistorical? selection;

  List<String> optionFilters = <String>[];
  List<String> positionFilters = <String>[];
  List<bool> hasQuantityFilters = [true, false];

  final List<String> orderFilters = <String>["confirmed", "filled"];

  double optionOrdersPremiumBalance = 0;
  double positionOrdersBalance = 0;

  Timer? refreshTriggerTime;
  //final dataKey = GlobalKey();

  _InstrumentWidgetState();

  @override
  void initState() {
    super.initState();

    _startRefreshTimer();

    //var fut = RobinhoodService.getOptionOrders(user); // , instrument);
    widget.analytics.setCurrentScreen(
      screenName: 'Instrument/${widget.instrument.symbol}',
    );
  }

  @override
  void dispose() {
    _stopRefreshTimer();
    super.dispose();
  }

/*
  // scopes: [acats, balances, document_upload, edocs, funding:all:read, funding:ach:read, funding:ach:write, funding:wire:read, funding:wire:write, internal, investments, margin, read, signup, trade, watchlist, web_limited])
  Request to https://api.robinhood.com/marketdata/options/?instruments=942d3704-7247-454f-9fb6-1f98f5d41702 failed with status 400: Bad Request.
  */

  @override
  Widget build(BuildContext context) {
    var instrument = widget.instrument;
    var user = widget.user;

    var optionOrderStore =
        Provider.of<OptionOrderStore>(context, listen: false);
    var optionOrders = optionOrderStore.items
        .where((element) => element.chainSymbol == widget.instrument.symbol)
        .toList();
    if (optionOrders.isNotEmpty) {
      futureOptionOrders = Future.value(optionOrders);
    } else if (widget.instrument.tradeableChainId != null) {
      futureOptionOrders ??= RobinhoodService.getOptionOrders(
          widget.user, optionOrderStore, widget.instrument.tradeableChainId!);
    } else {
      futureOptionOrders = Future.value([]);
    }

    var stockPositionOrderStore =
        Provider.of<StockOrderStore>(context, listen: false);
    var positionOrders = stockPositionOrderStore.items
        .where((element) => element.instrumentId == widget.instrument.id)
        .toList();
    if (positionOrders.isNotEmpty) {
      futureInstrumentOrders = Future.value(positionOrders);
    } else {
      futureInstrumentOrders ??= RobinhoodService.getInstrumentOrders(
          widget.user, stockPositionOrderStore, [widget.instrument.url]);
    }

    if (widget.instrument.logoUrl == null &&
        RobinhoodService.logoUrls.containsKey(widget.instrument.symbol)) {
      widget.instrument.logoUrl =
          RobinhoodService.logoUrls[widget.instrument.symbol];
    }

    if (instrument.quoteObj == null) {
      futureQuote ??= RobinhoodService.getQuote(user,
          Provider.of<QuoteStore>(context, listen: false), instrument.symbol);
    } else {
      futureQuote = Future.value(instrument.quoteObj);
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

    futureOptionEvents ??= RobinhoodService.getOptionEventsByInstrumentUrl(
        widget.user, instrument.url);

    futureEarnings ??= RobinhoodService.getEarnings(user, instrument.id);

    futureSimilar ??= RobinhoodService.getSimilar(user, instrument.id);

    futureSplits ??= RobinhoodService.getSplits(user, instrument);

    futureHistoricals ??= RobinhoodService.getInstrumentHistoricals(
        user,
        Provider.of<InstrumentHistoricalsStore>(context, listen: false),
        instrument.symbol,
        chartBoundsFilter: chartBoundsFilter,
        chartDateSpanFilter: chartDateSpanFilter);

    futureRsiHistoricals ??= RobinhoodService.getInstrumentHistoricals(
        user,
        Provider.of<InstrumentHistoricalsStore>(context, listen: false),
        instrument.symbol,
        chartBoundsFilter: Bounds.regular,
        chartDateSpanFilter: ChartDateSpan.month,
        chartInterval: 'day');

    return Scaffold(
        body: FutureBuilder(
      future: Future.wait([
        futureQuote as Future,
        futureFundamentals as Future,
        futureNews as Future,
        futureLists as Future,
        futureRatings as Future,
        futureRatingsOverview as Future,
        futureInstrumentOrders as Future,
        futureOptionOrders as Future,
        futureOptionEvents as Future,
        futureEarnings as Future,
        futureSimilar as Future,
        futureSplits as Future,
        futureRsiHistoricals as Future,
      ]),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          List<dynamic> data = snapshot.data as List<dynamic>;
          instrument.quoteObj = data.isNotEmpty ? data[0] : null;
          instrument.fundamentalsObj = data.length > 1 ? data[1] : null;
          instrument.newsObj = data.length > 2 ? data[2] : null;
          instrument.listsObj = data.length > 3 ? data[3] : null;
          instrument.ratingsObj = data.length > 4 ? data[4] : null;
          instrument.ratingsOverviewObj = data.length > 5 ? data[5] : null;
          instrument.positionOrders = data.length > 6 ? data[6] : null;
          instrument.optionOrders = data.length > 7 ? data[7] : null;
          instrument.optionEvents = data.length > 8 ? data[8] : null;
          instrument.earningsObj = data.length > 9 ? data[9] : null;
          instrument.similarObj = data.length > 10 ? data[10] : null;
          instrument.splitsObj = data.length > 11 ? data[11] : null;

          positionOrdersBalance = instrument.positionOrders != null &&
                  instrument.positionOrders!.isNotEmpty
              ? instrument.positionOrders!
                  .map((e) =>
                      (e.averagePrice != null
                          ? e.averagePrice! * e.quantity!
                          : 0.0) *
                      (e.side == "buy" ? 1 : -1))
                  .reduce((a, b) => a + b)
              : 0.0;

          optionOrdersPremiumBalance = instrument.optionOrders != null &&
                  instrument.optionOrders!.isNotEmpty
              ? instrument.optionOrders!
                  .map((e) =>
                      (e.processedPremium != null ? e.processedPremium! : 0) *
                      (e.direction == "credit" ? 1 : -1))
                  .reduce((a, b) => a + b) as double
              : 0;
        } else if (snapshot.hasError) {
          debugPrint("${snapshot.error}");
          return Center(child: Text("${snapshot.error}"));
        }
        return buildScrollView(instrument,
            done: snapshot.connectionState == ConnectionState.done);
      },
    ));
  }

  void _startRefreshTimer() {
    // Start listening to clipboard
    refreshTriggerTime = Timer.periodic(
      const Duration(milliseconds: 15000),
      (timer) async {
        if (widget.user.refreshEnabled) {
          await RobinhoodService.getInstrumentHistoricals(
              widget.user,
              Provider.of<InstrumentHistoricalsStore>(context, listen: false),
              widget.instrument.symbol,
              chartBoundsFilter: chartBoundsFilter,
              chartDateSpanFilter: chartDateSpanFilter);

          if (!mounted) return;
          await RobinhoodService.refreshQuote(
              widget.user,
              Provider.of<QuoteStore>(context, listen: false),
              widget.instrument.symbol);

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

  buildScrollView(Instrument instrument,
      {List<OptionInstrument>? optionInstruments, bool done = false}) {
    return RefreshIndicator(
        onRefresh: _pullRefresh,
        child: CustomScrollView(slivers: [
          SliverAppBar(
            title: Consumer<QuoteStore>(builder: (context, quoteStore, child) {
              return headerTitle(instrument, quoteStore);
            }),
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

              final settings = context.dependOnInheritedWidgetOfExactType<
                  FlexibleSpaceBarSettings>();
              final deltaExtent = settings!.maxExtent - settings.minExtent;
              final t = (1.0 -
                      (settings.currentExtent - settings.minExtent) /
                          deltaExtent)
                  .clamp(0.0, 1.0);
              final fadeStart =
                  math.max(0.0, 1.0 - kToolbarHeight / deltaExtent);
              const fadeEnd = 1.0;
              final opacity = 1.0 - Interval(fadeStart, fadeEnd).transform(t);
              return FlexibleSpaceBar(
                  //titlePadding:
                  //    const EdgeInsets.only(top: kToolbarHeight * 2, bottom: 15),
                  //background: const FlutterLogo(),
                  background: Hero(
                      tag: widget.heroTag != null
                          ? '${widget.heroTag}'
                          : 'logo_${instrument.symbol}',
                      child: SizedBox(
                          //width: double.infinity,
                          child: instrument.logoUrl != null
                              ? Image.network(
                                  instrument.logoUrl!,
                                  fit: BoxFit.none,
                                  errorBuilder: (BuildContext context,
                                      Object exception,
                                      StackTrace? stackTrace) {
                                    debugPrint(
                                        'Error with ${instrument.symbol} ${instrument.logoUrl}');
                                    //RobinhoodService.removeLogo(instrument.symbol);
                                    return Container(); // Text(instrument.symbol);
                                  },
                                )
                              : Container() //const FlutterLogo()
                          /*Image.network(
                        Constants.flexibleSpaceBarBackground,
                        fit: BoxFit.cover,
                      ),*/
                          )),
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
            }),
            actions: <Widget>[
              IconButton(
                icon: const Icon(Icons.more_vert),
                // icon: const Icon(Icons.settings),
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    //isScrollControlled: true,
                    //useRootNavigator: true,
                    //constraints: const BoxConstraints(maxHeight: 200),
                    builder: (_) => MoreMenuBottomSheet(
                      widget.user,
                      onSettingsChanged: _handleSettingsChanged,
                      analytics: widget.analytics,
                      observer: widget.observer,
                    ),
                  );
                },
              ),
              /*
        IconButton(
          icon: ru != null && ru.userName != null
              ? const Icon(Icons.logout)
              : const Icon(Icons.login),
          tooltip: ru != null && ru.userName != null ? 'Logout' : 'Login',
          onPressed: () {
            if (ru != null && ru.userName != null) {
              var alert = AlertDialog(
                title: const Text('Logout process'),
                content: SingleChildScrollView(
                  child: ListBody(
                    children: <Widget>[
                      const Text(
                          'This action will require you to log in again.'),
                      const Text('Are you sure you want to log out?'),
                    ],
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    child: const Text('Cancel'),
                    onPressed: () {
                      Navigator.pop(context, 'dialog');
                    },
                  ),
                  TextButton(
                    child: const Text('OK'),
                    onPressed: () {
                      _logout();
                      Navigator.pop(context, 'dialog');
                    },
                  ),
                ],
              );
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return alert;
                },
              );
            } else {
              _openLogin();
            }
            /* ... */
          },
        ),*/
            ],
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
          SliverToBoxAdapter(
              child: Align(
                  alignment: Alignment.center,
                  child: buildOverview(instrument))),
          Consumer<InstrumentHistoricalsStore>(builder: //, QuoteStore
              (context, instrumentHistoricalsStore, child) {
            //, quoteStore
            instrument.instrumentHistoricalsObj =
                instrumentHistoricalsStore.items.firstWhereOrNull((element) =>
                        element.symbol == instrument.symbol &&
                        element.span ==
                            RobinhoodService.convertChartSpanFilter(
                                chartDateSpanFilter) &&
                        element.bounds ==
                            RobinhoodService.convertChartBoundsFilter(
                                chartBoundsFilter)
                    //&& element.interval == element.interval
                    );

            var rsi = instrumentHistoricalsStore.items.firstWhereOrNull(
                (element) =>
                    element.symbol == instrument.symbol &&
                    element.span ==
                        RobinhoodService.convertChartSpanFilter(
                            ChartDateSpan.month) &&
                    element.bounds ==
                        RobinhoodService.convertChartBoundsFilter(
                            chartBoundsFilter) &&
                    element.interval == 'day');
            if (rsi != null) {
              debugPrint(rsi.historicals.first.closePrice!.toString());
            }

            if (instrument.instrumentHistoricalsObj != null &&
                instrument.instrumentHistoricalsObj!.historicals.isNotEmpty) {
              InstrumentHistorical? firstHistorical;
              InstrumentHistorical? lastHistorical;
              double open = 0;
              double close = 0;
              double changeInPeriod = 0;
              double changePercentInPeriod = 0;

              firstHistorical =
                  instrument.instrumentHistoricalsObj!.historicals[0];
              lastHistorical = instrument.instrumentHistoricalsObj!.historicals[
                  instrument.instrumentHistoricalsObj!.historicals.length - 1];
              open = instrument.instrumentHistoricalsObj!.previousClosePrice ??
                  firstHistorical.openPrice!;
              close = lastHistorical.closePrice!;
              changeInPeriod = close - open;
              changePercentInPeriod = changeInPeriod / close;

              var brightness = MediaQuery.of(context).platformBrightness;
              var textColor = Theme.of(context).colorScheme.background;
              if (brightness == Brightness.dark) {
                textColor = Colors.grey.shade200;
              } else {
                textColor = Colors.grey.shade800;
              }
              /* TODO: review
              var quoteObj = quoteStore.items.firstWhereOrNull(
                  (element) => element.symbol == instrument.symbol);
              if (instrument
                      .instrumentHistoricalsObj!.historicals.last.beginsAt !=
                  quoteObj!.updatedAt) {
                instrument.instrumentHistoricalsObj!.historicals
                    .add(InstrumentHistorical(
                        //DateTime.now(),
                        quoteObj.updatedAt,
                        quoteObj.lastTradePrice,
                        quoteObj.lastTradePrice,
                        quoteObj.lastTradePrice,
                        quoteObj.lastTradePrice,
                        0,
                        '',
                        false));
              }
              */
              List<charts.Series<dynamic, DateTime>> seriesList = [
                charts.Series<InstrumentHistorical, DateTime>(
                  id: 'Open',
                  colorFn: (_, __) => charts.ColorUtil.fromDartColor(
                      Theme.of(context).colorScheme.primary),
                  //colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
                  domainFn: (InstrumentHistorical history, _) =>
                      history.beginsAt!,
                  measureFn: (InstrumentHistorical history, _) =>
                      history.openPrice,
                  data: instrument.instrumentHistoricalsObj!.historicals,
                ),
                charts.Series<InstrumentHistorical, DateTime>(
                  id: 'Close',
                  colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
                  domainFn: (InstrumentHistorical history, _) =>
                      history.beginsAt!,
                  measureFn: (InstrumentHistorical history, _) =>
                      history.closePrice,
                  data: instrument.instrumentHistoricalsObj!.historicals,
                ),
                charts.Series<InstrumentHistorical, DateTime>(
                    id: 'Volume',
                    colorFn: (_, __) =>
                        charts.MaterialPalette.cyan.shadeDefault,
                    domainFn: (InstrumentHistorical history, _) =>
                        history.beginsAt!,
                    measureFn: (InstrumentHistorical history, _) =>
                        history.volume,
                    data: instrument.instrumentHistoricalsObj!.historicals),
                charts.Series<InstrumentHistorical, DateTime>(
                  id: 'Low',
                  colorFn: (_, __) => charts.MaterialPalette.red.shadeDefault,
                  domainFn: (InstrumentHistorical history, _) =>
                      history.beginsAt!,
                  measureFn: (InstrumentHistorical history, _) =>
                      history.lowPrice,
                  data: instrument.instrumentHistoricalsObj!.historicals,
                ),
                charts.Series<InstrumentHistorical, DateTime>(
                  id: 'High',
                  colorFn: (_, __) => charts.MaterialPalette.green.shadeDefault,
                  domainFn: (InstrumentHistorical history, _) =>
                      history.beginsAt!,
                  measureFn: (InstrumentHistorical history, _) =>
                      history.highPrice,
                  data: instrument.instrumentHistoricalsObj!.historicals,
                ),
              ];
              chart = TimeSeriesChart(seriesList,
                  open: open,
                  close: close,
                  hiddenSeries: const ["Close", "Volume", "Low", "High"],
                  onSelected: _onChartSelection);

              /*
              slivers.add(const SliverToBoxAdapter(
                  child: SizedBox(
                height: 25.0,
              )));
*/
              return SliverToBoxAdapter(
                  child: Column(
                children: [
                  Consumer<InstrumentHistoricalsSelectionStore>(
                      builder: (context, value, child) {
                    selection = value.selection;
                    if (selection != null) {
                      changeInPeriod = selection!.closePrice! - open;
                      changePercentInPeriod =
                          changeInPeriod / selection!.closePrice!;
                    } else {
                      changeInPeriod = close - open;
                      changePercentInPeriod = changeInPeriod / close;
                    }
                    return SizedBox(
                        height: 43,
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
                                    TextStyle(fontSize: 10, color: textColor),),
                          ],
                        )));
                  }),
                  SizedBox(
                      height: 240,
                      child: Padding(
                        //padding: EdgeInsets.symmetric(horizontal: 12.0),
                        padding: const EdgeInsets.all(10.0),
                        child: chart,
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
                                label: const Text('Trading Hours'),
                                selected: chartBoundsFilter == Bounds.trading,
                                onSelected: (bool value) {
                                  if (value) {
                                    resetChart(
                                        chartDateSpanFilter, Bounds.trading);
                                  }
                                },
                              ),
                            ),
                          ]);
                        },
                        itemCount: 1,
                      ))
                ],
              ));

              //child: StackedAreaLineChart.withSampleData()))));
            }
            return SliverToBoxAdapter(child: Container());
          }),
          Consumer<StockPositionStore>(
              builder: (context, stockPositionStore, child) {
            var position = stockPositionStore.items
                .firstWhereOrNull((e) => e.instrument == instrument.url);
            if (position == null) {
              return SliverToBoxAdapter(child: Container());
            }
            return SliverToBoxAdapter(
                child: Card(
                    child: Column(mainAxisSize: MainAxisSize.min, children: <
                        Widget>[
              const ListTile(
                  title:
                      Text("Stock Position", style: TextStyle(fontSize: 20))),
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
                    Text(formatCurrency.format(position.gainLoss), //.abs()
                        style: const TextStyle(fontSize: 18)),
                  ])

                  /*
          trailing: Text(formatCurrency.format(position!.gainLoss),
              style: const TextStyle(fontSize: 18)),
              */
                  ),
              ListTile(
                title: const Text("Return %"),
                trailing: Text(
                    formatPercentage.format(position.gainLossPercent),
                    style: const TextStyle(fontSize: 18)),
              ),
              ListTile(
                  title: const Text("Return Today"),
                  trailing: Wrap(children: [
                    position.trendingIconToday,
                    Container(
                      width: 2,
                    ),
                    Text(formatCurrency.format(position.gainLossToday), //.abs()
                        style: const TextStyle(fontSize: 18)),
                  ])

                  /*
          trailing: Text(formatCurrency.format(position!.gainLoss),
              style: const TextStyle(fontSize: 18)),
              */
                  ),
              ListTile(
                title: const Text("Return Today %"),
                trailing: Text(
                    formatPercentage.format(position.gainLossPercentToday),
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
            ])));
          }),
          Consumer<OptionPositionStore>(
              builder: (context, optionPositionStore, child) {
            var optionPositions = optionPositionStore.items
                .where((e) => e.symbol == widget.instrument.symbol)
                .toList();
            optionPositions.sort((a, b) {
              int comp = a.legs.first.expirationDate!
                  .compareTo(b.legs.first.expirationDate!);
              if (comp != 0) return comp;
              return a.legs.first.strikePrice!
                  .compareTo(b.legs.first.strikePrice!);
            });

            var filteredOptionPositions = optionPositions
                .where((e) =>
                    (hasQuantityFilters[0] && hasQuantityFilters[1]) ||
                    (!hasQuantityFilters[0] || e.quantity! > 0) &&
                        (!hasQuantityFilters[1] || e.quantity! <= 0))
                .toList();
            filteredOptionPositions.sort((a, b) {
              int comp = a.legs.first.expirationDate!
                  .compareTo(b.legs.first.expirationDate!);
              if (comp != 0) return comp;
              return a.legs.first.strikePrice!
                  .compareTo(b.legs.first.strikePrice!);
            });

            return SliverToBoxAdapter(
                child: ShrinkWrappingViewport(
                    offset: ViewportOffset.zero(),
                    slivers: [
                  if (filteredOptionPositions.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                        child: SizedBox(
                      height: 25.0,
                    )),
                    OptionPositionsRowWidget(
                      widget.user, //widget.account,
                      filteredOptionPositions,
                      analytics: widget.analytics,
                      observer: widget.observer,
                    )
                  ]
                ]));
          }),
          if (instrument.quoteObj != null) ...[
            const SliverToBoxAdapter(
                child: SizedBox(
              height: 25.0,
            )),
            quoteWidget(instrument)
          ],
          if (instrument.fundamentalsObj != null) ...[
            const SliverToBoxAdapter(
                child: SizedBox(
              height: 25.0,
            )),
            fundamentalsWidget(instrument)
          ],
          if (instrument.ratingsObj != null &&
              instrument.ratingsObj["summary"] != null) ...[
            const SliverToBoxAdapter(
                child: SizedBox(
              height: 25.0,
            )),
            _buildRatingsWidget(instrument)
          ],
          if (instrument.ratingsOverviewObj != null) ...[
            const SliverToBoxAdapter(
                child: SizedBox(
              height: 25.0,
            )),
            _buildRatingsOverviewWidget(instrument)
          ],
          if (instrument.earningsObj != null) ...[
            const SliverToBoxAdapter(
                child: SizedBox(
              height: 25.0,
            )),
            _buildEarningsWidget(instrument)
          ],
          if (instrument.splitsObj != null &&
              instrument.splitsObj!.isNotEmpty) ...[
            const SliverToBoxAdapter(
                child: SizedBox(
              height: 25.0,
            )),
            _buildSplitsWidget(instrument)
          ],
          if (instrument.newsObj != null) ...[
            const SliverToBoxAdapter(
                child: SizedBox(
              height: 25.0,
            )),
            _buildNewsWidget(instrument)
          ],
          if (instrument.similarObj != null) ...[
            const SliverToBoxAdapter(
                child: SizedBox(
              height: 25.0,
            )),
            _buildSimilarWidget(instrument)
          ],
          if (instrument.listsObj != null) ...[
            const SliverToBoxAdapter(
                child: SizedBox(
              height: 25.0,
            )),
            _buildListsWidget(instrument)
          ],
          Consumer<StockOrderStore>(builder: (context, stockOrderStore, child) {
            //var positionOrders = stockOrderStore.items.where(
            //    (element) => element.instrumentId == widget.instrument.id);

            if (instrument.positionOrders != null) {
              return SliverToBoxAdapter(
                  child: ShrinkWrappingViewport(
                      offset: ViewportOffset.zero(),
                      slivers: [
                    const SliverToBoxAdapter(
                        child: SizedBox(
                      height: 25.0,
                    )),
                    positionOrdersWidget(instrument.positionOrders!)
                  ]));
            }
            return SliverToBoxAdapter(child: Container());
          }),
          Consumer<OptionOrderStore>(
              builder: (context, optionOrderStore, child) {
            //var optionOrders = optionOrderStore.items.where(
            //    (element) => element.chainSymbol == widget.instrument.symbol);
            if (instrument.optionOrders != null) {
              return SliverToBoxAdapter(
                  child: ShrinkWrappingViewport(
                      offset: ViewportOffset.zero(),
                      slivers: [
                    const SliverToBoxAdapter(
                        child: SizedBox(
                      height: 25.0,
                    )),
                    OptionOrdersWidget(
                      widget.user,
                      //widget.account,
                      instrument.optionOrders!,
                      const ["confirmed", "filled"],
                      analytics: widget.analytics,
                      observer: widget.observer,
                    )
                  ]));
            }
            return SliverToBoxAdapter(child: Container());
          }),
          const SliverToBoxAdapter(
              child: SizedBox(
            height: 25.0,
          )),
          const SliverToBoxAdapter(child: DisclaimerWidget())
        ]));
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
    var provider = Provider.of<InstrumentHistoricalsSelectionStore>(context,
        listen: false);
    provider.selectionChanged(historical);
    /*
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
    */
  }

  void _handleSettingsChanged(dynamic settings) {
    setState(() {
      hasQuantityFilters = settings['hasQuantityFilters'];
      optionFilters = settings['optionFilters'];
      positionFilters = settings['positionFilters'];
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
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            const SizedBox(width: 8),
            if (instrument.tradeableChainId != null) ...[
              TextButton(
                child: const Text('OPTION CHAIN'),
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => InstrumentOptionChainWidget(
                                widget.user,
                                //widget.account,
                                instrument,
                                analytics: widget.analytics,
                                observer: widget.observer,
                              )));
                },
              ),
            ],
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

  Widget quoteWidget(Instrument instrument) {
    return SliverToBoxAdapter(
        child: ShrinkWrappingViewport(offset: ViewportOffset.zero(), slivers: [
      const SliverToBoxAdapter(
          child: Column(children: [
        ListTile(
          title: Text(
            "Quote",
            style: TextStyle(fontSize: 19.0),
          ),
        )
      ])),
      SliverToBoxAdapter(
          child: Card(
              child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
        ListTile(
            title: const Text("Last Trade Price"),
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
                formatCurrency.format(instrument.quoteObj!.lastTradePrice),
                style: const TextStyle(fontSize: 18.0),
                textAlign: TextAlign.right,
              ),
            ])),
        ListTile(
          title: const Text("Adjusted Previous Close"),
          trailing: Text(
              formatCurrency.format(instrument.quoteObj!.adjustedPreviousClose),
              style: const TextStyle(fontSize: 18)),
        ),
        ListTile(
          title: const Text("Change Today"),
          trailing: Text(
              formatCurrency.format(instrument.quoteObj!.changeToday),
              style: const TextStyle(fontSize: 18)),
        ),
        ListTile(
          title: const Text("Change Today %"),
          trailing: Text(
              formatPercentage.format(instrument.quoteObj!.changePercentToday),
              style: const TextStyle(fontSize: 18)),
        ),
        ListTile(
          title: const Text("Bid - Ask Price"),
          trailing: Text(
              "${formatCurrency.format(instrument.quoteObj!.bidPrice)} - ${formatCurrency.format(instrument.quoteObj!.askPrice)}",
              style: const TextStyle(fontSize: 18)),
        ),
        ListTile(
          title: const Text("Bid - Ask Size"),
          trailing: Text(
              "${formatCompactNumber.format(instrument.quoteObj!.bidSize)} - ${formatCompactNumber.format(instrument.quoteObj!.askSize)}",
              style: const TextStyle(fontSize: 18)),
        ),
        ListTile(
          title: const Text("Last Extended Hours Trade Price"),
          trailing: Text(
              instrument.quoteObj!.lastExtendedHoursTradePrice != null
                  ? formatCurrency
                      .format(instrument.quoteObj!.lastExtendedHoursTradePrice)
                  : "",
              style: const TextStyle(fontSize: 18)),
        ),
        Container(
          height: 25,
        )
      ])))
    ]));
  }

  Widget fundamentalsWidget(Instrument instrument) {
    return SliverToBoxAdapter(
        child: ShrinkWrappingViewport(offset: ViewportOffset.zero(), slivers: [
      const SliverToBoxAdapter(
          child: Column(children: [
        ListTile(
          title: Text(
            "Fundamentals",
            style: TextStyle(fontSize: 19.0),
          ),
        )
      ])),
      SliverToBoxAdapter(
          child: Card(
              child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
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
          subtitle: Text(instrument.name, style: const TextStyle(fontSize: 16)),
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
      ])))
    ]));
  }

  Widget _buildRatingsWidget(Instrument instrument) {
    return SliverToBoxAdapter(
        child: ShrinkWrappingViewport(offset: ViewportOffset.zero(), slivers: [
      const SliverToBoxAdapter(
          child: Column(children: [
        ListTile(
          title: Text(
            "Ratings",
            style: TextStyle(fontSize: 19.0),
          ),
        )
      ])),
      SliverPadding(
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
                    return Container();
                }
              },
              childCount: 3,
            ),
          ))
    ]));
  }

  Widget _buildRatingsOverviewWidget(Instrument instrument) {
    if (instrument.ratingsOverviewObj == null) {
      return Container();
    }
    return SliverToBoxAdapter(
        child: ShrinkWrappingViewport(offset: ViewportOffset.zero(), slivers: [
      const SliverToBoxAdapter(
          child: Column(children: [
        ListTile(
          title: Text(
            "Research",
            style: TextStyle(fontSize: 19.0),
          ),
        )
      ])),
      SliverToBoxAdapter(
          child: Card(
              child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
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
              var url = instrument.ratingsOverviewObj!["download_url"];
              await canLaunchUrl(url)
                  ? await launchUrl(url)
                  : throw 'Could not launch $url';
            },
          ),
        ])
      ])))
    ]));
  }

  Widget _buildEarningsWidget(Instrument instrument) {
    dynamic futureEarning;
    dynamic pastEarning;
    if (instrument.earningsObj!.isNotEmpty) {
      futureEarning =
          instrument.earningsObj![instrument.earningsObj!.length - 1];
      pastEarning = instrument.earningsObj![instrument.earningsObj!.length - 2];
    }

    return SliverToBoxAdapter(
        child: ShrinkWrappingViewport(offset: ViewportOffset.zero(), slivers: [
      const SliverToBoxAdapter(
          child: Column(children: [
        ListTile(
          title: Text(
            "Earnings",
            style: TextStyle(fontSize: 19.0),
          ),
        )
      ])),
      SliverToBoxAdapter(
          child: Card(
              child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
        for (var earning in instrument.earningsObj!) ...[
          ListTile(
              title: Text(
                "${earning!["year"]} Q${earning!["quarter"]}",
                style: const TextStyle(fontSize: 18.0),
                //overflow: TextOverflow.visible
              ),
              subtitle: Text(
                  earning!["report"] != null
                      ? "Report${earning!["report"]["verified"] ? "ed" : "ing"} ${formatDate.format(DateTime.parse(earning!["report"]["date"]))} ${earning!["report"]["timing"]}"
                      : "",
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
                                formatCurrency.format(
                                    double.parse(earning!["eps"]["estimate"])),
                                style: const TextStyle(fontSize: 18)),
                          ],
                        )
                      ],
                      if (earning!["eps"]["actual"] != null) ...[
                        Column(children: [
                          const Text("Actual", style: TextStyle(fontSize: 11)),
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
                    var url = earning!["call"]["replay_url"];
                    await canLaunchUrl(url)
                        ? await launchUrl(url)
                        : throw 'Could not launch $url';
                  },
                ),
              ],
              if (earning!["call"]["broadcast_url"] != null) ...[
                Container(width: 50),
                TextButton(
                  child: const Text('LISTEN TO BROADCAST'),
                  onPressed: () async {
                    var url = earning!["call"]["broadcast_url"];
                    await canLaunchUrl(url)
                        ? await launchUrl(url)
                        : throw 'Could not launch $url';
                  },
                ),
              ],
            ])
          ],
        ],
      ])))
    ]));
  }

  Widget _buildSplitsWidget(Instrument instrument) {
    return SliverToBoxAdapter(
        child: ShrinkWrappingViewport(offset: ViewportOffset.zero(), slivers: const [
      SliverToBoxAdapter(
          child: Column(children: [
        ListTile(
          title: Text(
            "Splits",
            style: TextStyle(fontSize: 19.0),
          ),
        )
      ])),
      SliverToBoxAdapter(
          child: Card(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
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
          ])))
    ]));
  }

  Widget _buildSimilarWidget(Instrument instrument) {
    return SliverToBoxAdapter(
        child: ShrinkWrappingViewport(offset: ViewportOffset.zero(), slivers: [
      const SliverToBoxAdapter(
          child: Column(children: [
        ListTile(
          title: Text(
            "Similar",
            style: TextStyle(fontSize: 19.0),
          ),
        )
      ])),
      SliverList(
        // delegate: SliverChildListDelegate(widgets),
        delegate: SliverChildBuilderDelegate((BuildContext context, int index) {
          return Card(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: Hero(
                    tag: 'logo_${instrument.similarObj![index]["symbol"]}',
                    child: instrument.similarObj![index]["logo_url"] != null
                        ? CircleAvatar(
                            radius: 25,
                            foregroundColor: Theme.of(context)
                                .colorScheme
                                .primary, //.onBackground,
                            //backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            child: Image.network(
                              instrument.similarObj![index]["logo_url"]
                                  .toString()
                                  .replaceAll("https:////", "https://"),
                              width: 40,
                              height: 40,
                              errorBuilder: (BuildContext context,
                                  Object exception, StackTrace? stackTrace) {
                                //RobinhoodService.removeLogo(instrument.similarObj![index]["symbol"]);
                                return Text(
                                    instrument.similarObj![index]["symbol"]);
                              },
                            ))
                        : CircleAvatar(
                            radius: 25,
                            foregroundColor:
                                Theme.of(context).colorScheme.primary,
                            child: Text(
                              instrument.similarObj![index]["symbol"],
                            ))),
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
                      await RobinhoodService.getInstrumentsByIds(
                          widget.user,
                          Provider.of<InstrumentStore>(context, listen: false),
                          [instrument.similarObj![index]["instrument_id"]]);
                  similarInstruments[0].logoUrl = instrument.similarObj![index]
                          ["logo_url"]
                      .toString()
                      .replaceAll("https:////", "https://");
                  if (!mounted) return;
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => InstrumentWidget(
                                widget.user,
                                //widget.account,
                                similarInstruments[0],
                                analytics: widget.analytics,
                                observer: widget.observer,
                              )));
                },
              ),
            ],
          ));

          //if (positionOrders.length > index) {
          //}
        }, childCount: instrument.similarObj!.length),
      )
    ]));
  }

  Widget _buildListsWidget(Instrument instrument) {
    return SliverToBoxAdapter(
        child: ShrinkWrappingViewport(offset: ViewportOffset.zero(), slivers: [
      const SliverToBoxAdapter(
          child: Column(children: [
        ListTile(
          title: Text(
            "Lists",
            style: TextStyle(fontSize: 19.0),
          ),
        )
      ])),
      SliverList(
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
                                //widget.account,
                                instrument.listsObj![index]["id"].toString(),
                                analytics: widget.analytics,
                                observer: widget.observer,
                              )));
                },
              ),
            ],
          ));

          //if (positionOrders.length > index) {
          //}
        }, childCount: instrument.listsObj!.length),
      )
    ]));
  }

  Widget _buildNewsWidget(Instrument instrument) {
    return SliverToBoxAdapter(
        child: ShrinkWrappingViewport(offset: ViewportOffset.zero(), slivers: [
      const SliverToBoxAdapter(
          child: Column(children: [
        ListTile(
          title: Text(
            "News",
            style: TextStyle(fontSize: 19.0),
          ),
        )
      ])),
      SliverList(
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
                  var url = instrument.newsObj![index]["url"];
                  await canLaunchUrl(url)
                      ? await launchUrl(url)
                      : throw 'Could not launch $url';
                },
              ),
            ],
          ));

          //if (positionOrders.length > index) {
          //}
        }, childCount: instrument.newsObj!.length),
      )
    ]));
  }

  Widget positionOrdersWidget(List<StockOrder> positionOrders) {
    return SliverToBoxAdapter(
        child: ShrinkWrappingViewport(offset: ViewportOffset.zero(), slivers: [
      SliverToBoxAdapter(
          child: Column(children: [
        ListTile(
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
                            tileColor: Theme.of(context).colorScheme.primary,
                            leading: const Icon(Icons.filter_list),
                            title: const Text(
                              "Filter Position Orders",
                              style: TextStyle(fontSize: 19.0),
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
      ])),
      SliverList(
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
      )
    ]));
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

  Widget headerTitle(Instrument instrument, QuoteStore store) {
    var quoteObj = store.items
        .firstWhereOrNull((element) => element.symbol == instrument.symbol);
    return Align(alignment: Alignment.centerLeft, child: 
      Wrap(
        crossAxisAlignment: WrapCrossAlignment.end,
        //runAlignment: WrapAlignment.end,
        //alignment: WrapAlignment.end,
        spacing: 20,
        //runSpacing: 5,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            //runAlignment: WrapAlignment.end,
            //alignment: WrapAlignment.end,
            spacing: 10,
            //runSpacing: 5,
            children: [
              Text(
                instrument.symbol, // ${optionPosition.strategy.split('_').first}
                //style: const TextStyle(fontSize: 20.0)
                style: const TextStyle(fontSize: 17.0)
              ),
              Text(
                instrument.simpleName ?? instrument.name, // ${optionPosition.strategy.split('_').first}
                //style: const TextStyle(fontSize: 20.0)
                style: const TextStyle(fontSize: 17.0)
              ),
          ]),
         if (quoteObj != null) ...[
            Wrap(spacing: 10, children: [
              Text(formatCurrency.format(quoteObj.lastTradePrice),
                  //style: const TextStyle(fontSize: 15.0)
                  style:
                      const TextStyle(fontSize: 16.0, color: Colors.white70)),
              Wrap(children: [
                Icon(
                    quoteObj.changeToday > 0
                        ? Icons.trending_up
                        : (quoteObj.changeToday < 0
                            ? Icons.trending_down
                            : Icons.trending_flat),
                    color: (quoteObj.changeToday > 0
                        ? Colors.lightGreenAccent
                        : (quoteObj.changeToday < 0
                            ? Colors.red
                            : Colors.grey)),
                    size: 20.0),
                Container(
                  width: 2,
                ),
                Text(formatPercentage.format(quoteObj.changePercentToday),
                    //style: const TextStyle(fontSize: 15.0)
                    style:
                        const TextStyle(fontSize: 16.0, color: Colors.white70)),
              ]),
              Text(
                  "${quoteObj.changeToday > 0 ? "+" : quoteObj.changeToday < 0 ? "-" : ""}${formatCurrency.format(quoteObj.changeToday.abs())}",
                  //style: const TextStyle(fontSize: 12.0),
                  style: const TextStyle(fontSize: 16.0, color: Colors.white70),
                  textAlign: TextAlign.right)
            ])
          ],
        ]),);
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
