import { getFirestore, Timestamp } from "firebase-admin/firestore";
// import { logger } from "firebase-functions/logger";

// Constants for thresholds and configuration
const CONFIG = {
  MIN_VOLUME: 50,
  BATCH_SIZE: 1, // 5,
  PREMIUM_THRESHOLDS: {
    BLOCK: 100000,
    DARK_POOL: 2000000,
    WHALE: 1000000,
    GOLDEN_SWEEP: 1000000,
  },
  VOL_OI_RATIOS: {
    MEGA: 10,
    EXPLOSION: 5,
    HIGH: 1.5,
  },
  IV_THRESHOLDS: {
    EXTREME: 2.5,
    HIGH: 1.0,
    LOW: 0.2,
  },
  DTE_THRESHOLDS: {
    ZERO: 1,
    WEEKLY: 7,
    LEAPS: 365,
  },
  DETAILS: {
    ASK_SIDE: "Ask Side",
    BID_SIDE: "Bid Side",
    ABOVE_ASK: "Above Ask",
    BELOW_BID: "Below Bid",
    MID_MARKET: "Mid Market",
    LARGE_BLOCK: "Large Block / Dark Pool",
  },
  SENTIMENT: {
    BULLISH: "bullish",
    BEARISH: "bearish",
    NEUTRAL: "neutral",
  },
};

export interface OptionFlowItem {
  symbol: string;
  time: string;
  strike: number;
  expirationDate: string;
  type: "Call" | "Put";
  spotPrice: number;
  premium: number;
  volume: number;
  openInterest: number;
  impliedVolatility: number;
  flowType: string;
  sentiment: string;
  details: string;
  flags: string[];
  reasons: string[];
  isUnusual: boolean;
  score: number;
  marketCap?: number;
  sector?: string;
  changePercent?: number;
  lastPrice?: number;
  bid?: number;
  ask?: number;
}

interface YahooQuote {
  marketCap?: number;
  sector?: string;
  earningsTimestamp?: number;
  regularMarketChangePercent?: number;
  regularMarketPrice?: number;
  [key: string]: unknown;
}

interface YahooOption {
  percentChange?: number;
  change?: number;
  lastPrice?: number;
  volume?: number;
  openInterest?: number;
  strike: number;
  expiration?: number | Date;
  contractSymbol?: string;
  lastTradeDate?: number | Date;
  impliedVolatility?: number;
  bid?: number;
  ask?: number;
  currency?: string;
  inTheMoney?: boolean;
}

interface YahooOptionsResult {
  expirationDates?: Date[];
  hasMiniOptions?: boolean;
  quote?: YahooQuote;
  options?: {
    calls?: YahooOption[];
    puts?: YahooOption[];
    expirationDate?: Date;
    hasMiniOptions?: boolean;
  }[];
  strikes?: number[];
  underlyingSymbol?: string;
  lastUpdated?: number;
}

// Simple in-memory cache with LRU eviction
const CACHE_CONFIG = {
  TTL: 30 * 24 * 60 * 60 * 1000, // 30 day cache for Firestore
  COLLECTION: "yahoo_options_results",
};

// eslint-disable-next-line @typescript-eslint/no-explicit-any
const convertTimestampsToDates = (obj: any): any => {
  if (obj === null || obj === undefined) return obj;
  if (obj instanceof Timestamp) return obj.toDate();
  if (Array.isArray(obj)) return obj.map(convertTimestampsToDates);
  if (typeof obj === "object") {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const newObj: any = {};
    for (const key in obj) {
      if (Object.prototype.hasOwnProperty.call(obj, key)) {
        newObj[key] = convertTimestampsToDates(obj[key]);
      }
    }
    return newObj;
  }
  return obj;
};

const getYahooOptionsResult = async (
  symbol: string
): Promise<YahooOptionsResult | null> => {
  try {
    const db = getFirestore();
    const docRef = db.collection(CACHE_CONFIG.COLLECTION).doc(symbol);
    console.log(
      `Fetching cached options for ${symbol} from ${CACHE_CONFIG.COLLECTION}`
    );
    const doc = await docRef.get();

    if (!doc.exists) {
      console.log(`No cached options found for ${symbol}`);
      return null;
    }

    const data = doc.data();
    if (!data) return null;

    // if (Date.now() - (data.lastUpdated || 0) > CACHE_CONFIG.TTL) {
    //   console.log(`Cached options for ${symbol} expired`);
    //   return null;
    // }

    const result = convertTimestampsToDates(data) as YahooOptionsResult;

    // Fetch expirations from subcollection
    const expirationsSnapshot = await docRef.collection("expirations").get();
    if (!expirationsSnapshot.empty) {
      const options = expirationsSnapshot.docs.map((d) =>
        convertTimestampsToDates(d.data())
      );
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      result.options = options as any;
    }

    console.log(`Returning cached options for ${symbol}`);
    return result;
  } catch (e) {
    console.error(`Error reading from Firestore for symbol ${symbol}:`, e);
    return null;
  }
};

