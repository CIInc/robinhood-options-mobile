import 'package:flutter/material.dart';
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
    final metrics = archetype.walkForwardMetrics;

    final semanticsText = '${archetype.name} Archetype, ${archetype.tag}, '
        'Walk-Forward Win Rate ${metrics.winRate.toStringAsFixed(1)} percent, '
        'Profit Factor ${metrics.profitFactor.toStringAsFixed(2)}, '
        'Max Drawdown ${metrics.maxDrawdownPercent.toStringAsFixed(1)} percent. '
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
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Row: Icon, Tag, and Active Indicator
                Row(
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
                            children: [
                              Flexible(
                                child: Text(
                                  archetype.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
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
                          Text(
                            archetype.tag,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: archetype.accentColor,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Description
                Text(
                  archetype.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),

                // Walk-Forward Performance Badges Header
                Row(
                  children: [
                    Icon(
                      Icons.verified_outlined,
                      size: 13,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '1-Yr Walk-Forward Validation',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // 3 Performance Badges
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricBadge(
                        context: context,
                        label: 'Win Rate',
                        value: '${metrics.winRate.toStringAsFixed(1)}%',
                        color: Colors.green,
                        icon: Icons.check_circle_outline,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildMetricBadge(
                        context: context,
                        label: 'Profit Factor',
                        value: metrics.profitFactor.toStringAsFixed(2),
                        color: Colors.blue,
                        icon: Icons.trending_up,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildMetricBadge(
                        context: context,
                        label: 'Max DD',
                        value:
                            '${metrics.maxDrawdownPercent.toStringAsFixed(1)}%',
                        color: Colors.orange,
                        icon: Icons.arrow_downward,
                      ),
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

  Widget _buildMetricBadge({
    required BuildContext context,
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 10, color: color),
                const SizedBox(width: 2),
                Text(
                  value,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 9,
              color: colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
