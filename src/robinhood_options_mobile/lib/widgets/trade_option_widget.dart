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
  final String? positionType;

  const TradeOptionWidget(this.user,
      {Key? key,
      this.optionPosition,
      this.optionInstrument,
      this.positionType = "Buy"})
      : super(key: key);

  @override
  _TradeOptionWidgetState createState() => _TradeOptionWidgetState();
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
    // futureOptionInstrument = RobinhoodService.downloadOptionInstrument(this.user, optionPosition);
  }

  @override
  Widget build(BuildContext context) {
    var floatBtn = SizedBox(
        width: 340.0,
        child: ElevatedButton.icon(
          label: Text(positionType!),
          //isSelected[0] ? "Buy" : "Sell"), // ${snapshot.connectionState}
          icon: const Icon(Icons.attach_money),
          onPressed: () {
            return;
          },
        ));
    priceCtl.text = formatCurrency
        .format(widget.optionInstrument!.optionMarketData!.markPrice);
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
                    ] //isSelected,
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
