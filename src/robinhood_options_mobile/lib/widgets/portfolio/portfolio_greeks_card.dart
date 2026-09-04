import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/utils/analytics_utils.dart';
import 'package:robinhood_options_mobile/widgets/analytics_style_card.dart';

class PortfolioGreeksCard extends StatelessWidget {
  final List<OptionAggregatePosition> positions;

  const PortfolioGreeksCard({super.key, required this.positions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final greeks = AnalyticsUtils.aggregateOptionGreeks(positions);
    final hasData = greeks['pricedContracts']! > 0;

    return AnalyticsStyleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.functions, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Portfolio Greeks', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text('Net sensitivity across priced option positions',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!hasData)
            Text('Greeks need priced option holdings.',
                style: theme.textTheme.bodyMedium)
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 520 ? 4 : 2;
                final tileWidth =
                    (constraints.maxWidth - (columns - 1) * 8) / columns;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in const [
                      MapEntry('delta', 'Delta'),
                      MapEntry('gamma', 'Gamma'),
                      MapEntry('theta', 'Theta'),
                      MapEntry('vega', 'Vega'),
                    ])
                      SizedBox(
                        width: tileWidth,
                        child: _greekTile(context, entry.key, entry.value,
                            greeks[entry.key]!),
                      ),
                  ],
                );
              },
            ),
          const SizedBox(height: 10),
          Text(
            '${greeks['pricedContracts']!.toStringAsFixed(0)} contracts with usable Greek data · per \$1 move for Delta/Gamma',
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _greekTile(
      BuildContext context, String key, String label, double value) {
    final theme = Theme.of(context);
    final color = value < 0 ? theme.colorScheme.error : Colors.green;
    return Semantics(
      label: '$label ${value.toStringAsFixed(2)}',
      container: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 62),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: theme.textTheme.labelMedium),
            const SizedBox(height: 3),
            Text(
              '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)}',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
