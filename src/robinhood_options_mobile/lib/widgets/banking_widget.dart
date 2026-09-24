import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/banking.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';

final _currencyFormat = NumberFormat.simpleCurrency();

/// Dashboard for monitoring ACH bank deposits, withdrawals, clearing timelines,
/// and linked bank account relationships.
class BankingWidget extends StatefulWidget {
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  final Account? account;
  final int initialTabIndex;
  final bool embedded;

  const BankingWidget({
    super.key,
    required this.brokerageUser,
    required this.service,
    this.account,
    this.initialTabIndex = 0,
    this.embedded = false,
  });

  @override
  State<BankingWidget> createState() => _BankingWidgetState();
}

class _BankingWidgetState extends State<BankingWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Future<(List<AchTransfer>, List<AchRelationship>)>? _futureData;

  String _directionFilter = 'all'; // 'all', 'deposit', 'withdraw'
  String _statusFilter = 'all'; // 'all', 'completed', 'pending', 'cancelled'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _loadData() {
    setState(() {
      _futureData = _fetchData();
    });
  }

  Future<(List<AchTransfer>, List<AchRelationship>)> _fetchData() async {
    try {
      Future<List<AchTransfer>> transfersFuture;
      Future<List<AchRelationship>> relationshipsFuture;

      if (widget.service is RobinhoodService) {
        final rh = widget.service as RobinhoodService;
        transfersFuture = rh.getAchTransfersModel(widget.brokerageUser);
        relationshipsFuture = rh.getAchRelationshipsModel(widget.brokerageUser);
      } else {
        transfersFuture =
            widget.service.getAchTransfersModel(widget.brokerageUser);
        relationshipsFuture =
            widget.service.getAchRelationshipsModel(widget.brokerageUser);
      }

      final results = await Future.wait([transfersFuture, relationshipsFuture]);
      return (
        results[0] as List<AchTransfer>,
        results[1] as List<AchRelationship>,
      );
    } catch (e) {
      debugPrint('Error loading banking and ACH data: $e');
      return (const <AchTransfer>[], const <AchRelationship>[]);
    }
  }

  Future<void> _cancelTransfer(AchTransfer transfer) async {
    if (transfer.cancelUrl == null || transfer.cancelUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This transfer cannot be cancelled.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Transfer?'),
        content: Text(
          'Are you sure you want to cancel this ${transfer.direction} of ${transfer.formattedAmountPlain}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Transfer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final success = await widget.service
        .cancelAchTransfer(widget.brokerageUser, transfer.cancelUrl!);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Transfer of ${transfer.formattedAmountPlain} cancelled.'),
          backgroundColor: Colors.green,
        ),
      );
      _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to cancel transfer. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final body = FutureBuilder<(List<AchTransfer>, List<AchRelationship>)>(
      future: _futureData,
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
                  const SizedBox(height: 12),
                  Text(
                    'Failed to load banking data',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data ??
            (const <AchTransfer>[], const <AchRelationship>[]);
        final transfers = data.$1;
        final relationships = data.$2;
        final summary = AchSummary.fromTransfersAndRelationships(
            transfers, relationships);

        return RefreshIndicator(
          onRefresh: () async => _loadData(),
          child: widget.embedded
              ? _buildTransfersTab(transfers, relationships, summary)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTransfersTab(transfers, relationships, summary),
                    _buildLinkedAccountsTab(relationships, summary),
                  ],
                ),
        );
      },
    );

    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Banking & Transfers'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.swap_vert), text: 'Transfers'),
            Tab(icon: Icon(Icons.account_balance), text: 'Linked Accounts'),
          ],
        ),
      ),
      body: body,
    );
  }

  Widget _buildTransfersTab(
    List<AchTransfer> transfers,
    List<AchRelationship> relationships,
    AchSummary summary,
  ) {
    final relationshipMap = {for (var r in relationships) r.id: r};

    // Filter
    final filteredTransfers = transfers.where((t) {
      if (_directionFilter == 'deposit' && !t.isDeposit) return false;
      if (_directionFilter == 'withdraw' && !t.isWithdrawal) return false;

      if (_statusFilter == 'completed' && !t.isCompleted) return false;
      if (_statusFilter == 'pending' && !t.isPending) return false;
      if (_statusFilter == 'cancelled' && !t.isCancelled) return false;

      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final bankName = t.achRelationship != null
            ? relationshipMap[t.achRelationship]?.displayName.toLowerCase() ??
                ''
            : '';
        final desc = t.statusDescription?.toLowerCase() ?? '';
        final ref = t.refId?.toLowerCase() ?? '';
        final amountStr = t.amount.toString();
        if (!bankName.contains(query) &&
            !desc.contains(query) &&
            !ref.contains(query) &&
            !amountStr.contains(query) &&
            !t.direction.toLowerCase().contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildHeroSummaryCard(summary),
        const SizedBox(height: 16),
        _buildPendingTransfersBanner(summary),
        const SizedBox(height: 16),
        _buildFilterAndSearchBar(),
        const SizedBox(height: 12),
        if (filteredTransfers.isEmpty)
          _buildEmptyTransfersState()
        else
          ...filteredTransfers.map(
            (transfer) => _buildTransferCard(
              transfer,
              relationshipMap[transfer.achRelationship],
            ),
          ),
      ],
    );
  }

  Widget _buildHeroSummaryCard(AchSummary summary) {
    final theme = Theme.of(context);
    final netColor = summary.netCashFlow >= 0 ? Colors.green : Colors.blue;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'NET CASH MOVEMENT',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: netColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    summary.netCashFlow >= 0 ? 'Net Inflow' : 'Net Outflow',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: netColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              summary.formattedNetCashFlow,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: netColor,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    label: 'Total Deposited',
                    value: summary.formattedTotalDeposited,
                    icon: Icons.south_west,
                    iconColor: Colors.green,
                  ),
                ),
                Container(
                  height: 36,
                  width: 1,
                  color: theme.dividerColor,
                ),
                Expanded(
                  child: _buildMetricTile(
                    label: 'Total Withdrawn',
                    value: summary.formattedTotalWithdrawn,
                    icon: Icons.north_east,
                    iconColor: Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingTransfersBanner(AchSummary summary) {
    if (summary.pendingTransfersCount == 0) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final nextClearing = summary.nextClearingTransfer;
    final landingText = nextClearing?.formattedLandingDate != null
        ? 'Clearing estimated ${nextClearing!.formattedLandingDate}'
        : 'Processing transfer';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_top, color: Colors.amber, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${summary.pendingTransfersCount} Pending Transfer${summary.pendingTransfersCount > 1 ? 's' : ''}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  landingText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.amber.shade900.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          if (summary.pendingDeposits > 0)
            Text(
              summary.formattedPendingDeposits,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterAndSearchBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search transfers by bank, amount, or ID...',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  )
                : null,
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          onChanged: (val) {
            setState(() {
              _searchQuery = val.trim();
            });
          },
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildChoiceChip(
                label: 'All',
                selected: _directionFilter == 'all' && _statusFilter == 'all',
                onSelected: () {
                  setState(() {
                    _directionFilter = 'all';
                    _statusFilter = 'all';
                  });
                },
              ),
              const SizedBox(width: 8),
              _buildChoiceChip(
                label: 'Deposits',
                selected: _directionFilter == 'deposit',
                onSelected: () {
                  setState(() {
                    _directionFilter =
                        _directionFilter == 'deposit' ? 'all' : 'deposit';
                  });
                },
              ),
              const SizedBox(width: 8),
              _buildChoiceChip(
                label: 'Withdrawals',
                selected: _directionFilter == 'withdraw',
                onSelected: () {
                  setState(() {
                    _directionFilter =
                        _directionFilter == 'withdraw' ? 'all' : 'withdraw';
                  });
                },
              ),
              const SizedBox(width: 8),
              _buildChoiceChip(
                label: 'Pending',
                selected: _statusFilter == 'pending',
                onSelected: () {
                  setState(() {
                    _statusFilter =
                        _statusFilter == 'pending' ? 'all' : 'pending';
                  });
                },
              ),
              const SizedBox(width: 8),
              _buildChoiceChip(
                label: 'Completed',
                selected: _statusFilter == 'completed',
                onSelected: () {
                  setState(() {
                    _statusFilter =
                        _statusFilter == 'completed' ? 'all' : 'completed';
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildTransferCard(
      AchTransfer transfer, AchRelationship? relationship) {
    final theme = Theme.of(context);
    final bankTitle = relationship?.displayName ??
        (transfer.isDeposit ? 'Bank Deposit' : 'Bank Withdrawal');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showTransferDetailsSheet(transfer, relationship),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor:
                    transfer.directionColor.withValues(alpha: 0.15),
                child: Icon(transfer.directionIcon,
                    color: transfer.directionColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            bankTitle,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          transfer.formattedAmount,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: transfer.directionColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          transfer.formattedCreatedAt,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: transfer.statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(transfer.statusIcon,
                                  size: 10, color: transfer.statusColor),
                              const SizedBox(width: 3),
                              Text(
                                transfer.statusTitle,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: transfer.statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (transfer.isPending &&
                        transfer.formattedLandingDate != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Expected arrival: ${transfer.formattedLandingDate}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyTransfersState() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40.0),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 48, color: theme.disabledColor),
            const SizedBox(height: 12),
            Text(
              'No transfers found',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try adjusting your search query or filters'
                  : 'Deposit or withdrawal history will appear here',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkedAccountsTab(
    List<AchRelationship> relationships,
    AchSummary summary,
  ) {
    final theme = Theme.of(context);
    final activeAccounts = relationships.where((r) => !r.isUnlinked).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      children: [
        Card(
          elevation: 1,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.account_balance,
                      color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Linked Bank Accounts',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${summary.verifiedAccountsCount} of ${summary.linkedAccountsCount} accounts verified for ACH',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'YOUR CONNECTED BANKS',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        if (activeAccounts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 36.0),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.link_off, size: 48, color: theme.disabledColor),
                  const SizedBox(height: 12),
                  Text('No linked accounts',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Link your bank account to initiate deposits and withdrawals',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          )
        else
          ...activeAccounts.map((account) => _buildLinkedAccountCard(account)),
        const SizedBox(height: 16),
        _buildAchInfoCard(),
      ],
    );
  }

  Widget _buildLinkedAccountCard(AchRelationship account) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  child: Icon(Icons.account_balance,
                      size: 18, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              account.displayName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (account.isDefault) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'PRIMARY',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${account.formattedAccountType} • ${account.maskedAccountNumber}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: account.statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(account.statusIcon,
                          size: 12, color: account.statusColor),
                      const SizedBox(width: 4),
                      Text(
                        account.statusTitle,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: account.statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (account.bankRoutingNumber != null &&
                account.bankRoutingNumber!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Routing Number',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    account.bankRoutingNumber!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
            if (account.bankAccountHolderName != null &&
                account.bankAccountHolderName!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Account Holder',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    account.bankAccountHolderName!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
            if (account.formattedCreatedAt.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Connected Date',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    account.formattedCreatedAt,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
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

  Widget _buildAchInfoCard() {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'ACH Transfer Guidelines',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '• Standard ACH deposits and withdrawals typically complete within 3-5 business days.\n'
              '• Instant deposits may be immediately available for eligible accounts up to your tier limit.\n'
              '• Only transfers with "Pending" status and active cancellation windows can be cancelled in-app.',
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

  void _showTransferDetailsSheet(
      AchTransfer transfer, AchRelationship? relationship) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (_, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(20.0),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      transfer.isDeposit
                          ? 'Deposit Details'
                          : 'Withdrawal Details',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: transfer.statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(transfer.statusIcon,
                              size: 14, color: transfer.statusColor),
                          const SizedBox(width: 4),
                          Text(
                            transfer.statusTitle,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: transfer.statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    transfer.formattedAmount,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: transfer.directionColor,
                    ),
                  ),
                ),
                if (transfer.statusDescription != null &&
                    transfer.statusDescription!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    transfer.statusDescription!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                const Divider(height: 1),
                const SizedBox(height: 16),
                _buildDetailRow('Transfer ID', transfer.id),
                if (transfer.refId != null)
                  _buildDetailRow('Reference ID', transfer.refId!),
                if (relationship != null)
                  _buildDetailRow('Bank Account', relationship.displayName),
                _buildDetailRow(
                    'Initiated Date', transfer.formattedCreatedDateTime),
                if (transfer.formattedLandingDate != null)
                  _buildDetailRow(
                      'Clearing / Arrival', transfer.formattedLandingDate!),
                _buildDetailRow(
                    'Transfer Fees', _currencyFormat.format(transfer.fees)),
                _buildDetailRow('Scheduled', transfer.scheduled ? 'Yes' : 'No'),
                if (transfer.rhsState != null)
                  _buildDetailRow('Clearing State', transfer.rhsState!),
                const SizedBox(height: 20),
                if (transfer.isPending &&
                    transfer.cancelUrl != null &&
                    transfer.cancelUrl!.isNotEmpty) ...[
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _cancelTransfer(transfer);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancel Transfer'),
                  ),
                  const SizedBox(height: 10),
                ],
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
