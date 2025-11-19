import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/model/investor_group.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';

class InvestorGroupManageMembersWidget extends StatefulWidget {
  final String groupId;
  final InvestorGroup group;
  final FirestoreService firestoreService;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;

  const InvestorGroupManageMembersWidget({
    super.key,
    required this.groupId,
    required this.group,
    required this.firestoreService,
    required this.analytics,
    required this.observer,
  });

  @override
  State<InvestorGroupManageMembersWidget> createState() =>
      _InvestorGroupManageMembersWidgetState();
}

class _InvestorGroupManageMembersWidgetState
    extends State<InvestorGroupManageMembersWidget>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String? _searchTerm;
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
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Members'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Members'),
            Tab(icon: Icon(Icons.mail_outline), text: 'Pending'),
            Tab(icon: Icon(Icons.person_add), text: 'Invite'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMembersList(),
          _buildPendingInvitations(),
          _buildInviteUsers(),
        ],
      ),
    );
  }

  Widget _buildMembersList() {
    return StreamBuilder<InvestorGroup?>(
      stream: widget.firestoreService.investorGroupCollection
          .doc(widget.groupId)
          .snapshots()
          .map((snapshot) => snapshot.data()),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final group = snapshot.data!;
        if (group.members.isEmpty) {
          return const Center(child: Text('No members'));
        }

        return ListView.builder(
          itemCount: group.members.length,
          itemBuilder: (context, index) {
            final userId = group.members[index];
            final isCreator = userId == group.createdBy;
            final isAdmin = group.isAdmin(userId);
            final isCurrentUser = auth.currentUser?.uid == userId;

            return FutureBuilder(
              future:
                  widget.firestoreService.userCollection.doc(userId).get(),
              builder: (context, userSnapshot) {
                String displayName = 'User';
                if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  final user = userSnapshot.data!.data();
                  displayName = user?.name ?? user?.email ?? 'User';
                }

                return ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person),
                  ),
                  title: Text(displayName),
                  subtitle: Text(
                    isCreator
                        ? 'Creator'
                        : isAdmin
                            ? 'Admin'
                            : 'Member',
                  ),
                  trailing: !isCreator && !isCurrentUser
                      ? PopupMenuButton(
                          itemBuilder: (context) => [
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
                            if (value == 'make_admin') {
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
        );
      },
    );
  }

  Widget _buildPendingInvitations() {
    return StreamBuilder<InvestorGroup?>(
      stream: widget.firestoreService.investorGroupCollection
          .doc(widget.groupId)
          .snapshots()
          .map((snapshot) => snapshot.data()),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final group = snapshot.data!;
        final pendingInvitations = group.pendingInvitations ?? [];

        if (pendingInvitations.isEmpty) {
          return const Center(child: Text('No pending invitations'));
        }

        return ListView.builder(
          itemCount: pendingInvitations.length,
          itemBuilder: (context, index) {
            final userId = pendingInvitations[index];

            return FutureBuilder(
              future:
                  widget.firestoreService.userCollection.doc(userId).get(),
              builder: (context, userSnapshot) {
                String displayName = 'User';
                if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  final user = userSnapshot.data!.data();
                  displayName = user?.name ?? user?.email ?? 'User';
                }

                return ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.mail_outline),
                  ),
                  title: Text(displayName),
                  subtitle: const Text('Invitation pending'),
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
      },
    );
  }

  Widget _buildInviteUsers() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: CupertinoSearchTextField(
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge!.color,
            ),
            controller: _searchController,
            placeholder: 'Search users',
            onChanged: (value) {
              setState(() {
                _searchTerm = value;
                _userStream =
                    widget.firestoreService.searchUsers(searchTerm: _searchTerm);
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

              return StreamBuilder<InvestorGroup?>(
                stream: widget.firestoreService.investorGroupCollection
                    .doc(widget.groupId)
                    .snapshots()
                    .map((snapshot) => snapshot.data()),
                builder: (context, groupSnapshot) {
                  final group = groupSnapshot.data ?? widget.group;
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

                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person),
                        ),
                        title: Text(user.name ?? 'User'),
                        subtitle: Text(user.email ?? ''),
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
        content: Text('Are you sure you want to remove $displayName from the group?'),
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
        await widget.firestoreService.removeMemberFromGroup(
            widget.groupId, userId);
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
      await widget.firestoreService.declineGroupInvitation(
          widget.groupId, userId);
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
