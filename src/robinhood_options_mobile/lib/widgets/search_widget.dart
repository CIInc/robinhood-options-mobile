import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/extensions.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/midlands_movers_item.dart';

import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/ad_banner_widget.dart';
import 'package:robinhood_options_mobile/widgets/agentic_trading_settings_widget.dart';
import 'package:robinhood_options_mobile/widgets/trade_signal_notification_settings_widget.dart';
import 'package:robinhood_options_mobile/widgets/animated_price_text.dart';
import 'package:robinhood_options_mobile/widgets/auto_trade_status_badge_widget.dart';
import 'package:robinhood_options_mobile/widgets/disclaimer_widget.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';
import 'package:robinhood_options_mobile/widgets/home/options_flow_card_widget.dart';
import 'package:robinhood_options_mobile/widgets/sliverappbar_widget.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/model/trade_signals_provider.dart';
import 'package:robinhood_options_mobile/utils/market_hours.dart';
import 'package:robinhood_options_mobile/widgets/list_widget.dart';
import 'package:robinhood_options_mobile/widgets/lists_widget.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';
import 'package:robinhood_options_mobile/model/watchlist.dart';

final formatDate = DateFormat("yMMMd");
final formatCurrency = NumberFormat.simpleCurrency();
final formatPercentage = NumberFormat.decimalPercentPattern(decimalDigits: 2);

class SearchWidget extends StatefulWidget {
  final User? user;
  final BrokerageUser? brokerageUser;
  final IBrokerageService? service;
  final GenerativeService generativeService;
  final DocumentReference<User>? userDocRef;

  const SearchWidget(
    this.brokerageUser,
    this.service, {
    super.key,
    required this.analytics,
    required this.observer,
    required this.generativeService,
    this.navigatorKey,
    required this.user,
    required this.userDocRef,
  });

  final GlobalKey<NavigatorState>? navigatorKey;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;

  @override
  State<SearchWidget> createState() => _SearchWidgetState();
}

