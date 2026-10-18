import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/schwab_transaction.dart';
import 'package:robinhood_options_mobile/services/schwab_service.dart';

class SchwabTransactionsWidget extends StatefulWidget {
  final BrokerageUser user;
  final SchwabService service;
  final String? initialAccountNumber;
  final bool embedded;

  const SchwabTransactionsWidget({
    super.key,
    required this.user,
    required this.service,
    this.initialAccountNumber,
    this.embedded = false,
  });

  @override
  State<SchwabTransactionsWidget> createState() =>
      _SchwabTransactionsWidgetState();
}

class _SchwabTransactionsWidgetState extends State<SchwabTransactionsWidget> {
  late Future<List<SchwabTransaction>> _futureTransactions;
  String _selectedType = 'ALL';
  String _symbolQuery = '';
  DateTimeRange? _selectedDateRange;
  String _datePreset = '3M';

  final currencyFormat = NumberFormat.simpleCurrency();
  final dateFormat = DateFormat('MMM d, y HH:mm');
  final shortDateFormat = DateFormat('MMM d, y');

  @override
  void initState() {
    super.initState();
    _applyPreset('3M');
    _loadTransactions();
  }

  void _applyPreset(String preset) {
    _datePreset = preset;
    final now = DateTime.now();
    DateTime start;
    switch (preset) {
      case '1M':
        start = DateTime(now.year, now.month - 1, now.day);
        break;
      case '3M':
        start = DateTime(now.year, now.month - 3, now.day);
        break;
      case '6M':
        start = DateTime(now.year, now.month - 6, now.day);
        break;
      case 'YTD':
        start = DateTime(now.year, 1, 1);
        break;
      case '1Y':
        start = DateTime(now.year - 1, now.month, now.day);
        break;
      default:
        start = DateTime(now.year, now.month - 3, now.day);
        break;
    }
    _selectedDateRange = DateTimeRange(start: start, end: now);
  }

  void _loadTransactions() {
    setState(() {
      _futureTransactions = widget.service.getSchwabTransactions(
        widget.user,
        accountNumber: widget.initialAccountNumber,
        startDate: _selectedDateRange?.start,
        endDate: _selectedDateRange?.end,
      );
    });
  }

