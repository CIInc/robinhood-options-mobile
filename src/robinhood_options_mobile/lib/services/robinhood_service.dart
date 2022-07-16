import 'dart:convert';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/forex_historicals.dart';
import 'package:robinhood_options_mobile/model/forex_holding_store.dart';
import 'package:robinhood_options_mobile/model/forex_quote.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals_store.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/midlands_movers_item.dart';
import 'package:robinhood_options_mobile/model/option_event_store.dart';
import 'package:robinhood_options_mobile/model/option_historicals.dart';
import 'package:robinhood_options_mobile/model/option_historicals_store.dart';
import 'package:robinhood_options_mobile/model/option_instrument_store.dart';
import 'package:robinhood_options_mobile/model/option_order_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_store.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';
import 'package:robinhood_options_mobile/model/stock_order_store.dart';
import 'package:robinhood_options_mobile/model/stock_position_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';

import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/forex_holding.dart';
import 'package:robinhood_options_mobile/model/fundamentals.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_chain.dart';
import 'package:robinhood_options_mobile/model/option_event.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/option_marketdata.dart';
import 'package:robinhood_options_mobile/model/option_order.dart';
import 'package:robinhood_options_mobile/model/portfolio.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals.dart';
import 'package:robinhood_options_mobile/model/stock_position.dart';
import 'package:robinhood_options_mobile/model/stock_order.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/robinhood_user.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/model/watchlist.dart';
import 'package:robinhood_options_mobile/model/watchlist_item.dart';

class RobinhoodService {
/*
  // scopes: [acats, balances, document_upload, edocs, funding:all:read, funding:ach:read, funding:ach:write, funding:wire:read, funding:wire:write, internal, investments, margin, read, signup, trade, watchlist, web_limited])
  */

  static Map<String, dynamic> logoUrls = {};

  static List<dynamic> forexPairs = [];

  /*
  USERS & ACCOUNTS
  */

  static Future<UserInfo> getUser(RobinhoodUser user) async {
    var url = '${Constants.robinHoodEndpoint}/user/';
    // debugPrint(result);
    /*
    debugPrint('${Constants.robinHoodEndpoint}/user/basic_info/');
    debugPrint('${Constants.robinHoodEndpoint}/user/investment_profile/');
    debugPrint('${Constants.robinHoodEndpoint}/user/additional_info/');
        */

    var resultJson = await getJson(user, url);

    var usr = UserInfo.fromJson(resultJson);
    return usr;
  }

