import 'dart:math';

import 'package:robinhood_options_mobile/model/forex_holding.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_marketdata.dart';

/// Represents a single asset or position's contribution to portfolio beta-weighted delta.
class BetaDeltaDriver {
  final String symbol;
  final String assetClass; // 'Equity', 'Option', 'Futures', 'Crypto', 'Forex'
  final double beta;
  final double deltaShares;
  final double dollarDelta;
  final double dollarDelta1Pct;

  const BetaDeltaDriver({
    required this.symbol,
    required this.assetClass,
    required this.beta,
    required this.deltaShares,
    required this.dollarDelta,
    required this.dollarDelta1Pct,
  });
}

/// Aggregated cross-asset Greeks result normalized to a benchmark (e.g. SPY).
class BetaWeightedGreeksResult {
  final String benchmarkSymbol;
  final double benchmarkPrice;
  final double netDeltaShares; // Equivalent benchmark shares
  final double dollarDelta1Pct; // Portfolio $ P&L per +1% move in benchmark
  final double netGamma; // Aggregate options gamma
  final double netTheta; // Aggregate daily theta decay ($/day)
  final double netVega; // Aggregate vega ($/1% IV)

  final double equityDeltaShares;
  final double optionDeltaShares;
  final double futuresDeltaShares;
  final double forexDeltaShares;

  final double equityDollarDelta;
  final double optionDollarDelta;
  final double futuresDollarDelta;
  final double forexDollarDelta;

  final String stance; // 'Bullish', 'Neutral', 'Bearish'
  final int totalPositions;
  final int pricedPositions;
  final List<BetaDeltaDriver> topDrivers;

  const BetaWeightedGreeksResult({
    required this.benchmarkSymbol,
    required this.benchmarkPrice,
    required this.netDeltaShares,
    required this.dollarDelta1Pct,
    required this.netGamma,
    required this.netTheta,
    required this.netVega,
    required this.equityDeltaShares,
    required this.optionDeltaShares,
    required this.futuresDeltaShares,
    required this.forexDeltaShares,
    required this.equityDollarDelta,
    required this.optionDollarDelta,
    required this.futuresDollarDelta,
    required this.forexDollarDelta,
    required this.stance,
    required this.totalPositions,
    required this.pricedPositions,
    required this.topDrivers,
  });

  bool get hasData => pricedPositions > 0;
}

