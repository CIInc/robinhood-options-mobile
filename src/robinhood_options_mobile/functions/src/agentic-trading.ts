import { onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as alphaagent from "./alpha-agent";
import { getFirestore } from "firebase-admin/firestore";
import fetch from "node-fetch";

const db = getFirestore();

/**
 * Fetches market data for a given symbol, utilizing a cache in Firestore.
 * @param {string} symbol The stock symbol to fetch data for.
 * @param {number} smaPeriodFast The fast SMA period.
 * @param {number} smaPeriodSlow The slow SMA period.
 * @return {Promise<object>} An object containing the symbol, prices,
 * and current price.
 */
export async function getMarketData(symbol: string,
  smaPeriodFast: number, smaPeriodSlow: number) {
  let prices: any[] = [];
  let currentPrice: number | null = null;

  /**
   * Checks if the cached chart data is stale based on the end of the current
   * trading period.
   * @param {any} chart The chart data object to check.
   * @return {boolean} True if the cache is stale, false otherwise.
   */
  function isCacheStale(chart: any): boolean {
    if (!chart?.meta?.currentTradingPeriod?.regular?.end) {
      return true;
    }
    const endSec = chart.meta.currentTradingPeriod.regular.end;
    const endMs = endSec * 1000;
    const now = new Date();
    const todayStart = Date.UTC(
      now.getUTCFullYear(),
      now.getUTCMonth(),
      now.getUTCDate()
    );
    return endMs < todayStart;
  }

  // Try to load cached prices from Firestore
  try {
    const doc = await db.doc(`agentic_trading/chart_${symbol}`).get();
    if (doc.exists) {
      const chart = doc.data()?.chart;
      const isCached = chart && !isCacheStale(chart);

      if (isCached && chart.indicators?.quote?.[0]?.close && chart.timestamp) {
        const closes = chart.indicators.quote[0].close;
        prices = closes.filter((p: any) => p !== null);
        if (chart && typeof chart?.meta?.regularMarketPrice === "number") {
          currentPrice = chart.meta.regularMarketPrice;
        } else if (Array.isArray(prices) && prices.length > 0) {
          currentPrice = prices[prices.length - 1];
        }
        logger.info(`Loaded cached prices for ${symbol} from Firestore`);
      } else {
        logger.info(`Cached data for ${symbol} is stale, will fetch new data`);
        prices = [];
      }
    }
  } catch (err) {
    logger.warn(`Failed to load cached prices for ${symbol}`, err);
  }

  // If still no prices, fetch from Yahoo Finance
  if (!prices.length) {
    try {
      const maxPeriod = Math.max(smaPeriodFast, smaPeriodSlow);
      const range = maxPeriod > 30 * 24 ? "5y" :
        (maxPeriod > 30 * 12 ? "2y" :
          (maxPeriod > 30 * 6 ? "1y" : "6mo"));
      const url = `https://query1.finance.yahoo.com/v8/finance/chart/${symbol}?interval=1d&range=${range}`;
      const resp = await fetch(url);
      const data: any = await resp.json();
      const result = data?.chart?.result?.[0];
      if (result && Array.isArray(result?.indicators?.quote?.[0]?.close) &&
        Array.isArray(result?.timestamp)) {
        const closes = result.indicators.quote[0].close;
        prices = closes.filter((p: any) => p !== null);
        logger.info(`Fetched ${prices.length} prices for 
          ${symbol} from Yahoo Finance`);
      }
      if (result && typeof result?.meta?.regularMarketPrice === "number") {
        currentPrice = result.meta.regularMarketPrice;
      } else if (Array.isArray(prices) && prices.length > 0) {
        currentPrice = prices[prices.length - 1];
      }
      // Cache prices in Firestore
      try {
        await db.doc(`agentic_trading/chart_${symbol}`)
          .set({ chart: result, updated: Date.now() });
      } catch (err) {
        logger.warn(`Failed to update cached prices for ${symbol}`, err);
      }
    } catch (err) {
      logger.error(`Failed to fetch prices from 
        Yahoo Finance for ${symbol}`, err);
    }
  }

  return {
    symbol,
    prices,
    currentPrice,
  };
}

/**
 * .
 * @param {string} request
 * @return {Promise<object>} An object containing the symbol, prices,
 * and current price.
 */
export async function performTradeProposal(request: any) {
  logger.info("Initiate Trade Proposal called", { structuredData: true });

  const config = {
    smaPeriodFast: request.data.smaPeriodFast || 10,
    smaPeriodSlow: request.data.smaPeriodSlow || 30,
    tradeQuantity: request.data.tradeQuantity || 1,
    maxPositionSize: request.data.maxPositionSize || 100,
    maxPortfolioConcentration: request.data.maxPortfolioConcentration || 0.5,
  };

  logger.info("Agentic Trading Configuration:", config);

  const symbol = request.data.symbol || "SPY";

  const marketData = await getMarketData(symbol,
    config.smaPeriodFast, config.smaPeriodSlow);

  const portfolioState = request.data.portfolioState || {};

  // Delegate to Alpha agent implementation which will call RiskGuard internally
  try {
    const result = await alphaagent.handleAlphaTask(marketData,
      portfolioState, config);
    return result;
  } catch (err) {
    logger.error("Error in initiateTradeProposal", err);
    return { status: "error", message: (err as Error).message || String(err) };
  }
}

export const initiateTradeProposal = onCall(async (request) => {
  return performTradeProposal(request);
});

export const getAgenticTradingConfig = onCall(async () => {
  logger.info("Get Agentic Trading Config called", { structuredData: true });
  // Try reading configuration from Firestore first
  try {
    const doc = await db.doc("agentic_trading/config").get();
    if (doc.exists) {
      const config = doc.data();
      logger.info("Loaded config from Firestore", config);
      return { status: "success", config };
    }
  } catch (err) {
    logger.warn("Failed to read agentic trading config from Firestore", err);
  }

  // Return default configuration as fallback
  const config = {
    smaPeriodFast: 10,
    smaPeriodSlow: 30,
    tradeQuantity: 1,
    maxPositionSize: 100,
    maxPortfolioConcentration: 0.5,
  };
  return { status: "success", config };
});

/**
 * Persist agentic trading configuration to Firestore.
 */
export const setAgenticTradingConfig = onCall(async (request) => {
  const cfg = request.data || {};
  try {
    await db.doc("agentic_trading/config").set(cfg, { merge: true });
    logger.info("Saved agentic trading config to Firestore", cfg);
    return { status: "success", config: cfg };
  } catch (err) {
    logger.error("Failed to save config to Firestore", err);
    return { status: "error", message: (err as Error).message || String(err) };
  }
});
