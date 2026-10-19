import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/retirement.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/retirement_projection_card.dart';

final _currencyFormat = NumberFormat.simpleCurrency();

/// Widget for monitoring IRA contributions, Robinhood matches, and annual IRS limits.
class RetirementWidget extends StatefulWidget {
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  final Account? account;
  final Future<RetirementHistory>? futureHistory;

  const RetirementWidget({
    super.key,
    required this.brokerageUser,
    required this.service,
    this.account,
    this.futureHistory,
  });

  @override
  State<RetirementWidget> createState() => _RetirementWidgetState();
}

class _RetirementWidgetState extends State<RetirementWidget> {
  Future<RetirementHistory>? _futureHistory;
  bool _useCatchUpLimit = false;
  int? _selectedYear;
  Account? _selectedAccount;

  @override
  void initState() {
    super.initState();
    _selectedAccount = widget.account ??
        widget.brokerageUser.accounts
            .where((a) => a.isRetirement)
            .firstOrNull ??
        (widget.brokerageUser.accounts.isNotEmpty
            ? widget.brokerageUser.accounts.first
            : null);
    _loadData();
  }

  void _loadData() {
    setState(() {
      _futureHistory = widget.futureHistory ??
          widget.service.getRetirementHistoryModel(
            widget.brokerageUser,
            accountNumber: _selectedAccount?.accountNumber,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final retirementAccounts =
        widget.brokerageUser.accounts.where((a) => a.isRetirement).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Retirement & IRA'),
        actions: [
          if (retirementAccounts.length > 1)
            PopupMenuButton<Account>(
              tooltip: 'Switch IRA Account',
              icon: const Icon(Icons.account_balance),
              onSelected: (acc) {
                setState(() {
                  _selectedAccount = acc;
                  _loadData();
                });
              },
              itemBuilder: (context) => retirementAccounts
                  .map((acc) => PopupMenuItem<Account>(
                        value: acc,
                        child:
                            Text('${acc.displayType} (${acc.accountNumber})'),
                      ))
                  .toList(),
            ),
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
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
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

          // Filter contributions matching current account if available
          final accountContribs = history.contributionsForAccount(
            accountType: _selectedAccount?.brokerageAccountType,
            accountNumber: _selectedAccount?.accountNumber,
          );

          // Build list of unique available tax years
          final availableYearsSet = <int>{currentYear};
          for (final c in accountContribs) {
            availableYearsSet.add(c.year);
          }
          for (final c in history.contributions) {
            availableYearsSet.add(c.year);
          }
          final availableYears = availableYearsSet.toList()
            ..sort((a, b) => b.compareTo(a));

          final activeYear = _selectedYear ?? currentYear;
          final activeContribution = history.contributionForYear(
                activeYear,
                accountType: _selectedAccount?.brokerageAccountType,
                accountNumber: _selectedAccount?.accountNumber,
              ) ??
              (accountContribs.isNotEmpty ? accountContribs.first : null) ??
              (history.contributions.isNotEmpty
                  ? history.contributions.first
                  : null);

          final rolloverTotal = history.contributions
              .where((c) => c.rolloverContributions > 0)
              .fold<double>(0.0, (s, c) => s + c.rolloverContributions);
          final totalBalance = history.totalValue ??
              _selectedAccount?.totalValue ??
              (rolloverTotal > 0 ? rolloverTotal : null) ??
              _selectedAccount?.portfolioCash;

          return RefreshIndicator(
            onRefresh: () async => _loadData(),
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildHeaderCard(
                    context, activeContribution, history, totalBalance),
                const SizedBox(height: 16),
                _buildYearSelector(context, availableYears, activeYear),
                const SizedBox(height: 16),
                _buildContributionCard(context, activeContribution, activeYear),
                const SizedBox(height: 16),
                _buildCatchUpToggle(context),
                const SizedBox(height: 16),
                RetirementProjectionCard(
                  currentContribution: activeContribution,
                  initialBalance: totalBalance ?? 10000.0,
                  initialCatchUp: _useCatchUpLimit,
                ),
                const SizedBox(height: 16),
                _buildHistorySection(context, accountContribs, history),
                const SizedBox(height: 24),
                _buildIrsInfoNotice(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildYearSelector(
      BuildContext context, List<int> years, int activeYear) {
    final currentYear = DateTime.now().year;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: years.map((year) {
          final isSelected = year == activeYear;
          final label = year == currentYear ? '$year (Current)' : '$year';
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedYear = year;
                  });
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, RetirementContribution? contrib,
      RetirementHistory history, double? totalBalance) {
    final theme = Theme.of(context);
    final isTrad = _selectedAccount?.isTraditionalIra == true ||
        (contrib?.isTraditional ?? false);
    final accountType = _selectedAccount?.displayType ??
        (contrib?.displayAccountType ??
            (isTrad ? 'Traditional IRA' : 'Roth IRA'));

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                  child: const Icon(Icons.savings, size: 26),
                ),
                const SizedBox(width: 14),
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
                      const SizedBox(height: 2),
                      Text(
                        _selectedAccount != null
                            ? 'Account: ${_selectedAccount!.accountNumber}'
                            : 'Tax-Advantaged Retirement',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                if (contrib?.matchRate != null && contrib!.matchRate > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${(contrib.matchRate * 100).toStringAsFixed(0)}% MATCH',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            if (totalBalance != null) ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Account Value',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    _currencyFormat.format(totalBalance),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              if (_selectedAccount?.portfolioCash != null &&
                  _selectedAccount?.portfolioCash != totalBalance) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Cash / Buying Power',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      _currencyFormat.format(_selectedAccount!.portfolioCash),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContributionCard(
      BuildContext context, RetirementContribution? contrib, int taxYear) {
    final theme = Theme.of(context);
    final year = contrib?.year ?? taxYear;
    final contributed = contrib?.contributionAmount ?? 0.0;
    final effectiveLimit = _useCatchUpLimit
        ? (contrib?.catchUpLimit ?? 8000.0)
        : (contrib?.limit ?? 7000.0);
    final remaining =
        (effectiveLimit - contributed).clamp(0.0, double.infinity);
    final progress = effectiveLimit > 0
        ? (contributed / effectiveLimit).clamp(0.0, 1.0)
        : 0.0;
    final match = contrib?.matchAmount ?? 0.0;
    final rollover = contrib?.rolloverContributions ?? 0.0;

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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                _buildStatColumn(context, 'Contributed',
                    _currencyFormat.format(contributed)),
                _buildStatColumn(
                    context, 'Remaining', _currencyFormat.format(remaining)),
                _buildStatColumn(context, 'IRS Limit',
                    _currencyFormat.format(effectiveLimit)),
              ],
            ),
            if (rollover > 0) ...[
              const Divider(height: 24),
              Row(
                children: [
                  const Icon(Icons.sync_alt, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Rollovers & Transfers: ',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    _currencyFormat.format(rollover),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              if (contrib?.sourceDescription != null) ...[
                const SizedBox(height: 2),
                Text(
                  contrib!.sourceDescription!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'Rollover contributions (e.g. from a 401(k) or brokerage transfer) do not count toward your \$${effectiveLimit.toStringAsFixed(0)} annual IRS limit.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
            if (contributed == 0.0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        rollover > 0
                            ? 'Your IRA was funded via rollover. You have ${_currencyFormat.format(remaining)} in available direct contribution room for tax year $year.'
                            : 'No annual direct contributions recorded for tax year $year. You have ${_currencyFormat.format(remaining)} available to contribute under the IRS limit.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (match > 0) ...[
              const Divider(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Robinhood Match Earned: ',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
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
                  ),
                ],
              ),
            ],
            if (contrib != null && contrib.transactions.isNotEmpty) ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Transfers & Contributions',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${contrib.transactions.length} record${contrib.transactions.length == 1 ? '' : 's'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...contrib.transactions.map((tx) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.green.withValues(alpha: 0.15),
                        child: const Icon(Icons.arrow_downward,
                            color: Colors.green, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tx.title,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              [
                                if (tx.date != null)
                                  DateFormat.yMMMd().format(tx.date!),
                                if (tx.matchAmount > 0)
                                  'Match: ${_currencyFormat.format(tx.matchAmount)}${tx.matchRate > 0 ? " (${(tx.matchRate * 100).toStringAsFixed(0)}%)" : ""}',
                              ].join(' • '),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _currencyFormat.format(tx.amount),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                );
              }),
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
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.5),
      child: SwitchListTile(
        title: const Text('Age 50+ Catch-Up Limit'),
        subtitle:
            const Text('Includes extra \$1,000 annual IRS catch-up limit'),
        value: _useCatchUpLimit,
        onChanged: (val) {
          setState(() {
            _useCatchUpLimit = val;
          });
        },
      ),
    );
  }

  Widget _buildHistorySection(BuildContext context,
      List<RetirementContribution> accountContribs, RetirementHistory history) {
    final theme = Theme.of(context);
    final displayList =
        accountContribs.isNotEmpty ? accountContribs : history.contributions;

    if (displayList.isEmpty) {
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
        ...displayList.map((c) {
          final effLimit = _useCatchUpLimit ? c.catchUpLimit : c.limit;
          final pct = effLimit > 0
              ? (c.contributionAmount / effLimit).clamp(0.0, 1.0)
              : 0.0;
          final isSelected = c.year == _selectedYear;
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6.0),
            shape: isSelected
                ? RoundedRectangleBorder(
                    side:
                        BorderSide(color: theme.colorScheme.primary, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  )
                : null,
            child: ListTile(
              onTap: () {
                setState(() {
                  _selectedYear = c.year;
                });
              },
              leading: CircleAvatar(
                backgroundColor: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.secondaryContainer,
                foregroundColor: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSecondaryContainer,
                child: Text(
                  c.year.toString().substring(2),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
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
                  if (c.transactions.isNotEmpty)
                    Text(
                      '${c.transactions.length} contribution transfer${c.transactions.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if (c.rolloverContributions > 0)
                    Text(
                      'Rollovers: ${_currencyFormat.format(c.rolloverContributions)}${c.sourceDescription != null ? " (${c.sourceDescription})" : ""}',
                      style: const TextStyle(fontSize: 11, color: Colors.blue),
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
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        pct >= 1.0 ? Colors.green : theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              trailing: pct >= 1.0
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : const Icon(Icons.chevron_right, size: 20),
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
