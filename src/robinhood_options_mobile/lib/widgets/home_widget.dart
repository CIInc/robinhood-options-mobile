// ignore_for_file: prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
// import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';

//import 'dart:async';
import 'dart:io';
import 'package:open_file/open_file.dart';

import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/holding.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_order.dart';
import 'package:robinhood_options_mobile/model/portfolio.dart';
import 'package:robinhood_options_mobile/model/position.dart';
import 'package:robinhood_options_mobile/model/position_order.dart';
import 'package:robinhood_options_mobile/model/robinhood_user.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/model/watchlist.dart';
import 'package:robinhood_options_mobile/model/watchlist_item.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';
import 'package:robinhood_options_mobile/widgets/login_widget.dart';
import 'package:robinhood_options_mobile/widgets/option_order_widget.dart';
import 'package:robinhood_options_mobile/widgets/persistent_header.dart';
import 'package:robinhood_options_mobile/widgets/position_order_widget.dart';

import 'option_position_widget.dart';

final formatDate = DateFormat("yMMMd");
final formatCompactDate = DateFormat("MMMd");
final formatCurrency = NumberFormat.simpleCurrency();
final formatPercentage = NumberFormat.decimalPercentPattern(decimalDigits: 2);
final formatCompactNumber = NumberFormat.compact();

enum SortType { alphabetical, change }
enum SortDirection { asc, desc }

/*
class DrawerItem {
  String title;
  IconData icon;
  DrawerItem(this.title, this.icon);
}
*/
class HomePage extends StatefulWidget {
  /*
  final drawerItems = [
    new DrawerItem("Home", Icons.home),
    //new DrawerItem("Account", Icons.verified_user),
    new DrawerItem("Options", Icons.library_books),
    new DrawerItem("Logout", Icons.logout),
  ];
  */

  const HomePage({Key? key, this.title}) : super(key: key);

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

class _HomePageState extends State<HomePage> {
  Future<RobinhoodUser>? futureRobinhoodUser;
  RobinhoodUser? robinhoodUser;

  Future<List<Account>>? futureAccounts;
  Future<List<Holding>>? futureNummusHoldings;
  Future<List<Portfolio>>? futurePortfolios;
  //Future<dynamic>? futurePortfolioHistoricals;
  Stream<List<Position>>? positionStream;
  Stream<List<PositionOrder>>? positionOrderStream;

  Stream<List<OptionAggregatePosition>>? optionAggregatePositionStream;
  Stream<List<OptionOrder>>? optionOrderStream;

  List<OptionAggregatePosition> optionAggregatePositions = [];

  List<String> optionOrderSymbols = [];
  List<String> positionOrderSymbols = [];
  List<String> chainSymbols = [];

  final List<String> optionFilters = <String>[];
  final List<String> positionFilters = <String>[];
  final List<String> chainSymbolFilters = <String>[];

  final List<bool> hasQuantityFilters = [true, false];

  final List<String> orderFilters = <String>["placed", "filled"];
  final List<String> orderSymbolFilters = <String>[];
  int orderDateFilterSelected = 1;

  Stream<List<Watchlist>>? watchlistStream;

  SortType? _sortType = SortType.alphabetical;
  SortDirection? _sortDirection = SortDirection.desc;

  Future<User>? futureUser;

/*
  late ScrollController _controller;
  bool silverCollapsed = false;
*/

  // int _selectedDrawerIndex = 0;
  // bool _showDrawerContents = true;

  @override
  void initState() {
    super.initState();

    futureRobinhoodUser = RobinhoodUser.loadUserFromStore();
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      /* Using SliverAppBar below
        appBar: new AppBar(
          title: new Text(widget.drawerItems[_selectedDrawerIndex].title),
        ),
        drawer: new FutureBuilder(
          future: user,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return _buildDrawer(snapshot.data);
            } else if (snapshot.hasError) {
              print("${snapshot.error}");
              return Text("${snapshot.error}");
            }
            // By default, show a loading spinner
            return Center(
              child: LinearProgressIndicator(),
            );
          },
        ),
        */
      body: _buildHomePage(),
      floatingActionButton:
          (robinhoodUser != null && robinhoodUser!.userName != null)
              ? FloatingActionButton(
                  onPressed: _generateCsvFile,
                  tooltip: 'Export to CSV',
                  child: const Icon(Icons.download),
                )
              : null,
    );
  }

