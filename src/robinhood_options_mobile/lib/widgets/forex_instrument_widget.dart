import 'dart:async';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
//import 'package:charts_flutter/flutter.dart' as charts;
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/forex_historicals.dart';
import 'package:robinhood_options_mobile/model/forex_holding.dart';
import 'package:robinhood_options_mobile/model/forex_holding_store.dart';
import 'package:robinhood_options_mobile/model/forex_quote.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals_selection_store.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/model/forex_order.dart';
import 'package:robinhood_options_mobile/widgets/forex_orders_widget.dart';
import 'package:robinhood_options_mobile/widgets/trade_forex_widget.dart';
import 'package:robinhood_options_mobile/widgets/disclaimer_widget.dart';
import 'package:robinhood_options_mobile/widgets/pnl_badge.dart';
import 'package:robinhood_options_mobile/widgets/sliverappbar_widget.dart';
import 'package:robinhood_options_mobile/widgets/chart_time_series_widget.dart';
import 'package:robinhood_options_mobile/model/instrument_historical.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';

class ForexInstrumentWidget extends StatefulWidget {
  const ForexInstrumentWidget(
    this.brokerageUser,
    this.service,
    //this.account,
    this.holding, {
    super.key,
    required this.analytics,
    required this.observer,
  });

  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  //final Account account;
  final ForexHolding holding;
  //final OptionAggregatePosition? optionPosition;

  @override
  State<ForexInstrumentWidget> createState() => _ForexInstrumentWidgetState();
}

