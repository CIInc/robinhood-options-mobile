import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/futures_position_store.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/future_instrument_widget.dart';
import 'package:robinhood_options_mobile/widgets/futures_positions_page_widget.dart';
import 'package:robinhood_options_mobile/widgets/chart_pie_widget.dart' as pie;
import 'package:robinhood_options_mobile/widgets/pnl_badge.dart';
import 'package:robinhood_options_mobile/widgets/animated_price_text.dart';

class FuturesPositionsWidget extends StatefulWidget {
  const FuturesPositionsWidget(
    this.brokerageUser,
    this.service,
    this.futuresPositions, {
    super.key,
    required this.analytics,
    required this.observer,
    required this.generativeService,
    required this.user,
    required this.userDocRef,
    this.showList = false,
    this.showGroupHeader = true,
  });

  final bool showList;
  final bool showGroupHeader;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  final GenerativeService generativeService;
  final List<dynamic> futuresPositions;
  final User? user;
  final DocumentReference<User>? userDocRef;

  @override
  State<FuturesPositionsWidget> createState() => _FuturesPositionsWidgetState();
}

class _FuturesPositionsWidgetState extends State<FuturesPositionsWidget> {
  late FuturesPositionStore store;

  @override
  void initState() {
    super.initState();
    store = FuturesPositionStore();
    store.addAll(widget.futuresPositions);
  }

