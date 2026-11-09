import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/portfolio_privacy_settings.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/auto_trade_status_badge_widget.dart';
import 'package:robinhood_options_mobile/widgets/sliverappbar_widget.dart';
import 'package:robinhood_options_mobile/widgets/user_listtile_widget.dart';

class UsersWidget extends StatefulWidget {
  final firebase_auth.FirebaseAuth auth;
  final IBrokerageService? service;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser? brokerageUser;
  final FirestoreService? firestoreService;
  final User? user;
  final DocumentReference<User>? userDocRef;
  final bool showAppBar;
  const UsersWidget(
    this.auth,
    this.service, {
    super.key,
    required this.analytics,
    required this.observer,
    this.brokerageUser,
    this.firestoreService,
    this.user,
    this.userDocRef,
    this.showAppBar = true,
  });

  @override
  State<UsersWidget> createState() => _UsersWidgetState();
}

class _UsersWidgetState extends State<UsersWidget> {
  late final FirestoreService _firestoreService;
  final TextEditingController _searchTermController = TextEditingController();
  String? _searchTerm;
  // late CollectionReference<User> _usersCollection;
  late Stream<QuerySnapshot<User>> _stream;

  bool get _isDemo =>
      widget.brokerageUser?.source == BrokerageSource.demo ||
      widget.service is DemoService;

  @override
  void initState() {
    super.initState();
    _firestoreService = widget.firestoreService ?? FirestoreService();
    // _usersCollection = _firestoreService.userCollection;

    final onlyPublic = userRole != UserRole.admin;
    _stream = _firestoreService.searchUsers(
      searchTerm: _searchTerm,
      onlyPublic: onlyPublic,
    );
  }

