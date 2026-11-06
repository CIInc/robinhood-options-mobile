import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { getMarketData } from "./market-data";
import * as technicalIndicators from "./technical-indicators";
import { CustomIndicatorConfig } from "./technical-indicators";

interface MarketData {
  timestamps?: number[];
  opens: number[];
  highs: number[];
  lows: number[];
  closes: number[];
  volumes: number[];
  currentPrice?: number | null;
  symbol?: string;
}

interface ExitStage {
  profitTargetPercent: number;
  quantityPercent: number;
}

interface BacktestParams {
  symbol: string;
  symbolData: MarketData;
  marketData: MarketData;
  startDate: Date;
  endDate: Date;
  initialCapital: number;
  enabledIndicators: Record<string, boolean>;
  tradeQuantity: number;
  takeProfitPercent: number;
  stopLossPercent: number;
  trailingStopEnabled: boolean;
  trailingStopPercent: number;
  rsiPeriod: number;
  smaPeriodFast: number;
  smaPeriodSlow: number;
  config: Record<string, unknown>;
  // New Params
  minSignalStrength: number;
  requireAllIndicatorsGreen: boolean;
  timeBasedExitEnabled: boolean;
  timeBasedExitMinutes: number;
  marketCloseExitEnabled: boolean;
  marketCloseExitMinutes: number;
  enablePartialExits: boolean;
  exitStages: ExitStage[];
  enableDynamicPositionSizing: boolean;
  riskPerTrade: number;
  atrMultiplier: number;
  customIndicators: CustomIndicatorConfig[];
  // Technical Exits
  rsiExitEnabled: boolean;
  rsiExitThreshold: number;
  signalStrengthExitEnabled: boolean;
  signalStrengthExitThreshold: number;
  gexExitEnabled: boolean;
  gexExitThreshold: number;
}

export type MarketRegimeType =
  | "BULL_LOW_VOL"
  | "BULL_HIGH_VOL"
  | "BEAR_LOW_VOL"
  | "BEAR_HIGH_VOL"
  | "UNKNOWN";

export interface RegimePerformance {
  regime: MarketRegimeType;
  label: string;
  tradeCount: number;
  winCount: number;
  lossCount: number;
  winRate: number;
  winRatePercent: number;
  netProfit: number;
  profitFactor: number;
  averageProfit: number;
  maxDrawdownPercent: number;
}

export interface WalkForwardPeriodMetrics {
  totalTrades: number;
  winRate: number;
  totalReturn: number;
  totalReturnPercent: number;
  profitFactor: number;
  sharpeRatio: number;
  maxDrawdownPercent: number;
}

export interface WalkForwardValidationResult {
  splitRatio: number;
  splitTimestamp: string;
  inSample: WalkForwardPeriodMetrics;
  outOfSample: WalkForwardPeriodMetrics;
  sharpeRetention: number;
  profitFactorRetention: number;
  stabilityScore: "ROBUST" | "MODERATE" | "OVERFITTED" | "INSUFFICIENT_DATA";
  summary: string;
}

interface Trade {
  timestamp: string;
  action: string;
  symbol: string;
  price: number;
  quantity: number;
  commission: number;
  reason: string;
  signalData: technicalIndicators.MultiIndicatorResult | null;
  entryRegime?: MarketRegimeType;
}

interface Position {
  entryPrice: number;
  quantity: number;
  entryTimestamp: Date;
  executedExitStages: number[]; // Indices of exit stages already executed
  entryRegime?: MarketRegimeType;
}

interface EquityPoint {
  timestamp: string;
  equity: number;
}

/**
 * Classifies benchmark conditions into 4 macro volatility regimes.
 * @param {number} benchmarkPrice Current benchmark close.
 * @param {number} benchmarkSma Benchmark moving average (e.g. SMA50).
 * @param {number} benchmarkNatr Benchmark normalized ATR percentage.
 * @param {number} natrThreshold Volatility threshold (default 1.15%).
 * @return {MarketRegimeType} Market regime.
 */
export function classifyMarketRegime(
  benchmarkPrice: number,
  benchmarkSma: number,
  benchmarkNatr: number,
  natrThreshold = 1.15
): MarketRegimeType {
  const isBull = benchmarkPrice >= benchmarkSma;
  const isHighVol = benchmarkNatr >= natrThreshold;
  if (isBull && !isHighVol) return "BULL_LOW_VOL";
  if (isBull && isHighVol) return "BULL_HIGH_VOL";
  if (!isBull && !isHighVol) return "BEAR_LOW_VOL";
  return "BEAR_HIGH_VOL";
}

/**
 * Computes trade performance attribution partitioned by market regime.
 * @param {Trade[]} trades List of executed trades.
 * @param {number} initialCapital Initial portfolio capital.
 * @return {Record<string, RegimePerformance>} Performance per regime.
 */
