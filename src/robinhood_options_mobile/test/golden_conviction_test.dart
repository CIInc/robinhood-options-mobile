import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/unified_conviction_rating.dart';
import 'package:robinhood_options_mobile/widgets/unified_conviction_widget.dart';

void main() {
  final bool shouldSkip =
      Platform.environment.containsKey('CI') || !Platform.isMacOS;
  final sampleRating = UnifiedConvictionRating(
    symbol: 'NVDA',
    direction: 'Bullish',
    convictionScore: 88.0,
    convictionTier: 'VERY_HIGH',
    pillarScores: const [
      FactorPillarScore(
        key: 'trend',
        label: 'Trend & Moving Avgs',
        score: 92.0,
        weight: 0.25,
        status: 'Bullish',
      ),
      FactorPillarScore(
        key: 'momentum',
        label: 'Momentum & Oscillators',
        score: 86.0,
        weight: 0.25,
        status: 'Bullish',
      ),
      FactorPillarScore(
        key: 'volatility',
        label: 'Volatility & Squeeze',
        score: 80.0,
        weight: 0.15,
        status: 'Bullish',
      ),
      FactorPillarScore(
        key: 'flow_gex',
        label: 'Options Flow & GEX',
        score: 94.0,
        weight: 0.20,
        status: 'Bullish',
      ),
      FactorPillarScore(
        key: 'resilience',
        label: 'Adversarial Resilience',
        score: 82.0,
        weight: 0.15,
        status: 'Bullish',
      ),
    ],
    stressPenalty: 2.0,
    keyCatalysts: const [
      'Institutional \$1.8M call sweep cluster',
      'MACD golden crossover above 20-day EMA'
    ],
    primaryRisks: const ['Semi sector beta volatility'],
    actionableGuidance:
        'Strong multi-factor institutional alignment. Consider standard sizing with trailing stops.',
    summary:
        'High-conviction bullish synthesis across technicals, gamma regime, and order flow.',
    lastUpdated: DateTime(2026, 10, 26, 9, 30),
  );

  final hazardRating = UnifiedConvictionRating(
    symbol: 'TSLA',
    direction: 'Bullish',
    convictionScore: 42.0,
    convictionTier: 'LOW',
    pillarScores: const [
      FactorPillarScore(
        key: 'trend',
        label: 'Trend & Moving Avgs',
        score: 55.0,
        weight: 0.25,
        status: 'Neutral',
      ),
      FactorPillarScore(
        key: 'momentum',
        label: 'Momentum & Oscillators',
        score: 48.0,
        weight: 0.25,
        status: 'Neutral',
      ),
      FactorPillarScore(
        key: 'volatility',
        label: 'Volatility & Squeeze',
        score: 35.0,
        weight: 0.15,
        status: 'Bearish',
      ),
      FactorPillarScore(
        key: 'flow_gex',
        label: 'Options Flow & GEX',
        score: 40.0,
        weight: 0.20,
        status: 'Bearish',
      ),
      FactorPillarScore(
        key: 'resilience',
        label: 'Adversarial Resilience',
        score: 30.0,
        weight: 0.15,
        status: 'Bearish',
      ),
    ],
    stressPenalty: 18.0,
    keyCatalysts: const ['Retail volume spike'],
    primaryRisks: const [
      'Adversarial stress penalty (-18 pts) due to downside hazards',
      'Upcoming catalyst hazard: Q3 Earnings Report tomorrow'
    ],
    actionableGuidance:
        'Conflicting or fragile factor signals. Recommended to wait for clearer confirmation or reduce position sizing.',
    summary: 'Fragile rating reflecting earnings hazard and inverted put skew.',
    lastUpdated: DateTime(2026, 10, 26, 9, 30),
  );

  testWidgets('Golden Test - Dark Theme Bullish Conviction', (tester) async {
    tester.view.physicalSize = const Size(500, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: Scaffold(
          backgroundColor: const Color(0xFF121212),
          body: Center(
            child: SizedBox(
              width: 440,
              child: UnifiedConvictionWidget(
                symbol: 'NVDA',
                preloadedRating: sampleRating,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byType(UnifiedConvictionWidget),
      matchesGoldenFile('goldens/unified_conviction_bullish_dark.png'),
    );
  }, skip: shouldSkip);

  testWidgets('Golden Test - Hazard Penalty Conviction', (tester) async {
    tester.view.physicalSize = const Size(500, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: Scaffold(
          backgroundColor: const Color(0xFF121212),
          body: Center(
            child: SizedBox(
              width: 440,
              child: UnifiedConvictionWidget(
                symbol: 'TSLA',
                preloadedRating: hazardRating,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byType(UnifiedConvictionWidget),
      matchesGoldenFile('goldens/unified_conviction_hazard_dark.png'),
    );
  }, skip: shouldSkip);

  testWidgets('Golden Test - Compact Order Ticket', (tester) async {
    tester.view.physicalSize = const Size(500, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: Scaffold(
          backgroundColor: const Color(0xFF121212),
          body: Center(
            child: SizedBox(
              width: 440,
              child: UnifiedConvictionWidget(
                symbol: 'NVDA',
                preloadedRating: sampleRating,
                isCompact: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byType(UnifiedConvictionWidget),
      matchesGoldenFile('goldens/unified_conviction_compact.png'),
    );
  }, skip: shouldSkip);
}
