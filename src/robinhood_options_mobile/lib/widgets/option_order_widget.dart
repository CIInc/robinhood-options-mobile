import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/option_order.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';

import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';

class OptionOrderWidget extends StatefulWidget {
  const OptionOrderWidget(
    this.user,
    this.service,
    //this.account,
    this.optionOrder, {
    super.key,
    required this.analytics,
    required this.observer,
    required this.generativeService,
  });

  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser user;
  final IBrokerageService service;
  final GenerativeService generativeService;
  //final Account account;
  final OptionOrder optionOrder;

  @override
  State<OptionOrderWidget> createState() => _OptionOrderWidgetState();
}

class _OptionOrderWidgetState extends State<OptionOrderWidget> {
  late Future<Quote?> futureQuote;
  late Future<Instrument> futureInstrument;

  // Loaded with option_positions parent widget
  //Future<OptionInstrument> futureOptionInstrument;

  _OptionOrderWidgetState();

  @override
  void initState() {
    super.initState();
    widget.analytics.logScreenView(
      screenName: 'OptionOrder/${widget.optionOrder.chainSymbol}',
    );
  }

  @override
  Widget build(BuildContext context) {
    var instrumentStore = Provider.of<InstrumentStore>(context, listen: false);
    var quoteStore = Provider.of<QuoteStore>(context, listen: false);
    var cachedQuotes = quoteStore.items
        .where((element) => element.symbol == widget.optionOrder.chainSymbol);
    if (cachedQuotes.isNotEmpty) {
      futureQuote = Future.value(cachedQuotes.first);
    } else {
      futureQuote = widget.service
          .getQuote(widget.user, quoteStore, widget.optionOrder.chainSymbol);
    }

    return Scaffold(
      body: FutureBuilder(
          future: futureQuote,
          builder: (context, AsyncSnapshot<Quote?> snapshot) {
            if (snapshot.hasData) {
              var quote = snapshot.data!;
              futureInstrument = widget.service.getInstrument(
                  widget.user, instrumentStore, snapshot.data!.instrument);
              return FutureBuilder(
                  future: futureInstrument,
                  builder:
                      (context, AsyncSnapshot<Instrument> instrumentSnapshot) {
                    if (instrumentSnapshot.hasData) {
                      var instrument = instrumentSnapshot.data!;
                      instrument.quoteObj = quote;
                      return _buildPage(instrument);
                    } else if (instrumentSnapshot.hasError) {
                      debugPrint("${instrumentSnapshot.error}");
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
    /*
    final DateTime today =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final int dte =
        optionOrder.legs.first.expirationDate!.difference(today).inDays;
    final DateTime createdAt = DateTime(widget.optionOrder.createdAt!.year,
        widget.optionOrder.createdAt!.month, widget.optionOrder.createdAt!.day);
    final int originalDte =
        optionOrder.legs.first.expirationDate!.difference(createdAt).inDays;
        */
    return CustomScrollView(slivers: [
      SliverAppBar(
        //title: Text(instrument.symbol), // Text('${optionOrder.symbol} \$${optionOrder.optionInstrument!.strikePrice} ${optionOrder.strategy.split('_').first} ${optionOrder.optionInstrument!.type.toUpperCase()}')
        expandedHeight: 160.0,
        floating: true,
        snap: true,
        pinned: false,
        centerTitle: false,
        flexibleSpace: FlexibleSpaceBar(
            title: SingleChildScrollView(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
              // const Row(children: [SizedBox(height: 70)]),
              Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  //runAlignment: WrapAlignment.end,
                  //alignment: WrapAlignment.end,
                  spacing: 5,
                  //runSpacing: 5,
                  children: [
                    Text(
                        "${widget.optionOrder.chainSymbol} \$${formatCompactNumber.format(widget.optionOrder.legs.first.strikePrice)} ${widget.optionOrder.strategy}",
                        style: TextStyle(
                            fontSize: 16.0,
                            color:
                                Theme.of(context).appBarTheme.foregroundColor)),
                    Text(
                        formatDate.format(
                            widget.optionOrder.legs.first.expirationDate!),
                        style: TextStyle(
                            fontSize: 16.0,
                            color:
                                Theme.of(context).appBarTheme.foregroundColor))
                  ]),
            ]))),
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
        child: _buildOverview(widget.user, instrument),
      ),
      SliverToBoxAdapter(
          child: Card(
              child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const ListTile(
              title: Text("Order Detail", style: TextStyle(fontSize: 20))),
          ListTile(
            title: const Text("Opening Strategy"),
            trailing: Text(
              widget.optionOrder.openingStrategy ?? "",
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Closing Strategy"),
            trailing: Text(
              widget.optionOrder.closingStrategy ?? "",
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Created"),
            trailing: Text(
              formatDate.format(widget.optionOrder.createdAt!),
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Updated"),
            trailing: Text(
              formatDate.format(widget.optionOrder.updatedAt!),
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Direction"),
            trailing: Text(
              widget.optionOrder.direction,
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Quantity"),
            trailing: Text(
              formatCompactNumber.format(widget.optionOrder.quantity),
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Processed Quantity"),
            trailing: Text(
              formatCompactNumber.format(widget.optionOrder.processedQuantity),
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Cancelled Quantity"),
            trailing: Text(
              formatCompactNumber.format(widget.optionOrder.canceledQuantity),
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Pending Quantity"),
            trailing: Text(
              formatCompactNumber.format(widget.optionOrder.pendingQuantity),
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Premium"),
            trailing: Text(
              formatCurrency.format(widget.optionOrder.premium),
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Processed Premium"),
            trailing: Text(
              formatCurrency.format(widget.optionOrder.processedPremium),
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Price"),
            trailing: Text(
              formatCurrency.format(widget.optionOrder.price),
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Stop Price"),
            trailing: Text(
              widget.optionOrder.stopPrice != null
                  ? formatCurrency.format(widget.optionOrder.stopPrice)
                  : "-",
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("State"),
            trailing: Text(
              widget.optionOrder.state,
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Time in Force"),
            trailing: Text(
              widget.optionOrder.timeInForce,
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Trigger"),
            trailing: Text(
              widget.optionOrder.trigger,
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Type"),
            trailing: Text(
              widget.optionOrder.type,
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Response Category"),
            trailing: Text(
              widget.optionOrder.responseCategory ?? "",
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text("Cancel Url"),
            trailing: Text(
              widget.optionOrder.cancelUrl ?? "",
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ))),
      SliverToBoxAdapter(
          child: Card(
              child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _buildLegs(widget.optionOrder).toList(),
      ))),
    ]);
  }

  Iterable<Widget> _buildLegs(OptionOrder optionOrder) sync* {
    for (int i = 0; i < optionOrder.legs.length; i++) {
      var leg = optionOrder.legs[i];
      yield ListTile(
          title: Text("Leg ${i + 1}", style: const TextStyle(fontSize: 20)));
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
        trailing: Text(formatCurrency.format(leg.strikePrice),
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

  Card _buildOverview(BrokerageUser user, Instrument instrument) {
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
                formatCurrency.format(
                    instrument.quoteObj!.lastExtendedHoursTradePrice ??
                        instrument.quoteObj!.lastTradePrice),
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
                              widget.service,
                              instrument,
                              analytics: widget.analytics,
                              observer: widget.observer,
                              generativeService: widget.generativeService,
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
