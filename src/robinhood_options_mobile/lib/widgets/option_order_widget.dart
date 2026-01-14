import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/option_order.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/ad_banner_widget.dart';
import 'package:robinhood_options_mobile/widgets/disclaimer_widget.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';

class OptionOrderWidget extends StatefulWidget {
  const OptionOrderWidget(
    this.brokerageUser,
    this.service,
    //this.account,
    this.optionOrder, {
    super.key,
    required this.analytics,
    required this.observer,
    required this.generativeService,
    required this.user,
    required this.userDocRef,
  });

  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  final GenerativeService generativeService;
  //final Account account;
  final OptionOrder optionOrder;
  final User? user;
  final DocumentReference<User>? userDocRef;

  @override
  State<OptionOrderWidget> createState() => _OptionOrderWidgetState();
}

class _OptionOrderWidgetState extends State<OptionOrderWidget> {
  late Future<Quote?> futureQuote;
  late Future<Instrument> futureInstrument;
  bool _isCancelling = false;

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
      futureQuote = widget.service.getQuote(
          widget.brokerageUser, quoteStore, widget.optionOrder.chainSymbol);
    }

    return Scaffold(
      body: FutureBuilder(
          future: futureQuote,
          builder: (context, AsyncSnapshot<Quote?> snapshot) {
            if (snapshot.hasData) {
              var quote = snapshot.data!;
              futureInstrument = widget.service.getInstrument(
                  widget.brokerageUser,
                  instrumentStore,
                  snapshot.data!.instrument);
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
    return CustomScrollView(slivers: [
      SliverAppBar(
        expandedHeight: 120.0,
        floating: false,
        snap: false,
        pinned: true,
        centerTitle: false,
        flexibleSpace: FlexibleSpaceBar(
            title: SingleChildScrollView(
                child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 5,
                    children: [
              Text(
                  "${widget.optionOrder.chainSymbol} \$${formatCompactNumber.format(widget.optionOrder.legs.first.strikePrice)} ${widget.optionOrder.strategy}",
                  style: TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).appBarTheme.foregroundColor)),
              Text(
                  formatDate
                      .format(widget.optionOrder.legs.first.expirationDate!),
                  style: TextStyle(
                      fontSize: 14.0,
                      color: Theme.of(context)
                          .appBarTheme
                          .foregroundColor
                          ?.withOpacity(0.7)))
            ]))),
      ),
      SliverToBoxAdapter(
        child: _buildOverview(widget.brokerageUser, instrument),
      ),
      SliverToBoxAdapter(
        child: Card(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                title: const Text("Order Detail",
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                trailing: Chip(
                  label: Text(widget.optionOrder.state.toUpperCase()),
                  backgroundColor: widget.optionOrder.state == 'filled'
                      ? Colors.green.withOpacity(0.2)
                      : (widget.optionOrder.state == 'cancelled' ||
                              widget.optionOrder.state == 'rejected')
                          ? Colors.red.withOpacity(0.2)
                          : Colors.orange.withOpacity(0.2),
                ),
              ),
              const Divider(),
              _buildSectionHeader("Execution"),
              _buildDetailRow("Quantity",
                  formatCompactNumber.format(widget.optionOrder.quantity)),
              _buildDetailRow(
                  "Processed Quantity",
                  formatCompactNumber
                      .format(widget.optionOrder.processedQuantity)),
              _buildDetailRow(
                  "Price",
                  widget.optionOrder.price != null
                      ? formatCurrency.format(widget.optionOrder.price)
                      : ''),
              _buildDetailRow(
                  "Premium",
                  widget.optionOrder.premium != null
                      ? formatCurrency.format(widget.optionOrder.premium)
                      : ''),
              _buildDetailRow(
                  "Processed Premium",
                  widget.optionOrder.processedPremium != null
                      ? formatCurrency
                          .format(widget.optionOrder.processedPremium)
                      : ''),
              const Divider(),
              _buildSectionHeader("Order Settings"),
              _buildDetailRow("Direction", widget.optionOrder.direction),
              _buildDetailRow("Type", widget.optionOrder.type),
              _buildDetailRow("Time in Force", widget.optionOrder.timeInForce),
              _buildDetailRow("Trigger", widget.optionOrder.trigger),
              if (widget.optionOrder.stopPrice != null)
                _buildDetailRow("Stop Price",
                    formatCurrency.format(widget.optionOrder.stopPrice)),
              if (widget.optionOrder.openingStrategy != null)
                _buildDetailRow(
                    "Opening Strategy", widget.optionOrder.openingStrategy!),
              if (widget.optionOrder.closingStrategy != null)
                _buildDetailRow(
                    "Closing Strategy", widget.optionOrder.closingStrategy!),
              const Divider(),
              _buildSectionHeader("Timestamps"),
              _buildDetailRow(
                  "Created", formatDate.format(widget.optionOrder.createdAt!)),
              _buildDetailRow(
                  "Updated", formatDate.format(widget.optionOrder.updatedAt!)),
              // if (widget.optionOrder.cancelUrl != null)
              //   _buildDetailRow("Cancel Url", widget.optionOrder.cancelUrl!),
            ],
          ),
        ),
      ),
      SliverToBoxAdapter(
          child: Card(
              child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _buildLegs(widget.optionOrder).toList(),
      ))),
      if (widget.optionOrder.cancelUrl != null) ...[
        SliverToBoxAdapter(
            child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton(
                  onPressed: _isCancelling
                      ? null
                      : () async {
                          setState(() {
                            _isCancelling = true;
                          });
                          try {
                            var response = await widget.service.cancelOrder(
                                widget.brokerageUser,
                                widget.optionOrder.cancelUrl!);
                            if (mounted) {
                              // TODO: Handle response properly, maybe it returns an object or map
                              // Assuming response is dynamic and we might need to check something
                              // For now, just show success if no error thrown
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Order cancelled successfully')),
                              );
                              Navigator.pop(context);
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content:
                                        Text('Error cancelling order: $e')),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() {
                                _isCancelling = false;
                              });
                            }
                          }
                        },
                  child: _isCancelling
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('CANCEL')),
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
    ]);
  }

  Iterable<Widget> _buildLegs(OptionOrder optionOrder) sync* {
    for (int i = 0; i < optionOrder.legs.length; i++) {
      var leg = optionOrder.legs[i];
      yield ListTile(
          title: Text("Leg ${i + 1}",
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)));
      yield const Divider();
      yield _buildDetailRow(
          "Expiration Date", formatDate.format(leg.expirationDate!));
      yield _buildDetailRow("Position Type", "${leg.positionType}");
      yield _buildDetailRow("Position Effect", "${leg.positionEffect}");
      yield _buildDetailRow("Option Type", leg.optionType);
      yield _buildDetailRow(
          "Strike Price", formatCurrency.format(leg.strikePrice));
      yield _buildDetailRow("Ratio Quantity", "${leg.ratioQuantity}");
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

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
