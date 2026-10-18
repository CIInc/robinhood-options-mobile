import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/insider_sentiment.dart';
import 'package:robinhood_options_mobile/model/insider_transaction.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/yahoo_service.dart';

class InsiderActivityWidget extends StatefulWidget {
  final BrokerageUser? brokerageUser;
  final IBrokerageService? service;
  final Instrument? instrument;
  final String symbol;
  final Future<List<InsiderTransaction>>? futureInsiderTransactions;
  final InsiderSentimentSummary? preloadedSummary;

  const InsiderActivityWidget({
    super.key,
    this.brokerageUser,
    this.service,
    this.instrument,
    required this.symbol,
    this.futureInsiderTransactions,
    this.preloadedSummary,
  });

  @override
  State<InsiderActivityWidget> createState() => _InsiderActivityWidgetState();
}

class _InsiderActivityWidgetState extends State<InsiderActivityWidget> {
  final YahooService _yahooService = YahooService();
  Future<InsiderSentimentSummary?>? _future;

  final NumberFormat _compactNumberFormat = NumberFormat.compact();
  final NumberFormat _currencyFormat =
      NumberFormat.simpleCurrency(decimalDigits: 2);
  final DateFormat _dateFormat = DateFormat('MMM d, yyyy');

  @override
  void initState() {
    super.initState();
    if (widget.preloadedSummary != null) {
      _future = Future.value(widget.preloadedSummary);
    } else {
      _loadData();
    }
  }