  @override
  void dispose() {
    _searchTermController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<firebase_auth.User?>(
        stream: widget.auth.authStateChanges(),
        builder: (context, snapshot) {
          final auth = widget.auth;
          final scrollView = CustomScrollView(slivers: [
            if (widget.showAppBar)
              SliverAppBar(
                  floating: true,
                  snap: true,
                  pinned: false,
                  centerTitle: false,
                  title: const Text('Discover Traders'),
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
                          if (widget.brokerageUser != null &&
                              widget.service != null) {
                            showProfile(
                                context,
                                widget.auth,
                                _firestoreService,
                                widget.analytics,
                                widget.observer,
                                widget.brokerageUser!,
                                widget.service!);
                          }
                        },
                      )
                    else
                      IconButton(
                          icon: const Icon(Icons.account_circle_outlined),
                          onPressed: () {
                            if (widget.brokerageUser != null &&
                                widget.service != null) {
                              showProfile(
                                  context,
                                  widget.auth,
                                  _firestoreService,
                                  widget.analytics,
                                  widget.observer,
                                  widget.brokerageUser!,
                                  widget.service!);
                            }
                          }),
                  ]),
            SliverPadding(
                padding: const EdgeInsets.all(16.0),
                sliver: SliverToBoxAdapter(
                    child: CupertinoSearchTextField(
                  style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge!.color),
                  controller: _searchTermController,
                  placeholder: 'Search traders by name',
                  onChanged: (value) {
                    setState(() {
                      _searchTerm = value;
                      final onlyPublic = userRole != UserRole.admin;
                      _stream = _firestoreService.searchUsers(
                        searchTerm: _searchTerm,
                        onlyPublic: onlyPublic,
                      );
                    });
                  },
                ))),
            StreamBuilder(
                stream: _stream,
                builder:
                    (context, AsyncSnapshot<QuerySnapshot<User>> snapshot) {
                  if (snapshot.hasError) {
                    if (_isDemo) {
                      return showSliverListWithUsers(_generateMockUsers());
                    }
                    return SliverToBoxAdapter(
                        child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.info_outline,
                                size: 40,
                                color: Theme.of(context).colorScheme.outline),
                            const SizedBox(height: 12),
                            Text(
                              'Unable to load traders',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              '${snapshot.error}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.outline,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    if (_isDemo) {
                      return showSliverListWithUsers(_generateMockUsers());
                    }
                    return const SliverToBoxAdapter(
                        child: Center(child: CircularProgressIndicator()));
                  }

                  if ((snapshot.data == null || snapshot.data!.docs.isEmpty) &&
                      _isDemo) {
                    return showSliverListWithUsers(_generateMockUsers());
                  }

                  return showSliverList(snapshot.data!);
                }),
            const SliverToBoxAdapter(child: SizedBox(height: 20.0)),
          ]);
          if (!widget.showAppBar) {
            return Material(
              type: MaterialType.transparency,
              child: scrollView,
            );
          }
          return Scaffold(
            body: scrollView,
          );
        });
  }

  Widget showSliverList(QuerySnapshot<User> querySnapshot) {
    final theme = Theme.of(context);
    return querySnapshot.docs.isNotEmpty
        ? SliverList(
            delegate:
                SliverChildBuilderDelegate((BuildContext context, int index) {
              QueryDocumentSnapshot<User> document = querySnapshot.docs[index];
              return UserListTile(
                  document: document,
                  analytics: widget.analytics,
                  observer: widget.observer,
                  brokerageUser: widget.brokerageUser,
                  service: widget.service);
            }, childCount: querySnapshot.docs.length),
          )
        : SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people_outline,
                        size: 48, color: theme.disabledColor),
                    const SizedBox(height: 16),
                    Text(
                      'No public traders found',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Traders must enable "Public Portfolio" in their privacy settings to be discoverable.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.disabledColor),
                    ),
                  ],
                ),
              ),
            ),
          );
  }

  Widget showSliverListWithUsers(Map<String, User> mockUsers) {
    final theme = Theme.of(context);
    final filteredEntries = mockUsers.entries.where((entry) {
      if (_searchTerm == null || _searchTerm!.trim().isEmpty) return true;
      final q = _searchTerm!.trim().toLowerCase();
      final name = (entry.value.name ?? '').toLowerCase();
      final loc = (entry.value.location ?? '').toLowerCase();
      return name.contains(q) || loc.contains(q);
    }).toList();

    return filteredEntries.isNotEmpty
        ? SliverList(
            delegate:
                SliverChildBuilderDelegate((BuildContext context, int index) {
              final entry = filteredEntries[index];
              return UserListTile(
                  user: entry.value,
                  userId: entry.key,
                  analytics: widget.analytics,
                  observer: widget.observer,
                  brokerageUser: widget.brokerageUser,
                  service: widget.service);
            }, childCount: filteredEntries.length),
          )
        : SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people_outline,
                        size: 48, color: theme.disabledColor),
                    const SizedBox(height: 16),
                    Text(
                      'No public traders found',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Traders must enable "Public Portfolio" in their privacy settings to be discoverable.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.disabledColor),
                    ),
                  ],
                ),
              ),
            ),
          );
  }

  Map<String, User> _generateMockUsers() {
    return {
      'demo_user_1': User(
        name: 'AlphaHunter',
        location: 'New York, NY',
        followersCount: 342,
        followingCount: 18,
        dateCreated: DateTime.now().subtract(const Duration(days: 120)),
        devices: const [],
        brokerageUsers: const [],
        portfolioPrivacy: const PortfolioPrivacySettings(isPublic: true),
      ),
      'demo_user_2': User(
        name: 'QuantumTheta',
        location: 'Chicago, IL',
        followersCount: 215,
        followingCount: 12,
        dateCreated: DateTime.now().subtract(const Duration(days: 95)),
        devices: const [],
        brokerageUsers: const [],
        portfolioPrivacy: const PortfolioPrivacySettings(isPublic: true),
      ),
      'demo_user_3': User(
        name: 'VolHarvester',
        location: 'San Francisco, CA',
        followersCount: 168,
        followingCount: 25,
        dateCreated: DateTime.now().subtract(const Duration(days: 80)),
        devices: const [],
        brokerageUsers: const [],
        portfolioPrivacy: const PortfolioPrivacySettings(isPublic: true),
      ),
    };
  }
}
