import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/investor_group.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/model/verified_track_record.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/investor_group_manage_members_widget.dart';
import 'package:robinhood_options_mobile/widgets/investor_groups_member_detail_widget.dart';
import 'package:robinhood_options_mobile/widgets/trader_profile_widget.dart';
import 'package:robinhood_options_mobile/widgets/user_widget.dart';

enum MemberFilterOption {
  all,
  admins,
  verified,
}

class InvestorGroupMembersWidget extends StatefulWidget {
  final InvestorGroup group;
  final FirestoreService firestoreService;
  final IBrokerageService? service;
  final BrokerageUser? brokerageUser;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;

  const InvestorGroupMembersWidget({
    super.key,
    required this.group,
    required this.firestoreService,
    this.service,
    this.brokerageUser,
    required this.analytics,
    required this.observer,
  });

  @override
  State<InvestorGroupMembersWidget> createState() =>
      _InvestorGroupMembersWidgetState();
}

class _InvestorGroupMembersWidgetState
    extends State<InvestorGroupMembersWidget> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  MemberFilterOption _selectedFilter = MemberFilterOption.all;

  bool get _isDarkTheme => Theme.of(context).brightness == Brightness.dark;

  Color _getCardBorderColor() =>
      _isDarkTheme ? Colors.grey[800]! : Colors.grey[200]!;

  Color _getSecondaryTextColor() =>
      _isDarkTheme ? Colors.grey[400]! : Colors.grey[600]!;

  @override
  void initState() {
    super.initState();
    widget.analytics.logScreenView(
      screenName: 'InvestorGroupMembers',
      screenClass: 'InvestorGroupMembersWidget',
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _navigateToManageMembers(InvestorGroup group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InvestorGroupManageMembersWidget(
          groupId: group.id,
          group: group,
          firestoreService: widget.firestoreService,
          analytics: widget.analytics,
          observer: widget.observer,
        ),
      ),
    );
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
    // final isSelf = auth.currentUser?.uid == userId;
    // if (isSelf) {
    //   Navigator.push(
    //     context,
    //     MaterialPageRoute(
    //       builder: (context) => Scaffold(
    //         appBar: AppBar(
    //           title: Text(displayName),
    //         ),
    //         body: UserWidget(
    //           auth,
    //           userId: userId,
    //           isProfileView: true,
    //           analytics: widget.analytics,
    //           observer: widget.observer,
    //           brokerageUser: widget.brokerageUser,
    //           service: widget.service,
    //         ),
    //       ),
    //     ),
    //   );
    // } else {
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
    // }
  }

  Future<void> _promoteToAdmin(String userId, String displayName) async {
    try {
      await widget.firestoreService.addGroupAdmin(widget.group.id, userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$displayName is now an admin')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating admin role: $e')),
        );
      }
    }
  }

  Future<void> _demoteFromAdmin(String userId, String displayName) async {
    try {
      await widget.firestoreService.removeGroupAdmin(widget.group.id, userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$displayName is no longer an admin')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing admin role: $e')),
        );
      }
    }
  }

  Future<void> _removeMember(String userId, String displayName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Remove $displayName from ${widget.group.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.firestoreService
            .removeMemberFromGroup(widget.group.id, userId);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<InvestorGroup?>(
      stream: widget.firestoreService.investorGroupCollection
          .doc(widget.group.id)
          .snapshots()
          .map((snapshot) => snapshot.data()),
      builder: (context, snapshot) {
        final group = snapshot.data ?? widget.group;
        final currentUserId = auth.currentUser?.uid;
        final isCurrentUserAdmin =
            currentUserId != null && group.isAdmin(currentUserId);

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Group Members'),
                Text(
                  '${group.members.length} member${group.members.length != 1 ? 's' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _getSecondaryTextColor(),
                  ),
                ),
              ],
            ),
            actions: [
              if (isCurrentUserAdmin)
                IconButton(
                  icon: const Icon(Icons.manage_accounts_outlined),
                  tooltip: 'Manage Invitations & Roles',
                  onPressed: () => _navigateToManageMembers(group),
                ),
            ],
          ),
          body: Column(
            children: [
              // Search field
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search members by name...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _getCardBorderColor()),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val.trim().toLowerCase());
                  },
                ),
              ),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    FilterChip(
                      label: Text('All (${group.members.length})'),
                      selected: _selectedFilter == MemberFilterOption.all,
                      onSelected: (val) {
                        if (val) {
                          setState(
                              () => _selectedFilter = MemberFilterOption.all);
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text(
                          'Leaders & Admins (${group.admins?.length ?? 0})'),
                      selected: _selectedFilter == MemberFilterOption.admins,
                      onSelected: (val) {
                        if (val) {
                          setState(() =>
                              _selectedFilter = MemberFilterOption.admins);
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Verified Traders'),
                      selected: _selectedFilter == MemberFilterOption.verified,
                      onSelected: (val) {
                        if (val) {
                          setState(() =>
                              _selectedFilter = MemberFilterOption.verified);
                        }
                      },
                    ),
                  ],
                ),
              ),

              const Divider(height: 16),

              // Members List
              Expanded(
                child: _buildMembersList(group, isCurrentUserAdmin),
              ),
            ],
          ),
          floatingActionButton: isCurrentUserAdmin
              ? FloatingActionButton.extended(
                  onPressed: () => _navigateToManageMembers(group),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Invite Members'),
                )
              : null,
        );
      },
    );
  }

  Widget _buildMembersList(InvestorGroup group, bool isCurrentUserAdmin) {
    if (group.members.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline,
                size: 64, color: _getSecondaryTextColor()),
            const SizedBox(height: 16),
            Text(
              'No members found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    // Sort: Creator first, then Admins, then members
    final sortedMembers = List<String>.from(group.members)
      ..sort((a, b) {
        if (a == group.createdBy) return -1;
        if (b == group.createdBy) return 1;
        final aAdmin = group.isAdmin(a);
        final bAdmin = group.isAdmin(b);
        if (aAdmin && !bAdmin) return -1;
        if (!aAdmin && bAdmin) return 1;
        return 0;
      });

    return ListView.builder(
      itemCount: sortedMembers.length,
      padding: const EdgeInsets.only(bottom: 80, top: 4),
      itemBuilder: (context, index) {
        final userId = sortedMembers[index];
        final isCreator = userId == group.createdBy;
        final isAdmin = group.isAdmin(userId);
        final isSelf = auth.currentUser?.uid == userId;

        final role = isCreator ? 'Creator' : (isAdmin ? 'Admin' : 'Member');

        // Apply admin filter
        if (_selectedFilter == MemberFilterOption.admins && !isAdmin) {
          return const SizedBox.shrink();
        }

        return FutureBuilder<DocumentSnapshot<User>>(
          future: widget.firestoreService.userCollection.doc(userId).get(),
          builder: (context, userSnapshot) {
            final user = userSnapshot.data?.data();
            final displayName =
                user?.name ?? (isCreator ? 'Group Creator' : 'Member');
            final email = user?.email ?? user?.phoneNumber ?? '';

            // Apply search query
            if (_searchQuery.isNotEmpty) {
              final queryMatch =
                  displayName.toLowerCase().contains(_searchQuery) ||
                      email.toLowerCase().contains(_searchQuery);
              if (!queryMatch) {
                return const SizedBox.shrink();
              }
            }

            return StreamBuilder<VerifiedTrackRecord?>(
              stream: widget.firestoreService.streamVerifiedTrackRecord(userId),
              builder: (context, recordSnapshot) {
                final trackRecord = recordSnapshot.data;
                final isVerified =
                    trackRecord != null && trackRecord.isVerified;

                // Apply verified filter
                if (_selectedFilter == MemberFilterOption.verified &&
                    !isVerified) {
                  return const SizedBox.shrink();
                }

                return _buildMemberCard(
                  user: user,
                  userId: userId,
                  displayName: displayName,
                  email: email,
                  role: role,
                  isCreator: isCreator,
                  isAdmin: isAdmin,
                  isSelf: isSelf,
                  isCurrentUserAdmin: isCurrentUserAdmin,
                  trackRecord: trackRecord,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMemberCard({
    required User? user,
    required String userId,
    required String displayName,
    required String email,
    required String role,
    required bool isCreator,
    required bool isAdmin,
    required bool isSelf,
    required bool isCurrentUserAdmin,
    required VerifiedTrackRecord? trackRecord,
  }) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: _getCardBorderColor()),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.lightImpact();
          _navigateToProfile(userId, displayName);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    backgroundImage: user?.photoUrl != null
                        ? CachedNetworkImageProvider(user!.photoUrl!)
                        : null,
                    child: user?.photoUrl == null
                        ? Text(
                            displayName.isNotEmpty
                                ? displayName[0].toUpperCase()
                                : 'U',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),

                  // Name & Subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isSelf) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'You',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            _buildRoleBadge(role, isCreator, isAdmin),
                            if (email.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  email,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _getSecondaryTextColor(),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Trailing Action / Admin Popup
                  if (isCurrentUserAdmin && !isCreator && !isSelf)
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert,
                          size: 20, color: _getSecondaryTextColor()),
                      onSelected: (action) {
                        if (action == 'make_admin') {
                          _promoteToAdmin(userId, displayName);
                        } else if (action == 'remove_admin') {
                          _demoteFromAdmin(userId, displayName);
                        } else if (action == 'remove_member') {
                          _removeMember(userId, displayName);
                        }
                      },
                      itemBuilder: (ctx) => [
                        if (!isAdmin)
                          const PopupMenuItem(
                            value: 'make_admin',
                            child: Row(
                              children: [
                                Icon(Icons.admin_panel_settings, size: 18),
                                SizedBox(width: 8),
                                Text('Promote to Admin'),
                              ],
                            ),
                          ),
                        if (isAdmin)
                          const PopupMenuItem(
                            value: 'remove_admin',
                            child: Row(
                              children: [
                                Icon(Icons.remove_moderator, size: 18),
                                SizedBox(width: 8),
                                Text('Demote from Admin'),
                              ],
                            ),
                          ),
                        const PopupMenuItem(
                          value: 'remove_member',
                          child: Row(
                            children: [
                              Icon(Icons.person_remove,
                                  color: Colors.red, size: 18),
                              SizedBox(width: 8),
                              Text('Remove from Group',
                                  style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    )
                  else
                    Icon(Icons.arrow_forward_ios,
                        size: 14, color: _getSecondaryTextColor()),
                ],
              ),

              // Verified Leader Track Record Badge
              if (trackRecord != null && trackRecord.isVerified) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: trackRecord.tier.color
                        .withValues(alpha: _isDarkTheme ? 0.25 : 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: trackRecord.tier.color.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(trackRecord.tier.icon,
                          size: 14, color: trackRecord.tier.color),
                      const SizedBox(width: 6),
                      Text(
                        '${trackRecord.tier.label} • ${trackRecord.verifiedReturnPercent >= 0 ? '+' : ''}${trackRecord.verifiedReturnPercent.toStringAsFixed(1)}% Return • ${trackRecord.verifiedWinRate.toStringAsFixed(0)}% Win Rate',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: trackRecord.tier.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Quick Action Buttons
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        if (user != null) {
                          _navigateToMemberDetail(user, userId, role);
                        } else {
                          _navigateToProfile(userId, displayName);
                        }
                      },
                      icon: const Icon(Icons.show_chart, size: 16),
                      label: const Text('Trades / Copy',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => _navigateToProfile(userId, displayName),
                      icon: const Icon(Icons.person_outline, size: 16),
                      label:
                          const Text('Profile', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String role, bool isCreator, bool isAdmin) {
    Color bg;
    Color fg;
    if (isCreator) {
      bg = Colors.amber.withValues(alpha: _isDarkTheme ? 0.3 : 0.15);
      fg = Colors.amber[_isDarkTheme ? 300 : 800]!;
    } else if (isAdmin) {
      bg = Colors.blue.withValues(alpha: _isDarkTheme ? 0.3 : 0.15);
      fg = Colors.blue[_isDarkTheme ? 300 : 700]!;
    } else {
      bg = Colors.grey.withValues(alpha: _isDarkTheme ? 0.25 : 0.12);
      fg = _isDarkTheme ? Colors.grey[300]! : Colors.grey[700]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        role,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}