const saveYahooOptionsResult = async (
  symbol: string,
  data: YahooOptionsResult
): Promise<void> => {
  try {
    console.log(`Saving options to Firestore for ${symbol}`);
    const db = getFirestore();
    const docRef = db.collection(CACHE_CONFIG.COLLECTION).doc(symbol);

    // Separate options from metadata
    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    const { options, ...metadata } = data;

    await docRef.set({
      ...metadata,
      lastUpdated: Date.now(),
    });

    if (options && options.length > 0) {
      const batch = db.batch();
      const expirationsRef = docRef.collection("expirations");

      for (const opt of options) {
        if (opt.expirationDate) {
          const dateId = Math.floor(
            opt.expirationDate.getTime() / 1000
          ).toString();
          const expDoc = expirationsRef.doc(dateId);
          batch.set(expDoc, opt);
        }
      }
      await batch.commit();
    }

    console.log(`Successfully saved options for ${symbol}`);
  } catch (e) {
    console.error(`Error writing to Firestore for symbol ${symbol}:`, e);
  }
};

let yahooCrumb: string | null = null;
let yahooCookie: string | null = null;

const fetchCrumb = async (): Promise<void> => {
  if (yahooCrumb && yahooCookie) return;

  try {
    // 1. Get cookie
    const cookieResponse = await fetch("https://fc.yahoo.com", {
      headers: {
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " +
          "AppleWebKit/537.36 (KHTML, like Gecko) " +
          "Chrome/120.0.0.0 Safari/537.36",
      },
    });

    const setCookie = cookieResponse.headers.get("set-cookie");
    if (!setCookie) throw new Error("No set-cookie header");
    yahooCookie = setCookie.split(";")[0];

    // 2. Get crumb
    const crumbResponse = await fetch(
      "https://query1.finance.yahoo.com/v1/test/getcrumb",
      {
        headers: {
          "Cookie": yahooCookie,
          "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " +
            "AppleWebKit/537.36 (KHTML, like Gecko) " +
            "Chrome/120.0.0.0 Safari/537.36",
        },
      }
    );

    if (!crumbResponse.ok) {
      throw new Error(`Failed to get crumb ${crumbResponse.statusText}`);
    }
    yahooCrumb = await crumbResponse.text();
  } catch (e) {
    console.error("Error fetching Yahoo crumb:", e);
  }
};

const fetchYahooOptions = async (
  symbol: string,
  date?: Date
): Promise<YahooOptionsResult> => {
  console.log(
    `Fetching options from Yahoo for ${symbol}${date ? ` (date: ${date})` : ""}`
  );
  await fetchCrumb();

  let url = `https://query2.finance.yahoo.com/v7/finance/options/${symbol}`;
  if (yahooCrumb) {
    url += `?crumb=${yahooCrumb}`;
  }
  if (date) {
    url += `${yahooCrumb ? "&" : "?"}date=${Math.floor(date.getTime() / 1000)}`;
  }
  const headers: Record<string, string> = {
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " +
      "AppleWebKit/537.36 (KHTML, like Gecko) " +
      "Chrome/120.0.0.0 Safari/537.36",
  };

  if (yahooCookie) {
    headers["Cookie"] = yahooCookie;
  }

  const response = await fetch(url, {
    headers,
  });
  if (!response.ok) {
    throw new Error(
      `Failed to fetch options for ${symbol}: ${response.statusText}`
    );
  }
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const data = await response.json() as any;
  const result = data.optionChain.result[0];

  console.log(`Successfully fetched options for ${symbol}`);

  return {
    expirationDates: result.expirationDates?.map(
      (ts: number) => new Date(ts * 1000)
    ) || [],
    hasMiniOptions: result.hasMiniOptions,
    quote: result.quote,
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    options: result.options?.map((opt: any) => ({
      expirationDate: opt.expirationDate ?
        new Date(opt.expirationDate * 1000) : undefined,
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      calls: opt.calls?.map((c: any) => ({
        ...c,
        expiration: c.expiration ? new Date(c.expiration * 1000) : undefined,
        lastTradeDate: c.lastTradeDate ?
          new Date(c.lastTradeDate * 1000) : undefined,
      })) || [],
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      puts: opt.puts?.map((p: any) => ({
        ...p,
        expiration: p.expiration ? new Date(p.expiration * 1000) : undefined,
        lastTradeDate: p.lastTradeDate ?
          new Date(p.lastTradeDate * 1000) : undefined,
      })) || [],
    })) || [],
    strikes: result.strikes || [],
    underlyingSymbol: result.underlyingSymbol,
    lastUpdated: Date.now(),
  };
};

