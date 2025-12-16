import 'dart:async';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/extensions.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/model/chart_selection_store.dart';
import 'package:robinhood_options_mobile/model/dividend_store.dart';
import 'package:robinhood_options_mobile/model/generative_provider.dart';
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
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/utils/ai.dart';
import 'package:robinhood_options_mobile/utils/market_hours.dart';
import 'package:robinhood_options_mobile/widgets/ad_banner_widget.dart';
import 'package:robinhood_options_mobile/widgets/chart_time_series_widget.dart';
import 'package:robinhood_options_mobile/widgets/disclaimer_widget.dart';
import 'package:robinhood_options_mobile/widgets/income_transactions_widget.dart';
import 'package:robinhood_options_mobile/widgets/instrument_option_chain_widget.dart';
import 'package:robinhood_options_mobile/widgets/list_widget.dart';
import 'package:robinhood_options_mobile/widgets/option_orders_widget.dart';
import 'package:robinhood_options_mobile/widgets/option_positions_widget.dart';
import 'package:robinhood_options_mobile/widgets/position_order_widget.dart';
import 'package:robinhood_options_mobile/widgets/sliverappbar_widget.dart';
import 'package:robinhood_options_mobile/widgets/trade_instrument_widget.dart';
import 'package:url_launcher/url_launcher.dart';
//import 'package:charts_flutter/flutter.dart' as charts;
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;

import 'package:robinhood_options_mobile/model/fundamentals.dart';
import 'package:robinhood_options_mobile/widgets/indicator_documentation_widget.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_historical.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/option_order.dart';
import 'package:robinhood_options_mobile/model/instrument_order.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/model/trade_signals_provider.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/widgets/agentic_trading_settings_widget.dart';
import 'package:robinhood_options_mobile/widgets/auto_trade_status_badge_widget.dart';
import 'package:robinhood_options_mobile/widgets/backtesting_widget.dart';

