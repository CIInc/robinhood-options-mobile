import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/investor_group.dart';
import 'package:robinhood_options_mobile/model/group_performance_analytics_provider.dart';
import 'package:robinhood_options_mobile/model/group_performance_analytics.dart';
import 'package:robinhood_options_mobile/model/group_watchlist_models.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/group_watchlist_service.dart';
import 'package:robinhood_options_mobile/widgets/copy_trade_settings_widget.dart';
import 'package:robinhood_options_mobile/widgets/investor_group_chat_widget.dart';
import 'package:robinhood_options_mobile/widgets/investor_group_manage_members_widget.dart';
import 'package:robinhood_options_mobile/widgets/investor_group_performance_analytics_widget.dart';
import 'package:robinhood_options_mobile/widgets/group_watchlists_widget.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

class InvestorGroupDetailWidget extends StatefulWidget {
  final String groupId;
  final FirestoreService firestoreService;
  final BrokerageUser? brokerageUser;
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
  int _unreadMessagesCount = 0;
  final GlobalKey _shareButtonKey = GlobalKey();

  // Theme-aware color helpers
  bool get _isDarkTheme => Theme.of(context).brightness == Brightness.dark;

  Color _getCardBorderColor() =>
      _isDarkTheme ? Colors.grey[700]! : Colors.grey[200]!;

  Color _getSecondaryTextColor() =>
      _isDarkTheme ? Colors.grey[400]! : Colors.grey[600]!;

  Color _getTertiaryTextColor() =>
      _isDarkTheme ? Colors.grey[500]! : Colors.grey[500]!;

  Color _getBackgroundColor() =>
      _isDarkTheme ? Colors.grey[900]! : Colors.grey[50]!;

  Color _getBadgeBackground(Color lightColor) {
    if (_isDarkTheme) {
      return lightColor.withOpacity(0.3);
    }
    return lightColor.withOpacity(0.15);
  }

  @override
  void initState() {
    super.initState();
    _trackScreenView();
    _listenToUnreadMessages();
  }

  void _trackScreenView() {
    widget.analytics.logScreenView(
      screenName: 'InvestorGroupDetail',
      screenClass: 'InvestorGroupDetailWidget',
    );
  }

