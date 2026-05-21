/**
 * Gamma Exposure (GEX) Analysis Module
 *
 * Computes net dealer gamma exposure from options chain data.
 * Positive GEX → dealers are net long gamma (price pinning / mean-reverting).
 * Negative GEX → dealers are net short gamma (trend amplifying).
 *
 * GEX per strike = (call_gamma × call_OI − put_gamma × put_OI) × 100 × spotPrice
 * Black-Scholes gamma: Γ = N'(d1) / (S × σ × √T)
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { getFirestore } from "firebase-admin/firestore";
import { IndicatorResult } from "./technical-indicators";
import { fetchOptionsFlowForSymbols } from "./options-flow-utils";

const db = getFirestore();

// GEX cache collection
const GEX_CACHE_COLLECTION = "gamma_exposure";
const GEX_CACHE_TTL = 4 * 60 * 60 * 1000; // 4 hours

export interface GexStrikeLevel {
  strike: number;
  callGamma: number;
  putGamma: number;
  callOI: number;
  putOI: number;
  callGEX: number;
  putGEX: number;
  netGEX: number; // positive = long gamma dealer, negative = short gamma dealer
}

export interface GammaExposureData {
  symbol: string;
  spotPrice: number;
  totalCallGEX: number;
  totalPutGEX: number;
  totalNetGEX: number; // sum of all strikes
  gammaFlip: number | null; // strike where net GEX crosses zero
  maxGammaStrike: number | null; // strike with highest absolute net GEX
  gexByStrike: GexStrikeLevel[];
  dealerPositioning: "long_gamma" | "short_gamma" | "neutral";
  signalStrength: number; // 0–100 expressing conviction
  updatedAt: number;
}

/**
 * Standard normal PDF (probability density function).
 */
function normalPDF(x: number): number {
  return Math.exp(-0.5 * x * x) / Math.sqrt(2 * Math.PI);
}

/**
 * Compute Black-Scholes gamma for a single option.
 * @param S - Current underlying price
 * @param K - Strike price
 * @param T - Time to expiration in years
 * @param r - Risk-free rate (default 0.05)
 * @param sigma - Implied volatility (annualized, e.g. 0.25 for 25%)
 * @returns Gamma value or 0 on invalid inputs
 */
export function computeBlackScholesGamma(
  S: number,
  K: number,
  T: number,
  r: number,
  sigma: number
): number {
  if (S <= 0 || K <= 0 || T <= 0 || sigma <= 0) return 0;

  const sqrtT = Math.sqrt(T);
  const d1 = (Math.log(S / K) + (r + 0.5 * sigma * sigma) * T) / (sigma * sqrtT);

  return normalPDF(d1) / (S * sigma * sqrtT);
}

/**
 * Compute GEX for each strike from options chain data.
 */
export function computeGEXByStrike(
  options: {
    calls: Array<{
      strike: number;
      impliedVolatility?: number;
      openInterest?: number;
      expiration?: Date | number;
    }>;
    puts: Array<{
      strike: number;
      impliedVolatility?: number;
      openInterest?: number;
      expiration?: Date | number;
    }>;
    expirationDate?: Date;
  },
  spotPrice: number,
  riskFreeRate = 0.05
): GexStrikeLevel[] {
  if (!spotPrice || spotPrice <= 0) return [];

  const now = Date.now();

  // Build a map of strike → { callGamma, callOI, putGamma, putOI }
  const strikeMap: Map<number, Omit<GexStrikeLevel, "netGEX" | "callGEX" | "putGEX">> = new Map();

  const processOption = (
    opt: { strike: number; impliedVolatility?: number; openInterest?: number; expiration?: Date | number },
    side: "call" | "put",
    defaultExpiration?: Date
  ) => {
    const strike = opt.strike;
    if (!strike || strike <= 0) return;

    // Compute time to expiration in years
    let expirationMs: number | null = null;
    const rawExp = opt.expiration ?? defaultExpiration;
    if (rawExp) {
      expirationMs = rawExp instanceof Date ? rawExp.getTime() : rawExp as number;
    }
    const T = expirationMs ? Math.max((expirationMs - now) / (365 * 24 * 60 * 60 * 1000), 0.001) : 0.05;

    const sigma = (opt.impliedVolatility || 0);
    const effectiveSigma = sigma > 0 ? sigma : 0.3; // fallback to 30% IV if not available

    const gamma = computeBlackScholesGamma(spotPrice, strike, T, riskFreeRate, effectiveSigma);
    const oi = opt.openInterest || 0;

    if (!strikeMap.has(strike)) {
      strikeMap.set(strike, {
        strike,
        callGamma: 0,
        putGamma: 0,
        callOI: 0,
        putOI: 0,
      });
    }

    const entry = strikeMap.get(strike)!;
    if (side === "call") {
      entry.callGamma = gamma;
      entry.callOI = oi;
    } else {
      entry.putGamma = gamma;
      entry.putOI = oi;
    }
  };

  for (const call of options.calls || []) {
    processOption(call, "call", options.expirationDate);
  }
  for (const put of options.puts || []) {
    processOption(put, "put", options.expirationDate);
  }

  // Convert to GexStrikeLevel with dollar-weighted GEX
  const result: GexStrikeLevel[] = [];
  for (const entry of strikeMap.values()) {
    const callGEX = entry.callGamma * entry.callOI * 100 * spotPrice;
    const putGEX = entry.putGamma * entry.putOI * 100 * spotPrice;
    const netGEX = callGEX - putGEX;

    result.push({
      ...entry,
      callGEX,
      putGEX,
      netGEX,
    });
  }

  return result.sort((a, b) => a.strike - b.strike);
}

