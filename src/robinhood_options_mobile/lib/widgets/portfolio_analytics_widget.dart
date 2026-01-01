import 'package:collection/collection.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals_store.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals_store.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/tax_optimization_service.dart';
import 'package:robinhood_options_mobile/utils/analytics_utils.dart';
import 'package:robinhood_options_mobile/enums.dart';
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
      this.futureMarketIndexHistoricalsDow});

  @override
  State<PortfolioAnalyticsWidget> createState() =>
      _PortfolioAnalyticsWidgetState();
}

class _PortfolioAnalyticsWidgetState extends State<PortfolioAnalyticsWidget> {
  Future<Map<String, dynamic>>? _analyticsFuture;
  String _selectedBenchmark = 'SPY'; // Default to SPY
  final List<String> _benchmarks = ['SPY', 'QQQ', 'DIA'];

  static const Map<String, String> definitions = {
    'Sharpe':
        'A measure of risk-adjusted return. Higher is better. >1 is good, >2 is very good.',
    'Sortino':
        'Similar to Sharpe, but only penalizes downside volatility. Useful for asymmetric return distributions.',
    'Treynor':
        'Excess return per unit of systematic risk (Beta). Useful for well-diversified portfolios.',
    'Info Ratio':
        'Measures portfolio returns beyond the returns of a benchmark, compared to the volatility of those returns (Tracking Error).',
    'Calmar':
        'Annualized return divided by Maximum Drawdown. Measures return relative to downside risk.',
    'Omega':
        'Probability weighted ratio of gains vs losses for a threshold return target. >1 indicates more gains than losses.',
    'Beta':
        'Volatility relative to the market (Benchmark). 1.0 means same volatility as market. >1 is more volatile.',
    'Alpha':
        'Excess return relative to the market benchmark. Positive alpha indicates outperformance.',
    'Excess Return':
        'The difference between the portfolio return and the benchmark return.',
    'Max Drawdown':
        'The maximum observed loss from a peak to a trough of a portfolio.',
    'Volatility':
        'Annualized standard deviation of returns. A measure of risk.',
    'VaR (95%)':
        'The maximum loss expected over a day with 95% confidence. E.g., -2% means there is a 5% chance of losing more than 2% in a day.',
  };

  @override
  void initState() {
    super.initState();
    _analyticsFuture = _calculateAnalytics();
  }

  @override
  void didUpdateWidget(PortfolioAnalyticsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.portfolioHistoricalsFuture !=
        oldWidget.portfolioHistoricalsFuture) {
      setState(() {
        _analyticsFuture = _calculateAnalytics();
      });
    }
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
    var instrumentStore =
        Provider.of<InstrumentHistoricalsStore>(context, listen: false);

    List<double> benchmarkPrices = [];
    List<DateTime> benchmarkDates = [];

