import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/midlands_movers_item.dart';

import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/yahoo_service.dart';
import 'package:robinhood_options_mobile/widgets/ad_banner_widget.dart';
import 'package:robinhood_options_mobile/widgets/disclaimer_widget.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';
import 'package:robinhood_options_mobile/widgets/sliverappbar_widget.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';

final formatDate = DateFormat("yMMMd");
final formatCurrency = NumberFormat.simpleCurrency();
final formatPercentage = NumberFormat.decimalPercentPattern(decimalDigits: 2);

class SearchWidget extends StatefulWidget {
  final User? user;
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  final GenerativeService generativeService;

  const SearchWidget(
    this.brokerageUser,
    this.service, {
    super.key,
    required this.analytics,
    required this.observer,
    required this.generativeService,
    this.navigatorKey,
    this.user,
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

  InstrumentStore? instrumentStore;

  // Advanced Stock Screener UI state
  List<Instrument>? screenerResults;
  String? screenerSector;
  int? screenerMarketCapMin;
  int? screenerMarketCapMax;
  int? screenerPeMin;
  int? screenerPeMax;
  int? screenerDividendYieldMin;
  int? screenerDividendYieldMax;
  bool screenerLoading = false;
  String? errorText;

  // Yahoo Screener integration
  late YahooService yahooService;
  ScreenerId? selectedYahooScreener;
  dynamic yahooScreenerResults;
  bool yahooScreenerLoading = false;
  String? yahooScreenerError;

  // Controllers for screener fields
  late TextEditingController marketCapMinCtl;
  late TextEditingController marketCapMaxCtl;
  late TextEditingController peMinCtl;
  late TextEditingController peMaxCtl;
  late TextEditingController dividendYieldMinCtl;
  late TextEditingController dividendYieldMaxCtl;

  _SearchWidgetState();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    searchCtl = TextEditingController();
    marketCapMinCtl = TextEditingController();
    marketCapMaxCtl = TextEditingController();
    peMinCtl = TextEditingController();
    peMaxCtl = TextEditingController();
    dividendYieldMinCtl = TextEditingController();
    dividendYieldMaxCtl = TextEditingController();
    yahooService = YahooService();
    widget.analytics.logScreenView(screenName: 'Search');

    // Fetch trade signals on initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final agenticTradingProvider =
          Provider.of<AgenticTradingProvider>(context, listen: false);
      agenticTradingProvider.fetchAllTradeSignals();
    });
  }

  @override
  void dispose() {
    searchCtl?.dispose();
    marketCapMinCtl.dispose();
    marketCapMaxCtl.dispose();
    peMinCtl.dispose();
    peMaxCtl.dispose();
    dividendYieldMinCtl.dispose();
    dividendYieldMaxCtl.dispose();
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

    futureMovers ??=
        widget.service.getMovers(widget.brokerageUser, direction: "up");
    futureLosers ??=
        widget.service.getMovers(widget.brokerageUser, direction: "down");
    futureListMovers ??=
        widget.service.getTopMovers(widget.brokerageUser, instrumentStore!);
    // futureListMostPopular ??=
    //     widget.service.getListMostPopular(widget.user, instrumentStore!);
    futureSearch ??= Future.value(null);

    return Column(
      children: [
        Expanded(child: _buildSearchContent()),
      ],
    );
  }

  Widget _buildScreenerPanel() {
    final sectors = [
      'All',
      'Electronic Technology',
      'Consumer Durables',
      'Consumer Non-Durables',
      'Consumer Services',
      'Finance',
      'Health Technology',
      'Miscellaneous',
      'Retail Trade',
      'Technology Services',
      'Transportation',
    ];

    // Keep controllers in sync with state
    marketCapMinCtl.text = screenerMarketCapMin?.toString() ?? '';
    marketCapMaxCtl.text = screenerMarketCapMax?.toString() ?? '';
    peMinCtl.text = screenerPeMin?.toString() ?? '';
    peMaxCtl.text = screenerPeMax?.toString() ?? '';
    dividendYieldMinCtl.text = screenerDividendYieldMin?.toString() ?? '';
    dividendYieldMaxCtl.text = screenerDividendYieldMax?.toString() ?? '';

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 12), // .all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: screenerSector,
            items: sectors
                .map((s) => DropdownMenuItem(
                      value: s == 'All' ? null : s,
                      child: Text(s),
                    ))
                .toList(),
            decoration: InputDecoration(labelText: 'Sector'),
            onChanged: (v) => setState(() => screenerSector = v),
          ),
          SizedBox(height: 12),
          Row(children: [
            Flexible(
              child: TextField(
                controller: marketCapMinCtl,
                decoration: InputDecoration(
                  labelText: 'Market Cap Min (USD)',
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) =>
                    setState(() => screenerMarketCapMin = int.tryParse(v)),
              ),
            ),
            SizedBox(width: 12),
            Flexible(
              child: TextField(
                controller: marketCapMaxCtl,
                decoration: InputDecoration(
                  labelText: 'Market Cap Max (USD)',
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) =>
                    setState(() => screenerMarketCapMax = int.tryParse(v)),
              ),
            ),
          ]),
          SizedBox(height: 12),
          Row(children: [
            Flexible(
              child: TextField(
                controller: peMinCtl,
                decoration: InputDecoration(
                  labelText: 'P/E Min',
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) =>
                    setState(() => screenerPeMin = int.tryParse(v)),
              ),
            ),
            SizedBox(width: 12),
            Flexible(
              child: TextField(
                controller: peMaxCtl,
                decoration: InputDecoration(
                  labelText: 'P/E Max',
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) =>
                    setState(() => screenerPeMax = int.tryParse(v)),
              ),
            ),
          ]),
          SizedBox(height: 12),
          Row(children: [
            Flexible(
              child: TextField(
                controller: dividendYieldMinCtl,
                decoration: InputDecoration(
                  labelText: 'Dividend Yield Min (%)',
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) =>
                    setState(() => screenerDividendYieldMin = int.tryParse(v)),
              ),
            ),
            SizedBox(width: 12),
            Flexible(
              child: TextField(
                controller: dividendYieldMaxCtl,
                decoration: InputDecoration(
                  labelText: 'Dividend Yield Max (%)',
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) =>
                    setState(() => screenerDividendYieldMax = int.tryParse(v)),
              ),
            ),
          ]),
          if (errorText != null) ...[
            SizedBox(height: 8),
            Text(errorText!, style: TextStyle(color: Colors.red)),
          ],
          SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton.icon(
                icon: Icon(Icons.search),
                onPressed: screenerLoading
                    ? null
                    : () async {
                        // Validate min/max fields
                        if (screenerMarketCapMin != null &&
                            screenerMarketCapMax != null &&
                            screenerMarketCapMin! > screenerMarketCapMax!) {
                          setState(() {
                            errorText =
                                'Market Cap Min cannot be greater than Max.';
                          });
                          return;
                        }
                        if (screenerPeMin != null &&
                            screenerPeMax != null &&
                            screenerPeMin! > screenerPeMax!) {
                          setState(() {
                            errorText = 'P/E Min cannot be greater than Max.';
                          });
                          return;
                        }
                        if (screenerDividendYieldMin != null &&
                            screenerDividendYieldMax != null &&
                            screenerDividendYieldMin! >
                                screenerDividendYieldMax!) {
                          setState(() {
                            errorText =
                                'Dividend Yield Min cannot be greater than Max.';
                          });
                          return;
                        }
                        setState(() {
                          screenerLoading = true;
                          errorText = null;
                        });
                        try {
                          final results = await _firestoreService.stockScreener(
                            sector: screenerSector,
                            marketCapMin: screenerMarketCapMin,
                            marketCapMax: screenerMarketCapMax,
                            peMin: screenerPeMin,
                            peMax: screenerPeMax,
                            dividendYieldMin: screenerDividendYieldMin,
                            dividendYieldMax: screenerDividendYieldMax,
                          );
                          setState(() {
                            screenerResults = results;
                            screenerLoading = false;
                            // Keep controllers in sync after results
                            marketCapMinCtl.text =
                                screenerMarketCapMin?.toString() ?? '';
                            marketCapMaxCtl.text =
                                screenerMarketCapMax?.toString() ?? '';
                            peMinCtl.text = screenerPeMin?.toString() ?? '';
                            peMaxCtl.text = screenerPeMax?.toString() ?? '';
                            dividendYieldMinCtl.text =
                                screenerDividendYieldMin?.toString() ?? '';
                            dividendYieldMaxCtl.text =
                                screenerDividendYieldMax?.toString() ?? '';
                          });
                        } catch (e) {
                          setState(() {
                            screenerLoading = false;
                          });
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: SelectableText(
                                      'Error running screener: $e')),
                            );
                          }
                        }
                      },
                label: Text('Run Screener'),
              ),
              if (screenerLoading) ...[
                SizedBox(width: 16),
                SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ]
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScreenerSliver() {
    if (screenerLoading) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return SliverStickyHeader(
      header: Material(
        child: Container(
          alignment: Alignment.centerLeft,
          child: Column(
            children: [
              const ListTile(
                title: Text(
                  "Screener",
                  style: TextStyle(fontSize: 19.0),
                ),
              ),
            ],
          ),
        ),
      ),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          _buildScreenerPanel(),
          if (screenerResults != null && screenerResults!.isNotEmpty)
            GridView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.all(8),
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 150.0,
                mainAxisSpacing: 6.0,
                crossAxisSpacing: 2.0,
                childAspectRatio: 1.4,
              ),
              itemCount: screenerResults!.length,
              itemBuilder: (BuildContext context, int gridIndex) {
                return _buildListGridItem(
                    screenerResults!, gridIndex, widget.brokerageUser);
              },
            )
          else if (screenerResults != null && screenerResults!.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No results found.',
                    style: TextStyle(color: Colors.grey)),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _buildYahooScreenerSliver() {
    return SliverStickyHeader(
      header: Material(
        child: Container(
          alignment: Alignment.centerLeft,
          child: const ListTile(
            title: Text(
              "Presets",
              style: TextStyle(fontSize: 19.0),
            ),
          ),
        ),
      ),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          _buildYahooScreenerPanel(),
          if (yahooScreenerLoading) ...[
            const SizedBox(height: 12),
            const Center(child: CircularProgressIndicator()),
          ],
          if (yahooScreenerError != null) ...[
            const SizedBox(height: 8),
            Text('Error: $yahooScreenerError',
                style: const TextStyle(color: Colors.red)),
          ],
          if (yahooScreenerResults != null) ...[
            Builder(
              builder: (context) {
                final records = yahooScreenerResults['finance']?['result']?[0]
                        ?['records'] ??
                    [];
                if (records.isEmpty) {
                  return const Center(child: Text('No results found.'));
                }
                return ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(4.0),
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: records.length,
                  // separatorBuilder: (context, idx) => const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final item = records[idx];
                    return ListTile(
                        // leading: item['logo_url'] != null
                        //     ? Image.network(item['logo_url'],
                        //         width: 32,
                        //         height: 32,
                        //         errorBuilder: (c, e, s) =>
                        //             const Icon(Icons.image_not_supported))
                        //     : const Icon(Icons.business),
                        title: Text(item['companyName'] ?? item['ticker'] ?? '',
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(item['ticker'] ?? '',
                            style: const TextStyle(fontSize: 13)),
                        trailing: item['regularMarketPrice'] != null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    formatCurrency.format(
                                        item['regularMarketPrice']['raw']),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.normal,
                                        fontSize: 16),
                                  ),
                                  if (item['regularMarketChangePercent'] !=
                                      null)
                                    Text(
                                      formatPercentage.format(
                                          item['regularMarketChangePercent']
                                                  ['raw'] /
                                              100),
                                      style: TextStyle(
                                        color:
                                            (item['regularMarketChangePercent']
                                                            ['raw'] ??
                                                        0) >=
                                                    0
                                                ? Colors.green
                                                : Colors.red,
                                        fontSize: 14,
                                      ),
                                    ),
                                ],
                              )
                            : null,
                        onTap: () async {
                          var instrument = await widget.service
                              .getInstrumentBySymbol(
                                  widget.brokerageUser,
                                  Provider.of<InstrumentStore>(context,
                                      listen: false),
                                  item['ticker']);
                          if (instrument != null) {
                            if (context.mounted) {
                              Navigator.of(context)
                                  .push(MaterialPageRoute(builder: (context) {
                                return InstrumentWidget(
                                  widget.brokerageUser,
                                  widget.service,
                                  instrument,
                                  analytics: widget.analytics,
                                  observer: widget.observer,
                                  generativeService: widget.generativeService,
                                );
                              }));
                            }
                          }
                        });
                  },
                );
              },
            ),
          ],
        ]),
      ),
    );
  }

  Widget _buildYahooScreenerPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<ScreenerId>(
            value: selectedYahooScreener,
            items: YahooService.scrIds
                .map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(s.display),
                    ))
                .toList(),
            onChanged: (v) async {
              setState(() => selectedYahooScreener = v);
              setState(() {
                yahooScreenerLoading = true;
                yahooScreenerError = null;
                yahooScreenerResults = null;
              });
              try {
                final result = await yahooService.getStockScreener(
                  scrIds: selectedYahooScreener!.id,
                );
                setState(() {
                  yahooScreenerResults = result;
                  yahooScreenerLoading = false;
                });
              } catch (e) {
                setState(() {
                  yahooScreenerError = e.toString();
                  yahooScreenerLoading = false;
                });
              }
            },
            decoration: const InputDecoration(labelText: 'Screener'),
          ),
          const SizedBox(height: 12),
          // ElevatedButton.icon(
          //   icon: Icon(Icons.search),
          //   onPressed: selectedYahooScreener == null || yahooScreenerLoading
          //       ? null
          //       : () async {
          //           setState(() {
          //             yahooScreenerLoading = true;
          //             yahooScreenerError = null;
          //             yahooScreenerResults = null;
          //           });
          //           try {
          //             final result = await yahooService.getStockScreener(
          //               scrIds: selectedYahooScreener!.id,
          //             );
          //             setState(() {
          //               yahooScreenerResults = result;
          //               yahooScreenerLoading = false;
          //             });
          //           } catch (e) {
          //             setState(() {
          //               yahooScreenerError = e.toString();
          //               yahooScreenerLoading = false;
          //             });
          //           }
          //         },
          //   label: const Text('Run Screener'),
          // ),
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
                      title: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0),
                          child: TextField(
                              controller: searchCtl,
                              decoration: InputDecoration(
                                hintText: 'Search by name or symbol',
                                hintStyle: TextStyle(
                                    fontSize: 18, color: Colors.grey.shade200
                                    //fontStyle: FontStyle.italic,
                                    ),
                              ),
                              style: TextStyle(
                                  fontSize: 18, color: Colors.grey.shade200
                                  //fontStyle: FontStyle.italic,
                                  ),
                              onChanged: (text) {
                                widget.analytics.logSearch(searchTerm: text);
                                setState(() {
                                  futureSearch = widget.service
                                      .search(widget.brokerageUser, text);
                                });
                              })),
                      //expandedHeight: 80.0,
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
                                  widget.brokerageUser);
                              if (response != null) {
                                setState(() {});
                              }
                            })
                      ]),
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
                  if (welcomeWidget != null) ...[
                    SliverToBoxAdapter(
                        child: SizedBox(
                      height: 150.0,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Align(
                            alignment: Alignment.center, child: welcomeWidget),
                      ),
                    ))
                  ],
                  if (search != null) ...[
                    SliverStickyHeader(
                        header: Material(
                            //elevation: 2,
                            child: Container(
                                alignment: Alignment.centerLeft,
                                child: const ListTile(
                                  title: Text(
                                    "Search Results",
                                    style: TextStyle(fontSize: 19.0),
                                  ),
                                  //subtitle: Text(
                                  //    "${formatCompactNumber.format(filteredPositionOrders!.length)} of ${formatCompactNumber.format(positionOrders.length)} orders $orderDateFilterDisplay ${positionOrdersBalance > 0 ? "+" : positionOrdersBalance < 0 ? "-" : ""}${formatCurrency.format(positionOrdersBalance.abs())}"),
                                ))),
                        sliver: SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 125.0,
                                mainAxisSpacing: 10.0,
                                crossAxisSpacing: 10.0,
                                childAspectRatio: 1.25,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (BuildContext context, int index) {
                                  return _buildSearchGridItem(search, index);
                                },
                                childCount: search["results"][0]["content"]
                                        ["data"]
                                    .length,
                              ),
                            ))),
                    const SliverToBoxAdapter(
                        child: SizedBox(
                      height: 25.0,
                    )),
                  ],
                  _buildScreenerSliver(),
                  _buildYahooScreenerSliver(),
                  Consumer<AgenticTradingProvider>(
                    builder: (context, agenticTradingProvider, child) {
                      final tradeSignals = agenticTradingProvider.tradeSignals;
                      if (tradeSignals.isEmpty) {
                        return const SliverToBoxAdapter(
                            child: SizedBox.shrink());
                      }
                      return SliverStickyHeader(
                          header: Material(
                              //elevation: 2,
                              child: Container(
                                  alignment: Alignment.centerLeft,
                                  child: const ListTile(
                                    title: Wrap(children: [
                                      Text(
                                        "Trade Signals",
                                        style: TextStyle(fontSize: 19.0),
                                      ),
                                    ]),
                                  ))),
                          sliver: SliverPadding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 2),
                              sliver: SliverGrid(
                                gridDelegate:
                                    const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 220.0,
                                  mainAxisSpacing: 10.0,
                                  crossAxisSpacing: 10.0,
                                  childAspectRatio: 1.3,
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  (BuildContext context, int index) {
                                    return _buildTradeSignalGridItem(
                                        tradeSignals, index);
                                  },
                                  childCount: tradeSignals.length,
                                ),
                              )));
                    },
                  ),

                  if (movers != null && movers.isNotEmpty) ...[
                    SliverStickyHeader(
                        header: Material(
                            //elevation: 2,
                            child: Container(
                                alignment: Alignment.centerLeft,
                                child: const ListTile(
                                  title: Wrap(children: [
                                    Text(
                                      "S&P Movers",
                                      style: TextStyle(fontSize: 19.0),
                                    ),
                                    Icon(Icons.trending_up,
                                        color: Colors.green, size: 28)
                                  ]),
                                ))),
                        sliver: SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 220.0,
                                mainAxisSpacing: 10.0,
                                crossAxisSpacing: 10.0,
                                childAspectRatio: 1.32,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (BuildContext context, int index) {
                                  return _buildMoversGridItem(movers, index);
                                },
                                childCount: movers.length,
                              ),
                            ))),
                    const SliverToBoxAdapter(
                        child: SizedBox(
                      height: 25.0,
                    )),
                  ],
                  if (losers != null && losers.isNotEmpty) ...[
                    SliverStickyHeader(
                        header: Material(
                            //elevation: 2,
                            child: Container(
                                alignment: Alignment.centerLeft,
                                child: const ListTile(
                                  title: Wrap(children: [
                                    Text(
                                      "S&P Movers",
                                      style: TextStyle(fontSize: 19.0),
                                    ),
                                    Icon(Icons.trending_down,
                                        color: Colors.red, size: 28)
                                  ]),
                                ))),
                        sliver: SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 220.0,
                                mainAxisSpacing: 10.0,
                                crossAxisSpacing: 10.0,
                                childAspectRatio: 1.32,
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
                            //elevation: 2,
                            child: Container(
                                alignment: Alignment.centerLeft,
                                child: const ListTile(
                                  title: Wrap(children: [
                                    Text(
                                      "Top Movers",
                                      style: TextStyle(fontSize: 19.0),
                                    ),
                                  ]),
                                ))),
                        sliver: SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 150.0,
                                mainAxisSpacing: 6.0,
                                crossAxisSpacing: 2.0,
                                childAspectRatio: 1.4,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (BuildContext context, int index) {
                                  return _buildListGridItem(
                                      listMovers, index, widget.brokerageUser);
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
                            //elevation: 2,
                            child: Container(
                                alignment: Alignment.centerLeft,
                                child: const ListTile(
                                  title: Wrap(children: [
                                    Text(
                                      "100 Most Popular",
                                      style: TextStyle(fontSize: 19.0),
                                    ),
                                  ]),
                                ))),
                        sliver: SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 150.0,
                                mainAxisSpacing: 6.0,
                                crossAxisSpacing: 2.0,
                                childAspectRatio: 1.22,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (BuildContext context, int index) {
                                  return _buildListGridItem(listMostPopular,
                                      index, widget.brokerageUser);
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
    final agenticTradingProvider =
        Provider.of<AgenticTradingProvider>(context, listen: false);
    await agenticTradingProvider.fetchAllTradeSignals();
  }

  Widget _buildMoversGridItem(List<MidlandMoversItem> movers, int index) {
    // var instrument = await RobinhoodService.getInstrument(
    //     widget.user, instrumentStore!, movers[index].instrumentUrl);
    // movers[index].instrumentObj = instrument;
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(6), //.symmetric(horizontal: 6),
            child: InkWell(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // movers[index].instrumentObj != null &&
                    //         movers[index].instrumentObj!.logoUrl != null
                    //     ? Image.network(
                    //         movers[index].instrumentObj!.logoUrl!,
                    //         width: 40,
                    //         height: 40,
                    //         errorBuilder: (BuildContext context,
                    //             Object exception, StackTrace? stackTrace) {
                    //           //RobinhoodService.removeLogo(instrument.symbol);
                    //           return Text(movers[index].instrumentObj!.symbol);
                    //         },
                    //       )
                    //     : SizedBox(height: 40, width: 40),
                    Text(movers[index].symbol,
                        style: const TextStyle(fontSize: 17.0),
                        overflow: TextOverflow.ellipsis),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Icon(
                            movers[index].marketHoursPriceMovement! > 0
                                ? Icons.trending_up
                                : (movers[index].marketHoursPriceMovement! < 0
                                    ? Icons.trending_down
                                    : Icons.trending_flat),
                            color: (movers[index].marketHoursPriceMovement! > 0
                                ? Colors.green
                                : (movers[index].marketHoursPriceMovement! < 0
                                    ? Colors.red
                                    : Colors.grey)),
                            size: 20),
                        Container(
                          width: 2,
                        ),
                        Text(
                            formatPercentage.format(
                                movers[index].marketHoursPriceMovement!.abs() /
                                    100),
                            style: const TextStyle(fontSize: 16.0)),
                        Container(
                          width: 10,
                        ),
                        Text(
                            formatCurrency
                                .format(movers[index].marketHoursLastPrice),
                            style: const TextStyle(fontSize: 16.0)),
                      ],
                    ),
                    Container(
                      height: 5,
                    ),
                    Expanded(
                      child: Text(movers[index].description,
                          style: const TextStyle(fontSize: 12.0),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
              onTap: () async {
                var instrument = await widget.service.getInstrument(
                    widget.brokerageUser,
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
                              widget.brokerageUser,
                              widget.service,
                              instrument,
                              analytics: widget.analytics,
                              observer: widget.observer,
                              generativeService: widget.generativeService,
                            )));
              },
            )));
  }

  Widget _buildSearchGridItem(dynamic search, int index) {
    var data = search["results"][0]["content"]["data"][index];
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(6), //.symmetric(horizontal: 6),
            child: InkWell(
                child:
                    Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                  Text(data["item"]["symbol"],
                      style: const TextStyle(fontSize: 16.0)),
                  Text(data["item"]["simple_name"] ?? data["item"]["name"],
                      style: const TextStyle(fontSize: 12.0),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis)
                ]),
                onTap: () {
                  var instrument = Instrument.fromJson(data["item"]);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => InstrumentWidget(
                                widget.brokerageUser,
                                widget.service,
                                instrument,
                                analytics: widget.analytics,
                                observer: widget.observer,
                                generativeService: widget.generativeService,
                              )));
                })));
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
    final signalType = signal['signal'] ?? 'HOLD';
    final reason = signal['reason'] ?? 'No reason provided';

    return Card(
        child: Padding(
            padding: const EdgeInsets.all(6), //.symmetric(horizontal: 6),
            child: InkWell(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(symbol,
                        style: const TextStyle(fontSize: 17.0),
                        overflow: TextOverflow.ellipsis),
                    Text(formatDate.format(timestamp),
                        style: const TextStyle(
                            fontSize: 15.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey),
                        overflow: TextOverflow.ellipsis),
                    Container(
                      height: 4,
                    ),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Icon(
                            signalType == 'BUY'
                                ? Icons.trending_up
                                : (signalType == 'SELL'
                                    ? Icons.trending_down
                                    : Icons.trending_flat),
                            color: (signalType == 'BUY'
                                ? Colors.green
                                : (signalType == 'SELL'
                                    ? Colors.red
                                    : Colors.grey)),
                            size: 20),
                        Container(
                          width: 2,
                        ),
                        Text(signalType,
                            style: const TextStyle(fontSize: 16.0)),
                      ],
                    ),
                    Container(
                      height: 5,
                    ),
                    Expanded(
                      child: Text(reason,
                          style: const TextStyle(fontSize: 12.0),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
              onTap: () async {
                final symbol = signal['symbol'];
                if (symbol == null || symbol == 'N/A') return;
                var instrument = await widget.service.getInstrumentBySymbol(
                    widget.brokerageUser, instrumentStore!, symbol);

                if (!mounted || instrument == null) return;
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => InstrumentWidget(
                              widget.brokerageUser,
                              widget.service,
                              instrument,
                              analytics: widget.analytics,
                              observer: widget.observer,
                              generativeService: widget.generativeService,
                            )));
              },
            )));
  }

  Widget _buildListGridItem(
      List<Instrument> instruments, int index, BrokerageUser user) {
    var instrumentObj = instruments[index];
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(6), //.symmetric(horizontal: 6),
            child: InkWell(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // instrumentObj.logoUrl != null
                    //     ? Image.network(
                    //         instrumentObj.logoUrl!,
                    //         width: 40,
                    //         height: 40,
                    //         errorBuilder: (BuildContext context, Object exception,
                    //             StackTrace? stackTrace) {
                    //           //RobinhoodService.removeLogo(instrument.symbol);
                    //           return Text(instrumentObj.symbol);
                    //         },
                    //       )
                    //     : SizedBox(height: 40, width: 40),
                    Text(instrumentObj.symbol,
                        style: const TextStyle(fontSize: 16.0),
                        overflow: TextOverflow.ellipsis),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (instrumentObj.quoteObj != null) ...[
                          Icon(
                              instrumentObj.quoteObj!.changeToday > 0
                                  ? Icons.trending_up
                                  : (instrumentObj.quoteObj!.changeToday < 0
                                      ? Icons.trending_down
                                      : Icons.trending_flat),
                              color: (instrumentObj.quoteObj!.changeToday > 0
                                  ? Colors.green
                                  : (instrumentObj.quoteObj!.changeToday < 0
                                      ? Colors.red
                                      : Colors.grey)),
                              size: 20),
                        ],
                        Container(
                          width: 2,
                        ),
                        if (instrumentObj.quoteObj != null) ...[
                          Text(
                              formatPercentage.format(instrumentObj
                                  .quoteObj!.changePercentToday
                                  .abs()),
                              style: const TextStyle(fontSize: 16.0)),
                        ],
                      ],
                    ),
                    Container(
                      height: 5,
                    ),
                    if (instrumentObj.quoteObj != null) ...[
                      Text(
                          formatPercentage.format(
                              instrumentObj.quoteObj!.changePercentToday.abs()),
                          style: const TextStyle(fontSize: 16.0)),
                    ],
                  ],
                ),
                Container(
                  height: 5,
                ),
                Wrap(children: [
                  Text(instrumentObj.simpleName ?? instrumentObj.name,
                      style: const TextStyle(fontSize: 12.0),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)
                ]),
                /*
                if (instrumentObj.fundamentalsObj != null) ...[
                  Container(
                    height: 5,
                  ),
                  Wrap(children: [
                    Text(instrumentObj.fundamentalsObj!.description,
                        style: const TextStyle(fontSize: 12.0),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis)
                  ]),
                ]
                  */
                  ]),
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
                              widget.service,
                              instrumentObj,
                              analytics: widget.analytics,
                              observer: widget.observer,
                              generativeService: widget.generativeService,
                            )));
              },
            )));
  }
}
