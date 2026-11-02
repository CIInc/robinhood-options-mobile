import 'dart:math';
import 'package:robinhood_options_mobile/model/tax_lot.dart';
import 'package:robinhood_options_mobile/utils/analytics_utils.dart';

enum RiskDataProvenance {
  holdingHistory,
  benchmarkProxy,
  defaultFallback,
}

class AssetRiskMetrics {
  final String key;
  final double volatility;
  final double capitalWeight;
  final double marginalContributionToRisk;
  final double totalRiskContribution;
  final double percentRiskContribution;
  final RiskDataProvenance provenance;
  final String? proxyLabel;

  const AssetRiskMetrics({
    required this.key,
    required this.volatility,
    required this.capitalWeight,
    required this.marginalContributionToRisk,
    required this.totalRiskContribution,
    required this.percentRiskContribution,
    required this.provenance,
    this.proxyLabel,
  });
}

class RiskParityAnalysis {
  final Map<String, AssetRiskMetrics> assetMetrics;
  final double portfolioVolatility;
  final double riskConcentrationHhi;
  final String topRiskDriver;
  final double topRiskPercentage;
  final List<String> provenanceNotices;

  const RiskParityAnalysis({
    required this.assetMetrics,
    required this.portfolioVolatility,
    required this.riskConcentrationHhi,
    required this.topRiskDriver,
    required this.topRiskPercentage,
    required this.provenanceNotices,
  });

  bool get isWellDiversified => riskConcentrationHhi < 35.0;
}

class TaxAwareRebalancingHint {
  final String key;
  final double amount;
  final String action; // 'Buy', 'Sell', 'Raise', 'Invest'
  final double? harvestableLoss;
  final double? estimatedTaxLiability;
  final String hintMessage;
  final bool isTaxAdvantaged;

  const TaxAwareRebalancingHint({
    required this.key,
    required this.amount,
    required this.action,
    this.harvestableLoss,
    this.estimatedTaxLiability,
    required this.hintMessage,
    this.isTaxAdvantaged = false,
  });
}

/// On-device Equal Risk Contribution (Risk Parity) & Inverse-Volatility Engine.
///
/// Implements Euler risk decomposition, closed-form inverse-volatility weighting,
/// cyclical coordinate descent for full equal risk contribution (ERC) parity,
/// and tax-lot-aware trade sizing hints.
class RiskParityService {
  /// Default annualized volatility proxies for asset classes when price series are limited.
  static const Map<String, double> defaultAssetClassVolatilities = {
    'Stocks': 0.16, // Proxy: S&P 500 (~16% annualized)
    'Options': 0.35, // Proxy: Leveraged derivatives basket (~35%)
    'Crypto': 0.60, // Proxy: BTC / ETH blend (~60%)
    'Forex': 0.10, // Proxy: Major currency pairs (~10%)
    'Futures': 0.20, // Proxy: Index / commodity futures blend (~20%)
    'Fixed Income': 0.08, // Proxy: US Treasuries / aggregate bonds (~8%)
    'Cash': 0.001, // Near zero risk-free buffer
  };

  /// Default annualized volatility proxies for GICS sectors.
  static const Map<String, double> defaultSectorVolatilities = {
    'Technology': 0.24,
    'Financial Services': 0.18,
    'Consumer Cyclical': 0.22,
    'Healthcare': 0.17,
    'Communication Services': 0.21,
    'Industrials': 0.18,
    'Consumer Defensive': 0.13,
    'Energy': 0.26,
    'Real Estate': 0.19,
    'Basic Materials': 0.20,
    'Utilities': 0.14,
  };

