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
import 'package:robinhood_options_mobile/widgets/delta_neutral_builder_widget.dart';
import 'package:robinhood_options_mobile/widgets/earnings_iv_crush_widget.dart';
import 'package:robinhood_options_mobile/widgets/persistent_header.dart';

/// Full-page / sheet modal dashboard for the Autonomous Agentic Risk Copilot.
class RiskCopilotWidget extends StatefulWidget {
  final User? user;
  final BrokerageUser? brokerageUser;
  final IBrokerageService? service;
  final List<InstrumentPosition> instrumentPositions;
  final List<OptionAggregatePosition> optionPositions;
  final double? totalEquity;
  final List<EarningsCalendarEvent>? earningsCalendarEvents;
  final List<EarningsIvCrushAnalysis>? earningsCrushAnalyses;
  final List<DeltaNeutralAnalysis>? deltaNeutralAnalyses;
  final RiskCopilotReport? precomputedReport;

  const RiskCopilotWidget({
    super.key,
    this.user,
    this.brokerageUser,
    this.service,
    this.instrumentPositions = const [],
    this.optionPositions = const [],
    this.totalEquity,
    this.earningsCalendarEvents,
    this.earningsCrushAnalyses,
    this.deltaNeutralAnalyses,
    this.precomputedReport,
  });

  @override
  State<RiskCopilotWidget> createState() => _RiskCopilotWidgetState();
}

