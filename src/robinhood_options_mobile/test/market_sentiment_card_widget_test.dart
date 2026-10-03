import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:robinhood_options_mobile/model/sentiment_data.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/widgets/market_sentiment_card_widget.dart';

class MockFirebaseAnalytics extends Mock implements FirebaseAnalytics {}

class MockFirebaseAnalyticsObserver extends Mock
    implements FirebaseAnalyticsObserver {}

class MockGenerativeService extends Mock implements GenerativeService {}

void main() {
  testWidgets('MarketSentimentCardWidget renders accessibility semantics',
      (WidgetTester tester) async {
    final mockAnalytics = MockFirebaseAnalytics();
    final mockObserver = MockFirebaseAnalyticsObserver();
    final mockGenerativeService = MockGenerativeService();

    final testSentimentData = SentimentData(
      score: 75.0,
      magnitude: 0.9,
      source: SentimentSource.news,
      summary:
          'Market is showing strong bullish momentum across major tech equities.',
      timestamp: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarketSentimentCardWidget(
            null,
            null,
            analytics: mockAnalytics,
            observer: mockObserver,
            generativeService: mockGenerativeService,
            user: null,
            userDocRef: null,
            sentimentDataFuture: Future.value(testSentimentData),
          ),
        ),
      ),
    );

    // Pump to complete the FutureBuilder
    await tester.pumpAndSettle();

    // Verify Semantics wrapper presence and parameters
    final cardFinder = find.byType(MarketSentimentCardWidget);
    expect(cardFinder, findsOneWidget);

    final semanticsFinder = find.descendant(
      of: cardFinder,
      matching: find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.button == true,
      ),
    );
    expect(semanticsFinder, findsOneWidget);

    final semanticsData =
        tester.getSemantics(semanticsFinder).getSemanticsData();
    expect(semanticsData.hasFlag(SemanticsFlag.isButton), isTrue);
    expect(
      semanticsData.hint,
      'Double tap to view detailed sentiment analysis',
    );
    expect(semanticsData.label, contains('Market Sentiment: Bullish'));
    expect(semanticsData.label, contains('score 75 out of 100'));
    expect(
      semanticsData.label,
      contains('Market is showing strong bullish momentum'),
    );
  });
}
