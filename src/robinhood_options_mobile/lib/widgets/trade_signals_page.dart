import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/trade_signals_provider.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/paywall_widget.dart';
import 'package:robinhood_options_mobile/services/subscription_service.dart';
import 'package:robinhood_options_mobile/widgets/trade_signal_notification_settings_widget.dart';
import 'package:robinhood_options_mobile/widgets/agentic_trading_settings_widget.dart';
import 'package:robinhood_options_mobile/utils/market_hours.dart';
import 'package:robinhood_options_mobile/widgets/trade_signals_widget.dart';

import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

class TradeSignalsPage extends StatefulWidget {
  final User? user;
  final DocumentReference<User>? userDocRef;
  final BrokerageUser? brokerageUser;
  final IBrokerageService? service;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final GenerativeService generativeService;

  const TradeSignalsPage({
    super.key,
    this.user,
    this.userDocRef,
    this.brokerageUser,
    this.service,
    required this.analytics,
    required this.observer,
    required this.generativeService,
  });

  @override
  State<TradeSignalsPage> createState() => _TradeSignalsPageState();
}

class _TradeSignalsPageState extends State<TradeSignalsPage> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  final GlobalKey<TradeSignalsWidgetState> _tradeSignalsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    widget.analytics.logScreenView(screenName: 'TradeSignals');
  }

  @override
  Widget build(BuildContext context) {
    if (widget.user == null || widget.userDocRef == null) {
      return Scaffold(
          appBar: AppBar(
            title: const Text(Constants.appTitle), // Search
            // title: const Text('Trade Signals')
          ),
          body: const Center(
            child: Text("Please login to access Trade Signals"),
          ));
    }

    return StreamBuilder<DocumentSnapshot<User>>(
        stream: widget.userDocRef!.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Scaffold(
                appBar: AppBar(
                  title: const Text(Constants.appTitle),
                  centerTitle: false,
                ),
                body: Center(child: Text('Error: ${snapshot.error}')));
          }

          // Use the latest user data if available, otherwise fallback to widget.user
          User currentUser = widget.user!;
          if (snapshot.hasData &&
              snapshot.data != null &&
              snapshot.data!.data() != null) {
            currentUser = snapshot.data!.data()!;
          }

          bool isSubscribed =
              _subscriptionService.isSubscriptionActive(currentUser);

          if (!isSubscribed) {
            return PaywallWidget(
              user: currentUser,
              userDocRef: widget.userDocRef!,
              onSuccess: () {
                // The stream will naturally update if Firestore is updated.
              },
            );
          }

          return Scaffold(
            body: RefreshIndicator(
              onRefresh: () async {
                _tradeSignalsKey.currentState?.refresh();
              },
              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    title: const Text(Constants.appTitle),
                    centerTitle: false,
                    floating: false,
                    pinned: true,
                    snap: false,
                    actions: _buildActions(context),
                  ),
                  TradeSignalsWidget(
                    key: _tradeSignalsKey,
                    user: currentUser,
                    brokerageUser: widget.brokerageUser,
                    userDocRef: widget.userDocRef,
                    service: widget.service,
                    analytics: widget.analytics,
                    observer: widget.observer,
                    generativeService: widget.generativeService,
                    showHeader: false,
                    useSlivers: true,
                  ),
                ],
              ),
            ),
          );
        });
  }

  List<Widget> _buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.tune),
        tooltip: 'Settings',
        onPressed: () async {
          if (widget.user != null && widget.userDocRef != null) {
            final result = await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => AgenticTradingSettingsWidget(
                  user: widget.user!,
                  userDocRef: widget.userDocRef!,
                  service: widget.service,
                  initialSection: 'entryStrategies',
                ),
              ),
            );
            if (result == true && mounted) {
              _tradeSignalsKey.currentState?.refresh();
            }
          }
        },
      ),
      IconButton(
        icon: const Icon(Icons.notifications_outlined),
        tooltip: 'Notification Settings',
        onPressed: () {
          if (widget.user != null && widget.userDocRef != null) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => TradeSignalNotificationSettingsWidget(
                  user: widget.user!,
                  userDocRef: widget.userDocRef!,
                ),
              ),
            );
          }
        },
      ),
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        tooltip: 'Options',
        itemBuilder: (BuildContext context) {
          final tradeSignalsProvider =
              Provider.of<TradeSignalsProvider>(context, listen: false);
          final isMarketOpen = MarketHours.isMarketOpen();
          final selectedInterval = tradeSignalsProvider.selectedInterval;

          return <PopupMenuEntry<String>>[
            // Subscription Section
            const PopupMenuItem<String>(
              value: 'config:manage_subscription',
              child: Row(
                children: [
                  Icon(Icons.payment),
                  SizedBox(width: 8),
                  Text('Manage Subscription'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            // Sort Section
            const PopupMenuItem<String>(
              enabled: false,
              child: Text(
                'SORT BY',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
            PopupMenuItem<String>(
              value: 'sort:signalStrength',
              child: Row(
                children: [
                  if (tradeSignalsProvider.sortBy == 'signalStrength')
                    Icon(Icons.check, size: 18, color: Colors.green.shade700)
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 8),
                  const Text('Signal Strength'),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'sort:timestamp',
              child: Row(
                children: [
                  if (tradeSignalsProvider.sortBy == 'timestamp')
                    Icon(Icons.check, size: 18, color: Colors.green.shade700)
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 8),
                  const Text('Recent'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            // Interval Section
            PopupMenuItem<String>(
              enabled: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'INTERVAL',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        isMarketOpen ? Icons.access_time : Icons.calendar_today,
                        size: 14,
                        color: isMarketOpen
                            ? Colors.green.shade700
                            : Colors.blue.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isMarketOpen ? 'Market Open' : 'After Hours',
                        style: TextStyle(
                          fontSize: 11,
                          color: isMarketOpen
                              ? Colors.green.shade700
                              : Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'interval:15m',
              child: Row(
                children: [
                  if (selectedInterval == '15m')
                    Icon(Icons.check, size: 18, color: Colors.green.shade700)
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 8),
                  const Text('15-min'),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'interval:1h',
              child: Row(
                children: [
                  if (selectedInterval == '1h')
                    Icon(Icons.check, size: 18, color: Colors.green.shade700)
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 8),
                  const Text('Hourly'),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'interval:1d',
              child: Row(
                children: [
                  if (selectedInterval == '1d')
                    Icon(Icons.check, size: 18, color: Colors.green.shade700)
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 8),
                  const Text('Daily'),
                ],
              ),
            ),
          ];
        },
        onSelected: (String value) async {
          if (widget.user == null || widget.userDocRef == null) return;

          final tradeSignalsProvider = Provider.of<TradeSignalsProvider>(
            context,
            listen: false,
          );
          if (value.startsWith('config:')) {
            if (value == 'config:manage_subscription') {
              if (Platform.isIOS) {
                final Uri url = Uri.parse(
                  'https://apps.apple.com/account/subscriptions',
                );
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                }
              } else if (Platform.isAndroid) {
                final Uri url = Uri.parse(
                  'https://play.google.com/store/account/subscriptions?sku=trade_signals_monthly&package=com.cidevelop.robinhood_options_mobile',
                );
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                }
              }
            }
          } else if (value.startsWith('sort:')) {
            final sortValue = value.split(':')[1];
            tradeSignalsProvider.sortBy = sortValue;
            _tradeSignalsKey.currentState?.refresh();
          } else if (value.startsWith('interval:')) {
            final intervalValue = value.split(':')[1];
            tradeSignalsProvider.setSelectedInterval(intervalValue);
            _tradeSignalsKey.currentState?.refresh();
          }
        },
      ),
    ];
  }
}
