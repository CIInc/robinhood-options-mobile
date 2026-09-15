import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/utils/json.dart';

final _currencyFormat = NumberFormat.simpleCurrency();

/// Known IRS IRA contribution limits by tax year.
const Map<int, double> kIrsIraLimits = {
  2023: 6500.0,
  2024: 7000.0,
  2025: 7000.0,
  2026: 7000.0,
};

/// Known IRS IRA catch-up contribution limits (age 50+) by tax year.
const Map<int, double> kIrsIraCatchUpLimits = {
  2023: 7500.0,
  2024: 8000.0,
  2025: 8000.0,
  2026: 8000.0,
};

/// Represents an annual IRA contribution breakdown, match, and IRS limit for a specific year.
class RetirementContribution {
  final int year;
  final String accountType; // 'ira_traditional', 'ira_roth'
  final double contributionAmount;
  final double matchAmount;
  final double matchRate;
  final double directContributions;
  final double rolloverContributions;
  final double conversions;
  final double limit;
  final double catchUpLimit;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String status;

  const RetirementContribution({
    required this.year,
    this.accountType = 'ira_roth',
    this.contributionAmount = 0.0,
    this.matchAmount = 0.0,
    this.matchRate = 0.01,
    this.directContributions = 0.0,
    this.rolloverContributions = 0.0,
    this.conversions = 0.0,
    this.limit = 7000.0,
    this.catchUpLimit = 8000.0,
    this.createdAt,
    this.updatedAt,
    this.status = 'active',
  });

  factory RetirementContribution.fromJson(dynamic json) {
    if (json is! Map) {
      return RetirementContribution(year: DateTime.now().year);
    }

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      try {
        return DateTime.parse(value.toString());
      } catch (_) {
        return null;
      }
    }

    final parsedYear =
        int.tryParse(
          json['year']?.toString() ??
              json['tax_year']?.toString() ??
              DateTime.now().year.toString(),
        ) ??
        DateTime.now().year;

    final defaultLimit = kIrsIraLimits[parsedYear] ?? 7000.0;
    final defaultCatchUpLimit =
        kIrsIraCatchUpLimits[parsedYear] ?? (defaultLimit + 1000.0);

    final contribAmt =
        parseDouble(
          json['contribution_amount'] ??
              json['total_contributions'] ??
              json['amount'] ??
              json['contributions'],
        ) ??
        0.0;
    final matchAmt =
        parseDouble(
          json['match_amount'] ?? json['total_match'] ?? json['match'],
        ) ??
        0.0;
    final rate = parseDouble(json['match_rate'] ?? json['rate']) ?? 0.01;
    final direct = parseDouble(json['direct_contributions']) ?? contribAmt;
    final rollover =
        parseDouble(json['rollover_contributions'] ?? json['rollover']) ?? 0.0;
    final conv = parseDouble(json['conversions'] ?? json['conversion']) ?? 0.0;

    final customLimit =
        parseDouble(json['limit'] ?? json['contribution_limit']) ??
        defaultLimit;
    final customCatchUp =
        parseDouble(json['catch_up_limit']) ?? defaultCatchUpLimit;