  void _listenToUnreadMessages() {
    if (auth.currentUser != null) {
      widget.firestoreService
          .getGroupMessages(widget.groupId)
          .listen((snapshot) {
        int unread = 0;
        for (var doc in snapshot.docs) {
          final message = doc.data();
          if (message.senderId != auth.currentUser!.uid &&
              !message.readBy.containsKey(auth.currentUser!.uid)) {
            unread++;
          }
        }
        if (mounted) {
          setState(() => _unreadMessagesCount = unread);
        }
      });
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Loading...')),
            body: _buildLoadingSkeleton(),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: _buildErrorState(snapshot.error),
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
              IconButton(
                key: _shareButtonKey,
                icon: const Icon(Icons.share),
                tooltip: 'Share Group',
                onPressed: () => _shareGroup(context, group),
              ),
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
                    HapticFeedback.mediumImpact();
                    if (value == 'manage_members') {
                      _trackEvent('manage_members_pressed');
                      _showManageMembersScreen(context, group);
                    } else if (value == 'edit') {
                      _trackEvent('edit_group_pressed');
                      _showEditGroupDialog(context, group);
                    } else if (value == 'delete') {
                      _trackEvent('delete_group_pressed');
                      _showDeleteConfirmDialog(context, group);
                    }
                  },
                ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => _handleRefresh(group),
            child: _buildCardHubLayout(group, isAdmin, isMember),
          ),
        );
      },
    );
  }

  Widget _buildCardHubLayout(InvestorGroup group, bool isAdmin, bool isMember) {
    return ChangeNotifierProvider(
      create: (_) {
        final provider =
            GroupPerformanceAnalyticsProvider(widget.firestoreService);
        // Load analytics with default period
        WidgetsBinding.instance.addPostFrameCallback((_) {
          provider.loadGroupPerformanceAnalytics(
              group.id, TimePeriodFilter.oneMonth);
        });
        return provider;
      },
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Group Header
              _buildGroupHeader(group, isMember),
              const SizedBox(height: 28),

              // Cards Grid
              _buildOverviewCard(group, isMember),
              const SizedBox(height: 16),
              _buildPerformanceCard(group),
              const SizedBox(height: 16),
              _buildWatchlistsCard(group, isMember),
              const SizedBox(height: 16),
              _buildChatCard(group, isMember),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupHeader(InvestorGroup group, bool isMember) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context)
                .primaryColor
                .withOpacity(_isDarkTheme ? 0.15 : 0.1),
            Theme.of(context)
                .primaryColor
                .withOpacity(_isDarkTheme ? 0.05 : 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).primaryColor,
                      Theme.of(context).primaryColor.withOpacity(0.7),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context)
                          .primaryColor
                          .withOpacity(_isDarkTheme ? 0.2 : 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.transparent,
                  child: Text(
                    group.name.isNotEmpty ? group.name[0].toUpperCase() : 'G',
                    style: const TextStyle(
                        fontSize: 28,
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getBadgeBackground(Colors.orange),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                group.isPrivate ? Icons.lock : Icons.public,
                                size: 14,
                                color: group.isPrivate
                                    ? Colors.orange[_isDarkTheme ? 400 : 700]
                                    : Colors.green[_isDarkTheme ? 400 : 700],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                group.isPrivate ? 'Private' : 'Public',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: group.isPrivate
                                      ? Colors.orange[_isDarkTheme ? 400 : 700]
                                      : Colors.green[_isDarkTheme ? 400 : 700],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getBadgeBackground(Colors.blue),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.people,
                                  size: 14,
                                  color: Colors.blue[_isDarkTheme ? 400 : 700]),
                              const SizedBox(width: 4),
                              Text(
                                '${group.members.length} member${group.members.length != 1 ? 's' : ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue[_isDarkTheme ? 400 : 700],
                                ),
                              ),
                            ],
                          ),
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
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: _getSecondaryTextColor(),
                  ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Created ${DateFormat.yMMMd().format(group.dateCreated)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _getTertiaryTextColor(),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(InvestorGroup group, bool isMember) {
    return Card(
      elevation: 0,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _getCardBorderColor(), width: 1),
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          _trackEvent('overview_card_tapped');
          _navigateToMembers(group);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .primaryColor
                          .withOpacity(_isDarkTheme ? 0.15 : 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.info_outline,
                        color: Theme.of(context).primaryColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Overview',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  Badge(
                    label: Text('${group.members.length}',
                        style: const TextStyle(color: Colors.white)),
                    backgroundColor: Theme.of(context).primaryColor,
                    child: const Icon(Icons.people, color: Colors.transparent),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward_ios,
                      size: 16, color: _getTertiaryTextColor()),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getBadgeBackground(
                    group.isPrivate ? Colors.orange : Colors.green,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      group.isPrivate ? Icons.lock : Icons.public,
                      size: 18,
                      color: group.isPrivate
                          ? Colors.orange[_isDarkTheme ? 400 : 700]
                          : Colors.green[_isDarkTheme ? 400 : 700],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      group.isPrivate ? 'Private Group' : 'Public Group',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: group.isPrivate
                                ? Colors.orange[_isDarkTheme ? 400 : 900]
                                : Colors.green[_isDarkTheme ? 400 : 900],
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Created ${_formatRelativeDate(group.dateCreated)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _getTertiaryTextColor(),
                    ),
              ),
              const SizedBox(height: 16),
              if (auth.currentUser != null) ...[
                if (isMember) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () {
                              HapticFeedback.mediumImpact();
                              _trackEvent('copy_trade_settings_pressed');
                              _showCopyTradeSettings(context, group);
                            },
                      icon: const Icon(Icons.content_copy, size: 18),
                      label: const Text('Copy Trade Settings'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () {
                              HapticFeedback.heavyImpact();
                              _trackEvent('leave_group_pressed');
                              _leaveGroup(context, group);
                            },
                      icon: const Icon(Icons.exit_to_app, size: 18),
                      label: const Text('Leave Group'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[_isDarkTheme ? 600 : 500],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ] else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () {
                              HapticFeedback.mediumImpact();
                              _trackEvent('join_group_pressed');
                              _joinGroup(context, group);
                            },
                      icon: const Icon(Icons.group_add, size: 18),
                      label: const Text('Join Group'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPerformanceCard(InvestorGroup group) {
    return Card(
      elevation: 0,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _getCardBorderColor(), width: 1),
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          _trackEvent('performance_card_tapped');
          _navigateToPerformance(group);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          Colors.green.withOpacity(_isDarkTheme ? 0.15 : 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.trending_up,
                        color: Colors.green, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Performance Analytics',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios,
                      size: 16, color: _getTertiaryTextColor()),
                ],
              ),
              const SizedBox(height: 16),
              Consumer<GroupPerformanceAnalyticsProvider>(
                builder: (context, provider, _) {
                  if (provider.groupMetrics != null) {
                    final metrics = provider.groupMetrics!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildMetricBox(
                              label: 'Avg Return',
                              value:
                                  '${metrics.groupAverageReturnPercent.toStringAsFixed(2)}%',
                              valueColor: metrics.groupAverageReturnPercent >= 0
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            _buildMetricBox(
                              label: 'Win Rate',
                              value:
                                  '${metrics.groupWinRate.toStringAsFixed(1)}%',
                              valueColor: Colors.blue,
                            ),
                          ],
                        ),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'View group performance metrics, rankings, and charts',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: _getSecondaryTextColor(),
                            ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => _navigateToPerformance(group),
                          child: const Text('View Details →'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricBox({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _getBackgroundColor(),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _getCardBorderColor(), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _getTertiaryTextColor(),
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: valueColor,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWatchlistsCard(InvestorGroup group, bool isMember) {
    if (!isMember) {
      return Card(
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _getCardBorderColor(), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(_isDarkTheme ? 0.15 : 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.bookmark_outline,
                        color: _getTertiaryTextColor(), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Group Watchlists',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Chip(
                      label: const Text('Members Only',
                          style: TextStyle(fontSize: 12)),
                      backgroundColor:
                          Colors.grey.withOpacity(_isDarkTheme ? 0.2 : 0.1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Create and manage collaborative watchlists with group members',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _getSecondaryTextColor(),
                    ),
              ),
            ],
          ),
        ),
      );
    }

    final watchlistService = GroupWatchlistService();
    return Card(
      elevation: 0,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _getCardBorderColor(), width: 1),
      ),
      child: InkWell(
        onTap: widget.brokerageUser != null
            ? () {
                HapticFeedback.lightImpact();
                _trackEvent('watchlists_card_tapped');
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => GroupWatchlistsWidget(
                      brokerageUser: widget.brokerageUser!,
                      groupId: widget.groupId,
                    ),
                  ),
                );
              }
            : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: StreamBuilder<List<GroupWatchlist>>(
            stream: watchlistService.getGroupWatchlistsStream(widget.groupId),
            builder: (context, snapshot) {
              final watchlists = snapshot.data ?? [];
              final hasData = watchlists.isNotEmpty;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(_isDarkTheme ? 0.15 : 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.bookmark_outline,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 24),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                'Group Watchlists',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(_isDarkTheme ? 0.2 : 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${watchlists.length}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (hasData)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Show first watchlist preview with symbols
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _getBackgroundColor(),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                watchlists.first.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (watchlists.first.symbols.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: watchlists.first.symbols
                                      .take(5)
                                      .map(
                                        (symbol) => Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withOpacity(0.2),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            symbol.symbol,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                                if (watchlists.first.symbols.length > 5)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      '+${watchlists.first.symbols.length - 5} more',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: _getSecondaryTextColor(),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  Text(
                    hasData
                        ? 'Tap to view all watchlists'
                        : 'Create and manage collaborative watchlists with group members',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _getSecondaryTextColor(),
                        ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildChatCard(InvestorGroup group, bool isMember) {
    return Card(
      elevation: 0,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _getCardBorderColor(), width: 1),
      ),
      child: InkWell(
        onTap: isMember
            ? () {
                HapticFeedback.lightImpact();
                _trackEvent('chat_card_tapped');
                _navigateToChat(group);
              }
            : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMember
                          ? Theme.of(context)
                              .primaryColor
                              .withOpacity(_isDarkTheme ? 0.15 : 0.1)
                          : Colors.grey.withOpacity(_isDarkTheme ? 0.15 : 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.chat_bubble_outline,
                        color: isMember
                            ? Theme.of(context).primaryColor
                            : _getTertiaryTextColor(),
                        size: 24),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Group Chat',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  if (isMember && _unreadMessagesCount > 0)
                    Badge(
                      label: Text('$_unreadMessagesCount',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      backgroundColor: Colors.red[_isDarkTheme ? 600 : 500],
                      child: const Icon(Icons.mail, color: Colors.transparent),
                    ),
                  if (isMember && _unreadMessagesCount == 0)
                    const SizedBox(width: 24),
                  if (isMember) const SizedBox(width: 8),
                  if (isMember)
                    Icon(Icons.arrow_forward_ios,
                        size: 16, color: _getTertiaryTextColor()),
                  if (!isMember)
                    Icon(Icons.lock_outline,
                        size: 20, color: _getTertiaryTextColor()),
                ],
              ),
              const SizedBox(height: 16),
              if (isMember)
                StreamBuilder(
                  stream: widget.firestoreService
                      .getGroupMessages(widget.groupId)
                      .map((snapshot) => snapshot.docs.isNotEmpty
                          ? snapshot.docs.first.data()
                          : null),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data != null) {
                      final lastMessage = snapshot.data!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _getBackgroundColor(),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: _getCardBorderColor(), width: 1),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        lastMessage.senderName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  lastMessage.text,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color: _getSecondaryTextColor()),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _formatRelativeDate(lastMessage.timestamp),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: _getTertiaryTextColor(),
                                      fontSize: 11,
                                    ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => _navigateToChat(group),
                              child: const Text('Open Chat →'),
                            ),
                          ),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _getBackgroundColor(),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: _getCardBorderColor(), width: 1),
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.chat_bubble_outline,
                                    size: 32, color: _getTertiaryTextColor()),
                                const SizedBox(height: 8),
                                Text(
                                  'No messages yet',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: _getSecondaryTextColor(),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => _navigateToChat(group),
                            child: const Text('Start Chat →'),
                          ),
                        ),
                      ],
                    );
                  },
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _getBadgeBackground(Colors.orange),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.orange[_isDarkTheme ? 400 : 200]!,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lock,
                            color: Colors.orange[_isDarkTheme ? 400 : 700],
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Join the group to chat with members',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color:
                                        Colors.orange[_isDarkTheme ? 400 : 900],
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () => _joinGroup(context, group),
                        icon: const Icon(Icons.group_add, size: 18),
                        label: const Text('Join Group'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
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

  void _navigateToMembers(InvestorGroup group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Members'),
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {
                  showSearch(
                    context: context,
                    delegate: _MemberSearchDelegate(
                      group: group,
                      firestoreService: widget.firestoreService,
                    ),
                  );
                },
              ),
            ],
          ),
          body: _buildMembersListView(group),
        ),
      ),
    );
  }

  Widget _buildMembersListView(InvestorGroup group) {
    if (group.members.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _getBackgroundColor(),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.people_outline,
                  size: 56, color: _getTertiaryTextColor()),
            ),
            const SizedBox(height: 20),
            Text(
              'No members yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Invite people to join this group',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _getSecondaryTextColor(),
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: group.members.length,
      itemBuilder: (context, index) {
        final userId = group.members[index];
        final isCreator = userId == group.createdBy;
        final isAdmin = group.isAdmin(userId);

        return FutureBuilder(
          future: widget.firestoreService.userCollection.doc(userId).get(),
          builder: (context, snapshot) {
            String displayName = 'User';
            Widget avatar = CircleAvatar(
              radius: 24,
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
              child: Icon(Icons.account_circle,
                  color: Theme.of(context).primaryColor),
            );

            if (snapshot.hasData && snapshot.data!.exists) {
              final user = snapshot.data!.data();
              displayName = user?.name ?? 'Guest';
              avatar = CircleAvatar(
                radius: 24,
                backgroundColor: Theme.of(context).primaryColor,
                child: Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              );
            }

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                leading: avatar,
                title: Text(
                  displayName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isCreator)
                      Chip(
                        label: const Text('Creator',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600)),
                        backgroundColor: Colors.amber[_isDarkTheme ? 700 : 100],
                        labelStyle: TextStyle(
                            color: Colors.amber[_isDarkTheme ? 100 : 900]),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                      )
                    else if (isAdmin)
                      Chip(
                        label: const Text('Admin',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600)),
                        backgroundColor: Colors.blue[_isDarkTheme ? 700 : 100],
                        labelStyle: TextStyle(
                            color: Colors.blue[_isDarkTheme ? 100 : 900]),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                      ),
                    if (group.isPrivate) const SizedBox(width: 8),
                    if (group.isPrivate)
                      const Icon(Icons.chevron_right, size: 20),
                  ],
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: _getCardBorderColor(), width: 1),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _navigateToPerformance(InvestorGroup group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider(
          create: (_) =>
              GroupPerformanceAnalyticsProvider(widget.firestoreService),
          child: GroupPerformanceAnalyticsWidget(group: group),
        ),
      ),
    );
  }

  void _navigateToChat(InvestorGroup group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Group Chat'),
          ),
          body: InvestorGroupChatWidget(
            group: group,
            firestoreService: widget.firestoreService,
            analytics: widget.analytics,
            observer: widget.observer,
          ),
        ),
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

  void _showCopyTradeSettings(BuildContext context, InvestorGroup group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CopyTradeSettingsWidget(
          group: group,
          firestoreService: widget.firestoreService,
        ),
      ),
    );
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

  Widget _buildLoadingSkeleton() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Header skeleton
            _buildSkeletonCard(height: 180),
            const SizedBox(height: 24),
            // Cards skeleton
            _buildSkeletonCard(height: 280),
            const SizedBox(height: 12),
            _buildSkeletonCard(height: 200),
            const SizedBox(height: 12),
            _buildSkeletonCard(height: 240),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonCard({required double height}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      child: Container(
        height: height,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 140,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 100,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 200,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red[_isDarkTheme ? 900 : 50],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline,
                  size: 64, color: Colors.red[_isDarkTheme ? 400 : 400]),
            ),
            const SizedBox(height: 24),
            Text(
              'Unable to Load Group',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              error?.toString() ?? 'Unknown error occurred',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _getSecondaryTextColor(),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Go Back'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleRefresh(InvestorGroup group) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _trackEvent('group_refreshed');
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _shareGroup(BuildContext context, InvestorGroup group) async {
    _trackEvent('share_group_pressed');
    HapticFeedback.mediumImpact();

    final url = 'https://realizealpha.web.app/investors?groupId=${group.id}';

    final shareText = group.isPrivate
        ? 'Join my private investor group "${group.name}" in RealizeAlpha! $url'
        : 'Check out the investor group "${group.name}" in RealizeAlpha! $url';

    try {
      // Get the share button position for iOS popover
      final RenderBox? renderBox =
          _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;

      Rect? sharePositionOrigin;
      if (renderBox != null &&
          renderBox.size.width > 0 &&
          renderBox.size.height > 0) {
        final size = renderBox.size;
        final offset = renderBox.localToGlobal(Offset.zero);
        sharePositionOrigin = Rect.fromLTWH(
          offset.dx,
          offset.dy,
          size.width,
          size.height,
        );
      }

      await Share.share(
        shareText,
        subject: 'Investor Group Invitation',
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e) {
      // Silently handle user cancellation, only show error for actual failures
      if (e.toString().isNotEmpty && !e.toString().contains('cancelled')) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Unable to share group'),
              action: SnackBarAction(
                label: 'Dismiss',
                onPressed: () =>
                    ScaffoldMessenger.of(context).hideCurrentSnackBar(),
              ),
            ),
          );
        }
      }
    }
  }

  void _trackEvent(String eventName) {
    widget.analytics.logEvent(
      name: eventName,
      parameters: {
        'group_id': widget.groupId,
      },
    );
  }

  String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks week${weeks > 1 ? "s" : ""} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months > 1 ? "s" : ""} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years year${years > 1 ? "s" : ""} ago';
    }
  }
}