  @override
  void didUpdateWidget(covariant FuturesPositionsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.futuresPositions != widget.futuresPositions) {
      store.removeAll();
      store.addAll(widget.futuresPositions);
    }
  }

  @override
  Widget build(BuildContext context) {
    // If using store inside, we want reactive updates.
    // Since we create store locally, we should use ChangeNotifierProvider.value wrapping the content
    // OR just use the store directly and use AnimatedBuilder or similar if we expect changes?
    // The parent (Home) passes a StreamBuilder result, so `futuresPositions` updates when stream updates.
    // So `didUpdateWidget` handles data refreshes.
    // However, existing logic used `Consumer`.
    // We can wrap our build method in `ChangeNotifierProvider.value`.

    return ChangeNotifierProvider<FuturesPositionStore>.value(
        value: store,
        child: Consumer<FuturesPositionStore>(
            builder: (context, localStore, child) {
          var items = localStore.items;
          if (items.isEmpty) {
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          }
          return SliverToBoxAdapter(
            child: Column(
              children: [
                if (widget.showGroupHeader)
                  ListTile(
                    title: Wrap(children: [
                      Text(
                        'Futures',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (!widget.showList) ...[
                        SizedBox(
                          height: 28,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.chevron_right),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      FuturesPositionsPageWidget(
                                    widget.brokerageUser,
                                    widget.service,
                                    widget.futuresPositions,
                                    analytics: widget.analytics,
                                    observer: widget.observer,
                                    generativeService: widget.generativeService,
                                    user: widget.user,
                                    userDocRef: widget.userDocRef,
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      ]
                    ]),
                    subtitle: Text(
                        '${items.length} positions • Notional: ${formatCurrency.format(localStore.totalNotional)}'),
                    trailing: InkWell(
                      onTap: () {
                        // Placeholder for functionality to switch display value
                      },
                      child: Wrap(spacing: 8, children: [
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(8.0, 8.0, 0.0, 8.0),
                          child: AnimatedPriceText(
                            price: localStore.totalOpenPnl,
                            format: formatCurrency,
                            style: TextStyle(
                              fontSize: assetValueFontSize,
                              // color: localStore.totalOpenPnl >= 0
                              //     ? Colors.green
                              //     : Colors.red
                            ),
                            textAlign: TextAlign.right,
                          ),
                        )
                      ]),
                    ),
                    onTap: !widget.showList
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    FuturesPositionsPageWidget(
                                  widget.brokerageUser,
                                  widget.service,
                                  widget.futuresPositions,
                                  analytics: widget.analytics,
                                  observer: widget.observer,
                                  generativeService: widget.generativeService,
                                  user: widget.user,
                                  userDocRef: widget.userDocRef,
                                ),
                              ),
                            );
                          }
                        : null,
                  ),
                if (localStore.notionalDistribution.isNotEmpty &&
                    widget.showList) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Risk Distribution (Notional)',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 200,
                    child: pie.PieChart(
                      [
                        charts.Series<pie.PieChartData, String>(
                          id: 'Notional',
                          domainFn: (pie.PieChartData sales, _) => sales.label,
                          measureFn: (pie.PieChartData sales, _) => sales.value,
                          data: localStore.notionalDistribution.entries
                              .map((e) => pie.PieChartData(e.key, e.value))
                              .toList(),
                          labelAccessorFn: (pie.PieChartData row, _) =>
                              '${row.label}: ${formatCompactNumber.format(row.value)}',
                          colorFn: (_, index) => pie.PieChart.makeShades(
                              charts.MaterialPalette.blue.shadeDefault,
                              localStore.notionalDistribution.length)[index!],
                        )
                      ],
                      renderer: charts.ArcRendererConfig(
                        arcWidth: 60,
                        arcRendererDecorators: [
                          charts.ArcLabelDecorator(
                              labelPosition: charts.ArcLabelPosition.outside)
                        ],
                      ),
                      onSelected: (p0) {},
                    ),
                  ),
                ],
                if (items.isNotEmpty && widget.showList)
                  Column(
                    children: items.map((pos) {
                      String displaySymbol = '—';
                      String description = '';
                      String contractSymbol = '';
                      double quantity = 0.0;
                      double avg = 0.0;
                      String accountNumber = '';
                      double? openPnl;
                      double? dayPnl;
                      double? lastPrice;
                      double? multiplier;
                      double? previousClosePrice;
                      double? totalCost;
                      double? notionalValue;
                      if (pos is Map) {
                        // Get product info for display
                        var product = pos['product'];
                        if (product != null) {
                          displaySymbol =
                              product['displaySymbol']?.toString() ?? '—';
                          description =
                              product['description']?.toString() ?? '';
                        }

                        // Get contract info
                        var contract = pos['contract'];
                        if (contract != null) {
                          contractSymbol =
                              contract['displaySymbol']?.toString() ?? '';
                          var multiplierStr =
                              contract['multiplier']?.toString();
                          if (multiplierStr != null) {
                            multiplier = double.tryParse(multiplierStr);
                          }
                        }

                        // If no product info, fall back to contract ID
                        if (displaySymbol == '—') {
                          displaySymbol = pos['contractId']?.toString() ?? '—';
                        }

                        quantity = double.tryParse(
                                pos['quantity']?.toString() ?? '0') ??
                            0.0;
                        avg = double.tryParse(
                                pos['avgTradePrice']?.toString() ?? '0') ??
                            0.0;
                        accountNumber = pos['accountNumber']?.toString() ?? '';
                        if (pos['openPnlCalc'] != null) {
                          openPnl =
                              double.tryParse(pos['openPnlCalc'].toString());
                        }
                        if (pos['dayPnlCalc'] != null) {
                          dayPnl =
                              double.tryParse(pos['dayPnlCalc'].toString());
                        }
                        if (pos['lastTradePrice'] != null) {
                          lastPrice =
                              double.tryParse(pos['lastTradePrice'].toString());
                        }
                        if (pos['notionalValue'] != null) {
                          notionalValue =
                              double.tryParse(pos['notionalValue'].toString());
                        }
                        if (pos['previousClosePrice'] != null) {
                          previousClosePrice = double.tryParse(
                              pos['previousClosePrice'].toString());
                        }

                        // Calculate total cost if we have all components
                        if (quantity != 0 && multiplier != null && avg > 0) {
                          totalCost = avg * quantity.abs() * multiplier;
                        }
                      }
                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              onTap: () {
                                if (pos is Map<String, dynamic>) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          FutureInstrumentWidget(
                                        brokerageUser: widget.brokerageUser,
                                        service: widget.service,
                                        position: pos,
                                        analytics: widget.analytics,
                                        observer: widget.observer,
                                        generativeService:
                                            widget.generativeService,
                                        user: widget.user,
                                        userDocRef: widget.userDocRef,
                                      ),
                                    ),
                                  );
                                }
                              },
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 4.0),
                              leading: CircleAvatar(
                                radius: 25,
                                child: Text(displaySymbol.isNotEmpty
                                    ? displaySymbol.replaceAll('/', '')
                                    : '—'),
                              ),
                              title: Text(
                                  '$contractSymbol ${quantity > 0 ? '+' : ''}${quantity.toStringAsFixed(quantity.truncateToDouble() == quantity ? 0 : 2)}'),
                              subtitle: Text(
                                description.isNotEmpty
                                    ? description
                                    : (contractSymbol.isNotEmpty
                                        ? contractSymbol
                                        : accountNumber),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: lastPrice != null
                                  ? Text(
                                      formatCurrency.format(lastPrice),
                                      style: const TextStyle(
                                          fontSize: positionValueFontSize),
                                      textAlign: TextAlign.right,
                                    )
                                  : null,
                            ),
                            if (avg > 0 || dayPnl != null || openPnl != null)
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 5),
                                  child: Row(
                                    children: [
                                      if (avg > 0)
                                        Padding(
                                          padding: const EdgeInsets.all(
                                              summaryEgdeInset),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              PnlBadge(
                                                  text: formatCurrency
                                                      .format(avg),
                                                  neutral: true),
                                              const SizedBox(height: 4),
                                              const Text("Cost",
                                                  style: TextStyle(
                                                      fontSize:
                                                          summaryLabelFontSize)),
                                            ],
                                          ),
                                        ),
                                      if (dayPnl != null)
                                        Padding(
                                          padding: const EdgeInsets.all(
                                              summaryEgdeInset),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              PnlBadge(
                                                  text: formatCurrency
                                                      .format(dayPnl),
                                                  value: dayPnl),
                                              const SizedBox(height: 4),
                                              const Text("Day P&L",
                                                  style: TextStyle(
                                                      fontSize:
                                                          summaryLabelFontSize)),
                                            ],
                                          ),
                                        ),
                                      if (openPnl != null)
                                        Padding(
                                          padding: const EdgeInsets.all(
                                              summaryEgdeInset),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              PnlBadge(
                                                  text: formatCurrency
                                                      .format(openPnl),
                                                  value: openPnl),
                                              const SizedBox(height: 4),
                                              const Text("Open P&L",
                                                  style: TextStyle(
                                                      fontSize:
                                                          summaryLabelFontSize)),
                                            ],
                                          ),
                                        ),
                                      if (totalCost != null)
                                        Padding(
                                          padding: const EdgeInsets.all(
                                              summaryEgdeInset),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              PnlBadge(
                                                  text: formatCurrency
                                                      .format(totalCost),
                                                  neutral: true),
                                              const SizedBox(height: 4),
                                              const Text("Total Cost",
                                                  style: TextStyle(
                                                      fontSize:
                                                          summaryLabelFontSize)),
                                            ],
                                          ),
                                        ),
                                      if (notionalValue != null)
                                        Padding(
                                          padding: const EdgeInsets.all(
                                              summaryEgdeInset),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              PnlBadge(
                                                  text: formatCurrency
                                                      .format(notionalValue),
                                                  neutral: true),
                                              const SizedBox(height: 4),
                                              const Text("Notional",
                                                  style: TextStyle(
                                                      fontSize:
                                                          summaryLabelFontSize)),
                                            ],
                                          ),
                                        ),
                                      if (multiplier != null)
                                        Padding(
                                          padding: const EdgeInsets.all(
                                              summaryEgdeInset),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              PnlBadge(
                                                  text:
                                                      '${multiplier.toStringAsFixed(0)}x',
                                                  neutral: true),
                                              const SizedBox(height: 4),
                                              const Text("Multiplier",
                                                  style: TextStyle(
                                                      fontSize:
                                                          summaryLabelFontSize)),
                                            ],
                                          ),
                                        ),
                                      if (previousClosePrice != null)
                                        Padding(
                                          padding: const EdgeInsets.all(
                                              summaryEgdeInset),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              PnlBadge(
                                                  text: formatCurrency.format(
                                                      previousClosePrice),
                                                  neutral: true),
                                              const SizedBox(height: 4),
                                              const Text("Prev Close",
                                                  style: TextStyle(
                                                      fontSize:
                                                          summaryLabelFontSize)),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          );
        }));
  }
}
