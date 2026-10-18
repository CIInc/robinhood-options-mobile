import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/analytics/metric_presentation.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/metric_disclosure_card.dart';

/// A named group of stat tiles inside the advanced tier.
class _MetricGroup {
  final String title;
  final IconData icon;
  final List<Widget> stats;

  const _MetricGroup(this.title, this.icon, this.stats);
}

/// Every quantitative risk metric, behind one score.
///
/// Replaces four sibling cards — Risk Metrics, Risk-Adjusted Return, Market
/// Comparison, and Advanced Edge — that between them showed eighteen numbers
/// with no ordering. A casual investor now reads one score and a band; the
/// eighteen metrics are unchanged, just one tap down.
class RiskAnalyticsCard extends StatelessWidget {
  final Map<String, dynamic> data;

  /// Set from the user's experience level so advanced users skip the tap.
  final bool expandAdvanced;

  const RiskAnalyticsCard({
    super.key,
    required this.data,
    this.expandAdvanced = false,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final rolling = (data['rollingStatistics'] as List?)
        ?.whereType<Map>()
        .cast<Map<String, dynamic>>()
        .lastOrNull;
    final scoreData = {...data, if (rolling != null) ...rolling};
    final score = _RiskScore.from(scoreData);
    final groups = _groups(context, scoreData);
    if (groups.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final Color color;
    final String status;
    final String summary;
    if (score.value < 33) {
      color = Colors.green;
      status = 'Low Risk';
      summary = 'Swings and drawdowns have stayed contained.';
    } else if (score.value < 66) {
      color = Colors.orange;
      status = 'Moderate Risk';
      summary = 'Typical market exposure for a diversified portfolio.';
    } else {
      color = theme.colorScheme.error;
      status = 'High Risk';
      summary = 'Volatility or drawdown is running well above the market.';
    }

    return MetricDisclosureCard(
      icon: Icons.shield_outlined,
      title: 'Risk Score',
      headline: '${score.value.round()}',
      status: status,
      statusColor: color,
      summary: summary,
      initiallyExpanded: expandAdvanced,
      tiles: score.tiles,
      advanced: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < groups.length; i++) ...[
            if (i > 0) const SizedBox(height: 24),
            Row(
              children: [
                Icon(groups[i].icon,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  groups[i].title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            MetricPresentation.buildStatsGrid(groups[i].stats),
          ],
        ],
      ),
    );
  }

  /// The advanced tier, preserving the original four groupings so a metric is
  /// still found where a returning user expects it.
  List<_MetricGroup> _groups(BuildContext context, Map<String, dynamic> data) {
    final groups = <_MetricGroup>[];

    final risk = <Widget>[];
    if (data.containsKey('maxDrawdown')) {
      // Stored as a positive magnitude; drawdown reads as a loss.
      var maxDrawdown = data['maxDrawdown'] as double?;
      if (maxDrawdown != null && maxDrawdown > 0) maxDrawdown = -maxDrawdown;
      risk.add(MetricPresentation.buildStatItem(
          context, 'Max Drawdown', maxDrawdown,
          isPercent: true, badThreshold: -0.2));
    }
    if (data.containsKey('currentDrawdown')) {
      risk.add(MetricPresentation.buildStatItem(
          context, 'Current Drawdown', data['currentDrawdown'],
          isPercent: true, badThreshold: -0.1));
    }
    if (data.containsKey('volatility')) {
      risk.add(MetricPresentation.buildStatItem(
          context, 'Volatility', data['volatility'],
          isPercent: true, reverseColor: true, badThreshold: 0.2));
    }
    if (data.containsKey('var95')) {
      risk.add(MetricPresentation.buildStatItem(
          context, 'VaR (95%)', data['var95'],
          isPercent: true, badThreshold: -0.02));
    }
    if (data.containsKey('cvar95')) {
      risk.add(MetricPresentation.buildStatItem(
          context, 'CVaR (95%)', data['cvar95'],
          isPercent: true, badThreshold: -0.03));
    }
    if (risk.isNotEmpty) {
      groups
          .add(_MetricGroup('Risk Metrics', Icons.warning_amber_rounded, risk));
    }

    final riskAdjusted = <Widget>[];
    if (data.containsKey('sharpe')) {
      riskAdjusted.add(MetricPresentation.buildStatItem(
          context, 'Sharpe', data['sharpe'],
          goodThreshold: 1.0, badThreshold: 0.0));
    }
    if (data.containsKey('sortino')) {
      riskAdjusted.add(MetricPresentation.buildStatItem(
          context, 'Sortino', data['sortino'],
          goodThreshold: 1.0, badThreshold: 0.0));
    }
    if (data.containsKey('treynor')) {
      riskAdjusted.add(MetricPresentation.buildStatItem(
          context, 'Treynor', data['treynor'],
          goodThreshold: 0.05));
    }
    if (data.containsKey('informationRatio')) {
      riskAdjusted.add(MetricPresentation.buildStatItem(
          context, 'Info Ratio', data['informationRatio'],
          goodThreshold: 0.5));
    }
    if (data.containsKey('calmar')) {
      riskAdjusted.add(MetricPresentation.buildStatItem(
          context, 'Calmar', data['calmar'],
          goodThreshold: 0.5));
    }
    if (data.containsKey('omega')) {
      riskAdjusted.add(MetricPresentation.buildStatItem(
          context, 'Omega', data['omega'],
          goodThreshold: 1.0));
    }
    if (riskAdjusted.isNotEmpty) {
      groups.add(_MetricGroup(
          'Risk-Adjusted Return', Icons.trending_up, riskAdjusted));
    }

    final market = <Widget>[];
    if (data.containsKey('beta')) {
      market.add(MetricPresentation.buildStatItem(context, 'Beta', data['beta'],
          neutralValue: 1.0, reverseColor: true));
    }
    if (data.containsKey('correlation')) {
      market.add(MetricPresentation.buildStatItem(
          context, 'Correlation', data['correlation'],
          goodThreshold: 0.7, badThreshold: 0.3));
    }
    if (data.containsKey('alpha')) {
      market.add(MetricPresentation.buildStatItem(
          context, 'Alpha', data['alpha'],
          isPercent: true, goodThreshold: 0.0));
    }
    if (data.containsKey('trackingError')) {
      market.add(MetricPresentation.buildStatItem(
          context, 'Tracking Error', data['trackingError'],
          isPercent: true,
          reverseColor: true,
          badThreshold: 0.1,
          goodThreshold: 0.05));
    }
    if (market.isNotEmpty) {
      groups
          .add(_MetricGroup('Market Comparison', Icons.compare_arrows, market));
    }

    final edge = <Widget>[];
    if (data.containsKey('kellyCriterion')) {
      edge.add(MetricPresentation.buildStatItem(
          context, 'Kelly Criterion', data['kellyCriterion'],
          isPercent: true, goodThreshold: 0.05, badThreshold: 0.0));
    }
    if (data.containsKey('ulcerIndex')) {
      edge.add(MetricPresentation.buildStatItem(
          context, 'Ulcer Index', data['ulcerIndex'],
          isPercent: true,
          reverseColor: true,
          badThreshold: 0.15,
          goodThreshold: 0.05));
    }
    if (data.containsKey('tailRatio')) {
      edge.add(MetricPresentation.buildStatItem(
          context, 'Tail Ratio', data['tailRatio'],
          goodThreshold: 1.1, badThreshold: 0.9));
    }
    if (edge.isNotEmpty) {
      groups.add(_MetricGroup('Advanced Edge', Icons.psychology_rounded, edge));
    }

    return groups;
  }
}

/// A 0-100 summary of portfolio risk, higher meaning riskier.
///
/// Deliberately simple and inspectable: it blends the three quantities a
/// non-specialist can reason about — how much it swings, how far it has fallen,
/// and how much it amplifies the market. The ceilings (40% volatility, 50%
/// drawdown, beta 2.0) are the points past which extra risk stops changing the
/// advice, so realistic portfolios use the full range.
class _RiskScore {
  final double value;
  final List<DisclosureTile> tiles;

  const _RiskScore(this.value, this.tiles);

  static _RiskScore from(Map<String, dynamic> data) {
    final rolling = (data['rollingStatistics'] as List?)
        ?.whereType<Map>()
        .cast<Map<String, dynamic>>()
        .lastOrNull;
    final source = rolling ?? data;
    final volatility = (source['volatility'] as num?)?.toDouble().abs();
    final maxDrawdown = (source['maxDrawdown'] as num?)?.toDouble().abs();
    final beta = (source['beta'] as num?)?.toDouble();

    var score = 0.0;
    var weight = 0.0;
    if (volatility != null) {
      score += (volatility / 0.40).clamp(0.0, 1.0) * 40;
      weight += 40;
    }
    if (maxDrawdown != null) {
      score += (maxDrawdown / 0.50).clamp(0.0, 1.0) * 40;
      weight += 40;
    }
    if (beta != null) {
      score += ((beta - 1.0).abs() / 1.0).clamp(0.0, 1.0) * 20;
      weight += 20;
    }
    // Rescale so a portfolio missing a component is not scored as low-risk.
    final normalized = weight == 0 ? 0.0 : (score / weight) * 100;

    String percent(double? value) =>
        value == null ? '—' : '${(value * 100).toStringAsFixed(1)}%';

    return _RiskScore(normalized, [
      DisclosureTile(label: 'Volatility', value: percent(volatility)),
      DisclosureTile(
        label: 'Max Drawdown',
        value: maxDrawdown == null ? '—' : '-${percent(maxDrawdown)}',
      ),
      DisclosureTile(
        label: 'Beta',
        value: beta == null ? '—' : beta.toStringAsFixed(2),
      ),
    ]);
  }
}
