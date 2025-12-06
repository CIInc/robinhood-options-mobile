import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';

import 'package:robinhood_options_mobile/model/instrument_order.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/ad_banner_widget.dart';
import 'package:robinhood_options_mobile/widgets/disclaimer_widget.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';

class PositionOrderWidget extends StatefulWidget {
  const PositionOrderWidget(
    this.brokerageUser,
    this.service,
    //this.account,
    this.positionOrder, {
    super.key,
    required this.analytics,
    required this.observer,
    required this.generativeService,
    this.user,
    this.userDocRef,
  });

  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  final GenerativeService generativeService;
  //final Account account;
  final InstrumentOrder positionOrder;
  final User? user;
  final DocumentReference<User>? userDocRef;

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
      futureInstrument = widget.service.getInstrument(widget.brokerageUser,
          instrumentStore, widget.positionOrder.instrument);
    }

    var quoteStore = Provider.of<QuoteStore>(context, listen: false);

    return FutureBuilder(
        future: futureInstrument,
        builder: (context, AsyncSnapshot<Instrument> snapshot) {
          if (snapshot.hasData) {
            widget.positionOrder.instrumentObj = snapshot.data!;
            futureQuote = widget.service.getQuote(widget.brokerageUser,
                quoteStore, widget.positionOrder.instrumentObj!.symbol);
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
        centerTitle: false,
        //title: Text(instrument.symbol), // Text('${positionOrder.symbol} \$${positionOrder.optionInstrument!.strikePrice} ${positionOrder.strategy.split('_').first} ${positionOrder.optionInstrument!.type.toUpperCase()}')
        expandedHeight: 120.0,
        floating: true,
        snap: true,
        pinned: false,
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
                    style: TextStyle(
                        fontSize: 16.0,
                        color: Theme.of(context).appBarTheme.foregroundColor)),
                Text(
                    positionOrder.averagePrice != null
                        ? formatCurrency.format(positionOrder.averagePrice)
                        : "",
                    style: TextStyle(
                        fontSize: 16.0,
                        color: Theme.of(context).appBarTheme.foregroundColor)),
                Text(
                  formatDate.format(positionOrder.updatedAt!),
                  style: TextStyle(
                      fontSize: 16.0,
                      color: Theme.of(context).appBarTheme.foregroundColor),
                  textAlign: TextAlign.start,
                )
              ])),

          /// If [titlePadding] is null, then defaults to start
          /// padding of 72.0 pixels and bottom padding of 16.0 pixels.
          // titlePadding: const EdgeInsetsDirectional.only(start: 6, bottom: 4),
          // centerTitle: false,
          // expandedTitleScale: 1.25,
        ),
      ),
      if (positionOrder.instrumentObj != null) ...[
        SliverToBoxAdapter(
          child: _buildOverview(
              widget.brokerageUser, positionOrder.instrumentObj!),
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
                minTileHeight: 10,
                trailing: Text(
                  formatDate.format(positionOrder.createdAt!),
                  style: const TextStyle(fontSize: summaryValueFontSize),
                ),
              ),
              ListTile(
                title: const Text("Updated"),
                minTileHeight: 10,
                trailing: Text(
                  formatDate.format(positionOrder.updatedAt!),
                  style: const TextStyle(fontSize: summaryValueFontSize),
                ),
              ),
              ListTile(
                title: const Text("Quantity"),
                minTileHeight: 10,
                trailing: Text(
                  formatCompactNumber.format(positionOrder.quantity),
                  style: const TextStyle(fontSize: summaryValueFontSize),
                ),
              ),
              ListTile(
                title: const Text("Cumulative Quantity"),
                minTileHeight: 10,
                trailing: Text(
                  formatCompactNumber.format(positionOrder.cumulativeQuantity),
                  style: const TextStyle(fontSize: summaryValueFontSize),
                ),
              ),
              ListTile(
                title: const Text("Price"),
                minTileHeight: 10,
                trailing: Text(
                  positionOrder.price != null
                      ? formatCurrency.format(positionOrder.price)
                      : '',
                  style: const TextStyle(fontSize: summaryValueFontSize),
                ),
              ),
              ListTile(
                title: const Text("Average Price"),
                minTileHeight: 10,
                trailing: Text(
                  positionOrder.averagePrice != null
                      ? formatCurrency.format(positionOrder.averagePrice)
                      : "-",
                  style: const TextStyle(fontSize: summaryValueFontSize),
                ),
              ),
              ListTile(
                title: const Text("Stop Price"),
                minTileHeight: 10,
                trailing: Text(
                  positionOrder.stopPrice != null
                      ? formatCurrency.format(positionOrder.stopPrice)
                      : "",
                  style: const TextStyle(fontSize: summaryValueFontSize),
                ),
              ),
              ListTile(
                title: const Text("Fees"),
                minTileHeight: 10,
                trailing: Text(
                  formatCurrency.format(positionOrder.fees),
                  style: const TextStyle(fontSize: summaryValueFontSize),
                ),
              ),
              ListTile(
                title: const Text("State"),
                minTileHeight: 10,
                trailing: Text(
                  positionOrder.state,
                  style: const TextStyle(fontSize: summaryValueFontSize),
                ),
              ),
              ListTile(
                title: const Text("Side"),
                minTileHeight: 10,
                trailing: Text(
                  positionOrder.side,
                  style: const TextStyle(fontSize: summaryValueFontSize),
                ),
              ),
              ListTile(
                title: const Text("Time in Force"),
                minTileHeight: 10,
                trailing: Text(
                  positionOrder.timeInForce,
                  style: const TextStyle(fontSize: summaryValueFontSize),
                ),
              ),
              ListTile(
                title: const Text("Trigger"),
                minTileHeight: 10,
                trailing: Text(
                  positionOrder.trigger,
                  style: const TextStyle(fontSize: summaryValueFontSize),
                ),
              ),
              ListTile(
                title: const Text("Type"),
                minTileHeight: 10,
                trailing: Text(
                  positionOrder.type,
                  style: const TextStyle(fontSize: summaryValueFontSize),
                ),
              ),
              if (positionOrder.rejectReason != null) ...[
                ListTile(
                  title: const Text("Reject Reason"),
                  minTileHeight: 10,
                  trailing: Text(
                    positionOrder.rejectReason ?? "-",
                    style: const TextStyle(fontSize: summaryValueFontSize),
                  ),
                ),
              ],
              // ListTile(
              //   title: const Text("Cancel"),
              //   minTileHeight: 10,
              //   trailing: Text(
              //     positionOrder.cancel ?? "-",
              //     style: const TextStyle(fontSize: summaryValueFontSize),
              //   ),
              // ),
            ],
          ),
        ),
      ),
      if (positionOrder.cancel != null) ...[
        SliverToBoxAdapter(
            child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton(
                  child: const Text('CANCEL'),
                  onPressed: () async {
                    var response = await widget.service.cancelOrder(
                        widget.brokerageUser, positionOrder.cancel!);
                    // debugPrint(jsonEncode(response.body));

                    if (mounted) {
                      showDialog<String>(
                        context: context,
                        builder: (BuildContext context) => AlertDialog(
                          title: const Text('Cancel'),
                          content: Text(response.statusCode == 200
                              ? 'Order has been cancelled.'
                              : 'Error: Order could not be cancelled.'),
                          // actions: <Widget>[
                          //   TextButton(
                          //     onPressed: () => Navigator.pop(context, 'OK'),
                          //     child: const Text('OK'),
                          //   ),
                          // ],
                        ),
                      );
                      Navigator.pop(context);
                    }
                  }),
              const SizedBox(width: 4),
            ],
          ),
        )),
      ],
      if (!kIsWeb) ...[
        const SliverToBoxAdapter(
            child: SizedBox(
          height: 25.0,
        )),
        SliverToBoxAdapter(child: AdBannerWidget(size: AdSize.mediumRectangle)),
      ],
      const SliverToBoxAdapter(
          child: SizedBox(
        height: 25.0,
      )),
      const SliverToBoxAdapter(child: DisclaimerWidget()),
      const SliverToBoxAdapter(
          child: SizedBox(
        height: 25.0,
      ))
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

  Card _buildOverview(BrokerageUser user, Instrument instrument) {
    return Card(
        child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ListTile(
          // leading: const Icon(Icons.album),
          title: Text(instrument.simpleName ?? instrument.symbol),
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
                  formatCurrency.format(
                      instrument.quoteObj!.lastExtendedHoursTradePrice ??
                          instrument.quoteObj!.lastTradePrice),
                  style: const TextStyle(fontSize: summaryValueFontSize),
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
                              widget.service,
                              instrument,
                              analytics: widget.analytics,
                              observer: widget.observer,
                              generativeService: widget.generativeService,
                              user: widget.user,
                              userDocRef: widget.userDocRef,
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
