import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/utils/analytics_utils.dart';
import 'package:robinhood_options_mobile/widgets/analytics_style_card.dart';

class PortfolioStressTestCard extends StatelessWidget {
  final List<InstrumentPosition> positions;

  const PortfolioStressTestCard({
    super.key,
    required this.positions,
  });

  @override
  Widget build(BuildContext context) {
    final exposures = <String, double>{};
    for (final position in positions) {
      final symbol = position.instrumentObj?.symbol;
      if (symbol != null && symbol.isNotEmpty) {
        exposures[symbol] = (exposures[symbol] ?? 0) + position.marketValue;
      }
    }
    final scenarios = AnalyticsUtils.calculateStressScenarios(exposures);
    final theme = Theme.of(context);
    final portfolioValue =
        scenarios.isEmpty ? 0.0 : scenarios.first['portfolioValue'] ?? 0.0;

    return AnalyticsStyleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_outlined,
                  color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Stress Test', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text('Projected impact of broad market moves',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (scenarios.isEmpty)
            Text('Stress testing needs priced holdings.',
                style: theme.textTheme.bodyMedium)
          else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.account_balance_wallet_outlined,
                      size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('Net priced exposure', style: theme.textTheme.bodySmall),
                  const Spacer(),
                  Text(_formatCurrency(portfolioValue, showSign: false),
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 520 ? 6 : 3;
                final tileWidth =
                    (constraints.maxWidth - (columns - 1) * 6) / columns;
                return Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final scenario in scenarios)
                      SizedBox(
                        width: tileWidth,
                        child: _scenarioTile(context, scenario),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _legendDot(theme.colorScheme.error),
                const SizedBox(width: 5),
                Text('loss', style: theme.textTheme.labelSmall),
                const SizedBox(width: 12),
                _legendDot(Colors.green),
                const SizedBox(width: 5),
                Text('gain', style: theme.textTheme.labelSmall),
                const Spacer(),
                Flexible(
                  child: Text(
                    'Illustrative, not a forecast',
                    textAlign: TextAlign.end,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _scenarioTile(BuildContext context, Map<String, double> scenario) {
    final theme = Theme.of(context);
    final shock = scenario['shock']!;
    final change = scenario['change']!;
    final color = change < 0 ? theme.colorScheme.error : Colors.green;
    return Semantics(
      label:
          '${shock >= 0 ? 'Up' : 'Down'} ${(shock.abs() * 100).toStringAsFixed(0)} percent market scenario, ${_formatCurrency(change)} projected change',
      container: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 62),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${shock >= 0 ? '+' : ''}${(shock * 100).toStringAsFixed(0)}%',
                style: theme.textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 3),
            Text(_formatCurrency(change),
                style: theme.textTheme.labelMedium?.copyWith(color: color)),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  String _formatCurrency(double value, {bool showSign = true}) {
    final sign = value < 0 ? '-' : (showSign ? '+' : '');
    return '$sign${formatCurrency.format(value.abs())}';
  }
}
