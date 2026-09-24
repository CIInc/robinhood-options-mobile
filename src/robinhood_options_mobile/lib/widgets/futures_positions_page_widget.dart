import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/auto_trade_status_badge_widget.dart';
import 'package:robinhood_options_mobile/widgets/futures_positions_widget.dart';
import 'package:robinhood_options_mobile/widgets/sliverappbar_widget.dart';

class FuturesPositionsPageWidget extends StatefulWidget {
  const FuturesPositionsPageWidget(
    this.brokerageUser,
    this.service,
    this.futuresPositions, {
    super.key,
    required this.analytics,
    required this.observer,
    required this.generativeService,
    required this.user,
    required this.userDocRef,
  });

  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  final GenerativeService generativeService;
  final List<dynamic> futuresPositions;
  final User? user;
  final DocumentReference<User>? userDocRef;

  @override
  State<FuturesPositionsPageWidget> createState() =>
      _FuturesPositionsPageWidgetState();
}

class _FuturesPositionsPageWidgetState
    extends State<FuturesPositionsPageWidget> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Material(
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            centerTitle: false,
            pinned: true,
            title: const Text('Futures'),
            floating: true,
            snap: true,
            actions: [
              if (auth.currentUser != null)
                AutoTradeStatusBadgeWidget(
                  user: widget.user,
                  userDocRef: widget.userDocRef,
                  service: widget.service,
                  userAvatar: (auth.currentUser!.photoURL ??
                              widget.user?.photoUrl) ==
                          null
                      ? const Icon(Icons.account_circle)
                      : CircleAvatar(
                          maxRadius: 11,
                          backgroundImage: CachedNetworkImageProvider(
                              (auth.currentUser!.photoURL ??
                                  widget.user?.photoUrl)!)),
                  onProfileTap: () {
                    showProfile(
                        context,
                        auth,
                        _firestoreService,
                        widget.analytics,
                        widget.observer,
                        widget.brokerageUser,
                        widget.service);
                  },
                )
              else
                IconButton(
                    icon: const Icon(Icons.account_circle_outlined),
                    onPressed: () {
                      showProfile(
                          context,
                          auth,
                          _firestoreService,
                          widget.analytics,
                          widget.observer,
                          widget.brokerageUser,
                          widget.service);
                    }),
            ],
          ),
          FuturesPositionsWidget(
            widget.brokerageUser,
            widget.service,
            widget.futuresPositions,
            analytics: widget.analytics,
            observer: widget.observer,
            generativeService: widget.generativeService,
            user: widget.user,
            userDocRef: widget.userDocRef,
            showList: true,
            showGroupHeader: false,
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 25.0)),
        ],
      ),
    );
  }
}