// eslint-disable-next-line @typescript-eslint/no-explicit-any
const fetchYahooQuoteSummary = async (symbol: string): Promise<any> => {
  await fetchCrumb();

  let url = `https://query1.finance.yahoo.com/v10/finance/quoteSummary/${symbol}?modules=assetProfile`;
  if (yahooCrumb) {
    url += `&crumb=${yahooCrumb}`;
  }

  const headers: Record<string, string> = {
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " +
      "AppleWebKit/537.36 (KHTML, like Gecko) " +
      "Chrome/120.0.0.0 Safari/537.36",
  };

  if (yahooCookie) {
    headers["Cookie"] = yahooCookie;
  }

  const response = await fetch(url, {
    headers,
  });
  if (!response.ok) {
    throw new Error(
      `Failed to fetch quote summary for ${symbol}: ${response.statusText}`
    );
  }
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const data = await response.json() as any;
  return data.quoteSummary.result[0];
};

/**
 * Fetches and analyzes options flow for a list of symbols.
 * @param {string[]} symbols List of stock symbols to fetch.
 * @param {string} [expirationFilter] Optional filter for expiration dates.
 * @return {Promise<OptionFlowItem[]>} A list of analyzed option flow items.
 */
export const fetchOptionsFlowForSymbols = async (
  symbols: string[],
  expirationFilter?: string
): Promise<OptionFlowItem[]> => {
  const items: OptionFlowItem[] = [];

  // Process symbols in batches to respect rate limits and manage concurrency
  for (let i = 0; i < symbols.length; i += CONFIG.BATCH_SIZE) {
    const batch = symbols.slice(i, i + CONFIG.BATCH_SIZE);
    const batchResults = await Promise.allSettled(
      batch.map((s) => fetchForSymbol(s, expirationFilter))
    );

    batchResults.forEach((result) => {
      if (result.status === "fulfilled" && result.value) {
        items.push(...result.value);
      } else if (result.status === "rejected") {
        console.error("Error fetching batch item:", result.reason);
        throw result.reason;
      }
    });
  }

  // Sort by time descending (newest first)
  items.sort((a, b) => {
    return new Date(b.time).getTime() - new Date(a.time).getTime();
  });

  return items;
};

const fetchForSymbol = async (
  symbol: string,
  expirationFilter?: string
): Promise<OptionFlowItem[]> => {
  console.log(`Processing symbol: ${symbol}`);
  // Try Firestore cache (Document Store)
  let cachedResult = await getYahooOptionsResult(symbol);

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  let quoteInfo: any = {};

  try {
    if (!cachedResult) {
      console.log(`Cache miss for ${symbol}, fetching fresh data`);
      // Initial fetch if no cache
      const initialResult = await fetchYahooOptions(symbol);
      cachedResult = initialResult;
      // {
      //   expirationDates: initialResult.expirationDates,
      //   hasMiniOptions: initialResult.hasMiniOptions,
      //   quote: initialResult.quote,
      // // initialResult usually contains options for the first expiration date
      //   options: initialResult.options || [],
      //   strikes: initialResult.strikes,
      //   underlyingSymbol: initialResult.underlyingSymbol,
      //   lastUpdated: Date.now(),
      // };
    }

    // Now we have a cachedResult
    const expirationDates = cachedResult.expirationDates || [];
    const quote = cachedResult.quote;

    if (!quote) return [];

    const sector = await ensureSector(symbol, quote);
    quoteInfo = {
      changePercent: quote.regularMarketChangePercent || 0,
      earningsTimestamp: quote.earningsTimestamp,
      marketCap: quote.marketCap,
      sector: sector,
    };

    const targetDates = filterExpirationDates(
      expirationDates,
      expirationFilter
    );

    // Identify missing dates
    const existingOptions = cachedResult.options || [];
    const missingDates = targetDates.filter(
      (date) => !isDateInOptions(date, existingOptions)
    );

    if (missingDates.length > 0) {
      // Fetch missing dates
      // We limit to 4 to avoid rate limits
      const datesToFetch = missingDates.slice(0, 1);

      if (datesToFetch.length > 0) {
        const fetchedResults = await Promise.all(
          datesToFetch.map((date) => fetchYahooOptions(symbol, date))
        );

        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const newOptions = fetchedResults
          .flatMap((r) => r.options || []) as any;

        // Merge
        cachedResult.options = [...existingOptions, ...newOptions];
        cachedResult.lastUpdated = Date.now();

        await saveYahooOptionsResult(symbol, cachedResult);
      }
    }
  } catch (e) {
    console.error(`Failed to fetch/update options for ${symbol}`, e);
    throw e;
    // if (
    //   !cachedResult ||
    //   !cachedResult.quote ||
    //   !cachedResult.expirationDates?.every((d) =>
    //     cachedResult?.options?.findIndex((o) =>
    //       o.expirationDate === d) ?? -1 >= 0)) {
    return [];
    // }
  }

  // Process results
  const items = processOptionChains(symbol, [cachedResult], quoteInfo);

  // Apply expiration filter to items if needed
  if (expirationFilter) {
    const now = new Date();
    return items.filter((item) => {
      const itemDate = new Date(item.expirationDate);
      const days = getDaysDifference(now, itemDate);
      if (expirationFilter === "0-7") return days >= -1 && days <= 7;
      if (expirationFilter === "8-30") return days > 7 && days <= 30;
      if (expirationFilter === "30+") return days > 30;
      return true;
    });
  }

  return items;
};

