import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../model/brokerage_user.dart';
import '../model/congress_trade.dart';
import '../services/congress_trading_service.dart';

class CongressTradingDashboardWidget extends StatefulWidget {
  final BrokerageUser? brokerageUser;
  final List<String>? userPortfolioSymbols;
  final String? initialSymbol;
  final CongressTradingSnapshot? preloadedSnapshot;
  final CongressTradingService? service;

  const CongressTradingDashboardWidget({
    super.key,
    this.brokerageUser,
    this.userPortfolioSymbols,
    this.initialSymbol,
    this.preloadedSnapshot,
    this.service,
  });

  @override
  State<CongressTradingDashboardWidget> createState() =>
      _CongressTradingDashboardWidgetState();
}

class _CongressTradingDashboardWidgetState
    extends State<CongressTradingDashboardWidget> {
  late final CongressTradingService _service =
      widget.service ?? CongressTradingService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedChamber = 'All';
  String _selectedParty = 'All';
  String _selectedType = 'All';
  bool _portfolioOnly = false;

  late Future<CongressTradingSnapshot> _future;

  @override
  void initState() {
    super.initState();
    if (widget.initialSymbol != null && widget.initialSymbol!.isNotEmpty) {
      _searchController.text = widget.initialSymbol!;
      _searchQuery = widget.initialSymbol!;
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
      _future = widget.preloadedSnapshot != null
          ? Future.value(widget.preloadedSnapshot)
          : _service.getTrades(
              chamber: _selectedChamber != 'All' ? _selectedChamber : null,
              party: _selectedParty != 'All' ? _selectedParty : null,
              transactionType: _selectedType != 'All' ? _selectedType : null,
              userPortfolioSymbols: widget.userPortfolioSymbols,
            );
    });
  }

  Future<void> _openFiling(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open congressional disclosure.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Congress Trading Tracker'),
        actions: [
          IconButton(
            tooltip: 'Refresh disclosures',
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: FutureBuilder<CongressTradingSnapshot>(
        future: _future,
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
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load congressional trading disclosures',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style: Theme.of(context).textTheme.bodySmall,
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

          final data = snapshot.data!;
          final upperUserSymbols = (widget.userPortfolioSymbols ?? const [])
              .map((s) => s.toUpperCase())
              .toSet();

          // Apply local search and portfolio-only filtering
          var filteredTrades = data.trades.where((t) {
            if (_portfolioOnly && !upperUserSymbols.contains(t.symbol)) {
              return false;
            }
            if (_searchQuery.isNotEmpty) {
              final q = _searchQuery.toLowerCase();
              final matchesSymbol = t.symbol.toLowerCase().contains(q);
              final matchesName = t.politicianName.toLowerCase().contains(q);
              final matchesDesc =
                  t.assetDescription.toLowerCase().contains(q);
              if (!matchesSymbol && !matchesName && !matchesDesc) {
                return false;
              }
            }
            return true;
          }).toList();

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // STOCK Act Info Header
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Under the STOCK Act of 2012, members of Congress must disclose stock transactions within 45 days. Tracking disclosures highlights potential legislative momentum and portfolio overlaps.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Metrics Summary
                      _buildMetricsRow(context, data, upperUserSymbols),
                      const SizedBox(height: 16),

                      // Search Bar
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search ticker, member of congress...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val.trim();
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      // Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            FilterChip(
                              avatar: const Icon(Icons.pie_chart_outline, size: 16),
                              label: const Text('My Portfolio Overlap'),
                              selected: _portfolioOnly,
                              onSelected: (val) {
                                setState(() {
                                  _portfolioOnly = val;
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            _buildChoiceMenuChip(
                              context: context,
                              label: 'Chamber: $_selectedChamber',
                              options: const ['All', 'House', 'Senate'],
                              selected: _selectedChamber,
                              onSelected: (val) {
                                setState(() {
                                  _selectedChamber = val;
                                  _loadData();
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            _buildChoiceMenuChip(
                              context: context,
                              label: 'Party: $_selectedParty',
                              options: const ['All', 'Democrat', 'Republican'],
                              selected: _selectedParty,
                              onSelected: (val) {
                                setState(() {
                                  _selectedParty = val;
                                  _loadData();
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            _buildChoiceMenuChip(
                              context: context,
                              label: 'Type: $_selectedType',
                              options: const ['All', 'Purchases', 'Sales'],
                              selected: _selectedType,
                              onSelected: (val) {
                                setState(() {
                                  _selectedType = val;
                                  _loadData();
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Active Result Count
                      Text(
                        'Showing ${filteredTrades.length} disclosed transactions',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ],
                  ),
                ),
              ),

              // Trade List
              if (filteredTrades.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 48,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No matching congressional trades found',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try adjusting your search query or filters.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final trade = filteredTrades[index];
                        final isHeld =
                            upperUserSymbols.contains(trade.symbol);
                        return _buildTradeCard(context, trade, isHeld);
                      },
                      childCount: filteredTrades.length,
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetricsRow(
    BuildContext context,
    CongressTradingSnapshot data,
    Set<String> userSymbols,
  ) {
    final currencyCompact =
        NumberFormat.compactSimpleCurrency(decimalDigits: 0);

    final overlapCount = data.trades
        .where((t) => userSymbols.contains(t.symbol))
        .map((t) => t.symbol)
        .toSet()
        .length;

    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            context,
            title: 'Tracked',
            value: '${data.totalTrades}',
            icon: Icons.receipt_long,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricTile(
            context,
            title: 'Buy Vol (Est)',
            value: currencyCompact.format(data.totalPurchases),
            icon: Icons.trending_up,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricTile(
            context,
            title: 'Sell Vol (Est)',
            value: currencyCompact.format(data.totalSales),
            icon: Icons.trending_down,
            color: Colors.red,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricTile(
            context,
            title: 'Held Overlap',
            value: '$overlapCount',
            icon: Icons.pie_chart,
            color: Colors.purple,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceMenuChip({
    required BuildContext context,
    required String label,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return PopupMenuButton<String>(
      initialValue: selected,
      onSelected: onSelected,
      itemBuilder: (context) {
        return options.map((opt) {
          return PopupMenuItem<String>(
            value: opt,
            child: Row(
              children: [
                if (opt == selected)
                  const Icon(Icons.check, size: 16)
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 8),
                Text(opt),
              ],
            ),
          );
        }).toList();
      },
      child: Chip(
        label: Text(label),
        deleteIcon: const Icon(Icons.arrow_drop_down, size: 18),
        onDeleted: () {}, // Triggers popup menu
      ),
    );
  }

  Widget _buildTradeCard(
    BuildContext context,
    CongressTrade trade,
    bool isHeldInPortfolio,
  ) {
    final dateFormat = DateFormat.yMMMd();
    final txDateStr = dateFormat.format(trade.transactionDate);
    final discDateStr = dateFormat.format(trade.disclosureDate);

    final isBuy = trade.transactionType.isPurchase;
    final badgeColor = isBuy ? Colors.green : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isHeldInPortfolio
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)
              : Theme.of(context).colorScheme.outlineVariant,
          width: isHeldInPortfolio ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Portfolio Overlap Tag
            if (isHeldInPortfolio) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.pie_chart_outline,
                      size: 14,
                      color:
                          Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Held in your portfolio',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Top Header: Politician & Party Pill
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: trade.party.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: trade.party.color.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    trade.politicalAffiliation,
                    style: TextStyle(
                      color: trade.party.color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trade.politicianTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        '${trade.chamber.displayName} · Owner: ${trade.owner}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    trade.transactionType.displayName,
                    style: TextStyle(
                      color: badgeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),

            // Ticker & Asset Info
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    trade.symbol,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trade.assetDescription,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Amount: ${trade.amount}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Dates & STOCK Act Lag
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Traded $txDateStr · Disclosed $discDateStr',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: trade.isOverdue
                        ? Colors.orange.withValues(alpha: 0.2)
                        : Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    trade.isOverdue
                        ? '⚠️ ${trade.filingLagDays}d lag (>45d limit)'
                        : '${trade.filingLagDays}d lag',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: trade.isOverdue ? Colors.orange.shade800 : null,
                    ),
                  ),
                ),
              ],
            ),
            if (trade.comment != null && trade.comment!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Notes: ${trade.comment}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ),

            // Footer Link
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _openFiling(trade.sourceUrl),
                icon: const Icon(Icons.open_in_new, size: 14),
                label: const Text('View Official PTR Filing'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
