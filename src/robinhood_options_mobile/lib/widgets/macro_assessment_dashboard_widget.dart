import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/macro_assessment.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/widgets/rebalancing_widget.dart';

class MacroAssessmentDashboardWidget extends StatelessWidget {
  final User? user;
  final DocumentReference<User>? userDocRef;
  final BrokerageUser? brokerageUser;

  const MacroAssessmentDashboardWidget({
    super.key,
    this.user,
    this.userDocRef,
    this.brokerageUser,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AgenticTradingProvider>(context);
    final assessment = provider.macroAssessment;

    if (assessment == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Macro Assessment"),
        ),
        body: const Center(
          child: Text("No assessment data available."),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.public, size: 24),
            SizedBox(width: 12),
            Text("Macro Assessment"),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Force Refresh',
            onPressed: () {
              // Trigger a force refresh
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Refreshing macro data from sources...')),
              );
              Provider.of<AgenticTradingProvider>(context, listen: false)
                  .fetchMacroAssessment(forceRefresh: true);
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showAboutDialog(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Summary Card
          _buildSummarySection(context, assessment),
          const SizedBox(height: 16),

          // Recent Changes (if any)
          if (provider.previousMacroAssessment != null) ...[
            _buildRecentChangesSection(
                context, assessment, provider.previousMacroAssessment!),
            const SizedBox(height: 24),
          ],

          // Indicators Heatmap
          Row(
            children: [
              Text(
                "Indicators Pulse",
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Tooltip(
                triggerMode: TooltipTriggerMode.tap,
                message:
                    "Real-time snapshot of 19 critical indicators. Signals update daily to quantify market health. Tap individual pillars below for more details.",
                child: Icon(Icons.info_outline,
                    size: 16,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildIndicatorHeatmap(context, assessment),
          const SizedBox(height: 12),
          _buildDivergenceSection(context, assessment),
          const SizedBox(height: 24),

          // Score History Chart
          if (provider.macroHistory.isNotEmpty) ...[
            Text(
              "Score Trend",
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildMacroHistoryChart(context, provider.macroHistory),
            const SizedBox(height: 24),
          ],

          // Indicators Grid
          Text(
            "Pillar Indicators",
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildIndicatorGrid(context, assessment),
          const SizedBox(height: 24),

          // Sector & Allocation
          if (assessment.sectorRotation != null ||
              assessment.assetAllocation != null) ...[
            Text(
              "Regime Guidance",
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (assessment.sectorRotation != null) ...[
              _buildSectorSection(context, assessment.sectorRotation!),
              const SizedBox(height: 12),
            ],
            if (assessment.assetAllocation != null) ...[
              _buildAllocationCard(context, assessment.assetAllocation!),
              const SizedBox(height: 24),
            ],
          ],

          // Options Strategy Guidance
          _buildStrategyGuidanceSection(context, assessment),
          const SizedBox(height: 24),

          // Analysis
          Text(
            "AI Analysis",
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildAnalysisSection(context, assessment),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStrategyGuidanceSection(
      BuildContext context, MacroAssessment assessment) {
    final colorScheme = Theme.of(context).colorScheme;

    // Use dynamic strategies from backend if available, otherwise fallback
    final strategies = assessment.strategies ??
        (assessment.status == 'RISK_ON'
            ? [
                MacroStrategy(
                    name: 'Bull Call Spread',
                    icon: 'call_made',
                    risk: 'Limited',
                    description: 'Capitalize on upside while limiting cost.'),
                MacroStrategy(
                    name: 'Cash Secured Put',
                    icon: 'shield',
                    risk: 'Defined',
                    description: 'Generate income and entry at lower prices.'),
                MacroStrategy(
                    name: 'Long Call',
                    icon: 'add_circle',
                    risk: 'Premium',
                    description: 'Max leverage for strong directional moves.'),
              ]
            : assessment.status == 'RISK_OFF'
                ? [
                    MacroStrategy(
                        name: 'Bear Put Spread',
                        icon: 'call_received',
                        risk: 'Limited',
                        description:
                            'Profit from downside with lower premium cost.'),
                    MacroStrategy(
                        name: 'Covered Call',
                        icon: 'security',
                        risk: 'Stock Risk',
                        description:
                            'Generate income to offset potential losses.'),
                    MacroStrategy(
                        name: 'Long Put',
                        icon: 'remove_circle',
                        risk: 'Premium',
                        description:
                            'Direct hedge against market further declines.'),
                  ]
                : [
                    MacroStrategy(
                        name: 'Iron Condor',
                        icon: 'compare_arrows',
                        risk: 'Limited',
                        description:
                            'Profit from range-bound, sideways markets.'),
                    MacroStrategy(
                        name: 'Calendar Spread',
                        icon: 'calendar_today',
                        risk: 'Volatility',
                        description: 'Benefit from time decay and rising IV.'),
                    MacroStrategy(
                        name: 'Butterfly',
                        icon: 'filter_vintage',
                        risk: 'Limited',
                        description:
                            'Low cost way to play a specific price target.'),
                  ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Options Strategy Insights",
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.8,
          ),
          itemCount: strategies.length,
          itemBuilder: (context, index) {
            final strategy = strategies[index];
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.1)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_getStrategyIcon(strategy.icon),
                      color: colorScheme.primary, size: 28),
                  const SizedBox(height: 8),
                  Text(
                    strategy.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      strategy.risk,
                      style: TextStyle(
                          fontSize: 8,
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  IconData _getStrategyIcon(String iconName) {
    switch (iconName) {
      case 'call_made':
        return Icons.call_made;
      case 'shield':
        return Icons.shield;
      case 'add_circle':
        return Icons.add_circle;
      case 'call_received':
        return Icons.call_received;
      case 'security':
        return Icons.security;
      case 'remove_circle':
        return Icons.remove_circle;
      case 'compare_arrows':
        return Icons.compare_arrows;
      case 'calendar_today':
        return Icons.calendar_today;
      case 'filter_vintage':
        return Icons.filter_vintage;
      default:
        return Icons.help_outline;
    }
  }

  Widget _buildAnalysisSection(
      BuildContext context, MacroAssessment assessment) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
      ),
      child: SelectionArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  "AI Insight Engine",
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "GEMINI 2.5 LITE",
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (assessment.aiAnalysis != null) ...[
              MarkdownBody(
                data: assessment.aiAnalysis!,
                styleSheet: MarkdownStyleSheet(
                  p: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.5,
                        color: colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                  listBullet: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                "Indicator Logic",
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
            ],
            MarkdownBody(
              data: assessment.reason,
              styleSheet: MarkdownStyleSheet(
                p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                listBullet: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentChangesSection(
      BuildContext context, MacroAssessment current, MacroAssessment previous) {
    final colorScheme = Theme.of(context).colorScheme;

    final List<Widget> changes = [];

    // Check regime change
    if (current.status != previous.status) {
      changes.add(_buildChangeItem(
        context,
        Icons.swap_horiz_rounded,
        "Regime Shift",
        "Regime changed from ${previous.status} to ${current.status}",
        _getStatusColor(context, current.status),
      ));
    }

    // Check score change
    final scoreDiff = current.score - previous.score;
    if (scoreDiff.abs() >= 10) {
      changes.add(_buildChangeItem(
        context,
        scoreDiff > 0 ? Icons.trending_up : Icons.trending_down,
        "Significant Score Move",
        "Macro score ${scoreDiff > 0 ? 'increased' : 'decreased'} by ${scoreDiff.abs()} points.",
        scoreDiff > 0 ? Colors.green : Colors.red,
      ));
    }

    // Check indicator signals
    final List<String> signalKeys = [
      'VIX',
      'TNX',
      'SPY',
      'Put/Call',
      'Credit (HYG)',
      'Dollar (DXY)',
      'Yield Curve'
    ];
    final curMap = {
      'VIX': current.indicators.vix.signal,
      'TNX': current.indicators.tnx.signal,
      'SPY': current.indicators.marketTrend.signal,
      'Put/Call': current.indicators.putCallRatio?.signal,
      'Credit (HYG)': current.indicators.hyg?.signal,
      'Dollar (DXY)': current.indicators.dxy?.signal,
      'Yield Curve': current.indicators.yieldCurve?.signal,
    };
    final prevMap = {
      'VIX': previous.indicators.vix.signal,
      'TNX': previous.indicators.tnx.signal,
      'SPY': previous.indicators.marketTrend.signal,
      'Put/Call': previous.indicators.putCallRatio?.signal,
      'Credit (HYG)': previous.indicators.hyg?.signal,
      'Dollar (DXY)': previous.indicators.dxy?.signal,
      'Yield Curve': previous.indicators.yieldCurve?.signal,
    };

    for (final key in signalKeys) {
      final curVal = curMap[key];
      final prevVal = prevMap[key];
      if (curVal != null && prevVal != null && curVal != prevVal) {
        changes.add(_buildChangeItem(
          context,
          Icons.lens_blur_rounded,
          "$key Signal Shift",
          "Shifted from $prevVal to $curVal",
          _getStatusColor(context, curVal),
        ));
      }
    }

    if (changes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Market Shifts",
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: changes.asMap().entries.map((entry) {
              return Column(
                children: [
                  entry.value,
                  if (entry.key < changes.length - 1)
                    const Divider(height: 24, indent: 32),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildChangeItem(BuildContext context, IconData icon, String title,
      String description, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectorSection(BuildContext context, SectorRotation rotation) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildSectorCard(
            context,
            "FAVORED",
            rotation.bullish,
            Colors.green,
            Icons.keyboard_double_arrow_up_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSectorCard(
            context,
            "AVOID",
            rotation.bearish,
            Colors.red,
            Icons.keyboard_double_arrow_down_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildIndicatorGrid(BuildContext context, MacroAssessment assessment) {
    return Column(
      children: [
        _buildDetailedIndicatorCard(
          context,
          "VIX",
          "Volatility Index",
          assessment.indicators.vix,
          "The CBOE Volatility Index (VIX) measures the market's expectation of 30-day volatility. Often called the 'Fear Gauge', values below 20 typically signal a stable, constructive environment for equities, while spikes above 30 indicate high stress or panic.",
          Icons.warning_amber_rounded,
        ),
        const SizedBox(height: 12),
        _buildDetailedIndicatorCard(
          context,
          "TNX",
          "10-Year Yield",
          assessment.indicators.tnx,
          "The 10-Year Treasury Yield serves as a benchmark for the risk-free rate. Rising yields increase borrowing costs and lower the present value of future earnings, often putting pressure on high-growth stock valuations and P/E multiples.",
          Icons.account_balance_rounded,
          unit: '%',
        ),
        const SizedBox(height: 12),
        _buildDetailedIndicatorCard(
          context,
          "SPY",
          "Market Trend",
          assessment.indicators.marketTrend,
          "Follows the relative performance of the S&P 500 (SPY). Trading above the 200-day moving average is generally bullish, indicating long-term upward momentum, while falling below suggests a potential primary downtrend.",
          Icons.show_chart_rounded,
          unit: '\$',
        ),
        if (assessment.indicators.yieldCurve != null) ...[
          const SizedBox(height: 12),
          _buildDetailedIndicatorCard(
            context,
            "CURV",
            "Yield Curve",
            assessment.indicators.yieldCurve!,
            "The spread between 10-Year and 3-Month yields. A 'normal' upward-sloping curve signals economic growth. An 'inverted' (negative) curve has historically been one of the most reliable leading indicators of an upcoming recession.",
            Icons.insights_rounded,
            unit: '%',
          ),
        ],
        if (assessment.indicators.putCallRatio != null) ...[
          const SizedBox(height: 12),
          _buildDetailedIndicatorCard(
            context,
            "PCCR",
            "Put/Call Ratio",
            assessment.indicators.putCallRatio!,
            "The ratio of put options to call options traded. High ratios (excessive puts) suggest extreme pessimism, while low ratios suggest over-complacency. These extremes often act as powerful contrarian signals for market reversals.",
            Icons.pie_chart_rounded,
          ),
        ],
        if (assessment.indicators.btc != null) ...[
          const SizedBox(height: 12),
          _buildDetailedIndicatorCard(
            context,
            "BTC",
            "Risk Appetite",
            assessment.indicators.btc!,
            "Bitcoin often acts as a leading indicator for global liquidity and speculative risk appetite. Strength in crypto frequently correlates with increased interest in high-beta tech sectors and speculative growth stocks.",
            Icons.currency_bitcoin_rounded,
            unit: '\$',
          ),
        ],
        if (assessment.indicators.hyg != null) ...[
          const SizedBox(height: 12),
          _buildDetailedIndicatorCard(
            context,
            "HYG",
            "Credit Health",
            assessment.indicators.hyg!,
            "Tracks the High-Yield Corporate Bond market. Since 'junk' bonds are sensitive to economic stress, strength here indicates robust credit conditions and corporate solvency, while weakness often precedes broad equity sell-offs.",
            Icons.credit_card_rounded,
            unit: '\$',
          ),
        ],
        if (assessment.indicators.dxy != null) ...[
          const SizedBox(height: 12),
          _buildDetailedIndicatorCard(
            context,
            "DXY",
            "U.S. Dollar Index",
            assessment.indicators.dxy!,
            "The U.S. Dollar Index (DXY) measures the greenback against a basket of currencies. A rapidly rising dollar can squeeze global liquidity and hurt international earnings for U.S.-based multinational corporations.",
            Icons.currency_exchange_rounded,
          ),
        ],
        if (assessment.indicators.gold != null) ...[
          const SizedBox(height: 12),
          _buildDetailedIndicatorCard(
            context,
            "GOLD",
            "Safe Haven",
            assessment.indicators.gold!,
            "Gold serves as a traditional hedge against inflation and geopolitical instability. It often moves inversely to stocks during periods of extreme market fear or when real interest rates are falling.",
            Icons.monetization_on_rounded,
            unit: '\$',
          ),
        ],
        if (assessment.indicators.oil != null) ...[
          const SizedBox(height: 12),
          _buildDetailedIndicatorCard(
            context,
            "OIL",
            "Energy & Inflation",
            assessment.indicators.oil!,
            "Tracks Crude Oil prices. While moderate prices support growth, rapid spikes in energy costs can act as an 'inflation tax' on consumers, potentially slowing economic activity and increasing corporate input costs.",
            Icons.oil_barrel_rounded,
            unit: '\$',
          ),
        ],
        if (assessment.indicators.advDecline != null) ...[
          const SizedBox(height: 12),
          _buildDetailedIndicatorCard(
            context,
            "NYA",
            "Market Breadth",
            assessment.indicators.advDecline!,
            "The NYSE Advance-Decline line measures the net number of stocks rising versus falling. Healthy uptrends are typically 'broad-based' with many stocks participating, rather than being driven by just a few mega-cap names.",
            Icons.grid_view_rounded,
            unit: '\$',
          ),
        ],
        if (assessment.indicators.riskAppetite != null) ...[
          const SizedBox(height: 12),
          _buildDetailedIndicatorCard(
            context,
            "IWM",
            "Small Caps",
            assessment.indicators.riskAppetite!,
            "The Russell 2000 tracks smaller, domestically-focused companies. Outperformance in small caps is a key sign of 'risk-on' behavior, suggesting investors are confident enough to rotate away from defensive large-cap safety.",
            Icons.rocket_launch_rounded,
          ),
        ],
        if (assessment.indicators.creditSpreads != null) ...[
          const SizedBox(height: 12),
          _buildDetailedIndicatorCard(
            context,
            "LQD",
            "Credit Spreads",
            assessment.indicators.creditSpreads!,
            "Investment Grade Corporate Bonds (LQD). Comparing credit performance against Treasuries reveals corporate borrowing stress; widening spreads often precede economic slowdowns.",
            Icons.analytics_rounded,
            unit: '\$',
          ),
        ],
        if (assessment.indicators.globalRisk != null) ...[
          const SizedBox(height: 12),
          _buildDetailedIndicatorCard(
            context,
            "EEM",
            "Global Risk",
            assessment.indicators.globalRisk!,
            "Emerging Markets (EEM) performance. Weakness in global markets while the US remains strong can signal 'divergence' risk and overall declining global liquidity.",
            Icons.public_rounded,
            unit: '\$',
          ),
        ],
        if (assessment.indicators.copper != null) ...[
          const SizedBox(height: 12),
          _buildDetailedIndicatorCard(
            context,
            "HG=F",
            "Copper (Dr. Copper)",
            assessment.indicators.copper!,
            "Copper is a primary leading indicator of industrial growth. If copper prices drop while equities rise, it may signal an unsustainable rally disconnected from manufacturing reality.",
            Icons.precision_manufacturing_rounded,
            unit: '\$',
          ),
        ],
        if (assessment.indicators.interestRateVol != null) ...[
          const SizedBox(height: 12),
          _buildDetailedIndicatorCard(
            context,
            "^MOVE",
            "Interest Rate Vol",
            assessment.indicators.interestRateVol!,
            "The Treasury Volatility Index (^MOVE) is the 'bond market VIX.' Elevated MOVE readings signal instability in the Treasury market, which often forces institutional liquidations and de-risking in equities.",
            Icons.speed_rounded,
          ),
        ],
        if (assessment.indicators.bankingHealth != null) ...[
          const SizedBox(height: 12),
          _buildDetailedIndicatorCard(
            context,
            "KRE",
            "Banking Health",
            assessment.indicators.bankingHealth!,
            "Regional Banking Index (KRE). Regional banks are the primary transmission mechanism for domestic liquidity and lending. Weakness here often signals credit contraction and hidden economic stress.",
            Icons.account_balance_rounded,
            unit: '\$',
          ),
        ],
        if (assessment.indicators.breadthQuality != null) ...[
          const SizedBox(height: 12),
          _buildDetailedIndicatorCard(
            context,
            "RSP/SPY",
            "Breadth Quality",
            assessment.indicators.breadthQuality!,
            "Equal-Weight vs. Cap-Weight S&P 500 ratio. A rising ratio indicates the rally is broad-based across hundreds of stocks. A falling ratio signals high-concentration fragility, where only a few mega-caps are holding up the index.",
            Icons.layers_rounded,
          ),
        ],
        if (assessment.indicators.globalLeadership != null) ...[
          const SizedBox(height: 12),
          _buildDetailedIndicatorCard(
            context,
            "FXI",
            "Global Leadership",
            assessment.indicators.globalLeadership!,
            "iShares China Large-Cap ETF (FXI). As the world's second-largest economy and a primary driver of commodities and Emerging Markets, China's credit cycle often leads global risk sentiment by several weeks.",
            Icons.flag_rounded,
            unit: '\$',
          ),
        ],
      ],
    );
  }

  Widget _buildSummarySection(
      BuildContext context, MacroAssessment assessment) {
    final statusColor = _getStatusColor(context, assessment.status);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: statusColor.withValues(alpha: 0.2), width: 2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        assessment.status == 'RISK_ON'
                            ? Icons.trending_up
                            : assessment.status == 'RISK_OFF'
                                ? Icons.trending_down
                                : Icons.trending_flat,
                        color: statusColor,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text('Current Regime',
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(width: 4),
                      Tooltip(
                        triggerMode: TooltipTriggerMode.tap,
                        message: _getRegimeTooltip(assessment.status),
                        child: Icon(Icons.info_outline,
                            size: 14,
                            color: statusColor.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      assessment.status,
                      style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 18),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        triggerMode: TooltipTriggerMode.tap,
                        message:
                            "Composite score (0-100) based on all 19 indicators. Higher values indicate a more favorable 'Risk-On' environment.",
                        child: Icon(Icons.info_outline,
                            size: 14,
                            color: statusColor.withValues(alpha: 0.6)),
                      ),
                      const SizedBox(width: 4),
                      Text('Macro Score',
                          style: Theme.of(context).textTheme.titleSmall),
                    ],
                  ),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                        begin: 0, end: assessment.score.toDouble()),
                    duration: const Duration(seconds: 1),
                    builder: (context, value, child) {
                      return Text(
                        '${value.toInt()}/100',
                        style:
                            Theme.of(context).textTheme.displaySmall?.copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.w900,
                                ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 140,
            width: 140,
            child: Stack(
              children: [
                Center(
                  child: CustomPaint(
                    size: const Size(140, 140),
                    painter: _MacroScoreGaugePainter(
                      score: assessment.score.toDouble(),
                      color: statusColor,
                      backgroundColor: statusColor.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${assessment.score}',
                        style:
                            Theme.of(context).textTheme.headlineLarge?.copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 40,
                                ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${assessment.confidence}% CONF',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 9,
                                  ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'POINTS',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: statusColor.withValues(alpha: 0.6),
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Confidence and Signal Divergence Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  statusColor.withValues(alpha: 0.05),
                  colorScheme.surface,
                ],
              ),
              border: Border.all(color: statusColor.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Stats Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSummaryStat(
                        context,
                        "Confidence",
                        "${assessment.confidence}%",
                        _getConfidenceColor(assessment.confidence)),
                    Container(
                        height: 30,
                        width: 1,
                        color: colorScheme.outline.withValues(alpha: 0.1)),
                    _buildSummaryStat(
                        context,
                        "Volatility",
                        assessment.indicators.vix.value != null
                            ? assessment.indicators.vix.value! < 20
                                ? "LOW"
                                : "HIGH"
                            : "--",
                        assessment.indicators.vix.signal == 'BULLISH'
                            ? Colors.green
                            : Colors.red),
                    Container(
                        height: 30,
                        width: 1,
                        color: colorScheme.outline.withValues(alpha: 0.1)),
                    _buildSummaryStat(
                        context,
                        "Momentum",
                        assessment.indicators.marketTrend.momentum
                                ?.split(' ')
                                .first ??
                            "Neutral",
                        _getStatusColor(
                            context, assessment.indicators.marketTrend.signal)),
                  ],
                ),
                const Divider(height: 24),
                // Signal Breadth
                _buildSignalDistribution(context, assessment),
                const SizedBox(height: 20),
                // Guidance Section
                _buildSummaryGuidance(context, assessment),
                // const SizedBox(height: 20),
                // Confidence Meter

                // Redundant with pillar indicators below
                // Row(
                //   children: [
                //     Icon(Icons.info_outline,
                //         size: 14, color: statusColor.withValues(alpha: 0.6)),
                //     const SizedBox(width: 8),
                //     Flexible(
                //       child: Text(
                //         assessment.reason,
                //         style: Theme.of(context).textTheme.bodySmall?.copyWith(
                //               color:
                //                   colorScheme.onSurface.withValues(alpha: 0.7),
                //               fontStyle: FontStyle.italic,
                //               height: 1.3,
                //             ),
                //       ),
                //     ),
                //   ],
                // ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGuidance(
      BuildContext context, MacroAssessment assessment) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                "Guidance",
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _getStrategyImplication(assessment.status),
            style:
                Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }

  Color _getConfidenceColor(int confidence) {
    if (confidence >= 80) return Colors.green;
    if (confidence >= 60) return Colors.blue;
    if (confidence >= 40) return Colors.orange;
    return Colors.red;
  }

  Widget _buildSummaryStat(
      BuildContext context, String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSignalDistribution(
      BuildContext context, MacroAssessment assessment) {
    final colorScheme = Theme.of(context).colorScheme;
    int bullish = 0;
    int neutral = 0;
    int bearish = 0;

    final signals = [
      assessment.indicators.vix.signal,
      assessment.indicators.tnx.signal,
      assessment.indicators.marketTrend.signal,
      if (assessment.indicators.yieldCurve != null)
        assessment.indicators.yieldCurve!.signal,
      if (assessment.indicators.putCallRatio != null)
        assessment.indicators.putCallRatio!.signal,
      if (assessment.indicators.btc != null) assessment.indicators.btc!.signal,
      if (assessment.indicators.hyg != null) assessment.indicators.hyg!.signal,
      if (assessment.indicators.dxy != null) assessment.indicators.dxy!.signal,
      if (assessment.indicators.gold != null)
        assessment.indicators.gold!.signal,
      if (assessment.indicators.oil != null) assessment.indicators.oil!.signal,
      if (assessment.indicators.advDecline != null)
        assessment.indicators.advDecline!.signal,
      if (assessment.indicators.riskAppetite != null)
        assessment.indicators.riskAppetite!.signal,
      if (assessment.indicators.creditSpreads != null)
        assessment.indicators.creditSpreads!.signal,
      if (assessment.indicators.globalRisk != null)
        assessment.indicators.globalRisk!.signal,
      if (assessment.indicators.copper != null)
        assessment.indicators.copper!.signal,
      if (assessment.indicators.interestRateVol != null)
        assessment.indicators.interestRateVol!.signal,
      if (assessment.indicators.bankingHealth != null)
        assessment.indicators.bankingHealth!.signal,
      if (assessment.indicators.breadthQuality != null)
        assessment.indicators.breadthQuality!.signal,
      if (assessment.indicators.globalLeadership != null)
        assessment.indicators.globalLeadership!.signal,
    ];

    for (var s in signals) {
      if (s == 'BULLISH' || s == 'RISK_ON') {
        bullish++;
      } else if (s == 'BEARISH' || s == 'RISK_OFF') {
        bearish++;
      } else {
        neutral++;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  "Signal Breadth",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  triggerMode: TooltipTriggerMode.tap,
                  message:
                      "Shows the internal alignment of all 19 indicators. High 'Signal Breadth' (more Bullish than Bearish) confirms the strength of the current regime.",
                  child: Icon(Icons.info_outline,
                      size: 14,
                      color: colorScheme.onSurface.withValues(alpha: 0.4)),
                ),
              ],
            ),
            Text(
              "$bullish Bull / $bearish Bear",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 6,
            child: Row(
              children: [
                if (bullish > 0)
                  Expanded(
                    flex: bullish,
                    child: Container(color: Colors.green),
                  ),
                if (neutral > 0)
                  Expanded(
                    flex: neutral,
                    child: Container(color: Colors.amber),
                  ),
                if (bearish > 0)
                  Expanded(
                    flex: bearish,
                    child: Container(color: Colors.red),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedIndicatorCard(BuildContext context, String symbol,
      String name, MacroIndicator indicator, String description, IconData icon,
      {String? unit}) {
    final color = _getStatusColor(context, indicator.signal);
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(icon, color: color, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: colorScheme.outline
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  symbol,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Analysis & Impact",
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    _buildWeightBadge(context, symbol),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.8),
                        height: 1.5,
                      ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatTile(
                      context,
                      "Current Value",
                      unit == '\$'
                          ? '\$${indicator.value?.toStringAsFixed(2) ?? '--'}'
                          : "${indicator.value?.toStringAsFixed(2) ?? '--'}${unit ?? ''}",
                      colorScheme.onSurface,
                    ),
                    _buildStatTile(
                      context,
                      "Current Signal",
                      indicator.signal,
                      color,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatTile(
                      context,
                      "Market Trend",
                      indicator.trend,
                      colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                    if (indicator.momentum != null)
                      _buildStatTile(
                        context,
                        "Momentum",
                        indicator.momentum!,
                        color,
                      ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
          border: Border.all(color: color.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.05),
              colorScheme.surface,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: color, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: colorScheme.outline
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    symbol,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: colorScheme.onSurface
                                          .withValues(alpha: 0.9),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                if (indicator.trend != 'Unknown') ...[
                                  Icon(
                                    indicator.trend
                                                .toUpperCase()
                                                .contains('UP') ||
                                            indicator.trend
                                                .toUpperCase()
                                                .contains('RISING')
                                        ? Icons.trending_up_rounded
                                        : indicator.trend
                                                    .toUpperCase()
                                                    .contains('DOWN') ||
                                                indicator.trend
                                                    .toUpperCase()
                                                    .contains('FALLING')
                                            ? Icons.trending_down_rounded
                                            : Icons.trending_flat_rounded,
                                    size: 14,
                                    color: color.withValues(alpha: 0.7),
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  indicator.trend,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: colorScheme.onSurface
                                            .withValues(alpha: 0.6),
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          unit == '\$'
                              ? '\$${indicator.value?.toStringAsFixed(2) ?? '--'}'
                              : "${indicator.value?.toStringAsFixed(2) ?? '--'}${unit ?? ''}",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: colorScheme.onSurface,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border:
                              Border.all(color: color.withValues(alpha: 0.3))),
                      child: Text(
                        indicator.signal,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: color,
                          letterSpacing: 0.5,
                        ),
                      ),
                    )
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.85),
                    height: 1.4,
                  ),
            ),
            if (indicator.momentum != null) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.speed_rounded, size: 14, color: color),
                    const SizedBox(width: 6),
                    Text(
                      "Momentum: ",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      indicator.momentum!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(
      BuildContext context, String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildAllocationCard(
      BuildContext context, AssetAllocation allocation) {
    final colorScheme = Theme.of(context).colorScheme;
    final canNavigateToRebalancing = user != null &&
        userDocRef != null &&
        brokerageUser != null &&
        brokerageUser!.accounts.isNotEmpty;

    // Parse percentages for the chart
    double equityVal =
        double.tryParse(allocation.equity.replaceAll('%', '')) ?? 0;
    double fixedVal =
        double.tryParse(allocation.fixedIncome.replaceAll('%', '')) ?? 0;
    double cashVal = double.tryParse(allocation.cash.replaceAll('%', '')) ?? 0;
    double commodityVal =
        double.tryParse(allocation.commodities.replaceAll('%', '')) ?? 0;

    final data = [
      _AllocationData('Equity', equityVal, Colors.blue),
      _AllocationData('Fixed Inc', fixedVal, Colors.purple),
      _AllocationData('Cash', cashVal, Colors.green),
      _AllocationData('Cmdty', commodityVal, Colors.orange),
    ].where((d) => d.value > 0).toList();

    final seriesList = [
      charts.Series<_AllocationData, String>(
        id: 'Allocation',
        domainFn: (_AllocationData d, _) => d.label,
        measureFn: (_AllocationData d, _) => d.value,
        colorFn: (_AllocationData d, _) =>
            charts.ColorUtil.fromDartColor(d.color),
        data: data,
        labelAccessorFn: (_AllocationData d, _) => '${d.value.toInt()}%',
      )
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                height: 110,
                width: 110,
                child: charts.PieChart<String>(
                  seriesList,
                  animate: false,
                  defaultRenderer: charts.ArcRendererConfig<String>(
                    arcWidth: 28,
                    arcRendererDecorators: [
                      charts.ArcLabelDecorator<String>(
                        labelPosition: charts.ArcLabelPosition.inside,
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    _buildAllocationRow(
                        context, "Equity", allocation.equity, Colors.blue),
                    _buildAllocationRow(context, "Fixed Inc",
                        allocation.fixedIncome, Colors.purple),
                    _buildAllocationRow(
                        context, "Cash", allocation.cash, Colors.green),
                    _buildAllocationRow(context, "Commodities",
                        allocation.commodities, Colors.orange),
                  ],
                ),
              ),
            ],
          ),
          if (canNavigateToRebalancing) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () => _applyToRebalancing(context, allocation),
                icon: const Icon(Icons.balance, size: 18),
                label: const Text('Apply to Rebalancing'),
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _applyToRebalancing(BuildContext context, AssetAllocation allocation) {
    // Parse percentages and convert to 0-1 range
    final Map<String, double> macroAllocation = {
      'Stocks':
          (double.tryParse(allocation.equity.replaceAll('%', '')) ?? 0) / 100,
      'Fixed Income':
          (double.tryParse(allocation.fixedIncome.replaceAll('%', '')) ?? 0) /
              100,
      'Cash': (double.tryParse(allocation.cash.replaceAll('%', '')) ?? 0) / 100,
      'Crypto':
          (double.tryParse(allocation.commodities.replaceAll('%', '')) ?? 0) /
              100,
      'Options': 0.0,
    };

    // Navigate to rebalancing widget with pre-populated allocation
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RebalancingWidget(
          user: user!,
          userDocRef: userDocRef!,
          account: brokerageUser!.accounts.first,
          initialAssetAllocation: macroAllocation,
          applyMacroGuidance: true,
        ),
      ),
    );
  }

  Widget _buildAllocationRow(
      BuildContext context, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildDivergenceSection(
      BuildContext context, MacroAssessment assessment) {
    final div = assessment.signalDivergence;
    final total = div.bullishCount + div.bearishCount + div.neutralCount;
    if (total == 0) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "Signal Composition",
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              triggerMode: TooltipTriggerMode.tap,
              message:
                  "Aggregated view of all active signals. Conflict (Divergence) occurs when key indicators like VIX and SPY move in unexpected directions together, signaling potential instability.",
              child: Icon(Icons.info_outline,
                  size: 14,
                  color: colorScheme.onSurface.withValues(alpha: 0.4)),
            ),
            const Spacer(),
            if (div.isConflicted)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.compare_arrows, size: 12, color: Colors.orange),
                    SizedBox(width: 4),
                    Text(
                      "DIVERGENCE DETECTED",
                      style: TextStyle(
                          color: Colors.orange,
                          fontSize: 8,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 12,
            child: Row(
              children: [
                if (div.bullishCount > 0)
                  Expanded(
                    flex: div.bullishCount,
                    child: Container(color: Colors.green),
                  ),
                if (div.neutralCount > 0)
                  Expanded(
                    flex: div.neutralCount,
                    child: Container(color: Colors.amber),
                  ),
                if (div.bearishCount > 0)
                  Expanded(
                    flex: div.bearishCount,
                    child: Container(color: Colors.red),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildDivLabel(context, "Bullish", div.bullishCount, Colors.green),
            _buildDivLabel(context, "Neutral", div.neutralCount, Colors.amber),
            _buildDivLabel(context, "Bearish", div.bearishCount, Colors.red),
          ],
        ),
        if (div.isConflicted) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_rounded,
                    color: Colors.orange, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Mixed signals detected. Traditional correlations are decoupling, which often happens at major market turning points or during 'volatility expansion' regimes.",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDivLabel(
      BuildContext context, String label, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          "$label ($count)",
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
                fontSize: 10,
              ),
        ),
      ],
    );
  }

  Widget _buildWeightBadge(BuildContext context, String symbol) {
    // Weights from backend (MACRO_WEIGHTS)
    final weights = {
      'VIX': 15,
      'SPY': 15,
      'TNX': 10,
      'CURV': 10,
      'HYG': 8,
      'PCCR': 8,
      'NYA': 6,
      'IWM': 6,
      'LQD': 5,
      'BTC': 4,
      'HG=F': 3,
      'COPX': 3,
      'EEM': 2,
      'GOLD': 2,
      'OIL': 2,
      'DXY': 1,
      '^MOVE': 1,
      'MOVE': 1,
      'KRE': 1,
      'RSP/SPY': 1,
      'RSP': 1,
    };

    final weight = weights[symbol];
    if (weight == null) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final bool isHighWeight = weight >= 10;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isHighWeight
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHighWeight
              ? colorScheme.primary.withValues(alpha: 0.3)
              : colorScheme.outline.withValues(alpha: 0.1),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isHighWeight ? Icons.anchor : Icons.scale,
            size: 14,
            color: isHighWeight
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            "Weight: $weight%",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: isHighWeight
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurface,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicatorHeatmap(
      BuildContext context, MacroAssessment assessment) {
    final Map<String, MacroIndicator?> indicatorsMap = {
      'VIX': assessment.indicators.vix,
      'TNX': assessment.indicators.tnx,
      'SPY': assessment.indicators.marketTrend,
      'CURV': assessment.indicators.yieldCurve,
      'PCR': assessment.indicators.putCallRatio,
      'BTC': assessment.indicators.btc,
      'HYG': assessment.indicators.hyg,
      'DXY': assessment.indicators.dxy,
      'GOLD': assessment.indicators.gold,
      'OIL': assessment.indicators.oil,
      'NYA': assessment.indicators.advDecline,
      'IWM': assessment.indicators.riskAppetite,
      'LQD': assessment.indicators.creditSpreads,
      'EEM': assessment.indicators.globalRisk,
      'COP': assessment.indicators.copper,
      'MOVE': assessment.indicators.interestRateVol,
      'KRE': assessment.indicators.bankingHealth,
      'RSP': assessment.indicators.breadthQuality,
      'FXI': assessment.indicators.globalLeadership,
    };

    final children = <Widget>[];
    indicatorsMap.forEach((key, value) {
      if (value != null) {
        final color = _getStatusColor(context, value.signal);
        final bool isBullish =
            value.signal == 'BULLISH' || value.signal == 'RISK_ON';
        final bool isBearish =
            value.signal == 'BEARISH' || value.signal == 'RISK_OFF';

        children.add(
          Tooltip(
            message: '${value.signal}: ${value.trend}',
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(
                        alpha: isBullish || isBearish ? 0.25 : 0.1),
                    color.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: color.withValues(
                      alpha: isBullish || isBearish ? 0.5 : 0.2),
                  width: isBullish || isBearish ? 1.2 : 0.8,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        key,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  if (value.value != null)
                    Text(
                      key == 'SPY' ||
                              key == 'BTC' ||
                              key == 'DXY' ||
                              key == 'NYA' ||
                              key == 'VIX' ||
                              key == 'OIL' ||
                              key == 'GOLD'
                          ? (value.value! > 1000
                              ? '${(value.value! / 1000).toStringAsFixed(1)}k'
                              : value.value!
                                  .toStringAsFixed(value.value! < 10 ? 1 : 0))
                          : value.value!.toStringAsFixed(1),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }
    });

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 5,
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      childAspectRatio: 1.3,
      children: children,
    );
  }

  Widget _buildMacroHistoryChart(
      BuildContext context, List<MacroAssessment> history) {
    final colorScheme = Theme.of(context).colorScheme;

    if (history.isEmpty) return const SizedBox.shrink();

    final seriesList = [
      charts.Series<MacroAssessment, DateTime>(
        id: 'Macro Score',
        colorFn: (MacroAssessment assessment, _) {
          final color = _getStatusColor(context, assessment.status);
          return charts.ColorUtil.fromDartColor(color);
        },
        domainFn: (MacroAssessment assessment, _) => assessment.timestamp,
        measureFn: (MacroAssessment assessment, _) => assessment.score,
        data: history,
      )
    ];

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
      ),
      child: Stack(
        children: [
          // Background zones
          Column(
            children: [
              Expanded(
                flex: 40, // 60-100
                child: Container(
                  color: Colors.green.withValues(alpha: 0.05),
                ),
              ),
              Expanded(
                flex: 20, // 40-60
                child: Container(
                  color: Colors.amber.withValues(alpha: 0.05),
                ),
              ),
              Expanded(
                flex: 40, // 0-40
                child: Container(
                  color: Colors.red.withValues(alpha: 0.05),
                ),
              ),
            ],
          ),
          charts.TimeSeriesChart(
            seriesList,
            animate: true,
            primaryMeasureAxis: charts.NumericAxisSpec(
                tickProviderSpec: const charts.BasicNumericTickProviderSpec(
                    desiredTickCount: 5),
                viewport: const charts.NumericExtents(0.0, 100.0),
                renderSpec: charts.GridlineRendererSpec(
                    labelStyle: charts.TextStyleSpec(
                        color: charts.ColorUtil.fromDartColor(
                            colorScheme.onSurface.withValues(alpha: 0.5))),
                    lineStyle: charts.LineStyleSpec(
                        color: charts.ColorUtil.fromDartColor(
                            colorScheme.outline.withValues(alpha: 0.1))))),
            domainAxis: charts.DateTimeAxisSpec(
                renderSpec: charts.SmallTickRendererSpec(
                    labelStyle: charts.TextStyleSpec(
                        color: charts.ColorUtil.fromDartColor(
                            colorScheme.onSurface.withValues(alpha: 0.5))),
                    lineStyle: charts.LineStyleSpec(
                        color: charts.ColorUtil.fromDartColor(
                            colorScheme.outline.withValues(alpha: 0.1))))),
          ),
        ],
      ),
    );
  }

  Widget _buildSectorCard(BuildContext context, String title,
      List<String> sectors, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...sectors.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  "• $s",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
              )),
        ],
      ),
    );
  }

  String _getStrategyImplication(String status) {
    switch (status) {
      case 'RISK_ON':
        return "Market conditions are favorable. Focus on growth assets, aggressive entry strategies, and larger position sizes. Consider selling puts on pullbacks.";
      case 'RISK_OFF':
        return "High risk environment. Prioritize capital preservation. Increase cash levels, use tighter stop losses, and consider hedging with puts or inverse ETFs.";
      default:
        return "Neutral regime. Expect range-bound action. Focus on high-quality setups and income-generating strategies like covered calls or iron condors.";
    }
  }

  void _showAboutDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;

        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.96,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(Icons.psychology,
                                    color: colorScheme.primary, size: 32),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Macro Analysis",
                                        style: textTheme.headlineSmall
                                            ?.copyWith(
                                                fontWeight: FontWeight.bold)),
                                    Text("Methodology & Regime Insights",
                                        style: textTheme.bodySmall?.copyWith(
                                            color: colorScheme.secondary)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 48),

                          // How it Works Section with subtle background
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.auto_awesome,
                                        size: 20, color: colorScheme.primary),
                                    const SizedBox(width: 8),
                                    Text("The Macro Engine",
                                        style: textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  "RealizeAlpha's proprietary engine synthesizes 19 institutional-grade indicators into a single actionable signal. It continuously monitors the 'Market Regime'—the underlying DNA of price action—to distinguish between sustainable trends and trap-filled environments.",
                                  style: textTheme.bodyMedium
                                      ?.copyWith(height: 1.5),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),

                          Text("Regime Classifications",
                              style: textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(height: 8),
                          Text("How we quantify market risk and opportunity",
                              style: textTheme.bodySmall),
                          const SizedBox(height: 20),
                          _buildRegimeItem(
                              context,
                              "RISK ON",
                              "SCORE: 60 - 100",
                              _getStatusColor(context, "RISK_ON"),
                              "Constructive environment. High correlation between price and market internals. Volatility is compressed, and credit spreads are tightening. Focus on growth and aggressive accumulation."),
                          _buildRegimeItem(
                              context,
                              "NEUTRAL",
                              "SCORE: 41 - 59",
                              _getStatusColor(context, "NEUTRAL"),
                              "Transition phase. Indicators are Divergent (e.g., price is up but breadth is down). Expect high rotation, 'sawtooth' price action, and sector-specific performance. Capital preservation starts becoming priority."),
                          _buildRegimeItem(
                              context,
                              "RISK OFF",
                              "SCORE: 0 - 40",
                              _getStatusColor(context, "RISK_OFF"),
                              "Defensive environment. Systemic stress detected in credit or volatility. Trend persistence is low. Focus on hedging, cash positions, and reducing beta exposure. Avoid 'dip-buying' until internals stabilize."),

                          const Divider(height: 48),

                          Text("Core Analysis Pillars",
                              style: textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(height: 20),
                          _buildPillarItem(
                              context,
                              Icons.speed,
                              "Volatility Multi-Asset",
                              "Analyzes VIX (Equities), MOVE (Bonds), and GVZ (Gold) to detect cross-asset fear levels and regime shifts."),
                          _buildPillarItem(
                              context,
                              Icons.trending_up,
                              "Credit & Liquidity Pulse",
                              "Monitors Junk Bond spreads (HYG) and the Yield Curve (10Y-2Y) to track systemic liquidity and recession probability."),
                          _buildPillarItem(
                              context,
                              Icons.grid_view_rounded,
                              "Trend Breadth internals",
                              "Uses NYSE Advance-Decline, New Highs/Lows, and Volatility Skew to verify if the 'majority' of stocks are participating."),
                          _buildPillarItem(
                              context,
                              Icons.pie_chart_rounded,
                              "Contrarian & Sentiment",
                              "Tracks extreme Put/Call ratios and Dark Pool positioning to identify potential exhaustion and reversal points."),

                          const Divider(height: 48),

                          Text("Tactical Strategy Guide",
                              style: textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(height: 20),
                          _buildStrategyGuideItem(
                            context,
                            "Bullish (Risk-On)",
                            "Market favors momentum. Strategies: Long Calls, Bull Call Spreads, and Selling OTM Puts on quality names. Overweight Technology and Cyclicals.",
                            Colors.green,
                          ),
                          _buildStrategyGuideItem(
                            context,
                            "Bearish (Risk-Off)",
                            "Market favors defensive posture. Strategies: Bear Put Spreads, Long Puts, and moving to T-Bills/Cash. Focus on Utilities and Consumer Staples.",
                            Colors.red,
                          ),
                          _buildStrategyGuideItem(
                            context,
                            "Choppy (Neutral)",
                            "Market favors range-bound income. Strategies: Iron Condors, Calendar Spreads, and Butterfly Spreads. Focus on high-quality 'Value' stocks.",
                            Colors.orange,
                          ),

                          const SizedBox(height: 40),
                          _buildRiskDisclaimer(context),
                          const SizedBox(height: 32),

                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () => Navigator.pop(context),
                              style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                padding: const EdgeInsets.all(20),
                                backgroundColor: colorScheme.primaryContainer,
                                foregroundColor: colorScheme.onPrimaryContainer,
                              ),
                              child: const Text("Understand Regime",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRegimeItem(BuildContext context, String title, String range,
      Color color, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Text(
              range,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 10),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 12)),
                Text(description, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillarItem(
      BuildContext context, IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                Text(description, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(BuildContext context, String? status) {
    status = status?.toUpperCase();
    final isLight = Theme.of(context).brightness == Brightness.light;
    if (status == 'RISK_ON' ||
        status == 'BULLISH' ||
        status == 'BULL' ||
        status == 'OVERWEIGHT') {
      return isLight ? Colors.green.shade700 : Colors.green;
    } else if (status == 'RISK_OFF' ||
        status == 'BEARISH' ||
        status == 'BEAR' ||
        status == 'UNDERWEIGHT') {
      return isLight ? Colors.red.shade700 : Colors.red;
    } else {
      return isLight ? Colors.orange.shade800 : Colors.amber;
    }
  }

  Widget _buildStrategyGuideItem(
      BuildContext context, String title, String strategy, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            Text(strategy,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(height: 1.3)),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskDisclaimer(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Macro signals are probabilistic. Market conditions can shift rapidly. External events (economic prints, geopolitics) may override regime status.",
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.error,
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  String _getRegimeTooltip(String status) {
    switch (status.toUpperCase()) {
      case 'RISK_ON':
      case 'BULLISH':
        return "Constructive Regime: Indicators are aligned for trend persistence. Volatility is low, credit flows are positive, and breadth is broad. Focus: Aggressive Growth.";
      case 'RISK_OFF':
      case 'BEARISH':
        return "Defensive Regime: Systemic stress detected. High yields, rising fear (VIX), and narrow breadth suggest significant downside risk. Focus: Hedging & Capital Preservation.";
      case 'NEUTRAL':
      case 'CHOPPY':
        return "Transition Regime: Conflicting signals. Price may be rising while internals deteriorate. Expect high sector rotation and sawtooth action. Focus: Range-bound income.";
      default:
        return "Undetermined Regime: Market is searching for clear direction. Monitor for divergence in key pillars like Credit and Volatility.";
    }
  }
}

class _MacroScoreGaugePainter extends CustomPainter {
  final double score;
  final Color color;
  final Color backgroundColor;

  _MacroScoreGaugePainter({
    required this.score,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final strokeWidth = 8.0;

    // Background Arc
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    final rect =
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);
    const startAngle = 0.75 * math.pi;
    const totalSweep = 1.5 * math.pi;

    canvas.drawArc(
      rect,
      startAngle, // Start at bottom-left
      totalSweep, // 270 degree arc
      false,
      bgPaint,
    );

    // Dynamic Color Gradient for Progress
    final progressPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.red.withValues(alpha: 0.8),
          Colors.orange.withValues(alpha: 0.8),
          Colors.yellow.withValues(alpha: 0.8),
          Colors.green.withValues(alpha: 0.8),
          Colors.blue.withValues(alpha: 0.8),
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
        startAngle: startAngle,
        endAngle: startAngle + totalSweep,
        transform: GradientRotation(startAngle),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    // Normalize score to 0..1 then to radians
    final sweepAngle = (score / 100).clamp(0.0, 1.0) * totalSweep;

    canvas.drawArc(
      rect,
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );

    // Indicators for 0, 50, 100
    final labelPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (var i = 0; i <= 4; i++) {
      final angle = startAngle + (i / 4) * totalSweep;
      final offset1 = Offset(
        center.dx + (radius - strokeWidth) * math.cos(angle),
        center.dy + (radius - strokeWidth) * math.sin(angle),
      );
      final offset2 = Offset(
        center.dx + (radius) * math.cos(angle),
        center.dy + (radius) * math.sin(angle),
      );
      canvas.drawLine(offset1, offset2, labelPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MacroScoreGaugePainter oldDelegate) {
    return oldDelegate.score != score || oldDelegate.color != color;
  }
}

class _AllocationData {
  final String label;
  final double value;
  final Color color;

  _AllocationData(this.label, this.value, this.color);
}
