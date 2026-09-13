import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/utils/json.dart';

final _currencyFormat = NumberFormat.simpleCurrency();
final _dateFormat = DateFormat('MMM d, yyyy');
final _percentFormat = NumberFormat.percentPattern()..maximumFractionDigits = 2;

/// Classification of margin call regulatory origin and rule.
enum MarginCallType {
  maintenance,
  federal, // Regulation T
  dayTrade, // Day Trade Call (FINRA 4210)
  house, // Broker-specific house maintenance
  exchange,
  other,
}

/// Status of the margin call demand.
enum MarginCallState {
  open,
  satisfied,
  closed,
  waived,
  canceled,
}

/// Represents an individual margin call demand issued against an account.
class MarginCall {
  final String id;
  final String? account;
  final String? accountNumber;
  final MarginCallType type;
  final MarginCallState state;
  final double amount; // Deficit demand
  final double? cashDeficit;
  final double? equityDeficit;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? dueDate;
  final DateTime? satisfiedAt;
  final String? reason;
  final String? description;

  const MarginCall({
    required this.id,
    this.account,
    this.accountNumber,
    this.type = MarginCallType.maintenance,
    this.state = MarginCallState.open,
    required this.amount,
    this.cashDeficit,
    this.equityDeficit,
    this.createdAt,
    this.updatedAt,
    this.dueDate,
    this.satisfiedAt,
    this.reason,
    this.description,
  });

  factory MarginCall.fromJson(dynamic json) {
    if (json is! Map) {
      return MarginCall(
        id: 'unknown_${DateTime.now().millisecondsSinceEpoch}',
        amount: 0.0,
      );
    }

    final id = json['id']?.toString() ??
        'call_${DateTime.now().millisecondsSinceEpoch}';
    final account = json['account']?.toString();
    final accountNumber = json['account_number']?.toString() ??
        (account != null ? _extractAccountNumber(account) : null);

    final rawType = (json['type'] ?? json['call_type'] ?? 'maintenance')
        .toString()
        .toLowerCase();
    MarginCallType type;
    if (rawType.contains('reg') ||
        rawType.contains('fed') ||
        rawType.contains('t_call')) {
      type = MarginCallType.federal;
    } else if (rawType.contains('day') || rawType.contains('pdt')) {
      type = MarginCallType.dayTrade;
    } else if (rawType.contains('house')) {
      type = MarginCallType.house;
    } else if (rawType.contains('exchange')) {
      type = MarginCallType.exchange;
    } else if (rawType.contains('maint')) {
      type = MarginCallType.maintenance;
    } else {
      type = MarginCallType.other;
    }

    final rawState =
        (json['state'] ?? json['status'] ?? 'open').toString().toLowerCase();
    MarginCallState state;
    if (rawState.contains('sat')) {
      state = MarginCallState.satisfied;
    } else if (rawState.contains('close')) {
      state = MarginCallState.closed;
    } else if (rawState.contains('waiv')) {
      state = MarginCallState.waived;
    } else if (rawState.contains('cancel')) {
      state = MarginCallState.canceled;
    } else {
      state = MarginCallState.open;
    }

    final amount = parseDouble(json['amount']) ??
        parseDouble(json['deficit']) ??
        parseDouble(json['demand_amount']) ??
        0.0;

    final cashDeficit = parseDouble(json['cash_deficit']);
    final equityDeficit = parseDouble(json['equity_deficit']);

    DateTime? createdAt;
    if (json['created_at'] != null) {
      createdAt = DateTime.tryParse(json['created_at'].toString());
    }

    DateTime? updatedAt;
    if (json['updated_at'] != null) {
      updatedAt = DateTime.tryParse(json['updated_at'].toString());
    }

    DateTime? dueDate;
    final rawDue = json['due_date'] ?? json['deadline'];
    if (rawDue != null) {
      dueDate = DateTime.tryParse(rawDue.toString());
    }

    DateTime? satisfiedAt;
    if (json['satisfied_at'] != null) {
      satisfiedAt = DateTime.tryParse(json['satisfied_at'].toString());
    }

    final reason = json['reason']?.toString();
    final description = json['description']?.toString() ??
        json['message']?.toString() ??
        json['details']?.toString();

    return MarginCall(
      id: id,
      account: account,
      accountNumber: accountNumber,
      type: type,
      state: state,
      amount: amount,
      cashDeficit: cashDeficit,
      equityDeficit: equityDeficit,
      createdAt: createdAt,
      updatedAt: updatedAt,
      dueDate: dueDate,
      satisfiedAt: satisfiedAt,
      reason: reason,
      description: description,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account': account,
      'account_number': accountNumber,
      'type': type.name,
      'state': state.name,
      'amount': amount,
      'cash_deficit': cashDeficit,
      'equity_deficit': equityDeficit,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'satisfied_at': satisfiedAt?.toIso8601String(),
      'reason': reason,
      'description': description,
    };
  }

