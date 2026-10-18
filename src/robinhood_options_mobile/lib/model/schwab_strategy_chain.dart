import 'package:flutter/foundation.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/option_marketdata.dart';
import 'package:robinhood_options_mobile/utils/json.dart';

/// Supported Schwab multi-leg option chain strategy types for `GET /marketdata/v1/chains`.
enum SchwabStrategyType {
  single('SINGLE', 'Single Option'),
  covered('COVERED', 'Covered Call/Put'),
  vertical('VERTICAL', 'Vertical Spread'),
  calendar('CALENDAR', 'Calendar Spread'),
  strangle('STRANGLE', 'Strangle'),
  straddle('STRADDLE', 'Straddle'),
  butterfly('BUTTERFLY', 'Butterfly'),
  condor('CONDOR', 'Condor'),
  diagonal('DIAGONAL', 'Diagonal Spread'),
  collar('COLLAR', 'Collar'),
  roll('ROLL', 'Roll');

  final String paramValue;
  final String displayName;

  const SchwabStrategyType(this.paramValue, this.displayName);

  static SchwabStrategyType fromString(String? value) {
    if (value == null || value.trim().isEmpty) return SchwabStrategyType.single;
    final normalized = value.trim().toUpperCase();
    for (var type in SchwabStrategyType.values) {
      if (type.paramValue == normalized ||
          type.name.toUpperCase() == normalized) {
        return type;
      }
    }
    return SchwabStrategyType.single;
  }
}

/// Represents the response payload from Schwab Market Data API:
/// `GET /marketdata/v1/chains?strategy=...`
@immutable
class SchwabStrategyChain {
  final String symbol;
  final String status;
  final String strategy;
  final SchwabStrategyType strategyType;
  final double? interval;
  final bool isDelayed;
  final bool isIndex;
  final double? interestRate;
  final double? underlyingPrice;
  final double? volatility;
  final double? daysToExpiration;
  final int? numberOfContracts;
  final SchwabStrategyUnderlying? underlying;
  final List<SchwabMonthlyStrategy> monthlyStrategies;

  const SchwabStrategyChain({
    required this.symbol,
    required this.status,
    required this.strategy,
    required this.strategyType,
    this.interval,
    this.isDelayed = false,
    this.isIndex = false,
    this.interestRate,
    this.underlyingPrice,
    this.volatility,
    this.daysToExpiration,
    this.numberOfContracts,
    this.underlying,
    this.monthlyStrategies = const [],
  });

