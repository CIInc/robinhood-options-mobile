import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:robinhood_options_mobile/model/robinhood_user.dart';
import 'package:robinhood_options_mobile/model/option_position.dart';

final formatCurrency = new NumberFormat.simpleCurrency();

class TradeOptionWidget extends StatefulWidget {
  final RobinhoodUser user;
  final OptionPosition optionPosition;
  TradeOptionWidget(this.user, this.optionPosition);

  @override
  _TradeOptionWidgetState createState() =>
      _TradeOptionWidgetState(user, optionPosition);
}

class _TradeOptionWidgetState extends State<TradeOptionWidget> {
  final RobinhoodUser user;
  final OptionPosition optionPosition;

  var quantityCtl = TextEditingController(text: '1');
  var priceCtl = TextEditingController();
  var deviceCtl = TextEditingController();

  // Loaded with option_positions parent widget
  //Future<OptionInstrument> futureOptionInstrument;

  _TradeOptionWidgetState(this.user, this.optionPosition);

  @override
  void initState() {
    super.initState();
    // futureOptionInstrument = RobinhoodService.downloadOptionInstrument(this.user, optionPosition);
  }

  @override
  Widget build(BuildContext context) {
    var floatBtn = new SizedBox(
        width: 340.0,
        child: ElevatedButton.icon(
          label: new Text("Buy"), // ${snapshot.connectionState}
          icon: new Icon(Icons.attach_money),
          onPressed: () {
            return null;
          },
        ));
    priceCtl.text =
        '${formatCurrency.format(optionPosition.optionInstrument!.optionMarketData!.adjustedMarkPrice)}';
    return new Scaffold(
        appBar: new AppBar(
          title: new Text(
              "Trade ${optionPosition.chainSymbol} \$${optionPosition.averagePrice!.toStringAsFixed(2)} ${optionPosition.type.toUpperCase()}"),
        ),
        body: new Builder(builder: (context) {
          return new ListView(
            padding: const EdgeInsets.all(15.0),
            children: [
              new ListTile(
                title: new TextField(
                  controller: quantityCtl,
                ),
                subtitle: Text("Quantity"),
              ),
              new ListTile(
                title: new TextField(
                  controller: priceCtl,
                  //obscureText: true,
                ),
                subtitle: Text("Price"),
              ),
              new Container(
                height: 20,
              ),
              new Center(child: floatBtn)
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
