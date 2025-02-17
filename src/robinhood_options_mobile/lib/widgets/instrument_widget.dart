import 'dart:async';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/extensions.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/model/chart_selection_store.dart';
import 'package:robinhood_options_mobile/model/dividend_store.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals_selection_store.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals_store.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/option_event.dart';
import 'package:robinhood_options_mobile/model/option_order_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';
import 'package:robinhood_options_mobile/model/instrument_order_store.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/ad_banner_widget.dart';
import 'package:robinhood_options_mobile/widgets/chart_time_series_widget.dart';
import 'package:robinhood_options_mobile/widgets/disclaimer_widget.dart';
import 'package:robinhood_options_mobile/widgets/income_transactions_widget.dart';
import 'package:robinhood_options_mobile/widgets/instrument_option_chain_widget.dart';
import 'package:robinhood_options_mobile/widgets/list_widget.dart';
import 'package:robinhood_options_mobile/widgets/option_orders_widget.dart';
import 'package:robinhood_options_mobile/widgets/option_positions_widget.dart';
import 'package:robinhood_options_mobile/widgets/sliverappbar_widget.dart';
import 'package:robinhood_options_mobile/widgets/trade_instrument_widget.dart';
import 'package:url_launcher/url_launcher.dart';
//import 'package:charts_flutter/flutter.dart' as charts;
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;

import 'package:robinhood_options_mobile/model/fundamentals.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_historical.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/option_order.dart';
import 'package:robinhood_options_mobile/model/instrument_order.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';

class InstrumentWidget extends StatefulWidget {
  const InstrumentWidget(
      this.user,
      this.service,
      //this.account,
      this.instrument,
      {super.key,
      required this.analytics,
      required this.observer,
      this.heroTag});

  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser user;
  final IBrokerageService service;
  //final Account account;
  final Instrument instrument;
  final String? heroTag;

  @override
  State<InstrumentWidget> createState() => _InstrumentWidgetState();
}

class _InstrumentWidgetState extends State<InstrumentWidget> {
  final FirestoreService _firestoreService = FirestoreService();

  Future<Quote?>? futureQuote;
  Future<Fundamentals?>? futureFundamentals;
  Future<InstrumentHistoricals>? futureHistoricals;
  Future<InstrumentHistoricals>? futureRsiHistoricals;
  Future<List<dynamic>>? futureNews;
  Future<List<dynamic>>? futureLists;
  Future<List<dynamic>>? futureDividends;
  Future<dynamic>? futureRatings;
  Future<dynamic>? futureRatingsOverview;
  Future<dynamic>? futureEarnings;
  Future<List<dynamic>>? futureSimilar;
  Future<List<dynamic>>? futureSplits;
  Future<List<InstrumentOrder>>? futureInstrumentOrders;
  Future<List<OptionOrder>>? futureOptionOrders;
  Future<List<OptionEvent>>? futureOptionEvents;
  Future<dynamic>? futureEtp;

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

    widget.analytics.logScreenView(
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
      futureOptionOrders ??= widget.service.getOptionOrders(
          widget.user, optionOrderStore, widget.instrument.tradeableChainId!);
    } else {
      futureOptionOrders = Future.value([]);
    }

    var stockPositionOrderStore =
        Provider.of<InstrumentOrderStore>(context, listen: false);
    var positionOrders = stockPositionOrderStore.items
        .where((element) => element.instrumentId == widget.instrument.id)
        .toList();
    if (positionOrders.isNotEmpty) {
      futureInstrumentOrders = Future.value(positionOrders);
    } else {
      futureInstrumentOrders ??= widget.service.getInstrumentOrders(
          widget.user, stockPositionOrderStore, [widget.instrument.url]);
    }

    if (widget.instrument.logoUrl == null &&
        RobinhoodService.logoUrls.containsKey(widget.instrument.symbol)) {
      widget.instrument.logoUrl =
          RobinhoodService.logoUrls[widget.instrument.symbol];
      _firestoreService.upsertInstrument(widget.instrument);
    }

    if (instrument.quoteObj == null) {
      futureQuote ??= widget.service.getQuote(user,
          Provider.of<QuoteStore>(context, listen: false), instrument.symbol);
    } else {
      futureQuote = Future.value(instrument.quoteObj);
    }

    if (instrument.fundamentalsObj == null) {
      futureFundamentals ??= widget.service.getFundamentals(user, instrument);
    } else {
      futureFundamentals ??= Future.value(instrument.fundamentalsObj);
    }

    futureNews ??= widget.service.getNews(user, instrument.symbol);

    futureLists ??= widget.service.getLists(user, instrument.id);

    futureDividends ??= widget.service.getDividends(
        user,
        Provider.of<DividendStore>(context, listen: false),
        Provider.of<InstrumentStore>(context, listen: false),
        instrumentId: instrument.id);

    futureRatings ??= widget.service.getRatings(user, instrument.id);
    futureRatingsOverview ??=
        widget.service.getRatingsOverview(user, instrument.id);

    futureOptionEvents ??= widget.service
        .getOptionEventsByInstrumentUrl(widget.user, instrument.url);

    futureEarnings ??= widget.service.getEarnings(user, instrument.id);

    futureSimilar ??= widget.service.getSimilar(user, instrument.id);

    futureSplits ??= widget.service.getSplits(user, instrument);

    futureHistoricals ??= widget.service.getInstrumentHistoricals(
        user,
        Provider.of<InstrumentHistoricalsStore>(context, listen: false),
        instrument.symbol,
        chartBoundsFilter: chartBoundsFilter,
        chartDateSpanFilter: chartDateSpanFilter);

    futureRsiHistoricals ??= widget.service.getInstrumentHistoricals(
        user,
        Provider.of<InstrumentHistoricalsStore>(context, listen: false),
        instrument.symbol,
        chartBoundsFilter: Bounds.regular,
        chartDateSpanFilter: ChartDateSpan.month,
        chartInterval: 'day');

    if (instrument.type == 'etp' && widget.service is RobinhoodService) {
      futureEtp ??=
          (widget.service as RobinhoodService).getEtpDetails(user, instrument);
    }

