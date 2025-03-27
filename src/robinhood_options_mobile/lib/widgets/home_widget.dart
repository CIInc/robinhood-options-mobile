import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:collection/collection.dart';
//import 'package:charts_flutter/flutter.dart' as charts;
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/main.dart';
// import 'dart:math' as math;

import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/chart_selection_store.dart';
import 'package:robinhood_options_mobile/model/dividend_store.dart';
import 'package:robinhood_options_mobile/model/equity_historical.dart';
import 'package:robinhood_options_mobile/model/forex_holding.dart';
import 'package:robinhood_options_mobile/model/forex_holding_store.dart';
import 'package:robinhood_options_mobile/model/generative_provider.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/interest_store.dart';
import 'package:robinhood_options_mobile/model/option_instrument_store.dart';
import 'package:robinhood_options_mobile/model/portfolio.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals_selection_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_store.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/model/user_info.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/yahoo_service.dart';
import 'package:robinhood_options_mobile/widgets/ad_banner_widget.dart';
import 'package:robinhood_options_mobile/widgets/chart_pie_widget.dart';
import 'package:robinhood_options_mobile/widgets/chart_time_series_widget.dart';
import 'package:robinhood_options_mobile/widgets/disclaimer_widget.dart';
import 'package:robinhood_options_mobile/widgets/forex_positions_widget.dart';
import 'package:robinhood_options_mobile/widgets/income_transactions_widget.dart';
import 'package:robinhood_options_mobile/widgets/instrument_positions_widget.dart';
import 'package:robinhood_options_mobile/widgets/more_menu_widget.dart';
import 'package:robinhood_options_mobile/widgets/option_positions_widget.dart';
import 'package:robinhood_options_mobile/widgets/sliverappbar_widget.dart';

/*
class DrawerItem {
  String title;
  IconData icon;
  DrawerItem(this.title, this.icon);
}
*/
class HomePage extends StatefulWidget {
  final BrokerageUser brokerageUser;
  final UserInfo userInfo;
  final IBrokerageService service;
  final GenerativeService generativeService;

  final User? user;
  final DocumentReference? userDoc;
  //final Account account;
  /*
  final drawerItems = [
    new DrawerItem("Home", Icons.home),
    //new DrawerItem("Account", Icons.verified_user),
    new DrawerItem("Options", Icons.library_books),
    new DrawerItem("Logout", Icons.logout),
  ];
  */

  const HomePage(
    this.brokerageUser,
    this.userInfo, // this.account,
    this.service, {
    super.key,
    required this.analytics,
    required this.observer,
    required this.generativeService,
    this.title,
    this.navigatorKey,
    this.user,
    this.userDoc,
    //required this.onUserChanged,
    //required this.onAccountsChanged
  });

  final GlobalKey<NavigatorState>? navigatorKey;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  //final ValueChanged<RobinhoodUser?> onUserChanged;

