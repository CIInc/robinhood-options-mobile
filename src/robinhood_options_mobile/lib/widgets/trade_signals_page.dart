import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/paywall_widget.dart';
import 'package:robinhood_options_mobile/services/subscription_service.dart';
import 'package:robinhood_options_mobile/widgets/agentic_trading_settings_widget.dart';
import 'package:robinhood_options_mobile/widgets/trade_signals_widget.dart';
import 'package:robinhood_options_mobile/model/trade_strategies.dart';
import 'package:robinhood_options_mobile/model/trade_signal_notifications_store.dart';
import 'package:robinhood_options_mobile/widgets/trade_signal_notifications_page.dart';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/widgets/sliverappbar_widget.dart';
import 'package:robinhood_options_mobile/widgets/offline_status_banner.dart';

class TradeSignalsPage extends StatefulWidget {
  final User? user;
  final DocumentReference<User>? userDocRef;
  final BrokerageUser? brokerageUser;
  final IBrokerageService? service;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final GenerativeService generativeService;
  final Map<String, String>? initialIndicators;
  final TradeStrategyTemplate? strategyTemplate;

  const TradeSignalsPage({
    super.key,
    this.user,
    this.userDocRef,
    this.brokerageUser,
    this.service,
    required this.analytics,
    required this.observer,
    required this.generativeService,
    this.initialIndicators,
    this.strategyTemplate,
  });

  @override
  State<TradeSignalsPage> createState() => _TradeSignalsPageState();
}

