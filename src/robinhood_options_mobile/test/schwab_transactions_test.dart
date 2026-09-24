import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/dividend_store.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/interest_store.dart';
import 'package:robinhood_options_mobile/model/schwab_transaction.dart';
import 'package:robinhood_options_mobile/model/schwab_user_preference.dart';
import 'package:robinhood_options_mobile/services/schwab_service.dart';
import 'package:robinhood_options_mobile/widgets/schwab_transactions_widget.dart';

void main() {
  group('SchwabTransaction Model Tests', () {
    test('SchwabTransaction.fromJson parses option trade with multiple fees',
        () {
      final json = {
        'activityId': 80990733204,
        'time': '2026-05-07T13:30:01+0000',
        'accountNumber': '12345678',
        'type': 'TRADE',
        'status': 'VALID',
        'subAccount': 'MARGIN',
        'tradeDate': '2026-05-07T13:30:01+0000',
        'settlementDate': '2026-05-08T13:30:01+0000',
        'positionId': 2472242249,
        'orderId': 1000454139831,
        'netAmount': -248.66,
        'description': 'Buy CVS Call',
        'transferItems': [
          {
            'instrument': {
              'assetType': 'CURRENCY',
              'status': 'ACTIVE',
              'symbol': 'CURRENCY_USD',
              'description': 'USD currency',
              'instrumentId': 1,
              'closingPrice': 0,
            },
            'amount': 0.65,
            'cost': -0.65,
            'feeType': 'COMMISSION',
          },
          {
            'instrument': {
              'assetType': 'CURRENCY',
              'status': 'ACTIVE',
              'symbol': 'CURRENCY_USD',
              'instrumentId': 1,
            },
            'amount': 0.01,
            'cost': -0.01,
            'feeType': 'OPT_REG_FEE',
          },
          {
            'instrument': {
              'assetType': 'OPTION',
              'status': 'ACTIVE',
              'symbol': 'CVS   260816C00057500',
              'description': 'Cvs Health Corp 08/16/2026 \$57.5 Call',
              'instrumentId': 217999238,
              'closingPrice': 0.85,
              'expirationDate': '2026-08-16T04:00:00+0000',
              'putCall': 'CALL',
              'strikePrice': 57.5,
              'type': 'VANILLA',
              'underlyingSymbol': 'CVS',
              'underlyingCusip': '126650100',
            },
            'amount': 1,
            'cost': -248,
            'price': 2.48,
            'positionEffect': 'OPENING',
          },
        ],
      };

      final tx = SchwabTransaction.fromJson(json);

      expect(tx.activityId, 80990733204);
      expect(tx.id, '80990733204');
      expect(tx.accountNumber, '12345678');
      expect(tx.type, 'TRADE');
      expect(tx.isTrade, isTrue);
      expect(tx.isDividendOrInterest, isFalse);
      expect(tx.isCashMovement, isFalse);
      expect(tx.isFee, isTrue);
      expect(tx.subAccount, 'MARGIN');
      expect(tx.netAmount, -248.66);
      expect(tx.positionId, 2472242249);
      expect(tx.orderId, 1000454139831);
      expect(tx.tradeDate, DateTime.parse('2026-05-07T13:30:01+0000'));
      expect(tx.settlementDate, DateTime.parse('2026-05-08T13:30:01+0000'));

      expect(tx.primarySymbol, 'CVS   260816C00057500');
      expect(tx.underlyingSymbol, 'CVS');
      expect(tx.primaryQuantity, 1.0);
      expect(tx.primaryPrice, 2.48);
      expect(tx.positionEffect, 'OPENING');

      expect(tx.commission, 0.65);
      expect(tx.regulatoryFees, 0.01);
      expect(tx.totalFees, 0.66);
      expect(tx.transferItems.length, 3);
    });

    test('SchwabTransaction.fromJson parses closing trade and calculates fees',
        () {
      final json = {
        'activityId': 80963406939,
        'time': '2026-05-03T18:57:19+0000',
        'accountNumber': '21453928',
        'type': 'TRADE',
        'status': 'VALID',
        'subAccount': 'MARGIN',
        'netAmount': 649.33,
        'transferItems': [
          {
            'instrument': {
              'assetType': 'CURRENCY',
              'symbol': 'CURRENCY_USD',
            },
            'amount': 0.65,
            'cost': -0.65,
            'feeType': 'COMMISSION',
          },
          {
            'instrument': {
              'assetType': 'CURRENCY',
              'symbol': 'CURRENCY_USD',
            },
            'amount': 0.02,
            'cost': -0.02,
            'feeType': 'SEC_FEE',
          },
          {
            'instrument': {
              'assetType': 'OPTION',
              'symbol': 'AAPL  260517C00180000',
              'underlyingSymbol': 'AAPL',
            },
            'amount': -1,
            'cost': 650,
            'price': 6.5,
            'positionEffect': 'CLOSING',
          },
        ],
      };

      final tx = SchwabTransaction.fromJson(json);

      expect(tx.isTrade, isTrue);
      expect(tx.positionEffect, 'CLOSING');
      expect(tx.commission, 0.65);
      expect(tx.regulatoryFees, 0.02);
      expect(tx.totalFees, 0.67);
      expect(tx.estimatedRealizedPnL, closeTo(649.33 - 0.67, 0.001));
    });

    test('SchwabTransaction converts dividend transaction to DividendStore map',
        () {
      final json = {
        'activityId': 700100200,
        'time': '2026-06-15T12:00:00+0000',
        'accountNumber': '88887777',
        'type': 'DIVIDEND_OR_INTEREST',
        'status': 'VALID',
        'subAccount': 'CASH',
        'tradeDate': '2026-06-10T00:00:00+0000',
        'settlementDate': '2026-06-15T00:00:00+0000',
        'netAmount': 54.25,
        'description': 'QUALIFIED DIVIDEND AAPL',
        'transferItems': [
          {
            'instrument': {
              'assetType': 'EQUITY',
              'status': 'ACTIVE',
              'symbol': 'AAPL',
              'description': 'Apple Inc',
            },
            'amount': 100,
            'cost': 54.25,
            'price': 0.5425,
          },
        ],
      };

      final tx = SchwabTransaction.fromJson(json);

      expect(tx.isDividendOrInterest, isTrue);
      expect(tx.isDividend, isTrue);
      expect(tx.isInterest, isFalse);

      final instrumentObj = Instrument.fromSchwabJson({
        'symbol': 'AAPL',
        'description': 'Apple Inc',
        'assetType': 'stock',
      });

      final dividendMap = tx.toDividendMap(instrumentObj: instrumentObj);

      expect(dividendMap['id'], '700100200');
      expect(dividendMap['symbol'], 'AAPL');
      expect(dividendMap['amount'], '54.25');
      expect(dividendMap['rate'], '0.5425');
      expect(dividendMap['state'], 'paid');
      expect(dividendMap['position'], '100.00');
      expect(dividendMap['accountNumber'], '88887777');
      expect(dividendMap['instrumentObj'], equals(instrumentObj));
    });

    test('SchwabTransaction converts interest payment to InterestStore map',
        () {
      final json = {
        'activityId': 700200300,
        'time': '2026-06-30T16:00:00+0000',
        'accountNumber': '88887777',
        'type': 'DIVIDEND_OR_INTEREST',
        'status': 'VALID',
        'subAccount': 'CASH',
        'settlementDate': '2026-06-30T00:00:00+0000',
        'netAmount': 18.75,
        'description': 'CREDIT INTEREST PAID',
        'transferItems': [],
      };

      final tx = SchwabTransaction.fromJson(json);

      expect(tx.isDividendOrInterest, isTrue);
      expect(tx.isInterest, isTrue);
      expect(tx.isDividend, isFalse);

      final interestMap = tx.toInterestMap();

      expect(interestMap['id'], '700200300');
      expect(interestMap['state'], 'paid');
      expect(interestMap['reason'], 'CREDIT INTEREST PAID');
      expect(interestMap['amount']['amount'], '18.75');
      expect(interestMap['amount']['currency_code'], 'USD');
    });

    test('SchwabTransaction handles cash movement transfers', () {
      final json = {
        'activityId': 600100100,
        'time': '2026-06-01T08:30:00+0000',
        'accountNumber': '12345678',
        'type': 'ACH_RECEIPT',
        'status': 'VALID',
        'subAccount': 'CASH',
        'netAmount': 5000.0,
        'description': 'ELECTRONIC DEPOSIT',
        'transferItems': [],
      };

      final tx = SchwabTransaction.fromJson(json);

      expect(tx.isCashMovement, isTrue);
      expect(tx.isTrade, isFalse);
      expect(tx.netAmount, 5000.0);
    });
  });

  group('SchwabUserPreference Model Tests', () {
    test('SchwabUserPreference.fromJson parses accounts, streamer, and offers',
        () {
      final json = {
        'accounts': [
          {
            'accountNumber': 'ACC111',
            'primaryAccount': false,
            'type': 'MARGIN',
            'nickName': 'Active Trading',
            'displayAcctId': '...111',
            'autoPositionEffect': true,
            'accountColor': 'BLUE',
          },
          {
            'accountNumber': 'ACC222',
            'primaryAccount': true,
            'type': 'BROKERAGE',
            'nickName': 'Main Savings',
            'displayAcctId': '...222',
            'autoPositionEffect': false,
            'accountColor': 'GREEN',
          },
        ],
        'streamerInfo': [
          {
            'streamerSocketUrl': 'wss://streamer-api.schwab.com/ws',
            'schwabClientCustomerId': 'CUST123',
            'schwabClientCorrelId': 'CORR456',
            'schwabClientChannel': 'CH789',
            'schwabClientFunctionId': 'FN012',
          },
        ],
        'offers': [
          {
            'level2Permissions': true,
            'mktDataPermission': 'REAL_TIME',
          },
        ],
      };

      final prefs = SchwabUserPreference.fromJson(json);

      expect(prefs.accounts.length, 2);
      expect(prefs.streamerInfo.length, 1);
      expect(prefs.offers.length, 1);

      final primary = prefs.primaryAccount;
      expect(primary, isNotNull);
      expect(primary!.accountNumber, 'ACC222');
      expect(primary.nickName, 'Main Savings');
      expect(primary.primaryAccount, isTrue);

      final found = prefs.findAccount('ACC111');
      expect(found, isNotNull);
      expect(found!.nickName, 'Active Trading');
      expect(found.autoPositionEffect, isTrue);

      final streamer = prefs.streamerInfo.first;
      expect(streamer.schwabClientCustomerId, 'CUST123');

      final offer = prefs.offers.first;
      expect(offer.level2Permissions, isTrue);
      expect(offer.mktDataPermission, 'REAL_TIME');
    });

    test('SchwabUserPreference handles empty and minimal payload safely', () {
      final prefs = SchwabUserPreference.fromJson({});
      expect(prefs.accounts, isEmpty);
      expect(prefs.streamerInfo, isEmpty);
      expect(prefs.offers, isEmpty);
      expect(prefs.primaryAccount, isNull);
      expect(prefs.findAccount('999'), isNull);
    });
  });

  group('SchwabService Transactions & Dividends Integration Tests', () {
    test('buildTransactionsUrl constructs expected URL and query parameters',
        () {
      final service = SchwabService();
      final url = service.buildTransactionsUrl(
        'ACC_HASH_123',
        startDate: DateTime.parse('2026-01-01T00:00:00.000Z'),
        endDate: DateTime.parse('2026-03-31T23:59:59.000Z'),
        types: ['TRADE', 'DIVIDEND_OR_INTEREST'],
        symbol: 'NVDA',
      );

      expect(url, startsWith('https://api.schwabapi.com/trader/v1/accounts/ACC_HASH_123/transactions?'));
      expect(url, contains('startDate=2026-01-01T00%3A00%3A00.000Z'));
      expect(url, contains('endDate=2026-03-31T23%3A59%3A59.000Z'));
      expect(url, contains('types=TRADE%2CDIVIDEND_OR_INTEREST'));
      expect(url, contains('symbol=NVDA'));
    });

    test('getSchwabTransactions returns empty list gracefully on error',
        () async {
      final service = SchwabService();
      final user = BrokerageUser(BrokerageSource.schwab, 'user', null, null);

      final transactions =
          await service.getSchwabTransactions(user, accountNumber: 'TEST');
      expect(transactions, isEmpty);
    });

    test('getDividends & streamDividends return empty list gracefully on error',
        () async {
      final service = SchwabService();
      final user = BrokerageUser(BrokerageSource.schwab, 'user', null, null);
      final divStore = DividendStore();
      final instStore = InstrumentStore();

      final divs = await service.getDividends(user, divStore, instStore);
      expect(divs, isEmpty);
      expect(divStore.items, isEmpty);

      final streamed = await service.streamDividends(user, instStore).first;
      expect(streamed, isEmpty);
    });

    test('getInterests & streamInterests return empty list gracefully on error',
        () async {
      final service = SchwabService();
      final user = BrokerageUser(BrokerageSource.schwab, 'user', null, null);
      final intStore = InterestStore();
      final instStore = InstrumentStore();

      final interests = await service.getInterests(user, intStore);
      expect(interests, isEmpty);
      expect(intStore.items, isEmpty);

      final streamed = await service.streamInterests(user, instStore).first;
      expect(streamed, isEmpty);
    });
  });

  group('SchwabTransactionsWidget UI Tests', () {
    testWidgets('SchwabTransactionsWidget renders summary cards and filters',
        (tester) async {
      final service = SchwabService();
      final user = BrokerageUser(BrokerageSource.schwab, 'schwab_user', null, null);

      await tester.pumpWidget(
        MaterialApp(
          home: SchwabTransactionsWidget(
            user: user,
            service: service,
            initialAccountNumber: 'TEST_ACCT_123',
          ),
        ),
      );

      // Loading state initially
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      // Verify app bar title
      expect(find.text('Schwab Transactions'), findsOneWidget);

      // Verify Summary Card components
      expect(find.text('Account Activity Summary'), findsOneWidget);
      expect(find.text('Net Cash Flow'), findsOneWidget);
      expect(find.text('Dividends & Income'), findsOneWidget);
      expect(find.text('Trades Executed'), findsOneWidget);
      expect(find.text('Fees & Commissions'), findsOneWidget);

      // Verify Filter chips
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Trades'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Cash & Transfers'), findsOneWidget);
      expect(find.text('Fees'), findsOneWidget);

      // Verify Date chips
      expect(find.widgetWithText(ChoiceChip, '1M'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, '3M'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'YTD'), findsOneWidget);

      // Verify search input
      expect(
          find.widgetWithText(
              TextField, 'Search by symbol or description...'),
          findsOneWidget);
    });

    testWidgets(
        'SchwabTransactionsWidget renders in embedded mode without Scaffold AppBar',
        (tester) async {
      final service = SchwabService();
      final user =
          BrokerageUser(BrokerageSource.schwab, 'schwab_user', null, null);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SchwabTransactionsWidget(
              user: user,
              service: service,
              initialAccountNumber: 'TEST_ACCT_123',
              embedded: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // In embedded mode, Scaffold AppBar title is not rendered
      expect(find.text('Schwab Transactions'), findsNothing);

      // Embedded header title is rendered
      expect(find.text('Account Activity'), findsOneWidget);

      // Verify Summary Card components are still rendered
      expect(find.text('Account Activity Summary'), findsOneWidget);
      expect(find.text('Net Cash Flow'), findsOneWidget);
    });
  });
}
