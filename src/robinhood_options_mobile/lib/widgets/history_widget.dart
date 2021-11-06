import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';

import 'package:robinhood_options_mobile/model/option_order.dart';
import 'package:robinhood_options_mobile/model/position_order.dart';
import 'package:robinhood_options_mobile/model/robinhood_user.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
import 'package:robinhood_options_mobile/widgets/option_order_widget.dart';
import 'package:robinhood_options_mobile/widgets/position_order_widget.dart';

final formatDate = DateFormat("yMMMd");
final formatCompactDate = DateFormat("MMMd");
final formatCurrency = NumberFormat.simpleCurrency();
final formatPercentage = NumberFormat.decimalPercentPattern(decimalDigits: 2);
final formatCompactNumber = NumberFormat.compact();

enum SortType { alphabetical, change }
enum SortDirection { asc, desc }
enum ChartDateSpan { hour, day, week, month, month_3, year, all }
enum Bounds { regular, t24_7 }

/*
class DrawerItem {
  String title;
  IconData icon;
  DrawerItem(this.title, this.icon);
}
*/
class HistoryPage extends StatefulWidget {
  /*
  final drawerItems = [
    new DrawerItem("Home", Icons.home),
    //new DrawerItem("Account", Icons.verified_user),
    new DrawerItem("Options", Icons.library_books),
    new DrawerItem("Logout", Icons.logout),
  ];
  */

  const HistoryPage(this.user, {Key? key, this.navigatorKey}) : super(key: key);

  final GlobalKey<NavigatorState>? navigatorKey;
  final RobinhoodUser user;

  @override
  _HistoryPageState createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage>
    with AutomaticKeepAliveClientMixin<HistoryPage> {
  Stream<List<PositionOrder>>? positionOrderStream;
  List<PositionOrder>? positionOrders;
  List<PositionOrder>? filteredPositionOrders;
  Stream<List<OptionOrder>>? optionOrderStream;
  List<OptionOrder>? optionOrders;
  List<OptionOrder>? filteredOptionOrders;

  double optionOrdersPremiumBalance = 0;
  double positionOrdersBalance = 0;
  double balance = 0;

  List<String> optionOrderSymbols = [];
  List<String> positionOrderSymbols = [];
  List<String> chainSymbols = [];
  List<String> cryptoSymbols = [];

  final List<String> optionSymbolFilters = <String>[];

  final List<String> orderFilters = <String>["placed", "filled"];
  final List<String> stockSymbolFilters = <String>[];
  final List<String> cryptoFilters = <String>[];

  int orderDateFilterSelected = 1;

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
    return WillPopScope(
      onWillPop: () => Future.value(false),
      child: Scaffold(
          //appBar: _buildFlowAppBar(),
          body: Navigator(
              key: widget.navigatorKey,
              onGenerateRoute: (_) =>
                  MaterialPageRoute(builder: (_) => _buildScaffold()))),
    );
  }

  Widget _buildScaffold() {
    optionOrderStream ??= RobinhoodService.streamOptionOrders(widget.user);

    //var optionEventStream = RobinhoodService.streamOptionEvents(widget.user);

    return StreamBuilder(
        stream: optionOrderStream,
        builder: (context5, optionOrdersSnapshot) {
          if (optionOrdersSnapshot.hasData) {
            optionOrders = optionOrdersSnapshot.data as List<OptionOrder>;

            positionOrderStream ??=
                RobinhoodService.streamPositionOrders(widget.user);

            return StreamBuilder(
                stream: positionOrderStream,
                builder: (context6, positionOrdersSnapshot) {
                  if (positionOrdersSnapshot.hasData) {
                    positionOrders =
                        positionOrdersSnapshot.data as List<PositionOrder>;
                    return _buildPage(
                        optionOrders: optionOrders,
                        positionOrders: positionOrders,
                        done: positionOrdersSnapshot.connectionState ==
                                ConnectionState.done &&
                            optionOrdersSnapshot.connectionState ==
                                ConnectionState.done);
                  } else if (positionOrdersSnapshot.hasError) {
                    debugPrint("${positionOrdersSnapshot.error}");
                    return _buildPage(
                        welcomeWidget: Text("${positionOrdersSnapshot.error}"));
                  } else {
                    // No Position Orders Found.
                    return _buildPage(
                        optionOrders: optionOrders,
                        done: positionOrdersSnapshot.connectionState ==
                                ConnectionState.done &&
                            optionOrdersSnapshot.connectionState ==
                                ConnectionState.done);
                  }
                });
          } else {
            // No Position Orders found.
            return _buildPage(
                done: optionOrdersSnapshot.connectionState ==
                    ConnectionState.done);
          }
        });
  }

