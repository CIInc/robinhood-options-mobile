import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/earnings_iv_crush_model.dart';
import 'package:robinhood_options_mobile/widgets/earnings_iv_crush_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void setLargeTestWindow(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  void setNarrowTestWindow(WidgetTester tester) {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: child,
    );
  }

  EarningsIvCrushAnalysis createMockAnalysis() {
    final now = DateTime(2026, 9, 21, 10, 0);
    final reportDate = DateTime(2026, 10, 22);

    return EarningsIvCrushAnalysis(
      symbol: 'GOOGL',
      spotPrice: 180.0,
      nextEarningsDate: reportDate,
      daysToEarnings: 31,
      currentIv: 0.54,
      postEarningsEstimatedIv: 0.28,
      summary: const EarningsIvCrushSummary(
        quartersAnalyzed: 12,
        averageImpliedMovePct: 6.8,
        averageActualMovePct: 4.1,
        impliedVsActualSpread: 2.7,
        overpricingRatePct: 75.0,
        averageIvCrushPct: 48.1,
        crushProbabilityScore: 81.5,
        riskTier: EarningsIvCrushRiskTier.extreme,
        maxHistoricalMovePct: 8.9,
        minHistoricalMovePct: 1.1,
        upMovesCount: 8,
        downMovesCount: 4,
      ),
      quarters: [
        EarningsQuarterRecord(
          quarterLabel: 'Q2 2026',
          reportDate: DateTime(2026, 7, 23),
          epsEstimate: 1.85,
          epsActual: 1.95,
          epsSurprisePct: 5.4,
          preEarningsIv: 0.58,
          postEarningsIv: 0.30,
          ivCrushPct: 48.3,
          impliedMovePct: 6.5,
          actualMovePct: 3.8,
          moveDirection: 3.8,
          impliedOverpriced: true,
          beatMiss: EarningsBeatMiss.beat,
        ),
        EarningsQuarterRecord(
          quarterLabel: 'Q1 2026',
          reportDate: DateTime(2026, 4, 25),
          epsEstimate: 1.70,
          epsActual: 1.62,
          epsSurprisePct: -4.7,
          preEarningsIv: 0.55,
          postEarningsIv: 0.29,
          ivCrushPct: 47.3,
          impliedMovePct: 6.2,
          actualMovePct: 4.5,
          moveDirection: -4.5,
          impliedOverpriced: true,
          beatMiss: EarningsBeatMiss.miss,
        ),
      ],
      straddleEstimate: const StraddlePricingEstimate(
        spotPrice: 180.0,
        atmStrike: 180.0,
        callPrice: 6.20,
        putPrice: 5.80,
        straddleCost: 12.00,
        straddleCostPct: 6.67,
        impliedMovePct: 6.67,
        upperBreakeven: 192.00,
        lowerBreakeven: 168.00,
        expectedPostEarningsIv: 0.28,
        longStraddleEv: -2.10,
        shortStraddleEv: 2.10,
        sellerWinProbability: 75.0,
        buyerWinProbability: 25.0,
        recommendedStrategy:
            StraddleStrategyRecommendation.sellStraddleOrSpread,
        recommendationReason:
            'Options are overpriced. Market implies a ±6.7% move vs historical actual of ±4.1%.',
      ),
      updatedAt: now,
    );
  }

  group('EarningsIvCrushWidget Component Tests', () {
    testWidgets('Renders header, hero card, and probability gauge',
        (tester) async {
      setLargeTestWindow(tester);
      final analysis = createMockAnalysis();

      await tester.pumpWidget(
        buildTestableWidget(
          EarningsIvCrushWidget(
            symbol: 'GOOGL',
            spotPrice: 180.0,
            precomputedAnalysis: analysis,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // App bar & symbol header
      expect(find.text('GOOGL Earnings IV Crush'), findsOneWidget);
      expect(find.text('GOOGL'), findsOneWidget);
      expect(find.text('In 31 Days'), findsOneWidget);

      // Probability gauge & risk tier
      expect(find.text('Extreme IV Crush Imminent'), findsOneWidget);
      expect(find.text('82%'), findsOneWidget); // 81.5% rounded to 82%
      expect(find.text('Based on 12 Historical Quarters'), findsOneWidget);
      expect(find.text('-48.1%'), findsOneWidget);
    });

    testWidgets('Renders Straddle Pricing and Expected Value components',
        (tester) async {
      setLargeTestWindow(tester);
      final analysis = createMockAnalysis();

      await tester.pumpWidget(
        buildTestableWidget(
          EarningsIvCrushWidget(
            symbol: 'GOOGL',
            spotPrice: 180.0,
            precomputedAnalysis: analysis,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Straddle pricing card
      expect(find.text('ATM Straddle Pricing & EV'), findsOneWidget);
      expect(find.text('Strike: \$180'), findsOneWidget);
      expect(find.text('\$12.00'), findsWidgets);
      expect(find.text('±6.7%'), findsOneWidget);
      expect(find.text('\$168.00 - \$192.00'), findsOneWidget);

      // EV comparisons
      expect(find.text('Straddle Seller EV'), findsOneWidget);
      expect(find.text('+\$2.10'), findsOneWidget);
      expect(find.text('Win Rate: 75%'), findsOneWidget);

      expect(find.text('Straddle Buyer EV'), findsOneWidget);
      expect(find.text('-\$2.10'), findsOneWidget);
      expect(find.text('Win Rate: 25%'), findsOneWidget);

      // Recommendation
      expect(find.text('Recommendation: Sell Premium / Iron Condor'),
          findsOneWidget);
    });

    testWidgets('Displays 12-quarter history and toggles between views',
        (tester) async {
      setLargeTestWindow(tester);
      final analysis = createMockAnalysis();

      await tester.pumpWidget(
        buildTestableWidget(
          EarningsIvCrushWidget(
            symbol: 'GOOGL',
            spotPrice: 180.0,
            precomputedAnalysis: analysis,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Quarter bars
      expect(find.text('12-Quarter Move History'), findsOneWidget);
      expect(find.text('Q2 2026'), findsOneWidget);
      expect(find.text('Q1 2026'), findsOneWidget);
      expect(find.text('Seller Won'), findsWidgets);

      // Switch to table mode
      final tableButton = find.byIcon(Icons.table_rows_rounded);
      expect(tableButton, findsOneWidget);
      await tester.tap(tableButton);
      await tester.pumpAndSettle();

      expect(find.text('EPS: \$1.95 vs \$1.85'), findsOneWidget);
      expect(find.text('EPS: \$1.62 vs \$1.70'), findsOneWidget);
    });

    testWidgets('Expands educational guidance card and triggers trade action',
        (tester) async {
      setLargeTestWindow(tester);
      final analysis = createMockAnalysis();
      bool tradeTriggered = false;

      await tester.pumpWidget(
        buildTestableWidget(
          EarningsIvCrushWidget(
            symbol: 'GOOGL',
            spotPrice: 180.0,
            precomputedAnalysis: analysis,
            onTradeOptions: () {
              tradeTriggered = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Education card
      expect(find.text('What is Earnings IV Crush?'), findsOneWidget);
      expect(find.textContaining('The Retail Trap:'), findsNothing);

      await tester.tap(find.text('What is Earnings IV Crush?'));
      await tester.pumpAndSettle();

      expect(find.textContaining('The Retail Trap:'), findsOneWidget);

      // Trade action button
      final tradeButton = find.text('Trade Options for Earnings');
      expect(tradeButton, findsOneWidget);
      await tester.tap(tradeButton);
      await tester.pump();

      expect(tradeTriggered, isTrue);
    });

    testWidgets('Renders properly without overflow on compact/narrow viewport',
        (tester) async {
      setNarrowTestWindow(tester);
      final analysis = createMockAnalysis();

      await tester.pumpWidget(
        buildTestableWidget(
          EarningsIvCrushWidget(
            symbol: 'GOOGL',
            spotPrice: 180.0,
            precomputedAnalysis: analysis,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify core widgets are rendered
      expect(find.text('ATM Straddle Pricing & EV'), findsOneWidget);
      expect(find.text('Straddle Seller EV'), findsOneWidget);
      expect(find.text('Straddle Buyer EV'), findsOneWidget);
    });
  });
}
