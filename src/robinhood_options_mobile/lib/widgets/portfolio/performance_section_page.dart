import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/chart_selection_store.dart';
import 'package:robinhood_options_mobile/model/dividend_store.dart';
import 'package:robinhood_options_mobile/model/instrument_order_store.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/interest_store.dart';
import 'package:robinhood_options_mobile/widgets/analytics_style_card.dart';
import 'package:robinhood_options_mobile/widgets/home/full_screen_performance_chart_widget.dart';
import 'package:robinhood_options_mobile/widgets/home/performance_chart_widget.dart';
import 'package:robinhood_options_mobile/widgets/income_transactions_widget.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/analytics/analytics_csv_export.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/analytics/benchmark_selector.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/analytics/daily_stats_card.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/analytics/metric_presentation.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/analytics/monthly_returns_card.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/analytics/performance_overview_card.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/portfolio_section_context.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/portfolio_section_scaffold.dart';
import 'package:robinhood_options_mobile/services/csv_import_service.dart';

/// "How did it do?" — returns, benchmarks, and income.
///
/// Monthly returns sits directly under the chart, where it answers the obvious
/// follow-up question, rather than eleven cards further down as it did in the
/// old single scroll.
class PerformanceSectionPage extends StatefulWidget {
  final PortfolioSectionContext sectionContext;

  const PerformanceSectionPage({super.key, required this.sectionContext});

  @override
  State<PerformanceSectionPage> createState() => _PerformanceSectionPageState();
}

class _PerformanceSectionPageState extends State<PerformanceSectionPage> {
  bool _showAllBenchmarks = true;

