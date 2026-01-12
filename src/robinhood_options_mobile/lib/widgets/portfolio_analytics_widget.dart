import 'dart:math';

import 'package:collection/collection.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals_store.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/model/esg_score.dart';
import 'package:robinhood_options_mobile/services/esg_service.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/tax_optimization_service.dart';
import 'package:robinhood_options_mobile/utils/analytics_utils.dart';
import 'package:robinhood_options_mobile/widgets/risk_heatmap_widget.dart';
import 'package:robinhood_options_mobile/widgets/tax_optimization_widget.dart';

class PortfolioAnalyticsWidget extends StatefulWidget {
  final BrokerageUser user;
  final IBrokerageService service;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final GenerativeService generativeService;
  final User? appUser;
  final DocumentReference<User>? userDocRef;
  final Future<PortfolioHistoricals>? portfolioHistoricalsFuture;
  final Future<dynamic>? futureMarketIndexHistoricalsSp500;
  final Future<dynamic>? futureMarketIndexHistoricalsNasdaq;
  final Future<dynamic>? futureMarketIndexHistoricalsDow;
  final Future<dynamic>? futureMarketIndexHistoricalsRussell2000;

  const PortfolioAnalyticsWidget(
      {super.key,
      required this.user,
      required this.service,
      required this.analytics,
      required this.observer,
      required this.generativeService,
      required this.appUser,
      required this.userDocRef,
      this.portfolioHistoricalsFuture,
      this.futureMarketIndexHistoricalsSp500,
      this.futureMarketIndexHistoricalsNasdaq,
      this.futureMarketIndexHistoricalsDow,
      this.futureMarketIndexHistoricalsRussell2000});

  @override
  State<PortfolioAnalyticsWidget> createState() =>
      _PortfolioAnalyticsWidgetState();
}

class _PortfolioAnalyticsWidgetState extends State<PortfolioAnalyticsWidget> {
  Future<Map<String, dynamic>>? _analyticsFuture;
  Future<Map<String, dynamic>>? _esgFuture;
  final ESGService _esgService = ESGService();
  String _selectedBenchmark = 'SPY'; // Default to SPY
  bool _showAllInsights = false;
  final List<String> _benchmarks = ['SPY', 'QQQ', 'DIA', 'IWM'];

  static const Map<String, String> definitions = {
    'Sharpe':
        'Risk-adjusted return metric. Shows how much excess return you earn per unit of risk.\n\n✓ >2.0: Excellent  ✓ >1.0: Good  ✗ <0: Negative returns',
    'Sortino':
        'Like Sharpe, but only penalizes downside volatility. Better for asymmetric strategies.\n\n✓ >2.0: Excellent  ✓ >1.0: Good  Focuses on downside risk only',
    'Treynor':
        'Excess return per unit of systematic risk (Beta). Best for diversified portfolios.\n\n✓ >0.15: Excellent  ✓ >0.05: Good  Higher = Better risk-adjusted returns',
    'Info Ratio':
        'Measures consistent outperformance vs. benchmark. Active management skill indicator.\n\n✓ >0.5: Good  ✓ >0: Positive  Negative = Underperforming inconsistently',
    'Calmar':
        'Annual return ÷ Max Drawdown. Shows return efficiency relative to worst-case loss.\n\n✓ >3.0: Exceptional  ✓ >0.5: Acceptable  Higher = Better recovery',
    'Omega':
        'Probability-weighted gains vs. losses ratio. Captures full return distribution.\n\n✓ >2.0: Excellent  ✓ >1.0: Profitable  Must be >1.0 to be positive',
    'Beta':
        'Market volatility multiplier. Shows portfolio sensitivity to market moves.\n\n⚡ >1.2: Aggressive  ⚖ 0.8-1.2: Balanced  🛡 <0.8: Defensive',
    'Alpha':
        'True outperformance beyond what Beta predicts. The holy grail of investing.\n\n✓ >5%: Excellent  ✓ >0%: Positive  ✗ <0%: Underperforming',
    'Excess Return':
        'Portfolio return minus benchmark return. Simple outperformance measure.\n\n✓ >0%: Outperforming  = 0%: Matching  ✗ <0%: Underperforming',
    'Max Drawdown':
        'Largest peak-to-trough loss. Your worst-case scenario experience.\n\n✓ <10%: Low risk  ⚠ <20%: Moderate  ✗ >30%: High risk - Review stops',
    'Volatility':
        'Annualized return swings (std dev). How bumpy the ride is.\n\n🎢 Higher = Wilder swings  🚂 Lower = Smoother ride  Compare to benchmark',
    'Correlation':
        'How closely you track the market. Diversification indicator.\n\n⚠ >0.9: High - Consider diversifying  ✓ 0.5-0.8: Moderate  ⬇ <0: Inverse',
    'VaR (95%)':
        'Value at Risk: Max expected 1-day loss (95% confidence). Tail risk metric.\n\nExample: -2% = 5% chance of losing >2% in a day  ⚠ Watch for spikes',
    'CVaR (95%)':
        'Expected Shortfall: Average loss when VaR is breached. True tail risk.\n\n⚠ Shows "black swan" severity  Always worse than VaR  Critical for risk mgmt',
    'Profit Factor':
        'Gross Profits ÷ Gross Losses. The profitability multiplier.\n\n✓ >2.0: Highly profitable  ✓ >1.5: Good  ✓ >1.0: Profitable  ✗ <1.0: Losing',
    'Win Rate':
        'Percentage of winning days. Consistency indicator.\n\n✓ >65%: High consistency  ✓ >50%: Above average  ⚠ <40%: Low - Need high payoff',
    'Expectancy':
        'Average \$ per day/trade. Your mathematical edge.\n\n✓ >0: Positive edge  ✗ <0: Negative edge  Must be positive long-term',
    'Payoff Ratio':
        'Avg Win ÷ Avg Loss. Win/loss size comparison.\n\n✓ >2.0: Large winners  ✓ >1.0: Wins bigger than losses  ⚠ <1.0: Losses cut gains',
    'Kelly Criterion':
        'Optimal position size for max long-term growth. Risk management tool.\n\n✓ >0: Mathematical edge  Use 1/4 to 1/2 Kelly in practice  ⚠ Full Kelly = risky',
    'Ulcer Index':
        'Drawdown depth × duration. Emotional stress measure.\n\n✓ <5%: Low stress  ⚠ <10%: Moderate  ✗ >15%: High anxiety - Review strategy',
    'Tail Ratio':
        'Big gains vs. big losses ratio. Asymmetry indicator.\n\n✓ >1.0: Positive skew (good!)  = 1.0: Symmetric  ✗ <1.0: Negative skew (bad)',
    'Max Win Streak':
        'Longest consecutive winning days. Momentum & consistency indicator.\n\n🔥 Higher = Better  Signals favorable market conditions  Track for confidence',
    'Max Loss Streak':
        'Longest consecutive losing days. Resilience & risk control test.\n\n⚠ >5 days: Review strategy  Lower = Better risk mgmt  🛑 Consider stops',
  };

