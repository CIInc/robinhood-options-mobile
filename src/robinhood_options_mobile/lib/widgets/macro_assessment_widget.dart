import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/macro_assessment.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/widgets/macro_assessment_dashboard_widget.dart';

class MacroAssessmentWidget extends StatefulWidget {
  final User? user;
  final DocumentReference<User>? userDocRef;
  final BrokerageUser? brokerageUser;

  const MacroAssessmentWidget({
    super.key,
    this.user,
    this.userDocRef,
    this.brokerageUser,
  });

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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MacroAssessmentDashboardWidget(
          user: widget.user,
          userDocRef: widget.userDocRef,
          brokerageUser: widget.brokerageUser,
        ),
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
                Icons.show_chart_rounded,
                unit: '\$')),
      ],
    );
  }

  Widget _buildIndicatorItem(BuildContext context, String label, double? value,
      String signal, String trend, IconData icon,
      {String? unit}) {
    final color = _getStatusColor(context, signal);
    final colorScheme = Theme.of(context).colorScheme;

    final valueStr = value != null
        ? (unit == '\$'
            ? '\$${value.toStringAsFixed(2)}'
            : "${value.toStringAsFixed(2)}${unit ?? ''}")
        : '--';

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

  Color _getStatusColor(BuildContext context, String? status) {
    status = status?.toUpperCase();
    final isLight = Theme.of(context).brightness == Brightness.light;
    if (status == 'RISK_ON' || status == 'BULLISH') {
      return isLight ? Colors.green.shade700 : Colors.green;
    } else if (status == 'RISK_OFF' || status == 'BEARISH') {
      return isLight ? Colors.red.shade700 : Colors.red;
    } else {
      return isLight ? Colors.orange.shade800 : Colors.amber;
    }
  }
}
