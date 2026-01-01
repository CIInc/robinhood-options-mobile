import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals.dart';
import 'package:robinhood_options_mobile/model/tax_harvesting_suggestion.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/tax_optimization_service.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';

class TaxOptimizationWidget extends StatelessWidget {
  final BrokerageUser user;
  final IBrokerageService service;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final GenerativeService generativeService;
  final User? appUser;
  final DocumentReference<User>? userDocRef;
  final PortfolioHistoricals? portfolioHistoricals;

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
  });

  @override
  Widget build(BuildContext context) {
    final instrumentPositionStore =
        Provider.of<InstrumentPositionStore>(context);
    final optionPositionStore = Provider.of<OptionPositionStore>(context);

    final suggestions =
        TaxOptimizationService.calculateTaxHarvestingOpportunities(
      instrumentPositions: instrumentPositionStore.items,
      optionPositions: optionPositionStore.items,
    );

    final totalEstimatedLoss = suggestions.fold<double>(
        0, (previousValue, element) => previousValue + element.estimatedLoss);

    final estimatedRealizedGains =
        TaxOptimizationService.calculateEstimatedRealizedGains(
      portfolioHistoricals: portfolioHistoricals,
      instrumentPositions: instrumentPositionStore.items,
      optionPositions: optionPositionStore.items,
    );

    final formatCurrency = NumberFormat.simpleCurrency();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.medium(
            title: const Text('Tax Loss Harvesting'),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildSeasonalityBanner(context),
                  const SizedBox(height: 16),
                  _buildSummaryCard(context, totalEstimatedLoss,
                      estimatedRealizedGains, formatCurrency),
                  const SizedBox(height: 16),
                  _buildWashSaleWarning(context),
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
      ),
    );
  }

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

  Widget _buildWashSaleWarning(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Wash Sale Rule Warning',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'If you sell a security at a loss and buy a "substantially identical" security within 30 days before or after the sale, the loss is disallowed for tax purposes.',
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
    );
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
                    user,
                    service,
                    instrument,
                    analytics: analytics,
                    observer: observer,
                    generativeService: generativeService,
                    user: appUser,
                    userDocRef: userDocRef,
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
              final instrument = await service.getInstrumentBySymbol(
                  user, instrumentStore, symbol);
              if (instrument != null && context.mounted) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => InstrumentWidget(
                      user,
                      service,
                      instrument,
                      analytics: analytics,
                      observer: observer,
                      generativeService: generativeService,
                      user: appUser,
                      userDocRef: userDocRef,
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
