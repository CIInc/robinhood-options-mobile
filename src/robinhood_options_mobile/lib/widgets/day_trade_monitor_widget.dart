import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/day_trade.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';

final _currencyFormat = NumberFormat.simpleCurrency();
final _dateFormat = DateFormat('EEE, MMM d, yyyy');
final _timeFormat = DateFormat('h:mm a');

class DayTradeMonitorWidget extends StatefulWidget {
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  final Account? account;

  const DayTradeMonitorWidget({
    super.key,
    required this.brokerageUser,
    required this.service,
    this.account,
  });

  @override
  State<DayTradeMonitorWidget> createState() => _DayTradeMonitorWidgetState();
}

class _DayTradeMonitorWidgetState extends State<DayTradeMonitorWidget> {
  late Future<DayTradeSummary> _futureSummary;
  int _selectedFilterIndex = 0; // 0: All, 1: Equities, 2: Options

  @override
  void initState() {
    super.initState();
    _futureSummary = _loadDayTradeSummary();
  }

  Account? _resolveAccount(BuildContext context) {
    if (widget.account != null) return widget.account;
    final store = Provider.of<AccountStore>(context, listen: false);
    return store.selectedAccount ??
        (widget.brokerageUser.accounts.isNotEmpty
            ? widget.brokerageUser.accounts.first
            : null);
  }

