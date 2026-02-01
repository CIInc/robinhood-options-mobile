import * as logger from "firebase-functions/logger";
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
  let timestamps: any[] = [];
  let currentPrice: number | null = null;

  /**
   * Checks if the cached chart data is stale based on the end of the current
   * trading period and interval type.
   * @param {any} cacheData The full cache document with chart and updated.
   * @param {string} interval The chart interval.
   * @return {boolean} True if the cache is stale, false otherwise.
   */
  function isCacheStale(cacheData: any, interval: string): boolean {
    const chart = cacheData?.chart;
    const updated = cacheData?.updated;

    if (!chart?.meta?.currentTradingPeriod?.regular?.end) {
      return true;
    }

    // If no updated timestamp, treat as stale (legacy cache)
    if (!updated) {
      logger.info("⚠️ Cache missing 'updated' field - treating as stale");
      return true;
    }

    const endSec = chart.meta.currentTradingPeriod.regular.end;
    const endMs = endSec * 1000;
    const now = new Date();

    // For intraday intervals, cache is stale after a shorter period
    if (interval !== "1d") {
      const cacheAge = now.getTime() - updated;
      const maxCacheAge = interval === "15m" ? 15 * 60 * 1000 : // 15 minutes
        interval === "30m" ? 30 * 60 * 1000 : // 30 minutes
          60 * 60 * 1000; // 1 hour for 1h interval
      return cacheAge > maxCacheAge;
    }

    // For daily interval, check if it's from a previous trading day
    // Use America/New_York timezone for consistent market hours
    const estNow = new Date(
      now.toLocaleString("en-US", { timeZone: "America/New_York" })
    );
    const todayStartEST = new Date(
      estNow.getFullYear(),
      estNow.getMonth(),
      estNow.getDate()
    ).getTime();
    return endMs < todayStartEST;
  }

  // Try to load cached prices from Firestore
  const cacheKey = interval === "1d" ?
    `agentic_trading/chart_${symbol}` :
    `agentic_trading/chart_${symbol}_${interval}`;
  try {
    const doc = await db.doc(cacheKey).get();
    if (doc.exists) {
      const cacheData = doc.data();
      const chart = cacheData?.chart;
      const isCached = chart && !isCacheStale(cacheData, interval);

      if (isCached && chart.indicators?.quote?.[0]?.close && chart.timestamp) {
        const opes = chart.indicators.quote[0].open;
        const higs = chart.indicators.quote[0].high;
        const los = chart.indicators.quote[0].low;
        const clos = chart.indicators.quote[0].close;
        const vols = chart.indicators.quote[0].volume || [];
        const tss = chart.timestamp || [];
        opens = opes.filter((p: any) => p !== null);
        highs = higs.filter((p: any) => p !== null);
        lows = los.filter((p: any) => p !== null);
        closes = clos.filter((p: any) => p !== null);
        volumes = vols.filter((v: any) => v !== null);
        timestamps = tss.filter((t: any) => t !== null);
        if (chart && typeof chart?.meta?.regularMarketPrice === "number") {
          currentPrice = chart.meta.regularMarketPrice;
        } else if (Array.isArray(closes) && closes.length > 0) {
          currentPrice = closes[closes.length - 1];
        }
        const lastFew = closes.slice(-5);
        logger.info(`✅ CACHE HIT: Loaded cached ${interval} data ` +
          `for ${symbol}`, {
          count: closes.length,
          lastFivePrices: lastFew,
          currentPrice,
          cacheAge: Date.now() - (cacheData?.updated || 0),
        });
      } else {
        logger.info(`❌ CACHE MISS: Cached ${interval} data for ${symbol} ` +
          "is stale, will fetch new data");
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
      // Ensure we have enough data for MACD (35) and RSI (15)
      const maxPeriod = Math.max(smaPeriodFast, smaPeriodSlow, 35);

      // Determine range based on interval and period
      let dataRange = range;
      if (!dataRange) {
        if (interval === "1d") {
          dataRange = maxPeriod > 250 ? "2y" : "1y";
        } else if (interval === "1h") {
          dataRange = maxPeriod > 30 ? "1mo" : "5d";
        } else if (interval === "30m") {
          dataRange = maxPeriod > 13 ? "5d" : "1d";
        } else if (interval === "15m") {
          dataRange = maxPeriod > 26 ? "5d" : "1d";
        }
      }

      // Yahoo Finance uses hyphens for share classes (e.g. BRK.B -> BRK-B)
      const querySymbol = symbol.replace(/\./g, "-");
      const url = `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(querySymbol)}?interval=${interval}&range=${dataRange}`;
      const resp = await fetch(url);
      const data: any = await resp.json();
      const result = data?.chart?.result?.[0];
      // Fix for Firebase which does not support arrays inside arrays
      if (result) {
        delete result.meta?.tradingPeriods;
      }
      if (result && Array.isArray(result?.indicators?.quote?.[0]?.close) &&
        Array.isArray(result?.timestamp)) {
        const opes = result.indicators.quote[0].open;
        const higs = result.indicators.quote[0].high;
        const los = result.indicators.quote[0].low;
        const clos = result.indicators.quote[0].close;
        const vols = result.indicators.quote[0].volume || [];
        const tss = result.timestamp || [];
        opens = opes.filter((p: any) => p !== null);
        highs = higs.filter((p: any) => p !== null);
        lows = los.filter((p: any) => p !== null);
        closes = clos.filter((p: any) => p !== null);
        volumes = vols.filter((v: any) => v !== null);
        timestamps = tss.filter((t: any) => t !== null);
        logger.info(`🌐 FRESH FETCH: Retrieved ${closes.length} ${interval} ` +
          `prices and ${volumes.length} volumes for ${symbol} from ` +
          `Yahoo Finance ${url}`);
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
    timestamps,
    currentPrice,
  };
}