  static const Map<String, Map<String, dynamic>> metricGuidance = {
    'Sharpe': {
      'goodThreshold': 2.0,
      'acceptableThreshold': 1.0,
      'example':
          'A Sharpe of 2.5 means you earn 2.5% excess return for every 1% of risk taken.',
      'tip':
          'Diversification and position sizing can improve your Sharpe ratio.',
    },
    'Sortino': {
      'goodThreshold': 2.0,
      'acceptableThreshold': 1.0,
      'example':
          'Sortino of 3.0 means excellent returns with minimal downside volatility.',
      'tip':
          'Focus on reducing losses rather than limiting upside to improve Sortino.',
    },
    'Alpha': {
      'goodThreshold': 0.05,
      'acceptableThreshold': 0.0,
      'example':
          'Alpha of 5% means you outperformed the benchmark by 5% annually.',
      'tip': 'Positive alpha suggests skill or strategy beyond market returns.',
    },
    'Beta': {
      'goodThreshold': 0.8,
      'acceptableThreshold': 1.2,
      'example':
          'Beta of 1.5 means your portfolio moves 50% more than the market.',
      'tip': 'Lower beta = more defensive, higher beta = more aggressive.',
    },
    'Max Drawdown': {
      'goodThreshold': 0.10,
      'acceptableThreshold': 0.20,
      'example':
          'A 25% drawdown means your portfolio fell 25% from peak to trough.',
      'tip': 'Use stop-losses and position sizing to limit maximum drawdown.',
      'reverse': true,
    },
    'Win Rate': {
      'goodThreshold': 0.60,
      'acceptableThreshold': 0.50,
      'example':
          'Win rate of 65% means 65% of your trading days were profitable.',
      'tip': 'High win rate with low payoff ratio can still be profitable.',
    },
    'Profit Factor': {
      'goodThreshold': 1.5,
      'acceptableThreshold': 1.0,
      'example': 'Profit factor of 2.0 means you made \$2 for every \$1 lost.',
      'tip': 'Above 1.0 is profitable, above 1.5 is considered strong.',
    },
  };

  @override
  void initState() {
    super.initState();
    _analyticsFuture = _calculateAnalytics();
    _esgFuture = _calculateESG();
  }

