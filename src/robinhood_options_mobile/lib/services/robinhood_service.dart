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
import 'package:robinhood_options_mobile/model/option_position.dart';
import 'package:robinhood_options_mobile/model/portfolio.dart';
import 'package:robinhood_options_mobile/model/position.dart';
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
  static List<OptionOrder>? optionOrders;

  /*
  USERS & ACCOUNTS
  */

  static Future<User> getUser(RobinhoodUser user) async {
    print('${Constants.robinHoodEndpoint}/user/');
    var result = await user.oauth2Client!
        .read(Uri.parse('${Constants.robinHoodEndpoint}/user/'));
    // print(result);
    /*
    print('${Constants.robinHoodEndpoint}/user/basic_info/');
    var basicInfoResult = await user.oauth2Client!
        .read(Uri.parse('${Constants.robinHoodEndpoint}/user/basic_info/'));
    print('${Constants.robinHoodEndpoint}/user/investment_profile/');
    var investmentProfileResult = await user.oauth2Client!.read(
        Uri.parse('${Constants.robinHoodEndpoint}/user/investment_profile/'));
    print('${Constants.robinHoodEndpoint}/user/additional_info/');
    var additionalInfoResult = await user.oauth2Client!.read(
        Uri.parse('${Constants.robinHoodEndpoint}/user/additional_info/'));
        */

    var resultJson = jsonDecode(result);
    var usr = User.fromJson(resultJson);
    return usr;
  }

  static Future<List<Account>> getAccounts(RobinhoodUser user) async {
    //var results = await user.oauth2Client.read("${Constants.robinHoodEndpoint}/portfolios/");
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

  // Not working
  static Future<dynamic> getPortfolioHistoricals(
      RobinhoodUser user, String account) async {
    var results = await RobinhoodService.pagedGet(user,
        "${Constants.robinHoodEndpoint}/portfolios/historicals/"); //${account}/
    print(results);
    /*
    List<Portfolio> portfolios = [];
    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      var op = new Portfolio.fromJson(result);
      portfolios.add(op);
    }
    return portfolios;
    */
  }

  /*
  POSITIONS
  */

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

      /* TODO: Change to lazy loading. 
      var fundamentalsObj = await downloadFundamentals(user, instrumentObj);
      instrumentObj.fundamentalsObj = fundamentalsObj;
      */

      /* TODO: Change to lazy loading. 
      var splitsObj = await downloadSplits(user, instrumentObj);
      instrumentObj.splitsObj = splitsObj;
      */

      positions[i].instrumentObj = instrumentObj;
    }

    return positions;
  }

  static Stream<List<Position>> streamPositions(RobinhoodUser user,
      {bool withQuantity = true}) async* {
    List<Position> positions = [];
    var pageStream = RobinhoodService.streamedGet(
        user, "${Constants.robinHoodEndpoint}/positions/"); // ?nonzero=true
    //print(results);
    await for (final results in pageStream) {
      for (var i = 0; i < results.length; i++) {
        var result = results[i];
        var op = Position.fromJson(result);

        if ((withQuantity && op.quantity! > 0) ||
            (!withQuantity && op.quantity == 0)) {
          var instrumentObj = await getInstrument(user, op.instrument);
          //var quoteObj = await downloadQuote(user, instrumentObj);
          var quoteObj = await getQuote(user, instrumentObj.symbol);
          instrumentObj.quoteObj = quoteObj;

          /* TODO: Change to lazy loading. 
        var fundamentalsObj = await downloadFundamentals(user, instrumentObj);
        instrumentObj.fundamentalsObj = fundamentalsObj;
        */

          /* TODO: Change to lazy loading. 
        var splitsObj = await downloadSplits(user, instrumentObj);
        instrumentObj.splitsObj = splitsObj;
        */

          op.instrumentObj = instrumentObj;

          positions.add(op);
          yield positions;
        }
      }
      positions.sort((a, b) => a.createdAt!.compareTo(b.createdAt!));
      yield positions;
    }
  }

  /* 
  INSTRUMENTS
  */

  static Future<Instrument> getInstrument(
      RobinhoodUser user, String instrumentUrl) async {
    print(instrumentUrl);
    String? result;
    try {
      result = await user.oauth2Client!.read(Uri.parse(instrumentUrl));
    } on Exception catch (e) {
      // Format
      print('No instrument found. ${instrumentUrl} Error: $e');
    }
    if (result == null) {
      return Future.value(null);
    }
    var resultJson = jsonDecode(result);
    var oi = Instrument.fromJson(resultJson);
    return oi;
  }

  static Future<Quote> getQuote(RobinhoodUser user, String symbol) async {
    print("${Constants.robinHoodEndpoint}/quotes/$symbol/");
    String? result;
    try {
      result = await user.oauth2Client!.read(Uri.parse(
          "${Constants.robinHoodEndpoint}/quotes/$symbol/")); // https://api.robinhood.com/options/instruments/8b6ba744-7ef7-4b0e-845b-1a12f50c25fa/
    } on Exception catch (e) {
      // Format
      print('No quote found. $symbol Error: $e');
    }
    if (result == null) {
      return Future.value(null);
    }
    var resultJson = jsonDecode(result);
    var quote = Quote.fromJson(resultJson);
    return quote;
  }
  /*
  static Future<Quote> downloadQuote(
      RobinhoodUser user, Instrument instrumentObj) async {
    print(instrumentObj.quote);
    var result = await user.oauth2Client!.read(Uri.parse(instrumentObj.quote));
    //print(result);

    var resultJson = jsonDecode(result);
    var oi = Quote.fromJson(resultJson);

    return oi;
  }
  */

  static Future<Fundamentals> getFundamentals(
      RobinhoodUser user, Instrument instrumentObj) async {
    print(instrumentObj.fundamentals);
    var result =
        await user.oauth2Client!.read(Uri.parse(instrumentObj.fundamentals));
    //print(result);

    var resultJson = jsonDecode(result);
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
    List<OptionAggregatePosition> optionPositions =
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

    var len = optionPositions.length;
    var size = 10; //17;
    List<List<OptionAggregatePosition>> chunks = [];
    for (var i = 0; i < len; i += size) {
      var end = (i + size < len) ? i + size : len;
      chunks.add(optionPositions.sublist(i, end));
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
        var optionPosition = optionPositions.singleWhere((element) {
          var splits = element.legs.first.option.split("/");
          return splits[splits.length - 2] == optionInstrument.id;
        });

        optionPosition.optionInstrument = optionInstrument;
      }

      var optionMarketData = await getOptionMarketDataByIds(user, optionIds);

      for (var optionMarketDatum in optionMarketData) {
        var optionPosition = optionPositions.singleWhere((element) {
          var splits = element.legs.first.option.split("/");
          return splits[splits.length - 2] == optionMarketDatum.instrumentId;
        });

        // TODO: remove in favor of flat below
        optionPosition.optionInstrument!.optionMarketData = optionMarketDatum;
        optionPosition.marketData = optionMarketDatum;

        optionPositions.sort((a, b) =>
            (a.legs.first.expirationDate ?? DateTime.now())
                .compareTo((b.legs.first.expirationDate ?? DateTime.now())));
        yield optionPositions;
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
    var result = await user.oauth2Client!
        .read(Uri.parse('${Constants.robinHoodEndpoint}/options/positions/'));

    var resultJson = jsonDecode(result);
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
    print(option);
    var result = await user.oauth2Client!.read(Uri.parse(
        option)); // https://api.robinhood.com/options/instruments/8b6ba744-7ef7-4b0e-845b-1a12f50c25fa/

    var resultJson = jsonDecode(result);
    var oi = OptionInstrument.fromJson(resultJson);
    return oi;
  }

  static Future<List<OptionInstrument>> getOptionInstrumentByIds(
      RobinhoodUser user, List<String> ids) async {
    var url =
        "${Constants.robinHoodEndpoint}/options/instruments/?ids=${Uri.encodeComponent(ids.join(","))}";
    print(url);
    var result = await user.oauth2Client!.read(Uri.parse(url));
    var resultJson = jsonDecode(result);

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
    var result = await user.oauth2Client!.read(Uri.parse(url));
    var resultJson = jsonDecode(result);
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
    print(url);
    var result = await user.oauth2Client!.read(Uri.parse(url));
    var resultJson = jsonDecode(result);

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

  /*
  CRYPTO
  */

  static Future<dynamic> getNummusAccounts(RobinhoodUser user) async {
    var results = await user.oauth2Client!
        .read(Uri.parse('${Constants.robinHoodNummusEndpoint}/accounts/'));
    //var results = await RobinhoodService.pagedGet(user, "${Constants.robinHoodNummusEndpoint}/accounts/");
    //print(results);
    return results;
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
    print(url);
    var results = await user.oauth2Client!.read(Uri.parse(url));

    return jsonDecode(results);
  }

  static Future<dynamic> getForexQuoteByIds(
      RobinhoodUser user, List<String> ids) async {
    //id = "3d961844-d360-45fc-989b-f6fca761d511"; // BTC-USD pair
    //id = "d674efea-e623-4396-9026-39574b92b093"; // BTC currency
    //id = "1072fc76-1862-41ab-82c2-485837590762"; // USD currency
    String url =
        "${Constants.robinHoodEndpoint}/marketdata/forex/quotes/?ids=${Uri.encodeComponent(ids.join(","))}";
    print(url);
    var results = await user.oauth2Client!.read(Uri.parse(url));

    return jsonDecode(results);
  }

  static Future<dynamic> getForexHistoricals(
      RobinhoodUser user, List<String> ids) async {
    String url =
        "${Constants.robinHoodEndpoint}/marketdata/forex/historicals/?ids=${Uri.encodeComponent(ids.join(","))}";
    print(url);
    var results = await user.oauth2Client!.read(Uri.parse(url));
    return jsonDecode(results);
  }

  static Future<dynamic> getForexPairs(RobinhoodUser user) async {
    print('${Constants.robinHoodNummusEndpoint}/currency_pairs/');
    var results = await user.oauth2Client!.read(
        Uri.parse('${Constants.robinHoodNummusEndpoint}/currency_pairs/'));
    return jsonDecode(results);
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
    var userItemString =
        await user.oauth2Client!.read(Uri.parse(watchlistsUrl));
    var userItemsJson = jsonDecode(userItemString); // Map<String, List>
    for (var entry in userItemsJson.entries) {
      var watchlistUrl =
          "${Constants.robinHoodEndpoint}/midlands/lists/${entry.key}/?owner_type=custom";
      print(watchlistUrl);
      var entryString = await user.oauth2Client!.read(Uri.parse(watchlistUrl));
      //https://api.robinhood.com/midlands/lists/c9649938-4a7f-429e-b579-24a45e939a82/?owner_type=custom
      var entryJson = jsonDecode(entryString);
      var wl = Watchlist.fromJson(entryJson);
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

        wl.items!.add(watchlistItem);
      }
      list.add(wl);
      yield list;
    }
  }

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

        /*
        var instrumentResponse =
            await user.oauth2Client!.read(Uri.parse(op.instrument));
        var instrument = Instrument.fromJson(jsonDecode(instrumentResponse));
        */
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
      var instrumentResponse =
          await user.oauth2Client!.read(Uri.parse(distinctInstrumentUrls[i]));
      var instrument = Instrument.fromJson(jsonDecode(instrumentResponse));
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
      var instrumentResponse =
          await user.oauth2Client!.read(Uri.parse(distinctInstrumentUrls[i]));
      var instrument = Instrument.fromJson(jsonDecode(instrumentResponse));
      var itemsToUpdate = watchlistItems
          .where((element) => element.instrument == distinctInstrumentUrls[i]);
      for (var element in itemsToUpdate) {
        element.instrumentObj = instrument;
      }
    }
    return watchlistItems;
  }

  /* COMMON */

  static Future<dynamic> getJson(RobinhoodUser user, String url) async {
    print(url);
    String responseStr = await user.oauth2Client!.read(Uri.parse(url));
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
    while (nextUrl != null && (pages == 0 || page < pages)) {
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

def portfolis_historicals_url(account_number):
    return('https://api.robinhood.com/portfolios/historicals/{0}/'.format(account_number))

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