  /// Computes annualized realized risk profiles, covariance matrix, and marginal
  /// risk contributions for the supplied capital weights.
  static RiskParityAnalysis calculateRiskContributions({
    required Map<String, double> weights,
    Map<String, List<double>>? returnSeries,
    Map<String, double>? customVolatilities,
    bool isSectorMode = false,
  }) {
    final keys = weights.keys.toList();
    if (keys.isEmpty) {
      return const RiskParityAnalysis(
        assetMetrics: {},
        portfolioVolatility: 0.0,
        riskConcentrationHhi: 0.0,
        topRiskDriver: 'None',
        topRiskPercentage: 0.0,
        provenanceNotices: [],
      );
    }

    final totalWeight = weights.values.fold(0.0, (a, b) => a + b);
    final normalizedWeights = <String, double>{};
    for (var k in keys) {
      normalizedWeights[k] = totalWeight > 0
          ? (weights[k] ?? 0.0) / totalWeight
          : 1.0 / keys.length;
    }

    // 1. Resolve asset volatilities and provenance
    final assetVols = <String, double>{};
    final provenanceMap = <String, RiskDataProvenance>{};
    final proxyLabelMap = <String, String>{};
    final provenanceNotices = <String>[];

    final defaults = isSectorMode
        ? defaultSectorVolatilities
        : defaultAssetClassVolatilities;

    for (var k in keys) {
      if (customVolatilities != null &&
          customVolatilities.containsKey(k) &&
          customVolatilities[k]! > 0) {
        assetVols[k] = customVolatilities[k]!;
        provenanceMap[k] = RiskDataProvenance.benchmarkProxy;
        proxyLabelMap[k] = 'Benchmark Proxy';
      } else if (returnSeries != null &&
          returnSeries.containsKey(k) &&
          (returnSeries[k]?.length ?? 0) >= 10) {
        final series = returnSeries[k]!;
        final vol = AnalyticsUtils.calculateVolatility(series);
        assetVols[k] = vol > 0 ? vol : (defaults[k] ?? 0.15);
        provenanceMap[k] = RiskDataProvenance.holdingHistory;
        proxyLabelMap[k] = 'Holding History (${series.length}d)';
      } else if (defaults.containsKey(k)) {
        assetVols[k] = defaults[k]!;
        provenanceMap[k] = RiskDataProvenance.defaultFallback;
        proxyLabelMap[k] = 'Category Baseline';
        provenanceNotices.add(
            '$k: Using historical baseline proxy (${(defaults[k]! * 100).toStringAsFixed(1)}% vol)');
      } else {
        assetVols[k] = 0.18; // General market baseline
        provenanceMap[k] = RiskDataProvenance.defaultFallback;
        proxyLabelMap[k] = 'Market Baseline';
      }
    }

    // 2. Build or estimate Covariance Matrix
    final n = keys.length;
    final cov = List.generate(n, (_) => List.filled(n, 0.0));

    for (int i = 0; i < n; i++) {
      for (int j = 0; j < n; j++) {
        final keyI = keys[i];
        final keyJ = keys[j];
        if (i == j) {
          cov[i][j] = assetVols[keyI]! * assetVols[keyI]!;
        } else {
          double corr = 0.25; // Default average cross-asset correlation
          if (returnSeries != null &&
              returnSeries.containsKey(keyI) &&
              returnSeries.containsKey(keyJ)) {
            final rI = returnSeries[keyI]!;
            final rJ = returnSeries[keyJ]!;
            if (rI.length == rJ.length && rI.length >= 10) {
              final calculatedCorr =
                  AnalyticsUtils.calculateCorrelation(rI, rJ);
              if (!calculatedCorr.isNaN && calculatedCorr.isFinite) {
                corr = calculatedCorr.clamp(-0.99, 0.99);
              }
            }
          }
          cov[i][j] = corr * assetVols[keyI]! * assetVols[keyJ]!;
        }
      }
    }

    // 3. Compute Portfolio Variance & Volatility
    // sigma_p^2 = w^T * Cov * w
    double portfolioVariance = 0.0;
    for (int i = 0; i < n; i++) {
      for (int j = 0; j < n; j++) {
        portfolioVariance += normalizedWeights[keys[i]]! *
            cov[i][j] *
            normalizedWeights[keys[j]]!;
      }
    }

    final portfolioVol =
        portfolioVariance > 0 ? sqrt(portfolioVariance) : 0.001;

    // 4. Compute Marginal Contribution to Risk (MCR) & Total Risk Contribution (TRC)
    // MCR_i = (Cov * w)_i / sigma_p
    // TRC_i = w_i * MCR_i
    // %RC_i = TRC_i / sigma_p = w_i * (Cov * w)_i / sigma_p^2
    final metrics = <String, AssetRiskMetrics>{};
    String topDriver = keys.first;
    double topPct = -1.0;
    double hhiSum = 0.0;

    for (int i = 0; i < n; i++) {
      final key = keys[i];
      final w = normalizedWeights[key]!;

      double covWi = 0.0;
      for (int j = 0; j < n; j++) {
        covWi += cov[i][j] * normalizedWeights[keys[j]]!;
      }

      final mcr = portfolioVol > 0 ? covWi / portfolioVol : 0.0;
      final trc = w * mcr;
      final pctRisk =
          portfolioVariance > 0 ? (w * covWi) / portfolioVariance : (1.0 / n);

      hhiSum += pow(pctRisk * 100, 2).toDouble();

      if (pctRisk > topPct) {
        topPct = pctRisk;
        topDriver = key;
      }

      metrics[key] = AssetRiskMetrics(
        key: key,
        volatility: assetVols[key]!,
        capitalWeight: w,
        marginalContributionToRisk: mcr,
        totalRiskContribution: trc,
        percentRiskContribution: pctRisk,
        provenance: provenanceMap[key]!,
        proxyLabel: proxyLabelMap[key],
      );
    }

    // Normalized Herfindahl-Hirschman Index (scaled 0 to 100)
    // Lower means more equally distributed risk (well-diversified).
    final hhi = (hhiSum / 100.0).clamp(0.0, 100.0);

    return RiskParityAnalysis(
      assetMetrics: metrics,
      portfolioVolatility: portfolioVol,
      riskConcentrationHhi: hhi,
      topRiskDriver: topDriver,
      topRiskPercentage: topPct,
      provenanceNotices: provenanceNotices,
    );
  }

