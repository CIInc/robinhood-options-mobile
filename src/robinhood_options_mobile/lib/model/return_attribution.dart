/// Data models for the Multi-Asset Brinson Performance & Greek Return
/// Attribution Engine (issue #278).
///
/// All values are computed on-device from already-hydrated position stores;
/// nothing here is persisted or sent to Firestore.
library;

/// A single holding reduced to the inputs Brinson attribution needs.
///
/// [beginValue] is the value at the start of the attribution window (e.g.
/// previous close × quantity) and [endValue] the value now. Weights are taken
/// from [beginValue], as Brinson-Fachler requires beginning-of-period weights.
class AttributionHolding {
  final String symbol;
  final String sector;
  final double beginValue;
  final double endValue;

  const AttributionHolding({
    required this.symbol,
    required this.sector,
    required this.beginValue,
    required this.endValue,
  });

  double get pnl => endValue - beginValue;
  double get periodReturn => beginValue == 0 ? 0 : pnl / beginValue;
}

/// Brinson-Fachler effects for one sector or asset class.
class BrinsonSectorAttribution {
  final String sector;
  final double portfolioWeight;
  final double benchmarkWeight;
  final double portfolioReturn;
  final double benchmarkReturn;
  final double allocationEffect;
  final double selectionEffect;
  final double interactionEffect;

  /// Beginning-of-window dollar value held in this sector.
  final double portfolioValue;

  /// Dollar P&L of the portfolio's holdings in this sector.
  final double portfolioPnL;

  const BrinsonSectorAttribution({
    required this.sector,
    required this.portfolioWeight,
    required this.benchmarkWeight,
    required this.portfolioReturn,
    required this.benchmarkReturn,
    required this.allocationEffect,
    required this.selectionEffect,
    required this.interactionEffect,
    required this.portfolioValue,
    required this.portfolioPnL,
  });

  double get totalEffect =>
      allocationEffect + selectionEffect + interactionEffect;

  double get activeWeight => portfolioWeight - benchmarkWeight;
}

/// Portfolio-level Brinson-Fachler decomposition.
///
/// Identity: `totalAllocationEffect + totalSelectionEffect +
/// totalInteractionEffect == activeReturn` (within floating-point error).
class BrinsonAttributionResult {
  final String benchmarkSymbol;
  final double totalPortfolioReturn;
  final double totalBenchmarkReturn;
  final double totalAllocationEffect;
  final double totalSelectionEffect;
  final double totalInteractionEffect;
  final double totalPortfolioValue;
  final double totalPortfolioPnL;
  final List<BrinsonSectorAttribution> sectorAttributions;

  /// Describes the measurement window, e.g. "Today's session".
  final String windowLabel;

  /// True when the benchmark sector weights are a stand-in (for example a
  /// custom benchmark that has no published sector breakdown).
  final bool usesProxyBenchmarkWeights;

  const BrinsonAttributionResult({
    required this.benchmarkSymbol,
    required this.totalPortfolioReturn,
    required this.totalBenchmarkReturn,
    required this.totalAllocationEffect,
    required this.totalSelectionEffect,
    required this.totalInteractionEffect,
    required this.totalPortfolioValue,
    required this.totalPortfolioPnL,
    required this.sectorAttributions,
    required this.windowLabel,
    this.usesProxyBenchmarkWeights = false,
  });

  double get activeReturn => totalPortfolioReturn - totalBenchmarkReturn;

  double get sumOfEffects =>
      totalAllocationEffect + totalSelectionEffect + totalInteractionEffect;

  bool get isEmpty => sectorAttributions.isEmpty || totalPortfolioValue <= 0;
}

/// Taylor-series P&L decomposition for one option position.
class GreekPnLAttribution {
  final String symbol;
  final double deltaPnL;
  final double gammaPnL;
  final double thetaPnL;

  /// P&L attributed to implied-volatility change. Without a stored prior IV,
  /// this is implied from the remainder after delta, gamma and theta.
  final double vegaPnL;

  /// Whatever the Greeks cannot explain (e.g. contracts with no vega).
  final double residualPnL;

  /// Observed mark-to-market change over the window.
  final double actualPnL;

  const GreekPnLAttribution({
    required this.symbol,
    required this.deltaPnL,
    required this.gammaPnL,
    required this.thetaPnL,
    required this.vegaPnL,
    required this.residualPnL,
    required this.actualPnL,
  });

  double get explainedPnL => deltaPnL + gammaPnL + thetaPnL + vegaPnL;
}

/// Disaggregated same-day income and yield attribution across dividends,
/// cash sweeps / interest, and SLIP securities lending.
class IncomeAttributionBreakdown {
  final double dividendIncome;
  final double interestAndSweepIncome;
  final double stockLoanIncome;
  final double dailySweepAccrualEstimate;
  final double dailyStockLoanAccrualEstimate;

  const IncomeAttributionBreakdown({
    this.dividendIncome = 0,
    this.interestAndSweepIncome = 0,
    this.stockLoanIncome = 0,
    this.dailySweepAccrualEstimate = 0,
    this.dailyStockLoanAccrualEstimate = 0,
  });

  double get totalIncomePnL =>
      dividendIncome + interestAndSweepIncome + stockLoanIncome;

  bool get hasBreakdown =>
      dividendIncome.abs() > 0 ||
      interestAndSweepIncome.abs() > 0 ||
      stockLoanIncome.abs() > 0 ||
      dailySweepAccrualEstimate.abs() > 0 ||
      dailyStockLoanAccrualEstimate.abs() > 0;
}

/// Aggregate options and income attribution.
class OptionsAttributionResult {
  final double totalDeltaPnL;
  final double totalGammaPnL;
  final double totalThetaPnL;
  final double totalVegaPnL;
  final double totalResidualPnL;
  final double totalIncomePnL;
  final IncomeAttributionBreakdown incomeBreakdown;
  final int contractCount;
  final List<GreekPnLAttribution> positions;
  final String windowLabel;

  static const String disclaimer =
      'Greek P&L is a second-order Taylor approximation from current '
      'Greeks and today\'s underlying move: Δ·ΔS + ½Γ·ΔS² + Θ·Δt. Vega '
      'P&L is implied from the remainder because prior implied volatility '
      'is not stored. Estimates, not broker-reported figures.';

  const OptionsAttributionResult({
    required this.totalDeltaPnL,
    required this.totalGammaPnL,
    required this.totalThetaPnL,
    required this.totalVegaPnL,
    required this.totalResidualPnL,
    required this.totalIncomePnL,
    IncomeAttributionBreakdown? incomeBreakdown,
    required this.contractCount,
    required this.positions,
    required this.windowLabel,
  }) : incomeBreakdown = incomeBreakdown ?? const IncomeAttributionBreakdown();

  /// Mark-to-market option P&L (sum of the Greek buckets and residual).
  double get totalOptionPnL =>
      totalDeltaPnL +
      totalGammaPnL +
      totalThetaPnL +
      totalVegaPnL +
      totalResidualPnL;

  /// Option P&L plus dividend, interest/sweep, and stock-lending income.
  double get totalPnL => totalOptionPnL + totalIncomePnL;

  bool get isEmpty =>
      positions.isEmpty &&
      contractCount == 0 &&
      totalIncomePnL == 0 &&
      !incomeBreakdown.hasBreakdown;
}
