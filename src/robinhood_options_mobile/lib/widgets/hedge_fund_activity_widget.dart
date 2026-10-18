import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/hedge_fund_sentiment.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';

class HedgeFundActivityWidget extends StatefulWidget {
  final BrokerageUser? brokerageUser;
  final IBrokerageService? service;
  final Instrument? instrument;
  final String symbol;
  final HedgeFundSummary? preloadedSummary;

  const HedgeFundActivityWidget({
    super.key,
    this.brokerageUser,
    this.service,
    this.instrument,
    required this.symbol,
    this.preloadedSummary,
  });

  @override
  State<HedgeFundActivityWidget> createState() =>
      _HedgeFundActivityWidgetState();
}

class _HedgeFundActivityWidgetState extends State<HedgeFundActivityWidget> {
  Future<HedgeFundSummary?>? _future;

  final NumberFormat _compactNumberFormat = NumberFormat.compact();
  final NumberFormat _currencyFormat =
      NumberFormat.simpleCurrency(decimalDigits: 0);
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
  void didUpdateWidget(covariant HedgeFundActivityWidget oldWidget) {
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
      _future = _fetchHedgeFundData();
    });
  }

  Future<HedgeFundSummary?> _fetchHedgeFundData() async {
    if (widget.brokerageUser != null &&
        widget.service != null &&
        widget.instrument != null) {
      try {
        final responses = await Future.wait([
          widget.service!
              .getHedgeFundSummary(widget.brokerageUser!, widget.instrument!.id)
              .catchError((e) {
            debugPrint('getHedgeFundSummary error: $e');
            return null;
          }),
          widget.service!
              .getHedgeFundTransactions(
                  widget.brokerageUser!, widget.instrument!.id)
              .catchError((e) {
            debugPrint('getHedgeFundTransactions error: $e');
            return null;
          }),
        ]);

        final summaryResp = responses[0];
        final txResp = responses[1];

        if (summaryResp != null || txResp != null) {
          final summary = HedgeFundSummary.fromResponses(
            summaryResponse: summaryResp,
            transactionsResponse: txResp,
            instrumentId: widget.instrument!.id,
            symbol: widget.instrument!.symbol,
          );
          if (summary.transactions.isNotEmpty ||
              summary.totalSharesHeld > 0 ||
              summary.totalManagersCount > 0) {
            return summary;
          }
        }
      } catch (e) {
        debugPrint('Error fetching hedge fund data: $e');
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HedgeFundSummary?>(
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
                title: const Text('Hedge fund data unavailable'),
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
                summary.totalSharesHeld <= 0 &&
                summary.totalManagersCount <= 0)) {
          return const SizedBox.shrink();
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final buyColor = isDark ? Colors.greenAccent : Colors.green.shade700;
        final sellColor = isDark ? Colors.redAccent : Colors.red.shade700;

        final buyersPct = summary.buyersPercentage;
        final sellersPct = summary.sellersPercentage;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 2.0),
              child: Row(
                children: [
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
                      Icons.account_balance,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Hedge Fund Sentiment',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Refresh hedge fund data',
                    onPressed: _loadData,
                  ),
                ],
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
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badges
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color:
                                summary.sentimentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color:
                                  summary.sentimentColor.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                summary.isBullish
                                    ? Icons.trending_up
                                    : summary.isBearish
                                        ? Icons.trending_down
                                        : Icons.swap_horiz,
                                size: 13,
                                color: summary.sentimentColor,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                summary.sentimentBadge,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: summary.sentimentColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(
                            'Net Flow: ${summary.formattedNetValue}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: summary.netValueChanged > 0
                                  ? buyColor
                                  : (summary.netValueChanged < 0
                                      ? sellColor
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Managers Buy vs Sell Split Bar
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Buyers: ${summary.buyingManagersCount} (${buyersPct.toStringAsFixed(1)}%)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: buyColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Sellers: ${summary.sellingManagersCount} (${sellersPct.toStringAsFixed(1)}%)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: sellColor,
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
                                  flex: (buyersPct * 10).round().clamp(1, 999),
                                  child: Container(color: buyColor),
                                ),
                                const SizedBox(width: 2),
                                Expanded(
                                  flex: (sellersPct * 10).round().clamp(1, 999),
                                  child: Container(color: sellColor),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Key Metrics Grid
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isCompact = constraints.maxWidth < 340;
                        if (isCompact) {
                          return Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildMetricTile(
                                      context,
                                      title: 'Net Flow',
                                      value: summary.formattedNetValue,
                                      color: summary.netValueChanged > 0
                                          ? buyColor
                                          : (summary.netValueChanged < 0
                                              ? sellColor
                                              : null),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildMetricTile(
                                      context,
                                      title: 'Held Value',
                                      value: summary.formattedTotalValueHeld,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildMetricTile(
                                      context,
                                      title: 'Total Funds',
                                      value: '${summary.totalManagersCount}',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildMetricTile(
                                      context,
                                      title: 'Ownership',
                                      value: summary
                                                  .institutionalOwnershipPercentage !=
                                              null
                                          ? '${summary.institutionalOwnershipPercentage!.toStringAsFixed(1)}%'
                                          : '-',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(
                              child: _buildMetricTile(
                                context,
                                title: 'Net Flow',
                                value: summary.formattedNetValue,
                                color: summary.netValueChanged > 0
                                    ? buyColor
                                    : (summary.netValueChanged < 0
                                        ? sellColor
                                        : null),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildMetricTile(
                                context,
                                title: 'Held Value',
                                value: summary.formattedTotalValueHeld,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildMetricTile(
                                context,
                                title: 'Total Funds',
                                value: '${summary.totalManagersCount}',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildMetricTile(
                                context,
                                title: 'Ownership',
                                value: summary
                                            .institutionalOwnershipPercentage !=
                                        null
                                    ? '${summary.institutionalOwnershipPercentage!.toStringAsFixed(1)}%'
                                    : '-',
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    // Quarterly Aggregate Flow Chips
                    if (summary.quarterlySummary.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        'Quarterly Manager Trends',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 42,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: summary.quarterlySummary.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final q = summary.quarterlySummary[index];
                            final netVal = q.buyValue - q.sellValue;
                            final isPos = netVal >= 0;
                            final chipColor = isPos ? buyColor : sellColor;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: chipColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: chipColor.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        q.quarter,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${netVal >= 0 ? '+' : ''}${_compactNumberFormat.format(netVal)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: chipColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${q.buyingManagersCount}B / ${q.sellingManagersCount}S',
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

                    // Top Institutional Holdings / Transactions List
                    if (summary.transactions.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'Top Institutional Filings',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (summary.transactions.length > 3)
                            TextButton(
                              style: TextButton.styleFrom(
                                minimumSize: Size.zero,
                                padding: EdgeInsets.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () =>
                                  _showAllTransactionsModal(context, summary),
                              child: const Text('View All'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: summary.transactions.length.clamp(0, 3),
                        separatorBuilder: (context, index) =>
                            const Divider(height: 12),
                        itemBuilder: (context, index) {
                          final tx = summary.transactions[index];
                          return _buildTransactionTile(context, tx);
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required String title,
    required String value,
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color ?? Theme.of(context).colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(
      BuildContext context, HedgeFundTransactionRecord tx) {
    final sharesFmt = _compactNumberFormat.format(tx.sharesHeld);
    final valFmt = tx.value != null ? _currencyFormat.format(tx.value!) : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: tx.typeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(tx.typeIcon, size: 16, color: tx.typeColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.managerName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  tx.fundName != null
                      ? (tx.reportDate != null
                          ? '${tx.fundName} • ${_dateFormat.format(tx.reportDate!)}'
                          : tx.fundName!)
                      : (tx.reportDate != null
                          ? _dateFormat.format(tx.reportDate!)
                          : (tx.quarter ?? 'Quarterly 13F Filing')),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 105),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$sharesFmt sh',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 3,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: tx.typeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tx.displayType,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: tx.typeColor,
                        ),
                      ),
                    ),
                    if (valFmt != null)
                      Text(
                        valFmt,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontSize: 9),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAllTransactionsModal(
      BuildContext context, HedgeFundSummary summary) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Hedge Fund Holdings (${summary.transactions.length})',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      Text(
                        summary.symbol ?? widget.symbol,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: summary.transactions.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 12),
                    itemBuilder: (context, index) {
                      final tx = summary.transactions[index];
                      return _buildTransactionTile(context, tx);
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
