import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_config.dart';
import 'package:robinhood_options_mobile/model/strategy_archetype.dart';
import 'package:robinhood_options_mobile/widgets/strategy_archetype_card.dart';

/// Streamlined 4-control progressive disclosure view for automated trading.
///
/// Surfaces only the essential controls for everyday investors:
/// 1. Master Control (Auto-Trading toggle, Paper/Live mode, Emergency Stop)
/// 2. 1-Tap Strategy Archetype selector
/// 3. Capital Budget allocation slider
/// 4. 3-state Risk Comfort Level toggle (Conservative, Balanced, Aggressive)
///
/// Switching to [QuantProSettingsView] preserves all underlying custom parameters.
class SimplifiedTradingControlsWidget extends StatelessWidget {
  final AgenticTradingConfig config;
  final String? selectedTemplateId;
  final bool emergencyStopActivated;
  final bool isAgenticTradingEnabled;
  final String? formattedDollarCap;
  final Widget masterControlCard;
  final ValueChanged<StrategyArchetype> onApplyArchetype;
  final ValueChanged<StrategyArchetype> onInspectArchetype;
  final ValueChanged<double> onCapitalAllocationChanged;
  final ValueChanged<RiskComfortLevel> onRiskComfortChanged;
  final VoidCallback onActivateEmergencyStop;
  final VoidCallback onSwitchToQuantPro;

  const SimplifiedTradingControlsWidget({
    super.key,
    required this.config,
    required this.selectedTemplateId,
    required this.emergencyStopActivated,
    required this.isAgenticTradingEnabled,
    this.formattedDollarCap,
    required this.masterControlCard,
    required this.onApplyArchetype,
    required this.onInspectArchetype,
    required this.onCapitalAllocationChanged,
    required this.onRiskComfortChanged,
    required this.onActivateEmergencyStop,
    required this.onSwitchToQuantPro,
  });

  static IconData _iconForRiskLevel(RiskComfortLevel level) {
    switch (level) {
      case RiskComfortLevel.conservative:
        return Icons.shield_outlined;
      case RiskComfortLevel.balanced:
        return Icons.balance;
      case RiskComfortLevel.aggressive:
        return Icons.bolt;
    }
  }

