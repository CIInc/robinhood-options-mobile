import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/utils/json.dart';

final _currencyFormat = NumberFormat.simpleCurrency();
final _compactCurrencyFormat = NumberFormat.compactSimpleCurrency();
final _percentFormat = NumberFormat.decimalPercentPattern(decimalDigits: 2);
final _shortDateFormat = DateFormat.yMMMd();

/// Represents a single loaned equity position within a stock loan payment or program snapshot.
class StockLoanPosition {
  final String symbol;
  final String? instrumentId;
  final double quantity;
  final double borrowRate; // e.g. 0.045 for 4.5%
  final double collateralAmount; // 102% cash collateral held in custody
  final double interestEarned;

  const StockLoanPosition({
    required this.symbol,
    this.instrumentId,
    this.quantity = 0.0,
    this.borrowRate = 0.0,
    this.collateralAmount = 0.0,
    this.interestEarned = 0.0,
  });

  factory StockLoanPosition.fromJson(dynamic json) {
    if (json is! Map) {
      return const StockLoanPosition(symbol: '');
    }

    final symbol = json['symbol']?.toString().toUpperCase() ??
        json['ticker']?.toString().toUpperCase() ??
        '';
    final instrumentId = json['instrument_id']?.toString() ??
        json['instrument']?.toString();
    final quantity = parseDouble(json['quantity']) ??
        parseDouble(json['shares']) ??
        parseDouble(json['shares_loaned']) ??
        0.0;
    final borrowRate = parseDouble(json['rate']) ??
        parseDouble(json['borrow_rate']) ??
        parseDouble(json['rebate_rate']) ??
        parseDouble(json['annualized_rate']) ??
        0.0;
    final collateralAmount = parseDouble(json['collateral_amount']) ??
        parseDouble(json['collateral']) ??
        parseDouble(json['cash_collateral']) ??
        0.0;
    final interestEarned = parseDouble(json['interest_earned']) ??
        parseDouble(json['amount']) ??
        parseDouble(json['earnings']) ??
        0.0;

    return StockLoanPosition(
      symbol: symbol,
      instrumentId: instrumentId,
      quantity: quantity,
      borrowRate: borrowRate,
      collateralAmount: collateralAmount,
      interestEarned: interestEarned,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      if (instrumentId != null) 'instrument_id': instrumentId,
      'quantity': quantity,
      'borrow_rate': borrowRate,
      'collateral_amount': collateralAmount,
      'interest_earned': interestEarned,
    };
  }

  String get formattedQuantity =>
      quantity % 1 == 0 ? quantity.toInt().toString() : quantity.toStringAsFixed(2);
  String get formattedBorrowRate => _percentFormat.format(borrowRate);
  String get formattedCollateralAmount => _currencyFormat.format(collateralAmount);
  String get formattedInterestEarned => _currencyFormat.format(interestEarned);
}

/// Represents a historical or pending payout from Robinhood's Fully Paid Securities Lending Program (SLIP).
class StockLoanPayment {
  final String id;
  final String accountNumber;
  final DateTime? paymentDate;
  final double amount;
  final String currencyCode;
  final String status; // 'paid', 'pending', 'settled', 'void'
  final String? description;
  final double? grossRate;
  final double? netRate;
  final List<StockLoanPosition> positions;

  const StockLoanPayment({
    required this.id,
    required this.accountNumber,
    this.paymentDate,
    required this.amount,
    this.currencyCode = 'USD',
    this.status = 'paid',
    this.description,
    this.grossRate,
    this.netRate,
    this.positions = const [],
  });

  factory StockLoanPayment.fromJson(dynamic json) {
    if (json is! Map) {
      return const StockLoanPayment(
        id: 'unknown',
        accountNumber: '',
        amount: 0.0,
      );
    }

    final id = json['id']?.toString() ??
        json['payment_id']?.toString() ??
        'slp_${DateTime.now().millisecondsSinceEpoch}';
    final accountNumber = json['account_number']?.toString() ??
        json['account']?.toString() ??
        '';
    final dateStr = json['payment_date']?.toString() ??
        json['date']?.toString() ??
        json['settlement_date']?.toString() ??
        json['paid_at']?.toString();
    DateTime? paymentDate;
    if (dateStr != null) {
      paymentDate = DateTime.tryParse(dateStr);
    }

    final amount = parseDouble(json['amount']) ??
        parseDouble(json['net_amount']) ??
        parseDouble(json['total_amount']) ??
        0.0;
    final currencyCode = json['currency_code']?.toString() ?? 'USD';
    final status = json['status']?.toString().toLowerCase() ?? 'paid';
    final description = json['description']?.toString() ?? json['memo']?.toString();
    final grossRate = parseDouble(json['gross_rate']);
    final netRate = parseDouble(json['net_rate']) ?? parseDouble(json['rate']);

    final positionsList = <StockLoanPosition>[];
    final itemsRaw = json['positions'] ??
        json['securities'] ??
        json['items'] ??
        json['line_items'];
    if (itemsRaw is List) {
      for (final item in itemsRaw) {
        if (item is Map) {
          positionsList.add(StockLoanPosition.fromJson(item));
        }
      }
    }

    return StockLoanPayment(
      id: id,
      accountNumber: accountNumber,
      paymentDate: paymentDate,
      amount: amount,
      currencyCode: currencyCode,
      status: status,
      description: description,
      grossRate: grossRate,
      netRate: netRate,
      positions: positionsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_number': accountNumber,
      if (paymentDate != null) 'payment_date': paymentDate!.toIso8601String(),
      'amount': amount,
      'currency_code': currencyCode,
      'status': status,
      if (description != null) 'description': description,
      if (grossRate != null) 'gross_rate': grossRate,
      if (netRate != null) 'net_rate': netRate,
      'positions': positions.map((p) => p.toJson()).toList(),
    };
  }

