import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/widgets/pnl_badge.dart';

void main() {
  testWidgets('PnlBadge renders profit semantic label when value > 0',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PnlBadge(
            value: 150.25,
            text: '+\$150.25',
          ),
        ),
      ),
    );

    final semantics = tester.getSemantics(find.byType(PnlBadge));
    expect(semantics.label, 'Profit: +\$150.25');
  });

  testWidgets('PnlBadge renders loss semantic label when value < 0',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PnlBadge(
            value: -45.50,
            text: '-\$45.50',
          ),
        ),
      ),
    );

    final semantics = tester.getSemantics(find.byType(PnlBadge));
    expect(semantics.label, 'Loss: -\$45.50');
  });

  testWidgets('PnlBadge infers profit label from text starting with +',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PnlBadge(
            text: '+12.5%',
          ),
        ),
      ),
    );

    final semantics = tester.getSemantics(find.byType(PnlBadge));
    expect(semantics.label, 'Profit: +12.5%');
  });

  testWidgets('PnlBadge infers loss label from text starting with -',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PnlBadge(
            text: '-3.2%',
          ),
        ),
      ),
    );

    final semantics = tester.getSemantics(find.byType(PnlBadge));
    expect(semantics.label, 'Loss: -3.2%');
  });

  testWidgets('PnlBadge renders neutral semantic label when neutral is true',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PnlBadge(
            text: '\$0.00',
            neutral: true,
          ),
        ),
      ),
    );

    final semantics = tester.getSemantics(find.byType(PnlBadge));
    expect(semantics.label, '\$0.00, neutral');
  });
}
