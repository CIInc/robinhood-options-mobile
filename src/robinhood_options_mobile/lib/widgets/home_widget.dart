import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'dart:math' as math;

import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/equity_historical.dart';
import 'package:robinhood_options_mobile/model/forex_holding.dart';
import 'package:robinhood_options_mobile/model/forex_holding_store.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/portfolio.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals_selection_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_store.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';
import 'package:robinhood_options_mobile/model/stock_position.dart';
import 'package:robinhood_options_mobile/model/robinhood_user.dart';
import 'package:robinhood_options_mobile/model/stock_position_store.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/model/user_store.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
import 'package:robinhood_options_mobile/widgets/chart_bar_widget.dart';
import 'package:robinhood_options_mobile/widgets/chart_pie_widget.dart';
import 'package:robinhood_options_mobile/widgets/chart_time_series_widget.dart';
import 'package:robinhood_options_mobile/widgets/forex_instrument_widget.dart';
import 'package:robinhood_options_mobile/widgets/disclaimer_widget.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';
import 'package:robinhood_options_mobile/widgets/more_menu_widget.dart';
import 'package:robinhood_options_mobile/widgets/option_positions_row_widget.dart';

final formatDate = DateFormat("yMMMd");
final formatMediumDate = DateFormat("EEE MMM d, y hh:mm:ss a");
final formatLongDate = DateFormat("EEEE MMMM d, y hh:mm:ss a");
final formatCompactDate = DateFormat("MMMd");
final formatCurrency = NumberFormat.simpleCurrency();
final formatCompactCurrency = NumberFormat.compactCurrency();
final formatPercentage = NumberFormat.decimalPercentPattern(decimalDigits: 2);
final formatCompactNumber = NumberFormat.compact();

/*
class DrawerItem {
  String title;
  IconData icon;
  DrawerItem(this.title, this.icon);
}
*/
class HomePage extends StatefulWidget {
  final RobinhoodUser user;
  final UserInfo userInfo;
  //final Account account;
  /*
  final drawerItems = [
    new DrawerItem("Home", Icons.home),
    //new DrawerItem("Account", Icons.verified_user),
    new DrawerItem("Options", Icons.library_books),
    new DrawerItem("Logout", Icons.logout),
  ];
  */

  const HomePage(this.user, this.userInfo, // this.account,
      {Key? key,
      this.title,
      this.navigatorKey,
      //required this.onUserChanged,
      required this.onAccountsChanged})
      : super(key: key);

