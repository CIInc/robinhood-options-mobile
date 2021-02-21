import 'dart:convert';

import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/option_position.dart';
import 'package:robinhood_options_mobile/model/robinhood_user.dart';

class RobinhoodService {
/*
  // scopes: [acats, balances, document_upload, edocs, funding:all:read, funding:ach:read, funding:ach:write, funding:wire:read, funding:wire:write, internal, investments, margin, read, signup, trade, watchlist, web_limited])
  */

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
    return optionPositions;
  }

  static Future<OptionInstrument> downloadOptionInstrument(
      RobinhoodUser user, OptionPosition optionPosition) async {
    var result = await user.oauth2Client.read("${optionPosition.option}"
        //"${Constants.robinHoodEndpoint}/marketdata/options/?instruments=${op.optionId}"
        );
    //print(result);

    var resultJson = jsonDecode(result);
    var oi = new OptionInstrument.fromJson(resultJson);

    return oi;
  }
}
