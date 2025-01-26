import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/extensions.dart';
import 'package:robinhood_options_mobile/model/option_order.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/option_order_widget.dart';

final formatDate = DateFormat.yMMMEd(); //.yMEd(); //("yMMMd");
final formatCompactDate = DateFormat("MMMd");
final formatCurrency = NumberFormat.simpleCurrency();
final formatCompactNumber = NumberFormat.compact();

class OptionOrdersWidget extends StatefulWidget {
  const OptionOrdersWidget(
    this.user,
    this.service,
    //this.account,
    this.optionOrders,
    this.orderFilters, {
    super.key,
    required this.analytics,
    required this.observer,
  });

  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser user;
  final IBrokerageService service;
  //final Account account;
  final List<OptionOrder> optionOrders;
  final List<String> orderFilters;

  @override
  State<OptionOrdersWidget> createState() => _OptionOrdersWidgetState();
}

class _OptionOrdersWidgetState extends State<OptionOrdersWidget> {
  //final List<String> orderFilters = <String>["confirmed", "filled"];

  _OptionOrdersWidgetState();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    /* Not a screen but a sub-view used by instrument widget and option instrument widget.
    widget.analytics.logScreenView(
      screenName:
          'OptionOrders/${widget.optionOrders.isNotEmpty ? widget.optionOrders[0].chainSymbol : ''}',
    );
    */
    var optionOrders = widget.optionOrders;
    var orderFilters = widget.orderFilters;
    var optionOrdersPremiumBalance = optionOrders.isNotEmpty
        ? optionOrders
            .map((e) =>
                (e.processedPremium != null ? e.processedPremium! : 0) *
                (e.direction == "credit" ? 1 : -1))
            .reduce((a, b) => a + b) as double
        : 0;

