import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/option_flow_notifications_store.dart';
import 'package:robinhood_options_mobile/widgets/options_flow_widget.dart';

class OptionsFlowNotificationsPage extends StatefulWidget {
  const OptionsFlowNotificationsPage({super.key});

  @override
  State<OptionsFlowNotificationsPage> createState() =>
      _OptionsFlowNotificationsPageState();
}

class _OptionsFlowNotificationsPageState
    extends State<OptionsFlowNotificationsPage> {
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
        title: const Text('Flow Alerts'),
        actions: [
          Consumer<OptionFlowNotificationsStore>(
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
      body: Consumer<OptionFlowNotificationsStore>(
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
                      'No flow alerts yet',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Alerts will appear here when institutional flow matches your criteria.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            );
          }

          final filteredNotifications = store.notifications.where((n) {
            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              final matchesSymbol = n.symbol.toLowerCase().contains(query);
              final matchesTitle = n.title.toLowerCase().contains(query);
              final matchesBody = n.body.toLowerCase().contains(query);
              if (!matchesSymbol && !matchesTitle && !matchesBody) {
                return false;
              }
            }
            if (!_selectedFilters.contains('All')) {
              if (_selectedFilters.contains('Unread') && n.read) {
                return false;
              }
              if (_selectedFilters.contains('Bullish') &&
                  n.sentiment != 'bullish') {
                return false;
              }
              if (_selectedFilters.contains('Bearish') &&
                  n.sentiment != 'bearish') {
                return false;
              }
            }
            return true;
          }).toList();

          return Column(
            children: [
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
                            hintText: 'Search flow alerts...',
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
                            _buildFilterChip('Unread'),
                            const SizedBox(width: 8),
                            _buildFilterChip('Bullish'),
                            const SizedBox(width: 8),
                            _buildFilterChip('Bearish'),
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
                          'No alerts found',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredNotifications.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final notification = filteredNotifications[index];
                          final sentimentColor =
                              notification.sentiment == 'bullish'
                                  ? Colors.green
                                  : (notification.sentiment == 'bearish'
                                      ? Colors.red
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant);
                          final subtitleParts = <String>[];
                          if (notification.premium != null) {
                            subtitleParts.add(
                              'Premium: ${NumberFormat.compact().format(notification.premium)}',
                            );
                          }
                          if (notification.volume != null) {
                            subtitleParts.add(
                              'Vol: ${NumberFormat.compact().format(notification.volume)}',
                            );
                          }
                          if (notification.expirationDate != null) {
                            subtitleParts
                                .add('Exp: ${notification.expirationDate}');
                          }
                          if (notification.flags.isNotEmpty) {
                            subtitleParts
                                .add('Flags: ${notification.flags.join(', ')}');
                          }

                          return Card(
                            elevation: 0,
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant,
                              ),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: sentimentColor.withValues(
                                  alpha: 0.15,
                                ),
                                child: Text(
                                  notification.symbol.isNotEmpty
                                      ? notification.symbol[0]
                                      : '?',
                                  style: TextStyle(color: sentimentColor),
                                ),
                              ),
                              title: Text(
                                notification.title,
                                style: TextStyle(
                                  fontWeight: notification.read
                                      ? FontWeight.normal
                                      : FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (subtitleParts.isNotEmpty)
                                    Text(subtitleParts.join(' | ')),
                                  Text(
                                    DateFormat('MMM d, h:mm a')
                                        .format(notification.timestamp),
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () {
                                  store.delete(notification.id);
                                },
                              ),
                              onTap: () {
                                store.markAsRead(notification.id);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => OptionsFlowWidget(
                                      initialSymbol: notification.symbol,
                                    ),
                                  ),
                                );
                              },
                            ),
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
      onSelected: (selected) {
        setState(() {
          if (label == 'All') {
            _selectedFilters
              ..clear()
              ..add('All');
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
    );
  }
}
