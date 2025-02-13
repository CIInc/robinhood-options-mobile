import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument_order.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';

final formatDate = DateFormat("yMMMd");
final formatCurrency = NumberFormat.simpleCurrency();
final formatPercentage = NumberFormat.decimalPercentPattern(decimalDigits: 2);

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

  // Loaded with option_positions parent widget
  //Future<OptionInstrument> futureOptionInstrument;

  _TradeInstrumentWidgetState();

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

            var orderJson = await widget.service.placeInstrumentOrder(
              widget.user,
              accountStore.items[0],
              widget.instrument!,
              widget.instrument!.symbol,
              positionType == "Buy" ? "buy" : "sell", // side
              double.parse(priceCtl.text),
              int.parse(quantityCtl.text),
            );
            debugPrint(orderJson);

            var newOrder = InstrumentOrder.fromJson(orderJson);

            // widget.analytics.logPurchase(
            //     currency: widget.instrument!.chainSymbol,
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
                          "Order to $positionType ${quantityCtl.text} shares of ${widget.instrument!.symbol} at \$${priceCtl.text} placed.")));
              }
            } else {
              setState(() {
                ScaffoldMessenger.of(context)
                  ..removeCurrentSnackBar()
                  ..showSnackBar(SnackBar(
                      content: Text("Error placing order. $orderJson")));
              });
            }
          },
        ));
    priceCtl.text = (widget.instrument!.quoteObj!.lastExtendedHoursTradePrice ??
            widget.instrument!.quoteObj!.lastTradePrice)
        .toString();
    return Scaffold(
        appBar: AppBar(
          title: Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              //runAlignment: WrapAlignment.end,
              //alignment: WrapAlignment.end,
              spacing: 20,
              //runSpacing: 5,
              children: [
                Text('${widget.instrument!.symbol} ${widget.instrument!.type}',
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
                subtitle: const Text("Shares"),
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
