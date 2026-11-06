import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/tail_risk_card.dart';

import 'portfolio_alert_service_test.dart' show buildPosition;

void main() {
  Widget buildTestWidget({
    required List<InstrumentPosition> positions,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: TailRiskCard(
            positions: positions,
            optionPositions: const [],
          ),
        ),
      ),
    );
  }

  testWidgets(
      'TailRiskCard provides unified screen reader semantics for metrics',
      (WidgetTester tester) async {
    final handle = tester.ensureSemantics();

    final positions = [
      buildPosition(symbol: 'AAPL', price: 150.0, quantity: 10),
      buildPosition(symbol: 'MSFT', price: 250.0, quantity: 10),
    ];

    await tester.pumpWidget(buildTestWidget(positions: positions));
    await tester.pumpAndSettle();

    expect(find.byType(TailRiskCard), findsOneWidget);

    // Verify unified Semantics nodes exist for downside screen and liquidity score
    final downsideSemantics = find.byWidgetPredicate((widget) =>
        widget is Semantics &&
        widget.properties.label != null &&
        widget.properties.label!.startsWith('20% downside screen:'));
    expect(downsideSemantics, findsOneWidget);

    final liquiditySemantics = find.byWidgetPredicate((widget) =>
        widget is Semantics &&
        widget.properties.label != null &&
        widget.properties.label!.startsWith('Liquidity score:'));
    expect(liquiditySemantics, findsOneWidget);

    handle.dispose();
  });
}
