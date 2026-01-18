import 'dart:async';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
//import 'package:charts_flutter/flutter.dart' as charts;
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/main.dart';

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
import 'package:robinhood_options_mobile/model/options_flow_store.dart';
import 'package:robinhood_options_mobile/widgets/ad_banner_widget.dart';
import 'package:robinhood_options_mobile/widgets/disclaimer_widget.dart';
import 'package:robinhood_options_mobile/widgets/option_orders_widget.dart';
//import 'package:firebase_ai/firebase_ai.dart';

import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/widgets/animated_price_text.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/chart_time_series_widget.dart';
import 'package:robinhood_options_mobile/widgets/option_chain_widget.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';
import 'package:robinhood_options_mobile/widgets/sliverappbar_widget.dart';
import 'package:robinhood_options_mobile/widgets/option_flow_list_item.dart';
import 'package:robinhood_options_mobile/widgets/trade_option_widget.dart';

class OptionInstrumentWidget extends StatefulWidget {
  const OptionInstrumentWidget(
      this.brokerageUser,
      this.service,
      //this.account,
      this.optionInstrument,
      {super.key,
      required this.analytics,
      required this.observer,
      required this.generativeService,
      this.optionPosition,
      this.heroTag,
      required this.user,
      required this.userDocRef});

  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  final GenerativeService generativeService;
  //final Account account;
  final OptionInstrument optionInstrument;
  final OptionAggregatePosition? optionPosition;
  final String? heroTag;
  final User? user;
  final DocumentReference<User>? userDocRef;

  @override
  State<OptionInstrumentWidget> createState() => _OptionInstrumentWidgetState();
}

class _OptionInstrumentWidgetState extends State<OptionInstrumentWidget> {
  final FirestoreService _firestoreService = FirestoreService();

  Future<Quote>? futureQuote;
  Future<Instrument>? futureInstrument;
  Future<List<OptionOrder>>? futureOptionOrders;
  Future<OptionHistoricals>? futureHistoricals;

  ChartDateSpan chartDateSpanFilter = ChartDateSpan.day;
  Bounds chartBoundsFilter = Bounds.regular;
  InstrumentHistorical? selection;

  Timer? refreshTriggerTime;

  @override
  void initState() {
    super.initState();

    _startRefreshTimer();
    widget.analytics.logScreenView(
      screenName:
          'OptionInstrument/${widget.optionInstrument.chainSymbol}/${widget.optionPosition != null ? widget.optionPosition!.strategy.split('_').first : ''}/${widget.optionInstrument.type}/${widget.optionInstrument.strikePrice}/${widget.optionInstrument.expirationDate}',
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
      futureOptionOrders = widget.service.getOptionOrders(widget.brokerageUser,
          optionOrderStore, widget.optionInstrument.chainId);
    }

    var quoteStore = Provider.of<QuoteStore>(context, listen: false);
    var cachedQuotes = quoteStore.items.where(
        (element) => element.symbol == widget.optionInstrument.chainSymbol);
    if (cachedQuotes.isNotEmpty) {
      futureQuote = Future.value(cachedQuotes.first);
    } else {
      futureQuote ??= widget.service.getQuote(widget.brokerageUser, quoteStore,
          widget.optionInstrument.chainSymbol);
    }

    futureHistoricals ??= widget.service.getOptionHistoricals(
        widget.brokerageUser,
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
              futureInstrument ??= widget.service.getInstrument(
                  widget.brokerageUser,
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

  Widget _buildExpirationSection(
      BuildContext context, int dte, int originalDte) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ListTile(
            title: Text("Expiration", style: TextStyle(fontSize: 20)),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0).copyWith(top: 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      LinearProgressIndicator(
                        value: originalDte > 0
                            ? (dte / originalDte).clamp(0.0, 1.0)
                            : 1.0,
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(5),
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          dte < 5
                              ? Colors.red
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Today",
                              style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      Theme.of(context).colorScheme.outline)),
                          Text(
                              formatDate.format(
                                  widget.optionInstrument.expirationDate!),
                              style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      Theme.of(context).colorScheme.outline)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Column(
                  children: [
                    Text(
                      "$dte",
                      style: const TextStyle(
                          fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    Text("days left",
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.outline)),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
      BuildContext context, String value, String symbol, String label) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(value,
              style:
                  const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(symbol,
              style: TextStyle(
                  fontSize: 15.0,
                  color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 10.0,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
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
    if (optionInstrument.createdAt != null) {
      DateTime createdAt = DateTime(optionInstrument.createdAt!.year,
          optionInstrument.createdAt!.month, optionInstrument.createdAt!.day);
      if (optionPosition != null) {
        createdAt = DateTime(optionPosition.createdAt!.year,
            optionPosition.createdAt!.month, optionPosition.createdAt!.day);
      }
      originalDte =
          optionInstrument.expirationDate!.difference(createdAt).inDays;
    }

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
                    child: _buildOverview(
                        widget.brokerageUser, optionInstrument, instrument,
                        optionPosition: optionPosition))),
            const SliverToBoxAdapter(
                child: SizedBox(
              height: 12,
            )),
          ],
          _buildHistoricalChartSection(optionInstrument),
          if (instrument != null)
            _buildOptionFlowAnalysis(optionInstrument, instrument),
          _buildGreeksSection(optionInstrument),
          SliverToBoxAdapter(
              child: _buildExpirationSection(context, dte, originalDte)),
          SliverToBoxAdapter(child: _buildMarketDataCard(optionInstrument)),
          SliverToBoxAdapter(
              child: _buildPositionCard(
                  optionInstrument, optionPosition, dte, originalDte)),
          if (optionPosition != null && optionPosition.legs.length > 1) ...[
            SliverToBoxAdapter(
                child: Card(
                    child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _buildLegs(optionPosition),
            ))),
          ],
          if (optionInstrumentOrders != null &&
              optionInstrumentOrders.isNotEmpty) ...[
            OptionOrdersWidget(
              widget.brokerageUser,
              widget.service,
              optionInstrumentOrders,
              const [],
              analytics: widget.analytics,
              observer: widget.observer,
              generativeService: widget.generativeService,
              authUser: widget.user,
              userDocRef: widget.userDocRef,
            ),
          ],
          if (!kIsWeb) ...[
            const SliverToBoxAdapter(
                child: SizedBox(
              height: 25.0,
            )),
            SliverToBoxAdapter(
                child: AdBannerWidget(size: AdSize.mediumRectangle)),
          ],
          const SliverToBoxAdapter(
              child: SizedBox(
            height: 25.0,
          )),
          const SliverToBoxAdapter(child: DisclaimerWidget()),
          const SliverToBoxAdapter(
              child: SizedBox(
            height: 25.0,
          ))
        ]));
  }

