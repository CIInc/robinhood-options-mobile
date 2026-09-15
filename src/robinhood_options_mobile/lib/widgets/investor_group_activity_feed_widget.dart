import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/group_activity.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_order.dart';
import 'package:robinhood_options_mobile/model/instrument_order_store.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/investor_group.dart';
import 'package:robinhood_options_mobile/model/option_order.dart';
import 'package:robinhood_options_mobile/model/option_order_store.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';

class InvestorGroupActivityFeedWidget extends StatefulWidget {
  final String groupId;
  final InvestorGroup group;
  final FirestoreService firestoreService;
  final IBrokerageService? service;
  final BrokerageUser? brokerageUser;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;

  const InvestorGroupActivityFeedWidget({
    super.key,
    required this.groupId,
    required this.group,
    required this.firestoreService,
    this.service,
    this.brokerageUser,
    required this.analytics,
    required this.observer,
  });

  @override
  State<InvestorGroupActivityFeedWidget> createState() =>
      _InvestorGroupActivityFeedWidgetState();
}

class _InvestorGroupActivityFeedWidgetState
    extends State<InvestorGroupActivityFeedWidget> {
  String? _selectedMemberId;
  GroupActivityType? _selectedType;
  GroupActivityPrivacySettings _privacySettings =
      const GroupActivityPrivacySettings();

  bool get _isDarkTheme => Theme.of(context).brightness == Brightness.dark;

  Color _getCardBorderColor() =>
      _isDarkTheme ? Colors.grey[700]! : Colors.grey[200]!;

  Color _getSecondaryTextColor() =>
      _isDarkTheme ? Colors.grey[400]! : Colors.grey[600]!;

  Color _getBackgroundColor() =>
      _isDarkTheme ? Colors.grey[900]! : Colors.grey[50]!;

  @override
  void initState() {
    super.initState();
    _trackScreenView();
    _loadPrivacySettings();
  }

  void _trackScreenView() {
    widget.analytics.logScreenView(
      screenName: 'InvestorGroupActivityFeed',
      screenClass: 'InvestorGroupActivityFeedWidget',
    );
  }

  Future<void> _loadPrivacySettings() async {
    final currentUid = auth.currentUser?.uid;
    if (currentUid == null) return;
    try {
      final settings = await widget.firestoreService
          .getUserGroupPrivacySettings(widget.groupId, currentUid);
      if (mounted) {
        setState(() {
          _privacySettings = settings;
        });
      }
    } catch (e) {
      debugPrint('Failed to load privacy settings: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Feed'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share Recent Trades',
            onPressed: () => _showShareRecentTradesSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.privacy_tip_outlined),
            tooltip: 'Privacy Controls',
            onPressed: () => _showPrivacySettingsDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<GroupActivity>>(
              stream: widget.firestoreService.getGroupActivitiesStream(
                widget.groupId,
                memberId: _selectedMemberId,
                type: _selectedType,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingSkeleton();
                }

                if (snapshot.hasError) {
                  return _buildErrorState(snapshot.error);
                }

                final activities = snapshot.data ?? [];
                if (activities.isEmpty) {
                  return _buildEmptyState();
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    HapticFeedback.lightImpact();
                    await Future.delayed(const Duration(milliseconds: 300));
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: activities.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return _buildActivityTile(activities[index]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: _getBackgroundColor(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // All types filter chip
            FilterChip(
              label: const Text('All'),
              selected: _selectedType == null,
              onSelected: (selected) {
                if (selected) {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedType = null);
                }
              },
            ),
            const SizedBox(width: 8),
            // Trades filter chip
            FilterChip(
              avatar: const Icon(Icons.show_chart, size: 16),
              label: const Text('Trades'),
              selected: _selectedType == GroupActivityType.trade,
              onSelected: (selected) {
                HapticFeedback.selectionClick();
                setState(() =>
                    _selectedType = selected ? GroupActivityType.trade : null);
              },
            ),
            const SizedBox(width: 8),
            // Watchlists filter chip
            FilterChip(
              avatar: const Icon(Icons.bookmark_outline, size: 16),
              label: const Text('Watchlists'),
              selected: _selectedType == GroupActivityType.watchlistUpdated,
              onSelected: (selected) {
                HapticFeedback.selectionClick();
                setState(() => _selectedType =
                    selected ? GroupActivityType.watchlistUpdated : null);
              },
            ),
            const SizedBox(width: 8),
            // Members filter chip
            FilterChip(
              avatar: const Icon(Icons.people_outline, size: 16),
              label: const Text('Members'),
              selected: _selectedType == GroupActivityType.memberJoined ||
                  _selectedType == GroupActivityType.memberLeft,
              onSelected: (selected) {
                HapticFeedback.selectionClick();
                setState(() => _selectedType =
                    selected ? GroupActivityType.memberJoined : null);
              },
            ),
            const SizedBox(width: 12),
            Container(height: 24, width: 1, color: _getCardBorderColor()),
            const SizedBox(width: 12),
            // Member selection dropdown
            DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _selectedMemberId,
                hint: const Text('All Members', style: TextStyle(fontSize: 13)),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All Members', style: TextStyle(fontSize: 13)),
                  ),
                  ...widget.group.members.map(
                    (memberId) => DropdownMenuItem<String?>(
                      value: memberId,
                      child: Text(
                        memberId == auth.currentUser?.uid
                            ? 'My Activity'
                            : 'Member (${memberId.length > 6 ? memberId.substring(0, 6) : memberId})',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ],
                onChanged: (val) {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedMemberId = val);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityTile(GroupActivity activity) {
    final theme = Theme.of(context);
    final isBuy = activity.isBuy;
    final isSell = activity.isSell;

    Color badgeColor;
    IconData badgeIcon;

    switch (activity.type) {
      case GroupActivityType.trade:
      case GroupActivityType.order:
        if (isBuy) {
          badgeColor = Colors.green;
          badgeIcon = Icons.arrow_upward;
        } else if (isSell) {
          badgeColor = Colors.red;
          badgeIcon = Icons.arrow_downward;
        } else {
          badgeColor = Colors.blue;
          badgeIcon = Icons.swap_horiz;
        }
        break;
      case GroupActivityType.memberJoined:
        badgeColor = Colors.teal;
        badgeIcon = Icons.person_add;
        break;
      case GroupActivityType.memberLeft:
        badgeColor = Colors.grey;
        badgeIcon = Icons.person_remove;
        break;
      case GroupActivityType.watchlistUpdated:
        badgeColor = Colors.indigo;
        badgeIcon = Icons.bookmark;
        break;
      case GroupActivityType.milestone:
        badgeColor = Colors.amber;
        badgeIcon = Icons.emoji_events;
        break;
    }

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _getCardBorderColor(), width: 1),
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          _showActivityDetailSheet(activity);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar with type indicator
              Stack(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: theme.primaryColor.withValues(alpha: 0.15),
                    backgroundImage:
                        activity.userPhotoUrl != null && !activity.isAnonymous
                            ? NetworkImage(activity.userPhotoUrl!)
                            : null,
                    child: activity.userPhotoUrl == null || activity.isAnonymous
                        ? (activity.isAnonymous
                            ? const Icon(Icons.person_outline, size: 20)
                            : Text(
                                activity.userName.isNotEmpty
                                    ? activity.userName[0].toUpperCase()
                                    : 'M',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.primaryColor,
                                ),
                              ))
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.scaffoldBackgroundColor,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(badgeIcon, size: 10, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // Activity text and metadata
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            activity.displayUserName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatRelativeTime(activity.timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color: _getSecondaryTextColor(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      activity.title,
                      style: TextStyle(
                        fontSize: 13,
                        color: isBuy
                            ? Colors.green[_isDarkTheme ? 300 : 700]
                            : isSell
                                ? Colors.red[_isDarkTheme ? 300 : 700]
                                : null,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (activity.symbol != null || activity.isTrade) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (activity.symbol != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(
                                    alpha: _isDarkTheme ? 0.2 : 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                activity.symbol!,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          if (activity.assetType != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(
                                    alpha: _isDarkTheme ? 0.2 : 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                activity.assetType!.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _getSecondaryTextColor(),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          if (activity.isPending)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(
                                    alpha: _isDarkTheme ? 0.25 : 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                (activity.details?['state'] ?? 'pending')
                                    .toString()
                                    .toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          if (activity.quantity != null)
                            Text(
                              '${activity.formattedQuantity} ${activity.assetType?.toLowerCase() == 'option' ? (activity.quantity == 1 ? 'contract' : 'contracts') : (activity.quantity == 1 ? 'share' : 'shares')}',
                              style: TextStyle(
                                fontSize: 12,
                                color: _getSecondaryTextColor(),
                              ),
                            ),
                          if (activity.price != null && !activity.hideAmounts)
                            Text(
                              '@ \$${activity.price!.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: _getSecondaryTextColor(),
                              ),
                            ),
                          if (activity.formattedTotal.isNotEmpty)
                            Text(
                              '(${activity.formattedTotal})',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isBuy
                                    ? Colors.green
                                    : isSell
                                        ? Colors.red
                                        : _getSecondaryTextColor(),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  void _showActivityDetailSheet(GroupActivity activity) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final formatCurrency = NumberFormat.simpleCurrency();
        final formatDate = DateFormat('MMM d, yyyy · h:mm a');

        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sheet drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Header with Title & Date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      activity.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (activity.symbol != null)
                    Flexible(
                      child: Chip(
                        label: Text(
                          activity.symbol!,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                formatDate.format(activity.timestamp),
                style: TextStyle(fontSize: 12, color: _getSecondaryTextColor()),
              ),
              const Divider(height: 24),
              // Details rows
              _buildDetailRow('Member', activity.displayUserName),
              if (activity.details?['companyName'] != null)
                _buildDetailRow(
                    'Security', activity.details!['companyName'].toString()),
              if (activity.isAnonymous)
                _buildDetailRow('Privacy', 'Posted Anonymously'),
              if (activity.assetType != null)
                _buildDetailRow(
                    'Asset Type', activity.assetType!.toUpperCase()),
              if (activity.side != null)
                _buildDetailRow(
                  'Action',
                  activity.side!.toUpperCase(),
                  valueColor: activity.isBuy
                      ? Colors.green
                      : activity.isSell
                          ? Colors.red
                          : null,
                ),
              if (activity.quantity != null)
                _buildDetailRow('Quantity', activity.formattedQuantity),
              if (activity.price != null)
                _buildDetailRow(
                  'Execution Price',
                  activity.hideAmounts
                      ? r'$***'
                      : formatCurrency.format(activity.price),
                ),
              if (activity.formattedTotal.isNotEmpty)
                _buildDetailRow(
                  'Total Value',
                  activity.formattedTotal,
                  valueColor: activity.isBuy
                      ? Colors.green
                      : activity.isSell
                          ? Colors.red
                          : null,
                ),
              if (activity.orderType != null)
                _buildDetailRow(
                    'Order Type', activity.orderType!.toUpperCase()),
              if (activity.details?['state'] != null || activity.isPending)
                _buildDetailRow(
                  'Order Status',
                  (activity.details?['state']?.toString() ??
                          (activity.isPending ? 'pending' : 'filled'))
                      .toUpperCase(),
                  valueColor: (activity.details?['state'] == 'filled' ||
                          (!activity.isPending &&
                              activity.details?['state'] == null))
                      ? Colors.green
                      : Colors.orange,
                ),
              // Option specific metadata if present
              if (activity.details != null && activity.details!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Option Contract Details',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _getSecondaryTextColor(),
                  ),
                ),
                const SizedBox(height: 6),
                if (activity.details!['strikePrice'] != null)
                  _buildDetailRow(
                    'Strike Price',
                    '\$${activity.details!['strikePrice']}',
                  ),
                if (activity.details!['expirationDate'] != null)
                  _buildDetailRow(
                    'Expiration',
                    activity.details!['expirationDate'].toString(),
                  ),
                if (activity.details!['optionType'] != null)
                  _buildDetailRow(
                    'Type',
                    activity.details!['optionType'].toString().toUpperCase(),
                  ),
              ],
              const SizedBox(height: 20),
              // Action Buttons
              Row(
                children: [
                  if (activity.symbol != null &&
                      widget.service != null &&
                      widget.brokerageUser != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.search, size: 18),
                        label: const Text('View Instrument'),
                        onPressed: () {
                          Navigator.pop(context);
                          _navigateToInstrument(activity.symbol!);
                        },
                      ),
                    ),
                  if (activity.isTrade &&
                      activity.userId != auth.currentUser?.uid) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.content_copy, size: 18),
                        label: const Text('Copy Trade'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _handleCopyTrade(activity);
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: _getSecondaryTextColor()),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  void _showPrivacySettingsDialog(BuildContext context) {
    bool shareTrades = _privacySettings.shareTrades;
    bool showTradeAmounts = _privacySettings.showTradeAmounts;
    bool anonymous = _privacySettings.anonymous;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.shield_outlined),
                  SizedBox(width: 8),
                  Text('Privacy Controls', style: TextStyle(fontSize: 18)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Configure how your trades and actions are shared with "${widget.group.name}".',
                    style: TextStyle(
                      fontSize: 13,
                      color: _getSecondaryTextColor(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Share Trades with Group',
                        style: TextStyle(fontSize: 14)),
                    subtitle: const Text(
                      'Broadcast your executed trades to the group feed',
                      style: TextStyle(fontSize: 11),
                    ),
                    value: shareTrades,
                    onChanged: (val) {
                      HapticFeedback.selectionClick();
                      setDialogState(() => shareTrades = val);
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show Dollar Amounts',
                        style: TextStyle(fontSize: 14)),
                    subtitle: const Text(
                      'When off, prices and totals are masked as \$***',
                      style: TextStyle(fontSize: 11),
                    ),
                    value: showTradeAmounts,
                    onChanged: shareTrades
                        ? (val) {
                            HapticFeedback.selectionClick();
                            setDialogState(() => showTradeAmounts = val);
                          }
                        : null,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Post Anonymously',
                        style: TextStyle(fontSize: 14)),
                    subtitle: const Text(
                      'Hide your name and avatar on group activity items',
                      style: TextStyle(fontSize: 11),
                    ),
                    value: anonymous,
                    onChanged: shareTrades
                        ? (val) {
                            HapticFeedback.selectionClick();
                            setDialogState(() => anonymous = val);
                          }
                        : null,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final currentUid = auth.currentUser?.uid;
                    if (currentUid != null) {
                      final updated = GroupActivityPrivacySettings(
                        shareTrades: shareTrades,
                        showTradeAmounts: showTradeAmounts,
                        anonymous: anonymous,
                      );
                      await widget.firestoreService
                          .updateUserGroupPrivacySettings(
                        widget.groupId,
                        currentUid,
                        updated,
                      );
                      setState(() => _privacySettings = updated);
                    }
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Privacy settings saved'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _navigateToInstrument(String symbol) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected instrument: $symbol'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleCopyTrade(GroupActivity activity) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Copy trade for ${activity.symbol ?? 'order'} prepared. Proceed in Copy Trading tab.',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatRelativeTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(time);
    }
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: _getCardBorderColor(), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey.withValues(alpha: 0.2),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 12,
                        width: 120,
                        color: Colors.grey.withValues(alpha: 0.2),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 10,
                        width: 180,
                        color: Colors.grey.withValues(alpha: 0.15),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showShareRecentTradesSheet(BuildContext context) {
    final currentUid = auth.currentUser?.uid ??
        widget.brokerageUser?.userName ??
        (widget.group.members.isNotEmpty ? widget.group.members.first : null);
    if (currentUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to share trades')),
      );
      return;
    }

    final currentDisplayName = auth.currentUser?.displayName ??
        auth.currentUser?.email?.split('@').first ??
        widget.brokerageUser?.userName ??
        'Member';
    final currentPhotoUrl = auth.currentUser?.photoURL;

    HapticFeedback.lightImpact();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _ShareRecentTradesModal(
          groupId: widget.groupId,
          groupName: widget.group.name,
          currentUid: currentUid,
          currentDisplayName: currentDisplayName,
          currentPhotoUrl: currentPhotoUrl,
          firestoreService: widget.firestoreService,
          service: widget.service,
          brokerageUser: widget.brokerageUser,
          privacySettings: _privacySettings,
          onOpenPrivacySettings: () {
            Navigator.pop(sheetContext);
            _showPrivacySettingsDialog(context);
          },
          onTradesShared: (int count) {
            Navigator.pop(sheetContext);
            if (count > 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Successfully shared $count trade${count == 1 ? '' : 's'} to the feed!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'No trades shared (disabled in privacy or already shared).'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.dynamic_feed_outlined,
                size: 64, color: _getSecondaryTextColor()),
            const SizedBox(height: 16),
            Text(
              'No Activity Yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Member trades, watchlist updates, and group milestones will appear here in real time.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: _getSecondaryTextColor(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.share),
              label: const Text('Share Recent Trades'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              onPressed: () => _showShareRecentTradesSheet(context),
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
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            const Text(
              'Failed to load activity feed',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              error?.toString() ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: _getSecondaryTextColor()),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareRecentTradesModal extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String currentUid;
  final String currentDisplayName;
  final String? currentPhotoUrl;
  final FirestoreService firestoreService;
  final IBrokerageService? service;
  final BrokerageUser? brokerageUser;
  final GroupActivityPrivacySettings privacySettings;
  final VoidCallback onOpenPrivacySettings;
  final ValueChanged<int> onTradesShared;

  const _ShareRecentTradesModal({
    required this.groupId,
    required this.groupName,
    required this.currentUid,
    required this.currentDisplayName,
    this.currentPhotoUrl,
    required this.firestoreService,
    this.service,
    this.brokerageUser,
    required this.privacySettings,
    required this.onOpenPrivacySettings,
    required this.onTradesShared,
  });

  @override
  State<_ShareRecentTradesModal> createState() =>
      _ShareRecentTradesModalState();
}

class _ShareRecentTradesModalState extends State<_ShareRecentTradesModal> {
  bool _isLoading = true;
  bool _isSharing = false;
  List<GroupActivity> _candidateTrades = [];
  final Set<int> _selectedIndices = {};
  bool _isSampleData = false;

  bool get _isDarkTheme => Theme.of(context).brightness == Brightness.dark;
  Color _getSecondaryTextColor() =>
      _isDarkTheme ? Colors.grey[400]! : Colors.grey[600]!;

  @override
  void initState() {
    super.initState();
    _loadRecentTrades();
  }

  Future<void> _loadRecentTrades() async {
    InstrumentStore? instrumentStore;
    try {
      instrumentStore = Provider.of<InstrumentStore>(context, listen: false);
    } catch (_) {}

    final candidates = <GroupActivity>[];
    try {
      bool isOrderIncluded(String state) {
        final s = state.toLowerCase();
        return s == 'filled' ||
            s == 'confirmed' ||
            s == 'queued' ||
            s == 'unconfirmed' ||
            s == 'pending' ||
            s == 'partially_filled';
      }

      List<InstrumentOrder> instOrders = [];
      try {
        final iStore =
            Provider.of<InstrumentOrderStore>(context, listen: false);
        instOrders =
            iStore.items.where((o) => isOrderIncluded(o.state)).toList();
      } catch (_) {}

      List<OptionOrder> optOrders = [];
      try {
        final oStore = Provider.of<OptionOrderStore>(context, listen: false);
        optOrders =
            oStore.items.where((o) => isOrderIncluded(o.state)).toList();
      } catch (_) {}

      if (instOrders.isEmpty && optOrders.isEmpty) {
        try {
          final userDoc =
              widget.firestoreService.userCollection.doc(widget.currentUid);
          final iSnap = await userDoc
              .collection(widget.firestoreService.instrumentOrderCollectionName)
              .orderBy('created_at', descending: true)
              .limit(15)
              .get();
          instOrders = iSnap.docs
              .map((d) => InstrumentOrder.fromJson(d.data()))
              .where((o) => isOrderIncluded(o.state))
              .toList();

          final oSnap = await userDoc
              .collection(widget.firestoreService.optionOrderCollectionName)
              .orderBy('created_at', descending: true)
              .limit(15)
              .get();
          optOrders = oSnap.docs
              .map((d) => OptionOrder.fromJson(d.data()))
              .where((o) => isOrderIncluded(o.state))
              .toList();
        } catch (e) {
          debugPrint('Error loading orders from Firestore: $e');
        }
      }

      for (final o in instOrders) {
        Instrument? inst = o.instrumentObj;
        if (inst == null && instrumentStore != null) {
          final matches = instrumentStore.items.where((i) =>
              i.url == o.instrument ||
              i.id == o.instrument ||
              (i.id.isNotEmpty && o.instrument.contains(i.id)));
          if (matches.isNotEmpty) {
            inst = matches.first;
            o.instrumentObj = inst;
          }
        }

        if (inst == null &&
            widget.service != null &&
            widget.brokerageUser != null &&
            instrumentStore != null &&
            o.instrument.isNotEmpty) {
          try {
            inst = await widget.service!.getInstrument(
              widget.brokerageUser!,
              instrumentStore,
              o.instrument,
            );
            o.instrumentObj = inst;
          } catch (e) {
            debugPrint('Error loading instrument details for order: $e');
          }
        }

        String sym = inst?.symbol ?? '';
        if (sym.isEmpty) {
          final rawId = o.instrument.isNotEmpty
              ? o.instrument.split('/').where((s) => s.isNotEmpty).last
              : '';
          final isUuid = RegExp(r'^[0-9a-fA-F\-]{15,}$').hasMatch(rawId);
          if (!isUuid && rawId.isNotEmpty && rawId.length <= 8) {
            sym = rawId.toUpperCase();
          } else {
            sym = 'STOCK';
          }
        }

        final companyName = inst?.simpleName ?? inst?.name;
        final side = o.side.toLowerCase();
        final isPending = o.state.toLowerCase() != 'filled';
        final qty = (o.cumulativeQuantity != null && o.cumulativeQuantity! > 0)
            ? o.cumulativeQuantity!
            : (o.quantity ?? 1.0);
        final prc = o.averagePrice ?? o.price ?? 0.0;
        final title = isPending
            ? '${side == 'buy' ? 'Buy Order' : 'Sell Order'}: $sym'
            : '${side == 'buy' ? 'Bought' : 'Sold'} $sym';
        candidates.add(GroupActivity(
          id: '',
          groupId: widget.groupId,
          userId: widget.currentUid,
          userName: widget.currentDisplayName,
          type: isPending ? GroupActivityType.order : GroupActivityType.trade,
          title: title,
          timestamp: o.updatedAt ?? o.createdAt ?? DateTime.now(),
          symbol: sym,
          side: side,
          quantity: qty,
          price: prc,
          orderType: o.type,
          assetType: 'equity',
          details: {
            'orderId': o.id,
            'state': o.state,
            'trigger': o.trigger,
            if (companyName != null && companyName.isNotEmpty)
              'companyName': companyName,
            if (inst?.id != null) 'instrumentId': inst!.id,
          },
        ));
      }

      for (final o in optOrders) {
        final sym = o.chainSymbol.isNotEmpty ? o.chainSymbol : 'OPTION';
        final side = (o.direction.toLowerCase() == 'credit') ? 'sell' : 'buy';
        final isPending = o.state.toLowerCase() != 'filled';
        final qty = (o.processedQuantity != null && o.processedQuantity! > 0)
            ? o.processedQuantity!
            : (o.quantity ?? 1.0);
        final prc = o.price ?? 0.0;
        final firstLeg = o.legs.isNotEmpty ? o.legs.first : null;
        final title = isPending
            ? '${side == 'buy' ? 'Buy Order' : 'Sell Order'}: $sym Option'
            : '${side == 'buy' ? 'Bought' : 'Sold'} $sym Option';
        candidates.add(GroupActivity(
          id: '',
          groupId: widget.groupId,
          userId: widget.currentUid,
          userName: widget.currentDisplayName,
          type: isPending ? GroupActivityType.order : GroupActivityType.trade,
          title: title,
          timestamp: o.updatedAt ?? o.createdAt ?? DateTime.now(),
          symbol: sym,
          side: side,
          quantity: qty,
          price: prc,
          orderType: o.type,
          assetType: 'option',
          details: {
            'orderId': o.id,
            'state': o.state,
            'direction': o.direction,
            if (firstLeg != null) ...{
              'strikePrice': firstLeg.strikePrice,
              'expirationDate': firstLeg.expirationDate?.toIso8601String(),
              'optionType': firstLeg.optionType,
            },
          },
        ));
      }
    } catch (e) {
      debugPrint('Error processing candidate trades: $e');
    }

    bool isSample = false;
    if (candidates.isEmpty) {
      isSample = true;
      final now = DateTime.now();
      candidates.addAll([
        GroupActivity(
          id: '',
          groupId: widget.groupId,
          userId: widget.currentUid,
          userName: widget.currentDisplayName,
          type: GroupActivityType.trade,
          title: 'Bought AAPL',
          timestamp: now.subtract(const Duration(hours: 2)),
          symbol: 'AAPL',
          side: 'buy',
          quantity: 10,
          price: 182.50,
          orderType: 'market',
          assetType: 'equity',
          details: {
            'orderId': 'sample-aapl-${now.millisecondsSinceEpoch}',
            'companyName': 'Apple Inc.',
          },
        ),
        GroupActivity(
          id: '',
          groupId: widget.groupId,
          userId: widget.currentUid,
          userName: widget.currentDisplayName,
          type: GroupActivityType.trade,
          title: 'Bought NVDA Call',
          timestamp: now.subtract(const Duration(hours: 5)),
          symbol: 'NVDA',
          side: 'buy',
          quantity: 1,
          price: 4.75,
          orderType: 'limit',
          assetType: 'option',
          details: {
            'orderId': 'sample-nvda-${now.millisecondsSinceEpoch}',
            'companyName': 'NVIDIA Corporation',
            'strikePrice': 125.0,
            'optionType': 'call',
            'expirationDate':
                now.add(const Duration(days: 30)).toIso8601String(),
          },
        ),
        GroupActivity(
          id: '',
          groupId: widget.groupId,
          userId: widget.currentUid,
          userName: widget.currentDisplayName,
          type: GroupActivityType.trade,
          title: 'Sold TSLA',
          timestamp: now.subtract(const Duration(days: 1)),
          symbol: 'TSLA',
          side: 'sell',
          quantity: 5,
          price: 214.20,
          orderType: 'limit',
          assetType: 'equity',
          details: {
            'orderId': 'sample-tsla-${now.millisecondsSinceEpoch}',
            'companyName': 'Tesla, Inc.',
          },
        ),
        GroupActivity(
          id: '',
          groupId: widget.groupId,
          userId: widget.currentUid,
          userName: widget.currentDisplayName,
          type: GroupActivityType.trade,
          title: 'Bought SPY Put',
          timestamp: now.subtract(const Duration(days: 2)),
          symbol: 'SPY',
          side: 'buy',
          quantity: 2,
          price: 2.15,
          orderType: 'market',
          assetType: 'option',
          details: {
            'orderId': 'sample-spy-${now.millisecondsSinceEpoch}',
            'companyName': 'SPDR S&P 500 ETF Trust',
            'strikePrice': 540.0,
            'optionType': 'put',
            'expirationDate':
                now.add(const Duration(days: 14)).toIso8601String(),
          },
        ),
      ]);
    }

    if (mounted) {
      setState(() {
        _candidateTrades = candidates;
        _isSampleData = isSample;
        _selectedIndices.addAll(List.generate(candidates.length, (i) => i));
        _isLoading = false;
      });
    }
  }

  Future<void> _shareSelected() async {
    if (_selectedIndices.isEmpty) return;
    setState(() => _isSharing = true);
    HapticFeedback.mediumImpact();

    final selectedActivities =
        _selectedIndices.map((i) => _candidateTrades[i]).toList();
    final count = await widget.firestoreService.shareRecentTradesToGroup(
      groupId: widget.groupId,
      userId: widget.currentUid,
      userName: widget.currentDisplayName,
      userPhotoUrl: widget.currentPhotoUrl,
      activities: selectedActivities,
    );

    widget.onTradesShared(count);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormatter = NumberFormat.simpleCurrency();
    final dateFormatter = DateFormat('MMM d, h:mm a');

    return Material(
      color: theme.scaffoldBackgroundColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Share Recent Trades',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Post your trades to ${widget.groupName}',
                          style: TextStyle(
                            fontSize: 12,
                            color: _getSecondaryTextColor(),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Privacy Callout Banner
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined,
                      color: theme.colorScheme.primary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Posting as: ${widget.privacySettings.anonymous ? 'Anonymous Member' : widget.currentDisplayName}',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Amounts: ${widget.privacySettings.showTradeAmounts ? 'Visible' : 'Hidden (\$***)'}',
                          style: TextStyle(
                              fontSize: 11, color: _getSecondaryTextColor()),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onOpenPrivacySettings,
                    child: const Text('Edit', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),

            if (_isSampleData)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No order history found. Showing sample demo trades ready to seed.',
                        style: TextStyle(fontSize: 11, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),

            // Selection controls bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${_selectedIndices.length} of ${_candidateTrades.length} selected',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _getSecondaryTextColor(),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: _candidateTrades.isEmpty
                        ? null
                        : () {
                            setState(() {
                              if (_selectedIndices.length ==
                                  _candidateTrades.length) {
                                _selectedIndices.clear();
                              } else {
                                _selectedIndices.addAll(List.generate(
                                    _candidateTrades.length, (i) => i));
                              }
                            });
                          },
                    child: Text(
                      _selectedIndices.length == _candidateTrades.length
                          ? 'Deselect All'
                          : 'Select All',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

            // Candidate Trades List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _candidateTrades.isEmpty
                      ? Center(
                          child: Text(
                            'No recent trades available to share.',
                            style: TextStyle(color: _getSecondaryTextColor()),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          itemCount: _candidateTrades.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final trade = _candidateTrades[index];
                            final isSelected = _selectedIndices.contains(index);
                            final isBuy = trade.isBuy;
                            final isOption = trade.assetType == 'option';
                            final companyName = trade.details?['companyName'] ??
                                trade.details?['name'];

                            // Option metadata formatting
                            final strikePrice = trade.details?['strikePrice'];
                            final optionType = trade.details?['optionType'];
                            final expDateStr = trade.details?['expirationDate'];
                            DateTime? expDate;
                            if (expDateStr != null) {
                              try {
                                expDate = DateTime.parse(expDateStr.toString());
                              } catch (_) {}
                            }
                            String? optionDetailText;
                            if (strikePrice != null && optionType != null) {
                              final expFormatted = expDate != null
                                  ? DateFormat('MMM d').format(expDate)
                                  : '';
                              optionDetailText =
                                  '\$${strikePrice % 1 == 0 ? strikePrice.toInt() : strikePrice} ${optionType.toString().toUpperCase()}${expFormatted.isNotEmpty ? ' • Exp $expFormatted' : ''}';
                            }

                            return CheckboxListTile(
                              value: isSelected,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedIndices.add(index);
                                  } else {
                                    _selectedIndices.remove(index);
                                  }
                                });
                              },
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              secondary: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: (isBuy ? Colors.green : Colors.red)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isOption
                                      ? Icons.candlestick_chart
                                      : (isBuy
                                          ? Icons.arrow_upward
                                          : Icons.arrow_downward),
                                  color: isBuy ? Colors.green : Colors.red,
                                  size: 20,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      trade.symbol ??
                                          (isOption ? 'OPTION' : 'STOCK'),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (isBuy ? Colors.green : Colors.red)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      (trade.side ?? 'trade').toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            isBuy ? Colors.green : Colors.red,
                                      ),
                                    ),
                                  ),
                                  if (isOption) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.purple
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'OPTION',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.purple,
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (trade.details?['state'] != null &&
                                      trade.details!['state'] != 'filled') ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.orange
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        trade.details!['state']
                                            .toString()
                                            .toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (companyName != null &&
                                      companyName.toString().isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      companyName.toString(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: _getSecondaryTextColor(),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  if (optionDetailText != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      optionDetailText,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: _getSecondaryTextColor(),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  const SizedBox(height: 2),
                                  Text(
                                    '${trade.quantity != null ? (trade.quantity! % 1 == 0 ? trade.quantity!.toInt().toString() : trade.quantity!.toStringAsFixed(2)) : ''} ${isOption ? 'contract(s)' : 'share(s)'} @ ${trade.price != null ? currencyFormatter.format(trade.price) : ''}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    dateFormatter.format(trade.timestamp),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _getSecondaryTextColor(),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),

            // Bottom Action Button
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    icon: _isSharing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.share),
                    label: Text(
                      _isSharing
                          ? 'Sharing...'
                          : 'Share ${_selectedIndices.length} Trade${_selectedIndices.length == 1 ? '' : 's'} to Feed',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: (_isSharing || _selectedIndices.isEmpty)
                        ? null
                        : _shareSelected,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
