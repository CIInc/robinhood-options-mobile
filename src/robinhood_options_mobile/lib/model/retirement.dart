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

/// Represents an individual retirement account transaction (e.g. IRA contribution or match).
class RetirementTransaction {
  final String id;
  final String title;
  final double amount;
  final double matchAmount;
  final double matchRate;
  final int taxYear;
  final DateTime? date;
  final String status;
  final String? accountType;
  final String? description;

  const RetirementTransaction({
    required this.id,
    this.title = 'IRA Contribution',
    required this.amount,
    this.matchAmount = 0.0,
    this.matchRate = 0.0,
    required this.taxYear,
    this.date,
    this.status = 'completed',
    this.accountType,
    this.description,
  });

  String get formattedAmount => _currencyFormat.format(amount);
  String get formattedMatchAmount => _currencyFormat.format(matchAmount);

  factory RetirementTransaction.fromJson(dynamic json) {
    if (json is! Map) {
      return RetirementTransaction(
        id: '',
        amount: 0.0,
        taxYear: DateTime.now().year,
      );
    }

    final id =
        json['id']?.toString() ?? json['payment_transfer_id']?.toString() ?? '';
    final amount = parseDouble(json['amount'] ?? json['net_amount']) ?? 0.0;

    String title = json['title']?.toString() ?? 'IRA Contribution';
    int? parsedTaxYear = int.tryParse(json['tax_year']?.toString() ?? '');
    double matchAmt = parseDouble(json['match_amount']) ?? 0.0;
    double matchRate = parseDouble(json['match_rate']) ?? 0.0;

    // Check enoki_amount in details (internal Robinhood match metadata)
    if (json['details'] is Map) {
      final details = json['details'] as Map;
      if (details['enoki_amount'] is Map) {
        final enokiAmt = parseDouble(details['enoki_amount']['amount']);
        if (enokiAmt != null && enokiAmt > 0) {
          matchAmt = enokiAmt;
        }
      }
    }

    // Check contribution_details SDUI rows from PaymentHub /contribution/ endpoint
    if (json['contribution_details'] is Map) {
      final cDetails = json['contribution_details'] as Map;
      final rows = cDetails['rows'];
      if (rows is List) {
        for (final row in rows) {
          if (row is! Map) continue;
          final label = row['label']?.toString().toLowerCase();
          final val = row['value']?.toString();
          if (val == null) continue;

          if (label == 'contribution type') {
            title = val;
          } else if (label == 'tax year') {
            parsedTaxYear = int.tryParse(val);
          } else if (label == 'match percentage') {
            final clean = val.replaceAll('%', '').trim();
            final rateVal = double.tryParse(clean);
            if (rateVal != null) {
              matchRate = rateVal > 0.05 ? rateVal / 100.0 : rateVal;
            }
          } else if (label == 'total match amount' || label == 'match amount') {
            final clean = val.replaceAll('\$', '').replaceAll(',', '').trim();
            final matchVal = double.tryParse(clean);
            if (matchVal != null) {
              matchAmt = matchVal;
            }
          }
        }
      }
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

    final date =
        parseDate(json['created_at'] ?? json['completed_at'] ?? json['date']);
    parsedTaxYear ??= date?.year ?? DateTime.now().year;

    if (matchRate == 0.0 && amount > 0 && matchAmt > 0) {
      matchRate = (matchAmt / amount);
    }

    return RetirementTransaction(
      id: id,
      title: title,
      amount: amount,
      matchAmount: matchAmt,
      matchRate: matchRate,
      taxYear: parsedTaxYear,
      date: date,
      status: (json['state'] ?? json['status'] ?? 'completed').toString(),
      accountType: json['originating_account_type']?.toString(),
      description: json['description']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'match_amount': matchAmount,
      'match_rate': matchRate,
      'tax_year': taxYear,
      if (date != null) 'date': date!.toIso8601String(),
      'status': status,
      if (accountType != null) 'account_type': accountType,
      if (description != null) 'description': description,
    };
  }
}

/// Represents an annual IRA contribution breakdown, match, and IRS limit for a specific year.
class RetirementContribution {
  final int year;
  final String accountType; // 'ira_traditional', 'ira_roth'
  final String? accountNumber;
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
  final String? sourceDescription;
  final List<RetirementTransaction> transactions;

