import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/future_historicals.dart';
import 'package:robinhood_options_mobile/model/instrument_historical.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals_selection_store.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/chart_time_series_widget.dart';

class FutureInstrumentWidget extends StatefulWidget {
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  final Map<String, dynamic> position;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final GenerativeService generativeService;
  final User? user;
  final DocumentReference<User>? userDocRef;

  const FutureInstrumentWidget({
    super.key,
    required this.brokerageUser,
    required this.service,
    required this.position,
    required this.analytics,
    required this.observer,
    required this.generativeService,
    required this.user,
    required this.userDocRef,
  });

  @override
  State<FutureInstrumentWidget> createState() => _FutureInstrumentWidgetState();
}

class _FutureInstrumentWidgetState extends State<FutureInstrumentWidget> {
  Future<FutureHistoricals?>? _futureHistoricals;
  // InstrumentHistorical? selection;

  @override
  void initState() {
    super.initState();
    var contractId = widget.position['contractId'];
    if (contractId != null) {
      _futureHistoricals = widget.service
          .getFuturesHistoricals(widget.brokerageUser, contractId.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    var pos = widget.position;
    String displaySymbol = '—';
    String description = '';
    String contractSymbol = '';
    double quantity = 0.0;
    double avg = 0.0;
    double? openPnl;
    double? dayPnl;
    double? lastPrice;
    double? multiplier;
    double? previousClosePrice;
    double? notionalValue;
    String? expirationDate;

    // Extract data
    var product = pos['product'];
    if (product != null) {
      displaySymbol = product['displaySymbol']?.toString() ?? '—';
      description = product['description']?.toString() ?? '';
    }

    var contract = pos['contract'];
    if (contract != null) {
      contractSymbol = contract['displaySymbol']?.toString() ?? '';
      var multiplierStr = contract['multiplier']?.toString();
      if (multiplierStr != null) {
        multiplier = double.tryParse(multiplierStr);
      }
      expirationDate = contract['expirationDate']?.toString();
    }

    if (displaySymbol == '—') {
      displaySymbol = pos['contractId']?.toString() ?? '—';
    }

    quantity = double.tryParse(pos['quantity']?.toString() ?? '0') ?? 0.0;
    avg = double.tryParse(pos['avgTradePrice']?.toString() ?? '0') ?? 0.0;

    if (pos['openPnlCalc'] != null) {
      openPnl = double.tryParse(pos['openPnlCalc'].toString());
    }
    if (pos['dayPnlCalc'] != null) {
      dayPnl = double.tryParse(pos['dayPnlCalc'].toString());
    }
    if (pos['lastTradePrice'] != null) {
      lastPrice = double.tryParse(pos['lastTradePrice'].toString());
    }
    if (pos['previousClosePrice'] != null) {
      previousClosePrice =
          double.tryParse(pos['previousClosePrice'].toString());
    }
    if (pos['notionalValue'] != null) {
      notionalValue = double.tryParse(pos['notionalValue'].toString());
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(displaySymbol),
            if (description.isNotEmpty)
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Stats
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatCurrency.format(lastPrice ?? 0),
                        style: const TextStyle(
                            fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          if (dayPnl != null) ...[
                            Text(
                              '${dayPnl >= 0 ? '+' : ''}${formatCurrency.format(dayPnl)}',
                              style: TextStyle(
                                  fontSize: 16,
                                  color:
                                      dayPnl >= 0 ? Colors.green : Colors.red),
                            ),
                            const Text(' Today',
                                style: TextStyle(fontSize: 16)),
                          ]
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(),
            if (_futureHistoricals != null)
              FutureBuilder(
                future: _futureHistoricals,
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    var data = snapshot.data!.historicals;
                    if (data.isEmpty) {
                      return const SizedBox(
                          height: 50,
                          child: Center(child: Text("No historical data")));
                    }
                    var series = [
                      charts.Series<InstrumentHistorical, DateTime>(
                        id: 'Price',
                        colorFn: (_, __) =>
                            charts.MaterialPalette.green.shadeDefault,
                        domainFn: (InstrumentHistorical sales, _) =>
                            sales.beginsAt!,
                        measureFn: (InstrumentHistorical sales, _) =>
                            sales.closePrice,
                        data: data,
                      )
                    ];
                    return ChangeNotifierProvider(
                        create: (context) =>
                            InstrumentHistoricalsSelectionStore(),
                        child: Column(
                          children: [
                            SizedBox(
                              height: 250,
                              child: Builder(builder: (context) {
                                return TimeSeriesChart(
                                  series,
                                  zeroBound: false,
                                  onSelected: (model) {
                                    if (model != null &&
                                        model.selectedDatum.isNotEmpty) {
                                      Provider.of<InstrumentHistoricalsSelectionStore>(
                                              context,
                                              listen: false)
                                          .selectionChanged(model
                                              .selectedDatum.first.datum
                                              as InstrumentHistorical);
                                    }
                                  },
                                );
                              }),
                            ),
                            Consumer<InstrumentHistoricalsSelectionStore>(
                                builder: (context, store, child) {
                              if (store.selection != null) {
                                return Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                      "${DateFormat.yMEd().add_jm().format(store.selection!.beginsAt!)}: ${formatCurrency.format(store.selection!.closePrice)}"),
                                );
                              }
                              return Container();
                            }),
                          ],
                        ));
                  } else if (snapshot.hasError) {
                    return const SizedBox(
                        height: 50,
                        child: Center(child: Text("Error loading chart")));
                  }
                  return const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()));
                },
              ),
            const Divider(),
            // Position Details
            ListTile(
              title: const Text('Your Position'),
              subtitle: Column(
                children: [
                  _buildRow('Quantity', quantity.toString()),
                  _buildRow('Avg Price', formatCurrency.format(avg)),
                  _buildRow(
                      'Current Price',
                      lastPrice != null
                          ? formatCurrency.format(lastPrice)
                          : '—'),
                  _buildRow(
                      'Market Value',
                      (lastPrice != null && multiplier != null)
                          ? formatCurrency
                              .format(lastPrice * quantity.abs() * multiplier)
                          : '—'),
                  if (openPnl != null)
                    _buildRow('Total Return', formatCurrency.format(openPnl),
                        isMoney: true),
                ],
              ),
            ),
            const Divider(),
            // Risk Metrics
            ListTile(
              title: const Text('Risk Metrics'),
              subtitle: Column(
                children: [
                  _buildRow(
                      'Notional Value',
                      notionalValue != null
                          ? formatCurrency.format(notionalValue)
                          : '—'),
                  _buildRow(
                      'Multiplier',
                      multiplier != null
                          ? '${multiplier.toStringAsFixed(0)}x'
                          : '—'),
                ],
              ),
            ),
            const Divider(),
            // Contract Details
            ListTile(
              title: const Text('Contract Details'),
              subtitle: Column(
                children: [
                  _buildRow('Symbol', contractSymbol),
                  _buildRow('Root Symbol', contract?['rootSymbol'] ?? '—'),
                  _buildRow('Expiration', expirationDate ?? '—'),
                  _buildRow(
                      'Previous Close',
                      previousClosePrice != null
                          ? formatCurrency.format(previousClosePrice)
                          : '—'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isMoney = false}) {
    Color? valueColor;
    if (isMoney) {
      if (value.startsWith('+') ||
          (!value.startsWith('-') && value != '0.00' && value != '\$0.00')) {
        valueColor = Colors.green;
      } else if (value.startsWith('-')) {
        valueColor = Colors.red;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w500, color: valueColor),
          ),
        ],
      ),
    );
  }
}
