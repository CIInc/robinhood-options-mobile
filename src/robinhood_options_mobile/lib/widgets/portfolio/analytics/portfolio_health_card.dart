import 'package:flutter/material.dart';

/// The health-score breakdown dialog.
///
/// Scoring mirrors `AnalyticsUtils.calculatePortfolioMetrics`, so the dialog
/// explains the same number the insights banner shows rather than deriving its
/// own.
class PortfolioHealthCard {
  const PortfolioHealthCard._();

  static void showDetails(BuildContext context, Map<String, dynamic> data) {
    // Calculate breakdown - now matches refined AnalyticsUtils scoring
    double riskAdjustedScore = 0;
    double marketPerformanceScore = 0;
    double riskManagementScore = 0;
    double efficiencyScore = 0;
    double advancedEdgeScore = 0;

    List<String> riskAdjustedDetails = [];
    List<String> marketPerformanceDetails = [];
    List<String> riskManagementDetails = [];
    List<String> efficiencyDetails = [];
    List<String> advancedEdgeDetails = [];

    // Risk-Adjusted Returns (matches AnalyticsUtils)
    if (data.containsKey('sharpe')) {
      double sharpe = data['sharpe']!;
      if (sharpe > 2.5) {
        riskAdjustedScore += 18;
        riskAdjustedDetails.add(
            'Sharpe: ${sharpe.toStringAsFixed(2)} (> 2.5 Exceptional) [+18]');
      } else if (sharpe > 2.0) {
        riskAdjustedScore += 15;
        riskAdjustedDetails.add(
            'Sharpe: ${sharpe.toStringAsFixed(2)} (> 2.0 Excellent) [+15]');
      } else if (sharpe > 1.5) {
        riskAdjustedScore += 12;
        riskAdjustedDetails.add(
            'Sharpe: ${sharpe.toStringAsFixed(2)} (> 1.5 Very Good) [+12]');
      } else if (sharpe > 1.0) {
        riskAdjustedScore += 9;
        riskAdjustedDetails
            .add('Sharpe: ${sharpe.toStringAsFixed(2)} (> 1.0 Good) [+9]');
      } else if (sharpe > 0.5) {
        riskAdjustedScore += 5;
        riskAdjustedDetails.add(
            'Sharpe: ${sharpe.toStringAsFixed(2)} (> 0.5 Acceptable) [+5]');
      } else if (sharpe > 0) {
        riskAdjustedScore += 2;
        riskAdjustedDetails.add(
            'Sharpe: ${sharpe.toStringAsFixed(2)} (> 0 Marginally Positive) [+2]');
      } else if (sharpe < -0.5) {
        riskAdjustedScore -= 10;
        riskAdjustedDetails.add(
            'Sharpe: ${sharpe.toStringAsFixed(2)} (< -0.5 Very Poor) [-10]');
      } else if (sharpe < 0) {
        riskAdjustedScore -= 5;
        riskAdjustedDetails
            .add('Sharpe: ${sharpe.toStringAsFixed(2)} (< 0 Negative) [-5]');
      }
    }
    if (data.containsKey('sortino')) {
      double sortino = data['sortino']!;
      if (sortino > 2.5) {
        riskAdjustedScore += 10;
        riskAdjustedDetails.add(
            'Sortino: ${sortino.toStringAsFixed(2)} (> 2.5 Exceptional) [+10]');
      } else if (sortino > 1.5) {
        riskAdjustedScore += 7;
        riskAdjustedDetails.add(
            'Sortino: ${sortino.toStringAsFixed(2)} (> 1.5 Very Good) [+7]');
      } else if (sortino > 0.75) {
        riskAdjustedScore += 4;
        riskAdjustedDetails.add(
            'Sortino: ${sortino.toStringAsFixed(2)} (> 0.75 Acceptable) [+4]');
      }
    }
    if (data.containsKey('treynor')) {
      double treynor = data['treynor']!;
      if (treynor > 0.20) {
        riskAdjustedScore += 4;
        riskAdjustedDetails.add(
            'Treynor: ${treynor.toStringAsFixed(2)} (> 0.20 Excellent) [+4]');
      } else if (treynor > 0.10) {
        riskAdjustedScore += 2;
        riskAdjustedDetails
            .add('Treynor: ${treynor.toStringAsFixed(2)} (> 0.10 Good) [+2]');
      }
    }
    if (data.containsKey('omega')) {
      double omega = data['omega']!;
      if (omega > 2.5) {
        riskAdjustedScore += 5;
        riskAdjustedDetails
            .add('Omega: ${omega.toStringAsFixed(2)} (> 2.5 Exceptional) [+5]');
      } else if (omega > 1.5) {
        riskAdjustedScore += 3;
        riskAdjustedDetails
            .add('Omega: ${omega.toStringAsFixed(2)} (> 1.5 Very Good) [+3]');
      } else if (omega < 1.0) {
        riskAdjustedScore -= 5;
        riskAdjustedDetails
            .add('Omega: ${omega.toStringAsFixed(2)} (< 1.0 More Losses) [-5]');
      }
    }

    // Market Performance (matches AnalyticsUtils)
    if (data.containsKey('alpha')) {
      double alpha = data['alpha']!;
      if (alpha > 0.10) {
        marketPerformanceScore += 15;
        marketPerformanceDetails.add(
            'Alpha: ${(alpha * 100).toStringAsFixed(1)}% (> 10% Beating Market) [+15]');
      } else if (alpha > 0.05) {
        marketPerformanceScore += 12;
        marketPerformanceDetails.add(
            'Alpha: ${(alpha * 100).toStringAsFixed(1)}% (> 5% Strong) [+12]');
      } else if (alpha > 0.02) {
        marketPerformanceScore += 8;
        marketPerformanceDetails.add(
            'Alpha: ${(alpha * 100).toStringAsFixed(1)}% (> 2% Good) [+8]');
      } else if (alpha > 0) {
        marketPerformanceScore += 4;
        marketPerformanceDetails.add(
            'Alpha: ${(alpha * 100).toStringAsFixed(1)}% (> 0% Positive) [+4]');
      } else if (alpha < -0.10) {
        marketPerformanceScore -= 10;
        marketPerformanceDetails.add(
            'Alpha: ${(alpha * 100).toStringAsFixed(1)}% (< -10% Significantly Under) [-10]');
      } else if (alpha < -0.05) {
        marketPerformanceScore -= 6;
        marketPerformanceDetails.add(
            'Alpha: ${(alpha * 100).toStringAsFixed(1)}% (< -5% Underperforming) [-6]');
      } else if (alpha < 0) {
        marketPerformanceScore -= 3;
        marketPerformanceDetails.add(
            'Alpha: ${(alpha * 100).toStringAsFixed(1)}% (< 0% Slightly Negative) [-3]');
      }
    }
    if (data.containsKey('informationRatio')) {
      double ir = data['informationRatio']!;
      if (ir > 0.75) {
        marketPerformanceScore += 5;
        marketPerformanceDetails.add(
            'Info Ratio: ${ir.toStringAsFixed(2)} (> 0.75 Very Consistent) [+5]');
      } else if (ir > 0.25) {
        marketPerformanceScore += 3;
        marketPerformanceDetails.add(
            'Info Ratio: ${ir.toStringAsFixed(2)} (> 0.25 Consistent) [+3]');
      } else if (ir < -0.5) {
        marketPerformanceScore -= 5;
        marketPerformanceDetails.add(
            'Info Ratio: ${ir.toStringAsFixed(2)} (< -0.5 Consistently Under) [-5]');
      } else if (ir < 0) {
        marketPerformanceScore -= 2;
        marketPerformanceDetails.add(
            'Info Ratio: ${ir.toStringAsFixed(2)} (< 0 Inconsistent) [-2]');
      }
    }

    // Risk Management (matches AnalyticsUtils refined scoring)
    if (data.containsKey('maxDrawdown')) {
      double mdd = data['maxDrawdown']!;
      if (mdd < 0.05) {
        riskManagementScore += 12;
        riskManagementDetails.add(
            'Max Drawdown: ${(mdd * 100).toStringAsFixed(1)}% (< 5% Exceptional) [+12]');
      } else if (mdd < 0.10) {
        riskManagementScore += 8;
        riskManagementDetails.add(
            'Max Drawdown: ${(mdd * 100).toStringAsFixed(1)}% (< 10% Excellent) [+8]');
      } else if (mdd < 0.15) {
        riskManagementScore += 4;
        riskManagementDetails.add(
            'Max Drawdown: ${(mdd * 100).toStringAsFixed(1)}% (< 15% Good) [+4]');
      } else if (mdd > 0.40) {
        riskManagementScore -= 25;
        riskManagementDetails.add(
            'Max Drawdown: ${(mdd * 100).toStringAsFixed(1)}% (> 40% Catastrophic) [-25]');
      } else if (mdd > 0.30) {
        riskManagementScore -= 15;
        riskManagementDetails.add(
            'Max Drawdown: ${(mdd * 100).toStringAsFixed(1)}% (> 30% Severe) [-15]');
      } else if (mdd > 0.20) {
        riskManagementScore -= 8;
        riskManagementDetails.add(
            'Max Drawdown: ${(mdd * 100).toStringAsFixed(1)}% (> 20% High) [-8]');
      }
    }
    if (data.containsKey('volatility') &&
        data.containsKey('benchmarkVolatility')) {
      double vol = data['volatility']!;
      double benchVol = data['benchmarkVolatility']!;
      double volRatio = vol / benchVol;
      if (volRatio < 0.8) {
        riskManagementScore += 6;
        riskManagementDetails.add(
            'Volatility: ${(vol * 100).toStringAsFixed(1)}% (< 80% of Benchmark) [+6]');
      } else if (volRatio < 1.0) {
        riskManagementScore += 3;
        riskManagementDetails.add(
            'Volatility: ${(vol * 100).toStringAsFixed(1)}% (< Benchmark) [+3]');
      } else if (volRatio > 1.5) {
        riskManagementScore -= 8;
        riskManagementDetails.add(
            'Volatility: ${(vol * 100).toStringAsFixed(1)}% (50% More Volatile) [-8]');
      } else if (volRatio > 1.25) {
        riskManagementScore -= 4;
        riskManagementDetails.add(
            'Volatility: ${(vol * 100).toStringAsFixed(1)}% (25% More Volatile) [-4]');
      }
    }
    if (data.containsKey('beta')) {
      double beta = data['beta']!;
      if (beta > 1.8) {
        riskManagementScore -= 6;
        riskManagementDetails.add(
            'Beta: ${beta.toStringAsFixed(2)} (> 1.8 Very Aggressive) [-6]');
      } else if (beta > 1.5) {
        riskManagementScore -= 3;
        riskManagementDetails
            .add('Beta: ${beta.toStringAsFixed(2)} (> 1.5 Aggressive) [-3]');
      } else if (beta < 0.3) {
        riskManagementScore -= 4;
        riskManagementDetails
            .add('Beta: ${beta.toStringAsFixed(2)} (< 0.3 Too Defensive) [-4]');
      }
    }
    if (data.containsKey('var95')) {
      double var95 = data['var95']!;
      // Mirror AnalyticsUtils: apply both penalties if both thresholds breached
      if (var95 < -0.04) {
        riskManagementScore -= 6;
        riskManagementDetails.add(
            'VaR (95%): ${(var95 * 100).toStringAsFixed(1)}% (< -4% High Daily Risk) [-6]');
      }
      if (var95 < -0.06) {
        riskManagementScore -= 6;
        riskManagementDetails.add(
            'VaR (95%): ${(var95 * 100).toStringAsFixed(1)}% (< -6% Extreme Daily Risk) [-6]');
      }
    }
    if (data.containsKey('cvar95')) {
      double cvar95 = data['cvar95']!;
      if (cvar95 < -0.10) {
        riskManagementScore -= 8;
        riskManagementDetails.add(
            'CVaR (95%): ${(cvar95 * 100).toStringAsFixed(1)}% (< -10% Extreme Tail Risk) [-8]');
      } else if (cvar95 < -0.07) {
        riskManagementScore -= 4;
        riskManagementDetails.add(
            'CVaR (95%): ${(cvar95 * 100).toStringAsFixed(1)}% (< -7% High Tail Risk) [-4]');
      }
    }
    if (data.containsKey('correlation')) {
      double correlation = data['correlation']!;
      if (correlation > 0 && correlation < 0.6) {
        riskManagementScore += 6;
        riskManagementDetails.add(
            'Correlation: ${correlation.toStringAsFixed(2)} (< 0.6 Excellent Diversification) [+6]');
      } else if (correlation < 0.8) {
        riskManagementScore += 3;
        riskManagementDetails.add(
            'Correlation: ${correlation.toStringAsFixed(2)} (< 0.8 Good Diversification) [+3]');
      } else if (correlation > 0.98) {
        riskManagementScore -= 4;
        riskManagementDetails.add(
            'Correlation: ${correlation.toStringAsFixed(2)} (> 0.98 Tracking Index) [-4]');
      }
    }

    // Efficiency & Consistency (matches AnalyticsUtils refined scoring)
    if (data.containsKey('profitFactor')) {
      double pf = data['profitFactor']!;
      if (pf > 3.0) {
        efficiencyScore += 12;
        efficiencyDetails.add(
            'Profit Factor: ${pf.toStringAsFixed(2)} (> 3.0 Exceptional 3:1) [+12]');
      } else if (pf > 2.0) {
        efficiencyScore += 9;
        efficiencyDetails.add(
            'Profit Factor: ${pf.toStringAsFixed(2)} (> 2.0 Excellent 2:1) [+9]');
      } else if (pf > 1.5) {
        efficiencyScore += 6;
        efficiencyDetails.add(
            'Profit Factor: ${pf.toStringAsFixed(2)} (> 1.5 Very Good 1.5:1) [+6]');
      } else if (pf > 1.2) {
        efficiencyScore += 3;
        efficiencyDetails
            .add('Profit Factor: ${pf.toStringAsFixed(2)} (> 1.2 Good) [+3]');
      } else if (pf < 0.9) {
        efficiencyScore -= 12;
        efficiencyDetails.add(
            'Profit Factor: ${pf.toStringAsFixed(2)} (< 0.9 Losing Money) [-12]');
      } else if (pf < 1.0) {
        efficiencyScore -= 6;
        efficiencyDetails.add(
            'Profit Factor: ${pf.toStringAsFixed(2)} (< 1.0 Break-even/Loss) [-6]');
      }
    }
    if (data.containsKey('winRate')) {
      double wr = data['winRate']!;
      if (wr > 0.65) {
        efficiencyScore += 8;
        efficiencyDetails.add(
            'Win Rate: ${(wr * 100).toStringAsFixed(0)}% (> 65% Very Consistent) [+8]');
      } else if (wr > 0.55) {
        efficiencyScore += 5;
        efficiencyDetails.add(
            'Win Rate: ${(wr * 100).toStringAsFixed(0)}% (> 55% Consistent) [+5]');
      } else if (wr > 0.50) {
        efficiencyScore += 2;
        efficiencyDetails.add(
            'Win Rate: ${(wr * 100).toStringAsFixed(0)}% (> 50% Above Average) [+2]');
      } else if (wr < 0.35) {
        efficiencyScore -= 6;
        efficiencyDetails.add(
            'Win Rate: ${(wr * 100).toStringAsFixed(0)}% (< 35% Very Inconsistent) [-6]');
      } else if (wr < 0.45) {
        efficiencyScore -= 3;
        efficiencyDetails.add(
            'Win Rate: ${(wr * 100).toStringAsFixed(0)}% (< 45% Below Average) [-3]');
      }
    }
    if (data.containsKey('calmar')) {
      double calmar = data['calmar']!;
      if (calmar > 2.0) {
        efficiencyScore += 6;
        efficiencyDetails.add(
            'Calmar: ${calmar.toStringAsFixed(2)} (> 2.0 Exceptional) [+6]');
      } else if (calmar > 1.0) {
        efficiencyScore += 3;
        efficiencyDetails
            .add('Calmar: ${calmar.toStringAsFixed(2)} (> 1.0 Good) [+3]');
      } else if (calmar < 0) {
        efficiencyScore -= 3;
        efficiencyDetails.add(
            'Calmar: ${calmar.toStringAsFixed(2)} (< 0 Negative Returns) [-3]');
      }
    }
    if (data.containsKey('payoffRatio')) {
      double payoff = data['payoffRatio']!;
      if (payoff > 2.5) {
        efficiencyScore += 5;
        efficiencyDetails.add(
            'Payoff Ratio: ${payoff.toStringAsFixed(2)} (> 2.5 Excellent Asymmetry) [+5]');
      } else if (payoff > 1.5) {
        efficiencyScore += 3;
        efficiencyDetails.add(
            'Payoff Ratio: ${payoff.toStringAsFixed(2)} (> 1.5 Good) [+3]');
      } else if (payoff < 0.7) {
        efficiencyScore -= 4;
        efficiencyDetails.add(
            'Payoff Ratio: ${payoff.toStringAsFixed(2)} (< 0.7 Losses > Wins) [-4]');
      }
    }
    if (data.containsKey('expectancy')) {
      double exp = data['expectancy']!;
      if (exp > 0) {
        efficiencyScore += 4;
        efficiencyDetails.add(
            'Expectancy: \$${exp.toStringAsFixed(2)} (> 0 Positive Edge) [+4]');
      } else {
        efficiencyScore -= 4;
        efficiencyDetails
            .add('Expectancy: \$${exp.toStringAsFixed(2)} (≤ 0 No Edge) [-4]');
      }
    }
    if (data.containsKey('maxLossStreak')) {
      int streak = data['maxLossStreak']!;
      if (streak > 7) {
        efficiencyScore -= 5;
        efficiencyDetails.add('Max Loss Streak: $streak (> 7 Concerning) [-5]');
      } else if (streak > 5) {
        efficiencyScore -= 2;
        efficiencyDetails.add('Max Loss Streak: $streak (> 5) [-2]');
      }
    }

    // Advanced Risk & Edge (matches AnalyticsUtils refined scoring)
    if (data.containsKey('kellyCriterion')) {
      double kelly = data['kellyCriterion']!;
      if (kelly > 0.15) {
        advancedEdgeScore += 6;
        advancedEdgeDetails.add(
            'Kelly Criterion: ${(kelly * 100).toStringAsFixed(1)}% (> 15% Very Strong Edge) [+6]');
      } else if (kelly > 0.08) {
        advancedEdgeScore += 4;
        advancedEdgeDetails.add(
            'Kelly Criterion: ${(kelly * 100).toStringAsFixed(1)}% (> 8% Strong Edge) [+4]');
      } else if (kelly > 0) {
        advancedEdgeScore += 2;
        advancedEdgeDetails.add(
            'Kelly Criterion: ${(kelly * 100).toStringAsFixed(1)}% (> 0% Positive Edge) [+2]');
      } else if (kelly < -0.05) {
        advancedEdgeScore -= 6;
        advancedEdgeDetails.add(
            'Kelly Criterion: ${(kelly * 100).toStringAsFixed(1)}% (< -5% Negative Edge) [-6]');
      }
    }
    if (data.containsKey('ulcerIndex')) {
      double ui = data['ulcerIndex']!;
      if (ui < 0.03) {
        advancedEdgeScore += 4;
        advancedEdgeDetails.add(
            'Ulcer Index: ${(ui * 100).toStringAsFixed(1)}% (< 3% Very Low Stress) [+4]');
      } else if (ui < 0.08) {
        advancedEdgeScore += 2;
        advancedEdgeDetails.add(
            'Ulcer Index: ${(ui * 100).toStringAsFixed(1)}% (< 8% Low Stress) [+2]');
      } else if (ui > 0.20) {
        advancedEdgeScore -= 6;
        advancedEdgeDetails.add(
            'Ulcer Index: ${(ui * 100).toStringAsFixed(1)}% (> 20% High Stress) [-6]');
      } else if (ui > 0.15) {
        advancedEdgeScore -= 3;
        advancedEdgeDetails.add(
            'Ulcer Index: ${(ui * 100).toStringAsFixed(1)}% (> 15% Moderate Stress) [-3]');
      }
    }
    if (data.containsKey('tailRatio')) {
      double tr = data['tailRatio']!;
      if (tr > 1.3) {
        advancedEdgeScore += 5;
        advancedEdgeDetails.add(
            'Tail Ratio: ${tr.toStringAsFixed(2)} (> 1.3 Strong Positive Skew) [+5]');
      } else if (tr > 1.0) {
        advancedEdgeScore += 2;
        advancedEdgeDetails.add(
            'Tail Ratio: ${tr.toStringAsFixed(2)} (> 1.0 Positive Skew) [+2]');
      } else if (tr < 0.7) {
        advancedEdgeScore -= 6;
        advancedEdgeDetails.add(
            'Tail Ratio: ${tr.toStringAsFixed(2)} (< 0.7 Negative Skew) [-6]');
      } else if (tr < 0.9) {
        advancedEdgeScore -= 3;
        advancedEdgeDetails.add(
            'Tail Ratio: ${tr.toStringAsFixed(2)} (< 0.9 Slightly Negative) [-3]');
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Health Score Breakdown',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'The Portfolio Health Score starts at a base of 50 and is adjusted based on your portfolio metrics across five key dimensions:',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _detailItem(
                    context,
                    Icons.trending_up,
                    Colors.blue,
                    'Risk-Adjusted Returns',
                    'Rewards high Sharpe, Sortino, and Omega ratios. Measures return efficiency per unit of risk taken. (Max +35/-15)',
                    riskAdjustedScore,
                    riskAdjustedDetails,
                  ),
                  _detailItem(
                    context,
                    Icons.compare_arrows,
                    Colors.purple,
                    'Market Performance',
                    'Rewards positive Alpha and Information Ratio. Shows consistent outperformance vs benchmark. (Max +20/-15)',
                    marketPerformanceScore,
                    marketPerformanceDetails,
                  ),
                  _detailItem(
                    context,
                    Icons.shield,
                    Colors.orange,
                    'Risk Management',
                    'Evaluates drawdowns, volatility, Beta, VaR/CVaR tail risk, and diversification benefit. (Max +20/-40)',
                    riskManagementScore,
                    riskManagementDetails,
                  ),
                  _detailItem(
                    context,
                    Icons.check_circle_outline,
                    Colors.green,
                    'Efficiency & Consistency',
                    'Rewards Profit Factor, Win Rate, Calmar, and positive expectancy. Measures strategy sustainability. (Max +30/-15)',
                    efficiencyScore,
                    efficiencyDetails,
                  ),
                  _detailItem(
                    context,
                    Icons.psychology_rounded,
                    Colors.teal,
                    'Advanced Risk & Edge',
                    'Evaluates optimal position sizing (Kelly), stress (Ulcer Index), and return asymmetry (Tail Ratio). (Max +15/-15)',
                    advancedEdgeScore,
                    advancedEdgeDetails,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Calculation Summary:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Base Score',
                                style: TextStyle(fontSize: 15)),
                            const Text('50', style: TextStyle(fontSize: 15)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Adjustments',
                                style: TextStyle(fontSize: 15)),
                            Text(
                              (riskAdjustedScore +
                                      marketPerformanceScore +
                                      riskManagementScore +
                                      efficiencyScore +
                                      advancedEdgeScore)
                                  .toStringAsFixed(0),
                              style: TextStyle(
                                color: (riskAdjustedScore +
                                            marketPerformanceScore +
                                            riskManagementScore +
                                            efficiencyScore +
                                            advancedEdgeScore) >=
                                        0
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Score',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              data.containsKey('healthScore')
                                  ? data['healthScore'].toStringAsFixed(0)
                                  : (50 +
                                          riskAdjustedScore +
                                          marketPerformanceScore +
                                          riskManagementScore +
                                          efficiencyScore +
                                          advancedEdgeScore)
                                      .clamp(0, 100)
                                      .toStringAsFixed(0),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static Widget _detailItem(BuildContext context, IconData icon, Color color,
      String title, String description, double scoreAdjustment,
      [List<String>? details]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      scoreAdjustment > 0
                          ? '+${scoreAdjustment.toStringAsFixed(0)}'
                          : scoreAdjustment.toStringAsFixed(0),
                      style: TextStyle(
                        color: scoreAdjustment > 0
                            ? Colors.green
                            : (scoreAdjustment < 0 ? Colors.red : Colors.grey),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                if (details != null && details.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...details.map((detail) => Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Row(
                          children: [
                            Icon(Icons.arrow_right,
                                size: 16,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                detail,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontFamily: 'RobotoMono',
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String grade(double score) {
    if (score >= 90) return 'A+';
    if (score >= 85) return 'A';
    if (score >= 80) return 'A-';
    if (score >= 75) return 'B+';
    if (score >= 70) return 'B';
    if (score >= 65) return 'B-';
    if (score >= 60) return 'C+';
    if (score >= 55) return 'C';
    if (score >= 50) return 'C-';
    if (score >= 45) return 'D+';
    if (score >= 40) return 'D';
    if (score >= 35) return 'D-';
    return 'F';
  }

  static String label(double score) {
    if (score >= 90) return 'Outstanding';
    if (score >= 80) return 'Excellent';
    if (score >= 70) return 'Very Good';
    if (score >= 60) return 'Good';
    if (score >= 50) return 'Fair';
    if (score >= 40) return 'Below Average';
    if (score >= 30) return 'Poor';
    return 'Critical';
  }
}
