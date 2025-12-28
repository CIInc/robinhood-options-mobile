import YahooFinance from "yahoo-finance2";

const yf = new YahooFinance({ suppressNotices: ["yahooSurvey"] });

// Constants for thresholds and configuration
const CONFIG = {
  MIN_VOLUME: 50,
  BATCH_SIZE: 5,
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
  isUnusual: boolean;
  score: number;
  marketCap?: number;
  sector?: string;
  changePercent?: number;
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
  quote?: YahooQuote;
  options?: {
    calls?: YahooOption[];
    puts?: YahooOption[];
  }[];
}

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
  try {
    // Fetch initial data to get expirations and quote info
    const initialResult = (await yf.options(symbol, {})) as YahooOptionsResult;
    const expirationDates = initialResult.expirationDates || [];
    const quote = initialResult.quote;

    if (!quote) return [];

    const sector = await ensureSector(symbol, quote);
    const marketCap = quote.marketCap;
    const earningsTimestamp = quote.earningsTimestamp;
    const changePercent = quote.regularMarketChangePercent || 0;

    // Filter expiration dates based on filter
    const targetDates = filterExpirationDates(
      expirationDates,
      expirationFilter
    );

    // Fetch option chains for target dates
    const resultsToProcess = await fetchOptionChains(
      symbol,
      targetDates,
      initialResult
    );

    // Process results
    return processOptionChains(symbol, resultsToProcess, {
      changePercent,
      earningsTimestamp,
      marketCap,
      sector,
    });
  } catch (e) {
    console.error(`Failed to fetch options for ${symbol}`, e);
    return [];
  }
};

