import 'dart:math';

class AnalyticsUtils {
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

  static double calculateVolatility(List<double> returns) {
    if (returns.isEmpty) return 0.0;
    return calculateStdDev(returns) * sqrt(252);
  }

  static double calculateCumulativeReturn(List<double> prices) {
    if (prices.isEmpty) return 0.0;
    return (prices.last - prices.first) / prices.first;
  }

  static double calculateSortinoRatio(List<double> returns,
      {double riskFreeRate = 0.04}) {
    if (returns.isEmpty) return 0.0;
    double dailyRiskFreeRate = riskFreeRate / 252;
    List<double> excessReturns =
        returns.map((r) => r - dailyRiskFreeRate).toList();
    double meanExcessReturn = calculateMean(excessReturns);

    // Calculate Downside Deviation (using 0 as target return for downside)
    // Standard Sortino uses MAR (Minimum Acceptable Return), often 0 or Risk Free Rate.
    // Here we use Risk Free Rate as the target, consistent with Sharpe.
    List<double> downsideSquared = excessReturns
        .where((r) => r < 0)
        .map((r) => pow(r, 2).toDouble())
        .toList();

    if (downsideSquared.isEmpty) return 0.0; // No downside volatility

    double downsideVariance =
        downsideSquared.reduce((a, b) => a + b) / returns.length;
    double downsideDeviation = sqrt(downsideVariance);

    if (downsideDeviation == 0) return 0.0;
    return (meanExcessReturn / downsideDeviation) * sqrt(252);
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
        portfolioReturns.isEmpty) return 0.0;

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

  static double calculateCalmarRatio(List<double> returns, double maxDrawdown) {
    if (returns.isEmpty || maxDrawdown == 0) return 0.0;
    double meanReturn = calculateMean(returns);
    double annualizedReturn = meanReturn * 252;
    return annualizedReturn / maxDrawdown;
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
    int index = ((1 - confidenceLevel) * sortedReturns.length).floor();
    if (index < 0) index = 0;
    if (index >= sortedReturns.length) index = sortedReturns.length - 1;
    return sortedReturns[index];
  }
}
