import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/forex_holding.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/option_chain.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/portfolio.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/services/offline_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('OfflineCacheService Tests', () {
    test('save and load portfolio snapshot successfully', () async {
      final account = Account.fromJson({
        'url': 'https://api.robinhood.com/accounts/ACC123/',
        'account_number': 'ACC123',
        'type': 'margin',
        'portfolio_cash': 2500.50,
        'buying_power': 5000.00,
        'total_value': 12500.75,
        'option_level': 'tier_3',
        'cash_held_for_options_collateral': 500.0,
        'unsettled_debit': 0.0,
        'settled_amount_borrowed': 0.0,
      });

      final portfolio = Portfolio.fromJson({
        'url': 'https://api.robinhood.com/portfolios/ACC123/',
        'account': 'ACC123',
        'start_date': '2025-01-01',
        'market_value': 10000.25,
        'equity': 12500.75,
        'excess_margin': 5000.00,
        'excess_maintenance': 4500.00,
        'equity_previous_close': 12000.00,
        'withdrawable_amount': 2500.50,
      });

      final stock = InstrumentPosition.fromJson({
        'url': 'https://api.robinhood.com/positions/ACC123/inst-1/',
        'instrument': 'https://api.robinhood.com/instruments/inst-1/',
        'account': 'https://api.robinhood.com/accounts/ACC123/',
        'account_number': 'ACC123',
        'average_buy_price': 150.25,
        'quantity': 10.0,
        'intraday_average_buy_price': 150.25,
        'intraday_quantity': 0.0,
        'shares_available_for_exercise': 10.0,
        'shares_held_for_buys': 0.0,
        'shares_held_for_sells': 0.0,
        'shares_held_for_stock_grants': 0.0,
        'shares_held_for_options_collateral': 0.0,
        'shares_held_for_options_events': 0.0,
        'shares_pending_from_options_events': 0.0,
        'shares_available_for_closing_short_position': 0.0,
        'ipo_allocated_quantity': 0.0,
        'avg_cost_affected': false,
        'updated_at': '2026-09-19T12:00:00Z',
        'created_at': '2026-09-19T10:00:00Z',
      });

      final option = OptionAggregatePosition.fromJson({
        'id': 'pos_opt_1',
        'chain': 'chain_AAPL',
        'account': 'ACC123',
        'symbol': 'AAPL',
        'strategy': 'call',
        'average_open_price': 2.50,
        'legs': [],
        'quantity': 2.0,
        'direction': 'debit',
        'intraday_direction': 'debit',
        'strategy_code': 'long_call',
      });

      final now = DateTime(2026, 9, 19, 14, 30);
      await OfflineCacheService.savePortfolioSnapshot(
        accounts: [account],
        portfolios: [portfolio],
        stockPositions: [stock],
        optionPositions: [option],
        customTimestamp: now,
      );

      final snapshot = await OfflineCacheService.loadPortfolioSnapshot();
      expect(snapshot, isNotNull);
      expect(snapshot!.timestamp, equals(now));
      expect(snapshot.accounts.length, equals(1));
      expect(snapshot.accounts.first.accountNumber, equals('ACC123'));
      expect(snapshot.accounts.first.portfolioCash, equals(2500.50));
      expect(snapshot.portfolios.length, equals(1));
      expect(snapshot.portfolios.first.equity, equals(12500.75));
      expect(snapshot.stockPositions.length, equals(1));
      expect(snapshot.stockPositions.first.quantity, equals(10.0));
      expect(snapshot.optionPositions.length, equals(1));
      expect(snapshot.optionPositions.first.symbol, equals('AAPL'));
      expect(snapshot.optionPositions.first.quantity, equals(2.0));

      final lastSync = await OfflineCacheService.getLastSyncTime();
      expect(lastSync, equals(now));
    });

    test('save and load portfolio snapshot with instrument and option chain',
        () async {
      final optionChain = OptionChain(
        'chain_AAPL',
        'AAPL',
        true,
        null,
        [DateTime(2026, 10, 16), DateTime(2026, 11, 20)],
        100.0,
        const MinTicks(0.01, 0.05, 3.0),
      );

      final instrument = Instrument.fromSchwabJson({
        'symbol': 'AAPL',
        'cusip': '037833100',
        'description': 'Apple Inc.',
        'exchange': 'NASDAQ',
        'assetType': 'stock',
      });
      instrument.optionChainObj = optionChain;

      final stock = InstrumentPosition.fromJson({
        'url': 'https://api.robinhood.com/positions/ACC123/inst-1/',
        'instrument': 'https://api.robinhood.com/instruments/inst-1/',
        'account': 'https://api.robinhood.com/accounts/ACC123/',
        'account_number': 'ACC123',
        'average_buy_price': 150.25,
        'quantity': 10.0,
        'intraday_average_buy_price': 150.25,
        'intraday_quantity': 0.0,
        'shares_available_for_exercise': 10.0,
        'shares_held_for_buys': 0.0,
        'shares_held_for_sells': 0.0,
        'shares_held_for_stock_grants': 0.0,
        'shares_held_for_options_collateral': 0.0,
        'shares_held_for_options_events': 0.0,
        'shares_pending_from_options_events': 0.0,
        'shares_available_for_closing_short_position': 0.0,
        'ipo_allocated_quantity': 0.0,
        'avg_cost_affected': false,
        'updated_at': '2026-09-19T12:00:00Z',
        'created_at': '2026-09-19T10:00:00Z',
      });
      stock.instrumentObj = instrument;

      final now = DateTime(2026, 9, 19, 15, 00);
      await OfflineCacheService.savePortfolioSnapshot(
        accounts: [],
        portfolios: [],
        stockPositions: [stock],
        optionPositions: [],
        customTimestamp: now,
      );

      final snapshot = await OfflineCacheService.loadPortfolioSnapshot();
      expect(snapshot, isNotNull);
      expect(snapshot!.stockPositions.length, equals(1));
      final loadedStock = snapshot.stockPositions.first;
      expect(loadedStock.instrumentObj, isNotNull);
      expect(loadedStock.instrumentObj!.optionChainObj, isNotNull);
      expect(loadedStock.instrumentObj!.optionChainObj!.expirationDates.length,
          equals(2));
      expect(loadedStock.instrumentObj!.optionChainObj!.expirationDates.first,
          equals(DateTime(2026, 10, 16)));
    });

    test('save and load portfolio snapshot with forex holdings', () async {
      final forex = ForexHolding.fromJson({
        'id': 'holding_btc_1',
        'account_id': 'ACC123',
        'cost_bases': [
          {
            'direct_cost_basis': '499.95',
            'direct_quantity': '0.0156',
            'id': 'cb_1',
          }
        ],
        'created_at': '2026-09-19T10:00:00Z',
        'updated_at': '2026-09-19T12:00:00Z',
        'currency': {
          'id': 'curr_btc',
          'code': 'BTC',
          'name': 'Bitcoin',
        },
        'quantity': '0.0156',
      });

      final now = DateTime(2026, 9, 19, 16, 00);
      await OfflineCacheService.savePortfolioSnapshot(
        accounts: [],
        portfolios: [],
        stockPositions: [],
        optionPositions: [],
        forexHoldings: [forex],
        customTimestamp: now,
      );

      final snapshot = await OfflineCacheService.loadPortfolioSnapshot();
      expect(snapshot, isNotNull);
      expect(snapshot!.forexHoldings.length, equals(1));
      final loadedForex = snapshot.forexHoldings.first;
      expect(loadedForex.id, equals('holding_btc_1'));
      expect(loadedForex.currencyCode, equals('BTC'));
      expect(loadedForex.quantity, equals(0.0156));
      expect(loadedForex.directCostBasis, equals(499.95));

      // Test re-saving the loaded snapshot to ensure round-trip stability when quantity is double
      await OfflineCacheService.savePortfolioSnapshot(
        accounts: [],
        portfolios: [],
        stockPositions: [],
        optionPositions: [],
        forexHoldings: [loadedForex],
        customTimestamp: now,
      );
      final reloadedSnapshot =
          await OfflineCacheService.loadPortfolioSnapshot();
      expect(reloadedSnapshot, isNotNull);
      expect(reloadedSnapshot!.forexHoldings.length, equals(1));
      expect(reloadedSnapshot.forexHoldings.first.quantity, equals(0.0156));
      expect(
          reloadedSnapshot.forexHoldings.first.directCostBasis, equals(499.95));
    });

    test('save and load trade signals', () async {
      final signals = [
        {
          'symbol': 'AAPL',
          'signalType': 'BUY',
          'strength': 85,
          'timestamp': '2026-09-19T14:00:00Z',
          'interval': '1d',
        },
        {
          'symbol': 'NVDA',
          'signalType': 'HOLD',
          'strength': 60,
          'timestamp': '2026-09-19T14:00:00Z',
          'interval': '1d',
        },
      ];

      await OfflineCacheService.saveTradeSignals(signals);
      final loaded = await OfflineCacheService.loadTradeSignals();

      expect(loaded.length, equals(2));
      expect(loaded[0]['symbol'], equals('AAPL'));
      expect(loaded[0]['signalType'], equals('BUY'));
      expect(loaded[1]['symbol'], equals('NVDA'));
    });

    test('save and load quotes', () async {
      final quote = Quote.fromJson({
        'symbol': 'TSLA',
        'last_trade_price': '225.50',
        'ask_price': '225.60',
        'ask_size': 100,
        'bid_price': '225.40',
        'bid_size': 200,
        'previous_close': '220.00',
        'trading_halted': false,
        'has_traded': true,
        'last_trade_price_source': 'consolidated',
        'instrument': 'https://api.robinhood.com/instruments/tsla/',
        'instrument_id': 'tsla-id',
      });

      await OfflineCacheService.saveQuotes([quote]);
      final loaded = await OfflineCacheService.loadQuotes();

      expect(loaded.length, equals(1));
      expect(loaded.first.symbol, equals('TSLA'));
      expect(loaded.first.lastTradePrice, equals(225.50));
    });

    test('save and load watchlists', () async {
      final symbols = ['AAPL', 'MSFT', 'GOOGL', 'AMZN'];
      await OfflineCacheService.saveWatchlistSymbols(symbols);

      final loaded = await OfflineCacheService.loadWatchlistSymbols();
      expect(loaded, equals(symbols));
    });

    test('clearCache removes all keys', () async {
      await OfflineCacheService.saveWatchlistSymbols(['SPY']);
      await OfflineCacheService.saveTradeSignals([
        {'symbol': 'SPY'}
      ]);

      await OfflineCacheService.clearCache();

      expect(await OfflineCacheService.loadWatchlistSymbols(), isEmpty);
      expect(await OfflineCacheService.loadTradeSignals(), isEmpty);
      expect(await OfflineCacheService.loadPortfolioSnapshot(), isNull);
      expect(await OfflineCacheService.getLastSyncTime(), isNull);
    });

    test('freshness evaluation and formatting helpers', () {
      final now = DateTime.now();
      expect(OfflineCacheService.isDataStale(now), isFalse);
      expect(
        OfflineCacheService.isDataStale(
          now.subtract(const Duration(minutes: 30)),
          threshold: const Duration(minutes: 15),
        ),
        isTrue,
      );
      expect(OfflineCacheService.isDataStale(null), isTrue);

      expect(OfflineCacheService.formatRelativeTime(now), equals('Just now'));
      expect(
        OfflineCacheService.formatRelativeTime(
            now.subtract(const Duration(minutes: 5))),
        equals('5m ago'),
      );
      expect(
        OfflineCacheService.formatRelativeTime(
            now.subtract(const Duration(hours: 3))),
        equals('3h ago'),
      );
      expect(OfflineCacheService.formatRelativeTime(null), equals('Never'));

      final testDate = DateTime(2026, 10, 12, 10, 30);
      expect(OfflineCacheService.formatSyncDateTime(testDate),
          equals('Oct 12, 10:30 AM'));
      expect(OfflineCacheService.formatSyncDateTime(null), equals('Unknown'));
    });
  });
}
