import { onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as agenticTrading from "./agentic-trading";
import * as technicalIndicators from "./technical-indicators";

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
}

interface Trade {
  timestamp: string;
  action: string;
  price: number;
  quantity: number;
  commission: number;
  reason: string;
  signalData: technicalIndicators.MultiIndicatorResult | null;
}

interface Position {
  entryPrice: number;
  quantity: number;
  entryTimestamp: Date;
}

interface EquityPoint {
  timestamp: string;
  equity: number;
}

/**
 * Cloud Function for running backtests
 *
 * Takes a backtest configuration and simulates trades over historical data
 * using the same multi-indicator trading logic as live trading.
 */
export const runBacktest = onCall(async (request) => {
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
    // Validate inputs
    if (!symbol || !startDate || !endDate) {
      throw new Error(
        "Missing required parameters: symbol, startDate, endDate"
      );
    }

    const start = new Date(startDate);
    const end = new Date(endDate);

    if (start >= end) {
      throw new Error("startDate must be before endDate");
    }

    // Calculate range for historical data fetch
    const daysDiff = Math.ceil(
      (end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24)
    );
    let range = "1y";
    if (daysDiff <= 7) range = "5d";
    else if (daysDiff <= 30) range = "1mo";
    else if (daysDiff <= 90) range = "3mo";
    else if (daysDiff <= 180) range = "6mo";
    else if (daysDiff <= 365) range = "1y";
    else if (daysDiff <= 730) range = "2y";
    else range = "5y";

    logger.info("Fetching historical data", {
      symbol,
      range,
      interval,
      daysDiff,
    });

    // Fetch historical data for the symbol
    const symbolData = await agenticTrading.getMarketData(
      symbol,
      smaPeriodFast,
      smaPeriodSlow,
      interval,
      range
    );

    // Fetch market index data (SPY/QQQ)
    const marketData = await agenticTrading.getMarketData(
      marketIndexSymbol || "SPY",
      smaPeriodFast,
      smaPeriodSlow,
      interval,
      range
    );

    // Run backtest simulation
    const result = await runBacktestSimulation({
      symbol,
      symbolData,
      marketData,
      startDate: start,
      endDate: end,
      initialCapital: initialCapital || 10000,
      enabledIndicators: enabledIndicators || {},
      tradeQuantity: tradeQuantity || 1,
      takeProfitPercent: takeProfitPercent || 10,
      stopLossPercent: stopLossPercent || 5,
      trailingStopEnabled: trailingStopEnabled || false,
      trailingStopPercent: trailingStopPercent || 5,
      rsiPeriod: rsiPeriod || 14,
      smaPeriodFast: smaPeriodFast || 10,
      smaPeriodSlow: smaPeriodSlow || 30,
      config,
    });

    logger.info("Backtest completed", {
      symbol,
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
  } = params;

  const trades: Trade[] = [];
  let capital = initialCapital;
  let position: Position | null = null;
  let highestPriceInPosition = 0;
  const equityCurve: EquityPoint[] = [];
  const performanceByIndicator: Record<string, unknown> = {};

  // Get timestamps and prices
  const timestamps = symbolData.timestamps || [];
  const { opens, highs, lows, closes, volumes } = symbolData;

  // Find start and end indices
  const startIndex = timestamps.findIndex(
    (t: number) => new Date(t * 1000) >= startDate
  );
  const endIndex = timestamps.findIndex(
    (t: number) => new Date(t * 1000) > endDate
  );

  if (startIndex === -1) {
    throw new Error("Start date not found in historical data");
  }

  const finalIndex = endIndex === -1 ? timestamps.length : endIndex;

  logger.info("Backtest range", {
    startIndex,
    endIndex: finalIndex,
    totalBars: finalIndex - startIndex,
  });

  // Iterate through historical data
  for (let i = startIndex; i < finalIndex; i++) {
    const timestamp = new Date(timestamps[i] * 1000);
    const close = closes[i];

    // Get data up to current point
    const histSymbolData = {
      opens: opens.slice(0, i + 1),
      highs: highs.slice(0, i + 1),
      lows: lows.slice(0, i + 1),
      closes: closes.slice(0, i + 1),
      volumes: volumes.slice(0, i + 1),
    };

    const histMarketData = {
      closes: marketData.closes.slice(0, i + 1),
      volumes: marketData.volumes ?
        marketData.volumes.slice(0, i + 1) : undefined,
    };

    // Evaluate indicators at this point in time
    const multiIndicatorResult = technicalIndicators.evaluateAllIndicators(
      histSymbolData,
      histMarketData,
      {
        rsiPeriod,
        marketFastPeriod: smaPeriodFast,
        marketSlowPeriod: smaPeriodSlow,
        customIndicators: config?.customIndicators as any,
      }
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

      // Exit position if conditions met
      if (exitReason) {
        const exitValue = exitPrice * position.quantity;
        capital += exitValue;

        trades.push({
          timestamp: timestamp.toISOString(),
          action: "SELL",
          price: exitPrice,
          quantity: position.quantity,
          commission: 0,
          reason: exitReason,
          signalData: null,
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

      if (activeIndicators.length === 0) {
        continue; // Skip if no indicators enabled
      }

      // Check if all enabled indicators signal BUY
      const indicatorResults = multiIndicatorResult.indicators;
      const allBuy = activeIndicators.every((indicator) => {
        const result = (indicatorResults as Record<
          string,
          technicalIndicators.IndicatorResult
        >)[indicator];
        return result && result.signal === "BUY";
      });

      if (allBuy) {
        // Enter position
        const entryPrice = close;
        const quantity = tradeQuantity;
        const entryCost = entryPrice * quantity;

        if (entryCost <= capital) {
          capital -= entryCost;
          position = {
            entryPrice,
            quantity,
            entryTimestamp: timestamp,
          };
          highestPriceInPosition = entryPrice;

          trades.push({
            timestamp: timestamp.toISOString(),
            action: "BUY",
            price: entryPrice,
            quantity,
            commission: 0,
            reason: "Multi-indicator BUY signal",
            signalData: multiIndicatorResult,
          });
        }
      }
    }

    // Track equity curve
    const positionValue = position ?
      close * position.quantity : 0;
    const equity = capital + positionValue;
    equityCurve.push({
      timestamp: timestamp.toISOString(),
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
      price: exitPrice,
      quantity: position.quantity,
      commission: 0,
      reason: "End of backtest period",
      signalData: null,
    });
  }

  // Calculate performance metrics
  const finalCapital = capital;
  const totalReturn = finalCapital - initialCapital;
  const totalReturnPercent = (totalReturn / initialCapital) * 100;

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
    const ret =
      (equityCurve[i].equity - equityCurve[i - 1].equity) /
      equityCurve[i - 1].equity;
    returns.push(ret);
  }
  const avgReturn = returns.reduce((a, b) => a + b, 0) / returns.length;
  const variance =
    returns.reduce((sum, r) => sum + Math.pow(r - avgReturn, 2), 0) /
    returns.length;
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

  return {
    config,
    trades,
    finalCapital,
    totalReturn,
    totalReturnPercent,
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
    performanceByIndicator,
  };
}
