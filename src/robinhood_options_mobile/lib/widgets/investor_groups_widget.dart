import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/investor_group.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/investor_group_detail_widget.dart';
import 'package:robinhood_options_mobile/widgets/investor_group_create_widget.dart';
import 'package:robinhood_options_mobile/widgets/copy_trading_dashboard_widget.dart';
import 'package:robinhood_options_mobile/widgets/sliverappbar_widget.dart';

class InvestorGroupsWidget extends StatelessWidget {
  final FirestoreService firestoreService;
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final User? user;
  final DocumentReference<User>? userDocRef;

  const InvestorGroupsWidget({
    super.key,
    required this.firestoreService,
    required this.brokerageUser,
    required this.service,
    required this.analytics,
    required this.observer,
    this.user,
    this.userDocRef,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            floating: true,
            snap: true,
            pinned: true,
            centerTitle: false,
            title:
                const Text('Investor Groups', style: TextStyle(fontSize: 20.0)),
            actions: [
              IconButton(
                icon: const Icon(Icons.history),
                tooltip: 'Copy Trading History',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CopyTradingDashboardWidget(),
                    ),
                  );
                },
              ),
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
                      observer, brokerageUser, service);
                },
              ),
            ],
            bottom: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.groups), text: 'My Groups'),
                Tab(icon: Icon(Icons.mail_outline), text: 'Invitations'),
                Tab(icon: Icon(Icons.public), text: 'Discover'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          children: [
            _buildMyGroups(context),
            _buildPendingInvitations(context),
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
                  Icon(Icons.groups_outlined,
                      size: 64,
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.6)),
                  const SizedBox(height: 16),
                  const Text('Sign in to join investor groups',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.login),
                    onPressed: () {
                      showProfile(context, auth, firestoreService, analytics,
                          observer, brokerageUser, service);
                    },
                    label: const Text('Sign In'),
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
                      Icon(Icons.groups_outlined,
                          size: 64,
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.6)),
                      const SizedBox(height: 16),
                      const Text('You haven\'t joined any groups yet',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Text('Create a group or discover public groups',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 14)),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final group = groups[index].data();
                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        leading: CircleAvatar(
                          radius: 28,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.2),
                          child: Text(
                            group.name.isNotEmpty
                                ? group.name[0].toUpperCase()
                                : 'G',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary),
                          ),
                        ),
                        title: Text(group.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 16)),
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
                                fontSize: 12,
                                color: Theme.of(context).brightness ==
                                        Brightness.light
                                    ? Colors.grey[700]
                                    : Theme.of(context).colorScheme.secondary,
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

  Widget _buildPendingInvitations(BuildContext context) {
    if (auth.currentUser == null) {
      return CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mail_outline,
                      size: 64,
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.6)),
                  const SizedBox(height: 16),
                  const Text('Sign in to view invitations',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.login),
                    onPressed: () {
                      showProfile(context, auth, firestoreService, analytics,
                          observer, brokerageUser, service);
                    },
                    label: const Text('Sign In'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return StreamBuilder(
      stream: firestoreService.getUserPendingInvitations(auth.currentUser!.uid),
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
                      Icon(Icons.mail_outline,
                          size: 64,
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.6)),
                      const SizedBox(height: 16),
                      const Text('No pending invitations',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Text(
                          'You\'ll see invitations here when group admins invite you',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 14)),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final group = groups[index].data();

                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        leading: CircleAvatar(
                          radius: 28,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.2),
                          child: Text(
                            group.name.isNotEmpty
                                ? group.name[0].toUpperCase()
                                : 'G',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary),
                          ),
                        ),
                        title: Text(group.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 16)),
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
                              'Invitation from group admin',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon:
                                  const Icon(Icons.check, color: Colors.green),
                              tooltip: 'Accept',
                              onPressed: () async {
                                await _acceptInvitation(context, group);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              tooltip: 'Decline',
                              onPressed: () async {
                                await _declineInvitation(context, group);
                              },
                            ),
                          ],
                        ),
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

  Future<void> _acceptInvitation(
      BuildContext context, InvestorGroup group) async {
    if (auth.currentUser == null) return;

    try {
      await firestoreService.acceptGroupInvitation(
          group.id, auth.currentUser!.uid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Joined ${group.name}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error accepting invitation: $e')),
        );
      }
    }
  }

  Future<void> _declineInvitation(
      BuildContext context, InvestorGroup group) async {
    if (auth.currentUser == null) return;

    try {
      await firestoreService.declineGroupInvitation(
          group.id, auth.currentUser!.uid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Declined invitation to ${group.name}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error declining invitation: $e')),
        );
      }
    }
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
                      Icon(Icons.public,
                          size: 64,
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.6)),
                      const SizedBox(height: 16),
                      const Text('No public groups available',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Text('Create the first public group!',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 14)),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final group = groups[index].data();
                    final isMember = auth.currentUser != null &&
                        group.isMember(auth.currentUser!.uid);

                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        leading: CircleAvatar(
                          radius: 28,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.2),
                          child: Text(
                            group.name.isNotEmpty
                                ? group.name[0].toUpperCase()
                                : 'G',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary),
                          ),
                        ),
                        title: Text(group.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 16)),
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
                                fontSize: 12,
                                color: Theme.of(context).brightness ==
                                        Brightness.light
                                    ? Colors.grey[700]
                                    : Theme.of(context).colorScheme.secondary,
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