  /// Solves for closed-form Inverse-Volatility (Naive Risk Parity) target weights:
  /// w_i = (1 / sigma_i) / sum(1 / sigma_j)
  static Map<String, double> solveInverseVolatility(
    Map<String, double> volatilities, {
    double cashTarget = 0.0,
  }) {
    if (volatilities.isEmpty) return {};

    final result = <String, double>{};
    final activeKeys = volatilities.keys.where((k) => k != 'Cash').toList();

    if (activeKeys.isEmpty) {
      if (volatilities.containsKey('Cash')) {
        result['Cash'] = 1.0;
      }
      return result;
    }

    double sumInvVol = 0.0;
    for (var k in activeKeys) {
      final vol = volatilities[k] ?? 0.15;
      final safeVol = vol > 0.001 ? vol : 0.001;
      sumInvVol += 1.0 / safeVol;
    }

    final riskyBudget = (1.0 - cashTarget).clamp(0.0, 1.0);

    for (var k in activeKeys) {
      final vol = volatilities[k] ?? 0.15;
      final safeVol = vol > 0.001 ? vol : 0.001;
      result[k] = sumInvVol > 0
          ? (1.0 / safeVol / sumInvVol) * riskyBudget
          : (riskyBudget / activeKeys.length);
    }

    if (volatilities.containsKey('Cash')) {
      result['Cash'] = cashTarget;
    }

    return result;
  }

  /// Solves for Equal Risk Contribution (ERC / Full Risk Parity) weights using
  /// Cyclical Coordinate Descent (CCD):
  /// Finds w such that w_i * (Cov * w)_i = w_j * (Cov * w)_j for all i, j.
  static Map<String, double> solveEqualRiskContribution({
    required List<String> assets,
    required List<List<double>> covarianceMatrix,
    Map<String, double>? initialWeights,
    int maxIterations = 50,
    double tolerance = 1e-4,
    double cashTarget = 0.0,
  }) {
    final activeAssets = assets.where((a) => a != 'Cash').toList();
    final n = activeAssets.length;
    if (n == 0) {
      return assets.contains('Cash') ? {'Cash': 1.0} : {};
    }
    if (n == 1) {
      final res = <String, double>{activeAssets.first: 1.0 - cashTarget};
      if (assets.contains('Cash')) res['Cash'] = cashTarget;
      return res;
    }

    // Map active asset indices in the covariance matrix
    final indices = activeAssets.map((a) => assets.indexOf(a)).toList();

    // Sub-covariance matrix for active risky assets
    final cov = List.generate(
      n,
      (i) => List.generate(n, (j) => covarianceMatrix[indices[i]][indices[j]]),
    );

    // Initialize with 1/N weights
    var w = List.filled(n, 1.0 / n);
    if (initialWeights != null) {
      for (int i = 0; i < n; i++) {
        w[i] = initialWeights[activeAssets[i]] ?? (1.0 / n);
      }
      final s = w.fold(0.0, (a, b) => a + b);
      if (s > 0) w = w.map((x) => x / s).toList();
    }

    final riskyBudget = (1.0 - cashTarget).clamp(0.0, 1.0);

    for (int iter = 0; iter < maxIterations; iter++) {
      // Current portfolio variance sigma_p^2 = w^T * Cov * w
      double variance = 0.0;
      for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) {
          variance += w[i] * cov[i][j] * w[j];
        }
      }

      if (variance <= 0) break;

      // Equal risk contribution target for each asset: TRC_i = sigma_p^2 / n
      final targetRisk = variance / n;
      double maxError = 0.0;

      for (int i = 0; i < n; i++) {
        // Condition: cov[i][i] * w[i]^2 + (sum_{j != i} cov[i][j] * w[j]) * w[i] - targetRisk = 0
        final a = cov[i][i];
        double b = 0.0;
        for (int j = 0; j < n; j++) {
          if (j != i) {
            b += cov[i][j] * w[j];
          }
        }
        final c = targetRisk;

        // Quadratic equation: a * w_i^2 + b * w_i - c = 0
        // Unique positive root: w_i = (-b + sqrt(b^2 + 4 * a * c)) / (2 * a)
        final discriminant = b * b + 4.0 * a * c;
        if (a > 0 && discriminant >= 0) {
          final newWi = (-b + sqrt(discriminant)) / (2.0 * a);
          final diff = (newWi - w[i]).abs();
          if (diff > maxError) maxError = diff;
          w[i] = newWi > 0 ? newWi : 1e-6;
        }
      }

