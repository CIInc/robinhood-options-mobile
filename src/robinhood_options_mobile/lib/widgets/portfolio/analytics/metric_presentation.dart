import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Shared rendering and reference material for the quantitative metrics.
///
/// These were instance methods on `PortfolioAnalyticsWidget`. They are static
/// here because the Performance and Risk sections both render the same stat
/// tiles and open the same explainer dialogs, and neither one owns the
/// definitions.
class MetricPresentation {
  const MetricPresentation._();

  static const Map<String, String> definitions = {
    'Sharpe':
        'Risk-adjusted return metric. Shows how much excess return you earn per unit of risk.\n\n✓ >2.0: Excellent\n✓ >1.0: Good\n✗ <0: Negative returns',
    'Sortino':
        'Like Sharpe, but only penalizes downside volatility. Better for asymmetric strategies.\n\n✓ >2.0: Excellent\n✓ >1.0: Good\nFocuses on downside risk only',
    'Treynor':
        'Excess return per unit of systematic risk (Beta). Best for diversified portfolios.\n\n✓ >0.15: Excellent\n✓ >0.05: Good\nHigher = Better risk-adjusted returns',
    'Info Ratio':
        'Measures consistent outperformance vs. benchmark. Active management skill indicator.\n\n✓ >0.5: Good\n✓ >0: Positive\nNegative = Underperforming inconsistently',
    'Calmar':
        'Annual return ÷ Max Drawdown. Shows return efficiency relative to worst-case loss.\n\n✓ >3.0: Exceptional\n✓ >0.5: Acceptable\nHigher = Better recovery',
    'Omega':
        'Probability-weighted gains vs. losses ratio. Captures full return distribution.\n\n✓ >2.0: Excellent\n✓ >1.0: Profitable\nMust be >1.0 to be positive',
    'Beta':
        'Market volatility multiplier. Shows portfolio sensitivity to market moves.\n\n⚡ >1.2: Aggressive\n⚖ 0.8-1.2: Balanced\n🛡 <0.8: Defensive',
    'Alpha':
        'True outperformance beyond what Beta predicts. The holy grail of investing.\n\n✓ >5%: Excellent\n✓ >0%: Positive\n✗ <0%: Underperforming',
    'Excess Return':
        'Portfolio return minus benchmark return. Simple outperformance measure.\n\n✓ >0%: Outperforming\n= 0%: Matching\n✗ <0%: Underperforming',
    'Annualized Return':
        'Compound Annual Growth Rate (CAGR). The smoothed annual return.',
    'Tracking Error':
        'Standard deviation of active returns. Measures consistency vs. benchmark.\n\n✓ <5%: Index hugger\n⚠ >10%: Active manager\nLower = Closer tracking',
    'Max Drawdown':
        'Largest peak-to-trough loss. Your worst-case scenario experience.\n\n✓ <10%: Low risk\n⚠ <20%: Moderate\n✗ >30%: High risk - Review stops',
    'Current Drawdown':
        'Percentage drop from the highest peak in the selected period to the current value.\n\n✓ 0%: At all-time high\n⚠ < -10%: In correction\n✗ < -20%: Bear market',
    'Volatility':
        'Annualized return swings (std dev). How bumpy the ride is.\n\n🎢 Higher = Wilder swings\n🚂 Lower = Smoother ride\nCompare to benchmark',
    'Correlation':
        'How closely you track the market. Diversification indicator.\n\n⚠ >0.9: High - Consider diversifying\n✓ 0.5-0.8: Moderate\n⬇ <0: Inverse',
    'VaR (95%)':
        'Value at Risk: Max expected 1-day loss (95% confidence). Tail risk metric.\n\nExample: -2% = 5% chance of losing >2% in a day\n⚠ Watch for spikes',
    'CVaR (95%)':
        'Expected Shortfall: Average loss when VaR is breached. True tail risk.\n\n⚠ Shows "black swan" severity\nAlways worse than VaR\nCritical for risk mgmt',
    'Profit Factor':
        'Gross Profits ÷ Gross Losses. The profitability multiplier.\n\n✓ >2.0: Highly profitable\n✓ >1.5: Good\n✓ >1.0: Profitable\n✗ <1.0: Losing',
    'Win Rate':
        'Percentage of winning days. Consistency indicator.\n\n✓ >65%: High consistency\n✓ >50%: Above average\n⚠ <40%: Low - Need high payoff',
    'Expectancy':
        'Average \$ per day/trade. Your mathematical edge.\n\n✓ >0: Positive edge\n✗ <0: Negative edge\nMust be positive long-term',
    'Avg Win': 'Average daily gain on winning days. Higher is better.',
    'Avg Loss':
        'Average daily loss on losing days. Keep this small relative to Avg Win.',
    'Avg Daily': 'Average daily percentage return over the selected period.',
    'Payoff Ratio':
        'Avg Win ÷ Avg Loss. Win/loss size comparison.\n\n✓ >2.0: Large winners\n✓ >1.0: Wins bigger than losses\n⚠ <1.0: Losses cut gains',
    'Kelly Criterion':
        'Optimal position size for max long-term growth. Risk management tool.\n\n✓ >0: Mathematical edge\nUse 1/4 to 1/2 Kelly in practice\n⚠ Full Kelly = risky',
    'Ulcer Index':
        'Drawdown depth × duration. Emotional stress measure.\n\n✓ <5%: Low stress\n⚠ <10%: Moderate\n✗ >15%: High anxiety - Review strategy',
    'Tail Ratio':
        'Big gains vs. big losses ratio. Asymmetry indicator.\n\n✓ >1.0: Positive skew (good!)\n= 1.0: Symmetric\n✗ <1.0: Negative skew (bad)',
    'Max Win Streak':
        'Longest consecutive winning days. Momentum & consistency indicator.\n\n🔥 Higher = Better\nSignals favorable market conditions\nTrack for confidence',
    'Max Loss Streak':
        'Longest consecutive losing days. Resilience & risk control test.\n\n⚠ >5 days: Review strategy\nLower = Better risk mgmt\n🛑 Consider stops',
    'Best Day':
        'The highest single-day percentage gain in the selected period.',
    'Worst Day':
        'The largest single-day percentage loss in the selected period.',
    'Portfolio Return':
        'The total cumulative return of the portfolio over the selected period.',
    'Benchmark Return':
        'The total cumulative return of the benchmark index over the selected period.',
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
      'goodThreshold': -0.10,
      'acceptableThreshold': -0.20,
      'example':
          'A -25% drawdown means your portfolio fell 25% from peak to trough.',
      'tip': 'Use stop-losses and position sizing to limit maximum drawdown.',
      'reverse': false,
    },
    'Current Drawdown': {
      'goodThreshold': -0.05,
      'acceptableThreshold': -0.10,
      'example':
          'Current Drawdown of -12% means your portfolio is 12% below its recent peak.',
      'tip':
          'In deep drawdown? Reduce position size to preserve capital until momentum returns.',
      'reverse': false,
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
    'Tracking Error': {
      'goodThreshold': 0.05,
      'acceptableThreshold': 0.1,
      'example':
          'Tracking Error of 3% means you are efficiently matching the benchmark.',
      'tip':
          'Lower tracking error means your performance closely mirrors the benchmark.',
      'reverse': true,
    },
    'Excess Return': {
      'goodThreshold': 0.0,
      'acceptableThreshold': 0.0,
      'example':
          'Excess Return of +5% means you beat the benchmark by 5% over the period.',
      'tip': 'Positive excess return indicates true outperformance.',
    },
    'Annualized Return': {
      'goodThreshold': 0.10,
      'acceptableThreshold': 0.0,
      'example':
          'CAGR of 12% means your portfolio grew 12% annually on average.',
      'tip': 'Compare your CAGR against the S&P 500 (~10% historical average).',
    },
    'Correlation': {
      'goodThreshold': 0.7,
      'acceptableThreshold': 0.5,
      'example':
          'Correlation of 0.6 means you have healthy diversification from the index.',
      'tip':
          'Lower correlation (<0.7) means you are less exposed to broad market crashes.',
      'reverse': true,
    },
    'Best Day': {
      'tip': 'A high best day is good, but check if it was luck or volatility.',
    },
    'Worst Day': {
      'goodThreshold': -0.02,
      'acceptableThreshold': -0.05,
      'tip': 'Large single-day drops can indicate high risk exposure.',
    },
    'Portfolio Return': {
      'tip':
          'Cumulative return is the total percentage gain or loss over the specific time period.',
    },
    'Benchmark Return': {
      'tip':
          'Return of the selected benchmark (e.g. SPY) over the same time period and data points.',
    },
  };

