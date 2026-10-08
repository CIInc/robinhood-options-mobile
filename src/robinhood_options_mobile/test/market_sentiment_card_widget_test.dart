import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:mockito/mockito.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/widgets/market_sentiment_card_widget.dart';

import 'firebase_mocks.dart';

class MockGenerativeService extends Mock implements GenerativeService {}

class FakeObserver extends Fake implements FirebaseAnalyticsObserver {}

void main() {
  setUpAll(() async {
    await setupFirebaseMocks();
  });

  testWidgets(
      'renders MarketSentimentCardWidget loading and accessibility semantics', (
    WidgetTester tester,
  ) async {
    final mockAnalytics = FakeFirebaseAnalytics();
    final mockObserver = FakeObserver();
    final mockGenerativeService = MockGenerativeService();

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
          ),
        ),
      ),
    );

    // Initial pump shows loading state with CircularProgressIndicator semanticsLabel
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is CircularProgressIndicator &&
            widget.semanticsLabel == 'Loading market sentiment',
      ),
      findsOneWidget,
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Verify Semantics exists in widget tree
    final semanticsFinder = find.byType(Semantics);
    expect(semanticsFinder, findsAtLeastNWidgets(1));

    expect(tester.takeException(), isNull);
  });
}
