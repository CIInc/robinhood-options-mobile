import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/utils/json.dart';

final _currencyFormat = NumberFormat.simpleCurrency();

/// Cash component of collateral locked for an options chain.
class OptionCollateralCash {
  final double amount;
  final String direction; // 'debit' or 'credit'
  final bool infinite;

  const OptionCollateralCash({
    required this.amount,
    this.direction = 'debit',
    this.infinite = false,
  });

  factory OptionCollateralCash.fromJson(dynamic json) {
    if (json is! Map) {
      return const OptionCollateralCash(amount: 0.0);
    }
    final rawAmount = parseDouble(json['amount']) ?? 0.0;
    final amount = rawAmount.abs() < 1e-6 ? 0.0 : rawAmount;
    return OptionCollateralCash(
      amount: amount,
      direction: json['direction']?.toString() ?? 'debit',
      infinite: json['infinite'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'amount': amount.toStringAsFixed(4),
        'direction': direction,
        'infinite': infinite,
      };

  String get formattedAmount =>
      infinite ? 'Unlimited' : _currencyFormat.format(amount);
  bool get hasCollateral => amount > 0.0001 || infinite;
}

/// Equity shares locked as collateral for an options chain (e.g. covered calls).
class OptionCollateralEquity {
  final String symbol;
  final double quantity;
  final double uncoveredShares;
  final String direction; // 'debit' or 'credit'
  final String? instrumentUrl;

  const OptionCollateralEquity({
    required this.symbol,
    required this.quantity,
    this.uncoveredShares = 0.0,
    this.direction = 'debit',
    this.instrumentUrl,
  });

  factory OptionCollateralEquity.fromJson(dynamic json) {
    if (json is! Map) {
      return const OptionCollateralEquity(symbol: '', quantity: 0.0);
    }
    final rawQty = parseDouble(json['quantity']) ?? 0.0;
    final qty = rawQty.abs() < 1e-6 ? 0.0 : rawQty;
    final rawUncovered = parseDouble(json['uncovered_shares']) ?? 0.0;
    final uncovered = rawUncovered.abs() < 1e-6 ? 0.0 : rawUncovered;
    return OptionCollateralEquity(
      symbol: json['symbol']?.toString() ?? '',
      quantity: qty,
      uncoveredShares: uncovered,
      direction: json['direction']?.toString() ?? 'debit',
      instrumentUrl: json['instrument']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'quantity': quantity.toString(),
        'uncovered_shares': uncoveredShares.toString(),
        'direction': direction,
        if (instrumentUrl != null) 'instrument': instrumentUrl,
      };

  String get formattedQuantity => quantity % 1 == 0
      ? quantity.toInt().toString()
      : quantity.toStringAsFixed(2);
  String get formattedUncoveredShares => uncoveredShares % 1 == 0
      ? uncoveredShares.toInt().toString()
      : uncoveredShares.toStringAsFixed(2);
  bool get hasCollateral => quantity > 0.0001 || uncoveredShares > 0.0001;
}

/// Collateral breakdown for a specific state (active positions or pending orders).
class OptionCollateralBreakdown {
  final OptionCollateralCash cash;
  final List<OptionCollateralEquity> equities;

  const OptionCollateralBreakdown({
    required this.cash,
    required this.equities,
  });

  factory OptionCollateralBreakdown.fromJson(dynamic json) {
    if (json is! Map) {
      return const OptionCollateralBreakdown(
        cash: OptionCollateralCash(amount: 0.0),
        equities: [],
      );
    }

    final cash = OptionCollateralCash.fromJson(json['cash']);
    final equitiesList = <OptionCollateralEquity>[];
    if (json['equities'] is List) {
      for (final item in json['equities']) {
        equitiesList.add(OptionCollateralEquity.fromJson(item));
      }
    }

    return OptionCollateralBreakdown(
      cash: cash,
      equities: equitiesList,
    );
  }

  Map<String, dynamic> toJson() => {
        'cash': cash.toJson(),
        'equities': equities.map((e) => e.toJson()).toList(),
      };

  double get totalShares {
    double sum = 0.0;
    for (final eq in equities) {
      sum += eq.quantity;
    }
    return sum;
  }

  /// Equities that have actual non-zero shares locked or uncovered
  List<OptionCollateralEquity> get activeEquities =>
      equities.where((e) => e.hasCollateral).toList();

  bool get hasCollateral => cash.hasCollateral || activeEquities.isNotEmpty;
}

/// Complete options collateral structure for an options chain and account.
class OptionChainCollateral {
  final String chainId;
  final String accountNumber;
  final OptionCollateralBreakdown collateral;
  final OptionCollateralBreakdown collateralHeldForOrders;
  final DateTime updatedAt;

  const OptionChainCollateral({
    required this.chainId,
    required this.accountNumber,
    required this.collateral,
    required this.collateralHeldForOrders,
    required this.updatedAt,
  });

  factory OptionChainCollateral.fromJson(
    String chainId,
    String accountNumber,
    dynamic json,
  ) {
    if (json is! Map) {
      return OptionChainCollateral(
        chainId: chainId,
        accountNumber: accountNumber,
        collateral: const OptionCollateralBreakdown(
          cash: OptionCollateralCash(amount: 0.0),
          equities: [],
        ),
        collateralHeldForOrders: const OptionCollateralBreakdown(
          cash: OptionCollateralCash(amount: 0.0),
          equities: [],
        ),
        updatedAt: DateTime.now(),
      );
    }

    final resolvedAccountNumber = (json['account_number'] != null &&
            json['account_number'].toString().trim().isNotEmpty)
        ? json['account_number'].toString().trim()
        : accountNumber;

    return OptionChainCollateral(
      chainId: chainId,
      accountNumber: resolvedAccountNumber,
      collateral: OptionCollateralBreakdown.fromJson(json['collateral']),
      collateralHeldForOrders: OptionCollateralBreakdown.fromJson(
          json['collateral_held_for_orders']),
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'chain_id': chainId,
        'account_number': accountNumber,
        'collateral': collateral.toJson(),
        'collateral_held_for_orders': collateralHeldForOrders.toJson(),
        'updated_at': updatedAt.toIso8601String(),
      };

  double get totalCashLocked =>
      collateral.cash.amount + collateralHeldForOrders.cash.amount;

  double get totalSharesLocked =>
      collateral.totalShares + collateralHeldForOrders.totalShares;

  bool get hasAnyCollateral =>
      collateral.hasCollateral || collateralHeldForOrders.hasCollateral;

  String get formattedTotalCash => _currencyFormat.format(totalCashLocked);
  String get formattedTotalShares => totalSharesLocked % 1 == 0
      ? totalSharesLocked.toInt().toString()
      : totalSharesLocked.toStringAsFixed(2);
}

/// Options tier upgrade status and eligibility.
class OptionUpgradeStatus {
  final bool shouldShowUpgrade;
  final String
      optionLevel; // 'option_level_1', 'option_level_2', 'option_level_3'
  final int currentTier;
  final int targetTier;
  final String title;
  final String subtitle;
  final String? upgradeUrl;
  final bool isEligible;
  final List<String> requirements;
  final List<String> tierFeatures;

  const OptionUpgradeStatus({
    required this.shouldShowUpgrade,
    required this.optionLevel,
    required this.currentTier,
    required this.targetTier,
    required this.title,
    required this.subtitle,
    this.upgradeUrl,
    required this.isEligible,
    required this.requirements,
    required this.tierFeatures,
  });

  factory OptionUpgradeStatus.fromJson(dynamic json,
      {String? defaultAccountLevel}) {
    if (json is! Map) {
      final level = defaultAccountLevel ?? 'option_level_2';
      final tier = _parseTier(level);
      return OptionUpgradeStatus(
        shouldShowUpgrade: tier < 3,
        optionLevel: level,
        currentTier: tier,
        targetTier: tier < 3 ? 3 : 3,
        title:
            tier < 3 ? 'Upgrade to Options Level 3' : 'Level 3 Options Active',
        subtitle: tier < 3
            ? 'Access multi-leg spreads, straddles, and iron condors.'
            : 'Multi-leg spread and complex options trading enabled.',
        upgradeUrl: null,
        isEligible: true,
        requirements: _defaultRequirements(tier),
        tierFeatures: _defaultFeatures(tier < 3 ? 3 : tier),
      );
    }

    final rawLevel = json['option_level']?.toString() ??
        json['current_level']?.toString() ??
        defaultAccountLevel ??
        'option_level_2';
    final currentTier = _parseTier(rawLevel);
    final targetTier = (json['target_tier'] as num?)?.toInt() ??
        (currentTier < 3 ? 3 : currentTier);

    final shouldShow = json['should_show_options_upgrade'] == true ||
        json['should_show_upgrade'] == true ||
        (currentTier < 3 && json['should_show_options_upgrade'] != false);

    final title = json['upgrade_title']?.toString() ??
        json['title']?.toString() ??
        (currentTier < 3
            ? 'Upgrade to Options Level $targetTier'
            : 'Options Level $currentTier Active');

    final subtitle = json['upgrade_subtitle']?.toString() ??
        json['subtitle']?.toString() ??
        (currentTier < 3
            ? 'Unlock multi-leg strategies including Spreads and Iron Condors.'
            : 'All advanced options strategies are enabled on this account.');

    final upgradeUrl = json['upgrade_url']?.toString() ??
        json['action_url']?.toString() ??
        json['url']?.toString();

    final isEligible = json['is_eligible'] != false;

    final reqList = <String>[];
    if (json['requirements'] is List) {
      for (final r in json['requirements']) {
        reqList.add(r.toString());
      }
    } else {
      reqList.addAll(_defaultRequirements(currentTier));
    }

    final featList = <String>[];
    if (json['features'] is List) {
      for (final f in json['features']) {
        featList.add(f.toString());
      }
    } else {
      featList.addAll(_defaultFeatures(targetTier));
    }

    return OptionUpgradeStatus(
      shouldShowUpgrade: shouldShow,
      optionLevel: rawLevel,
      currentTier: currentTier,
      targetTier: targetTier,
      title: title,
      subtitle: subtitle,
      upgradeUrl: upgradeUrl,
      isEligible: isEligible,
      requirements: reqList,
      tierFeatures: featList,
    );
  }

  Map<String, dynamic> toJson() => {
        'should_show_options_upgrade': shouldShowUpgrade,
        'option_level': optionLevel,
        'current_tier': currentTier,
        'target_tier': targetTier,
        'upgrade_title': title,
        'upgrade_subtitle': subtitle,
        if (upgradeUrl != null) 'upgrade_url': upgradeUrl,
        'is_eligible': isEligible,
        'requirements': requirements,
        'features': tierFeatures,
      };

  static int _parseTier(String level) {
    final lower = level.toLowerCase();
    if (lower.contains('3')) return 3;
    if (lower.contains('2')) return 2;
    if (lower.contains('1')) return 1;
    return 2; // Default to Level 2
  }

  static List<String> _defaultRequirements(int currentTier) {
    if (currentTier < 3) {
      return [
        'Margin or limited-margin account enabled',
        'Options trading agreement acknowledged',
        'Options risk profile suitable for multi-leg strategies',
      ];
    }
    return [
      'Account approved for all supported options strategies',
    ];
  }

  static List<String> _defaultFeatures(int tier) {
    if (tier >= 3) {
      return [
        'Multi-leg debit & credit spreads',
        'Iron condors & iron butterflies',
        'Calendar & diagonal spreads',
        'Straddles & strangles',
      ];
    }
    return [
      'Long calls & long puts',
      'Covered calls against held stock',
      'Cash-secured puts with full cash collateral',
    ];
  }

  String get tierBadgeLabel => 'Level $currentTier';
}
