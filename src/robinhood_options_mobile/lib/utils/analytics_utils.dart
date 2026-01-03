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
    double healthScore = 60.0; // Start with a neutral base

    // Risk-Adjusted Returns (Max +30, Min -15)
    if (sharpe > 2.0) {
      healthScore += 15;
    } else if (sharpe > 1.5) {
      healthScore += 12;
    } else if (sharpe > 1.0) {
      healthScore += 8;
    } else if (sharpe > 0.5) {
      healthScore += 4;
    } else if (sharpe < 0) {
      healthScore -= 10;
    }

    if (sortino > 2.0) {
      healthScore += 10;
    } else if (sortino > 1.0) {
      healthScore += 5;
    }

    if (treynor != null && treynor > 0.15) {
      healthScore += 5; // Reward high excess return per unit of risk
    }

    if (omega != null && omega > 2.0) {
      healthScore += 5; // Excellent probability-weighted returns
    }

    // Market Performance (Max +20, Min -10)
    if (alpha > 0.05) {
      healthScore += 15;
    } else if (alpha > 0) {
      healthScore += 5;
    } else if (alpha < -0.05) {
      healthScore -= 5;
    }

    if (informationRatio != null) {
      if (informationRatio > 0.5) healthScore += 5;
      if (informationRatio < -0.5) healthScore -= 5;
    }

    // Risk Management (Max +20, Min -45)
    if (maxDrawdown < 0.10) {
      healthScore += 10;
    } else if (maxDrawdown > 0.30) {
      healthScore -= 20;
    } else if (maxDrawdown > 0.20) {
      healthScore -= 10;
    }

    if (volatility != null && benchmarkVolatility != null) {
      if (volatility < benchmarkVolatility) {
        healthScore += 5;
      } else if (volatility > benchmarkVolatility + 0.10) {
        healthScore -= 5;
      }
    }

    if (beta > 1.5 || beta < 0.5) {
      healthScore -= 5; // Penalize extreme beta
    }

    if (var95 != null) {
      if (var95 < -0.03) {
        healthScore -= 5; // High daily risk (>3%)
      }
      if (var95 < -0.05) {
        healthScore -= 5; // Very high daily risk (>5%)
      }
    }

    if (cvar95 != null && cvar95 < -0.07) {
      healthScore -= 5; // Extreme tail risk (>7% expected loss in worst 5%)
    }

    if (correlation != null) {
      if (correlation < 0.7 && correlation > 0) {
        healthScore += 5; // Good diversification benefit
      } else if (correlation > 0.95) {
        healthScore -= 5; // Too correlated with benchmark
      }
    }

    // Efficiency & Consistency (Max +25, Min -10)
    if (profitFactor != null) {
      if (profitFactor > 2.0) {
        healthScore += 10;
      } else if (profitFactor > 1.5) {
        healthScore += 7;
      } else if (profitFactor > 1.2) {
        healthScore += 4;
      } else if (profitFactor < 1.0) {
        healthScore -= 10;
      }
    }

    if (winRate != null) {
      if (winRate > 0.60) {
        healthScore += 10;
      } else if (winRate > 0.50) {
        healthScore += 5;
      } else if (winRate < 0.40) {
        healthScore -= 5;
      }
    }

    if (calmar != null) {
      if (calmar > 1.0) healthScore += 5;
    }

    if (payoffRatio != null) {
      if (payoffRatio > 2.0) {
        healthScore += 5;
      } else if (payoffRatio < 0.8) {
        healthScore -= 5;
      }
    }

    if (expectancy != null && expectancy > 0) {
      healthScore += 5;
    }

    if (maxLossStreak != null && maxLossStreak > 5) {
      healthScore -= 5;
    }

    // Advanced Risk & Edge (Max +15, Min -15)
    if (kellyCriterion != null) {
      if (kellyCriterion > 0.10) {
        healthScore += 5; // Strong edge
      } else if (kellyCriterion > 0) {
        healthScore += 2; // Positive edge
      } else {
        healthScore -= 5; // Negative edge
      }
    }

    if (ulcerIndex != null) {
      if (ulcerIndex < 0.05) {
        healthScore += 5; // Low stress
      } else if (ulcerIndex > 0.15) {
        healthScore -= 5; // High stress
      }
    }

    if (tailRatio != null) {
      if (tailRatio > 1.1) {
        healthScore += 5; // Good upside skew
      } else if (tailRatio < 0.9) {
        healthScore -= 5; // Bad downside skew
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
}
