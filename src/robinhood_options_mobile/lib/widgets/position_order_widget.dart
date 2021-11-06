import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:robinhood_options_mobile/model/position_order.dart';
import 'package:robinhood_options_mobile/model/robinhood_user.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';

final formatDate = DateFormat("yMMMd");
final formatCompactDate = DateFormat("MMMd");
final formatCurrency = NumberFormat.simpleCurrency();
final formatPercentage = NumberFormat.decimalPercentPattern(decimalDigits: 2);
final formatNumber = NumberFormat("0.####");
final formatCompactNumber = NumberFormat.compact();

class PositionOrderWidget extends StatefulWidget {
  final RobinhoodUser user;
  final PositionOrder positionOrder;
  const PositionOrderWidget(this.user, this.positionOrder, {Key? key})
      : super(key: key);

  @override
  _PositionOrderWidgetState createState() => _PositionOrderWidgetState();
}

class _PositionOrderWidgetState extends State<PositionOrderWidget> {
  late Future<Quote> futureQuote;
  late Future<Instrument> futureInstrument;

  // Loaded with option_positions parent widget
  //Future<OptionInstrument> futureOptionInstrument;

  _PositionOrderWidgetState();

  @override
  void initState() {
    super.initState();

    futureInstrument = RobinhoodService.getInstrument(
        widget.user, widget.positionOrder.instrument);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: futureInstrument,
        builder: (context, AsyncSnapshot<Instrument> snapshot) {
          if (snapshot.hasData) {
            widget.positionOrder.instrumentObj = snapshot.data!;
            futureQuote = RobinhoodService.getQuote(
                widget.user, widget.positionOrder.instrumentObj!.symbol);
            return FutureBuilder(
                future: futureQuote,
                builder: (context, AsyncSnapshot<Quote> quoteSnapshot) {
                  if (quoteSnapshot.hasData) {
                    widget.positionOrder.instrumentObj!.quoteObj =
                        quoteSnapshot.data!;
                  }
                  return Scaffold(body: _buildPage(widget.positionOrder));
                });
          }
          return Scaffold(body: _buildPage(widget.positionOrder));
        });

