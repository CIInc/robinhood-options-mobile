import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/top_portfolio_entry.dart';
import 'package:robinhood_options_mobile/model/verified_track_record.dart';

void main() {
  group('ReputationTier Tests', () {
    test('ReputationTier fromScore returns correct tier', () {
      expect(ReputationTier.fromScore(95), equals(ReputationTier.masterTrader));
      expect(ReputationTier.fromScore(90), equals(ReputationTier.masterTrader));
      expect(ReputationTier.fromScore(80), equals(ReputationTier.eliteTrader));
      expect(ReputationTier.fromScore(75), equals(ReputationTier.eliteTrader));
      expect(
          ReputationTier.fromScore(60), equals(ReputationTier.trustedTrader));
      expect(
          ReputationTier.fromScore(50), equals(ReputationTier.trustedTrader));
      expect(ReputationTier.fromScore(30), equals(ReputationTier.activeTrader));
      expect(ReputationTier.fromScore(25), equals(ReputationTier.activeTrader));
      expect(ReputationTier.fromScore(10), equals(ReputationTier.novice));
      expect(ReputationTier.fromScore(0), equals(ReputationTier.novice));
    });
  });

  group('UserReputation Tests', () {
    test(
        'UserReputation calculation with verified master trader and high metrics',
        () {
      final trackRecord = VerifiedTrackRecord(
        userId: 'trader-1',
        userName: 'Alpha Master',
        tier: VerifiedLeaderTier.masterTrader,
        verifiedReturnPercent: 120.0,
        verifiedWinRate: 75.0,
        totalTradesAudited: 150,
        verificationDate: DateTime(2026, 9, 1),
      );

      final reputation = UserReputation.calculate(
        trackRecord: trackRecord,
        followersCount: 120,
      );

      // verification (35) + winRate (round(75/100 * 25) = 19) + return (20) + activity (10) + community (10) = 94
      expect(reputation.verificationScore, equals(35));
      expect(reputation.winRateScore, equals(19));
      expect(reputation.returnScore, equals(20));
      expect(reputation.activityScore, equals(10));
      expect(reputation.communityScore, equals(10));
      expect(reputation.score, equals(94));
      expect(reputation.tier, equals(ReputationTier.masterTrader));
    });

    test('UserReputation calculation with unverified new trader', () {
      final reputation = UserReputation.calculate(
        returnPercent: 10.0,
        winRate: 50.0,
        totalTrades: 3,
        followersCount: 1,
      );

      // verification (0) + winRate (13) + return (round(10/100*20) = 2) + activity (1) + community (1) = 17
      expect(reputation.verificationScore, equals(0));
      expect(reputation.winRateScore, equals(13));
      expect(reputation.returnScore, equals(2));
      expect(reputation.activityScore, equals(1));
      expect(reputation.communityScore, equals(1));
      expect(reputation.score, equals(17));
      expect(reputation.tier, equals(ReputationTier.novice));
    });

    test('UserReputation json serialization and deserialization', () {
      const original = UserReputation(
        score: 82,
        tier: ReputationTier.eliteTrader,
        verificationScore: 28,
        winRateScore: 20,
        returnScore: 16,
        activityScore: 10,
        communityScore: 8,
      );

      final json = original.toJson();
      final reconstituted = UserReputation.fromJson(json);

      expect(reconstituted.score, equals(original.score));
      expect(reconstituted.tier, equals(original.tier));
      expect(
          reconstituted.verificationScore, equals(original.verificationScore));
      expect(reconstituted.winRateScore, equals(original.winRateScore));
      expect(reconstituted.returnScore, equals(original.returnScore));
      expect(reconstituted.activityScore, equals(original.activityScore));
      expect(reconstituted.communityScore, equals(original.communityScore));
    });
  });

  group('TopPortfolioEntry Tests', () {
    test('TopPortfolioEntry serialization and deserialization', () {
      final entry = TopPortfolioEntry(
        userId: 'trader-100',
        userName: 'Jane Doe',
        userPhotoUrl: 'https://example.com/jane.jpg',
        location: 'New York, NY',
        followersCount: 45,
        followingCount: 12,
        isPublic: true,
        returnPercent: 42.5,
        winRate: 64.0,
        totalTrades: 85,
        winningTrades: 54,
        losingTrades: 31,
        sharpeRatio: 1.85,
        maxDrawdownPercent: 9.2,
        profitFactor: 2.1,
        periodReturns: const {
          '1W': 2.3,
          '1M': 8.5,
          '3M': 21.0,
          '1Y': 42.5,
          'ALL': 42.5,
        },
        reputation: const UserReputation(
          score: 68,
          tier: ReputationTier.trustedTrader,
        ),
        rank: 1,
      );

      final json = entry.toJson();
      final fromJson = TopPortfolioEntry.fromJson(json, 'trader-100');

      expect(fromJson.userId, equals('trader-100'));
      expect(fromJson.userName, equals('Jane Doe'));
      expect(fromJson.userPhotoUrl, equals('https://example.com/jane.jpg'));
      expect(fromJson.location, equals('New York, NY'));
      expect(fromJson.followersCount, equals(45));
      expect(fromJson.followingCount, equals(12));
      expect(fromJson.isPublic, isTrue);
      expect(fromJson.returnPercent, equals(42.5));
      expect(fromJson.winRate, equals(64.0));
      expect(fromJson.totalTrades, equals(85));
      expect(fromJson.sharpeRatio, equals(1.85));
      expect(fromJson.maxDrawdownPercent, equals(9.2));
      expect(fromJson.profitFactor, equals(2.1));
      expect(fromJson.periodReturns['1M'], equals(8.5));
      expect(fromJson.reputation.score, equals(68));
      expect(fromJson.reputation.tier, equals(ReputationTier.trustedTrader));
      expect(fromJson.rank, equals(1));
    });

    test('returnForPeriod returns correct period return or fallback', () {
      const entry = TopPortfolioEntry(
        userId: 'u1',
        userName: 'Trader 1',
        returnPercent: 50.0,
        winRate: 60.0,
        periodReturns: {
          '1W': 3.0,
          '1M': 10.0,
        },
        reputation:
            UserReputation(score: 50, tier: ReputationTier.trustedTrader),
      );

      expect(entry.returnForPeriod(LeaderboardTimePeriod.oneWeek), equals(3.0));
      expect(
          entry.returnForPeriod(LeaderboardTimePeriod.oneMonth), equals(10.0));
      // 3M not explicitly present, falls back to returnPercent
      expect(entry.returnForPeriod(LeaderboardTimePeriod.threeMonths),
          equals(50.0));
      expect(
          entry.returnForPeriod(LeaderboardTimePeriod.allTime), equals(50.0));
    });

    test('LeaderboardTimePeriod and LeaderboardSortOption properties', () {
      expect(LeaderboardTimePeriod.oneWeek.label, equals('1W'));
      expect(LeaderboardTimePeriod.oneMonth.label, equals('1M'));
      expect(LeaderboardTimePeriod.threeMonths.label, equals('3M'));
      expect(LeaderboardTimePeriod.oneYear.label, equals('1Y'));
      expect(LeaderboardTimePeriod.allTime.label, equals('ALL'));

      expect(LeaderboardSortOption.totalReturn.label, equals('Highest Return'));
      expect(LeaderboardSortOption.sharpeRatio.label, equals('Sharpe Ratio'));
      expect(LeaderboardSortOption.winRate.label, equals('Win Rate'));
      expect(LeaderboardSortOption.reputationScore.label, equals('Reputation'));
      expect(
          LeaderboardSortOption.followersCount.label, equals('Most Followed'));
    });
  });
}
