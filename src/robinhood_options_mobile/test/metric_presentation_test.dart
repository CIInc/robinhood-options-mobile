import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/analytics/metric_presentation.dart';

void main() {
  testWidgets(
      'showMetricDetails renders without overflow in constrained viewport',
      (WidgetTester tester) async {
    // Set a constrained viewport height where dialog content might exceed bounds
    tester.view.physicalSize = const Size(400, 500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                MetricPresentation.showMetricDetails(
                  context,
                  'Sharpe Ratio',
                  'A comprehensive definition explaining how this metric measures risk-adjusted performance over long horizons.',
                  {
                    'example':
                        'An example showing how portfolio A compares with portfolio B with higher returns but significantly higher volatility.',
                    'goodThreshold': 1.5,
                    'acceptableThreshold': 1.0,
                    'tip':
                        'Focus on optimizing Sharpe ratio rather than raw absolute returns to avoid excessive downside drawdown.',
                  },
                );
              },
              child: const Text('Open Details'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Details'));
    await tester.pumpAndSettle();

    expect(find.text('Sharpe Ratio'), findsOneWidget);
    expect(find.text('Definition'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });

  testWidgets(
      'showBenchmarkInfo renders without overflow in constrained viewport',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                MetricPresentation.showBenchmarkGuide(context,
                    selectedBenchmark: 'SPY');
              },
              child: const Text('Open Benchmark'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Benchmark'));
    await tester.pumpAndSettle();

    expect(find.text('Benchmark Guide'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });
}
