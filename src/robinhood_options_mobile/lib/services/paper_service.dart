import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:robinhood_options_mobile/enums.dart';

import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/dividend_store.dart';
import 'package:robinhood_options_mobile/model/forex_historicals.dart';
import 'package:robinhood_options_mobile/model/forex_holding.dart';
import 'package:robinhood_options_mobile/model/forex_holding_store.dart';
import 'package:robinhood_options_mobile/model/forex_order.dart';
import 'package:robinhood_options_mobile/model/forex_quote.dart';
import 'package:robinhood_options_mobile/model/fundamentals.dart';
import 'package:robinhood_options_mobile/model/future_historicals.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals_store.dart';
import 'package:robinhood_options_mobile/model/instrument_order.dart';
import 'package:robinhood_options_mobile/model/instrument_order_store.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/interest_store.dart';
import 'package:robinhood_options_mobile/model/midlands_movers_item.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_chain.dart';
import 'package:robinhood_options_mobile/model/option_event.dart';
import 'package:robinhood_options_mobile/model/option_event_store.dart';
import 'package:robinhood_options_mobile/model/option_historicals.dart';
import 'package:robinhood_options_mobile/model/option_historicals_store.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/option_instrument_store.dart';
import 'package:robinhood_options_mobile/model/option_marketdata.dart';
import 'package:robinhood_options_mobile/model/option_order.dart';
import 'package:robinhood_options_mobile/model/option_order_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/portfolio.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_store.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/user_info.dart';
import 'package:robinhood_options_mobile/model/watchlist.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/yahoo_service.dart';
import 'package:robinhood_options_mobile/main.dart';

import 'package:robinhood_options_mobile/model/equity_historical.dart';

class PaperService implements IBrokerageService {
  final YahooService yahooService = YahooService();
  final FirestoreService _firestoreService = FirestoreService();

  PaperService();

  @override
  String name = 'Paper Trading - Integrated';
  @override
  Uri endpoint = Uri.parse('https://realizealpha.web.app/api/v1');
  @override
  Uri authEndpoint = Uri.parse('https://realizealpha.web.app/oauth2/auth/');
  @override
  Uri tokenEndpoint = Uri.parse('https://realizealpha.web.app/oauth2/token/');
  @override
  String clientId = 'robinhood_options_mobile';
  @override
  String redirectUrl = ''; // http://localhost:8080

  @override
  Future<UserInfo?> getUser(BrokerageUser user) async {
    return user.userInfo;
  }

  @override
  Future<List<Account>> getAccounts(BrokerageUser user, AccountStore store,
      PortfolioStore? portfolioStore, OptionPositionStore? optionPositionStore,
      {InstrumentPositionStore? instrumentPositionStore,
      DocumentReference? userDoc}) async {
    final userId = userDoc?.id ??
        auth.currentUser?.uid ??
        user.userInfo?.id ??
        user.userName ??
        'default_paper_user';
    final paperAccountDoc = await _firestoreService.getPaperAccountDoc(userId);
    final data = paperAccountDoc.data() ?? {};

    final balance = (data['cashBalance'] as num?)?.toDouble() ?? 100000.0;

    final account = Account(
      'paper_account_url', // url
      balance, // portfolioCash
      'paper_account', // accountNumber
      'Paper Account', // type
      balance, // buyingPower
      'Level 3', // optionLevel
      0.0, // cashHeldForOptionsCollateral
      0.0, // unsettledDebit
      0.0, // settledAmountBorrowed
    );

    store.removeAll();
    store.add(account);

    if (portfolioStore != null) {
      final portfolio = Portfolio(
        'paper_portfolio',
        'paper_account',
        DateTime.now(),
        balance, // marketValue
        balance, // equity
        balance, // extendedHoursMarketValue
        balance, // extendedHoursEquity
        balance, // extendedHoursPortfolioEquity
        balance, // lastCoreMarketValue
        balance, // lastCoreEquity
        balance, // lastCorePortfolioEquity
        balance, // excessMargin
        balance, // excessMaintenance
        balance, // excessMarginWithUnclearedDeposits
        balance, // excessMaintenanceWithUnclearedDeposits
        balance, // equityPreviousClose
        balance, // portfolioEquityPreviousClose
        balance, // adjustedEquityPreviousClose
        balance, // adjustedPortfolioEquityPreviousClose
        balance, // withdrawableAmount
        0.0, // unwithdrawableDeposits
        0.0, // unwithdrawableGrants
        DateTime.now(), // updatedAt
      );
      portfolioStore.removeAll();
      portfolioStore.add(portfolio);
    }

    if (instrumentPositionStore != null) {
      await getStockPositionStore(
          user, instrumentPositionStore, InstrumentStore(), QuoteStore(),
          userDoc: userDoc);
    }

    return [account];
  }

