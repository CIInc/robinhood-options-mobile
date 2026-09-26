/// Represents a scheduled, projected, or historical dividend event.
class DividendPaymentEvent {
  final String symbol;
  final DateTime? payableDate;
  final DateTime? recordDate;
  final DateTime? exDividendDate;
  final double? amount;
  final double? rate;
  final double? sharesHeld;
  final String?
      state; // 'pending', 'paid', 'reinvested', 'projected', 'unconfirmed'
  final bool isReinvested;
  final String?
      frequency; // 'monthly', 'quarterly', 'semi-annually', 'annually'
  final double? dividendYield; // percentage e.g. 3.2 for 3.2%

  const DividendPaymentEvent({
    required this.symbol,
    this.payableDate,
    this.recordDate,
    this.exDividendDate,
    this.amount,
    this.rate,
    this.sharesHeld,
    this.state,
    this.isReinvested = false,
    this.frequency,
    this.dividendYield,
  });

  /// Calculates calendar day difference from [now] to [payableDate].
  /// Returns null if [payableDate] is not set.
  int? daysUntilPayable(DateTime now) {
    if (payableDate == null) return null;
    final payDay =
        DateTime(payableDate!.year, payableDate!.month, payableDate!.day);
    final currentDay = DateTime(now.year, now.month, now.day);
    return payDay.difference(currentDay).inDays;
  }

  /// Calculates calendar day difference from [now] to [exDividendDate].
  /// Returns null if [exDividendDate] is not set.
  int? daysUntilExDividend(DateTime now) {
    if (exDividendDate == null) return null;
    final exDay = DateTime(
        exDividendDate!.year, exDividendDate!.month, exDividendDate!.day);
    final currentDay = DateTime(now.year, now.month, now.day);
    return exDay.difference(currentDay).inDays;
  }

  /// Returns true if this dividend is marked as paid.
  bool get isPaid {
    final s = state?.toLowerCase().trim();
    return s == 'paid' || s == 'reinvested';
  }

  /// Returns true if this dividend is pending or scheduled for payment.
  bool get isPending {
    final s = state?.toLowerCase().trim();
    return s == 'pending' || s == 'unconfirmed' || s == 'projected';
  }

  /// Formatted total payment amount e.g. "$14.50" or null.
  String? get formattedAmount {
    if (amount == null) return null;
    return '\$${amount!.toStringAsFixed(2)}';
  }

  /// Formatted per-share rate e.g. "$0.25/share" or null.
  String? get formattedRate {
    if (rate == null) return null;
    return '\$${rate!.toStringAsFixed(2)}/share';
  }

  /// Formatted dividend yield e.g. "3.20%" or null.
  String? get formattedYield {
    if (dividendYield == null) return null;
    return '${dividendYield!.toStringAsFixed(2)}%';
  }

  /// Copies this event with updated fields.
  DividendPaymentEvent copyWith({
    String? symbol,
    DateTime? payableDate,
    DateTime? recordDate,
    DateTime? exDividendDate,
    double? amount,
    double? rate,
    double? sharesHeld,
    String? state,
    bool? isReinvested,
    String? frequency,
    double? dividendYield,
  }) {
    return DividendPaymentEvent(
      symbol: symbol ?? this.symbol,
      payableDate: payableDate ?? this.payableDate,
      recordDate: recordDate ?? this.recordDate,
      exDividendDate: exDividendDate ?? this.exDividendDate,
      amount: amount ?? this.amount,
      rate: rate ?? this.rate,
      sharesHeld: sharesHeld ?? this.sharesHeld,
      state: state ?? this.state,
      isReinvested: isReinvested ?? this.isReinvested,
      frequency: frequency ?? this.frequency,
      dividendYield: dividendYield ?? this.dividendYield,
    );
  }

  /// Parses a dividend record from a Robinhood, Schwab, Fidelity, or Firestore map.
  factory DividendPaymentEvent.fromDividendMap(
    dynamic json, {
    String? defaultSymbol,
    double? fallbackShares,
  }) {
    if (json is! Map) {
      throw ArgumentError('json must be a Map');
    }

    String sym = defaultSymbol ?? '';
    if (json['symbol'] is String && (json['symbol'] as String).isNotEmpty) {
      sym = json['symbol'] as String;
    } else if (json['instrumentObj'] is Map &&
        json['instrumentObj']['symbol'] is String) {
      sym = json['instrumentObj']['symbol'] as String;
    } else if (json['instrument'] is String &&
        !(json['instrument'] as String).startsWith('http')) {
      sym = json['instrument'] as String;
    }

    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      if (val is String && val.isNotEmpty) {
        return DateTime.tryParse(val);
      }
      return null;
    }

    double? parseNum(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      if (val is String && val.isNotEmpty) {
        return double.tryParse(val);
      }
      return null;
    }

    final payableDate =
        parseDate(json['payable_date'] ?? json['pay_date'] ?? json['date']);
    final recordDate = parseDate(json['record_date']);
    final exDividendDate =
        parseDate(json['ex_dividend_date'] ?? json['ex_date']);

    var amount = parseNum(json['amount']);
    final rate = parseNum(json['rate']);
    var shares =
        parseNum(json['position'] ?? json['shares'] ?? json['shares_held']) ??
            fallbackShares;

    // If amount is not set but rate and shares are present, calculate amount
    if (amount == null && rate != null && shares != null && shares > 0) {
      amount = rate * shares;
    }

    final state = json['state']?.toString().toLowerCase();
    final isReinvested = json['is_reinvested'] == true ||
        state == 'reinvested' ||
        json['drip_dividend_id'] != null;

    final divYield = parseNum(json['dividend_yield'] ?? json['yield']);

    return DividendPaymentEvent(
      symbol: sym,
      payableDate: payableDate,
      recordDate: recordDate,
      exDividendDate: exDividendDate,
      amount: amount,
      rate: rate,
      sharesHeld: shares,
      state: state,
      isReinvested: isReinvested,
      frequency: json['frequency']?.toString(),
      dividendYield: divYield,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'payable_date': payableDate?.toIso8601String(),
      'record_date': recordDate?.toIso8601String(),
      'ex_dividend_date': exDividendDate?.toIso8601String(),
      'amount': amount,
      'rate': rate,
      'shares_held': sharesHeld,
      'state': state,
      'is_reinvested': isReinvested,
      'frequency': frequency,
      'dividend_yield': dividendYield,
    };
  }

  factory DividendPaymentEvent.fromJson(Map<String, dynamic> json) {
    return DividendPaymentEvent.fromDividendMap(json);
  }
}
