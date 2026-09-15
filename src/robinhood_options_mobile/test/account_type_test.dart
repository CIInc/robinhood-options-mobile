import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/unified_account.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';

void main() {
  group('Account Type & IRA Recognition Tests', () {
    test('parses individual brokerage account correctly', () {
      final json = {
        'account_number': '1AB23456',
        'type': 'margin',
        'brokerage_account_type': 'individual',
        'portfolio_cash': '17546.87',
      };

      final account = Account.fromJson(json);

      expect(account.accountNumber, '1AB23456');
      expect(account.type, 'margin');
      expect(account.brokerageAccountType, 'individual');
      expect(account.isRetirement, isFalse);
      expect(account.isRothIra, isFalse);
      expect(account.isTraditionalIra, isFalse);
      expect(account.displayType, 'Margin');
    });

    test('parses Roth IRA account correctly', () {
      final json = {
        'account_number': 'ROTH7890',
        'type': 'cash',
        'brokerage_account_type': 'ira_roth',
        'portfolio_cash': '7000.00',
      };

      final account = Account.fromJson(json);

      expect(account.accountNumber, 'ROTH7890');
      expect(account.brokerageAccountType, 'ira_roth');
      expect(account.isRetirement, isTrue);
      expect(account.isRothIra, isTrue);
      expect(account.isTraditionalIra, isFalse);
      expect(account.displayType, 'Roth IRA');
    });

    test('parses Traditional IRA account correctly', () {
      final json = {
        'account_number': 'TRAD5555',
        'type': 'cash',
        'brokerage_account_type': 'ira_traditional',
        'portfolio_cash': '6500.00',
      };

      final account = Account.fromJson(json);

      expect(account.accountNumber, 'TRAD5555');
      expect(account.brokerageAccountType, 'ira_traditional');
      expect(account.isRetirement, isTrue);
      expect(account.isTraditionalIra, isTrue);
      expect(account.isRothIra, isFalse);
      expect(account.displayType, 'Traditional IRA');
    });

    test('recognizes IRA from type field fallback', () {
      final json = {
        'account_number': 'IRA_FALLBACK',
        'type': 'ira_roth',
      };

      final account = Account.fromJson(json);
      expect(account.isRetirement, isTrue);
      expect(account.isRothIra, isTrue);
      expect(account.displayType, 'Roth IRA');
    });
  });

  group('UnifiedAccount IRA Margin Rules Tests', () {
    test('standard margin account returns isMarginAccount = true', () {
      const unified = UnifiedAccount(
        accountNumber: '1AB23456',
        accountType: 'margin',
        brokerageAccountType: 'individual',
      );

      expect(unified.isRetirement, isFalse);
      expect(unified.isMarginAccount, isTrue);
    });

    test('IRA account returns isMarginAccount = false even if type is margin', () {
      const unified = UnifiedAccount(
        accountNumber: 'ROTH7890',
        accountType: 'margin',
        brokerageAccountType: 'ira_roth',
        marginHealth: MarginHealth(borrowedAmount: 500.0),
      );

      expect(unified.isRetirement, isTrue);
      // IRS regulation: IRAs cannot have margin borrowing
      expect(unified.isMarginAccount, isFalse);
    });
  });

  group('AccountStore Multi-Account Categorization Tests', () {
    test('filters brokerage and retirement accounts separately', () {
      final store = AccountStore();

      final acct1 = Account(
        'url1',
        10000.0,
        'ACCT_BROKERAGE_1',
        'margin',
        10000.0,
        'level3',
        0.0,
        0.0,
        0.0,
        brokerageAccountType: 'individual',
      );

      final acct2 = Account(
        'url2',
        7000.0,
        'ACCT_ROTH_1',
        'cash',
        7000.0,
        'level2',
        0.0,
        0.0,
        0.0,
        brokerageAccountType: 'ira_roth',
      );

      final acct3 = Account(
        'url3',
        5000.0,
        'ACCT_TRAD_1',
        'cash',
        5000.0,
        'level2',
        0.0,
        0.0,
        0.0,
        brokerageAccountType: 'ira_traditional',
      );

      store.add(acct1);
      store.add(acct2);
      store.add(acct3);

      expect(store.items.length, 3);
      expect(store.brokerageAccounts.length, 1);
      expect(store.brokerageAccounts.first.accountNumber, 'ACCT_BROKERAGE_1');

      expect(store.retirementAccounts.length, 2);
      expect(store.retirementAccounts.map((a) => a.accountNumber),
          containsAll(['ACCT_ROTH_1', 'ACCT_TRAD_1']));
    });

    test('DemoService returns both individual and Roth IRA accounts', () async {
      final service = DemoService();
      final store = AccountStore();
      final user = BrokerageUser(
        BrokerageSource.demo,
        'demo_user',
        null,
        null,
      );

      final accounts = await service.getAccounts(user, store, null, null);

      expect(accounts.length, greaterThanOrEqualTo(2));
      expect(store.brokerageAccounts, isNotEmpty);
      expect(store.retirementAccounts, isNotEmpty);

      final roth = store.retirementAccounts.firstWhere((a) => a.isRothIra);
      expect(roth.accountNumber, 'ROTH7890');
      expect(roth.displayType, 'Roth IRA');
    });
  });
}
