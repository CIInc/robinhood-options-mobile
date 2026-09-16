import 'dart:math' as math;
import 'package:robinhood_options_mobile/utils/json.dart';

/// Represents an equity or option day trade within the FINRA rolling 5-day window.
class DayTrade {
  final String id;
  final String symbol;
  final String? instrumentUrl;
  final String type; // 'equity', 'option', 'crypto'
  final DateTime executionDate;
  final DateTime timestamp;
  final int count;
  final String? direction;
  final double? price;
  final double? quantity;
  final DateTime dropOffDate;

  DayTrade({
    required this.id,
    required this.symbol,
    this.instrumentUrl,
    this.type = 'equity',
    required this.executionDate,
    required this.timestamp,
    this.count = 1,
    this.direction,
    this.price,
    this.quantity,
    DateTime? dropOffDate,
  }) : dropOffDate = dropOffDate ?? computeDropOffDate(executionDate);

  factory DayTrade.fromJson(dynamic json, {String defaultType = 'equity'}) {
    final symbol = json['symbol'] ??
        json['ticker'] ??
        (json['instrument_symbol'] ?? 'UNKNOWN');
    final rawDate = json['trade_execution_date'] ??
        json['date'] ??
        json['created_at'] ??
        json['timestamp'];
    DateTime execDate;
    if (rawDate != null) {
      execDate = DateTime.tryParse(rawDate.toString()) ?? DateTime.now();
    } else {
      execDate = DateTime.now();
    }

    final rawTs = json['created_at'] ?? json['timestamp'] ?? rawDate;
    DateTime ts;
    if (rawTs != null) {
      ts = DateTime.tryParse(rawTs.toString()) ?? execDate;
    } else {
      ts = execDate;
    }

    final instrumentUrl =
        json['instrument'] ?? json['option'] ?? json['instrument_url'];
    final type =
        json['type'] ?? (json['option'] != null ? 'option' : defaultType);

    final id = json['id'] ??
        '${symbol}_${ts.millisecondsSinceEpoch}_${json['count'] ?? 1}';

    return DayTrade(
      id: id,
      symbol: symbol,
      instrumentUrl: instrumentUrl,
      type: type,
      executionDate: DateTime(execDate.year, execDate.month, execDate.day),
      timestamp: ts,
      count: json['count'] is int
          ? json['count']
          : (int.tryParse(json['count']?.toString() ?? '1') ?? 1),
      direction: json['direction'] ?? json['side'],
      price: parseDouble(json['price'] ?? json['execution_price']),
      quantity: parseDouble(json['quantity'] ?? json['shares']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'symbol': symbol,
      'instrument_url': instrumentUrl,
      'type': type,
      'execution_date': executionDate.toIso8601String(),
      'timestamp': timestamp.toIso8601String(),
      'count': count,
      'direction': direction,
      'price': price,
      'quantity': quantity,
      'drop_off_date': dropOffDate.toIso8601String(),
    };
  }

  /// Calculates the drop-off date (5 business days after trade date).
  static DateTime computeDropOffDate(DateTime fromDate) {
    var d = DateTime(fromDate.year, fromDate.month, fromDate.day);
    int businessDaysAdded = 0;
    while (businessDaysAdded < 5) {
      d = d.add(const Duration(days: 1));
      if (d.weekday != DateTime.saturday && d.weekday != DateTime.sunday) {
        businessDaysAdded++;
      }
    }
    return d;
  }

  /// Returns whether this day trade has passed the 5 business day rolling window.
  bool get isExpired {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.isAfter(dropOffDate) || today.isAtSameMomentAs(dropOffDate);
  }

  /// Trading days remaining until this trade drops out of the 5-day window.
  int get remainingTradingDays {
    final now = DateTime.now();
    var cur = DateTime(now.year, now.month, now.day);
    if (cur.isAfter(dropOffDate) || cur.isAtSameMomentAs(dropOffDate)) {
      return 0;
    }
    int count = 0;
    while (cur.isBefore(dropOffDate)) {
      if (cur.weekday != DateTime.saturday && cur.weekday != DateTime.sunday) {
        count++;
      }
      cur = cur.add(const Duration(days: 1));
    }
    return count;
  }
}

/// Pattern Day Trader (PDT) risk level based on FINRA Rule 4210.
enum PdtRiskLevel {
  /// 0 or 1 day trades used out of 3.
  safe,

  /// 2 day trades used out of 3. Caution advised.
  warning,