  bool get isPaid => status == 'paid' || status == 'settled';
  bool get isPending => status == 'pending';

  String get formattedAmount => _currencyFormat.format(amount);
  String get formattedPaymentDate =>
      paymentDate != null ? _shortDateFormat.format(paymentDate!) : 'Pending';
  String get formattedStatus =>
      status.isNotEmpty ? status[0].toUpperCase() + status.substring(1) : 'Unknown';

  Color get statusColor {
    switch (status) {
      case 'paid':
      case 'settled':
        return Colors.green;
      case 'pending':
        return Colors.amber;
      case 'void':
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

/// Status of the user's participation in Robinhood's Securities Lending Income Program (SLIP).
enum SlipEnrollmentStatus {
  enrolled,
  eligible,
  ineligible,
  pending,
  paused,
}

/// Represents the user's Securities Lending (SLIP) agreement eligibility, enrollment status, and aggregate yields.
class SlipEligibility {
  final bool isEnrolled;
  final bool isEligible;
  final SlipEnrollmentStatus status;
  final bool agreementSigned;
  final DateTime? agreementSignedDate;
  final List<String> ineligibilityReasons;
  final double? totalInterestEarnedYtd;
  final double? totalInterestEarnedAllTime;
  final double? estimatedAnnualizedYield;
  final int loanedSecuritiesCount;
  final double? totalLoanedValue;
  final DateTime? enabledAt;

  const SlipEligibility({
    this.isEnrolled = false,
    this.isEligible = true,
    this.status = SlipEnrollmentStatus.eligible,
    this.agreementSigned = false,
    this.agreementSignedDate,
    this.ineligibilityReasons = const [],
    this.totalInterestEarnedYtd,
    this.totalInterestEarnedAllTime,
    this.estimatedAnnualizedYield,
    this.loanedSecuritiesCount = 0,
    this.totalLoanedValue,
    this.enabledAt,
  });

  factory SlipEligibility.fromJson(dynamic json) {
    if (json is! Map) {
      return const SlipEligibility();
    }

    final enrolled = json['enrolled'] == true ||
        json['is_enrolled'] == true ||
        json['status']?.toString().toLowerCase() == 'enrolled';
    final eligible = json['eligible'] == true ||
        json['is_eligible'] == true ||
        (json['status']?.toString().toLowerCase() != 'ineligible');

    final statusStr = json['status']?.toString().toLowerCase() ?? '';
    SlipEnrollmentStatus status = SlipEnrollmentStatus.eligible;
    if (enrolled || statusStr == 'enrolled') {
      status = SlipEnrollmentStatus.enrolled;
    } else if (statusStr == 'pending') {
      status = SlipEnrollmentStatus.pending;
    } else if (statusStr == 'paused' || statusStr == 'suspended') {
      status = SlipEnrollmentStatus.paused;
    } else if (!eligible || statusStr == 'ineligible') {
      status = SlipEnrollmentStatus.ineligible;
    }

    final agreementSigned = json['agreement_signed'] == true ||
        json['has_signed_agreement'] == true ||
        enrolled;
    final signedDateStr = json['agreement_signed_date']?.toString() ??
        json['signed_at']?.toString();
    DateTime? signedDate;
    if (signedDateStr != null) {
      signedDate = DateTime.tryParse(signedDateStr);
    }

    final enabledAtStr = json['enabled_at']?.toString() ??
        json['enrolled_at']?.toString();
    DateTime? enabledAt;
    if (enabledAtStr != null) {
      enabledAt = DateTime.tryParse(enabledAtStr);
    }

    final reasons = <String>[];
    final reasonsRaw = json['ineligibility_reasons'] ??
        json['reasons'] ??
        json['disqualification_reasons'];
    if (reasonsRaw is List) {
      for (final r in reasonsRaw) {
        if (r != null) reasons.add(r.toString());
      }
    }

    final totalYtd = parseDouble(json['total_interest_earned_ytd']) ??
        parseDouble(json['ytd_earnings']) ??
        parseDouble(json['interest_ytd']);
    final totalAllTime = parseDouble(json['total_interest_earned_all_time']) ??
        parseDouble(json['all_time_earnings']) ??
        parseDouble(json['total_earnings']);
    final yieldEstimate = parseDouble(json['estimated_annualized_yield']) ??
        parseDouble(json['estimated_yield']) ??
        parseDouble(json['average_rebate_rate']);
    final securitiesCount = (json['loaned_securities_count'] as num?)?.toInt() ??
        (json['active_loans_count'] as num?)?.toInt() ??
        0;
    final loanedValue = parseDouble(json['total_loaned_value']) ??
        parseDouble(json['loaned_value']) ??
        parseDouble(json['market_value_loaned']);

    return SlipEligibility(
      isEnrolled: enrolled,
      isEligible: eligible,
      status: status,
      agreementSigned: agreementSigned,
      agreementSignedDate: signedDate,
      ineligibilityReasons: reasons,
      totalInterestEarnedYtd: totalYtd,
      totalInterestEarnedAllTime: totalAllTime,
      estimatedAnnualizedYield: yieldEstimate,
      loanedSecuritiesCount: securitiesCount,
      totalLoanedValue: loanedValue,
      enabledAt: enabledAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_enrolled': isEnrolled,
      'is_eligible': isEligible,
      'status': status.name,
      'agreement_signed': agreementSigned,
      if (agreementSignedDate != null)
        'agreement_signed_date': agreementSignedDate!.toIso8601String(),
      'ineligibility_reasons': ineligibilityReasons,
      if (totalInterestEarnedYtd != null)
        'total_interest_earned_ytd': totalInterestEarnedYtd,
      if (totalInterestEarnedAllTime != null)
        'total_interest_earned_all_time': totalInterestEarnedAllTime,
      if (estimatedAnnualizedYield != null)
        'estimated_annualized_yield': estimatedAnnualizedYield,
      'loaned_securities_count': loanedSecuritiesCount,
      if (totalLoanedValue != null) 'total_loaned_value': totalLoanedValue,
      if (enabledAt != null) 'enabled_at': enabledAt!.toIso8601String(),
    };
  }

  String get formattedStatus {
    switch (status) {
      case SlipEnrollmentStatus.enrolled:
        return 'Enrolled & Earning';
      case SlipEnrollmentStatus.eligible:
        return 'Eligible to Enroll';
      case SlipEnrollmentStatus.ineligible:
        return 'Ineligible';
      case SlipEnrollmentStatus.pending:
        return 'Enrollment Pending';
      case SlipEnrollmentStatus.paused:
        return 'Lending Paused';
    }
  }

  Color get statusColor {
    switch (status) {
      case SlipEnrollmentStatus.enrolled:
        return Colors.green;
      case SlipEnrollmentStatus.eligible:
        return Colors.blue;
      case SlipEnrollmentStatus.ineligible:
        return Colors.red;
      case SlipEnrollmentStatus.pending:
        return Colors.amber;
      case SlipEnrollmentStatus.paused:
        return Colors.orange;
    }
  }

  String get formattedTotalYtd => totalInterestEarnedYtd != null
      ? _currencyFormat.format(totalInterestEarnedYtd)
      : '\$0.00';
  String get formattedTotalAllTime => totalInterestEarnedAllTime != null
      ? _currencyFormat.format(totalInterestEarnedAllTime)
      : '\$0.00';
  String get formattedEstimatedYield => estimatedAnnualizedYield != null
      ? _percentFormat.format(estimatedAnnualizedYield)
      : '0.00%';
  String get formattedTotalLoanedValue => totalLoanedValue != null
      ? _currencyFormat.format(totalLoanedValue)
      : '\$0.00';
}

/// Represents Robinhood's High-Yield Cash Sweeps interest rate tiers, enrollment, and FDIC coverage.
class SweepsInterest {
  final String? accountNumber;
  final bool isEnrolled;
  final double goldApy; // e.g. 0.050 (5.0%)
  final double standardApy; // e.g. 0.015 (1.5%)
  final double? boostedApy; // Promotional bonus APY if any
  final double currentEffectiveApy;
  final double fdicInsuranceLimit; // e.g. 2,250,000 or 2,500,000
  final double sweepBalance; // Uninvested cash earning interest
  final List<String> partnerBanks;
  final DateTime? updatedAt;

  const SweepsInterest({
    this.accountNumber,
    this.isEnrolled = false,
    this.goldApy = 0.050,
    this.standardApy = 0.015,
    this.boostedApy,
    this.currentEffectiveApy = 0.015,
    this.fdicInsuranceLimit = 2250000.0,
    this.sweepBalance = 0.0,
    this.partnerBanks = const [
      'Citibank, N.A.',
      'Goldman Sachs Bank USA',
      'Wells Fargo Bank, N.A.',
      'JPMorgan Chase Bank, N.A.',
      'Bank of Baroda',
      'HSBC Bank USA, N.A.',
      'First National Bank of Omaha',
    ],
    this.updatedAt,
  });

  factory SweepsInterest.fromJson(dynamic json, {double uninvestedCash = 0.0}) {
    if (json is! Map) {
      return SweepsInterest(sweepBalance: uninvestedCash);
    }

    final accountNumber = json['account_number']?.toString() ??
        json['account']?.toString();
    final isEnrolled = json['is_enrolled'] == true ||
        json['enrolled'] == true ||
        json['status']?.toString().toLowerCase() == 'enrolled';

    // APY parsing
    final goldApy = parseDouble(json['gold_rate']) ??
        parseDouble(json['gold_apy']) ??
        0.050;
    final standardApy = parseDouble(json['standard_rate']) ??
        parseDouble(json['regular_rate']) ??
        parseDouble(json['standard_apy']) ??
        0.015;
    final boostedApy = parseDouble(json['boosted_rate']) ??
        parseDouble(json['superboost_rate']) ??
        parseDouble(json['promotional_rate']);
    final currentEffectiveApy = parseDouble(json['rate']) ??
        parseDouble(json['effective_rate']) ??
        parseDouble(json['current_apy']) ??
        (isEnrolled ? (goldApy > 0 ? goldApy : standardApy) : standardApy);

    final fdicLimit = parseDouble(json['fdic_insurance_limit']) ??
        parseDouble(json['fdic_coverage']) ??
        2250000.0;
    final sweepBalance = parseDouble(json['sweep_balance']) ??
        parseDouble(json['cash_balance']) ??
        uninvestedCash;

    final banks = <String>[];
    final banksRaw = json['partner_banks'] ?? json['program_banks'] ?? json['banks'];
    if (banksRaw is List) {
      for (final b in banksRaw) {
        if (b != null) banks.add(b.toString());
      }
    }

    final updatedStr = json['updated_at']?.toString() ?? json['date']?.toString();
    DateTime? updatedAt;
    if (updatedStr != null) {
      updatedAt = DateTime.tryParse(updatedStr);
    }

    return SweepsInterest(
      accountNumber: accountNumber,
      isEnrolled: isEnrolled,
      goldApy: goldApy,
      standardApy: standardApy,
      boostedApy: boostedApy,
      currentEffectiveApy: currentEffectiveApy,
      fdicInsuranceLimit: fdicLimit,
      sweepBalance: sweepBalance,
      partnerBanks: banks.isNotEmpty
          ? banks
          : const [
              'Citibank, N.A.',
              'Goldman Sachs Bank USA',
              'Wells Fargo Bank, N.A.',
              'JPMorgan Chase Bank, N.A.',
              'Bank of Baroda',
              'HSBC Bank USA, N.A.',
              'First National Bank of Omaha',
            ],
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (accountNumber != null) 'account_number': accountNumber,
      'is_enrolled': isEnrolled,
      'gold_rate': goldApy,
      'standard_rate': standardApy,
      if (boostedApy != null) 'boosted_rate': boostedApy,
      'current_effective_apy': currentEffectiveApy,
      'fdic_insurance_limit': fdicInsuranceLimit,
      'sweep_balance': sweepBalance,
      'partner_banks': partnerBanks,
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  double get estimatedAnnualInterest => sweepBalance * currentEffectiveApy;
  double get estimatedMonthlyInterest => estimatedAnnualInterest / 12.0;

  String get formattedGoldApy => _percentFormat.format(goldApy);
  String get formattedStandardApy => _percentFormat.format(standardApy);
  String get formattedEffectiveApy => _percentFormat.format(currentEffectiveApy);
  String get formattedBoostedApy =>
      boostedApy != null ? _percentFormat.format(boostedApy) : '';
  String get formattedSweepBalance => _currencyFormat.format(sweepBalance);
  String get formattedEstimatedAnnualInterest =>
      _currencyFormat.format(estimatedAnnualInterest);
  String get formattedEstimatedMonthlyInterest =>
      _currencyFormat.format(estimatedMonthlyInterest);
  String get formattedFdicInsuranceLimit =>
      _currencyFormat.format(fdicInsuranceLimit);
  String get formattedCompactFdicLimit =>
      _compactCurrencyFormat.format(fdicInsuranceLimit);
}
