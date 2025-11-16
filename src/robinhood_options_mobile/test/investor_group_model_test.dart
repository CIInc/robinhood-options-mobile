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
  });
}
