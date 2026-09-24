import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_config.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/widgets/investor_groups_widget.dart';

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

class MockAgenticTradingProvider extends ChangeNotifier
    implements AgenticTradingProvider {
  @override
  AgenticTradingConfig config = AgenticTradingConfig(
    strategyConfig: TradeStrategyConfig(),
    autoTradeEnabled: false,
  );

  @override
  bool showAutoTradingVisual = false;

  @override
  bool emergencyStopActivated = false;

  @override
  int dailyTradeCount = 0;

  @override
  int autoTradeCountdownSeconds = 300;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async {
    await setupFirebaseMocks();
  });

  group('InvestorGroupsWidget Streamlined Redesign Tests', () {
    late FakeFirebaseFirestore fakeDb;
    late FirestoreService firestoreService;
    final fakeAnalytics = FakeAnalytics();
    final fakeObserver = FakeObserver();
    final brokerageUser =
        BrokerageUser(BrokerageSource.demo, 'demo_user', null, null);
    final service = DemoService();
    late MockAgenticTradingProvider mockAgenticProvider;
    late BrokerageUserStore mockBrokerageUserStore;
    late AccountStore mockAccountStore;

    setUp(() {
      fakeDb = FakeFirebaseFirestore();
      firestoreService = FirestoreService(firestore: fakeDb);
      mockAgenticProvider = MockAgenticTradingProvider();
      mockBrokerageUserStore = BrokerageUserStore([], 0);
      mockAccountStore = AccountStore();
    });

    Widget createTestWidget() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AgenticTradingProvider>.value(
            value: mockAgenticProvider,
          ),
          ChangeNotifierProvider<BrokerageUserStore>.value(
            value: mockBrokerageUserStore,
          ),
          ChangeNotifierProvider<AccountStore>.value(
            value: mockAccountStore,
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: InvestorGroupsWidget(
            firestoreService: firestoreService,
            brokerageUser: brokerageUser,
            service: service,
            analytics: fakeAnalytics,
            observer: fakeObserver,
          ),
        ),
      );
    }

    testWidgets(
        'renders 3 primary tabs (Feed, Leaderboard, Groups) and overflow menu',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verify the 3 streamlined primary tabs
      expect(find.text('Feed'), findsOneWidget);
      expect(find.text('Leaderboard'), findsOneWidget);
      expect(find.text('Groups'), findsOneWidget);

      // Verify overflow action menu button is present in app bar
      expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);

      // Verify old top-level icon buttons are removed from app bar
      expect(find.byTooltip('Following Activity Feed'), findsNothing);
      expect(find.byTooltip('Copy Trading History'), findsNothing);
    });

    testWidgets('tapping Groups tab displays segmented filter chips',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap the 'Groups' tab (index 2)
      await tester.tap(find.text('Groups'));
      await tester.pumpAndSettle();

      // Verify segmented filter chips are present
      expect(find.text('All Groups'), findsOneWidget);
      expect(find.text('My Groups'), findsOneWidget);
      expect(find.text('Invitations'), findsOneWidget);

      // Verify old confusing discover cards are gone
      expect(find.text('Ranked traders & returns'), findsNothing);
      expect(find.text('Find & follow top peers'), findsNothing);
    });

    testWidgets(
        'Groups tab renders toolbar with category chips, search bar, and sort menu icon',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Groups'));
      await tester.pumpAndSettle();

      // Verify Search bar and sort button
      expect(find.byType(CupertinoSearchTextField), findsOneWidget);
      expect(find.byIcon(Icons.sort_rounded), findsOneWidget);

      // Verify Category chips are present
      expect(find.text('All Groups'), findsOneWidget);
      expect(find.text('My Groups'), findsOneWidget);
      expect(find.text('Invitations'), findsOneWidget);

      // Verify redundant sort chips are removed
      expect(find.widgetWithText(ChoiceChip, 'Members'), findsNothing);
      expect(find.widgetWithText(ChoiceChip, 'Recent'), findsNothing);
      expect(find.widgetWithText(ChoiceChip, 'Name'), findsNothing);

      // Verify Search is located below the Category chips row
      final chipPos = tester.getTopLeft(find.text('All Groups'));
      final searchPos =
          tester.getTopLeft(find.byType(CupertinoSearchTextField));
      expect(searchPos.dy, greaterThan(chipPos.dy));

      // Verify sort popup menu button opens options
      await tester.tap(find.byIcon(Icons.sort_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Most Members'), findsOneWidget);
      expect(find.text('Recent Activity'), findsOneWidget);
      expect(find.text('Alphabetical'), findsOneWidget);
    });

    testWidgets(
        'Leaderboard tab renders Publish floating action button matching other tabs',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      FakeFirebaseAuth.mockUser = MockFirebaseUser();
      addTearDown(() {
        FakeFirebaseAuth.mockUser = null;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // On Tab 0 (Feed), Share Idea FAB is present
      expect(find.text('Share Idea'), findsOneWidget);
      expect(find.text('Publish'), findsNothing);

      // Switch to Tab 1 (Leaderboard)
      await tester.tap(find.text('Leaderboard'));
      await tester.pumpAndSettle();

      // Publish FAB is now present to match other tabs
      expect(find.text('Publish'), findsOneWidget);
      expect(find.text('Share Idea'), findsNothing);
      expect(find.text('Create Group'), findsNothing);

      // Tapping Publish opens PublishPortfolioBottomSheet
      await tester.tap(find.text('Publish'));
      await tester.pumpAndSettle();
      expect(find.text('Leaderboard Publication'), findsOneWidget);
    });
  });
}
