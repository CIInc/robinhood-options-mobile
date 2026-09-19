import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/portfolio.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_store.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument_historical.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals_store.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/services/schwab_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
          const MethodChannel('home_widget'), (call) async => true);
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

  test('parses totalValue and buying power in Account.fromSchwabJson', () {
    final account = Account.fromSchwabJson({
      'securitiesAccount': {
        'accountNumber': '87654321',
        'type': 'MARGIN',
        'currentBalances': {
          'liquidationValue': 54321.50,
          'cashBalance': 1234.50,
          'buyingPower': 10000.0,
          'dayTradingBuyingPower': 25000.0,
        },
        'initialBalances': {
          'liquidationValue': 50000.00,
        },
      },
    });

    expect(account.accountNumber, '87654321');
    expect(account.totalValue, 54321.50);
    expect(account.portfolioCash, 1234.50);
    expect(account.buyingPower, 10000.0);
    expect(account.dayTradeBuyingPower, 25000.0);

    // Serialization check
    final json = account.toJson();
    expect(json['total_value'], 54321.50);
    final restored = Account.fromJson(json);
    expect(restored.totalValue, 54321.50);
  });

  test(
      'Account.fromSchwabJson falls back to aggregatedBalance and initialBalances',
      () {
    final accountAgg = Account.fromSchwabJson({
      'aggregatedBalance': {
        'currentLiquidationValue': 42000.00,
      },
      'securitiesAccount': {
        'accountNumber': '11223344',
        'type': 'CASH',
      },
    });
    expect(accountAgg.totalValue, 42000.00);

    final accountInit = Account.fromSchwabJson({
      'securitiesAccount': {
        'accountNumber': '55667788',
        'type': 'CASH',
        'initialBalances': {
          'liquidationValue': 31000.00,
        },
      },
    });
    expect(accountInit.totalValue, 31000.00);
  });

  test(
      'parses equity, equityPreviousClose, and marketValue in Portfolio.fromSchwabJson',
      () {
    final portfolio = Portfolio.fromSchwabJson({
      'securitiesAccount': {
        'accountNumber': '87654321',
        'type': 'MARGIN',
        'currentBalances': {
          'liquidationValue': 75000.00,
          'marketValue': 50000.00,
          'mutualFundValue': 5000.00,
          'bondValue': 2000.00,
          'cashBalance': 18000.00,
          'excessMargin': 12000.00,
          'availableFunds': 15000.00,
        },
        'initialBalances': {
          'liquidationValue': 70000.00,
          'accountValue': 70000.00,
        },
      },
    });

    expect(portfolio.account, '87654321');
    expect(portfolio.equity, 75000.00);
    expect(portfolio.marketValue, 57000.00); // 50000 + 5000 + 2000
    expect(portfolio.equityPreviousClose, 70000.00);
    expect(portfolio.excessMargin, 12000.00);
    expect(portfolio.withdrawableAmount, 15000.00);

    // Calculate today's return
    final change =
        (portfolio.equity ?? 0.0) - (portfolio.equityPreviousClose ?? 0.0);
    expect(change, 5000.00);
  });

  test('PortfolioStore retains multiple Schwab portfolios without overwriting',
      () {
    final portfolioOne = Portfolio.fromSchwabJson({
      'securitiesAccount': {
        'accountNumber': 'schwab-acct-1',
        'type': 'MARGIN',
        'currentBalances': {
          'liquidationValue': 15000.0,
        },
      },
    });

    final portfolioTwo = Portfolio.fromSchwabJson({
      'securitiesAccount': {
        'accountNumber': 'schwab-acct-2',
        'type': 'CASH',
        'currentBalances': {
          'liquidationValue': 25000.0,
        },
      },
    });

    final store = PortfolioStore();
    store.addOrUpdate(portfolioOne);
    store.addOrUpdate(portfolioTwo);

    expect(store.items, hasLength(2));
    final p1 = store.items.firstWhere((p) => p.account == 'schwab-acct-1');
    final p2 = store.items.firstWhere((p) => p.account == 'schwab-acct-2');
    expect(p1.equity, 15000.0);
    expect(p2.equity, 25000.0);

    // Update first portfolio with new value
    final updatedP1 = Portfolio.fromSchwabJson({
      'securitiesAccount': {
        'accountNumber': 'schwab-acct-1',
        'type': 'MARGIN',
        'currentBalances': {
          'liquidationValue': 16000.0,
        },
      },
    });
    store.addOrUpdate(updatedP1);

    expect(store.items, hasLength(2));
    expect(store.items.firstWhere((p) => p.account == 'schwab-acct-1').equity,
        16000.0);
    expect(store.items.firstWhere((p) => p.account == 'schwab-acct-2').equity,
        25000.0);
  });

  test('AccountStore updates selectedAccount and switches totalValue correctly',
      () {
    final acctOne = Account.fromSchwabJson({
      'securitiesAccount': {
        'accountNumber': 'schwab-acct-1',
        'type': 'MARGIN',
        'currentBalances': {
          'liquidationValue': 15000.0,
        },
      },
    });
    final acctTwo = Account.fromSchwabJson({
      'securitiesAccount': {
        'accountNumber': 'schwab-acct-2',
        'type': 'CASH',
        'currentBalances': {
          'liquidationValue': 25000.0,
        },
      },
    });

    final store = AccountStore();
    store.addOrUpdate(acctOne);
    store.addOrUpdate(acctTwo);

    expect(store.items, hasLength(2));

    // Default selection is first account
    expect(store.selectedAccount?.accountNumber, 'schwab-acct-1');
    expect(store.selectedAccount?.totalValue, 15000.0);

    // Switch to second account
    store.setSelectedAccountNumber('schwab-acct-2');
    expect(store.selectedAccount?.accountNumber, 'schwab-acct-2');
    expect(store.selectedAccount?.totalValue, 25000.0);

    // Switch back to first account
    store.setSelectedAccountNumber('schwab-acct-1');
    expect(store.selectedAccount?.accountNumber, 'schwab-acct-1');
    expect(store.selectedAccount?.totalValue, 15000.0);
  });

  test(
      'Schwab historicals use converted span and bounds compatible with InstrumentChartWidget',
      () async {
    final store = InstrumentHistoricalsStore();
    final service = SchwabService();
    final user = BrokerageUser(
      BrokerageSource.schwab,
      'user@example.com',
      null,
      null,
    );

    // Fetch historicals (will fall back gracefully without OAuth client)
    final hist = await service.getInstrumentHistoricals(
      user,
      store,
      'AAPL',
      chartDateSpanFilter: ChartDateSpan.month_3,
      chartBoundsFilter: Bounds.t24_7,
    );

    expect(hist.symbol, 'AAPL');
    // Expect span and bounds to match convertChartSpanFilter and convertChartBoundsFilter
    expect(hist.span, convertChartSpanFilter(ChartDateSpan.month_3));
    expect(hist.span, '3month');
    expect(hist.bounds, convertChartBoundsFilter(Bounds.t24_7));
    expect(hist.bounds, '24_7');

    // Verify lookup by InstrumentChartWidget succeeds
    final found = store.items.firstWhereOrNull((element) =>
        element.symbol == 'AAPL' &&
        element.span == convertChartSpanFilter(ChartDateSpan.month_3) &&
        element.bounds == convertChartBoundsFilter(Bounds.t24_7));
    expect(found, isNotNull);
  });

  test('Schwab candles JSON correctly maps to InstrumentHistorical objects',
      () {
    final candlesJson = [
      {
        'datetime': 1700000000000,
        'open': 150.25,
        'close': 152.50,
        'high': 153.00,
        'low': 149.80,
        'volume': 1234567,
      },
      {
        'datetime': 1700000300000,
        'open': 152.50,
        'close': 151.75,
        'high': 152.90,
        'low': 151.20,
        'volume': 98765,
      }
    ];

    List<InstrumentHistorical> historicals = [];
    for (var c in candlesJson) {
      historicals.add(InstrumentHistorical(
        DateTime.fromMillisecondsSinceEpoch(c['datetime'] as int, isUtc: true),
        (c['open'] as num).toDouble(),
        (c['close'] as num).toDouble(),
        (c['high'] as num).toDouble(),
        (c['low'] as num).toDouble(),
        (c['volume'] as num).toInt(),
        'regular',
        false,
      ));
    }

    expect(historicals, hasLength(2));
    expect(historicals[0].openPrice, 150.25);
    expect(historicals[0].closePrice, 152.50);
    expect(historicals[0].highPrice, 153.00);
    expect(historicals[0].lowPrice, 149.80);
    expect(historicals[0].volume, 1234567);
    expect(historicals[0].beginsAt,
        DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true));

    final store = InstrumentHistoricalsStore();
    final histObj = InstrumentHistoricals(
      'https://api.schwabapi.com/marketdata/v1/quotes?symbols=AAPL',
      'AAPL',
      '5minute',
      convertChartSpanFilter(ChartDateSpan.day),
      convertChartBoundsFilter(Bounds.trading),
      150.00,
      DateTime.fromMillisecondsSinceEpoch(1699999000000, isUtc: true),
      historicals.first.openPrice,
      historicals.first.beginsAt,
      'AAPL',
      'AAPL',
      historicals,
    );

    store.set(histObj);

    final retrieved = store.items.firstWhereOrNull((element) =>
        element.symbol == 'AAPL' &&
        element.span == convertChartSpanFilter(ChartDateSpan.day) &&
        element.bounds == convertChartBoundsFilter(Bounds.trading));

    expect(retrieved, isNotNull);
    expect(retrieved!.historicals, hasLength(2));
    expect(retrieved.historicals.first.openPrice, 150.25);
  });

  test('InstrumentHistoricalsStore handles empty historicals gracefully', () {
    final store = InstrumentHistoricalsStore();
    final emptyHist = InstrumentHistoricals(
      '',
      'MSFT',
      '5minute',
      convertChartSpanFilter(ChartDateSpan.day),
      convertChartBoundsFilter(Bounds.trading),
      null,
      null,
      null,
      null,
      'MSFT',
      'MSFT',
      [],
    );

    // Initial set
    store.set(emptyHist);
    expect(store.items, hasLength(1));
    expect(store.items.first.historicals, isEmpty);

    // Subsequent set should update without throwing StateError on empty list
    store.set(emptyHist);
    expect(store.items, hasLength(1));

    // addOrUpdate should also work cleanly
    store.addOrUpdate(emptyHist);
    expect(store.items, hasLength(1));
  });
}
