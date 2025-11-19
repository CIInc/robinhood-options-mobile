import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/extensions.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/investor_group.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
import 'package:robinhood_options_mobile/widgets/investor_group_manage_members_widget.dart';
import 'package:robinhood_options_mobile/widgets/shared_portfolio_widget.dart';
import 'package:intl/intl.dart';

class InvestorGroupDetailWidget extends StatefulWidget {
  final String groupId;
  final FirestoreService firestoreService;
  final BrokerageUser brokerageUser;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;

  const InvestorGroupDetailWidget({
    super.key,
    required this.groupId,
    required this.firestoreService,
    required this.brokerageUser,
    required this.analytics,
    required this.observer,
  });

  @override
  State<InvestorGroupDetailWidget> createState() =>
      _InvestorGroupDetailWidgetState();
}

class _InvestorGroupDetailWidgetState extends State<InvestorGroupDetailWidget> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<InvestorGroup?>(
      stream: widget.firestoreService.investorGroupCollection
          .doc(widget.groupId)
          .snapshots()
          .map((snapshot) => snapshot.data()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Loading...')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: Center(
              child: Text('Error loading group: ${snapshot.error}'),
            ),
          );
        }

        final group = snapshot.data!;
        final isAdmin =
            auth.currentUser != null && group.isAdmin(auth.currentUser!.uid);
        final isMember =
            auth.currentUser != null && group.isMember(auth.currentUser!.uid);

        return Scaffold(
          appBar: AppBar(
            title: Text(group.name),
            actions: [
              if (isAdmin)
                PopupMenuButton(
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'manage_members',
                      child: Row(
                        children: [
                          Icon(Icons.people),
                          SizedBox(width: 8),
                          Text('Manage Members'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit),
                          SizedBox(width: 8),
                          Text('Edit Group'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete Group',
                              style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'manage_members') {
                      _showManageMembersScreen(context, group);
                    } else if (value == 'edit') {
                      _showEditGroupDialog(context, group);
                    } else if (value == 'delete') {
                      _showDeleteConfirmDialog(context, group);
                    }
                  },
                ),
            ],
          ),
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            child: Text(
                              group.name.isNotEmpty
                                  ? group.name[0].toUpperCase()
                                  : 'G',
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  group.name,
                                  style:
                                      Theme.of(context).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      group.isPrivate
                                          ? Icons.lock
                                          : Icons.public,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      group.isPrivate ? 'Private' : 'Public',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                      '${group.members.length} members',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (group.description != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          group.description!,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'Created ${DateFormat.yMMMd().format(group.dateCreated)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      if (auth.currentUser != null) ...[
                        if (isMember)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading
                                  ? null
                                  : () => _leaveGroup(context, group),
                              icon: const Icon(Icons.exit_to_app),
                              label: const Text('Leave Group'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          )
                        else
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading
                                  ? null
                                  : () => _joinGroup(context, group),
                              icon: const Icon(Icons.group_add),
                              label: const Text('Join Group'),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Members',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              _buildMembersList(group),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMembersList(InvestorGroup group) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final userId = group.members[index];
          final isCreator = userId == group.createdBy;
          final isAdmin = group.isAdmin(userId);

          return FutureBuilder(
            future: widget.firestoreService.userCollection.doc(userId).get(),
            builder: (context, snapshot) {
              String displayName = 'User';
              Widget avatar = const CircleAvatar(
                radius: 20,
                child: Icon(Icons.account_circle),
              );

              if (snapshot.hasData && snapshot.data!.exists) {
                final user = snapshot.data!.data();
                displayName =
                    user?.name ?? user?.providerId?.capitalize() ?? 'Guest';
                if (user?.photoUrl != null) {
                  avatar = CircleAvatar(
                    radius: 20,
                    backgroundImage:
                        CachedNetworkImageProvider(user!.photoUrl!),
                  );
                }
              }

              return ListTile(
                leading: avatar,
                title: Text(displayName),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isCreator)
                      const Chip(
                        label: Text('Creator', style: TextStyle(fontSize: 12)),
                      )
                    else if (isAdmin)
                      const Chip(
                        label: Text('Admin', style: TextStyle(fontSize: 12)),
                      ),
                    if (group.isPrivate) const SizedBox(width: 8),
                    if (group.isPrivate) const Icon(Icons.chevron_right),
                  ],
                ),
                onTap:
                    group.isPrivate && snapshot.hasData && snapshot.data!.exists
                        ? () {
                            final user = snapshot.data!.data();
                            if (user != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SharedPortfolioWidget(
                                    user: user,
                                    userDoc: snapshot.data!.reference,
                                    brokerageService: RobinhoodService(),
                                    firestoreService: widget.firestoreService,
                                  ),
                                ),
                              );
                            }
                          }
                        : null,
              );
            },
          );
        },
        childCount: group.members.length,
      ),
    );
  }

  Future<void> _joinGroup(BuildContext context, InvestorGroup group) async {
    if (auth.currentUser == null) return;

    setState(() => _isLoading = true);

    try {
      await widget.firestoreService
          .joinInvestorGroup(group.id, auth.currentUser!.uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully joined the group!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error joining group: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _leaveGroup(BuildContext context, InvestorGroup group) async {
    if (auth.currentUser == null) return;

    // Don't allow creator to leave
    if (group.createdBy == auth.currentUser!.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Group creator cannot leave. Delete the group instead.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await widget.firestoreService
          .leaveInvestorGroup(group.id, auth.currentUser!.uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully left the group')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error leaving group: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showManageMembersScreen(BuildContext context, InvestorGroup group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InvestorGroupManageMembersWidget(
          groupId: widget.groupId,
          group: group,
          firestoreService: widget.firestoreService,
          analytics: widget.analytics,
          observer: widget.observer,
        ),
      ),
    );
  }

  void _showEditGroupDialog(BuildContext context, InvestorGroup group) {
    final nameController = TextEditingController(text: group.name);
    final descriptionController =
        TextEditingController(text: group.description);
    bool isPrivate = group.isPrivate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Group'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Group Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Private Group'),
                  value: isPrivate,
                  onChanged: (value) {
                    setState(() => isPrivate = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a group name')),
                  );
                  return;
                }

                group.name = nameController.text;
                group.description = descriptionController.text;
                group.isPrivate = isPrivate;

                try {
                  await widget.firestoreService.updateInvestorGroup(group);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Group updated!')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating group: $e')),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, InvestorGroup group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Group'),
        content: Text(
            'Are you sure you want to delete "${group.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await widget.firestoreService.deleteInvestorGroup(group.id);
                if (context.mounted) {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back to groups list
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Group deleted')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting group: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
