import 'package:flutter/material.dart';

/*
{
  "open":"33.550000",
  "high":"34.170000",
  "low":"33.516500",
  "volume":"1324071.000000",
  "market_date":"2021-03-01",
  "average_volume_2_weeks":"1384179.400000",
  "average_volume":"1384179.400000",
  "high_52_weeks":"35.180000",
  "dividend_yield":"0.350360",
  "float":null,
  "low_52_weeks":"24.669000",
  "market_cap":"1102057734.130000",
  "pb_ratio":null,
  "pe_ratio":null,
  "shares_outstanding":"32290001.000000",
  "description":"QQQJ tracks a modified market-cap-weighted, narrow index of 100 non-financial stocks that are next-eligible for inclusion in the NASDAQ-100 Index.",
  "instrument":"https://api.robinhood.com/instruments/da5fb84a-e6d4-467c-8a36-4feb9c2abf4d/",
  "ceo":"",
  "headquarters_city":"",
  "headquarters_state":"",
  "sector":"Miscellaneous",
  "industry":"Investment Trusts Or Mutual Funds",
  "num_employees":null,
  "year_founded":null
  }
*/
@immutable
class Fundamentals {
  final double? open;
  final double? high;
  final double? low;
  final double? volume;
  final DateTime? marketDate;
  final double? averageVolume2Weeks;
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
  final String instrument;
  final String ceo;
  final String headquartersCity;
  final String headquartersState;
  final String sector;
  final String industry;
  final int numEmployees;
  final int yearFounded;

  const Fundamentals(
      this.open,
      this.high,
      this.low,
      this.volume,
      this.marketDate,
      this.averageVolume2Weeks,
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
      : open = double.tryParse(json['open']),
        high = double.tryParse(json['high']),
        low = double.tryParse(json['low']),
        volume = double.tryParse(json['volume']),
        marketDate = DateTime.tryParse(json['market_date']),
        averageVolume2Weeks = double.tryParse(json['average_volume_2_weeks']),
        averageVolume = double.tryParse(json['average_volume']),
        high52Weeks = double.tryParse(json['high_52_weeks']),
        dividendYield = json['dividend_yield'] != null
            ? double.tryParse(json['dividend_yield'])
            : null,
        float = json['float'] != null ? double.tryParse(json['float']) : null,
        low52Weeks = double.tryParse(json['low_52_weeks']),
        marketCap = double.tryParse(json['market_cap']),
        pbRatio =
            json['pb_ratio'] != null ? double.tryParse(json['pb_ratio']) : null,
        peRatio =
            json['pe_ratio'] != null ? double.tryParse(json['pe_ratio']) : null,
        sharesOutstanding = double.tryParse(json['shares_outstanding']),
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
