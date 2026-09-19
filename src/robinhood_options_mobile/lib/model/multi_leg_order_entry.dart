import 'package:robinhood_options_mobile/model/option_strategy.dart';

/// Represents a single option leg in a multi-leg options strategy order.
class MultiLegOrderLeg {
  final String id;
  LegAction action; // buy, sell
  LegType type; // call, put
  double strike;
  DateTime expirationDate;
  int ratio;
  double premium; // mark price per share

  MultiLegOrderLeg({
    required this.id,
    required this.action,
    required this.type,
    required this.strike,
    required this.expirationDate,
    this.ratio = 1,
    this.premium = 0.0,
  });

  MultiLegOrderLeg copyWith({
    String? id,
    LegAction? action,
    LegType? type,
    double? strike,
    DateTime? expirationDate,
    int? ratio,
    double? premium,
  }) {
    return MultiLegOrderLeg(
      id: id ?? this.id,
      action: action ?? this.action,
      type: type ?? this.type,
      strike: strike ?? this.strike,
      expirationDate: expirationDate ?? this.expirationDate,
      ratio: ratio ?? this.ratio,
      premium: premium ?? this.premium,
    );
  }

  bool get isBuy => action == LegAction.buy;
  bool get isSell => action == LegAction.sell;
  bool get isCall => type == LegType.call;
  bool get isPut => type == LegType.put;

  /// Effective premium contribution: negative if bought (cash outflow), positive if sold (cash inflow).
  double get signedPremium {
    final sign = isSell ? 1.0 : -1.0;
    return sign * premium * ratio;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'action': action.name,
        'type': type.name,
        'strike': strike,
        'expirationDate': expirationDate.toIso8601String(),
        'ratio': ratio,
        'premium': premium,
      };

