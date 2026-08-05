import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/widgets/analytics_style_card.dart';
import 'package:robinhood_options_mobile/widgets/correlation_matrix_widget.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/analytics/metric_presentation.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/analytics/portfolio_health_card.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/analytics/risk_analytics_card.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/portfolio_risk_summary_widget.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/portfolio_section_context.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/portfolio_section_scaffold.dart';
import 'package:robinhood_options_mobile/widgets/risk_heatmap_widget.dart';

/// "How much risk am I taking?" — the single home for every risk metric.
///
/// Leads with two scores (overall risk, concentration) and reveals the eighteen
/// quantitative metrics only on request, so the page reads as an answer rather
/// than a spreadsheet.
class RiskSectionPage extends StatefulWidget {
  final PortfolioSectionContext sectionContext;

  const RiskSectionPage({super.key, required this.sectionContext});

  @override
  State<RiskSectionPage> createState() => _RiskSectionPageState();
}

class _RiskSectionPageState extends State<RiskSectionPage> {
  @override
  void initState() {
    super.initState();
    widget.sectionContext.analyticsController.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final ctx = widget.sectionContext;
    final controller = ctx.analyticsController;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        return Consumer<InstrumentPositionStore>(
          builder: (context, store, child) {
            final metrics = controller.metrics;
            final symbols = store.items
                .where((position) => position.instrumentObj != null)
                .map((position) => position.instrumentObj!.symbol)
                .toList();
            final healthScore = metrics['healthScore'] as double?;

            return PortfolioSectionScaffold(
              title: 'Risk',
              subtitle: 'Score, drawdown, concentration & correlation',
              actions: [
                IconButton(
                  icon: const Icon(Icons.help_outline),
                  tooltip: 'All Definitions',
                  onPressed: () =>
                      MetricPresentation.showAllDefinitions(context),
                ),
              ],
              cards: [
                if (metrics.isEmpty &&
                    (controller.isLoading || !controller.hasComputed))
                  const SizedBox(
                    height: 160,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                RiskAnalyticsCard(data: metrics),
                if (healthScore != null)
                  _healthCard(context, healthScore, metrics),
                PortfolioRiskSummaryWidget(positions: store.items),
                const AnalyticsStyleCard(
                  padding: EdgeInsets.zero,
                  child: RiskHeatmapWidget(),
                ),
                if (symbols.isNotEmpty)
                  AnalyticsStyleCard(
                    padding: EdgeInsets.zero,
                    child: CorrelationMatrixWidget(
                      user: ctx.brokerageUser,
                      service: ctx.service,
                      symbols: symbols,
                      isEmbedded: true,
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _healthCard(
      BuildContext context, double score, Map<String, dynamic> metrics) {
    final theme = Theme.of(context);
    final color = score >= 80
        ? Colors.green
        : (score >= 50 ? Colors.orange : theme.colorScheme.error);

    return AnalyticsStyleCard(
      onTap: () => PortfolioHealthCard.showDetails(context, metrics),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              PortfolioHealthCard.grade(score),
              style: theme.textTheme.titleLarge
                  ?.copyWith(color: color, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Portfolio Health',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  '${PortfolioHealthCard.label(score)} · '
                  '${score.toStringAsFixed(0)}/100',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
