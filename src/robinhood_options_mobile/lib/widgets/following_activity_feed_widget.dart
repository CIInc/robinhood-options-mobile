import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/group_activity.dart';
import 'package:robinhood_options_mobile/model/user_follow.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/copy_trade_button_widget.dart';
import 'package:robinhood_options_mobile/widgets/trader_profile_widget.dart';

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
    extends State<FollowingActivityFeedWidget> {
  String _selectedFilter = 'all'; // 'all', 'equity', 'option', 'buy', 'sell'

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = widget.auth.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Following Feed')),
        body: const Center(
          child: Text('Sign in to view your following feed.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Following Activity'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Feed',
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(theme),
          Expanded(
            child: StreamBuilder<List<UserFollow>>(
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
                if (follows.isEmpty) {
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
                            'Follow top traders from the Community or Groups to see their trades and copy strategies.',
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

                final followedUserIds =
                    follows.map((f) => f.followingId).toList();

                return StreamBuilder<List<GroupActivity>>(
                  stream: widget.firestoreService
                      .getFollowedUsersActivitiesStream(followedUserIds),
                  builder: (context, activitySnapshot) {
                    if (activitySnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (activitySnapshot.hasError) {
                      return Center(
                        child: Text(
                            'Failed to load activities: ${activitySnapshot.error}'),
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
                                Icons.dynamic_feed_outlined,
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
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final activity = filtered[index];
                        return _buildActivityCard(context, activity, theme);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(ThemeData theme) {
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
                    onTap: () => _openUserProfile(context, activity.userId, activity.displayUserName),
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
                          onTap: () => _openUserProfile(context, activity.userId, activity.displayUserName),
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

  Future<void> _copyTrade(BuildContext context, GroupActivity activity) async {
    if (widget.brokerageUser == null || widget.service == null) return;
    await showCopyTradeDialog(
      context: context,
      brokerageService: widget.service!,
      currentUser: widget.brokerageUser!,
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
