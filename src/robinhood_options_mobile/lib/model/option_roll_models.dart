import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';

enum RollPreset {
  rollOut, // Same strike, later expiration
  rollUpAndOut, // Higher strike, later expiration
  rollDownAndOut, // Lower strike, later expiration
  custom, // User-selected strike and expiration
}

class OptionRollCalculation {
  final OptionAggregatePosition position;
  final OptionInstrument oldInstrument;
  final OptionInstrument newInstrument;
  final double quantity;
  final double? underlyingPrice;
  final double? underlyingCostBasis;

  final bool isShort;
  final double closingPrice;
  final double openingPrice;
  final double netPrice; // Absolute price difference
  final String creditOrDebit; // 'credit' | 'debit'
  final double netCashFlow; // Positive for credit, negative for debit per share
  final double totalNetCashFlow; // Total dollar cash flow (x 100 x quantity)

  final int dteCurrent;
  final int dteTarget;
  final int dteDelta;
  final double strikeDelta;

  final double currentBreakeven;
  final double updatedBreakeven;
  final double breakevenDelta;

  final double? deltaOld;
  final double? deltaNew;
  final double? deltaChange;

  final double? thetaOld;
  final double? thetaNew;
  final double? thetaChange;

  final double? ivOld;
  final double? ivNew;
  final double? ivChange;

  OptionRollCalculation._({
    required this.position,
    required this.oldInstrument,
    required this.newInstrument,
    required this.quantity,
    this.underlyingPrice,
    this.underlyingCostBasis,
    required this.isShort,
    required this.closingPrice,
    required this.openingPrice,
    required this.netPrice,
    required this.creditOrDebit,
    required this.netCashFlow,
    required this.totalNetCashFlow,
    required this.dteCurrent,
    required this.dteTarget,
    required this.dteDelta,
    required this.strikeDelta,
    required this.currentBreakeven,
    required this.updatedBreakeven,
    required this.breakevenDelta,
    this.deltaOld,
    this.deltaNew,
    this.deltaChange,
    this.thetaOld,
    this.thetaNew,
    this.thetaChange,
    this.ivOld,
    this.ivNew,
    this.ivChange,
  });

