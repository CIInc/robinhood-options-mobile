import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/group_activity.dart';
import 'package:robinhood_options_mobile/model/group_analysis.dart';
import 'package:robinhood_options_mobile/model/instrument_order.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/model/user_follow.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/auto_trade_status_badge_widget.dart';
import 'package:robinhood_options_mobile/widgets/copy_trade_button_widget.dart';
import 'package:robinhood_options_mobile/widgets/share_trade_idea_sheet.dart';
import 'package:robinhood_options_mobile/widgets/sliverappbar_widget.dart';
import 'package:robinhood_options_mobile/widgets/trader_profile_widget.dart';

/// Unified Social Feed supporting followed trades, shared trade ideas,
/// public community theses, and 1-tap strategy cloning.
class FollowingActivityFeedWidget extends StatefulWidget {
  final firebase_auth.FirebaseAuth auth;
  final FirestoreService firestoreService;
  final BrokerageUser? brokerageUser;
  final IBrokerageService? service;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final UserRole? userRole;
  final User? user;
  final DocumentReference<User>? userDocRef;
  final bool showAppBar;
  final bool showFab;

  const FollowingActivityFeedWidget({
    super.key,
    required this.auth,
    required this.firestoreService,
    required this.brokerageUser,
    required this.service,
    required this.analytics,
    required this.observer,
    this.userRole,
    this.user,
    this.userDocRef,
    this.showAppBar = true,
    this.showFab = true,
  });

  @override
  State<FollowingActivityFeedWidget> createState() =>
      _FollowingActivityFeedWidgetState();
}

