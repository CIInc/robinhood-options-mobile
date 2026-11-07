import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/forex_holding_store.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals_store.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/option_historicals_store.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/option_instrument_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals_store.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DemoService Tests', () {
    late DemoService demoService;
    late BrokerageUser demoUser;
    late Account demoAccount;

    setUp(() {
      demoService = DemoService();
      demoUser = BrokerageUser(
        BrokerageSource.demo,
        'demo_user',
        null,
        null,
      );
      demoAccount = Account.fromJson({
        'account_number': '5DM12345',
        'url': 'https://api.robinhood.com/accounts/5DM12345/',
        'type': 'margin',
        'buying_power': '50000.00',
        'cash': '50000.00',
        'portfolio_cash': '50000.00',
      });
    });

    test('getInstrumentHistoricals generates valid historicals for SPY',
        () async {
      final store = InstrumentHistoricalsStore();
      final historicals = await demoService.getInstrumentHistoricals(
        demoUser,
        store,
        'SPY',
        chartDateSpanFilter: ChartDateSpan.day,
        chartBoundsFilter: Bounds.trading,
      );

      expect(historicals.symbol, equals('SPY'));
      expect(
          historicals.span, equals(convertChartSpanFilter(ChartDateSpan.day)));
      expect(
          historicals.bounds, equals(convertChartBoundsFilter(Bounds.trading)));
      expect(historicals.historicals, isNotNull);
      expect(historicals.historicals.isNotEmpty, isTrue);
      expect(store.items.any((h) => h.symbol == 'SPY'), isTrue);
    });

    test('getPortfolioHistoricals injects requested span and bounds', () async {
      final store = PortfolioHistoricalsStore();
      final portfolioHist = await demoService.getPortfolioHistoricals(
        demoUser,
        store,
        '5DM12345',
        Bounds.regular,
        ChartDateSpan.month,
      );

      expect(portfolioHist.span,
          equals(convertChartSpanFilter(ChartDateSpan.month)));
      expect(portfolioHist.bounds,
          equals(convertChartBoundsFilter(Bounds.regular)));
    });

    test('getOptionHistoricals injects requested span and bounds', () async {
      final store = OptionHistoricalsStore();
      final optHist = await demoService.getOptionHistoricals(
        demoUser,
        store,
        ['demo-opt-id'],
        chartDateSpanFilter: ChartDateSpan.week,
        chartBoundsFilter: Bounds.regular,
      );

      expect(optHist.span, equals(convertChartSpanFilter(ChartDateSpan.week)));
      expect(optHist.bounds, equals(convertChartBoundsFilter(Bounds.regular)));
    });

    test('getOptionChains generates dynamic Friday expirations and symbol',
        () async {
      final chain = await demoService.getOptionChains(demoUser, 'SPY');
      expect(chain.symbol, equals('SPY'));
      expect(chain.expirationDates.isNotEmpty, isTrue);
      expect(chain.expirationDates.length, equals(8));
    });

    test('streamOptionInstruments yields valid strikes with market data',
        () async {
      final store = OptionInstrumentStore();
      final instrument = Instrument.fromJson({
        'url': 'https://api.robinhood.com/instruments/spy-id/',
        'id': 'spy-id',
        'symbol': 'SPY',
        'name': 'SPDR S&P 500 ETF Trust',
        'quote': 'https://api.robinhood.com/quotes/spy-id/',
        'fundamentals': 'https://api.robinhood.com/fundamentals/spy-id/',
        'splits': 'https://api.robinhood.com/splits/spy-id/',
        'state': 'active',
        'market': 'https://api.robinhood.com/markets/XNYS/',
        'tradeable': true,
        'tradability': 'tradable',
        'bloomberg_unique': 'EQ0010174300001000',
        'country': 'US',
        'type': 'etp',
      });

      final stream = demoService.streamOptionInstruments(
        demoUser,
        store,
        instrument,
        null,
        'call',
        includeMarketData: true,
      );

      final list = await stream.first;
      expect(list.isNotEmpty, isTrue);
      expect(list.first.chainSymbol, equals('SPY'));
      expect(list.first.optionMarketData, isNotNull);
      expect(list.first.optionMarketData!.askPrice, isNotNull);
      expect(list.first.optionMarketData!.delta, isNotNull);
    });

    test('previously unimplemented methods execute without throwing', () async {
      final posStore = InstrumentPositionStore();
      final quoteStore = QuoteStore();
      final forexStore = ForexHoldingStore();

      // refreshPositionQuote
      final positions = await demoService.refreshPositionQuote(
          demoUser, posStore, quoteStore);
      expect(positions, isNotNull);

      // refreshQuote
      final quote = await demoService.refreshQuote(demoUser, quoteStore, 'SPY');
      expect(quote, isNotNull);

      // refreshNummusHoldings
      final holdings =
          await demoService.refreshNummusHoldings(demoUser, forexStore);
      expect(holdings, isNotNull);
      expect(forexStore.isLoading, isFalse);

      // placeOptionsOrder
      final optInstrument = OptionInstrument.fromJson({
        'id': 'test-opt',
        'url': 'https://api.robinhood.com/options/instruments/test-opt/',
        'chain_id': 'chain-1',
        'chain_symbol': 'SPY',
        'created_at': '2024-01-01T00:00:00Z',
        'expiration_date': '2026-12-18',
        'issue_date': '2024-01-01',
        'min_ticks': {'above_tick': '0.01', 'below_tick': '0.01'},
        'rhs_tradability': 'tradable',
        'state': 'active',
        'strike_price': '580.0000',
        'tradability': 'tradable',
        'type': 'call',
        'updated_at': '2024-01-01T00:00:00Z',
        'long_strategy_code': 'test-opt_L1',
        'short_strategy_code': 'test-opt_S1',
      });
      final optOrder = await demoService.placeOptionsOrder(
        demoUser,
        demoAccount,
        optInstrument,
        'buy',
        'open',
        'debit',
        5.50,
        1,
      );
      expect(optOrder['state'], equals('confirmed'));

      // placeMultiLegOptionsOrder
      final multiOrder = await demoService.placeMultiLegOptionsOrder(
        demoUser,
        demoAccount,
        [],
        'debit',
        10.0,
        1,
      );
      expect(multiOrder['state'], equals('confirmed'));
    });

    test(
        'generateRealisticPricePath creates authentic Brownian bridge with exact endpoints',
        () {
      final path = DemoService.generateRealisticPricePath(
        steps: 78,
        startVal: 77050.00,
        endVal: 78450.25,
        volatility: 550.0,
        seed: 42,
      );

      expect(path.length, equals(79));
      expect(path.first, equals(77050.00));
      expect(path.last, equals(78450.25));

      // Check for non-zero variance and absence of NaNs
      for (final p in path) {
        expect(p.isFinite, isTrue);
        expect(p > 0, isTrue);
      }

      // Ensure intermediate values are not monotonic or flat
      final diffs = <double>[];
      for (int i = 1; i < path.length; i++) {
        diffs.add(path[i] - path[i - 1]);
      }
      expect(diffs.any((d) => d > 0), isTrue);
      expect(diffs.any((d) => d < 0), isTrue);
    });

    test(
        'getPortfolioHistoricals 1D equity curve matches portfolio totals and continuous path',
        () async {
      final store = PortfolioHistoricalsStore();
      final portfolioHist = await demoService.getPortfolioHistoricals(
        demoUser,
        store,
        '5DM12345',
        Bounds.t24_7,
        ChartDateSpan.day,
      );

      expect(portfolioHist.equityHistoricals.isNotEmpty, isTrue);
      expect(portfolioHist.equityHistoricals.first.adjustedOpenEquity,
          equals(77050.00));
      expect(portfolioHist.equityHistoricals.last.adjustedCloseEquity,
          equals(78450.25));

      // Verify each point has valid values and no NaNs
      for (final h in portfolioHist.equityHistoricals) {
        expect(h.adjustedOpenEquity, isNotNull);
        expect(h.adjustedCloseEquity, isNotNull);
        expect(h.adjustedOpenEquity!.isFinite, isTrue);
        expect(h.adjustedCloseEquity!.isFinite, isTrue);
      }
    });

    test('getNummusHoldings manages loading state and marks store not loading',
        () async {
      final forexStore = ForexHoldingStore();
      expect(forexStore.isLoading, isFalse);
      final holdings =
          await demoService.getNummusHoldings(demoUser, forexStore);
      expect(holdings, isNotEmpty);
      expect(forexStore.isLoading, isFalse);
    });

    test(
        'getInstrumentBySymbol resolves known and arbitrary symbols resiliently',
        () async {
      final store = InstrumentStore();

      // Hardcoded JSON symbol
      final aapl =
          await demoService.getInstrumentBySymbol(demoUser, store, 'AAPL');
      expect(aapl, isNotNull);
      expect(aapl!.symbol, equals('AAPL'));

      // Demo known instrument (mover)
      final nflx =
          await demoService.getInstrumentBySymbol(demoUser, store, 'NFLX');
      expect(nflx, isNotNull);
      expect(nflx!.symbol, equals('NFLX'));

      // Dynamic arbitrary ticker synthesis
      final pltr =
          await demoService.getInstrumentBySymbol(demoUser, store, 'PLTR');
      expect(pltr, isNotNull);
      expect(pltr!.symbol, equals('PLTR'));
      expect(pltr.id, contains('pltr'));

      // Empty symbol returns null
      final empty =
          await demoService.getInstrumentBySymbol(demoUser, store, '   ');
      expect(empty, isNull);
    });

    test('search returns matching demo instruments and synthesizes typed query',
        () async {
      final nflxResults = await demoService.search(demoUser, 'NFLX');
      expect(nflxResults, isNotEmpty);
      expect(nflxResults.first['symbol'], equals('NFLX'));

      final customResults = await demoService.search(demoUser, 'XYZ');
      expect(customResults, isNotEmpty);
      expect(customResults.first['symbol'], equals('XYZ'));
    });

    test('streamList populates Watchlist items with instrumentObj and quotes',
        () async {
      final instStore = InstrumentStore();
      final qStore = QuoteStore();
      const bullishListKey = 'c9649938-4a7f-429e-b579-24a45e939a82';

      final stream =
          demoService.streamList(demoUser, instStore, qStore, bullishListKey);
      final watchlist = await stream.last;

      expect(watchlist.id, equals(bullishListKey));
      expect(watchlist.items.isNotEmpty, isTrue);
      expect(watchlist.items.length, equals(14));
      expect(
          watchlist.items.every((item) => item.instrumentObj != null), isTrue);
      expect(
          watchlist.items.every((item) =>
              item.instrumentObj != null &&
              item.instrumentObj!.symbol.isNotEmpty &&
              !item.instrumentObj!.symbol.startsWith('INST-')),
          isTrue);
      expect(
          watchlist.items.every((item) =>
              item.instrumentObj != null &&
              item.instrumentObj!.quoteObj != null),
          isTrue);
    });

    test(
        'streamList populates Options Watchlist with OptionInstrument and MarketData',
        () async {
      final instStore = InstrumentStore();
      final qStore = QuoteStore();
      const optionsListKey = '7a803fc0-bd97-4623-b141-748f3afa56a4';

      final stream =
          demoService.streamList(demoUser, instStore, qStore, optionsListKey);
      final watchlist = await stream.last;

      expect(watchlist.id, equals(optionsListKey));
      expect(watchlist.items.isNotEmpty, isTrue);
      expect(watchlist.items.length, equals(10));
      expect(
          watchlist.items.every((item) =>
              item.optionInstrumentObj != null &&
              item.optionInstrumentObj!.chainSymbol.isNotEmpty),
          isTrue);
      expect(
          watchlist.items.every((item) =>
              item.optionInstrumentObj != null &&
              item.optionInstrumentObj!.optionMarketData != null),
          isTrue);
    });

    test(
        'streamLists populates all 6 watchlists with non-empty items and quotes',
        () async {
      final instStore = InstrumentStore();
      final qStore = QuoteStore();

      final stream = demoService.streamLists(demoUser, instStore, qStore);
      final watchlists = await stream.last;

      expect(watchlists.length, equals(6));
      for (final wl in watchlists) {
        expect(wl.items.isNotEmpty, isTrue,
            reason:
                'Watchlist ${wl.displayName} (${wl.id}) should not be empty');
      }

      final optionsWl = watchlists
          .firstWhere((wl) => wl.id == '7a803fc0-bd97-4623-b141-748f3afa56a4');
      expect(optionsWl.items.length, equals(10));
      expect(
          optionsWl.items.every((item) =>
              item.optionInstrumentObj != null &&
              item.optionInstrumentObj!.optionMarketData != null),
          isTrue);

      final bearishWl = watchlists
          .firstWhere((wl) => wl.id == 'd65e8fed-a8f0-4349-a249-c5ff12926c1f');
      expect(bearishWl.items.length, equals(6));
      expect(
          bearishWl.items.every((item) =>
              item.instrumentObj != null &&
              !item.instrumentObj!.symbol.startsWith('INST-') &&
              item.instrumentObj!.quoteObj != null),
          isTrue);
    });

    test('getForexPairs returns pairs and initializes crypto mapping',
        () async {
      final pairs = await demoService.getForexPairs(demoUser);
      expect(pairs.isNotEmpty, isTrue);
      expect(pairs.any((p) => p['symbol'] == 'BTC-USD'), isTrue);
      expect(pairs.any((p) => p['symbol'] == 'DOGE-USD'), isTrue);
      expect(pairs.any((p) => p['symbol'] == 'SHIB-USD'), isTrue);
    });

    test('getForexQuote returns quotes for BTC and DOGE', () async {
      final btcQuote = await demoService.getForexQuote(
          demoUser, '3d961844-d360-45fc-989b-f6fca761d511');
      expect(btcQuote.symbol, equals('BTCUSD'));
      expect(btcQuote.markPrice, isNotNull);
      expect(btcQuote.markPrice!, greaterThan(10000));

      final dogeQuote = await demoService.getForexQuote(
          demoUser, '1ef78e1b-049b-4f12-90e5-555dcf2fe204');
      expect(dogeQuote.symbol, equals('DOGEUSD'));
      expect(dogeQuote.markPrice, isNotNull);
      expect(dogeQuote.markPrice!, greaterThan(0));
    });

    test(
        'getForexHistoricals returns non-empty recent historicals across spans for crypto',
        () async {
      final btcId = '3d961844-d360-45fc-989b-f6fca761d511';
      final dayHist = await demoService.getForexHistoricals(demoUser, btcId,
          chartDateSpanFilter: ChartDateSpan.day);
      expect(dayHist.historicals.isNotEmpty, isTrue);
      expect(dayHist.historicals.length, greaterThan(10));
      // Ensure data points are recent (ended within the last hour)
      final lastPoint = dayHist.historicals.last;
      expect(lastPoint.beginsAt, isNotNull);
      expect(DateTime.now().difference(lastPoint.beginsAt!).inHours.abs(),
          lessThan(2));

      final weekHist = await demoService.getForexHistoricals(demoUser, btcId,
          chartDateSpanFilter: ChartDateSpan.week);
      expect(weekHist.historicals.isNotEmpty, isTrue);

      final monthHist = await demoService.getForexHistoricals(demoUser, btcId,
          chartDateSpanFilter: ChartDateSpan.month);
      expect(monthHist.historicals.isNotEmpty, isTrue);
    });
  });
}
