import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/unified_conviction_rating.dart';
import 'package:robinhood_options_mobile/widgets/unified_conviction_widget.dart';

void main() {
  group('UnifiedConvictionWidget Tests', () {
    final sampleRating = UnifiedConvictionRating(
      symbol: 'AAPL',
      direction: 'Bullish',
      convictionScore: 82.0,
      convictionTier: 'VERY_HIGH',
      pillarScores: const [
        FactorPillarScore(
          key: 'trend',
          label: 'Trend & Moving Avgs',
          score: 85.0,
          weight: 0.25,
          status: 'Bullish',
        ),
        FactorPillarScore(
          key: 'momentum',
          label: 'Momentum & Oscillators',
          score: 80.0,
          weight: 0.25,
          status: 'Bullish',
        ),
        FactorPillarScore(
          key: 'volatility',
          label: 'Volatility & Squeeze',
          score: 75.0,
          weight: 0.15,
          status: 'Bullish',
        ),
        FactorPillarScore(
          key: 'flow_gex',
          label: 'Options Flow & GEX',
          score: 88.0,
          weight: 0.20,
          status: 'Bullish',
        ),
        FactorPillarScore(
          key: 'resilience',
          label: 'Adversarial Resilience',
          score: 80.0,
          weight: 0.15,
          status: 'Bullish',
        ),
      ],
      stressPenalty: 4.0,
      keyCatalysts: const ['Institutional call sweep', 'Golden cross break'],
      primaryRisks: const ['Tech sector rotation'],
      actionableGuidance:
          'Strong institutional alignment. Recommended standard size.',
      summary: 'Very high conviction bullish synthesis.',
      lastUpdated: DateTime(2026, 10, 26, 12, 0),
    );

    testWidgets('renders preloaded rating with score and pillars',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: UnifiedConvictionWidget(
                symbol: 'AAPL',
                preloadedRating: sampleRating,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI Conviction'), findsOneWidget);
      expect(find.text('Very High Conviction'), findsOneWidget);
      expect(find.text('82'), findsOneWidget);
      expect(find.text('Trend & Moving Avgs'), findsOneWidget);
      expect(find.text('Momentum & Oscillators'), findsOneWidget);
      expect(find.text('Volatility & Squeeze'), findsOneWidget);
      expect(find.text('Options Flow & GEX'), findsOneWidget);
      expect(find.text('Adversarial Resilience'), findsOneWidget);
      expect(
          find.text(
              'Strong institutional alignment. Recommended standard size.'),
          findsOneWidget);
      expect(
          find.text('-4 pt Devil\'s Advocate hazard penalty'), findsOneWidget);
      expect(find.text('Institutional call sweep'), findsOneWidget);
    });

    testWidgets('compact mode hides pillars and chips', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: UnifiedConvictionWidget(
                symbol: 'AAPL',
                preloadedRating: sampleRating,
                isCompact: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI Conviction'), findsOneWidget);
      expect(find.text('82'), findsOneWidget);
      expect(find.text('Factor Alignment Matrix'), findsNothing);
      expect(find.text('Trend & Moving Avgs'), findsNothing);
    });

    testWidgets('verifies assistive screen reader semantics label',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnifiedConvictionWidget(
              symbol: 'AAPL',
              preloadedRating: sampleRating,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final semanticsFinder = find.bySemanticsLabel(RegExp(
          r'AAPL Bullish Conviction: 82 out of 100, Very High Conviction'));
      expect(semanticsFinder, findsOneWidget);
    });
  });
}
