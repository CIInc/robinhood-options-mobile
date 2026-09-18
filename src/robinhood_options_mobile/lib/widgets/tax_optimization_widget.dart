import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument_order_store.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/option_order_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_analytics_controller.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals.dart';
import 'package:robinhood_options_mobile/model/tax_harvesting_suggestion.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/model/wash_sale_record.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/tax_optimization_service.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';
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
    this.initialTabIndex = 0,
    this.analyticsController,
  });

  @override
  State<TaxOptimizationWidget> createState() => _TaxOptimizationWidgetState();
}

class _TaxOptimizationWidgetState extends State<TaxOptimizationWidget> {
  String _washSaleFilter = 'all'; // 'all', 'active', 'disallowed'

  @override
  void initState() {
    super.initState();
    // if (widget.analyticsController != null) {
    //   WidgetsBinding.instance.addPostFrameCallback((_) {
    //     if (mounted) {
    //       final positions =
    //           Provider.of<InstrumentPositionStore>(context, listen: false)
    //               .items;
    //       widget.analyticsController!.loadEsg(positions);
    //     }
    //   });
    // }
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

    final suggestions =
        TaxOptimizationService.calculateTaxHarvestingOpportunities(
      instrumentPositions: instrumentPositionStore.items,
      optionPositions: optionPositionStore.items,
    );

    final totalEstimatedLoss = suggestions.fold<double>(
        0, (previousValue, element) => previousValue + element.estimatedLoss);

    final estimatedRealizedGains =
        TaxOptimizationService.calculateEstimatedRealizedGains(
      portfolioHistoricals: widget.portfolioHistoricals,
      instrumentPositions: instrumentPositionStore.items,
      optionPositions: optionPositionStore.items,
    );

    final washSales = TaxOptimizationService.detectWashSales(
      stockOrders: instrumentOrderStore?.items.toList() ?? const [],
      optionOrders: optionOrderStore?.items.toList() ?? const [],
      instrumentPositions: instrumentPositionStore.items,
      optionPositions: optionPositionStore.items,
      initialRecords: widget.initialWashSales,
    );

    final formatCurrency = NumberFormat.simpleCurrency();
    // final hasEsg = widget.analyticsController != null;
    // final tabCount = hasEsg ? 3 : 2;

    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTabIndex,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Taxes'),
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.savings_outlined),
                text: 'Loss Harvesting',
              ),
              Tab(
                icon: Icon(Icons.schedule),
                text: 'Wash Sales',
              ),
              // if (hasEsg)
              //   const Tab(
              //     icon: Icon(Icons.eco_outlined),
              //     text: 'ESG Analysis',
              //   ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildHarvestingTab(
              context,
              suggestions,
              totalEstimatedLoss,
              estimatedRealizedGains,
              formatCurrency,
            ),
            _buildWashSalesTab(
              context,
              washSales,
              formatCurrency,
            ),
            // if (hasEsg) _buildEsgTab(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHarvestingTab(
    BuildContext context,
    List<TaxHarvestingSuggestion> suggestions,
    double totalEstimatedLoss,
    double estimatedRealizedGains,
    NumberFormat formatCurrency,
  ) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildSeasonalityBanner(context),
                const SizedBox(height: 16),
                _buildSummaryCard(context, totalEstimatedLoss,
                    estimatedRealizedGains, formatCurrency),
                const SizedBox(height: 24),
                if (suggestions.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Opportunities (${suggestions.length})',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (suggestions.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text('No tax harvesting opportunities found.'),
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

  Widget _buildSummaryCard(BuildContext context, double totalLoss,
      double estimatedRealizedGains, NumberFormat formatCurrency) {
    final canOffset = estimatedRealizedGains > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red.shade900.withValues(alpha: 0.8),
            Colors.red.shade700.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
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
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formatCurrency.format(totalLoss),
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          if (canOffset) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Can offset ~${formatCurrency.format(estimatedRealizedGains)} of YTD gains',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Estimated Savings: ~25-35%', // Rough estimate based on tax brackets
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
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
                        if (selected) setState(() => _washSaleFilter = 'active');
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
          child:
              Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
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
              final instrument = await widget.service.getInstrumentBySymbol(
                  widget.user, instrumentStore, symbol);
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
                ],
              ),
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
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