class _ForexInstrumentWidgetState extends State<ForexInstrumentWidget>
    with AutomaticKeepAliveClientMixin<ForexInstrumentWidget> {
  final FirestoreService _firestoreService = FirestoreService();
  Future<dynamic>? futureQuote;
  Future<ForexHistoricals>? futureHistoricals;
  Future<List<ForexOrder>>? futureOrders;

  ChartDateSpan chartDateSpanFilter = ChartDateSpan.day;
  Bounds chartBoundsFilter = Bounds.t24_7; //regular

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
          widget.service.getForexQuote(widget.brokerageUser, forexPair['id']);
    } else {
      futureQuote ??= Future.value(widget.holding.quoteObj);
    }

    futureOrders ??= widget.service.getForexOrders(widget.brokerageUser);

    return Scaffold(
        body: FutureBuilder(
      future: futureQuote,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          widget.holding.quoteObj = snapshot.data! as ForexQuote;

          futureHistoricals ??= widget.service.getForexHistoricals(
              widget.brokerageUser, widget.holding.quoteObj!.id,
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

  RefreshIndicator buildScrollView(ForexHolding holding, {bool done = false}) {
    var slivers = <Widget>[];
    slivers.add(SliverLayoutBuilder(
      builder: (BuildContext context, constraints) {
        const expandedHeight = 180.0;
        final scrolled =
            math.min(expandedHeight, constraints.scrollOffset) / expandedHeight;
        final t = (1 - scrolled).clamp(0.0, 1.0);
        final opacity = 1.0 - Interval(0, 1).transform(t);

        return SliverAppBar(
          centerTitle: false,
          title: Opacity(
            opacity: opacity,
            child: headerTitle(holding),
          ),
          expandedHeight: 240,
          floating: false,
          pinned: true,
          snap: false,
          flexibleSpace: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
            final settings = context
                .dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
            final deltaExtent = settings!.maxExtent - settings.minExtent;
            final t = (1.0 -
                    (settings.currentExtent - settings.minExtent) / deltaExtent)
                .clamp(0.0, 1.0);
            final fadeStart =
                math.max(0.0, 1.0 - kToolbarHeight * 2 / deltaExtent);
            const fadeEnd = 1.0;
            final opacity = 1.0 - Interval(fadeStart, fadeEnd).transform(t);
            return FlexibleSpaceBar(
                background: Hero(
                    tag: 'logo_crypto_${holding.currencyCode}',
                    child: SizedBox(child: Container() // Placeholder for logo
                        )),
                title: Opacity(
                  opacity: opacity,
                  child: SingleChildScrollView(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: headerWidgets.toList())),
                ));
          }),
          actions: [
            IconButton(
                icon: auth.FirebaseAuth.instance.currentUser != null
                    ? (auth.FirebaseAuth.instance.currentUser!.photoURL == null
                        ? const Icon(Icons.account_circle)
                        : CircleAvatar(
                            maxRadius: 12,
                            backgroundImage: CachedNetworkImageProvider(auth
                                .FirebaseAuth.instance.currentUser!.photoURL!)))
                    : const Icon(Icons.login),
                onPressed: () async {
                  var response = await showProfile(
                      context,
                      auth.FirebaseAuth.instance,
                      _firestoreService,
                      widget.analytics,
                      widget.observer,
                      widget.brokerageUser,
                      widget.service);
                  if (response != null) {
                    setState(() {});
                  }
                }),
          ],
        );
      },
    ));

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

    slivers.add(ForexChartWidget(
      holding: holding,
      chartDateSpanFilter: chartDateSpanFilter,
      chartBoundsFilter: chartBoundsFilter,
      onFilterChanged: (span, bounds) {
        resetChart(span, bounds);
      },
    ));
    // slivers.add(
    //   const SliverToBoxAdapter(
    //       child: SizedBox(
    //     height: 8.0,
    //   )),
    // );
    slivers.add(quoteWidget(holding));

    //if (holding != null) {
    slivers.add(SliverToBoxAdapter(
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      ListTile(
          title: const Text("Position",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          subtitle: Text(
              '${formatNumber.format(holding.quantity!)} ${holding.currencyCode}'),
          trailing: Text(formatCurrency.format(holding.marketValue),
              style: const TextStyle(fontSize: 21))),
      _buildDetailScrollRow(holding, 16, 14, iconSize: 23.0),
    ])));
    //}

    if (holding.quoteObj != null) {
      slivers.add(FutureBuilder(
        future: futureOrders,
        builder: (context, AsyncSnapshot<List<ForexOrder>> snapshot) {
          if (snapshot.hasData) {
            var orders = snapshot.data!;
            orders = orders
                .where((o) => o.currencyPairId == holding.quoteObj!.id)
                .toList();
            if (orders.isNotEmpty) {
              return ForexOrdersWidget(
                widget.brokerageUser,
                widget.service,
                orders,
                analytics: widget.analytics,
                observer: widget.observer,
              );
            }
          }
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        },
      ));
    }

    slivers.add(const SliverToBoxAdapter(
        child: SizedBox(
      height: 25.0,
    )));
    slivers.add(const SliverToBoxAdapter(child: DisclaimerWidget()));
    slivers.add(const SliverToBoxAdapter(
        child: SizedBox(
      height: 25.0,
    )));

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
        if (widget.brokerageUser.refreshEnabled) {
          if (widget.holding.historicalsObj != null) {
            setState(() {
              widget.holding.historicalsObj = null;
              futureHistoricals = null;
            });
          }
          var holdings = await widget.service.refreshNummusHoldings(
              widget.brokerageUser,
              Provider.of<ForexHoldingStore>(context, listen: false));

          var updatedHolding = holdings
              .firstWhereOrNull((element) => element.id == widget.holding.id);
          if (updatedHolding != null && mounted) {
            setState(() {
              widget.holding.quoteObj = updatedHolding.quoteObj;
              futureQuote = Future.value(widget.holding.quoteObj);
            });
          }
        }
      },
    );
  }

  void _stopRefreshTimer() {
    if (refreshTriggerTime != null) {
      refreshTriggerTime!.cancel();
    }
  }

  Widget buildOverview(ForexHolding holding) {
    if (holding.quoteObj == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: <Widget>[
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8)),
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Buy'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TradeForexWidget(
                    widget.brokerageUser,
                    widget.service,
                    analytics: widget.analytics,
                    observer: widget.observer,
                    holding: holding,
                    positionType: "Buy",
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8)),
              icon: const Icon(Icons.remove, size: 20),
              label: const Text('Sell'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TradeForexWidget(
                    widget.brokerageUser,
                    widget.service,
                    analytics: widget.analytics,
                    observer: widget.observer,
                    holding: holding,
                    positionType: "Sell",
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget quoteWidget(ForexHolding holding) {
    return SliverToBoxAdapter(
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      ListTile(
        title: const Text(
          "Quote",
          style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
        ),
        trailing: Text(
          holding.quoteObj!.markPrice! < 0.001
              ? NumberFormat.simpleCurrency(decimalDigits: 8)
                  .format(holding.quoteObj!.markPrice)
              : formatCurrency.format(holding.quoteObj!.markPrice),
          style: const TextStyle(fontSize: 21.0),
          textAlign: TextAlign.right,
        ),
      ),
      _buildQuoteScrollRow(holding, 16, 14, iconSize: 23.0),
      Container(
        height: 10,
      )
    ]));
  }

  SingleChildScrollView _buildQuoteScrollRow(
      ForexHolding holding, double valueFontSize, double labelFontSize,
      {double iconSize = 23.0}) {
    List<Widget> tiles = [];

    double? todayReturn = holding.quoteObj!.changeToday;
    String? todayReturnText = formatCurrency.format(todayReturn);

    double? todayReturnPercent = holding.quoteObj!.changePercentToday;
    String? todayReturnPercentText =
        formatPercentage.format(todayReturnPercent);

    tiles = [
      Padding(
          padding: const EdgeInsets.all(summaryEgdeInset),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            PnlBadge(
                text: todayReturnText,
                value: todayReturn,
                fontSize: valueFontSize),
            Text("Change Today", style: TextStyle(fontSize: labelFontSize))
          ])),
      Padding(
          padding: const EdgeInsets.all(summaryEgdeInset),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            PnlBadge(
                text: todayReturnPercentText,
                value: todayReturnPercent,
                fontSize: valueFontSize),
            Text("Change Today %", style: TextStyle(fontSize: labelFontSize))
          ])),
      Padding(
          padding: const EdgeInsets.all(summaryEgdeInset),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            PnlBadge(
                text: holding.quoteObj!.bidPrice! < 0.001
                    ? NumberFormat.simpleCurrency(decimalDigits: 8)
                        .format(holding.quoteObj!.bidPrice)
                    : formatCurrency.format(holding.quoteObj!.bidPrice),
                fontSize: valueFontSize,
                neutral: true),
            Text("Bid", style: TextStyle(fontSize: labelFontSize))
          ])),
      Padding(
          padding: const EdgeInsets.all(summaryEgdeInset),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            PnlBadge(
                text: holding.quoteObj!.askPrice! < 0.001
                    ? NumberFormat.simpleCurrency(decimalDigits: 8)
                        .format(holding.quoteObj!.askPrice)
                    : formatCurrency.format(holding.quoteObj!.askPrice),
                fontSize: valueFontSize,
                neutral: true),
            Text("Ask", style: TextStyle(fontSize: labelFontSize))
          ])),
      Padding(
          padding: const EdgeInsets.all(summaryEgdeInset),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            PnlBadge(
                text: holding.quoteObj!.openPrice! < 0.001
                    ? NumberFormat.simpleCurrency(decimalDigits: 8)
                        .format(holding.quoteObj!.openPrice)
                    : formatCurrency.format(holding.quoteObj!.openPrice),
                fontSize: valueFontSize,
                neutral: true),
            Text("Open", style: TextStyle(fontSize: labelFontSize))
          ])),
      Padding(
          padding: const EdgeInsets.all(summaryEgdeInset),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            PnlBadge(
                text: holding.quoteObj!.highPrice! < 0.001
                    ? NumberFormat.simpleCurrency(decimalDigits: 8)
                        .format(holding.quoteObj!.highPrice)
                    : formatCurrency.format(holding.quoteObj!.highPrice),
                fontSize: valueFontSize,
                neutral: true),
            Text("High", style: TextStyle(fontSize: labelFontSize))
          ])),
      Padding(
          padding: const EdgeInsets.all(summaryEgdeInset),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            PnlBadge(
                text: holding.quoteObj!.lowPrice! < 0.001
                    ? NumberFormat.simpleCurrency(decimalDigits: 8)
                        .format(holding.quoteObj!.lowPrice)
                    : formatCurrency.format(holding.quoteObj!.lowPrice),
                fontSize: valueFontSize,
                neutral: true),
            Text("Low", style: TextStyle(fontSize: labelFontSize))
          ])),
      Padding(
          padding: const EdgeInsets.all(summaryEgdeInset),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            PnlBadge(
                text: formatCompactNumber.format(holding.quoteObj!.volume),
                fontSize: valueFontSize,
                neutral: true),
            Text("Volume", style: TextStyle(fontSize: labelFontSize))
          ]))
    ];

    return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: tiles)));
  }

  Widget headerTitle(ForexHolding holding) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(holding.currencyCode,
                  style: const TextStyle(
                      fontSize: 16.0, fontWeight: FontWeight.bold)),
              Text(
                holding.currencyName,
                style: const TextStyle(fontSize: 12.0),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
        if (holding.quoteObj != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                holding.quoteObj!.markPrice! < 0.001
                    ? NumberFormat.simpleCurrency(decimalDigits: 8)
                        .format(holding.quoteObj!.markPrice)
                    : formatCurrency.format(holding.quoteObj!.markPrice),
                style: const TextStyle(
                    fontSize: 16.0, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  Text(
                    formatPercentage
                        .format(holding.quoteObj!.changePercentToday),
                    style: TextStyle(
                        fontSize: 12.0,
                        color: holding.quoteObj!.changeToday > 0
                            ? (Theme.of(context).brightness == Brightness.light
                                ? Colors.green
                                : Colors.lightGreenAccent)
                            : (holding.quoteObj!.changeToday < 0
                                ? Colors.red
                                : Colors.grey)),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "${holding.quoteObj!.changeToday > 0 ? "+" : holding.quoteObj!.changeToday < 0 ? "-" : ""}${holding.quoteObj!.markPrice! < 0.001 ? NumberFormat.simpleCurrency(decimalDigits: 8).format(holding.quoteObj!.changeToday.abs()) : formatCurrency.format(holding.quoteObj!.changeToday.abs())}",
                    style: TextStyle(
                        fontSize: 12.0,
                        color: holding.quoteObj!.changeToday > 0
                            ? (Theme.of(context).brightness == Brightness.light
                                ? Colors.green
                                : Colors.lightGreenAccent)
                            : (holding.quoteObj!.changeToday < 0
                                ? Colors.red
                                : Colors.grey)),
                  ),
                ],
              ),
            ],
          )
      ],
    );
  }

  Iterable<Widget> get headerWidgets sync* {
    var holding = widget.holding;
    yield Padding(
      padding: const EdgeInsets.only(left: 10.0, right: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            holding.currencyName,
            style: TextStyle(
                fontSize: 16.0,
                color: Theme.of(context).appBarTheme.foregroundColor),
            textAlign: TextAlign.left,
          ),
          if (holding.quoteObj != null) ...[
            const SizedBox(height: 4),
            Text(
              holding.quoteObj!.markPrice! < 0.001
                  ? NumberFormat.simpleCurrency(decimalDigits: 8)
                      .format(holding.quoteObj!.markPrice)
                  : formatCurrency.format(holding.quoteObj!.markPrice),
              style: TextStyle(
                  fontSize: 24.0,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).appBarTheme.foregroundColor),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                    holding.quoteObj!.changeToday > 0
                        ? Icons.trending_up
                        : (holding.quoteObj!.changeToday < 0
                            ? Icons.trending_down
                            : Icons.trending_flat),
                    color: (holding.quoteObj!.changeToday > 0
                        ? (Theme.of(context).brightness == Brightness.light
                            ? Colors.green
                            : Colors.lightGreenAccent)
                        : (holding.quoteObj!.changeToday < 0
                            ? Colors.red
                            : Colors.grey)),
                    size: 20.0),
                const SizedBox(width: 4),
                Text(
                  formatPercentage.format(holding.quoteObj!.changePercentToday),
                  style: TextStyle(
                      fontSize: 16.0,
                      color: Theme.of(context).appBarTheme.foregroundColor),
                ),
                const SizedBox(width: 8),
                Text(
                  "${holding.quoteObj!.changeToday > 0 ? "+" : holding.quoteObj!.changeToday < 0 ? "-" : ""}${holding.quoteObj!.markPrice! < 0.001 ? NumberFormat.simpleCurrency(decimalDigits: 8).format(holding.quoteObj!.changeToday.abs()) : formatCurrency.format(holding.quoteObj!.changeToday.abs())}",
                  style: TextStyle(
                      fontSize: 16.0,
                      color: Theme.of(context).appBarTheme.foregroundColor),
                ),
              ],
            ),
          ]
        ],
      ),
    );
  }

  SingleChildScrollView _buildDetailScrollRow(
      ForexHolding holding, double valueFontSize, double labelFontSize,
      {double iconSize = 23.0}) {
    List<Widget> tiles = [];

    double? totalReturn = holding.gainLoss;
    String? totalReturnText = formatCurrency.format(totalReturn);

    double? totalReturnPercent = holding.gainLossPercent;
    String? totalReturnPercentText =
        formatPercentage.format(totalReturnPercent);

    double? todayReturn = holding.quoteObj!.changeToday * holding.quantity!;
    String? todayReturnText = formatCurrency.format(todayReturn);

    double? todayReturnPercent = holding.quoteObj!.changePercentToday;
    String? todayReturnPercentText =
        formatPercentage.format(todayReturnPercent);

    tiles = [
      Padding(
          padding: const EdgeInsets.all(summaryEgdeInset),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            PnlBadge(
                text: todayReturnText,
                value: todayReturn,
                fontSize: valueFontSize),
            Text("Return Today", style: TextStyle(fontSize: labelFontSize))
          ])),
      Padding(
          padding: const EdgeInsets.all(summaryEgdeInset),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            PnlBadge(
                text: todayReturnPercentText,
                value: todayReturnPercent,
                fontSize: valueFontSize),
            Text("Return Today %", style: TextStyle(fontSize: labelFontSize))
          ])),
      Padding(
          padding: const EdgeInsets.all(summaryEgdeInset),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            PnlBadge(
                text: totalReturnText,
                value: totalReturn,
                fontSize: valueFontSize),
            Text("Total Return", style: TextStyle(fontSize: labelFontSize))
          ])),
      Padding(
          padding: const EdgeInsets.all(summaryEgdeInset),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            PnlBadge(
                text: totalReturnPercentText,
                value: totalReturnPercent,
                fontSize: valueFontSize),
            Text("Total Return %", style: TextStyle(fontSize: labelFontSize))
          ])),
      Padding(
          padding: const EdgeInsets.all(summaryEgdeInset),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            PnlBadge(
                text: holding.averageCost < 0.001
                    ? NumberFormat.simpleCurrency(decimalDigits: 8)
                        .format(holding.averageCost)
                    : formatCurrency.format(holding.averageCost),
                fontSize: valueFontSize,
                neutral: true),
            Text("Average Cost", style: TextStyle(fontSize: labelFontSize))
          ])),
      Padding(
          padding: const EdgeInsets.all(summaryEgdeInset),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            PnlBadge(
                text: formatCurrency.format(holding.totalCost),
                fontSize: valueFontSize,
                neutral: true),
            Text("Total Cost", style: TextStyle(fontSize: labelFontSize))
          ])),
    ];

    return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: tiles)));
  }
}

