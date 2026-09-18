import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/widgets/analytics_style_card.dart';
import 'package:robinhood_options_mobile/widgets/chat_widget.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/analytics/portfolio_health_card.dart';

/// The plain-language read on the portfolio: a health score, prioritized
/// observations, and a one-tap handoff to the AI assistant with the metrics
/// already in the prompt.
class AiInsightsCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final GenerativeService generativeService;
  final User? appUser;
  final String benchmarkSymbol;

  const AiInsightsCard({
    super.key,
    required this.data,
    required this.generativeService,
    required this.appUser,
    this.benchmarkSymbol = 'SPY',
  });

  @override
  State<AiInsightsCard> createState() => _AiInsightsCardState();
}

class _AiInsightsCardState extends State<AiInsightsCard> {
  bool _showAllInsights = false;

  @override
  Widget build(BuildContext context) => _insights(context, widget.data);

  Widget _insights(BuildContext context, Map<String, dynamic> data) {
    List<Widget> insights = [];
    List<Widget> highPriority = [];
    List<Widget> mediumPriority = [];
    List<Widget> lowPriority = [];
    List<Widget> otherPriority = [];

    void addInsight(IconData icon, Color color, String text) {
      Widget widget = _insightRow(context, icon, color, text);
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
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 8,
                    color: scoreColor.withValues(alpha: 0.1),
                  ),
                ),
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 8,
                    valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                    strokeCap: StrokeCap.round,
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
                      Flexible(
                        child: Text('Portfolio Health Score',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () =>
                            PortfolioHealthCard.showDetails(context, data),
                        child: Icon(Icons.info_outline,
                            size: 18, color: scoreColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        PortfolioHealthCard.grade(score),
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
                        PortfolioHealthCard.label(score),
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

    // AI Analysis Button
    final aiButton = Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
      child: OutlinedButton.icon(
        onPressed: () => _generateAiAnalysis(context, data),
        icon: const Icon(Icons.auto_awesome, size: 18),
        label: const Text('Get AI Assessment'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );

    if (insights.isEmpty) {
      return AnalyticsStyleCard(
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
            const SizedBox(height: 16),
            const Text(
                'Not enough data for automated insights yet. Try the AI assessment.'),
            const SizedBox(height: 12),
            aiButton,
          ],
        ),
      );
    }

    final displayedInsights =
        _showAllInsights ? insights : insights.take(3).toList();

    return AnalyticsStyleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Portfolio Insights',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              // AI Button in header for compact mode
              IconButton(
                icon: const Icon(Icons.auto_awesome),
                tooltip: 'Analyze with AI',
                onPressed: () => _generateAiAnalysis(context, data),
              ),
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
    );
  }

  Widget _insightRow(
      BuildContext context, IconData icon, Color color, String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
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

  void _generateAiAnalysis(BuildContext context, Map<String, dynamic> metrics) {
    // 1. Fetch Positions for Context
    var instrumentPositionStore =
        Provider.of<InstrumentPositionStore>(context, listen: false);
    var positions = instrumentPositionStore.items;

    // Sort by market value desc
    final sortedPositions = List.of(positions)
      ..sort((a, b) => b.marketValue.compareTo(a.marketValue));

    final topPositions = sortedPositions.take(5).toList();
    final totalValue =
        positions.fold<double>(0, (sum, p) => sum + p.marketValue);

    // 2. Identify Sectors
    final Map<String, double> sectorAllocation = {};
    if (totalValue > 0) {
      for (var p in positions) {
        final sector = p.instrumentObj?.fundamentalsObj?.sector ?? 'Unknown';
        sectorAllocation.update(
            sector, (value) => value + (p.marketValue / totalValue),
            ifAbsent: () => p.marketValue / totalValue);
      }
    }

    final sb = StringBuffer();
    sb.writeln("Analyze my portfolio performance based on these metrics:");

    final percentFormat = NumberFormat.decimalPercentPattern(decimalDigits: 2);
    final decimalFormat = NumberFormat.decimalPattern();

    if (metrics.containsKey('portfolioCumulative')) {
      sb.writeln(
          "- Cumulative Return: ${percentFormat.format(metrics['portfolioCumulative'])}");
    }
    if (metrics.containsKey('benchmarkCumulative')) {
      sb.writeln(
          "- Benchmark Return ($widget.benchmarkSymbol): ${percentFormat.format(metrics['benchmarkCumulative'])}");
    }
    if (metrics.containsKey('sharpe')) {
      sb.writeln("- Sharpe Ratio: ${decimalFormat.format(metrics['sharpe'])}");
    }
    if (metrics.containsKey('sortino')) {
      sb.writeln(
          "- Sortino Ratio: ${decimalFormat.format(metrics['sortino'])}");
    }
    if (metrics.containsKey('maxDrawdown')) {
      sb.writeln(
          "- Max Drawdown: ${percentFormat.format(metrics['maxDrawdown'])}");
    }
    if (metrics.containsKey('beta')) {
      sb.writeln("- Beta: ${decimalFormat.format(metrics['beta'])}");
    }
    if (metrics.containsKey('alpha')) {
      sb.writeln("- Alpha: ${percentFormat.format(metrics['alpha'])}");
    }
    if (metrics.containsKey('volatility')) {
      sb.writeln(
          "- Volatility: ${percentFormat.format(metrics['volatility'])}");
    }
    if (metrics.containsKey('correlation')) {
      sb.writeln(
          "- Correlation: ${percentFormat.format(metrics['correlation'])}");
    }

    // Add Holdings Context
    if (topPositions.isNotEmpty && totalValue > 0) {
      sb.writeln("\nTop Holdings (Context):");
      for (var p in topPositions) {
        final allocation = p.marketValue / totalValue;
        final symbol = p.instrumentObj?.symbol ?? 'Unknown';
        final sector = p.instrumentObj?.fundamentalsObj?.sector ?? 'Unknown';
        sb.writeln("- $symbol: ${percentFormat.format(allocation)} ($sector)");
      }
    }

    // Add Sector Context
    if (sectorAllocation.isNotEmpty) {
      sb.writeln("\nSector Allocation:");
      var sortedSectors = sectorAllocation.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (var entry in sortedSectors.take(5)) {
        sb.writeln("- ${entry.key}: ${percentFormat.format(entry.value)}");
      }
    }

    sb.writeln("\nPlease provide:");
    sb.writeln("1. An executive summary of my performance.");
    sb.writeln("2. Risk assessment (drawdown, volatility, beta).");
    sb.writeln(
        "3. Analysis of how my top holdings/sectors contribute to my risk profile.");
    sb.writeln(
        "4. Three specific, actionable recommendations to improve my risk-adjusted returns (Sharpe/Sortino).");

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatWidget(
          generativeService: widget.generativeService,
          user: widget.appUser,
          initialMessage: sb.toString(),
        ),
      ),
    );
  }
}
