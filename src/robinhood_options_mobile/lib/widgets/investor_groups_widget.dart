import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/investor_group.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/widgets/investor_group_detail_widget.dart';
import 'package:robinhood_options_mobile/widgets/investor_group_create_widget.dart';
import 'package:robinhood_options_mobile/widgets/sliverappbar_widget.dart';

class InvestorGroupsWidget extends StatelessWidget {
  final FirestoreService firestoreService;
  final BrokerageUser brokerageUser;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;

  const InvestorGroupsWidget({
    super.key,
    required this.firestoreService,
    required this.brokerageUser,
    required this.analytics,
    required this.observer,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            floating: true,
            snap: true,
            pinned: true,
            centerTitle: false,
            title: const Text('Investor Groups',
                style: TextStyle(fontSize: 20.0)),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () async {
                  if (auth.currentUser == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please sign in to create a group'),
                      ),
                    );
                    return;
                  }
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => InvestorGroupCreateWidget(
                        firestoreService: firestoreService,
                        analytics: analytics,
                        observer: observer,
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
                onPressed: () async {
                  await showProfile(context, auth, firestoreService, analytics,
                      observer, brokerageUser);
                },
              ),
            ],
            bottom: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.groups), text: 'My Groups'),
                Tab(icon: Icon(Icons.public), text: 'Discover'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          children: [
            _buildMyGroups(context),
            _buildPublicGroups(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMyGroups(BuildContext context) {
    if (auth.currentUser == null) {
      return CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.groups_outlined, size: 64),
                  const SizedBox(height: 16),
                  const Text('Sign in to join investor groups'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      showProfile(context, auth, firestoreService, analytics,
                          observer, brokerageUser);
                    },
                    child: const Text('Sign In'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return StreamBuilder(
      stream: firestoreService.getUserInvestorGroups(auth.currentUser!.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.size == 0) {
          return CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.groups_outlined, size: 64),
                      const SizedBox(height: 16),
                      const Text('You haven\'t joined any groups yet'),
                      const SizedBox(height: 8),
                      const Text('Create a group or discover public groups',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        final groups = snapshot.data!.docs;
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(8.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final group = groups[index].data();
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            group.name.isNotEmpty
                                ? group.name[0].toUpperCase()
                                : 'G',
                          ),
                        ),
                        title: Text(group.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (group.description != null)
                              Text(
                                group.description!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            Text(
                              '${group.members.length} members',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.secondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        trailing: group.isPrivate
                            ? const Icon(Icons.lock, size: 16)
                            : const Icon(Icons.public, size: 16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => InvestorGroupDetailWidget(
                                groupId: group.id,
                                firestoreService: firestoreService,
                                brokerageUser: brokerageUser,
                                analytics: analytics,
                                observer: observer,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  childCount: groups.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPublicGroups(BuildContext context) {
    return StreamBuilder(
      stream: firestoreService.getPublicInvestorGroups(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.size == 0) {
          return CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.public, size: 64),
                      const SizedBox(height: 16),
                      const Text('No public groups available'),
                      const SizedBox(height: 8),
                      const Text('Create the first public group!',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        final groups = snapshot.data!.docs;
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(8.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final group = groups[index].data();
                    final isMember = auth.currentUser != null &&
                        group.isMember(auth.currentUser!.uid);

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            group.name.isNotEmpty
                                ? group.name[0].toUpperCase()
                                : 'G',
                          ),
                        ),
                        title: Text(group.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (group.description != null)
                              Text(
                                group.description!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            Text(
                              '${group.members.length} members',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.secondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        trailing: isMember
                            ? Chip(
                                label: const Text('Joined',
                                    style: TextStyle(fontSize: 12)),
                                backgroundColor:
                                    Theme.of(context).colorScheme.primary,
                                labelStyle: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimary),
                              )
                            : null,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => InvestorGroupDetailWidget(
                                groupId: group.id,
                                firestoreService: firestoreService,
                                brokerageUser: brokerageUser,
                                analytics: analytics,
                                observer: observer,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  childCount: groups.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