  @override
  Future<List<Portfolio>> getPortfolios(
      BrokerageUser user, PortfolioStore store) async {
    final userId = auth.currentUser?.uid ??
        user.userInfo?.id ??
        user.userName ??
        'default_paper_user';
    final paperAccountDoc = await _firestoreService.getPaperAccountDoc(userId);
    final data = paperAccountDoc.data() ?? {};
    final balance = (data['cashBalance'] as num?)?.toDouble() ?? 100000.0;

    final portfolio = Portfolio(
      'paper_portfolio',
      'paper_account',
      DateTime.now(),
      balance,
      balance,
      balance,
      balance,
      balance,
      balance,
      balance,
      balance,
      balance,
      balance,
      balance,
      balance,
      balance,
      balance,
      balance,
      balance,
      balance,
      0.0,
      0.0,
      DateTime.now(),
    );
    store.removeAll();
    store.add(portfolio);
    return [portfolio];
  }

  @override
  Future<InstrumentPositionStore> getStockPositionStore(
      BrokerageUser user,
      InstrumentPositionStore store,
      InstrumentStore instrumentStore,
      QuoteStore quoteStore,
      {bool nonzero = true,
      DocumentReference? userDoc}) async {
    final userId = userDoc?.id ??
        auth.currentUser?.uid ??
        user.userInfo?.id ??
        user.userName ??
        'default_paper_user';
    final positions = await _firestoreService.listPaperPositions(userId);

    if (positions.isNotEmpty) {
      // Collect symbols from positions that already have instrumentObj
      var symbols = positions
          .map((p) => p.instrumentObj?.symbol ?? '')
          .where((s) => s.isNotEmpty)
          .toList();

      // For positions without instrumentObj, fetch instruments by ID from instrument URL
      final positionsNeedingInstrument = positions
          .where((p) => p.instrumentObj == null && p.instrument.isNotEmpty)
          .toList();
      if (positionsNeedingInstrument.isNotEmpty) {
        final instrumentIds = positionsNeedingInstrument
            .map((p) => p.instrumentId)
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList();
        if (instrumentIds.isNotEmpty) {
          final fetchedById =
              await getInstrumentsByIds(user, instrumentStore, instrumentIds);
          for (var pos in positionsNeedingInstrument) {
            final match = fetchedById
                .firstWhereOrNull((i) => pos.instrument.contains(i.id));
            if (match != null) {
              pos.instrumentObj = match;
              if (!symbols.contains(match.symbol)) {
                symbols.add(match.symbol);
              }
            }
          }
        }
      }

      if (symbols.isNotEmpty) {
        final fetchedInstruments = await yahooService.getInstruments(symbols);

        for (var pos in positions) {
          if (pos.instrumentObj != null) {
            pos.instrumentObj = fetchedInstruments.firstWhereOrNull(
                    (i) => i.symbol == pos.instrumentObj!.symbol) ??
                pos.instrumentObj;
          } else {
            pos.instrumentObj = fetchedInstruments.firstWhereOrNull((i) =>
                pos.instrument.contains(i.symbol) ||
                pos.instrument.contains(i.id));
          }
        }
        await getQuoteByIds(user, quoteStore, symbols);
        for (var pos in positions) {
          if (pos.instrumentObj != null &&
              pos.instrumentObj!.quoteObj == null &&
              quoteStore.items.isNotEmpty) {
            final quote = quoteStore.items
                .firstWhereOrNull((q) => q.symbol == pos.instrumentObj!.symbol);
            if (quote != null) {
              pos.instrumentObj!.quoteObj = quote;
            }
          }
        }
      }
    }

    store.removeAll();
    for (var pos in positions) {
      store.add(pos);
    }
    return store;
  }

  @override
  Future<List<ForexHolding>> getNummusHoldings(
      BrokerageUser user, ForexHoldingStore store,
      {bool nonzero = true, DocumentReference? userDoc}) async {
    return [];
  }

  @override
  Future<List<ForexHolding>> refreshNummusHoldings(
      BrokerageUser user, ForexHoldingStore store) async {
    return [];
  }

