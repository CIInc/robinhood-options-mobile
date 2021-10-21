import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/option_order.dart';

import 'package:robinhood_options_mobile/model/option_position.dart';
import 'package:robinhood_options_mobile/model/robinhood_user.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';
import 'package:robinhood_options_mobile/widgets/trade_option_widget.dart';

final formatDate = DateFormat("yMMMd");
final formatCompactDate = DateFormat("MMMd");
final formatCurrency = NumberFormat.simpleCurrency();
final formatPercentage = NumberFormat.decimalPercentPattern(decimalDigits: 2);
final formatNumber = NumberFormat("0.####");
final formatCompactNumber = NumberFormat.compact();

class OptionOrderWidget extends StatefulWidget {
  final RobinhoodUser user;
  final OptionOrder optionOrder;
  OptionOrderWidget(this.user, this.optionOrder);

  @override
  _OptionOrderWidgetState createState() =>
      _OptionOrderWidgetState(user, optionOrder);
}

class _OptionOrderWidgetState extends State<OptionOrderWidget> {
  final RobinhoodUser user;
  final OptionOrder optionOrder;
  late Future<Quote> futureQuote;
  late Future<Instrument> futureInstrument;

  // Loaded with option_positions parent widget
  //Future<OptionInstrument> futureOptionInstrument;

  _OptionOrderWidgetState(this.user, this.optionOrder);

