import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/widgets/pnl_badge.dart';

void main() {
  testWidgets('PnlBadge renders profit semantic label when value is positive',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PnlBadge(
            text: '+\$150.00',
            value: 150.0,
          ),
        ),
      ),
    );

    final semantics = tester.getSemantics(find.byType(PnlBadge));
    expect(semantics.label, 'Profit: +\$150.00');
  });

  testWidgets('PnlBadge renders loss semantic label when value is negative',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PnlBadge(
            text: '-\$50.00',
            value: -50.0,
          ),
        ),
      ),
    );

    final semantics = tester.getSemantics(find.byType(PnlBadge));
    expect(semantics.label, 'Loss: -\$50.00');
  });

  testWidgets('PnlBadge uses custom semanticLabel when provided',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PnlBadge(
            text: '+\$10.00',
            value: 10.0,
            semanticLabel: 'Custom Profit Label',
          ),
        ),
      ),
    );

    final semantics = tester.getSemantics(find.byType(PnlBadge));
    expect(semantics.label, 'Custom Profit Label');
  });

  testWidgets('PnlBadge renders raw text label when neutral is true',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PnlBadge(
            text: '0.00%',
            value: 0.0,
            neutral: true,
          ),
        ),
      ),
    );

    final semantics = tester.getSemantics(find.byType(PnlBadge));
    expect(semantics.label, '0.00%');
  });
}
