import 'package:flutter/material.dart';

@immutable
class MinTicks {
  final double aboveTick;
  final double belowTick;
  final double cutoffPrice;
  MinTicks(this.aboveTick, this.belowTick, this.cutoffPrice);
}

/*
  {"chain_id":"eefb80a4-efc0-4b5f-ba27-a7aa9a358469",
  "chain_symbol":"KODK",
  "created_at":"2021-01-14T05:32:04.917251Z",
  "expiration_date":"2021-03-19",
  "id":"c9b32d07-30bf-420b-b18d-9e7b3f5b9de2",
  "issue_date":"2013-12-20",
  "min_ticks":{
    "above_tick":"0.05",
    "below_tick":"0.01",
    "cutoff_price":"3.00"
  },
  "rhs_tradability":"untradable",
  "state":"active",
  "strike_price":"12.5000",
  "tradability":"tradable",
  "type":"put",
  "updated_at":"2021-01-14T05:32:04.917267Z",
  "url":"https:\/\/api.robinhood.com\/options\/instruments\/c9b32d07-30bf-420b-b18d-9e7b3f5b9de2\/",
  "sellout_datetime":"2021-03-19T19:00:00+00:00"}
*/
@immutable
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