class ForexChartWidget extends StatefulWidget {
  final ForexHolding holding;
  final ChartDateSpan chartDateSpanFilter;
  final Bounds chartBoundsFilter;
  final Function(ChartDateSpan, Bounds) onFilterChanged;

  const ForexChartWidget({
    super.key,
    required this.holding,
    required this.chartDateSpanFilter,
    required this.chartBoundsFilter,
    required this.onFilterChanged,
  });

  @override
  State<ForexChartWidget> createState() => _ForexChartWidgetState();
}

class _ForexChartWidgetState extends State<ForexChartWidget> {
  TimeSeriesChart? chart;
  InstrumentHistorical? selection;

  @override
  Widget build(BuildContext context) {
    if (widget.holding.historicalsObj != null &&
        widget.holding.historicalsObj!.historicals.isNotEmpty) {
      InstrumentHistorical? firstHistorical;
      InstrumentHistorical? lastHistorical;
      double open = 0;
      double close = 0;
      double changeInPeriod = 0;
      double changePercentInPeriod = 0;

      firstHistorical = widget.holding.historicalsObj!.historicals[0];
      lastHistorical = widget.holding.historicalsObj!
          .historicals[widget.holding.historicalsObj!.historicals.length - 1];
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
          data: widget.holding.historicalsObj!.historicals,
        ),
        charts.Series<InstrumentHistorical, DateTime>(
          id: 'Close',
          colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
          domainFn: (InstrumentHistorical history, _) => history.beginsAt!,
          measureFn: (InstrumentHistorical history, _) => history.closePrice,
          data: widget.holding.historicalsObj!.historicals,
        ),
        charts.Series<InstrumentHistorical, DateTime>(
            id: 'Volume',
            colorFn: (_, __) => charts.MaterialPalette.cyan.shadeDefault,
            domainFn: (InstrumentHistorical history, _) => history.beginsAt!,
            measureFn: (InstrumentHistorical history, _) => history.volume,
            data: widget.holding.historicalsObj!.historicals),
        charts.Series<InstrumentHistorical, DateTime>(
          id: 'Low',
          colorFn: (_, __) => charts.MaterialPalette.red.shadeDefault,
          domainFn: (InstrumentHistorical history, _) => history.beginsAt!,
          measureFn: (InstrumentHistorical history, _) => history.lowPrice,
          data: widget.holding.historicalsObj!.historicals,
        ),
        charts.Series<InstrumentHistorical, DateTime>(
          id: 'High',
          colorFn: (_, __) => charts.MaterialPalette.green.shadeDefault,
          domainFn: (InstrumentHistorical history, _) => history.beginsAt!,
          measureFn: (InstrumentHistorical history, _) => history.highPrice,
          data: widget.holding.historicalsObj!.historicals,
        ),
      ];
      var extents = charts.NumericExtents.fromValues(
          seriesList[0].data.map((e) => e.openPrice!));
      extents = charts.NumericExtents(extents.min - (extents.width * 0.1),
          extents.max + (extents.width * 0.1));
      var provider = Provider.of<InstrumentHistoricalsSelectionStore>(context,
          listen: false);

