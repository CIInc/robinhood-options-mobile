import * as logger from "firebase-functions/logger";
import { getFirestore } from "firebase-admin/firestore";
import { fetchWithRetry } from "./utils";

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

    // Fix for weekend loop: If it's Saturday (6) or Sunday (0) and we already
    // updated today, don't refetch
    const dayOfWeek = estNow.getDay();
    const isWeekend = dayOfWeek === 0 || dayOfWeek === 6;
    if (isWeekend && updated && updated > todayStartEST) {
      return false;
    }

    const isStale = endMs < todayStartEST;
    if (isStale) {
      logger.info(`🔍 Cache Stale Detail for ${symbol}:`, {
        symbol,
        interval,
        endMs,
        todayStartEST,
        updated,
        isWeekend,
        cacheAgeMs: updated ? Date.now() - updated : null,
        endVsStart: endMs - todayStartEST,
      });
    }
    return isStale;
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
      const url = `https://query2.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(querySymbol)}?interval=${interval}&range=${dataRange}`;
      const resp = await fetchWithRetry(url, {
        headers: {
          "Referer": "https://finance.yahoo.com/",
          "Origin": "https://finance.yahoo.com",
        },
      });
      const data: any = await resp.json();
      const result = data?.chart?.result?.[0];

      if (!result) {
        logger.warn(`⚠️ No result from Yahoo Finance for ${symbol}`, {
          url,
          status: resp.status,
          error: data?.chart?.error,
        });
      }

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
      // Cache prices and volumes in Firestore if result is valid
      if (result) {
        try {
          await db.doc(cacheKey)
            .set({ chart: result, updated: Date.now() });
        } catch (err) {
          logger.warn(`Failed to update cached ${interval} data for ${symbol}`,
            err);
        }
      } else {
        logger.warn(`⚠️ Skipping cache update for ${symbol} (${interval}): ` +
          "Yahoo Finance result is undefined or invalid", {
          symbol,
          interval,
          url,
          responseStatus: resp.status,
          hasData: !!data,
          error: data?.chart?.error,
        });
      }
    } catch (err) {
      logger.error(`Failed to fetch ${interval} data from ` +
        `Yahoo Finance for ${symbol}`, err);
    }
  }

  // Fallback to Fidelity Open API if Yahoo is rate limited or no results
  if (!closes.length) {
    logger.info(`🌐 FALLBACK: Attempting Fidelity Open API for ${symbol}`);
    try {
      // Ensure we have enough data for MACD (35) and RSI (15)
      const maxPeriod = Math.max(smaPeriodFast, smaPeriodSlow, 35);
      let dataRange = range || "1y";
      if (!range) {
        if (interval === "1d") {
          dataRange = maxPeriod > 250 ? "2y" : "1y";
        } else if (interval === "1h") {
          dataRange = maxPeriod > 30 ? "1mo" : "5d";
        } else {
          dataRange = "5d";
        }
      }

      const result = await fetchFromFidelity(symbol, interval, dataRange);

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
        logger.info(`🌐 FIDELITY FETCH: Retrieved ${closes.length} ` +
          `${interval} prices for ${symbol} from Fidelity`);
      }
      if (result && typeof result?.meta?.regularMarketPrice === "number") {
        currentPrice = result.meta.regularMarketPrice;
      } else if (Array.isArray(closes) && closes.length > 0) {
        currentPrice = closes[closes.length - 1];
      }
      // Cache Fidelity data too for resilience
      if (result) {
        try {
          await db.doc(cacheKey).set({ chart: result, updated: Date.now() });
        } catch (err) {
          logger.warn(`Failed to update cached ${interval} ` +
            `from Fidelity for ${symbol}`, err);
        }
      }
    } catch (fidErr) {
      logger.error(`Failed to fetch ${interval} data from ` +
        `Fidelity for ${symbol}`, fidErr);
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

/**
 * Fetches market data for a given symbol from Fidelity Open API.
 * @param {string} symbol The stock symbol to fetch data for.
 * @param {string} interval The chart interval (1d, 1h, 30m, 15m, etc.)
 * @param {string} dataRange The time range (1y, 5d, 1mo, etc.)
 * @return {Promise<any>} A Yahoo-compatible chart result object,
 * or null if no data found.
 */
async function fetchFromFidelity(
  symbol: string, interval: string, dataRange: string
): Promise<any> {
  // Map interval to barWidth
  let barWidth = "DAILY";
  if (interval === "1h") barWidth = "60";
  else if (interval === "30m") barWidth = "30";
  else if (interval === "15m") barWidth = "15";
  else if (interval === "5m") barWidth = "5";
  else if (interval === "1m") barWidth = "1";

  // Using the documented endpoint:
  // https://github.com/njfdev/fidelity-api/blob/main/docs/historical-data.md
  const baseFidStr = "https://fastquote.fidelity.com/service/marketdata/" +
    "historical/chart/json?productid=researchexperience&callback=data";
  let url = `${baseFidStr}&symbols=${encodeURIComponent(symbol)}` +
    `&barWidth=${barWidth}`;

  if (barWidth !== "DAILY") {
    // Intraday: map dataRange to numDays (only works for intraday)
    let numDays = 1;
    if (dataRange === "5y" || dataRange === "2y" ||
      dataRange === "1y") numDays = 120; // Max allowed often
    else if (dataRange === "1mo") numDays = 30;
    else if (dataRange.includes("d")) numDays = parseInt(dataRange) || 1;
    url += `&numDays=${numDays}`;
  } else {
    // Daily: map dataRange to startDate/endDate
    const now = new Date();
    const endDateStr = formatDateForFidelity(now);
    const startDate = new Date();
    if (dataRange === "5y") startDate.setFullYear(now.getFullYear() - 5);
    else if (dataRange === "2y") startDate.setFullYear(now.getFullYear() - 2);
    else if (dataRange === "1y") startDate.setFullYear(now.getFullYear() - 1);
    else if (dataRange === "1mo") startDate.setMonth(now.getMonth() - 1);
    else if (dataRange === "5d") startDate.setDate(now.getDate() - 7);
    else startDate.setFullYear(now.getFullYear() - 1); // Default 1y
    url += `&startDate=${formatDateForFidelity(startDate)}` +
      `&endDate=${endDateStr}`;
  }

  try {
    const resp = await fetchWithRetry(url);
    if (!resp.ok) {
      throw new Error(`Fidelity API returned status ${resp.status}`);
    }
    const text = await resp.text();
    // Fidelity returns JSONP wrapped in function call, e.g. data({...})
    // Strip leading "data(" and trailing ")", trim whitespace
    const startIndex = text.indexOf("(");
    const endIndex = text.lastIndexOf(")");
    if (startIndex === -1 || endIndex === -1) {
      throw new Error("Invalid Fidelity JSONP response format");
    }
    const jsonText = text.substring(startIndex + 1, endIndex).trim();
    const data = JSON.parse(jsonText);

    // From community code, bars are in SYMBOL[0].BARS.CB or SYMBOL[0].BARS.I
    // Also handle Symbol[0].BarList.BarRecord from research API
    const symbolData = data.Symbol && data.Symbol[0];
    const bars = symbolData?.BarList?.BarRecord;

    if (!bars || !Array.isArray(bars) || !bars.length) {
      logger.warn(`No bars found in Fidelity for ${symbol}`, {
        url,
        responseKeys: Object.keys(data),
        symbolDataKeys: symbolData ? Object.keys(symbolData) : "no-symbolData",
      });
      return null;
    }

    // Map Fidelity "BarRecord" to Yahoo indicator format
    // op (open), hi (high), lo (low), cl (close),vo/v (volume),
    // ts/lt (timestamp)
    const opes = bars.map((b: any) => parseFloat(b.op));
    const higs = bars.map((b: any) => parseFloat(b.hi));
    const los = bars.map((b: any) => parseFloat(b.lo));
    const clos = bars.map((b: any) => parseFloat(b.cl));
    const vols = bars.map((b: any) => parseInt(b.vo || b.v));
    const tss = bars.map((b: any) => parseFidelityTimestamp(b.ts || b.lt));

    return {
      meta: {
        symbol: symbol,
        regularMarketPrice: clos[clos.length - 1],
        currentTradingPeriod: {
          regular: {
            end: Math.floor(Date.now() / 1000), // Stubs end today
          },
        },
      },
      indicators: {
        quote: [{
          open: opes,
          high: higs,
          low: los,
          close: clos,
          volume: vols,
        }],
      },
      timestamp: tss,
    };
  } catch (err) {
    logger.error(`Failed to fetch from Fidelity for ${symbol}:`, err);
    return null;
  }
}

/**
 * Formats a Date object to Fidelity's string format:
 * yyyy/MM/dd-HH:mm:ss
 * @param {Date} date The date to format.
 * @return {string} Fidelity formatted date.
 */
function formatDateForFidelity(date: Date): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  const hh = String(date.getHours()).padStart(2, "0");
  const mm = String(date.getMinutes()).padStart(2, "0");
  const ss = String(date.getSeconds()).padStart(2, "0");
  return `${y}/${m}/${d}-${hh}:${mm}:${ss}`;
}

/**
 * Parses Fidelity timestamp (yyyy/MM/dd-HH:mm:ss) into seconds since epoch.
 * @param {string} ts Fidelity timestamp string.
 * @return {number} Seconds since epoch.
 */
function parseFidelityTimestamp(ts: string): number {
  if (!ts) return 0;
  try {
    // Fidelity formats like "2023/03/02-09:30:00" or "2023/03/02"
    // Convert to ISO-ish: "2023-03-02T09:30:00"
    let normalized = ts.replace(/\//g, "-").replace("-", "T");
    if (normalized.length === 10) { // Date only
      normalized += "T00:00:00";
    }
    const d = new Date(normalized);
    return Math.floor(d.getTime() / 1000);
  } catch (err) {
    return 0;
  }
}