const ensureSector = async (
  symbol: string,
  quote: YahooQuote
): Promise<string | undefined> => {
  if (quote.sector) return quote.sector;
  try {
    const summary = await yf.quoteSummary(symbol, {
      modules: ["assetProfile"],
    });
    return summary.assetProfile?.sector;
  } catch (e) {
    console.warn(`Failed to fetch sector for ${symbol}:`, e);
    return undefined;
  }
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

const fetchOptionChains = async (
  symbol: string,
  targetDates: Date[],
  initialResult: YahooOptionsResult
): Promise<YahooOptionsResult[]> => {
  const initialExpirationDate = initialResult.expirationDates?.[0];
  let resultsToProcess: YahooOptionsResult[] = [];

  // We want up to 4 dates from our filtered list to avoid excessive calls
  const datesWeWant = targetDates.slice(0, 4);

  // Check if we can reuse initialResult
  const reuseInitial =
    initialExpirationDate &&
    datesWeWant.some(
      (d) => d.getTime() === initialExpirationDate.getTime()
    );

  let datesToFetch: Date[] = [];

  if (reuseInitial && initialExpirationDate) {
    resultsToProcess.push(initialResult);
    datesToFetch = datesWeWant.filter(
      (d) => d.getTime() !== initialExpirationDate.getTime()
    );
  } else {
    datesToFetch = datesWeWant;
  }

  if (datesToFetch.length > 0) {
    const additionalResults = await Promise.all(
      datesToFetch.map((date) => yf.options(symbol, { date }))
    );
    resultsToProcess = [
      ...resultsToProcess,
      ...additionalResults,
    ] as YahooOptionsResult[];
  }

  return resultsToProcess;
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
        quoteInfo.sector
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
        quoteInfo.sector
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
  sector: string | undefined
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
  const now = new Date();
  const daysToExpiration = getDaysDifference(now, expirationDate);

  const isOTM = isCall ? opt.strike > spotPrice : opt.strike < spotPrice;

  const { flags, isUnusual } = detectFlags({
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
    isUnusual: isUnusual,
    score: score,
    marketCap: marketCap,
    sector: sector,
    changePercent: changePercent,
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
}

const detectFlags = (
  params: FlagDetectionParams
): { flags: string[]; isUnusual: boolean } => {
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
  } = params;

  const flags: string[] = [];
  let isUnusual = false;

  // Whale Detection
  // Adjust threshold for small caps (<2B)
  const isSmallCap = marketCap && marketCap < 2000000000;
  const whaleThreshold = isSmallCap ?
    CONFIG.PREMIUM_THRESHOLDS.WHALE / 5 :
    CONFIG.PREMIUM_THRESHOLDS.WHALE;

  if (premium > whaleThreshold) {
    flags.push("WHALE");
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
    isUnusual = true;
  }

  // New Position (Volume > Open Interest)
  if (openInterest > 0 && volume > openInterest) {
    flags.push("New Position");
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
    isUnusual = true;
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
      isUnusual = true;
    }
  }

  // Contrarian / Divergence
  if (changePercent) {
    if (isCall && changePercent < -1.0) {
      flags.push("Bullish Divergence");
      isUnusual = true;
    } else if (!isCall && changePercent > 1.0) {
      flags.push("Bearish Divergence");
      isUnusual = true;
    } else if (isCall && changePercent < -2.0) {
      flags.push("Contrarian");
      isUnusual = true;
    } else if (!isCall && changePercent > 2.0) {
      flags.push("Contrarian");
      isUnusual = true;
    }
  }

  // Unusual activity detection
  if (openInterest > 0) {
    if (volume > openInterest * CONFIG.VOL_OI_RATIOS.MEGA) {
      isUnusual = true;
      flags.push("Mega Vol");
    } else if (volume > openInterest * CONFIG.VOL_OI_RATIOS.EXPLOSION) {
      isUnusual = true;
      flags.push("Vol Explosion");
    } else if (volume > openInterest * CONFIG.VOL_OI_RATIOS.HIGH) {
      isUnusual = true;
      flags.push("High Vol/OI");
    }
  }

  if (iv > CONFIG.IV_THRESHOLDS.EXTREME) {
    isUnusual = true;
    flags.push("Extreme IV");
  } else if (iv > CONFIG.IV_THRESHOLDS.HIGH) {
    isUnusual = true;
    flags.push("High IV");
  } else if (iv < CONFIG.IV_THRESHOLDS.LOW && daysToExpiration > 30) {
    flags.push("Low IV");
  }

  // Spread Detection
  if (bid && ask && ask > 0) {
    const spread = (ask - bid) / ask;
    if (spread < 0.01 && volume > 500) {
      flags.push("Tight Spread");
    } else if (spread > 0.1) {
      flags.push("Wide Spread");
    }
  }

  // ATM Detection (High Gamma Potential)
  const percentDiff = Math.abs(strike - spotPrice) / spotPrice;
  if (percentDiff < 0.01 && volume > 500) {
    flags.push("ATM Flow");
  }

  // Deep ITM detection
  if (isCall && spotPrice > strike * 1.1) {
    flags.push("Deep ITM");
  } else if (!isCall && spotPrice < strike * 0.9) {
    flags.push("Deep ITM");
  }

  // Deep OTM detection
  if (isCall && spotPrice < strike * 0.8) {
    flags.push("Deep OTM");
  } else if (!isCall && spotPrice > strike * 1.2) {
    flags.push("Deep OTM");
  }

  // Aggressive detection
  if (
    (details === CONFIG.DETAILS.ABOVE_ASK ||
      details === CONFIG.DETAILS.BELOW_BID) &&
    flowType === "sweep"
  ) {
    flags.push("Aggressive");
  }

  // Cheap Volatility
  if (lastPrice < 0.50 && volume > 2000) {
    flags.push("Cheap Vol");
  }

  // High Premium Contract
  if (lastPrice > 20.0 && volume > 100) {
    flags.push("High Premium");
  }

  // Lotto Detection (Far OTM, Short Term)
  const percentOTM = Math.abs(strike - spotPrice) / spotPrice;
  if (isOTM && percentOTM > 0.15 && daysToExpiration < 14 && lastPrice < 1.0) {
    // Only flag as Lotto if premium is relatively low per contract (cheap bets)
    flags.push("Lotto");
    isUnusual = true;
  }

  // Expiration-based unusual activity
  if (daysToExpiration <= CONFIG.DTE_THRESHOLDS.ZERO) {
    flags.push("0DTE");
    if (volume > 1000) isUnusual = true;
  } else if (
    daysToExpiration <= CONFIG.DTE_THRESHOLDS.WEEKLY &&
    isOTM &&
    volume > 500
  ) {
    isUnusual = true;
    flags.push("Weekly OTM");
  } else if (
    daysToExpiration > CONFIG.DTE_THRESHOLDS.LEAPS &&
    volume > 100
  ) {
    isUnusual = true;
    flags.push("LEAPS");
  }

  return { flags, isUnusual };
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

  if (bid && ask) {
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
  }

  // Determine flow type based on volume vs OI and premium
  let flowType = "block";

  if (openInterest && volume > openInterest) {
    flowType = "sweep"; // High relative volume often indicates sweeps
  } else if (premium > CONFIG.PREMIUM_THRESHOLDS.BLOCK) {
    flowType = "block";
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