    // Try to use market indices if available and selected
    if (_selectedBenchmark == 'SPY' &&
        widget.futureMarketIndexHistoricalsSp500 != null) {
      try {
        var data = await widget.futureMarketIndexHistoricalsSp500;
        if (data != null) {
          var timestamps = (data['chart']['result'][0]['timestamp'] as List);
          var adjcloses = (data['chart']['result'][0]['indicators']['adjclose']
              [0]['adjclose'] as List);
          for (int i = 0; i < timestamps.length; i++) {
            if (adjcloses[i] != null) {
              benchmarkDates.add(
                  DateTime.fromMillisecondsSinceEpoch(timestamps[i] * 1000));
              benchmarkPrices.add((adjcloses[i] as num).toDouble());
            }
          }
        }
      } catch (e) {
        debugPrint('Error using SP500 index data: $e');
      }
    } else if (_selectedBenchmark == 'QQQ' &&
        widget.futureMarketIndexHistoricalsNasdaq != null) {
      try {
        var data = await widget.futureMarketIndexHistoricalsNasdaq;
        if (data != null) {
          var timestamps = (data['chart']['result'][0]['timestamp'] as List);
          var adjcloses = (data['chart']['result'][0]['indicators']['adjclose']
              [0]['adjclose'] as List);
          for (int i = 0; i < timestamps.length; i++) {
            if (adjcloses[i] != null) {
              benchmarkDates.add(
                  DateTime.fromMillisecondsSinceEpoch(timestamps[i] * 1000));
              benchmarkPrices.add((adjcloses[i] as num).toDouble());
            }
          }
        }
      } catch (e) {
        debugPrint('Error using Nasdaq index data: $e');
      }
    } else if (_selectedBenchmark == 'DIA' &&
        widget.futureMarketIndexHistoricalsDow != null) {
      try {
        var data = await widget.futureMarketIndexHistoricalsDow;
        if (data != null) {
          var timestamps = (data['chart']['result'][0]['timestamp'] as List);
          var adjcloses = (data['chart']['result'][0]['indicators']['adjclose']
              [0]['adjclose'] as List);
          for (int i = 0; i < timestamps.length; i++) {
            if (adjcloses[i] != null) {
              benchmarkDates.add(
                  DateTime.fromMillisecondsSinceEpoch(timestamps[i] * 1000));
              benchmarkPrices.add((adjcloses[i] as num).toDouble());
            }
          }
        }
      } catch (e) {
        debugPrint('Error using Dow index data: $e');
      }
    }