  @override
  Future<ForexQuote> getForexQuote(BrokerageUser user, String id) async {
    throw UnimplementedError();
  }

  @override
  Future<List<ForexQuote>> getForexQuoteByIds(
      BrokerageUser user, List<String> ids) async {
    return [];
  }

  @override
  Future<OptionPositionStore> getOptionPositionStore(BrokerageUser user,
      OptionPositionStore store, InstrumentStore instrumentStore,
      {bool nonzero = true, DocumentReference? userDoc}) async {
    final userId = userDoc?.id ??
        auth.currentUser?.uid ??
        user.userInfo?.id ??
        user.userName ??
        'default_paper_user';
    final positions = await _firestoreService.listPaperOptionPositions(userId);

    if (positions.isNotEmpty) {
      // Collect option instrument IDs to fetch metadata/market data
      final optionIds = positions
          .where((p) => p.optionInstrument == null)
          .map((p) =>
              p.legs.first.option.split('/').where((s) => s.isNotEmpty).last)
          .toSet()
          .toList();

      if (optionIds.isNotEmpty) {
        final fetched = await getOptionInstrumentByIds(user, optionIds);
        for (var pos in positions) {
          if (pos.optionInstrument == null) {
            pos.optionInstrument = fetched
                .firstWhereOrNull((i) => pos.legs.first.option.contains(i.id));
          }
        }
      }

      // Fetch market data for all positions
      final allOptionIds = positions
          .map((p) => p.optionInstrument?.id)
          .whereType<String>()
          .toList();
      if (allOptionIds.isNotEmpty) {
        final marketData = await getOptionMarketDataByIds(user, allOptionIds);
        for (var pos in positions) {
          if (pos.optionInstrument != null) {
            pos.optionInstrument!.optionMarketData =
                marketData.firstWhereOrNull(
                    (m) => m.instrumentId == pos.optionInstrument!.id);
          }
        }
      }
    }

    store.removeAll();
    for (var pos in positions) {
      store.add(pos);
    }
    return store;
  }

  @override
  Future<List<OptionAggregatePosition>> getAggregateOptionPositions(
      BrokerageUser user,
      {bool nonzero = true}) async {
    final userId = auth.currentUser?.uid ??
        user.userInfo?.id ??
        user.userName ??
        'default_paper_user';
    return _firestoreService.listPaperOptionPositions(userId);
  }

  @override
  Stream<List<OptionInstrument>> streamOptionInstruments(
      BrokerageUser user,
      OptionInstrumentStore store,
      Instrument instrument,
      String? expirationDates,
      String? type,
      {String? state = "active",
      bool includeMarketData = false}) {
    return Stream.value([]);
  }

  @override
  Future<List<OptionInstrument>> getOptionInstrumentByIds(
      BrokerageUser user, List<String> ids) async {
    return _firestoreService.getOptionInstruments(ids);
  }

  @override
  Future<OptionMarketData?> getOptionMarketData(
      BrokerageUser user, OptionInstrument optionInstrument) async {
    return _firestoreService.getOptionMarketData(optionInstrument.id);
  }

  @override
  Future<List<OptionMarketData>> getOptionMarketDataByIds(
      BrokerageUser user, List<String> ids) async {
    return _firestoreService.getOptionMarketDataList(ids);
  }

  @override
  Future<List<OptionAggregatePosition>> refreshOptionMarketData(
      BrokerageUser user,
      OptionPositionStore optionPositionStore,
      OptionInstrumentStore optionInstrumentStore) async {
    if (optionPositionStore.items.isEmpty) {
      return [];
    }

    var optionIds = optionPositionStore.items.map((e) {
      var parts = e.legs.first.option.split('/');
      return parts.last.isEmpty ? parts[parts.length - 2] : parts.last;
    }).toList();

    var optionMarketData = await getOptionMarketDataByIds(user, optionIds);

    for (var optionMarketDatum in optionMarketData) {
      try {
        var optionPosition = optionPositionStore.items.singleWhere((element) {
          return element.legs.first.option
              .contains(optionMarketDatum.instrumentId);
        });

        if (optionPosition.optionInstrument != null) {
          optionPosition.optionInstrument!.optionMarketData = optionMarketDatum;
          optionInstrumentStore.addOrUpdate(optionPosition.optionInstrument!);
          optionPositionStore.update(optionPosition);
        }
      } catch (e) {
        // Not found or multiple matches, skip
      }
    }
    return optionPositionStore.items;
  }

