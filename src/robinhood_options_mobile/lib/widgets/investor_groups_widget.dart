import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/constants.dart';
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

class InvestorGroupsWidget extends StatefulWidget {
  final FirestoreService firestoreService;
  final BrokerageUser? brokerageUser;
  final IBrokerageService? service;
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
  State<InvestorGroupsWidget> createState() => _InvestorGroupsWidgetState();
}

class _InvestorGroupsWidgetState extends State<InvestorGroupsWidget> {
  Stream<QuerySnapshot<InvestorGroup>>? _publicGroupsStream;
  Stream<QuerySnapshot<InvestorGroup>>? _userGroupsStream;
  Stream<QuerySnapshot<InvestorGroup>>? _pendingInvitationsStream;

  String _searchQuery = '';
  String _sortBy = 'name'; // name, members, recent
  final TextEditingController _searchController = TextEditingController();
  int _pendingInvitationCount = 0;

  @override
  void initState() {
    super.initState();
    _refreshStreams();
    _logScreenView();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _logScreenView() {
    widget.analytics.logScreenView(
      screenName: 'investor_groups',
      screenClass: 'InvestorGroupsWidget',
    );
  }

  void _refreshStreams() {
    _publicGroupsStream = widget.firestoreService.getPublicInvestorGroups();
    if (auth.currentUser != null) {
      _userGroupsStream =
          widget.firestoreService.getUserInvestorGroups(auth.currentUser!.uid);
      _pendingInvitationsStream = widget.firestoreService
          .getUserPendingInvitations(auth.currentUser!.uid);
    } else {
      _userGroupsStream = null;
      _pendingInvitationsStream = null;
      _pendingInvitationCount = 0;
    }
  }

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
            title: const Text(Constants.appTitle),
            actions: [
              IconButton(
                icon: const Icon(Icons.copy_rounded),
                tooltip: 'Copy Trading History',
                onPressed: () {
                  widget.analytics.logEvent(name: 'view_copy_trading_history');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CopyTradingDashboardWidget(),
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
                    : const Icon(Icons.account_circle_outlined),
                onPressed: () async {
                  await showProfile(
                      context,
                      auth,
                      widget.firestoreService,
                      widget.analytics,
                      widget.observer,
                      widget.brokerageUser,
                      widget.service);
                  setState(() {
                    _refreshStreams();
                  });
                },
              ),
            ],
            bottom: TabBar(
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: [
                const Tab(
                  icon: Icon(Icons.explore_rounded),
                  text: 'Discover',
                ),
                const Tab(
                  icon: Icon(Icons.groups_rounded),
                  text: 'My Groups',
                ),
                Tab(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.mail_rounded),
                          SizedBox(height: 2),
                          Text('Invitations'),
                        ],
                      ),
                      if (_pendingInvitationCount > 0)
                        Positioned(
                          right: -8,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.error,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 20,
                              minHeight: 20,
                            ),
                            child: Text(
                              _pendingInvitationCount > 99
                                  ? '99+'
                                  : _pendingInvitationCount.toString(),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onError,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        body: Stack(
          children: [
            TabBarView(
              children: [
                _buildPublicGroups(context),
                _buildMyGroups(context),
                _buildPendingInvitations(context),
              ],
            ),
            // Floating Action Button for creating groups
            if (auth.currentUser != null)
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton.extended(
                  heroTag: 'create_group_fab',
                  onPressed: () async {
                    widget.analytics.logEvent(name: 'create_group_fab_pressed');
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => InvestorGroupCreateWidget(
                          firestoreService: widget.firestoreService,
                          analytics: widget.analytics,
                          observer: widget.observer,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create Group'),
                  elevation: 4,
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<InvestorGroup> _filterAndSortGroups(List<InvestorGroup> groups) {
    var filtered = groups.where((group) {
      if (_searchQuery.trim().isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return group.name.toLowerCase().contains(query) ||
          (group.description?.toLowerCase().contains(query) ?? false);
    }).toList();

    filtered.sort((a, b) {
      switch (_sortBy) {
        case 'members':
          return b.members.length.compareTo(a.members.length);
        case 'recent':
          return (b.dateUpdated ?? b.dateCreated)
              .compareTo(a.dateUpdated ?? a.dateCreated);
        case 'name':
        default:
          return a.name.compareTo(b.name);
      }
    });

    return filtered;
  }

  Widget _buildSearchAndSort() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search groups...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.sort, size: 20),
            ),
            tooltip: 'Sort by',
            offset: const Offset(0, 50),
            onSelected: (value) {
              setState(() {
                _sortBy = value;
              });
              widget.analytics.logEvent(
                name: 'sort_groups',
                parameters: {'sort_by': value},
              );
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'name',
                child: Row(
                  children: [
                    Icon(_sortBy == 'name' ? Icons.check : Icons.sort_by_alpha),
                    const SizedBox(width: 12),
                    const Text('Name'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'members',
                child: Row(
                  children: [
                    Icon(_sortBy == 'members' ? Icons.check : Icons.people),
                    const SizedBox(width: 12),
                    const Text('Members'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'recent',
                child: Row(
                  children: [
                    Icon(_sortBy == 'recent' ? Icons.check : Icons.access_time),
                    const SizedBox(width: 12),
                    const Text('Recent'),
                  ],
                ),
              ),
            ],
          ),
        ],
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
                          .withValues(alpha: 0.6)),
                  const SizedBox(height: 16),
                  const Text('Sign in to join investor groups',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.login),
                    onPressed: () async {
                      await showProfile(
                          context,
                          auth,
                          widget.firestoreService,
                          widget.analytics,
                          widget.observer,
                          widget.brokerageUser,
                          widget.service);
                      setState(() {
                        _refreshStreams();
                      });
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
      stream: _userGroupsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }
        if (snapshot.hasError) {
          return _buildErrorState('Error loading groups: ${snapshot.error}');
        }
        if (!snapshot.hasData || snapshot.data!.size == 0) {
          return CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.2),
                                Theme.of(context)
                                    .colorScheme
                                    .secondary
                                    .withValues(alpha: 0.1),
                              ],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.groups_rounded,
                            size: 64,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'No Groups Yet',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Create a group to collaborate with other investors\nor discover public groups',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FilledButton.icon(
                              onPressed: () async {
                                widget.analytics
                                    .logEvent(name: 'create_group_empty_state');
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        InvestorGroupCreateWidget(
                                      firestoreService: widget.firestoreService,
                                      analytics: widget.analytics,
                                      observer: widget.observer,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Create Group'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        final allGroups = snapshot.data!.docs.map((doc) => doc.data()).toList();
        final filteredGroups = _filterAndSortGroups(allGroups);

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _refreshStreams();
            });
            widget.analytics.logEvent(name: 'refresh_my_groups');
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _buildSearchAndSort(),
              ),
              if (filteredGroups.isEmpty && _searchQuery.trim().isNotEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off,
                            size: 64,
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.6)),
                        const SizedBox(height: 16),
                        const Text('No groups found',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        Text('Try adjusting your search',
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontSize: 14)),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12.0, vertical: 8.0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final group = filteredGroups[index];
                        return _AnimatedGroupCard(
                          index: index,
                          child: _GroupCard(
                            group: group,
                            heroSource: 'my_groups',
                            trailing: group.isPrivate
                                ? Chip(
                                    label: const Text(
                                      'Private',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                    avatar: const Icon(Icons.lock_rounded,
                                        size: 14),
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  )
                                : Chip(
                                    label: const Text(
                                      'Public',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                    avatar: const Icon(Icons.public_rounded,
                                        size: 14),
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                            onTap: () {
                              widget.analytics.logEvent(
                                name: 'view_group_details',
                                parameters: {
                                  'group_id': group.id,
                                  'from': 'my_groups',
                                },
                              );
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      InvestorGroupDetailWidget(
                                    groupId: group.id,
                                    firestoreService: widget.firestoreService,
                                    brokerageUser: widget.brokerageUser,
                                    analytics: widget.analytics,
                                    observer: widget.observer,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                      childCount: filteredGroups.length,
                    ),
                  ),
                ),
            ],
          ),
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
                          .withValues(alpha: 0.6)),
                  const SizedBox(height: 16),
                  const Text('Sign in to view invitations',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.login),
                    onPressed: () async {
                      await showProfile(
                          context,
                          auth,
                          widget.firestoreService,
                          widget.analytics,
                          widget.observer,
                          widget.brokerageUser,
                          widget.service);
                      setState(() {
                        _refreshStreams();
                      });
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
      stream: _pendingInvitationsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }
        if (snapshot.hasError) {
          return _buildErrorState(
              'Error loading invitations: ${snapshot.error}');
        }
        if (!snapshot.hasData || snapshot.data!.size == 0) {
          // Update count when we receive data
          if (snapshot.hasData) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _pendingInvitationCount != snapshot.data!.size) {
                setState(() {
                  _pendingInvitationCount = snapshot.data!.size;
                });
              }
            });
          }
          return CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.2),
                                Theme.of(context)
                                    .colorScheme
                                    .tertiary
                                    .withValues(alpha: 0.1),
                              ],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.mail_rounded,
                            size: 64,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'No Invitations',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Group admins can invite you to join\ntheir investor groups',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        // Update count when we have data with invitations
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pendingInvitationCount != snapshot.data!.size) {
            setState(() {
              _pendingInvitationCount = snapshot.data!.size;
            });
          }
        });

        final allGroups = snapshot.data!.docs.map((doc) => doc.data()).toList();
        final filteredGroups = _filterAndSortGroups(allGroups);

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _refreshStreams();
            });
            widget.analytics.logEvent(name: 'refresh_invitations');
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _buildSearchAndSort(),
              ),
              if (filteredGroups.isEmpty && _searchQuery.trim().isNotEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off,
                            size: 64,
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.6)),
                        const SizedBox(height: 16),
                        const Text('No invitations found',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12.0, vertical: 8.0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final group = filteredGroups[index];

                        return _AnimatedGroupCard(
                          index: index,
                          child: _GroupCard(
                            group: group,
                            heroSource: 'invitations',
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
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Semantics(
                                  label: 'Accept invitation to ${group.name}',
                                  child: FilledButton.tonal(
                                    onPressed: () async {
                                      await _acceptInvitation(context, group);
                                    },
                                    style: FilledButton.styleFrom(
                                      backgroundColor:
                                          Colors.green.withValues(alpha: 0.2),
                                      foregroundColor: Colors.green[700],
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.check_rounded,
                                            size: 18),
                                        const SizedBox(width: 4),
                                        const Text('Accept'),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Semantics(
                                  label: 'Decline invitation to ${group.name}',
                                  child: OutlinedButton(
                                    onPressed: () async {
                                      await _declineInvitation(context, group);
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red[700],
                                      side: BorderSide(
                                          color: Colors.red
                                              .withValues(alpha: 0.5)),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.close_rounded,
                                            size: 18),
                                        const SizedBox(width: 4),
                                        const Text('Decline'),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            onTap: () {
                              widget.analytics.logEvent(
                                name: 'view_group_details',
                                parameters: {
                                  'group_id': group.id,
                                  'from': 'invitations',
                                },
                              );
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      InvestorGroupDetailWidget(
                                    groupId: group.id,
                                    firestoreService: widget.firestoreService,
                                    brokerageUser: widget.brokerageUser,
                                    analytics: widget.analytics,
                                    observer: widget.observer,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                      childCount: filteredGroups.length,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _acceptInvitation(
      BuildContext context, InvestorGroup group) async {
    if (auth.currentUser == null) return;

    try {
      await widget.firestoreService
          .acceptGroupInvitation(group.id, auth.currentUser!.uid);
      widget.analytics.logEvent(
        name: 'accept_group_invitation',
        parameters: {'group_id': group.id, 'group_name': group.name},
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Joined ${group.name}'),
            action: SnackBarAction(
              label: 'View',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => InvestorGroupDetailWidget(
                      groupId: group.id,
                      firestoreService: widget.firestoreService,
                      brokerageUser: widget.brokerageUser,
                      analytics: widget.analytics,
                      observer: widget.observer,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      widget.analytics.logEvent(
        name: 'accept_invitation_error',
        parameters: {'group_id': group.id, 'error': e.toString()},
      );
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
      await widget.firestoreService
          .declineGroupInvitation(group.id, auth.currentUser!.uid);
      widget.analytics.logEvent(
        name: 'decline_group_invitation',
        parameters: {'group_id': group.id, 'group_name': group.name},
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Declined invitation to ${group.name}')),
        );
      }
    } catch (e) {
      widget.analytics.logEvent(
        name: 'decline_invitation_error',
        parameters: {'group_id': group.id, 'error': e.toString()},
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error declining invitation: $e')),
        );
      }
    }
  }

  Widget _buildLoadingState() {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(12.0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  leading: CircleAvatar(
                    radius: 28,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.1),
                  ),
                  title: Container(
                    height: 16,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  subtitle: Container(
                    height: 12,
                    width: 100,
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              childCount: 3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(String message) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _refreshStreams();
        });
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline,
                      size: 64, color: Theme.of(context).colorScheme.error),
                  const SizedBox(height: 16),
                  Text(message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    onPressed: () {
                      setState(() {
                        _refreshStreams();
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPublicGroups(BuildContext context) {
    return StreamBuilder(
      stream: _publicGroupsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }
        if (snapshot.hasError) {
          return _buildErrorState(
              'Error loading public groups: ${snapshot.error}');
        }
        if (!snapshot.hasData || snapshot.data!.size == 0) {
          return CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.2),
                                Theme.of(context)
                                    .colorScheme
                                    .secondary
                                    .withValues(alpha: 0.1),
                              ],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.explore_rounded,
                            size: 64,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'No Public Groups',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Be the first to create a public group\nand build an investing community!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 32),
                        FilledButton.icon(
                          onPressed: () async {
                            widget.analytics.logEvent(
                                name: 'create_public_group_empty_state');
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => InvestorGroupCreateWidget(
                                  firestoreService: widget.firestoreService,
                                  analytics: widget.analytics,
                                  observer: widget.observer,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Create Public Group'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        final allGroups = snapshot.data!.docs.map((doc) => doc.data()).toList();
        final filteredGroups = _filterAndSortGroups(allGroups);

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _refreshStreams();
            });
            widget.analytics.logEvent(name: 'refresh_public_groups');
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _buildSearchAndSort(),
              ),
              if (filteredGroups.isEmpty && _searchQuery.trim().isNotEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off,
                            size: 64,
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.6)),
                        const SizedBox(height: 16),
                        const Text('No groups found',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        Text('Try adjusting your search',
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontSize: 14)),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12.0, vertical: 8.0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final group = filteredGroups[index];
                        final isMember = auth.currentUser != null &&
                            group.isMember(auth.currentUser!.uid);

                        return _AnimatedGroupCard(
                          index: index,
                          child: _GroupCard(
                            group: group,
                            heroSource: 'discover',
                            trailing: isMember
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Theme.of(context).colorScheme.primary,
                                          Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: 0.8),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.check_circle_rounded,
                                          size: 16,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Joined',
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onPrimary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : null,
                            onTap: () {
                              widget.analytics.logEvent(
                                name: 'view_group_details',
                                parameters: {
                                  'group_id': group.id,
                                  'from': 'discover',
                                  'is_member': isMember.toString(),
                                },
                              );
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      InvestorGroupDetailWidget(
                                    groupId: group.id,
                                    firestoreService: widget.firestoreService,
                                    brokerageUser: widget.brokerageUser,
                                    analytics: widget.analytics,
                                    observer: widget.observer,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                      childCount: filteredGroups.length,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Reusable group card widget to reduce code duplication
class _GroupCard extends StatelessWidget {
  final InvestorGroup group;
  final Widget? trailing;
  final Widget? subtitle;
  final VoidCallback onTap;
  final String heroSource; // Source/context for unique hero tag

  const _GroupCard({
    required this.group,
    this.trailing,
    this.subtitle,
    required this.onTap,
    this.heroSource = 'default',
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Group: ${group.name}, ${group.members.length} members',
      button: true,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Hero(
                  tag: 'group_avatar_${group.id}_$heroSource',
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.3),
                          Theme.of(context)
                              .colorScheme
                              .secondary
                              .withValues(alpha: 0.2),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        group.name.isNotEmpty
                            ? group.name[0].toUpperCase()
                            : 'G',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      subtitle ??
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (group.description != null)
                                Text(
                                  group.description!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    height: 1.3,
                                  ),
                                ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.people_rounded,
                                    size: 16,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${group.members.length}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    group.members.length == 1
                                        ? 'member'
                                        : 'members',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 12),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated wrapper for group cards with staggered entrance
class _AnimatedGroupCard extends StatelessWidget {
  final int index;
  final Widget child;

  const _AnimatedGroupCard({
    required this.index,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