      chart = TimeSeriesChart(seriesList,
          open: open,
          close: close,
          seriesLegend: charts.SeriesLegend(
            horizontalFirst: true,
            position: charts.BehaviorPosition.top,
            defaultHiddenSeries: const ["Close", "Volume", "Low", "High"],
            showMeasures: true,
            measureFormatter: (measure) =>
                measure != null ? formatCurrency.format(measure) : '',
          ), onSelected: (charts.SelectionModel<DateTime>? historical) {
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

      return SliverToBoxAdapter(
          child: Column(
        children: [
          SizedBox(
              height: 340,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: chart,
              )),
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
                          close < 0.001
                              ? NumberFormat.simpleCurrency(decimalDigits: 8)
                                  .format(selection != null
                                      ? selection!.closePrice
                                      : close)
                              : formatCurrency.format(selection != null
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
                            : (changeInPeriod < 0 ? Colors.red : Colors.grey)),
                      ),
                      Container(
                        width: 2,
                      ),
                      Text(formatPercentage.format(changePercentInPeriod.abs()),
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
                key: const PageStorageKey<String>('forexChartFilters'),
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
                  ]);
                },
                itemCount: 1,
              ))
        ],
      ));
    }
    return SliverToBoxAdapter(
        child: Column(
      children: [
        const SizedBox(
            height: 340,
            child: Center(child: CircularProgressIndicator.adaptive())),
        SizedBox(
            height: 56,
            child: ListView.builder(
              key: const PageStorageKey<String>('forexChartFilters'),
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
                ]);
              },
              itemCount: 1,
            ))
      ],
    ));
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
}
