//import 'package:flutter/material.dart';

//@immutable
import 'package:robinhood_options_mobile/model/fundamentals.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals.dart';
import 'package:robinhood_options_mobile/model/option_chain.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/split.dart';

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
