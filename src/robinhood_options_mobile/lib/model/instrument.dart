//import 'package:flutter/material.dart';

//@immutable

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:robinhood_options_mobile/model/fundamentals.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_chain.dart';
import 'package:robinhood_options_mobile/model/option_event.dart';
import 'package:robinhood_options_mobile/model/option_order.dart';
import 'package:robinhood_options_mobile/model/instrument_order.dart';
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
  final String type; // stock | etp
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

  final DateTime dateCreated;
  DateTime? dateUpdated;

  Quote? quoteObj;
  Fundamentals? fundamentalsObj;
  InstrumentHistoricals? instrumentHistoricalsObj;
  OptionChain? optionChainObj;
  List<dynamic>? newsObj;
  List<dynamic>? listsObj;
  List<dynamic>? dividendsObj;
  dynamic ratingsObj;
  dynamic ratingsOverviewObj;
  List<dynamic>? earningsObj;
  List<dynamic>? similarObj;
  List<dynamic>? splitsObj;
  List<OptionAggregatePosition>? optionPositions;
  List<InstrumentOrder>? positionOrders;
  List<OptionOrder>? optionOrders;
  List<OptionEvent>? optionEvents;
  String? logoUrl;
  dynamic etpDetails;

  Instrument(
      {required this.id,
      required this.url,
      required this.quote,
      required this.fundamentals,
      required this.splits,
      required this.state,
      required this.market,
      this.simpleName,
      required this.name,
      required this.tradeable,
      required this.tradability,
      required this.symbol,
      required this.bloombergUnique,
      this.marginInitialRatio,
      this.maintenanceRatio,
      required this.country,
      this.dayTradeRatio,
      this.listDate,
      this.minTickSize,
      required this.type,
      this.tradeableChainId,
      required this.rhsTradability,
      required this.fractionalTradability,
      this.defaultCollarFraction,
      this.ipoAccessStatus,
      this.ipoAccessCobDeadline,
      this.ipoAllocatedPrice,
      this.ipoCustomersReceived,
      this.ipoCustomersRequested,
      this.ipoDate,
      this.ipoS1Url,
      this.ipoRoadshowUrl,
      required this.isSpac,
      required this.isTest,
      required this.ipoAccessSupportsDsp,
      this.etpDetails,
      this.logoUrl,
      this.quoteObj,
      this.fundamentalsObj,
      this.instrumentHistoricalsObj,
      this.optionChainObj,
      this.newsObj,
      this.listsObj,
      this.dividendsObj,
      this.ratingsObj,
      this.ratingsOverviewObj,
      this.earningsObj,
      this.similarObj,
      this.splitsObj,
      this.optionPositions,
      this.positionOrders,
      this.optionOrders,
      this.optionEvents,
      required this.dateCreated,
      this.dateUpdated});

  Instrument.fromSchwabJson(dynamic json)
      : id = json['cusip'] ?? json['symbol'], // Use cusip as ID for Schwab
        url = '',
        quote = '',
        fundamentals = '',
        splits = '',
        state = 'active',
        market = json['exchange'] ?? '',
        simpleName = json['description'],
        name = json['description'] ?? '',
        tradeable = true,
        tradability = 'tradable',
        symbol = json['symbol'],
        bloombergUnique = json['cusip'] ?? '',
        marginInitialRatio = null,
        maintenanceRatio = null,
        country = 'US',
        dayTradeRatio = null,
        listDate = null,
        minTickSize = null,
        type = json['assetType'] ?? 'stock',
        tradeableChainId = null,
        rhsTradability = 'tradable',
        fractionalTradability = 'tradable',
        defaultCollarFraction = null,
        ipoAccessStatus = null,
        ipoAccessCobDeadline = null,
        ipoAllocatedPrice = null,
        ipoCustomersReceived = null,
        ipoCustomersRequested = null,
        ipoDate = null,
        ipoS1Url = null,
        ipoRoadshowUrl = null,
        isSpac = false,
        isTest = false,
        ipoAccessSupportsDsp = false,
        dateCreated = DateTime.now(),
        dateUpdated = null;

  factory Instrument.fromJson(dynamic json) {
    if (json['cusip'] != null ||
        (json['assetType'] != null && json['id'] == null)) {
      return Instrument.fromSchwabJson(json);
    }
    return Instrument(
        id: json['id'],
        url: json['url'],
        quote: json['quote'],
        fundamentals: json['fundamentals'],
        splits: json['splits'],
        state: json['state'],
        market: json['market'],
        simpleName: json['simple_name'],
        name: json['name'],
        tradeable: json['tradeable'],
        tradability: json['tradability'],
        symbol: json['symbol'],
        bloombergUnique: json['bloomberg_unique'],
        marginInitialRatio: json['margin_initial_ratio'] is double
            ? json['margin_initial_ratio']
            : double.tryParse(json['margin_initial_ratio']),
        maintenanceRatio: json['maintenance_ratio'] is double
            ? json['maintenance_ratio']
            : double.tryParse(json['maintenance_ratio']),
        country: json['country'],
        dayTradeRatio: json['day_trade_ratio'] is double
            ? json['day_trade_ratio']
            : double.tryParse(json['day_trade_ratio']),
        listDate: json['list_date'] == null
            ? null
            : json['list_date'] is Timestamp
                ? (json['list_date'] as Timestamp).toDate()
                : DateTime.tryParse(json['list_date']),
        minTickSize: json['min_tick_size'] == null
            ? null
            : double.tryParse(json['min_tick_size']),
        type: json['type'],
        tradeableChainId: json['tradable_chain_id'],
        rhsTradability: json['rhs_tradability'],
        fractionalTradability: json['fractional_tradability'],
        defaultCollarFraction: json['default_collar_fraction'] is double
            ? json['default_collar_fraction']
            : double.tryParse(json['default_collar_fraction']),
        ipoAccessStatus: json['ipo_access_status'],
        ipoAccessCobDeadline: json['ipo_access_cob_deadline'] == null
            ? null
            : json['ipo_access_cob_deadline'] is Timestamp
                ? (json['ipo_access_cob_deadline'] as Timestamp).toDate()
                : DateTime.tryParse(json['ipo_access_cob_deadline']),
        ipoAllocatedPrice: json['ipo_allocated_price'] == null
            ? null
            : double.tryParse(json['ipo_allocated_price']),
        ipoCustomersReceived: json['ipo_customers_received'],
        ipoCustomersRequested: json['ipo_customers_requested'],
        ipoDate: json['ipo_date'] == null
            ? null
            : json['ipo_date'] is Timestamp
                ? (json['ipo_date'] as Timestamp).toDate()
                : DateTime.tryParse(json['ipo_date']),
        ipoS1Url: json['ipo_s1_url'],
        ipoRoadshowUrl: json['ipo_roadshow_url'],
        isSpac: json['is_spac'],
        isTest: json['is_test'] ?? false,
        ipoAccessSupportsDsp: json['ipo_access_supports_dsp'],
        dateCreated: json["date_created"] == null
            ? DateTime.now()
            : (json['date_created'] as Timestamp).toDate(),
        dateUpdated: json['date_updated'] != null
            ? (json['date_updated'] as Timestamp).toDate()
            : null,
        quoteObj:
            json['quoteObj'] != null ? Quote.fromJson(json['quoteObj']) : null,
        fundamentalsObj: json['fundamentalsObj'] != null
            ? Fundamentals.fromJson(json['fundamentalsObj'])
            : null,
        instrumentHistoricalsObj: json['instrumentHistoricalsObj'] != null
            ? InstrumentHistoricals.fromJson(json['instrumentHistoricalsObj'])
            : null,
        optionChainObj: json['optionChainObj'] != null
            ? OptionChain.fromJson(json['optionChainObj'])
            : null,
        logoUrl: json["logo_url"],
        etpDetails: json['etp_details']);
  }
  // json['etp_details'] != null
  //     ? jsonDecode(json['etp_details'])
  //     : null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'quote': quote,
        'fundamentals': fundamentals,
        'splits': splits,
        'state': state,
        'market': market,
        'simple_name': simpleName,
        'name': name,
        'tradeable': tradeable,
        'tradability': tradability,
        'symbol': symbol,
        'bloomberg_unique': bloombergUnique,
        'margin_initial_ratio': marginInitialRatio,
        'maintenance_ratio': maintenanceRatio,
        'country': country,
        'day_trade_ratio': dayTradeRatio,
        'list_date': listDate, // ?.toIso8601String(),
        'min_tick_size': minTickSize,
        'type': type,
        'tradable_chain_id': tradeableChainId,
        'rhs_tradability': rhsTradability,
        'fractional_tradability': fractionalTradability,
        'default_collar_fraction': defaultCollarFraction,
        'ipo_access_status': ipoAccessStatus,
        'ipo_access_cob_deadline': ipoAccessCobDeadline, //?.toIso8601String(),
        'ipo_allocated_price': ipoAllocatedPrice,
        'ipo_customers_received': ipoCustomersReceived,
        'ipo_customers_requested': ipoCustomersRequested,
        'ipo_date': ipoDate, //?.toIso8601String(),
        'ipo_s1_url': ipoS1Url,
        'ipo_roadshow_url': ipoRoadshowUrl,
        'is_spac': isSpac,
        'is_test': isTest,
        'ipo_access_supports_dsp': ipoAccessSupportsDsp,
        'date_created': dateCreated,
        'date_updated': dateUpdated,
        'logo_url': logoUrl,
        'etp_details': etpDetails,

        'quoteObj': quoteObj?.toJson(),
        'fundamentalsObj': fundamentalsObj?.toJson(),
        'instrumentHistoricalsObj': instrumentHistoricalsObj?.toJson(),
        'optionChainObj': optionChainObj?.toJson(),
        // 'newsObj': newsObj,
        // 'listsObj': listsObj,
        // 'dividendsObj': dividendsObj,
        // 'ratingsObj': ratingsObj,
        // 'ratingsOverviewObj': ratingsOverviewObj,
        // 'earningsObj': earningsObj,
        // 'similarObj': similarObj,
        // 'splitsObj': splitsObj,

        // 'optionPositions': optionPositions?.map((e) => e.toJson()).toList(),
        // 'positionOrders': positionOrders?.map((e) => e.toJson()).toList(),
        // 'optionOrders': optionOrders?.map((e) => e.toJson()).toList(),
        // 'optionEvents': optionEvents?.map((e) => e.toJson()).toList(),
      };

  /// Generates a markdown table from a list of Instrument,
  /// including key Instrument fields, selected Fundamentals, and Quote fields if available.
  static String toMarkdownTable(List<Instrument> instruments) {
    if (instruments.isEmpty) return 'No instruments available.';

    final headers = [
      'Symbol',
      'Name',
      'Type',
      'Country',
      'Tradeable',
      'Tradability',
      'RHS Tradability',
      'Fractional Tradability',
      'List Date',
      'Min Tick Size',
      'Margin Initial Ratio',
      'Maintenance Ratio',
      'Is SPAC',
      'Is Test',
      // Fundamentals fields
      'Sector',
      'Industry',
      'Market Cap',
      'P/E Ratio',
      'Dividend Yield',
      '52W High',
      '52W Low',
      // Quote fields
      'Last Price',
      'Bid Price',
      'Ask Price',
      'Bid Size',
      'Ask Size',
      'Previous Close',
    ];

    final buffer = StringBuffer();
    buffer.writeln('| ${headers.join(' | ')} |');
    buffer.writeln('|${List.filled(headers.length, '---').join('|')}|');

    for (final i in instruments) {
      final f = i.fundamentalsObj;
      final q = i.quoteObj;
      buffer.writeln('| ${[
        i.symbol,
        i.name,
        i.type,
        i.country,
        i.tradeable ? 'Yes' : 'No',
        i.tradability,
        i.rhsTradability,
        i.fractionalTradability,
        i.listDate?.toIso8601String().split('T').first ?? '',
        i.minTickSize?.toString() ?? '',
        i.marginInitialRatio?.toString() ?? '',
        i.maintenanceRatio?.toString() ?? '',
        i.isSpac ? 'Yes' : 'No',
        i.isTest ? 'Yes' : 'No',
        // Fundamentals
        f?.sector ?? '',
        f?.industry ?? '',
        f?.marketCap?.toString() ?? '',
        f?.peRatio?.toString() ?? '',
        f?.dividendYield?.toString() ?? '',
        f?.high52Weeks?.toString() ?? '',
        f?.low52Weeks?.toString() ?? '',
        // Quote
        q?.lastTradePrice?.toString() ?? '',
        q?.bidPrice?.toString() ?? '',
        q?.askPrice?.toString() ?? '',
        q?.bidSize.toString() ?? '',
        q?.askSize.toString() ?? '',
        q?.previousClose?.toString() ?? '',
      ].join(' | ')} |');
    }
    return buffer.toString();
  }
}
