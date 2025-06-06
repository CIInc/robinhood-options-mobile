import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/constants.dart';

import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/option_order.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';

class TradeOptionWidget extends StatefulWidget {
  const TradeOptionWidget(this.user, this.service,
      //this.account,
      {super.key,
      required this.analytics,
      required this.observer,
      this.optionPosition,
      this.optionInstrument,
      this.positionType = "Buy"});

  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser user;
  final IBrokerageService service;
  //final Account account;
  final OptionAggregatePosition? optionPosition;
  final OptionInstrument? optionInstrument;
  final String? positionType;

  @override
  State<TradeOptionWidget> createState() => _TradeOptionWidgetState();
}

class _TradeOptionWidgetState extends State<TradeOptionWidget> {
  String? positionType;

  //String? optionType = "Call";

  //final List<bool> isSelected = [true, false];

  var quantityCtl = TextEditingController(text: '1');
  var priceCtl = TextEditingController();
  var deviceCtl = TextEditingController();

  // Loaded with option_positions parent widget
  //Future<OptionInstrument> futureOptionInstrument;

  _TradeOptionWidgetState();

  @override
  void initState() {
    super.initState();
    positionType = widget.positionType;
    widget.analytics.logScreenView(screenName: 'Trade Option');
  }

  @override
  Widget build(BuildContext context) {
    var floatBtn = SizedBox(
        width: 340.0,
        child: ElevatedButton.icon(
          label: Text(positionType!),
          //isSelected[0] ? "Buy" : "Sell"), // ${snapshot.connectionState}
          icon: const Icon(Icons.attach_money),
          onPressed: () async {
            var accountStore =
                Provider.of<AccountStore>(context, listen: false);
            var orderJson = await widget.service.placeOptionsOrder(
              widget.user,
              accountStore.items[0],
              widget.optionInstrument!,
              positionType == "Buy" ? "buy" : "sell", // side
              "open", //positionEffect
              "debit", //creditOrDebit
              double.parse(priceCtl.text),
              int.parse(quantityCtl.text),
            );

            var newOrder = OptionOrder.fromJson(orderJson);

            // widget.analytics.logPurchase(
            //     currency: widget.optionInstrument!.chainSymbol,
            //     value:
            //         double.parse(priceCtl.text) + int.parse(quantityCtl.text),
            //     transactionId: newOrder.id,
            //     affiliation: positionType);

            if (newOrder.state == "confirmed" ||
                newOrder.state == "unconfirmed") {
              if (context.mounted) {
                Navigator.pop(context);

                ScaffoldMessenger.of(context)
                  ..removeCurrentSnackBar()
                  ..showSnackBar(SnackBar(
                    content: Text(
                        "Order to $positionType ${widget.optionInstrument!.chainSymbol} \$${widget.optionInstrument!.strikePrice} ${widget.optionInstrument!.type} placed."),
                    behavior: SnackBarBehavior.floating,
                  ));
              }
            } else {
              setState(() {
                ScaffoldMessenger.of(context)
                  ..removeCurrentSnackBar()
                  ..showSnackBar(SnackBar(
                    content: Text("Error placing order. $orderJson"),
                    behavior: SnackBarBehavior.floating,
                  ));
              });
            }
          },
        ));
    priceCtl.text =
        widget.optionInstrument!.optionMarketData!.markPrice!.toString();
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
                    '${widget.optionInstrument!.chainSymbol} \$${widget.optionInstrument!.strikePrice} ${widget.optionInstrument!.type}',
                    style: const TextStyle(fontSize: 20.0)),
                Text(
                    formatDate.format(widget.optionInstrument!.expirationDate!),
                    style: const TextStyle(fontSize: 15.0))
              ]),
        ),
        body: Builder(builder: (context) {
          return ListView(
            padding: const EdgeInsets.all(15.0),
            children: [
              ListTile(
                title: const Text("Position Type"),
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
                title: TextField(
                  controller: quantityCtl,
                ),
                subtitle: const Text("Contract"),
              ),
              ListTile(
                title: TextField(
                  controller: priceCtl,
                  //obscureText: true,
                ),
                subtitle: const Text("Price"),
              ),
              Container(
                height: 20,
              ),
              Center(child: floatBtn)
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