    return SliverStickyHeader(
      header: Material(
          //elevation: 2,
          child: Container(
              //height: 208.0, //60.0,
              //padding: EdgeInsets.symmetric(horizontal: 16.0),
              alignment: Alignment.centerLeft,
              child: ListTile(
                title: const Text(
                  "Option Orders",
                  style: TextStyle(fontSize: 19.0),
                ),
                subtitle: Text(
                    "${formatCompactNumber.format(optionOrders.length)} orders - balance: ${optionOrdersPremiumBalance > 0 ? "+" : optionOrdersPremiumBalance < 0 ? "-" : ""}${formatCurrency.format(optionOrdersPremiumBalance.abs())}"),
                trailing: IconButton(
                    icon: const Icon(Icons.filter_list),
                    onPressed: () {
                      showModalBottomSheet<void>(
                        context: context,
                        showDragHandle: true,
                        constraints: const BoxConstraints(maxHeight: 260),
                        builder: (BuildContext context) {
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                // tileColor:
                                //     Theme.of(context).colorScheme.surface,
                                leading: const Icon(Icons.filter_list),
                                title: const Text(
                                  "Filter Option Orders",
                                  style: TextStyle(fontSize: 19.0),
                                ),
                                /*
                                  trailing: TextButton(
                                      child: const Text("APPLY"),
                                      onPressed: () => Navigator.pop(context))*/
                              ),
                              orderFilterWidget,
                            ],
                          );
                        },
                      );
                    }),
              ))),
      sliver: SliverList(
        // delegate: SliverChildListDelegate(widgets),
        delegate: SliverChildBuilderDelegate((BuildContext context, int index) {
          if ( //optionOrders[index] == null ||
              (orderFilters.isNotEmpty &&
                  !orderFilters.contains(optionOrders[index].state))) {
            return Container();
          }
          var optionOrder = optionOrders[index];
          var subtitle =
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                "${optionOrder.state.capitalize()} ${formatDate.format(optionOrder.updatedAt!)}"),
            if (optionOrder.optionEvents != null) ...[
              Text(
                "${optionOrder.optionEvents!.first.type == "expiration" ? "Expired" : (optionOrder.optionEvents!.first.type == "assignment" ? "Assigned" : (optionOrder.optionEvents!.first.type == "exercise" ? "Exercised" : optionOrder.optionEvents!.first.type))} ${formatCompactDate.format(optionOrder.optionEvents!.first.eventDate!)} at ${optionOrder.optionEvents!.first.underlyingPrice != null ? formatCurrency.format(optionOrder.optionEvents!.first.underlyingPrice) : ""}",
                //style: TextStyle(fontSize: 16.0)
              )
            ]
          ]);

          return Card(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: CircleAvatar(
                    //backgroundImage: AssetImage(user.profilePicture),
                    /*
                    backgroundColor: optionOrder.optionEvents != null
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.secondary,
                        */
                    child: optionOrder.optionEvents != null
                        ? const Icon(Icons.check)
                        : Text('${optionOrder.quantity!.round()}',
                            style: const TextStyle(fontSize: 17))),
                title: Text(
                    "${optionOrders[index].chainSymbol} \$${formatCompactNumber.format(optionOrders[index].legs.first.strikePrice)} ${optionOrders[index].strategy} ${formatCompactDate.format(optionOrders[index].legs.first.expirationDate!)}"), // , style: TextStyle(fontSize: 18.0)),
                subtitle: subtitle,
                trailing: Wrap(spacing: 8, children: [
                  Text(
                    (optionOrders[index].direction == "credit" ? "+" : "-") +
                        (optionOrders[index].processedPremium != null
                            ? formatCurrency
                                .format(optionOrders[index].processedPremium)
                            : ""),
                    style: const TextStyle(fontSize: 18.0),
                    textAlign: TextAlign.right,
                  )
                ]),

                /*Wrap(
            spacing: 12,
            children: [
              Column(children: [
                Text(
                  "${formatCurrency.format(gainLoss)}\n${formatPercentage.format(gainLossPercent)}",
                  style: const TextStyle(fontSize: 15.0),
                  textAlign: TextAlign.right,
                ),
                Icon(
                    gainLossPerContract > 0
                        ? Icons.trending_up
                        : (gainLossPerContract < 0
                            ? Icons.trending_down
                            : Icons.trending_flat),
                    color: (gainLossPerContract > 0
                        ? Colors.green
                        : (gainLossPerContract < 0 ? Colors.red : Colors.grey)))
              ]),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "${formatCurrency.format(marketValue)}",
                    style: const TextStyle(fontSize: 18.0),
                    textAlign: TextAlign.right,
                  ),
                ],
              )
            ],
          ),*/
                isThreeLine: optionOrder.optionEvents != null,
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => OptionOrderWidget(
                                widget.user,
                                widget.service,
                                optionOrders[index],
                                analytics: widget.analytics,
                                observer: widget.observer,
                              )));
                },
              ),
            ],
          ));
        }, childCount: optionOrders.length),
      ),
    );
  }

  Widget get orderFilterWidget {
    var orderFilters = widget.orderFilters;
    return SizedBox(
        height: 56,
        child: ListView.builder(
          padding: const EdgeInsets.all(4.0),
          scrollDirection: Axis.horizontal,
          itemBuilder: (context, index) {
            return Row(children: [
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: FilterChip(
                  //avatar: const Icon(Icons.history_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('Confirmed'),
                  selected: orderFilters.contains("confirmed"),
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        orderFilters.add("confirmed");
                      } else {
                        orderFilters.removeWhere((String name) {
                          return name == "confirmed";
                        });
                      }
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: FilterChip(
                  //avatar: const Icon(Icons.history_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('Filled'),
                  selected: orderFilters.contains("filled"),
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        orderFilters.add("filled");
                      } else {
                        orderFilters.removeWhere((String name) {
                          return name == "filled";
                        });
                      }
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: FilterChip(
                  //avatar: const Icon(Icons.history_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('Cancelled'),
                  selected: orderFilters.contains("cancelled"),
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        orderFilters.add("cancelled");
                      } else {
                        orderFilters.removeWhere((String name) {
                          return name == "cancelled";
                        });
                      }
                    });
                  },
                ),
              ),
            ]);
          },
          itemCount: 1,
        ));
  }
}
