import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/investment_profile.dart';
import 'package:robinhood_options_mobile/model/user.dart';

void main() {
  group('User Model Investment Profile Tests', () {
    test(
        'User model should serialize and deserialize investment profile fields',
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
        investmentProfile: InvestmentProfile(
          investmentGoals: 'Retirement planning and wealth building',
          timeHorizon: 'Long-term (5-10 years)',
          riskTolerance: 'Moderate',
          totalPortfolioValue: 100000.00,
        ),
      );

      // Convert to JSON
      final json = user.toJson();

      // Verify JSON contains investment profile nested object
      expect(json['investmentProfile'], isNotNull);
      final investmentProfile =
          json['investmentProfile'] as Map<String, Object?>;
      expect(investmentProfile['investmentGoals'],
          equals('Retirement planning and wealth building'));
      expect(
          investmentProfile['timeHorizon'], equals('Long-term (5-10 years)'));
      expect(investmentProfile['riskTolerance'], equals('Moderate'));
      expect(investmentProfile['totalPortfolioValue'], equals(100000.00));

      // Convert Timestamp for dateCreated (as Firestore would)
      json['dateCreated'] = Timestamp.fromDate(now);

      // Deserialize from JSON
      final deserializedUser = User.fromJson(json);

      // Verify investment profile fields are correctly deserialized
      expect(deserializedUser.investmentProfile, isNotNull);
      expect(deserializedUser.investmentProfile!.investmentGoals,
          equals('Retirement planning and wealth building'));
      expect(deserializedUser.investmentProfile!.timeHorizon,
          equals('Long-term (5-10 years)'));
      expect(deserializedUser.investmentProfile!.riskTolerance,
          equals('Moderate'));
      expect(deserializedUser.investmentProfile!.totalPortfolioValue,
          equals(100000.00));
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
      );

      // Convert to JSON
      final json = user.toJson();

      // Verify JSON contains null investment profile
      expect(json['investmentProfile'], isNull);

      // Convert Timestamp for dateCreated
      json['dateCreated'] = Timestamp.fromDate(now);

      // Deserialize from JSON
      final deserializedUser = User.fromJson(json);

      // Verify investment profile is null after deserialization
      expect(deserializedUser.investmentProfile, isNull);
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
        'refreshQuotes': true,
      };

      // Deserialize from JSON
      final user = User.fromJson(json);

      // Verify investment profile is null (for backward compatibility)
      expect(user.investmentProfile, isNull);
    });
  });
}
