import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/option_positions_widget.dart';
import 'package:robinhood_options_mobile/widgets/more_menu_widget.dart';
import 'package:robinhood_options_mobile/widgets/sliverappbar_widget.dart';

class OptionPositionsPageWidget extends StatefulWidget {
  const OptionPositionsPageWidget(
    this.user,
    this.service,
    //this.account,
    this.filteredPositions, {
    super.key,
    required this.analytics,
    required this.observer,
  });

  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser user;
  final IBrokerageService service;
  //final Account account;
  final List<OptionAggregatePosition> filteredPositions;

  @override
  State<OptionPositionsPageWidget> createState() =>
      _OptionPositionsPageWidgetState();
}

class _OptionPositionsPageWidgetState extends State<OptionPositionsPageWidget> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Material(
        child: CustomScrollView(slivers: [
      SliverAppBar(
        centerTitle: false,
        title: Text("Options"),
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
                    widget.observer, widget.user);
              }),
          IconButton(
              icon: Icon(Icons.more_vert),
              onPressed: () async {
                await showModalBottomSheet<void>(
                    context: context,
                    showDragHandle: true,
                    //isScrollControlled: true,
                    //useRootNavigator: true,
                    //constraints: const BoxConstraints(maxHeight: 200),
                    builder: (_) => MoreMenuBottomSheet(widget.user,
                            analytics: widget.analytics,
                            observer: widget.observer,
                            showOptionsSettings: true,
                            chainSymbols: null,
                            positionSymbols: null,
                            cryptoSymbols: null,
                            optionSymbolFilters: null,
                            stockSymbolFilters: null,
                            cryptoFilters: null, onSettingsChanged: (value) {
                          // debugPrint(
                          //     "Settings changed ${jsonEncode(value)}");
                          debugPrint(
                              "showPositionDetails: ${widget.user.showPositionDetails.toString()}");
                          debugPrint(
                              "displayValue: ${widget.user.displayValue.toString()}");
                          setState(() {});
                        }));
                // Navigator.pop(context);
              })
        ],
      ),
      OptionPositionsWidget(
        widget.user,
        widget.service,
        widget.filteredPositions,
        analytics: widget.analytics,
        observer: widget.observer,
      )
    ]));
  }
}
