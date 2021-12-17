import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/widgets/disclaimer_widget.dart';
import 'package:share_plus/share_plus.dart';

import 'package:robinhood_options_mobile/extension_methods.dart';
import 'package:robinhood_options_mobile/model/option_event.dart';

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

  const HistoryPage(this.user, this.account, {Key? key, this.navigatorKey})
      : super(key: key);

  final GlobalKey<NavigatorState>? navigatorKey;
  final RobinhoodUser user;
  final Account? account;

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
  Stream<List<dynamic>>? optionEventStream;
  List<OptionEvent>? optionEvents;
  List<OptionEvent>? filteredOptionEvents;

  double optionOrdersPremiumBalance = 0;
  double positionOrdersBalance = 0;
  double balance = 0;

  List<String> optionOrderSymbols = [];
  List<String> positionOrderSymbols = [];
  List<String> chainSymbols = [];
  List<String> cryptoSymbols = [];

  final List<String> optionSymbolFilters = <String>[];

  final List<String> orderFilters = <String>["confirmed", "filled"];
  final List<String> stockSymbolFilters = <String>[];
  final List<String> cryptoFilters = <String>[];

  int orderDateFilterSelected = 1;

  bool showShareView = false;
  List<String> selectedPositionOrdersToShare = [];
  List<String> selectedOptionOrdersToShare = [];
  bool shareText = true;
  bool shareLink = true;

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
    optionOrderStream ??= RobinhoodService.streamOptionOrders(widget.user);

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

                    optionEventStream ??=
                        RobinhoodService.streamOptionEvents(widget.user);
                    return StreamBuilder(
                        stream: optionEventStream,
                        builder: (context6, optionEventSnapshot) {
                          if (optionEventSnapshot.hasData) {
                            optionEvents =
                                optionEventSnapshot.data as List<OptionEvent>;
                            if (optionOrders != null) {
                              for (var optionEvent in optionEvents!) {
                                var originalOptionOrder = optionOrders!
                                    .firstWhereOrNull((element) =>
                                        element.legs.first.option ==
                                        optionEvent.option);
                                if (originalOptionOrder != null) {
                                  originalOptionOrder.optionEvents ??= [];
                                  originalOptionOrder.optionEvents!
                                      .add(optionEvent);
                                }
                              }
                            }
                            return _buildPage(
                                optionOrders: optionOrders,
                                positionOrders: positionOrders,
                                optionEvents: optionEvents,
                                done: positionOrdersSnapshot.connectionState ==
                                        ConnectionState.done &&
                                    optionOrdersSnapshot.connectionState ==
                                        ConnectionState.done);
                          } else {
                            return _buildPage(
                                optionOrders: optionOrders,
                                positionOrders: positionOrders,
                                done: positionOrdersSnapshot.connectionState ==
                                        ConnectionState.done &&
                                    optionOrdersSnapshot.connectionState ==
                                        ConnectionState.done);
                          }
                        });
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
      List<OptionEvent>? optionEvents,
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
                  (element.createdAt!
                          .add(Duration(days: days))
                          .compareTo(DateTime.now()) >=
                      0) ||
                  (element.optionEvents != null &&
                      element.optionEvents!.any((event) =>
                          event.eventDate!
                              .add(Duration(days: days))
                              .compareTo(DateTime.now()) >=
                          0))) &&
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

    if (optionEvents != null) {
      filteredOptionEvents = optionEvents
          .where((element) =>
                  (orderFilters.isEmpty ||
                      orderFilters.contains(element.state)) &&
                  (days == 0 ||
                      (element.createdAt!
                              .add(Duration(days: days))
                              .compareTo(DateTime.now()) >=
                          0)) //&&
              //(optionSymbolFilters.isEmpty || optionSymbolFilters.contains(element.chainSymbol))
              )
          .toList();
    }
    slivers.add(SliverAppBar(
      floating: false,
      pinned: true,
      snap: false,
      title: Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          //runAlignment: WrapAlignment.end,
          //alignment: WrapAlignment.end,
          spacing: 20,
          //runSpacing: 5,
          children: [
            const Text('History', style: TextStyle(fontSize: 20.0)),
            Text(
                "${filteredPositionOrders != null && filteredOptionOrders != null ? formatCompactNumber.format(filteredPositionOrders!.length + filteredOptionOrders!.length) : "0"} of ${positionOrders != null && optionOrders != null ? formatCompactNumber.format(positionOrders.length + optionOrders.length) : "0"} orders $orderDateFilterDisplay ${balance > 0 ? "+" : balance < 0 ? "-" : ""}${formatCurrency.format(balance.abs())}",
                style: const TextStyle(fontSize: 16.0, color: Colors.white70)),
          ]),
      actions: [
        IconButton(
            icon: const Icon(Icons.more_vert_sharp),
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                //constraints: BoxConstraints(maxHeight: 260),
                builder: (BuildContext context) {
                  return Scaffold(
                      appBar: AppBar(
                          leading: const CloseButton(),
                          title: const Text('History Settings')),
                      body: ListView(
                        //Column(
                        //mainAxisAlignment: MainAxisAlignment.start,
                        //crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ListTile(
                            title: const Text("Share"),
                            trailing: IconButton(
                              onPressed: _closeAndShowShareView,
                              icon: showShareView
                                  ? const Icon(Icons.preview)
                                  : const Icon(Icons.share),
                            ),
                          ),
                          const ListTile(
                            leading: Icon(Icons.filter_list),
                            title: Text(
                              "Filters",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
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
                          const SizedBox(
                            height: 25.0,
                          )
                        ],
                      ));
                },
              );
            })
      ],
    ));
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

      if (optionOrders != null) {
        slivers.add(SliverStickyHeader(
          header: Material(
              //elevation: 2,
              child: Container(
                  //height: 208.0, //60.0,
                  //padding: EdgeInsets.symmetric(horizontal: 16.0),
                  alignment: Alignment.centerLeft,
                  child: ListTile(
                    title: const Text(
                      "Option Orders & Events",
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
                                  ListTile(
                                    tileColor:
                                        Theme.of(context).colorScheme.primary,
                                    leading: const Icon(Icons.filter_list),
                                    title: const Text(
                                      "Filter Option Orders",
                                      style: TextStyle(fontSize: 19.0),
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
                var optionOrder = filteredOptionOrders![index];
                var subtitle = Text(
                    "${optionOrder.state.capitalize()} ${formatDate.format(optionOrder.updatedAt!)}");
                if (optionOrder.optionEvents != null) {
                  var optionEvent = optionOrder.optionEvents!.first;
                  subtitle = Text(
                      "${optionOrder.state.capitalize()} ${formatDate.format(optionOrder.updatedAt!)}\n${optionEvent.type == "expiration" ? "Expired" : (optionEvent.type == "assignment" ? "Assigned" : (optionEvent.type == "exercise" ? "Exercised" : optionEvent.type))} ${formatCompactDate.format(optionOrder.optionEvents!.first.eventDate!)} at ${optionOrder.optionEvents!.first.underlyingPrice != null ? formatCurrency.format(optionOrder.optionEvents!.first.underlyingPrice) : ""}");
                }
                return Card(
                    child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    showShareView
                        ? CheckboxListTile(
                            value: selectedOptionOrdersToShare
                                .contains(filteredOptionOrders![index].id),
                            onChanged: (bool? newValue) {
                              if (newValue!) {
                                setState(() {
                                  selectedOptionOrdersToShare
                                      .add(filteredOptionOrders![index].id);
                                });
                              } else {
                                setState(() {
                                  selectedOptionOrdersToShare
                                      .remove(filteredOptionOrders![index].id);
                                });
                              }
                            },
                            title: Text(
                                "${optionOrder.chainSymbol} \$${formatCompactNumber.format(optionOrder.legs.first.strikePrice)} ${optionOrder.strategy} ${formatCompactDate.format(optionOrder.legs.first.expirationDate!)}"), // , style: TextStyle(fontSize: 18.0)),
                            subtitle: subtitle,
                          )
                        : ListTile(
                            leading: CircleAvatar(
                                //backgroundImage: AssetImage(user.profilePicture),
                                /*
                          backgroundColor: optionOrder.optionEvents != null
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.secondary,
                              */
                                child: optionOrder.optionEvents != null
                                    ? const Icon(Icons.check)
                                    : Text('${optionOrder.quantity!.round()}',
                                        style: const TextStyle(fontSize: 17))),
                            title: Text(
                                "${optionOrder.chainSymbol} \$${formatCompactNumber.format(optionOrder.legs.first.strikePrice)} ${optionOrder.strategy} ${formatCompactDate.format(optionOrder.legs.first.expirationDate!)}"), // , style: TextStyle(fontSize: 18.0)),
                            subtitle: subtitle,
                            trailing: Wrap(spacing: 8, children: [
                              Text(
                                (optionOrder.direction == "credit"
                                        ? "+"
                                        : "-") +
                                    (optionOrder.processedPremium != null
                                        ? formatCurrency.format(
                                            optionOrder.processedPremium)
                                        : ""),
                                style: const TextStyle(fontSize: 18.0),
                                textAlign: TextAlign.right,
                              )
                            ]),

                            isThreeLine: optionOrder.optionEvents != null,
                            onTap: () {
                              /* For navigation within this tab, uncomment
                              widget.navigatorKey!.currentState!.push(
                                  MaterialPageRoute(
                                      builder: (context) => OptionOrderWidget(
                                          widget.user,
                                          widget.account,
                                          optionOrder)));
                                          */
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => OptionOrderWidget(
                                          widget.user,
                                          widget.account!,
                                          optionOrder)));
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
      if (optionEvents != null && filteredOptionEvents != null) {
        slivers.add(SliverStickyHeader(
          header: Material(
              //elevation: 2,
              child: Container(
                  //height: 208.0, //60.0,
                  //padding: EdgeInsets.symmetric(horizontal: 16.0),
                  alignment: Alignment.centerLeft,
                  child: ListTile(
                    title: const Text(
                      "Option Events",
                      style: TextStyle(fontSize: 19.0),
                    ),
                    subtitle: Text(
                        "${formatCompactNumber.format(filteredOptionEvents!.length)} of ${formatCompactNumber.format(optionEvents.length)} orders $orderDateFilterDisplay"),
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
                                  ListTile(
                                    tileColor:
                                        Theme.of(context).colorScheme.primary,
                                    leading: const Icon(Icons.filter_list),
                                    title: const Text(
                                      "Filter Option Events",
                                      style: TextStyle(fontSize: 19.0),
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
                              '${filteredOptionEvents![index].quantity!.round()}',
                              style: const TextStyle(fontSize: 17))),
                      title: Text(
                          "${filteredOptionEvents![index].type} ${formatCompactDate.format(filteredOptionEvents![index].eventDate!)} ${filteredOptionEvents![index].underlyingPrice != null ? formatCurrency.format(filteredOptionEvents![index].underlyingPrice) : ""}"), // , style: TextStyle(fontSize: 18.0)),
                      subtitle: Text(
                          "${filteredOptionEvents![index].state} ${filteredOptionEvents![index].direction} ${filteredOptionEvents![index].state}"),
                      trailing: Wrap(spacing: 8, children: [
                        Text(
                          (filteredOptionEvents![index].direction == "credit"
                                  ? "+"
                                  : "-") +
                              (filteredOptionEvents![index].totalCashAmount !=
                                      null
                                  ? formatCurrency.format(
                                      filteredOptionEvents![index]
                                          .totalCashAmount)
                                  : ""),
                          style: const TextStyle(fontSize: 18.0),
                          textAlign: TextAlign.right,
                        )
                      ]),

                      //isThreeLine: true,
                      onTap: () {
                        () => showDialog<String>(
                            context: context,
                            builder: (BuildContext context) => AlertDialog(
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
                                ));
                      },
                    ),
                  ],
                ));
              },
              childCount: filteredOptionEvents!.length,
            ),
          ),
        ));
        slivers.add(const SliverToBoxAdapter(
            child: SizedBox(
          height: 25.0,
        )));
      }

      if (positionOrders != null) {
        slivers.add(SliverStickyHeader(
          header: Material(
              //elevation: 2,
              child: Container(
                  //height: 208.0, //60.0,
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
                                  ListTile(
                                    tileColor:
                                        Theme.of(context).colorScheme.primary,
                                    leading: const Icon(Icons.filter_list),
                                    title: const Text(
                                      "Filter Stock Orders",
                                      style: TextStyle(fontSize: 19.0),
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
                    showShareView
                        ? CheckboxListTile(
                            value: selectedPositionOrdersToShare
                                .contains(filteredPositionOrders![index].id),
                            onChanged: (bool? newValue) {
                              if (newValue!) {
                                setState(() {
                                  selectedPositionOrdersToShare
                                      .add(filteredPositionOrders![index].id);
                                });
                              } else {
                                setState(() {
                                  selectedPositionOrdersToShare.remove(
                                      filteredPositionOrders![index].id);
                                });
                              }
                            },
                            title: Text(
                                "${filteredPositionOrders![index].instrumentObj != null ? filteredPositionOrders![index].instrumentObj!.symbol : ""} ${filteredPositionOrders![index].type} ${filteredPositionOrders![index].side} ${filteredPositionOrders![index].averagePrice != null ? formatCurrency.format(filteredPositionOrders![index].averagePrice) : ""}"),
                            subtitle: Text(
                                "${filteredPositionOrders![index].state} ${formatDate.format(filteredPositionOrders![index].updatedAt!)}"),
                          )
                        : ListTile(
                            leading: CircleAvatar(
                                //backgroundImage: AssetImage(user.profilePicture),
                                child: Text(
                                    formatCompactNumber.format(
                                        filteredPositionOrders![index]
                                            .quantity!),
                                    style: const TextStyle(fontSize: 17))),
                            title: Text(
                                "${filteredPositionOrders![index].instrumentObj != null ? filteredPositionOrders![index].instrumentObj!.symbol : ""} ${filteredPositionOrders![index].type} ${filteredPositionOrders![index].side} ${filteredPositionOrders![index].averagePrice != null ? formatCurrency.format(filteredPositionOrders![index].averagePrice) : ""}"),
                            subtitle: Text(
                                "${filteredPositionOrders![index].state} ${formatDate.format(filteredPositionOrders![index].updatedAt!)}"),
                            trailing: Wrap(spacing: 8, children: [
                              Text(
                                filteredPositionOrders![index].averagePrice !=
                                        null
                                    ? "${amount > 0 ? "+" : (amount < 0 ? "-" : "")}${formatCurrency.format(amount.abs())}"
                                    : "",
                                style: const TextStyle(fontSize: 18.0),
                                textAlign: TextAlign.right,
                              )
                            ]),

                            //isThreeLine: true,
                            onTap: () {
                              /* For navigation within this tab, uncomment
                              widget.navigatorKey!.currentState!.push(
                                  MaterialPageRoute(
                                      builder: (context) => PositionOrderWidget(
                                          widget.user,
                                          widget.account,
                                          filteredPositionOrders![index])));
                                          */
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => PositionOrderWidget(
                                          widget.user,
                                          widget.account!,
                                          filteredPositionOrders![index])));
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
        slivers.add(const SliverToBoxAdapter(child: DisclaimerWidget()));
      }
    }
    slivers.add(const SliverToBoxAdapter(
        child: SizedBox(
      height: 25.0,
    )));

    return Scaffold(
      body: RefreshIndicator(
        child: CustomScrollView(slivers: slivers), //controller: _controller,
        onRefresh: _pullRefresh,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showShareView,
        tooltip: 'Share Orders',
        child:
            showShareView ? const Icon(Icons.preview) : const Icon(Icons.share),
      ),
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
                  label: const Text('Confirmed'),
                  selected: orderFilters.contains("confirmed"),
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        orderFilters.add("confirmed");
                      } else {
                        orderFilters.removeWhere((String name) {
                          return name == "confirmed";
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

  _closeAndShowShareView() async {
    Navigator.pop(context);
    _showShareView();
  }

  _showShareView() async {
    if (showShareView) {
      var optionOrdersToShare = optionOrders!
          .where((element) => selectedOptionOrdersToShare.contains(element.id));
      var positionOrdersToShare = positionOrders!.where(
          (element) => selectedPositionOrdersToShare.contains(element.id));
      String ordersText = "";
      var optionOrdersMap = optionOrdersToShare.map((e) =>
          "${e.chainSymbol} \$${formatCompactNumber.format(e.legs.first.strikePrice)} ${e.strategy} ${formatCompactDate.format(e.legs.first.expirationDate!)} for ${e.direction == "credit" ? "+" : "-"}${formatCurrency.format(e.processedPremium)} (${e.quantity!.round()} ${e.openingStrategy != null ? e.openingStrategy!.split("_")[0] : e.closingStrategy!.split("_")[0]} contract${e.quantity! > 1 ? "s" : ""} at ${formatCurrency.format(e.price)})");
      var optionOrdersIdMap = optionOrdersToShare.map((e) {
        var splits = e.legs.first.option.split("/");
        return splits[splits.length - 2];
      });
      var positionOrdersMap = positionOrdersToShare.map((e) =>
          "${e.instrumentObj != null ? e.instrumentObj!.symbol : ""} ${e.type} ${e.side} ${e.averagePrice != null ? formatCurrency.format(e.averagePrice) : ""}");
      var positionOrdersIdMap =
          positionOrdersToShare.map((e) => e.instrumentId);
      if (shareText) {
        ordersText += "Here are my";
        if (optionOrdersMap.isNotEmpty) {
          ordersText += " option orders:\n";
        }
        ordersText += optionOrdersMap.join("\n");

        if (positionOrdersMap.isNotEmpty) {
          ordersText += " stock orders:\n";
        }
        ordersText += positionOrdersMap.join("\n");
      }
      if (shareLink) {
        ordersText +=
            "\n\nClick the link to import this data into Robinhood Options Mobile: https://robinhood-options-mobile.web.app/?options=${Uri.encodeComponent(optionOrdersIdMap.join(","))}&positions=${Uri.encodeComponent(positionOrdersIdMap.join(","))}";
      }
      /*
adb shell am start -a android.intent.action.VIEW -c android.intent.category.BROWSABLE -d "https://robinhood-options-mobile.web.app/?options=123"
      */

      await showModalBottomSheet<void>(
        context: context,
        //isScrollControlled: true,
        //useRootNavigator: true,
        //constraints: BoxConstraints(maxHeight: 260),
        builder: (BuildContext context) {
          return Scaffold(
              appBar: AppBar(
                leading: const CloseButton(),
                title: const Text('Sharing Options'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () {
                      Navigator.pop(context);
                      Share.share(ordersText);
                    },
                  )
                ],
              ),
              body: ListView(
                //Column(
                //mainAxisAlignment: MainAxisAlignment.start,
                //crossAxisAlignment: CrossAxisAlignment.center,

                children: [
                  CheckboxListTile(
                    value: shareText,
                    onChanged: (bool? newValue) {
                      setState(() {
                        shareText = newValue!;
                      });
                    },
                    title: const Text(
                        "Share Text"), // , style: TextStyle(fontSize: 18.0)),
                    //subtitle: subtitle,
                  ),
                  CheckboxListTile(
                    value: shareLink,
                    onChanged: (bool? newValue) {
                      setState(() {
                        shareLink = newValue!;
                      });
                    },
                    title: const Text(
                        "Share Link"), // , style: TextStyle(fontSize: 18.0)),
                    //subtitle: subtitle,
                  ),
                  ListTile(
                    subtitle: Text(ordersText,
                        maxLines: 17, overflow: TextOverflow.ellipsis),
                    /*
                                  trailing: TextButton(
                                      child: const Text("APPLY"),
                                      onPressed: () => Navigator.pop(context))*/
                  ),
                ],
              ));
        },
      );
    }
    setState(() {
      showShareView = !showShareView;
    });
  }

  Future<void> _pullRefresh() async {
    setState(() {
      optionEventStream = null;
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
