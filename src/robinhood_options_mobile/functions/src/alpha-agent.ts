import * as riskguard from "./riskguard-agent";
import { onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as indicators from "./technical-indicators";
import fetch from "node-fetch";

/**
 * Compute the Simple Moving Average (SMA) for a given period.
 * @param {number[]} prices - Array of prices.
 * @param {number} period - The period for the SMA.
 * @return {number|null} The computed SMA or null if not enough data.
 */
export function computeSMA(prices: number[], period: number): number | null {
  if (!prices || prices.length < period || period <= 0) return null;
  const slice = prices.slice(prices.length - period);
  const sum = slice.reduce((a, b) => a + b, 0);
  return sum / period;
}

/**
 * Fetch market index data (SPY or QQQ) for market direction analysis
 * @param {string} symbol The market index symbol (default: SPY)
 * @return {Promise<{prices: number[], volumes: number[]}>} Market data
 */
async function fetchMarketData(symbol = "SPY"): Promise<{
  prices: number[];
  volumes: number[];
}> {
  try {
    const baseUrl = "https://query1.finance.yahoo.com";
    const url = `${baseUrl}/v8/finance/chart/${symbol}` +
      "?interval=1d&range=1y"; // 3mo
    const resp = await fetch(url);
    const data: any = await resp.json();
    const result = data?.chart?.result?.[0];

    if (result &&
      Array.isArray(result?.indicators?.quote?.[0]?.close) &&
      Array.isArray(result?.indicators?.quote?.[0]?.volume)) {
      const closeData = result.indicators.quote[0].close;
      const volumeData = result.indicators.quote[0].volume;
      const closes = closeData.filter((p: any) => p !== null);
      const vols = volumeData.filter((v: any) => v !== null);

      return { prices: closes, volumes: vols };
    }
  } catch (err) {
    logger.warn(`Failed to fetch market data for ${symbol}`, err);
  }

  return { prices: [], volumes: [] };
}

/**
 * Handle Alpha agent logic for trade signal and risk assessment.
 * Uses multi-indicator analysis (Price Movement, Momentum,
 * Market Direction, Volume)
 * @param {object} marketData - Market data including prices,
 *                               volumes, and symbol.
 * @param {object} portfolioState - Current portfolio state.
 * @param {object} config - Trading configuration.
 * @return {Promise<object>} The result of the Alpha agent task.
 */
export async function handleAlphaTask(marketData: any,
  portfolioState: any, config: any) {
  const logMsg = "Alpha agent: handleAlphaTask called " +
    "with multi-indicator analysis";
  logger.info(logMsg, { marketData, portfolioState, config });

  const prices: number[] = marketData?.prices || [];
  const volumes: number[] = marketData?.volumes || [];
  const symbol = marketData?.symbol || "SPY";

  // Fetch market index data (SPY by default, or QQQ if configured)
  const marketIndexSymbol = config?.marketIndexSymbol || "SPY";
  const marketIndexData = await fetchMarketData(marketIndexSymbol);

  logger.info("Fetched market index data", {
    symbol: marketIndexSymbol,
    pricesLength: marketIndexData.prices.length,
    volumesLength: marketIndexData.volumes.length,
  });

  // Evaluate all 4 technical indicators
  const multiIndicatorResult = indicators.evaluateAllIndicators(
    { prices, volumes },
    marketIndexData,
    {
      rsiPeriod: config?.rsiPeriod || 14,
      marketFastPeriod: config?.smaPeriodFast || 10,
      marketSlowPeriod: config?.smaPeriodSlow || 30,
    }
  );

  const { allGreen, indicators: indicatorResults,
    overallSignal, reason } = multiIndicatorResult;

  logger.info("Multi-indicator evaluation", {
    allGreen,
    overallSignal,
    indicators: {
      priceMovement: indicatorResults.priceMovement.signal,
      momentum: indicatorResults.momentum.signal,
      marketDirection: indicatorResults.marketDirection.signal,
      volume: indicatorResults.volume.signal,
    },
  });

  // Legacy SMA calculation for backward compatibility
  const smaPeriodFast = config?.smaPeriodFast || 10;
  const smaPeriodSlow = config?.smaPeriodSlow || 30;
  const fast = computeSMA(prices, smaPeriodFast);
  const slow = computeSMA(prices, smaPeriodSlow);
  const fastPrev = prices.length > smaPeriodFast ?
    computeSMA(prices.slice(0, prices.length - 1), smaPeriodFast) : null;
  const slowPrev = prices.length > smaPeriodSlow ?
    computeSMA(prices.slice(0, prices.length - 1), smaPeriodSlow) : null;

  // If not all indicators are green, hold
  if (overallSignal === "HOLD") {
    // Persist signal even when holding
    try {
      const { getFirestore } = await import("firebase-admin/firestore");
      const db = getFirestore();
      const signalDoc = {
        timestamp: Date.now(),
        symbol: symbol,
        signal: overallSignal,
        reason,
        multiIndicatorResult,
        [`${smaPeriodFast}-day SMA`]: fast,
        [`${smaPeriodSlow}-day SMA`]: slow,
        currentPrice: marketData.currentPrice,
        config,
        portfolioState,
      };
      await db.doc(`agentic_trading/signals_${symbol}`).set(signalDoc);
      logger.info("Alpha agent stored HOLD signal", signalDoc);
    } catch (err) {
      logger.warn("Failed to persist trade signal", err);
    }

    return {
      status: "no_action",
      message: "Alpha agent: Multi-indicator analysis shows HOLD.",
      reason,
      signal: overallSignal,
      multiIndicatorResult,
    };
  }

  const lastPrice = prices.length > 0 ?
    prices[prices.length - 1] : marketData?.currentPrice || 0;
  const quantity = config?.tradeQuantity || 1;

  const proposal = {
    symbol,
    action: overallSignal,
    reason: reason,
    quantity,
    price: lastPrice,
    multiIndicatorResult,
  };

  // Call riskguard to assess
  const assessment = await riskguard.assessTrade(proposal,
    portfolioState, config);

  // Persist trade signal to Firestore
  try {
    const { getFirestore } = await import("firebase-admin/firestore");
    const db = getFirestore();
    const signalDoc = {
      timestamp: Date.now(),
      symbol: symbol,
      signal: overallSignal,
      reason,
      multiIndicatorResult,
      [`${smaPeriodFast}-day SMA`]: fast,
      [`${smaPeriodSlow}-day SMA`]: slow,
      [`Previous ${smaPeriodFast}-day SMA`]: fastPrev,
      [`Previous ${smaPeriodSlow}-day SMA`]: slowPrev,
      currentPrice: marketData.currentPrice,
      pricesLength: Array.isArray(marketData.prices) ?
        marketData.prices.length : 0,
      volumesLength: Array.isArray(marketData.volumes) ?
        marketData.volumes.length : 0,
      config,
      portfolioState,
      proposal,
      assessment,
    };
    await db.doc(`agentic_trading/signals_${symbol}`).set(signalDoc);
    logger.info("Alpha agent stored trade signal", signalDoc);
  } catch (err) {
    logger.warn("Failed to persist trade signal", err);
  }

  if (!assessment.approved) {
    return {
      status: "rejected",
      message: "RiskGuard agent rejected the proposal",
      proposal: proposal,
      assessment: assessment,
      multiIndicatorResult,
    };
  }

  return {
    status: "approved",
    message: `Alpha agent approved ${overallSignal} proposal: ` +
      "All 4 indicators aligned",
    proposal: proposal,
    assessment: assessment,
    multiIndicatorResult,
  };
}

/**
 * Cloud Function to handle Alpha agent task via HTTP trigger.
 * @param {object} request - The request object containing
 *                          marketData, portfolioState, and config.
 * @returns {Promise<object>} The Alpha agent task result.
 */
export const alphabotTask = onCall(async (request) => {
  logger.info("Alpha agent task called via onCall", { data: request.data });
  const marketData = request.data.marketData || {};
  const portfolioState = request.data.portfolioState || {};
  const config = request.data.config || {};
  const result = await handleAlphaTask(marketData,
    portfolioState, config);
  return result;
});
