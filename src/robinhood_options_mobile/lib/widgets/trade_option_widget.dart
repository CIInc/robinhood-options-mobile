import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';

import 'package:robinhood_options_mobile/model/robinhood_user.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';

final formatDate = DateFormat("yMMMd");
final formatCurrency = NumberFormat.simpleCurrency();
final formatPercentage = NumberFormat.decimalPercentPattern(decimalDigits: 2);

class TradeOptionWidget extends StatefulWidget {
  final RobinhoodUser user;
  final OptionAggregatePosition? optionPosition;
  final OptionInstrument? optionInstrument;
  TradeOptionWidget(this.user, {this.optionPosition, this.optionInstrument});

  @override
  _TradeOptionWidgetState createState() =>
      _TradeOptionWidgetState(user, optionPosition, optionInstrument);
}

class _TradeOptionWidgetState extends State<TradeOptionWidget> {
  final RobinhoodUser user;
  final OptionAggregatePosition? optionPosition;
  OptionInstrument? optionInstrument;

  //String? actionFilter = "Buy";
  //String? typeFilter = "Call";

  final List<bool> isSelected = [true, false];

  var quantityCtl = TextEditingController(text: '1');
  var priceCtl = TextEditingController();
  var deviceCtl = TextEditingController();

  // Loaded with option_positions parent widget
  //Future<OptionInstrument> futureOptionInstrument;

  _TradeOptionWidgetState(
      this.user, this.optionPosition, this.optionInstrument);

  @override
  void initState() {
    super.initState();
    if (this.optionPosition != null && this.optionInstrument == null) {
      optionInstrument = this.optionPosition!.optionInstrument;
    }
    // futureOptionInstrument = RobinhoodService.downloadOptionInstrument(this.user, optionPosition);
  }

  @override
  Widget build(BuildContext context) {
    var floatBtn = SizedBox(
        width: 340.0,
        child: ElevatedButton.icon(
          label: Text(
              isSelected[0] ? "Buy" : "Sell"), // ${snapshot.connectionState}
          icon: const Icon(Icons.attach_money),
          onPressed: () {
            return;
          },
        ));
    priceCtl.text =
        formatCurrency.format(optionInstrument!.optionMarketData!.markPrice);
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
                    'Trade ${optionInstrument!.chainSymbol} \$${optionInstrument!.strikePrice} ${optionInstrument!.type}',
                    style: const TextStyle(fontSize: 20.0)),
                Text('${formatDate.format(optionInstrument!.expirationDate!)}',
                    style: const TextStyle(fontSize: 16.0))
              ]),
        ),
        body: Builder(builder: (context) {
          return ListView(
            padding: const EdgeInsets.all(15.0),
            children: [
              ListTile(
                title: Text("Position Type"),
                trailing: ToggleButtons(
                  children: <Widget>[
                    Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Row(
                          children: const [
                            Text(
                              'Buy',
                              style: TextStyle(fontSize: 16),
                            )
                          ],
                        )),
                    Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Row(
                        children: const [
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
                  onPressed: (int index) {
                    setState(() {
                      for (int buttonIndex = 0;
                          buttonIndex < isSelected.length;
                          buttonIndex++) {
                        if (buttonIndex == index) {
                          isSelected[buttonIndex] = true;
                        } else {
                          isSelected[buttonIndex] = false;
                        }
                      }
                      /*
          if (index == 0 && futureCallOptionInstruments == null) {
            futureCallOptionInstruments =
                RobinhoodService.downloadOptionInstruments(
                    user, instrument, null, 'call');
          } else if (index == 1 && futurePutOptionInstruments == null) {
            futurePutOptionInstruments =
                RobinhoodService.downloadOptionInstruments(
                    user, instrument, null, 'put');
          }
          */
                    });
                  },
                  isSelected: isSelected,
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
