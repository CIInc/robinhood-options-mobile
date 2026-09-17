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
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/sliverappbar_widget.dart';
import 'package:robinhood_options_mobile/widgets/top_portfolios_leaderboard_widget.dart';
import 'package:robinhood_options_mobile/widgets/user_listtile_widget.dart';

class UsersWidget extends StatefulWidget {
  final firebase_auth.FirebaseAuth auth;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  const UsersWidget(
    this.auth,
    this.service, {
    super.key,
    required this.analytics,
    required this.observer,
    required this.brokerageUser,
  });

  @override
  State<UsersWidget> createState() => _UsersWidgetState();
}

class _UsersWidgetState extends State<UsersWidget> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchTermController = TextEditingController();
  String? _searchTerm;
  // late CollectionReference<User> _usersCollection;
  late Stream<QuerySnapshot<User>> _stream;

  @override
  void initState() {
    super.initState();
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
          return Scaffold(
            body: CustomScrollView(slivers: [
              SliverAppBar(
                  floating: true,
                  snap: true,
                  pinned: false,
                  centerTitle: false,
                  title: const Text('Discover Traders'),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.leaderboard_rounded),
                      tooltip: 'Top Portfolios Leaderboard',
                      onPressed: () {
                        widget.analytics.logEvent(
                            name: 'top_portfolios_leaderboard_opened');
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                TopPortfoliosLeaderboardWidget(
                              auth: widget.auth,
                              firestoreService: _firestoreService,
                              brokerageUser: widget.brokerageUser,
                              service: widget.service,
                              analytics: widget.analytics,
                              observer: widget.observer,
                            ),
                          ),
                        );
                      },
                    ),
                    IconButton(
                        icon: auth.currentUser != null
                            ? (auth.currentUser!.photoURL == null
                                ? const Icon(Icons.account_circle)
                                : CircleAvatar(
                                    maxRadius: 12,
                                    backgroundImage: CachedNetworkImageProvider(
                                        auth.currentUser!.photoURL!)))
                            : const Icon(Icons.login),
                        onPressed: () {
                          showProfile(
                              context,
                              widget.auth,
                              _firestoreService,
                              widget.analytics,
                              widget.observer,
                              widget.brokerageUser,
                              widget.service);
                        })
                  ]),
              SliverPadding(
                  padding: const EdgeInsets.all(16.0),
                  sliver: SliverToBoxAdapter(
                      child: Column(
                    children: [
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: Theme.of(context)
                                .colorScheme
                                .outlineVariant
                                .withValues(alpha: 0.5),
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            widget.analytics.logEvent(
                                name: 'users_widget_leaderboard_banner_tapped');
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    TopPortfoliosLeaderboardWidget(
                                  auth: widget.auth,
                                  firestoreService: _firestoreService,
                                  brokerageUser: widget.brokerageUser,
                                  service: widget.service,
                                  analytics: widget.analytics,
                                  observer: widget.observer,
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 12.0),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.emoji_events_rounded,
                                    color: Colors.amber,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Top Portfolios Leaderboard',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'View ranked traders, track records & credibility',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 16,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      CupertinoSearchTextField(
                        style: TextStyle(
                            color:
                                Theme.of(context).textTheme.bodyLarge!.color),
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
                      ),
                    ],
                  ))),
              StreamBuilder(
                  stream: _stream,
                  builder:
                      (context, AsyncSnapshot<QuerySnapshot<User>> snapshot) {
                    if (snapshot.hasError) {
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
                      return const SliverToBoxAdapter(
                          child: Center(child: CircularProgressIndicator()));
                    }
                    return showSliverList(snapshot.data!);
                  }),
              const SliverToBoxAdapter(child: SizedBox(height: 20.0)),
            ]),
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
}