    return RetirementContribution(
      year: parsedYear,
      accountType: (json['account_type'] ?? json['type'] ?? 'ira_roth')
          .toString(),
      contributionAmount: contribAmt,
      matchAmount: matchAmt,
      matchRate: rate,
      directContributions: direct,
      rolloverContributions: rollover,
      conversions: conv,
      limit: customLimit,
      catchUpLimit: customCatchUp,
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
      status: (json['status'] ?? 'active').toString(),
    );
  }

  double get remainingLimit =>
      (limit - contributionAmount).clamp(0.0, double.infinity);
  double get remainingCatchUpLimit =>
      (catchUpLimit - contributionAmount).clamp(0.0, double.infinity);

  double get progressPercentage =>
      limit > 0 ? (contributionAmount / limit).clamp(0.0, 1.0) : 0.0;
  double get catchUpProgressPercentage => catchUpLimit > 0
      ? (contributionAmount / catchUpLimit).clamp(0.0, 1.0)
      : 0.0;

  bool get isMaxedOut => contributionAmount >= limit;
  bool get isTraditional => accountType.toLowerCase().contains('traditional');
  bool get isRoth => accountType.toLowerCase().contains('roth');

  String get displayAccountType {
    if (isRoth) return 'Roth IRA';
    if (isTraditional) return 'Traditional IRA';
    return 'IRA';
  }

  String get formattedContribution =>
      _currencyFormat.format(contributionAmount);
  String get formattedMatch => _currencyFormat.format(matchAmount);
  String get formattedLimit => _currencyFormat.format(limit);
  String get formattedCatchUpLimit => _currencyFormat.format(catchUpLimit);
  String get formattedRemaining => _currencyFormat.format(remainingLimit);

  Map<String, dynamic> toJson() {
    return {
      'year': year,
      'account_type': accountType,
      'contribution_amount': contributionAmount,
      'match_amount': matchAmount,
      'match_rate': matchRate,
      'direct_contributions': directContributions,
      'rollover_contributions': rolloverContributions,
      'conversions': conversions,
      'limit': limit,
      'catch_up_limit': catchUpLimit,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      'status': status,
    };
  }
}

/// Aggregated history of retirement account contributions, matches, and limits.
class RetirementHistory {
  final List<RetirementContribution> contributions;
  final double totalContributions;
  final double totalMatch;
  final String? accountId;
  final String? accountNumber;

  const RetirementHistory({
    this.contributions = const [],
    this.totalContributions = 0.0,
    this.totalMatch = 0.0,
    this.accountId,
    this.accountNumber,
  });

  factory RetirementHistory.fromJson(dynamic json) {
    if (json == null) {
      return const RetirementHistory();
    }

    List<RetirementContribution> items = [];
    double totalContrib = 0.0;
    double totalMatchAmt = 0.0;

    dynamic rawList;
    if (json is List) {
      rawList = json;
    } else if (json is Map) {
      rawList = json['results'] ?? json['history'] ?? json['contributions'];
      totalContrib =
          parseDouble(
            json['total_contributions'] ?? json['total_contribution'],
          ) ??
          0.0;
      totalMatchAmt =
          parseDouble(json['total_match'] ?? json['total_match_amount']) ?? 0.0;
    }

    if (rawList is List) {
      for (final item in rawList) {
        final contrib = RetirementContribution.fromJson(item);
        items.add(contrib);
        if (totalContrib == 0.0) {
          totalContrib += contrib.contributionAmount;
        }
        if (totalMatchAmt == 0.0) {
          totalMatchAmt += contrib.matchAmount;
        }
      }
    }

    // Sort by year descending
    items.sort((a, b) => b.year.compareTo(a.year));

    final acctId = json is Map
        ? (json['account_id'] ?? json['account'] ?? '').toString()
        : null;
    final acctNum = json is Map ? json['account_number']?.toString() : null;

    return RetirementHistory(
      contributions: items,
      totalContributions: totalContrib,
      totalMatch: totalMatchAmt,
      accountId: acctId,
      accountNumber: acctNum,
    );
  }

  RetirementContribution? contributionForYear(int year) {
    try {
      return contributions.firstWhere((c) => c.year == year);
    } catch (_) {
      return null;
    }
  }

  RetirementContribution? get currentYearContribution {
    final now = DateTime.now().year;
    return contributionForYear(now);
  }

  String get formattedTotalContributions =>
      _currencyFormat.format(totalContributions);
  String get formattedTotalMatch => _currencyFormat.format(totalMatch);

  Map<String, dynamic> toJson() {
    return {
      'contributions': contributions.map((c) => c.toJson()).toList(),
      'total_contributions': totalContributions,
      'total_match': totalMatch,
      if (accountId != null) 'account_id': accountId,
      if (accountNumber != null) 'account_number': accountNumber,
    };
  }
}