// Member search delegate
class _MemberSearchDelegate extends SearchDelegate<String> {
  final InvestorGroup group;
  final FirestoreService firestoreService;

  _MemberSearchDelegate({
    required this.group,
    required this.firestoreService,
  });

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    final filteredMembers = group.members.where((userId) {
      // This is a simple filter, in a real app you'd fetch user data
      return true;
    }).toList();

    if (filteredMembers.isEmpty) {
      return const Center(
        child: Text('No members found'),
      );
    }

    return ListView.builder(
      itemCount: filteredMembers.length,
      itemBuilder: (context, index) {
        final userId = filteredMembers[index];
        final isCreator = userId == group.createdBy;
        final isAdmin = group.isAdmin(userId);

        return FutureBuilder(
          future: firestoreService.userCollection.doc(userId).get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const ListTile(
                leading: CircularProgressIndicator(),
                title: Text('Loading...'),
              );
            }

            String displayName = 'User';
            if (snapshot.data!.exists) {
              final user = snapshot.data!.data();
              displayName = user?.name ?? 'Guest';
            }

            // Filter by name
            if (query.isNotEmpty &&
                !displayName.toLowerCase().contains(query.toLowerCase())) {
              return const SizedBox.shrink();
            }

            return ListTile(
              leading: CircleAvatar(
                child: Text(displayName.isNotEmpty
                    ? displayName[0].toUpperCase()
                    : 'U'),
              ),
              title: Text(displayName),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isCreator)
                    const Chip(
                      label: Text('Creator', style: TextStyle(fontSize: 11)),
                    )
                  else if (isAdmin)
                    const Chip(
                      label: Text('Admin', style: TextStyle(fontSize: 11)),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