  Future<DayTradeSummary> _loadDayTradeSummary() async {
    final account = _resolveAccount(context);
    final accountNum = account?.accountNumber ?? '';

    dynamic rawJson;
    try {
      rawJson = await widget.service
          .getRecentDayTrades(widget.brokerageUser, accountNum);
    } catch (e) {
      debugPrint('Error fetching recent day trades: $e');
    }

    final equity = account?.buyingPower ?? account?.portfolioCash ?? 0.0;

    return DayTradeSummary.fromJson(
      rawJson,
      accountNumber: accountNum,
      portfolioEquity: equity,
      isPatternDayTrader: account?.markedPatternDayTraderDate != null,
      dayTradesProtection: account?.dayTradesProtection ?? true,
      markedPatternDayTraderDate: account?.markedPatternDayTraderDate,
      patternDayTraderExpiryDate: account?.patternDayTraderExpiryDate,
      isPdtForever: account?.isPdtForever ?? false,
      dayTradeBuyingPower: account?.dayTradeBuyingPower,
      dayTradeRatio: account?.dayTradeRatio,
      accountType: account?.type,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _futureSummary = _loadDayTradeSummary();
    });
    await _futureSummary;
  }

  @override
  Widget build(BuildContext context) {
    final account = _resolveAccount(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Day Trade & PDT Monitor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'PDT Rules Information',
            onPressed: () => _showPdtInfoDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<DayTradeSummary>(
          future: _futureSummary,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final summary = snapshot.data ??
                DayTradeSummary(
                  accountNumber: account?.accountNumber ?? '',
                  dayTrades: [],
                  portfolioEquity: account?.portfolioCash ?? 0.0,
                  accountType: account?.type,
                );

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                _buildHeaderCard(context, summary, account),
                const SizedBox(height: 16),
                _buildEquityThresholdCard(context, summary),
                const SizedBox(height: 16),
                _buildDayTradeProtectionCard(context, summary, account),
                const SizedBox(height: 16),
                _buildTradesSection(context, summary),
                const SizedBox(height: 16),
                _buildRegulatoryFaq(context),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeaderCard(
    BuildContext context,
    DayTradeSummary summary,
    Account? account,
  ) {
    final theme = Theme.of(context);
    final riskLevel = summary.riskLevel;

    Color statusColor;
    IconData statusIcon;
    switch (riskLevel) {
      case PdtRiskLevel.exempt:
        statusColor = Colors.blue;
        statusIcon = Icons.verified_user_outlined;
        break;
      case PdtRiskLevel.flagged:
        statusColor = Colors.purple;
        statusIcon = Icons.gavel_outlined;
        break;
      case PdtRiskLevel.danger:
        statusColor = theme.colorScheme.error;
        statusIcon = Icons.warning_rounded;
        break;
      case PdtRiskLevel.warning:
        statusColor = Colors.orange;
        statusIcon = Icons.shield_outlined;
        break;
      case PdtRiskLevel.safe:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_outline;
        break;
    }

    final usedTrades = summary.activeDayTradeCount;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Account ${summary.accountNumber}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        account != null && account.type.isNotEmpty
                            ? (account.type.toLowerCase().endsWith('account')
                                ? account.type.toUpperCase()
                                : '${account.type.toUpperCase()} ACCOUNT')
                            : 'MARGIN ACCOUNT',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: summary.statusTitle,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: statusColor.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 16, color: statusColor),
                        const SizedBox(width: 6),
                        Text(
                          summary.statusBadge,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Visual 4-segment meter
            Text(
              'Rolling 5-Day Trades Counter',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(4, (index) {
                final isFourth = index == 3;
                final isFilled = index < usedTrades;
                Color segColor;
                if (isFourth) {
                  segColor = isFilled ? Colors.purple : Colors.red.shade300;
                } else if (isFilled) {
                  segColor = statusColor;
                } else {
                  segColor = theme.colorScheme.surfaceContainerHighest;
                }

                return Expanded(
                  child: Container(
                    height: 12,
                    margin: EdgeInsets.only(right: index < 3 ? 6 : 0),
                    decoration: BoxDecoration(
                      color: segColor,
                      borderRadius: BorderRadius.circular(6),
                      border: isFourth && !isFilled
                          ? Border.all(color: Colors.red.shade400, width: 1.5)
                          : null,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '$usedTrades of 3 Allowed Day Trades Used',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  summary.isPdtExempt
                      ? 'Exempt'
                      : (summary.remainingDayTrades == 0
                          ? '0 Left'
                          : '${summary.remainingDayTrades} Left'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                summary.statusDescription,
                style: theme.textTheme.bodySmall?.copyWith(height: 1.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEquityThresholdCard(
    BuildContext context,
    DayTradeSummary summary,
  ) {
    final theme = Theme.of(context);
    final equity = summary.portfolioEquity ?? 0.0;
    const finraThreshold = 25000.0;
    final progress = (equity / finraThreshold).clamp(0.0, 1.0);
    final isExempt = summary.isPdtExempt;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance,
                  size: 20,
                  color: isExempt ? Colors.blue : theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'FINRA \$25,000 Equity Threshold',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  'Current Account Equity',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  _currencyFormat.format(equity),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isExempt ? Colors.green : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                isExempt ? Colors.green : theme.colorScheme.primary,
              ),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '\$0',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Threshold: \$25,000.00',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              isExempt
                  ? '✓ Your account maintains over \$25,000 in equity. You are exempt from the 3-day-trade restriction.'
                  : 'Maintaining \$25,000+ equity unlocks unlimited day trades. Deficit: ${_currencyFormat.format(summary.equityDeficitTo25k)}.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isExempt
                    ? Colors.green
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayTradeProtectionCard(
    BuildContext context,
    DayTradeSummary summary,
    Account? account,
  ) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.security,
                    size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Protection & Buying Power',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                summary.dayTradesProtection
                    ? Icons.lock_outline
                    : Icons.lock_open_outlined,
                color: summary.dayTradesProtection ? Colors.green : Colors.red,
              ),
              title: const Text('Robinhood Day Trade Protection'),
              subtitle: Text(
                summary.dayTradesProtection
                    ? 'Active — Prevents opening orders that would cause a 4th day trade'
                    : 'Disabled — Orders will execute without day trade warnings',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Chip(
                label: Text(
                  summary.dayTradesProtection ? 'Protected' : 'Off',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color:
                        summary.dayTradesProtection ? Colors.green : Colors.red,
                  ),
                ),
                backgroundColor: summary.dayTradesProtection
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
              ),
            ),
            const Divider(),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  'Day Trade Buying Power (DTBP)',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  summary.dayTradeBuyingPower != null
                      ? _currencyFormat.format(summary.dayTradeBuyingPower)
                      : (account?.buyingPower != null
                          ? _currencyFormat.format(account!.buyingPower)
                          : 'N/A'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  'Day Trade Margin Ratio',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  summary.dayTradeRatio != null
                      ? '${(summary.dayTradeRatio! * 100).toStringAsFixed(0)}% (${(1.0 / summary.dayTradeRatio!).toStringAsFixed(0)}x leverage)'
                      : '25% (4x intraday)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (summary.patternDayTraderExpiryDate != null) ...[
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    'PDT Restriction Expiry',
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    _dateFormat.format(summary.patternDayTraderExpiryDate!),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
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

  Widget _buildTradesSection(BuildContext context, DayTradeSummary summary) {
    final theme = Theme.of(context);

    List<DayTrade> displayedTrades;
    switch (_selectedFilterIndex) {
      case 1:
        displayedTrades = summary.equityDayTrades;
        break;
      case 2:
        displayedTrades = summary.optionDayTrades;
        break;
      default:
        displayedTrades = summary.dayTrades;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Day Trades (${summary.activeDayTradeCount})',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('All')),
              ButtonSegment(value: 1, label: Text('Stocks')),
              ButtonSegment(value: 2, label: Text('Options')),
            ],
            selected: {_selectedFilterIndex},
            onSelectionChanged: (set) {
              setState(() {
                _selectedFilterIndex = set.first;
              });
            },
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (displayedTrades.isEmpty)
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.event_available,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No Day Trades in Rolling Window',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You have 3 of 3 allowable day trades ready to use.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ...displayedTrades.map((trade) => _buildTradeTile(context, trade)),
      ],
    );
  }

  Widget _buildTradeTile(BuildContext context, DayTrade trade) {
    final theme = Theme.of(context);
    final isOption = trade.type == 'option';
    final remainingDays = trade.remainingTradingDays;
    final isExpired = trade.isExpired;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: isOption
              ? Colors.deepPurple.withValues(alpha: 0.15)
              : Colors.teal.withValues(alpha: 0.15),
          foregroundColor: isOption ? Colors.deepPurple : Colors.teal,
          child: Icon(
            isOption ? Icons.call_split : Icons.show_chart,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                trade.symbol,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                trade.type.toUpperCase(),
                style:
                    const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${_dateFormat.format(trade.timestamp)} • ${_timeFormat.format(trade.timestamp)}',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (trade.price != null || trade.quantity != null) ...[
              const SizedBox(height: 2),
              Text(
                '${trade.quantity != null ? "${trade.quantity} ${isOption ? 'contracts' : 'shares'}" : ""}${trade.price != null ? " @ ${_currencyFormat.format(trade.price)}" : ""}${trade.direction != null ? " • ${trade.direction!.replaceAll('_', ' ')}" : ""}',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isExpired
                ? Colors.grey.withValues(alpha: 0.15)
                : (remainingDays <= 1
                    ? Colors.green.withValues(alpha: 0.15)
                    : Colors.amber.withValues(alpha: 0.15)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isExpired
                    ? 'Expired'
                    : (remainingDays == 1
                        ? 'Rolls off today'
                        : 'Rolls off in $remainingDays days'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isExpired
                      ? Colors.grey
                      : (remainingDays <= 1
                          ? Colors.green.shade800
                          : Colors.amber.shade900),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('MMM d').format(trade.dropOffDate),
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegulatoryFaq(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        leading: const Icon(Icons.help_outline),
        title: const Text(
          'FINRA Rule 4210 & PDT Guide',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: const Text(
          'Learn how day trades, restrictions, and roll-offs work',
          style: TextStyle(fontSize: 12),
        ),
        childrenPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: const [
          ListTile(
            title: Text('What counts as a Day Trade?'),
            subtitle: Text(
              'Purchasing and selling (or shorting and buying) the same equity or option contract on the same market day.',
              style: TextStyle(fontSize: 12),
            ),
          ),
          ListTile(
            title: Text('What triggers Pattern Day Trader status?'),
            subtitle: Text(
              'Executing 4 or more day trades within 5 business days in a margin account, where day trades make up more than 6% of total trades.',
              style: TextStyle(fontSize: 12),
            ),
          ),
          ListTile(
            title: Text('The \$25,000 Minimum Equity Rule'),
            subtitle: Text(
              'Accounts designated as PDT must maintain at least \$25,000 in equity at the close of every business day to execute new day trades.',
              style: TextStyle(fontSize: 12),
            ),
          ),
          ListTile(
            title: Text('When do Day Trades Roll Off?'),
            subtitle: Text(
              'Each day trade rolls off after 5 business days (weekends and market holidays do not count). For example, a trade on Monday drops off on the following Monday.',
              style: TextStyle(fontSize: 12),
            ),
          ),
          ListTile(
            title: Text('What happens if restricted?'),
            subtitle: Text(
              'If your account is flagged as PDT with under \$25,000, you are restricted from day trading for 90 days or limited to cash-available trades only, unless a broker one-time reset is granted.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showPdtInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Colors.blue),
            SizedBox(width: 8),
            Text('FINRA Rule 4210'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Pattern Day Trading Rules Summary',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                '• 3 Day Trades allowed in any rolling 5-business-day window.\n'
                '• 4th Day Trade flags your account as a Pattern Day Trader.\n'
                '• \$25,000 Equity Requirement: Accounts with \$25k+ equity are exempt from day trading restrictions.\n'
                '• Robinhood Day Trade Protection prevents you from accidentally placing a 4th trade.\n'
                '• Day trades automatically roll off after 5 trading days.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got It'),
          ),
        ],
      ),
    );
  }
}
