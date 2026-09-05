import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/utils/analytics_utils.dart';
import 'package:robinhood_options_mobile/widgets/analytics_style_card.dart';

class TailRiskCard extends StatelessWidget {
  final List<InstrumentPosition> positions;
  final List<OptionAggregatePosition> optionPositions;

  const TailRiskCard({
    super.key,
    required this.positions,
    required this.optionPositions,
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
    final assessment = AnalyticsUtils.calculateTailRiskAndLiquidity(
        exposures, optionPositions);
    final score = assessment['liquidityScore']!;
    final theme = Theme.of(context);
    final hasData = assessment['pricedContracts']! > 0 || exposures.isNotEmpty;
    final scoreColor = score >= 70
        ? Colors.green
        : (score >= 40 ? Colors.orange : theme.colorScheme.error);

    return AnalyticsStyleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tail Risk & Liquidity',
                        style: theme.textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text('Downside screen and option exit conditions',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!hasData)
            Text('Risk assessment needs priced holdings.',
                style: theme.textTheme.bodyMedium)
          else ...[
            Row(
              children: [
                Expanded(
                  child: _metric(
                    context,
                    '20% downside screen',
                    _formatCurrency(assessment['downsideLoss']!),
                    theme.colorScheme.error,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _metric(
                    context,
                    'Liquidity score',
                    '${score.toStringAsFixed(0)}/100',
                    scoreColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              score < 40
                  ? 'Wide spreads or shallow quotes may make exits costly. Review hedges before increasing exposure.'
                  : score < 70
                      ? 'Liquidity is mixed. Prefer limit orders and confirm the spread before adjusting risk.'
                      : 'Quoted liquidity is healthy. Continue monitoring downside concentration as positions change.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              assessment['pricedContracts']! > 0
                  ? '${assessment['pricedContracts']!.toStringAsFixed(0)} option contracts assessed from current bid/ask quotes.'
                  : 'No option bid/ask quotes available; liquidity score is provisional.',
              style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metric(BuildContext context, String label, String value, Color color) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(value,
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _formatCurrency(double value) {
    final sign = value < 0 ? '-' : '';
    return '$sign${formatCurrency.format(value.abs())}';
  }
}