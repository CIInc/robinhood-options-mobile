import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/notification_item.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// In-app notification center and announcements viewer integrating Midlands stack
/// (`/midlands/notifications/stack/`) and Inbox threads (`/inbox/threads/`).
class NotificationCenterWidget extends StatefulWidget {
  final BrokerageUser brokerageUser;
  final IBrokerageService service;

  const NotificationCenterWidget({
    super.key,
    required this.brokerageUser,
    required this.service,
  });

  @override
  State<NotificationCenterWidget> createState() =>
      _NotificationCenterWidgetState();
}

class _NotificationCenterWidgetState extends State<NotificationCenterWidget> {
  Future<List<NotificationItem>>? _futureNotifications;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'all';
  bool _unreadOnly = false;
  final Set<String> _expandedItemIds = {};
  final Set<String> _localReadIds = {};

  final List<String> _categories = [
    'all',
    'orders',
    'options',
    'crypto',
    'futures',
    'dividends',
    'ipo',
    'announcements',
    'security',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadData() {
    setState(() {
      _futureNotifications = _fetchCombinedNotifications();
    });
  }

  Future<List<NotificationItem>> _fetchCombinedNotifications() async {
    final stack =
        await widget.service.getNotificationStackModel(widget.brokerageUser);
    final threads =
        await widget.service.getInboxThreadsModel(widget.brokerageUser);

    final combined = <NotificationItem>[...stack, ...threads];

    // Sort with critical & fixed items first, then by timestamp descending
    combined.sort((a, b) {
      if (a.isCritical && !b.isCritical) return -1;
      if (!a.isCritical && b.isCritical) return 1;
      if (a.isFixed && !b.isFixed) return -1;
      if (!a.isFixed && b.isFixed) return 1;
      final aTime = a.time ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.time ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    return combined;
  }

  bool _isItemRead(NotificationItem item) {
    if (_localReadIds.contains(item.cardId)) {
      return true;
    }
    return item.isRead;
  }

  void _toggleItemRead(NotificationItem item) {
    setState(() {
      if (_localReadIds.contains(item.cardId)) {
        _localReadIds.remove(item.cardId);
      } else {
        _localReadIds.add(item.cardId);
      }
    });
  }

  void _markAllAsRead(List<NotificationItem> items) {
    setState(() {
      for (final item in items) {
        _localReadIds.add(item.cardId);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All notifications marked as read'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleAction(NotificationItem item) async {
    final target = item.actionUrl ?? item.action ?? item.url;
    if (target != null && target.isNotEmpty) {
      if (target.startsWith('http://') || target.startsWith('https://')) {
        final uri = Uri.tryParse(target);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      } else if (target.startsWith('robinhood://web?url=')) {
        final embedded = Uri.decodeComponent(
            target.replaceFirst('robinhood://web?url=', ''));
        final uri = Uri.tryParse(embedded);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      } else if (target.startsWith('robinhood://')) {
        _handleRobinhoodDeepLink(target, item);
        return;
      }
    }

    // Default info dialog if action cannot be launched externally
    if (mounted) {
      _showDetailDialog(item);
    }
  }

  void _handleRobinhoodDeepLink(String deepLink, NotificationItem item) {
    final uri = Uri.tryParse(deepLink);
    final path = uri?.host ?? '';
    final queryParams = uri?.queryParameters ?? {};

    String title = item.title;
    String content = item.message;

    if (path == 'orders') {
      final orderId = queryParams['id'];
      final orderType = queryParams['type'] ?? 'equity';
      title = 'Order Details';
      content = 'Type: ${orderType.toUpperCase()}\n'
          '${orderId != null ? 'Order ID: $orderId\n' : ''}'
          '${item.message}';
    } else if (path == 'dividends') {
      final divId = queryParams['id'];
      title = 'Dividend Information';
      content = '${divId != null ? 'Dividend ID: $divId\n' : ''}'
          '${item.message}';
    } else if (path == 'lists') {
      final listId = queryParams['id'];
      title = 'Robinhood Watchlist';
      content = '${listId != null ? 'List ID: $listId\n' : ''}'
          '${item.message}';
    } else if (path == 'instrument') {
      final symbol = queryParams['symbol'];
      title = symbol != null ? 'Stock Symbol: $symbol' : 'Instrument Details';
      content = item.message;
    } else if (path == 'trusted_devices') {
      title = 'Security & Trusted Devices';
      content = 'Device verification alert.\n${item.message}';
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SelectableText(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showDetailDialog(NotificationItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            if (item.shortDisplayName != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: item.iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.shortDisplayName!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: item.iconColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(child: Text(item.title, overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.isCritical)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Critical Notification',
                        style: TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              SelectableText(item.message),
              if (item.formattedTime.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  item.formattedTime,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _handleResponseTap(
      NotificationItem item, NotificationResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected: "${response.displayText}"'),
        action: SnackBarAction(
          label: 'Details',
          onPressed: () => _showDetailDialog(item),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Center'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
      ),
      body: FutureBuilder<List<NotificationItem>>(
        future: _futureNotifications,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error loading notifications: ${snapshot.error}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadData,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final allItems = snapshot.data ?? [];
          final filteredItems = _filterItems(allItems);

          return RefreshIndicator(
            onRefresh: () async => _loadData(),
            child: Column(
              children: [
                _buildSearchBar(),
                _buildCategoryFilterBar(context, allItems),
                _buildStatusBar(context, allItems, filteredItems),
                Expanded(
                  child: filteredItems.isEmpty
                      ? _buildEmptyState(context)
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12.0, vertical: 6.0),
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            return _buildNotificationCard(
                                context, filteredItems[index]);
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<NotificationItem> _filterItems(List<NotificationItem> allItems) {
    return allItems.where((item) {
      // Category filter
      if (_selectedCategory != 'all') {
        if (item.category.toLowerCase() != _selectedCategory) {
          return false;
        }
      }

      // Unread only filter
      if (_unreadOnly && _isItemRead(item)) {
        return false;
      }

      // Search query filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final title = item.title.toLowerCase();
        final message = item.message.toLowerCase();
        final shortName = (item.shortDisplayName ?? '').toLowerCase();
        final actionText = (item.actionDisplayText ?? '').toLowerCase();
        if (!title.contains(query) &&
            !message.contains(query) &&
            !shortName.contains(query) &&
            !actionText.contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search notifications, symbols, orders...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          filled: true,
          fillColor:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (val) {
          setState(() {
            _searchQuery = val.trim();
          });
        },
      ),
    );
  }

  Widget _buildCategoryFilterBar(
      BuildContext context, List<NotificationItem> items) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        children: [
          ..._categories.map((cat) {
            final isSelected = _selectedCategory == cat;
            final count = cat == 'all'
                ? items.length
                : items.where((i) => i.category.toLowerCase() == cat).length;
            final label = cat == 'all'
                ? 'All ($count)'
                : '${_getCategoryLabel(cat)} ($count)';

            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilterChip(
                label: Text(label, style: const TextStyle(fontSize: 12)),
                selected: isSelected,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedCategory = cat;
                    });
                  }
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatusBar(
    BuildContext context,
    List<NotificationItem> allItems,
    List<NotificationItem> filteredItems,
  ) {
    final unreadCount = allItems.where((i) => !_isItemRead(i)).length;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              FilterChip(
                label: Text(
                  'Unread only ($unreadCount)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        _unreadOnly ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                selected: _unreadOnly,
                visualDensity: VisualDensity.compact,
                onSelected: (val) {
                  setState(() {
                    _unreadOnly = val;
                  });
                },
              ),
            ],
          ),
          if (unreadCount > 0)
            TextButton.icon(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              icon: const Icon(Icons.done_all, size: 16),
              label: Text(
                'Mark all read',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () => _markAllAsRead(allItems),
            ),
        ],
      ),
    );
  }

  String _getCategoryLabel(String cat) {
    switch (cat) {
      case 'ipo':
        return 'IPO Access';
      case 'orders':
        return 'Orders';
      case 'options':
        return 'Options';
      case 'crypto':
        return 'Crypto';
      case 'futures':
        return 'Futures';
      case 'dividends':
        return 'Dividends';
      case 'announcements':
        return 'Announcements';
      case 'security':
        return 'Security';
      default:
        return cat.isNotEmpty ? cat[0].toUpperCase() + cat.substring(1) : cat;
    }
  }

  Widget _buildNotificationCard(BuildContext context, NotificationItem item) {
    final theme = Theme.of(context);
    final isRead = _isItemRead(item);
    final isExpanded = _expandedItemIds.contains(item.cardId);

    return Card(
      elevation: item.isCritical ? 3 : (item.isFixed ? 2 : 1),
      margin: const EdgeInsets.symmetric(vertical: 5.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: item.isCritical
            ? BorderSide(color: Colors.red.shade400, width: 1.5)
            : (item.isFixed
                ? BorderSide(
                    color: theme.colorScheme.primary.withValues(alpha: 0.5),
                    width: 1.5,
                  )
                : BorderSide(
                    color:
                        theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                    width: 0.5,
                  )),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetailDialog(item),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Critical banner
              if (item.isCritical) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 15, color: Colors.red),
                      const SizedBox(width: 6),
                      Text(
                        'CRITICAL NOTICE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar Badge
                  _buildAvatar(item),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Row(
                                children: [
                                  if (!isRead) ...[
                                    Container(
                                      width: 8,
                                      height: 8,
                                      margin: const EdgeInsets.only(right: 6),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                  Flexible(
                                    child: Text(
                                      item.title,
                                      style:
                                          theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: isRead
                                            ? FontWeight.w600
                                            : FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              item.relativeTime.isNotEmpty
                                  ? item.relativeTime
                                  : item.formattedTime,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: item.iconColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(item.iconData,
                                      size: 11, color: item.iconColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    item.formattedCategory.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: item.iconColor,
                                      letterSpacing: 0.3,
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
              const SizedBox(height: 10),
              // Message text
              Text(
                item.message,
                maxLines: isExpanded ? null : 3,
                overflow:
                    isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.35,
                  color: theme.colorScheme.onSurface
                      .withValues(alpha: isRead ? 0.85 : 1.0),
                ),
              ),
              if (item.message.length > 120 || item.message.contains('\n')) ...[
                InkWell(
                  onTap: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedItemIds.remove(item.cardId);
                      } else {
                        _expandedItemIds.add(item.cardId);
                      }
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      isExpanded ? 'Show less' : 'Show more',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
              // Quick interactive responses
              if (item.responses.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: item.responses.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, rIdx) {
                      final resp = item.responses[rIdx];
                      return ActionChip(
                        label: Text(resp.displayText,
                            style: const TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        onPressed: () => _handleResponseTap(item, resp),
                      );
                    },
                  ),
                ),
              ],
              // Action buttons row
              if (item.actionDisplayText != null &&
                  item.actionDisplayText!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(
                        isRead
                            ? Icons.mark_email_unread_outlined
                            : Icons.mark_email_read_outlined,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      tooltip: isRead ? 'Mark as unread' : 'Mark as read',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _toggleItemRead(item),
                    ),
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 0),
                      ),
                      icon: const Icon(Icons.arrow_outward, size: 14),
                      label: Text(
                        item.actionDisplayText!,
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () => _handleAction(item),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(
                        isRead
                            ? Icons.mark_email_unread_outlined
                            : Icons.mark_email_read_outlined,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      tooltip: isRead ? 'Mark as unread' : 'Mark as read',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _toggleItemRead(item),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(NotificationItem item) {
    final avatarBg = item.avatarColor ?? item.iconColor;
    final isShortValid =
        item.shortDisplayName != null && item.shortDisplayName!.isNotEmpty;

    if (isShortValid) {
      final text = item.shortDisplayName!;
      final fontSize = text.length > 4 ? 9.0 : (text.length > 2 ? 11.0 : 13.0);
      return CircleAvatar(
        backgroundColor: avatarBg,
        foregroundColor: Colors.white,
        radius: 20,
        child: Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.2,
          ),
        ),
      );
    }

    return CircleAvatar(
      backgroundColor: avatarBg.withValues(alpha: 0.15),
      foregroundColor: avatarBg,
      radius: 20,
      child: Icon(item.iconData, size: 20),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_off_outlined,
                size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No notifications found for "$_searchQuery"'
                  : 'No notifications in this category',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try adjusting your search terms or filters.'
                  : 'New orders, announcements, dividends, and alerts will be displayed here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