  final GlobalKey<NavigatorState>? navigatorKey;
  //final ValueChanged<RobinhoodUser?> onUserChanged;
  final ValueChanged<List<Account>> onAccountsChanged;

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String? title;

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
//with AutomaticKeepAliveClientMixin<HomePage>
{
  Future<List<Account>>? futureAccounts;
  List<Account>? accounts;
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
  EquityHistorical? selection;

  Future<StockPositionStore>? futureStockPositions;
  //Stream<StockPositionStore>? positionStoreStream;
  Future<OptionPositionStore>? futureOptionPositions;
  //Stream<OptionPositionStore>? optionPositionStoreStream;

  /*
  Stream<List<StockPosition>>? positionStream;
  List<StockPosition> positions = [];
  Stream<List<StockOrder>>? positionOrderStream;

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

  _HomePageState();

  /*
  @override
  bool get wantKeepAlive => true;
  */

  @override
  void initState() {
    super.initState();

    _startRefreshTimer();
  }

  @override
  void dispose() {
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
    /* For navigation within this tab, uncomment
    return WillPopScope(
      onWillPop: () => Future.value(false),
      child: Scaffold(
          //appBar: _buildFlowAppBar(),
          body: Navigator(
              key: widget.navigatorKey,
              onGenerateRoute: (_) =>
                  MaterialPageRoute(builder: (_) => _buildScaffold()))),
    );
    */
    return WillPopScope(
        onWillPop: () => Future.value(false), child: _buildScaffold());
  }

  Widget _buildScaffold() {
    Provider.of<UserStore>(context, listen: true);

    futureAccounts ??= RobinhoodService.getAccounts(
        widget.user, Provider.of<AccountStore>(context, listen: false));

    futurePortfolios ??= RobinhoodService.getPortfolios(
        widget.user, Provider.of<PortfolioStore>(context, listen: false));
    //futureNummusAccounts ??= RobinhoodService.downloadNummusAccounts(widget.user);
    futureNummusHoldings ??= RobinhoodService.getNummusHoldings(
        widget.user, Provider.of<ForexHoldingStore>(context, listen: false),
        nonzero: !hasQuantityFilters[1]);

    futureOptionPositions ??= RobinhoodService.getOptionPositionStore(
        widget.user,
        Provider.of<OptionPositionStore>(context, listen: false),
        Provider.of<InstrumentStore>(context, listen: false),
        nonzero: !hasQuantityFilters[1]);

    futureStockPositions ??= RobinhoodService.getStockPositionStore(
        widget.user,
        Provider.of<StockPositionStore>(context, listen: false),
        Provider.of<InstrumentStore>(context, listen: false),
        Provider.of<QuoteStore>(context, listen: false),
        nonzero: !hasQuantityFilters[1]);

    /*
    positionStoreStream ??= RobinhoodService.streamStockPositionStore(
        widget.user,
        Provider.of<StockPositionStore>(context, listen: false),
        Provider.of<InstrumentStore>(context, listen: false),
        Provider.of<QuoteStore>(context, listen: false),
        nonzero: !hasQuantityFilters[1]);
    optionPositionStoreStream ??= RobinhoodService.streamOptionPositionStore(
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
      ]),
      builder: (context1, dataSnapshot) {
        if (dataSnapshot.hasData) {
          List<dynamic> data = dataSnapshot.data as List<dynamic>;
          List<Account> accts = data[0] as List<Account>;
          if (accounts != accts) {
            accounts = accts;
            account = accounts!.first;
            WidgetsBinding.instance!.addPostFrameCallback(
                (_) => widget.onAccountsChanged(accounts!));
          }

          futurePortfolioHistoricals ??=
              RobinhoodService.getPortfolioHistoricals(
                  widget.user,
                  Provider.of<PortfolioHistoricalsStore>(context,
                      listen: false),
                  account!.accountNumber,
                  chartBoundsFilter,
                  chartDateSpanFilter);
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
              userInfo: widget.userInfo, account: account);
          //});
        } else if (dataSnapshot.hasError) {
          debugPrint("${dataSnapshot.error}");
          /*
          if (dataSnapshot.error.toString() ==
              "OAuth authorization error (invalid_grant).") {
            RobinhoodUser.clearUserFromStore(userStore);
            // Causes: 'package:flutter/src/widgets/navigator.dart': Failed assertion: line 4841 pos 12: '!_debugLocked': is not true.
            //_openLogin();
          }
          */
          return _buildPage(context,
              //ru: snapshotUser,
              welcomeWidget: Text("${dataSnapshot.error}"));
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

  void _startRefreshTimer() {
    // Start listening to clipboard
    refreshTriggerTime = Timer.periodic(
      const Duration(milliseconds: 15000),
      (timer) async {
        if (widget.user.refreshEnabled) {
          await RobinhoodService.getPortfolioHistoricals(
              widget.user,
              Provider.of<PortfolioHistoricalsStore>(context, listen: false),
              account!.accountNumber,
              chartBoundsFilter,
              chartDateSpanFilter);

          await RobinhoodService.refreshOptionMarketData(widget.user,
              Provider.of<OptionPositionStore>(context, listen: false));

          await RobinhoodService.refreshPositionQuote(
              widget.user,
              Provider.of<StockPositionStore>(context, listen: false),
              Provider.of<QuoteStore>(context, listen: false));

          await RobinhoodService.getPortfolios(
              widget.user, Provider.of<PortfolioStore>(context, listen: false));

          await RobinhoodService.refreshNummusHoldings(
            widget.user,
            Provider.of<ForexHoldingStore>(context, listen: false),
          );
        }
      },
    );
  }

  void _stopRefreshTimer() {
    if (refreshTriggerTime != null) {
      refreshTriggerTime!.cancel();
    }
  }

  _onChartSelection(dynamic historical) {
    var provider =
        Provider.of<PortfolioHistoricalsSelectionStore>(context, listen: false);
    provider.selectionChanged(historical);
    /*
    if (historical != null) {
      if (selection != historical as EquityHistorical) {
        setState(() {
          selection = historical;
        });
      }
    } else {
      if (selection != historical) {
        setState(() {
          selection = null;
        });
      }
    }
    */
  }

  void resetChart(ChartDateSpan span, Bounds bounds) async {
    setState(() {
      prevChartDateSpanFilter = chartDateSpanFilter;
      chartDateSpanFilter = span;
      prevChartBoundsFilter = chartBoundsFilter;
      chartBoundsFilter = bounds;
      futurePortfolioHistoricals = null;
    });
    /*
    chartDateSpanFilter = span;
    chartBoundsFilter = bounds;
    await RobinhoodService.getPortfolioHistoricals(
        widget.user,
        Provider.of<PortfolioHistoricalsStore>(context, listen: false),
        account!.accountNumber,
        chartBoundsFilter,
        chartDateSpanFilter);
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
      bool done = true}) {
    //debugPrint('_buildPage');
    return RefreshIndicator(
      child: CustomScrollView(
          // physics: ClampingScrollPhysics(),
          slivers: [
            Consumer4<PortfolioStore, StockPositionStore, OptionPositionStore,
                ForexHoldingStore>(
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

            Consumer<
                PortfolioHistoricalsStore /*, PortfolioStore,
                    ForexHoldingStore*/
                >(builder: (context,
                portfolioHistoricalsStore /*, portfolioStore,
                    forexHoldingStore*/
                ,
                child) {
              /*
                if (portfolioHistoricals != null) {
                  debugPrint(
                      'data: ${portfolioHistoricals!.bounds} ${portfolioHistoricals!.span} chip: ${chartBoundsFilter.toString()} ${chartDateSpanFilter.toString()}');
                }
                */
              portfolioHistoricals = portfolioHistoricalsStore.items
                  .firstWhereOrNull((element) =>
                          element.span ==
                              RobinhoodService.convertChartSpanFilter(
                                  chartDateSpanFilter) &&
                          element.bounds ==
                              RobinhoodService.convertChartBoundsFilter(
                                  chartBoundsFilter)
                      //&& element.interval == element.interval
                      );
              if (portfolioHistoricals == null) {
                portfolioHistoricals = portfolioHistoricalsStore.items
                    .firstWhereOrNull(
                        (element) =>
                            element.span ==
                                RobinhoodService.convertChartSpanFilter(
                                    prevChartDateSpanFilter) &&
                            element.bounds ==
                                RobinhoodService.convertChartBoundsFilter(
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

              firstHistorical = portfolioHistoricals!.equityHistoricals[0];
              lastHistorical = portfolioHistoricals!.equityHistoricals[
                  portfolioHistoricals!.equityHistoricals.length - 1];
              open = portfolioHistoricals!.adjustedPreviousCloseEquity ??
                  firstHistorical.adjustedOpenEquity!;
              close = lastHistorical.adjustedCloseEquity!;
              changeInPeriod = close - open;
              changePercentInPeriod = changeInPeriod / close;

              // Override the portfolio API with current historical data.
              //portfolioValue = close;

              var brightness = MediaQuery.of(context).platformBrightness;
              var textColor = Theme.of(context).colorScheme.background;
              if (brightness == Brightness.dark) {
                textColor = Colors.grey.shade200;
              } else {
                textColor = Colors.grey.shade800;
              }
              TimeSeriesChart historicalChart = TimeSeriesChart(
                  [
                    charts.Series<EquityHistorical, DateTime>(
                      id: 'Adjusted Equity',
                      colorFn: (_, __) => charts.ColorUtil.fromDartColor(
                          Theme.of(context).colorScheme.primary),
                      //charts.MaterialPalette.blue.shadeDefault,
                      domainFn: (EquityHistorical history, _) =>
                          history.beginsAt!,
                      //filteredEquityHistoricals.indexOf(history),
                      measureFn: (EquityHistorical history, index) => index == 0
                          ? history.adjustedOpenEquity
                          : history.adjustedCloseEquity,
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
                  open: open,
                  close: close,
                  hiddenSeries: const ['Equity', 'Market Value'],
                  onSelected: _onChartSelection);

              return SliverToBoxAdapter(
                  child: Column(children: [
                Consumer<PortfolioHistoricalsSelectionStore>(
                    builder: (context, value, child) {
                  selection = value.selection;
                  if (selection != null) {
                    changeInPeriod = selection!.adjustedCloseEquity! -
                        open; // portfolios![0].equityPreviousClose!;
                    changePercentInPeriod =
                        changeInPeriod / selection!.adjustedCloseEquity!;
                  } else {
                    changeInPeriod = close - open;
                    changePercentInPeriod = changeInPeriod / close;
                  }

                  //return Text(value.selection!.beginsAt.toString());
                  return SizedBox(
                      height: 72,
                      child: Column(
                        children: [
                          ListTile(
                            title: /*const Text(
                      "Portfolio",
                      style: TextStyle(fontSize: 19.0),)
                      */
                                Wrap(
                              children: [
                                /*
                                  const Text(
                                    "Portfolio",
                                    style: TextStyle(fontSize: 19.0),
                                  ),
                                  Container(
                                    width: 10,
                                  ),
                                  */
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
                          ),
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
                    height: 240,
                    child: Padding(
                      //padding: EdgeInsets.symmetric(horizontal: 12.0),
                      padding: const EdgeInsets.all(10.0),
                      child: historicalChart,
                    )),
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
                                  resetChart(
                                      ChartDateSpan.hour, chartBoundsFilter);
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
                              selected:
                                  chartDateSpanFilter == ChartDateSpan.month_3,
                              onSelected: (bool value) {
                                if (value) {
                                  resetChart(
                                      ChartDateSpan.month_3, chartBoundsFilter);
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
                                  resetChart(chartDateSpanFilter, Bounds.t24_7);
                                }
                              },
                            ),
                          ),
                        ]);
                      },
                      itemCount: 1,
                    )),
              ]));
            }),

            Consumer4<PortfolioStore, StockPositionStore, OptionPositionStore,
                    ForexHoldingStore>(
                builder: (context, portfolioStore, stockPositionStore,
                    optionPositionStore, forexHoldingStore, child) {
              List<PieChartData> data = [];
              //if (portfolioStore.items.isNotEmpty) {
              //var portfolioValue = (portfolioStore.items[0].equity ?? 0) + forexHoldingStore.equity;
              //var stockAndOptionsEquityPercent = portfolioStore.items[0].marketValue! / portfolioValue;
              data.add(PieChartData(
                  'Options\n${formatCompactNumber.format(optionPositionStore.equity)}',
                  optionPositionStore.equity)); // / portfolioValue
              data.add(PieChartData(
                  'Stocks\n${formatCompactNumber.format(stockPositionStore.equity)}',
                  stockPositionStore.equity)); // / portfolioValue
              data.add(PieChartData(
                  'Crypto\n${formatCompactNumber.format(forexHoldingStore.equity)}',
                  forexHoldingStore.equity)); // / portfolioValue
              double portfolioCash =
                  account != null ? account.portfolioCash! : 0;
              data.add(PieChartData(
                  'Cash\n${formatCompactNumber.format(portfolioCash)}',
                  portfolioCash)); // / portfolioValue
              //}
              data.sort((a, b) => b.value.compareTo(a.value));
              var shades = PieChart.makeShades(
                  charts.ColorUtil.fromDartColor(
                      Theme.of(context).colorScheme.primary),
                  4);
              var total = data.map((e) => e.value).reduce((a, b) => a + b);
              return SliverToBoxAdapter(
                  child: Center(
                child: SizedBox(
                    height: 240,
                    width: 240,
                    child: Padding(
                      padding: EdgeInsets.zero,
                      //padding: EdgeInsets.symmetric(horizontal: 1.0),
                      //padding: const EdgeInsets.all(10.0),
                      child: total > 0
                          ? PieChart(
                              [
                                charts.Series<PieChartData, String>(
                                  id: 'Portfolio Breakdown',
                                  colorFn: (_, index) => shades[index!],
                                  /*
                            colorFn: (_, index) => charts.MaterialPalette.cyan
                                .makeShades(4)[index!],
                            colorFn: (_, __) => charts.ColorUtil.fromDartColor(
                                Theme.of(context).colorScheme.primary),
                            */
                                  domainFn: (PieChartData val, index) =>
                                      val.label,
                                  measureFn: (PieChartData val, index) =>
                                      val.value,
                                  data: data,
                                ),
                              ],
                              animate: false,
                              renderer: charts.ArcRendererConfig(
                                  //arcWidth: 60,
                                  arcRendererDecorators: [
                                    charts.ArcLabelDecorator()
                                  ]),
                              onSelected: (_) {},
                            )
                          : Container(),
                    )),
                /*
                SizedBox(
                    height: 240,
                    width: 200,
                    child: Padding(
                      //padding: EdgeInsets.symmetric(horizontal: 12.0),
                      padding: const EdgeInsets.all(10.0),
                      child: PieChart(
                        [
                          charts.Series<PieChartData, String>(
                            id: 'Portfolio Breakdown',
                            //colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
                            domainFn: (PieChartData val, index) => val.label,
                            measureFn: (PieChartData val, index) => val.value,
                            data: data,
                          ),
                        ],
                        renderer: new charts.ArcRendererConfig(
                            //arcWidth: 60,
                            arcRendererDecorators: [
                              new charts.ArcLabelDecorator()
                            ]),
                        onSelected: (_) {},
                      ),
                    ))
                    */
              ));
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

              return SliverToBoxAdapter(
                  child: ShrinkWrappingViewport(
                      offset: ViewportOffset.zero(),
                      slivers: [
                    if (filteredOptionAggregatePositions.isNotEmpty) ...[
                      /*
                      const SliverToBoxAdapter(
                          child: SizedBox(
                        height: 25.0,
                      )),
                      */
                      OptionPositionsRowWidget(
                          widget.user,
                          //account!,
                          filteredOptionAggregatePositions)
                    ],
                    const SliverToBoxAdapter(
                        child: SizedBox(
                      height: 25.0,
                    ))
                  ]));
            }),
            Consumer<StockPositionStore>(
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

              List<charts.Series<dynamic, String>> barChartSeriesList = [];
              var data = [];
              for (var position in filteredPositions) {
                if (position.instrumentObj != null) {
                  double? value = widget.user.getPositionDisplayValue(position);
                  String? trailingText = widget.user.getDisplayText(value);
                  data.add({
                    'domain': position.instrumentObj!.symbol,
                    'measure': value,
                    'label': trailingText
                  });
                }
              }
              barChartSeriesList.add(charts.Series<dynamic, String>(
                id: widget.user.displayValue.toString(),
                data: data,
                colorFn: (_, __) => charts.ColorUtil.fromDartColor(
                    Theme.of(context).colorScheme.primary),
                domainFn: (var d, _) => d['domain'],
                measureFn: (var d, _) => d['measure'],
                labelAccessorFn: (d, _) => d['label'],
              ));
              var brightness = MediaQuery.of(context).platformBrightness;
              var axisLabelColor = charts.MaterialPalette.gray.shade500;
              if (brightness == Brightness.light) {
                axisLabelColor = charts.MaterialPalette.gray.shade700;
              }
              var primaryMeasureAxis = charts.NumericAxisSpec(
                //showAxisLine: true,
                //renderSpec: charts.GridlineRendererSpec(),
                renderSpec: charts.GridlineRendererSpec(
                    labelStyle: charts.TextStyleSpec(color: axisLabelColor)),
                //renderSpec: charts.NoneRenderSpec(),
                //tickProviderSpec: charts.BasicNumericTickProviderSpec(),
                //tickProviderSpec: charts.NumericEndPointsTickProviderSpec(),
                //tickProviderSpec:
                //    charts.StaticNumericTickProviderSpec(widget.staticNumericTicks!),
                //viewport: charts.NumericExtents(0, widget.staticNumericTicks![widget.staticNumericTicks!.length - 1].value + 1)
              );
              if (widget.user.displayValue == DisplayValue.todayReturnPercent ||
                  widget.user.displayValue == DisplayValue.totalReturnPercent) {
                var positionDisplayValues = filteredPositions
                    .map((e) => widget.user.getPositionDisplayValue(e));
                var minimum = 0.0;
                var maximum = 0.0;
                if (positionDisplayValues.isNotEmpty) {
                  minimum = positionDisplayValues.reduce(math.min);
                  if (minimum < 0) {
                    minimum -= 0.05;
                  } else if (minimum > 0) {
                    minimum = 0;
                  }
                  maximum = positionDisplayValues.reduce(math.max);
                  if (maximum > 0) {
                    maximum += 0.05;
                  } else if (maximum < 0) {
                    maximum = 0;
                  }
                }

                primaryMeasureAxis = charts.PercentAxisSpec(
                    viewport: charts.NumericExtents(minimum, maximum),
                    renderSpec: charts.GridlineRendererSpec(
                        labelStyle:
                            charts.TextStyleSpec(color: axisLabelColor)));
              }
              var positionChart = BarChart(barChartSeriesList,
                  renderer: charts.BarRendererConfig(
                      barRendererDecorator: charts.BarLabelDecorator<String>(),
                      cornerStrategy: const charts.ConstCornerStrategy(10)),
                  primaryMeasureAxis: primaryMeasureAxis,
                  barGroupingType: null,
                  domainAxis: charts.OrdinalAxisSpec(
                      renderSpec: charts.SmallTickRendererSpec(
                          labelStyle:
                              charts.TextStyleSpec(color: axisLabelColor))),
                  onSelected: (_) {});

              double? marketValue = widget.user
                  .getPositionAggregateDisplayValue(filteredPositions,
                      displayValue: DisplayValue.marketValue);
              String? marketValueText = widget.user.getDisplayText(marketValue!,
                  displayValue: DisplayValue.marketValue);

              double? totalReturn = widget.user
                  .getPositionAggregateDisplayValue(filteredPositions,
                      displayValue: DisplayValue.totalReturn);
              String? totalReturnText = widget.user.getDisplayText(totalReturn!,
                  displayValue: DisplayValue.totalReturn);

              double? totalReturnPercent = widget.user
                  .getPositionAggregateDisplayValue(filteredPositions,
                      displayValue: DisplayValue.totalReturnPercent);
              String? totalReturnPercentText = widget.user.getDisplayText(
                  totalReturnPercent!,
                  displayValue: DisplayValue.totalReturnPercent);

              double? todayReturn = widget.user
                  .getPositionAggregateDisplayValue(filteredPositions,
                      displayValue: DisplayValue.todayReturn);
              String? todayReturnText = widget.user.getDisplayText(todayReturn!,
                  displayValue: DisplayValue.todayReturn);

              double? todayReturnPercent = widget.user
                  .getPositionAggregateDisplayValue(filteredPositions,
                      displayValue: DisplayValue.todayReturnPercent);
              String? todayReturnPercentText = widget.user.getDisplayText(
                  todayReturnPercent!,
                  displayValue: DisplayValue.todayReturnPercent);

              Icon todayIcon =
                  widget.user.getDisplayIcon(todayReturn, size: 21.0);
              Icon totalIcon =
                  widget.user.getDisplayIcon(totalReturn, size: 21.0);

              return SliverToBoxAdapter(
                  child: ShrinkWrappingViewport(
                      offset: ViewportOffset.zero(),
                      slivers: [
                    SliverToBoxAdapter(
                        child: Column(children: [
                      ListTile(
                        title: const Text(
                          "Stocks",
                          style: TextStyle(fontSize: 19.0),
                        ),
                        subtitle: Text(
                            "${formatCompactNumber.format(filteredPositions.length)} positions"), // , ${formatCurrency.format(positionEquity)} market value // of ${formatCompactNumber.format(positions.length)}
                        trailing: Wrap(spacing: 8, children: [
                          Text(
                            marketValueText,
                            style: const TextStyle(fontSize: 21.0),
                            textAlign: TextAlign.right,
                          )
                          /*
                          if (icon != null) ...[
                            icon,
                          ],
                          if (trailingText != null) ...[
                            Text(
                              trailingText,
                              style: const TextStyle(fontSize: 21.0),
                              textAlign: TextAlign.right,
                            )
                          ]
                          */
                        ]),
                      ),
                      /*
        if (widget.user.displayValue != DisplayValue.lastPrice) ...[
          SizedBox(
              height: barChartSeriesList.first.data.length == 1
                  ? 75
                  : barChartSeriesList.first.data.length * 50,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    10.0, 0, 10, 10), //EdgeInsets.zero
                child: positionChart,
              )),
        ],
        */
                      SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 5),
                              child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
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
                                      child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: <Widget>[
                                            Wrap(spacing: 8, children: [
                                              todayIcon,
                                              Text(todayReturnText,
                                                  style: const TextStyle(
                                                      fontSize:
                                                          summaryValueFontSize))
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
                                            Text(todayReturnPercentText,
                                                style: const TextStyle(
                                                    fontSize:
                                                        summaryValueFontSize)),
                                            const Text("Return Today %",
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
                                            Wrap(spacing: 8, children: [
                                              totalIcon,
                                              Text(totalReturnText,
                                                  style: const TextStyle(
                                                      fontSize:
                                                          summaryValueFontSize))
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
                                            Text(totalReturnPercentText,
                                                style: const TextStyle(
                                                    fontSize:
                                                        summaryValueFontSize)),

                                            //Container(height: 5),
                                            //const Text("Δ", style: TextStyle(fontSize: 15.0)),
                                            const Text("Total Return %",
                                                style: TextStyle(
                                                    fontSize:
                                                        summaryLabelFontSize)),
                                          ]),
                                    ),
                                  ])))
                    ])),
                    if (widget.user.displayValue != DisplayValue.lastPrice &&
                        barChartSeriesList.isNotEmpty &&
                        barChartSeriesList.first.data.isNotEmpty) ...[
                      SliverToBoxAdapter(
                          child: SizedBox(
                              height: barChartSeriesList.first.data.length == 1
                                  ? 75
                                  : barChartSeriesList.first.data.length * 50,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    10.0, 0, 10, 10), //EdgeInsets.zero
                                child: positionChart,
                              )))
                    ],
                    SliverList(
                      // delegate: SliverChildListDelegate(widgets),
                      delegate: SliverChildBuilderDelegate(
                        (BuildContext context, int index) {
                          return _buildPositionRow(filteredPositions, index);
                        },
                        // Or, uncomment the following line:
                        childCount: filteredPositions.length,
                      ),
                    ),
                    const SliverToBoxAdapter(
                        child: SizedBox(
                      height: 25.0,
                    ))
                  ]));
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
                    .toList();
                /*
                double? value = widget.user
                    .getCryptoAggregateDisplayValue(filteredHoldings);
                String? trailingText;
                Icon? icon;
                if (value != null) {
                  trailingText = widget.user.getDisplayText(value);
                  icon = widget.user.getDisplayIcon(value);
                }
                */

                List<charts.Series<dynamic, String>> barChartSeriesList = [];
                var data = [];
                for (var position in filteredHoldings) {
                  if (position.quoteObj != null) {
                    double? value = widget.user.getCryptoDisplayValue(position);
                    String? trailingText = widget.user.getDisplayText(value);
                    data.add({
                      'domain': position.currencyCode,
                      'measure': value,
                      'label': trailingText
                    });
                  }
                }
                barChartSeriesList.add(charts.Series<dynamic, String>(
                  id: widget.user.displayValue.toString(),
                  data: data,
                  colorFn: (_, __) => charts.ColorUtil.fromDartColor(
                      Theme.of(context).colorScheme.primary),
                  domainFn: (var d, _) => d['domain'],
                  measureFn: (var d, _) => d['measure'],
                  labelAccessorFn: (d, _) => d['label'],
                ));
                var brightness = MediaQuery.of(context).platformBrightness;
                var axisLabelColor = charts.MaterialPalette.gray.shade500;
                if (brightness == Brightness.light) {
                  axisLabelColor = charts.MaterialPalette.gray.shade700;
                }
                var primaryMeasureAxis = charts.NumericAxisSpec(
                  //showAxisLine: true,
                  //renderSpec: charts.GridlineRendererSpec(),
                  renderSpec: charts.GridlineRendererSpec(
                      labelStyle: charts.TextStyleSpec(color: axisLabelColor)),
                  //renderSpec: charts.NoneRenderSpec(),
                  //tickProviderSpec: charts.BasicNumericTickProviderSpec(),
                  //tickProviderSpec: charts.NumericEndPointsTickProviderSpec(),
                  //tickProviderSpec:
                  //    charts.StaticNumericTickProviderSpec(widget.staticNumericTicks!),
                  //viewport: charts.NumericExtents(0, widget.staticNumericTicks![widget.staticNumericTicks!.length - 1].value + 1)
                );
                if (widget.user.displayValue ==
                        DisplayValue.todayReturnPercent ||
                    widget.user.displayValue ==
                        DisplayValue.totalReturnPercent) {
                  var positionDisplayValues = filteredHoldings
                      .map((e) => widget.user.getCryptoDisplayValue(e));
                  var minimum = 0.0;
                  var maximum = 0.0;
                  if (positionDisplayValues.isNotEmpty) {
                    minimum = positionDisplayValues.reduce(math.min);
                    if (minimum < 0) {
                      minimum -= 0.05;
                    } else if (minimum > 0) {
                      minimum = 0;
                    }
                    maximum = positionDisplayValues.reduce(math.max);
                    if (maximum > 0) {
                      maximum += 0.05;
                    } else if (maximum < 0) {
                      maximum = 0;
                    }
                  }

                  primaryMeasureAxis = charts.PercentAxisSpec(
                      viewport: charts.NumericExtents(minimum, maximum),
                      renderSpec: charts.GridlineRendererSpec(
                          labelStyle:
                              charts.TextStyleSpec(color: axisLabelColor)));
                }
                var positionChart = BarChart(barChartSeriesList,
                    renderer: charts.BarRendererConfig(
                        barRendererDecorator:
                            charts.BarLabelDecorator<String>(),
                        cornerStrategy: const charts.ConstCornerStrategy(10)),
                    primaryMeasureAxis: primaryMeasureAxis,
                    barGroupingType: null,
                    domainAxis: charts.OrdinalAxisSpec(
                        renderSpec: charts.SmallTickRendererSpec(
                            labelStyle:
                                charts.TextStyleSpec(color: axisLabelColor))),
                    onSelected: (_) {});

                double? marketValue = widget.user
                    .getCryptoAggregateDisplayValue(filteredHoldings,
                        displayValue: DisplayValue.marketValue);
                String? marketValueText = widget.user.getDisplayText(
                    marketValue!,
                    displayValue: DisplayValue.marketValue);

                double? totalReturn = widget.user
                    .getCryptoAggregateDisplayValue(filteredHoldings,
                        displayValue: DisplayValue.totalReturn);
                String? totalReturnText = widget.user.getDisplayText(
                    totalReturn!,
                    displayValue: DisplayValue.totalReturn);

                double? totalReturnPercent = widget.user
                    .getCryptoAggregateDisplayValue(filteredHoldings,
                        displayValue: DisplayValue.totalReturnPercent);
                String? totalReturnPercentText = widget.user.getDisplayText(
                    totalReturnPercent!,
                    displayValue: DisplayValue.totalReturnPercent);

                double? todayReturn = widget.user
                    .getCryptoAggregateDisplayValue(filteredHoldings,
                        displayValue: DisplayValue.todayReturn);
                String? todayReturnText = widget.user.getDisplayText(
                    todayReturn!,
                    displayValue: DisplayValue.todayReturn);

                double? todayReturnPercent = widget.user
                    .getCryptoAggregateDisplayValue(filteredHoldings,
                        displayValue: DisplayValue.todayReturnPercent);
                String? todayReturnPercentText = widget.user.getDisplayText(
                    todayReturnPercent!,
                    displayValue: DisplayValue.todayReturnPercent);

                Icon todayIcon =
                    widget.user.getDisplayIcon(todayReturn, size: 21.0);
                Icon totalIcon =
                    widget.user.getDisplayIcon(totalReturn, size: 21.0);

                return SliverToBoxAdapter(
                    child: ShrinkWrappingViewport(
                        offset: ViewportOffset.zero(),
                        slivers: [
                      SliverToBoxAdapter(
                          child: Column(children: [
                        ListTile(
                            title: const Text(
                              "Cryptos",
                              style: TextStyle(fontSize: 19.0),
                            ),
                            subtitle: Text(
                                "${formatCompactNumber.format(filteredHoldings.length)} cryptos"), // , ${formatCurrency.format(nummusEquity)} market value // of ${formatCompactNumber.format(nummusHoldings.length)}
                            trailing: Wrap(spacing: 8, children: [
                              Text(
                                marketValueText,
                                style: const TextStyle(fontSize: 21.0),
                                textAlign: TextAlign.right,
                              )
                              /*
                              if (icon != null) ...[
                                icon,
                              ],
                              if (trailingText != null) ...[
                                Text(
                                  trailingText,
                                  style: const TextStyle(fontSize: 21.0),
                                  textAlign: TextAlign.right,
                                )
                              ]
                              */
                            ])),
                        SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 5),
                                child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
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
                                        child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: <Widget>[
                                              Wrap(spacing: 8, children: [
                                                todayIcon,
                                                Text(todayReturnText,
                                                    style: const TextStyle(
                                                        fontSize:
                                                            summaryValueFontSize))
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
                                              Text(todayReturnPercentText,
                                                  style: const TextStyle(
                                                      fontSize:
                                                          summaryValueFontSize)),
                                              const Text("Return Today %",
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
                                              Wrap(spacing: 8, children: [
                                                totalIcon,
                                                Text(totalReturnText,
                                                    style: const TextStyle(
                                                        fontSize:
                                                            summaryValueFontSize))
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
                                              Text(totalReturnPercentText,
                                                  style: const TextStyle(
                                                      fontSize:
                                                          summaryValueFontSize)),

                                              //Container(height: 5),
                                              //const Text("Δ", style: TextStyle(fontSize: 15.0)),
                                              const Text("Total Return %",
                                                  style: TextStyle(
                                                      fontSize:
                                                          summaryLabelFontSize)),
                                            ]),
                                      ),
                                    ])))
                      ])),
                      if (widget.user.displayValue != DisplayValue.lastPrice &&
                          barChartSeriesList.isNotEmpty &&
                          barChartSeriesList.first.data.isNotEmpty) ...[
                        SliverToBoxAdapter(
                            child: SizedBox(
                                height: barChartSeriesList.first.data.length ==
                                        1
                                    ? 75
                                    : barChartSeriesList.first.data.length * 50,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      10.0, 0, 10, 10), //EdgeInsets.zero
                                  child: positionChart,
                                )))
                      ],
                      SliverList(
                        // delegate: SliverChildListDelegate(widgets),
                        delegate: SliverChildBuilderDelegate(
                          (BuildContext context, int index) {
                            return _buildCryptoRow(filteredHoldings, index);
                          },
                          // Or, uncomment the following line:
                          childCount: filteredHoldings.length,
                        ),
                      ),
                      const SliverToBoxAdapter(
                          child: SizedBox(
                        height: 25.0,
                      ))
                    ]));
              },
            ),
            /*
            Consumer<PortfolioStore>(builder: (context, portfolioStore, child) {
              return SliverToBoxAdapter(
                  child: ShrinkWrappingViewport(
                      offset: ViewportOffset.zero(),
                      slivers: [
                    SliverToBoxAdapter(
                        child: Column(children: const [
                      ListTile(
                        title: Text(
                          "Portfolios",
                          style: TextStyle(fontSize: 19.0),
                        ),
                      )
                    ])),
                    portfoliosWidget(portfolioStore.items),
                    const SliverToBoxAdapter(
                        child: SizedBox(
                      height: 25.0,
                    ))
                  ]));
            }),
            */
            const SliverToBoxAdapter(child: DisclaimerWidget()),
            const SliverToBoxAdapter(
                child: SizedBox(
              height: 25.0,
            ))
          ]), //controller: _controller,
      onRefresh: _pullRefresh,
    );
  }

  Widget portfoliosWidget(List<Portfolio> portfolios) {
    return SliverList(
      // delegate: SliverChildListDelegate(widgets),
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) {
          if (portfolios.length > index) {
            var accountSplit = portfolios[index].account.split("/");
            return Card(
                child:
                    Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
              ListTile(
                title: const Text("Account", style: TextStyle(fontSize: 14)),
                trailing: Text(accountSplit[accountSplit.length - 2],
                    style: const TextStyle(fontSize: 16)),
              ),
              ListTile(
                title: const Text("Equity", style: TextStyle(fontSize: 14)),
                trailing: Text(formatCurrency.format(portfolios[index].equity),
                    style: const TextStyle(fontSize: 16)),
              ),
              ListTile(
                title: const Text("Extended Hours Equity",
                    style: TextStyle(fontSize: 14)),
                trailing: Text(
                    portfolios[index].extendedHoursEquity != null
                        ? formatCurrency
                            .format(portfolios[index].extendedHoursEquity)
                        : "",
                    style: const TextStyle(fontSize: 16)),
              ),
              ListTile(
                title: const Text("Last Core Equity",
                    style: TextStyle(fontSize: 14)),
                trailing: Text(
                    formatCurrency.format(portfolios[index].lastCoreEquity),
                    style: const TextStyle(fontSize: 16)),
              ),
              ListTile(
                title: const Text("Last Core Portfolio Equity",
                    style: TextStyle(fontSize: 14)),
                trailing: Text(
                    formatCurrency
                        .format(portfolios[index].lastCorePortfolioEquity),
                    style: const TextStyle(fontSize: 16)),
              ),
              ListTile(
                title: const Text("Extended Hours Portfolio Equity",
                    style: TextStyle(fontSize: 14)),
                trailing: Text(
                    portfolios[index].extendedHoursPortfolioEquity != null
                        ? formatCurrency.format(
                            portfolios[index].extendedHoursPortfolioEquity)
                        : "",
                    style: const TextStyle(fontSize: 16)),
              ),
              ListTile(
                title: const Text("Equity Previous Close",
                    style: TextStyle(fontSize: 14)),
                trailing: Text(
                    formatCurrency
                        .format(portfolios[index].equityPreviousClose),
                    style: const TextStyle(fontSize: 16)),
              ),
              ListTile(
                title: const Text("Adjusted Equity Previous Close",
                    style: TextStyle(fontSize: 14)),
                trailing: Text(
                    formatCurrency
                        .format(portfolios[index].adjustedEquityPreviousClose),
                    style: const TextStyle(fontSize: 16)),
              ),
              ListTile(
                title: const Text("Portfolio Equity Previous Close",
                    style: TextStyle(fontSize: 14)),
                trailing: Text(
                    formatCurrency
                        .format(portfolios[index].portfolioEquityPreviousClose),
                    style: const TextStyle(fontSize: 16)),
              ),
              ListTile(
                title: const Text("Adjusted Portfolio Equity Previous Close",
                    style: TextStyle(fontSize: 14)),
                trailing: Text(
                    formatCurrency.format(
                        portfolios[index].adjustedPortfolioEquityPreviousClose),
                    style: const TextStyle(fontSize: 16)),
              ),
              ListTile(
                title:
                    const Text("Market Value", style: TextStyle(fontSize: 14)),
                trailing: Text(
                    formatCurrency.format(portfolios[index].marketValue),
                    style: const TextStyle(fontSize: 16)),
              ),
              ListTile(
                title: const Text("Extended Hours Market Value",
                    style: TextStyle(fontSize: 14)),
                trailing: Text(
                    portfolios[index].extendedHoursMarketValue != null
                        ? formatCurrency
                            .format(portfolios[index].extendedHoursMarketValue)
                        : "",
                    style: const TextStyle(fontSize: 16)),
              ),
              ListTile(
                title: const Text("Last Core Market Value",
                    style: TextStyle(fontSize: 14)),
                trailing: Text(
                    formatCurrency
                        .format(portfolios[index].lastCoreMarketValue),
                    style: const TextStyle(fontSize: 16)),
              ),
              ListTile(
                title: const Text("Excess Maintenance",
                    style: TextStyle(fontSize: 14)),
                trailing: Text(
                    formatCurrency.format(portfolios[index].excessMaintenance),
                    style: const TextStyle(fontSize: 16)),
              ),
              ListTile(
                title: const Text("Excess Maintenance With Uncleared Deposits",
                    style: TextStyle(fontSize: 14)),
                trailing: Text(
                    formatCurrency.format(portfolios[index]
                        .excessMaintenanceWithUnclearedDeposits),
                    style: const TextStyle(fontSize: 16)),
              ),
              ListTile(
                title:
                    const Text("Excess Margin", style: TextStyle(fontSize: 14)),
                trailing: Text(
                    formatCurrency.format(portfolios[index].excessMargin),
                    style: const TextStyle(fontSize: 16)),
              ),
              ListTile(
                title: const Text("Excess Margin With Uncleared Deposits",
                    style: TextStyle(fontSize: 14)),
                trailing: Text(
                    formatCurrency.format(
                        portfolios[index].excessMarginWithUnclearedDeposits),
                    style: const TextStyle(fontSize: 16)),
              ),
              ListTile(
                title: const Text("Start Date", style: TextStyle(fontSize: 14)),
                trailing: Text(formatDate.format(portfolios[index].startDate!),
                    style: const TextStyle(fontSize: 16)),
              ),
              ListTile(
                title: const Text("Unwithdrawable Deposits",
                    style: TextStyle(fontSize: 14)),
                trailing: Text(
                    formatCurrency
                        .format(portfolios[index].unwithdrawableDeposits),
                    style: const TextStyle(fontSize: 16)),
              ),
              ListTile(
                title: const Text("Unwithdrawable Grants",
                    style: TextStyle(fontSize: 14)),
                trailing: Text(
                    formatCurrency
                        .format(portfolios[index].unwithdrawableGrants),
                    style: const TextStyle(fontSize: 16)),
              ),
              ListTile(
                title: const Text("Withdrawable Amount",
                    style: TextStyle(fontSize: 14)),
                trailing: Text(
                    formatCurrency.format(portfolios[index].withdrawableAmount),
                    style: const TextStyle(fontSize: 16)),
              ),
              /*
              ListTile(
                title: const Text("Url", style: TextStyle(fontSize: 14)),
                trailing: Text(portfolios[index].url,
                    style: const TextStyle(fontSize: 14)),
              ),
              */
            ]));
          }
          return null;
          // To convert this infinite list to a list with three items,
          // uncomment the following line:
          // if (index > 3) return null;
        },
        // Or, uncomment the following line:
        // childCount: widgets.length + 10,
      ),
    );
  }

  Widget symbolWidgets(List<Widget> widgets) {
    var n = 3; // 4;
    if (widgets.length < 8) {
      n = 1;
    } else if (widgets.length < 14) {
      n = 2;
    } /* else if (widgets.length < 24) {
      n = 3;
    }*/

    var m = (widgets.length / n).round();
    var lists = List.generate(
        n,
        (i) => widgets.sublist(
            m * i, (i + 1) * m <= widgets.length ? (i + 1) * m : null));
    List<Widget> rows = []; //<Widget>[]
    for (int i = 0; i < lists.length; i++) {
      var list = lists[i];
      rows.add(
        SizedBox(
            height: 56,
            child: ListView.builder(
              //physics: NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              padding: const EdgeInsets.all(4.0),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                return Row(children: list);
              },
              itemCount: 1,
            )),
      );
    }

    return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: rows));
  }

  Widget optionSymbolFilterWidget(
      StateSetter bottomState, OptionPositionStore optionPositionStore) {
    var widgets = optionSymbolFilterWidgets(
            chainSymbols, optionPositionStore.items, bottomState)
        .toList();
    /*
    if (widgets.length < 20) {
      return Padding(
          padding: const EdgeInsets.all(4.0),
          child: Wrap(
            children: widgets,
          ));
    }
    */
    return symbolWidgets(widgets);
  }

  Iterable<Widget> optionSymbolFilterWidgets(List<String> chainSymbols,
      List<OptionAggregatePosition> options, StateSetter bottomState) sync* {
    for (final String chainSymbol in chainSymbols) {
      yield Padding(
        padding: const EdgeInsets.all(4.0),
        child: FilterChip(
          // avatar: CircleAvatar(child: Text(contractCount.toString())),
          label: Text(chainSymbol),
          selected: optionSymbolFilters.contains(chainSymbol),
          onSelected: (bool value) {
            bottomState(() {
              if (value) {
                optionSymbolFilters.add(chainSymbol);
              } else {
                optionSymbolFilters.removeWhere((String name) {
                  return name == chainSymbol;
                });
              }
            });
            setState(() {});
            //Navigator.pop(context);
          },
        ),
      );
    }
  }

  Widget optionTypeFilterWidget(StateSetter bottomState) {
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
                      bottomState(() {
                        if (value) {
                          positionFilters.add("long");
                        } else {
                          positionFilters.removeWhere((String name) {
                            return name == "long";
                          });
                        }
                      });
                      setState(() {});
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
                      bottomState(() {
                        if (value) {
                          positionFilters.add("short");
                        } else {
                          positionFilters.removeWhere((String name) {
                            return name == "short";
                          });
                        }
                      });
                      setState(() {});
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
                      bottomState(() {
                        if (value) {
                          optionFilters.add("call");
                        } else {
                          optionFilters.removeWhere((String name) {
                            return name == "call";
                          });
                        }
                      });
                      setState(() {});
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
                      bottomState(() {
                        if (value) {
                          optionFilters.add("put");
                        } else {
                          optionFilters.removeWhere((String name) {
                            return name == "put";
                          });
                        }
                      });
                      setState(() {});
                    },
                  ),
                )
              ],
            );
          },
          itemCount: 1,
        ));
  }

  Widget positionTypeFilterWidget(StateSetter bottomState) {
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
                    bottomState(() {
                      if (value) {
                        hasQuantityFilters[0] = true;
                      } else {
                        hasQuantityFilters[0] = false;
                      }
                    });
                    setState(() {});
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
                    bottomState(() {
                      if (value) {
                        hasQuantityFilters[1] = true;
                      } else {
                        hasQuantityFilters[1] = false;
                      }
                      // TODO: Refresh stock and option positions;
                      //positionStoreStream = null;
                      //optionPositionStoreStream = null;
                    });
                    setState(() {});
                  },
                ),
              ),
            ]);
          },
          itemCount: 1,
        ));
  }

  Widget stockOrderSymbolFilterWidget(StateSetter bottomState) {
    var widgets =
        symbolFilterWidgets(positionSymbols, stockSymbolFilters, bottomState)
            .toList();
    return symbolWidgets(widgets);
  }

  Widget cryptoFilterWidget(StateSetter bottomState) {
    var widgets =
        symbolFilterWidgets(cryptoSymbols, cryptoFilters, bottomState).toList();
    return symbolWidgets(widgets);
  }

  Iterable<Widget> symbolFilterWidgets(List<String> symbols,
      List<String> selectedSymbols, StateSetter bottomState) sync* {
    for (final String chainSymbol in symbols) {
      yield Padding(
        padding: const EdgeInsets.all(4.0),
        child: FilterChip(
          // avatar: CircleAvatar(child: Text(contractCount.toString())),
          label: Text(chainSymbol),
          selected: selectedSymbols.contains(chainSymbol),
          onSelected: (bool value) {
            bottomState(() {
              if (value) {
                selectedSymbols.add(chainSymbol);
              } else {
                selectedSymbols.removeWhere((String name) {
                  return name == chainSymbol;
                });
              }
            });
            setState(() {});
          },
        ),
      );
    }
  }

  SliverAppBar buildSliverAppBar(
      //List<Portfolio>? portfolios,
      UserInfo? userInfo,
      Account? account,
      PortfolioStore portfolioStore,
      StockPositionStore stockPositionStore,
      OptionPositionStore optionPositionStore,
      ForexHoldingStore forexHoldingStore) {
    positionSymbols = stockPositionStore.symbols;
    positionSymbols.sort((a, b) => (a.compareTo(b)));

    chainSymbols = optionPositionStore.symbols;
    chainSymbols.sort((a, b) => (a.compareTo(b)));

    double portfolioValue = 0.0;
    double stockAndOptionsEquityPercent = 0.0;
    double optionEquityPercent = 0.0;
    double positionEquityPercent = 0.0;
    double portfolioCash = 0.0;
    double cashPercent = 0.0;
    double cryptoPercent = 0.0;
    if (portfolioStore.items.isNotEmpty) {
      portfolioValue =
          (portfolioStore.items[0].equity ?? 0) + forexHoldingStore.equity;
      stockAndOptionsEquityPercent =
          portfolioStore.items[0].marketValue! / portfolioValue;
      optionEquityPercent = optionPositionStore.equity / portfolioValue;
      positionEquityPercent = stockPositionStore.equity / portfolioValue;
      if (account != null) {
        portfolioCash = account.portfolioCash ?? 0;
      }
      cashPercent = portfolioCash / portfolioValue;
      cryptoPercent = forexHoldingStore.equity / portfolioValue;
    }

    double changeInPeriod = 0;
    double changePercentInPeriod = 0;
    if (portfolioStore.items.isNotEmpty) {
      changeInPeriod = portfolioStore.items[0].equity! -
          portfolioStore.items[0].equityPreviousClose!;
      changePercentInPeriod =
          (changeInPeriod) / portfolioStore.items[0].equity!;
    }
    var sliverAppBar = SliverAppBar(
      /* Drawer will automatically add menu to SliverAppBar.
                    leading: IconButton(
                      icon: const Icon(Icons.menu),
                      tooltip: 'Menu',
                      onPressed: () {/* ... */},
                    ),*/
      // backgroundColor: Colors.green,
      // brightness: Brightness.light,
      expandedHeight: 240.0, //280.0,
      //collapsedHeight: 80.0,
      /*
                      bottom: PreferredSize(
                        child: Icon(Icons.linear_scale, size: 60.0),
                        preferredSize: Size.fromHeight(50.0))
                        */
      floating: false,
      pinned: true,
      snap: false,
      //leading: Container(),
      /*IconButton(
        icon: const Icon(Icons.menu),
        tooltip: 'Menu',
        onPressed: () {/* ... */},
      ),*/
      title: Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          //runAlignment: WrapAlignment.end,
          //alignment: WrapAlignment.end,
          spacing: 20,
          //runSpacing: 5,
          children: [
            if (userInfo != null) ...[
              Text(userInfo.profileName,
                  style: const TextStyle(fontSize: 22.0)),
              Wrap(spacing: 10, children: [
                Text(formatCurrency.format(portfolioValue),
                    style:
                        const TextStyle(fontSize: 17.0, color: Colors.white70)),
                //style: const TextStyle(fontSize: 20.0),
                //textAlign: TextAlign.right
                Wrap(alignment: WrapAlignment.center, children: [
                  Icon(
                      changeInPeriod > 0
                          ? Icons.trending_up
                          : (changeInPeriod < 0
                              ? Icons.trending_down
                              : Icons.trending_flat),
                      color: (changeInPeriod > 0
                          ? Colors.green
                          : (changeInPeriod < 0 ? Colors.red : Colors.grey)),
                      size: 20.0),
                  Text(formatPercentage.format(changePercentInPeriod.abs()),
                      style: const TextStyle(
                          fontSize: 17.0, color: Colors.white70)),
                ]),
                Text(
                    "${changeInPeriod > 0 ? "+" : changeInPeriod < 0 ? "-" : ""}${formatCurrency.format(changeInPeriod.abs())}",
                    style:
                        const TextStyle(fontSize: 17.0, color: Colors.white70)),
              ]),
            ]
          ]),
      flexibleSpace: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
        //var top = constraints.biggest.height;
        //debugPrint(top.toString());
        //debugPrint(kToolbarHeight.toString());

        /*
        List<PieChartData> data = [];
        if (portfolioStore.items.isNotEmpty) {
          data.add(PieChartData(
              'Options\n\$${formatCompactNumber.format(optionPositionStore.equity)}',
              optionPositionStore.equity)); // / portfolioValue
          data.add(PieChartData(
              'Stocks\n\$${formatCompactNumber.format(stockPositionStore.equity)}',
              stockPositionStore.equity)); // / portfolioValue
          data.add(PieChartData(
              'Crypto\n\$${formatCompactNumber.format(forexHoldingStore.equity)}',
              forexHoldingStore.equity)); // / portfolioValue
          double portfolioCash = account != null ? account.portfolioCash! : 0;
          data.add(PieChartData(
              'Cash\n\$${formatCompactNumber.format(portfolioCash)}',
              portfolioCash)); // / portfolioValue
        }
        data.sort((a, b) => b.value.compareTo(a.value));
        */

        final settings = context
            .dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
        final deltaExtent = settings!.maxExtent - settings.minExtent;
        final t =
            (1.0 - (settings.currentExtent - settings.minExtent) / deltaExtent)
                .clamp(0.0, 1.0);
        final fadeStart = math.max(0.0, 1.0 - kToolbarHeight / deltaExtent);
        const fadeEnd = 1.0;
        final opacity = 1.0 - Interval(fadeStart, fadeEnd).transform(t);
        return FlexibleSpaceBar(
            /*
            titlePadding:
                const EdgeInsets.only(top: kToolbarHeight * 2, bottom: 15),
                */
            //centerTitle: true,
            //titlePadding: EdgeInsets.symmetric(horizontal: 5),
            //titlePadding: EdgeInsets.all(5),
            //background: const FlutterLogo(),
            /*
            background: const SizedBox(
              width: double.infinity,
              child:
                  FlutterLogo()
              //Image.network(
              //  Constants.flexibleSpaceBarBackground,
              //  fit: BoxFit.cover,
              //)
              ,
            ),
            */
            /*
            background: SizedBox(
                height: 180,
                width: 180,
                child: Padding(
                  //padding: EdgeInsets.symmetric(horizontal: 12.0),
                  //padding: const EdgeInsets.all(10.0),
                  padding: const EdgeInsets.fromLTRB(10, 100, 10, 10),
                  child: PieChart(
                    [
                      charts.Series<PieChartData, String>(
                        id: 'Portfolio Breakdown',
                        //colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
                        domainFn: (PieChartData val, index) => val.label,
                        measureFn: (PieChartData val, index) => val.value,
                        data: data,
                      ),
                    ],
                    renderer: new charts.ArcRendererConfig(
                        arcWidth: 60,
                        arcRendererDecorators: [
                          new charts.ArcLabelDecorator()
                        ]),
                    onSelected: (_) {},
                  ),
                )),
                */
            title: Opacity(
                //duration: Duration(milliseconds: 300),
                opacity: opacity, //top > kToolbarHeight * 3 ? 1.0 : 0.0,
                child: _buildExpandedSliverAppBarTitle(
                    userInfo,
                    portfolioValue,
                    stockAndOptionsEquityPercent,
                    portfolioStore.items,
                    optionEquityPercent,
                    portfolioStore,
                    optionPositionStore,
                    stockPositionStore,
                    forexHoldingStore,
                    positionEquityPercent,
                    cryptoPercent,
                    cashPercent,
                    portfolioCash)));
      }),
      actions: <Widget>[
        IconButton(
          icon: const Icon(Icons.more_vert),
          // icon: const Icon(Icons.settings),
          onPressed: () {
            showModalBottomSheet<void>(
                context: context,
                //isScrollControlled: true,
                //useRootNavigator: true,
                //constraints: const BoxConstraints(maxHeight: 200),
                builder: (_) => MoreMenuBottomSheet(widget.user,
                    chainSymbols: chainSymbols,
                    positionSymbols: positionSymbols,
                    cryptoSymbols: cryptoSymbols,
                    optionSymbolFilters: optionSymbolFilters,
                    stockSymbolFilters: stockSymbolFilters,
                    cryptoFilters: cryptoFilters,
                    onSettingsChanged: _onSettingsChanged));
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

  SingleChildScrollView _buildExpandedSliverAppBarTitle(
      UserInfo? user,
      double portfolioValue,
      double stockAndOptionsEquityPercent,
      List<Portfolio> portfolios,
      double optionEquityPercent,
      PortfolioStore portfolioStore,
      OptionPositionStore optionPositionStore,
      StockPositionStore stockPositionStore,
      ForexHoldingStore forexHoldingStore,
      double positionEquityPercent,
      double cryptoPercent,
      double cashPercent,
      double portfolioCash) {
    /*
    List<PieChartData> data = [];
    if (portfolioStore.items.isNotEmpty) {
      data.add(PieChartData(
          'Options\n\$${formatCompactNumber.format(optionPositionStore.equity)}',
          optionPositionStore.equity)); // / portfolioValue
      data.add(PieChartData(
          'Stocks\n\$${formatCompactNumber.format(stockPositionStore.equity)}',
          stockPositionStore.equity)); // / portfolioValue
      data.add(PieChartData(
          'Crypto\n\$${formatCompactNumber.format(forexHoldingStore.equity)}',
          forexHoldingStore.equity)); // / portfolioValue
      double portfolioCash = account != null ? account!.portfolioCash! : 0;
      data.add(PieChartData(
          'Cash\n\$${formatCompactNumber.format(portfolioCash)}',
          portfolioCash)); // / portfolioValue
    }
    data.sort((a, b) => b.value.compareTo(a.value));
    */
    return SingleChildScrollView(
      child: Column(
          //mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            /*
            Row(
              children: [
                SizedBox(
                    height: 180,
                    width: 180,
                    child: Padding(
                      //padding: EdgeInsets.symmetric(horizontal: 12.0),
                      padding: const EdgeInsets.all(10.0),
                      child: PieChart(
                        [
                          charts.Series<PieChartData, String>(
                            id: 'Portfolio Breakdown',
                            //colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
                            domainFn: (PieChartData val, index) => val.label,
                            measureFn: (PieChartData val, index) => val.value,
                            data: data,
                          ),
                        ],
                        renderer: new charts.ArcRendererConfig(
                            arcWidth: 60,
                            arcRendererDecorators: [
                              new charts.ArcLabelDecorator()
                            ]),
                        onSelected: (_) {},
                      ),
                    )),
              ],
            ),
            */
            /*Row(children: const [SizedBox(height: 68)]),*/
            /*
            Wrap(
                crossAxisAlignment: WrapCrossAlignment.end,
                //runAlignment: WrapAlignment.end,
                //alignment: WrapAlignment.end,
                spacing: 10,
                //runSpacing: 5,
                children: [
                  Text(
                    user!.profileName,
                    //style: const TextStyle(fontSize: 20.0)
                  ),
                  Text(
                    formatCurrency.format(portfolioValue),
                    //style: const TextStyle(fontSize: 20.0),
                    //textAlign: TextAlign.right
                  ),
                ]),
                */
            /*
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Container(
                  width: 10,
                ),
                Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: const [
                      SizedBox(
                        width: 80,
                        child: Text(
                          "Portfolio Value",
                          style: TextStyle(fontSize: 10.0),
                        ),
                      )
                    ]),
                Container(
                  width: 3,
                ),
                Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: const [
                      SizedBox(
                          width: 39,
                          child: Text("", //${formatPercentage.format(1)}
                              style: TextStyle(fontSize: 10.0),
                              textAlign: TextAlign.right))
                    ]),
                Container(
                  width: 5,
                ),
                SizedBox(
                    width: 65,
                    child: Text(formatCurrency.format(portfolioValue),
                        style: const TextStyle(fontSize: 12.0),
                        textAlign: TextAlign.right)),
                Container(
                  width: 10,
                ),
              ],
            ),
            */
            /*
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Container(
                  width: 10,
                ),
                Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: const [
                      SizedBox(
                        width: 80,
                        child: Text(
                          "Stocks & Options",
                          style: TextStyle(fontSize: 10.0),
                        ),
                      )
                    ]),
                Container(
                  width: 3,
                ),
                Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  SizedBox(
                      width: 40,
                      child: Text(
                          formatPercentage.format(stockAndOptionsEquityPercent),
                          style: const TextStyle(fontSize: 11.0),
                          textAlign: TextAlign.right))
                ]),
                Container(
                  width: 5,
                ),
                SizedBox(
                    width: 75,
                    child: Text(
                        formatCurrency.format(portfolios[0].marketValue),
                        style: const TextStyle(fontSize: 13.0),
                        textAlign: TextAlign.right)),
                Container(
                  width: 10,
                ),
              ],
            ),
            */
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Container(
                  width: 10,
                ),
                Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: const [
                      SizedBox(
                        width: 80,
                        child: Text(
                          "Options",
                          style: TextStyle(fontSize: 11.0),
                        ),
                      )
                    ]),
                Container(
                  width: 3,
                ),
                Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  SizedBox(
                      width: 40,
                      child: Text(formatPercentage.format(optionEquityPercent),
                          style: const TextStyle(fontSize: 12.0),
                          textAlign: TextAlign.right))
                ]),
                Container(
                  width: 5,
                ),
                SizedBox(
                    width: 75,
                    child: Text(
                        formatCurrency.format(optionPositionStore.equity),
                        style: const TextStyle(fontSize: 13.0),
                        textAlign: TextAlign.right)),
                Container(
                  width: 10,
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Container(
                  width: 10,
                ),
                Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: const [
                      SizedBox(
                        width: 80,
                        child: Text(
                          "Stocks",
                          style: TextStyle(fontSize: 11.0),
                        ),
                      )
                    ]),
                Container(
                  width: 3,
                ),
                Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  SizedBox(
                      width: 40,
                      child: Text(
                          formatPercentage.format(positionEquityPercent),
                          style: const TextStyle(fontSize: 12.0),
                          textAlign: TextAlign.right))
                ]),
                Container(
                  width: 5,
                ),
                SizedBox(
                    width: 75,
                    child: Text(
                        formatCurrency.format(stockPositionStore.equity),
                        style: const TextStyle(fontSize: 13.0),
                        textAlign: TextAlign.right)),
                Container(
                  width: 10,
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Container(
                  width: 10,
                ),
                Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: const [
                      SizedBox(
                          width: 80,
                          child: Text(
                            "Crypto",
                            style: TextStyle(fontSize: 11.0),
                          )),
                    ]),
                Container(
                  width: 3,
                ),
                Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  SizedBox(
                      width: 40,
                      child: Text(formatPercentage.format(cryptoPercent),
                          style: const TextStyle(fontSize: 12.0),
                          textAlign: TextAlign.right))
                ]),
                Container(
                  width: 5,
                ),
                SizedBox(
                    width: 75,
                    child: Text(formatCurrency.format(forexHoldingStore.equity),
                        style: const TextStyle(fontSize: 13.0),
                        textAlign: TextAlign.right)),
                Container(
                  width: 10,
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Container(
                  width: 10,
                ),
                Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: const [
                      SizedBox(
                          width: 80,
                          child: Text(
                            "Cash",
                            style: TextStyle(fontSize: 11.0),
                          )),
                    ]),
                Container(
                  width: 3,
                ),
                Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  SizedBox(
                      width: 40,
                      child: Text(formatPercentage.format(cashPercent),
                          style: const TextStyle(fontSize: 12.0),
                          textAlign: TextAlign.right))
                ]),
                Container(
                  width: 5,
                ),
                SizedBox(
                    width: 75,
                    child: Text(formatCurrency.format(portfolioCash),
                        style: const TextStyle(fontSize: 13.0),
                        textAlign: TextAlign.right)),
                Container(
                  width: 10,
                ),
              ],
            ),
          ]),
    );
  }

  Future<void> _pullRefresh() async {
    /*
    setState(() {
      futurePortfolios = null;

      positionStoreStream = null;
      optionPositionStoreStream = null;
    });
    */
    /*
    var accounts = await RobinhoodService.getAccounts(
        widget.user, Provider.of<AccountStore>(context, listen: false));
    var portfolios = await RobinhoodService.getPortfolios(
        widget.user, Provider.of<PortfolioStore>(context, listen: false));
    */

    setState(() {
      Provider.of<AccountStore>(context, listen: false).removeAll();
      futureAccounts = null;
      Provider.of<PortfolioStore>(context, listen: false).removeAll();
      futurePortfolios = null;
      Provider.of<ForexHoldingStore>(context, listen: false).removeAll();
      futureNummusHoldings = null;
      Provider.of<OptionPositionStore>(context, listen: false).removeAll();
      futureOptionPositions = null;
      Provider.of<StockPositionStore>(context, listen: false).removeAll();
      futureStockPositions = null;
      /*
      futureAccounts = Future.value(accounts);
      futurePortfolios = Future.value(portfolios);
      */
    });
    /*
    futureAccounts ??= RobinhoodService.getAccounts(
        widget.user, Provider.of<AccountStore>(context, listen: false));

    futurePortfolios ??= RobinhoodService.getPortfolios(
        widget.user, Provider.of<PortfolioStore>(context, listen: false));
    //futureNummusAccounts ??= RobinhoodService.downloadNummusAccounts(widget.user);
    futureNummusHoldings ??= RobinhoodService.getNummusHoldings(
        widget.user, Provider.of<ForexHoldingStore>(context, listen: false),
        nonzero: !hasQuantityFilters[1]);

    futureOptionPositions ??= RobinhoodService.getOptionPositionStore(
        widget.user,
        Provider.of<OptionPositionStore>(context, listen: false),
        Provider.of<InstrumentStore>(context, listen: false),
        nonzero: !hasQuantityFilters[1]);

    futureStockPositions ??= RobinhoodService.getStockPositionStore(
        widget.user,
        Provider.of<StockPositionStore>(context, listen: false),
        Provider.of<InstrumentStore>(context, listen: false),
        Provider.of<QuoteStore>(context, listen: false),
        nonzero: !hasQuantityFilters[1]);
    */

    /*
    await RobinhoodService.getPortfolioHistoricals(
        widget.user,
        Provider.of<PortfolioHistoricalsStore>(context, listen: false),
        account!.accountNumber,
        chartBoundsFilter,
        chartDateSpanFilter);

    await RobinhoodService.refreshOptionMarketData(
        widget.user, Provider.of<OptionPositionStore>(context, listen: false));

    await RobinhoodService.refreshPositionQuote(
        widget.user,
        Provider.of<StockPositionStore>(context, listen: false),
        Provider.of<QuoteStore>(context, listen: false));

    await RobinhoodService.getPortfolios(
        widget.user, Provider.of<PortfolioStore>(context, listen: false));

    await RobinhoodService.refreshNummusHoldings(
      widget.user,
      Provider.of<ForexHoldingStore>(context, listen: false),
    );
    */
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

  Widget _buildPositionRow(List<StockPosition> positions, int index) {
    var instrument = positions[index].instrumentObj;

    double value = widget.user.getPositionDisplayValue(positions[index]);
    String trailingText = widget.user.getDisplayText(value);
    Icon? icon = (widget.user.displayValue == DisplayValue.lastPrice ||
            widget.user.displayValue == DisplayValue.marketValue)
        ? null
        : widget.user.getDisplayIcon(value);

    return Card(
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      ListTile(
        /*
        leading: CircleAvatar(
            child: Text(formatCompactNumber.format(positions[index].quantity!),
                style: const TextStyle(fontSize: 17))),
                */
        leading: instrument != null
            ? Hero(
                tag: 'logo_${instrument.symbol}${instrument.id}',
                child: instrument.logoUrl != null
                    ? CircleAvatar(
                        radius: 25,
                        foregroundColor: Theme.of(context)
                            .colorScheme
                            .primary, //.onBackground,
                        //backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        child: Image.network(
                          instrument.logoUrl!,
                          width: 40,
                          height: 40,
                          errorBuilder: (BuildContext context, Object exception,
                              StackTrace? stackTrace) {
                            //RobinhoodService.removeLogo(instrument.symbol);
                            return Text(instrument.symbol);
                          },
                        ))
                    : CircleAvatar(
                        radius: 25,
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        child: Text(
                          instrument.symbol,
                        )))
            : null,
        title: Text(
            instrument != null ? instrument.simpleName ?? instrument.name : ""),
        subtitle: Text("${positions[index].quantity} shares"),
        //'Average cost ${formatCurrency.format(positions[index].averageBuyPrice)}'),
        /*
        subtitle: Text(
            '${positions[index].quantity} shares\navg cost ${formatCurrency.format(positions[index].averageBuyPrice)}'),
            */
        trailing: Wrap(spacing: 8, children: [
          if (icon != null) ...[
            icon,
          ],
          Text(
            trailingText,
            style: const TextStyle(fontSize: 21.0),
            textAlign: TextAlign.right,
          )
        ]),
        // isThreeLine: true,
        onTap: () {
          /* For navigation within this tab, uncomment
          widget.navigatorKey!.currentState!.push(MaterialPageRoute(
              builder: (context) => InstrumentWidget(ru, accounts!.first,
                  positions[index].instrumentObj as Instrument,
                  position: positions[index])));
                  */
          var futureFromInstrument = Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => InstrumentWidget(
                      widget.user,
                      //account!,
                      instrument!,
                      heroTag: 'logo_${instrument.symbol}${instrument.id}')));
          // Refresh in case settings were updated.
          futureFromInstrument.then((value) => setState(() {}));
        },
      )
    ]));
  }

  Widget _buildCryptoRow(List<ForexHolding> holdings, int index) {
    double value = widget.user.getCryptoDisplayValue(holdings[index]);
    String trailingText = widget.user.getDisplayText(value);
    Icon? icon = (widget.user.displayValue == DisplayValue.lastPrice ||
            widget.user.displayValue == DisplayValue.marketValue)
        ? null
        : widget.user.getDisplayIcon(value);

    return Card(
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      ListTile(
        leading: Hero(
            tag: 'logo_crypto_${holdings[index].currencyCode}',
            child: CircleAvatar(
                radius: 25,
                foregroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  holdings[index].currencyCode,
                ))),

        /*
        leading: CircleAvatar(
            child: Icon(
                holdings[index].gainLossPerShare > 0
                    ? Icons.trending_up
                    : (holdings[index].gainLossPerShare < 0
                        ? Icons.trending_down
                        : Icons.trending_flat),
                color: (holdings[index].gainLossPerShare > 0
                    ? Colors.green
                    : (holdings[index].gainLossPerShare < 0
                        ? Colors.red
                        : Colors.grey)),
                size: 36.0)),
                */
        title: Text(holdings[index].currencyName),
        subtitle: Text("${holdings[index].quantity} shares"),
        //'Average cost ${formatCurrency.format(positions[index].averageBuyPrice)}'),
        /*
        subtitle: Text(
            '${positions[index].quantity} shares\navg cost ${formatCurrency.format(positions[index].averageBuyPrice)}'),
            */
        trailing: Wrap(spacing: 8, children: [
          if (icon != null) ...[
            icon,
          ],
          //if (trailingText != null) ...[
          Text(
            trailingText,
            style: const TextStyle(fontSize: 21.0),
            textAlign: TextAlign.right,
          )
          //]
        ]),
        // isThreeLine: true,
        onTap: () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => ForexInstrumentWidget(
                      widget.user,
                      //account!,
                      holdings[index])));
          /*
          showDialog<String>(
              context: context,
              builder: (BuildContext context) => AlertDialog(
                    title: const Text('Alert'),
                    content: const Text('This feature is not implemented.'),
                    actions: <Widget>[
                      /*
                    TextButton(
                      onPressed: () => Navigator.pop(context, 'Cancel'),
                      child: const Text('Cancel'),
                    ),
                    */
                      TextButton(
                        onPressed: () => Navigator.pop(context, 'OK'),
                        child: const Text('OK'),
                      ),
                    ],
                  ));
                  */
        },
      )
    ]));
  }

  /*
  _buildLogin() {
    return Column(
      children: [
        Container(height: 150),
        const Align(
            alignment: Alignment.center,
            child: Text("Not logged in.", style: TextStyle(fontSize: 20.0))),
        // Align(alignment: Alignment.center, child: new Text("Login above.")),
        Container(height: 150),
      ],
    );
  }

  _openLogin() async {
    final RobinhoodUser? result = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (BuildContext context) => const LoginWidget()));

    if (result != null) {
      await RobinhoodUser.writeUserToStore(result);

      widget.onUserChanged(result);

      setState(() {
        futureRobinhoodUser = null;
        //user = null;
      });

      Navigator.pop(context); //, 'login'

      // After the Selection Screen returns a result, hide any previous snackbars
      // and show the new result.
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text("Logged in ${result.userName}")));
    }
  }

  _logout() async {
    await RobinhoodUser.clearUserFromStore();
    // Future.delayed(const Duration(milliseconds: 1), () async {

    widget.onUserChanged(null);

    setState(() {
      futureRobinhoodUser = null;
      // _selectedDrawerIndex = 0;
    });
    //});
  }
  */

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
