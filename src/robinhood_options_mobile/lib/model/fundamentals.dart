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

  const Fundamentals(
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
      : open = json['open'] != null ? double.tryParse(json['open']) : null,
        high = json['high'] != null ? double.tryParse(json['high']) : null,
        low = json['low'] != null ? double.tryParse(json['low']) : null,
        volume =
            json['volume'] != null ? double.tryParse(json['volume']) : null,
        marketDate = DateTime.tryParse(json['market_date']),
        averageVolume2Weeks = json['average_volume_2_weeks'] != null
            ? double.tryParse(json['average_volume_2_weeks'])
            : null,
        averageVolume30Days = json['average_volume_30_days'] != null
            ? double.tryParse(json['average_volume_30_days'])
            : null,
        averageVolume = json['average_volume'] != null
            ? double.tryParse(json['average_volume'])
            : null,
        high52Weeks = double.tryParse(json['high_52_weeks']),
        dividendYield = json['dividend_yield'] != null
            ? double.tryParse(json['dividend_yield'])
            : null,
        float = json['float'] != null ? double.tryParse(json['float']) : null,
        low52Weeks = double.tryParse(json['low_52_weeks']),
        marketCap = json['market_cap'] != null
            ? double.tryParse(json['market_cap'])
            : null,
        pbRatio =
            json['pb_ratio'] != null ? double.tryParse(json['pb_ratio']) : null,
        peRatio =
            json['pe_ratio'] != null ? double.tryParse(json['pe_ratio']) : null,
        sharesOutstanding = json['shares_outstanding'] != null
            ? double.tryParse(json['shares_outstanding'])
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
}
