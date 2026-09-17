import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/group_activity.dart';
import 'package:robinhood_options_mobile/model/group_analysis.dart';
import 'package:robinhood_options_mobile/model/instrument_order.dart';
import 'package:robinhood_options_mobile/model/user_follow.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/copy_trade_button_widget.dart';
import 'package:robinhood_options_mobile/widgets/share_trade_idea_sheet.dart';
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

  const FollowingActivityFeedWidget({
    super.key,
    required this.auth,
    required this.firestoreService,
    required this.brokerageUser,
    required this.service,
    required this.analytics,
    required this.observer,
  });

  @override
  State<FollowingActivityFeedWidget> createState() =>
      _FollowingActivityFeedWidgetState();
}

class _FollowingActivityFeedWidgetState
    extends State<FollowingActivityFeedWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'all'; // 'all', 'equity', 'option', 'buy', 'sell'
  String _selectedSentiment = 'all'; // 'all', 'bullish', 'bearish', 'neutral'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = widget.auth.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Social Feed')),
        body: const Center(
          child: Text('Sign in to view your social feed.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Social Feed & Ideas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Feed',
            onPressed: () => setState(() {}),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: Icon(Icons.dynamic_feed_rounded), text: 'All'),
            Tab(
                icon: Icon(Icons.lightbulb_outline_rounded),
                text: 'Trade Ideas'),
            Tab(icon: Icon(Icons.swap_vert_rounded), text: 'Trades'),
            Tab(icon: Icon(Icons.public_rounded), text: 'Community'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Share Idea'),
        onPressed: () => _openShareTradeIdea(context),
      ),
      body: StreamBuilder<List<UserFollow>>(
        stream: widget.firestoreService.getFollowingStream(currentUser.uid),
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
              _buildFilterBar(theme),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 0: All (Interleaved)
                    _buildAllFeed(currentUser.uid, followedUserIds, theme),

                    // Tab 1: Followed Trade Ideas
                    _buildTradeIdeasFeed(
                      currentUser.uid,
                      followedUserIds,
                      theme,
                      isCommunity: false,
                    ),

                    // Tab 2: Followed Trades Only
                    _buildTradesFeed(currentUser.uid, followedUserIds, theme),

                    // Tab 3: Global Community Ideas
                    _buildTradeIdeasFeed(
                      currentUser.uid,
                      null, // null = all community ideas
                      theme,
                      isCommunity: true,
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

  Widget _buildFilterBar(ThemeData theme) {
    final isIdeaTab = _tabController.index == 1 || _tabController.index == 3;

    if (isIdeaTab) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            _sentimentChip('all', 'All Ideas', Icons.lightbulb_outline),
            const SizedBox(width: 8),
            _sentimentChip(
                'bullish', 'Bullish', Icons.trending_up_rounded, Colors.green),
            const SizedBox(width: 8),
            _sentimentChip(
                'bearish', 'Bearish', Icons.trending_down_rounded, Colors.red),
            const SizedBox(width: 8),
            _sentimentChip(
                'neutral', 'Neutral', Icons.trending_flat_rounded, Colors.grey),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _filterChip('all', 'All Activity', Icons.grid_view),
          const SizedBox(width: 8),
          _filterChip('equity', 'Stocks/ETFs', Icons.show_chart),
          const SizedBox(width: 8),
          _filterChip('option', 'Options', Icons.candlestick_chart),
          const SizedBox(width: 8),
          _filterChip('buy', 'Buys Only', Icons.arrow_downward),
          const SizedBox(width: 8),
          _filterChip('sell', 'Sells Only', Icons.arrow_upward),
        ],
      ),
    );
  }

  Widget _filterChip(String filterKey, String label, IconData icon) {
    final isSelected = _selectedFilter == filterKey;
    final theme = Theme.of(context);
    return FilterChip(
      selected: isSelected,
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected ? theme.colorScheme.onPrimary : null,
      ),
      label: Text(label),
      onSelected: (_) {
        setState(() => _selectedFilter = filterKey);
      },
    );
  }

  Widget _sentimentChip(String sentimentKey, String label, IconData icon,
      [Color? color]) {
    final isSelected = _selectedSentiment == sentimentKey;
    final theme = Theme.of(context);
    return FilterChip(
      selected: isSelected,
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected ? Colors.white : (color ?? theme.colorScheme.primary),
      ),
      label: Text(label),
      selectedColor: color,
      onSelected: (_) {
        setState(() => _selectedSentiment = sentimentKey);
      },
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
            final feedItems = <_FeedItem>[
              ...filteredActivities
                  .map((a) => _FeedItem(activity: a, date: a.timestamp)),
              ...ideas.map((i) => _FeedItem(idea: i, date: i.createdAt)),
            ];

            feedItems.sort((a, b) => b.date.compareTo(a.date));

            if (feedItems.isEmpty) {
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
        final filtered = ideas.where((idea) {
          if (_selectedSentiment == 'bullish') {
            return idea.sentiment == GroupAnalysisSentiment.bullish;
          } else if (_selectedSentiment == 'bearish') {
            return idea.sentiment == GroupAnalysisSentiment.bearish;
          } else if (_selectedSentiment == 'neutral') {
            return idea.sentiment == GroupAnalysisSentiment.neutral;
          }
          return true;
        }).toList();

        if (filtered.isEmpty) {
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
        final filtered = activities.where((act) {
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

        if (filtered.isEmpty) {
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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showIdeaDetails(context, idea),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Author & Date
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _openUserProfile(
                        context, idea.authorId, idea.authorName),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundImage: idea.authorPhotoUrl != null
                          ? CachedNetworkImageProvider(idea.authorPhotoUrl!)
                          : null,
                      child: idea.authorPhotoUrl == null
                          ? const Icon(Icons.person, size: 20)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              idea.authorName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Idea',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
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
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: sentiment.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: sentiment.color.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(sentiment.icon, size: 14, color: sentiment.color),
                        const SizedBox(width: 4),
                        Text(
                          sentiment.label.toUpperCase(),
                          style: TextStyle(
                            color: sentiment.color,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Title and Symbol
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '\$${idea.symbol}',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      idea.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

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
                    color: theme.colorScheme.surfaceContainerHighest,
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
                            fontWeight: FontWeight.bold,
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

              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // Footer: Likes, Horizon, and Clone Strategy action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          isLiked
                              ? Icons.thumb_up_rounded
                              : Icons.thumb_up_outlined,
                          size: 18,
                          color: isLiked ? theme.colorScheme.primary : null,
                        ),
                        onPressed: () {
                          widget.firestoreService.toggleLikeSocialTradeIdea(
                              idea.id, currentUserId);
                        },
                      ),
                      Text(
                        '${idea.likes.length}',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(width: 12),
                      Chip(
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        label: Text(
                          idea.timeHorizon.label,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                  ),

                  // 1-Tap Clone Strategy / Copy Trade button
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      minimumSize: const Size(100, 32),
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 14),
                    label: const Text('Clone Strategy',
                        style: TextStyle(fontSize: 12)),
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showActivityDetails(context, activity),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
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
                      radius: 18,
                      backgroundImage: activity.userPhotoUrl != null
                          ? CachedNetworkImageProvider(activity.userPhotoUrl!)
                          : null,
                      child: activity.userPhotoUrl == null
                          ? const Icon(Icons.person, size: 20)
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
                              fontWeight: FontWeight.bold,
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
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: badgeColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      (activity.side ?? 'trade').toUpperCase(),
                      style: TextStyle(
                        color: badgeColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Title and Symbol
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  if (activity.symbol != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
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

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),

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
                          fontWeight: FontWeight.bold,
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
                          horizontal: 12,
                          vertical: 6,
                        ),
                        minimumSize: const Size(80, 32),
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 14),
                      label: const Text('Copy', style: TextStyle(fontSize: 12)),
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

  void _showIdeaDetails(BuildContext context, GroupAnalysisPost idea) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
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