export function computeRegimeAttribution(
  trades: Trade[],
  initialCapital: number
): Record<string, RegimePerformance> {
  const regimes: MarketRegimeType[] = [
    "BULL_LOW_VOL",
    "BULL_HIGH_VOL",
    "BEAR_LOW_VOL",
    "BEAR_HIGH_VOL",
  ];
  const labels: Record<MarketRegimeType, string> = {
    BULL_LOW_VOL: "Bull Low-Vol",
    BULL_HIGH_VOL: "Bull High-Vol",
    BEAR_LOW_VOL: "Bear Low-Vol",
    BEAR_HIGH_VOL: "Bear High-Vol",
    UNKNOWN: "Unknown / Other",
  };

  const stats: Record<string, RegimePerformance> = {};
  for (const r of regimes) {
    stats[r] = {
      regime: r,
      label: labels[r],
      tradeCount: 0,
      winCount: 0,
      lossCount: 0,
      winRate: 0,
      winRatePercent: 0,
      netProfit: 0,
      profitFactor: 0,
      averageProfit: 0,
      maxDrawdownPercent: 0,
    };
  }

  const buyTrades = trades.filter((t) => t.action === "BUY");
  const sellTrades = trades.filter((t) => t.action === "SELL");
  const completed = Math.min(buyTrades.length, sellTrades.length);

  const grossProfits: Record<string, number> = {};
  const grossLosses: Record<string, number> = {};
  const peakPnl: Record<string, number> = {};
  const maxDd: Record<string, number> = {};

  for (const r of regimes) {
    grossProfits[r] = 0;
    grossLosses[r] = 0;
    peakPnl[r] = 0;
    maxDd[r] = 0;
  }

  for (let i = 0; i < completed; i++) {
    const buy = buyTrades[i];
    const sell = sellTrades[i];
    const regime = buy.entryRegime || "UNKNOWN";
    if (!stats[regime]) {
      stats[regime] = {
        regime,
        label: labels[regime] || regime,
        tradeCount: 0,
        winCount: 0,
        lossCount: 0,
        winRate: 0,
        winRatePercent: 0,
        netProfit: 0,
        profitFactor: 0,
        averageProfit: 0,
        maxDrawdownPercent: 0,
      };
      grossProfits[regime] = 0;
      grossLosses[regime] = 0;
      peakPnl[regime] = 0;
      maxDd[regime] = 0;
    }

    const pnl = (sell.price - buy.price) * buy.quantity;
    const s = stats[regime];
    s.tradeCount++;
    s.netProfit += pnl;

    if (pnl > 0) {
      s.winCount++;
      grossProfits[regime] += pnl;
    } else {
      s.lossCount++;
      grossLosses[regime] += Math.abs(pnl);
    }

    if (s.netProfit > peakPnl[regime]) {
      peakPnl[regime] = s.netProfit;
    }
    const currentDd = peakPnl[regime] - s.netProfit;
    if (currentDd > maxDd[regime]) {
      maxDd[regime] = currentDd;
    }
  }

  for (const key of Object.keys(stats)) {
    const s = stats[key];
    if (s.tradeCount > 0) {
      s.winRate = s.winCount / s.tradeCount;
      s.winRatePercent = Math.round(s.winRate * 100);
      s.averageProfit = s.netProfit / s.tradeCount;
      const gp = grossProfits[key] || 0;
      const gl = grossLosses[key] || 0;
      s.profitFactor = gl > 0 ?
        Number((gp / gl).toFixed(2)) :
        (gp > 0 ? 999 : 0);
      const cap = Math.max(1, initialCapital);
      s.maxDrawdownPercent = Number(((maxDd[key] / cap) * 100).toFixed(2));
      s.netProfit = Number(s.netProfit.toFixed(2));
      s.averageProfit = Number(s.averageProfit.toFixed(2));
    }
  }

  return stats;
}

/**
 * Evaluates in-sample vs out-of-sample performance to flag curve-fitting.
 * @param {Trade[]} trades List of executed trades.
 * @param {number} initialCapital Initial portfolio capital.
 * @param {number} splitRatio Ratio of in-sample trades (default 0.70).
 * @return {WalkForwardValidationResult} Walk-forward validation metrics.
 */
export function computeWalkForwardValidation(
  trades: Trade[],
  initialCapital: number,
  splitRatio = 0.7
): WalkForwardValidationResult {
  const buyTrades = trades.filter((t) => t.action === "BUY");
  const sellTrades = trades.filter((t) => t.action === "SELL");
  const completed = Math.min(buyTrades.length, sellTrades.length);

  const emptyPeriod = (): WalkForwardPeriodMetrics => ({
    totalTrades: 0,
    winRate: 0,
    totalReturn: 0,
    totalReturnPercent: 0,
    profitFactor: 0,
    sharpeRatio: 0,
    maxDrawdownPercent: 0,
  });

  if (completed < 4) {
    return {
      splitRatio,
      splitTimestamp: trades[0]?.timestamp || "",
      inSample: emptyPeriod(),
      outOfSample: emptyPeriod(),
      sharpeRetention: 1,
      profitFactorRetention: 1,
      stabilityScore: "INSUFFICIENT_DATA",
      summary: "Insufficient completed trades (need >= 4) for validation.",
    };
  }

  const isCount = Math.max(1, Math.floor(completed * splitRatio));
  const splitTimestamp = buyTrades[isCount]?.timestamp ||
    buyTrades[isCount - 1]?.timestamp || "";

  /**
   * Evaluates trade metrics for a given subset of completed trades.
   * @param {number} start Start trade index.
   * @param {number} end End trade index.
   * @param {number} baseCapital Starting capital for this period.
   * @return {object} Slice metrics and ending capital.
   */
  function evaluateSlice(
    start: number,
    end: number,
    baseCapital: number
  ): { metrics: WalkForwardPeriodMetrics; endingCapital: number } {
    let wins = 0;
    let grossWins = 0;
    let grossLosses = 0;
    let netPnl = 0;
    const sliceReturns: number[] = [];
    let currentEquity = baseCapital;
    let peakEquity = baseCapital;
    let maxDd = 0;

    for (let i = start; i < end; i++) {
      const buy = buyTrades[i];
      const sell = sellTrades[i];
      const pnl = (sell.price - buy.price) * buy.quantity;
      netPnl += pnl;
      if (pnl > 0) {
        wins++;
        grossWins += pnl;
      } else {
        grossLosses += Math.abs(pnl);
      }
      const prevEquity = currentEquity;
      currentEquity += pnl;
      if (prevEquity > 0) {
        sliceReturns.push(pnl / prevEquity);
      }
      if (currentEquity > peakEquity) {
        peakEquity = currentEquity;
      }
      const dd = peakEquity - currentEquity;
      if (dd > maxDd) {
        maxDd = dd;
      }
    }

    const count = end - start;
    const winRate = count > 0 ? Number((wins / count).toFixed(3)) : 0;
    const profitFactor = grossLosses > 0 ?
      Number((grossWins / grossLosses).toFixed(2)) :
      (grossWins > 0 ? 999 : 0);
    const returnPct = baseCapital > 0 ?
      Number(((netPnl / baseCapital) * 100).toFixed(2)) : 0;
    const maxDdPct = peakEquity > 0 ?
      Number(((maxDd / peakEquity) * 100).toFixed(2)) : 0;

    // Sharpe ratio
    let sharpe = 0;
    if (sliceReturns.length > 1) {
      const avg = sliceReturns.reduce((a, b) => a + b, 0) /
        sliceReturns.length;
      const variance = sliceReturns.reduce(
        (sum, r) => sum + Math.pow(r - avg, 2), 0
      ) / sliceReturns.length;
      const std = Math.sqrt(variance);
      if (std > 0) {
        sharpe = Number(((avg / std) * Math.sqrt(252)).toFixed(2));
      }
    }

    return {
      metrics: {
        totalTrades: count,
        winRate,
        totalReturn: Number(netPnl.toFixed(2)),
        totalReturnPercent: returnPct,
        profitFactor,
        sharpeRatio: sharpe,
        maxDrawdownPercent: maxDdPct,
      },
      endingCapital: currentEquity,
    };
  }

  const isResult = evaluateSlice(0, isCount, initialCapital);
  const oosResult = evaluateSlice(isCount, completed, isResult.endingCapital);

  const isSharpe = isResult.metrics.sharpeRatio;
  const oosSharpe = oosResult.metrics.sharpeRatio;
  const isPf = isResult.metrics.profitFactor;
  const oosPf = oosResult.metrics.profitFactor;

  let sharpeRetention = 1;
  if (isSharpe > 0) {
    sharpeRetention = Number((oosSharpe / isSharpe).toFixed(2));
  } else if (oosSharpe < 0) {
    sharpeRetention = 0;
  }

  let pfRetention = 1;
  if (isPf > 0) {
    pfRetention = Number((oosPf / isPf).toFixed(2));
  } else if (oosPf <= 0) {
    pfRetention = 0;
  }

  type StabilityTier =
    | "ROBUST"
    | "MODERATE"
    | "OVERFITTED"
    | "INSUFFICIENT_DATA";
  let stabilityScore: StabilityTier;
  let summary = "";

  if (completed < 8) {
    stabilityScore = "INSUFFICIENT_DATA";
    summary = "Limited sample size. Collect more trades for higher confidence.";
  } else if (
    oosResult.metrics.totalReturn >= 0 &&
    oosPf >= 1.0 &&
    (isSharpe <= 0 || sharpeRetention >= 0.65)
  ) {
    stabilityScore = "ROBUST";
    summary = "Robust out-of-sample performance. Strategy generalizes well.";
  } else if (
    oosResult.metrics.totalReturn >= 0 &&
    oosPf >= 0.85 &&
    (isSharpe <= 0 || sharpeRetention >= 0.35)
  ) {
    stabilityScore = "MODERATE";
    summary = "Moderate OOS degradation. Watch parameter sensitivity.";
  } else {
    stabilityScore = "OVERFITTED";
    summary = "High curve-fitting risk. Out-of-sample performance decayed.";
  }

  return {
    splitRatio,
    splitTimestamp,
    inSample: isResult.metrics,
    outOfSample: oosResult.metrics,
    sharpeRetention,
    profitFactorRetention: pfRetention,
    stabilityScore,
    summary,
  };
}

