import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/option_marketdata.dart';

@immutable
class MinTicks {
  final double? aboveTick;
  final double? belowTick;
  final double? cutoffPrice;
  const MinTicks(this.aboveTick, this.belowTick, this.cutoffPrice);
  Map<String, dynamic> toJson() => {
        'above_tick': aboveTick,
        'below_tick': belowTick,
        'cutoff_price': cutoffPrice
      };
}

//@immutable
class OptionInstrument {
  final String chainId;
  final String chainSymbol;
  final DateTime? createdAt;
  final DateTime? expirationDate;
  final String id;
  final DateTime? issueDate;
  final MinTicks minTicks;

  final String rhsTradability;
  final String state;
  final double? strikePrice;
  final String tradability;
  final String type;
  final DateTime? updatedAt;
  final String url;
  final DateTime? selloutDateTime;
  final String longStrategyCode;
  final String shortStrategyCode;

  OptionMarketData? optionMarketData;

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
      this.selloutDateTime,
      this.longStrategyCode,
      this.shortStrategyCode);

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
        rhsTradability = json['rhs_tradability'],
        state = json['state'],
        strikePrice = double.tryParse(json['strike_price']),
        tradability = json['tradability'],
        type = json['type'],
        updatedAt = DateTime.tryParse(json['updated_at']),
        url = json['url'],
        selloutDateTime = DateTime.tryParse(json['sellout_datetime']),
        longStrategyCode = json['long_strategy_code'],
        shortStrategyCode = json['short_strategy_code'];
}
