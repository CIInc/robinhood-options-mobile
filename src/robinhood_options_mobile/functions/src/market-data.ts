import { onCall } from "firebase-functions/v2/https";
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
  // Decode symbols if encoded (e.g. ^VIX -> %5EVIX)
  const decodedSymbol = decodeURIComponent(symbol);

  // PCC/CPC symbols from CBOE (CSV) handled specifically for caching
  const pccSymbols = [
    "^PCC", "^CPC", "^CPCE", ".PCC", ".PCCE", ".PCCT", "PCCR",
  ];
  const isPccSymbol = pccSymbols.includes(decodedSymbol);

  let opens: any[] = [];
  let highs: any[] = [];
  let lows: any[] = [];
  let closes: any[] = [];
  let volumes: any[] = [];
  let timestamps: any[] = [];
  let currentPrice: number | null = null;
  let staleFallback: any = null;

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

    // Special handling for PCC symbols from CBOE: They update once daily.
    // If we checked recently (last 4 hours), don't treat as stale even if
    // the data is from a previous day.
    if (isPccSymbol && updated &&
      (now.getTime() - updated < 4 * 60 * 60 * 1000)) {
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
    `charts/${decodedSymbol}` :
    `charts/${decodedSymbol}_${interval}`;
  try {
    const doc = await db.doc(cacheKey).get();
    if (doc.exists) {
      const cacheData = doc.data();
      const chart = cacheData?.chart;
      const isCached = chart && !isCacheStale(cacheData, interval);

      if (chart && chart.indicators?.quote?.[0]?.close && chart.timestamp) {
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

        if (isCached) {
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
            "is stale, will fetch new data and keep stale as fallback");
          staleFallback = {
            opens: [...opens],
            highs: [...highs],
            lows: [...lows],
            closes: [...closes],
            volumes: [...volumes],
            timestamps: [...timestamps],
            currentPrice,
          };
          opens = [];
          highs = [];
          lows = [];
          closes = [];
          volumes = [];
          timestamps = [];
          currentPrice = null;
        }
      }
    }
  } catch (err) {
    logger.warn(`Failed to load cached ${interval} prices for ${symbol}`, err);
  }

  // Handle Put/Call Ratio symbols separately (Primary CBOE, Fallback Fid/Yahoo)
  if (!closes.length && isPccSymbol) {
    try {
      const cboeRes = await fetchFromCBOE(decodedSymbol);
      if (cboeRes && cboeRes.indicators?.quote?.[0]?.close) {
        const resQuote = cboeRes.indicators.quote[0];
        opens = resQuote.open;
        highs = resQuote.high;
        lows = resQuote.low;
        closes = resQuote.close;
        volumes = resQuote.volume;
        timestamps = cboeRes.timestamp;
        currentPrice = cboeRes.meta.regularMarketPrice;
        logger.info(`🌐 CBOE FETCH: Retrieved Put/Call data for ${symbol} ` +
          "from CBOE");
        // Cache CBOE result to prevent frequent refetches
        try {
          await db.doc(cacheKey).set({ chart: cboeRes, updated: Date.now() });
        } catch (err) {
          logger.warn(`Failed to update cached ${interval} ` +
            `from CBOE for ${symbol}`, err);
        }
      }
    } catch (cboeErr) {
      logger.warn(`Failed to fetch Put/Call data from CBOE for ${symbol}`,
        cboeErr);
    }
  }

  // If still no prices, fetch from Fidelity Open API (Primary)
  if (!closes.length) {
    logger.info(`🌐 FRESH FETCH: Attempting Fidelity Open API for ${symbol}`);
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

      const result =
        await fetchFromFidelity(decodedSymbol, interval, dataRange);

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

  // Fallback to Yahoo Finance if Fidelity fails
  if (!closes.length) {
    logger.info(`🌐 FALLBACK: Attempting Yahoo Finance for ${symbol}`);
    try {
      // Ensure we have enough data for MACD (35) and Patterns (30-60)
      const maxPeriod = Math.max(smaPeriodFast, smaPeriodSlow, 60);

      // Determine range based on interval and period
      let dataRange = range;
      if (!dataRange) {
        if (interval === "1d") {
          dataRange = maxPeriod > 250 ? "2y" : "1y";
        } else if (interval === "1h") {
          dataRange = maxPeriod > 30 ? "1mo" : "2y";
        } else if (interval === "30m") {
          dataRange = maxPeriod > 13 ? "5d" : "1mo";
        } else if (interval === "15m") {
          dataRange = maxPeriod > 26 ? "5d" : "1mo";
        }
      }

      // Yahoo Finance uses hyphens for share classes (e.g. BRK.B -> BRK-B)
      const querySymbol = decodedSymbol.replace(/\./g, "-");
      const url = `https://query2.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(querySymbol)}?interval=${interval}&range=${dataRange}`;
      const resp = await fetchWithRetry(url, {
        headers: {
          "Referer": "https://finance.yahoo.com/",
          "Origin": "https://finance.yahoo.com",
        },
      }, 1);
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

  // Last-ditch recovery: Use stale cache if all fresh fetches failed
  if (!closes.length && staleFallback) {
    logger.info(`🌐 RECOVERY: Using stale cache for ${symbol} ` +
      "as total fallback");
    opens = staleFallback.opens;
    highs = staleFallback.highs;
    lows = staleFallback.lows;
    closes = staleFallback.closes;
    volumes = staleFallback.volumes;
    timestamps = staleFallback.timestamps;
    currentPrice = staleFallback.currentPrice;
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
 * Fetches real-time quotes for a list of symbols from Fidelity.
 * @param {string[]} symbols List of stock symbols.
 * @return {Promise<any>} An object mapping symbols to their quote data.
 */
export async function getQuotes(symbols: string[]): Promise<any> {
  if (!symbols || symbols.length === 0) {
    return {};
  }

  // Map symbols to Fidelity format
  const fidSymbols = symbols.map((s) => {
    let fidS = s;
    if (s.startsWith("^")) {
      fidS = "." + s.substring(1);
    }
    // Fidelity specific mappings
    const sUpper = fidS.toUpperCase();
    if (sUpper === ".GSPC") fidS = ".SPX";
    if (sUpper === "^PCC" || sUpper === "^CPCE") fidS = ".PCCE";
    if (sUpper === "^CPC") fidS = ".PCC";
    if (sUpper === "DX-Y.NYB" || sUpper === "DX=F" || sUpper === "DXY" ||
      sUpper === "DX") fidS = ".DXY";
    if (sUpper === "BTC-USD" || sUpper === "BTCUSD") fidS = "BTC/USD";
    if (sUpper === "ETH-USD" || sUpper === "ETHUSD") fidS = "ETH/USD";
    return fidS;
  }).join(",");

  const url = "https://fastquote.fidelity.com/service/quote/json?" +
    `productid=embeddedquotes&symbols=${encodeURIComponent(fidSymbols)}`;

  try {
    const resp = await fetchWithRetry(url);
    if (!resp.ok) {
      throw new Error(`Fidelity Quotes API returned status ${resp.status}`);
    }

    const text = await resp.text();
    // Fidelity returns JSONP-ish wrapped in parentheses: ( { ... } )
    const startIndex = text.indexOf("(");
    const endIndex = text.lastIndexOf(")");
    if (startIndex === -1 || endIndex === -1) {
      throw new Error("Invalid Fidelity Quotes response format");
    }
    const jsonText = text.substring(startIndex + 1, endIndex).trim();
    const data = JSON.parse(jsonText);

    if (data.STATUS?.ERROR_CODE !== "0") {
      logger.warn("Fidelity Quotes API reported an error", {
        status: data.STATUS,
        symbols,
      });
    }

    return data.QUOTES || {};
  } catch (err) {
    logger.error("Failed to fetch quotes from Fidelity", { err, symbols });
    throw err;
  }
}

/**
 * Callable function to fetch quotes.
 */
export const getQuotesCall = onCall(async (request) => {
  const symbols = request.data?.symbols;
  if (!symbols || !Array.isArray(symbols)) {
    return { error: "Expected 'symbols' as an array of strings." };
  }
  return await getQuotes(symbols);
});

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

  // Fidelity uses . or $ prefix for indices instead of Yahoo's ^
  const symUpper = symbol.toUpperCase();
  let fidSymbol = symbol;
  const isIndex = symUpper.startsWith("^") ||
    symUpper.startsWith(".") ||
    symUpper.startsWith("$") ||
    symUpper === "DX-Y.NYB" ||
    symUpper === "DX=F" ||
    symUpper === "BTC-USD" ||
    symUpper === "ETH-USD";

  if (symbol.startsWith("^")) {
    fidSymbol = "." + symbol.substring(1);
  }
  // Fidelity specific mappings
  const fidUpper = fidSymbol.toUpperCase();
  const symUpper2 = symbol.toUpperCase();
  if (fidUpper === ".GSPC") fidSymbol = ".SPX";
  if (symUpper2 === "^PCC" || symUpper2 === "^CPCE" ||
    fidUpper === ".PCC" || fidUpper === ".CPCE") {
    fidSymbol = ".PCCE";
  } else if (symUpper2 === "^CPC" || fidUpper === ".CPC") {
    fidSymbol = ".PCC";
  }
  if (fidUpper === "DX-Y.NYB" || fidUpper === "DX=F" || fidUpper === "DXY" ||
    fidUpper === "DX") fidSymbol = ".DXY";
  if (fidUpper === "BTC-USD" || fidUpper === "BTCUSD") fidSymbol = "BTC/USD";
  if (fidUpper === "ETH-USD" || fidUpper === "ETHUSD") fidSymbol = "ETH/USD";

  // Using the documented endpoint:
  // https://github.com/njfdev/fidelity-api/blob/main/docs/historical-data.md
  const baseFidStr = "https://fastquote.fidelity.com/service/marketdata/" +
    "historical/chart/json?productid=researchexperience&callback=data";

  // For indices that might fail with ".", also consider "$" prefix
  const symbolsToTry = [fidSymbol];
  const fidUpperForTry = fidSymbol.toUpperCase();
  if (isIndex && fidSymbol.startsWith(".")) {
    symbolsToTry.push("$" + fidSymbol.substring(1));
  }
  // Put/Call Ratio specific fallback symbols for Fidelity
  if (fidUpperForTry === ".PCCE" || fidUpperForTry === "$PCCE" ||
    fidUpperForTry === ".PCC" || fidUpperForTry === "$PCC") {
    const list = [
      ".PCC", "$PCC", ".PCCE", "$PCCE", ".PCCT", "$PCCT", ".CPC", "$CPC",
    ];
    list.forEach((s) => {
      if (!symbolsToTry.includes(s)) symbolsToTry.push(s);
    });
  }

  for (const currentFidSymbol of symbolsToTry) {
    let url = `${baseFidStr}&symbols=${encodeURIComponent(currentFidSymbol)}` +
      `&barWidth=${barWidth}`;

    const now = new Date();
    const endDateStr = formatDateForFidelity(now);
    const startDate = new Date();
    if (dataRange === "5y") startDate.setFullYear(now.getFullYear() - 5);
    else if (dataRange === "2y") startDate.setFullYear(now.getFullYear() - 2);
    else if (dataRange === "1y") startDate.setFullYear(now.getFullYear() - 1);
    else if (dataRange === "1mo") startDate.setMonth(now.getMonth() - 1);
    else if (dataRange === "5d") startDate.setDate(now.getDate() - 7);
    else startDate.setFullYear(now.getFullYear() - 1); // Default 1y

    if (barWidth !== "DAILY") {
      // Intraday: map dataRange to numDays (only works for intraday)
      let numDays = 1;
      if (dataRange === "5y" || dataRange === "2y" ||
        dataRange === "1y") numDays = isIndex ? 30 : 120; // Max allowed often
      else if (dataRange === "1mo") numDays = 30;
      else if (dataRange.includes("d")) numDays = parseInt(dataRange) || 1;
      url += `&numDays=${numDays}`;
    } else {
      // Daily: map dataRange to startDate/endDate
      // Use only date for DAILY to avoid API rejection
      const startD = formatDateForFidelity(startDate).split("-")[0];
      const endD = endDateStr.split("-")[0];
      url += `&startDate=${startD}&endDate=${endD}&numDays=1000`;
    }

    try {
      const resp = await fetchWithRetry(url, {
        headers: {
          "Referer": "https://www.fidelity.com/",
          "Origin": "https://www.fidelity.com",
        },
      });
      if (!resp.ok) {
        continue;
      }
      const text = await resp.text();
      // Fidelity returns JSONP wrapped in function call, e.g. data({...})
      const startIndex = text.indexOf("(");
      const endIndex = text.lastIndexOf(")");
      if (startIndex === -1 || endIndex === -1) {
        continue;
      }
      const jsonText = text.substring(startIndex + 1, endIndex).trim();
      const data = JSON.parse(jsonText);

      // Search all possible locations for bars in the response
      const findBars = (obj: any): any[] | null => {
        if (!obj || typeof obj !== "object") return null;

        // Try common array locations
        const possibleArrays = [
          obj.Symbol?.[0]?.BarList?.BarRecord,
          obj.Symbol?.[0]?.Bars?.CB,
          obj.Symbol?.[0]?.Bars?.I,
          obj[currentFidSymbol]?.[0]?.BarList?.BarRecord,
          obj[currentFidSymbol]?.[0]?.Bars?.CB,
          obj[currentFidSymbol]?.[0]?.Bars?.I,
          obj[currentFidSymbol.toUpperCase()]?.[0]?.Bars?.CB,
          obj[currentFidSymbol.toUpperCase()]?.[0]?.Bars?.I,
        ];

        for (const arr of possibleArrays) {
          if (Array.isArray(arr) && arr.length > 0) return arr;
        }

        // Recursive search for any key named BARS or BarRecord
        for (const key of Object.keys(obj)) {
          if (key === "BarRecord" && Array.isArray(obj[key])) return obj[key];
          if (typeof obj[key] === "object") {
            const result = findBars(obj[key]);
            if (result) return result;
          }
        }
        return null;
      };

      const bars = findBars(data);

      if (!bars || !Array.isArray(bars) || !bars.length) {
        continue;
      }

      // Map Fidelity "BarRecord" to Yahoo indicator format
      // op (open), hi (high), lo (low), cl (close),vo/v (volume),
      // ts/lt (timestamp)
      const opes = bars.map((b: any) => parseFloat(b.op));
      const higs = bars.map((b: any) => parseFloat(b.hi));
      const los = bars.map((b: any) => parseFloat(b.lo));
      const clos = bars.map((b: any) => parseFloat(b.cl));
      const vols = bars.map((b: any) => parseInt(b.vo || b.v || 0));
      const tss = bars.map((b: any) => parseFidelityTimestamp(b.ts || b.lt));

      logger.info(`🌐 FIDELITY SUCCESS: Retrieved ${clos.length} bars ` +
        `for ${symbol} using ${currentFidSymbol}`);

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
      logger.warn(`Failed attempt for ${currentFidSymbol}`, err);
    }
  }

  logger.error(`Failed to fetch any Fidelity data for ${symbol} ` +
    `after trying ${symbolsToTry.join(", ")}`);
  return null;
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
 * Fetches Put/Call Ratio symbols from CBOE's public JSON daily statistics.
 * Useful as a final fallback for macro indicators when Yahoo/Fidelity fail.
 * @param {string} symbol The stock symbol (Yahoo style ^PCC, ^CPC, ^CPCE).
 * @return {Promise<any>} A Yahoo-compatible chart result object or null.
 */
async function fetchFromCBOE(symbol: string): Promise<any> {
  const symUpper = (symbol || "").toUpperCase();
  // Mapping symbols to CBOE JSON ratio names
  let ratioName = "EQUITY PUT/CALL RATIO";
  if (symUpper === "^CPC" || symUpper === ".PCC" || symUpper === "PCCR" ||
    symUpper.includes("PCCT")) {
    ratioName = "TOTAL PUT/CALL RATIO";
  } else if (symUpper === "^PCCI" || symUpper === ".PCCI") {
    ratioName = "INDEX PUT/CALL RATIO";
  } else if (symUpper === "^VIX" || symUpper === ".VIX") {
    ratioName = "CBOE VOLATILITY INDEX (VIX) PUT/CALL RATIO";
  }

  // Iterate backwards to find the most recent daily options file (up to 7 days)
  const now = new Date();
  for (let i = 0; i < 7; i++) {
    const d = new Date(now.getTime() - i * 24 * 60 * 60 * 1000);
    const yyyy = d.getFullYear();
    const mm = String(d.getMonth() + 1).padStart(2, "0");
    const dd = String(d.getDate()).padStart(2, "0");
    const dateStr = `${yyyy}-${mm}-${dd}`;
    // CBOE Daily Statistics JSON endpoint (no extension)
    const url = "https://cdn.cboe.com/data/us/options/market_statistics/" +
      `daily/${dateStr}_daily_options`;

    try {
      const resp = await fetchWithRetry(url, {
        headers: {
          "Referer": "https://www.cboe.com/",
        },
      });
      if (!resp.ok) continue;

      const data: any = await resp.json();
      const ratioObj = data.ratios?.find((r: any) =>
        r.name.toUpperCase() === ratioName.toUpperCase());
      if (ratioObj && ratioObj.value) {
        const val = parseFloat(ratioObj.value);
        if (!isNaN(val)) {
          const ts = Math.floor(d.getTime() / 1000);
          logger.info(`🌐 CBOE SUCCESS: Found ${ratioName} ` +
            `for ${dateStr}: ${val}`);
          // Set end of trading day to 16:00 EST for cache verification
          const endOfDay = new Date(d);
          endOfDay.setHours(16, 0, 0, 0);
          return {
            meta: {
              symbol,
              regularMarketPrice: val,
              currentTradingPeriod: {
                regular: {
                  end: Math.floor(endOfDay.getTime() / 1000),
                },
              },
            },
            indicators: {
              quote: [{
                close: [val], open: [val], high: [val], low: [val],
                volume: [0],
              }],
            },
            timestamp: [ts],
          };
        }
      }
    } catch (err) {
      // Continue to try previous day
    }
  }
  return null;
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
    // Robust replacement: swap the date-time separator hyphen for T,
    // then swap slashes for hyphens
    let normalized = ts.split("-").join("T").replace(/\//g, "-");
    if (normalized.length === 10) { // Date only
      normalized += "T00:00:00";
    }
    const d = new Date(normalized);
    return Math.floor(d.getTime() / 1000);
  } catch (err) {
    return 0;
  }
}
