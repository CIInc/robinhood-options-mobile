import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/forex_order.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'forex_order_widget.dart';

class ForexOrdersWidget extends StatefulWidget {
  const ForexOrdersWidget(
    this.brokerageUser,
    this.service,
    this.orders, {
    super.key,
    required this.analytics,
    required this.observer,
  });

  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  final List<ForexOrder> orders;

  @override
  State<ForexOrdersWidget> createState() => _ForexOrdersWidgetState();
}

class _ForexOrdersWidgetState extends State<ForexOrdersWidget> {
  bool _showAllOrders = false;
  final List<String> orderFilters = <String>[];

  @override
  Widget build(BuildContext context) {
    var orders = widget.orders;
    Map<String, double> runningBalances = {};
    double currentBalance = 0;
    for (var i = orders.length - 1; i >= 0; i--) {
      var order = orders[i];
      if (order.state == 'filled') {
        double orderValue = ((order.averagePrice ?? order.price ?? 0.0) *
                (order.quantity ?? 0.0)) *
            (order.side == "sell" ? 1 : -1);
        currentBalance += orderValue;
      }
      runningBalances[order.id] = currentBalance;
    }

    var filteredOrders = orders
        .where((element) =>
            orderFilters.isEmpty || orderFilters.contains(element.state))
        .toList();

    final displayCount = _showAllOrders
        ? filteredOrders.length
        : (filteredOrders.length > 3 ? 3 : filteredOrders.length);
    final showButton = filteredOrders.length > 3;

    double ordersBalance = 0;
    if (orders.isNotEmpty) {
      ordersBalance = orders
          .where((e) => e.state == 'filled')
          .map((e) =>
              ((e.averagePrice ?? e.price ?? 0.0) * (e.quantity ?? 0.0)) *
              (e.side == "sell" ? 1 : -1))
          .reduce((a, b) => a + b);
    }

    return SliverStickyHeader(
      header: Material(
        child: Container(
          alignment: Alignment.centerLeft,
          child: ListTile(
            title: const Text(
              "Orders",
              style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
                "${formatCompactNumber.format(orders.length)} orders - balance: ${ordersBalance > 0 ? "+" : ordersBalance < 0 ? "-" : ""}${formatCurrency.format(ordersBalance.abs())}"),
            trailing: IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    showDragHandle: true,
                    constraints: const BoxConstraints(maxHeight: 260),
                    builder: (BuildContext context) {
                      return StatefulBuilder(builder:
                          (BuildContext context, StateSetter setModalState) {
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const ListTile(
                              leading: Icon(Icons.filter_list),
                              title: Text(
                                "Filter Orders",
                                style: TextStyle(
                                    fontSize: 20.0,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            SizedBox(
                                height: 56,
                                child: ListView(
                                  padding: const EdgeInsets.all(4.0),
                                  scrollDirection: Axis.horizontal,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: FilterChip(
                                        label: const Text('Confirmed'),
                                        selected:
                                            orderFilters.contains("confirmed"),
                                        onSelected: (bool value) {
                                          setModalState(() {
                                            if (value) {
                                              orderFilters.add("confirmed");
                                            } else {
                                              orderFilters.remove("confirmed");
                                            }
                                          });
                                          setState(() {});
                                        },
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: FilterChip(
                                        label: const Text('Filled'),
                                        selected:
                                            orderFilters.contains("filled"),
                                        onSelected: (bool value) {
                                          setModalState(() {
                                            if (value) {
                                              orderFilters.add("filled");
                                            } else {
                                              orderFilters.remove("filled");
                                            }
                                          });
                                          setState(() {});
                                        },
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: FilterChip(
                                        label: const Text('Cancelled'),
                                        selected:
                                            orderFilters.contains("cancelled"),
                                        onSelected: (bool value) {
                                          setModalState(() {
                                            if (value) {
                                              orderFilters.add("cancelled");
                                            } else {
                                              orderFilters.remove("cancelled");
                                            }
                                          });
                                          setState(() {});
                                        },
                                      ),
                                    ),
                                  ],
                                )),
                          ],
                        );
                      });
                    },
                  );
                }),
          ),
        ),
      ),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index >= displayCount) {
              return Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showAllOrders = !_showAllOrders;
                    });
                  },
                  icon: Icon(
                      _showAllOrders ? Icons.expand_less : Icons.expand_more),
                  label: Text(_showAllOrders
                      ? "Show Less"
                      : "Show All (${filteredOrders.length})"),
                ),
              );
            }
            var order = filteredOrders[index];
            return Card(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: order.side == 'buy'
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.red.withValues(alpha: 0.1),
                      foregroundColor:
                          order.side == 'buy' ? Colors.green : Colors.red,
                      child: Text(order.side == 'buy' ? 'B' : 'S',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    title: Text(
                        "${order.side == 'buy' ? 'Buy' : 'Sell'} ${formatNumber.format(order.quantity)} at ${order.averagePrice != null ? formatCurrency.format(order.averagePrice) : (order.price != null ? formatCurrency.format(order.price) : "Market")}"),
                    subtitle: Text(
                        "${order.state} ${order.updatedAt != null ? formatDate.format(order.updatedAt!) : ''}"),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          (order.averagePrice != null || order.price != null)
                              ? (order.side == "sell" ? "+" : "-") +
                                  formatCurrency.format(
                                      (order.averagePrice ?? order.price!) *
                                          (order.quantity ?? 0))
                              : "",
                          style: const TextStyle(fontSize: 16.0),
                          textAlign: TextAlign.right,
                        ),
                        if (order.state == 'filled')
                          Text(
                            formatCurrency
                                .format(runningBalances[order.id] ?? 0),
                            style: const TextStyle(
                                fontSize: 12.0, color: Colors.grey),
                            textAlign: TextAlign.right,
                          ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ForexOrderWidget(
                            widget.brokerageUser,
                            widget.service,
                            order,
                            analytics: widget.analytics,
                            observer: widget.observer,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
          childCount: displayCount + (showButton ? 1 : 0),
        ),
      ),
    );
  }
}