  List<SchwabTransaction> _filterTransactions(
      List<SchwabTransaction> transactions) {
    return transactions.where((tx) {
      // Type filter
      if (_selectedType == 'TRADES' && !tx.isTrade) return false;
      if (_selectedType == 'INCOME' && !tx.isDividendOrInterest) return false;
      if (_selectedType == 'CASH' && !tx.isCashMovement) return false;
      if (_selectedType == 'FEES' && !tx.isFee) return false;

      // Symbol filter
      if (_symbolQuery.isNotEmpty) {
        final query = _symbolQuery.toUpperCase();
        final sym = tx.primarySymbol?.toUpperCase() ?? '';
        final desc = tx.description?.toUpperCase() ?? '';
        if (!sym.contains(query) && !desc.contains(query)) {
          return false;
        }
      }

      // Date range filter
      if (_selectedDateRange != null) {
        if (tx.time.isBefore(_selectedDateRange!.start) ||
            tx.time.isAfter(
                _selectedDateRange!.end.add(const Duration(days: 1)))) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  void _exportCsv(List<SchwabTransaction> transactions) {
    final rows = <List<dynamic>>[];
    rows.add([
      'Activity ID',
      'Time',
      'Account Number',
      'Type',
      'Status',
      'Sub Account',
      'Symbol',
      'Description',
      'Quantity',
      'Price',
      'Position Effect',
      'Net Amount',
      'Commission',
      'Regulatory Fees',
      'Total Fees',
      'Order ID',
      'Settlement Date',
    ]);

    for (final tx in transactions) {
      rows.add([
        tx.activityId,
        tx.time.toIso8601String(),
        tx.accountNumber,
        tx.type,
        tx.status,
        tx.subAccount,
        tx.primarySymbol ?? '',
        tx.description ?? '',
        tx.primaryQuantity,
        tx.primaryPrice ?? '',
        tx.positionEffect ?? '',
        tx.netAmount,
        tx.commission,
        tx.regulatoryFees,
        tx.totalFees,
        tx.orderId ?? '',
        tx.settlementDate?.toIso8601String() ?? '',
      ]);
    }

    final csv = Csv().encode(rows);
    SharePlus.instance.share(ShareParams(
      text: csv,
      subject:
          'Schwab_Transactions_${widget.initialAccountNumber ?? "account"}.csv',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final body = FutureBuilder<List<SchwabTransaction>>(
      future: _futureTransactions,
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
                      size: 48, color: Colors.redAccent),
                  const SizedBox(height: 12),
                  Text(
                    'Error loading transactions: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    onPressed: _loadTransactions,
                  ),
                ],
              ),
            ),
          );
        }

        final allTransactions = snapshot.data ?? [];
        final filteredTransactions = _filterTransactions(allTransactions);

        return RefreshIndicator(
          onRefresh: () async {
            _loadTransactions();
            await _futureTransactions;
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              if (widget.embedded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Account Activity',
                        style: TextStyle(
                            fontSize: 20.0, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            tooltip: 'Refresh Transactions',
                            onPressed: _loadTransactions,
                          ),
                          IconButton(
                            icon: const Icon(Icons.download),
                            tooltip: 'Export CSV',
                            onPressed: () async {
                              final transactions = await _futureTransactions;
                              final filtered =
                                  _filterTransactions(transactions);
                              _exportCsv(filtered);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              _buildSummaryCard(allTransactions),
              _buildFilterControls(),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Transactions (${filteredTransactions.length})',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (_selectedType != 'ALL' || _symbolQuery.isNotEmpty)
                      TextButton(
                        child: const Text('Reset Filters'),
                        onPressed: () {
                          setState(() {
                            _selectedType = 'ALL';
                            _symbolQuery = '';
                            _applyPreset('3M');
                          });
                          _loadTransactions();
                        },
                      ),
                  ],
                ),
              ),
              if (filteredTransactions.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'No transactions found for the selected criteria.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...filteredTransactions.map((tx) => _buildTransactionTile(tx)),
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
        title: const Text('Schwab Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Transactions',
            onPressed: _loadTransactions,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export CSV',
            onPressed: () async {
              final transactions = await _futureTransactions;
              final filtered = _filterTransactions(transactions);
              _exportCsv(filtered);
            },
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildSummaryCard(List<SchwabTransaction> transactions) {
    double totalNet = 0;
    double totalDividends = 0;
    double totalFees = 0;
    int tradeCount = 0;

    for (final tx in transactions) {
      totalNet += tx.netAmount;
      if (tx.isDividendOrInterest) {
        totalDividends += tx.netAmount;
      }
      totalFees += tx.totalFees;
      if (tx.isTrade) {
        tradeCount++;
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Account Activity Summary',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _datePreset,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    'Net Cash Flow',
                    currencyFormat.format(totalNet),
                    color: totalNet >= 0 ? Colors.green : Colors.redAccent,
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    'Dividends & Income',
                    currencyFormat.format(totalDividends),
                    color: totalDividends > 0 ? Colors.green : null,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    'Trades Executed',
                    '$tradeCount',
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    'Fees & Commissions',
                    currencyFormat.format(totalFees),
                    color: totalFees > 0 ? Colors.orange : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search box
          TextField(
            decoration: InputDecoration(
              hintText: 'Search by symbol or description...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _symbolQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _symbolQuery = '';
                        });
                      },
                    )
                  : null,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onChanged: (val) {
              setState(() {
                _symbolQuery = val.trim();
              });
            },
          ),
          const SizedBox(height: 10),
          // Type filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 'ALL'),
                _buildFilterChip('Trades', 'TRADES'),
                _buildFilterChip('Income', 'INCOME'),
                _buildFilterChip('Cash & Transfers', 'CASH'),
                _buildFilterChip('Fees', 'FEES'),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Date range preset chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...['1M', '3M', '6M', 'YTD', '1Y'].map(
                  (preset) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(preset),
                      selected: _datePreset == preset,
                      onSelected: (selected) {
                        if (selected) {
                          _applyPreset(preset);
                          _loadTransactions();
                        }
                      },
                    ),
                  ),
                ),
                ActionChip(
                  avatar: const Icon(Icons.calendar_today, size: 16),
                  label: Text(_selectedDateRange != null &&
                          _datePreset == 'Custom'
                      ? '${shortDateFormat.format(_selectedDateRange!.start)} - ${shortDateFormat.format(_selectedDateRange!.end)}'
                      : 'Custom Range'),
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      initialDateRange: _selectedDateRange,
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedDateRange = picked;
                        _datePreset = 'Custom';
                      });
                      _loadTransactions();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedType == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedType = value;
          });
        },
      ),
    );
  }

  Widget _buildTransactionTile(SchwabTransaction tx) {
    IconData icon;
    Color iconColor;

    if (tx.isTrade) {
      icon = Icons.swap_horiz;
      iconColor = Colors.blue;
    } else if (tx.isDividendOrInterest) {
      icon = tx.isDividend ? Icons.paid : Icons.savings;
      iconColor = Colors.green;
    } else if (tx.isCashMovement) {
      icon = Icons.account_balance;
      iconColor = Colors.teal;
    } else {
      icon = Icons.receipt_long;
      iconColor = Colors.grey;
    }

    final title =
        tx.primarySymbol != null ? '${tx.type} • ${tx.primarySymbol}' : tx.type;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: iconColor.withAlpha(35),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dateFormat.format(tx.time)),
          if (tx.description != null && tx.description!.isNotEmpty)
            Text(
              tx.description!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          if (tx.totalFees > 0)
            Text(
              'Fees: ${currencyFormat.format(tx.totalFees)}',
              style: const TextStyle(fontSize: 11, color: Colors.orange),
            ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${tx.netAmount >= 0 ? "+" : ""}${currencyFormat.format(tx.netAmount)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: tx.netAmount >= 0 ? Colors.green : Colors.redAccent,
            ),
          ),
          if (tx.positionEffect != null)
            Text(
              tx.positionEffect!,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            )
          else if (tx.status.isNotEmpty)
            Text(
              tx.status,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
        ],
      ),
      onTap: () => _showTransactionDetails(tx),
    );
  }

  void _showTransactionDetails(SchwabTransaction tx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return SafeArea(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Transaction Detail',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  _buildDetailRow('Activity ID', tx.activityId.toString()),
                  _buildDetailRow('Account Number', tx.accountNumber),
                  _buildDetailRow('Type', tx.type),
                  _buildDetailRow('Status', tx.status),
                  _buildDetailRow('Sub Account', tx.subAccount),
                  _buildDetailRow('Time', dateFormat.format(tx.time)),
                  if (tx.tradeDate != null)
                    _buildDetailRow(
                        'Trade Date', dateFormat.format(tx.tradeDate!)),
                  if (tx.settlementDate != null)
                    _buildDetailRow('Settlement Date',
                        dateFormat.format(tx.settlementDate!)),
                  if (tx.orderId != null)
                    _buildDetailRow('Order ID', tx.orderId.toString()),
                  if (tx.positionId != null)
                    _buildDetailRow('Position ID', tx.positionId.toString()),
                  _buildDetailRow(
                    'Net Amount',
                    '${tx.netAmount >= 0 ? "+" : ""}${currencyFormat.format(tx.netAmount)}',
                    color: tx.netAmount >= 0 ? Colors.green : Colors.redAccent,
                  ),
                  if (tx.commission > 0)
                    _buildDetailRow(
                        'Commission', currencyFormat.format(tx.commission)),
                  if (tx.regulatoryFees > 0)
                    _buildDetailRow('Regulatory Fees',
                        currencyFormat.format(tx.regulatoryFees)),
                  if (tx.description != null)
                    _buildDetailRow('Description', tx.description!),
                  const SizedBox(height: 16),
                  if (tx.transferItems.isNotEmpty) ...[
                    Text(
                      'Transfer Items (${tx.transferItems.length})',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    ...tx.transferItems.map((item) {
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    item.instrument.symbol.isNotEmpty
                                        ? item.instrument.symbol
                                        : item.instrument.assetType,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  if (item.feeType != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withAlpha(30),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        item.feeType!,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              if (item.instrument.description != null)
                                Text(
                                  item.instrument.description!,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600),
                                ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Amount: ${item.amount}'),
                                  if (item.price != null)
                                    Text(
                                        'Price: ${currencyFormat.format(item.price)}'),
                                  Text(
                                    'Cost: ${currencyFormat.format(item.cost)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              if (item.positionEffect != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Effect: ${item.positionEffect}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade500),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