  Widget _buildPositionCard(OptionInstrument optionInstrument,
      OptionAggregatePosition? optionPosition, int dte, int originalDte) {
    if (optionPosition == null) return Container();

    var isLong = optionPosition.legs.first.positionType == "long";
    var quantity = optionPosition.quantity!.abs();

    // ITM/OTM Logic
    bool? isItm;
    if (optionInstrument.optionMarketData != null &&
        optionInstrument.optionMarketData!.adjustedMarkPrice != null &&
        optionInstrument.strikePrice != null) {
      final mark = optionInstrument.optionMarketData!.adjustedMarkPrice!;
      final strike = optionInstrument.strikePrice!;
      if (optionInstrument.type == 'call') {
        isItm = mark > strike;
      } else {
        isItm = mark < strike;
      }
    }

    // Position Break Even Logic
    double? positionBreakEven;
    if (optionInstrument.strikePrice != null &&
        optionPosition.averageOpenPrice != null) {
      // averageOpenPrice is total cost per contract (x100), so divide by 100 for per-share math
      double avgPerShare = optionPosition.averageOpenPrice! / 100;
      if (optionInstrument.type == 'call') {
        positionBreakEven = optionInstrument.strikePrice! + avgPerShare;
      } else {
        // Put: Strike - Premium
        positionBreakEven = optionInstrument.strikePrice! - avgPerShare;
      }
    }

    double? dayGainLoss;
    double? dayGainLossPercent;
    if (optionInstrument.optionMarketData != null) {
      final change = optionInstrument.optionMarketData!.changeToday;
      final changePct = optionInstrument.optionMarketData!.changePercentToday;
      dayGainLoss = (isLong ? 1 : -1) * change * quantity * 100;
      dayGainLossPercent = (isLong ? 1 : -1) * changePct;
    }

    return Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withOpacity(0.5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text("Position",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      if (isItm != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isItm
                                ? Colors.green.withOpacity(0.2)
                                : Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: isItm
                                    ? Colors.green
                                    : Colors.grey.withOpacity(0.5),
                                width: 1),
                          ),
                          child: Text(
                            isItm ? "ITM" : "OTM",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isItm
                                  ? Colors.green
                                  : Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                      "${formatCompactNumber.format(quantity)}x ${optionPosition.legs.first.positionType} @ ${formatCurrency.format(optionInstrument.strikePrice)}",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary)),
                ],
              ),
            ),
            Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildReturnBlock(
                          context,
                          "Total Return",
                          optionPosition.gainLoss,
                          optionPosition.gainLossPercent,
                          large: true),
                    ),
                    const SizedBox(width: 12),
                    Container(
                        width: 1,
                        height: 40,
                        color: Theme.of(context).dividerColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildReturnBlock(context, "Today's Return",
                          dayGainLoss, dayGainLossPercent,
                          large: true),
                    ),
                  ],
                )),
            const Divider(height: 1),
            Padding(
                padding: const EdgeInsets.all(16.0),
                child: LayoutBuilder(builder: (context, constraints) {
                  final width = (constraints.maxWidth - 24) / 3;
                  return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.start,
                      children: [
                        _buildStatCard(context, "Market Value",
                            formatCurrency.format(optionPosition.marketValue),
                            width: width),
                        _buildStatCard(
                            context,
                            isLong ? "Avg Price" : "Avg Credit",
                            formatCurrency
                                .format(optionPosition.averageOpenPrice! / 100),
                            width: width),
                        _buildStatCard(
                            context,
                            "Total ${isLong ? 'Cost' : 'Credit'}",
                            formatCurrency.format(optionPosition.totalCost),
                            width: width),
                        if (positionBreakEven != null)
                          _buildStatCard(context, "Break Even",
                              formatCurrency.format(positionBreakEven),
                              width: width),
                        _buildStatCard(context, "Expires",
                            "${dte.isNegative ? 0 : dte} days",
                            textColor:
                                dte < 5 && !dte.isNegative ? Colors.red : null,
                            width: width),
                        if (!isLong)
                          _buildStatCard(
                              context,
                              "Collateral",
                              formatCurrency
                                  .format(optionPosition.shortCollateral),
                              width: width),
                      ]);
                })),
            const Divider(height: 1),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
              child: Text(
                  "Opened ${formatDate.format(optionPosition.createdAt!)}",
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline),
                  textAlign: TextAlign.right),
            )
          ],
        ));
  }

  Widget _buildDetailRow(String title, String value, {Widget? trailing}) {
    return ListTile(
      minTileHeight: 10,
      title: Text(title),
      trailing: trailing ?? Text(value, style: const TextStyle(fontSize: 18)),
    );
  }

  Widget _buildMarketDataCard(OptionInstrument optionInstrument) {
    if (optionInstrument.optionMarketData == null) return Container();
    final data = optionInstrument.optionMarketData!;

    final totalSize = data.bidSize + data.askSize;
    final bidPct = totalSize > 0 ? data.bidSize / totalSize : 0.5;

    final spread = (data.askPrice ?? 0) - (data.bidPrice ?? 0);
    final spreadPct = data.markPrice != null && data.markPrice! > 0
        ? spread / data.markPrice!
        : 0.0;

    // Liquidity score (heuristic)
    // < 1% : Excellent (Green)
    // < 5% : Good (Orange)
    // > 5% : Low Liquidity (Red)
    Color liquidityColor = Colors.green;
    String liquidityLabel = "Tight Spread";
    if (spreadPct > 0.05) {
      liquidityColor = Colors.red;
      liquidityLabel = "Wide Spread";
    } else if (spreadPct > 0.01) {
      liquidityColor = Colors.orange;
      liquidityLabel = "Moderate Spread";
    }

    // Volume vs OI
    final highActivity =
        data.openInterest > 0 && data.volume > data.openInterest;

    return Card(
        child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const ListTile(
          title: Text("Market Data", style: TextStyle(fontSize: 20)),
        ),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: LayoutBuilder(builder: (context, constraints) {
              const int crossAxisCount = 3;
              const double spacing = 8.0;
              final double itemWidth =
                  (constraints.maxWidth - ((crossAxisCount - 1) * spacing)) /
                      crossAxisCount;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  if (data.volume > 0)
                    _buildStatCard(context, "Volume",
                        formatCompactNumber.format(data.volume),
                        width: itemWidth),
                  if (data.openInterest > 0)
                    _buildStatCard(context, "Open Interest",
                        formatCompactNumber.format(data.openInterest),
                        width: itemWidth),
                  if (data.impliedVolatility != null)
                    _buildStatCard(context, "Implied Vol",
                        formatPercentage.format(data.impliedVolatility),
                        width: itemWidth),
                  if (data.breakEvenPrice != null)
                    _buildStatCard(context, "Break Even",
                        formatCurrency.format(data.breakEvenPrice),
                        width: itemWidth),
                  if (data.chanceOfProfitLong != null)
                    _buildStatCard(context, "Profit Chance",
                        formatPercentage.format(data.chanceOfProfitLong),
                        width: itemWidth),
                  _buildStatCard(context, liquidityLabel,
                      formatPercentage.format(spreadPct),
                      color: liquidityColor.withOpacity(0.1),
                      textColor: liquidityColor,
                      width: itemWidth),
                  if (highActivity)
                    _buildStatCard(context, "Activity", "High",
                        color: Colors.orange.withOpacity(0.1),
                        textColor: Colors.orange,
                        width: itemWidth),
                ],
              );
            })),
        const Divider(),
        // Depth Visualization
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Bid Size (${data.bidSize})",
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.primary)),
                    Text("Ask Size (${data.askSize})",
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.primary)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                        flex: (bidPct * 100).toInt(),
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: const BorderRadius.horizontal(
                                  left: Radius.circular(2))),
                        )),
                    const SizedBox(width: 2),
                    Expanded(
                        flex: ((1 - bidPct) * 100).toInt(),
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: const BorderRadius.horizontal(
                                  right: Radius.circular(2))),
                        )),
                  ],
                ),
              ],
            )),
        Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(children: [
                  Text("Bid",
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.outline)),
                  Text(formatCurrency.format(data.bidPrice),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ]),
                Container(
                    width: 1,
                    height: 40,
                    color: Theme.of(context).dividerColor),
                Column(children: [
                  Text("Mark",
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.outline)),
                  Text(formatCurrency.format(data.adjustedMarkPrice),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ]),
                Container(
                    width: 1,
                    height: 40,
                    color: Theme.of(context).dividerColor),
                Column(children: [
                  Text("Ask",
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.outline)),
                  Text(formatCurrency.format(data.askPrice),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ]),
              ],
            )),
        const Divider(),
        _buildDetailRow(
            "Last Trade",
            data.lastTradePrice != null
                ? "${formatCurrency.format(data.lastTradePrice)} x ${formatCompactNumber.format(data.lastTradeSize)}"
                : '-'),
        if (data.lowPrice != null && data.highPrice != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Day Range",
                        style: TextStyle(
                            fontSize: 16,
                            color:
                                Theme.of(context).textTheme.bodyMedium!.color)),
                    Text(
                        "${formatCurrency.format(data.lowPrice)} - ${formatCurrency.format(data.highPrice)}",
                        style: const TextStyle(fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 8),
                LayoutBuilder(builder: (context, constraints) {
                  final range = data.highPrice! - data.lowPrice!;
                  final position = data.adjustedMarkPrice! - data.lowPrice!;
                  final percent = range > 0 ? (position / range) : 0.5;
                  return Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Container(
                        height: 4,
                        width: constraints.maxWidth,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Container(
                        margin: EdgeInsets.only(
                            left: (constraints.maxWidth * percent)
                                .clamp(0, constraints.maxWidth - 4)),
                        width: 8, // marker width
                        height: 8,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ] else
          _buildDetailRow(
              "Day Range",
              data.lowPrice != null && data.highPrice != null
                  ? "${formatCurrency.format(data.lowPrice)} - ${formatCurrency.format(data.highPrice)}"
                  : "-"),
        _buildDetailRow(
            "Previous Close", formatCurrency.format(data.previousClosePrice)),
      ],
    ));
  }

  Widget _buildStatCard(BuildContext context, String label, String value,
      {Color? color, Color? textColor, double? width}) {
    return Container(
      width: width,
      constraints: width == null ? const BoxConstraints(minWidth: 100) : null,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: textColor ?? Theme.of(context).colorScheme.outline),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildReturnBlock(
      BuildContext context, String label, double? value, double? percent,
      {bool large = false}) {
    if (value == null || percent == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 4),
          Text("-",
              style: TextStyle(
                  fontSize: large ? 24 : 20, fontWeight: FontWeight.bold)),
        ],
      );
    }
    final isPositive = value > 0;
    final isNegative = value < 0;
    final color = isPositive
        ? (Theme.of(context).brightness == Brightness.light
            ? Colors.green
            : Colors.lightGreenAccent)
        : (isNegative
            ? (Theme.of(context).brightness == Brightness.light
                ? Colors.red
                : Colors.redAccent)
            : Colors.grey);

    if (large) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: Theme.of(context).colorScheme.outline)),
          const SizedBox(height: 2),
          Text(formatCurrency.format(value),
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(formatPercentage.format(percent),
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w500, color: color)),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 4),
          Text(formatCurrency.format(value),
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(formatPercentage.format(percent),
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildHistoricalChartSection(OptionInstrument optionInstrument) {
    return Consumer<OptionHistoricalsStore>(
        builder: (context, optionHistoricalsStore, child) {
      var optionInstrumentHistoricalsObj = optionHistoricalsStore.items
          .firstWhereOrNull((element) =>
              element.legs.first.id == optionInstrument.id &&
              element.span == convertChartSpanFilter(chartDateSpanFilter) &&
              element.bounds == convertChartBoundsFilter(chartBoundsFilter));
      debugPrint(
          '${optionInstrumentHistoricalsObj != null ? 'Found' : 'Not found'} optionInstrumentHistoricals for span: ${convertChartSpanFilter(chartDateSpanFilter)}, bounds: ${convertChartBoundsFilter(chartBoundsFilter)}');
      if (optionInstrumentHistoricalsObj != null) {
        InstrumentHistorical? firstHistorical;
        InstrumentHistorical? lastHistorical;
        double open = 0;
        double close = 0;
        double changeInPeriod = 0;
        double changePercentInPeriod = 0;

        firstHistorical = optionInstrumentHistoricalsObj.historicals.first;
        lastHistorical = optionInstrumentHistoricalsObj.historicals.last;
        open = firstHistorical.openPrice!;
        close = lastHistorical.closePrice!;
        changeInPeriod = close - open;
        changePercentInPeriod = close / open - 1;

        if (selection != null) {
          changeInPeriod = selection!.closePrice! - open;
          changePercentInPeriod = selection!.closePrice! / open - 1;
        }

        var brightness = MediaQuery.of(context).platformBrightness;
        var textColor = Theme.of(context).colorScheme.surface;
        if (brightness == Brightness.dark) {
          textColor = Colors.grey.shade200;
        } else {
          textColor = Colors.grey.shade800;
        }

        var seriesList = [
          charts.Series<InstrumentHistorical, DateTime>(
            id: 'Open',
            colorFn: (_, __) => charts.ColorUtil.fromDartColor(
                Theme.of(context).colorScheme.primary),
            domainFn: (InstrumentHistorical history, _) => history.beginsAt!,
            measureFn: (InstrumentHistorical history, _) => history.openPrice,
            data: optionInstrumentHistoricalsObj.historicals,
          ),
          charts.Series<InstrumentHistorical, DateTime>(
            id: 'Close',
            colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
            domainFn: (InstrumentHistorical history, _) => history.beginsAt!,
            measureFn: (InstrumentHistorical history, _) => history.closePrice,
            data: optionInstrumentHistoricalsObj.historicals,
          ),
          charts.Series<InstrumentHistorical, DateTime>(
            id: 'Low',
            colorFn: (_, __) => charts.MaterialPalette.red.shadeDefault,
            domainFn: (InstrumentHistorical history, _) => history.beginsAt!,
            measureFn: (InstrumentHistorical history, _) => history.lowPrice,
            data: optionInstrumentHistoricalsObj.historicals,
          ),
          charts.Series<InstrumentHistorical, DateTime>(
            id: 'High',
            colorFn: (_, __) => charts.MaterialPalette.green.shadeDefault,
            domainFn: (InstrumentHistorical history, _) => history.beginsAt!,
            measureFn: (InstrumentHistorical history, _) => history.highPrice,
            data: optionInstrumentHistoricalsObj.historicals,
          ),
        ];

        var provider = Provider.of<InstrumentHistoricalsSelectionStore>(context,
            listen: false);

        TimeSeriesChart historicalChart = TimeSeriesChart(
          seriesList,
          open: optionInstrumentHistoricalsObj.historicals[0].openPrice!,
          close: optionInstrumentHistoricalsObj
              .historicals[
                  optionInstrumentHistoricalsObj.historicals.length - 1]
              .closePrice!,
          seriesLegend: charts.SeriesLegend(
            horizontalFirst: true,
            position: charts.BehaviorPosition.top,
            defaultHiddenSeries: const ["Close", "Low", "High"],
            showMeasures: true,
            measureFormatter: (measure) =>
                measure != null ? formatCurrency.format(measure) : '',
          ),
          zeroBound: false,
          onSelected: (charts.SelectionModel<DateTime>? historical) {
            provider.selectionChanged(historical?.selectedDatum.first.datum);
          },
          symbolRenderer: TextSymbolRenderer(() {
            return provider.selection != null
                ? formatCompactDateTimeWithHour
                    .format(provider.selection!.beginsAt!.toLocal())
                : '0';
          },
              marginBottom: 16,
              backgroundColor: Theme.of(context).colorScheme.inverseSurface,
              textColor: Theme.of(context).colorScheme.onInverseSurface),
        );

        return SliverToBoxAdapter(
            child: Card(
                child: Column(
          children: [
            SizedBox(
                height: 340,
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: historicalChart,
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
                          style: TextStyle(fontSize: 10, color: textColor)),
                    ],
                  )));
            }),
            SizedBox(
                height: 56,
                child: ListView(
                  key: const PageStorageKey<String>('instrumentChartFilters'),
                  padding: const EdgeInsets.all(5.0),
                  scrollDirection: Axis.horizontal,
                  children: [
                    ...[
                      (label: '1D', span: ChartDateSpan.day),
                      (label: '1W', span: ChartDateSpan.week),
                      (label: '1M', span: ChartDateSpan.month),
                      (label: '3M', span: ChartDateSpan.month_3),
                      (label: '1Y', span: ChartDateSpan.year),
                      (label: '5Y', span: ChartDateSpan.year_5),
                    ].map((e) => Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: ChoiceChip(
                            label: Text(e.label),
                            selected: chartDateSpanFilter == e.span,
                            onSelected: (bool value) {
                              if (value) {
                                resetChart(e.span, chartBoundsFilter);
                              }
                            },
                          ),
                        )),
                  ],
                ))
          ],
        )));
      }
      return SliverToBoxAdapter(child: Container());
    });
  }

  Widget _buildGreeksSection(OptionInstrument optionInstrument) {
    return SliverToBoxAdapter(
      child: Card(
        child: Column(
          children: [
            ListTile(
              title: const Text("Greeks", style: TextStyle(fontSize: 20.0)),
              trailing: IconButton(
                  icon: const Icon(Icons.info_outline, size: 20),
                  tooltip: "Greeks Help",
                  onPressed: () => showDialog<String>(
                        context: context,
                        builder: (BuildContext context) => AlertDialog(
                          title: const Text('Greeks'),
                          content: const SingleChildScrollView(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(
                                    "Delta (Δ): Rate of change of the theoretical option value with respect to changes in the underlying asset's price.\n"),
                                Text(
                                    "Gamma (Γ): Rate of change in the delta with respect to changes in the underlying price.\n"),
                                Text(
                                    "Theta (Θ): Sensitivity of the value of the derivative to the passage of time.\n"),
                                Text("Vega (v): Sensitivity to volatility.\n"),
                                Text(
                                    "Rho (p): Sensitivity to the interest rate."),
                              ])),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () => Navigator.pop(context, 'OK'),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      )),
            ),
            if (optionInstrument.optionMarketData != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (optionInstrument.optionMarketData!.delta != null)
                          _buildInfoCard(
                              context,
                              formatNumber.format(
                                  optionInstrument.optionMarketData!.delta),
                              "Δ",
                              "Delta"),
                        if (optionInstrument.optionMarketData!.gamma != null)
                          _buildInfoCard(
                              context,
                              formatNumber.format(
                                  optionInstrument.optionMarketData!.gamma!),
                              "Γ",
                              "Gamma"),
                        if (optionInstrument.optionMarketData!.theta != null)
                          _buildInfoCard(
                              context,
                              formatNumber.format(
                                  optionInstrument.optionMarketData!.theta!),
                              "Θ",
                              "Theta"),
                        if (optionInstrument.optionMarketData!.vega != null)
                          _buildInfoCard(
                              context,
                              formatNumber.format(
                                  optionInstrument.optionMarketData!.vega!),
                              "v",
                              "Vega"),
                        if (optionInstrument.optionMarketData!.rho != null)
                          _buildInfoCard(
                              context,
                              formatNumber.format(
                                  optionInstrument.optionMarketData!.rho!),
                              "p",
                              "Rho"),
                      ],
                    )),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(OptionInstrumentStore optionInstrumentStore,
      OptionAggregatePosition? optionPosition, Instrument? instrument) {
    //if (optionInstrument != null) {
    return SliverLayoutBuilder(builder: (BuildContext context, constraints) {
      const expandedHeight = 180.0;
      final scrolled =
          math.min(expandedHeight, constraints.scrollOffset) / expandedHeight;
      final t = (1 - scrolled).clamp(0.0, 1.0);
      final opacity = 1.0 - Interval(0, 1).transform(t);
      // debugPrint("transform: $t scrolled: $scrolled");

      var optionInstrument = optionInstrumentStore.items.firstWhereOrNull(
              (element) => element.id == widget.optionInstrument.id) ??
          widget.optionInstrument;
      return SliverAppBar(
        centerTitle: false,
        title: Opacity(
          opacity: opacity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 5,
                  children: [
                    Text(optionInstrument.chainSymbol,
                        style: const TextStyle(fontSize: 16.0)),
                    Text("\$${optionInstrument.strikePrice}",
                        style: const TextStyle(fontSize: 16.0)),
                    Text(optionInstrument.type.toUpperCase(),
                        style: const TextStyle(fontSize: 16.0)),
                    Text(formatDate.format(optionInstrument.expirationDate!),
                        style: const TextStyle(fontSize: 16.0)),
                  ]),
              if (optionInstrument.optionMarketData != null) ...[
                Wrap(spacing: 10, children: [
                  AnimatedPriceText(
                      price:
                          optionInstrument.optionMarketData!.adjustedMarkPrice!,
                      format: formatCurrency,
                      style: const TextStyle(fontSize: 14.0)),
                  Wrap(children: [
                    Icon(
                        optionInstrument.optionMarketData!.changeToday > 0
                            ? Icons.trending_up
                            : (optionInstrument.optionMarketData!.changeToday <
                                    0
                                ? Icons.trending_down
                                : Icons.trending_flat),
                        color: (optionInstrument.optionMarketData!.changeToday >
                                0
                            ? Colors.lightGreenAccent
                            : (optionInstrument.optionMarketData!.changeToday <
                                    0
                                ? Colors.red
                                : Colors.grey)),
                        size: 16.0),
                    Container(
                      width: 2,
                    ),
                    Text(
                        formatPercentage.format(optionInstrument
                            .optionMarketData!.changePercentToday),
                        style: const TextStyle(fontSize: 14.0)),
                  ]),
                  Text(
                      "${optionInstrument.optionMarketData!.changeToday > 0 ? "+" : optionInstrument.optionMarketData!.changeToday < 0 ? "-" : ""}${formatCurrency.format(optionInstrument.optionMarketData!.changeToday.abs())}",
                      style: const TextStyle(fontSize: 14.0),
                      textAlign: TextAlign.right)
                ])
              ],
            ],
          ),
        ),
        expandedHeight: optionPosition != null ? 240 : 210,
        floating: false,
        snap: false,
        pinned: true,
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
          final fadeStart =
              math.max(0.0, 1.0 - kToolbarHeight * 2 / deltaExtent);
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
                  opacity: opacity,
                  child: SingleChildScrollView(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Padding(
                            padding:
                                const EdgeInsets.only(left: 10.0, right: 10.0),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${optionInstrument.chainSymbol} \$${formatCompactNumber.format(optionInstrument.strikePrice)} ${optionInstrument.type.toUpperCase()} ${formatDate.format(optionInstrument.expirationDate!)}',
                                    style: TextStyle(
                                        fontSize: 16.0,
                                        color: Theme.of(context)
                                            .appBarTheme
                                            .foregroundColor),
                                    textAlign: TextAlign.left,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (optionInstrument.optionMarketData !=
                                      null) ...[
                                    const SizedBox(height: 4),
                                    AnimatedPriceText(
                                      price: optionInstrument
                                          .optionMarketData!.adjustedMarkPrice!,
                                      format: formatCurrency,
                                      style: TextStyle(
                                          fontSize: 24.0,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .appBarTheme
                                              .foregroundColor),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                            optionInstrument.optionMarketData!
                                                        .changeToday >
                                                    0
                                                ? Icons.trending_up
                                                : (optionInstrument
                                                            .optionMarketData!
                                                            .changeToday <
                                                        0
                                                    ? Icons.trending_down
                                                    : Icons.trending_flat),
                                            color: (optionInstrument
                                                        .optionMarketData!
                                                        .changeToday >
                                                    0
                                                ? (Theme.of(context)
                                                            .brightness ==
                                                        Brightness.light
                                                    ? Colors.green
                                                    : Colors.lightGreenAccent)
                                                : (optionInstrument
                                                            .optionMarketData!
                                                            .changeToday <
                                                        0
                                                    ? Colors.red
                                                    : Colors.grey)),
                                            size: 20.0),
                                        const SizedBox(width: 4),
                                        Text(
                                          formatPercentage.format(
                                              optionInstrument.optionMarketData!
                                                  .changePercentToday),
                                          style: TextStyle(
                                              fontSize: 16.0,
                                              color: Theme.of(context)
                                                  .appBarTheme
                                                  .foregroundColor),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          "${optionInstrument.optionMarketData!.changeToday > 0 ? "+" : optionInstrument.optionMarketData!.changeToday < 0 ? "-" : ""}${formatCurrency.format(optionInstrument.optionMarketData!.changeToday.abs())}",
                                          style: TextStyle(
                                              fontSize: 16.0,
                                              color: Theme.of(context)
                                                  .appBarTheme
                                                  .foregroundColor),
                                        ),
                                      ],
                                    ),
                                  ]
                                ]))
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
                  : const Icon(Icons.account_circle_outlined),
              onPressed: () async {
                var response = await showProfile(
                    context,
                    auth,
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
    });
  }

  void _startRefreshTimer() {
    // Start listening to clipboard
    refreshTriggerTime = Timer.periodic(
      const Duration(milliseconds: 15000),
      (timer) async {
        if (widget.brokerageUser.refreshEnabled) {
          await widget.service.getOptionHistoricals(
              widget.brokerageUser,
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

    var quote = await widget.service.getQuote(
        widget.brokerageUser, quoteStore, widget.optionInstrument.chainSymbol);

    setState(() {
      futureQuote = null;
      futureInstrument = null;
      futureQuote = Future.value(quote);
    });
  }

  List<Widget> _buildLegs(OptionAggregatePosition optionPosition) {
    var widgets = <Widget>[];
    for (int i = 0; i < optionPosition.legs.length; i++) {
      var leg = optionPosition.legs[i];
      widgets.add(ListTile(
          title: Text("Leg ${i + 1}", style: const TextStyle(fontSize: 20))));
      widgets.add(_buildDetailRow(
          "Expiration Date", formatDate.format(leg.expirationDate!)));
      widgets.add(_buildDetailRow("Position Type", "${leg.positionType}"));
      widgets.add(_buildDetailRow("Position Effect", "${leg.positionEffect}"));
      widgets.add(_buildDetailRow("Option Type", leg.optionType));
      widgets.add(_buildDetailRow(
          "Strike Price", formatCurrency.format(leg.strikePrice)));
      widgets.add(_buildDetailRow("Ratio Quantity", "${leg.ratioQuantity}"));
    }
    return widgets;
  }

  Widget _buildOptionFlowAnalysis(
      OptionInstrument optionInstrument, Instrument instrument) {
    if (optionInstrument.optionMarketData == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final md = optionInstrument.optionMarketData!;
    final contract = {
      'volume': md.volume,
      'openInterest': md.openInterest,
      'strike': optionInstrument.strikePrice,
      'lastPrice': md.lastTradePrice ?? md.markPrice ?? 0.0,
      'bid': md.bidPrice,
      'ask': md.askPrice,
      'impliedVolatility': md.impliedVolatility,
      'percentChange': md.changePercentToday,
      'lastTradeDate': md.updatedAt,
    };

    final item = OptionsFlowStore.processOptionContract(
      contract,
      optionInstrument.type.substring(0, 1).toUpperCase() +
          optionInstrument.type.substring(1), // 'call' -> 'Call'
      optionInstrument.chainSymbol,
      optionInstrument.expirationDate!,
      instrument.quoteObj?.lastTradePrice ?? 0.0,
      skipFilters: true,
      delta: md.delta,
      gamma: md.gamma,
      marketCap: instrument.fundamentalsObj?.marketCap,
      sector: instrument.fundamentalsObj?.sector,
    );

    if (item == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0),
            child: OptionFlowListItem(
              item: item,
              brokerageUser: widget.brokerageUser,
              service: widget.service,
              analytics: widget.analytics,
              observer: widget.observer,
              generativeService: widget.generativeService,
              user: widget.user,
              userDocRef: widget.userDocRef,
            )));
  }

  Widget _buildOverview(BrokerageUser user, OptionInstrument optionInstrument,
      Instrument instrument,
      {OptionAggregatePosition? optionPosition}) {
    return Column(children: [
      Card(
          clipBehavior: Clip.hardEdge,
          child: InkWell(
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => InstrumentWidget(
                              user,
                              widget.service,
                              instrument,
                              analytics: widget.analytics,
                              observer: widget.observer,
                              generativeService: widget.generativeService,
                              user: widget.user,
                              userDocRef: widget.userDocRef,
                            )));
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ListTile(
                  title: Text(instrument.simpleName ?? instrument.symbol,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  subtitle: Text(instrument.name),
                  trailing: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      AnimatedPriceText(
                        price:
                            instrument.quoteObj!.lastExtendedHoursTradePrice ??
                                instrument.quoteObj!.lastTradePrice!,
                        format: formatCurrency,
                        style: const TextStyle(
                            fontSize: 18.0, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.right,
                      ),
                      Wrap(
                        spacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Icon(
                              instrument.quoteObj!.changeToday > 0
                                  ? Icons.trending_up
                                  : (instrument.quoteObj!.changeToday < 0
                                      ? Icons.trending_down
                                      : Icons.trending_flat),
                              size: 16,
                              color: (instrument.quoteObj!.changeToday > 0
                                  ? Colors.green
                                  : (instrument.quoteObj!.changeToday < 0
                                      ? Colors.red
                                      : Colors.grey))),
                          Text(
                            formatPercentage.format(
                                instrument.quoteObj!.changePercentToday),
                            style: TextStyle(
                                fontSize: 14.0,
                                fontWeight: FontWeight.w500,
                                color: (instrument.quoteObj!.changeToday > 0
                                    ? Colors.green
                                    : (instrument.quoteObj!.changeToday < 0
                                        ? Colors.red
                                        : Colors.grey))),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ))),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          children: <Widget>[
            Expanded(
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8)),
                icon: const Icon(Icons.list_alt, size: 20),
                label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Chain',
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => InstrumentOptionChainWidget(
                                user,
                                widget.service,
                                instrument,
                                analytics: widget.analytics,
                                observer: widget.observer,
                                generativeService: widget.generativeService,
                                user: widget.user,
                                userDocRef: widget.userDocRef,
                                initialExpirationDate:
                                    optionInstrument.expirationDate,
                                initialTypeFilter:
                                    optionInstrument.type == 'call'
                                        ? 'Call'
                                        : 'Put',
                                selectedOption: optionInstrument,
                              )));
                },
              ),
            ),
            const SizedBox(width: 8),
            if (optionPosition != null) ...[
              Expanded(
                child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8)),
                    icon: const Icon(Icons.add, size: 20),
                    label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(optionPosition.direction == "debit"
                            ? "Buy"
                            : "Buy to Close")),
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => TradeOptionWidget(
                                  user,
                                  widget.service,
                                  optionPosition: optionPosition,
                                  optionInstrument: optionInstrument,
                                  positionType: "Buy",
                                  analytics: widget.analytics,
                                  observer: widget.observer,
                                )))),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8)),
                    icon: const Icon(Icons.remove, size: 20),
                    label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(optionPosition.direction == "debit"
                            ? "Sell"
                            : "Sell to Open")),
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => TradeOptionWidget(
                                  user,
                                  widget.service,
                                  optionPosition: optionPosition,
                                  optionInstrument: optionInstrument,
                                  positionType: "Sell",
                                  analytics: widget.analytics,
                                  observer: widget.observer,
                                )))),
              ),
            ] else ...[
              Expanded(
                child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8)),
                    icon: const Icon(Icons.attach_money, size: 20),
                    label: const FittedBox(
                        fit: BoxFit.scaleDown, child: Text('Trade Option')),
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => TradeOptionWidget(
                                  user,
                                  widget.service,
                                  optionInstrument: optionInstrument,
                                  analytics: widget.analytics,
                                  observer: widget.observer,
                                )))),
              ),
            ],
          ],
        ),
      ),
    ]);
  }
}
