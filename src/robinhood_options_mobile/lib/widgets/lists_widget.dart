import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/model/watchlist.dart';
import 'package:robinhood_options_mobile/model/watchlist_item.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/ad_banner_widget.dart';
import 'package:robinhood_options_mobile/widgets/disclaimer_widget.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';
import 'package:robinhood_options_mobile/widgets/sliverappbar_widget.dart';

enum SortType { alphabetical, change }

enum SortDirection { asc, desc }

final formatCompactNumber = NumberFormat.compact();
final formatPercentage = NumberFormat.decimalPercentPattern(decimalDigits: 2);

class ListsWidget extends StatefulWidget {
  const ListsWidget(this.brokerageUser, this.service,
      {super.key,
      required this.analytics,
      required this.observer,
      required this.generativeService,
      this.navigatorKey,
      required this.user,
      required this.userDocRef});

  final GlobalKey<NavigatorState>? navigatorKey;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  final GenerativeService generativeService;
  final User? user;
  final DocumentReference<User>? userDocRef;

  @override
  State<ListsWidget> createState() => _ListsWidgetState();
}

class _ListsWidgetState extends State<ListsWidget>
    with AutomaticKeepAliveClientMixin<ListsWidget> {
  final FirestoreService _firestoreService = FirestoreService();

  Stream<List<Watchlist>>? watchlistStream;
  List<Watchlist>? watchlists;
  SortType? _sortType = SortType.alphabetical;
  SortDirection? _sortDirection = SortDirection.desc;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    widget.analytics.logScreenView(
      screenName: 'Lists',
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return PopScope(
        canPop: false, //When false, blocks the current route from being popped.
        onPopInvokedWithResult: (didPop, result) {
          //do your logic here
          // setStatusBarColor(statusBarColorPrimary,statusBarIconBrightness: Brightness.light);
          // do your logic ends
          return;
        },
        child: _buildPage());
  }

  Widget _buildPage() {
    if (widget.brokerageUser.userName == null) {
      return Container();
    }
    watchlistStream ??= widget.service.streamLists(
        widget.brokerageUser,
        Provider.of<InstrumentStore>(context, listen: false),
        Provider.of<QuoteStore>(context, listen: false));
    return StreamBuilder(
        stream: watchlistStream,
        builder: (context4, snapshot) {
          if (snapshot.hasData) {
            watchlists = snapshot.data!;
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
          } else if (snapshot.hasError) {
            debugPrint("${snapshot.error}");
            return _buildScaffold(welcomeWidget: Text("${snapshot.error}"));
          } else {
            // No Watchlists found.
          }
          return _buildScaffold(
              done: snapshot.connectionState == ConnectionState.done);
        });
  }

  Widget _buildScaffold({Widget? welcomeWidget, bool done = false}) {
    var totalItems = 0;
    var totalLists = 0;
    if (watchlists != null) {
      totalLists = watchlists!.length;
      totalItems =
          watchlists!.map((e) => e.items.length).reduce((a, b) => a + b);
    }
    return /*Scaffold(
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
                    showDragHandle: true
                    //constraints: BoxConstraints(maxHeight: 260),
                    builder: (BuildContext context) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            // tileColor: Theme.of(context).colorScheme.primary,
                            leading: const Icon(Icons.sort),
                            title: const Text(
                              "Sort Watch List",
                              style: TextStyle(fontSize: 19.0),
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
        body: */
        CustomScrollView(slivers: [
      SliverAppBar(
        floating: false,
        snap: false,
        pinned: true,
        centerTitle: false,
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
                    widget.brokerageUser);
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
          //                         trailing: TextButton(
          //                             child: const Text("APPLY"),
          //                             onPressed: () => Navigator.pop(context))*/
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
          //                         _sortDirection = SortDirection.asc;
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
          //                     title: const Text('Change (Ascending)'),
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
      if (welcomeWidget != null) ...[
        SliverToBoxAdapter(
            child: SizedBox(
          height: 150.0,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Align(alignment: Alignment.center, child: welcomeWidget),
          ),
        ))
      ],
      if (watchlists != null) ...[
        for (var watchlist in watchlists!) ...[
          SliverStickyHeader(
              header: Material(
                  //elevation: 2,
                  child: Container(
                      //height: 208.0, //60.0,
                      //padding: EdgeInsets.symmetric(horizontal: 16.0),
                      alignment: Alignment.centerLeft,
                      child: ListTile(
                        title: Text(
                          watchlist.displayName,
                          style: const TextStyle(fontSize: 19.0),
                        ),
                        subtitle: Text(
                            "${formatCompactNumber.format(watchlist.items.length)} items"),
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
                        /*
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
                                */
                      ))),
              sliver: watchListWidget(watchlist.items)),
          const SliverToBoxAdapter(
              child: SizedBox(
            height: 25.0,
          )),
        ]
      ],
      // TODO: Introduce web banner
      if (!kIsWeb) ...[
        SliverToBoxAdapter(child: AdBannerWidget(size: AdSize.largeBanner)),
      ],
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
        ;
  }

  Widget watchListWidget(List<WatchlistItem> watchLists) {
    return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220.0,
            mainAxisSpacing: 10.0,
            crossAxisSpacing: 10.0,
            childAspectRatio: 1.25,
          ),
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              return _buildWatchlistGridItem(
                  watchLists, index, widget.brokerageUser);
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
    final isPositive = instrumentObj != null && instrumentObj.quoteObj != null
        ? instrumentObj.quoteObj!.changeToday > 0
        : changePercentToday > 0;
    final isNegative = instrumentObj != null && instrumentObj.quoteObj != null
        ? instrumentObj.quoteObj!.changeToday < 0
        : changePercentToday < 0;

    return Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: BorderSide(
            color: isPositive
                ? Colors.green.withOpacity(0.3)
                : (isNegative
                    ? Colors.red.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.2)),
            width: 1.5,
          ),
        ),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(12.0),
          child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (instrumentObj != null)
                          Expanded(
                            child: Text(instrumentObj.symbol,
                                style: const TextStyle(
                                  fontSize: 18.0,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis),
                          ),
                        if (forexObj != null)
                          Expanded(
                            child: Text(forexObj.symbol,
                                style: const TextStyle(
                                  fontSize: 18.0,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isPositive
                                ? Colors.green.withOpacity(0.15)
                                : (isNegative
                                    ? Colors.red.withOpacity(0.15)
                                    : Colors.grey.withOpacity(0.15)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (instrumentObj != null &&
                                  instrumentObj.quoteObj != null) ...[
                                Icon(
                                    instrumentObj.quoteObj!.changeToday > 0
                                        ? Icons.trending_up
                                        : (instrumentObj.quoteObj!.changeToday <
                                                0
                                            ? Icons.trending_down
                                            : Icons.trending_flat),
                                    color:
                                        (instrumentObj.quoteObj!.changeToday > 0
                                            ? Colors.green
                                            : (instrumentObj
                                                        .quoteObj!.changeToday <
                                                    0
                                                ? Colors.red
                                                : Colors.grey)),
                                    size: 16),
                                const SizedBox(width: 4),
                                Text(
                                    formatPercentage.format(instrumentObj
                                        .quoteObj!.changePercentToday
                                        .abs()),
                                    style: TextStyle(
                                      fontSize: 14.0,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          (instrumentObj.quoteObj!.changeToday >
                                                  0
                                              ? Colors.green
                                              : (instrumentObj.quoteObj!
                                                          .changeToday <
                                                      0
                                                  ? Colors.red
                                                  : Colors.grey)),
                                    )),
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
                                    size: 16),
                                const SizedBox(width: 4),
                                Text(
                                    formatPercentage
                                        .format(changePercentToday.abs()),
                                    style: TextStyle(
                                      fontSize: 14.0,
                                      fontWeight: FontWeight.bold,
                                      color: (changePercentToday > 0
                                          ? Colors.green
                                          : (changePercentToday < 0
                                              ? Colors.red
                                              : Colors.grey)),
                                    )),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (watchLists[index].instrumentObj != null)
                      Text(
                          watchLists[index].instrumentObj!.simpleName ??
                              watchLists[index].instrumentObj!.name,
                          style: TextStyle(
                              fontSize: 12.0, color: Colors.grey.shade600),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis),
                  ])),
          onTap: () {
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
                          user: widget.user,
                          userDocRef: widget.userDocRef,
                        )));
          },
        ));
  }
}
