import 'dart:async';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
//import 'package:charts_flutter/flutter.dart' as charts;
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/enums.dart';
// import 'dart:math' as math;

import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/chart_selection_store.dart';
import 'package:robinhood_options_mobile/model/dividend_store.dart';
import 'package:robinhood_options_mobile/model/equity_historical.dart';
import 'package:robinhood_options_mobile/model/forex_holding.dart';
import 'package:robinhood_options_mobile/model/forex_holding_store.dart';
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
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/ad_banner_widget.dart';
import 'package:robinhood_options_mobile/widgets/chart_pie_widget.dart';
import 'package:robinhood_options_mobile/widgets/chart_time_series_widget.dart';
import 'package:robinhood_options_mobile/widgets/disclaimer_widget.dart';
import 'package:robinhood_options_mobile/widgets/forex_positions_widget.dart';
import 'package:robinhood_options_mobile/widgets/income_transactions_widget.dart';
import 'package:robinhood_options_mobile/widgets/instrument_positions_widget.dart';
import 'package:robinhood_options_mobile/widgets/more_menu_widget.dart';
import 'package:robinhood_options_mobile/widgets/option_positions_widget.dart';

final formatDate = DateFormat("yMMMd");
final formatMediumDate = DateFormat("EEE MMM d, y hh:mm:ss a");
final formatLongDate = DateFormat("EEEE MMMM d, y hh:mm:ss a");
final formatCompactDate = DateFormat("MMM d yy");
final formatCompactDateTimeWithHour = DateFormat("MMM d h:mm a");
final formatCompactDateTimeWithMinute = DateFormat("MMM d yy hh:mm a");
final formatCurrency = NumberFormat.simpleCurrency();
final formatCompactCurrency = NumberFormat.compactCurrency();
final formatPercentage = NumberFormat.decimalPercentPattern(decimalDigits: 2);
final formatPercentageOneDigit =
    NumberFormat.decimalPercentPattern(decimalDigits: 1);
final formatPercentageInteger =
    NumberFormat.decimalPercentPattern(decimalDigits: 0);
final formatCompactNumber = NumberFormat.compact();

/*
class DrawerItem {
  String title;
  IconData icon;
  DrawerItem(this.title, this.icon);
}
*/
class HomePage extends StatefulWidget {
  final BrokerageUser user;
  final UserInfo userInfo;
  final IBrokerageService service;
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
    this.user,
    this.userInfo, // this.account,
    this.service, {
    super.key,
    required this.analytics,
    required this.observer,
    this.title,
    this.navigatorKey,
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
        widget.user,
        Provider.of<AccountStore>(context, listen: false),
        Provider.of<PortfolioStore>(context, listen: false),
        Provider.of<OptionPositionStore>(context, listen: false),
        instrumentPositionStore:
            Provider.of<InstrumentPositionStore>(context, listen: false));

    if (widget.user.source == Source.robinhood ||
        widget.user.source == Source.demo) {
      futurePortfolios = widget.service.getPortfolios(
          widget.user, Provider.of<PortfolioStore>(context, listen: false));
      futureNummusHoldings = widget.service.getNummusHoldings(
          widget.user, Provider.of<ForexHoldingStore>(context, listen: false),
          nonzero: !hasQuantityFilters[1]);

      futureOptionPositions = widget.service.getOptionPositionStore(
          widget.user,
          Provider.of<OptionPositionStore>(context, listen: false),
          Provider.of<InstrumentStore>(context, listen: false),
          nonzero: !hasQuantityFilters[1]);

      futureStockPositions = widget.service.getStockPositionStore(
          widget.user,
          Provider.of<InstrumentPositionStore>(context, listen: false),
          Provider.of<InstrumentStore>(context, listen: false),
          Provider.of<QuoteStore>(context, listen: false),
          nonzero: !hasQuantityFilters[1]);
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

          if (widget.user.source == Source.schwab) {
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
                widget.user,
                Provider.of<InstrumentPositionStore>(context, listen: false),
                Provider.of<InstrumentStore>(context, listen: false),
                Provider.of<QuoteStore>(context, listen: false),
                nonzero: !hasQuantityFilters[1]);
          }

