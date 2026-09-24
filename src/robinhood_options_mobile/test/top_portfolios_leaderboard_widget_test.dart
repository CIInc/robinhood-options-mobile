import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/portfolio_privacy_settings.dart';
import 'package:robinhood_options_mobile/model/top_portfolio_entry.dart';
import 'package:robinhood_options_mobile/model/verified_track_record.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/widgets/top_portfolios_leaderboard_widget.dart';

import 'firebase_mocks.dart';

class FakeUser extends Fake implements firebase_auth.User {
  final String _uid;
  final String? _displayName;
  final String? _photoURL;

  FakeUser({
    String uid = 'test_user',
    String? displayName = 'Test Trader',
    String? photoURL,
  })  : _uid = uid,
        _displayName = displayName,
        _photoURL = photoURL;

  @override
  String get uid => _uid;

  @override
  String? get displayName => _displayName;

  @override
  String? get photoURL => _photoURL;
}

class FakeFirebaseAuthWithUser extends Fake
    implements firebase_auth.FirebaseAuth {
  final firebase_auth.User _user;
  FakeFirebaseAuthWithUser(this._user);

  @override
  firebase_auth.User? get currentUser => _user;

  @override
  Stream<firebase_auth.User?> authStateChanges() => Stream.value(_user);
}

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

  group('TopPortfoliosLeaderboardWidget Tests', () {
    late FakeFirebaseFirestore fakeDb;
    late FirestoreService firestoreService;
    final fakeAnalytics = FakeAnalytics();
    final fakeObserver = FakeObserver();
    final brokerageUser =
        BrokerageUser(BrokerageSource.demo, 'demo_user', null, null);
    final service = DemoService();

    setUp(() async {
      fakeDb = FakeFirebaseFirestore();
      firestoreService = FirestoreService(firestore: fakeDb);

      // Seed 3 traders for podium
      // 1. Alice (1st place)
      await fakeDb
          .collection(firestoreService.userCollectionName)
          .doc('alice')
          .set({
        'id': 'alice',
        'name': 'Alice Capital',
        'followersCount': 120,
        'followingCount': 10,
        'portfolioPrivacy':
            const PortfolioPrivacySettings(isPublic: true).toJson(),
      });

      final aliceRecord = VerifiedTrackRecord(
        userId: 'alice',
        userName: 'Alice Capital',
        isVerified: true,
        tier: VerifiedLeaderTier.masterTrader,
        verifiedReturnPercent: 115.0,
        verifiedWinRate: 75.0,
        totalTradesAudited: 150,
        winningTrades: 112,
        losingTrades: 38,
        sharpeRatio: 2.8,
        maxDrawdownPercent: 6.5,
        profitFactor: 2.9,
        verificationDate: DateTime(2026, 9, 1),
        monthlyReturns: {
          '1W': 5.2,
          '1M': 18.0,
          '3M': 42.0,
          '1Y': 115.0,
        },
      );
      await fakeDb
          .collection(firestoreService.verifiedTrackRecordCollectionName)
          .doc('alice')
          .set(aliceRecord.toJson());

      // 2. Bob (2nd place)
      await fakeDb
          .collection(firestoreService.userCollectionName)
          .doc('bob')
          .set({
        'id': 'bob',
        'name': 'Bob Options',
        'followersCount': 45,
        'followingCount': 8,
        'portfolioPrivacy':
            const PortfolioPrivacySettings(isPublic: true).toJson(),
      });

      final bobRecord = VerifiedTrackRecord(
        userId: 'bob',
        userName: 'Bob Options',
        isVerified: true,
        tier: VerifiedLeaderTier.topPerformer,
        verifiedReturnPercent: 68.0,
        verifiedWinRate: 65.0,
        totalTradesAudited: 85,
        winningTrades: 55,
        losingTrades: 30,
        sharpeRatio: 2.1,
        maxDrawdownPercent: 9.0,
        profitFactor: 2.2,
        verificationDate: DateTime(2026, 9, 1),
        monthlyReturns: {
          '1W': 2.4,
          '1M': 8.5,
          '3M': 25.0,
          '1Y': 68.0,
        },
      );
      await fakeDb
          .collection(firestoreService.verifiedTrackRecordCollectionName)
          .doc('bob')
          .set(bobRecord.toJson());

      // 3. Charlie (3rd place)
      await fakeDb
          .collection(firestoreService.userCollectionName)
          .doc('charlie')
          .set({
        'id': 'charlie',
        'name': 'Charlie Quant',
        'followersCount': 20,
        'followingCount': 4,
        'portfolioPrivacy':
            const PortfolioPrivacySettings(isPublic: true).toJson(),
      });

      final charlieRecord = VerifiedTrackRecord(
        userId: 'charlie',
        userName: 'Charlie Quant',
        isVerified: true,
        tier: VerifiedLeaderTier.verifiedLeader,
        verifiedReturnPercent: 35.0,
        verifiedWinRate: 58.0,
        totalTradesAudited: 40,
        winningTrades: 23,
        losingTrades: 17,
        sharpeRatio: 1.6,
        maxDrawdownPercent: 11.2,
        profitFactor: 1.8,
        verificationDate: DateTime(2026, 9, 1),
        monthlyReturns: {
          '1W': 1.1,
          '1M': 4.0,
          '3M': 12.0,
          '1Y': 35.0,
        },
      );
      await fakeDb
          .collection(firestoreService.verifiedTrackRecordCollectionName)
          .doc('charlie')
          .set(charlieRecord.toJson());
    });

    Widget createWidgetUnderTest({firebase_auth.FirebaseAuth? auth}) {
      return MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: TopPortfoliosLeaderboardWidget(
          auth: auth ?? FakeFirebaseAuth(),
          firestoreService: firestoreService,
          analytics: fakeAnalytics,
          observer: fakeObserver,
          brokerageUser: brokerageUser,
          service: service,
        ),
      );
    }

    testWidgets('renders leaderboard title, period chips, and sort chips',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Verify title
      expect(find.text('Top Portfolios'), findsOneWidget);

      // Verify period chips
      expect(find.widgetWithText(ChoiceChip, '1W'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, '1M'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, '3M'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, '1Y'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'ALL'), findsOneWidget);

      // Verify sort chips
      expect(find.text('Highest Return'), findsOneWidget);
      expect(find.text('Sharpe Ratio'), findsOneWidget);
      expect(find.text('Win Rate'), findsOneWidget);
      expect(find.text('Reputation'), findsOneWidget);
      expect(find.text('Most Followed'), findsOneWidget);
    });

    testWidgets('renders podium and ranked traders with return metrics',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Top Performers section in podium
      expect(find.text('Top Performers (ALL)'), findsOneWidget);

      // Trader names in podium and list
      expect(find.text('Alice Capital'), findsWidgets);
      expect(find.text('Bob Options'), findsWidgets);
      expect(find.text('Charlie Quant'), findsWidgets);
    });

    testWidgets('period chip selection triggers period change',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Tap '1M' period chip
      await tester.tap(find.text('1M'));
      await tester.pumpAndSettle();

      expect(find.text('Top Performers (1M)'), findsOneWidget);
    });

    testWidgets(
        'leaderboard toolbar renders period and sort chips in a single row without search bar',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoSearchTextField), findsNothing);
      expect(find.widgetWithText(ChoiceChip, '1W'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'ALL'), findsOneWidget);
      expect(find.text('Alice Capital'), findsWidgets);
      expect(find.text('Bob Options'), findsWidgets);
      expect(find.text('Charlie Quant'), findsWidgets);
    });

    testWidgets('tapping info button opens reputation explainer bottom sheet',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Tap info icon button in AppBar
      await tester.tap(find.byIcon(Icons.info_outline_rounded));
      await tester.pumpAndSettle();

      // Verify Reputation Explainer Sheet
      expect(find.text('User Reputation System'), findsOneWidget);
      expect(find.text('Score Breakdown (100 Points Total)'), findsOneWidget);
      expect(find.text('Reputation Tiers'), findsOneWidget);
      expect(find.text('Master Trader'), findsWidgets);
    });

    testWidgets('renders properly when embedded (showAppBar: false)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: TopPortfoliosLeaderboardWidget(
          auth: FakeFirebaseAuth(),
          firestoreService: firestoreService,
          analytics: fakeAnalytics,
          observer: fakeObserver,
          brokerageUser: brokerageUser,
          service: service,
          showAppBar: false,
        ),
      ));
      await tester.pumpAndSettle();

      // App bar title is hidden
      expect(find.text('Top Portfolios'), findsNothing);

      // Period chips and info action remain visible without search field
      expect(find.byType(CupertinoSearchTextField), findsNothing);
      expect(find.widgetWithText(ChoiceChip, '1W'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'ALL'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
    });

    testWidgets('private portfolios are strictly excluded from the leaderboard',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Seed a private trader with high returns
      await fakeDb
          .collection(firestoreService.userCollectionName)
          .doc('secret_whale')
          .set({
        'id': 'secret_whale',
        'name': 'Secret Whale',
        'followersCount': 1000,
        'followingCount': 0,
        'portfolioPrivacy':
            const PortfolioPrivacySettings(isPublic: false).toJson(),
      });

      final secretRecord = VerifiedTrackRecord(
        userId: 'secret_whale',
        userName: 'Secret Whale',
        isVerified: true,
        tier: VerifiedLeaderTier.masterTrader,
        verifiedReturnPercent: 500.0,
        verifiedWinRate: 90.0,
        totalTradesAudited: 200,
        winningTrades: 180,
        losingTrades: 20,
        verificationDate: DateTime(2026, 9, 1),
        monthlyReturns: {
          '1W': 10.0,
          '1M': 40.0,
          '3M': 100.0,
          '1Y': 300.0,
        },
      );
      await fakeDb
          .collection(firestoreService.verifiedTrackRecordCollectionName)
          .doc('secret_whale')
          .set(secretRecord.toJson());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Secret Whale should NOT appear on the leaderboard
      expect(find.text('Secret Whale'), findsNothing);

      // Public traders appear
      expect(find.text('Alice Capital'), findsWidgets);
      expect(find.text('Bob Options'), findsWidgets);
    });

    testWidgets(
        'filter dialog does not include Public Portfolios Only switch and only shows Verified Only',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Open filter dialog
      await tester.tap(find.byTooltip('Filter Leaderboard'));
      await tester.pumpAndSettle();

      expect(find.text('Filter Leaderboard'), findsOneWidget);
      expect(find.text('Verified Only'), findsOneWidget);

      // Verify "Public Portfolios Only" switch is completely absent
      expect(find.text('Public Portfolios Only'), findsNothing);
      expect(
          find.text('Exclude traders who have marked their portfolio private'),
          findsNothing);
    });

    testWidgets('Tapping compare action enables compare mode and selection FAB',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Find compare button in AppBar
      final compareBtn = find.byTooltip('Compare Traders');
      expect(compareBtn, findsOneWidget);
      await tester.tap(compareBtn);
      await tester.pumpAndSettle();

      // Verify title updates to selection mode
      expect(find.text('Select Traders (0/4)'), findsOneWidget);

      // Checkboxes appear for comparing traders
      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsWidgets);

      // Select first two traders
      await tester.tap(checkboxes.at(0));
      await tester.pumpAndSettle();
      expect(find.text('Select Traders (1/4)'), findsOneWidget);

      await tester.tap(checkboxes.at(1));
      await tester.pumpAndSettle();
      expect(find.text('Select Traders (2/4)'), findsOneWidget);

      // Compare FAB appears
      expect(find.text('Compare (2)'), findsOneWidget);
    });

    testWidgets(
        'tapping publish floating action button opens PublishPortfolioBottomSheet',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final user = FakeUser(uid: 'user_123', displayName: 'David Trader');
      final auth = FakeFirebaseAuthWithUser(user);

      await tester.pumpWidget(createWidgetUnderTest(auth: auth));
      await tester.pumpAndSettle();

      final publishFab = find.byType(FloatingActionButton);
      expect(publishFab, findsOneWidget);
      expect(find.text('Publish'), findsOneWidget);

      await tester.tap(publishFab);
      await tester.pumpAndSettle();

      expect(find.text('Leaderboard Publication'), findsOneWidget);
      expect(find.text('Manage your public visibility and ranking'),
          findsOneWidget);
      expect(find.text('Status: Not Published'), findsOneWidget);
      expect(find.text('Publish Portfolio to Leaderboard'), findsOneWidget);
    });

    testWidgets(
        'empty state displays Publish My Portfolio button and tapping it opens bottom sheet',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final emptyDb = FakeFirebaseFirestore();
      final emptyFirestoreService = FirestoreService(firestore: emptyDb);
      final user = FakeUser(uid: 'user_123', displayName: 'David Trader');
      final auth = FakeFirebaseAuthWithUser(user);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: TopPortfoliosLeaderboardWidget(
            auth: auth,
            firestoreService: emptyFirestoreService,
            analytics: fakeAnalytics,
            observer: fakeObserver,
            brokerageUser: brokerageUser,
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Portfolios Found'), findsOneWidget);
      expect(find.text('No public portfolios match the current filters.'),
          findsOneWidget);
      expect(find.text('Publish My Portfolio'), findsOneWidget);

      await tester.tap(find.text('Publish My Portfolio'));
      await tester.pumpAndSettle();

      expect(find.text('Leaderboard Publication'), findsOneWidget);
    });

    testWidgets(
        'PublishPortfolioBottomSheet publishes portfolio and updates Firestore',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final user = FakeUser(uid: 'david', displayName: 'David Trader');
      final auth = FakeFirebaseAuthWithUser(user);

      await fakeDb
          .collection(firestoreService.userCollectionName)
          .doc('david')
          .set({
        'id': 'david',
        'name': 'David Trader',
        'portfolioPrivacy':
            const PortfolioPrivacySettings(isPublic: false).toJson(),
      });

      await tester.pumpWidget(createWidgetUnderTest(auth: auth));
      await tester.pumpAndSettle();

      // Open publish sheet
      await tester.tap(find.text('Publish'));
      await tester.pumpAndSettle();

      expect(find.text('Status: Not Published'), findsOneWidget);

      // Tap publish button
      await tester.tap(find.text('Publish Portfolio to Leaderboard'));
      await tester.pumpAndSettle();

      // Sheet closes and entry should now exist in Firestore
      final entry = await firestoreService.getTopPortfolioEntry('david');
      expect(entry, isNotNull);
      expect(entry!.userId, equals('david'));
      expect(entry.isPublic, isTrue);

      // User document privacy should have been updated to isPublic: true
      final userDoc = await fakeDb
          .collection(firestoreService.userCollectionName)
          .doc('david')
          .get();
      expect(userDoc.data()!['portfolioPrivacy']['isPublic'], isTrue);
    });

    testWidgets(
        'PublishPortfolioBottomSheet unpublishes portfolio from leaderboard',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final user = FakeUser(uid: 'david', displayName: 'David Trader');
      final auth = FakeFirebaseAuthWithUser(user);

      await fakeDb
          .collection(firestoreService.userCollectionName)
          .doc('david')
          .set({
        'id': 'david',
        'name': 'David Trader',
        'portfolioPrivacy':
            const PortfolioPrivacySettings(isPublic: true).toJson(),
      });

      // Pre-seed top portfolio entry
      await firestoreService.setTopPortfolioEntry(
        const TopPortfolioEntry(
          userId: 'david',
          userName: 'David Trader',
          returnPercent: 25.0,
          winRate: 60.0,
          reputation:
              UserReputation(score: 50, tier: ReputationTier.trustedTrader),
        ),
      );

      await tester.pumpWidget(createWidgetUnderTest(auth: auth));
      await tester.pumpAndSettle();

      // Open publish sheet
      await tester.tap(find.text('Publish'));
      await tester.pumpAndSettle();

      expect(find.text('Status: Published'), findsOneWidget);
      expect(find.text('Unpublish'), findsOneWidget);

      // Tap unpublish
      await tester.tap(find.text('Unpublish'));
      await tester.pumpAndSettle();

      // Entry should now be removed from Firestore
      final entry = await firestoreService.getTopPortfolioEntry('david');
      expect(entry, isNull);
    });

    testWidgets(
        'tapping leaderboard card navigates to TraderProfileWidget smoothly and preserves state on return',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Alice Capital should be visible
      expect(find.text('Alice Capital'), findsWidgets);

      // Tap on Alice Capital
      await tester.tap(find.text('Alice Capital').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Navigated to TraderProfileWidget
      expect(find.text('Trader Profile'), findsOneWidget);

      // Pop back to Leaderboard
      await tester.pageBack();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Leaderboard view is still active and cards remain rendered without spinner
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Alice Capital'), findsWidgets);
    });

    testWidgets(
        'shows guidance banner and persistent bottom bar in compare mode with showAppBar: false',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool compareModeReported = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: TopPortfoliosLeaderboardWidget(
              auth: FakeFirebaseAuth(),
              firestoreService: firestoreService,
              analytics: fakeAnalytics,
              observer: fakeObserver,
              brokerageUser: brokerageUser,
              service: service,
              showAppBar: false,
              onCompareModeChanged: (active) {
                compareModeReported = active;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap compare button on first trader card
      final compareButtons = find.byTooltip('Compare Trader');
      expect(compareButtons, findsWidgets);
      await tester.tap(compareButtons.first);
      await tester.pumpAndSettle();

      expect(compareModeReported, isTrue);

      // Verify guidance banner is visible
      expect(find.text('Compare Mode Active'), findsOneWidget);
      expect(find.text('Select 2 to 4 traders to compare metrics side-by-side'),
          findsOneWidget);
      expect(find.text('Exit'), findsOneWidget);

      // Verify persistent bottom bar is visible with selection count
      expect(find.text('1 of 4 selected'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Compare'), findsOneWidget);

      // Checkboxes appear
      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsWidgets);

      // Select second trader
      await tester.tap(checkboxes.at(1));
      await tester.pumpAndSettle();

      expect(find.text('2 of 4 selected'), findsOneWidget);

      // Tap Exit on the banner to cancel compare mode
      await tester.tap(find.text('Exit'));
      await tester.pumpAndSettle();

      expect(compareModeReported, isFalse);
      expect(find.text('Compare Mode Active'), findsNothing);
      expect(find.text('2 of 4 selected'), findsNothing);
    });

    testWidgets('unchecking all traders automatically exits compare mode',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool compareModeReported = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: TopPortfoliosLeaderboardWidget(
              auth: FakeFirebaseAuth(),
              firestoreService: firestoreService,
              analytics: fakeAnalytics,
              observer: fakeObserver,
              brokerageUser: brokerageUser,
              service: service,
              showAppBar: false,
              onCompareModeChanged: (active) {
                compareModeReported = active;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter compare mode via first card
      final compareButtons = find.byTooltip('Compare Trader');
      await tester.tap(compareButtons.first);
      await tester.pumpAndSettle();

      expect(compareModeReported, isTrue);
      expect(find.text('Compare Mode Active'), findsOneWidget);

      // Deselect the trader by tapping the checked checkbox
      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsWidgets);
      await tester.tap(checkboxes.first);
      await tester.pumpAndSettle();

      // Compare mode should now auto-exit because 0 traders are selected
      expect(compareModeReported, isFalse);
      expect(find.text('Compare Mode Active'), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
    });

    testWidgets(
        'tapping card row in compare mode still navigates to TraderProfileWidget',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: TopPortfoliosLeaderboardWidget(
              auth: FakeFirebaseAuth(),
              firestoreService: firestoreService,
              analytics: fakeAnalytics,
              observer: fakeObserver,
              brokerageUser: brokerageUser,
              service: service,
              showAppBar: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter compare mode via first card
      final compareButtons = find.byTooltip('Compare Trader');
      await tester.tap(compareButtons.first);
      await tester.pumpAndSettle();

      expect(find.text('Compare Mode Active'), findsOneWidget);

      // Tap on Alice Capital text/card (outside checkbox)
      await tester.tap(find.text('Alice Capital').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Successfully navigated to TraderProfileWidget without app restart!
      expect(find.text('Trader Profile'), findsOneWidget);
    });
  });
}