class _SearchWidgetState extends State<SearchWidget>
    with AutomaticKeepAliveClientMixin<SearchWidget> {
  final FirestoreService _firestoreService = FirestoreService();

  String? query;
  TextEditingController? searchCtl;
  Future<dynamic>? futureSearch;
  Future<List<MidlandMoversItem>>? futureMovers;
  Future<List<MidlandMoversItem>>? futureLosers;
  Future<List<Instrument>>? futureListMovers;
  Future<List<Instrument>>? futureListMostPopular;
  Future<List<Map<String, dynamic>>>? futureTradeSignals;
  Stream<List<Watchlist>>? watchlistStream;

  InstrumentStore? instrumentStore;

  // Trade Signal Strength category (per docs): STRONG (75-100), MODERATE (50-74), WEAK (0-49)
  String? signalStrengthCategory; // 'STRONG' | 'MODERATE' | 'WEAK' | null

  // Trade Signal Filters
  // String? tradeSignalFilter; // null = all, 'BUY', 'SELL', 'HOLD'
  Map<String, String> selectedIndicators =
      {}; // Selected indicators from multiIndicatorResult.indicators
  int? minSignalStrength; // null = no filter, 0-100
  int? maxSignalStrength; // null = no filter, 0-100
  DateTime? tradeSignalStartDate;
  DateTime? tradeSignalEndDate;
  int tradeSignalLimit = 50; // Default limit

  _SearchWidgetState();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    searchCtl = TextEditingController();
    widget.analytics.logScreenView(screenName: 'Search');

    // Fetch trade signals on initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchTradeSignalsWithFilters();
    });
  }

  @override
  void dispose() {
    searchCtl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return PopScope(
        canPop: false, //When false, blocks the current route from being popped.
        onPopInvokedWithResult: (didPop, result) {
          //do your logic here
          // setStatusBarColor(statusBarColorPrimary,statusBarIconBrightness: Brightness.light);
          // do your logic ends
          return;
        },
        child: _buildScaffold());
  }

  Widget _buildScaffold() {
    instrumentStore = Provider.of<InstrumentStore>(context, listen: false);

    if (widget.brokerageUser != null && widget.service != null) {
      futureMovers ??=
          widget.service!.getMovers(widget.brokerageUser!, direction: "up");
      futureLosers ??=
          widget.service!.getMovers(widget.brokerageUser!, direction: "down");
      futureListMovers ??=
          widget.service!.getTopMovers(widget.brokerageUser!, instrumentStore!);
      if (widget.brokerageUser!.source == BrokerageSource.robinhood) {
        watchlistStream ??= widget.service!.streamLists(widget.brokerageUser!,
            instrumentStore!, Provider.of<QuoteStore>(context, listen: false));
      }
    } else {
      futureMovers = Future.value([]);
      futureLosers = Future.value([]);
      futureListMovers = Future.value([]);
    }
    // futureListMostPopular ??=
    //     widget.service.getListMostPopular(widget.user, instrumentStore!);
    futureSearch ??= Future.value(null);

    return Column(
      children: [
        Expanded(child: _buildSearchContent()),
      ],
    );
  }

  Widget _buildSearchContent() {
    return FutureBuilder(
        future: Future.wait([
          futureSearch as Future,
          futureMovers as Future,
          futureLosers as Future,
          futureListMovers as Future,
          // futureListMostPopular as Future,
        ]),
        builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
          if (snapshot.hasData) {
            List<dynamic> data = snapshot.data as List<dynamic>;
            var search = data.isNotEmpty ? data[0] as dynamic : null;
            var movers =
                data.length > 1 ? data[1] as List<MidlandMoversItem> : null;
            var losers =
                data.length > 2 ? data[2] as List<MidlandMoversItem> : null;
            var listMovers =
                data.length > 3 ? data[3] as List<Instrument> : null;
            // var listMostPopular =
            //     data.length > 4 ? data[4] as List<Instrument> : null;
            return _buildPage(
                search: search,
                movers: movers,
                losers: losers,
                listMovers: listMovers,
                listMostPopular: null, //listMostPopular,
                done: snapshot.connectionState == ConnectionState.done);
          } else if (snapshot.hasError) {
            debugPrint("${snapshot.error}");
            return _buildPage(welcomeWidget: Text("${snapshot.error}"));
          } else {
            return _buildPage(
                done: snapshot.connectionState == ConnectionState.done);
          }
        });
  }

  Widget _buildPage(
      {Widget? welcomeWidget,
      dynamic search,
      List<MidlandMoversItem>? movers,
      List<MidlandMoversItem>? losers,
      List<Instrument>? listMovers,
      List<Instrument>? listMostPopular,
      bool done = false}) {
    return RefreshIndicator(
        onRefresh: _pullRefresh,
        child: GestureDetector(
            onTap: () {
              FocusScopeNode currentFocus = FocusScope.of(context);

              if (!currentFocus.hasPrimaryFocus) {
                currentFocus.unfocus();
              }
            },
            child: CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverAppBar(
                      floating: false,
                      snap: false,
                      pinned: true,
                      centerTitle: false,
                      title: const Text(Constants.appTitle), // Search
                      actions: [
                        if (auth.currentUser != null)
                          AutoTradeStatusBadgeWidget(
                            user: widget.user,
                            userDocRef: widget.userDocRef,
                            service: widget.service,
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
                            })
                      ]),
                  /*
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
                  */
                  SliverStickyHeader(
                    header: Material(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: TextField(
                          controller: searchCtl,
                          decoration: InputDecoration(
                            hintText: 'Search stocks by name or symbol',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: searchCtl!.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      searchCtl!.clear();
                                      setState(() {
                                        futureSearch = Future.value(null);
                                      });
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: BorderSide(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: const BorderSide(
                                  color: Colors.blue, width: 2),
                            ),
                            filled: true,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 16.0),
                          ),
                          onChanged: (text) {
                            widget.analytics.logSearch(searchTerm: text);
                            setState(() {
                              futureSearch =
                                  text.isEmpty || widget.service == null
                                      ? Future.value(null)
                                      : widget.service!
                                          .search(widget.brokerageUser!, text);
                            });
                          },
                        ),
                      ),
                    ),
                    sliver: SliverPadding(
                        padding: const EdgeInsets.all(
                            2), // .symmetric(horizontal: 2),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 150.0,
                            mainAxisSpacing: 10.0,
                            crossAxisSpacing: 10.0,
                            childAspectRatio: 0.925,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (BuildContext context, int index) {
                              return _buildSearchGridItem(search, index);
                            },
                            childCount: search != null
                                ? (search is List
                                    ? search.length
                                    : search["results"][0]["content"]["data"]
                                        .length)
                                : 0,
                          ),
                        )),
                  ),
                  if (watchlistStream != null &&
                      (search == null ||
                          (search is List && search.isEmpty))) ...[
                    SliverToBoxAdapter(
                      child: StreamBuilder<List<Watchlist>>(
                        stream: watchlistStream,
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            var lists = snapshot.data!;
                            return SizedBox(
                              height: 50,
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0),
                                scrollDirection: Axis.horizontal,
                                itemCount: lists.length + 1,
                                itemBuilder: (context, index) {
                                  if (index == 0) {
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(right: 8.0),
                                      child: ActionChip(
                                        avatar: const Icon(Icons.list),
                                        label: const Text('All Lists'),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => ListsWidget(
                                                widget.brokerageUser!,
                                                widget.service!,
                                                analytics: widget.analytics,
                                                observer: widget.observer,
                                                generativeService:
                                                    widget.generativeService,
                                                user: widget.user,
                                                userDocRef: widget.userDocRef,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    );
                                  }
                                  var list = lists[index - 1];
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: ActionChip(
                                      label: Text(list.displayName),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ListWidget(
                                              widget.brokerageUser!,
                                              widget.service!,
                                              list.id,
                                              ownerType: "custom",
                                              analytics: widget.analytics,
                                              observer: widget.observer,
                                              generativeService:
                                                  widget.generativeService,
                                              user: widget.user,
                                              userDocRef: widget.userDocRef,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                            );
                          }
                          return Container();
                        },
                      ),
                    ),
                  ],
                  if (welcomeWidget != null) ...[
                    SliverToBoxAdapter(
                        child: SizedBox(
                      height: 80.0,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Align(
                            alignment: Alignment.center, child: welcomeWidget),
                      ),
                    ))
                  ],
                  // if (search != null) ...[
                  //   SliverStickyHeader(
                  //       header: Material(
                  //           //elevation: 2,
                  //           child: Container(
                  //               alignment: Alignment.centerLeft,
                  //               child: const ListTile(
                  //                 title: Text(
                  //                   "Search Results",
                  //                   style: TextStyle(fontSize: 19.0),
                  //                 ),
                  //                 //subtitle: Text(
                  //                 //    "${formatCompactNumber.format(filteredPositionOrders!.length)} of ${formatCompactNumber.format(positionOrders.length)} orders $orderDateFilterDisplay ${positionOrdersBalance > 0 ? "+" : positionOrdersBalance < 0 ? "-" : ""}${formatCurrency.format(positionOrdersBalance.abs())}"),
                  //               ))),
                  //       sliver: SliverPadding(
                  //           padding: const EdgeInsets.symmetric(horizontal: 2),
                  //           sliver: SliverGrid(
                  //             gridDelegate:
                  //                 const SliverGridDelegateWithMaxCrossAxisExtent(
                  //               maxCrossAxisExtent: 125.0,
                  //               mainAxisSpacing: 10.0,
                  //               crossAxisSpacing: 10.0,
                  //               childAspectRatio: 1.25,
                  //             ),
                  //             delegate: SliverChildBuilderDelegate(
                  //               (BuildContext context, int index) {
                  //                 return _buildSearchGridItem(search, index);
                  //               },
                  //               childCount: search["results"][0]["content"]
                  //                       ["data"]
                  //                   .length,
                  //             ),
                  //           ))),
                  //   const SliverToBoxAdapter(
                  //       child: SizedBox(
                  //     height: 25.0,
                  //   )),
                  // ],
                  SliverToBoxAdapter(
                    child: OptionsFlowCardWidget(
                      brokerageUser: widget.brokerageUser,
                      service: widget.service,
                      analytics: widget.analytics,
                      observer: widget.observer,
                      generativeService: widget.generativeService,
                      user: widget.user,
                      userDocRef: widget.userDocRef,
                    ),
                  ),
                  Consumer<TradeSignalsProvider>(
                    builder: (context, tradeSignalsProvider, child) {
                      // Apply client-side filtering for strength categories when needed
                      final tradeSignals = tradeSignalsProvider.tradeSignals;
                      final isMarketOpen = MarketHours.isMarketOpen();
                      final selectedInterval =
                          tradeSignalsProvider.selectedInterval;
                      final intervalLabel = selectedInterval == '1d'
                          ? 'Daily'
                          : selectedInterval == '1h'
                              ? 'Hourly'
                              : selectedInterval == '30m'
                                  ? '30-min'
                                  : selectedInterval == '15m'
                                      ? '15-min'
                                      : selectedInterval;

                      return SliverStickyHeader(
                          header: Material(
                              elevation: 2,
                              child: Container(
                                  color: Theme.of(context).colorScheme.surface,
                                  alignment: Alignment.centerLeft,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ListTile(
                                        leading: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primaryContainer
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Icon(Icons.insights,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                              size: 22),
                                        ),
                                        title: Text(
                                          "Trade Signals",
                                          style: TextStyle(
                                            fontSize: 20.0,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            PopupMenuButton<String>(
                                              icon: const Icon(Icons.settings,
                                                  size: 20),
                                              tooltip: 'Settings',
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                              itemBuilder:
                                                  (BuildContext context) =>
                                                      <PopupMenuEntry<String>>[
                                                const PopupMenuItem<String>(
                                                  value: 'notifications',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons
                                                          .notifications_outlined),
                                                      SizedBox(width: 8),
                                                      Text('Notifications'),
                                                    ],
                                                  ),
                                                ),
                                                const PopupMenuItem<String>(
                                                  value: 'agentic_settings',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.tune),
                                                      SizedBox(width: 8),
                                                      Text('Configuration'),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                              onSelected: (String value) async {
                                                if (!mounted ||
                                                    widget.user == null ||
                                                    widget.userDocRef == null) {
                                                  return;
                                                }
                                                if (value == 'notifications') {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (context) =>
                                                          TradeSignalNotificationSettingsWidget(
                                                        user: widget.user!,
                                                        userDocRef:
                                                            widget.userDocRef!,
                                                      ),
                                                    ),
                                                  );
                                                } else if (value ==
                                                    'agentic_settings') {
                                                  final result =
                                                      await Navigator.of(
                                                              context)
                                                          .push(
                                                    MaterialPageRoute(
                                                      builder: (context) =>
                                                          AgenticTradingSettingsWidget(
                                                        user: widget.user!,
                                                        userDocRef:
                                                            widget.userDocRef!,
                                                        service: widget.service,
                                                        initialSection:
                                                            'entryStrategies',
                                                      ),
                                                    ),
                                                  );
                                                  if (result == true &&
                                                      mounted) {
                                                    _fetchTradeSignalsWithFilters();
                                                  }
                                                }
                                              },
                                            ),
                                            const SizedBox(width: 4),
                                            PopupMenuButton<String>(
                                              icon: Icon(
                                                Icons.sort,
                                                size: 20,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface,
                                              ),
                                              tooltip: 'Sort by',
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                              itemBuilder:
                                                  (BuildContext context) {
                                                return [
                                                  PopupMenuItem<String>(
                                                    value: 'signalStrength',
                                                    child: Row(
                                                      children: [
                                                        const Text(
                                                            'Signal Strength'),
                                                        if (tradeSignalsProvider
                                                                .sortBy ==
                                                            'signalStrength') ...[
                                                          const SizedBox(
                                                              width: 8),
                                                          Icon(Icons.check,
                                                              size: 18,
                                                              color: Colors
                                                                  .green
                                                                  .shade700),
                                                        ],
                                                      ],
                                                    ),
                                                  ),
                                                  PopupMenuItem<String>(
                                                    value: 'timestamp',
                                                    child: Row(
                                                      children: [
                                                        const Text('Recent'),
                                                        if (tradeSignalsProvider
                                                                .sortBy ==
                                                            'timestamp') ...[
                                                          const SizedBox(
                                                              width: 8),
                                                          Icon(Icons.check,
                                                              size: 18,
                                                              color: Colors
                                                                  .green
                                                                  .shade700),
                                                        ],
                                                      ],
                                                    ),
                                                  ),
                                                ];
                                              },
                                              onSelected: (String value) {
                                                tradeSignalsProvider.sortBy =
                                                    value;
                                                _fetchTradeSignalsWithFilters();
                                              },
                                            ),
                                            const SizedBox(width: 4),
                                            PopupMenuButton<String>(
                                              icon: Icon(
                                                isMarketOpen
                                                    ? Icons.access_time
                                                    : Icons.calendar_today,
                                                color: isMarketOpen
                                                    ? Colors.green.shade700
                                                    : Colors.blue.shade700,
                                              ),
                                              tooltip:
                                                  '${isMarketOpen ? 'Market Open' : 'After Hours'} • $intervalLabel',
                                              itemBuilder:
                                                  (BuildContext context) {
                                                return [
                                                  PopupMenuItem<String>(
                                                    enabled: false,
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              bottom: 8.0),
                                                      child: Text(
                                                        isMarketOpen
                                                            ? 'Market Open'
                                                            : 'After Hours',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: isMarketOpen
                                                              ? Colors.green
                                                                  .shade700
                                                              : Colors.blue
                                                                  .shade700,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  PopupMenuDivider(),
                                                  PopupMenuItem<String>(
                                                    value: '15m',
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Text('15-min'),
                                                        if (selectedInterval ==
                                                            '15m')
                                                          const SizedBox(
                                                              width: 8),
                                                        if (selectedInterval ==
                                                            '15m')
                                                          Icon(Icons.check,
                                                              size: 18,
                                                              color: Colors
                                                                  .green
                                                                  .shade700),
                                                      ],
                                                    ),
                                                  ),
                                                  PopupMenuItem<String>(
                                                    value: '1h',
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Text('Hourly'),
                                                        if (selectedInterval ==
                                                            '1h')
                                                          const SizedBox(
                                                              width: 8),
                                                        if (selectedInterval ==
                                                            '1h')
                                                          Icon(Icons.check,
                                                              size: 18,
                                                              color: Colors
                                                                  .green
                                                                  .shade700),
                                                      ],
                                                    ),
                                                  ),
                                                  PopupMenuItem<String>(
                                                    value: '1d',
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Text('Daily'),
                                                        if (selectedInterval ==
                                                            '1d')
                                                          const SizedBox(
                                                              width: 8),
                                                        if (selectedInterval ==
                                                            '1d')
                                                          Icon(Icons.check,
                                                              size: 18,
                                                              color: Colors
                                                                  .green
                                                                  .shade700),
                                                      ],
                                                    ),
                                                  ),
                                                ];
                                              },
                                              onSelected: (String interval) {
                                                tradeSignalsProvider
                                                    .setSelectedInterval(
                                                        interval);
                                                _fetchTradeSignalsWithFilters();
                                              },
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Consumer<AgenticTradingProvider>(
                                        builder:
                                            (context, agenticProvider, child) {
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16.0,
                                                vertical: 4.0),
                                            child:
                                                _buildTradeSignalFilterChips(),
                                          );
                                        },
                                      ),
                                    ],
                                  ))),
                          sliver: tradeSignalsProvider.isLoading
                              ? SliverToBoxAdapter(
                                  child: SizedBox(
                                    height: 300,
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const CircularProgressIndicator(),
                                          const SizedBox(height: 16),
                                          Text(
                                            'Loading trade signal data...',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurface
                                                      .withValues(alpha: 0.7),
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                              : tradeSignalsProvider.error != null
                                  ? SliverToBoxAdapter(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.error_outline,
                                                  size: 48,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .error),
                                              const SizedBox(height: 16),
                                              Text(
                                                'Error loading signals',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .error,
                                                    ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                tradeSignalsProvider.error!,
                                                textAlign: TextAlign.center,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                              ),
                                              const SizedBox(height: 16),
                                              ElevatedButton.icon(
                                                onPressed: () {
                                                  _fetchTradeSignalsWithFilters();
                                                },
                                                icon: const Icon(Icons.refresh),
                                                label: const Text('Retry'),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    )
                                  : tradeSignals.isEmpty
                                      ? SliverToBoxAdapter(
                                          child: Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Center(
                                              child: Text(
                                                selectedIndicators.isEmpty &&
                                                        signalStrengthCategory ==
                                                            null
                                                    ? 'No trade signals available'
                                                    : 'No matching signals found',
                                                style: TextStyle(
                                                  fontSize: 16.0,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                      : SliverPadding(
                                          padding: const EdgeInsets.all(
                                              2), // .symmetric(horizontal: 2),
                                          sliver: SliverGrid(
                                            gridDelegate:
                                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                              maxCrossAxisExtent: 220.0,
                                              mainAxisSpacing: 10.0,
                                              crossAxisSpacing: 10.0,
                                              childAspectRatio: 1.25,
                                            ),
                                            delegate:
                                                SliverChildBuilderDelegate(
                                              (BuildContext context,
                                                  int index) {
                                                return _buildTradeSignalGridItem(
                                                    tradeSignals, index);
                                              },
                                              childCount: tradeSignals.length,
                                            ),
                                          )));
                    },
                  ),
                  if (movers != null && movers.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                        child: SizedBox(
                      height: 25.0,
                    )),
                    SliverStickyHeader(
                        header: Material(
                            elevation: 2,
                            child: Container(
                                color: Theme.of(context).colorScheme.surface,
                                alignment: Alignment.centerLeft,
                                child: ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.green.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.trending_up,
                                        color: Colors.green, size: 22),
                                  ),
                                  title: Text(
                                    "S&P Gainers",
                                    style: TextStyle(
                                      fontSize: 20.0,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  ),
                                ))),
                        sliver: SliverPadding(
                            padding: const EdgeInsets.all(
                                2), // .symmetric(horizontal: 2),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 220.0,
                                mainAxisSpacing: 10.0,
                                crossAxisSpacing: 10.0,
                                childAspectRatio: 1.25,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (BuildContext context, int index) {
                                  return _buildMoversGridItem(movers, index);
                                },
                                childCount: movers.length,
                              ),
                            ))),
                  ],
                  if (losers != null && losers.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                        child: SizedBox(
                      height: 25.0,
                    )),
                    SliverStickyHeader(
                        header: Material(
                            elevation: 2,
                            child: Container(
                                color: Theme.of(context).colorScheme.surface,
                                alignment: Alignment.centerLeft,
                                child: ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.trending_down,
                                        color: Colors.red, size: 22),
                                  ),
                                  title: Text(
                                    "S&P Decliners",
                                    style: TextStyle(
                                      fontSize: 20.0,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  ),
                                ))),
                        sliver: SliverPadding(
                            padding: const EdgeInsets.all(
                                2), // .symmetric(horizontal: 2),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 220.0,
                                mainAxisSpacing: 10.0,
                                crossAxisSpacing: 10.0,
                                childAspectRatio: 1.25,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (BuildContext context, int index) {
                                  return _buildMoversGridItem(losers, index);
                                },
                                childCount: losers.length,
                              ),
                            ))),
                    const SliverToBoxAdapter(
                        child: SizedBox(
                      height: 25.0,
                    )),
                  ],
                  if (listMovers != null && listMovers.isNotEmpty) ...[
                    SliverStickyHeader(
                        header: Material(
                            elevation: 2,
                            child: Container(
                                color: Theme.of(context).colorScheme.surface,
                                alignment: Alignment.centerLeft,
                                child: ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.show_chart,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        size: 22),
                                  ),
                                  title: Text(
                                    "Top Movers",
                                    style: TextStyle(
                                      fontSize: 20.0,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  ),
                                ))),
                        sliver: SliverPadding(
                            padding: const EdgeInsets.all(
                                2), // .symmetric(horizontal: 2),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 220.0,
                                mainAxisSpacing: 10.0,
                                crossAxisSpacing: 10.0,
                                childAspectRatio: 1.37,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (BuildContext context, int index) {
                                  return _buildListGridItem(
                                      listMovers, index, widget.brokerageUser!);
                                },
                                childCount: listMovers.length,
                              ),
                            ))),
                    const SliverToBoxAdapter(
                        child: SizedBox(
                      height: 25.0,
                    )),
                  ],
                  if (listMostPopular != null &&
                      listMostPopular.isNotEmpty) ...[
                    SliverStickyHeader(
                        header: Material(
                            elevation: 2,
                            child: Container(
                                color: Theme.of(context).colorScheme.surface,
                                alignment: Alignment.centerLeft,
                                child: ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.star,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        size: 22),
                                  ),
                                  title: Text(
                                    "100 Most Popular",
                                    style: TextStyle(
                                      fontSize: 20.0,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  ),
                                ))),
                        sliver: SliverPadding(
                            padding: const EdgeInsets.all(
                                2), // .symmetric(horizontal: 2),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 150.0,
                                mainAxisSpacing: 6.0,
                                crossAxisSpacing: 2.0,
                                childAspectRatio: 1.25,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (BuildContext context, int index) {
                                  return _buildListGridItem(listMostPopular,
                                      index, widget.brokerageUser!);
                                },
                                childCount: listMostPopular.length,
                              ),
                            ))),
                    const SliverToBoxAdapter(
                        child: SizedBox(
                      height: 25.0,
                    )),
                  ],

                  // TODO: Introduce web banner
                  if (!kIsWeb) ...[
                    SliverToBoxAdapter(
                        child: AdBannerWidget(
                      size: AdSize.mediumRectangle,
                      searchBanner: true,
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
                ])));
  }

  Future<void> _pullRefresh() async {
    setState(() {
      futureMovers = null;
      futureLosers = null;
      futureListMovers = null;
      futureListMostPopular = null;
      futureSearch = Future.value(null);
      futureTradeSignals = null;
    });
    // Refresh trade signals on pull-to-refresh
    _fetchTradeSignalsWithFilters();
  }

  Widget _buildMoversGridItem(List<MidlandMoversItem> movers, int index) {
    final isPositive = movers[index].marketHoursPriceMovement! > 0;
    final isNegative = movers[index].marketHoursPriceMovement! < 0;
    return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: BorderSide(
            color: isPositive
                ? Colors.green.withValues(alpha: 0.3)
                : (isNegative
                    ? Colors.red.withValues(alpha: 0.3)
                    : Colors.grey.withValues(
                        alpha:
                            0.2)), // Theme.of(context).colorScheme.outlineVariant)
            width: 1.5,
          ),
        ),
        child: InkWell(
            borderRadius: BorderRadius.circular(12.0),
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(movers[index].symbol,
                          style: TextStyle(
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                              isPositive
                                  ? Icons.trending_up
                                  : (isNegative
                                      ? Icons.trending_down
                                      : Icons.trending_flat),
                              color: isPositive
                                  ? Colors.green
                                  : (isNegative ? Colors.red : Colors.grey),
                              size: 18),
                          const SizedBox(width: 4),
                          Text(
                              formatPercentage.format(movers[index]
                                      .marketHoursPriceMovement!
                                      .abs() /
                                  100),
                              style: TextStyle(
                                fontSize: 15.0,
                                fontWeight: FontWeight.w600,
                                color: isPositive
                                    ? Colors.green
                                    : (isNegative ? Colors.red : Colors.grey),
                              )),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                          formatCurrency
                              .format(movers[index].marketHoursLastPrice),
                          style: TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onSurface,
                          )),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Text(movers[index].description,
                            style: TextStyle(
                              fontSize: 12.0,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ])),
            onTap: () async {
              if (widget.brokerageUser == null || widget.service == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text(
                        "Please link a brokerage account to view details.")));
                return;
              }
              var instrument = await widget.service!.getInstrument(
                  widget.brokerageUser!,
                  instrumentStore!,
                  movers[index].instrumentUrl);

              /* For navigation within this tab, uncomment
                widget.navigatorKey!.currentState!.push(MaterialPageRoute(
                    builder: (context) => InstrumentWidget(ru,
                        watchLists[index].instrumentObj as Instrument)));
                        */
              if (!mounted) return;
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => InstrumentWidget(
                            widget.brokerageUser!,
                            widget.service!,
                            instrument,
                            analytics: widget.analytics,
                            observer: widget.observer,
                            generativeService: widget.generativeService,
                            user: widget.user,
                            userDocRef: widget.userDocRef,
                          )));
            }));
  }

  Widget _buildSearchGridItem(dynamic search, int index) {
    dynamic data;
    if (search is List) {
      data = search[index];
    } else {
      data = search["results"][0]["content"]["data"][index]["item"];
    }
    return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: BorderSide(
            color: Colors.grey.withValues(
                alpha: 0.2), // Theme.of(context).colorScheme.outlineVariant,
            width: 1,
          ),
        ),
        child: InkWell(
            borderRadius: BorderRadius.circular(12.0),
            child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              data["symbol"],
                              style: TextStyle(
                                fontSize: 18.0,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data["simple_name"] ??
                            data["name"] ??
                            data[
                                "description"], // Schwab API returns this field
                        style: TextStyle(
                          fontSize: 13.0,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      if (data["exchange"] != null ||
                          data["assetType"] != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (data["exchange"] != null)
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .secondaryContainer
                                        .withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    data["exchange"],
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSecondaryContainer,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            if (data["exchange"] != null &&
                                data["assetType"] != null &&
                                data["exchange"] != "Mutual Fund" &&
                                data["assetType"] != "INDEX" &&
                                data["assetType"] != "EQUITY")
                              const SizedBox(width: 4),
                            if (data["assetType"] != null &&
                                data["exchange"] != "Mutual Fund" &&
                                data["assetType"] != "INDEX" &&
                                data["assetType"] != "EQUITY")
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .tertiaryContainer
                                        .withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    data["assetType"],
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onTertiaryContainer,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                          ],
                        )
                      ]
                    ])),
            onTap: () async {
              if (widget.brokerageUser == null || widget.service == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text(
                        "Please link a brokerage account to view details.")));
                return;
              }
              final instrumentStore =
                  Provider.of<InstrumentStore>(context, listen: false);
              var instrument = await widget.service!.getInstrumentBySymbol(
                  widget.brokerageUser!, instrumentStore, data["symbol"]);

              if (!mounted) return;

              // var instrument = Instrument.fromJson(data);
              if (instrument != null) {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => InstrumentWidget(
                              widget.brokerageUser!,
                              widget.service!,
                              instrument,
                              analytics: widget.analytics,
                              observer: widget.observer,
                              generativeService: widget.generativeService,
                              user: widget.user,
                              userDocRef: widget.userDocRef,
                            )));
              }
            }));
    /*
    return ListTile(
      title: Text(data["item"]["symbol"]),
      subtitle: Text(data["item"]["simple_name"] ?? data["item"]["name"]),
      onTap: () {
        var instrument = Instrument.fromJson(data["item"]);
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    InstrumentWidget(widget.user, instrument)));
      },
    );
    */
  }

  Widget _buildTradeSignalGridItem(
      List<Map<String, dynamic>> tradeSignals, int index) {
    final signal = tradeSignals[index];
    final timestamp = signal['timestamp'] != null
        ? DateTime.fromMillisecondsSinceEpoch(signal['timestamp'] as int)
        : DateTime.now();
    final symbol = signal['symbol'] ?? 'N/A';
    final overallSignalType = signal['signal'] ?? 'HOLD';

    // Extract individual indicator signals and signal strength from multiIndicatorResult
    final multiIndicatorResult =
        signal['multiIndicatorResult'] as Map<String, dynamic>?;
    final indicatorsMap =
        multiIndicatorResult?['indicators'] as Map<String, dynamic>?;
    final signalStrength = multiIndicatorResult?['signalStrength'] as int?;

    Map<String, String> indicatorSignals = {};
    if (indicatorsMap != null) {
      const indicatorNames = [
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
      ];

      for (final indicator in indicatorNames) {
        final indicatorData = indicatorsMap[indicator] as Map<String, dynamic>?;
        if (indicatorData != null && indicatorData['signal'] != null) {
          indicatorSignals[indicator] = indicatorData['signal'];
        }
      }
    }

    // Calculate composite signal based on enabled indicators
    final agenticProvider =
        Provider.of<AgenticTradingProvider>(context, listen: false);
    final enabledIndicators =
        agenticProvider.config['enabledIndicators'] != null
            ? Map<String, bool>.from(
                agenticProvider.config['enabledIndicators'] as Map)
            : {};

    // If there are enabled indicators, use them to calculate composite signal
    String displaySignalType = overallSignalType;
    if (enabledIndicators.isNotEmpty) {
      final enabledIndicatorSignals = indicatorSignals.entries
          .where((entry) => enabledIndicators[entry.key] == true)
          .map((entry) => entry.value)
          .toList();

      if (enabledIndicatorSignals.isNotEmpty) {
        // Require unanimous agreement for BUY or SELL, otherwise HOLD (mixed)
        final allBuy = enabledIndicatorSignals.every((s) => s == 'BUY');
        final allSell = enabledIndicatorSignals.every((s) => s == 'SELL');

        if (allBuy) {
          displaySignalType = 'BUY';
        } else if (allSell) {
          displaySignalType = 'SELL';
        } else {
          // Mixed signals: use HOLD
          displaySignalType = 'HOLD';
        }
      }
    }

    final signalType = displaySignalType;
    final isBuy = signalType == 'BUY';
    final isSell = signalType == 'SELL';

    return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: BorderSide(
            color: isBuy
                ? Colors.green.withValues(alpha: 0.3)
                : (isSell
                    ? Colors.red.withValues(alpha: 0.3)
                    : Colors.grey.withValues(alpha: 0.2)),
            width: 1.5,
          ),
        ),
        child: InkWell(
            borderRadius: BorderRadius.circular(12.0),
            child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(symbol,
                                style: const TextStyle(
                                  fontSize: 18.0,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isBuy
                                  ? Colors.green.withValues(alpha: 0.15)
                                  : (isSell
                                      ? Colors.red.withValues(alpha: 0.15)
                                      : Colors.grey.withValues(alpha: 0.15)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                    isBuy
                                        ? Icons.trending_up
                                        : (isSell
                                            ? Icons.trending_down
                                            : Icons.trending_flat),
                                    color: isBuy
                                        ? Colors.green
                                        : (isSell ? Colors.red : Colors.grey),
                                    size: 16),
                                const SizedBox(width: 4),
                                Text(signalType,
                                    style: TextStyle(
                                      fontSize: 13.0,
                                      fontWeight: FontWeight.bold,
                                      color: isBuy
                                          ? Colors.green
                                          : (isSell ? Colors.red : Colors.grey),
                                    )),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Timestamp and Signal Strength row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(_formatSignalTimestamp(timestamp),
                                style: TextStyle(
                                    fontSize: 12.0,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant),
                                overflow: TextOverflow.ellipsis),
                          ),
                          if (signalStrength != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getSignalStrengthColor(signalStrength)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.speed,
                                    size: 12,
                                    color:
                                        _getSignalStrengthColor(signalStrength),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '$signalStrength',
                                    style: TextStyle(
                                      fontSize: 11.0,
                                      fontWeight: FontWeight.bold,
                                      color: _getSignalStrengthColor(
                                          signalStrength),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      // Individual indicator signal tags
                      if (indicatorSignals.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: indicatorSignals.entries.map((entry) {
                            final indicatorName = entry.key;
                            final indicatorSignal = entry.value;

                            Color tagColor;
                            if (indicatorSignal == 'BUY') {
                              tagColor = Colors.green;
                            } else if (indicatorSignal == 'SELL') {
                              tagColor = Colors.red;
                            } else {
                              tagColor = Colors.grey;
                            }

                            // Short names for display
                            String displayName;
                            switch (indicatorName) {
                              case 'priceMovement':
                                displayName = 'Price';
                                break;
                              case 'marketDirection':
                                displayName = 'Market';
                                break;
                              case 'bollingerBands':
                                displayName = 'BB';
                                break;
                              case 'stochastic':
                                displayName = 'Stoch';
                                break;
                              case 'williamsR':
                                displayName = 'W%R';
                                break;
                              case 'momentum':
                                displayName = 'RSI';
                                break;
                              default:
                                displayName = indicatorName
                                    .capitalize(); // .toUpperCase()
                            }

                            // Disable styling for indicators not in settings
                            final opacity = 1.0;
                            // isIndicatorEnabled ? 1.0 : 0.4;
                            final finalTagColor = tagColor;
                            // isIndicatorEnabled ? tagColor : disabledColor;

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: finalTagColor.withValues(
                                    alpha: 0.15 * opacity),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: finalTagColor.withValues(
                                      alpha: 0.4 * opacity),
                                  width: 0.5,
                                ),
                              ),
                              child: Opacity(
                                opacity: opacity,
                                child: Text(
                                  displayName, //'$displayName: ${indicatorSignal[0]}',
                                  style: TextStyle(
                                    fontSize: 9.0,
                                    fontWeight: FontWeight.w600,
                                    color: finalTagColor,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      // const SizedBox(height: 8),
                      // Expanded(
                      //   child: Text(reason,
                      //       style: TextStyle(
                      //         fontSize: 12.0,
                      //         color: Colors.grey.shade700,
                      //       ),
                      //       maxLines: 3,
                      //       overflow: TextOverflow.ellipsis),
                      // ),
                    ])),
            onTap: () async {
              final symbol = signal['symbol'];
              if (symbol == null || symbol == 'N/A') return;
              if (widget.brokerageUser == null || widget.service == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text(
                        "Please link a brokerage account to view details.")));
                return;
              }
              var instrument = await widget.service!.getInstrumentBySymbol(
                  widget.brokerageUser!, instrumentStore!, symbol);

              if (!mounted || instrument == null) return;
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => InstrumentWidget(
                            widget.brokerageUser!,
                            widget.service!,
                            instrument,
                            analytics: widget.analytics,
                            observer: widget.observer,
                            generativeService: widget.generativeService,
                            user: widget.user,
                            userDocRef: widget.userDocRef,
                          )));
            }));
  }

  Widget _buildListGridItem(
      List<Instrument> instruments, int index, BrokerageUser user) {
    var instrumentObj = instruments[index];
    final hasQuote = instrumentObj.quoteObj != null;
    final lastTradePrice =
        hasQuote ? instrumentObj.quoteObj!.lastTradePrice : null;
    final changeToday = hasQuote ? instrumentObj.quoteObj!.changeToday : 0.0;
    final changePercentToday =
        hasQuote ? instrumentObj.quoteObj!.changePercentToday : 0.0;

    return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: BorderSide(
            color: changeToday > 0
                ? Colors.green.withValues(alpha: 0.3)
                : (changeToday < 0
                    ? Colors.red.withValues(alpha: 0.3)
                    : Colors.grey.withValues(
                        alpha:
                            0.2)), // Theme.of(context).colorScheme.outlineVariant)
            width: 1.5,
          ),
        ),
        child: InkWell(
            borderRadius: BorderRadius.circular(12.0),
            child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Symbol - always shown
                    Text(
                      instrumentObj.symbol,
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    // Current Price
                    if (lastTradePrice != null) ...[
                      AnimatedPriceText(
                        price: lastTradePrice,
                        format: formatCurrency,
                        style: TextStyle(
                          fontSize: 15.0,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                    ],

                    // Change indicator with percentage
                    if (hasQuote) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            changeToday > 0
                                ? Icons.trending_up
                                : (changeToday < 0
                                    ? Icons.trending_down
                                    : Icons.trending_flat),
                            color: changeToday > 0
                                ? Colors.green
                                : (changeToday < 0 ? Colors.red : Colors.grey),
                            size: 15,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              formatPercentage.format(changePercentToday.abs()),
                              style: TextStyle(
                                fontSize: 13.0,
                                fontWeight: FontWeight.w600,
                                color: changeToday > 0
                                    ? Colors.green
                                    : (changeToday < 0
                                        ? Colors.red
                                        : Colors.grey),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        'No quote data',
                        style: TextStyle(
                            fontSize: 12.0,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Expanded(
                      child:
                          Text(instrumentObj.fundamentalsObj?.description ?? '',
                              style: TextStyle(
                                fontSize: 12.0,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                    ),
                  ],
                )),
            onTap: () {
              /* For navigation within this tab, uncomment
              widget.navigatorKey!.currentState!.push(MaterialPageRoute(
                  builder: (context) => InstrumentWidget(ru,
                      watchLists[index].instrumentObj as Instrument)));
                      */
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => InstrumentWidget(
                            user,
                            widget.service!,
                            instrumentObj,
                            analytics: widget.analytics,
                            observer: widget.observer,
                            generativeService: widget.generativeService,
                            user: widget.user,
                            userDocRef: widget.userDocRef,
                          )));
            }));
  }

  void _fetchTradeSignalsWithFilters() {
    final tradeSignalsProvider =
        Provider.of<TradeSignalsProvider>(context, listen: false);
    // Map category to minimum strength for server-side prefiltering.
    // Strong: >=75, Moderate: >=50, Weak: >=0 (we'll further filter client-side to <50)
    final int? serverMinStrength = signalStrengthCategory == 'STRONG'
        ? 75
        : signalStrengthCategory == 'MODERATE'
            ? 50
            : signalStrengthCategory == 'WEAK'
                ? 0
                : minSignalStrength; // fallback to any explicit slider/legacy state

    final int? serverMaxStrength = signalStrengthCategory == 'STRONG'
        ? null
        : signalStrengthCategory == 'MODERATE'
            ? 74
            : signalStrengthCategory == 'WEAK'
                ? 49
                : null;

    tradeSignalsProvider.streamTradeSignals(
      // signalType: tradeSignalFilter,
      indicatorFilters: selectedIndicators.isEmpty ? null : selectedIndicators,
      minSignalStrength: serverMinStrength,
      maxSignalStrength: serverMaxStrength,
      startDate: tradeSignalStartDate,
      endDate: tradeSignalEndDate,
      limit: tradeSignalLimit,
      sortBy: tradeSignalsProvider.sortBy,
    );
  }

  Widget _buildTradeSignalFilterChips() {
    final indicatorOptions = [
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
    ];

    // Label mapping for indicators
    String getIndicatorLabel(String indicator) {
      switch (indicator) {
        case 'priceMovement':
          return 'Price';
        case 'momentum':
          return 'RSI';
        case 'marketDirection':
          return 'Market';
        case 'bollingerBands':
          return 'BB';
        case 'stochastic':
          return 'Stoch';
        case 'williamsR':
          return 'W%R';
        case 'volume':
          return 'Volume';
        default:
          return indicator.toUpperCase();
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Signal Strength Category Filters FIRST (Strong, Moderate, Weak)
          // Strong (75-100)
          FilterChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt,
                    size: 14,
                    color: signalStrengthCategory == 'STRONG'
                        ? Colors.green.shade700
                        : Theme.of(context).colorScheme.onSurface),
                const SizedBox(width: 4),
                const Text('Strong'),
              ],
            ),
            selected: signalStrengthCategory == 'STRONG',
            onSelected: (selected) {
              setState(() {
                signalStrengthCategory = selected ? 'STRONG' : null;
                minSignalStrength = selected ? 75 : null;
                if (selected) {
                  selectedIndicators.clear();
                }
              });
              _fetchTradeSignalsWithFilters();
            },
            backgroundColor: Colors.transparent,
            selectedColor: Colors.green.withValues(alpha: 0.15),
            side: BorderSide(
              color: signalStrengthCategory == 'STRONG'
                  ? Colors.green.shade400
                  : Colors.grey.shade300,
              width: signalStrengthCategory == 'STRONG' ? 1.5 : 1,
            ),
            labelStyle: TextStyle(
              color: signalStrengthCategory == 'STRONG'
                  ? Colors.green.shade700
                  : Theme.of(context).colorScheme.onSurface,
              fontWeight: signalStrengthCategory == 'STRONG'
                  ? FontWeight.w600
                  : FontWeight.w500,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          // Moderate (50-74)
          FilterChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.speed,
                    size: 14,
                    color: signalStrengthCategory == 'MODERATE'
                        ? Colors.orange.shade700
                        : Theme.of(context).colorScheme.onSurface),
                const SizedBox(width: 4),
                const Text('Moderate'),
              ],
            ),
            selected: signalStrengthCategory == 'MODERATE',
            onSelected: (selected) {
              setState(() {
                signalStrengthCategory = selected ? 'MODERATE' : null;
                minSignalStrength = selected ? 50 : null;
                if (selected) {
                  selectedIndicators.clear();
                }
              });
              _fetchTradeSignalsWithFilters();
            },
            backgroundColor: Colors.transparent,
            selectedColor: Colors.orange.withValues(alpha: 0.15),
            side: BorderSide(
              color: signalStrengthCategory == 'MODERATE'
                  ? Colors.orange.shade400
                  : Colors.grey.shade300,
              width: signalStrengthCategory == 'MODERATE' ? 1.5 : 1,
            ),
            labelStyle: TextStyle(
              color: signalStrengthCategory == 'MODERATE'
                  ? Colors.orange.shade700
                  : Theme.of(context).colorScheme.onSurface,
              fontWeight: signalStrengthCategory == 'MODERATE'
                  ? FontWeight.w600
                  : FontWeight.w500,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          // Weak (0-49)
          FilterChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.thermostat_auto,
                    size: 14,
                    color: signalStrengthCategory == 'WEAK'
                        ? Colors.red.shade700
                        : Theme.of(context).colorScheme.onSurface),
                const SizedBox(width: 4),
                const Text('Weak'),
              ],
            ),
            selected: signalStrengthCategory == 'WEAK',
            onSelected: (selected) {
              setState(() {
                signalStrengthCategory = selected ? 'WEAK' : null;
                minSignalStrength = selected ? 0 : null;
                maxSignalStrength = selected ? 49 : null;
                if (selected) {
                  selectedIndicators.clear();
                }
              });
              _fetchTradeSignalsWithFilters();
            },
            backgroundColor: Colors.transparent,
            selectedColor: Colors.red.withValues(alpha: 0.12),
            side: BorderSide(
              color: signalStrengthCategory == 'WEAK'
                  ? Colors.red.shade400
                  : Colors.grey.shade300,
              width: signalStrengthCategory == 'WEAK' ? 1.5 : 1,
            ),
            labelStyle: TextStyle(
              color: signalStrengthCategory == 'WEAK'
                  ? Colors.red.shade700
                  : Theme.of(context).colorScheme.onSurface,
              fontWeight: signalStrengthCategory == 'WEAK'
                  ? FontWeight.w600
                  : FontWeight.w500,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          Text('•',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.outlineVariant)),
          const SizedBox(width: 8),
          // Indicator chips
          ...indicatorOptions.map((indicator) {
            final indicatorLabel = getIndicatorLabel(indicator);
            final currentSignal = selectedIndicators[indicator];

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(
                    currentSignal != null
                        ? '$indicatorLabel: $currentSignal'
                        : indicatorLabel,
                    style: TextStyle(fontSize: 12)),
                selected: currentSignal != null,
                onSelected: (selected) {
                  setState(() {
                    if (currentSignal == null) {
                      selectedIndicators[indicator] = 'BUY';
                      signalStrengthCategory = null;
                      minSignalStrength = null;
                      maxSignalStrength = null;
                    } else if (currentSignal == 'BUY') {
                      selectedIndicators[indicator] = 'SELL';
                    } else if (currentSignal == 'SELL') {
                      selectedIndicators[indicator] = 'HOLD';
                    } else {
                      selectedIndicators.remove(indicator);
                    }
                  });
                  _fetchTradeSignalsWithFilters();
                },
                backgroundColor: Colors.transparent,
                selectedColor: currentSignal == 'BUY'
                    ? Colors.green.withValues(alpha: 0.15)
                    : currentSignal == 'SELL'
                        ? Colors.red.withValues(alpha: 0.15)
                        : Colors.grey.withValues(alpha: 0.15),
                side: BorderSide(
                  color: currentSignal == 'BUY'
                      ? Colors.green.shade400
                      : currentSignal == 'SELL'
                          ? Colors.red.shade400
                          : currentSignal == 'HOLD'
                              ? Colors.grey.shade400
                              : Colors.grey.shade300,
                  width: currentSignal != null ? 1.5 : 1,
                ),
                labelStyle: TextStyle(
                  color: currentSignal == 'BUY'
                      ? Colors.green.shade700
                      : currentSignal == 'SELL'
                          ? Colors.red.shade700
                          : currentSignal == 'HOLD'
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.onSurface,
                  fontWeight:
                      currentSignal != null ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Formats signal timestamp as "x ago" for recent signals or date for older ones.
  /// Recent signals (within 24 hours) show relative time (e.g., "5 mins ago").
  /// Older signals show the formatted date (e.g., "Dec 5, 2024").
  String _formatSignalTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    // If signal is recent (within 24 hours), show "x ago" format
    if (difference.inHours < 24) {
      if (difference.inMinutes < 1) {
        return 'just now';
      } else if (difference.inMinutes < 60) {
        final mins = difference.inMinutes;
        return '$mins min${mins != 1 ? 's' : ''} ago';
      } else {
        final hours = difference.inHours;
        return '$hours hour${hours != 1 ? 's' : ''} ago';
      }
    } else {
      // For older signals, show the date
      return formatDate.format(timestamp);
    }
  }

  /// Returns color based on signal strength value (0-100).
  /// Matches filter categories:
  /// Strong (75-100): Green
  /// Moderate (50-74): Orange
  /// Weak (0-49): Red
  Color _getSignalStrengthColor(int strength) {
    if (strength >= 75) {
      return Colors.green;
    } else if (strength >= 50) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}
