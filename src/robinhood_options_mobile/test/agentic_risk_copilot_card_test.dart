import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/risk_copilot_model.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/agentic_risk_copilot_card.dart';

void main() {
  testWidgets('AgenticRiskCopilotCard wraps card in accessible Semantics',
      (WidgetTester tester) async {
    final semanticsHandle = tester.ensureSemantics();
    bool tapped = false;

    final report = RiskCopilotReport(
      generatedAt: DateTime.now(),
      overallScore: 85.0,
      overallSeverity: RiskCopilotSeverity.normal,
      statusHeadline: 'Portfolio gap exposure & earnings risks fully managed.',
      summary: 'All risk parameters within safe levels.',
      totalOvernightGapExposure: 0.0,
      portfolioNetDelta: 12.5,
      hasImminentEarnings: false,
      gapRisks: const [],
      earningsHazards: const [],
      deltaHedges: const [],
      topMitigations: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AgenticRiskCopilotCard(
            positions: const [],
            optionPositions: const [],
            precomputedReport: report,
            onTap: () {
              tapped = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('Autonomous Risk Copilot'), findsOneWidget);

    final semantics = tester.getSemantics(find.byType(AgenticRiskCopilotCard));
    final data = semantics.getSemanticsData();

    expect(data.hasFlag(SemanticsFlag.isButton), isTrue);
    expect(data.label, contains('Autonomous Risk Copilot'));
    expect(data.label, contains('Risk Score: 85 out of 100'));
    expect(data.label, contains('Overnight Gap: \$0'));
    expect(data.label, contains('Earnings Hazard: 0 Held'));
    expect(data.label, contains('Net Delta: +12.5 Δ'));
    expect(data.label, contains('Status: Portfolio gap exposure'));
    expect(data.hint, 'Tap to open autonomous risk copilot details');

    await tester.tap(find.byType(AgenticRiskCopilotCard));
    expect(tapped, isTrue);

    semanticsHandle.dispose();
  });
}
