import 'package:flutter/material.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/midlands_movers_item.dart';

import 'package:robinhood_options_mobile/model/robinhood_user.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
import 'package:robinhood_options_mobile/widgets/disclaimer_widget.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';

final formatDate = DateFormat("yMMMd");
final formatCurrency = NumberFormat.simpleCurrency();
final formatPercentage = NumberFormat.decimalPercentPattern(decimalDigits: 2);

class SearchWidget extends StatefulWidget {
  final RobinhoodUser user;
  final Account? account;

  const SearchWidget(this.user, this.account, {Key? key, this.navigatorKey})
      : super(key: key);

  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  State<SearchWidget> createState() => _SearchWidgetState();
}

class _SearchWidgetState extends State<SearchWidget>
    with AutomaticKeepAliveClientMixin<SearchWidget> {
  String? query;
  TextEditingController? searchCtl;
  Future<dynamic>? futureSearch;
  Future<List<MidlandMoversItem>>? futureMovers;
  Future<List<MidlandMoversItem>>? futureLosers;
  Future<List<Instrument>>? futureListMovers;
  Future<List<Instrument>>? futureListMostPopular;

  InstrumentStore? instrumentStore;

  _SearchWidgetState();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    searchCtl = TextEditingController();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

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
    instrumentStore = Provider.of<InstrumentStore>(context, listen: false);

    futureMovers ??= RobinhoodService.getMovers(widget.user, direction: "up");
    futureLosers ??= RobinhoodService.getMovers(widget.user, direction: "down");
    futureListMovers ??=
        RobinhoodService.getListMovers(widget.user, instrumentStore!);
    futureListMostPopular ??=
        RobinhoodService.getListMostPopular(widget.user, instrumentStore!);
    futureSearch ??= Future.value(null);

    return FutureBuilder(
        future: Future.wait([
          futureSearch as Future,
          futureMovers as Future,
          futureLosers as Future,
          futureListMovers as Future,
          futureListMostPopular as Future,
        ]),
        builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
          if (snapshot.hasData) {
            List<dynamic> data = snapshot.data as List<dynamic>;
            var search = data.isNotEmpty ? data[0] as dynamic : null;
            var movers =
                data.length > 1 ? data[1] as List<MidlandMoversItem> : null;
            var losers =
                data.length > 2 ? data[2] as List<MidlandMoversItem> : null;
            var listMovers =
                data.length > 3 ? data[3] as List<Instrument> : null;
            var listMostPopular =
                data.length > 4 ? data[4] as List<Instrument> : null;
            return _buildPage(
                search: search,
                movers: movers,
                losers: losers,
                listMovers: listMovers,
                listMostPopular: listMostPopular,
                done: snapshot.connectionState == ConnectionState.done);
          } else {
            return _buildPage(
                done: snapshot.connectionState == ConnectionState.done);
          }
        });
  }

  Widget _buildPage(
      {dynamic search,
      List<MidlandMoversItem>? movers,
      List<MidlandMoversItem>? losers,
      List<Instrument>? listMovers,
      List<Instrument>? listMostPopular,
      bool done = false}) {
    return RefreshIndicator(
        onRefresh: _pullRefresh,
        child: GestureDetector(
            onTap: () {
              FocusScopeNode currentFocus = FocusScope.of(context);

              if (!currentFocus.hasPrimaryFocus) {
                currentFocus.unfocus();
              }
            },
            child: CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverAppBar(
                    title: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
                        child: TextField(
                            controller: searchCtl,
                            decoration: InputDecoration(
                              hintText: 'Search by name or symbol',
                              hintStyle: TextStyle(
                                  fontSize: 18, color: Colors.grey.shade200
                                  //fontStyle: FontStyle.italic,
                                  ),
                            ),
                            style: TextStyle(
                                fontSize: 18, color: Colors.grey.shade200
                                //fontStyle: FontStyle.italic,
                                ),
                            onChanged: (text) {
                              setState(() {
                                futureSearch =
                                    RobinhoodService.search(widget.user, text);
                              });
                            })),
                    //expandedHeight: 80.0,
                    pinned: true,
                  ),
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
                  if (search != null) ...[
                    SliverStickyHeader(
                        header: Material(
                            //elevation: 2,
                            child: Container(
                                alignment: Alignment.centerLeft,
                                child: const ListTile(
                                  title: Text(
                                    "Search Results",
                                    style: TextStyle(fontSize: 19.0),
                                  ),
                                  //subtitle: Text(
                                  //    "${formatCompactNumber.format(filteredPositionOrders!.length)} of ${formatCompactNumber.format(positionOrders.length)} orders $orderDateFilterDisplay ${positionOrdersBalance > 0 ? "+" : positionOrdersBalance < 0 ? "-" : ""}${formatCurrency.format(positionOrdersBalance.abs())}"),
                                ))),
                        sliver: SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 120.0,
                                mainAxisSpacing: 10.0,
                                crossAxisSpacing: 10.0,
                                childAspectRatio: 1.25,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (BuildContext context, int index) {
                                  return _buildSearchGridItem(search, index);
                                },
                                childCount: search["results"][0]["content"]
                                        ["data"]
                                    .length,
                              ),
                            ))),
                    const SliverToBoxAdapter(
                        child: SizedBox(
                      height: 25.0,
                    )),
                  ],
                  if (movers != null && movers.isNotEmpty) ...[
                    SliverStickyHeader(
                        header: Material(
                            //elevation: 2,
                            child: Container(
                                alignment: Alignment.centerLeft,
                                child: ListTile(
                                  title: Wrap(children: const [
                                    Text(
                                      "S&P Movers",
                                      style: TextStyle(fontSize: 19.0),
                                    ),
                                    Icon(Icons.trending_up,
                                        color: Colors.green, size: 28)
                                  ]),
                                ))),
                        sliver: SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 200.0,
                                mainAxisSpacing: 10.0,
                                crossAxisSpacing: 10.0,
                                childAspectRatio: 1.5,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (BuildContext context, int index) {
                                  return _buildMoversGridItem(movers, index);
                                },
                                childCount: movers.length,
                              ),
                            ))),
                    const SliverToBoxAdapter(
                        child: SizedBox(
                      height: 25.0,
                    )),
                  ],
                  if (losers != null && losers.isNotEmpty) ...[
                    SliverStickyHeader(
                        header: Material(
                            //elevation: 2,
                            child: Container(
                                alignment: Alignment.centerLeft,
                                child: ListTile(
                                  title: Wrap(children: const [
                                    Text(
                                      "S&P Movers",
                                      style: TextStyle(fontSize: 19.0),
                                    ),
                                    Icon(Icons.trending_down,
                                        color: Colors.red, size: 28)
                                  ]),
                                ))),
                        sliver: SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 200.0,
                                mainAxisSpacing: 10.0,
                                crossAxisSpacing: 10.0,
                                childAspectRatio: 1.5,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (BuildContext context, int index) {
                                  return _buildMoversGridItem(losers, index);
                                },
                                childCount: losers.length,
                              ),
                            ))),
                    const SliverToBoxAdapter(
                        child: SizedBox(
                      height: 25.0,
                    )),
                  ],
                  if (listMovers != null && listMovers.isNotEmpty) ...[
                    SliverStickyHeader(
                        header: Material(
                            //elevation: 2,
                            child: Container(
                                alignment: Alignment.centerLeft,
                                child: ListTile(
                                  title: Wrap(children: const [
                                    Text(
                                      "Top Movers",
                                      style: TextStyle(fontSize: 19.0),
                                    ),
                                  ]),
                                ))),
                        sliver: SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 150.0,
                                mainAxisSpacing: 6.0,
                                crossAxisSpacing: 2.0,
                                childAspectRatio: 1.3,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (BuildContext context, int index) {
                                  return _buildListGridItem(
                                      listMovers, index, widget.user);
                                },
                                childCount: listMovers.length,
                              ),
                            ))),
                    const SliverToBoxAdapter(
                        child: SizedBox(
                      height: 25.0,
                    )),
                  ],
                  if (listMostPopular != null &&
                      listMostPopular.isNotEmpty) ...[
                    SliverStickyHeader(
                        header: Material(
                            //elevation: 2,
                            child: Container(
                                alignment: Alignment.centerLeft,
                                child: ListTile(
                                  title: Wrap(children: const [
                                    Text(
                                      "100 Most Popular",
                                      style: TextStyle(fontSize: 19.0),
                                    ),
                                  ]),
                                ))),
                        sliver: SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 150.0,
                                mainAxisSpacing: 6.0,
                                crossAxisSpacing: 2.0,
                                childAspectRatio: 1.3,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (BuildContext context, int index) {
                                  return _buildListGridItem(
                                      listMostPopular, index, widget.user);
                                },
                                childCount: listMostPopular.length,
                              ),
                            ))),
                    const SliverToBoxAdapter(
                        child: SizedBox(
                      height: 25.0,
                    )),
                  ],
                  const SliverToBoxAdapter(child: DisclaimerWidget())
                ])));
  }

  Future<void> _pullRefresh() async {
    setState(() {
      futureMovers = null;
      futureLosers = null;
      futureListMovers = null;
      futureListMostPopular = null;
      futureSearch = Future.value(null);
    });
  }

  Widget _buildMoversGridItem(List<MidlandMoversItem> movers, int index) {
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(6), //.symmetric(horizontal: 6),
            child: InkWell(
              child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                Text(movers[index].symbol,
                    style: const TextStyle(fontSize: 16.0)),
                Wrap(
                  children: [
                    Icon(
                        movers[index].marketHoursPriceMovement! > 0
                            ? Icons.trending_up
                            : (movers[index].marketHoursPriceMovement! < 0
                                ? Icons.trending_down
                                : Icons.trending_flat),
                        color: (movers[index].marketHoursPriceMovement! > 0
                            ? Colors.green
                            : (movers[index].marketHoursPriceMovement! < 0
                                ? Colors.red
                                : Colors.grey)),
                        size: 20),
                    Container(
                      width: 2,
                    ),
                    Text(
                        formatPercentage.format(
                            movers[index].marketHoursPriceMovement!.abs() /
                                100),
                        style: const TextStyle(fontSize: 16.0)),
                    Container(
                      width: 10,
                    ),
                    Text(
                        formatCurrency
                            .format(movers[index].marketHoursLastPrice),
                        style: const TextStyle(fontSize: 16.0)),
                  ],
                ),
                Container(
                  height: 5,
                ),
                Wrap(children: [
                  Text(movers[index].description,
                      style: const TextStyle(fontSize: 12.0),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis)
                ]),
              ]),
              onTap: () async {
                var instrument = await RobinhoodService.getInstrument(
                    widget.user, instrumentStore!, movers[index].instrumentUrl);

                /* For navigation within this tab, uncomment
                widget.navigatorKey!.currentState!.push(MaterialPageRoute(
                    builder: (context) => InstrumentWidget(ru, widget.account,
                        watchLists[index].instrumentObj as Instrument)));
                        */
                if (!mounted) return;
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => InstrumentWidget(
                            widget.user,
                            //widget.account!,
                            instrument)));
              },
            )));
  }

  Widget _buildSearchGridItem(dynamic search, int index) {
    var data = search["results"][0]["content"]["data"][index];
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(6), //.symmetric(horizontal: 6),
            child: InkWell(
                child:
                    Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                  Text(data["item"]["symbol"],
                      style: const TextStyle(fontSize: 16.0)),
                  Text(data["item"]["simple_name"] ?? data["item"]["name"],
                      style: const TextStyle(fontSize: 12.0),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis)
                ]),
                onTap: () {
                  var instrument = Instrument.fromJson(data["item"]);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => InstrumentWidget(
                              widget.user,
                              //widget.account!,
                              instrument)));
                })));
    /*
    return ListTile(
      title: Text(data["item"]["symbol"]),
      subtitle: Text(data["item"]["simple_name"] ?? data["item"]["name"]),
      onTap: () {
        var instrument = Instrument.fromJson(data["item"]);
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    InstrumentWidget(widget.user, widget.account, instrument)));
      },
    );
    */
  }

  Widget _buildListGridItem(
      List<Instrument> instruments, int index, RobinhoodUser user) {
    var instrumentObj = instruments[index];
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(6), //.symmetric(horizontal: 6),
            child: InkWell(
              child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                Text(instrumentObj.symbol,
                    style: const TextStyle(fontSize: 16.0)),
                Wrap(
                  children: [
                    if (instrumentObj.quoteObj != null) ...[
                      Icon(
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
                          size: 20),
                    ],
                    Container(
                      width: 2,
                    ),
                    if (instrumentObj.quoteObj != null) ...[
                      Text(
                          formatPercentage.format(
                              instrumentObj.quoteObj!.changePercentToday.abs()),
                          style: const TextStyle(fontSize: 16.0)),
                    ],
                  ],
                ),
                Container(
                  height: 5,
                ),
                Wrap(children: [
                  Text(instrumentObj.simpleName ?? instrumentObj.name,
                      style: const TextStyle(fontSize: 12.0),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis)
                ]),
                /*
                if (instrumentObj.fundamentalsObj != null) ...[
                  Container(
                    height: 5,
                  ),
                  Wrap(children: [
                    Text(instrumentObj.fundamentalsObj!.description,
                        style: const TextStyle(fontSize: 12.0),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis)
                  ]),
                ]
                  */
              ]),
              onTap: () {
                /* For navigation within this tab, uncomment
                widget.navigatorKey!.currentState!.push(MaterialPageRoute(
                    builder: (context) => InstrumentWidget(ru, widget.account,
                        watchLists[index].instrumentObj as Instrument)));
                        */
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => InstrumentWidget(
                            user,
                            //widget.account!,
                            instrumentObj)));
              },
            )));
  }
}
