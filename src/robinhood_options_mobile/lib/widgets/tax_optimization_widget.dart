import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/form_8949_model.dart';
import 'package:robinhood_options_mobile/model/instrument_order_store.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/option_order_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_analytics_controller.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals.dart';
import 'package:robinhood_options_mobile/model/tax_harvesting_suggestion.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/model/wash_sale_record.dart';
import 'package:robinhood_options_mobile/model/capital_gains_model.dart';
import 'package:robinhood_options_mobile/model/tax_lot.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/tax_optimization_service.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';
import 'package:robinhood_options_mobile/widgets/trade_instrument_widget.dart';
import 'package:share_plus/share_plus.dart';
// import 'package:robinhood_options_mobile/widgets/portfolio/analytics/esg_card.dart';

class TaxOptimizationWidget extends StatefulWidget {
  final BrokerageUser user;
  final IBrokerageService service;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final GenerativeService generativeService;
  final User? appUser;
  final DocumentReference<User>? userDocRef;
  final PortfolioHistoricals? portfolioHistoricals;
  final List<WashSaleRecord>? initialWashSales;
  final List<Form8949Entry>? initialForm8949Entries;
  final int initialTabIndex;
  final PortfolioAnalyticsController? analyticsController;

  const TaxOptimizationWidget({
    super.key,
    required this.user,
    required this.service,
    required this.analytics,
    required this.observer,
    required this.generativeService,
    required this.appUser,
    required this.userDocRef,
    this.portfolioHistoricals,
    this.initialWashSales,
    this.initialForm8949Entries,
    this.initialTabIndex = 0,
    this.analyticsController,
  });

  @override
  State<TaxOptimizationWidget> createState() => _TaxOptimizationWidgetState();
}

class _TaxOptimizationWidgetState extends State<TaxOptimizationWidget> {
  String _washSaleFilter = 'all'; // 'all', 'active', 'disallowed'
  String _assetFilter = 'all'; // 'all', 'stock', 'option'
  double _minLossThreshold = 0.0; // 0, 100, 500, 1000
  String _sortBy = 'loss'; // 'loss', 'percent', 'tax_savings'

  String _capitalGainsFilter =
      'all'; // 'all', 'short_term', 'long_term', 'approaching', 'gains'
  String _capitalGainsSortBy =
      'timer'; // 'timer', 'gain_loss', 'tax_savings', 'holding_period'
  double _shortTermTaxRate = 0.24; // 24% default
  double _longTermTaxRate = 0.15; // 15% default

  int? _form8949Year = DateTime.now().year;
  String _form8949Filter = 'all'; // 'all', 'short_term', 'long_term', 'wash_sales'

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final instrumentPositionStore =
        Provider.of<InstrumentPositionStore>(context);
    final optionPositionStore = Provider.of<OptionPositionStore>(context);

    InstrumentOrderStore? instrumentOrderStore;
    try {
      instrumentOrderStore = Provider.of<InstrumentOrderStore>(context);
    } catch (_) {}

    OptionOrderStore? optionOrderStore;
    try {
      optionOrderStore = Provider.of<OptionOrderStore>(context);
    } catch (_) {}

    final scanResult =
        TaxOptimizationService.scanTaxLossHarvestingOpportunities(
      instrumentPositions: instrumentPositionStore.items,
      optionPositions: optionPositionStore.items,
      portfolioHistoricals: widget.portfolioHistoricals,
      assetFilter: _assetFilter,
      minLossThreshold: _minLossThreshold,
      sortBy: _sortBy,
    );

    final allOpportunities =
        TaxOptimizationService.calculateTaxHarvestingOpportunities(
      instrumentPositions: instrumentPositionStore.items,
      optionPositions: optionPositionStore.items,
    );
    final stockCount = allOpportunities.where((s) => s.type == 'stock').length;
    final optionCount =
        allOpportunities.where((s) => s.type == 'option').length;

    final washSales = TaxOptimizationService.detectWashSales(
      stockOrders: instrumentOrderStore?.items.toList() ?? const [],
      optionOrders: optionOrderStore?.items.toList() ?? const [],
      instrumentPositions: instrumentPositionStore.items,
      optionPositions: optionPositionStore.items,
      initialRecords: widget.initialWashSales,
    );

    final capitalGainsSummary = TaxOptimizationService.analyzeCapitalGains(
      instrumentPositions: instrumentPositionStore.items,
      optionPositions: optionPositionStore.items,
      shortTermTaxRate: _shortTermTaxRate,
      longTermTaxRate: _longTermTaxRate,
    );

    final form8949Reconciliation = TaxOptimizationService.reconcileForm8949(
      stockOrders: instrumentOrderStore?.items.toList() ?? const [],
      optionOrders: optionOrderStore?.items.toList() ?? const [],
      washSales: washSales,
      initialEntries: widget.initialForm8949Entries,
      taxYear: _form8949Year,
    );

    final formatCurrency = NumberFormat.simpleCurrency();

