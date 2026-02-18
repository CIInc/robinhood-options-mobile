import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/model/macro_assessment.dart';

class MacroAssessmentWidget extends StatefulWidget {
  const MacroAssessmentWidget({super.key});

  @override
  State<MacroAssessmentWidget> createState() => _MacroAssessmentWidgetState();
}

class _MacroAssessmentWidgetState extends State<MacroAssessmentWidget> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Fetch on init if not already fetched
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAssessment();
    });
  }

  Future<void> _fetchAssessment() async {
    if (_isLoading) return;
    HapticFeedback.lightImpact();
    setState(() {
      _isLoading = true;
    });
    try {
      await Provider.of<AgenticTradingProvider>(context, listen: false)
          .fetchMacroAssessment();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AgenticTradingProvider>(context);
    final assessment = provider.macroAssessment;
    final colorScheme = Theme.of(context).colorScheme;

    if (assessment == null && _isLoading) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            constraints: const BoxConstraints(minHeight: 150),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Analyzing Macro Market State..."),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (assessment == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Text("Unable to load assessment."),
              TextButton.icon(
                onPressed: _fetchAssessment,
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
              )
            ],
          ),
        ),
      );
    }

    final statusColor = assessment.status == 'RISK_ON'
        ? Colors.green
        : assessment.status == 'RISK_OFF'
            ? Colors.red
            : Colors.amber;

    return Card(
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showDetails(context, assessment),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.public, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Macro Market State',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.only(right: 8.0),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: statusColor),
                        ),
                        child: Text(
                          assessment.status,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Risk Score',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '${assessment.score.toInt()}/100',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            if (provider.previousMacroAssessment != null) ...[
                              const SizedBox(width: 8),
                              _buildScoreTrendIcon(
                                  assessment.score.toDouble(),
                                  provider.previousMacroAssessment!.score
                                      .toDouble(),
                                  context),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(right: 16.0),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                                begin: 0, end: assessment.score / 100.0),
                            duration: const Duration(milliseconds: 1000),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) {
                              return LinearProgressIndicator(
                                value: value,
                                backgroundColor:
                                    statusColor.withValues(alpha: 0.2),
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(statusColor),
                                minHeight: 6,
                                borderRadius: BorderRadius.circular(3),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        assessment.reason,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              _buildIndicators(assessment, context),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                      onPressed: () => _fetchAssessment(),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text("Refresh")),
                  Text(
                    'Last updated: ${_formatDate(assessment.timestamp)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context, MacroAssessment assessment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final statusColor = assessment.status == 'RISK_ON'
            ? Colors.green
            : assessment.status == 'RISK_OFF'
                ? Colors.red
                : Colors.amber;

        return DraggableScrollableSheet(
            initialChildSize: 0.94,
            minChildSize: 0.5,
            maxChildSize: 0.94,
            expand: false,
            builder: (context, scrollController) {
              return Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.public, size: 28),
                            SizedBox(width: 12),
                            Text("Macro Assessment",
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        IconButton(
                            icon: const Icon(Icons.info_outline),
                            onPressed: () {
                              showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                          title: const Text(
                                              "About Macro Assessment"),
                                          content: const Text(
                                              "This analysis evaluates broad market risk using 12 key components:\n\n• 'Fear Index' (VIX) & Market Trend (SPY)\n• 10-Year Yields (TNX) & Yield Curve\n• Commodities (Gold & Oil)\n• Dollar Strength (DXY) & Bitcoin (Risk Appetite)\n• Corp Credit Health (HYG)\n• Put/Call Ratio (Sentiment)\n• Broad Breadth (NYA)\n• Risk Appetite (Small Caps IWM)\n\nA high score (>50) typically signals a 'Risk-On' environment favorable for buying, while a low score suggests 'Risk-Off', warranting caution."),
                                          actions: [
                                            TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx),
                                                child: const Text("Got it"))
                                          ]));
                            })
                      ],
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Score Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color:
                                    colorScheme.outline.withValues(alpha: 0.2)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Market State',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(
                                              alpha: 0.2),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border:
                                              Border.all(color: statusColor),
                                        ),
                                        child: Text(
                                          assessment.status,
                                          style: TextStyle(
                                              color: statusColor,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('Risk Score',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (Provider.of<AgenticTradingProvider>(
                                                      context,
                                                      listen: false)
                                                  .previousMacroAssessment !=
                                              null) ...[
                                            _buildScoreTrendIcon(
                                                assessment.score.toDouble(),
                                                Provider.of<AgenticTradingProvider>(
                                                        context,
                                                        listen: false)
                                                    .previousMacroAssessment!
                                                    .score
                                                    .toDouble(),
                                                context),
                                            const SizedBox(width: 8),
                                          ],
                                          Text(
                                            '${assessment.score}/100',
                                            style: Theme.of(context)
                                                .textTheme
                                                .displaySmall
                                                ?.copyWith(
                                                  color: statusColor,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 120,
                                width: 120,
                                child: Stack(
                                  children: [
                                    Center(
                                      child: CustomPaint(
                                        size: const Size(120, 120),
                                        painter: _MacroScoreGaugePainter(
                                          score: assessment.score.toDouble(),
                                          color: statusColor,
                                          backgroundColor: statusColor
                                              .withValues(alpha: 0.1),
                                        ),
                                      ),
                                    ),
                                    Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            '${assessment.score}%',
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineMedium
                                                ?.copyWith(
                                                  color: statusColor,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          Text(
                                            'RISK',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  color: statusColor.withValues(
                                                      alpha: 0.7),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: colorScheme.surface,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.lightbulb_outline,
                                            size: 16,
                                            color: colorScheme.primary),
                                        const SizedBox(width: 8),
                                        Text(
                                          "Strategy Implication",
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelLarge
                                              ?.copyWith(
                                                color: colorScheme.primary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _getStrategyImplication(
                                          assessment.status),
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          "Key Indicators",
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        Column(
                          children: [
                            _buildDetailedIndicatorCard(
                              context,
                              "VIX",
                              "Volatility Index",
                              assessment.indicators.vix,
                              "Measures expected market volatility. <20 is generally bullish, >30 indicates fear.",
                            ),
                            const SizedBox(height: 12),
                            _buildDetailedIndicatorCard(
                              context,
                              "TNX",
                              "10-Year Yield",
                              assessment.indicators.tnx,
                              "Rising yields often pressure high-growth stocks and equities.",
                            ),
                            const SizedBox(height: 12),
                            _buildDetailedIndicatorCard(
                              context,
                              "SPY",
                              "S&P 500 Trend",
                              assessment.indicators.marketTrend,
                              "The primary benchmark. trading above 200 SMA indicates a long-term uptrend.",
                            ),
                            if (assessment.indicators.yieldCurve != null) ...[
                              const SizedBox(height: 12),
                              _buildDetailedIndicatorCard(
                                context,
                                "US10Y-TR13W",
                                "Yield Curve",
                                assessment.indicators.yieldCurve!,
                                "Spread between 10yr and 13wk yields. Inversion (<0) is a strong recession signal.",
                              )
                            ],
                            if (assessment.indicators.gold != null) ...[
                              const SizedBox(height: 12),
                              _buildDetailedIndicatorCard(
                                context,
                                "GLD",
                                "Gold Trend",
                                assessment.indicators.gold!,
                                "Safe haven asset. Rising Gold often signals risk aversion or inflation hedging.",
                              )
                            ],
                            if (assessment.indicators.oil != null) ...[
                              const SizedBox(height: 12),
                              _buildDetailedIndicatorCard(
                                context,
                                "USO",
                                "Oil Trend",
                                assessment.indicators.oil!,
                                "Energy prices impact inflation expectations and consumer spending power.",
                              )
                            ],
                            if (assessment.indicators.dxy != null) ...[
                              const SizedBox(height: 12),
                              _buildDetailedIndicatorCard(
                                context,
                                "DXY",
                                "Dollar Index",
                                assessment.indicators.dxy!,
                                "Strength of USD. Strong dollar can be a headwind for equities and international earnings.",
                              )
                            ],
                            if (assessment.indicators.btc != null) ...[
                              const SizedBox(height: 12),
                              _buildDetailedIndicatorCard(
                                context,
                                "BTC",
                                "Bitcoin Risk",
                                assessment.indicators.btc!,
                                "Risk appetite proxy. Bitcoin strength often correlates with high speculative interest in markets.",
                              )
                            ],
                            if (assessment.indicators.hyg != null) ...[
                              const SizedBox(height: 12),
                              _buildDetailedIndicatorCard(
                                context,
                                "HYG",
                                "Credit Health",
                                assessment.indicators.hyg!,
                                "High Yield Bond ETF. Rising trend indicates healthy credit markets and risk appetite.",
                              )
                            ],
                            if (assessment.indicators.putCallRatio != null) ...[
                              const SizedBox(height: 12),
                              _buildDetailedIndicatorCard(
                                context,
                                "PCCR",
                                "Put/Call Ratio",
                                assessment.indicators.putCallRatio!,
                                "Equity Put/Call ratio. Extreme high values (>1.0) suggest panic (Bullish), extreme low (<0.7) suggest greed (Bearish).",
                              )
                            ],
                            if (assessment.indicators.advDecline != null) ...[
                              const SizedBox(height: 12),
                              _buildDetailedIndicatorCard(
                                context,
                                "NYA",
                                "Broad Market",
                                assessment.indicators.advDecline!,
                                "NYSE Composite Index. Monitors broad market participate beyond just the S&P 500.",
                              )
                            ],
                            if (assessment.indicators.riskAppetite != null) ...[
                              const SizedBox(height: 12),
                              _buildDetailedIndicatorCard(
                                context,
                                "RISK",
                                "Risk Appetite",
                                assessment.indicators.riskAppetite!,
                                "Ratio of Small Caps (IWM) vs S&P 500 (SPY). Rising ratio signals high risk tolerance.",
                              )
                            ],
                          ],
                        ),
                        if (assessment.sectorRotation != null) ...[
                          const SizedBox(height: 24),
                          Text(
                            "Sector Rotation",
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildSectorCard(
                                  context,
                                  "Favored",
                                  assessment.sectorRotation!.bullish,
                                  Colors.green,
                                  Icons.trending_up,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSectorCard(
                                  context,
                                  "Avoid",
                                  assessment.sectorRotation!.bearish,
                                  Colors.red,
                                  Icons.trending_down,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (assessment.assetAllocation != null) ...[
                          const SizedBox(height: 24),
                          Text(
                            "Strategic Allocation",
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          _buildAllocationCard(
                              context, assessment.assetAllocation!),
                        ],
                        const SizedBox(height: 24),
                        Text(
                          "Detailed Analysis",
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        SelectionArea(
                          child: MarkdownBody(
                            data: assessment.reason,
                            styleSheet: MarkdownStyleSheet(
                              p: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(height: 1.5),
                              h1: Theme.of(context).textTheme.headlineMedium,
                              h2: Theme.of(context).textTheme.headlineSmall,
                              h3: Theme.of(context).textTheme.titleLarge,
                              listBullet: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        Center(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Done"),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              );
            });
      },
    );
  }

  Widget _buildDetailedIndicatorCard(BuildContext context, String symbol,
      String name, MacroIndicator indicator, String description) {
    final color = indicator.signal == 'BULLISH'
        ? Colors.green
        : indicator.signal == 'BEARISH'
            ? Colors.red
            : Colors.amber;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: Text(
                      symbol,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: Theme.of(context).textTheme.titleSmall),
                      Text(
                        indicator.trend,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                colorScheme.onSurface.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    indicator.value?.toStringAsFixed(2) ?? '--',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4)),
                    child: Text(indicator.signal,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: color)),
                  )
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.85),
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllocationCard(
      BuildContext context, AssetAllocation allocation) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildAllocationItem(context, "Equity", allocation.equity,
              Colors.blue, Icons.pie_chart),
          _buildAllocationItem(context, "Fixed Inc", allocation.fixedIncome,
              Colors.purple, Icons.account_balance),
          _buildAllocationItem(context, "Cash", allocation.cash, Colors.green,
              Icons.attach_money),
          _buildAllocationItem(context, "Cmdty", allocation.commodities,
              Colors.orange, Icons.landscape),
        ],
      ),
    );
  }

  Widget _buildAllocationItem(BuildContext context, String title, String value,
      Color color, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(
          title,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildSectorCard(BuildContext context, String title,
      List<String> sectors, Color color, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (sectors.isEmpty)
            Text(
              "None",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6)),
            )
          else
            ...sectors.map((sector) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colorScheme.onSurface.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          sector,
                          style: Theme.of(context).textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  String _getStrategyImplication(String status) {
    switch (status) {
      case 'RISK_ON':
        return "Conditions favor growth and momentum. Consider increasing equity exposure or using defined-risk bullish strategies.";
      case 'RISK_OFF':
        return "Defensive posture recommended. Consider hedging, reducing position sizes, or focusing on high-quality assets.";
      default:
        return "Conflicting signals detected. Exercise caution and wait for a clear trend or focus on non-correlated strategies.";
    }
  }

  Widget _buildIndicators(MacroAssessment assessment, BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Expanded(
                child: _buildIndicatorItem(
                    context,
                    'VIX',
                    assessment.indicators.vix.value,
                    assessment.indicators.vix.signal,
                    assessment.indicators.vix.trend)),
            const SizedBox(width: 8),
            Expanded(
                child: _buildIndicatorItem(
                    context,
                    'TNX',
                    assessment.indicators.tnx.value,
                    assessment.indicators.tnx.signal,
                    assessment.indicators.tnx.trend)),
            const SizedBox(width: 8),
            Expanded(
                child: _buildIndicatorItem(
                    context,
                    'SPY',
                    assessment.indicators.marketTrend.value,
                    assessment.indicators.marketTrend.signal,
                    assessment.indicators.marketTrend.trend)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (assessment.indicators.yieldCurve != null) ...[
              Expanded(
                  child: _buildIndicatorItem(
                      context,
                      'Curve',
                      assessment.indicators.yieldCurve!.value,
                      assessment.indicators.yieldCurve!.signal,
                      assessment.indicators.yieldCurve!.trend)),
              const SizedBox(width: 8),
            ],
            if (assessment.indicators.gold != null) ...[
              Expanded(
                  child: _buildIndicatorItem(
                      context,
                      'Gold',
                      assessment.indicators.gold!.value,
                      assessment.indicators.gold!.signal,
                      assessment.indicators.gold!.trend)),
              const SizedBox(width: 8),
            ],
            if (assessment.indicators.oil != null) ...[
              Expanded(
                  child: _buildIndicatorItem(
                      context,
                      'Oil',
                      assessment.indicators.oil!.value,
                      assessment.indicators.oil!.signal,
                      assessment.indicators.oil!.trend)),
            ],
            // Filler if needed to align grids
            if (assessment.indicators.gold == null &&
                assessment.indicators.oil == null) ...[
              const Spacer(),
              const SizedBox(width: 8),
              const Spacer(),
            ] else if (assessment.indicators.oil == null) ...[
              const Spacer(),
            ]
          ],
        ),
        if (assessment.indicators.dxy != null ||
            assessment.indicators.btc != null ||
            assessment.indicators.hyg != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              if (assessment.indicators.dxy != null) ...[
                Expanded(
                    child: _buildIndicatorItem(
                        context,
                        'DXY',
                        assessment.indicators.dxy!.value,
                        assessment.indicators.dxy!.signal,
                        assessment.indicators.dxy!.trend)),
                const SizedBox(width: 8),
              ] else ...[
                const Spacer(),
                const SizedBox(width: 8),
              ],
              if (assessment.indicators.btc != null) ...[
                Expanded(
                    child: _buildIndicatorItem(
                        context,
                        'BTC',
                        assessment.indicators.btc!.value,
                        assessment.indicators.btc!.signal,
                        assessment.indicators.btc!.trend)),
                const SizedBox(width: 8),
              ] else ...[
                const Spacer(),
                const SizedBox(width: 8),
              ],
              if (assessment.indicators.hyg != null) ...[
                Expanded(
                    child: _buildIndicatorItem(
                        context,
                        'HYG',
                        assessment.indicators.hyg!.value,
                        assessment.indicators.hyg!.signal,
                        assessment.indicators.hyg!.trend)),
              ] else ...[
                const Spacer(),
              ]
            ],
          ),
        ],
        if (assessment.indicators.putCallRatio != null ||
            assessment.indicators.advDecline != null ||
            assessment.indicators.riskAppetite != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              if (assessment.indicators.putCallRatio != null) ...[
                Expanded(
                    child: _buildIndicatorItem(
                        context,
                        'PCCR',
                        assessment.indicators.putCallRatio!.value,
                        assessment.indicators.putCallRatio!.signal,
                        assessment.indicators.putCallRatio!.trend)),
                const SizedBox(width: 8),
              ] else ...[
                const Spacer(),
                const SizedBox(width: 8),
              ],
              if (assessment.indicators.advDecline != null) ...[
                Expanded(
                    child: _buildIndicatorItem(
                        context,
                        'NYA',
                        assessment.indicators.advDecline!.value,
                        assessment.indicators.advDecline!.signal,
                        assessment.indicators.advDecline!.trend)),
                const SizedBox(width: 8),
              ] else ...[
                const Spacer(),
                const SizedBox(width: 8),
              ],
              if (assessment.indicators.riskAppetite != null) ...[
                Expanded(
                    child: _buildIndicatorItem(
                        context,
                        'RISK',
                        assessment.indicators.riskAppetite!.value,
                        assessment.indicators.riskAppetite!.signal,
                        assessment.indicators.riskAppetite!.trend)),
              ] else ...[
                const Spacer(),
              ]
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildIndicatorItem(BuildContext context, String label, double? value,
      String signal, String trend) {
    final color = signal == 'BULLISH'
        ? Colors.green
        : signal == 'BEARISH'
            ? Colors.red
            : Colors.amber;
    final colorScheme = Theme.of(context).colorScheme;

    final valueStr = value != null ? value.toStringAsFixed(2) : '--';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            valueStr,
            style: TextStyle(
                color: color, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4)),
            child: Text(
              signal,
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    }

    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final timeStr =
        "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    return isToday ? timeStr : "${date.month}/${date.day} $timeStr";
  }

  Widget _buildScoreTrendIcon(
      double current, double previous, BuildContext context) {
    final diff = current - previous;
    if (diff == 0) return const SizedBox.shrink();

    final isUp = diff > 0;
    final color = isUp ? Colors.green : Colors.red;
    final icon = isUp ? Icons.trending_up : Icons.trending_down;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(
          '${diff > 0 ? '+' : ''}${diff.toInt()}',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
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

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      0.75 * math.pi, // Start at bottom-left
      1.5 * math.pi, // 270 degree arc
      false,
      bgPaint,
    );

    // Progress Arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    // Normalize score to 0..1 then to radians
    final sweepAngle = (score / 100) * 1.5 * math.pi;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      0.75 * math.pi,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _MacroScoreGaugePainter oldDelegate) {
    return oldDelegate.score != score || oldDelegate.color != color;
  }
}