    // Fallback to instrument search if index data not available or empty
    if (benchmarkPrices.isEmpty) {
      String? benchmarkId;
      try {
        var searchResult =
            await widget.service.search(widget.user, _selectedBenchmark);
        if (searchResult['results'] != null &&
            searchResult['results'].isNotEmpty) {
          for (var item in searchResult['results']) {
            if (item['symbol'] == _selectedBenchmark) {
              if (item['object_id'] != null) {
                benchmarkId = item['object_id'];
              } else if (item['id'] != null) {
                benchmarkId = item['id'];
              }
              break;
            }
          }
        }
      } catch (e) {
        debugPrint('Error searching for $_selectedBenchmark: $e');
      }

      if (benchmarkId == null) {
        // Fallback: Calculate Sharpe only
        List<double> portfolioPrices = portfolioHistoricals.equityHistoricals
            .map((e) => e.adjustedCloseEquity ?? e.closeEquity ?? 0.0)
            .toList();
        List<double> portfolioReturns =
            AnalyticsUtils.calculateDailyReturns(portfolioPrices);
        double sharpe = AnalyticsUtils.calculateSharpeRatio(portfolioReturns);
        double maxDrawdown =
            AnalyticsUtils.calculateMaxDrawdown(portfolioPrices);
        double volatility =
            AnalyticsUtils.calculateVolatility(portfolioReturns);
        return {
          'sharpe': sharpe,
          'maxDrawdown': maxDrawdown,
          'volatility': volatility
        };
      }

      // Fetch Benchmark historicals with same span/interval
      ChartDateSpan spanEnum = ChartDateSpan.year;
      if (portfolioHistoricals.span == '5year') spanEnum = ChartDateSpan.year_5;
      if (portfolioHistoricals.span == '3month') {
        spanEnum = ChartDateSpan.month_3;
      }

      try {
        var benchmarkHistoricals = await widget.service
            .getInstrumentHistoricals(widget.user, instrumentStore, benchmarkId,
                chartDateSpanFilter: spanEnum);
        for (var h in benchmarkHistoricals.historicals) {
          if (h.beginsAt != null && h.closePrice != null) {
            benchmarkDates.add(h.beginsAt!);
            benchmarkPrices.add(h.closePrice!);
          }
        }
      } catch (e) {
        debugPrint('Error fetching $_selectedBenchmark historicals: $e');
        // Fallback to Sharpe only
        List<double> portfolioPrices = portfolioHistoricals.equityHistoricals
            .map((e) => e.adjustedCloseEquity ?? e.closeEquity ?? 0.0)
            .toList();
        List<double> portfolioReturns =
            AnalyticsUtils.calculateDailyReturns(portfolioPrices);
        double sharpe = AnalyticsUtils.calculateSharpeRatio(portfolioReturns);
        double maxDrawdown =
            AnalyticsUtils.calculateMaxDrawdown(portfolioPrices);
        double volatility =
            AnalyticsUtils.calculateVolatility(portfolioReturns);
        return {
          'sharpe': sharpe,
          'maxDrawdown': maxDrawdown,
          'volatility': volatility
        };
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

    for (var h in portfolioHistoricals.equityHistoricals) {
      if (h.beginsAt != null) {
        String dateKey = h.beginsAt!.toIso8601String().split('T')[0];
        if (benchmarkMap.containsKey(dateKey)) {
          alignedPortfolioPrices
              .add(h.adjustedCloseEquity ?? h.closeEquity ?? 0.0);
          alignedBenchmarkPrices.add(benchmarkMap[dateKey]!);
        }
      }
    }

    List<double> portfolioReturns =
        AnalyticsUtils.calculateDailyReturns(alignedPortfolioPrices);
    List<double> benchmarkReturns =
        AnalyticsUtils.calculateDailyReturns(alignedBenchmarkPrices);

    double sharpe = AnalyticsUtils.calculateSharpeRatio(portfolioReturns);
    double beta =
        AnalyticsUtils.calculateBeta(portfolioReturns, benchmarkReturns);
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
    double calmar =
        AnalyticsUtils.calculateCalmarRatio(portfolioReturns, maxDrawdown);
    double omega = AnalyticsUtils.calculateOmegaRatio(portfolioReturns);
    double var95 = AnalyticsUtils.calculateVaR(portfolioReturns);

    // Calculate Health Score
    double healthScore = 70.0;
    if (sharpe > 2.0) {
      healthScore += 15;
    } else if (sharpe > 1.0) {
      healthScore += 10;
    } else if (sharpe < 0) {
      healthScore -= 10;
    }

    if (sortino > 1.5) healthScore += 5;
    if (alpha > 0) healthScore += 10;
    if (maxDrawdown > 0.20) healthScore -= 20;
    if (beta > 1.5) healthScore -= 5;

    healthScore = healthScore.clamp(0.0, 100.0);

    return {
      'sharpe': sharpe,
      'beta': beta,
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
      'healthScore': healthScore,
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
          ],
        );
      },
    );
  }

  Widget _buildInsightsCard(BuildContext context, Map<String, dynamic> data) {
    List<Widget> insights = [];

    if (data.containsKey('healthScore')) {
      double score = data['healthScore'];
      Color scoreColor = score >= 80
          ? Colors.green
          : (score >= 50 ? Colors.orange : Colors.red);

      insights.add(Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 6,
                    backgroundColor: scoreColor.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                  ),
                ),
                Text(
                  score.toStringAsFixed(0),
                  style: TextStyle(
                    color: scoreColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Portfolio Health Score',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    score >= 80
                        ? 'Excellent'
                        : (score >= 50 ? 'Moderate' : 'Needs Attention'),
                    style: TextStyle(
                      color: scoreColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ));
      insights.add(const Divider());
      insights.add(const SizedBox(height: 8));
    }

    if (data.containsKey('sharpe')) {
      if (data['sharpe']! > 2.0) {
        insights.add(_buildInsightRow(context, Icons.check_circle, Colors.green,
            'Excellent risk-adjusted returns (Sharpe > 2.0).'));
      } else if (data['sharpe']! < 0) {
        insights.add(_buildInsightRow(context, Icons.warning, Colors.orange,
            'Negative risk-adjusted returns. Consider reducing risk.'));
      }
    }

    if (data.containsKey('alpha') && data.containsKey('beta')) {
      if (data['alpha']! > 0) {
        insights.add(_buildInsightRow(context, Icons.trending_up, Colors.green,
            'Outperforming benchmark by ${(data['alpha']! * 100).toStringAsFixed(1)}%.'));
      } else {
        insights.add(_buildInsightRow(context, Icons.trending_down, Colors.red,
            'Underperforming benchmark by ${(data['alpha']! * 100).abs().toStringAsFixed(1)}%.'));
      }
    }

    if (data.containsKey('beta')) {
      if (data['beta']! > 1.1) {
        insights.add(_buildInsightRow(context, Icons.speed, Colors.orange,
            'Portfolio is ${(data['beta']! * 100 - 100).toStringAsFixed(0)}% more volatile than the market.'));
      } else if (data['beta']! < 0.9) {
        insights.add(_buildInsightRow(context, Icons.shield, Colors.blue,
            'Portfolio is ${(100 - data['beta']! * 100).toStringAsFixed(0)}% less volatile than the market.'));
      }
    }

    if (data.containsKey('maxDrawdown')) {
      if (data['maxDrawdown']! > 0.20) {
        insights.add(_buildInsightRow(context, Icons.warning_amber, Colors.red,
            'High drawdown detected (${(data['maxDrawdown']! * 100).toStringAsFixed(1)}%). Review risk management.'));
      }
    }

    if (data.containsKey('volatility') &&
        data.containsKey('benchmarkVolatility')) {
      double volDiff = data['volatility']! - data['benchmarkVolatility']!;
      if (volDiff > 0.05) {
        insights.add(_buildInsightRow(context, Icons.waves, Colors.orange,
            'Higher volatility than benchmark (${(data['volatility']! * 100).toStringAsFixed(1)}% vs ${(data['benchmarkVolatility']! * 100).toStringAsFixed(1)}%).'));
      } else if (volDiff < -0.05) {
        insights.add(_buildInsightRow(context, Icons.waves, Colors.green,
            'Lower volatility than benchmark (${(data['volatility']! * 100).toStringAsFixed(1)}% vs ${(data['benchmarkVolatility']! * 100).toStringAsFixed(1)}%).'));
      }
    }

    if (insights.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
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
            ...insights,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
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
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () => _showInfoDialog(context),
                tooltip: 'Definitions',
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
      stats.add(_buildStatItem(context, 'Treynor', data['treynor']));
    }
    if (data.containsKey('informationRatio')) {
      stats.add(_buildStatItem(context, 'Info Ratio', data['informationRatio'],
          goodThreshold: 0.0));
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
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
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
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
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

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
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

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Analytics Definitions'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: definitions.entries.map((entry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.key,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(entry.value),
                  const SizedBox(height: 8),
                ],
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(List<Widget> stats) {
    return LayoutBuilder(builder: (context, constraints) {
      int itemsPerRow = 3;
      if (constraints.maxWidth < 350) {
        itemsPerRow = 2;
      } else if (constraints.maxWidth > 600) {
        itemsPerRow = 4;
      }

      List<Widget> rows = [];
      for (int i = 0; i < stats.length; i += itemsPerRow) {
        int end =
            (i + itemsPerRow < stats.length) ? i + itemsPerRow : stats.length;
        List<Widget> rowItems = stats.sublist(i, end);

        List<Widget> expandedItems =
            rowItems.map<Widget>((w) => Expanded(child: w)).toList();

        // Fill with spacers if needed to maintain grid alignment
        while (expandedItems.length < itemsPerRow) {
          expandedItems.add(const Spacer());
        }

        List<Widget> rowChildren = [];
        for (int j = 0; j < expandedItems.length; j++) {
          rowChildren.add(expandedItems[j]);
          if (j < expandedItems.length - 1) {
            rowChildren.add(const SizedBox(width: 8));
          }
        }

        rows.add(Row(children: rowChildren));
        if (i + itemsPerRow < stats.length) {
          rows.add(const SizedBox(height: 8));
        }
      }
      return Column(children: rows);
    });
  }

  Widget _buildStatItem(BuildContext context, String label, double? value,
      {bool isPercent = false,
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
      message: definitions[label] ?? '',
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      showDuration: const Duration(seconds: 5),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
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
}
