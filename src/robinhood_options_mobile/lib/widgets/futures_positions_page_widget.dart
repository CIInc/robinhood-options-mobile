import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/futures_positions_widget.dart';

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
  // final FirestoreService _firestoreService = FirestoreService();

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