  static Widget buildStatsGrid(List<Widget> stats) {
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
            height: 120,
            child: widget,
          );
        }).toList(),
      );
    });
  }

  static Widget buildStatItem(BuildContext context, String label, double? value,
      {bool isPercent = false,
      bool isCurrency = false,
      bool isInt = false,
      double? goodThreshold,
      double? badThreshold,
      double? neutralValue,
      bool reverseColor = false}) {
    String valueStr = '-';
    Color? valueColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
      child: InkWell(
        onTap: () {
          final definition = definitions[label];
          if (definition != null) {
            final guidance = metricGuidance[label] ??
                {'tip': definition, 'noThreshold': true};
            showMetricDetails(context, label, definition, guidance);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      Colors.grey[850]!,
                      Colors.grey[900]!,
                    ]
                  : [
                      Theme.of(context).colorScheme.surfaceContainer,
                      Theme.of(context).colorScheme.surface,
                    ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                blurRadius: 8,
                spreadRadius: 1,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: isDark
                            ? Colors.grey[400]
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(valueStr,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: valueColor ??
                            (isDark
                                ? Colors.white
                                : Theme.of(context).colorScheme.onSurface))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void showMetricDetails(BuildContext context, String metric,
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
                    _detailSection(
                      context,
                      'Definition',
                      Icons.description,
                      definition,
                    ),
                    const SizedBox(height: 16),
                    // Example
                    if (guidance['example'] != null)
                      _detailSection(
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
                    if (guidance['noThreshold'] != true &&
                        (guidance['goodThreshold'] != null ||
                            guidance['acceptableThreshold'] != null)) ...[
                      _thresholdsSection(context, guidance),
                      const SizedBox(height: 16),
                    ],
                    // Tip
                    if (guidance['tip'] != null)
                      _detailSection(
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

  static Widget _detailSection(
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

  static Widget _thresholdsSection(
      BuildContext context, Map<String, dynamic> guidance) {
    if (guidance['noThreshold'] == true ||
        (guidance['goodThreshold'] == null &&
            guidance['acceptableThreshold'] == null)) {
      return const SizedBox.shrink();
    }
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
            _thresholdRow(
              context,
              isReverse
                  ? '< ${guidance['goodThreshold']}'
                  : '> ${guidance['goodThreshold']}',
              'Excellent',
              Colors.green,
            ),
          if (guidance['acceptableThreshold'] != null)
            _thresholdRow(
              context,
              isReverse
                  ? '< ${guidance['acceptableThreshold']}'
                  : '> ${guidance['acceptableThreshold']}',
              'Acceptable',
              Colors.orange,
            ),
          _thresholdRow(
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

  static Widget _thresholdRow(
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

  static void showAllDefinitions(BuildContext context) {
    // Group definitions by category
    final riskAdjusted = [
      'Sharpe',
      'Sortino',
      'Treynor',
      'Info Ratio',
      'Calmar',
      'Omega'
    ];
    final market = ['Beta', 'Alpha', 'Correlation', 'Tracking Error'];
    final risk = [
      'Max Drawdown',
      'Current Drawdown',
      'Volatility',
      'VaR (95%)',
      'CVaR (95%)'
    ];
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
                      _performanceSnapshotInfoSection(context),
                      const SizedBox(height: 20),
                      _definitionCategory(context, 'Risk-Adjusted Returns',
                          Icons.trending_up, riskAdjusted),
                      const SizedBox(height: 16),
                      _definitionCategory(context, 'Market Comparison',
                          Icons.compare_arrows, market),
                      const SizedBox(height: 16),
                      _definitionCategory(
                          context, 'Risk Metrics', Icons.warning_amber, risk),
                      const SizedBox(height: 16),
                      _definitionCategory(
                          context, 'Advanced Edge', Icons.psychology, advanced),
                      const SizedBox(height: 16),
                      _definitionCategory(context, 'Daily Return Stats',
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

  static Widget _definitionCategory(
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
                      ? () => showMetricDetails(
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

  static void showQuickGuide(BuildContext context) {
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
                      _guideSection(
                        context,
                        'Getting Started',
                        Icons.play_circle_outline,
                        [
                          'Select a benchmark (SPY, QQQ, DIA, IWM) to compare your portfolio performance',
                          'Check the Performance Snapshot to see your cumulative return vs. benchmark',
                          'Check the Performance Chart to visualize trends and calculate YTD, 1Y, 2Y... returns',
                          'Review your Health Score for an overall assessment',
                          'Check Smart Insights for actionable recommendations',
                          'Tap "Analyze with AI" for a personalized assessment',
                          'Tap any metric for a detailed definition',
                          'Review the Risk Heatmap to identify sector and correlation risks at a glance',
                        ],
                      ),
                      const SizedBox(height: 20),
                      _guideSection(
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
                      _guideSection(
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
                      _guideSection(
                        context,
                        'Taking Action',
                        Icons.lightbulb_outline,
                        [
                          'Low Sharpe? Diversify to improve risk-adjusted returns',
                          'Negative Alpha? Review underperforming positions',
                          'High Drawdown? Consider position sizing and stop-losses',
                          'High Beta? Add defensive assets to reduce volatility',
                          'Use Tax Optimization to harvest losses strategically',
                          'Use the AI Assistant to get tailored advice for your situation',
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

  static Widget _guideSection(
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

  static void showBenchmarkGuide(BuildContext context,
      {String? selectedBenchmark}) {
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
                                    if (selectedBenchmark == entry.key)
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

  static Widget _performanceSnapshotInfoSection(BuildContext context) {
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
          Icons.calendar_today,
          'Annualized Return (CAGR)',
          'Compound Annual Growth Rate. Represents the smoothed annual return over the period. For periods < 1 year, this is projected.',
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
}
