import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/trade_strategies.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_config.dart';

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

  static String _formatIndicatorNameStatic(String key) {
    final Map<String, String> names = {
      'priceMovement': 'Price Action',
      'momentum': 'RSI',
      'marketDirection': 'Market Direction',
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

  static void showWithConfirmation({
    required BuildContext context,
    required TradeStrategyTemplate template,
    required TradeStrategyConfig? currentConfig,
    required Function(TradeStrategyTemplate) onConfirmLoad,
    VoidCallback? onSearch,
  }) {
    show(context, template, () {
      if (currentConfig != null) {
        final diffs = template.config.getDifferences(currentConfig);
        if (diffs.isEmpty) {
          Navigator.pop(context); // Close sheet
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No changes to apply.')),
          );
          return;
        }

        if (diffs.isNotEmpty) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              icon: const Icon(Icons.playlist_add_check),
              title: Text('Load "${template.name}"?'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('The following settings will change:'),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: diffs.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final key = diffs.keys.elementAt(index);
                          final val = diffs[key]!;

                          // Special handling for Enabled Indicators
                          if (key == 'Enabled Indicators') {
                            final changes = val.split('\n');
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outlineVariant
                                        .withValues(alpha: 0.5)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(key,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface)),
                                  const SizedBox(height: 8),
                                  ...changes.map((change) {
                                    final parts = change.split(': ');
                                    if (parts.length != 2) return Text(change);

                                    final indicatorKey = parts[0];
                                    final transition = parts[
                                        1]; // true -> false or false -> true

                                    final isEnabling =
                                        transition.contains('false -> true');
                                    final prettyName =
                                        _formatIndicatorNameStatic(
                                            indicatorKey);

                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 4.0),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isEnabling
                                                ? Icons.check_circle_outline
                                                : Icons.remove_circle_outline,
                                            size: 14,
                                            color: isEnabling
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              prettyName,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                                decoration: isEnabling
                                                    ? null
                                                    : TextDecoration
                                                        .lineThrough,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isEnabling
                                                  ? Colors.green
                                                      .withValues(alpha: 0.1)
                                                  : Colors.red
                                                      .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              isEnabling ? 'ADDED' : 'REMOVED',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: isEnabling
                                                    ? Colors.green
                                                    : Colors.red,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            );
                          }

                          // Parse "From: x\nTo: y"
                          String? fromVal;
                          String? toVal;
                          if (val.contains('\nTo: ')) {
                            final parts = val.split('\nTo: ');
                            fromVal = parts[0].replaceAll('From: ', '');
                            toVal = parts[1];
                          } else {
                            toVal = val;
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant
                                      .withValues(alpha: 0.5)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(key,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface)),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    if (fromVal != null) ...[
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .errorContainer
                                                .withValues(alpha: 0.2),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            fromVal,
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .error,
                                              decoration:
                                                  TextDecoration.lineThrough,
                                              fontSize: 12,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8.0),
                                        child: Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 16,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primaryContainer
                                              .withValues(alpha: 0.2),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          toVal,
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.check, size: 18),
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Close sheet
                    onConfirmLoad(template);
                  },
                  label: const Text('Apply Strategy'),
                ),
              ],
            ),
          );
          return;
        }
      }

      Navigator.pop(context); // Close sheet
      onConfirmLoad(template);
    }, onSearch: onSearch);
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
              // Header
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDefault
                            ? Colors.amber.withValues(alpha: 0.1)
                            : colorScheme.primaryContainer
                                .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: isDefault
                                ? Colors.amber.withValues(alpha: 0.3)
                                : colorScheme.primary.withValues(alpha: 0.1)),
                      ),
                      child: Icon(
                        isDefault ? Icons.verified_rounded : Icons.bookmark,
                        color:
                            isDefault ? Colors.amber[800] : colorScheme.primary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isDefault)
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                    color: Colors.amber.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                'SYSTEM STRATEGY',
                                style: TextStyle(
                                  color: Colors.amber[900],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          Text(
                            template.name,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  height: 1.1,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            template.description,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Key Metrics Grid
              LayoutBuilder(builder: (context, constraints) {
                final width = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: width,
                      child: _buildDetailMetric(
                          context,
                          "Take Profit",
                          "${config.takeProfitPercent}%",
                          Icons.trending_up,
                          Colors.green,
                          valueSize: 16),
                    ),
                    SizedBox(
                      width: width,
                      child: _buildDetailMetric(
                          context,
                          "Stop Loss",
                          "${config.stopLossPercent}%",
                          Icons.trending_down,
                          Colors.red,
                          valueSize: 16),
                    ),
                    SizedBox(
                      width: width,
                      child: _buildDetailMetric(
                          context,
                          "Risk / Trade",
                          "${(config.riskPerTrade * 100).toStringAsFixed(1)}%",
                          Icons.shield_outlined,
                          Colors.orange,
                          valueSize: 16),
                    ),
                    SizedBox(
                      width: width,
                      child: _buildDetailMetric(
                          context,
                          "Timeframe",
                          config.interval.toUpperCase(),
                          Icons.timer_outlined,
                          colorScheme.primary,
                          valueSize: 16),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 32),

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
                  label: const Text('Search Market Signals'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    iconColor: colorScheme.primary,
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              FilledButton.icon(
                onPressed: onLoad,
                icon: const Icon(Icons.download_rounded),
                label: const Text('Load Strategy Configuration'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24), // Extra bottom padding
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildRuleChip(BuildContext context, String label, IconData? icon,
      {bool isAccent = true, String? tooltip}) {
    final colorScheme = Theme.of(context).colorScheme;
    // Use slightly different colors/styles
    final bg = isAccent
        ? colorScheme.primaryContainer.withValues(alpha: 0.2)
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3);
    final fg = isAccent ? colorScheme.primary : colorScheme.onSurface;
    final border = isAccent
        ? colorScheme.primary.withValues(alpha: 0.2)
        : Colors.transparent;

    Widget chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: fg.withValues(alpha: 0.8)),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: fg,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (tooltip != null) ...[
            const SizedBox(width: 6),
            Icon(Icons.info_outline_rounded,
                size: 14, color: fg.withValues(alpha: 0.6)),
          ]
        ],
      ),
    );
    // ... tooltip wrapper ...
    if (tooltip != null && tooltip.isNotEmpty) {
      return Tooltip(
        message: tooltip,
        triggerMode: TooltipTriggerMode.tap,
        preferBelow: false,
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(color: colorScheme.onInverseSurface, fontSize: 12),
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
      IconData icon, Color color,
      {double valueSize = 13}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Theme.of(context)
                .colorScheme
                .outlineVariant
                .withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color.withValues(alpha: 0.8)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: valueSize,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