  const RetirementContribution({
    required this.year,
    this.accountType = 'ira_roth',
    this.accountNumber,
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
    this.sourceDescription,
    this.transactions = const [],
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

    final parsedYear = int.tryParse(json['year']?.toString() ??
            json['tax_year']?.toString() ??
            DateTime.now().year.toString()) ??
        DateTime.now().year;

    final defaultLimit = kIrsIraLimits[parsedYear] ?? 7000.0;
    final defaultCatchUpLimit =
        kIrsIraCatchUpLimits[parsedYear] ?? (defaultLimit + 1000.0);

    final rawAccountType = (json['account_type'] ??
            json['type'] ??
            json['brokerage_account_type'] ??
            '')
        .toString();
    final parsedAccountType =
        rawAccountType.isNotEmpty ? rawAccountType : 'ira_roth';

    final direct = parseDouble(json['direct_contributions'] ??
            json['total_direct_contributions'] ??
            json['direct']) ??
        0.0;
    final rollover = parseDouble(json['rollover_contributions'] ??
            json['total_rollover_contributions'] ??
            json['rollover']) ??
        0.0;
    final conv = parseDouble(json['conversions'] ?? json['conversion']) ?? 0.0;

    double contribAmt = parseDouble(json['contribution_amount'] ??
            json['total_contributions'] ??
            json['amount'] ??
            json['contributions']) ??
        0.0;
    // If direct contributions are present but contribution_amount is zero/absent,
    // use direct contributions as the annual contribution figure.
    if (contribAmt == 0.0 && direct > 0.0) {
      contribAmt = direct;
    }

    final matchAmt = parseDouble(
            json['match_amount'] ?? json['total_match'] ?? json['match']) ??
        0.0;
    final rate = parseDouble(json['match_rate'] ?? json['rate']) ?? 0.01;

    final customLimit =
        parseDouble(json['limit'] ?? json['contribution_limit']) ??
            defaultLimit;
    final customCatchUp =
        parseDouble(json['catch_up_limit']) ?? defaultCatchUpLimit;

    final acctNum = json['account_number']?.toString() ??
        json['account']?.toString() ??
        json['rhs_account_number']?.toString();

    final txList = <RetirementTransaction>[];
    if (json['transactions'] is List) {
      for (final tx in json['transactions']) {
        txList.add(RetirementTransaction.fromJson(tx));
      }
    }

    return RetirementContribution(
      year: parsedYear,
      accountType: parsedAccountType,
      accountNumber: acctNum,
      contributionAmount: contribAmt,
      matchAmount: matchAmt,
      matchRate: rate,
      directContributions: direct > 0 ? direct : contribAmt,
      rolloverContributions: rollover,
      conversions: conv,
      limit: customLimit,
      catchUpLimit: customCatchUp,
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
      status: (json['status'] ?? 'active').toString(),
      sourceDescription: json['source_description']?.toString() ??
          json['contra_broker_name']?.toString() ??
          json['description']?.toString(),
      transactions: txList,
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
      if (accountNumber != null) 'account_number': accountNumber,
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
      if (sourceDescription != null) 'source_description': sourceDescription,
      if (transactions.isNotEmpty)
        'transactions': transactions.map((t) => t.toJson()).toList(),
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
  final double? totalValue;

  const RetirementHistory({
    this.contributions = const [],
    this.totalContributions = 0.0,
    this.totalMatch = 0.0,
    this.accountId,
    this.accountNumber,
    this.totalValue,
  });

  factory RetirementHistory.fromJson(dynamic json) {
    if (json == null) {
      return const RetirementHistory();
    }

    List<RetirementContribution> items = [];
    double? explicitTotalContrib;
    double? explicitTotalMatch;

    dynamic rawList;
    if (json is List) {
      rawList = json;
    } else if (json is Map) {
      rawList = json['results'] ?? json['history'] ?? json['contributions'];
      explicitTotalContrib = parseDouble(
          json['total_contributions'] ?? json['total_contribution']);
      explicitTotalMatch =
          parseDouble(json['total_match'] ?? json['total_match_amount']);
    }

    if (rawList is List) {
      for (final item in rawList) {
        final contrib = RetirementContribution.fromJson(item);
        items.add(contrib);
      }
    }

    final acctId = json is Map
        ? (json['account_id'] ?? json['account'] ?? '').toString()
        : null;
    final acctNum = json is Map ? json['account_number']?.toString() : null;
    final accountType = json is Map
        ? (json['account_type'] ??
                json['brokerage_account_type'] ??
                'ira_traditional')
            .toString()
        : 'ira_traditional';
    final totalValue = json is Map ? parseDouble(json['total_value']) : null;
    final rawMatchRate = json is Map ? parseDouble(json['match_rate']) : null;
    final matchRate = rawMatchRate != null
        ? (rawMatchRate > 0.05 ? rawMatchRate / 100.0 : rawMatchRate)
        : 0.01;

    // Process ACATS rollovers/transfers if provided
    if (json is Map && json['acats'] is List) {
      final acatsList = json['acats'] as List;
      for (final acat in acatsList) {
        if (acat is! Map) continue;
        final phase = (acat['phase'] ?? '').toString();
        if (phase != 'settled' && phase != 'completed' && phase.isNotEmpty) {
          continue;
        }
        final rhsAcct = acat['rhs_account_number']?.toString();
        if (acctNum != null &&
            rhsAcct != null &&
            rhsAcct.isNotEmpty &&
            rhsAcct != acctNum) {
          continue;
        }

        final settlementDateStr =
            (acat['settlement_date'] ?? acat['requested_at'] ?? '').toString();
        int transferYear = DateTime.now().year;
        if (settlementDateStr.length >= 4) {
          transferYear =
              int.tryParse(settlementDateStr.substring(0, 4)) ?? transferYear;
        }

        final contraBroker = acat['contra_broker_name']?.toString() ??
            acat['contra_account_name']?.toString() ??
            'Rollover';
        final transferValue =
            parseDouble(acat['market_value']) ?? totalValue ?? 0.0;

        final existingIndex = items.indexWhere((c) => c.year == transferYear);
        if (existingIndex >= 0) {
          final existing = items[existingIndex];
          items[existingIndex] = RetirementContribution(
            year: existing.year,
            accountType: existing.accountType,
            accountNumber: existing.accountNumber ?? acctNum,
            contributionAmount: existing.contributionAmount,
            matchAmount: existing.matchAmount,
            matchRate: existing.matchRate > 0 ? existing.matchRate : matchRate,
            directContributions: existing.directContributions,
            rolloverContributions: existing.rolloverContributions > 0
                ? existing.rolloverContributions
                : transferValue,
            conversions: existing.conversions,
            limit: existing.limit,
            catchUpLimit: existing.catchUpLimit,
            createdAt: existing.createdAt,
            updatedAt: existing.updatedAt,
            status: existing.status,
            sourceDescription: 'Rollover from $contraBroker',
          );
        } else {
          items.add(RetirementContribution(
            year: transferYear,
            accountType: accountType,
            accountNumber: acctNum,
            contributionAmount: 0.0,
            matchAmount: 0.0,
            matchRate: matchRate,
            directContributions: 0.0,
            rolloverContributions: transferValue,
            limit: kIrsIraLimits[transferYear] ?? 7000.0,
            catchUpLimit: kIrsIraCatchUpLimits[transferYear] ?? 8000.0,
            status: 'settled',
            sourceDescription: 'Rollover from $contraBroker',
          ));
        }
      }
    }

    // Process unified transfers (PaymentHub direct IRA contributions and match)
    if (json is Map && json['unified_transfers'] is List) {
      final transfers = json['unified_transfers'] as List;
      final Map<int, List<RetirementTransaction>> yearTransactions = {};
      for (final t in transfers) {
        final tx = RetirementTransaction.fromJson(t);
        if (tx.amount <= 0 && tx.matchAmount <= 0) continue;
        yearTransactions.putIfAbsent(tx.taxYear, () => []).add(tx);
      }

      for (final entry in yearTransactions.entries) {
        final txYear = entry.key;
        final txList = entry.value;
        txList.sort(
            (a, b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));

        final totalYearAmount =
            txList.fold<double>(0.0, (sum, tx) => sum + tx.amount);
        final totalYearMatch =
            txList.fold<double>(0.0, (sum, tx) => sum + tx.matchAmount);
        final yearMatchRate = txList.isNotEmpty && txList.first.matchRate > 0
            ? txList.first.matchRate
            : matchRate;

        final existingIndex = items.indexWhere((c) => c.year == txYear);
        if (existingIndex >= 0) {
          final existing = items[existingIndex];
          final contribAmt = existing.contributionAmount > 0
              ? existing.contributionAmount
              : totalYearAmount;
          final matchAmt =
              existing.matchAmount > 0 ? existing.matchAmount : totalYearMatch;

          items[existingIndex] = RetirementContribution(
            year: existing.year,
            accountType: existing.accountType,
            accountNumber: existing.accountNumber ?? acctNum,
            contributionAmount: contribAmt,
            matchAmount: matchAmt,
            matchRate:
                existing.matchRate > 0 ? existing.matchRate : yearMatchRate,
            directContributions: contribAmt,
            rolloverContributions: existing.rolloverContributions,
            conversions: existing.conversions,
            limit: existing.limit,
            catchUpLimit: existing.catchUpLimit,
            createdAt: existing.createdAt ?? txList.first.date,
            updatedAt: existing.updatedAt,
            status: existing.status,
            sourceDescription: existing.sourceDescription,
            transactions: [...existing.transactions, ...txList],
          );
        } else {
          items.add(RetirementContribution(
            year: txYear,
            accountType: accountType,
            accountNumber: acctNum,
            contributionAmount: totalYearAmount,
            matchAmount: totalYearMatch,
            matchRate: yearMatchRate,
            directContributions: totalYearAmount,
            rolloverContributions: 0.0,
            limit: kIrsIraLimits[txYear] ?? 7000.0,
            catchUpLimit: kIrsIraCatchUpLimits[txYear] ?? 8000.0,
            status: 'completed',
            createdAt: txList.first.date,
            transactions: txList,
          ));
        }
      }
    }

    // Ensure current tax year is present for active retirement accounts
    if (acctNum != null || (json is Map && json['account_type'] != null)) {
      final currentYear = DateTime.now().year;
      if (!items.any((c) => c.year == currentYear)) {
        items.add(RetirementContribution(
          year: currentYear,
          accountType: accountType,
          accountNumber: acctNum,
          contributionAmount: 0.0,
          matchAmount: 0.0,
          matchRate: matchRate,
          directContributions: 0.0,
          rolloverContributions: 0.0,
          limit: kIrsIraLimits[currentYear] ?? 7000.0,
          catchUpLimit: kIrsIraCatchUpLimits[currentYear] ?? 8000.0,
          status: 'active',
        ));
      }
    }

    // Sort by year descending
    items.sort((a, b) => b.year.compareTo(a.year));

    final double totalContrib = explicitTotalContrib ??
        items.fold<double>(0.0, (double sum, c) => sum + c.contributionAmount);
    final double totalMatchAmt = explicitTotalMatch ??
        items.fold<double>(0.0, (double sum, c) => sum + c.matchAmount);

    return RetirementHistory(
      contributions: items,
      totalContributions: totalContrib,
      totalMatch: totalMatchAmt,
      accountId: acctId,
      accountNumber: acctNum,
      totalValue: totalValue,
    );
  }

  /// Returns contributions filtered by optional account type and account number.
  List<RetirementContribution> contributionsForAccount({
    String? accountType,
    String? accountNumber,
  }) {
    if (accountType == null && accountNumber == null) {
      return contributions;
    }
    final filtered = contributions.where((c) {
      if (accountNumber != null &&
          c.accountNumber != null &&
          c.accountNumber!.isNotEmpty &&
          c.accountNumber != accountNumber) {
        return false;
      }
      if (accountType != null &&
          c.accountType.isNotEmpty &&
          !accountTypeMatches(c.accountType, accountType)) {
        return false;
      }
      return true;
    }).toList();

    return filtered.isNotEmpty ? filtered : contributions;
  }

  /// Finds contribution breakdown for a specific year, optionally filtering by account.
  RetirementContribution? contributionForYear(
    int year, {
    String? accountType,
    String? accountNumber,
  }) {
    // 1. Try matching year, account number, and account type
    if (accountNumber != null || accountType != null) {
      try {
        return contributions.firstWhere((c) {
          if (c.year != year) return false;
          if (accountNumber != null &&
              c.accountNumber != null &&
              c.accountNumber!.isNotEmpty &&
              c.accountNumber != accountNumber) {
            return false;
          }
          if (accountType != null &&
              c.accountType.isNotEmpty &&
              !accountTypeMatches(c.accountType, accountType)) {
            return false;
          }
          return true;
        });
      } catch (_) {
        // Fallback to checking just accountType + year
        if (accountType != null) {
          try {
            return contributions.firstWhere((c) =>
                c.year == year &&
                accountTypeMatches(c.accountType, accountType));
          } catch (_) {}
        }
      }
    }

    // 2. Fallback: match by year alone
    try {
      return contributions.firstWhere((c) => c.year == year);
    } catch (_) {
      return null;
    }
  }

  /// Compares two account type strings (e.g. 'ira_traditional' vs 'traditional')
  static bool accountTypeMatches(String a, String b) {
    final normA =
        a.toLowerCase().replaceAll('_', '').replaceAll(' ', '').trim();
    final normB =
        b.toLowerCase().replaceAll('_', '').replaceAll(' ', '').trim();
    if (normA == normB) return true;
    if (normA.contains('traditional') && normB.contains('traditional')) {
      return true;
    }
    if (normA.contains('roth') && normB.contains('roth')) {
      return true;
    }
    return false;
  }

  RetirementContribution? getCurrentYearContribution({
    String? accountType,
    String? accountNumber,
  }) {
    final now = DateTime.now().year;
    return contributionForYear(now,
        accountType: accountType, accountNumber: accountNumber);
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
