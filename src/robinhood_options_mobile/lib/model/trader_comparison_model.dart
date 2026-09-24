import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/top_portfolio_entry.dart';

/// Categories of metrics evaluated during side-by-side trader comparison.
enum TraderComparisonCategory {
  performance,
  risk,
  activity,
  reputation;

  String get label {
    switch (this) {
      case TraderComparisonCategory.performance:
        return 'Performance & Returns';
      case TraderComparisonCategory.risk:
        return 'Risk & Preservation';
      case TraderComparisonCategory.activity:
        return 'Activity & Execution';
      case TraderComparisonCategory.reputation:
        return 'Reputation & Trust';
    }
  }
}

/// An individual metric evaluated across multiple traders.
class TraderComparisonMetric {
  final String label;
  final String description;
  final TraderComparisonCategory category;
  final bool higherIsBetter;
  final List<double?> rawValues;
  final List<String> formattedValues;
  final int? bestTraderIndex;

  const TraderComparisonMetric({
    required this.label,
    required this.description,
    required this.category,
    required this.higherIsBetter,
    required this.rawValues,
    required this.formattedValues,
    this.bestTraderIndex,
  });
}

/// 5-dimensional relative strength scores (0 - 100) for a trader.
class TraderRelativeStrength {
  final double returnScore;
  final double consistencyScore;
  final double riskAdjustedScore;
  final double preservationScore;
  final double reputationScore;

  const TraderRelativeStrength({
    required this.returnScore,
    required this.consistencyScore,
    required this.riskAdjustedScore,
    required this.preservationScore,
    required this.reputationScore,
  });

  double get overallScore =>
      (returnScore +
          consistencyScore +
          riskAdjustedScore +
          preservationScore +
          reputationScore) /
      5.0;
}

/// Complete comparison analysis model for 2 to 4 traders.
class TraderComparisonSummary {
  final List<TopPortfolioEntry> traders;
  final LeaderboardTimePeriod period;
  final List<TraderComparisonMetric> metrics;
  final List<TraderRelativeStrength> relativeStrengths;
  final List<int> categoryWinCounts;

  const TraderComparisonSummary({
    required this.traders,
    required this.period,
    required this.metrics,
    required this.relativeStrengths,
    required this.categoryWinCounts,
  });

