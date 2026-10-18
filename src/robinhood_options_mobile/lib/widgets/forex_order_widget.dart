import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/forex_order.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';

class ForexOrderWidget extends StatefulWidget {
  const ForexOrderWidget(
    this.brokerageUser,
    this.service,
    this.order, {
    super.key,
    required this.analytics,
    required this.observer,
  });

  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  final ForexOrder order;

  @override
  State<ForexOrderWidget> createState() => _ForexOrderWidgetState();
}

class _ForexOrderWidgetState extends State<ForexOrderWidget> {
  late ForexOrder order;

  @override
  void initState() {
    super.initState();
    order = widget.order;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              title: Text(
                  "${order.side == 'buy' ? 'Buy' : 'Sell'} ${order.currencyPairId}"),
              pinned: true,
            ),
            SliverList(
              delegate: SliverChildListDelegate(
                [
                  Card(
                    margin: const EdgeInsets.all(10),
                    child: Column(
                      children: [
                        ListTile(
                          title: const Text("State"),
                          trailing: Text(
                            order.state ?? "",
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                        if (order.averagePrice != null)
                          ListTile(
                            title: const Text("Average Price"),
                            trailing: Text(
                              formatCurrency.format(order.averagePrice),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        if (order.price != null)
                          ListTile(
                            title: const Text("Price"),
                            trailing: Text(
                              formatCurrency.format(order.price),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        if (order.quantity != null)
                          ListTile(
                            title: const Text("Quantity"),
                            trailing: Text(
                              formatCompactNumber.format(order.quantity),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        if (order.cumulativeQuantity != null)
                          ListTile(
                            title: const Text("Filled Quantity"),
                            trailing: Text(
                              formatCompactNumber
                                  .format(order.cumulativeQuantity),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        if (order.quantity != null &&
                            (order.averagePrice != null || order.price != null))
                          ListTile(
                            title: const Text("Total Value"),
                            trailing: Text(
                              formatCurrency.format((order.quantity ?? 0) *
                                  (order.averagePrice ?? order.price ?? 0)),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        if (order.fees != null)
                          ListTile(
                            title: const Text("Fees"),
                            trailing: Text(
                              formatCurrency.format(order.fees),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        if (order.type != null)
                          ListTile(
                            title: const Text("Type"),
                            trailing: Text(
                              order.type!,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        if (order.timeInForce != null)
                          ListTile(
                            title: const Text("Time in Force"),
                            trailing: Text(
                              order.timeInForce!,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        if (order.createdAt != null)
                          ListTile(
                            title: const Text("Created"),
                            trailing: Text(
                              DateFormat.yMMMd()
                                  .add_jm()
                                  .format(order.createdAt!),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        if (order.updatedAt != null)
                          ListTile(
                            title: const Text("Updated"),
                            trailing: Text(
                              DateFormat.yMMMd()
                                  .add_jm()
                                  .format(order.updatedAt!),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (order.cancel != null ||
                      (order.state == 'confirmed' || order.state == 'queued'))
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white),
                        onPressed: _confirmCancelOrder,
                        child: const Text("Cancel Order"),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    try {
      var orders = await widget.service.getForexOrders(widget.brokerageUser);
      var updatedOrder = orders.firstWhere((element) => element.id == order.id,
          orElse: () => order);
      setState(() {
        order = updatedOrder;
      });
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _confirmCancelOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cancel Order"),
        content: const Text("Are you sure you want to cancel this order?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Yes"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _cancelOrder();
    }
  }

  Future<void> _cancelOrder() async {
    if (order.cancel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Order cannot be cancelled at this time."),
        ),
      );
      return;
    }
    try {
      final result =
          await widget.service.cancelOrder(widget.brokerageUser, order.cancel!);
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Order cancelled successfully")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to cancel order: $e")),
      );
    }
  }
}
