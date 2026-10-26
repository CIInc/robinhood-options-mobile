import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/utils/json.dart';

/// Tax efficiency tier of an individual asset.
enum TaxEfficiencyTier {
  /// Tax-efficient assets: Broad index ETFs, low dividend growth stocks, municipal bonds.
  /// Generates minimal ordinary income; ideal in Taxable accounts.
  high,

  /// Moderately efficient: Mixed dividend payers, large-cap value, balanced funds.
  moderate,

  /// Tax-inefficient assets: REITs, high-yield bond funds, high-turnover options, high dividends.
  /// Generates significant ordinary income; best kept inside tax-deferred or tax-free retirement accounts.
  low;

  String get label {
    switch (this) {
      case TaxEfficiencyTier.high:
        return 'Tax-Efficient';
      case TaxEfficiencyTier.moderate:
        return 'Moderate';
      case TaxEfficiencyTier.low:
        return 'Tax-Inefficient';
    }
  }
}

/// Tax classification for brokerage and retirement accounts.
enum AccountTaxClassification {
  taxable,
  traditionalIra,
  rothIra;

  static AccountTaxClassification fromAccount(Account? account) {
    if (account == null) return AccountTaxClassification.taxable;
    if (account.isRothIra) return AccountTaxClassification.rothIra;
    if (account.isTraditionalIra || account.isRetirement) {
      return AccountTaxClassification.traditionalIra;
    }
    return AccountTaxClassification.taxable;
  }

  String get label {
    switch (this) {
      case AccountTaxClassification.taxable:
        return 'Taxable Brokerage';
      case AccountTaxClassification.traditionalIra:
        return 'Traditional IRA (Tax-Deferred)';
      case AccountTaxClassification.rothIra:
        return 'Roth IRA (Tax-Free)';
    }
  }

  String get shortLabel {
    switch (this) {
      case AccountTaxClassification.taxable:
        return 'Taxable';
      case AccountTaxClassification.traditionalIra:
        return 'Trad IRA';
      case AccountTaxClassification.rothIra:
        return 'Roth IRA';
    }
  }
}

/// Evaluated holding showing current placement vs. optimal tax location.
class AssetLocationHolding {
  final String symbol;
  final String name;
  final String assetType; // 'stock' or 'option'
  final double marketValue;
  final String accountNumber;
  final String accountType;
  final AccountTaxClassification accountClassification;
  final double dividendYield; // percentage, e.g. 3.5 for 3.5%
  final TaxEfficiencyTier taxEfficiencyTier;
  final AccountTaxClassification idealAccountClassification;
  final bool isMisplaced;
  final String misplacementRationale;

  const AssetLocationHolding({
    required this.symbol,
    required this.name,
    required this.assetType,
    required this.marketValue,
    required this.accountNumber,
    required this.accountType,
    required this.accountClassification,
    this.dividendYield = 0.0,
    required this.taxEfficiencyTier,
    required this.idealAccountClassification,
    required this.isMisplaced,
    required this.misplacementRationale,
  });

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'name': name,
        'asset_type': assetType,
        'market_value': marketValue,
        'account_number': accountNumber,
        'account_type': accountType,
        'account_classification': accountClassification.name,
        'dividend_yield': dividendYield,
        'tax_efficiency_tier': taxEfficiencyTier.name,
        'ideal_account_classification': idealAccountClassification.name,
        'is_misplaced': isMisplaced,
        'misplacement_rationale': misplacementRationale,
      };

  factory AssetLocationHolding.fromJson(dynamic json) {
    return AssetLocationHolding(
      symbol: (json['symbol'] ?? '').toString().toUpperCase(),
      name: json['name']?.toString() ?? '',
      assetType: json['asset_type']?.toString() ?? 'stock',
      marketValue: parseDouble(json['market_value']) ?? 0.0,
      accountNumber: json['account_number']?.toString() ?? '',
      accountType: json['account_type']?.toString() ?? 'Individual',
      accountClassification: AccountTaxClassification.values.firstWhere(
        (e) => e.name == json['account_classification'],
        orElse: () => AccountTaxClassification.taxable,
      ),
      dividendYield: parseDouble(json['dividend_yield']) ?? 0.0,
      taxEfficiencyTier: TaxEfficiencyTier.values.firstWhere(
        (e) => e.name == json['tax_efficiency_tier'],
        orElse: () => TaxEfficiencyTier.moderate,
      ),
      idealAccountClassification: AccountTaxClassification.values.firstWhere(
        (e) => e.name == json['ideal_account_classification'],
        orElse: () => AccountTaxClassification.taxable,
      ),
      isMisplaced: json['is_misplaced'] == true,
      misplacementRationale: json['misplacement_rationale']?.toString() ?? '',
    );
  }
}

