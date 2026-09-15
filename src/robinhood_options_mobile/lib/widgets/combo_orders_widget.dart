import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/combo_order.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/combo_order_widget.dart';

class ComboOrdersWidget extends StatefulWidget {
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  final List<ComboOrder> comboOrders;
  final List<String> orderFilters;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final GenerativeService generativeService;
  final User? authUser;
  final DocumentReference<User>? userDocRef;

  const ComboOrdersWidget(
    this.brokerageUser,
    this.service,
    this.comboOrders,
    this.orderFilters, {
    super.key,
    required this.analytics,
    required this.observer,
    required this.generativeService,
    this.authUser,
    this.userDocRef,
  });

  @override
  State<ComboOrdersWidget> createState() => _ComboOrdersWidgetState();
}

class _ComboOrdersWidgetState extends State<ComboOrdersWidget> {
  late List<String> orderFilters;
  bool _showAll = false;

  @override
  void initState() {
    super.initState();
    orderFilters = List.from(widget.orderFilters);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final comboOrders = widget.comboOrders;

    final filteredOrders = comboOrders.where((element) {
      if (orderFilters.isEmpty) return true;
      return orderFilters.contains(element.state);
    }).toList();

    filteredOrders.sort(
      (a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
    );

    final netPremiumBalance = filteredOrders.fold<double>(0.0, (total, order) {
      final sign = order.direction == 'credit' ? 1 : -1;
      return total + (order.netAmount * sign);
    });

    final displayCount = _showAll
        ? filteredOrders.length
        : (filteredOrders.length > 3 ? 3 : filteredOrders.length);
    final hasOverflow = filteredOrders.length > 3;

    return SliverStickyHeader(
      header: Material(
        color: theme.scaffoldBackgroundColor,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Combo Orders',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${netPremiumBalance >= 0 ? "+" : "-"}${formatCurrency.format(netPremiumBalance.abs())}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: netPremiumBalance >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: orderFilters.isEmpty,
                      onSelected: (selected) {
                        setState(() {
                          orderFilters.clear();
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Filled'),
                      selected: orderFilters.contains('filled'),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            orderFilters.add('filled');
                          } else {
                            orderFilters.remove('filled');
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Queued / Open'),
                      selected:
                          orderFilters.contains('queued') ||
                          orderFilters.contains('confirmed'),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            orderFilters.addAll([
                              'queued',
                              'confirmed',
                              'unconfirmed',
                            ]);
                          } else {
                            orderFilters.removeWhere(
                              (s) =>
                                  s == 'queued' ||
                                  s == 'confirmed' ||
                                  s == 'unconfirmed',
                            );
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Cancelled'),
                      selected: orderFilters.contains('cancelled'),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            orderFilters.add('cancelled');
                          } else {
                            orderFilters.remove('cancelled');
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index == displayCount) {
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 4.0,
              ),
              child: Center(
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showAll = !_showAll;
                    });
                  },
                  icon: Icon(_showAll ? Icons.expand_less : Icons.expand_more),
                  label: Text(
                    _showAll
                        ? 'Show Less'
                        : 'Show All (${filteredOrders.length})',
                  ),
                ),
              ),
            );
          }

          final order = filteredOrders[index];
          return _buildOrderTile(order, theme);
        }, childCount: displayCount + (hasOverflow ? 1 : 0)),
      ),
    );
  }

  Widget _buildOrderTile(ComboOrder order, ThemeData theme) {
    Color stateColor;
    if (order.isFilled) {
      stateColor = Colors.green;
    } else if (order.isCancelled || order.isRejected) {
      stateColor = Colors.red;
    } else {
      stateColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            Icons.layers,
            color: theme.colorScheme.onPrimaryContainer,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Text(
              order.primarySymbol,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                order.strategyDisplay,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              '${order.quantity.toInt()} pkg • ${order.legs.length} legs • ${order.directionDisplay}',
              style: const TextStyle(fontSize: 12),
            ),
            if (order.createdAt != null)
              Text(
                formatMediumDate.format(order.createdAt!),
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.8,
                  ),
                ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              order.price != null
                  ? formatCurrency.format(order.price)
                  : (order.netAmount > 0
                        ? formatCurrency.format(order.netAmount)
                        : 'Market'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: stateColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: stateColor.withValues(alpha: 0.4)),
              ),
              child: Text(
                order.state.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: stateColor,
                ),
              ),
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ComboOrderWidget(
                widget.brokerageUser,
                widget.service,
                order,
                analytics: widget.analytics,
                observer: widget.observer,
                generativeService: widget.generativeService,
                user: widget.authUser,
                userDocRef: widget.userDocRef,
              ),
            ),
          );
        },
      ),
    );
  }
}