import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InstrumentWidget extends StatefulWidget {
  const InstrumentWidget(
      this.brokerageUser,
      this.service,
      //this.account,
      this.instrument,
      {super.key,
      required this.analytics,
      required this.observer,
      required this.generativeService,
      required this.user,
      required this.userDocRef,
      this.heroTag});

  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  final GenerativeService generativeService;
  final User? user;
  final DocumentReference<User>? userDocRef;
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
  Bounds chartBoundsFilter = Bounds.t24_7;
  InstrumentHistorical? selection;

  List<String> optionFilters = <String>[];
  List<String> positionFilters = <String>[];
  List<bool> hasQuantityFilters = [true, false];

  final List<String> orderFilters = <String>["confirmed", "filled", "queued"];

  double optionOrdersPremiumBalance = 0;
  double positionOrdersBalance = 0;
  // Controls whether all similar instruments are shown or only the first 5.
  bool _showAllSimilar = false;

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
    Provider.of<TradeSignalsProvider>(context, listen: false)
        .fetchTradeSignal(widget.instrument.symbol);
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

  /// Builds a portfolio state map with cash and all stock positions.
  ///
  /// Returns a map containing:
  /// - 'cash': The available portfolio cash from the account
  /// - For each position: symbol -> {quantity, price} or just quantity if price unavailable
  Map<String, dynamic> _buildPortfolioState(BuildContext context) {
    // Get actual portfolio cash from account (same as Home widget)
    double cash = 0.0;
    final accountStore = Provider.of<AccountStore>(context, listen: false);
    if (accountStore.items.isNotEmpty) {
      final account = accountStore.items.first;
      cash = account.portfolioCash ?? 0.0;
    }

    final stockPositionStore =
        Provider.of<InstrumentPositionStore>(context, listen: false);

    final Map<String, dynamic> portfolioState = {
      'cash': cash,
    };

    // Add all stock positions with their quantities and prices
    for (final position in stockPositionStore.items) {
      if (position.instrumentObj != null &&
          position.quantity != null &&
          position.quantity! > 0) {
        final posSymbol = position.instrumentObj!.symbol;
        final posQuantity = position.quantity!;
        final posPrice =
            position.instrumentObj!.quoteObj?.lastExtendedHoursTradePrice ??
                position.instrumentObj!.quoteObj?.lastTradePrice;

        if (posPrice != null) {
          // Store as object with quantity and price for accurate valuation
          portfolioState[posSymbol] = {
            'quantity': posQuantity,
            'price': posPrice,
          };
        } else {
          // Fallback to just quantity if price unavailable
          portfolioState[posSymbol] = posQuantity;
        }
      }
    }

    return portfolioState;
  }

  @override
  Widget build(BuildContext context) {
    var instrument = widget.instrument;
    var user = widget.brokerageUser;

    var optionOrderStore =
        Provider.of<OptionOrderStore>(context, listen: false);
    var optionOrders = optionOrderStore.items
        .where((element) => element.chainSymbol == widget.instrument.symbol)
        .toList();
    if (optionOrders.isNotEmpty) {
      futureOptionOrders = Future.value(optionOrders);
    } else if (widget.instrument.tradeableChainId != null) {
      futureOptionOrders ??= widget.service.getOptionOrders(
          widget.brokerageUser,
          optionOrderStore,
          widget.instrument.tradeableChainId!);
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
          widget.brokerageUser,
          stockPositionOrderStore,
          [widget.instrument.url]);
    }

    if (widget.instrument.logoUrl == null &&
        RobinhoodService.logoUrls.containsKey(widget.instrument.symbol) &&
        auth.currentUser != null) {
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
        .getOptionEventsByInstrumentUrl(widget.brokerageUser, instrument.url);

    futureEarnings ??= widget.service.getEarnings(user, instrument.id);

    futureSimilar ??= widget.service.getSimilar(user, instrument.id);

    futureSplits ??= widget.service.getSplits(user, instrument);

    futureHistoricals ??= widget.service.getInstrumentHistoricals(
        user,
        Provider.of<InstrumentHistoricalsStore>(context, listen: false),
        instrument.symbol,
        chartBoundsFilter: chartBoundsFilter,
        chartDateSpanFilter: chartDateSpanFilter);

    // futureRsiHistoricals ??= widget.service.getInstrumentHistoricals(
    //     user,
    //     Provider.of<InstrumentHistoricalsStore>(context, listen: false),
    //     instrument.symbol,
    //     chartBoundsFilter: Bounds.t24_7,
    //     chartDateSpanFilter: ChartDateSpan.month,
    //     chartInterval: 'day');

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
        futureHistoricals as Future,
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
          if (updateInstrument && auth.currentUser != null) {
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
        if (widget.brokerageUser.refreshEnabled) {
          await widget.service.getInstrumentHistoricals(
              widget.brokerageUser,
              Provider.of<InstrumentHistoricalsStore>(context, listen: false),
              widget.instrument.symbol,
              chartBoundsFilter: chartBoundsFilter,
              chartDateSpanFilter: chartDateSpanFilter);

          if (!mounted) return;
          await widget.service.refreshQuote(
              widget.brokerageUser,
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

  RefreshIndicator buildScrollView(Instrument instrument,
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
                centerTitle: false,
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
                        child: Consumer<QuoteStore>(
                            builder: (context, quoteStore, child) {
                          return SingleChildScrollView(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children:
                                      getHeaderWidgets(quoteStore).toList()));
                        }),
                        /*
          ListTile(
            title: Text('${instrument.simpleName}'),
            subtitle: Text(instrument.name),
          )*/
                      ));
                }),
                actions: [
                  AutoTradeStatusBadgeWidget(
                    user: widget.user,
                    userDocRef: widget.userDocRef,
                  ),
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
                            widget.brokerageUser);
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
          Consumer2<InstrumentHistoricalsStore, GenerativeProvider>(builder:
              (context, instrumentHistoricalsStore, generativeProvider, child) {
            return SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(
                    12.0,
                    0, // 16.0,
                    16.0,
                    0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // const CircleAvatar(
                    //   child: Icon(Icons.lightbulb_circle_outlined),
                    // ),
                    // const SizedBox(width: 10),
                    // const Text(
                    //   'AI Insight',
                    //   style:
                    //       TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    // ),
                    // const SizedBox(width: 16),
                    Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: ActionChip(
                        avatar: generativeProvider.generating &&
                                generativeProvider.generatingPrompt ==
                                    'chart-trend'
                            ? const CircularProgressIndicator()
                            : const Icon(Icons.recommend_outlined),
                        label: const Text('Trend'),
                        onPressed: () async {
                          var prompt = widget.generativeService.prompts
                              .firstWhere((p) => p.key == 'chart-trend');
                          String historicalDataString = instrument
                              .instrumentHistoricalsObj!.historicals
                              .where((e) => e.volume > 0)
                              .map((e) =>
                                  'Date: ${e.beginsAt}, Open: ${formatCurrency.format(e.openPrice)}, High: ${formatCurrency.format(e.highPrice)}, Low: ${formatCurrency.format(e.lowPrice)}, Close: ${formatCurrency.format(e.closePrice)}, Volume: ${formatCompactNumber.format(e.volume)}')
                              .join("\n");
                          var newPrompt = Prompt(
                              key: prompt.key,
                              title: prompt.title,
                              prompt:
                                  '${prompt.prompt.replaceAll("{{symbol}}", instrument.symbol)}\nwith the following chart data:\n$historicalDataString');
                          await generateContent(generativeProvider,
                              widget.generativeService, newPrompt, context);
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: ActionChip(
                        avatar: generativeProvider.generating &&
                                generativeProvider.generatingPrompt ==
                                    'stock-summary'
                            ? const CircularProgressIndicator()
                            : const Icon(Icons.summarize),
                        label: const Text('Summary'),
                        onPressed: () async {
                          var prompt = widget.generativeService.prompts
                              .firstWhere((p) => p.key == 'stock-summary');
                          var newPrompt = Prompt(
                              key: prompt.key,
                              title: prompt.title,
                              prompt: prompt.prompt
                                  .replaceAll("{{symbol}}", instrument.symbol));
                          await generateContent(generativeProvider,
                              widget.generativeService, newPrompt, context);
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: ActionChip(
                        avatar: generativeProvider.generating &&
                                generativeProvider.generatingPrompt == 'ask'
                            ? const CircularProgressIndicator()
                            : const Icon(Icons.question_answer),
                        label: const Text('Ask a question'),
                        onPressed: () async {
                          var prompt = widget.generativeService.prompts
                              .firstWhere((p) => p.key == 'ask');
                          prompt.appendPortfolioToPrompt = false;
                          await generateContent(generativeProvider,
                              widget.generativeService, prompt, context);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );

            // return SliverToBoxAdapter(
            //   child: Column(children: [
            //     // ListTile(
            //     //   title: const Text(
            //     //     "Assistant",
            //     //     style: TextStyle(fontSize: 19.0),
            //     //   ),
            //     // ),
            //     ListTile(
            //       title: Text(
            //         "Insight",
            //         style: TextStyle(fontSize: listTileTitleFontSize),
            //       ),
            //       trailing: Wrap(
            //         children: [
            //           TextButton.icon(
            //               onPressed: () async {
            //                 generativeProvider
            //                     .setGenerativePrompt('portfolio-summary');
            //                 await widget.generativeService
            //                     .generatePortfolioContent(
            //                         widget.generativeService.prompts
            //                             .firstWhere((p) =>
            //                                 p.key == 'portfolio-summary'),
            //                         stockPositionStore,
            //                         optionPositionStore,
            //                         forexHoldingStore,
            //                         generativeProvider);
            //               },
            //               label: Text("Summary"),
            //               icon: generativeProvider.generating &&
            //                               generativeProvider.promptResponses.containsKey('portfolio-summary') &&
            //                               generativeProvider.promptResponses['portfolio-summary'] == null
            //                   ? CircularProgressIndicator.adaptive()
            //                   : const Icon(Icons.summarize)),
            //           TextButton.icon(
            //               onPressed: () async {
            //                 generativeProvider.setGenerativePrompt(
            //                     'portfolio-recommendations');
            //                 await widget.generativeService
            //                     .generatePortfolioContent(
            //                         widget.generativeService.prompts
            //                             .firstWhere((p) =>
            //                                 p.key ==
            //                                 'portfolio-recommendations'),
            //                         stockPositionStore,
            //                         optionPositionStore,
            //                         forexHoldingStore,
            //                         generativeProvider);
            //               },
            //               label: Text("Recommendations"),
            //               icon: generativeProvider.generating &&
            //                               generativeProvider.promptResponses.containsKey('portfolio-recommendations') &&
            //                               generativeProvider.promptResponses['portfolio-recommendations'] == null
            //                   ? CircularProgressIndicator.adaptive()
            //                   : const Icon(Icons.recommend)),
            //         ],
            //       ),
            //     ),
            //     if (generativeProvider.promptResponses != null) ...[
            //       Padding(
            //         padding: const EdgeInsets.all(8.0),
            //         child: Card(
            //             child: SizedBox(
            //                 height: 280,
            //                 child: Markdown(
            //                     data: generativeProvider.response!))),
            //       ),
            //     ],
            //   ]),
            // );
          }),
          SliverToBoxAdapter(
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
          ])),
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
              var provider = Provider.of<InstrumentHistoricalsSelectionStore>(
                  context,
                  listen: false);

              chart = TimeSeriesChart(seriesList,
                  open: open,
                  close: close,
                  seriesLegend: charts.SeriesLegend(
                    horizontalFirst: true,
                    position: charts.BehaviorPosition.top,
                    defaultHiddenSeries: const [
                      "Close",
                      "Volume",
                      "Low",
                      "High"
                    ],
                    // To show value on legend upon selection
                    showMeasures: true,
                    measureFormatter: (measure) =>
                        measure != null ? formatCurrency.format(measure) : '',
                    // legendDefaultMeasure: charts.LegendDefaultMeasure.lastValue
                  ), onSelected: (charts.SelectionModel<DateTime>? historical) {
                provider
                    .selectionChanged(historical?.selectedDatum.first.datum);
              },
                  symbolRenderer: TextSymbolRenderer(() {
                    return provider.selection != null
                        // ${formatPercentage.format((provider.selection as MapEntry).value)}\n
                        ? formatCompactDateTimeWithHour.format(
                            (provider.selection as InstrumentHistorical)
                                .beginsAt!
                                .toLocal())
                        : '0';
                  }, marginBottom: 16),
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
                  SizedBox(
                      height: 340, // 240,
                      child: Padding(
                        //padding: EdgeInsets.symmetric(horizontal: 12.0),
                        padding: const EdgeInsets.all(10.0),
                        child: chart,
                      )),
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
                        // height: 43,
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
                child:
                    Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
              ListTile(
                  title: Text("Position", style: TextStyle(fontSize: 19)),
                  subtitle:
                      Text('${formatNumber.format(position.quantity!)} shares'),
                  trailing: Text(formatCurrency.format(position.marketValue),
                      style: const TextStyle(fontSize: 21))),
              _buildDetailScrollRow(
                  position, badgeValueFontSize, badgeLabelFontSize,
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
              // ListTile(
              //   minTileHeight: 10,
              //   title: const Text("Created"),
              //   trailing: Text(formatDate.format(position.createdAt!),
              //       style: const TextStyle(fontSize: 15)),
              // ),
              // ListTile(
              //   minTileHeight: 10,
              //   title: const Text("Updated"),
              //   trailing: Text(formatDate.format(position.updatedAt!),
              //       style: const TextStyle(fontSize: 15)),
              // ),
            ]));
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
                    OptionPositionsWidget(widget.brokerageUser, widget.service,
                        filteredOptionPositions,
                        showFooter: false,
                        showGroupHeader: false,
                        analytics: widget.analytics,
                        observer: widget.observer,
                        generativeService: widget.generativeService,
                        user: widget.user,
                        userDocRef: widget.userDocRef)
                  ]
                ]));
          }),
          if (instrument.tradeable) ...[
            const SliverToBoxAdapter(
                child: SizedBox(
              height: 8.0,
            )),
            _buildAgenticTradeSignals(instrument),
          ],
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
          if (instrument.listsObj != null &&
              instrument.listsObj!.isNotEmpty) ...[
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
                      widget.brokerageUser,
                      widget.service,
                      instrument.optionOrders!,
                      const ["confirmed", "filled"],
                      analytics: widget.analytics,
                      observer: widget.observer,
                      generativeService: widget.generativeService,
                      authUser: widget.user,
                      userDocRef: widget.userDocRef,
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
            SliverToBoxAdapter(
                child: AdBannerWidget(
              size: AdSize.mediumRectangle,
              // searchBanner: true,
            )),
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

  /*
  void _handleSettingsChanged(dynamic settings) {
    setState(() {
      hasQuantityFilters = settings['hasQuantityFilters'];
      optionFilters = settings['optionFilters'];
      positionFilters = settings['positionFilters'];
    });
  }
  */

  Widget buildOverview(Instrument instrument) {
    if (instrument.quoteObj == null) {
      return Container();
    }
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            if (instrument.tradeableChainId != null) ...[
              FilledButton.tonal(
                child: const Text('OPTION CHAIN'),
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => InstrumentOptionChainWidget(
                                widget.brokerageUser,
                                widget.service,
                                instrument,
                                analytics: widget.analytics,
                                observer: widget.observer,
                                generativeService: widget.generativeService,
                                user: widget.user,
                                userDocRef: widget.userDocRef,
                              )));
                },
              ),
            ],
            const SizedBox(width: 8),
            if (instrument.tradeable) ...[
              FilledButton(
                child: const Text('TRADE'),
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => TradeInstrumentWidget(
                              widget.brokerageUser,
                              widget.service,
                              instrument: instrument,
                              positionType: "Buy",
                              analytics: widget.analytics,
                              observer: widget.observer,
                            ))),
              ),
            ],
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  // Badge helpers extracted for reuse across detail & quote scroll rows.
  Color _pnlColor(double? value) {
    if (value == null) return Colors.grey;
    if (value > 0) return Colors.green;
    if (value < 0) return Colors.red;
    return Colors.grey;
  }

  Widget _pnlBadge(String text, double? value, double fontSize,
      {bool neutral = false}) {
    var color = neutral ? Colors.grey : _pnlColor(value);
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.25))),
        child: Text(text,
            style: TextStyle(
                fontSize: fontSize, color: color)) // keep passed font size
        );
  }

  SingleChildScrollView _buildDetailScrollRow(
      InstrumentPosition ops, double valueFontSize, double labelFontSize,
      {double iconSize = 23.0}) {
    List<Widget> tiles = [];

    double? totalReturn = widget.brokerageUser
        .getDisplayValueInstrumentPosition(ops,
            displayValue: DisplayValue.totalReturn);
    String? totalReturnText = widget.brokerageUser
        .getDisplayText(totalReturn, displayValue: DisplayValue.totalReturn);

    double? totalReturnPercent = widget.brokerageUser
        .getDisplayValueInstrumentPosition(ops,
            displayValue: DisplayValue.totalReturnPercent);
    String? totalReturnPercentText = widget.brokerageUser.getDisplayText(
        totalReturnPercent,
        displayValue: DisplayValue.totalReturnPercent);

    double? todayReturn = widget.brokerageUser
        .getDisplayValueInstrumentPosition(ops,
            displayValue: DisplayValue.todayReturn);
    String? todayReturnText = widget.brokerageUser
        .getDisplayText(todayReturn, displayValue: DisplayValue.todayReturn);

    double? todayReturnPercent = widget.brokerageUser
        .getDisplayValueInstrumentPosition(ops,
            displayValue: DisplayValue.todayReturnPercent);
    String? todayReturnPercentText = widget.brokerageUser.getDisplayText(
        todayReturnPercent,
        displayValue: DisplayValue.todayReturnPercent);

    tiles = [
      Padding(
          padding: const EdgeInsets.all(summaryEgdeInset),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _pnlBadge(todayReturnText, todayReturn, valueFontSize),
            Text("Return Today", style: TextStyle(fontSize: labelFontSize))
          ])),
      Padding(
          padding: const EdgeInsets.all(summaryEgdeInset),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _pnlBadge(
                todayReturnPercentText, todayReturnPercent, valueFontSize),
            Text("Return Today %", style: TextStyle(fontSize: labelFontSize))
          ])),
      Padding(
          padding: const EdgeInsets.all(summaryEgdeInset),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _pnlBadge(totalReturnText, totalReturn, valueFontSize),
            Text("Total Return", style: TextStyle(fontSize: labelFontSize))
          ])),
      Padding(
          padding: const EdgeInsets.all(summaryEgdeInset),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _pnlBadge(
                totalReturnPercentText, totalReturnPercent, valueFontSize),
            Text("Total Return %", style: TextStyle(fontSize: labelFontSize))
          ])),
      Padding(
          padding: const EdgeInsets.all(summaryEgdeInset),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _pnlBadge(
                widget.brokerageUser.getDisplayText(ops.totalCost,
                    displayValue: DisplayValue.totalCost),
                null,
                valueFontSize,
                neutral: true),
            Text("Cost", style: TextStyle(fontSize: labelFontSize))
          ])),
      Padding(
          padding: const EdgeInsets.all(summaryEgdeInset),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _pnlBadge(
                widget.brokerageUser.getDisplayText(ops.averageBuyPrice!,
                    displayValue: DisplayValue.lastPrice),
                null,
                valueFontSize,
                neutral: true),
            Text("Cost per share", style: TextStyle(fontSize: labelFontSize))
          ])),
      Padding(
          padding: const EdgeInsets.all(summaryEgdeInset),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _pnlBadge(formatCompactDateYear.format(ops.createdAt!), null,
                valueFontSize,
                neutral: true),
            Text("Opened", style: TextStyle(fontSize: labelFontSize))
          ])),
      Padding(
          padding: const EdgeInsets.all(summaryEgdeInset),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _pnlBadge(formatCompactDateYear.format(ops.updatedAt!), null,
                valueFontSize,
                neutral: true),
            Text("Updated", style: TextStyle(fontSize: labelFontSize))
          ])),
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
    String? todayReturnText = widget.brokerageUser
        .getDisplayText(todayReturn!, displayValue: DisplayValue.todayReturn);

    double? todayReturnPercent = ops.quoteObj?.changePercentToday;
    String? todayReturnPercentText = widget.brokerageUser.getDisplayText(
        todayReturnPercent!,
        displayValue: DisplayValue.todayReturnPercent);

    tiles = [
      Padding(
          padding: const EdgeInsets.all(summaryEgdeInset),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _pnlBadge(todayReturnText, todayReturn, valueFontSize),
            Text("Change Today", style: TextStyle(fontSize: labelFontSize))
          ])),
      Padding(
          padding: const EdgeInsets.all(summaryEgdeInset),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _pnlBadge(
                todayReturnPercentText, todayReturnPercent, valueFontSize),
            Text("Change Today %", style: TextStyle(fontSize: labelFontSize))
          ])),
      Padding(
          padding: const EdgeInsets.all(summaryEgdeInset),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _pnlBadge(
                widget.brokerageUser.getDisplayText(ops.quoteObj!.bidPrice!,
                    displayValue: DisplayValue.lastPrice),
                null,
                valueFontSize,
                neutral: true),
            Text("Bid x ${ops.quoteObj!.bidSize}",
                style: TextStyle(fontSize: labelFontSize))
          ])),
      Padding(
          padding: const EdgeInsets.all(summaryEgdeInset),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _pnlBadge(
                widget.brokerageUser.getDisplayText(ops.quoteObj!.askPrice!,
                    displayValue: DisplayValue.lastPrice),
                null,
                valueFontSize,
                neutral: true),
            Text("Ask x ${ops.quoteObj!.askSize}",
                style: TextStyle(fontSize: labelFontSize))
          ])),
      Padding(
          padding: const EdgeInsets.all(summaryEgdeInset),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _pnlBadge(
                widget.brokerageUser.getDisplayText(
                    ops.quoteObj!.adjustedPreviousClose!,
                    displayValue: DisplayValue.lastPrice),
                null,
                valueFontSize,
                neutral: true),
            Text("Previous Close", style: TextStyle(fontSize: labelFontSize))
          ])),
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
          subtitle: instrument.quoteObj!.lastExtendedHoursTradePrice != null
              ? Text('Extended hours')
              : null,
          trailing: Text(
              formatCurrency.format(
                  instrument.quoteObj!.lastExtendedHoursTradePrice ??
                      instrument.quoteObj!.lastTradePrice),
              style: const TextStyle(fontSize: 21)),
        ),
        _buildQuoteScrollRow(instrument, badgeValueFontSize, badgeLabelFontSize,
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
        if (instrument.fundamentalsObj!.averageVolume != null) ...[
          ListTile(
            minTileHeight: 10,
            title: const Text("Average Volume"),
            trailing: Text(
                formatCompactNumber
                    .format(instrument.fundamentalsObj!.averageVolume!),
                style: const TextStyle(fontSize: 18)),
          ),
        ],
        if (instrument.fundamentalsObj!.averageVolume2Weeks != null) ...[
          ListTile(
            minTileHeight: 10,
            title: const Text("Average Volume (2 weeks)"),
            trailing: Text(
                formatCompactNumber
                    .format(instrument.fundamentalsObj!.averageVolume2Weeks!),
                style: const TextStyle(fontSize: 18)),
          ),
        ],
        if (instrument.fundamentalsObj!.high52Weeks != null) ...[
          ListTile(
            minTileHeight: 10,
            title: const Text("52 Week High"),
            trailing: Text(
                formatCurrency.format(instrument.fundamentalsObj!.high52Weeks!),
                style: const TextStyle(fontSize: 18)),
          ),
        ],
        if (instrument.fundamentalsObj!.low52Weeks != null) ...[
          ListTile(
            minTileHeight: 10,
            title: const Text("52 Week Low"),
            trailing: Text(
                formatCurrency.format(instrument.fundamentalsObj!.low52Weeks!),
                style: const TextStyle(fontSize: 18)),
          ),
        ],
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
                  .format(instrument.fundamentalsObj!.marketCap ?? 0),
              style: const TextStyle(fontSize: 18)),
        ),
        ListTile(
          minTileHeight: 10,
          title: const Text("Shares Outstanding"),
          trailing: Text(
              formatCompactNumber
                  .format(instrument.fundamentalsObj!.sharesOutstanding ?? 0),
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
          if (instrument.etpDetails["total_holdings"] != null) ...[
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
                Text(
                    formatNumber
                        .format(instrument.etpDetails["total_holdings"]),
                    style: const TextStyle(fontSize: 18)),
              ]),
            ),
          ],
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
          widget.brokerageUser,
          widget.service,
          Provider.of<DividendStore>(context, listen: false),
          Provider.of<InstrumentPositionStore>(context, listen: false),
          Provider.of<InstrumentOrderStore>(context, listen: false),
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
    final similar = instrument.similarObj!;
    final displayCount = _showAllSimilar
        ? similar.length
        : (similar.length > 3 ? 3 : similar.length);

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
        delegate: SliverChildBuilderDelegate((BuildContext context, int index) {
          return Card(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: Hero(
                    tag: 'logo_${similar[index]["symbol"]}',
                    child: similar[index]["logo_url"] != null
                        ? Image.network(
                            similar[index]["logo_url"]
                                .toString()
                                .replaceAll("https:////", "https://"),
                            width: 50,
                            height: 50,
                            errorBuilder: (BuildContext context,
                                Object exception, StackTrace? stackTrace) {
                              return CircleAvatar(
                                  radius: 25,
                                  child: Text(
                                    similar[index]["symbol"],
                                  ));
                            },
                          )
                        : CircleAvatar(
                            radius: 25,
                            child: Text(
                              similar[index]["symbol"],
                            ))),
                title: Text(
                  "${similar[index]["symbol"]}",
                ),
                subtitle: Text("${similar[index]["name"]}"),
                onTap: () async {
                  var similarInstruments = await widget.service
                      .getInstrumentsByIds(
                          widget.brokerageUser,
                          Provider.of<InstrumentStore>(context, listen: false),
                          [similar[index]["instrument_id"]]);
                  if (similar[index]["logo_url"] != null &&
                      similar[index]["logo_url"] !=
                          similarInstruments[0].logoUrl &&
                      auth.currentUser != null) {
                    similarInstruments[0].logoUrl = similar[index]["logo_url"]
                        .toString()
                        .replaceAll("https:////", "https://");
                    await _firestoreService
                        .upsertInstrument(similarInstruments[0]);
                  }
                  if (context.mounted) {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => InstrumentWidget(
                                  widget.brokerageUser,
                                  widget.service,
                                  similarInstruments[0],
                                  analytics: widget.analytics,
                                  observer: widget.observer,
                                  generativeService: widget.generativeService,
                                  user: widget.user,
                                  userDocRef: widget.userDocRef,
                                )));
                  }
                },
              ),
            ],
          ));
        }, childCount: displayCount),
      ),
      if (similar.length > 5)
        SliverToBoxAdapter(
            child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _showAllSimilar = !_showAllSimilar;
                });
              },
              icon:
                  Icon(_showAllSimilar ? Icons.expand_less : Icons.expand_more),
              label: Text(_showAllSimilar
                  ? 'Show Less'
                  : 'Show All (${similar.length})')),
        ))
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
                              widget.brokerageUser,
                              widget.service,
                              instrument.listsObj![index]["id"].toString(),
                              analytics: widget.analytics,
                              observer: widget.observer,
                              generativeService: widget.generativeService,
                              user: widget.user,
                              userDocRef: widget.userDocRef)));
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
                    "${positionOrders[index].side == "buy" ? "Buy" : positionOrders[index].side == "sell" ? "Sell" : positionOrders[index].side} ${positionOrders[index].quantity} at \$${positionOrders[index].averagePrice != null ? formatCompactNumber.format(positionOrders[index].averagePrice) : (positionOrders[index].price != null ? formatCompactNumber.format(positionOrders[index].price) : "")}"), // , style: TextStyle(fontSize: 18.0)),
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
                onTap: () {
                  positionOrders[index].instrumentObj = widget.instrument;
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => PositionOrderWidget(
                                widget.brokerageUser,
                                widget.service,
                                positionOrders[index],
                                analytics: widget.analytics,
                                observer: widget.observer,
                                generativeService: widget.generativeService,
                                user: widget.user,
                                userDocRef: widget.userDocRef,
                              )));
                },
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
                  label: const Text('Queued'),
                  selected: orderFilters.contains("queued"),
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        orderFilters.add("queued");
                      } else {
                        orderFilters.removeWhere((String name) {
                          return name == "queued";
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
    quoteObj ??= instrument.quoteObj;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(instrument.symbol,
                  style: const TextStyle(
                      fontSize: 16.0, fontWeight: FontWeight.bold)),
              if (instrument.simpleName != null || instrument.name != "")
                Text(
                  instrument.simpleName ?? instrument.name,
                  style: const TextStyle(fontSize: 12.0),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
            ],
          ),
        ),
        if (quoteObj != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                formatCurrency.format(quoteObj.lastExtendedHoursTradePrice ??
                    quoteObj.lastTradePrice),
                style: const TextStyle(
                    fontSize: 16.0, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
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
                      size: 14.0),
                  const SizedBox(width: 2),
                  Text(
                    formatPercentage.format(quoteObj.changePercentToday),
                    style: TextStyle(
                        fontSize: 12.0,
                        color: (quoteObj.changeToday > 0
                            ? Colors.lightGreenAccent
                            : (quoteObj.changeToday < 0
                                ? Colors.red
                                : Colors.grey))),
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildMultiIndicatorDisplay(Map<String, dynamic> multiIndicator) {
    final indicators = multiIndicator['indicators'] as Map<String, dynamic>?;
    if (indicators == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<AgenticTradingProvider>(
      builder: (context, agenticProvider, child) {
        final enabledIndicators = agenticProvider.config['enabledIndicators']
                as Map<String, dynamic>? ??
            {};
        final enabledCount =
            enabledIndicators.values.where((v) => v == true).length;

        // Recalculate signals based on only enabled indicators
        bool displayAllGreen = true;
        bool displayAllRed = true;
        if (enabledCount > 0) {
          for (final key in [
            'priceMovement',
            'momentum',
            'marketDirection',
            'volume',
            'macd',
            'bollingerBands',
            'stochastic',
            'atr',
            'obv',
            'vwap',
            'adx',
            'williamsR',
          ]) {
            if (enabledIndicators[key] == true) {
              final indicator = indicators[key] as Map<String, dynamic>?;
              final signal = indicator?['signal'];
              if (indicator == null || signal != 'BUY') {
                displayAllGreen = false;
              }
              if (indicator == null || signal != 'SELL') {
                displayAllRed = false;
              }
            }
          }
        } else {
          displayAllGreen = false;
          displayAllRed = false;
        }

        // Extract signal strength
        final signalStrength = multiIndicator['signalStrength'] as int?;

        final Color borderColor = displayAllGreen
            ? (isDark ? Colors.green.shade700 : Colors.green.shade200)
            : displayAllRed
                ? (isDark ? Colors.red.shade700 : Colors.red.shade200)
                : (isDark ? Colors.orange.shade700 : Colors.orange.shade200);

        return Container(
          margin: const EdgeInsets.only(top: 12.0),
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.grey.shade900.withOpacity(0.5)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: borderColor,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    size: 20,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Technical Indicators', // ($enabledCount/9 enabled)
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.info_outline,
                      size: 20,
                      color:
                          isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Indicator Documentation',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Technical Indicators'),
                          content: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildDocSection('priceMovement'),
                                _buildDocSection('momentum'),
                                _buildDocSection('marketDirection'),
                                _buildDocSection('volume'),
                                _buildDocSection('macd'),
                                _buildDocSection('bollingerBands'),
                                _buildDocSection('stochastic'),
                                _buildDocSection('atr'),
                                _buildDocSection('obv'),
                                _buildDocSection('vwap'),
                                _buildDocSection('adx'),
                                _buildDocSection('williamsR'),
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
                    },
                  ),
                ],
              ),
              // const SizedBox(height: 12),
              Column(
                children: [
                  _buildIndicatorRow(
                      'Price Movement',
                      'priceMovement',
                      indicators['priceMovement'] as Map<String, dynamic>?,
                      enabledIndicators['priceMovement'] == true),
                  _buildIndicatorRow(
                      'Momentum (RSI)',
                      'momentum',
                      indicators['momentum'] as Map<String, dynamic>?,
                      enabledIndicators['momentum'] == true),
                  _buildIndicatorRow(
                      'Market Direction',
                      'marketDirection',
                      indicators['marketDirection'] as Map<String, dynamic>?,
                      enabledIndicators['marketDirection'] == true),
                  _buildIndicatorRow(
                      'Volume',
                      'volume',
                      indicators['volume'] as Map<String, dynamic>?,
                      enabledIndicators['volume'] == true),
                  _buildIndicatorRow(
                      'MACD',
                      'macd',
                      indicators['macd'] as Map<String, dynamic>?,
                      enabledIndicators['macd'] == true),
                  _buildIndicatorRow(
                      'Bollinger Bands',
                      'bollingerBands',
                      indicators['bollingerBands'] as Map<String, dynamic>?,
                      enabledIndicators['bollingerBands'] == true),
                  _buildIndicatorRow(
                      'Stochastic',
                      'stochastic',
                      indicators['stochastic'] as Map<String, dynamic>?,
                      enabledIndicators['stochastic'] == true),
                  _buildIndicatorRow(
                      'ATR (Volatility)',
                      'atr',
                      indicators['atr'] as Map<String, dynamic>?,
                      enabledIndicators['atr'] == true),
                  _buildIndicatorRow(
                      'OBV (On-Balance Volume)',
                      'obv',
                      indicators['obv'] as Map<String, dynamic>?,
                      enabledIndicators['obv'] == true),
                  _buildIndicatorRow(
                      'VWAP',
                      'vwap',
                      indicators['vwap'] as Map<String, dynamic>?,
                      enabledIndicators['vwap'] == true),
                  _buildIndicatorRow(
                      'ADX (Trend Strength)',
                      'adx',
                      indicators['adx'] as Map<String, dynamic>?,
                      enabledIndicators['adx'] == true),
                  _buildIndicatorRow(
                      'Williams %R',
                      'williamsR',
                      indicators['williamsR'] as Map<String, dynamic>?,
                      enabledIndicators['williamsR'] == true),
                ],
              ),
              const SizedBox(height: 12),
              // Signal Strength gauge
              if (signalStrength != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.grey.shade800.withOpacity(0.5)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Signal Strength',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: isDark
                                  ? Colors.grey.shade300
                                  : Colors.grey.shade700,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getSignalStrengthColor(signalStrength)
                                  .withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.speed,
                                  size: 16,
                                  color:
                                      _getSignalStrengthColor(signalStrength),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$signalStrength/100',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color:
                                        _getSignalStrengthColor(signalStrength),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: signalStrength / 100,
                          minHeight: 8,
                          backgroundColor: isDark
                              ? Colors.grey.shade700
                              : Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getSignalStrengthColor(signalStrength),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Bearish',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.red.shade400,
                            ),
                          ),
                          Text(
                            'Neutral',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          Text(
                            'Bullish',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.green.shade400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: displayAllGreen
                      ? (isDark
                          ? Colors.green.withOpacity(0.25)
                          : Colors.green.withOpacity(0.15))
                      : displayAllRed
                          ? (isDark
                              ? Colors.red.withOpacity(0.25)
                              : Colors.red.withOpacity(0.15))
                          : (isDark
                              ? Colors.orange.withOpacity(0.25)
                              : Colors.orange.withOpacity(0.15)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      displayAllGreen
                          ? Icons.check_circle
                          : displayAllRed
                              ? Icons.cancel
                              : Icons.warning_amber_rounded,
                      color: displayAllGreen
                          ? (isDark
                              ? Colors.green.shade400
                              : Colors.green.shade800)
                          : displayAllRed
                              ? (isDark
                                  ? Colors.red.shade400
                                  : Colors.red.shade800)
                              : (isDark
                                  ? Colors.orange.shade400
                                  : Colors.orange.shade800),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      displayAllGreen
                          ? 'Overall: BUY'
                          : displayAllRed
                              ? 'Overall: SELL'
                              : 'Overall: ${multiIndicator['overallSignal'] ?? 'HOLD'}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: displayAllGreen
                            ? (isDark
                                ? Colors.green.shade400
                                : Colors.green.shade800)
                            : displayAllRed
                                ? (isDark
                                    ? Colors.red.shade400
                                    : Colors.red.shade800)
                                : (isDark
                                    ? Colors.orange.shade400
                                    : Colors.orange.shade800),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIndicatorRow(String name, String key,
      Map<String, dynamic>? indicator, bool isEnabled) {
    if (indicator == null) return const SizedBox.shrink();

    final signal = indicator['signal'] as String? ?? 'HOLD';
    final reason = indicator['reason'] as String? ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color signalColor;
    IconData signalIcon;

    switch (signal) {
      case 'BUY':
        signalColor = Colors.green;
        signalIcon = Icons.arrow_upward;
        break;
      case 'SELL':
        signalColor = Colors.red;
        signalIcon = Icons.arrow_downward;
        break;
      default:
        signalColor = Colors.grey;
        signalIcon = Icons.horizontal_rule;
    }

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.4,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isEnabled ? signalIcon : Icons.remove_circle_outline,
              color: isEnabled
                  ? signalColor
                  : (isDark ? Colors.grey.shade600 : Colors.grey.shade400),
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$name: ${isEnabled ? signal : 'DISABLED'}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isEnabled
                          ? signalColor
                          : (isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade600),
                    ),
                  ),
                  if (reason.isNotEmpty && isEnabled)
                    Text(
                      reason,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocSection(String key) {
    return IndicatorDocumentationWidget(
      indicatorKey: key,
      showContainer: false,
    );
  }

  /// Returns color based on signal strength value (0-100).
  /// 0-33: Red (bearish), 34-66: Grey (neutral), 67-100: Green (bullish)
  Color _getSignalStrengthColor(int strength) {
    if (strength >= 67) {
      return Colors.green;
    } else if (strength <= 33) {
      return Colors.red;
    } else {
      return Colors.grey;
    }
  }

  Widget _buildAgenticTradeSignals(Instrument instrument) {
    final symbol = instrument.symbol;
    return SliverToBoxAdapter(
      child: Column(
        children: [
          Consumer<TradeSignalsProvider>(
            builder: (context, provider, child) {
              final isMarketOpen = MarketHours.isMarketOpen();
              final selectedInterval = provider.selectedInterval;
              final intervalLabel = selectedInterval == '1d'
                  ? 'Daily'
                  : selectedInterval == '1h'
                      ? 'Hourly'
                      : selectedInterval == '15m'
                          ? '15-min'
                          : selectedInterval;

              return ListTile(
                title: const Text(
                  "Trade Signal",
                  style: TextStyle(fontSize: 19.0),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.history_outlined,
                        size: 20,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey.shade400
                            : Colors.grey.shade700,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Run Backtest',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => BacktestingWidget(
                              userDocRef: widget.userDocRef,
                              prefilledSymbol: widget.instrument.symbol,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        Icons.settings,
                        size: 20,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey.shade400
                            : Colors.grey.shade700,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Automated Trading',
                      onPressed: () async {
                        if (widget.user == null || widget.userDocRef == null) {
                          return;
                        }
                        final result = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => AgenticTradingSettingsWidget(
                              user: widget.user!,
                              userDocRef: widget.userDocRef!,
                            ),
                          ),
                        );
                        if (result == true && mounted) {
                          provider.fetchTradeSignal(widget.instrument.symbol,
                              interval: provider.selectedInterval);
                        }
                      },
                    ),
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      icon: Icon(
                        isMarketOpen ? Icons.access_time : Icons.calendar_today,
                        size: 20,
                        color: isMarketOpen
                            ? Colors.green.shade700
                            : Colors.blue.shade700,
                      ),
                      tooltip:
                          '${isMarketOpen ? 'Market Open' : 'After Hours'} • $intervalLabel',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      itemBuilder: (context) => [
                        PopupMenuItem<String>(
                          enabled: false,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(
                              isMarketOpen ? 'Market Open' : 'After Hours',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isMarketOpen
                                    ? Colors.green.shade700
                                    : Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem<String>(
                          value: '15m',
                          child: Row(
                            children: [
                              const Text('15-min'),
                              if (selectedInterval == '15m') ...[
                                const SizedBox(width: 8),
                                Icon(Icons.check,
                                    size: 18, color: Colors.green.shade700),
                              ],
                            ],
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: '1h',
                          child: Row(
                            children: [
                              const Text('Hourly'),
                              if (selectedInterval == '1h') ...[
                                const SizedBox(width: 8),
                                Icon(Icons.check,
                                    size: 18, color: Colors.green.shade700),
                              ],
                            ],
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: '1d',
                          child: Row(
                            children: [
                              const Text('Daily'),
                              if (selectedInterval == '1d') ...[
                                const SizedBox(width: 8),
                                Icon(Icons.check,
                                    size: 18, color: Colors.green.shade700),
                              ],
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        provider.setSelectedInterval(value);
                        provider.fetchTradeSignal(symbol, interval: value);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Consumer2<TradeSignalsProvider, AccountStore>(
            builder: (context, tradeSignalsProvider, accountStore, child) {
              final signal = tradeSignalsProvider.tradeSignal;
              if (signal == null || signal.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.signal_cellular_nodata,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "No trade signal found for this instrument.",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        _AgenticTradeButton(
                          instrument: instrument,
                          buildPortfolioState: () =>
                              _buildPortfolioState(context),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final timestamp = DateTime.fromMillisecondsSinceEpoch(
                  signal['timestamp'] as int);
              var signalType = signal['signal'] ?? 'HOLD';
              // String? recalculatedReason;
              final signalInterval = signal['interval'] ?? '1d';
              final assessment = signal['assessment'] as Map<String, dynamic>?;
              final multiIndicator =
                  signal['multiIndicatorResult'] as Map<String, dynamic>?;

              // // Recalculate overall signal based on enabled indicators
              // if (multiIndicator != null) {
              //   final indicators =
              //       multiIndicator['indicators'] as Map<String, dynamic>?;
              //   if (indicators != null) {
              //     final agenticTradingProvider =
              //         Provider.of<AgenticTradingProvider>(context,
              //             listen: false);
              //     final enabledIndicators =
              //         agenticTradingProvider.config['enabledIndicators']
              //                 as Map<String, dynamic>? ??
              //             {};
              //     final enabledCount =
              //         enabledIndicators.values.where((v) => v == true).length;

              //     if (enabledCount > 0) {
              //       final enabledSignals = <String>[];
              //       for (final key in [
              //         'priceMovement',
              //         'momentum',
              //         'marketDirection',
              //         'volume',
              //         'macd',
              //         'bollingerBands',
              //         'stochastic',
              //         'atr',
              //         'obv',
              //         'vwap',
              //         'adx',
              //         'williamsR',
              //       ]) {
              //         if (enabledIndicators[key] == true) {
              //           final indicator =
              //               indicators[key] as Map<String, dynamic>?;
              //           final sig = indicator?['signal'] as String?;
              //           if (sig != null) {
              //             enabledSignals.add(sig);
              //           }
              //         }
              //       }

              //       if (enabledSignals.isNotEmpty) {
              //         final allBuy = enabledSignals.every((s) => s == 'BUY');
              //         final allSell = enabledSignals.every((s) => s == 'SELL');
              //         final buyCount =
              //             enabledSignals.where((s) => s == 'BUY').length;
              //         final sellCount =
              //             enabledSignals.where((s) => s == 'SELL').length;
              //         final holdCount =
              //             enabledSignals.where((s) => s == 'HOLD').length;

              //         if (allBuy) {
              //           signalType = 'BUY';
              //           recalculatedReason =
              //               'All $enabledCount enabled indicators are GREEN - Strong BUY signal';
              //         } else if (allSell) {
              //           signalType = 'SELL';
              //           recalculatedReason =
              //               'All $enabledCount enabled indicators are RED - Strong SELL signal';
              //         } else {
              //           signalType = 'HOLD';
              //           recalculatedReason =
              //               'Mixed signals ($enabledCount enabled) - BUY: $buyCount, SELL: $sellCount, HOLD: $holdCount. Need all $enabledCount indicators aligned for action.';
              //         }
              //       }
              //     } else {
              //       signalType = 'HOLD';
              //       recalculatedReason =
              //           'No indicators enabled - cannot generate signal';
              //     }
              //   }
              // }

              // Determine signal color and icon
              Color signalColor;
              IconData signalIcon;
              switch (signalType) {
                case 'BUY':
                  signalColor = Colors.green;
                  signalIcon = Icons.trending_up;
                  break;
                case 'SELL':
                  signalColor = Colors.red;
                  signalIcon = Icons.trending_down;
                  break;
                default:
                  signalColor = Colors.grey;
                  signalIcon = Icons.trending_flat;
              }

              // Format interval label
              final intervalLabel = signalInterval == '1d'
                  ? 'Daily'
                  : signalInterval == '1h'
                      ? 'Hourly'
                      : signalInterval == '30m'
                          ? '30-min'
                          : signalInterval == '15m'
                              ? '15-min'
                              : signalInterval;

              return Card(
                elevation: 2,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // Header with signal badge and timestamp
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: signalColor.withOpacity(0.1),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Signal Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 8.0,
                                ),
                                decoration: BoxDecoration(
                                  color: signalColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      signalIcon,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      signalType,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Timestamp and interval
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    intervalLabel,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    formatCompactDateTimeWithHour
                                        .format(timestamp),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Reason section
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 20,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Analysis',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  // recalculatedReason ??
                                  signal['reason'] ?? 'No reason provided',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Multi-Indicator Display
                    if (multiIndicator != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                        child: _buildMultiIndicatorDisplay(multiIndicator),
                      ),

                    // Risk Assessment
                    if (assessment != null) ...[
                      const Divider(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              size: 20,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Risk Assessment',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Container(
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: assessment['approved'] == true
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: assessment['approved'] == true
                                  ? Colors.green.shade300
                                  : Colors.red.shade300,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    assessment['approved'] == true
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    color: assessment['approved'] == true
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    assessment['approved'] == true
                                        ? 'Trade Approved'
                                        : 'Trade Rejected',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: assessment['approved'] == true
                                          ? Colors.green.shade700
                                          : Colors.red.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              if (assessment['reason'] != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  assessment['reason'] ?? '',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Action Buttons
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _RiskGuardButton(
                            symbol: symbol,
                            signalType: signalType,
                            signal: signal,
                            assessment: assessment,
                            buildPortfolioState: () =>
                                _buildPortfolioState(context),
                          ),
                          const SizedBox(height: 8),
                          _AgenticTradeButton(
                            instrument: instrument,
                            buildPortfolioState: () =>
                                _buildPortfolioState(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Iterable<Widget> getHeaderWidgets(QuoteStore quoteStore) sync* {
    var instrument = widget.instrument;
    var quoteObj = quoteStore.items
        .firstWhereOrNull((element) => element.symbol == instrument.symbol);
    quoteObj ??= instrument.quoteObj;

    yield Padding(
      padding: const EdgeInsets.only(left: 10.0, right: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${instrument.name != "" ? instrument.name : instrument.simpleName}',
            style: TextStyle(
                fontSize: 16.0,
                color: Theme.of(context).appBarTheme.foregroundColor),
            textAlign: TextAlign.left,
          ),
          if (quoteObj != null) ...[
            const SizedBox(height: 4),
            Text(
              formatCurrency.format(quoteObj.lastTradePrice),
              style:
                  const TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
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
                const SizedBox(width: 4),
                Text(
                  formatPercentage.format(quoteObj.changePercentToday),
                  style: const TextStyle(fontSize: 16.0),
                ),
                const SizedBox(width: 8),
                Text(
                  "${quoteObj.changeToday > 0 ? "+" : quoteObj.changeToday < 0 ? "-" : ""}${formatCurrency.format(quoteObj.changeToday.abs())}",
                  style: const TextStyle(fontSize: 16.0),
                ),
              ],
            ),
            if (quoteObj.lastExtendedHoursTradePrice != null) ...[
              const SizedBox(height: 4),
              Text(
                "After Hours: ${formatCurrency.format(quoteObj.lastExtendedHoursTradePrice)}",
                style: const TextStyle(fontSize: 12.0, color: Colors.grey),
              ),
            ]
          ]
        ],
      ),
    );
  }
}

// Risk Guard Button Widget
class _RiskGuardButton extends StatefulWidget {
  final String symbol;
  final String signalType;
  final Map<String, dynamic> signal;
  final Map<String, dynamic>? assessment;
  final Map<String, dynamic> Function() buildPortfolioState;

  const _RiskGuardButton({
    required this.symbol,
    required this.signalType,
    required this.signal,
    required this.assessment,
    required this.buildPortfolioState,
  });

  @override
  State<_RiskGuardButton> createState() => _RiskGuardButtonState();
}

class _RiskGuardButtonState extends State<_RiskGuardButton> {
  bool _isAssessing = false;

  Future<void> _runRiskAssessment() async {
    if (_isAssessing) return;

    setState(() {
      _isAssessing = true;
    });

    try {
      final proposal = {
        'symbol': widget.symbol,
        'action': widget.signalType,
        'quantity': widget.signal['proposal']?['quantity'] ?? 1,
        'price': widget.signal['proposal']?['price'] ?? 0,
      };

      final portfolioState = widget.buildPortfolioState();

      final tradeSignalsProvider =
          Provider.of<TradeSignalsProvider>(context, listen: false);
      final agenticTradingProvider =
          Provider.of<AgenticTradingProvider>(context, listen: false);
      final result = await tradeSignalsProvider.assessTradeRisk(
        proposal: proposal,
        portfolioState: portfolioState,
        config: agenticTradingProvider.config,
      );

      // Update assessment in the signal and refresh UI
      widget.signal['assessment'] = result;
      if (mounted) {
        (context as Element).markNeedsBuild();
      }

      if (mounted) {
        await showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  result['approved']
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  color: result['approved'] ? Colors.green : Colors.red,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    result['approved']
                        ? 'Risk Assessment Passed'
                        : 'Risk Assessment Failed',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: result['approved']
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Status:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        result['approved'] ? 'Approved' : 'Rejected',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: result['approved']
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (result['reason'] != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Reason:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    result['reason'],
                    style: const TextStyle(fontSize: 15),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error running risk assessment: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAssessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
        ),
        icon: _isAssessing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.shield_outlined),
        label: Text(
          _isAssessing
              ? 'Assessing...'
              : (widget.assessment == null
                  ? 'Run Risk Guard'
                  : 'Re-assess Risk'),
          style: const TextStyle(fontSize: 16),
        ),
        onPressed: _isAssessing ? null : _runRiskAssessment,
      ),
    );
  }
}

class _AgenticTradeButton extends StatefulWidget {
  final Instrument instrument;
  final Map<String, dynamic> Function() buildPortfolioState;

  const _AgenticTradeButton({
    required this.instrument,
    required this.buildPortfolioState,
  });

  @override
  State<_AgenticTradeButton> createState() => _AgenticTradeButtonState();
}

class _AgenticTradeButtonState extends State<_AgenticTradeButton> {
  bool _isGenerating = false;

  Future<void> _generateTradeSignal(BuildContext context) async {
    if (_isGenerating) return;

    setState(() {
      _isGenerating = true;
    });

    try {
      final portfolioState = widget.buildPortfolioState();
      final price = widget.instrument.quoteObj?.lastExtendedHoursTradePrice ??
          widget.instrument.quoteObj?.lastTradePrice;

      if (price == null) {
        throw Exception('Unable to fetch current price');
      }

      // Generate new signal via initiateTradeProposal
      final tradeSignalsProvider =
          Provider.of<TradeSignalsProvider>(context, listen: false);
      final agenticTradingProvider =
          Provider.of<AgenticTradingProvider>(context, listen: false);
      await tradeSignalsProvider.initiateTradeProposal(
        symbol: widget.instrument.symbol,
        currentPrice: price,
        portfolioState: portfolioState,
        config: agenticTradingProvider.config,
      );

      // Wait briefly to ensure Firestore write has completed
      await Future.delayed(const Duration(milliseconds: 500));

      // Refresh the signal from Firestore
      await Provider.of<TradeSignalsProvider>(context, listen: false)
          .fetchTradeSignal(widget.instrument.symbol);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trade signal generated successfully!'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating signal: $e'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
        ),
        icon: _isGenerating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.auto_awesome),
        label: Text(
          _isGenerating ? 'Generating Signal...' : 'Generate Trade Signal',
          style: const TextStyle(fontSize: 16),
        ),
        onPressed: _isGenerating ? null : () => _generateTradeSignal(context),
      ),
    );
  }
}
