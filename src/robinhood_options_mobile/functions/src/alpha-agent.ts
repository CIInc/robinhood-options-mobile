import * as riskguard from "./riskguard-agent";
import { onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as indicators from "./technical-indicators";
import { optimizeSignal } from "./signal-optimizer";
import fetch from "node-fetch";
import { getFirestore } from "firebase-admin/firestore";

const db = getFirestore();

/**
 * Check if cached market data is stale
 * During market hours (9:30 AM - 4:00 PM EST), refresh every 15 minutes
 * After hours, cache is valid for the rest of the trading day
 * @param {any} cacheData The full cache document with chart and updated fields
 * @return {boolean} True if stale
 */
function isMarketDataCacheStale(cacheData: any): boolean {
  const chart = cacheData?.chart;
  const updated = cacheData?.updated;

  if (!chart?.meta?.currentTradingPeriod?.regular?.end) {
    return true;
  }
  const endSec = chart.meta.currentTradingPeriod.regular.end;
  const endMs = endSec * 1000;
  const now = new Date();

  // Use America/New_York timezone for consistent market hours
  const estTimeString = now.toLocaleString("en-US", {
    timeZone: "America/New_York",
    hour12: false,
  });

  // Parse EST time components
  const estMatch =
    estTimeString.match(/(\d+)\/(\d+)\/(\d+),?\s+(\d+):(\d+):(\d+)/);
  if (!estMatch) {
    logger.warn("Failed to parse EST time", { estTimeString });
    return true; // Treat as stale if we can't parse
  }

  const [, month, day, year, hour, minute] = estMatch;
  const estHour = parseInt(hour, 10);
  const estMinute = parseInt(minute, 10);

  const todayStartEST = new Date(
    parseInt(year, 10),
    parseInt(month, 10) - 1,
    parseInt(day, 10),
    0,
    0,
    0
  ).getTime();

  // Check if from previous trading day
  if (endMs < todayStartEST) {
    return true;
  }

  // During market hours (9:30 AM - 4:00 PM EST), refresh every 15 minutes
  const isMarketHours =
    (estHour > 9 || (estHour === 9 && estMinute >= 30)) && estHour < 16;

  logger.info("📅 Market hours check", {
    estTimeString,
    estHour,
    estMinute,
    isMarketHours,
    cacheUpdated: updated,
    cacheAge: updated ? now.getTime() - updated : null,
  });

  // If no updated timestamp, treat as stale (legacy cache)
  if (!updated) {
    logger.info("⚠️ Cache missing 'updated' field - treating as stale");
    return true;
  }

  if (isMarketHours) {
    const cacheAge = now.getTime() - updated;
    const maxCacheAge = 15 * 60 * 1000; // 15 minutes
    const isStale = cacheAge > maxCacheAge;
    logger.info(`🕐 Cache age check: ${Math.round(cacheAge / 1000 / 60)} min ` +
      `(max: 15 min) - ${isStale ? "STALE" : "FRESH"}`);
    return isStale;
  }

  logger.info("✅ Cache valid (after market hours)");
  return false;
}

/**
 * Fetch market index data (SPY or QQQ) for market direction analysis
 * Now includes Firestore caching with timezone-aware staleness check
 * @param {string} symbol The market index symbol (default: SPY)
 * @return {Promise<{prices: number[], volumes: number[]}>} Market data
 */
async function fetchMarketData(symbol = "SPY"): Promise<{
  closes: number[];
  volumes: number[];
}> {
  let closes: number[] = [];
  let volumes: number[] = [];

  // Try to load cached data from Firestore
  const cacheKey = `agentic_trading/chart_${symbol}`;
  logger.info(`🔍 Checking cache for ${symbol}`, { cacheKey });
  try {
    const doc = await db.doc(cacheKey).get();
    if (doc.exists) {
      const cacheData = doc.data();
      const chart = cacheData?.chart;
      logger.info(`📦 Cache document exists for ${symbol}`, {
        hasChart: !!chart,
        hasUpdated: !!(cacheData?.updated),
        updated: cacheData?.updated,
        chartClosesLength: chart?.indicators?.quote?.[0]?.close?.length,
      });
      const isStale = isMarketDataCacheStale(cacheData);
      const isCached = chart && !isStale;

      logger.info(`🎯 Cache decision for ${symbol}`, {
        isStale,
        isCached,
        willUseCache: isCached && chart.indicators?.quote?.[0]?.close,
      });

      if (isCached && chart.indicators?.quote?.[0]?.close) {
        const closeData = chart.indicators.quote[0].close;
        const volumeData = chart.indicators.quote[0].volume || [];
        closes = closeData.filter((p: any) => p !== null);
        volumes = volumeData.filter((v: any) => v !== null);
        const lastFew = closes.slice(-5);
        logger.info(`✅ CACHE HIT: Loaded cached market data for ${symbol}`, {
          count: closes.length,
          lastFivePrices: lastFew,
          cacheAge: Date.now() - (cacheData?.updated || 0),
          source: "cache",
        });
        return { closes, volumes };
      } else {
        logger.info(`❌ CACHE MISS: Cached market data for ${symbol} is ` +
          "stale, fetching fresh data");
      }
    }
  } catch (err) {
    logger.warn(`Failed to load cached market data for ${symbol}`, err);
  }

  // Fetch fresh data from Yahoo Finance
  try {
    const baseUrl = "https://query1.finance.yahoo.com";
    const url = `${baseUrl}/v8/finance/chart/${symbol}` +
      "?interval=1d&range=1y";
    const resp = await fetch(url);
    const data: any = await resp.json();
    const result = data?.chart?.result?.[0];

    if (result &&
      Array.isArray(result?.indicators?.quote?.[0]?.close) &&
      Array.isArray(result?.indicators?.quote?.[0]?.volume)) {
      // Remove nested arrays that cause Firestore errors
      delete result.meta?.tradingPeriods;

      const closeData = result.indicators.quote[0].close;
      const volumeData = result.indicators.quote[0].volume;
      closes = closeData.filter((p: any) => p !== null);
      volumes = volumeData.filter((v: any) => v !== null);

      const lastFew = closes.slice(-5);
      logger.info(`🌐 FRESH FETCH: Retrieved ${closes.length} prices ` +
        `for ${symbol} from Yahoo Finance`, {
        lastFivePrices: lastFew,
        source: "yahoo-finance",
      });

      // Cache the data
      try {
        await db.doc(cacheKey).set({ chart: result, updated: Date.now() });
        logger.info(`💾 Cached market data for ${symbol} in Firestore`);
      } catch (err) {
        logger.warn(`Failed to cache market data for ${symbol}`, err);
      }

      return { closes, volumes };
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

  // Log detailed market data for debugging cache consistency
  const lastFewPrices = marketIndexData.closes.slice(-5);
  logger.info("📊 Market index data retrieved", {
    symbol: marketIndexSymbol,
    pricesLength: marketIndexData.closes.length,
    volumesLength: marketIndexData.volumes.length,
    lastFivePrices: lastFewPrices,
    lastPrice: lastFewPrices[lastFewPrices.length - 1],
  });

  // Evaluate all 9 technical indicators
  const indicatorConfig = {
    rsiPeriod: config?.rsiPeriod || 14,
    marketFastPeriod: config?.smaPeriodFast || 10,
    marketSlowPeriod: config?.smaPeriodSlow || 30,
    customIndicators: config?.customIndicators || [],
  };

  logger.info(`📊 Evaluating indicators for ${symbol} with config`, {
    marketFastPeriod: indicatorConfig.marketFastPeriod,
    marketSlowPeriod: indicatorConfig.marketSlowPeriod,
    configSmaPeriodFast: config?.smaPeriodFast,
    configSmaPeriodSlow: config?.smaPeriodSlow,
    marketDataClosesLength: marketIndexData.closes.length,
    symbolDataClosesLength: closes.length,
    marketIndexDataLastFive: marketIndexData.closes.slice(-5),
  });

  const multiIndicatorResult = indicators.evaluateAllIndicators(
    { opens, highs, lows, closes, volumes },
    marketIndexData,
    indicatorConfig
  );

  // Check if indicators have changed since last run to avoid expensive ML calls
  const signalDocId = interval === "1d" ?
    `signals_${symbol}` : `signals_${symbol}_${interval}`;
  let previousSignalDoc: any = null;
  try {
    const doc = await db.doc(`agentic_trading/${signalDocId}`).get();
    if (doc.exists) {
      previousSignalDoc = doc.data();
    }
  } catch (e) {
    logger.warn(`Error fetching previous signal for ${symbol}`, e);
  }

  let optimization: any = null;
  let indicatorsChanged = true;

  if (previousSignalDoc && previousSignalDoc.multiIndicatorResult) {
    // Simple string comparison of indicators object
    // This assumes key order stability which is generally true in V8
    const prevIndicators = JSON.stringify(
      previousSignalDoc.multiIndicatorResult.indicators
    );
    const currIndicators = JSON.stringify(multiIndicatorResult.indicators);
    if (prevIndicators === currIndicators) {
      indicatorsChanged = false;
      logger.info(`Indicators unchanged for ${symbol}, skipping processing`);
      // Reuse previous optimization if available
      optimization = previousSignalDoc.optimization;

      // If indicators haven't changed, we can skip the rest of the processing
      // and return the previous result (or a no-action result)
      return {
        status: "no_action",
        message: "Alpha agent: Indicators unchanged, skipping processing.",
        reason: previousSignalDoc.reason,
        signal: previousSignalDoc.signal,
        interval,
        multiIndicatorResult: previousSignalDoc.multiIndicatorResult,
      };
    }
  }

  // Optimize signal with ML
  // Only run optimization if indicators changed
  if (indicatorsChanged) {
    try {
      optimization = await optimizeSignal(
        symbol,
        interval,
        multiIndicatorResult,
        { opens, highs, lows, closes, volumes },
        marketIndexData
      );
    } catch (error) {
      logger.error(`Error running signal optimization for ${symbol}`, error);
    }
  }

  let { allGreen, indicators: indicatorResults,
    overallSignal, reason } = multiIndicatorResult;

  // Apply ML Optimization (Smart Filter)
  if (optimization && optimization.confidenceScore > 75) {
    // If ML strongly disagrees with a trade signal, downgrade to HOLD
    if (overallSignal !== "HOLD" &&
      optimization.refinedSignal === "HOLD") {
      logger.info(
        `📉 ML Optimization for ${symbol} downgraded ${overallSignal} ` +
        "to HOLD",
        {
          original: overallSignal,
          mlSignal: optimization.refinedSignal,
          confidence: optimization.confidenceScore,
          reason: optimization.reasoning,
        }
      );
      overallSignal = "HOLD";
      reason = `ML Optimization: ${optimization.reasoning}`;
      // Update the result object for storage consistency
      multiIndicatorResult.overallSignal = "HOLD";
      multiIndicatorResult.reason = reason;
    } else if (overallSignal === "HOLD" &&
      optimization.refinedSignal !== "HOLD") {
      // If ML strongly disagrees with a HOLD signal, upgrade to BUY/SELL
      logger.info(
        `📈 ML Optimization for ${symbol} upgraded HOLD to ` +
        `${optimization.refinedSignal}`,
        {
          original: overallSignal,
          mlSignal: optimization.refinedSignal,
          confidence: optimization.confidenceScore,
          reason: optimization.reasoning,
        }
      );
      overallSignal = optimization.refinedSignal;
      reason = `ML Optimization: ${optimization.reasoning}`;
      // Update the result object for storage consistency
      multiIndicatorResult.overallSignal = optimization.refinedSignal;
      multiIndicatorResult.reason = reason;
    }
  }

  logger.info("Multi-indicator evaluation", {
    allGreen,
    overallSignal,
    interval,
    symbol,
    marketIndexSymbol,
    indicators: {
      priceMovement: indicatorResults.priceMovement.signal,
      momentum: indicatorResults.momentum.signal,
      marketDirection: {
        signal: indicatorResults.marketDirection.signal,
        reason: indicatorResults.marketDirection.reason,
        fastMA: indicatorResults.marketDirection.metadata?.fastMA,
        slowMA: indicatorResults.marketDirection.metadata?.slowMA,
        trendStrength: indicatorResults.marketDirection.metadata?.trendStrength,
      },
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
        optimization,
        currentPrice: marketData.currentPrice,
        config,
        portfolioState,
      };
      await db.doc(`agentic_trading/${signalDocId}`).set(signalDoc);
      logger.info(
        `Alpha agent stored HOLD signal for ${interval} (${symbol})`,
        signalDoc
      );
    } catch (err) {
      logger.warn(`Failed to persist trade signal for ${symbol}`, err);
    }

    return {
      status: "rejected",
      message: "Alpha agent: Multi-indicator analysis shows " +
        `HOLD (${interval}).`,
      reason,
      signal: overallSignal,
      interval,
      multiIndicatorResult,
      optimization,
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
  const assessment = await riskguard.assessTrade(
    proposal, portfolioState, config,
    {
      ...marketData,
      marketIndexCloses: marketIndexData.closes,
    });

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
      optimization,
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
    logger.warn(`Failed to persist trade signal for ${symbol}`, err);
  }

  if (!assessment.approved) {
    return {
      status: "rejected",
      message: "RiskGuard agent rejected the proposal",
      proposal: proposal,
      assessment: assessment,
      interval,
      multiIndicatorResult,
      optimization,
    };
  }

  return {
    status: "approved",
    message: `Alpha agent approved ${overallSignal} proposal (${interval}): ` +
      "All 12 indicators aligned",
    proposal: proposal,
    assessment: assessment,
    interval,
    multiIndicatorResult,
    optimization,
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
