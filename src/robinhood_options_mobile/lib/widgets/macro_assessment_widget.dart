import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
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

    final statusColor = _getStatusColor(context, assessment.status);

    return Card(
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: () => _showDetails(context, assessment),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                statusColor.withValues(alpha: 0.15),
                colorScheme.surface,
              ],
            ),
          ),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.public, color: statusColor, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Macro Market State',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              if (provider.previousMacroAssessment != null &&
                                  provider.previousMacroAssessment!.status !=
                                      assessment.status) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'SHIFT',
                                    style: TextStyle(
                                      color: colorScheme.onPrimary,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            'Global Risk Assessment',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
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
                          border: Border.all(
                              color: statusColor.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          assessment.status,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
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
                          'Macro Score',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '${assessment.score.toInt()}',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineLarge
                                  ?.copyWith(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            Text(
                              '/100',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.4),
                                  ),
                            ),
                            if (provider.previousMacroAssessment != null) ...[
                              const SizedBox(width: 12),
                              _buildScoreTrendIcon(
                                  assessment.score.toDouble(),
                                  provider.previousMacroAssessment!.score
                                      .toDouble(),
                                  context),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.only(right: 24.0),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                                begin: 0, end: assessment.score / 100.0),
                            duration: const Duration(milliseconds: 1000),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) {
                              return LinearProgressIndicator(
                                value: value,
                                backgroundColor:
                                    statusColor.withValues(alpha: 0.1),
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(statusColor),
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(4),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: colorScheme.outline.withValues(alpha: 0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.lightbulb_outline,
                                  size: 14, color: colorScheme.primary),
                              const SizedBox(width: 4),
                              Text(
                                'Guidance',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 70),
                            child: Text(
                              _getStrategyImplication(assessment.status),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    // fontStyle: FontStyle.italic,
                                    height: 1.3,
                                    fontSize: 11,
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.8),
                                  ),
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              _buildIndicators(assessment, context),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () => _fetchAssessment(),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Row(
                        children: [
                          Icon(Icons.sync,
                              size: 14, color: colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            "Refresh",
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Update: ${_formatDate(assessment.timestamp)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color:
                                  colorScheme.onSurface.withValues(alpha: 0.4),
                              fontSize: 10,
                            ),
                      ),
                      Text(
                        'Next Review: 4:00 PM ET',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color:
                                  colorScheme.onSurface.withValues(alpha: 0.25),
                              fontSize: 8,
                              fontWeight: FontWeight.w300,
                            ),
                      ),
                    ],
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
                            onPressed: () => _showAboutDialog(context)),
                      ],
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      children: [
                        // Summary Card
                        _buildSummarySection(context, assessment),
                        const SizedBox(height: 16),

                        // Recent Changes (if any)
                        if (Provider.of<AgenticTradingProvider>(context)
                                .previousMacroAssessment !=
                            null) ...[
                          _buildRecentChangesSection(
                              context,
                              assessment,
                              Provider.of<AgenticTradingProvider>(context)
                                  .previousMacroAssessment!),
                          const SizedBox(height: 24),
                        ],

                        // Indicators Heatmap
                        Text(
                          "Indicators Pulse",
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        _buildIndicatorHeatmap(context, assessment),
                        const SizedBox(height: 24),

                        // Score History Chart
                        if (Provider.of<AgenticTradingProvider>(context)
                            .macroHistory
                            .isNotEmpty) ...[
                          Text(
                            "Score Trend",
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          _buildMacroHistoryChart(context),
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
                            _buildSectorSection(
                                context, assessment.sectorRotation!),
                            const SizedBox(height: 12),
                          ],
                          if (assessment.assetAllocation != null) ...[
                            _buildAllocationCard(
                                context, assessment.assetAllocation!),
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

                        Center(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 32, vertical: 12),
                            ),
                            child: const Text("Close Dashboard"),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              );
            });
      },
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
          "Fear gauge. Levels below 20 are constructive for stocks.",
          Icons.warning_amber_rounded,
        ),
        const SizedBox(height: 12),
        _buildDetailedIndicatorCard(
          context,
          "TNX",
          "10-Year Yield",
          assessment.indicators.tnx,
          "Risk-free rate. High yields lower equity valuation multiples (P/E ratios).",
          Icons.account_balance_rounded,
          unit: '%',
        ),
        const SizedBox(height: 12),
        _buildDetailedIndicatorCard(
          context,
          "SPY",
          "Market Trend",
          assessment.indicators.marketTrend,
          "Broad market trend. Performance relative to 200-day moving average.",
          Icons.show_chart_rounded,
        ),
        if (assessment.indicators.yieldCurve != null) ...[
          const SizedBox(height: 12),
          _buildDetailedIndicatorCard(
            context,
            "CURV",
            "Yield Curve",
            assessment.indicators.yieldCurve!,
            "Bond market growth expectations. Inverted (negative) values are a primary recession warning.",
            Icons.insights_rounded,
          ),
        ],
        if (assessment.indicators.putCallRatio != null) ...[
          const SizedBox(height: 12),
          _buildDetailedIndicatorCard(
            context,
            "PCCR",
            "Put/Call Ratio",
            assessment.indicators.putCallRatio!,
            "Sentiment. Extremes often act as contrarian signals.",
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
            "Speculative demand. Often correlates with high-beta equity interest.",
            Icons.currency_bitcoin_rounded,
          ),
        ],
        if (assessment.indicators.hyg != null) ...[
          const SizedBox(height: 12),
          _buildDetailedIndicatorCard(
            context,
            "HYG",
            "Credit Health",
            assessment.indicators.hyg!,
            "High-yield corporate bonds. Strength indicates robust credit markets.",
            Icons.credit_card_rounded,
          ),
        ],
        if (assessment.indicators.dxy != null) ...[
          const SizedBox(height: 12),
          _buildDetailedIndicatorCard(
            context,
            "DXY",
            "U.S. Dollar Index",
            assessment.indicators.dxy!,
            "Currency strength. A rising dollar often pressures international earnings.",
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
            "Inflation hedge. Often moves inversely to risk appetite in extreme volatility.",
            Icons.monetization_on_rounded,
          ),
        ],
        if (assessment.indicators.oil != null) ...[
          const SizedBox(height: 12),
          _buildDetailedIndicatorCard(
            context,
            "OIL",
            "Energy & Inflation",
            assessment.indicators.oil!,
            "Commodity prices. Rapidly rising energy costs can act as a tax on consumers.",
            Icons.oil_barrel_rounded,
          ),
        ],
        if (assessment.indicators.advDecline != null) ...[
          const SizedBox(height: 12),
          _buildDetailedIndicatorCard(
            context,
            "NYA",
            "Market Breadth",
            assessment.indicators.advDecline!,
            "NYSE Composite. Measures the performance of all common stocks on the exchange.",
            Icons.grid_view_rounded,
          ),
        ],
        if (assessment.indicators.riskAppetite != null) ...[
          const SizedBox(height: 12),
          _buildDetailedIndicatorCard(
            context,
            "IWM",
            "Small Caps",
            assessment.indicators.riskAppetite!,
            "Russell 2000. Strength in small caps indicates broad-based risk appetite.",
            Icons.rocket_launch_rounded,
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
                  Text('Current Regime',
                      style: Theme.of(context).textTheme.titleSmall),
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
                  Text('Macro Score',
                      style: Theme.of(context).textTheme.titleSmall),
                  Text(
                    '${assessment.score}/100',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w900,
                        ),
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
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Confidence Meter
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shield_moon,
                            size: 16, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Assessment Confidence',
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                        ),
                      ],
                    ),
                    Text(
                      '${assessment.confidence}%',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _getConfidenceColor(assessment.confidence),
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: assessment.confidence / 100,
                    minHeight: 6,
                    backgroundColor: colorScheme.outline.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getConfidenceColor(assessment.confidence),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Signal Divergence
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Signal Alignment',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: _buildSignalBar(
                                  'Bullish',
                                  assessment.signalDivergence.bullishCount,
                                  Colors.green,
                                  colorScheme,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: _buildSignalBar(
                                  'Neutral',
                                  assessment.signalDivergence.neutralCount,
                                  Colors.orange,
                                  colorScheme,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: _buildSignalBar(
                                  'Bearish',
                                  assessment.signalDivergence.bearishCount,
                                  Colors.red,
                                  colorScheme,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (assessment.signalDivergence.isConflicted) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, size: 14, color: Colors.orange),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Mixed signals detected - Monitor closely',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: Colors.orange.shade700,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSummaryGuidance(context, assessment),
        ],
      ),
    );
  }

  Widget _buildSignalBar(
      String label, int count, Color color, ColorScheme colorScheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 20,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Center(
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
              fontSize: 8, color: colorScheme.onSurface.withValues(alpha: 0.6)),
        ),
      ],
    );
  }

  Color _getConfidenceColor(int confidence) {
    if (confidence >= 80) return Colors.green;
    if (confidence >= 60) return Colors.blue;
    if (confidence >= 40) return Colors.orange;
    return Colors.red;
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

  Widget _buildDetailedIndicatorCard(BuildContext context, String symbol,
      String name, MacroIndicator indicator, String description, IconData icon,
      {String? unit}) {
    final color = _getStatusColor(context, indicator.signal);
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
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(name,
                              style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.outline.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              symbol,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        ],
                      ),
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
                    "${indicator.value?.toStringAsFixed(2) ?? '--'}${unit ?? ''}",
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
        ],
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

  Widget _buildIndicators(MacroAssessment assessment, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Expanded(
            child: _buildIndicatorItem(
                context,
                'VIX',
                assessment.indicators.vix.value,
                assessment.indicators.vix.signal,
                assessment.indicators.vix.trend,
                Icons.warning_amber_rounded)),
        const SizedBox(width: 8),
        Expanded(
            child: _buildIndicatorItem(
                context,
                'TNX',
                assessment.indicators.tnx.value,
                assessment.indicators.tnx.signal,
                assessment.indicators.tnx.trend,
                Icons.account_balance_rounded,
                unit: '%')),
        const SizedBox(width: 8),
        Expanded(
            child: _buildIndicatorItem(
                context,
                'SPY',
                assessment.indicators.marketTrend.value,
                assessment.indicators.marketTrend.signal,
                assessment.indicators.marketTrend.trend,
                Icons.show_chart_rounded)),
      ],
    );
  }

  Widget _buildIndicatorItem(BuildContext context, String label, double? value,
      String signal, String trend, IconData icon,
      {String? unit}) {
    final color = _getStatusColor(context, signal);
    final colorScheme = Theme.of(context).colorScheme;

    final valueStr =
        value != null ? "${value.toStringAsFixed(2)}${unit ?? ''}" : '--';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            valueStr,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              signal == 'BULLISH'
                  ? 'BULLISH'
                  : signal == 'BEARISH'
                      ? 'BEARISH'
                      : 'NEUTRAL',
              style: TextStyle(
                color: color,
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
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
    };

    final children = <Widget>[];
    indicatorsMap.forEach((key, value) {
      if (value != null) {
        final color = _getStatusColor(context, value.signal);
        children.add(
          Tooltip(
            message: '${value.signal}: ${value.trend}',
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.2),
                    color.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    key,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
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
                                  .toStringAsFixed(value.value! < 10 ? 2 : 0))
                          : value.value!.toStringAsFixed(2),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    width: 20,
                    height: 2,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(1),
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
      crossAxisCount: 6,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.85,
      children: children,
    );
  }

  Widget _buildMacroHistoryChart(BuildContext context) {
    final provider = Provider.of<AgenticTradingProvider>(context);
    final history = provider.macroHistory;
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

  Widget _buildScoreTrendIcon(
      double current, double previous, BuildContext context) {
    final diff = current - previous;
    if (diff == 0) return const SizedBox.shrink();

    final isUp = diff > 0;
    // For this Macro Score, higher is more Bullish (Green), lower is more Bearish (Red)
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

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;

        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.psychology,
                            color: colorScheme.primary, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Macro Analysis", style: textTheme.titleLarge),
                            Text("Methodology & Scoring",
                                style: textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  _buildAboutSection(
                    context,
                    "How it Works",
                    "This model analyzes 12 real-time market components to determine the global 'Risk Regime'. It calculates a score from 0 to 100 based on moving average trends, signal alignment, and momentum correlations.",
                  ),
                  const SizedBox(height: 24),
                  Text("Regime Definitions", style: textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _buildRegimeItem(
                      context,
                      "RISK ON",
                      "60 - 100",
                      _getStatusColor(context, "RISK_ON"),
                      "Bullish environment. Growth, technology, and speculative assets are favored. Increase position sizes."),
                  _buildRegimeItem(
                      context,
                      "NEUTRAL",
                      "41 - 59",
                      _getStatusColor(context, "NEUTRAL"),
                      "Mixed signals. Market index is often range-bound. Focus on quality, energy, and value rotation."),
                  _buildRegimeItem(
                      context,
                      "RISK OFF",
                      "0 - 40",
                      _getStatusColor(context, "RISK_OFF"),
                      "Bearish environment. High volatility and credit stress. Minimize risk exposure and focus on safe havens."),
                  const SizedBox(height: 24),
                  Text("The Four Pillars", style: textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _buildPillarItem(context, Icons.speed, "Volatility (VIX)",
                      "Measures market fear and implied stress. Rising VIX signals lower risk appetite."),
                  _buildPillarItem(context, Icons.trending_up, "Rates & Credit",
                      "TNX yields and the Yield Curve spread. Inversions and rising rates act as valuation headwinds."),
                  _buildPillarItem(
                      context,
                      Icons.grid_view_rounded,
                      "Internals & Breadth",
                      "SPY 200 SMA, NYSE Breadth, and Small Cap relative strength define trend quality."),
                  _buildPillarItem(
                      context,
                      Icons.pie_chart_rounded,
                      "Sentiment (PCR)",
                      "Put/Call ratios act as contrarian indicators for potential market tops or bottoms."),
                  const Divider(height: 48),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.all(16),
                      ),
                      child: const Text("Got it, thanks!"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAboutSection(BuildContext context, String title, String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Text(text, style: Theme.of(context).textTheme.bodyMedium),
      ],
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
    if (status == 'RISK_ON' || status == 'BULLISH') {
      return isLight ? Colors.green.shade700 : Colors.green;
    } else if (status == 'RISK_OFF' || status == 'BEARISH') {
      return isLight ? Colors.red.shade700 : Colors.red;
    } else {
      // Use orange shade 800 for light theme to improve readability as requested
      return isLight ? Colors.orange.shade800 : Colors.amber;
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

class _AllocationData {
  final String label;
  final double value;
  final Color color;

  _AllocationData(this.label, this.value, this.color);
}
