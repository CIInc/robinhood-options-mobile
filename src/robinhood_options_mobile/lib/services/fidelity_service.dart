import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide UserInfo;
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
import 'package:robinhood_options_mobile/model/dividend_store.dart';
import 'package:robinhood_options_mobile/model/forex_holding.dart';
import 'package:robinhood_options_mobile/model/forex_holding_store.dart';
import 'package:robinhood_options_mobile/model/forex_quote.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_order.dart';
import 'package:robinhood_options_mobile/model/instrument_order_store.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/option_leg.dart';
import 'package:robinhood_options_mobile/model/option_marketdata.dart';
import 'package:robinhood_options_mobile/model/option_order.dart';
import 'package:robinhood_options_mobile/model/option_order_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/option_instrument_store.dart';
import 'package:robinhood_options_mobile/model/portfolio.dart';
import 'package:robinhood_options_mobile/model/portfolio_store.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';
import 'package:robinhood_options_mobile/model/user_info.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/model/user.dart' as app_user;
import 'package:robinhood_options_mobile/model/fundamentals.dart';
import 'package:robinhood_options_mobile/services/yahoo_service.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals_store.dart';
import 'package:robinhood_options_mobile/model/option_chain.dart';
import 'package:robinhood_options_mobile/model/option_event.dart';
import 'package:robinhood_options_mobile/model/option_event_store.dart';
import 'package:robinhood_options_mobile/model/option_historicals.dart';
import 'package:robinhood_options_mobile/model/option_historicals_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals_store.dart';
import 'package:robinhood_options_mobile/model/watchlist.dart';
import 'package:robinhood_options_mobile/model/midlands_movers_item.dart';
import 'package:robinhood_options_mobile/model/forex_order.dart';
import 'package:robinhood_options_mobile/model/interest_store.dart';
import 'package:robinhood_options_mobile/model/forex_historicals.dart';
import 'package:robinhood_options_mobile/model/future_historicals.dart';

class FidelityService implements IBrokerageService {
  @override
  String name = 'Fidelity';
  @override
  Uri endpoint = Uri.parse('manual'); // No API endpoint
  @override
  Uri authEndpoint = Uri.parse('manual');
  @override
  Uri tokenEndpoint = Uri.parse('manual');
  @override
  String clientId = 'fidelity_manual';
  @override
  String redirectUrl = 'manual';

  // --- IBrokerageService Implementation (Stubs for Manual Service) ---

  @override
  Future<UserInfo?> getUser(BrokerageUser user) async {
    // Return a dummy user info or null
    return UserInfo(
        url: 'fidelity_user',
        id: 'fidelity_user_id',
        idInfo: 'fidelity_user_id',
        username: 'Fidelity User',
        email: 'user@fidelity.com',
        firstName: 'Fidelity',
        lastName: 'User',
        profileName: 'Fidelity User',
        createdAt: DateTime.now());
  }