/**
 * Efficiently aggregates equity curves across multiple symbol backtest
 * results. Optimization: Replaces O(N^2 * M) quadratic searching
 * (`Array.find()` + `reverse().find()`) with O(N * M) Map lookups
 * and forward-state tracking.
 *
 * @param {Array<object>} results Backtest results per symbol
 * @param {number} symbolCapital Initial capital allocated per symbol
 * @return {EquityPoint[]} Combined equity points sorted chronologically
 */
export function aggregateEquityCurves(
  results: {
    equityCurve: EquityPoint[];
    buyAndHoldEquityCurve: EquityPoint[];
  }[],
  symbolCapital: number
): EquityPoint[] {
  // Map timestamp -> array index for O(1) lookup per result
  const resultMaps = results.map((r) => {
    const eqMap = new Map<string, number>();
    for (const p of r.equityCurve) {
      eqMap.set(p.timestamp, p.equity);
    }
    const bhMap = new Map<string, number>();
    for (const p of r.buyAndHoldEquityCurve) {
      bhMap.set(p.timestamp, p.equity);
    }
    return { eqMap, bhMap };
  });

  // Collect and sort all distinct timestamps
  const timeSet = new Set<string>();
  for (const r of results) {
    for (const p of r.equityCurve) {
      timeSet.add(p.timestamp);
    }
  }
  // Optimization: ISO 8601 string timestamps sort in chronological order
  // lexicographically, avoiding allocating Date objects for sorting.
  const sortedTimes = Array.from(timeSet).sort(
    (a, b) => (a < b ? -1 : a > b ? 1 : 0)
  );

  // Track current/last known equity state per symbol to avoid searching
  // backward
  const lastEquity = new Array<number>(results.length).fill(symbolCapital);
  const lastBuyAndHold = new Array<number>(results.length).fill(symbolCapital);

  const combinedEquityCurve = sortedTimes.map((t) => {
    let sumEquity = 0;
    let sumBuyAndHold = 0;

    for (let i = 0; i < results.length; i++) {
      const eqVal = resultMaps[i].eqMap.get(t);
      if (eqVal !== undefined) {
        lastEquity[i] = eqVal;
      }
      sumEquity += lastEquity[i];

      const bhVal = resultMaps[i].bhMap.get(t);
      if (bhVal !== undefined) {
        lastBuyAndHold[i] = bhVal;
      }
      sumBuyAndHold += lastBuyAndHold[i];
    }

    return {
      timestamp: t,
      equity: sumEquity,
      buyAndHoldEquity: sumBuyAndHold,
    };
  });

  return combinedEquityCurve;
}

/**
 * Cloud Function for running backtests
 *
 * Takes a backtest configuration and simulates trades over historical data
 * using the same multi-indicator trading logic as live trading.
 */
