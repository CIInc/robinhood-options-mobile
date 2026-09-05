import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:candlesticks/candlesticks.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
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
import 'package:robinhood_options_mobile/model/generative_provider.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals_selection_store.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/model/forex_order.dart';
import 'package:robinhood_options_mobile/widgets/ad_banner_widget.dart';
import 'package:robinhood_options_mobile/widgets/forex_orders_widget.dart';
import 'package:robinhood_options_mobile/widgets/auto_trade_status_badge_widget.dart';
import 'package:robinhood_options_mobile/widgets/indicator_documentation_widget.dart';
import 'package:robinhood_options_mobile/widgets/trade_forex_widget.dart';
import 'package:robinhood_options_mobile/widgets/disclaimer_widget.dart';
import 'package:robinhood_options_mobile/widgets/pnl_badge.dart';
import 'package:robinhood_options_mobile/widgets/sliverappbar_widget.dart';
import 'package:robinhood_options_mobile/widgets/animated_price_text.dart';
import 'package:robinhood_options_mobile/widgets/chart_time_series_widget.dart';
import 'package:robinhood_options_mobile/widgets/chat_widget.dart';
import 'package:robinhood_options_mobile/model/instrument_historical.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
import 'package:robinhood_options_mobile/utils/technical_indicators.dart';
import 'package:share_plus/share_plus.dart';

class ForexInstrumentWidget extends StatefulWidget {
  const ForexInstrumentWidget(
    this.brokerageUser,
    this.service,
    //this.account,
    this.holding, {
    super.key,
    required this.analytics,
    required this.observer,
    this.generativeService,
    this.user,
    this.userDocRef,
    this.heroTag,
  });

  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  //final Account account;
  final ForexHolding holding;
  //final OptionAggregatePosition? optionPosition;
  final GenerativeService? generativeService;
  final User? user;
  final DocumentReference<User>? userDocRef;
  final String? heroTag;

  @override
  State<ForexInstrumentWidget> createState() => _ForexInstrumentWidgetState();
}

