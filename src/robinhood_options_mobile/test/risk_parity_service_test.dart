import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/tax_lot.dart';
import 'package:robinhood_options_mobile/services/risk_parity_service.dart';

void main() {
  group('RiskParityService Unit Tests', () {
    test('calculateRiskContributions verifies Euler identity and 100% risk sum',
        () {
      final weights = {
        'Stocks': 0.60,
        'Fixed Income': 0.30,
        'Crypto': 0.10,
      };

      final analysis = RiskParityService.calculateRiskContributions(
        weights: weights,
        isSectorMode: false,
      );

      expect(analysis.portfolioVolatility, greaterThan(0.0));
      expect(analysis.assetMetrics.length, equals(3));

      // Euler identity check: sum of TRC_i == sigma_p
      double sumTrc = 0.0;
      double sumPctRisk = 0.0;

      for (var entry in analysis.assetMetrics.entries) {
        sumTrc += entry.value.totalRiskContribution;
        sumPctRisk += entry.value.percentRiskContribution;
      }

      expect(sumTrc, closeTo(analysis.portfolioVolatility, 1e-4));
      expect(sumPctRisk, closeTo(1.0, 1e-4));

      // Crypto has higher vol (0.60) than Stocks (0.16) and Fixed Income (0.08),
      // so Crypto's risk contribution % should be higher than its capital weight (10%)
      final cryptoMetrics = analysis.assetMetrics['Crypto']!;
      expect(cryptoMetrics.percentRiskContribution, greaterThan(0.10));
    });

    test(
        'solveInverseVolatility returns weights inversely proportional to volatility',
        () {
      final vols = {
        'AssetA': 0.10,
        'AssetB': 0.20,
        'AssetC': 0.40,
      };

      final weights = RiskParityService.solveInverseVolatility(vols);

      // 1/0.10 = 10, 1/0.20 = 5, 1/0.40 = 2.5. Sum = 17.5.
      // Expected: AssetA = 10/17.5 (~0.5714), AssetB = 5/17.5 (~0.2857), AssetC = 2.5/17.5 (~0.1429)
      expect(weights['AssetA']!, closeTo(10.0 / 17.5, 1e-4));
      expect(weights['AssetB']!, closeTo(5.0 / 17.5, 1e-4));
      expect(weights['AssetC']!, closeTo(2.5 / 17.5, 1e-4));

      final sumW = weights.values.fold(0.0, (a, b) => a + b);
      expect(sumW, closeTo(1.0, 1e-4));
    });

    test('solveInverseVolatility respects cashTarget buffer', () {
      final vols = {
        'Stocks': 0.16,
        'Bonds': 0.08,
        'Cash': 0.001,
      };

      final weights =
          RiskParityService.solveInverseVolatility(vols, cashTarget: 0.10);

      expect(weights['Cash']!, equals(0.10));
      // Risky weights should sum to 0.90
      final riskySum = weights['Stocks']! + weights['Bonds']!;
      expect(riskySum, closeTo(0.90, 1e-4));
      // Bonds (lower vol) should receive higher risky allocation than Stocks
      expect(weights['Bonds']!, greaterThan(weights['Stocks']!));
    });

    test(
        'solveEqualRiskContribution converges to equal risk contributions for uncorrelated assets',
        () {
      final assets = ['A', 'B', 'C'];
      final vols = [0.10, 0.20, 0.40];
      // Diagonal covariance (zero correlation)
      final cov = List.generate(
          3, (i) => List.generate(3, (j) => i == j ? vols[i] * vols[i] : 0.0));

      final weights = RiskParityService.solveEqualRiskContribution(
        assets: assets,
        covarianceMatrix: cov,
      );

      // For uncorrelated assets, ERC weights should equal Inverse-Vol weights exactly!
      final invVol = RiskParityService.solveInverseVolatility(
          {'A': 0.10, 'B': 0.20, 'C': 0.40});
      for (var a in assets) {
        expect(weights[a]!, closeTo(invVol[a]!, 1e-3));
      }

      // Check risk contributions are equal: TRC_i = w_i * (cov * w)_i / sigma_p
      final wList = [weights['A']!, weights['B']!, weights['C']!];
      final variance = wList[0] * wList[0] * cov[0][0] +
          wList[1] * wList[1] * cov[1][1] +
          wList[2] * wList[2] * cov[2][2];
      final sigmaP = sqrt(variance);

      final trc0 = (wList[0] * cov[0][0] * wList[0]) / sigmaP;
      final trc1 = (wList[1] * cov[1][1] * wList[1]) / sigmaP;
      final trc2 = (wList[2] * cov[2][2] * wList[2]) / sigmaP;

      expect(trc0, closeTo(trc1, 1e-4));
      expect(trc1, closeTo(trc2, 1e-4));
    });

    test(
        'solveEqualRiskContribution converges with non-zero cross-asset correlation',
        () {
      final assets = ['Equity', 'Bond', 'Commodity'];
      final vols = [0.20, 0.08, 0.25];
      final corr = [
        [1.00, 0.15, 0.35],
        [0.15, 1.00, -0.05],
        [0.35, -0.05, 1.00],
      ];

      final cov = List.generate(
          3, (i) => List.generate(3, (j) => corr[i][j] * vols[i] * vols[j]));

      final weights = RiskParityService.solveEqualRiskContribution(
        assets: assets,
        covarianceMatrix: cov,
      );

      final w = [weights['Equity']!, weights['Bond']!, weights['Commodity']!];
      expect(w.fold(0.0, (a, b) => a + b), closeTo(1.0, 1e-4));

      // Calculate TRC for each asset
      double variance = 0.0;
      for (int i = 0; i < 3; i++) {
        for (int j = 0; j < 3; j++) {
          variance += w[i] * cov[i][j] * w[j];
        }
      }
      final sigmaP = sqrt(variance);

      final trc = List.generate(3, (i) {
        double covWi = 0.0;
        for (int j = 0; j < 3; j++) {
          covWi += cov[i][j] * w[j];
        }
        return (w[i] * covWi) / sigmaP;
      });

      // Target risk contribution is sigmaP / 3
      final targetTrc = sigmaP / 3.0;
      expect(trc[0], closeTo(targetTrc, 1e-3));
      expect(trc[1], closeTo(targetTrc, 1e-3));
      expect(trc[2], closeTo(targetTrc, 1e-3));
    });

    test(
        'generateTaxAwareHints detects tax-loss harvesting and cash-inflow preference',
        () {
      final currentAllocation = {
        'Stocks': 0.70,
        'Crypto': 0.20,
        'Fixed Income': 0.10,
      };
      final targetAllocation = {
        'Stocks': 0.50, // Trim -20% (-$20,000)
        'Crypto': 0.10, // Trim -10% (-$10,000)
        'Fixed Income': 0.40, // Add +30% (+$30,000)
      };

      // Mock tax lots for Stocks with unrealized loss
      final lots = [
        TaxLot(
          symbol: 'Stocks',
          quantity: 100,
          quantityAvailable: 100,
          costPerShare: 150.0,
          openDate: DateTime.now().subtract(const Duration(days: 45)),
        ),
      ];
      final currentPrices = {
        'Stocks': 120.0
      }; // $30 loss per share = $3,000 loss

      final hints = RiskParityService.generateTaxAwareHints(
        currentAllocation: currentAllocation,
        targetAllocation: targetAllocation,
        totalEquity: 100000.0,
        driftThreshold: 100.0,
        taxLots: lots,
        currentPrices: currentPrices,
      );

      expect(hints.length, equals(3));

      // Fixed Income should be a Buy / Inflow with tax-neutral hint
      final fiHint = hints.firstWhere((h) => h.key == 'Fixed Income');
      expect(fiHint.action, equals('Buy'));
      expect(fiHint.isTaxAdvantaged, isTrue);

      // Stocks should detect the harvestable loss
      final stockHint = hints.firstWhere((h) => h.key == 'Stocks');
      expect(stockHint.action, equals('Sell'));
      expect(stockHint.isTaxAdvantaged, isTrue);
      expect(stockHint.harvestableLoss, greaterThan(0.0));
    });
  });
}
