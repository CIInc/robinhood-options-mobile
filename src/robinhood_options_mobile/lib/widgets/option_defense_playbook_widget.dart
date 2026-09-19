import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_defense_models.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/option_roll_models.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/risk_circuit_breaker_service.dart';
import 'package:robinhood_options_mobile/widgets/option_roll_assistant_widget.dart';
import 'package:robinhood_options_mobile/widgets/trade_option_widget.dart';

class OptionDefensePlaybookWidget extends StatefulWidget {
  final BrokerageUser user;
  final IBrokerageService service;
  final Instrument instrument;
  final OptionAggregatePosition optionPosition;
  final OptionInstrument optionInstrument;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final GenerativeService generativeService;
  final User? appUser;
  final DocumentReference<User>? userDocRef;
  final bool initialIsPaperTrade;
  final double? underlyingCostBasis;
  final RiskCircuitBreakerService? riskCircuitBreakerService;

  const OptionDefensePlaybookWidget({
    super.key,
    required this.user,
    required this.service,
    required this.instrument,
    required this.optionPosition,
    required this.optionInstrument,
    required this.analytics,
    required this.observer,
    required this.generativeService,
    required this.appUser,
    required this.userDocRef,
    this.initialIsPaperTrade = false,
    this.underlyingCostBasis,
    this.riskCircuitBreakerService,
  });

  @override
  State<OptionDefensePlaybookWidget> createState() =>
      _OptionDefensePlaybookWidgetState();
}

