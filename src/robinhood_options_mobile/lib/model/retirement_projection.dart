import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/utils/json.dart';

final _currencyFormat = NumberFormat.simpleCurrency();

/// Parameters for calculating IRA compounding, tax advantages, and match benefits.
class RetirementProjectionParams {
  /// Initial capital in the retirement account.
  final double startingBalance;

  /// Annual amount contributed to the IRA.
  final double annualContribution;

  /// Investment time horizon in years until retirement.
  final int yearsToRetirement;

  /// Expected annualized portfolio growth rate (e.g. 0.08 for 8%).
  final double expectedAnnualReturn;

  /// Robinhood IRA contribution match rate (e.g. 0.03 for 3% Gold match, 0.01 for 1% Standard match).
  final double matchRate;

  /// Estimated current marginal income tax rate (for Traditional IRA deduction comparison).
  final double estimatedMarginalTaxRate;

  /// Estimated retirement tax rate during distribution years.
  final double estimatedRetirementTaxRate;

  /// Estimated annual dividend and capital gains tax drag in a non-tax-advantaged taxable account.
  final double taxableAccountTaxDrag;

  /// Annual cost of Robinhood Gold subscription (defaults to \$50/year).
  final double annualGoldFee;

  const RetirementProjectionParams({
    this.startingBalance = 10000.0,
    this.annualContribution = 7000.0,
    this.yearsToRetirement = 25,
    this.expectedAnnualReturn = 0.08,
    this.matchRate = 0.03,
    this.estimatedMarginalTaxRate = 0.24,
    this.estimatedRetirementTaxRate = 0.15,
    this.taxableAccountTaxDrag = 0.015,
    this.annualGoldFee = 50.0,
  });

  RetirementProjectionParams copyWith({
    double? startingBalance,
    double? annualContribution,
    int? yearsToRetirement,
    double? expectedAnnualReturn,
    double? matchRate,
    double? estimatedMarginalTaxRate,
    double? estimatedRetirementTaxRate,
    double? taxableAccountTaxDrag,
    double? annualGoldFee,
  }) {
    return RetirementProjectionParams(
      startingBalance: startingBalance ?? this.startingBalance,
      annualContribution: annualContribution ?? this.annualContribution,
      yearsToRetirement: yearsToRetirement ?? this.yearsToRetirement,
      expectedAnnualReturn: expectedAnnualReturn ?? this.expectedAnnualReturn,
      matchRate: matchRate ?? this.matchRate,
      estimatedMarginalTaxRate:
          estimatedMarginalTaxRate ?? this.estimatedMarginalTaxRate,
      estimatedRetirementTaxRate:
          estimatedRetirementTaxRate ?? this.estimatedRetirementTaxRate,
      taxableAccountTaxDrag:
          taxableAccountTaxDrag ?? this.taxableAccountTaxDrag,
      annualGoldFee: annualGoldFee ?? this.annualGoldFee,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'starting_balance': startingBalance,
      'annual_contribution': annualContribution,
      'years_to_retirement': yearsToRetirement,
      'expected_annual_return': expectedAnnualReturn,
      'match_rate': matchRate,
      'estimated_marginal_tax_rate': estimatedMarginalTaxRate,
      'estimated_retirement_tax_rate': estimatedRetirementTaxRate,
      'taxable_account_tax_drag': taxableAccountTaxDrag,
      'annual_gold_fee': annualGoldFee,
    };
  }

  factory RetirementProjectionParams.fromJson(dynamic json) {
    if (json is! Map) return const RetirementProjectionParams();
    return RetirementProjectionParams(
      startingBalance: parseDouble(json['starting_balance']) ?? 10000.0,
      annualContribution: parseDouble(json['annual_contribution']) ?? 7000.0,
      yearsToRetirement:
          int.tryParse(json['years_to_retirement']?.toString() ?? '25') ?? 25,
      expectedAnnualReturn: parseDouble(json['expected_annual_return']) ?? 0.08,
      matchRate: parseDouble(json['match_rate']) ?? 0.03,
      estimatedMarginalTaxRate:
          parseDouble(json['estimated_marginal_tax_rate']) ?? 0.24,
      estimatedRetirementTaxRate:
          parseDouble(json['estimated_retirement_tax_rate']) ?? 0.15,
      taxableAccountTaxDrag:
          parseDouble(json['taxable_account_tax_drag']) ?? 0.015,
      annualGoldFee: parseDouble(json['annual_gold_fee']) ?? 50.0,
    );
  }
}