  /// 3 day trades used. 0 remaining. Next day trade triggers PDT flag.
  danger,

  /// Account has 4+ day trades or is flagged as PDT with equity under $25,000.
  flagged,

  /// Account equity is >= $25,000, exempt from FINRA PDT 3-trade restriction.
  exempt,
}

/// Comprehensive summary of rolling day trades and PDT status for an account.
class DayTradeSummary {
  final String accountNumber;
  final List<DayTrade> dayTrades;
  final List<DayTrade> equityDayTrades;
  final List<DayTrade> optionDayTrades;
  final bool isPatternDayTrader;
  final bool dayTradesProtection;
  final DateTime? markedPatternDayTraderDate;
  final DateTime? patternDayTraderExpiryDate;
  final bool isPdtForever;
  final double? portfolioEquity;
  final double? dayTradeBuyingPower;
  final double? dayTradeRatio;
  final String? accountType;

  DayTradeSummary({
    required this.accountNumber,
    required this.dayTrades,
    List<DayTrade>? equityDayTrades,
    List<DayTrade>? optionDayTrades,
    this.isPatternDayTrader = false,
    this.dayTradesProtection = true,
    this.markedPatternDayTraderDate,
    this.patternDayTraderExpiryDate,
    this.isPdtForever = false,
    this.portfolioEquity,
    this.dayTradeBuyingPower,
    this.dayTradeRatio,
    this.accountType,
  })  : equityDayTrades = equityDayTrades ??
            dayTrades.where((t) => t.type == 'equity').toList(),
        optionDayTrades = optionDayTrades ??
            dayTrades.where((t) => t.type == 'option').toList();

  /// Total active (non-expired) day trades in rolling 5-day window.
  int get activeDayTradeCount {
    return dayTrades.where((t) => !t.isExpired).fold<int>(
          0,
          (sum, trade) => sum + trade.count,
        );
  }

  /// Max day trades permitted in a margin account before PDT designation (3).
  int get maxAllowedDayTrades => 3;

  /// Day trades remaining before restriction (or -1 if exempt).
  int get remainingDayTrades {
    if (isPdtExempt) return -1;
    return math.max(0, maxAllowedDayTrades - activeDayTradeCount);
  }

  /// Whether the account meets FINRA's $25,000 equity requirement for unlimited day trading.
  bool get isPdtExempt {
    return (portfolioEquity ?? 0) >= 25000.0;
  }

  /// Whether this is a cash account (cash accounts are not subject to PDT rules).
  bool get isCashAccount {
    return (accountType ?? '').toLowerCase().contains('cash');
  }

  /// Current PDT risk level based on FINRA Rule 4210.
  PdtRiskLevel get riskLevel {
    if (isCashAccount || isPdtExempt) {
      return PdtRiskLevel.exempt;
    }
    if (isPatternDayTrader ||
        markedPatternDayTraderDate != null ||
        activeDayTradeCount >= 4) {
      return PdtRiskLevel.flagged;
    }
    if (activeDayTradeCount == 3) {
      return PdtRiskLevel.danger;
    }
    if (activeDayTradeCount == 2) {
      return PdtRiskLevel.warning;
    }
    return PdtRiskLevel.safe;
  }

  /// Compact status badge label tailored for pills and chips.
  String get statusBadge {
    switch (riskLevel) {
      case PdtRiskLevel.exempt:
        return isCashAccount ? 'Cash (Exempt)' : 'PDT Exempt';
      case PdtRiskLevel.flagged:
        return 'PDT Flagged';
      case PdtRiskLevel.danger:
        return '0 Trades Left';
      case PdtRiskLevel.warning:
        return '1 Trade Left';
      case PdtRiskLevel.safe:
        return '$remainingDayTrades Left';
    }
  }

  /// Concise status title for badges and alerts.
  String get statusTitle {
    switch (riskLevel) {
      case PdtRiskLevel.exempt:
        return isCashAccount
            ? 'Cash Account (PDT Exempt)'
            : 'PDT Exempt (\$25k+ Equity)';
      case PdtRiskLevel.flagged:
        return 'Pattern Day Trader Flagged';
      case PdtRiskLevel.danger:
        return 'PDT Limit Reached (0 Left)';
      case PdtRiskLevel.warning:
        return '1 Day Trade Left (Warning)';
      case PdtRiskLevel.safe:
        return '$remainingDayTrades of 3 Day Trades Available';
    }
  }

