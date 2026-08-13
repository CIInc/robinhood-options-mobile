import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/futures_position_store.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/chart_bar_widget.dart';
import 'package:robinhood_options_mobile/widgets/future_instrument_widget.dart';
import 'package:robinhood_options_mobile/widgets/futures_positions_page_widget.dart';
import 'package:robinhood_options_mobile/widgets/chart_pie_widget.dart' as pie;
import 'package:robinhood_options_mobile/widgets/pnl_badge.dart';
import 'package:robinhood_options_mobile/widgets/animated_price_text.dart';

enum _FuturesChartMeasure {
  notional('Notional'),
  totalCost('Total Cost'),
  marginRequirement('Margin Requirement'),
  openPnl('Open P&L'),
  dayPnl('Day P&L'),
  realizedPnl('Realized P&L');

  const _FuturesChartMeasure(this.label);

  final String label;
}

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
    this.disableNavigation = false,
    this.chartRowLimit,
  });

  final bool showList;
  final bool showGroupHeader;
  final bool disableNavigation;
  final int? chartRowLimit;
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
  _FuturesChartMeasure _chartMeasure = _FuturesChartMeasure.openPnl;
  bool _sortDescending = true;

  void _showAggregateTradeDisabled(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
              'Trading actions are disabled in Aggregate View. Switch to a single account to trade.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _handleNavigation(BuildContext context, VoidCallback action) {
    if (widget.disableNavigation) {
      _showAggregateTradeDisabled(context);
      return;
    }
    action();
  }

  String _positionSymbol(dynamic position) {
    if (position is! Map) {
      return 'Other';
    }
    final contract = position['contract'];
    final product = position['product'];
    final symbol = contract is Map
        ? (contract['rootSymbol'] ??
                contract['symbol'] ??
                contract['displaySymbol'] ??
                position['contractId'] ??
                'Other')
            .toString()
        : product is Map
            ? (product['symbol'] ??
                    product['displaySymbol'] ??
                    position['contractId'] ??
                    'Other')
                .toString()
            : (position['contractId'] ?? 'Other').toString();
    return symbol.split(':').first;
  }

  double _positionChartValue(dynamic position) {
    if (position is! Map) {
      return 0;
    }

    double readValue(String key) =>
        double.tryParse(position[key]?.toString() ?? '0') ?? 0;

    switch (_chartMeasure) {
      case _FuturesChartMeasure.notional:
        return readValue('notionalValue').abs();
      case _FuturesChartMeasure.totalCost:
        final contract = position['contract'];
        final multiplier = contract is Map
            ? double.tryParse(contract['multiplier']?.toString() ?? '0') ?? 0
            : 0;
        return readValue('avgTradePrice') *
            readValue('quantity').abs() *
            multiplier;
      case _FuturesChartMeasure.marginRequirement:
        return readValue('marginRequirement');
      case _FuturesChartMeasure.openPnl:
        return readValue('openPnlCalc');
      case _FuturesChartMeasure.dayPnl:
        return readValue('dayPnlCalc');
      case _FuturesChartMeasure.realizedPnl:
        return readValue('realizedPnl');
    }
  }

  void _showChartMeasurePicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.35,
          maxChildSize: 0.9,
          builder: (context, scrollController) => Column(
            children: [
              ListTile(
                leading: const Icon(Icons.bar_chart_rounded),
                title: const Text('Primary Measure'),
                subtitle: const Text('Choose how to display futures positions'),
              ),
              Expanded(
                child: RadioGroup<_FuturesChartMeasure>(
                  groupValue: _chartMeasure,
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() => _chartMeasure = value);
                    Navigator.pop(sheetContext);
                  },
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _FuturesChartMeasure.values.length,
                    itemBuilder: (context, index) {
                      final measure = _FuturesChartMeasure.values[index];
                      return RadioListTile<_FuturesChartMeasure>(
                        title: Text(measure.label),
                        value: measure,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToPosition(BuildContext context, dynamic position) {
    if (position is! Map<String, dynamic>) {
      return;
    }
    _handleNavigation(context, () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FutureInstrumentWidget(
            brokerageUser: widget.brokerageUser,
            service: widget.service,
            position: position,
            analytics: widget.analytics,
            observer: widget.observer,
            generativeService: widget.generativeService,
            user: widget.user,
            userDocRef: widget.userDocRef,
          ),
        ),
      );
    });
  }

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
          final contracts = items.fold<double>(0, (total, position) {
            if (position is! Map) {
              return total;
            }
            final quantity =
                double.tryParse(position['quantity']?.toString() ?? '0') ?? 0;
            return total + quantity.abs();
          });
          final notionalEntries = localStore.notionalDistribution.entries
              .where((entry) => entry.value > 0)
              .toList();
          final chartValuesBySymbol = <String, double>{};
          for (final position in items) {
            if (position is Map) {
              final symbol = _positionSymbol(position);
              chartValuesBySymbol[symbol] = (chartValuesBySymbol[symbol] ?? 0) +
                  _positionChartValue(position);
            }
          }
          final sortedChartEntries = chartValuesBySymbol.entries.toList()
            ..sort((a, b) => _sortDescending
                ? b.value.compareTo(a.value)
                : a.value.compareTo(b.value));
          final chartEntries = widget.chartRowLimit == null
              ? sortedChartEntries
              : sortedChartEntries.take(widget.chartRowLimit!).toList();
          final chartRowsOmitted =
              sortedChartEntries.length - chartEntries.length;
          final grossNotional = notionalEntries.fold<double>(
            0,
            (total, entry) => total + entry.value,
          );
          final compactCurrency = NumberFormat.compactSimpleCurrency();
          final chartData = chartEntries
              .map((entry) => {
                    'domain': entry.key,
                    'measure': entry.value,
                    'label': compactCurrency.format(entry.value),
                  })
              .toList();
          final chartSeries = <charts.Series<dynamic, String>>[
            charts.Series<dynamic, String>(
              id: _chartMeasure.label,
              data: chartData,
              seriesColor: charts.ColorUtil.fromDartColor(
                Theme.of(context).brightness == Brightness.light
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.primaryContainer,
              ),
              domainFn: (datum, _) => datum['domain'],
              measureFn: (datum, _) => datum['measure'],
              labelAccessorFn: (datum, _) => datum['label'],
              insideLabelStyleAccessorFn: (datum, index) =>
                  charts.TextStyleSpec(
                fontSize: 14,
                color: charts.ColorUtil.fromDartColor(
                  Theme.of(context).brightness == Brightness.light
                      ? Theme.of(context).colorScheme.surface
                      : Theme.of(context).colorScheme.inverseSurface,
                ),
              ),
              outsideLabelStyleAccessorFn: (datum, index) =>
                  charts.TextStyleSpec(
                fontSize: 14,
                color: charts.ColorUtil.fromDartColor(
                  Theme.of(context).textTheme.labelSmall!.color!,
                ),
              ),
            ),
          ];
          final axisLabelColor =
              Theme.of(context).brightness == Brightness.light
                  ? charts.MaterialPalette.gray.shade700
                  : charts.MaterialPalette.gray.shade500;
          final openPnlChart = BarChart(
            chartSeries,
            barGroupingType: null,
            renderer: charts.BarRendererConfig(
              groupingType: charts.BarGroupingType.stacked,
              barRendererDecorator: charts.BarLabelDecorator<String>(),
              cornerStrategy: const charts.ConstCornerStrategy(10),
            ),
            primaryMeasureAxis: charts.NumericAxisSpec(
              renderSpec: charts.GridlineRendererSpec(
                labelStyle: charts.TextStyleSpec(color: axisLabelColor),
              ),
              tickFormatterSpec:
                  charts.BasicNumericTickFormatterSpec.fromNumberFormat(
                compactCurrency,
              ),
            ),
            domainAxis: charts.OrdinalAxisSpec(
              renderSpec: charts.SmallTickRendererSpec(
                labelStyle: charts.TextStyleSpec(color: axisLabelColor),
              ),
            ),
            behaviors: [charts.SeriesLegend()],
            onSelected: (dynamic selected) {
              if (selected == null) {
                return;
              }
              final position = items.cast<dynamic>().firstWhere(
                    (item) => _positionSymbol(item) == selected['domain'],
                    orElse: () => null,
                  );
              setState(() {});
              _navigateToPosition(context, position);
            },
          );
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
                              _handleNavigation(context, () {
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
                                      generativeService:
                                          widget.generativeService,
                                      user: widget.user,
                                      userDocRef: widget.userDocRef,
                                    ),
                                  ),
                                );
                              });
                            },
                          ),
                        )
                      ]
                    ]),
                    subtitle: Text(
                        '${formatCompactNumber.format(items.length)} positions, ${formatCompactNumber.format(contracts)} contracts${chartRowsOmitted > 0 ? ', charting top ${chartEntries.length}' : ''}'),
                    trailing: InkWell(
                      onTap: () {
                        setState(() {
                          _chartMeasure = _FuturesChartMeasure.openPnl;
                        });
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
                            _handleNavigation(context, () {
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
                            });
                          }
                        : null,
                  ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Row(
                      children: [
                        _buildSummaryMetric(
                          'Day P&L',
                          localStore.totalDayPnl,
                          measure: _FuturesChartMeasure.dayPnl,
                        ),
                        _buildSummaryMetric(
                          'Open P&L',
                          localStore.totalOpenPnl,
                          measure: _FuturesChartMeasure.openPnl,
                        ),
                        _buildSummaryMetric(
                          'Realized',
                          localStore.totalRealizedPnl,
                          measure: _FuturesChartMeasure.realizedPnl,
                        ),
                        _buildSummaryMetric(
                          'Notional',
                          grossNotional,
                          measure: _FuturesChartMeasure.notional,
                          neutral: true,
                        ),
                        _buildSummaryMetric(
                          'Margin',
                          localStore.totalMarginRequirement,
                          measure: _FuturesChartMeasure.marginRequirement,
                          neutral: true,
                        ),
                      ],
                    ),
                  ),
                ),
                if (chartData.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SizedBox(
                        height: chartData.length * 26 + 80,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                          child: openPnlChart,
                        ),
                      ),
                      _buildChartControls(context),
                    ],
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
                      double? realizedPnl;
                      double? lastPrice;
                      double? multiplier;
                      double? previousClosePrice;
                      double? totalCost;
                      double? notionalValue;
                      double? marginRequirement;
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
                        if (pos['realizedPnl'] != null) {
                          realizedPnl =
                              double.tryParse(pos['realizedPnl'].toString());
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
                        if (pos['marginRequirement'] != null) {
                          marginRequirement = double.tryParse(
                              pos['marginRequirement'].toString());
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
                                  _handleNavigation(context, () {
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
                                  });
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
                                      if (realizedPnl != null &&
                                          realizedPnl != 0)
                                        Padding(
                                          padding: const EdgeInsets.all(
                                              summaryEgdeInset),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              PnlBadge(
                                                  text: formatCurrency
                                                      .format(realizedPnl),
                                                  value: realizedPnl),
                                              const SizedBox(height: 4),
                                              const Text("Realized",
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
                                      if (marginRequirement != null)
                                        Padding(
                                          padding: const EdgeInsets.all(
                                              summaryEgdeInset),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              PnlBadge(
                                                text: formatCurrency
                                                    .format(marginRequirement),
                                                neutral: true,
                                              ),
                                              const SizedBox(height: 4),
                                              const Text("Margin Requirement",
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

  Widget _buildSummaryMetric(
    String label,
    double value, {
    required _FuturesChartMeasure measure,
    bool neutral = false,
  }) {
    return Semantics(
      button: true,
      selected: _chartMeasure == measure,
      label: 'Show ${measure.label} chart',
      child: InkWell(
        onTap: () => setState(() => _chartMeasure = measure),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(summaryEgdeInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PnlBadge(
                text: formatCurrency.format(value),
                value: neutral ? null : value,
                neutral: neutral,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(fontSize: summaryLabelFontSize),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartControls(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildToolbarButton(
                context,
                label: _chartMeasure.label,
                icon: Icons.bar_chart_rounded,
                onTap: () => _showChartMeasurePicker(context),
              ),
              VerticalDivider(
                width: 1,
                thickness: 1,
                indent: 8,
                endIndent: 8,
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
              _buildToolbarButton(
                context,
                label: _sortDescending ? 'High to low' : 'Low to high',
                icon:
                    _sortDescending ? Icons.arrow_downward : Icons.arrow_upward,
                iconColor: colorScheme.secondary,
                onTap: () {
                  setState(() => _sortDescending = !_sortDescending);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolbarButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: iconColor),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}
