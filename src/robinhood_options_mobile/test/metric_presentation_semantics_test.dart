import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/analytics/metric_presentation.dart';

void main() {
  testWidgets(
      'MetricPresentation.buildStatItem wraps tile in unified semantics container',
      (WidgetTester tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => MetricPresentation.buildStatItem(
              context,
              'Sharpe',
              1.85,
            ),
          ),
        ),
      ),
    );

    final semanticsFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label == 'Sharpe: 1.85' &&
          widget.properties.button == true &&
          widget.properties.hint ==
              'Double tap to view metric explanation and guidance',
    );

    expect(semanticsFinder, findsOneWidget);
    handle.dispose();
  });

  testWidgets(
      'MetricPresentation.buildStatItem formats percentages and currencies with unified semantics',
      (WidgetTester tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Builder(
                builder: (context) => MetricPresentation.buildStatItem(
                  context,
                  'Win Rate',
                  0.654,
                  isPercent: true,
                ),
              ),
              Builder(
                builder: (context) => MetricPresentation.buildStatItem(
                  context,
                  'Expectancy',
                  125.50,
                  isCurrency: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Win Rate: 65.40%'), findsOneWidget);
    expect(find.bySemanticsLabel('Expectancy: \$125.50'), findsOneWidget);
    handle.dispose();
  });

  testWidgets(
      'MetricPresentation.buildStatItem opens metric detail dialog on tap',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => MetricPresentation.buildStatItem(
              context,
              'Sharpe',
              1.85,
            ),
          ),
        ),
      ),
    );

    // Tap the stat item
    await tester.tap(find.text('Sharpe'));
    await tester.pumpAndSettle();

    // Verify detail dialog is presented with metric information
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Definition'), findsOneWidget);
  });
}
