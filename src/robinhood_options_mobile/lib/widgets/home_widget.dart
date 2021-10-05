// ignore_for_file: prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// import 'package:shared_preferences/shared_preferences.dart';

//import 'dart:async';
import 'dart:io';
import 'package:open_file/open_file.dart';

import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/holding.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_position.dart';
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
  late RobinhoodUser robinhoodUser;

  Future<List<Account>>? futureAccounts;
  Future<List<Holding>>? futureNummusHoldings;
  Future<List<Portfolio>>? futurePortfolios;
  Future<dynamic>? futurePortfolioHistoricals;
  Future<List<Position>>? futurePositions;

  Stream<List<OptionAggregatePosition>>? optionAggregatePositionStream;
  List<OptionAggregatePosition> optionAggregatePositions = [];
  //Stream<List<OptionPosition>>? optionPositionStream;
  //List<OptionPosition> optionPositions = [];
  List<String> chainSymbols = [];
  final List<bool> hasQuantityFilters = [true, false];
  final List<String> chainSymbolFilters = <String>[];

  Future<List<dynamic>>? futureWatchlists;
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
              child: CircularProgressIndicator(),
            );
          },
        ),
        */
      body: _buildHomePage(),
      floatingActionButton: FloatingActionButton(
        onPressed: _generateCsvFile,
        tooltip: 'Export to CSV',
        child: const Icon(Icons.download),
      ),
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

            if (robinhoodUser.userName != null) {
              futureUser ??= RobinhoodService.getUser(robinhoodUser);
              futureAccounts ??= RobinhoodService.getAccounts(robinhoodUser);
              futurePortfolios ??=
                  RobinhoodService.getPortfolios(robinhoodUser);
              //futureNummusAccounts ??= RobinhoodService.downloadNummusAccounts(snapshotUser);
              futureNummusHoldings ??=
                  RobinhoodService.getNummusHoldings(robinhoodUser);

              /*
              if (futurePortfolioHistoricals == null) {
                futurePortfolioHistoricals =
                    RobinhoodService.downloadPortfolioHistoricals(
                        snapshotUser, null);
              }
              */
              futurePositions ??= RobinhoodService.getPositions(robinhoodUser);
              futureWatchlists ??=
                  RobinhoodService.getWatchlists(robinhoodUser);

              return FutureBuilder(
                future: Future.wait([
                  futureUser as Future,
                  futureAccounts as Future,
                  futurePortfolios as Future,
                  futureNummusHoldings as Future,
                  futurePositions as Future,
                  futureWatchlists as Future,
                ]),
                builder: (context1, AsyncSnapshot<List<dynamic>> dataSnapshot) {
                  if (dataSnapshot.hasData) {
                    List<dynamic> data = dataSnapshot.data as List<dynamic>;
                    var user = data.isNotEmpty ? data[0] : null;
                    var accounts = data.length > 1 ? data[1] : null;
                    var portfolios = data.length > 2 ? data[2] : null;
                    var nummusHoldings = data.length > 3 ? data[3] : null;
                    var positions = data.length > 4 ? data[4] : null;
                    var watchlist = data.length > 5 ? data[5] : null;
                    //var welcomeWidget = _buildWelcomeWidget(snapshotUser);
                    optionAggregatePositionStream ??=
                        RobinhoodService.streamOptionAggregatePositionList(
                            robinhoodUser,
                            includeOpen: hasQuantityFilters[0],
                            includeClosed: hasQuantityFilters[1],
                            filters: chainSymbolFilters);
                    /*
                    optionPositionsStream ??=
                        RobinhoodService.streamOptionPositionList(snapshotUser,
                            includeOpen: hasQuantityFilters[0],
                            includeClosed: hasQuantityFilters[1],
                            filters: chainSymbolFilters);
                            */
                    return StreamBuilder<List<OptionAggregatePosition>>(
                        stream: optionAggregatePositionStream,
                        builder: (BuildContext context,
                            AsyncSnapshot<List<OptionAggregatePosition>>
                                optionAggregatePositionSnapshot) {
                          if (optionAggregatePositionSnapshot.hasData) {
                            optionAggregatePositions =
                                optionAggregatePositionSnapshot.data!;
                            List<Widget> slivers = _buildSlivers(
                                portfolios: portfolios,
                                user: user,
                                ru: robinhoodUser,
                                accounts: accounts,
                                nummusHoldings: nummusHoldings,
                                optionAggregatePositions:
                                    optionAggregatePositions,
                                positions: positions,
                                watchLists: watchlist);
                            return RefreshIndicator(
                              child: CustomScrollView(
                                  slivers: slivers), //controller: _controller,
                              onRefresh: _pullRefresh,
                            );
                          } else {
                            List<Widget> slivers = _buildSlivers(
                                portfolios: portfolios,
                                user: user,
                                ru: robinhoodUser,
                                accounts: accounts);
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
                      _openLogin();
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
                        welcomeWidget: const Center(
                          child: CircularProgressIndicator(),
                        ));
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
                //ru: snapshotUser,
                welcomeWidget: Center(
              child: userSnapshot.connectionState != ConnectionState.done
                  ? const CircularProgressIndicator()
                  : null,
            ));
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
      List<WatchlistItem>? watchLists}) {
    var slivers = <Widget>[];
    double changeToday = 0;
    double changeTodayPercentage = 0;
    if (portfolios != null) {
      changeToday = portfolios[0].equity! - portfolios[0].equityPreviousClose!;
      changeTodayPercentage = changeToday / portfolios[0].equity!;
    }
    double nummusEquity = 0;
    if (nummusHoldings != null) {
      nummusEquity = nummusHoldings
          .map((e) => e.value! * e.quantity!)
          .reduce((a, b) => a + b);
    }
    SliverAppBar sliverAppBar = buildSliverAppBar(ru, portfolios, user,
        accounts, nummusEquity, changeToday, changeTodayPercentage);
    slivers.add(sliverAppBar);

    if (ru != null && ru.userName != null) {
      if (welcomeWidget != null) {
        slivers.add(SliverToBoxAdapter(
            child: SizedBox(
          // color: Colors.white,
          height: 150.0,
          child: Align(alignment: Alignment.center, child: welcomeWidget),
        )));
      }
      /*
      if (portfolios != null) {
        slivers.add(
          SliverPersistentHeader(
            pinned: false,
            delegate: PersistentHeader("Portfolios"),
          ),
        );
        slivers.add(SliverList(
          // delegate: SliverChildListDelegate(widgets),
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              if (portfolios.length > index) {
                return Text('\$${portfolios[index].equity}');
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
      }
      */
      if (optionAggregatePositions != null) {
        var totalAdjustedMarkPrice = optionAggregatePositions
            .map((e) =>
                e.optionInstrument?.optionMarketData!.adjustedMarkPrice! ?? 0)
            .reduce((a, b) => a + b);
        chainSymbols =
            optionAggregatePositions.map((e) => e.symbol).toSet().toList();
        chainSymbols.sort((a, b) => (a.compareTo(b)));
        slivers.add(
          SliverPersistentHeader(
            pinned: true,
            delegate: PersistentHeader(
                "Options ${formatCurrency.format(totalAdjustedMarkPrice * 100)}"),
          ),
        );
        slivers.add(SliverToBoxAdapter(
            child: Wrap(children: [
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: FilterChip(
              avatar: const Icon(Icons.new_releases_outlined),
              //avatar: CircleAvatar(child: Text(optionCount.toString())),
              label: const Text('Open Options'),
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
              avatar: const Icon(Icons.history_outlined),
              //avatar: CircleAvatar(child: Text(optionCount.toString())),
              label: const Text('Closed Options'),
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
          )
        ])
            /*ToggleButtons(
            children: <Widget>[
              Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Row(
                    children: const [
                      Icon(Icons.new_releases),
                      SizedBox(width: 10),
                      Text(
                        'Open',
                        style: TextStyle(fontSize: 18),
                      )
                    ],
                  )),
              Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Row(
                    children: const [
                      Icon(Icons.history),
                      SizedBox(width: 10),
                      Text(
                        'Closed',
                        style: TextStyle(fontSize: 16),
                      )
                    ],
                  ))
              /*
              Icon(Icons.ac_unit),
              Icon(Icons.call),
              Icon(Icons.cake),
              */
            ],
            onPressed: (int index) {
              setState(() {
                /* For mutually exclusive selection requiring at least one selection.
                for (int buttonIndex = 0;
                    buttonIndex < isSelected.length;
                    buttonIndex++) {
                  if (buttonIndex == index) {
                    isSelected[buttonIndex] = true;
                  } else {
                    isSelected[buttonIndex] = false;
                  }
                }
                */
                isSelected[index] = !isSelected[index];
                optionPositionsStream = null;
              });
            },
            isSelected: isSelected,
          ),*/
            ));
        slivers.add(SliverToBoxAdapter(
            child:
                /*SingleChildScrollView(
                  child: Row(
                      children: filterWidgets(chainSymbols, optionsPositions)
                          .toList()),
                )*/
                SizedBox(
                    height: 56,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (context, index) {
                        return Row(
                            children: filterWidgets(
                                    chainSymbols, optionAggregatePositions)
                                .toList());
                      },
                      itemCount: 1,
                    ))
            /*
              Wrap(
            direction: Axis.horizontal,
            children: filterWidgets(chainSymbols, optionsPositions).toList(),
          ),
          */
            ));
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
      } else {
        slivers.add(const SliverToBoxAdapter(
            child: SizedBox(
          // color: Colors.white,
          height: 150.0,
          child: Align(
              alignment: Alignment.center,
              child: Center(
                child: CircularProgressIndicator(),
              )),
        )));
      }
      if (positions != null) {
        var totalPositionEquity = 0;
        if (positions.isNotEmpty) {
          positions
              .map((e) =>
                  e.quantity! * e.instrumentObj!.quoteObj!.lastTradePrice!)
              .reduce((a, b) => a + b);
        }
        slivers.add(
          SliverPersistentHeader(
            pinned: true,
            delegate: PersistentHeader(
                "Positions ${formatCurrency.format(totalPositionEquity)}"),
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
      }
      if (watchLists != null) {
        slivers.add(
          SliverPersistentHeader(
            pinned: true,
            delegate: PersistentHeader("Watch Lists"),
          ),
        );
        slivers.add(SliverList(
          // delegate: SliverChildListDelegate(widgets),
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              if (watchLists.length > index) {
                return _buildWatchlistRow(watchLists, index, ru);
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
      }
      slivers.add(SliverPersistentHeader(
        pinned: false,
        delegate: PersistentHeader("Account"),
      ));
      slivers.add(SliverToBoxAdapter(
          child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
        Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text('Welcome ${ru.userName}')]),
        portfolios != null
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  'Trading since ${dateFormat.format(portfolios[0].startDate!)}',
                )
              ])
            : Container(),
      ])));
      /*
          Container(
              height: 80.0,
              child: Align(
                  alignment: Alignment.center,
                  child: new Text("Welcome ${ru.userName}, ")))));
                  */
      /*
      slivers.add(SliverToBoxAdapter(
          child: Container(
        // color: Colors.white,
        height: 150.0,
        child: Align(alignment: Alignment.center, child: Text("Lorem ipsum")),
      )));
      */

    }
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
    return slivers;
  }