export const runBacktest = onCall({
  secrets: ["TWELVE_DATA_API_KEY"],
  timeoutSeconds: 300,
  memory: "512MiB",
}, async (request) => {
  // SECURITY: Require authentication to prevent unauthorized execution
  // and API secret consumption
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "Authentication is required to run backtests."
    );
  }

  logger.info("Starting backtest", { structuredData: true });

  const config = request.data;
  const {
    symbol,
    startDate,
    endDate,
    initialCapital,
    interval,
    enabledIndicators,
    tradeQuantity,
    takeProfitPercent,
    stopLossPercent,
    trailingStopEnabled,
    trailingStopPercent,
    rsiPeriod,
    smaPeriodFast,
    smaPeriodSlow,
    marketIndexSymbol,
  } = config;

  try {
    const symbols = request.data.symbolFilter &&
      request.data.symbolFilter.length > 0 ?
      request.data.symbolFilter :
      (symbol ? [symbol] : []);

    // Validate inputs
    if (symbols.length === 0 || !startDate || !endDate) {
      throw new Error(
        "Missing required params: symbol/symbolFilter, startDate, endDate"
      );
    }

    const start = new Date(startDate);
    const end = new Date(endDate);

    if (start >= end) {
      throw new Error("startDate must be before endDate");
    }

    // Calculate range for historical data fetch based
    // on start date relative to now
    // We need enough history to cover the start date
    const now = new Date();
    const daysDiff = Math.ceil(
      (now.getTime() - start.getTime()) / (1000 * 60 * 60 * 24)
    );
    let range = "1y";
    if (daysDiff <= 7) range = "5d";
    else if (daysDiff <= 30) range = "1mo";
    else if (daysDiff <= 90) range = "3mo";
    else if (daysDiff <= 180) range = "6mo";
    else if (daysDiff <= 365) range = "1y";
    else if (daysDiff <= 730) range = "2y";
    else if (daysDiff <= 1825) range = "5y";
    else range = "10y";

    logger.info("Fetching historical data", {
      symbols,
      range,
      interval,
      daysDiff,
    });

    // Fetch market index data (SPY/QQQ)
    const marketData = await getMarketData(
      marketIndexSymbol || "SPY",
      smaPeriodFast,
      smaPeriodSlow,
      interval,
      range
    );

    const symbolCapital = symbols.length > 0 ?
      (initialCapital || 10000) / symbols.length :
      (initialCapital || 10000);

    const results = await Promise.all(symbols.map(async (sym: string) => {
      // Fetch historical data for the symbol
      const symbolData = await getMarketData(
        sym,
        smaPeriodFast,
        smaPeriodSlow,
        interval,
        range
      );

      return runBacktestSimulation({
        symbol: sym,
        symbolData,
        marketData,
        startDate: start,
        endDate: end,
        initialCapital: symbolCapital,
        enabledIndicators: enabledIndicators || {},
        tradeQuantity: tradeQuantity || 1,
        takeProfitPercent: takeProfitPercent || 10,
        stopLossPercent: stopLossPercent || 5,
        trailingStopEnabled: trailingStopEnabled || false,
        trailingStopPercent: trailingStopPercent || 5,
        rsiPeriod: rsiPeriod || 14,
        smaPeriodFast: smaPeriodFast || 10,
        smaPeriodSlow: smaPeriodSlow || 30,
        config: config,
        minSignalStrength: request.data.minSignalStrength || 50,
        requireAllIndicatorsGreen:
          request.data.requireAllIndicatorsGreen || false,
        timeBasedExitEnabled: request.data.timeBasedExitEnabled || false,
        timeBasedExitMinutes: request.data.timeBasedExitMinutes || 120,
        marketCloseExitEnabled: request.data.marketCloseExitEnabled || false,
        marketCloseExitMinutes: request.data.marketCloseExitMinutes || 15,
        enablePartialExits: request.data.enablePartialExits || false,
        exitStages: request.data.exitStages || [],
        enableDynamicPositionSizing:
          request.data.enableDynamicPositionSizing || false,
        riskPerTrade: request.data.riskPerTrade || 0.01,
        atrMultiplier: request.data.atrMultiplier || 2.0,
        customIndicators: request.data.customIndicators || [],
        rsiExitEnabled: request.data.rsiExitEnabled || false,
        rsiExitThreshold: request.data.rsiExitThreshold || 80,
        signalStrengthExitEnabled:
          request.data.signalStrengthExitEnabled || false,
        signalStrengthExitThreshold:
          request.data.signalStrengthExitThreshold || 40,
        gexExitEnabled: request.data.gexExitEnabled || false,
        gexExitThreshold: request.data.gexExitThreshold || 0,
      });
    }));

    // If single result, return it (but ensure type compatibility)
    if (results.length === 1) {
      return results[0];
    }

    // Aggregate Results for Portfolio
    let totalInitialCapital = 0;
    let totalFinalCapital = 0;
    let totalBuyAndHoldReturn = 0;
    let totalTradesCount = 0;
    let totalWinningTrades = 0;
    let totalLosingTrades = 0;
    let totalWins = 0;
    let totalLosses = 0;
    let maxWin = 0;
    let maxLoss = 0;
    // weighted by trades count? No, just sum(avg * count)
    let totalHoldTimePts = 0;
    const totalDurationSeconds = results[0].totalDurationSeconds; // Use first

    const allTrades: Trade[] = [];
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const aggSignals: Record<string, any> = {};

    // Combine stats
    for (const res of results) {
      totalInitialCapital += symbolCapital; // Approx, effectively user input
      totalFinalCapital += res.finalCapital;
      totalBuyAndHoldReturn += res.buyAndHoldReturn;
      totalTradesCount += res.totalTrades;
      totalWinningTrades += res.winningTrades;
      totalLosingTrades += res.losingTrades;

      // Re-derive totals from averages
      const resTotalWins = res.averageWin * res.winningTrades;
      // averageLoss is usually positive magnitude
      const resTotalLosses = res.averageLoss * res.losingTrades;

      totalWins += resTotalWins;
      totalLosses += resTotalLosses;

      if (res.largestWin > maxWin) maxWin = res.largestWin;
      if (res.largestLoss > maxLoss) maxLoss = res.largestLoss;

      totalHoldTimePts += res.averageHoldTimeSeconds * res.totalTrades;

      allTrades.push(...res.trades);

      // Aggregate signals
      if (res.indicatorSignalCounts) {
        for (const k of Object.keys(res.indicatorSignalCounts)) {
          if (!aggSignals[k]) {
            aggSignals[k] = { ...res.indicatorSignalCounts[k] };
          } else {
            aggSignals[k].buy += res.indicatorSignalCounts[k].buy;
            aggSignals[k].sell += res.indicatorSignalCounts[k].sell;
            aggSignals[k].hold += res.indicatorSignalCounts[k].hold;
            aggSignals[k].winContribution +=
              res.indicatorSignalCounts[k].winContribution;
          }
        }
      }
    }

    const totalReturn = totalFinalCapital - totalInitialCapital;
    const totalReturnPercent = totalInitialCapital > 0 ?
      (totalReturn / totalInitialCapital) * 100 : 0;
    const totalBuyAndHoldReturnPercent = totalInitialCapital > 0 ?
      (totalBuyAndHoldReturn / totalInitialCapital) * 100 : 0;

    // Sort trades
    allTrades.sort((a, b) =>
      new Date(a.timestamp).getTime() - new Date(b.timestamp).getTime()
    );

    const combinedEquityCurve = aggregateEquityCurves(results, symbolCapital);

    const buyAndHoldEquityCurve = combinedEquityCurve.map((p) => ({
      timestamp: p.timestamp,
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      equity: (p as any).buyAndHoldEquity,
    }));

    // Calculate Portfolio Max Drawdown from combined curve
    let peak = -Infinity;
    let maxDrawdown = 0;
    for (const pt of combinedEquityCurve) {
      if (pt.equity > peak) peak = pt.equity;
      const dd = peak - pt.equity;
      if (dd > maxDrawdown) maxDrawdown = dd;
    }
    const maxDrawdownPercent = peak > 0 ? (maxDrawdown / peak) * 100 : 0;

    // Recalculate Portfolio Sharpe (Simplified: Daily Returns)
    // We need daily returns of the *portfolio equity*.
    // Note: timestamps might be intraday.
    const returns = [];
    for (let i = 1; i < combinedEquityCurve.length; i++) {
      const val = combinedEquityCurve[i].equity;
      const prev = combinedEquityCurve[i - 1].equity;
      returns.push((val - prev) / prev);
    }
    const avgRet = returns.length > 0 ?
      returns.reduce((a, b) => a + b, 0) / returns.length : 0;
    const diffSq = returns.length > 0 ?
      returns.reduce((a, b) => a + Math.pow(b - avgRet, 2), 0) : 0;
    const variance = returns.length > 0 ? diffSq / returns.length : 0;
    const stdDev = Math.sqrt(variance);
    // Annualize (assuming daily bars roughly)
    const sharpeRatio = stdDev > 0 ? (avgRet / stdDev) * Math.sqrt(252) : 0;

    // Rebuild Performance By Indicator
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const performanceByIndicator: Record<string, any> = {};
    for (const k of Object.keys(aggSignals)) {
      const counts = aggSignals[k];
      const wr = counts.buy > 0 ? counts.winContribution / counts.buy : 0;
      const wrP = Math.round(wr * 100);
      performanceByIndicator[k] = {
        buySignals: counts.buy,
        sellSignals: counts.sell,
        holdSignals: counts.hold,
        winRate: wrP,
        winRateDisplay: `${wrP}%`,
        summary:
          `${counts.buy} BUY, ${counts.sell} SELL, ` +
          `${counts.hold} HOLD - ${wrP}% wins`,
      };
    }

    const result = {
      config,
      trades: allTrades,
      finalCapital: totalFinalCapital,
      totalReturn,
      totalReturnPercent,
      buyAndHoldReturn: totalBuyAndHoldReturn,
      buyAndHoldReturnPercent: totalBuyAndHoldReturnPercent,
      totalTrades: totalTradesCount,
      winningTrades: totalWinningTrades,
      losingTrades: totalLosingTrades,
      winRate: totalTradesCount > 0 ? totalWinningTrades / totalTradesCount : 0,
      averageWin: totalWinningTrades > 0 ? totalWins / totalWinningTrades : 0,
      averageLoss: totalLosingTrades > 0 ? totalLosses / totalLosingTrades : 0,
      largestWin: maxWin,
      largestLoss: maxLoss,
      profitFactor: totalLosses > 0 ? totalWins / totalLosses : 0,
      sharpeRatio,
      maxDrawdown,
      maxDrawdownPercent,
      averageHoldTimeSeconds: totalTradesCount > 0 ?
        Math.floor(totalHoldTimePts / totalTradesCount) : 0,
      totalDurationSeconds,
      equityCurve: combinedEquityCurve,
      buyAndHoldEquityCurve,
      performanceByIndicator,
    };

    logger.info("Backtest completed (Multi-Symbol)", {
      symbols,
      totalTrades: result.totalTrades,
      totalReturn: result.totalReturn,
    });

    return result;
  } catch (error) {
    logger.error("Backtest error", { error });
    throw error;
  }
});

