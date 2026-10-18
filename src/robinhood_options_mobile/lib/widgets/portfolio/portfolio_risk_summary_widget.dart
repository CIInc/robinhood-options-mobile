import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/metric_disclosure_card.dart';

/// The concentration read-out, expressed first as a single score.
///
/// This is the reference implementation of the progressive-disclosure pattern:
/// a casual investor reads "Moderate" and stops; an advanced user expands and
/// gets the top-N weights and the Herfindahl-Hirschman Index that produced it.
class PortfolioRiskSummaryWidget extends StatelessWidget {
  final List<InstrumentPosition> positions;

  /// Set from the user's experience-level preference so advanced users skip the
  /// extra tap.
  final bool expandAdvanced;

  final VoidCallback? onTap;

  const PortfolioRiskSummaryWidget({
    super.key,
    required this.positions,
    this.expandAdvanced = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final concentration = _ConcentrationMetrics.from(positions);
    if (concentration == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final percent = NumberFormat.percentPattern()..maximumFractionDigits = 1;

    final Color color;
    final String status;
    final String summary;
    if (concentration.hhi < 0.15) {
      color = Colors.green;
      status = 'Well Diversified';
      summary = 'No single holding dominates your returns.';
    } else if (concentration.hhi < 0.25) {
      color = Colors.orange;
      status = 'Moderate Risk';
      summary = 'Consider trimming your largest holdings.';
    } else {
      color = theme.colorScheme.error;
      status = 'High Risk';
      summary = 'A few positions drive most of your performance.';
    }

    return MetricDisclosureCard(
      icon: Icons.shield_outlined,
      title: 'Concentration',
      headline: '${concentration.score.round()}',
      status: status,
      statusColor: color,
      summary: summary,
      initiallyExpanded: expandAdvanced,
      onTap: onTap,
      advancedLabel: 'Concentration Detail',
      tiles: [
        DisclosureTile(
          label: 'Top holding',
          value: percent.format(concentration.top1),
          valueColor: concentration.top1 > 0.30 ? color : null,
        ),
        DisclosureTile(
          label: 'Top 5',
          value: percent.format(concentration.top5),
        ),
        DisclosureTile(
          label: 'Holdings',
          value: '${concentration.count}',
        ),
      ],
      advanced: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bar(context, 'Top 1 Holding', concentration.top1,
              warnAbove: 0.20, alertAbove: 0.30),
          const SizedBox(height: 12),
          _bar(context, 'Top 3 Holdings', concentration.top3,
              warnAbove: 0.50, alertAbove: 0.70),
          const SizedBox(height: 12),
          _bar(context, 'Top 5 Holdings', concentration.top5),
          const SizedBox(height: 12),
          _bar(context, 'Top 10 Holdings', concentration.top10),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Herfindahl-Hirschman Index (HHI)',
                  style: theme.textTheme.bodySmall),
              Text(
                concentration.hhi.toStringAsFixed(4),
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bar(
    BuildContext context,
    String label,
    double value, {
    double? warnAbove,
    double? alertAbove,
  }) {
    final theme = Theme.of(context);
    final percent = NumberFormat.percentPattern();

    var color = theme.colorScheme.primary;
    if (alertAbove != null && value > alertAbove) {
      color = theme.colorScheme.error;
    } else if (warnAbove != null && value > warnAbove) {
      color = Colors.orange;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.bodyMedium),
            Text(
              percent.format(value),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.6),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

/// Concentration statistics for a set of holdings.
class _ConcentrationMetrics {
  final double top1;
  final double top3;
  final double top5;
  final double top10;
  final double hhi;
  final int count;

  const _ConcentrationMetrics({
    required this.top1,
    required this.top3,
    required this.top5,
    required this.top10,
    required this.hhi,
    required this.count,
  });

  /// A 0-100 score where higher means more concentrated. HHI runs from ~0 (many
  /// equal holdings) to 1 (a single holding); 0.4 is treated as the practical
  /// ceiling so realistic portfolios use the full range.
  double get score => (hhi / 0.4).clamp(0.0, 1.0) * 100;

  static _ConcentrationMetrics? from(List<InstrumentPosition> positions) {
    final active =
        positions.where((position) => position.marketValue > 0).toList();
    if (active.isEmpty) return null;

    final total =
        active.fold<double>(0, (sum, position) => sum + position.marketValue);
    if (total <= 0) return null;

    active.sort((a, b) => b.marketValue.compareTo(a.marketValue));

    double topN(int n) =>
        active.take(n).fold<double>(0, (sum, p) => sum + p.marketValue) / total;

    var hhi = 0.0;
    for (final position in active) {
      final weight = position.marketValue / total;
      hhi += weight * weight;
    }

    return _ConcentrationMetrics(
      top1: topN(1),
      top3: topN(3),
      top5: topN(5),
      top10: topN(10),
      hhi: hhi,
      count: active.length,
    );
  }
}