  factory SchwabStrategyChain.fromJson(Map<String, dynamic> json) {
    final strategyStr = json['strategy']?.toString() ?? 'SINGLE';
    final strategyType = SchwabStrategyType.fromString(strategyStr);

    final monthlyListRaw = json['monthlyStrategyList'];
    List<SchwabMonthlyStrategy> monthlyStrategies = [];
    if (monthlyListRaw is List) {
      for (var item in monthlyListRaw) {
        if (item is Map<String, dynamic>) {
          monthlyStrategies.add(SchwabMonthlyStrategy.fromJson(item));
        } else if (item is Map) {
          monthlyStrategies.add(
              SchwabMonthlyStrategy.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    return SchwabStrategyChain(
      symbol: json['symbol']?.toString() ?? '',
      status: json['status']?.toString() ?? 'SUCCESS',
      strategy: strategyStr,
      strategyType: strategyType,
      interval: parseDouble(json['interval']),
      isDelayed: json['isDelayed'] == true,
      isIndex: json['isIndex'] == true,
      interestRate: parseDouble(json['interestRate']),
      underlyingPrice: parseDouble(json['underlyingPrice']),
      volatility: parseDouble(json['volatility']),
      daysToExpiration: parseDouble(json['daysToExpiration']),
      numberOfContracts: parseInt(json['numberOfContracts']),
      underlying: json['underlying'] != null && json['underlying'] is Map
          ? SchwabStrategyUnderlying.fromJson(
              json['underlying'] is Map<String, dynamic>
                  ? json['underlying'] as Map<String, dynamic>
                  : Map<String, dynamic>.from(json['underlying'] as Map))
          : null,
      monthlyStrategies: monthlyStrategies,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'status': status,
      'strategy': strategy,
      if (interval != null) 'interval': interval,
      'isDelayed': isDelayed,
      'isIndex': isIndex,
      if (interestRate != null) 'interestRate': interestRate,
      if (underlyingPrice != null) 'underlyingPrice': underlyingPrice,
      if (volatility != null) 'volatility': volatility,
      if (daysToExpiration != null) 'daysToExpiration': daysToExpiration,
      if (numberOfContracts != null) 'numberOfContracts': numberOfContracts,
      if (underlying != null) 'underlying': underlying!.toJson(),
      'monthlyStrategyList': monthlyStrategies.map((e) => e.toJson()).toList(),
    };
  }

  /// Flattens all packages across all expiration months.
  List<SchwabStrategyPackage> get allPackages {
    return monthlyStrategies.expand((m) => m.packages).toList();
  }

  /// All unique expiration dates in this chain.
  List<DateTime> get availableExpirations {
    final dates = <DateTime>{};
    for (var m in monthlyStrategies) {
      if (m.expirationDate != null) {
        dates.add(m.expirationDate!);
      }
    }
    final sorted = dates.toList()..sort();
    return sorted;
  }

  /// All strategy packages matching a specific expiration date.
  List<SchwabStrategyPackage> packagesForExpiration(DateTime expiration) {
    final matching = <SchwabStrategyPackage>[];
    for (var m in monthlyStrategies) {
      if (m.expirationDate != null &&
          m.expirationDate!.year == expiration.year &&
          m.expirationDate!.month == expiration.month &&
          m.expirationDate!.day == expiration.day) {
        matching.addAll(m.packages);
      }
    }
    return matching;
  }
}

/// Underlying equity/index quote information in a Schwab chain response.
@immutable
class SchwabStrategyUnderlying {
  final String? symbol;
  final String? description;
  final double? change;
  final double? percentChange;
  final double? close;
  final double? open;
  final double? high;
  final double? low;
  final double? bid;
  final double? ask;
  final double? last;
  final double? mark;
  final double? markChange;
  final double? markPercentChange;
  final int? bidSize;
  final int? askSize;
  final int? totalVolume;
  final double? fiftyTwoWeekHigh;
  final double? fiftyTwoWeekLow;
  final DateTime? quoteTime;
  final DateTime? tradeTime;

  const SchwabStrategyUnderlying({
    this.symbol,
    this.description,
    this.change,
    this.percentChange,
    this.close,
    this.open,
    this.high,
    this.low,
    this.bid,
    this.ask,
    this.last,
    this.mark,
    this.markChange,
    this.markPercentChange,
    this.bidSize,
    this.askSize,
    this.totalVolume,
    this.fiftyTwoWeekHigh,
    this.fiftyTwoWeekLow,
    this.quoteTime,
    this.tradeTime,
  });

  factory SchwabStrategyUnderlying.fromJson(Map<String, dynamic> json) {
    return SchwabStrategyUnderlying(
      symbol: json['symbol']?.toString(),
      description: json['description']?.toString(),
      change: parseDouble(json['change']),
      percentChange: parseDouble(json['percentChange']),
      close: parseDouble(json['close']),
      open: parseDouble(json['openPrice'] ?? json['open']),
      high: parseDouble(json['highPrice'] ?? json['high']),
      low: parseDouble(json['lowPrice'] ?? json['low']),
      bid: parseDouble(json['bid']),
      ask: parseDouble(json['ask']),
      last: parseDouble(json['last']),
      mark: parseDouble(json['mark']),
      markChange: parseDouble(json['markChange']),
      markPercentChange: parseDouble(json['markPercentChange']),
      bidSize: parseInt(json['bidSize']),
      askSize: parseInt(json['askSize']),
      totalVolume: parseInt(json['totalVolume']),
      fiftyTwoWeekHigh: parseDouble(json['fiftyTwoWeekHigh']),
      fiftyTwoWeekLow: parseDouble(json['fiftyTwoWeekLow']),
      quoteTime: json['quoteTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              parseInt(json['quoteTime']) ?? 0)
          : null,
      tradeTime: json['tradeTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              parseInt(json['tradeTime']) ?? 0)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (symbol != null) 'symbol': symbol,
      if (description != null) 'description': description,
      if (change != null) 'change': change,
      if (percentChange != null) 'percentChange': percentChange,
      if (close != null) 'close': close,
      if (open != null) 'openPrice': open,
      if (high != null) 'highPrice': high,
      if (low != null) 'lowPrice': low,
      if (bid != null) 'bid': bid,
      if (ask != null) 'ask': ask,
      if (last != null) 'last': last,
      if (mark != null) 'mark': mark,
      if (markChange != null) 'markChange': markChange,
      if (markPercentChange != null) 'markPercentChange': markPercentChange,
      if (bidSize != null) 'bidSize': bidSize,
      if (askSize != null) 'askSize': askSize,
      if (totalVolume != null) 'totalVolume': totalVolume,
      if (fiftyTwoWeekHigh != null) 'fiftyTwoWeekHigh': fiftyTwoWeekHigh,
      if (fiftyTwoWeekLow != null) 'fiftyTwoWeekLow': fiftyTwoWeekLow,
      if (quoteTime != null) 'quoteTime': quoteTime!.millisecondsSinceEpoch,
      if (tradeTime != null) 'tradeTime': tradeTime!.millisecondsSinceEpoch,
    };
  }
}

/// Represents an expiration-grouped monthly node in `monthlyStrategyList`.
@immutable
class SchwabMonthlyStrategy {
  final String? month;
  final int? year;
  final int? day;
  final int? daysToExpiration;
  final String? secondaryMonth;
  final int? secondaryYear;
  final int? secondaryDay;
  final int? secondaryDaysToExpiration;
  final bool leapCheck;
  final List<SchwabStrategyPackage> packages;

  const SchwabMonthlyStrategy({
    this.month,
    this.year,
    this.day,
    this.daysToExpiration,
    this.secondaryMonth,
    this.secondaryYear,
    this.secondaryDay,
    this.secondaryDaysToExpiration,
    this.leapCheck = false,
    this.packages = const [],
  });

  factory SchwabMonthlyStrategy.fromJson(Map<String, dynamic> json) {
    final packageListRaw = json['optionStrategyList'];
    List<SchwabStrategyPackage> packages = [];
    if (packageListRaw is List) {
      for (var item in packageListRaw) {
        if (item is Map<String, dynamic>) {
          packages.add(SchwabStrategyPackage.fromJson(item));
        } else if (item is Map) {
          packages.add(
              SchwabStrategyPackage.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    return SchwabMonthlyStrategy(
      month: json['month']?.toString(),
      year: parseInt(json['year']),
      day: parseInt(json['day']),
      daysToExpiration: parseInt(json['daysToExpiration']),
      secondaryMonth: json['secondaryMonth']?.toString(),
      secondaryYear: parseInt(json['secondaryYear']),
      secondaryDay: parseInt(json['secondaryDay']),
      secondaryDaysToExpiration: parseInt(json['secondaryDaysToExpiration']),
      leapCheck: json['leapCheck'] == true,
      packages: packages,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (month != null) 'month': month,
      if (year != null) 'year': year,
      if (day != null) 'day': day,
      if (daysToExpiration != null) 'daysToExpiration': daysToExpiration,
      if (secondaryMonth != null) 'secondaryMonth': secondaryMonth,
      if (secondaryYear != null) 'secondaryYear': secondaryYear,
      if (secondaryDay != null) 'secondaryDay': secondaryDay,
      if (secondaryDaysToExpiration != null)
        'secondaryDaysToExpiration': secondaryDaysToExpiration,
      'leapCheck': leapCheck,
      'optionStrategyList': packages.map((e) => e.toJson()).toList(),
    };
  }

  /// Derived primary expiration date from year, month, and day.
  DateTime? get expirationDate {
    if (year != null && day != null && month != null) {
      final monthNum = _parseMonth(month!);
      if (monthNum != null) {
        return DateTime(year!, monthNum, day!);
      }
    }
    // Fall back to primaryLeg expirationDate if present in first package
    if (packages.isNotEmpty &&
        packages.first.primaryLeg?.expirationDate != null) {
      return packages.first.primaryLeg!.expirationDate;
    }
    return null;
  }

  /// Derived secondary expiration date for calendar/diagonal/roll spreads.
  DateTime? get secondaryExpirationDate {
    if (secondaryYear != null &&
        secondaryDay != null &&
        secondaryMonth != null) {
      final monthNum = _parseMonth(secondaryMonth!);
      if (monthNum != null) {
        return DateTime(secondaryYear!, monthNum, secondaryDay!);
      }
    }
    if (packages.isNotEmpty &&
        packages.first.secondaryLeg?.expirationDate != null) {
      return packages.first.secondaryLeg!.expirationDate;
    }
    return null;
  }

  static int? _parseMonth(String m) {
    switch (m.trim().toUpperCase()) {
      case 'JAN':
      case 'JANUARY':
        return 1;
      case 'FEB':
      case 'FEBRUARY':
        return 2;
      case 'MAR':
      case 'MARCH':
        return 3;
      case 'APR':
      case 'APRIL':
        return 4;
      case 'MAY':
        return 5;
      case 'JUN':
      case 'JUNE':
        return 6;
      case 'JUL':
      case 'JULY':
        return 7;
      case 'AUG':
      case 'AUGUST':
        return 8;
      case 'SEP':
      case 'SEPTEMBER':
        return 9;
      case 'OCT':
      case 'OCTOBER':
        return 10;
      case 'NOV':
      case 'NOVEMBER':
        return 11;
      case 'DEC':
      case 'DECEMBER':
        return 12;
      default:
        return int.tryParse(m);
    }
  }
}

/// Represents an individual multi-leg package option quote combination within `optionStrategyList`.
@immutable
class SchwabStrategyPackage {
  final String? strategyStrike;
  final double? strategyBid;
  final double? strategyAsk;
  final double? strategyMark;
  final double? bid;
  final double? ask;
  final double? mark;
  final double? delta;
  final double? gamma;
  final double? theta;
  final double? vega;
  final double? rho;
  final SchwabStrategyLeg? primaryLeg;
  final SchwabStrategyLeg? secondaryLeg;
  final List<SchwabStrategyLeg> additionalLegs;

  const SchwabStrategyPackage({
    this.strategyStrike,
    this.strategyBid,
    this.strategyAsk,
    this.strategyMark,
    this.bid,
    this.ask,
    this.mark,
    this.delta,
    this.gamma,
    this.theta,
    this.vega,
    this.rho,
    this.primaryLeg,
    this.secondaryLeg,
    this.additionalLegs = const [],
  });

  factory SchwabStrategyPackage.fromJson(Map<String, dynamic> json) {
    SchwabStrategyLeg? primary;
    if (json['primaryLeg'] != null && json['primaryLeg'] is Map) {
      primary = SchwabStrategyLeg.fromJson(
          json['primaryLeg'] is Map<String, dynamic>
              ? json['primaryLeg'] as Map<String, dynamic>
              : Map<String, dynamic>.from(json['primaryLeg'] as Map));
    }

    SchwabStrategyLeg? secondary;
    if (json['secondaryLeg'] != null && json['secondaryLeg'] is Map) {
      secondary = SchwabStrategyLeg.fromJson(
          json['secondaryLeg'] is Map<String, dynamic>
              ? json['secondaryLeg'] as Map<String, dynamic>
              : Map<String, dynamic>.from(json['secondaryLeg'] as Map));
    }

    List<SchwabStrategyLeg> additionals = [];
    if (json['legs'] is List) {
      for (var legItem in json['legs'] as List) {
        if (legItem is Map) {
          final mapped = legItem is Map<String, dynamic>
              ? legItem
              : Map<String, dynamic>.from(legItem);
          additionals.add(SchwabStrategyLeg.fromJson(mapped));
        }
      }
    }

    return SchwabStrategyPackage(
      strategyStrike: json['strategyStrike']?.toString(),
      strategyBid: parseDouble(json['strategyBid']),
      strategyAsk: parseDouble(json['strategyAsk']),
      strategyMark: parseDouble(json['strategyMark']),
      bid: parseDouble(json['bid']),
      ask: parseDouble(json['ask']),
      mark: parseDouble(json['mark']),
      delta: parseDouble(json['delta']),
      gamma: parseDouble(json['gamma']),
      theta: parseDouble(json['theta']),
      vega: parseDouble(json['vega']),
      rho: parseDouble(json['rho']),
      primaryLeg: primary,
      secondaryLeg: secondary,
      additionalLegs: additionals,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (strategyStrike != null) 'strategyStrike': strategyStrike,
      if (strategyBid != null) 'strategyBid': strategyBid,
      if (strategyAsk != null) 'strategyAsk': strategyAsk,
      if (strategyMark != null) 'strategyMark': strategyMark,
      if (bid != null) 'bid': bid,
      if (ask != null) 'ask': ask,
      if (mark != null) 'mark': mark,
      if (delta != null) 'delta': delta,
      if (gamma != null) 'gamma': gamma,
      if (theta != null) 'theta': theta,
      if (vega != null) 'vega': vega,
      if (rho != null) 'rho': rho,
      if (primaryLeg != null) 'primaryLeg': primaryLeg!.toJson(),
      if (secondaryLeg != null) 'secondaryLeg': secondaryLeg!.toJson(),
      if (additionalLegs.isNotEmpty)
        'legs': additionalLegs.map((e) => e.toJson()).toList(),
    };
  }

  /// Convenience getter for all constituent legs in this package.
  List<SchwabStrategyLeg> get legs {
    if (additionalLegs.isNotEmpty) {
      return additionalLegs;
    }
    return [
      if (primaryLeg != null) primaryLeg!,
      if (secondaryLeg != null) secondaryLeg!,
    ];
  }

  /// The effective bid price for the multi-leg package.
  double? get effectiveBid => strategyBid ?? bid;

  /// The effective ask price for the multi-leg package.
  double? get effectiveAsk => strategyAsk ?? ask;

  /// The effective mark price (or midpoint of bid/ask) for the package.
  double? get effectiveMark {
    if (strategyMark != null) return strategyMark;
    if (mark != null) return mark;
    if (effectiveBid != null && effectiveAsk != null) {
      return (effectiveBid! + effectiveAsk!) / 2;
    }
    return effectiveBid ?? effectiveAsk;
  }

  /// Whether executing this package is a net debit (costs capital to buy).
  bool get isDebit {
    final price = effectiveMark ?? 0.0;
    return price >= 0;
  }

  /// Whether executing this package is a net credit (generates cash on open).
  bool get isCredit => !isDebit;

  /// Spread width between primary and secondary strikes if numerical strikes can be parsed.
  double? get spreadWidth {
    if (primaryLeg?.strikePrice != null && secondaryLeg?.strikePrice != null) {
      return (primaryLeg!.strikePrice! - secondaryLeg!.strikePrice!).abs();
    }
    if (strategyStrike != null && strategyStrike!.contains('/')) {
      final parts = strategyStrike!.split('/');
      if (parts.length >= 2) {
        final s1 = double.tryParse(parts[0].trim());
        final s2 = double.tryParse(parts[1].trim());
        if (s1 != null && s2 != null) {
          return (s1 - s2).abs();
        }
      }
    }
    return null;
  }
}

/// Represents an individual option leg within a multi-leg strategy package.
@immutable
class SchwabStrategyLeg {
  final String symbol;
  final String putCall;
  final String? description;
  final double? bid;
  final double? ask;
  final double? mark;
  final double? last;
  final int? bidSize;
  final int? askSize;
  final int? lastSize;
  final double? openPrice;
  final double? highPrice;
  final double? lowPrice;
  final double? closePrice;
  final double? netChange;
  final double? percentChange;
  final int? totalVolume;
  final int? openInterest;
  final double? volatility;
  final double? delta;
  final double? gamma;
  final double? theta;
  final double? vega;
  final double? rho;
  final double? timeValue;
  final double? theoreticalOptionValue;
  final double? theoreticalVolatility;
  final double? strikePrice;
  final DateTime? expirationDate;
  final int? daysToExpiration;
  final String? expirationType;
  final double? multiplier;
  final String? settlementType;
  final String? deliverableNote;
  final bool isIndexOption;
  final bool inTheMoney;
  final bool mini;
  final bool nonStandard;

  const SchwabStrategyLeg({
    required this.symbol,
    required this.putCall,
    this.description,
    this.bid,
    this.ask,
    this.mark,
    this.last,
    this.bidSize,
    this.askSize,
    this.lastSize,
    this.openPrice,
    this.highPrice,
    this.lowPrice,
    this.closePrice,
    this.netChange,
    this.percentChange,
    this.totalVolume,
    this.openInterest,
    this.volatility,
    this.delta,
    this.gamma,
    this.theta,
    this.vega,
    this.rho,
    this.timeValue,
    this.theoreticalOptionValue,
    this.theoreticalVolatility,
    this.strikePrice,
    this.expirationDate,
    this.daysToExpiration,
    this.expirationType,
    this.multiplier,
    this.settlementType,
    this.deliverableNote,
    this.isIndexOption = false,
    this.inTheMoney = false,
    this.mini = false,
    this.nonStandard = false,
  });

  factory SchwabStrategyLeg.fromJson(Map<String, dynamic> json) {
    DateTime? expDate;
    if (json['expirationDate'] != null) {
      try {
        expDate = DateTime.parse(json['expirationDate'].toString());
      } catch (_) {}
    }

    return SchwabStrategyLeg(
      symbol: json['symbol']?.toString() ?? '',
      putCall: (json['putCall']?.toString() ?? 'CALL').toUpperCase(),
      description: json['description']?.toString(),
      bid: parseDouble(json['bid']),
      ask: parseDouble(json['ask']),
      mark: parseDouble(json['mark']),
      last: parseDouble(json['last']),
      bidSize: parseInt(json['bidSize']),
      askSize: parseInt(json['askSize']),
      lastSize: parseInt(json['lastSize']),
      openPrice: parseDouble(json['openPrice']),
      highPrice: parseDouble(json['highPrice']),
      lowPrice: parseDouble(json['lowPrice']),
      closePrice: parseDouble(json['closePrice']),
      netChange: parseDouble(json['netChange']),
      percentChange: parseDouble(json['percentChange']),
      totalVolume: parseInt(json['totalVolume']),
      openInterest: parseInt(json['openInterest']),
      volatility: parseDouble(json['volatility']),
      delta: parseDouble(json['delta']),
      gamma: parseDouble(json['gamma']),
      theta: parseDouble(json['theta']),
      vega: parseDouble(json['vega']),
      rho: parseDouble(json['rho']),
      timeValue: parseDouble(json['timeValue']),
      theoreticalOptionValue: parseDouble(json['theoreticalOptionValue']),
      theoreticalVolatility: parseDouble(json['theoreticalVolatility']),
      strikePrice: parseDouble(json['strikePrice']),
      expirationDate: expDate,
      daysToExpiration: parseInt(json['daysToExpiration']),
      expirationType: json['expirationType']?.toString(),
      multiplier: parseDouble(json['multiplier']),
      settlementType: json['settlementType']?.toString(),
      deliverableNote: json['deliverableNote']?.toString(),
      isIndexOption: json['isIndexOption'] == true,
      inTheMoney: json['inTheMoney'] == true,
      mini: json['mini'] == true,
      nonStandard: json['nonStandard'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'putCall': putCall,
      if (description != null) 'description': description,
      if (bid != null) 'bid': bid,
      if (ask != null) 'ask': ask,
      if (mark != null) 'mark': mark,
      if (last != null) 'last': last,
      if (bidSize != null) 'bidSize': bidSize,
      if (askSize != null) 'askSize': askSize,
      if (lastSize != null) 'lastSize': lastSize,
      if (openPrice != null) 'openPrice': openPrice,
      if (highPrice != null) 'highPrice': highPrice,
      if (lowPrice != null) 'lowPrice': lowPrice,
      if (closePrice != null) 'closePrice': closePrice,
      if (netChange != null) 'netChange': netChange,
      if (percentChange != null) 'percentChange': percentChange,
      if (totalVolume != null) 'totalVolume': totalVolume,
      if (openInterest != null) 'openInterest': openInterest,
      if (volatility != null) 'volatility': volatility,
      if (delta != null) 'delta': delta,
      if (gamma != null) 'gamma': gamma,
      if (theta != null) 'theta': theta,
      if (vega != null) 'vega': vega,
      if (rho != null) 'rho': rho,
      if (timeValue != null) 'timeValue': timeValue,
      if (theoreticalOptionValue != null)
        'theoreticalOptionValue': theoreticalOptionValue,
      if (theoreticalVolatility != null)
        'theoreticalVolatility': theoreticalVolatility,
      if (strikePrice != null) 'strikePrice': strikePrice,
      if (expirationDate != null)
        'expirationDate': expirationDate!.toIso8601String(),
      if (daysToExpiration != null) 'daysToExpiration': daysToExpiration,
      if (expirationType != null) 'expirationType': expirationType,
      if (multiplier != null) 'multiplier': multiplier,
      if (settlementType != null) 'settlementType': settlementType,
      if (deliverableNote != null) 'deliverableNote': deliverableNote,
      'isIndexOption': isIndexOption,
      'inTheMoney': inTheMoney,
      'mini': mini,
      'nonStandard': nonStandard,
    };
  }

  /// Converts this strategy leg into standard [OptionMarketData].
  OptionMarketData toOptionMarketData({String? rootSymbol}) {
    return OptionMarketData(
      mark,
      ask,
      askSize ?? 0,
      bid,
      bidSize ?? 0,
      null, // breakEvenPrice
      highPrice,
      symbol, // instrument
      symbol, // instrumentId
      last,
      lastSize ?? 0,
      lowPrice,
      mark,
      openInterest ?? 0,
      null, // previousCloseDate
      closePrice,
      totalVolume ?? 0,
      rootSymbol ?? (symbol.split(' ').firstOrNull ?? ''),
      symbol, // occSymbol
      null, // chanceOfProfitLong
      null, // chanceOfProfitShort
      delta,
      gamma,
      volatility,
      rho,
      theta,
      vega,
      null,
      null,
      null,
      null,
      DateTime.now(),
    );
  }

  /// Converts this strategy leg into a standard [OptionInstrument] model.
  OptionInstrument toOptionInstrument(Instrument underlyingInstrument) {
    return OptionInstrument(
      underlyingInstrument.id,
      underlyingInstrument.symbol,
      DateTime.now(),
      expirationDate ?? DateTime.now(),
      symbol,
      DateTime.now(),
      const MinTicks(0.05, 0.01, 3.0),
      'tradable',
      'active',
      strikePrice ?? 0.0,
      'tradable',
      putCall.toLowerCase(),
      DateTime.now(),
      symbol,
      null,
      '',
      '',
    );
  }
}
