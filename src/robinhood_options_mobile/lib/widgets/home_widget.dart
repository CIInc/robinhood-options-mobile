import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
//import 'package:charts_flutter/flutter.dart' as charts;
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/main.dart';
// import 'dart:math' as math;

import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/chart_selection_store.dart';
import 'package:robinhood_options_mobile/model/dividend_store.dart';
import 'package:robinhood_options_mobile/model/forex_holding.dart';
import 'package:robinhood_options_mobile/model/forex_holding_store.dart';
// import 'package:robinhood_options_mobile/model/generative_provider.dart';
import 'package:robinhood_options_mobile/model/instrument_order_store.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/interest_store.dart';
import 'package:robinhood_options_mobile/model/option_instrument_store.dart';
import 'package:robinhood_options_mobile/model/portfolio.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_store.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/futures_position_store.dart';
import 'package:robinhood_options_mobile/widgets/futures_positions_widget.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/model/user_info.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
import 'package:robinhood_options_mobile/services/yahoo_service.dart';
// import 'package:robinhood_options_mobile/utils/ai.dart';
import 'package:robinhood_options_mobile/widgets/ad_banner_widget.dart';
import 'package:robinhood_options_mobile/widgets/disclaimer_widget.dart';
import 'package:robinhood_options_mobile/widgets/forex_positions_widget.dart';
import 'package:robinhood_options_mobile/widgets/generative_actions_widget.dart';
import 'package:robinhood_options_mobile/widgets/income_transactions_widget.dart';
import 'package:robinhood_options_mobile/widgets/instrument_positions_widget.dart';
import 'package:robinhood_options_mobile/widgets/more_menu_widget.dart';
import 'package:robinhood_options_mobile/widgets/option_positions_widget.dart';
import 'package:robinhood_options_mobile/widgets/home/portfolio_chart_widget.dart';
import 'package:robinhood_options_mobile/widgets/home/allocation_widget.dart';
import 'package:robinhood_options_mobile/widgets/home/performance_chart_widget.dart';
import 'package:robinhood_options_mobile/widgets/welcome_widget.dart';
import 'package:robinhood_options_mobile/widgets/sliverappbar_widget.dart';
import 'package:robinhood_options_mobile/widgets/agentic_trading_settings_widget.dart';
import 'package:robinhood_options_mobile/widgets/backtesting_widget.dart';

/*
class DrawerItem {
  String title;
  IconData icon;
  DrawerItem(this.title, this.icon);
}
*/
class HomePage extends StatefulWidget {
  final BrokerageUser? brokerageUser;
  final UserInfo? userInfo;
  final IBrokerageService? service;
  final GenerativeService generativeService;

  final User? user;
  final DocumentReference<User>? userDoc;
  final VoidCallback? onLogin;
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
    required this.user,
    required this.userDoc,
    this.onLogin,
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
  ChartDateSpan benchmarkChartDateSpanFilter = ChartDateSpan.ytd;
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

  Future<List<dynamic>>? futureFuturesAccounts;
  Stream<List<dynamic>>? futuresStream;

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

  _HomePageState();

