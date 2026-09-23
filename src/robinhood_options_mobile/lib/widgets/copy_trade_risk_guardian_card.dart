import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/copy_trade_record.dart';
import 'package:robinhood_options_mobile/model/investor_group.dart';

/// Card displaying Automated Copy-Trading Risk Guardian status, telemetry,
/// and quick-action reset controls on the Copy Trading Dashboard.
class CopyTradeRiskGuardianCard extends StatelessWidget {
  final List<CopyTradeRecord> trades;
  final CopyTradeSettings? settings;
  final VoidCallback? onReset;
  final VoidCallback? onConfigure;

  const CopyTradeRiskGuardianCard({
    super.key,
    required this.trades,
    this.settings,
    this.onReset,
    this.onConfigure,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTripped = settings?.isRiskGuardianTripped ?? false;
    final tripReason = settings?.riskGuardianTripReason;
    final trippedAt = settings?.riskGuardianTrippedAt;

    final abortedTrades = trades.where((t) => t.isAborted).toList();
    final slippageAborted = trades.where((t) => t.isAbortedMaxSlippage).length;
    final allocAborted = trades.where((t) => t.isAbortedAllocation).length;
    final guardianTrippedAborted =
        trades.where((t) => t.isAbortedRiskGuardian).length;

    final maxAllocationText = settings?.maxAllocationPerTrade != null
        ? '\$${settings!.maxAllocationPerTrade!.toStringAsFixed(0)}'
        : (settings?.maxAllocationPct != null
            ? '${settings!.maxAllocationPct!.toStringAsFixed(1)}%'
            : 'Default');

    final slippageText = settings?.maxSlippageBps != null
        ? '${settings!.maxSlippageBps!.toStringAsFixed(0)} bps (${(settings!.maxSlippageBps! / 100).toStringAsFixed(2)}%)'
        : '75 bps (0.75%)';

    final autoDisconnectEnabled =
        settings?.autoDisconnectOnDivergence ?? false;
    final autoDisconnectText = autoDisconnectEnabled
        ? 'Active (DD: ${settings?.maxLeaderDrawdownPct?.toStringAsFixed(0) ?? 15}%, Div: ${settings?.maxReturnDivergencePct?.toStringAsFixed(0) ?? 5}%)'
        : 'Off';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isTripped
            ? BorderSide(color: theme.colorScheme.error, width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Icon(
                  isTripped ? Icons.gpp_bad : Icons.gpp_good,
                  color: isTripped
                      ? theme.colorScheme.error
                      : (theme.brightness == Brightness.dark
                          ? Colors.tealAccent
                          : Colors.teal),
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Risk Guardian',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Follower Capital & Execution Protection',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isTripped
                        ? theme.colorScheme.errorContainer
                        : (theme.brightness == Brightness.dark
                            ? Colors.teal.withValues(alpha: 0.25)
                            : Colors.teal.shade50),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isTripped
                          ? theme.colorScheme.error
                          : Colors.teal.shade300,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    isTripped ? 'CIRCUIT TRIPPED' : 'PROTECTING',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isTripped
                          ? theme.colorScheme.onErrorContainer
                          : (theme.brightness == Brightness.dark
                              ? Colors.tealAccent
                              : Colors.teal.shade800),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Tripped Alert Banner
            if (isTripped) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: theme.colorScheme.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Copy Trading Auto-Disconnected',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tripReason ?? 'Circuit breaker tripped by Risk Guardian.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                    if (trippedAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Tripped: ${DateFormat('MMM dd, yyyy HH:mm').format(trippedAt)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer
                              .withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                    if (onReset != null) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: onReset,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.error,
                            foregroundColor: theme.colorScheme.onError,
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.restart_alt, size: 16),
                          label: const Text('Reset Guardian & Reconnect'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Guardrail Metric Chips
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    context,
                    title: 'Max Allocation',
                    value: maxAllocationText,
                    subtitle: 'Cap per trade',
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    context,
                    title: 'Max Slippage',
                    value: slippageText,
                    subtitle: 'Abort threshold',
                    icon: Icons.price_check,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    context,
                    title: 'Auto-Disconnect',
                    value: autoDisconnectEnabled ? 'Enabled' : 'Disabled',
                    subtitle: autoDisconnectText,
                    icon: Icons.link_off,
                  ),
                ),
              ],
            ),

            // Aborted Orders Protected Banner
            if (abortedTrades.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shield,
                        size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Protected from ${abortedTrades.length} adverse orders (${slippageAborted > 0 ? '$slippageAborted slippage' : ''}${slippageAborted > 0 && allocAborted > 0 ? ', ' : ''}${allocAborted > 0 ? '$allocAborted capital cap' : ''}${guardianTrippedAborted > 0 ? ', $guardianTrippedAborted circuit trip' : ''})',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: theme.hintColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.hintColor,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitle,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.hintColor,
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
