import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/price_target_analysis.dart';
import 'package:robinhood_options_mobile/widgets/price_targets_widget.dart';

void main() {
  testWidgets(
      'PriceTargetsWidget renders targets, confidence, levels, and expands details',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final testAnalysis = PriceTargetAnalysis(
      confidenceScore: 85.0,
      investmentHorizon: '3-6 Months',
      summary:
          'Apple exhibits strong momentum supported by services growth and robust iPhone demand.',
      fairValue: FairValueAnalysis(
        price: 245.50,
        high: 260.00,
        low: 230.00,
        method:
            'Discounted Cash Flow (DCF) with 10% WACC and 3% terminal growth rate.',
        currency: 'USD',
      ),
      bullishTarget: PriceTargetLevel(
        price: 270.00,
        description: 'Upside breakout target if services revenue expands >15%.',
      ),
      bearishTarget: PriceTargetLevel(
        price: 215.00,
        description:
            'Downside support retest if gross margin contracts below 44%.',
      ),
      supportLevels: [
        PriceTargetLevel(price: 228.00, description: '50-day SMA support'),
        PriceTargetLevel(
            price: 215.00, description: 'Prior resistance now support'),
      ],
      resistanceLevels: [
        PriceTargetLevel(price: 255.00, description: 'Previous 52-week high'),
        PriceTargetLevel(
            price: 270.00, description: 'Fibonacci 1.618 extension'),
      ],
      keyRisks: [
        'Geopolitical supply chain disruption in key manufacturing hubs',
        'Regulatory headwinds impacting app store commission structure',
      ],
      lastUpdated: DateTime(2026, 9, 11, 10, 30),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PriceTargetsWidget(
              symbol: 'AAPL',
              preloadedAnalysis: testAnalysis,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title & Header
    expect(find.text('AI Price Targets'), findsOneWidget);
    expect(find.byIcon(Icons.psychology), findsOneWidget);

    // Verify Header Badges
    expect(find.text('85% Confidence'), findsOneWidget);
    expect(find.text('3-6 Months'), findsOneWidget);
    expect(find.text('Fair Value: \$245.50'), findsOneWidget);

    // Verify Metric Pills
    expect(find.text('Bearish Target'), findsOneWidget);
    expect(find.text('\$215.00'), findsWidgets);
    expect(find.text('Fair Value'), findsOneWidget);
    expect(find.text('\$245.50'), findsWidgets);
    expect(find.text('\$230 - \$260'), findsOneWidget);
    expect(find.text('Bullish Target'), findsOneWidget);
    expect(find.text('\$270.00'), findsWidgets);

    // Verify Confidence bar and Summary
    expect(find.text('Model Confidence'), findsOneWidget);
    expect(
        find.text(
            'Apple exhibits strong momentum supported by services growth and robust iPhone demand.'),
        findsOneWidget);

    // Verify Levels
    expect(find.text('Support Levels'), findsOneWidget);
    expect(find.text('Resistance Levels'), findsOneWidget);
    expect(find.text('\$228.00'), findsOneWidget);
    expect(find.text('\$255.00'), findsOneWidget);

    // Initially, detailed breakdown is collapsed
    expect(find.text('Valuation Methodology'), findsNothing);
    expect(find.text('Key Risk Factors'), findsNothing);
    expect(find.text('View Detailed Rationale & Risks'), findsOneWidget);

    // Tap to expand
    await tester.tap(find.text('View Detailed Rationale & Risks'));
    await tester.pumpAndSettle();

    // Verify Expanded Content
    expect(find.text('Valuation Methodology'), findsOneWidget);
    expect(
        find.text(
            'Discounted Cash Flow (DCF) with 10% WACC and 3% terminal growth rate.'),
        findsOneWidget);
    expect(find.text('Bullish Scenario'), findsOneWidget);
    expect(find.text('Bearish Scenario'), findsOneWidget);
    expect(find.text('Key Risk Factors'), findsOneWidget);
    expect(
        find.text(
            'Geopolitical supply chain disruption in key manufacturing hubs'),
        findsOneWidget);
    expect(
        find.text(
            'Regulatory headwinds impacting app store commission structure'),
        findsOneWidget);
    expect(find.text('Hide Detailed Breakdown'), findsOneWidget);

    // Tap to collapse
    await tester.tap(find.text('Hide Detailed Breakdown'));
    await tester.pumpAndSettle();

    expect(find.text('Valuation Methodology'), findsNothing);
    expect(find.text('View Detailed Rationale & Risks'), findsOneWidget);
  });
}
