import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/top_portfolio_entry.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/trader_profile_widget.dart';

/// Leaderboard showcasing top-performing portfolios with time-period filters,
/// detailed metrics, and a quantified user reputation system.
class TopPortfoliosLeaderboardWidget extends StatefulWidget {
  final firebase_auth.FirebaseAuth auth;
  final FirestoreService firestoreService;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser? brokerageUser;
  final IBrokerageService? service;
  final bool showAppBar;

  const TopPortfoliosLeaderboardWidget({
    super.key,
    required this.auth,
    required this.firestoreService,
    required this.analytics,
    required this.observer,
    this.brokerageUser,
    this.service,
    this.showAppBar = true,
  });

  @override
  State<TopPortfoliosLeaderboardWidget> createState() =>
      _TopPortfoliosLeaderboardWidgetState();
}

class _TopPortfoliosLeaderboardWidgetState
    extends State<TopPortfoliosLeaderboardWidget> {
  LeaderboardTimePeriod _selectedPeriod = LeaderboardTimePeriod.allTime;
  LeaderboardSortOption _selectedSort = LeaderboardSortOption.totalReturn;
  bool _verifiedOnly = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final NumberFormat _percentFormat =
      NumberFormat.decimalPercentPattern(decimalDigits: 1);
  final NumberFormat _compactNumberFormat = NumberFormat.compact();

  @override
  void initState() {
    super.initState();
    widget.analytics.logScreenView(
      screenName: 'top_portfolios_leaderboard',
      screenClass: 'TopPortfoliosLeaderboardWidget',
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? theme.colorScheme.surface
          : theme.colorScheme.surfaceContainerLowest,
      body: CustomScrollView(
        slivers: [
          // AppBar
          if (widget.showAppBar)
            SliverAppBar(
              title: const Text('Top Portfolios'),
              floating: true,
              snap: true,
              pinned: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.info_outline_rounded),
                  tooltip: 'Reputation System Info',
                  onPressed: () => _showReputationInfoSheet(context),
                ),
                IconButton(
                  icon: Icon(
                    _verifiedOnly
                        ? Icons.filter_alt
                        : Icons.filter_alt_outlined,
                    color: _verifiedOnly ? theme.colorScheme.primary : null,
                  ),
                  tooltip: 'Filter Leaderboard',
                  onPressed: () => _showFilterDialog(context),
                ),
              ],
            ),

          // Unified Single-Row Controls: Period Chips + Sort Chips + Action Buttons
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Horizontally scrollable period & sort chips
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ...LeaderboardTimePeriod.values.map((period) {
                                final isSelected = _selectedPeriod == period;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6.0),
                                  child: ChoiceChip(
                                    label: Text(
                                      period.label,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: isSelected
                                            ? theme
                                                .colorScheme.onPrimaryContainer
                                            : theme
                                                .colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    selected: isSelected,
                                    showCheckmark: false,
                                    selectedColor:
                                        theme.colorScheme.primaryContainer,
                                    backgroundColor: theme
                                        .colorScheme.surfaceContainerHighest
                                        .withValues(alpha: 0.35),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(
                                        color: isSelected
                                            ? theme.colorScheme.primary
                                                .withValues(alpha: 0.3)
                                            : Colors.transparent,
                                      ),
                                    ),
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() {
                                          _selectedPeriod = period;
                                        });
                                        widget.analytics.logEvent(
                                          name: 'leaderboard_filter_period',
                                          parameters: {'period': period.name},
                                        );
                                      }
                                    },
                                  ),
                                );
                              }),
                              Container(
                                height: 20,
                                width: 1,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                color: theme.colorScheme.outlineVariant
                                    .withValues(alpha: 0.5),
                              ),
                              ...LeaderboardSortOption.values.map((opt) {
                                final isSelected = _selectedSort == opt;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6.0),
                                  child: ChoiceChip(
                                    avatar: Icon(
                                      opt.icon,
                                      size: 15,
                                      color: isSelected
                                          ? theme
                                              .colorScheme.onSecondaryContainer
                                          : theme.colorScheme.outline,
                                    ),
                                    label: Text(
                                      opt.label,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: isSelected
                                            ? theme.colorScheme
                                                .onSecondaryContainer
                                            : theme
                                                .colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    selected: isSelected,
                                    showCheckmark: false,
                                    selectedColor:
                                        theme.colorScheme.secondaryContainer,
                                    backgroundColor: theme
                                        .colorScheme.surfaceContainerHighest
                                        .withValues(alpha: 0.35),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(
                                        color: isSelected
                                            ? theme.colorScheme.secondary
                                                .withValues(alpha: 0.3)
                                            : Colors.transparent,
                                      ),
                                    ),
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() {
                                          _selectedSort = opt;
                                        });
                                        widget.analytics.logEvent(
                                          name: 'leaderboard_sort_changed',
                                          parameters: {'sort': opt.label},
                                        );
                                      }
                                    },
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                      if (!widget.showAppBar) ...[
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'Reputation System Info',
                          child: InkWell(
                            onTap: () => _showReputationInfoSheet(context),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.info_outline_rounded,
                                  size: 20,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'Filter Leaderboard',
                          child: InkWell(
                            onTap: () => _showFilterDialog(context),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _verifiedOnly
                                    ? theme.colorScheme.primary
                                        .withValues(alpha: 0.12)
                                    : theme.colorScheme.surfaceContainerHighest
                                        .withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _verifiedOnly
                                      ? theme.colorScheme.primary
                                          .withValues(alpha: 0.3)
                                      : theme.colorScheme.outlineVariant
                                          .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Center(
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Icon(
                                      Icons.tune_rounded,
                                      size: 20,
                                      color: _verifiedOnly
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurfaceVariant,
                                    ),
                                    if (_verifiedOnly)
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
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Active Filter Badges
                  if (_verifiedOnly)
                    Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          Chip(
                            avatar: const Icon(Icons.verified, size: 14),
                            label: const Text('Verified Only',
                                style: TextStyle(fontSize: 11)),
                            onDeleted: () {
                              setState(() => _verifiedOnly = false);
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Main Stream Content
          StreamBuilder<List<TopPortfolioEntry>>(
            stream: widget.firestoreService.getTopPortfoliosStream(
              period: _selectedPeriod,
              sortBy: _selectedSort,
              verifiedOnly: _verifiedOnly,
            ),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline_rounded,
                              size: 48, color: theme.colorScheme.error),
                          const SizedBox(height: 12),
                          Text('Failed to load leaderboard',
                              style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text(
                            '${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final allEntries = snapshot.data ?? [];
              final filteredEntries = _searchQuery.isEmpty
                  ? allEntries
                  : allEntries.where((e) {
                      final name = e.userName.toLowerCase();
                      final loc = (e.location ?? '').toLowerCase();
                      return name.contains(_searchQuery) ||
                          loc.contains(_searchQuery);
                    }).toList();

              if (filteredEntries.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.leaderboard_outlined,
                              size: 56, color: theme.disabledColor),
                          const SizedBox(height: 16),
                          Text(
                            'No Portfolios Found',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No top traders match "$_searchQuery".'
                                : 'No public portfolios match the current filters.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_verifiedOnly || _searchQuery.isNotEmpty)
                            OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _verifiedOnly = false;
                                  _searchController.clear();
                                  _searchQuery = '';
                                });
                              },
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Reset Filters'),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    // Podium Header for top 3 traders (when no search query is active)
                    if (index == 0 &&
                        _searchQuery.isEmpty &&
                        filteredEntries.length >= 3) {
                      return Column(
                        children: [
                          _buildPodium(
                              context, filteredEntries.take(3).toList()),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.0),
                            child: Divider(),
                          ),
                        ],
                      );
                    }

                    final entry = filteredEntries[index];
                    return _buildLeaderboardCard(context, entry);
                  },
                  childCount: filteredEntries.length,
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  /// Top 3 Olympic-style Podium
  Widget _buildPodium(BuildContext context, List<TopPortfolioEntry> top3) {
    if (top3.length < 3) return const SizedBox.shrink();
    final first = top3[0];
    final second = top3[1];
    final third = top3[2];

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 12),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
            Theme.of(context).colorScheme.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events_rounded,
                  color: Colors.amber, size: 20),
              const SizedBox(width: 6),
              Text(
                'Top Performers (${_selectedPeriod.label})',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // #2 Silver (Left)
              Expanded(
                child: _buildPodiumColumn(
                  context,
                  entry: second,
                  rank: 2,
                  medalColor: const Color(0xFFC0C0C0), // Silver
                  pedestalHeight: 65,
                ),
              ),
              // #1 Gold (Center, elevated)
              Expanded(
                child: _buildPodiumColumn(
                  context,
                  entry: first,
                  rank: 1,
                  medalColor: const Color(0xFFFFD700), // Gold
                  pedestalHeight: 90,
                ),
              ),
              // #3 Bronze (Right)
              Expanded(
                child: _buildPodiumColumn(
                  context,
                  entry: third,
                  rank: 3,
                  medalColor: const Color(0xFFCD7F32), // Bronze
                  pedestalHeight: 45,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumColumn(
    BuildContext context, {
    required TopPortfolioEntry entry,
    required int rank,
    required Color medalColor,
    required double pedestalHeight,
  }) {
    final theme = Theme.of(context);
    final returnVal = entry.returnForPeriod(_selectedPeriod);
    final isPositive = returnVal >= 0;

    return GestureDetector(
      onTap: () => _navigateToProfile(entry.userId),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Crown / Trophy for #1
          if (rank == 1)
            const Icon(Icons.workspace_premium,
                color: Color(0xFFFFD700), size: 22)
          else
            const SizedBox(height: 22),

          // Avatar with ring
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: medalColor, width: 2.5),
                ),
                child: CircleAvatar(
                  radius: rank == 1 ? 28 : 22,
                  backgroundImage: entry.userPhotoUrl != null
                      ? CachedNetworkImageProvider(entry.userPhotoUrl!)
                      : const CachedNetworkImageProvider(
                          Constants.placeholderImage),
                ),
              ),
              if (entry.isVerified)
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: entry.verifiedTrackRecord?.tier.color ?? Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 10, color: Colors.white),
                ),
            ],
          ),
          const SizedBox(height: 6),

          // Name
          Text(
            entry.userName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),

          // Return Chip
          Text(
            '${isPositive ? "+" : ""}${_percentFormat.format(returnVal / 100)}',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isPositive ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(height: 6),

          // Pedestal Base
          Container(
            height: pedestalHeight,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: medalColor.withValues(alpha: 0.18),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
              border: Border.all(color: medalColor.withValues(alpha: 0.5)),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '#$rank',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: medalColor,
                    ),
                  ),
                  Text(
                    '${entry.reputation.score} pts',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Individual Leaderboard Card
  Widget _buildLeaderboardCard(BuildContext context, TopPortfolioEntry entry) {
    final theme = Theme.of(context);
    final returnVal = entry.returnForPeriod(_selectedPeriod);
    final isPositive = returnVal >= 0;
    final rank = entry.rank ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 5.0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _navigateToProfile(entry.userId),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Rank, Avatar, Trader Name, Reputation Badge, and Return
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Rank Indicator
                  Container(
                    width: 32,
                    alignment: Alignment.center,
                    child: _buildRankBadge(context, rank),
                  ),
                  const SizedBox(width: 8),

                  // Avatar
                  Hero(
                    tag: 'user_${entry.userId}',
                    child: CircleAvatar(
                      radius: 20,
                      backgroundImage: entry.userPhotoUrl != null
                          ? CachedNetworkImageProvider(entry.userPhotoUrl!)
                          : const CachedNetworkImageProvider(
                              Constants.placeholderImage),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Name and Reputation Tier
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                entry.userName,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (entry.isVerified) ...[
                              const SizedBox(width: 4),
                              Icon(
                                entry.verifiedTrackRecord?.tier.icon ??
                                    Icons.verified,
                                size: 16,
                                color: entry.verifiedTrackRecord?.tier.color ??
                                    Colors.blue,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            // Reputation Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: entry.reputation.tier.color
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(entry.reputation.tier.icon,
                                      size: 11,
                                      color: entry.reputation.tier.color),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${entry.reputation.tier.label} (${entry.reputation.score})',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: entry.reputation.tier.color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (entry.location != null &&
                                entry.location!.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  entry.location!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.outline,
                                    fontSize: 11,
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

                  // Return % Highlight
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${isPositive ? "+" : ""}${_percentFormat.format(returnVal / 100)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: isPositive ? Colors.green : Colors.red,
                        ),
                      ),
                      Text(
                        _selectedPeriod.label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.outline,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Row 2: Performance Mini Chips
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _buildMetricBadge(
                    context,
                    label: 'Win Rate',
                    value: '${entry.winRate.toStringAsFixed(1)}%',
                    icon: Icons.check_circle_outline,
                  ),
                  if (entry.sharpeRatio > 0)
                    _buildMetricBadge(
                      context,
                      label: 'Sharpe',
                      value: entry.sharpeRatio.toStringAsFixed(2),
                      icon: Icons.insights,
                    ),
                  if (entry.maxDrawdownPercent > 0)
                    _buildMetricBadge(
                      context,
                      label: 'Max DD',
                      value: '-${entry.maxDrawdownPercent.toStringAsFixed(1)}%',
                      icon: Icons.arrow_downward,
                    ),
                  _buildMetricBadge(
                    context,
                    label: 'Trades',
                    value: entry.totalTrades.toString(),
                    icon: Icons.history,
                  ),
                  _buildMetricBadge(
                    context,
                    label: 'Followers',
                    value: _compactNumberFormat.format(entry.followersCount),
                    icon: Icons.people_outline,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Row 3: Follow/Unfollow and Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Verification Source Note
                  if (entry.isVerified)
                    Flexible(
                      child: Row(
                        children: [
                          Icon(Icons.shield_rounded,
                              size: 12,
                              color: entry.verifiedTrackRecord?.tier.color ??
                                  Colors.blue),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Audited via ${entry.verifiedTrackRecord?.verificationSource ?? "Brokerage"}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 10,
                                color: theme.colorScheme.outline,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const Spacer(),

                  // Follow/Unfollow Action Button
                  _buildFollowActionButton(context, entry),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Rank Badge
  Widget _buildRankBadge(BuildContext context, int rank) {
    if (rank == 1) {
      return Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: Color(0xFFFFD700),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Text('1',
              style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w900,
                  fontSize: 12)),
        ),
      );
    }
    if (rank == 2) {
      return Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: Color(0xFFC0C0C0),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Text('2',
              style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w900,
                  fontSize: 12)),
        ),
      );
    }
    if (rank == 3) {
      return Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: Color(0xFFCD7F32),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Text('3',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12)),
        ),
      );
    }

    return Text(
      '#$rank',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.outline,
          ),
    );
  }

  /// Mini Metric Badge
  Widget _buildMetricBadge(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: theme.colorScheme.outline),
          const SizedBox(width: 3),
          Text(
            '$label: ',
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color: theme.colorScheme.outline,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Follow/Unfollow Button with Real-time Stream
  Widget _buildFollowActionButton(
      BuildContext context, TopPortfolioEntry entry) {
    final currentUserId = widget.auth.currentUser?.uid;
    if (currentUserId == null || currentUserId == entry.userId) {
      if (currentUserId == entry.userId) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'You',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    return StreamBuilder<bool>(
      stream: widget.firestoreService.isFollowingStream(
        currentUserId,
        entry.userId,
      ),
      builder: (context, snapshot) {
        final isFollowing = snapshot.data ?? false;

        return SizedBox(
          height: 28,
          child: isFollowing
              ? OutlinedButton.icon(
                  onPressed: () => _toggleFollow(entry, isFollowing),
                  icon: const Icon(Icons.check, size: 13),
                  label:
                      const Text('Following', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                )
              : FilledButton.tonalIcon(
                  onPressed: () => _toggleFollow(entry, isFollowing),
                  icon: const Icon(Icons.person_add, size: 13),
                  label: const Text('Follow', style: TextStyle(fontSize: 11)),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
        );
      },
    );
  }

  Future<void> _toggleFollow(
      TopPortfolioEntry entry, bool currentlyFollowing) async {
    final currentUserId = widget.auth.currentUser?.uid;
    if (currentUserId == null) return;

    final currentUserName = widget.auth.currentUser?.displayName ?? 'Anonymous';
    final currentUserPhoto = widget.auth.currentUser?.photoURL;

    try {
      if (currentlyFollowing) {
        await widget.firestoreService.unfollowUser(currentUserId, entry.userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unfollowed ${entry.userName}'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        await widget.firestoreService.followUser(
          currentUserId: currentUserId,
          currentUserName: currentUserName,
          currentUserPhotoUrl: currentUserPhoto,
          targetUserId: entry.userId,
          targetUserName: entry.userName,
          targetUserPhotoUrl: entry.userPhotoUrl,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Now following ${entry.userName}'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _navigateToProfile(String targetUserId) {
    widget.analytics.logEvent(
      name: 'view_trader_from_leaderboard',
      parameters: {'target_user_id': targetUserId},
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TraderProfileWidget(
          auth: widget.auth,
          userId: targetUserId,
          analytics: widget.analytics,
          observer: widget.observer,
          brokerageUser: widget.brokerageUser,
          service: widget.service,
        ),
      ),
    );
  }

  /// Reputation System Explainer Bottom Sheet
  void _showReputationInfoSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.military_tech_rounded,
                          color: Colors.amber, size: 28),
                      const SizedBox(width: 10),
                      Text(
                        'User Reputation System',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'RealizeAlpha calculates an objective 0–100 credibility score for each trader based on verified brokerage data and community standing.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Scoring Breakdown Table
                  Text(
                    'Score Breakdown (100 Points Total)',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildScoreBreakdownItem(
                    context,
                    title: 'Brokerage Verification (35 pts)',
                    desc:
                        'Audited trade ledger authentication directly from brokerages (Master Trader = 35, Top Performer = 28, Verified Leader = 20, Verified Trader = 15).',
                    icon: Icons.verified_user_rounded,
                    color: Colors.blue,
                  ),
                  _buildScoreBreakdownItem(
                    context,
                    title: 'Win Rate Consistency (25 pts)',
                    desc:
                        'Historical percentage of profitable closed trades (scaled proportionally up to 25 points).',
                    icon: Icons.check_circle_outline,
                    color: Colors.green,
                  ),
                  _buildScoreBreakdownItem(
                    context,
                    title: 'Cumulative Return & P&L (20 pts)',
                    desc:
                        'Audited percentage return on invested capital across trading cycles.',
                    icon: Icons.trending_up_rounded,
                    color: Colors.teal,
                  ),
                  _buildScoreBreakdownItem(
                    context,
                    title: 'Trading Activity & Longevity (10 pts)',
                    desc:
                        'Total trade count and execution history over time (100+ trades = 10 pts).',
                    icon: Icons.history_rounded,
                    color: Colors.orange,
                  ),
                  _buildScoreBreakdownItem(
                    context,
                    title: 'Community Trust & Followers (10 pts)',
                    desc:
                        'Number of active platform traders following and copying trades.',
                    icon: Icons.people_outline,
                    color: Colors.purple,
                  ),
                  const SizedBox(height: 20),

                  // Tiers Table
                  Text(
                    'Reputation Tiers',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...ReputationTier.values.reversed.map((tier) {
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(tier.icon, color: tier.color, size: 24),
                      title: Text(tier.label,
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: tier.color)),
                      subtitle: Text(_getTierDescription(tier)),
                    );
                  }),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildScoreBreakdownItem(
    BuildContext context, {
    required String title,
    required String desc,
    required IconData icon,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTierDescription(ReputationTier tier) {
    switch (tier) {
      case ReputationTier.masterTrader:
        return 'Score 90–100: Elite audited track record, high win rate & significant community trust.';
      case ReputationTier.eliteTrader:
        return 'Score 75–89: Proven multi-month performance with verified metrics.';
      case ReputationTier.trustedTrader:
        return 'Score 50–74: Consistent profitable executions and positive track record.';
      case ReputationTier.activeTrader:
        return 'Score 25–49: Active trading record with emerging consistency.';
      case ReputationTier.novice:
        return 'Score 0–24: New or building trader profile.';
    }
  }

  /// Filter Dialog (Verified Only)
  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        bool localVerified = _verifiedOnly;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Filter Leaderboard'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: const Text('Verified Only'),
                    subtitle: const Text(
                        'Only show traders with broker-audited track records'),
                    value: localVerified,
                    onChanged: (val) {
                      setDialogState(() => localVerified = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _verifiedOnly = localVerified;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
