import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/group_activity.dart';
import 'package:robinhood_options_mobile/model/investor_group.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:robinhood_options_mobile/widgets/investor_group_activity_feed_widget.dart';
import 'firebase_mocks.dart';

class FakeFirebaseAnalyticsObserver extends Fake
    implements FirebaseAnalyticsObserver {}

class MockTestFirebaseAnalytics extends Fake implements FirebaseAnalytics {
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

class MockActivityFirestoreService extends Fake implements FirestoreService {
  final List<GroupActivity> mockActivities;
  GroupActivityPrivacySettings privacySettings;

  MockActivityFirestoreService({
    required this.mockActivities,
    this.privacySettings = const GroupActivityPrivacySettings(),
  });

  @override
  Stream<List<GroupActivity>> getGroupActivitiesStream(
    String groupId, {
    String? memberId,
    GroupActivityType? type,
    int limit = 50,
  }) {
    List<GroupActivity> filtered = List.from(mockActivities);
    if (memberId != null) {
      filtered = filtered.where((a) => a.userId == memberId).toList();
    }
    if (type != null) {
      filtered = filtered.where((a) => a.type == type).toList();
    }
    return Stream.value(filtered);
  }

  @override
  Future<GroupActivityPrivacySettings> getUserGroupPrivacySettings(
      String groupId, String userId) async {
    return privacySettings;
  }

  @override
  Future<void> updateUserGroupPrivacySettings(String groupId, String userId,
      GroupActivityPrivacySettings settings) async {
    privacySettings = settings;
  }
}

void main() {
  setUpAll(() async {
    await setupFirebaseMocks();
  });

  final testBrokerageUser = BrokerageUser(
    BrokerageSource.demo,
    'demo_trader',
    null,
    null,
  );

  final testGroup = InvestorGroup(
    id: 'group_test_1',
    name: 'Alpha Traders',
    createdBy: 'user_1',
    members: ['user_1', 'user_2', 'user_3'],
    dateCreated: DateTime(2026, 1, 1),
    isPrivate: true,
  );

  final testActivities = [
    GroupActivity(
      id: 'act_1',
      groupId: 'group_test_1',
      userId: 'user_1',
      userName: 'Alice Trader',
      type: GroupActivityType.trade,
      title: 'Alice Trader bought AAPL',
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      symbol: 'AAPL',
      side: 'buy',
      quantity: 10,
      price: 150.0,
      orderType: 'market',
      assetType: 'equity',
    ),
    GroupActivity(
      id: 'act_2',
      groupId: 'group_test_1',
      userId: 'user_2',
      userName: 'Bob Trader',
      type: GroupActivityType.trade,
      title: 'Bob Trader sold TSLA',
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      symbol: 'TSLA',
      side: 'sell',
      quantity: 5,
      price: 200.0,
      orderType: 'limit',
      assetType: 'equity',
    ),
    GroupActivity(
      id: 'act_3',
      groupId: 'group_test_1',
      userId: 'user_3',
      userName: 'Charlie Speculator',
      type: GroupActivityType.watchlistUpdated,
      title: 'Charlie Speculator added NVDA to Watchlist',
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      symbol: 'NVDA',
    ),
  ];

  testWidgets(
      'InvestorGroupActivityFeedWidget renders activity list with filters and chips',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final mockFirestore =
        MockActivityFirestoreService(mockActivities: testActivities);

    await tester.pumpWidget(
      MaterialApp(
        home: InvestorGroupActivityFeedWidget(
          groupId: testGroup.id,
          group: testGroup,
          firestoreService: mockFirestore,
          service: DemoService(),
          brokerageUser: testBrokerageUser,
          analytics: MockTestFirebaseAnalytics(),
          observer: FakeFirebaseAnalyticsObserver(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify AppBar title
    expect(find.text('Activity Feed'), findsOneWidget);

    // Verify Filter Chips
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Trades'), findsOneWidget);
    expect(find.text('Watchlists'), findsOneWidget);
    expect(find.text('Members'), findsOneWidget);

    // Verify Activity items
    expect(find.text('Alice Trader'), findsOneWidget);
    expect(find.text('Alice Trader bought AAPL'), findsOneWidget);
    expect(find.text('AAPL'), findsOneWidget);

    expect(find.text('Bob Trader'), findsOneWidget);
    expect(find.text('Bob Trader sold TSLA'), findsOneWidget);
    expect(find.text('TSLA'), findsOneWidget);
  });

  testWidgets(
      'InvestorGroupActivityFeedWidget shows empty state when no activities exist',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final mockFirestore = MockActivityFirestoreService(mockActivities: []);

    await tester.pumpWidget(
      MaterialApp(
        home: InvestorGroupActivityFeedWidget(
          groupId: testGroup.id,
          group: testGroup,
          firestoreService: mockFirestore,
          service: DemoService(),
          brokerageUser: testBrokerageUser,
          analytics: MockTestFirebaseAnalytics(),
          observer: FakeFirebaseAnalyticsObserver(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No Activity Yet'), findsOneWidget);
  });

  testWidgets(
      'InvestorGroupActivityFeedWidget opens trade details sheet on tap',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final mockFirestore =
        MockActivityFirestoreService(mockActivities: testActivities);

    await tester.pumpWidget(
      MaterialApp(
        home: InvestorGroupActivityFeedWidget(
          groupId: testGroup.id,
          group: testGroup,
          firestoreService: mockFirestore,
          service: DemoService(),
          brokerageUser: testBrokerageUser,
          analytics: MockTestFirebaseAnalytics(),
          observer: FakeFirebaseAnalyticsObserver(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap the first activity tile
    await tester.tap(find.text('Alice Trader bought AAPL'));
    await tester.pumpAndSettle();

    // Verify detail sheet content
    expect(find.text('Execution Price'), findsOneWidget);
    expect(find.text('Total Value'), findsOneWidget);
    expect(find.text('Copy Trade'), findsOneWidget);
    expect(find.text('View Instrument'), findsOneWidget);
  });

  testWidgets('InvestorGroupActivityFeedWidget opens privacy controls dialog',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final mockFirestore =
        MockActivityFirestoreService(mockActivities: testActivities);

    await tester.pumpWidget(
      MaterialApp(
        home: InvestorGroupActivityFeedWidget(
          groupId: testGroup.id,
          group: testGroup,
          firestoreService: mockFirestore,
          service: DemoService(),
          brokerageUser: testBrokerageUser,
          analytics: MockTestFirebaseAnalytics(),
          observer: FakeFirebaseAnalyticsObserver(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap privacy icon button in app bar
    await tester.tap(find.byIcon(Icons.privacy_tip_outlined));
    await tester.pumpAndSettle();

    // Verify Privacy dialog contents
    expect(find.text('Privacy Controls'), findsOneWidget);
    expect(find.text('Share Trades with Group'), findsOneWidget);
    expect(find.text('Show Dollar Amounts'), findsOneWidget);
    expect(find.text('Post Anonymously'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });
}
