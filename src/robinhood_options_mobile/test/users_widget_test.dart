import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/widgets/users_widget.dart';

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

class MockFirebaseUser extends Fake implements firebase_auth.User {
  @override
  String get uid => 'test_user_id';
  @override
  String? get displayName => 'Test User';
  @override
  String? get photoURL => null;
}

class MockFirebaseAuthWithUser extends Fake
    implements firebase_auth.FirebaseAuth {
  final firebase_auth.User _user;
  MockFirebaseAuthWithUser(this._user);

  @override
  firebase_auth.User? get currentUser => _user;

  @override
  Stream<firebase_auth.User?> authStateChanges() => Stream.value(_user);
}

void main() {
  setUpAll(() async {
    await setupFirebaseMocks();
  });

  group('UsersWidget (Discover Traders) Tests', () {
    late FakeFirebaseFirestore fakeDb;
    final mockUser = MockFirebaseUser();
    late MockFirebaseAuthWithUser mockAuth;
    final fakeAnalytics = FakeAnalytics();
    final fakeObserver = FakeObserver();
    final brokerageUser =
        BrokerageUser(BrokerageSource.demo, 'demo_user', null, null);
    final service = DemoService();

    setUp(() {
      fakeDb = FakeFirebaseFirestore();
      mockAuth = MockFirebaseAuthWithUser(mockUser);
    });

    Widget createTestWidget() {
      return MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: UsersWidget(
          mockAuth,
          service,
          firestoreService: FirestoreService(firestore: fakeDb),
          analytics: fakeAnalytics,
          observer: fakeObserver,
          brokerageUser: brokerageUser,
        ),
      );
    }

    testWidgets(
        'renders Discover Traders title and search bar without Leaderboard banner or icon',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verify page title and search bar
      expect(find.text('Discover Traders'), findsOneWidget);
      expect(find.byType(CupertinoSearchTextField), findsOneWidget);

      // Verify Top Portfolios Leaderboard card and icon are NOT present
      expect(find.byIcon(Icons.leaderboard_rounded), findsNothing);
      expect(find.text('Top Portfolios Leaderboard'), findsNothing);
      expect(find.text('View ranked traders, track records & credibility'),
          findsNothing);
    });
  });
}
