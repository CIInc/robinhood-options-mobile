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

    double sortino = AnalyticsUtils.calculateSortinoRatio(portfolioReturns);
    double treynor =
        AnalyticsUtils.calculateTreynorRatio(portfolioReturns, beta);
    double informationRatio = AnalyticsUtils.calculateInformationRatio(
        portfolioReturns, benchmarkReturns);

    // Derive period length from aligned dates to match selected timeline
    double periodYears = 1.0;
    if (alignedDates.isNotEmpty) {
      final start = alignedDates.first;
      final end = alignedDates.last;
      final days = end.difference(start).inDays.abs();
      // Minimum of one day to avoid zero division
      periodYears = (days > 0 ? days : 1) / 365.0;
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
                  Text(
                    score >= 80
                        ? 'Excellent'
                        : (score >= 60
                            ? 'Good'
                            : (score >= 40 ? 'Moderate' : 'Needs Attention')),
                    style: TextStyle(
                      color: scoreColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ));
    }

    if (data.containsKey('sharpe')) {
      if (data['sharpe']! > 2.0) {
        addInsight(Icons.check_circle, Colors.green,
            'Excellent risk-adjusted returns (Sharpe > 2.0).');
      } else if (data['sharpe']! < 1.0 && data['sharpe']! > 0) {
        addInsight(Icons.info_outline, Colors.orange,
            'Consider diversifying to improve risk-adjusted returns (Sharpe < 1.0).');
      } else if (data['sharpe']! < 0) {
        addInsight(Icons.warning, Colors.red,
            'Negative risk-adjusted returns. Consider reducing risk.');
      }
    }

    if (data.containsKey('sortino')) {
      if (data['sortino']! > 2.0) {
        addInsight(Icons.shield, Colors.green,
            'Excellent downside protection (Sortino > 2.0).');
      } else if (data['sortino']! < 1.0 && data['sortino']! > 0) {
        addInsight(Icons.info_outline, Colors.orange,
            'Watch downside volatility (Sortino < 1.0).');
      }
    }

    if (data.containsKey('calmar')) {
      if (data['calmar']! > 3.0) {
        addInsight(Icons.trending_up, Colors.green,
            'Exceptional return relative to drawdown (Calmar > 3.0).');
      } else if (data['calmar']! < 0.5 && data['calmar']! > 0) {
        addInsight(Icons.warning_amber, Colors.orange,
            'High drawdown relative to return (Calmar < 0.5).');
      }
    }

    if (data.containsKey('profitFactor')) {
      if (data['profitFactor']! > 2.0) {
        addInsight(Icons.attach_money, Colors.green,
            'Highly profitable strategy (Profit Factor > 2.0).');
      } else if (data['profitFactor']! < 1.0) {
        addInsight(Icons.money_off, Colors.red,
            'Strategy is currently losing money (Profit Factor < 1.0).');
      }
    }

    if (data.containsKey('winRate')) {
      if (data['winRate']! > 0.65) {
        addInsight(Icons.check, Colors.green,
            'High win rate (${(data['winRate']! * 100).toStringAsFixed(0)}%).');
      } else if (data['winRate']! < 0.40) {
        addInsight(Icons.priority_high, Colors.orange,
            'Low win rate. Ensure average wins are large.');
      }
    }

    if (data.containsKey('alpha') && data.containsKey('beta')) {
      double alpha = data['alpha']!;
      String alphaFixed = (alpha * 100).abs().toStringAsFixed(1);

      if (alphaFixed == '0.0') {
        addInsight(Icons.compare_arrows, Colors.grey,
            'Performing in line with benchmark.');
      } else if (alpha > 0) {
        addInsight(Icons.trending_up, Colors.green,
            'Outperforming benchmark by $alphaFixed%.');
      } else {
        addInsight(Icons.trending_down, Colors.red,
            'Underperforming benchmark by $alphaFixed%.');
      }
    }

    if (data.containsKey('beta')) {
      double beta = data['beta']!;
      if (beta > 1.2) {
        addInsight(Icons.speed, Colors.orange,
            'Aggressive portfolio (Beta > 1.2). Consider adding defensive assets to reduce volatility.');
      } else if (beta < 0.8 && beta > 0) {
        addInsight(Icons.shield, Colors.blue,
            'Defensive portfolio (Beta < 0.8). Consider adding growth assets for higher potential returns.');
      } else if (beta < 0) {
        addInsight(Icons.shield, Colors.blue,
            'Portfolio is inversely correlated with the market.');
      }
    }

    if (data.containsKey('correlation')) {
      double correlation = data['correlation']!;
      if (correlation > 0.9) {
        addInsight(Icons.link, Colors.orange,
            'High correlation with market (> 0.9). Portfolio may lack diversification.');
      } else if (correlation < 0.5 && correlation > -0.5) {
        addInsight(Icons.link_off, Colors.green,
            'Low correlation provides good diversification benefits.');
      }
    }

    if (data.containsKey('maxDrawdown')) {
      if (data['maxDrawdown']! > 0.20) {
        addInsight(Icons.warning_amber, Colors.red,
            'High drawdown detected (${(data['maxDrawdown']! * 100).toStringAsFixed(1)}%). Review position sizing and stop-loss strategies.');
      }
    }

    if (data.containsKey('volatility') &&
        data.containsKey('benchmarkVolatility')) {
      double volDiff = data['volatility']! - data['benchmarkVolatility']!;
      if (volDiff > 0.10) {
        addInsight(Icons.waves, Colors.red,
            'Significantly higher volatility than benchmark. Ensure this aligns with your risk tolerance.');
      } else if (volDiff > 0.05) {
        addInsight(Icons.waves, Colors.orange,
            'Higher volatility than benchmark (${(data['volatility']! * 100).toStringAsFixed(1)}% vs ${(data['benchmarkVolatility']! * 100).toStringAsFixed(1)}%).');
      } else if (volDiff < -0.05) {
        addInsight(Icons.waves, Colors.green,
            'Lower volatility than benchmark (${(data['volatility']! * 100).toStringAsFixed(1)}% vs ${(data['benchmarkVolatility']! * 100).toStringAsFixed(1)}%).');
      }
    }

    if (data.containsKey('var95')) {
      double var95 = data['var95']!;
      if (var95 < -0.03) {
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
                    case 'health_score':
                      if (_analyticsFuture != null) {
                        _analyticsFuture!.then((data) {
                          if (data.containsKey('healthScore')) {
                            _showHealthScoreDetails(context, data);
                          }
                        });
                      }
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
                  const PopupMenuItem(
                    value: 'health_score',
                    child: ListTile(
                      leading: Icon(Icons.health_and_safety_outlined),
                      title: Text('Health Score Info'),
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
        }).toList(),
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
                          'Review your Health Score for an overall assessment',
                          'Check Smart Insights for actionable recommendations',
                          'Tap any metric for a detailed definition',
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
    // Calculate breakdown
    double riskAdjustedScore = 0;
    double marketPerformanceScore = 0;
    double riskManagementScore = 0;
    double efficiencyScore = 0;

    List<String> riskAdjustedDetails = [];
    List<String> marketPerformanceDetails = [];
    List<String> riskManagementDetails = [];
    List<String> efficiencyDetails = [];

    // Risk-Adjusted Returns
    if (data.containsKey('sharpe')) {
      double sharpe = data['sharpe']!;
      if (sharpe > 2.0) {
        riskAdjustedScore += 15;
        riskAdjustedDetails
            .add('Sharpe: ${sharpe.toStringAsFixed(2)} (> 2.0) [+15]');
      } else if (sharpe > 1.5) {
        riskAdjustedScore += 12;
        riskAdjustedDetails
            .add('Sharpe: ${sharpe.toStringAsFixed(2)} (> 1.5) [+12]');
      } else if (sharpe > 1.0) {
        riskAdjustedScore += 8;
        riskAdjustedDetails
            .add('Sharpe: ${sharpe.toStringAsFixed(2)} (> 1.0) [+8]');
      } else if (sharpe > 0.5) {
        riskAdjustedScore += 4;
        riskAdjustedDetails
            .add('Sharpe: ${sharpe.toStringAsFixed(2)} (> 0.5) [+4]');
      } else if (sharpe < 0) {
        riskAdjustedScore -= 10;
        riskAdjustedDetails
            .add('Sharpe: ${sharpe.toStringAsFixed(2)} (< 0.0) [-10]');
      }
    }
    if (data.containsKey('sortino')) {
      double sortino = data['sortino']!;
      if (sortino > 2.0) {
        riskAdjustedScore += 10;
        riskAdjustedDetails
            .add('Sortino: ${sortino.toStringAsFixed(2)} (> 2.0) [+10]');
      } else if (sortino > 1.0) {
        riskAdjustedScore += 5;
        riskAdjustedDetails
            .add('Sortino: ${sortino.toStringAsFixed(2)} (> 1.0) [+5]');
      }
    }
    if (data.containsKey('treynor')) {
      double treynor = data['treynor']!;
      if (treynor > 0.15) {
        riskAdjustedScore += 5;
        riskAdjustedDetails
            .add('Treynor: ${treynor.toStringAsFixed(2)} (> 0.15) [+5]');
      }
    }
    if (data.containsKey('omega')) {
      double omega = data['omega']!;
      if (omega > 2.0) {
        riskAdjustedScore += 5;
        riskAdjustedDetails
            .add('Omega: ${omega.toStringAsFixed(2)} (> 2.0) [+5]');
      }
    }

    // Market Performance
    if (data.containsKey('alpha')) {
      double alpha = data['alpha']!;
      if (alpha > 0.05) {
        marketPerformanceScore += 15;
        marketPerformanceDetails
            .add('Alpha: ${(alpha * 100).toStringAsFixed(1)}% (> 5%) [+15]');
      } else if (alpha > 0) {
        marketPerformanceScore += 5;
        marketPerformanceDetails
            .add('Alpha: ${(alpha * 100).toStringAsFixed(1)}% (> 0%) [+5]');
      } else if (alpha < -0.05) {
        marketPerformanceScore -= 5;
        marketPerformanceDetails
            .add('Alpha: ${(alpha * 100).toStringAsFixed(1)}% (< -5%) [-5]');
      }
    }
    if (data.containsKey('informationRatio')) {
      double ir = data['informationRatio']!;
      if (ir > 0.5) {
        marketPerformanceScore += 5;
        marketPerformanceDetails
            .add('Info Ratio: ${ir.toStringAsFixed(2)} (> 0.5) [+5]');
      }
      if (ir < -0.5) {
        marketPerformanceScore -= 5;
        marketPerformanceDetails
            .add('Info Ratio: ${ir.toStringAsFixed(2)} (< -0.5) [-5]');
      }
    }

    // Risk Management
    if (data.containsKey('maxDrawdown')) {
      double mdd = data['maxDrawdown']!;
      if (mdd < 0.10) {
        riskManagementScore += 10;
        riskManagementDetails.add(
            'Max Drawdown: ${(mdd * 100).toStringAsFixed(1)}% (< 10%) [+10]');
      } else if (mdd > 0.30) {
        riskManagementScore -= 20;
        riskManagementDetails.add(
            'Max Drawdown: ${(mdd * 100).toStringAsFixed(1)}% (> 30%) [-20]');
      } else if (mdd > 0.20) {
        riskManagementScore -= 10;
        riskManagementDetails.add(
            'Max Drawdown: ${(mdd * 100).toStringAsFixed(1)}% (> 20%) [-10]');
      }
    }
    if (data.containsKey('volatility') &&
        data.containsKey('benchmarkVolatility')) {
      double vol = data['volatility']!;
      double benchVol = data['benchmarkVolatility']!;
      if (vol < benchVol) {
        riskManagementScore += 5;
        riskManagementDetails.add(
            'Volatility: ${(vol * 100).toStringAsFixed(1)}% (< Benchmark) [+5]');
      } else if (vol > benchVol + 0.10) {
        riskManagementScore -= 5;
        riskManagementDetails.add(
            'Volatility: ${(vol * 100).toStringAsFixed(1)}% (> Benchmark + 10%) [-5]');
      }
    }
    if (data.containsKey('beta')) {
      double beta = data['beta']!;
      if (beta > 1.5 || beta < 0.5) {
        riskManagementScore -= 5;
        riskManagementDetails
            .add('Beta: ${beta.toStringAsFixed(2)} (Extreme) [-5]');
      }
    }
    if (data.containsKey('var95')) {
      double var95 = data['var95']!;
      if (var95 < -0.05) {
        riskManagementScore -= 5;
        riskManagementDetails.add(
            'VaR (95%): ${(var95 * 100).toStringAsFixed(1)}% (< -5%) [-5]');
      } else if (var95 < -0.03) {
        riskManagementScore -= 5;
        riskManagementDetails.add(
            'VaR (95%): ${(var95 * 100).toStringAsFixed(1)}% (< -3%) [-5]');
      }
    }
    if (data.containsKey('cvar95')) {
      double cvar95 = data['cvar95']!;
      if (cvar95 < -0.07) {
        riskManagementScore -= 5;
        riskManagementDetails.add(
            'CVaR (95%): ${(cvar95 * 100).toStringAsFixed(1)}% (< -7%) [-5]');
      }
    }
    if (data.containsKey('correlation')) {
      double correlation = data['correlation']!;
      if (correlation < 0.7 && correlation > 0) {
        riskManagementScore += 5;
        riskManagementDetails
            .add('Correlation: ${correlation.toStringAsFixed(2)} (< 0.7) [+5]');
      } else if (correlation > 0.95) {
        riskManagementScore -= 5;
        riskManagementDetails.add(
            'Correlation: ${correlation.toStringAsFixed(2)} (> 0.95) [-5]');
      }
    }

    // Efficiency & Consistency
    if (data.containsKey('profitFactor')) {
      double pf = data['profitFactor']!;
      if (pf > 2.0) {
        efficiencyScore += 10;
        efficiencyDetails
            .add('Profit Factor: ${pf.toStringAsFixed(2)} (> 2.0) [+10]');
      } else if (pf > 1.5) {
        efficiencyScore += 7;
        efficiencyDetails
            .add('Profit Factor: ${pf.toStringAsFixed(2)} (> 1.5) [+7]');
      } else if (pf > 1.2) {
        efficiencyScore += 4;
        efficiencyDetails
            .add('Profit Factor: ${pf.toStringAsFixed(2)} (> 1.2) [+4]');
      } else if (pf < 1.0) {
        efficiencyScore -= 10;
        efficiencyDetails
            .add('Profit Factor: ${pf.toStringAsFixed(2)} (< 1.0) [-10]');
      }
    }
    if (data.containsKey('winRate')) {
      double wr = data['winRate']!;
      if (wr > 0.60) {
        efficiencyScore += 10;
        efficiencyDetails
            .add('Win Rate: ${(wr * 100).toStringAsFixed(0)}% (> 60%) [+10]');
      } else if (wr > 0.50) {
        efficiencyScore += 5;
        efficiencyDetails
            .add('Win Rate: ${(wr * 100).toStringAsFixed(0)}% (> 50%) [+5]');
      } else if (wr < 0.40) {
        efficiencyScore -= 5;
        efficiencyDetails
            .add('Win Rate: ${(wr * 100).toStringAsFixed(0)}% (< 40%) [-5]');
      }
    }
    if (data.containsKey('calmar')) {
      double calmar = data['calmar']!;
      if (calmar > 1.0) {
        efficiencyScore += 5;
        efficiencyDetails
            .add('Calmar: ${calmar.toStringAsFixed(2)} (> 1.0) [+5]');
      }
    }
    if (data.containsKey('payoffRatio')) {
      double payoff = data['payoffRatio']!;
      if (payoff > 2.0) {
        efficiencyScore += 5;
        efficiencyDetails
            .add('Payoff Ratio: ${payoff.toStringAsFixed(2)} (> 2.0) [+5]');
      } else if (payoff < 0.8) {
        efficiencyScore -= 5;
        efficiencyDetails
            .add('Payoff Ratio: ${payoff.toStringAsFixed(2)} (< 0.8) [-5]');
      }
    }
    if (data.containsKey('expectancy')) {
      double exp = data['expectancy']!;
      if (exp > 0) {
        efficiencyScore += 5;
        efficiencyDetails
            .add('Expectancy: \$${exp.toStringAsFixed(2)} (> 0) [+5]');
      }
    }
    if (data.containsKey('maxLossStreak')) {
      int streak = data['maxLossStreak']!;
      if (streak > 5) {
        efficiencyScore -= 5;
        efficiencyDetails.add('Max Loss Streak: $streak (> 5) [-5]');
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
                  'The Portfolio Health Score starts at a base of 60 and is adjusted based on your portfolio metrics across four key dimensions:',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                _buildHealthScoreDetailItem(
                  context,
                  Icons.trending_up,
                  Colors.blue,
                  'Risk-Adjusted Returns',
                  'Rewards high Sharpe and Sortino ratios. Measures how much return you are getting for each unit of risk taken.',
                  riskAdjustedScore,
                  riskAdjustedDetails,
                ),
                _buildHealthScoreDetailItem(
                  context,
                  Icons.compare_arrows,
                  Colors.purple,
                  'Market Performance',
                  'Rewards positive Alpha and Information Ratio. Indicates if you are beating the benchmark (SPY, QQQ, etc.).',
                  marketPerformanceScore,
                  marketPerformanceDetails,
                ),
                _buildHealthScoreDetailItem(
                  context,
                  Icons.shield,
                  Colors.orange,
                  'Risk Management',
                  'Penalizes high Drawdowns, extreme Beta, and excessive Volatility relative to the market.',
                  riskManagementScore,
                  riskManagementDetails,
                ),
                _buildHealthScoreDetailItem(
                  context,
                  Icons.check_circle_outline,
                  Colors.green,
                  'Efficiency & Consistency',
                  'Rewards high Profit Factor, Win Rate, and Calmar Ratio. Measures the sustainability of your trading strategy.',
                  efficiencyScore,
                  efficiencyDetails,
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
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Base Score'),
                          const Text('60'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Adjustments'),
                          Text(
                            (riskAdjustedScore +
                                    marketPerformanceScore +
                                    riskManagementScore +
                                    efficiencyScore)
                                .toStringAsFixed(0),
                            style: TextStyle(
                              color: (riskAdjustedScore +
                                          marketPerformanceScore +
                                          riskManagementScore +
                                          efficiencyScore) >=
                                      0
                                  ? Colors.green
                                  : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Score',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            (60 +
                                    riskAdjustedScore +
                                    marketPerformanceScore +
                                    riskManagementScore +
                                    efficiencyScore)
                                .clamp(0, 100)
                                .toStringAsFixed(0),
                            style: const TextStyle(fontWeight: FontWeight.bold),
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
}
