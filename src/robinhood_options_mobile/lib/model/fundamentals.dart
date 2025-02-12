import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

  Fundamentals(
      this.open,
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
      this.description,
      this.instrument,
      this.ceo,
      this.headquartersCity,
      this.headquartersState,
      this.sector,
      this.industry,
      this.numEmployees,
      this.yearFounded);

  Fundamentals.fromJson(dynamic json)
      : open = json['open'] != null
            ? (json['open'] is double
                ? json['open']
                : double.tryParse(json['open']))
            : null,
        high = json['high'] != null
            ? (json['high'] is double
                ? json['high']
                : double.tryParse(json['high']))
            : null,
        low = json['low'] != null
            ? (json['low'] is double
                ? json['low']
                : double.tryParse(json['low']))
            : null,
        volume = json['volume'] != null
            ? (json['volume'] is double
                ? json['volume']
                : double.tryParse(json['volume']))
            : null,
        marketDate = json['market_date'] is Timestamp
            ? (json['market_date'] as Timestamp).toDate()
            : DateTime.tryParse(json['market_date']),
        averageVolume2Weeks = json['average_volume_2_weeks'] != null
            ? (json['average_volume_2_weeks'] is double
                ? json['average_volume_2_weeks']
                : double.tryParse(json['average_volume_2_weeks']))
            : null,
        averageVolume30Days = json['average_volume_30_days'] != null
            ? (json['average_volume_30_days'] is double
                ? json['average_volume_30_days']
                : double.tryParse(json['average_volume_30_days']))
            : null,
        averageVolume = json['average_volume'] != null
            ? (json['average_volume'] is double
                ? json['average_volume']
                : double.tryParse(json['average_volume']))
            : null,
        high52Weeks = json['high_52_weeks'] is double
            ? json['high_52_weeks']
            : double.tryParse(json['high_52_weeks']),
        dividendYield = json['dividend_yield'] != null
            ? (json['dividend_yield'] is double
                ? json['dividend_yield']
                : double.tryParse(json['dividend_yield']))
            : null,
        float = json['float'] != null
            ? (json['float'] is double
                ? json['float']
                : double.tryParse(json['float']))
            : null,
        low52Weeks = json['low_52_weeks'] is double
            ? json['low_52_weeks']
            : double.tryParse(json['low_52_weeks']),
        marketCap = json['market_cap'] != null
            ? (json['market_cap'] is double
                ? json['market_cap']
                : double.tryParse(json['market_cap']))
            : null,
        pbRatio = json['pb_ratio'] != null
            ? (json['pb_ratio'] is double
                ? json['pb_ratio']
                : double.tryParse(json['pb_ratio']))
            : null,
        peRatio = json['pe_ratio'] != null
            ? (json['pe_ratio'] is double
                ? json['pe_ratio']
                : double.tryParse(json['pe_ratio']))
            : null,
        sharesOutstanding = json['shares_outstanding'] != null
            ? (json['shares_outstanding'] is double
                ? json['shares_outstanding']
                : double.tryParse(json['shares_outstanding']))
            : null,
        description = json['description'],
        instrument = json['instrument'],
        ceo = json['ceo'],
        headquartersCity = json['headquarters_city'],
        headquartersState = json['headquarters_state'],
        sector = json['sector'],
        industry = json['industry'],
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