  Widget _buildPage(
      {Widget? welcomeWidget,
      List<OptionOrder>? optionOrders,
      List<PositionOrder>? positionOrders,
      //List<Watchlist>? watchlists,
      //List<WatchlistItem>? watchListItems,
      bool done = false}) {
    var slivers = <Widget>[];

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

    if (optionOrders != null) {
      optionOrderSymbols =
          optionOrders.map((e) => e.chainSymbol).toSet().toList();
      optionOrderSymbols.sort((a, b) => (a.compareTo(b)));

      filteredOptionOrders = optionOrders
          .where((element) =>
              (orderFilters.isEmpty || orderFilters.contains(element.state)) &&
              (days == 0 ||
                  element.createdAt!
                          .add(Duration(days: days))
                          .compareTo(DateTime.now()) >=
                      0) &&
              (optionSymbolFilters.isEmpty ||
                  optionSymbolFilters.contains(element.chainSymbol)))
          .toList();

      optionOrdersPremiumBalance = filteredOptionOrders!.isNotEmpty
          ? filteredOptionOrders!
              .map((e) =>
                  (e.processedPremium != null ? e.processedPremium! : 0) *
                  (e.direction == "credit" ? 1 : -1))
              .reduce((a, b) => a + b) as double
          : 0;
    }

    if (positionOrders != null) {
      positionOrderSymbols = positionOrders
          .where((element) => element.instrumentObj != null)
          .map((e) => e.instrumentObj!.symbol)
          .toSet()
          .toList();
      positionOrderSymbols.sort((a, b) => (a.compareTo(b)));

      filteredPositionOrders = positionOrders
          .where((element) =>
              (orderFilters.isEmpty || orderFilters.contains(element.state)) &&
              (days == 0 ||
                  element.createdAt!
                          .add(Duration(days: days))
                          .compareTo(DateTime.now()) >=
                      0) &&
              (stockSymbolFilters.isEmpty ||
                  stockSymbolFilters.contains(element.instrumentObj!.symbol)))
          .toList();

      positionOrdersBalance = filteredPositionOrders!.isNotEmpty
          ? filteredPositionOrders!
              .map((e) =>
                  (e.averagePrice != null ? e.averagePrice! * e.quantity! : 0) *
                  (e.side == "buy" ? -1 : 1))
              .reduce((a, b) => a + b) as double
          : 0;
    }
    balance = optionOrdersPremiumBalance + positionOrdersBalance;

    if (widget.user.userName != null) {
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
      slivers.add(const SliverToBoxAdapter(
          child: SizedBox(
        height: 25.0,
      )));
      if (welcomeWidget != null) {
        slivers.add(SliverToBoxAdapter(
            child: SizedBox(
          height: 150.0,
          child: Align(alignment: Alignment.center, child: welcomeWidget),
        )));
      }

      if (positionOrders != null) {
        slivers.add(SliverStickyHeader(
          header: Material(
              elevation: 2,
              child: Container(
                  //height: 208.0, //60.0,
                  //color: Colors.blue,
                  //color: Colors.white,
                  //padding: EdgeInsets.symmetric(horizontal: 16.0),
                  alignment: Alignment.centerLeft,
                  child: ListTile(
                    title: const Text(
                      "Stock Orders",
                      style: TextStyle(fontSize: 19.0),
                    ),
                    subtitle: Text(
                        "${formatCompactNumber.format(filteredPositionOrders!.length)} of ${formatCompactNumber.format(positionOrders.length)} orders $orderDateFilterDisplay ${positionOrdersBalance > 0 ? "+" : positionOrdersBalance < 0 ? "-" : ""}${formatCurrency.format(positionOrdersBalance.abs())}"),
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
                              optionPositions:
                                  optionPositions)
                                  */
                                (BuildContext context) {
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const ListTile(
                                    tileColor: Colors.blue,
                                    leading: Icon(Icons.filter_list),
                                    title: Text(
                                      "Filter Stock Orders",
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 19.0),
                                    ),
                                    /*
                                  trailing: TextButton(
                                      child: const Text("APPLY"),
                                      onPressed: () => Navigator.pop(context))*/
                                  ),
                                  const ListTile(
                                    title: Text("Order State & Date"),
                                  ),
                                  orderFilterWidget,
                                  orderDateFilterWidget,
                                  const ListTile(
                                    title: Text("Symbols"),
                                  ),
                                  stockOrderSymbolFilterWidget,
                                ],
                              );
                            },
                          );
                          future.then((void value) => {});
                        }),
                  ))),
          sliver: SliverList(
            // delegate: SliverChildListDelegate(widgets),
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) {
                var amount = filteredPositionOrders![index].averagePrice! *
                    filteredPositionOrders![index].quantity! *
                    (filteredPositionOrders![index].side == "buy" ? -1 : 1);
                return Card(
                    child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ListTile(
                      leading: CircleAvatar(
                          //backgroundImage: AssetImage(user.profilePicture),
                          child: Text(
                              formatCompactNumber.format(
                                  filteredPositionOrders![index].quantity!),
                              style: const TextStyle(fontSize: 17))),
                      title: Text(
                          "${filteredPositionOrders![index].instrumentObj != null ? filteredPositionOrders![index].instrumentObj!.symbol : ""} ${filteredPositionOrders![index].type} ${filteredPositionOrders![index].side} ${filteredPositionOrders![index].averagePrice != null ? formatCurrency.format(filteredPositionOrders![index].averagePrice) : ""}"),
                      subtitle: Text(
                          "${filteredPositionOrders![index].state} ${formatDate.format(filteredPositionOrders![index].updatedAt!)}"),
                      trailing: Wrap(spacing: 8, children: [
                        Text(
                          filteredPositionOrders![index].averagePrice != null
                              ? "${amount > 0 ? "+" : (amount < 0 ? "-" : "")}${formatCurrency.format(amount.abs())}"
                              : "",
                          style: const TextStyle(fontSize: 18.0),
                          textAlign: TextAlign.right,
                        )
                      ]),

                      //isThreeLine: true,
                      onTap: () {
                        widget.navigatorKey!.currentState!.push(
                            MaterialPageRoute(
                                builder: (context) => PositionOrderWidget(
                                    widget.user,
                                    filteredPositionOrders![index])));
                        /*
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => PositionOrderWidget(
                                    ru, filteredPositionOrders![index])));
                                    */
                      },
                    ),
                  ],
                ));
              },
              childCount: filteredPositionOrders!.length,
            ),
          ),
        ));
        slivers.add(const SliverToBoxAdapter(
            child: SizedBox(
          height: 25.0,
        )));
      }
      if (optionOrders != null) {
        slivers.add(SliverStickyHeader(
          header: Material(
              elevation: 2,
              child: Container(
                  //height: 208.0, //60.0,
                  //color: Colors.blue,
                  //color: Colors.white,
                  //padding: EdgeInsets.symmetric(horizontal: 16.0),
                  alignment: Alignment.centerLeft,
                  child: ListTile(
                    title: const Text(
                      "Option Orders",
                      style: TextStyle(fontSize: 19.0),
                    ),
                    subtitle: Text(
                        "${formatCompactNumber.format(filteredOptionOrders!.length)} of ${formatCompactNumber.format(optionOrders.length)} orders $orderDateFilterDisplay ${optionOrdersPremiumBalance > 0 ? "+" : optionOrdersPremiumBalance < 0 ? "-" : ""}${formatCurrency.format(optionOrdersPremiumBalance.abs())}"),
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
                              optionPositions:
                                  optionPositions)
                                  */
                                (BuildContext context) {
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const ListTile(
                                    tileColor: Colors.blue,
                                    leading: Icon(Icons.filter_list),
                                    title: Text(
                                      "Filter Option Orders",
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 19.0),
                                    ),
                                    /*
                                  trailing: TextButton(
                                      child: const Text("APPLY"),
                                      onPressed: () => Navigator.pop(context))*/
                                  ),
                                  const ListTile(
                                    title: Text("Order State & Date"),
                                  ),
                                  orderFilterWidget,
                                  orderDateFilterWidget,
                                  const ListTile(
                                    title: Text("Symbols"),
                                  ),
                                  optionOrderSymbolFilterWidget,
                                ],
                              );
                            },
                          );
                          future.then((void value) => {});
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
                              '${filteredOptionOrders![index].quantity!.round()}',
                              style: const TextStyle(fontSize: 17))),
                      title: Text(
                          "${filteredOptionOrders![index].chainSymbol} \$${formatCompactNumber.format(filteredOptionOrders![index].legs.first.strikePrice)} ${filteredOptionOrders![index].strategy} ${formatCompactDate.format(filteredOptionOrders![index].legs.first.expirationDate!)}"), // , style: TextStyle(fontSize: 18.0)),
                      subtitle: Text(
                          "${filteredOptionOrders![index].state} ${formatDate.format(filteredOptionOrders![index].updatedAt!)}"),
                      trailing: Wrap(spacing: 8, children: [
                        Text(
                          (filteredOptionOrders![index].direction == "credit"
                                  ? "+"
                                  : "-") +
                              (filteredOptionOrders![index].processedPremium !=
                                      null
                                  ? formatCurrency.format(
                                      filteredOptionOrders![index]
                                          .processedPremium)
                                  : ""),
                          style: const TextStyle(fontSize: 18.0),
                          textAlign: TextAlign.right,
                        )
                      ]),

                      //isThreeLine: true,
                      onTap: () {
                        widget.navigatorKey!.currentState!.push(
                            MaterialPageRoute(
                                builder: (context) => OptionOrderWidget(
                                    widget.user,
                                    filteredOptionOrders![index])));
                        /*
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => OptionOrderWidget(
                                    ru, filteredOptionOrders![index])));
                                    */
                      },
                    ),
                  ],
                ));
              },
              childCount: filteredOptionOrders!.length,
            ),
          ),
        ));
        slivers.add(const SliverToBoxAdapter(
            child: SizedBox(
          height: 25.0,
        )));
      }
    }
    slivers.add(SliverStickyHeader(
        header: Material(
            elevation: 2.0,
            child: Container(
                //height: 208.0, //60.0,
                //color: Colors.blue,
                //color: Colors.white,
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
                //color: Colors.white,
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
    slivers.add(const SliverToBoxAdapter(
        child: SizedBox(
      // color: Colors.white,
      height: 25.0,
    )));

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
              debugPrint("${snapshot.error}");
              return Text("${snapshot.error}");
            }
            // By default, show a loading spinner
            return Center(
              child: LinearProgressIndicator(),
            );
          },
        ),
        */
        appBar: AppBar(
          title: Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              //runAlignment: WrapAlignment.end,
              //alignment: WrapAlignment.end,
              spacing: 20,
              //runSpacing: 5,
              children: [
                const Text('History', style: TextStyle(fontSize: 20.0)),
                Text(
                    "${positionOrders != null && optionOrders != null ? formatCompactNumber.format(positionOrders.length + optionOrders.length) : ""} orders $orderDateFilterDisplay ${balance > 0 ? "+" : balance < 0 ? "-" : ""}${formatCurrency.format(balance.abs())}",
                    style:
                        const TextStyle(fontSize: 16.0, color: Colors.white70)),
              ]),
          actions: [
            IconButton(
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
                          const ListTile(
                            tileColor: Colors.blue,
                            leading: Icon(Icons.filter_list),
                            title: Text(
                              "Filter Orders",
                              style: TextStyle(
                                  color: Colors.white, fontSize: 19.0),
                            ),
                            /*
                                  trailing: TextButton(
                                      child: const Text("APPLY"),
                                      onPressed: () => Navigator.pop(context))*/
                          ),
                          const ListTile(
                            title: Text("Order State & Date"),
                          ),
                          orderFilterWidget,
                          orderDateFilterWidget,
                          const ListTile(
                            title: Text("Symbols"),
                          ),
                          stockOrderSymbolFilterWidget,
                          /*                         
                          Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RadioListTile<SortType>(
                                title: const Text('Alphabetical (Ascending)'),
                                value: SortType.alphabetical,
                                groupValue: _sortType,
                                onChanged: (SortType? value) {
                                  Navigator.pop(context);
                                  setState(() {
                                    _sortType = value;
                                    _sortDirection = SortDirection.asc;
                                  });
                                },
                              ),
                              RadioListTile<SortType>(
                                title: const Text('Alphabetical (Descending)'),
                                value: SortType.alphabetical,
                                groupValue: _sortType,
                                onChanged: (SortType? value) {
                                  Navigator.pop(context);
                                  setState(() {
                                    _sortType = value;
                                    _sortDirection = SortDirection.desc;
                                  });
                                },
                              ),
                              RadioListTile<SortType>(
                                title: const Text('Change (Ascending)'),
                                value: SortType.change,
                                groupValue: _sortType,
                                onChanged: (SortType? value) {
                                  Navigator.pop(context);
                                  setState(() {
                                    _sortType = value;
                                    _sortDirection = SortDirection.asc;
                                  });
                                },
                              ),
                              RadioListTile<SortType>(
                                title: const Text('Change (Descending)'),
                                value: SortType.change,
                                groupValue: _sortType,
                                onChanged: (SortType? value) {
                                  Navigator.pop(context);
                                  setState(() {
                                    _sortType = value;
                                    _sortDirection = SortDirection.desc;
                                  });
                                },
                              ),
                            ],
                          )
                          */
                        ],
                      );
                    },
                  );
                })
          ],
        ),
        body: RefreshIndicator(
          child: CustomScrollView(slivers: slivers), //controller: _controller,
          onRefresh: _pullRefresh,
        ) /*
      floatingActionButton:
          (widget.user != null && widget.user.userName != null)
              ? FloatingActionButton(
                  onPressed: _generateCsvFile,
                  tooltip: 'Export to CSV',
                  child: const Icon(Icons.download),
                )
              : null,
              */
        );
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

  String get orderDateFilterDisplay {
    return orderDateFilterSelected == 0
        ? "today"
        : (orderDateFilterSelected == 1
            ? "past week"
            : (orderDateFilterSelected == 2
                ? "past month"
                : (orderDateFilterSelected == 3 ? "past year" : "")));
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
    var widgets =
        symbolFilterWidgets(optionOrderSymbols, optionSymbolFilters).toList();
    return symbolWidgets(widgets);
  }

  Widget get stockOrderSymbolFilterWidget {
    var widgets =
        symbolFilterWidgets(positionOrderSymbols, stockSymbolFilters).toList();
    return symbolWidgets(widgets);
  }

  Widget get cryptoFilterWidget {
    var widgets = symbolFilterWidgets(cryptoSymbols, cryptoFilters).toList();
    return symbolWidgets(widgets);
  }

  Iterable<Widget> symbolFilterWidgets(
      List<String> symbols, List<String> selectedSymbols) sync* {
    for (final String chainSymbol in symbols) {
      yield Padding(
        padding: const EdgeInsets.all(4.0),
        child: FilterChip(
          // avatar: CircleAvatar(child: Text(contractCount.toString())),
          label: Text(chainSymbol),
          selected: selectedSymbols.contains(chainSymbol),
          onSelected: (bool value) {
            setState(() {
              if (value) {
                selectedSymbols.add(chainSymbol);
              } else {
                selectedSymbols.removeWhere((String name) {
                  return name == chainSymbol;
                });
              }
            });
          },
        ),
      );
    }
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

  Future<void> _pullRefresh() async {
    setState(() {
      optionOrderStream = null;
      positionOrderStream = null;
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
