import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/risk_copilot_model.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/agentic_risk_copilot_card.dart';

void main() {
  group('AgenticRiskCopilotCard Accessibility & Semantics', () {
    testWidgets('renders unified semantics for score, metrics, and mitigation',
        (tester) async {
      final precomputedReport = RiskCopilotReport(
        generatedAt: DateTime.now(),
        overallScore: 82.0,
        overallSeverity: RiskCopilotSeverity.normal,
        statusHeadline: 'Hedges active · Tail risk balanced',
        summary: 'All positions monitored',
        totalOvernightGapExposure: 1250.0,
        earningsHazards: const [],
        deltaHedges: const [],
        topMitigations: const [
          RiskCopilotMitigationAction(
            id: 'mitigation_1',
            symbol: 'ES',
            title: 'Hedge delta divergence with micro futures',
            description: 'Portfolio delta exceeds desired neutral band.',
            severity: RiskCopilotSeverity.normal,
            actionLabel: 'Hedge Delta',
            targetRoute: 'delta_neutral',
          ),
        ],
        portfolioNetDelta: 14.5,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AgenticRiskCopilotCard(
                positions: const [],
                optionPositions: const [],
                precomputedReport: precomputedReport,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify title & headline
      expect(find.text('Autonomous Risk Copilot'), findsOneWidget);

      // Verify unified semantics label for risk score
      expect(
        find.bySemanticsLabel('Risk score: 82 out of 100, Normal'),
        findsOneWidget,
      );

      // Verify unified semantics labels for the 3 metric pills
      expect(
        find.bySemanticsLabel('Overnight Gap: -\$1,250'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Earnings Hazard: 0 Held'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Net Delta: +14.5 Δ'),
        findsOneWidget,
      );

      // Verify unified semantics label for the recommendation banner
      expect(
        find.bySemanticsLabel(
            'Recommendation: Hedge delta divergence with micro futures'),
        findsOneWidget,
      );
    });

    testWidgets(
        'renders fallback status headline semantics when no mitigations',
        (tester) async {
      final precomputedReport = RiskCopilotReport(
        generatedAt: DateTime.now(),
        overallScore: 90.0,
        overallSeverity: RiskCopilotSeverity.normal,
        statusHeadline:
            'No imminent earnings risk or gap vulnerability detected',
        summary: 'All safe',
        totalOvernightGapExposure: 0.0,
        earningsHazards: const [],
        deltaHedges: const [],
        topMitigations: const [],
        portfolioNetDelta: 0.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AgenticRiskCopilotCard(
                positions: const [],
                optionPositions: const [],
                precomputedReport: precomputedReport,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(
            'Recommendation: No imminent earnings risk or gap vulnerability detected'),
        findsOneWidget,
      );
    });
  });
}