class AnalyticsUtils {
  /// Aggregates cross-asset positions (stocks, options, futures, crypto/forex)
  /// into beta-weighted Greeks normalized to a benchmark index (default: SPY).
  ///
  /// For each asset:
  /// - Equities: Dollar Delta = shares * price
  /// - Options: Dollar Delta = contracts * multiplier * delta * underlyingSpot
  /// - Futures: Dollar Delta = notionalValue
  /// - Forex/Crypto: Dollar Delta = marketValue
  ///
  /// Weighted Dollar Delta = Dollar Delta * Beta
  /// Benchmark Equivalent Shares (Delta_beta) = Weighted Dollar Delta / Benchmark Price
  /// Dollar Delta (1% Market Move) = Weighted Dollar Delta * 0.01
  static BetaWeightedGreeksResult calculateBetaWeightedGreeks({
    Iterable<InstrumentPosition>? equityPositions,
    Iterable<OptionAggregatePosition>? optionPositions,
    Iterable<dynamic>? futuresPositions,
    Iterable<ForexHolding>? forexHoldings,
    String benchmarkSymbol = 'SPY',
    double? benchmarkPrice,
    Map<String, double>? assetBetas,
  }) {
    final effectiveBenchmarkPrice =
        (benchmarkPrice != null && benchmarkPrice > 0 && benchmarkPrice.isFinite)
            ? benchmarkPrice
            : _defaultBenchmarkPrice(benchmarkSymbol);

    double totalWeightedDollarDelta = 0;
    double equityDollarDelta = 0;
    double optionDollarDelta = 0;
    double futuresDollarDelta = 0;
    double forexDollarDelta = 0;

    double netGamma = 0;
    double netTheta = 0;
    double netVega = 0;

    int totalPositions = 0;
    int pricedPositions = 0;

    final drivers = <BetaDeltaDriver>[];

    // 1. Equities
    if (equityPositions != null) {
      for (final position in equityPositions) {
        final quantity = position.quantity ?? 0.0;
        if (quantity == 0 || !quantity.isFinite) continue;
        totalPositions++;

        final rawSymbol = position.instrumentObj?.symbol;
        final rawName = position.instrumentObj?.simpleName;
        final symbol = (rawSymbol != null && !_isId(rawSymbol))
            ? rawSymbol
            : ((rawName != null && !_isId(rawName)) ? rawName : 'Stock');
        final price = position.instrumentObj?.quoteObj?.lastTradePrice ??
            position.averageBuyPrice ??
            0.0;
        if (price <= 0 || !price.isFinite) continue;
        pricedPositions++;

        final beta = _resolveBeta(symbol, assetBetas, defaultBeta: 1.0);
        final dollarDelta = quantity * price;
        final weightedDollarDelta = dollarDelta * beta;
        final deltaShares = weightedDollarDelta / effectiveBenchmarkPrice;

        equityDollarDelta += weightedDollarDelta;
        totalWeightedDollarDelta += weightedDollarDelta;

        drivers.add(BetaDeltaDriver(
          symbol: symbol,
          assetClass: 'Equity',
          beta: beta,
          deltaShares: deltaShares,
          dollarDelta: weightedDollarDelta,
          dollarDelta1Pct: weightedDollarDelta * 0.01,
        ));
      }
    }

    // 2. Options
    if (optionPositions != null) {
      for (final position in optionPositions) {
        final quantity = position.quantity;
        final marketData = position.optionInstrument?.optionMarketData;
        if (quantity == null || quantity == 0 || !quantity.isFinite) continue;
        totalPositions++;

        final chainSymbol = position.optionInstrument?.chainSymbol;
        final instSymbol = position.instrumentObj?.symbol;
        final posSymbol = position.symbol;

        String cleanSymbol = '';
        if (chainSymbol != null && !_isId(chainSymbol)) {
          cleanSymbol = chainSymbol;
        } else if (instSymbol != null && !_isId(instSymbol)) {
          cleanSymbol = instSymbol;
        } else if (!_isId(posSymbol)) {
          cleanSymbol = posSymbol;
        }

        final multiplier = position.tradeValueMultiplier ?? 100.0;
        final direction =
            position.direction.toLowerCase() == 'credit' ? -1 : 1;
        final scale = quantity * multiplier * direction;

        final delta = marketData?.delta;
        final gamma = marketData?.gamma;
        final theta = marketData?.theta;
        final vega = marketData?.vega;

        final spotPrice = position.instrumentObj?.quoteObj?.lastTradePrice ??
            position.optionInstrument?.strikePrice ??
            0.0;

        if (delta != null && delta.isFinite && spotPrice > 0) {
          pricedPositions++;
          final beta = _resolveBeta(cleanSymbol, assetBetas, defaultBeta: 1.0);
          final rawDollarDelta = delta * scale * spotPrice;
          final weightedDollarDelta = rawDollarDelta * beta;
          final deltaShares = weightedDollarDelta / effectiveBenchmarkPrice;

          optionDollarDelta += weightedDollarDelta;
          totalWeightedDollarDelta += weightedDollarDelta;

          drivers.add(BetaDeltaDriver(
            symbol: cleanSymbol.isNotEmpty ? '$cleanSymbol (Opt)' : 'Option',
            assetClass: 'Option',
            beta: beta,
            deltaShares: deltaShares,
            dollarDelta: weightedDollarDelta,
            dollarDelta1Pct: weightedDollarDelta * 0.01,
          ));
        }

        if (gamma != null && gamma.isFinite) {
          netGamma += gamma * scale;
        }
        if (theta != null && theta.isFinite) {
          netTheta += theta * scale;
        }
        if (vega != null && vega.isFinite) {
          netVega += vega * scale;
        }
      }
    }

    // 3. Futures
    if (futuresPositions != null) {
      for (final pos in futuresPositions) {
        if (pos == null) continue;
        totalPositions++;
        double notional = 0.0;
        String symbol = 'Futures';
        if (pos is Map) {
          notional = double.tryParse(pos['notionalValue']?.toString() ?? '') ??
              (double.tryParse(pos['openPnlCalc']?.toString() ?? '') ?? 0.0);

          final product = pos['product'] is Map ? pos['product'] as Map : null;
          final contract = pos['contract'] is Map ? pos['contract'] as Map : null;

          final productSymbol = product?['symbol']?.toString();
          final contractRoot = contract?['rootSymbol']?.toString();
          final contractSymbol = contract?['symbol']?.toString();
          final contractName = contract?['name']?.toString();
          final posSymbol = pos['symbol']?.toString();

          if (productSymbol != null && !_isId(productSymbol)) {
            symbol = productSymbol;
          } else if (contractRoot != null && !_isId(contractRoot)) {
            symbol = contractRoot;
          } else if (contractSymbol != null && !_isId(contractSymbol)) {
            symbol = contractSymbol;
          } else if (posSymbol != null && !_isId(posSymbol)) {
            symbol = posSymbol;
          } else if (contractName != null && !_isId(contractName)) {
            symbol = contractName;
          }
        }
        if (notional != 0 && notional.isFinite) {
          pricedPositions++;
          final beta = _resolveFuturesBeta(symbol, assetBetas);
          final weightedDollarDelta = notional * beta;
          final deltaShares = weightedDollarDelta / effectiveBenchmarkPrice;

          futuresDollarDelta += weightedDollarDelta;
          totalWeightedDollarDelta += weightedDollarDelta;

          drivers.add(BetaDeltaDriver(
            symbol: symbol,
            assetClass: 'Futures',
            beta: beta,
            deltaShares: deltaShares,
            dollarDelta: weightedDollarDelta,
            dollarDelta1Pct: weightedDollarDelta * 0.01,
          ));
        }
      }
    }

    // 4. Forex / Crypto
    if (forexHoldings != null) {
      for (final holding in forexHoldings) {
        final marketValue = holding.marketValue;
        if (!marketValue.isFinite || marketValue == 0) continue;
        totalPositions++;
        pricedPositions++;

        final rawCode = holding.currencyCode;
        final isCrypto = rawCode.toUpperCase() == 'BTC' ||
            rawCode.toUpperCase() == 'ETH' ||
            rawCode.toUpperCase() == 'SOL' ||
            rawCode.toUpperCase() == 'DOGE' ||
            holding.currencyName.toLowerCase().contains('coin') ||
            holding.currencyName.toLowerCase().contains('crypto');
        final code = !_isId(rawCode)
            ? rawCode
            : (!_isId(holding.currencyName)
                ? holding.currencyName
                : (isCrypto ? 'Crypto' : 'Forex'));

        final beta = _resolveForexCryptoBeta(code, isCrypto, assetBetas);
        final weightedDollarDelta = marketValue * beta;
        final deltaShares = weightedDollarDelta / effectiveBenchmarkPrice;

        forexDollarDelta += weightedDollarDelta;
        totalWeightedDollarDelta += weightedDollarDelta;

        drivers.add(BetaDeltaDriver(
          symbol: code,
          assetClass: isCrypto ? 'Crypto' : 'Forex',
          beta: beta,
          deltaShares: deltaShares,
          dollarDelta: weightedDollarDelta,
          dollarDelta1Pct: weightedDollarDelta * 0.01,
        ));
      }
    }

    // Sort drivers by largest absolute dollar exposure
    drivers.sort((a, b) => b.dollarDelta.abs().compareTo(a.dollarDelta.abs()));

    final netDeltaShares =
        totalWeightedDollarDelta / effectiveBenchmarkPrice;
    final dollarDelta1Pct = totalWeightedDollarDelta * 0.01;

    String stance = 'Neutral';
    if (netDeltaShares > 10.0) {
      stance = 'Bullish';
    } else if (netDeltaShares < -10.0) {
      stance = 'Bearish';
    }

    return BetaWeightedGreeksResult(
      benchmarkSymbol: benchmarkSymbol,
      benchmarkPrice: effectiveBenchmarkPrice,
      netDeltaShares: netDeltaShares,
      dollarDelta1Pct: dollarDelta1Pct,
      netGamma: netGamma,
      netTheta: netTheta,
      netVega: netVega,
      equityDeltaShares: equityDollarDelta / effectiveBenchmarkPrice,
      optionDeltaShares: optionDollarDelta / effectiveBenchmarkPrice,
      futuresDeltaShares: futuresDollarDelta / effectiveBenchmarkPrice,
      forexDeltaShares: forexDollarDelta / effectiveBenchmarkPrice,
      equityDollarDelta: equityDollarDelta,
      optionDollarDelta: optionDollarDelta,
      futuresDollarDelta: futuresDollarDelta,
      forexDollarDelta: forexDollarDelta,
      stance: stance,
      totalPositions: totalPositions,
      pricedPositions: pricedPositions,
      topDrivers: drivers.take(6).toList(),
    );
  }

