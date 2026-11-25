import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_config.dart';
import 'package:robinhood_options_mobile/model/strategy_archetype.dart';

/// Strategy Archetype Card
///
/// Surfaces curated strategy presets with empirical Walk-Forward Performance Badges,
/// risk bounds, and archetype inspection.
class StrategyArchetypeCard extends StatelessWidget {
  final StrategyArchetype archetype;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onQuickApply;
  final bool isLocked;

  const StrategyArchetypeCard({
    super.key,
    required this.archetype,
    required this.onTap,
    this.isSelected = false,
    this.onQuickApply,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final semanticsText = '${archetype.name} Archetype, ${archetype.tag}, '
        '${archetype.tradingMode == TradingMode.reasoning ? "Autonomous AI" : "Systematic rule-based"}, '
        'Target Regime: ${archetype.targetMarketRegime}. '
        '${isSelected ? "Currently active strategy." : "Tap to inspect or apply."}';

    return Semantics(
      label: semanticsText,
      button: true,
      selected: isSelected,
      child: Card(
        elevation: isSelected ? 3 : 0,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected
                ? archetype.accentColor
                : colorScheme.outline.withValues(alpha: 0.15),
            width: isSelected ? 2 : 1,
          ),
        ),
        color: isSelected
            ? archetype.accentColor.withValues(alpha: 0.08)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Row: Icon, Tag, and Active Indicator
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: archetype.accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        archetype.icon,
                        color: archetype.accentColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  archetype.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    height: 1.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isLocked) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: colorScheme.outline
                                        .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.lock_outline,
                                          size: 10,
                                          color: colorScheme.onSurfaceVariant),
                                      const SizedBox(width: 3),
                                      Text(
                                        'BETA',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 9,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else if (isSelected) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: archetype.accentColor,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'ACTIVE',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 9,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            archetype.tag,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: archetype.accentColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Description
                Text(
                  archetype.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),

                // Strategy Trait Badges (Mode & Target Market Regime)
                Row(
                  children: [
                    _buildTraitChip(
                      context,
                      icon: archetype.tradingMode == TradingMode.reasoning
                          ? Icons.psychology_outlined
                          : Icons.tune,
                      label: archetype.tradingMode == TradingMode.reasoning
                          ? 'Gemini AI'
                          : 'Systematic',
                      color: archetype.tradingMode == TradingMode.reasoning
                          ? Colors.purple
                          : Colors.teal,
                    ),
                    const SizedBox(width: 6),
                    _buildTraitChip(
                      context,
                      icon: Icons.speed,
                      label: archetype.targetMarketRegime,
                      color: colorScheme.onSurfaceVariant,
                      flexible: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTraitChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    bool flexible = false,
  }) {
    final theme = Theme.of(context);
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          flexible
              ? Flexible(
                  child: Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              : Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
        ],
      ),
    );
    return flexible ? Flexible(child: content) : content;
  }
}
