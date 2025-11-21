import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/investor_group.dart';

void main() {
  group('InvestorGroup Model Tests', () {
    test('InvestorGroup should serialize and deserialize correctly', () {
      // Create an investor group
      final now = DateTime.now();
      final group = InvestorGroup(
        id: 'test-group-id',
        name: 'Tech Investors',
        description: 'A group for tech stock enthusiasts',
        createdBy: 'user123',
        members: ['user123', 'user456', 'user789'],
        admins: ['user123', 'user456'],
        pendingInvitations: ['user999'],
        dateCreated: now,
        dateUpdated: now,
        isPrivate: true,
      );

      // Convert to JSON
      final json = group.toJson();

      // Verify JSON contains all fields
      expect(json['id'], equals('test-group-id'));
      expect(json['name'], equals('Tech Investors'));
      expect(json['description'], equals('A group for tech stock enthusiasts'));
      expect(json['createdBy'], equals('user123'));
      expect(json['members'], equals(['user123', 'user456', 'user789']));
      expect(json['admins'], equals(['user123', 'user456']));
      expect(json['pendingInvitations'], equals(['user999']));
      expect(json['dateCreated'], equals(now));
      expect(json['dateUpdated'], equals(now));
      expect(json['isPrivate'], equals(true));

      // Convert Timestamp for dates (as Firestore would)
      json['dateCreated'] = Timestamp.fromDate(now);
      json['dateUpdated'] = Timestamp.fromDate(now);

      // Deserialize from JSON
      final deserializedGroup = InvestorGroup.fromJson(json);

      // Verify all fields are correctly deserialized
      expect(deserializedGroup.id, equals('test-group-id'));
      expect(deserializedGroup.name, equals('Tech Investors'));
      expect(
          deserializedGroup.description, equals('A group for tech stock enthusiasts'));
      expect(deserializedGroup.createdBy, equals('user123'));
      expect(deserializedGroup.members, equals(['user123', 'user456', 'user789']));
      expect(deserializedGroup.admins, equals(['user123', 'user456']));
      expect(deserializedGroup.pendingInvitations, equals(['user999']));
      expect(deserializedGroup.isPrivate, equals(true));
    });

    test('InvestorGroup should handle null optional fields', () {
      final now = DateTime.now();
      final group = InvestorGroup(
        id: 'minimal-group',
        name: 'Minimal Group',
        createdBy: 'user123',
        members: ['user123'],
        dateCreated: now,
      );

      // Convert to JSON
      final json = group.toJson();

      // Verify optional fields are null
      expect(json['description'], isNull);
      expect(json['admins'], isNull);
      expect(json['dateUpdated'], isNull);

      // Verify default values
      expect(json['isPrivate'], equals(true));

      // Convert Timestamp for dateCreated
      json['dateCreated'] = Timestamp.fromDate(now);

      // Deserialize from JSON
      final deserializedGroup = InvestorGroup.fromJson(json);

      // Verify optional fields are null
      expect(deserializedGroup.description, isNull);
      expect(deserializedGroup.admins, isNull);
      expect(deserializedGroup.dateUpdated, isNull);
      expect(deserializedGroup.isPrivate, equals(true));
    });

    test('InvestorGroup.isMember should correctly identify members', () {
      final group = InvestorGroup(
        id: 'test-group',
        name: 'Test Group',
        createdBy: 'user123',
        members: ['user123', 'user456', 'user789'],
        dateCreated: DateTime.now(),
      );

      expect(group.isMember('user123'), isTrue);
      expect(group.isMember('user456'), isTrue);
      expect(group.isMember('user789'), isTrue);
      expect(group.isMember('user999'), isFalse);
    });

    test('InvestorGroup.isAdmin should correctly identify admins', () {
      final group = InvestorGroup(
        id: 'test-group',
        name: 'Test Group',
        createdBy: 'user123',
        members: ['user123', 'user456', 'user789'],
        admins: ['user456'],
        dateCreated: DateTime.now(),
      );

      // Creator should always be considered an admin
      expect(group.isAdmin('user123'), isTrue);
      // Explicit admin
      expect(group.isAdmin('user456'), isTrue);
      // Regular member
      expect(group.isAdmin('user789'), isFalse);
      // Non-member
      expect(group.isAdmin('user999'), isFalse);
    });

    test('InvestorGroup should handle empty members list', () {
      final now = DateTime.now();
      final json = {
        'id': 'empty-group',
        'name': 'Empty Group',
        'createdBy': 'user123',
        'dateCreated': Timestamp.fromDate(now),
        'isPrivate': false,
      };

      final group = InvestorGroup.fromJson(json);

      expect(group.members, isEmpty);
      expect(group.isMember('user123'), isFalse);
    });

    test('InvestorGroup should default isPrivate to true', () {
      final now = DateTime.now();
      final json = {
        'id': 'default-group',
        'name': 'Default Group',
        'createdBy': 'user123',
        'members': ['user123'],
        'dateCreated': Timestamp.fromDate(now),
      };

      final group = InvestorGroup.fromJson(json);

      expect(group.isPrivate, isTrue);
    });

    test('InvestorGroup should handle public groups', () {
      final group = InvestorGroup(
        id: 'public-group',
        name: 'Public Group',
        createdBy: 'user123',
        members: ['user123'],
        dateCreated: DateTime.now(),
        isPrivate: false,
      );

      expect(group.isPrivate, isFalse);

      final json = group.toJson();
      json['dateCreated'] = Timestamp.fromDate(group.dateCreated);
      final deserializedGroup = InvestorGroup.fromJson(json);

      expect(deserializedGroup.isPrivate, isFalse);
    });

    test('InvestorGroup.fromJsonArray should create a list of groups', () {
      final now = DateTime.now();
      final jsonArray = [
        {
          'id': 'group1',
          'name': 'Group 1',
          'createdBy': 'user123',
          'members': ['user123'],
          'dateCreated': Timestamp.fromDate(now),
          'isPrivate': true,
        },
        {
          'id': 'group2',
          'name': 'Group 2',
          'createdBy': 'user456',
          'members': ['user456'],
          'dateCreated': Timestamp.fromDate(now),
          'isPrivate': false,
        },
      ];

      final groups = InvestorGroup.fromJsonArray(jsonArray);

      expect(groups.length, equals(2));
      expect(groups[0].id, equals('group1'));
      expect(groups[0].name, equals('Group 1'));
      expect(groups[0].isPrivate, isTrue);
      expect(groups[1].id, equals('group2'));
      expect(groups[1].name, equals('Group 2'));
      expect(groups[1].isPrivate, isFalse);
    });

    test('InvestorGroup.hasPendingInvitation should correctly identify pending invitations', () {
      final group = InvestorGroup(
        id: 'test-group',
        name: 'Test Group',
        createdBy: 'user123',
        members: ['user123'],
        pendingInvitations: ['user456', 'user789'],
        dateCreated: DateTime.now(),
      );

      expect(group.hasPendingInvitation('user456'), isTrue);
      expect(group.hasPendingInvitation('user789'), isTrue);
      expect(group.hasPendingInvitation('user123'), isFalse);
      expect(group.hasPendingInvitation('user999'), isFalse);
    });

    test('InvestorGroup should handle null pendingInvitations', () {
      final group = InvestorGroup(
        id: 'test-group',
        name: 'Test Group',
        createdBy: 'user123',
        members: ['user123'],
        dateCreated: DateTime.now(),
      );

      expect(group.hasPendingInvitation('user456'), isFalse);
      expect(group.pendingInvitations, isNull);
    });
  });

  group('CopyTradeSettings Tests', () {
    test('CopyTradeSettings should serialize and deserialize correctly', () {
      final settings = CopyTradeSettings(
        enabled: true,
        targetUserId: 'user456',
        autoExecute: true,
        maxQuantity: 100,
        maxAmount: 5000,
        overridePrice: true,
      );

      final json = settings.toJson();
      expect(json['enabled'], equals(true));
      expect(json['targetUserId'], equals('user456'));
      expect(json['autoExecute'], equals(true));
      expect(json['maxQuantity'], equals(100));
      expect(json['maxAmount'], equals(5000));
      expect(json['overridePrice'], equals(true));

      final deserializedSettings = CopyTradeSettings.fromJson(json);
      expect(deserializedSettings.enabled, equals(true));
      expect(deserializedSettings.targetUserId, equals('user456'));
      expect(deserializedSettings.autoExecute, equals(true));
      expect(deserializedSettings.maxQuantity, equals(100));
      expect(deserializedSettings.maxAmount, equals(5000));
      expect(deserializedSettings.overridePrice, equals(true));
    });

    test('CopyTradeSettings should handle default values', () {
      final settings = CopyTradeSettings();

      expect(settings.enabled, equals(false));
      expect(settings.targetUserId, isNull);
      expect(settings.autoExecute, equals(false));
      expect(settings.maxQuantity, isNull);
      expect(settings.maxAmount, isNull);
      expect(settings.overridePrice, equals(false));
    });
  });

  group('InvestorGroup CopyTrade Methods Tests', () {
    test('InvestorGroup should handle copy trade settings', () {
      final group = InvestorGroup(
        id: 'test-group',
        name: 'Test Group',
        createdBy: 'user123',
        members: ['user123', 'user456'],
        dateCreated: DateTime.now(),
      );

      final settings = CopyTradeSettings(
        enabled: true,
        targetUserId: 'user456',
        autoExecute: false,
      );

      group.setCopyTradeSettings('user123', settings);
      expect(group.getCopyTradeSettings('user123'), isNotNull);
      expect(group.getCopyTradeSettings('user123')!.enabled, equals(true));
      expect(
          group.getCopyTradeSettings('user123')!.targetUserId, equals('user456'));
      expect(group.getCopyTradeSettings('user456'), isNull);
    });

    test('InvestorGroup should serialize and deserialize copy trade settings',
        () {
      final now = DateTime.now();
      final settings1 = CopyTradeSettings(
        enabled: true,
        targetUserId: 'user456',
        maxQuantity: 50,
      );
      final settings2 = CopyTradeSettings(
        enabled: true,
        targetUserId: 'user123',
        maxAmount: 1000,
      );

      final group = InvestorGroup(
        id: 'test-group',
        name: 'Test Group',
        createdBy: 'user123',
        members: ['user123', 'user456'],
        dateCreated: now,
        memberCopyTradeSettings: {
          'user123': settings1,
          'user456': settings2,
        },
      );

      final json = group.toJson();
      expect(json['memberCopyTradeSettings'], isNotNull);

      json['dateCreated'] = Timestamp.fromDate(now);
      final deserializedGroup = InvestorGroup.fromJson(json);

      expect(deserializedGroup.memberCopyTradeSettings, isNotNull);
      expect(deserializedGroup.getCopyTradeSettings('user123'), isNotNull);
      expect(deserializedGroup.getCopyTradeSettings('user123')!.enabled,
          equals(true));
      expect(
          deserializedGroup.getCopyTradeSettings('user123')!.targetUserId,
          equals('user456'));
      expect(deserializedGroup.getCopyTradeSettings('user123')!.maxQuantity,
          equals(50));

      expect(deserializedGroup.getCopyTradeSettings('user456'), isNotNull);
      expect(deserializedGroup.getCopyTradeSettings('user456')!.maxAmount,
          equals(1000));
    });
  });
}
