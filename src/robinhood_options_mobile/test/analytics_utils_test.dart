import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/utils/analytics_utils.dart';

void main() {
  group('AnalyticsUtils', () {
    test('calculateSharpeRatio', () {
      // Risk-free rate 0.02 (2%)
      // Returns: [0.05, 0.02, 0.03] -> Mean: 0.0333
      // Daily Risk Free: 0.02 / 252 ~= 0.000079
      // Excess Returns: [0.0499, 0.0199, 0.0299]
      // Mean Excess: ~0.03325
      // StdDev Excess: ~0.01527
      // Daily Sharpe: 0.03325 / 0.01527 ~= 2.177
      // Annualized Sharpe: 2.177 * sqrt(252) ~= 34.56
      final returns = [0.05, 0.02, 0.03];
      final sharpe =
          AnalyticsUtils.calculateSharpeRatio(returns, riskFreeRate: 0.02);
      expect(sharpe, closeTo(34.56, 0.1));
    });

    test('calculateSortinoRatio', () {
      // Risk-free rate 0.02
      // Returns: [0.05, -0.01, 0.06]
      // Target Return: 0.02
      // Downside Returns (r < 0.02): [-0.01]
      // Downside Diff: -0.01 - 0.02 = -0.03. Sq: 0.0009.
      // Downside Variance: 0.0009 / 3 = 0.0003
      // Downside Deviation: sqrt(0.0003) = 0.01732
      // Mean Excess (vs Rf 0.02/252): ~0.03325
      // Daily Sortino: 0.03325 / 0.01732 ~= 1.919
      // Annualized Sortino: 1.919 * sqrt(252) ~= 30.47
      final returns = [0.05, -0.01, 0.06];
      final sortino = AnalyticsUtils.calculateSortinoRatio(returns,
          riskFreeRate: 0.02, targetReturn: 0.02);
      expect(sortino, closeTo(30.40, 0.5));
    });

    test('calculateCalmarRatio', () {
      // Total Return: 0.50 (50%)
      // Max Drawdown: 0.25 (25%)
      // Period: 2 years
      // CAGR: (1 + 0.50)^(1/2) - 1 = 1.2247 - 1 = 0.2247
      // Calmar: 0.2247 / 0.25 = 0.898
      final calmar = AnalyticsUtils.calculateCalmarRatio(0.50, 0.25, 2.0);
      expect(calmar, closeTo(0.89, 0.01));
    });

    test('calculateOmegaRatio', () {
      // Threshold: 0.0
      // Returns: [0.10, -0.05, 0.15]
      // Gains: 0.10 + 0.15 = 0.25
      // Losses: |-0.05| = 0.05
      // Omega: 0.25 / 0.05 = 5.0
      final returns = [0.10, -0.05, 0.15];
      final omega = AnalyticsUtils.calculateOmegaRatio(returns, threshold: 0.0);
      expect(omega, closeTo(5.0, 0.01));
    });

    test('calculateMaxDrawdown', () {
      // Values: [100, 110, 99, 105, 120]
      // Peak 110 -> 99 (Drop 11, 10%)
      // Peak 120
      // Max Drawdown: 0.10
      final values = [100.0, 110.0, 99.0, 105.0, 120.0];
      final mdd = AnalyticsUtils.calculateMaxDrawdown(values);
      expect(mdd, closeTo(0.10, 0.01));
    });

    test('calculateCVaR', () {
      // Returns: [-0.05, -0.03, -0.01, 0.01, 0.02, 0.03, 0.04, 0.05, 0.06, 0.07]
      // Sorted: [-0.05, -0.03, -0.01, 0.01, 0.02, 0.03, 0.04, 0.05, 0.06, 0.07]
      // Confidence: 0.80 (80%)
      // Index: (1 - 0.80) * 10 = 2.
      // VaR is sorted[2] = -0.01.
      // Tail: [-0.05, -0.03, -0.01]
      // CVaR: (-0.05 - 0.03 - 0.01) / 3 = -0.03
      final returns = [
        -0.05,
        -0.03,
        -0.01,
        0.01,
        0.02,
        0.03,
        0.04,
        0.05,
        0.06,
        0.07
      ];
      final cvar = AnalyticsUtils.calculateCVaR(returns, confidenceLevel: 0.80);
      expect(cvar, closeTo(-0.03, 0.001));
    });

    test('calculateKellyCriterion', () {
      // Win Rate: 0.6, Payoff: 1.5
      // K% = 0.6 - (0.4 / 1.5) = 0.3333
      final kelly = AnalyticsUtils.calculateKellyCriterion(0.6, 1.5);
      expect(kelly, closeTo(0.333, 0.001));
    });

    test('calculateUlcerIndex', () {
      // Prices: [100, 105, 100, 95, 100, 110]
      // Drawdowns: [0, 0, -0.0476, -0.0952, -0.0476, 0]
      // UI ~= 0.0475
      final prices = [100.0, 105.0, 100.0, 95.0, 100.0, 110.0];
      final ui = AnalyticsUtils.calculateUlcerIndex(prices);
      expect(ui, closeTo(0.0475, 0.001));
    });

    test('calculateTailRatio', () {
      // Returns: [-0.05, -0.02, 0.01, 0.03, 0.04, 0.06, 0.08, 0.10, 0.12, 0.15]
      // 95th: 0.15, 5th: -0.05
      // Ratio: 3.0
      final returns = [
        -0.05,
        -0.02,
        0.01,
        0.03,
        0.04,
        0.06,
        0.08,
        0.10,
        0.12,
        0.15
      ];
      final tail = AnalyticsUtils.calculateTailRatio(returns);
      expect(tail, closeTo(3.0, 0.001));
    });

    test('calculatePortfolioMetrics returns correct structure', () {
      final portfolioPrices = [100.0, 105.0, 102.0, 110.0];
      final benchmarkPrices = [100.0, 102.0, 101.0, 105.0];
      final fullPortfolio = [100.0, 105.0, 102.0, 110.0];
      final periodYears = 1.0;

      final metrics = AnalyticsUtils.calculatePortfolioMetrics(
        alignedPortfolioPrices: portfolioPrices,
        alignedBenchmarkPrices: benchmarkPrices,
        fullPortfolioPrices: fullPortfolio,
        periodYears: periodYears,
      );

      expect(metrics.containsKey('sharpe'), isTrue);
      expect(metrics.containsKey('beta'), isTrue);
      expect(metrics.containsKey('healthScore'), isTrue);
      expect(metrics['sharpe'], isA<double>());
    });
  });
}