  _buildHomePage() {
    return FutureBuilder(
        future: futureRobinhoodUser,
        builder: (context, AsyncSnapshot<RobinhoodUser> userSnapshot) {
          // Can chain new FutureBuilder()'s here

          print("${userSnapshot.connectionState}");
          if (userSnapshot.hasData) {
            robinhoodUser = userSnapshot.data!;
            //print("snapshotUser: ${jsonEncode(snapshotUser)}");

            if (robinhoodUser!.userName != null) {
              futureUser ??= RobinhoodService.getUser(robinhoodUser!);
              futureAccounts ??= RobinhoodService.getAccounts(robinhoodUser!);
              futurePortfolios ??=
                  RobinhoodService.getPortfolios(robinhoodUser!);
              //futureNummusAccounts ??= RobinhoodService.downloadNummusAccounts(snapshotUser);
              futureNummusHoldings ??=
                  RobinhoodService.getNummusHoldings(robinhoodUser!);

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
                    var user = data.isNotEmpty ? data[0] : null;
                    var accounts = data.length > 1 ? data[1] : null;
                    var portfolios = data.length > 2 ? data[2] : null;
                    var nummusHoldings = data.length > 3 ? data[3] : null;

                    positionStream ??=
                        RobinhoodService.streamPositions(robinhoodUser!);

                    return StreamBuilder(
                        stream: positionStream,
                        builder: (context2, positionSnapshot) {
                          if (positionSnapshot.hasData) {
                            var positions =
                                positionSnapshot.data as List<Position>;

                            optionAggregatePositionStream ??= RobinhoodService
                                .streamOptionAggregatePositionList(
                                    robinhoodUser!,
                                    nonzero: hasQuantityFilters[1]);

                            return StreamBuilder<List<OptionAggregatePosition>>(
                                stream: optionAggregatePositionStream,
                                builder: (BuildContext context3,
                                    AsyncSnapshot<List<OptionAggregatePosition>>
                                        optionAggregatePositionSnapshot) {
                                  if (optionAggregatePositionSnapshot.hasData) {
                                    optionAggregatePositions =
                                        optionAggregatePositionSnapshot.data!;

                                    watchlistStream ??=
                                        RobinhoodService.streamLists(
                                            robinhoodUser!);

                                    return StreamBuilder(
                                        stream: watchlistStream,
                                        builder:
                                            (context4, watchlistsSnapshot) {
                                          if (watchlistsSnapshot.hasData) {
                                            List<Watchlist> watchLists =
                                                watchlistsSnapshot.data!
                                                    as List<Watchlist>;
                                            for (var watchList in watchLists) {
                                              if (_sortType ==
                                                  SortType.alphabetical) {
                                                watchList.items.sort((a, b) =>
                                                    (a.instrumentObj!.symbol
                                                        .compareTo(b
                                                            .instrumentObj!
                                                            .symbol)));
                                              } else if (_sortType ==
                                                  SortType.change) {
                                                watchList.items.sort((a, b) => (b
                                                    .instrumentObj!
                                                    .quoteObj!
                                                    .changePercentToday
                                                    .compareTo(a
                                                        .instrumentObj!
                                                        .quoteObj!
                                                        .changePercentToday)));
                                              }
                                            }

                                            optionOrderStream ??=
                                                RobinhoodService
                                                    .streamOptionOrders(
                                                        robinhoodUser!);
                                            return StreamBuilder(
                                                stream: optionOrderStream,
                                                builder: (context5,
                                                    optionOrdersSnapshot) {
                                                  if (optionOrdersSnapshot
                                                      .hasData) {
                                                    var optionOrders =
                                                        optionOrdersSnapshot
                                                                .data
                                                            as List<
                                                                OptionOrder>;

                                                    positionOrderStream ??=
                                                        RobinhoodService
                                                            .streamPositionOrders(
                                                                robinhoodUser!);

                                                    return StreamBuilder(
                                                        stream:
                                                            positionOrderStream,
                                                        builder: (context6,
                                                            positionOrdersSnapshot) {
                                                          if (positionOrdersSnapshot
                                                              .hasData) {
                                                            var positionOrders =
                                                                positionOrdersSnapshot
                                                                        .data
                                                                    as List<
                                                                        PositionOrder>;
                                                            List<Widget>
                                                                slivers =
                                                                _buildSlivers(
                                                                    portfolios:
                                                                        portfolios,
                                                                    user: user,
                                                                    ru:
                                                                        robinhoodUser,
                                                                    accounts:
                                                                        accounts,
                                                                    nummusHoldings:
                                                                        nummusHoldings,
                                                                    optionAggregatePositions:
                                                                        optionAggregatePositions,
                                                                    optionOrders:
                                                                        optionOrders,
                                                                    positions:
                                                                        positions,
                                                                    positionOrders:
                                                                        positionOrders,
                                                                    watchlists:
                                                                        watchLists,
                                                                    //watchListItems:
                                                                    //    watchListItems,
                                                                    done: positionSnapshot.connectionState ==
                                                                            ConnectionState
                                                                                .done &&
                                                                        optionAggregatePositionSnapshot.connectionState ==
                                                                            ConnectionState.done /* &&
                                                            watchlistSnapshot
                                                                    .connectionState ==
                                                                ConnectionState.done*/
                                                                    );
                                                            return RefreshIndicator(
                                                              child: CustomScrollView(
                                                                  slivers:
                                                                      slivers), //controller: _controller,
                                                              onRefresh:
                                                                  _pullRefresh,
                                                            );
                                                          } else if (positionOrdersSnapshot
                                                              .hasError) {
                                                            print(
                                                                "${positionOrdersSnapshot.error}");
                                                            List<Widget>
                                                                slivers =
                                                                _buildSlivers(
                                                                    //ru: snapshotUser,
                                                                    welcomeWidget:
                                                                        Text(
                                                                            "${positionOrdersSnapshot.error}"));
                                                            return RefreshIndicator(
                                                              child: CustomScrollView(
                                                                  slivers:
                                                                      slivers), // controller: _controller,
                                                              onRefresh:
                                                                  _pullRefresh,
                                                            );
                                                          } else {
                                                            // No Position Orders Found.
                                                            List<Widget>
                                                                slivers =
                                                                _buildSlivers(
                                                                    portfolios:
                                                                        portfolios,
                                                                    user: user,
                                                                    ru:
                                                                        robinhoodUser,
                                                                    accounts:
                                                                        accounts,
                                                                    nummusHoldings:
                                                                        nummusHoldings,
                                                                    optionAggregatePositions:
                                                                        optionAggregatePositions,
                                                                    optionOrders:
                                                                        optionOrders,
                                                                    positions:
                                                                        positions,
                                                                    watchlists:
                                                                        watchLists,
                                                                    //watchListItems:
                                                                    //    watchListItems,
                                                                    done: positionSnapshot.connectionState ==
                                                                            ConnectionState
                                                                                .done &&
                                                                        optionAggregatePositionSnapshot.connectionState ==
                                                                            ConnectionState.done /* &&
                                                            watchlistSnapshot
                                                                    .connectionState ==
                                                                ConnectionState.done*/
                                                                    );
                                                            return RefreshIndicator(
                                                              child: CustomScrollView(
                                                                  slivers:
                                                                      slivers), //controller: _controller,
                                                              onRefresh:
                                                                  _pullRefresh,
                                                            );
                                                          }
                                                        });
                                                  } else {
                                                    // No Options Orders found.
                                                    List<Widget> slivers =
                                                        _buildSlivers(
                                                            portfolios:
                                                                portfolios,
                                                            user: user,
                                                            ru: robinhoodUser,
                                                            accounts: accounts,
                                                            nummusHoldings:
                                                                nummusHoldings,
                                                            optionAggregatePositions:
                                                                optionAggregatePositions,
                                                            positions:
                                                                positions,
                                                            watchlists:
                                                                watchLists,
                                                            //watchListItems:
                                                            //    watchListItems,
                                                            done: positionSnapshot
                                                                        .connectionState ==
                                                                    ConnectionState
                                                                        .done &&
                                                                optionAggregatePositionSnapshot
                                                                        .connectionState ==
                                                                    ConnectionState
                                                                        .done /* &&
                                                            watchlistSnapshot
                                                                    .connectionState ==
                                                                ConnectionState.done*/
                                                            );
                                                    return RefreshIndicator(
                                                      child: CustomScrollView(
                                                          slivers:
                                                              slivers), //controller: _controller,
                                                      onRefresh: _pullRefresh,
                                                    );
                                                  }
                                                });
                                          } else if (watchlistsSnapshot
                                              .hasError) {
                                            print(
                                                "${watchlistsSnapshot.error}");
                                            List<Widget> slivers =
                                                _buildSlivers(
                                              welcomeWidget: Text(
                                                  "${watchlistsSnapshot.error}"),
                                              portfolios: portfolios,
                                              user: user,
                                              ru: robinhoodUser,
                                              accounts: accounts,
                                              nummusHoldings: nummusHoldings,
                                              optionAggregatePositions:
                                                  optionAggregatePositions,
                                              positions: positions,
                                            );

                                            return RefreshIndicator(
                                              child: CustomScrollView(
                                                  slivers:
                                                      slivers), // controller: _controller,
                                              onRefresh: _pullRefresh,
                                            );
                                          } else {
                                            // No Watchlists found.
                                            List<Widget> slivers =
                                                _buildSlivers(
                                              portfolios: portfolios,
                                              user: user,
                                              ru: robinhoodUser,
                                              accounts: accounts,
                                              nummusHoldings: nummusHoldings,
                                              optionAggregatePositions:
                                                  optionAggregatePositions,
                                              positions: positions,
                                            );
                                            return RefreshIndicator(
                                              child: CustomScrollView(
                                                  slivers:
                                                      slivers), //controller: _controller,
                                              onRefresh: _pullRefresh,
                                            );
                                          }
                                        });
                                  } else {
                                    // No Options found.
                                    List<Widget> slivers = _buildSlivers(
                                      portfolios: portfolios,
                                      user: user,
                                      ru: robinhoodUser,
                                      accounts: accounts,
                                      nummusHoldings: nummusHoldings,
                                      positions: positions,
                                    );
                                    return RefreshIndicator(
                                      child: CustomScrollView(
                                          slivers:
                                              slivers), // controller: _controller
                                      onRefresh: _pullRefresh,
                                    );
                                  }
                                });
                          } else {
                            // No Positions found.
                            List<Widget> slivers = _buildSlivers(
                                portfolios: portfolios,
                                user: user,
                                ru: robinhoodUser,
                                accounts: accounts,
                                nummusHoldings: nummusHoldings);
                            return RefreshIndicator(
                              child: CustomScrollView(
                                  slivers: slivers), // controller: _controller
                              onRefresh: _pullRefresh,
                            );
                          }
                        });
                  } else if (dataSnapshot.hasError) {
                    print("${dataSnapshot.error}");
                    if (dataSnapshot.error.toString() ==
                        "OAuth authorization error (invalid_grant).") {
                      RobinhoodUser.clearUserFromStore();
                      // Causes: 'package:flutter/src/widgets/navigator.dart': Failed assertion: line 4841 pos 12: '!_debugLocked': is not true.
                      //_openLogin();
                    }
                    List<Widget> slivers = _buildSlivers(
                        //ru: snapshotUser,
                        welcomeWidget: Text("${dataSnapshot.error}"));
                    return RefreshIndicator(
                      child: CustomScrollView(
                          slivers: slivers), // controller: _controller,
                      onRefresh: _pullRefresh,
                    );
                  } else {
                    List<Widget> slivers = _buildSlivers(
                      ru: robinhoodUser,
                    );
                    return RefreshIndicator(
                      child: CustomScrollView(slivers: slivers),
                      onRefresh: _pullRefresh,
                    );
                  }
                },
              );
            } else {
              // No
              List<Widget> slivers = _buildSlivers(
                  ru: robinhoodUser, welcomeWidget: _buildLogin());
              return RefreshIndicator(
                child: CustomScrollView(slivers: slivers),
                onRefresh: _pullRefresh,
              );
            }
          } else if (userSnapshot.hasError) {
            print("userSnapshot.hasError: ${userSnapshot.error}");
            List<Widget> slivers =
                _buildSlivers(welcomeWidget: Text("${userSnapshot.error}"));
            return RefreshIndicator(
              child: CustomScrollView(slivers: slivers),
              onRefresh: _pullRefresh,
            );
          } else {
            List<Widget> slivers = _buildSlivers(
                done: userSnapshot.connectionState == ConnectionState.done);
            return RefreshIndicator(
              child: CustomScrollView(slivers: slivers),
              onRefresh: _pullRefresh,
            );
          }
        });
  }

  List<Widget> _buildSlivers(
      {List<Portfolio>? portfolios,
      User? user,
      RobinhoodUser? ru,
      List<Account>? accounts,
      List<Holding>? nummusHoldings,
      Widget? welcomeWidget,
      List<OptionAggregatePosition>? optionAggregatePositions,
      List<OptionOrder>? optionOrders,
      List<Position>? positions,
      List<PositionOrder>? positionOrders,
      List<Watchlist>? watchlists,
      //List<WatchlistItem>? watchListItems,
      bool done = false}) {
    var slivers = <Widget>[];
    double changeToday = 0;
    double changePercentToday = 0;
    if (portfolios != null) {
      changeToday = portfolios[0].equity! - portfolios[0].equityPreviousClose!;
      changePercentToday = changeToday / portfolios[0].equity!;
    }
    double positionEquity = 0;
    if (positions != null) {
      if (positions.isNotEmpty) {
        positionEquity =
            positions.map((e) => e.marketValue).reduce((a, b) => a + b);
      }
    }
    double nummusEquity = 0;
    if (nummusHoldings != null) {
      nummusEquity = nummusHoldings
          .map((e) => e.value! * e.quantity!)
          .reduce((a, b) => a + b);
    }
    double optionEquity = 0;
    if (optionAggregatePositions != null) {
      optionEquity = optionAggregatePositions
          .map((e) => e.legs.first.positionType == "long"
              ? e.marketValue
              : e.marketValue) // TODO: Match portfolios[0].marketValue (e.totalCost - e.marketValue)
          .reduce((a, b) => a + b);
      chainSymbols =
          optionAggregatePositions.map((e) => e.symbol).toSet().toList();
      chainSymbols.sort((a, b) => (a.compareTo(b)));
    }
    SliverAppBar sliverAppBar = buildSliverAppBar(
        ru,
        portfolios,
        user,
        accounts,
        positionEquity,
        nummusEquity,
        optionEquity,
        changeToday,
        changePercentToday);
    slivers.add(sliverAppBar);

    if (ru != null && ru.userName != null) {
      if (done == false) {
        slivers.add(const SliverToBoxAdapter(
            child: SizedBox(
          // color: Colors.white,
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
      slivers.add(SliverToBoxAdapter(
          child: SizedBox(
        // color: Colors.white,
        height: 25.0,
      )));
      if (welcomeWidget != null) {
        slivers.add(SliverToBoxAdapter(
            child: SizedBox(
          // color: Colors.white,
          height: 150.0,
          child: Align(alignment: Alignment.center, child: welcomeWidget),
        )));
      }
      if (optionAggregatePositions != null) {
        var filteredOptionAggregatePositions = optionAggregatePositions
            .where((element) =>
                (!hasQuantityFilters[0] || element.quantity! > 0) &&
                (!hasQuantityFilters[1] || element.quantity! <= 0) &&
                (positionFilters.isEmpty ||
                    positionFilters
                        .contains(element.legs.first.positionType)) &&
                (optionFilters.isEmpty ||
                    optionFilters.contains(element.legs.first.positionType)) &&
                (chainSymbolFilters.isEmpty ||
                    chainSymbolFilters.contains(element.symbol)))
            .toList();
        /*
                    (chainSymbolFilters.isNotEmpty &&
            !chainSymbolFilters.contains(optionsPositions[index].symbol)) ||
        (positionFilters.isNotEmpty &&
            !positionFilters
                .contains(optionsPositions[index].strategy.split("_").first)) ||
        (optionFilters.isNotEmpty &&
            !optionFilters
                .contains(optionsPositions[index].optionInstrument!.type))) {

            */

        slivers.add(SliverStickyHeader(
          header: Material(
              elevation: 2,
              child: Container(
                  //height: 208.0, //60.0,
                  //color: Colors.blue,
                  color: Colors.white,
                  //padding: EdgeInsets.symmetric(horizontal: 16.0),
                  alignment: Alignment.centerLeft,
                  child: ListTile(
                    title: Text(
                      "Options",
                      style: const TextStyle(
                          //color: Colors.white,
                          fontSize: 19.0),
                    ),
                    subtitle: Text(
                        "${formatCompactNumber.format(filteredOptionAggregatePositions.length)} of ${formatCompactNumber.format(optionAggregatePositions.length)} positions - value: ${formatCurrency.format(optionEquity)}"),
                    trailing: IconButton(
                        icon: const Icon(Icons.filter_list),
                        onPressed: () {
                          showModalBottomSheet<void>(
                            context: context,
                            //constraints: BoxConstraints(maxHeight: 260),
                            builder: (BuildContext context) {
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ListTile(
                                    tileColor: Colors.blue,
                                    title: Text(
                                      "Filter Option Positions",
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 19.0),
                                    ),
                                    /*
                                  trailing: TextButton(
                                      child: const Text("APPLY"),
                                      onPressed: () => Navigator.pop(context))*/
                                  ),
                                  ListTile(
                                    title: Text("Position & Option Type"),
                                  ),
                                  openClosedFilterWidget,
                                  optionTypeFilterWidget,
                                  ListTile(
                                    title: Text("Symbols"),
                                  ),
                                  optionSymbolFilterWidget
                                ],
                              );
                            },
                          );
                        }),
                  ))),
          sliver: SliverList(
            // delegate: SliverChildListDelegate(widgets),
            delegate:
                SliverChildBuilderDelegate((BuildContext context, int index) {
              return _buildOptionPositionRow(
                  filteredOptionAggregatePositions[index], ru);
            }, childCount: filteredOptionAggregatePositions.length),
          ),
        ));
        /*
        slivers.add(
          SliverPersistentHeader(
            pinned: true,
            delegate: PersistentHeader(
                "Options ${formatCurrency.format(optionEquity)}"),
          ),
        );
        // Open/Closed Filters
        slivers.add(SliverToBoxAdapter(child: openClosedFilterWidget));
        // Option/Position Type Filters
        slivers.add(SliverToBoxAdapter(child: optionTypeFilterWidget));
        // Symbol Filters
        slivers.add(SliverToBoxAdapter(child: symbolFilterWidget));
        // Option Positions
        slivers.add(SliverList(
          // delegate: SliverChildListDelegate(widgets),
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              if (optionAggregatePositions.length > index) {
                return _buildOptionPositionRow(
                    optionAggregatePositions, index, ru);
              }
              return null;
            },
          ),
        ));
        */
        slivers.add(SliverToBoxAdapter(
            child: SizedBox(
          // color: Colors.white,
          height: 25.0,
        )));
      }
      if (optionOrders != null) {
        int days = 0;
        switch (orderDateFilterSelected) {
          case 0:
            days = 1;
            break;
          case 1:
            days = 7;
            break;
          case 2:
            days = 30;
            break;
          case 3:
            days = 365;
            break;
          case 4:
            break;
        }
        optionOrderSymbols =
            optionOrders.map((e) => e.chainSymbol).toSet().toList();
        optionOrderSymbols.sort((a, b) => (a.compareTo(b)));

        var filteredOptionOrders = optionOrders
            .where((element) =>
                (orderFilters.isEmpty ||
                    orderFilters.contains(element.state)) &&
                (days == 0 ||
                    element.createdAt!
                            .add(Duration(days: days))
                            .compareTo(DateTime.now()) >=
                        0) &&
                (orderSymbolFilters.isEmpty ||
                    orderSymbolFilters.contains(element.chainSymbol)))
            .toList();
        slivers.add(SliverStickyHeader(
          header: Material(
              elevation: 2,
              child: Container(
                  //height: 208.0, //60.0,
                  //color: Colors.blue,
                  color: Colors.white,
                  //padding: EdgeInsets.symmetric(horizontal: 16.0),
                  alignment: Alignment.centerLeft,
                  child: ListTile(
                    title: Text(
                      "Option Orders",
                      style: const TextStyle(
                          //color: Colors.white,
                          fontSize: 19.0),
                    ),
                    subtitle: Text(
                        "${formatCompactNumber.format(filteredOptionOrders.length)} of ${formatCompactNumber.format(optionOrders.length)} orders ${orderDateFilterSelected == 0 ? "Today" : (orderDateFilterSelected == 1 ? "Past Week" : (orderDateFilterSelected == 2 ? "Past Month" : (orderDateFilterSelected == 3 ? "Past Year" : "")))}"),
                    trailing: IconButton(
                        icon: const Icon(Icons.filter_list),
                        onPressed: () {
                          var future = showModalBottomSheet<void>(
                            context: context,
                            // constraints: BoxConstraints(maxHeight: 260),
                            builder:
                                /*
                          (_) => OptionOrderFilterBottomSheet(
                              orderSymbols: orderSymbols,
                              optionAggregatePositions:
                                  optionAggregatePositions)
                                  */
                                (BuildContext context) {
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ListTile(
                                    tileColor: Colors.blue,
                                    title: Text(
                                      "Filter Option Orders",
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 19.0),
                                    ),
                                    /*
                                  trailing: TextButton(
                                      child: const Text("APPLY"),
                                      onPressed: () => Navigator.pop(context))*/
                                  ),
                                  ListTile(
                                    title: Text("Order State & Date"),
                                  ),
                                  orderFilterWidget,
                                  orderDateFilterWidget,
                                  ListTile(
                                    title: Text("Symbols"),
                                  ),
                                  optionOrderSymbolFilterWidget,
                                ],
                              );
                            },
                          );
                          //future.then((void value) => {});
                        }),
                  ))),
          sliver: SliverList(
            // delegate: SliverChildListDelegate(widgets),
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) {
                return Card(
                    child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ListTile(
                      leading: CircleAvatar(
                          //backgroundImage: AssetImage(user.profilePicture),
                          child: Text(
                              '${filteredOptionOrders[index].quantity!.round()}',
                              style: const TextStyle(fontSize: 18))),
                      title: Text(
                          "${filteredOptionOrders[index].chainSymbol} \$${formatCompactNumber.format(filteredOptionOrders[index].legs.first.strikePrice)} ${filteredOptionOrders[index].strategy} ${formatCompactDate.format(filteredOptionOrders[index].legs.first.expirationDate!)}"), // , style: TextStyle(fontSize: 18.0)),
                      subtitle: Text(
                          "${filteredOptionOrders[index].state} ${dateFormat.format(filteredOptionOrders[index].updatedAt!)}"),
                      trailing: Wrap(spacing: 8, children: [
                        Text(
                          (filteredOptionOrders[index].direction == "credit"
                                  ? "+"
                                  : "-") +
                              "${filteredOptionOrders[index].processedPremium != null ? formatCurrency.format(filteredOptionOrders[index].processedPremium) : ""}",
                          style: const TextStyle(fontSize: 18.0),
                          textAlign: TextAlign.right,
                        )
                      ]),

                      //isThreeLine: true,
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => OptionOrderWidget(
                                    ru, filteredOptionOrders[index])));
                      },
                    ),
                  ],
                ));
              },
              childCount: filteredOptionOrders.length,
            ),
          ),
        ));
        slivers.add(SliverToBoxAdapter(
            child: SizedBox(
          // color: Colors.white,
          height: 25.0,
        )));
      }
      if (positions != null) {
        var filteredPositions = positions
            .where((element) =>
                (!hasQuantityFilters[0] || element.quantity! > 0) &&
                (!hasQuantityFilters[1] || element.quantity! <= 0))
            .toList();

        slivers.add(SliverStickyHeader(
            header: Material(
                elevation: 2,
                child: Container(
                    //height: 208.0, //60.0,
                    //color: Colors.blue,
                    color: Colors.white,
                    //padding: EdgeInsets.symmetric(horizontal: 16.0),
                    alignment: Alignment.centerLeft,
                    child: ListTile(
                      title: Text(
                        "Stocks",
                        style: const TextStyle(
                            //color: Colors.white,
                            fontSize: 19.0),
                      ),
                      subtitle: Text(
                          "${formatCompactNumber.format(filteredPositions.length)} of ${formatCompactNumber.format(positions.length)} positions - value: ${formatCurrency.format(positionEquity)}"),
                      trailing: IconButton(
                          icon: const Icon(Icons.filter_list),
                          onPressed: () {
                            showModalBottomSheet<void>(
                              context: context,
                              //constraints: BoxConstraints(maxHeight: 260),
                              builder: (BuildContext context) {
                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ListTile(
                                      tileColor: Colors.blue,
                                      title: Text(
                                        "Filter Stock Positions",
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 19.0),
                                      ),
                                      /*
                                  trailing: TextButton(
                                      child: const Text("APPLY"),
                                      onPressed: () => Navigator.pop(context))*/
                                    ),
                                    ListTile(
                                      title: Text("Position Type"),
                                    ),
                                    positionTypeFilterWidget,
                                  ],
                                );
                              },
                            );
                          }),
                    ))),
