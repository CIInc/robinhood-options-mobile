import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/widgets/sliverappbar_widget.dart';
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
import 'package:robinhood_options_mobile/widgets/following_activity_feed_widget.dart';
import 'package:robinhood_options_mobile/widgets/top_portfolios_leaderboard_widget.dart';
import 'package:robinhood_options_mobile/widgets/users_widget.dart';
import 'package:robinhood_options_mobile/widgets/share_trade_idea_sheet.dart';
import 'package:robinhood_options_mobile/model/verified_track_record.dart';

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

class _InvestorGroupsWidgetState extends State<InvestorGroupsWidget>
    with SingleTickerProviderStateMixin {
  Stream<QuerySnapshot<InvestorGroup>>? _publicGroupsStream;
  Stream<QuerySnapshot<InvestorGroup>>? _userGroupsStream;
  Stream<QuerySnapshot<InvestorGroup>>? _pendingInvitationsStream;

  String _searchQuery = '';
  String _sortBy = 'name'; // name, members, recent
  String _selectedGroupCategory = 'all'; // all, my_groups, invitations
  final TextEditingController _searchController = TextEditingController();
  late final TabController _tabController;
  int _currentTabIndex = 0;
  int _pendingInvitationCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _currentTabIndex) {
        setState(() {
          _currentTabIndex = _tabController.index;
        });
      }
    });
    _refreshStreams();
    _logScreenView();
  }

  @override
  void dispose() {
    _tabController.dispose();
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
          ExpandedSliverAppBar(
            auth: auth,
            firestoreService: widget.firestoreService,
            automaticallyImplyLeading: true,
            title: const Text(Constants.appTitle),
            analytics: widget.analytics,
            observer: widget.observer,
            user: widget.brokerageUser,
            firestoreUser: widget.user,
            userDocRef: widget.userDocRef,
            service: widget.service,
            floating: true,
            snap: true,
            onChange: () {
              setState(() {
                _refreshStreams();
              });
            },
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                tooltip: 'More options',
                onSelected: (value) {
                  if (value == 'copy_trading') {
                    widget.analytics
                        .logEvent(name: 'view_copy_trading_history');
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const CopyTradingDashboardWidget(),
                      ),
                    );
                  } else if (value == 'find_traders') {
                    widget.analytics.logEvent(name: 'view_find_traders');
                    if (widget.brokerageUser != null &&
                        widget.service != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UsersWidget(
                            auth,
                            widget.service!,
                            firestoreService: widget.firestoreService,
                            analytics: widget.analytics,
                            observer: widget.observer,
                            brokerageUser: widget.brokerageUser!,
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Please connect your brokerage account to find traders.'),
                        ),
                      );
                    }
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'copy_trading',
                    child: ListTile(
                      leading: Icon(Icons.copy_rounded),
                      title: Text('Copy Trading History'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'find_traders',
                    child: ListTile(
                      leading: Icon(Icons.person_search_rounded),
                      title: Text('Find Traders'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                ],
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: [
                const Tab(
                  icon: Icon(Icons.dynamic_feed_rounded),
                  text: 'Feed',
                ),
                const Tab(
                  icon: Icon(Icons.emoji_events_rounded),
                  text: 'Leaderboard',
                ),
                Tab(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.groups_rounded),
                          SizedBox(height: 2),
                          Text('Groups'),
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
                              minWidth: 18,
                              minHeight: 18,
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
              controller: _tabController,
              children: [
                FollowingActivityFeedWidget(
                  auth: auth,
                  firestoreService: widget.firestoreService,
                  analytics: widget.analytics,
                  observer: widget.observer,
                  brokerageUser: widget.brokerageUser,
                  service: widget.service,
                  userRole: widget.user?.role,
                  showAppBar: false,
                  showFab: false,
                ),
                TopPortfoliosLeaderboardWidget(
                  auth: auth,
                  firestoreService: widget.firestoreService,
                  analytics: widget.analytics,
                  observer: widget.observer,
                  brokerageUser: widget.brokerageUser,
                  service: widget.service,
                  showAppBar: false,
                ),
                _buildGroupsTab(context),
              ],
            ),
            // Floating Action Button - Share Idea on Feed (0), Create Group on Groups (2)
            if (auth.currentUser != null && _currentTabIndex == 0)
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton.extended(
                  heroTag: 'feed_share_idea_fab',
                  onPressed: () => ShareTradeIdeaSheet.show(
                    context: context,
                    auth: auth,
                    firestoreService: widget.firestoreService,
                    analytics: widget.analytics,
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Share Idea'),
                  elevation: 4,
                ),
              ),
            if (auth.currentUser != null &&
                _currentTabIndex == 2 &&
                _selectedGroupCategory != 'invitations')
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

  Widget _buildGroupsTab(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      type: MaterialType.transparency,
      child: Column(
        children: [
          _buildGroupsToolbar(theme),
          Expanded(
            child: _selectedGroupCategory == 'my_groups'
                ? _buildMyGroups(context)
                : _selectedGroupCategory == 'invitations'
                    ? _buildPendingInvitations(context)
                    : _buildPublicGroups(context),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupsToolbar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Category Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildGroupCategoryPill('all', 'All Groups', Icons.public),
                const SizedBox(width: 8),
                _buildGroupCategoryPill('my_groups', 'My Groups', Icons.groups),
                const SizedBox(width: 8),
                _buildGroupCategoryPill(
                  'invitations',
                  'Invitations',
                  Icons.mail_outline,
                  badgeCount: _pendingInvitationCount,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Row 2: Search Bar & Sort Menu Button below Chips (relaxed, less tight)
          Row(
            children: [
              Expanded(
                child: CupertinoSearchTextField(
                  controller: _searchController,
                  placeholder: 'Search groups by name...',
                  padding: const EdgeInsetsDirectional.fromSTEB(8, 10, 8, 10),
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  onSuffixTap: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                initialValue: _sortBy,
                tooltip: 'Sort groups',
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _sortBy != 'members'
                        ? theme.colorScheme.primary.withValues(alpha: 0.12)
                        : theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _sortBy != 'members'
                          ? theme.colorScheme.primary.withValues(alpha: 0.3)
                          : theme.colorScheme.outlineVariant
                              .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          Icons.sort_rounded,
                          size: 20,
                          color: _sortBy != 'members'
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        if (_sortBy != 'members')
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
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
                    value: 'members',
                    child: Row(
                      children: [
                        Icon(_sortBy == 'members' ? Icons.check : Icons.people,
                            size: 16),
                        const SizedBox(width: 10),
                        const Text('Most Members'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'recent',
                    child: Row(
                      children: [
                        Icon(
                            _sortBy == 'recent'
                                ? Icons.check
                                : Icons.access_time,
                            size: 16),
                        const SizedBox(width: 10),
                        const Text('Recent Activity'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'name',
                    child: Row(
                      children: [
                        Icon(
                            _sortBy == 'name'
                                ? Icons.check
                                : Icons.sort_by_alpha,
                            size: 16),
                        const SizedBox(width: 10),
                        const Text('Alphabetical'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCategoryPill(
    String category,
    String label,
    IconData icon, {
    int badgeCount = 0,
  }) {
    final isSelected = _selectedGroupCategory == category;
    final theme = Theme.of(context);
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 15,
        color: isSelected
            ? theme.colorScheme.onPrimaryContainer
            : theme.colorScheme.onSurfaceVariant,
      ),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (badgeCount > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.error,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$badgeCount',
                style: TextStyle(
                  color: theme.colorScheme.onError,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      selected: isSelected,
      showCheckmark: false,
      selectedColor: theme.colorScheme.primaryContainer,
      backgroundColor:
          theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.3)
              : Colors.transparent,
        ),
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedGroupCategory = category;
          });
          widget.analytics.logEvent(
            name: 'select_group_category',
            parameters: {'category': category},
          );
        }
      },
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
                  padding: const EdgeInsets.only(top: 4, bottom: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final group = filteredGroups[index];
                        return _AnimatedGroupCard(
                          index: index,
                          child: _GroupCard(
                            group: group,
                            firestoreService: widget.firestoreService,
                            heroSource: 'my_groups',
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant
                                      .withValues(alpha: 0.4),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    group.isPrivate
                                        ? Icons.lock_rounded
                                        : Icons.public_rounded,
                                    size: 13,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    group.isPrivate ? 'Private' : 'Public',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
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
                                    service: widget.service,
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
                  padding: const EdgeInsets.only(top: 4, bottom: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final group = filteredGroups[index];

                        return _AnimatedGroupCard(
                          index: index,
                          child: _GroupCard(
                            group: group,
                            firestoreService: widget.firestoreService,
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
                                    service: widget.service,
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
                      service: widget.service,
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
                  padding: const EdgeInsets.only(top: 4, bottom: 16),
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
                            firestoreService: widget.firestoreService,
                            heroSource: 'discover',
                            trailing: isMember
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.check_circle_rounded,
                                          size: 14,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimaryContainer,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Joined',
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onPrimaryContainer,
                                            fontSize: 11,
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
                                    service: widget.service,
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
  final FirestoreService? firestoreService;
  final Widget? trailing;
  final Widget? subtitle;
  final VoidCallback onTap;
  final String heroSource; // Source/context for unique hero tag

  const _GroupCard({
    required this.group,
    this.firestoreService,
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
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Theme.of(context)
                .colorScheme
                .outlineVariant
                .withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Hero(
                  tag: 'group_avatar_${group.id}_$heroSource',
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        group.name.isNotEmpty
                            ? group.name[0].toUpperCase()
                            : 'G',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      subtitle ??
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (group.description != null &&
                                  group.description!.isNotEmpty) ...[
                                Text(
                                  group.description!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    height: 1.25,
                                  ),
                                ),
                                const SizedBox(height: 6),
                              ],
                              Row(
                                children: [
                                  Icon(
                                    Icons.people_rounded,
                                    size: 14,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${group.members.length}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    group.members.length == 1
                                        ? 'member'
                                        : 'members',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                  if (firestoreService != null)
                                    StreamBuilder<VerifiedTrackRecord?>(
                                      stream: firestoreService!
                                          .streamVerifiedTrackRecord(
                                              group.createdBy),
                                      builder: (context, snapshot) {
                                        final record = snapshot.data;
                                        if (record == null ||
                                            !record.isVerified) {
                                          return const SizedBox.shrink();
                                        }
                                        return Container(
                                          margin:
                                              const EdgeInsets.only(left: 8),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: record.tier.color
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                              color: record.tier.color
                                                  .withValues(alpha: 0.4),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(record.tier.icon,
                                                  size: 11,
                                                  color: record.tier.color),
                                              const SizedBox(width: 3),
                                              Text(
                                                '${record.tier.label} ${record.verifiedReturnPercent >= 0 ? '+' : ''}${record.verifiedReturnPercent.toStringAsFixed(0)}%',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: record.tier.color,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
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