/// An actionable asset location reallocation recommendation.
class AssetLocationRecommendation {
  final String symbol;
  final String action; // 'Relocate', 'Keep', 'Prioritize'
  final AccountTaxClassification fromAccount;
  final AccountTaxClassification toAccount;
  final String priority; // 'high', 'medium', 'low'
  final String rationale;
  final double
      estimatedTaxImpact; // Estimated annual tax drag reduction in dollars

  const AssetLocationRecommendation({
    required this.symbol,
    required this.action,
    required this.fromAccount,
    required this.toAccount,
    required this.priority,
    required this.rationale,
    this.estimatedTaxImpact = 0.0,
  });

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'action': action,
        'from_account': fromAccount.name,
        'to_account': toAccount.name,
        'priority': priority,
        'rationale': rationale,
        'estimated_tax_impact': estimatedTaxImpact,
      };

  factory AssetLocationRecommendation.fromJson(dynamic json) {
    return AssetLocationRecommendation(
      symbol: (json['symbol'] ?? '').toString().toUpperCase(),
      action: json['action']?.toString() ?? 'Relocate',
      fromAccount: AccountTaxClassification.values.firstWhere(
        (e) => e.name == json['from_account'],
        orElse: () => AccountTaxClassification.taxable,
      ),
      toAccount: AccountTaxClassification.values.firstWhere(
        (e) => e.name == json['to_account'],
        orElse: () => AccountTaxClassification.traditionalIra,
      ),
      priority: json['priority']?.toString() ?? 'medium',
      rationale: json['rationale']?.toString() ?? '',
      estimatedTaxImpact: parseDouble(json['estimated_tax_impact']) ?? 0.0,
    );
  }
}

/// Comprehensive multi-account asset location optimization analysis.
class AssetLocationAnalysis {
  final double efficiencyScore; // 0.0 to 100.0
  final String
      ratingLabel; // 'Optimal', 'Good', 'Suboptimal', 'Needs Rebalancing'
  final double totalTaxableValue;
  final double totalTraditionalIraValue;
  final double totalRothIraValue;
  final List<AssetLocationHolding> holdings;
  final List<AssetLocationRecommendation> recommendations;
  final int misplacedHoldingsCount;

  const AssetLocationAnalysis({
    required this.efficiencyScore,
    required this.ratingLabel,
    required this.totalTaxableValue,
    required this.totalTraditionalIraValue,
    required this.totalRothIraValue,
    required this.holdings,
    required this.recommendations,
    required this.misplacedHoldingsCount,
  });

  double get totalPortfolioValue =>
      totalTaxableValue + totalTraditionalIraValue + totalRothIraValue;

  double get misplacedValue => holdings
      .where((h) => h.isMisplaced)
      .fold(0.0, (sum, h) => sum + h.marketValue);

  double get misplacedPercentage => totalPortfolioValue > 0
      ? (misplacedValue / totalPortfolioValue) * 100
      : 0.0;

  double get potentialAnnualTaxSavings =>
      recommendations.fold(0.0, (sum, r) => sum + r.estimatedTaxImpact);

  Map<String, dynamic> toJson() => {
        'efficiency_score': efficiencyScore,
        'rating_label': ratingLabel,
        'total_taxable_value': totalTaxableValue,
        'total_traditional_ira_value': totalTraditionalIraValue,
        'total_roth_ira_value': totalRothIraValue,
        'holdings': holdings.map((h) => h.toJson()).toList(),
        'recommendations': recommendations.map((r) => r.toJson()).toList(),
        'misplaced_holdings_count': misplacedHoldingsCount,
      };
}
