import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/watchlist.dart';
import 'package:robinhood_options_mobile/model/watchlist_item.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/disclaimer_widget.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';
import 'package:robinhood_options_mobile/widgets/sliverappbar_widget.dart';

enum SortType { alphabetical, change }

enum SortDirection { asc, desc }

class ListWidget extends StatefulWidget {
  const ListWidget(
      this.user,
      this.service,
      //this.account,
      this.listKey,
      {super.key,
      required this.analytics,
      required this.observer,
      required this.generativeService,
      this.navigatorKey});

  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final GlobalKey<NavigatorState>? navigatorKey;
  final BrokerageUser user;
  final IBrokerageService service;
  final GenerativeService generativeService;
  //final Account account;
  final String listKey;

  @override
  State<ListWidget> createState() => _ListWidgetState();
}

class _ListWidgetState extends State<ListWidget>
    with AutomaticKeepAliveClientMixin<ListWidget> {
  final FirestoreService _firestoreService = FirestoreService();
  Stream<Watchlist>? watchlistStream;
  Watchlist? watchlist;
  SortType? _sortType = SortType.alphabetical;
  SortDirection? _sortDirection = SortDirection.asc;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    widget.analytics.logScreenView(
      screenName: 'List/${widget.listKey}',
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _buildPage();
  }

  Widget _buildPage() {
    if (widget.user.userName == null) {
      return Container();
    }

    watchlistStream ??= widget.service.streamList(
        widget.user,
        Provider.of<InstrumentStore>(context, listen: false),
        Provider.of<QuoteStore>(context, listen: false),
        widget.listKey,
        ownerType: "robinhood");
    return StreamBuilder(
        stream: watchlistStream,
        builder: (context4, watchlistsSnapshot) {
          if (watchlistsSnapshot.hasData) {
            watchlist = watchlistsSnapshot.data!;
            if (_sortType == SortType.alphabetical) {
              watchlist!.items.sort((a, b) =>
                  a.instrumentObj != null && b.instrumentObj != null
                      ? (_sortDirection == SortDirection.asc
                          ? (a.instrumentObj!.symbol
                              .compareTo(b.instrumentObj!.symbol))
                          : (b.instrumentObj!.symbol
                              .compareTo(a.instrumentObj!.symbol)))
                      : 0);
            } else if (_sortType == SortType.change) {
              watchlist!.items.sort((a, b) => a.instrumentObj != null &&
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
    if (watchlist != null) {
      totalItems = watchlist!.items.length;
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
                  "${formatCompactNumber.format(totalItems)} items",
                  style: const TextStyle(fontSize: 16.0, color: Colors.white70),
                )
              ]),
          actions: [
            IconButton(
                icon: auth.currentUser != null
                    ? (auth.currentUser!.photoURL == null
                        ? const Icon(Icons.account_circle)
                        : CircleAvatar(
                            maxRadius: 12,
                            backgroundImage: CachedNetworkImageProvider(
                                auth.currentUser!.photoURL!
                                //  ?? Constants .placeholderImage, // No longer used
                                )))
                    : const Icon(Icons.login),
                onPressed: () async {
                  var response = await showProfile(
                      context,
                      auth,
                      _firestoreService,
                      widget.analytics,
                      widget.observer,
                      widget.user);
                  if (response != null) {
                    setState(() {});
                  }
                }),
            // IconButton(
            //     icon: const Icon(Icons.sort),
            //     onPressed: () {
            //       showModalBottomSheet<void>(
            //         context: context,
            //         showDragHandle: true,
            //         //constraints: BoxConstraints(maxHeight: 260),
            //         builder: (BuildContext context) {
            //           return Column(
            //             mainAxisAlignment: MainAxisAlignment.start,
            //             crossAxisAlignment: CrossAxisAlignment.start,
            //             children: [
            //               ListTile(
            //                 // tileColor: Theme.of(context).colorScheme.primary,
            //                 leading: const Icon(Icons.sort),
            //                 title: const Text(
            //                   "Sort Watch List",
            //                   style: TextStyle(fontSize: 19.0),
            //                 ),
            //                 /*
            //                       trailing: TextButton(
            //                           child: const Text("APPLY"),
            //                           onPressed: () => Navigator.pop(context))*/
            //               ),
            //               Column(
            //                 mainAxisAlignment: MainAxisAlignment.start,
            //                 crossAxisAlignment: CrossAxisAlignment.start,
            //                 children: [
            //                   RadioListTile<SortType>(
            //                     title: const Text('Alphabetical'),
            //                     value: SortType.alphabetical,
            //                     groupValue: _sortType,
            //                     onChanged: (SortType? value) {
            //                       Navigator.pop(context);
            //                       setState(() {
            //                         _sortType = value;
            //                         _sortDirection = SortDirection.desc;
            //                       });
            //                     },
            //                     secondary: _sortType == SortType.alphabetical
            //                         ? IconButton(
            //                             icon: Icon(
            //                                 _sortDirection == SortDirection.desc
            //                                     ? Icons.south
            //                                     : Icons.north),
            //                             onPressed: () {
            //                               Navigator.pop(context, 'dialog');
            //                               setState(() {
            //                                 _sortDirection = _sortDirection ==
            //                                         SortDirection.asc
            //                                     ? SortDirection.desc
            //                                     : SortDirection.asc;
            //                               });
            //                               // showSettings();
            //                             },
            //                           )
            //                         : null,
            //                   ),
            //                   RadioListTile<SortType>(
            //                     title: const Text('Change'),
            //                     value: SortType.change,
            //                     groupValue: _sortType,
            //                     onChanged: (SortType? value) {
            //                       Navigator.pop(context);
            //                       setState(() {
            //                         _sortType = value;
            //                         _sortDirection = SortDirection.asc;
            //                       });
            //                     },
            //                     secondary: _sortType == SortType.change
            //                         ? IconButton(
            //                             icon: Icon(
            //                                 _sortDirection == SortDirection.desc
            //                                     ? Icons.south
            //                                     : Icons.north),
            //                             onPressed: () {
            //                               Navigator.pop(context, 'dialog');
            //                               setState(() {
            //                                 _sortDirection = _sortDirection ==
            //                                         SortDirection.asc
            //                                     ? SortDirection.desc
            //                                     : SortDirection.asc;
            //                               });
            //                               // showSettings();
            //                             },
            //                           )
            //                         : null,
            //                   ),
            //                 ],
            //               )
            //             ],
            //           );
            //         },
            //       );
            //     })
          ],
        ),
        body: CustomScrollView(slivers: [
          SliverStickyHeader(
              header: Material(
                  //elevation: 2,
                  child: Container(
                      //height: 208.0, //60.0,
                      //padding: EdgeInsets.symmetric(horizontal: 16.0),
                      alignment: Alignment.centerLeft,
                      child: ListTile(
                        title: Text(
                          watchlist != null ? watchlist!.displayName : '',
                          style: const TextStyle(fontSize: 19.0),
                        ),
                        subtitle: Text(
                            "${formatCompactNumber.format(watchlist != null ? watchlist!.items.length : 0)} items"),
                        trailing: IconButton(
                            icon: const Icon(Icons.sort),
                            onPressed: () {
                              showModalBottomSheet<void>(
                                context: context,
                                showDragHandle: true,
                                constraints:
                                    const BoxConstraints(maxHeight: 260),
                                builder: (BuildContext context) {
                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ListTile(
                                        // tileColor: Theme.of(context)
                                        //     .colorScheme
                                        //     .primary,
                                        title: const Text(
                                          "Sort Watch List",
                                          style: TextStyle(fontSize: 19.0),
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
                                            secondary: _sortType ==
                                                    SortType.alphabetical
                                                ? IconButton(
                                                    icon: Icon(_sortDirection ==
                                                            SortDirection.desc
                                                        ? Icons.south
                                                        : Icons.north),
                                                    onPressed: () {
                                                      Navigator.pop(
                                                          context, 'dialog');
                                                      setState(() {
                                                        _sortDirection =
                                                            _sortDirection ==
                                                                    SortDirection
                                                                        .asc
                                                                ? SortDirection
                                                                    .desc
                                                                : SortDirection
                                                                    .asc;
                                                      });
                                                      // showSettings();
                                                    },
                                                  )
                                                : null,
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
                                            secondary: _sortType ==
                                                    SortType.change
                                                ? IconButton(
                                                    icon: Icon(_sortDirection ==
                                                            SortDirection.desc
                                                        ? Icons.south
                                                        : Icons.north),
                                                    onPressed: () {
                                                      Navigator.pop(
                                                          context, 'dialog');
                                                      setState(() {
                                                        _sortDirection =
                                                            _sortDirection ==
                                                                    SortDirection
                                                                        .asc
                                                                ? SortDirection
                                                                    .desc
                                                                : SortDirection
                                                                    .asc;
                                                      });
                                                      // showSettings();
                                                    },
                                                  )
                                                : null,
                                          ),
                                        ],
                                      )
                                    ],
                                  );
                                },
                              );
                            }),
                      ))),
              sliver:
                  watchlist != null ? watchListWidget(watchlist!.items) : null),
          const SliverToBoxAdapter(
              child: SizedBox(
            height: 25.0,
          )),
          const SliverToBoxAdapter(child: DisclaimerWidget()),
          const SliverToBoxAdapter(
              child: SizedBox(
            height: 25.0,
          )),
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
            mainAxisSpacing: 2.0,
            crossAxisSpacing: 2.0,
            childAspectRatio: 1.2,
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
      List<WatchlistItem> watchLists, int index, BrokerageUser ru) {
    var instrumentObj = watchLists[index].instrumentObj;
    var forexObj = watchLists[index].forexObj;
    var changePercentToday = 0.0;
    if (forexObj != null) {
      changePercentToday =
          (forexObj.markPrice! - forexObj.openPrice!) / forexObj.openPrice!;
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
                  Text(forexObj.symbol, style: const TextStyle(fontSize: 16.0))
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
                /* For navigation within this tab, uncomment
                widget.navigatorKey!.currentState!.push(MaterialPageRoute(
                    builder: (context) => InstrumentWidget(ru, widget.account,
                        watchLists[index].instrumentObj as Instrument)));
                        */
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => InstrumentWidget(
                              ru,
                              widget.service,
                              watchLists[index].instrumentObj as Instrument,
                              analytics: widget.analytics,
                              observer: widget.observer,
                              generativeService: widget.generativeService,
                            )));
              },
            )));
  }
}
