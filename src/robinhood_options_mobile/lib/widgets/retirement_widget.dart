import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/retirement.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';

final _currencyFormat = NumberFormat.simpleCurrency();

/// Widget for monitoring IRA contributions, Robinhood matches, and annual IRS limits.
class RetirementWidget extends StatefulWidget {
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  final Account? account;

  const RetirementWidget({
    super.key,
    required this.brokerageUser,
    required this.service,
    this.account,
  });

  @override
  State<RetirementWidget> createState() => _RetirementWidgetState();
}

class _RetirementWidgetState extends State<RetirementWidget> {
  Future<RetirementHistory>? _futureHistory;
  bool _useCatchUpLimit = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _futureHistory = widget.service.getRetirementHistoryModel(widget.brokerageUser);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Retirement & IRA'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
      ),
      body: FutureBuilder<RetirementHistory>(
        future: _futureHistory,
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
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error loading retirement data: ${snapshot.error}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadData,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final history = snapshot.data ?? const RetirementHistory();
          final currentYear = DateTime.now().year;
          final currentContribution = history.contributionForYear(currentYear) ??
              history.currentYearContribution ??
              (history.contributions.isNotEmpty ? history.contributions.first : null);

          return RefreshIndicator(
            onRefresh: () async => _loadData(),
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildHeaderCard(context, currentContribution),
                const SizedBox(height: 16),
                _buildCurrentYearCard(context, currentContribution),
                const SizedBox(height: 16),
                _buildCatchUpToggle(context),
                const SizedBox(height: 16),
                _buildHistorySection(context, history),
                const SizedBox(height: 24),
                _buildIrsInfoNotice(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, RetirementContribution? contrib) {
    final theme = Theme.of(context);
    final accountType = widget.account?.displayType ??
        (contrib?.displayAccountType ?? 'Roth IRA');

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundColor: theme.colorScheme.onPrimaryContainer,
              child: const Icon(Icons.savings, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    accountType,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.account != null
                        ? 'Account: ${widget.account!.accountNumber}'
                        : 'Tax-Advantaged Retirement',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'TAX-ADVANTAGED',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentYearCard(BuildContext context, RetirementContribution? contrib) {
    final theme = Theme.of(context);
    final year = contrib?.year ?? DateTime.now().year;
    final contributed = contrib?.contributionAmount ?? 0.0;
    final effectiveLimit = _useCatchUpLimit
        ? (contrib?.catchUpLimit ?? 8000.0)
        : (contrib?.limit ?? 7000.0);
    final remaining = (effectiveLimit - contributed).clamp(0.0, double.infinity);
    final progress = effectiveLimit > 0 ? (contributed / effectiveLimit).clamp(0.0, 1.0) : 0.0;
    final match = contrib?.matchAmount ?? 0.0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$year Contribution Progress',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${(progress * 100).toStringAsFixed(1)}% Maxed',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress >= 1.0 ? Colors.green : theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatColumn(context, 'Contributed', _currencyFormat.format(contributed)),
                _buildStatColumn(context, 'Remaining', _currencyFormat.format(remaining)),
                _buildStatColumn(context, 'IRS Limit', _currencyFormat.format(effectiveLimit)),
              ],
            ),
            if (match > 0) ...[
              const Divider(height: 24),
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Robinhood Match Earned: ',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    _currencyFormat.format(match),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  if (contrib != null && contrib.matchRate > 0)
                    Text(
                      ' (${(contrib.matchRate * 100).toStringAsFixed(0)}% Gold Match)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildCatchUpToggle(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: SwitchListTile(
        title: const Text('Age 50+ Catch-Up Limit'),
        subtitle: const Text('Includes extra \$1,000 annual IRS catch-up limit'),
        value: _useCatchUpLimit,
        onChanged: (val) {
          setState(() {
            _useCatchUpLimit = val;
          });
        },
      ),
    );
  }

  Widget _buildHistorySection(BuildContext context, RetirementHistory history) {
    final theme = Theme.of(context);
    if (history.contributions.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Icon(Icons.history, size: 40, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('No Contribution History Found'),
              const SizedBox(height: 4),
              Text(
                'Contributions made to your IRA will appear here.',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contribution History',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...history.contributions.map((c) {
          final effLimit = _useCatchUpLimit ? c.catchUpLimit : c.limit;
          final pct = effLimit > 0 ? (c.contributionAmount / effLimit).clamp(0.0, 1.0) : 0.0;
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6.0),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.secondaryContainer,
                child: Text(
                  c.year.toString().substring(2),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
              title: Text(
                'Tax Year ${c.year}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    '${c.displayAccountType} • ${_currencyFormat.format(c.contributionAmount)} of ${_currencyFormat.format(effLimit)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  if (c.matchAmount > 0)
                    Text(
                      'Match: ${_currencyFormat.format(c.matchAmount)}',
                      style: const TextStyle(fontSize: 11, color: Colors.green),
                    ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 6,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        pct >= 1.0 ? Colors.green : theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              trailing: pct >= 1.0
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : null,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildIrsInfoNotice(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'IRS IRA contribution deadline for any tax year is typically April 15 of the following calendar year. Total contributions across all Traditional and Roth IRAs cannot exceed the combined annual limit.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
