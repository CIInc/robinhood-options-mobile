import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/banking.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';

void main() {
  group('AchTransfer Model Tests', () {
    test('parses completed deposit transfer correctly', () {
      final json = {
        'id': 'ach_101',
        'account': 'ACCT12345',
        'direction': 'deposit',
        'amount': '2500.00',
        'state': 'completed',
        'status_description': 'Deposit completed from Chase Checking',
        'scheduled': false,
        'expected_landing_date': '2026-09-10',
        'expected_landing_datetime': '2026-09-10T09:30:00Z',
        'created_at': '2026-09-08T14:00:00Z',
        'updated_at': '2026-09-10T09:30:00Z',
        'ach_relationship': 'ach_rel_01',
        'fees': '0.00',
        'ref_id': 'REF-DEP-101',
        'rhs_state': 'completed',
      };

      final transfer = AchTransfer.fromJson(json);
      expect(transfer.id, 'ach_101');
      expect(transfer.account, 'ACCT12345');
      expect(transfer.direction, 'deposit');
      expect(transfer.amount, 2500.0);
      expect(transfer.state, 'completed');
      expect(transfer.isDeposit, isTrue);
      expect(transfer.isWithdrawal, isFalse);
      expect(transfer.isCompleted, isTrue);
      expect(transfer.isPending, isFalse);
      expect(transfer.formattedAmount, '+\$2,500.00');
      expect(transfer.formattedAmountPlain, '\$2,500.00');
      expect(transfer.statusTitle, 'Completed');
      expect(transfer.refId, 'REF-DEP-101');
    });

    test('parses pending withdrawal transfer with cancel URL', () {
      final json = {
        'id': 'ach_102',
        'account_number': 'ACCT12345',
        'cancel': 'https://api.robinhood.com/ach/transfers/ach_102/cancel/',
        'direction': 'withdraw',
        'amount': 450.75,
        'state': 'pending',
        'status_description': 'Withdrawal initiated to Ally Savings',
        'expected_landing_date': '2026-09-15',
        'created_at': '2026-09-13T10:00:00Z',
        'ref_id': 'REF-WTH-102',
      };

      final transfer = AchTransfer.fromJson(json);
      expect(transfer.id, 'ach_102');
      expect(transfer.account, 'ACCT12345');
      expect(transfer.cancelUrl,
          'https://api.robinhood.com/ach/transfers/ach_102/cancel/');
      expect(transfer.direction, 'withdraw');
      expect(transfer.amount, 450.75);
      expect(transfer.isWithdrawal, isTrue);
      expect(transfer.isPending, isTrue);
      expect(transfer.isCompleted, isFalse);
      expect(transfer.formattedAmount, '-\$450.75');
      expect(transfer.statusTitle, 'Pending');
      expect(transfer.formattedLandingDate, contains('Sep 15'));
    });

    test('roundtrips to and from json', () {
      final original = AchTransfer(
        id: 'ach_103',
        account: 'ACCT9999',
        direction: 'deposit',
        amount: 1500.0,
        state: 'completed',
        statusDescription: 'Deposit from Bank',
        scheduled: true,
        expectedLandingDate: DateTime(2026, 9, 14),
        createdAt: DateTime(2026, 9, 12, 10, 0),
        fees: 0.0,
        refId: 'REF-103',
      );

      final json = original.toJson();
      final parsed = AchTransfer.fromJson(json);
      expect(parsed.id, original.id);
      expect(parsed.direction, original.direction);
      expect(parsed.amount, original.amount);
      expect(parsed.state, original.state);
      expect(parsed.scheduled, isTrue);
      expect(parsed.refId, original.refId);
    });

    test('handles empty and invalid json gracefully', () {
      final transfer = AchTransfer.fromJson(null);
      expect(transfer.id, '');
      expect(transfer.amount, 0.0);
      expect(transfer.direction, 'deposit');
      expect(transfer.state, 'completed');
    });
  });

  group('AchRelationship Model Tests', () {
    test('parses approved checking bank relationship', () {
      final json = {
        'id': 'rel_chase_01',
        'bank_account_nickname': 'Chase Premier Checking',
        'bank_account_type': 'checking',
        'bank_account_holder_name': 'John Trader',
        'bank_routing_number': '021000021',
        'bank_account_number': '****6742',
        'state': 'approved',
        'verified': true,
        'default': true,
        'created_at': '2025-05-15T12:00:00Z',
      };

      final rel = AchRelationship.fromJson(json);
      expect(rel.id, 'rel_chase_01');
      expect(rel.displayName, 'Chase Premier Checking');
      expect(rel.bankAccountType, 'checking');
      expect(rel.formattedAccountType, 'Checking');
      expect(rel.maskedAccountNumber, '****6742');
      expect(rel.isApproved, isTrue);
      expect(rel.isDefault, isTrue);
      expect(rel.statusTitle, 'Verified');
      expect(rel.bankAccountHolderName, 'John Trader');
      expect(rel.bankRoutingNumber, '021000021');
    });

    test('masks account number automatically if unmasked', () {
      final json = {
        'id': 'rel_ally_02',
        'bank_account_type': 'savings',
        'bank_account_number': '123456789',
        'state': 'pending',
        'verified': false,
      };

      final rel = AchRelationship.fromJson(json);
      expect(rel.displayName, 'Savings (****6789)');
      expect(rel.maskedAccountNumber, '****6789');
      expect(rel.isPending, isTrue);
      expect(rel.statusTitle, 'Pending');
    });

    test('roundtrips to and from json', () {
      final original = AchRelationship(
        id: 'rel_test_03',
        bankAccountNickname: 'Credit Union',
        bankAccountType: 'savings',
        bankAccountNumber: '****4400',
        state: 'approved',
        verified: true,
        isDefault: false,
      );

      final json = original.toJson();
      final parsed = AchRelationship.fromJson(json);
      expect(parsed.id, original.id);
      expect(parsed.displayName, 'Credit Union');
      expect(parsed.bankAccountType, 'savings');
      expect(parsed.maskedAccountNumber, '****4400');
      expect(parsed.isApproved, isTrue);
    });
  });

  group('AchSummary Aggregations Tests', () {
    test('computes totals, net flow, and pending amounts correctly', () {
      final transfers = [
        AchTransfer(
          id: 't1',
          direction: 'deposit',
          amount: 5000.0,
          state: 'completed',
          createdAt: DateTime(2026, 9, 1),
        ),
        AchTransfer(
          id: 't2',
          direction: 'withdraw',
          amount: 1200.0,
          state: 'completed',
          createdAt: DateTime(2026, 9, 5),
        ),
        AchTransfer(
          id: 't3',
          direction: 'deposit',
          amount: 1000.0,
          state: 'pending',
          expectedLandingDate: DateTime(2026, 9, 15),
          createdAt: DateTime(2026, 9, 13),
        ),
        AchTransfer(
          id: 't4',
          direction: 'withdraw',
          amount: 300.0,
          state: 'cancelled',
          createdAt: DateTime(2026, 9, 7),
        ),
      ];

      final relationships = [
        const AchRelationship(
          id: 'r1',
          bankAccountNickname: 'Chase Checking',
          state: 'approved',
          verified: true,
          isDefault: true,
        ),
        const AchRelationship(
          id: 'r2',
          bankAccountNickname: 'Ally Savings',
          state: 'approved',
          verified: true,
        ),
      ];

      final summary =
          AchSummary.fromTransfersAndRelationships(transfers, relationships);

      expect(summary.totalDeposited, 5000.0);
      expect(summary.totalWithdrawn, 1200.0);
      expect(summary.netCashFlow, 3800.0);
      expect(summary.formattedNetCashFlow, '\$3,800.00');
      expect(summary.completedTransfersCount, 2);
      expect(summary.pendingTransfersCount, 1);
      expect(summary.pendingDeposits, 1000.0);
      expect(summary.pendingWithdrawals, 0.0);
      expect(summary.linkedAccountsCount, 2);
      expect(summary.verifiedAccountsCount, 2);
      expect(summary.latestTransfer?.id, 't3');
      expect(summary.nextClearingTransfer?.id, 't3');
    });
  });

  group('DemoService Banking Integration Tests', () {
    final user = BrokerageUser(
      BrokerageSource.demo,
      'demo_trader',
      null,
      null,
    );

    test('returns demo ACH transfers with valid models', () async {
      final service = DemoService();
      final transfers = await service.getAchTransfersModel(user);

      expect(transfers, isNotEmpty);
      expect(transfers.length, greaterThanOrEqualTo(5));

      final pending = transfers.firstWhere((t) => t.isPending);
      expect(pending.direction, 'deposit');
      expect(pending.amount, 1000.0);
      expect(pending.cancelUrl, isNotNull);

      final completedDeposits =
          transfers.where((t) => t.isDeposit && t.isCompleted);
      expect(completedDeposits, isNotEmpty);
    });

    test('returns demo ACH relationships with verified Chase and Ally',
        () async {
      final service = DemoService();
      final relationships = await service.getAchRelationshipsModel(user);

      expect(relationships, isNotEmpty);
      expect(relationships.length, 3);

      final chase = relationships.firstWhere((r) => r.id == 'ach_rel_demo_01');
      expect(chase.displayName, contains('Chase'));
      expect(chase.isDefault, isTrue);
      expect(chase.isApproved, isTrue);
      expect(chase.maskedAccountNumber, '****6742');

      final pendingBank = relationships.firstWhere((r) => r.isPending);
      expect(pendingBank.isPending, isTrue);
      expect(pendingBank.verifyMicroDepositsUrl, isNotNull);
    });

    test('cancels pending ACH transfer in DemoService', () async {
      final service = DemoService();
      final transfersBefore = await service.getAchTransfersModel(user);
      final pending = transfersBefore.firstWhere((t) => t.isPending);

      final success = await service.cancelAchTransfer(user, pending.cancelUrl!);
      expect(success, isTrue);

      final transfersAfter = await service.getAchTransfersModel(user);
      final cancelled = transfersAfter.firstWhere((t) => t.id == pending.id);
      expect(cancelled.isCancelled, isTrue);
      expect(cancelled.statusDescription, contains('cancelled'));
    });
  });
}