  /// Builds a complete comparison summary for the provided traders and period.
  factory TraderComparisonSummary.build({
    required List<TopPortfolioEntry> traders,
    LeaderboardTimePeriod period = LeaderboardTimePeriod.allTime,
  }) {
    if (traders.isEmpty) {
      return TraderComparisonSummary(
        traders: const [],
        period: period,
        metrics: const [],
        relativeStrengths: const [],
        categoryWinCounts: const [],
      );
    }

    final n = traders.length;
    final metrics = <TraderComparisonMetric>[];

    // Helper to evaluate a metric across all traders
    TraderComparisonMetric evaluateMetric({
      required String label,
      required String description,
      required TraderComparisonCategory category,
      required bool higherIsBetter,
      required List<double?> values,
      required String Function(double? val, int index) formatter,
    }) {
      int? bestIdx;
      double? bestVal;

      for (int i = 0; i < values.length; i++) {
        final v = values[i];
        if (v == null) continue;
        if (bestVal == null) {
          bestVal = v;
          bestIdx = i;
        } else if (higherIsBetter && v > bestVal) {
          bestVal = v;
          bestIdx = i;
        } else if (!higherIsBetter && v < bestVal) {
          bestVal = v;
          bestIdx = i;
        }
      }

      final formatted = <String>[];
      for (int i = 0; i < values.length; i++) {
        formatted.add(formatter(values[i], i));
      }

      return TraderComparisonMetric(
        label: label,
        description: description,
        category: category,
        higherIsBetter: higherIsBetter,
        rawValues: values,
        formattedValues: formatted,
        bestTraderIndex: bestIdx,
      );
    }

    // 1. Performance Category
    // Return for period
    metrics.add(evaluateMetric(
      label: '${period.label} Return',
      description: 'Total percentage return realized over the selected period.',
      category: TraderComparisonCategory.performance,
      higherIsBetter: true,
      values: traders.map((t) => t.returnForPeriod(period)).toList(),
      formatter: (v, _) =>
          v != null ? '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}%' : 'N/A',
    ));

    // Win Rate
    metrics.add(evaluateMetric(
      label: 'Win Rate',
      description: 'Percentage of completed trades that ended profitably.',
      category: TraderComparisonCategory.performance,
      higherIsBetter: true,
      values: traders.map((t) => t.winRate).toList(),
      formatter: (v, _) => v != null ? '${v.toStringAsFixed(1)}%' : 'N/A',
    ));

    // Profit Factor
    metrics.add(evaluateMetric(
      label: 'Profit Factor',
      description:
          'Ratio of gross profits to gross losses (>1.5 considered robust).',
      category: TraderComparisonCategory.performance,
      higherIsBetter: true,
      values: traders.map((t) => t.profitFactor).toList(),
      formatter: (v, _) => v != null ? v.toStringAsFixed(2) : 'N/A',
    ));

    // Risk-Adjusted Return (Calmar-like: Return / Max Drawdown)
    final riskAdjustedReturns = traders.map((t) {
      final ret = t.returnForPeriod(period);
      final dd = t.maxDrawdownPercent.abs();
      if (dd <= 0.001) return ret > 0 ? 10.0 : 0.0;
      return ret / dd;
    }).toList();

    metrics.add(evaluateMetric(
      label: 'Return / Drawdown',
      description:
          'Efficiency ratio of return generated per unit of peak drawdown.',
      category: TraderComparisonCategory.performance,
      higherIsBetter: true,
      values: riskAdjustedReturns,
      formatter: (v, _) => v != null ? v.toStringAsFixed(2) : 'N/A',
    ));

    // 2. Risk & Preservation Category
    // Max Drawdown % (lower is better!)
    metrics.add(evaluateMetric(
      label: 'Max Drawdown',
      description:
          'Maximum peak-to-trough decline experienced in the portfolio.',
      category: TraderComparisonCategory.risk,
      higherIsBetter: false,
      values: traders.map((t) => t.maxDrawdownPercent.abs()).toList(),
      formatter: (v, _) => v != null ? '-${v.toStringAsFixed(1)}%' : 'N/A',
    ));

    // Sharpe Ratio
    metrics.add(evaluateMetric(
      label: 'Sharpe Ratio',
      description:
          'Excess return per unit of volatility relative to risk-free rate.',
      category: TraderComparisonCategory.risk,
      higherIsBetter: true,
      values: traders.map((t) => t.sharpeRatio).toList(),
      formatter: (v, _) => v != null ? v.toStringAsFixed(2) : 'N/A',
    ));

    // 3. Activity & Execution Category
    // Total Trades
    metrics.add(evaluateMetric(
      label: 'Total Trades',
      description: 'Historical audited trade count recorded for this trader.',
      category: TraderComparisonCategory.activity,
      higherIsBetter: true,
      values: traders.map((t) => t.totalTrades.toDouble()).toList(),
      formatter: (v, _) => v != null ? v.toInt().toString() : '0',
    ));

    // Winning Trades
    metrics.add(evaluateMetric(
      label: 'Winning Trades',
      description: 'Total number of profitable closed trades.',
      category: TraderComparisonCategory.activity,
      higherIsBetter: true,
      values: traders.map((t) => t.winningTrades.toDouble()).toList(),
      formatter: (v, _) => v != null ? v.toInt().toString() : '0',
    ));

    // Losing Trades (lower is better)
    metrics.add(evaluateMetric(
      label: 'Losing Trades',
      description: 'Total number of unprofitable closed trades.',
      category: TraderComparisonCategory.activity,
      higherIsBetter: false,
      values: traders.map((t) => t.losingTrades.toDouble()).toList(),
      formatter: (v, _) => v != null ? v.toInt().toString() : '0',
    ));

    // 4. Reputation & Trust Category
    // Reputation Score (0 - 100)
    metrics.add(evaluateMetric(
      label: 'Reputation Score',
      description: 'Quantified credibility score spanning 5 trust pillars.',
      category: TraderComparisonCategory.reputation,
      higherIsBetter: true,
      values: traders.map((t) => t.reputation.score.toDouble()).toList(),
      formatter: (v, _) => v != null ? '${v.toInt()} / 100' : '0',
    ));

    // Followers Count
    metrics.add(evaluateMetric(
      label: 'Followers',
      description: 'Active community followers tracking this portfolio.',
      category: TraderComparisonCategory.reputation,
      higherIsBetter: true,
      values: traders.map((t) => t.followersCount.toDouble()).toList(),
      formatter: (v, _) => v != null ? NumberFormat.compact().format(v) : '0',
    ));

    // Calculate category win counts per trader
    final categoryWinCounts = List<int>.filled(n, 0);
    for (final m in metrics) {
      if (m.bestTraderIndex != null && m.bestTraderIndex! < n) {
        categoryWinCounts[m.bestTraderIndex!]++;
      }
    }

    // Compute 5-dimensional Relative Strength Scores (0 - 100)
    final relativeStrengths = <TraderRelativeStrength>[];

    // Find max values across traders for normalization
    double maxReturn = 1.0;
    double maxSharpe = 1.0;
    double maxDd = 1.0;

    for (final t in traders) {
      final ret = math.max(0.0, t.returnForPeriod(period));
      if (ret > maxReturn) maxReturn = ret;
      if (t.sharpeRatio > maxSharpe) maxSharpe = t.sharpeRatio;
      final dd = t.maxDrawdownPercent.abs();
      if (dd > maxDd) maxDd = dd;
    }

    for (final t in traders) {
      // 1. Return score: normalized 0-100 against maxReturn
      final ret = t.returnForPeriod(period);
      final returnScore =
          ret <= 0 ? 0.0 : math.min(100.0, (ret / maxReturn) * 100.0);

      // 2. Consistency: based on winRate (0-100)
      final consistencyScore = t.winRate.clamp(0.0, 100.0);

      // 3. Risk-adjusted: based on Sharpe (>= 3.0 is 100)
      final riskAdjustedScore = t.sharpeRatio <= 0
          ? 0.0
          : math.min(100.0, (t.sharpeRatio / 3.0) * 100.0);

      // 4. Capital preservation: inverted max drawdown (0% dd = 100, 30% dd = 0)
      final dd = t.maxDrawdownPercent.abs();
      final preservationScore =
          math.max(0.0, (1.0 - (dd / 30.0)) * 100.0).clamp(0.0, 100.0);

      // 5. Reputation score: already 0-100
      final reputationScore = t.reputation.score.toDouble().clamp(0.0, 100.0);

      relativeStrengths.add(TraderRelativeStrength(
        returnScore: returnScore,
        consistencyScore: consistencyScore,
        riskAdjustedScore: riskAdjustedScore,
        preservationScore: preservationScore,
        reputationScore: reputationScore,
      ));
    }

    return TraderComparisonSummary(
      traders: traders,
      period: period,
      metrics: metrics,
      relativeStrengths: relativeStrengths,
      categoryWinCounts: categoryWinCounts,
    );
  }

  /// Groups metrics by their respective categories.
  Map<TraderComparisonCategory, List<TraderComparisonMetric>>
      get metricsByCategory {
    final map = <TraderComparisonCategory, List<TraderComparisonMetric>>{};
    for (final cat in TraderComparisonCategory.values) {
      map[cat] = metrics.where((m) => m.category == cat).toList();
    }
    return map;
  }
}