class _OptionDefensePlaybookWidgetState
    extends State<OptionDefensePlaybookWidget> {
  final NumberFormat _currencyFormat = NumberFormat.simpleCurrency();

  late OptionDefensePlaybook _playbook;

  @override
  void initState() {
    super.initState();
    widget.analytics.logScreenView(screenName: 'Options Defense Playbook');
    _computePlaybook();
  }

  void _computePlaybook() {
    final spotPrice = widget.instrument.quoteObj?.lastTradePrice ??
        widget.optionPosition.instrumentObj?.quoteObj?.lastTradePrice;

    _playbook = OptionDefensePlaybook.analyze(
      position: widget.optionPosition,
      optionInstrument: widget.optionInstrument,
      underlyingPrice: spotPrice,
      underlyingCostBasis: widget.underlyingCostBasis,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final threat = _playbook.threat;

    Color threatPrimaryColor;
    Color threatContainerColor;
    Color onThreatContainerColor;
    IconData threatIcon;

    switch (threat.level) {
      case OptionDefenseThreatLevel.critical:
        threatPrimaryColor = Colors.red.shade700;
        threatContainerColor = Colors.red.shade900.withValues(alpha: 0.25);
        onThreatContainerColor = Colors.red.shade200;
        threatIcon = Icons.error_rounded;
        break;
      case OptionDefenseThreatLevel.breached:
        threatPrimaryColor = Colors.deepOrange.shade600;
        threatContainerColor = Colors.deepOrange.shade900.withValues(alpha: 0.25);
        onThreatContainerColor = Colors.deepOrange.shade200;
        threatIcon = Icons.warning_rounded;
        break;
      case OptionDefenseThreatLevel.caution:
        threatPrimaryColor = Colors.amber.shade700;
        threatContainerColor = Colors.amber.shade900.withValues(alpha: 0.25);
        onThreatContainerColor = Colors.amber.shade200;
        threatIcon = Icons.report_problem_rounded;
        break;
      case OptionDefenseThreatLevel.safe:
        threatPrimaryColor = Colors.green.shade600;
        threatContainerColor = Colors.green.shade900.withValues(alpha: 0.25);
        onThreatContainerColor = Colors.green.shade200;
        threatIcon = Icons.shield_rounded;
        break;
    }

    final strategyName = widget.optionPosition.strategy.isNotEmpty
        ? widget.optionPosition.strategy.toUpperCase()
        : (widget.optionInstrument.type.toUpperCase() +
            (widget.optionPosition.direction == 'credit' ? ' (SHORT)' : ' (LONG)'));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Defense Playbook',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              '${widget.instrument.symbol} • $strategyName',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Open Roll Assistant',
            icon: const Icon(Icons.sync_alt),
            onPressed: () => _navigateToRollAssistant(null),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Threat Status Header Banner
            Container(
              decoration: BoxDecoration(
                color: threatContainerColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: threatPrimaryColor.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(threatIcon, color: threatPrimaryColor, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          threat.statusTitle,
                          style: TextStyle(
                            color: threatPrimaryColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: threatPrimaryColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          threat.level.name.toUpperCase(),
                          style: TextStyle(
                            color: threatPrimaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    threat.statusDescription,
                    style: TextStyle(
                      color: onThreatContainerColor,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  // Key metrics grid
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetricItem(
                        context,
                        label: 'Short Strike',
                        value: threat.shortStrike != null
                            ? _currencyFormat.format(threat.shortStrike)
                            : '-',
                      ),
                      _buildMetricItem(
                        context,
                        label: 'Spot Price',
                        value: threat.underlyingPrice != null
                            ? _currencyFormat.format(threat.underlyingPrice)
                            : '-',
                      ),
                      _buildMetricItem(
                        context,
                        label: 'Distance',
                        value: threat.distanceToStrike != null
                            ? '${threat.distanceToStrike! >= 0 ? '+' : ''}${threat.distanceToStrike!.toStringAsFixed(1)}%'
                            : '-',
                        valueColor: threat.distanceToStrike != null &&
                                threat.distanceToStrike! > 0
                            ? (widget.optionInstrument.type.toLowerCase() ==
                                    'call'
                                ? Colors.red.shade400
                                : Colors.green.shade400)
                            : null,
                      ),
                      _buildMetricItem(
                        context,
                        label: 'DTE',
                        value: '${threat.daysToExpiration}d',
                        valueColor: threat.daysToExpiration <= 14
                            ? Colors.amber.shade400
                            : null,
                      ),
                      _buildMetricItem(
                        context,
                        label: 'Delta',
                        value: threat.delta != null
                            ? threat.delta!.toStringAsFixed(2)
                            : '-',
                        valueColor: threat.delta != null &&
                                threat.delta!.abs() >= 0.40
                            ? Colors.red.shade400
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Threat Diagnostic Findings Card
            if (threat.threatReasons.isNotEmpty) ...[
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.troubleshoot_rounded,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Threat Diagnostics',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...threat.threatReasons.map((reason) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.fiber_manual_record,
                                  size: 10,
                                  color: threatPrimaryColor,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    reason,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.9),
                                      height: 1.25,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 3. Tactical Defense Playbook Header
            Row(
              children: [
                Icon(Icons.menu_book_rounded,
                    size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Tactical Playbook Actions',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Automated tactical recommendations ranked by strategic effectiveness and risk reduction.',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),

            // 4. Playbook Actions List
            ..._playbook.actions.map((action) => _buildActionCard(context, action)),

            const SizedBox(height: 16),

            // 5. Institutional Defense Principles Card
            _buildInstitutionalPrinciplesCard(context),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(
    BuildContext context, {
    required String label,
    required String value,
    Color? valueColor,
  }) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: valueColor ?? theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(BuildContext context, DefensePlaybookAction action) {
    final theme = Theme.of(context);

    Color badgeColor;
    Color badgeTextColor;
    if (action.isRecommended) {
      badgeColor = Colors.amber.shade700;
      badgeTextColor = Colors.black;
    } else if (action.actionType == DefenseActionType.closePosition) {
      badgeColor = Colors.red.shade700;
      badgeTextColor = Colors.white;
    } else if (action.actionType == DefenseActionType.convertIronCondor) {
      badgeColor = Colors.blue.shade600;
      badgeTextColor = Colors.white;
    } else {
      badgeColor = theme.colorScheme.primaryContainer;
      badgeTextColor = theme.colorScheme.onPrimaryContainer;
    }

    return Card(
      elevation: action.isRecommended ? 2 : 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: action.isRecommended
              ? Colors.amber.shade700.withValues(alpha: 0.8)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: action.isRecommended ? 1.8 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Title & Badges
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (action.isRecommended) ...[
                        Row(
                          children: [
                            Icon(Icons.star_rounded,
                                size: 16, color: Colors.amber.shade600),
                            const SizedBox(width: 4),
                            Text(
                              'RECOMMENDED DEFENSE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        action.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    action.badge,
                    style: TextStyle(
                      color: badgeTextColor,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Objective
            Text(
              action.objective,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 6),

            // Rationale
            Text(
              action.rationale,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),

            // Expected Impact Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.trending_up,
                    size: 15,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    action.expectedImpact,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Steps
            ...action.executionSteps.map((step) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.arrow_right_rounded,
                          size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          step,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 14),

            // Action Button
            SizedBox(
              width: double.infinity,
              child: action.suggestedPreset != null
                  ? FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: action.isRecommended
                            ? Colors.amber.shade700
                            : theme.colorScheme.primary,
                        foregroundColor: action.isRecommended
                            ? Colors.black
                            : theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.sync_alt, size: 18),
                      label: Text(
                        'Execute with Roll Assistant (${action.title.split(' (').first})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () =>
                          _navigateToRollAssistant(action.suggestedPreset),
                    )
                  : action.actionType == DefenseActionType.convertIronCondor
                      ? OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.layers_outlined, size: 18),
                          label: const Text(
                            'Open Options Chain to Add Opposing Leg',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => _navigateToTradeOption(),
                        )
                      : action.actionType == DefenseActionType.closePosition
                          ? OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade400,
                                side: BorderSide(color: Colors.red.shade400),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.close_rounded, size: 18),
                              label: const Text(
                                'Close Position (Cut Loss)',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              onPressed: () => _navigateToTradeOption(
                                positionType:
                                    widget.optionPosition.direction == 'credit'
                                        ? 'Buy'
                                        : 'Sell',
                              ),
                            )
                          : OutlinedButton.icon(
                              icon: const Icon(Icons.check_circle_outline, size: 18),
                              label: const Text('Manage Position'),
                              onPressed: () => _navigateToRollAssistant(null),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstitutionalPrinciplesCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: Icon(
          Icons.school_outlined,
          color: theme.colorScheme.primary,
        ),
        title: const Text(
          'Institutional Options Defense Rules',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: const [
          _RuleBullet(
            title: '1. Always Roll for Credit',
            desc:
                'Never pay a net debit to defend a short option. Paying debits increases your maximum capital at risk on a losing trade.',
          ),
          _RuleBullet(
            title: '2. Defend at 21 DTE Benchmark',
            desc:
                'Gamma risk accelerates exponentially inside 21 DTE. Defend or extend duration before rapid gamma swings amplify losses.',
          ),
          _RuleBullet(
            title: '3. Zero-Margin Opposing Spread',
            desc:
                'When converting a tested credit spread into an Iron Condor, brokerages only hold margin on the wider side. The new credit collected directly offsets losses.',
          ),
          _RuleBullet(
            title: '4. Know When to Cut Losses',
            desc:
                'If the short strike is breached by > 3% and cannot be rolled out for a net credit, close the position and reallocate capital.',
          ),
        ],
      ),
    );
  }

  void _navigateToRollAssistant(RollPreset? preset) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OptionRollAssistantWidget(
          user: widget.user,
          service: widget.service,
          instrument: widget.instrument,
          optionPosition: widget.optionPosition,
          optionInstrument: widget.optionInstrument,
          analytics: widget.analytics,
          observer: widget.observer,
          generativeService: widget.generativeService,
          appUser: widget.appUser,
          userDocRef: widget.userDocRef,
          initialIsPaperTrade: widget.initialIsPaperTrade,
          underlyingCostBasis: widget.underlyingCostBasis,
          riskCircuitBreakerService: widget.riskCircuitBreakerService,
          initialPreset: preset ?? RollPreset.rollOut,
        ),
      ),
    );
  }

  void _navigateToTradeOption({String positionType = 'Buy'}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TradeOptionWidget(
          widget.user,
          widget.service,
          analytics: widget.analytics,
          observer: widget.observer,
          optionPosition: widget.optionPosition,
          optionInstrument: widget.optionInstrument,
          positionType: positionType,
          initialIsPaperTrade: widget.initialIsPaperTrade,
          riskCircuitBreakerService: widget.riskCircuitBreakerService,
        ),
      ),
    );
  }
}

class _RuleBullet extends StatelessWidget {
  final String title;
  final String desc;

  const _RuleBullet({required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            desc,
            style: TextStyle(
              fontSize: 12.5,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
