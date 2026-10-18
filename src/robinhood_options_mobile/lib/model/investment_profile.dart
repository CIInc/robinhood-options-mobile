/// Investment profile for a user
/// Contains user's investment preferences, goals, and risk profile
class InvestmentProfile {
  String? investmentGoals;
  String? timeHorizon;
  String? riskTolerance;
  double? totalPortfolioValue;

  InvestmentProfile({
    this.investmentGoals,
    this.timeHorizon,
    this.riskTolerance,
    this.totalPortfolioValue,
  });

  InvestmentProfile.fromJson(Map<String, Object?> json)
      : investmentGoals = json['investmentGoals'] as String?,
        timeHorizon = json['timeHorizon'] as String?,
        riskTolerance = json['riskTolerance'] as String?,
        totalPortfolioValue = json['totalPortfolioValue'] != null
            ? (json['totalPortfolioValue'] as num).toDouble()
            : null;

  Map<String, Object?> toJson() {
    return {
      'investmentGoals': investmentGoals,
      'timeHorizon': timeHorizon,
      'riskTolerance': riskTolerance,
      'totalPortfolioValue': totalPortfolioValue,
    };
  }

  static const List<String> investmentGoalOptions = [
    'Capital Preservation',
    'Income',
    'Growth',
    'Speculation',
  ];

  static const List<String> timeHorizonOptions = [
    'Short Term (< 3 yrs)',
    'Medium Term (3-7 yrs)',
    'Long Term (> 7 yrs)',
  ];

  static const List<String> riskToleranceOptions = [
    'Conservative',
    'Moderate',
    'Growth',
    'Aggressive',
    'Speculative',
  ];
}
