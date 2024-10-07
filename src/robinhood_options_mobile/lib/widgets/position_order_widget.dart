import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';

import 'package:robinhood_options_mobile/model/instrument_order.dart';
import 'package:robinhood_options_mobile/model/robinhood_user.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';

final formatDate = DateFormat("yMMMd");
final formatCompactDate = DateFormat("MMMd");
final formatCurrency = NumberFormat.simpleCurrency();
final formatPercentage = NumberFormat.decimalPercentPattern(decimalDigits: 2);
final formatNumber = NumberFormat("0.####");
final formatCompactNumber = NumberFormat.compact();

class PositionOrderWidget extends StatefulWidget {
  const PositionOrderWidget(
    this.user,
    //this.account,
    this.positionOrder, {
    super.key,
    required this.analytics,
    required this.observer,
  });

  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final RobinhoodUser user;
  //final Account account;
  final InstrumentOrder positionOrder;

  @override
  State<PositionOrderWidget> createState() => _PositionOrderWidgetState();
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
    widget.analytics.logScreenView(
      screenName: 'PositionOrder/${widget.positionOrder.instrumentObj!.symbol}',
    );
  }

  @override
  Widget build(BuildContext context) {
    var instrumentStore = Provider.of<InstrumentStore>(context, listen: false);
    var instruments = instrumentStore.items
        .where((element) => element.url == widget.positionOrder.instrument);
    if (instruments.isNotEmpty) {
      futureInstrument = Future.value(instruments.first);
    } else {
      futureInstrument = RobinhoodService.getInstrument(
          widget.user, instrumentStore, widget.positionOrder.instrument);
    }

    var quoteStore = Provider.of<QuoteStore>(context, listen: false);

    return FutureBuilder(
        future: futureInstrument,
        builder: (context, AsyncSnapshot<Instrument> snapshot) {
          if (snapshot.hasData) {
            widget.positionOrder.instrumentObj = snapshot.data!;
            futureQuote = RobinhoodService.getQuote(widget.user, quoteStore,
                widget.positionOrder.instrumentObj!.symbol);
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

  Widget _buildPage(InstrumentOrder positionOrder) {
    return CustomScrollView(slivers: [
      SliverAppBar(
        //title: Text(instrument.symbol), // Text('${positionOrder.symbol} \$${positionOrder.optionInstrument!.strikePrice} ${positionOrder.strategy.split('_').first} ${positionOrder.optionInstrument!.type.toUpperCase()}')
        expandedHeight: 120.0,
        flexibleSpace: FlexibleSpaceBar(
          title: SingleChildScrollView(
              child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  //runAlignment: WrapAlignment.end,
                  //alignment: WrapAlignment.end,
                  spacing: 5,
                  //runSpacing: 5,
                  children: [
                Text(
                    "${positionOrder.instrumentObj!.symbol} ${positionOrder.type} ${positionOrder.side}",
                    style: const TextStyle(fontSize: 19.0)),
                Text(
                    positionOrder.averagePrice != null
                        ? formatCurrency.format(positionOrder.averagePrice)
                        : "",
                    style: const TextStyle(fontSize: 19.0)),
                Text(
                  formatDate.format(positionOrder.updatedAt!),
                  style: const TextStyle(fontSize: 15.0),
                  textAlign: TextAlign.start,
                )
              ])),

          /// If [titlePadding] is null, then defaults to start
          /// padding of 72.0 pixels and bottom padding of 16.0 pixels.
          // titlePadding: const EdgeInsetsDirectional.only(start: 6, bottom: 4),
          // centerTitle: false,
          expandedTitleScale: 1.25,
        ),
        pinned: true,
      ),
      if (positionOrder.instrumentObj != null) ...[
        SliverToBoxAdapter(
          child: _buildOverview(widget.user, positionOrder.instrumentObj!),
        ),
      ],
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
              positionOrder.price != null
                  ? formatCurrency.format(positionOrder.price)
                  : '',
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

  Card _buildOverview(RobinhoodUser user, Instrument instrument) {
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
              if (instrument.quoteObj != null) ...[
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
              ]
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            TextButton(
              child: const Text('VIEW STOCK'),
              onPressed: () {
                /*
                _navKey.currentState!.push(
                  MaterialPageRoute(
                    builder: (_) => SubSecondPage(),
                  ),
                );
                */
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => InstrumentWidget(
                              user,
                              //widget.account,
                              instrument,
                              analytics: widget.analytics,
                              observer: widget.observer,
                            )));
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
      ],
    ));
  }
}