  @override
  Future<List<OptionEvent>> getOptionEventsByInstrumentUrl(
      BrokerageUser user, String instrumentUrl) async {
    return [];
  }

  @override
  Stream<List<OptionEvent>> streamOptionEvents(
      BrokerageUser user, OptionEventStore store,
      {int pageSize = 20, DocumentReference? userDoc}) {
    return Stream.value([]);
  }

  @override
  Future<List<OptionChain>> getOptionChainsByIds(
      BrokerageUser user, List<String> ids) async {
    return [];
  }

  @override
  Future<OptionChain> getOptionChains(BrokerageUser user, String id) async {
    // Return empty mock for paper options
    return OptionChain(
        id, 'paper_symbol', true, 0.0, [], 100.0, const MinTicks(0.05, 0.01, 3.0));
  }

  @override
  Future<Instrument> getInstrument(
      BrokerageUser user, InstrumentStore store, String instrumentUrl) async {
    // Try to extract symbol from URL if it's like .../instruments/AAPL/
    var parts = instrumentUrl.split('/').where((s) => s.isNotEmpty).toList();
    var symbol = parts.last;
    final instruments = await yahooService.getInstruments([symbol]);
    if (instruments.isNotEmpty) {
      store.add(instruments[0]);
      return instruments[0];
    }
    throw Exception('Failed to load instrument from Yahoo: $symbol');
  }

  @override
  Future<Instrument?> getInstrumentBySymbol(
      BrokerageUser user, InstrumentStore store, String symbol) async {
    final instruments = await yahooService.getInstruments([symbol]);
    if (instruments.isNotEmpty) {
      store.add(instruments[0]);
      return instruments[0];
    }
    return null;
  }

  @override
  Future<List<Instrument>> getInstrumentsByIds(
      BrokerageUser user, InstrumentStore store, List<String> ids) async {
    if (ids.isEmpty) return [];
    final instruments = await yahooService.getInstruments(ids);
    for (var i in instruments) {
      store.add(i);
    }
    return instruments;
  }

  @override
  Future<List<Quote>> getQuoteByIds(
      BrokerageUser user, QuoteStore store, List<String> symbols,
      {bool fromCache = true}) async {
    if (symbols.isEmpty) return [];
    try {
      final quotes = await yahooService.getQuotesByIds(symbols);
      for (var q in quotes) {
        store.add(q);
      }
      return quotes;
    } catch (e) {
      debugPrint('Error fetching quotes from Yahoo: $e');
      return [];
    }
  }

  @override
  Future<Quote> getQuote(
      BrokerageUser user, QuoteStore store, String symbol) async {
    try {
      final quote = await yahooService.getQuote(symbol);
      store.add(quote);
      return quote;
    } catch (e) {
      debugPrint('Error fetching quote from Yahoo: $e');
      rethrow;
    }
  }

  @override
  Future<Quote> refreshQuote(
      BrokerageUser user, QuoteStore store, String symbol) async {
    return getQuote(user, store, symbol);
  }