//Iterable<Widget> get filterWidgets sync* {
  Iterable<Widget> filterWidgets(
      List<String> chainSymbols, List<OptionAggregatePosition> options) sync* {
    for (final String chainSymbol in chainSymbols) {
      var optionCount =
          options.where((element) => element.symbol == chainSymbol).length;
      /*
          options
              .where((element) => element.chainSymbol == chainSymbol)
              .map((e) => e.quantity)
              .reduce((a, b) => a! + b!)!
              .round();
              */

      yield Padding(
        padding: const EdgeInsets.all(4.0),
        child: FilterChip(
          avatar: CircleAvatar(child: Text(optionCount.toString())),
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
      double nummusEquity,
      double changeToday,
      double changeTodayPercentage) {
    var sliverAppBar = SliverAppBar(
      /* Drawer will automatically add menu to SliverAppBar.
                    leading: IconButton(
                      icon: const Icon(Icons.menu),
                      tooltip: 'Menu',
                      onPressed: () {/* ... */},
                    ),*/
      // backgroundColor: Colors.green,
      // brightness: Brightness.light,
      expandedHeight: 240.0,
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
          ? getAppBarTitle(user, changeToday, changeTodayPercentage)
          : Container(),
          */
      flexibleSpace: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
        if (ru == null || ru.userName == null || portfolios == null) {
          return const FlexibleSpaceBar(title: Text('Robinhood Options'));
        } /* else if (silverCollapsed) {
          return Container();
        }*/
        return FlexibleSpaceBar(
            background: const FlutterLogo(),
            title: SingleChildScrollView(
              child: Column(//mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                Row(children: [const Text('')]),
                Row(children: [const Text('')]),
                Row(children: [const Text('')]),
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
                    Column(
                      children: [
                        Container(
                          width: 10,
                        ),
                      ],
                    ),
                    Text(
                      formatCurrency
                          .format((portfolios[0].equity ?? 0) + nummusEquity),
                      style: const TextStyle(fontSize: 18.0),
                    ),
                    Column(
                      children: [
                        Container(
                          width: 10,
                        ),
                      ],
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
                              size: 14.0),
                          Container(
                            width: 2,
                          ),
                          Text(
                              '${formatPercentage.format(changeTodayPercentage.abs())}',
                              style: const TextStyle(fontSize: 16.0)),
                          Container(
                            width: 10,
                          ),
                          Text(
                              '${formatCurrency.format(changeToday.abs())}', //${formatPercentage.format(changeTodayPercentage.abs())}
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
                      width: 20,
                    ),
                    const Text(
                      'Stocks & Options',
                      style: TextStyle(fontSize: 10.0),
                    ),
                    Container(
                      width: 10,
                    ),
                    Text(
                      formatCurrency.format(portfolios[0].marketValue),
                      style: const TextStyle(fontSize: 13.0),
                    ),
                    Column(
                      children: [
                        Container(
                          width: 10,
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 10,
                        ),
                      ],
                    ),
                    Column(children: [
                      const Text(
                        'Cash',
                        style: TextStyle(fontSize: 10.0),
                      )
                    ]),
                    Container(
                      width: 10,
                    ),
                    Column(children: [
                      Text(
                        formatCurrency.format(accounts![0].portfolioCash),
                        style: const TextStyle(fontSize: 13.0),
                      )
                    ]),
                    Column(
                      children: [
                        Container(
                          width: 10,
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 10,
                        ),
                      ],
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        const Text(
                          'Crypto',
                          style: TextStyle(fontSize: 10.0),
                        ),
                      ],
                    ),
                    Container(
                      width: 10,
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          formatCurrency.format(nummusEquity),
                          style: const TextStyle(fontSize: 13.0),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Container(
                          width: 10,
                        ),
                      ],
                    ),
                  ],
                ),
                /*
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Portfolio Equity',
                            style: TextStyle(fontSize: 12.0),
                          ),
                          const Text(
                            '\t\tStocks & Options',
                            style: TextStyle(fontSize: 10.0),
                          ),
                          const Text(
                            '\t\tCash',
                            style: TextStyle(fontSize: 10.0),
                          ),
                          const Text(
                            '\t\tCrypto', //'\t\t\tChange',
                            style: TextStyle(fontSize: 10.0),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatCurrency.format(
                                (portfolios[0].equity ?? 0) + nummusEquity),
                            style: const TextStyle(fontSize: 15.0),
                          ),
                          Text(
                            formatCurrency.format(portfolios[0].marketValue),
                            style: const TextStyle(fontSize: 12.0),
                          ),
                          Text(
                            formatCurrency.format(accounts![0].portfolioCash),
                            style: const TextStyle(fontSize: 12.0),
                          ),
                          Text(
                            formatCurrency.format(nummusEquity),
                            style: const TextStyle(fontSize: 12.0),
                          ),
                        ],
                      ),
                    ]),
                    */
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

    var accounts = await RobinhoodService.getAccounts(robinhoodUser);
    var portfolios = await RobinhoodService.getPortfolios(robinhoodUser);
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
    return ListTile(
      title: Text(positions[index].instrumentObj!.symbol),
      subtitle: Text(
          '${positions[index].quantity} shares - avg cost ${formatCurrency.format(positions[index].averageBuyPrice)}'),
      trailing: Text(formatCurrency.format(positions[index].quantity! *
          positions[index].instrumentObj!.quoteObj!.lastTradePrice!)),
      /*
      leading: CircleAvatar(
          //backgroundImage: AssetImage(user.profilePicture),
          child: optionsPositions[index].optionInstrument.type == 'call'
              ? new Icon(Icons.trending_up)
              : new Icon(Icons.trending_down)
          // child: new Text(optionsPositions[i].symbol)
          ),
      // trailing: user.icon,
      title: new Text(
          '${optionsPositions[index].chainSymbol} \$${optionsPositions[index].optionInstrument.strikePrice} ${optionsPositions[index].optionInstrument.type.toUpperCase()}'), // , style: TextStyle(fontSize: 18.0)
      subtitle: new Text(
          '${optionsPositions[index].quantity.round()}x Expires ${dateFormat.format(optionsPositions[index].optionInstrument.expirationDate)}'),
      trailing: new Text(
        "\$${optionsPositions[index].averagePrice.toString()}",
        //style: TextStyle(fontSize: 18.0),
      ),
      */
      onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => InstrumentWidget(
                    ru, positions[index].instrumentObj as Instrument)));
      },
    );
  }

  Widget _buildOptionPositionRow(List<OptionAggregatePosition> optionsPositions,
      int index, RobinhoodUser ru) {
    if (optionsPositions[index].optionInstrument == null ||
        (chainSymbolFilters.isNotEmpty &&
            !chainSymbolFilters.contains(optionsPositions[index].symbol))) {
      return Container();
    }
    final double gainLossPerContract = (optionsPositions[index]
                .optionInstrument!
                .optionMarketData!
                .adjustedMarkPrice! -
            (optionsPositions[index].averageOpenPrice! / 100)) *
        100;
    final double gainLoss =
        gainLossPerContract * optionsPositions[index].quantity!;
    final double gainLossPercent =
        gainLossPerContract / optionsPositions[index].averageOpenPrice!;
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
              '${optionsPositions[index].symbol} \$${optionsPositions[index].optionInstrument!.strikePrice} ${optionsPositions[index].strategy.split('_').first} ${optionsPositions[index].optionInstrument!.type.toUpperCase()}'), // , style: TextStyle(fontSize: 18.0)),
          subtitle: Text(
              'Expires ${dateFormat.format(optionsPositions[index].optionInstrument!.expirationDate!)}'),
          trailing: Wrap(
            spacing: 12,
            children: [
              Icon(
                  gainLossPerContract > 0
                      ? Icons.trending_up
                      : (gainLossPerContract < 0
                          ? Icons.trending_down
                          : Icons.trending_flat),
                  color: (gainLossPerContract > 0
                      ? Colors.green
                      : (gainLossPerContract < 0 ? Colors.red : Colors.grey))),
              Text(
                "${formatCurrency.format(gainLoss)}\n${formatPercentage.format(gainLossPercent)}",
                style: const TextStyle(fontSize: 16.0),
                textAlign: TextAlign.right,
              ),
              /*
              new Text(
                "${formatPercentage.format(gainLossPercent)}",
                style: TextStyle(fontSize: 15.0),
              )
              */
            ],
          ),
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => OptionPositionWidget(
                        ru, optionAggregatePositions[index])));
          },
        ),
        /*
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            TextButton(
              child: const Text('TRADE INSTRUMENT'),
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            TradeOptionWidget(ru, optionsPositions[index])));
              },
            ),
            const SizedBox(width: 8),
            TextButton(
              child: const Text('VIEW MARKET DATA'),
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            OptionPositionWidget(ru, optionsPositions[index])));
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        */
      ],
    ));
    /*
    return new ListTile(
      leading: CircleAvatar(
          //backgroundImage: AssetImage(user.profilePicture),
          child: optionsPositions[index].optionInstrument.type == 'call'
              ? new Icon(Icons.trending_up)
              : new Icon(Icons.trending_down)
          // child: new Text(optionsPositions[i].symbol)
          ),
      // trailing: user.icon,
      title: new Text(
          '${optionsPositions[index].chainSymbol} \$${optionsPositions[index].optionInstrument.strikePrice} ${optionsPositions[index].optionInstrument.type.toUpperCase()}'), // , style: TextStyle(fontSize: 18.0)
      subtitle: new Text(
          '${optionsPositions[index].quantity.round()}x Expires ${dateFormat.format(optionsPositions[index].optionInstrument.expirationDate)}'),
      trailing: new Text(
        "\$${optionsPositions[index].averagePrice.toString()}",
        //style: TextStyle(fontSize: 18.0),
      ),
      onTap: () {
        Navigator.push(
            context,
            new MaterialPageRoute(
                builder: (context) =>
                    new OptionPositionWidget(ru, optionsPositions[index])));
      },
    );
    */
  }

  Widget _buildWatchlistRow(
      List<WatchlistItem> watchLists, int index, RobinhoodUser ru) {
    return ListTile(
      /*
      leading: CircleAvatar(
          //backgroundImage: AssetImage(user.profilePicture),
          child: watchLists[index].type == 'call'
              ? new Icon(Icons.trending_up)
              : new Icon(Icons.trending_down)
          // child: new Text(optionsPositions[i].symbol)
          ),
          */
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
                builder: (context) => InstrumentWidget(
                    ru, watchLists[index].instrumentObj as Instrument)));
      },
    );
  }

/*
  Widget _buildWelcomeWidget(RobinhoodUser ru) {
    return Column(
      children: [
        Container(height: 10),
        Align(alignment: Alignment.center, child: new Text("Logged in.")),
        Align(
            alignment: Alignment.center,
            child: new Text("Welcome ${ru.userName}")),
        Container(height: 10),
      ],
    );
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
        ..showSnackBar(SnackBar(content: Text("${result.userName}")));
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
