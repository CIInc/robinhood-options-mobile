import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/margin_call.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';

final _currencyFormat = NumberFormat.simpleCurrency();
final _dateFormat = DateFormat('MMM d, yyyy');

class MarginFinancingWidget extends StatefulWidget {
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  final Account? account;

  const MarginFinancingWidget({
    super.key,
    required this.brokerageUser,
    required this.service,
    this.account,
  });

  @override
  State<MarginFinancingWidget> createState() => _MarginFinancingWidgetState();
}

class _MarginFinancingWidgetState extends State<MarginFinancingWidget>
    with SingleTickerProviderStateMixin {
  late Future<MarginFinancingSummary> _futureSummary;
  late TabController _tabController;
  int _callsFilterIndex = 0; // 0: All, 1: Active, 2: Satisfied

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _futureSummary = _loadSummary();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Account? _resolveAccount(BuildContext context) {
    if (widget.account != null) return widget.account;
    try {
      final store = Provider.of<AccountStore>(context, listen: false);
      return store.selectedAccount ??
          (widget.brokerageUser.accounts.isNotEmpty
              ? widget.brokerageUser.accounts.first
              : null);
    } catch (_) {
      return widget.brokerageUser.accounts.isNotEmpty
          ? widget.brokerageUser.accounts.first
          : null;
    }
  }

  Future<MarginFinancingSummary> _loadSummary() async {
    final account = _resolveAccount(context);
    final accountNum = account?.accountNumber ?? '';

    List<dynamic> rawCalls = [];
    List<dynamic> rawInterest = [];

    try {
      final futures = await Future.wait([
        widget.service.getMarginCalls(widget.brokerageUser),
        widget.service.getMarginInterestCharges(widget.brokerageUser),
      ]);
      rawCalls = futures[0];
      rawInterest = futures[1];
    } catch (e) {
      debugPrint('Error loading margin calls or financing charges: $e');
    }

    return MarginFinancingSummary.fromMarginCallsAndInterest(
      accountNumber: accountNum,
      rawCalls: rawCalls,
      rawInterestCharges: rawInterest,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _futureSummary = _loadSummary();
    });
    await _futureSummary;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Margin Calls & Financing',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Margin Info & Rules',
            onPressed: () => _showMarginInfoDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.gavel_outlined), text: 'Margin Calls'),
            Tab(
              icon: Icon(Icons.receipt_long_outlined),
              text: 'Financing Costs',
            ),
          ],
        ),
      ),
      body: FutureBuilder<MarginFinancingSummary>(
        future: _futureSummary,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to load margin financing details: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      onPressed: _refresh,
                    ),
                  ],
                ),
              ),
            );
          }

          final summary =
              snapshot.data ??
              MarginFinancingSummary(
                accountNumber: '',
                updatedAt: DateTime.now(),
              );

          return RefreshIndicator(
            onRefresh: _refresh,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMarginCallsTab(context, summary),
                _buildFinancingCostsTab(context, summary),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMarginCallsTab(
    BuildContext context,
    MarginFinancingSummary summary,
  ) {
    final filteredCalls = summary.marginCalls.where((call) {
      if (_callsFilterIndex == 1) return call.isOpen;
      if (_callsFilterIndex == 2) return call.isSatisfied;
      return true;
    }).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        _buildHeroStatusCard(context, summary),
        const SizedBox(height: 14),
        _buildMetricsRow(context, summary),
        const SizedBox(height: 14),
        const Text(
          'Deficit Demands',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('All')),
              ButtonSegment(value: 1, label: Text('Active')),
              ButtonSegment(value: 2, label: Text('Resolved')),
            ],
            selected: {_callsFilterIndex},
            onSelectionChanged: (set) {
              setState(() {
                _callsFilterIndex = set.first;
              });
            },
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (filteredCalls.isEmpty)
          _buildEmptyCallsCard(context)
        else
          ...filteredCalls.map((call) => _buildCallCard(context, call)),
        const SizedBox(height: 16),
        _buildResolutionGuideCard(context),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildHeroStatusCard(
    BuildContext context,
    MarginFinancingSummary summary,
  ) {
    final theme = Theme.of(context);
    final hasActive = summary.hasActiveMarginCall;
    final color = hasActive ? Colors.redAccent : Colors.green;
    final icon = hasActive ? Icons.error_rounded : Icons.verified_user_rounded;
    final title = hasActive
        ? 'Active Margin Deficit: ${summary.formattedTotalDeficit}'
        : 'Good Standing - No Active Margin Calls';
    final subtitle = hasActive
        ? 'You have ${summary.openCallsCount} active margin deficit demand(s). Immediate deposit or liquidation is required to meet maintenance requirements.'
        : 'Your account satisfies all FINRA and house maintenance margin requirements. No deficit demands are outstanding.';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: hasActive ? color : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (hasActive && summary.nearestDueDate != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Deadline: ${_dateFormat.format(summary.nearestDueDate!)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsRow(
    BuildContext context,
    MarginFinancingSummary summary,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            context,
            title: 'Active Calls',
            value: '${summary.openCallsCount}',
            color: summary.openCallsCount > 0 ? Colors.red : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricTile(
            context,
            title: 'Total Deficit',
            value: summary.formattedTotalDeficit,
            color: summary.totalDeficitDemand > 0 ? Colors.red : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricTile(
            context,
            title: '2026 Interest',
            value: summary.formattedTotalInterestYtd,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required String title,
    required String value,
    Color? color,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCallsCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: 40,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 8),
              const Text(
                'No Margin Calls',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                'No active or historical margin calls on record for this account.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCallCard(BuildContext context, MarginCall call) {
    final theme = Theme.of(context);
    final stateColor = call.stateColor;

    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(call.stateIcon, color: stateColor, size: 18),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          call.displayType,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: stateColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: stateColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    call.displayState,
                    style: TextStyle(
                      color: stateColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Deficit Demand',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  call.formattedAmount,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: call.isOpen ? Colors.red : null,
                  ),
                ),
              ],
            ),
            if (call.cashDeficit != null || call.equityDeficit != null) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text(
                    'Cash Deficit: ${_currencyFormat.format(call.cashDeficit ?? call.amount)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (call.equityDeficit != null)
                    Text(
                      'Equity Liquidation: ${_currencyFormat.format(call.equityDeficit!)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ],
            const Divider(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                if (call.createdAt != null)
                  Text(
                    'Issued: ${_dateFormat.format(call.createdAt!)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (call.formattedDueDate != null)
                  Text(
                    'Due: ${call.formattedDueDate}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: call.isOverdue ? Colors.red : null,
                    ),
                  ),
                if (call.satisfiedAt != null)
                  Text(
                    'Satisfied: ${_dateFormat.format(call.satisfiedAt!)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.green,
                    ),
                  ),
              ],
            ),
            if (call.description != null && call.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(call.description!, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResolutionGuideCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'How to Resolve Margin Calls',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '• Deposit Cash: Funds clear immediately toward satisfying maintenance calls.\n'
              '• Deposit Marginable Stock: Fully paid eligible securities add equity.\n'
              '• Close Positions: Selling securities frees up maintenance margin requirements (typically 25% to 30% for equities).\n'
              '• Automatic Liquidation: If not satisfied by the deadline, Robinhood will liquidate securities to restore margin health.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancingCostsTab(
    BuildContext context,
    MarginFinancingSummary summary,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        _buildFinancingSummaryCard(context, summary),
        const SizedBox(height: 14),
        const Text(
          'Monthly Interest Debits',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        if (summary.interestCharges.isEmpty)
          _buildEmptyInterestCard(context)
        else
          ...summary.interestCharges.map(
            (charge) => _buildInterestChargeCard(context, charge),
          ),
        const SizedBox(height: 16),
        _buildInterestCalculationExplainer(context, summary),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildFinancingSummaryCard(
    BuildContext context,
    MarginFinancingSummary summary,
  ) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        color: theme.colorScheme.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      const Flexible(
                        child: Text(
                          'Financing Overview',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Rate: ${summary.formattedAverageRate}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
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
                        'Total Interest YTD',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        summary.formattedTotalInterestYtd,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Latest Debit',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        summary.formattedLatestMonthlyCharge,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Debits Logged',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${summary.interestCharges.length}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyInterestCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 40,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 8),
              const Text(
                'No Interest Charges',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                'No monthly margin borrowing debits recorded for this account.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInterestChargeCard(
    BuildContext context,
    MarginInterestCharge charge,
  ) {
    final theme = Theme.of(context);
    final isPosted = charge.isPosted;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        isThreeLine: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isPosted
                ? Colors.red.withValues(alpha: 0.1)
                : Colors.amber.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isPosted ? Icons.remove_circle_outline : Icons.schedule_outlined,
            color: isPosted ? Colors.red : Colors.amber,
            size: 20,
          ),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                charge.formattedEffectiveDate ?? 'Monthly Debit',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              charge.formattedAmount,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                charge.description ?? 'Margin Interest',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    charge.formattedInterestRate,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (charge.settledAmountBorrowed != null)
                    Text(
                      '• Avg Borrowed: ${charge.formattedSettledAmountBorrowed}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (charge.periodStart != null && charge.periodEnd != null)
                    Text(
                      '• Period: ${_dateFormat.format(charge.periodStart!)} – ${_dateFormat.format(charge.periodEnd!)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
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

  Widget _buildInterestCalculationExplainer(
    BuildContext context,
    MarginFinancingSummary summary,
  ) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calculate_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'How Margin Interest is Calculated',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Margin interest is calculated daily using your settled borrowed balance:\n\n'
              'Daily Interest = (Settled Margin Balance × Annual Interest Rate) ÷ 360\n\n'
              'Accrued interest is compiled over the monthly billing cycle and debited directly from your cash balance via Cash Journal entry on the first business day of the subsequent month.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMarginInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Margin Rules & Definitions'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Regulation T (Fed Call):',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 2),
              Text(
                'Requires 50% initial equity deposit for marginable stock purchases.',
                style: TextStyle(fontSize: 13),
              ),
              SizedBox(height: 10),
              Text(
                'FINRA Maintenance Margin (Rule 4210):',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 2),
              Text(
                'Requires at least 25% equity in margin accounts at all times (broker house rules typically require 30% to 50%).',
                style: TextStyle(fontSize: 13),
              ),
              SizedBox(height: 10),
              Text(
                'Margin Call Deficit:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 2),
              Text(
                'The exact dollar demand required to return portfolio equity back to required maintenance minimums.',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
