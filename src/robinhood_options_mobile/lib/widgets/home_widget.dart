// ignore_for_file: prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
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
import 'package:robinhood_options_mobile/model/robinhood_user.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/model/watchlist_item.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';
import 'package:robinhood_options_mobile/widgets/login_widget.dart';
import 'package:robinhood_options_mobile/widgets/persistent_header.dart';

import 'option_position_widget.dart';

final dateFormat = DateFormat("yMMMd");
final formatCurrency = NumberFormat.simpleCurrency();
final formatPercentage = NumberFormat.decimalPercentPattern(decimalDigits: 2);
final formatCompactNumber = NumberFormat.compact();

enum SortType { alphabetical, change }

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
  //Future<List<Position>>? futurePositions;
  Stream<List<Position>>? positionStream;
  // Future<List<OptionOrder>>? futureOptionOrders;
  Stream<List<OptionOrder>>? optionOrderStream;

  Stream<List<OptionAggregatePosition>>? optionAggregatePositionStream;
  List<OptionAggregatePosition> optionAggregatePositions = [];
  //Stream<List<OptionPosition>>? optionPositionStream;
  //List<OptionPosition> optionPositions = [];
  List<String> chainSymbols = [];

  final List<bool> headersExpanded = [false, false, false];
  final List<bool> hasQuantityFilters = [true, false];
  final List<String> optionFilters = <String>[];
  final List<String> positionFilters = <String>[];
  final List<String> chainSymbolFilters = <String>[];

  Stream<List<WatchlistItem>>? watchlistStream;
  SortType? _sortType = SortType.alphabetical;

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
                                    includeOpen: hasQuantityFilters[0],
                                    includeClosed: hasQuantityFilters[1],
                                    filters: chainSymbolFilters);

                            optionOrderStream ??=
                                RobinhoodService.streamOptionOrders(
                                    robinhoodUser!);

                            return StreamBuilder<List<OptionAggregatePosition>>(
                                stream: optionAggregatePositionStream,
                                builder: (BuildContext context3,
                                    AsyncSnapshot<List<OptionAggregatePosition>>
                                        optionAggregatePositionSnapshot) {
                                  if (optionAggregatePositionSnapshot.hasData) {
                                    optionAggregatePositions =
                                        optionAggregatePositionSnapshot.data!;

                                    watchlistStream ??=
                                        RobinhoodService.streamWatchlists(
                                            robinhoodUser!);

                                    return StreamBuilder(
                                        stream: watchlistStream,
                                        builder: (context4, watchlistSnapshot) {
                                          if (watchlistSnapshot.hasData) {
                                            List<WatchlistItem> watchLists =
                                                watchlistSnapshot.data!
                                                    as List<WatchlistItem>;
                                            if (_sortType ==
                                                SortType.alphabetical) {
                                              watchLists.sort((a, b) => (a
                                                  .instrumentObj!.symbol
                                                  .compareTo(b
                                                      .instrumentObj!.symbol)));
                                            } else if (_sortType ==
                                                SortType.change) {
                                              watchLists.sort((a, b) => (a
                                                  .instrumentObj!
                                                  .quoteObj!
                                                  .changePercentToday
                                                  .compareTo(b
                                                      .instrumentObj!
                                                      .quoteObj!
                                                      .changePercentToday)));
                                            }

                                            List<Widget> slivers = _buildSlivers(
                                                portfolios: portfolios,
                                                user: user,
                                                ru: robinhoodUser,
                                                accounts: accounts,
                                                nummusHoldings: nummusHoldings,
                                                optionAggregatePositions:
                                                    optionAggregatePositions,
                                                positions: positions,
                                                watchLists: watchLists,
                                                done: positionSnapshot
                                                            .connectionState ==
                                                        ConnectionState.done &&
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
                                          } else {
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
      List<Position>? positions,
      List<WatchlistItem>? watchLists,
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
      if (welcomeWidget != null) {
        slivers.add(SliverToBoxAdapter(
            child: SizedBox(
          // color: Colors.white,
          height: 150.0,
          child: Align(alignment: Alignment.center, child: welcomeWidget),
        )));
      }
      if (optionAggregatePositions != null) {
        slivers.add(SliverStickyHeader(
          header: Container(
            //height: 208.0, //60.0,
            //color: Colors.blue,
            color: Colors.white,
            //padding: EdgeInsets.symmetric(horizontal: 16.0),
            alignment: Alignment.centerLeft,
            child: ExpansionPanelList(
                expansionCallback: (int index, bool isExpanded) {
                  setState(() {
                    headersExpanded[0] = !headersExpanded[0];
                    //_data[index].isExpanded = !isExpanded;
                  });
                },
                expandedHeaderPadding: EdgeInsets.all(0),
                children: [
                  ExpansionPanel(
                    headerBuilder: (BuildContext context, bool isExpanded) {
                      return ListTile(
                        title: Text(
                          "Options ${formatCurrency.format(optionEquity)}",
                          style: const TextStyle(
                              //color: Colors.white,
                              fontSize: 19.0),
                        ),
                      );
                    },
                    body: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /*
                        Container(
                            //height: 40,
                            padding: EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 0),
                            //const EdgeInsets.all(4.0),
                            //EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text(
                              'Options ${formatCurrency.format(optionEquity)}',
                              style: const TextStyle(
                                  //color: Colors.white,
                                  fontSize: 19.0),
                            )),
                            */
                        openClosedFilterWidget,
                        //optionTypeFilterWidget,
                        symbolFilterWidget
                      ],
                    ),
                    /*
                    ListTile(
                        title: Text("item.expandedValue"),
                        subtitle: const Text(
                            'To delete this panel, tap the trash can icon'),
                        trailing: const Icon(Icons.delete),
                        onTap: () {
                          setState(() {
                            expanded = false;
                            //_data.removeWhere((Item currentItem) => item == currentItem);
                          });
                        }),*/
                    isExpanded: headersExpanded[0], //item.isExpanded,
                  )
                ]),
/*
              Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                      //height: 40,
                      padding: EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 0),
                      //const EdgeInsets.all(4.0),
                      //EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        'Options ${formatCurrency.format(optionEquity)}',
                        style: const TextStyle(
                            //color: Colors.white,
                            fontSize: 19.0),
                      )),
                  openClosedFilterWidget,
                  //optionTypeFilterWidget,
                  symbolFilterWidget
                ],
              )*/
          ),
          sliver: SliverList(
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
      }
      if (positions != null) {
        slivers.add(SliverStickyHeader(
            header: Container(
              //height: 208.0, //60.0,
              //color: Colors.blue,
              color: Colors.white,
              //padding: EdgeInsets.symmetric(horizontal: 16.0),
              alignment: Alignment.centerLeft,
              child: ExpansionPanelList(
                  expansionCallback: (int index, bool isExpanded) {
                    setState(() {
                      headersExpanded[1] = !headersExpanded[1];
                      //_data[index].isExpanded = !isExpanded;
                    });
                  },
                  expandedHeaderPadding: EdgeInsets.all(0),
                  children: [
                    ExpansionPanel(
                      headerBuilder: (BuildContext context, bool isExpanded) {
                        return ListTile(
                          title: Text(
                            "Positions ${formatCurrency.format(positionEquity)}",
                            style: const TextStyle(
                                //color: Colors.white,
                                fontSize: 19.0),
                          ),
                        );
                      },
                      body: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          positionFilterWidget,
                        ],
                      ),
                      /*
                    ListTile(
                        title: Text("item.expandedValue"),
                        subtitle: const Text(
                            'To delete this panel, tap the trash can icon'),
                        trailing: const Icon(Icons.delete),
                        onTap: () {
                          setState(() {
                            expanded = false;
                            //_data.removeWhere((Item currentItem) => item == currentItem);
                          });
                        }),*/
                      isExpanded: headersExpanded[1], //item.isExpanded,
                    )
                  ]),
            ),
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
      }
      if (watchLists != null) {
        slivers.add(SliverStickyHeader(
            /*
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
                      "Watch Lists",
                      style: const TextStyle(
                          //color: Colors.white,
                          fontSize: 19.0),
                    ),
                  ),
                )),
                */
            header: Container(
              //height: 208.0, //60.0,
              //color: Colors.blue,
              color: Colors.white,
              //padding: EdgeInsets.symmetric(horizontal: 16.0),
              alignment: Alignment.centerLeft,
              child: ExpansionPanelList(
                  expansionCallback: (int index, bool isExpanded) {
                    setState(() {
                      headersExpanded[2] = !headersExpanded[2];
                      //_data[index].isExpanded = !isExpanded;
                    });
                  },
                  expandedHeaderPadding: EdgeInsets.all(0),
                  children: [
                    ExpansionPanel(
                      headerBuilder: (BuildContext context, bool isExpanded) {
                        return ListTile(
                          title: Text(
                            "Watch List",
                            style: const TextStyle(
                                //color: Colors.white,
                                fontSize: 19.0),
                          ),
                        );
                      },
                      body: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RadioListTile<SortType>(
                            title: const Text('Alphabetical'),
                            value: SortType.alphabetical,
                            groupValue: _sortType,
                            onChanged: (SortType? value) {
                              /*
                                watchLists.sort((a, b) => (a
                                    .instrumentObj!.symbol
                                    .compareTo(b.instrumentObj!.symbol)));
                              */
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
                              /*
                                watchLists.sort((a, b) => (a
                                    .instrumentObj!.quoteObj!.changePercentToday
                                    .compareTo(b.instrumentObj!.quoteObj!
                                        .changePercentToday)));
                              */
                              setState(() {
                                _sortType = value;
                              });
                            },
                          ),
                          //positionFilterWidget,
                        ],
                      ),
                      /*
                    ListTile(
                        title: Text("item.expandedValue"),
                        subtitle: const Text(
                            'To delete this panel, tap the trash can icon'),
                        trailing: const Icon(Icons.delete),
                        onTap: () {
                          setState(() {
                            expanded = false;
                            //_data.removeWhere((Item currentItem) => item == currentItem);
                          });
                        }),*/
                      isExpanded: headersExpanded[2], //item.isExpanded,
                    )
                  ]),
            ),
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
                          'Watch List',
                          style: const TextStyle(
                              //color: Colors.white,
                              fontSize: 19.0),
                        )),
                  ],
                )),
                */
            sliver: watchListWidget(watchLists)));
        /*
      slivers.add(
        SliverPersistentHeader(
          pinned: false,
          delegate: PersistentHeader("Watch Lists"),
        ),
      );
      slivers.add(watchListWidget(watchLists));
      */
      }
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
                        'User',
                        style: const TextStyle(
                            //color: Colors.white,
                            fontSize: 19.0),
                      )),
                ],
              )),
              */
          sliver: userWidget(user)));
      /*
      slivers.add(SliverPersistentHeader(
        pinned: false,
        delegate: PersistentHeader("User"),
      ));
      slivers.add(userWidget(user));
      */
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
              child: ListTile(
                title: Text(
                  "Disclaimer",
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

  Widget get symbolFilterWidget {
    return SizedBox(
        height: 56,
        child: ListView.builder(
          padding: const EdgeInsets.all(4.0),
          scrollDirection: Axis.horizontal,
          itemBuilder: (context, index) {
            return Row(
                children: filterWidgets(chainSymbols, optionAggregatePositions)
                    .toList());
          },
          itemCount: 1,
        ));
  }

  /*
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
                    label: const Text('Long Positions'),
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
                    label: const Text('Short Positions'),
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
                    label: const Text('Call Options'),
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
                    label: const Text('Put Options'),
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
  */

  Widget get positionFilterWidget {
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
            ]);
          },
          itemCount: 1,
        ));
  }