/// Snapshot of projected balance, cumulative contributions, matches, and tax status for a single year.
class YearlyProjectionData {
  /// The 1-based forecast year (1..yearsToRetirement).
  final int year;

  /// Cumulative principal contributed by the user through this year.
  final double cumulativeContributions;

  /// Cumulative match deposited by Robinhood through this year.
  final double cumulativeMatch;

  /// Ending account balance including user contributions, Robinhood match, and market growth.
  final double balanceWithMatch;

  /// Ending account balance assuming no brokerage match (0%).
  final double balanceWithoutMatch;

  /// Ending balance assuming the standard 1% match.
  final double balanceWithStandardMatch;

  /// Ending balance of an identical taxable brokerage account subject to annual tax drag.
  final double taxableAccountBalance;

  /// Additional wealth created strictly by the Robinhood match and its compounded return.
  double get matchWealthGenerated =>
      (balanceWithMatch - balanceWithoutMatch).clamp(0.0, double.infinity);

  /// Advantage of tax-sheltered compounding over a taxable account.
  double get taxAdvantageVsTaxable =>
      (balanceWithMatch - taxableAccountBalance).clamp(0.0, double.infinity);

  const YearlyProjectionData({
    required this.year,
    required this.cumulativeContributions,
    required this.cumulativeMatch,
    required this.balanceWithMatch,
    required this.balanceWithoutMatch,
    required this.balanceWithStandardMatch,
    required this.taxableAccountBalance,
  });

  Map<String, dynamic> toJson() {
    return {
      'year': year,
      'cumulative_contributions': cumulativeContributions,
      'cumulative_match': cumulativeMatch,
      'balance_with_match': balanceWithMatch,
      'balance_without_match': balanceWithoutMatch,
      'balance_with_standard_match': balanceWithStandardMatch,
      'taxable_account_balance': taxableAccountBalance,
    };
  }

  factory YearlyProjectionData.fromJson(dynamic json) {
    if (json is! Map) {
      return const YearlyProjectionData(
        year: 1,
        cumulativeContributions: 0,
        cumulativeMatch: 0,
        balanceWithMatch: 0,
        balanceWithoutMatch: 0,
        balanceWithStandardMatch: 0,
        taxableAccountBalance: 0,
      );
    }
    return YearlyProjectionData(
      year: int.tryParse(json['year']?.toString() ?? '1') ?? 1,
      cumulativeContributions:
          parseDouble(json['cumulative_contributions']) ?? 0.0,
      cumulativeMatch: parseDouble(json['cumulative_match']) ?? 0.0,
      balanceWithMatch: parseDouble(json['balance_with_match']) ?? 0.0,
      balanceWithoutMatch: parseDouble(json['balance_without_match']) ?? 0.0,
      balanceWithStandardMatch:
          parseDouble(json['balance_with_standard_match']) ?? 0.0,
      taxableAccountBalance:
          parseDouble(json['taxable_account_balance']) ?? 0.0,
    );
  }
}

/// Comprehensive outcome of the multi-year retirement projection and Gold match maximizer.
class RetirementProjectionResult {
  final RetirementProjectionParams params;
  final List<YearlyProjectionData> yearlyBreakdown;

  /// Final total balance at the retirement horizon.
  final double finalBalance;

  /// Final balance without any match bonus.
  final double finalBalanceWithoutMatch;

  /// Final balance with standard 1% match.
  final double finalBalanceWithStandardMatch;

  /// Final balance of a regular taxable brokerage account.
  final double finalTaxableBalance;

  /// Total capital deposited directly by the user over the entire horizon.
  final double totalUserContributions;

