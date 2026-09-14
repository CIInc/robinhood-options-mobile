import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/instrument_historical_position.dart';
import 'package:robinhood_options_mobile/model/instrument_order.dart';

class InstrumentHistoricalPositionsWidget extends StatefulWidget {
  final InstrumentCostBasisLookbackSummary summary;
  final Function(InstrumentOrder)? onTapOrder;
  final bool showHeader;

  const InstrumentHistoricalPositionsWidget({
    super.key,
    required this.summary,
    this.onTapOrder,
    this.showHeader = true,
  });

  @override
  State<InstrumentHistoricalPositionsWidget> createState() =>
      _InstrumentHistoricalPositionsWidgetState();
}

class _InstrumentHistoricalPositionsWidgetState
    extends State<InstrumentHistoricalPositionsWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.summary.hasHistory) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isProfitable = widget.summary.isProfitable;
    final isLoss = widget.summary.isLoss;
    final pnlColor = isProfitable
        ? Colors.green
        : (isLoss ? Colors.red : theme.colorScheme.onSurfaceVariant);

    final closedCycles = widget.summary.closedCycles.reversed.toList();
    final displayedCycles =
        _isExpanded ? closedCycles : closedCycles.take(2).toList();

    final card = Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Metric Badges Grid
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildMetricChip(
                  context,
                  label: 'Win Rate',
                  value:
                      '${(widget.summary.winRate * 100).toStringAsFixed(0)}% (${widget.summary.winningTradesCount}/${widget.summary.totalRoundTrips})',
                  icon: Icons.emoji_events_outlined,
                  valueColor: widget.summary.winRate >= 0.5
                      ? Colors.green
                      : Colors.orange,
                ),
                _buildMetricChip(
                  context,
                  label: 'Avg Hold',
                  value: _formatDuration(widget.summary.averageHoldDuration),
                  icon: Icons.timer_outlined,
                ),
                _buildMetricChip(
                  context,
                  label: 'Avg Buy',
                  value: formatCurrency
                      .format(widget.summary.overallAverageBuyPrice),
                  icon: Icons.shopping_bag_outlined,
                ),
                _buildMetricChip(
                  context,
                  label: 'Avg Sell',
                  value: formatCurrency
                      .format(widget.summary.overallAverageSellPrice),
                  icon: Icons.sell_outlined,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Cost Basis & Execution Spread Visualizer
            _buildCostBasisSpreadBar(context),
            const SizedBox(height: 16),

            const Divider(height: 1),
            const SizedBox(height: 12),

            // Section Subheader: Closed Cycles List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Historical Cycles',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (closedCycles.length > 2) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      child: Row(
                        children: [
                          Text(
                            _isExpanded
                                ? 'Show Less'
                                : 'Show All (${closedCycles.length})',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Icon(
                            _isExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // List of closed cycles
            ...displayedCycles.map((cycle) => _buildCycleCard(context, cycle)),
          ],
        ),
      ),
    );

    if (!widget.showHeader) {
      return card;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          context: context,
          title: 'Previous Positions',
          subtitle:
              '${widget.summary.totalRoundTrips} round trip${widget.summary.totalRoundTrips == 1 ? "" : "s"} • Cost Basis Lookback',
          icon: Icons.history_toggle_off_rounded,
          trailing: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${isProfitable ? "+" : ""}${formatCurrency.format(widget.summary.totalRealizedGainLoss)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: pnlColor,
                ),
              ),
              Text(
                '${isProfitable ? "+" : ""}${formatPercentage.format(widget.summary.totalRealizedGainLossPercent)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: pnlColor,
                ),
              ),
            ],
          ),
        ),
        card,
      ],
    );
  }

  Widget _buildSectionHeader({
    required BuildContext context,
    required String title,
    Widget? trailing,
    String? subtitle,
    IconData? icon,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 6.0),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 19,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _buildMetricChip(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    Color? valueColor,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: valueColor ?? theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCostBasisSpreadBar(BuildContext context) {
    final theme = Theme.of(context);
    final avgBuy = widget.summary.overallAverageBuyPrice;
    final avgSell = widget.summary.overallAverageSellPrice;
    final spread = avgSell - avgBuy;
    final spreadPct = avgBuy > 0 ? (spread / avgBuy) : 0.0;
    final isSpreadProfitable = spread >= 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Historical Execution Spread',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${isSpreadProfitable ? "+" : ""}${formatCurrency.format(spread)} (${formatPercentage.format(spreadPct)})',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isSpreadProfitable ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: [
                Expanded(
                  flex: 50,
                  child: Container(
                    height: 6,
                    color: Colors.blue.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  flex: 50,
                  child: Container(
                    height: 6,
                    color: isSpreadProfitable ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Avg Entry: ${formatCurrency.format(avgBuy)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Avg Exit: ${formatCurrency.format(avgSell)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCycleCard(
      BuildContext context, InstrumentHistoricalPosition cycle) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMd();
    final dateRangeStr = cycle.closedAt != null
        ? '${dateFormat.format(cycle.openedAt)} - ${dateFormat.format(cycle.closedAt!)}'
        : 'Opened ${dateFormat.format(cycle.openedAt)}';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: cycle.statusColor.withValues(alpha: 0.15),
          child: Icon(
            cycle.trendingIcon,
            color: cycle.statusColor,
            size: 18,
          ),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                dateRangeStr,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${cycle.isProfitable ? "+" : ""}${formatCurrency.format(cycle.realizedGainLoss)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: cycle.statusColor,
              ),
            ),
          ],
        ),
        subtitle: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '${formatNumber.format(cycle.totalShares)} shares • ${formatCurrency.format(cycle.averageBuyPrice)} → ${formatCurrency.format(cycle.averageSellPrice)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${cycle.isProfitable ? "+" : ""}${formatPercentage.format(cycle.realizedGainLossPercent)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cycle.statusColor,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    cycle.formattedHoldDuration,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (cycle.hasSplits) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.call_split,
                          size: 10,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          cycle.splitsApplied.first.shortRatioBadge,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        onTap: () => _showCycleDetailsBottomSheet(context, cycle),
      ),
    );
  }

  void _showCycleDetailsBottomSheet(
      BuildContext context, InstrumentHistoricalPosition cycle) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        final theme = Theme.of(bottomSheetContext);
        final dateFormat = DateFormat.yMMMd().add_jm();

        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Round-Trip Execution Details',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: cycle.statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${cycle.isProfitable ? "+" : ""}${formatCurrency.format(cycle.realizedGainLoss)} (${formatPercentage.format(cycle.realizedGainLossPercent)})',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: cycle.statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    theme,
                    label: 'Holding Period',
                    value:
                        '${DateFormat.yMMMd().format(cycle.openedAt)} - ${cycle.closedAt != null ? DateFormat.yMMMd().format(cycle.closedAt!) : "Present"} (${cycle.formattedHoldDuration})',
                  ),
                  _buildDetailRow(
                    theme,
                    label: 'Total Shares',
                    value: cycle.hasSplits
                        ? '${formatNumber.format(cycle.totalShares)} (split-adjusted)'
                        : formatNumber.format(cycle.totalShares),
                  ),
                  _buildDetailRow(
                    theme,
                    label: 'Average Buy Price',
                    value: cycle.hasSplits
                        ? '${formatCurrency.format(cycle.averageBuyPrice)} (split-adjusted)'
                        : formatCurrency.format(cycle.averageBuyPrice),
                  ),
                  _buildDetailRow(
                    theme,
                    label: 'Total Cost Basis',
                    value: formatCurrency.format(cycle.totalCostBasis),
                  ),
                  _buildDetailRow(
                    theme,
                    label: 'Average Sell Price',
                    value: formatCurrency.format(cycle.averageSellPrice),
                  ),
                  _buildDetailRow(
                    theme,
                    label: 'Total Proceeds',
                    value: formatCurrency.format(cycle.totalProceeds),
                  ),
                  _buildDetailRow(
                    theme,
                    label: 'Realized P&L',
                    value:
                        '${cycle.isProfitable ? "+" : ""}${formatCurrency.format(cycle.realizedGainLoss)}',
                    valueColor: cycle.statusColor,
                  ),
                  if (cycle.hasSplits) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Corporate Actions / Stock Splits (${cycle.splitsApplied.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...cycle.splitsApplied.map((split) {
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer
                              .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.call_split,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    split.formattedRatio,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Ex-Date: ${DateFormat.yMMMd().format(split.executionDate)} • Factor: ${split.effectiveMultiplier}x',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    'Orders in this Cycle (${cycle.orders.length})',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...cycle.orders.map((order) {
                    final isBuy = order.side.toLowerCase() == 'buy';
                    final orderQty =
                        order.cumulativeQuantity ?? order.quantity ?? 0.0;
                    final orderPrice = order.averagePrice ?? order.price ?? 0.0;
                    final orderTotal = orderQty * orderPrice;
                    final orderDate = order.createdAt ?? order.updatedAt;

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  isBuy
                                      ? Icons.add_circle_outline
                                      : Icons.remove_circle_outline,
                                  color: isBuy ? Colors.green : Colors.red,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${order.side.toUpperCase()} ${formatNumber.format(orderQty)} shares @ ${formatCurrency.format(orderPrice)}',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (orderDate != null)
                                        Text(
                                          dateFormat.format(orderDate),
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formatCurrency.format(orderTotal),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(
    ThemeData theme, {
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: valueColor ?? theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 365) {
      return '${(duration.inDays / 365).toStringAsFixed(1)} yrs';
    } else if (duration.inDays > 30) {
      return '${(duration.inDays / 30).toStringAsFixed(1)} mos';
    } else if (duration.inDays > 0) {
      return '${duration.inDays} ${duration.inDays == 1 ? "day" : "days"}';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} hrs';
    } else {
      return '${duration.inMinutes} mins';
    }
  }
}
