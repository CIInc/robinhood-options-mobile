import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/portfolio_analytics_controller.dart';
import 'package:robinhood_options_mobile/widgets/analytics_style_card.dart';

class RollingStatisticsDashboard extends StatelessWidget {
  final PortfolioAnalyticsController controller;

  const RollingStatisticsDashboard({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = controller.metrics;
    final points = (metrics['rollingStatistics'] as List?)
            ?.whereType<Map>()
            .map((point) => Map<String, dynamic>.from(point))
            .toList() ??
        const <Map<String, dynamic>>[];

    return AnalyticsStyleCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Rolling Statistics',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      'Volatility, beta & correlation vs ${controller.selectedBenchmark}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (points.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  'Rolling statistics need more aligned trading sessions for the selected period.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
          else ...[
            _latestSummary(context, points.last),
            const SizedBox(height: 16),
            _metricChart(
                context, points, 'Volatility', 'volatility', Colors.orange,
                percent: true),
            _metricChart(context, points, 'Beta', 'beta', Colors.blue),
            _metricChart(
                context, points, 'Correlation', 'correlation', Colors.teal),
          ],
        ],
      ),
    );
  }

  Widget _latestSummary(BuildContext context, Map<String, dynamic> point) {
    final values = [
      ('Volatility', point['volatility'] as double, '%', Colors.orange),
      ('Beta', point['beta'] as double, '', Colors.blue),
      ('Correlation', point['correlation'] as double, '', Colors.teal),
    ];
    return Row(
      children: [
        for (var i = 0; i < values.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: values[i].$4.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(values[i].$1,
                      style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 3),
                  Text(
                    '${(values[i].$2 * (values[i].$3 == '%' ? 100 : 1)).toStringAsFixed(2)}${values[i].$3}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: values[i].$4, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _metricChart(
    BuildContext context,
    List<Map<String, dynamic>> points,
    String title,
    String key,
    Color color, {
    bool percent = false,
  }) {
    final axisLabelColor = charts.ColorUtil.fromDartColor(
      Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final series = charts.Series<Map<String, dynamic>, DateTime>(
      id: key,
      data: points,
      domainFn: (point, _) => point['date'] as DateTime,
      measureFn: (point, _) => (point[key] as double) * (percent ? 100 : 1),
      colorFn: (_, __) => charts.ColorUtil.fromDartColor(color),
    );
    final latest = points.last[key] as double;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        SizedBox(
          height: 116,
          child: charts.TimeSeriesChart(
            [series],
            animate: false,
            defaultRenderer: charts.LineRendererConfig<DateTime>(
              includeArea: true,
              strokeWidthPx: 2,
            ),
            primaryMeasureAxis: charts.NumericAxisSpec(
              renderSpec: charts.SmallTickRendererSpec(
                labelStyle: charts.TextStyleSpec(
                  color: axisLabelColor,
                  fontSize: 10,
                ),
              ),
              tickFormatterSpec: charts.BasicNumericTickFormatterSpec(
                (value) => percent
                    ? '${value?.toString() ?? '0'}%'
                    : value?.toString() ?? '0',
              ),
            ),
            domainAxis: charts.DateTimeAxisSpec(
              renderSpec: charts.SmallTickRendererSpec(
                labelStyle: charts.TextStyleSpec(
                  color: axisLabelColor,
                  fontSize: 10,
                ),
              ),
              tickFormatterSpec: charts.BasicDateTimeTickFormatterSpec(
                (date) => DateFormat('MMM d').format(date),
              ),
            ),
            behaviors: const [],
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'Latest ${percent ? '${(latest * 100).toStringAsFixed(2)}%' : latest.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