    return DefaultTabController(
      length: 4,
      initialIndex: widget.initialTabIndex,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Taxes'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(
                icon: Icon(Icons.savings_outlined),
                text: 'Loss Harvesting',
              ),
              Tab(
                icon: Icon(Icons.schedule),
                text: 'Wash Sales',
              ),
              Tab(
                icon: Icon(Icons.pie_chart_outline),
                text: 'Capital Gains',
              ),
              Tab(
                icon: Icon(Icons.description_outlined),
                text: 'Form 8949',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildHarvestingTab(
              context,
              scanResult,
              allOpportunities.length,
              stockCount,
              optionCount,
              formatCurrency,
            ),
            _buildWashSalesTab(
              context,
              washSales,
              formatCurrency,
            ),
            _buildCapitalGainsTab(
              context,
              capitalGainsSummary,
              formatCurrency,
            ),
            _buildForm8949Tab(
              context,
              form8949Reconciliation,
              formatCurrency,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHarvestingTab(
    BuildContext context,
    TaxHarvestingScanResult scanResult,
    int totalCount,
    int stockCount,
    int optionCount,
    NumberFormat formatCurrency,
  ) {
    final suggestions = scanResult.suggestions;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSeasonalityBanner(context),
                const SizedBox(height: 16),
                _buildSummaryCard(context, scanResult, formatCurrency),
                const SizedBox(height: 20),
                _buildScannerFilterBar(
                  context,
                  totalCount: totalCount,
                  stockCount: stockCount,
                  optionCount: optionCount,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Opportunities (${suggestions.length})',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (scanResult.totalScannedPositions > 0)
                      Text(
                        '${scanResult.totalScannedPositions} scanned',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (suggestions.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                      'No tax harvesting opportunities matching filters.'),
                  if (_assetFilter != 'all' || _minLossThreshold > 0) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _assetFilter = 'all';
                          _minLossThreshold = 0.0;
                        });
                      },
                      child: const Text('Reset Filters'),
                    ),
                  ],
                ],
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final suggestion = suggestions[index];
                return _buildSuggestionCard(
                    context, suggestion, formatCurrency);
              },
              childCount: suggestions.length,
            ),
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
      ],
    );
  }

  Widget _buildWashSalesTab(
    BuildContext context,
    List<WashSaleRecord> washSales,
    NumberFormat formatCurrency,
  ) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildWashSaleTracker(context, washSales, formatCurrency),
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
      ],
    );
  }

  Widget _buildCapitalGainsTab(
    BuildContext context,
    CapitalGainsSummary summary,
    NumberFormat formatCurrency,
  ) {
    final theme = Theme.of(context);

    // Filter positions
    List<CapitalGainPosition> displayed = summary.allPositions.where((p) {
      if (_capitalGainsFilter == 'short_term') {
        return !p.isLongTerm;
      } else if (_capitalGainsFilter == 'long_term') {
        return p.isLongTerm;
      } else if (_capitalGainsFilter == 'approaching') {
        return p.qualifiesForLongTermSoon;
      } else if (_capitalGainsFilter == 'gains') {
        return p.gainLoss > 0;
      }
      return true;
    }).toList();

    // Sort positions
    displayed.sort((a, b) {
      if (_capitalGainsSortBy == 'timer') {
        if (a.isLongTerm && !b.isLongTerm) return 1;
        if (!a.isLongTerm && b.isLongTerm) return -1;
        return a.daysUntilLongTerm.compareTo(b.daysUntilLongTerm);
      } else if (_capitalGainsSortBy == 'gain_loss') {
        return b.gainLoss.compareTo(a.gainLoss);
      } else if (_capitalGainsSortBy == 'tax_savings') {
        return b.potentialTaxSavingsIfHeld
            .compareTo(a.potentialTaxSavingsIfHeld);
      } else if (_capitalGainsSortBy == 'holding_period') {
        return b.holdingDays.compareTo(a.holdingDays);
      }
      return 0;
    });

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCapitalGainsSummaryCard(context, summary, formatCurrency),
                const SizedBox(height: 12),
                if (summary.approachingLongTermPositions.isNotEmpty) ...[
                  _buildApproachingTimerBanner(
                      context, summary, formatCurrency),
                  const SizedBox(height: 12),
                ],
                _buildCapitalGainsFilterBar(context, summary),
              ],
            ),
          ),
        ),
        if (displayed.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.pie_chart_outline,
                      size: 64,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No positions found',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No open positions match the selected filter.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final pos = displayed[index];
                return _buildCapitalGainPositionCard(
                  context,
                  pos,
                  formatCurrency,
                );
              },
              childCount: displayed.length,
            ),
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
      ],
    );
  }

  Widget _buildCapitalGainsSummaryCard(
    BuildContext context,
    CapitalGainsSummary summary,
    NumberFormat formatCurrency,
  ) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.pie_chart, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Capital Gains & Tax Projection',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.tune, size: 20),
                  tooltip: 'Tax Bracket Rates',
                  onPressed: () => _showTaxBracketDialog(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                'Short-Term',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${(_shortTermTaxRate * 100).toInt()}%',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          formatCurrency.format(summary.shortTermNet),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: summary.shortTermNet >= 0
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Est. Tax: ${formatCurrency.format(summary.estimatedShortTermTaxLiability)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          'Holding: ≤ 365 Days (${summary.shortTermPositions.length} pos)',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                'Long-Term',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${(_longTermTaxRate * 100).toInt()}%',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          formatCurrency.format(summary.longTermNet),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: summary.longTermNet >= 0
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Est. Tax: ${formatCurrency.format(summary.estimatedLongTermTaxLiability)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          'Holding: > 365 Days (${summary.longTermPositions.length} pos)',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Total Projected Tax Liability:',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatCurrency.format(summary.totalEstimatedTaxLiability),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: summary.totalEstimatedTaxLiability > 0
                          ? Colors.orange
                          : theme.colorScheme.onSurface,
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

  Widget _buildApproachingTimerBanner(
    BuildContext context,
    CapitalGainsSummary summary,
    NumberFormat formatCurrency,
  ) {
    final theme = Theme.of(context);
    final approaching = summary.approachingLongTermPositions;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_outlined, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${approaching.length} ${approaching.length == 1 ? 'position' : 'positions'} nearing Long-Term status',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Hold these profitable positions until the 1-year mark to save up to ${formatCurrency.format(summary.potentialTaxSavingsFromHolding)} in capital gains taxes by qualifying for preferential rates.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: approaching.map((p) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ActionChip(
                    avatar: const Icon(Icons.hourglass_bottom, size: 14),
                    label: Text(
                      '${p.symbol}: ${p.daysUntilLongTerm}d left (save ${formatCurrency.format(p.potentialTaxSavingsIfHeld)})',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () => _navigateToInstrument(
                      context,
                      p.symbol,
                      p.type == 'stock',
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapitalGainsFilterBar(
    BuildContext context,
    CapitalGainsSummary summary,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                label: Text('All (${summary.allPositions.length})'),
                selected: _capitalGainsFilter == 'all',
                onSelected: (selected) {
                  setState(() => _capitalGainsFilter = 'all');
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label:
                    Text('Short-Term (${summary.shortTermPositions.length})'),
                selected: _capitalGainsFilter == 'short_term',
                onSelected: (selected) {
                  setState(() => _capitalGainsFilter = 'short_term');
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: Text('Long-Term (${summary.longTermPositions.length})'),
                selected: _capitalGainsFilter == 'long_term',
                onSelected: (selected) {
                  setState(() => _capitalGainsFilter = 'long_term');
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: Text(
                    'Approaching (${summary.approachingLongTermPositions.length})'),
                selected: _capitalGainsFilter == 'approaching',
                onSelected: (selected) {
                  setState(() => _capitalGainsFilter = 'approaching');
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Gains Only'),
                selected: _capitalGainsFilter == 'gains',
                onSelected: (selected) {
                  setState(() => _capitalGainsFilter = 'gains');
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Holding Period & Lots',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            DropdownButton<String>(
              value: _capitalGainsSortBy,
              underline: const SizedBox(),
              icon: const Icon(Icons.sort, size: 16),
              items: const [
                DropdownMenuItem(
                  value: 'timer',
                  child: Text('Sort: Days to Long-Term'),
                ),
                DropdownMenuItem(
                  value: 'gain_loss',
                  child: Text('Sort: Highest P&L'),
                ),
                DropdownMenuItem(
                  value: 'tax_savings',
                  child: Text('Sort: Tax Savings'),
                ),
                DropdownMenuItem(
                  value: 'holding_period',
                  child: Text('Sort: Holding Days'),
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _capitalGainsSortBy = val);
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCapitalGainPositionCard(
    BuildContext context,
    CapitalGainPosition pos,
    NumberFormat formatCurrency,
  ) {
    final theme = Theme.of(context);
    final isStock = pos.type == 'stock';

    Color badgeColor;
    String badgeText;
    if (pos.isLongTerm) {
      badgeColor = Colors.green;
      badgeText = 'Long-Term (${pos.formattedHoldingPeriod})';
    } else if (pos.qualifiesForLongTermSoon) {
      badgeColor = Colors.amber.shade700;
      badgeText = '⏳ ${pos.daysUntilLongTerm}d to Long-Term';
    } else {
      badgeColor = theme.colorScheme.primary;
      badgeText = 'Short-Term (${pos.formattedHoldingPeriod})';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _navigateToInstrument(context, pos.symbol, isStock),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    child: Text(
                      pos.symbol.length > 4
                          ? pos.symbol.substring(0, 4)
                          : pos.symbol,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                pos.symbol,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: badgeColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                badgeText,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: badgeColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          pos.name,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatCurrency.format(pos.gainLoss),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: pos.gainLoss >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                      Text(
                        '${pos.gainLoss >= 0 ? '+' : ''}${(pos.gainLossPercent * 100).toStringAsFixed(1)}%',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: pos.gainLoss >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Position & Cost Basis',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '${pos.quantity.toStringAsFixed(pos.quantity.truncateToDouble() == pos.quantity ? 0 : 2)} ${isStock ? 'shares' : 'contracts'} • Cost: ${formatCurrency.format(pos.totalCost)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        pos.isLongTerm
                            ? 'Est. Tax (${(_longTermTaxRate * 100).toInt()}%)'
                            : 'Est. Tax (${(_shortTermTaxRate * 100).toInt()}%)',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (pos.gainLoss > 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              formatCurrency.format(pos.isLongTerm
                                  ? pos.estimatedLongTermTax
                                  : pos.estimatedShortTermTax),
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (pos.qualifiesForLongTermSoon) ...[
                              const SizedBox(width: 6),
                              Text(
                                '(Save ${formatCurrency.format(pos.potentialTaxSavingsIfHeld)})',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        )
                      else
                        Text(
                          'No tax due (loss)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.green,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTaxBracketDialog(BuildContext context) {
    double tempSt = _shortTermTaxRate;
    double tempLt = _longTermTaxRate;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Estimated Tax Brackets'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Customize federal and state tax rates to project short-term vs. long-term capital gains liability.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Short-Term Rate: ${(tempSt * 100).toStringAsFixed(0)}% (Ordinary)',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Slider(
                    value: tempSt,
                    min: 0.10,
                    max: 0.45,
                    divisions: 35,
                    label: '${(tempSt * 100).toStringAsFixed(0)}%',
                    onChanged: (val) {
                      setDialogState(() => tempSt = val);
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Long-Term Rate: ${(tempLt * 100).toStringAsFixed(0)}% (Preferential)',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Slider(
                    value: tempLt,
                    min: 0.0,
                    max: 0.25,
                    divisions: 25,
                    label: '${(tempLt * 100).toStringAsFixed(0)}%',
                    onChanged: (val) {
                      setDialogState(() => tempLt = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _shortTermTaxRate = tempSt;
                      _longTermTaxRate = tempLt;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Widget _buildEsgTab(BuildContext context) {
  //   if (widget.analyticsController == null) {
  //     return const Center(child: Text('ESG data unavailable.'));
  //   }
  //   return ListenableBuilder(
  //     listenable: widget.analyticsController!,
  //     builder: (context, child) {
  //       final esgData = widget.analyticsController!.esg;
  //       if (esgData.isEmpty) {
  //         return const Center(
  //           child: Padding(
  //             padding: EdgeInsets.all(32.0),
  //             child: CircularProgressIndicator(),
  //           ),
  //         );
  //       }
  //       return CustomScrollView(
  //         slivers: [
  //           SliverToBoxAdapter(
  //             child: Padding(
  //               padding: const EdgeInsets.all(16.0),
  //               child: EsgCard(data: esgData),
  //             ),
  //           ),
  //           const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
  //         ],
  //       );
  //     },
  //   );
  // }

  Widget _buildSeasonalityBanner(BuildContext context) {
    final urgency = TaxOptimizationService.getSeasonalityUrgency();
    final message = TaxOptimizationService.getSeasonalityMessage();

    Color color;
    IconData icon;

    switch (urgency) {
      case 2:
        color = Colors.red;
        icon = Icons.warning_amber_rounded;
        break;
      case 1:
        color = Colors.orange;
        icon = Icons.access_time;
        break;
      default:
        color = Colors.blue;
        icon = Icons.info_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context,
      TaxHarvestingScanResult scanResult, NumberFormat formatCurrency) {
    final totalLoss = scanResult.totalUnrealizedLoss;
    final realizedGains = scanResult.realizedCapitalGains;
    final ordinaryUsed = scanResult.capitalLossDeductionUsed;
    final carryforward = scanResult.capitalLossCarryforward;
    final estSavings = scanResult.estimatedTaxSavings;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red.shade900.withValues(alpha: 0.85),
            Colors.red.shade700.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Total Potential Tax Loss',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formatCurrency.format(totalLoss),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              if (realizedGains > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Offsets ${formatCurrency.format(min(realizedGains, totalLoss.abs()))} of ${formatCurrency.format(realizedGains)} realized gains',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              if (ordinaryUsed > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '+ ${formatCurrency.format(ordinaryUsed)} Ordinary Income Offset (IRS Cap)',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              if (carryforward > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${formatCurrency.format(carryforward)} Loss Carryforward',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Est. Tax Alpha: ~${formatCurrency.format(estSavings)} (${(scanResult.effectiveTaxRate * 100).toInt()}% Rate)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScannerFilterBar(
    BuildContext context, {
    required int totalCount,
    required int stockCount,
    required int optionCount,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: Text('All ($totalCount)'),
            selected: _assetFilter == 'all',
            onSelected: (selected) {
              if (selected) setState(() => _assetFilter = 'all');
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: Text('Stocks ($stockCount)'),
            selected: _assetFilter == 'stock',
            onSelected: (selected) {
              if (selected) setState(() => _assetFilter = 'stock');
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: Text('Options ($optionCount)'),
            selected: _assetFilter == 'option',
            onSelected: (selected) {
              if (selected) setState(() => _assetFilter = 'option');
            },
          ),
          const SizedBox(width: 12),
          Container(
            height: 24,
            width: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(width: 12),
          ChoiceChip(
            label: const Text('Any Loss'),
            selected: _minLossThreshold == 0.0,
            onSelected: (selected) {
              if (selected) setState(() => _minLossThreshold = 0.0);
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('>\$100'),
            selected: _minLossThreshold == 100.0,
            onSelected: (selected) {
              if (selected) setState(() => _minLossThreshold = 100.0);
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('>\$500'),
            selected: _minLossThreshold == 500.0,
            onSelected: (selected) {
              if (selected) setState(() => _minLossThreshold = 500.0);
            },
          ),
          const SizedBox(width: 12),
          Container(
            height: 24,
            width: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(width: 12),
          ChoiceChip(
            avatar: const Icon(Icons.arrow_downward, size: 14),
            label: const Text('Loss \$'),
            selected: _sortBy == 'loss',
            onSelected: (selected) {
              if (selected) setState(() => _sortBy = 'loss');
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            avatar: const Icon(Icons.percent, size: 14),
            label: const Text('Loss %'),
            selected: _sortBy == 'percent',
            onSelected: (selected) {
              if (selected) setState(() => _sortBy = 'percent');
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            avatar: const Icon(Icons.shield_outlined, size: 14),
            label: const Text('Tax Relief'),
            selected: _sortBy == 'tax_savings',
            onSelected: (selected) {
              if (selected) setState(() => _sortBy = 'tax_savings');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWashSaleTracker(
    BuildContext context,
    List<WashSaleRecord> washSales,
    NumberFormat formatCurrency,
  ) {
    final activeWindows =
        TaxOptimizationService.getActiveWashSaleWindows(washSales);
    final disallowedSales =
        TaxOptimizationService.getDisallowedWashSales(washSales);

    final filteredRecords = washSales.where((r) {
      if (_washSaleFilter == 'active') return r.isWindowActive();
      if (_washSaleFilter == 'disallowed') return r.isDisallowed;
      return true;
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.schedule,
                color: activeWindows.isNotEmpty
                    ? Colors.orange
                    : (disallowedSales.isNotEmpty
                        ? Colors.red
                        : Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '30-Day Wash Sale Tracker',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'IRS Section 1091 Real-Time Monitoring',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline, size: 20),
                tooltip: 'IRS Rule 1091 Guide',
                onPressed: () => _showWashSaleExplainer(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (activeWindows.isEmpty && disallowedSales.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      color: Colors.green, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No active wash sale restrictions. You are safe to repurchase recently sold securities without tax penalty.',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text('All (${washSales.length})'),
                    selected: _washSaleFilter == 'all',
                    onSelected: (selected) {
                      if (selected) setState(() => _washSaleFilter = 'all');
                    },
                  ),
                  const SizedBox(width: 8),
                  if (activeWindows.isNotEmpty) ...[
                    ChoiceChip(
                      avatar: const Icon(Icons.timer_outlined,
                          size: 16, color: Colors.orange),
                      label: Text(
                          '${activeWindows.length} Active Window${activeWindows.length == 1 ? '' : 's'}'),
                      selected: _washSaleFilter == 'active',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _washSaleFilter = 'active');
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (disallowedSales.isNotEmpty) ...[
                    ChoiceChip(
                      avatar: const Icon(Icons.warning_amber_rounded,
                          size: 16, color: Colors.red),
                      label: Text('${disallowedSales.length} Disallowed'),
                      selected: _washSaleFilter == 'disallowed',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _washSaleFilter = 'disallowed');
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            ...filteredRecords.map((record) =>
                _buildWashSaleRecordCard(context, record, formatCurrency)),
          ],
        ],
      ),
    );
  }

  Widget _buildWashSaleRecordCard(
    BuildContext context,
    WashSaleRecord record,
    NumberFormat formatCurrency,
  ) {
    final theme = Theme.of(context);
    final daysRemaining = record.getDaysRemaining();
    final isDisallowed = record.isDisallowed;
    final isStock = record.assetType == 'stock';

    Color statusColor;
    String statusLabel;
    if (isDisallowed) {
      statusColor = Colors.red;
      statusLabel = 'Loss Disallowed';
    } else if (daysRemaining > 0) {
      statusColor = Colors.orange;
      statusLabel =
          '$daysRemaining ${daysRemaining == 1 ? 'day' : 'days'} left';
    } else {
      statusColor = Colors.green;
      statusLabel = 'Safe to Repurchase';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: theme.colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: statusColor.withValues(alpha: 0.3),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _navigateToInstrument(context, record.symbol, isStock),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isStock
                          ? Colors.blue.withValues(alpha: 0.1)
                          : Colors.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      record.symbol,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isStock ? Colors.blue : Colors.purple,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      record.name,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: statusColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (isDisallowed) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Disallowed Tax Loss:',
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      formatCurrency.format(
                          record.disallowedLoss ?? record.realizedLoss.abs()),
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                if (record.adjustedCostBasis != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Deferred Basis Adjustment:',
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        formatCurrency.format(record.adjustedCostBasis),
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Realized Sale Loss:',
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      formatCurrency.format(record.realizedLoss),
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Safe Repurchase Date:',
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      DateFormat.yMMMd().format(record.safeRepurchaseDate),
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showWashSaleExplainer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'IRS Section 1091 Wash Sale Rule',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  _explainerBullet(
                    context,
                    Icons.date_range,
                    '61-Day Window',
                    'A wash sale occurs if you sell a security at a loss and acquire substantially identical securities within a 61-day period: 30 days before the sale, the sale day, or 30 days after the sale.',
                  ),
                  const SizedBox(height: 14),
                  _explainerBullet(
                    context,
                    Icons.swap_horiz,
                    'Substantially Identical Contracts',
                    'The rule applies cross-instrument. Buying call options or in-the-money puts on a stock you sold at a loss is considered acquiring substantially identical contracts and triggers the penalty.',
                  ),
                  const SizedBox(height: 14),
                  _explainerBullet(
                    context,
                    Icons.add_chart,
                    'Loss Is Deferred, Not Lost',
                    'The disallowed loss is added to the cost basis of your replacement shares or options. This defers the tax benefit until you eventually dispose of the replacement position without triggering another wash sale.',
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Understood'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _explainerBullet(
    BuildContext context,
    IconData icon,
    String title,
    String description,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon,
              size: 20, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _navigateToInstrument(
      BuildContext context, String symbol, bool isStock) async {
    final instrumentStore =
        Provider.of<InstrumentStore>(context, listen: false);
    try {
      final instrument = await widget.service
          .getInstrumentBySymbol(widget.user, instrumentStore, symbol);
      if (instrument != null && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => InstrumentWidget(
              widget.user,
              widget.service,
              instrument,
              analytics: widget.analytics,
              observer: widget.observer,
              generativeService: widget.generativeService,
              user: widget.appUser,
              userDocRef: widget.userDocRef,
            ),
          ),
        );
      }
    } catch (_) {}
  }

  Widget _buildSuggestionCard(BuildContext context,
      TaxHarvestingSuggestion suggestion, NumberFormat formatCurrency) {
    final isStock = suggestion.type == 'stock';
    final lossPercentage =
        (suggestion.estimatedLoss / suggestion.totalCost).abs();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          final instrumentStore =
              Provider.of<InstrumentStore>(context, listen: false);
          if (isStock) {
            final instrument = suggestion.position.instrumentObj;
            if (instrument != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => InstrumentWidget(
                    widget.user,
                    widget.service,
                    instrument,
                    analytics: widget.analytics,
                    observer: widget.observer,
                    generativeService: widget.generativeService,
                    user: widget.appUser,
                    userDocRef: widget.userDocRef,
                  ),
                ),
              );
            }
          } else {
            // For options, fetch the underlying instrument
            final symbol = suggestion.symbol;
            // Show loading indicator?
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Loading instrument...')),
            );
            try {
              final instrument = await widget.service
                  .getInstrumentBySymbol(widget.user, instrumentStore, symbol);
              if (instrument != null && context.mounted) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => InstrumentWidget(
                      widget.user,
                      widget.service,
                      instrument,
                      analytics: widget.analytics,
                      observer: widget.observer,
                      generativeService: widget.generativeService,
                      user: widget.appUser,
                      userDocRef: widget.userDocRef,
                    ),
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error loading instrument: $e')),
                );
              }
            }
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isStock
                          ? Colors.blue.withValues(alpha: 0.1)
                          : Colors.orange.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      isStock ? 'S' : 'O',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isStock ? Colors.blue : Colors.orange,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          suggestion.symbol,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          suggestion.name,
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatCurrency.format(suggestion.estimatedLoss),
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${(lossPercentage * 100).toStringAsFixed(2)}%',
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDetailItem(
                    context,
                    'Quantity',
                    suggestion.quantity.toStringAsFixed(isStock ? 4 : 1),
                  ),
                  _buildDetailItem(
                    context,
                    'Avg Cost',
                    formatCurrency.format(suggestion.averageBuyPrice),
                  ),
                  _buildDetailItem(
                    context,
                    'Current',
                    formatCurrency.format(suggestion.currentPrice),
                  ),
                  if (suggestion.taxSavingsEstimate != null)
                    _buildDetailItem(
                      context,
                      'Est. Relief',
                      formatCurrency.format(suggestion.taxSavingsEstimate),
                    ),
                ],
              ),
              if (suggestion.replacements.isNotEmpty) ...[
                const Divider(height: 24),
                Row(
                  children: [
                    Icon(
                      Icons.swap_horiz,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Correlated Replacements',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Safe CUSIP',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...suggestion.replacements.take(2).map((replacement) {
                  return Container(
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant
                            .withValues(alpha: 0.4),
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _navigateToInstrument(
                        context,
                        replacement.symbol,
                        replacement.assetType != 'option',
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    replacement.symbol,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    replacement.name,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '~${(replacement.correlation * 100).toInt()}% corr',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 11,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              replacement.rationale,
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
              if (isStock) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.sell_outlined, size: 16),
                    label: const Text('Harvest with HIFO'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () async {
                      final instrumentStore =
                          Provider.of<InstrumentStore>(context, listen: false);
                      var instrument = suggestion.position?.instrumentObj;
                      if (instrument == null) {
                        try {
                          instrument = await widget.service.getInstrumentBySymbol(
                            widget.user,
                            instrumentStore,
                            suggestion.symbol,
                          );
                        } catch (_) {}
                      }
                      if (instrument != null && context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TradeInstrumentWidget(
                              widget.user,
                              widget.service,
                              instrument: instrument,
                              stockPosition: suggestion.position is InstrumentPosition
                                  ? suggestion.position as InstrumentPosition
                                  : null,
                              positionType: "Sell",
                              initialTaxLotStrategy: TaxLotStrategy.hifo,
                              analytics: widget.analytics,
                              observer: widget.observer,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForm8949Tab(
    BuildContext context,
    Form8949Reconciliation reconciliation,
    NumberFormat formatCurrency,
  ) {
    List<Form8949Entry> displayedEntries = reconciliation.allEntries;
    if (_form8949Filter == 'short_term') {
      displayedEntries = reconciliation.shortTermEntries;
    } else if (_form8949Filter == 'long_term') {
      displayedEntries = reconciliation.longTermEntries;
    } else if (_form8949Filter == 'wash_sales') {
      displayedEntries =
          reconciliation.allEntries.where((e) => e.hasWashSale).toList();
    }

    final currentYear = DateTime.now().year;
    final availableYears = [currentYear, currentYear - 1, currentYear - 2, null];

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildForm8949Header(context, reconciliation, availableYears),
                const SizedBox(height: 16),
                _buildForm8949SummaryCard(
                    context, reconciliation, formatCurrency),
                const SizedBox(height: 20),
                _buildForm8949FilterBar(context, reconciliation),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Dispositions (${displayedEntries.length})',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'IRS Part I & II',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (displayedEntries.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _form8949Year != null
                        ? 'No realized dispositions recorded for $_form8949Year.'
                        : 'No realized dispositions recorded.',
                  ),
                  if (_form8949Filter != 'all') ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _form8949Filter = 'all';
                        });
                      },
                      child: const Text('Show All Dispositions'),
                    ),
                  ],
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final entry = displayedEntries[index];
                  return _buildForm8949EntryCard(
                    context,
                    entry,
                    formatCurrency,
                  );
                },
                childCount: displayedEntries.length,
              ),
            ),
          ),
        const SliverToBoxAdapter(
          child: SizedBox(height: 24),
        ),
      ],
    );
  }

  Widget _buildForm8949Header(
    BuildContext context,
    Form8949Reconciliation reconciliation,
    List<int?> availableYears,
  ) {
    return Card(
      elevation: 0,
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.receipt_long,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'IRS Form 8949 & Schedule D',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Capital gains dispositions & wash sale reconciliation',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [
                    const Text('Tax Year: ',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    DropdownButton<int?>(
                      value: _form8949Year,
                      isDense: true,
                      borderRadius: BorderRadius.circular(12),
                      items: availableYears.map((yr) {
                        return DropdownMenuItem<int?>(
                          value: yr,
                          child: Text(yr != null ? '$yr' : 'All Years'),
                        );
                      }).toList(),
                      onChanged: (yr) {
                        setState(() {
                          _form8949Year = yr;
                        });
                      },
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: () => _exportForm8949Csv(context, reconciliation),
                  icon: const Icon(Icons.file_download_outlined, size: 18),
                  label: const Text('Export Form 8949 CSV'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm8949SummaryCard(
    BuildContext context,
    Form8949Reconciliation reconciliation,
    NumberFormat formatCurrency,
  ) {
    final stNet = reconciliation.shortTermTotals.totalGainOrLoss;
    final ltNet = reconciliation.longTermTotals.totalGainOrLoss;
    final grandNet = reconciliation.grandTotals.totalGainOrLoss;
    final washTotal = reconciliation.totalWashSaleDisallowed;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  const Text(
                    'Reconciliation Summary',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Boxes A & D Covered',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildForm8949MetricTile(
                    context,
                    'Part I: Short-Term',
                    formatCurrency.format(stNet),
                    '${reconciliation.shortTermEntries.length} dispositions',
                    stNet >= 0 ? Colors.green : Colors.red,
                  ),
                ),
                Container(
                  height: 48,
                  width: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),
                Expanded(
                  child: _buildForm8949MetricTile(
                    context,
                    'Part II: Long-Term',
                    formatCurrency.format(ltNet),
                    '${reconciliation.longTermEntries.length} dispositions',
                    ltNet >= 0 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildForm8949MetricTile(
                    context,
                    'Wash Sale Disallowed',
                    formatCurrency.format(washTotal),
                    'Code W Added Back',
                    Colors.orange,
                  ),
                ),
                Container(
                  height: 48,
                  width: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),
                Expanded(
                  child: _buildForm8949MetricTile(
                    context,
                    'Schedule D Net Gain/Loss',
                    formatCurrency.format(grandNet),
                    'Line 16 Net Total',
                    grandNet >= 0 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Column (h) = (d) Proceeds - (e) Cost + (g) Wash Sale Adjustment. Formatted for Schedule D Lines 1b and 8b.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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

  Widget _buildForm8949MetricTile(
    BuildContext context,
    String label,
    String value,
    String subtitle,
    Color valueColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildForm8949FilterBar(
    BuildContext context,
    Form8949Reconciliation reconciliation,
  ) {
    final washCount =
        reconciliation.allEntries.where((e) => e.hasWashSale).length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          FilterChip(
            label: Text('All (${reconciliation.allEntries.length})'),
            selected: _form8949Filter == 'all',
            onSelected: (sel) {
              if (sel) setState(() => _form8949Filter = 'all');
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text('Short-Term (${reconciliation.shortTermEntries.length})'),
            selected: _form8949Filter == 'short_term',
            onSelected: (sel) {
              if (sel) setState(() => _form8949Filter = 'short_term');
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text('Long-Term (${reconciliation.longTermEntries.length})'),
            selected: _form8949Filter == 'long_term',
            onSelected: (sel) {
              if (sel) setState(() => _form8949Filter = 'long_term');
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text('Wash Sales ($washCount)'),
            selected: _form8949Filter == 'wash_sales',
            avatar: washCount > 0
                ? const Icon(Icons.warning_amber_rounded,
                    size: 16, color: Colors.orange)
                : null,
            onSelected: (sel) {
              if (sel) setState(() => _form8949Filter = 'wash_sales');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildForm8949EntryCard(
    BuildContext context,
    Form8949Entry entry,
    NumberFormat formatCurrency,
  ) {
    final dateFormat = DateFormat('MM/dd/yyyy');
    final isGain = entry.gainOrLoss >= 0;
    final gainColor = isGain ? Colors.green : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: entry.hasWashSale
              ? Colors.orange.withValues(alpha: 0.4)
              : Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    entry.description,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: entry.isLongTerm
                        ? Colors.blue.withValues(alpha: 0.12)
                        : Colors.purple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    entry.isLongTerm
                        ? 'Part II (Long-Term)'
                        : 'Part I (Short-Term)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: entry.isLongTerm
                          ? Colors.blue.shade700
                          : Colors.purple.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    'Acq: ${dateFormat.format(entry.acquiredDate)} • Sold: ${dateFormat.format(entry.soldDate)} (${entry.holdingDays}d)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (entry.hasWashSale)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Code W: +${formatCurrency.format(entry.adjustmentAmount)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 18),
            Row(
              children: [
                Expanded(
                  child: _buildDetailItem(
                    context,
                    'Proceeds (d)',
                    formatCurrency.format(entry.proceeds),
                  ),
                ),
                Expanded(
                  child: _buildDetailItem(
                    context,
                    'Cost Basis (e)',
                    formatCurrency.format(entry.costBasis),
                  ),
                ),
                Expanded(
                  child: _buildDetailItem(
                    context,
                    'Adj (g)',
                    entry.adjustmentAmount > 0
                        ? '+${formatCurrency.format(entry.adjustmentAmount)}'
                        : '--',
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Gain/Loss (h)',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          (isGain ? '+' : '') +
                              formatCurrency.format(entry.gainOrLoss),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: gainColor,
                          ),
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

  Future<void> _exportForm8949Csv(
    BuildContext context,
    Form8949Reconciliation reconciliation,
  ) async {
    try {
      final csvString = reconciliation.toCsv();
      final bytes = utf8.encode(csvString);
      final yearStr = reconciliation.taxYear != null
          ? '${reconciliation.taxYear}'
          : 'All';
      final file = XFile.fromData(
        bytes,
        mimeType: 'text/csv',
        name:
            'Form_8949_Reconciliation_${yearStr}_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
      );

      final box = context.findRenderObject() as RenderBox?;
      final origin =
          box != null ? box.localToGlobal(Offset.zero) & box.size : null;

      await SharePlus.instance.share(
        ShareParams(
          files: [file],
          text: 'IRS Form 8949 & Schedule D Reconciliation ($yearStr)',
          sharePositionOrigin: origin,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export Form 8949 CSV: $e')),
        );
      }
    }
  }
}