  //final ValueChanged<List<Account>> onAccountsChanged;

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String? title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver
//with AutomaticKeepAliveClientMixin<HomePage>
{
  Future<List<Account>>? futureAccounts;
  // final List<Account>? accounts = [];
  Account? account;

  Future<List<ForexHolding>>? futureNummusHoldings;
  List<ForexHolding>? nummusHoldings;

  Future<List<Portfolio>>? futurePortfolios;

  Future<PortfolioHistoricals>? futurePortfolioHistoricals;
  PortfolioHistoricals? portfolioHistoricals;

  List<charts.Series<dynamic, DateTime>>? seriesList;
  ChartDateSpan chartDateSpanFilter = ChartDateSpan.day;
  Bounds chartBoundsFilter = Bounds.t24_7;
  ChartDateSpan prevChartDateSpanFilter = ChartDateSpan.day;
  Bounds prevChartBoundsFilter = Bounds.t24_7;
  // EquityHistorical? selection;
  bool animateChart = true;

  Future<List<dynamic>>? futureDividends;
  Future<List<dynamic>>? futureInterests;

  Future<PortfolioHistoricals>? futurePortfolioHistoricalsYear;
  Future<dynamic>? futureMarketIndexHistoricalsSp500;
  Future<dynamic>? futureMarketIndexHistoricalsNasdaq;
  Future<dynamic>? futureMarketIndexHistoricalsDow;
  // final marketIndexHistoricalsNotifier = ValueNotifier<dynamic>(null);

  Future<InstrumentPositionStore>? futureStockPositions;
  //Stream<StockPositionStore>? positionStoreStream;
  Future<OptionPositionStore>? futureOptionPositions;
  //Stream<OptionPositionStore>? optionPositionStoreStream;

  /*
  Stream<List<StockPosition>>? positionStream;
  List<StockPosition> positions = [];
  Stream<List<InstrumentOrder>>? positionOrderStream;

  Stream<List<OptionAggregatePosition>>? optionPositionStream;
  List<OptionAggregatePosition> optionPositions = [];
  Stream<List<OptionOrder>>? optionOrderStream;
  */

  List<String> positionSymbols = [];
  List<String> chainSymbols = [];
  List<String> cryptoSymbols = [];

  List<String> optionSymbolFilters = <String>[];
  List<String> stockSymbolFilters = <String>[];

  List<String> optionFilters = <String>[];
  List<String> positionFilters = <String>[];
  List<String> cryptoFilters = <String>[];
  List<bool> hasQuantityFilters = [true, false];

  Timer? refreshTriggerTime;
  AppLifecycleState? _notification;

  late final CarouselController _carouselController;
  // late final Timer _carouselTimer;

  _HomePageState();

  /*
  @override
  bool get wantKeepAlive => true;
  */

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      _notification = state;
      debugPrint('AppLifecycleState: $state');
      // if (state == AppLifecycleState.resumed) {
      //   _refresh();
      // }
    });
  }

  @override
  void initState() {
    super.initState();

    _startRefreshTimer();
    WidgetsBinding.instance.addObserver(this);

    _carouselController = CarouselController();
    // _carouselTimer = Timer.periodic(
    //   const Duration(seconds: 4),
    //   (_) => _animateToNextItem(),
    // );

    widget.analytics.logScreenView(
      screenName: 'Home',
    );
  }

  @override
  void dispose() {
    // _carouselTimer.cancel();
    _carouselController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _stopRefreshTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    //super.build(context);

    /*
    return Navigator(
        key: widget.navigatorKey,
        onGenerateRoute: (_) =>
            MaterialPageRoute(builder: (_) => _buildScaffold()));
            */
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
    // Commented out, the BrokerageUserStore change detection occurs one level up at NavigationStatefulWidget which will pass in the new user in the ctor.
    // Provider.of<BrokerageUserStore>(context, listen: true);

    futureAccounts = widget.service.getAccounts(
        widget.brokerageUser,
        Provider.of<AccountStore>(context, listen: false),
        Provider.of<PortfolioStore>(context, listen: false),
        Provider.of<OptionPositionStore>(context, listen: false),
        instrumentPositionStore:
            Provider.of<InstrumentPositionStore>(context, listen: false),
        userDoc: widget.userDoc);

    if (widget.brokerageUser.source == BrokerageSource.robinhood ||
        widget.brokerageUser.source == BrokerageSource.demo) {
      futurePortfolios = widget.service.getPortfolios(widget.brokerageUser,
          Provider.of<PortfolioStore>(context, listen: false));
      futureNummusHoldings = widget.service.getNummusHoldings(
          widget.brokerageUser,
          Provider.of<ForexHoldingStore>(context, listen: false),
          nonzero: !hasQuantityFilters[1],
          userDoc: widget.userDoc);

      futureOptionPositions = widget.service.getOptionPositionStore(
          widget.brokerageUser,
          Provider.of<OptionPositionStore>(context, listen: false),
          Provider.of<InstrumentStore>(context, listen: false),
          nonzero: !hasQuantityFilters[1],
          userDoc: widget.userDoc);

      futureStockPositions = widget.service.getStockPositionStore(
          widget.brokerageUser,
          Provider.of<InstrumentPositionStore>(context, listen: false),
          Provider.of<InstrumentStore>(context, listen: false),
          Provider.of<QuoteStore>(context, listen: false),
          nonzero: !hasQuantityFilters[1],
          userDoc: widget.userDoc);
    }
    /*
    positionStoreStream = widget.service.streamStockPositionStore(
        widget.user,
        Provider.of<StockPositionStore>(context, listen: false),
        Provider.of<InstrumentStore>(context, listen: false),
        Provider.of<QuoteStore>(context, listen: false),
        nonzero: !hasQuantityFilters[1]);
    optionPositionStoreStream = widget.service.streamOptionPositionStore(
        widget.user,
        Provider.of<OptionPositionStore>(context, listen: false),
        Provider.of<InstrumentStore>(context, listen: false),
        nonzero: !hasQuantityFilters[1]);
        */

    return FutureBuilder(
      future: Future.wait([
        futureAccounts as Future,
        //futurePortfolios as Future,
        //futureNummusHoldings as Future,
        // myBanner.load()
      ]),
      builder: (context1, dataSnapshot) {
        if (dataSnapshot.hasData &&
            dataSnapshot.connectionState == ConnectionState.done) {
          List<dynamic> data = dataSnapshot.data as List<dynamic>;
          List<Account> accts = data[0] as List<Account>;
          if (accts.isNotEmpty) {
            account = accts[0];
          } else {
            account = null;
          }

          // for (var acct in accts) {
          //   var existingAccount = accounts!.firstWhereOrNull((element) =>
          //       element.userId == widget.user.id &&
          //       element.accountNumber == acct.accountNumber);
          //   if (existingAccount == null) {
          //     accounts!.add(acct);
          //     /*
          //     WidgetsBinding.instance.addPostFrameCallback(
          //         (_) => widget.onAccountsChanged(accounts!));
          //         */
          //     account = acct;
          //   }
          // }

          if (widget.brokerageUser.source == BrokerageSource.schwab) {
            // futurePortfolios = widget.service.getPortfolios(
            //     widget.user, Provider.of<PortfolioStore>(context, listen: false));
            // futureNummusHoldings = widget.service.getNummusHoldings(
            //     widget.user, Provider.of<ForexHoldingStore>(context, listen: false),
            //     nonzero: !hasQuantityFilters[1]);

            // futureOptionPositions = widget.service.getOptionPositionStore(
            //     widget.user,
            //     Provider.of<OptionPositionStore>(context, listen: false),
            //     Provider.of<InstrumentStore>(context, listen: false),
            //     nonzero: !hasQuantityFilters[1]);

            futureStockPositions = widget.service.getStockPositionStore(
                widget.brokerageUser,
                Provider.of<InstrumentPositionStore>(context, listen: false),
                Provider.of<InstrumentStore>(context, listen: false),
                Provider.of<QuoteStore>(context, listen: false),
                nonzero: !hasQuantityFilters[1],
                userDoc: widget.userDoc);
          }

          if (widget.brokerageUser.source == BrokerageSource.robinhood ||
              widget.brokerageUser.source == BrokerageSource.demo) {
            futurePortfolioHistoricals = widget.service.getPortfolioHistoricals(
                widget.brokerageUser,
                Provider.of<PortfolioHistoricalsStore>(context, listen: false),
                account!.accountNumber,
                chartBoundsFilter,
                chartDateSpanFilter);

            futurePortfolioHistoricalsYear = widget.service
                .getPortfolioHistoricals(
                    widget.brokerageUser,
                    Provider.of<PortfolioHistoricalsStore>(context,
                        listen: false),
                    account!.accountNumber,
                    chartBoundsFilter,
                    ChartDateSpan.ytd);

            // Future.delayed(Duration(seconds: 1), () {
            //   if (mounted) {
            futureDividends = widget.service.getDividends(
              widget.brokerageUser,
              Provider.of<DividendStore>(context, listen: false),
              Provider.of<InstrumentStore>(context, listen: false),
            );
            //   }
            // });
            futureInterests = widget.service.getInterests(
              widget.brokerageUser,
              Provider.of<InterestStore>(context, listen: false),
            );
          } else {
            // Needed when switching users or linking new
            futurePortfolioHistoricals = null;
            futurePortfolioHistoricalsYear = null;
            futureDividends = null;
            futureInterests = null;
          }
          /*
          return MultiProvider(
              providers: [
                StreamProvider<StockPositionStore>.value(
                  value: positionStoreStream,
                  initialData: StockPositionStore(),
                ),
                StreamProvider<OptionPositionStore>.value(
                  value: optionPositionStoreStream,
                  initialData: OptionPositionStore(),
                )
              ],
              builder: (BuildContext context, Widget? subwidget) {
                */
          return _buildPage(context,
              userInfo: widget.userInfo,
              account: account,
              done: dataSnapshot.connectionState == ConnectionState.done);
          //});
        } else if (dataSnapshot.hasError) {
          debugPrint("${dataSnapshot.error}");
          return _buildPage(context,
              //ru: snapshotUser,
              welcomeWidget: Text("${dataSnapshot.error}"),
              done: dataSnapshot.connectionState == ConnectionState.done);
        } else {
          return _buildPage(context);
        }
      },
    );

    /*
      floatingActionButton:
          (robinhoodUser != null && widget.user.userName != null)
              ? FloatingActionButton(
                  onPressed: _generateCsvFile,
                  tooltip: 'Export to CSV',
                  child: const Icon(Icons.download),
                )
              : null,
              */
  }

  Widget _buildPage(BuildContext context,
      {
      //List<Portfolio>? portfolios,
      UserInfo? userInfo,
      Account? account,
      //List<ForexHolding>? nummusHoldings,
      Widget? welcomeWidget,
      //PortfolioHistoricals? portfolioHistoricals,
      //List<OptionAggregatePosition>? optionPositions,
      //List<StockPosition>? positions,
      bool done = false}) {
    // var indices = RobinhoodService().getMarketIndices(user: widget.user);
    final yahooService = YahooService();
    futureMarketIndexHistoricalsSp500 =
        yahooService.getMarketIndexHistoricals(symbol: '^GSPC'); // ^IXIC
    futureMarketIndexHistoricalsNasdaq =
        yahooService.getMarketIndexHistoricals(symbol: '^IXIC');
    futureMarketIndexHistoricalsDow =
        yahooService.getMarketIndexHistoricals(symbol: '^DJI');
    //debugPrint('_buildPage');
    return RefreshIndicator(
      onRefresh: _pullRefresh,
      child: CustomScrollView(
          // physics: ClampingScrollPhysics(),
          slivers: [
            ExpandedSliverAppBar(
              title: Text(widget.title!),
              auth: auth,
              firestoreService: FirestoreService(),
              automaticallyImplyLeading: true,
              onChange: () {
                setState(() {});
              },
              analytics: widget.analytics,
              observer: widget.observer,
              user: widget.brokerageUser,
            ),

            if (welcomeWidget != null) ...[
              const SliverToBoxAdapter(
                  child: SizedBox(
                height: 25.0,
              )),
              SliverToBoxAdapter(
                  child: SizedBox(
                height: 150.0,
                child: Align(alignment: Alignment.center, child: welcomeWidget),
              ))
            ],
            Consumer5<PortfolioStore, InstrumentPositionStore,
                    OptionPositionStore, ForexHoldingStore, GenerativeProvider>(
                builder: (context,
                    portfolioStore,
                    stockPositionStore,
                    optionPositionStore,
                    forexHoldingStore,
                    generativeProvider,
                    child) {
              return SliverToBoxAdapter(
                child: ExpansionTile(
                  shape: const Border(),
                  leading: const CircleAvatar(
                      // radius: 20,
                      child: Icon(Icons.lightbulb_circle_outlined)),
                  title: Text(
                    'AI Insight',
                    overflow: TextOverflow.ellipsis,
                  ),
                  // subtitle: Text(metadata != null
                  //         ? constants
                  //             .formatLongDateTime
                  //             .format(metadata
                  //                 .timeCreated!)
                  //         : ''
                  //     // '${metadata != null ? constants.formatLongDateTime.format(metadata.timeCreated!) : ''} extension ${videoRef.name.substring(videoRef.name.lastIndexOf('.'))}',
                  //     // overflow: TextOverflow.ellipsis,
                  //     ),
                  children: [
                    SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(
                            12.0,
                            0, // 16.0,
                            16.0,
                            0),
                        // padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Column(
                          children: [
                            Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: ActionChip(
                                      avatar: generativeProvider.generating &&
                                              generativeProvider.promptResponses
                                                  .containsKey(
                                                      'portfolio-summary') &&
                                              generativeProvider
                                                          .promptResponses[
                                                      'portfolio-summary'] ==
                                                  null
                                          ? const CircularProgressIndicator()
                                          : const Icon(
                                              Icons.summarize_outlined),
                                      label: const Text('Portfolio Summary'),
                                      onPressed: () async {
                                        await generateContent(
                                            generativeProvider,
                                            widget.generativeService.prompts
                                                .firstWhere((p) =>
                                                    p.key ==
                                                    'portfolio-summary'),
                                            stockPositionStore,
                                            optionPositionStore,
                                            forexHoldingStore,
                                            context);
                                      },
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: ActionChip(
                                      avatar: generativeProvider.generating &&
                                              generativeProvider.promptResponses
                                                  .containsKey(
                                                      'portfolio-recommendations') &&
                                              generativeProvider
                                                          .promptResponses[
                                                      'portfolio-recommendations'] ==
                                                  null
                                          ? const CircularProgressIndicator()
                                          : const Icon(
                                              Icons.recommend_outlined),
                                      label: const Text('Recommendations'),
                                      onPressed: () async {
                                        await generateContent(
                                            generativeProvider,
                                            widget.generativeService.prompts
                                                .firstWhere((p) =>
                                                    p.key ==
                                                    'portfolio-recommendations'),
                                            stockPositionStore,
                                            optionPositionStore,
                                            forexHoldingStore,
                                            context);
                                      },
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: ActionChip(
                                      avatar: generativeProvider.generating &&
                                              generativeProvider.promptResponses
                                                  .containsKey(
                                                      'market-summary') &&
                                              generativeProvider
                                                          .promptResponses[
                                                      'market-summary'] ==
                                                  null
                                          ? const CircularProgressIndicator()
                                          : const Icon(Icons.public),
                                      label: const Text('Market Summary'),
                                      onPressed: () async {
                                        await generateContent(
                                            generativeProvider,
                                            widget.generativeService.prompts
                                                .firstWhere((p) =>
                                                    p.key == 'market-summary'),
                                            stockPositionStore,
                                            optionPositionStore,
                                            forexHoldingStore,
                                            context);
                                      },
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: ActionChip(
                                      avatar: generativeProvider.generating &&
                                              generativeProvider.promptResponses
                                                  .containsKey(
                                                      'market-predictions') &&
                                              generativeProvider
                                                          .promptResponses[
                                                      'market-predictions'] ==
                                                  null
                                          ? const CircularProgressIndicator()
                                          : const Icon(
                                              Icons.batch_prediction_outlined),
                                      label: const Text('Market Predictions'),
                                      onPressed: () async {
                                        await generateContent(
                                            generativeProvider,
                                            widget.generativeService.prompts
                                                .firstWhere((p) =>
                                                    p.key ==
                                                    'market-predictions'),
                                            stockPositionStore,
                                            optionPositionStore,
                                            forexHoldingStore,
                                            context);
                                      },
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: ActionChip(
                                      avatar: generativeProvider.generating &&
                                              generativeProvider.promptResponses
                                                  .containsKey('ask') &&
                                              generativeProvider
                                                      .promptResponses['ask'] ==
                                                  null
                                          ? const CircularProgressIndicator()
                                          : const Icon(Icons.question_answer),
                                      label: const Text('Ask a question'),
                                      onPressed: () async {
                                        await generateContent(
                                            generativeProvider,
                                            widget.generativeService.prompts
                                                .firstWhere(
                                                    (p) => p.key == 'ask'),
                                            stockPositionStore,
                                            optionPositionStore,
                                            forexHoldingStore,
                                            context);
                                      },
                                    ),
                                  ),
                                ]),
                          ],
                        )),

                    // ListTile(
                    //   title: const Text(
                    //       'Filename'),
                    //   subtitle: SelectableText(
                    //     videoRef.name,
                    //     maxLines: 2,
                    //     // style: const TextStyle(
                    //     //   overflow:
                    //     //       TextOverflow.ellipsis,
                    //     // )
                    //   ),
                    // ),
                  ],
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

            Consumer4<PortfolioStore, InstrumentPositionStore,
                    OptionPositionStore, ForexHoldingStore>(
                builder: (context, portfolioStore, stockPositionStore,
                    optionPositionStore, forexHoldingStore, child) {
              double close = 0;
              DateTime? updatedAt;
              if (portfolioStore.items.isNotEmpty && account != null) {
                // close = (portfolioStore.items[0].equity ?? 0) +
                //     forexHoldingStore.equity;
                close = account.portfolioCash! +
                    // (account.unsettledDebit ?? 0) +
                    // (account.settledAmountBorrowed ?? 0) +
                    stockPositionStore.equity +
                    optionPositionStore.equity +
                    forexHoldingStore.equity;
                updatedAt = portfolioStore.items[0].updatedAt!;
              }

              return SliverToBoxAdapter(
                  child: ListTile(
                // leading: Icon(Icons.account_balance),
                title: const Text(
                  "Portfolio",
                  style: TextStyle(fontSize: 19.0),
                ),
                subtitle: Text(
                  // '${formatMediumDate.format(firstHistorical!.beginsAt!.toLocal())} -
                  updatedAt != null
                      ? formatLongDateTime.format(updatedAt.toLocal())
                      : '',
                  // selection != null
                  // ? selection!.beginsAt!.toLocal()
                  // : lastHistorical!.beginsAt!.toLocal()),
                  style: const TextStyle(fontSize: 10.0),
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Wrap(spacing: 8, children: [
                  AnimatedSwitcher(
                    duration: Duration(milliseconds: 200),
                    // transitionBuilder:
                    //     (Widget child, Animation<double> animation) {
                    //   return SlideTransition(
                    //       position: (Tween<Offset>(
                    //               begin: Offset(0, -0.25), end: Offset.zero))
                    //           .animate(animation),
                    //       child: child);
                    // },
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                      return ScaleTransition(scale: animation, child: child);
                    },
                    child: Text(
                      key: ValueKey<String>(close.toString()),
                      formatCurrency.format(close),
                      // selection != null
                      //  ? selection!.adjustedCloseEquity
                      //  : close),
                      style: const TextStyle(
                          fontSize: totalValueFontSize), //  21.0
                      textAlign: TextAlign.right,
                    ),
                  )
                ]),
              ));
            }),
            if (widget.brokerageUser.source == BrokerageSource.robinhood ||
                widget.brokerageUser.source == BrokerageSource.demo) ...[
              Consumer<
                  PortfolioHistoricalsStore
                  // PortfolioStore,
                  // InstrumentPositionStore,
                  // OptionPositionStore,
                  // ForexHoldingStore
                  >(builder: (context,
                  portfolioHistoricalsStore,
                  // portfolioStore,
                  // instrumentPositionStore,
                  // optionPositionStore,
                  // forexHoldingStore,
                  child) {
                // Consumer3<PortfolioHistoricalsStore, PortfolioStore, ForexHoldingStore>(builder: (context, portfolioHistoricalsStore, portfolioStore, forexHoldingStore, child) {
                /*
                if (portfolioHistoricals != null) {
                  debugPrint(
                      'data: ${portfolioHistoricals!.bounds} ${portfolioHistoricals!.span} chip: ${chartBoundsFilter.toString()} ${chartDateSpanFilter.toString()}');
                }
                */
                portfolioHistoricals = portfolioHistoricalsStore.items
                    .firstWhereOrNull((element) =>
                            element.span ==
                                convertChartSpanFilter(chartDateSpanFilter) &&
                            element.bounds ==
                                convertChartBoundsFilter(chartBoundsFilter)
                        //&& element.interval == element.interval
                        );
                if (portfolioHistoricals == null) {
                  portfolioHistoricals = portfolioHistoricalsStore.items
                      .firstWhereOrNull((element) =>
                              element.span ==
                                  convertChartSpanFilter(
                                      prevChartDateSpanFilter) &&
                              element.bounds ==
                                  convertChartBoundsFilter(
                                      prevChartBoundsFilter)
                          //&& element.interval == element.interval
                          );

                  if (portfolioHistoricals == null) {
                    return SliverToBoxAdapter(child: Container());
                  }
                }

                /* Removed because it was causing PortfolioHistoricalStore to updateListeners when the next http request was no different.  
                if (portfolioHistoricals!.span == "day") {
                  final DateTime now = DateTime.now();
                  final DateTime today = DateTime(now.year, now.month, now.day);

                  portfolioHistoricals!.equityHistoricals =
                      portfolioHistoricals!.equityHistoricals
                          .where((element) =>
                              element.beginsAt!.compareTo(today) >= 0)
                          .toList();
                }
                */

                EquityHistorical? firstHistorical;
                EquityHistorical? lastHistorical;
                double open = 0;
                double close = 0;
                double changeInPeriod = 0;
                double changePercentInPeriod = 0;

                firstHistorical = portfolioHistoricals!.equityHistoricals.first;
                lastHistorical = portfolioHistoricals!.equityHistoricals.last;

                // Update last historical from day span to deal with the issue that
                // lastHistorical return different values at different increment spans.
                var hourHistoricals = portfolioHistoricalsStore.items
                    .singleWhereOrNull((e) => e.span == 'hour');
                var dayHistoricals = portfolioHistoricalsStore.items
                    .singleWhereOrNull((e) => e.span == 'day');
                final DateTime now = DateTime.now();
                final DateTime today = DateTime(now.year, now.month, now.day);
                final maxDate = portfolioHistoricals!.equityHistoricals
                    .map((e) => e.beginsAt!)
                    .reduce((a, b) => a.isAfter(b) ? a : b);
                var allHistoricals = (portfolioHistoricals!.span == "day"
                        // || portfolioHistoricals!.span == "hour"
                        ? portfolioHistoricals!.equityHistoricals
                            .where((element) =>
                                element.beginsAt!.compareTo(today) >= 0)
                            .toList()
                        : portfolioHistoricals!.equityHistoricals) +
                    (hourHistoricals != null
                        ? hourHistoricals.equityHistoricals
                            .where((element) =>
                                element.beginsAt!.compareTo(today) >= 0 &&
                                element.beginsAt!.compareTo(maxDate) >= 0)
                            .toList()
                        : [dayHistoricals!.equityHistoricals.last]);
                if (allHistoricals.isNotEmpty) {
                  firstHistorical = allHistoricals.first;
                  lastHistorical = allHistoricals.last;
                }

                open = firstHistorical
                    .adjustedOpenEquity!; // .adjustedOpenEquity!; // portfolioHistoricals!.adjustedPreviousCloseEquity ??
                // Issue with using lastHistorical is that different increments return different values.
                close = lastHistorical.adjustedCloseEquity!;

                // close = (portfolioStore.items[0].equity ?? 0) + forexHoldingStore.equity;
                // if (account != null) {
                //   close = account.portfolioCash! +
                //       instrumentPositionStore.equity +
                //       optionPositionStore.equity +
                //       forexHoldingStore.equity;
                //   // updatedAt = portfolioStore.items[0].updatedAt!;
                // }

                changeInPeriod = close - open;
                changePercentInPeriod = (close / open) - 1;
                // Wrong change percent calculation.
                // changePercentInPeriod = changeInPeriod / close;

                // Since the chart is not candlesticks, each point is the opening value of the time span,
                // so add a final point at an extra increment of time span to account for the closing value.
                Duration intervalDuration = Duration.zero;
                switch (portfolioHistoricals!.interval) {
                  case 'month':
                    intervalDuration = Duration(days: 30);
                    break;
                  case 'week':
                    intervalDuration = Duration(days: 7);
                    break;
                  case 'day':
                    intervalDuration = Duration(days: 1);
                    break;
                  case 'hour':
                    intervalDuration = Duration(hours: 1);
                    break;
                  case '10minute':
                    intervalDuration = Duration(minutes: 10);
                    break;
                  case '5minute':
                    intervalDuration = Duration(minutes: 5);
                    break;
                  case '15second':
                    intervalDuration = Duration(seconds: 15);
                    break;
                }
                var adjDate =
                    allHistoricals.last.beginsAt!.add(intervalDuration);
                if (adjDate.compareTo(now) >= 0) {
                  adjDate = now;
                }
                allHistoricals.add(EquityHistorical(
                    allHistoricals.last.adjustedCloseEquity,
                    allHistoricals.last.adjustedCloseEquity,
                    allHistoricals.last.closeEquity,
                    allHistoricals.last.closeEquity,
                    allHistoricals.last.closeMarketValue,
                    allHistoricals.last.closeMarketValue,
                    adjDate,
                    allHistoricals.last.netReturn,
                    allHistoricals.last.session));

                /*
              var brightness = MediaQuery.of(context).platformBrightness;
              var textColor = Theme.of(context).colorScheme.background;
              if (brightness == Brightness.dark) {
                textColor = Colors.grey.shade200;
              } else {
                textColor = Colors.grey.shade800;
              }
              */
                var provider = Provider.of<PortfolioHistoricalsSelectionStore>(
                    context,
                    listen: false);
                TimeSeriesChart historicalChart = TimeSeriesChart(
                  [
                    charts.Series<EquityHistorical, DateTime>(
                      id: 'Adjusted Equity',
                      colorFn: (_, __) => charts.ColorUtil.fromDartColor(
                          Theme.of(context).colorScheme.primary),
                      // strokeWidthPxFn: (EquityHistorical history, index) => 1,
                      //charts.MaterialPalette.blue.shadeDefault,
                      domainFn: (EquityHistorical history, _) =>
                          history.beginsAt!,
                      //filteredEquityHistoricals.indexOf(history),
                      measureFn: (EquityHistorical history, index) =>
                          history.adjustedOpenEquity,
                      labelAccessorFn: (EquityHistorical history, index) =>
                          formatCompactNumber
                              .format((history.adjustedOpenEquity)),
                      data:
                          allHistoricals, // portfolioHistoricals!.equityHistoricals,
                    ),
                    charts.Series<EquityHistorical, DateTime>(
                        id: 'Equity',
                        colorFn: (_, __) =>
                            charts.MaterialPalette.green.shadeDefault,
                        // strokeWidthPxFn: (EquityHistorical history, index) => 1,
                        domainFn: (EquityHistorical history, _) =>
                            history.beginsAt!,
                        //filteredEquityHistoricals.indexOf(history),
                        measureFn: (EquityHistorical history, index) =>
                            history.openEquity,
                        data:
                            allHistoricals // portfolioHistoricals!.equityHistoricals
                        ),
                    charts.Series<EquityHistorical, DateTime>(
                        id: 'Market Value',
                        colorFn: (_, __) =>
                            charts.MaterialPalette.red.shadeDefault,
                        // strokeWidthPxFn: (EquityHistorical history, index) => 1,
                        domainFn: (EquityHistorical history, _) =>
                            history.beginsAt!,
                        //filteredEquityHistoricals.indexOf(history),
                        measureFn: (EquityHistorical history, index) =>
                            history.openMarketValue,
                        data:
                            allHistoricals // portfolioHistoricals!.equityHistoricals
                        ),
                  ],
                  animate: animateChart,
                  zeroBound: false,
                  open: open,
                  close: close,
                  seriesLegend: charts.SeriesLegend(
                    horizontalFirst: true,
                    position: charts.BehaviorPosition.top,
                    defaultHiddenSeries: const ['Equity', 'Market Value'],
                    // To show value on legend upon selection
                    // showMeasures: true,
                    measureFormatter: (measure) =>
                        measure != null ? formatPercentage.format(measure) : '',
                    // legendDefaultMeasure: charts.LegendDefaultMeasure.lastValue
                  ),
                  onSelected: (charts.SelectionModel<dynamic>? model) {
                    provider.selectionChanged(
                        model?.selectedDatum.first.datum); //?.first
                  },
                  symbolRenderer: TextSymbolRenderer(() {
                    firstHistorical =
                        portfolioHistoricals!.equityHistoricals[0];
                    open = firstHistorical!.adjustedOpenEquity!;
                    if (provider.selection != null) {
                      changeInPeriod =
                          provider.selection!.adjustedCloseEquity! -
                              open; // portfolios![0].equityPreviousClose!;
                      changePercentInPeriod = provider
                                  .selection!.adjustedCloseEquity! /
                              open -
                          1; // changeInPeriod / provider.selection!.adjustedCloseEquity!;
                    } else {
                      changeInPeriod = close - open;
                      changePercentInPeriod =
                          (close / open) - 1; // changeInPeriod / close;
                    }
                    // String? returnText = widget.user.getDisplayText(changeInPeriod,
                    //     displayValue: DisplayValue.totalReturn);
                    // String? returnPercentText = widget.user.getDisplayText(
                    //     changePercentInPeriod,
                    //     displayValue: DisplayValue.totalReturnPercent);
                    return "${formatCurrency.format(provider.selection != null ? provider.selection!.adjustedCloseEquity : close)}\n${formatCompactDateTimeWithHour.format(provider.selection != null ? provider.selection!.beginsAt!.toLocal() : lastHistorical!.beginsAt!.toLocal())}";
                    // \n$returnText $returnPercentText
                  }, marginBottom: 16),
                );

                return SliverToBoxAdapter(
                    child: Stack(
                  children: [
                    if (done == false) ...[
                      const SizedBox(
                        height: 3, //150.0,
                        child: Align(
                            alignment: Alignment.center,
                            child: Center(
                                child: LinearProgressIndicator(
                                    //value: controller.value,
                                    //semanticsLabel: 'Linear progress indicator',
                                    ) //CircularProgressIndicator(),
                                )),
                      )
                    ],
                    Column(children: [
                      SizedBox(
                          height: 460, // 240,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                                10.0, 10.0, 10.0, 10.0),
                            //padding: EdgeInsets.symmetric(horizontal: 10.0),
                            //padding: const EdgeInsets.all(10.0),
                            child: historicalChart,
                          )),
                      Consumer<PortfolioHistoricalsSelectionStore>(
                          builder: (context, value, child) {
                        var selection = value.selection;
                        if (selection != null) {
                          changeInPeriod = selection.adjustedCloseEquity! -
                              open; // portfolios![0].equityPreviousClose!;
                          changePercentInPeriod = selection
                                      .adjustedCloseEquity! /
                                  open -
                              1; // changeInPeriod / selection.adjustedCloseEquity!;
                        } else {
                          changeInPeriod = close - open;
                          changePercentInPeriod =
                              close / open - 1; // changeInPeriod / close;
                        }
                        String? returnText = widget.brokerageUser
                            .getDisplayText(changeInPeriod,
                                displayValue: DisplayValue.totalReturn);
                        String? returnPercentText = widget.brokerageUser
                            .getDisplayText(changePercentInPeriod,
                                displayValue: DisplayValue.totalReturnPercent);
                        Icon todayIcon = widget.brokerageUser
                            .getDisplayIcon(changeInPeriod, size: 26.0);

                        //return Text(value.selection!.beginsAt.toString());
                        return SizedBox(
                            //height: 72,
                            child: Column(
                          children: [
                            SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5),
                                    child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.all(
                                                summaryEgdeInset), //.symmetric(horizontal: 6),
                                            child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: <Widget>[
                                                  Text(
                                                      formatCurrency.format(
                                                          selection != null
                                                              ? selection
                                                                  .adjustedCloseEquity
                                                              : close),
                                                      textAlign:
                                                          TextAlign.right,
                                                      style: const TextStyle(
                                                          fontSize:
                                                              summaryValueFontSize)),
                                                  Text(
                                                      formatMediumDateTime
                                                          .format(selection !=
                                                                  null
                                                              ? selection
                                                                  .beginsAt!
                                                                  .toLocal()
                                                              : lastHistorical!
                                                                  .beginsAt!
                                                                  .toLocal()), // "Value",
                                                      style: const TextStyle(
                                                          fontSize:
                                                              summaryLabelFontSize)),
                                                ]),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(
                                                summaryEgdeInset), //.symmetric(horizontal: 6),
                                            child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: <Widget>[
                                                  Wrap(spacing: 8, children: [
                                                    todayIcon,
                                                    Text(returnText,
                                                        style: const TextStyle(
                                                            fontSize:
                                                                summaryValueFontSize))
                                                  ]),
                                                  const Text("Change",
                                                      style: TextStyle(
                                                          fontSize:
                                                              summaryLabelFontSize)),
                                                ]),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(
                                                summaryEgdeInset), //.symmetric(horizontal: 6),
                                            child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: <Widget>[
                                                  Text(returnPercentText,
                                                      style: const TextStyle(
                                                          fontSize:
                                                              summaryValueFontSize)),
                                                  const Text("Change %",
                                                      style: TextStyle(
                                                          fontSize:
                                                              summaryLabelFontSize)),
                                                ]),
                                          ),
                                          // Padding(
                                          //   padding: const EdgeInsets.all(
                                          //       summaryEgdeInset), //.symmetric(horizontal: 6),
                                          //   child: Column(
                                          //       mainAxisSize: MainAxisSize.min,
                                          //       children: <Widget>[
                                          //         const Text(
                                          //           "",
                                          //           // formatLongDate.format(selection != null
                                          //           // ? selection!.beginsAt!.toLocal()
                                          //           //: lastHistorical!.beginsAt!.toLocal()),
                                          //         textAlign: TextAlign.right,
                                          //             style: TextStyle(
                                          //                 fontSize:
                                          //                     summaryValueFontSize)),
                                          //         Text(formatLongDate.format(selection != null
                                          //           ? selection!.beginsAt!.toLocal()
                                          //           : lastHistorical!.beginsAt!.toLocal()),
                                          //           //"Date",
                                          //             style: TextStyle(
                                          //                 fontSize:
                                          //                     summaryLabelFontSize)),
                                          //       ]),
                                          // ),
                                        ])))

                            /*
                            ListTile(
                              title:
                                  Wrap(
                                children: [
                                  Text(
                                      formatCurrency.format(selection != null
                                          ? selection!.adjustedCloseEquity
                                          : close),
                                      style: TextStyle(
                                          fontSize: 19, color: textColor)),
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
                                          fontSize: 19.0, color: textColor)),
                                  Container(
                                    width: 10,
                                  ),
                                  Text(
                                      "${changeInPeriod > 0 ? "+" : changeInPeriod < 0 ? "-" : ""}${formatCurrency.format(changeInPeriod.abs())}",
                                      style: TextStyle(
                                          fontSize: 19.0, color: textColor)),
                                ],
                              ),
                              subtitle: Text(
                                  '${formatMediumDate.format(firstHistorical!.beginsAt!.toLocal())} - ${formatMediumDate.format(selection != null ? selection!.beginsAt!.toLocal() : lastHistorical!.beginsAt!.toLocal())}',
                                  style: const TextStyle(fontSize: 12.0)),
                            )
                            */
                            /*
                      trailing: Wrap(
                        children: [
                          Text(
                              formatCurrency.format(selection != null
                                  ? selection!.adjustedCloseEquity
                                  : close),
                              style: TextStyle(fontSize: 19, color: textColor)),
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
                              style: TextStyle(fontSize: 19.0, color: textColor)),
                          Container(
                            width: 10,
                          ),
                          Text(
                              "${changeInPeriod > 0 ? "+" : changeInPeriod < 0 ? "-" : ""}${formatCurrency.format(changeInPeriod.abs())}",
                              style: TextStyle(fontSize: 19.0, color: textColor)),
                        ],
                      ),
                      */
                            /*
                    Wrap(
                      children: [
                        Text(formatCurrency.format(close),
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
                          //size: 16.0
                        ),
                        Container(
                          width: 2,
                        ),
                        Text(
                            formatPercentage
                                //.format(selection!.netReturn!.abs()),
                                .format(changePercentInPeriod.abs()),
                            style: TextStyle(fontSize: 20.0, color: textColor)),
                        Container(
                          width: 10,
                        ),
                        Text(
                            "${changeInPeriod > 0 ? "+" : changeInPeriod < 0 ? "-" : ""}${formatCurrency.format(changeInPeriod.abs())}",
                            style: TextStyle(fontSize: 20.0, color: textColor)),
                      ],
                    ),
                    Text(
                        '${formatMediumDate.format(firstHistorical!.beginsAt!.toLocal())} - ${formatMediumDate.format(selection != null ? selection!.beginsAt!.toLocal() : lastHistorical!.beginsAt!.toLocal())}',
                        style: TextStyle(fontSize: 10, color: textColor)),
                        */
                          ],
                        ));
                      }),
                      SizedBox(
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
                                    label: const Text('Hour'),
                                    selected: chartDateSpanFilter ==
                                        ChartDateSpan.hour,
                                    onSelected: (bool value) {
                                      if (value) {
                                        resetChart(ChartDateSpan.hour,
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
                                    //selectedColor: Theme.of(context).colorScheme.primaryContainer,
                                    //labelStyle: TextStyle(color: Theme.of(context).colorScheme.background),
                                    label: const Text('Day'),
                                    selected: chartDateSpanFilter ==
                                        ChartDateSpan.day,
                                    onSelected: (bool value) {
                                      if (value) {
                                        resetChart(ChartDateSpan.day,
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
                                    label: const Text('Week'),
                                    selected: chartDateSpanFilter ==
                                        ChartDateSpan.week,
                                    onSelected: (bool value) {
                                      if (value) {
                                        resetChart(ChartDateSpan.week,
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
                                    label: const Text('Month'),
                                    selected: chartDateSpanFilter ==
                                        ChartDateSpan.month,
                                    onSelected: (bool value) {
                                      if (value) {
                                        resetChart(ChartDateSpan.month,
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
                                    label: const Text('YTD'),
                                    selected: chartDateSpanFilter ==
                                        ChartDateSpan.ytd,
                                    onSelected: (bool value) {
                                      if (value) {
                                        resetChart(ChartDateSpan.ytd,
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
                                    selected: chartDateSpanFilter ==
                                        ChartDateSpan.year,
                                    onSelected: (bool value) {
                                      if (value) {
                                        resetChart(ChartDateSpan.year,
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
                                    label: const Text('5 Years'),
                                    selected: chartDateSpanFilter ==
                                        ChartDateSpan.year_5,
                                    onSelected: (bool value) {
                                      if (value) {
                                        resetChart(ChartDateSpan.year_5,
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
                                    label: const Text('All'),
                                    selected: chartDateSpanFilter ==
                                        ChartDateSpan.all,
                                    onSelected: (bool value) {
                                      if (value) {
                                        resetChart(ChartDateSpan.all,
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
                                    selected:
                                        chartBoundsFilter == Bounds.regular,
                                    onSelected: (bool value) {
                                      if (value) {
                                        resetChart(chartDateSpanFilter,
                                            Bounds.regular);
                                      }
                                    },
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: ChoiceChip(
                                    //avatar: const Icon(Icons.history_outlined),
                                    //avatar: CircleAvatar(child: Text(optionCount.toString())),
                                    label: const Text('24/7 Hours'),
                                    selected: chartBoundsFilter == Bounds.t24_7,
                                    onSelected: (bool value) {
                                      if (value) {
                                        resetChart(
                                            chartDateSpanFilter, Bounds.t24_7);
                                      }
                                    },
                                  ),
                                ),
                              ]);
                            },
                            itemCount: 1,
                          )),
                    ])
                  ],
                ));
              }),
            ],
            Consumer4<PortfolioStore, InstrumentPositionStore,
                    OptionPositionStore, ForexHoldingStore>(
                builder: (context, portfolioStore, stockPositionStore,
                    optionPositionStore, forexHoldingStore, child) {
              final charts.ChartBehavior<String> legendBehavior =
                  charts.DatumLegend(
                // Positions for "start" and "end" will be left and right respectively
                // for widgets with a build context that has directionality ltr.
                // For rtl, "start" and "end" will be right and left respectively.
                // Since this example has directionality of ltr, the legend is
                // positioned on the right side of the chart.
                position: charts.BehaviorPosition.end,
                // By default, if the position of the chart is on the left or right of
                // the chart, [horizontalFirst] is set to false. This means that the
                // legend entries will grow as new rows first instead of a new column.
                horizontalFirst: false,
                // This defines the padding around each legend entry.
                cellPadding: EdgeInsets.only(right: 4.0, bottom: 4.0),
                // Set [showMeasures] to true to display measures in series legend.
                showMeasures: true,
                // Configure the measure value to be shown by default in the legend.
                legendDefaultMeasure: charts.LegendDefaultMeasure.firstValue,
                // Optionally provide a measure formatter to format the measure value.
                // If none is specified the value is formatted as a decimal.
                measureFormatter: (num? value) {
                  return value == null
                      ? '-'
                      : '\$${formatCompactNumber.format(value)}';
                },
                // entryTextStyle: charts.TextStyleSpec(fontSize: 12)
              );

              double portfolioValue = 0.0;
              // double stockAndOptionsEquityPercent = 0.0;
              double optionEquityPercent = 0.0;
              double positionEquityPercent = 0.0;
              double portfolioCash =
                  account != null ? account.portfolioCash! : 0;
              double cashPercent = 0.0;
              double cryptoPercent = 0.0;
              if (portfolioStore.items.isNotEmpty) {
                portfolioValue = (portfolioStore.items[0].equity ?? 0) +
                    forexHoldingStore.equity;
                // stockAndOptionsEquityPercent =
                //     portfolioStore.items[0].marketValue! / portfolioValue;
                optionEquityPercent =
                    optionPositionStore.equity / portfolioValue;
                positionEquityPercent =
                    stockPositionStore.equity / portfolioValue;
                cashPercent = portfolioCash / portfolioValue;
                cryptoPercent = forexHoldingStore.equity / portfolioValue;
              }

              List<PieChartData> data = [];
              //if (portfolioStore.items.isNotEmpty) {
              //var portfolioValue = (portfolioStore.items[0].equity ?? 0) + forexHoldingStore.equity;
              //var stockAndOptionsEquityPercent = portfolioStore.items[0].marketValue! / portfolioValue;
              data.add(PieChartData(
                  'Options ${formatPercentageInteger.format(optionEquityPercent)}',
                  optionPositionStore.equity));
              data.add(PieChartData(
                  'Stocks ${formatPercentageInteger.format(positionEquityPercent)}',
                  stockPositionStore.equity));
              data.add(PieChartData(
                  'Crypto ${formatPercentageInteger.format(cryptoPercent)}',
                  forexHoldingStore.equity));
              data.add(PieChartData(
                  'Cash ${formatPercentageInteger.format(cashPercent)}',
                  portfolioCash));
              //}
              data.sort((a, b) => b.value.compareTo(a.value));

              const maxLabelChars = 15;
              final maxSectors = 5;
              final maxIndustries = 5;

              List<PieChartData> diversificationSectorData = [];
              var groupedBySector = stockPositionStore.items.groupListsBy(
                  (item) => item.instrumentObj != null &&
                          item.instrumentObj!.fundamentalsObj != null
                      ? item.instrumentObj!.fundamentalsObj!.sector
                      : 'Unknown');
              final groupedSectors = groupedBySector
                  .map((k, v) {
                    return MapEntry(
                        k, v.map((m) => m.marketValue).reduce((a, b) => a + b));
                  })
                  .entries
                  .toList();
              groupedSectors.sort((a, b) => b.value.compareTo(a.value));
              for (var groupedSector in groupedSectors.take(maxSectors)) {
                diversificationSectorData
                    .add(PieChartData(groupedSector.key, groupedSector.value));
              }
              diversificationSectorData
                  .sort((a, b) => b.value.compareTo(a.value));
              if (groupedSectors.length > maxSectors) {
                diversificationSectorData.add(PieChartData(
                    'Others',
                    groupedSectors
                        .skip(maxSectors)
                        .map((e) => e.value)
                        .reduce((a, b) => a + b)));
              }

              List<PieChartData> diversificationIndustryData = [];
              var groupedByIndustry = stockPositionStore.items.groupListsBy(
                  (item) => item.instrumentObj != null &&
                          item.instrumentObj!.fundamentalsObj != null
                      ? item.instrumentObj!.fundamentalsObj!.industry
                      : 'Unknown');
              final groupedIndustry = groupedByIndustry
                  .map((k, v) {
                    return MapEntry(
                        k, v.map((m) => m.marketValue).reduce((a, b) => a + b));
                  })
                  .entries
                  .toList();
              groupedIndustry.sort((a, b) => b.value.compareTo(a.value));

              for (var groupedSector in groupedIndustry.take(maxIndustries)) {
                diversificationIndustryData
                    .add(PieChartData(groupedSector.key, groupedSector.value));
              }
              diversificationIndustryData
                  .sort((a, b) => b.value.compareTo(a.value));
              if (groupedIndustry.length > maxIndustries) {
                diversificationIndustryData.add(PieChartData(
                    'Others',
                    groupedIndustry
                        .skip(maxIndustries)
                        .map((e) => e.value)
                        .reduce((a, b) => a + b)));
              }
              // for (var stock in stockPositionStore.items) {
              //   // var stockPositionStore.items.reduce((a, b)=> a.marketValue + b.marketValue)
              //   diversificationData.add(PieChartData(
              //       stock.instrumentObj!.symbol,
              //       stock.marketValue)); // / portfolioValue
              // }

              var shades = PieChart.makeShades(
                  charts.ColorUtil.fromDartColor(Theme.of(context)
                      .colorScheme
                      .primary), // .withOpacity(0.75)
                  4);
              // var total = data.map((e) => e.value).reduce((a, b) => a + b);

              var brightness = MediaQuery.of(context).platformBrightness;
              var axisLabelColor = charts.MaterialPalette.gray.shade500;
              if (brightness == Brightness.light) {
                axisLabelColor = charts.MaterialPalette.gray.shade700;
              }
              // double portfolioValue = 0.0;
              // double optionEquityPercent = 0.0;
              // double positionEquityPercent = 0.0;
              // double cashPercent = 0.0;
              // double cryptoPercent = 0.0;
              // if (account != null) {
              //   portfolioCash = account.portfolioCash ?? 0;
              // }
              // if (portfolioStore.items.isNotEmpty) {
              //   portfolioValue = (portfolioStore.items[0].equity ?? 0) +
              //       forexHoldingStore.equity;
              //   optionEquityPercent =
              //       optionPositionStore.equity / portfolioValue;
              //   positionEquityPercent =
              //       stockPositionStore.equity / portfolioValue;
              //   cashPercent = portfolioCash / portfolioValue;
              //   cryptoPercent = forexHoldingStore.equity / portfolioValue;
              // }
              return SliverToBoxAdapter(
                  child: Column(
                children: [
                  ListTile(
                    title: const Text(
                      "Allocation",
                      style: TextStyle(fontSize: 19.0),
                    ),
                    // subtitle: Text("last 12 months"),
                    // trailing: Wrap(spacing: 8, children: [
                    //   Text(
                    //     "${(positionEquityPercent * 100).round()}:${(optionEquityPercent * 100).round()}:${(cryptoPercent * 100).round()}:${(cashPercent * 100).round()}%",
                    //     style: const TextStyle(fontSize: assetValueFontSize),
                    //     textAlign: TextAlign.right,
                    //   )
                    // ]),
                  ),
                  ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: 180), // 320
                      child:
                          // ListView(
                          //     padding: const EdgeInsets.all(5.0),
                          //     scrollDirection: Axis.horizontal,
                          //     children: [
                          CarouselView(
                              enableSplash: false,
                              // padding: const EdgeInsets.all(5.0),
                              scrollDirection: Axis.horizontal,
                              itemSnapping: true,
                              itemExtent: double.infinity, // 360, //
                              shrinkExtent: 245,
                              // controller: _carouselController,
                              onTap: (value) {},
                              children: [
                            //if (total > 0) ...[
                            PieChart(
                              [
                                charts.Series<PieChartData, String>(
                                  id: 'Portfolio Breakdown',
                                  colorFn: (_, index) => shades[index!],
                                  domainFn: (PieChartData val, index) =>
                                      val.label,
                                  measureFn: (PieChartData val, index) =>
                                      val.value,
                                  labelAccessorFn: (PieChartData val, _) =>
                                      '${val.label}\n${formatCompactNumber.format(val.value)}',
                                  data: data,
                                ),
                              ],
                              animate: false,
                              renderer: charts.ArcRendererConfig(),
                              // renderer: charts.ArcRendererConfig(
                              //     //arcWidth: 60,
                              //     arcRendererDecorators: [
                              //       charts.ArcLabelDecorator(
                              //           // insideLabelStyleSpec:
                              //           //     charts.TextStyleSpec(fontSize: 14),
                              //           // labelPadding: 0,
                              //           outsideLabelStyleSpec:
                              //               charts.TextStyleSpec(
                              //                   fontSize: 12,
                              //                   color: axisLabelColor))
                              //     ]),
                              behaviors: [
                                legendBehavior,
                                charts.ChartTitle('Asset',
                                    titleStyleSpec: charts.TextStyleSpec(
                                        color: axisLabelColor),
                                    behaviorPosition:
                                        charts.BehaviorPosition.end),
                                charts.SelectNearest(),
                                charts.DomainHighlighter(),
                                charts.LinePointHighlighter(
                                  symbolRenderer: TextSymbolRenderer(() =>
                                      // widget.chartSelectionStore.selection != null
                                      //     ? formatCurrency
                                      //         .format(widget.chartSelectionStore.selection!.value)
                                      //     :
                                      ''),
                                  // chartSelectionStore.selection
                                  //     ?.map((s) => s.value.round().toString())
                                  //     .join(' ') ??
                                  // ''),
                                  // seriesIds: [
                                  //   dividendItems.isNotEmpty ? 'Dividend' : 'Interest'
                                  // ], // , 'Interest'
                                  // drawFollowLinesAcrossChart: true,
                                  // formatCompactCurrency
                                  //     .format(chartSelection?.value)),
                                  showHorizontalFollowLine: charts
                                      .LinePointHighlighterFollowLineType
                                      .none, //.nearest,
                                  showVerticalFollowLine: charts
                                      .LinePointHighlighterFollowLineType
                                      .none, //.nearest,
                                )
                              ],
                              onSelected: (value) {
                                debugPrint(value.value.toString());
                              },
                            ),
                            PieChart(
                              [
                                charts.Series<PieChartData, String>(
                                  id: 'Diversification Sector',
                                  colorFn: (_, index) =>
                                      charts.ColorUtil.fromDartColor(
                                          Colors.accents[index! %
                                              Colors.accents
                                                  .length]), // shades[index!],
                                  /*
                                                        colorFn: (_, index) => charts.MaterialPalette.cyan
                                                            .makeShades(4)[index!],
                                                        colorFn: (_, __) => charts.ColorUtil.fromDartColor(
                                                            Theme.of(context).colorScheme.primary),
                                                        */
                                  domainFn: (PieChartData val, index) =>
                                      val.label.length > maxLabelChars
                                          ? val.label.replaceRange(
                                              maxLabelChars,
                                              val.label.length,
                                              '...')
                                          : val.label,
                                  measureFn: (PieChartData val, index) =>
                                      val.value,
                                  labelAccessorFn: (PieChartData val, _) =>
                                      '${val.label}\n${formatCompactNumber.format(val.value)}',
                                  data: diversificationSectorData,
                                ),
                              ],
                              animate: false,
                              renderer: charts.ArcRendererConfig(),
                              // renderer: charts.ArcRendererConfig(
                              //     arcWidth: 14,
                              //     arcRendererDecorators: [
                              //       charts.ArcLabelDecorator(
                              //           // insideLabelStyleSpec:
                              //           //     charts.TextStyleSpec(fontSize: 14),
                              //           // labelPadding: 0,
                              //           outsideLabelStyleSpec:
                              //               charts.TextStyleSpec(
                              //                   fontSize: 12,
                              //                   color: axisLabelColor))
                              //     ]),
                              onSelected: (_) {},
                              behaviors: [
                                legendBehavior,
                                charts.SelectNearest(),
                                charts.DomainHighlighter(),
                                charts.ChartTitle('Sector',
                                    titleStyleSpec: charts.TextStyleSpec(
                                        color: axisLabelColor),
                                    behaviorPosition:
                                        charts.BehaviorPosition.end)
                              ],
                            ),
                            PieChart(
                              [
                                charts.Series<PieChartData, String>(
                                  id: 'Diversification Industry',
                                  colorFn: (_, index) =>
                                      charts.ColorUtil.fromDartColor(
                                          Colors.accents[index! %
                                              Colors.accents
                                                  .length]), // shades[index!],
                                  domainFn: (PieChartData val, index) =>
                                      val.label.length > maxLabelChars
                                          ? val.label.replaceRange(
                                              maxLabelChars,
                                              val.label.length,
                                              '...')
                                          : val.label,
                                  measureFn: (PieChartData val, index) =>
                                      val.value,
                                  labelAccessorFn: (PieChartData val, _) =>
                                      '${val.label}\n${formatCompactNumber.format(val.value)}',
                                  data: diversificationIndustryData,
                                ),
                              ],
                              animate: false,
                              renderer: charts.ArcRendererConfig(),
                              // renderer: charts.ArcRendererConfig(
                              //     arcWidth: 14,
                              //     arcRendererDecorators: [
                              //       charts.ArcLabelDecorator(
                              //           // insideLabelStyleSpec:
                              //           //     charts.TextStyleSpec(fontSize: 14),
                              //           // labelPadding: 0,
                              //           outsideLabelStyleSpec:
                              //               charts.TextStyleSpec(
                              //                   fontSize: 12,
                              //                   color: axisLabelColor))
                              //     ]),
                              behaviors: [
                                legendBehavior,
                                charts.SelectNearest(),
                                charts.DomainHighlighter(),
                                charts.ChartTitle('Industry',
                                    titleStyleSpec: charts.TextStyleSpec(
                                        color: axisLabelColor),
                                    behaviorPosition:
                                        charts.BehaviorPosition.end)
                              ],
                              onSelected: (_) {},
                            )
                            //],
                          ])),
                ],
              ));
            }),
            if (widget.brokerageUser.source == BrokerageSource.robinhood ||
                widget.brokerageUser.source == BrokerageSource.demo) ...[
              Consumer2<DividendStore, InterestStore>(
                  //, ChartSelectionStore
                  builder: (context, dividendStore, interestStore, child) {
                //, chartSelectionStore
                // var dividendStore =
                //     Provider.of<DividendStore>(context, listen: false);
                // var interestStore =
                //     Provider.of<InterestStore>(context, listen: false);
                var instrumentPositionStore =
                    Provider.of<InstrumentPositionStore>(context,
                        listen: false);
                var chartSelectionStore =
                    Provider.of<ChartSelectionStore>(context, listen: false);
                return IncomeTransactionsWidget(
                    widget.brokerageUser,
                    widget.service,
                    dividendStore,
                    instrumentPositionStore,
                    chartSelectionStore,
                    interestStore: interestStore,
                    showChips: false,
                    showList: false,
                    showFooter: false,
                    analytics: widget.analytics,
                    observer: widget.observer);
              }),
            ],
            FutureBuilder(
              future: Future.wait([
                futureMarketIndexHistoricalsSp500 as Future,
                futureMarketIndexHistoricalsNasdaq as Future,
                futureMarketIndexHistoricalsDow as Future,
                futurePortfolioHistoricalsYear != null
                    ? futurePortfolioHistoricalsYear as Future
                    : Future.value(null)
              ]),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  var sp500 = snapshot.data![0];
                  var nasdaq = snapshot.data![1];
                  var dow = snapshot.data![2];
                  var portfolioHistoricals =
                      snapshot.data![3] as PortfolioHistoricals?;
                  if (portfolioHistoricals != null) {
                    final DateTime now = DateTime.now();
                    final DateTime newYearsDay = DateTime(now.year, 1, 1);
                    // var ytdportfolio = portfolioHistoricals.equityHistoricals
                    //     // .where((element) =>
                    //     //     element.beginsAt!.compareTo(newYearsDay) >= 0)
                    //     .toList();
                    // Update last historical from day span to deal with the issue that
                    // lastHistorical return different values at different increment spans.
                    var portfolioHistoricalsStore =
                        Provider.of<PortfolioHistoricalsStore>(context,
                            listen: true);
                    var dayHistoricals = portfolioHistoricalsStore.items
                        .singleWhereOrNull((e) => e.span == 'day');
                    if (dayHistoricals != null &&
                        !portfolioHistoricals.equityHistoricals.any((e) =>
                            e.beginsAt ==
                            dayHistoricals.equityHistoricals.last.beginsAt)) {
                      portfolioHistoricals.equityHistoricals
                          .add(dayHistoricals.equityHistoricals.last);
                    }

                    // var portfolioStore =
                    //     Provider.of<PortfolioStore>(context, listen: false);
                    // var forexHoldingStore =
                    //     Provider.of<ForexHoldingStore>(context, listen: false);
                    // var close = (portfolioStore.items[0].equity ?? 0) +
                    //     forexHoldingStore.equity;
                    // ytdportfolio.add(EquityHistorical(
                    //     close,
                    //     close,
                    //     close,
                    //     close,
                    //     close,
                    //     close,
                    //     portfolioStore.items.first.updatedAt,
                    //     0,
                    //     ''));
                    var regularsp500 = sp500['chart']['result'][0]['meta']
                        ['currentTradingPeriod']['regular'];
                    // var postsp500 = sp500['chart']['result'][0]['meta']
                    //     ['currentTradingPeriod']['post'];
                    var sp500PreviousClose = sp500['chart']['result'][0]['meta']
                        ['chartPreviousClose'];
                    var nasdaqPreviousClose = nasdaq['chart']['result'][0]
                        ['meta']['chartPreviousClose'];
                    var dowPreviousClose =
                        dow['chart']['result'][0]['meta']['chartPreviousClose'];
                    var enddiffsp500 =
                        regularsp500['end'] - regularsp500['start'];
                    // var enddiffsp500 = postsp500['end'] - regularsp500['start'];
                    // var quotesp500 =
                    //     sp500['chart']['result'][0]['indicators']['quote'][0];
                    // var quotenasdaq =
                    //     nasdaq['chart']['result'][0]['indicators']['quote'][0];
                    // var seriesOpensp500 = quotesp500['open'][0];
                    // var seriesOpennasdaq = quotenasdaq['open'][0];
                    var seriesDatasp500 =
                        (sp500['chart']['result'][0]['timestamp'] as List)
                            .mapIndexed((index, e) => {
                                  'date': DateTime.fromMillisecondsSinceEpoch(
                                      (e + enddiffsp500) * 1000),
                                  'value': (sp500['chart']['result'][0]
                                                  ['indicators']['adjclose'][0]
                                              ['adjclose'] as List)[index] /
                                          sp500PreviousClose -
                                      1
                                })
                            .toList();
                    seriesDatasp500
                        .insert(0, {'date': newYearsDay, 'value': 0.0});
                    var seriesDatanasdaq =
                        (nasdaq['chart']['result'][0]['timestamp'] as List)
                            .mapIndexed((index, e) => {
                                  'date': DateTime.fromMillisecondsSinceEpoch(
                                      (e + enddiffsp500) * 1000),
                                  'value': (nasdaq['chart']['result'][0]
                                                  ['indicators']['adjclose'][0]
                                              ['adjclose'] as List)[index] /
                                          nasdaqPreviousClose -
                                      1
                                })
                            .toList();
                    seriesDatanasdaq
                        .insert(0, {'date': newYearsDay, 'value': 0.0});
                    var seriesDatadow =
                        (dow['chart']['result'][0]['timestamp'] as List)
                            .mapIndexed((index, e) => {
                                  'date': DateTime.fromMillisecondsSinceEpoch(
                                      (e + enddiffsp500) * 1000),
                                  'value': (dow['chart']['result'][0]
                                                  ['indicators']['adjclose'][0]
                                              ['adjclose'] as List)[index] /
                                          dowPreviousClose -
                                      1
                                })
                            .toList();
                    seriesDatadow
                        .insert(0, {'date': newYearsDay, 'value': 0.0});
                    var seriesOpenportfolio = portfolioHistoricals
                        .equityHistoricals[0].adjustedOpenEquity;
                    var seriesDataportfolio =
                        portfolioHistoricals.equityHistoricals
                            .mapIndexed((index, e) => {
                                  'date': e.beginsAt,
                                  'value':
                                      // index == 0 ? 0.0 :
                                      e.adjustedCloseEquity! /
                                              seriesOpenportfolio! -
                                          1
                                })
                            .toList();
                    // seriesDataportfolio
                    //     .insert(0, {'date': newYearsDay, 'value': 0});
                    // var portfoliodiffsp500 =
                    //     (seriesDataportfolio.last['value'] as double) -
                    //         seriesDatasp500.last['value'];
                    // var portfoliodiffnasdaq =
                    //     (seriesDataportfolio.last['value'] as double) -
                    //         seriesDatanasdaq.last['value'];
                    var extents = charts.NumericExtents.fromValues(
                        (seriesDatasp500 +
                                seriesDatanasdaq +
                                seriesDatadow +
                                seriesDataportfolio)
                            .map((e) => e['value']));
                    extents = charts.NumericExtents(
                        extents.min - (extents.width * 0.1),
                        extents.max + (extents.width * 0.1));
                    var brightness = MediaQuery.of(context).platformBrightness;
                    var axisLabelColor = charts.MaterialPalette.gray.shade500;
                    if (brightness == Brightness.light) {
                      axisLabelColor = charts.MaterialPalette.gray.shade700;
                    }
                    var chartSelectionStore = Provider.of<ChartSelectionStore>(
                        context,
                        listen: false);
                    // provider.selectionChanged(MapEntry(
                    //     seriesDataportfolio.first['date'] as DateTime,
                    //     seriesDataportfolio.first['value'] as double));

                    // var seriesData = Map<DateTime, double>.fromIterables(
                    //     (snapshot.data['chart']['result'][0]['timestamp'] as List)
                    //         .map((e) => (e as Timestamp).toDate()),
                    //     snapshot.data['chart']['result'][0]['indicators']
                    //         ['adjClose'][0]['adjClose'] as List<double>);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      // chartSelectionStore.selection = MapEntry(
                      //     seriesDatasp500.last['date'] as DateTime,
                      //     seriesDatasp500.last['value'] as double);
                      // In order to highlight the last data point domain (date).
                      chartSelectionStore.selectionChanged(MapEntry(
                          seriesDataportfolio.last['date'] as DateTime,
                          seriesDataportfolio.last['value'] as double));
                    });
                    TimeSeriesChart marketIndicesChart = TimeSeriesChart(
                      [
                        charts.Series<dynamic, DateTime>(
                          id: 'Portfolio',
                          colorFn: (_, index) => charts.ColorUtil.fromDartColor(
                              Colors.accents[0 % Colors.accents.length]),
                          // strokeWidthPxFn: (dynamic data, index) => 1,
                          //charts.MaterialPalette.blue.shadeDefault,
                          domainFn: (dynamic data, _) => data['date'],
                          //filteredEquityHistoricals.indexOf(history),
                          measureFn: (dynamic data, index) => data['value'],
                          // labelAccessorFn: (dynamic data, index) =>
                          //     formatCompactNumber.format(data['value']),
                          data: seriesDataportfolio,
                        ),
                        charts.Series<dynamic, DateTime>(
                          id: 'S&P 500',
                          colorFn: (_, index) => charts.ColorUtil.fromDartColor(
                              Colors.accents[4 % Colors.accents.length]),
                          // strokeWidthPxFn: (dynamic data, index) => 1,
                          //charts.MaterialPalette.blue.shadeDefault,
                          domainFn: (dynamic data, _) => data['date'],
                          //filteredEquityHistoricals.indexOf(history),
                          measureFn: (dynamic data, index) => data['value'],
                          // labelAccessorFn: (dynamic data, index) =>
                          //     formatCompactNumber.format(data['value']),
                          data: seriesDatasp500,
                        ),
                        charts.Series<dynamic, DateTime>(
                          id: 'Nasdaq',
                          colorFn: (_, index) => charts.ColorUtil.fromDartColor(
                              Colors.accents[2 % Colors.accents.length]),
                          // strokeWidthPxFn: (dynamic data, index) => 1,
                          //charts.MaterialPalette.blue.shadeDefault,
                          domainFn: (dynamic data, _) => data['date'],
                          //filteredEquityHistoricals.indexOf(history),
                          measureFn: (dynamic data, index) => data['value'],
                          // labelAccessorFn: (dynamic data, index) =>
                          //     formatCompactNumber.format(data['value']),
                          data: seriesDatanasdaq,
                        ),
                        charts.Series<dynamic, DateTime>(
                          id: 'Dow 30',
                          colorFn: (_, index) => charts.ColorUtil.fromDartColor(
                              Colors.accents[6 % Colors.accents.length]),
                          // strokeWidthPxFn: (dynamic data, index) => 1,
                          //charts.MaterialPalette.blue.shadeDefault,
                          domainFn: (dynamic data, _) => data['date'],
                          //filteredEquityHistoricals.indexOf(history),
                          measureFn: (dynamic data, index) => data['value'],
                          // labelAccessorFn: (dynamic data, index) =>
                          //     formatCompactNumber.format(data['value']),
                          data: seriesDatadow,
                        ),
                      ],
                      animate: animateChart,
                      zeroBound: false,
                      primaryMeasureAxis: charts.PercentAxisSpec(
                          viewport: extents,
                          renderSpec: charts.GridlineRendererSpec(
                              labelStyle:
                                  charts.TextStyleSpec(color: axisLabelColor))),
                      seriesLegend: charts.SeriesLegend(
                        horizontalFirst: true,
                        desiredMaxColumns: 2,
                        cellPadding: EdgeInsets.fromLTRB(8, 4, 8, 4),
                        position: charts.BehaviorPosition.top,
                        defaultHiddenSeries: const [
                          // 'Dow 30',
                          // 'Nasdaq',
                          // 'S&P 500'
                        ],
                        // To show value on legend upon selection
                        showMeasures: true,
                        measureFormatter: (measure) => measure != null
                            ? formatPercentage.format(measure)
                            : '',
                        // Causes null exception when series are toggled from visible to hidden.
                        // legendDefaultMeasure:
                        //     charts.LegendDefaultMeasure.lastValue
                      ),
                      onSelected: (charts.SelectionModel? model) {
                        chartSelectionStore.selectionChanged(model != null
                            ? MapEntry(model.selectedDatum.first.datum['date'],
                                model.selectedDatum.first.datum['value'])
                            : null); //?.first
                      },
                      initialSelection:
                          charts.InitialSelection(selectedDataConfig: [
                        charts.SeriesDatumConfig<DateTime>('Portfolio',
                            seriesDataportfolio.last['date'] as DateTime),
                        charts.SeriesDatumConfig<DateTime>('S&P 500',
                            seriesDatasp500.last['date'] as DateTime),
                        charts.SeriesDatumConfig<DateTime>('Nasdaq',
                            seriesDatanasdaq.last['date'] as DateTime),
                        charts.SeriesDatumConfig<DateTime>(
                            'Dow 30', seriesDatadow.last['date'] as DateTime)
                      ], shouldPreserveSelectionOnDraw: true),
                      symbolRenderer: TextSymbolRenderer(() {
                        return chartSelectionStore.selection != null
                            // ${formatPercentage.format((provider.selection as MapEntry).value)}\n
                            ? formatCompactDateTimeWithHour.format(
                                (chartSelectionStore.selection as MapEntry)
                                    .key
                                    .toLocal())
                            : '';
                      }, marginBottom: 16),
                    );
                    return SliverToBoxAdapter(
                        child: ShrinkWrappingViewport(
                            offset: ViewportOffset.zero(),
                            slivers: [
                          SliverToBoxAdapter(
                            child: ListTile(
                              title: const Text(
                                "Performance",
                                style: TextStyle(fontSize: 19.0),
                              ),
                              subtitle: Text(
                                  "Compare market indices and benchmarks (YTD)"),
                              // trailing: Wrap(spacing: 8, children: [
                              //   Text(
                              //     '${portfoliodiffsp500 > 0 ? '+' : ''}${formatPercentage.format(portfoliodiffsp500)}  ${portfoliodiffnasdaq > 0 ? '+' : ''}${formatPercentage.format(portfoliodiffnasdaq)}', // seriesDataportfolio.last['value']
                              //     style: const TextStyle(fontSize: assetValueFontSize),
                              //     textAlign: TextAlign.right,
                              //   )
                              // ]),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: SizedBox(
                                height: 380, // 460, // 240,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      10.0, 10.0, 10.0, 10.0),
                                  //padding: EdgeInsets.symmetric(horizontal: 10.0),
                                  //padding: const EdgeInsets.all(10.0),
                                  child: marketIndicesChart,
                                )),
                          )
                        ]));
                  }
                }
                return SliverToBoxAdapter(
                  child: Container(),
                );
              },
            ),
            Consumer<InstrumentPositionStore>(
                builder: (context, stockPositionStore, child) {
              //if (positions != null) {
              var filteredPositions = stockPositionStore.items
                  .where((element) =>
                      ((hasQuantityFilters[0] && hasQuantityFilters[1]) ||
                          //(!hasQuantityFilters[0] && !hasQuantityFilters[1]) ||
                          (!hasQuantityFilters[0] || element.quantity! > 0) &&
                              (!hasQuantityFilters[1] ||
                                  element.quantity! <= 0)) &&
                      /*
                (days == 0 ||
                    element.createdAt!
                            .add(Duration(days: days))
                            .compareTo(DateTime.now()) >=
                        0) &&
                        */
                      (stockSymbolFilters.isEmpty ||
                          stockSymbolFilters
                              .contains(element.instrumentObj!.symbol)))
                  // widget.user.displayValue == DisplayValue.totalReturnPercent ? : i.marketValue
                  .toList();

              /*
              double? value = widget.user
                  .getPositionAggregateDisplayValue(filteredPositions);
              String? trailingText;
              Icon? icon;
              if (value != null) {
                trailingText = widget.user.getDisplayText(value);
                icon = widget.user.getDisplayIcon(value);
              }
              */
              return InstrumentPositionsWidget(
                widget.brokerageUser,
                widget.service,
                filteredPositions,
                showList: false,
                analytics: widget.analytics,
                observer: widget.observer,
              );
            }),
            Consumer<OptionPositionStore>(
                builder: (context, optionPositionStore, child) {
              //if (optionPositions != null) {
              var filteredOptionAggregatePositions = optionPositionStore.items
                  .where((element) =>
                      ((hasQuantityFilters[0] && hasQuantityFilters[1]) ||
                          (!hasQuantityFilters[0] || element.quantity! > 0) &&
                              (!hasQuantityFilters[1] ||
                                  element.quantity! <= 0)) &&
                      (positionFilters.isEmpty ||
                          positionFilters
                              .contains(element.legs.first.positionType)) &&
                      (optionFilters.isEmpty ||
                          optionFilters
                              .contains(element.legs.first.positionType)) &&
                      (optionSymbolFilters.isEmpty ||
                          optionSymbolFilters.contains(element.symbol)))
                  .toList();

              return OptionPositionsWidget(
                widget.brokerageUser,
                widget.service,
                filteredOptionAggregatePositions,
                showList: false,
                analytics: widget.analytics,
                observer: widget.observer,
              );
            }),
            Consumer<ForexHoldingStore>(
              builder: (context, forexHoldingStore, child) {
                var nummusHoldings = forexHoldingStore.items;
                cryptoSymbols =
                    nummusHoldings.map((e) => e.currencyCode).toSet().toList();
                cryptoSymbols.sort((a, b) => (a.compareTo(b)));
                var filteredHoldings = nummusHoldings
                    .where((element) =>
                        ((hasQuantityFilters[0] && hasQuantityFilters[1]) ||
                            (!hasQuantityFilters[0] || element.quantity! > 0) &&
                                (!hasQuantityFilters[1] ||
                                    element.quantity! <= 0)) &&
                        /*
                (days == 0 ||
                    element.createdAt!
                            .add(Duration(days: days))
                            .compareTo(DateTime.now()) >=
                        0) &&
                        */
                        (cryptoFilters.isEmpty ||
                            cryptoFilters.contains(element.currencyCode)))
                    // .sortedBy<num>((i) => widget.user.getCryptoDisplayValue(i))
                    // .reversed
                    .toList();

                return SliverToBoxAdapter(
                    child: ShrinkWrappingViewport(
                        offset: ViewportOffset.zero(),
                        slivers: [
                      //if (filteredOptionAggregatePositions.isNotEmpty) ...[
                      /*
                      const SliverToBoxAdapter(
                          child: SizedBox(
                        height: 25.0,
                      )),
                      */
                      ForexPositionsWidget(
                        widget.brokerageUser,
                        widget.service,
                        filteredHoldings,
                        showList: false,
                        analytics: widget.analytics,
                        observer: widget.observer,
                      ),
                      //],
                      // const SliverToBoxAdapter(
                      //     child: SizedBox(
                      //   height: 25.0,
                      // ))
                    ]));
              },
            ), // TODO: Introduce web banner
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
          ]), //controller: _controller,
    );
  }

  Future<void> generateContent(
      GenerativeProvider generativeProvider,
      Prompt prompt,
      InstrumentPositionStore stockPositionStore,
      OptionPositionStore optionPositionStore,
      ForexHoldingStore forexHoldingStore,
      BuildContext context) async {
    String? response;
    if (generativeProvider.promptResponses[prompt.key] != null) {
      response = generativeProvider.promptResponses[prompt.key];
    } else {
      generativeProvider.startGenerating(prompt.key);
      if (prompt.key == "market-summary" ||
          prompt.key == "market-predictions") {
        response = await widget.generativeService.generateContent(
            widget.generativeService.prompts
                .firstWhere((p) => p.key == prompt.key),
            stockPositionStore,
            optionPositionStore,
            forexHoldingStore);
        generativeProvider.setGenerativeResponse(prompt.key, response);
      } else if (prompt.prompt.isEmpty) {
        response = '';
        generativeProvider.generating = false;
      } else {
        var generateContentResponse = await widget.generativeService
            .generatePortfolioContent(
                widget.generativeService.prompts
                    .firstWhere((p) => p.key == prompt.key),
                stockPositionStore,
                optionPositionStore,
                forexHoldingStore,
                generativeProvider);
        response = generateContentResponse.text;
      }
    }
    if (context.mounted) {
      showAIResponse(response, prompt, context, generativeProvider,
          stockPositionStore, optionPositionStore, forexHoldingStore);
    }
  }

  void _startRefreshTimer() {
    // Start listening to clipboard
    refreshTriggerTime = Timer.periodic(
      const Duration(milliseconds: 15000),
      (timer) async {
        await _refresh();
      },
    );
  }

  void _stopRefreshTimer() {
    if (refreshTriggerTime != null) {
      refreshTriggerTime!.cancel();
    }
  }

  _refresh() async {
    var random = Random();
    final maxDelay = 15000;
    if (widget.brokerageUser.refreshEnabled &&
        (_notification == null || _notification == AppLifecycleState.resumed)) {
      if (widget.brokerageUser.source == BrokerageSource.robinhood) {
        if (account != null) {
          // // Added to attempt to fix a bug where cash balance does not refresh. TODO: Confirm
          // await service.getAccounts(
          //     widget.user,
          //     Provider.of<AccountStore>(context, listen: false),
          //     Provider.of<PortfolioStore>(context, listen: false),
          //     Provider.of<OptionPositionStore>(context, listen: false));
          var newRandom = (random.nextDouble() * maxDelay).toInt();
          debugPrint('getPortfolioHistoricals scheduled in $newRandom');
          Future.delayed(Duration(milliseconds: newRandom), () async {
            if (!mounted) return;
            await widget.service.getPortfolioHistoricals(
                widget.brokerageUser,
                Provider.of<PortfolioHistoricalsStore>(context, listen: false),
                account!.accountNumber,
                chartBoundsFilter,
                // Use the faster increment hour chart to append to the day chart.
                chartDateSpanFilter == ChartDateSpan.day
                    ? ChartDateSpan.hour
                    : chartDateSpanFilter);
          });
        }
        var newRandom = (random.nextDouble() * maxDelay).toInt();
        debugPrint('refreshOptionMarketData scheduled in $newRandom');
        Future.delayed(Duration(milliseconds: newRandom), () async {
          if (!mounted) return;
          await widget.service.refreshOptionMarketData(
              widget.brokerageUser,
              Provider.of<OptionPositionStore>(context, listen: false),
              Provider.of<OptionInstrumentStore>(context, listen: false));
        });

        newRandom = (random.nextDouble() * maxDelay).toInt();
        debugPrint('refreshPositionQuote scheduled in $newRandom');
        Future.delayed(Duration(milliseconds: newRandom), () async {
          if (!mounted) return;
          await widget.service.refreshPositionQuote(
              widget.brokerageUser,
              Provider.of<InstrumentPositionStore>(context, listen: false),
              Provider.of<QuoteStore>(context, listen: false));
        });

        newRandom = (random.nextDouble() * maxDelay).toInt();
        debugPrint('getPortfolios scheduled in $newRandom');
        Future.delayed(Duration(milliseconds: newRandom), () async {
          if (!mounted) return;
          await widget.service.getPortfolios(widget.brokerageUser,
              Provider.of<PortfolioStore>(context, listen: false));
        });

        newRandom = (random.nextDouble() * maxDelay).toInt();
        debugPrint('refreshNummusHoldings scheduled in $newRandom');
        Future.delayed(Duration(milliseconds: newRandom), () async {
          if (!mounted) return;
          await widget.service.refreshNummusHoldings(
            widget.brokerageUser,
            Provider.of<ForexHoldingStore>(context, listen: false),
          );
        });
      }
      if (widget.brokerageUser.source == BrokerageSource.schwab) {
        futureAccounts = widget.service.getAccounts(
            widget.brokerageUser,
            Provider.of<AccountStore>(context, listen: false),
            Provider.of<PortfolioStore>(context, listen: false),
            Provider.of<OptionPositionStore>(context, listen: false),
            instrumentPositionStore:
                Provider.of<InstrumentPositionStore>(context, listen: false),
            userDoc: widget.userDoc);
      }
    }
  }

  // void _animateToNextItem() {
  //   _carouselController.animateTo(
  //     _carouselController.offset + 320,
  //     duration: const Duration(milliseconds: 500),
  //     curve: Curves.linear,
  //   );
  // }

  void resetChart(ChartDateSpan span, Bounds bounds) async {
    // setState(() {
    prevChartDateSpanFilter = chartDateSpanFilter;
    chartDateSpanFilter = span;
    prevChartBoundsFilter = chartBoundsFilter;
    chartBoundsFilter = bounds;
    // futurePortfolioHistoricals = null;
    var portfolioHistoricalStore =
        Provider.of<PortfolioHistoricalsStore>(context, listen: false);
    // futurePortfolioHistoricals =
    await widget.service.getPortfolioHistoricals(
        widget.brokerageUser,
        portfolioHistoricalStore,
        account!.accountNumber,
        chartBoundsFilter,
        chartDateSpanFilter);
    portfolioHistoricalStore.notify();
  }

  Future<void> _pullRefresh() async {
    Provider.of<AccountStore>(context, listen: false).removeAll();
    Provider.of<PortfolioStore>(context, listen: false).removeAll();
    Provider.of<ForexHoldingStore>(context, listen: false).removeAll();
    Provider.of<OptionPositionStore>(context, listen: false).removeAll();
    Provider.of<InstrumentPositionStore>(context, listen: false).removeAll();
    setState(() {
      futureAccounts = null;
      futurePortfolios = null;
      futureNummusHoldings = null;
      futureOptionPositions = null;
      futureStockPositions = null;
    });
  }

  void showAIResponse(
      String? response,
      Prompt prompt,
      BuildContext context,
      GenerativeProvider generativeProvider,
      InstrumentPositionStore stockPositionStore,
      OptionPositionStore optionPositionStore,
      ForexHoldingStore forexHoldingStore) {
    final TextEditingController promptController = TextEditingController();

    // // score-swing uses a JSON response, so don't show the details of the document unless it's already cached.
    // double scoreFontSize = 28;
    // double scoreLabelFontSize = 12;
    // // int totalScore = 0;
    // int formScore = 0;
    // int clubSpeedScore = 0;
    // int powerScore = 0;
    // int controlScore = 0;
    // if (promptKey == 'score-swing') {
    //   try {
    //     var scores = jsonDecode(
    //         response!.replaceAll('```json\n', '').replaceAll('```', ''));
    //     formScore = scores["form"];
    //     clubSpeedScore = scores["club-speed"];
    //     powerScore = scores["power"];
    //     controlScore = scores["control"];
    //     // totalScore =
    //     //     ((formScore + clubSpeedScore + powerScore + controlScore) / 4)
    //     //         .round();
    //   } catch (e) {
    //     // on Exception
    //     debugPrint(e.toString());
    //   }
    //   // TODO: Add animation of score.
    // }
    showModalBottomSheet(
        context: context,
        enableDrag: true,
        // backgroundColor: Colors.grey.shade100,
        // shape: const BeveledRectangleBorder(),
        showDragHandle: true,
        isScrollControlled: true,
        useSafeArea: true,
        // constraints: BoxConstraints.loose(const Size.fromHeight(340)),
        builder: (BuildContext newContext) {
          return StatefulBuilder(builder: (BuildContext context, setState) {
            return DraggableScrollableSheet(
                expand: false,
                snap: true,
                minChildSize: 0.5,
                builder: (context1, controller) {
                  return SingleChildScrollView(
                    controller: controller,
                    child: Column(
                      children: [
                        // if (promptKey == 'score-swing') ...[
                        //   Padding(
                        //     padding: const EdgeInsets.symmetric(vertical: 16.0),
                        //     child: Card(
                        //       margin: const EdgeInsets.symmetric(horizontal: 10.0),
                        //       child: Padding(
                        //         padding: const EdgeInsets.all(16.0),
                        //         child: Column(
                        //           children: [
                        //             // const SizedBox(
                        //             //   height: 16,
                        //             // ),
                        //             const ListTile(
                        //               leading: Icon(Icons.sports_score),
                        //               title: Text(
                        //                 'Swing Score AI',
                        //                 style: TextStyle(fontSize: 20.0),
                        //               ),
                        //             ),
                        //             const SizedBox(
                        //               height: 16,
                        //             ),
                        //             Row(
                        //               mainAxisAlignment: MainAxisAlignment.spaceAround,
                        //               children: [
                        //                 Column(
                        //                   children: [
                        //                     CircleAvatar(
                        //                         radius: 30,
                        //                         child: Wrap(children: [
                        //                           // const Icon(Icons.sports_score),
                        //                           Text(
                        //                             formScore.toString(),
                        //                             style: TextStyle(
                        //                                 fontSize: scoreFontSize),
                        //                           )
                        //                         ])),
                        //                     Text(
                        //                       'form',
                        //                       style: TextStyle(
                        //                           fontSize: scoreLabelFontSize),
                        //                     ),
                        //                   ],
                        //                 ),
                        //                 Column(
                        //                   children: [
                        //                     CircleAvatar(
                        //                         radius: 30,
                        //                         child: Wrap(children: [
                        //                           // const Icon(Icons.sports_score),
                        //                           Text(
                        //                             clubSpeedScore.toString(),
                        //                             style: TextStyle(
                        //                                 fontSize: scoreFontSize),
                        //                           )
                        //                         ])),
                        //                     Text(
                        //                       'club speed',
                        //                       style: TextStyle(
                        //                           fontSize: scoreLabelFontSize),
                        //                     ),
                        //                   ],
                        //                 ),
                        //                 Column(
                        //                   children: [
                        //                     CircleAvatar(
                        //                         radius: 30,
                        //                         child: Wrap(children: [
                        //                           // const Icon(Icons.sports_score),
                        //                           Text(
                        //                             powerScore.toString(),
                        //                             style: TextStyle(
                        //                                 fontSize: scoreFontSize),
                        //                           )
                        //                         ])),
                        //                     Text(
                        //                       'power',
                        //                       style: TextStyle(
                        //                           fontSize: scoreLabelFontSize),
                        //                     ),
                        //                   ],
                        //                 ),
                        //                 Column(
                        //                   children: [
                        //                     CircleAvatar(
                        //                         radius: 30,
                        //                         child: Wrap(children: [
                        //                           // const Icon(Icons.sports_score),
                        //                           Text(
                        //                             controlScore.toString(),
                        //                             style: TextStyle(
                        //                                 fontSize: scoreFontSize),
                        //                           )
                        //                         ])),
                        //                     Text(
                        //                       'control',
                        //                       style: TextStyle(
                        //                           fontSize: scoreLabelFontSize),
                        //                     ),
                        //                   ],
                        //                 ),
                        //               ],
                        //             ),
                        //             const SizedBox(
                        //               height: 16,
                        //             ),
                        //           ],
                        //         ),
                        //       ),
                        //     ),
                        //   ),
                        // ] else ...[
                        if (prompt.key == 'ask') ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            // padding: const EdgeInsets.symmetric(vertical: 16.0),
                            // padding: const EdgeInsets.all(8.0),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: promptController,
                                      // maxLines: null,
                                      autofocus: true,
                                      decoration: InputDecoration(
                                        hintText: 'Ask a question.',
                                        // labelText: 'Text Message',
                                        // border: OutlineInputBorder(
                                        //     borderRadius: BorderRadius.circular(15)),
                                      ),
                                      // validator: (String? value) {
                                      //   if (value == null || value.isEmpty) {
                                      //     return 'Ask a question.';
                                      //   }
                                      //   return null;
                                      // },
                                    ),
                                  ),
                                  IconButton(
                                    icon: generativeProvider.generating
                                        ? const CircularProgressIndicator()
                                        : const Icon(Icons.send),
                                    onPressed: () async {
                                      if (promptController.text.isNotEmpty) {
                                        generativeProvider
                                            .startGenerating(prompt.key);
                                        generativeProvider
                                            .promptResponses[prompt.key] = null;
                                        prompt.prompt = promptController.text;
                                        setState(() {});

                                        response = await widget
                                            .generativeService
                                            .generateContent(
                                                prompt,
                                                stockPositionStore,
                                                optionPositionStore,
                                                forexHoldingStore);
                                        generativeProvider
                                            .setGenerativeResponse(
                                                prompt.key, response!);
                                        setState(() {});
                                      }
                                    },
                                  )
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (response!.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            // padding: const EdgeInsets.symmetric(vertical: 16.0),
                            // padding: const EdgeInsets.all(8.0),
                            child: Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 10.0),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: SelectionArea(
                                    // SelectionTransformer.separated allows for new lines to be copied and
                                    // pasted.
                                    child: MarkdownBody(
                                      // selectable: true,
                                      data: "# ${prompt.title}  \n$response",
                                      // styleSheet: MarkdownStyleSheet(
                                      //   h1Align: WrapAlignment.center,
                                      //   tableHeadAlign: TextAlign.left,
                                      //   textAlign: WrapAlignment.spaceEvenly,
                                      // ),
                                    ),
                                  ),
                                )),
                          ),
                        ],
                        // if (promptKey == 'summarize-video') ...[
                        //   TextButton.icon(
                        //     icon: const Icon(Icons.copy_all_outlined),
                        //     onPressed: () async {
                        //       if (widget.video != null) {
                        //         if (context.mounted) {
                        //           Navigator.pop(context);
                        //         }
                        //         state(() {
                        //           currentPrompt = promptKey;
                        //         });
                        //         widget.video!.note = response;
                        //         if (widget.onChange != null) {
                        //           widget.onChange!();
                        //         }
                        //         state(() {
                        //           currentPrompt = null;
                        //         });
                        //       }
                        //     },
                        //     label: const Text('Copy to Pro Notes'),
                        //   ),
                        // ],
                        if (prompt.key != 'ask') ...[
                          TextButton.icon(
                            icon: const Icon(Icons.refresh),
                            onPressed: () async {
                              // if (widget.video != null &&
                              //     widget.video!.responses != null) {
                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                              //   state(() {
                              //     currentPrompt = promptKey;
                              //   });
                              generativeProvider.promptResponses[prompt.key] =
                                  null;
                              // generativeProvider.promptResponses.removeWhere((key, value) => key == 'portfolio-summary');
                              await generateContent(
                                  generativeProvider,
                                  prompt,
                                  stockPositionStore,
                                  optionPositionStore,
                                  forexHoldingStore,
                                  context);

                              //   widget.video!.responses!.remove(promptKey);
                              //   await onAIChipPressed(promptKey!, context, state);
                              //   state(() {
                              //     currentPrompt = null;
                              //   });
                              // }
                            },
                            label: const Text('Generate new answer'),
                          ),
                        ],
                        SizedBox(
                          height: 25,
                        )
                      ],
                    ),
                  );
                });
          });
        });
    // ScaffoldMessenger.of(context)
    //     .showSnackBar(SnackBar(
    //   content:
    //       Text('$response'),
    //   duration:
    //       const Duration(days: 1),
    //   action:
    //       SnackBarAction(
    //     label: 'Ok',
    //     onPressed: () {},
    //   ),
    //   behavior:
    //       SnackBarBehavior.floating,
    // ));
  }

  showSettings() {
    showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        //isScrollControlled: true,
        //useRootNavigator: true,
        //constraints: const BoxConstraints(maxHeight: 200),
        builder: (_) => MoreMenuBottomSheet(widget.brokerageUser,
            analytics: widget.analytics,
            observer: widget.observer,
            chainSymbols: chainSymbols,
            positionSymbols: positionSymbols,
            cryptoSymbols: cryptoSymbols,
            optionSymbolFilters: optionSymbolFilters,
            stockSymbolFilters: stockSymbolFilters,
            cryptoFilters: cryptoFilters,
            onSettingsChanged: _onSettingsChanged));
  }

  void _onSettingsChanged(dynamic settings) {
    setState(() {
      hasQuantityFilters = settings['hasQuantityFilters'];

      stockSymbolFilters = settings['stockSymbolFilters'];
      optionSymbolFilters = settings['optionSymbolFilters'];
      cryptoFilters = settings['cryptoFilters'];

      optionFilters = settings['optionFilters'];
      positionFilters = settings['positionFilters'];
    });
  }

  /*
  void _generateCsvFile() async {
    File file = await OptionAggregatePosition.generateCsv(optionPositions);

    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text("Downloaded ${file.path.split('/').last}"),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Open',
            onPressed: () {
              OpenFile.open(file.path, type: 'text/csv');
            },
          )));
  }
  */
}
