import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/widgets/analytics_style_card.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/analytics/metric_presentation.dart';

/// The headline performance read-out: cumulative return against the benchmark,
/// the excess-return curve, and the period's best and worst days.
class PerformanceOverviewCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String benchmarkSymbol;

  const PerformanceOverviewCard({
    super.key,
    required this.data,
    this.benchmarkSymbol = 'SPY',
  });

  @override
  Widget build(BuildContext context) => _overview(context, data);

  Widget _overview(BuildContext context, Map<String, dynamic> data) {
    if (!data.containsKey('portfolioCumulative')) {
      return const SizedBox.shrink();
    }

    final percentFormat = NumberFormat.decimalPercentPattern(decimalDigits: 1);
    String formatPercent(double value) {
      final formatted = percentFormat.format(value);
      if (value > 0 && !formatted.startsWith('+')) {
        return '+$formatted';
      }
      return formatted;
    }

    double portfolioReturn = data['portfolioCumulative'] ?? 0.0;
    double benchmarkReturn = data['benchmarkCumulative'] ?? 0.0;
    double excessReturn =
        data['excessReturn'] ?? portfolioReturn - benchmarkReturn;
    double cagr = data['cagr'] ?? 0.0;
    // double avgDailyReturn = data['avgDailyReturn'] ?? 0.0;
    double bestDay = data['bestDay'] ?? 0.0;
    double worstDay = data['worstDay'] ?? 0.0;
    DateTime? bestDayDate = data['bestDayDate'];
    DateTime? worstDayDate = data['worstDayDate'];
    int periodDays = data['periodDays'] ?? 0;

    final dateFormat = DateFormat.yMMMd();
    String formatDate(DateTime? date) =>
        date != null ? dateFormat.format(date) : '-';

    Color colorFor(double value) => value >= 0 ? Colors.green : Colors.red;

    final stats = [
      _snapshotTile(
        context,
        icon: Icons.trending_up,
        label: 'Portfolio',
        metricKey: 'Portfolio Return',
        value: formatPercent(portfolioReturn),
        valueColor: colorFor(portfolioReturn),
        footer: 'Cumulative return',
        tooltip: 'Cumulative return of your portfolio over the aligned window.',
      ),
      _snapshotTile(
        context,
        icon: Icons.show_chart,
        label: 'Benchmark',
        metricKey: 'Benchmark Return',
        value: formatPercent(benchmarkReturn),
        valueColor: colorFor(benchmarkReturn),
        footer: '$benchmarkSymbol performance',
        tooltip:
            'Cumulative return of the selected benchmark over the same window.',
      ),
      _snapshotTile(
        context,
        icon: Icons.stacked_line_chart,
        label: 'Excess Return',
        value: formatPercent(excessReturn),
        valueColor: colorFor(excessReturn),
        footer: 'vs $benchmarkSymbol',
        tooltip:
            'Portfolio cumulative return minus benchmark cumulative return.',
      ),
      _snapshotTile(
        context,
        icon: Icons.calendar_today,
        label: 'Annualized',
        metricKey: 'Annualized Return',
        value: formatPercent(cagr),
        valueColor: colorFor(cagr),
        footer: 'CAGR',
        tooltip: 'Compound Annual Growth Rate.',
      ),
      _snapshotTile(
        context,
        icon: Icons.arrow_upward,
        label: 'Best Day',
        value: formatPercent(bestDay),
        valueColor: colorFor(bestDay),
        footer:
            bestDayDate != null ? formatDate(bestDayDate) : 'Single-day peak',
        tooltip: 'Highest single-day return observed in the period.',
      ),
      _snapshotTile(
        context,
        icon: Icons.arrow_downward,
        label: 'Worst Day',
        value: formatPercent(worstDay),
        valueColor: colorFor(worstDay),
        footer: worstDayDate != null
            ? formatDate(worstDayDate)
            : 'Single-day trough',
        tooltip: 'Lowest single-day return observed in the period.',
      ),
    ];

    return AnalyticsStyleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Overview',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              if (periodDays > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${periodDays}d window',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              // const SizedBox(width: 8),
              // Container(
              //   padding:
              //       const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              //   decoration: BoxDecoration(
              //     color: Theme.of(context)
              //         .colorScheme
              //         .primaryContainer
              //         .withValues(alpha: 0.3),
              //     borderRadius: BorderRadius.circular(20),
              //   ),
              //   child: Row(
              //     mainAxisSize: MainAxisSize.min,
              //     children: [
              //       const Icon(Icons.flag, size: 14),
              //       const SizedBox(width: 6),
              //       Text(
              //         benchmarkSymbol,
              //         style: TextStyle(
              //           fontWeight: FontWeight.bold,
              //           color:
              //               Theme.of(context).colorScheme.onPrimaryContainer,
              //         ),
              //       ),
              //     ],
              //   ),
              // ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              double itemWidth;
              if (constraints.maxWidth < 360) {
                itemWidth = (constraints.maxWidth - 8) / 2;
              } else if (constraints.maxWidth > 680) {
                itemWidth = (constraints.maxWidth - 24) / 3;
              } else {
                itemWidth = (constraints.maxWidth - 16) / 2;
              }

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: stats
                    .map((widget) => SizedBox(
                          width: itemWidth,
                          height: 120,
                          child: widget,
                        ))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          _benchmarkComparison(
              context, portfolioReturn, benchmarkReturn, benchmarkSymbol),
          if (data['excessReturnHistory'] != null) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Icon(Icons.monitor_heart_outlined,
                    size: 18, color: Theme.of(context).colorScheme.secondary),
                const SizedBox(width: 8),
                Text('Alpha Drift (Cumulative Excess Return)',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.secondary,
                          fontWeight: FontWeight.bold,
                        )),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: _excessReturnChart(context,
                  data['excessReturnHistory'] as List<Map<String, dynamic>>),
            )
          ]
        ],
      ),
    );
  }

  Widget _benchmarkComparison(BuildContext context, double portfolioReturn,
      double benchmarkReturn, String benchmarkName) {
    final percentFormat = NumberFormat.decimalPercentPattern(decimalDigits: 1);
    final maxVal = [portfolioReturn.abs(), benchmarkReturn.abs()]
        .reduce((curr, next) => curr > next ? curr : next);
    // Avoid division by zero
    final scale = maxVal > 0.001 ? 1.0 / maxVal : 0.0;

    Widget buildBar(String label, double value, Color color, bool isBenchmark) {
      final widthFactor = (value.abs() * scale).clamp(0.01, 1.0);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(isBenchmark ? Icons.show_chart : Icons.trending_up,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(label,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
              Text(
                '${(value < 0 ? "-" : "+")}${percentFormat.format(value.abs())}',
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Stack(
            children: [
              Container(
                height: 8,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              if (widthFactor > 0)
                FractionallySizedBox(
                  widthFactor: widthFactor,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
            ],
          ),
        ],
      );
    }

    final excess = portfolioReturn - benchmarkReturn;
    final isOutperforming = excess > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(isOutperforming ? Icons.check_circle : Icons.info_outline,
                size: 16,
                color: isOutperforming ? Colors.green : Colors.orange),
            const SizedBox(width: 8),
            Text(
              isOutperforming
                  ? 'Outperforming $benchmarkName by ${percentFormat.format(excess)}'
                  : 'Trailing $benchmarkName by ${percentFormat.format(excess.abs())}',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isOutperforming ? Colors.green : Colors.orange,
                  fontSize: 13),
            )
          ]),
          const SizedBox(height: 16),
          buildBar('Your Portfolio', portfolioReturn,
              portfolioReturn >= 0 ? Colors.green : Colors.red, false),
          const SizedBox(height: 12),
          buildBar('Benchmark ($benchmarkName)', benchmarkReturn,
              benchmarkReturn >= 0 ? Colors.green : Colors.red, true),
        ],
      ),
    );
  }

  Widget _excessReturnChart(
      BuildContext context, List<Map<String, dynamic>> data) {
    if (data.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final series = [
      charts.Series<Map<String, dynamic>, DateTime>(
        id: 'Excess Return',
        domainFn: (datum, _) => datum['date'] as DateTime,
        measureFn: (datum, _) => datum['value'] as double,
        colorFn: (datum, _) {
          final val = datum['value'] as double;
          return val >= 0
              ? charts.MaterialPalette.green.shadeDefault
              : charts.MaterialPalette.red.shadeDefault;
        },
        areaColorFn: (datum, _) {
          final val = datum['value'] as double;
          return val >= 0
              ? charts.MaterialPalette.green.shadeDefault.lighter
              : charts.MaterialPalette.red.shadeDefault.lighter;
        },
        data: data,
      )
    ];

    return charts.TimeSeriesChart(
      series,
      animate: true,
      defaultRenderer:
          charts.LineRendererConfig(includeArea: true, stacked: false),
      domainAxis: const charts.DateTimeAxisSpec(
        renderSpec: charts.NoneRenderSpec(),
      ),
      primaryMeasureAxis: charts.NumericAxisSpec(
        renderSpec: charts.GridlineRendererSpec(
          labelStyle: charts.TextStyleSpec(
              color: isDark
                  ? charts.MaterialPalette.gray.shade500
                  : charts.MaterialPalette.gray.shade700,
              fontSize: 10),
          lineStyle: charts.LineStyleSpec(
            color: isDark
                ? charts.MaterialPalette.gray.shade800
                : charts.MaterialPalette.gray.shade300,
          ),
        ),
        tickFormatterSpec:
            charts.BasicNumericTickFormatterSpec.fromNumberFormat(
          NumberFormat.percentPattern(),
        ),
      ),
    );
  }

  Widget _snapshotTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    String? footer,
    String? tooltip,
    String? metricKey,
  }) {
    final keyToUse = metricKey ?? label;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final tile = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  Colors.grey[850]!,
                  Colors.grey[900]!,
                ]
              : [
                  Theme.of(context).colorScheme.surfaceContainer,
                  Theme.of(context).colorScheme.surface,
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.05),
            blurRadius: 12,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                child: Icon(icon,
                    size: 16, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.grey[400]
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: valueColor ??
                      (isDark
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface),
                  fontSize: 22,
                ),
          ),
          if (footer != null) ...[
            const SizedBox(height: 4),
            Text(
              footer,
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? Colors.grey[500]
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );

    // Get definition if available
    final definition = MetricPresentation.definitions[keyToUse];
    final tooltipText = tooltip ?? definition;

    if (tooltipText != null && tooltipText.isNotEmpty) {
      return Tooltip(
        richMessage: TextSpan(
          children: [
            TextSpan(
              text: '$label\n\n',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            TextSpan(
              text: tooltipText,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white,
                height: 1.6,
                fontWeight: FontWeight.w400,
              ),
            ),
            if (definition != null)
              const TextSpan(
                text: '\n\nTap for details',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white70,
                  height: 1.6,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        margin: const EdgeInsets.symmetric(horizontal: 20),
        showDuration: const Duration(seconds: 30),
        waitDuration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.grey[850]!,
              Colors.grey[900]!,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 12,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        textStyle: const TextStyle(color: Colors.white),
        child: InkWell(
          onTap: () {
            if (definition != null) {
              final guidance = MetricPresentation.metricGuidance[keyToUse] ??
                  {'tip': definition, 'noThreshold': true};
              MetricPresentation.showMetricDetails(
                  context, label, definition, guidance);
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: tile,
        ),
      );
    }
    return InkWell(
      onTap: () {
        if (definition != null) {
          final guidance = MetricPresentation.metricGuidance[keyToUse] ??
              {'tip': definition, 'noThreshold': true};
          MetricPresentation.showMetricDetails(
              context, label, definition, guidance);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: tile,
    );
  }
}