  void _loadData() {
    if (widget.brokerageUser == null || widget.service == null) return;

    futureAccounts = widget.service!.getAccounts(
        widget.brokerageUser!,
        Provider.of<AccountStore>(context, listen: false),
        Provider.of<PortfolioStore>(context, listen: false),
        Provider.of<OptionPositionStore>(context, listen: false),
        instrumentPositionStore:
            Provider.of<InstrumentPositionStore>(context, listen: false),
        userDoc: widget.userDoc);

    futureAccounts!.then((accounts) {
      if (mounted && accounts.isNotEmpty) {
        setState(() {
          account = accounts[0];
          _loadPortfolioHistoricals();
        });
      }
    });

    if (widget.brokerageUser!.source == BrokerageSource.robinhood ||
        widget.brokerageUser!.source == BrokerageSource.demo) {
      futurePortfolios = widget.service!.getPortfolios(widget.brokerageUser!,
          Provider.of<PortfolioStore>(context, listen: false));
      futureNummusHoldings = widget.service!.getNummusHoldings(
          widget.brokerageUser!,
          Provider.of<ForexHoldingStore>(context, listen: false),
          nonzero: !hasQuantityFilters[1],
          userDoc: widget.userDoc);

      futureOptionPositions = widget.service!.getOptionPositionStore(
          widget.brokerageUser!,
          Provider.of<OptionPositionStore>(context, listen: false),
          Provider.of<InstrumentStore>(context, listen: false),
          nonzero: !hasQuantityFilters[1],
          userDoc: widget.userDoc);

      futureStockPositions = widget.service!.getStockPositionStore(
          widget.brokerageUser!,
          Provider.of<InstrumentPositionStore>(context, listen: false),
          Provider.of<InstrumentStore>(context, listen: false),
          Provider.of<QuoteStore>(context, listen: false),
          nonzero: !hasQuantityFilters[1],
          userDoc: widget.userDoc);
    } else if (widget.brokerageUser!.source == BrokerageSource.schwab) {
      futureStockPositions = widget.service!.getStockPositionStore(
          widget.brokerageUser!,
          Provider.of<InstrumentPositionStore>(context, listen: false),
          Provider.of<InstrumentStore>(context, listen: false),
          Provider.of<QuoteStore>(context, listen: false),
          nonzero: !hasQuantityFilters[1],
          userDoc: widget.userDoc);
    }
  }

  void _loadPortfolioHistoricals() {
    if (account == null) return;
    if (widget.brokerageUser!.source == BrokerageSource.robinhood ||
        widget.brokerageUser!.source == BrokerageSource.demo) {
      futurePortfolioHistoricals = widget.service!.getPortfolioPerformance(
          widget.brokerageUser!,
          Provider.of<PortfolioHistoricalsStore>(context, listen: false),
          account!.accountNumber,
          chartBoundsFilter: chartBoundsFilter,
          chartDateSpanFilter: chartDateSpanFilter);

      futurePortfolioHistoricalsYear = widget.service!.getPortfolioPerformance(
          widget.brokerageUser!,
          Provider.of<PortfolioHistoricalsStore>(context, listen: false),
          account!.accountNumber,
          chartBoundsFilter: chartBoundsFilter,
          chartDateSpanFilter: benchmarkChartDateSpanFilter);

      futureDividends = widget.service!.getDividends(
        widget.brokerageUser!,
        Provider.of<DividendStore>(context, listen: false),
        Provider.of<InstrumentStore>(context, listen: false),
      );
      futureInterests = widget.service!.getInterests(
        widget.brokerageUser!,
        Provider.of<InterestStore>(context, listen: false),
      );

      if (widget.brokerageUser!.source == BrokerageSource.robinhood) {
        futureFuturesAccounts = (widget.service! as RobinhoodService)
            .getFuturesAccounts(widget.brokerageUser!, account!);
      }
    } else {
      futurePortfolioHistoricals = null;
      futurePortfolioHistoricalsYear = null;
      futureDividends = null;
      futureInterests = null;
    }
  }

  void _loadMarketIndices() {
    final yahooService = YahooService();
    String range = "ytd";
    switch (benchmarkChartDateSpanFilter) {
      case ChartDateSpan.year:
        range = "1y";
        break;
      case ChartDateSpan.year_2:
        range = "2y";
        break;
      case ChartDateSpan.year_3:
        range = "5y"; // Yahoo doesn't support 3y
        break;
      case ChartDateSpan.year_5:
        range = "5y";
        break;
      default:
        range = "ytd";
    }
    futureMarketIndexHistoricalsSp500 = yahooService.getMarketIndexHistoricals(
        symbol: '^GSPC', range: range); // ^IXIC
    futureMarketIndexHistoricalsNasdaq =
        yahooService.getMarketIndexHistoricals(symbol: '^IXIC', range: range);
    futureMarketIndexHistoricalsDow =
        yahooService.getMarketIndexHistoricals(symbol: '^DJI', range: range);
  }