/**
 * Aggregate GEX across all option expirations.
 */
export function aggregateGEXByStrike(
  allExpirationGEX: GexStrikeLevel[][]
): GexStrikeLevel[] {
  const aggregateMap: Map<number, GexStrikeLevel> = new Map();

  for (const strikeList of allExpirationGEX) {
    for (const level of strikeList) {
      if (aggregateMap.has(level.strike)) {
        const existing = aggregateMap.get(level.strike)!;
        existing.callGamma += level.callGamma;
        existing.putGamma += level.putGamma;
        existing.callOI += level.callOI;
        existing.putOI += level.putOI;
        existing.callGEX += level.callGEX;
        existing.putGEX += level.putGEX;
        existing.netGEX += level.netGEX;
      } else {
        aggregateMap.set(level.strike, { ...level });
      }
    }
  }

  return Array.from(aggregateMap.values()).sort((a, b) => a.strike - b.strike);
}

/**
 * Find the gamma flip point — the strike where cumulative GEX
 * transitions from positive to negative (or vice versa) nearest to spot price.
 */
export function computeGammaFlipLevel(
  gexByStrike: GexStrikeLevel[],
  spotPrice: number
): number | null {
  if (gexByStrike.length < 2) return null;

  // Sort by strike and look for sign change in netGEX
  const sorted = [...gexByStrike].sort((a, b) => a.strike - b.strike);

  // Find strikes closest to spot price where sign changes
  let flipStrike: number | null = null;
  let closestDistance = Infinity;

  for (let i = 1; i < sorted.length; i++) {
    const prev = sorted[i - 1];
    const curr = sorted[i];

    if (prev.netGEX !== 0 && curr.netGEX !== 0 &&
      Math.sign(prev.netGEX) !== Math.sign(curr.netGEX)) {
      // Linear interpolation for the exact crossing
      const crossingStrike = prev.strike +
        (curr.strike - prev.strike) * Math.abs(prev.netGEX) /
        (Math.abs(prev.netGEX) + Math.abs(curr.netGEX));

      const dist = Math.abs(crossingStrike - spotPrice);
      if (dist < closestDistance) {
        closestDistance = dist;
        flipStrike = Math.round(crossingStrike * 100) / 100;
      }
    }
  }

  return flipStrike;
}

/**
 * Find the strike with the highest absolute net GEX (strongest gravity well).
 */
export function findMaxGammaStrike(gexByStrike: GexStrikeLevel[]): number | null {
  if (gexByStrike.length === 0) return null;
  return gexByStrike.reduce((maxLevel, level) =>
    Math.abs(level.netGEX) > Math.abs(maxLevel.netGEX) ? level : maxLevel
  ).strike;
}

/**
 * Compute full GammaExposureData from options chain.
 */