class _FollowingActivityFeedWidgetState
    extends State<FollowingActivityFeedWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _chipScrollController = ScrollController();
  final GlobalKey _communityChipKey = GlobalKey();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'all'; // 'all', 'equity', 'option', 'buy', 'sell'
  String _selectedSentiment = 'all'; // 'all', 'bullish', 'bearish', 'neutral'
  Stream<List<UserFollow>>? _followingStream;
  String? _cachedUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    final currentUser = widget.auth.currentUser;
    if (currentUser != null) {
      _cachedUserId = currentUser.uid;
      _followingStream =
          widget.firestoreService.getFollowingStream(currentUser.uid);
    }
  }

  @override
  void didUpdateWidget(covariant FollowingActivityFeedWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentUser = widget.auth.currentUser;
    if (currentUser?.uid != _cachedUserId) {
      _cachedUserId = currentUser?.uid;
      _followingStream = currentUser != null
          ? widget.firestoreService.getFollowingStream(currentUser.uid)
          : null;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chipScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = widget.auth.currentUser;

    if (currentUser == null) {
      if (!widget.showAppBar) {
        return const Center(
          child: Text('Sign in to view your social feed.'),
        );
      }
      return Scaffold(
        appBar: AppBar(
          title: const Text('Social Feed'),
          actions: [
            IconButton(
                icon: const Icon(Icons.account_circle_outlined),
                onPressed: () {
                  showProfile(
                      context,
                      widget.auth,
                      widget.firestoreService,
                      widget.analytics,
                      widget.observer,
                      widget.brokerageUser,
                      widget.service);
                }),
          ],
        ),
        body: const Center(
          child: Text('Sign in to view your social feed.'),
        ),
      );
    }

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Social Feed & Ideas'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh Feed',
                  onPressed: () => setState(() {}),
                ),
                if (widget.auth.currentUser != null)
                  AutoTradeStatusBadgeWidget(
                    user: widget.user,
                    userDocRef: widget.userDocRef,
                    service: widget.service,
                    userAvatar: (widget.auth.currentUser!.photoURL ??
                                widget.user?.photoUrl) ==
                            null
                        ? const Icon(Icons.account_circle)
                        : CircleAvatar(
                            maxRadius: 11,
                            backgroundImage: CachedNetworkImageProvider(
                                (widget.auth.currentUser!.photoURL ??
                                    widget.user?.photoUrl)!)),
                    onProfileTap: () {
                      showProfile(
                          context,
                          widget.auth,
                          widget.firestoreService,
                          widget.analytics,
                          widget.observer,
                          widget.brokerageUser,
                          widget.service);
                    },
                  )
                else
                  IconButton(
                      icon: const Icon(Icons.account_circle_outlined),
                      onPressed: () {
                        showProfile(
                            context,
                            widget.auth,
                            widget.firestoreService,
                            widget.analytics,
                            widget.observer,
                            widget.brokerageUser,
                            widget.service);
                      }),
              ],
            )
          : null,
      floatingActionButton: widget.showFab
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Share Idea'),
              onPressed: () => _openShareTradeIdea(context),
            )
          : null,
      body: StreamBuilder<List<UserFollow>>(
        stream: _followingStream ??
            widget.firestoreService.getFollowingStream(currentUser.uid),
        builder: (context, followSnapshot) {
          if (followSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (followSnapshot.hasError) {
            return Center(
              child: Text('Error: ${followSnapshot.error}'),
            );
          }

          final follows = followSnapshot.data ?? [];
          final followedUserIds = follows.map((f) => f.followingId).toList();

          return Column(
            children: [
              _buildFeedToolbar(theme),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const ClampingScrollPhysics(),
                  children: [
                    // Tab 0: All (Interleaved)
                    _KeepAliveTab(
                      child: _buildAllFeed(
                          currentUser.uid, followedUserIds, theme),
                    ),

                    // Tab 1: Followed Trade Ideas
                    _KeepAliveTab(
                      child: _buildTradeIdeasFeed(
                        currentUser.uid,
                        followedUserIds,
                        theme,
                        isCommunity: false,
                      ),
                    ),

                    // Tab 2: Followed Trades Only
                    _KeepAliveTab(
                      child: _buildTradesFeed(
                          currentUser.uid, followedUserIds, theme),
                    ),

                    // Tab 3: Global Community Ideas
                    _KeepAliveTab(
                      child: _buildTradeIdeasFeed(
                        currentUser.uid,
                        null, // null = all community ideas
                        theme,
                        isCommunity: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFeedToolbar(ThemeData theme) {
    final isIdeaTab = _tabController.index == 1 || _tabController.index == 3;
    final hasActiveFilter =
        isIdeaTab ? _selectedSentiment != 'all' : _selectedFilter != 'all';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              key: const PageStorageKey<String>('feed_stream_pills_scroll'),
              controller: _chipScrollController,
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _streamPill(0, 'All', icon: Icons.dynamic_feed_rounded),
                  const SizedBox(width: 8),
                  _streamPill(1, 'Trade Ideas',
                      icon: Icons.lightbulb_outline_rounded),
                  const SizedBox(width: 8),
                  _streamPill(2, 'Trades', icon: Icons.swap_horiz_rounded),
                  const SizedBox(width: 8),
                  _streamPill(
                    3,
                    'Community',
                    key: _communityChipKey,
                    icon: Icons.groups_outlined,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildFilterMenuButton(theme, hasActiveFilter, isIdeaTab),
        ],
      ),
    );
  }

  Widget _streamPill(int index, String label, {Key? key, IconData? icon}) {
    final isSelected = _tabController.index == index;
    final theme = Theme.of(context);
    return ChoiceChip(
      key: key,
      avatar: icon != null
          ? Icon(
              icon,
              size: 15,
              color: isSelected
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurfaceVariant,
            )
          : null,
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
      selected: isSelected,
      showCheckmark: false,
      selectedColor: theme.colorScheme.primaryContainer,
      backgroundColor:
          theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      padding:
          EdgeInsets.symmetric(horizontal: icon != null ? 8 : 10, vertical: 4),
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
            _tabController.animateTo(index);
          });
          if (key != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final chipContext = (key as GlobalKey).currentContext;
              if (chipContext != null) {
                Scrollable.ensureVisible(
                  chipContext,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  alignment: 0.5,
                );
              }
            });
          }
        }
      },
    );
  }

  Widget _buildFilterMenuButton(
      ThemeData theme, bool hasActiveFilter, bool isIdeaTab) {
    return PopupMenuButton<String>(
      tooltip: 'Filter Feed',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: hasActiveFilter
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasActiveFilter
                ? theme.colorScheme.primary.withValues(alpha: 0.3)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                Icons.tune_rounded,
                size: 20,
                color: hasActiveFilter
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              if (hasActiveFilter)
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
          if (isIdeaTab) {
            _selectedSentiment = value;
          } else {
            _selectedFilter = value;
          }
        });
      },
      itemBuilder: (context) {
        if (isIdeaTab) {
          return [
            PopupMenuItem(
              value: 'all',
              child: _menuItemRow('All Ideas', Icons.lightbulb_outline,
                  _selectedSentiment == 'all'),
            ),
            PopupMenuItem(
              value: 'bullish',
              child: _menuItemRow('Bullish', Icons.trending_up_rounded,
                  _selectedSentiment == 'bullish', Colors.green),
            ),
            PopupMenuItem(
              value: 'bearish',
              child: _menuItemRow('Bearish', Icons.trending_down_rounded,
                  _selectedSentiment == 'bearish', Colors.red),
            ),
            PopupMenuItem(
              value: 'neutral',
              child: _menuItemRow('Neutral', Icons.trending_flat_rounded,
                  _selectedSentiment == 'neutral', Colors.grey),
            ),
          ];
        } else {
          return [
            PopupMenuItem(
              value: 'all',
              child: _menuItemRow(
                  'All Activity', Icons.grid_view, _selectedFilter == 'all'),
            ),
            PopupMenuItem(
              value: 'equity',
              child: _menuItemRow(
                  'Stocks/ETFs', Icons.show_chart, _selectedFilter == 'equity'),
            ),
            PopupMenuItem(
              value: 'option',
              child: _menuItemRow('Options', Icons.candlestick_chart,
                  _selectedFilter == 'option'),
            ),
            PopupMenuItem(
              value: 'buy',
              child: _menuItemRow('Buys Only', Icons.arrow_downward,
                  _selectedFilter == 'buy', Colors.green),
            ),
            PopupMenuItem(
              value: 'sell',
              child: _menuItemRow('Sells Only', Icons.arrow_upward,
                  _selectedFilter == 'sell', Colors.red),
            ),
          ];
        }
      },
    );
  }

  Widget _menuItemRow(String text, IconData icon, bool isSelected,
      [Color? iconColor]) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: iconColor ??
              (isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? theme.colorScheme.primary : null,
            ),
          ),
        ),
        if (isSelected)
          Icon(Icons.check, size: 16, color: theme.colorScheme.primary),
      ],
    );
  }

  /// Tab 0: Interleaved trades and trade ideas
  Widget _buildAllFeed(
    String currentUserId,
    List<String> followedUserIds,
    ThemeData theme,
  ) {
    if (followedUserIds.isEmpty) {
      return _buildNoFollowingEmptyState(theme);
    }

    return StreamBuilder<List<GroupActivity>>(
      stream: widget.firestoreService
          .getFollowedUsersActivitiesStream(followedUserIds),
      builder: (context, actSnapshot) {
        return StreamBuilder<List<GroupAnalysisPost>>(
          stream: widget.firestoreService
              .getSocialTradeIdeasStream(authorIds: followedUserIds),
          builder: (context, ideaSnapshot) {
            if (actSnapshot.connectionState == ConnectionState.waiting &&
                ideaSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final activities = actSnapshot.data ?? [];
            final ideas = ideaSnapshot.data ?? [];

            // Filter activities
            final filteredActivities = activities.where((act) {
              if (_selectedFilter == 'equity') {
                return act.assetType?.toLowerCase() == 'equity' ||
                    act.assetType == null;
              } else if (_selectedFilter == 'option') {
                return act.assetType?.toLowerCase() == 'option';
              } else if (_selectedFilter == 'buy') {
                return act.isBuy;
              } else if (_selectedFilter == 'sell') {
                return act.isSell;
              }
              return true;
            }).toList();

            // Merge items
            var feedItems = <_FeedItem>[
              ...filteredActivities
                  .map((a) => _FeedItem(activity: a, date: a.timestamp)),
              ...ideas.map((i) => _FeedItem(idea: i, date: i.createdAt)),
            ];

            if (_searchQuery.trim().isNotEmpty) {
              final q = _searchQuery.trim().toLowerCase();
              feedItems = feedItems.where((item) {
                if (item.idea != null) {
                  final idea = item.idea!;
                  return idea.symbol.toLowerCase().contains(q) ||
                      idea.title.toLowerCase().contains(q) ||
                      (idea.thesis.toLowerCase().contains(q)) ||
                      (idea.authorName.toLowerCase().contains(q));
                } else if (item.activity != null) {
                  final act = item.activity!;
                  return (act.symbol?.toLowerCase().contains(q) ?? false) ||
                      act.userName.toLowerCase().contains(q) ||
                      (act.description?.toLowerCase().contains(q) ?? false);
                }
                return false;
              }).toList();
            }

            feedItems.sort((a, b) => b.date.compareTo(a.date));

            if (feedItems.isEmpty) {
              if (_searchQuery.trim().isNotEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off,
                          size: 56,
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.6)),
                      const SizedBox(height: 12),
                      Text('No matching feed items',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text('Try adjusting your search query',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.disabledColor,
                          )),
                    ],
                  ),
                );
              }
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.dynamic_feed_outlined,
                        size: 56,
                        color: theme.disabledColor,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No recent activity or shared ideas from followed traders.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.disabledColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 80),
              itemCount: feedItems.length,
              itemBuilder: (context, index) {
                final item = feedItems[index];
                if (item.idea != null) {
                  return _buildTradeIdeaCard(
                      context, item.idea!, currentUserId, theme);
                } else {
                  return _buildActivityCard(context, item.activity!, theme);
                }
              },
            );
          },
        );
      },
    );
  }

  /// Tab 1 & 3: Trade ideas stream
  Widget _buildTradeIdeasFeed(
    String currentUserId,
    List<String>? authorIds,
    ThemeData theme, {
    required bool isCommunity,
  }) {
    if (!isCommunity && (authorIds == null || authorIds.isEmpty)) {
      return _buildNoFollowingEmptyState(theme);
    }

    return StreamBuilder<List<GroupAnalysisPost>>(
      stream: widget.firestoreService.getSocialTradeIdeasStream(
        authorIds: isCommunity ? null : authorIds,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          final isPermissionDenied =
              snapshot.error.toString().contains('permission-denied');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isPermissionDenied
                        ? Icons.lock_outline_rounded
                        : Icons.error_outline_rounded,
                    size: 48,
                    color: isPermissionDenied
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.error,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isPermissionDenied
                        ? 'Firestore Rules Not Deployed'
                        : 'Error Loading Trade Ideas',
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isPermissionDenied
                        ? 'The security rules for trade ideas must be deployed to Firebase (realizealpha):\nfirebase deploy --only firestore:rules'
                        : '${snapshot.error}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.disabledColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final ideas = snapshot.data ?? [];
        var filtered = ideas.where((idea) {
          if (_selectedSentiment == 'bullish') {
            return idea.sentiment == GroupAnalysisSentiment.bullish;
          } else if (_selectedSentiment == 'bearish') {
            return idea.sentiment == GroupAnalysisSentiment.bearish;
          } else if (_selectedSentiment == 'neutral') {
            return idea.sentiment == GroupAnalysisSentiment.neutral;
          }
          return true;
        }).toList();

        if (_searchQuery.trim().isNotEmpty) {
          final q = _searchQuery.trim().toLowerCase();
          filtered = filtered.where((idea) {
            return idea.symbol.toLowerCase().contains(q) ||
                idea.title.toLowerCase().contains(q) ||
                (idea.thesis.toLowerCase().contains(q)) ||
                (idea.authorName.toLowerCase().contains(q));
          }).toList();
        }

        if (filtered.isEmpty) {
          if (_searchQuery.trim().isNotEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off,
                      size: 56,
                      color: theme.colorScheme.primary.withValues(alpha: 0.6)),
                  const SizedBox(height: 12),
                  Text('No matching trade ideas',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('Try adjusting your search query',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.disabledColor,
                      )),
                ],
              ),
            );
          }
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 56,
                    color: theme.disabledColor,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isCommunity
                        ? 'No community trade ideas found. Be the first to share one!'
                        : 'No trade ideas from traders you follow yet.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.disabledColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Share a Trade Idea'),
                    onPressed: () => _openShareTradeIdea(context),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 80),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            return _buildTradeIdeaCard(
                context, filtered[index], currentUserId, theme);
          },
        );
      },
    );
  }

  /// Tab 2: Followed trades stream
  Widget _buildTradesFeed(
    String currentUserId,
    List<String> followedUserIds,
    ThemeData theme,
  ) {
    if (followedUserIds.isEmpty) {
      return _buildNoFollowingEmptyState(theme);
    }

    return StreamBuilder<List<GroupActivity>>(
      stream: widget.firestoreService
          .getFollowedUsersActivitiesStream(followedUserIds),
      builder: (context, activitySnapshot) {
        if (activitySnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (activitySnapshot.hasError) {
          return Center(
            child: Text('Failed to load activities: ${activitySnapshot.error}'),
          );
        }

        final activities = activitySnapshot.data ?? [];
        var filtered = activities.where((act) {
          if (_selectedFilter == 'equity') {
            return act.assetType?.toLowerCase() == 'equity' ||
                act.assetType == null;
          } else if (_selectedFilter == 'option') {
            return act.assetType?.toLowerCase() == 'option';
          } else if (_selectedFilter == 'buy') {
            return act.isBuy;
          } else if (_selectedFilter == 'sell') {
            return act.isSell;
          }
          return true;
        }).toList();

        if (_searchQuery.trim().isNotEmpty) {
          final q = _searchQuery.trim().toLowerCase();
          filtered = filtered.where((act) {
            return (act.symbol?.toLowerCase().contains(q) ?? false) ||
                act.userName.toLowerCase().contains(q) ||
                (act.description?.toLowerCase().contains(q) ?? false);
          }).toList();
        }

        if (filtered.isEmpty) {
          if (_searchQuery.trim().isNotEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off,
                      size: 56,
                      color: theme.colorScheme.primary.withValues(alpha: 0.6)),
                  const SizedBox(height: 12),
                  Text('No matching trades',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('Try adjusting your search query',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.disabledColor,
                      )),
                ],
              ),
            );
          }
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.swap_vert_rounded,
                    size: 56,
                    color: theme.disabledColor,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No recent trade activity from followed traders.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.disabledColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 80),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final activity = filtered[index];
            return _buildActivityCard(context, activity, theme);
          },
        );
      },
    );
  }

  Widget _buildNoFollowingEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_add_alt_1_outlined,
              size: 64,
              color: theme.disabledColor,
            ),
            const SizedBox(height: 16),
            Text(
              'You are not following any traders yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Follow top traders from the Leaderboard or Discover tab to see their trades, shared ideas, and clone strategies.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.disabledColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Card displaying a shared trade idea or thesis
  Widget _buildTradeIdeaCard(
    BuildContext context,
    GroupAnalysisPost idea,
    String currentUserId,
    ThemeData theme,
  ) {
    final dateFormat = DateFormat('MMM d, h:mm a');
    final sentiment = idea.sentiment;
    final isLiked = idea.isLikedBy(currentUserId);
    final canManage = currentUserId.isNotEmpty &&
        (idea.authorId == currentUserId || widget.userRole == UserRole.admin);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showIdeaDetails(context, idea),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Author, Date, and Sentiment Chip
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _openUserProfile(
                        context, idea.authorId, idea.authorName),
                    child: CircleAvatar(
                      radius: 17,
                      backgroundImage: idea.authorPhotoUrl != null
                          ? CachedNetworkImageProvider(idea.authorPhotoUrl!)
                          : null,
                      child: idea.authorPhotoUrl == null
                          ? const Icon(Icons.person, size: 18)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          idea.authorName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          dateFormat.format(idea.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color
                                ?.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Sentiment chip
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: sentiment.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: sentiment.color.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(sentiment.icon, size: 13, color: sentiment.color),
                        const SizedBox(width: 4),
                        Text(
                          sentiment.label.toUpperCase(),
                          style: TextStyle(
                            color: sentiment.color,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (canManage) ...[
                    const SizedBox(width: 2),
                    PopupMenuButton<String>(
                      tooltip: 'Idea options',
                      icon: const Icon(Icons.more_vert, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editTradeIdea(context, idea);
                        } else if (value == 'delete') {
                          _deleteTradeIdea(context, idea);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 20),
                              SizedBox(width: 12),
                              Text('Edit Idea'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline,
                                  size: 20, color: Colors.red),
                              const SizedBox(width: 12),
                              Text(
                                'Delete Idea',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),

              // Title and Symbol
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '\$${idea.symbol}',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      idea.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // Thesis narrative
              Text(
                idea.thesis,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color
                      ?.withValues(alpha: 0.85),
                ),
              ),

              // Target metrics (Entry, Target, Est Return, Risk/Reward)
              if (idea.entryTarget != null ||
                  idea.targetPrice != null ||
                  idea.stopLoss != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (idea.entryTarget != null)
                        Text(
                          'Entry: \$${idea.entryTarget!.toStringAsFixed(2)}',
                          style: theme.textTheme.bodySmall,
                        ),
                      if (idea.targetPrice != null)
                        Text(
                          'Target: \$${idea.targetPrice!.toStringAsFixed(2)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (idea.potentialReturnPercent != null)
                        Text(
                          '${idea.potentialReturnPercent! >= 0 ? '+' : ''}${idea.potentialReturnPercent!.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: idea.potentialReturnPercent! >= 0
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      if (idea.riskRewardRatio != null)
                        Text(
                          'R:R ${idea.riskRewardRatio!.toStringAsFixed(1)}:1',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent,
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 8),
              Divider(
                height: 12,
                thickness: 0.5,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
              ),
              const SizedBox(height: 4),

              // Footer: Likes, Horizon, and Clone Strategy action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          isLiked
                              ? Icons.thumb_up_rounded
                              : Icons.thumb_up_outlined,
                          size: 17,
                          color: isLiked ? theme.colorScheme.primary : null,
                        ),
                        onPressed: () {
                          widget.firestoreService.toggleLikeSocialTradeIdea(
                              idea.id, currentUserId);
                        },
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${idea.likes.length}',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          idea.timeHorizon.label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // 1-Tap Clone Strategy / Copy Trade button
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      minimumSize: const Size(90, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 13),
                    label: const Text('Clone Strategy',
                        style: TextStyle(fontSize: 11)),
                    onPressed: () => _cloneStrategy(context, idea),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityCard(
    BuildContext context,
    GroupActivity activity,
    ThemeData theme,
  ) {
    final dateFormat = DateFormat('MMM d, h:mm a');
    final isBuy = activity.isBuy;
    final badgeColor = isBuy ? Colors.green : Colors.red;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showActivityDetails(context, activity),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Trader info & Time
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _openUserProfile(
                        context, activity.userId, activity.displayUserName),
                    child: CircleAvatar(
                      radius: 17,
                      backgroundImage: activity.userPhotoUrl != null
                          ? CachedNetworkImageProvider(activity.userPhotoUrl!)
                          : null,
                      child: activity.userPhotoUrl == null
                          ? const Icon(Icons.person, size: 18)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => _openUserProfile(context,
                              activity.userId, activity.displayUserName),
                          child: Text(
                            activity.displayUserName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          dateFormat.format(activity.timestamp),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color
                                ?.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: badgeColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      (activity.side ?? 'trade').toUpperCase(),
                      style: TextStyle(
                        color: badgeColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Title and Symbol
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  if (activity.symbol != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer
                            .withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        activity.symbol!,
                        style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                  Expanded(
                    child: Text(
                      activity.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),

              if (activity.description != null &&
                  activity.description!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  activity.description!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color
                        ?.withValues(alpha: 0.8),
                  ),
                ),
              ],

              const SizedBox(height: 8),
              Divider(
                height: 12,
                thickness: 0.5,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
              ),
              const SizedBox(height: 4),

              // Footer: Price / Amount and Copy Trade Action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.hideAmounts
                            ? 'Amount: \$***'
                            : 'Total: ${activity.formattedTotal}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      if (!activity.hideAmounts && activity.price != null) ...[
                        Text(
                          'Price: \$${activity.price!.toStringAsFixed(2)} | Qty: ${activity.formattedQuantity}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color
                                ?.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (widget.brokerageUser != null &&
                      widget.service != null &&
                      activity.symbol != null) ...[
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        minimumSize: const Size(72, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 13),
                      label: const Text('Copy', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        _copyTrade(context, activity);
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openUserProfile(BuildContext context, String userId, String userName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TraderProfileWidget(
          auth: widget.auth,
          userId: userId,
          analytics: widget.analytics,
          observer: widget.observer,
          brokerageUser: widget.brokerageUser,
          service: widget.service,
        ),
      ),
    );
  }

  Future<void> _openShareTradeIdea(BuildContext context) async {
    final created = await ShareTradeIdeaSheet.show(
      context: context,
      auth: widget.auth,
      firestoreService: widget.firestoreService,
      analytics: widget.analytics,
    );
    if (created != null) {
      setState(() {});
    }
  }

  Future<void> _cloneStrategy(
      BuildContext context, GroupAnalysisPost idea) async {
    widget.analytics.logEvent(
      name: 'clone_strategy_clicked',
      parameters: {
        'symbol': idea.symbol,
        'sentiment': idea.sentiment.name,
      },
    );

    if (widget.brokerageUser == null || widget.service == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Please connect a brokerage account to clone strategies')),
      );
      return;
    }

    final side =
        idea.sentiment == GroupAnalysisSentiment.bearish ? 'sell' : 'buy';
    final userAccount = widget.brokerageUser?.accounts.isNotEmpty == true
        ? widget.brokerageUser!.accounts.first.accountNumber
        : '';
    final instrumentOrder = InstrumentOrder.fromJson({
      'id': 'clone_${idea.id}',
      'url': '',
      'account': userAccount,
      'position': '',
      'instrument': '',
      'instrument_id': '',
      'state': 'unconfirmed',
      'type': idea.entryTarget != null ? 'limit' : 'market',
      'side': side,
      'time_in_force': 'gtc',
      'trigger': 'immediate',
      'price': idea.entryTarget ?? idea.targetPrice ?? 0.0,
      'quantity': 1.0,
      'symbol': idea.symbol,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    await showCopyTradeDialog(
      context: context,
      brokerageService: widget.service!,
      currentUser: widget.brokerageUser!,
      instrumentOrder: instrumentOrder,
    );
  }

  Future<void> _copyTrade(BuildContext context, GroupActivity activity) async {
    if (widget.brokerageUser == null || widget.service == null) return;
    final userAccount = widget.brokerageUser?.accounts.isNotEmpty == true
        ? widget.brokerageUser!.accounts.first.accountNumber
        : '';
    final instrumentOrder = activity.symbol != null
        ? InstrumentOrder.fromJson({
            'id': 'copy_${activity.id}',
            'url': '',
            'account': userAccount,
            'position': '',
            'instrument': '',
            'instrument_id': '',
            'state': 'unconfirmed',
            'type': activity.orderType ?? 'market',
            'side': activity.side ?? 'buy',
            'time_in_force': 'gfd',
            'trigger': 'immediate',
            'price': activity.price ?? 0.0,
            'quantity': activity.quantity ?? 1.0,
            'symbol': activity.symbol ?? '',
            'created_at': activity.timestamp.toIso8601String(),
            'updated_at': activity.timestamp.toIso8601String(),
          })
        : null;

    await showCopyTradeDialog(
      context: context,
      brokerageService: widget.service!,
      currentUser: widget.brokerageUser!,
      instrumentOrder: instrumentOrder,
    );
  }

  Future<void> _editTradeIdea(
      BuildContext context, GroupAnalysisPost idea) async {
    final updated = await ShareTradeIdeaSheet.show(
      context: context,
      firestoreService: widget.firestoreService,
      auth: widget.auth,
      analytics: widget.analytics,
      existingPost: idea,
    );
    if (updated != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trade idea updated successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {});
    }
  }

  Future<void> _deleteTradeIdea(
      BuildContext context, GroupAnalysisPost idea) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Trade Idea'),
        content: const Text(
          'Are you sure you want to delete this trade idea? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await widget.firestoreService.deleteSocialTradeIdea(idea.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Trade idea deleted.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() {});
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete trade idea: $e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _showIdeaDetails(BuildContext context, GroupAnalysisPost idea) {
    final theme = Theme.of(context);
    final currentUserId = widget.auth.currentUser?.uid;
    final canManage = currentUserId != null &&
        (idea.authorId == currentUserId || widget.userRole == UserRole.admin);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundImage: idea.authorPhotoUrl != null
                        ? CachedNetworkImageProvider(idea.authorPhotoUrl!)
                        : null,
                    child: idea.authorPhotoUrl == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(idea.authorName,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        Text('Shared Trade Idea',
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Chip(
                    avatar: Icon(idea.sentiment.icon,
                        size: 14, color: idea.sentiment.color),
                    label: Text(idea.sentiment.label),
                  ),
                  if (canManage) ...[
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      tooltip: 'Idea options',
                      icon: const Icon(Icons.more_vert, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onSelected: (value) {
                        Navigator.pop(bottomSheetContext);
                        if (value == 'edit') {
                          _editTradeIdea(context, idea);
                        } else if (value == 'delete') {
                          _deleteTradeIdea(context, idea);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 20),
                              SizedBox(width: 12),
                              Text('Edit Idea'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline,
                                  size: 20, color: Colors.red),
                              const SizedBox(width: 12),
                              Text(
                                'Delete Idea',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Text(idea.title,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(idea.thesis, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              const Divider(),
              ListTile(
                dense: true,
                title: const Text('Symbol'),
                trailing: Text('\$${idea.symbol}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              if (idea.entryTarget != null)
                ListTile(
                  dense: true,
                  title: const Text('Entry Target'),
                  trailing: Text('\$${idea.entryTarget!.toStringAsFixed(2)}'),
                ),
              if (idea.targetPrice != null)
                ListTile(
                  dense: true,
                  title: const Text('Target Price'),
                  trailing: Text('\$${idea.targetPrice!.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              if (idea.stopLoss != null)
                ListTile(
                  dense: true,
                  title: const Text('Stop Loss'),
                  trailing: Text('\$${idea.stopLoss!.toStringAsFixed(2)}'),
                ),
              if (idea.riskRewardRatio != null)
                ListTile(
                  dense: true,
                  title: const Text('Risk/Reward Ratio'),
                  trailing: Text(
                    '${idea.riskRewardRatio!.toStringAsFixed(2)}:1',
                    style: const TextStyle(
                        color: Colors.blueAccent, fontWeight: FontWeight.bold),
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Clone this Strategy'),
                  onPressed: () {
                    Navigator.pop(context);
                    _cloneStrategy(context, idea);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showActivityDetails(BuildContext context, GroupActivity activity) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: activity.userPhotoUrl != null
                      ? CachedNetworkImageProvider(activity.userPhotoUrl!)
                      : null,
                  child: activity.userPhotoUrl == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(activity.displayUserName,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      Text(activity.title, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            if (activity.symbol != null)
              ListTile(
                dense: true,
                title: const Text('Symbol'),
                trailing: Text(activity.symbol!,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            if (activity.side != null)
              ListTile(
                dense: true,
                title: const Text('Action'),
                trailing: Text(activity.side!.toUpperCase(),
                    style: TextStyle(
                        color: activity.isBuy ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold)),
              ),
            ListTile(
              dense: true,
              title: const Text('Quantity'),
              trailing: Text(activity.formattedQuantity),
            ),
            ListTile(
              dense: true,
              title: const Text('Price'),
              trailing: Text(activity.price != null
                  ? '\$${activity.price!.toStringAsFixed(2)}'
                  : 'N/A'),
            ),
            ListTile(
              dense: true,
              title: const Text('Total Amount'),
              trailing: Text(activity.formattedTotal,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  _copyTrade(context, activity);
                },
                child: const Text('Copy this Trade'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedItem {
  final GroupActivity? activity;
  final GroupAnalysisPost? idea;
  final DateTime date;

  _FeedItem({this.activity, this.idea, required this.date});
}

class _KeepAliveTab extends StatefulWidget {
  final Widget child;

  const _KeepAliveTab({required this.child});

  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
