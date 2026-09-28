import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/devils_advocate_model.dart';
import 'package:robinhood_options_mobile/widgets/devils_advocate_widget.dart';

void main() {
  testWidgets(
      'DevilsAdvocateWidget renders score, killer question, tabs, and details',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final testAnalysis = DevilsAdvocateAnalysis(
      symbol: 'NVDA',
      direction: 'Bullish',
      resilienceScore: 42.0,
      verdict: 'Fragile',
      killerQuestion:
          'What happens to Blackwell gross margins if hyperscaler capex cycles normalize in Q4?',
      summary:
          'Extreme concentration in top 4 customer hyperscalers creates asymmetric downside risk despite record guidance.',
      counterArguments: [
        ThesisCounterArgument(
          title: 'Hyperscaler Concentration Risk',
          argument:
              'Top four customers account for 40%+ of revenue, creating cliff risk if capex commitments moderate.',
          severity: 'High',
        ),
        ThesisCounterArgument(
          title: 'Export Control Headwinds',
          argument:
              'Geopolitical trade restrictions reduce addressable Asian market by 15-20%.',
          severity: 'Medium',
        ),
      ],
      skewTraps: [
        SkewTrap(
          title: 'High Call Volatility Skew',
          description:
              'Call option implied volatility is 18 vol points over historical 30-day realized vol.',
          severity: 'High',
        ),
        SkewTrap(
          title: 'Earnings IV Crush Trap',
          description:
              '85th percentile IV will contract up to 40% immediately following earnings release.',
          severity: 'High',
        ),
      ],
      eventHazards: [
        EventHazard(
          event: 'Quarterly Earnings Call',
          timing: 'In 18 days',
          risk: 'Implied straddle pricing implies +/- 8.5% move.',
          hazardLevel: 'High',
        ),
        EventHazard(
          event: 'FOMC Rate Announcement',
          timing: 'Next Wednesday',
          risk: 'High duration growth stock sensitive to 10-year Treasury yield moves.',
          hazardLevel: 'Medium',
        ),
      ],
      stressScenarios: [
        StressScenario(
          scenario: 'Broad Market Selloff (-5% SPY)',
          projectedImpact: '-8.5%',
          assessment: 'High beta 1.7x semiconductor multiple compression.',
        ),
        StressScenario(
          scenario: 'Volatility Shock (+30% VIX)',
          projectedImpact: '-6.2%',
          assessment: 'Rapid contraction in high-beta speculative call open interest.',
        ),
      ],
      lastUpdated: DateTime(2026, 9, 27, 2, 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DevilsAdvocateWidget(
              symbol: 'NVDA',
              preloadedAnalysis: testAnalysis,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify Header & Adversarial Badge
    expect(find.text('AI Devil\'s Advocate'), findsOneWidget);
    expect(find.text('Adversarial'), findsOneWidget);
    expect(find.text('Thesis Stress Test · NVDA'), findsOneWidget);
    expect(find.text('42 / 100'), findsOneWidget);
    expect(find.text('Fragile Resilience'), findsOneWidget);

    // 2. Verify Direction Chips
    expect(find.text('Bullish'), findsOneWidget);
    expect(find.text('Bearish'), findsOneWidget);
    expect(find.text('Neutral'), findsOneWidget);

    // 3. Verify Killer Question Banner
    expect(find.text('KILLER QUESTION (STRESS POINT)'), findsOneWidget);
    expect(
        find.text(
            'What happens to Blackwell gross margins if hyperscaler capex cycles normalize in Q4?'),
        findsOneWidget);

    // 4. Verify Summary
    expect(
        find.text(
            'Extreme concentration in top 4 customer hyperscalers creates asymmetric downside risk despite record guidance.'),
        findsOneWidget);

    // 5. Verify Counter-Arguments (default tab index 0)
    expect(find.text('Hyperscaler Concentration Risk'), findsOneWidget);
    expect(find.text('High Risk'), findsOneWidget);
    expect(find.text('Export Control Headwinds'), findsOneWidget);
    expect(find.text('Medium Risk'), findsOneWidget);

    // 6. Switch to Skew Traps tab (index 1)
    await tester.tap(find.text('Skew Traps (2)'));
    await tester.pumpAndSettle();

    expect(find.text('High Call Volatility Skew'), findsOneWidget);
    expect(find.text('Earnings IV Crush Trap'), findsOneWidget);

    // 7. Switch to Event Hazards tab (index 2)
    await tester.tap(find.text('Event Hazards (2)'));
    await tester.pumpAndSettle();

    expect(find.text('Quarterly Earnings Call'), findsOneWidget);
    expect(find.text('In 18 days'), findsOneWidget);
    expect(find.text('FOMC Rate Announcement'), findsOneWidget);
    expect(find.text('Next Wednesday'), findsOneWidget);

    // 8. Switch to Stress Scenarios tab (index 3)
    await tester.tap(find.text('Stress Scenarios (2)'));
    await tester.pumpAndSettle();

    expect(find.text('Broad Market Selloff (-5% SPY)'), findsOneWidget);
    expect(find.text('-8.5%'), findsOneWidget);
    expect(find.text('Volatility Shock (+30% VIX)'), findsOneWidget);
    expect(find.text('-6.2%'), findsOneWidget);

    // 9. Verify Footer
    expect(find.byTooltip('Re-run stress test'), findsOneWidget);
  });
}