  static Future<List<Account>> getAccounts(
      RobinhoodUser user, AccountStore store) async {
    var results = await RobinhoodService.pagedGet(
        user, "${Constants.robinHoodEndpoint}/accounts/");
    //debugPrint(results);
    // https://phoenix.robinhood.com/accounts/unified
    List<Account> accounts = [];
    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      var op = Account.fromJson(result);
      accounts.add(op);
      store.add(op);
    }
    return accounts;
  }

  /*
  PORTFOLIOS
  */
  // Unified Amounts
  //https://bonfire.robinhood.com/phoenix/accounts/unified

  static Future<List<Portfolio>> getPortfolios(
      RobinhoodUser user, PortfolioStore store) async {
    var results = await RobinhoodService.pagedGet(
        user, "${Constants.robinHoodEndpoint}/portfolios/");
    //debugPrint(results);
    List<Portfolio> portfolios = [];
    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      var op = Portfolio.fromJson(result);
      store.addOrUpdate(op);
      portfolios.add(op);
    }
    return portfolios;
  }

  /*
  // Bounds options     [24_7, regular]
  // Interval options   [15second, 5minute, hour, day, week]
  // Span options       [hour, day, week, month, 3month, year, all]

  // Hour: bounds: 24_7,interval: 15second, span: hour
  // Day: bounds: 24_7,interval: 5minute, span: day
  // Week: bounds: 24_7,interval: hour, span: week
  // Month: bounds: 24_7,interval: hour, span: month
  // 3 Months: bounds: 24_7,interval: day, span: 3month
  // Year: bounds: 24_7,interval: day, span: year
  // All bounds: 24_7, span: all
  */
  static Future<PortfolioHistoricals> getPortfolioHistoricals(
      RobinhoodUser user,
      PortfolioHistoricalsStore store,
      String account,
      Bounds chartBoundsFilter,
      ChartDateSpan chartDateSpanFilter) async {
    String? bounds = convertChartBoundsFilter(chartBoundsFilter);
    var rtn = convertChartSpanFilterWithInterval(chartDateSpanFilter);
    String? span = rtn[0];
    String? interval = rtn[1];

    // https://api.robinhood.com/portfolios/historicals/1AB23456/?account=1AB23456&bounds=24_7&interval=5minute&span=day
    var result = await RobinhoodService.getJson(user,
        "${Constants.robinHoodEndpoint}/portfolios/historicals/$account/?&bounds=$bounds&span=$span&interval=$interval"); //${account}/
    var historicals = PortfolioHistoricals.fromJson(result);
    store.set(historicals);
    return historicals;
  }

  static String convertChartBoundsFilter(Bounds chartBoundsFilter) {
    String bounds = "regular";
    switch (chartBoundsFilter) {
      case Bounds.regular:
        bounds = "regular";
        break;
      case Bounds.t24_7:
        bounds = "24_7";
        break;
      case Bounds.trading:
        bounds = "trading";
        break;
      default:
        bounds = "regular";
        break;
    }
    return bounds;
  }

  static String convertChartSpanFilter(ChartDateSpan chartDateSpanFilter) {
    String span = "day";
    switch (chartDateSpanFilter) {
      case ChartDateSpan.hour:
        span = "hour";
        //bounds = "24_7"; // Does not work with regular?!
        break;
      case ChartDateSpan.day:
        span = "day";
        break;
      case ChartDateSpan.week:
        span = "week";
        // bounds = "24_7"; // Does not look good with regular?!
        break;
      case ChartDateSpan.month:
        span = "month";
        // bounds = "24_7"; // Does not look good with regular?!
        break;
      case ChartDateSpan.month_3:
        span = "3month";
        break;
      case ChartDateSpan.year:
        span = "year";
        break;
      case ChartDateSpan.year_5:
        span = "5year";
        break;
      case ChartDateSpan.all:
        span = "all";
        break;
    }
    return span;
  }

  static List<String> convertChartSpanFilterWithInterval(
      ChartDateSpan chartDateSpanFilter) {
    String interval = "5minute";
    String span = "day";
    switch (chartDateSpanFilter) {
      case ChartDateSpan.hour:
        interval = "15second";
        span = "hour";
        //bounds = "24_7"; // Does not work with regular?!
        break;
      case ChartDateSpan.day:
        interval = "5minute";
        span = "day";
        break;
      case ChartDateSpan.week:
        interval = "10minute"; //"hour";
        span = "week";
        // bounds = "24_7"; // Does not look good with regular?!
        break;
      case ChartDateSpan.month:
        interval = "hour";
        span = "month";
        // bounds = "24_7"; // Does not look good with regular?!
        break;
      case ChartDateSpan.month_3:
        interval = "day";
        span = "3month";
        break;
      case ChartDateSpan.year:
        interval = "day";
        span = "year";
        break;
      case ChartDateSpan.year_5:
        interval = "week";
        span = "5year";
        break;
      case ChartDateSpan.all:
        // interval = "week";
        span = "all";
        break;
      //default:
      //  interval = "5minute";
      //  span = "day";
    }
    return [span, interval];
  }

  /*
  POSITIONS
  */

  /*
  static Future<List<Position>> getPositions(RobinhoodUser user,
      {bool withQuantity = true}) async {
    var results = await RobinhoodService.pagedGet(
        user, "${Constants.robinHoodEndpoint}/positions/");
    List<Position> positions = [];
    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      var op = Position.fromJson(result);
      if ((withQuantity && op.quantity! > 0) ||
          (!withQuantity && op.quantity == 0)) {
        positions.add(op);
      }
    }

    for (var i = 0; i < positions.length; i++) {
      var instrumentObj = await getInstrument(user, positions[i].instrument);

      //var quoteObj = await downloadQuote(user, instrumentObj);
      var quoteObj = await getQuote(user, instrumentObj.symbol);
      instrumentObj.quoteObj = quoteObj;

      positions[i].instrumentObj = instrumentObj;
    }

    return positions;
  }
  */

  static Future<StockPositionStore> getStockPositionStore(
      RobinhoodUser user,
      StockPositionStore store,
      InstrumentStore instrumentStore,
      QuoteStore quoteStore,
      {bool nonzero = true}) async {
    var pageStream = RobinhoodService.streamedGet(
        user, "${Constants.robinHoodEndpoint}/positions/?nonzero=$nonzero");
    //debugPrint(results);
    await for (final results in pageStream) {
      for (var i = 0; i < results.length; i++) {
        var result = results[i];
        var op = StockPosition.fromJson(result);

        //if ((withQuantity && op.quantity! > 0) ||
        //    (!withQuantity && op.quantity == 0)) {
        store.add(op);
      }
      var instrumentIds = store.items.map((e) => e.instrumentId).toList();
      var instrumentObjs =
          await getInstrumentsByIds(user, instrumentStore, instrumentIds);
      for (var instrumentObj in instrumentObjs) {
        var position = store.items
            .firstWhere((element) => element.instrumentId == instrumentObj.id);
        position.instrumentObj = instrumentObj;
        store.update(position);
      }
      var symbols = store.items.map((e) => e.instrumentObj!.symbol).toList();
      var quoteObjs = await getQuoteByIds(user, quoteStore, symbols);
      for (var quoteObj in quoteObjs) {
        var position = store.items.firstWhere(
            (element) => element.instrumentObj!.symbol == quoteObj.symbol);
        position.instrumentObj!.quoteObj = quoteObj;
        store.update(position);
      }
    }
    return store;
  }

  static Stream<StockPositionStore> streamStockPositionStore(
      RobinhoodUser user,
      StockPositionStore store,
      InstrumentStore instrumentStore,
      QuoteStore quoteStore,
      {bool nonzero = true}) async* {
    var pageStream = RobinhoodService.streamedGet(
        user, "${Constants.robinHoodEndpoint}/positions/?nonzero=$nonzero");
    //debugPrint(results);
    await for (final results in pageStream) {
      for (var i = 0; i < results.length; i++) {
        var result = results[i];
        var op = StockPosition.fromJson(result);

        //if ((withQuantity && op.quantity! > 0) ||
        //    (!withQuantity && op.quantity == 0)) {
        store.add(op);
        yield store;
        /*
        var instrumentObj = await getInstrument(user, op.instrument);
        //var quoteObj = await downloadQuote(user, instrumentObj);
        op.instrumentObj = instrumentObj;
        yield positions;

        var quoteObj = await getQuote(user, instrumentObj.symbol);
        op.instrumentObj!.quoteObj = quoteObj;
        yield positions;
        */
      }
      var instrumentIds = store.items.map((e) => e.instrumentId).toList();
      var instrumentObjs =
          await getInstrumentsByIds(user, instrumentStore, instrumentIds);
      for (var instrumentObj in instrumentObjs) {
        var position = store.items
            .firstWhere((element) => element.instrumentId == instrumentObj.id);
        position.instrumentObj = instrumentObj;
      }
      var symbols = store.items.map((e) => e.instrumentObj!.symbol).toList();
      var quoteObjs = await getQuoteByIds(user, quoteStore, symbols);
      for (var quoteObj in quoteObjs) {
        var position = store.items.firstWhere(
            (element) => element.instrumentObj!.symbol == quoteObj.symbol);
        position.instrumentObj!.quoteObj = quoteObj;
      }
    }
    yield store;
  }

  static Future<List<StockPosition>> refreshPositionQuote(RobinhoodUser user,
      StockPositionStore store, QuoteStore quoteStore) async {
    if (store.items.isEmpty || store.items.first.instrumentObj == null) {
      return store.items;
    }

    var ops = store.items;
    var len = ops.length;
    var size = 25; //20; //15; //17;
    List<List<StockPosition>> chunks = [];
    for (var i = 0; i < len; i += size) {
      var end = (i + size < len) ? i + size : len;
      chunks.add(ops.sublist(i, end));
    }
    for (var chunk in chunks) {
      var symbols = chunk.map((e) => e.instrumentObj!.symbol).toList();

      var quoteObjs =
          await getQuoteByIds(user, quoteStore, symbols, fromCache: false);
      for (var quoteObj in quoteObjs) {
        var position = store.items.firstWhere(
            (element) => element.instrumentObj!.symbol == quoteObj.symbol);
        position.instrumentObj!.quoteObj = quoteObj;
        // Update store
        store.update(position);
      }
    }
    return ops;
  }

  static Stream<List<StockOrder>> streamPositionOrders(RobinhoodUser user,
      StockOrderStore store, InstrumentStore instrumentStore) async* {
    List<StockOrder> list = [];
    var pageStream = RobinhoodService.streamedGet(user,
        "${Constants.robinHoodEndpoint}/orders/"); // ?chain_id=${instrument.tradeableChainId}
    //debugPrint(results);
    await for (final results in pageStream) {
      for (var i = 0; i < results.length; i++) {
        var result = results[i];
        var op = StockOrder.fromJson(result);
        if (!list.any((element) => element.id == op.id)) {
          list.add(op);
          store.add(op);
          yield list;
          /*
          var instrumentObj = await getInstrument(user, op.instrument);
          op.instrumentObj = instrumentObj;
          yield list;
          */
        }
      }
      list.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
      yield list;

      var instrumentIds = list.map((e) => e.instrumentId).toSet().toList();
      var instrumentObjs =
          await getInstrumentsByIds(user, instrumentStore, instrumentIds);
      for (var instrumentObj in instrumentObjs) {
        var pos =
            list.where((element) => element.instrumentId == instrumentObj.id);
        for (var po in pos) {
          po.instrumentObj = instrumentObj;
        }
        yield list;
      }
    }
    //positionOrders = list;
  }

  /*
  SEARCH and MARKETS
  */

  static Future<dynamic> search(RobinhoodUser user, String query) async {
    var resultJson = await getJson(
        user, "${Constants.robinHoodSearchEndpoint}/search/?query=$query");
    //https://bonfire.robinhood.com/deprecated_search/?query=Micro&user_origin=US
    return resultJson;
  }

  static Future<List<MidlandMoversItem>> getMovers(RobinhoodUser user,
      {String direction = "up"}) async {
    //https://api.robinhood.com/midlands/movers/sp500/?direction=up
    var results = await RobinhoodService.pagedGet(user,
        "${Constants.robinHoodEndpoint}/midlands/movers/sp500/?direction=$direction");
    List<MidlandMoversItem> list = [];
    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      var op = MidlandMoversItem.fromJson(result);
      list.add(op);
    }
    /*
    var instrumentIds = results["results"]
        .map((e) {
          var splits = e["instrument_url"].split("/");
          return splits[splits.length - 2];
        })
        .toSet()
        .toList();
    var instruments = await getInstrumentsByIds(user, instrumentIds);
    instruments.map((i) => )
    */
    return list;
  }

  static Future<List<Instrument>> getListMovers(
      RobinhoodUser user, InstrumentStore instrumentStore) async {
    var resultJson = await getJson(
        user, "${Constants.robinHoodEndpoint}/midlands/tags/tag/top-movers/");
    // https://api.robinhood.com/midlands/tags/tag/top-movers/
    var instrumentIds = resultJson["instruments"]
        .map((e) {
          var splits = e.split("/");
          return splits[splits.length - 2];
        })
        .toSet()
        .toList();
    var list = getInstrumentsByIds(user, instrumentStore, instrumentIds);
    return list;
  }

  static Future<List<Instrument>> getListMostPopular(
      RobinhoodUser user, InstrumentStore instrumentStore) async {
    var resultJson = await getJson(user,
        "${Constants.robinHoodEndpoint}/midlands/tags/tag/100-most-popular/");
    // https://api.robinhood.com/midlands/tags/tag/top-movers/
    var instrumentIds = resultJson["instruments"]
        .map((e) {
          var splits = e.split("/");
          return splits[splits.length - 2].toString();
        })
        .toSet()
        .toList();
    var list = getInstrumentsByIds(user, instrumentStore, instrumentIds);
    return list;
  }

  static Future<List<dynamic>> getFeed(RobinhoodUser user) async {
    //https://dora.robinhood.com/feed/
    var resultJson =
        await getJson(user, "${Constants.robinHoodExploreEndpoint}/feed/");
    List<dynamic> list = [];
    for (var i = 0; i < resultJson["results"].length; i++) {
      var result = resultJson["results"][i];
      list.add(result);
    }
    return list;
  }

  /* 
  INSTRUMENTS
  */

  static Future<Instrument> getInstrument(
      RobinhoodUser user, InstrumentStore store, String instrumentUrl) async {
    var cached = store.items.where((element) => element.url == instrumentUrl);
    if (cached.isNotEmpty) {
      debugPrint('Returned instrument from cache $instrumentUrl');
      return Future.value(cached.first);
    }

    var resultJson = await getJson(user, instrumentUrl);
    var i = Instrument.fromJson(resultJson);
    store.add(i);

    return i;
  }

  static Future<Instrument?> getInstrumentBySymbol(
      RobinhoodUser user, InstrumentStore store, String symbol) async {
    var cached = store.items.where((element) => element.symbol == symbol);
    if (cached.isNotEmpty) {
      debugPrint('Returned instrument from cache $symbol');
      return Future.value(cached.first);
    }

    // https://api.robinhood.com/instruments/?active_instruments_only=false&symbol=GOOG
    var resultJson = await getJson(user,
        "${Constants.robinHoodEndpoint}/instruments/?active_instruments_only=false&symbol=$symbol");
    if (resultJson["results"].length > 0) {
      var i = Instrument.fromJson(resultJson["results"][0]);
      store.add(i);
      return i;
    } else {
      return Future.value(null);
    }
  }

  static Future<List<Instrument>> getInstrumentsByIds(
      RobinhoodUser user, InstrumentStore store, List<dynamic> ids) async {
    if (ids.isEmpty) {
      return Future.value([]);
    }
    var cached =
        store.items.where((element) => ids.contains(element.id)).toList();

    if (cached.isNotEmpty && ids.length == cached.length) {
      debugPrint('Returned instruments from cache ${ids.join(",")}');
      return Future.value(cached);
    }

    var nonCached = ids
        .where((element) => !cached.any((cached) => cached.id == element))
        .toSet()
        .toList();

    List<Instrument> list = cached.toList();
    /*
    var url =
        "${Constants.robinHoodEndpoint}/instruments/?ids=${Uri.encodeComponent(nonCached.join(","))}";
    debugPrint(url);
    var resultJson = await getJson(user, url);

    for (var i = 0; i < resultJson['results'].length; i++) {
      var result = resultJson['results'][i];
      var op = Instrument.fromJson(result);
      list.add(op);
    }
    */

    var len = nonCached.length;
    var size = 15; //17;
    List<List<dynamic>> chunks = [];
    for (var i = 0; i < len; i += size) {
      var end = (i + size < len) ? i + size : len;
      chunks.add(nonCached.sublist(i, end));
    }
    for (var chunk in chunks) {
      //https://api.robinhood.com/instruments/?ids=c0bb3aec-bd1e-471e-a4f0-ca011cbec711%2C50810c35-d215-4866-9758-0ada4ac79ffa%2Cebab2398-028d-4939-9f1d-13bf38f81c50%2C81733743-965a-4d93-b87a-6973cb9efd34
      var url =
          "${Constants.robinHoodEndpoint}/instruments/?ids=${Uri.encodeComponent(chunk.join(","))}";
      // debugPrint(url);
      var resultJson = await getJson(user, url);

      for (var i = 0; i < resultJson['results'].length; i++) {
        var result = resultJson['results'][i];
        if (result != null) {
          var op = Instrument.fromJson(result);

          if (RobinhoodService.logoUrls.containsKey(op.symbol)) {
            op.logoUrl = RobinhoodService.logoUrls[op.symbol];
          }

          list.add(op);
          store.add(op);
        }
      }
    }
    return list;
  }

  // Collars
  // https://api.robinhood.com/instruments/943c5009-a0bb-4665-8cf4-a95dab5874e4/collars/

  // Popularity
  // https://api.robinhood.com/instruments/{0}/popularity/'.format(id_for_stock(symbol))

  static Future<Quote> getQuote(
      RobinhoodUser user, QuoteStore store, String symbol) async {
    var cachedQuotes = store.items.where((element) => element.symbol == symbol);
    if (cachedQuotes.isNotEmpty) {
      debugPrint('Returned quote from cache $symbol');
      return Future.value(cachedQuotes.first);
    }
    var url = "${Constants.robinHoodEndpoint}/quotes/$symbol/";
    var resultJson = await getJson(user, url);
    var quote = Quote.fromJson(resultJson);
    store.add(quote);

    return quote;
  }

  static Future<Quote> refreshQuote(
      RobinhoodUser user, QuoteStore store, String symbol) async {
    var url = "${Constants.robinHoodEndpoint}/quotes/$symbol/";
    var resultJson = await getJson(user, url);
    var quote = Quote.fromJson(resultJson);
    store.update(quote);
    return quote;
  }

  //https://api.robinhood.com/quotes/historicals/

  /*
  static Future<List<Quote>> getQuoteByInstrumentUrls(
      RobinhoodUser user, QuoteStore store, List<String> instrumentUrls) async {
    if (instrumentUrls.isEmpty) {
      return Future.value([]);
    }

    var cached = store.items
        .where((element) => instrumentUrls.contains(element.instrument));

    if (cached.isNotEmpty && instrumentUrls.length == cached.length) {
      debugPrint('Returned quotes from cache ${instrumentUrls.join(",")}');
      return Future.value(cached.toList());
    }

    var nonCached = instrumentUrls
        .where((element) =>
            !cached.any((cachedQuote) => cachedQuote.symbol == element))
        .toSet()
        .toList();

    List<Quote> list = cached.toList();

    var len = nonCached.length;
    var size = 15; //17;
    List<List<dynamic>> chunks = [];
    for (var i = 0; i < len; i += size) {
      var end = (i + size < len) ? i + size : len;
      chunks.add(nonCached.sublist(i, end));
    }
    for (var chunk in chunks) {
      var url =
          "${Constants.robinHoodEndpoint}/marketdata/quotes/?bounds=trading&include_inactive=true&instruments=${Uri.encodeComponent(chunk.join(","))}";
      // https://api.robinhood.com/marketdata/quotes/?bounds=trading&include_inactive=true&instruments=https%3A%2F%2Fapi.robinhood.com%2Finstruments%2F6c62bf75-bc42-457a-8c58-24097799966b%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2Febab2398-028d-4939-9f1d-13bf38f81c50%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2Fcd822b83-39cd-49b5-a33b-9a08eb3f5103%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2F17302400-f9c0-423b-b370-beaf6cee021b%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2F24fb7b13-6679-40a5-9eba-360d648f9ea3%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2Ff1adc843-1a28-4cc5-b6d2-082271fdd126%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2F3a47ca97-d5a2-4a55-9045-053a588894de%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2Fb2e06903-5c44-46a4-bd42-2a696f9d68e1%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2F8a9fe49d-5d0a-4040-a19b-f3f4df44408f%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2F2ed64ef4-2c1a-44d6-832d-1be84741dc41%2F
      var resultJson = await getJson(user, url);

      List<Quote> list = cached.toList();
      for (var i = 0; i < resultJson['results'].length; i++) {
        var result = resultJson['results'][i];
        var op = Quote.fromJson(result);
        list.add(op);
        store.addOrUpdate(op);
      }
    }
    return list;
  }
  */

  static Future<List<Quote>> getQuoteByIds(
      RobinhoodUser user, QuoteStore store, List<String> symbols,
      {bool fromCache = true}) async {
    Iterable<Quote> cached = [];
    if (fromCache) {
      cached = store.items.where((element) => symbols.contains(element.symbol));
    }
    var nonCached = symbols
        .where((element) =>
            !cached.any((cachedQuote) => cachedQuote.symbol == element))
        .toList();
    if (nonCached.isEmpty) {
      return cached.toList();
    }

    List<Quote> list = cached.toList();

    var len = nonCached.length;
    var size = 50;
    List<List<dynamic>> chunks = [];
    for (var i = 0; i < len; i += size) {
      var end = (i + size < len) ? i + size : len;
      chunks.add(nonCached.sublist(i, end));
    }
    for (var chunk in chunks) {
      var url =
          "${Constants.robinHoodEndpoint}/quotes/?symbols=${Uri.encodeComponent(chunk.join(","))}";
      // https://api.robinhood.com/marketdata/quotes/?bounds=trading&include_inactive=true&instruments=https%3A%2F%2Fapi.robinhood.com%2Finstruments%2F6c62bf75-bc42-457a-8c58-24097799966b%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2Febab2398-028d-4939-9f1d-13bf38f81c50%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2Fcd822b83-39cd-49b5-a33b-9a08eb3f5103%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2F17302400-f9c0-423b-b370-beaf6cee021b%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2F24fb7b13-6679-40a5-9eba-360d648f9ea3%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2Ff1adc843-1a28-4cc5-b6d2-082271fdd126%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2F3a47ca97-d5a2-4a55-9045-053a588894de%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2Fb2e06903-5c44-46a4-bd42-2a696f9d68e1%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2F8a9fe49d-5d0a-4040-a19b-f3f4df44408f%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2F2ed64ef4-2c1a-44d6-832d-1be84741dc41%2F
      var resultJson = await getJson(user, url);

      for (var i = 0; i < resultJson['results'].length; i++) {
        var result = resultJson['results'][i];
        var op = Quote.fromJson(result);
        list.add(op);
        store.addOrUpdate(op);
      }
    }

    return list;
  }

  /*
  // Bounds options     [regular, trading]
  // Interval options   [15second, 5minute, 10minute, hour, day, week]
  // Span options       [day, week, month, 3month, year, 5year]

  // Day: bounds: trading, interval: 5minute, span: day
  // Week: bounds: regular, interval: 10minute, span: week
  // Month: bounds: regular, interval: hour, span: month
  // 3 Months: bounds: regular, interval: day, span: 3month
  // Year: bounds: regular, interval: day, span: year
  // Year: bounds: regular, interval: day, span: 5year
  */
  static Future<InstrumentHistoricals> getInstrumentHistoricals(
      RobinhoodUser user,
      InstrumentHistoricalsStore store,
      String symbolOrInstrumentId,
      {bool includeInactive = true,
      Bounds chartBoundsFilter = Bounds.trading,
      ChartDateSpan chartDateSpanFilter = ChartDateSpan.day,
      String? chartInterval}) async {
    String? bounds = convertChartBoundsFilter(chartBoundsFilter);
    var rtn = convertChartSpanFilterWithInterval(chartDateSpanFilter);
    String? span = rtn[0];
    String? interval = rtn[1];
    if (chartInterval != null) {
      interval = chartInterval;
    }
    var result = await RobinhoodService.getJson(
        user,
        //https://api.robinhood.com/marketdata/historicals/943c5009-a0bb-4665-8cf4-a95dab5874e4/?bounds=trading&include_inactive=true&interval=5minute&span=day
        //https://api.robinhood.com/marketdata/historicals/GOOG/?bounds=regular&include_inactive=true&interval=10minute&span=week
        //https://api.robinhood.com/marketdata/historicals/GOOG/?bounds=trading&include_inactive=true&interval=5minute&span=day
        "${Constants.robinHoodEndpoint}/marketdata/historicals/$symbolOrInstrumentId/?bounds=$bounds&include_inactive=$includeInactive&interval=$interval&span=$span"); //${account}/
    var instrumentHistorical = InstrumentHistoricals.fromJson(result);
    store.set(instrumentHistorical);
    return instrumentHistorical;
  }

  static Future<List<StockOrder>> getInstrumentOrders(RobinhoodUser user,
      StockOrderStore store, List<String> instrumentUrls) async {
    // https://api.robinhood.com/orders/?instrument=https%3A%2F%2Fapi.robinhood.com%2Finstruments%2F943c5009-a0bb-4665-8cf4-a95dab5874e4%2F

    var results = await RobinhoodService.pagedGet(user,
        "${Constants.robinHoodEndpoint}/orders/?instrument=${Uri.encodeComponent(instrumentUrls.join(","))}");
    List<StockOrder> list = [];
    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      var op = StockOrder.fromJson(result);
      list.add(op);
      store.addOrUpdate(op);
    }
    return list;
  }

  static Future<Fundamentals> getFundamentals(
      RobinhoodUser user, Instrument instrumentObj) async {
    // https://api.robinhood.com/fundamentals/
    // https://api.robinhood.com/marketdata/fundamentals/943c5009-a0bb-4665-8cf4-a95dab5874e4/?include_inactive=true
    var resultJson = await getJson(user, instrumentObj.fundamentals);

    var oi = Fundamentals.fromJson(resultJson);

    return oi;
  }

  static Future<List<dynamic>> getSplits(
      RobinhoodUser user, Instrument instrumentObj) async {
    //debugPrint(instrumentObj.splits);
    // Splits
    // https://api.robinhood.com/instruments/{0}/splits/'.format(id_for_stock(symbol))
    //https://api.robinhood.com/corp_actions/v2/split_payments/?instrument_ids=943c5009-a0bb-4665-8cf4-a95dab5874e4
    var results = await RobinhoodService.pagedGet(user, instrumentObj.splits);
    List<dynamic> list = [];
    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      //var op = Split.fromJson(result);
      list.add(result);
    }
    return list;
  }

  static Future<List<dynamic>> getNews(
      RobinhoodUser user, String symbol) async {
    //https://api.robinhood.com/midlands/news/MSFT/
    //https://dora.robinhood.com/feed/instrument/50810c35-d215-4866-9758-0ada4ac79ffa/?
    var results = await RobinhoodService.pagedGet(
        user, "${Constants.robinHoodEndpoint}/midlands/news/$symbol/");

    List<dynamic> list = [];
    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      list.add(result);
    }
    return list;
  }

  static Future<List<dynamic>> getLists(
      RobinhoodUser user, String instrumentId) async {
    //https://api.robinhood.com/midlands/lists/?object_id=943c5009-a0bb-4665-8cf4-a95dab5874e4&object_type=instrument&owner_type=robinhood
    //https://api.robinhood.com/midlands/lists/?object_id=943c5009-a0bb-4665-8cf4-a95dab5874e4&object_type=instrument&owner_type=custom
    var results = await pagedGet(user,
        "${Constants.robinHoodEndpoint}/midlands/lists/?object_id=$instrumentId&object_type=instrument&owner_type=robinhood");
    List<dynamic> list = [];
    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      list.add(result);
    }
    return list;
  }

  static Future<List<dynamic>> getDividends(
      RobinhoodUser user, String instrumentId) async {
    // https://api.robinhood.com/dividends/
    //https://api.robinhood.com/dividends/?instrument_id=943c5009-a0bb-4665-8cf4-a95dab5874e4
    var results = await pagedGet(user,
        "${Constants.robinHoodEndpoint}/dividends/?instrument_id=$instrumentId");
    List<dynamic> list = [];
    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      list.add(result);
    }
    return list;
  }

  static Future<List<dynamic>> getRecurringTradeLogs(
      RobinhoodUser user, String instrumentId) async {
    //https://bonfire.robinhood.com/recurring_trade_logs/?instrument_id=50810c35-d215-4866-9758-0ada4ac79ffa
    //https://bonfire.robinhood.com/recurring_schedules/?asset_types=equity&instrument_id=50810c35-d215-4866-9758-0ada4ac79ffa
    var results = await pagedGet(user,
        "${Constants.robinHoodEndpoint}/recurring_trade_logs/?instrument_id=$instrumentId");
    List<dynamic> list = [];
    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      list.add(result);
    }
    return list;
  }

  static Future<dynamic> getRatings(
      RobinhoodUser user, String instrumentId) async {
    //https://api.robinhood.com/midlands/ratings/943c5009-a0bb-4665-8cf4-a95dab5874e4/
    //https://api.robinhood.com/midlands/ratings/?ids=c0bb3aec-bd1e-471e-a4f0-ca011cbec711%2C50810c35-d215-4866-9758-0ada4ac79ffa%2Cebab2398-028d-4939-9f1d-13bf38f81c50%2C81733743-965a-4d93-b87a-6973cb9efd34
    var resultJson = await getJson(
        user, "${Constants.robinHoodEndpoint}/midlands/ratings/$instrumentId/");
    return resultJson;
  }

  static Future<dynamic> getRatingsOverview(
      RobinhoodUser user, String instrumentId) async {
    //https://api.robinhood.com/midlands/ratings/50810c35-d215-4866-9758-0ada4ac79ffa/overview/
    dynamic resultJson;
    try {
      resultJson = await getJson(user,
          "${Constants.robinHoodEndpoint}/midlands/ratings/$instrumentId/overview/");
    } on Exception catch (e) {
      // Format
      debugPrint('No rating overview found. Error: $e');
      return Future.value();
    }
    return resultJson;
  }

  static Future<List<dynamic>> getEarnings(
      RobinhoodUser user, String instrumentId) async {
    //https://api.robinhood.com/marketdata/earnings/?instrument=%2Finstruments%2F943c5009-a0bb-4665-8cf4-a95dab5874e4%2F
    var resultJson = await getJson(user,
        "${Constants.robinHoodEndpoint}/marketdata/earnings/?instrument=${Uri.encodeQueryComponent("/instruments/" + instrumentId + "/")}");
    List<dynamic> list = [];
    for (var i = 0; i < resultJson["results"].length; i++) {
      var result = resultJson["results"][i];
      list.add(result);
    }
    return list;
  }

  static Future<List<dynamic>> getSimilar(
      RobinhoodUser user, String instrumentId) async {
    //https://dora.robinhood.com/instruments/similar/50810c35-d215-4866-9758-0ada4ac79ffa/
    var resultJson = await getJson(user,
        "${Constants.robinHoodExploreEndpoint}/instruments/similar/$instrumentId/");
    //return resultJson;
    List<dynamic> list = [];
    bool savePrefs = false;
    for (var i = 0; i < resultJson["similar"].length; i++) {
      var result = resultJson["similar"][i];

      // Add to cache
      if (result["logo_url"] != null) {
        if (!logoUrls.containsKey(result["symbol"])) {
          // result["instrument_id"]
          var logoUrl = result["logo_url"]
              .toString()
              .replaceAll("https:////", "https://");
          logoUrls[result["symbol"]] = logoUrl; // result["instrument_id"]
          savePrefs = true;
        }
      }
      list.add(result);
    }
    if (savePrefs) {
      saveLogos();
    }
    return list;
  }

  static saveLogos() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString("logoUrls", jsonEncode(logoUrls));
    debugPrint("Cached ${logoUrls.keys.length} logos");
  }

  static Future<void> loadLogos() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var prefString = prefs.getString("logoUrls");
    if (prefString != null) {
      logoUrls = jsonDecode(prefString);
    } else {
      logoUrls = {};
    }
    debugPrint("Loaded ${logoUrls.keys.length} logos");
  }

  static Future<void> removeLogo(String symbol) async {
    logoUrls.remove(symbol);
    saveLogos();
  }

  /* 
  OPTIONS
  */

  static Stream<OptionPositionStore> streamOptionPositionStore(
      RobinhoodUser user,
      OptionPositionStore store,
      OptionInstrumentStore optionInstrumentStore,
      InstrumentStore instrumentStore,
      {bool nonzero = true}) async* {
    List<OptionAggregatePosition> ops =
        await getAggregateOptionPositions(user, nonzero: nonzero);
    for (var op in ops) {
      store.addOrUpdate(op);
    }
    store.sort();

    /*
    // Load OptionAggregatePosition.instrumentObj
    var symbols = ops.map((e) => e.symbol);
    var cachedInstruments =
        instruments.where((element) => symbols.contains(element.symbol));
    cachedInstruments.map((e) {
      var op = ops.firstWhereOrNull((element) => element.symbol == e.symbol);
      if (op != null) {
        op.instrumentObj = e;
      }
    });
    */

    var len = ops.length;
    var size = 25; //20; //15; //17;
    List<List<OptionAggregatePosition>> chunks = [];
    for (var i = 0; i < len; i += size) {
      var end = (i + size < len) ? i + size : len;
      chunks.add(ops.sublist(i, end));
    }
    for (var chunk in chunks) {
      var optionIds = chunk.map((e) {
        var splits = e.legs.first.option.split("/");
        return splits[splits.length - 2];
      })
          //.toSet()
          .toList();

      var optionInstruments = await getOptionInstrumentByIds(user, optionIds);

      for (var optionInstrument in optionInstruments) {
        var optionPosition = ops.singleWhere((element) {
          var splits = element.legs.first.option.split("/");
          return splits[splits.length - 2] == optionInstrument.id;
        });

        optionPosition.optionInstrument = optionInstrument;
        optionInstrumentStore.addOrUpdate(optionPosition.optionInstrument!);
      }

      var optionMarketData = await getOptionMarketDataByIds(user, optionIds);

      for (var optionMarketDatum in optionMarketData) {
        var optionPosition = ops.singleWhere((element) {
          var splits = element.legs.first.option.split("/");
          return splits[splits.length - 2] == optionMarketDatum.instrumentId;
        });

        optionPosition.optionInstrument!.optionMarketData = optionMarketDatum;
        optionInstrumentStore.addOrUpdate(optionPosition.optionInstrument!);
        //optionPosition.marketData = optionMarketDatum;

        // Link OptionPosition to Instrument and vice-versa.
        var instrument = await getInstrumentBySymbol(
            user, instrumentStore, optionPosition.symbol);
        optionPosition.instrumentObj = instrument;
        /*
        if (instrument!.optionPositions == null) {
          instrument.optionPositions = [];
        }
        instrument.optionPositions!.add(optionPosition);
        */

        /*
        ops.sort((a, b) {
          int comp = a.legs.first.expirationDate!
              .compareTo(b.legs.first.expirationDate!);
          if (comp != 0) return comp;
          return a.legs.first.strikePrice!.compareTo(b.legs.first.strikePrice!);
        });
        */
      }
    }

    // Load logos from cache.
    for (var op in ops) {
      if (RobinhoodService.logoUrls.containsKey(op.symbol)) {
        op.logoUrl = RobinhoodService.logoUrls[op.symbol];
      }
    }
    yield store;
  }

  static Future<OptionPositionStore> getOptionPositionStore(RobinhoodUser user,
      OptionPositionStore store, InstrumentStore instrumentStore,
      {bool nonzero = true}) async {
    List<OptionAggregatePosition> ops =
        await getAggregateOptionPositions(user, nonzero: nonzero);
    for (var op in ops) {
      store.addOrUpdate(op);
    }
    store.sort();

    var len = ops.length;
    var size = 25; //20; //15; //17;
    List<List<OptionAggregatePosition>> chunks = [];
    for (var i = 0; i < len; i += size) {
      var end = (i + size < len) ? i + size : len;
      chunks.add(ops.sublist(i, end));
    }
    for (var chunk in chunks) {
      var optionIds = chunk.map((e) {
        var splits = e.legs.first.option.split("/");
        return splits[splits.length - 2];
      })
          //.toSet()
          .toList();

      var optionInstruments = await getOptionInstrumentByIds(user, optionIds);

      for (var optionInstrument in optionInstruments) {
        var optionPosition = ops.singleWhere((element) {
          var splits = element.legs.first.option.split("/");
          return splits[splits.length - 2] == optionInstrument.id;
        });

        optionPosition.optionInstrument = optionInstrument;
      }

      var optionMarketData = await getOptionMarketDataByIds(user, optionIds);

      for (var optionMarketDatum in optionMarketData) {
        var optionPosition = ops.singleWhere((element) {
          var splits = element.legs.first.option.split("/");
          return splits[splits.length - 2] == optionMarketDatum.instrumentId;
        });

        optionPosition.optionInstrument!.optionMarketData = optionMarketDatum;
        //optionPosition.marketData = optionMarketDatum;

        // Link OptionPosition to Instrument and vice-versa.
        var instrument = await getInstrumentBySymbol(
            user, instrumentStore, optionPosition.symbol);
        optionPosition.instrumentObj = instrument;
        /*
        if (instrument!.optionPositions == null) {
          instrument.optionPositions = [];
        }
        instrument.optionPositions!.add(optionPosition);
        */

        /*
        ops.sort((a, b) {
          int comp = a.legs.first.expirationDate!
              .compareTo(b.legs.first.expirationDate!);
          if (comp != 0) return comp;
          return a.legs.first.strikePrice!.compareTo(b.legs.first.strikePrice!);
        });
        */

        // Update store
        store.update(optionPosition);
      }
    }

    // Load logos from cache.
    for (var op in ops) {
      if (RobinhoodService.logoUrls.containsKey(op.symbol)) {
        op.logoUrl = RobinhoodService.logoUrls[op.symbol];
      }
    }
    return store;
  }

  static Future<List<OptionAggregatePosition>> getAggregateOptionPositions(
      RobinhoodUser user,
      {bool nonzero = true}) async {
    List<OptionAggregatePosition> optionPositions = [];
    //https://api.robinhood.com/options/aggregate_positions/?chain_ids=9330028e-455f-4acf-9954-77f60b19151d&nonzero=True
    var results = await RobinhoodService.pagedGet(user,
        "${Constants.robinHoodEndpoint}/options/aggregate_positions/?nonzero=$nonzero"); // ?nonzero=true

    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      var op = OptionAggregatePosition.fromJson(result);
      if (!nonzero || (nonzero && op.quantity! > 0)) {
        optionPositions.add(op);
      }
    }
    return optionPositions;
  }

  static Future<OptionInstrument> getOptionInstrument(
      RobinhoodUser user, String option) async {
    var resultJson = await getJson(user, option);
    var oi = OptionInstrument.fromJson(resultJson);
    return oi;
  }

  static Future<List<OptionInstrument>> getOptionInstrumentByIds(
      RobinhoodUser user, List<String> ids) async {
    var url =
        "${Constants.robinHoodEndpoint}/options/instruments/?ids=${Uri.encodeComponent(ids.join(","))}";
    var resultJson = await getJson(user, url);

    List<OptionInstrument> list = [];
    for (var i = 0; i < resultJson['results'].length; i++) {
      var result = resultJson['results'][i];
      var op = OptionInstrument.fromJson(result);
      list.add(op);
    }
    return list;
  }

  static Future<List<OptionChain>> getOptionChainsByIds(
      RobinhoodUser user, List<String> ids) async {
    // https://api.robinhood.com/options/chains/9330028e-455f-4acf-9954-77f60b19151d/
    // https://api.robinhood.com/options/chains/?equity_instrument_ids=943c5009-a0bb-4665-8cf4-a95dab5874e4
    var url =
        "${Constants.robinHoodEndpoint}/options/chains/?equity_instrument_ids=${Uri.encodeComponent(ids.join(","))}";
    var resultJson = await getJson(user, url);

    List<OptionChain> list = [];
    for (var i = 0; i < resultJson['results'].length; i++) {
      var result = resultJson['results'][i];
      var op = OptionChain.fromJson(result);
      list.add(op);
    }
    return list;
  }

  static Future<OptionChain> getOptionChains(
      RobinhoodUser user, String id) async {
    // https://api.robinhood.com/options/chains/?equity_instrument_id=943c5009-a0bb-4665-8cf4-a95dab5874e4
    // {"id":"9330028e-455f-4acf-9954-77f60b19151d","symbol":"GOOG","can_open_position":true,"cash_component":null,"expiration_dates":["2021-10-29","2021-11-05","2021-11-12","2021-11-19","2021-11-26","2021-12-03","2021-12-17","2022-01-21","2022-02-18","2022-03-18","2022-06-17","2023-01-20","2023-03-17","2023-06-16","2024-01-19"],"trade_value_multiplier":"100.0000","underlying_instruments":[{"id":"204f1955-a737-47c9-a559-9fff1279428d","instrument":"https:\/\/api.robinhood.com\/instruments\/943c5009-a0bb-4665-8cf4-a95dab5874e4\/","quantity":100}],"min_ticks":{"above_tick":"0.10","below_tick":"0.05","cutoff_price":"3.00"}}
    var url =
        "${Constants.robinHoodEndpoint}/options/chains/?equity_instrument_id=$id";
    var resultJson = await getJson(user, url);
    List<OptionChain> list = [];
    for (var result in resultJson['results']) {
      var op = OptionChain.fromJson(result);
      list.add(op);
    }
    var canOpenOptionChain =
        list.firstWhereOrNull((element) => element.canOpenPosition);
    return canOpenOptionChain ?? list[0];
  }

  static Stream<List<OptionInstrument>> streamOptionInstruments(
      RobinhoodUser user,
      OptionInstrumentStore store,
      Instrument instrument,
      String? expirationDates, // 2021-03-05
      String? type, // call or put
      {String? state = "active"}) async* {
    // https://api.robinhood.com/options/chains/9330028e-455f-4acf-9954-77f60b19151d/collateral/?account_number=1AB23456
    // {"collateral":{"cash":{"amount":"0.0000","direction":"debit","infinite":false},"equities":[{"quantity":"0E-8","direction":"debit","instrument":"https:\/\/api.robinhood.com\/instruments\/943c5009-a0bb-4665-8cf4-a95dab5874e4\/","symbol":"GOOG"}]},"collateral_held_for_orders":{"cash":{"amount":"0.0000","direction":"debit","infinite":false},"equities":[{"quantity":"0E-8","direction":"debit","instrument":"https:\/\/api.robinhood.com\/instruments\/943c5009-a0bb-4665-8cf4-a95dab5874e4\/","symbol":"GOOG"}]}}
    var url =
        "${Constants.robinHoodEndpoint}/options/instruments/?chain_id=${instrument.tradeableChainId}";
    if (expirationDates != null) {
      url += "&expiration_dates=$expirationDates";
    }
    if (type != null) {
      url += "&type=$type";
    }
    if (state != null) {
      url += "&state=$state";
    }
    debugPrint(url);

    List<OptionInstrument> optionInstruments = [];

    var pageStream = RobinhoodService.streamedGet(user, url);
    await for (final results in pageStream) {
      for (var i = 0; i < results.length; i++) {
        var result = results[i];
        var op = OptionInstrument.fromJson(result);
        if (!optionInstruments.any((element) => element.id == op.id)) {
          optionInstruments.add(op);
          store.addOrUpdate(op);
          yield optionInstruments;
        }
      }
      optionInstruments
          .sort((a, b) => a.strikePrice!.compareTo(b.strikePrice!));
      yield optionInstruments;
    }
    /*
    var results = await RobinhoodService.pagedGet(user, url);
    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      var op = OptionInstrument.fromJson(result);
      optionInstruments.add(op);
    }
    optionInstruments.sort((a, b) => a.strikePrice!.compareTo(b.strikePrice!));
    yield optionInstruments;
    */
  }

  //https://api.robinhood.com/options/strategies/?strategy_codes=24234e97-250c-4b1a-be95-16dcb19a9679_L1

  //https://api.robinhood.com/marketdata/options/strategy/quotes/?ids=24234e97-250c-4b1a-be95-16dcb19a9679&ratios=1&types=long

  //https://api.robinhood.com/midlands/lists/items/?load_all_attributes=False&strategy_code=24234e97-250c-4b1a-be95-16dcb19a9679_L1

  //https://bonfire.robinhood.com/options/simulated/today_total_return/?direction=debit&mark_price=%7B%22amount%22%3A%222.60%22%2C%22currency_code%22%3A%22USD%22%2C%22currency_id%22%3A%221072fc76-1862-41ab-82c2-485837590762%22%7D&previous_close_price=%7B%22amount%22%3A%222.20%22%2C%22currency_code%22%3A%22USD%22%2C%22currency_id%22%3A%221072fc76-1862-41ab-82c2-485837590762%22%7D&simulated_open_price=%7B%22amount%22%3A%22228.00%22%2C%22currency_code%22%3A%22USD%22%2C%22currency_id%22%3A%221072fc76-1862-41ab-82c2-485837590762%22%7D&trade_multiplier=100&watched_at=2021-12-07T18%3A09%3A09.029757Z
