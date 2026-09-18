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
import 'package:robinhood_options_mobile/widgets/user_listtile_widget.dart';

class UsersWidget extends StatefulWidget {
  final firebase_auth.FirebaseAuth auth;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  final FirestoreService? firestoreService;
  const UsersWidget(
    this.auth,
    this.service, {
    super.key,
    required this.analytics,
    required this.observer,
    required this.brokerageUser,
    this.firestoreService,
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
                      child: CupertinoSearchTextField(
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
