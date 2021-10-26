import 'dart:convert';

import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/holding.dart';
import 'package:robinhood_options_mobile/model/fundamentals.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/option_marketdata.dart';
import 'package:robinhood_options_mobile/model/option_order.dart';
import 'package:robinhood_options_mobile/model/portfolio.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals.dart';
import 'package:robinhood_options_mobile/model/position.dart';
import 'package:robinhood_options_mobile/model/position_order.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/robinhood_user.dart';
import 'package:robinhood_options_mobile/model/split.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/model/watchlist.dart';
import 'package:robinhood_options_mobile/model/watchlist_item.dart';

class RobinhoodService {
/*
  // scopes: [acats, balances, document_upload, edocs, funding:all:read, funding:ach:read, funding:ach:write, funding:wire:read, funding:wire:write, internal, investments, margin, read, signup, trade, watchlist, web_limited])
  */
  static List<OptionAggregatePosition>? optionPositions;
  static List<OptionOrder>? optionOrders;
  static List<Position>? stockPositions;
  static List<PositionOrder>? positionOrders;
  static List<Quote> quotes = [];
  static List<Instrument> instruments = [];

  /*
  USERS & ACCOUNTS
  */

  static Future<User> getUser(RobinhoodUser user) async {
    var url = '${Constants.robinHoodEndpoint}/user/';
    // print(result);
    /*
    print('${Constants.robinHoodEndpoint}/user/basic_info/');
    print('${Constants.robinHoodEndpoint}/user/investment_profile/');
    print('${Constants.robinHoodEndpoint}/user/additional_info/');
        */

    var resultJson = await getJson(user, url);

    var usr = User.fromJson(resultJson);
    return usr;
  }

