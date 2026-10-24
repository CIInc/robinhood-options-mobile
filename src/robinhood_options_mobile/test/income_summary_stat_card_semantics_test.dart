import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/widgets/income_transactions_widget.dart';

void main() {
  testWidgets(
      'SummaryStatCard provides unified semantics for non-interactive state',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SummaryStatCard(
            label: 'Yield on cost',
            value: '3.50%',
          ),
        ),
      ),
    );

    final semanticsFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label == 'Yield on cost: 3.50%' &&
          widget.properties.button != true,
    );

    expect(semanticsFinder, findsOneWidget);
  });

  testWidgets(
      'SummaryStatCard provides unified button semantics when interactive',
      (WidgetTester tester) async {
    bool tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SummaryStatCard(
            label: 'Last yield',
            value: '4.25%',
            onTap: () {
              tapped = true;
            },
          ),
        ),
      ),
    );

    final semanticsFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label == 'Last yield: 4.25%' &&
          widget.properties.button == true &&
          widget.properties.hint == 'Double tap to view detailed calculation',
    );

    expect(semanticsFinder, findsOneWidget);

    await tester.tap(find.byType(SummaryStatCard));
    expect(tapped, isTrue);
  });
}
