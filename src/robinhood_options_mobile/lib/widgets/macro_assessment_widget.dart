import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/model/macro_assessment.dart';

class MacroAssessmentWidget extends StatefulWidget {
  const MacroAssessmentWidget({super.key});

  @override
  State<MacroAssessmentWidget> createState() => _MacroAssessmentWidgetState();
}

class _MacroAssessmentWidgetState extends State<MacroAssessmentWidget> {
  @override
  void initState() {
    super.initState();
    // Fetch on init if not already fetched
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AgenticTradingProvider>(context, listen: false)
          .fetchMacroAssessment();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AgenticTradingProvider>(context);
    final assessment = provider.macroAssessment;
    final colorScheme = Theme.of(context).colorScheme;

    if (assessment == null) {
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

    final statusColor = assessment.status == 'RISK_ON'
        ? Colors.green
        : assessment.status == 'RISK_OFF'
            ? Colors.red
            : Colors.amber;

    return Card(
      elevation: 4,
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
                      Text(
                        '${assessment.score}/100',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
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
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            _buildIndicators(assessment, context),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Last updated: ${_formatDate(assessment.timestamp)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicators(MacroAssessment assessment, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildIndicatorItem(
            context,
            'VIX (Fear)',
            assessment.indicators.vix.value,
            assessment.indicators.vix.signal,
            assessment.indicators.vix.trend),
        _buildIndicatorItem(
            context,
            'TNX (Yields)',
            assessment.indicators.tnx.value,
            assessment.indicators.tnx.signal,
            assessment.indicators.tnx.trend),
        _buildIndicatorItem(
            context,
            'SPY (Trend)',
            assessment.indicators.marketTrend.value,
            assessment.indicators.marketTrend.signal,
            assessment.indicators.marketTrend.trend),
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

    final valueStr = value != null ? value.toStringAsFixed(2) : '--';

    return Column(
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          valueStr,
          style: TextStyle(
              color: color, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
              trend.contains("Rising") ||
                      trend.contains("Above") ||
                      trend.contains("Up")
                  ? Icons.trending_up
                  : trend.contains("Falling") ||
                          trend.contains("Below") ||
                          trend.contains("Down")
                      ? Icons.trending_down
                      : Icons.trending_flat,
              size: 14,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6)),
          const SizedBox(width: 4),
          Text(
            trend,
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
          ),
        ]),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }
}
