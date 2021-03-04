import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/option_marketdata.dart';

/*
{
  "chain_id":"1ac71e01-0677-42c6-a490-1457980954f8",
  "chain_symbol":"MSFT",
  "created_at":"2020-08-20T07:32:27.513753Z",
  "expiration_date":"2021-04-16",
  "id":"f48cc8d3-cb4f-42bb-8c89-4f53ce43aebc",
  "issue_date":"1987-03-12",
  "min_ticks":{
    "above_tick":"0.05","
    below_tick":"0.01",
    "cutoff_price":"3.00"
  },
  "rhs_tradability":"untradable",
  "state":"active",
  "strike_price":"255.0000",
  "tradability":"tradable",
  "type":"call",
  "updated_at":"2020-08-20T07:32:27.513761Z",
  "url":"https:\/\/api.robinhood.com\/options\/instruments\/f48cc8d3-cb4f-42bb-8c89-4f53ce43aebc\/",
  "sellout_datetime":"2021-04-16T19:00:00+00:00"
}
*/

@immutable
class MinTicks {
  final double aboveTick;
  final double belowTick;
  final double cutoffPrice;
  MinTicks(this.aboveTick, this.belowTick, this.cutoffPrice);
}

//@immutable
class OptionInstrument {
  final String chainId;
  final String chainSymbol;
  final DateTime createdAt;
  final DateTime expirationDate;
  final String id;
  final DateTime issueDate;
  final MinTicks minTicks;

  final String rhsTradability;
  final String state;
  final double strikePrice;
  final String tradability;
  final String type;
  final DateTime updatedAt;
  final String url;
  final DateTime selloutDateTime;

  OptionMarketData optionMarketData;

  OptionInstrument(
      this.chainId,
      this.chainSymbol,
      this.createdAt,
      this.expirationDate,
      this.id,
      this.issueDate,
      this.minTicks,
      this.rhsTradability,
      this.state,
      this.strikePrice,
      this.tradability,
      this.type,
      this.updatedAt,
      this.url,
      this.selloutDateTime);

  OptionInstrument.fromJson(dynamic json)
      : chainId = json['chain_id'],
        chainSymbol = json['chain_symbol'],
        createdAt = DateTime.tryParse(json['created_at']),
        expirationDate = DateTime.tryParse(json['expiration_date']),
        id = json['id'],
        issueDate = DateTime.tryParse(json['issue_date']),
        minTicks = MinTicks(
            double.tryParse(json['min_ticks']['above_tick']),
            double.tryParse(json['min_ticks']['below_tick']),
            double.tryParse(json['min_ticks']['cutoff_price'])),
        rhsTradability = json['rhsTradability'],
        state = json['state'],
        strikePrice = double.tryParse(json['strike_price']),
        tradability = json['tradability'],
        type = json['type'],
        updatedAt = DateTime.tryParse(json['updated_at']),
        url = json['url'],
        selloutDateTime = DateTime.tryParse(json['sellout_datetime']);
}
