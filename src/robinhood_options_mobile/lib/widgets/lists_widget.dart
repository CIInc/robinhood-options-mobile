import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/main.dart';
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
import 'package:robinhood_options_mobile/widgets/auto_trade_status_badge_widget.dart';
import 'package:robinhood_options_mobile/widgets/disclaimer_widget.dart';
import 'package:robinhood_options_mobile/widgets/watchlist_grid_item_widget.dart';
import 'package:robinhood_options_mobile/widgets/sliverappbar_widget.dart';

enum SortType { alphabetical, change }

enum SortDirection { asc, desc }

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

    return _buildPage();
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

  void _showCreateListDialog() {
    final TextEditingController nameController = TextEditingController();
    String selectedEmoji = "💡";
    final List<String> emojis = [
      "💡",
      "🔥",
      "🚀",
      "💰",
      "📈",
      "📉",
      "👀",
      "❤️",
      "⭐",
      "⚠️"
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text("Create New List"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: "List Name"),
                ),
                const SizedBox(height: 16),
                const Text("Select Icon"),
                Wrap(
                  spacing: 8.0,
                  children: emojis.map((emoji) {
                    return ChoiceChip(
                      label: Text(emoji, style: const TextStyle(fontSize: 24)),
                      selected: selectedEmoji == emoji,
                      onSelected: (bool selected) {
                        setStateDialog(() {
                          selectedEmoji = emoji;
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                child: const Text("Cancel"),
                onPressed: () => Navigator.pop(context),
              ),
              TextButton(
                child: const Text("Create"),
                onPressed: () async {
                  if (nameController.text.isNotEmpty) {
                    try {
                      await widget.service.createList(
                          widget.brokerageUser, nameController.text,
                          emoji: selectedEmoji);
                      if (context.mounted) {
                        Navigator.pop(context);
                        setState(() {
                          watchlistStream = widget.service.streamLists(
                              widget.brokerageUser,
                              Provider.of<InstrumentStore>(context,
                                  listen: false),
                              Provider.of<QuoteStore>(context, listen: false));
                        });
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text("Error: $e")));
                      }
                    }
                  }
                },
              ),
            ],
          );
        });
      },
    );
  }

  Widget _buildScaffold({Widget? welcomeWidget, bool done = false}) {
    /*
    var totalItems = 0;
    var totalLists = 0;
    if (watchlists != null) {
      totalLists = watchlists!.length;
      totalItems =
          watchlists!.map((e) => e.items.length).reduce((a, b) => a + b);
    }
    */
    return Scaffold(
        body: CustomScrollView(slivers: [
      SliverAppBar(
        floating: false,
        snap: false,
        pinned: true,
        centerTitle: false,
        // title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        //   const Text('Lists', style: TextStyle(fontSize: 20.0)),
        //   Text(
        //     "${formatCompactNumber.format(totalItems)} items in ${formatCompactNumber.format(totalLists)} lists",
        //     style: const TextStyle(fontSize: 16.0),
        //   )
        // ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateListDialog,
          ),
          if (auth.currentUser != null)
            AutoTradeStatusBadgeWidget(
              user: widget.user,
              userDocRef: widget.userDocRef,
              service: widget.service,
            ),
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
                    widget.brokerageUser,
                    widget.service);
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
                        leading: watchlist.iconEmoji != null
                            ? Text(
                                watchlist.iconEmoji!,
                                style: const TextStyle(fontSize: 32),
                              )
                            : null,
                        title: Text(
                          // "${watchlist.iconEmoji ?? ''} ${watchlist.displayName}".trim()
                          watchlist.displayName.trim(),
                          style: const TextStyle(fontSize: 20.0),
                        ),
                        subtitle: Text(
                            "${formatCompactNumber.format(watchlist.items.length)} items"),
                        trailing: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert),
                            onSelected: (value) {
                              if (value == 'sort') {
                                showModalBottomSheet<void>(
                                  context: context,
                                  showDragHandle: true,
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
                                          // tileColor: Theme.of(context)
                                          //     .colorScheme
                                          //     .primary,
                                          title: const Text(
                                            "Sort Watch List",
                                            style: TextStyle(fontSize: 20.0),
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
                                                      icon: Icon(
                                                          _sortDirection ==
                                                                  SortDirection
                                                                      .desc
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
                                                      icon: Icon(
                                                          _sortDirection ==
                                                                  SortDirection
                                                                      .desc
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
                              } else if (value == 'delete') {
                                showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: const Text("Delete List"),
                                        content: Text(
                                            "Are you sure you want to delete ${watchlist.displayName}?"),
                                        actions: [
                                          TextButton(
                                            child: const Text("Cancel"),
                                            onPressed: () =>
                                                Navigator.of(context).pop(),
                                          ),
                                          TextButton(
                                            child: const Text("Delete"),
                                            onPressed: () async {
                                              Navigator.of(context).pop();
                                              await widget.service.deleteList(
                                                  widget.brokerageUser,
                                                  watchlist.id);
                                              setState(() {
                                                watchlistStream = null;
                                              });
                                            },
                                          ),
                                        ],
                                      );
                                    });
                              }
                            },
                            itemBuilder: (BuildContext context) =>
                                <PopupMenuEntry<String>>[
                                  const PopupMenuItem<String>(
                                    value: 'sort',
                                    child: ListTile(
                                      leading: Icon(Icons.sort),
                                      title: Text('Sort'),
                                    ),
                                  ),
                                  const PopupMenuItem<String>(
                                    value: 'delete',
                                    child: ListTile(
                                      leading: Icon(Icons.delete),
                                      title: Text('Delete'),
                                    ),
                                  ),
                                ]),
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
    ]));
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
              return WatchlistGridItemWidget(
                  watchLists[index],
                  widget.brokerageUser,
                  widget.service,
                  widget.analytics,
                  widget.observer,
                  widget.generativeService,
                  widget.user,
                  widget.userDocRef);
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
}