  @override
  void didUpdateWidget(PortfolioAnalyticsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.portfolioHistoricalsFuture !=
        oldWidget.portfolioHistoricalsFuture) {
      setState(() {
        _analyticsFuture = _calculateAnalytics();
        _esgFuture = _calculateESG();
      });
    }
  }

  Future<Map<String, dynamic>> _calculateESG() async {
    if (!mounted) return {};
    // Wait for the widget to build so Provider is available
    await Future.delayed(Duration.zero);
    if (!mounted) return {};

    var instrumentPositionStore =
        Provider.of<InstrumentPositionStore>(context, listen: false);
    var positions = instrumentPositionStore.items;

    if (positions.isEmpty) return {};

    var symbols = positions
        .where((p) => p.instrumentObj != null)
        .map((p) => p.instrumentObj!.symbol)
        .toList();

    if (symbols.isEmpty) return {};

    var scores = await _esgService.getESGScores(symbols);

    // Calculate weighted average
    double totalWeightedScore = 0;
    double totalWeightedEnv = 0;
    double totalWeightedSoc = 0;
    double totalWeightedGov = 0;
    double totalValue = 0;

    for (var position in positions) {
      if (position.instrumentObj == null) continue;
      var symbol = position.instrumentObj!.symbol;
      var score = scores.firstWhereOrNull((s) => s.symbol == symbol);
      if (score == null) continue;

      double value = position.marketValue;

      totalWeightedScore += score.totalScore * value;
      totalWeightedEnv += score.environmentalScore * value;
      totalWeightedSoc += score.socialScore * value;
      totalWeightedGov += score.governanceScore * value;
      totalValue += value;
    }

    if (totalValue == 0) return {};

    return {
      'totalScore': totalWeightedScore / totalValue,
      'environmentalScore': totalWeightedEnv / totalValue,
      'socialScore': totalWeightedSoc / totalValue,
      'governanceScore': totalWeightedGov / totalValue,
      'scores': scores,
    };
  }

  Future<Map<String, dynamic>> _calculateAnalytics() async {
    PortfolioHistoricals? portfolioHistoricals;

    if (widget.portfolioHistoricalsFuture != null) {
      try {
        portfolioHistoricals = await widget.portfolioHistoricalsFuture;
      } catch (e) {
        debugPrint('Error awaiting portfolio historicals: $e');
      }
    }

    if (portfolioHistoricals == null) {
      // Fallback to store
      if (!mounted) return {};
      var portfolioStore =
          Provider.of<PortfolioHistoricalsStore>(context, listen: false);
      if (portfolioStore.items.isNotEmpty) {
        portfolioHistoricals = portfolioStore.items
            .firstWhereOrNull((item) => item.span == 'year');
        portfolioHistoricals ??= portfolioStore.items
            .firstWhereOrNull((item) => item.span == '5year');
        portfolioHistoricals ??= portfolioStore.items
            .firstWhereOrNull((item) => item.span == '3month');
        portfolioHistoricals ??= portfolioStore.items.first;
      }
    }

    if (portfolioHistoricals == null) return {};

    // 2. Fetch Benchmark Historicals
    if (!mounted) return {};

    List<double> benchmarkPrices = [];
    List<DateTime> benchmarkDates = [];

    // Try to use market indices if available and selected
    Future<dynamic>? selectedFuture;
    if (_selectedBenchmark == 'SPY') {
      selectedFuture = widget.futureMarketIndexHistoricalsSp500;
    } else if (_selectedBenchmark == 'QQQ') {
      selectedFuture = widget.futureMarketIndexHistoricalsNasdaq;
    } else if (_selectedBenchmark == 'DIA') {
      selectedFuture = widget.futureMarketIndexHistoricalsDow;
    } else if (_selectedBenchmark == 'IWM') {
      selectedFuture = widget.futureMarketIndexHistoricalsRussell2000;
    }

    if (selectedFuture != null) {
      try {
        var data = await selectedFuture;
        if (data != null) {
          var timestamps = (data['chart']['result'][0]['timestamp'] as List);
          var adjcloses = (data['chart']['result'][0]['indicators']['adjclose']
              [0]['adjclose'] as List);
          // var opens = (data['chart']['result'][0]['indicators']['quote'][0]
          //     ['open'] as List);

          for (int i = 0; i < timestamps.length; i++) {
            if (adjcloses[i] != null) {
              // if (i == 0) {
              //   benchmarkDates.add(
              //       DateTime.fromMillisecondsSinceEpoch(timestamps[i] * 1000)
              //           .add(Duration(days: -1)));
              //   benchmarkPrices.add((opens[i] as num).toDouble());
              // }
              benchmarkDates.add(
                  DateTime.fromMillisecondsSinceEpoch(timestamps[i] * 1000));
              benchmarkPrices.add((adjcloses[i] as num).toDouble());
            }
          }
        }
      } catch (e) {
        debugPrint('Error using $_selectedBenchmark index data: $e');
      }
    }

    // 3. Align dates and calculate metrics
    Map<String, double> benchmarkMap = {};
    for (int i = 0; i < benchmarkDates.length; i++) {
      String dateKey = benchmarkDates[i].toIso8601String().split('T')[0];
      benchmarkMap[dateKey] = benchmarkPrices[i];
    }

    List<double> alignedPortfolioPrices = [];
    List<double> alignedBenchmarkPrices = [];
    List<DateTime> alignedDates = [];

    for (var h in portfolioHistoricals.equityHistoricals) {
      if (h.beginsAt != null) {
        String dateKey = h.beginsAt!.toIso8601String().split('T')[0];
        if (benchmarkMap.containsKey(dateKey)) {
          alignedPortfolioPrices
              .add(h.adjustedCloseEquity ?? h.closeEquity ?? 0.0);
          alignedBenchmarkPrices.add(benchmarkMap[dateKey]!);
          alignedDates.add(h.beginsAt!);
        }
      }
    }

    // If we failed to align enough points, skip analytics
    if (alignedPortfolioPrices.length < 2 ||
        alignedBenchmarkPrices.length < 2) {
      return {};
    }

    List<double> portfolioReturns =
        AnalyticsUtils.calculateDailyReturns(alignedPortfolioPrices);
    List<double> benchmarkReturns =
        AnalyticsUtils.calculateDailyReturns(alignedBenchmarkPrices);
    List<double> activeReturns = [];
    for (int i = 0; i < portfolioReturns.length; i++) {
      activeReturns.add(portfolioReturns[i] - benchmarkReturns[i]);
    }

    double sharpe = AnalyticsUtils.calculateSharpeRatio(portfolioReturns);
    double beta =
        AnalyticsUtils.calculateBeta(portfolioReturns, benchmarkReturns);
    double correlation =
        AnalyticsUtils.calculateCorrelation(portfolioReturns, benchmarkReturns);
    double alpha =
        AnalyticsUtils.calculateAlpha(portfolioReturns, benchmarkReturns, beta);
    double maxDrawdown =
        AnalyticsUtils.calculateMaxDrawdown(alignedPortfolioPrices);
    double volatility = AnalyticsUtils.calculateVolatility(portfolioReturns);
    double benchmarkVolatility =
        AnalyticsUtils.calculateVolatility(benchmarkReturns);

    double portfolioCumulative =
        AnalyticsUtils.calculateCumulativeReturn(alignedPortfolioPrices);
    double benchmarkCumulative =
        AnalyticsUtils.calculateCumulativeReturn(alignedBenchmarkPrices);
    double excessReturn = portfolioCumulative - benchmarkCumulative;
    double trackingError = activeReturns.isNotEmpty
        ? AnalyticsUtils.calculateStdDev(activeReturns) * sqrt(252)
        : 0.0;
    double avgDailyReturn = AnalyticsUtils.calculateMean(portfolioReturns);
    double bestDay =
        portfolioReturns.isNotEmpty ? portfolioReturns.reduce(max) : 0.0;
    double worstDay =
        portfolioReturns.isNotEmpty ? portfolioReturns.reduce(min) : 0.0;

    double sortino = AnalyticsUtils.calculateSortinoRatio(portfolioReturns);
    double treynor =
        AnalyticsUtils.calculateTreynorRatio(portfolioReturns, beta);
    double informationRatio = AnalyticsUtils.calculateInformationRatio(
        portfolioReturns, benchmarkReturns);

    // Derive period length from aligned dates to match selected timeline
    int periodDays = 0;
    double periodYears = 1.0;
    if (alignedDates.isNotEmpty) {
      final start = alignedDates.first;
      final end = alignedDates.last;
      final days = end.difference(start).inDays.abs();
      periodDays = days > 0 ? days : 1;
      periodYears = periodDays / 365.0;
    }

    double calmar = AnalyticsUtils.calculateCalmarRatio(
        portfolioCumulative, maxDrawdown, periodYears);
    double omega = AnalyticsUtils.calculateOmegaRatio(portfolioReturns);
    double var95 = AnalyticsUtils.calculateVaR(portfolioReturns);
    double cvar95 = AnalyticsUtils.calculateCVaR(portfolioReturns);

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

    double profitFactor =
        AnalyticsUtils.calculateProfitFactor(grossProfit, grossLoss);
    double winRate =
        (winCount + lossCount) > 0 ? winCount / (winCount + lossCount) : 0.0;
    double avgWin = winCount > 0 ? totalWinAmt / winCount : 0.0;
    double avgLoss = lossCount > 0 ? totalLossAmt / lossCount : 0.0;
    double payoffRatio = avgLoss > 0 ? avgWin / avgLoss : 0.0;
    double expectancy = (avgWin * winRate) - (avgLoss * (1 - winRate));

    int maxWinStreak =
        AnalyticsUtils.calculateMaxWinningStreak(portfolioReturns);
    int maxLossStreak =
        AnalyticsUtils.calculateMaxLosingStreak(portfolioReturns);

    double kellyCriterion =
        AnalyticsUtils.calculateKellyCriterion(winRate, payoffRatio);
    double ulcerIndex =
        AnalyticsUtils.calculateUlcerIndex(alignedPortfolioPrices);
    double tailRatio = AnalyticsUtils.calculateTailRatio(portfolioReturns);

    // Calculate Health Score
    double healthScore = AnalyticsUtils.calculateHealthScore(
      sharpe: sharpe,
      sortino: sortino,
      alpha: alpha,
      maxDrawdown: maxDrawdown,
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
      'volatility': volatility,
      'benchmarkVolatility': benchmarkVolatility,
      'excessReturn': excessReturn,
      'trackingError': trackingError,
      'portfolioCumulative': portfolioCumulative,
      'benchmarkCumulative': benchmarkCumulative,
      'avgDailyReturn': avgDailyReturn,
      'bestDay': bestDay,
      'worstDay': worstDay,
      'periodDays': periodDays,
      'sortino': sortino,
      'treynor': treynor,
      'informationRatio': informationRatio,
      'calmar': calmar,
      'omega': omega,
      'var95': var95,
      'cvar95': cvar95,
      'healthScore': healthScore,
      'profitFactor': profitFactor,
      'winRate': winRate,
      'payoffRatio': payoffRatio,
      'expectancy': expectancy,
      'avgWin': avgWin,
      'avgLoss': avgLoss,
      'maxWinStreak': maxWinStreak,
      'maxLossStreak': maxLossStreak,
      'kellyCriterion': kellyCriterion,
      'ulcerIndex': ulcerIndex,
      'tailRatio': tailRatio,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _analyticsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return SizedBox(
            height: 200,
            child: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        var data = snapshot.data ?? {};
        if (data.isEmpty) {
          return const SizedBox(
            height: 200,
            child: Center(child: Text('No analytics data available.')),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 16),
            _buildPerformanceOverviewCard(context, data),
            const SizedBox(height: 16),
            _buildInsightsCard(context, data),
            const SizedBox(height: 16),
            _buildRiskAdjustedReturnCard(context, data),
            const SizedBox(height: 16),
            _buildMarketComparisonCard(context, data),
            const SizedBox(height: 16),
            _buildRiskCard(context, data),
            const SizedBox(height: 16),
            _buildAdvancedEdgeCard(context, data),
            const SizedBox(height: 16),
            _buildDailyStatsCard(context, data),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.5),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: const RiskHeatmapWidget(),
            ),
            const SizedBox(height: 16),
            _buildTaxOptimizationCard(context),
            const SizedBox(height: 16),
            _buildESGCard(context),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildPerformanceOverviewCard(
      BuildContext context, Map<String, dynamic> data) {
    if (!data.containsKey('portfolioCumulative')) {
      return const SizedBox.shrink();
    }

    final percentFormat = NumberFormat.decimalPercentPattern(decimalDigits: 1);
    String formatPercent(double value) {
      final formatted = percentFormat.format(value);
      if (value > 0 && !formatted.startsWith('+')) {
        return '+$formatted';
      }
      return formatted;
    }

    double portfolioReturn = data['portfolioCumulative'] ?? 0.0;
    double benchmarkReturn = data['benchmarkCumulative'] ?? 0.0;
    double excessReturn =
        data['excessReturn'] ?? portfolioReturn - benchmarkReturn;
    double avgDailyReturn = data['avgDailyReturn'] ?? 0.0;
    double bestDay = data['bestDay'] ?? 0.0;
    double worstDay = data['worstDay'] ?? 0.0;
    double trackingError = data['trackingError'] ?? 0.0;
    int periodDays = data['periodDays'] ?? 0;
    final trackingColor = trackingError > 0.12
        ? Colors.red
        : (trackingError > 0.08 ? Colors.orange : Colors.green);

    Color colorFor(double value) => value >= 0 ? Colors.green : Colors.red;

    final stats = [
      _buildSnapshotTile(
        context,
        icon: Icons.trending_up,
        label: 'Portfolio',
        value: formatPercent(portfolioReturn),
        valueColor: colorFor(portfolioReturn),
        footer: 'Cumulative return',
        tooltip: 'Cumulative return of your portfolio over the aligned window.',
      ),
      _buildSnapshotTile(
        context,
        icon: Icons.show_chart,
        label: 'Benchmark',
        value: formatPercent(benchmarkReturn),
        valueColor: colorFor(benchmarkReturn),
        footer: '$_selectedBenchmark performance',
        tooltip:
            'Cumulative return of the selected benchmark over the same window.',
      ),
      _buildSnapshotTile(
        context,
        icon: Icons.stacked_line_chart,
        label: 'Excess Return',
        value: formatPercent(excessReturn),
        valueColor: colorFor(excessReturn),
        footer: 'vs $_selectedBenchmark',
        tooltip:
            'Portfolio cumulative return minus benchmark cumulative return.',
      ),
      _buildSnapshotTile(
        context,
        icon: Icons.calendar_today_outlined,
        label: 'Avg Daily',
        value: formatPercent(avgDailyReturn),
        valueColor: colorFor(avgDailyReturn),
        footer: 'Mean daily move',
        tooltip: 'Mean of daily returns for your portfolio during the window.',
      ),
      _buildSnapshotTile(
        context,
        icon: Icons.arrow_upward,
        label: 'Best Day',
        value: formatPercent(bestDay),
        valueColor: colorFor(bestDay),
        footer: 'Single-day peak',
        tooltip: 'Highest single-day return observed in the period.',
      ),
      _buildSnapshotTile(
        context,
        icon: Icons.arrow_downward,
        label: 'Worst Day',
        value: formatPercent(worstDay),
        valueColor: colorFor(worstDay),
        footer: 'Single-day trough',
        tooltip: 'Lowest single-day return observed in the period.',
      ),
      _buildSnapshotTile(
        context,
        icon: Icons.science_outlined,
        label: 'Tracking Error',
        value: formatPercent(trackingError),
        valueColor: trackingColor,
        footer: 'Active risk (ann.)',
        tooltip:
            'Annualized std dev of active returns (portfolio − benchmark).',
      ),
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Performance Snapshot',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                if (periodDays > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${periodDays}d window',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                // const SizedBox(width: 8),
                // Container(
                //   padding:
                //       const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                //   decoration: BoxDecoration(
                //     color: Theme.of(context)
                //         .colorScheme
                //         .primaryContainer
                //         .withValues(alpha: 0.3),
                //     borderRadius: BorderRadius.circular(20),
                //   ),
                //   child: Row(
                //     mainAxisSize: MainAxisSize.min,
                //     children: [
                //       const Icon(Icons.flag, size: 14),
                //       const SizedBox(width: 6),
                //       Text(
                //         _selectedBenchmark,
                //         style: TextStyle(
                //           fontWeight: FontWeight.bold,
                //           color:
                //               Theme.of(context).colorScheme.onPrimaryContainer,
                //         ),
                //       ),
                //     ],
                //   ),
                // ),
              ],
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                double itemWidth;
                if (constraints.maxWidth < 360) {
                  itemWidth = (constraints.maxWidth - 8) / 2;
                } else if (constraints.maxWidth > 680) {
                  itemWidth = (constraints.maxWidth - 24) / 3;
                } else {
                  itemWidth = (constraints.maxWidth - 16) / 2;
                }

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: stats
                      .map((widget) => SizedBox(
                            width: itemWidth,
                            child: widget,
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceSnapshotInfoSection(BuildContext context) {
    final neutral = Theme.of(context)
        .colorScheme
        .surfaceContainerHighest
        .withValues(alpha: 0.3);
    final borderColor =
        Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3);

    Widget buildItem(IconData icon, String title, String description) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: neutral,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon,
                  size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.flag,
                size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'What the Snapshot Shows',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        buildItem(
          Icons.trending_up,
          'Portfolio (Cumulative Return)',
          'Total return over the selected window, based on aligned portfolio equity. Positive values indicate growth; negative values indicate decline.',
        ),
        buildItem(
          Icons.show_chart,
          'Benchmark (Cumulative Return)',
          'Total return of the selected benchmark (SPY/QQQ/DIA/IWM) over the same aligned window.',
        ),
        buildItem(
          Icons.stacked_line_chart,
          'Excess Return',
          'Difference between portfolio and benchmark cumulative returns. Positive means outperformance; negative means underperformance.',
        ),
        buildItem(
          Icons.calendar_today_outlined,
          'Average Daily Return',
          'Mean of daily returns for your portfolio during the window. Gives a sense of typical day-to-day movement.',
        ),
        buildItem(
          Icons.arrow_upward,
          'Best Day',
          'Highest single-day return observed in the period.',
        ),
        buildItem(
          Icons.arrow_downward,
          'Worst Day',
          'Lowest single-day return observed in the period.',
        ),
        buildItem(
          Icons.science_outlined,
          'Tracking Error (Annualized)',
          'Standard deviation of active returns (portfolio minus benchmark), annualized using √252. Measures consistency vs. benchmark (lower is closer tracking).',
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.info_outline,
                size: 16, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'All metrics are computed on date-aligned series. The window label shows the number of calendar days between first and last aligned points.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInsightsCard(BuildContext context, Map<String, dynamic> data) {
    List<Widget> insights = [];
    List<Widget> highPriority = [];
    List<Widget> mediumPriority = [];
    List<Widget> lowPriority = [];
    List<Widget> otherPriority = [];

    void addInsight(IconData icon, Color color, String text) {
      Widget widget = _buildInsightRow(context, icon, color, text);
      if (color == Colors.red) {
        highPriority.add(widget);
      } else if (color == Colors.orange) {
        mediumPriority.add(widget);
      } else if (color == Colors.green) {
        lowPriority.add(widget);
      } else {
        otherPriority.add(widget);
      }
    }

    if (data.containsKey('healthScore')) {
      double score = data['healthScore'];
      Color scoreColor = score >= 80
          ? Colors.green
          : (score >= 50 ? Colors.orange : Colors.red);

      insights.add(Container(
        padding: const EdgeInsets.all(16.0),
        margin: const EdgeInsets.only(bottom: 16.0),
        decoration: BoxDecoration(
          color: scoreColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scoreColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 70,
                  height: 70,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 8,
                    backgroundColor: scoreColor.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                  ),
                ),
                Text(
                  score.toStringAsFixed(0),
                  style: TextStyle(
                    color: scoreColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Portfolio Health Score',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _showHealthScoreDetails(context, data),
                        child: Icon(Icons.info_outline,
                            size: 18, color: scoreColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        _getHealthScoreGrade(score),
                        style: TextStyle(
                          color: scoreColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '•',
                        style: TextStyle(
                          color: scoreColor.withValues(alpha: 0.5),
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getHealthScoreLabel(score),
                        style: TextStyle(
                          color: scoreColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ));
    }

    if (data.containsKey('sharpe')) {
      double sharpe = data['sharpe']!;
      if (sharpe > 2.5) {
        addInsight(Icons.star, Colors.green,
            'Outstanding risk-adjusted returns (Sharpe ${sharpe.toStringAsFixed(2)}). Maintain this disciplined approach.');
      } else if (sharpe > 1.5) {
        addInsight(Icons.check_circle, Colors.green,
            'Excellent risk-adjusted returns (Sharpe ${sharpe.toStringAsFixed(2)}). You\'re efficiently using capital.');
      } else if (sharpe > 0.75) {
        addInsight(Icons.info_outline, Colors.blue,
            'Good risk-adjusted returns (Sharpe ${sharpe.toStringAsFixed(2)}). Consider tightening stops to reduce volatility.');
      } else if (sharpe > 0) {
        addInsight(Icons.info_outline, Colors.orange,
            'Moderate risk-adjusted returns (Sharpe ${sharpe.toStringAsFixed(2)}). Focus on reducing volatility or increasing returns.');
      } else {
        addInsight(Icons.warning, Colors.red,
            'Negative risk-adjusted returns (Sharpe ${sharpe.toStringAsFixed(2)}). Review strategy fundamentals.');
      }
    }

    if (data.containsKey('profitFactor')) {
      double pf = data['profitFactor']!;
      if (pf > 2.5) {
        addInsight(Icons.trending_up, Colors.green,
            'Exceptional profit efficiency (PF ${pf.toStringAsFixed(2)}). Winning trades far exceed losses.');
      } else if (pf > 1.5) {
        addInsight(Icons.attach_money, Colors.green,
            'Strong profitability (PF ${pf.toStringAsFixed(2)}). Strategy is working well.');
      } else if (pf < 1.0) {
        addInsight(Icons.money_off, Colors.red,
            'Strategy is losing money (PF ${pf.toStringAsFixed(2)}). Losses exceed wins - urgent review needed.');
      } else if (pf < 1.3) {
        addInsight(Icons.warning_amber, Colors.orange,
            'Marginal profitability (PF ${pf.toStringAsFixed(2)}). Improve win rate or cut losses faster.');
      }
    }

    if (data.containsKey('winRate')) {
      double wr = data['winRate']!;
      if (wr > 0.65) {
        addInsight(Icons.check, Colors.green,
            'Very consistent performance (${(wr * 100).toStringAsFixed(0)}% win rate).');
      } else if (wr < 0.40) {
        addInsight(Icons.priority_high, Colors.orange,
            'Low win rate (${(wr * 100).toStringAsFixed(0)}%). Ensure your average winners are significantly larger than losers.');
      }
    }

    if (data.containsKey('maxDrawdown')) {
      double mdd = data['maxDrawdown']!;
      if (mdd > 0.30) {
        addInsight(Icons.emergency, Colors.red,
            'Severe drawdown alert (${(mdd * 100).toStringAsFixed(1)}%)! Implement strict position sizing and risk management immediately.');
      } else if (mdd > 0.20) {
        addInsight(Icons.warning_amber, Colors.red,
            'High drawdown (${(mdd * 100).toStringAsFixed(1)}%). Review stop-loss strategies and reduce position sizes.');
      } else if (mdd < 0.10) {
        addInsight(Icons.security, Colors.green,
            'Excellent risk control - max drawdown only ${(mdd * 100).toStringAsFixed(1)}%.');
      }
    }

    if (data.containsKey('alpha') && data.containsKey('beta')) {
      double alpha = data['alpha']!;
      String alphaFixed = (alpha * 100).abs().toStringAsFixed(1);

      if (alpha > 0.05) {
        addInsight(Icons.trending_up, Colors.green,
            'Strong outperformance: +$alphaFixed% alpha vs benchmark. You\'re adding real value.');
      } else if (alpha > 0) {
        addInsight(Icons.compare_arrows, Colors.blue,
            'Modest outperformance: +$alphaFixed% alpha. Stay disciplined.');
      } else if (alpha < -0.05) {
        addInsight(Icons.trending_down, Colors.red,
            'Significant underperformance: -$alphaFixed% alpha. Consider index ETFs or strategy revision.');
      } else if (alpha < 0) {
        addInsight(Icons.compare_arrows, Colors.orange,
            'Slight underperformance: -$alphaFixed% alpha. Monitor closely.');
      } else {
        addInsight(Icons.compare_arrows, Colors.grey,
            'Matching benchmark performance (0% alpha).');
      }
    }

    if (data.containsKey('beta')) {
      double beta = data['beta']!;
      if (beta > 1.5) {
        addInsight(Icons.bolt, Colors.orange,
            'Very aggressive portfolio (Beta ${beta.toStringAsFixed(2)}). Amplifies market moves by ${((beta - 1) * 100).toStringAsFixed(0)}%. Add bonds or defensive stocks.');
      } else if (beta > 1.2) {
        addInsight(Icons.speed, Colors.orange,
            'Aggressive positioning (Beta ${beta.toStringAsFixed(2)}). Consider hedging during volatile periods.');
      } else if (beta < 0.5 && beta > 0) {
        addInsight(Icons.shield, Colors.blue,
            'Very defensive (Beta ${beta.toStringAsFixed(2)}). Consider adding growth exposure for higher returns.');
      } else if (beta < 0) {
        addInsight(Icons.shield_moon, Colors.blue,
            'Inverse market correlation (Beta ${beta.toStringAsFixed(2)}). Useful hedge but limits upside.');
      }
    }

    if (data.containsKey('correlation')) {
      double correlation = data['correlation']!;
      if (correlation > 0.95) {
        addInsight(Icons.link, Colors.orange,
            'Essentially tracking the index (${(correlation * 100).toStringAsFixed(0)}% correlation). Consider active strategies or just buy SPY.');
      } else if (correlation > 0 && correlation < 0.6) {
        addInsight(Icons.link_off, Colors.green,
            'Excellent diversification (${(correlation * 100).toStringAsFixed(0)}% correlation). Portfolio has unique return drivers.');
      } else if (correlation < 0) {
        addInsight(Icons.compare_arrows, Colors.blue,
            'Negative correlation (${(correlation * 100).toStringAsFixed(0)}%). Acts as market hedge.');
      }
    }

    if (data.containsKey('volatility') &&
        data.containsKey('benchmarkVolatility')) {
      double volRatio = data['volatility']! / data['benchmarkVolatility']!;
      if (volRatio > 1.5) {
        addInsight(Icons.waves, Colors.red,
            '50%+ more volatile than market. High risk - ensure you can handle the swings or reduce leverage.');
      } else if (volRatio < 0.8) {
        addInsight(Icons.water, Colors.green,
            'Lower volatility than market. Smoother ride with 20% less price swings.');
      }
    }

    if (data.containsKey('kellyCriterion')) {
      double kelly = data['kellyCriterion']!;
      if (kelly > 0.10) {
        addInsight(Icons.psychology_rounded, Colors.green,
            'Strong mathematical edge (${(kelly * 100).toStringAsFixed(1)}% Kelly). You can size positions confidently.');
      } else if (kelly < 0) {
        addInsight(Icons.dangerous, Colors.red,
            'Negative Kelly suggests no statistical edge. Trading costs may be eating profits.');
      }
    }

    if (data.containsKey('tailRatio')) {
      double tr = data['tailRatio']!;
      if (tr > 1.2) {
        addInsight(Icons.show_chart, Colors.green,
            'Positive skew (Tail Ratio ${tr.toStringAsFixed(2)}). Big wins outnumber big losses - ideal asymmetry.');
      } else if (tr < 0.8) {
        addInsight(Icons.show_chart, Colors.red,
            'Negative skew (Tail Ratio ${tr.toStringAsFixed(2)}). Losing tails hurt more than winning tails help. Use tight stops.');
      }
    }

    if (data.containsKey('var95')) {
      double var95 = data['var95']!;
      if (var95 < -0.04) {
        addInsight(Icons.warning, Colors.red,
            'High Value at Risk (VaR 95%: ${(var95 * 100).toStringAsFixed(1)}%). Potential for significant daily losses.');
      }
    }

    insights.addAll(highPriority);
    insights.addAll(mediumPriority);
    insights.addAll(lowPriority);
    insights.addAll(otherPriority);

    if (insights.isEmpty) return const SizedBox.shrink();

    final displayedInsights =
        _showAllInsights ? insights : insights.take(3).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Text('Portfolio Insights',
                    style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 20),
            ...displayedInsights,
            if (insights.length > 3) ...[
              const SizedBox(height: 10),
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showAllInsights = !_showAllInsights;
                    });
                  },
                  icon: Icon(
                      _showAllInsights ? Icons.expand_less : Icons.expand_more),
                  label: Text(_showAllInsights ? 'Show Less' : 'Show More'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTaxOptimizationCard(BuildContext context) {
    final instrumentPositionStore =
        Provider.of<InstrumentPositionStore>(context);
    final optionPositionStore = Provider.of<OptionPositionStore>(context);

    final suggestions =
        TaxOptimizationService.calculateTaxHarvestingOpportunities(
      instrumentPositions: instrumentPositionStore.items,
      optionPositions: optionPositionStore.items,
    );

    final totalEstimatedLoss = suggestions.fold<double>(
        0, (previousValue, element) => previousValue + element.estimatedLoss);

    if (suggestions.isEmpty) return const SizedBox.shrink();

    final urgency = TaxOptimizationService.getSeasonalityUrgency();

    // Smart Visibility:
    // - High/Medium Urgency (Oct-Dec): Show for any loss > $10
    // - Low Urgency (Jan-Sep): Only show for significant losses > $100
    final threshold = urgency > 0 ? -100.0 : -1000.0;
    if (totalEstimatedLoss > threshold) return const SizedBox.shrink();

    final formatCurrency = NumberFormat.simpleCurrency();

    return FutureBuilder<PortfolioHistoricals>(
      future: widget.portfolioHistoricalsFuture,
      builder: (context, snapshot) {
        final portfolioHistoricals = snapshot.data;
        final estimatedRealizedGains =
            TaxOptimizationService.calculateEstimatedRealizedGains(
          portfolioHistoricals: portfolioHistoricals,
          instrumentPositions: instrumentPositionStore.items,
          optionPositions: optionPositionStore.items,
        );

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.5),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TaxOptimizationWidget(
                    user: widget.user,
                    service: widget.service,
                    analytics: widget.analytics,
                    observer: widget.observer,
                    generativeService: widget.generativeService,
                    appUser: widget.appUser,
                    userDocRef: widget.userDocRef,
                    portfolioHistoricals: portfolioHistoricals, // Pass it down
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.savings_outlined,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text('Tax Loss Harvesting',
                                  style: Theme.of(context).textTheme.titleLarge,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            if (urgency > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color:
                                      urgency == 2 ? Colors.red : Colors.orange,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  urgency == 2 ? 'URGENT' : 'SEASON',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        formatCurrency.format(totalEstimatedLoss),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Potential Loss',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (estimatedRealizedGains > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Can offset ~${formatCurrency.format(estimatedRealizedGains)} of YTD gains',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if (suggestions.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor:
                                Theme.of(context).colorScheme.surface,
                            child: Text(
                              suggestions.first.symbol.substring(0, 1),
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Top Opportunity',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  suggestions.first.symbol,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            formatCurrency
                                .format(suggestions.first.estimatedLoss),
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _buildInsightRow(
                    context,
                    Icons.info_outline,
                    Colors.orange,
                    '${suggestions.length} opportunities available to harvest.',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInsightRow(
      BuildContext context, IconData icon, Color color, String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Portfolio Analytics',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedBenchmark,
                    isDense: true,
                    items: _benchmarks.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value,
                            style: TextStyle(
                                color:
                                    Theme.of(context).colorScheme.onSurface)),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedBenchmark = newValue;
                          _analyticsFuture = _calculateAnalytics();
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: const Icon(Icons.help_outline),
                tooltip: 'Help & Documentation',
                onSelected: (value) {
                  switch (value) {
                    case 'definitions':
                      _showEnhancedInfoDialog(context);
                      break;
                    case 'quick_guide':
                      _showQuickGuide(context);
                      break;
                    case 'benchmarks':
                      _showBenchmarkGuide(context);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'quick_guide',
                    child: ListTile(
                      leading: Icon(Icons.book_outlined),
                      title: Text('Quick Guide'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'definitions',
                    child: ListTile(
                      leading: Icon(Icons.description_outlined),
                      title: Text('All Definitions'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'benchmarks',
                    child: ListTile(
                      leading: Icon(Icons.compare_arrows),
                      title: Text('Benchmark Guide'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSnapshotTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    String? footer,
    String? tooltip,
  }) {
    final tile = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon,
                  size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: valueColor ?? Theme.of(context).colorScheme.onSurface,
                ),
          ),
          if (footer != null) ...[
            const SizedBox(height: 4),
            Text(
              footer,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );

    if (tooltip != null && tooltip.isNotEmpty) {
      return Tooltip(
        richMessage: TextSpan(
          children: [
            TextSpan(
              text: '$label\n\n',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            TextSpan(
              text: tooltip,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white,
                height: 1.6,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        margin: const EdgeInsets.symmetric(horizontal: 20),
        showDuration: const Duration(seconds: 30),
        waitDuration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.grey[850]!,
              Colors.grey[900]!,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 12,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        textStyle: const TextStyle(color: Colors.white),
        child: tile,
      );
    }
    return tile;
  }

  Widget _buildRiskAdjustedReturnCard(
      BuildContext context, Map<String, dynamic> data) {
    List<Widget> stats = [];
    stats.add(_buildStatItem(context, 'Sharpe', data['sharpe'],
        goodThreshold: 1.0, badThreshold: 0.0));
    if (data.containsKey('sortino')) {
      stats.add(_buildStatItem(context, 'Sortino', data['sortino'],
          goodThreshold: 1.0, badThreshold: 0.0));
    }
    if (data.containsKey('treynor')) {
      stats.add(_buildStatItem(context, 'Treynor', data['treynor'],
          goodThreshold: 0.05));
    }
    if (data.containsKey('informationRatio')) {
      stats.add(_buildStatItem(context, 'Info Ratio', data['informationRatio'],
          goodThreshold: 0.5));
    }
    if (data.containsKey('calmar')) {
      stats.add(_buildStatItem(context, 'Calmar', data['calmar'],
          goodThreshold: 0.5));
    }
    if (data.containsKey('omega')) {
      stats.add(
          _buildStatItem(context, 'Omega', data['omega'], goodThreshold: 1.0));
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Text('Risk-Adjusted Return',
                    style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 20),
            _buildStatsGrid(stats),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketComparisonCard(
      BuildContext context, Map<String, dynamic> data) {
    if (!data.containsKey('beta') &&
        !data.containsKey('alpha') &&
        !data.containsKey('excessReturn')) {
      return const SizedBox.shrink();
    }

    List<Widget> stats = [];
    if (data.containsKey('beta')) {
      stats.add(_buildStatItem(context, 'Beta', data['beta'],
          neutralValue: 1.0, reverseColor: true));
    }
    if (data.containsKey('correlation')) {
      stats.add(_buildStatItem(context, 'Correlation', data['correlation'],
          goodThreshold: 0.7, badThreshold: 0.3));
    }
    if (data.containsKey('alpha')) {
      stats.add(_buildStatItem(context, 'Alpha', data['alpha'],
          isPercent: true, goodThreshold: 0.0));
    }
    if (data.containsKey('excessReturn')) {
      stats.add(_buildStatItem(context, 'Excess Return', data['excessReturn'],
          isPercent: true, goodThreshold: 0.0));
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.compare_arrows,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Text('Market Comparison',
                    style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 20),
            _buildStatsGrid(stats),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskCard(BuildContext context, Map<String, dynamic> data) {
    if (!data.containsKey('maxDrawdown') && !data.containsKey('volatility')) {
      return const SizedBox.shrink();
    }

    List<Widget> stats = [];
    if (data.containsKey('maxDrawdown')) {
      stats.add(_buildStatItem(context, 'Max Drawdown', data['maxDrawdown'],
          isPercent: true, reverseColor: true, badThreshold: 0.2));
    }
    if (data.containsKey('volatility')) {
      stats.add(_buildStatItem(context, 'Volatility', data['volatility'],
          isPercent: true, reverseColor: true, badThreshold: 0.2));
    }
    if (data.containsKey('var95')) {
      stats.add(_buildStatItem(context, 'VaR (95%)', data['var95'],
          isPercent: true, reverseColor: false, badThreshold: -0.02));
    }
    if (data.containsKey('cvar95')) {
      stats.add(_buildStatItem(context, 'CVaR (95%)', data['cvar95'],
          isPercent: true, reverseColor: false, badThreshold: -0.03));
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 12),
                Text('Risk Metrics',
                    style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 20),
            _buildStatsGrid(stats),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedEdgeCard(
      BuildContext context, Map<String, dynamic> data) {
    if (!data.containsKey('kellyCriterion') &&
        !data.containsKey('ulcerIndex') &&
        !data.containsKey('tailRatio')) {
      return const SizedBox.shrink();
    }

    List<Widget> stats = [];
    if (data.containsKey('kellyCriterion')) {
      stats.add(_buildStatItem(
          context, 'Kelly Criterion', data['kellyCriterion'],
          isPercent: true, goodThreshold: 0.05, badThreshold: 0.0));
    }
    if (data.containsKey('ulcerIndex')) {
      stats.add(_buildStatItem(context, 'Ulcer Index', data['ulcerIndex'],
          isPercent: true,
          reverseColor: true,
          badThreshold: 0.15,
          goodThreshold: 0.05));
    }
    if (data.containsKey('tailRatio')) {
      stats.add(_buildStatItem(context, 'Tail Ratio', data['tailRatio'],
          goodThreshold: 1.1, badThreshold: 0.9));
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology_rounded,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Text('Advanced Edge',
                    style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 20),
            _buildStatsGrid(stats),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyStatsCard(BuildContext context, Map<String, dynamic> data) {
    if (!data.containsKey('profitFactor') && !data.containsKey('winRate')) {
      return const SizedBox.shrink();
    }

    List<Widget> stats = [];
    if (data.containsKey('profitFactor')) {
      stats.add(_buildStatItem(context, 'Profit Factor', data['profitFactor'],
          goodThreshold: 1.5, badThreshold: 1.0));
    }
    if (data.containsKey('winRate')) {
      stats.add(_buildStatItem(context, 'Win Rate', data['winRate'],
          isPercent: true, goodThreshold: 0.55, badThreshold: 0.45));
    }
    if (data.containsKey('payoffRatio')) {
      stats.add(_buildStatItem(context, 'Payoff Ratio', data['payoffRatio'],
          goodThreshold: 1.5, badThreshold: 1.0));
    }
    if (data.containsKey('expectancy')) {
      stats.add(_buildStatItem(context, 'Expectancy', data['expectancy'],
          goodThreshold: 0.0, isCurrency: true));
    }
    if (data.containsKey('maxWinStreak')) {
      stats.add(_buildStatItem(
          context, 'Max Win Streak', (data['maxWinStreak'] as int).toDouble(),
          isInt: true, goodThreshold: 3.0));
    }
    if (data.containsKey('maxLossStreak')) {
      stats.add(_buildStatItem(
          context, 'Max Loss Streak', (data['maxLossStreak'] as int).toDouble(),
          isInt: true, badThreshold: 3.0, reverseColor: true));
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
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
            _buildStatsGrid(stats),
          ],
        ),
      ),
    );
  }

  void _showEnhancedInfoDialog(BuildContext context) {
    // Group definitions by category
    final riskAdjusted = [
      'Sharpe',
      'Sortino',
      'Treynor',
      'Info Ratio',
      'Calmar',
      'Omega'
    ];
    final market = ['Beta', 'Alpha', 'Excess Return', 'Correlation'];
    final risk = ['Max Drawdown', 'Volatility', 'VaR (95%)', 'CVaR (95%)'];
    final advanced = ['Kelly Criterion', 'Ulcer Index', 'Tail Ratio'];
    final daily = ['Profit Factor', 'Win Rate', 'Expectancy', 'Payoff Ratio'];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.library_books,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Analytics Definitions',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Performance Snapshot section
                      _buildPerformanceSnapshotInfoSection(context),
                      const SizedBox(height: 20),
                      _buildDefinitionCategory(context, 'Risk-Adjusted Returns',
                          Icons.trending_up, riskAdjusted),
                      const SizedBox(height: 16),
                      _buildDefinitionCategory(context, 'Market Comparison',
                          Icons.compare_arrows, market),
                      const SizedBox(height: 16),
                      _buildDefinitionCategory(
                          context, 'Risk Metrics', Icons.warning_amber, risk),
                      const SizedBox(height: 16),
                      _buildDefinitionCategory(
                          context, 'Advanced Edge', Icons.psychology, advanced),
                      const SizedBox(height: 16),
                      _buildDefinitionCategory(context, 'Daily Return Stats',
                          Icons.calendar_today, daily),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefinitionCategory(
      BuildContext context, String title, IconData icon, List<String> metrics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...metrics.map((metric) {
          final definition = definitions[metric];
          if (definition == null) return const SizedBox.shrink();
          final guidance = metricGuidance[metric];
          final hasGuidance = guidance != null;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: hasGuidance
                      ? () => _showMetricDetails(
                          context, metric, definition, guidance)
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                metric,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            if (hasGuidance)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.lightbulb_outline,
                                        size: 12,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer),
                                    const SizedBox(width: 2),
                                    Text(
                                      'Tips',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          definition,
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                        if (hasGuidance) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.touch_app,
                                  size: 14,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.6)),
                              const SizedBox(width: 4),
                              Text(
                                'Tap for examples & thresholds',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.8),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  void _showMetricDetails(BuildContext context, String metric,
      String definition, Map<String, dynamic> guidance) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primaryContainer,
                      Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.7),
                    ],
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.analytics,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        metric,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Content
              SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Definition
                    _buildDetailSection(
                      context,
                      'Definition',
                      Icons.description,
                      definition,
                    ),
                    const SizedBox(height: 16),
                    // Example
                    if (guidance['example'] != null)
                      _buildDetailSection(
                        context,
                        'Example',
                        Icons.lightbulb_outline,
                        guidance['example'] as String,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .tertiaryContainer
                            .withValues(alpha: 0.3),
                      ),
                    if (guidance['example'] != null) const SizedBox(height: 16),
                    // Thresholds
                    _buildThresholdsSection(context, guidance),
                    const SizedBox(height: 16),
                    // Tip
                    if (guidance['tip'] != null)
                      _buildDetailSection(
                        context,
                        'Pro Tip',
                        Icons.tips_and_updates,
                        guidance['tip'] as String,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .secondaryContainer
                            .withValues(alpha: 0.3),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(
    BuildContext context,
    String title,
    IconData icon,
    String content, {
    Color? backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor ??
            Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon,
                  size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThresholdsSection(
      BuildContext context, Map<String, dynamic> guidance) {
    final isReverse = guidance['reverse'] == true;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag,
                  size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Performance Thresholds',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (guidance['goodThreshold'] != null)
            _buildThresholdRow(
              context,
              isReverse
                  ? '< ${guidance['goodThreshold']}'
                  : '> ${guidance['goodThreshold']}',
              'Excellent',
              Colors.green,
            ),
          if (guidance['acceptableThreshold'] != null)
            _buildThresholdRow(
              context,
              isReverse
                  ? '< ${guidance['acceptableThreshold']}'
                  : '> ${guidance['acceptableThreshold']}',
              'Acceptable',
              Colors.orange,
            ),
          _buildThresholdRow(
            context,
            isReverse
                ? '> ${guidance['acceptableThreshold'] ?? guidance['goodThreshold']}'
                : '< ${guidance['acceptableThreshold'] ?? guidance['goodThreshold']}',
            'Needs Improvement',
            Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildThresholdRow(
      BuildContext context, String value, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _showQuickGuide(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.book,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Quick Reference Guide',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildGuideSection(
                        context,
                        'Getting Started',
                        Icons.play_circle_outline,
                        [
                          'Select a benchmark (SPY, QQQ, DIA, IWM) to compare your portfolio performance',
                          'Check the Performance Snapshot to see your cumulative return vs. benchmark',
                          'Review your Health Score for an overall assessment',
                          'Check Smart Insights for actionable recommendations',
                          'Tap any metric for a detailed definition',
                          'Review the Risk Heatmap to identify sector and correlation risks at a glance',
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildGuideSection(
                        context,
                        'Reading the Metrics',
                        Icons.analytics_outlined,
                        [
                          '🟢 Green values: Good performance',
                          '🔴 Red values: Areas needing attention',
                          '⚪ Gray values: Neutral or informational',
                          'Higher Sharpe/Sortino/Calmar = Better',
                          'Lower Max Drawdown/Volatility = Better',
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildGuideSection(
                        context,
                        'Key Thresholds',
                        Icons.speed,
                        [
                          'Sharpe > 1.0 = Good, > 2.0 = Excellent',
                          'Alpha > 0 = Outperforming benchmark',
                          'Beta > 1.0 = More volatile than market',
                          'Max Drawdown < 20% = Acceptable risk',
                          'Win Rate > 50% = More winning days',
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildGuideSection(
                        context,
                        'Taking Action',
                        Icons.lightbulb_outline,
                        [
                          'Low Sharpe? Diversify to improve risk-adjusted returns',
                          'Negative Alpha? Review underperforming positions',
                          'High Drawdown? Consider position sizing and stop-losses',
                          'High Beta? Add defensive assets to reduce volatility',
                          'Use Tax Optimization to harvest losses strategically',
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuideSection(
      BuildContext context, String title, IconData icon, List<String> points) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              child: Icon(icon,
                  size: 20, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...points.map((point) => Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ',
                      style: TextStyle(
                          fontSize: 16,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                  Expanded(
                    child: Text(
                      point,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  void _showBenchmarkGuide(BuildContext context) {
    const benchmarkInfo = {
      'SPY': {
        'name': 'S&P 500',
        'description':
            'Tracks the 500 largest US companies. Best for comparing against large-cap growth.',
        'icon': Icons.business,
        'color': Colors.blue,
      },
      'QQQ': {
        'name': 'Nasdaq 100',
        'description':
            'Tech-heavy index. Use when your portfolio is growth/tech focused.',
        'icon': Icons.computer,
        'color': Colors.purple,
      },
      'DIA': {
        'name': 'Dow Jones',
        'description':
            'Blue-chip stocks. Ideal for conservative, dividend-focused portfolios.',
        'icon': Icons.account_balance,
        'color': Colors.green,
      },
      'IWM': {
        'name': 'Russell 2000',
        'description':
            'Small-cap index. Compare here if you invest in smaller companies.',
        'icon': Icons.storefront,
        'color': Colors.orange,
      },
    };

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.compare_arrows,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Benchmark Guide',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Content
              SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: benchmarkInfo.entries.map((entry) {
                    final info = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color:
                              (info['color'] as Color).withValues(alpha: 0.3),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor:
                                (info['color'] as Color).withValues(alpha: 0.1),
                            child: Icon(
                              info['icon'] as IconData,
                              color: info['color'] as Color,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      entry.key,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (_selectedBenchmark == entry.key)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          'Active',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onPrimary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  info['name'] as String,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  info['description'] as String,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(List<Widget> stats) {
    return LayoutBuilder(builder: (context, constraints) {
      // Calculate item width based on available width
      // We want roughly 3 items per row on standard phones, 2 on small, 4 on tablets
      double itemWidth;
      if (constraints.maxWidth < 350) {
        itemWidth = (constraints.maxWidth - 8) / 2; // 2 items
      } else if (constraints.maxWidth > 600) {
        itemWidth = (constraints.maxWidth - 24) / 4; // 4 items
      } else {
        itemWidth = (constraints.maxWidth - 16) / 3; // 3 items
      }

      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: stats.map((widget) {
          return SizedBox(
            width: itemWidth,
            child: widget,
          );
        }).toList(),
      );
    });
  }

  Widget _buildStatItem(BuildContext context, String label, double? value,
      {bool isPercent = false,
      bool isCurrency = false,
      bool isInt = false,
      double? goodThreshold,
      double? badThreshold,
      double? neutralValue,
      bool reverseColor = false}) {
    String valueStr = '-';
    Color? valueColor;
    // Color borderColor = Theme.of(context).dividerColor.withValues(alpha: 0.1);

    if (value != null) {
      if (isPercent) {
        valueStr = '${(value * 100).toStringAsFixed(2)}%';
      } else if (isCurrency) {
        valueStr = NumberFormat.simpleCurrency().format(value);
      } else if (isInt) {
        valueStr = value.toStringAsFixed(0);
      } else {
        valueStr = value.toStringAsFixed(2);
      }

      if (goodThreshold != null) {
        if (value > goodThreshold) {
          valueColor = reverseColor ? Colors.red : Colors.green;
        } else if (badThreshold != null && value < badThreshold) {
          valueColor = reverseColor ? Colors.green : Colors.red;
        }
      } else if (badThreshold != null) {
        if (value > badThreshold) {
          valueColor = reverseColor ? Colors.red : Colors.green;
        } else {
          valueColor = reverseColor ? Colors.green : Colors.red;
        }
      }

      // if (valueColor != null) {
      //   borderColor = valueColor.withValues(alpha: 0.3);
      // }
    }

    return Tooltip(
      richMessage: TextSpan(
        children: [
          TextSpan(
            text: '$label\n\n',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          TextSpan(
            text: definitions[label] ?? '',
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white,
              height: 1.6,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      showDuration: const Duration(seconds: 30),
      waitDuration: const Duration(milliseconds: 500),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey[850]!,
            Colors.grey[900]!,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 12,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      textStyle: const TextStyle(color: Colors.white),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          // border: Border.all(color: borderColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(valueStr,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: valueColor ??
                          Theme.of(context).colorScheme.onSurface)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildESGCard(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _esgFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        var data = snapshot.data!;
        double totalScore = data['totalScore'];
        double envScore = data['environmentalScore'];
        double socScore = data['socialScore'];
        double govScore = data['governanceScore'];
        List<ESGScore> scores = data['scores'] ?? [];

        Color scoreColor = totalScore >= 70
            ? Colors.green
            : (totalScore >= 50 ? Colors.orange : Colors.red);

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.5),
            ),
          ),
          child: InkWell(
            onTap: () => _showESGDetails(context, scores),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ESG Analysis',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: scoreColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          totalScore.toStringAsFixed(1),
                          style: TextStyle(
                            color: scoreColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Environmental, Social, and Governance Score',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 24),
                  _buildESGBar(
                      context, 'Environmental', envScore, Colors.green),
                  const SizedBox(height: 16),
                  _buildESGBar(context, 'Social', socScore, Colors.blue),
                  const SizedBox(height: 16),
                  _buildESGBar(context, 'Governance', govScore, Colors.purple),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Based on weighted average of portfolio holdings.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 16,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showESGDetails(BuildContext context, List<ESGScore> scores) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        // Sort scores by total score descending
        var sortedScores = List<ESGScore>.from(scores)
          ..sort((a, b) => b.totalScore.compareTo(a.totalScore));

        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ESG Breakdown',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: sortedScores.length,
                    itemBuilder: (context, index) {
                      var score = sortedScores[index];
                      Color scoreColor = score.totalScore >= 70
                          ? Colors.green
                          : (score.totalScore >= 50
                              ? Colors.orange
                              : Colors.red);

                      return ListTile(
                        title: Text(
                          score.symbol,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          score.description ?? 'No description available.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              score.totalScore.toStringAsFixed(1),
                              style: TextStyle(
                                color: scoreColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              score.rating,
                              style: TextStyle(
                                color: scoreColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          // Could show even more details here
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildESGBar(
      BuildContext context, String label, double score, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            Text(score.toStringAsFixed(1),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score / 100,
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  void _showHealthScoreDetails(
      BuildContext context, Map<String, dynamic> data) {
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const Text(
                  'The Portfolio Health Score starts at a base of 50 and is adjusted based on your portfolio metrics across five key dimensions:',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                _buildHealthScoreDetailItem(
                  context,
                  Icons.trending_up,
                  Colors.blue,
                  'Risk-Adjusted Returns',
                  'Rewards high Sharpe, Sortino, and Omega ratios. Measures return efficiency per unit of risk taken. (Max +35/-15)',
                  riskAdjustedScore,
                  riskAdjustedDetails,
                ),
                _buildHealthScoreDetailItem(
                  context,
                  Icons.compare_arrows,
                  Colors.purple,
                  'Market Performance',
                  'Rewards positive Alpha and Information Ratio. Shows consistent outperformance vs benchmark. (Max +20/-15)',
                  marketPerformanceScore,
                  marketPerformanceDetails,
                ),
                _buildHealthScoreDetailItem(
                  context,
                  Icons.shield,
                  Colors.orange,
                  'Risk Management',
                  'Evaluates drawdowns, volatility, Beta, VaR/CVaR tail risk, and diversification benefit. (Max +20/-40)',
                  riskManagementScore,
                  riskManagementDetails,
                ),
                _buildHealthScoreDetailItem(
                  context,
                  Icons.check_circle_outline,
                  Colors.green,
                  'Efficiency & Consistency',
                  'Rewards Profit Factor, Win Rate, Calmar, and positive expectancy. Measures strategy sustainability. (Max +30/-15)',
                  efficiencyScore,
                  efficiencyDetails,
                ),
                _buildHealthScoreDetailItem(
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
          );
        },
      ),
    );
  }

  Widget _buildHealthScoreDetailItem(BuildContext context, IconData icon,
      Color color, String title, String description, double scoreAdjustment,
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

  String _getHealthScoreGrade(double score) {
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

  String _getHealthScoreLabel(double score) {
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
