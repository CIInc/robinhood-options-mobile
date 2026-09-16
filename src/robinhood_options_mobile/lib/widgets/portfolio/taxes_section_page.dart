import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/services/tax_optimization_service.dart';
import 'package:robinhood_options_mobile/widgets/analytics_style_card.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/analytics/esg_card.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/portfolio_section_context.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/portfolio_section_scaffold.dart';
import 'package:robinhood_options_mobile/widgets/tax_optimization_widget.dart';

/// Tax-loss harvesting and ESG scoring — the two "how should this be shaped?"
/// analyses that are neither performance nor risk.
class TaxesSectionPage extends StatefulWidget {
  final PortfolioSectionContext sectionContext;

  const TaxesSectionPage({super.key, required this.sectionContext});

  @override
  State<TaxesSectionPage> createState() => _TaxesSectionPageState();
}

class _TaxesSectionPageState extends State<TaxesSectionPage> {
  @override
  void initState() {
    super.initState();
    // ESG depends on holdings rather than historicals, so it loads separately.
    final positions =
        Provider.of<InstrumentPositionStore>(context, listen: false).items;
    widget.sectionContext.analyticsController.loadEsg(positions);
  }

  @override
  Widget build(BuildContext context) {
    final ctx = widget.sectionContext;
    final controller = ctx.analyticsController;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        return Consumer2<InstrumentPositionStore, OptionPositionStore>(
          builder: (context, stockStore, optionStore, child) {
            return PortfolioSectionScaffold(
              title: 'Taxes',
              subtitle: 'Loss harvesting & ESG scoring',
              cards: [
                _harvestingCard(context, stockStore, optionStore),
                EsgCard(data: controller.esg),
              ],
            );
          },
        );
      },
    );
  }

  Widget _harvestingCard(
    BuildContext context,
    InstrumentPositionStore stockStore,
    OptionPositionStore optionStore,
  ) {
    final ctx = widget.sectionContext;
    final theme = Theme.of(context);
    final currency = NumberFormat.simpleCurrency();

    final suggestions =
        TaxOptimizationService.calculateTaxHarvestingOpportunities(
      instrumentPositions: stockStore.items,
      optionPositions: optionStore.items,
    );
    final totalLoss = suggestions.fold<double>(
        0, (sum, suggestion) => sum + suggestion.estimatedLoss);
    final urgency = TaxOptimizationService.getSeasonalityUrgency();

    void openFullTool() => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TaxOptimizationWidget(
              user: ctx.brokerageUser,
              service: ctx.service,
              analytics: ctx.analytics,
              observer: ctx.observer,
              generativeService: ctx.generativeService,
              appUser: ctx.appUser,
              userDocRef: ctx.userDocRef,
            ),
          ),
        );

    if (suggestions.isEmpty) {
      return AnalyticsStyleCard(
        onTap: openFullTool,
        child: Row(
          children: [
            Icon(Icons.savings_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tax Loss Harvesting',
                      style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text('No harvestable losses right now.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      );
    }

    return AnalyticsStyleCard(
      onTap: openFullTool,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.savings_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Tax Loss Harvesting',
                    style: theme.textTheme.titleLarge,
                    overflow: TextOverflow.ellipsis),
              ),
              if (urgency > 0) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: urgency == 2 ? Colors.red : Colors.orange,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    urgency == 2 ? 'URGENT' : 'SEASON',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Icon(Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                currency.format(totalLoss),
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red),
              ),
              const SizedBox(width: 8),
              Text(
                'Potential Loss',
                style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${suggestions.length} '
            '${suggestions.length == 1 ? 'opportunity' : 'opportunities'} '
            'available to harvest.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
