import 'dart:convert';

import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/option_position.dart';
import 'package:robinhood_options_mobile/model/portfolio.dart';
import 'package:robinhood_options_mobile/model/position.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/robinhood_user.dart';
import 'package:robinhood_options_mobile/model/watchlist_item.dart';

class RobinhoodService {
/*
  // scopes: [acats, balances, document_upload, edocs, funding:all:read, funding:ach:read, funding:ach:write, funding:wire:read, funding:wire:write, internal, investments, margin, read, signup, trade, watchlist, web_limited])
  */

  static Future<List<Portfolio>> downloadPortfolios(RobinhoodUser user) async {
    //var results = await user.oauth2Client.read("${Constants.robinHoodEndpoint}/portfolios/");
    var results = await RobinhoodService.pagedGet(
        user, "${Constants.robinHoodEndpoint}/portfolios/");
    print(results);
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
      positions[i].instrumentObj = instrumentObj;
    }

    return positions;
  }

  static Future<Quote> downloadQuote(
      RobinhoodUser user, Instrument instrumentObj) async {
    print(instrumentObj.quote);
    var result = await user.oauth2Client.read("${instrumentObj.quote}");
    // print(result);

    var resultJson = jsonDecode(result);
    var oi = new Quote.fromJson(resultJson);

    return oi;
  }

  static Future<Instrument> downloadInstrument(
      RobinhoodUser user, String instrumentUrl) async {
    print(instrumentUrl);
    var result = await user.oauth2Client.read(instrumentUrl);
    // print(result);

    var resultJson = jsonDecode(result);
    var oi = new Instrument.fromJson(resultJson);

    return oi;
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
    //List<OptionInstrument> instruments = [];
    for (var i = 0; i < optionPositions.length; i++) {
      var optionInstrument =
          await downloadOptionInstrument(user, optionPositions[i]);
      optionPositions[i].optionInstrument = optionInstrument;
      //instruments.add(optionInstrument);
    }
    return optionPositions;
  }

  // https://api.robinhood.com/options/instruments/8b6ba744-7ef7-4b0e-845b-1a12f50c25fa/
  static Future<OptionInstrument> downloadOptionInstrument(
      RobinhoodUser user, OptionPosition optionPosition) async {
    print(optionPosition.option);
    var result = await user.oauth2Client.read("${optionPosition.option}");
    //print(result);

    var resultJson = jsonDecode(result);
    var oi = new OptionInstrument.fromJson(resultJson);

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
