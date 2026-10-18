import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/widgets/market_sentiment_card_widget.dart';

void main() {
  testWidgets(
      'MarketSentimentCardWidget renders accessible error state semantics when service fails or is uninitialized',
      (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarketSentimentCardWidget(
            null,
            null,
            analytics: FakeFirebaseAnalytics(),
            observer: FakeFirebaseAnalyticsObserver(),
            generativeService: FakeGenerativeService(),
            user: null,
            userDocRef: null,
          ),
        ),
      ),
    );

    // Initial frame or error state
    await tester.pumpAndSettle();

    expect(find.text('Sentiment unavailable'), findsOneWidget);

    // Verify Semantics container for error state
    final semanticsFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label == 'Market sentiment unavailable',
    );
    expect(semanticsFinder, findsOneWidget);
  });
}

class FakeFirebaseAnalytics extends Fake implements FirebaseAnalytics {}

class FakeFirebaseAnalyticsObserver extends Fake
    implements FirebaseAnalyticsObserver {}

class FakeGenerativeService extends Fake implements GenerativeService {}
