import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:robinhood_options_mobile/enums.dart';
import 'dart:math' as math;

import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/equity_historical.dart';
import 'package:robinhood_options_mobile/model/forex_holding.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_order.dart';
import 'package:robinhood_options_mobile/model/portfolio.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals.dart';
import 'package:robinhood_options_mobile/model/position.dart';
import 'package:robinhood_options_mobile/model/position_order.dart';
import 'package:robinhood_options_mobile/model/robinhood_user.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
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
  /*
  final drawerItems = [
    new DrawerItem("Home", Icons.home),
    //new DrawerItem("Account", Icons.verified_user),
    new DrawerItem("Options", Icons.library_books),
    new DrawerItem("Logout", Icons.logout),
  ];
  */

  const HomePage(this.user,
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
  Future<List<ForexHolding>>? futureNummusHoldings;
  Future<List<Portfolio>>? futurePortfolios;

  Future<PortfolioHistoricals>? futurePortfolioHistoricals;
  PortfolioHistoricals? portfolioHistoricals;
  //charts.TimeSeriesChart? chart;
  List<charts.Series<dynamic, DateTime>>? seriesList;
  TimeSeriesChart? chart;
  ChartDateSpan chartDateSpanFilter = ChartDateSpan.day;
  Bounds chartBoundsFilter = Bounds.t24_7;
  EquityHistorical? selection;

  Stream<List<Position>>? positionStream;
  List<Position> positions = [];
  Stream<List<PositionOrder>>? positionOrderStream;

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

  /*
  Stream<List<Watchlist>>? watchlistStream;

  SortType? _sortType = SortType.alphabetical;
  SortDirection? _sortDirection = SortDirection.desc;
  */

  Future<User>? futureUser;

  Timer? refreshTriggerTime;

/*
  late ScrollController _controller;
  bool silverCollapsed = false;
*/

  // int _selectedDrawerIndex = 0;
  // bool _showDrawerContents = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    /*
    _controller = ScrollController();
    _controller.addListener(() {
      if (_controller.offset > 220 && !_controller.position.outOfRange) {
        if (!silverCollapsed) {
          // do what ever you want when silver is collapsing !

          silverCollapsed = true;
          setState(() {});
        }
      }
      if (_controller.offset <= 220 && !_controller.position.outOfRange) {
        if (silverCollapsed) {
          // do what ever you want when silver is expanding !

          silverCollapsed = false;
          setState(() {});
        }
      }
    });
    */
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
    futureUser ??= RobinhoodService.getUser(widget.user);
    futureAccounts ??= RobinhoodService.getAccounts(widget.user);
    futurePortfolios ??= RobinhoodService.getPortfolios(widget.user);
    //futureNummusAccounts ??= RobinhoodService.downloadNummusAccounts(widget.user);
    futureNummusHoldings ??= RobinhoodService.getNummusHoldings(widget.user,
        nonzero: !hasQuantityFilters[1]);

    return FutureBuilder(
      future: Future.wait([
        futureUser as Future,
        futureAccounts as Future,
        futurePortfolios as Future,
        futureNummusHoldings as Future,
      ]),
      builder: (context1, dataSnapshot) {
        if (dataSnapshot.hasData) {
          List<dynamic> data = dataSnapshot.data as List<dynamic>;
          var user = data.isNotEmpty ? data[0] as User : null;
          var _accounts = data.length > 1 ? data[1] as List<Account> : null;

          // Special logic to refresh the parent widget when a new account is downloaded.
          if (accounts == null || accounts!.length != _accounts!.length) {
            accounts = _accounts;
            WidgetsBinding.instance!.addPostFrameCallback(
                (_) => widget.onAccountsChanged(accounts!));
          }
          var portfolios = data.length > 2 ? data[2] as List<Portfolio> : null;
          var nummusHoldings =
              data.length > 3 ? data[3] as List<ForexHolding> : null;

          futurePortfolioHistoricals ??=
              RobinhoodService.getPortfolioHistoricals(
                  widget.user,
                  accounts![0].accountNumber,
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
                  }
                  portfolioHistoricals =
                      historicalsSnapshot.data as PortfolioHistoricals;

                  positionStream ??= RobinhoodService.streamPositions(
                      widget.user,
                      nonzero: !hasQuantityFilters[1]);

                  return StreamBuilder(
                      stream: positionStream,
                      builder: (context2, positionSnapshot) {
                        if (positionSnapshot.hasData) {
                          positions = positionSnapshot.data as List<Position>;

                          optionPositionStream ??= RobinhoodService
                              .streamOptionAggregatePositionList(widget.user,
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
                                      user: user,
                                      accounts: accounts,
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
                                    user: user,
                                    accounts: accounts,
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
                            user: user,
                            accounts: accounts,
                            nummusHoldings: nummusHoldings,
                            portfolioHistoricals: portfolioHistoricals,
                          );
                        }
                      });
                } else {
                  // No PortfolioHistoricals found
                  return _buildPage(
                      portfolios: portfolios,
                      user: user,
                      accounts: accounts,
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
          var refreshedOptionPositions =
              await RobinhoodService.refreshOptionMarketData(
                  widget.user, optionPositions);
          setState(() {
            optionPositions = refreshedOptionPositions;
          });
          var refreshPositions = await RobinhoodService.refreshPositionQuote(
              widget.user, positions);
          setState(() {
            positions = refreshPositions;
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
      User? user,
      List<Account>? accounts,
      List<ForexHolding>? nummusHoldings,
      Widget? welcomeWidget,
      PortfolioHistoricals? portfolioHistoricals,
      List<OptionAggregatePosition>? optionPositions,
      List<Position>? positions,
      bool done = false}) {
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

    double changeToday = 0;
    double changePercentToday = 0;

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
      optionEquity = optionPositions
          .map((e) => e.legs.first.positionType == "long"
              ? e.marketValue
              : e.marketValue)
          .reduce((a, b) => a + b);
      chainSymbols = optionPositions.map((e) => e.symbol).toSet().toList();
      chainSymbols.sort((a, b) => (a.compareTo(b)));
    }

    if (portfolios != null) {
      portfolioValue = (portfolios[0].equity ?? 0) + nummusEquity;
      stockAndOptionsEquityPercent =
          portfolios[0].marketValue! / portfolioValue;
      optionEquityPercent = optionEquity / portfolioValue;
      positionEquityPercent = positionEquity / portfolioValue;
      portfolioCash = accounts![0].portfolioCash ?? 0;
      cashPercent = portfolioCash / portfolioValue;
      cryptoPercent = nummusEquity / portfolioValue;

      changeToday = portfolios[0].equity! - portfolios[0].equityPreviousClose!;
      changePercentToday = changeToday / portfolios[0].equity!;
    }

    if (portfolioHistoricals != null) {
      firstHistorical = portfolioHistoricals.equityHistoricals[0];
      lastHistorical = portfolioHistoricals
          .equityHistoricals[portfolioHistoricals.equityHistoricals.length - 1];
      open = firstHistorical.adjustedOpenEquity!;
      close = lastHistorical.adjustedCloseEquity!;
      changeInPeriod = close - open;
      //changePercentToday = changeInPeriod / close;

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
        var open =
            portfolioHistoricals.equityHistoricals[0].adjustedOpenEquity!;
        var close = portfolioHistoricals
            .equityHistoricals[
                portfolioHistoricals.equityHistoricals.length - 1]
            .adjustedCloseEquity!;
        chart = TimeSeriesChart(seriesList,
            open: open,
            close: close,
            hiddenSeries: const ['Equity', 'Market Value'],
            onSelected: _onChartSelection);
      }
    }

    SliverAppBar sliverAppBar = buildSliverAppBar(
        portfolios,
        user,
        accounts,
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
        changeToday,
        changePercentToday);

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

      //var interval = portfolioHistoricals.interval; // "15second"

      double changeSelection = 0;
      double changePercentSelection = 0;
      if (selection != null) {
        changeSelection = selection!.adjustedCloseEquity! -
            open; // portfolios![0].equityPreviousClose!;
        changePercentSelection =
            changeSelection / selection!.adjustedCloseEquity!;
      }
      slivers.add(const SliverToBoxAdapter(
          child: SizedBox(
        height: 25.0,
      )));

      slivers.add(SliverToBoxAdapter(
          child: SizedBox(
              height: 36,
              child: Center(
                  child: Column(
                children: [
                  Wrap(
                    children: [
                      if (selection != null) ...[
                        Text(
                            formatCurrency
                                .format(selection!.adjustedCloseEquity),
                            style: TextStyle(fontSize: 20, color: textColor)),
                        Container(
                          width: 10,
                        ),
                        Icon(
                          changePercentSelection > 0
                              ? Icons.trending_up
                              : (changePercentSelection < 0
                                  ? Icons.trending_down
                                  : Icons.trending_flat),
                          color: (changePercentSelection > 0
                              ? Colors.green
                              : (changePercentSelection < 0
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
                                .format(changePercentSelection.abs()),
                            style: TextStyle(fontSize: 20.0, color: textColor)),
                        Container(
                          width: 10,
                        ),
                        Text(
                            "${changeSelection > 0 ? "+" : changeSelection < 0 ? "-" : ""}${formatCurrency.format(changeSelection.abs())}",
                            style: TextStyle(fontSize: 20.0, color: textColor)),
                      ] else ...[
                        Text(
                            formatCurrency.format(
                                close), //(portfolios![0].equity ?? 0) + nummusEquity
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
                          //size: 16.0
                        ),
                        Container(
                          width: 2,
                        ),
                        Text(formatPercentage.format(changePercentToday.abs()),
                            style: TextStyle(fontSize: 20.0, color: textColor)),
                        Container(
                          width: 10,
                        ),
                        Text(
                            "${changeInPeriod > 0 ? "+" : changeInPeriod < 0 ? "-" : ""}${formatCurrency.format(changeInPeriod.abs())}",
                            style: TextStyle(fontSize: 20.0, color: textColor)),
                      ]
                    ],
                  ),
                  if (selection != null) ...[
                    Text(
                        '${formatMediumDate.format(firstHistorical!.beginsAt!.toLocal())} - ${formatMediumDate.format(selection!.beginsAt!.toLocal())}',
                        style: TextStyle(fontSize: 10, color: textColor)),
                  ] else ...[
                    Text(
                        '${formatMediumDate.format(firstHistorical!.beginsAt!.toLocal())} - ${formatMediumDate.format(lastHistorical!.beginsAt!.toLocal())}', //portfolios![0].updatedAt!.toLocal()
                        style: TextStyle(fontSize: 10, color: textColor)),
                  ]
                  /*
                      Text(
                          "Equity ${formatCurrency.format(selection!.openEquity)}, ${formatCurrency.format(selection!.closeEquity)}",
                          style: const TextStyle(fontSize: 11)),
                      Text(
                          "Value ${formatCurrency.format(selection!.openMarketValue)}, ${formatCurrency.format(selection!.closeMarketValue)}",
                          style: const TextStyle(fontSize: 11))
                          */
                ],
              )))));

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
      /*
      var groupedOptionAggregatePositions = filteredOptionAggregatePositions
          .groupListsBy((element) => element.symbol);
      */
      if (filteredOptionAggregatePositions.isNotEmpty) {
        slivers.add(const SliverToBoxAdapter(
            child: SizedBox(
          height: 25.0,
        )));
        slivers.add(OptionPositionsRowWidget(
            widget.user, accounts!.first, filteredOptionAggregatePositions));
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

      double? value = getPositionAggregateDisplayValue(filteredPositions);
      String? trailingText;
      Icon? icon;
      if (value != null) {
        trailingText = getDisplayText(value);
        icon = getDisplayIcon(value);
      }

      slivers.add(SliverStickyHeader(
          header: Material(
              //elevation: 2,
              child: Container(
                  //height: 208.0, //60.0,
                  //padding: EdgeInsets.symmetric(horizontal: 16.0),
                  alignment: Alignment.centerLeft,
                  child: ListTile(
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
                    /*
                      IconButton(
                          icon: const Icon(Icons.more_vert),
                          onPressed: () {
                            showModalBottomSheet<void>(
                                context: context,
                                //constraints: BoxConstraints(maxHeight: 260),
                                builder: (BuildContext context) {
                                  return StatefulBuilder(builder:
                                      (BuildContext context,
                                          StateSetter bottomState) {
                                    return Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ListTile(
                                          tileColor: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          leading:
                                              const Icon(Icons.filter_list),
                                          title: const Text(
                                            "Filter Stocks",
                                            style: TextStyle(fontSize: 19.0),
                                          ),
                                          /*
                                  trailing: TextButton(
                                      child: const Text("APPLY"),
                                      onPressed: () => Navigator.pop(context))*/
                                        ),
                                        const ListTile(
                                          title:
                                              Text("Position Type"), // & Date
                                        ),
                                        positionTypeFilterWidget(bottomState),
                                        //orderDateFilterWidget,
                                        const ListTile(
                                          title: Text("Symbols"),
                                        ),
                                        stockOrderSymbolFilterWidget(
                                            bottomState),
                                      ],
                                    );
                                  });
                                });
                          }),*/
                  ))),
          sliver: SliverList(
            // delegate: SliverChildListDelegate(widgets),
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) {
                return _buildPositionRow(filteredPositions, index);
              },
              // Or, uncomment the following line:
              childCount: filteredPositions.length,
            ),
          )));
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

      double? value = getCryptoAggregateDisplayValue(filteredHoldings);
      String? trailingText;
      Icon? icon;
      if (value != null) {
        trailingText = getDisplayText(value);
        icon = getDisplayIcon(value);
      }

      slivers.add(SliverStickyHeader(
          header: Material(
              //elevation: 2,
              child: Container(
                  //height: 208.0, //60.0,
                  //padding: EdgeInsets.symmetric(horizontal: 16.0),
                  alignment: Alignment.centerLeft,
                  child: ListTile(
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
                    ]),
                    /*
                      IconButton(
                          icon: const Icon(Icons.more_vert),
                          onPressed: () {
                            showModalBottomSheet<void>(
                                context: context,
                                //constraints: BoxConstraints(maxHeight: 260),
                                builder: (BuildContext context) {
                                  return StatefulBuilder(builder:
                                      (BuildContext context,
                                          StateSetter bottomState) {
                                    return Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ListTile(
                                          tileColor: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          leading:
                                              const Icon(Icons.filter_list),
                                          title: const Text(
                                            "Filter Cryptos",
                                            style: TextStyle(fontSize: 19.0),
                                          ),
                                          /*
                                  trailing: TextButton(
                                      child: const Text("APPLY"),
                                      onPressed: () => Navigator.pop(context))*/
                                        ),
                                        const ListTile(
                                          title:
                                              Text("Position Type"), // & Date
                                        ),
                                        positionTypeFilterWidget(bottomState),
                                        //orderDateFilterWidget,
                                        const ListTile(
                                          title: Text("Symbols"),
                                        ),
                                        cryptoFilterWidget(bottomState),
                                      ],
                                    );
                                  });
                                });
                          }),*/
                  ))),
          sliver: SliverList(
            // delegate: SliverChildListDelegate(widgets),
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) {
                return _buildCryptoRow(filteredHoldings, index);
              },
              // Or, uncomment the following line:
              childCount: filteredHoldings.length,
            ),
          )));
      slivers.add(const SliverToBoxAdapter(
          child: SizedBox(
        height: 25.0,
      )));
    }

    if (accounts != null) {
      slivers.add(SliverStickyHeader(
          header: Material(
              //elevation: 2,
              child: Container(
            //height: 208.0, //60.0,
            //padding: EdgeInsets.symmetric(horizontal: 16.0),
            alignment: Alignment.centerLeft,
            child: const ListTile(
              title: Text(
                "Accounts",
                style: TextStyle(fontSize: 19.0),
              ),
            ),
          )),
          sliver: SliverToBoxAdapter(
              child: Card(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: accountWidgets(accounts).toList())))));
      slivers.add(const SliverToBoxAdapter(
          child: SizedBox(
        height: 25.0,
      )));
    }

    if (portfolios != null) {
      slivers.add(SliverStickyHeader(
          header: Material(
              //elevation: 2,
              child: Container(
            //height: 208.0, //60.0,
            //padding: EdgeInsets.symmetric(horizontal: 16.0),
            alignment: Alignment.centerLeft,
            child: const ListTile(
              title: Text(
                "Portfolios",
                style: TextStyle(fontSize: 19.0),
              ),
            ),
          )),
          sliver: portfoliosWidget(portfolios)));
      slivers.add(const SliverToBoxAdapter(
          child: SizedBox(
        height: 25.0,
      )));
    }
    if (user != null) {
      slivers.add(SliverStickyHeader(
          header: Material(
              //elevation: 2,
              child: Container(
            //height: 208.0, //60.0,
            //padding: EdgeInsets.symmetric(horizontal: 16.0),
            alignment: Alignment.centerLeft,
            child: const ListTile(
              title: Text(
                "User",
                style: TextStyle(fontSize: 19.0),
              ),
            ),
          )),
          sliver: userWidget(user)));
      slivers.add(const SliverToBoxAdapter(
          child: SizedBox(
        height: 25.0,
      )));
    }
    slivers.add(SliverStickyHeader(
        header: Material(
            //elevation: 2.0,
            child: Container(
                //height: 208.0, //60.0,
                //padding: EdgeInsets.symmetric(horizontal: 16.0),
                alignment: Alignment.centerLeft,
                child: null)),
        sliver: const SliverToBoxAdapter(child: DisclaimerWidget())));
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

  Iterable<Widget> accountWidgets(List<Account> accounts) sync* {
    for (Account account in accounts) {
      yield ListTile(
        title: const Text("Account", style: TextStyle(fontSize: 14)),
        trailing:
            Text(account.accountNumber, style: const TextStyle(fontSize: 16)),
      );
      yield ListTile(
        title: const Text("Type", style: TextStyle(fontSize: 14)),
        trailing: Text(account.type, style: const TextStyle(fontSize: 16)),
      );
      yield ListTile(
        title: const Text("Portfolio Cash", style: TextStyle(fontSize: 14)),
        trailing: Text(formatCurrency.format(account.portfolioCash),
            style: const TextStyle(fontSize: 16)),
      );
      yield ListTile(
        title: const Text("Buying Power", style: TextStyle(fontSize: 14)),
        trailing: Text(formatCurrency.format(account.buyingPower),
            style: const TextStyle(fontSize: 16)),
      );
      yield ListTile(
        title: const Text("Cash Held For Options Collateral",
            style: TextStyle(fontSize: 14)),
        trailing: Text(
            formatCurrency.format(account.cashHeldForOptionsCollateral),
            style: const TextStyle(fontSize: 16)),
      );
      yield ListTile(
        title: const Text("Option Level", style: TextStyle(fontSize: 14)),
        trailing:
            Text(account.optionLevel, style: const TextStyle(fontSize: 16)),
      );
    }
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

  Widget userWidget(User user) {
    return SliverToBoxAdapter(
        child: Card(
            child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      ListTile(
        title: const Text("Profile Name", style: TextStyle(fontSize: 14)),
        trailing: Text(user.profileName, style: const TextStyle(fontSize: 16)),
      ),
      ListTile(
        title: const Text("Username", style: TextStyle(fontSize: 14)),
        trailing: Text(user.username, style: const TextStyle(fontSize: 16)),
      ),
      ListTile(
        title: const Text("Full Name", style: TextStyle(fontSize: 14)),
        trailing: Text("${user.firstName} ${user.lastName}",
            style: const TextStyle(fontSize: 16)),
      ),
      ListTile(
        title: const Text("Email", style: TextStyle(fontSize: 14)),
        trailing: Text(user.email, style: const TextStyle(fontSize: 16)),
      ),
      ListTile(
        title: const Text("Joined", style: TextStyle(fontSize: 14)),
        trailing: Text(formatDate.format(user.createdAt!),
            style: const TextStyle(fontSize: 16)),
      ),
      ListTile(
        title: const Text("Locality", style: TextStyle(fontSize: 14)),
        trailing: Text(user.locality, style: const TextStyle(fontSize: 16)),
      ),
      ListTile(
        title: const Text("Id", style: TextStyle(fontSize: 14)),
        trailing: Text(user.id, style: const TextStyle(fontSize: 14)),
      ),
      /*
        ListTile(
          title: const Text("Id Info", style: const TextStyle(fontSize: 14)),
          trailing: Text(user.idInfo, style: const TextStyle(fontSize: 12)),
        ),
        ListTile(
          title: const Text("Url", style: const TextStyle(fontSize: 14)),
          trailing: Text(user.url, style: const TextStyle(fontSize: 12)),
        ),
        */
    ])));
  }

  /*
  Widget watchListWidget(List<WatchlistItem> watchLists) {
    return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 150.0,
            mainAxisSpacing: 6.0,
            crossAxisSpacing: 2.0,
            childAspectRatio: 1.3,
          ),
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              return _buildWatchlistGridItem(watchLists, index, widget.user);
            },
            childCount: watchLists.length,
          ),
        ));
  }
  */

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
      User? user,
      List<Account>? accounts,
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
      double changeToday,
      double changePercentToday) {
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
            if (user != null) ...[
              Text(user.profileName, style: const TextStyle(fontSize: 22.0)),
              Wrap(spacing: 10, children: [
                Text(formatCurrency.format(portfolioValue),
                    style:
                        const TextStyle(fontSize: 17.0, color: Colors.white70)),
                //style: const TextStyle(fontSize: 20.0),
                //textAlign: TextAlign.right
                Wrap(alignment: WrapAlignment.center, children: [
                  Icon(
                      changeToday > 0
                          ? Icons.trending_up
                          : (changeToday < 0
                              ? Icons.trending_down
                              : Icons.trending_flat),
                      color: (changeToday > 0
                          ? Colors.green
                          : (changeToday < 0 ? Colors.red : Colors.grey)),
                      size: 20.0),
                  Text(formatPercentage.format(changePercentToday.abs()),
                      style: const TextStyle(
                          fontSize: 17.0, color: Colors.white70)),
                ]),
                Text(
                    "${changeToday > 0 ? "+" : changeToday < 0 ? "-" : ""}${formatCurrency.format(changeToday.abs())}",
                    style:
                        const TextStyle(fontSize: 17.0, color: Colors.white70)),
              ]),
            ]
          ]),
      /*
      silverCollapsed && user != null && portfolios != null
          ? getAppBarTitle(user, changeToday, changePercentToday)
          : Container(),
          */
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
                    user,
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
                    onSettingsChanged: _onSettingsChanged)
                /*
              (BuildContext context) {
                return StatefulBuilder(
                    builder: (BuildContext context, StateSetter bottomState) {
                  return Scaffold(
                      appBar: AppBar(
                          leading: const CloseButton(),
                          title: const Text('Settings')),
                      body: ListView(
                        //Column(
                        //mainAxisAlignment: MainAxisAlignment.start,
                        //crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          /*
                    new AppBar(
                      title: new Text("Menu"),
                    ),
                    */
                          /*
                    Container(
                      height: 10,
                    ),
                    const Text(
                      "Menu",
                      style: TextStyle(fontSize: 20),
                    ),
                    Container(
                      height: 10,
                    ),
                    const Divider(
                      height: 10,
                    ),
                    */
                          if (ru != null && ru.userName != null) ...[
                            const ListTile(
                              leading: Icon(Icons.refresh),
                              title: Text(
                                "Refresh",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            RadioListTile<bool>(
                                //leading: const Icon(Icons.account_circle),
                                title: const Text("No Refresh"),
                                value: widget.user.refreshEnabled == false,
                                groupValue: true, //"refresh-setting"
                                onChanged: (val) {
                                  widget.user.refreshEnabled = false;
                                  widget.user.save();
                                  Navigator.pop(context, 'dialog');
                                }),
                            RadioListTile<bool>(
                              //leading: const Icon(Icons.account_circle),
                              title: const Text("Automatic Refresh"),
                              value: widget.user.refreshEnabled == true,
                              groupValue: true, //"refresh-setting",
                              onChanged: (val) {
                                setState(() {
                                  portfolioHistoricals = null;
                                  futurePortfolioHistoricals = null;
                                });
                                widget.user.refreshEnabled = true;
                                widget.user.save();
                                Navigator.pop(context, 'dialog');
                              },
                            ),
                            const Divider(
                              height: 10,
                            ),
                            const ListTile(
                              leading: Icon(Icons.calculate),
                              title: Text(
                                "Display Value",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            RadioListTile<bool>(
                                title: const Text("Last Price"),
                                value: widget.user.displayValue ==
                                    DisplayValue.lastPrice,
                                groupValue: true, //"refresh-setting"
                                onChanged: (val) {
                                  setState(() {
                                    widget.user.displayValue =
                                        DisplayValue.lastPrice;
                                  });
                                  widget.user.save();
                                  Navigator.pop(context, 'dialog');
                                }),
                            RadioListTile<bool>(
                                title: const Text("Market Value"),
                                value: widget.user.displayValue ==
                                    DisplayValue.marketValue,
                                groupValue: true, //"refresh-setting"
                                onChanged: (val) {
                                  setState(() {
                                    widget.user.displayValue =
                                        DisplayValue.marketValue;
                                  });
                                  widget.user.save();
                                  Navigator.pop(context, 'dialog');
                                }),
                            RadioListTile<bool>(
                                title: const Text("Return Today"),
                                value: widget.user.displayValue ==
                                    DisplayValue.todayReturn,
                                groupValue: true, //"refresh-setting"
                                onChanged: (val) {
                                  setState(() {
                                    widget.user.displayValue =
                                        DisplayValue.todayReturn;
                                  });
                                  widget.user.save();
                                  Navigator.pop(context, 'dialog');
                                }),
                            RadioListTile<bool>(
                                title: const Text("Return % Today"),
                                value: widget.user.displayValue ==
                                    DisplayValue.todayReturnPercent,
                                groupValue: true, //"refresh-setting"
                                onChanged: (val) {
                                  setState(() {
                                    widget.user.displayValue =
                                        DisplayValue.todayReturnPercent;
                                  });
                                  widget.user.save();
                                  Navigator.pop(context, 'dialog');
                                }),
                            RadioListTile<bool>(
                                title: const Text("Total Return"),
                                value: widget.user.displayValue ==
                                    DisplayValue.totalReturn,
                                groupValue: true, //"refresh-setting"
                                onChanged: (val) {
                                  setState(() {
                                    widget.user.displayValue =
                                        DisplayValue.totalReturn;
                                  });
                                  widget.user.save();
                                  Navigator.pop(context, 'dialog');
                                }),
                            RadioListTile<bool>(
                                title: const Text("Total Return %"),
                                value: widget.user.displayValue ==
                                    DisplayValue.totalReturnPercent,
                                groupValue: true, //"refresh-setting"
                                onChanged: (val) {
                                  setState(() {
                                    widget.user.displayValue =
                                        DisplayValue.totalReturnPercent;
                                  });
                                  widget.user.save();
                                  Navigator.pop(context, 'dialog');
                                }),
                            const Divider(
                              height: 10,
                            ),
                            const ListTile(
                              leading: Icon(Icons.view_module),
                              title: Text(
                                "Options View",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            RadioListTile<bool>(
                                //leading: const Icon(Icons.account_circle),
                                title: const Text("Grouped"),
                                value:
                                    widget.user.optionsView == View.grouped,
                                groupValue: true, //"refresh-setting"
                                onChanged: (val) {
                                  setState(() {
                                    widget.user.optionsView = View.grouped;
                                  });
                                  widget.user.save();
                                  Navigator.pop(context, 'dialog');
                                }),
                            RadioListTile<bool>(
                              //leading: const Icon(Icons.account_circle),
                              title: const Text("List"),
                              value: widget.user.optionsView == View.list,
                              groupValue: true, //"refresh-setting",
                              onChanged: (val) {
                                setState(() {
                                  widget.user.optionsView = View.list;
                                });
                                widget.user.save();
                                Navigator.pop(context, 'dialog');
                              },
                            ),
                            const Divider(
                              height: 10,
                            ),
                            const ListTile(
                              leading: Icon(Icons.filter_list),
                              title: Text(
                                "Filters",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            const ListTile(
                              //leading: Icon(Icons.filter_list),
                              title: Text("Position Type"),
                            ),
                            positionTypeFilterWidget(bottomState),
                            const ListTile(
                              //leading: Icon(Icons.filter_list),
                              title: Text("Option Type"),
                            ),
                            optionTypeFilterWidget(bottomState),
                            const ListTile(
                              //leading: Icon(Icons.filter_list),
                              title: Text("Option Symbols"),
                            ),
                            optionSymbolFilterWidget(bottomState),
                            const ListTile(
                              //leading: Icon(Icons.filter_list),
                              title: Text("Stock Symbols"),
                            ),
                            stockOrderSymbolFilterWidget(bottomState),
                            const ListTile(
                              title: Text("Crypto Symbols"),
                            ),
                            cryptoFilterWidget(bottomState),
                            const Divider(
                              height: 10,
                            ),
                            /*
                            const ListTile(
                              leading: Icon(Icons.manage_accounts),
                              title: Text(
                                "Account",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            */
                            ListTile(
                                leading: const Icon(Icons.account_circle),
                                title: const Text("Profile"),
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: const Text('Alert'),
                                        content: const Text(
                                            'This feature is not implemented.'),
                                        actions: <Widget>[
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, 'OK'),
                                            child: const Text('OK'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                }),
                            ListTile(
                              leading: const Icon(Icons.logout),
                              title: const Text("Logout"),
                              onTap: () {
                                var alert = AlertDialog(
                                  title: const Text('Logout process'),
                                  content: SingleChildScrollView(
                                    child: ListBody(
                                      children: const <Widget>[
                                        Text(
                                            'This action will require you to log in again.'),
                                        Text(
                                            'Are you sure you want to log out?'),
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
                                        Navigator.pop(context, 'dialog');
                                        _logout();
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
                              },
                            ),
                            const Divider(
                              height: 10,
                            )
                          ] else ...[
                            ListTile(
                              leading: const Icon(Icons.login),
                              title: const Text("Login"),
                              onTap: () {
                                _openLogin();
                              },
                            ),
                            const Divider(
                              height: 10,
                            )
                          ],
                          Container(
                            height: 10,
                          ),
                        ],
                      ));
                });
              },
            */
                );
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
      User? user,
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
      futureAccounts = null;
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

  Widget _buildPositionRow(List<Position> positions, int index) {
    var instrument = positions[index].instrumentObj;

    double value = getPositionDisplayValue(positions[index]);
    String trailingText = getDisplayText(value);
    Icon? icon = getDisplayIcon(value);

    return Card(
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      ListTile(
        /*
        leading: CircleAvatar(
            child: Text(formatCompactNumber.format(positions[index].quantity!),
                style: const TextStyle(fontSize: 17))),
                */
        leading: instrument != null && instrument.logoUrl != null
            ? CircleAvatar(
                radius: 25,
                foregroundColor:
                    Theme.of(context).colorScheme.primary, //.onBackground,
                //backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Image.network(
                  instrument.logoUrl!,
                  width: 40,
                  height: 40,
                  errorBuilder: (BuildContext context, Object exception,
                      StackTrace? stackTrace) {
                    return Text(instrument.symbol);
                  },
                ))
            : CircleAvatar(
                radius: 25,
                foregroundColor:
                    Theme.of(context).colorScheme.primary, //.onBackground,
                //backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  positions[index].instrumentObj != null
                      ? positions[index].instrumentObj!.symbol
                      /*.substring(
                          0,
                          positions[index].instrumentObj!.symbol.length < 4
                              ? positions[index].instrumentObj!.symbol.length
                              : 4)*/
                      : "",
                  //style: TextStyle(fontSize: 16.0),
                )), //const SizedBox(width: 40, height: 40),
        title: Text(positions[index].instrumentObj != null
            ? positions[index].instrumentObj!.simpleName ??
                positions[index].instrumentObj!.name
            : ""),
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
                      accounts!.first,
                      positions[index].instrumentObj as Instrument)));
          // Refresh in case settings were updated.
          futureFromInstrument.then((value) => setState(() {}));
        },
      )
    ]));
  }

  double? getAggregateDisplayValue(List<OptionAggregatePosition> ops) {
    double value = 0;
    switch (widget.user.displayValue) {
      case DisplayValue.lastPrice:
        return null;
      /*
        value = ops
            .map((OptionAggregatePosition e) => e.marketData!.lastTradePrice!)
            .reduce((a, b) => a + b);
        break;
            */
      case DisplayValue.marketValue:
        value = ops
            .map((OptionAggregatePosition e) =>
                e.legs.first.positionType == "long"
                    ? e.marketValue
                    : e.marketValue)
            .reduce((a, b) => a + b);
        break;
      case DisplayValue.todayReturn:
        value = ops
            .map((OptionAggregatePosition e) => e.changeToday)
            .reduce((a, b) => a + b);
        break;
      case DisplayValue.todayReturnPercent:
        var numerator = ops
            .map((OptionAggregatePosition e) =>
                e.changePercentToday * e.totalCost)
            .reduce((a, b) => a + b);
        var denominator = ops
            .map((OptionAggregatePosition e) => e.totalCost)
            .reduce((a, b) => a + b);
        value = numerator / denominator;
        /*
        value = ops
            .map((OptionAggregatePosition e) =>
                e.changePercentToday * e.marketValue)
            .reduce((a, b) => a + b);
            */
        break;
      case DisplayValue.totalReturn:
        value = ops
            .map((OptionAggregatePosition e) => e.gainLoss)
            .reduce((a, b) => a + b);
        break;
      case DisplayValue.totalReturnPercent:
        var numerator = ops
            .map((OptionAggregatePosition e) => e.gainLossPercent * e.totalCost)
            .reduce((a, b) => a + b);
        var denominator = ops
            .map((OptionAggregatePosition e) => e.totalCost)
            .reduce((a, b) => a + b);
        value = numerator / denominator;
        /*
        value = ops
            .map((OptionAggregatePosition e) => e.gainLossPercent)
            .reduce((a, b) => a + b);
            */
        break;
      default:
    }
    return value;
  }

  Icon? getDisplayIcon(double value) {
    if (widget.user.displayValue == DisplayValue.lastPrice ||
        widget.user.displayValue == DisplayValue.marketValue) {
      return null;
    }
    var icon = Icon(
        value > 0
            ? Icons.trending_up
            : (value < 0 ? Icons.trending_down : Icons.trending_flat),
        color: (value > 0
            ? Colors.green
            : (value < 0 ? Colors.red : Colors.grey)));
    return icon;
  }

  String getDisplayText(double value) {
    String opTrailingText = '';
    switch (widget.user.displayValue) {
      case DisplayValue.lastPrice:
      case DisplayValue.marketValue:
      case DisplayValue.todayReturn:
      case DisplayValue.totalReturn:
        opTrailingText = formatCurrency.format(value);
        break;
      case DisplayValue.todayReturnPercent:
      case DisplayValue.totalReturnPercent:
        opTrailingText = formatPercentage.format(value);
        break;
      default:
    }
    return opTrailingText;
  }

  double getDisplayValue(OptionAggregatePosition op) {
    double value = 0;
    switch (widget.user.displayValue) {
      case DisplayValue.lastPrice:
        value = op.marketData!.markPrice!;
        break;
      case DisplayValue.marketValue:
        value = op.marketValue;
        break;
      case DisplayValue.todayReturn:
        value = op.changeToday;
        break;
      case DisplayValue.todayReturnPercent:
        value = op.changePercentToday;
        break;
      case DisplayValue.totalReturn:
        value = op.gainLoss;
        break;
      case DisplayValue.totalReturnPercent:
        value = op.gainLossPercent;
        break;
      default:
    }
    return value;
  }

  double? getPositionAggregateDisplayValue(List<Position> ops) {
    double value = 0;
    switch (widget.user.displayValue) {
      case DisplayValue.lastPrice:
        return null;
      /*
        value = ops
            .map((Position e) =>
                e.instrumentObj!.quoteObj!.lastExtendedHoursTradePrice ??
                e.instrumentObj!.quoteObj!.lastTradePrice!)
            .reduce((a, b) => a + b);
        break;
        */
      case DisplayValue.marketValue:
        value = ops.map((Position e) => e.marketValue).reduce((a, b) => a + b);
        break;
      case DisplayValue.todayReturn:
        value =
            ops.map((Position e) => e.gainLossToday).reduce((a, b) => a + b);
        break;
      case DisplayValue.todayReturnPercent:
        var numerator = ops
            .map((Position e) => e.gainLossPercentToday * e.totalCost)
            .reduce((a, b) => a + b);
        var denominator =
            ops.map((Position e) => e.totalCost).reduce((a, b) => a + b);
        value = numerator / denominator;
        /*
        value = ops
            .map((OptionAggregatePosition e) =>
                e.changePercentToday * e.marketValue)
            .reduce((a, b) => a + b);
            */
        break;
      case DisplayValue.totalReturn:
        value = ops.map((Position e) => e.gainLoss).reduce((a, b) => a + b);
        break;
      case DisplayValue.totalReturnPercent:
        var numerator = ops
            .map((Position e) => e.gainLossPercent * e.totalCost)
            .reduce((a, b) => a + b);
        var denominator =
            ops.map((Position e) => e.totalCost).reduce((a, b) => a + b);
        value = numerator / denominator;
        /*
        value = ops
            .map((OptionAggregatePosition e) => e.gainLossPercent)
            .reduce((a, b) => a + b);
            */
        break;
      default:
    }
    return value;
  }

  double? getCryptoAggregateDisplayValue(List<ForexHolding> ops) {
    double value = 0;
    switch (widget.user.displayValue) {
      case DisplayValue.lastPrice:
        return null;
      /*
        value = ops
            .map((Position e) =>
                e.instrumentObj!.quoteObj!.lastExtendedHoursTradePrice ??
                e.instrumentObj!.quoteObj!.lastTradePrice!)
            .reduce((a, b) => a + b);
        break;
        */
      case DisplayValue.marketValue:
        value =
            ops.map((ForexHolding e) => e.marketValue).reduce((a, b) => a + b);
        break;
      case DisplayValue.todayReturn:
        value = ops
            .map((ForexHolding e) => e.gainLossToday)
            .reduce((a, b) => a + b);
        break;
      case DisplayValue.todayReturnPercent:
        var numerator = ops
            .map((ForexHolding e) => e.gainLossPercentToday * e.totalCost)
            .reduce((a, b) => a + b);
        var denominator =
            ops.map((ForexHolding e) => e.totalCost).reduce((a, b) => a + b);
        value = numerator / denominator;
        /*
        value = ops
            .map((OptionAggregatePosition e) =>
                e.changePercentToday * e.marketValue)
            .reduce((a, b) => a + b);
            */
        break;
      case DisplayValue.totalReturn:
        value = ops.map((ForexHolding e) => e.gainLoss).reduce((a, b) => a + b);
        break;
      case DisplayValue.totalReturnPercent:
        var numerator = ops
            .map((ForexHolding e) => e.gainLossPercent * e.totalCost)
            .reduce((a, b) => a + b);
        var denominator =
            ops.map((ForexHolding e) => e.totalCost).reduce((a, b) => a + b);
        value = numerator / denominator;
        /*
        value = ops
            .map((OptionAggregatePosition e) => e.gainLossPercent)
            .reduce((a, b) => a + b);
            */
        break;
      default:
    }
    return value;
  }

  double getCryptoDisplayValue(ForexHolding op) {
    double value = 0;
    switch (widget.user.displayValue) {
      case DisplayValue.lastPrice:
        value = op.quoteObj!.markPrice!;
        break;
      case DisplayValue.marketValue:
        value = op.marketValue;
        break;
      case DisplayValue.todayReturn:
        value = op.gainLossToday;
        break;
      case DisplayValue.todayReturnPercent:
        value = op.gainLossPercentToday;
        break;
      case DisplayValue.totalReturn:
        value = op.gainLoss;
        break;
      case DisplayValue.totalReturnPercent:
        value = op.gainLossPercent;
        break;
      default:
    }
    return value;
  }

  double getPositionDisplayValue(Position op) {
    double value = 0;
    switch (widget.user.displayValue) {
      case DisplayValue.lastPrice:
        value = op.instrumentObj!.quoteObj!.lastExtendedHoursTradePrice ??
            op.instrumentObj!.quoteObj!.lastTradePrice!;
        break;
      case DisplayValue.marketValue:
        value = op.marketValue;
        break;
      case DisplayValue.todayReturn:
        value = op.gainLossToday;
        break;
      case DisplayValue.todayReturnPercent:
        value = op.gainLossPercentToday;
        break;
      case DisplayValue.totalReturn:
        value = op.gainLoss;
        break;
      case DisplayValue.totalReturnPercent:
        value = op.gainLossPercent;
        break;
      default:
    }
    return value;
  }

  Widget _buildCryptoRow(List<ForexHolding> holdings, int index) {
    double value = getCryptoDisplayValue(holdings[index]);
    String trailingText = getDisplayText(value);
    Icon? icon = getDisplayIcon(value);

    return Card(
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      ListTile(
        leading: CircleAvatar(
            radius: 25,
            foregroundColor:
                Theme.of(context).colorScheme.primary, //.onBackground,
            //backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Text(
              holdings[index].currencyCode
              /*.substring(
                          0,
                          positions[index].instrumentObj!.symbol.length < 4
                              ? positions[index].instrumentObj!.symbol.length
                              : 4)*/
              ,
              //style: TextStyle(fontSize: 16.0),
            )), //const SizedBox(width: 40, height: 40),

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
                      widget.user, accounts![0], holdings[index])));
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
  _buildDrawer(RobinhoodUser ru) {
    var drawerOptions = <Widget>[];
    for (var i = 0; i < widget.drawerItems.length; i++) {
      var d = widget.drawerItems[i];
      drawerOptions.add(new ListTile(
        leading: new Icon(d.icon),
        title: new Text(d.title),
        selected: i == _selectedDrawerIndex,
        onTap: () => _onSelectItem(i),
      ));
    }
    return new Drawer(
      child: new ListView(
        padding: EdgeInsets.zero,
        children: ru == null || ru.userName == null
            ? <Widget>[
                new DrawerHeader(
                    child: new Text('Robinhood Options',
                        style:
                            new TextStyle(fontSize: 24.9)),
                    decoration: new BoxDecoration(color: Colors.green)),
                new ListTile(
                    leading: new Icon(Icons.verified_user),
                    title: new Text('Login'),
                    onTap: () => _onSelectItem(0)),
              ]
            : <Widget>[
                new UserAccountsDrawerHeader(
                  accountName: new Text(ru.userName),
                  accountEmail: new Text(ru.userName),
                  currentAccountPicture: new CircleAvatar(
                      backgroundColor: Colors.amber,
                      child: new Text(ru.userName)),
                  otherAccountsPictures: [
                    new GestureDetector(
                      onTap: () => _onTapOtherAccounts(context),
                      child: new Semantics(
                        label: 'Switch Account',
                        child: CircleAvatar(
                          backgroundColor: Colors.lightBlue,
                          child: new Text('SA'),
                        ),
                      ),
                    )
                  ],
                  onDetailsPressed: () {
                    _showDrawerContents = !_showDrawerContents;
                  },
                ),
                new Column(children: drawerOptions),
              ],
      ),
    );
  }

  _onSelectItem(int index) {
    setState(() => {_selectedDrawerIndex = index});
    Navigator.pop(context); // close the drawer
  }

  Widget _getDrawerItemWidget(int pos, RobinhoodUser ru) {
    debugPrint(pos);
    switch (pos) {
      case 0:
        return SizedBox(height: 1000, child: _buildWelcomeWidget(ru));
      case 1:
        return SizedBox(
          height: 2000,
          child: new OptionPositionsWidget(ru),
        );
      //return SingleChildScrollView(child: new OptionPositionsWidget(ru));
      // return Container(child: new OptionPositionsWidget(ru));
      // return LayoutBuilder(
      //  builder: (context, constraints) {
      //    return new OptionPositionsWidget(ru);
      //  },
      //);
      case 2:
        Future.delayed(Duration(milliseconds: 100), () async {
          await Store.deleteFile(Constants.cacheFilename);
          setState(() {
            user = RobinhoodUser.loadUserFromStore();
            _selectedDrawerIndex = 0;
          });
        });
        return new Text("Logged out.");
      // return _openLogin();
      // return new Logout();
      default:
        return new Text("Widget not implemented.");
    }
  }

  _onTapOtherAccounts(BuildContext context) {
    Store.deleteFile(Constants.cacheFilename);

    setState(() {
      user = RobinhoodUser.loadUserFromStore();
      //user = null;
    });

    Navigator.pop(context);
    showDialog(
        context: context,
        builder: (_) {
          return new AlertDialog(
            title: new Text("You are logged out."),
            actions: <Widget>[
              new TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: new Text("OK"),
              )
            ],
          );
        });
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