  @override
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.brokerageUser != oldWidget.brokerageUser) {
      _loadData();
    }
  }

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

    _loadData();
    _loadMarketIndices();
    _startRefreshTimer();
    WidgetsBinding.instance.addObserver(this);

    widget.analytics.logScreenView(
      screenName: 'Home',
    );
  }

  @override
  void dispose() {
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
    if (widget.brokerageUser == null || widget.service == null) {
      return Scaffold(
          body: RefreshIndicator(
        onRefresh: () async {
          if (widget.onLogin != null) {
            widget.onLogin!();
          }
        },
        child: CustomScrollView(
          slivers: [
            ExpandedSliverAppBar(
              title: Text(widget.title ?? 'Home'),
              auth: auth,
              firestoreService: FirestoreService(),
              automaticallyImplyLeading: true,
              onChange: () {
                setState(() {});
              },
              analytics: widget.analytics,
              observer: widget.observer,
              user: widget.brokerageUser,
              firestoreUser: widget.user,
              userDocRef: widget.userDoc,
              service: widget.service,
            ),
            SliverFillRemaining(
              child: WelcomeWidget(
                onLogin: widget.onLogin,
              ),
            ),
          ],
        ),
      ));
    }
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

          // if (widget.brokerageUser!.source == BrokerageSource.robinhood) {
          //   futureFuturesAccounts = (widget.service! as RobinhoodService)
          //       .getFuturesAccounts(widget.brokerageUser!, account!);
          // }

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
              user: widget.brokerageUser!,
              firestoreUser: widget.user,
              userDocRef: widget.userDoc,
              service: widget.service!,
            ),

            if (welcomeWidget != null) ...[
              const SliverToBoxAdapter(
                  child: SizedBox(
                height: 16.0,
              )),
              SliverToBoxAdapter(
                  child: SizedBox(
                height: 150.0,
                child: Align(alignment: Alignment.center, child: welcomeWidget),
              ))
            ],
            SliverToBoxAdapter(
              child: GenerativeActionsWidget(
                generativeService: widget.generativeService,
                user: widget.user,
              ),
            ),

            if (widget.brokerageUser!.source == BrokerageSource.robinhood ||
                widget.brokerageUser!.source == BrokerageSource.demo) ...[
              SliverToBoxAdapter(
                child: PortfolioChartWidget(
                  brokerageUser: widget.brokerageUser!,
                  chartDateSpanFilter: chartDateSpanFilter,
                  chartBoundsFilter: chartBoundsFilter,
                  onFilterChanged: (span, bounds) {
                    resetChart(span, bounds);
                  },
                ),
              ),
            ],
            SliverToBoxAdapter(child: AllocationWidget(account: account)),
            SliverToBoxAdapter(
              child:
                  // Promote Automated Trading & Backtesting
                  Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Card(
                  elevation: 0,
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.auto_graph,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Automated Trading',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  Text(
                                    '& Backtesting',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Let the system trade for you or simulate strategies on historical data.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(Icons.settings, size: 18),
                                label: const Text('Configure'),
                                onPressed: (widget.user == null ||
                                        widget.userDoc == null)
                                    ? null
                                    : () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                AgenticTradingSettingsWidget(
                                              user: widget.user!,
                                              userDocRef: widget.userDoc!,
                                              service: widget.service!,
                                            ),
                                          ),
                                        );
                                      },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(Icons.history, size: 18),
                                label: const Text('Backtest'),
                                onPressed: (widget.user == null ||
                                        widget.userDoc == null)
                                    ? null
                                    : () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                BacktestingWidget(
                                              userDocRef: widget.userDoc,
                                            ),
                                          ),
                                        );
                                      },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (widget.brokerageUser!.source == BrokerageSource.robinhood ||
                widget.brokerageUser!.source == BrokerageSource.demo) ...[
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
                var instrumentOrderStore =
                    Provider.of<InstrumentOrderStore>(context, listen: false);
                var chartSelectionStore =
                    Provider.of<ChartSelectionStore>(context, listen: false);
                return IncomeTransactionsWidget(
                    widget.brokerageUser!,
                    widget.service!,
                    dividendStore,
                    instrumentPositionStore,
                    instrumentOrderStore,
                    chartSelectionStore,
                    interestStore: interestStore,
                    showChips: false,
                    showList: false,
                    showFooter: false,
                    analytics: widget.analytics,
                    observer: widget.observer);
              }),
            ],
            SliverToBoxAdapter(
              child: PerformanceChartWidget(
                futureMarketIndexHistoricalsSp500:
                    futureMarketIndexHistoricalsSp500,
                futureMarketIndexHistoricalsNasdaq:
                    futureMarketIndexHistoricalsNasdaq,
                futureMarketIndexHistoricalsDow:
                    futureMarketIndexHistoricalsDow,
                futurePortfolioHistoricalsYear: futurePortfolioHistoricalsYear,
                benchmarkChartDateSpanFilter: benchmarkChartDateSpanFilter,
                onFilterChanged: (span) {
                  setState(() {
                    benchmarkChartDateSpanFilter = span;
                  });
                },
              ),
            ),
            // FUTURES: If we have futures accounts, stream aggregated positions
            if (widget.brokerageUser!.source == BrokerageSource.robinhood) ...[
              FutureBuilder<List<dynamic>>(
                  future: futureFuturesAccounts,
                  builder: (context, snapshotAccounts) {
                    if (snapshotAccounts.hasData &&
                        snapshotAccounts.data != null) {
                      var accounts = snapshotAccounts.data!;
                      var futuresAccount = accounts.firstWhere(
                          (f) => f != null && f['accountType'] == 'FUTURES',
                          orElse: () => null);
                      if (futuresAccount != null) {
                        var accountId = futuresAccount['id'];
                        var stream = (widget.service! as RobinhoodService)
                            .streamFuturePositions(
                                widget.brokerageUser!, accountId);
                        return StreamBuilder<List<dynamic>>(
                            stream: stream,
                            builder: (context, futSnapshot) {
                              if (futSnapshot.hasData &&
                                  futSnapshot.data != null) {
                                var list = futSnapshot.data!;
                                // Build a store and provide it to descendants
                                var store = FuturesPositionStore();
                                store.addAll(list);
                                return ChangeNotifierProvider<
                                    FuturesPositionStore>.value(
                                  value: store,
                                  child: FuturesPositionsWidget(
                                    showList: false,
                                    onTapHeader: () {
                                      // navigate to a full futures page if desired
                                    },
                                  ),
                                );
                              } else if (futSnapshot.hasError) {
                                return SliverToBoxAdapter(
                                  child: Text('${futSnapshot.error}'),
                                );
                              } else {
                                return const SliverToBoxAdapter(
                                  child: Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(12.0),
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                );
                              }
                            });
                      }
                      return SliverToBoxAdapter();
                    } else {
                      return SliverToBoxAdapter();
                    }
                  }),
            ],
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
                widget.brokerageUser!,
                widget.service!,
                filteredOptionAggregatePositions,
                showList: false,
                analytics: widget.analytics,
                observer: widget.observer,
                generativeService: widget.generativeService,
                user: widget.user,
                userDocRef: widget.userDoc,
              );
            }),
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
                widget.brokerageUser!,
                widget.service!,
                filteredPositions,
                showList: false,
                analytics: widget.analytics,
                observer: widget.observer,
                generativeService: widget.generativeService,
                user: widget.user,
                userDocRef: widget.userDoc,
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
                        widget.brokerageUser!,
                        widget.service!,
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
                height: 16.0,
              )),
              SliverToBoxAdapter(
                  child: AdBannerWidget(
                size: AdSize.mediumRectangle,
                // searchBanner: true,
              )),
            ],
            const SliverToBoxAdapter(
                child: SizedBox(
              height: 16.0,
            )),
            const SliverToBoxAdapter(child: DisclaimerWidget()),
            const SliverToBoxAdapter(
                child: SizedBox(
              height: 16.0,
            )),
          ]), //controller: _controller,
    );
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

  Future<void> _refresh() async {
    var random = Random();
    final maxDelay = 15000;
    if (widget.brokerageUser != null &&
        widget.brokerageUser!.refreshEnabled &&
        (_notification == null || _notification == AppLifecycleState.resumed)) {
      if (widget.brokerageUser!.source == BrokerageSource.robinhood) {
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
            // Always fetch hour data for real-time updates
            await widget.service!.getPortfolioPerformance(
                widget.brokerageUser!,
                Provider.of<PortfolioHistoricalsStore>(context, listen: false),
                account!.accountNumber,
                chartBoundsFilter: chartBoundsFilter,
                chartDateSpanFilter: ChartDateSpan.hour);
            // await widget.service!.getPortfolioHistoricals(
            //     widget.brokerageUser!,
            //     Provider.of<PortfolioHistoricalsStore>(context, listen: false),
            //     account!.accountNumber,
            //     chartBoundsFilter,
            //     // Use the faster increment hour chart to append to the day chart.
            //     chartDateSpanFilter == ChartDateSpan.day
            //         ? ChartDateSpan.hour
            //         : chartDateSpanFilter);
          });
        }
        var newRandom = (random.nextDouble() * maxDelay).toInt();
        debugPrint('refreshOptionMarketData scheduled in $newRandom');
        Future.delayed(Duration(milliseconds: newRandom), () async {
          if (!mounted) return;
          await widget.service!.refreshOptionMarketData(
              widget.brokerageUser!,
              Provider.of<OptionPositionStore>(context, listen: false),
              Provider.of<OptionInstrumentStore>(context, listen: false));
        });

        newRandom = (random.nextDouble() * maxDelay).toInt();
        debugPrint('refreshPositionQuote scheduled in $newRandom');
        Future.delayed(Duration(milliseconds: newRandom), () async {
          if (!mounted) return;
          await widget.service!.refreshPositionQuote(
              widget.brokerageUser!,
              Provider.of<InstrumentPositionStore>(context, listen: false),
              Provider.of<QuoteStore>(context, listen: false));
        });

        newRandom = (random.nextDouble() * maxDelay).toInt();
        debugPrint('getPortfolios scheduled in $newRandom');
        Future.delayed(Duration(milliseconds: newRandom), () async {
          if (!mounted) return;
          await widget.service!.getPortfolios(widget.brokerageUser!,
              Provider.of<PortfolioStore>(context, listen: false));
        });

        newRandom = (random.nextDouble() * maxDelay).toInt();
        debugPrint('refreshNummusHoldings scheduled in $newRandom');
        Future.delayed(Duration(milliseconds: newRandom), () async {
          if (!mounted) return;
          await widget.service!.refreshNummusHoldings(
            widget.brokerageUser!,
            Provider.of<ForexHoldingStore>(context, listen: false),
          );
        });
      }
      if (widget.brokerageUser!.source == BrokerageSource.schwab) {
        futureAccounts = widget.service!.getAccounts(
            widget.brokerageUser!,
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
    if (widget.brokerageUser == null || widget.service == null) return;
    // setState(() {
    prevChartDateSpanFilter = chartDateSpanFilter;
    chartDateSpanFilter = span;
    prevChartBoundsFilter = chartBoundsFilter;
    chartBoundsFilter = bounds;
    // futurePortfolioHistoricals = null;
    var portfolioHistoricalStore =
        Provider.of<PortfolioHistoricalsStore>(context, listen: false);
    // futurePortfolioHistoricals =
    await widget.service!.getPortfolioPerformance(
        widget.brokerageUser!, portfolioHistoricalStore, account!.accountNumber,
        chartBoundsFilter: chartBoundsFilter,
        chartDateSpanFilter: chartDateSpanFilter);
    // await widget.service!.getPortfolioHistoricals(
    //     widget.brokerageUser!,
    //     portfolioHistoricalStore,
    //     account!.accountNumber,
    //     chartBoundsFilter,
    //     chartDateSpanFilter);
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

  void showSettings() {
    showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        //isScrollControlled: true,
        //useRootNavigator: true,
        //constraints: const BoxConstraints(maxHeight: 200),
        builder: (_) => MoreMenuBottomSheet(widget.brokerageUser!,
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
