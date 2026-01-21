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
    required this.user,
    required this.userDocRef,
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
  late Future<void> _dataLoadFuture;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    if (widget.positionOrder.instrumentObj != null) {
      widget.analytics.logScreenView(
        screenName:
            'PositionOrder/${widget.positionOrder.instrumentObj!.symbol}',
      );
    }
    _dataLoadFuture = _loadData();
  }

  Future<void> _loadData() async {
    var instrumentStore = Provider.of<InstrumentStore>(context, listen: false);
    var quoteStore = Provider.of<QuoteStore>(context, listen: false);

    if (widget.positionOrder.instrumentObj == null) {
      var instruments = instrumentStore.items
          .where((element) => element.url == widget.positionOrder.instrument);
      if (instruments.isNotEmpty) {
        widget.positionOrder.instrumentObj = instruments.first;
      } else {
        widget.positionOrder.instrumentObj = await widget.service.getInstrument(
            widget.brokerageUser,
            instrumentStore,
            widget.positionOrder.instrument);
      }
    }

    if (widget.positionOrder.instrumentObj != null) {
      var quote = await widget.service.getQuote(widget.brokerageUser,
          quoteStore, widget.positionOrder.instrumentObj!.symbol);
      widget.positionOrder.instrumentObj!.quoteObj = quote;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: _dataLoadFuture,
        builder: (context, snapshot) {
          if (widget.positionOrder.instrumentObj != null) {
            return Scaffold(body: _buildPage(widget.positionOrder));
          } else if (snapshot.hasError) {
            return Scaffold(
                body: Center(
                    child: Text("Error loading order: ${snapshot.error}")));
          }
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        });
  }

  Widget _buildPage(InstrumentOrder positionOrder) {
    return CustomScrollView(slivers: [
      SliverAppBar(
        centerTitle: false,
        //title: Text(instrument.symbol), // Text('${positionOrder.symbol} \$${positionOrder.optionInstrument!.strikePrice} ${positionOrder.strategy.split('_').first} ${positionOrder.optionInstrument!.type.toUpperCase()}')
        expandedHeight: 120.0,
        floating: false,
        snap: false,
        pinned: true,
        flexibleSpace: FlexibleSpaceBar(
          title: SingleChildScrollView(
              child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  children: [
                Text(
                    "${positionOrder.instrumentObj!.symbol} ${positionOrder.side} ${positionOrder.type}",
                    style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).appBarTheme.foregroundColor)),
                if (positionOrder.averagePrice != null)
                  Text(formatCurrency.format(positionOrder.averagePrice),
                      style: TextStyle(
                          fontSize: 16.0,
                          color:
                              Theme.of(context).appBarTheme.foregroundColor)),
                Text(
                  formatDate.format(positionOrder.updatedAt!),
                  style: TextStyle(
                      fontSize: 14.0,
                      color: Theme.of(context)
                          .appBarTheme
                          .foregroundColor
                          ?.withValues(alpha: 0.7)),
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
              ListTile(
                title: const Text("Order Detail",
                    style:
                        TextStyle(fontSize: 20)),
                trailing: Chip(
                  label: Text(positionOrder.state.toUpperCase()),
                  backgroundColor: positionOrder.state == 'filled'
                      ? Colors.green.withValues(alpha: 0.2)
                      : (positionOrder.state == 'cancelled' ||
                              positionOrder.state == 'rejected')
                          ? Colors.red.withValues(alpha: 0.2)
                          : Colors.orange.withValues(alpha: 0.2),
                ),
              ),
              const Divider(),
              _buildSectionHeader("Execution"),
              _buildDetailRow("Quantity",
                  formatCompactNumber.format(positionOrder.quantity)),
              _buildDetailRow("Cumulative Quantity",
                  formatCompactNumber.format(positionOrder.cumulativeQuantity)),
              _buildDetailRow(
                  "Price",
                  positionOrder.price != null
                      ? formatCurrency.format(positionOrder.price)
                      : ''),
              _buildDetailRow(
                  "Average Price",
                  positionOrder.averagePrice != null
                      ? formatCurrency.format(positionOrder.averagePrice)
                      : "-"),
              _buildDetailRow(
                  "Fees", formatCurrency.format(positionOrder.fees)),
              const Divider(),
              _buildSectionHeader("Order Settings"),
              _buildDetailRow("Side", positionOrder.side),
              _buildDetailRow("Type", positionOrder.type),
              _buildDetailRow("Time in Force", positionOrder.timeInForce),
              _buildDetailRow("Trigger", positionOrder.trigger),
              if (positionOrder.trailingPeg != null) ...[
                _buildDetailRow(
                    "Trailing Peg Type",
                    positionOrder.trailingPeg!['type']
                            ?.toString()
                            .toLowerCase() ??
                        ""),
                if (positionOrder.trailingPeg!['percentage'] != null)
                  _buildDetailRow("Trailing Peg Percentage",
                      "${positionOrder.trailingPeg!['percentage']}%"),
                if (positionOrder.trailingPeg!['price'] != null &&
                    positionOrder.trailingPeg!['price']['amount'] != null)
                  _buildDetailRow(
                      "Trailing Peg Amount",
                      formatCurrency.format(double.tryParse(
                          positionOrder.trailingPeg!['price']['amount']))),
              ],
              if (positionOrder.stopPrice != null)
                _buildDetailRow("Stop Price",
                    formatCurrency.format(positionOrder.stopPrice)),
              const Divider(),
              _buildSectionHeader("Timestamps"),
              _buildDetailRow(
                  "Created", formatDate.format(positionOrder.createdAt!)),
              _buildDetailRow(
                  "Updated", formatDate.format(positionOrder.updatedAt!)),
              if (positionOrder.rejectReason != null) ...[
                const Divider(),
                ListTile(
                  title: const Text("Reject Reason",
                      style: TextStyle(color: Colors.red)),
                  subtitle: Text(positionOrder.rejectReason ?? "-"),
                ),
              ],
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
                  onPressed: _isCancelling
                      ? null
                      : () async {
                          setState(() {
                            _isCancelling = true;
                          });
                          try {
                            var response = await widget.service.cancelOrder(
                                widget.brokerageUser, positionOrder.cancel!);
                            if (mounted) {
                              if (response.statusCode == 200) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Order cancelled successfully')),
                                );
                                Navigator.pop(context);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'Failed to cancel order: ${response.body}')),
                                );
                              }
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 16)),
          Text(value,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
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