class _ForexInstrumentWidgetState extends State<ForexInstrumentWidget>
    with AutomaticKeepAliveClientMixin<ForexInstrumentWidget> {
  final FirestoreService _firestoreService = FirestoreService();
  final GenerativeService _generativeService = GenerativeService();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _shareButtonKey = GlobalKey();
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
    _scrollController.dispose();
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
                          data.bounds !=
                              widget.holding.historicalsObj!.bounds ||
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
                        done:
                            snapshot.connectionState == ConnectionState.done &&
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
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _openAIChat(context, widget.holding.currencyCode),
          child: const Icon(Icons.auto_awesome),
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
        const expandedHeight = 160.0;
        final scrolled =
            math.min(expandedHeight, constraints.scrollOffset) / expandedHeight;
        final t = (1 - scrolled).clamp(0.0, 1.0);
        final opacity = 1.0 - Interval(0, 1).transform(t);

        return SliverAppBar(
          centerTitle: false,
          title: AppBarUtils.buildScrollToTopGestureDetector(
            context: context,
            scrollController: _scrollController,
            child: Opacity(
              opacity: opacity,
              child: headerTitle(holding),
            ),
          ),
          expandedHeight: 160,
          floating: false,
          pinned: true,
          snap: false,
          flexibleSpace: Stack(
            fit: StackFit.expand,
            children: [
              LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
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
                final opacity = 1.0 - Interval(fadeStart, fadeEnd).transform(t);
                return FlexibleSpaceBar(
                    background: Hero(
                        tag: widget.heroTag ??
                            'logo_forex_${holding.currencyCode}',
                        child: const SizedBox()),
                    title: Opacity(
                      opacity: opacity,
                      child: SingleChildScrollView(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: headerWidgets.toList())),
                    ));
              }),
              AppBarUtils.buildScrollToTopGestureDetector(
                context: context,
                scrollController: _scrollController,
                child: Container(color: Colors.transparent),
              ),
            ],
          ),
          actions: [
            IconButton(
              key: _shareButtonKey,
              icon: const Icon(Icons.share),
              tooltip: 'Share Instrument',
              onPressed: () {
                final symbol = widget.holding.currencyCode;
                final url = 'https://realizealpha.web.app/forex/$symbol';
                final shareText = 'Check out $symbol on RealizeAlpha: $url';

                final RenderBox? renderBox = _shareButtonKey.currentContext
                    ?.findRenderObject() as RenderBox?;
                Rect? sharePositionOrigin;
                if (renderBox != null &&
                    renderBox.size.width > 0 &&
                    renderBox.size.height > 0) {
                  final size = renderBox.size;
                  final offset = renderBox.localToGlobal(Offset.zero);
                  sharePositionOrigin = Rect.fromLTWH(
                    offset.dx,
                    offset.dy,
                    size.width,
                    size.height,
                  );
                }

                SharePlus.instance.share(
                  ShareParams(
                    text: shareText,
                    sharePositionOrigin: sharePositionOrigin,
                  ),
                );
              },
            ),
            if (auth.FirebaseAuth.instance.currentUser != null)
              AutoTradeStatusBadgeWidget(
                user: widget.user,
                userDocRef: widget.userDocRef,
                service: widget.service,
              ),
            IconButton(
                icon: auth.FirebaseAuth.instance.currentUser != null
                    ? (auth.FirebaseAuth.instance.currentUser!.photoURL == null
                        ? const Icon(Icons.account_circle)
                        : CircleAvatar(
                            maxRadius: 12,
                            backgroundImage: CachedNetworkImageProvider(auth
                                .FirebaseAuth.instance.currentUser!.photoURL!)))
                    : const Icon(Icons.account_circle_outlined),
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

    if (auth.FirebaseAuth.instance.currentUser != null) {
      slivers.add(_buildAIInsights(context));
    }

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
    slivers.add(const SliverToBoxAdapter(
        child: SizedBox(
      height: 8.0,
    )));
    slivers.add(quoteWidget(holding));
    slivers.add(SliverToBoxAdapter(
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      ListTile(
          title: const Text("Position", style: TextStyle(fontSize: 20)),
          subtitle: Text(
              '${formatNumber.format(holding.quantity!)} ${holding.currencyCode}'),
          trailing: Text(formatCurrency.format(holding.marketValue),
              style: const TextStyle(fontSize: 21))),
      _buildDetailScrollRow(holding, 16, 14, iconSize: 23.0),
    ])));
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

    if (!kIsWeb) {
      slivers.add(const SliverToBoxAdapter(
          child: SizedBox(
        height: 25.0,
      )));
      slivers.add(SliverToBoxAdapter(
          child: AdBannerWidget(
        size: AdSize.mediumRectangle,
      )));
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
        onRefresh: _pullRefresh,
        child:
            CustomScrollView(controller: _scrollController, slivers: slivers));
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

  Future<void> _generateAIContent(
      GenerativeProvider provider, Prompt prompt) async {
    provider.startGenerating(prompt.key);
    try {
      final genService = widget.generativeService ?? _generativeService;
      final response =
          await genService.generateContentFromServer(prompt, null, null, null);
      provider.setGenerativeResponse(prompt.key, response);
    } catch (_) {
      provider.setGenerativeResponse(
          prompt.key, 'Failed to generate insight. Please try again.');
    }
  }

  Widget _buildAIInsights(BuildContext context) {
    return Consumer<GenerativeProvider>(
        builder: (context, generativeProvider, child) {
      final symbol = widget.holding.currencyCode;
      final keys = {
        'summary': 'insight-$symbol-summary',
        'sentiment': 'insight-$symbol-sentiment',
        'keyLevels': 'insight-$symbol-key-levels',
        'strategy': 'insight-$symbol-strategy',
      };

      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Card(
            elevation: 0,
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.3),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ExpansionTile(
              leading: Icon(Icons.auto_awesome,
                  color: Theme.of(context).colorScheme.primary),
              title: const Text('AI Market Insights',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Analysis & Trade Ideas'),
              initiallyExpanded: keys.values.any((key) =>
                  generativeProvider.promptResponses[key]?.isNotEmpty == true),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: keys.entries.map((entry) {
                      final isGenerating = generativeProvider.generating &&
                          generativeProvider.generatingPrompt == entry.value;
                      return ActionChip(
                        avatar: isGenerating
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : Icon(_analysisIcon(entry.key), size: 16),
                        label: Text(_analysisLabel(entry.key)),
                        onPressed: isGenerating
                            ? null
                            : () => _generateAIContent(
                                generativeProvider,
                                GenerativeService.buildInstrumentAnalysisPrompt(
                                    symbol: symbol, type: entry.key)),
                      );
                    }).toList()
                      ..add(ActionChip(
                        avatar: const Icon(Icons.chat, size: 16),
                        label: const Text('Ask Assistant'),
                        onPressed: () => _openAIChat(context, symbol),
                      )),
                  ),
                ),
                ...keys.entries
                    .where((entry) =>
                        generativeProvider
                            .promptResponses[entry.value]?.isNotEmpty ==
                        true)
                    .map((entry) => Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_analysisLabel(entry.key),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              MarkdownBody(
                                data: generativeProvider
                                    .promptResponses[entry.value]!,
                              ),
                            ],
                          ),
                        )),
              ],
            ),
          ),
        ),
      );
    });
  }

  String _analysisLabel(String type) {
    switch (type) {
      case 'keyLevels':
        return 'Key Levels';
      default:
        return '${type[0].toUpperCase()}${type.substring(1)}';
    }
  }

  IconData _analysisIcon(String type) {
    switch (type) {
      case 'summary':
        return Icons.summarize;
      case 'sentiment':
        return Icons.bar_chart;
      case 'keyLevels':
        return Icons.layers;
      default:
        return Icons.lightbulb;
    }
  }

  void _openAIChat(BuildContext context, String symbol) {
    final prompts = [
      Prompt(
        key: 'forex-$symbol-summary',
        title: '$symbol Summary',
        prompt: 'Summarize the forex pair or currency $symbol, including its '
            'current market context, major drivers, and key risks.',
      ),
      Prompt(
        key: 'forex-$symbol-trend',
        title: '$symbol Trend',
        prompt: 'Analyze the technical trend for forex $symbol and describe '
            'important support, resistance, momentum, and reversal risks.',
      ),
      Prompt(
        key: 'forex-$symbol-strategy',
        title: '$symbol Strategy',
        prompt: 'Discuss potential risk-aware trading approaches for forex '
            '$symbol. Do not assume a specific position or guarantee an outcome.',
      ),
    ];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatWidget(
          generativeService: widget.generativeService ?? _generativeService,
          user: widget.user,
          prompts: prompts,
        ),
      ),
    );
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
              label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Buy')),
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
              label:
                  const FittedBox(fit: BoxFit.scaleDown, child: Text('Sell')),
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
          style: TextStyle(fontSize: 20.0),
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
      if (holding.quoteObj!.volume != null && holding.quoteObj!.volume! > 0)
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
                      fontSize: 16.0, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1),
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
              AnimatedPriceText(
                price: holding.quoteObj!.markPrice!,
                format: holding.quoteObj!.markPrice! < 0.001
                    ? NumberFormat.simpleCurrency(decimalDigits: 8)
                    : formatCurrency,
                style: const TextStyle(
                    fontSize: 16.0, fontWeight: FontWeight.bold),
              ),
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
                      size: 14.0),
                  const SizedBox(width: 2),
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
            holding.currencyCode,
            style: TextStyle(
                fontSize: 14.0,
                color: Theme.of(context).appBarTheme.foregroundColor),
            textAlign: TextAlign.left,
          ),
          const SizedBox(height: 4),
          Text(
            holding.currencyName,
            style: TextStyle(
                fontSize: 16.0,
                color: Theme.of(context).appBarTheme.foregroundColor),
            textAlign: TextAlign.left,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
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
  bool _showSma20 = true;
  bool _showSma50 = true;
  bool _showSma10 = false;
  bool _showSma200 = false;
  bool _showVolume = true;
  bool _showEma12 = false;
  bool _showEma26 = false;
  bool _showVwap = false;
  bool _showBollinger = false;
  bool _showCandles = false;
  bool _showTechnicalSummary = true;

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

      final candles =
          _historicalsToCandles(widget.holding.historicalsObj!.historicals);
      final maxVolume = widget.holding.historicalsObj!.historicals
          .map((historical) => historical.volume)
          .reduce(math.max)
          .toDouble();
      final hasVolume = maxVolume > 0;
      final sma20 = TechnicalIndicators.calculateSMA(candles, 20);
      final sma50 = TechnicalIndicators.calculateSMA(candles, 50);
      final sma10 = TechnicalIndicators.calculateSMA(candles, 10);
      final sma200 = TechnicalIndicators.calculateSMA(candles, 200);
      final ema12 = TechnicalIndicators.calculateEMA(candles, 12);
      final ema26 = TechnicalIndicators.calculateEMA(candles, 26);
      final vwap = TechnicalIndicators.calculateVWAP(candles);
      final bollinger = TechnicalIndicators.calculateBollingerBands(candles);
      final bollingerUpper = bollinger['upper'] ?? <double?>[];
      final bollingerLower = bollinger['lower'] ?? <double?>[];

      List<charts.Series<InstrumentHistorical, DateTime>> seriesList = [
        charts.Series<InstrumentHistorical, DateTime>(
          id: 'Price',
          colorFn: (_, __) => charts.ColorUtil.fromDartColor(
              Theme.of(context).colorScheme.primary),
          domainFn: (InstrumentHistorical history, _) => history.beginsAt!,
          measureFn: (InstrumentHistorical history, _) =>
              history.closePrice ?? history.openPrice,
          data: widget.holding.historicalsObj!.historicals,
        )..setAttribute(charts.rendererIdKey, 'price'),
      ];
      if (_showVolume && hasVolume) {
        seriesList.add(charts.Series<InstrumentHistorical, DateTime>(
            id: 'Volume',
            colorFn: (_, __) => charts.MaterialPalette.cyan.shadeDefault,
            domainFn: (InstrumentHistorical history, _) => history.beginsAt!,
            measureFn: (InstrumentHistorical history, _) => history.volume,
            data: widget.holding.historicalsObj!.historicals)
          ..setAttribute(charts.rendererIdKey, 'volume')
          ..setAttribute(
              charts.measureAxisIdKey, charts.Axis.secondaryMeasureAxisId));
      }
      if (_showSma20) {
        seriesList.add(charts.Series<InstrumentHistorical, DateTime>(
          id: 'SMA 20',
          colorFn: (_, __) => charts.ColorUtil.fromDartColor(Colors.orange),
          domainFn: (InstrumentHistorical history, _) => history.beginsAt!,
          measureFn: (_, index) =>
              index != null && index < sma20.length ? sma20[index] : null,
          data: widget.holding.historicalsObj!.historicals,
        ));
      }
      if (_showSma10) {
        seriesList.add(charts.Series<InstrumentHistorical, DateTime>(
          id: 'SMA 10',
          colorFn: (_, __) => charts.ColorUtil.fromDartColor(Colors.lightBlue),
          domainFn: (InstrumentHistorical history, _) => history.beginsAt!,
          measureFn: (_, index) =>
              index != null && index < sma10.length ? sma10[index] : null,
          data: widget.holding.historicalsObj!.historicals,
        ));
      }
      if (_showSma50) {
        seriesList.add(charts.Series<InstrumentHistorical, DateTime>(
          id: 'SMA 50',
          colorFn: (_, __) => charts.ColorUtil.fromDartColor(Colors.teal),
          domainFn: (InstrumentHistorical history, _) => history.beginsAt!,
          measureFn: (_, index) =>
              index != null && index < sma50.length ? sma50[index] : null,
          data: widget.holding.historicalsObj!.historicals,
        ));
      }
      if (_showSma200) {
        seriesList.add(charts.Series<InstrumentHistorical, DateTime>(
          id: 'SMA 200',
          colorFn: (_, __) => charts.ColorUtil.fromDartColor(Colors.brown),
          domainFn: (InstrumentHistorical history, _) => history.beginsAt!,
          measureFn: (_, index) =>
              index != null && index < sma200.length ? sma200[index] : null,
          data: widget.holding.historicalsObj!.historicals,
        ));
      }
      if (_showEma12) {
        seriesList.add(charts.Series<InstrumentHistorical, DateTime>(
          id: 'EMA 12',
          colorFn: (_, __) => charts.ColorUtil.fromDartColor(Colors.purple),
          domainFn: (InstrumentHistorical history, _) => history.beginsAt!,
          measureFn: (_, index) =>
              index != null && index < ema12.length ? ema12[index] : null,
          data: widget.holding.historicalsObj!.historicals,
        ));
      }
      if (_showEma26) {
        seriesList.add(charts.Series<InstrumentHistorical, DateTime>(
          id: 'EMA 26',
          colorFn: (_, __) => charts.ColorUtil.fromDartColor(Colors.indigo),
          domainFn: (InstrumentHistorical history, _) => history.beginsAt!,
          measureFn: (_, index) =>
              index != null && index < ema26.length ? ema26[index] : null,
          data: widget.holding.historicalsObj!.historicals,
        ));
      }
      if (_showVwap) {
        seriesList.add(charts.Series<InstrumentHistorical, DateTime>(
          id: 'VWAP',
          colorFn: (_, __) => charts.ColorUtil.fromDartColor(Colors.amber),
          domainFn: (InstrumentHistorical history, _) => history.beginsAt!,
          measureFn: (_, index) =>
              index != null && index < vwap.length ? vwap[index] : null,
          data: widget.holding.historicalsObj!.historicals,
        ));
      }
      if (_showBollinger) {
        for (final band in [
          ('BB Upper', bollingerUpper, Colors.deepOrange),
          ('BB Lower', bollingerLower, Colors.deepOrangeAccent),
        ]) {
          seriesList.add(charts.Series<InstrumentHistorical, DateTime>(
            id: band.$1,
            colorFn: (_, __) => charts.ColorUtil.fromDartColor(band.$3),
            domainFn: (InstrumentHistorical history, _) => history.beginsAt!,
            measureFn: (_, index) =>
                index != null && index < band.$2.length ? band.$2[index] : null,
            data: widget.holding.historicalsObj!.historicals,
          ));
        }
      }
      var extents = charts.NumericExtents.fromValues(
          seriesList[0].data.map((e) => e.closePrice ?? e.openPrice!));
      extents = charts.NumericExtents(extents.min - (extents.width * 0.1),
          extents.max + (extents.width * 0.1));
      var provider = Provider.of<InstrumentHistoricalsSelectionStore>(context,
          listen: false);

      chart = TimeSeriesChart(seriesList,
          open: open,
          close: close,
          seriesLegend: null,
          customSeriesRenderers: [
            charts.LineRendererConfig<DateTime>(
                customRendererId: 'price', includeArea: true, strokeWidthPx: 2),
            if (_showVolume && hasVolume)
              charts.BarRendererConfig<DateTime>(
                  customRendererId: 'volume',
                  groupingType: charts.BarGroupingType.grouped),
          ],
          secondaryMeasureAxis: _showVolume && hasVolume
              ? charts.NumericAxisSpec(
                  tickProviderSpec: const charts.BasicNumericTickProviderSpec(
                      zeroBound: true),
                  renderSpec: charts.NoneRenderSpec(),
                  viewport: charts.NumericExtents(0, maxVolume * 5))
              : null,
          onSelected: (charts.SelectionModel<DateTime>? historical) {
        provider.selectionChanged(historical?.selectedDatum.first.datum);
      },
          symbolRenderer: TextSymbolRenderer(() {
            return provider.selection != null
                ? formatCompactDateTimeWithHour.format(
                    (provider.selection as InstrumentHistorical)
                        .beginsAt!
                        .toLocal())
                : '0';
          },
              marginBottom: 16,
              backgroundColor: Theme.of(context).colorScheme.inverseSurface,
              textColor: Theme.of(context).colorScheme.onInverseSurface),
          zeroBound: false,
          viewport: extents);

      return SliverToBoxAdapter(
          child: Column(
        children: [
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
            final selectedClose = selection?.closePrice ?? close;
            return SizedBox(
              width: double.infinity,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedPriceText(
                      price: selectedClose,
                      format: selectedClose < 0.001
                          ? NumberFormat.simpleCurrency(decimalDigits: 8)
                          : formatCurrency,
                      style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          height: 1.1),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${changeInPeriod > 0 ? "+" : changeInPeriod < 0 ? "-" : ""}${formatCurrency.format(changeInPeriod.abs())} (${formatPercentage.format(changePercentInPeriod.abs())})',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: changeInPeriod > 0
                                  ? Colors.green
                                  : (changeInPeriod < 0
                                      ? Colors.red
                                      : textColor)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                selection != null
                                    ? Icons.access_time
                                    : Icons.calendar_today,
                                size: 14,
                                color: textColor.withValues(alpha: 0.5),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  selection != null
                                      ? formatMediumDateTime.format(
                                          selection!.beginsAt!.toLocal())
                                      : '${formatMediumDateTime.format(firstHistorical!.beginsAt!.toLocal())} - ${formatMediumDateTime.format(lastHistorical!.beginsAt!.toLocal())}',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: textColor.withValues(alpha: 0.7)),
                                  overflow: TextOverflow.fade,
                                  maxLines: 1,
                                  softWrap: false,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (!_showCandles)
                      _buildSelectedIndicatorValues(
                          widget.holding.historicalsObj!.historicals,
                          selection ?? lastHistorical!,
                          textColor),
                  ],
                ),
              ),
            );
          }),
          SizedBox(
              height: 340,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: _showCandles
                    ? Candlesticks(
                        candles: _generateCandles(
                            widget.holding.historicalsObj!.historicals),
                      )
                    : chart!,
              )),
          _buildChartControls(hasVolume: hasVolume),
          _buildDateFilters(),
          _buildInlineTechnicalAnalysis(context),
        ],
      ));
    }
    return SliverToBoxAdapter(
        child: Column(
      children: [
        SizedBox(
            height: 340,
            child: Center(
                child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator.adaptive(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.7)),
                    )),
                const SizedBox(height: 20),
                Text(
                  "Loading chart data...",
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                )
              ],
            ))),
        _buildDateFilters(),
      ],
    ));
  }

  Widget _buildSelectedIndicatorValues(List<InstrumentHistorical> historicals,
      InstrumentHistorical selected, Color textColor) {
    final selectedIndex = historicals
        .indexWhere((historical) => historical.beginsAt == selected.beginsAt);
    if (selectedIndex < 0) return const SizedBox.shrink();

    final candles = _historicalsToCandles(historicals);
    final indicators = <String, List<double?>>{
      'SMA 10': TechnicalIndicators.calculateSMA(candles, 10),
      'SMA 20': TechnicalIndicators.calculateSMA(candles, 20),
      'SMA 50': TechnicalIndicators.calculateSMA(candles, 50),
      'SMA 200': TechnicalIndicators.calculateSMA(candles, 200),
      'EMA 12': TechnicalIndicators.calculateEMA(candles, 12),
      'EMA 26': TechnicalIndicators.calculateEMA(candles, 26),
      'VWAP': TechnicalIndicators.calculateVWAP(candles),
    };
    final colors = <String, Color>{
      'SMA 10': Colors.lightBlue,
      'SMA 20': Colors.orange,
      'SMA 50': Colors.teal,
      'SMA 200': Colors.brown,
      'EMA 12': Colors.purple,
      'EMA 26': Colors.indigo,
      'VWAP': Colors.amber,
    };

    String formatValue(double? value) => value == null
        ? '-'
        : (value.abs() < 0.001
            ? NumberFormat('0.00000000').format(value)
            : formatCurrency.format(value));

    final enabled = <String>{
      if (_showSma10) 'SMA 10',
      if (_showSma20) 'SMA 20',
      if (_showSma50) 'SMA 50',
      if (_showSma200) 'SMA 200',
      if (_showEma12) 'EMA 12',
      if (_showEma26) 'EMA 26',
      if (_showVwap) 'VWAP',
    };
    final chips = <Widget>[];

    Widget buildChip(String label, String valueText, Color color) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: textColor.withValues(alpha: 0.9),
                    fontFeatures: [ui.FontFeature.tabularFigures()])),
            const SizedBox(width: 4),
            Text(valueText,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontFeatures: [ui.FontFeature.tabularFigures()])),
          ],
        ),
      );
    }

    if (_showVolume && historicals.any((h) => h.volume > 0)) {
      chips.add(buildChip('Vol', formatCompactNumber.format(selected.volume),
          Theme.of(context).colorScheme.primary));
    }

    for (final label in enabled) {
      final values = indicators[label]!;
      final value =
          selectedIndex < values.length ? values[selectedIndex] : null;
      chips.add(buildChip(label, formatValue(value), colors[label]!));
    }
    if (_showBollinger) {
      for (final band in ['upper', 'lower']) {
        final values =
            TechnicalIndicators.calculateBollingerBands(candles)[band] ?? [];
        final value =
            selectedIndex < values.length ? values[selectedIndex] : null;
        chips.add(buildChip('BB ${band == 'upper' ? 'Upper' : 'Lower'}',
            formatValue(value), Colors.deepOrange));
      }
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: chips
              .map((chip) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: chip,
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildChartControls({bool hasVolume = true}) {
    Widget indicatorChip(
        String label, bool selected, VoidCallback onSelected, Color color) {
      return FilterChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected ? color : null,
          ),
        ),
        selected: selected,
        onSelected: (_) {
          HapticFeedback.selectionClick();
          setState(onSelected);
        },
        selectedColor: color.withValues(alpha: 0.2),
        checkmarkColor: color,
        backgroundColor: Colors.transparent,
        side: BorderSide(
          color: selected ? color : Theme.of(context).dividerColor,
          width: 1,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        visualDensity: VisualDensity.compact,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: _showCandles
                ? const SizedBox()
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: indicatorChip('SMA 10', _showSma10,
                              () => _showSma10 = !_showSma10, Colors.lightBlue),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: indicatorChip('SMA 20', _showSma20,
                              () => _showSma20 = !_showSma20, Colors.orange),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: indicatorChip('SMA 50', _showSma50,
                              () => _showSma50 = !_showSma50, Colors.teal),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: indicatorChip('SMA 200', _showSma200,
                              () => _showSma200 = !_showSma200, Colors.brown),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: indicatorChip('EMA 12', _showEma12,
                              () => _showEma12 = !_showEma12, Colors.purple),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: indicatorChip('EMA 26', _showEma26,
                              () => _showEma26 = !_showEma26, Colors.indigo),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: indicatorChip('VWAP', _showVwap,
                              () => _showVwap = !_showVwap, Colors.amber),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: indicatorChip(
                              'Bollinger',
                              _showBollinger,
                              () => _showBollinger = !_showBollinger,
                              Colors.deepOrange),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: const Icon(Icons.tune, size: 20),
            tooltip: 'Chart Settings',
            constraints: const BoxConstraints(minWidth: 240),
            position: PopupMenuPosition.over,
            itemBuilder: (context) => [
              const PopupMenuItem(
                enabled: false,
                height: 32,
                child: Text('VIEW',
                    style:
                        TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              PopupMenuItem(
                value: 'type',
                child: Row(
                  children: [
                    Icon(
                        _showCandles
                            ? Icons.candlestick_chart
                            : Icons.show_chart,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    Text(_showCandles ? 'Line Chart' : 'Candlestick'),
                  ],
                ),
              ),
              if (!_showCandles && hasVolume) ...[
                PopupMenuItem(
                  value: 'volume',
                  child: Row(
                    children: [
                      Icon(
                          _showVolume
                              ? Icons.bar_chart
                              : Icons.bar_chart_outlined,
                          size: 18,
                          color: _showVolume
                              ? Theme.of(context).colorScheme.primary
                              : null),
                      const SizedBox(width: 12),
                      const Text('Volume'),
                      const Spacer(),
                      if (_showVolume)
                        const Icon(Icons.check, size: 16, color: Colors.green),
                    ],
                  ),
                ),
              ],
              if (!_showCandles) ...[
                PopupMenuItem(
                  value: 'analysis',
                  child: Row(
                    children: [
                      Icon(
                          _showTechnicalSummary
                              ? Icons.analytics
                              : Icons.analytics_outlined,
                          size: 18,
                          color: _showTechnicalSummary
                              ? Theme.of(context).colorScheme.primary
                              : null),
                      const SizedBox(width: 12),
                      const Text('Analysis'),
                      const Spacer(),
                      if (_showTechnicalSummary)
                        const Icon(Icons.check, size: 16, color: Colors.green),
                    ],
                  ),
                ),
              ],
              const PopupMenuDivider(),
              const PopupMenuItem(
                enabled: false,
                height: 32,
                child: Text('INDICATOR PRESETS',
                    style:
                        TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              if (_showCandles)
                const PopupMenuItem(
                  enabled: false,
                  height: 32,
                  child: Text('Not available in Candlestick mode',
                      style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey)),
                ),
              if (!_showCandles) ...[
                const PopupMenuItem(
                  value: 'trend',
                  child: Row(children: [
                    Icon(Icons.trending_up, size: 18),
                    SizedBox(width: 12),
                    Text('Trend Following')
                  ]),
                ),
                const PopupMenuItem(
                  value: 'mean_reversion',
                  child: Row(children: [
                    Icon(Icons.compare_arrows, size: 18),
                    SizedBox(width: 12),
                    Text('Mean Reversion')
                  ]),
                ),
                const PopupMenuItem(
                  value: 'reset',
                  child: Row(children: [
                    Icon(Icons.refresh, size: 18),
                    SizedBox(width: 12),
                    Text('Reset All')
                  ]),
                ),
              ],
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'help',
                child: Row(
                  children: [
                    Icon(Icons.help_outline, size: 18),
                    SizedBox(width: 12),
                    Text('Indicator Help'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'help') {
                _showIndicatorHelp();
                return;
              }
              setState(() {
                if (value == 'type') {
                  _showCandles = !_showCandles;
                } else if (value == 'volume') {
                  _showVolume = !_showVolume;
                } else if (value == 'analysis') {
                  _showTechnicalSummary = !_showTechnicalSummary;
                } else if (value == 'trend') {
                  _showSma20 = true;
                  _showSma50 = true;
                  _showEma12 = true;
                  _showSma10 = false;
                  _showSma200 = false;
                  _showEma26 = false;
                  _showVwap = false;
                  _showBollinger = false;
                } else if (value == 'mean_reversion') {
                  _showBollinger = true;
                  _showSma20 = true;
                  _showVwap = true;
                  _showSma10 = false;
                  _showSma50 = false;
                  _showSma200 = false;
                  _showEma12 = false;
                  _showEma26 = false;
                } else if (value == 'reset') {
                  _showSma20 = true;
                  _showSma50 = true;
                  _showSma10 = false;
                  _showSma200 = false;
                  _showEma12 = false;
                  _showEma26 = false;
                  _showVwap = false;
                  _showBollinger = false;
                  _showVolume = true;
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilters() {
    return Container(
      height: 36,
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
      child: ListView(
        key: const PageStorageKey<String>('forexChartFilters'),
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        scrollDirection: Axis.horizontal,
        children: [
          Row(
            children: {
              ChartDateSpan.day: '1D',
              ChartDateSpan.week: '1W',
              ChartDateSpan.month: '1M',
              ChartDateSpan.month_3: '3M',
              ChartDateSpan.year: '1Y',
              ChartDateSpan.year_5: '5Y',
            }.entries.map((e) => _buildDateSpanChip(e.key, e.value)).toList(),
          )
        ],
      ),
    );
  }

  Widget _buildInlineTechnicalAnalysis(BuildContext context) {
    if (widget.holding.historicalsObj == null ||
        widget.holding.historicalsObj!.historicals.isEmpty) {
      return const SizedBox.shrink();
    }

    if (widget.chartDateSpanFilter == ChartDateSpan.day) {
      final historicals = widget.holding.historicalsObj!.historicals;
      double minPrice = double.maxFinite;
      double maxPrice = -double.maxFinite;
      for (var h in historicals) {
        final p = h.closePrice ?? h.openPrice ?? 0;
        if (p < minPrice) minPrice = p;
        if (p > maxPrice) maxPrice = p;
      }

      if ((maxPrice - minPrice).abs() < 0.00000001) {
        return const SizedBox.shrink();
      }
    }

    final candles = _generateCandles(widget.holding.historicalsObj!.historicals,
        fullResolution: true);
    final sortedCandles = candles.reversed.toList();

    var sma10 = TechnicalIndicators.calculateSMA(sortedCandles, 10).lastOrNull;
    var sma20 = TechnicalIndicators.calculateSMA(sortedCandles, 20).lastOrNull;
    var sma50 = TechnicalIndicators.calculateSMA(sortedCandles, 50).lastOrNull;
    var sma200 =
        TechnicalIndicators.calculateSMA(sortedCandles, 200).lastOrNull;

    var ema12 = TechnicalIndicators.calculateEMA(sortedCandles, 12).lastOrNull;
    var ema26 = TechnicalIndicators.calculateEMA(sortedCandles, 26).lastOrNull;

    var rsi = TechnicalIndicators.calculateRSI(sortedCandles, 14).lastOrNull;

    var macdData = TechnicalIndicators.calculateMACD(sortedCandles);
    var macd = macdData['macd']?.lastOrNull;
    var signal = macdData['signal']?.lastOrNull;

    var vwap = TechnicalIndicators.calculateVWAP(sortedCandles).lastOrNull;

    var stochastic = TechnicalIndicators.calculateStochastic(sortedCandles);
    var stochK = stochastic['k']?.lastOrNull;
    var stochD = stochastic['d']?.lastOrNull;

    var cci = TechnicalIndicators.calculateCCI(sortedCandles).lastOrNull;
    var williamsR =
        TechnicalIndicators.calculateWilliamsR(sortedCandles).lastOrNull;
    var roc = TechnicalIndicators.calculateROC(sortedCandles).lastOrNull;
    var cmf =
        TechnicalIndicators.calculateChaikinMoneyFlow(sortedCandles).lastOrNull;

    var ichimoku = TechnicalIndicators.calculateIchimokuCloud(sortedCandles);
    var spanA = ichimoku['spanA']?.lastOrNull;
    var spanB = ichimoku['spanB']?.lastOrNull;

    var sarData = TechnicalIndicators.calculateParabolicSAR(sortedCandles);
    var sar = sarData['sar']?.lastOrNull as double?;
    var isUptrendSar = sarData['isUptrend']?.lastOrNull as bool?;

    var bbData = TechnicalIndicators.calculateBollingerBands(sortedCandles);
    var bbUp = bbData['upper']?.lastOrNull;
    var bbLow = bbData['lower']?.lastOrNull;

    var kcData = TechnicalIndicators.calculateKeltnerChannels(
        sortedCandles, 20, 10, 1.5);
    var kcUp = kcData['upper']?.lastOrNull;
    var kcLow = kcData['lower']?.lastOrNull;

    bool isSqueeze = false;
    if (bbUp != null && bbLow != null && kcUp != null && kcLow != null) {
      if (bbUp < kcUp && bbLow > kcLow) {
        isSqueeze = true;
      }
    }

    double currentPrice = sortedCandles.last.close;

    int bullishVotes = 0;
    int bearishVotes = 0;

    void vote(bool isBullish) {
      if (isBullish) {
        bullishVotes++;
      } else {
        bearishVotes++;
      }
    }

    if (sma10 != null) vote(currentPrice > sma10);
    if (sma20 != null) vote(currentPrice > sma20);
    if (sma50 != null) vote(currentPrice > sma50);
    if (sma200 != null) vote(currentPrice > sma200);
    if (ema12 != null) vote(currentPrice > ema12);
    if (ema26 != null) vote(currentPrice > ema26);
    if (vwap != null) vote(currentPrice > vwap);

    if (rsi != null) {
      if (rsi < 30) {
        vote(true);
      } else if (rsi > 70) {
        vote(false);
      }
    }
    if (stochK != null && stochD != null) {
      if (stochK < 20 && stochK > stochD) {
        vote(true);
      } else if (stochK > 80 && stochK < stochD) {
        vote(false);
      }
    }
    if (cci != null) {
      if (cci < -100) {
        vote(true);
      } else if (cci > 100) {
        vote(false);
      }
    }
    if (williamsR != null) {
      if (williamsR < -80) {
        vote(true);
      } else if (williamsR > -20) {
        vote(false);
      }
    }
    if (macd != null && signal != null) {
      vote(macd > signal);
    }
    if (roc != null) {
      vote(roc > 0);
    }
    if (cmf != null) {
      if (cmf > 0.05) {
        vote(true);
      } else if (cmf < -0.05) {
        vote(false);
      }
    }
    if (spanA != null && spanB != null) {
      bool aboveCloud = currentPrice > math.max(spanA, spanB);
      bool belowCloud = currentPrice < math.min(spanA, spanB);
      if (aboveCloud) {
        vote(true);
      } else if (belowCloud) {
        vote(false);
      }
    }
    if (sar != null && isUptrendSar != null) {
      vote(isUptrendSar);
    }

    String summaryText = "Neutral";
    Color summaryColor = Colors.grey;
    IconData summaryIcon = Icons.remove;

    if (bullishVotes > bearishVotes + 2) {
      summaryText = "Strong Buy";
      summaryColor = Colors.green;
      summaryIcon = Icons.stars;
    } else if (bullishVotes > bearishVotes) {
      summaryText = "Buy";
      summaryColor = Colors.green.shade400;
      summaryIcon = Icons.arrow_upward;
    } else if (bearishVotes > bullishVotes + 2) {
      summaryText = "Strong Sell";
      summaryColor = Colors.red;
      summaryIcon = Icons.warning;
    } else if (bearishVotes > bullishVotes) {
      summaryText = "Sell";
      summaryColor = Colors.red.shade400;
      summaryIcon = Icons.arrow_downward;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: _showTechnicalSummary ? null : 0,
      margin: _showTechnicalSummary
          ? const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0)
          : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        gradient: LinearGradient(
          colors: [
            summaryColor.withValues(alpha: 0.05),
            Theme.of(context).cardColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: summaryColor.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          if (_showTechnicalSummary)
            BoxShadow(
              color: summaryColor.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
        ],
      ),
      child: _showTechnicalSummary
          ? Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _showTechnicalAnalysis,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: summaryColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: summaryColor.withValues(alpha: 0.3)),
                            ),
                            child: Icon(summaryIcon,
                                color: summaryColor, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  summaryText,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: summaryColor,
                                  ),
                                ),
                                Text(
                                  'Based on ${sortedCandles.length} periods',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                                if (isSqueeze)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.red.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                            color: Colors.red
                                                .withValues(alpha: 0.3),
                                            width: 1),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.compress,
                                              size: 10, color: Colors.red),
                                          SizedBox(width: 4),
                                          Text(
                                            "TTM Squeeze",
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                textBaseline: TextBaseline.alphabetic,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                children: [
                                  if (bullishVotes > 0) ...[
                                    Text(
                                      '$bullishVotes',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade400,
                                          fontSize: 13),
                                    ),
                                    Text(
                                      ' Buy',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.green.shade400
                                              .withValues(alpha: 0.8),
                                          fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  if (bearishVotes > 0) ...[
                                    Text(
                                      '$bearishVotes',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red.shade400,
                                          fontSize: 13),
                                    ),
                                    Text(
                                      ' Sell',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.red.shade400
                                              .withValues(alpha: 0.8),
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                  if (bullishVotes == 0 && bearishVotes == 0)
                                    Text(
                                      'No Signals',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: 80,
                                height: 4,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: Row(
                                    children: [
                                      if (bullishVotes > 0)
                                        Expanded(
                                          flex: bullishVotes,
                                          child: Container(
                                              color: Colors.green.shade400),
                                        ),
                                      if (bearishVotes > 0)
                                        Expanded(
                                          flex: bearishVotes,
                                          child: Container(
                                              color: Colors.red.shade400),
                                        ),
                                      if (bullishVotes == 0 &&
                                          bearishVotes == 0)
                                        Expanded(
                                            child: Container(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .surfaceContainerHighest)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right,
                            size: 20,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                      if (_showTechnicalSummary) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildQuickMetric('RSI', rsi, (v) {
                              return v.toStringAsFixed(1);
                            }, (v) {
                              if (v > 70) return Colors.red;
                              if (v < 30) return Colors.green;
                              return Theme.of(context).colorScheme.onSurface;
                            }),
                            _buildQuickMetric('MACD', macd, (v) {
                              if (signal == null) return 'N/A';
                              final diff = v - signal;
                              return '${diff > 0 ? '+' : ''}${diff.toStringAsFixed(4)}';
                            }, (v) {
                              if (signal == null) return Colors.grey;
                              return v > signal ? Colors.green : Colors.red;
                            }),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  void _showTechnicalAnalysis() {
    if (widget.holding.historicalsObj == null ||
        widget.holding.historicalsObj!.historicals.isEmpty) {
      return;
    }

    final candles = _generateCandles(widget.holding.historicalsObj!.historicals,
        fullResolution: true);
    final sortedCandles = candles.reversed.toList();

    var sma10 = TechnicalIndicators.calculateSMA(sortedCandles, 10).lastOrNull;
    var sma20 = TechnicalIndicators.calculateSMA(sortedCandles, 20).lastOrNull;
    var sma50 = TechnicalIndicators.calculateSMA(sortedCandles, 50).lastOrNull;
    var sma200 =
        TechnicalIndicators.calculateSMA(sortedCandles, 200).lastOrNull;

    var ema12 = TechnicalIndicators.calculateEMA(sortedCandles, 12).lastOrNull;
    var ema26 = TechnicalIndicators.calculateEMA(sortedCandles, 26).lastOrNull;

    var rsi = TechnicalIndicators.calculateRSI(sortedCandles, 14).lastOrNull;

    var macdData = TechnicalIndicators.calculateMACD(sortedCandles);
    var macd = macdData['macd']?.lastOrNull;
    var signal = macdData['signal']?.lastOrNull;

    var bb = TechnicalIndicators.calculateBollingerBands(sortedCandles);
    var upper = bb['upper']?.lastOrNull;
    var lower = bb['lower']?.lastOrNull;

    var vwap = TechnicalIndicators.calculateVWAP(sortedCandles).lastOrNull;

    var stochastic = TechnicalIndicators.calculateStochastic(sortedCandles);
    var stochK = stochastic['k']?.lastOrNull;
    var stochD = stochastic['d']?.lastOrNull;

    var atr = TechnicalIndicators.calculateATR(sortedCandles).lastOrNull;

    var cci = TechnicalIndicators.calculateCCI(sortedCandles).lastOrNull;

    var adxData = TechnicalIndicators.calculateADX(sortedCandles);
    var adx = adxData['adx']?.lastOrNull;

    var williamsR =
        TechnicalIndicators.calculateWilliamsR(sortedCandles).lastOrNull;

    var kcData = TechnicalIndicators.calculateKeltnerChannels(
        sortedCandles, 20, 10, 1.5);
    var kcUp = kcData['upper']?.lastOrNull;
    var kcLow = kcData['lower']?.lastOrNull;

    var roc = TechnicalIndicators.calculateROC(sortedCandles).lastOrNull;

    var cmf =
        TechnicalIndicators.calculateChaikinMoneyFlow(sortedCandles).lastOrNull;

    var ichimoku = TechnicalIndicators.calculateIchimokuCloud(sortedCandles);
    var spanA = ichimoku['spanA']?.lastOrNull;
    var spanB = ichimoku['spanB']?.lastOrNull;

    var sarData = TechnicalIndicators.calculateParabolicSAR(sortedCandles);
    var sar = sarData['sar']?.lastOrNull as double?;
    var isUptrendSar = sarData['isUptrend']?.lastOrNull as bool?;

    bool isSqueezeIndepth = false;
    if (upper != null && lower != null && kcUp != null && kcLow != null) {
      if (upper < kcUp && lower > kcLow) {
        isSqueezeIndepth = true;
      }
    }

    var obv = TechnicalIndicators.calculateOBV(sortedCandles).lastOrNull;

    double currentPrice = sortedCandles.last.close;

    int bullishVotes = 0;
    int bearishVotes = 0;

    void vote(bool isBullish) {
      if (isBullish) {
        bullishVotes++;
      } else {
        bearishVotes++;
      }
    }

    if (sma10 != null) vote(currentPrice > sma10);
    if (sma20 != null) vote(currentPrice > sma20);
    if (sma50 != null) vote(currentPrice > sma50);
    if (sma200 != null) vote(currentPrice > sma200);
    if (ema12 != null) vote(currentPrice > ema12);
    if (ema26 != null) vote(currentPrice > ema26);
    if (vwap != null) vote(currentPrice > vwap);

    if (rsi != null) {
      if (rsi < 30) {
        vote(true);
      } else if (rsi > 70) {
        vote(false);
      }
    }
    if (stochK != null && stochD != null) {
      if (stochK < 20 && stochK > stochD) {
        vote(true);
      } else if (stochK > 80 && stochK < stochD) {
        vote(false);
      }
    }
    if (cci != null) {
      if (cci < -100) {
        vote(true);
      } else if (cci > 100) {
        vote(false);
      }
    }
    if (williamsR != null) {
      if (williamsR < -80) {
        vote(true);
      } else if (williamsR > -20) {
        vote(false);
      }
    }
    if (macd != null && signal != null) {
      vote(macd > signal);
    }
    if (roc != null) {
      vote(roc > 0);
    }
    if (cmf != null) {
      if (cmf > 0.05) {
        vote(true);
      } else if (cmf < -0.05) {
        vote(false);
      }
    }
    if (spanA != null && spanB != null) {
      bool aboveCloud = currentPrice > math.max(spanA, spanB);
      bool belowCloud = currentPrice < math.min(spanA, spanB);
      if (aboveCloud) {
        vote(true);
      } else if (belowCloud) {
        vote(false);
      }
    }
    if (sar != null && isUptrendSar != null) {
      vote(isUptrendSar);
    }

    String summaryText = "Neutral";
    Color summaryColor = Colors.grey;
    if (bullishVotes > bearishVotes + 2) {
      summaryText = "Strong Buy";
      summaryColor = Colors.green;
    } else if (bullishVotes > bearishVotes) {
      summaryText = "Buy";
      summaryColor = Colors.green.shade300;
    } else if (bearishVotes > bullishVotes + 2) {
      summaryText = "Strong Sell";
      summaryColor = Colors.red;
    } else if (bearishVotes > bullishVotes) {
      summaryText = "Sell";
      summaryColor = Colors.red.shade300;
    }

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
              return Container(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                      controller: scrollController,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Center(
                              child: Container(
                                width: 32,
                                height: 4,
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant
                                      .withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Technical Analysis",
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall),
                                IconButton(
                                    onPressed: () => Navigator.pop(context),
                                    icon: const Icon(Icons.close))
                              ],
                            ),
                            Text(
                                "Based on latest candle close: ${_formatPrice(currentPrice)}",
                                style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(height: 16),

                            // Summary Card
                            Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                    color: summaryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: summaryColor)),
                                child: Column(children: [
                                  Text(summaryText,
                                      style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: summaryColor)),
                                  const SizedBox(height: 4),
                                  Text(
                                      "Bullish: $bullishVotes  Bearish: $bearishVotes",
                                      style: const TextStyle(fontSize: 12))
                                ])),
                            const SizedBox(height: 16),

                            _buildSectionHeader(
                                context, "Momentum & Oscillators"),
                            _buildIndicatorWithSignal("RSI (14)", rsi, (v) {
                              if (v > 70) {
                                return const Signal(
                                    text: "Overbought", color: Colors.red);
                              }
                              if (v < 30) {
                                return const Signal(
                                    text: "Oversold", color: Colors.green);
                              }
                              return const Signal(
                                  text: "Neutral", color: Colors.grey);
                            }, indicatorKey: 'momentum'),
                            _buildIndicatorWithSignal(
                                "Stochastic (14, 3)", stochK, (v) {
                              if (v > 80) {
                                return const Signal(
                                    text: "Overbought", color: Colors.red);
                              }
                              if (v < 20) {
                                return const Signal(
                                    text: "Oversold", color: Colors.green);
                              }
                              return const Signal(
                                  text: "Neutral", color: Colors.grey);
                            },
                                valueText:
                                    "K: ${stochK?.toStringAsFixed(2)} D: ${stochD?.toStringAsFixed(2)}",
                                indicatorKey: 'stochastic'),
                            _buildIndicatorWithSignal("CCI (20)", cci, (v) {
                              if (v > 100) {
                                return const Signal(
                                    text: "Overbought", color: Colors.red);
                              }
                              if (v < -100) {
                                return const Signal(
                                    text: "Oversold", color: Colors.green);
                              }
                              return const Signal(
                                  text: "Neutral", color: Colors.grey);
                            }, indicatorKey: 'cci'),
                            _buildIndicatorWithSignal(
                                "Williams %R (14)", williamsR, (v) {
                              if (v > -20) {
                                return const Signal(
                                    text: "Overbought", color: Colors.red);
                              }
                              if (v < -80) {
                                return const Signal(
                                    text: "Oversold", color: Colors.green);
                              }
                              return const Signal(
                                  text: "Neutral", color: Colors.grey);
                            }, indicatorKey: 'williamsR'),
                            _buildIndicatorWithSignal("MACD (12, 26, 9)", macd,
                                (v) {
                              if (signal == null) {
                                return const Signal(
                                    text: "N/A", color: Colors.grey);
                              }
                              if (v > signal) {
                                return const Signal(
                                    text: "Bullish", color: Colors.green);
                              }
                              return const Signal(
                                  text: "Bearish", color: Colors.red);
                            },
                                valueText: "${macd?.toStringAsFixed(4)}",
                                indicatorKey: 'macd'),
                            _buildIndicatorWithSignal("ROC (9)", roc, (v) {
                              if (v > 0) {
                                return const Signal(
                                    text: "Bullish", color: Colors.green);
                              }
                              return const Signal(
                                  text: "Bearish", color: Colors.red);
                            }, indicatorKey: 'roc'),
                            _buildIndicatorWithSignal("CMF (20)", cmf, (v) {
                              if (v > 0.05) {
                                return const Signal(
                                    text: "Accumulation", color: Colors.green);
                              }
                              if (v < -0.05) {
                                return const Signal(
                                    text: "Distribution", color: Colors.red);
                              }
                              return const Signal(
                                  text: "Neutral", color: Colors.grey);
                            },
                                valueText: cmf?.toStringAsFixed(3),
                                indicatorKey: 'chaikinMoneyFlow'),

                            const Divider(),
                            _buildSectionHeader(context, "Trend Strength"),
                            _buildIndicatorWithSignal("ADX (14)", adx, (v) {
                              if (v > 25) {
                                return const Signal(
                                    text: "Strong Trend", color: Colors.blue);
                              }
                              return const Signal(
                                  text: "Weak Trend", color: Colors.grey);
                            }, indicatorKey: 'adx'),
                            _buildIndicatorWithSignal("Ichimoku Cloud", spanA,
                                (v) {
                              final sA = spanA;
                              final sB = spanB;
                              if (sA == null || sB == null) {
                                return const Signal(
                                    text: "N/A", color: Colors.grey);
                              }
                              bool aboveCloud = currentPrice > math.max(sA, sB);
                              bool belowCloud = currentPrice < math.min(sA, sB);

                              if (aboveCloud) {
                                return const Signal(
                                    text: "Bullish (Above)",
                                    color: Colors.green);
                              }
                              if (belowCloud) {
                                return const Signal(
                                    text: "Bearish (Below)", color: Colors.red);
                              }
                              return const Signal(
                                  text: "Neutral (In Cloud)",
                                  color: Colors.grey);
                            },
                                valueText:
                                    "A: ${_formatPrice(spanA)} B: ${_formatPrice(spanB)}",
                                indicatorKey: 'ichimoku'),
                            if (sar != null)
                              _buildIndicatorWithSignal("Parabolic SAR", sar,
                                  (v) {
                                if (isUptrendSar == true) {
                                  return const Signal(
                                      text: "Bullish", color: Colors.green);
                                }
                                return const Signal(
                                    text: "Bearish", color: Colors.red);
                              },
                                  valueText: _formatPrice(sar),
                                  indicatorKey: 'parabolicSar'),

                            const Divider(),
                            _buildSectionHeader(context, "Moving Averages"),
                            _buildIndicatorWithSignal("SMA 10", sma10,
                                (v) => _comparePrice(currentPrice, v),
                                valueText:
                                    sma10 != null ? _formatPrice(sma10) : null,
                                indicatorKey: 'sma'),
                            _buildIndicatorWithSignal("SMA 20", sma20,
                                (v) => _comparePrice(currentPrice, v),
                                valueText:
                                    sma20 != null ? _formatPrice(sma20) : null,
                                indicatorKey: 'sma'),
                            _buildIndicatorWithSignal("SMA 50", sma50,
                                (v) => _comparePrice(currentPrice, v),
                                valueText:
                                    sma50 != null ? _formatPrice(sma50) : null,
                                indicatorKey: 'sma'),
                            _buildIndicatorWithSignal("SMA 200", sma200,
                                (v) => _comparePrice(currentPrice, v),
                                valueText: sma200 != null
                                    ? _formatPrice(sma200)
                                    : null,
                                indicatorKey: 'sma'),
                            _buildIndicatorWithSignal("EMA 12", ema12,
                                (v) => _comparePrice(currentPrice, v),
                                valueText:
                                    ema12 != null ? _formatPrice(ema12) : null,
                                indicatorKey: 'ema'),
                            _buildIndicatorWithSignal("EMA 26", ema26,
                                (v) => _comparePrice(currentPrice, v),
                                valueText:
                                    ema26 != null ? _formatPrice(ema26) : null,
                                indicatorKey: 'ema'),
                            _buildIndicatorWithSignal("VWAP", vwap,
                                (v) => _comparePrice(currentPrice, v),
                                valueText:
                                    vwap != null ? _formatPrice(vwap) : null,
                                indicatorKey: 'vwap'),
                            const Divider(),
                            _buildSectionHeader(context, "Volatility & Volume"),
                            _buildIndicatorWithSignal(
                                "ATR (14)",
                                atr,
                                (v) => const Signal(
                                    text: "Volatility", color: Colors.grey),
                                valueText:
                                    atr != null ? _formatPrice(atr) : null,
                                indicatorKey: 'atr'),
                            _buildIndicatorWithSignal(
                                "OBV",
                                obv,
                                (v) => const Signal(
                                    text: "Volume", color: Colors.grey),
                                valueText: formatCompactNumber.format(obv ?? 0),
                                indicatorKey: 'obv'),
                            _buildIndicatorWithSignal("Bollinger Bands", null,
                                (v) {
                              if (upper != null && currentPrice > upper) {
                                return const Signal(
                                    text: "Above Upper", color: Colors.red);
                              }
                              if (lower != null && currentPrice < lower) {
                                return const Signal(
                                    text: "Below Lower", color: Colors.green);
                              }
                              return const Signal(
                                  text: "Within Bands", color: Colors.grey);
                            },
                                valueText:
                                    "U: ${_formatPrice(upper ?? 0)} / L: ${_formatPrice(lower ?? 0)}",
                                indicatorKey: 'bollingerBands'),
                            _buildIndicatorWithSignal(
                                "TTM Squeeze", isSqueezeIndepth ? 1.0 : 0.0,
                                (v) {
                              if (v == 1.0) {
                                return const Signal(
                                    text: "Squeeze ON", color: Colors.red);
                              }
                              return const Signal(
                                  text: "No Squeeze", color: Colors.grey);
                            },
                                valueText:
                                    isSqueezeIndepth ? "Active" : "Inactive",
                                indicatorKey: 'ttmSqueeze'),
                          ])));
            },
          );
        });
  }

  Signal _comparePrice(double price, double indicatorValue) {
    if (price > indicatorValue) {
      return const Signal(text: "Bullish", color: Colors.green);
    }
    if (price < indicatorValue) {
      return const Signal(text: "Bearish", color: Colors.red);
    }
    return const Signal(text: "Neutral", color: Colors.grey);
  }

  String _formatPrice(double? value) {
    if (value == null) return '-';
    if (value.abs() >= 100000) {
      return formatCompactCurrency.format(value);
    } else if (value.abs() < 0.001 && value != 0) {
      return NumberFormat.simpleCurrency(decimalDigits: 8).format(value);
    } else if (value.abs() < 1.0 && value != 0) {
      return NumberFormat.currency(
              locale: 'en_US', symbol: '\$', decimalDigits: 4)
          .format(value);
    }
    return formatCurrency.format(value);
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary)),
    );
  }

  Widget _buildIndicatorWithSignal(
      String label, double? value, Signal Function(double) getSignal,
      {String? valueText, String? indicatorKey}) {
    Signal signal = const Signal(text: "N/A", color: Colors.grey);
    if (value != null) {
      signal = getSignal(value);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                ),
                if (indicatorKey != null) ...[
                  const SizedBox(width: 2),
                  IconButton(
                    onPressed: () => _showIndicatorDefinition(indicatorKey),
                    icon: const Icon(Icons.info_outline, size: 18),
                    tooltip: 'About $label',
                    visualDensity: VisualDensity.compact,
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: const EdgeInsets.all(8),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 2,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(valueText ?? (value != null ? _formatPrice(value) : "N/A"),
                    style: const TextStyle(fontWeight: FontWeight.w400)),
                const SizedBox(width: 8),
                Flexible(
                  child: Tooltip(
                    message: signal.text,
                    child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: signal.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: signal.color.withValues(alpha: 0.5))),
                        child: Text(signal.text,
                            style: TextStyle(
                                color: signal.color,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis)),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Future<void> _showIndicatorDefinition(String indicatorKey) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            child: IndicatorDocumentationWidget(
              indicatorKey: indicatorKey,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickMetric(
      String label,
      double? value,
      String Function(double) textProvider,
      Color Function(double) colorProvider) {
    if (value == null) return const SizedBox.shrink();

    final text = textProvider(value);
    final color = colorProvider(value);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showIndicatorHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Technical Indicators'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHelpItem('SMA', 'Simple Moving Average',
                  'Average price over a period. Helps identify trends.'),
              _buildHelpItem('EMA', 'Exponential Moving Average',
                  'Weighted average giving more weight to recent prices.'),
              _buildHelpItem('VWAP', 'Volume Weighted Average Price',
                  'Average price weighted by volume. Intraday benchmark.'),
              _buildHelpItem('Bollinger Bands', 'Volatility Bands',
                  'Shows price volatility. Price near upper band = overbought, near lower = oversold. Includes TTM Squeeze detection (Red dots).'),
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
  }

  Widget _buildHelpItem(String title, String subtitle, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Text(subtitle,
              style: TextStyle(
                  fontSize: 12, color: Colors.grey.shade600, height: 1.2)),
          const SizedBox(height: 4),
          Text(description, style: const TextStyle(fontSize: 12, height: 1.3)),
        ],
      ),
    );
  }

  List<Candle> _generateCandles(List<InstrumentHistorical> historicals,
      {bool fullResolution = false}) {
    if (historicals.isEmpty) return [];

    int bucketSize = 1;
    if (!fullResolution) {
      bucketSize = (historicals.length / 60).ceil();
      if (bucketSize < 1) {
        bucketSize = 1;
      }
    }

    List<Candle> candles = [];
    for (int i = 0; i < historicals.length; i += bucketSize) {
      int end = (i + bucketSize < historicals.length)
          ? i + bucketSize
          : historicals.length;
      var chunk = historicals.sublist(i, end);

      double open = chunk.first.openPrice ?? chunk.first.closePrice ?? 0.0001;
      double close = chunk.last.closePrice ?? chunk.last.openPrice ?? open;

      double high = chunk
          .map((e) => math.max(e.highPrice ?? 0, e.openPrice ?? 0))
          .reduce(math.max);
      double low = chunk
          .map((e) => math.min(
              e.lowPrice ?? double.infinity, e.openPrice ?? double.infinity))
          .reduce(math.min);
      if (low == double.infinity) low = open;
      high = math.max(high, math.max(open, close));
      low = math.min(low, math.min(open, close));

      double volume =
          chunk.map((e) => e.volume.toDouble()).reduce((a, b) => a + b);

      if (volume < 1) volume = 1;

      const double minPrice = 0.00000001;
      if (high < minPrice) high = minPrice;
      if (low < minPrice) low = minPrice;
      if (open < minPrice) open = minPrice;
      if (close < minPrice) close = minPrice;

      if (high <= low) {
        high = low + 0.00001;
      }

      candles.add(Candle(
        date: chunk.first.beginsAt ?? DateTime.now(),
        high: high,
        low: low,
        open: open,
        close: close,
        volume: volume,
      ));
    }
    return candles.reversed.toList();
  }

  List<Candle> _historicalsToCandles(List<InstrumentHistorical> historicals) {
    if (historicals.isEmpty) return [];
    const double minPrice = 0.00000001;

    return historicals.map((h) {
      final open = (h.openPrice ?? h.closePrice ?? minPrice)
          .clamp(minPrice, double.infinity)
          .toDouble();
      final close = (h.closePrice ?? h.openPrice ?? minPrice)
          .clamp(minPrice, double.infinity)
          .toDouble();
      var high = math
          .max(h.highPrice ?? open, math.max(open, close))
          .clamp(minPrice, double.infinity)
          .toDouble();
      final low = math
          .min(h.lowPrice ?? open, math.min(open, close))
          .clamp(minPrice, double.infinity)
          .toDouble();

      if (high <= low) high = low + 0.00001;

      return Candle(
        date: h.beginsAt ?? DateTime.now(),
        high: high,
        low: low,
        open: open,
        close: close,
        volume: math.max(1.0, h.volume.toDouble()),
      );
    }).toList();
  }

  Widget _buildDateSpanChip(ChartDateSpan span, String label) {
    final bool isSelected = widget.chartDateSpanFilter == span;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onFilterChanged(span, widget.chartBoundsFilter);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 2.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.surface
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class Signal {
  final String text;
  final Color color;
  const Signal({required this.text, required this.color});
}