/**
 * Run the backtest simulation
 * @param {BacktestParams} params - Backtest configuration parameters
 * @return {Promise<any>} Backtest results
 */
async function runBacktestSimulation(params: BacktestParams) {
  const {
    symbol,
    symbolData,
    marketData,
    startDate,
    endDate,
    initialCapital,
    enabledIndicators,
    tradeQuantity,
    takeProfitPercent,
    stopLossPercent,
    trailingStopEnabled,
    trailingStopPercent,
    rsiPeriod,
    smaPeriodFast,
    smaPeriodSlow,
    config,
    minSignalStrength,
    requireAllIndicatorsGreen,
    timeBasedExitEnabled,
    timeBasedExitMinutes,
    marketCloseExitEnabled,
    marketCloseExitMinutes,
    enablePartialExits,
    exitStages,
    enableDynamicPositionSizing,
    riskPerTrade,
    atrMultiplier,
    customIndicators,
    rsiExitEnabled,
    rsiExitThreshold,
    signalStrengthExitEnabled,
    signalStrengthExitThreshold,
    gexExitEnabled,
    gexExitThreshold,
  } = params;

  const trades: Trade[] = [];
  let capital = initialCapital;
  let position: Position | null = null;
  let highestPriceInPosition = 0;
  const equityCurve: EquityPoint[] = [];
  const buyAndHoldEquityCurve: EquityPoint[] = [];
  const performanceByIndicator: Record<string, unknown> = {};
  let initialPositionQuantity = 0; // Track initial quantity for partial exits

  // Get timestamps and prices
  const timestamps = symbolData.timestamps || [];
  const { closes } = symbolData;

  // Optimization: Use primitive numeric comparison on timestamp
  // milliseconds instead of allocating Date objects for every bar
  // in findIndex.
  const startMs = startDate.getTime();
  const endMs = endDate.getTime();

  const startIndex = timestamps.findIndex(
    (t: number) => t * 1000 >= startMs
  );
  const endIndex = timestamps.findIndex(
    (t: number) => t * 1000 > endMs
  );

  if (startIndex === -1) {
    throw new Error("Start date not found in historical data");
  }

  const finalIndex = endIndex === -1 ? timestamps.length : endIndex;
  // Calculate Start Price for Buy & Hold
  const initialPrice = closes[startIndex];

  logger.info("Backtest range", {
    startIndex,
    endIndex: finalIndex,
    totalBars: finalIndex - startIndex,
  });

  // Optimization: Pre-calculate active keys
  const activeIndicatorKeys = Object.keys(enabledIndicators).filter(
    (key) => enabledIndicators[key] === true
  );

  // Precompute benchmark regimes aligned with symbol timestamps
  let mIdx = 0;
  const benchmarkCloses = marketData?.closes || [];
  const benchmarkHighs = marketData?.highs || [];
  const benchmarkLows = marketData?.lows || [];
  const benchmarkTimes = marketData?.timestamps || [];

  const getBenchmarkRegimeAt = (targetSec: number): MarketRegimeType => {
    if (!benchmarkCloses.length) return "UNKNOWN";
    while (
      benchmarkTimes.length &&
      mIdx + 1 < benchmarkTimes.length &&
      benchmarkTimes[mIdx + 1] <= targetSec
    ) {
      mIdx++;
    }
    const idx = Math.min(mIdx, benchmarkCloses.length - 1);
    const close = benchmarkCloses[idx];
    const periodSma = Math.min(50, idx + 1);
    const sma = technicalIndicators.computeSMA(
      benchmarkCloses,
      periodSma,
      idx + 1
    ) ?? close;
    const periodAtr = Math.min(14, idx);
    let natr = 1.0;
    if (periodAtr >= 2 && benchmarkHighs.length > idx) {
      const atr = technicalIndicators.computeATR(
        benchmarkHighs,
        benchmarkLows,
        benchmarkCloses,
        periodAtr,
        idx + 1
      );
      if (atr && close > 0) {
        natr = (atr / close) * 100;
      }
    }
    return classifyMarketRegime(close, sma, natr);
  };

  // Iterate through historical data
  for (let i = startIndex; i < finalIndex; i++) {
    const timestampMs = timestamps[i] * 1000;
    const timestamp = new Date(timestampMs);
    const isoTimestamp = timestamp.toISOString();
    const close = closes[i];
    const currentRegime = getBenchmarkRegimeAt(timestamps[i]);

    // Buy & Hold Calculation
    const bhChangePercent = (close - initialPrice) / initialPrice;
    const bhEquity = initialCapital * (1 + bhChangePercent);
    buyAndHoldEquityCurve.push({
      timestamp: isoTimestamp,
      equity: bhEquity,
    });

    // Evaluate indicators at this point in time without array slicing
    const multiIndicatorResult = technicalIndicators.evaluateAllIndicators(
      symbolData,
      marketData,
      {
        rsiPeriod,
        marketFastPeriod: smaPeriodFast,
        marketSlowPeriod: smaPeriodSlow,
        customIndicators: customIndicators ||
          (config?.customIndicators as CustomIndicatorConfig[]),
        enabledIndicators: activeIndicatorKeys, // Optimization: only active
      },
      undefined,
      i + 1,
      Math.min(i + 1, marketData.closes.length)
    );

    // Check if we have an open position
    if (position) {
      // Track highest price for trailing stop
      if (close > highestPriceInPosition) {
        highestPriceInPosition = close;
      }

      // Check exit conditions
      let exitReason: string | null = null;
      const exitPrice = close;

      // Partial Exits
      if (enablePartialExits && exitStages && exitStages.length > 0) {
        const profitPercent =
          ((close - position.entryPrice) / position.entryPrice) * 100;

        for (let j = 0; j < exitStages.length; j++) {
          const stage = exitStages[j];
          if (!position.executedExitStages.includes(j) &&
            profitPercent >= stage.profitTargetPercent) {
            // Execute partial exit
            const exitQuantity = Math.floor(
              initialPositionQuantity * stage.quantityPercent
            );
            if (exitQuantity > 0 && exitQuantity <= position.quantity) {
              const exitValue = exitPrice * exitQuantity;
              capital += exitValue;

              trades.push({
                timestamp: isoTimestamp,
                action: "SELL",
                symbol,
                price: exitPrice,
                quantity: exitQuantity,
                commission: 0,
                reason: `Partial Take Profit (${stage.profitTargetPercent}%)`,
                signalData: multiIndicatorResult,
                entryRegime: position.entryRegime || currentRegime,
              });

              position.quantity -= exitQuantity;
              position.executedExitStages.push(j);

              // If completely exited
              if (position.quantity <= 0) {
                position = null;
                // Just to skip other checks
                exitReason = "Partial Exit Completed";
                break;
              }
            }
          }
        }
        if (!position) continue; // Skip rest of loop if position closed
      }

      // Take profit
      const profitPercent =
        ((close - position.entryPrice) / position.entryPrice) * 100;
      if (profitPercent >= takeProfitPercent) {
        exitReason = "Take Profit";
      }

      // Stop loss
      if (!exitReason && profitPercent <= -stopLossPercent) {
        exitReason = "Stop Loss";
      }

      // Trailing stop
      if (!exitReason && trailingStopEnabled) {
        const drawdownFromHigh =
          ((highestPriceInPosition - close) / highestPriceInPosition) * 100;
        if (drawdownFromHigh >= trailingStopPercent) {
          exitReason = "Trailing Stop";
        }
      }

      // Time-Based Exit
      if (!exitReason && timeBasedExitEnabled) {
        const durationMs =
          timestamp.getTime() - position.entryTimestamp.getTime();
        const durationMinutes = durationMs / (1000 * 60);
        if (durationMinutes >= timeBasedExitMinutes) {
          exitReason = "Time-Based Exit";
        }
      }

      // Market Close Exit
      if (!exitReason && marketCloseExitEnabled) {
        // Assuming timestamp is in UTC, convert to EST to check time
        // Market Closes at 16:00 EST.
        const estTime = new Date(timestamp.toLocaleString("en-US", {
          timeZone: "America/New_York",
        }));
        const hour = estTime.getHours();
        const minute = estTime.getMinutes();

        const closeHour = 15; // 3 PM used as base
        // If it is 15:XX and we are within minutes of close (16:00 is close)
        // Actually market close is 16:00.
        // If marketCloseExitMinutes is 15, we exit at 15:45 or later.

        if (hour === closeHour && minute >= (60 - marketCloseExitMinutes)) {
          exitReason = "Market Close Exit";
        }
      }

      // Technical Exits
      if (!exitReason && rsiExitEnabled) {
        const rsi = multiIndicatorResult.indicators.momentum?.value;
        if (rsi !== undefined && rsi !== null && rsi >= rsiExitThreshold) {
          exitReason = `RSI Exit (${rsi.toFixed(1)})`;
        }
      }

      if (!exitReason && signalStrengthExitEnabled) {
        const strength = multiIndicatorResult.signalStrength;
        if (strength !== undefined && strength !== null &&
          strength < signalStrengthExitThreshold) {
          exitReason = `Weak Signal Exit (${strength.toFixed(1)}%)`;
        }
      }

      if (!exitReason && gexExitEnabled) {
        const gex = multiIndicatorResult.indicators.gammaExposure?.value;
        if (gex !== undefined && gex !== null && gex < gexExitThreshold) {
          exitReason = `GEX Exit ($${(gex / 1e6).toFixed(1)}M)`;
        }
      }

      // Exit position if conditions met
      if (exitReason) {
        const exitValue = exitPrice * position.quantity;
        capital += exitValue;

        trades.push({
          timestamp: isoTimestamp,
          action: "SELL",
          symbol,
          price: exitPrice,
          quantity: position.quantity,
          commission: 0,
          reason: exitReason,
          signalData: null,
          entryRegime: position.entryRegime || currentRegime,
        });

        position = null;
        highestPriceInPosition = 0;
      }
    } else {
      // No position - check for entry signal
      // Filter enabled indicators
      const activeIndicators = Object.keys(enabledIndicators).filter(
        (key) => enabledIndicators[key] === true
      );

      // Add custom indicators to evaluation
      const activeCustomIndicators = customIndicators || [];
      const totalActiveIndicators =
        activeIndicators.length + activeCustomIndicators.length;

      if (totalActiveIndicators === 0) {
        continue; // Skip if no indicators enabled
      }

      const indicatorResults = multiIndicatorResult.indicators;
      const customResults = multiIndicatorResult.customIndicators || {};

      let indicatorsBuy = 0;
      let indicatorsGreen = true;
      const buySignalsList: string[] = [];

      // Check standard indicators
      for (const indicator of activeIndicators) {
        const result = (indicatorResults as Record<
          string,
          technicalIndicators.IndicatorResult
        >)[indicator];
        if (result) {
          if (result.signal === "BUY") {
            indicatorsBuy++;
            buySignalsList.push(indicator);
          } else {
            indicatorsGreen = false;
          }
        }
      }

      // Check custom indicators
      for (const customInd of activeCustomIndicators) {
        const result = customResults[customInd.id];
        if (result) {
          if (result.signal === "BUY") {
            indicatorsBuy++;
            buySignalsList.push(customInd.name);
          } else {
            indicatorsGreen = false;
          }
        }
      }

      // Calculate signal strength based on ENABLED indicators
      const strength = (indicatorsBuy / totalActiveIndicators) * 100;

      let shouldEnter = false;
      if (requireAllIndicatorsGreen) {
        shouldEnter = indicatorsGreen;
      } else {
        shouldEnter = strength >= minSignalStrength;
      }

      if (shouldEnter) {
        // Enter position
        const entryPrice = close;
        let quantity = tradeQuantity;

        // Dynamic Position Sizing
        if (enableDynamicPositionSizing &&
          multiIndicatorResult.indicators.atr?.value) {
          const atr = multiIndicatorResult.indicators.atr.value;
          const riskPerShare = atr * atrMultiplier;
          if (riskPerShare > 0) {
            const riskAmount = capital * riskPerTrade;
            quantity = Math.floor(riskAmount / riskPerShare);
          }
        }

        const entryCost = entryPrice * quantity;

        if (entryCost <= capital && quantity > 0) {
          capital -= entryCost;
          position = {
            entryPrice,
            quantity,
            entryTimestamp: timestamp,
            executedExitStages: [],
            entryRegime: currentRegime,
          };
          initialPositionQuantity = quantity;
          highestPriceInPosition = entryPrice;

          trades.push({
            timestamp: isoTimestamp,
            action: "BUY",
            symbol,
            price: entryPrice,
            quantity,
            commission: 0,
            reason:
              `Signal Entry (Strength: ${strength.toFixed(1)}% - ` +
              `${buySignalsList.join(", ")})`,
            signalData: multiIndicatorResult,
            entryRegime: currentRegime,
          });
        }
      }
    }

    // Track equity curve
    const positionValue = position ?
      close * position.quantity : 0;
    const equity = capital + positionValue;
    equityCurve.push({
      timestamp: isoTimestamp,
      equity,
    });
  }

  // Close any open position at end of backtest
  if (position) {
    const exitPrice = closes[finalIndex - 1];
    const exitValue = exitPrice * position.quantity;
    capital += exitValue;

    trades.push({
      timestamp: new Date(timestamps[finalIndex - 1] * 1000).toISOString(),
      action: "SELL",
      symbol,
      price: exitPrice,
      quantity: position.quantity,
      commission: 0,
      reason: "End of backtest period",
      signalData: null,
      entryRegime: position.entryRegime || "UNKNOWN",
    });
  }

  // Calculate performance metrics
  const finalCapital = capital;
  const totalReturn = finalCapital - initialCapital;
  const totalReturnPercent = (totalReturn / initialCapital) * 100;

  // Calculate Buy & Hold Return
  const startPrice = closes[startIndex];
  const endPrice = closes[finalIndex - 1];
  const buyAndHoldReturnPercent =
    ((endPrice - startPrice) / startPrice) * 100;
  const buyAndHoldReturn = initialCapital * (buyAndHoldReturnPercent / 100);

  // Calculate trade statistics
  const buyTrades = trades.filter((t) => t.action === "BUY");
  const sellTrades = trades.filter((t) => t.action === "SELL");
  const completedTrades = Math.min(buyTrades.length, sellTrades.length);

  let winningTrades = 0;
  let losingTrades = 0;
  let totalWins = 0;
  let totalLosses = 0;
  let largestWin = 0;
  let largestLoss = 0;
  const holdTimes: number[] = [];

  for (let i = 0; i < completedTrades; i++) {
    const buy = buyTrades[i];
    const sell = sellTrades[i];
    const pnl = (sell.price - buy.price) * buy.quantity;

    if (pnl > 0) {
      winningTrades++;
      totalWins += pnl;
      if (pnl > largestWin) largestWin = pnl;
    } else {
      losingTrades++;
      totalLosses += Math.abs(pnl);
      if (Math.abs(pnl) > largestLoss) largestLoss = Math.abs(pnl);
    }

    const buyTime = new Date(buy.timestamp).getTime();
    const sellTime = new Date(sell.timestamp).getTime();
    holdTimes.push(sellTime - buyTime);
  }

  const winRate = completedTrades > 0 ? winningTrades / completedTrades : 0;
  const averageWin = winningTrades > 0 ? totalWins / winningTrades : 0;
  const averageLoss = losingTrades > 0 ? totalLosses / losingTrades : 0;
  const profitFactor = totalLosses > 0 ?
    totalWins / totalLosses : (totalWins > 0 ? 999 : 0);

  // Calculate Sharpe ratio
  const returns: number[] = [];
  for (let i = 1; i < equityCurve.length; i++) {
    const val = equityCurve[i].equity;
    const prev = equityCurve[i - 1].equity;
    // Guard against division by zero if prev is 0 (bankruptcy)
    if (prev === 0) {
      returns.push(0);
    } else {
      const ret = (val - prev) / prev;
      returns.push(ret);
    }
  }
  const avgReturn = returns.length > 0 ?
    returns.reduce((a, b) => a + b, 0) / returns.length : 0;
  const variance = returns.length > 0 ?
    returns.reduce((sum, r) => sum + Math.pow(r - avgReturn, 2), 0) /
    returns.length : 0;
  const stdDev = Math.sqrt(variance);
  const sharpeRatio = stdDev > 0 ? (avgReturn / stdDev) * Math.sqrt(252) : 0;

  // Calculate max drawdown
  let peak = initialCapital;
  let maxDrawdown = 0;
  let maxDrawdownPercent = 0;
  for (const point of equityCurve) {
    if (point.equity > peak) {
      peak = point.equity;
    }
    const drawdown = peak - point.equity;
    const drawdownPercent = (drawdown / peak) * 100;
    if (drawdown > maxDrawdown) {
      maxDrawdown = drawdown;
      maxDrawdownPercent = drawdownPercent;
    }
  }

  // Calculate average hold time
  const avgHoldTimeMs = holdTimes.length > 0 ?
    holdTimes.reduce((a, b) => a + b, 0) / holdTimes.length : 0;
  const avgHoldTimeSeconds = Math.floor(avgHoldTimeMs / 1000);

  // Calculate total duration
  const totalDurationMs =
    new Date(timestamps[finalIndex - 1] * 1000).getTime() -
    new Date(timestamps[startIndex] * 1000).getTime();
  const totalDurationSeconds = Math.floor(totalDurationMs / 1000);

  // Performance by indicator - analyze signal contribution and accuracy
  const indicatorSignalCounts: Record<
    string,
    { buy: number; sell: number; hold: number; winContribution: number }
  > = {};

  // Initialize counters for all enabled indicators
  for (const indicator of Object.keys(enabledIndicators)) {
    if (enabledIndicators[indicator]) {
      indicatorSignalCounts[indicator] = {
        buy: 0,
        sell: 0,
        hold: 0,
        winContribution: 0,
      };
    }
  }

  // Track signals from buy trades
  for (let i = 0; i < completedTrades; i++) {
    const buyTrade = buyTrades[i];
    const sellTrade = sellTrades[i];
    const pnl = (sellTrade.price - buyTrade.price) * buyTrade.quantity;
    const isWin = pnl > 0;

    if (buyTrade.signalData && buyTrade.signalData.indicators) {
      for (const indicator of Object.keys(enabledIndicators)) {
        if (enabledIndicators[indicator]) {
          const indResult = (buyTrade.signalData.indicators as Record<
            string,
            technicalIndicators.IndicatorResult
          >)[indicator];

          if (indResult) {
            if (indResult.signal === "BUY") {
              indicatorSignalCounts[indicator].buy++;
              if (isWin) {
                indicatorSignalCounts[indicator].winContribution++;
              }
            } else if (indResult.signal === "SELL") {
              indicatorSignalCounts[indicator].sell++;
            } else {
              indicatorSignalCounts[indicator].hold++;
            }
          }
        }
      }
    }
  }

  // Build performance summary for each indicator
  for (const indicator of Object.keys(indicatorSignalCounts)) {
    const counts = indicatorSignalCounts[indicator];
    const winRate = counts.buy > 0 ? counts.winContribution / counts.buy : 0;
    const winRatePercent = Math.round(winRate * 100);

    performanceByIndicator[indicator] = {
      buySignals: counts.buy,
      sellSignals: counts.sell,
      holdSignals: counts.hold,
      winRate: winRatePercent,
      winRateDisplay: `${winRatePercent}%`,
      summary:
        `${counts.buy} BUY, ${counts.sell} SELL, ` +
        `${counts.hold} HOLD - ${winRatePercent}% wins`,
    };
  }

  const regimeAttribution = computeRegimeAttribution(trades, initialCapital);
  const walkForwardValidation = computeWalkForwardValidation(
    trades,
    initialCapital
  );

  return {
    config,
    trades,
    finalCapital,
    totalReturn,
    totalReturnPercent,
    buyAndHoldReturn,
    buyAndHoldReturnPercent,
    totalTrades: trades.length,
    winningTrades,
    losingTrades,
    winRate,
    averageWin,
    averageLoss,
    largestWin,
    largestLoss,
    profitFactor,
    sharpeRatio,
    maxDrawdown,
    maxDrawdownPercent,
    averageHoldTimeSeconds: avgHoldTimeSeconds,
    totalDurationSeconds: totalDurationSeconds,
    equityCurve,
    buyAndHoldEquityCurve,
    performanceByIndicator,
    indicatorSignalCounts,
    regimeAttribution,
    walkForwardValidation,
  };
}
