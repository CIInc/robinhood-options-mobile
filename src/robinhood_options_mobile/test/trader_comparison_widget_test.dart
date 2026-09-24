import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/top_portfolio_entry.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/widgets/trader_comparison_widget.dart';

import 'firebase_mocks.dart';

class FakeObserver extends Fake implements FirebaseAnalyticsObserver {}

class FakeAnalytics extends Fake implements FirebaseAnalytics {
  @override
  Future<void> logScreenView({
    String? screenClass,
    String? screenName,
    AnalyticsCallOptions? callOptions,
    Map<String, Object>? parameters,
  }) async {}

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
    List<AnalyticsEventItem>? items,
    AnalyticsCallOptions? callOptions,
  }) async {}
}

void main() {
  setUpAll(() async {
    await setupFirebaseMocks();
  });

  group('TraderComparisonWidget Tests', () {
    late FakeFirebaseFirestore fakeDb;
    late FirestoreService firestoreService;
    final fakeAnalytics = FakeAnalytics();
    final fakeObserver = FakeObserver();
    final brokerageUser =
        BrokerageUser(BrokerageSource.demo, 'demo_user', null, null);
    final service = DemoService();

    late TopPortfolioEntry traderA;
    late TopPortfolioEntry traderB;

    setUp(() {
      fakeDb = FakeFirebaseFirestore();
      firestoreService = FirestoreService(firestore: fakeDb);

      traderA = TopPortfolioEntry(
        userId: 'alice',
        userName: 'Alice Cooper',
        returnPercent: 110.5,
        winRate: 74.0,
        totalTrades: 95,
        winningTrades: 70,
        losingTrades: 25,
        sharpeRatio: 2.3,
        maxDrawdownPercent: 9.0,
        profitFactor: 2.1,
        followersCount: 150,
        periodReturns: {
          '1W': 2.0,
          '1M': 8.5,
          '3M': 25.0,
          '1Y': 90.0,
          'ALL': 110.5,
        },
        reputation: const UserReputation(
          score: 85,
          tier: ReputationTier.eliteTrader,
        ),
      );

      traderB = TopPortfolioEntry(
        userId: 'bob',
        userName: 'Bob Ross',
        returnPercent: 65.0,
        winRate: 88.0,
        totalTrades: 50,
        winningTrades: 44,
        losingTrades: 6,
        sharpeRatio: 3.2,
        maxDrawdownPercent: 3.5,
        profitFactor: 3.5,
        followersCount: 80,
        periodReturns: {
          '1W': 1.0,
          '1M': 4.0,
          '3M': 12.0,
          '1Y': 50.0,
          'ALL': 65.0,
        },
        reputation: const UserReputation(
          score: 78,
          tier: ReputationTier.eliteTrader,
        ),
      );
    });

    testWidgets('Renders side-by-side comparison with traders, headers, and categories',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TraderComparisonWidget(
            initialTraders: [traderA, traderB],
            auth: firebase_auth.FirebaseAuth.instance,
            firestoreService: firestoreService,
            analytics: fakeAnalytics,
            observer: fakeObserver,
            brokerageUser: brokerageUser,
            service: service,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check title and subtitle
      expect(find.text('Trader Comparison'), findsOneWidget);
      expect(find.text('Comparing 2 Potential Leaders'), findsOneWidget);

      // Check trader names rendered in header columns
      expect(find.text('Alice Cooper'), findsWidgets);
      expect(find.text('Bob Ross'), findsWidgets);

      // Check privacy banner
      expect(find.textContaining('protect dollar portfolio privacy'), findsOneWidget);

      // Check Relative Strengths card
      expect(find.text('Multi-Factor Relative Strengths'), findsOneWidget);

      // Check Categories
      expect(find.text('Performance & Returns'), findsOneWidget);
      expect(find.text('Risk & Preservation'), findsOneWidget);
      expect(find.text('Activity & Execution'), findsOneWidget);
      expect(find.text('Reputation & Trust'), findsOneWidget);

      // Check Copy CTA buttons
      expect(find.text('Copy'), findsNWidgets(2));
    });

    testWidgets('Period switching updates metric values and labels',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TraderComparisonWidget(
            initialTraders: [traderA, traderB],
            auth: firebase_auth.FirebaseAuth.instance,
            firestoreService: firestoreService,
            analytics: fakeAnalytics,
            observer: fakeObserver,
            brokerageUser: brokerageUser,
            service: service,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initial period is ALL Return
      expect(find.text('ALL Return'), findsOneWidget);
      expect(find.text('+110.5%'), findsOneWidget);
      expect(find.text('+65.0%'), findsOneWidget);

      // Switch to 1M
      final chip1M = find.widgetWithText(ChoiceChip, '1M');
      expect(chip1M, findsOneWidget);
      await tester.tap(chip1M);
      await tester.pumpAndSettle();

      expect(find.text('1M Return'), findsOneWidget);
      expect(find.text('+8.5%'), findsOneWidget);
      expect(find.text('+4.0%'), findsOneWidget);
    });
  });
}
