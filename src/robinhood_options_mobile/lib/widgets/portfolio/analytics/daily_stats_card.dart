import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/widgets/analytics_style_card.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/analytics/metric_presentation.dart';

/// Trade-level statistics: win rate, profit factor, payoff, and streaks.
class DailyStatsCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const DailyStatsCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) => _dailyStats(context, data);

  Widget _dailyStats(BuildContext context, Map<String, dynamic> data) {
    if (!data.containsKey('profitFactor') && !data.containsKey('winRate')) {
      return const SizedBox.shrink();
    }

    List<Widget> stats = [];
    if (data.containsKey('profitFactor')) {
      stats.add(MetricPresentation.buildStatItem(
          context, 'Profit Factor', data['profitFactor'],
          goodThreshold: 1.5, badThreshold: 1.0));
    }
    if (data.containsKey('winRate')) {
      stats.add(MetricPresentation.buildStatItem(
          context, 'Win Rate', data['winRate'],
          isPercent: true, goodThreshold: 0.55, badThreshold: 0.45));
    }
    if (data.containsKey('payoffRatio')) {
      stats.add(MetricPresentation.buildStatItem(
          context, 'Payoff Ratio', data['payoffRatio'],
          goodThreshold: 1.5, badThreshold: 1.0));
    }
    if (data.containsKey('expectancy')) {
      stats.add(MetricPresentation.buildStatItem(
          context, 'Expectancy', data['expectancy'],
          goodThreshold: 0.0, isCurrency: true));
    }
    if (data.containsKey('avgWin')) {
      stats.add(MetricPresentation.buildStatItem(
          context, 'Avg Win', data['avgWin'],
          goodThreshold: 0.0, isCurrency: true));
    }
    if (data.containsKey('avgLoss')) {
      stats.add(MetricPresentation.buildStatItem(
          context, 'Avg Loss', data['avgLoss'],
          badThreshold: 0.0, isCurrency: true, reverseColor: true));
    }
    if (data.containsKey('avgDailyReturn')) {
      stats.add(MetricPresentation.buildStatItem(
          context, 'Avg Daily', data['avgDailyReturn'],
          isPercent: true, goodThreshold: 0.0));
    }
    if (data.containsKey('maxWinStreak')) {
      stats.add(MetricPresentation.buildStatItem(
          context, 'Max Win Streak', (data['maxWinStreak'] as int).toDouble(),
          isInt: true, goodThreshold: 3.0));
    }
    if (data.containsKey('maxLossStreak')) {
      stats.add(MetricPresentation.buildStatItem(
          context, 'Max Loss Streak', (data['maxLossStreak'] as int).toDouble(),
          isInt: true, badThreshold: 3.0, reverseColor: true));
    }

    return AnalyticsStyleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_outlined,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Text('Daily Return Stats',
                  style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 20),
          MetricPresentation.buildStatsGrid(stats),
        ],
      ),
    );
  }
}
