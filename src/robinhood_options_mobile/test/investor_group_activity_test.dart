import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/group_activity.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';

void main() {
  group('GroupActivity Model Tests', () {
    test('GroupActivity should serialize and deserialize correctly', () {
      final now = DateTime(2026, 9, 15, 10, 30);
      final activity = GroupActivity(
        id: 'act-123',
        groupId: 'grp-456',
        userId: 'usr-789',
        userName: 'Alice Trader',
        userPhotoUrl: 'https://example.com/alice.png',
        type: GroupActivityType.trade,
        title: 'Alice Trader bought AAPL',
        description: 'Bought 10 shares of Apple',
        timestamp: now,
        symbol: 'AAPL',
        side: 'buy',
        quantity: 10,
        price: 150.50,
        orderType: 'limit',
        assetType: 'equity',
        details: {'notes': 'Target reached'},
        isAnonymous: false,
        hideAmounts: false,
      );

      final json = activity.toJson();

      expect(json['id'], equals('act-123'));
      expect(json['groupId'], equals('grp-456'));
      expect(json['userId'], equals('usr-789'));
      expect(json['userName'], equals('Alice Trader'));
      expect(json['userPhotoUrl'], equals('https://example.com/alice.png'));
      expect(json['type'], equals('trade'));
      expect(json['title'], equals('Alice Trader bought AAPL'));
      expect(json['symbol'], equals('AAPL'));
      expect(json['side'], equals('buy'));
      expect(json['quantity'], equals(10));
      expect(json['price'], equals(150.50));
      expect(json['orderType'], equals('limit'));
      expect(json['assetType'], equals('equity'));
      expect(json['isAnonymous'], isFalse);
      expect(json['hideAmounts'], isFalse);

      final deserialized = GroupActivity.fromJson(json, 'act-123');
      expect(deserialized.id, equals('act-123'));
      expect(deserialized.groupId, equals('grp-456'));
      expect(deserialized.userId, equals('usr-789'));
      expect(deserialized.userName, equals('Alice Trader'));
      expect(deserialized.type, equals(GroupActivityType.trade));
      expect(deserialized.symbol, equals('AAPL'));
      expect(deserialized.side, equals('buy'));
      expect(deserialized.quantity, equals(10.0));
      expect(deserialized.price, equals(150.50));
      expect(deserialized.isTrade, isTrue);
      expect(deserialized.isBuy, isTrue);
      expect(deserialized.isSell, isFalse);
      expect(deserialized.totalAmount, equals(1505.0));
      expect(deserialized.formattedTotal, equals(r'$1,505.00'));
      expect(deserialized.formattedQuantity, equals('10'));
      expect(deserialized.displayUserName, equals('Alice Trader'));
    });

    test('GroupActivity correctly masks amounts when hideAmounts is true', () {
      final now = DateTime.now();
      final activity = GroupActivity(
        id: 'act-masked',
        groupId: 'grp-1',
        userId: 'usr-1',
        userName: 'Bob Investor',
        type: GroupActivityType.trade,
        title: 'Bob Investor bought NVDA',
        timestamp: now,
        symbol: 'NVDA',
        side: 'buy',
        quantity: 50,
        price: 120.0,
        hideAmounts: true,
      );

      expect(activity.hideAmounts, isTrue);
      expect(activity.formattedTotal, equals(r'$***'));
      expect(activity.formattedQuantity, equals('***'));
    });

    test('GroupActivity correctly handles anonymity when isAnonymous is true',
        () {
      final now = DateTime.now();
      final activity = GroupActivity(
        id: 'act-anon',
        groupId: 'grp-1',
        userId: 'usr-hidden',
        userName: 'Secret Whale',
        type: GroupActivityType.trade,
        title: 'A member bought TSLA',
        timestamp: now,
        symbol: 'TSLA',
        side: 'buy',
        isAnonymous: true,
      );

      expect(activity.isAnonymous, isTrue);
      expect(activity.displayUserName, equals('Anonymous Member'));
    });

    test('GroupActivity handles option multiplier calculation', () {
      final now = DateTime.now();
      final optionActivity = GroupActivity(
        id: 'act-option',
        groupId: 'grp-1',
        userId: 'usr-1',
        userName: 'Option King',
        type: GroupActivityType.trade,
        title: 'Option King bought SPY 500C',
        timestamp: now,
        symbol: 'SPY',
        side: 'buy',
        quantity: 2, // 2 contracts
        price: 3.50, // $3.50 premium
        assetType: 'option',
        details: {
          'strikePrice': 500.0,
          'expirationDate': '2026-10-16',
          'optionType': 'call',
        },
      );

      expect(optionActivity.totalAmount, equals(700.0)); // 2 * 3.50 * 100
      expect(optionActivity.formattedTotal, equals(r'$700.00'));
      expect(optionActivity.details!['strikePrice'], equals(500.0));
      expect(optionActivity.details!['optionType'], equals('call'));
    });

    test('GroupActivity correctly parses non-trade types', () {
      final now = DateTime.now();
      final joinActivity = GroupActivity(
        id: 'act-join',
        groupId: 'grp-1',
        userId: 'usr-new',
        userName: 'New Member',
        type: GroupActivityType.memberJoined,
        title: 'New Member joined the group',
        timestamp: now,
      );

      expect(joinActivity.isTrade, isFalse);
      expect(joinActivity.type, equals(GroupActivityType.memberJoined));
      expect(joinActivity.formattedTotal, isEmpty);
    });
  });

  group('GroupActivityPrivacySettings Tests', () {
    test('Default privacy settings are permissive for group collaboration', () {
      const settings = GroupActivityPrivacySettings();
      expect(settings.shareTrades, isTrue);
      expect(settings.showTradeAmounts, isTrue);
      expect(settings.anonymous, isFalse);
    });

    test('Privacy settings serialization and deserialization', () {
      const settings = GroupActivityPrivacySettings(
        shareTrades: false,
        showTradeAmounts: false,
        anonymous: true,
      );

      final json = settings.toJson();
      expect(json['shareTrades'], isFalse);
      expect(json['showTradeAmounts'], isFalse);
      expect(json['anonymous'], isTrue);

      final deserialized = GroupActivityPrivacySettings.fromJson(json);
      expect(deserialized.shareTrades, isFalse);
      expect(deserialized.showTradeAmounts, isFalse);
      expect(deserialized.anonymous, isTrue);
    });

    test('copyWith updates specific fields', () {
      const original = GroupActivityPrivacySettings();
      final updated =
          original.copyWith(anonymous: true, showTradeAmounts: false);

      expect(updated.shareTrades, isTrue);
      expect(updated.showTradeAmounts, isFalse);
      expect(updated.anonymous, isTrue);
    });
  });

  group('FirestoreService Group Activity Tests', () {
    late FakeFirebaseFirestore fakeDb;
    late FirestoreService firestoreService;
    const testGroupId = 'grp-activity-test';

    setUp(() async {
      fakeDb = FakeFirebaseFirestore();
      firestoreService = FirestoreService(firestore: fakeDb);

      // Seed group
      await fakeDb.collection('investor_groups').doc(testGroupId).set({
        'id': testGroupId,
        'name': 'Test Group',
        'createdBy': 'user-1',
        'members': ['user-1', 'user-2'],
        'dateCreated': Timestamp.now(),
        'isPrivate': true,
      });
    });

    test('recordGroupActivity and getGroupActivitiesStream work correctly',
        () async {
      final activity = GroupActivity(
        id: 'act-1',
        groupId: testGroupId,
        userId: 'user-1',
        userName: 'Trader 1',
        type: GroupActivityType.trade,
        title: 'Trader 1 bought AAPL',
        timestamp: DateTime.now(),
        symbol: 'AAPL',
        side: 'buy',
        quantity: 10,
        price: 150.0,
      );

      final docRef =
          await firestoreService.recordGroupActivity(testGroupId, activity);
      expect(docRef.id, isNotEmpty);

      final activities =
          await firestoreService.getGroupActivitiesStream(testGroupId).first;

      expect(activities.length, equals(1));
      expect(activities.first.title, equals('Trader 1 bought AAPL'));
      expect(activities.first.symbol, equals('AAPL'));
      expect(activities.first.quantity, equals(10.0));
    });

    test(
        'getUserGroupPrivacySettings and updateUserGroupPrivacySettings work correctly',
        () async {
      // Default should be permissive
      final initial = await firestoreService.getUserGroupPrivacySettings(
          testGroupId, 'user-privacy-test');
      expect(initial.shareTrades, isTrue);
      expect(initial.showTradeAmounts, isTrue);
      expect(initial.anonymous, isFalse);

      // Update settings
      const updated = GroupActivityPrivacySettings(
        shareTrades: false,
        showTradeAmounts: false,
        anonymous: true,
      );
      await firestoreService.updateUserGroupPrivacySettings(
          testGroupId, 'user-privacy-test', updated);

      final fetched = await firestoreService.getUserGroupPrivacySettings(
          testGroupId, 'user-privacy-test');
      expect(fetched.shareTrades, isFalse);
      expect(fetched.showTradeAmounts, isFalse);
      expect(fetched.anonymous, isTrue);
    });

    test('broadcastTradeActivity respects privacy settings', () async {
      // 1. Broadcast with default settings
      final ref1 = await firestoreService.broadcastTradeActivity(
        groupId: testGroupId,
        userId: 'user-1',
        userName: 'Alice',
        symbol: 'NVDA',
        side: 'buy',
        quantity: 20,
        price: 130.0,
      );
      expect(ref1, isNotNull);

      // 2. Broadcast with shareTrades = false
      await firestoreService.updateUserGroupPrivacySettings(
        testGroupId,
        'user-private',
        const GroupActivityPrivacySettings(shareTrades: false),
      );
      final ref2 = await firestoreService.broadcastTradeActivity(
        groupId: testGroupId,
        userId: 'user-private',
        userName: 'Private User',
        symbol: 'MSFT',
        side: 'buy',
        quantity: 5,
        price: 400.0,
      );
      expect(ref2, isNull);

      // 3. Broadcast with anonymous and hideAmounts
      await firestoreService.updateUserGroupPrivacySettings(
        testGroupId,
        'user-anon',
        const GroupActivityPrivacySettings(
          shareTrades: true,
          showTradeAmounts: false,
          anonymous: true,
        ),
      );
      final ref3 = await firestoreService.broadcastTradeActivity(
        groupId: testGroupId,
        userId: 'user-anon',
        userName: 'Secret',
        symbol: 'GOOGL',
        side: 'buy',
        quantity: 15,
        price: 170.0,
      );
      expect(ref3, isNotNull);

      final activities =
          await firestoreService.getGroupActivitiesStream(testGroupId).first;

      final anonActivity = activities.firstWhere((a) => a.symbol == 'GOOGL');
      expect(anonActivity.isAnonymous, isTrue);
      expect(anonActivity.hideAmounts, isTrue);
      expect(anonActivity.displayUserName, equals('Anonymous Member'));
      expect(anonActivity.formattedTotal, equals(r'$***'));
      expect(anonActivity.title, equals('A member bought GOOGL'));
      expect(anonActivity.title, isNot(contains('buyed')));

      final aliceActivity = activities.firstWhere((a) => a.symbol == 'NVDA');
      expect(aliceActivity.title, equals('Alice bought NVDA'));
      expect(aliceActivity.title, isNot(contains('buyed')));
    });
  });
}