  @override
  void initState() {
    super.initState();
    // futureOptionInstrument = RobinhoodService.downloadOptionInstrument(this.user, optionOrder);
    futureQuote = RobinhoodService.getQuote(user, optionOrder.chainSymbol);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder(
          future: futureQuote,
          builder: (context, AsyncSnapshot<Quote> snapshot) {
            if (snapshot.hasData) {
              var quote = snapshot.data!;
              futureInstrument = RobinhoodService.getInstrument(
                  user, snapshot.data!.instrument);
              return FutureBuilder(
                  future: futureInstrument,
                  builder:
                      (context, AsyncSnapshot<Instrument> instrumentSnapshot) {
                    if (instrumentSnapshot.hasData) {
                      var instrument = instrumentSnapshot.data!;
                      instrument.quoteObj = quote;
                      return _buildPage(instrument);
                    } else if (instrumentSnapshot.hasError) {
                      print("${instrumentSnapshot.error}");
                      return Text("${instrumentSnapshot.error}");
                    }
                    return Container();
                  });
            }
            return Container();
          }),
      /*
        floatingActionButton: (user != null && user.userName != null)
            ? FloatingActionButton(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => TradeOptionWidget(user,
                            optionOrder: optionOrder))),
                tooltip: 'Trade',
                child: const Icon(Icons.shopping_cart),
              )
            : null*/
    );
  }

  Widget _buildPage(Instrument instrument) {
    final DateTime today =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final int dte =
        optionOrder.legs.first.expirationDate!.difference(today).inDays;
    final DateTime createdAt = DateTime(optionOrder.createdAt!.year,
        optionOrder.createdAt!.month, optionOrder.createdAt!.day);
    final int originalDte =
        optionOrder.legs.first.expirationDate!.difference(createdAt).inDays;
    return CustomScrollView(slivers: [
      SliverAppBar(
        //title: Text(instrument.symbol), // Text('${optionOrder.symbol} \$${optionOrder.optionInstrument!.strikePrice} ${optionOrder.strategy.split('_').first} ${optionOrder.optionInstrument!.type.toUpperCase()}')
        expandedHeight: 160.0,
        flexibleSpace: FlexibleSpaceBar(
            background: const FlutterLogo(),
            title: SingleChildScrollView(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: const [SizedBox(height: 70)]),
                  Wrap(
                      crossAxisAlignment: WrapCrossAlignment.end,
                      //runAlignment: WrapAlignment.end,
                      //alignment: WrapAlignment.end,
                      spacing: 5,
                      //runSpacing: 5,
                      children: [
                        Text(
                            "${optionOrder.chainSymbol} \$${formatCompactNumber.format(optionOrder.legs.first.strikePrice)} ${optionOrder.strategy}",
                            style: const TextStyle(fontSize: 20.0)),
                        Text(
                            '${formatDate.format(optionOrder.legs.first.expirationDate!)}',
                            style: const TextStyle(fontSize: 15.0))
                      ]),
                  /*
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Container(
                        width: 10,
                      ),
                      Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 70,
                              child: Text(
                                "Strategy",
                                style: TextStyle(fontSize: 10.0),
                              ),
                            )
                          ]),
                      Container(
                        width: 5,
                      ),
                      SizedBox(
                          width: 115,
                          child: Text(
                              "${optionOrder.openingStrategy} ${optionOrder.type}",
                              style: const TextStyle(fontSize: 12.0),
                              textAlign: TextAlign.right)),
                      Container(
                        width: 10,
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Container(
                        width: 10,
                      ),
                      Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 70,
                              child: Text(
                                "Contracts",
                                style: TextStyle(fontSize: 10.0),
                              ),
                            )
                          ]),
                      Container(
                        width: 5,
                      ),
                      SizedBox(
                          width: 115,
                          child: Text(
                              "${optionOrder.direction == "debit" ? "+" : "-"}${formatCompactNumber.format(optionOrder.quantity)}",
                              style: const TextStyle(fontSize: 12.0),
                              textAlign: TextAlign.right)),
                      Container(
                        width: 10,
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Container(
                        width: 10,
                      ),
                      Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: const [
                            SizedBox(
                              width: 70,
                              child: Text(
                                "State",
                                style: TextStyle(fontSize: 10.0),
                              ),
                            )
                          ]),
                      Container(
                        width: 5,
                      ),
                      SizedBox(
                          width: 115,
                          child: Text("${optionOrder.state}",
                              style: const TextStyle(fontSize: 12.0),
                              textAlign: TextAlign.right)),
                      Container(
                        width: 10,
                      ),
                    ],
                  ),
                  */
                ]))),
        pinned: true,
        /*
        actions: <Widget>[
          IconButton(
              icon: const Icon(Icons.shopping_cart),
              tooltip: 'Trade',
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => TradeOptionWidget(user,
                          optionOrder: optionOrder))))
        ],*/
      ),
      /*
      SliverToBoxAdapter(
          child: Align(alignment: Alignment.center, child: buildOverview())),
          */

      SliverToBoxAdapter(
          child: Card(
              child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
              title:
                  const Text("Order Detail", style: TextStyle(fontSize: 20))),
          ListTile(
            title: const Text("Opening Strategy"),
            trailing: Text(
              optionOrder.openingStrategy ?? "",
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Closing Strategy"),
            trailing: Text(
              optionOrder.closingStrategy ?? "",
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Created"),
            trailing: Text(
              formatDate.format(optionOrder.createdAt!),
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Updated"),
            trailing: Text(
              formatDate.format(optionOrder.updatedAt!),
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Direction"),
            trailing: Text(
              optionOrder.direction,
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Quantity"),
            trailing: Text(
              formatCompactNumber.format(optionOrder.quantity),
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Processed Quantity"),
            trailing: Text(
              formatCompactNumber.format(optionOrder.processedQuantity),
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Cancelled Quantity"),
            trailing: Text(
              formatCompactNumber.format(optionOrder.canceledQuantity),
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Pending Quantity"),
            trailing: Text(
              formatCompactNumber.format(optionOrder.pendingQuantity),
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Premium"),
            trailing: Text(
              formatCurrency.format(optionOrder.premium),
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Processed Premium"),
            trailing: Text(
              formatCurrency.format(optionOrder.processedPremium),
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Price"),
            trailing: Text(
              formatCurrency.format(optionOrder.price),
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Stop Price"),
            trailing: Text(
              optionOrder.stopPrice != null
                  ? formatCurrency.format(optionOrder.stopPrice)
                  : "-",
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("State"),
            trailing: Text(
              optionOrder.state,
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Time in Force"),
            trailing: Text(
              optionOrder.timeInForce,
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Trigger"),
            trailing: Text(
              optionOrder.trigger,
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Type"),
            trailing: Text(
              optionOrder.type,
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Response Category"),
            trailing: Text(
              optionOrder.responseCategory ?? "",
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Cancel Url"),
            trailing: Text(
              optionOrder.cancelUrl ?? "",
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ))),
      SliverToBoxAdapter(
          child: Card(
              child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _buildLegs(optionOrder).toList(),
      ))),
      SliverToBoxAdapter(
        child: _buildStockView(instrument),
      ),
    ]);
  }

  Iterable<Widget> _buildLegs(OptionOrder optionOrder) sync* {
    for (int i = 0; i < optionOrder.legs.length; i++) {
      var leg = optionOrder.legs[i];
      yield ListTile(
          title: Text("Leg ${i + 1}", style: TextStyle(fontSize: 20)));
      // yield Text("Leg ${i + 1}", style: TextStyle(fontSize: 20));
      yield ListTile(
        title: const Text("Expiration Date"),
        trailing: Text(formatDate.format(leg.expirationDate!),
            style: const TextStyle(fontSize: 18)),
      );
      yield ListTile(
        title: const Text("Position Type"),
        trailing:
            Text("${leg.positionType}", style: const TextStyle(fontSize: 18)),
      );
      yield ListTile(
        title: const Text("Position Effect"),
        trailing:
            Text("${leg.positionEffect}", style: const TextStyle(fontSize: 18)),
      );
      yield ListTile(
        title: const Text("Option Type"),
        trailing: Text(leg.optionType, style: const TextStyle(fontSize: 18)),
      );
      yield ListTile(
        title: const Text("Strike Price"),
        trailing: Text("${formatCurrency.format(leg.strikePrice)}",
            style: const TextStyle(fontSize: 18)),
      );
      yield ListTile(
        title: const Text("Ratio Quantity"),
        trailing:
            Text("${leg.ratioQuantity}", style: const TextStyle(fontSize: 18)),
      );
    }
  }

  /*
  Card buildOverview() {
    return Card(
        child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            TextButton(
                child: Text(optionOrder.direction == "debit"
                    ? "BUY"
                    : "BUY TO CLOSE"),
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => TradeOptionWidget(user,
                            optionOrder: optionOrder,
                            positionType: "Buy")))),
            TextButton(
                child: Text(optionOrder.direction == "debit"
                    ? "SELL"
                    : "SELL TO OPEN"),
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => TradeOptionWidget(user,
                            optionOrder: optionOrder,
                            positionType: "Sell")))),
            const SizedBox(width: 8),
          ],
        ),
      ],
    ));
  }
  */

  Widget _buildStockView(Instrument instrument) {
    return Card(
        child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ListTile(
          // leading: const Icon(Icons.album),
          title: Text('${instrument.simpleName}'),
          subtitle: Text(instrument.name),
          trailing: Wrap(
            spacing: 8,
            children: [
              Icon(
                  instrument.quoteObj!.changeToday > 0
                      ? Icons.trending_up
                      : (instrument.quoteObj!.changeToday < 0
                          ? Icons.trending_down
                          : Icons.trending_flat),
                  color: (instrument.quoteObj!.changeToday > 0
                      ? Colors.green
                      : (instrument.quoteObj!.changeToday < 0
                          ? Colors.red
                          : Colors.grey))),
              Text(
                formatCurrency.format(instrument.quoteObj!.lastTradePrice),
                style: const TextStyle(fontSize: 18.0),
                textAlign: TextAlign.right,
              ),
            ],
          ),
        ),
        /*
        ListTile(
        title: const Text("Expiration Date"),
        trailing: Text(formatDate.format(leg.expirationDate!),
            style: const TextStyle(fontSize: 18)),
        ),
        */
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            TextButton(
              child: const Text('VIEW STOCK'),
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            InstrumentWidget(user, instrument)));
              },
            ),
          ],
        ),
      ],
    ));
  }
}