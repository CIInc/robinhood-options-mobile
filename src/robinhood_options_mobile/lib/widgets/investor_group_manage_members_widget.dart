import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/extensions.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/investor_group.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/investor_groups_member_detail_widget.dart';
import 'package:robinhood_options_mobile/widgets/trader_profile_widget.dart';
import 'package:robinhood_options_mobile/widgets/user_widget.dart';

class InvestorGroupManageMembersWidget extends StatefulWidget {
  final String groupId;
  final InvestorGroup group;
  final FirestoreService firestoreService;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final IBrokerageService? service;
  final BrokerageUser? brokerageUser;

  const InvestorGroupManageMembersWidget({
    super.key,
    required this.groupId,
    required this.group,
    required this.firestoreService,
    required this.analytics,
    required this.observer,
    this.service,
    this.brokerageUser,
  });

  @override
  State<InvestorGroupManageMembersWidget> createState() =>
      _InvestorGroupManageMembersWidgetState();
}

class _InvestorGroupManageMembersWidgetState
    extends State<InvestorGroupManageMembersWidget>
    with SingleTickerProviderStateMixin {
  final TextEditingController _inviteSearchController = TextEditingController();
  final TextEditingController _memberSearchController = TextEditingController();
  String? _searchTerm;
  String _memberSearchTerm = '';
  late Stream<QuerySnapshot<User>> _userStream;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _userStream = widget.firestoreService.searchUsers(searchTerm: _searchTerm);
  }

  @override
  void dispose() {
    _inviteSearchController.dispose();
    _memberSearchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _navigateToMemberDetail(User user, String userId, String groupRole) {
    final userDoc = widget.firestoreService.userCollection.doc(userId);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InvestorGroupsMemberDetailWidget(
          user: user,
          userDoc: userDoc,
          brokerageService: widget.service,
          firestoreService: widget.firestoreService,
          currentUser: widget.brokerageUser,
          groupRole: groupRole,
          analytics: widget.analytics,
          observer: widget.observer,
        ),
      ),
    );
  }

  void _navigateToProfile(String userId, String displayName) {
    final isSelf = auth.currentUser?.uid == userId;
    if (isSelf) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: Text(displayName),
            ),
            body: UserWidget(
              auth,
              userId: userId,
              isProfileView: true,
              analytics: widget.analytics,
              observer: widget.observer,
              brokerageUser: widget.brokerageUser,
              service: widget.service,
            ),
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TraderProfileWidget(
            auth: auth,
            userId: userId,
            analytics: widget.analytics,
            observer: widget.observer,
            brokerageUser: widget.brokerageUser,
            service: widget.service,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<InvestorGroup?>(
      stream: widget.firestoreService.investorGroupCollection
          .doc(widget.groupId)
          .snapshots()
          .map((snapshot) => snapshot.data()),
      builder: (context, snapshot) {
        final group = snapshot.data ?? widget.group;
        final memberCount = group.members.length;
        final pendingCount = group.pendingInvitations?.length ?? 0;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Manage Members'),
            bottom: TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  icon: const Icon(Icons.people),
                  text: 'Members ($memberCount)',
                ),
                Tab(
                  icon: const Icon(Icons.mail_outline),
                  text: 'Pending ($pendingCount)',
                ),
                const Tab(
                  icon: Icon(Icons.person_add),
                  text: 'Invite',
                ),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildMembersList(group),
              _buildPendingInvitations(group),
              _buildInviteUsers(group),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMembersList(InvestorGroup group) {
    if (group.members.isEmpty) {
      return const Center(child: Text('No members'));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: CupertinoSearchTextField(
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
            controller: _memberSearchController,
            placeholder: 'Filter active members',
            onChanged: (value) {
              setState(() {
                _memberSearchTerm = value.trim().toLowerCase();
              });
            },
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: group.members.length,
            itemBuilder: (context, index) {
              final userId = group.members[index];
              final isCreator = userId == group.createdBy;
              final isAdmin = group.isAdmin(userId);
              final isCurrentUser = auth.currentUser?.uid == userId;

              return FutureBuilder<DocumentSnapshot<User>>(
                future: widget.firestoreService.userCollection.doc(userId).get(),
                builder: (context, userSnapshot) {
                  String displayName = 'User';
                  String? subtitle;
                  User? user;
                  Widget avatar = const CircleAvatar(
                    radius: 20,
                    child: Icon(Icons.account_circle),
                  );

                  if (userSnapshot.hasData && userSnapshot.data!.exists) {
                    user = userSnapshot.data!.data();
                    displayName = user?.name ?? 'Guest';
                    subtitle = user?.email ?? user?.phoneNumber ?? '';
                    if (user?.photoUrl != null) {
                      avatar = CircleAvatar(
                        radius: 20,
                        backgroundImage:
                            CachedNetworkImageProvider(user!.photoUrl!),
                      );
                    }
                  }

                  if (_memberSearchTerm.isNotEmpty) {
                    final matches = displayName
                            .toLowerCase()
                            .contains(_memberSearchTerm) ||
                        (subtitle?.toLowerCase().contains(_memberSearchTerm) ??
                            false);
                    if (!matches) {
                      return const SizedBox.shrink();
                    }
                  }

                  final roleText = isCreator
                      ? 'Creator'
                      : isAdmin
                          ? 'Admin'
                          : 'Member';
                  final fullSubtitle = subtitle != null && subtitle.isNotEmpty
                      ? '$subtitle • $roleText'
                      : roleText;

                  return ListTile(
                    leading: avatar,
                    title: Row(
                      children: [
                        Flexible(child: Text(displayName)),
                        if (isCurrentUser) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'You',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(fullSubtitle),
                    onTap: () {
                      _navigateToProfile(userId, displayName);
                    },
                    trailing: !isCreator && !isCurrentUser
                        ? PopupMenuButton<String>(
                            itemBuilder: (context) => [
                              if (user != null)
                                const PopupMenuItem(
                                  value: 'trades',
                                  child: Row(
                                    children: [
                                      Icon(Icons.show_chart),
                                      SizedBox(width: 8),
                                      Text('View Trades / Activity'),
                                    ],
                                  ),
                                ),
                              if (!isAdmin)
                                const PopupMenuItem(
                                  value: 'make_admin',
                                  child: Row(
                                    children: [
                                      Icon(Icons.admin_panel_settings),
                                      SizedBox(width: 8),
                                      Text('Make Admin'),
                                    ],
                                  ),
                                ),
                              if (isAdmin && userId != group.createdBy)
                                const PopupMenuItem(
                                  value: 'remove_admin',
                                  child: Row(
                                    children: [
                                      Icon(Icons.remove_moderator),
                                      SizedBox(width: 8),
                                      Text('Remove Admin'),
                                    ],
                                  ),
                                ),
                              const PopupMenuItem(
                                value: 'remove',
                                child: Row(
                                  children: [
                                    Icon(Icons.person_remove, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Remove Member',
                                        style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                            onSelected: (value) async {
                              if (value == 'trades' && user != null) {
                                _navigateToMemberDetail(user, userId, roleText);
                              } else if (value == 'make_admin') {
                                await _makeAdmin(userId, displayName);
                              } else if (value == 'remove_admin') {
                                await _removeAdmin(userId, displayName);
                              } else if (value == 'remove') {
                                await _removeMember(userId, displayName);
                              }
                            },
                          )
                        : null,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPendingInvitations(InvestorGroup group) {
    final pendingInvitations = group.pendingInvitations ?? [];

    if (pendingInvitations.isEmpty) {
      return const Center(child: Text('No pending invitations'));
    }

    return ListView.builder(
      itemCount: pendingInvitations.length,
      itemBuilder: (context, index) {
        final userId = pendingInvitations[index];

        return FutureBuilder<DocumentSnapshot<User>>(
          future: widget.firestoreService.userCollection.doc(userId).get(),
          builder: (context, userSnapshot) {
            String displayName = 'User';
            String? subtitle;
            Widget avatar = const CircleAvatar(
              radius: 20,
              child: Icon(Icons.account_circle),
            );

            if (userSnapshot.hasData && userSnapshot.data!.exists) {
              final user = userSnapshot.data!.data();
              displayName = user?.name ?? 'Guest';
              subtitle = user?.email ?? user?.phoneNumber ?? '';
              if (user?.photoUrl != null) {
                avatar = CircleAvatar(
                  radius: 20,
                  backgroundImage:
                      CachedNetworkImageProvider(user!.photoUrl!),
                );
              }
            }

            final fullSubtitle = subtitle != null && subtitle.isNotEmpty
                ? '$subtitle • Invitation pending'
                : 'Invitation pending';

            return ListTile(
              leading: avatar,
              title: Text(displayName),
              subtitle: Text(fullSubtitle),
              trailing: IconButton(
                icon: const Icon(Icons.cancel, color: Colors.red),
                tooltip: 'Cancel invitation',
                onPressed: () async {
                  await _cancelInvitation(userId, displayName);
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInviteUsers(InvestorGroup group) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: CupertinoSearchTextField(
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
            controller: _inviteSearchController,
            placeholder: 'Search users to invite',
            onChanged: (value) {
              setState(() {
                _searchTerm = value;
                _userStream = widget.firestoreService
                    .searchUsers(searchTerm: _searchTerm);
              });
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<User>>(
            stream: _userStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No users found'));
              }

              final members = group.members;
              final pendingInvitations = group.pendingInvitations ?? [];

              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final userDoc = snapshot.data!.docs[index];
                  final user = userDoc.data();
                  final userId = userDoc.id;

                  // Don't show if already a member or has pending invitation
                  if (members.contains(userId) ||
                      pendingInvitations.contains(userId)) {
                    return const SizedBox.shrink();
                  }

                  final displayName =
                      user.name ?? user.providerId?.capitalize() ?? 'Guest';
                  final subtitle = user.email ?? user.phoneNumber ?? '';
                  final avatar = user.photoUrl != null
                      ? CircleAvatar(
                          radius: 20,
                          backgroundImage:
                              CachedNetworkImageProvider(user.photoUrl!),
                        )
                      : const CircleAvatar(
                          radius: 20,
                          child: Icon(Icons.account_circle),
                        );

                  return ListTile(
                    leading: avatar,
                    title: Text(displayName),
                    subtitle: Text(subtitle),
                    trailing: ElevatedButton.icon(
                      onPressed: () async {
                        await _sendInvitation(userId, user.name ?? 'User');
                      },
                      icon: const Icon(Icons.send, size: 16),
                      label: const Text('Invite'),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _makeAdmin(String userId, String displayName) async {
    try {
      await widget.firestoreService.addGroupAdmin(widget.groupId, userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$displayName is now an admin')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error making admin: $e')),
        );
      }
    }
  }

  Future<void> _removeAdmin(String userId, String displayName) async {
    try {
      await widget.firestoreService.removeGroupAdmin(widget.groupId, userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$displayName is no longer an admin')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing admin: $e')),
        );
      }
    }
  }

  Future<void> _removeMember(String userId, String displayName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text(
            'Are you sure you want to remove $displayName from the group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await widget.firestoreService
            .removeMemberFromGroup(widget.groupId, userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$displayName removed from group')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error removing member: $e')),
          );
        }
      }
    }
  }

  Future<void> _sendInvitation(String userId, String displayName) async {
    try {
      await widget.firestoreService.inviteUserToGroup(widget.groupId, userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invitation sent to $displayName')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending invitation: $e')),
        );
      }
    }
  }

  Future<void> _cancelInvitation(String userId, String displayName) async {
    try {
      await widget.firestoreService
          .declineGroupInvitation(widget.groupId, userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invitation to $displayName cancelled')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cancelling invitation: $e')),
        );
      }
    }
  }
}