          if (widget.user.source == Source.robinhood ||
              widget.user.source == Source.demo) {
            futurePortfolioHistoricals = widget.service.getPortfolioHistoricals(
                widget.user,
                Provider.of<PortfolioHistoricalsStore>(context, listen: false),
                account!.accountNumber,
                chartBoundsFilter,
                chartDateSpanFilter);

            // Future.delayed(Duration(seconds: 1), () {
            //   if (mounted) {
            futureDividends = widget.service.getDividends(
              widget.user,
              Provider.of<DividendStore>(context, listen: false),
              Provider.of<InstrumentStore>(context, listen: false),
            );
            //   }
            // });
            futureInterests = widget.service.getInterests(
              widget.user,
              Provider.of<InterestStore>(context, listen: false),
            );
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
    //debugPrint('_buildPage');
    return RefreshIndicator(
      onRefresh: _pullRefresh,
      child: CustomScrollView(
          // physics: ClampingScrollPhysics(),
          slivers: [
            Consumer4<PortfolioStore, InstrumentPositionStore,
                OptionPositionStore, ForexHoldingStore>(
              builder: (context, portfolioStore, stockPositionStore,
                  optionPositionStore, forexHoldingStore, child) {
                return buildSliverAppBar(
                    //portfolios,
                    widget.userInfo,
                    account,
                    portfolioStore,
                    stockPositionStore,
                    optionPositionStore,
                    forexHoldingStore);
                /*
                return SliverToBoxAdapter(
                    child: ShrinkWrappingViewport(
                        offset: ViewportOffset.zero(), slivers: []));
                        */
              },
            ),
            //userWidget(userInfo)
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
                    stockPositionStore.equity +
                    optionPositionStore.equity +
                    forexHoldingStore.equity;
                updatedAt = portfolioStore.items[0].updatedAt!;
              }

              return SliverToBoxAdapter(
                  child: ListTile(
                title: const Text(
                  "Portfolio",
                  style: TextStyle(fontSize: 19.0),
                ),
                subtitle: Text(
                  // '${formatMediumDate.format(firstHistorical!.beginsAt!.toLocal())} -
                  updatedAt != null
                      ? formatLongDate.format(updatedAt.toLocal())
                      : '',
                  // selection != null
                  // ? selection!.beginsAt!.toLocal()
                  // : lastHistorical!.beginsAt!.toLocal()),
                  style: const TextStyle(fontSize: 10.0),
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Wrap(spacing: 8, children: [
                  Text(
                    formatCurrency.format(close),
                    // selection != null
                    //  ? selection!.adjustedCloseEquity
                    //  : close),
                    style:
                        const TextStyle(fontSize: totalValueFontSize), //  21.0
                    textAlign: TextAlign.right,
                  ),
                ]),
                // shape: Border(),
                // children: [
                //   _buildExpandedSliverAppBarTitle(
                //       userInfo,
                //       portfolioStore.items,
                //       portfolioStore,
                //       optionPositionStore,
                //       stockPositionStore,
                //       forexHoldingStore)
                // ],
                /*
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
                              )*/
              ));
            }),
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
                                convertChartBoundsFilter(prevChartBoundsFilter)
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

              firstHistorical = portfolioHistoricals!.equityHistoricals[0];
              lastHistorical = portfolioHistoricals!.equityHistoricals[
                  portfolioHistoricals!.equityHistoricals.length - 1];
              open = firstHistorical
                  .adjustedCloseEquity!; // .adjustedOpenEquity!; // portfolioHistoricals!.adjustedPreviousCloseEquity ??

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

              // This solution uses the portfolioStore but causes flickers on each refresh as the value keeps changing.
              // if (portfolioStore.items.isNotEmpty) {// && forexHoldingStore.items.isNotEmpty
              //   close = (portfolioStore.items[0].equity ?? 0) + forexHoldingStore.equity;
              // }

              changeInPeriod = close - open;
              changePercentInPeriod = (close / open) - 1;
              // Wrong change percent calculation.
              // changePercentInPeriod = changeInPeriod / close;

              // Add latest portfolio value to historical to show current value on chart.
              // if (portfolioStore.items.isNotEmpty) {
              //   // debugPrint("equity ${portfolioStore.items[0].equity.toString()} forex ${forexHoldingStore.equity} close ${close.toString()}");
              //   portfolioHistoricals!.addOrUpdate(EquityHistorical(
              //       lastHistorical.adjustedCloseEquity,
              //       close,
              //       lastHistorical.closeEquity,
              //       close,
              //       lastHistorical.closeMarketValue,
              //       close,
              //       portfolioStore.items[0].updatedAt,
              //       lastHistorical.closeEquity! - close,
              //       '')); //  DateTime.now()
              //   lastHistorical = portfolioHistoricals!.equityHistoricals[
              //       portfolioHistoricals!.equityHistoricals.length - 1];
              //   close = lastHistorical.adjustedCloseEquity!;
              // }

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
                      strokeWidthPxFn: (EquityHistorical history, index) => 2,
                      //charts.MaterialPalette.blue.shadeDefault,
                      domainFn: (EquityHistorical history, _) =>
                          history.beginsAt!,
                      //filteredEquityHistoricals.indexOf(history),
                      measureFn: (EquityHistorical history, index) => index == 0
                          ? history.adjustedCloseEquity //adjustedOpenEquity
                          : history.adjustedCloseEquity,
                      labelAccessorFn: (EquityHistorical history, index) =>
                          formatCompactNumber.format((index == 0
                              ? history.adjustedCloseEquity //adjustedOpenEquity
                              : history.adjustedCloseEquity)),
                      data: portfolioHistoricals!.equityHistoricals,
                      /*
                          [
                            ...portfolioHistoricals!.equityHistoricals,
                            EquityHistorical(portfolioValue, portfolioValue, portfolioValue, portfolioValue, portfolioValue, portfolioValue, portfolioStore.items.first.updatedAt, 0, '')
                          ]
                          */
                    ),
                    charts.Series<EquityHistorical, DateTime>(
                        id: 'Equity',
                        colorFn: (_, __) =>
                            charts.MaterialPalette.green.shadeDefault,
                        strokeWidthPxFn: (EquityHistorical history, index) => 2,
                        domainFn: (EquityHistorical history, _) =>
                            history.beginsAt!,
                        //filteredEquityHistoricals.indexOf(history),
                        measureFn: (EquityHistorical history, index) =>
                            index == 0
                                ? history.openEquity
                                : history.closeEquity,
                        data: portfolioHistoricals!
                            .equityHistoricals //filteredEquityHistoricals,
                        ),
                    charts.Series<EquityHistorical, DateTime>(
                        id: 'Market Value',
                        colorFn: (_, __) =>
                            charts.MaterialPalette.red.shadeDefault,
                        strokeWidthPxFn: (EquityHistorical history, index) => 2,
                        domainFn: (EquityHistorical history, _) =>
                            history.beginsAt!,
                        //filteredEquityHistoricals.indexOf(history),
                        measureFn: (EquityHistorical history, index) =>
                            index == 0
                                ? history.openMarketValue
                                : history.closeMarketValue,
                        data: portfolioHistoricals!
                            .equityHistoricals //filteredEquityHistoricals,
                        ),
                  ],
                  animate: animateChart,
                  zeroBound: false,
                  open: open,
                  close: close,
                  hiddenSeries: const ['Equity', 'Market Value'],
                  onSelected: (dynamic historical) {
                provider.selectionChanged(historical); //?.first
              }, getTextForTextSymbolRenderer: () {
                firstHistorical = portfolioHistoricals!.equityHistoricals[0];
                open = firstHistorical!.adjustedOpenEquity!;
                if (provider.selection != null) {
                  changeInPeriod = provider.selection!.adjustedCloseEquity! -
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
              });

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
                          padding:
                              const EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 10.0),
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
                        changePercentInPeriod = selection.adjustedCloseEquity! /
                                open -
                            1; // changeInPeriod / selection.adjustedCloseEquity!;
                      } else {
                        changeInPeriod = close - open;
                        changePercentInPeriod =
                            close / open - 1; // changeInPeriod / close;
                      }
                      String? returnText = widget.user.getDisplayText(
                          changeInPeriod,
                          displayValue: DisplayValue.totalReturn);
                      String? returnPercentText = widget.user.getDisplayText(
                          changePercentInPeriod,
                          displayValue: DisplayValue.totalReturnPercent);
                      Icon todayIcon = widget.user
                          .getDisplayIcon(changeInPeriod, size: 27.0);

                      //return Text(value.selection!.beginsAt.toString());
                      return SizedBox(
                          //height: 72,
                          child: Column(
                        children: [
                          // ListTile(
                          //     title: const Text(
                          //       "Portfolio",
                          //       style: TextStyle(fontSize: 19.0),
                          //     ),
                          //     subtitle: Text(
                          //       // '${formatMediumDate.format(firstHistorical!.beginsAt!.toLocal())} -
                          //       formatLongDate.format(
                          //           lastHistorical!.beginsAt!.toLocal()),
                          //       // selection != null
                          //       // ? selection!.beginsAt!.toLocal()
                          //       // : lastHistorical!.beginsAt!.toLocal()),
                          //       style: const TextStyle(fontSize: 10.0),
                          //       overflow: TextOverflow.ellipsis,
                          //     ),
                          //     trailing: Wrap(spacing: 8, children: [
                          //       Text(
                          //         formatCurrency.format(close),
                          //         // selection != null
                          //         //  ? selection!.adjustedCloseEquity
                          //         //  : close),
                          //         style: const TextStyle(fontSize: 21.0),
                          //         textAlign: TextAlign.right,
                          //       )
                          //     ])
                          //     /*
                          //     Wrap(
                          //       children: [
                          //         Text(
                          //             formatCurrency.format(selection != null
                          //                 ? selection!.adjustedCloseEquity
                          //                 : close),
                          //             style: TextStyle(
                          //                 fontSize: 19, color: textColor)),
                          //         Container(
                          //           width: 10,
                          //         ),
                          //         Icon(
                          //           changeInPeriod > 0
                          //               ? Icons.trending_up
                          //               : (changeInPeriod < 0
                          //                   ? Icons.trending_down
                          //                   : Icons.trending_flat),
                          //           color: (changeInPeriod > 0
                          //               ? Colors.green
                          //               : (changeInPeriod < 0
                          //                   ? Colors.red
                          //                   : Colors.grey)),
                          //           //size: 16.0
                          //         ),
                          //         Container(
                          //           width: 2,
                          //         ),
                          //         Text(
                          //             formatPercentage
                          //                 //.format(selection!.netReturn!.abs()),
                          //                 .format(changePercentInPeriod.abs()),
                          //             style: TextStyle(
                          //                 fontSize: 19.0, color: textColor)),
                          //         Container(
                          //           width: 10,
                          //         ),
                          //         Text(
                          //             "${changeInPeriod > 0 ? "+" : changeInPeriod < 0 ? "-" : ""}${formatCurrency.format(changeInPeriod.abs())}",
                          //             style: TextStyle(
                          //                 fontSize: 19.0, color: textColor)),
                          //       ],
                          //     )*/
                          //     ),
                          SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 5),
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
                                                    textAlign: TextAlign.right,
                                                    style: const TextStyle(
                                                        fontSize:
                                                            summaryValueFontSize)),
                                                Text(
                                                    formatMediumDate.format(
                                                        selection != null
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
                                  selected:
                                      chartDateSpanFilter == ChartDateSpan.hour,
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
                                  label: const Text('Year'),
                                  selected:
                                      chartDateSpanFilter == ChartDateSpan.year,
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
                                  label: const Text('All'),
                                  selected:
                                      chartDateSpanFilter == ChartDateSpan.all,
                                  onSelected: (bool value) {
                                    if (value) {
                                      resetChart(
                                          ChartDateSpan.all, chartBoundsFilter);
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
                    //     style: const TextStyle(fontSize: 21.0),
                    //     textAlign: TextAlign.right,
                    //   )
                    // ]),
                  ),
                  ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: 175), // 320
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

            Consumer4<DividendStore, InterestStore, InstrumentPositionStore,
                    ChartSelectionStore>(
                builder: (context, dividendStore, interestStore,
                    instrumentPositionStore, chartSelectionStore, child) {
              return IncomeTransactionsWidget(widget.user, widget.service,
                  dividendStore, instrumentPositionStore, chartSelectionStore,
                  interestStore: interestStore,
                  showChips: false,
                  showList: false,
                  showFooter: false,
                  analytics: widget.analytics,
                  observer: widget.observer);
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
                widget.user,
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
                widget.user,
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
                        widget.user,
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
          ]), //controller: _controller,
    );
  }

  SingleChildScrollView buildDetailScrollView(
      Icon todayIcon,
      String todayReturnText,
      String todayReturnPercentText,
      Icon totalIcon,
      String totalReturnText,
      String totalReturnPercentText) {
    return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              /*
                                    Padding(
                                      padding: const EdgeInsets.all(
                                          summaryEgdeInset), //.symmetric(horizontal: 6),
                                      child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: <Widget>[
                                            Text(marketValueText,
                                                style: const TextStyle(
                                                    fontSize:
                                                        summaryValueFontSize)),
                                            //Container(height: 5),
                                            //const Text("Δ", style: TextStyle(fontSize: 15.0)),
                                            const Text("Market Value",
                                                style: TextStyle(
                                                    fontSize:
                                                        summaryLabelFontSize)),
                                          ]),
                                    ),
                                    */
              Padding(
                padding: const EdgeInsets.all(
                    summaryEgdeInset), //.symmetric(horizontal: 6),
                child:
                    Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                  Wrap(spacing: 8, children: [
                    todayIcon,
                    Text(todayReturnText,
                        style: const TextStyle(fontSize: summaryValueFontSize))
                  ]),
                  /*
                                          Text(todayReturnText,
                                              style: const TextStyle(
                                                  fontSize:
                                                      summaryValueFontSize)),
                                                      */
                  /*
                                  Text(todayReturnPercentText,
                                      style: const TextStyle(
                                          fontSize: summaryValueFontSize)),
                                          */
                  const Text("Return Today",
                      style: TextStyle(fontSize: summaryLabelFontSize)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(
                    summaryEgdeInset), //.symmetric(horizontal: 6),
                child:
                    Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                  Text(todayReturnPercentText,
                      style: const TextStyle(fontSize: summaryValueFontSize)),
                  const Text("Return Today %",
                      style: TextStyle(fontSize: summaryLabelFontSize)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(
                    summaryEgdeInset), //.symmetric(horizontal: 6),
                child:
                    Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                  Wrap(spacing: 8, children: [
                    totalIcon,
                    Text(totalReturnText,
                        style: const TextStyle(fontSize: summaryValueFontSize))
                  ]),
                  /*
                                          Text(totalReturnText,
                                              style: const TextStyle(
                                                  fontSize:
                                                      summaryValueFontSize)),
                                                      */
                  /*
                                  Text(totalReturnPercentText,
                                      style: const TextStyle(
                                          fontSize: summaryValueFontSize)),
                                          */
                  //Container(height: 5),
                  //const Text("Δ", style: TextStyle(fontSize: 15.0)),
                  const Text("Total Return",
                      style: TextStyle(fontSize: summaryLabelFontSize)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(
                    summaryEgdeInset), //.symmetric(horizontal: 6),
                child:
                    Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                  Text(totalReturnPercentText,
                      style: const TextStyle(fontSize: summaryValueFontSize)),

                  //Container(height: 5),
                  //const Text("Δ", style: TextStyle(fontSize: 15.0)),
                  const Text("Total Return %",
                      style: TextStyle(fontSize: summaryLabelFontSize)),
                ]),
              ),
            ])));
  }

  SliverAppBar buildSliverAppBar(
      //List<Portfolio>? portfolios,
      UserInfo? userInfo,
      Account? account,
      PortfolioStore portfolioStore,
      InstrumentPositionStore stockPositionStore,
      OptionPositionStore optionPositionStore,
      ForexHoldingStore forexHoldingStore) {
    positionSymbols = stockPositionStore.symbols;
    positionSymbols.sort((a, b) => (a.compareTo(b)));

    chainSymbols = optionPositionStore.symbols;
    chainSymbols.sort((a, b) => (a.compareTo(b)));

    // double changeInPeriod = 0;
    // double changePercentInPeriod = 0;
    // if (portfolioStore.items.isNotEmpty &&
    //     portfolioStore.items[0].equity != null &&
    //     portfolioStore.items[0].equityPreviousClose != null) {
    //   changeInPeriod = portfolioStore.items[0].equity! -
    //       portfolioStore.items[0].equityPreviousClose!;
    //   changePercentInPeriod =
    //       (changeInPeriod) / portfolioStore.items[0].equity!;
    // }
    var sliverAppBar = SliverAppBar(
      /* Drawer will automatically add menu to SliverAppBar.
                    leading: IconButton(
                      icon: const Icon(Icons.menu),
                      tooltip: 'Menu',
                      onPressed: () {/* ... */},
                    ),*/
      // backgroundColor: Colors.green,
      // brightness: Brightness.light,
      // expandedHeight: 185.0, //240.0, //280.0,
      //collapsedHeight: 80.0,
      /*
                      bottom: PreferredSize(
                        child: Icon(Icons.linear_scale, size: 60.0),
                        preferredSize: Size.fromHeight(50.0))
                        */
      floating: false,
      pinned: true,
      snap: false,
      /*
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(0),
        child: AppBar( )
        ),
        */
      //leading: Container(),
      /*IconButton(
        icon: const Icon(Icons.menu),
        tooltip: 'Menu',
        onPressed: () {/* ... */},
      ),*/
      title: Text(
        widget.title!, // ${userInfo?.profileName} (${widget.service.name})
        // style: const TextStyle(fontSize: 17.0)
      ),
      // Wrap(
      //     crossAxisAlignment: WrapCrossAlignment.end,
      //     //runAlignment: WrapAlignment.end,
      //     //alignment: WrapAlignment.end,
      //     spacing: 20,
      //     //runSpacing: 5,
      //     children: [
      //       if (userInfo != null) ...[
      //         Text(
      //             "${userInfo.profileName} (${widget.user.source == Source.robinhood ? Constants.robinhoodName : ''})",
      //             style: const TextStyle(
      //                 fontSize: 17.0)), //, color: Colors.white70
      //         Wrap(
      //             spacing: 10,
      //             crossAxisAlignment: WrapCrossAlignment.end,
      //             children: [
      //               Text(formatCurrency.format(portfolioValue),
      //                   style: const TextStyle(fontSize: 19.0)),
      //               //style: const TextStyle(fontSize: 20.0),
      //               //textAlign: TextAlign.right
      //               Wrap(
      //                   spacing: 2,
      //                   //crossAxisAlignment: WrapCrossAlignment.center,
      //                   //alignment: WrapAlignment.center,
      //                   children: [
      //                     Icon(
      //                         changeInPeriod > 0
      //                             ? Icons.trending_up
      //                             : (changeInPeriod < 0
      //                                 ? Icons.trending_down
      //                                 : Icons.trending_flat),
      //                         color: (changeInPeriod > 0
      //                             ? Colors.green
      //                             : (changeInPeriod < 0
      //                                 ? Colors.red
      //                                 : Colors.grey)),
      //                         size: 19.0),
      //                     Text(
      //                         formatPercentage
      //                             .format(changePercentInPeriod.abs()),
      //                         style: const TextStyle(fontSize: 16.0)),
      //                   ]),
      //               Text(
      //                   "${changeInPeriod > 0 ? "+" : changeInPeriod < 0 ? "-" : ""}${formatCurrency.format(changeInPeriod.abs())}",
      //                   style: const TextStyle(fontSize: 16.0)),
      //             ]),
      //       ]
      //     ]),
      flexibleSpace: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
        // // Disabled SliverAppBar effect for now
        // final settings = context
        //     .dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();

        // final deltaExtent = settings!.maxExtent - settings.minExtent;
        // final t =
        //     (1.0 - (settings.currentExtent - settings.minExtent) / deltaExtent)
        //         .clamp(0.0, 1.0);
        // final fadeStart = math.max(0.0, 1.0 - kToolbarHeight / deltaExtent);
        // const fadeEnd = 1.0;
        // final opacity = 1.0 - Interval(fadeStart, fadeEnd).transform(t);

        //bool visible = settings == null || settings.currentExtent <= settings.minExtent;

        // var shades = PieChart.makeShades(
        //     charts.ColorUtil.fromDartColor(
        //         Theme.of(context).colorScheme.primary),
        //     4);
        return FlexibleSpaceBar(
          expandedTitleScale: 1.2,
          // titlePadding:
          //     const EdgeInsets.only(top: kToolbarHeight * 2, bottom: 15),
          //centerTitle: true,
          //titlePadding: EdgeInsets.symmetric(horizontal: 5),
          //background: const FlutterLogo(),
          // background: const SizedBox(
          //   width: double.infinity,
          //   child:
          //       FlutterLogo()
          //   //Image.network(
          //   //  Constants.flexibleSpaceBarBackground,
          //   //  fit: BoxFit.cover,
          //   //)
          //   ,
          // ),
          // background: SizedBox(
          //     height: 180,
          //     width: 180,
          //     child: Padding(
          //       //padding: EdgeInsets.zero,
          //       //padding: EdgeInsets.symmetric(horizontal: 12.0),
          //       //padding: const EdgeInsets.all(10.0),
          //       padding: const EdgeInsets.fromLTRB(10, 100, 10, 10),
          //       child: PieChart(
          //         [
          //           charts.Series<PieChartData, String>(
          //             id: 'Portfolio Breakdown',
          //             //colorFn: (_, index) => shades[index!],
          //             //colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
          //             // colorFn: (_, index) => charts.MaterialPalette.cyan
          //             //     .makeShades(4)[index!],
          //             // colorFn: (_, __) => charts.ColorUtil.fromDartColor(
          //             //     Theme.of(context).colorScheme.primary),
          //             domainFn: (PieChartData val, index) => val.label,
          //             measureFn: (PieChartData val, index) => val.value,
          //             data: data,
          //           ),
          //         ],
          //         animate: false,
          //         renderer: charts.ArcRendererConfig(
          //             //arcWidth: 60,
          //             arcRendererDecorators: [
          //               new charts.ArcLabelDecorator()
          //             ]),
          //         onSelected: (_) {},
          //       ),
          //     )),

          // // Disabled SliverAppBar effect for now
          // title: Opacity(
          //     //duration: Duration(milliseconds: 300),
          //     opacity: opacity, //top > kToolbarHeight * 3 ? 1.0 : 0.0,
          //     child: //Container()
          //         SingleChildScrollView(
          //             child: _buildExpandedSliverAppBarTitle(
          //                 userInfo,
          //                 portfolioStore.items,
          //                 portfolioStore,
          //                 optionPositionStore,
          //                 stockPositionStore,
          //                 forexHoldingStore)))
        );
      }),
      actions: <Widget>[
        IconButton(
          icon: const Icon(Icons.more_vert),
          // icon: const Icon(Icons.settings),
          onPressed: () {
            showSettings();
          },
        ),
        /*
        IconButton(
          icon: ru != null && ru.userName != null
              ? const Icon(Icons.logout)
              : const Icon(Icons.login),
          tooltip: ru != null && ru.userName != null ? 'Logout' : 'Login',
          onPressed: () {
            if (ru != null && ru.userName != null) {
              var alert = AlertDialog(
                title: const Text('Logout process'),
                content: SingleChildScrollView(
                  child: ListBody(
                    children: <Widget>[
                      const Text(
                          'This action will require you to log in again.'),
                      const Text('Are you sure you want to log out?'),
                    ],
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    child: const Text('Cancel'),
                    onPressed: () {
                      Navigator.pop(context, 'dialog');
                    },
                  ),
                  TextButton(
                    child: const Text('OK'),
                    onPressed: () {
                      _logout();
                      Navigator.pop(context, 'dialog');
                    },
                  ),
                ],
              );
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return alert;
                },
              );
            } else {
              _openLogin();
            }
            /* ... */
          },
        ),*/
      ],
    );
    return sliverAppBar;
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
    if (widget.user.refreshEnabled &&
        widget.user.source == Source.robinhood &&
        (_notification == null || _notification == AppLifecycleState.resumed)) {
      if (account != null) {
        // // Added to attempt to fix a bug where cash balance does not refresh. TODO: Confirm
        // await service.getAccounts(
        //     widget.user,
        //     Provider.of<AccountStore>(context, listen: false),
        //     Provider.of<PortfolioStore>(context, listen: false),
        //     Provider.of<OptionPositionStore>(context, listen: false));
        // if (!mounted) return;
        await widget.service.getPortfolioHistoricals(
            widget.user,
            Provider.of<PortfolioHistoricalsStore>(context, listen: false),
            account!.accountNumber,
            chartBoundsFilter,
            chartDateSpanFilter);
      }
      if (!mounted) return;
      await widget.service.refreshOptionMarketData(
          widget.user,
          Provider.of<OptionPositionStore>(context, listen: false),
          Provider.of<OptionInstrumentStore>(context, listen: false));

      if (!mounted) return;
      await widget.service.refreshPositionQuote(
          widget.user,
          Provider.of<InstrumentPositionStore>(context, listen: false),
          Provider.of<QuoteStore>(context, listen: false));

      if (!mounted) return;
      await widget.service.getPortfolios(
          widget.user, Provider.of<PortfolioStore>(context, listen: false));

      if (!mounted) return;
      await widget.service.refreshNummusHoldings(
        widget.user,
        Provider.of<ForexHoldingStore>(context, listen: false),
      );
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
        widget.user,
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

  showSettings() {
    showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        //isScrollControlled: true,
        //useRootNavigator: true,
        //constraints: const BoxConstraints(maxHeight: 200),
        builder: (_) => MoreMenuBottomSheet(widget.user,
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
          action: SnackBarAction(
            label: 'Open',
            onPressed: () {
              OpenFile.open(file.path, type: 'text/csv');
            },
          )));
  }
  */
}
