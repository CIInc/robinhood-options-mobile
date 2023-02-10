//import 'package:flutter/material.dart';

//@immutable
import 'package:robinhood_options_mobile/model/fundamentals.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_chain.dart';
import 'package:robinhood_options_mobile/model/option_event.dart';
import 'package:robinhood_options_mobile/model/option_order.dart';
import 'package:robinhood_options_mobile/model/stock_order.dart';
import 'package:robinhood_options_mobile/model/quote.dart';

/*
https://api.robinhood.com/instruments/?ids=4cf14b0c-a633-4002-9719-ee221decca22
{
    "next": null,
    "previous": null,
    "results": [
        {
            "id": "4cf14b0c-a633-4002-9719-ee221decca22",
            "url": "https:\/\/api.robinhood.com\/instruments\/4cf14b0c-a633-4002-9719-ee221decca22\/",
            "quote": "https:\/\/api.robinhood.com\/quotes\/KODK\/",
            "fundamentals": "https:\/\/api.robinhood.com\/fundamentals\/KODK\/",
            "splits": "https:\/\/api.robinhood.com\/instruments\/4cf14b0c-a633-4002-9719-ee221decca22\/splits\/",
            "state": "active",
            "market": "https:\/\/api.robinhood.com\/markets\/XNYS\/",
            "simple_name": "Kodak",
            "name": "EASTMAN KODAK COMPANY",
            "tradeable": true,
            "tradability": "tradable",
            "symbol": "KODK",
            "bloomberg_unique": "EQ0000000031536927",
            "margin_initial_ratio": "0.8000",
            "maintenance_ratio": "0.7500",
            "country": "US",
            "day_trade_ratio": "0.2500",
            "list_date": "2013-11-01",
            "min_tick_size": null,
            "type": "stock",
            "tradable_chain_id": "eefb80a4-efc0-4b5f-ba27-a7aa9a358469",
            "rhs_tradability": "tradable",
            "fractional_tradability": "tradable",
            "default_collar_fraction": "0.05",
            "ipo_access_status": null,
            "ipo_access_cob_deadline": null,
            "ipo_s1_url": null,
            "ipo_roadshow_url": null,
            "is_spac": false,
            "is_test": false,
            "ipo_access_supports_dsp": false,
            "extended_hours_fractional_tradability": false,
            "internal_halt_reason": "",
            "internal_halt_details": "",
            "internal_halt_sessions": null,
            "internal_halt_start_time": null,
            "internal_halt_end_time": null,
            "internal_halt_source": "",
            "all_day_tradability": "untradable"
        }
    ]
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
  final int? ipoCustomersReceived;
  final int? ipoCustomersRequested;
  final DateTime? ipoDate;
  final String? ipoS1Url;
  final String? ipoRoadshowUrl;
  final bool isSpac;
  final bool isTest;
  final bool ipoAccessSupportsDsp;

  Quote? quoteObj;
  Fundamentals? fundamentalsObj;
  InstrumentHistoricals? instrumentHistoricalsObj;
  OptionChain? optionChainObj;
  List<dynamic>? newsObj;
  List<dynamic>? listsObj;
  dynamic ratingsObj;
  dynamic ratingsOverviewObj;
  List<dynamic>? earningsObj;
  List<dynamic>? similarObj;
  List<dynamic>? splitsObj;
  List<OptionAggregatePosition>? optionPositions;
  List<StockOrder>? positionOrders;
  List<OptionOrder>? optionOrders;
  List<OptionEvent>? optionEvents;
  String? logoUrl;

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
      this.ipoRoadshowUrl,
      this.isSpac,
      this.isTest,
      this.ipoAccessSupportsDsp);

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
        ipoCustomersReceived = json['ipo_customers_received'],
        ipoCustomersRequested = json['ipo_customers_requested'],
        ipoDate = json['ipo_date'] == null
            ? null
            : DateTime.tryParse(json['ipo_date']),
        ipoS1Url = json['ipo_s1_url'],
        ipoRoadshowUrl = json['ipo_roadshow_url'],
        isSpac = json['is_spac'],
        isTest = json['is_test'] ?? false,
        ipoAccessSupportsDsp = json['ipo_access_supports_dsp'];

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'quote': quote,
        'fundamentals': fundamentals,
//    'endDate': _endDate.toIso8601String(),
      };
}