  /// Total cash bonuses deposited via the Robinhood match over the horizon.
  final double totalMatchBonusesEarned;

  /// Total earnings produced strictly by compound market growth on all deposits.
  final double totalInvestmentGrowth;

  /// Extra wealth in the portfolio at retirement resulting from the match compounding.
  final double compoundedMatchAddedWealth;

  /// Year 1 net cash bonus from Robinhood Gold after subtracting the annual Gold fee.
  final double yearOneNetGoldBonus;

  /// Minimum annual contribution needed to completely offset the annual Gold subscription fee.
  final double goldBreakEvenAnnualContribution;

  /// Total tax drag avoided by investing in the tax-advantaged retirement account vs taxable.
  final double lifetimeTaxAdvantage;

  const RetirementProjectionResult({
    required this.params,
    required this.yearlyBreakdown,
    required this.finalBalance,
    required this.finalBalanceWithoutMatch,
    required this.finalBalanceWithStandardMatch,
    required this.finalTaxableBalance,
    required this.totalUserContributions,
    required this.totalMatchBonusesEarned,
    required this.totalInvestmentGrowth,
    required this.compoundedMatchAddedWealth,
    required this.yearOneNetGoldBonus,
    required this.goldBreakEvenAnnualContribution,
    required this.lifetimeTaxAdvantage,
  });

  String get formattedFinalBalance => _currencyFormat.format(finalBalance);
  String get formattedFinalBalanceWithoutMatch =>
      _currencyFormat.format(finalBalanceWithoutMatch);
  String get formattedUserContributions =>
      _currencyFormat.format(totalUserContributions);
  String get formattedTotalMatch =>
      _currencyFormat.format(totalMatchBonusesEarned);
  String get formattedInvestmentGrowth =>
      _currencyFormat.format(totalInvestmentGrowth);
  String get formattedCompoundedMatchAddedWealth =>
      _currencyFormat.format(compoundedMatchAddedWealth);
  String get formattedYearOneNetGoldBonus =>
      _currencyFormat.format(yearOneNetGoldBonus);
  String get formattedGoldBreakEven =>
      _currencyFormat.format(goldBreakEvenAnnualContribution);
  String get formattedLifetimeTaxAdvantage =>
      _currencyFormat.format(lifetimeTaxAdvantage);

  /// Proportion of the final balance made up of user contributions (0.0 to 1.0).
  double get userContributionShare => finalBalance > 0
      ? (totalUserContributions / finalBalance).clamp(0.0, 1.0)
      : 0.0;

  /// Proportion of the final balance made up of pure market investment growth (0.0 to 1.0).
  double get investmentGrowthShare => finalBalance > 0
      ? (totalInvestmentGrowth / finalBalance).clamp(0.0, 1.0)
      : 0.0;

  /// Proportion of final balance resulting directly from compounded match bonuses (0.0 to 1.0).
  double get matchShare => finalBalance > 0
      ? (compoundedMatchAddedWealth / finalBalance).clamp(0.0, 1.0)
      : 0.0;

  Map<String, dynamic> toJson() {
    return {
      'params': params.toJson(),
      'yearly_breakdown': yearlyBreakdown.map((y) => y.toJson()).toList(),
      'final_balance': finalBalance,
      'final_balance_without_match': finalBalanceWithoutMatch,
      'final_balance_with_standard_match': finalBalanceWithStandardMatch,
      'final_taxable_balance': finalTaxableBalance,
      'total_user_contributions': totalUserContributions,
      'total_match_bonuses_earned': totalMatchBonusesEarned,
      'total_investment_growth': totalInvestmentGrowth,
      'compounded_match_added_wealth': compoundedMatchAddedWealth,
      'year_one_net_gold_bonus': yearOneNetGoldBonus,
      'gold_break_even_annual_contribution': goldBreakEvenAnnualContribution,
      'lifetime_tax_advantage': lifetimeTaxAdvantage,
    };
  }
}