const ensureSector = async (
  symbol: string,
  quote: YahooQuote
): Promise<string | undefined> => {
  if (quote.sector) return quote.sector;

  const db = getFirestore();
  const summaryRef = db.collection("yahoo_quote_summaries").doc(symbol);

  try {
    const doc = await summaryRef.get();
    if (doc.exists) {
      const data = doc.data();
      if (
        data
      ) {
        return data.assetProfile?.sector;
      }
    }

    const summary = await fetchYahooQuoteSummary(symbol);
    const sector = summary.assetProfile?.sector;

    await summaryRef.set({
      ...summary,
      lastUpdated: Date.now(),
    });

    return sector;
  } catch (e) {
    console.warn(`Failed to fetch sector for ${symbol}:`, e);
    return undefined;
  }
};

const isDateInOptions = (
  date: Date,
  options: {
    calls?: YahooOption[];
    puts?: YahooOption[];
    expirationDate?: Date;
  }[]
): boolean => {
  return options.some((opt) => {
    if (opt.expirationDate) {
      return getDaysDifference(opt.expirationDate, date) === 0;
    }
    const c = opt.calls?.[0];
    const p = opt.puts?.[0];
    const exp = c?.expiration || p?.expiration;
    if (!exp) return false;
    return getDaysDifference(new Date(exp), date) === 0;
  });
};

const filterExpirationDates = (dates: Date[], filter?: string): Date[] => {
  if (!filter) return dates;
  const now = new Date();
  return dates.filter((date) => {
    const days = getDaysDifference(now, date);
    if (filter === "0-7") return days >= -1 && days <= 7;
    if (filter === "8-30") return days > 7 && days <= 30;
    if (filter === "30+") return days > 30;
    return true;
  });
};


const processOptionChains = (
  symbol: string,
  results: YahooOptionsResult[],
  quoteInfo: {
    changePercent: number;
    earningsTimestamp?: number;
    marketCap?: number;
    sector?: string;
  }
): OptionFlowItem[] => {
  const symbolItems: OptionFlowItem[] = [];
  const now = new Date();

  for (const result of results) {
    const spotPrice = result.quote?.regularMarketPrice || 0;
    const options = result.options?.[0];
    if (!options) continue;

    const calls = (options.calls || []) as YahooOption[];
    const puts = (options.puts || []) as YahooOption[];

    calls.forEach((opt) => {
      const analyzed = analyzeOption(
        symbol,
        opt,
        "Call",
        spotPrice,
        quoteInfo.changePercent,
        quoteInfo.earningsTimestamp,
        quoteInfo.marketCap,
        quoteInfo.sector,
        now
      );
      if (analyzed) symbolItems.push(analyzed);
    });

    puts.forEach((opt) => {
      const analyzed = analyzeOption(
        symbol,
        opt,
        "Put",
        spotPrice,
        quoteInfo.changePercent,
        quoteInfo.earningsTimestamp,
        quoteInfo.marketCap,
        quoteInfo.sector,
        now
      );
      if (analyzed) symbolItems.push(analyzed);
    });
  }
  return symbolItems;
};

const analyzeOption = (
  symbol: string,
  opt: YahooOption,
  type: "Call" | "Put",
  spotPrice: number,
  changePercent: number,
  earningsTimestamp: number | undefined,
  marketCap: number | undefined,
  sector: string | undefined,
  now: Date
): OptionFlowItem | null => {
  // Filter for significant volume to simulate "flow"
  if (!opt.volume || opt.volume < CONFIG.MIN_VOLUME) return null;

  const isCall = type === "Call";
  const lastPrice = opt.lastPrice || 0;
  const bid = opt.bid || 0;
  const ask = opt.ask || 0;
  const volume = opt.volume;
  const openInterest = opt.openInterest || 0;
  const premium = lastPrice * volume * 100;

  const { sentiment, details, flowType } = analyzeTradeExecution(
    isCall,
    lastPrice,
    bid,
    ask,
    volume,
    openInterest,
    premium
  );

  const expirationDate = getDateFromPotentialTimestamp(opt.expiration);
  const daysToExpiration = getDaysDifference(now, expirationDate);

  const isOTM = isCall ? opt.strike > spotPrice : opt.strike < spotPrice;
  // const volToOiRatio = openInterest > 0 ? volume / openInterest : 0;
  // let moneyness = "ATM";
  // const percentDiff = Math.abs(opt.strike - spotPrice) / spotPrice;
  // if (percentDiff < 0.01) moneyness = "ATM";
  // else if (isCall) moneyness = opt.strike < spotPrice ? "ITM" : "OTM";
  // else moneyness = opt.strike > spotPrice ? "ITM" : "OTM";

  const { flags, reasons, isUnusual } = detectFlags({
    premium,
    flowType,
    isOTM,
    details,
    openInterest,
    volume: opt.volume,
    daysToExpiration,
    isCall,
    changePercent,
    earningsTimestamp,
    expirationDate,
    now,
    iv: opt.impliedVolatility || 0,
    spotPrice,
    strike: opt.strike,
    bid,
    ask,
    marketCap: marketCap,
    lastPrice,
    // volToOiRatio,
  });

  const score = calculateConvictionScore({
    premium,
    flowType,
    isOTM,
    daysToExpiration,
    volume,
    openInterest,
    flags,
  });

  const lastTradeDate = getDateFromPotentialTimestamp(opt.lastTradeDate);

  return {
    symbol: symbol,
    time: lastTradeDate.toISOString(),
    strike: opt.strike,
    expirationDate: expirationDate.toISOString(),
    type: type,
    spotPrice: spotPrice,
    premium: premium,
    volume: opt.volume,
    openInterest: openInterest,
    impliedVolatility: opt.impliedVolatility || 0,
    flowType: flowType,
    sentiment: sentiment,
    details: details,
    flags: flags,
    reasons: reasons,
    isUnusual: isUnusual,
    score: score,
    marketCap: marketCap,
    sector: sector,
    changePercent: changePercent,
    lastPrice: lastPrice,
    bid: bid,
    ask: ask,
  };
};

