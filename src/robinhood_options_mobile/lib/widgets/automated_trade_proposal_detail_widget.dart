import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/model/automated_trade_proposal.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/paper_trading_store.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';

/// Interactive deep-dive screen/sheet displaying full AI signal diagnostics,
/// GEX levels, RiskGuard checks, buying power impact, and execution controls.
class AutomatedTradeProposalDetailWidget extends StatefulWidget {
  final AutomatedTradeProposal proposal;
  final IBrokerageService? service;
  final BrokerageUser? brokerageUser;
  final User? user;
  final DocumentReference<User>? userDocRef;
  final FirebaseAnalytics? analytics;
  final FirebaseAnalyticsObserver? observer;
  final GenerativeService? generativeService;

  const AutomatedTradeProposalDetailWidget({
    super.key,
    required this.proposal,
    this.service,
    this.brokerageUser,
    this.user,
    this.userDocRef,
    this.analytics,
    this.observer,
    this.generativeService,
  });

  @override
  State<AutomatedTradeProposalDetailWidget> createState() =>
      _AutomatedTradeProposalDetailWidgetState();
}

class _AutomatedTradeProposalDetailWidgetState
    extends State<AutomatedTradeProposalDetailWidget> {
  bool _isProcessing = false;
  late AutomatedTradeProposal _proposal;

  @override
  void initState() {
    super.initState();
    _proposal = widget.proposal;
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 80) return Colors.green;
    if (confidence >= 60) return Colors.orange;
    return Colors.red;
  }

  Color _getQualificationColor(ProposalQualification qual) {
    switch (qual) {
      case ProposalQualification.confirmed:
        return Colors.green;
      case ProposalQualification.pending:
        return Colors.amber.shade800;
      case ProposalQualification.blocked:
        return Colors.red;
      case ProposalQualification.unknown:
        return Colors.grey;
    }
  }

  Color _getMacroColor(String? status) {
    switch (status?.toUpperCase()) {
      case 'BULLISH':
        return Colors.green;
      case 'BEARISH':
        return Colors.red;
      case 'NEUTRAL':
      default:
        return Colors.grey;
    }
  }

  IconData _getMacroIcon(String? status) {
    switch (status?.toUpperCase()) {
      case 'BULLISH':
        return Icons.trending_up;
      case 'BEARISH':
        return Icons.trending_down;
      case 'NEUTRAL':
      default:
        return Icons.trending_flat;
    }
  }

  Future<void> _handleApprove(
      BuildContext context, AgenticTradingProvider provider) async {
    final userStore = Provider.of<BrokerageUserStore>(context, listen: false);
    final accountStore = Provider.of<AccountStore>(context, listen: false);
    final paperStore = Provider.of<PaperTradingStore>(context, listen: false);
    final quoteStore = Provider.of<QuoteStore>(context, listen: false);
    final posStore =
        Provider.of<InstrumentPositionStore>(context, listen: false);

    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final errorColor = Theme.of(context).colorScheme.error;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Approve ${_proposal.action.toDisplayString()} Order?'),
        content: Text(
          'This will submit a '
          '${provider.config.paperTradingMode ? 'paper ' : 'live '}'
          '${_proposal.action.name.toUpperCase()} order for ${_proposal.quantity} shares of '
          '${_proposal.symbol} at approx. \$${_proposal.price.toStringAsFixed(2)}.\n\n'
          'Are you sure you want to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Approve & Execute'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    try {
      final isPaper = provider.config.paperTradingMode;
      final brokerageUser = widget.brokerageUser ?? userStore.currentUser;
      final account =
          accountStore.items.isNotEmpty ? accountStore.items.first : null;

      final heldQty = isPaper
          ? paperStore.positions
              .where((p) =>
                  p.instrumentObj?.symbol.toUpperCase() == _proposal.symbol)
              .fold<double>(0.0, (tot, p) => tot + (p.quantity ?? 0.0))
          : posStore.items
              .where((p) =>
                  p.instrumentObj?.symbol.toUpperCase() == _proposal.symbol)
              .fold<double>(0.0, (tot, p) => tot + (p.quantity ?? 0.0));

      final success = await provider.approveOrder(
        _proposal.rawMap,
        brokerageUser: brokerageUser,
        account: account,
        brokerageService: widget.service,
        userDocRef: widget.userDocRef,
        paperTradingStore: paperStore,
        heldQuantity: heldQty,
        quoteStore: quoteStore,
      );

      if (!mounted) return;

      if (success) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
                '✅ Approved & executed ${_proposal.action.name.toUpperCase()} ${_proposal.symbol}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        nav.pop(true);
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
                '❌ Failed to execute ${_proposal.symbol}. See Activity Log for details.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleReject(
      BuildContext context, AgenticTradingProvider provider) async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Reject Proposal?'),
        content: Text(
          'Rejecting will dismiss this ${_proposal.symbol} proposal and log it in your trading audit history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isProcessing = true);
    HapticFeedback.lightImpact();

    try {
      await provider.rejectOrder(_proposal.rawMap,
          userDocRef: widget.userDocRef);
      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text('Dismissed proposal for ${_proposal.symbol}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      nav.pop(false);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _navigateToInstrument(BuildContext context) async {
    final navContext = context;
    final instrumentStore =
        Provider.of<InstrumentStore>(navContext, listen: false);
    final userStore =
        Provider.of<BrokerageUserStore>(navContext, listen: false);
    final user = widget.brokerageUser ?? userStore.currentUser;

    if (user != null && widget.service != null) {
      final instrument = await widget.service!
          .getInstrumentBySymbol(user, instrumentStore, _proposal.symbol);
      if (instrument != null && navContext.mounted) {
        Navigator.push(
          navContext,
          MaterialPageRoute(
            builder: (context) => InstrumentWidget(
              user,
              widget.service!,
              instrument,
              analytics: widget.analytics ?? FirebaseAnalytics.instance,
              observer: widget.observer ??
                  FirebaseAnalyticsObserver(
                      analytics: FirebaseAnalytics.instance),
              generativeService:
                  widget.generativeService ?? GenerativeService(),
              user: widget.user,
              userDocRef: widget.userDocRef,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accountStore = Provider.of<AccountStore>(context);
    final provider = Provider.of<AgenticTradingProvider>(context);
    final showBalances = accountStore.showBalances;
    const masked = r'$••••••';

    final isBuy = _proposal.isBuy;
    final actionColor = isBuy ? Colors.green : Colors.red;
    final isEmergencyStop = provider.emergencyStopActivated;

    return Scaffold(
      appBar: AppBar(
        title: Text('${_proposal.symbol} Proposal Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.candlestick_chart_outlined),
            tooltip: 'View Chart & Book',
            onPressed: () => _navigateToInstrument(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Proposal Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: actionColor.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              color:
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: actionColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _proposal.action.toDisplayString(),
                                style: TextStyle(
                                  color: actionColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _proposal.symbol,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        // Qualification Badge
                        if (_proposal.qualification !=
                            ProposalQualification.unknown)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getQualificationColor(
                                      _proposal.qualification)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _proposal.qualification.toDisplayString(),
                              style: TextStyle(
                                color: _getQualificationColor(
                                    _proposal.qualification),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Quantity and Price
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order Parameters',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_proposal.quantity} shares @ \$${_proposal.price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Estimated Total',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              showBalances
                                  ? '\$${_proposal.estimatedCost.toStringAsFixed(2)}'
                                  : masked,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Mode and Time
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: provider.config.paperTradingMode
                                ? Colors.blue.withValues(alpha: 0.12)
                                : Colors.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            provider.config.paperTradingMode
                                ? 'Paper Simulation'
                                : 'Live Broker Execution',
                            style: TextStyle(
                              color: provider.config.paperTradingMode
                                  ? Colors.blue
                                  : Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        Text(
                          DateFormat('MMM d, yyyy · h:mm:ss a')
                              .format(_proposal.timestamp),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Emergency Stop Alert Banner
            if (isEmergencyStop)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: colorScheme.error.withValues(alpha: 0.6)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: colorScheme.error),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Emergency stop is currently active. Pending proposals cannot be executed until resumed.',
                        style: TextStyle(
                          color: colorScheme.onErrorContainer,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // AI Reasoning & Conviction
            _buildSectionHeader(
                context, 'AI Conviction & Reasoning', Icons.psychology),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
              ),
              color:
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.18),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (_proposal.confidence != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getConfidenceColor(
                                      _proposal.confidence!.toDouble())
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _getConfidenceColor(
                                        _proposal.confidence!.toDouble())
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.bolt,
                                    size: 14,
                                    color: _getConfidenceColor(
                                        _proposal.confidence!.toDouble())),
                                const SizedBox(width: 4),
                                Text(
                                  '${_proposal.confidence}% Confidence',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: _getConfidenceColor(
                                        _proposal.confidence!.toDouble()),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (_proposal.rewardRiskRatio != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'R:R ${_proposal.rewardRiskRatio!.toStringAsFixed(1)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (_proposal.interval != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _proposal.interval!.toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (_proposal.reason != null &&
                        _proposal.reason!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: colorScheme.outlineVariant
                                  .withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.format_quote_rounded,
                                size: 18, color: colorScheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _proposal.reason!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontStyle: FontStyle.italic,
                                  height: 1.35,
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
            ),
            const SizedBox(height: 14),

            // RiskGuard & Assessment Metrics
            _buildSectionHeader(
                context, 'RiskGuard & Portfolio Safety', Icons.shield_outlined),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
              ),
              color:
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.18),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  children: [
                    _buildMetricRow(
                      context,
                      'Volatility Filter',
                      _proposal.metrics?['volatilityFilter'] == 'pass',
                      _proposal.metrics?['volatilityFilter']?.toString() ??
                          'N/A',
                    ),
                    const Divider(height: 16),
                    _buildMetricRow(
                      context,
                      'Correlation Check',
                      _proposal.metrics?['correlationFilter'] == 'pass',
                      _proposal.metrics?['correlationFilter']?.toString() ??
                          'N/A',
                    ),
                    const Divider(height: 16),
                    _buildMetricRow(
                      context,
                      'Sector Concentration',
                      _proposal.metrics?['sectorLimitFilter'] == 'pass',
                      _proposal.metrics?['sectorLimitFilter']?.toString() ??
                          'N/A',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // GEX Institutional Levels (if present)
            if (_proposal.gexData != null) ...[
              _buildSectionHeader(context, 'Gamma Exposure (GEX) Levels',
                  Icons.analytics_outlined),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.blue.withValues(alpha: 0.25)),
                ),
                color: Colors.blue.withValues(alpha: 0.04),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildGexLevelItem(
                          context,
                          'pTrans',
                          _proposal.pTransPrice != null
                              ? '\$${_proposal.pTransPrice!.toStringAsFixed(2)}'
                              : 'N/A',
                          Colors.green),
                      _buildGexLevelItem(
                          context,
                          'nTrans',
                          _proposal.nTransPrice != null
                              ? '\$${_proposal.nTransPrice!.toStringAsFixed(2)}'
                              : 'N/A',
                          Colors.red),
                      _buildGexLevelItem(
                          context,
                          'Gamma Flip',
                          _proposal.gammaFlipPrice != null
                              ? '\$${_proposal.gammaFlipPrice!.toStringAsFixed(2)}'
                              : 'N/A',
                          Colors.blue),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Macro Assessment (if present)
            if (_proposal.macroAssessment != null) ...[
              _buildSectionHeader(
                  context, 'Macro Economic Assessment', Icons.public_rounded),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                      color: _getMacroColor(_proposal.macroStatus)
                          .withValues(alpha: 0.3)),
                ),
                color: _getMacroColor(_proposal.macroStatus)
                    .withValues(alpha: 0.05),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _getMacroIcon(_proposal.macroStatus),
                        color: _getMacroColor(_proposal.macroStatus),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Regime: ${_proposal.macroStatus ?? "UNKNOWN"}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _getMacroColor(_proposal.macroStatus),
                              ),
                            ),
                            if (_proposal.macroReason != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                _proposal.macroReason!,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            const SizedBox(height: 80), // Padding for sticky bottom buttons
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isProcessing
                      ? null
                      : () => _handleReject(context, provider),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: colorScheme.error),
                    foregroundColor: colorScheme.error,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Reject Proposal',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _isProcessing || isEmergencyStop
                      ? null
                      : () => _handleApprove(context, provider),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: isBuy ? Colors.green : Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Approve ${isBuy ? "BUY" : "SELL"} Order',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, String title, IconData icon) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(
      BuildContext context, String label, bool isPass, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        Row(
          children: [
            Icon(
              isPass ? Icons.check_circle : Icons.cancel,
              size: 16,
              color: isPass ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 6),
            Text(
              isPass ? 'PASS' : value.toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: isPass ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGexLevelItem(
      BuildContext context, String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }
}