/*
  // scopes: [acats, balances, document_upload, edocs, funding:all:read, funding:ach:read, funding:ach:write, funding:wire:read, funding:wire:write, internal, investments, margin, read, signup, trade, watchlist, web_limited])
  Request to https://api.robinhood.com/marketdata/options/?instruments=942d3704-7247-454f-9fb6-1f98f5d41702 failed with status 400: Bad Request.
  */

  static Future<OptionMarketData?> getOptionMarketData(
      RobinhoodUser user, OptionInstrument optionInstrument) async {
    var url =
        "${Constants.robinHoodEndpoint}/marketdata/options/?instruments=${Uri.encodeQueryComponent(optionInstrument.url)}";
    debugPrint(url);
    var resultJson = await getJson(user, url);
    var firstResult = resultJson['results'][0];
    if (firstResult != null) {
      var oi = OptionMarketData.fromJson(firstResult);
      return oi;
    } else {
      return Future.value(null);
    }
  }

  static Future<OptionHistoricals> getOptionHistoricals(
      RobinhoodUser user, OptionHistoricalsStore store, List<String> ids,
      {Bounds chartBoundsFilter = Bounds.regular,
      ChartDateSpan chartDateSpanFilter = ChartDateSpan.day}) async {
    String? bounds = convertChartBoundsFilter(chartBoundsFilter);
    var rtn = convertChartSpanFilterWithInterval(chartDateSpanFilter);
    String? span = rtn[0];
    String? interval = rtn[1];
    // https://api.robinhood.com/marketdata/options/strategy/historicals/?bounds=regular&ids=04c8d8fb-7805-4593-84a7-eb3641e75c7b&interval=5minute&ratios=1&span=day&types=long
    String url =
        "${Constants.robinHoodEndpoint}/marketdata/options/strategy/historicals/?bounds=$bounds&ids=${Uri.encodeComponent(ids.join(","))}&interval=$interval&span=$span&types=long&ratios=1";
    var result = await RobinhoodService.getJson(user, url); //${account}/
    var optionHistoricals = OptionHistoricals.fromJson(result);
    store.addOrUpdate(optionHistoricals);
    return optionHistoricals;
  }

  static Future<List<OptionMarketData>> getOptionMarketDataByIds(
      RobinhoodUser user, List<String> ids) async {
    var url =
        "${Constants.robinHoodEndpoint}/marketdata/options/?ids=${Uri.encodeComponent(ids.join(","))}";
    var resultJson = await getJson(user, url);

    List<OptionMarketData> list = [];
    for (var i = 0; i < resultJson['results'].length; i++) {
      var result = resultJson['results'][i];
      var op = OptionMarketData.fromJson(result);
      list.add(op);
    }
    return list;
  }

  static Future<List<OptionAggregatePosition>> refreshOptionMarketData(
      RobinhoodUser user,
      OptionPositionStore optionPositionStore,
      OptionInstrumentStore optionInstrumentStore) async {
    if (optionPositionStore.items.isEmpty ||
        optionPositionStore.items.first.optionInstrument == null) {
      return optionPositionStore.items;
    }
    var len = optionPositionStore.items.length;
    // TODO: Size appropriately
    var size = 30;
    //25; //20; //15; //17;
    List<List<OptionAggregatePosition>> chunks = [];
    for (var i = 0; i < len; i += size) {
      var end = (i + size < len) ? i + size : len;
      chunks.add(optionPositionStore.items.sublist(i, end));
    }
    for (var chunk in chunks) {
      var optionIds = chunk.map((e) {
        var splits = e.legs.first.option.split("/");
        return splits[splits.length - 2];
      })
          //.toSet()
          .toList();

      var optionMarketData = await getOptionMarketDataByIds(user, optionIds);

      for (var optionMarketDatum in optionMarketData) {
        var optionPosition = optionPositionStore.items.singleWhere((element) {
          var splits = element.legs.first.option.split("/");
          return splits[splits.length - 2] == optionMarketDatum.instrumentId;
        });

        optionPosition.optionInstrument!.optionMarketData = optionMarketDatum;
        optionInstrumentStore.addOrUpdate(optionPosition.optionInstrument!);

        // Update store
        optionPositionStore.update(optionPosition);
      }
    }

    return optionPositionStore.items;
  }

  static Stream<List<OptionOrder>> streamOptionOrders(
      RobinhoodUser user, OptionOrderStore store) async* {
    List<OptionOrder> list = [];
    //https://api.robinhood.com/options/orders/?chain_ids=9330028e-455f-4acf-9954-77f60b19151d
    var pageStream = RobinhoodService.streamedGet(user,
        "${Constants.robinHoodEndpoint}/options/orders/"); // ?chain_id=${instrument.tradeableChainId}
    //debugPrint(results);
    await for (final results in pageStream) {
      for (var i = 0; i < results.length; i++) {
        var result = results[i];
        var op = OptionOrder.fromJson(result);
        if (!list.any((element) => element.id == op.id)) {
          list.add(op);
          store.add(op);
          yield list;
        }
      }
      list.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
      yield list;
    }
    //optionOrders = list;
  }

  static Future<List<OptionOrder>> getOptionOrders(
      RobinhoodUser user, OptionOrderStore store, String chainId) async {
    var results = await RobinhoodService.pagedGet(user,
        "${Constants.robinHoodEndpoint}/options/orders/?chain_ids=${Uri.encodeComponent(chainId)}");
    List<OptionOrder> list = [];
    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      var op = OptionOrder.fromJson(result);
      list.add(op);
      store.addOrUpdate(op);
    }

    return list;
  }

  /*
  static Future<List<OptionOrder>> getOptionOrders(RobinhoodUser user) async {
    // , Instrument instrument
    var results = await RobinhoodService.pagedGet(user,
        "${Constants.robinHoodEndpoint}/options/orders/"); // ?chain_id=${instrument.tradeableChainId}
    //debugPrint(results);
    List<OptionOrder> optionOrders = [];
    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      // debugPrint(result["id"]);
      var op = OptionOrder.fromJson(result);
      optionOrders.add(op);
    }
    return optionOrders;
  }
  */

  static Stream<List<OptionEvent>> streamOptionEvents(
      RobinhoodUser user, OptionEventStore store,
      {int pageSize = 20}) async* {
    List<OptionEvent> list = [];
    //https://api.robinhood.com/options/orders/?page_size=10
    var pageStream = RobinhoodService.streamedGet(user,
        "${Constants.robinHoodEndpoint}/options/events/?page_size=$pageSize"); // ?chain_id=${instrument.tradeableChainId}
    //debugPrint(results);
    await for (final results in pageStream) {
      for (var i = 0; i < results.length; i++) {
        var result = results[i];
        var obj = OptionEvent.fromJson(result);
        if (!list.any((element) => element.id == obj.id)) {
          list.add(obj);
          store.add(obj);
          yield list;
        }
      }
    }
    //optionEvents = list;
  }

  static Future<dynamic> getOptionEvents(RobinhoodUser user,
      {int pageSize = 10}) async {
    //https://api.robinhood.com/options/events/?equity_instrument_id=943c5009-a0bb-4665-8cf4-a95dab5874e4&states=preparing

    var url =
        "${Constants.robinHoodEndpoint}/options/events/?page_size=$pageSize}";
    return await getJson(user, url);
  }

  static Future<List<OptionEvent>> getOptionEventsByInstrumentUrl(
      RobinhoodUser user, String instrumentUrl) async {
    //https://api.robinhood.com/options/events/?chain_ids=9330028e-455f-4acf-9954-77f60b19151d&equity_instrument_id=https%3A%2F%2Fapi.robinhood.com%2Finstruments%2F943c5009-a0bb-4665-8cf4-a95dab5874e4%2F

    //var url =
    //    "${Constants.robinHoodEndpoint}/options/events/?chain_ids=${Uri.encodeComponent(chainIds.join(","))}&equity_instrument_id=$instrumentId";
    //var url =
    //    "${Constants.robinHoodEndpoint}/options/events/?chain_ids=${Uri.encodeComponent(chainIds.join(","))}";

    //https://api.robinhood.com/options/events/?equity_instrument_id=https%3A%2F%2Fapi.robinhood.com%2Finstruments%2F50810c35-d215-4866-9758-0ada4ac79ffa%2F
    var url =
        "${Constants.robinHoodEndpoint}/options/events/?equity_instrument_id=${Uri.encodeComponent(instrumentUrl)}";

    var resultJson = await getJson(user, url);

    List<OptionEvent> list = [];
    for (var i = 0; i < resultJson["results"].length; i++) {
      var result = resultJson["results"][i];
      var obj = OptionEvent.fromJson(result);
      list.add(obj);
    }
    return list;
  }

  /*
  CRYPTO
  */

  static Future<dynamic> getNummusAccounts(RobinhoodUser user) async {
    var resultJson =
        await getJson(user, '${Constants.robinHoodNummusEndpoint}/accounts/');

    return resultJson;
    /*
    List<Account> accounts = [];
    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      var op = new Account.fromJson(result);
      accounts.add(op);
    }
    return accounts;
    */
  }

  static Future<List<ForexHolding>> getNummusHoldings(
      RobinhoodUser user, ForexHoldingStore store,
      {bool nonzero = true}) async {
    var results = await RobinhoodService.pagedGet(user,
        "${Constants.robinHoodNummusEndpoint}/holdings/?nonzero=$nonzero");
    var quotes = await RobinhoodService.getForexPairs(user);
    List<ForexHolding> list = [];
    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      var op = ForexHolding.fromJson(result);
      for (var j = 0; j < quotes.length; j++) {
        var quote = quotes[j];
        var assetCurrencyId = quote['asset_currency']['id'];
        if (assetCurrencyId == op.currencyId) {
          //op.quote = quotes['results'][j];

          var quoteObj = await getForexQuote(user, quote['id']);
          op.quoteObj = quoteObj;
          break;
        }
      }
      list.add(op);
      store.addOrUpdate(op);
    }

    return list;
  }

  static Future<List<ForexHolding>> refreshNummusHoldings(
      RobinhoodUser user, ForexHoldingStore store) async {
    var forexHolding = store.items;
    var len = forexHolding.length;
    var size = 25; //20; //15; //17;
    List<List<ForexHolding>> chunks = [];
    for (var i = 0; i < len; i += size) {
      var end = (i + size < len) ? i + size : len;
      chunks.add(forexHolding.sublist(i, end));
    }
    for (var chunk in chunks) {
      var symbols = chunk.map((e) => e.quoteObj!.id).toList();
      var quoteObjs = await getForexQuoteByIds(user, symbols);
      for (var quoteObj in quoteObjs) {
        var forex = forexHolding
            .firstWhere((element) => element.quoteObj!.id == quoteObj.id);
        forex.quoteObj = quoteObj;
        store.update(forex);
      }
    }
    return forexHolding;
  }

  static Future<ForexQuote> getForexQuote(RobinhoodUser user, String id) async {
    //id = "3d961844-d360-45fc-989b-f6fca761d511"; // BTC-USD pair
    //id = "d674efea-e623-4396-9026-39574b92b093"; // BTC currency
    //id = "1072fc76-1862-41ab-82c2-485837590762"; // USD currency
    String url = "${Constants.robinHoodEndpoint}/marketdata/forex/quotes/$id/";
    var resultJson = await getJson(user, url);
    var quoteObj = ForexQuote.fromJson(resultJson);
    return quoteObj;
  }

  static Future<List<ForexQuote>> getForexQuoteByIds(
      RobinhoodUser user, List<String> ids) async {
    //id = "3d961844-d360-45fc-989b-f6fca761d511"; // BTC-USD pair
    //id = "d674efea-e623-4396-9026-39574b92b093"; // BTC currency
    //id = "1072fc76-1862-41ab-82c2-485837590762"; // USD currency
    String url =
        "${Constants.robinHoodEndpoint}/marketdata/forex/quotes/?ids=${Uri.encodeComponent(ids.join(","))}";
    var resultJson = await getJson(user, url);

    List<ForexQuote> list = [];
    for (var i = 0; i < resultJson['results'].length; i++) {
      var result = resultJson['results'][i];
      var quoteObj = ForexQuote.fromJson(result);
      list.add(quoteObj);
    }
    return list;
  }

  /*
  // Bounds options     [trading, 24_7]
  // Interval options   [15second, 5minute, 10minute, hour, day, week]
  // Span options       [day, week, month, 3month, year, 5year]

  // Day: bounds: trading, interval: 5minute, span: day
  // Week: bounds: regular, interval: 10minute, span: week
  // Month: bounds: regular, interval: hour, span: month
  // 3 Months: bounds: regular, interval: day, span: 3month
  // Year: bounds: regular, interval: day, span: year
  // Year: bounds: regular, interval: day, span: 5year
  */
  static Future<ForexHistoricals> getForexHistoricals(
      RobinhoodUser user, String id,
      {Bounds chartBoundsFilter = Bounds.t24_7,
      ChartDateSpan chartDateSpanFilter = ChartDateSpan.day}) async {
    //https://api.robinhood.com/marketdata/forex/historicals/?bounds=24_7&ids=3d961844-d360-45fc-989b-f6fca761d511%2C1ef78e1b-049b-4f12-90e5-555dcf2fe204%2C76637d50-c702-4ed1-bcb5-5b0732a81f48%2C1ef78e1b-049b-4f12-90e5-555dcf2fe204%2C383280b1-ff53-43fc-9c84-f01afd0989cd%2Ccc2eb8d1-c42d-4f12-8801-1c4bbe43a274%2C3d961844-d360-45fc-989b-f6fca761d511&interval=5minute&span=day
    //https://api.robinhood.com/marketdata/forex/historicals/3d961844-d360-45fc-989b-f6fca761d511/?bounds=24_7&interval=hour&span=week
    // var url = "${Constants.robinHoodEndpoint}/marketdata/forex/historicals/?${bounds != null ? "&bounds=$bounds" : ""}&ids=${Uri.encodeComponent(ids.join(","))}${interval != null ? "&interval=$interval" : ""}${span != null ? "&span=$span" : ""}";
    String bounds = convertChartBoundsFilter(chartBoundsFilter);
    var rtn = convertChartSpanFilterWithInterval(chartDateSpanFilter);
    String span = rtn[0];
    String interval = rtn[1];

    var url =
        "${Constants.robinHoodEndpoint}/marketdata/forex/historicals/$id/?bounds=$bounds&interval=$interval&span=$span";
    var resultJson = await RobinhoodService.getJson(user, url);
    var item = ForexHistoricals.fromJson(resultJson);
    return item;
  }

  static Future<List<dynamic>> getForexPairs(RobinhoodUser user) async {
    String url = '${Constants.robinHoodNummusEndpoint}/currency_pairs/';
    var resultJson = await getJson(user, url);
    List<dynamic> list = [];
    for (var i = 0; i < resultJson['results'].length; i++) {
      var result = resultJson['results'][i];
      list.add(result);
    }
    forexPairs = list;

    return list;
  }

  /*
  TRADING
  */

  static Future<dynamic> placeOptionsOrder(
      RobinhoodUser user,
      Account account,
      //Instrument instrument,
      OptionInstrument optionInstrument,
      String side, // Either 'buy' or 'sell'
      String
          positionEffect, // Either 'open' for a buy to open effect or 'close' for a buy to close effect.
      String creditOrDebit, // Either 'debit' or 'credit'.
      double price, // Limit price to trigger a buy of the option.
      //String symbol, // Ticker of the stock to trade.
      int quantity, // Number of options to buy.
      //String expirationDate, // Expiration date of the option in 'YYYY-MM-DD' format.
      //double strike, // The strike price of the option.
      //String optionType, // This should be 'call' or 'put'
      {String type = 'limit', // market
      String trigger = 'immediate',
      String timeInForce =
          'gtc' // How long order will be in effect. 'gtc' = good until cancelled. 'gfd' = good for the day. 'ioc' = immediate or cancel. 'opg' execute at opening.
      }) async {
    // instrument.tradeableChainId
    var uuid = const Uuid();
    var payload = {
      'account': account.url,
      'direction': creditOrDebit,
      'time_in_force': timeInForce,
      'legs': [
        {
          'position_effect': positionEffect,
          'side': side,
          'ratio_quantity': 1,
          'option': optionInstrument.url // option_instruments_url(optionID)
        },
      ],
      'type': type,
      'trigger': trigger,
      'price': price,
      'quantity': quantity,
      'override_day_trade_checks': false,
      'override_dtbp_checks': false,
      'ref_id': uuid.v4(),
    };
    var url = "${Constants.robinHoodEndpoint}/options/orders/";
    debugPrint(url);
    var result = await user.oauth2Client!.post(Uri.parse(url),
        body: jsonEncode(payload),
        headers: {
          "content-type": "application/json",
          "accept": "application/json"
        });

    return result;
  }

