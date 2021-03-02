import 'dart:convert';

import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/fundamentals.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/option_marketdata.dart';
import 'package:robinhood_options_mobile/model/option_position.dart';
import 'package:robinhood_options_mobile/model/portfolio.dart';
import 'package:robinhood_options_mobile/model/position.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/robinhood_user.dart';
import 'package:robinhood_options_mobile/model/split.dart';
import 'package:robinhood_options_mobile/model/watchlist_item.dart';

class RobinhoodService {
/*
  // scopes: [acats, balances, document_upload, edocs, funding:all:read, funding:ach:read, funding:ach:write, funding:wire:read, funding:wire:write, internal, investments, margin, read, signup, trade, watchlist, web_limited])
  */

  static Future<List<Portfolio>> downloadPortfolios(RobinhoodUser user) async {
    //var results = await user.oauth2Client.read("${Constants.robinHoodEndpoint}/portfolios/");
    var results = await RobinhoodService.pagedGet(
        user, "${Constants.robinHoodEndpoint}/portfolios/");
    //print(results);
    // https://phoenix.robinhood.com/accounts/unified
    List<Portfolio> portfolios = [];
    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      var op = new Portfolio.fromJson(result);
      portfolios.add(op);
    }
    return portfolios;
  }

  static Future<List<Position>> downloadPositions(RobinhoodUser user,
      {bool withQuantity = true}) async {
    var results = await RobinhoodService.pagedGet(
        user, "${Constants.robinHoodEndpoint}/positions/");
    List<Position> positions = [];
    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      var op = new Position.fromJson(result);
      if ((withQuantity && op.quantity > 0) ||
          (!withQuantity && op.quantity == 0)) {
        positions.add(op);
      }
    }
    /*
    var instrumentUrls = positions.map((e) => e.instrument).toList();
    List<String> distinctInstrumentUrls = [
      ...{...instrumentUrls}
    ];
    for (var i = 0; i < distinctInstrumentUrls.length; i++) {
      var instrumentResponse =
          await user.oauth2Client.read(distinctInstrumentUrls[i]);
      var instrument = Instrument.fromJson(jsonDecode(instrumentResponse));
      var itemsToUpdate = positions
          .where((element) => element.instrument == distinctInstrumentUrls[i]);
      itemsToUpdate.forEach((element) {
        element.instrumentObj = instrument;
      });
    }
    */
    for (var i = 0; i < positions.length; i++) {
      var instrumentObj =
          await downloadInstrument(user, positions[i].instrument);

      var quoteObj = await downloadQuote(user, instrumentObj);
      instrumentObj.quoteObj = quoteObj;

      var fundamentalsObj = await downloadFundamentals(user, instrumentObj);
      instrumentObj.fundamentalsObj = fundamentalsObj;

      var splitsObj = await downloadSplits(user, instrumentObj);
      instrumentObj.splitsObj = splitsObj;

      positions[i].instrumentObj = instrumentObj;
    }

    return positions;
  }

  static Future<Instrument> downloadInstrument(
      RobinhoodUser user, String instrumentUrl) async {
    print(instrumentUrl);
    var result = await user.oauth2Client.read(instrumentUrl);
    //print(result);

    var resultJson = jsonDecode(result);
    var oi = new Instrument.fromJson(resultJson);

    return oi;
  }

  static Future<Quote> downloadQuote(
      RobinhoodUser user, Instrument instrumentObj) async {
    print(instrumentObj.quote);
    var result = await user.oauth2Client.read("${instrumentObj.quote}");
    //print(result);

    var resultJson = jsonDecode(result);
    var oi = new Quote.fromJson(resultJson);

    return oi;
  }

  static Future<Fundamentals> downloadFundamentals(
      RobinhoodUser user, Instrument instrumentObj) async {
    print(instrumentObj.fundamentals);
    var result = await user.oauth2Client.read("${instrumentObj.fundamentals}");
    //print(result);

    var resultJson = jsonDecode(result);
    var oi = new Fundamentals.fromJson(resultJson);

    return oi;
  }

  static Future<List<Split>> downloadSplits(
      RobinhoodUser user, Instrument instrumentObj) async {
    print(instrumentObj.splits);
    var results = await RobinhoodService.pagedGet(user, instrumentObj.splits);
    List<Split> splits = [];
    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      var op = new Split.fromJson(result);
      splits.add(op);
    }
    return splits;
  }

  static Future<List<OptionPosition>> downloadOptionPositions(
      RobinhoodUser user,
      {bool withQuantity = true}) async {
    var result = await user.oauth2Client
        .read("${Constants.robinHoodEndpoint}/options/positions/");
    //print(result);

    var resultJson = jsonDecode(result);
    List<OptionPosition> optionPositions = [];
    for (var i = 0; i < resultJson['results'].length; i++) {
      var result = resultJson['results'][i];
      var op = new OptionPosition.fromJson(result);
      if ((withQuantity && op.quantity > 0) ||
          (!withQuantity && op.quantity == 0)) {
        optionPositions.add(op);
      }
    }
    for (var i = 0; i < optionPositions.length; i++) {
      var optionInstrument =
          await downloadOptionInstrument(user, optionPositions[i]);

      var optionMarketData =
          await downloadOptionMarketData(user, optionInstrument);

      optionInstrument.optionMarketData = optionMarketData;

      // https://api.robinhood.com/options/aggregate_positions/40db41b7-f8a3-453b-b03c-8fc611c9b79d/
      // https://api.robinhood.com/options/positions/?filter_on_nonzero=true&nonzero=True&option_ids=9c85994d-1f5a-4818-98d1-886ea6f8e6dd
      // https://api.robinhood.com/options/positions/?nonzero=True&option_ids=9c85994d-1f5a-4818-98d1-886ea6f8e6dd

      /*
      var tmp = await user.oauth2Client.read(
          "${Constants.robinHoodEndpoint}/marketdata/options/?instruments=${Uri.encodeQueryComponent(optionInstrument.url)}");
      print(tmp);
      // https://api.robinhood.com/marketdata/options/?instruments=https%3A%2F%2Fapi.robinhood.com%2Finstruments%2Fda5fb84a-e6d4-467c-8a36-4feb9c2abf4d%2F
      */

      optionPositions[i].optionInstrument = optionInstrument;
    }
    return optionPositions;
  }

  // https://api.robinhood.com/options/instruments/8b6ba744-7ef7-4b0e-845b-1a12f50c25fa/
  static Future<OptionInstrument> downloadOptionInstrument(
      RobinhoodUser user, OptionPosition optionPosition) async {
    //https://api.robinhood.com/options/instruments/?chain_id=1ac71e01-0677-42c6-a490-1457980954f8&expiration_dates=2021-03-05&state=active&type=call
    // or
    // https://api.robinhood.com/options/instruments/?chain_id=1ac71e01-0677-42c6-a490-1457980954f8&expiration_dates=2021-03-05&state=active&type=call
    print(optionPosition.option);
    var result = await user.oauth2Client.read("${optionPosition.option}");
    //print(result);

    var resultJson = jsonDecode(result);
    var oi = new OptionInstrument.fromJson(resultJson);

    return oi;
  }

  static Future<OptionMarketData> downloadOptionMarketData(
      RobinhoodUser user, OptionInstrument optionInstrument) async {
    // https://api.robinhood.com/marketdata/options/9c85994d-1f5a-4818-98d1-886ea6f8e6dd/
    // or
    // https://api.robinhood.com/marketdata/options/?instruments=https%3A%2F%2Fapi.robinhood.com%2Foptions%2Finstruments%2F189cd725-24ef-4ea7-9332-bca0ff697488%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Foptions%2Finstruments%2F9c85994d-1f5a-4818-98d1-886ea6f8e6dd%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Foptions%2Finstruments%2F8b6ba744-7ef7-4b0e-845b-1a12f50c25fa%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Foptions%2Finstruments%2F8278f44d-3d9c-4f9e-8479-896f47be5578%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Foptions%2Finstruments%2Ff48cc8d3-cb4f-42bb-8c89-4f53ce43aebc%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Foptions%2Finstruments%2Ff92b79bb-edff-449a-aa72-4c56235c3de2%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Foptions%2Finstruments%2Ff94e0dc3-9b11-4add-ac72-d2442c1ee0ab%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Foptions%2Finstruments%2F5afdafc3-8aa0-4b57-906a-bd3e72991df8%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Foptions%2Finstruments%2F078dc480-bd05-4836-9fba-7f29f17eff19%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Foptions%2Finstruments%2F436e1910-e884-4c37-b87f-2a0c59c02d9f%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Foptions%2Finstruments%2F942d3704-7247-454f-9fb6-1f98f5d41702%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Foptions%2Finstruments%2Fc9b32d07-30bf-420b-b18d-9e7b3f5b9de2%2F
    var url =
        "${Constants.robinHoodEndpoint}/marketdata/options/?instruments=${Uri.encodeQueryComponent(optionInstrument.url)}";
    print(url);
    var result = await user.oauth2Client.read(url);
    //print(result);

    var resultJson = jsonDecode(result);
    var oi = new OptionMarketData.fromJson(resultJson['results'][0]);

    return oi;
  }

  static Future<List<dynamic>> downloadWatchlists(RobinhoodUser user) async {
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
          await user.oauth2Client.read(distinctInstrumentUrls[i]);
      var instrument = Instrument.fromJson(jsonDecode(instrumentResponse));
      var itemsToUpdate = watchlistItems
          .where((element) => element.instrument == distinctInstrumentUrls[i]);
      itemsToUpdate.forEach((element) {
        element.instrumentObj = instrument;
      });
    }
    return watchlistItems;
  }

  static pagedGet(RobinhoodUser user, String url) async {
    var responseStr = await user.oauth2Client.read(url);
    var responseJson = jsonDecode(responseStr);
    var results = responseJson['results'];
    var nextUrl = responseJson['next'];
    while (nextUrl != null) {
      responseStr = await user.oauth2Client.read(nextUrl);
      results.push.apply(results, responseJson['results']);
      nextUrl = responseJson['next'];
    }
    return results;
  }
}