  factory MultiLegOrderLeg.fromJson(Map<String, dynamic> json) {
    return MultiLegOrderLeg(
      id: json['id'] as String? ?? 'leg_${DateTime.now().millisecondsSinceEpoch}',
      action: LegAction.values.firstWhere(
        (e) => e.name == json['action'],
        orElse: () => LegAction.buy,
      ),
      type: LegType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => LegType.call,
      ),
      strike: (json['strike'] as num?)?.toDouble() ?? 0.0,
      expirationDate: json['expirationDate'] != null
          ? DateTime.parse(json['expirationDate'] as String)
          : DateTime.now().add(const Duration(days: 30)),
      ratio: json['ratio'] as int? ?? 1,
      premium: (json['premium'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Represents a multi-leg order entry configuration with real-time risk/reward calculation.
class MultiLegOrderEntry {
  final String symbol;
  final double underlyingPrice;
  StrategyType strategyType;
  String strategyName;
  List<MultiLegOrderLeg> legs;
  int quantity;
  String orderType; // 'Limit', 'Market'
  double? limitPrice;
  String timeInForce; // 'day', 'gtc'

  MultiLegOrderEntry({
    required this.symbol,
    required this.underlyingPrice,
    this.strategyType = StrategyType.vertical,
    this.strategyName = 'Bull Call Spread',
    List<MultiLegOrderLeg>? legs,
    this.quantity = 1,
    this.orderType = 'Limit',
    this.limitPrice,
    this.timeInForce = 'gtc',
  }) : legs = legs ?? [];

  /// Net premium per share across all legs:
  /// Positive value = Net Credit (inflow)
  /// Negative value = Net Debit (outflow)
  double get netPremium {
    if (legs.isEmpty) return 0.0;
    double sum = 0.0;
    for (final leg in legs) {
      sum += leg.signedPremium;
    }
    return sum;
  }

  bool get isCredit => netPremium > 0;
  bool get isDebit => netPremium < 0;
  bool get isEven => netPremium == 0;

  /// Absolute value of net premium per share
  double get absNetPremium => netPremium.abs();

  /// Estimated total value across all contracts ($100 multiplier per contract)
  double get estimatedTotal {
    final effectivePrice = limitPrice ?? absNetPremium;
    return effectivePrice * quantity * 100.0;
  }

  /// Calculated maximum potential profit per contract (in dollars).
  /// Null if unlimited profit potential.
  double? get maxProfitPerContract {
    if (legs.isEmpty) return 0.0;

    switch (strategyType) {
      case StrategyType.single:
        final leg = legs.first;
        if (leg.isBuy && leg.isCall) return null; // Unlimited
        if (leg.isBuy && leg.isPut) {
          return ((leg.strike - leg.premium) * 100.0).clamp(0.0, double.infinity);
        }
        if (leg.isSell) {
          return leg.premium * 100.0; // Limited to premium received
        }
        return null;

      case StrategyType.vertical:
        if (legs.length != 2) return null;
        final leg1 = legs[0];
        final leg2 = legs[1];
        final strikeDiff = (leg1.strike - leg2.strike).abs();
        if (isDebit) {
          // Debit spread: max profit is width - debit paid
          return ((strikeDiff - absNetPremium) * 100.0).clamp(0.0, double.infinity);
        } else {
          // Credit spread: max profit is credit received
          return absNetPremium * 100.0;
        }

      case StrategyType.ironCondor:
        // Iron Condor is a credit strategy: max profit is net credit collected
        return absNetPremium * 100.0;

      case StrategyType.straddle:
      case StrategyType.strangle:
        // Long straddle/strangle: unlimited upside profit
        return null;

      case StrategyType.shortStraddle:
      case StrategyType.shortStrangle:
        // Short straddle/strangle: max profit is total credit collected
        return absNetPremium * 100.0;

      default:
        if (isCredit) return absNetPremium * 100.0;
        return null;
    }
  }

  /// Calculated maximum potential loss per contract (in dollars).
  /// Null if unlimited loss potential.
  double? get maxLossPerContract {
    if (legs.isEmpty) return 0.0;

    switch (strategyType) {
      case StrategyType.single:
        final leg = legs.first;
        if (leg.isBuy) return leg.premium * 100.0; // Limited to debit paid
        return null; // Selling naked call/put has undefined/unlimited risk

      case StrategyType.vertical:
        if (legs.length != 2) return null;
        final leg1 = legs[0];
        final leg2 = legs[1];
        final strikeDiff = (leg1.strike - leg2.strike).abs();
        if (isDebit) {
          // Debit spread: max loss is debit paid
          return absNetPremium * 100.0;
        } else {
          // Credit spread: max loss is width - credit received
          return ((strikeDiff - absNetPremium) * 100.0).clamp(0.0, double.infinity);
        }

      case StrategyType.ironCondor:
        if (legs.length != 4) return null;
        // Sort calls and puts
        final puts = legs.where((l) => l.isPut).toList()
          ..sort((a, b) => a.strike.compareTo(b.strike));
        final calls = legs.where((l) => l.isCall).toList()
          ..sort((a, b) => a.strike.compareTo(b.strike));

        double putSpreadWidth = 0.0;
        if (puts.length == 2) {
          putSpreadWidth = (puts[1].strike - puts[0].strike).abs();
        }
        double callSpreadWidth = 0.0;
        if (calls.length == 2) {
          callSpreadWidth = (calls[1].strike - calls[0].strike).abs();
        }
        final maxSpreadWidth = putSpreadWidth > callSpreadWidth ? putSpreadWidth : callSpreadWidth;
        return ((maxSpreadWidth - absNetPremium) * 100.0).clamp(0.0, double.infinity);

      case StrategyType.straddle:
      case StrategyType.strangle:
        // Long straddle/strangle: max loss is debit paid
        return absNetPremium * 100.0;

      case StrategyType.shortStraddle:
      case StrategyType.shortStrangle:
        // Short straddle/strangle: unlimited loss risk
        return null;

      default:
        if (isDebit) return absNetPremium * 100.0;
        return null;
    }
  }

  /// Total maximum profit across all contracts
  double? get totalMaxProfit {
    final perContract = maxProfitPerContract;
    return perContract != null ? perContract * quantity : null;
  }

  /// Total maximum loss across all contracts
  double? get totalMaxLoss {
    final perContract = maxLossPerContract;
    return perContract != null ? perContract * quantity : null;
  }

  /// Calculated breakeven stock prices at expiration.
  List<double> get breakevens {
    if (legs.isEmpty) return [];

    switch (strategyType) {
      case StrategyType.single:
        final leg = legs.first;
        if (leg.isCall) {
          return [leg.strike + (leg.isBuy ? leg.premium : -leg.premium)];
        } else {
          return [leg.strike - (leg.isBuy ? leg.premium : -leg.premium)];
        }

      case StrategyType.vertical:
        if (legs.length != 2) return [];
        final longLeg = legs.firstWhere((l) => l.isBuy, orElse: () => legs.first);
        final shortLeg = legs.firstWhere((l) => l.isSell, orElse: () => legs.last);

        if (longLeg.isCall && shortLeg.isCall) {
          // Call spread
          final lowerStrike = longLeg.strike < shortLeg.strike ? longLeg.strike : shortLeg.strike;
          return isDebit
              ? [lowerStrike + absNetPremium]
              : [lowerStrike + absNetPremium];
        } else if (longLeg.isPut && shortLeg.isPut) {
          // Put spread
          final higherStrike = longLeg.strike > shortLeg.strike ? longLeg.strike : shortLeg.strike;
          return isDebit
              ? [higherStrike - absNetPremium]
              : [higherStrike - absNetPremium];
        }
        return [];

      case StrategyType.straddle:
      case StrategyType.shortStraddle:
        if (legs.length != 2) return [];
        final strike = legs.first.strike;
        return [strike - absNetPremium, strike + absNetPremium];

      case StrategyType.strangle:
      case StrategyType.shortStrangle:
        if (legs.length != 2) return [];
        final putLeg = legs.firstWhere((l) => l.isPut, orElse: () => legs[0]);
        final callLeg = legs.firstWhere((l) => l.isCall, orElse: () => legs[1]);
        return [putLeg.strike - absNetPremium, callLeg.strike + absNetPremium];

      case StrategyType.ironCondor:
        if (legs.length != 4) return [];
        final shortPut = legs.firstWhere(
          (l) => l.isSell && l.isPut,
          orElse: () => legs[1],
        );
        final shortCall = legs.firstWhere(
          (l) => l.isSell && l.isCall,
          orElse: () => legs[2],
        );
        return [shortPut.strike - absNetPremium, shortCall.strike + absNetPremium];

      default:
        return [];
    }
  }

  /// Formatted risk/reward summary string (e.g. "1 : 2.4" or "Defined Risk")
  String get riskRewardRatio {
    final profit = maxProfitPerContract;
    final loss = maxLossPerContract;
    if (profit == null && loss != null) return 'Unlimited / \$${loss.toStringAsFixed(0)}';
    if (profit != null && loss == null) return '\$${profit.toStringAsFixed(0)} / Unlimited';
    if (profit != null && loss != null && loss > 0) {
      final ratio = profit / loss;
      return '1 : ${ratio.toStringAsFixed(2)}';
    }
    return 'Custom';
  }

  // Preset Strategy Factory Methods

  /// Bull Call Spread (Debit): Buy lower call, sell higher call
  factory MultiLegOrderEntry.bullCallSpread({
    required String symbol,
    required double spotPrice,
    DateTime? expiration,
  }) {
    final exp = expiration ?? DateTime.now().add(const Duration(days: 30));
    final strikeStep = _resolveStrikeStep(spotPrice);
    final lowerStrike = _roundToStep(spotPrice, strikeStep);
    final higherStrike = lowerStrike + strikeStep;

    return MultiLegOrderEntry(
      symbol: symbol,
      underlyingPrice: spotPrice,
      strategyType: StrategyType.vertical,
      strategyName: 'Bull Call Spread',
      legs: [
        MultiLegOrderLeg(
          id: 'leg_bc_1',
          action: LegAction.buy,
          type: LegType.call,
          strike: lowerStrike,
          expirationDate: exp,
          premium: spotPrice * 0.04,
        ),
        MultiLegOrderLeg(
          id: 'leg_bc_2',
          action: LegAction.sell,
          type: LegType.call,
          strike: higherStrike,
          expirationDate: exp,
          premium: spotPrice * 0.02,
        ),
      ],
    );
  }

  /// Bear Put Spread (Debit): Buy higher put, sell lower put
  factory MultiLegOrderEntry.bearPutSpread({
    required String symbol,
    required double spotPrice,
    DateTime? expiration,
  }) {
    final exp = expiration ?? DateTime.now().add(const Duration(days: 30));
    final strikeStep = _resolveStrikeStep(spotPrice);
    final higherStrike = _roundToStep(spotPrice, strikeStep);
    final lowerStrike = higherStrike - strikeStep;

    return MultiLegOrderEntry(
      symbol: symbol,
      underlyingPrice: spotPrice,
      strategyType: StrategyType.vertical,
      strategyName: 'Bear Put Spread',
      legs: [
        MultiLegOrderLeg(
          id: 'leg_bp_1',
          action: LegAction.buy,
          type: LegType.put,
          strike: higherStrike,
          expirationDate: exp,
          premium: spotPrice * 0.04,
        ),
        MultiLegOrderLeg(
          id: 'leg_bp_2',
          action: LegAction.sell,
          type: LegType.put,
          strike: lowerStrike,
          expirationDate: exp,
          premium: spotPrice * 0.02,
        ),
      ],
    );
  }

  /// Bull Put Spread (Credit): Sell higher put, buy lower put
  factory MultiLegOrderEntry.bullPutSpread({
    required String symbol,
    required double spotPrice,
    DateTime? expiration,
  }) {
    final exp = expiration ?? DateTime.now().add(const Duration(days: 30));
    final strikeStep = _resolveStrikeStep(spotPrice);
    final higherStrike = _roundToStep(spotPrice * 0.98, strikeStep);
    final lowerStrike = higherStrike - strikeStep;

    return MultiLegOrderEntry(
      symbol: symbol,
      underlyingPrice: spotPrice,
      strategyType: StrategyType.vertical,
      strategyName: 'Bull Put Spread',
      legs: [
        MultiLegOrderLeg(
          id: 'leg_bup_1',
          action: LegAction.sell,
          type: LegType.put,
          strike: higherStrike,
          expirationDate: exp,
          premium: spotPrice * 0.025,
        ),
        MultiLegOrderLeg(
          id: 'leg_bup_2',
          action: LegAction.buy,
          type: LegType.put,
          strike: lowerStrike,
          expirationDate: exp,
          premium: spotPrice * 0.012,
        ),
      ],
    );
  }

  /// Bear Call Spread (Credit): Sell lower call, buy higher call
  factory MultiLegOrderEntry.bearCallSpread({
    required String symbol,
    required double spotPrice,
    DateTime? expiration,
  }) {
    final exp = expiration ?? DateTime.now().add(const Duration(days: 30));
    final strikeStep = _resolveStrikeStep(spotPrice);
    final lowerStrike = _roundToStep(spotPrice * 1.02, strikeStep);
    final higherStrike = lowerStrike + strikeStep;

    return MultiLegOrderEntry(
      symbol: symbol,
      underlyingPrice: spotPrice,
      strategyType: StrategyType.vertical,
      strategyName: 'Bear Call Spread',
      legs: [
        MultiLegOrderLeg(
          id: 'leg_bec_1',
          action: LegAction.sell,
          type: LegType.call,
          strike: lowerStrike,
          expirationDate: exp,
          premium: spotPrice * 0.025,
        ),
        MultiLegOrderLeg(
          id: 'leg_bec_2',
          action: LegAction.buy,
          type: LegType.call,
          strike: higherStrike,
          expirationDate: exp,
          premium: spotPrice * 0.012,
        ),
      ],
    );
  }

  /// Long Straddle: Buy ATM Call & ATM Put
  factory MultiLegOrderEntry.straddle({
    required String symbol,
    required double spotPrice,
    DateTime? expiration,
  }) {
    final exp = expiration ?? DateTime.now().add(const Duration(days: 30));
    final strikeStep = _resolveStrikeStep(spotPrice);
    final atmStrike = _roundToStep(spotPrice, strikeStep);

    return MultiLegOrderEntry(
      symbol: symbol,
      underlyingPrice: spotPrice,
      strategyType: StrategyType.straddle,
      strategyName: 'Long Straddle',
      legs: [
        MultiLegOrderLeg(
          id: 'leg_std_c',
          action: LegAction.buy,
          type: LegType.call,
          strike: atmStrike,
          expirationDate: exp,
          premium: spotPrice * 0.035,
        ),
        MultiLegOrderLeg(
          id: 'leg_std_p',
          action: LegAction.buy,
          type: LegType.put,
          strike: atmStrike,
          expirationDate: exp,
          premium: spotPrice * 0.035,
        ),
      ],
    );
  }

  /// Long Strangle: Buy OTM Put & OTM Call
  factory MultiLegOrderEntry.strangle({
    required String symbol,
    required double spotPrice,
    DateTime? expiration,
  }) {
    final exp = expiration ?? DateTime.now().add(const Duration(days: 30));
    final strikeStep = _resolveStrikeStep(spotPrice);
    final putStrike = _roundToStep(spotPrice * 0.95, strikeStep);
    final callStrike = _roundToStep(spotPrice * 1.05, strikeStep);

    return MultiLegOrderEntry(
      symbol: symbol,
      underlyingPrice: spotPrice,
      strategyType: StrategyType.strangle,
      strategyName: 'Long Strangle',
      legs: [
        MultiLegOrderLeg(
          id: 'leg_stg_p',
          action: LegAction.buy,
          type: LegType.put,
          strike: putStrike,
          expirationDate: exp,
          premium: spotPrice * 0.018,
        ),
        MultiLegOrderLeg(
          id: 'leg_stg_c',
          action: LegAction.buy,
          type: LegType.call,
          strike: callStrike,
          expirationDate: exp,
          premium: spotPrice * 0.018,
        ),
      ],
    );
  }

  /// Iron Condor (Credit): Buy low put, sell mid put, sell mid call, buy high call
  factory MultiLegOrderEntry.ironCondor({
    required String symbol,
    required double spotPrice,
    DateTime? expiration,
  }) {
    final exp = expiration ?? DateTime.now().add(const Duration(days: 30));
    final strikeStep = _resolveStrikeStep(spotPrice);
    final shortPut = _roundToStep(spotPrice * 0.95, strikeStep);
    final longPut = shortPut - strikeStep;
    final shortCall = _roundToStep(spotPrice * 1.05, strikeStep);
    final longCall = shortCall + strikeStep;

    return MultiLegOrderEntry(
      symbol: symbol,
      underlyingPrice: spotPrice,
      strategyType: StrategyType.ironCondor,
      strategyName: 'Iron Condor',
      legs: [
        MultiLegOrderLeg(
          id: 'leg_ic_lp',
          action: LegAction.buy,
          type: LegType.put,
          strike: longPut,
          expirationDate: exp,
          premium: spotPrice * 0.01,
        ),
        MultiLegOrderLeg(
          id: 'leg_ic_sp',
          action: LegAction.sell,
          type: LegType.put,
          strike: shortPut,
          expirationDate: exp,
          premium: spotPrice * 0.022,
        ),
        MultiLegOrderLeg(
          id: 'leg_ic_sc',
          action: LegAction.sell,
          type: LegType.call,
          strike: shortCall,
          expirationDate: exp,
          premium: spotPrice * 0.022,
        ),
        MultiLegOrderLeg(
          id: 'leg_ic_lc',
          action: LegAction.buy,
          type: LegType.call,
          strike: longCall,
          expirationDate: exp,
          premium: spotPrice * 0.01,
        ),
      ],
    );
  }

  /// Single Leg option order
  factory MultiLegOrderEntry.singleLeg({
    required String symbol,
    required double spotPrice,
    LegAction action = LegAction.buy,
    LegType type = LegType.call,
    DateTime? expiration,
  }) {
    final exp = expiration ?? DateTime.now().add(const Duration(days: 30));
    final strikeStep = _resolveStrikeStep(spotPrice);
    final strike = _roundToStep(spotPrice, strikeStep);

    return MultiLegOrderEntry(
      symbol: symbol,
      underlyingPrice: spotPrice,
      strategyType: StrategyType.single,
      strategyName: '${action == LegAction.buy ? 'Long' : 'Short'} ${type == LegType.call ? 'Call' : 'Put'}',
      legs: [
        MultiLegOrderLeg(
          id: 'leg_single_1',
          action: action,
          type: type,
          strike: strike,
          expirationDate: exp,
          premium: spotPrice * 0.03,
        ),
      ],
    );
  }

  static double _resolveStrikeStep(double price) {
    if (price < 25) return 0.5;
    if (price < 50) return 1.0;
    if (price < 150) return 2.5;
    if (price < 300) return 5.0;
    return 10.0;
  }

  static double _roundToStep(double value, double step) {
    return (value / step).round() * step;
  }
}