    /*
        floatingActionButton: (user != null && user.userName != null)
            ? FloatingActionButton(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => TradeOptionWidget(user,
                            positionOrder: positionOrder))),
                tooltip: 'Trade',
                child: const Icon(Icons.shopping_cart),
              )
            : null*/
  }

  Widget _buildPage(PositionOrder positionOrder) {
    return CustomScrollView(slivers: [
      SliverAppBar(
        //title: Text(instrument.symbol), // Text('${positionOrder.symbol} \$${positionOrder.optionInstrument!.strikePrice} ${positionOrder.strategy.split('_').first} ${positionOrder.optionInstrument!.type.toUpperCase()}')
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
                            "${positionOrder.instrumentObj!.symbol} ${positionOrder.type} ${positionOrder.side}",
                            style: const TextStyle(fontSize: 20.0)),
                        Text(
                            "${positionOrder.averagePrice != null ? formatCurrency.format(positionOrder.averagePrice) : ""}",
                            style: const TextStyle(fontSize: 20.0)),
                        Text(formatDate.format(positionOrder.updatedAt!),
                            style: const TextStyle(fontSize: 15.0))
                      ]),
                ]))),
        pinned: true,
      ),
      SliverToBoxAdapter(
          child: Card(
              child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const ListTile(
              title: Text("Order Detail", style: TextStyle(fontSize: 20))),
          ListTile(
            title: const Text("Created"),
            trailing: Text(
              formatDate.format(positionOrder.createdAt!),
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Updated"),
            trailing: Text(
              formatDate.format(positionOrder.updatedAt!),
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Quantity"),
            trailing: Text(
              formatCompactNumber.format(positionOrder.quantity),
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Cumulative Quantity"),
            trailing: Text(
              formatCompactNumber.format(positionOrder.cumulativeQuantity),
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Price"),
            trailing: Text(
              formatCurrency.format(positionOrder.price),
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Average Price"),
            trailing: Text(
              formatCurrency.format(positionOrder.averagePrice),
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Stop Price"),
            trailing: Text(
              positionOrder.stopPrice != null
                  ? formatCurrency.format(positionOrder.stopPrice)
                  : "",
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Fees"),
            trailing: Text(
              formatCurrency.format(positionOrder.fees),
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("State"),
            trailing: Text(
              positionOrder.state,
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Side"),
            trailing: Text(
              positionOrder.side,
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Time in Force"),
            trailing: Text(
              positionOrder.timeInForce,
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Trigger"),
            trailing: Text(
              positionOrder.trigger,
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Type"),
            trailing: Text(
              positionOrder.type,
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Reject Reason"),
            trailing: Text(
              positionOrder.rejectReason ?? "",
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Cancel"),
            trailing: Text(
              positionOrder.cancel ?? "",
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ))),
      /*
      SliverToBoxAdapter(
          child: Card(
              child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _buildLegs(positionOrder).toList(),
      ))),
      SliverToBoxAdapter(
        child: _buildPositionView(position),
      ),
      SliverToBoxAdapter(
        child: _buildStockView(instrument),
      ),
      */
    ]);
  }

  /*
  Widget _buildPage(Instrument instrument) {
    final DateTime today =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final int dte =
        positionOrder.legs.first.expirationDate!.difference(today).inDays;
    final DateTime createdAt = DateTime(positionOrder.createdAt!.year,
        positionOrder.createdAt!.month, positionOrder.createdAt!.day);
    final int originalDte =
        positionOrder.legs.first.expirationDate!.difference(createdAt).inDays;
    return CustomScrollView(slivers: [
      SliverAppBar(
        //title: Text(instrument.symbol), // Text('${positionOrder.symbol} \$${positionOrder.optionInstrument!.strikePrice} ${positionOrder.strategy.split('_').first} ${positionOrder.optionInstrument!.type.toUpperCase()}')
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
                            "${positionOrder.chainSymbol} \$${formatCompactNumber.format(positionOrder.legs.first.strikePrice)} ${positionOrder.strategy}",
                            style: const TextStyle(fontSize: 20.0)),
                        Text(
                            '${formatDate.format(positionOrder.legs.first.expirationDate!)}',
                            style: const TextStyle(fontSize: 15.0))
                      ]),
                ]))),
        pinned: true,
      ),

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
              positionOrder.openingStrategy ?? "",
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Closing Strategy"),
            trailing: Text(
              positionOrder.closingStrategy ?? "",
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Created"),
            trailing: Text(
              formatDate.format(positionOrder.createdAt!),
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Updated"),
            trailing: Text(
              formatDate.format(positionOrder.updatedAt!),
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Direction"),
            trailing: Text(
              positionOrder.direction,
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Quantity"),
            trailing: Text(
              formatCompactNumber.format(positionOrder.quantity),
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Processed Quantity"),
            trailing: Text(
              formatCompactNumber.format(positionOrder.processedQuantity),
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Cancelled Quantity"),
            trailing: Text(
              formatCompactNumber.format(positionOrder.canceledQuantity),
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Pending Quantity"),
            trailing: Text(
              formatCompactNumber.format(positionOrder.pendingQuantity),
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Premium"),
            trailing: Text(
              formatCurrency.format(positionOrder.premium),
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Processed Premium"),
            trailing: Text(
              formatCurrency.format(positionOrder.processedPremium),
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Price"),
            trailing: Text(
              formatCurrency.format(positionOrder.price),
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Stop Price"),
            trailing: Text(
              positionOrder.stopPrice != null
                  ? formatCurrency.format(positionOrder.stopPrice)
                  : "-",
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("State"),
            trailing: Text(
              positionOrder.state,
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Time in Force"),
            trailing: Text(
              positionOrder.timeInForce,
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Trigger"),
            trailing: Text(
              positionOrder.trigger,
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Type"),
            trailing: Text(
              positionOrder.type,
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Response Category"),
            trailing: Text(
              positionOrder.responseCategory ?? "",
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Cancel Url"),
            trailing: Text(
              positionOrder.cancelUrl ?? "",
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ))),
      SliverToBoxAdapter(
          child: Card(
              child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _buildLegs(positionOrder).toList(),
      ))),
      SliverToBoxAdapter(
        child: _buildStockView(instrument),
      ),
    ]);
  }

  Iterable<Widget> _buildLegs(PositionOrder positionOrder) sync* {
    for (int i = 0; i < positionOrder.legs.length; i++) {
      var leg = positionOrder.legs[i];
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
  */

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
                child: Text(positionOrder.direction == "debit"
                    ? "BUY"
                    : "BUY TO CLOSE"),
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => TradeOptionWidget(user,
                            positionOrder: positionOrder,
                            positionType: "Buy")))),
            TextButton(
                child: Text(positionOrder.direction == "debit"
                    ? "SELL"
                    : "SELL TO OPEN"),
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => TradeOptionWidget(user,
                            positionOrder: positionOrder,
                            positionType: "Sell")))),
            const SizedBox(width: 8),
          ],
        ),
      ],
    ));
  }
  */

  /*
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
  */
}
