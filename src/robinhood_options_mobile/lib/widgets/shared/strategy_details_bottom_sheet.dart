import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/trade_strategies.dart';

class StrategyDetailsBottomSheet extends StatelessWidget {
  final TradeStrategyTemplate template;
  final VoidCallback onLoad;
  final VoidCallback? onSearch;

  const StrategyDetailsBottomSheet({
    super.key,
    required this.template,
    required this.onLoad,
    this.onSearch,
  });

  static void show(
      BuildContext context, TradeStrategyTemplate template, VoidCallback onLoad,
      {VoidCallback? onSearch}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => StrategyDetailsBottomSheet(
        template: template,
        onLoad: onLoad,
        onSearch: onSearch,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDefault = template.id.startsWith('default_');
    final config = template.config;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDefault
                          ? Colors.amber.withValues(alpha: 0.1)
                          : colorScheme.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isDefault ? Icons.verified_rounded : Icons.bookmark,
                      color:
                          isDefault ? Colors.amber[700] : colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          template.name,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        if (isDefault)
                          Text(
                            'System Strategy',
                            style: TextStyle(
                              color: Colors.amber[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                template.description,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),

              // Key Metrics
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildDetailMetric(
                      context,
                      "Take Profit",
                      "${config.takeProfitPercent}%",
                      Icons.trending_up,
                      Colors.green),
                  _buildDetailMetric(
                      context,
                      "Stop Loss",
                      "${config.stopLossPercent}%",
                      Icons.trending_down,
                      Colors.red),
                  _buildDetailMetric(
                      context,
                      "Risk / Trade",
                      "${(config.riskPerTrade * 100).toStringAsFixed(1)}%",
                      Icons.shield_outlined,
                      Colors.orange),
                  _buildDetailMetric(context, "Interval", config.interval,
                      Icons.timer_outlined, colorScheme.primary),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // Entry Rules
              _buildSectionTitle(context, "Entry Rules"),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildRuleChip(
                    context,
                    config.requireAllIndicatorsGreen
                        ? "All Indicators Match"
                        : "Min Strength: ${config.minSignalStrength.toStringAsFixed(0)}%",
                    Icons.verified_user_outlined,
                  ),
                  ...config.enabledIndicators.entries
                      .where((e) => e.value)
                      .map((e) => _buildRuleChip(
                            context,
                            _formatIndicatorName(e.key),
                            Icons.check_circle_outline,
                            isAccent: false,
                            tooltip: config.indicatorReasons[e.key],
                          )),
                  ...config.customIndicators.map((c) => _buildRuleChip(
                        context,
                        c.name,
                        Icons.auto_fix_high,
                        isAccent: false,
                      )),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // Exit Rules
              _buildSectionTitle(context, "Exit Rules"),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (config.trailingStopEnabled)
                    _buildRuleChip(
                      context,
                      "Trailing Stop: ${config.trailingStopPercent}%",
                      Icons.trending_up,
                    ),
                  if (config.timeBasedExitEnabled)
                    _buildRuleChip(
                      context,
                      "Exit after ${config.timeBasedExitMinutes}m",
                      Icons.timer,
                    ),
                  if (config.marketCloseExitEnabled)
                    _buildRuleChip(
                      context,
                      "Close ${config.marketCloseExitMinutes}m before bell",
                      Icons.access_time,
                    ),
                  if (config.enablePartialExits && config.exitStages.isNotEmpty)
                    _buildRuleChip(
                      context,
                      "Partial Exits: ${config.exitStages.length} stages",
                      Icons.call_split,
                    ),
                  if (!config.trailingStopEnabled &&
                      !config.timeBasedExitEnabled &&
                      !config.marketCloseExitEnabled &&
                      !config.enablePartialExits)
                    _buildRuleChip(context, "Standard TP/SL only",
                        Icons.check_box_outline_blank,
                        isAccent: false),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // Execution & Filters
              _buildSectionTitle(context, "Execution & Filters"),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (config.symbolFilter.isNotEmpty) ...[
                    ...config.symbolFilter.take(20).map((s) => _buildRuleChip(
                          context,
                          s,
                          null,
                          isAccent: false,
                        )),
                    if (config.symbolFilter.length > 20)
                      _buildRuleChip(
                        context,
                        "+${config.symbolFilter.length - 20} more",
                        Icons.add,
                        isAccent: true,
                      ),
                  ] else
                    _buildRuleChip(
                      context,
                      "All Symbols",
                      Icons.public,
                      isAccent: false,
                    ),
                  if (config.enableDynamicPositionSizing)
                    _buildRuleChip(
                      context,
                      "Dynamic Sizing (ATR ${config.atrMultiplier}x)",
                      Icons.show_chart,
                    ),
                ],
              ),

              const SizedBox(height: 32),
              if (onSearch != null) ...[
                OutlinedButton.icon(
                  onPressed: onSearch,
                  icon: const Icon(Icons.search),
                  label: const Text('Search Signals'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              FilledButton.icon(
                onPressed: onLoad,
                icon: const Icon(Icons.download_rounded),
                label: const Text('Load Strategy'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildRuleChip(BuildContext context, String label, IconData? icon,
      {bool isAccent = true, String? tooltip}) {
    final colorScheme = Theme.of(context).colorScheme;
    final bg = isAccent
        ? colorScheme.secondaryContainer.withValues(alpha: 0.3)
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3);
    final fg = isAccent ? colorScheme.secondary : colorScheme.onSurface;

    Widget chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isAccent
              ? colorScheme.secondary.withValues(alpha: 0.2)
              : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: fg,
              ),
            ),
          ),
          if (tooltip != null) ...[
            const SizedBox(width: 4),
            Icon(Icons.info_outline,
                size: 12, color: fg.withValues(alpha: 0.7)),
          ]
        ],
      ),
    );

    if (tooltip != null && tooltip.isNotEmpty) {
      return Tooltip(
        message: tooltip,
        triggerMode: TooltipTriggerMode.tap,
        preferBelow: false,
        child: chip,
      );
    }
    return chip;
  }

  String _formatIndicatorName(String key) {
    final Map<String, String> names = {
      'priceMovement': 'Price Action',
      'momentum': 'RSI',
      'marketDirection': 'Market Direction (SMA)',
      'volume': 'Volume',
      'macd': 'MACD',
      'bollingerBands': 'Bollinger Bands',
      'stochastic': 'Stochastic',
      'atr': 'ATR',
      'obv': 'OBV',
      'vwap': 'VWAP',
      'adx': 'ADX',
      'williamsR': 'Williams %R',
      'ichimoku': 'Ichimoku',
      'cci': 'CCI',
      'parabolicSar': 'Parabolic SAR',
    };
    return names[key] ?? key;
  }

  Widget _buildDetailMetric(BuildContext context, String label, String value,
      IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
