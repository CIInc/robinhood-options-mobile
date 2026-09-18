import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/group_activity.dart';
import 'package:robinhood_options_mobile/model/group_analysis.dart';
import 'package:robinhood_options_mobile/model/user_follow.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/widgets/following_activity_feed_widget.dart';
import 'package:robinhood_options_mobile/widgets/share_trade_idea_sheet.dart';

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

  group('FollowingActivityFeedWidget Tests', () {
    late FakeFirebaseFirestore fakeDb;
    late FirestoreService firestoreService;
    final mockUser = MockFirebaseUser();
    late MockFirebaseAuthWithUser mockAuth;
    final fakeAnalytics = FakeAnalytics();
    final fakeObserver = FakeObserver();
    final brokerageUser =
        BrokerageUser(BrokerageSource.demo, 'demo_user', null, null);
    final service = DemoService();

    setUp(() async {
      fakeDb = FakeFirebaseFirestore();
      firestoreService = FirestoreService(firestore: fakeDb);
      mockAuth = MockFirebaseAuthWithUser(mockUser);

      // Current user follows 'alice'
      final follow = UserFollow(
        id: 'alice',
        followerId: mockUser.uid,
        followerName: 'Test User',
        followingId: 'alice',
        followingName: 'Alice Trader',
        createdAt: DateTime.now(),
      );
      await fakeDb
          .collection(firestoreService.userCollectionName)
          .doc(mockUser.uid)
          .collection('following')
          .doc('alice')
          .set(follow.toJson());

      // Seed trade activity for Alice
      final activity = GroupActivity(
        id: 'act_1',
        groupId: 'public_social_feed',
        userId: 'alice',
        userName: 'Alice Trader',
        type: GroupActivityType.trade,
        title: 'Bought 10 shares of AAPL',
        symbol: 'AAPL',
        side: 'buy',
        quantity: 10,
        price: 220.0,
        assetType: 'equity',
        timestamp: DateTime(2026, 9, 17, 10, 0),
      );
      await fakeDb
          .collection(firestoreService.socialActivityCollectionName)
          .doc('act_1')
          .set(activity.toJson());

      // Seed trade idea for Alice (followed)
      final ideaAlice = GroupAnalysisPost(
        id: 'idea_alice',
        groupId: 'social',
        authorId: 'alice',
        authorName: 'Alice Trader',
        title: 'NVDA Q3 Breakout',
        symbol: 'NVDA',
        sentiment: GroupAnalysisSentiment.bullish,
        thesis: 'Strong momentum and enterprise AI demand.',
        entryTarget: 140.0,
        targetPrice: 180.0,
        stopLoss: 125.0,
        timeHorizon: GroupAnalysisTimeHorizon.mediumTerm,
        createdAt: DateTime(2026, 9, 17, 11, 0),
      );
      await fakeDb
          .collection(firestoreService.socialTradeIdeaCollectionName)
          .doc('idea_alice')
          .set(ideaAlice.toJson());

      // Seed trade idea for Bob (community, not followed)
      final ideaBob = GroupAnalysisPost(
        id: 'idea_bob',
        groupId: 'social',
        authorId: 'bob',
        authorName: 'Bob Trader',
        title: 'TSLA Overbought Short Setup',
        symbol: 'TSLA',
        sentiment: GroupAnalysisSentiment.bearish,
        thesis: 'Testing upper resistance channel, asymmetric risk.',
        entryTarget: 260.0,
        targetPrice: 210.0,
        stopLoss: 275.0,
        timeHorizon: GroupAnalysisTimeHorizon.shortTerm,
        createdAt: DateTime(2026, 9, 17, 12, 0),
      );
      await fakeDb
          .collection(firestoreService.socialTradeIdeaCollectionName)
          .doc('idea_bob')
          .set(ideaBob.toJson());
    });

    Widget createTestWidget() {
      return MaterialApp(
        home: FollowingActivityFeedWidget(
          auth: mockAuth,
          firestoreService: firestoreService,
          brokerageUser: brokerageUser,
          service: service,
          analytics: fakeAnalytics,
          observer: fakeObserver,
        ),
      );
    }

    testWidgets('renders appbar title, tabs, and share idea FAB',
        (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Social Feed & Ideas'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Trade Ideas'), findsOneWidget);
      expect(find.text('Trades'), findsOneWidget);
      expect(find.text('Community'), findsOneWidget);
      expect(find.text('Share Idea'), findsOneWidget);
    });

    testWidgets('renders all feed with interleaved trades and trade ideas',
        (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Alice's trade and idea should appear on the All tab
      expect(find.text('Bought 10 shares of AAPL'), findsOneWidget);
      expect(find.text('NVDA Q3 Breakout'), findsOneWidget);
      expect(find.text('\$NVDA'), findsOneWidget);
      expect(find.text('BULLISH'), findsOneWidget);
      expect(find.text('Clone Strategy'), findsOneWidget);
    });

    testWidgets(
        'switching to Trade Ideas tab displays followed ideas and sentiment filters',
        (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap 'Trade Ideas' tab
      await tester.tap(find.text('Trade Ideas'));
      await tester.pumpAndSettle();

      // Alice's idea should be visible
      expect(find.text('NVDA Q3 Breakout'), findsOneWidget);
      expect(find.text('\$NVDA'), findsOneWidget);
      expect(find.text('Clone Strategy'), findsOneWidget);

      // Bob's idea is not followed, so it should not appear here
      expect(find.text('TSLA Overbought Short Setup'), findsNothing);

      // Filter button should open sentiment filter options
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();
      expect(find.text('All Ideas'), findsOneWidget);
      expect(find.text('Bullish'), findsOneWidget);
      expect(find.text('Bearish'), findsOneWidget);
    });

    testWidgets(
        'switching to Trades tab displays trade activity cards with Copy button',
        (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap 'Trades' tab
      await tester.tap(find.text('Trades'));
      await tester.pumpAndSettle();

      expect(find.text('Bought 10 shares of AAPL'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
    });

    testWidgets(
        'switching to Community tab displays public community ideas including non-followed traders',
        (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap 'Community' tab
      await tester.tap(find.text('Community'));
      await tester.pumpAndSettle();

      // Both Alice's and Bob's ideas should appear in Community
      expect(find.text('NVDA Q3 Breakout'), findsOneWidget);
      expect(find.text('TSLA Overbought Short Setup'), findsOneWidget);
      expect(find.text('\$TSLA'), findsOneWidget);
      expect(find.text('BEARISH'), findsOneWidget);
    });

    testWidgets('tapping Share Idea FAB opens ShareTradeIdeaSheet',
        (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Share Idea'));
      await tester.pumpAndSettle();

      expect(find.byType(ShareTradeIdeaSheet), findsOneWidget);
      expect(find.text('Share Trade Idea'), findsOneWidget);
      expect(find.text('Thesis Headline'), findsOneWidget);
      expect(find.text('Investment Thesis & Catalyst'), findsOneWidget);
    });

    testWidgets(
        'renders properly when embedded (showAppBar: false, showFab: false)',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: FollowingActivityFeedWidget(
          auth: mockAuth,
          firestoreService: firestoreService,
          analytics: fakeAnalytics,
          observer: fakeObserver,
          brokerageUser: brokerageUser,
          service: service,
          showAppBar: false,
          showFab: false,
        ),
      ));
      await tester.pumpAndSettle();

      // App bar title and FAB are hidden
      expect(find.text('Social Feed & Ideas'), findsNothing);
      expect(find.text('Share Idea'), findsNothing);

      // Embedded tabs are visible
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Trade Ideas'), findsOneWidget);
      expect(find.text('Trades'), findsOneWidget);
      expect(find.text('Community'), findsOneWidget);
    });

    testWidgets(
        'feed toolbar renders stream pills and filter button in a single row without search bar',
        (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoSearchTextField), findsNothing);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Trade Ideas'), findsOneWidget);
      expect(find.text('Trades'), findsOneWidget);
      expect(find.text('Community'), findsOneWidget);
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
    });

    testWidgets(
        'tapping Community chip switches tab to Community and keeps selection without resetting',
        (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap Community chip
      await tester.tap(find.text('Community'));
      await tester.pumpAndSettle();

      // Community tab content is displayed
      expect(find.text('TSLA Overbought Short Setup'), findsOneWidget);

      // Verify ChoiceChip for Community remains selected
      final communityChip = tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Community'));
      expect(communityChip.selected, isTrue);

      final allChip =
          tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'All'));
      expect(allChip.selected, isFalse);
    });

    testWidgets(
        'author sees options menu with Edit and Delete on own idea, while other ideas do not show options',
        (tester) async {
      // Seed an idea authored by the logged-in user
      final myIdea = GroupAnalysisPost(
        id: 'idea_self',
        groupId: 'social',
        authorId: mockUser.uid,
        authorName: 'Test User',
        title: 'My Bullish Thesis',
        symbol: 'AMD',
        sentiment: GroupAnalysisSentiment.bullish,
        thesis: 'Strong server share gains against competition',
        entryTarget: 150.0,
        targetPrice: 190.0,
        stopLoss: 135.0,
        timeHorizon: GroupAnalysisTimeHorizon.mediumTerm,
        createdAt: DateTime(2026, 9, 17, 14, 0),
      );
      await fakeDb
          .collection(firestoreService.socialTradeIdeaCollectionName)
          .doc('idea_self')
          .set(myIdea.toJson());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Navigate to Community tab where both my idea and others' ideas appear
      await tester.tap(find.text('Community'));
      await tester.pumpAndSettle();

      expect(find.text('My Bullish Thesis'), findsOneWidget);
      expect(find.text('TSLA Overbought Short Setup'), findsOneWidget);

      // Only 1 PopupMenuButton exists across the cards (for myIdea, not for Bob's idea)
      expect(find.byTooltip('Idea options'), findsOneWidget);

      // Tap options menu to reveal Edit Idea and Delete Idea
      await tester.tap(find.byTooltip('Idea options'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Idea'), findsOneWidget);
      expect(find.text('Delete Idea'), findsOneWidget);
    });

    testWidgets(
        'tapping Edit Idea opens ShareTradeIdeaSheet pre-populated with existing data',
        (tester) async {
      final myIdea = GroupAnalysisPost(
        id: 'idea_edit_test',
        groupId: 'social',
        authorId: mockUser.uid,
        authorName: 'Test User',
        title: 'Breakout Play for MSFT',
        symbol: 'MSFT',
        sentiment: GroupAnalysisSentiment.bullish,
        thesis: 'Azure cloud growth acceleration',
        entryTarget: 420.0,
        targetPrice: 470.0,
        stopLoss: 400.0,
        timeHorizon: GroupAnalysisTimeHorizon.longTerm,
        createdAt: DateTime(2026, 9, 17, 14, 0),
      );
      await fakeDb
          .collection(firestoreService.socialTradeIdeaCollectionName)
          .doc('idea_edit_test')
          .set(myIdea.toJson());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Community'));
      await tester.pumpAndSettle();

      // Open options and tap Edit Idea
      await tester.tap(find.byTooltip('Idea options'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Edit Idea'));
      await tester.pumpAndSettle();

      // Edit Trade Idea modal should be open
      expect(find.byType(ShareTradeIdeaSheet), findsOneWidget);
      expect(find.text('Edit Trade Idea'), findsOneWidget);
      expect(
          find.descendant(
            of: find.byType(ShareTradeIdeaSheet),
            matching: find.text('Breakout Play for MSFT'),
          ),
          findsOneWidget);
      expect(
          find.descendant(
            of: find.byType(ShareTradeIdeaSheet),
            matching: find.text('MSFT'),
          ),
          findsOneWidget);
      expect(
          find.descendant(
            of: find.byType(ShareTradeIdeaSheet),
            matching: find.text('Azure cloud growth acceleration'),
          ),
          findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
    });

    testWidgets(
        'author can delete idea after confirming in confirmation dialog',
        (tester) async {
      final myIdea = GroupAnalysisPost(
        id: 'idea_delete_test',
        groupId: 'social',
        authorId: mockUser.uid,
        authorName: 'Test User',
        title: 'Idea to be deleted',
        symbol: 'COIN',
        sentiment: GroupAnalysisSentiment.neutral,
        thesis: 'Short term rangebound play',
        createdAt: DateTime(2026, 9, 17, 14, 0),
      );
      await fakeDb
          .collection(firestoreService.socialTradeIdeaCollectionName)
          .doc('idea_delete_test')
          .set(myIdea.toJson());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Community'));
      await tester.pumpAndSettle();

      expect(find.text('Idea to be deleted'), findsOneWidget);

      // Open options and tap Delete Idea
      await tester.tap(find.byTooltip('Idea options'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete Idea'));
      await tester.pumpAndSettle();

      // Confirmation dialog should be displayed
      expect(find.text('Delete Trade Idea'), findsOneWidget);
      expect(
          find.text(
              'Are you sure you want to delete this trade idea? This action cannot be undone.'),
          findsOneWidget);

      // Tap Delete in dialog
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      // Document is deleted from firestore
      final doc = await fakeDb
          .collection(firestoreService.socialTradeIdeaCollectionName)
          .doc('idea_delete_test')
          .get();
      expect(doc.exists, isFalse);

      // Snackbar is shown
      expect(find.text('Trade idea deleted.'), findsOneWidget);
    });

    testWidgets(
        'details sheet shows options menu for author with Edit and Delete',
        (tester) async {
      final myIdea = GroupAnalysisPost(
        id: 'idea_details_test',
        groupId: 'social',
        authorId: mockUser.uid,
        authorName: 'Test User',
        title: 'Detailed Thesis',
        symbol: 'AMZN',
        sentiment: GroupAnalysisSentiment.bullish,
        thesis: 'Retail margins expanding with AWS AI services',
        createdAt: DateTime(2026, 9, 17, 14, 0),
      );
      await fakeDb
          .collection(firestoreService.socialTradeIdeaCollectionName)
          .doc('idea_details_test')
          .set(myIdea.toJson());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Community'));
      await tester.pumpAndSettle();

      // Tap on the card itself to open details sheet
      await tester.tap(find.text('Detailed Thesis'));
      await tester.pumpAndSettle();

      // Bottom sheet is displayed
      expect(find.text('Shared Trade Idea'), findsOneWidget);
      expect(find.text('Clone this Strategy'), findsOneWidget);

      // Details bottom sheet header contains options button
      expect(find.byTooltip('Idea options'), findsWidgets);
    });
  });
}