      // Normalize weights
      final sumW = w.fold(0.0, (sum, val) => sum + val);
      if (sumW > 0) {
        w = w.map((val) => val / sumW).toList();
      }

      if (maxError < tolerance) {
        break;
      }
    }

    final result = <String, double>{};
    for (int i = 0; i < n; i++) {
      result[activeAssets[i]] = w[i] * riskyBudget;
    }
    if (assets.contains('Cash')) {
      result['Cash'] = cashTarget;
    }
    return result;
  }

  /// Evaluates tax lot harvesting and capital gains deferral opportunities
  /// for the recommended rebalancing adjustments.
  static List<TaxAwareRebalancingHint> generateTaxAwareHints({
    required Map<String, double> currentAllocation,
    required Map<String, double> targetAllocation,
    required double totalEquity,
    required double driftThreshold,
    List<TaxLot>? taxLots,
    List<dynamic>? positions,
    Map<String, double>? currentPrices,
  }) {
    final hints = <TaxAwareRebalancingHint>[];
    final lots = taxLots ?? [];

    currentAllocation.forEach((key, currentPct) {
      final targetPct = targetAllocation[key] ?? 0.0;
      final diff = targetPct - currentPct;
      final amount = diff * totalEquity;

      if (amount.abs() <= driftThreshold) return;

      if (amount > 0) {
        // Buy / Inflow recommendation
        final action = key == 'Cash' ? 'Raise' : 'Buy';
        hints.add(TaxAwareRebalancingHint(
          key: key,
          amount: amount,
          action: action,
          hintMessage:
              'Tax-neutral: Rebalance with available cash or dividends without selling appreciated lots.',
          isTaxAdvantaged: true,
        ));
      } else {
        // Sell / Outflow recommendation
        final action = key == 'Cash' ? 'Invest' : 'Sell';
        final assetLots =
            lots.where((l) => l.symbol == key || l.isSelectable).toList();

        double harvestableLoss = 0.0;
        double shortTermGain = 0.0;
        double longTermGain = 0.0;

        if (assetLots.isNotEmpty) {
          for (var lot in assetLots) {
            final price = currentPrices?[lot.symbol] ?? lot.costPerShare;
            final gainLoss = lot.unrealizedGainLoss(price);
            if (gainLoss < 0) {
              harvestableLoss += gainLoss.abs();
            } else if (lot.isShortTerm) {
              shortTermGain += gainLoss;
            } else {
              longTermGain += gainLoss;
            }
          }
        } else if (positions != null && positions.isNotEmpty) {
          for (var pos in positions) {
            try {
              final sym = pos.instrumentObj?.symbol;
              final sector = pos.instrumentObj?.fundamentalsObj?.sector;
              if (sym == key || sector == key || key == 'Stocks') {
                final gl = (pos.gainLoss as num?)?.toDouble() ?? 0.0;
                if (gl < 0) {
                  harvestableLoss += gl.abs();
                } else {
                  shortTermGain += gl;
                }
              }
            } catch (_) {}
          }
        }

        if (harvestableLoss > 50.0) {
          hints.add(TaxAwareRebalancingHint(
            key: key,
            amount: amount,
            action: action,
            harvestableLoss: harvestableLoss,
            hintMessage:
                'Tax-Loss Harvest: \$${harvestableLoss.toStringAsFixed(0)} in unrealized losses available to offset gains.',
            isTaxAdvantaged: true,
          ));
        } else if (shortTermGain > 100.0 || longTermGain > 150.0) {
          final estTax = (shortTermGain * 0.24) + (longTermGain * 0.15);
          hints.add(TaxAwareRebalancingHint(
            key: key,
            amount: amount,
            action: action,
            estimatedTaxLiability: estTax,
            hintMessage:
                'Tax Alert: Trims may incur ~\$${estTax.toStringAsFixed(0)} in capital gains tax. Prefer new cash inflows.',
            isTaxAdvantaged: false,
          ));
        } else {
          hints.add(TaxAwareRebalancingHint(
            key: key,
            amount: amount,
            action: action,
            hintMessage:
                'Standard rebalance trim to achieve target risk weighting.',
            isTaxAdvantaged: false,
          ));
        }
      }
    });

    return hints;
  }
}
