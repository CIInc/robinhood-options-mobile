import 'package:flutter/material.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/robinhood_user.dart';
import 'package:robinhood_options_mobile/model/watchlist.dart';
import 'package:robinhood_options_mobile/model/watchlist_item.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';

enum SortType { alphabetical, change }
enum SortDirection { asc, desc }

final formatCompactNumber = NumberFormat.compact();
final formatPercentage = NumberFormat.decimalPercentPattern(decimalDigits: 2);

class ListsWidget extends StatefulWidget {
  const ListsWidget(this.user, {Key? key, this.navigatorKey}) : super(key: key);

  final GlobalKey<NavigatorState>? navigatorKey;
  final RobinhoodUser user;

  @override
  _ListsWidgetState createState() => _ListsWidgetState();
}

class _ListsWidgetState extends State<ListsWidget>
    with AutomaticKeepAliveClientMixin<ListsWidget> {
  Stream<List<Watchlist>>? watchlistStream;
  List<Watchlist>? watchlists;
  SortType? _sortType = SortType.alphabetical;
  SortDirection? _sortDirection = SortDirection.desc;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return WillPopScope(
      onWillPop: () => Future.value(false),
      child: Scaffold(
          //appBar: _buildFlowAppBar(),
          body: Navigator(
              key: widget.navigatorKey,
              onGenerateRoute: (_) =>
                  MaterialPageRoute(builder: (_) => _buildPage()))),
    );
  }

  Widget _buildPage() {
    if (widget.user.userName == null) {
      return Container();
    }
    watchlistStream ??= RobinhoodService.streamLists(widget.user);
    return StreamBuilder(
        stream: watchlistStream,
        builder: (context4, watchlistsSnapshot) {
          if (watchlistsSnapshot.hasData) {
            watchlists = watchlistsSnapshot.data! as List<Watchlist>;
            for (var watchList in watchlists!) {
              if (_sortType == SortType.alphabetical) {
                watchList.items.sort((a, b) =>
                    a.instrumentObj != null && b.instrumentObj != null
                        ? (_sortDirection == SortDirection.asc
                            ? (a.instrumentObj!.symbol
                                .compareTo(b.instrumentObj!.symbol))
                            : (b.instrumentObj!.symbol
                                .compareTo(a.instrumentObj!.symbol)))
                        : 0);
              } else if (_sortType == SortType.change) {
                watchList.items.sort((a, b) => a.instrumentObj != null &&
                        b.instrumentObj != null
                    ? (_sortDirection == SortDirection.asc
                        ? (b.instrumentObj!.quoteObj!.changePercentToday
                            .compareTo(
                                a.instrumentObj!.quoteObj!.changePercentToday))
                        : (a.instrumentObj!.quoteObj!.changePercentToday
                            .compareTo(
                                b.instrumentObj!.quoteObj!.changePercentToday)))
                    : 0);
              }
            }
            //return _buildScaffold();
          } else if (watchlistsSnapshot.hasError) {
            debugPrint("${watchlistsSnapshot.error}");
          } else {
            // No Watchlists found.
          }
          return _buildScaffold();
        });
  }

  Widget _buildScaffold() {
    var totalItems = 0;
    var totalLists = 0;
    if (watchlists != null) {
      totalLists = watchlists!.length;
      totalItems =
          watchlists!.map((e) => e.items.length).reduce((a, b) => a + b);
    }
    return Scaffold(
        appBar: AppBar(
          title: Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              //runAlignment: WrapAlignment.end,
              //alignment: WrapAlignment.end,
              spacing: 20,
              //runSpacing: 5,
              children: [
                const Text('Lists', style: TextStyle(fontSize: 20.0)),
                Text(
                  "${formatCompactNumber.format(totalItems)} items in ${formatCompactNumber.format(totalLists)} lists",
                  style: const TextStyle(fontSize: 16.0, color: Colors.white70),
                )
              ]),
          actions: [
            IconButton(
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
                            tileColor: Theme.of(context).colorScheme.primary,
                            leading: const Icon(Icons.sort),
                            title: const Text(
                              "Sort Watch List",
                              style: TextStyle(
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
                        ],
                      );
                    },
                  );
                })
          ],
        ),
        body: CustomScrollView(slivers: [
          /*
                  SliverStickyHeader(
                      header: Material(
                          elevation: 2,
                          child: Container(
                              //height: 208.0, //60.0,
                              color: Colors.white,
                              //padding: EdgeInsets.symmetric(horizontal: 16.0),
                              alignment: Alignment.centerLeft,
                              child: ListTile(
                                title: const Text(
                                  "Lists",
                                  style: TextStyle(
                                      //color: Colors.white,
                                      fontSize: 19.0),
                                ),
                                subtitle: Text(
                                    "${formatCompactNumber.format(watchlists!.length)} items"),
                                trailing: IconButton(
                                    icon: const Icon(Icons.sort),
                                    onPressed: () {
                                      showModalBottomSheet<void>(
                                        context: context,
                                        //constraints: BoxConstraints(maxHeight: 260),
                                        builder: (BuildContext context) {
                                          return Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              ListTile(
                                                tileColor: Theme.of(context).colorScheme.primary,
                                                title: const Text(
                                                  "Sort Watch List",
                                                  style: TextStyle(
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
                                                    value:
                                                        SortType.alphabetical,
                                                    groupValue: _sortType,
                                                    onChanged:
                                                        (SortType? value) {
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
                                                    value:
                                                        SortType.alphabetical,
                                                    groupValue: _sortType,
                                                    onChanged:
                                                        (SortType? value) {
                                                      Navigator.pop(context);
                                                      setState(() {
                                                        _sortType = value;
                                                        _sortDirection =
                                                            SortDirection.desc;
                                                      });
                                                    },
                                                  ),
                                                  RadioListTile<SortType>(
                                                    title: const Text(
                                                        'Change (Ascending)'),
                                                    value: SortType.change,
                                                    groupValue: _sortType,
                                                    onChanged:
                                                        (SortType? value) {
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
                                                        'Change (Descending)'),
                                                    value: SortType.change,
                                                    groupValue: _sortType,
                                                    onChanged:
                                                        (SortType? value) {
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
                      sliver: SliverToBoxAdapter(child: Container())),
                      */
          if (watchlists != null) ...[
            for (var watchlist in watchlists!) ...[
              SliverStickyHeader(
                  header: Material(
                      elevation: 2,
                      child: Container(
                          //height: 208.0, //60.0,
                          //padding: EdgeInsets.symmetric(horizontal: 16.0),
                          alignment: Alignment.centerLeft,
                          child: ListTile(
                            title: Text(
                              watchlist.displayName,
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
                                    constraints:
                                        const BoxConstraints(maxHeight: 260),
                                    builder: (BuildContext context) {
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
                                            title: const Text(
                                              "Sort Watch List",
                                              style: TextStyle(
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
                                                title:
                                                    const Text('Alphabetical'),
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
                  sliver: watchListWidget(watchlist.items))
            ]
          ]
        ])

        /*body: Builder(builder: (context) {
          return Text("Lists");
        })*/
        /*
        body: new FutureBuilder(
            future: futureOptionPosition,
            builder: (context, AsyncSnapshot<OptionPosition> snapshot) {
              if (snapshot.hasData) {
                return _buildPosition(snapshot.data);
              } else if (snapshot.hasError) {
                print("${snapshot.error}");
                return Text("${snapshot.error}");
              }
              // By default, show a loading spinner
              return Center(
                child: CircularProgressIndicator(),
              );
            }));
            */
        );
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
              return _buildWatchlistGridItem(watchLists, index, widget.user);
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

  Widget _buildWatchlistGridItem(
      List<WatchlistItem> watchLists, int index, RobinhoodUser ru) {
    var instrumentObj = watchLists[index].instrumentObj;
    var forexObj = watchLists[index].forexObj;
    var changePercentToday = 0.0;
    if (forexObj != null) {
      changePercentToday = (double.parse(forexObj["mark_price"]) -
              double.parse(forexObj["open_price"])) /
          double.parse(forexObj["open_price"]);
    }
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(6), //.symmetric(horizontal: 6),
            child: InkWell(
              child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                if (instrumentObj != null) ...[
                  Text(instrumentObj.symbol,
                      style: const TextStyle(fontSize: 16.0)),
                ],
                if (forexObj != null) ...[
                  Text(forexObj!["symbol"],
                      style: const TextStyle(fontSize: 16.0))
                ],
                Wrap(
                  children: [
                    if (instrumentObj != null &&
                        instrumentObj.quoteObj != null) ...[
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
                    if (forexObj != null) ...[
                      Icon(
                          changePercentToday > 0
                              ? Icons.trending_up
                              : (changePercentToday < 0
                                  ? Icons.trending_down
                                  : Icons.trending_flat),
                          color: (changePercentToday > 0
                              ? Colors.green
                              : (changePercentToday < 0
                                  ? Colors.red
                                  : Colors.grey)),
                          size: 20),
                    ],
                    Container(
                      width: 2,
                    ),
                    if (instrumentObj != null &&
                        instrumentObj.quoteObj != null) ...[
                      Text(
                          formatPercentage.format(
                              instrumentObj.quoteObj!.changePercentToday.abs()),
                          style: const TextStyle(fontSize: 16.0)),
                    ],
                    if (forexObj != null) ...[
                      Text(formatPercentage.format(changePercentToday.abs()),
                          style: const TextStyle(fontSize: 16.0)),
                    ],
                  ],
                ),
                Container(
                  height: 5,
                ),
                Wrap(children: [
                  if (watchLists[index].instrumentObj != null) ...[
                    Text(
                        watchLists[index].instrumentObj!.simpleName ??
                            watchLists[index].instrumentObj!.name,
                        style: const TextStyle(fontSize: 12.0),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis)
                  ],
                ]),
              ]),
              onTap: () {
                widget.navigatorKey!.currentState!.push(MaterialPageRoute(
                    builder: (context) => InstrumentWidget(
                        ru, watchLists[index].instrumentObj as Instrument)));
                /*
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => InstrumentWidget(ru,
                            watchLists[index].instrumentObj as Instrument)));
                            */
              },
            )));
  }
}