interface FlagDetectionParams {
  premium: number;
  flowType: string;
  isOTM: boolean;
  details: string;
  openInterest: number;
  volume: number;
  daysToExpiration: number;
  isCall: boolean;
  changePercent: number;
  earningsTimestamp?: number;
  expirationDate: Date;
  now: Date;
  iv: number;
  spotPrice: number;
  strike: number;
  bid?: number;
  ask?: number;
  marketCap?: number;
  lastPrice: number;
  // volToOiRatio: number;
}

const detectFlags = (
  params: FlagDetectionParams
): { flags: string[]; reasons: string[]; isUnusual: boolean } => {
  const {
    premium,
    flowType,
    isOTM,
    details,
    openInterest,
    volume,
    daysToExpiration,
    isCall,
    changePercent,
    earningsTimestamp,
    expirationDate,
    now,
    iv,
    spotPrice,
    strike,
    bid,
    ask,
    marketCap,
    lastPrice,
    // volToOiRatio,
  } = params;

  const flags: string[] = [];
  const reasons: string[] = [];
  let isUnusual = false;

  // Super Whale Detection (> $5M)
  if (premium > 5000000) {
    flags.push("Super Whale");
    reasons.push(
      `Massive premium > $5M ($${Math.round(premium).toLocaleString()})`
    );
    isUnusual = true;
  }

  // Whale Detection
  // Adjust threshold for small caps (<2B)
  const isSmallCap = marketCap && marketCap < 2000000000;
  const whaleThreshold = isSmallCap ?
    CONFIG.PREMIUM_THRESHOLDS.WHALE / 5 :
    CONFIG.PREMIUM_THRESHOLDS.WHALE;

  if (premium > whaleThreshold && premium <= 5000000) {
    flags.push("WHALE");
    reasons.push(
      `Large premium of $${Math.round(premium).toLocaleString()} ` +
      `exceeds whale threshold ($${whaleThreshold.toLocaleString()})`
    );
    isUnusual = true;
  }

  // Institutional / Dark Pool Proxy
  if (premium > 2000000 && flowType === "block") {
    flags.push("Institutional");
    reasons.push("Large block trade > $2M premium");
    isUnusual = true;
  }

  // Golden Sweep Detection
  if (
    flowType === "sweep" &&
    premium > CONFIG.PREMIUM_THRESHOLDS.GOLDEN_SWEEP &&
    isOTM &&
    details === CONFIG.DETAILS.ABOVE_ASK &&
    volume > openInterest
  ) {
    flags.push("Golden Sweep");
    reasons.push(
      "High-conviction sweep: Premium > " +
      `$${CONFIG.PREMIUM_THRESHOLDS.GOLDEN_SWEEP.toLocaleString()}, ` +
      "OTM, Above Ask, and Vol > OI"
    );
    isUnusual = true;
  }

  // Steamroller Detection (Deep ITM, High Volume)
  if (
    ((isCall && spotPrice > strike * 1.1) ||
      (!isCall && spotPrice < strike * 0.9)) &&
    volume > 500 &&
    volume > openInterest
  ) {
    flags.push("Steamroller");
    reasons.push(
      `Deep ITM position with heavy volume (${volume}) ` +
      `exceeding OI (${openInterest})`
    );
    isUnusual = true;
  }

  // New Position (Volume > Open Interest)
  if (openInterest > 0 && volume > openInterest) {
    flags.push("New Position");
    reasons.push(
      `Volume (${volume}) exceeds Open Interest (${openInterest}), ` +
      "indicating fresh entry"
    );
    isUnusual = true;
  }

  // Gamma Squeeze Potential
  if (
    daysToExpiration <= 2 &&
    isCall &&
    isOTM &&
    volume > openInterest &&
    changePercent > 1.0
  ) {
    flags.push("Gamma Squeeze");
    reasons.push(
      "Short-dated OTM calls with high volume and rising price " +
      `(+${changePercent.toFixed(2)}%)`
    );
    isUnusual = true;
  }

  // Panic Protection / Hedging
  if (
    !isCall &&
    changePercent < -2.0 &&
    isOTM &&
    details === CONFIG.DETAILS.ABOVE_ASK
  ) {
    flags.push("Panic Hedge");
    reasons.push(
      "Aggressive OTM puts bought while stock is down " +
      `${changePercent.toFixed(2)}%`
    );
    isUnusual = true;
  }

  // Floor Protection (Deep OTM Puts with high volume)
  if (!isCall && spotPrice > strike * 1.2 && volume > 1000) {
    flags.push("Floor Protection");
    reasons.push(
      "High volume deep OTM puts. Likely institutional hedging/insurance."
    );
  }

  // Earnings Play
  if (earningsTimestamp) {
    const earningsDate = new Date(earningsTimestamp * 1000);
    const daysToEarnings = getDaysDifference(now, earningsDate);
    if (
      daysToEarnings >= 0 &&
      daysToEarnings <= 14 &&
      expirationDate > earningsDate
    ) {
      flags.push("Earnings Play");
      reasons.push(
        `Options expire shortly after earnings in ${daysToEarnings} days`
      );
      isUnusual = true;
    }

    // IV Crush Risk
    if (
      daysToEarnings >= 0 &&
      daysToEarnings <= 2 &&
      iv > CONFIG.IV_THRESHOLDS.HIGH
    ) {
      flags.push("IV Crush Risk");
      reasons.push(
        "High IV (${iv.toFixed(2)}) just before earnings." +
        " Risk of volatility crush."
      );
    }
  }

  // Contrarian / Divergence
  if (changePercent) {
    if (isCall && changePercent < -1.0) {
      flags.push("Bullish Divergence");
      reasons.push(
        `Calls bought despite stock dropping ${changePercent.toFixed(2)}%`
      );
      isUnusual = true;
    } else if (!isCall && changePercent > 1.0) {
      flags.push("Bearish Divergence");
      reasons.push(
        `Puts bought despite stock rising ${changePercent.toFixed(2)}%`
      );
      isUnusual = true;
    } else if (isCall && changePercent < -2.0) {
      flags.push("Contrarian");
      reasons.push(
        `Calls bought opposing strong downtrend (${changePercent.toFixed(2)}%)`
      );
      isUnusual = true;
    } else if (!isCall && changePercent > 2.0) {
      flags.push("Contrarian");
      reasons.push(
        `Puts bought opposing strong uptrend (${changePercent.toFixed(2)}%)`
      );
      isUnusual = true;
    }
  }

  // Unusual activity detection
  if (openInterest > 0) {
    const volToOiRatio = openInterest > 0 ? volume / openInterest : 0;
    if (volToOiRatio > CONFIG.VOL_OI_RATIOS.MEGA) {
      isUnusual = true;
      flags.push("Mega Vol");
      reasons.push(
        `Volume (${volume}) is ${volToOiRatio.toFixed(1)}x ` +
        `greater than Open Interest (${openInterest})`
      );
    } else if (volToOiRatio > CONFIG.VOL_OI_RATIOS.EXPLOSION) {
      isUnusual = true;
      flags.push("Vol Explosion");
      reasons.push(
        `Volume (${volume}) is ${volToOiRatio.toFixed(1)}x ` +
        `greater than Open Interest (${openInterest})`
      );
    } else if (volToOiRatio > CONFIG.VOL_OI_RATIOS.HIGH) {
      isUnusual = true;
      flags.push("High Vol/OI");
      reasons.push(
        `Volume (${volume}) is ${volToOiRatio.toFixed(1)}x ` +
        `greater than Open Interest (${openInterest})`
      );
    }
  }

  if (iv > CONFIG.IV_THRESHOLDS.EXTREME) {
    isUnusual = true;
    flags.push("Extreme IV");
    reasons.push(
      `Implied Volatility at ${iv.toFixed(2)} ` +
      `(Threshold: ${CONFIG.IV_THRESHOLDS.EXTREME})`
    );
  } else if (iv > CONFIG.IV_THRESHOLDS.HIGH) {
    isUnusual = true;
    flags.push("High IV");
    reasons.push(
      `Implied Volatility at ${iv.toFixed(2)} ` +
      `(Threshold: ${CONFIG.IV_THRESHOLDS.HIGH})`
    );
  } else if (iv < CONFIG.IV_THRESHOLDS.LOW && daysToExpiration > 30) {
    flags.push("Low IV");
    reasons.push(
      `Implied Volatility at ${iv.toFixed(2)} is low ` +
      `(< ${CONFIG.IV_THRESHOLDS.LOW}) for long-dated option`
    );
  }

  // Spread Detection
  if (bid && ask && ask > 0) {
    const spread = (ask - bid) / ask;
    if (spread < 0.01 && volume > 500) {
      flags.push("Tight Spread");
      reasons.push(
        `Liquid market with ${(spread * 100).toFixed(2)}% spread ` +
        "and high volume"
      );
    } else if (spread > 0.1) {
      flags.push("Wide Spread");
      reasons.push(
        `Illiquid market with ${(spread * 100).toFixed(2)}% spread ` +
        "(> 10%)"
      );
    }
  }

  // ATM Detection (High Gamma Potential)
  const percentDiff = Math.abs(strike - spotPrice) / spotPrice;
  if (percentDiff < 0.01 && volume > 500) {
    flags.push("ATM Flow");
    reasons.push(
      `Strike ($${strike}) is near Spot ($${spotPrice}) ` +
      "with significant volume"
    );
  }

  // Deep ITM detection
  if (isCall && spotPrice > strike * 1.1) {
    flags.push("Deep ITM");
    reasons.push(
      `Call Strike ($${strike}) is significantly below Spot ($${spotPrice})`
    );
  } else if (!isCall && spotPrice < strike * 0.9) {
    flags.push("Deep ITM");
    reasons.push(
      `Put Strike ($${strike}) is significantly above Spot ($${spotPrice})`
    );
  }

  // Deep OTM detection
  if (isCall && spotPrice < strike * 0.8) {
    flags.push("Deep OTM");
    reasons.push(
      `Call Strike ($${strike}) is significantly above Spot ($${spotPrice})`
    );
  } else if (!isCall && spotPrice > strike * 1.2) {
    flags.push("Deep OTM");
    reasons.push(
      `Put Strike ($${strike}) is significantly below Spot ($${spotPrice})`
    );
  }

  // Aggressive detection
  if (
    (details === CONFIG.DETAILS.ABOVE_ASK ||
      details === CONFIG.DETAILS.BELOW_BID) &&
    flowType === "sweep"
  ) {
    flags.push("Aggressive");
    reasons.push(`Sweep executed ${details}`);
  }

  // Cheap Volatility
  if (lastPrice < 0.50 && volume > 2000) {
    flags.push("Cheap Vol");
    reasons.push(
      `Low-cost contracts ($${lastPrice}) with high volume (>2000)`
    );
  }

  // High Premium Contract
  if (lastPrice > 20.0 && volume > 100) {
    flags.push("High Premium");
    reasons.push(
      `Expensive contracts ($${lastPrice}) with significant volume`
    );
  }

  // Lotto Detection (Far OTM, Short Term)
  const percentOTM = Math.abs(strike - spotPrice) / spotPrice;
  if (isOTM && percentOTM > 0.15 && daysToExpiration < 14 && lastPrice < 1.0) {
    // Only flag as Lotto if premium is relatively low per contract (cheap bets)
    flags.push("Lotto");
    reasons.push("Cheap (<$1), short-term OTM bet (>15% OTM)");
    isUnusual = true;
  }

  // Expiration-based unusual activity
  if (daysToExpiration <= CONFIG.DTE_THRESHOLDS.ZERO) {
    if (isOTM && volume > 1000) {
      flags.push("0DTE Lotto");
      reasons.push("High volume 0DTE OTM speculation");
      isUnusual = true;
    } else {
      flags.push("0DTE");
      reasons.push("Expires today or tomorrow");
      if (volume > 2000) isUnusual = true;
    }
  } else if (
    daysToExpiration <= CONFIG.DTE_THRESHOLDS.WEEKLY &&
    isOTM &&
    volume > 500
  ) {
    isUnusual = true;
    flags.push("Weekly OTM");
    reasons.push("Short-term speculative bet (Weekly exp, OTM)");
  } else if (
    daysToExpiration > CONFIG.DTE_THRESHOLDS.LEAPS &&
    volume > 100
  ) {
    isUnusual = true;
    flags.push("LEAPS");
    reasons.push("Long-term investment (>1 year)");

    if (isCall && isOTM) {
      flags.push("Leaps Buy");
      reasons.push("Long-term OTM bullish speculation");
    }
  }

  return { flags, reasons, isUnusual };
};