  @override
  void didUpdateWidget(covariant InsiderActivityWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.instrument?.id != widget.instrument?.id ||
        oldWidget.symbol != widget.symbol ||
        oldWidget.preloadedSummary != widget.preloadedSummary) {
      if (widget.preloadedSummary != null) {
        _future = Future.value(widget.preloadedSummary);
      } else {
        _loadData();
      }
    }
  }

  void _loadData() {
    setState(() {
      _future = _fetchInsiderData();
    });
  }

  Future<InsiderSentimentSummary?> _fetchInsiderData() async {
    // 1. Try first-party Robinhood market data if brokerageUser & service are available
    if (widget.brokerageUser != null &&
        widget.service != null &&
        widget.instrument != null) {
      try {
        final responses = await Future.wait([
          widget.service!
              .getInsiderSummary(widget.brokerageUser!, widget.instrument!.id)
              .catchError((e) {
            debugPrint('getInsiderSummary error: $e');
            return null;
          }),
          widget.service!
              .getInsiderTransactions(
                  widget.brokerageUser!, widget.instrument!.id)
              .catchError((e) {
            debugPrint('getInsiderTransactions error: $e');
            return null;
          }),
        ]);

        final summaryResp = responses[0];
        final txResp = responses[1];

        if (summaryResp != null || txResp != null) {
          final summary = InsiderSentimentSummary.fromResponses(
            summaryResponse: summaryResp,
            transactionsResponse: txResp,
            instrumentId: widget.instrument!.id,
            symbol: widget.instrument!.symbol,
          );
          if (summary.transactions.isNotEmpty ||
              summary.totalBuyShares > 0 ||
              summary.totalSellShares > 0) {
            return summary;
          }
        }
      } catch (e) {
        debugPrint('Error fetching first-party insider data: $e');
      }
    }

    // 2. Legacy fallback: futureInsiderTransactions or YahooService
    try {
      final Future<List<InsiderTransaction>> txFuture =
          widget.futureInsiderTransactions ??
              _yahooService.getInsiderTransactions(widget.symbol);
      final legacyList = await txFuture;

      if (legacyList.isNotEmpty) {
        final records = legacyList.map((t) => t.toRecord()).toList();
        return InsiderSentimentSummary.fromResponses(
          transactionsResponse: records
              .map((r) => {
                    'filer_name': r.filerName,
                    'relationship': r.relationship,
                    'transaction_date': r.transactionDate?.toIso8601String(),
                    'transaction_type': r.transactionType,
                    'transaction_code': r.transactionCode,
                    'shares': r.shares,
                    'price': r.price,
                    'value': r.value,
                    'sec_form4_url': r.secForm4Url,
                  })
              .toList(),
          instrumentId: widget.instrument?.id ?? widget.symbol,
          symbol: widget.symbol,
        );
      }
    } catch (e) {
      debugPrint('Error fetching legacy insider data: $e');
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<InsiderSentimentSummary?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Card(
              child: ListTile(
                leading: Icon(Icons.error_outline,
                    color: Theme.of(context).colorScheme.error),
                title: const Text('Insider activity unavailable'),
                subtitle: Text('${snapshot.error}'),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadData,
                ),
              ),
            ),
          );
        }

        final summary = snapshot.data;
        if (summary == null ||
            (summary.transactions.isEmpty &&
                summary.totalBuyShares == 0 &&
                summary.totalSellShares == 0)) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              context: context,
              title: 'Insider Sentiment',
              icon: Icons.badge_outlined,
              trailing: IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
                tooltip: 'Refresh insider activity',
                onPressed: _loadData,
              ),
            ),
            Card(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              elevation: 0,
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.25),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.4),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBadges(context, summary),
                    const SizedBox(height: 14),
                    _buildSplitBar(context, summary),
                    const SizedBox(height: 14),
                    _buildMetricsRow(context, summary),
                    if (summary.monthlySummary.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _buildMonthlySummary(context, summary),
                    ],
                    if (summary.transactions.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      _buildTransactionsList(context, summary),
                    ],
                    const SizedBox(height: 14),
                    _buildEducationalCard(context),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader({
    required BuildContext context,
    required String title,
    Widget? trailing,
    String? subtitle,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 2.0),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 19,
                      ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildBadges(BuildContext context, InsiderSentimentSummary summary) {
    Color badgeColor;
    IconData badgeIcon;

    if (summary.isBullish) {
      badgeColor = Colors.green;
      badgeIcon = Icons.trending_up;
    } else if (summary.isBearish) {
      badgeColor = Colors.red;
      badgeIcon = Icons.trending_down;
    } else {
      badgeColor = Colors.grey;
      badgeIcon = Icons.remove;
    }

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: badgeColor.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(badgeIcon, size: 14, color: badgeColor),
              const SizedBox(width: 4),
              Text(
                summary.sentimentBadge,
                style: TextStyle(
                  color: badgeColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Text(
            'Net Flow: ${summary.formattedNetValue}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: summary.isBullish
                  ? Colors.green.shade700
                  : (summary.isBearish
                      ? Colors.red.shade700
                      : Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSplitBar(BuildContext context, InsiderSentimentSummary summary) {
    final buyPct = summary.buyPercentage.clamp(0.0, 100.0);
    final sellPct = summary.sellPercentage.clamp(0.0, 100.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'Buys: ${buyPct.toStringAsFixed(1)}% (${summary.formattedTotalBuyValue})',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Sells: ${sellPct.toStringAsFixed(1)}% (${summary.formattedTotalSellValue})',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                Expanded(
                  flex: (buyPct * 10).round().clamp(1, 1000),
                  child: Container(color: Colors.green),
                ),
                Expanded(
                  flex: (sellPct * 10).round().clamp(1, 1000),
                  child: Container(color: Colors.red),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsRow(
      BuildContext context, InsiderSentimentSummary summary) {
    final netColor = summary.netValue > 0
        ? Colors.green.shade700
        : (summary.netValue < 0 ? Colors.red.shade700 : Colors.grey.shade700);

    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            context,
            title: 'Net Bias',
            value: summary.formattedNetValue,
            valueColor: netColor,
            subtitle: summary.formattedNetShares,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricTile(
            context,
            title: 'Purchases',
            value: summary.formattedTotalBuyValue,
            valueColor: Colors.green.shade700,
            subtitle:
                '${summary.buyCount} buys (${_compactNumberFormat.format(summary.totalBuyShares)} sh)',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricTile(
            context,
            title: 'Sales',
            value: summary.formattedTotalSellValue,
            valueColor: Colors.red.shade700,
            subtitle:
                '${summary.sellCount} sells (${_compactNumberFormat.format(summary.totalSellShares)} sh)',
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required String title,
    required String value,
    Color? valueColor,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: valueColor ?? Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: Colors.grey,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlySummary(
      BuildContext context, InsiderSentimentSummary summary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Monthly Aggregate Trend',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: summary.monthlySummary.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final m = summary.monthlySummary[index];
              final isPositive = m.netValue > 0 || m.buyValue > m.sellValue;
              final isNegative = m.netValue < 0 || m.sellValue > m.buyValue;
              final chipColor = isPositive
                  ? Colors.green.withValues(alpha: 0.12)
                  : (isNegative
                      ? Colors.red.withValues(alpha: 0.12)
                      : Colors.grey.withValues(alpha: 0.12));
              final textColor = isPositive
                  ? Colors.green.shade800
                  : (isNegative ? Colors.red.shade800 : Colors.grey.shade800);

              final fmtVal =
                  NumberFormat.compactSimpleCurrency().format(m.netValue.abs());
              final sign = m.netValue > 0 ? '+' : (m.netValue < 0 ? '-' : '');

              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: chipColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      m.formattedMonth,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$sign$fmtVal',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionsList(
      BuildContext context, InsiderSentimentSummary summary) {
    final previewTxs = summary.transactions.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Recent Form 4 Transactions',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (summary.transactions.length > 4) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => _showAllTransactionsModal(context, summary),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(60, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('View All (${summary.transactions.length})'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        ListView.separated(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: previewTxs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            return _buildTransactionRow(context, previewTxs[index]);
          },
        ),
      ],
    );
  }

  Widget _buildTransactionRow(
      BuildContext context, InsiderTransactionRecord t) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: t.typeColor.withValues(alpha: 0.12),
            child: Icon(t.typeIcon, color: t.typeColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.filerName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: t.typeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        t.displayType,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: t.typeColor,
                        ),
                      ),
                    ),
                    if (t.relationship.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '• ${t.relationship}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_compactNumberFormat.format(t.shares)} sh',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: t.typeColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                t.value != null
                    ? NumberFormat.compactSimpleCurrency().format(t.value)
                    : (t.price != null
                        ? '@ ${_currencyFormat.format(t.price)}'
                        : (t.transactionDate != null
                            ? _dateFormat.format(t.transactionDate!)
                            : '')),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAllTransactionsModal(
      BuildContext context, InsiderSentimentSummary summary) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _AllInsiderTransactionsSheet(summary: summary);
      },
    );
  }

  Widget _buildEducationalCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'SEC Form 4 transactions reflect moves by corporate officers, directors, and 10%+ owners. Routine executive sales often follow Rule 10b5-1 pre-scheduled plans, whereas open-market purchases typically signal strong insider confidence.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.3,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllInsiderTransactionsSheet extends StatefulWidget {
  final InsiderSentimentSummary summary;

  const _AllInsiderTransactionsSheet({required this.summary});

  @override
  State<_AllInsiderTransactionsSheet> createState() =>
      _AllInsiderTransactionsSheetState();
}

class _AllInsiderTransactionsSheetState
    extends State<_AllInsiderTransactionsSheet> {
  String _selectedFilter = 'All';
  final NumberFormat _compactNumberFormat = NumberFormat.compact();
  final NumberFormat _currencyFormat =
      NumberFormat.simpleCurrency(decimalDigits: 2);
  final DateFormat _dateFormat = DateFormat('MMM d, yyyy');

  @override
  Widget build(BuildContext context) {
    final filtered = widget.summary.transactions.where((t) {
      if (_selectedFilter == 'Purchases') return t.isBuy;
      if (_selectedFilter == 'Sales') return t.isSale;
      if (_selectedFilter == 'Options') return t.isOption;
      if (_selectedFilter == 'Grants') return t.isGrant;
      return true;
    }).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, controller) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'All Insider Activity (${widget.summary.transactions.length})',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _filterChip('All', widget.summary.transactions.length),
                  const SizedBox(width: 8),
                  _filterChip('Purchases',
                      widget.summary.transactions.where((t) => t.isBuy).length),
                  const SizedBox(width: 8),
                  _filterChip(
                      'Sales',
                      widget.summary.transactions
                          .where((t) => t.isSale)
                          .length),
                  const SizedBox(width: 8),
                  _filterChip(
                      'Options',
                      widget.summary.transactions
                          .where((t) => t.isOption)
                          .length),
                  const SizedBox(width: 8),
                  _filterChip(
                      'Grants',
                      widget.summary.transactions
                          .where((t) => t.isGrant)
                          .length),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No transactions found for filter "$_selectedFilter"',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  : ListView.separated(
                      controller: controller,
                      padding: const EdgeInsets.only(bottom: 24, top: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final t = filtered[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                t.typeColor.withValues(alpha: 0.12),
                            child:
                                Icon(t.typeIcon, color: t.typeColor, size: 20),
                          ),
                          title: Text(
                            t.filerName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${t.displayType} • ${t.relationship}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              if (t.transactionDate != null)
                                Text(
                                  'Date: ${_dateFormat.format(t.transactionDate!)}${t.filingDate != null ? ' (Filed ${_dateFormat.format(t.filingDate!)})' : ''}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          fontSize: 11, color: Colors.grey),
                                ),
                              if (t.sharesHeldAfter != null)
                                Text(
                                  'Post-trade: ${_compactNumberFormat.format(t.sharesHeldAfter)} shares (${t.isDirect ? 'Direct' : 'Indirect'})',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          fontSize: 11, color: Colors.grey),
                                ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${_compactNumberFormat.format(t.shares)} sh',
                                style: TextStyle(
                                  color: t.typeColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              if (t.value != null)
                                Text(
                                  NumberFormat.compactSimpleCurrency()
                                      .format(t.value),
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500),
                                ),
                              if (t.price != null)
                                Text(
                                  '@ ${_currencyFormat.format(t.price)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(fontSize: 10),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _filterChip(String label, int count) {
    final isSelected = _selectedFilter == label;
    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilter = label;
          });
        }
      },
    );
  }
}
