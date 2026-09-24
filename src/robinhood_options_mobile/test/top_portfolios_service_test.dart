import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/portfolio_privacy_settings.dart';
import 'package:robinhood_options_mobile/model/top_portfolio_entry.dart';
import 'package:robinhood_options_mobile/model/verified_track_record.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';

void main() {
  group('FirestoreService Top Portfolios Leaderboard Tests', () {
    late FakeFirebaseFirestore fakeDb;
    late FirestoreService firestoreService;

    setUp(() async {
      fakeDb = FakeFirebaseFirestore();
      firestoreService = FirestoreService(firestore: fakeDb);

      // Seed Alice (public, verified master trader)
      await fakeDb
          .collection(firestoreService.userCollectionName)
          .doc('alice')
          .set({
        'id': 'alice',
        'name': 'Alice Trader',
        'followersCount': 60,
        'followingCount': 10,
        'portfolioPrivacy':
            const PortfolioPrivacySettings(isPublic: true).toJson(),
      });

      final aliceRecord = VerifiedTrackRecord(
        userId: 'alice',
        userName: 'Alice Trader',
        isVerified: true,
        tier: VerifiedLeaderTier.masterTrader,
        verifiedReturnPercent: 88.0,
        verifiedWinRate: 72.0,
        totalTradesAudited: 120,
        winningTrades: 86,
        losingTrades: 34,
        sharpeRatio: 2.4,
        maxDrawdownPercent: 7.2,
        profitFactor: 2.5,
        verificationDate: DateTime(2026, 9, 1),
        monthlyReturns: {
          '1W': 4.5,
          '1M': 15.0,
          '3M': 35.0,
          '1Y': 88.0,
        },
      );
      await fakeDb
          .collection(firestoreService.verifiedTrackRecordCollectionName)
          .doc('alice')
          .set(aliceRecord.toJson());

      // Seed Bob (public, verified top performer, higher Sharpe)
      await fakeDb
          .collection(firestoreService.userCollectionName)
          .doc('bob')
          .set({
        'id': 'bob',
        'name': 'Bob Investor',
        'followersCount': 25,
        'followingCount': 5,
        'portfolioPrivacy':
            const PortfolioPrivacySettings(isPublic: true).toJson(),
      });

      final bobRecord = VerifiedTrackRecord(
        userId: 'bob',
        userName: 'Bob Investor',
        isVerified: true,
        tier: VerifiedLeaderTier.topPerformer,
        verifiedReturnPercent: 52.0,
        verifiedWinRate: 64.0,
        totalTradesAudited: 80,
        winningTrades: 51,
        losingTrades: 29,
        sharpeRatio: 2.8, // higher than Alice
        maxDrawdownPercent: 5.5,
        profitFactor: 2.1,
        verificationDate: DateTime(2026, 9, 1),
        monthlyReturns: {
          '1W': 1.5,
          '1M': 6.0,
          '3M': 18.0,
          '1Y': 52.0,
        },
      );
      await fakeDb
          .collection(firestoreService.verifiedTrackRecordCollectionName)
          .doc('bob')
          .set(bobRecord.toJson());

      // Seed Charlie (private, verified, high return)
      await fakeDb
          .collection(firestoreService.userCollectionName)
          .doc('charlie')
          .set({
        'id': 'charlie',
        'name': 'Charlie Stealth',
        'followersCount': 5,
        'followingCount': 2,
        'portfolioPrivacy':
            const PortfolioPrivacySettings(isPublic: false).toJson(),
      });

      final charlieRecord = VerifiedTrackRecord(
        userId: 'charlie',
        userName: 'Charlie Stealth',
        isVerified: true,
        tier: VerifiedLeaderTier.masterTrader,
        verifiedReturnPercent: 140.0,
        verifiedWinRate: 80.0,
        totalTradesAudited: 95,
        verificationDate: DateTime(2026, 9, 1),
      );
      await fakeDb
          .collection(firestoreService.verifiedTrackRecordCollectionName)
          .doc('charlie')
          .set(charlieRecord.toJson());
    });

    test(
        'getTopPortfoliosStream excludes private users when onlyPublic is true',
        () async {
      final entries =
          await firestoreService.getTopPortfoliosStream(onlyPublic: true).first;

      final userIds = entries.map((e) => e.userId).toList();
      expect(userIds.contains('alice'), isTrue);
      expect(userIds.contains('bob'), isTrue);
      expect(userIds.contains('charlie'), isFalse); // Private user excluded
    });

    test(
        'getTopPortfoliosStream includes private users when onlyPublic is false',
        () async {
      final entries = await firestoreService
          .getTopPortfoliosStream(onlyPublic: false)
          .first;

      final userIds = entries.map((e) => e.userId).toList();
      expect(userIds.contains('charlie'), isTrue);
    });

    test(
        'getTopPortfoliosStream sorts by totalReturn descending and sets ranks',
        () async {
      final entries = await firestoreService
          .getTopPortfoliosStream(
            sortBy: LeaderboardSortOption.totalReturn,
            onlyPublic: true,
          )
          .first;

      expect(entries.length, equals(2));
      expect(entries[0].userId, equals('alice')); // 88% > 52%
      expect(entries[0].rank, equals(1));
      expect(entries[1].userId, equals('bob'));
      expect(entries[1].rank, equals(2));
    });

    test('getTopPortfoliosStream sorts by sharpeRatio descending', () async {
      final entries = await firestoreService
          .getTopPortfoliosStream(
            sortBy: LeaderboardSortOption.sharpeRatio,
            onlyPublic: true,
          )
          .first;

      expect(entries.length, equals(2));
      expect(entries[0].userId, equals('bob')); // Sharpe 2.8 > 2.4
      expect(entries[0].rank, equals(1));
      expect(entries[1].userId, equals('alice'));
      expect(entries[1].rank, equals(2));
    });

    test('getTopPortfoliosStream sorts by followersCount descending', () async {
      final entries = await firestoreService
          .getTopPortfoliosStream(
            sortBy: LeaderboardSortOption.followersCount,
            onlyPublic: true,
          )
          .first;

      expect(entries.length, equals(2));
      expect(entries[0].userId, equals('alice')); // 60 > 25
      expect(entries[1].userId, equals('bob'));
    });

    test('getTopPortfoliosStream respects period filtering', () async {
      final entries = await firestoreService
          .getTopPortfoliosStream(
            period: LeaderboardTimePeriod.oneMonth,
            sortBy: LeaderboardSortOption.totalReturn,
            onlyPublic: true,
          )
          .first;

      expect(entries.length, equals(2));
      // Alice 1M = 15.0, Bob 1M = 6.0
      expect(entries[0].returnForPeriod(LeaderboardTimePeriod.oneMonth),
          equals(15.0));
      expect(entries[1].returnForPeriod(LeaderboardTimePeriod.oneMonth),
          equals(6.0));
    });

    test(
        'setTopPortfolioEntry, getTopPortfolioEntry, and deleteTopPortfolioEntry work correctly',
        () async {
      const entry = TopPortfolioEntry(
        userId: 'test_trader',
        userName: 'Test Trader',
        returnPercent: 45.0,
        winRate: 70.0,
        reputation:
            UserReputation(score: 65, tier: ReputationTier.masterTrader),
      );

      // Set entry
      await firestoreService.setTopPortfolioEntry(entry);

      // Fetch entry
      final fetched =
          await firestoreService.getTopPortfolioEntry('test_trader');
      expect(fetched, isNotNull);
      expect(fetched!.userId, equals('test_trader'));
      expect(fetched.userName, equals('Test Trader'));
      expect(fetched.returnPercent, equals(45.0));

      // Delete entry
      await firestoreService.deleteTopPortfolioEntry('test_trader');

      // Verify deletion
      final deleted =
          await firestoreService.getTopPortfolioEntry('test_trader');
      expect(deleted, isNull);
    });
  });
}