export function computeGammaExposure(
  symbol: string,
  spotPrice: number,
  optionsChain: {
    options: Array<{
      calls?: Array<{ strike: number; impliedVolatility?: number; openInterest?: number; expiration?: Date | number }>;
      puts?: Array<{ strike: number; impliedVolatility?: number; openInterest?: number; expiration?: Date | number }>;
      expirationDate?: Date;
    }>;
  }
): GammaExposureData {
  const allExpirationGEX: GexStrikeLevel[][] = [];

  for (const expiration of optionsChain.options || []) {
    const gex = computeGEXByStrike(
      {
        calls: expiration.calls || [],
        puts: expiration.puts || [],
        expirationDate: expiration.expirationDate,
      },
      spotPrice
    );
    if (gex.length > 0) {
      allExpirationGEX.push(gex);
    }
  }

  const gexByStrike = aggregateGEXByStrike(allExpirationGEX);

  const totalCallGEX = gexByStrike.reduce((sum, l) => sum + l.callGEX, 0);
  const totalPutGEX = gexByStrike.reduce((sum, l) => sum + l.putGEX, 0);
  const totalNetGEX = totalCallGEX - totalPutGEX;

  const gammaFlip = computeGammaFlipLevel(gexByStrike, spotPrice);
  const maxGammaStrike = findMaxGammaStrike(gexByStrike);

  let dealerPositioning: "long_gamma" | "short_gamma" | "neutral";
  const absGEX = Math.abs(totalNetGEX);
  const threshold = 1e6; // $1M threshold for neutral zone
  if (absGEX < threshold) {
    dealerPositioning = "neutral";
  } else if (totalNetGEX > 0) {
    dealerPositioning = "long_gamma";
  } else {
    dealerPositioning = "short_gamma";
  }

  // Normalize signal strength 0–100 based on GEX magnitude relative to typical range
  // Use $1B as the "max" scale (very high GEX for mega-caps)
  const gexMagnitude = Math.min(Math.abs(totalNetGEX) / 1e9, 1.0);
  const signalStrength = Math.round(gexMagnitude * 100);

  return {
    symbol,
    spotPrice,
    totalCallGEX,
    totalPutGEX,
    totalNetGEX,
    gammaFlip,
    maxGammaStrike,
    gexByStrike,
    dealerPositioning,
    signalStrength,
    updatedAt: Date.now(),
  };
}

/**
 * Evaluate GEX as a trading indicator signal.
 * Positive GEX (dealers long) → price pinning / mean-reversion → HOLD/BUY.
 * Negative GEX (dealers short) → trend amplification.
 * If price is above gamma flip → BUY context; below → SELL context.
 */
export function evaluateGammaExposure(
  gexData: GammaExposureData
): IndicatorResult {
  const { totalNetGEX, gammaFlip, spotPrice, dealerPositioning, maxGammaStrike } = gexData;

  const absGEX = Math.abs(totalNetGEX);
  const threshold = 1e6;

  if (absGEX < threshold) {
    return {
      value: totalNetGEX,
      signal: "HOLD",
      reason: `GEX near zero ($${(totalNetGEX / 1e6).toFixed(0)}M): neutral dealer positioning`,
      metadata: { dealerPositioning, gammaFlip, maxGammaStrike },
    };
  }

  // Key signal logic:
  // 1. Price above gamma flip + dealers long gamma → BUY (supports upward pinning)
  // 2. Price below gamma flip + dealers short gamma → SELL (downward acceleration)
  // 3. Dealers long gamma regardless → mild BUY (stabilizing)
  // 4. Dealers short gamma regardless → mild SELL (amplifying)
  let signal: "BUY" | "SELL" | "HOLD";
  let reason: string;

  const gexMillions = (totalNetGEX / 1e6).toFixed(0);
  const flipStr = gammaFlip ? `$${gammaFlip.toFixed(2)}` : "N/A";
  const maxStr = maxGammaStrike ? `$${maxGammaStrike.toFixed(2)}` : "N/A";

  if (gammaFlip !== null) {
    if (spotPrice > gammaFlip && dealerPositioning === "long_gamma") {
      signal = "BUY";
      reason = `GEX +$${gexMillions}M: dealers long gamma, price above flip ${flipStr} → pinning support. Max gamma @ ${maxStr}`;
    } else if (spotPrice < gammaFlip && dealerPositioning === "short_gamma") {
      signal = "SELL";
      reason = `GEX $${gexMillions}M: dealers short gamma, price below flip ${flipStr} → trend amplification risk. Max gamma @ ${maxStr}`;
    } else if (spotPrice > gammaFlip && dealerPositioning === "short_gamma") {
      signal = "SELL";
      reason = `GEX $${gexMillions}M: dealers short gamma above flip ${flipStr} → potential breakdown. Max gamma @ ${maxStr}`;
    } else {
      // Below flip, long gamma → stabilizing below flip
      signal = "HOLD";
      reason = `GEX +$${gexMillions}M: dealers long gamma, price below flip ${flipStr} → mixed signals. Max gamma @ ${maxStr}`;
    }
  } else {
    // No gamma flip (all same sign)
    if (dealerPositioning === "long_gamma") {
      signal = "BUY";
      reason = `GEX +$${gexMillions}M: dealers uniformly long gamma → strong pinning regime. Max gamma @ ${maxStr}`;
    } else {
      signal = "SELL";
      reason = `GEX $${gexMillions}M: dealers uniformly short gamma → trending/volatile regime. Max gamma @ ${maxStr}`;
    }
  }

  return {
    value: totalNetGEX,
    signal,
    reason,
    metadata: { dealerPositioning, gammaFlip, maxGammaStrike, totalNetGEX },
  };
}

