import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/group_activity.dart';
import 'package:robinhood_options_mobile/model/verified_track_record.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';

void main() {
  group('VerifiedTrackRecord Model Tests', () {
    test('VerifiedTrackRecord serializes and deserializes correctly', () {
      final now = DateTime(2026, 9, 16, 10, 0);
      final record = VerifiedTrackRecord(
        userId: 'leader-123',
        userName: 'Alpha Trader',
        userPhotoUrl: 'https://example.com/alpha.png',
        groupId: 'grp-1',
        isVerified: true,
        tier: VerifiedLeaderTier.topPerformer,
        verifiedReturnPercent: 45.2,
        verifiedWinRate: 68.5,
        totalTradesAudited: 84,
        winningTrades: 58,
        losingTrades: 26,
        sharpeRatio: 2.15,
        maxDrawdownPercent: 7.2,
        profitFactor: 2.4,
        verificationDate: now,
        verificationSource: 'Robinhood Execution Ledger',
        monthlyReturns: {'1M': 5.2, '1Y': 45.2},
      );

      final json = record.toJson();
      expect(json['userId'], equals('leader-123'));
      expect(json['userName'], equals('Alpha Trader'));
      expect(json['isVerified'], isTrue);
      expect(json['tier'], equals('topPerformer'));
      expect(json['verifiedReturnPercent'], equals(45.2));
      expect(json['verifiedWinRate'], equals(68.5));
      expect(json['totalTradesAudited'], equals(84));
      expect(json['sharpeRatio'], equals(2.15));

      final fromJson = VerifiedTrackRecord.fromJson(json, 'leader-123');
      expect(fromJson.userId, equals('leader-123'));
      expect(fromJson.userName, equals('Alpha Trader'));
      expect(fromJson.tier, equals(VerifiedLeaderTier.topPerformer));
      expect(fromJson.verifiedReturnPercent, equals(45.2));
      expect(fromJson.verifiedWinRate, equals(68.5));
      expect(fromJson.monthlyReturns['1M'], equals(5.2));
    });

    test('VerifiedLeaderTier classification from metrics', () {
      final master = VerifiedLeaderTier.fromMetrics(
        returnPercent: 65.0,
        winRate: 70.0,
        totalTrades: 60,
      );
      expect(master, equals(VerifiedLeaderTier.masterTrader));

      final top = VerifiedLeaderTier.fromMetrics(
        returnPercent: 30.0,
        winRate: 58.0,
        totalTrades: 30,
      );
      expect(top, equals(VerifiedLeaderTier.topPerformer));

      final leader = VerifiedLeaderTier.fromMetrics(
        returnPercent: 12.0,
        winRate: 50.0,
        totalTrades: 15,
      );
      expect(leader, equals(VerifiedLeaderTier.verifiedLeader));

      final beginner = VerifiedLeaderTier.fromMetrics(
        returnPercent: -5.0,
        winRate: 40.0,
        totalTrades: 5,
      );
      expect(beginner, equals(VerifiedLeaderTier.verifiedTrader));
    });
  });

  group('FirestoreService Verified Track Record Tests', () {
    late FakeFirebaseFirestore fakeDb;
    late FirestoreService service;

    setUp(() {
      fakeDb = FakeFirebaseFirestore();
      service = FirestoreService(firestore: fakeDb);
    });

    test(
        'setVerifiedTrackRecord, getVerifiedTrackRecord, and streamVerifiedTrackRecord',
        () async {
      final record = VerifiedTrackRecord(
        userId: 'trader-abc',
        userName: 'Market Wizard',
        isVerified: true,
        tier: VerifiedLeaderTier.verifiedLeader,
        verifiedReturnPercent: 28.4,
        verifiedWinRate: 62.0,
        totalTradesAudited: 35,
        verificationDate: DateTime.now(),
      );

      await service.setVerifiedTrackRecord(record);

      final fetched = await service.getVerifiedTrackRecord('trader-abc');
      expect(fetched, isNotNull);
      expect(fetched!.userName, equals('Market Wizard'));
      expect(fetched.verifiedReturnPercent, equals(28.4));
      expect(fetched.tier, equals(VerifiedLeaderTier.verifiedLeader));

      final streamed =
          await service.streamVerifiedTrackRecord('trader-abc').first;
      expect(streamed, isNotNull);
      expect(streamed!.userId, equals('trader-abc'));
    });

    test(
        'calculateAndVerifyLeaderTrackRecord evaluates group activities and saves record',
        () async {
      const groupId = 'group-audit-test';
      const leaderId = 'leader-audit-user';

      // Seed trade activities for the leader
      final buyActivity = GroupActivity(
        id: 'act-buy',
        groupId: groupId,
        userId: leaderId,
        userName: 'Leader Alice',
        type: GroupActivityType.trade,
        title: 'Bought SPY',
        timestamp: DateTime.now().subtract(const Duration(days: 5)),
        symbol: 'SPY',
        side: 'buy',
        quantity: 10,
        price: 500.0,
      );

      final sellActivity = GroupActivity(
        id: 'act-sell',
        groupId: groupId,
        userId: leaderId,
        userName: 'Leader Alice',
        type: GroupActivityType.trade,
        title: 'Sold SPY',
        timestamp: DateTime.now(),
        symbol: 'SPY',
        side: 'sell',
        quantity: 10,
        price: 550.0,
      );

      await service.recordGroupActivity(groupId, buyActivity);
      await service.recordGroupActivity(groupId, sellActivity);

      final verified = await service.calculateAndVerifyLeaderTrackRecord(
        leaderId,
        groupId: groupId,
        userName: 'Leader Alice',
      );

      expect(verified.isVerified, isTrue);
      expect(verified.userId, equals(leaderId));
      expect(verified.totalTradesAudited, equals(2));
      expect(verified.winningTrades, equals(1));
      expect(verified.verifiedWinRate, equals(50.0));
      expect(verified.verificationSource, contains('Robinhood Brokerage'));

      // Check persisted record in Firestore
      final persisted = await service.getVerifiedTrackRecord(leaderId);
      expect(persisted, isNotNull);
      expect(persisted!.userName, equals('Leader Alice'));
    });
  });
}
