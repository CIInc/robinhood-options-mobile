import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/trade_signal_notification.dart';
import 'package:robinhood_options_mobile/model/trade_signal_notifications_store.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
import 'package:robinhood_options_mobile/services/schwab_service.dart';
import 'package:robinhood_options_mobile/services/fidelity_service.dart';
import 'package:robinhood_options_mobile/services/paper_service.dart';
import 'package:robinhood_options_mobile/services/plaid_service.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/widgets/trade_signal_notification_settings_widget.dart';

class TradeSignalNotificationsPage extends StatefulWidget {
  final User user;
  final DocumentReference<User> userDocRef;
  final bool fromSettings;

  const TradeSignalNotificationsPage({
    super.key,
    required this.user,
    required this.userDocRef,
    this.fromSettings = false,
  });

  @override
  State<TradeSignalNotificationsPage> createState() =>
      _TradeSignalNotificationsPageState();
}

class _TradeSignalNotificationsPageState
    extends State<TradeSignalNotificationsPage> {
  String _searchQuery = '';
  final Set<String> _selectedFilters = {'All'};
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (!widget.fromSettings)
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Notification Settings',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => TradeSignalNotificationSettingsWidget(
                      user: widget.user,
                      userDocRef: widget.userDocRef,
                      hideNotificationIcon: true,
                    ),
                  ),
                );
              },
            ),
          Consumer<TradeSignalNotificationsStore>(
            builder: (context, store, child) {
              if (store.unreadCount == 0) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.done_all),
                tooltip: 'Mark all as read',
                onPressed: () {
                  store.markAllAsRead();
                },
              );
            },
          ),
        ],
      ),
      body: Consumer<TradeSignalNotificationsStore>(
        builder: (context, store, child) {
          if (store.notifications.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.notifications_none_rounded,
                        size: 48,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No new trade signals',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You will be notified when new trading opportunities match your criteria.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 32),
                    if (!widget.fromSettings)
                      FilledButton.tonalIcon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  TradeSignalNotificationSettingsWidget(
                                user: widget.user,
                                userDocRef: widget.userDocRef,
                                hideNotificationIcon: true,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.tune),
                        label: const Text('Adjust Alerts'),
                      ),
                  ],
                ),
              ),
            );
          }

          // Filter notifications
          final filteredNotifications = store.notifications.where((n) {
            // Text search
            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              final matchesSymbol = n.symbol.toLowerCase().contains(query);
              final matchesTitle = n.title.toLowerCase().contains(query);
              final matchesBody = n.body.toLowerCase().contains(query);
              if (!matchesSymbol && !matchesTitle && !matchesBody) {
                return false;
              }
            }
            // Filter chips
            if (!_selectedFilters.contains('All')) {
              if (_selectedFilters.contains('Buy') && n.signal != 'BUY') {
                return false;
              }
              if (_selectedFilters.contains('Sell') && n.signal != 'SELL') {
                return false;
              }
              if (_selectedFilters.contains('Unread') && n.read) {
                return false;
              }
            }
            return true;
          }).toList();

          // Group notifications by date
          final groupedNotifications =
              _groupNotifications(filteredNotifications);

          return Column(
            children: [
              // Search and Filter Bar
              Material(
                elevation: 1,
                color: Theme.of(context).colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search signals...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      setState(() {
                                        _searchController.clear();
                                        _searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 0),
                            fillColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.5),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            _buildFilterChip('All'),
                            const SizedBox(width: 8),
                            _buildFilterChip('Buy'),
                            const SizedBox(width: 8),
                            _buildFilterChip('Sell'),
                            const SizedBox(width: 8),
                            _buildFilterChip('Unread'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: filteredNotifications.isEmpty
                    ? Center(
                        child: Text(
                          'No signals found',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: groupedNotifications.length,
                        itemBuilder: (context, index) {
                          final group = groupedNotifications[index];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 24, 16, 8),
                                child: Row(
                                  children: [
                                    Text(
                                      group.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: Divider(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .outlineVariant)),
                                  ],
                                ),
                              ),
                              ...group.notifications
                                  .map((notification) => _NotificationItem(
                                        notification: notification,
                                        store: store,
                                        user: widget.user,
                                        userDocRef: widget.userDocRef,
                                      )),
                            ],
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilters.contains(label);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        setState(() {
          if (label == 'All') {
            _selectedFilters.clear();
            _selectedFilters.add('All');
          } else {
            _selectedFilters.remove('All');
            if (selected) {
              _selectedFilters.add(label);
            } else {
              _selectedFilters.remove(label);
            }
            if (_selectedFilters.isEmpty) {
              _selectedFilters.add('All');
            }
          }
        });
      },
      showCheckmark: false,
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      labelStyle: TextStyle(
        color: isSelected
            ? Theme.of(context).colorScheme.onPrimaryContainer
            : Theme.of(context).colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  List<_NotificationGroup> _groupNotifications(
      List<TradeSignalNotification> notifications) {
    final groups = <_NotificationGroup>[];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final todayNotifications = <TradeSignalNotification>[];
    final yesterdayNotifications = <TradeSignalNotification>[];
    final olderNotifications = <TradeSignalNotification>[];

    for (var n in notifications) {
      final date =
          DateTime(n.timestamp.year, n.timestamp.month, n.timestamp.day);
      if (date.isAtSameMomentAs(today)) {
        todayNotifications.add(n);
      } else if (date.isAtSameMomentAs(yesterday)) {
        yesterdayNotifications.add(n);
      } else {
        olderNotifications.add(n);
      }
    }

    if (todayNotifications.isNotEmpty) {
      groups.add(_NotificationGroup('Today', todayNotifications));
    }
    if (yesterdayNotifications.isNotEmpty) {
      groups.add(_NotificationGroup('Yesterday', yesterdayNotifications));
    }
    if (olderNotifications.isNotEmpty) {
      groups.add(_NotificationGroup('Older', olderNotifications));
    }

    return groups;
  }
}

class _NotificationGroup {
  final String title;
  final List<TradeSignalNotification> notifications;

  _NotificationGroup(this.title, this.notifications);
}

class _NotificationItem extends StatelessWidget {
  final TradeSignalNotification notification;
  final TradeSignalNotificationsStore store;
  final User user;
  final DocumentReference<User> userDocRef;

  const _NotificationItem({
    required this.notification,
    required this.store,
    required this.user,
    required this.userDocRef,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final date = DateTime(notification.timestamp.year,
        notification.timestamp.month, notification.timestamp.day);

    final isTodayOrYesterday =
        date.isAtSameMomentAs(today) || date.isAtSameMomentAs(yesterday);
    final dateFormat =
        isTodayOrYesterday ? DateFormat.jm() : DateFormat.MMMd().add_jm();

    Color signalColor;
    IconData signalIcon;

    if (notification.signal == 'BUY') {
      signalColor = Colors.green;
      signalIcon = Icons.arrow_upward;
    } else if (notification.signal == 'SELL') {
      signalColor = Colors.red;
      signalIcon = Icons.arrow_downward;
    } else if (notification.signal == 'HOLD') {
      signalColor = Colors.orange;
      signalIcon = Icons.pause;
    } else {
      signalColor = Colors.grey;
      signalIcon = Icons.info_outline;
    }

    return Dismissible(
      key: Key(notification.id),
      background: Container(
        color: theme.colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Delete',
                style: TextStyle(
                    color: theme.colorScheme.onError,
                    fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Icon(Icons.delete_outline, color: theme.colorScheme.onError),
          ],
        ),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        store.delete(notification.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification deleted')),
        );
      },
      child: InkWell(
        onTap: () {
          if (!notification.read) {
            store.markAsRead(notification.id);
          }
          _navigateToInstrument(context);
        },
        onLongPress: () {
          if (notification.read) {
            store.markAsUnread(notification.id);
          } else {
            store.markAsRead(notification.id);
          }
        },
        child: Container(
          color: notification.read
              ? null
              : theme.colorScheme.primaryContainer.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Signal Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: signalColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    signalIcon,
                    color: signalColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: notification.read
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                                color: notification.read
                                    ? theme.textTheme.bodyLarge?.color
                                    : theme.colorScheme.primary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            dateFormat.format(notification.timestamp),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.body,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodyMedium?.color
                              ?.withValues(alpha: 0.8),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(
                          spacing: 8,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: theme.colorScheme.outline
                                      .withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    notification.interval == '1d'
                                        ? Icons.calendar_today
                                        : Icons.access_time,
                                    size: 12,
                                    color: theme.textTheme.bodySmall?.color,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    notification.interval == '1d'
                                        ? 'Daily'
                                        : notification.interval == '1h'
                                            ? 'Hourly'
                                            : notification.interval == '30m'
                                                ? '30m'
                                                : notification.interval == '15m'
                                                    ? '15m'
                                                    : notification.interval,
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            if (notification.price != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '\$${notification.price!.toStringAsFixed(2)}',
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(fontSize: 11),
                                ),
                              ),
                            if (notification.confidence != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (notification.confidence! > 0.8)
                                      ? Colors.green.withValues(alpha: 0.1)
                                      : theme
                                          .colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(4),
                                  border: (notification.confidence! > 0.8)
                                      ? Border.all(
                                          color: Colors.green
                                              .withValues(alpha: 0.3))
                                      : null,
                                ),
                                child: Text(
                                  '${(notification.confidence! * 100).toStringAsFixed(0)}% Conf.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 11,
                                    color: (notification.confidence! > 0.8)
                                        ? Colors.green
                                        : null,
                                    fontWeight: (notification.confidence! > 0.8)
                                        ? FontWeight.bold
                                        : null,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!notification.read)
                  Container(
                    margin: const EdgeInsets.only(left: 8, top: 8),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToInstrument(BuildContext context) {
    if (notification.symbol.isEmpty) return;

    final userStore = Provider.of<BrokerageUserStore>(context, listen: false);
    final instrumentStore =
        Provider.of<InstrumentStore>(context, listen: false);

    if (userStore.items.isNotEmpty) {
      // Use the current user or default to first
      var brokerageUser = userStore.currentUser ?? userStore.items.first;

      // Determine service based on user source
      IBrokerageService service;
      switch (brokerageUser.source) {
        case BrokerageSource.robinhood:
          service = RobinhoodService();
          break;
        case BrokerageSource.schwab:
          service = SchwabService();
          break;
        case BrokerageSource.fidelity:
          service = FidelityService();
          break;
        case BrokerageSource.plaid:
          service = PlaidService();
          break;
        case BrokerageSource.paper:
          service = PaperService();
          break;
        default:
          service = DemoService();
      }

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      service
          .getInstrumentBySymbol(
              brokerageUser, instrumentStore, notification.symbol)
          .then((instrument) {
        if (!context.mounted) return;
        Navigator.pop(context); // Dismiss loading

        if (instrument != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => InstrumentWidget(
                brokerageUser,
                service,
                instrument,
                analytics: FirebaseAnalytics.instance,
                observer: MyApp.observer,
                generativeService: GenerativeService(),
                user: user,
                userDocRef: userDocRef,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Instrument not found: ${notification.symbol}')),
          );
        }
      }).catchError((e) {
        if (!context.mounted) return;
        Navigator.pop(context); // Dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading instrument: $e')),
        );
      });
    }
  }
}
