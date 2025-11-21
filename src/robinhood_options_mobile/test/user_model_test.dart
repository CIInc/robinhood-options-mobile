import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/user.dart';

void main() {
  group('User Model Investment Profile Tests', () {
    test('User model should serialize and deserialize investment profile fields',
        () {
      // Create a user with investment profile data
      final now = DateTime.now();
      final user = User(
        name: 'Test User',
        nameLower: 'test user',
        email: 'test@example.com',
        role: UserRole.user,
        devices: [],
        dateCreated: now,
        brokerageUsers: [],
        accounts: [],
        investmentGoals: 'Retirement planning and wealth building',
        timeHorizon: 'Long-term (5-10 years)',
        riskTolerance: 'Moderate',
        totalPortfolioValue: 100000.00,
      );

      // Convert to JSON
      final json = user.toJson();

      // Verify JSON contains investment profile fields
      expect(json['investmentGoals'], equals('Retirement planning and wealth building'));
      expect(json['timeHorizon'], equals('Long-term (5-10 years)'));
      expect(json['riskTolerance'], equals('Moderate'));
      expect(json['totalPortfolioValue'], equals(100000.00));

      // Convert Timestamp for dateCreated (as Firestore would)
      json['dateCreated'] = Timestamp.fromDate(now);

      // Deserialize from JSON
      final deserializedUser = User.fromJson(json);

      // Verify investment profile fields are correctly deserialized
      expect(deserializedUser.investmentGoals, equals('Retirement planning and wealth building'));
      expect(deserializedUser.timeHorizon, equals('Long-term (5-10 years)'));
      expect(deserializedUser.riskTolerance, equals('Moderate'));
      expect(deserializedUser.totalPortfolioValue, equals(100000.00));
    });

    test('User model should handle null investment profile fields', () {
      // Create a user without investment profile data
      final now = DateTime.now();
      final user = User(
        name: 'Test User',
        nameLower: 'test user',
        email: 'test@example.com',
        role: UserRole.user,
        devices: [],
        dateCreated: now,
        brokerageUsers: [],
        accounts: [],
      );

      // Convert to JSON
      final json = user.toJson();

      // Verify JSON contains null investment profile fields
      expect(json['investmentGoals'], isNull);
      expect(json['timeHorizon'], isNull);
      expect(json['riskTolerance'], isNull);
      expect(json['totalPortfolioValue'], isNull);

      // Convert Timestamp for dateCreated
      json['dateCreated'] = Timestamp.fromDate(now);

      // Deserialize from JSON
      final deserializedUser = User.fromJson(json);

      // Verify investment profile fields are null after deserialization
      expect(deserializedUser.investmentGoals, isNull);
      expect(deserializedUser.timeHorizon, isNull);
      expect(deserializedUser.riskTolerance, isNull);
      expect(deserializedUser.totalPortfolioValue, isNull);
    });

    test('User model should handle missing investment profile fields in JSON',
        () {
      final now = DateTime.now();
      
      // Create a JSON object without investment profile fields (simulating old data)
      final json = {
        'name': 'Test User',
        'nameLower': 'test user',
        'email': 'test@example.com',
        'role': 'user',
        'devices': [],
        'dateCreated': Timestamp.fromDate(now),
        'brokerageUsers': [],
        'accounts': [],
        'persistToFirebase': true,
        'refreshQuotes': false,
      };

      // Deserialize from JSON
      final user = User.fromJson(json);

      // Verify investment profile fields default to null
      expect(user.investmentGoals, isNull);
      expect(user.timeHorizon, isNull);
      expect(user.riskTolerance, isNull);
      expect(user.totalPortfolioValue, isNull);
    });
  });
}
