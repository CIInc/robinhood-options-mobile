import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/forex_holding.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/auto_trade_status_badge_widget.dart';
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
    this.generativeService,
    this.user,
    this.userDocRef,
  });

  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  //final Account account;
  final List<ForexHolding> filteredPositions;
  final GenerativeService? generativeService;
  final User? user;
  final DocumentReference<User>? userDocRef;

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
        pinned: true,
        actions: [
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
                              auth.currentUser!.photoURL!)))
                  : const Icon(Icons.account_circle_outlined),
              onPressed: () {
                showProfile(context, auth, _firestoreService, widget.analytics,
                    widget.observer, widget.brokerageUser, widget.service);
              }),
        ],
      ),
      ForexPositionsWidget(
        widget.brokerageUser,
        widget.service,
        widget.filteredPositions,
        analytics: widget.analytics,
        observer: widget.observer,
        generativeService: widget.generativeService,
        user: widget.user,
        userDocRef: widget.userDocRef,
      )
    ]));
  }
}
