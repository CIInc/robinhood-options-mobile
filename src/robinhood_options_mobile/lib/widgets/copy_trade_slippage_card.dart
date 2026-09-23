import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/copy_trade_record.dart';
import 'package:robinhood_options_mobile/model/copy_trade_slippage_analytics.dart';

/// Card widget displaying Copy-Trading Slippage, Fill Latency, and Return Divergence Analytics
class CopyTradeSlippageCard extends StatelessWidget {
  final List<CopyTradeRecord> trades;
  final List<dynamic>? completedTrades;

  const CopyTradeSlippageCard({
    super.key,
    required this.trades,
    this.completedTrades,
  });

  @override
  Widget build(BuildContext context) {
    final summary = CopyTradeSlippageAnalytics.compute(
      trades: trades,
      completedTrades: completedTrades,
    );

    if (summary.executedTrades == 0) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.speed,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Slippage & Latency Analytics',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'No executed copy trades yet. When your copied trades execute, real-time fill latency, price slippage, and leader return divergence will appear here.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    final currencyFormat = NumberFormat.simpleCurrency();
    final theme = Theme.of(context);

    // Color indicators
    final Color slippageColor;
    if (summary.averageSlippageDollar < -0.001) {
      slippageColor = Colors.green;
    } else if (summary.averageSlippageDollar > 0.001) {
      slippageColor = Colors.orange;
    } else {
      slippageColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    }

    final Color latencyColor;
    if (summary.averageLatencyMs <= 200) {
      latencyColor = Colors.green;
    } else if (summary.averageLatencyMs <= 600) {
      latencyColor = Colors.amber;
    } else {
      latencyColor = Colors.redAccent;
    }

    final Color qualityColor;
    if (summary.executionQualityScore >= 90) {
      qualityColor = Colors.green;
    } else if (summary.executionQualityScore >= 70) {
      qualityColor = Colors.amber;
    } else {
      qualityColor = Colors.redAccent;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Header with Tooltip
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.speed, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Slippage & Divergence Audit',
                      style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                Tooltip(
                  message:
                      'Slippage is the difference between leader price and your fill price.\nLatency is the delay from leader order to your execution.',
                  child: Icon(
                    Icons.info_outline,
                    size: 18,
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Top Hero Metrics Grid
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    context,
                    label: 'Avg Latency',
                    value: '${summary.averageLatencyMs.toStringAsFixed(0)} ms',
                    subtitle: 'Median: ${summary.medianLatencyMs.toStringAsFixed(0)}ms',
                    color: latencyColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    context,
                    label: 'Avg Slippage',
                    value:
                        '${summary.averageSlippageBps >= 0 ? "+" : ""}${summary.averageSlippageBps.toStringAsFixed(1)} bps',
                    subtitle:
                        '${summary.averageSlippageDollar >= 0 ? "+" : ""}${currencyFormat.format(summary.averageSlippageDollar)}/sh',
                    color: slippageColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    context,
                    label: 'Slippage Drag',
                    value: currencyFormat.format(summary.totalSlippageCost),
                    subtitle: summary.totalSlippageCost > 0
                        ? 'Unfavorable drag'
                        : (summary.totalSlippageCost < 0
                            ? 'Favorable price improvement'
                            : 'Zero cost drag'),
                    color: summary.totalSlippageCost > 0
                        ? Colors.redAccent
                        : (summary.totalSlippageCost < 0
                            ? Colors.green
                            : Colors.grey),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    context,
                    label: 'Fill Quality',
                    value:
                        '${summary.executionQualityScore.toStringAsFixed(1)}%',
                    subtitle:
                        '${summary.favorableTradesCount + summary.neutralTradesCount}/${summary.executedTrades} on-target',
                    color: qualityColor,
                  ),
                ),
              ],
            ),

            // Return Divergence Banner (if paired data available)
            if (summary.netReturnDivergencePct != null) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: (summary.netReturnDivergencePct! >= 0
                          ? Colors.green
                          : Colors.red)
                      .withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (summary.netReturnDivergencePct! >= 0
                            ? Colors.green
                            : Colors.red)
                        .withAlpha(80),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Net Return Divergence vs Leader:',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${summary.netReturnDivergencePct! >= 0 ? "+" : ""}${(summary.netReturnDivergencePct! * 100).toStringAsFixed(2)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: summary.netReturnDivergencePct! >= 0
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // Execution Quality Breakdown Bar
            Text(
              'Fill Quality Distribution',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _buildQualityBar(context, summary),
            const SizedBox(height: 12),

            // Latency Distribution Chips
            Text(
              'Latency Breakdown',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6.0,
              runSpacing: 4.0,
              children: summary.latencyBuckets.entries.map((e) {
                final count = e.value;
                return Chip(
                  labelPadding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  visualDensity: VisualDensity.compact,
                  label: Text('${e.key}: $count'),
                  backgroundColor: count > 0
                      ? theme.colorScheme.primaryContainer.withAlpha(60)
                      : theme.disabledColor.withAlpha(20),
                );
              }).toList(),
            ),

            // Leader Comparison Section (if multiple leaders)
            if (summary.byTrader.length > 1) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Slippage by Leader',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...summary.byTrader.entries.map((entry) {
                final t = entry.value;
                final shortId = t.traderId.length > 8
                    ? t.traderId.substring(0, 8)
                    : t.traderId;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Trader: $shortId... (${t.totalTrades} trades)',
                          style: theme.textTheme.bodySmall),
                      Row(
                        children: [
                          Text(
                            '${t.averageLatencyMs.toStringAsFixed(0)}ms',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${t.averageSlippageBps >= 0 ? "+" : ""}${t.averageSlippageBps.toStringAsFixed(1)} bps',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: t.averageSlippageBps > 0
                                  ? Colors.orange
                                  : (t.averageSlippageBps < 0
                                      ? Colors.green
                                      : Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required String label,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.dividerColor.withAlpha(50),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityBar(
      BuildContext context, CopyTradeSlippageSummary summary) {
    final total = summary.executedTrades;
    if (total == 0) return const SizedBox.shrink();

    final favorableFlex = (summary.favorableTradesCount * 1000 ~/ total);
    final neutralFlex = (summary.neutralTradesCount * 1000 ~/ total);
    final unfavorableFlex = (summary.unfavorableTradesCount * 1000 ~/ total);

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                if (favorableFlex > 0)
                  Expanded(
                    flex: favorableFlex,
                    child: Container(color: Colors.green),
                  ),
                if (neutralFlex > 0)
                  Expanded(
                    flex: neutralFlex,
                    child: Container(color: Colors.blue),
                  ),
                if (unfavorableFlex > 0)
                  Expanded(
                    flex: unfavorableFlex,
                    child: Container(color: Colors.orange),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildLegendItem(
                'Favorable: ${summary.favorableTradesCount}', Colors.green),
            _buildLegendItem(
                'Exact: ${summary.neutralTradesCount}', Colors.blue),
            _buildLegendItem(
                'Unfavorable: ${summary.unfavorableTradesCount}', Colors.orange),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}