  @override
  Future<List<InstrumentPosition>> refreshPositionQuote(BrokerageUser user,
      InstrumentPositionStore store, QuoteStore quoteStore) async {
    final symbols = store.items
        .map((e) => e.instrumentObj?.symbol ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
    if (symbols.isNotEmpty) {
      await getQuoteByIds(user, quoteStore, symbols);
    }
    return store.items.toList();
  }

  @override
  Future<List<Fundamentals>> getFundamentalsById(BrokerageUser user,
      List<String> instruments, InstrumentStore store) async {
    if (instruments.isEmpty) return [];
    return yahooService.getFundamentals(instruments);
  }

  @override
  Future<Fundamentals> getFundamentals(
      BrokerageUser user, Instrument instrumentObj) async {
    final results = await yahooService.getFundamentals([instrumentObj.symbol]);
    if (results.isNotEmpty) {
      return results[0];
    }
    throw Exception('Fundamentals not found for ${instrumentObj.symbol}');
  }

  @override
  Future<PortfolioHistoricals> getPortfolioHistoricals(
      BrokerageUser user,
      PortfolioHistoricalsStore store,
      String account,
      Bounds chartBoundsFilter,
      ChartDateSpan chartDateSpanFilter) async {
    final userId = auth.currentUser?.uid ??
        user.userInfo?.id ??
        user.userName ??
        'default_paper_user';
    final paperAccountDoc = await _firestoreService.getPaperAccountDoc(userId);
    final data = paperAccountDoc.data() ?? {};
    final cashBalance = (data['cashBalance'] as num?)?.toDouble() ?? 100000.0;
    final initialCapital =
        (data['initialCapital'] as num?)?.toDouble() ?? 100000.0;

    // Include position market values in total balance
    double positionsValue = 0.0;

    // Stock positions
    final positions = await _firestoreService.listPaperPositions(userId);
    if (positions.isNotEmpty) {
      var symbols = positions
          .map((p) => p.instrumentObj?.symbol ?? '')
          .where((s) => s.isNotEmpty)
          .toList();

      // Fetch instruments for positions missing instrumentObj
      final positionsNeedingInstrument = positions
          .where((p) => p.instrumentObj == null && p.instrument.isNotEmpty)
          .toList();
      if (positionsNeedingInstrument.isNotEmpty) {
        final instrumentIds = positionsNeedingInstrument
            .map((p) => p.instrumentId)
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList();
        if (instrumentIds.isNotEmpty) {
          final instrumentStore = InstrumentStore();
          final fetchedById =
              await getInstrumentsByIds(user, instrumentStore, instrumentIds);
          for (var pos in positionsNeedingInstrument) {
            final match = fetchedById
                .firstWhereOrNull((i) => pos.instrument.contains(i.id));
            if (match != null) {
              pos.instrumentObj = match;
              if (!symbols.contains(match.symbol)) {
                symbols.add(match.symbol);
              }
            }
          }
        }
      }

      if (symbols.isNotEmpty) {
        final quoteStore = QuoteStore();
        await getQuoteByIds(user, quoteStore, symbols);
        for (var pos in positions) {
          if (pos.instrumentObj != null &&
              pos.instrumentObj!.quoteObj == null &&
              quoteStore.items.isNotEmpty) {
            final quote = quoteStore.items
                .firstWhereOrNull((q) => q.symbol == pos.instrumentObj!.symbol);
            if (quote != null) {
              pos.instrumentObj!.quoteObj = quote;
            }
          }
        }
      }

      for (var pos in positions) {
        positionsValue += pos.marketValue;
      }
    }

    // Option positions
    if (data['optionPositions'] != null) {
      final optionPositions = (data['optionPositions'] as List)
          .map((e) => OptionAggregatePosition.fromJson(e))
          .toList();
      for (var op in optionPositions) {
        positionsValue += op.marketValue;
      }
    }

    final balance = cashBalance + positionsValue;

    // Fetch historical snapshots from Firestore
    final historyData = await _firestoreService.getPaperHistory(userId);
    List<EquityHistorical> equityHistoricals = historyData.map((e) {
      // Handle Firestore Timestamp to String conversion for EquityHistorical.fromJson
      if (e['begins_at'] is Timestamp) {
        e['begins_at'] =
            (e['begins_at'] as Timestamp).toDate().toIso8601String();
      }
      return EquityHistorical.fromJson(e);
    }).toList();

    // Add current balance as the latest point
    equityHistoricals.add(EquityHistorical(
      balance,
      balance,
      balance,
      balance,
      balance,
      balance,
      DateTime.now(),
      0.0,
      'regular',
    ));

    final historicals = PortfolioHistoricals(
      balance,
      balance,
      balance,
      balance,
      DateTime.now().toIso8601String(),
      '1day',
      convertChartSpanFilter(chartDateSpanFilter),
      convertChartBoundsFilter(chartBoundsFilter),
      balance - initialCapital,
      equityHistoricals,
      false,
    );
    store.add(historicals);
    return historicals;
  }

  @override
  Future<PortfolioHistoricals> getPortfolioPerformance(
      BrokerageUser user, PortfolioHistoricalsStore store, String account,
      {Bounds chartBoundsFilter = Bounds.t24_7,
      ChartDateSpan chartDateSpanFilter = ChartDateSpan.day}) async {
    return getPortfolioHistoricals(
        user, store, account, chartBoundsFilter, chartDateSpanFilter);
  }

  @override
  Future<OptionHistoricals> getOptionHistoricals(
      BrokerageUser user, OptionHistoricalsStore store, List<String> ids,
      {Bounds chartBoundsFilter = Bounds.regular,
      ChartDateSpan chartDateSpanFilter = ChartDateSpan.day}) async {
    // For now, return empty or mock data for paper options
    final historicals = OptionHistoricals(
      convertChartBoundsFilter(chartBoundsFilter),
      '5minute',
      convertChartSpanFilter(chartDateSpanFilter),
      [],
      null,
      null,
      null,
      null,
      [],
    );
    store.add(historicals);
    return historicals;
  }

  @override
  Future<ForexHistoricals> getForexHistoricals(BrokerageUser user, String id,
      {Bounds chartBoundsFilter = Bounds.t24_7,
      ChartDateSpan chartDateSpanFilter = ChartDateSpan.day}) async {
    final interval = '5minute';
    final span = convertChartSpanFilter(chartDateSpanFilter);
    final bounds = convertChartBoundsFilter(chartBoundsFilter);

    return ForexHistoricals(
        bounds, interval, span, id, id, null, null, null, null, []);
  }

  @override
  Future<InstrumentHistoricals> getInstrumentHistoricals(BrokerageUser user,
      InstrumentHistoricalsStore store, String symbolOrInstrumentId,
      {bool includeInactive = true,
      Bounds chartBoundsFilter = Bounds.trading,
      ChartDateSpan chartDateSpanFilter = ChartDateSpan.day,
      String? chartInterval}) async {
    final interval = chartInterval ?? '5minute';
    final span = convertChartSpanFilter(chartDateSpanFilter);
    final bounds = convertChartBoundsFilter(chartBoundsFilter);

    // Map Robinhood span to Yahoo range
    String range = '1d';
    switch (span) {
      case 'day':
        range = '1d';
        break;
      case 'week':
        range = '5d';
        break;
      case 'month':
        range = '1mo';
        break;
      case '3month':
        range = '3mo';
        break;
      case 'year':
        range = '1y';
        break;
      case '5year':
        range = '5y';
        break;
      case 'all':
        range = 'max';
        break;
    }

    // Map Robinhood interval to Yahoo interval
    String yInterval = '5m';
    switch (interval) {
      case '5minute':
        yInterval = '5m';
        break;
      case '10minute':
        yInterval = '15m'; // Yahoo doesn't have 10m
        break;
      case 'hour':
        yInterval = '1h';
        break;
      case 'day':
        yInterval = '1d';
        break;
    }

    try {
      final data = await yahooService.getHistoricals(
          symbolOrInstrumentId, range, yInterval);
      final historicals = InstrumentHistoricals(
          '',
          symbolOrInstrumentId,
          interval,
          span,
          bounds,
          null,
          null,
          null,
          null,
          'https://api.robinhood.com/instruments/$symbolOrInstrumentId/',
          symbolOrInstrumentId,
          data);
      store.addOrUpdate(historicals);
      return historicals;
    } catch (e) {
      debugPrint('Error fetching historicals from Yahoo: $e');
      // Fallback to empty historicals if Yahoo fails
      final historicals = InstrumentHistoricals('', symbolOrInstrumentId,
          interval, span, bounds, null, null, null, null, '', null, []);
      store.addOrUpdate(historicals);
      return historicals;
    }
  }

  @override
  Future<FutureHistoricals?> getFuturesHistoricals(
      BrokerageUser user, String id,
      {Bounds chartBoundsFilter = Bounds.regular,
      ChartDateSpan chartDateSpanFilter = ChartDateSpan.day}) async {
    return null;
  }

  @override
  Stream<List<dynamic>> streamDividends(
      BrokerageUser user, InstrumentStore instrumentStore,
      {DocumentReference? userDoc}) {
    return Stream.value([]);
  }

  @override
  Future<List<dynamic>> getDividends(BrokerageUser user,
      DividendStore dividendStore, InstrumentStore instrumentStore,
      {String? instrumentId}) async {
    // Return empty results for paper trading for now
    return [];
  }

  @override
  Stream<List<dynamic>> streamInterests(
      BrokerageUser user, InstrumentStore instrumentStore,
      {DocumentReference? userDoc}) {
    return Stream.value([]);
  }

  @override
  Future<List<dynamic>> getInterests(
      BrokerageUser user, InterestStore interestStore,
      {String? instrumentId}) async {
    // Return empty results for paper trading for now
    return [];
  }

  @override
  Future<List<dynamic>> getNews(BrokerageUser user, String symbol) async => [];
  @override
  Future<dynamic> getRatings(BrokerageUser user, String instrumentId) async =>
      null;
  @override
  Future<dynamic> getRatingsOverview(
          BrokerageUser user, String instrumentId) async =>
      null;
  @override
  Future<List<dynamic>> getEarnings(
          BrokerageUser user, String instrumentId) async =>
      [];
  @override
  Future<List<dynamic>> getSimilar(
          BrokerageUser user, String instrumentId) async =>
      [];
  @override
  Future<List<dynamic>> getSplits(
          BrokerageUser user, Instrument instrumentObj) async =>
      [];

  @override
  Future<dynamic> search(BrokerageUser user, String query) async {
    return yahooService.search(query);
  }

  @override
  Future<List<MidlandMoversItem>> getMovers(BrokerageUser user,
      {String direction = "up"}) async {
    final movers = await yahooService.getMovers(direction: direction);
    return movers.map((q) {
      return MidlandMoversItem(
          'https://api.robinhood.com/instruments/${q['symbol']}/', // dummy
          q['symbol'] ?? '',
          DateTime.now(),
          (q['changePercent'] as num?)?.toDouble(),
          (q['price'] as num?)?.toDouble(),
          q['description'] ?? '');
    }).toList();
  }

  @override
  Future<List<Instrument>> getTopMovers(
      BrokerageUser user, InstrumentStore instrumentStore) async {
    final actives =
        await yahooService.getStockScreener(scrIds: 'most_actives', count: 10);
    final results = actives['finance']?['result']?[0]?['records'] ?? [];

    List<String> symbols = [];
    for (var q in results) {
      if (q['ticker'] != null) symbols.add(q['ticker']);
    }

    if (symbols.isEmpty) return [];

    final quotes = await yahooService.getQuotesByIds(symbols);
    final mapQuotes = {for (var q in quotes) q.symbol.toUpperCase(): q};

    List<Instrument> instruments = [];
    for (var symbol in symbols) {
      final instrument =
          await getInstrumentBySymbol(user, instrumentStore, symbol);
      if (instrument != null) {
        instrument.quoteObj = mapQuotes[symbol.toUpperCase()];
        instruments.add(instrument);
      }
    }
    return instruments;
  }

  @override
  Future<List<Instrument>> getListMostPopular(
      BrokerageUser user, InstrumentStore instrumentStore) async {
    final popular =
        await yahooService.getStockScreener(scrIds: 'most_actives', count: 10);
    final results = popular['finance']?['result']?[0]?['records'] ?? [];

    List<String> symbols = [];
    for (var q in results) {
      if (q['ticker'] != null) symbols.add(q['ticker']);
    }

    if (symbols.isEmpty) return [];

    final quotes = await yahooService.getQuotesByIds(symbols);
    final mapQuotes = {for (var q in quotes) q.symbol.toUpperCase(): q};

    List<Instrument> instruments = [];
    for (var symbol in symbols) {
      final instrument =
          await getInstrumentBySymbol(user, instrumentStore, symbol);
      if (instrument != null) {
        instrument.quoteObj = mapQuotes[symbol.toUpperCase()];
        instruments.add(instrument);
      }
    }
    return instruments;
  }

  @override
  Stream<List<Watchlist>> streamLists(BrokerageUser user,
      InstrumentStore instrumentStore, QuoteStore quoteStore) {
    return Stream.value([]);
  }

  @override
  Future<List<dynamic>> getLists(
          BrokerageUser user, String instrumentId) async =>
      [];
  @override
  Stream<Watchlist> streamList(BrokerageUser user,
      InstrumentStore instrumentStore, QuoteStore quoteStore, String key,
      {String ownerType = "custom"}) {
    throw UnimplementedError();
  }

  @override
  Future<Watchlist> getList(String key, BrokerageUser user,
      {String ownerType = "custom"}) async {
    throw UnimplementedError();
  }

  @override
  Future<List<Watchlist>> getAllLists(BrokerageUser user) async => [];
  @override
  Future<void> addToList(
      BrokerageUser user, String listId, String instrumentId) async {}
  @override
  Future<void> removeFromList(
      BrokerageUser user, String listId, String instrumentId) async {}
  @override
  Future<void> createList(BrokerageUser user, String name,
      {String? emoji}) async {}
  @override
  Future<void> deleteList(BrokerageUser user, String listId) async {}

  @override
  Stream<List<InstrumentOrder>> streamPositionOrders(BrokerageUser user,
      InstrumentOrderStore store, InstrumentStore instrumentStore,
      {DocumentReference? userDoc}) {
    final userId = userDoc?.id ??
        auth.currentUser?.uid ??
        user.userInfo?.id ??
        user.userName ??
        'default_paper_user';
    return _firestoreService.streamPaperOrders(userId).map(
        (list) => list.map((d) => InstrumentOrder.fromPaperJson(d)).toList());
  }

  @override
  Stream<List<OptionOrder>> streamOptionOrders(
      BrokerageUser user, OptionOrderStore store,
      {DocumentReference? userDoc}) {
    return Stream.value([]);
  }

  @override
  Future<List<OptionOrder>> getOptionOrders(
          BrokerageUser user, OptionOrderStore store, String chainId) async =>
      [];
  @override
  Future<List<InstrumentOrder>> getInstrumentOrders(BrokerageUser user,
          InstrumentOrderStore store, List<String> instrumentUrls) async =>
      [];

  @override
  Future<dynamic> placeInstrumentOrder(
      BrokerageUser user,
      Account account,
      Instrument instrument,
      String symbol,
      String side,
      double? price,
      int quantity,
      {String type = 'limit',
      String trigger = 'immediate',
      double? stopPrice,
      String timeInForce = 'gtc',
      Map<String, dynamic>? trailingPeg}) async {
    final userId = auth.currentUser?.uid ??
        user.userInfo?.id ??
        user.userName ??
        'default_paper_user';

    final orderMap = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'symbol': symbol,
      'side': side,
      'type': type,
      'quantity': quantity.toDouble(),
      'price': price,
      'state': 'filled', // Paper trades are immediately filled for now
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'instrument': instrument.url,
      'account': account.url,
      'trigger': trigger,
      'time_in_force': timeInForce,
    };

    await _firestoreService.createPaperOrder(userId, orderMap);

    if (side == 'buy') {
      final posMap = {
        'url': 'https://api.robinhood.com/positions/paper/$symbol/',
        'instrument': instrument.url,
        'account': account.url,
        'account_number': account.accountNumber,
        'quantity': quantity.toDouble(),
        'average_buy_price': price,
        'pending_average_buy_price': price,
        'intraday_average_buy_price': price,
        'intraday_quantity': quantity.toDouble(),
        'updated_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'instrument_obj': instrument.toJson(),
      };
      await _firestoreService.createPaperPosition(userId, posMap);

      final paperAccountDoc =
          await _firestoreService.getPaperAccountDoc(userId);
      final data = paperAccountDoc.data() ?? {};
      final currentBalance =
          (data['cashBalance'] as num?)?.toDouble() ?? 100000.0;
      final cost = (price ?? 0) * quantity;
      await _firestoreService
          .updatePaperAccount(userId, {'cashBalance': currentBalance - cost});
    } else if (side == 'sell') {
      final paperAccountDoc =
          await _firestoreService.getPaperAccountDoc(userId);
      final data = paperAccountDoc.data() ?? {};
      final currentBalance =
          (data['cashBalance'] as num?)?.toDouble() ?? 100000.0;
      final gain = (price ?? 0) * quantity;
      await _firestoreService
          .updatePaperAccount(userId, {'cashBalance': currentBalance + gain});
    }

    return {'status': 'success', 'order_id': orderMap['id']};
  }

