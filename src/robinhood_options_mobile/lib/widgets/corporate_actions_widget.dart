import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/split.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
import 'package:robinhood_options_mobile/utils/json.dart';

/// Comprehensive dashboard for reviewing corporate action stock split payments,
/// forward/reverse ratio adjustments, and fractional share cash-in-lieu tracking.
class CorporateActionsWidget extends StatefulWidget {
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  final Account? account;
  final String? filterSymbol;
  final String? filterInstrumentId;

  const CorporateActionsWidget({
    super.key,
    required this.brokerageUser,
    required this.service,
    this.account,
    this.filterSymbol,
    this.filterInstrumentId,
  });

  @override
  State<CorporateActionsWidget> createState() => _CorporateActionsWidgetState();
}

class _CorporateActionsWidgetState extends State<CorporateActionsWidget> {
  Future<List<SplitPayment>>? _futurePayments;
  String _filterType = 'all'; // 'all', 'forward', 'reverse', 'cash_in_lieu'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.filterSymbol != null && widget.filterSymbol!.isNotEmpty) {
      _searchQuery = widget.filterSymbol!.toUpperCase();
      _searchController.text = _searchQuery;
    }
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadData() {
    setState(() {
      _futurePayments = widget.service
          .getSplitPaymentsModel(
            widget.brokerageUser,
            instrumentId: widget.filterInstrumentId,
          )
          .then((payments) async {
            _enrichPaymentsWithStore(payments);
            return payments;
          })
          .catchError((e) {
            debugPrint('Error loading corporate action split payments: $e');
            return <SplitPayment>[];
          });
    });
  }

  Future<void> _enrichPaymentsWithStore(List<SplitPayment> payments) async {
    final needsEnrichment = payments
        .where((p) => p.symbol.isEmpty || p.effectiveMultiplier == 1.0)
        .toList();
    if (needsEnrichment.isEmpty || !mounted) return;

    InstrumentStore? instrumentStore;
    try {
      instrumentStore = Provider.of<InstrumentStore>(context, listen: false);
    } catch (_) {}

    bool anyUpdated = false;
    for (int i = 0; i < payments.length; i++) {
      var p = payments[i];
      if (p.symbol.isNotEmpty && p.effectiveMultiplier != 1.0) continue;

      Instrument? match;
      if (instrumentStore != null) {
        if (p.instrumentId.isNotEmpty) {
          match = instrumentStore.items.firstWhereOrNull(
            (inst) =>
                inst.id == p.instrumentId ||
                inst.url == p.instrumentId ||
                (p.instrumentId.isNotEmpty &&
                    inst.url.contains(p.instrumentId)),
          );
        }
        if (match == null) {
          final oldInst = p.oldInstrumentId;
          final newInst = p.newInstrumentId;
          final splitUrl = p.splitUrl;
          match = instrumentStore.items.firstWhereOrNull(
            (inst) =>
                (oldInst.isNotEmpty && inst.id == oldInst) ||
                (newInst.isNotEmpty && inst.id == newInst) ||
                (splitUrl != null &&
                    (inst.splits == splitUrl || splitUrl.contains(inst.id))),
          );
        }
      }

      if (match != null && p.symbol.isEmpty) {
        p = p.copyWith(
          symbol: match.symbol,
          description: match.simpleName ?? match.name,
        );
        payments[i] = p;
        anyUpdated = true;
      } else if (p.symbol.isEmpty &&
          p.instrumentId.isNotEmpty &&
          instrumentStore != null) {
        try {
          final instUrl = p.instrumentId.startsWith('http')
              ? p.instrumentId
              : 'https://api.robinhood.com/instruments/${p.instrumentId}/';
          final fetched = await widget.service.getInstrument(
            widget.brokerageUser,
            instrumentStore,
            instUrl,
          );
          if (fetched.symbol.isNotEmpty) {
            match = fetched;
            p = p.copyWith(
              symbol: fetched.symbol,
              description: fetched.simpleName ?? fetched.name,
            );
            payments[i] = p;
            anyUpdated = true;
          }
        } catch (_) {}
      }

      // Enrich split multiplier and divisor if still 1.0
      if (p.effectiveMultiplier == 1.0) {
        if (p.split != null &&
            (p.split!.multiplier != 1.0 || p.split!.divisor != 1.0)) {
          p = p.copyWith(
            multiplier: p.split!.multiplier,
            divisor: p.split!.divisor,
            actionType: p.split!.multiplier > p.split!.divisor
                ? 'forward_split'
                : 'reverse_split',
          );
          payments[i] = p;
          anyUpdated = true;
        } else if (p.splitUrl != null && p.splitUrl!.isNotEmpty) {
          try {
            final splitJson = await RobinhoodService.getJson(
              widget.brokerageUser,
              p.splitUrl!,
            );
            if (splitJson is Map) {
              final sm = parseDouble(splitJson['multiplier']);
              final sd = parseDouble(splitJson['divisor']);
              if (sm != null && sd != null && (sm != 1.0 || sd != 1.0)) {
                final actionType = sm > sd ? 'forward_split' : 'reverse_split';
                p = p.copyWith(
                  multiplier: sm,
                  divisor: sd,
                  actionType: actionType,
                );
                payments[i] = p;
                anyUpdated = true;
              }
            }
          } catch (_) {}
        }
      }

      // Fallback to instrument splits if still 1.0
      if (p.effectiveMultiplier == 1.0 &&
          match != null &&
          match.splits.isNotEmpty) {
        try {
          final splits = await widget.service.getSplits(
            widget.brokerageUser,
            match,
          );
          if (splits.isNotEmpty) {
            dynamic matchSplit;
            if (p.executionDate != null) {
              matchSplit = splits.firstWhereOrNull((s) {
                if (s is! Map) return false;
                final d = DateTime.tryParse(
                  (s['execution_date'] ?? s['date'] ?? '').toString(),
                );
                if (d == null) return false;
                return d.year == p.executionDate!.year &&
                    d.month == p.executionDate!.month &&
                    (d.day - p.executionDate!.day).abs() <= 2;
              });
            }
            matchSplit ??= splits.first;
            if (matchSplit is Map) {
              final sm = parseDouble(matchSplit['multiplier']);
              final sd = parseDouble(matchSplit['divisor']);
              if (sm != null && sd != null && (sm != 1.0 || sd != 1.0)) {
                final actionType = sm > sd
                    ? 'forward_split'
                    : (sm < sd ? 'reverse_split' : p.actionType);
                p = p.copyWith(
                  multiplier: sm,
                  divisor: sd,
                  actionType: actionType,
                );
                payments[i] = p;
                anyUpdated = true;
              }
            }
          }
        } catch (_) {}
      }
    }

    if (anyUpdated && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Corporate Actions & Splits'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'About Corporate Actions & Splits',
            onPressed: () => _showInfoDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
      ),
      body: FutureBuilder<List<SplitPayment>>(
        future: _futurePayments,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allPayments = snapshot.data ?? [];
          final summary = CorporateActionSplitsSummary.fromPayments(
            allPayments,
          );

          // Apply filters
          final filteredPayments = allPayments.where((payment) {
            // Type filter
            if (_filterType == 'forward' && !payment.isForwardSplit) {
              return false;
            }
            if (_filterType == 'reverse' && !payment.isReverseSplit) {
              return false;
            }
            if (_filterType == 'cash_in_lieu' && !payment.hasCashInLieu) {
              return false;
            }

            // Search query filter
            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              final matchesSymbol =
                  payment.symbol.toLowerCase().contains(query) ||
                  payment.displaySymbol.toLowerCase().contains(query);
              final matchesDesc = (payment.description ?? '')
                  .toLowerCase()
                  .contains(query);
              final matchesId = payment.id.toLowerCase().contains(query);
              return matchesSymbol || matchesDesc || matchesId;
            }

            return true;
          }).toList();

          return RefreshIndicator(
            onRefresh: () async => _loadData(),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: _buildHeroSummary(context, summary),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: _buildSearchBar(context),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: _buildFilterChips(context, summary),
                  ),
                ),
                if (filteredPayments.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(context),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final payment = filteredPayments[index];
                        return _buildSplitCard(context, payment);
                      }, childCount: filteredPayments.length),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroSummary(
    BuildContext context,
    CorporateActionSplitsSummary summary,
  ) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                  child: const Icon(Icons.call_split, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stock Split Adjustments',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Audited corporate share conversions & cash-in-lieu',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    context,
                    label: 'Total Splits',
                    value: '${summary.totalSplitsCount}',
                    icon: Icons.history,
                  ),
                ),
                Container(
                  height: 36,
                  width: 1,
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    context,
                    label: 'Cash-in-Lieu',
                    value: summary.formattedTotalCashInLieu,
                    icon: Icons.attach_money,
                    valueColor: Colors.green.shade700,
                  ),
                ),
                Container(
                  height: 36,
                  width: 1,
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    context,
                    label: 'Fwd / Rev',
                    value:
                        '${summary.forwardSplitsCount} / ${summary.reverseSplitsCount}',
                    icon: Icons.swap_vert,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.3,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Stock splits adjust share quantity and per-share cost basis. Fractional shares are paid out as cash-in-lieu.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    Color? valueColor,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: valueColor ?? theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final theme = Theme.of(context);

    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search by symbol or description...',
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
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.3,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: (val) {
        setState(() {
          _searchQuery = val.trim();
        });
      },
    );
  }

  Widget _buildFilterChips(
    BuildContext context,
    CorporateActionSplitsSummary summary,
  ) {
    final filters = [
      {'key': 'all', 'label': 'All (${summary.totalSplitsCount})'},
      {'key': 'forward', 'label': 'Forward (${summary.forwardSplitsCount})'},
      {'key': 'reverse', 'label': 'Reverse (${summary.reverseSplitsCount})'},
      {'key': 'cash_in_lieu', 'label': 'With Cash-in-Lieu'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _filterType == f['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                f['label']!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _filterType = f['key']!;
                  });
                }
              },
              showCheckmark: false,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSplitCard(BuildContext context, SplitPayment payment) {
    final theme = Theme.of(context);
    final isForward = payment.isForwardSplit;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showSplitDetailsBottomSheet(context, payment),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: isForward
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.amber.withValues(alpha: 0.15),
                    foregroundColor: isForward
                        ? Colors.green.shade800
                        : Colors.amber.shade900,
                    child: Icon(
                      isForward ? Icons.call_split : Icons.merge_type,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              payment.displaySymbol,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isForward
                                    ? Colors.green.withValues(alpha: 0.12)
                                    : Colors.amber.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isForward
                                      ? Colors.green.withValues(alpha: 0.3)
                                      : Colors.amber.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                payment.shortRatioBadge,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isForward
                                      ? Colors.green.shade800
                                      : Colors.amber.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (payment.description != null &&
                            payment.description!.isNotEmpty &&
                            payment.description != payment.displaySymbol) ...[
                          const SizedBox(height: 2),
                          Text(
                            payment.description!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ] else ...[
                          const SizedBox(height: 2),
                          Text(
                            payment.isForwardSplit
                                ? 'Forward Stock Split'
                                : 'Reverse Stock Split',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Shares Converted',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '${payment.formattedOldShares} sh',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(Icons.arrow_forward, size: 14),
                            ),
                            Text(
                              '${payment.formattedNewShares} sh',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                payment.formattedSharesDelta,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isForward
                                      ? Colors.green.shade700
                                      : Colors.orange.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (payment.hasCashInLieu) ...[
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Cash-in-Lieu',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.green.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add,
                                size: 12,
                                color: Colors.green.shade700,
                              ),
                              Text(
                                payment.formattedCashInLieu,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Executed: ${payment.formattedExecutionDate}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: payment.isSettled
                          ? Colors.blue.withValues(alpha: 0.1)
                          : Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      payment.state.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: payment.isSettled
                            ? Colors.blue.shade800
                            : Colors.amber.shade900,
                      ),
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

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.call_split,
                size: 36,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Split Payments Found',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty || _filterType != 'all'
                  ? 'No corporate action splits match your active search or filters.'
                  : 'Your account has not experienced any corporate stock split adjustments or cash-in-lieu payments.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isNotEmpty || _filterType != 'all') ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('Clear Filters'),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _filterType = 'all';
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showSplitDetailsBottomSheet(
    BuildContext context,
    SplitPayment payment,
  ) {
    final theme = Theme.of(context);
    final isForward = payment.isForwardSplit;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: isForward
                            ? Colors.green.withValues(alpha: 0.15)
                            : Colors.amber.withValues(alpha: 0.15),
                        foregroundColor: isForward
                            ? Colors.green.shade800
                            : Colors.amber.shade900,
                        child: Icon(
                          isForward ? Icons.call_split : Icons.merge_type,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              payment.displaySymbol,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              payment.description?.isNotEmpty == true
                                  ? '${payment.description!} • ${payment.formattedRatio}'
                                  : '${payment.isForwardSplit ? "Forward" : "Reverse"} Stock Split • ${payment.formattedRatio}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: payment.isSettled
                              ? Colors.blue.withValues(alpha: 0.15)
                              : Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          payment.state.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: payment.isSettled
                                ? Colors.blue.shade800
                                : Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Conversion Mechanics',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    'Stock / Asset',
                    payment.displaySymbol,
                    isBold: true,
                  ),
                  if (payment.description != null &&
                      payment.description!.isNotEmpty)
                    _buildDetailRow(
                      'Company / Asset Name',
                      payment.description!,
                    ),
                  _buildDetailRow(
                    'Pre-Split Shares Held',
                    '${payment.formattedOldShares} sh',
                  ),
                  _buildDetailRow(
                    'Split Ratio',
                    '${payment.formattedSplitRatio} (${payment.formattedRatio})',
                  ),
                  _buildDetailRow(
                    'Post-Split Shares Credited',
                    '${payment.formattedNewShares} sh',
                  ),
                  _buildDetailRow(
                    'Share Count Adjustment',
                    payment.formattedSharesDelta,
                  ),
                  if (payment.hasCashInLieu) ...[
                    const Divider(height: 16),
                    _buildDetailRow(
                      'Cash-in-Lieu (CIL) Paid',
                      payment.formattedCashInLieu,
                      valueColor: Colors.green.shade700,
                      isBold: true,
                    ),
                    _buildDetailRow('Currency', payment.currencyCode),
                  ],
                  const Divider(height: 16),
                  Text(
                    'Dates & Accounting',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    'Execution Date',
                    payment.formattedExecutionDate,
                  ),
                  _buildDetailRow(
                    'Settlement Date',
                    payment.formattedPaymentDate,
                  ),
                  if (payment.accountNumber.isNotEmpty)
                    _buildDetailRow('Account Number', payment.accountNumber),
                  if (payment.instrumentId.isNotEmpty)
                    _buildDetailRow(
                      'Instrument ID',
                      payment.shortInstrumentId.isNotEmpty
                          ? payment.shortInstrumentId
                          : payment.instrumentId,
                    ),
                  if (payment.split?.id.isNotEmpty == true)
                    _buildDetailRow('Split Definition ID', payment.split!.id),
                  if (payment.id.isNotEmpty)
                    _buildDetailRow('Audit Record ID', payment.id),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.3,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.gavel,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Tax & Basis Reporting',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Stock splits do not trigger capital gains tax on whole converted shares; your total cost basis remains unchanged while per-share basis adjusts proportionally. However, cash-in-lieu received for fractional shares is treated as a taxable distribution reported on Form 1099-B (Box 1d).',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            flex: 5,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.call_split),
              SizedBox(width: 8),
              Text('Corporate Actions FAQ'),
            ],
          ),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'What is a Forward Stock Split?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'A forward split (e.g. 10:1 or 4:1) increases share count while proportionately lowering the share price. The overall position market value remains identical.',
                ),
                SizedBox(height: 12),
                Text(
                  'What is a Reverse Stock Split?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'A reverse split (e.g. 1:10 or 1:25) consolidates shares into fewer shares with a higher per-share price, often used to meet exchange listing standards.',
                ),
                SizedBox(height: 12),
                Text(
                  'What is Cash-in-Lieu (CIL)?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'When a split cannot divide fractional holdings into whole shares, the fractional remainder is liquidated for cash and deposited directly into your brokerage account.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Got It'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }
}
