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
 * @param {string} interval The chart interval (1d, 1h, 30m, 15m, etc.)
 * @param {string} range The time range (1y, 5d, 1mo, etc.)
 * @return {Promise<object>} An object containing the symbol, prices,
 * volumes, and current price.
 */
export async function getMarketData(symbol: string,
  smaPeriodFast: number, smaPeriodSlow: number,
  interval = "1d", range?: string) {
  let opens: any[] = [];
  let highs: any[] = [];
  let lows: any[] = [];
  let closes: any[] = [];
  let volumes: any[] = [];
  let currentPrice: number | null = null;

  /**
   * Checks if the cached chart data is stale based on the end of the current
   * trading period and interval type.
   * @param {any} chart The chart data object to check.
   * @param {string} interval The chart interval.
   * @return {boolean} True if the cache is stale, false otherwise.
   */
  function isCacheStale(chart: any, interval: string): boolean {
    if (!chart?.meta?.currentTradingPeriod?.regular?.end) {
      return true;
    }
    const endSec = chart.meta.currentTradingPeriod.regular.end;
    const endMs = endSec * 1000;
    const now = new Date();

    // For intraday intervals, cache is stale after a shorter period
    if (interval !== "1d") {
      const cacheAge = now.getTime() - (chart.updated || 0);
      const maxCacheAge = interval === "15m" ? 15 * 60 * 1000 : // 15 minutes
        interval === "30m" ? 30 * 60 * 1000 : // 30 minutes
          60 * 60 * 1000; // 1 hour for 1h interval
      return cacheAge > maxCacheAge;
    }

    // For daily interval, check if it's from a previous trading day
    const todayStart = Date.UTC(
      now.getUTCFullYear(),
      now.getUTCMonth(),
      now.getUTCDate()
    );
    return endMs < todayStart;
  }

  // Try to load cached prices from Firestore
  const cacheKey = interval === "1d" ?
    `agentic_trading/chart_${symbol}` :
    `agentic_trading/chart_${symbol}_${interval}`;
  try {
    const doc = await db.doc(cacheKey).get();
    if (doc.exists) {
      const chart = doc.data()?.chart;
      const isCached = chart && !isCacheStale(chart, interval);

      if (isCached && chart.indicators?.quote?.[0]?.close && chart.timestamp) {
        const opes = chart.indicators.quote[0].open;
        const higs = chart.indicators.quote[0].high;
        const los = chart.indicators.quote[0].low;
        const clos = chart.indicators.quote[0].close;
        const vols = chart.indicators.quote[0].volume || [];
        opens = opes.filter((p: any) => p !== null);
        highs = higs.filter((p: any) => p !== null);
        lows = los.filter((p: any) => p !== null);
        closes = clos.filter((p: any) => p !== null);
        volumes = vols.filter((v: any) => v !== null);
        if (chart && typeof chart?.meta?.regularMarketPrice === "number") {
          currentPrice = chart.meta.regularMarketPrice;
        } else if (Array.isArray(closes) && closes.length > 0) {
          currentPrice = closes[closes.length - 1];
        }
        logger.info(`Loaded cached ${interval} prices and volumes ` +
          `for ${symbol} from Firestore`);
      } else {
        logger.info(`Cached ${interval} data for ${symbol} is stale, ` +
          "will fetch new data");
        opens = [];
        highs = [];
        lows = [];
        closes = [];
        volumes = [];
      }
    }
  } catch (err) {
    logger.warn(`Failed to load cached ${interval} prices for ${symbol}`, err);
  }

  // If still no prices, fetch from Yahoo Finance
  if (!closes.length) {
    try {
      const maxPeriod = Math.max(smaPeriodFast, smaPeriodSlow);

      // Determine range based on interval and period
      let dataRange = range;
      if (!dataRange) {
        if (interval === "1d") {
          dataRange = maxPeriod > 30 * 24 ? "5y" :
            (maxPeriod > 30 * 12 ? "2y" : "1y");
        } else if (interval === "1h") {
          // For hourly, we can get up to 730 hours (1mo)
          dataRange = maxPeriod > 168 ? "1mo" : "5d";
        } else if (interval === "30m") {
          // For 30m, we can get up to 60 days
          dataRange = maxPeriod > 48 ? "5d" : "1d";
        } else if (interval === "15m") {
          // For 15m, we can get up to 60 days
          dataRange = maxPeriod > 96 ? "5d" : "1d";
        }
      }

      const url = `https://query1.finance.yahoo.com/v8/finance/chart/${symbol}?interval=${interval}&range=${dataRange}`;
      const resp = await fetch(url);
      const data: any = await resp.json();
      const result = data?.chart?.result?.[0];
      // Fix for Firebase which does not support arrays inside arrays
      // INVALID_ARGUMENT: Property chart contains an invalid nested entity
      delete result.meta?.tradingPeriods;
      if (result && Array.isArray(result?.indicators?.quote?.[0]?.close) &&
        Array.isArray(result?.timestamp)) {
        const opes = result.indicators.quote[0].open;
        const higs = result.indicators.quote[0].high;
        const los = result.indicators.quote[0].low;
        const clos = result.indicators.quote[0].close;
        const vols = result.indicators.quote[0].volume || [];
        opens = opes.filter((p: any) => p !== null);
        highs = higs.filter((p: any) => p !== null);
        lows = los.filter((p: any) => p !== null);
        closes = clos.filter((p: any) => p !== null);
        volumes = vols.filter((v: any) => v !== null);
        logger.info(`Fetched ${closes.length} ${interval} prices and ` +
          `${volumes.length} volumes for ${symbol} from Yahoo Finance ${url}`);
      }
      if (result && typeof result?.meta?.regularMarketPrice === "number") {
        currentPrice = result.meta.regularMarketPrice;
      } else if (Array.isArray(closes) && closes.length > 0) {
        currentPrice = closes[closes.length - 1];
      }
      // Cache prices and volumes in Firestore
      try {
        await db.doc(cacheKey)
          .set({ chart: result, updated: Date.now() });
      } catch (err) {
        logger.warn(`Failed to update cached ${interval} data for ${symbol}`,
          err);
      }
    } catch (err) {
      logger.error(`Failed to fetch ${interval} data from ` +
        `Yahoo Finance for ${symbol}`, err);
    }
  }

  return {
    symbol,
    opens,
    highs,
    lows,
    closes,
    volumes,
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
  const interval = request.data.interval || "1d";
  const range = request.data.range;

  const marketData = await getMarketData(symbol,
    config.smaPeriodFast, config.smaPeriodSlow, interval, range);

  const portfolioState = request.data.portfolioState || {};

  // Delegate to Alpha agent implementation which will call RiskGuard internally
  try {
    const result = await alphaagent.handleAlphaTask(marketData,
      portfolioState, config, interval);
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
    rsiPeriod: 14,
    marketIndexSymbol: "SPY",
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