  @override
  Future<List<Account>> getAccounts(BrokerageUser user, AccountStore store,
      PortfolioStore? portfolioStore, OptionPositionStore? optionPositionStore,
      {InstrumentPositionStore? instrumentPositionStore,
      DocumentReference? userDoc}) async {
    // Try to fetch latest from Firestore if provided (ensures fresh data after import)
    if (userDoc != null) {
      try {
        // Safe to cast because userDoc in HomePage is typed DocumentReference<User>
        // But here it is passed as DocumentReference? (raw or dynamic in signature?)
        // The signature says DocumentReference? which is raw.
        // We know standard is DocumentReference<User> in this app context usually,
        // but we should be careful.
        // Let's use get() and try to parse.
        var snapshot = await userDoc.get();
        if (snapshot.exists) {
          app_user.User? u;
          if (snapshot.data() is app_user.User) {
            u = snapshot.data() as app_user.User;
          } else if (snapshot.data() is Map<String, dynamic>) {
            u = app_user.User.fromJson(snapshot.data() as Map<String, dynamic>);
          }

          if (u != null) {
            var distinctBrokerageUsers = u.brokerageUsers
                .where((b) => b.source == BrokerageSource.fidelity);
            if (distinctBrokerageUsers.isNotEmpty) {
              var freshUser = distinctBrokerageUsers.first;
              if (freshUser.accounts.isNotEmpty) {
                return freshUser.accounts;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error fetching fresh user in getAccounts: $e');
      }
    }

    // If we have stored accounts, return them
    if (user.accounts.isNotEmpty) {
      return user.accounts;
    }

    // If we have positions, we can reconstruct the account estimates
    if (instrumentPositionStore != null &&
        instrumentPositionStore.items.isNotEmpty) {
      Map<String, double> accountCash = {};
      Set<String> accountNumbers = {};

      for (var pos in instrumentPositionStore.items) {
        // Collect unique account numbers
        if (pos.account.isNotEmpty) {
          accountNumbers.add(pos.account);
        }

        // Calculate cash from Swaps/Money Market positions
        if (pos.instrumentObj != null &&
            pos.instrumentObj!.symbol.endsWith('**')) {
          String acc = pos.account;
          if (acc.isEmpty) acc = 'Fidelity-Imported';
          accountCash[acc] = (accountCash[acc] ?? 0) + pos.marketValue;
        }
      }

      if (accountNumbers.isNotEmpty) {
        return accountNumbers.map((accNum) {
          double cash = accountCash[accNum] ?? 0;
          return Account(
              'fidelity_account_url_$accNum', // url
              cash, // portfolioCash
              accNum, // accountNumber
              'cash', // type
              cash, // buyingPower
              '3', // optionLevel
              0, // cashHeldForOptionsCollateral
              0, // unsettledDebit
              0 // settledAmountBorrowed
              );
        }).toList();
      }
    }

    // Return a dummy account if no data
    return [
      Account(
          'fidelity_account_url', // url
          0, // portfolioCash
          'Fidelity-Imported', // accountNumber
          'cash', // type
          0, // buyingPower
          '3', // optionLevel
          0, // cashHeldForOptionsCollateral
          0, // unsettledDebit
          0 // settledAmountBorrowed
          )
    ];
  }

  @override
  Future<List<Portfolio>> getPortfolios(
      BrokerageUser user, PortfolioStore store) async {
    // Return a dummy portfolio
    return [
      Portfolio(
          'fidelity_portfolio_url', // url
          'fidelity_account_url', // account
          DateTime.now(), // startDate
          0, // marketValue
          0, // equity
          0, // extendedHoursMarketValue
          0, // extendedHoursEquity
          0, // extendedHoursPortfolioEquity
          0, // lastCoreMarketValue
          0, // lastCoreEquity
          0, // lastCorePortfolioEquity
          0, // excessMargin
          0, // excessMaintenance
          0, // excessMarginWithUnclearedDeposits
          0, // excessMaintenanceWithUnclearedDeposits
          0, // equityPreviousClose
          0, // portfolioEquityPreviousClose
          0, // adjustedEquityPreviousClose
          0, // adjustedPortfolioEquityPreviousClose
          0, // withdrawableAmount
          0, // unwithdrawableDeposits
          0, // unwithdrawableGrants
          DateTime.now() // updatedAt
          )
    ];
  }

  @override
  Future<InstrumentPositionStore> getStockPositionStore(
      BrokerageUser user,
      InstrumentPositionStore store,
      InstrumentStore instrumentStore,
      QuoteStore quoteStore,
      {bool nonzero = true,
      DocumentReference? userDoc}) async {
    if (userDoc != null) {
      try {
        var firestoreService = FirestoreService();
        var positions = await firestoreService.getInstrumentPositions(userDoc);
        var manualPositions =
            positions.where((p) => p.url.startsWith('manual_pos')).toList();
        if (manualPositions.isNotEmpty) {
          /*
          var instrumentUrls =
              manualPositions.map((p) => p.instrument).toSet().toList();
          List<Instrument> instruments = [];
          for (var i = 0; i < instrumentUrls.length; i += 10) {
            var chunk = instrumentUrls.sublist(
                i,
                (i + 10) < instrumentUrls.length
                    ? i + 10
                    : instrumentUrls.length);
            var snapshot = await FirebaseFirestore.instance
                .collection(firestoreService.instrumentCollectionName)
                .where('url', whereIn: chunk)
                .get();
            instruments.addAll(
                snapshot.docs.map((d) => Instrument.fromJson(d.data())));
          }
          var instrumentMap = {for (var i in instruments) i.url: i};
          */
          for (var p in manualPositions) {
            /*
            if (instrumentMap.containsKey(p.instrument)) {
              p.instrumentObj = instrumentMap[p.instrument];
            }
            */
            store.addOrUpdate(p);
          }
        }
      } catch (e) {
        debugPrint('Error loading fidelity stock positions: $e');
      }
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
    // Basic Stub
    return ForexQuote(
        null, null, null, null, null, null, id, id, null, DateTime.now());
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
    if (userDoc != null) {
      try {
        var firestoreService = FirestoreService();
        var positions = await firestoreService.getOptionPositions(userDoc);
        var manualPositions =
            positions.where((p) => p.id.startsWith('manual_op_')).toList();
        if (manualPositions.isNotEmpty) {
          /*
          Set<String> optUrls = {};
          for (var p in manualPositions) {
            for (var leg in p.legs) {
              if (leg.option.startsWith('manual_opt_inst')) {
                optUrls.add(leg.option);
              }
            }
          }

          var optionInstruments = await firestoreService
              .getOptionInstrumentsByUrls(optUrls.toList());
          var optMap = {for (var o in optionInstruments) o.url: o};
          */

          for (var p in manualPositions) {
            /*
            if (p.legs.isNotEmpty) {
              var url = p.legs.first.option;
              if (optMap.containsKey(url)) {
                p.optionInstrument = optMap[url];
              }
            }
            */
            var exists = store.items.any((existing) => existing.id == p.id);
            if (!exists) {
              store.add(p);
            }
          }
        }
      } catch (e) {
        debugPrint('Error loading fidelity option positions: $e');
      }
    }
    return store;
  }

  @override
  Future<List<OptionAggregatePosition>> getAggregateOptionPositions(
      BrokerageUser user,
      {bool nonzero = true}) async {
    return [];
  }

  @override
  Stream<List<OptionInstrument>> streamOptionInstruments(
      BrokerageUser user,
      OptionInstrumentStore store,
      Instrument instrument,
      String? expirationDates,
      String? type,
      {String? state = "active",
      bool includeMarketData = false}) async* {
    yield [];
  }

  @override
  Future<List<OptionInstrument>> getOptionInstrumentByIds(
      BrokerageUser user, List<String> ids) async {
    return [];
  }

  @override
  Future<OptionMarketData?> getOptionMarketData(
      BrokerageUser user, OptionInstrument optionInstrument) async {
    return null;
  }

  @override
  Future<List<OptionMarketData>> getOptionMarketDataByIds(
      BrokerageUser user, List<String> ids) async {
    return [];
  }

  @override
  Future<List<ForexOrder>> getForexOrders(BrokerageUser user) async {
    return [];
  }

  @override
  Future<dynamic> placeForexOrder(BrokerageUser user, String pairId,
      String side, double? price, double quantity,
      {String type = 'market',
      String timeInForce = 'gtc',
      double? stopPrice}) async {
    throw UnimplementedError();
  }

  @override
  Future<List<OptionAggregatePosition>> refreshOptionMarketData(
      BrokerageUser user,
      OptionPositionStore optionPositionStore,
      OptionInstrumentStore optionInstrumentStore) async {
    return [];
  }

  @override
  Future<List<OptionEvent>> getOptionEventsByInstrumentUrl(
      BrokerageUser user, String instrumentUrl) async {
    return [];
  }

  @override
  Stream<List<OptionEvent>> streamOptionEvents(
      BrokerageUser user, OptionEventStore store,
      {int pageSize = 20, DocumentReference? userDoc}) async* {
    if (userDoc != null) {
      yield* userDoc
          .collection(FirestoreService().optionEventCollectionName)
          .orderBy('event_date', descending: true)
          .snapshots()
          .map((snapshot) {
        var list = snapshot.docs
            .map((doc) => OptionEvent.fromJson(doc.data()))
            .toList();
        for (var item in list) {
          store.addOrUpdate(item);
        }
        return list;
      });
    } else {
      yield [];
    }
  }

  @override
  Future<List<OptionChain>> getOptionChainsByIds(
      BrokerageUser user, List<String> ids) async {
    return [];
  }

  @override
  Future<OptionChain> getOptionChains(BrokerageUser user, String id) async {
    // Return empty or dummy
    return OptionChain(
        id, id, false, null, [], 100, MinTicks(null, null, null));
  }

  @override
  Future<Instrument> getInstrument(
      BrokerageUser user, InstrumentStore store, String instrumentUrl) async {
    // We assume instrumentUrl == symbol for manual entries
    return Instrument.fromJson(
        {'symbol': instrumentUrl, 'description': instrumentUrl});
  }

  @override
  Future<Instrument?> getInstrumentBySymbol(
      BrokerageUser user, InstrumentStore store, String symbol) async {
    return Instrument.fromJson({'symbol': symbol, 'description': symbol});
  }

  @override
  Future<List<Instrument>> getInstrumentsByIds(
      BrokerageUser user, InstrumentStore store, List<String> ids) async {
    return ids
        .map((id) => Instrument.fromJson({'symbol': id, 'description': id}))
        .toList();
  }

  @override
  Future<List<Quote>> getQuoteByIds(
      BrokerageUser user, QuoteStore store, List<String> symbols,
      {bool fromCache = true}) async {
    // Basic fallback using Yahoo
    List<Quote> quotes = [];
    final yahooService = YahooService();
    // YahooService usually fetches single quote, maybe loop or check if it supports list
    // getQuote in YahooService takes single symbol.
    for (var sym in symbols) {
      try {
        var q = await yahooService.getQuote(sym);
        quotes.add(q);
      } catch (e) {
        // ignore
      }
    }
    return quotes;
  }

  @override
  Future<Quote> getQuote(
      BrokerageUser user, QuoteStore store, String symbol) async {
    final yahooService = YahooService();
    return await yahooService.getQuote(symbol);
  }

  @override
  Future<Quote> refreshQuote(
      BrokerageUser user, QuoteStore store, String symbol) async {
    return await getQuote(user, store, symbol);
  }

  @override
  Future<List<InstrumentPosition>> refreshPositionQuote(BrokerageUser user,
      InstrumentPositionStore store, QuoteStore quoteStore) async {
    return [];
  }

  @override
  Future<List<Fundamentals>> getFundamentalsById(BrokerageUser user,
      List<String> instruments, InstrumentStore store) async {
    return [];
  }

  @override
  Future<Fundamentals> getFundamentals(
      BrokerageUser user, Instrument instrumentObj) async {
    // Basic Stub / No-Op to prevent crash + try Yahoo if possible
    /*
    try {
      final yahooService = YahooService();
      // return await yahooService.getFundamentals(instrumentObj.symbol);
      // YahooService in this codebase doesn't seem to expose full fundamentals easily yet
    } catch (e) {}
    */
    return Fundamentals(description: 'Fidelity Position');
  }

  @override
  Future<PortfolioHistoricals> getPortfolioHistoricals(
      BrokerageUser user,
      PortfolioHistoricalsStore store,
      String account,
      Bounds chartBoundsFilter,
      ChartDateSpan chartDateSpanFilter) async {
    await Future.delayed(Duration.zero);
    var rtn = convertChartSpanFilterWithInterval(chartDateSpanFilter);
    String rhSpan = rtn[0];
    String rhInterval = rtn[1];
    String bounds = convertChartBoundsFilter(chartBoundsFilter);

    var hist = PortfolioHistoricals(
        0, 0, 0, 0, null, rhInterval, rhSpan, bounds, 0, [], false);
    store.set(hist);
    return hist;
  }

  @override
  Future<PortfolioHistoricals> getPortfolioPerformance(
      BrokerageUser user, PortfolioHistoricalsStore store, String account,
      {Bounds chartBoundsFilter = Bounds.t24_7,
      ChartDateSpan chartDateSpanFilter = ChartDateSpan.day}) async {
    await Future.delayed(Duration.zero);
    var rtn = convertChartSpanFilterWithInterval(chartDateSpanFilter);
    String rhSpan = rtn[0];
    String rhInterval = rtn[1];
    String bounds = convertChartBoundsFilter(chartBoundsFilter);

    var hist = PortfolioHistoricals(
        0, 0, 0, 0, null, rhInterval, rhSpan, bounds, 0, [], false);
    store.set(hist);
    return hist;
  }

  @override
  Future<OptionHistoricals> getOptionHistoricals(
      BrokerageUser user, OptionHistoricalsStore store, List<String> ids,
      {Bounds chartBoundsFilter = Bounds.regular,
      ChartDateSpan chartDateSpanFilter = ChartDateSpan.day}) async {
    await Future.delayed(Duration.zero);
    var rtn = convertChartSpanFilterWithInterval(chartDateSpanFilter);
    String rhSpan = rtn[0];
    String rhInterval = rtn[1];
    String bounds = convertChartBoundsFilter(chartBoundsFilter);

    // Create dummy legs so the Store can index them
    List<Leg> legs = ids.map((id) => Leg(id, "1", "call")).toList();

    var hist = OptionHistoricals(
        bounds, rhInterval, rhSpan, legs, null, null, null, null, []);

    if (legs.isNotEmpty) {
      // OptionHistoricalsStore uses update() (returns bool) or add()
      if (!store.update(hist)) {
        store.add(hist);
      }
    }
    return hist;
  }

  @override
  Future<InstrumentHistoricals> getInstrumentHistoricals(BrokerageUser user,
      InstrumentHistoricalsStore store, String symbolOrInstrumentId,
      {bool includeInactive = true,
      Bounds chartBoundsFilter = Bounds.trading,
      ChartDateSpan chartDateSpanFilter = ChartDateSpan.day,
      String? chartInterval}) async {
    await Future.delayed(Duration.zero);
    final yahooService = YahooService();

    // Get Robinhood standard values first
    var rtn = convertChartSpanFilterWithInterval(chartDateSpanFilter);
    String rhSpan = rtn[0];
    String rhInterval = rtn[1];

    if (chartInterval != null) {
      rhInterval = chartInterval;
    }

    // Map to Yahoo values
    String range = '1d';
    String interval = '5m';

    // Minimal mapping
    switch (chartDateSpanFilter) {
      case ChartDateSpan.hour:
        range = '1d'; // Yahoo min is 1d
        interval = '2m'; // Yahoo min is 1m, using 2m or 5m
        break;
      case ChartDateSpan.day:
        range = '1d';
        interval = '5m';
        break;
      case ChartDateSpan.week:
        range = '5d';
        interval = '15m'; // Yahoo supports 15m
        break;
      case ChartDateSpan.month:
        range = '1mo';
        interval = '60m'; // 1h
        break;
      case ChartDateSpan.month_3:
        range = '3mo';
        interval = '1d';
        break;
      case ChartDateSpan.ytd:
        range = 'ytd';
        interval = '1d';
        break;
      case ChartDateSpan.year:
        range = '1y';
        interval = '1d';
        break;
      case ChartDateSpan.year_5:
        range = '5y';
        interval = '1wk';
        break;
      case ChartDateSpan.all:
        range = 'max';
        interval = '1mo';
        break;
      default:
        range = '1d';
        interval = '5m';
    }

    try {
      // getHistoricals returns List<InstrumentHistorical>
      var candles = await yahooService.getHistoricals(
          symbolOrInstrumentId, range, interval);

      var bounds = convertChartBoundsFilter(chartBoundsFilter);

      // We need to construct InstrumentHistoricals manually
      var hist = InstrumentHistoricals(
          symbolOrInstrumentId,
          symbolOrInstrumentId,
          rhInterval,
          rhSpan,
          bounds,
          null,
          null,
          null,
          null,
          symbolOrInstrumentId,
          symbolOrInstrumentId,
          candles);

      store.set(hist);
      return hist;
    } catch (e) {
      debugPrint('Error fetching yahoo historicals: $e');

      var bounds = convertChartBoundsFilter(chartBoundsFilter);

      var hist = InstrumentHistoricals(
          symbolOrInstrumentId,
          symbolOrInstrumentId,
          rhInterval,
          rhSpan,
          bounds,
          null,
          null,
          null,
          null,
          symbolOrInstrumentId,
          symbolOrInstrumentId, []);

      store.set(hist);
      return hist;
    }
  }

  @override
  Future<ForexHistoricals> getForexHistoricals(BrokerageUser user, String id,
      {Bounds chartBoundsFilter = Bounds.t24_7,
      ChartDateSpan chartDateSpanFilter = ChartDateSpan.day}) async {
    // Stub
    return ForexHistoricals(
        'regular', '5m', 'day', id, id, null, null, null, null, []);
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
      {DocumentReference? userDoc}) async* {
    if (userDoc != null) {
      yield* userDoc
          .collection(FirestoreService().dividendCollectionName)
          .orderBy('payable_date', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
    } else {
      yield [];
    }
  }

  @override
  Future<List<dynamic>> getDividends(BrokerageUser user,
      DividendStore dividendStore, InstrumentStore instrumentStore,
      {String? instrumentId}) async {
    return [];
  }

  @override
  Stream<List<dynamic>> streamInterests(
      BrokerageUser user, InstrumentStore instrumentStore,
      {DocumentReference? userDoc}) async* {
    if (userDoc != null) {
      yield* userDoc
          .collection(FirestoreService().interestCollectionName)
          .orderBy('pay_date', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
    } else {
      yield [];
    }
  }

  @override
  Future<List<dynamic>> getInterests(
      BrokerageUser user, InterestStore dividendStore,
      {String? instrumentId}) async {
    return [];
  }

  @override
  Future<List<dynamic>> getNews(BrokerageUser user, String symbol) async {
    return [];
  }

  @override
  Future<dynamic> getRatings(BrokerageUser user, String instrumentId) async {
    return null;
  }

  @override
  Future<dynamic> getRatingsOverview(
      BrokerageUser user, String instrumentId) async {
    return null;
  }

  @override
  Future<List<dynamic>> getEarnings(
      BrokerageUser user, String instrumentId) async {
    return [];
  }

  @override
  Future<List<dynamic>> getSimilar(
      BrokerageUser user, String instrumentId) async {
    return [];
  }

  @override
  Future<List<dynamic>> getSplits(
      BrokerageUser user, Instrument instrumentObj) async {
    return [];
  }

  @override
  Future<dynamic> search(BrokerageUser user, String query) async {
    return [];
  }

  @override
  Future<List<MidlandMoversItem>> getMovers(BrokerageUser user,
      {String direction = "up"}) async {
    return [];
  }

  @override
  Future<List<Instrument>> getTopMovers(
      BrokerageUser user, InstrumentStore instrumentStore) async {
    return [];
  }

  @override
  Future<List<Instrument>> getListMostPopular(
      BrokerageUser user, InstrumentStore instrumentStore) async {
    return [];
  }

  @override
  Stream<List<Watchlist>> streamLists(BrokerageUser user,
      InstrumentStore instrumentStore, QuoteStore quoteStore) async* {
    yield [];
  }

  @override
  Future<List<dynamic>> getLists(
      BrokerageUser user, String instrumentId) async {
    return [];
  }

  @override
  Stream<Watchlist> streamList(BrokerageUser user,
      InstrumentStore instrumentStore, QuoteStore quoteStore, String key,
      {String ownerType = "custom"}) async* {
    yield Watchlist(
        key, key, 'custom', null, null, DateTime.now(), DateTime.now());
  }

  @override
  Future<Watchlist> getList(String key, BrokerageUser user,
      {String ownerType = "custom"}) async {
    return Watchlist(
        key, key, 'custom', null, null, DateTime.now(), DateTime.now());
  }

  @override
  Future<List<Watchlist>> getAllLists(BrokerageUser user) async {
    return [];
  }

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
      {DocumentReference? userDoc}) async* {
    if (userDoc != null) {
      yield* userDoc
          .collection(FirestoreService().instrumentOrderCollectionName)
          .orderBy('updated_at', descending: true)
          .snapshots()
          .map((snapshot) {
        var list = snapshot.docs
            .map((doc) => InstrumentOrder.fromJson(doc.data()))
            .toList();
        for (var item in list) {
          store.addOrUpdate(item);
        }
        return list;
      });
    } else {
      yield [];
    }
  }

  @override
  Stream<List<OptionOrder>> streamOptionOrders(
      BrokerageUser user, OptionOrderStore store,
      {DocumentReference? userDoc}) async* {
    if (userDoc != null) {
      yield* userDoc
          .collection(FirestoreService().optionOrderCollectionName)
          .orderBy('updated_at', descending: true)
          .snapshots()
          .map((snapshot) {
        var list = snapshot.docs
            .map((doc) => OptionOrder.fromJson(doc.data()))
            .toList();
        for (var item in list) {
          store.addOrUpdate(item);
        }
        return list;
      });
    } else {
      yield [];
    }
  }

  @override
  Future<List<OptionOrder>> getOptionOrders(
      BrokerageUser user, OptionOrderStore store, String chainId) async {
    return [];
  }

  @override
  Future<List<InstrumentOrder>> getInstrumentOrders(BrokerageUser user,
      InstrumentOrderStore store, List<String> instrumentUrls) async {
    return [];
  }

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
    throw UnimplementedError();
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
  Future<dynamic> cancelOrder(BrokerageUser user, String cancel) async {
    throw UnimplementedError();
  }

  // --- CSV Import Functionality (Ported from CsvImportService) ---

  Future<void> clearImportedData(BuildContext context) async {
    bool? shouldClear = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Reset Fidelity Data'),
          content: const Text(
              'Are you sure you want to clear all imported Fidelity data? This cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Reset Data'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (shouldClear != true) return;

    if (context.mounted) {
      Provider.of<InstrumentPositionStore>(context, listen: false)
          .removeWhere((p) => p.url.startsWith('manual_pos'));
      Provider.of<OptionPositionStore>(context, listen: false)
          .removeWhere((p) => p.id.startsWith('manual_op_'));
      Provider.of<InstrumentOrderStore>(context, listen: false)
          .removeWhere((o) => o.id.startsWith('manual_order_'));
      Provider.of<OptionOrderStore>(context, listen: false)
          .removeWhere((o) => o.id.startsWith('manual_ord_'));
      Provider.of<DividendStore>(context, listen: false)
          .removeWhere((d) => (d['id'] as String).startsWith('manual_div_'));
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final firestoreService = FirestoreService();
      final userDoc = firestoreService.userCollection.doc(user.uid);
      var batch = FirebaseFirestore.instance.batch();
      int batchCount = 0;

      // Delete Manual Instrument Positions
      final instSnapshot = await userDoc
          .collection(firestoreService.instrumentPositionCollectionName)
          .where('url', isGreaterThanOrEqualTo: 'manual_pos')
          .where('url', isLessThan: 'manual_pos\uf8ff')
          .get();

      for (var doc in instSnapshot.docs) {
        batch.delete(doc.reference);
        batchCount++;
        if (batchCount >= 500) {
          await batch.commit();
          batch = FirebaseFirestore.instance.batch();
          batchCount = 0;
        }
      }

      // Delete Manual Option Positions
      final optSnapshot = await userDoc
          .collection(firestoreService.optionPositionCollectionName)
          .where('id', isGreaterThanOrEqualTo: 'manual_op_')
          .where('id', isLessThan: 'manual_op_\uf8ff')
          .get();

      for (var doc in optSnapshot.docs) {
        batch.delete(doc.reference);
        batchCount++;
        if (batchCount >= 500) {
          await batch.commit();
          batch = FirebaseFirestore.instance.batch();
          batchCount = 0;
        }
      }

      // Delete Manual Instrument Orders
      final instOrderSnapshot = await userDoc
          .collection(firestoreService.instrumentOrderCollectionName)
          .where('id', isGreaterThanOrEqualTo: 'manual_order_')
          .where('id', isLessThan: 'manual_order_\uf8ff')
          .get();

      for (var doc in instOrderSnapshot.docs) {
        batch.delete(doc.reference);
        batchCount++;
        if (batchCount >= 500) {
          await batch.commit();
          batch = FirebaseFirestore.instance.batch();
          batchCount = 0;
        }
      }

      // Delete Manual Option Orders
      final optOrderSnapshot = await userDoc
          .collection(firestoreService.optionOrderCollectionName)
          .where('id', isGreaterThanOrEqualTo: 'manual_ord_')
          .where('id', isLessThan: 'manual_ord_\uf8ff')
          .get();

      for (var doc in optOrderSnapshot.docs) {
        batch.delete(doc.reference);
        batchCount++;
        if (batchCount >= 500) {
          await batch.commit();
          batch = FirebaseFirestore.instance.batch();
          batchCount = 0;
        }
      }

      // Delete Manual Dividends
      final divSnapshot = await userDoc
          .collection(firestoreService.dividendCollectionName)
          .where('id', isGreaterThanOrEqualTo: 'manual_div_')
          .where('id', isLessThan: 'manual_div_\uf8ff')
          .get();

      for (var doc in divSnapshot.docs) {
        batch.delete(doc.reference);
        batchCount++;
        if (batchCount >= 500) {
          await batch.commit();
          batch = FirebaseFirestore.instance.batch();
          batchCount = 0;
        }
      }

      if (batchCount > 0) {
        await batch.commit();
      }

      // Reset Account Balances (Cash)
      var userSnapshot = await userDoc.get();
      if (userSnapshot.exists) {
        var userModel = userSnapshot.data()!;
        try {
          var fidelityUser = userModel.brokerageUsers.firstWhere(
              (b) => b.source == BrokerageSource.fidelity,
              orElse: () => BrokerageUser(
                  BrokerageSource.fidelity, 'Fidelity Manual', null, null,
                  accounts: []));
          bool changed = false;
          for (int i = 0; i < fidelityUser.accounts.length; i++) {
            var acc = fidelityUser.accounts[i];
            if (acc.portfolioCash != 0) {
              fidelityUser.accounts[i] = Account(acc.url, 0.0,
                  acc.accountNumber, acc.type, 0.0, acc.optionLevel, 0.0, 0, 0);
              changed = true;
            }
          }

          if (changed) {
            await firestoreService.updateUser(userDoc, userModel);
            if (context.mounted) {
              var userStore =
                  Provider.of<BrokerageUserStore>(context, listen: false);
              userStore.addOrUpdate(fidelityUser);
            }
          }
        } catch (e) {
          debugPrint('Error resetting account balances: $e');
        }
      }

      // if (batchCount > 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cleared previously imported data.')),
        );
      }
      // } else {
      //   if (context.mounted) {
      //     ScaffoldMessenger.of(context).showSnackBar(
      //       const SnackBar(
      //           content: Text('No previous imported data found to clear.')),
      //     );
      //   }
      // }
    }
  }

  Future<void> importFidelityCsv(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        String? path = result.files.single.path;
        if (path == null) return;

        File file = File(path);
        // Fidelity CSVs can be funky encoded, but let's try utf8 first
        String content = await file.readAsString();
        // Normalize newlines to \n to ensure CsvToListConverter handles them correctly
        content = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
        final fields = const CsvToListConverter().convert(content, eol: '\n');

        if (fields.isEmpty) return;

        // Verify headers
        List<dynamic> headers = [];
        Map<String, int> headerMap = {};
        int dataStartRow = 1;

        // Find header row logic
        for (int i = 0; i < fields.length; i++) {
          List<dynamic> row = fields[i];
          if (row.isNotEmpty && row[0].toString() == 'Run Date') {
            headers = row;
            headerMap = {
              for (var j = 0; j < headers.length; j++)
                headers[j].toString().trim(): j
            };
            dataStartRow = i + 1;
            break;
          }
          if (row.isNotEmpty && row[0].toString() == 'Account Number') {
            headers = row;
            headerMap = {
              for (var j = 0; j < headers.length; j++)
                headers[j].toString().trim(): j
            };
            dataStartRow = i + 1;
            break;
          }
        }

        if (headerMap.isEmpty) {
          if (fields.isNotEmpty) {
            headers = fields.first;
            headerMap = {
              for (var i = 0; i < headers.length; i++)
                headers[i].toString().trim(): i
            };
          }
        }

        // Identify Account Column
        int? accountColIndex;
        int? accountNameColIndex;
        if (headerMap.containsKey('Account Number')) {
          accountColIndex = headerMap['Account Number'];
        }
        if (headerMap.containsKey('Account Name')) {
          accountNameColIndex = headerMap['Account Name'];
        }

        // Scan for unique accounts
        Map<String, String> distinctAccounts = {};
        if (accountColIndex != null) {
          for (int i = dataStartRow; i < fields.length; i++) {
            var row = fields[i];

            // Stop on empty row or disclaimer
            if (row.isEmpty) break;
            if (row.isNotEmpty &&
                (row[0].toString().isEmpty ||
                    row[0].toString().contains('The data'))) {
              break;
            }

            if (row.length <= accountColIndex) continue;
            String accNum = row[accountColIndex].toString().trim();
            if (accNum.isNotEmpty) {
              String display = accNum;
              if (accountNameColIndex != null &&
                  row.length > accountNameColIndex) {
                String accName = row[accountNameColIndex].toString().trim();
                if (accName.isNotEmpty) {
                  display = '$accName ($accNum)';
                }
              }
              distinctAccounts[accNum] = display;
            }
          }
        }

        List<String> selectedAccounts = distinctAccounts.keys.toList();
        if (distinctAccounts.length > 1) {
          // ignore: use_build_context_synchronously
          final result = await showDialog<List<String>>(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return _AccountSelectionDialog(
                  accounts: distinctAccounts.keys.toList(),
                  accountLabels: distinctAccounts);
            },
          );

          if (result == null || result.isEmpty) {
            return; // Cancelled
          }
          selectedAccounts = result;
        }

        // Detect File Type
        if (headerMap.containsKey('Run Date') &&
            headerMap.containsKey('Action')) {
          await _importHistory(context, fields, headerMap, dataStartRow,
              selectedAccounts, accountColIndex);
          return;
        }

        if (!headerMap.containsKey('Symbol') ||
            !headerMap.containsKey('Quantity') ||
            !headerMap.containsKey('Average Cost Basis')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Invalid CSV format - missing required columns')),
          );
          return;
        }

        int importedStocks = 0;
        int importedOptions = 0;
        List<InstrumentPosition> newStockPositions = [];
        List<OptionAggregatePosition> newOptionPositions = [];
        Map<String, double> accountCashBalances = {};

        for (int i = dataStartRow; i < fields.length; i++) {
          List<dynamic> row = fields[i];

          // Stop on empty row or disclaimer
          if (row.isEmpty) break;
          if (row.isNotEmpty &&
              (row[0].toString().isEmpty ||
                  row[0].toString().contains('The data'))) {
            break;
          }

          if (row.length < headerMap.length) continue;

          // Account Filtering
          String accountNumber = 'manual_account';
          if (accountColIndex != null && row.length > accountColIndex) {
            String acc = row[accountColIndex].toString().trim();
            if (selectedAccounts.isNotEmpty &&
                !selectedAccounts.contains(acc)) {
              continue;
            }
            if (acc.isNotEmpty) accountNumber = acc;
          }

          String symbol = row[headerMap['Symbol']!].toString().trim();
          var quantityStr = row[headerMap['Quantity']!].toString();
          double quantity = double.tryParse(quantityStr) ?? 0;

          // Handle Cash Positions (e.g. FCASH**, SPAXX**)
          if (symbol.endsWith('**')) {
            if (quantity == 0) {
              if (headerMap.containsKey('Current Value')) {
                String cvStr =
                    _cleanCurrency(row[headerMap['Current Value']!].toString());
                quantity = double.tryParse(cvStr) ?? 0;
              }
            }
            accountCashBalances[accountNumber] =
                (accountCashBalances[accountNumber] ?? 0) + quantity;
            continue;
          } else {
            if (quantityStr.isEmpty) continue;
          }

          String costBasisStr =
              _cleanCurrency(row[headerMap['Average Cost Basis']!].toString());
          double averageCost = double.tryParse(costBasisStr) ?? 0;

          double lastPrice = 0;
          if (headerMap.containsKey('Last Price')) {
            String lpStr =
                _cleanCurrency(row[headerMap['Last Price']!].toString());
            lastPrice = double.tryParse(lpStr) ?? 0;
          }

          // Fix Last Price for Cash if missing
          if (lastPrice == 0 && symbol.endsWith('**')) {
            lastPrice = 1.0;
          }

          double lastPriceChange = 0;
          if (headerMap.containsKey('Last Price Change')) {
            String lpcStr =
                _cleanCurrency(row[headerMap['Last Price Change']!].toString());
            lastPriceChange = double.tryParse(lpcStr) ?? 0;
          }

          double previousClose = lastPrice - lastPriceChange;

          String cleanSymbol = symbol.trim();
          if (cleanSymbol.startsWith('-')) {
            cleanSymbol = cleanSymbol.substring(1);
          }

          // Regex for Fidelity Option: ^([A-Z]+)(\d{6})([CP])([\d\.]+)$
          RegExp optionRegex = RegExp(r'^([A-Z]+)(\d{6})([CP])([\d\.]+)$');
          Match? match = optionRegex.firstMatch(cleanSymbol);

          if (match != null) {
            importedOptions++;
            newOptionPositions.add(_importOption(
                context,
                cleanSymbol,
                match,
                quantity,
                averageCost,
                lastPrice,
                previousClose,
                accountNumber));
          } else {
            // Note: Cash positions (**) are skipped above
            importedStocks++;

            String type = 'stock';
            String description = symbol;
            if (headerMap.containsKey('Description')) {
              description = row[headerMap['Description']!].toString().trim();
            }

            newStockPositions.add(_importStock(
                context,
                cleanSymbol,
                description,
                quantity,
                averageCost,
                lastPrice,
                previousClose,
                accountNumber,
                type: type));
          }
        }

        var user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          var firestoreService = FirestoreService();
          var userDoc = firestoreService.userCollection.doc(user.uid);
          for (var p in newStockPositions) {
            await firestoreService.upsertInstrumentPosition(p, userDoc);
          }
          for (var p in newOptionPositions) {
            await firestoreService.upsertOptionPosition(p, userDoc);
          }

          if (accountCashBalances.isNotEmpty) {
            var userSnapshot = await userDoc.get();
            if (userSnapshot.exists) {
              var userModel = userSnapshot.data()!;
              var fidelityUser = userModel.brokerageUsers.firstWhere(
                  (b) => b.source == BrokerageSource.fidelity,
                  orElse: () => BrokerageUser(
                      BrokerageSource.fidelity, 'Fidelity Manual', null, null,
                      accounts: [])); // Should exist if enabled?

              // Update Accounts
              bool accountsUpdated = false;
              for (var entry in accountCashBalances.entries) {
                var accountNum = entry.key;
                var cash = entry.value;

                var accountIndex = fidelityUser.accounts
                    .indexWhere((a) => a.accountNumber == accountNum);
                if (accountIndex != -1) {
                  var existing = fidelityUser.accounts[accountIndex];
                  if (existing.portfolioCash != cash) {
                    fidelityUser.accounts[accountIndex] = Account(
                        existing.url,
                        cash,
                        existing.accountNumber,
                        existing.type,
                        cash,
                        existing.optionLevel,
                        existing.cashHeldForOptionsCollateral,
                        existing.unsettledDebit,
                        existing.settledAmountBorrowed);
                    accountsUpdated = true;
                  }
                } else {
                  fidelityUser.accounts.add(Account(
                      'manual_account_$accountNum',
                      cash,
                      accountNum,
                      'cash',
                      cash,
                      '3',
                      0,
                      0,
                      0));
                  accountsUpdated = true;
                }
              }

              if (accountsUpdated) {
                // Ensure the brokerage user is in the list (if we created a new one, add it)
                if (!userModel.brokerageUsers
                    .any((b) => b.source == BrokerageSource.fidelity)) {
                  userModel.brokerageUsers.add(fidelityUser);
                } else {
                  // Replace it? No, if we mutated it in place it's fine if it was from the list
                  // But wait, `firstWhere` returns the element from the list.
                }

                await firestoreService.updateUser(userDoc, userModel);

                if (context.mounted) {
                  var userStore =
                      Provider.of<BrokerageUserStore>(context, listen: false);
                  userStore.addOrUpdate(fidelityUser);
                }
              }
            }
          }
        }

        String message =
            'Imported $importedStocks stocks and $importedOptions options.';
        if (accountCashBalances.isNotEmpty) {
          message += ' Updated cash balances.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      debugPrint('Error importing CSV: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error importing CSV: $e')),
      );
    }
  }

  static String _cleanCurrency(String input) {
    return input.replaceAll('\$', '').replaceAll(',', '').replaceAll('+', '');
  }

  static Future<void> _importHistory(
      BuildContext context,
      List<List<dynamic>> fields,
      Map<String, int> headerMap,
      int dataStartRow,
      List<String> selectedAccounts,
      int? accountColIndex) async {
    int importedOrders = 0;

    List<dynamic> dividends = [];
    List<InstrumentOrder> orders = [];
    List<OptionOrder> optionOrders = [];

    for (int i = dataStartRow; i < fields.length; i++) {
      List<dynamic> row = fields[i];

      // Stop on empty row or disclaimer
      if (row.isEmpty) break;
      if (row.isNotEmpty &&
          (row[0].toString().isEmpty ||
              row[0].toString().contains('The data'))) {
        break;
      }

      if (row.length < headerMap.length) continue;

      // Account Filtering
      String accountNumber = 'manual_account';
      if (accountColIndex != null && row.length > accountColIndex) {
        String acc = row[accountColIndex].toString().trim();
        if (selectedAccounts.isNotEmpty && !selectedAccounts.contains(acc)) {
          continue;
        }
        if (acc.isNotEmpty) accountNumber = acc;
      }

      String action = row[headerMap['Action']!].toString();
      bool isTrade =
          action.contains('YOU BOUGHT') || action.contains('YOU SOLD');
      bool isDividend = action.contains('DIVIDEND RECEIVED');

      if (!isTrade && !isDividend) {
        continue;
      }

      String symbol = row[headerMap['Symbol']!].toString().trim();
      if (symbol.isEmpty) continue;

      String dateStr = row[headerMap['Run Date']!].toString();
      DateTime? date;
      try {
        List<String> parts = dateStr.split('/');
        if (parts.length == 3) {
          date = DateTime(
              int.parse(parts[2]), int.parse(parts[0]), int.parse(parts[1]));
        }
      } catch (e) {/* ignore */}

      String quantityStr = row[headerMap['Quantity']!].toString();
      double quantity = double.tryParse(quantityStr) ?? 0;

      String priceStr = _cleanCurrency(row[headerMap['Price']!].toString());
      double price = double.tryParse(priceStr) ?? 0;

      String amountStr = _cleanCurrency(row[headerMap['Amount']!].toString());
      double amount = double.tryParse(amountStr) ?? 0;

      String cleanSymbol = symbol.trim();
      bool isOption = false;
      if (cleanSymbol.startsWith('-') || cleanSymbol.contains(RegExp(r'\d'))) {
        if (cleanSymbol.startsWith('-')) cleanSymbol = cleanSymbol.substring(1);
      }

      RegExp optionRegex = RegExp(r'^([A-Z]+)(\d{6})([CP])([\d\.]+)$');
      Match? match = optionRegex.firstMatch(cleanSymbol);

      if (match != null) {
        isOption = true;
      }

      if (isDividend) {
        dividends.add(_createDividend(
            cleanSymbol, date, amount, quantity, accountNumber));
      } else if (isOption && match != null) {
        optionOrders.add(_createOptionOrder(cleanSymbol, match, date, action,
            quantity, price, amount, accountNumber));
      } else {
        orders.add(_createStockOrder(
            cleanSymbol, date, action, quantity, price, amount, accountNumber));
      }
      importedOrders++;
    }

    if (context.mounted) {
      if (dividends.isNotEmpty) {
        var store = Provider.of<DividendStore>(context, listen: false);
        for (var item in dividends) {
          store.add(item);
        }
      }
      if (orders.isNotEmpty) {
        var store = Provider.of<InstrumentOrderStore>(context, listen: false);
        for (var item in orders) {
          store.add(item);
        }
      }
      if (optionOrders.isNotEmpty) {
        var store = Provider.of<OptionOrderStore>(context, listen: false);
        for (var item in optionOrders) {
          store.add(item);
        }
      }
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final firestoreService = FirestoreService();
        final userDoc = firestoreService.userCollection.doc(user.uid);
        const int chunkSize = 450;

        if (dividends.isNotEmpty) {
          for (var i = 0; i < dividends.length; i += chunkSize) {
            var end = (i + chunkSize < dividends.length)
                ? i + chunkSize
                : dividends.length;
            await firestoreService.upsertDividends(
                dividends.sublist(i, end), userDoc);
          }
        }
        if (orders.isNotEmpty) {
          for (var i = 0; i < orders.length; i += chunkSize) {
            var end =
                (i + chunkSize < orders.length) ? i + chunkSize : orders.length;
            await firestoreService.upsertInstrumentOrders(
                orders.sublist(i, end), userDoc);
          }
        }
        if (optionOrders.isNotEmpty) {
          for (var i = 0; i < optionOrders.length; i += chunkSize) {
            var end = (i + chunkSize < optionOrders.length)
                ? i + chunkSize
                : optionOrders.length;
            await firestoreService.upsertOptionOrders(
                optionOrders.sublist(i, end), userDoc);
          }
        }
      }
    } catch (e) {
      debugPrint('Error saving imported history to Firestore: $e');
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Imported $importedOrders transactions from history.')),
      );
    }
  }

  static Map<String, dynamic> _createDividend(String symbol, DateTime? date,
      double amount, double quantity, String account) {
    return {
      'id': 'manual_div_${symbol}_${date?.millisecondsSinceEpoch}',
      'account': account,
      'instrument': 'manual_inst_$symbol',
      'amount': amount.toString(),
      'payable_date': date?.toIso8601String(),
      'paid_at': date?.toIso8601String(),
      'state': 'paid',
      'record_date': date?.toIso8601String(),
      'position': quantity.toString(),
      'withholding': '0.00',
      'rate': '0.00',
    };
  }

  static InstrumentOrder _createStockOrder(
      String symbol,
      DateTime? date,
      String action,
      double quantity,
      double price,
      double amount,
      String account) {
    String side = 'buy';
    if (action.contains('SOLD')) side = 'sell';
    if (action.contains('BOUGHT')) side = 'buy';

    double fees = 0;
    double tradeVal = price * quantity.abs();
    if (amount != 0) {
      if (side == 'buy') {
        fees = (-amount) - tradeVal;
      } else {
        fees = tradeVal - amount;
      }
    }

    InstrumentOrder order = InstrumentOrder(
        'manual_order_${symbol}_${date?.millisecondsSinceEpoch}',
        null,
        'manual_url',
        account,
        'manual_pos_url',
        null,
        'manual_inst_url_$symbol',
        'manual_inst_id_$symbol',
        quantity.abs(),
        price,
        fees,
        'filled',
        null,
        'market',
        side,
        'gfd',
        'immediate',
        price,
        null,
        quantity.abs(),
        null, // rejectReason
        date ?? DateTime.now(),
        date ?? DateTime.now(),
        null);

    order.instrumentObj = Instrument(
        id: 'manual_$symbol',
        url: 'manual_inst_$symbol',
        quote: 'manual_quote_$symbol',
        fundamentals: 'manual_fundamentals_$symbol',
        splits: 'manual_splits_$symbol',
        state: 'active',
        market: 'manual_market_$symbol',
        name: symbol,
        tradeable: true,
        tradability: 'tradable',
        symbol: symbol,
        bloombergUnique: 'manual_$symbol',
        country: 'US',
        type: 'stock',
        rhsTradability: 'tradable',
        fractionalTradability: 'tradable',
        isSpac: false,
        isTest: false,
        ipoAccessSupportsDsp: false,
        dateCreated: DateTime.now());

    return order;
  }

  static OptionOrder _createOptionOrder(
      String occSymbol,
      Match match,
      DateTime? date,
      String action,
      double quantity,
      double price,
      double amount,
      String account) {
    String symbol = match.group(1)!;
    String dateStr = match.group(2)!;
    String type = match.group(3)!;
    String strikeStr = match.group(4)!;

    int year = int.parse('20${dateStr.substring(0, 2)}');
    int month = int.parse(dateStr.substring(2, 4));
    int day = int.parse(dateStr.substring(4, 6));
    DateTime expirationDate = DateTime(year, month, day);

    double strike = double.parse(strikeStr);
    String optionType = type == 'C' ? 'call' : 'put';

    String direction = 'debit';
    if (amount > 0) direction = 'credit';
    if (action.contains('SOLD')) direction = 'credit';
    if (action.contains('BOUGHT')) direction = 'debit';

    String side = 'long';
    if (action.contains('SOLD')) side = 'short';
    if (action.contains('BOUGHT')) side = 'long';

    // Refine strategy naming
    String openingStrategy = 'long_call';
    if (optionType == 'call') {
      openingStrategy = (side == 'long') ? 'long_call' : 'short_call';
    } else {
      openingStrategy = (side == 'long') ? 'long_put' : 'short_put';
    }

    String? closingStrategy;
    String positionEffect = 'open';

    if (action.contains('OPENING')) {
      closingStrategy = null;
      positionEffect = 'open';
    } else if (action.contains('CLOSING')) {
      closingStrategy = 'close';
      positionEffect = 'close';
    }

    OptionLeg leg = OptionLeg(
        'manual_leg_${occSymbol}_${date?.millisecondsSinceEpoch}',
        'manual_pos_url',
        side,
        'manual_opt_inst_$occSymbol',
        positionEffect,
        1,
        side,
        expirationDate,
        strike,
        optionType, []);

    OptionOrder order = OptionOrder(
      'manual_ord_${occSymbol}_${date?.millisecondsSinceEpoch}',
      'manual_chain',
      symbol,
      null,
      0,
      direction,
      [leg],
      0,
      amount.abs() / 100 / quantity.abs(),
      amount.abs(),
      price,
      quantity.abs(),
      quantity.abs(),
      'manual_ref',
      'filled',
      'gfd',
      'immediate',
      'market',
      null,
      openingStrategy,
      closingStrategy,
      null,
      date ?? DateTime.now(),
      date ?? DateTime.now(),
    );

    return order;
  }

  static InstrumentPosition _importStock(
      BuildContext context,
      String symbol,
      String description,
      double quantity,
      double averageCost,
      double lastPrice,
      double previousClose,
      String account,
      {String type = 'stock'}) {
    var store = Provider.of<InstrumentPositionStore>(context, listen: false);

    Quote quote = Quote(
      symbol: symbol,
      lastTradePrice: lastPrice,
      lastExtendedHoursTradePrice: lastPrice,
      adjustedPreviousClose: previousClose,
      previousClose: previousClose,
      askSize: 0,
      bidSize: 0,
      updatedAt: DateTime.now(),
      instrument: 'manual_inst_$symbol',
      instrumentId: 'manual_inst_$symbol',
      tradingHalted: false,
      hasTraded: true,
      lastTradePriceSource: 'consolidated',
    );

    Instrument instrument = Instrument(
        id: 'manual_$symbol',
        url: 'manual_inst/$symbol/',
        quote: 'manual_quote_$symbol',
        fundamentals: 'manual_fundamentals_$symbol',
        splits: 'manual_splits_$symbol',
        state: 'active',
        market: 'manual_market_$symbol',
        simpleName: description.isNotEmpty ? description : symbol,
        name: description.isNotEmpty ? description : symbol,
        tradeable: true,
        tradability: 'tradable',
        symbol: symbol,
        bloombergUnique: 'manual_bloomberg_$symbol',
        marginInitialRatio: 0,
        maintenanceRatio: 0,
        country: 'US',
        dayTradeRatio: 0,
        listDate: DateTime.now(),
        minTickSize: null,
        type: type,
        tradeableChainId: 'manual',
        rhsTradability: 'tradable',
        fractionalTradability: 'tradable',
        isSpac: false,
        isTest: false,
        ipoAccessSupportsDsp: false,
        dateCreated: DateTime.now(),
        quoteObj: quote);

    InstrumentPosition position = InstrumentPosition(
      'manual_pos://$symbol',
      'manual_inst/$symbol/',
      account,
      account,
      averageCost,
      0,
      quantity,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      false,
      DateTime.now(),
      DateTime.now(),
    );

    position.instrumentObj = instrument;

    store.add(position);
    return position;
  }

  static OptionAggregatePosition _importOption(
      BuildContext context,
      String occSymbol,
      Match match,
      double quantity,
      double averageCost,
      double lastPrice,
      double previousClose,
      String account) {
    var store = Provider.of<OptionPositionStore>(context, listen: false);

    String symbol = match.group(1)!;
    String dateStr = match.group(2)!;
    String type = match.group(3)!;
    String strikeStr = match.group(4)!;

    int year = int.parse('20${dateStr.substring(0, 2)}');
    int month = int.parse(dateStr.substring(2, 4));
    int day = int.parse(dateStr.substring(4, 6));
    DateTime expirationDate = DateTime(year, month, day);

    double strike = double.parse(strikeStr);
    String optionType = type == 'C' ? 'call' : 'put';

    String direction = quantity < 0 ? 'credit' : 'debit';
    double absQuantity = quantity.abs();

    OptionMarketData marketData = OptionMarketData(
        lastPrice,
        0,
        0,
        0,
        0,
        averageCost,
        0,
        'manual_opt_inst_$occSymbol',
        'manual_opt_inst_id_$occSymbol',
        lastPrice,
        0,
        0, // lowPrice
        lastPrice,
        0,
        null,
        previousClose,
        0,
        symbol,
        occSymbol,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        DateTime.now());

    OptionInstrument optInstrument = OptionInstrument(
        'manual_chain',
        'manual_chain_symbol',
        DateTime.now(),
        expirationDate,
        'manual_opt_inst_id_$occSymbol',
        DateTime.now(),
        const MinTicks(0.01, 0.01, 0.0),
        'tradable',
        'active',
        strike,
        'tradable',
        optionType,
        DateTime.now(),
        'manual_opt_inst_$occSymbol',
        DateTime.now(), // AI chose `null` on initial code generation
        'none',
        'none');
    optInstrument.optionMarketData = marketData;

    OptionLeg leg = OptionLeg(
        'manual_leg_$occSymbol',
        'manual_pos',
        direction == 'debit' ? 'long' : 'short',
        'manual_opt_inst_$occSymbol',
        'open',
        1,
        direction == 'debit' ? 'long' : 'short',
        expirationDate,
        strike,
        optionType, []);

    OptionAggregatePosition position = OptionAggregatePosition(
      'manual_op_$occSymbol',
      'manual_chain_$symbol',
      account,
      symbol,
      'long_$optionType',
      averageCost,
      [leg],
      absQuantity,
      0,
      0,
      direction,
      '',
      100,
      DateTime.now(),
      DateTime.now(),
      'long_$optionType',
    );

    position.optionInstrument = optInstrument;
    position.instrumentObj = Instrument(
        id: 'manual_$symbol',
        url: 'manual_inst_$symbol',
        quote: 'manual_quote_$symbol',
        fundamentals: 'manual_fundamentals_$symbol',
        splits: 'manual_splits_$symbol',
        state: 'active',
        market: 'manual_market_$symbol',
        name: symbol,
        tradeable: true,
        tradability: 'tradable',
        symbol: symbol,
        bloombergUnique: 'manual_bloomberg_$symbol',
        country: 'US',
        type: 'stock',
        rhsTradability: 'tradable',
        fractionalTradability: 'tradable',
        isSpac: false,
        isTest: false,
        ipoAccessSupportsDsp: false,
        dateCreated: DateTime.now());

    store.add(position);
    return position;
  }
}

class _AccountSelectionDialog extends StatefulWidget {
  final List<String> accounts;
  final Map<String, String>? accountLabels;

  const _AccountSelectionDialog(
      {required this.accounts, this.accountLabels});

  @override
  _AccountSelectionDialogState createState() => _AccountSelectionDialogState();
}

class _AccountSelectionDialogState extends State<_AccountSelectionDialog> {
  final Map<String, bool> _selectedAccounts = {};

  @override
  void initState() {
    super.initState();
    for (var account in widget.accounts) {
      _selectedAccounts[account] = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Accounts to Import'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: widget.accounts.map((account) {
            String label = account;
            if (widget.accountLabels != null &&
                widget.accountLabels!.containsKey(account)) {
              label = widget.accountLabels![account]!;
            }
            return CheckboxListTile(
              title: Text(label),
              value: _selectedAccounts[account],
              onChanged: (bool? value) {
                setState(() {
                  _selectedAccounts[account] = value ?? false;
                });
              },
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(null); // Return null on cancel
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            List<String> selected = _selectedAccounts.entries
                .where((entry) => entry.value)
                .map((entry) => entry.key)
                .toList();
            Navigator.of(context).pop(selected);
          },
          child: const Text('Import'),
        ),
      ],
    );
  }
}