/*
WATCHLIST
*/
  static Stream<List<Watchlist>> streamLists(RobinhoodUser user,
      InstrumentStore instrumentStore, QuoteStore quoteStore) async* {
    List<Watchlist> list = [];
    // https://api.robinhood.com/midlands/lists/default/
    // https://api.robinhood.com/midlands/lists/items/ (not working)
    var watchlistsUrl =
        "${Constants.robinHoodEndpoint}/midlands/lists/user_items/";
    var userItemsJson = await getJson(user, watchlistsUrl);
    for (var entry in userItemsJson.entries) {
      Watchlist wl = await getList(entry.key, user);

      list.add(wl);
      yield list;

      var instrumentIds = entry.value
          .where((e) => e['object_type'] == "instrument")
          .map((e) => e['object_id'].toString())
          .toList();
      var instrumentObjs =
          await getInstrumentsByIds(user, instrumentStore, instrumentIds);
      for (var instrumentObj in instrumentObjs) {
        var watchlistItem = WatchlistItem('instrument', instrumentObj.id,
            instrumentObj.id, DateTime.now(), entry.key, "");
        watchlistItem.instrumentObj = instrumentObj;
        wl.items.add(watchlistItem);
        yield list;
      }

      var instrumentSymbols = wl.items
          .where((e) => e.instrumentObj != null)
          .map((e) => e.instrumentObj!.symbol)
          .toList();
      var quoteObjs = await getQuoteByIds(user, quoteStore, instrumentSymbols);
      for (var quoteObj in quoteObjs) {
        var watchlistItem = wl.items.firstWhere(
            (element) => element.instrumentObj!.symbol == quoteObj.symbol);
        watchlistItem.instrumentObj!.quoteObj = quoteObj;
        yield list;
      }

      List<String> forexIds = List<String>.from(entry.value
          .where((e) => e['object_type'] == "currency_pair")
          .map((e) => e['object_id'].toString()));
      if (forexIds.isNotEmpty) {
        var forexQuotes = await getForexQuoteByIds(user, forexIds);
        for (var forexQuote in forexQuotes) {
          var watchlistItem = WatchlistItem('currency_pair', forexQuote.id,
              forexQuote.id, DateTime.now(), entry.key, "");
          watchlistItem.forexObj = forexQuote;
          wl.items.add(watchlistItem);
          yield list;
        }
      }

      List<String> optionStrategies = List<String>.from(entry.value
          .where((e) => e['object_type'] == "option_strategy")
          .map((e) => e['object_id'].toString()));
      if (optionStrategies.isNotEmpty) {
        /*
        var optionInstruments =
            await getOptionInstrumentByIds(user, optionStrategies);
        for (var optionInstrument in optionInstruments) {
          var watchlistItem =
              WatchlistItem(optionInstrument.id, DateTime.now(), entry.key, "");
          watchlistItem.optionInstrumentObj = optionInstrument;
          wl.items.add(watchlistItem);
          yield list;
        }
        */
      }
    }
  }

  static Stream<Watchlist> streamList(RobinhoodUser user,
      InstrumentStore instrumentStore, QuoteStore quoteStore, String key,
      {String ownerType = "custom"}) async* {
    Watchlist wl = await getList(key, user, ownerType: ownerType);

    List<WatchlistItem> items = await getListItems(key, user);
    //wl.items.addAll(items);
    yield wl;

    var instrumentIds = items.map((e) => e.objectId).toList();
    var instrumentObjs =
        await getInstrumentsByIds(user, instrumentStore, instrumentIds);
    for (var instrumentObj in instrumentObjs) {
      var watchlistItem =
          items.firstWhere((element) => element.objectId == instrumentObj.id);
      watchlistItem.instrumentObj = instrumentObj;
      wl.items.add(watchlistItem);
      yield wl;
    }

    var instrumentSymbols = items
        .where((e) => e.instrumentObj != null)
        .map((e) => e.instrumentObj!.symbol)
        .toList();
    var quoteObjs = await getQuoteByIds(user, quoteStore, instrumentSymbols);
    for (var quoteObj in quoteObjs) {
      var watchlistItem = wl.items.firstWhere(
          (element) => element.instrumentObj!.symbol == quoteObj.symbol);
      watchlistItem.instrumentObj!.quoteObj = quoteObj;
      //wl.items.add(watchlistItem);
      yield wl;
      //wl.items.add(watchlistItem);
    }

    /*


      List<String> forexIds = List<String>.from(entry.value
          .where((e) => e['object_type'] == "currency_pair")
          .map((e) => e['object_id'].toString()));
      if (forexIds.isNotEmpty) {
        var forexQuotes = await getForexQuoteByIds(user, forexIds);
        for (var forexQuote in forexQuotes) {
          var watchlistItem =
              WatchlistItem(forexQuote['id'], DateTime.now(), entry.key, "");
          watchlistItem.forexObj = forexQuote;
          wl.items.add(watchlistItem);
          yield list;
        }
      }
  */
  }

  static Future<Watchlist> getList(String key, RobinhoodUser user,
      {String ownerType = "custom"}) async {
    var watchlistUrl =
        "${Constants.robinHoodEndpoint}/midlands/lists/$key/?owner_type=$ownerType";
    var entryJson = await getJson(user, watchlistUrl);

    var wl = Watchlist.fromJson(entryJson);
    return wl;
  }

  static Future<List<WatchlistItem>> getListItems(
      String key, RobinhoodUser user) async {
    //https://api.robinhood.com/midlands/lists/items/?list_id=8ce9f620-5bb0-4b6a-8c61-5a06763f7a8b&local_midnight=2021-12-30T06%3A00%3A00.000Z
    var watchlistUrl =
        "${Constants.robinHoodEndpoint}/midlands/lists/items/?list_id=$key";
    var entryJson = await getJson(user, watchlistUrl);
    List<WatchlistItem> list = [];
    for (var i = 0; i < entryJson['results'].length; i++) {
      var item = WatchlistItem.fromJson(entryJson['results'][i]);
      list.add(item);
    }
    return list;
  }

  /* COMMON */
  // SocketException (SocketException: Failed host lookup: 'loadbalancer-brokeback.nginx.service.robinhood' (OS Error: No address associated with hostname, errno = 7))
  static Future<dynamic> getJson(RobinhoodUser user, String url) async {
    // debugPrint(url);
    Stopwatch stopwatch = Stopwatch();
    stopwatch.start();
    String responseStr = await user.oauth2Client!.read(Uri.parse(url));
    debugPrint(
        "${(responseStr.length / 1000)}K in ${stopwatch.elapsed.inMilliseconds}ms $url");
    dynamic responseJson = jsonDecode(responseStr);
    return responseJson;
  }

  static Stream<List<dynamic>> streamedGet(RobinhoodUser user, String url,
      {int pages = 0}) async* {
    List<dynamic> results = [];
    dynamic responseJson = await getJson(user, url);
    results = responseJson['results'];
    yield results;
    int page = 1;
    var nextUrl = responseJson['next'];
    while (nextUrl != null &&
        nextUrl != url &&
        (pages == 0 || page < pages) &&
        url.startsWith(Constants.robinHoodEndpoint.toString())) {
      responseJson = await getJson(user, nextUrl);
      results.addAll(responseJson['results']);
      yield results;
      page++;
      nextUrl = responseJson['next'];
    }
  }

  static pagedGet(RobinhoodUser user, String url) async {
    dynamic responseJson = await getJson(user, url);
    var results = responseJson['results'];
    var nextUrl = responseJson['next'];
    while (nextUrl != null) {
      responseJson = await getJson(user, nextUrl);
      results.addAll(responseJson['results']);
      //results.push.apply(results, responseJson['results']);
      nextUrl = responseJson['next'];
    }
    return results;
  }
}