  static String? _extractAccountNumber(String url) {
    final segments = Uri.tryParse(url)?.pathSegments;
    if (segments != null && segments.length >= 2) {
      final accIdx = segments.indexOf('accounts');
      if (accIdx != -1 && accIdx + 1 < segments.length) {
        return segments[accIdx + 1];
      }
    }
    return null;
  }

  bool get isOpen => state == MarginCallState.open;
  bool get isSatisfied => state == MarginCallState.satisfied;

  bool get isOverdue {
    if (!isOpen || dueDate == null) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  Duration? get remainingTime {
    if (dueDate == null) return null;
    final diff = dueDate!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  String get displayType {
    switch (type) {
      case MarginCallType.maintenance:
        return 'Maintenance Call';
      case MarginCallType.federal:
        return 'Regulation T Call';
      case MarginCallType.dayTrade:
        return 'Day Trade Call';
      case MarginCallType.house:
        return 'House Call';
      case MarginCallType.exchange:
        return 'Exchange Call';
      case MarginCallType.other:
        return 'Margin Call';
    }
  }

  String get displayState {
    switch (state) {
      case MarginCallState.open:
        return isOverdue ? 'Overdue' : 'Active Deficit';
      case MarginCallState.satisfied:
        return 'Satisfied';
      case MarginCallState.closed:
        return 'Closed';
      case MarginCallState.waived:
        return 'Waived';
      case MarginCallState.canceled:
        return 'Canceled';
    }
  }

  Color get stateColor {
    switch (state) {
      case MarginCallState.open:
        return isOverdue ? Colors.red : Colors.orange;
      case MarginCallState.satisfied:
        return Colors.green;
      case MarginCallState.closed:
        return Colors.grey;
      case MarginCallState.waived:
        return Colors.blueGrey;
      case MarginCallState.canceled:
        return Colors.grey;
    }
  }

  IconData get stateIcon {
    switch (state) {
      case MarginCallState.open:
        return isOverdue ? Icons.error_rounded : Icons.warning_amber_rounded;
      case MarginCallState.satisfied:
        return Icons.check_circle_rounded;
      case MarginCallState.closed:
      case MarginCallState.canceled:
        return Icons.cancel_outlined;
      case MarginCallState.waived:
        return Icons.shield_outlined;
    }
  }

  String get formattedAmount => _currencyFormat.format(amount);

  String? get formattedDueDate =>
      dueDate != null ? _dateFormat.format(dueDate!) : null;
}

/// Represents a monthly margin interest debit or financing charge from
/// `/cash_journal/margin_interest_charges/`.
class MarginInterestCharge {
  final String id;
  final String? account;
  final String? accountNumber;
  final double amount;
  final String state; // 'posted', 'pending', 'scheduled'
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? effectiveDate;
  final double? interestRate; // e.g. 0.065 for 6.5%
  final double? settledAmountBorrowed; // Average daily balance
  final String? description;
  final DateTime? periodStart;
  final DateTime? periodEnd;

  const MarginInterestCharge({
    required this.id,
    this.account,
    this.accountNumber,
    required this.amount,
    this.state = 'posted',
    this.createdAt,
    this.updatedAt,
    this.effectiveDate,
    this.interestRate,
    this.settledAmountBorrowed,
    this.description,
    this.periodStart,
    this.periodEnd,
  });

  factory MarginInterestCharge.fromJson(dynamic json) {
    if (json is! Map) {
      return MarginInterestCharge(
        id: 'unknown_${DateTime.now().millisecondsSinceEpoch}',
        amount: 0.0,
      );
    }

    final id = json['id']?.toString() ??
        'mic_${DateTime.now().millisecondsSinceEpoch}';
    final account = json['account']?.toString();
    final accountNumber = json['account_number']?.toString();

    final amount = parseDouble(json['amount']) ??
        parseDouble(json['charge_amount']) ??
        0.0;

    final state = (json['state'] ?? json['status'] ?? 'posted').toString();

    DateTime? createdAt;
    if (json['created_at'] != null) {
      createdAt = DateTime.tryParse(json['created_at'].toString());
    }

    DateTime? updatedAt;
    if (json['updated_at'] != null) {
      updatedAt = DateTime.tryParse(json['updated_at'].toString());
    }

    DateTime? effectiveDate;
    final rawEff = json['effective_date'] ?? json['date'] ?? json['posted_at'];
    if (rawEff != null) {
      effectiveDate = DateTime.tryParse(rawEff.toString());
    }

    double? interestRate = parseDouble(json['interest_rate']) ??
        parseDouble(json['rate']) ??
        parseDouble(json['annual_percentage_rate']);
    // Normalize percentage if > 1.0 (e.g. 6.5 -> 0.065)
    if (interestRate != null && interestRate > 1.0) {
      interestRate = interestRate / 100.0;
    }

    final settledAmountBorrowed =
        parseDouble(json['settled_amount_borrowed']) ??
            parseDouble(json['average_daily_balance']) ??
            parseDouble(json['principal']);

    final description = json['description']?.toString() ??
        json['details']?.toString() ??
        'Margin Interest Charge';

    DateTime? periodStart;
    if (json['period_start'] != null) {
      periodStart = DateTime.tryParse(json['period_start'].toString());
    }

    DateTime? periodEnd;
    if (json['period_end'] != null) {
      periodEnd = DateTime.tryParse(json['period_end'].toString());
    }

    return MarginInterestCharge(
      id: id,
      account: account,
      accountNumber: accountNumber,
      amount: amount,
      state: state,
      createdAt: createdAt,
      updatedAt: updatedAt,
      effectiveDate: effectiveDate,
      interestRate: interestRate,
      settledAmountBorrowed: settledAmountBorrowed,
      description: description,
      periodStart: periodStart,
      periodEnd: periodEnd,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account': account,
      'account_number': accountNumber,
      'amount': amount,
      'state': state,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'effective_date': effectiveDate?.toIso8601String(),
      'interest_rate': interestRate,
      'settled_amount_borrowed': settledAmountBorrowed,
      'description': description,
      'period_start': periodStart?.toIso8601String(),
      'period_end': periodEnd?.toIso8601String(),
    };
  }

  bool get isPosted => state.toLowerCase() == 'posted';
  bool get isPending => state.toLowerCase() == 'pending';

  String get formattedAmount => _currencyFormat.format(amount);

  String? get formattedEffectiveDate =>
      effectiveDate != null ? _dateFormat.format(effectiveDate!) : null;

  String get formattedInterestRate => interestRate != null
      ? _percentFormat.format(interestRate!)
      : 'Standard Tier';

  String? get formattedPrincipal => settledAmountBorrowed != null
      ? _currencyFormat.format(settledAmountBorrowed!)
      : null;

  String? get formattedSettledAmountBorrowed => formattedPrincipal;
}

/// Aggregated summary model combining active margin calls, deficit demands,
/// and financing charges history.
class MarginFinancingSummary {
  final String accountNumber;
  final List<MarginCall> marginCalls;
  final List<MarginInterestCharge> interestCharges;
  final int openCallsCount;
  final double totalDeficitDemand;
  final DateTime? nearestDueDate;
  final double totalInterestYtd;
  final double latestMonthlyCharge;
  final double averageBorrowingRate;
  final DateTime updatedAt;

  const MarginFinancingSummary({
    required this.accountNumber,
    this.marginCalls = const [],
    this.interestCharges = const [],
    this.openCallsCount = 0,
    this.totalDeficitDemand = 0.0,
    this.nearestDueDate,
    this.totalInterestYtd = 0.0,
    this.latestMonthlyCharge = 0.0,
    this.averageBorrowingRate = 0.0,
    required this.updatedAt,
  });

  factory MarginFinancingSummary.fromMarginCallsAndInterest({
    required String accountNumber,
    required List<dynamic> rawCalls,
    required List<dynamic> rawInterestCharges,
  }) {
    final calls = <MarginCall>[];
    for (final item in rawCalls) {
      if (item != null) {
        calls.add(MarginCall.fromJson(item));
      }
    }

    final charges = <MarginInterestCharge>[];
    for (final item in rawInterestCharges) {
      if (item != null) {
        charges.add(MarginInterestCharge.fromJson(item));
      }
    }

    // Sort calls: open first, then by due date ascending
    calls.sort((a, b) {
      if (a.isOpen && !b.isOpen) return -1;
      if (!a.isOpen && b.isOpen) return 1;
      if (a.dueDate != null && b.dueDate != null) {
        return a.dueDate!.compareTo(b.dueDate!);
      }
      return 0;
    });

    // Sort charges: newest effective date first
    charges.sort((a, b) {
      final aDate = a.effectiveDate ?? a.createdAt ?? DateTime(1970);
      final bDate = b.effectiveDate ?? b.createdAt ?? DateTime(1970);
      return bDate.compareTo(aDate);
    });

    final openCalls = calls.where((c) => c.isOpen).toList();
    final openCallsCount = openCalls.length;
    final totalDeficitDemand =
        openCalls.fold<double>(0.0, (sum, call) => sum + call.amount);

    DateTime? nearestDueDate;
    for (final call in openCalls) {
      if (call.dueDate != null) {
        if (nearestDueDate == null || call.dueDate!.isBefore(nearestDueDate)) {
          nearestDueDate = call.dueDate;
        }
      }
    }

    final now = DateTime.now();
    final currentYear = now.year;
    double ytdTotal = 0.0;
    for (final c in charges) {
      final date = c.effectiveDate ?? c.createdAt;
      if (date != null && date.year == currentYear) {
        ytdTotal += c.amount;
      }
    }

    final latestMonthlyCharge = charges.isNotEmpty ? charges.first.amount : 0.0;

    double rateSum = 0.0;
    int rateCount = 0;
    for (final c in charges) {
      if (c.interestRate != null && c.interestRate! > 0) {
        rateSum += c.interestRate!;
        rateCount++;
      }
    }
    final averageBorrowingRate = rateCount > 0 ? (rateSum / rateCount) : 0.065;

    return MarginFinancingSummary(
      accountNumber: accountNumber,
      marginCalls: calls,
      interestCharges: charges,
      openCallsCount: openCallsCount,
      totalDeficitDemand: totalDeficitDemand,
      nearestDueDate: nearestDueDate,
      totalInterestYtd: ytdTotal,
      latestMonthlyCharge: latestMonthlyCharge,
      averageBorrowingRate: averageBorrowingRate,
      updatedAt: DateTime.now(),
    );
  }

  bool get hasActiveMarginCall => openCallsCount > 0 && totalDeficitDemand > 0;

  String get formattedTotalDeficit => _currencyFormat.format(totalDeficitDemand);
  String get formattedTotalInterestYtd =>
      _currencyFormat.format(totalInterestYtd);
  String get formattedLatestMonthlyCharge =>
      _currencyFormat.format(latestMonthlyCharge);
  String get formattedAverageRate =>
      _percentFormat.format(averageBorrowingRate);
}