  static double _defaultBenchmarkPrice(String symbol) {
    switch (symbol.toUpperCase()) {
      case 'QQQ':
        return 480.0;
      case 'DIA':
        return 420.0;
      case 'IWM':
        return 210.0;
      case 'SPY':
      default:
        return 540.0;
    }
  }

  static double _resolveBeta(
    String symbol,
    Map<String, double>? assetBetas, {
    double defaultBeta = 1.0,
  }) {
    if (symbol.isEmpty) return defaultBeta;
    final upper = symbol.toUpperCase();
    if (assetBetas != null && assetBetas.containsKey(upper)) {
      final b = assetBetas[upper];
      if (b != null && b.isFinite) return b;
    }
    // Check known leveraged / inverse ETFs
    if (upper == 'SQQQ' || upper == 'SPXU' || upper == 'SOXS') return -3.0;
    if (upper == 'TQQQ' || upper == 'UPRO' || upper == 'SOXL') return 3.0;
    if (upper == 'QLD' || upper == 'SSO') return 2.0;
    if (upper == 'PSQ' || upper == 'SH') return -1.0;
    return defaultBeta;
  }

  static double _resolveFuturesBeta(
    String symbol,
    Map<String, double>? assetBetas,
  ) {
    final upper = symbol.toUpperCase();
    if (assetBetas != null && assetBetas.containsKey(upper)) {
      final b = assetBetas[upper];
      if (b != null && b.isFinite) return b;
    }
    if (upper.contains('ES') || upper.contains('MES')) return 1.0;
    if (upper.contains('NQ') || upper.contains('MNQ')) return 1.18;
    if (upper.contains('YM') || upper.contains('MYM')) return 0.85;
    if (upper.contains('RTY') || upper.contains('M2K')) return 1.25;
    if (upper.contains('CL')) return 0.35;
    if (upper.contains('GC')) return 0.05;
    return 1.0;
  }

  static double _resolveForexCryptoBeta(
    String code,
    bool isCrypto,
    Map<String, double>? assetBetas,
  ) {
    final upper = code.toUpperCase();
    if (assetBetas != null && assetBetas.containsKey(upper)) {
      final b = assetBetas[upper];
      if (b != null && b.isFinite) return b;
    }
    if (isCrypto || upper == 'BTC' || upper == 'ETH' || upper == 'SOL') {
      if (upper == 'BTC') return 1.4;
      if (upper == 'ETH') return 1.6;
      return 1.8;
    }
    // Fiat currency pairs
    return 0.15;
  }

  /// Helper to check if a symbol or candidate string is actually an internal ID, UUID,
  /// URL, stringified Map/JSON, or meaningless placeholder rather than a clean ticker symbol.
  static bool _isId(String? s) {
    if (s == null) return true;
    final trimmed = s.trim();
    if (trimmed.isEmpty) return true;
    final lower = trimmed.toLowerCase();
    if (lower == 'id' ||
        lower == 'null' ||
        lower == 'none' ||
        lower == 'unknown' ||
        lower == 'other') {
      return true;
    }
    if (trimmed.startsWith('{') ||
        trimmed.startsWith('[') ||
        trimmed.startsWith('(')) {
      return true;
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return true;
    }
    if (lower.startsWith('id:') || lower.startsWith('id=')) {
      return true;
    }
    // UUID regex: 8-4-4-4-12 hex characters
    final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    if (uuidRegex.hasMatch(trimmed)) return true;

    // Hex-only string of 16 or more chars (e.g. 32-char hex UUID or hash)
    if (trimmed.length >= 16 && RegExp(r'^[0-9a-fA-F-]+$').hasMatch(trimmed)) {
      return true;
    }

    return false;
  }

  /// Aggregates option Greeks using the position direction and contract size.
  /// Positions without usable market data are excluded from the totals.
  static Map<String, double> aggregateOptionGreeks(
    Iterable<OptionAggregatePosition> positions,
  ) {
    final totals = <String, double>{
      'delta': 0,
      'gamma': 0,
      'theta': 0,
      'vega': 0,
      'pricedContracts': 0,
    };

    for (final position in positions) {
      final marketData = position.optionInstrument?.optionMarketData;
      final quantity = position.quantity;
      if (marketData == null || quantity == null || !quantity.isFinite) {
        continue;
      }

      final multiplier = position.tradeValueMultiplier ?? 100;
      if (!multiplier.isFinite || multiplier <= 0) continue;
      final direction = position.direction.toLowerCase() == 'credit' ? -1 : 1;
      final scale = quantity * multiplier * direction;
      _addGreek(totals, 'delta', marketData.delta, scale);
      _addGreek(totals, 'gamma', marketData.gamma, scale);
      _addGreek(totals, 'theta', marketData.theta, scale);
      _addGreek(totals, 'vega', marketData.vega, scale);
      if (_hasAnyGreek(marketData)) {
        totals['pricedContracts'] = totals['pricedContracts']! + quantity.abs();
      }
    }
    return totals;
  }

  static void _addGreek(
    Map<String, double> totals,
    String name,
    double? value,
    double scale,
  ) {
    if (value != null && value.isFinite) {
      totals[name] = totals[name]! + value * scale;
    }
  }

  static bool _hasAnyGreek(OptionMarketData marketData) => [
        marketData.delta,
        marketData.gamma,
        marketData.theta,
        marketData.vega
      ].any((value) => value != null && value.isFinite);

  /// Projects portfolio value under simple proportional market shocks.
  ///
  /// This is deliberately transparent rather than predictive: every holding
  /// is shocked by the same percentage and short exposure moves in the
  /// opposite direction. Invalid or zero-value holdings are excluded.
  static List<Map<String, double>> calculateStressScenarios(
    Map<String, double> exposures, {
    List<double> shocks = const [-0.20, -0.10, -0.05, 0.05, 0.10, 0.20],
  }) {
    final validExposures = exposures.values
        .where((value) => value.isFinite && value != 0)
        .toList();
    final portfolioValue =
        validExposures.fold<double>(0, (sum, value) => sum + value);
    if (!portfolioValue.isFinite || portfolioValue == 0) return const [];

    return shocks
        .where((shock) => shock.isFinite)
        .map((shock) => {
              'shock': shock,
              'change': validExposures.fold<double>(
                  0, (sum, value) => sum + value * shock),
              'projectedValue': portfolioValue * (1 + shock),
              'portfolioValue': portfolioValue,
            })
        .toList();
  }