  static Future<List<Account>> getAccounts(RobinhoodUser user) async {
    var results = await RobinhoodService.pagedGet(
        user, "${Constants.robinHoodEndpoint}/accounts/");
    //print(results);
    // https://phoenix.robinhood.com/accounts/unified
    List<Account> accounts = [];
    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      var op = Account.fromJson(result);
      accounts.add(op);
    }
    return accounts;
  }

  /*
  PORTFOLIOS
  */

  static Future<List<Portfolio>> getPortfolios(RobinhoodUser user) async {
    var results = await RobinhoodService.pagedGet(
        user, "${Constants.robinHoodEndpoint}/portfolios/");
    //print(results);
    // https://phoenix.robinhood.com/accounts/unified
    List<Portfolio> portfolios = [];
    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      var op = Portfolio.fromJson(result);
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
      RobinhoodUser user, String account,
      {String? bounds, String? interval, String? span}) async {
    // https://api.robinhood.com/portfolios/historicals/5QR24141/?account=5QR24141&bounds=24_7&interval=5minute&span=day
    // https://api.robinhood.com/marketdata/options/strategy/historicals/?bounds=regular&ids=e4e27a2e-4621-4ccb-8922-860a99fe0cd2&interval=10minute&ratios=1&span=week&types=long
    var result = await RobinhoodService.getJson(user,
        "${Constants.robinHoodEndpoint}/portfolios/historicals/$account/?${bounds != null ? "&bounds=$bounds" : ""}${interval != null ? "&interval=$interval" : ""}${span != null ? "&span=$span" : ""}"); //${account}/
    return new PortfolioHistoricals.fromJson(result);
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

  static Stream<List<Position>> streamPositions(RobinhoodUser user,
      {bool nonzero = true}) async* {
    List<Position> positions = [];
    var pageStream = RobinhoodService.streamedGet(
        user, "${Constants.robinHoodEndpoint}/positions/?nonzero=${nonzero}");
    //print(results);
    await for (final results in pageStream) {
      for (var i = 0; i < results.length; i++) {
        var result = results[i];
        var op = Position.fromJson(result);

        //if ((withQuantity && op.quantity! > 0) ||
        //    (!withQuantity && op.quantity == 0)) {
        positions.add(op);
        yield positions;

        var instrumentObj = await getInstrument(user, op.instrument);
        //var quoteObj = await downloadQuote(user, instrumentObj);
        op.instrumentObj = instrumentObj;

        yield positions;

        var quoteObj = await getQuote(user, instrumentObj.symbol);
        op.instrumentObj!.quoteObj = quoteObj;
        yield positions;

        /* Loaded by InstrumentWidget
        var fundamentalsObj = await getFundamentals(user, instrumentObj);
        op.instrumentObj!.fundamentalsObj = fundamentalsObj;
        */

        /* TODO: Move to InstrumentWidget 
        var splitsObj = await downloadSplits(user, instrumentObj);
        instrumentObj.splitsObj = splitsObj;
        */

        //}
      }
      positions.sort((a, b) => a.createdAt!.compareTo(b.createdAt!));
      yield positions;
    }
    // Persist in static value
    stockPositions = positions;
  }

  static Stream<List<PositionOrder>> streamPositionOrders(
      RobinhoodUser user) async* {
    List<PositionOrder> list = [];
    var pageStream = RobinhoodService.streamedGet(user,
        "${Constants.robinHoodEndpoint}/orders/"); // ?chain_id=${instrument.tradeableChainId}
    //print(results);
    await for (final results in pageStream) {
      for (var i = 0; i < results.length; i++) {
        var result = results[i];
        var op = PositionOrder.fromJson(result);
        if (!list.any((element) => element.id == op.id)) {
          list.add(op);
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
      var instrumentObjs = await getInstrumentsByIds(user, instrumentIds);
      for (var instrumentObj in instrumentObjs) {
        var pos =
            list.where((element) => element.instrumentId == instrumentObj.id);
        for (var po in pos) {
          po.instrumentObj = instrumentObj;
        }
        yield list;
      }
    }
    positionOrders = list;
  }

  /* 
  INSTRUMENTS
  */

  static Future<Instrument> getInstrument(
      RobinhoodUser user, String instrumentUrl) async {
    var cached = instruments.where((element) => element.url == instrumentUrl);
    if (cached.isNotEmpty) {
      print('Returned instrument from cache $instrumentUrl');
      return Future.value(cached.first);
    }

    var resultJson = await getJson(user, instrumentUrl);
    var i = Instrument.fromJson(resultJson);

    instruments.add(i);

    return i;
  }

  static Future<List<Instrument>> getInstrumentsByIds(
      RobinhoodUser user, List<dynamic> ids) async {
    if (ids.isEmpty) {
      return Future.value([]);
    }
    var cached =
        instruments.where((element) => ids.contains(element.id)).toList();

    if (cached.isNotEmpty && ids.length == cached.length) {
      print('Returned instruments from cache ${ids.join(",")}');
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
    print(url);
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
      var url =
          "${Constants.robinHoodEndpoint}/instruments/?ids=${Uri.encodeComponent(chunk.join(","))}";
      print(url);
      var resultJson = await getJson(user, url);

      for (var i = 0; i < resultJson['results'].length; i++) {
        var result = resultJson['results'][i];
        if (result != null) {
          var op = Instrument.fromJson(result);
          list.add(op);
          instruments.add(op);
        }
      }
    }
    return list;
  }

  static Future<Quote> getQuote(RobinhoodUser user, String symbol) async {
    var cachedQuotes = quotes.where((element) => element.symbol == symbol);
    if (cachedQuotes.isNotEmpty) {
      print('Returned quote from cache $symbol');
      return Future.value(cachedQuotes.first);
    }
    var url = "${Constants.robinHoodEndpoint}/quotes/$symbol/";
    var resultJson = await getJson(user, url);
    var quote = Quote.fromJson(resultJson);
    quotes.add(quote);

    return quote;
  }

  static Future<List<Quote>> getQuoteByInstrumentUrls(
      RobinhoodUser user, List<String> instrumentUrls) async {
    if (instrumentUrls.isEmpty) {
      return Future.value([]);
    }

    var cached =
        quotes.where((element) => instrumentUrls.contains(element.instrument));

    if (cached.isNotEmpty && instrumentUrls.length == cached.length) {
      print('Returned quotes from cache ${instrumentUrls.join(",")}');
      return Future.value(cached.toList());
    }

    var nonCached = instrumentUrls.where((element) =>
        !cached.any((cachedQuote) => cachedQuote.symbol == element));
    var url =
        "${Constants.robinHoodEndpoint}/marketdata/quotes/?bounds=trading&include_inactive=true&instruments=${Uri.encodeComponent(nonCached.join(","))}";
    // https://api.robinhood.com/marketdata/quotes/?bounds=trading&include_inactive=true&instruments=https%3A%2F%2Fapi.robinhood.com%2Finstruments%2F6c62bf75-bc42-457a-8c58-24097799966b%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2Febab2398-028d-4939-9f1d-13bf38f81c50%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2Fcd822b83-39cd-49b5-a33b-9a08eb3f5103%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2F17302400-f9c0-423b-b370-beaf6cee021b%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2F24fb7b13-6679-40a5-9eba-360d648f9ea3%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2Ff1adc843-1a28-4cc5-b6d2-082271fdd126%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2F3a47ca97-d5a2-4a55-9045-053a588894de%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2Fb2e06903-5c44-46a4-bd42-2a696f9d68e1%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2F8a9fe49d-5d0a-4040-a19b-f3f4df44408f%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2F2ed64ef4-2c1a-44d6-832d-1be84741dc41%2F
    var resultJson = await getJson(user, url);

    List<Quote> list = cached.toList();
    for (var i = 0; i < resultJson['results'].length; i++) {
      var result = resultJson['results'][i];
      var op = Quote.fromJson(result);
      list.add(op);
    }
    return list;
  }

  static Future<List<Quote>> getQuoteByIds(
      RobinhoodUser user, List<String> symbols) async {
    var cached = quotes.where((element) => symbols.contains(element.symbol));
    var nonCachedSymbols = symbols.where((element) =>
        !cached.any((cachedQuote) => cachedQuote.symbol == element));
    var url =
        "${Constants.robinHoodEndpoint}/quotes/?symbols=${Uri.encodeComponent(nonCachedSymbols.join(","))}";
    // https://api.robinhood.com/marketdata/quotes/?bounds=trading&include_inactive=true&instruments=https%3A%2F%2Fapi.robinhood.com%2Finstruments%2F6c62bf75-bc42-457a-8c58-24097799966b%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2Febab2398-028d-4939-9f1d-13bf38f81c50%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2Fcd822b83-39cd-49b5-a33b-9a08eb3f5103%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2F17302400-f9c0-423b-b370-beaf6cee021b%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2F24fb7b13-6679-40a5-9eba-360d648f9ea3%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2Ff1adc843-1a28-4cc5-b6d2-082271fdd126%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2F3a47ca97-d5a2-4a55-9045-053a588894de%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2Fb2e06903-5c44-46a4-bd42-2a696f9d68e1%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2F8a9fe49d-5d0a-4040-a19b-f3f4df44408f%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2F2ed64ef4-2c1a-44d6-832d-1be84741dc41%2F
    var resultJson = await getJson(user, url);

    List<Quote> list = cached.toList();
    for (var i = 0; i < resultJson['results'].length; i++) {
      var result = resultJson['results'][i];
      var op = Quote.fromJson(result);
      list.add(op);
    }
    return list;
  }

  static Future<Fundamentals> getFundamentals(
      RobinhoodUser user, Instrument instrumentObj) async {
    var resultJson = await getJson(user, instrumentObj.fundamentals);

    var oi = Fundamentals.fromJson(resultJson);

    return oi;
  }

  static Future<List<Split>> getSplits(
      RobinhoodUser user, Instrument instrumentObj) async {
    print(instrumentObj.splits);
    var results = await RobinhoodService.pagedGet(user, instrumentObj.splits);
    List<Split> splits = [];
    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      var op = Split.fromJson(result);
      splits.add(op);
    }
    return splits;
  }

  /* 
  OPTIONS
  */

  /* NOT USED, streamOptionPositionList return Stream<List> vs this Stream which does not accumulate only emits.
  static Stream<OptionPosition> streamOptionPositions(RobinhoodUser user,
      {bool includeOpen = true, bool includeClosed = false}) async* {
    List<OptionPosition> optionPositions =
        await getOptionPositions(user, includeOpen, includeClosed);
    List<String> optionIds =
        optionPositions.map((e) => e.option).toSet().toList();
    for (var i = 0; i < optionIds.length; i++) {
      var optionInstrument = await downloadOptionInstrument(user, optionIds[i]);

      var optionMarketData =
          await downloadOptionMarketData(user, optionInstrument);

      optionInstrument.optionMarketData = optionMarketData;
      for (var j = 0; j < optionPositions.length; j++) {
        if (optionPositions[j].option == optionIds[i]) {
          optionPositions[j].optionInstrument = optionInstrument;
          yield optionPositions[j];
        }
      }
    }
  }
  */

  static Stream<List<OptionAggregatePosition>>
      streamOptionAggregatePositionList(RobinhoodUser user,
          {bool nonzero = true}) async* {
    List<OptionAggregatePosition> ops =
        await getAggregateOptionPositions(user, nonzero: nonzero);
    /*
    for (var optionPosition in optionPositions) {
      if (((includeOpen && optionPosition.quantity! > 0) ||
              (includeClosed && optionPosition.quantity! <= 0)) &&
          (filters.isEmpty || filters.contains(optionPosition.symbol))) {}
      var optionInstrument = await getOptionInstrument(user, optionPosition.id);

      var optionMarketData = await getOptionMarketData(user, optionInstrument);

      optionInstrument.optionMarketData = optionMarketData;

      optionPosition.optionInstrument = optionInstrument;

      optionPositions.sort((a, b) => (a.optionInstrument?.expirationDate! ??
              DateTime.now())
          .compareTo((b.optionInstrument?.expirationDate! ?? DateTime.now())));
      yield optionPositions;
    }
    */

    var len = ops.length;
    var size = 15; //17;
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

        // TODO: remove in favor of flat below
        optionPosition.optionInstrument!.optionMarketData = optionMarketDatum;
        optionPosition.marketData = optionMarketDatum;

        ops.sort((a, b) => (a.legs.first.expirationDate ?? DateTime.now())
            .compareTo((b.legs.first.expirationDate ?? DateTime.now())));
        yield ops;
      }
      /*
      for (var i = 0; i < optionMarketData.length; i++) {
        optionPositions.singleWhere(
            (element) => element.id == optionMarketData[i].instrumentId);
      }
      */
    }
    /*
    for (var i = 0; i < optionIds.length; i++) {
      var optionInstrument = await getOptionInstrument(user, optionIds[i]);

      var optionMarketData = await getOptionMarketData(user, optionInstrument);

      optionInstrument.optionMarketData = optionMarketData;

      for (var j = 0; j < optionPositions.length; j++) {
        if (optionPositions[j].legs.first.option == optionIds[i]) {
          if (optionPositions[j].optionInstrument == null) {
            optionPositions[j].optionInstrument = optionInstrument;
          } else {
            print("optionPositions: ${j}");
            //print("${jsonEncode(optionPositions[j])}");
          }
          //yield optionPositions[j];
          //yield optionPositions;
        }
      }
      optionPositions.sort((a, b) => (a.optionInstrument?.expirationDate! ??
              DateTime.now())
          .compareTo((b.optionInstrument?.expirationDate! ?? DateTime.now())));
      yield optionPositions;
    }
    yield optionPositions;
    */
    // Persist in static value
    optionPositions = ops;
  }

  /*
  static Stream<List<OptionPosition>> streamOptionPositionList(
      RobinhoodUser user,
      {bool includeOpen = true,
      bool includeClosed = false,
      List<String> filters = const []}) async* {
    List<OptionPosition> optionPositions =
        await getOptionPositions(user, includeOpen, includeClosed, filters);
    List<String> optionIds =
        optionPositions.map((e) => e.option).toSet().toList();
    for (var i = 0; i < optionIds.length; i++) {
      var optionInstrument = await getOptionInstrument(user, optionIds[i]);

      var optionMarketData = await getOptionMarketData(user, optionInstrument);

      optionInstrument.optionMarketData = optionMarketData;

      for (var j = 0; j < optionPositions.length; j++) {
        if (optionPositions[j].option == optionIds[i]) {
          if (optionPositions[j].optionInstrument == null) {
            optionPositions[j].optionInstrument = optionInstrument;
          } else {
            print("optionPositions: ${j}");
            //print("${jsonEncode(optionPositions[j])}");
          }
          //yield optionPositions[j];
          //yield optionPositions;
        }
      }
      optionPositions.sort((a, b) => (a.optionInstrument?.expirationDate! ??
              DateTime.now())
          .compareTo((b.optionInstrument?.expirationDate! ?? DateTime.now())));
      yield optionPositions;
    }
    yield optionPositions;
  }
  */

  static Future<List<OptionAggregatePosition>> getAggregateOptionPositions(
      RobinhoodUser user,
      {bool nonzero = true}) async {
    List<OptionAggregatePosition> optionPositions = [];

    var results = await RobinhoodService.pagedGet(user,
        "${Constants.robinHoodEndpoint}/options/aggregate_positions/?nonzero=${nonzero}"); // ?nonzero=true

    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      var op = OptionAggregatePosition.fromJson(result);
      optionPositions.add(op);
    }
    return optionPositions;
  }

  /*
  static Future<List<OptionPosition>> getOptionPositions(RobinhoodUser user,
      bool includeOpen, bool includeClosed, List<String> filters) async {
    var resultJson = await getJson(user, '${Constants.robinHoodEndpoint}/options/positions/');
    List<OptionPosition> optionPositions = [];
    for (var i = 0; i < resultJson['results'].length; i++) {
      var result = resultJson['results'][i];
      var op = OptionPosition.fromJson(result);
      if (((includeOpen && op.quantity! > 0) ||
              (includeClosed && op.quantity! <= 0)) &&
          (filters.isEmpty || filters.contains(op.chainSymbol))) {
        optionPositions.add(op);
      }
    }
    return optionPositions;
  }
  */

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

  static Stream<List<OptionInstrument>> streamOptionInstruments(
      RobinhoodUser user,
      Instrument instrument,
      String? expirationDates, // 2021-03-05
      String? type, // call or put
      {String? state = "active"}) async* {
    // options/chain (see below)
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
    print(url);

    List<OptionInstrument> optionInstruments = [];

    var pageStream = RobinhoodService.streamedGet(user, url);
    await for (final results in pageStream) {
      for (var i = 0; i < results.length; i++) {
        var result = results[i];
        var op = OptionInstrument.fromJson(result);
        if (!optionInstruments.any((element) => element.id == op.id)) {
          optionInstruments.add(op);
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

/*
  // scopes: [acats, balances, document_upload, edocs, funding:all:read, funding:ach:read, funding:ach:write, funding:wire:read, funding:wire:write, internal, investments, margin, read, signup, trade, watchlist, web_limited])
  Request to https://api.robinhood.com/marketdata/options/?instruments=942d3704-7247-454f-9fb6-1f98f5d41702 failed with status 400: Bad Request.
  */

  static Future<OptionMarketData?> getOptionMarketData(
      RobinhoodUser user, OptionInstrument optionInstrument) async {
    var url =
        "${Constants.robinHoodEndpoint}/marketdata/options/?instruments=${Uri.encodeQueryComponent(optionInstrument.url)}";
    print(url);
    var resultJson = await getJson(user, url);
    var firstResult = resultJson['results'][0];
    if (firstResult != null) {
      var oi = OptionMarketData.fromJson(firstResult);
      return oi;
    } else {
      return Future.value(null);
    }
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

  static Stream<List<OptionOrder>> streamOptionOrders(
      RobinhoodUser user) async* {
    List<OptionOrder> list = [];
    var pageStream = RobinhoodService.streamedGet(user,
        "${Constants.robinHoodEndpoint}/options/orders/"); // ?chain_id=${instrument.tradeableChainId}
    //print(results);
    await for (final results in pageStream) {
      for (var i = 0; i < results.length; i++) {
        var result = results[i];
        var op = OptionOrder.fromJson(result);
        if (!list.any((element) => element.id == op.id)) {
          list.add(op);
          yield list;
        }
      }
      list.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
      yield list;
    }
    optionOrders = list;
  }

  /*
  static Future<List<OptionOrder>> getOptionOrders(RobinhoodUser user) async {
    // , Instrument instrument
    var results = await RobinhoodService.pagedGet(user,
        "${Constants.robinHoodEndpoint}/options/orders/"); // ?chain_id=${instrument.tradeableChainId}
    //print(results);
    List<OptionOrder> optionOrders = [];
    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      // print(result["id"]);
      var op = OptionOrder.fromJson(result);
      optionOrders.add(op);
    }
    return optionOrders;
  }
  */

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

  static Future<List<Holding>> getNummusHoldings(RobinhoodUser user) async {
    /*
    var holdings = await RobinhoodService.pagedGet(
        user, "${Constants.robinHoodNummusEndpoint}/holdings/");

    List<Holding> list = [];
    for (var i = 0; i < holdings.length; i++) {
      var result = holdings[i];
      var op = Holding.fromJson(result);
      list.add(op);
    }

    var pairs = await RobinhoodService.getForexPairs(user);
    List<dynamic> pairResults = pairs['results'];
    var pairHoldings = pairResults.where((element) => list.any(
        (listitem) => element['asset_currency']['id'] == listitem.currencyId));
    var pairHoldingIds = pairHoldings.map((e) => e['id'].toString()).toList();
    var quotes = await getForexQuoteByIds(user, pairHoldingIds);
    for (var quote in quotes['results']) {
      var holding =
          list.firstWhere((element) => element.currencyId == quote['id']);
      holding.quote = quote;
      holding.value = double.tryParse(holding.quote['mark_price']);
    }
    */

    var results = await RobinhoodService.pagedGet(
        user, "${Constants.robinHoodNummusEndpoint}/holdings/");
    var quotes = await RobinhoodService.getForexPairs(user);
    List<Holding> list = [];
    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      var op = Holding.fromJson(result);
      for (var j = 0; j < quotes['results'].length; j++) {
        var quote = quotes['results'][j];
        var assetCurrencyId = quote['asset_currency']['id'];
        if (assetCurrencyId == op.currencyId) {
          //op.quote = quotes['results'][j];

          op.quote = await getForexQuote(user, quote['id']);
          op.value = double.tryParse(op.quote['mark_price']);
          break;
        }
      }
      // TODO: Not working 404 on quote, 400 on historicals
      //op.quote = await getForexQuote(user, op.currencyId);
      list.add(op);
    }

    return list;
  }

  static Future<dynamic> getForexQuote(RobinhoodUser user, String id) async {
    //id = "3d961844-d360-45fc-989b-f6fca761d511"; // BTC-USD pair
    //id = "d674efea-e623-4396-9026-39574b92b093"; // BTC currency
    //id = "1072fc76-1862-41ab-82c2-485837590762"; // USD currency
    String url = "${Constants.robinHoodEndpoint}/marketdata/forex/quotes/$id/";
    var resultJson = await getJson(user, url);
    return resultJson;
  }

  static Future<dynamic> getForexQuoteByIds(
      RobinhoodUser user, List<String> ids) async {
    //id = "3d961844-d360-45fc-989b-f6fca761d511"; // BTC-USD pair
    //id = "d674efea-e623-4396-9026-39574b92b093"; // BTC currency
    //id = "1072fc76-1862-41ab-82c2-485837590762"; // USD currency
    String url =
        "${Constants.robinHoodEndpoint}/marketdata/forex/quotes/?ids=${Uri.encodeComponent(ids.join(","))}";
    var resultJson = await getJson(user, url);

    return resultJson;
  }

  static Future<dynamic> getForexHistoricals(
      RobinhoodUser user, List<String> ids) async {
    String url =
        "${Constants.robinHoodEndpoint}/marketdata/forex/historicals/?ids=${Uri.encodeComponent(ids.join(","))}";
    var resultJson = await getJson(user, url);
    return resultJson;
  }

  static Future<dynamic> getForexPairs(RobinhoodUser user) async {
    String url = '${Constants.robinHoodNummusEndpoint}/currency_pairs/';
    var resultJson = await getJson(user, url);
    return resultJson;
  }

  /*
  TRADING
  */

  static Future<dynamic> buyOptionLimit(
      RobinhoodUser user,
      Account account,
      Instrument instrument,
      String
          positionEffect, // Either 'open' for a buy to open effect or 'close' for a buy to close effect.
      String creditOrDebit, // Either 'debit' or 'credit'.
      double price, // Limit price to trigger a buy of the option.
      String symbol, // Ticker of the stock to trade.
      int quantity, // Number of options to buy.
      String
          expirationDate, // Expiration date of the option in 'YYYY-MM-DD' format.
      double strike, // The strike price of the option.
      String optionType, // This should be 'call' or 'put'
      {String timeInForce =
          'gtc' // How long order will be in effect. 'gtc' = good until cancelled. 'gfd' = good for the day. 'ioc' = immediate or cancel. 'opg' execute at opening.
      }) async {
    // instrument.tradeableChainId

    /*
    var payload = {
        'account': account.url,
        'direction': creditOrDebit,
        'time_in_force': timeInForce,
        'legs': [
            {
              'position_effect': positionEffect, 
              'side': 'buy',
              'ratio_quantity': 1, 
              'option': // option_instruments_url(optionID)
            },
        ],
        'type': 'limit',
        'trigger': 'immediate',
        'price': price,
        'quantity': quantity,
        'override_day_trade_checks': false,
        'override_dtbp_checks': false,
        'ref_id': str(uuid4()),
    }
    */
    var url = "${Constants.robinHoodEndpoint}/options/orders/";
    print(url);
    var result = await user.oauth2Client!.post(Uri.parse(url));

    return result;
  }

/*
WATCHLIST
*/
  static Stream<List<Watchlist>> streamLists(RobinhoodUser user) async* {
    List<Watchlist> list = [];
    var watchlistsUrl =
        "${Constants.robinHoodEndpoint}/midlands/lists/user_items/";
    var userItemsJson = await getJson(user, watchlistsUrl);
    for (var entry in userItemsJson.entries) {
      var watchlistUrl =
          "${Constants.robinHoodEndpoint}/midlands/lists/${entry.key}/?owner_type=custom";
      var entryJson = await getJson(user, watchlistUrl);

      var wl = Watchlist.fromJson(entryJson);

      list.add(wl);
      yield list;

      /*
      var instrumentIds = entry.value
          .where((e) => e['object_type'] == "instrument")
          .map((e) =>
              "https://api.robinhood.com/instruments/" +
              e['object_id'].toString())
          .toList();
      var quoteObjs = await getQuoteByInstrumentUrls(user, instrumentIds);
      for (var quoteObj in quoteObjs) {
        //var watchlistItem =
        //    new WatchlistItem(instrumentObj.id, DateTime.now(), entry.key, "");
        watchlistItem.instrumentObj!.quoteObj = quoteObj;
        yield list;
      }
      */

      var instrumentIds = entry.value
          .where((e) => e['object_type'] == "instrument")
          .map((e) => e['object_id'].toString())
          .toList();
      var instrumentObjs = await getInstrumentsByIds(user, instrumentIds);
      for (var instrumentObj in instrumentObjs) {
        var watchlistItem =
            new WatchlistItem(instrumentObj.id, DateTime.now(), entry.key, "");
        watchlistItem.instrumentObj = instrumentObj;
        wl.items.add(watchlistItem);
        yield list;
      }

      var instrumentUrls = wl.items
          .where((e) => e.instrumentObj != null)
          .map((e) => e.instrumentObj!.url)
          .toList();
      var quoteObjs = await getQuoteByInstrumentUrls(user, instrumentUrls);
      for (var quoteObj in quoteObjs) {
        var watchlistItem = wl.items
            .where(
                (element) => element.instrumentObj!.symbol == quoteObj.symbol)
            .first;
        watchlistItem.instrumentObj!.quoteObj = quoteObj;
        yield list;
      }
      /*
      for (var val in entry.value) {
        if (val['object_type'] != "instrument") {
          continue;
        }
        var watchlistItem =
            new WatchlistItem(val['object_id'], DateTime.now(), entry.key, "");

        var instrumentObj = await getInstrument(user,
            "${Constants.robinHoodEndpoint}/instruments/${watchlistItem.instrument}");
        watchlistItem.instrumentObj = instrumentObj;

        if (watchlistItem.instrumentObj != null) {
          var quoteObj =
              await getQuote(user, watchlistItem.instrumentObj!.symbol);
          watchlistItem.instrumentObj!.quoteObj = quoteObj;
        }

        wl.items.add(watchlistItem);
        yield list;
      }
      */
    }

    /*
    for (var entry in userItemsJson.entries) {
      var wl =
          list.singleWhere((element) => element.displayName == entry.key);
      List<dynamic> instruments = entry.value
          .where((e) => e['object_type'] == "instrument")
          .toList();
      // type 'MappedIterable<dynamic, dynamic>' is not a subtype of type 'List<String>'

      var len = instruments.length;
      var size = 15;
      List<List<dynamic>> chunks = [];
      for (var i = 0; i < len; i += size) {
        var end = (i + size < len) ? i + size : len;
        chunks.add(instruments.sublist(i, end));
      }
      for (var chunk in chunks) {
        var instrumentIds =
            chunk.map((e) => e['object_id'].toString()).toList();

        //var instrumentIds =
        //    instruments.map((e) => e['object_id'].toString()).toList();
        var instrumentObjs = await getInstrumentByIds(user, instrumentIds);

        for (var instrumentObj in instrumentObjs) {
          var watchlistItem = new WatchlistItem(
              instrumentObj.id, DateTime.now(), entry.key, "");
          watchlistItem.instrumentObj = instrumentObj;

          wl.items!.add(watchlistItem);
          yield list;
        //if (watchlistItem.instrumentObj != null) {
        //  var quoteObj =
        //      await getQuote(user, watchlistItem.instrumentObj!.symbol);
        //  watchlistItem.instrumentObj!.quoteObj = quoteObj;
        //  yield list;
        //}
        }
        var symbols = wl.items!.map((e) => e.instrumentObj!.symbol).toList();
        var quotes = await getQuoteById(user, symbols);
        for (var quote in quotes) {
          var watchlistItem = wl.items!.where(
              (element) => element.instrumentObj!.symbol == quote.symbol);
          watchlistItem.first.instrumentObj!.quoteObj = quote;
        }
      }
      yield list;
    }
      */
  }

  /*
  static Stream<List<WatchlistItem>> streamWatchlists(
      RobinhoodUser user) async* {
    List<WatchlistItem> watchlistItems = [];

    var pageStream = RobinhoodService.streamedGet(user,
        "${Constants.robinHoodEndpoint}/watchlists/Default/"); // ?chain_id=${instrument.tradeableChainId}
    //print(results);
    await for (final results in pageStream) {
      for (var i = 0; i < results.length; i++) {
        var result = results[i];
        var op = WatchlistItem.fromJson(result);

        var instrumentObj = await getInstrument(user, op.instrument);
        op.instrumentObj = instrumentObj;

        var quoteObj = await getQuote(user, op.instrumentObj!.symbol);
        op.instrumentObj!.quoteObj = quoteObj;

        watchlistItems.add(op);
        yield watchlistItems;
      }
      watchlistItems.sort((a, b) => b.watchlist.compareTo(a.watchlist));
      yield watchlistItems;
    }
  }

  static Future<List<WatchlistItem>> getWatchlists(RobinhoodUser user) async {
    var results = [];
    try {
      results = await RobinhoodService.pagedGet(
          user, "${Constants.robinHoodEndpoint}/watchlists/Default/");
    } on Exception catch (e) {
      // Format
      print('No watchlist found. Error: $e');
    }
    List<WatchlistItem> watchlistItems = [];
    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      var op = WatchlistItem.fromJson(result);
      watchlistItems.add(op);
    }
    var instrumentUrls = watchlistItems.map((e) => e.instrument).toList();
    List<String> distinctInstrumentUrls = [
      ...{...instrumentUrls}
    ];
    for (var i = 0; i < distinctInstrumentUrls.length; i++) {
      print(distinctInstrumentUrls[i]);
      var instrumentJson = await getJson(user, distinctInstrumentUrls[i]);
      var instrument = Instrument.fromJson(instrumentJson);
      var itemsToUpdate = watchlistItems
          .where((element) => element.instrument == distinctInstrumentUrls[i]);
      for (var element in itemsToUpdate) {
        element.instrumentObj = instrument;
      }
    }
    return watchlistItems;
  }

  static Future<List<dynamic>> getWatchlist(
      RobinhoodUser user, String url) async {
    var results = await RobinhoodService.pagedGet(
        user, "${Constants.robinHoodEndpoint}/watchlists/Default/");
    List<WatchlistItem> watchlistItems = [];
    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      var op = WatchlistItem.fromJson(result);
      watchlistItems.add(op);
    }
    var instrumentUrls = watchlistItems.map((e) => e.instrument).toList();
    List<String> distinctInstrumentUrls = [
      ...{...instrumentUrls}
    ];
    for (var i = 0; i < distinctInstrumentUrls.length; i++) {
      var instrumentJson = await getJson(user, distinctInstrumentUrls[i]);
      var instrument = Instrument.fromJson(instrumentJson);
      var itemsToUpdate = watchlistItems
          .where((element) => element.instrument == distinctInstrumentUrls[i]);
      for (var element in itemsToUpdate) {
        element.instrumentObj = instrument;
      }
    }
    return watchlistItems;
  }
  */

  /* COMMON */
  // SocketException (SocketException: Failed host lookup: 'loadbalancer-brokeback.nginx.service.robinhood' (OS Error: No address associated with hostname, errno = 7))
  static Future<dynamic> getJson(RobinhoodUser user, String url) async {
    // print(url);
    Stopwatch stopwatch = new Stopwatch();
    stopwatch.start();
    String responseStr = await user.oauth2Client!.read(Uri.parse(url));
    print(
        "${(responseStr.length / 1000)}K in ${stopwatch.elapsed.inMilliseconds} ${url}");
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

# Stocks


def earnings_url():
    return('https://api.robinhood.com/marketdata/earnings/')


def events_url():
    return('https://api.robinhood.com/options/events/')


def fundamentals_url():
    return('https://api.robinhood.com/fundamentals/')


def historicals_url():
    return('https://api.robinhood.com/quotes/historicals/')


def instruments_url():
    return('https://api.robinhood.com/instruments/')


def news_url(symbol):
    return('https://api.robinhood.com/midlands/news/{0}/?'.format(symbol))


def popularity_url(symbol):
    return('https://api.robinhood.com/instruments/{0}/popularity/'.format(id_for_stock(symbol)))

def quotes_url():
    return('https://api.robinhood.com/quotes/')


def ratings_url(symbol):
    return('https://api.robinhood.com/midlands/ratings/{0}/'.format(id_for_stock(symbol)))


def splits_url(symbol):
    return('https://api.robinhood.com/instruments/{0}/splits/'.format(id_for_stock(symbol)))

# account

def phoenix_url():
    return('https://phoenix.robinhood.com/accounts/unified')

def positions_url():
    return('https://api.robinhood.com/positions/')

def banktransfers_url(direction=None):
    if direction == 'received':
        return('https://api.robinhood.com/ach/received/transfers/')
    else:
        return('https://api.robinhood.com/ach/transfers/')

def cardtransactions_url():
   return('https://minerva.robinhood.com/history/transactions/')

def daytrades_url(account):
    return('https://api.robinhood.com/accounts/{0}/recent_day_trades/'.format(account))


def dividends_url():
    return('https://api.robinhood.com/dividends/')


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


// URLS DO NOT WORK
def watchlists_url(name=None, add=False):
    if name:
        return('https://api.robinhood.com/midlands/lists/items/')
    else:
        return('https://api.robinhood.com/midlands/lists/default/')


# markets


def currency_url():
    return('https://nummus.robinhood.com/currency_pairs/')

def markets_url():
    return('https://api.robinhood.com/markets/')

def market_hours_url(market, date):
    return('https://api.robinhood.com/markets/{}/hours/{}/'.format(market, date))

def movers_sp500_url():
    return('https://api.robinhood.com/midlands/movers/sp500/')

def get_100_most_popular_url():
    return('https://api.robinhood.com/midlands/tags/tag/100-most-popular/')

def movers_top_url():
    return('https://api.robinhood.com/midlands/tags/tag/top-movers/')

def market_category_url(category):
    return('https://api.robinhood.com/midlands/tags/tag/{}/'.format(category))

# options


def aggregate_url():
    return('https://api.robinhood.com/options/aggregate_positions/')


def chains_url(symbol):
    return('https://api.robinhood.com/options/chains/{0}/'.format(id_for_chain(symbol)))


def option_historicals_url(id):
    return('https://api.robinhood.com/marketdata/options/historicals/{0}/'.format(id))


def option_instruments_url(id=None):
    if id:
        return('https://api.robinhood.com/options/instruments/{0}/'.format(id))
    else:
        return('https://api.robinhood.com/options/instruments/')


def option_orders_url(orderID=None):
    if orderID:
        return('https://api.robinhood.com/options/orders/{0}/'.format(orderID))
    else:
        return('https://api.robinhood.com/options/orders/')


def option_positions_url():
    return('https://api.robinhood.com/options/positions/')


def marketdata_options_url():
    return('https://api.robinhood.com/marketdata/options/')

# pricebook


def marketdata_quotes_url(id):
    return ('https://api.robinhood.com/marketdata/quotes/{0}/'.format(id))


def marketdata_pricebook_url(id):
    return ('https://api.robinhood.com/marketdata/pricebook/snapshots/{0}/'.format(id))

# crypto


def order_crypto_url():
    return('https://nummus.robinhood.com/orders/')


def crypto_account_url():
    return('https://nummus.robinhood.com/accounts/')


def crypto_currency_pairs_url():
    return('https://nummus.robinhood.com/currency_pairs/')


def crypto_quote_url(id):
    return('https://api.robinhood.com/marketdata/forex/quotes/{0}/'.format(id))


def crypto_holdings_url():
    return('https://nummus.robinhood.com/holdings/')


def crypto_historical_url(id):
    return('https://api.robinhood.com/marketdata/forex/historicals/{0}/'.format(id))


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