class _TradeSignalsPageState extends State<TradeSignalsPage> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  final GlobalKey<TradeSignalsWidgetState> _tradeSignalsKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.analytics.logScreenView(screenName: 'TradeSignals');
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.user == null) {
      return Scaffold(
        body: RefreshIndicator(
          onRefresh: () async {
            _tradeSignalsKey.currentState?.refresh();
          },
          child: CustomScrollView(
            controller: _scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              ExpandedSliverAppBar(
                auth: firebase_auth.FirebaseAuth.instance,
                firestoreService: FirestoreService(),
                automaticallyImplyLeading: true,
                title: Text(widget.strategyTemplate != null
                    ? widget.strategyTemplate!.name
                    : Constants.appTitle),
                analytics: widget.analytics,
                observer: widget.observer,
                user: widget.brokerageUser,
                firestoreUser: null,
                userDocRef: null,
                service: widget.service,
                scrollController: _scrollController,
                onChange: () {
                  _tradeSignalsKey.currentState?.refresh();
                },
                actions: _buildActions(context,
                    isSubscribed: false, currentUser: null),
              ),
              const SliverToBoxAdapter(child: OfflineStatusBanner()),
              SliverToBoxAdapter(
                child: _buildFreemiumBanner(
                  context,
                  isGuest: true,
                  onUnlock: () async {
                    await showProfile(
                        context,
                        firebase_auth.FirebaseAuth.instance,
                        FirestoreService(),
                        widget.analytics,
                        widget.observer,
                        widget.brokerageUser,
                        widget.service);
                  },
                ),
              ),
              TradeSignalsWidget(
                key: _tradeSignalsKey,
                user: null,
                brokerageUser: widget.brokerageUser,
                userDocRef: null,
                service: widget.service,
                analytics: widget.analytics,
                observer: widget.observer,
                generativeService: widget.generativeService,
                showHeader: false,
                useSlivers: true,
                initialIndicators: widget.initialIndicators,
                strategyTemplate: widget.strategyTemplate,
                isSubscribed: false,
                onUpgrade: () async {
                  await showProfile(
                      context,
                      firebase_auth.FirebaseAuth.instance,
                      FirestoreService(),
                      widget.analytics,
                      widget.observer,
                      widget.brokerageUser,
                      widget.service);
                },
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<User>>(
      stream: widget.userDocRef?.snapshots(),
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

        return Scaffold(
          body: RefreshIndicator(
            onRefresh: () async {
              _tradeSignalsKey.currentState?.refresh();
            },
            child: CustomScrollView(
              controller: _scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                ExpandedSliverAppBar(
                  auth: firebase_auth.FirebaseAuth.instance,
                  firestoreService: FirestoreService(),
                  automaticallyImplyLeading: true,
                  title: Text(widget.strategyTemplate != null
                      ? widget.strategyTemplate!.name
                      : Constants.appTitle),
                  analytics: widget.analytics,
                  observer: widget.observer,
                  user: widget.brokerageUser,
                  firestoreUser: currentUser,
                  userDocRef: widget.userDocRef,
                  service: widget.service,
                  scrollController: _scrollController,
                  onChange: () {
                    _tradeSignalsKey.currentState?.refresh();
                  },
                  actions: _buildActions(context,
                      isSubscribed: isSubscribed, currentUser: currentUser),
                ),
                const SliverToBoxAdapter(child: OfflineStatusBanner()),
                if (!isSubscribed)
                  SliverToBoxAdapter(
                    child: _buildFreemiumBanner(
                      context,
                      isGuest: false,
                      onUnlock: () => _openPaywall(context, currentUser),
                    ),
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
                  initialIndicators: widget.initialIndicators,
                  strategyTemplate: widget.strategyTemplate,
                  isSubscribed: isSubscribed,
                  onUpgrade: () => _openPaywall(context, currentUser),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFreemiumBanner(BuildContext context,
      {required bool isGuest, required VoidCallback onUnlock}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: isDark
              ? [
                  theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                  theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.8),
                ]
              : [
                  theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                  theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.bolt,
              color: theme.colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'RealizeAlpha Pro Preview',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'PREVIEW',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimary,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isGuest
                      ? 'Previewing delayed signals. Sign in and subscribe to Pro for real-time alerts and auto-trading.'
                      : 'Previewing sample signals. Unlock Pro for real-time alerts, agentic execution, and full analytics.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color
                        ?.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: onUnlock,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              visualDensity: VisualDensity.compact,
            ),
            child: Text(
              isGuest ? 'Sign In' : 'Unlock Pro',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _openPaywall(BuildContext context, User currentUser) {
    if (widget.userDocRef == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => PaywallWidget(
        user: currentUser,
        userDocRef: widget.userDocRef!,
        onSuccess: () => Navigator.of(ctx).pop(),
        onDismiss: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context,
      {required bool isSubscribed, required User? currentUser}) {
    return [
      Consumer<TradeSignalNotificationsStore>(
        builder: (context, store, child) {
          return IconButton(
            icon: Badge(
              isLabelVisible: store.unreadCount > 0,
              label: Text('${store.unreadCount}'),
              child: const Icon(Icons.notifications_outlined),
            ),
            tooltip: 'Notifications',
            onPressed: () {
              if (!isSubscribed) {
                if (currentUser == null || widget.userDocRef == null) {
                  showProfile(
                      context,
                      firebase_auth.FirebaseAuth.instance,
                      FirestoreService(),
                      widget.analytics,
                      widget.observer,
                      widget.brokerageUser,
                      widget.service);
                } else {
                  _openPaywall(context, currentUser);
                }
                return;
              }
              if (widget.user != null && widget.userDocRef != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => TradeSignalNotificationsPage(
                      user: widget.user!,
                      userDocRef: widget.userDocRef!,
                    ),
                  ),
                );
              }
            },
          );
        },
      ),
      IconButton(
        icon: const Icon(Icons.tune),
        tooltip: 'Settings (My Strategy)',
        onPressed: () async {
          if (!isSubscribed) {
            if (currentUser == null || widget.userDocRef == null) {
              showProfile(
                  context,
                  firebase_auth.FirebaseAuth.instance,
                  FirestoreService(),
                  widget.analytics,
                  widget.observer,
                  widget.brokerageUser,
                  widget.service);
            } else {
              _openPaywall(context, currentUser);
            }
            return;
          }
          if (widget.user != null && widget.userDocRef != null) {
            final result = await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => AgenticTradingSettingsWidget(
                  user: widget.user!,
                  userDocRef: widget.userDocRef!,
                  service: widget.service,
                  // initialSection: 'entryStrategies',
                ),
              ),
            );
            if (result == true && mounted) {
              _tradeSignalsKey.currentState?.refresh();
            }
          }
        },
      ),
      // PopupMenuButton<String>(
      //   icon: const Icon(Icons.more_vert),
      //   tooltip: 'Options',
      //   itemBuilder: (BuildContext context) {
      //     final tradeSignalsProvider =
      //         Provider.of<TradeSignalsProvider>(context, listen: false);

      //     return <PopupMenuEntry<String>>[
      //       // Subscription Section
      //       const PopupMenuItem<String>(
      //         value: 'config:manage_subscription',
      //         child: Row(
      //           children: [
      //             Icon(Icons.payment),
      //             SizedBox(width: 8),
      //             Text('Manage Subscription'),
      //           ],
      //         ),
      //       ),
      //     ];
      //   },
      //   onSelected: (String value) async {
      //     if (widget.user == null || widget.userDocRef == null) return;

      //     final tradeSignalsProvider = Provider.of<TradeSignalsProvider>(
      //       context,
      //       listen: false,
      //     );
      //     if (value.startsWith('config:')) {
      //       if (value == 'config:manage_subscription') {
      //         if (Platform.isIOS) {
      //           final Uri url = Uri.parse(
      //             'https://apps.apple.com/account/subscriptions',
      //           );
      //           if (await canLaunchUrl(url)) {
      //             await launchUrl(url);
      //           }
      //         } else if (Platform.isAndroid) {
      //           final Uri url = Uri.parse(
      //             'https://play.google.com/store/account/subscriptions?sku=trade_signals_monthly&package=com.cidevelop.robinhood_options_mobile',
      //           );
      //           if (await canLaunchUrl(url)) {
      //             await launchUrl(url);
      //           }
      //         }
      //       }
      //     } else if (value.startsWith('interval:')) {
      //       final intervalValue = value.split(':')[1];
      //       tradeSignalsProvider.setSelectedInterval(intervalValue);
      //       _tradeSignalsKey.currentState?.refresh();
      //     }
      //   },
      // ),
    ];
  }
}