    return Scaffold(
        body: FutureBuilder(
      future: Future.wait([
        futureQuote as Future,
        futureFundamentals as Future,
        futureNews as Future,
        futureLists as Future,
        futureDividends as Future,
        futureRatings as Future,
        futureRatingsOverview as Future,
        futureInstrumentOrders as Future,
        futureOptionOrders as Future,
        futureOptionEvents as Future,
        futureEarnings as Future,
        futureSimilar as Future,
        futureSplits as Future,
        futureRsiHistoricals as Future,
        if (futureEtp != null) ...[futureEtp as Future]
      ]),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          bool updateInstrument = false;
          List<dynamic> data = snapshot.data as List<dynamic>;
          if (instrument.quoteObj != null) {
            Quote? newQuote = data.isNotEmpty ? data[0] : null;
            if (instrument.quoteObj!.updatedAt!
                .isBefore(newQuote!.updatedAt!)) {
              instrument.quoteObj = newQuote;
              updateInstrument = true;
            }
          } else {
            instrument.quoteObj = data.isNotEmpty ? data[0] : null;
          }
          instrument.fundamentalsObj = data.length > 1 ? data[1] : null;
          instrument.newsObj = data.length > 2 ? data[2] : null;
          instrument.listsObj = data.length > 3 ? data[3] : null;
          instrument.dividendsObj = data.length > 4 ? data[4] : null;
          instrument.ratingsObj = data.length > 5 ? data[5] : null;
          instrument.ratingsOverviewObj = data.length > 6 ? data[6] : null;
          instrument.positionOrders = data.length > 7 ? data[7] : null;
          instrument.optionOrders = data.length > 8 ? data[8] : null;
          instrument.optionEvents = data.length > 9 ? data[9] : null;
          instrument.earningsObj = data.length > 10 ? data[10] : null;
          instrument.similarObj = data.length > 11 ? data[11] : null;
          instrument.splitsObj = data.length > 12 ? data[12] : null;
          instrument.instrumentHistoricalsObj =
              data.length > 12 ? data[13] : null;
          // Conditionally persist to Firestore if the data has changed.
          if (instrument.etpDetails != null) {
            //// TODO: Figure out why the first 2 solutions don't work
            //// instead going to compare date properties.
            // if (DeepCollectionEquality.unordered().equals(instrument.etpDetails, data[14])) {
            // if (jsonMapEquals(instrument.etpDetails, data[14])) {
            //// Doesn't work because json ordering is different between Firebase and Robinhood API
            // if (jsonEncode(instrument.etpDetails) != jsonEncode(data[14])) {
            if (instrument.etpDetails['quarter_end_date'] !=
                    data[14]['quarter_end_date'] ||
                instrument.etpDetails['month_end_date'] !=
                    data[14]['month_end_date'] ||
                instrument.etpDetails['sectors_portfolio_date'] !=
                    data[14]['sectors_portfolio_date'] ||
                instrument.etpDetails['holdings_portfolio_date'] !=
                    data[14]['holdings_portfolio_date']) {
              updateInstrument = true;
            }
          } else {
            updateInstrument = true;
          }
          instrument.etpDetails = data.length > 14 ? data[14] : null;
          if (updateInstrument) {
            _firestoreService.upsertInstrument(instrument);
            debugPrint(
                'InstrumentWidget: Stored instrument into Firestore ${instrument.symbol}');
          }
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
          await widget.service.getInstrumentHistoricals(
              widget.user,
              Provider.of<InstrumentHistoricalsStore>(context, listen: false),
              widget.instrument.symbol,
              chartBoundsFilter: chartBoundsFilter,
              chartDateSpanFilter: chartDateSpanFilter);

          if (!mounted) return;
          await widget.service.refreshQuote(
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
          SliverLayoutBuilder(
            builder: (BuildContext context, constraints) {
              const expandedHeight = 180.0;
              final scrolled =
                  math.min(expandedHeight, constraints.scrollOffset) /
                      expandedHeight;
              final t = (1 - scrolled).clamp(0.0, 1.0);
              final opacity = 1.0 - Interval(0, 1).transform(t);
              // debugPrint("transform: $t scrolled: $scrolled");
              return SliverAppBar(
                title:
                    Consumer<QuoteStore>(builder: (context, quoteStore, child) {
                  return Opacity(
                      opacity: opacity,
                      child: headerTitle(instrument, quoteStore));
                }),
                expandedHeight: 240, // 280.0,
                floating: false,
                snap: false,
                pinned: true,
                flexibleSpace: LayoutBuilder(builder:
                    (BuildContext context, BoxConstraints constraints) {
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
                      math.max(0.0, 1.0 - kToolbarHeight * 2 / deltaExtent);
                  const fadeEnd = 1.0;
                  final opacity =
                      1.0 - Interval(fadeStart, fadeEnd).transform(t);
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
                                        RobinhoodService.removeLogo(instrument);
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
                        opacity:
                            opacity, //top > kToolbarHeight * 3 ? 1.0 : 0.0,
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
                actions: [
                  IconButton(
                      icon: auth.currentUser != null
                          ? (auth.currentUser!.photoURL == null
                              ? const Icon(Icons.account_circle)
                              : CircleAvatar(
                                  maxRadius: 12,
                                  backgroundImage: CachedNetworkImageProvider(
                                      auth.currentUser!.photoURL!
                                      //  ?? Constants .placeholderImage, // No longer used
                                      )))
                          : const Icon(Icons.login),
                      onPressed: () async {
                        var response = await showProfile(
                            context,
                            auth,
                            _firestoreService,
                            widget.analytics,
                            widget.observer,
                            widget.user);
                        if (response != null) {
                          setState(() {});
                        }
                      }),
                ],
                // actions: <Widget>[
                //   IconButton(
                //     icon: const Icon(Icons.more_vert),
                //     // icon: const Icon(Icons.settings),
                //     onPressed: () {
                //       showModalBottomSheet<void>(
                //         context: context,
                //        showDragHandle: true,
                //         //isScrollControlled: true,
                //         //useRootNavigator: true,
                //         //constraints: const BoxConstraints(maxHeight: 200),
                //         builder: (_) => MoreMenuBottomSheet(
                //           widget.user,
                //           onSettingsChanged: _handleSettingsChanged,
                //           analytics: widget.analytics,
                //           observer: widget.observer,
                //         ),
                //       );
                //     },
                //   ),
                // ],
              );
            },
          ),
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
                    buildOverview(instrument)
                  ]))),
          Consumer<InstrumentHistoricalsStore>(builder: //, QuoteStore
              (context, instrumentHistoricalsStore, child) {
            //, quoteStore
            instrument.instrumentHistoricalsObj =
                instrumentHistoricalsStore.items.firstWhereOrNull((element) =>
                        element.symbol == instrument.symbol &&
                        element.span ==
                            convertChartSpanFilter(chartDateSpanFilter) &&
                        element.bounds ==
                            convertChartBoundsFilter(chartBoundsFilter)
                    //&& element.interval == element.interval
                    );

            // TODO: The close of the last period should be added to the chart series data.
            // var rsi = instrumentHistoricalsStore.items.firstWhereOrNull(
            //     (element) =>
            //         element.symbol == instrument.symbol &&
            //         element.span ==
            //             convertChartSpanFilter(ChartDateSpan.month) &&
            //         element.bounds ==
            //             convertChartBoundsFilter(chartBoundsFilter) &&
            //         element.interval == 'day');
            // if (rsi != null) {
            //   debugPrint(rsi.historicals.first.closePrice!.toString());
            //   debugPrint(rsi.historicals.last.closePrice!.toString());
            // }

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
              open = firstHistorical
                  .openPrice!; // instrument.instrumentHistoricalsObj!.previousClosePrice ??
              close = lastHistorical.closePrice!;
              changeInPeriod = close - open;
              changePercentInPeriod =
                  close / open - 1; // changeInPeriod / close;

              var brightness = MediaQuery.of(context).platformBrightness;
              var textColor = Theme.of(context).colorScheme.surface;
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
                        quoteObj.lastExtendedHoursTradePrice ?? quoteObj.lastTradePrice,
                        quoteObj.lastExtendedHoursTradePrice ?? quoteObj.lastTradePrice,
                        quoteObj.lastExtendedHoursTradePrice ?? quoteObj.lastTradePrice,
                        quoteObj.lastExtendedHoursTradePrice ?? quoteObj.lastTradePrice,
                        0,
                        '',
                        false));
              }
              */
              List<charts.Series<InstrumentHistorical, DateTime>> seriesList = [
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
              var extents = charts.NumericExtents.fromValues(
                  seriesList[0].data.map((e) => e.openPrice!));
              extents = charts.NumericExtents(
                  extents.min - (extents.width * 0.1),
                  extents.max + (extents.width * 0.1));
              //extents.min - (extents.min * 0.01), extents.max * 1.01);
              chart = TimeSeriesChart(seriesList,
                  open: open,
                  close: close,
                  hiddenSeries: const ["Close", "Volume", "Low", "High"],
                  onSelected: _onChartSelection,
                  zeroBound: false,
                  viewport: extents);

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
                      changePercentInPeriod = selection!.closePrice! / open -
                          1; // changeInPeriod / selection!.closePrice!;
                    } else {
                      changeInPeriod = close - open;
                      changePercentInPeriod =
                          close / open - 1; // changeInPeriod / close;
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
                              style: TextStyle(fontSize: 10, color: textColor),
                            ),
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
          if (instrument.quoteObj != null) ...[
            const SliverToBoxAdapter(
                child: SizedBox(
              height: 8.0,
            )),
            Consumer<InstrumentPositionStore>(
                builder: (context, stockPositionStore, child) {
              return quoteWidget(instrument);
            })
          ],
          Consumer<InstrumentPositionStore>(
              builder: (context, stockPositionStore, child) {
            var position = stockPositionStore.items
                .firstWhereOrNull((e) => e.instrument == instrument.url);
            if (position == null) {
              return SliverToBoxAdapter(child: Container());
            }
            return SliverToBoxAdapter(
                child: Card(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                  ListTile(
                      title: Text("Position", style: TextStyle(fontSize: 19)),
                      subtitle: Text(
                          '${formatNumber.format(position.quantity!)} shares'),
                      trailing: Text(
                          formatCurrency.format(position.marketValue),
                          style: const TextStyle(fontSize: 21))),
                  _buildDetailScrollRow(
                      position, summaryValueFontSize, summaryLabelFontSize,
                      iconSize: 27.0),
                  // ListTile(
                  //   minTileHeight: 10,
                  //   title: const Text("Cost"),
                  //   trailing: Text(formatCurrency.format(position.totalCost),
                  //       style: const TextStyle(fontSize: 18)),
                  // ),
                  // ListTile(
                  //   minTileHeight: 10,
                  //   contentPadding: const EdgeInsets.fromLTRB(0, 0, 24, 8),
                  //   // title: const Text("Average Cost"),
                  //   trailing: Text(
                  //       formatCurrency.format(position.averageBuyPrice),
                  //       style: const TextStyle(fontSize: 18)),
                  // ),
                  ListTile(
                    minTileHeight: 10,
                    title: const Text("Created"),
                    trailing: Text(formatDate.format(position.createdAt!),
                        style: const TextStyle(fontSize: 15)),
                  ),
                  ListTile(
                    minTileHeight: 10,
                    title: const Text("Updated"),
                    trailing: Text(formatDate.format(position.updatedAt!),
                        style: const TextStyle(fontSize: 15)),
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
                      height: 8.0,
                    )),
                    OptionPositionsWidget(
                      widget.user,
                      widget.service,
                      filteredOptionPositions,
                      showFooter: false,
                      showGroupHeader: false,
                      analytics: widget.analytics,
                      observer: widget.observer,
                    )
                  ]
                ]));
          }),
          if (instrument.dividendsObj != null &&
              instrument.dividendsObj!.isNotEmpty) ...[
            const SliverToBoxAdapter(
                child: SizedBox(
              height: 8.0,
            )),
            _buildDividendsWidget(instrument)
          ],
          if (instrument.fundamentalsObj != null) ...[
            const SliverToBoxAdapter(
                child: SizedBox(
              height: 8.0,
            )),
            fundamentalsWidget(instrument)
          ],
          if (instrument.ratingsObj != null &&
              instrument.ratingsObj["summary"] != null) ...[
            const SliverToBoxAdapter(
                child: SizedBox(
              height: 8.0,
            )),
            _buildRatingsWidget(instrument)
          ],
          if (instrument.ratingsOverviewObj != null) ...[
            const SliverToBoxAdapter(
                child: SizedBox(
              height: 8.0,
            )),
            _buildRatingsOverviewWidget(instrument)
          ],
          if (instrument.earningsObj != null &&
              instrument.earningsObj!.isNotEmpty) ...[
            const SliverToBoxAdapter(
                child: SizedBox(
              height: 8.0,
            )),
            _buildEarningsWidget(instrument)
          ],
          if (instrument.splitsObj != null &&
              instrument.splitsObj!.isNotEmpty) ...[
            const SliverToBoxAdapter(
                child: SizedBox(
              height: 8.0,
            )),
            _buildSplitsWidget(instrument)
          ],
          if (instrument.newsObj != null &&
              instrument.earningsObj!.isNotEmpty) ...[
            const SliverToBoxAdapter(
                child: SizedBox(
              height: 8.0,
            )),
            _buildNewsWidget(instrument)
          ],
          if (instrument.similarObj != null) ...[
            const SliverToBoxAdapter(
                child: SizedBox(
              height: 8.0,
            )),
            _buildSimilarWidget(instrument)
          ],
          if (instrument.listsObj != null) ...[
            const SliverToBoxAdapter(
                child: SizedBox(
              height: 8.0,
            )),
            _buildListsWidget(instrument)
          ],
          Consumer<InstrumentOrderStore>(
              builder: (context, stockOrderStore, child) {
            //var positionOrders = stockOrderStore.items.where(
            //    (element) => element.instrumentId == widget.instrument.id);

            if (instrument.positionOrders != null) {
              return SliverToBoxAdapter(
                  child: ShrinkWrappingViewport(
                      offset: ViewportOffset.zero(),
                      slivers: [
                    const SliverToBoxAdapter(
                        child: SizedBox(
                      height: 8.0,
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
                      height: 8.0,
                    )),
                    OptionOrdersWidget(
                      widget.user,
                      widget.service,
                      instrument.optionOrders!,
                      const ["confirmed", "filled"],
                      analytics: widget.analytics,
                      observer: widget.observer,
                    )
                  ]));
            }
            return SliverToBoxAdapter(child: Container());
          }),
          // TODO: Introduce web banner
          if (!kIsWeb) ...[
            const SliverToBoxAdapter(
                child: SizedBox(
              height: 25.0,
            )),
            SliverToBoxAdapter(child: AdBannerWidget()),
          ],
          const SliverToBoxAdapter(
              child: SizedBox(
            height: 25.0,
          )),
          const SliverToBoxAdapter(child: DisclaimerWidget()),
          const SliverToBoxAdapter(
              child: SizedBox(
            height: 25.0,
          )),
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

  /*
  void _handleSettingsChanged(dynamic settings) {
    setState(() {
      hasQuantityFilters = settings['hasQuantityFilters'];
      optionFilters = settings['optionFilters'];
      positionFilters = settings['positionFilters'];
    });
  }
  */

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
                                widget.service,
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
                onPressed: () =>
                    // showDialog<String>(
                    //   context: context,
                    //   builder: (BuildContext context) => AlertDialog(
                    //     title: const Text('Alert'),
                    //     content: const Text('This feature is not implemented.'),
                    //     actions: <Widget>[
                    //       TextButton(
                    //         onPressed: () => Navigator.pop(context, 'OK'),
                    //         child: const Text('OK'),
                    //       ),
                    //     ],
                    //   ),
                    // ),
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => TradeInstrumentWidget(
                                  widget.user, widget.service,
                                  //widget.account,
                                  // stockPosition: positi,
                                  instrument: instrument,
                                  positionType: "Buy",
                                  analytics: widget.analytics,
                                  observer: widget.observer,
                                )))),
            const SizedBox(width: 8),
            TextButton(
                child: const Text('SELL'),
                onPressed: () =>
                    // showDialog<String>(
                    //   context: context,
                    //   builder: (BuildContext context) => AlertDialog(
                    //     title: const Text('Alert'),
                    //     content: const Text('This feature is not implemented.'),
                    //     actions: <Widget>[
                    //       TextButton(
                    //         onPressed: () => Navigator.pop(context, 'OK'),
                    //         child: const Text('OK'),
                    //       ),
                    //     ],
                    //   ),
                    // ),
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => TradeInstrumentWidget(
                                  widget.user, widget.service,
                                  //widget.account,
                                  // stockPosition: positi,
                                  instrument: instrument,
                                  positionType: "Sell",
                                  analytics: widget.analytics,
                                  observer: widget.observer,
                                )))),
            const SizedBox(width: 8),
          ],
        ),
      ],
    ));
  }

  SingleChildScrollView _buildDetailScrollRow(
      InstrumentPosition ops, double valueFontSize, double labelFontSize,
      {double iconSize = 23.0}) {
    List<Widget> tiles = [];

    double? totalReturn = widget.user.getDisplayValueInstrumentPosition(ops,
        displayValue: DisplayValue.totalReturn);
    String? totalReturnText = widget.user
        .getDisplayText(totalReturn, displayValue: DisplayValue.totalReturn);

    double? totalReturnPercent = widget.user.getDisplayValueInstrumentPosition(
        ops,
        displayValue: DisplayValue.totalReturnPercent);
    String? totalReturnPercentText = widget.user.getDisplayText(
        totalReturnPercent,
        displayValue: DisplayValue.totalReturnPercent);

    double? todayReturn = widget.user.getDisplayValueInstrumentPosition(ops,
        displayValue: DisplayValue.todayReturn);
    String? todayReturnText = widget.user
        .getDisplayText(todayReturn, displayValue: DisplayValue.todayReturn);

    double? todayReturnPercent = widget.user.getDisplayValueInstrumentPosition(
        ops,
        displayValue: DisplayValue.todayReturnPercent);
    String? todayReturnPercentText = widget.user.getDisplayText(
        todayReturnPercent,
        displayValue: DisplayValue.todayReturnPercent);

    Icon todayIcon = widget.user.getDisplayIcon(todayReturn, size: iconSize);
    Icon totalIcon = widget.user.getDisplayIcon(totalReturn, size: iconSize);

    tiles = [
      Padding(
        padding:
            const EdgeInsets.all(summaryEgdeInset), //.symmetric(horizontal: 6),
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          Wrap(spacing: 8, children: [
            todayIcon,
            Text(todayReturnText, style: TextStyle(fontSize: valueFontSize))
          ]),
          /*
                                    Text(todayReturnText,
                                        style: const TextStyle(
                                            fontSize: summaryValueFontSize)),
                                            */
          /*
                                    Text(todayReturnPercentText,
                                        style: const TextStyle(
                                            fontSize: summaryValueFontSize)),
                                            */
          Text("Return Today", style: TextStyle(fontSize: labelFontSize)),
        ]),
      ),
      Padding(
        padding:
            const EdgeInsets.all(summaryEgdeInset), //.symmetric(horizontal: 6),
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          Text(todayReturnPercentText,
              style: TextStyle(fontSize: valueFontSize)),
          Text("Return Today %", style: TextStyle(fontSize: labelFontSize)),
        ]),
      ),
      Padding(
        padding:
            const EdgeInsets.all(summaryEgdeInset), //.symmetric(horizontal: 6),
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          Wrap(spacing: 8, children: [
            totalIcon,
            Text(totalReturnText, style: TextStyle(fontSize: valueFontSize))
          ]),
          /*
                                    Text(totalReturnText,
                                        style: const TextStyle(
                                            fontSize: summaryValueFontSize)),
                                            */
          /*
                                    Text(totalReturnPercentText,
                                        style: const TextStyle(
                                            fontSize: summaryValueFontSize)),
                                            */
          //Container(height: 5),
          //const Text("Δ", style: TextStyle(fontSize: 15.0)),
          Text("Total Return", style: TextStyle(fontSize: labelFontSize)),
        ]),
      ),
      Padding(
        padding:
            const EdgeInsets.all(summaryEgdeInset), //.symmetric(horizontal: 6),
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          Text(totalReturnPercentText,
              style: TextStyle(fontSize: valueFontSize)),

          //Container(height: 5),
          //const Text("Δ", style: TextStyle(fontSize: 15.0)),
          Text("Total Return %", style: TextStyle(fontSize: labelFontSize)),
        ]),
      ),
      Padding(
        padding:
            const EdgeInsets.all(summaryEgdeInset), //.symmetric(horizontal: 6),
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          Text(
              widget.user.getDisplayText(ops.totalCost,
                  displayValue: DisplayValue.totalCost),
              style: TextStyle(fontSize: valueFontSize)),

          //Container(height: 5),
          //const Text("Δ", style: TextStyle(fontSize: 15.0)),
          Text("Cost", style: TextStyle(fontSize: labelFontSize)),
        ]),
      ),
      Padding(
        padding:
            const EdgeInsets.all(summaryEgdeInset), //.symmetric(horizontal: 6),
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          Text(
              widget.user.getDisplayText(ops.averageBuyPrice!,
                  displayValue: DisplayValue.lastPrice),
              style: TextStyle(fontSize: valueFontSize)),

          //Container(height: 5),
          //const Text("Δ", style: TextStyle(fontSize: 15.0)),
          Text("Cost per share", style: TextStyle(fontSize: labelFontSize)),
        ]),
      )
    ];
    return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ...tiles,
            ])));
  }

  SingleChildScrollView _buildQuoteScrollRow(
      Instrument ops, double valueFontSize, double labelFontSize,
      {double iconSize = 23.0}) {
    List<Widget> tiles = [];

    // double? totalReturn = 0;
    // widget.user
    //     .getPositionDisplayValue(ops, displayValue: DisplayValue.totalReturn);
    // String? totalReturnText = '';
    // widget.user
    //     .getDisplayText(totalReturn!, displayValue: DisplayValue.totalReturn);

    // double? totalReturnPercent = 0;
    // widget.user.getPositionDisplayValue(ops,
    //     displayValue: DisplayValue.totalReturnPercent);
    // String? totalReturnPercentText = widget.user.getDisplayText(
    //     totalReturnPercent!,
    //     displayValue: DisplayValue.totalReturnPercent);

    double? todayReturn = ops.quoteObj?.changeToday;
    String? todayReturnText = widget.user
        .getDisplayText(todayReturn!, displayValue: DisplayValue.todayReturn);

    double? todayReturnPercent = ops.quoteObj?.changePercentToday;
    String? todayReturnPercentText = widget.user.getDisplayText(
        todayReturnPercent!,
        displayValue: DisplayValue.todayReturnPercent);

    Icon todayIcon = widget.user.getDisplayIcon(todayReturn, size: iconSize);
    // Icon totalIcon = widget.user.getDisplayIcon(totalReturn, size: iconSize);

    tiles = [
      Padding(
        padding:
            const EdgeInsets.all(summaryEgdeInset), //.symmetric(horizontal: 6),
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          Wrap(spacing: 8, children: [
            todayIcon,
            Text(todayReturnText, style: TextStyle(fontSize: valueFontSize))
          ]),
          Text("Change Today", style: TextStyle(fontSize: labelFontSize)),
        ]),
      ),
      Padding(
        padding:
            const EdgeInsets.all(summaryEgdeInset), //.symmetric(horizontal: 6),
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          Text(todayReturnPercentText,
              style: TextStyle(fontSize: valueFontSize)),
          Text("Change Today %", style: TextStyle(fontSize: labelFontSize)),
        ]),
      ),
      Padding(
        padding:
            const EdgeInsets.all(summaryEgdeInset), //.symmetric(horizontal: 6),
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          Wrap(spacing: 8, children: [
            // totalIcon,
            Text(
                widget.user.getDisplayText(ops.quoteObj!.bidPrice!,
                    displayValue: DisplayValue.lastPrice),
                style: TextStyle(fontSize: valueFontSize))
          ]),
          //Container(height: 5),
          //const Text("Δ", style: TextStyle(fontSize: 15.0)),
          Text("Bid x ${ops.quoteObj!.bidSize}",
              style: TextStyle(fontSize: labelFontSize)),
        ]),
      ),
      Padding(
        padding:
            const EdgeInsets.all(summaryEgdeInset), //.symmetric(horizontal: 6),
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          Wrap(spacing: 8, children: [
            // totalIcon,
            Text(
                widget.user.getDisplayText(ops.quoteObj!.askPrice!,
                    displayValue: DisplayValue.lastPrice),
                style: TextStyle(fontSize: valueFontSize))
          ]),
          //Container(height: 5),
          //const Text("Δ", style: TextStyle(fontSize: 15.0)),
          Text("Ask x ${ops.quoteObj!.askSize}",
              style: TextStyle(fontSize: labelFontSize)),
        ]),
      ),
      Padding(
        padding:
            const EdgeInsets.all(summaryEgdeInset), //.symmetric(horizontal: 6),
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          Wrap(spacing: 8, children: [
            // totalIcon,
            Text(
                widget.user.getDisplayText(ops.quoteObj!.adjustedPreviousClose!,
                    displayValue: DisplayValue.lastPrice),
                style: TextStyle(fontSize: valueFontSize))
          ]),
          //Container(height: 5),
          //const Text("Δ", style: TextStyle(fontSize: 15.0)),
          Text("Previous Close", style: TextStyle(fontSize: labelFontSize)),
        ]),
      ),
    ];
    return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ...tiles,
            ])));
  }

  Widget quoteWidget(Instrument instrument) {
    return SliverToBoxAdapter(
        child: ShrinkWrappingViewport(offset: ViewportOffset.zero(), slivers: [
      SliverToBoxAdapter(
          child: Column(children: [
        ListTile(
          title: Text(
            "Quote",
            style: TextStyle(fontSize: 19.0),
          ),
          subtitle: Text(
              instrument.quoteObj!.lastExtendedHoursTradePrice != null
                  ? 'Extended hours'
                  : ''),
          trailing: Text(
              formatCurrency.format(
                  instrument.quoteObj!.lastExtendedHoursTradePrice ??
                      instrument.quoteObj!.lastTradePrice),
              style: const TextStyle(fontSize: 21)),
        ),
        _buildQuoteScrollRow(
            instrument, summaryValueFontSize, summaryLabelFontSize,
            iconSize: 27.0),
      ])),
      SliverToBoxAdapter(
          child: Card(
              child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
        // ListTile(
        //   minTileHeight: 10,
        //   title: const Text("Bid/Ask"),
        //   trailing: Text(
        //       "${formatCurrency.format(instrument.quoteObj!.bidPrice)} x ${formatCompactNumber.format(instrument.quoteObj!.bidSize)}",
        //       style: const TextStyle(fontSize: 18)),
        // ),
        // ListTile(
        //   minTileHeight: 10,
        //   contentPadding: const EdgeInsets.fromLTRB(0, 0, 24, 8),
        //   // title: const Text("Ask"),
        //   trailing: Text(
        //       "${formatCurrency.format(instrument.quoteObj!.askPrice)} x ${formatCompactNumber.format(instrument.quoteObj!.askSize)}",
        //       style: const TextStyle(fontSize: 18)),
        // ),
        // ListTile(
        //   minTileHeight: 10,
        //   title: const Text("Previous Close"),
        //   trailing: Text(
        //       formatCurrency.format(instrument.quoteObj!.adjustedPreviousClose),
        //       style: const TextStyle(fontSize: 18)),
        // ),
        // ListTile(
        //   minTileHeight: 10,
        //   title: const Text("Bid - Ask Size"),
        //   trailing: Text(
        //       "${formatCompactNumber.format(instrument.quoteObj!.bidSize)} - ${formatCompactNumber.format(instrument.quoteObj!.askSize)}",
        //       style: const TextStyle(fontSize: 18)),
        // ),
        // Container(
        //   height: 10,
        // )
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
                  const Text("Fundamentals", style: TextStyle(fontSize: 19))),
                  */
        ListTile(
          minTileHeight: 10,
          title: const Text("Volume"),
          trailing: Text(
              formatCompactNumber.format(instrument.fundamentalsObj!.volume!),
              style: const TextStyle(fontSize: 18)),
        ),
        ListTile(
          minTileHeight: 10,
          title: const Text("Average Volume"),
          trailing: Text(
              formatCompactNumber
                  .format(instrument.fundamentalsObj!.averageVolume!),
              style: const TextStyle(fontSize: 18)),
        ),
        ListTile(
          minTileHeight: 10,
          title: const Text("Average Volume (2 weeks)"),
          trailing: Text(
              formatCompactNumber
                  .format(instrument.fundamentalsObj!.averageVolume2Weeks!),
              style: const TextStyle(fontSize: 18)),
        ),
        ListTile(
          minTileHeight: 10,
          title: const Text("52 Week High"),
          trailing: Text(
              formatCurrency.format(instrument.fundamentalsObj!.high52Weeks!),
              style: const TextStyle(fontSize: 18)),
        ),
        ListTile(
          minTileHeight: 10,
          title: const Text("52 Week Low"),
          trailing: Text(
              formatCurrency.format(instrument.fundamentalsObj!.low52Weeks!),
              style: const TextStyle(fontSize: 18)),
        ),
        ListTile(
          minTileHeight: 10,
          title: const Text("Dividend Yield"),
          trailing: Text(
              instrument.fundamentalsObj!.dividendYield != null
                  ? formatCompactNumber
                      .format(instrument.fundamentalsObj!.dividendYield!)
                  : "-",
              style: const TextStyle(fontSize: 18)),
        ),
        ListTile(
          minTileHeight: 10,
          title: const Text("Market Cap"),
          trailing: Text(
              formatCompactNumber
                  .format(instrument.fundamentalsObj!.marketCap!),
              style: const TextStyle(fontSize: 18)),
        ),
        ListTile(
          minTileHeight: 10,
          title: const Text("Shares Outstanding"),
          trailing: Text(
              formatCompactNumber
                  .format(instrument.fundamentalsObj!.sharesOutstanding!),
              style: const TextStyle(fontSize: 18)),
        ),
        ListTile(
          minTileHeight: 10,
          title: const Text("P/E Ratio"),
          trailing: Text(
              instrument.fundamentalsObj!.peRatio != null
                  ? formatCompactNumber
                      .format(instrument.fundamentalsObj!.peRatio!)
                  : "-",
              style: const TextStyle(fontSize: 18)),
        ),
        ListTile(
          minTileHeight: 10,
          title: const Text("Type"),
          trailing: Text(
              instrument.type == "stock"
                  ? "Stock"
                  : (instrument.type == "etp"
                      ? "Exchange Traded Product"
                      : instrument.type),
              style: const TextStyle(fontSize: 16)),
        ),
        if (instrument.type == "etp" && instrument.etpDetails != null) ...[
          ListTile(
            minTileHeight: 10,
            title: const Text("Inception"),
            trailing: Text(
                formatDate.format(
                    DateTime.parse(instrument.etpDetails["inception_date"])),
                style: const TextStyle(fontSize: 16)),
          ),
          if (instrument.etpDetails["is_inverse"] ||
              instrument.etpDetails["is_leveraged"] ||
              instrument.etpDetails["is_volatility_linked"] ||
              instrument.etpDetails["is_crypto_futures"] ||
              instrument.etpDetails["is_actively_managed"]) ...[
            ListTile(
              minTileHeight: 10,
              title: const Text("Characteristics"),
              trailing: Text(
                  "${instrument.etpDetails["is_inverse"] ? "Inverse" : ""} ${instrument.etpDetails["is_leveraged"] ? "Leveraged" : ""} ${instrument.etpDetails["is_volatility_linked"] ? "Volatility linked" : ""} ${instrument.etpDetails["is_crypto_futures"] ? "Crypto futures" : ""} ${instrument.etpDetails["is_actively_managed"] ? "Actively managed" : ""}",
                  style: const TextStyle(fontSize: 16)),
            ),
          ],
          ListTile(
            minTileHeight: 10,
            title: const Text("Category"),
            trailing: Text(instrument.etpDetails["category"],
                style: const TextStyle(fontSize: 16)),
          ),
          ListTile(
            minTileHeight: 10,
            title: Wrap(
              children: [
                const Text("Holdings"),
                SizedBox(
                  height: 24,
                  child: IconButton(
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.info_outline),
                    onPressed: () {
                      // var holdings = instrument.etpDetails["holdings"]
                      //     .map((h) => "${h["name"]} ${h["weight"]}%")
                      //     .toList();
                      showDialog<String>(
                          context: context,
                          builder: (BuildContext context) => AlertDialog(
                                // context: context,
                                title: Text('${instrument.symbol} Holdings'),
                                content: Table(
                                  border: TableBorder.all(),
                                  columnWidths: {
                                    0: FlexColumnWidth(4),
                                    1: FlexColumnWidth(1)
                                  },
                                  children: [
                                    for (var holding in instrument
                                        .etpDetails["holdings"]) ...[
                                      TableRow(children: [
                                        SelectableText(holding["name"]),
                                        SelectableText(holding["weight"]),
                                      ])
                                    ]
                                  ],
                                ),
                                // SelectableText(holdings.join("\n")),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text('OK'),
                                  ),
                                ],
                              ));
                    },
                  ),
                ),
              ],
            ),
            trailing: Wrap(children: [
              Text(formatNumber.format(instrument.etpDetails["total_holdings"]),
                  style: const TextStyle(fontSize: 18)),
            ]),
          ),
          ListTile(
            minTileHeight: 10,
            title: const Text("Assets under Management"),
            trailing: Text(
                formatCompactCurrency
                    .format(double.parse(instrument.etpDetails["aum"])),
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            minTileHeight: 10,
            title: const Text("Gross Expense Ratio"),
            trailing: Text(
                formatPercentage.format(double.tryParse(
                        instrument.etpDetails["gross_expense_ratio"])! /
                    100),
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            minTileHeight: 10,
            title: const Text("SEC Yield"),
            trailing: Text(
                instrument.etpDetails["sec_yield"] != null
                    ? formatPercentage.format(
                        double.tryParse(instrument.etpDetails["sec_yield"])! /
                            100)
                    : "-",
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            minTileHeight: 10,
            title: const Text("Month Performance"),
            subtitle:
                Text("1 year to ${instrument.etpDetails["month_end_date"]}"),
            trailing: Text(
                instrument.etpDetails["month_end_performance"]["market"]
                            ["1Y"] !=
                        null
                    ? formatPercentage.format(double.tryParse(
                            instrument.etpDetails["month_end_performance"]
                                ["market"]["1Y"])! /
                        100)
                    : "-",
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            minTileHeight: 10,
            title: const Text("Quarter Performance"),
            subtitle: Text(
                "Since inception to ${instrument.etpDetails["quarter_end_date"]}"),
            trailing: Text(
                instrument.etpDetails["quarter_end_performance"]["market"]
                            ["since_inception"] !=
                        null
                    ? formatPercentage.format(double.tryParse(
                            instrument.etpDetails["quarter_end_performance"]
                                ["market"]["since_inception"])! /
                        100)
                    : "-",
                style: const TextStyle(fontSize: 18)),
          ),
        ],
        ListTile(
          minTileHeight: 10,
          title: const Text("Sector"),
          subtitle: Text(instrument.fundamentalsObj!.sector,
              style: const TextStyle(fontSize: 16)),
        ),
        ListTile(
          minTileHeight: 10,
          title: const Text("Industry"),
          subtitle: Text(instrument.fundamentalsObj!.industry,
              style: const TextStyle(fontSize: 16)),
          // trailing: Text(instrument.fundamentalsObj!.industry,
          //     overflow: TextOverflow.ellipsis,
          //     style: const TextStyle(fontSize: 16)),
        ),
        ListTile(
          minTileHeight: 10,
          title: const Text(
            "Name",
            style: TextStyle(fontSize: 18.0),
            //overflow: TextOverflow.visible
          ),
          subtitle: Text(instrument.name, style: const TextStyle(fontSize: 16)),
        ),
        ListTile(
          minTileHeight: 10,
          title: const Text(
            "Description",
            style: TextStyle(fontSize: 18.0),
            //overflow: TextOverflow.visible
          ),
          subtitle: Text(instrument.fundamentalsObj!.description,
              style: const TextStyle(fontSize: 16)),
        ),
        if (instrument.fundamentalsObj!.headquartersCity.isNotEmpty ||
            instrument.fundamentalsObj!.headquartersState.isNotEmpty) ...[
          ListTile(
            minTileHeight: 10,
            title: const Text("Headquarters"),
            subtitle: Text(
                "${instrument.fundamentalsObj!.headquartersCity}${instrument.fundamentalsObj!.headquartersCity.isNotEmpty ? "," : ""} ${instrument.fundamentalsObj!.headquartersState}",
                style: const TextStyle(fontSize: 16)),
          ),
        ],
        if (instrument.fundamentalsObj!.ceo.isNotEmpty) ...[
          ListTile(
            minTileHeight: 10,
            title: const Text("CEO"),
            trailing: Text(instrument.fundamentalsObj!.ceo,
                style: const TextStyle(fontSize: 17)),
          ),
        ],
        if (instrument.fundamentalsObj!.numEmployees != null) ...[
          ListTile(
            minTileHeight: 10,
            title: const Text("Number of Employees"),
            trailing: Text(
                instrument.fundamentalsObj!.numEmployees != null
                    ? formatCompactNumber
                        .format(instrument.fundamentalsObj!.numEmployees!)
                    : "",
                style: const TextStyle(fontSize: 17)),
          ),
        ],
        if (instrument.fundamentalsObj!.yearFounded != null) ...[
          ListTile(
            minTileHeight: 10,
            title: const Text("Year Founded"),
            trailing: Text("${instrument.fundamentalsObj!.yearFounded ?? ""}",
                style: const TextStyle(fontSize: 17)),
          ),
        ],
        Container(
          height: 10,
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
        // const SizedBox(height: 15),
        if (instrument.ratingsOverviewObj!["fair_value"] != null) ...[
          ListTile(
            minTileHeight: 10,
            title: const Text("Fair Value"),
            trailing: Text(
                formatCurrency.format(double.parse(
                    instrument.ratingsOverviewObj!["fair_value"]["value"])),
                style: const TextStyle(fontSize: 18)),
          ),
        ],
        ListTile(
          minTileHeight: 10,
          title: const Text("Economic Moat"),
          trailing: Text(
              instrument.ratingsOverviewObj!["economic_moat"]
                  .toString()
                  .capitalize(),
              style: const TextStyle(fontSize: 18)),
        ),
        if (instrument.ratingsOverviewObj!["star_rating"] != null) ...[
          ListTile(
              minTileHeight: 10,
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
          minTileHeight: 10,
          title: const Text("Stewardship"),
          trailing: Text(
              instrument.ratingsOverviewObj!["stewardship"]
                  .toString()
                  .capitalize(),
              style: const TextStyle(fontSize: 18)),
        ),
        ListTile(
          minTileHeight: 10,
          title: const Text("Uncertainty"),
          trailing: Text(
              instrument.ratingsOverviewObj!["uncertainty"]
                  .toString()
                  .replaceAll('_', ' ')
                  .capitalize(),
              style: const TextStyle(fontSize: 18)),
        ),
        ListTile(
          minTileHeight: 10,
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
        Row(mainAxisAlignment: MainAxisAlignment.end, children: <Widget>[
          TextButton(
            child: const Text('DOWNLOAD REPORT'),
            onPressed: () async {
              var url = instrument.ratingsOverviewObj!["download_url"];
              var uri = Uri.parse(url);
              await canLaunchUrl(uri)
                  ? await launchUrl(uri)
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
                    var uri = Uri.parse(url);
                    await canLaunchUrl(uri)
                        ? await launchUrl(uri)
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
                    var uri = Uri.parse(url);
                    await canLaunchUrl(uri)
                        ? await launchUrl(uri)
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

  Widget _buildDividendsWidget(Instrument instrument) {
    return SliverToBoxAdapter(
        child: ShrinkWrappingViewport(offset: ViewportOffset.zero(), slivers: [
      IncomeTransactionsWidget(
          widget.user,
          widget.service,
          Provider.of<DividendStore>(context, listen: false),
          Provider.of<InstrumentPositionStore>(context, listen: false),
          Provider.of<ChartSelectionStore>(context, listen: false),
          transactionSymbolFilters: [instrument.symbol],
          showChips: false,
          showList: true,
          showFooter: false,
          showYield: true,
          analytics: widget.analytics,
          observer: widget.observer),
      // const SliverToBoxAdapter(
      //     child: Column(children: [
      //   ListTile(
      //     title: Text(
      //       "Dividends",
      //       style: TextStyle(fontSize: 19.0),
      //     ),
      //   )
      // ])),
      // SliverToBoxAdapter(
      //     child: Card(
      //         child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      //   for (var dividend in instrument.dividendsObj!) ...[
      //     ListTile(
      //         title: Text(
      //           "${formatCurrency.format(double.parse(dividend!["rate"]))} ${dividend!["state"]}",
      //           style: const TextStyle(fontSize: 18.0),
      //           //overflow: TextOverflow.visible
      //         ), // ${formatNumber.format(double.parse(dividend!["position"]))}
      //         subtitle: Text(
      //             "${formatNumber.format(double.parse(dividend!["position"]))} shares on ${formatDate.format(DateTime.parse(dividend!["payable_date"]))}", // ${formatDate.format(DateTime.parse(dividend!["record_date"]))}s
      //             style: const TextStyle(fontSize: 14)),
      //         trailing: Wrap(spacing: 10.0, children: [
      //           Column(children: [
      //             // const Text("Actual", style: TextStyle(fontSize: 11)),
      //             Text(formatCurrency.format(double.parse(dividend!["amount"])),
      //                 style: const TextStyle(fontSize: 18))
      //           ])
      //         ])),
      //   ],
      // ])))
    ]));
  }

  Widget _buildSplitsWidget(Instrument instrument) {
    return SliverToBoxAdapter(
        child: ShrinkWrappingViewport(
            offset: ViewportOffset.zero(),
            slivers: const [
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
                  child:
                      Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
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
                        ? Image.network(
                            instrument.similarObj![index]["logo_url"]
                                .toString()
                                .replaceAll("https:////", "https://"),
                            width: 50,
                            height: 50,
                            errorBuilder: (BuildContext context,
                                Object exception, StackTrace? stackTrace) {
                              //RobinhoodService.removeLogo(instrument.similarObj![index]["symbol"]);
                              return CircleAvatar(
                                  radius: 25,
                                  // foregroundColor:
                                  //     Theme.of(context).colorScheme.primary,
                                  child: Text(
                                    instrument.similarObj![index]["symbol"],
                                  ));
                            },
                          )
                        : CircleAvatar(
                            radius: 25,
                            // foregroundColor:
                            //     Theme.of(context).colorScheme.primary,
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
                  var similarInstruments = await widget.service
                      .getInstrumentsByIds(
                          widget.user,
                          Provider.of<InstrumentStore>(context, listen: false),
                          [instrument.similarObj![index]["instrument_id"]]);
                  if (instrument.similarObj![index]["logo_url"] != null &&
                      instrument.similarObj![index]["logo_url"] !=
                          similarInstruments[0].logoUrl) {
                    similarInstruments[0].logoUrl = instrument
                        .similarObj![index]["logo_url"]
                        .toString()
                        .replaceAll("https:////", "https://");
                    _firestoreService.upsertInstrument(similarInstruments[0]);
                  }
                  if (context.mounted) {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => InstrumentWidget(
                                  widget.user,
                                  widget.service,
                                  similarInstruments[0],
                                  analytics: widget.analytics,
                                  observer: widget.observer,
                                )));
                  }
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
                // minTileHeight: 10,
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
                                widget.service,
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
                  var uri = Uri.parse(url);
                  await canLaunchUrl(uri)
                      ? await launchUrl(uri)
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

  Widget positionOrdersWidget(List<InstrumentOrder> positionOrders) {
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
                    showDragHandle: true,
                    constraints: const BoxConstraints(maxHeight: 260),
                    builder: (BuildContext context) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            // tileColor: Theme.of(context).colorScheme.primary,
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
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          //runAlignment: WrapAlignment.end,
          //alignment: WrapAlignment.end,
          spacing: 20,
          //runSpacing: 5,
          children: [
            Row(children: [
              Text(
                  instrument
                      .symbol, // ${optionPosition.strategy.split('_').first}
                  //style: const TextStyle(fontSize: 20.0)
                  style: const TextStyle(fontSize: 17.0)),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(
                      instrument.simpleName ??
                          instrument
                              .name, // ${optionPosition.strategy.split('_').first}
                      //style: const TextStyle(fontSize: 20.0)
                      style: const TextStyle(fontSize: 17.0))),
            ]),
            /*
            Wrap(
                crossAxisAlignment: WrapCrossAlignment.end,
                //runAlignment: WrapAlignment.end,
                //alignment: WrapAlignment.end,
                spacing: 10,
                //runSpacing: 5,
                children: [
                  Text(
                      instrument
                          .symbol, // ${optionPosition.strategy.split('_').first}
                      //style: const TextStyle(fontSize: 20.0)
                      style: const TextStyle(fontSize: 17.0)),
                  Text(
                      instrument.simpleName ??
                          instrument
                              .name, // ${optionPosition.strategy.split('_').first}
                      //style: const TextStyle(fontSize: 20.0)
                      style: const TextStyle(fontSize: 17.0)),
                ]),
                */
            if (quoteObj != null) ...[
              Wrap(spacing: 10, children: [
                Text(
                    formatCurrency.format(
                        quoteObj.lastExtendedHoursTradePrice ??
                            quoteObj.lastTradePrice),
                    //style: const TextStyle(fontSize: 15.0)
                    style: const TextStyle(
                        fontSize: 16.0)), // , color: Colors.white70
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
                      style: const TextStyle(
                          fontSize: 16.0)), // , color: Colors.white70
                ]),
                Text(
                    "${quoteObj.changeToday > 0 ? "+" : quoteObj.changeToday < 0 ? "-" : ""}${formatCurrency.format(quoteObj.changeToday.abs())}",
                    //style: const TextStyle(fontSize: 12.0),
                    style: const TextStyle(
                        fontSize: 16.0), // , color: Colors.white70
                    textAlign: TextAlign.right)
              ])
            ],
          ]),
    );
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
                  style: TextStyle(
                      fontSize: 16.0,
                      color: Theme.of(context).appBarTheme.foregroundColor),
                  // Colors.white), // Theme.of(context).textTheme.bodyLarge!.color!),
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