interface ConvictionScoreParams {
  premium: number;
  flowType: string;
  isOTM: boolean;
  daysToExpiration: number;
  volume: number;
  openInterest: number;
  flags: string[];
}

const calculateConvictionScore = (params: ConvictionScoreParams): number => {
  let score = 0;
  const {
    premium,
    flowType,
    isOTM,
    daysToExpiration,
    volume,
    openInterest,
    flags,
  } = params;

  // Premium Score (0-40)
  if (premium > 5000000) score += 40;
  else if (premium > 1000000) score += 30;
  else if (premium > 500000) score += 20;
  else if (premium > 100000) score += 10;

  // Flow Type Score (0-20)
  if (flowType === "sweep") score += 20;
  else if (flowType === "block") score += 10;

  // Urgency/Aggression Score (0-20)
  if (isOTM) score += 10;
  if (daysToExpiration <= 1) score += 10; // Boost for 0DTE/1DTE
  else if (daysToExpiration < 14) score += 5;

  if (flags.includes("Aggressive")) score += 5;
  if (flags.includes("Tight Spread")) score += 5;
  if (flags.includes("ATM Flow")) score += 5;
  if (flags.includes("Gamma Squeeze")) score += 5;
  if (flags.includes("Steamroller")) score += 5;
  if (flags.includes("Earnings Play")) score += 5;

  // Unusual Activity Score (0-25)
  if (volume > openInterest * 10) score += 25;
  else if (volume > openInterest * 5) score += 20;
  else if (volume > openInterest * 2) score += 10;
  else if (volume > openInterest) score += 5;

  // Bonus Multipliers
  if (flags.includes("Golden Sweep")) score *= 1.2;
  if (flags.includes("WHALE")) score *= 1.1;
  if (flags.includes("Bullish Divergence") ||
    flags.includes("Bearish Divergence")) score *= 1.1;
  if (flags.includes("Lotto")) score *= 1.05;

  return Math.min(Math.round(score), 100);
};