// ─── Firestore Cache ──────────────────────────────────────────────────────────

const getCachedGEX = async (symbol: string): Promise<GammaExposureData | null> => {
  try {
    const doc = await db.collection(GEX_CACHE_COLLECTION).doc(symbol).get();
    if (!doc.exists) return null;
    const data = doc.data() as GammaExposureData;
    if (Date.now() - (data.updatedAt || 0) > GEX_CACHE_TTL) {
      logger.info(`GEX cache expired for ${symbol}`);
      return null;
    }
    return data;
  } catch (e) {
    logger.warn(`Error reading GEX cache for ${symbol}`, e);
    return null;
  }
};

const saveGEXCache = async (data: GammaExposureData): Promise<void> => {
  try {
    await db.collection(GEX_CACHE_COLLECTION).doc(data.symbol).set(data);
  } catch (e) {
    logger.warn(`Error saving GEX cache for ${data.symbol}`, e);
  }
};

/**
 * Compute GEX for a symbol by fetching its options chain.
 * Uses the existing Firestore-cached options data from options-flow-utils.
 */
export async function fetchGammaExposure(symbol: string): Promise<GammaExposureData | null> {
  // Check cache first
  const cached = await getCachedGEX(symbol);
  if (cached) return cached;

  try {
    // Use existing options flow infrastructure to get the options chain
    // fetchOptionsFlowForSymbols already handles Twelve Data + Yahoo fallback + caching
    const flowItems = await fetchOptionsFlowForSymbols([symbol]);

    if (flowItems.length === 0) {
      logger.warn(`No options data available for GEX computation: ${symbol}`);
      return null;
    }

    const spotPrice = flowItems[0]?.spotPrice || 0;
    if (spotPrice <= 0) return null;

    // Reconstruct a minimal options chain from flow items to compute GEX
    // Group flow items by expiration date and strike
    const expirationMap: Map<string, {
      calls: Map<number, { strike: number; impliedVolatility: number; openInterest: number; expiration: Date }>;
      puts: Map<number, { strike: number; impliedVolatility: number; openInterest: number; expiration: Date }>;
      expirationDate: Date;
    }> = new Map();

    for (const item of flowItems) {
      const expKey = item.expirationDate;
      if (!expirationMap.has(expKey)) {
        expirationMap.set(expKey, {
          calls: new Map(),
          puts: new Map(),
          expirationDate: new Date(expKey),
        });
      }
      const expEntry = expirationMap.get(expKey)!;
      const optEntry = {
        strike: item.strike,
        impliedVolatility: item.impliedVolatility || 0.3,
        openInterest: item.openInterest || 0,
        expiration: new Date(expKey),
      };
      if (item.type === "Call") {
        expEntry.calls.set(item.strike, optEntry);
      } else {
        expEntry.puts.set(item.strike, optEntry);
      }
    }

    const optionsChain = {
      options: Array.from(expirationMap.values()).map((exp) => ({
        calls: Array.from(exp.calls.values()),
        puts: Array.from(exp.puts.values()),
        expirationDate: exp.expirationDate,
      })),
    };

    const gexData = computeGammaExposure(symbol, spotPrice, optionsChain);
    await saveGEXCache(gexData);
    return gexData;
  } catch (e) {
    logger.error(`Error computing GEX for ${symbol}`, e);
    return null;
  }
}

// ─── Firebase Callable Function ───────────────────────────────────────────────

/**
 * Callable Firebase Function to fetch Gamma Exposure data for a symbol.
 */
export const getGammaExposure = onCall({
  secrets: ["TWELVE_DATA_API_KEY"],
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const symbol: string = request.data?.symbol;
  if (!symbol || typeof symbol !== "string") {
    throw new HttpsError("invalid-argument", "symbol is required.");
  }

  logger.info(`getGammaExposure called for ${symbol}`);

  const gexData = await fetchGammaExposure(symbol.toUpperCase());

  if (!gexData) {
    return {
      status: "error",
      message: `Unable to compute GEX for ${symbol}. Options data may not be available.`,
    };
  }

  return {
    status: "ok",
    data: gexData,
  };
});