  @override
  void initState() {
    super.initState();
    // Whichever section the user opens first triggers the computation; the
    // other reads the cached result.
    widget.sectionContext.analyticsController.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final ctx = widget.sectionContext;
    final controller = ctx.analyticsController;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final metrics = controller.metrics;

        return PortfolioSectionScaffold(
          title: 'Performance',
          subtitle: 'Returns, benchmarks & monthly history',
          actions: [
            IconButton(
              icon: const Icon(Icons.upload_file),
              tooltip: 'Import from Fidelity CSV',
              onPressed: () => CsvImportService.importFidelityCsv(context),
            ),
            Builder(builder: (context) {
              return IconButton(
                icon: const Icon(Icons.download),
                tooltip: 'Export to CSV',
                onPressed: () {
                  final box = context.findRenderObject() as RenderBox?;
                  AnalyticsCsvExport.share(
                    context,
                    metrics,
                    benchmarkSymbol: controller.selectedBenchmark,
                    sharePositionOrigin: box == null
                        ? null
                        : box.localToGlobal(Offset.zero) & box.size,
                  );
                },
              );
            }),
            PopupMenuButton<String>(
              icon: const Icon(Icons.help_outline),
              tooltip: 'Help & Documentation',
              onSelected: (value) {
                switch (value) {
                  case 'quick_guide':
                    MetricPresentation.showQuickGuide(context);
                  case 'definitions':
                    MetricPresentation.showAllDefinitions(context);
                  case 'benchmarks':
                    MetricPresentation.showBenchmarkGuide(context,
                        selectedBenchmark: controller.selectedBenchmark);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'quick_guide',
                  child: ListTile(
                    leading: Icon(Icons.book_outlined),
                    title: Text('Quick Guide'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'definitions',
                  child: ListTile(
                    leading: Icon(Icons.description_outlined),
                    title: Text('All Definitions'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'benchmarks',
                  child: ListTile(
                    leading: Icon(Icons.compare_arrows),
                    title: Text('Benchmark Guide'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
          cards: [
            BenchmarkSelector(
              controller: controller,
              initialSpan: ctx.benchmarkChartDateSpanFilter,
              onSpanChanged: ctx.onBenchmarkFilterChanged,
            ),
            _chartCard(context),
            // "No data" is only honest once a computation has actually run.
            // Before that the Portfolio page may still be resolving the account
            // its historicals depend on.
            if (metrics.isEmpty &&
                (controller.isLoading || !controller.hasComputed))
              const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (metrics.isEmpty)
              _emptyState(context)
            else ...[
              PerformanceOverviewCard(
                data: metrics,
                benchmarkSymbol: controller.selectedBenchmark,
              ),
              MonthlyReturnsCard(data: metrics),
              DailyStatsCard(data: metrics),
            ],
          ],
          slivers: [
            Consumer2<DividendStore, InterestStore>(
              builder: (context, dividendStore, interestStore, child) {
                return IncomeTransactionsWidget(
                  ctx.brokerageUser,
                  ctx.service,
                  dividendStore,
                  Provider.of<InstrumentPositionStore>(context, listen: false),
                  Provider.of<InstrumentOrderStore>(context, listen: false),
                  Provider.of<ChartSelectionStore>(context, listen: false),
                  interestStore: interestStore,
                  showChips: true,
                  showList: true,
                  showFooter: true,
                  analytics: ctx.analytics,
                  observer: ctx.observer,
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _chartCard(BuildContext context) {
    final ctx = widget.sectionContext;
    final controller = ctx.analyticsController;
    // The controller carries the live period; the context's copy was captured
    // when this route was pushed and goes stale on the first period change.
    final span = controller.span ?? ctx.benchmarkChartDateSpanFilter;
    if (span == null || ctx.onBenchmarkFilterChanged == null) {
      return const SizedBox.shrink();
    }

    return AnalyticsStyleCard(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: Icon(Icons.show_chart,
                color: Theme.of(context).colorScheme.primary),
            title:
                Text('Growth', style: Theme.of(context).textTheme.titleLarge),
            subtitle: const Text('Portfolio vs. market indices'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(_showAllBenchmarks
                      ? Icons.visibility_off
                      : Icons.visibility),
                  tooltip: _showAllBenchmarks
                      ? 'Hide Other Indices'
                      : 'Show All Indices',
                  onPressed: () =>
                      setState(() => _showAllBenchmarks = !_showAllBenchmarks),
                ),
                IconButton(
                  icon: const Icon(Icons.fullscreen),
                  tooltip: 'Full Screen',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FullScreenPerformanceChartWidget(
                        user: ctx.brokerageUser,
                        service: ctx.service,
                        accountNumber: ctx.accountNumber,
                        futureMarketIndexHistoricalsSp500:
                            ctx.futureMarketIndexHistoricalsSp500,
                        futureMarketIndexHistoricalsNasdaq:
                            ctx.futureMarketIndexHistoricalsNasdaq,
                        futureMarketIndexHistoricalsDow:
                            ctx.futureMarketIndexHistoricalsDow,
                        futureMarketIndexHistoricalsRussell2000:
                            ctx.futureMarketIndexHistoricalsRussell2000,
                        futurePortfolioHistoricalsYear:
                            ctx.portfolioHistoricalsFuture,
                        benchmarkChartDateSpanFilter: span,
                        onFilterChanged: ctx.onBenchmarkFilterChanged!,
                        selectedBenchmark: controller.selectedBenchmark,
                        showAllBenchmarks: _showAllBenchmarks,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          PerformanceChartWidget(
            futureMarketIndexHistoricalsSp500:
                ctx.futureMarketIndexHistoricalsSp500,
            futureMarketIndexHistoricalsNasdaq:
                ctx.futureMarketIndexHistoricalsNasdaq,
            futureMarketIndexHistoricalsDow:
                ctx.futureMarketIndexHistoricalsDow,
            futureMarketIndexHistoricalsRussell2000:
                ctx.futureMarketIndexHistoricalsRussell2000,
            futurePortfolioHistoricalsYear: ctx.portfolioHistoricalsFuture,
            benchmarkChartDateSpanFilter: span,
            onFilterChanged: ctx.onBenchmarkFilterChanged!,
            selectedBenchmark:
                _showAllBenchmarks ? null : controller.selectedBenchmark,
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.query_stats, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text('No Analytics Data Available',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Try selecting a different benchmark or time period.',
                style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