interface TradeExecutionAnalysis {
  sentiment: string;
  details: string;
  flowType: string;
}

const analyzeTradeExecution = (
  isCall: boolean,
  lastPrice: number,
  bid: number,
  ask: number,
  volume: number,
  openInterest: number,
  premium: number
): TradeExecutionAnalysis => {
  // Determine sentiment based on trade price relative to Bid/Ask
  let sentiment = isCall ? CONFIG.SENTIMENT.BULLISH : CONFIG.SENTIMENT.BEARISH;
  let details = isCall ? CONFIG.DETAILS.ASK_SIDE : CONFIG.DETAILS.BID_SIDE;

  if (bid > 0 && ask > 0) {
    if (lastPrice >= ask) {
      details = CONFIG.DETAILS.ABOVE_ASK;
      // Buying Calls or Puts
      sentiment = isCall ? CONFIG.SENTIMENT.BULLISH : CONFIG.SENTIMENT.BEARISH;
    } else if (lastPrice <= bid) {
      details = CONFIG.DETAILS.BELOW_BID;
      // Selling Calls or Puts
      sentiment = isCall ? CONFIG.SENTIMENT.BEARISH : CONFIG.SENTIMENT.BULLISH;
    } else {
      const mid = (bid + ask) / 2;
      details = CONFIG.DETAILS.MID_MARKET;
      if (lastPrice > mid) {
        sentiment = isCall ?
          CONFIG.SENTIMENT.BULLISH :
          CONFIG.SENTIMENT.BEARISH; // Leans Buy
      } else {
        sentiment = isCall ?
          CONFIG.SENTIMENT.BEARISH :
          CONFIG.SENTIMENT.BULLISH; // Leans Sell
      }
    }
  } else {
    // If bid/ask are missing, assume mid-market or unknown
    details = CONFIG.DETAILS.MID_MARKET;
  }

  // Determine flow type based on volume vs OI and premium
  let flowType = "block";

  if (openInterest && volume > openInterest) {
    flowType = "sweep"; // High relative volume often indicates sweeps
  } else if (premium > CONFIG.PREMIUM_THRESHOLDS.BLOCK) {
    flowType = "block";
  }

  // Detect Cross Trades (Price exactly at Bid or Ask with high volume)
  if (bid > 0 && ask > 0 && volume > 5000) {
    if (lastPrice === bid || lastPrice === ask) {
      flowType = "cross";
      details = "Cross Trade";
      sentiment = CONFIG.SENTIMENT.NEUTRAL;
    }
  }

  // Detect large block trades (proxy for Dark Pool/Institutional)
  if (premium > CONFIG.PREMIUM_THRESHOLDS.DARK_POOL) {
    flowType = "darkPool";
    sentiment = CONFIG.SENTIMENT.NEUTRAL;
    details = CONFIG.DETAILS.LARGE_BLOCK;
  }

  return { sentiment, details, flowType };
};

// Helper to handle dates that might be Date objects or timestamps
const getDateFromPotentialTimestamp = (
  dateOrTimestamp: Date | number | undefined
): Date => {
  if (!dateOrTimestamp) return new Date();
  if (dateOrTimestamp instanceof Date) return dateOrTimestamp;
  // If it's a number, check if it's seconds (likely) or ms
  // Yahoo Finance usually returns seconds for timestamps
  if (dateOrTimestamp < 10000000000) {
    return new Date(dateOrTimestamp * 1000);
  }
  return new Date(dateOrTimestamp);
};

const getDaysDifference = (date1: Date, date2: Date): number => {
  const diffTime = date2.getTime() - date1.getTime();
  return Math.ceil(diffTime / (1000 * 60 * 60 * 24));
};