  @override
  Future<dynamic> placeOptionsOrder(
      BrokerageUser user,
      Account account,
      OptionInstrument optionInstrument,
      String side,
      String positionEffect,
      String creditOrDebit,
      double price,
      int quantity,
      {String type = 'limit',
      String trigger = 'immediate',
      double? stopPrice,
      String timeInForce = 'gtc',
      Map<String, dynamic>? trailingPeg}) async {
    throw UnimplementedError();
  }

  @override
  Future<dynamic> placeMultiLegOptionsOrder(
      BrokerageUser user,
      Account account,
      List<Map<String, dynamic>> legs,
      String creditOrDebit,
      double price,
      int quantity,
      {String type = 'limit',
      String trigger = 'immediate',
      String timeInForce = 'gtc'}) async {
    throw UnimplementedError();
  }

  @override
  Future<List<ForexOrder>> getForexOrders(BrokerageUser user) async => [];

  @override
  Future<dynamic> placeForexOrder(BrokerageUser user, String pairId,
      String side, double? price, double quantity,
      {String type = 'market',
      String timeInForce = 'gtc',
      double? stopPrice}) async {
    throw UnimplementedError();
  }

  @override
  Future<dynamic> cancelOrder(BrokerageUser user, String cancel) async {
    return {'status': 'success'};
  }
}
