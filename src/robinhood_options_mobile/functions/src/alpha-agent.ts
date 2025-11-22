import * as riskguard from "./riskguard-agent";
import { onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as indicators from "./technical-indicators";
import fetch from "node-fetch";

/**
 * Fetch market index data (SPY or QQQ) for market direction analysis
 * @param {string} symbol The market index symbol (default: SPY)
 * @return {Promise<{prices: number[], volumes: number[]}>} Market data
 */
async function fetchMarketData(symbol = "SPY"): Promise<{
  closes: number[];
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
      const clos = closeData.filter((p: any) => p !== null);
      const vols = volumeData.filter((v: any) => v !== null);

      return { closes: clos, volumes: vols };
    }
  } catch (err) {
    logger.warn(`Failed to fetch market data for ${symbol}`, err);
  }

  return { closes: [], volumes: [] };
}

/**
 * Handle Alpha agent logic for trade signal and risk assessment.
 * Uses multi-indicator analysis (Price Movement, Momentum,
 * Market Direction, Volume)
 * @param {object} marketData - Market data including closes,
 *                               volumes, and symbol.
 * @param {object} portfolioState - Current portfolio state.
 * @param {object} config - Trading configuration.
 * @param {string} interval - Chart interval (1d, 1h, 30m, 15m).
 * @return {Promise<object>} The result of the Alpha agent task.
 */
export async function handleAlphaTask(marketData: any,
  portfolioState: any, config: any, interval = "1d") {
  const logMsg = "Alpha agent: handleAlphaTask called " +
    "with multi-indicator analysis";
  logger.info(logMsg, { marketData, portfolioState, config, interval });

  const opens: number[] = marketData?.opens || [];
  const highs: number[] = marketData?.highs || [];
  const lows: number[] = marketData?.lows || [];
  const closes: number[] = marketData?.closes || [];
  const volumes: number[] = marketData?.volumes || [];
  const symbol = marketData?.symbol || "SPY";

  // Fetch market index data (SPY by default, or QQQ if configured)
  const marketIndexSymbol = config?.marketIndexSymbol || "SPY";
  const marketIndexData = await fetchMarketData(marketIndexSymbol);

  logger.info("Fetched market index data", {
    symbol: marketIndexSymbol,
    pricesLength: marketIndexData.closes.length,
    volumesLength: marketIndexData.volumes.length,
  });

  // Evaluate all 9 technical indicators
  const multiIndicatorResult = indicators.evaluateAllIndicators(
    { opens, highs, lows, closes, volumes },
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
    interval,
    indicators: {
      priceMovement: indicatorResults.priceMovement.signal,
      momentum: indicatorResults.momentum.signal,
      marketDirection: indicatorResults.marketDirection.signal,
      volume: indicatorResults.volume.signal,
      macd: indicatorResults.macd.signal,
      bollingerBands: indicatorResults.bollingerBands.signal,
      stochastic: indicatorResults.stochastic.signal,
      atr: indicatorResults.atr.signal,
      obv: indicatorResults.obv.signal,
    },
  });

  // If not all indicators are green, hold
  if (overallSignal === "HOLD") {
    // Persist signal even when holding
    try {
      const { getFirestore } = await import("firebase-admin/firestore");
      const db = getFirestore();
      const signalDocId = interval === "1d" ?
        `signals_${symbol}` : `signals_${symbol}_${interval}`;
      const signalDoc = {
        timestamp: Date.now(),
        symbol: symbol,
        interval: interval,
        signal: overallSignal,
        reason,
        multiIndicatorResult,
        currentPrice: marketData.currentPrice,
        config,
        portfolioState,
      };
      await db.doc(`agentic_trading/${signalDocId}`).set(signalDoc);
      logger.info(`Alpha agent stored HOLD signal for ${interval}`, signalDoc);
    } catch (err) {
      logger.warn("Failed to persist trade signal", err);
    }

    return {
      status: "no_action",
      message: "Alpha agent: Multi-indicator analysis shows " +
        `HOLD (${interval}).`,
      reason,
      signal: overallSignal,
      interval,
      multiIndicatorResult,
    };
  }

  const lastPrice = closes.length > 0 ?
    closes[closes.length - 1] : marketData?.currentPrice || 0;
  const quantity = config?.tradeQuantity || 1;

  const proposal = {
    symbol,
    action: overallSignal,
    reason: reason,
    quantity,
    price: lastPrice,
    interval,
    multiIndicatorResult,
  };

  // Call riskguard to assess
  const assessment = await riskguard.assessTrade(proposal,
    portfolioState, config);

  // Persist trade signal to Firestore
  try {
    const { getFirestore } = await import("firebase-admin/firestore");
    const db = getFirestore();
    const signalDocId = interval === "1d" ?
      `signals_${symbol}` : `signals_${symbol}_${interval}`;
    const signalDoc = {
      timestamp: Date.now(),
      symbol: symbol,
      interval: interval,
      signal: overallSignal,
      reason,
      multiIndicatorResult,
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
    await db.doc(`agentic_trading/${signalDocId}`).set(signalDoc);
    logger.info(`Alpha agent stored ${interval} trade signal`, signalDoc);
  } catch (err) {
    logger.warn("Failed to persist trade signal", err);
  }

  if (!assessment.approved) {
    return {
      status: "rejected",
      message: "RiskGuard agent rejected the proposal",
      proposal: proposal,
      assessment: assessment,
      interval,
      multiIndicatorResult,
    };
  }

  return {
    status: "approved",
    message: `Alpha agent approved ${overallSignal} proposal (${interval}): ` +
      "All 9 indicators aligned",
    proposal: proposal,
    assessment: assessment,
    interval,
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