/*
            header: Container(
                //height: 208.0, //60.0,
                //color: Colors.blue,
                color: Colors.white,
                //padding: EdgeInsets.symmetric(horizontal: 16.0),
                alignment: Alignment.centerLeft,
                child: Column(
                  children: [
                    Container(
                        //height: 40,
                        padding: EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 12.0),
                        //padding: const EdgeInsets.all(4.0), //EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          "Positions ${formatCurrency.format(positionEquity)}",
                          style: const TextStyle(
                              //color: Colors.white,
                              fontSize: 19.0),
                        )),
                  ],
                )),
                */
            sliver: SliverList(
              // delegate: SliverChildListDelegate(widgets),
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) {
                  return _buildPositionRow(positions, index, ru);
                },
                // Or, uncomment the following line:
                childCount: filteredPositions.length,
              ),
            )));
        /*
        slivers.add(
          SliverPersistentHeader(
            pinned: true,
            delegate: PersistentHeader(
                "Positions ${formatCurrency.format(positionEquity)}"),
          ),
        );
        slivers.add(SliverList(
          // delegate: SliverChildListDelegate(widgets),
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              if (positions.length > index) {
                return _buildPositionRow(positions, index, ru);
              }
              return null;
              // To convert this infinite list to a list with three items,
              // uncomment the following line:
              // if (index > 3) return null;
            },
            // Or, uncomment the following line:
            // childCount: widgets.length + 10,
          ),
        ));
        */
        slivers.add(SliverToBoxAdapter(
            child: SizedBox(
          // color: Colors.white,
          height: 25.0,
        )));
      }
      if (positionOrders != null) {
        int days = 0;
        switch (orderDateFilterSelected) {
          case 0:
            days = 1;
            break;
          case 1:
            days = 7;
            break;
          case 2:
            days = 30;
            break;
          case 3:
            days = 365;
            break;
          case 4:
            break;
        }
        positionOrderSymbols =
            []; // TODO, map symbol, only instrumentId is available on PositionOrder
        //positionOrders.map((e) => e.instrumentId).toSet().toList();
        positionOrderSymbols.sort((a, b) => (a.compareTo(b)));

        var filteredPositionOrders = positionOrders
            .where((element) =>
                (orderFilters.isEmpty ||
                    orderFilters.contains(element.state)) &&
                (days == 0 ||
                    element.createdAt!
                            .add(Duration(days: days))
                            .compareTo(DateTime.now()) >=
                        0) &&
                (orderSymbolFilters.isEmpty ||
                    orderSymbolFilters.contains(element.instrumentId)))
            .toList();
        slivers.add(SliverStickyHeader(
          header: Material(
              elevation: 2,
              child: Container(
                  //height: 208.0, //60.0,
                  //color: Colors.blue,
                  color: Colors.white,
                  //padding: EdgeInsets.symmetric(horizontal: 16.0),
                  alignment: Alignment.centerLeft,
                  child: ListTile(
                    title: Text(
                      "Stock Orders",
                      style: const TextStyle(
                          //color: Colors.white,
                          fontSize: 19.0),
                    ),
                    subtitle: Text(
                        "${formatCompactNumber.format(filteredPositionOrders.length)} of ${formatCompactNumber.format(positionOrders.length)} orders ${orderDateFilterSelected == 0 ? "Today" : (orderDateFilterSelected == 1 ? "Past Week" : (orderDateFilterSelected == 2 ? "Past Month" : (orderDateFilterSelected == 3 ? "Past Year" : "")))}"),
                    trailing: IconButton(
                        icon: const Icon(Icons.filter_list),
                        onPressed: () {
                          var future = showModalBottomSheet<void>(
                            context: context,
                            // constraints: BoxConstraints(maxHeight: 260),
                            builder:
                                /*
                          (_) => OptionOrderFilterBottomSheet(
                              orderSymbols: orderSymbols,
                              optionAggregatePositions:
                                  optionAggregatePositions)
                                  */
                                (BuildContext context) {
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ListTile(
                                    tileColor: Colors.blue,
                                    title: Text(
                                      "Filter Position Orders",
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 19.0),
                                    ),
                                    /*
                                  trailing: TextButton(
                                      child: const Text("APPLY"),
                                      onPressed: () => Navigator.pop(context))*/
                                  ),
                                  ListTile(
                                    title: Text("Order State & Date"),
                                  ),
                                  orderFilterWidget,
                                  orderDateFilterWidget,
                                  ListTile(
                                    title: Text("Symbols"),
                                  ),
                                  positionOrderSymbolFilterWidget,
                                ],
                              );
                            },
                          );
                          //future.then((void value) => {});
                        }),
                  ))),
          sliver: SliverList(
            // delegate: SliverChildListDelegate(widgets),
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) {
                return Card(
                    child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ListTile(
                      leading: CircleAvatar(
                          //backgroundImage: AssetImage(user.profilePicture),
                          child: Text(
                              '${filteredPositionOrders[index].quantity!.round()}',
                              style: const TextStyle(fontSize: 18))),
                      title: Text(
                          "${filteredPositionOrders[index].instrumentId} ${filteredPositionOrders[index].averagePrice != null ? formatCurrency.format(filteredPositionOrders[index].averagePrice) : ""} ${filteredPositionOrders[index].type} ${filteredPositionOrders[index].side}"),
                      subtitle: Text(
                          "${filteredPositionOrders[index].state} ${dateFormat.format(filteredPositionOrders[index].updatedAt!)}"),
                      trailing: Wrap(spacing: 8, children: [
                        Text(
                          "${filteredPositionOrders[index].averagePrice != null ? formatCurrency.format(filteredPositionOrders[index].averagePrice! * filteredPositionOrders[index].quantity!) : ""}",
                          style: const TextStyle(fontSize: 18.0),
                          textAlign: TextAlign.right,
                        )
                      ]),

                      //isThreeLine: true,
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => PositionOrderWidget(
                                    ru, filteredPositionOrders[index])));
                      },
                    ),
                  ],
                ));
              },
              childCount: filteredPositionOrders.length,
            ),
          ),
        ));
        slivers.add(SliverToBoxAdapter(
            child: SizedBox(
          // color: Colors.white,
          height: 25.0,
        )));
      }
      if (watchlists != null) {
        slivers.add(SliverStickyHeader(
            header: Material(
                elevation: 2,
                child: Container(
                    //height: 208.0, //60.0,
                    //color: Colors.blue,
                    color: Colors.white,
                    //padding: EdgeInsets.symmetric(horizontal: 16.0),
                    alignment: Alignment.centerLeft,
                    child: ListTile(
                      title: Text(
                        "Lists",
                        style: const TextStyle(
                            //color: Colors.white,
                            fontSize: 19.0),
                      ),
                      subtitle: Text(
                          "${formatCompactNumber.format(watchlists.length)} items"),
                      trailing: IconButton(
                          icon: const Icon(Icons.sort),
                          onPressed: () {
                            showModalBottomSheet<void>(
                              context: context,
                              //constraints: BoxConstraints(maxHeight: 260),
                              builder: (BuildContext context) {
                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ListTile(
                                      tileColor: Colors.blue,
                                      title: Text(
                                        "Sort Watch List",
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 19.0),
                                      ),
                                      /*
                                  trailing: TextButton(
                                      child: const Text("APPLY"),
                                      onPressed: () => Navigator.pop(context))*/
                                    ),
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        RadioListTile<SortType>(
                                          title: const Text(
                                              'Alphabetical (Ascending)'),
                                          value: SortType.alphabetical,
                                          groupValue: _sortType,
                                          onChanged: (SortType? value) {
                                            Navigator.pop(context);
                                            setState(() {
                                              _sortType = value;
                                              _sortDirection =
                                                  SortDirection.asc;
                                            });
                                          },
                                        ),
                                        RadioListTile<SortType>(
                                          title: const Text(
                                              'Alphabetical (Descending)'),
                                          value: SortType.alphabetical,
                                          groupValue: _sortType,
                                          onChanged: (SortType? value) {
                                            Navigator.pop(context);
                                            setState(() {
                                              _sortType = value;
                                              _sortDirection =
                                                  SortDirection.desc;
                                            });
                                          },
                                        ),
                                        RadioListTile<SortType>(
                                          title:
                                              const Text('Change (Ascending)'),
                                          value: SortType.change,
                                          groupValue: _sortType,
                                          onChanged: (SortType? value) {
                                            Navigator.pop(context);
                                            setState(() {
                                              _sortType = value;
                                              _sortDirection =
                                                  SortDirection.asc;
                                            });
                                          },
                                        ),
                                        RadioListTile<SortType>(
                                          title:
                                              const Text('Change (Descending)'),
                                          value: SortType.change,
                                          groupValue: _sortType,
                                          onChanged: (SortType? value) {
                                            Navigator.pop(context);
                                            setState(() {
                                              _sortType = value;
                                              _sortDirection =
                                                  SortDirection.desc;
                                            });
                                          },
                                        ),
                                      ],
                                    )
                                  ],
                                );
                              },
                            );
                          }),
                    ))),
            sliver: SliverToBoxAdapter(child: Container())));

        for (var watchlist in watchlists) {
          slivers.add(SliverStickyHeader(
              header: Material(
                  elevation: 2,
                  child: Container(
                      //height: 208.0, //60.0,
                      //color: Colors.blue,
                      color: Colors.white,
                      //padding: EdgeInsets.symmetric(horizontal: 16.0),
                      alignment: Alignment.centerLeft,
                      child: ListTile(
                        title: Text(
                          "${watchlist.displayName}",
                          style: const TextStyle(
                              //color: Colors.white,
                              fontSize: 19.0),
                        ),
                        subtitle: Text(
                            "${formatCompactNumber.format(watchlist.items.length)} items"),
                        trailing: IconButton(
                            icon: const Icon(Icons.sort),
                            onPressed: () {
                              showModalBottomSheet<void>(
                                context: context,
                                constraints: BoxConstraints(maxHeight: 260),
                                builder: (BuildContext context) {
                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ListTile(
                                        tileColor: Colors.blue,
                                        title: Text(
                                          "Sort Watch List",
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 19.0),
                                        ),
                                        //trailing: TextButton(
                                        //    child: const Text("APPLY"),
                                        //    onPressed: () => Navigator.pop(context))
                                      ),
                                      Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          RadioListTile<SortType>(
                                            title: const Text('Alphabetical'),
                                            value: SortType.alphabetical,
                                            groupValue: _sortType,
                                            onChanged: (SortType? value) {
                                              Navigator.pop(context);
                                              setState(() {
                                                _sortType = value;
                                              });
                                            },
                                          ),
                                          RadioListTile<SortType>(
                                            title: const Text('Change'),
                                            value: SortType.change,
                                            groupValue: _sortType,
                                            onChanged: (SortType? value) {
                                              Navigator.pop(context);
                                              setState(() {
                                                _sortType = value;
                                              });
                                            },
                                          ),
                                        ],
                                      )
                                    ],
                                  );
                                },
                              );
                            }),
                      ))),
              sliver: watchListWidget(watchlist.items)));
        }
        slivers.add(SliverToBoxAdapter(
            child: SizedBox(
          // color: Colors.white,
          height: 25.0,
        )));
      }
      /*
      if (watchListItems != null) {
        slivers.add(SliverStickyHeader(
            header: Container(
                //height: 208.0, //60.0,
                //color: Colors.blue,
                color: Colors.white,
                //padding: EdgeInsets.symmetric(horizontal: 16.0),
                alignment: Alignment.centerLeft,
                child: ListTile(
                  title: Text(
                    "Watch List",
                    style: const TextStyle(
                        //color: Colors.white,
                        fontSize: 19.0),
                  ),
                  subtitle: Text(
                      "${formatCompactNumber.format(watchListItems.length)} items"),
                  trailing: IconButton(
                      icon: const Icon(Icons.sort),
                      onPressed: () {
                        showModalBottomSheet<void>(
                          context: context,
                          constraints: BoxConstraints(maxHeight: 260),
                          builder: (BuildContext context) {
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ListTile(
                                  tileColor: Colors.blue,
                                  title: Text(
                                    "Sort Watch List",
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 19.0),
                                  ),
                                  /*
                                  trailing: TextButton(
                                      child: const Text("APPLY"),
                                      onPressed: () => Navigator.pop(context))*/
                                ),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    RadioListTile<SortType>(
                                      title: const Text('Alphabetical'),
                                      value: SortType.alphabetical,
                                      groupValue: _sortType,
                                      onChanged: (SortType? value) {
                                        Navigator.pop(context);
                                        setState(() {
                                          _sortType = value;
                                        });
                                      },
                                    ),
                                    RadioListTile<SortType>(
                                      title: const Text('Change'),
                                      value: SortType.change,
                                      groupValue: _sortType,
                                      onChanged: (SortType? value) {
                                        Navigator.pop(context);
                                        setState(() {
                                          _sortType = value;
                                        });
                                      },
                                    ),
                                  ],
                                )
                              ],
                            );
                          },
                        );
                      }),
                )),
            sliver: watchListWidget(watchListItems)));
        slivers.add(SliverToBoxAdapter(
            child: SizedBox(
          // color: Colors.white,
          height: 25.0,
        )));
      }
      */
      if (accounts != null) {
        slivers.add(SliverStickyHeader(
            header: Material(
                elevation: 2.0,
                child: Container(
                  //height: 208.0, //60.0,
                  //color: Colors.blue,
                  color: Colors.white,
                  //padding: EdgeInsets.symmetric(horizontal: 16.0),
                  alignment: Alignment.centerLeft,
                  child: ListTile(
                    title: Text(
                      "Accounts",
                      style: const TextStyle(
                          //color: Colors.white,
                          fontSize: 19.0),
                    ),
                  ),
                )),
            /*
            header: Container(
                //height: 208.0, //60.0,
                //color: Colors.blue,
                color: Colors.white,
                //padding: EdgeInsets.symmetric(horizontal: 16.0),
                alignment: Alignment.centerLeft,
                child: Column(
                  children: [
                    Container(
                        //height: 40,
                        padding: const EdgeInsets.all(12.0),
                        child: Text(
                          "Accounts",
                          style: const TextStyle(
                              //color: Colors.white,
                              fontSize: 19.0),
                        )),
                  ],
                )),
                */
            sliver: SliverToBoxAdapter(
                child: Card(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: accountWidgets(accounts).toList())))));
        /*        
        slivers.add(SliverPersistentHeader(
          pinned: true,
          delegate: PersistentHeader(
              "Accounts ${formatCurrency.format(accounts[0].portfolioCash)}"),
        ));
        slivers.add(SliverToBoxAdapter(
            child: Card(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: accountWidgets(accounts).toList()))));
                    */
        slivers.add(SliverToBoxAdapter(
            child: SizedBox(
          // color: Colors.white,
          height: 25.0,
        )));
      }
    }
    if (portfolios != null) {
      slivers.add(SliverStickyHeader(
          header: Material(
              elevation: 2.0,
              child: Container(
                //height: 208.0, //60.0,
                //color: Colors.blue,
                color: Colors.white,
                //padding: EdgeInsets.symmetric(horizontal: 16.0),
                alignment: Alignment.centerLeft,
                child: ListTile(
                  title: Text(
                    "Portfolios",
                    style: const TextStyle(
                        //color: Colors.white,
                        fontSize: 19.0),
                  ),
                ),
              )),
/*
          header: Container(
              //height: 208.0, //60.0,
              //color: Colors.blue,
              color: Colors.white,
              //padding: EdgeInsets.symmetric(horizontal: 16.0),
              alignment: Alignment.centerLeft,
              child: Column(
                children: [
                  Container(
                      //height: 40,
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        'Portfolios',
                        style: const TextStyle(
                            //color: Colors.white,
                            fontSize: 19.0),
                      )),
                ],
              )),
              */
          sliver: portfoliosWidget(portfolios)));
      /*
      slivers.add(
        SliverPersistentHeader(
          pinned: false,
          delegate: PersistentHeader("Portfolios"),
        ),
      );
      slivers.add(portfoliosWidget(portfolios));
      */
      slivers.add(SliverToBoxAdapter(
          child: SizedBox(
        // color: Colors.white,
        height: 25.0,
      )));
    }
    if (user != null) {
      slivers.add(SliverStickyHeader(
          header: Material(
              elevation: 2.0,
              child: Container(
                //height: 208.0, //60.0,
                //color: Colors.blue,
                color: Colors.white,
                //padding: EdgeInsets.symmetric(horizontal: 16.0),
                alignment: Alignment.centerLeft,
                child: ListTile(
                  title: Text(
                    "User",
                    style: const TextStyle(
                        //color: Colors.white,
                        fontSize: 19.0),
                  ),
                ),
              )),
          sliver: userWidget(user)));
      slivers.add(SliverToBoxAdapter(
          child: SizedBox(
        // color: Colors.white,
        height: 25.0,
      )));
    }
    slivers.add(SliverStickyHeader(
        header: Material(
            elevation: 2.0,
            child: Container(
                //height: 208.0, //60.0,
                //color: Colors.blue,
                color: Colors.white,
                //padding: EdgeInsets.symmetric(horizontal: 16.0),
                alignment: Alignment.centerLeft,
                child:
                    null /*ListTile(
                title: Text(
                  "Disclaimer",
                  style: const TextStyle(
                      //color: Colors.white,
                      fontSize: 19.0),
                ),
              ),*/
                )),
        /*
        header: Container(
            //height: 208.0, //60.0,
            //color: Colors.blue,
            color: Colors.white,
            //padding: EdgeInsets.symmetric(horizontal: 16.0),
            alignment: Alignment.centerLeft,
            child: Column(
              children: [
                Container(
                    //height: 40,
                    padding: const EdgeInsets.all(12.0),
                    child: Text(
                      'Disclaimer',
                      style: const TextStyle(
                          //color: Colors.white,
                          fontSize: 19.0),
                    )),
              ],
            )),
            */
        sliver: SliverToBoxAdapter(
            child: Container(
                color: Colors.white,
                //height: 420.0,
                padding: const EdgeInsets.all(12.0),
                child: const Align(
                    alignment: Alignment.center,
                    child: Text(
                        "Robinhood Options is not a registered investment, legal or tax advisor or a broker/dealer. All investment/financial opinions expressed by Robinhood Options are intended  as educational material.\n\n Lorem ipsum dolor sit amet, consectetur adipiscing elit. Duis sit amet lectus velit. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia curae; Nam eget dolor quis eros vulputate pharetra. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Maecenas porttitor augue ipsum, non mattis lorem commodo eu. Vivamus tellus lorem, rhoncus vel fermentum et, pharetra at sapien. Donec non auctor augue. Cras ante metus, commodo ornare augue at, commodo pellentesque risus. Donec laoreet iaculis orci, eu suscipit enim vehicula ut. Aliquam at erat sit amet diam fringilla fermentum vel eget massa. Duis nec mi dolor.\n\nMauris porta ac libero in vestibulum. Vivamus vestibulum, nibh ut dignissim aliquet, arcu elit tempor urna, in vehicula diam ante ut lacus. Donec vehicula ullamcorper orci, ac facilisis nibh fermentum id. Aliquam nec erat at mi tristique vestibulum ac quis sapien. Donec a auctor sem, sed sollicitudin nunc. Sed bibendum rhoncus nisl. Donec eu accumsan quam. Praesent iaculis fermentum tortor sit amet varius. Nam a dui et mauris commodo porta. Nam egestas molestie quam eu commodo. Proin nec justo neque."))))));
    /*
    slivers.add(SliverPersistentHeader(
      // pinned: true,
      delegate: PersistentHeader("Disclaimer"),
    ));
    slivers.add(SliverToBoxAdapter(
        child: Container(
            color: Colors.white,
            height: 420.0,
            child: const Align(
                alignment: Alignment.center,
                child: Text(
                    "Robinhood Options is not a registered investment, legal or tax advisor or a broker/dealer. All investment/financial opinions expressed by Robinhood Options are intended  as educational material.\n\n Lorem ipsum dolor sit amet, consectetur adipiscing elit. Duis sit amet lectus velit. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia curae; Nam eget dolor quis eros vulputate pharetra. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Maecenas porttitor augue ipsum, non mattis lorem commodo eu. Vivamus tellus lorem, rhoncus vel fermentum et, pharetra at sapien. Donec non auctor augue. Cras ante metus, commodo ornare augue at, commodo pellentesque risus. Donec laoreet iaculis orci, eu suscipit enim vehicula ut. Aliquam at erat sit amet diam fringilla fermentum vel eget massa. Duis nec mi dolor.\n\nMauris porta ac libero in vestibulum. Vivamus vestibulum, nibh ut dignissim aliquet, arcu elit tempor urna, in vehicula diam ante ut lacus. Donec vehicula ullamcorper orci, ac facilisis nibh fermentum id. Aliquam nec erat at mi tristique vestibulum ac quis sapien. Donec a auctor sem, sed sollicitudin nunc. Sed bibendum rhoncus nisl. Donec eu accumsan quam. Praesent iaculis fermentum tortor sit amet varius. Nam a dui et mauris commodo porta. Nam egestas molestie quam eu commodo. Proin nec justo neque.")))));
                    */
    slivers.add(SliverToBoxAdapter(
        child: SizedBox(
      // color: Colors.white,
      height: 25.0,
    )));

    return slivers;
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
              ListTile(
                title: const Text("Url", style: TextStyle(fontSize: 14)),
                trailing: Text(portfolios[index].url,
                    style: const TextStyle(fontSize: 14)),
              ),
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
        trailing: Text(dateFormat.format(user.createdAt!),
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
              return _buildWatchlistGridItem(watchLists, index, robinhoodUser!);
              /*
          return Container(
            alignment: Alignment.center,
            color: Colors.teal[100 * (index % 9)],
            child: Text('grid item $index'),
          );
          */
            },
            childCount: watchLists.length,
          ),
        ));
    /*
    return SliverList(
      // delegate: SliverChildListDelegate(widgets),
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) {
          if (watchLists.length > index) {
            return _buildWatchlistRow(watchLists, index, robinhoodUser!);
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
    */
  }

  Widget symbolWidgets(List<Widget> widgets) {
    var n = 3; // 4;
    if (widgets.length < 8) {
      n = 1;
    } else if (widgets.length < 12) {
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

  Widget get optionSymbolFilterWidget {
    var widgets =
        optionSymbolFilterWidgets(chainSymbols, optionAggregatePositions)
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

  Iterable<Widget> optionSymbolFilterWidgets(
      List<String> chainSymbols, List<OptionAggregatePosition> options) sync* {
    for (final String chainSymbol in chainSymbols) {
      yield Padding(
        padding: const EdgeInsets.all(4.0),
        child: FilterChip(
          // avatar: CircleAvatar(child: Text(contractCount.toString())),
          label: Text(chainSymbol),
          selected: chainSymbolFilters.contains(chainSymbol),
          onSelected: (bool value) {
            setState(() {
              if (value) {
                chainSymbolFilters.add(chainSymbol);
              } else {
                chainSymbolFilters.removeWhere((String name) {
                  return name == chainSymbol;
                });
              }
            });
          },
        ),
      );
    }
  }

  Widget get openClosedFilterWidget {
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
                    setState(() {
                      if (value) {
                        hasQuantityFilters[0] = true;
                      } else {
                        hasQuantityFilters[0] = false;
                      }
                    });
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
                    setState(() {
                      if (value) {
                        hasQuantityFilters[1] = true;
                      } else {
                        hasQuantityFilters[1] = false;
                      }
                      optionAggregatePositionStream = null;
                    });
                  },
                ),
              ),
              /*
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: FilterChip(
                  //avatar: const Icon(Icons.history_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('Long'),
                  selected: positionFilters.contains("long"),
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        positionFilters.add("long");
                      } else {
                        positionFilters.removeWhere((String name) {
                          return name == "long";
                        });
                      }
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: FilterChip(
                  //avatar: const Icon(Icons.history_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('Short'),
                  selected: positionFilters.contains("short"),
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        positionFilters.add("short");
                      } else {
                        positionFilters.removeWhere((String name) {
                          return name == "short";
                        });
                      }
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: FilterChip(
                  //avatar: const Icon(Icons.history_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('Call'),
                  selected: optionFilters.contains("call"),
                  //selected: optionFilters[0],
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        optionFilters.add("call");
                      } else {
                        optionFilters.removeWhere((String name) {
                          return name == "call";
                        });
                      }
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: FilterChip(
                  //avatar: const Icon(Icons.history_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('Put'),
                  selected: optionFilters.contains("put"),
                  //selected: optionFilters[1],
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        optionFilters.add("put");
                      } else {
                        optionFilters.removeWhere((String name) {
                          return name == "put";
                        });
                      }
                    });
                  },
                ),
              )
              */
            ]);
          },
          itemCount: 1,
        ));
  }

  Widget get optionTypeFilterWidget {
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
                      setState(() {
                        if (value) {
                          positionFilters.add("long");
                        } else {
                          positionFilters.removeWhere((String name) {
                            return name == "long";
                          });
                        }
                      });
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
                      setState(() {
                        if (value) {
                          positionFilters.add("short");
                        } else {
                          positionFilters.removeWhere((String name) {
                            return name == "short";
                          });
                        }
                      });
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
                      setState(() {
                        if (value) {
                          optionFilters.add("call");
                        } else {
                          optionFilters.removeWhere((String name) {
                            return name == "call";
                          });
                        }
                      });
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
                      setState(() {
                        if (value) {
                          optionFilters.add("put");
                        } else {
                          optionFilters.removeWhere((String name) {
                            return name == "put";
                          });
                        }
                      });
                    },
                  ),
                )
              ],
            );
          },
          itemCount: 1,
        ));
  }

  Widget get positionTypeFilterWidget {
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
                    setState(() {
                      if (value) {
                        hasQuantityFilters[0] = true;
                      } else {
                        hasQuantityFilters[0] = false;
                      }
                    });
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
                    setState(() {
                      if (value) {
                        hasQuantityFilters[1] = true;
                      } else {
                        hasQuantityFilters[1] = false;
                      }
                      optionAggregatePositionStream = null;
                    });
                  },
                ),
              ),
            ]);
          },
          itemCount: 1,
        ));
  }

  Widget get orderFilterWidget {
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
                  //avatar: const Icon(Icons.history_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('Placed'),
                  selected: orderFilters.contains("placed"),
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        orderFilters.add("placed");
                      } else {
                        orderFilters.removeWhere((String name) {
                          return name == "placed";
                        });
                      }
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: FilterChip(
                  //avatar: const Icon(Icons.history_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('Filled'),
                  selected: orderFilters.contains("filled"),
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        orderFilters.add("filled");
                      } else {
                        orderFilters.removeWhere((String name) {
                          return name == "filled";
                        });
                      }
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: FilterChip(
                  //avatar: const Icon(Icons.history_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('Cancelled'),
                  selected: orderFilters.contains("cancelled"),
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        orderFilters.add("cancelled");
                      } else {
                        orderFilters.removeWhere((String name) {
                          return name == "cancelled";
                        });
                      }
                    });
                  },
                ),
              ),
            ]);
          },
          itemCount: 1,
        ));
  }

  Widget get optionOrderSymbolFilterWidget {
    var widgets = orderSymbolFilterWidgets(optionOrderSymbols).toList();
    return symbolWidgets(widgets);
  }

  Widget get positionOrderSymbolFilterWidget {
    var widgets = orderSymbolFilterWidgets(positionOrderSymbols).toList();
    return symbolWidgets(widgets);
  }

  Widget get orderDateFilterWidget {
    return SizedBox(
        height: 56,
        child: ListView.builder(
          padding: const EdgeInsets.all(4.0),
          scrollDirection: Axis.horizontal,
          itemBuilder: (context, index) {
            return Row(children: [
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: ChoiceChip(
                  //avatar: const Icon(Icons.history_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('Today'),
                  selected: orderDateFilterSelected == 0,
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        orderDateFilterSelected = 0;
                      } else {
                        //dateFilterSelected = null;
                      }
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: ChoiceChip(
                  //avatar: const Icon(Icons.history_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('Past Week'),
                  selected: orderDateFilterSelected == 1,
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        orderDateFilterSelected = 1;
                      } else {
                        //dateFilterSelected = null;
                      }
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: ChoiceChip(
                  //avatar: const Icon(Icons.history_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('Past Month'),
                  selected: orderDateFilterSelected == 2,
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        orderDateFilterSelected = 2;
                      } else {}
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: ChoiceChip(
                  //avatar: const Icon(Icons.history_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('Past Year'),
                  selected: orderDateFilterSelected == 3,
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        orderDateFilterSelected = 3;
                      } else {}
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: ChoiceChip(
                  //avatar: const Icon(Icons.history_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('All Time'),
                  selected: orderDateFilterSelected == 4,
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        orderDateFilterSelected = 4;
                      } else {}
                    });
                  },
                ),
              ),
            ]);
          },
          itemCount: 1,
        ));
  }

  Iterable<Widget> orderSymbolFilterWidgets(List<String> chainSymbols) sync* {
    for (final String chainSymbol in chainSymbols) {
      yield Padding(
        padding: const EdgeInsets.all(4.0),
        child: FilterChip(
          // avatar: CircleAvatar(child: Text(contractCount.toString())),
          label: Text(chainSymbol),
          selected: orderSymbolFilters.contains(chainSymbol),
          onSelected: (bool value) {
            setState(() {
              if (value) {
                orderSymbolFilters.add(chainSymbol);
              } else {
                orderSymbolFilters.removeWhere((String name) {
                  return name == chainSymbol;
                });
              }
            });
          },
        ),
      );
    }
  }

  SliverAppBar buildSliverAppBar(
      RobinhoodUser? ru,
      List<Portfolio>? portfolios,
      User? user,
      List<Account>? accounts,
      double positionEquity,
      double nummusEquity,
      double optionEquity,
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
      expandedHeight: 300.0,
      // collapsedHeight: 80.0,
      /*
                      bottom: PreferredSize(
                        child: Icon(Icons.linear_scale, size: 60.0),
                        preferredSize: Size.fromHeight(50.0))
                        */
      floating: false,
      pinned: true,
      snap: false,
      /*
      title: silverCollapsed && user != null && portfolios != null
          ? getAppBarTitle(user, changeToday, changePercentToday)
          : Container(),
          */
      flexibleSpace: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
        if (ru == null || ru.userName == null || portfolios == null) {
          return const FlexibleSpaceBar(title: Text('Robinhood Options'));
        } /* else if (silverCollapsed) {
          return Container();
        }*/
        var portfolioValue = (portfolios[0].equity ?? 0) + nummusEquity;
        var stockAndOptionsEquityPercent =
            portfolios[0].marketValue! / portfolioValue;
        var optionEquityPercent = optionEquity / portfolioValue;
        var positionEquityPercent = positionEquity / portfolioValue;
        var portfolioCash = accounts![0].portfolioCash ?? 0;
        var cashPercent = portfolioCash / portfolioValue;
        var cryptoPercent = nummusEquity / portfolioValue;
        return FlexibleSpaceBar(
            background: const FlutterLogo(),
            title: SingleChildScrollView(
              child: Column(//mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                Row(children: [const SizedBox(height: 65)]),
                //Row(children: [const Text('')]),
                //Row(children: [const Text('')]),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(user!.profileName,
                        style: const TextStyle(fontSize: 24.0)),
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
                      Wrap(
                        children: [
                          Icon(
                              changeToday > 0
                                  ? Icons.trending_up
                                  : (changeToday < 0
                                      ? Icons.trending_down
                                      : Icons.trending_flat),
                              color: (changeToday > 0
                                  ? Colors.lightGreenAccent
                                  : (changeToday < 0
                                      ? Colors.red
                                      : Colors.grey)),
                              size: 16.0),
                          Container(
                            width: 2,
                          ),
                          Text(
                              '${formatPercentage.format(changePercentToday.abs())}',
                              style: const TextStyle(fontSize: 16.0)),
                          Container(
                            width: 10,
                          ),
                          Text(
                              "${changeToday > 0 ? "+" : changeToday < 0 ? "-" : ""}${formatCurrency.format(changeToday.abs())}",
                              style: const TextStyle(fontSize: 16.0)),
                          Container(
                            width: 10,
                          ),
                        ],
                      ),
                    ]),
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
                        children: [
                          const SizedBox(
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
                    Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      SizedBox(
                          width: 39,
                          child: Text("", //${formatPercentage.format(1)}
                              style: const TextStyle(fontSize: 10.0),
                              textAlign: TextAlign.right))
                    ]),
                    Container(
                      width: 5,
                    ),
                    SizedBox(
                        width: 65,
                        child: Text("${formatCurrency.format(portfolioValue)}",
                            style: const TextStyle(fontSize: 12.0),
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
                        children: [
                          const SizedBox(
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
                          width: 39,
                          child: Text(
                              "${formatPercentage.format(stockAndOptionsEquityPercent)}",
                              style: const TextStyle(fontSize: 10.0),
                              textAlign: TextAlign.right))
                    ]),
                    Container(
                      width: 5,
                    ),
                    SizedBox(
                        width: 65,
                        child: Text(
                            "${formatCurrency.format(portfolios[0].marketValue)}",
                            style: const TextStyle(fontSize: 12.0),
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
                        children: [
                          const SizedBox(
                            width: 80,
                            child: Text(
                              "Options",
                              style: TextStyle(fontSize: 10.0),
                            ),
                          )
                        ]),
                    Container(
                      width: 3,
                    ),
                    Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      SizedBox(
                          width: 39,
                          child: Text(
                              "${formatPercentage.format(optionEquityPercent)}",
                              style: const TextStyle(fontSize: 10.0),
                              textAlign: TextAlign.right))
                    ]),
                    Container(
                      width: 5,
                    ),
                    SizedBox(
                        width: 65,
                        child: Text("${formatCurrency.format(optionEquity)}",
                            style: const TextStyle(fontSize: 12.0),
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
                        children: [
                          const SizedBox(
                            width: 80,
                            child: Text(
                              "Stocks",
                              style: TextStyle(fontSize: 10.0),
                            ),
                          )
                        ]),
                    Container(
                      width: 3,
                    ),
                    Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      SizedBox(
                          width: 39,
                          child: Text(
                              "${formatPercentage.format(positionEquityPercent)}",
                              style: const TextStyle(fontSize: 10.0),
                              textAlign: TextAlign.right))
                    ]),
                    Container(
                      width: 5,
                    ),
                    SizedBox(
                        width: 65,
                        child: Text("${formatCurrency.format(positionEquity)}",
                            style: const TextStyle(fontSize: 12.0),
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
                        children: [
                          const SizedBox(
                              width: 80,
                              child: Text(
                                "Crypto",
                                style: TextStyle(fontSize: 10.0),
                              )),
                        ]),
                    Container(
                      width: 3,
                    ),
                    Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      SizedBox(
                          width: 39,
                          child: Text(
                              "${formatPercentage.format(cryptoPercent)}",
                              style: const TextStyle(fontSize: 10.0),
                              textAlign: TextAlign.right))
                    ]),
                    Container(
                      width: 5,
                    ),
                    SizedBox(
                        width: 65,
                        child: Text(formatCurrency.format(nummusEquity),
                            style: const TextStyle(fontSize: 12.0),
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
                        children: [
                          const SizedBox(
                              width: 80,
                              child: Text(
                                "Cash",
                                style: TextStyle(fontSize: 10.0),
                              )),
                        ]),
                    Container(
                      width: 3,
                    ),
                    Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      SizedBox(
                          width: 39,
                          child: Text("${formatPercentage.format(cashPercent)}",
                              style: const TextStyle(fontSize: 10.0),
                              textAlign: TextAlign.right))
                    ]),
                    Container(
                      width: 5,
                    ),
                    SizedBox(
                        width: 65,
                        child: Text(formatCurrency.format(portfolioCash),
                            style: const TextStyle(fontSize: 12.0),
                            textAlign: TextAlign.right)),
                    Container(
                      width: 10,
                    ),
                  ],
                ),
              ]),
            ));
      }),
      actions: <Widget>[
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
        ),
      ],
    );
    return sliverAppBar;
  }

  Future<void> _pullRefresh() async {
    setState(() {
      futureAccounts = null;
      futurePortfolios = null;
      //futureOptionPositions = null;
      optionAggregatePositionStream = null;
    });

    var accounts = await RobinhoodService.getAccounts(robinhoodUser!);
    var portfolios = await RobinhoodService.getPortfolios(robinhoodUser!);
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

  Widget _buildPositionRow(
      List<Position> positions, int index, RobinhoodUser ru) {
    return Card(
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      ListTile(
        leading: CircleAvatar(
            child: Text(formatCompactNumber.format(positions[index].quantity!),
                style: const TextStyle(fontSize: 18))),
        title: Text(positions[index].instrumentObj != null
            ? positions[index].instrumentObj!.symbol
            : ""),
        subtitle: Text("${positions[index].quantity} shares"),
        //'Average cost ${formatCurrency.format(positions[index].averageBuyPrice)}'),
        /*
        subtitle: Text(
            '${positions[index].quantity} shares\navg cost ${formatCurrency.format(positions[index].averageBuyPrice)}'),
            */
        trailing: Wrap(
          spacing: 8,
          children: [
            Icon(
                positions[index].gainLossPerShare > 0
                    ? Icons.trending_up
                    : (positions[index].gainLossPerShare < 0
                        ? Icons.trending_down
                        : Icons.trending_flat),
                color: (positions[index].gainLossPerShare > 0
                    ? Colors.green
                    : (positions[index].gainLossPerShare < 0
                        ? Colors.red
                        : Colors.grey))),
            Text(
              "${formatCurrency.format(positions[index].marketValue)}",
              style: const TextStyle(fontSize: 16.0),
              textAlign: TextAlign.right,
            ),
            /*
            Text(
              "${formatCurrency.format(marketValue)}\n${formatCurrency.format(gainLoss)}\n${formatPercentage.format(gainLossPercent)}",
              style: const TextStyle(fontSize: 16.0),
              textAlign: TextAlign.right,
            ),*/
          ],
        ),
        // isThreeLine: true,
        onTap: () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => InstrumentWidget(
                      ru, positions[index].instrumentObj as Instrument,
                      position: positions[index])));
        },
      )
    ]));
  }

  Widget _buildOptionPositionRow(OptionAggregatePosition op, RobinhoodUser ru) {
    /*
    if (optionsPositions[index].optionInstrument == null ||
        (chainSymbolFilters.isNotEmpty &&
            !chainSymbolFilters.contains(optionsPositions[index].symbol)) ||
        (positionFilters.isNotEmpty &&
            !positionFilters
                .contains(optionsPositions[index].strategy.split("_").first)) ||
        (optionFilters.isNotEmpty &&
            !optionFilters
                .contains(optionsPositions[index].optionInstrument!.type))) {
      return Container();
    }
    */

    return Card(
        child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ListTile(
          leading: CircleAvatar(
              //backgroundImage: AssetImage(user.profilePicture),
              /*
              backgroundColor:
                  optionsPositions[index].optionInstrument!.type == 'call'
                      ? Colors.green
                      : Colors.amber,
              child: optionsPositions[index].optionInstrument!.type == 'call'
                  ? const Text('Call')
                  : const Text('Put')),
                      */
              child: Text('${op.quantity!.round()}',
                  style: const TextStyle(fontSize: 18))),
          title: Text(
              '${op.symbol} \$${formatCompactNumber.format(op.legs.first.strikePrice)} ${op.legs.first.positionType} ${op.legs.first.optionType}'),
          subtitle: Text(
              'Expires ${dateFormat.format(op.legs.first.expirationDate!)}'),
          trailing: Wrap(spacing: 8, children: [
            Icon(
                op.gainLossPerContract > 0
                    ? Icons.trending_up
                    : (op.gainLossPerContract < 0
                        ? Icons.trending_down
                        : Icons.trending_flat),
                color: (op.gainLossPerContract > 0
                    ? Colors.green
                    : (op.gainLossPerContract < 0 ? Colors.red : Colors.grey))),
            Text(
              "${formatCurrency.format(op.marketValue)}",
              style: const TextStyle(fontSize: 18.0),
              textAlign: TextAlign.right,
            )
          ]),

          /*Wrap(
            spacing: 12,
            children: [
              Column(children: [
                Text(
                  "${formatCurrency.format(gainLoss)}\n${formatPercentage.format(gainLossPercent)}",
                  style: const TextStyle(fontSize: 15.0),
                  textAlign: TextAlign.right,
                ),
                Icon(
                    gainLossPerContract > 0
                        ? Icons.trending_up
                        : (gainLossPerContract < 0
                            ? Icons.trending_down
                            : Icons.trending_flat),
                    color: (gainLossPerContract > 0
                        ? Colors.green
                        : (gainLossPerContract < 0 ? Colors.red : Colors.grey)))
              ]),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "${formatCurrency.format(marketValue)}",
                    style: const TextStyle(fontSize: 18.0),
                    textAlign: TextAlign.right,
                  ),
                ],
              )
            ],
          ),*/
          //isThreeLine: true,
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => OptionPositionWidget(ru, op)));
          },
        ),
      ],
    ));
  }

  Widget _buildWatchlistRow(Watchlist watchlist, RobinhoodUser ru) {
    return Card(
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      ListTile(
        title: Text(watchlist.displayName),
        //subtitle: Text("${positions[index].quantity} shares"),
        // isThreeLine: true,
      )
    ]));
  }

  Widget _buildWatchlistGridItem(
      List<WatchlistItem> watchLists, int index, RobinhoodUser ru) {
    var instrumentObj = watchLists[index].instrumentObj!;
    if (watchLists[index].instrumentObj == null) {
      return Card(child: Text("${watchLists[index].instrument}"));
    }
    return Card(
        child: Padding(
            padding: EdgeInsets.all(6), //.symmetric(horizontal: 6),
            child: InkWell(
              child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                Text(instrumentObj.symbol, style: TextStyle(fontSize: 16.0)),
                Wrap(
                  children: [
                    instrumentObj.quoteObj != null
                        ? Icon(
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
                            size: 20)
                        : Container(),
                    Container(
                      width: 2,
                    ),
                    Text(
                        '${instrumentObj.quoteObj != null ? formatPercentage.format(instrumentObj.quoteObj!.changePercentToday.abs()) : ""}',
                        style: const TextStyle(fontSize: 16.0)),
                  ],
                ),
                Container(
                  height: 5,
                ),
                Wrap(children: [
                  Text(
                      '${watchLists[index].instrumentObj!.name}', // ${watchLists[index].instrumentObj!.country}',
                      style: TextStyle(fontSize: 12.0),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis)
                ]),
              ]),
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => InstrumentWidget(ru,
                            watchLists[index].instrumentObj as Instrument)));
              },
            )));
  }

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
    final RobinhoodUser? result = await Navigator.push(context,
        MaterialPageRoute(builder: (BuildContext context) => LoginWidget()));

    if (result != null) {
      RobinhoodUser.writeUserToStore(result);
      setState(() {
        futureRobinhoodUser = RobinhoodUser.loadUserFromStore();
        //user = null;
      });

      // this.user = _hydrateUser(contents);

      // After the Selection Screen returns a result, hide any previous snackbars
      // and show the new result.
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text("Logged in ${result.userName}")));
    }
  }

  _logout() {
    Future.delayed(const Duration(milliseconds: 1), () async {
      RobinhoodUser.clearUserFromStore();
      setState(() {
        futureRobinhoodUser = RobinhoodUser.loadUserFromStore();
        // _selectedDrawerIndex = 0;
      });
    });
    return const Text("Logged out.");
  }

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
                            new TextStyle(color: Colors.white, fontSize: 24.9)),
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
    print(pos);
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

  void _generateCsvFile() async {
    File file =
        await OptionAggregatePosition.generateCsv(optionAggregatePositions);

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
}