  factory OptionRollCalculation.calculate({
    required OptionAggregatePosition position,
    required OptionInstrument oldInstrument,
    required OptionInstrument newInstrument,
    double? quantity,
    double? underlyingPrice,
    double? underlyingCostBasis,
  }) {
    final qty = quantity ?? position.quantity ?? 1.0;

    // Determine if the position is short or long
    final isShort = position.direction == 'credit' ||
        (position.legs.isNotEmpty &&
            position.legs.first.positionType == 'short');

    // Prices:
    // Closing: Buy to close for short (uses ask or mark), Sell to close for long (uses bid or mark)
    final double closingPrice = isShort
        ? (oldInstrument.optionMarketData?.askPrice != null &&
                oldInstrument.optionMarketData!.askPrice! > 0
            ? oldInstrument.optionMarketData!.askPrice!
            : (oldInstrument.optionMarketData?.markPrice ?? 0.0))
        : (oldInstrument.optionMarketData?.bidPrice != null &&
                oldInstrument.optionMarketData!.bidPrice! > 0
            ? oldInstrument.optionMarketData!.bidPrice!
            : (oldInstrument.optionMarketData?.markPrice ?? 0.0));

    // Opening: Sell to open for short (uses bid or mark), Buy to open for long (uses ask or mark)
    final double openingPrice = isShort
        ? (newInstrument.optionMarketData?.bidPrice != null &&
                newInstrument.optionMarketData!.bidPrice! > 0
            ? newInstrument.optionMarketData!.bidPrice!
            : (newInstrument.optionMarketData?.markPrice ?? 0.0))
        : (newInstrument.optionMarketData?.askPrice != null &&
                newInstrument.optionMarketData!.askPrice! > 0
            ? newInstrument.optionMarketData!.askPrice!
            : (newInstrument.optionMarketData?.markPrice ?? 0.0));

    // Net calculation:
    // For short: We pay closingPrice and receive openingPrice -> net = openingPrice - closingPrice
    // For long: We receive closingPrice and pay openingPrice -> net = closingPrice - openingPrice
    final double rawNet =
        isShort ? (openingPrice - closingPrice) : (closingPrice - openingPrice);

    final bool isCredit = rawNet >= 0;
    final String creditOrDebit = isCredit ? 'credit' : 'debit';
    final double netPrice = rawNet.abs();
    final double netCashFlow = rawNet; // positive for credit, negative for debit
    final double totalNetCashFlow = netCashFlow * qty * 100;

    // DTE calculations
    final now = DateTime.now();
    final dteCurrent = oldInstrument.expirationDate != null
        ? oldInstrument.expirationDate!.difference(now).inDays
        : 0;
    final dteTarget = newInstrument.expirationDate != null
        ? newInstrument.expirationDate!.difference(now).inDays
        : 0;
    final dteDelta = dteTarget - dteCurrent;

    // Strike delta
    final oldStrike = oldInstrument.strikePrice ?? 0.0;
    final newStrike = newInstrument.strikePrice ?? 0.0;
    final strikeDelta = newStrike - oldStrike;

    // Breakeven calculations
    final isCall = oldInstrument.type.toLowerCase() == 'call';
    final initialPerShareCost =
        (position.averageOpenPrice ?? 0.0) / 100.0; // Per share premium

    double curBreakeven = 0.0;
    double newBreakeven = 0.0;

    if (isShort) {
      if (isCall) {
        // Covered Call / Short Call
        final basis = underlyingCostBasis ??
            underlyingPrice ??
            (oldStrike - initialPerShareCost);
        curBreakeven = basis - initialPerShareCost;
        // When rolling short call:
        // Rolling for net credit lowers the breakeven further
        // Rolling for net debit increases the breakeven
        newBreakeven = curBreakeven - netCashFlow;
      } else {
        // Cash-Secured Put / Short Put
        // Breakeven = Strike - Premium
        curBreakeven = oldStrike - initialPerShareCost;
        // Rolled breakeven = new Strike - (original premium + net roll credit/debit)
        newBreakeven = newStrike - (initialPerShareCost + netCashFlow);
      }
    } else {
      if (isCall) {
        // Long Call
        // Breakeven = Strike + Premium
        curBreakeven = oldStrike + initialPerShareCost;
        // Rolled breakeven = new Strike + (prior net premium - netCashFlow)
        newBreakeven = newStrike + (initialPerShareCost - netCashFlow);
      } else {
        // Long Put
        // Breakeven = Strike - Premium
        curBreakeven = oldStrike - initialPerShareCost;
        newBreakeven = newStrike - (initialPerShareCost - netCashFlow);
      }
    }

    final breakevenDelta = newBreakeven - curBreakeven;

    // Greeks
    final deltaOld = oldInstrument.optionMarketData?.delta;
    final deltaNew = newInstrument.optionMarketData?.delta;
    final deltaChange = (deltaOld != null && deltaNew != null)
        ? (isShort ? -(deltaNew - deltaOld) : (deltaNew - deltaOld))
        : null;

    final thetaOld = oldInstrument.optionMarketData?.theta;
    final thetaNew = newInstrument.optionMarketData?.theta;
    final thetaChange = (thetaOld != null && thetaNew != null)
        ? (isShort ? -(thetaNew - thetaOld) : (thetaNew - thetaOld))
        : null;

    final ivOld = oldInstrument.optionMarketData?.impliedVolatility;
    final ivNew = newInstrument.optionMarketData?.impliedVolatility;
    final ivChange =
        (ivOld != null && ivNew != null) ? (ivNew - ivOld) : null;

    return OptionRollCalculation._(
      position: position,
      oldInstrument: oldInstrument,
      newInstrument: newInstrument,
      quantity: qty,
      underlyingPrice: underlyingPrice,
      underlyingCostBasis: underlyingCostBasis,
      isShort: isShort,
      closingPrice: closingPrice,
      openingPrice: openingPrice,
      netPrice: netPrice,
      creditOrDebit: creditOrDebit,
      netCashFlow: netCashFlow,
      totalNetCashFlow: totalNetCashFlow,
      dteCurrent: dteCurrent,
      dteTarget: dteTarget,
      dteDelta: dteDelta,
      strikeDelta: strikeDelta,
      currentBreakeven: curBreakeven,
      updatedBreakeven: newBreakeven,
      breakevenDelta: breakevenDelta,
      deltaOld: deltaOld,
      deltaNew: deltaNew,
      deltaChange: deltaChange,
      thetaOld: thetaOld,
      thetaNew: thetaNew,
      thetaChange: thetaChange,
      ivOld: ivOld,
      ivNew: ivNew,
      ivChange: ivChange,
    );
  }

  /// Builds the 2-leg structure suitable for [IBrokerageService.placeMultiLegOptionsOrder].
  List<Map<String, dynamic>> buildOrderLegs() {
    return [
      {
        'position_effect': 'close',
        'side': isShort ? 'buy' : 'sell',
        'ratio_quantity': 1,
        'option': oldInstrument.url,
        'option_instrument': oldInstrument,
      },
      {
        'position_effect': 'open',
        'side': isShort ? 'sell' : 'buy',
        'ratio_quantity': 1,
        'option': newInstrument.url,
        'option_instrument': newInstrument,
      },
    ];
  }

  /// Human-readable label for the roll action, e.g., "Roll Out", "Roll Up & Out"
  String get summaryLabel {
    final isCall = oldInstrument.type.toLowerCase() == 'call';
    if (dteDelta > 0 && strikeDelta == 0) {
      return 'Roll Out (+${dteDelta}d)';
    } else if (strikeDelta > 0) {
      return isCall
          ? 'Roll Up & Out (+\$${strikeDelta.toStringAsFixed(1)}, +${dteDelta}d)'
          : 'Roll Up (+\$${strikeDelta.toStringAsFixed(1)})';
    } else if (strikeDelta < 0) {
      return !isCall
          ? 'Roll Down & Out (-\$${(-strikeDelta).toStringAsFixed(1)}, +${dteDelta}d)'
          : 'Roll Down (-\$${(-strikeDelta).toStringAsFixed(1)})';
    }
    return 'Custom Roll';
  }
}
