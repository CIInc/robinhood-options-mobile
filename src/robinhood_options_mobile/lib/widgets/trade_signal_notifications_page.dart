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
import 'package:robinhood_options_mobile/services/plaid_service.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:robinhood_options_mobile/main.dart';

class TradeSignalNotificationsPage extends StatelessWidget {
  final User user;
  final DocumentReference<User> userDocRef;

  const TradeSignalNotificationsPage({
    super.key,
    required this.user,
    required this.userDocRef,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
              ),
            );
          }

          // Group notifications by date
          final groupedNotifications = _groupNotifications(store.notifications);

          return ListView.builder(
            itemCount: groupedNotifications.length,
            itemBuilder: (context, index) {
              final group = groupedNotifications[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      group.title,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  ...group.notifications
                      .map((notification) => _NotificationItem(
                            notification: notification,
                            store: store,
                            user: user,
                            userDocRef: userDocRef,
                          )),
                ],
              );
            },
          );
        },
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
    final timeFormat = DateFormat.jm();

    Color signalColor;
    if (notification.signal == 'BUY') {
      signalColor = Colors.green;
    } else if (notification.signal == 'SELL') {
      signalColor = Colors.red;
    } else {
      signalColor = Colors.grey;
    }

    return Dismissible(
      key: Key(notification.id),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
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
        child: Container(
          color: notification.read
              ? null
              : theme.colorScheme.primaryContainer
                  .withAlpha(50), //.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Signal Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: signalColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    notification.signal == 'BUY'
                        ? Icons.trending_up
                        : (notification.signal == 'SELL'
                            ? Icons.trending_down
                            : Icons.remove),
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
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            timeFormat.format(notification.timestamp),
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
                      if (notification.price != null ||
                          notification.confidence != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Wrap(
                            spacing: 8,
                            children: [
                              if (notification.price != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme
                                        .colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '\$${notification.price!.toStringAsFixed(2)}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                              if (notification.confidence != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme
                                        .colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Conf: ${(notification.confidence! * 100).toStringAsFixed(0)}%',
                                    style: theme.textTheme.bodySmall,
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
        case BrokerageSource.plaid:
          service = PlaidService();
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
        Navigator.pop(context); // Dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading instrument: $e')),
        );
      });
    }
  }
}
