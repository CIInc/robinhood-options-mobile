import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/widgets/sliverappbar_widget.dart';
import 'package:robinhood_options_mobile/widgets/user_listtile_widget.dart';

class UsersWidget extends StatefulWidget {
  final firebase_auth.FirebaseAuth auth;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser brokerageUser;
  const UsersWidget(
    this.auth, {
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

    _stream = _firestoreService.searchUsers(searchTerm: _searchTerm);
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
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            body: CustomScrollView(slivers: [
              SliverAppBar(
                  floating: true,
                  snap: true,
                  pinned: false,
                  centerTitle: false,
                  title: const Text('Users'),
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
                          showProfile(
                              context,
                              widget.auth,
                              _firestoreService,
                              widget.analytics,
                              widget.observer,
                              widget.brokerageUser);
                        })
                  ]),
              SliverPadding(
                  padding: const EdgeInsets.all(16.0),
                  sliver: SliverToBoxAdapter(
                      child: Column(
                    children: [
                      CupertinoSearchTextField(
                        style: TextStyle(
                            color:
                                Theme.of(context).textTheme.bodyLarge!.color),
                        controller: _searchTermController,
                        placeholder: 'Search',
                        onChanged: (value) {
                          setState(() {
                            _searchTerm = value;
                            _stream = _firestoreService.searchUsers(
                                searchTerm: _searchTerm);
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
                          child: Center(
                              child: SelectableText(
                                  'Something went wrong\n${snapshot.error}')));
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
    return querySnapshot.docs.isNotEmpty
        ? SliverList(
            delegate:
                SliverChildBuilderDelegate((BuildContext context, int index) {
              QueryDocumentSnapshot<User> document = querySnapshot.docs[index];
              return UserListTile(
                  document: document,
                  analytics: widget.analytics,
                  observer: widget.observer,
                  brokerageUser: widget.brokerageUser);
            }, childCount: querySnapshot.docs.length),
          )
        : const SliverToBoxAdapter(
            child: Center(
                child: Column(children: [
            SizedBox(
              height: 20,
            ),
            Text('No users')
          ])));
  }
}
