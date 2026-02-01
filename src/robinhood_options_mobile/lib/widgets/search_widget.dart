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
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/midlands_movers_item.dart';

import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/animated_price_text.dart';
import 'package:robinhood_options_mobile/widgets/alpha_factor_discovery_widget.dart';
import 'package:robinhood_options_mobile/widgets/trade_signals_widget.dart';
import 'package:robinhood_options_mobile/widgets/ad_banner_widget.dart';
import 'package:robinhood_options_mobile/widgets/auto_trade_status_badge_widget.dart';
import 'package:robinhood_options_mobile/widgets/disclaimer_widget.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';
import 'package:robinhood_options_mobile/widgets/home/market_sentiment_card_widget.dart';
import 'package:robinhood_options_mobile/widgets/macro_assessment_widget.dart';
import 'package:robinhood_options_mobile/widgets/home/options_flow_card_widget.dart';
import 'package:robinhood_options_mobile/widgets/sliverappbar_widget.dart';
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

  Stream<List<Watchlist>>? watchlistStream;

  InstrumentStore? instrumentStore;

  final GlobalKey<TradeSignalsWidgetState> _tradeSignalsKey = GlobalKey();

  // Trade Signal Filters

  _SearchWidgetState();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    searchCtl = TextEditingController();
    widget.analytics.logScreenView(screenName: 'Search');
  }

  @override
  void didUpdateWidget(SearchWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.brokerageUser != oldWidget.brokerageUser) {
      debugPrint("SearchWidget: User changed. Resetting futures.");
      futureMovers = null;
      futureLosers = null;
      futureListMovers = null;
      futureSearch = null;
      watchlistStream = null;

      if (searchCtl?.text.isNotEmpty == true && widget.service != null) {
        debugPrint(
            "SearchWidget: User changed and text present. Retriggering search.");
        futureSearch =
            widget.service!.search(widget.brokerageUser!, searchCtl!.text);
      }
    }
  }

  @override
  void dispose() {
    searchCtl?.dispose();
    super.dispose();
  } // WidgetsBinding.instance.addPostFrameCallback((_) {

  //   _fetchTradeSignalsWithFilters();
  //override
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
      if (widget.brokerageUser!.source == BrokerageSource.robinhood ||
          widget.brokerageUser!.source == BrokerageSource.demo) {
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

    return Scaffold(
      body: Column(
        children: [
          Expanded(child: _buildSearchContent()),
        ],
      ),
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

            if (search != null)
              debugPrint("SearchWidget: has search results: $search");

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
                        // IconButton(
                        //   icon: const Icon(Icons.sentiment_satisfied_alt),
                        //   tooltip: 'Sentiment Analysis',
                        //   onPressed: () {
                        //     Navigator.push(
                        //         context,
                        //         MaterialPageRoute(
                        //             builder: (context) =>
                        //                 const SentimentAnalysisDashboardWidget()));
                        //   },
                        // ),
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
                      elevation: 1,
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
                            debugPrint(
                                "SearchWidget: onChanged '$text'. Service: ${widget.service}");
                            setState(() {
                              if (text.contains(',') &&
                                  widget.service != null) {
                                var queries = text
                                    .split(',')
                                    .map((e) => e.trim())
                                    .where((e) => e.isNotEmpty)
                                    .toList();
                                if (queries.isNotEmpty) {
                                  futureSearch = Future.wait(queries.map((q) =>
                                          widget.service!.search(
                                              widget.brokerageUser!, q)))
                                      .then((results) {
                                    var combined = [];
                                    for (var result in results) {
                                      if (result is List) {
                                        combined.addAll(result);
                                      } else if (result is Map) {
                                        // Assume Robinhood structure
                                        try {
                                          var resList =
                                              result['results'] as List?;
                                          if (resList != null) {
                                            for (var res in resList) {
                                              var content = res['content'];
                                              if (content != null) {
                                                var data =
                                                    content['data'] as List?;
                                                if (data != null) {
                                                  for (var d in data) {
                                                    if (d['item'] != null) {
                                                      combined.add(d['item']);
                                                    }
                                                  }
                                                }
                                              }
                                            }
                                          }
                                        } catch (e) {
                                          debugPrint(
                                              'Error parsing search result: $e');
                                        }
                                      }
                                    }
                                    return combined;
                                  });
                                  return;
                                }
                              }
                              futureSearch =
                                  text.isEmpty || widget.service == null
                                      ? Future.value(null)
                                      : widget.service!
                                          .search(widget.brokerageUser!, text);
                            });
                          },
                          textInputAction: TextInputAction.search,
                          onSubmitted: (value) {
                            FocusScope.of(context).unfocus();
                          },
                        ),
                      ),
                    ),
                    sliver: search == null
                        ? null
                        : SliverPadding(
                            padding: const EdgeInsets.all(
                                12), // .symmetric(horizontal: 2),
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
                                        : search["results"][0]["content"]
                                                ["data"]
                                            .length)
                                    : 0,
                              ),
                            )),
                  ),
                  if (watchlistStream != null) ...[
                    SliverToBoxAdapter(
                      child: StreamBuilder<List<Watchlist>>(
                        stream: watchlistStream,
                        builder: (context, snapshot) {
                          final visible = search == null ||
                              (search is List && search.isEmpty);
                          if (visible && snapshot.hasData) {
                            var lists = snapshot.data!;
                            return SizedBox(
                              height: 50,
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                    16.0, 12.0, 16.0, 0.0),
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
                          return const SizedBox.shrink();
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
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: MacroAssessmentWidget(),
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: MarketSentimentCardWidget(),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: Card(
                        elevation: 0,
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                            width: 1,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const AlphaFactorDiscoveryWidget(),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.analytics_outlined,
                                      size: 24, color: Colors.purple),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Alpha Factor Discovery",
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Backtest predictive factors & correlations",
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
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
                  // Moved to its own page
                  // TradeSignalsWidget(
                  //   key: _tradeSignalsKey,
                  //   user: widget.user,
                  //   brokerageUser: widget.brokerageUser,
                  //   userDocRef: widget.userDocRef,
                  //   service: widget.service,
                  //   analytics: widget.analytics,
                  //   observer: widget.observer,
                  //   generativeService: widget.generativeService,
                  // ),
                  if (movers != null && movers.isNotEmpty) ...[
                    // const SliverToBoxAdapter(
                    //     child: SizedBox(
                    //   height: 25.0,
                    // )),
                    SliverStickyHeader(
                        header: Material(
                            elevation: 1,
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
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  ),
                                ))),
                        sliver: SliverPadding(
                            padding: const EdgeInsets.all(
                                12), // .symmetric(horizontal: 2),
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
                            elevation: 1,
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
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  ),
                                ))),
                        sliver: SliverPadding(
                            padding: const EdgeInsets.all(
                                12), // .symmetric(horizontal: 2),
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
                            elevation: 1,
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
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  ),
                                ))),
                        sliver: SliverPadding(
                            padding: const EdgeInsets.all(
                                12), // .symmetric(horizontal: 2),
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
                            elevation: 1,
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
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  ),
                                ))),
                        sliver: SliverPadding(
                            padding: const EdgeInsets.all(
                                12), // .symmetric(horizontal: 2),
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
    });
    // Refresh trade signals on pull-to-refresh
    _tradeSignalsKey.currentState?.refresh();
  }

  Widget _buildMoversGridItem(List<MidlandMoversItem> movers, int index) {
    final isPositive = movers[index].marketHoursPriceMovement! > 0;
    final isNegative = movers[index].marketHoursPriceMovement! < 0;
    return Card(
        elevation: 1,
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
        elevation: 1,
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
        elevation: 1,
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
}
