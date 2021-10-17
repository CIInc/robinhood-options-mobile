import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:robinhood_options_mobile/model/robinhood_user.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';

final formatCurrency = NumberFormat.simpleCurrency();

class TradeOptionWidget extends StatefulWidget {
  final RobinhoodUser user;
  final OptionAggregatePosition optionPosition;
  TradeOptionWidget(this.user, this.optionPosition);

  @override
  _TradeOptionWidgetState createState() =>
      _TradeOptionWidgetState(user, optionPosition);
}

class _TradeOptionWidgetState extends State<TradeOptionWidget> {
  final RobinhoodUser user;
  final OptionAggregatePosition optionPosition;

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
    var floatBtn = SizedBox(
        width: 340.0,
        child: ElevatedButton.icon(
          label: const Text("Buy"), // ${snapshot.connectionState}
          icon: const Icon(Icons.attach_money),
          onPressed: () {
            return;
          },
        ));
    priceCtl.text = formatCurrency.format(
        optionPosition.optionInstrument!.optionMarketData!.adjustedMarkPrice);
    return Scaffold(
        appBar: AppBar(
          title: Text(
              "Trade ${optionPosition.symbol} \$${optionPosition.averageOpenPrice!.toStringAsFixed(2)} ${optionPosition.legs.first.optionType}"),
        ),
        body: Builder(builder: (context) {
          return ListView(
            padding: const EdgeInsets.all(15.0),
            children: [
              ListTile(
                title: TextField(
                  controller: quantityCtl,
                ),
                subtitle: const Text("Quantity"),
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
