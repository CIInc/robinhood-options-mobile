import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/portfolio_privacy_settings.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/model/user_follow.dart';

void main() {
  group('UserFollow Model Tests', () {
    test('UserFollow serialization and deserialization', () {
      final now = DateTime(2026, 9, 16, 12, 0);
      final follow = UserFollow(
        id: 'follow-id-123',
        followerId: 'user-alice',
        followerName: 'Alice Trader',
        followerPhotoUrl: 'https://example.com/alice.jpg',
        followingId: 'user-bob',
        followingName: 'Bob Trader',
        followingPhotoUrl: 'https://example.com/bob.jpg',
        createdAt: now,
        notificationsEnabled: true,
      );

      final json = follow.toJson();
      expect(json['id'], equals('follow-id-123'));
      expect(json['followerId'], equals('user-alice'));
      expect(json['followerName'], equals('Alice Trader'));
      expect(json['followerPhotoUrl'], equals('https://example.com/alice.jpg'));
      expect(json['followingId'], equals('user-bob'));
      expect(json['followingName'], equals('Bob Trader'));
      expect(json['followingPhotoUrl'], equals('https://example.com/bob.jpg'));
      expect(json['notificationsEnabled'], isTrue);

      final docData = {
        ...json,
        'createdAt': Timestamp.fromDate(now),
      };

      final deserialized = UserFollow.fromJson(docData, 'follow-id-123');
      expect(deserialized.id, equals('follow-id-123'));
      expect(deserialized.followerId, equals('user-alice'));
      expect(deserialized.followerName, equals('Alice Trader'));
      expect(deserialized.followerPhotoUrl, equals('https://example.com/alice.jpg'));
      expect(deserialized.followingId, equals('user-bob'));
      expect(deserialized.followingName, equals('Bob Trader'));
      expect(deserialized.followingPhotoUrl, equals('https://example.com/bob.jpg'));
      expect(deserialized.notificationsEnabled, isTrue);
      expect(deserialized.createdAt.year, equals(2026));
    });

    test('UserFollow copyWith', () {
      final follow = UserFollow(
        id: 'f1',
        followerId: 'alice',
        followerName: 'Alice',
        followingId: 'bob',
        followingName: 'Bob',
        createdAt: DateTime.now(),
        notificationsEnabled: false,
      );

      final updated = follow.copyWith(notificationsEnabled: true);
      expect(updated.notificationsEnabled, isTrue);
      expect(updated.followerId, equals('alice'));
      expect(updated.followingId, equals('bob'));
    });
  });

  group('PortfolioPrivacySettings Model Tests', () {
    test('PortfolioPrivacySettings default values', () {
      const settings = PortfolioPrivacySettings();
      expect(settings.isPublic, isTrue);
      expect(settings.showTradeAmounts, isFalse);
      expect(settings.showHoldings, isTrue);
      expect(settings.showTrades, isTrue);
      expect(settings.allowFollowers, isTrue);
    });

    test('PortfolioPrivacySettings serialization and deserialization', () {
      const settings = PortfolioPrivacySettings(
        isPublic: false,
        showTradeAmounts: true,
        showHoldings: false,
        showTrades: true,
        allowFollowers: false,
      );

      final json = settings.toJson();
      expect(json['isPublic'], isFalse);
      expect(json['showTradeAmounts'], isTrue);
      expect(json['showHoldings'], isFalse);
      expect(json['showTrades'], isTrue);
      expect(json['allowFollowers'], isFalse);

      final deserialized = PortfolioPrivacySettings.fromJson(json);
      expect(deserialized.isPublic, isFalse);
      expect(deserialized.showTradeAmounts, isTrue);
      expect(deserialized.showHoldings, isFalse);
      expect(deserialized.showTrades, isTrue);
      expect(deserialized.allowFollowers, isFalse);
    });

    test('PortfolioPrivacySettings copyWith', () {
      const settings = PortfolioPrivacySettings();
      final updated = settings.copyWith(
        isPublic: false,
        showTradeAmounts: true,
      );

      expect(updated.isPublic, isFalse);
      expect(updated.showTradeAmounts, isTrue);
      expect(updated.showHoldings, isTrue);
    });

    test('User with portfolioPrivacy serialization', () {
      final user = User(
        name: 'User1',
        nameLower: 'user1',
        role: UserRole.user,
        devices: [],
        dateCreated: DateTime.now(),
        brokerageUsers: [],
        portfolioPrivacy: const PortfolioPrivacySettings(
          isPublic: true,
          showHoldings: true,
          showTrades: true,
        ),
      );

      final json = user.toJson();
      expect(json['portfolioPrivacy'], isNotNull);
      expect((json['portfolioPrivacy'] as Map)['isPublic'], isTrue);

      final deserialized = User.fromJson(json);
      expect(deserialized.portfolioPrivacy?.isPublic, isTrue);
      expect(deserialized.portfolioPrivacy?.showHoldings, isTrue);
    });

    test('User with private portfolio privacy', () {
      final user = User(
        name: 'Private Trader',
        nameLower: 'private trader',
        role: UserRole.user,
        devices: [],
        dateCreated: DateTime.now(),
        brokerageUsers: [],
        portfolioPrivacy: const PortfolioPrivacySettings(
          isPublic: false,
          showHoldings: false,
          showTrades: false,
        ),
      );

      final json = user.toJson();
      expect((json['portfolioPrivacy'] as Map)['isPublic'], isFalse);

      final deserialized = User.fromJson(json);
      expect(deserialized.portfolioPrivacy?.isPublic, isFalse);
    });
  });
}