  /// Informative message for user guidance.
  String get statusDescription {
    switch (riskLevel) {
      case PdtRiskLevel.exempt:
        if (isCashAccount) {
          return 'Cash accounts are not subject to Pattern Day Trader restrictions. Be mindful of cash settlement times.';
        }
        return 'Your portfolio equity exceeds \$25,000. You have unlimited day trades as long as equity stays above \$25,000.';
      case PdtRiskLevel.flagged:
        return 'Your account is marked as a Pattern Day Trader with portfolio equity under \$25,000. Further day trades are restricted.';
      case PdtRiskLevel.danger:
        return 'You have used 3 of 3 allowable day trades in the last 5 business days. Executing another day trade will designate your account as a Pattern Day Trader.';
      case PdtRiskLevel.warning:
        return 'You have 1 day trade remaining. Please plan your entry and exit strategies carefully to avoid PDT designation.';
      case PdtRiskLevel.safe:
        return 'You have $remainingDayTrades day trades available in the rolling 5-business-day window.';
    }
  }

  /// Equity needed to reach the \$25,000 FINRA exemption threshold.
  double get equityDeficitTo25k {
    final eq = portfolioEquity ?? 0.0;
    return eq < 25000.0 ? 25000.0 - eq : 0.0;
  }

  factory DayTradeSummary.fromJson(
    dynamic json, {
    required String accountNumber,
    double? portfolioEquity,
    bool isPatternDayTrader = false,
    bool dayTradesProtection = true,
    DateTime? markedPatternDayTraderDate,
    DateTime? patternDayTraderExpiryDate,
    bool isPdtForever = false,
    double? dayTradeBuyingPower,
    double? dayTradeRatio,
    String? accountType,
  }) {
    final trades = <DayTrade>[];
    final eqTrades = <DayTrade>[];
    final optTrades = <DayTrade>[];

    if (json != null) {
      if (json['equity_day_trades'] is List) {
        for (var item in json['equity_day_trades']) {
          final t = DayTrade.fromJson(item, defaultType: 'equity');
          eqTrades.add(t);
          trades.add(t);
        }
      }
      if (json['option_day_trades'] is List) {
        for (var item in json['option_day_trades']) {
          final t = DayTrade.fromJson(item, defaultType: 'option');
          optTrades.add(t);
          trades.add(t);
        }
      }
      if (json['day_trades'] is List) {
        for (var item in json['day_trades']) {
          final t = DayTrade.fromJson(item);
          if (!trades.any((existing) => existing.id == t.id)) {
            trades.add(t);
            if (t.type == 'option') {
              optTrades.add(t);
            } else {
              eqTrades.add(t);
            }
          }
        }
      }
    }

    // Sort most recent first
    trades.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    eqTrades.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    optTrades.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return DayTradeSummary(
      accountNumber: accountNumber,
      dayTrades: trades,
      equityDayTrades: eqTrades,
      optionDayTrades: optTrades,
      isPatternDayTrader: isPatternDayTrader ||
          (json != null && json['is_pattern_day_trader'] == true),
      dayTradesProtection:
          (json != null && json['day_trades_protection'] != null)
              ? json['day_trades_protection'] == true
              : dayTradesProtection,
      markedPatternDayTraderDate: markedPatternDayTraderDate,
      patternDayTraderExpiryDate: patternDayTraderExpiryDate,
      isPdtForever: isPdtForever,
      portfolioEquity: portfolioEquity,
      dayTradeBuyingPower: dayTradeBuyingPower,
      dayTradeRatio: dayTradeRatio,
      accountType: accountType,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'account_number': accountNumber,
      'day_trades': dayTrades.map((t) => t.toJson()).toList(),
      'equity_day_trades': equityDayTrades.map((t) => t.toJson()).toList(),
      'option_day_trades': optionDayTrades.map((t) => t.toJson()).toList(),
      'is_pattern_day_trader': isPatternDayTrader,
      'day_trades_protection': dayTradesProtection,
      'marked_pattern_day_trader_date':
          markedPatternDayTraderDate?.toIso8601String(),
      'pattern_day_trader_expiry_date':
          patternDayTraderExpiryDate?.toIso8601String(),
      'is_pdt_forever': isPdtForever,
      'portfolio_equity': portfolioEquity,
      'day_trade_buying_power': dayTradeBuyingPower,
      'day_trade_ratio': dayTradeRatio,
      'account_type': accountType,
    };
  }
}