/*

# account

def banktransfers_url(direction=None):
    if direction == 'received':
        return('https://api.robinhood.com/ach/received/transfers/')
    else:
        return('https://api.robinhood.com/ach/transfers/')

def cardtransactions_url():
   return('https://minerva.robinhood.com/history/transactions/')

def daytrades_url(account):
    return('https://api.robinhood.com/accounts/{0}/recent_day_trades/'.format(account))

def documents_url():
    return('https://api.robinhood.com/documents/')

def withdrawl_url(bank_id):
    return("https://api.robinhood.com/ach/relationships/{}/".format(bank_id))

def linked_url(id=None, unlink=False):
    if unlink:
        return('https://api.robinhood.com/ach/relationships/{0}/unlink/'.format(id))
    if id:
        return('https://api.robinhood.com/ach/relationships/{0}/'.format(id))
    else:
        return('https://api.robinhood.com/ach/relationships/')


def margin_url():
    return('https://api.robinhood.com/margin/calls/')


def margininterest_url():
    return('https://api.robinhood.com/cash_journal/margin_interest_charges/')


def notifications_url(tracker=False):
    if tracker:
        return('https://api.robinhood.com/midlands/notifications/notification_tracker/')
    else:
        return('https://api.robinhood.com/notifications/devices/')


def referral_url():
    return('https://api.robinhood.com/midlands/referral/')


def stockloan_url():
    return('https://api.robinhood.com/stock_loan/payments/')


def subscription_url():
    return('https://api.robinhood.com/subscription/subscription_fees/')


def wiretransfers_url():
    return('https://api.robinhood.com/wire/transfers')

# markets

def markets_url():
    return('https://api.robinhood.com/markets/')

def market_hours_url(market, date):
    return('https://api.robinhood.com/markets/{}/hours/{}/'.format(market, date))

def market_category_url(category):
    return('https://api.robinhood.com/midlands/tags/tag/{}/'.format(category))

# options

def option_historicals_url(id):
    return('https://api.robinhood.com/marketdata/options/historicals/{0}/'.format(id))


def option_orders_url(orderID=None):
    if orderID:
        return('https://api.robinhood.com/options/orders/{0}/'.format(orderID))
    else:
        return('https://api.robinhood.com/options/orders/')


def option_positions_url():
    return('https://api.robinhood.com/options/positions/')


# pricebook


def marketdata_quotes_url(id):
    return ('https://api.robinhood.com/marketdata/quotes/{0}/'.format(id))


def marketdata_pricebook_url(id):
    return ('https://api.robinhood.com/marketdata/pricebook/snapshots/{0}/'.format(id))

# crypto


def order_crypto_url():
    return('https://nummus.robinhood.com/orders/')


def crypto_orders_url(orderID=None):
    if orderID:
        return('https://nummus.robinhood.com/orders/{0}/'.format(orderID))
    else:
        return('https://nummus.robinhood.com/orders/')


def crypto_cancel_url(id):
    return('https://nummus.robinhood.com/orders/{0}/cancel/'.format(id))

# orders


def cancel_url(url):
    return('https://api.robinhood.com/orders/{0}/cancel/'.format(url))


def option_cancel_url(id):
    return('https://api.robinhood.com/options/orders/{0}/cancel/'.format(id))


def orders_url(orderID=None):
    if orderID:
        return('https://api.robinhood.com/orders/{0}/'.format(orderID))
    else:
        return('https://api.robinhood.com/orders/')
*/
