import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'dart:math' as math;

import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/equity_historical.dart';
import 'package:robinhood_options_mobile/model/forex_holding.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_order.dart';
import 'package:robinhood_options_mobile/model/portfolio.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';
import 'package:robinhood_options_mobile/model/stock_position.dart';
import 'package:robinhood_options_mobile/model/stock_order.dart';
import 'package:robinhood_options_mobile/model/robinhood_user.dart';
import 'package:robinhood_options_mobile/model/stock_position_store.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/model/user_store.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
import 'package:robinhood_options_mobile/widgets/chart_bar_widget.dart';
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
      required this.onUserChanged,
      required this.onAccountsChanged})
      : super(key: key);

  final GlobalKey<NavigatorState>? navigatorKey;
  final ValueChanged<RobinhoodUser?> onUserChanged;
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
    with AutomaticKeepAliveClientMixin<HomePage> {
  Future<List<Account>>? futureAccounts;
  List<Account>? accounts;
  Account? account;

  Future<List<ForexHolding>>? futureNummusHoldings;
  List<ForexHolding>? nummusHoldings;

  Future<List<Portfolio>>? futurePortfolios;

  Future<PortfolioHistoricals>? futurePortfolioHistoricals;
  PortfolioHistoricals? portfolioHistoricals;

  //charts.TimeSeriesChart? chart;
  List<charts.Series<dynamic, DateTime>>? seriesList;
  TimeSeriesChart? chart;
  ChartDateSpan chartDateSpanFilter = ChartDateSpan.day;
  Bounds chartBoundsFilter = Bounds.t24_7;
  EquityHistorical? selection;

  Stream<List<StockPosition>>? positionStream;
  List<StockPosition> positions = [];
  Stream<List<StockOrder>>? positionOrderStream;

  Stream<List<OptionAggregatePosition>>? optionPositionStream;
  Stream<List<OptionOrder>>? optionOrderStream;

  List<OptionAggregatePosition> optionPositions = [];

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
  OptionPositionStore? optionPositionStore;
  StockPositionStore? stockPositionStore;
  QuoteStore? quoteStore;

  @override
  bool get wantKeepAlive => true;

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
    super.build(context);
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
    futureAccounts ??= RobinhoodService.getAccounts(widget.user);
    futurePortfolios ??= RobinhoodService.getPortfolios(widget.user);
    //futureNummusAccounts ??= RobinhoodService.downloadNummusAccounts(widget.user);
    futureNummusHoldings ??= RobinhoodService.getNummusHoldings(widget.user,
        nonzero: !hasQuantityFilters[1]);

    // This gets the current state of CartModel and also tells Flutter
    // to rebuild this widget when CartModel notifies listeners (in other words,
    // when it changes).
    optionPositionStore = context.watch<OptionPositionStore>();
    //optionPositionStore = Provider.of<OptionPositionStore>(context, listen: true);

    stockPositionStore = context.watch<StockPositionStore>();
    var instrumentStore = context.watch<InstrumentStore>();
    quoteStore = context.watch<QuoteStore>();
    context.watch<UserStore>();

    return FutureBuilder(
      future: Future.wait([
        futureAccounts as Future,
        futurePortfolios as Future,
        futureNummusHoldings as Future,
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

          /*
          var _accounts = data.isNotEmpty ? data[0] as List<Account> : null;
          // Special logic to refresh the parent widget when a new account is downloaded.
          if (accounts == null || accounts!.length != _accounts!.length) {
            accounts = _accounts;
            WidgetsBinding.instance!.addPostFrameCallback(
                (_) => widget.onAccountsChanged(accounts!));
          }
          */

          var portfolios = data.length > 1 ? data[1] as List<Portfolio> : null;
          nummusHoldings =
              data.length > 2 ? data[2] as List<ForexHolding> : null;

          futurePortfolioHistoricals ??=
              RobinhoodService.getPortfolioHistoricals(
                  widget.user,
                  account!.accountNumber,
                  chartBoundsFilter,
                  chartDateSpanFilter);

          return FutureBuilder<PortfolioHistoricals>(
              future: futurePortfolioHistoricals,
              builder: (context11, historicalsSnapshot) {
                if (historicalsSnapshot.hasData) {
                  if (portfolioHistoricals == null ||
                      historicalsSnapshot.data!.bounds !=
                          portfolioHistoricals!.bounds ||
                      historicalsSnapshot.data!.span !=
                          portfolioHistoricals!.span) {
                    chart = null;
                    //selection = historicalsSnapshot
                    //    .data!.equityHistoricals.last;
                    var portfolioHistoricals =
                        historicalsSnapshot.data as PortfolioHistoricals;
                    if (portfolioHistoricals.span == "day") {
                      final DateTime now = DateTime.now();
                      final DateTime today =
                          DateTime(now.year, now.month, now.day);

                      portfolioHistoricals.equityHistoricals =
                          portfolioHistoricals.equityHistoricals
                              .where((element) =>
                                  element.beginsAt!.compareTo(today) >= 0)
                              .toList();
                    }
                    this.portfolioHistoricals = portfolioHistoricals;
                  }
                  /*
                  Stream<StockPositionStore> positionStoreStream =
                      RobinhoodService.streamStockPositionStore(widget.user,
                          StockPositionStore(), instrumentStore, quoteStore!,
                          nonzero: !hasQuantityFilters[1]);
                  Stream<OptionPositionStore> optionPositionStoreStream =
                      RobinhoodService.streamOptionPositionStore(
                          widget.user, OptionPositionStore(), instrumentStore,
                          nonzero: !hasQuantityFilters[1]);
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
                        return _buildPage(
                            portfolios: portfolios,
                            userInfo: widget.userInfo,
                            account: account,
                            nummusHoldings: nummusHoldings,
                            portfolioHistoricals: portfolioHistoricals,
                            //optionPositions: optionPositions,
                            //positions: positions,
                            done: true);
                      });
                      */
                  positionStream ??= RobinhoodService.streamPositions(
                      widget.user,
                      stockPositionStore!,
                      instrumentStore,
                      quoteStore!,
                      nonzero: !hasQuantityFilters[1]);

                  return StreamBuilder(
                      stream: positionStream,
                      builder: (context2, positionSnapshot) {
                        if (positionSnapshot.hasData) {
                          positions =
                              positionSnapshot.data as List<StockPosition>;

                          optionPositionStream ??= RobinhoodService
                              .streamOptionAggregatePositionList(widget.user,
                                  optionPositionStore!, instrumentStore,
                                  nonzero: !hasQuantityFilters[1]);

                          return StreamBuilder<List<OptionAggregatePosition>>(
                              stream: optionPositionStream,
                              builder: (BuildContext context3,
                                  AsyncSnapshot<List<OptionAggregatePosition>>
                                      optionAggregatePositionSnapshot) {
                                if (optionAggregatePositionSnapshot.hasData) {
                                  optionPositions =
                                      optionAggregatePositionSnapshot.data!;

                                  return _buildPage(
                                      portfolios: portfolios,
                                      userInfo: widget.userInfo,
                                      account: account,
                                      nummusHoldings: nummusHoldings,
                                      portfolioHistoricals:
                                          portfolioHistoricals,
                                      optionPositions: optionPositions,
                                      positions: positions,
                                      done: positionSnapshot.connectionState ==
                                              ConnectionState.done &&
                                          optionAggregatePositionSnapshot
                                                  .connectionState ==
                                              ConnectionState.done);
                                } else {
                                  // No Options found.
                                  return _buildPage(
                                    portfolios: portfolios,
                                    userInfo: widget.userInfo,
                                    account: account,
                                    nummusHoldings: nummusHoldings,
                                    portfolioHistoricals: portfolioHistoricals,
                                    positions: positions,
                                  );
                                }
                              });
                        } else {
                          // No Positions found.
                          return _buildPage(
                            portfolios: portfolios,
                            userInfo: widget.userInfo,
                            account: account,
                            nummusHoldings: nummusHoldings,
                            portfolioHistoricals: portfolioHistoricals,
                          );
                        }
                      });
                } else {
                  // No PortfolioHistoricals found
                  return _buildPage(
                      portfolios: portfolios,
                      userInfo: widget.userInfo,
                      account: account,
                      nummusHoldings: nummusHoldings);
                }
              });
        } else if (dataSnapshot.hasError) {
          debugPrint("${dataSnapshot.error}");
          if (dataSnapshot.error.toString() ==
              "OAuth authorization error (invalid_grant).") {
            RobinhoodUser.clearUserFromStore();
            // Causes: 'package:flutter/src/widgets/navigator.dart': Failed assertion: line 4841 pos 12: '!_debugLocked': is not true.
            //_openLogin();
          }
          return _buildPage(
              //ru: snapshotUser,
              welcomeWidget: Text("${dataSnapshot.error}"));
        } else {
          return _buildPage();
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
          if (portfolioHistoricals != null) {
            setState(() {
              portfolioHistoricals = null;
              futurePortfolioHistoricals = null;
            });
          }

          //var optionPositionStore = Provider.of<OptionPositionStore>(context, listen: false);
          var refreshedOptionPositions =
              await RobinhoodService.refreshOptionMarketData(
                  widget.user, optionPositionStore!, optionPositions);
          setState(() {
            optionPositions = refreshedOptionPositions;
          });
          //var stockPositionStore = Provider.of<StockPositionStore>(context, listen: false);
          var refreshPositions = await RobinhoodService.refreshPositionQuote(
              widget.user, stockPositionStore!, quoteStore!, positions);
          setState(() {
            positions = refreshPositions;
          });

          var refreshForex = await RobinhoodService.refreshNummusHoldings(
              widget.user, nummusHoldings!);
          setState(() {
            nummusHoldings = refreshForex;
          });
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
  }

  void resetChart(ChartDateSpan span, Bounds bounds) {
    setState(() {
      chartDateSpanFilter = span;
      chartBoundsFilter = bounds;
      futurePortfolioHistoricals = null;
    });
    //portfolioHistoricals = null;
    /* RobinhoodService.getPortfolioHistoricals(
        widget.user,
        accounts![0].accountNumber,
        chartBoundsFilter,
        chartDateSpanFilter);*/
  }

  Widget _buildPage(
      {List<Portfolio>? portfolios,
      UserInfo? userInfo,
      Account? account,
      List<ForexHolding>? nummusHoldings,
      Widget? welcomeWidget,
      PortfolioHistoricals? portfolioHistoricals,
      List<OptionAggregatePosition>? optionPositions,
      List<StockPosition>? positions,
      bool done = false}) {
    /*
    var stockPositionStore =
        Provider.of<StockPositionStore>(context); //, listen: true
    var optionPositionStore =
        Provider.of<OptionPositionStore>(context); //, listen: true
    List<OptionAggregatePosition>? optionPositions = optionPositionStore.items;
    List<StockPosition>? positions = stockPositionStore.items;
    */
    double portfolioValue = 0.0;
    double stockAndOptionsEquityPercent = 0.0;
    double optionEquityPercent = 0.0;
    double positionEquityPercent = 0.0;
    double portfolioCash = 0.0;
    double cashPercent = 0.0;
    double cryptoPercent = 0.0;

    EquityHistorical? firstHistorical;
    EquityHistorical? lastHistorical;
    double open = 0;
    double close = 0;
    double changeInPeriod = 0;
    double changePercentInPeriod = 0;

    double optionEquity = 0;
    double positionEquity = 0;
    double nummusEquity = 0;

    if (positions != null) {
      if (positions.isNotEmpty) {
        positionEquity =
            positions.map((e) => e.marketValue).reduce((a, b) => a + b);
      }
      positionSymbols = positions
          .where((element) => element.instrumentObj != null)
          .map((e) => e.instrumentObj!.symbol)
          .toSet()
          .toList();
      positionSymbols.sort((a, b) => (a.compareTo(b)));
    }

    if (nummusHoldings != null && nummusHoldings.isNotEmpty) {
      nummusEquity =
          nummusHoldings.map((e) => e.marketValue).reduce((a, b) => a + b);
    }

    if (optionPositions != null) {
      if (optionPositions.isNotEmpty) {
        optionEquity = optionPositions
            .map((e) => e.legs.first.positionType == "long"
                ? e.marketValue
                : e.marketValue)
            .reduce((a, b) => a + b);
      }
      chainSymbols = optionPositions.map((e) => e.symbol).toSet().toList();
      chainSymbols.sort((a, b) => (a.compareTo(b)));
    }

    if (portfolios != null) {
      portfolioValue = (portfolios[0].equity ?? 0) + nummusEquity;
      stockAndOptionsEquityPercent =
          portfolios[0].marketValue! / portfolioValue;
      optionEquityPercent = optionEquity / portfolioValue;
      positionEquityPercent = positionEquity / portfolioValue;
      portfolioCash = account!.portfolioCash ?? 0;
      cashPercent = portfolioCash / portfolioValue;
      cryptoPercent = nummusEquity / portfolioValue;
      changeInPeriod =
          portfolios[0].equity! - portfolios[0].equityPreviousClose!;
      changePercentInPeriod = changeInPeriod / portfolios[0].equity!;
    }
    if (portfolioHistoricals != null) {
      firstHistorical = portfolioHistoricals.equityHistoricals[0];
      lastHistorical = portfolioHistoricals
          .equityHistoricals[portfolioHistoricals.equityHistoricals.length - 1];
      // TODO - Figure out what properties to use // portfolioHistoricals.adjustedOpenEquity
      open = firstHistorical.adjustedOpenEquity!;
      close = lastHistorical.adjustedCloseEquity!;
      changeInPeriod = close - open;
      changePercentInPeriod = changeInPeriod / close;

      if (selection != null) {
        changeInPeriod = selection!.adjustedCloseEquity! -
            open; // portfolios![0].equityPreviousClose!;
        changePercentInPeriod =
            changeInPeriod / selection!.adjustedCloseEquity!;
      }

      // Override the portfolio API with current historical data.
      portfolioValue = close;

      if (chart == null) {
        List<charts.Series<dynamic, DateTime>> seriesList = [
          charts.Series<EquityHistorical, DateTime>(
              id: 'Adjusted Equity',
              colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
              domainFn: (EquityHistorical history, _) => history.beginsAt!,
              //filteredEquityHistoricals.indexOf(history),
              measureFn: (EquityHistorical history, index) => index == 0
                  ? history.adjustedOpenEquity
                  : history.adjustedCloseEquity,
              data: portfolioHistoricals
                  .equityHistoricals //filteredEquityHistoricals,
              ),
          charts.Series<EquityHistorical, DateTime>(
              id: 'Equity',
              colorFn: (_, __) => charts.MaterialPalette.green.shadeDefault,
              domainFn: (EquityHistorical history, _) => history.beginsAt!,
              //filteredEquityHistoricals.indexOf(history),
              measureFn: (EquityHistorical history, index) =>
                  index == 0 ? history.openEquity : history.closeEquity,
              data: portfolioHistoricals
                  .equityHistoricals //filteredEquityHistoricals,
              ),
          charts.Series<EquityHistorical, DateTime>(
              id: 'Market Value',
              colorFn: (_, __) => charts.MaterialPalette.red.shadeDefault,
              domainFn: (EquityHistorical history, _) => history.beginsAt!,
              //filteredEquityHistoricals.indexOf(history),
              measureFn: (EquityHistorical history, index) => index == 0
                  ? history.openMarketValue
                  : history.closeMarketValue,
              data: portfolioHistoricals
                  .equityHistoricals //filteredEquityHistoricals,
              ),
        ];
        chart = TimeSeriesChart(seriesList,
            open: open,
            close: close,
            hiddenSeries: const ['Equity', 'Market Value'],
            onSelected: _onChartSelection);
      }
    }

    SliverAppBar sliverAppBar = buildSliverAppBar(
        portfolios,
        widget.userInfo,
        account,
        portfolioValue,
        stockAndOptionsEquityPercent,
        positionEquity,
        positionEquityPercent,
        nummusEquity,
        cryptoPercent,
        optionEquity,
        optionEquityPercent,
        portfolioCash,
        cashPercent,
        changeInPeriod,
        changePercentInPeriod);

    var slivers = <Widget>[];

    slivers.add(sliverAppBar);

    if (done == false) {
      slivers.add(const SliverToBoxAdapter(
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
      )));
    }
    if (portfolioHistoricals != null) {
      var brightness = MediaQuery.of(context).platformBrightness;
      var textColor = Theme.of(context).colorScheme.background;
      if (brightness == Brightness.dark) {
        textColor = Colors.grey.shade200;
      } else {
        textColor = Colors.grey.shade800;
      }
      /*
      slivers.add(const SliverToBoxAdapter(
          child: SizedBox(
        height: 25.0,
      )));
*/
      slivers.add(SliverToBoxAdapter(
          child: SizedBox(
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
                        const Text(
                          "Portfolio",
                          style: TextStyle(fontSize: 19.0),
                        ),
                        Container(
                          width: 10,
                        ),
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
              ))));

      slivers.add(SliverToBoxAdapter(
          child: SizedBox(
              height: 400,
              child: Padding(
                //padding: EdgeInsets.symmetric(horizontal: 12.0),
                padding: const EdgeInsets.all(10.0),
                child: chart,
              ))));
      //child: StackedAreaLineChart.withSampleData()))));
      slivers.add(SliverToBoxAdapter(
          child: SizedBox(
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
                        selected: chartDateSpanFilter == ChartDateSpan.hour,
                        onSelected: (bool value) {
                          if (value) {
                            resetChart(ChartDateSpan.hour, chartBoundsFilter);
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
                        selected: chartDateSpanFilter == ChartDateSpan.day,
                        onSelected: (bool value) {
                          if (value) {
                            resetChart(ChartDateSpan.day, chartBoundsFilter);
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
                        selected: chartDateSpanFilter == ChartDateSpan.week,
                        onSelected: (bool value) {
                          if (value) {
                            resetChart(ChartDateSpan.week, chartBoundsFilter);
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
                        selected: chartDateSpanFilter == ChartDateSpan.month,
                        onSelected: (bool value) {
                          if (value) {
                            resetChart(ChartDateSpan.month, chartBoundsFilter);
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
                        selected: chartDateSpanFilter == ChartDateSpan.month_3,
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
                        selected: chartDateSpanFilter == ChartDateSpan.year,
                        onSelected: (bool value) {
                          if (value) {
                            resetChart(ChartDateSpan.year, chartBoundsFilter);
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
                        selected: chartDateSpanFilter == ChartDateSpan.all,
                        onSelected: (bool value) {
                          if (value) {
                            resetChart(ChartDateSpan.all, chartBoundsFilter);
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
                            resetChart(chartDateSpanFilter, Bounds.regular);
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
              ))));
    }
    if (welcomeWidget != null) {
      slivers.add(const SliverToBoxAdapter(
          child: SizedBox(
        height: 25.0,
      )));
      slivers.add(SliverToBoxAdapter(
          child: SizedBox(
        height: 150.0,
        child: Align(alignment: Alignment.center, child: welcomeWidget),
      )));
    }

    if (optionPositions != null) {
      var filteredOptionAggregatePositions = optionPositions
          .where((element) =>
              ((hasQuantityFilters[0] && hasQuantityFilters[1]) ||
                  (!hasQuantityFilters[0] || element.quantity! > 0) &&
                      (!hasQuantityFilters[1] || element.quantity! <= 0)) &&
              (positionFilters.isEmpty ||
                  positionFilters.contains(element.legs.first.positionType)) &&
              (optionFilters.isEmpty ||
                  optionFilters.contains(element.legs.first.positionType)) &&
              (optionSymbolFilters.isEmpty ||
                  optionSymbolFilters.contains(element.symbol)))
          .toList();

      if (filteredOptionAggregatePositions.isNotEmpty) {
        slivers.add(const SliverToBoxAdapter(
            child: SizedBox(
          height: 25.0,
        )));
        slivers.add(OptionPositionsRowWidget(
            widget.user, account!, filteredOptionAggregatePositions));
      }
      slivers.add(const SliverToBoxAdapter(
          child: SizedBox(
        height: 25.0,
      )));
    }

    if (positions != null) {
      var filteredPositions = positions
          .where((element) =>
              ((hasQuantityFilters[0] && hasQuantityFilters[1]) ||
                  //(!hasQuantityFilters[0] && !hasQuantityFilters[1]) ||
                  (!hasQuantityFilters[0] || element.quantity! > 0) &&
                      (!hasQuantityFilters[1] || element.quantity! <= 0)) &&
              /*
                (days == 0 ||
                    element.createdAt!
                            .add(Duration(days: days))
                            .compareTo(DateTime.now()) >=
                        0) &&
                        */
              (stockSymbolFilters.isEmpty ||
                  stockSymbolFilters.contains(element.instrumentObj!.symbol)))
          .toList();

      double? value =
          widget.user.getPositionAggregateDisplayValue(filteredPositions);
      String? trailingText;
      Icon? icon;
      if (value != null) {
        trailingText = widget.user.getDisplayText(value);
        icon = widget.user.getDisplayIcon(value);
      }

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
        var minimum = positionDisplayValues.reduce(math.min);
        if (minimum < 0) {
          minimum -= 0.05;
        } else if (minimum > 0) {
          minimum = 0;
        }
        var maximum = positionDisplayValues.reduce(math.max);
        if (maximum > 0) {
          maximum += 0.05;
        } else if (maximum < 0) {
          maximum = 0;
        }

        primaryMeasureAxis = charts.PercentAxisSpec(
            viewport: charts.NumericExtents(minimum, maximum),
            renderSpec: charts.GridlineRendererSpec(
                labelStyle: charts.TextStyleSpec(color: axisLabelColor)));
      }
      var positionChart = BarChart(barChartSeriesList,
          renderer: charts.BarRendererConfig(
              barRendererDecorator: charts.BarLabelDecorator<String>(),
              cornerStrategy: const charts.ConstCornerStrategy(10)),
          primaryMeasureAxis: primaryMeasureAxis,
          barGroupingType: null,
          domainAxis: charts.OrdinalAxisSpec(
              renderSpec: charts.SmallTickRendererSpec(
                  labelStyle: charts.TextStyleSpec(color: axisLabelColor))),
          onSelected: (_) {});
      //}
      slivers.add(SliverToBoxAdapter(
          child: Column(children: [
        ListTile(
          title: const Text(
            "Stocks",
            style: TextStyle(fontSize: 19.0),
          ),
          subtitle: Text(
              "${formatCompactNumber.format(filteredPositions.length)} positions"), // , ${formatCurrency.format(positionEquity)} market value // of ${formatCompactNumber.format(positions.length)}
          trailing: Wrap(spacing: 8, children: [
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
      ])));
      if (widget.user.displayValue != DisplayValue.lastPrice &&
          barChartSeriesList.isNotEmpty &&
          barChartSeriesList.first.data.isNotEmpty) {
        slivers.add(SliverToBoxAdapter(
            child: SizedBox(
                height: barChartSeriesList.first.data.length == 1
                    ? 75
                    : barChartSeriesList.first.data.length * 50,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      10.0, 0, 10, 10), //EdgeInsets.zero
                  child: positionChart,
                ))));
      }
      slivers.add(SliverList(
        // delegate: SliverChildListDelegate(widgets),
        delegate: SliverChildBuilderDelegate(
          (BuildContext context, int index) {
            return _buildPositionRow(filteredPositions, index);
          },
          // Or, uncomment the following line:
          childCount: filteredPositions.length,
        ),
      ));
      slivers.add(const SliverToBoxAdapter(
          child: SizedBox(
        height: 25.0,
      )));
    }

    if (nummusHoldings != null) {
      cryptoSymbols =
          nummusHoldings.map((e) => e.currencyCode).toSet().toList();
      cryptoSymbols.sort((a, b) => (a.compareTo(b)));

      var filteredHoldings = nummusHoldings
          .where((element) =>
              ((hasQuantityFilters[0] && hasQuantityFilters[1]) ||
                  (!hasQuantityFilters[0] || element.quantity! > 0) &&
                      (!hasQuantityFilters[1] || element.quantity! <= 0)) &&
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

      double? value =
          widget.user.getCryptoAggregateDisplayValue(filteredHoldings);
      String? trailingText;
      Icon? icon;
      if (value != null) {
        trailingText = widget.user.getDisplayText(value);
        icon = widget.user.getDisplayIcon(value);
      }
      slivers.add(SliverToBoxAdapter(
          child: Column(children: [
        ListTile(
            title: const Text(
              "Cryptos",
              style: TextStyle(fontSize: 19.0),
            ),
            subtitle: Text(
                "${formatCompactNumber.format(filteredHoldings.length)} cryptos"), // , ${formatCurrency.format(nummusEquity)} market value // of ${formatCompactNumber.format(nummusHoldings.length)}
            trailing: Wrap(spacing: 8, children: [
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
            ]))
      ])));
      slivers.add(SliverList(
        // delegate: SliverChildListDelegate(widgets),
        delegate: SliverChildBuilderDelegate(
          (BuildContext context, int index) {
            return _buildCryptoRow(filteredHoldings, index);
          },
          // Or, uncomment the following line:
          childCount: filteredHoldings.length,
        ),
      ));
      slivers.add(const SliverToBoxAdapter(
          child: SizedBox(
        height: 25.0,
      )));
    }

    if (portfolios != null) {
      slivers.add(SliverToBoxAdapter(
          child: Column(children: const [
        ListTile(
          title: Text(
            "Portfolios",
            style: TextStyle(fontSize: 19.0),
          ),
        )
      ])));
      slivers.add(portfoliosWidget(portfolios));
      slivers.add(const SliverToBoxAdapter(
          child: SizedBox(
        height: 25.0,
      )));
    }
    /*
    if (userInfo != null) {
      slivers.add(SliverToBoxAdapter(
          child: Column(children: const [
        ListTile(
          title: Text(
            "User",
            style: TextStyle(fontSize: 19.0),
          ),
        )
      ])));
      slivers.add(userWidget(userInfo));
      slivers.add(const SliverToBoxAdapter(
          child: SizedBox(
        height: 25.0,
      )));
    }
    */
    slivers.add(const SliverToBoxAdapter(child: DisclaimerWidget()));
    slivers.add(const SliverToBoxAdapter(
        child: SizedBox(
      height: 25.0,
    )));

    return RefreshIndicator(
      child: CustomScrollView(
          // physics: ClampingScrollPhysics(),
          slivers: slivers), //controller: _controller,
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

  Widget optionSymbolFilterWidget(StateSetter bottomState) {
    var widgets =
        optionSymbolFilterWidgets(chainSymbols, optionPositions, bottomState)
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
                      optionPositionStream = null;
                      positionStream = null;
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
      List<Portfolio>? portfolios,
      UserInfo? userInfo,
      Account? account,
      double portfolioValue,
      double stockAndOptionsEquityPercent,
      double positionEquity,
      double positionEquityPercent,
      double nummusEquity,
      double cryptoPercent,
      double optionEquity,
      double optionEquityPercent,
      double portfolioCash,
      double cashPercent,
      double changeInPeriod,
      double changePercentInPeriod) {
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
        if (portfolios == null) {
          return const FlexibleSpaceBar(title: Text('Robinhood Options'));
        }
        //var top = constraints.biggest.height;
        //debugPrint(top.toString());
        //debugPrint(kToolbarHeight.toString());

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
            title: Opacity(
                //duration: Duration(milliseconds: 300),
                opacity: opacity, //top > kToolbarHeight * 3 ? 1.0 : 0.0,
                child: _buildExpandedSliverAppBarTitle(
                    userInfo,
                    portfolioValue,
                    stockAndOptionsEquityPercent,
                    portfolios,
                    optionEquityPercent,
                    optionEquity,
                    positionEquityPercent,
                    positionEquity,
                    cryptoPercent,
                    nummusEquity,
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
      double optionEquity,
      double positionEquityPercent,
      double positionEquity,
      double cryptoPercent,
      double nummusEquity,
      double cashPercent,
      double portfolioCash) {
    return SingleChildScrollView(
      child: Column(
          //mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
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
                    child: Text(formatCurrency.format(optionEquity),
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
                    child: Text(formatCurrency.format(positionEquity),
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
                    child: Text(formatCurrency.format(nummusEquity),
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
    setState(() {
      futurePortfolios = null;

      //futureOptionPositions = null;
      optionPositionStream = null;
      optionOrderStream = null;
      positionStream = null;
      positionOrderStream = null;
      //watchlistStream = null;
    });

    var accounts = await RobinhoodService.getAccounts(widget.user);
    var portfolios = await RobinhoodService.getPortfolios(widget.user);

    //var optionPositions = await RobinhoodService.downloadOptionPositions(snapshotUser);
    /*
    var positions = await RobinhoodService.downloadPositions(snapshotUser);
    var watchlists = await RobinhoodService.downloadWatchlists(snapshotUser);
    */
    //var user = await RobinhoodService.downloadUser(snapshotUser);

    setState(() {
      futureAccounts = Future.value(accounts);
      futurePortfolios = Future.value(portfolios);
      //futureUser = Future.value(user);
    });
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
    Icon? icon = widget.user.getDisplayIcon(value);

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
                      widget.user, account!, instrument!,
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
    Icon? icon = widget.user.getDisplayIcon(value);

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
                      widget.user, account!, holdings[index])));
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
