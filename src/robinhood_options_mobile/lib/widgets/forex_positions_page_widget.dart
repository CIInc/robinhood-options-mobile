import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/forex_holding.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/forex_positions_widget.dart';
import 'package:robinhood_options_mobile/widgets/sliverappbar_widget.dart';

class ForexPositionsPageWidget extends StatefulWidget {
  const ForexPositionsPageWidget(
    this.brokerageUser,
    this.service,
    //this.account,
    this.filteredPositions, {
    super.key,
    required this.analytics,
    required this.observer,
  });

  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  //final Account account;
  final List<ForexHolding> filteredPositions;

  @override
  State<ForexPositionsPageWidget> createState() =>
      _ForexPositionsPageWidgetState();
}

class _ForexPositionsPageWidgetState extends State<ForexPositionsPageWidget> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Material(
        child: CustomScrollView(slivers: [
      SliverAppBar(
        centerTitle: false,
        title: Text("Crypto"),
        floating: true,
        snap: true,
        pinned: false,
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
              onPressed: () {
                showProfile(context, auth, _firestoreService, widget.analytics,
                    widget.observer, widget.brokerageUser, widget.service);
              }),
          // IconButton(
          //     icon: Icon(Icons.more_vert),
          //     onPressed: () async {
          //       await showModalBottomSheet<void>(
          //           context: context,
          //           showDragHandle: true,
          //           //isScrollControlled: true,
          //           //useRootNavigator: true,
          //           //constraints: const BoxConstraints(maxHeight: 200),
          //           builder: (_) => MoreMenuBottomSheet(widget.user,
          //                   analytics: widget.analytics,
          //                   observer: widget.observer,
          //                   showStockSettings: true,
          //                   showCryptoSettings: true,
          //                   chainSymbols: null,
          //                   positionSymbols: null,
          //                   cryptoSymbols: null,
          //                   optionSymbolFilters: null,
          //                   stockSymbolFilters: null,
          //                   cryptoFilters: null, onSettingsChanged: (value) {
          //                 // debugPrint(
          //                 //     "Settings changed ${jsonEncode(value)}");
          //                 debugPrint(
          //                     "showPositionDetails: ${widget.user.showPositionDetails.toString()}");
          //                 debugPrint(
          //                     "displayValue: ${widget.user.displayValue.toString()}");
          //                 setState(() {});
          //               }
          //               )
          //               );
          //       // Navigator.pop(context);
          //     })
        ],
      ),
      ForexPositionsWidget(
        widget.brokerageUser,
        widget.service,
        widget.filteredPositions,
        analytics: widget.analytics,
        observer: widget.observer,
      )
    ]));
  }
}
