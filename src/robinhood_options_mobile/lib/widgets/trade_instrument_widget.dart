import 'dart:convert';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument_order.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';

class TradeInstrumentWidget extends StatefulWidget {
  const TradeInstrumentWidget(this.user, this.service,
      //this.account,
      {super.key,
      required this.analytics,
      required this.observer,
      this.stockPosition,
      this.instrument,
      this.positionType = "Buy"});

  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser user;
  final IBrokerageService service;
  //final Account account;
  final InstrumentPosition? stockPosition;
  final Instrument? instrument;
  final String? positionType;

  @override
  State<TradeInstrumentWidget> createState() => _TradeInstrumentWidgetState();
}

class _TradeInstrumentWidgetState extends State<TradeInstrumentWidget> {
  String? positionType;

  //String? optionType = "Call";

  //final List<bool> isSelected = [true, false];

  var quantityCtl = TextEditingController(text: '1');
  var priceCtl = TextEditingController();
  var deviceCtl = TextEditingController();

  bool placingOrder = false;

  // Loaded with option_positions parent widget
  //Future<OptionInstrument> futureOptionInstrument;

  _TradeInstrumentWidgetState();

  @override
  void initState() {
    super.initState();
    positionType = widget.positionType;
    widget.analytics.logScreenView(screenName: 'Trade Option');
    priceCtl.text = (widget.instrument!.quoteObj!.lastExtendedHoursTradePrice ??
            widget.instrument!.quoteObj!.lastTradePrice)
        .toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              //runAlignment: WrapAlignment.end,
              //alignment: WrapAlignment.end,
              spacing: 20,
              //runSpacing: 5,
              children: [
                Text(
                    'Trade ${widget.instrument!.symbol} stock', //  ${widget.instrument!.type.toUpperCase()}
                    style: const TextStyle(fontSize: 20.0)),
                // Text(
                //     formatDate.format(widget.instrument!.expirationDate!),
                //     style: const TextStyle(fontSize: 15.0))
              ]),
        ),
        body: Builder(builder: (context) {
          return ListView(
            padding: const EdgeInsets.all(15.0),
            children: [
              ListTile(
                title: const Text("Trade Type"),
                trailing: ToggleButtons(
                  onPressed: (int index) {
                    setState(() {
                      positionType = index == 0 ? "Buy" : "Sell";
                      /*
                      for (int buttonIndex = 0;
                          buttonIndex < isSelected.length;
                          buttonIndex++) {
                        if (buttonIndex == index) {
                          positionType = buttonIndex
                          isSelected[buttonIndex] = true;
                        } else {
                          isSelected[buttonIndex] = false;
                        }
                      }
                      */
                    });
                  },
                  isSelected: [
                    positionType == "Buy",
                    positionType == "Sell"
                  ], //isSelected,
                  children: const <Widget>[
                    Padding(
                        padding: EdgeInsets.all(14.0),
                        child: Row(
                          children: [
                            Text(
                              'Buy',
                              style: TextStyle(fontSize: 16),
                            )
                          ],
                        )),
                    Padding(
                      padding: EdgeInsets.all(14.0),
                      child: Row(
                        children: [
                          Text(
                            'Sell',
                            style: TextStyle(fontSize: 16),
                          )
                        ],
                      ),
                    ),
                    //Icon(Icons.ac_unit),
                    //Icon(Icons.call),
                    //Icon(Icons.cake),
                  ],
                ),
              ),
              ListTile(
                title: const Text("Shares"),
                trailing: SizedBox(
                  width: 120,
                  child: TextField(
                    controller: quantityCtl,
                    keyboardType:
                        TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(fontSize: 21),
                    textAlign: TextAlign.right,
                  ),
                ),
                // subtitle: const Text("Shares"),
              ),
              ListTile(
                title: const Text("Limit Price"),
                trailing: SizedBox(
                  width: 120,
                  child: TextField(
                    controller: priceCtl,
                    keyboardType:
                        TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(fontSize: 21),
                    textAlign: TextAlign.right,
                    //obscureText: true,
                  ),
                ),
                // subtitle: const Text("Price"),
              ),
              Container(
                height: 20,
              ),
              Center(
                  child: SizedBox(
                      width: 340.0,
                      child: FilledButton.icon(
                        label: Text(
                          "Place Order", // positionType!,
                          style: TextStyle(fontSize: 19),
                        ),
                        //isSelected[0] ? "Buy" : "Sell"), // ${snapshot.connectionState}
                        icon: placingOrder
                            ? SizedBox(
                                width: 19,
                                height: 19,
                                child: const CircularProgressIndicator())
                            : null, //const Icon(Icons.send, size: 19),
                        onPressed: placingOrder
                            ? null
                            : () async {
                                setState(() {
                                  placingOrder = true;
                                });
                                var accountStore = Provider.of<AccountStore>(
                                    context,
                                    listen: false);

                                var orderJson =
                                    await widget.service.placeInstrumentOrder(
                                  widget.user,
                                  accountStore.items[0],
                                  widget.instrument!,
                                  widget.instrument!.symbol,
                                  positionType == "Buy"
                                      ? "buy"
                                      : "sell", // side
                                  double.parse(priceCtl.text),
                                  int.parse(quantityCtl.text),
                                );
                                debugPrint(orderJson.body);
                                if (orderJson.statusCode != 200 &&
                                    orderJson.statusCode != 201) {
                                  setState(() {
                                    placingOrder = false;
                                  });
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context)
                                      ..removeCurrentSnackBar()
                                      ..showSnackBar(SnackBar(
                                        showCloseIcon: true,
                                        duration: const Duration(days: 1),
                                        // action: SnackBarAction(
                                        //   label: 'Ok',
                                        //   onPressed: () {},
                                        // ),
                                        content:
                                            Text(jsonEncode(orderJson.body)),
                                        behavior: SnackBarBehavior.floating,
                                      ));
                                  }
                                } else {
                                  var newOrder = InstrumentOrder.fromJson(
                                      jsonDecode(orderJson.body));

                                  // widget.analytics.logPurchase(
                                  //     currency: widget.instrument!.chainSymbol,
                                  //     value:
                                  //         double.parse(priceCtl.text) + int.parse(quantityCtl.text),
                                  //     transactionId: newOrder.id,
                                  //     affiliation: positionType);
                                  placingOrder = false;

                                  if (newOrder.state == "confirmed" ||
                                      newOrder.state == "queued" ||
                                      newOrder.state == "unconfirmed") {
                                    if (context.mounted) {
                                      Navigator.pop(context);

                                      ScaffoldMessenger.of(context)
                                        ..removeCurrentSnackBar()
                                        ..showSnackBar(SnackBar(
                                          duration: const Duration(days: 1),
                                          showCloseIcon: true,
                                          // action: SnackBarAction(
                                          //   label: 'Ok',
                                          //   onPressed: () {},
                                          // ),
                                          content: Text(
                                              "Order to $positionType ${quantityCtl.text} shares of ${widget.instrument!.symbol} at \$${priceCtl.text} ${newOrder.state}."),
                                          behavior: SnackBarBehavior.floating,
                                        ));
                                    }
                                  } else {
                                    setState(() {
                                      ScaffoldMessenger.of(context)
                                        ..removeCurrentSnackBar()
                                        ..showSnackBar(SnackBar(
                                          content: Text("Error placing order."),
                                          behavior: SnackBarBehavior.floating,
                                        ));
                                    });
                                  }
                                }
                              },
                      )))
            ],
          );
        })
        /*
        body: new FutureBuilder(
            future: futureOptionPosition,
            builder: (context, AsyncSnapshot<OptionPosition> snapshot) {
              if (snapshot.hasData) {
                return _buildPosition(snapshot.data);
              } else if (snapshot.hasError) {
                print("${snapshot.error}");
                return Text("${snapshot.error}");
              }
              // By default, show a loading spinner
              return Center(
                child: CircularProgressIndicator(),
              );
            }));
            */
        );
  }
}