  /// Summarizes downside exposure and option liquidity using currently
  /// available quotes. The score is a screening aid, not an execution quote.
  static Map<String, double> calculateTailRiskAndLiquidity(
    Map<String, double> exposures,
    Iterable<OptionAggregatePosition> optionPositions,
  ) {
    final validExposures = exposures.values
        .where((value) => value.isFinite && value != 0)
        .toList();
    final downsideLoss =
        validExposures.fold<double>(0, (loss, value) => loss + value * -0.20);

    double weightedSpread = 0;
    double totalWeight = 0;
    double depthRatio = 0;
    double depthWeight = 0;
    var pricedContracts = 0.0;

    for (final position in optionPositions) {
      final marketData = position.optionInstrument?.optionMarketData;
      final quantity = position.quantity?.abs();
      if (marketData == null || quantity == null || quantity == 0) continue;

      final bid = marketData.bidPrice;
      final ask = marketData.askPrice;
      if (bid == null || ask == null || bid < 0 || ask <= 0 || ask < bid) {
        continue;
      }
      final midpoint = (bid + ask) / 2;
      if (!midpoint.isFinite || midpoint <= 0) continue;

      final weight =
          quantity * midpoint * (position.tradeValueMultiplier ?? 100);
      final spread = (ask - bid) / midpoint;
      if (!weight.isFinite || !spread.isFinite) continue;

      weightedSpread += spread * weight;
      totalWeight += weight;
      final quotedDepth = marketData.bidSize + marketData.askSize;
      depthRatio += (quotedDepth / quantity).clamp(0, 100).toDouble() * weight;
      depthWeight += weight;
      pricedContracts += quantity;
    }

    final averageSpread = totalWeight == 0 ? 0.0 : weightedSpread / totalWeight;
    final averageDepthRatio = depthWeight == 0 ? 0.0 : depthRatio / depthWeight;
    final spreadScore = (1 - averageSpread / 0.20).clamp(0, 1).toDouble();
    final depthScore = (averageDepthRatio / 100).clamp(0, 1).toDouble();
    final liquidityScore = (spreadScore * 0.7 + depthScore * 0.3) * 100;

    return {
      'downsideLoss': downsideLoss,
      'averageSpread': averageSpread,
      'averageDepthRatio': averageDepthRatio,
      'liquidityScore': liquidityScore,
      'pricedContracts': pricedContracts,
    };
  }

  static List<double> calculateDailyReturns(List<double> prices) {
    if (prices.length < 2) return [];
    List<double> returns = [];
    for (int i = 1; i < prices.length; i++) {
      if (prices[i - 1] != 0) {
        returns.add((prices[i] - prices[i - 1]) / prices[i - 1]);
      } else {
        returns.add(0.0);
      }
    }
    return returns;
  }

