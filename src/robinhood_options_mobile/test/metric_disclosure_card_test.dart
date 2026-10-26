import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/metric_disclosure_card.dart';

void main() {
  testWidgets('MetricDisclosureCard renders headline, tiles, and semantics',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MetricDisclosureCard(
            icon: Icons.analytics,
            title: 'Portfolio Risk',
            headline: '64',
            status: 'Moderate Risk',
            tiles: [
              DisclosureTile(label: 'Max Drawdown', value: '-12.4%'),
              DisclosureTile(label: 'Beta', value: '1.05'),
            ],
            advancedLabel: 'Advanced Metrics',
            advanced: Text('Advanced Content'),
          ),
        ),
      ),
    );

    expect(find.text('Portfolio Risk'), findsOneWidget);
    expect(find.text('64'), findsOneWidget);
    expect(find.text('Moderate Risk'), findsOneWidget);
    expect(find.text('Max Drawdown'), findsOneWidget);
    expect(find.text('-12.4%'), findsOneWidget);

    // Advanced content is collapsed initially
    expect(find.text('Advanced Content'), findsNothing);

    // Verify Semantics
    final headlineSemantics =
        tester.getSemantics(find.bySemanticsLabel('64, Moderate Risk'));
    expect(headlineSemantics.label, '64, Moderate Risk');

    final tileSemantics =
        tester.getSemantics(find.bySemanticsLabel('Max Drawdown: -12.4%'));
    expect(tileSemantics.label, 'Max Drawdown: -12.4%');

    // Tap to expand advanced section
    await tester.tap(find.text('Advanced Metrics'));
    await tester.pumpAndSettle();

    expect(find.text('Advanced Content'), findsOneWidget);
  });
}