class _RiskCopilotWidgetState extends State<RiskCopilotWidget>
    with SingleTickerProviderStateMixin {
  static final _currency = NumberFormat.simpleCurrency(decimalDigits: 0);
  late TabController _tabController;
  late RiskCopilotReport _report;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _generateReport();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _generateReport() {
    if (widget.precomputedReport != null) {
      _report = widget.precomputedReport!;
    } else {
      _report = RiskCopilotService.evaluateRiskReport(
        instrumentPositions: widget.instrumentPositions,
        optionPositions: widget.optionPositions,
        totalEquity: widget.totalEquity,
        earningsCalendarEvents: widget.earningsCalendarEvents,
        earningsCrushAnalyses: widget.earningsCrushAnalyses,
        deltaNeutralAnalyses: widget.deltaNeutralAnalyses,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final severityColor = _report.overallSeverity.color(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Autonomous Risk Copilot'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Recalculate Copilot Risk',
            onPressed: () {
              setState(() {
                _report = RiskCopilotService.evaluateRiskReport(
                  instrumentPositions: widget.instrumentPositions,
                  optionPositions: widget.optionPositions,
                  totalEquity: widget.totalEquity,
                  earningsCalendarEvents: widget.earningsCalendarEvents,
                  earningsCrushAnalyses: widget.earningsCrushAnalyses,
                  deltaNeutralAnalyses: widget.deltaNeutralAnalyses,
                );
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Risk Copilot analysis refreshed.'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // 1. Executive Summary & Score Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: severityColor.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: severityColor.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _report.overallSeverity == RiskCopilotSeverity.normal
                                  ? Icons.shield_outlined
                                  : Icons.warning_amber_rounded,
                              color: severityColor,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _report.statusHeadline,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Safety Score: ${_report.overallScore.toStringAsFixed(0)} / 100 · ${_report.overallSeverity.label}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: severityColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _report.summary,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // 3 Summary stats
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricPill(
                              context,
                              label: 'Overnight Gap',
                              value: _report.totalOvernightGapExposure > 0
                                  ? '-${_currency.format(_report.totalOvernightGapExposure)}'
                                  : '\$0',
                              color: _report.totalOvernightGapExposure > 1000
                                  ? Colors.orange
                                  : theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildMetricPill(
                              context,
                              label: 'Earnings Hazard',
                              value: '${_report.earningsHazards.length} Held',
                              color: _report.hasImminentEarnings
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildMetricPill(
                              context,
                              label: 'Portfolio Delta',
                              value:
                                  '${_report.portfolioNetDelta >= 0 ? '+' : ''}${_report.portfolioNetDelta.toStringAsFixed(1)} Δ',
                              color: _report.portfolioNetDelta.abs() > 50
                                  ? Colors.orange
                                  : Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 2. Prioritized Action Checklist
          if (_report.topMitigations.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.checklist_rounded,
                            size: 20, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Prioritized Mitigations',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._report.topMitigations
                        .map((m) => _buildMitigationItem(context, m)),
                  ],
                ),
              ),
            ),

          // 3. Pinned Tab Bar for Vector Drill-downs
          SliverPersistentHeader(
            pinned: true,
            delegate: PersistentHeader(
              '',
              size: 72.0,
              widget: Material(
                color: theme.scaffoldBackgroundColor,
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    tabs: [
                      Tab(
                        text: 'Overnight (${_report.gapRisks.length})',
                        icon: const Icon(Icons.nightlight_round, size: 18),
                      ),
                      Tab(
                        text: 'Earnings (${_report.earningsHazards.length})',
                        icon: const Icon(Icons.event_note_rounded, size: 18),
                      ),
                      Tab(
                        text: 'Delta Hedges (${_report.deltaHedges.length})',
                        icon: const Icon(Icons.tune_rounded, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildGapRisksTab(context),
            _buildEarningsTab(context),
            _buildDeltaHedgesTab(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricPill(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
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

  Widget _buildMitigationItem(
    BuildContext context,
    RiskCopilotMitigationAction mitigation,
  ) {
    final theme = Theme.of(context);
    final color = mitigation.severity.color(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.shield_outlined, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mitigation.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mitigation.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => _handleMitigationAction(mitigation),
              style: TextButton.styleFrom(
                foregroundColor: color,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(mitigation.actionLabel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGapRisksTab(BuildContext context) {
    final theme = Theme.of(context);
    if (_report.gapRisks.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        children: [
          const SizedBox(height: 48),
          const Icon(Icons.check_circle_outline, size: 48, color: Colors.green),
          const SizedBox(height: 12),
          Text(
            'No Overnight Gap Hazards',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'All open positions are within safe volatility limits.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _report.gapRisks.length,
      itemBuilder: (context, index) {
        final gap = _report.gapRisks[index];
        final color = gap.severity.color(context);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          gap.symbol,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (gap.isLeveragedOrVolatile) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('LEVERAGED',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange)),
                          ),
                        ],
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        gap.severity.label,
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  gap.warningMessage,
                  style: theme.textTheme.bodyMedium,
                ),
                const Divider(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Potential Gap Loss:',
                        style: theme.textTheme.bodySmall),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '-${_currency.format(gap.potentialDollarLoss)} (${(gap.estimatedGapPercent * 100).toStringAsFixed(1)}%)',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Beta (β):', style: theme.textTheme.bodySmall),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        gap.beta.toStringAsFixed(2),
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline_rounded,
                          size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          gap.mitigationAction,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEarningsTab(BuildContext context) {
    final theme = Theme.of(context);
    if (_report.earningsHazards.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        children: [
          const SizedBox(height: 48),
          const Icon(Icons.event_available, size: 48, color: Colors.green),
          const SizedBox(height: 12),
          Text(
            'No Imminent Earnings Hazards',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'None of your held symbols report earnings in the next 7 days.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _report.earningsHazards.length,
      itemBuilder: (context, index) {
        final eh = _report.earningsHazards[index];
        final color = eh.severity.color(context);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      eh.symbol,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        eh.daysUntilEarnings == 0
                            ? 'TODAY'
                            : (eh.daysUntilEarnings == 1
                                ? 'TOMORROW'
                                : 'IN ${eh.daysUntilEarnings} DAYS'),
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    eh.hazardType.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(eh.warningMessage, style: theme.textTheme.bodyMedium),
                const Divider(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Implied Move:', style: theme.textTheme.bodySmall),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '±${(eh.expectedMovePercent * 100).toStringAsFixed(1)}%',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('IV Crush Probability:',
                        style: theme.textTheme.bodySmall),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${(eh.crushProbability * 100).toStringAsFixed(0)}%',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonal(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EarningsIvCrushWidget(
                            symbol: eh.symbol,
                            user: widget.user,
                            brokerageUser: widget.brokerageUser,
                            service: widget.service,
                          ),
                        ),
                      );
                    },
                    child: const Text('Analyze IV Crush'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeltaHedgesTab(BuildContext context) {
    final theme = Theme.of(context);
    if (_report.deltaHedges.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        children: [
          const SizedBox(height: 48),
          const Icon(Icons.balance_rounded, size: 48, color: Colors.green),
          const SizedBox(height: 12),
          Text(
            'Portfolio Delta Balanced',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'All open positions are within delta-neutral tolerance bands.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _report.deltaHedges.length,
      itemBuilder: (context, index) {
        final dh = _report.deltaHedges[index];
        final color = dh.severity.color(context);
        final deltaSign = dh.netDelta >= 0 ? '+' : '';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      dh.symbol,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$deltaSign${dh.netDelta.toStringAsFixed(1)} Δ',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  dh.hedgeRationale,
                  style: theme.textTheme.bodyMedium,
                ),
                const Divider(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Move per 1% Shift:',
                        style: theme.textTheme.bodySmall),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${dh.dollarDeltaPerOnePercent >= 0 ? '+' : ''}${_currency.format(dh.dollarDeltaPerOnePercent)}',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Recommended Option Hedge:',
                        style: theme.textTheme.bodySmall),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        dh.suggestedOptionHedge,
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonal(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DeltaNeutralBuilderWidget(
                            symbol: dh.symbol,
                            user: widget.user,
                            brokerageUser: widget.brokerageUser,
                            service: widget.service,
                          ),
                        ),
                      );
                    },
                    child: const Text('Open Delta Neutral Builder'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleMitigationAction(RiskCopilotMitigationAction mitigation) {
    if (mitigation.targetRoute == 'delta_neutral') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DeltaNeutralBuilderWidget(
            symbol: mitigation.symbol,
            user: widget.user,
            brokerageUser: widget.brokerageUser,
            service: widget.service,
          ),
        ),
      );
    } else if (mitigation.targetRoute == 'earnings_crush') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EarningsIvCrushWidget(
            symbol: mitigation.symbol,
            user: widget.user,
            brokerageUser: widget.brokerageUser,
            service: widget.service,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${mitigation.symbol}: ${mitigation.actionLabel}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
