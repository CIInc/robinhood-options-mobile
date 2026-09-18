import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';

void main() {
  test('uses the Schwab account number as the account identifier', () {
    final account = Account.fromSchwabJson({
      'securitiesAccount': {
        'accountNumber': '12345678',
        'hashValue': 'hashed-account-id',
        'type': 'MARGIN',
        'currentBalances': {
          'cashBalance': 1000,
          'buyingPower': 2000,
        },
      },
    });

    expect(account.accountNumber, '12345678');
    expect(account.url, '12345678');
    expect(account.toJson()['account_number'], '12345678');
  });

  test('assigns Schwab stock positions to their account', () {
    final position = InstrumentPosition.fromSchwabJson(
      {
        'averagePrice': 100.0,
        'longQuantity': 2.0,
        'instrument': {
          'cusip': 'CUSIP',
          'symbol': 'AAPL',
          'description': 'Apple Inc',
          'type': 'EQUITY',
        },
      },
      accountNumber: '12345678',
    );

    expect(position.account, '12345678');
    expect(position.accountNumber, '12345678');
  });

  test('parses Schwab equity positions as stock positions', () {
    final position = InstrumentPosition.fromSchwabJson(
      {
        'averagePrice': 100.0,
        'longQuantity': 2.0,
        'instrument': {
          'assetType': 'EQUITY',
          'cusip': 'CUSIP',
          'symbol': 'AAPL',
          'description': 'Apple Inc',
          'type': 'COMMON_STOCK',
        },
      },
      accountNumber: '12345678',
    );

    expect(position.instrumentObj?.symbol, 'AAPL');
    expect(position.accountNumber, '12345678');
  });

  test('handles missing Schwab instrument descriptions', () {
    final position = InstrumentPosition.fromSchwabJson(
      {
        'averagePrice': 100.0,
        'longQuantity': 2.0,
        'instrument': {
          'assetType': 'EQUITY',
          'cusip': 'CUSIP',
          'symbol': 'AAPL',
          'description': null,
          'type': 'COMMON_STOCK',
        },
      },
    );

    expect(position.instrumentObj?.name, isEmpty);
  });

  test('keeps the same Schwab symbol for separate accounts', () {
    InstrumentPosition createPosition(String accountNumber) {
      return InstrumentPosition.fromSchwabJson(
        {
          'averagePrice': 100.0,
          'longQuantity': 2.0,
          'instrument': {
            'cusip': 'CUSIP',
            'symbol': 'AAPL',
            'description': 'Apple Inc',
            'type': 'EQUITY',
          },
        },
        accountNumber: accountNumber,
      );
    }

    final store = InstrumentPositionStore();
    store.addOrUpdate(createPosition('account-one'));
    store.addOrUpdate(createPosition('account-two'));

    expect(store.items, hasLength(2));
    expect(store.items.map((position) => position.accountNumber),
        containsAll(<String>['account-one', 'account-two']));
  });

  test('keeps the same Schwab option contract for separate accounts', () {
    final accountOne = Account.fromSchwabJson({
      'securitiesAccount': {
        'accountNumber': 'account-one',
        'type': 'MARGIN',
      },
    });
    final accountTwo = Account.fromSchwabJson({
      'securitiesAccount': {
        'accountNumber': 'account-two',
        'type': 'MARGIN',
      },
    });

    Map<String, dynamic> createPosition() => {
          'averagePrice': 4.0,
          'longQuantity': 1.0,
          'shortQuantity': 0.0,
          'instrument': {
            'assetType': 'OPTION',
            'cusip': 'SHARED-CUSIP',
            'symbol': 'AAPL  261220C00200000',
            'underlyingSymbol': 'AAPL',
            'putCall': 'CALL',
            'description': 'AAPL 12/20/2026 \$200 Call',
            'type': 'VANILLA',
          },
        };

    final store = OptionPositionStore();
    store.addOrUpdate(
        OptionAggregatePosition.fromSchwabJson(createPosition(), accountOne));
    store.addOrUpdate(
        OptionAggregatePosition.fromSchwabJson(createPosition(), accountTwo));

    expect(store.items, hasLength(2));
    expect(store.items.map((position) => position.account),
        containsAll(<String>['account-one', 'account-two']));
  });

  test('loads legacy accounts using their account number', () {
    final account = Account.fromJson({
      'account_number': 'legacy-account',
      'type': 'cash',
    });

    expect(account.accountNumber, 'legacy-account');
    expect(account.toJson()['account_number'], 'legacy-account');
  });

  test('populates synthetic quote and computes market value and today return',
      () {
    final position = InstrumentPosition.fromSchwabJson({
      'averagePrice': 140.0,
      'longQuantity': 10.0,
      'marketValue': 1500.0,
      'currentDayProfitLoss': 50.0,
      'currentDayProfitLossPercentage': 3.45,
      'instrument': {
        'assetType': 'EQUITY',
        'cusip': '037833100',
        'symbol': 'AAPL',
        'description': 'Apple Inc',
        'netChange': 5.0,
        'type': 'COMMON_STOCK',
      },
    }, accountNumber: '12345678');

    expect(position.instrumentObj, isNotNull);
    expect(position.instrumentObj?.quoteObj, isNotNull);
    expect(position.instrumentObj!.quoteObj!.lastTradePrice, 150.0);
    expect(position.instrumentObj!.quoteObj!.adjustedPreviousClose, 145.0);
    expect(position.marketValue, 1500.0);
    expect(position.gainLossToday, 50.0);
    expect(position.gainLoss, 100.0); // 1500 - 1400
  });

  test(
      'derives netChange from currentDayProfitLoss if instrument.netChange is missing',
      () {
    final position = InstrumentPosition.fromSchwabJson({
      'averagePrice': 100.0,
      'longQuantity': 5.0,
      'marketValue': 600.0,
      'currentDayProfitLoss': 25.0,
      'instrument': {
        'assetType': 'EQUITY',
        'cusip': 'CUSIP1',
        'symbol': 'MSFT',
        'description': 'Microsoft Corp',
      },
    }, accountNumber: '12345678');

    expect(position.instrumentObj?.quoteObj, isNotNull);
    expect(position.instrumentObj!.quoteObj!.lastTradePrice, 120.0); // 600 / 5
    expect(position.instrumentObj!.quoteObj!.adjustedPreviousClose,
        115.0); // 120 - (25 / 5)
    expect(position.marketValue, 600.0);
    expect(position.gainLossToday, 25.0);
  });
}
