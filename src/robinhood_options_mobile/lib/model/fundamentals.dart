import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:robinhood_options_mobile/utils/json.dart';

@immutable
class Fundamentals {
  final double? open;
  final double? high;
  final double? low;
  final double? volume;
  final DateTime? marketDate;
  final double? averageVolume2Weeks;
  final double? averageVolume30Days;
  final double? averageVolume;
  final double? high52Weeks;
  final double? dividendYield;
  final double? float;
  final double? low52Weeks;
  final double? marketCap;
  final double? pbRatio;
  final double? peRatio;
  final double? sharesOutstanding;
  final String description;
  // Data is url based. E.g. https://api.robinhood.com/instruments/8f92e76f-1e0e-4478-8580-16a6ffcfaef5/
  final String instrument;
  final String ceo;
  final String headquartersCity;
  final String headquartersState;
  final String sector;
  final String industry;
  final int? numEmployees;
  final int? yearFounded;

  const Fundamentals(
      {this.open,
      this.high,
      this.low,
      this.volume,
      this.marketDate,
      this.averageVolume2Weeks,
      this.averageVolume30Days,
      this.averageVolume,
      this.high52Weeks,
      this.dividendYield,
      this.float,
      this.low52Weeks,
      this.marketCap,
      this.pbRatio,
      this.peRatio,
      this.sharesOutstanding,
      this.description = '',
      this.instrument = '',
      this.ceo = '',
      this.headquartersCity = '',
      this.headquartersState = '',
      this.sector = '',
      this.industry = '',
      this.numEmployees,
      this.yearFounded});

  Fundamentals.fromJson(dynamic json)
      : open = parseDouble(json['open']),
        high = parseDouble(json['high']),
        low = parseDouble(json['low']),
        volume = parseDouble(json['volume']),
        marketDate = json['market_date'] is Timestamp
            ? (json['market_date'] as Timestamp).toDate()
            : (json['market_date'] is String
                ? DateTime.tryParse(json['market_date'])
                : null),
        averageVolume2Weeks = parseDouble(json['average_volume_2_weeks']),
        averageVolume30Days = parseDouble(json['average_volume_30_days']),
        averageVolume = parseDouble(json['average_volume']),
        high52Weeks = parseDouble(json['high_52_weeks']),
        dividendYield = parseDouble(json['dividend_yield']),
        float = parseDouble(json['float']),
        low52Weeks = parseDouble(json['low_52_weeks']),
        marketCap = parseDouble(json['market_cap']),
        pbRatio = parseDouble(json['pb_ratio']),
        peRatio = parseDouble(json['pe_ratio']),
        sharesOutstanding = parseDouble(json['shares_outstanding']),
        description = json['description'],
        instrument = json['instrument'],
        ceo = json['ceo'],
        headquartersCity = json['headquarters_city'],
        headquartersState = json['headquarters_state'],
        sector = json['sector'],
        industry = json['industry'],
        numEmployees = json['num_employees'],
        yearFounded = json['year_founded'];

  Fundamentals.fromSchwabJson(dynamic json,
      {this.instrument = '',
      String description = '',
      this.sector = '',
      this.industry = ''})
      : open = parseDouble(json['open']),
        high = parseDouble(json['high']),
        low = parseDouble(json['low']),
        volume = parseDouble(json['fundamental']?['vol1DayAvg'] ??
            json['vol1DayAvg'] ??
            json['volume']),
        marketDate = null,
        averageVolume2Weeks = parseDouble(
            json['fundamental']?['vol10DayAvg'] ?? json['vol10DayAvg']),
        averageVolume30Days = parseDouble(
            json['fundamental']?['vol3MonthAvg'] ?? json['vol3MonthAvg']),
        averageVolume = parseDouble(
            json['fundamental']?['vol3MonthAvg'] ?? json['vol3MonthAvg']),
        high52Weeks =
            parseDouble(json['fundamental']?['high52'] ?? json['high52']),
        dividendYield = parseDouble(
            json['fundamental']?['dividendYield'] ?? json['dividendYield']),
        float = parseDouble(
            json['fundamental']?['marketCapFloat'] ?? json['marketCapFloat']),
        low52Weeks =
            parseDouble(json['fundamental']?['low52'] ?? json['low52']),
        marketCap =
            parseDouble(json['fundamental']?['marketCap'] ?? json['marketCap']),
        pbRatio =
            parseDouble(json['fundamental']?['pbRatio'] ?? json['pbRatio']),
        peRatio =
            parseDouble(json['fundamental']?['peRatio'] ?? json['peRatio']),
        sharesOutstanding = parseDouble(
            json['fundamental']?['sharesOutstanding'] ??
                json['sharesOutstanding']),
        description = (json['description'] is String &&
                (json['description'] as String).isNotEmpty)
            ? json['description']
            : description,
        ceo = json['ceo'] ?? '',
        headquartersCity = json['headquarters_city'] ?? '',
        headquartersState = json['headquarters_state'] ?? '',
        numEmployees = json['num_employees'],
        yearFounded = json['year_founded'];

  Map<String, dynamic> toJson() => {
        'open': open,
        'high': high,
        'low': low,
        'volume': volume,
        'market_date': marketDate, //?.toIso8601String(),
        'average_volume_2_weeks': averageVolume2Weeks,
        'average_volume_30_days': averageVolume30Days,
        'average_volume': averageVolume,
        'high_52_weeks': high52Weeks,
        'dividend_yield': dividendYield,
        'float': float,
        'low_52_weeks': low52Weeks,
        'market_cap': marketCap,
        'pb_ratio': pbRatio,
        'pe_ratio': peRatio,
        'shares_outstanding': sharesOutstanding,
        'description': description,
        'instrument': instrument,
        'ceo': ceo,
        'headquarters_city': headquartersCity,
        'headquarters_state': headquartersState,
        'sector': sector,
        'industry': industry,
        'num_employees': numEmployees,
        'year_founded': yearFounded,
      };
}
