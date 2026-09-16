import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/spending_account.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';

void main() {
  group('SpendingAccount Model Tests', () {
    test('parses active spending account with card details', () {
      final json = {
        'id': 'sp_001',
        'account_number': 'RHSP-1234-5678',
        'routing_number': '021000021',
        'status': 'active',
        'balance': '3450.75',
        'available_balance': '3400.00',
        'unsettled_charges': '50.75',
        'interest_earned': '84.20',
        'apy': '0.0500',
        'card': {
          'status': 'active',
          'last_four': '1234',
          'type': 'physical',
        },
        'created_at': '2023-04-12T10:00:00Z',
      };

      final acct = SpendingAccount.fromJson(json);

      expect(acct.id, 'sp_001');
      expect(acct.accountNumber, 'RHSP-1234-5678');
      expect(acct.routingNumber, '021000021');
      expect(acct.balance, 3450.75);
      expect(acct.availableBalance, 3400.00);
      expect(acct.unsettledCharges, 50.75);
      expect(acct.interestEarned, 84.20);
      expect(acct.apy, 0.0500);
      expect(acct.cardStatus, 'active');
      expect(acct.cardLastFour, '1234');
      expect(acct.cardType, 'physical');
      expect(acct.isActive, isTrue);
      expect(acct.isCardLocked, isFalse);
      expect(acct.formattedBalance, '\$3,450.75');
      expect(acct.formattedAvailable, '\$3,400.00');
      expect(acct.formattedApy, '5.00%');
      expect(acct.formattedInterest, '\$84.20');
    });

    test('parses locked card status', () {
      final json = {
        'id': 'sp_002',
        'account_number': 'RHSP-9999',
        'card_status': 'locked',
        'card_last_four': '9999',
      };

      final acct = SpendingAccount.fromJson(json);
      expect(acct.isCardLocked, isTrue);
      expect(acct.cardLastFour, '9999');
    });

    test('roundtrips to and from json', () {
      const original = SpendingAccount(
        id: 'sp_roundtrip',
        accountNumber: 'RHSP-7777',
        routingNumber: '021000021',
        balance: 1000.0,
        availableBalance: 950.0,
        apy: 0.045,
        status: 'active',
        cardStatus: 'active',
        cardLastFour: '4321',
      );

      final json = original.toJson();
      final parsed = SpendingAccount.fromJson(json);

      expect(parsed.id, original.id);
      expect(parsed.accountNumber, original.accountNumber);
      expect(parsed.routingNumber, original.routingNumber);
      expect(parsed.balance, original.balance);
      expect(parsed.availableBalance, original.availableBalance);
      expect(parsed.apy, original.apy);
      expect(parsed.cardStatus, original.cardStatus);
    });

    test('handles null and invalid json gracefully', () {
      final acct = SpendingAccount.fromJson(null);
      expect(acct.id, '');
      expect(acct.accountNumber, '');
      expect(acct.balance, 0.0);
      expect(acct.isActive, isTrue); // default status is active
    });

    test('integrates with DemoService', () async {
      final service = DemoService();
      final user = BrokerageUser(
        BrokerageSource.demo,
        'demo_user',
        null,
        null,
      );

      final spending = await service.getSpendingAccountModel(user);
      expect(spending, isNotNull);
      expect(spending!.accountNumber, isNotEmpty);
      expect(spending.balance, greaterThan(0));
      expect(spending.apy, greaterThan(0));
      expect(spending.cardLastFour, '8834');
    });
  });
}
