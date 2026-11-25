import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_config.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/model/strategy_archetype.dart';

/// Modal bottom sheet presenting in-depth strategy archetype parameters,
/// walk-forward validation statistics, philosophy, and apply / clone actions.
class StrategyArchetypeDetailBottomSheet extends StatelessWidget {
  final StrategyArchetype archetype;
  final bool isCurrentlyActive;
  final Function(StrategyArchetype) onApply;
  final Function(StrategyArchetype, String)? onClone;
  final bool isLocked;
  final VoidCallback? onUnlock;

  const StrategyArchetypeDetailBottomSheet({
    super.key,
    required this.archetype,
    required this.onApply,
    this.isCurrentlyActive = false,
    this.onClone,
    this.isLocked = false,
    this.onUnlock,
  });

  static void show({
    required BuildContext context,
    required StrategyArchetype archetype,
    required Function(StrategyArchetype) onApply,
    bool isCurrentlyActive = false,
    Function(StrategyArchetype, String)? onClone,
    bool isLocked = false,
    VoidCallback? onUnlock,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StrategyArchetypeDetailBottomSheet(
        archetype: archetype,
        isCurrentlyActive: isCurrentlyActive,
        onApply: onApply,
        onClone: onClone,
        isLocked: isLocked,
        onUnlock: onUnlock,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final metrics = archetype.walkForwardMetrics;
    final config = archetype.config;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: archetype.accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      archetype.icon,
                      color: archetype.accentColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                archetype.name,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (isCurrentlyActive) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: archetype.accentColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'ACTIVE',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          archetype.tag,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: archetype.accentColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Badges Row: Mode & Target Regime
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildTagBadge(
                    context: context,
                    icon: archetype.tradingMode == TradingMode.reasoning
                        ? Icons.psychology
                        : Icons.alt_route,
                    label: archetype.tradingMode == TradingMode.reasoning
                        ? 'Reasoning AI Mode'
                        : 'Systematic Mode',
                    color: archetype.tradingMode == TradingMode.reasoning
                        ? Colors.purple
                        : Colors.teal,
                  ),
                  _buildTagBadge(
                    context: context,
                    icon: Icons.speed,
                    label: archetype.targetMarketRegime,
                    color: colorScheme.secondary,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Summary & Philosophy Card
              Card(
                elevation: 0,
                color:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: colorScheme.outline.withValues(alpha: 0.12),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lightbulb_outline,
                              size: 18, color: archetype.accentColor),
                          const SizedBox(width: 8),
                          Text(
                            'Strategy Philosophy',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: archetype.accentColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        archetype.detailedPhilosophy,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Walk-Forward Backtest Validation Section
              Row(
                children: [
                  Icon(Icons.verified, size: 20, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Historical Walk-Forward Benchmark (1-Year)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Card(
                elevation: 0,
                color:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: colorScheme.outline.withValues(alpha: 0.12),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricItem(
                              context: context,
                              label: 'Win Rate',
                              value: '${metrics.winRate.toStringAsFixed(1)}%',
                              color: Colors.green,
                            ),
                          ),
                          Expanded(
                            child: _buildMetricItem(
                              context: context,
                              label: 'Profit Factor',
                              value: metrics.profitFactor.toStringAsFixed(2),
                              color: Colors.blue,
                            ),
                          ),
                          Expanded(
                            child: _buildMetricItem(
                              context: context,
                              label: 'Max Drawdown',
                              value:
                                  '${metrics.maxDrawdownPercent.toStringAsFixed(1)}%',
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricItem(
                              context: context,
                              label: 'Sharpe Ratio',
                              value: metrics.sharpeRatio.toStringAsFixed(2),
                              color: colorScheme.primary,
                            ),
                          ),
                          Expanded(
                            child: _buildMetricItem(
                              context: context,
                              label: 'Total Return',
                              value:
                                  '+${metrics.totalReturnPercent.toStringAsFixed(1)}%',
                              color: Colors.green,
                            ),
                          ),
                          Expanded(
                            child: _buildMetricItem(
                              context: context,
                              label: 'Sample Trades',
                              value: metrics.totalTrades.toString(),
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline,
                              size: 14, color: colorScheme.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Out-of-sample quantitative baseline evaluated on historical SPY large-cap data. Individual forward performance varies based on selected watchlist symbols and live market conditions.',
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.8),
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Key Invariants & Risk Bounds
              Row(
                children: [
                  Icon(Icons.tune, size: 20, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pre-Configured Risk Bounds & Stops',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Card(
                elevation: 0,
                color:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: colorScheme.outline.withValues(alpha: 0.12),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildParameterRow(
                        context: context,
                        label: 'Take Profit / Stop Loss',
                        value:
                            '+${config.takeProfitPercent}% / -${config.stopLossPercent}%',
                      ),
                      _buildParameterRow(
                        context: context,
                        label: config.isDynamicSizing
                            ? 'Trade Sizing (Dynamic Risk)'
                            : (config.isTargetDollar
                                ? 'Trade Sizing (Target Dollar)'
                                : 'Trade Sizing (Fixed Shares)'),
                        value: config.isDynamicSizing
                            ? '${(config.riskPerTrade * 100).toStringAsFixed(1)}% Risk • ${config.atrMultiplier}x ATR'
                            : (config.isTargetDollar
                                ? '\$${config.targetDollarAllocation.toStringAsFixed(0)} per order'
                                : '${config.tradeQuantity} shares per order'),
                      ),
                      _buildParameterRow(
                        context: context,
                        label:
                            'Position Sizing (${config.positionLimitMode.label})',
                        value: config.isMaxSharesPositionLimit
                            ? '${config.maxPositionSize} shares ceiling'
                            : '${(config.maxPortfolioConcentration * 100).toInt()}% of Portfolio ceiling',
                      ),
                      _buildParameterRow(
                        context: context,
                        label: 'Total Capital Budget',
                        value:
                            '${(config.totalCapitalBudgetPercent * 100).toInt()}% of Portfolio',
                      ),
                      _buildParameterRow(
                        context: context,
                        label: 'Daily Trade Limit',
                        value: '${config.dailyTradeLimit} trades / day',
                      ),
                      _buildParameterRow(
                        context: context,
                        label: 'Drawdown Protection',
                        value: config.enableDrawdownProtection
                            ? 'Halt at -${(config.maxDrawdown * 100).toInt()}% Drawdown'
                            : 'Disabled',
                      ),
                      _buildParameterRow(
                        context: context,
                        label: 'Trailing Stop',
                        value: config.trailingStopEnabled
                            ? 'Enabled (${config.trailingStopPercent}%)'
                            : 'Disabled',
                      ),
                      _buildParameterRow(
                        context: context,
                        label: 'Trailing Peak Stop',
                        value: config.enableTrailingPeakStop
                            ? 'Enabled (${config.trailingPeakStopPercent}% from Peak)'
                            : 'Disabled',
                      ),
                      _buildParameterRow(
                        context: context,
                        label: '5-Tier GEX Stops',
                        value: config.enableGexStructuralStops
                            ? 'Enabled (Spot < nTrans)'
                            : 'Disabled',
                      ),
                      _buildParameterRow(
                        context: context,
                        label: 'Catastrophic Stop',
                        value: config.enableCatastrophicStop
                            ? 'Hard Stop at -${config.catastrophicStopPercent}%'
                            : 'Disabled',
                      ),
                      _buildParameterRow(
                        context: context,
                        label: 'Active Indicators',
                        value:
                            '${config.enabledIndicators.values.where((v) => v).length} enabled',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (isLocked) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.purple.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline,
                          size: 20, color: Colors.purple),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Autonomous Agentic Trading (AI) is disabled in Beta Labs. Enable it to apply and run this archetype.',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Clone Preset'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _promptCloneArchetype(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      icon: Icon(
                        isLocked ? Icons.lock_open_rounded : Icons.bolt_rounded,
                        size: 18,
                      ),
                      label: Text(
                        isLocked
                            ? 'Unlock in Beta Labs'
                            : isCurrentlyActive
                                ? 'Re-Apply Archetype'
                                : 'Apply Archetype',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: archetype.accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: isLocked
                          ? (onUnlock != null
                              ? () {
                                  Navigator.pop(context);
                                  onUnlock!();
                                }
                              : null)
                          : () => _confirmAndApply(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTagBadge({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem({
    required BuildContext context,
    required String label,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildParameterRow({
    required BuildContext context,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 3,
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmAndApply(BuildContext context) {
    AgenticTradingProvider? provider;
    try {
      provider = Provider.of<AgenticTradingProvider>(context, listen: false);
    } catch (_) {}

    final currentStrategy = provider?.config.strategyConfig;
    final currentMaxPosition = currentStrategy?.maxPositionSize ?? 100;
    final currentConcentration =
        ((currentStrategy?.maxPortfolioConcentration ?? 0.5) * 100).toInt();
    final archetypeMaxPosition = archetype.config.maxPositionSize;
    final archetypeConcentration =
        (archetype.config.maxPortfolioConcentration * 100).toInt();

    final isSizingConflict =
        archetype.config.enableDynamicPositionSizing && currentMaxPosition < 15;

    bool keepSafetyLimits = true;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          final colorScheme = Theme.of(context).colorScheme;
          return AlertDialog(
            icon: Icon(archetype.icon, color: archetype.accentColor, size: 32),
            title: Text('Apply "${archetype.name}"?'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Review configuration changes before applying this archetype:',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Comparison table
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildDiffRow(
                            'Trading Mode',
                            currentStrategy != null
                                ? (provider!.config.tradingMode ==
                                        TradingMode.reasoning
                                    ? 'Reasoning'
                                    : 'Systematic')
                                : 'Current',
                            archetype.tradingMode == TradingMode.reasoning
                                ? 'Reasoning AI'
                                : 'Systematic'),
                        const Divider(height: 12),
                        _buildDiffRow(
                            'Trade Sizing',
                            currentStrategy?.positionSizingMode.label ??
                                'Fixed Shares',
                            archetype.config.positionSizingMode.label),
                        const Divider(height: 12),
                        _buildDiffRow(
                            'Risk Per Trade',
                            '${((currentStrategy?.riskPerTrade ?? 0.01) * 100).toStringAsFixed(1)}%',
                            '${(archetype.config.riskPerTrade * 100).toStringAsFixed(1)}%'),
                        const Divider(height: 12),
                        _buildDiffRow(
                            'Stop Loss',
                            '-${currentStrategy?.stopLossPercent ?? 5.0}%',
                            '-${archetype.config.stopLossPercent}%'),
                        const Divider(height: 12),
                        _buildDiffRow(
                            'Position Sizing',
                            currentStrategy != null
                                ? (currentStrategy.isMaxPercentPositionLimit
                                    ? '$currentConcentration%'
                                    : '$currentMaxPosition sh')
                                : '$currentMaxPosition sh',
                            archetype.config.isMaxPercentPositionLimit
                                ? '$archetypeConcentration%'
                                : '$archetypeMaxPosition sh'),
                      ],
                    ),
                  ),
                  if (isSizingConflict) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              size: 18, color: Colors.amber),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Sizing Alert: Your current Max Position Size ($currentMaxPosition sh) is very low. Dynamic Sizing typically calculates 10–25+ shares. Orders may be declined unless you increase Max Position Size.',
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.3,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: keepSafetyLimits,
                    onChanged: (val) =>
                        setState(() => keepSafetyLimits = val ?? true),
                    title: const Text(
                      'Keep personal Safety Limits',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Preserves your current Max Position Size ($currentMaxPosition sh) and Max Concentration ($currentConcentration%).',
                      style: const TextStyle(fontSize: 11),
                    ),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: archetype.accentColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(dialogContext); // Close dialog
                  Navigator.pop(context); // Close bottom sheet
                  if (keepSafetyLimits && currentStrategy != null) {
                    final modifiedArchetype = archetype.copyWith(
                      config: archetype.config.copyWith(
                        positionLimitMode: currentStrategy.positionLimitMode,
                        maxPositionSize: currentStrategy.maxPositionSize,
                        maxPortfolioConcentration:
                            currentStrategy.maxPortfolioConcentration,
                        totalCapitalBudgetPercent:
                            currentStrategy.totalCapitalBudgetPercent,
                      ),
                    );
                    onApply(modifiedArchetype);
                  } else {
                    onApply(archetype);
                  }
                },
                child: const Text('Confirm & Apply'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDiffRow(String label, String currentVal, String newVal) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            currentVal,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ),
        const Icon(Icons.arrow_forward, size: 10, color: Colors.grey),
        Expanded(
          flex: 3,
          child: Text(
            newVal,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  void _promptCloneArchetype(BuildContext context) {
    final controller =
        TextEditingController(text: '${archetype.name} (Custom)');
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.copy_all_outlined, size: 28),
        title: const Text('Clone to Custom Preset'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create an editable copy of this archetype in your custom strategy templates.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Template Name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final customName = controller.text.trim();
              if (customName.isNotEmpty) {
                Navigator.pop(dialogContext);
                Navigator.pop(context);
                if (onClone != null) {
                  onClone!(archetype, customName);
                }
              }
            },
            child: const Text('Save Custom Preset'),
          ),
        ],
      ),
    );
  }
}
