import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/retail_order_flow.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';

class RetailOrderFlowWidget extends StatefulWidget {
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  final Instrument instrument;
  final RetailOrderFlow? preloadedOrderFlow;

  const RetailOrderFlowWidget({
    super.key,
    required this.brokerageUser,
    required this.service,
    required this.instrument,
    this.preloadedOrderFlow,
  });

  @override
  State<RetailOrderFlowWidget> createState() => _RetailOrderFlowWidgetState();
}

class _RetailOrderFlowWidgetState extends State<RetailOrderFlowWidget> {
  Future<RetailOrderFlow?>? _future;
  bool _isExpanded = false;

  final NumberFormat _compactNumberFormat = NumberFormat.compact();
  final DateFormat _dateFormat = DateFormat('MMM d, yyyy');

  @override
  void initState() {
    super.initState();
    if (widget.preloadedOrderFlow != null) {
      _future = Future.value(widget.preloadedOrderFlow);
    } else {
      _loadData();
    }
  }

  @override
  void didUpdateWidget(covariant RetailOrderFlowWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.instrument.id != widget.instrument.id ||
        oldWidget.preloadedOrderFlow != widget.preloadedOrderFlow) {
      if (widget.preloadedOrderFlow != null) {
        _future = Future.value(widget.preloadedOrderFlow);
      } else {
        _loadData();
      }
    }
  }

  void _loadData() {
    setState(() {
      _future = _fetchRetailOrderFlow();
    });
  }

  Future<RetailOrderFlow?> _fetchRetailOrderFlow() async {
    try {
      final res = await widget.service.getRetailSentiment(
        widget.brokerageUser,
        widget.instrument.id,
      );

      if (res == null) return null;

      if (res is Map<String, dynamic>) {
        return RetailOrderFlow.fromJson(
          res,
          fallbackInstrumentId: widget.instrument.id,
          fallbackSymbol: widget.instrument.symbol,
        );
      } else if (res is Map) {
        return RetailOrderFlow.fromJson(
          Map<String, dynamic>.from(res),
          fallbackInstrumentId: widget.instrument.id,
          fallbackSymbol: widget.instrument.symbol,
        );
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching retail order flow data: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RetailOrderFlow?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Card(
              child: ListTile(
                leading: Icon(Icons.error_outline,
                    color: Theme.of(context).colorScheme.error),
                title: const Text('Retail order flow unavailable'),
                subtitle: Text('${snapshot.error}'),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadData,
                ),
              ),
            ),
          );
        }

        final flow = snapshot.data;
        if (flow == null) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, flow),
                  const SizedBox(height: 16),
                  _buildSplitBar(context, flow),
                  const SizedBox(height: 16),
                  _buildPrimaryMetricsGrid(context, flow),
                  const SizedBox(height: 12),
                  _buildSummaryBanner(context, flow),
                  if (_isExpanded) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    _buildHistoryTable(context, flow),
                    const SizedBox(height: 12),
                    _buildEducationalNotes(context),
                  ],
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                      },
                      icon: Icon(
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                      ),
                      label: Text(
                        _isExpanded
                            ? 'Hide Retail Trend'
                            : 'View Historical Retail Trend',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, RetailOrderFlow flow) {
    Color badgeColor;
    if (flow.isBullish) {
      badgeColor = Colors.green;
    } else if (flow.isBearish) {
      badgeColor = Colors.red;
    } else {
      badgeColor = Colors.grey;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(
                    Icons.groups_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Retail Order Flow & Robinhood Sentiment',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              tooltip: 'Refresh retail sentiment',
              onPressed: _loadData,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withAlpha((255 * 0.12).round()),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: badgeColor.withAlpha((255 * 0.35).round()),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    flow.isBullish
                        ? Icons.arrow_upward
                        : (flow.isBearish
                            ? Icons.arrow_downward
                            : Icons.remove),
                    size: 14,
                    color: badgeColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${flow.sentimentLabel} (${flow.buyRatioFormatted} Buy)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withAlpha((255 * 0.5).round()),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withAlpha((255 * 0.2).round()),
                ),
              ),
              child: Text(
                'Net Flow: ${flow.netBuyFormatted}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSplitBar(BuildContext context, RetailOrderFlow flow) {
    final buyFlex = (flow.buyPercentage * 10).round().clamp(1, 999);
    final sellFlex = (flow.sellPercentage * 10).round().clamp(1, 999);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.arrow_drop_up, color: Colors.green, size: 20),
                Text(
                  'Buyers ${flow.buyRatioFormatted}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  'Sellers ${flow.sellRatioFormatted}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                    fontSize: 13,
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: Colors.red, size: 20),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 14,
            child: Row(
              children: [
                Expanded(
                  flex: buyFlex,
                  child: Container(
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  flex: sellFlex,
                  child: Container(
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryMetricsGrid(BuildContext context, RetailOrderFlow flow) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 16) / 3;
        final volSubtitle = flow.sellVolumeChangePercentage != null
            ? 'Sell Vol: ${flow.sellVolumeChangeFormatted}'
            : 'Recent Trend';

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildMetricTile(
              context,
              title: 'Net Retail Bias',
              value: flow.netBuyFormatted,
              subtitle:
                  flow.netBuyPercentage >= 0 ? 'Accumulation' : 'Distribution',
              width: cardWidth,
              valueColor:
                  flow.netBuyPercentage >= 0 ? Colors.green : Colors.red,
            ),
            _buildMetricTile(
              context,
              title: flow.numBuyOrders != null ? 'Buy Orders' : 'Buy Ratio',
              value: flow.numBuyOrders != null
                  ? _compactNumberFormat.format(flow.numBuyOrders)
                  : flow.buyRatioFormatted,
              subtitle: flow.numSellOrders != null
                  ? 'vs ${_compactNumberFormat.format(flow.numSellOrders)} Sell'
                  : 'vs ${flow.sellRatioFormatted} Sell',
              width: cardWidth,
            ),
            _buildMetricTile(
              context,
              title: flow.buyVolumeChangePercentage != null
                  ? 'Buy Vol Shift'
                  : 'Volume Shift',
              value: flow.volumeChangeFormatted,
              subtitle: volSubtitle,
              width: cardWidth,
              valueColor: (flow.volumeChangePercentage ?? 0) >= 0
                  ? Colors.green
                  : Colors.red,
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required double width,
    Color? valueColor,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerLow
            .withAlpha((255 * 0.7).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withAlpha((255 * 0.4).round()),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: valueColor ?? Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withAlpha((255 * 0.75).round()),
                  fontSize: 10,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBanner(BuildContext context, RetailOrderFlow flow) {
    String message;
    IconData icon;
    Color color;

    if (flow.buyPercentage >= 70.0) {
      message =
          'Strong retail accumulation. Retail traders are aggressively buying with high conviction.';
      icon = Icons.bolt;
      color = Colors.green;
    } else if (flow.isBullish) {
      message =
          'Net retail buying interest observed. Buyers outnumber sellers across recent sessions.';
      icon = Icons.trending_up;
      color = Colors.green;
    } else if (flow.buyPercentage <= 30.0) {
      message =
          'Heavy retail selling pressure. Outflows dominate customer order routing.';
      icon = Icons.warning_amber_rounded;
      color = Colors.red;
    } else if (flow.isBearish) {
      message =
          'Net retail distribution. Selling volume currently outpaces buying interest.';
      icon = Icons.trending_down;
      color = Colors.red;
    } else {
      message =
          'Balanced retail activity. Buy and sell orders are relatively evenly split.';
      icon = Icons.balance;
      color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha((255 * 0.08).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha((255 * 0.25).round())),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTable(BuildContext context, RetailOrderFlow flow) {
    if (flow.history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'Historical trend data unavailable.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      );
    }

    final hasSeparateVolumes = flow.history.any((pt) =>
        pt.buyVolumeChangePercentage != null ||
        pt.sellVolumeChangePercentage != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daily Retail Sentiment Trend',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 16,
            horizontalMargin: 8,
            headingRowHeight: 36,
            dataRowMinHeight: 36,
            dataRowMaxHeight: 40,
            columns: [
              const DataColumn(
                  label: Text('Date',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
              const DataColumn(
                  label: Text('Net Flow',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
              const DataColumn(
                  label: Text('Buy %',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
              const DataColumn(
                  label: Text('Sell %',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
              if (hasSeparateVolumes) ...[
                const DataColumn(
                    label: Text('Buy Vol',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12))),
                const DataColumn(
                    label: Text('Sell Vol',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12))),
              ] else ...[
                const DataColumn(
                    label: Text('Vol Shift',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12))),
              ],
            ],
            rows: flow.history.map((pt) {
              final dateLabel =
                  pt.date != null ? _dateFormat.format(pt.date!) : '-';
              final netColor =
                  pt.netBuyPercentage >= 0 ? Colors.green : Colors.red;
              return DataRow(
                cells: [
                  DataCell(
                      Text(dateLabel, style: const TextStyle(fontSize: 12))),
                  DataCell(Text(pt.netBuyFormatted,
                      style: TextStyle(
                          fontSize: 12,
                          color: netColor,
                          fontWeight: FontWeight.bold))),
                  DataCell(Text(pt.buyFormatted,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                          fontWeight: FontWeight.w600))),
                  DataCell(Text(pt.sellFormatted,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                          fontWeight: FontWeight.w600))),
                  if (hasSeparateVolumes) ...[
                    DataCell(Text(pt.buyVolumeChangeFormatted,
                        style: TextStyle(
                            fontSize: 12,
                            color: (pt.buyVolumeChangePercentage ?? 0) >= 0
                                ? Colors.green
                                : Colors.red))),
                    DataCell(Text(pt.sellVolumeChangeFormatted,
                        style: TextStyle(
                            fontSize: 12,
                            color: (pt.sellVolumeChangePercentage ?? 0) >= 0
                                ? Colors.green
                                : Colors.red))),
                  ] else ...[
                    DataCell(Text(pt.volumeChangeFormatted,
                        style: const TextStyle(fontSize: 12))),
                  ],
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildEducationalNotes(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withAlpha((255 * 0.3).round()),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'About Robinhood Retail Sentiment',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Aggregated directly from Robinhood retail customer execution data. Tracks daily buy/sell order ratios, net retail positioning, and customer trading volume shifts to spot retail momentum and sentiment divergences.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  height: 1.35,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
