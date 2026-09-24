import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/top_portfolio_entry.dart';
import 'package:robinhood_options_mobile/model/trader_comparison_model.dart';

void main() {
  group('TraderComparisonModel Tests', () {
    late TopPortfolioEntry traderA;
    late TopPortfolioEntry traderB;
    late TopPortfolioEntry traderC;

    setUp(() {
      traderA = TopPortfolioEntry(
        userId: 'user-a',
        userName: 'Alpha Queen',
        returnPercent: 85.5,
        winRate: 72.0,
        totalTrades: 120,
        winningTrades: 86,
        losingTrades: 34,
        sharpeRatio: 2.4,
        maxDrawdownPercent: 8.5,
        profitFactor: 2.1,
        followersCount: 250,
        periodReturns: {
          '1W': 2.5,
          '1M': 10.2,
          '3M': 28.4,
          '1Y': 75.0,
          'ALL': 85.5,
        },
        reputation: const UserReputation(
          score: 88,
          tier: ReputationTier.eliteTrader,
        ),
      );

      traderB = TopPortfolioEntry(
        userId: 'user-b',
        userName: 'Delta Master',
        returnPercent: 120.0,
        winRate: 58.0,
        totalTrades: 200,
        winningTrades: 116,
        losingTrades: 84,
        sharpeRatio: 1.8,
        maxDrawdownPercent: 16.0,
        profitFactor: 1.65,
        followersCount: 180,
        periodReturns: {
          '1W': 5.0,
          '1M': 18.5,
          '3M': 45.0,
          '1Y': 110.0,
          'ALL': 120.0,
        },
        reputation: const UserReputation(
          score: 80,
          tier: ReputationTier.eliteTrader,
        ),
      );

      traderC = TopPortfolioEntry(
        userId: 'user-c',
        userName: 'Steady Conservative',
        returnPercent: 35.0,
        winRate: 85.0,
        totalTrades: 60,
        winningTrades: 51,
        losingTrades: 9,
        sharpeRatio: 3.1,
        maxDrawdownPercent: 3.2,
        profitFactor: 3.4,
        followersCount: 95,
        periodReturns: {
          '1W': 0.8,
          '1M': 3.2,
          '3M': 9.0,
          '1Y': 30.0,
          'ALL': 35.0,
        },
        reputation: const UserReputation(
          score: 76,
          tier: ReputationTier.eliteTrader,
        ),
      );
    });

    test('Builds comparison summary for empty traders list gracefully', () {
      final summary = TraderComparisonSummary.build(traders: []);
      expect(summary.traders, isEmpty);
      expect(summary.metrics, isEmpty);
      expect(summary.relativeStrengths, isEmpty);
      expect(summary.categoryWinCounts, isEmpty);
    });

    test('Correctly computes metrics across multiple traders', () {
      final summary = TraderComparisonSummary.build(
        traders: [traderA, traderB, traderC],
        period: LeaderboardTimePeriod.allTime,
      );

      expect(summary.traders.length, equals(3));
      expect(summary.metrics, isNotEmpty);

      // Return metric: Trader B has highest return (120.0%)
      final returnMetric = summary.metrics.firstWhere(
          (m) => m.label.contains('Return') && !m.label.contains('Drawdown'));
      expect(returnMetric.bestTraderIndex, equals(1)); // Trader B
      expect(returnMetric.formattedValues[1], equals('+120.0%'));

      // Win Rate metric: Trader C has highest win rate (85.0%)
      final winRateMetric =
          summary.metrics.firstWhere((m) => m.label == 'Win Rate');
      expect(winRateMetric.bestTraderIndex, equals(2)); // Trader C
      expect(winRateMetric.formattedValues[2], equals('85.0%'));

      // Sharpe Ratio: Trader C has highest Sharpe (3.10)
      final sharpeMetric =
          summary.metrics.firstWhere((m) => m.label == 'Sharpe Ratio');
      expect(sharpeMetric.bestTraderIndex, equals(2)); // Trader C
      expect(sharpeMetric.formattedValues[2], equals('3.10'));

      // Max Drawdown: Lower is better, Trader C has lowest drawdown (3.2%)
      final ddMetric =
          summary.metrics.firstWhere((m) => m.label == 'Max Drawdown');
      expect(ddMetric.higherIsBetter, isFalse);
      expect(ddMetric.bestTraderIndex, equals(2)); // Trader C
      expect(ddMetric.formattedValues[2], equals('-3.2%'));

      // Total Trades: Trader B has most trades (200)
      final tradesMetric =
          summary.metrics.firstWhere((m) => m.label == 'Total Trades');
      expect(tradesMetric.bestTraderIndex, equals(1)); // Trader B
      expect(tradesMetric.formattedValues[1], equals('200'));

      // Reputation Score: Trader A has highest reputation (88)
      final repMetric =
          summary.metrics.firstWhere((m) => m.label == 'Reputation Score');
      expect(repMetric.bestTraderIndex, equals(0)); // Trader A
      expect(repMetric.formattedValues[0], equals('88 / 100'));
    });

    test('Period switching updates return metric and evaluations', () {
      final summary1M = TraderComparisonSummary.build(
        traders: [traderA, traderB, traderC],
        period: LeaderboardTimePeriod.oneMonth,
      );

      final returnMetric =
          summary1M.metrics.firstWhere((m) => m.label == '1M Return');
      expect(returnMetric.formattedValues[0], equals('+10.2%'));
      expect(returnMetric.formattedValues[1], equals('+18.5%'));
      expect(returnMetric.formattedValues[2], equals('+3.2%'));
      expect(returnMetric.bestTraderIndex, equals(1)); // Trader B
    });

    test('Computes relative strengths across 5 dimensions within [0, 100]', () {
      final summary = TraderComparisonSummary.build(
        traders: [traderA, traderB, traderC],
        period: LeaderboardTimePeriod.allTime,
      );

      expect(summary.relativeStrengths.length, equals(3));
      for (final rs in summary.relativeStrengths) {
        expect(rs.returnScore, inInclusiveRange(0.0, 100.0));
        expect(rs.consistencyScore, inInclusiveRange(0.0, 100.0));
        expect(rs.riskAdjustedScore, inInclusiveRange(0.0, 100.0));
        expect(rs.preservationScore, inInclusiveRange(0.0, 100.0));
        expect(rs.reputationScore, inInclusiveRange(0.0, 100.0));
        expect(rs.overallScore, inInclusiveRange(0.0, 100.0));
      }

      // Trader C with 3.2% drawdown should have higher preservation score than Trader B with 16.0%
      expect(summary.relativeStrengths[2].preservationScore,
          greaterThan(summary.relativeStrengths[1].preservationScore));
    });

    test('Groups metrics correctly by category', () {
      final summary = TraderComparisonSummary.build(
        traders: [traderA, traderB],
      );

      final categories = summary.metricsByCategory;
      expect(categories[TraderComparisonCategory.performance], isNotEmpty);
      expect(categories[TraderComparisonCategory.risk], isNotEmpty);
      expect(categories[TraderComparisonCategory.activity], isNotEmpty);
      expect(categories[TraderComparisonCategory.reputation], isNotEmpty);
    });
  });
}
