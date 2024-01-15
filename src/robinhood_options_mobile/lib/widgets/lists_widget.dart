import 'dart:io' show Platform;
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';
import 'package:robinhood_options_mobile/model/robinhood_user.dart';
import 'package:robinhood_options_mobile/model/watchlist.dart';
import 'package:robinhood_options_mobile/model/watchlist_item.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
import 'package:robinhood_options_mobile/widgets/disclaimer_widget.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';

enum SortType { alphabetical, change }

enum SortDirection { asc, desc }

final formatCompactNumber = NumberFormat.compact();
final formatPercentage = NumberFormat.decimalPercentPattern(decimalDigits: 2);

class ListsWidget extends StatefulWidget {
  const ListsWidget(this.user,
      {super.key,
      required this.analytics,
      required this.observer,
      this.navigatorKey});

  final GlobalKey<NavigatorState>? navigatorKey;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final RobinhoodUser user;

  @override
  State<ListsWidget> createState() => _ListsWidgetState();
}

class _ListsWidgetState extends State<ListsWidget>
    with AutomaticKeepAliveClientMixin<ListsWidget> {
  Stream<List<Watchlist>>? watchlistStream;
  List<Watchlist>? watchlists;
  SortType? _sortType = SortType.alphabetical;
  SortDirection? _sortDirection = SortDirection.desc;

  final BannerAd myBanner = BannerAd(
    adUnitId: kDebugMode
        ? Constants.testAdUnit
        : (Platform.isAndroid
            ? Constants.homeBannerAndroidAdUnit
            : Constants.homeBanneriOSAdUnit),
    size: AdSize.largeBanner,
    request: const AdRequest(),
    listener: const BannerAdListener(),
  );

  final BannerAdListener listener = BannerAdListener(
    // Called when an ad is successfully received.
    onAdLoaded: (Ad ad) => debugPrint('Ad loaded.'),
    // Called when an ad request failed.
    onAdFailedToLoad: (Ad ad, LoadAdError error) {
      // Dispose the ad here to free resources.
      ad.dispose();
      debugPrint('Ad failed to load: $error');
    },
    // Called when an ad opens an overlay that covers the screen.
    onAdOpened: (Ad ad) => debugPrint('Ad opened.'),
    // Called when an ad removes an overlay that covers the screen.
    onAdClosed: (Ad ad) => debugPrint('Ad closed.'),
    // Called when an impression occurs on the ad.
    onAdImpression: (Ad ad) => debugPrint('Ad impression.'),
  );

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    widget.analytics.setCurrentScreen(
      screenName: 'Lists',
    );
    myBanner.load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return PopScope(
        canPop: false, //When false, blocks the current route from being popped.
        onPopInvoked: (didPop) {
          //do your logic here
          // setStatusBarColor(statusBarColorPrimary,statusBarIconBrightness: Brightness.light);
          // do your logic ends
          return;
        },
        child: _buildPage());
  }

  Widget _buildPage() {
    if (widget.user.userName == null) {
      return Container();
    }
    watchlistStream ??= RobinhoodService.streamLists(
        widget.user,
        Provider.of<InstrumentStore>(context, listen: false),
        Provider.of<QuoteStore>(context, listen: false));
    return StreamBuilder(
        stream: watchlistStream,
        builder: (context4, watchlistsSnapshot) {
          if (watchlistsSnapshot.hasData) {
            watchlists = watchlistsSnapshot.data!;
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
          return _buildScaffold(
              done: watchlistsSnapshot.connectionState == ConnectionState.done);
        });
  }

  Widget _buildScaffold({bool done = false}) {
    final AdWidget adWidget = AdWidget(ad: myBanner);
    final Container adContainer = Container(
      alignment: Alignment.center,
      width: myBanner.size.width.toDouble(),
      height: myBanner.size.height.toDouble(),
      child: adWidget,
    );

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
        pinned: true,
        snap: false,
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
      SliverToBoxAdapter(child: adContainer),
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
            maxCrossAxisExtent: 150.0,
            mainAxisSpacing: 6.0,
            crossAxisSpacing: 2.0,
            childAspectRatio: 1.22,
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
                    builder: (context) => InstrumentWidget(ru,
                        watchLists[index].instrumentObj as Instrument)));
                        */
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => InstrumentWidget(
                              ru,
                              watchLists[index].instrumentObj as Instrument,
                              analytics: widget.analytics,
                              observer: widget.observer,
                            )));
              },
            )));
  }
}
