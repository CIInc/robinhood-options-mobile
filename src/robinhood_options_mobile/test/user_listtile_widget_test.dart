import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/top_portfolio_entry.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/widgets/user_listtile_widget.dart';

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

  group('UserListTile Semantics Tests', () {
    late FakeFirebaseFirestore fakeDb;
    final fakeAnalytics = FakeAnalytics();
    final fakeObserver = FakeObserver();
    final brokerageUser =
        BrokerageUser(BrokerageSource.demo, 'demo_user', null, null);
    final service = DemoService();

    setUp(() {
      fakeDb = FakeFirebaseFirestore();
    });

    testWidgets(
        'provides unified screen reader semantics for user profile card',
        (tester) async {
      final docRef = fakeDb.collection('users').doc('trader_123');
      await docRef.set({
        'name': 'Alex Trader',
        'location': 'New York, NY',
        'followersCount': 15,
        'followingCount': 5,
      });

      final doc = await docRef
          .withConverter<User>(
            fromFirestore: (snapshot, _) => User.fromJson(snapshot.data()!),
            toFirestore: (user, _) => user.toJson(),
          )
          .get();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserListTile(
              document: doc,
              showNavigation: true,
              analytics: fakeAnalytics,
              observer: fakeObserver,
              brokerageUser: brokerageUser,
              service: service,
            ),
          ),
        ),
      );

      final expectedTier =
          ReputationTier.fromScore((15 * 2).clamp(0, 100)).label;
      final expectedLabel =
          'Alex Trader, New York, NY, 15 followers, $expectedTier tier';

      expect(find.bySemanticsLabel(expectedLabel), findsOneWidget);

      final semantics = tester.getSemantics(find.byType(UserListTile));
      expect(semantics.label, equals(expectedLabel));
      expect(semantics.hint, equals('Double tap to view trader profile'));
    });
  });
}