  static String _formatPercent(double value) {
    return value % 1 == 0
        ? '${value.toInt()}%'
        : '${value.toStringAsFixed(1)}%';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final strategy = config.strategyConfig;
    final allocationPercent =
        (strategy.maxPortfolioConcentration * 100).clamp(5.0, 100.0);
    final inferredRisk = RiskComfortLevel.fromStrategyConfig(strategy);
    final matchesPreset =
        RiskComfortLevel.matchesPreset(strategy, inferredRisk);

    final activeArchetype =
        StrategyArchetypes.curated.cast<StrategyArchetype?>().firstWhere(
              (a) =>
                  selectedTemplateId == 'default_${a!.id}' ||
                  selectedTemplateId == a.id,
              orElse: () => null,
            );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Master Control (Status header + Paper/Live + Always-available Emergency Stop)
        masterControlCard,
        if (!config.autoTradeEnabled && !emergencyStopActivated) ...[
          const SizedBox(height: 10),
          Semantics(
            label: 'Activate Emergency Stop to halt all automated trading',
            button: true,
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const ValueKey('simplified-emergency-stop-button'),
                onPressed: onActivateEmergencyStop,
                icon: Icon(Icons.emergency_outlined,
                    size: 18, color: colorScheme.error),
                label: Text(
                  'Activate Emergency Stop',
                  style: TextStyle(
                    color: colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: colorScheme.error.withValues(alpha: 0.45)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),

        // 2. Strategy Selection: 1-Tap Archetype Selector
        _buildSectionHeader(
          context,
          icon: Icons.auto_awesome_rounded,
          title: '1. Strategy Selection',
          subtitle: '1-Tap Curated Archetypes with Walk-Forward Validation',
          trailing: activeArchetype != null
              ? IconButton(
                  tooltip: 'Inspect ${activeArchetype.name} details',
                  onPressed: () => onInspectArchetype(activeArchetype),
                  icon: Icon(
                    Icons.info_outline,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                )
              : null,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 195,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: StrategyArchetypes.curated.length,
            itemBuilder: (context, index) {
              final archetype = StrategyArchetypes.curated[index];
              final isSelected =
                  selectedTemplateId == 'default_${archetype.id}' ||
                      selectedTemplateId == archetype.id;
              final isLocked = archetype.tradingMode == TradingMode.reasoning &&
                  !isAgenticTradingEnabled;

              return SizedBox(
                width: 280,
                child: StrategyArchetypeCard(
                  archetype: archetype,
                  isSelected: isSelected,
                  isLocked: isLocked,
                  onTap: () {
                    if (isLocked) {
                      onInspectArchetype(archetype);
                    } else {
                      onApplyArchetype(archetype);
                    }
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // 3. Capital Allocation Budget Slider
        Card(
          key: const ValueKey('simplified-capital-allocation-card'),
          elevation: 0,
          margin: EdgeInsets.zero,
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: colorScheme.outline.withValues(alpha: 0.15),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  label:
                      'Capital Budget: ${_formatPercent(allocationPercent)} of portfolio equity'
                      '${formattedDollarCap != null ? ", approximately $formattedDollarCap" : ""}',
                  child: Row(
                    children: [
                      Icon(Icons.pie_chart_outline,
                          size: 20, color: colorScheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '2. Capital Budget',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Max portfolio equity allocated to auto-trading',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          formattedDollarCap != null
                              ? '${_formatPercent(allocationPercent)} • $formattedDollarCap'
                              : _formatPercent(allocationPercent),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Slider(
                  key: const ValueKey('capital-allocation-slider'),
                  value: allocationPercent,
                  min: 5,
                  max: 100,
                  divisions: 19,
                  label: _formatPercent(allocationPercent),
                  onChanged: (value) =>
                      onCapitalAllocationChanged(value / 100.0),
                ),
                SingleChildScrollView(
                  key: const ValueKey('capital-allocation-chips-scroll'),
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final preset in const [10, 25, 50, 75, 100])
                        Padding(
                          padding:
                              EdgeInsets.only(right: preset == 100 ? 0 : 8),
                          child: ChoiceChip(
                            label: Text('$preset%'),
                            selected: (allocationPercent - preset).abs() < 0.5,
                            visualDensity: VisualDensity.compact,
                            onSelected: (_) =>
                                onCapitalAllocationChanged(preset / 100.0),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 4. Risk Comfort Level (3-state toggle)
        Card(
          key: const ValueKey('simplified-risk-comfort-card'),
          elevation: 0,
          margin: EdgeInsets.zero,
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: colorScheme.outline.withValues(alpha: 0.15),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.shield_outlined,
                        size: 20, color: colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '3. Risk Comfort Level',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Auto-tunes stop-loss, profit target, and share sizing',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (!matchesPreset) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer
                          .withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Custom Quant Pro risk bounds active (${_formatPercent(strategy.stopLossPercent)} SL / ${_formatPercent(strategy.takeProfitPercent)} TP / ${strategy.tradeQuantity} sh). Tap a preset below to override.',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<RiskComfortLevel>(
                    key: const ValueKey('risk-comfort-segmented-button'),
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                    emptySelectionAllowed: !matchesPreset,
                    segments: RiskComfortLevel.values
                        .map(
                          (level) => ButtonSegment<RiskComfortLevel>(
                            value: level,
                            icon: Icon(_iconForRiskLevel(level), size: 16),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(level.label),
                            ),
                          ),
                        )
                        .toList(),
                    selected: matchesPreset
                        ? {inferredRisk}
                        : const <RiskComfortLevel>{},
                    onSelectionChanged: (selection) {
                      if (selection.isEmpty) return;
                      onRiskComfortChanged(selection.first);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Semantics(
                  label:
                      'Current risk tuning: Stop Loss ${_formatPercent(strategy.stopLossPercent)}, '
                      'Take Profit ${_formatPercent(strategy.takeProfitPercent)}, '
                      'Trade Size ${strategy.tradeQuantity} shares',
                  child: SingleChildScrollView(
                    key: const ValueKey('risk-comfort-metrics-scroll'),
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildRiskMetricPill(
                          context,
                          label: 'Stop Loss',
                          value: _formatPercent(strategy.stopLossPercent),
                          color: Colors.redAccent,
                        ),
                        const SizedBox(width: 8),
                        _buildRiskMetricPill(
                          context,
                          label: 'Take Profit',
                          value: _formatPercent(strategy.takeProfitPercent),
                          color: Colors.green,
                        ),
                        const SizedBox(width: 8),
                        _buildRiskMetricPill(
                          context,
                          label: 'Trade Size',
                          value: '${strategy.tradeQuantity} sh',
                          color: colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Quant Pro Discovery Callout
        Card(
          key: const ValueKey('switch-to-quant-pro-card'),
          elevation: 0,
          margin: EdgeInsets.zero,
          color: colorScheme.primaryContainer.withValues(alpha: 0.18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: colorScheme.primary.withValues(alpha: 0.25),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.science_outlined,
                        size: 18, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Need full quantitative control?',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Unlock all 19 technical indicators, custom formulas, 5-tier GEX structural stops, sector caps, backtesting, and OEM background journals without losing your current settings.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    key: const ValueKey('switch-to-quant-pro-button'),
                    onPressed: onSwitchToQuantPro,
                    icon: const Icon(Icons.tune, size: 16),
                    label: const Text('Switch to Quant Pro'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildRiskMetricPill(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
