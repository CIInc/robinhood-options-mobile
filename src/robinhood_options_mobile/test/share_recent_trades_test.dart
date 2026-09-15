import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/group_activity.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_order.dart';
import 'package:robinhood_options_mobile/model/instrument_order_store.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/investor_group.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/widgets/investor_group_activity_feed_widget.dart';
import 'firebase_mocks.dart';

class FakeAnalyticsObserver extends Fake implements FirebaseAnalyticsObserver {}

class MockAnalytics extends Fake implements FirebaseAnalytics {
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

  group('FirestoreService shareRecentTradesToGroup Tests', () {
    late FakeFirebaseFirestore fakeDb;
    late FirestoreService firestoreService;
    const testGroupId = 'group-share-test';
    const testUserId = 'trader-1';

    setUp(() async {
      fakeDb = FakeFirebaseFirestore();
      firestoreService = FirestoreService(firestore: fakeDb);

      await fakeDb.collection('investor_groups').doc(testGroupId).set({
        'id': testGroupId,
        'name': 'Test Group',
        'createdBy': testUserId,
        'members': [testUserId],
        'dateCreated': Timestamp.now(),
        'isPrivate': false,
      });
    });

    test('shares trades successfully and respects deduplication', () async {
      final trades = [
        GroupActivity(
          id: '',
          groupId: testGroupId,
          userId: testUserId,
          userName: 'Trader One',
          type: GroupActivityType.trade,
          title: 'Bought AAPL',
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          symbol: 'AAPL',
          side: 'buy',
          quantity: 10,
          price: 180.0,
          orderType: 'market',
          assetType: 'equity',
          details: {'orderId': 'order-aapl-1'},
        ),
        GroupActivity(
          id: '',
          groupId: testGroupId,
          userId: testUserId,
          userName: 'Trader One',
          type: GroupActivityType.trade,
          title: 'Bought NVDA Call',
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
          symbol: 'NVDA',
          side: 'buy',
          quantity: 1,
          price: 5.0,
          orderType: 'limit',
          assetType: 'option',
          details: {
            'orderId': 'order-nvda-1',
            'strikePrice': 120.0,
            'optionType': 'call',
          },
        ),
      ];

      // 1. Initial share
      final sharedCount = await firestoreService.shareRecentTradesToGroup(
        groupId: testGroupId,
        userId: testUserId,
        userName: 'Trader One',
        activities: trades,
      );

      expect(sharedCount, equals(2));

      final activitiesSnap = await fakeDb
          .collection('investor_groups')
          .doc(testGroupId)
          .collection('activities')
          .get();

      expect(activitiesSnap.docs.length, equals(2));
      final titles =
          activitiesSnap.docs.map((d) => d.data()['title'] as String).toList();
      expect(titles, contains('Trader One bought AAPL'));
      expect(titles, contains('Trader One bought NVDA'));
      for (final t in titles) {
        expect(t, isNot(contains('buyed')));
        expect(t, isNot(contains('selled')));
      }

      // 2. Sharing same trades again triggers deduplication
      final secondShareCount = await firestoreService.shareRecentTradesToGroup(
        groupId: testGroupId,
        userId: testUserId,
        userName: 'Trader One',
        activities: trades,
      );

      expect(secondShareCount, equals(0));
    });

    test('formats sold trades as "sold" instead of "selled"', () async {
      final trades = [
        GroupActivity(
          id: '',
          groupId: testGroupId,
          userId: testUserId,
          userName: 'Trader One',
          type: GroupActivityType.trade,
          title: 'Sold COIN',
          timestamp: DateTime.now(),
          symbol: 'COIN',
          side: 'sell',
          quantity: 10,
          price: 250.0,
          details: {'orderId': 'order-coin-sold'},
        ),
      ];

      final count = await firestoreService.shareRecentTradesToGroup(
        groupId: testGroupId,
        userId: testUserId,
        userName: 'Trader One',
        activities: trades,
      );

      expect(count, equals(1));

      final activitiesSnap = await fakeDb
          .collection('investor_groups')
          .doc(testGroupId)
          .collection('activities')
          .where('symbol', isEqualTo: 'COIN')
          .get();

      final title = activitiesSnap.docs.first.data()['title'] as String;
      expect(title, equals('Trader One sold COIN'));
      expect(title, isNot(contains('selled')));
    });

    test('accounts for pending orders with proper type and title phrasing', () async {
      final trades = [
        GroupActivity(
          id: '',
          groupId: testGroupId,
          userId: testUserId,
          userName: 'Trader One',
          type: GroupActivityType.order,
          title: 'Sell Order: PCG',
          timestamp: DateTime.now(),
          symbol: 'PCG',
          side: 'sell',
          quantity: 1,
          price: 3.05,
          assetType: 'option',
          details: {
            'orderId': 'order-pending-pcg',
            'state': 'confirmed',
          },
        ),
      ];

      final count = await firestoreService.shareRecentTradesToGroup(
        groupId: testGroupId,
        userId: testUserId,
        userName: 'Trader One',
        activities: trades,
      );

      expect(count, equals(1));

      final activitiesSnap = await fakeDb
          .collection('investor_groups')
          .doc(testGroupId)
          .collection('activities')
          .where('symbol', isEqualTo: 'PCG')
          .get();

      final data = activitiesSnap.docs.first.data();
      expect(data['title'], equals('Trader One placed a sell order for PCG'));
      expect(data['type'], equals('order'));
      expect(data['quantity'], equals(1));

      final activity = GroupActivity.fromJson(data, activitiesSnap.docs.first.id);
      expect(activity.isPending, isTrue);
    });

    test('respects privacy settings when sharing trades', () async {
      // Set privacy settings: Anonymous and Hidden Amounts
      await firestoreService.updateUserGroupPrivacySettings(
        testGroupId,
        testUserId,
        const GroupActivityPrivacySettings(
          shareTrades: true,
          showTradeAmounts: false,
          anonymous: true,
        ),
      );

      final trades = [
        GroupActivity(
          id: '',
          groupId: testGroupId,
          userId: testUserId,
          userName: 'Secret Trader',
          type: GroupActivityType.trade,
          title: 'Bought TSLA',
          timestamp: DateTime.now(),
          symbol: 'TSLA',
          side: 'buy',
          quantity: 5,
          price: 200.0,
          details: {'orderId': 'order-tsla-anon'},
        ),
      ];

      final count = await firestoreService.shareRecentTradesToGroup(
        groupId: testGroupId,
        userId: testUserId,
        userName: 'Secret Trader',
        activities: trades,
      );

      expect(count, equals(1));

      final feed = await firestoreService
          .getGroupActivitiesStream(testGroupId)
          .first;

      expect(feed.length, equals(1));
      final item = feed.first;
      expect(item.isAnonymous, isTrue);
      expect(item.displayUserName, equals('Anonymous Member'));
      expect(item.title, equals('A member bought TSLA'));
      expect(item.title, isNot(contains('buyed')));
      expect(item.hideAmounts, isTrue);
      expect(item.formattedTotal, equals(r'$***'));
      expect(item.formattedQuantity, equals('***'));
    });

    test('returns 0 if shareTrades privacy is disabled', () async {
      await firestoreService.updateUserGroupPrivacySettings(
        testGroupId,
        testUserId,
        const GroupActivityPrivacySettings(shareTrades: false),
      );

      final trades = [
        GroupActivity(
          id: '',
          groupId: testGroupId,
          userId: testUserId,
          userName: 'Trader',
          type: GroupActivityType.trade,
          title: 'Bought MSFT',
          timestamp: DateTime.now(),
          symbol: 'MSFT',
          side: 'buy',
          quantity: 1,
          price: 400.0,
          details: {'orderId': 'order-msft-private'},
        ),
      ];

      final count = await firestoreService.shareRecentTradesToGroup(
        groupId: testGroupId,
        userId: testUserId,
        userName: 'Trader',
        activities: trades,
      );

      expect(count, equals(0));
    });
  });

