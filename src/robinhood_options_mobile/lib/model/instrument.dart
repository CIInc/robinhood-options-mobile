//import 'package:flutter/material.dart';

//@immutable
import 'package:robinhood_options_mobile/model/fundamentals.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/split.dart';

/*
{
  "id":"da5fb84a-e6d4-467c-8a36-4feb9c2abf4d",
  "url":"https:\/\/api.robinhood.com\/instruments\/da5fb84a-e6d4-467c-8a36-4feb9c2abf4d\/",
  "quote":"https:\/\/api.robinhood.com\/quotes\/QQQJ\/",
  "fundamentals":"https:\/\/api.robinhood.com\/fundamentals\/QQQJ\/",
  "splits":"https:\/\/api.robinhood.com\/instruments\/da5fb84a-e6d4-467c-8a36-4feb9c2abf4d\/splits\/",
  "state":"active",
  "market":"https:\/\/api.robinhood.com\/markets\/XNAS\/",
  "simple_name":null,
  "name":"Invesco Exchange-Traded Fund Trust II Invesco NASDAQ Next Gen 100 ETF",
  "tradeable":true,
  "tradability":"tradable",
  "symbol":"QQQJ",
  "bloomberg_unique":"EQ0000000088005853",
  "margin_initial_ratio":"0.5000",
  "maintenance_ratio":"0.2500",
  "country":"US",
  "day_trade_ratio":"0.2500",
  "list_date":"2020-10-13",
  "min_tick_size":null,
  "type":"etp",
  "tradable_chain_id":"2d9df0db-08b1-4ba6-bce6-2c502e5d88dd",
  "rhs_tradability":"tradable",
  "fractional_tradability":"tradable",
  "default_collar_fraction":"0.05",
  "ipo_access_status":null,
  "ipo_access_cob_deadline":null,
  "ipo_allocated_price":null,
  "ipo_customers_received":null,
  "ipo_customers_requested":null,
  "ipo_date":null,
  "ipo_s1_url":null,
  "is_spac":false
  }
*/
class Instrument {
  final String id;
  final String url;
  final String quote;
  final String fundamentals;
  final String splits;
  final String state;
  final String market;
  final String? simpleName;
  final String name;
  final bool tradeable;
  final String tradability;
  final String symbol;
  final String bloombergUnique;
  final double? marginInitialRatio;
  final double? maintenanceRatio;
  final String country;
  final double? dayTradeRatio;
  final DateTime? listDate;
  final double? minTickSize;
  final String type;
  final String? tradeableChainId;
  final String rhsTradability;
  final String fractionalTradability;
  final double? defaultCollarFraction;
  final String? ipoAccessStatus;
  final DateTime? ipoAccessCobDeadline;
  final double? ipoAllocatedPrice;
  final double? ipoCustomersReceived;
  final double? ipoCustomersRequested;
  final DateTime? ipoDate;
  final String? ipoS1Url;
  final bool isSpac;

  Quote? quoteObj;
  Fundamentals? fundamentalsObj;
  List<Split> splitsObj = [];

  Instrument(
      this.id,
      this.url,
      this.quote,
      this.fundamentals,
      this.splits,
      this.state,
      this.market,
      this.simpleName,
      this.name,
      this.tradeable,
      this.tradability,
      this.symbol,
      this.bloombergUnique,
      this.marginInitialRatio,
      this.maintenanceRatio,
      this.country,
      this.dayTradeRatio,
      this.listDate,
      this.minTickSize,
      this.type,
      this.tradeableChainId,
      this.rhsTradability,
      this.fractionalTradability,
      this.defaultCollarFraction,
      this.ipoAccessStatus,
      this.ipoAccessCobDeadline,
      this.ipoAllocatedPrice,
      this.ipoCustomersReceived,
      this.ipoCustomersRequested,
      this.ipoDate,
      this.ipoS1Url,
      this.isSpac);

  Instrument.fromJson(dynamic json)
      : id = json['id'],
        url = json['url'],
        quote = json['quote'],
        fundamentals = json['fundamentals'],
        splits = json['splits'],
        state = json['state'],
        market = json['market'],
        simpleName = json['simple_name'],
        name = json['name'],
        tradeable = json['tradeable'],
        tradability = json['tradability'],
        symbol = json['symbol'],
        bloombergUnique = json['bloomberg_unique'],
        marginInitialRatio = double.tryParse(json['margin_initial_ratio']),
        maintenanceRatio = double.tryParse(json['maintenance_ratio']),
        country = json['country'],
        dayTradeRatio = double.tryParse(json['day_trade_ratio']),
        listDate = DateTime.tryParse(json['list_date']),
        minTickSize = json['min_tick_size'] == null
            ? null
            : double.tryParse(json['min_tick_size']),
        type = json['type'],
        tradeableChainId = json['tradable_chain_id'],
        rhsTradability = json['rhs_tradability'],
        fractionalTradability = json['fractional_tradability'],
        defaultCollarFraction =
            double.tryParse(json['default_collar_fraction']),
        ipoAccessStatus = json['ipo_access_status'],
        ipoAccessCobDeadline = json['ipo_access_cob_deadline'] == null
            ? null
            : DateTime.tryParse(json['ipo_access_cob_deadline']),
        ipoAllocatedPrice = json['ipo_allocated_price'] == null
            ? null
            : double.tryParse(json['ipo_allocated_price']),
        ipoCustomersReceived = json['ipo_customers_received'] == null
            ? null
            : double.tryParse(json['ipo_customers_received']),
        ipoCustomersRequested = json['ipo_customers_requested'] == null
            ? null
            : double.tryParse(json['ipo_customers_requested']),
        ipoDate = json['ipo_date'] == null
            ? null
            : DateTime.tryParse(json['ipo_date']),
        ipoS1Url = json['ipo_s1_url'],
        isSpac = json['is_spac'];

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'quote': quote,
        'fundamentals': fundamentals,
        // TODO: Finish
//    'endDate': _endDate.toIso8601String(),
      };
}
