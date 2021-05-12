import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
// import 'package:shared_preferences/shared_preferences.dart';

import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/option_position.dart';
import 'package:robinhood_options_mobile/model/portfolio.dart';
import 'package:robinhood_options_mobile/model/position.dart';
import 'package:robinhood_options_mobile/model/robinhood_user.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/model/watchlist_item.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
import 'package:robinhood_options_mobile/services/store.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';
import 'package:robinhood_options_mobile/widgets/login_widget.dart';
import 'package:robinhood_options_mobile/widgets/persistent_header.dart';
import 'package:robinhood_options_mobile/widgets/trade_option_widget.dart';

import 'option_position_widget.dart';

final dateFormat = DateFormat("yMMMd");
final formatCurrency = new NumberFormat.simpleCurrency();
final formatPercentage =
    new NumberFormat.decimalPercentPattern(decimalDigits: 2);

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

  HomePage({Key? key, this.title}) : super(key: key);

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
  late RobinhoodUser snapshotUser;

  Future<List<Account>>? futureAccounts;
  Future<List<Portfolio>>? futurePortfolios;
  Future<dynamic>? futurePortfolioHistoricals;
  Future<List<Position>>? futurePositions;
  Future<List<OptionPosition>>? futureOptionPositions;
  Future<List<dynamic>>? futureWatchlists;
  Future<User>? futureUser;

  late ScrollController _controller;
  bool silverCollapsed = false;

  // int _selectedDrawerIndex = 0;
  // bool _showDrawerContents = true;

  @override
  void initState() {
    super.initState();
    print('Loading cache.');
    futureRobinhoodUser = RobinhoodUser.loadUserFromStore();

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
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
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
        body: _buildHomePage());
  }

  _buildHomePage() {
    return new FutureBuilder(
        future: futureRobinhoodUser,
        builder: (context, AsyncSnapshot<RobinhoodUser> userSnapshot) {
          // Can chain new FutureBuilder()'s here

          if (userSnapshot.hasData) {
            snapshotUser = userSnapshot.data!;
            if (snapshotUser.userName != null) {
              if (futureAccounts == null) {
                //RobinhoodService.downloadNummusAccounts(snapshotUser);
                //RobinhoodService.downloadNummusHoldings(snapshotUser);

                futureAccounts =
                    RobinhoodService.downloadAccounts(snapshotUser);
              }
              if (futurePortfolios == null) {
                futurePortfolios =
                    RobinhoodService.downloadPortfolios(snapshotUser);
              }
              /*
              if (futurePortfolioHistoricals == null) {
                futurePortfolioHistoricals =
                    RobinhoodService.downloadPortfolioHistoricals(
                        snapshotUser, null);
              }
              */
              if (futurePositions == null) {
                futurePositions =
                    RobinhoodService.downloadPositions(snapshotUser);
              }
              if (futureOptionPositions == null) {
                futureOptionPositions =
                    RobinhoodService.downloadOptionPositions(snapshotUser);
              }
              if (futureWatchlists == null) {
                futureWatchlists =
                    RobinhoodService.downloadWatchlists(snapshotUser);
              }
              if (futureUser == null) {
                futureUser = RobinhoodService.downloadUser(snapshotUser);
              }

              return new FutureBuilder(
                future: Future.wait([
                  futureAccounts as Future,
                  futurePortfolios as Future,
                  futurePositions as Future,
                  futureOptionPositions as Future,
                  futureWatchlists as Future,
                  futureUser as Future
                ]),
                builder: (context1, AsyncSnapshot<List<dynamic>> dataSnapshot) {
                  if (dataSnapshot.hasData) {
                    List<dynamic> data = dataSnapshot.data as List<dynamic>;
                    //var welcomeWidget = _buildWelcomeWidget(snapshotUser);
                    return RefreshIndicator(
                        child: _buildCustomScrollView(
                            ru: snapshotUser,
                            accounts: data.length > 0 ? data[0] : null,
                            portfolios: data.length > 1 ? data[1] : null,
                            positions: data.length > 2 ? data[2] : null,
                            optionsPositions: data.length > 3 ? data[3] : null,
                            watchLists: data.length > 4 ? data[4] : null,
                            user: data.length > 5 ? data[5] : null),
                        onRefresh: _pullRefresh);
                  } else if (dataSnapshot.hasError) {
                    print("${dataSnapshot.error}");
                    return _buildCustomScrollView(
                        ru: snapshotUser,
                        welcomeWidget: Text("${dataSnapshot.error}"));
                  } else {
                    return _buildCustomScrollView(
                        ru: snapshotUser,
                        welcomeWidget: Center(
                          child: CircularProgressIndicator(),
                        ));
                  }
                },
              );
            } else {
              return _buildCustomScrollView(
                  ru: snapshotUser, welcomeWidget: _buildLogin());
            }
          } else if (userSnapshot.hasError) {
            print("${userSnapshot.error}");
            return _buildCustomScrollView(
                welcomeWidget: Text("${userSnapshot.error}"));
          } else {
            return _buildCustomScrollView(
              welcomeWidget: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
        });
  }

  RefreshIndicator _buildCustomScrollView(
      {RobinhoodUser? ru,
      Widget? welcomeWidget,
      List<Account>? accounts,
      List<Portfolio>? portfolios,
      List<Position>? positions,
      List<OptionPosition>? optionsPositions,
      List<WatchlistItem>? watchLists,
      User? user}) {
    List<Widget> slivers = _buildSlivers(portfolios, user, ru, accounts,
        welcomeWidget, optionsPositions, positions, watchLists);
    return RefreshIndicator(
      child: CustomScrollView(controller: _controller, slivers: slivers),
      onRefresh: _pullRefresh,
    );
    // return CustomScrollView(controller: _controller, slivers: slivers);
  }

  List<Widget> _buildSlivers(
      List<Portfolio>? portfolios,
      User? user,
      RobinhoodUser? ru,
      List<Account>? accounts,
      Widget? welcomeWidget,
      List<OptionPosition>? optionsPositions,
      List<Position>? positions,
      List<WatchlistItem>? watchLists) {
    var slivers = <Widget>[];
    double changeToday = 0;
    double changeTodayPercentage = 0;
    if (portfolios != null) {
      changeToday = portfolios[0].equity! - portfolios[0].equityPreviousClose!;
      changeTodayPercentage = changeToday / portfolios[0].equity!;
    }

    slivers.add(SliverAppBar(
      /*
      title: new Text('Robinhood Options'),
      */
      /* Drawer will automatically add menu to SliverAppBar.
                leading: IconButton(
                  icon: const Icon(Icons.menu),
                  tooltip: 'Menu',
                  onPressed: () {/* ... */},
                ),*/
      // backgroundColor: Colors.green,
      // brightness: Brightness.light,
      expandedHeight: 280.0,
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
          ? Text(
              '${user.profileName}: ${formatCurrency.format(portfolios[0].equity)}')
          : Container(),
          */
      flexibleSpace: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
        if (ru == null || ru.userName == null || portfolios == null) {
          return FlexibleSpaceBar(title: Text('Robinhood Options'));
        }
        /* else if (silverCollapsed) {
          return Container();
        }*/
        return FlexibleSpaceBar(
          background: FlutterLogo(),
          title: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            Row(
              children: [Text('${user!.profileName}')],
            ),
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Equity',
                        style: TextStyle(fontSize: 15.0),
                      ),
                      Text(
                        'Market Value',
                        style: TextStyle(fontSize: 15.0),
                      ),
                      Text(
                        'Cash',
                        style: TextStyle(fontSize: 15.0),
                      ),
                      Text(
                        'Today Change',
                        style: TextStyle(fontSize: 15.0),
                      ),
                      Text(
                        '',
                        style: TextStyle(fontSize: 15.0),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${formatCurrency.format(portfolios[0].equity)}',
                        style: TextStyle(fontSize: 15.0),
                      ),
                      Text(
                        '${formatCurrency.format(portfolios[0].marketValue)}',
                        style: TextStyle(fontSize: 15.0),
                      ),
                      Text(
                        '${formatCurrency.format(accounts![0].portfolioCash)}',
                        style: TextStyle(fontSize: 15.0),
                      ),
                      Text(
                        '${formatCurrency.format(changeToday)}',
                        style: TextStyle(fontSize: 15.0),
                      ), // ${formatPercentage.format(changeTodayPercentage)}
                      Wrap(
                        children: [
                          new Icon(
                              changeToday > 0
                                  ? Icons.trending_up
                                  : (changeToday < 0
                                      ? Icons.trending_down
                                      : Icons.trending_flat),
                              color: (changeToday > 0
                                  ? Colors.green
                                  : (changeToday < 0
                                      ? Colors.red
                                      : Colors.grey))),
                          Text(
                              '${formatPercentage.format(changeTodayPercentage)}',
                              style: TextStyle(fontSize: 15.0))
                        ],
                      )
                    ],
                  ),
                ]),
          ]),
        );
      }),
      actions: <Widget>[
        IconButton(
          icon: ru != null && ru.userName != null
              ? const Icon(Icons.logout)
              : Icon(Icons.login),
          tooltip: ru != null && ru.userName != null ? 'Logout' : 'Login',
          onPressed: () {
            if (ru != null && ru.userName != null) {
              var alert = AlertDialog(
                title: Text('Logout process'),
                content: SingleChildScrollView(
                  child: ListBody(
                    children: <Widget>[
                      Text('This action will require you to log in again.'),
                      Text('Are you sure you want to log out?'),
                    ],
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    child: Text('Cancel'),
                    onPressed: () {
                      Navigator.pop(context, 'dialog');
                    },
                  ),
                  TextButton(
                    child: Text('OK'),
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
    ));

    if (ru != null && ru.userName != null) {
      if (welcomeWidget != null) {
        slivers.add(SliverToBoxAdapter(
            child: Container(
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
      if (optionsPositions != null) {
        var totalAdjustedMarkPrice = optionsPositions
            .map(
                (e) => e.optionInstrument!.optionMarketData!.adjustedMarkPrice!)
            .reduce((a, b) => a + b);
        slivers.add(
          SliverPersistentHeader(
            pinned: false,
            delegate: PersistentHeader(
                "Options ${formatCurrency.format(totalAdjustedMarkPrice * 100)}"),
          ),
        );
        slivers.add(SliverList(
          // delegate: SliverChildListDelegate(widgets),
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              if (optionsPositions.length > index) {
                return _buildOptionPositionRow(optionsPositions, index, ru);
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
      if (positions != null) {
        var totalPositionEquity = positions
            .map(
                (e) => e.quantity! * e.instrumentObj!.quoteObj!.lastTradePrice!)
            .reduce((a, b) => a + b);
        slivers.add(
          SliverPersistentHeader(
            pinned: false,
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
            pinned: false,
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
            : new Container(),
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
            child: Align(
                alignment: Alignment.center,
                child: Text(
                    "Robinhood Options is not a registered investment, legal or tax advisor or a broker/dealer. All investment/financial opinions expressed by Robinhood Options are intended  as educational material.\n\n Lorem ipsum dolor sit amet, consectetur adipiscing elit. Duis sit amet lectus velit. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia curae; Nam eget dolor quis eros vulputate pharetra. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Maecenas porttitor augue ipsum, non mattis lorem commodo eu. Vivamus tellus lorem, rhoncus vel fermentum et, pharetra at sapien. Donec non auctor augue. Cras ante metus, commodo ornare augue at, commodo pellentesque risus. Donec laoreet iaculis orci, eu suscipit enim vehicula ut. Aliquam at erat sit amet diam fringilla fermentum vel eget massa. Duis nec mi dolor.\n\nMauris porta ac libero in vestibulum. Vivamus vestibulum, nibh ut dignissim aliquet, arcu elit tempor urna, in vehicula diam ante ut lacus. Donec vehicula ullamcorper orci, ac facilisis nibh fermentum id. Aliquam nec erat at mi tristique vestibulum ac quis sapien. Donec a auctor sem, sed sollicitudin nunc. Sed bibendum rhoncus nisl. Donec eu accumsan quam. Praesent iaculis fermentum tortor sit amet varius. Nam a dui et mauris commodo porta. Nam egestas molestie quam eu commodo. Proin nec justo neque.")))));
    /*
              SliverPadding(
                  padding: EdgeInsets.all(50),
                  sliver: SliverList(
                    // delegate: SliverChildListDelegate(widgets),
                    delegate: SliverChildBuilderDelegate(
                      (BuildContext context, int index) {
                        if (widgets.length > index) {
                          return widgets[index];
                        }
                        if (index > widgets.length + 10) return null;
                        // To convert this infinite list to a list with three items,
                        // uncomment the following line:
                        // if (index > 3) return null;
                        return Container(
                          color: Colors.white,
                          height: 150.0,
                          child: Align(
                              alignment: Alignment.center,
                              child: Text("Lorem ipsum")),
                        );
                      },
                      // Or, uncomment the following line:
                      // childCount: widgets.length + 10,
                    ),
                  ))
                  */
    return slivers;
  }

  Future<void> _pullRefresh() async {
    var accounts = await RobinhoodService.downloadAccounts(snapshotUser);
    var portfolios = await RobinhoodService.downloadPortfolios(snapshotUser);
    var positions = await RobinhoodService.downloadPositions(snapshotUser);
    var optionPositions =
        await RobinhoodService.downloadOptionPositions(snapshotUser);
    var watchlists = await RobinhoodService.downloadWatchlists(snapshotUser);
    //var user = await RobinhoodService.downloadUser(snapshotUser);

    setState(() {
      futureAccounts = Future.value(accounts);
      futurePortfolios = Future.value(portfolios);
      futurePositions = Future.value(positions);
      futureOptionPositions = Future.value(optionPositions);
      futureWatchlists = Future.value(watchlists);
      //futureUser = Future.value(user);
    });
  }

  Widget _buildPositionRow(
      List<Position> positions, int index, RobinhoodUser ru) {
    return new ListTile(
      title: new Text('${positions[index].instrumentObj!.symbol}'),
      subtitle: new Text(
          '${positions[index].quantity} shares - avg cost ${formatCurrency.format(positions[index].averageBuyPrice)}'),
      trailing: new Text(
          '${formatCurrency.format(positions[index].quantity! * positions[index].instrumentObj!.quoteObj!.lastTradePrice!)}'),
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
            new MaterialPageRoute(
                builder: (context) => new InstrumentWidget(
                    ru, positions[index].instrumentObj as Instrument)));
      },
    );
  }

  Widget _buildOptionPositionRow(
      List<OptionPosition> optionsPositions, int index, RobinhoodUser ru) {
    final double gainLoss = (optionsPositions[index]
                .optionInstrument!
                .optionMarketData!
                .adjustedMarkPrice! -
            (optionsPositions[index].averagePrice! / 100)) *
        100;
    final double gainLossPercent =
        gainLoss / optionsPositions[index].averagePrice!;
    return Card(
        child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ListTile(
          leading: CircleAvatar(
              backgroundColor:
                  optionsPositions[index].optionInstrument!.type == 'call'
                      ? Colors.green
                      : Colors.amber,
              //backgroundImage: AssetImage(user.profilePicture),
              child: optionsPositions[index].optionInstrument!.type == 'call'
                  ? new Text('Call')
                  : new Text('Put')),
          title: Text(
              '${optionsPositions[index].chainSymbol} \$${optionsPositions[index].optionInstrument!.strikePrice} ${optionsPositions[index].optionInstrument!.type.toUpperCase()}'), // , style: TextStyle(fontSize: 18.0)),
          subtitle: Text(
              'Expires ${dateFormat.format(optionsPositions[index].optionInstrument!.expirationDate!)} (${optionsPositions[index].quantity!.round()}x)'),
          trailing: new Wrap(
            spacing: 12,
            children: [
              new Icon(
                  gainLoss > 0
                      ? Icons.trending_up
                      : (gainLoss < 0
                          ? Icons.trending_down
                          : Icons.trending_flat),
                  color: (gainLoss > 0
                      ? Colors.green
                      : (gainLoss < 0 ? Colors.red : Colors.grey))),
              new Text(
                "${formatCurrency.format(gainLoss)}\n${formatPercentage.format(gainLossPercent)}",
                style: TextStyle(fontSize: 16.0),
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
                new MaterialPageRoute(
                    builder: (context) =>
                        new OptionPositionWidget(ru, optionsPositions[index])));
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            TextButton(
              child: const Text('TRADE INSTRUMENT'),
              onPressed: () {
                Navigator.push(
                    context,
                    new MaterialPageRoute(
                        builder: (context) => new TradeOptionWidget(
                            ru, optionsPositions[index])));
              },
            ),
            const SizedBox(width: 8),
            TextButton(
              child: const Text('VIEW MARKET DATA'),
              onPressed: () {
                Navigator.push(
                    context,
                    new MaterialPageRoute(
                        builder: (context) => new OptionPositionWidget(
                            ru, optionsPositions[index])));
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
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
    return new ListTile(
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
      title: new Text(
          '${watchLists[index].instrumentObj!.symbol}'), // , style: TextStyle(fontSize: 18.0)
      subtitle: new Text(
          '${watchLists[index].instrumentObj!.name} ${watchLists[index].instrumentObj!.country}'),
      trailing: new Text(
        "${dateFormat.format(watchLists[index].instrumentObj!.listDate!)}",
        //style: TextStyle(fontSize: 18.0),
      ),
      onTap: () {
        Navigator.push(
            context,
            new MaterialPageRoute(
                builder: (context) => new InstrumentWidget(
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
        Align(
            alignment: Alignment.center,
            child:
                new Text("Not logged in.", style: TextStyle(fontSize: 20.0))),
        // Align(alignment: Alignment.center, child: new Text("Login above.")),
        Container(height: 150),
      ],
    );
  }

  _openLogin() async {
    final RobinhoodUser? result = await Navigator.push(context,
        MaterialPageRoute(builder: (BuildContext context) => LoginWidget()));

    if (result != null) {
      var contents = jsonEncode(result);
      await Store.writeFile(Constants.cacheFilename, contents);
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
    Future.delayed(Duration(milliseconds: 1), () async {
      await Store.deleteFile(Constants.cacheFilename);
      setState(() {
        futureRobinhoodUser = RobinhoodUser.loadUserFromStore();
        // _selectedDrawerIndex = 0;
      });
    });
    return new Text("Logged out.");
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
}