  group('InvestorGroupActivityFeedWidget Share Recent Trades UI Tests', () {
    late FakeFirebaseFirestore fakeDb;
    late FirestoreService firestoreService;
    const testGroupId = 'grp-ui-share-test';
    const testUserId = 'test-uid';

    final testBrokerageUser = BrokerageUser(
      BrokerageSource.demo,
      'demo_trader',
      null,
      null,
    );

    final testGroup = InvestorGroup(
      id: testGroupId,
      name: 'Alpha Club',
      createdBy: testUserId,
      members: [testUserId],
      dateCreated: DateTime(2026, 1, 1),
      isPrivate: false,
    );

    setUp(() async {
      fakeDb = FakeFirebaseFirestore();
      firestoreService = FirestoreService(firestore: fakeDb);

      await fakeDb.collection('investor_groups').doc(testGroupId).set({
        'id': testGroupId,
        'name': 'Alpha Club',
        'createdBy': testUserId,
        'members': [testUserId],
        'dateCreated': Timestamp.now(),
        'isPrivate': false,
      });
    });

    testWidgets('shows Share Recent Trades button in empty state and opens modal',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: InvestorGroupActivityFeedWidget(
            groupId: testGroupId,
            group: testGroup,
            firestoreService: firestoreService,
            brokerageUser: testBrokerageUser,
            analytics: MockAnalytics(),
            observer: FakeAnalyticsObserver(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Empty state verification
      expect(find.text('No Activity Yet'), findsOneWidget);
      final shareBtn = find.widgetWithText(ElevatedButton, 'Share Recent Trades');
      expect(shareBtn, findsOneWidget);

      // Tap to open sheet
      await tester.tap(shareBtn);
      await tester.pumpAndSettle();

      // Verify bottom sheet opened
      expect(find.text('Share Recent Trades'), findsWidgets);
      expect(find.textContaining('Post your trades to Alpha Club'), findsOneWidget);
      expect(find.textContaining('Posting as:'), findsOneWidget);

      // Verify candidate demo trades
      expect(find.text('AAPL'), findsOneWidget);
      expect(find.text('Apple Inc.'), findsOneWidget);
      expect(find.text('NVDA'), findsOneWidget);
      expect(find.text('NVIDIA Corporation'), findsOneWidget);
      expect(find.text('TSLA'), findsOneWidget);
      expect(find.text('Tesla, Inc.'), findsOneWidget);
      expect(find.text('SPY'), findsOneWidget);
      expect(find.text('SPDR S&P 500 ETF Trust'), findsOneWidget);

      // Verify selection controls
      expect(find.text('4 of 4 selected'), findsOneWidget);

      // Tap Deselect All
      await tester.tap(find.text('Deselect All'));
      await tester.pumpAndSettle();
      expect(find.text('0 of 4 selected'), findsOneWidget);

      // Tap Select All
      await tester.tap(find.text('Select All'));
      await tester.pumpAndSettle();
      expect(find.text('4 of 4 selected'), findsOneWidget);

      // Tap Share Selected Trades
      final submitBtn = find.widgetWithText(ElevatedButton, 'Share 4 Trades to Feed');
      expect(submitBtn, findsOneWidget);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Verify snackbar confirmation
      expect(find.textContaining('Successfully shared 4 trades to the feed!'),
          findsOneWidget);

      // Verify activities now appear in the feed stream
      expect(find.text('AAPL'), findsOneWidget);
      expect(find.text('NVDA'), findsOneWidget);
      expect(find.text('TSLA'), findsOneWidget);
      expect(find.text('SPY'), findsOneWidget);
    });

    testWidgets('AppBar Share Recent Trades action opens modal', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: InvestorGroupActivityFeedWidget(
            groupId: testGroupId,
            group: testGroup,
            firestoreService: firestoreService,
            brokerageUser: testBrokerageUser,
            analytics: MockAnalytics(),
            observer: FakeAnalyticsObserver(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final shareAppBarIcon = find.byTooltip('Share Recent Trades');
      expect(shareAppBarIcon, findsOneWidget);

      await tester.tap(shareAppBarIcon);
      await tester.pumpAndSettle();

      expect(find.text('Share Recent Trades'), findsWidgets);
      expect(find.byType(CheckboxListTile), findsWidgets);
    });

    testWidgets(
        'resolves stock details from stores and avoids raw UUID header overflow',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const rawUuid = 'e39df238-010f-47b7-9823-6da7a137e5f6';
      const instrumentUrl = 'https://api.robinhood.com/instruments/$rawUuid/';

      final instStore = InstrumentStore();
      instStore.add(Instrument.fromJson({
        'id': rawUuid,
        'url': instrumentUrl,
        'symbol': 'AMZN',
        'name': 'Amazon.com, Inc.',
        'simple_name': 'Amazon',
        'quote': 'https://api.robinhood.com/quotes/AMZN/',
        'fundamentals': 'https://api.robinhood.com/fundamentals/AMZN/',
        'splits': 'https://api.robinhood.com/instruments/$rawUuid/splits/',
        'state': 'active',
        'market': 'https://api.robinhood.com/markets/XNAS/',
        'tradeable': true,
        'tradability': 'tradable',
        'bloomberg_unique': 'EQ00000000',
        'country': 'US',
        'type': 'stock',
        'rhs_tradability': 'tradable',
        'fractional_tradability': 'tradable',
        'is_spac': false,
        'is_test': false,
        'ipo_access_supports_dsp': false,
      }));

      final orderStore = InstrumentOrderStore();
      orderStore.add(InstrumentOrder.fromJson({
        'id': 'order-amzn-1',
        'url': 'https://api.robinhood.com/orders/order-amzn-1/',
        'account': 'https://api.robinhood.com/accounts/ACC123/',
        'position': 'https://api.robinhood.com/positions/ACC123/$rawUuid/',
        'instrument': instrumentUrl,
        'instrument_id': rawUuid,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'state': 'filled',
        'type': 'market',
        'side': 'buy',
        'time_in_force': 'gtc',
        'trigger': 'immediate',
        'quantity': '10.0',
        'price': '185.50',
        'cumulative_quantity': '10.0',
        'average_price': '185.50',
      }));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: instStore),
            ChangeNotifierProvider.value(value: orderStore),
          ],
          child: MaterialApp(
            home: InvestorGroupActivityFeedWidget(
              groupId: testGroupId,
              group: testGroup,
              firestoreService: firestoreService,
              brokerageUser: testBrokerageUser,
              analytics: MockAnalytics(),
              observer: FakeAnalyticsObserver(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final shareBtn = find.widgetWithText(ElevatedButton, 'Share Recent Trades');
      expect(shareBtn, findsOneWidget);
      await tester.tap(shareBtn);
      await tester.pumpAndSettle();

      // Ensure symbol and company name are displayed
      expect(find.text('AMZN'), findsOneWidget);
      expect(find.text('Amazon'), findsOneWidget);
      // Ensure the raw UUID is NOT displayed as the header
      expect(find.text(rawUuid), findsNothing);
    });

    testWidgets('displays pending orders with status badge and proper phrasing',
        (tester) async {
      final instStore = InstrumentStore();
      final orderStore = InstrumentOrderStore();
      orderStore.add(InstrumentOrder.fromJson({
        'id': 'order-goog-pending',
        'url': 'https://api.robinhood.com/orders/order-goog-pending/',
        'account': 'https://api.robinhood.com/accounts/ACC123/',
        'position': 'https://api.robinhood.com/positions/ACC123/inst-goog/',
        'instrument': 'https://api.robinhood.com/instruments/inst-goog/',
        'instrument_id': 'inst-goog',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'state': 'confirmed',
        'type': 'limit',
        'side': 'buy',
        'time_in_force': 'gtc',
        'trigger': 'immediate',
        'quantity': '5.0',
        'price': '170.00',
        'cumulative_quantity': '0.0',
        'average_price': null,
      }));

      instStore.add(Instrument.fromJson({
        'url': 'https://api.robinhood.com/instruments/inst-goog/',
        'id': 'inst-goog',
        'symbol': 'GOOG',
        'name': 'Alphabet Inc.',
        'simple_name': 'Alphabet',
        'type': 'stock',
        'state': 'active',
        'tradeable': true,
        'tradability': 'tradable',
        'quote': 'https://api.robinhood.com/quotes/GOOG/',
        'fundamentals': 'https://api.robinhood.com/fundamentals/GOOG/',
        'splits': 'https://api.robinhood.com/instruments/inst-goog/splits/',
        'market': 'https://api.robinhood.com/markets/XNAS/',
        'bloomberg_unique': 'EQ00000001',
        'country': 'US',
        'rhs_tradability': 'tradable',
        'fractional_tradability': 'tradable',
        'is_spac': false,
        'is_test': false,
        'ipo_access_supports_dsp': false,
      }));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: instStore),
            ChangeNotifierProvider.value(value: orderStore),
          ],
          child: MaterialApp(
            home: InvestorGroupActivityFeedWidget(
              groupId: testGroupId,
              group: testGroup,
              firestoreService: firestoreService,
              brokerageUser: testBrokerageUser,
              analytics: MockAnalytics(),
              observer: FakeAnalyticsObserver(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final shareBtn =
          find.widgetWithText(ElevatedButton, 'Share Recent Trades');
      expect(shareBtn, findsOneWidget);
      await tester.tap(shareBtn);
      await tester.pumpAndSettle();

      // Ensure symbol, company name, and pending badge are displayed
      expect(find.text('GOOG'), findsOneWidget);
      expect(find.text('Alphabet'), findsOneWidget);
      expect(find.text('CONFIRMED'), findsOneWidget);
      // Ensure quantity uses total quantity (5) and not cumulative quantity (0)
      expect(find.textContaining('5 share(s)'), findsOneWidget);
    });
  });
}