//Iterable<Widget> get filterWidgets sync* {
  Iterable<Widget> filterWidgets(
      List<String> chainSymbols, List<OptionAggregatePosition> options) sync* {
    for (final String chainSymbol in chainSymbols) {
      /*
      var contractCount = options
          .where((element) => element.symbol == chainSymbol)
          .map((element) => element.quantity)
          .reduce((a, b) => (a! + b!))!
          .round();
          */

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
      /*
      futurePositions = Future.value(positions);
      futureWatchlists = Future.value(watchlists);
      */
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
        title: Text(positions[index].instrumentObj!.symbol),
        subtitle: Text(
            'Average cost ${formatCurrency.format(positions[index].averageBuyPrice)}'),
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

  Widget _buildOptionPositionRow(List<OptionAggregatePosition> optionsPositions,
      int index, RobinhoodUser ru) {
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
              child: Text('${optionsPositions[index].quantity!.round()}',
                  style: const TextStyle(fontSize: 18))),
          title: Text(
              '${optionsPositions[index].symbol} \$${formatCompactNumber.format(optionsPositions[index].optionInstrument!.strikePrice)} ${optionsPositions[index].strategy.split('_').first} ${optionsPositions[index].optionInstrument!.type}'), // , style: TextStyle(fontSize: 18.0)),
          subtitle: Text(
              'Expires ${dateFormat.format(optionsPositions[index].optionInstrument!.expirationDate!)}'),
          trailing: Wrap(spacing: 8, children: [
            Icon(
                optionsPositions[index].gainLossPerContract > 0
                    ? Icons.trending_up
                    : (optionsPositions[index].gainLossPerContract < 0
                        ? Icons.trending_down
                        : Icons.trending_flat),
                color: (optionsPositions[index].gainLossPerContract > 0
                    ? Colors.green
                    : (optionsPositions[index].gainLossPerContract < 0
                        ? Colors.red
                        : Colors.grey))),
            Text(
              "${formatCurrency.format(optionsPositions[index].marketValue)}",
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
                    builder: (context) =>
                        OptionPositionWidget(ru, optionsPositions[index])));
          },
        ),
      ],
    ));
  }

  Widget _buildWatchlistGridItem(
      List<WatchlistItem> watchLists, int index, RobinhoodUser ru) {
    var instrumentObj = watchLists[index].instrumentObj!;
    var quoteObj = instrumentObj.quoteObj!;
    return Card(
        child: Padding(
            padding: EdgeInsets.all(6), //.symmetric(horizontal: 6),
            child: InkWell(
              child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                Text(instrumentObj.symbol, style: TextStyle(fontSize: 16.0)),
                Wrap(
                  children: [
                    Icon(
                        quoteObj.changeToday > 0
                            ? Icons.trending_up
                            : (quoteObj.changeToday < 0
                                ? Icons.trending_down
                                : Icons.trending_flat),
                        color: (quoteObj.changeToday > 0
                            ? Colors.green
                            : (quoteObj.changeToday < 0
                                ? Colors.red
                                : Colors.grey)),
                        size: 20),
                    Container(
                      width: 2,
                    ),
                    Text(
                        '${formatPercentage.format(quoteObj.changePercentToday.abs())}',
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

  /*
  Widget _buildWatchlistRow(
      List<WatchlistItem> watchLists, int index, RobinhoodUser ru) {
    return Card(
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      ListTile(
//      leading: CircleAvatar(
//          //backgroundImage: AssetImage(user.profilePicture),
//          child: watchLists[index].type == 'call'
//              ? new Icon(Icons.trending_up)
//              : new Icon(Icons.trending_down)
//          // child: new Text(optionsPositions[i].symbol)
//          ),
        // trailing: user.icon,
        title: Text(watchLists[index]
            .instrumentObj!
            .symbol), // , style: TextStyle(fontSize: 18.0)
        subtitle: Text(
            '${watchLists[index].instrumentObj!.name} ${watchLists[index].instrumentObj!.country}'),
        trailing: Text(
          dateFormat.format(watchLists[index].instrumentObj!.listDate!),
          //style: TextStyle(fontSize: 18.0),
        ),
        onTap: () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => InstrumentWidget(ru,
                      watchLists[index].instrumentObj as Instrument, null)));
        },
      )
    ]));
  }
  */

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