/// Calculation engine for projecting retirement compounding, tax advantages, and Robinhood Gold match optimization.
class RetirementProjectionCalculator {
  /// Computes a multi-year compounding simulation using beginning-of-year contributions.
  static RetirementProjectionResult calculate(
      RetirementProjectionParams params) {
    final horizon = params.yearsToRetirement.clamp(1, 60);
    final annualReturn = params.expectedAnnualReturn.clamp(-0.20, 0.40);
    final matchRate = params.matchRate.clamp(0.0, 0.10);
    final startingBalance = params.startingBalance.clamp(0.0, 100000000.0);
    final annualContrib = params.annualContribution.clamp(0.0, 10000000.0);

    // Taxable account effective return reflects annual tax drag (dividends & turnover tax)
    final taxableReturn =
        (annualReturn - params.taxableAccountTaxDrag).clamp(0.0, 0.40);

    double currentBalanceWithMatch = startingBalance;
    double currentBalanceWithoutMatch = startingBalance;
    double currentBalanceWithStandard = startingBalance;
    double currentTaxableBalance = startingBalance;

    double cumulativeUserContributions = startingBalance;
    double cumulativeMatch = 0.0;

    final List<YearlyProjectionData> breakdown = [];

    final annualMatchAmount = annualContrib * matchRate;
    final standardMatchAmount = annualContrib * 0.01;

    for (int yr = 1; yr <= horizon; yr++) {
      cumulativeUserContributions += annualContrib;
      cumulativeMatch += annualMatchAmount;

      // Beginning-of-year compounding: contributions and match compound for the full year
      currentBalanceWithMatch =
          (currentBalanceWithMatch + annualContrib + annualMatchAmount) *
              (1.0 + annualReturn);

      currentBalanceWithoutMatch =
          (currentBalanceWithoutMatch + annualContrib) * (1.0 + annualReturn);

      currentBalanceWithStandard =
          (currentBalanceWithStandard + annualContrib + standardMatchAmount) *
              (1.0 + annualReturn);

      currentTaxableBalance =
          (currentTaxableBalance + annualContrib) * (1.0 + taxableReturn);

      breakdown.add(YearlyProjectionData(
        year: yr,
        cumulativeContributions: cumulativeUserContributions,
        cumulativeMatch: cumulativeMatch,
        balanceWithMatch: currentBalanceWithMatch,
        balanceWithoutMatch: currentBalanceWithoutMatch,
        balanceWithStandardMatch: currentBalanceWithStandard,
        taxableAccountBalance: currentTaxableBalance,
      ));
    }

    final totalDeposits = cumulativeUserContributions + cumulativeMatch;
    final totalInvestmentGrowth =
        (currentBalanceWithMatch - totalDeposits).clamp(0.0, double.infinity);
    final matchWealth = (currentBalanceWithMatch - currentBalanceWithoutMatch)
        .clamp(0.0, double.infinity);

    // Gold annual fee break-even: annualContribution * 0.03 = annualGoldFee
    final goldBreakEven = params.annualGoldFee > 0 && matchRate > 0
        ? params.annualGoldFee / (matchRate > 0 ? matchRate : 0.03)
        : 0.0;

    // Year 1 match minus fee
    final year1Match = annualContrib * matchRate;
    final year1Net = year1Match - params.annualGoldFee;

    final taxAdvantage = (currentBalanceWithMatch - currentTaxableBalance)
        .clamp(0.0, double.infinity);

    return RetirementProjectionResult(
      params: params,
      yearlyBreakdown: breakdown,
      finalBalance: currentBalanceWithMatch,
      finalBalanceWithoutMatch: currentBalanceWithoutMatch,
      finalBalanceWithStandardMatch: currentBalanceWithStandard,
      finalTaxableBalance: currentTaxableBalance,
      totalUserContributions: cumulativeUserContributions,
      totalMatchBonusesEarned: cumulativeMatch,
      totalInvestmentGrowth: totalInvestmentGrowth,
      compoundedMatchAddedWealth: matchWealth,
      yearOneNetGoldBonus: year1Net,
      goldBreakEvenAnnualContribution: goldBreakEven,
      lifetimeTaxAdvantage: taxAdvantage,
    );
  }
}