  static double calculateMean(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  static double calculateVariance(List<double> values) {
    if (values.length < 2) return 0.0;
    double mean = calculateMean(values);
    double sumSquaredDiff =
        values.map((v) => pow(v - mean, 2).toDouble()).reduce((a, b) => a + b);
    return sumSquaredDiff / (values.length - 1);
  }

  static double calculateStdDev(List<double> values) {
    return sqrt(calculateVariance(values));
  }

  static double calculateCovariance(List<double> x, List<double> y) {
    if (x.length != y.length || x.length < 2) return 0.0;
    double meanX = calculateMean(x);
    double meanY = calculateMean(y);
    double sumProductDiff = 0.0;
    for (int i = 0; i < x.length; i++) {
      sumProductDiff += (x[i] - meanX) * (y[i] - meanY);
    }
    return sumProductDiff / (x.length - 1);
  }

  static double calculateSharpeRatio(List<double> returns,
      {double riskFreeRate = 0.04}) {
    if (returns.isEmpty) return 0.0;
    // Annualize risk free rate for daily returns
    double dailyRiskFreeRate = riskFreeRate / 252;
    List<double> excessReturns =
        returns.map((r) => r - dailyRiskFreeRate).toList();
    double meanExcessReturn = calculateMean(excessReturns);
    double stdDevExcessReturn = calculateStdDev(excessReturns);

    if (stdDevExcessReturn == 0) return 0.0;
    return (meanExcessReturn / stdDevExcessReturn) * sqrt(252);
  }

  static double calculateBeta(
      List<double> assetReturns, List<double> marketReturns) {
    if (assetReturns.length != marketReturns.length || assetReturns.isEmpty) {
      return 0.0;
    }
    double covariance = calculateCovariance(assetReturns, marketReturns);
    double varianceMarket = calculateVariance(marketReturns);
    if (varianceMarket == 0) return 0.0;
    return covariance / varianceMarket;
  }

  static double calculateAlpha(
      List<double> assetReturns, List<double> marketReturns, double beta,
      {double riskFreeRate = 0.04}) {
    if (assetReturns.isEmpty || marketReturns.isEmpty) return 0.0;
    double dailyRiskFreeRate = riskFreeRate / 252;
    double meanAssetReturn = calculateMean(assetReturns);
    double meanMarketReturn = calculateMean(marketReturns);

    // Alpha = Rp - [Rf + Beta * (Rm - Rf)]
    // Annualized Alpha
    double dailyAlpha = meanAssetReturn -
        (dailyRiskFreeRate + beta * (meanMarketReturn - dailyRiskFreeRate));
    return dailyAlpha * 252;
  }

  static double calculateMaxDrawdown(List<double> prices) {
    if (prices.isEmpty) return 0.0;
    double maxDrawdown = 0.0;
    double peak = prices[0];
    for (double price in prices) {
      if (price > peak) {
        peak = price;
      }
      double drawdown = (peak - price) / peak;
      if (drawdown > maxDrawdown) {
        maxDrawdown = drawdown;
      }
    }
    return maxDrawdown;
  }

  /// Calculates the Profit Factor (Gross Profit / Gross Loss)
  static double calculateProfitFactor(double grossProfit, double grossLoss) {
    if (grossLoss == 0) return grossProfit > 0 ? double.infinity : 0.0;
    return grossProfit / grossLoss.abs();
  }

  /// Calculates the Expectancy per trade
  /// Expectancy = (Avg Win * Win Rate) - (Avg Loss * Loss Rate)
  static double calculateExpectancy(
      double avgWin, double winRate, double avgLoss, double lossRate) {
    return (avgWin * winRate) - (avgLoss * lossRate);
  }

  /// Calculates the Sortino Ratio
  /// Similar to Sharpe Ratio but only penalizes downside volatility
  static double calculateSortinoRatio(List<double> returns,
      {double riskFreeRate = 0.04, double targetReturn = 0.0}) {
    if (returns.isEmpty) return 0.0;
    double dailyRiskFreeRate = riskFreeRate / 252;
    List<double> excessReturns =
        returns.map((r) => r - dailyRiskFreeRate).toList();
    double meanExcessReturn = calculateMean(excessReturns);

    // Calculate downside deviation (only negative returns relative to target)
    List<double> downsideReturns = returns
        .where((r) => r < targetReturn)
        .map((r) => pow(r - targetReturn, 2).toDouble())
        .toList();

    if (downsideReturns.isEmpty) return 0.0;

    double downsideVariance =
        downsideReturns.reduce((a, b) => a + b) / returns.length;
    double downsideDeviation = sqrt(downsideVariance);

    if (downsideDeviation == 0) return 0.0;
    return (meanExcessReturn / downsideDeviation) * sqrt(252);
  }

  /// Calculates the Calmar Ratio
  /// Annualized Return (CAGR) / Max Drawdown
  static double calculateCalmarRatio(
      double totalReturn, double maxDrawdown, double periodYears) {
    if (maxDrawdown == 0 || periodYears <= 0) return 0.0;
    double cagr = pow(1 + totalReturn, 1 / periodYears).toDouble() - 1;
    return cagr / maxDrawdown.abs();
  }

  static double calculateVolatility(List<double> returns) {
    if (returns.isEmpty) return 0.0;
    return calculateStdDev(returns) * sqrt(252);
  }

  /// Calculates rolling annualized risk statistics for aligned price series.
  ///
  /// Each point uses [window] trading sessions ending on its date. The first
  /// point therefore appears after [window] price observations, and contains
  /// volatility, beta, and correlation for the same return sample.
  static List<Map<String, dynamic>> calculateRollingStatistics({
    required List<DateTime> dates,
    required List<double> assetPrices,
    required List<double> benchmarkPrices,
    int window = 30,
  }) {
    if (window < 2 ||
        assetPrices.length != benchmarkPrices.length ||
        assetPrices.length != dates.length ||
        assetPrices.length <= window) {
      return [];
    }

    final points = <Map<String, dynamic>>[];
    for (var end = window; end < assetPrices.length; end++) {
      final assetWindow = assetPrices.sublist(end - window, end + 1);
      final benchmarkWindow = benchmarkPrices.sublist(end - window, end + 1);
      final assetReturns = calculateDailyReturns(assetWindow);
      final benchmarkReturns = calculateDailyReturns(benchmarkWindow);

      points.add({
        'date': dates[end],
        'volatility': calculateVolatility(assetReturns),
        'beta': calculateBeta(assetReturns, benchmarkReturns),
        'correlation': calculateCorrelation(assetReturns, benchmarkReturns),
        'maxDrawdown': calculateMaxDrawdown(assetWindow),
      });
    }
    return points;
  }

  /// Calculates the Compound Annual Growth Rate (CAGR)
  static double calculateCAGR(double totalReturn, double periodYears) {
    if (periodYears <= 0) return 0.0;
    // Handle negative total return case carefully: (1+r)^(1/t) - 1
    // If totalReturn is -50%, base is 0.5.
    return pow(1 + totalReturn, 1 / periodYears).toDouble() - 1;
  }

  static double calculateCumulativeReturn(List<double> prices) {
    if (prices.isEmpty) return 0.0;
    return (prices.last - prices.first) / prices.first;
  }

  static double calculateTreynorRatio(List<double> returns, double beta,
      {double riskFreeRate = 0.04}) {
    if (returns.isEmpty || beta == 0) return 0.0;
    double dailyRiskFreeRate = riskFreeRate / 252;
    List<double> excessReturns =
        returns.map((r) => r - dailyRiskFreeRate).toList();
    double meanExcessReturn = calculateMean(excessReturns);

    // Annualize mean excess return
    double annualizedExcessReturn = meanExcessReturn * 252;

    return annualizedExcessReturn / beta;
  }

  static double calculateInformationRatio(
      List<double> portfolioReturns, List<double> benchmarkReturns) {
    if (portfolioReturns.length != benchmarkReturns.length ||
        portfolioReturns.isEmpty) {
      return 0.0;
    }

    List<double> activeReturns = [];
    for (int i = 0; i < portfolioReturns.length; i++) {
      activeReturns.add(portfolioReturns[i] - benchmarkReturns[i]);
    }

    double meanActiveReturn = calculateMean(activeReturns);
    double trackingError = calculateStdDev(activeReturns);

    if (trackingError == 0) return 0.0;

    // Annualize
    return (meanActiveReturn / trackingError) * sqrt(252);
  }

  static double calculateOmegaRatio(List<double> returns,
      {double threshold = 0.0}) {
    if (returns.isEmpty) return 0.0;
    double sumGains = 0.0;
    double sumLosses = 0.0;

    for (double r in returns) {
      if (r > threshold) {
        sumGains += r - threshold;
      } else {
        sumLosses += threshold - r;
      }
    }

    if (sumLosses == 0) return 0.0;
    return sumGains / sumLosses;
  }

  static double calculateVaR(List<double> returns,
      {double confidenceLevel = 0.95}) {
    if (returns.isEmpty) return 0.0;
    List<double> sortedReturns = List.from(returns)..sort();
    int index =
        ((1 - confidenceLevel) * sortedReturns.length + 0.00001).floor();
    if (index < 0) index = 0;
    if (index >= sortedReturns.length) index = sortedReturns.length - 1;
    return sortedReturns[index];
  }

  static double calculateCVaR(List<double> returns,
      {double confidenceLevel = 0.95}) {
    if (returns.isEmpty) return 0.0;
    List<double> sortedReturns = List.from(returns)..sort();
    int index =
        ((1 - confidenceLevel) * sortedReturns.length + 0.00001).floor();
    if (index < 0) index = 0;
    if (index >= sortedReturns.length) index = sortedReturns.length - 1;

    // Take all returns up to the VaR index (the tail)
    // We include the VaR point itself in the tail average
    List<double> tailReturns = sortedReturns.sublist(0, index + 1);

    if (tailReturns.isEmpty) return 0.0;

    return calculateMean(tailReturns);
  }

  static double calculateCorrelation(
      List<double> assetReturns, List<double> marketReturns) {
    if (assetReturns.length != marketReturns.length || assetReturns.isEmpty) {
      return 0.0;
    }
    double covariance = calculateCovariance(assetReturns, marketReturns);
    double stdDevAsset = calculateStdDev(assetReturns);
    double stdDevMarket = calculateStdDev(marketReturns);

    if (stdDevAsset == 0 || stdDevMarket == 0) return 0.0;
    return covariance / (stdDevAsset * stdDevMarket);
  }

  static double calculateHealthScore({
    required double sharpe,
    required double sortino,
    required double alpha,
    required double maxDrawdown,
    required double beta,
    double? volatility,
    double? benchmarkVolatility,
    double? currentDrawdown,
    double? profitFactor,
    double? winRate,
    double? calmar,
    double? informationRatio,
    double? treynor,
    double? var95,
    double? cvar95,
    double? omega,
    double? correlation,
    double? payoffRatio,
    double? expectancy,
    int? maxLossStreak,
    double? kellyCriterion,
    double? ulcerIndex,
    double? tailRatio,
  }) {
    double healthScore = 50.0; // Start with neutral base (adjusted from 60)

    // Risk-Adjusted Returns (Max +35, Min -15) - Increased max potential
    // Sharpe Ratio - Most important risk-adjusted metric
    if (sharpe > 2.5) {
      healthScore += 18; // Exceptional
    } else if (sharpe > 2.0) {
      healthScore += 15; // Excellent
    } else if (sharpe > 1.5) {
      healthScore += 12; // Very good
    } else if (sharpe > 1.0) {
      healthScore += 9; // Good
    } else if (sharpe > 0.5) {
      healthScore += 5; // Acceptable
    } else if (sharpe > 0) {
      healthScore += 2; // Marginally positive
    } else if (sharpe < -0.5) {
      healthScore -= 10; // Very poor
    } else if (sharpe < 0) {
      healthScore -= 5; // Negative
    }

    // Drawdowns (Current + Max)
    // Penalize if currently in deep drawdown
    if (currentDrawdown != null) {
      if (currentDrawdown < -0.20) {
        healthScore -= 8; // Heavy penalty for deep active drawdown
      } else if (currentDrawdown < -0.10) {
        healthScore -= 4;
      }
    }

    // Sortino Ratio - Downside-focused risk measure
    if (sortino > 2.5) {
      healthScore += 10; // Exceptional downside control
    } else if (sortino > 1.5) {
      healthScore += 7; // Very good
    } else if (sortino > 0.75) {
      healthScore += 4; // Acceptable
    }

    // Treynor Ratio - Systematic risk efficiency
    if (treynor != null) {
      if (treynor > 0.20) {
        healthScore += 4; // Excellent
      } else if (treynor > 0.10) {
        healthScore += 2; // Good
      }
    }

    // Omega Ratio - Probability weighted gains vs losses
    if (omega != null) {
      if (omega > 2.5) {
        healthScore += 5; // Exceptional
      } else if (omega > 1.5) {
        healthScore += 3; // Very good
      } else if (omega < 1.0) {
        healthScore -= 5; // More losses than gains
      }
    }

    // Market Performance (Max +20, Min -15) - Alpha & Outperformance
    if (alpha > 0.10) {
      healthScore += 15; // Beating market by >10%
    } else if (alpha > 0.05) {
      healthScore += 12; // Beating market by >5%
    } else if (alpha > 0.02) {
      healthScore += 8; // Beating market by >2%
    } else if (alpha > 0) {
      healthScore += 4; // Positive alpha
    } else if (alpha < -0.10) {
      healthScore -= 10; // Significantly underperforming
    } else if (alpha < -0.05) {
      healthScore -= 6; // Underperforming
    } else if (alpha < 0) {
      healthScore -= 3; // Slightly negative
    }

    // Information Ratio - Consistency of outperformance
    if (informationRatio != null) {
      if (informationRatio > 0.75) {
        healthScore += 5; // Very consistent outperformance
      } else if (informationRatio > 0.25) {
        healthScore += 3; // Consistent outperformance
      } else if (informationRatio < -0.5) {
        healthScore -= 5; // Consistently underperforming
      } else if (informationRatio < 0) {
        healthScore -= 2; // Inconsistent
      }
    }

    // Risk Management (Max +20, Min -40) - Drawdown, volatility, tail risk
    // Max Drawdown - Most critical risk metric
    if (maxDrawdown < 0.05) {
      healthScore += 12; // Exceptional risk control (<5%)
    } else if (maxDrawdown < 0.10) {
      healthScore += 8; // Excellent (<10%)
    } else if (maxDrawdown < 0.15) {
      healthScore += 4; // Good (<15%)
    } else if (maxDrawdown > 0.40) {
      healthScore -= 25; // Catastrophic (>40%)
    } else if (maxDrawdown > 0.30) {
      healthScore -= 15; // Severe (>30%)
    } else if (maxDrawdown > 0.20) {
      healthScore -= 8; // High (>20%)
    }

    // Volatility vs Benchmark
    if (volatility != null && benchmarkVolatility != null) {
      double volRatio = volatility / benchmarkVolatility;
      if (volRatio < 0.8) {
        healthScore += 6; // Much lower volatility than market
      } else if (volRatio < 1.0) {
        healthScore += 3; // Lower volatility
      } else if (volRatio > 1.5) {
        healthScore -= 8; // 50% more volatile
      } else if (volRatio > 1.25) {
        healthScore -= 4; // 25% more volatile
      }
    }

    // Beta - Market sensitivity
    if (beta > 1.8) {
      healthScore -= 6; // Very aggressive
    } else if (beta > 1.5) {
      healthScore -= 3; // Aggressive
    } else if (beta < 0.3) {
      healthScore -= 4; // Too defensive/disconnected
    }

    // Value at Risk (VaR 95%)
    if (var95 != null) {
      if (var95 < -0.04) {
        healthScore -= 6; // High daily risk (>4%)
      }
      if (var95 < -0.06) {
        healthScore -= 6; // Extreme daily risk (>6%)
      }
    }

    // Conditional VaR (tail risk)
    if (cvar95 != null) {
      if (cvar95 < -0.10) {
        healthScore -= 8; // Extreme tail risk (>10%)
      } else if (cvar95 < -0.07) {
        healthScore -= 4; // High tail risk (>7%)
      }
    }

    // Correlation - Diversification benefit
    if (correlation != null) {
      if (correlation > 0 && correlation < 0.6) {
        healthScore += 6; // Excellent diversification
      } else if (correlation < 0.8) {
        healthScore += 3; // Good diversification
      } else if (correlation > 0.98) {
        healthScore -= 4; // Essentially tracking the index
      }
    }

    // Efficiency & Consistency (Max +30, Min -15)
    // Profit Factor - Win/Loss ratio
    if (profitFactor != null) {
      if (profitFactor > 3.0) {
        healthScore += 12; // Exceptional (3:1 win/loss)
      } else if (profitFactor > 2.0) {
        healthScore += 9; // Excellent (2:1)
      } else if (profitFactor > 1.5) {
        healthScore += 6; // Very good (1.5:1)
      } else if (profitFactor > 1.2) {
        healthScore += 3; // Good
      } else if (profitFactor < 0.9) {
        healthScore -= 12; // Losing money
      } else if (profitFactor < 1.0) {
        healthScore -= 6; // Break-even or slight loss
      }
    }

    // Win Rate - Consistency
    if (winRate != null) {
      if (winRate > 0.65) {
        healthScore += 8; // Very consistent
      } else if (winRate > 0.55) {
        healthScore += 5; // Consistent
      } else if (winRate > 0.50) {
        healthScore += 2; // Slightly above average
      } else if (winRate < 0.35) {
        healthScore -= 6; // Very inconsistent
      } else if (winRate < 0.45) {
        healthScore -= 3; // Below average
      }
    }

    // Calmar Ratio - Return/Drawdown efficiency
    if (calmar != null) {
      if (calmar > 2.0) {
        healthScore += 6; // Exceptional
      } else if (calmar > 1.0) {
        healthScore += 3; // Good
      } else if (calmar < 0) {
        healthScore -= 3; // Negative returns
      }
    }

    // Payoff Ratio - Avg Win/Avg Loss
    if (payoffRatio != null) {
      if (payoffRatio > 2.5) {
        healthScore += 5; // Excellent asymmetry
      } else if (payoffRatio > 1.5) {
        healthScore += 3; // Good
      } else if (payoffRatio < 0.7) {
        healthScore -= 4; // Losses bigger than wins
      }
    }

    // Expectancy - Mathematical edge
    if (expectancy != null) {
      if (expectancy > 0) {
        healthScore += 4; // Positive edge
      } else {
        healthScore -= 4; // No edge
      }
    }

    // Loss Streaks
    if (maxLossStreak != null) {
      if (maxLossStreak > 7) {
        healthScore -= 5; // Concerning pattern
      } else if (maxLossStreak > 5) {
        healthScore -= 2;
      }
    }

    // Advanced Risk & Edge (Max +15, Min -15)
    // Kelly Criterion - Optimal position sizing
    if (kellyCriterion != null) {
      if (kellyCriterion > 0.15) {
        healthScore += 6; // Very strong edge
      } else if (kellyCriterion > 0.08) {
        healthScore += 4; // Strong edge
      } else if (kellyCriterion > 0) {
        healthScore += 2; // Positive edge
      } else if (kellyCriterion < -0.05) {
        healthScore -= 6; // Negative edge
      }
    }

    // Ulcer Index - Stress/drawdown depth
    if (ulcerIndex != null) {
      if (ulcerIndex < 0.03) {
        healthScore += 4; // Very low stress
      } else if (ulcerIndex < 0.08) {
        healthScore += 2; // Low stress
      } else if (ulcerIndex > 0.20) {
        healthScore -= 6; // High stress
      } else if (ulcerIndex > 0.15) {
        healthScore -= 3; // Moderate stress
      }
    }

    // Tail Ratio - Upside vs downside extremes
    if (tailRatio != null) {
      if (tailRatio > 1.3) {
        healthScore += 5; // Strong positive skew
      } else if (tailRatio > 1.0) {
        healthScore += 2; // Positive skew
      } else if (tailRatio < 0.7) {
        healthScore -= 6; // Negative skew (bad tails)
      } else if (tailRatio < 0.9) {
        healthScore -= 3; // Slightly negative skew
      }
    }

    return healthScore.clamp(0.0, 100.0);
  }

  static int calculateMaxWinningStreak(List<double> returns) {
    if (returns.isEmpty) return 0;
    int maxStreak = 0;
    int currentStreak = 0;
    for (double r in returns) {
      if (r > 0) {
        currentStreak++;
        if (currentStreak > maxStreak) maxStreak = currentStreak;
      } else {
        currentStreak = 0;
      }
    }
    return maxStreak;
  }

  static int calculateMaxLosingStreak(List<double> returns) {
    if (returns.isEmpty) return 0;
    int maxStreak = 0;
    int currentStreak = 0;
    for (double r in returns) {
      if (r < 0) {
        currentStreak++;
        if (currentStreak > maxStreak) maxStreak = currentStreak;
      } else {
        currentStreak = 0;
      }
    }
    return maxStreak;
  }

  /// Calculates the Kelly Criterion percentage
  /// K% = W - (1 - W) / R
  /// Where W = Win Probability, R = Win/Loss Ratio
  static double calculateKellyCriterion(double winRate, double payoffRatio) {
    if (payoffRatio == 0) return 0.0;
    return winRate - (1 - winRate) / payoffRatio;
  }

  /// Calculates the Ulcer Index
  /// UI = sqrt(sum(Ri^2) / n)
  /// Where Ri is the percentage drawdown from the highest high
  static double calculateUlcerIndex(List<double> prices) {
    if (prices.isEmpty) return 0.0;
    double maxPrice = prices[0];
    double sumSquaredDrawdowns = 0.0;

    for (double price in prices) {
      if (price > maxPrice) {
        maxPrice = price;
      }
      double drawdown = (price - maxPrice) / maxPrice; // Negative value
      sumSquaredDrawdowns += pow(drawdown, 2);
    }

    return sqrt(sumSquaredDrawdowns / prices.length);
  }

  /// Calculates the Tail Ratio
  /// Ratio of the 95th percentile return to the absolute value of the 5th percentile return
  static double calculateTailRatio(List<double> returns) {
    if (returns.isEmpty) return 0.0;
    List<double> sortedReturns = List.from(returns)..sort();

    int index95 = (0.95 * sortedReturns.length).floor();
    int index05 = (0.05 * sortedReturns.length).floor();

    if (index95 >= sortedReturns.length) index95 = sortedReturns.length - 1;
    if (index05 < 0) index05 = 0;

    double return95 = sortedReturns[index95];
    double return05 = sortedReturns[index05];

    if (return05 == 0) return 0.0;
    return return95 / return05.abs();
  }

  /// Calculates comprehensive portfolio metrics
  static Map<String, dynamic> calculatePortfolioMetrics({
    required List<double> alignedPortfolioPrices,
    required List<double> alignedBenchmarkPrices,
    required List<double> fullPortfolioPrices,
    required double periodYears,
    List<DateTime>? alignedDates,
  }) {
    if (alignedPortfolioPrices.length < 2 ||
        alignedBenchmarkPrices.length < 2) {
      return {};
    }

    List<double> portfolioReturns =
        calculateDailyReturns(alignedPortfolioPrices);
    List<double> benchmarkReturns =
        calculateDailyReturns(alignedBenchmarkPrices);

    List<double> activeReturns = [];
    for (int i = 0; i < portfolioReturns.length; i++) {
      activeReturns.add(portfolioReturns[i] - benchmarkReturns[i]);
    }

    double sharpe = calculateSharpeRatio(portfolioReturns);
    double beta = calculateBeta(portfolioReturns, benchmarkReturns);
    double correlation =
        calculateCorrelation(portfolioReturns, benchmarkReturns);
    double alpha = calculateAlpha(portfolioReturns, benchmarkReturns, beta);
    double maxDrawdown = calculateMaxDrawdown(alignedPortfolioPrices);
    double volatility = calculateVolatility(portfolioReturns);
    double benchmarkVolatility = calculateVolatility(benchmarkReturns);

    double portfolioCumulative = fullPortfolioPrices.length >= 2
        ? calculateCumulativeReturn(fullPortfolioPrices)
        : calculateCumulativeReturn(alignedPortfolioPrices);
    double benchmarkCumulative =
        calculateCumulativeReturn(alignedBenchmarkPrices);

    double trackingError = activeReturns.isNotEmpty
        ? calculateStdDev(activeReturns) * sqrt(252)
        : 0.0;
    double avgDailyReturn = calculateMean(portfolioReturns);

    double currentDrawdown = 0.0;
    if (alignedPortfolioPrices.isNotEmpty) {
      double currentPrice = alignedPortfolioPrices.last;
      // Peak of the selected period (High Water Mark for this window)
      double peak = alignedPortfolioPrices.reduce(max);
      if (peak != 0) {
        currentDrawdown = (currentPrice - peak) / peak;
      }
    }

    double bestDay = 0.0;
    double worstDay = 0.0;
    DateTime? bestDayDate;
    DateTime? worstDayDate;

    if (portfolioReturns.isNotEmpty) {
      int bestIdx = 0;
      int worstIdx = 0;
      bestDay = portfolioReturns[0];
      worstDay = portfolioReturns[0];

      for (int i = 1; i < portfolioReturns.length; i++) {
        if (portfolioReturns[i] > bestDay) {
          bestDay = portfolioReturns[i];
          bestIdx = i;
        }
        if (portfolioReturns[i] < worstDay) {
          worstDay = portfolioReturns[i];
          worstIdx = i;
        }
      }

      if (alignedDates != null && alignedDates.length > bestIdx + 1) {
        // aligns with daily returns which start from index 1 (date[1])
        bestDayDate = alignedDates[bestIdx + 1];
        worstDayDate = alignedDates[worstIdx + 1];
      }
    }

    double sortino = calculateSortinoRatio(portfolioReturns);
    double treynor = calculateTreynorRatio(portfolioReturns, beta);
    double informationRatio =
        calculateInformationRatio(portfolioReturns, benchmarkReturns);

    double calmar =
        calculateCalmarRatio(portfolioCumulative, maxDrawdown, periodYears);
    double omega = calculateOmegaRatio(portfolioReturns);
    double var95 = calculateVaR(portfolioReturns);
    double cvar95 = calculateCVaR(portfolioReturns);

    // Calculate Daily Stats (Dollar based)
    double grossProfit = 0.0;
    double grossLoss = 0.0;
    int winCount = 0;
    int lossCount = 0;
    double totalWinAmt = 0.0;
    double totalLossAmt = 0.0;

    for (int i = 1; i < alignedPortfolioPrices.length; i++) {
      double diff = alignedPortfolioPrices[i] - alignedPortfolioPrices[i - 1];
      if (diff > 0) {
        grossProfit += diff;
        winCount++;
        totalWinAmt += diff;
      } else if (diff < 0) {
        grossLoss += diff.abs();
        lossCount++;
        totalLossAmt += diff.abs();
      }
    }

    double profitFactor = calculateProfitFactor(grossProfit, grossLoss);
    double winRate =
        (winCount + lossCount) > 0 ? winCount / (winCount + lossCount) : 0.0;
    double avgWin = winCount > 0 ? totalWinAmt / winCount : 0.0;
    // Return negative value for Avg Loss to make it intuitive
    double avgLoss = lossCount > 0 ? -(totalLossAmt / lossCount) : 0.0;
    // Payoff Ratio uses absolute values: Avg Win / |Avg Loss|
    double payoffRatio = avgLoss != 0 ? avgWin / avgLoss.abs() : 0.0;
    double expectancy = (avgWin * winRate) - (avgLoss * (1 - winRate));

    int maxWinStreak = calculateMaxWinningStreak(portfolioReturns);
    int maxLossStreak = calculateMaxLosingStreak(portfolioReturns);

    double kellyCriterion = calculateKellyCriterion(winRate, payoffRatio);
    double ulcerIndex = calculateUlcerIndex(alignedPortfolioPrices);
    double tailRatio = calculateTailRatio(portfolioReturns);

    double cagr = calculateCAGR(portfolioCumulative, periodYears);

    double healthScore = calculateHealthScore(
      sharpe: sharpe,
      sortino: sortino,
      alpha: alpha,
      maxDrawdown: maxDrawdown,
      currentDrawdown: currentDrawdown,
      beta: beta,
      volatility: volatility,
      benchmarkVolatility: benchmarkVolatility,
      profitFactor: profitFactor,
      winRate: winRate,
      calmar: calmar,
      informationRatio: informationRatio,
      treynor: treynor,
      var95: var95,
      cvar95: cvar95,
      omega: omega,
      correlation: correlation,
      payoffRatio: payoffRatio,
      expectancy: expectancy,
      maxLossStreak: maxLossStreak,
      kellyCriterion: kellyCriterion,
      ulcerIndex: ulcerIndex,
      tailRatio: tailRatio,
    );

    return {
      'sharpe': sharpe,
      'beta': beta,
      'correlation': correlation,
      'alpha': alpha,
      'maxDrawdown': maxDrawdown,
      'currentDrawdown': currentDrawdown,
      'volatility': volatility,
      'benchmarkVolatility': benchmarkVolatility,
      'portfolioCumulative': portfolioCumulative,
      'benchmarkCumulative': benchmarkCumulative,
      'trackingError': trackingError,
      'avgDailyReturn': avgDailyReturn,
      'bestDay': bestDay,
      'worstDay': worstDay,
      'bestDayDate': bestDayDate,
      'worstDayDate': worstDayDate,
      'sortino': sortino,
      'treynor': treynor,
      'informationRatio': informationRatio,
      'calmar': calmar,
      'omega': omega,
      'var95': var95,
      'cvar95': cvar95,
      'profitFactor': profitFactor,
      'winRate': winRate,
      'cagr': cagr,
      'avgWin': avgWin,
      'avgLoss': avgLoss,
      'payoffRatio': payoffRatio,
      'expectancy': expectancy,
      'maxWinStreak': maxWinStreak,
      'maxLossStreak': maxLossStreak,
      'kellyCriterion': kellyCriterion,
      'ulcerIndex': ulcerIndex,
      'tailRatio': tailRatio,
      'healthScore': healthScore,
    };
  }
}
