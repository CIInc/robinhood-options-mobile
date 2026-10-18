import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/delta_neutral_model.dart';
import 'package:robinhood_options_mobile/model/earnings_calendar_event.dart';
import 'package:robinhood_options_mobile/model/earnings_iv_crush_model.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/risk_copilot_model.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/risk_copilot_service.dart';
import 'package:robinhood_options_mobile/widgets/analytics_style_card.dart';
import 'package:robinhood_options_mobile/widgets/risk_copilot_widget.dart';

/// Progressive-disclosure overview card for the Autonomous Agentic Risk Copilot.
/// Embedded directly into the Portfolio Risk section.
class AgenticRiskCopilotCard extends StatelessWidget {
  static final _currency = NumberFormat.simpleCurrency(decimalDigits: 0);

  final List<InstrumentPosition> positions;
  final List<OptionAggregatePosition> optionPositions;
  final double? totalEquity;
  final List<EarningsCalendarEvent>? earningsCalendarEvents;
  final List<EarningsIvCrushAnalysis>? earningsCrushAnalyses;
  final List<DeltaNeutralAnalysis>? deltaNeutralAnalyses;
  final RiskCopilotReport? precomputedReport;
  final User? user;
  final BrokerageUser? brokerageUser;
  final IBrokerageService? service;
  final VoidCallback? onTap;

  const AgenticRiskCopilotCard({
    super.key,
    required this.positions,
    required this.optionPositions,
    this.totalEquity,
    this.earningsCalendarEvents,
    this.earningsCrushAnalyses,
    this.deltaNeutralAnalyses,
    this.precomputedReport,
    this.user,
    this.brokerageUser,
    this.service,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final report = precomputedReport ??
        RiskCopilotService.evaluateRiskReport(
          instrumentPositions: positions,
          optionPositions: optionPositions,
          totalEquity: totalEquity,
          earningsCalendarEvents: earningsCalendarEvents,
          earningsCrushAnalyses: earningsCrushAnalyses,
          deltaNeutralAnalyses: deltaNeutralAnalyses,
        );

    final theme = Theme.of(context);
    final severityColor = report.overallSeverity.color(context);

    return AnalyticsStyleCard(
      onTap: onTap ?? () => _openCopilotDetails(context, report),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: severityColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  report.overallSeverity == RiskCopilotSeverity.normal
                      ? Icons.shield_outlined
                      : Icons.psychology_alt_outlined,
                  color: severityColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Autonomous Risk Copilot',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        )),
                    const SizedBox(height: 1),
                    Text('Overnight gap, earnings hazards & delta hedge monitor',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        )),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: severityColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${report.overallScore.toStringAsFixed(0)}/100 · ${report.overallSeverity.label}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: severityColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3 Metric Pills
          Row(
            children: [
              Expanded(
                child: _buildTile(
                  context,
                  title: 'Overnight Gap',
                  value: report.totalOvernightGapExposure > 0
                      ? '-${_currency.format(report.totalOvernightGapExposure)}'
                      : '\$0',
                  color: report.totalOvernightGapExposure > 1000
                      ? Colors.orange
                      : theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTile(
                  context,
                  title: 'Earnings Hazard',
                  value: '${report.earningsHazards.length} Held',
                  color: report.hasImminentEarnings
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTile(
                  context,
                  title: 'Net Delta',
                  value:
                      '${report.portfolioNetDelta >= 0 ? '+' : ''}${report.portfolioNetDelta.toStringAsFixed(1)} Δ',
                  color: report.portfolioNetDelta.abs() > 40
                      ? Colors.orange
                      : Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Headline or Top Mitigation
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: severityColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: severityColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(
                  report.overallSeverity == RiskCopilotSeverity.normal
                      ? Icons.check_circle_outline
                      : Icons.warning_amber_rounded,
                  size: 18,
                  color: severityColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    report.topMitigations.isNotEmpty
                        ? report.topMitigations.first.title
                        : report.statusHeadline,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right,
                    size: 18, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required String title,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _openCopilotDetails(BuildContext context, RiskCopilotReport report) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RiskCopilotWidget(
          user: user,
          brokerageUser: brokerageUser,
          service: service,
          instrumentPositions: positions,
          optionPositions: optionPositions,
          totalEquity: totalEquity,
          earningsCalendarEvents: earningsCalendarEvents,
          earningsCrushAnalyses: earningsCrushAnalyses,
          deltaNeutralAnalyses: deltaNeutralAnalyses,
          precomputedReport: report,
        ),
      ),
    );
  }
}
