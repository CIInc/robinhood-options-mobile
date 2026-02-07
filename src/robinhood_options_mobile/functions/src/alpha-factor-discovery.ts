import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { getMarketData } from "./market-data";
import {
  computeRSIArray,
  computeSMAArray,
  computeEMAArray,
  computeBollingerBandsArray,
  computeStochasticArray,
  computeATRArray,
  computeOBV,
  computeKeltnerChannelsArray,
} from "./technical-indicators";

// Helper for rate limiting
const delay = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

// --- Interfaces ---

interface AlphaFactorConfig {
  id: string;
  name: string;
  type:
  | "RSI"
  | "SMA_DISTANCE"
  | "MACD_SIGNAL"
  | "BB_WIDTH"
  | "MOMENTUM"
  | "STOCHASTIC_K"
  | "ATR"
  | "ADX"
  | "CCI"
  | "OBV"
  | "KELTNER_POSITION"
  | "WILLIAMS_R"
  | "ROC"
  | "MFI";
  parameters: Record<string, number>;
}

interface SymbolAnalysis {
  symbol: string;
  correlation: number | null;
  count: number;
}

interface AlphaFactorResult {
  config: AlphaFactorConfig;
  globalIC: number; // Mean Information Coefficient across universe
  icStdDev: number; // Volatility of IC
  icir: number; // Information Coefficient Information Ratio (Quality)
  symbolBreakdown: SymbolAnalysis[];
  status: "SUCCESS" | "ERROR";
  error?: string;
}

interface AlphaDiscoveryRequest {
  // Universe of symbols. Defaults to top tech/indices if empty.
  symbols?: string[];
  startDate?: string; // YYYY-MM-DD
  endDate?: string; // YYYY-MM-DD
  factors: AlphaFactorConfig[];
  forwardHorizon: number; // Days to look ahead for returns (e.g., 1, 5, 21)
}

// --- Helper Functions ---

/**
 * Calculates Pearson correlation coefficient between two arrays.
 * Ignores indices where either value is null/NaN.
 * @param {Array<number|null>} x First array of values
 * @param {Array<number|null>} y Second array of values
 * @return {number|null} Pearson correlation coefficient or null if invalid
 */
function calculateCorrelation(
  x: (number | null)[],
  y: (number | null)[]
): number | null {
  let sumX = 0;
  let sumY = 0;
  let sumXY = 0;
  let sumX2 = 0;
  let sumY2 = 0;
  let n = 0;

  for (let i = 0; i < x.length; i++) {
    const xi = x[i];
    const yi = y[i];

    if (xi !== null && yi !== null && !isNaN(xi) && !isNaN(yi)) {
      sumX += xi;
      sumY += yi;
      sumXY += xi * yi;
      sumX2 += xi * xi;
      sumY2 += yi * yi;
      n++;
    }
  }

  if (n < 2) return null;

  const numerator = n * sumXY - sumX * sumY;
  const denominator = Math.sqrt(
    (n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY)
  );

  if (denominator === 0) return 0;
  return numerator / denominator;
}

/**
 * Calculates forward percentage returns.
 * Returns[t] = (Price[t + horizon] - Price[t]) / Price[t]
 * @param {number[]} prices Array of historical prices
 * @param {number} horizon Number of periods to look forward
 * @return {Array<number|null>} Array of forward returns
 */
function calculateForwardReturns(
  prices: number[],
  horizon: number
): (number | null)[] {
  const returns: (number | null)[] = new Array(prices.length).fill(null);
  for (let i = 0; i < prices.length - horizon; i++) {
    const currentPrice = prices[i];
    const futurePrice = prices[i + horizon];
    if (currentPrice !== 0 && futurePrice !== undefined) {
      returns[i] = (futurePrice - currentPrice) / currentPrice;
    }
  }
  return returns;
}

/**
 * Computes ADX array locally since library only returns last value.
 * @param {number[]} highs High prices
 * @param {number[]} lows Low prices
 * @param {number[]} closes Close prices
 * @param {number} period ADX period
 * @return {Array<number|null>} Array of ADX values
 */
function computeADXArrayLocal(
  highs: number[],
  lows: number[],
  closes: number[],
  period: number
): (number | null)[] {
  if (highs.length < period * 2) return Array(closes.length).fill(null);

  const plusDM: number[] = [];
  const minusDM: number[] = [];
  const tr: number[] = [];

  // 1. Calculate +DM, -DM, TR
  for (let i = 1; i < highs.length; i++) {
    const highDiff = highs[i] - highs[i - 1];
    const lowDiff = lows[i - 1] - lows[i];

    plusDM.push((highDiff > lowDiff && highDiff > 0) ? highDiff : 0);
    minusDM.push((lowDiff > highDiff && lowDiff > 0) ? lowDiff : 0);

    const trueRange = Math.max(
      highs[i] - lows[i],
      Math.abs(highs[i] - closes[i - 1]),
      Math.abs(lows[i] - closes[i - 1])
    );
    tr.push(trueRange);
  }

  // 2. Wilder's Smoothing
  const smooth = (src: number[]) => {
    const output: number[] = [];
    let sum = src.slice(0, period).reduce((a, b) => a + b, 0);
    output.push(sum);
    for (let i = period; i < src.length; i++) {
      sum = sum - (sum / period) + src[i];
      output.push(sum);
    }
    return output;
  };

  const smPlusDM = smooth(plusDM);
  const smMinusDM = smooth(minusDM);
  const smTR = smooth(tr);

  // 3. DX and ADX
  const dx: number[] = [];
  for (let i = 0; i < smTR.length; i++) {
    if (smTR[i] === 0) {
      dx.push(0);
    } else {
      const pdi = (smPlusDM[i] / smTR[i]) * 100;
      const mdi = (smMinusDM[i] / smTR[i]) * 100;
      const sum = pdi + mdi;
      dx.push(sum === 0 ? 0 : (Math.abs(pdi - mdi) / sum) * 100);
    }
  }

  const adxRaw = smooth(dx);

  // Create final array aligned with input size
  // Steps lost data:
  // - 1 index lost at step 1 (diffs)
  // - (period - 1) indices lost at step 2 (first smoothing)
  // - (period - 1) indices lost at step 3 (final adx smoothing)

  // Total padding = N - ADX length = 2*period - 1.
  const padding = closes.length - adxRaw.length;
  // Normalize ADX (Wilder's Smoothing is a Sum in this impl, need Average)
  const adxNormalized = adxRaw.map((v) => v / period);
  return [...Array(padding).fill(null), ...adxNormalized];
}

/**
 * Computes CCI array.
 * @param {number[]} highs High prices
 * @param {number[]} lows Low prices
 * @param {number[]} closes Close prices
 * @param {number} period CCI period
 * @return {Array<number|null>} Array of CCI values
 */
function computeCCIArrayLocal(
  highs: number[],
  lows: number[],
  closes: number[],
  period: number
): (number | null)[] {
  if (closes.length < period) return Array(closes.length).fill(null);

  const tp = closes.map((c, i) => (highs[i] + lows[i] + c) / 3);
  const result: (number | null)[] = Array(period - 1).fill(null);

  for (let i = period - 1; i < tp.length; i++) {
    const slice = tp.slice(i - period + 1, i + 1);
    const sma = slice.reduce((a, b) => a + b, 0) / period;
    const meanDev = slice.reduce((a, b) => a + Math.abs(b - sma), 0) / period;

    if (meanDev === 0) {
      result.push(0);
    } else {
      result.push((tp[i] - sma) / (0.015 * meanDev));
    }
  }

  // Align padding if logic off by 1
  const padding = closes.length - result.length;
  if (padding > 0) {
    return [...Array(padding).fill(null), ...result];
  }
  return result;
}

/**
 * Computes Williams %R array.
 * %R = (Highest High - Close) / (Highest High - Lowest Low) * -100
 * @param {number[]} highs High prices
 * @param {number[]} lows Low prices
 * @param {number[]} closes Close prices
 * @param {number} period Lookback period
 * @return {Array<number|null>} Array of Williams %R values
 */
function computeWilliamsRArrayLocal(
  highs: number[],
  lows: number[],
  closes: number[],
  period: number
): (number | null)[] {
  if (closes.length < period) return Array(closes.length).fill(null);

  const result: (number | null)[] = Array(period - 1).fill(null);

  for (let i = period - 1; i < closes.length; i++) {
    const start = i - period + 1;
    const end = i + 1; // slice is exclusive end

    // Slice arrays for window
    // Performance note: creating new arrays in loop is slow for big data,
    // but for 2y daily (~500 pts) it's negligible.
    let highest = -Infinity;
    let lowest = Infinity;

    for (let j=start; j<end; j++) {
      if (highs[j] > highest) highest = highs[j];
      if (lows[j] < lowest) lowest = lows[j];
    }

    const range = highest - lowest;
    if (range === 0) {
      result.push(0);
    } else {
      // Williams %R formula
      result.push(((highest - closes[i]) / range) * -100);
    }
  }
  return result;
}

/**
 * Computes Rate of Change (ROC) array.
 * ROC = ((Close - Close[prev]) / Close[prev]) * 100
 * @param {number[]} closes Close prices
 * @param {number} period Lookback period
 * @return {Array<number|null>} Array of ROC values
 */
function computeROCArrayLocal(
  closes: number[],
  period: number
): (number | null)[] {
  if (closes.length < period) return Array(closes.length).fill(null);

  const result: (number | null)[] = Array(period).fill(null);

  for (let i = period; i < closes.length; i++) {
    const prev = closes[i - period];
    if (prev === 0) {
      result.push(null);
    } else {
      result.push(((closes[i] - prev) / prev) * 100);
    }
  }
  return result;
}

/**
 * Computes Money Flow Index (MFI) array.
 * MFI = 100 - (100 / (1 + Money Ratio))
 * Money Ratio = Positive Money Flow / Negative Money Flow
 * @param {number[]} highs High prices
 * @param {number[]} lows Low prices
 * @param {number[]} closes Close prices
 * @param {number[]} volumes Volumes
 * @param {number} period Period
 * @return {Array<number|null>} Array of MFI values
 */
function computeMFIArrayLocal(
  highs: number[],
  lows: number[],
  closes: number[],
  volumes: number[],
  period: number
): (number | null)[] {
  if (closes.length < period + 1) return Array(closes.length).fill(null);

  // Typical Price = (H + L + C) / 3
  const tp = closes.map((c, i) => (highs[i] + lows[i] + c) / 3);

  // First valid index is at 'period' because of 1-period lookback for flow
  const result: (number | null)[] = Array(period).fill(null);

  for (let i = period; i < tp.length; i++) {
    // Window: [i - period + 1 ... i]
    // Flow calculation requires looking back 1 step within window

    let posFlow = 0;
    let negFlow = 0;

    // Check flows for the last 'period' days relative to i
    // Sequence of calculation: compare j to j-1
    // Range of j: (i - period + 1) to i
    for (let j = i - period + 1; j <= i; j++) {
      if (j === 0) continue;

      const rawMoneyFlow = tp[j] * volumes[j];
      if (tp[j] > tp[j - 1]) {
        posFlow += rawMoneyFlow;
      } else if (tp[j] < tp[j - 1]) {
        negFlow += rawMoneyFlow;
      }
    }

    if (negFlow === 0) {
      result.push(100);
    } else {
      const mr = posFlow / negFlow;
      result.push(100 - (100 / (1 + mr)));
    }
  }

  return result;
}

/**
 * Computes factor values time series based on config.
 * @param {AlphaFactorConfig} factor Configuration for the alpha factor
 * @param {number[]} closes Array of historical close prices
 * @param {number[]} highs Array of historical high prices
 * @param {number[]} lows Array of historical low prices
 * @param {number[]} volumes Array of historical volumes
 * @return {Array<number|null>} Array of computed factor values
 */
function computeFactorValues(
  factor: AlphaFactorConfig,
  closes: number[],
  highs?: number[],
  lows?: number[],
  volumes?: number[]
): (number | null)[] {
  switch (factor.type) {
  case "RSI": {
    const period = factor.parameters.period || 14;
    const rsiArr = computeRSIArray(closes, period);
    const rsiPadding = closes.length - rsiArr.length;
    return [...Array(rsiPadding).fill(null), ...rsiArr];
  }

  case "SMA_DISTANCE": {
    const smaPeriod = factor.parameters.period || 50;
    const smaArr = computeSMAArray(closes, smaPeriod);
    return smaArr.map((sma, i) => {
      if (sma === null || sma === 0) return null;
      return (closes[i] - sma) / sma;
    });
  }

  case "MACD_SIGNAL": {
    const fast = factor.parameters.fast || 12;
    const slow = factor.parameters.slow || 26;
    const signal = factor.parameters.signal || 9;

    const fastEMAs = computeEMAArray(closes, fast);
    const slowEMAs = computeEMAArray(closes, slow);

    const macdSeries: (number | null)[] = [];
    for (let i = 0; i < closes.length; i++) {
      if (fastEMAs[i] !== null && slowEMAs[i] !== null) {
        macdSeries.push(fastEMAs[i]! - slowEMAs[i]!);
      } else {
        macdSeries.push(null);
      }
    }

    const firstValidIdx = macdSeries.findIndex((v) => v !== null);
    if (firstValidIdx === -1) return Array(closes.length).fill(null);

    const validMACD = macdSeries.slice(firstValidIdx) as number[];
    const signalSeriesRaw = computeEMAArray(validMACD, signal);

    const signalSeries = [
      ...Array(firstValidIdx).fill(null),
      ...signalSeriesRaw,
    ];

    return macdSeries.map((m, i) => {
      const s = signalSeries[i];
      if (m !== null && s !== null) {
        return m - s;
      }
      return null;
    });
  }

  case "BB_WIDTH": {
    const bbPeriod = factor.parameters.period || 20;
    const stdDev = factor.parameters.stdDev || 2;
    const bbArr = computeBollingerBandsArray(closes, bbPeriod, stdDev);
    return bbArr.map((bb) => {
      if (bb === null) return null;
      if (bb.middle === 0) return null;
      return (bb.upper - bb.lower) / bb.middle;
    });
  }

  case "MOMENTUM": {
    const momPeriod = factor.parameters.period || 10;
    return closes.map((close, i) => {
      if (i < momPeriod) return null;
      const prev = closes[i - momPeriod];
      if (prev === 0) return null;
      return (close - prev) / prev;
    });
  }

  case "STOCHASTIC_K": {
    if (!highs || !lows) return Array(closes.length).fill(null);
    const kPeriod = factor.parameters.kPeriod || 14;
    const dPeriod = factor.parameters.dPeriod || 3;
    const stochArr = computeStochasticArray(
      highs, lows, closes, kPeriod, dPeriod
    );
    // stochArr maps to aligned index but returns object {k, d} or null
    return stochArr.map((val) => val ? val.k : null);
  }

  case "ATR": {
    if (!highs || !lows) return Array(closes.length).fill(null);
    const atrPeriod = factor.parameters.period || 14;
    return computeATRArray(highs, lows, closes, atrPeriod);
  }

  case "ADX": {
    if (!highs || !lows) return Array(closes.length).fill(null);
    const adxPeriod = factor.parameters.period || 14;
    return computeADXArrayLocal(highs, lows, closes, adxPeriod);
  }

  case "CCI": {
    if (!highs || !lows) return Array(closes.length).fill(null);
    const cciPeriod = factor.parameters.period || 20;
    return computeCCIArrayLocal(highs, lows, closes, cciPeriod);
  }

  case "OBV": {
    if (!volumes) return Array(closes.length).fill(null);
    // OBV is cumulative. Correlation needs stationary series?
    // Absolute OBV is non-stationary.
    // Use OBV Change (ROC) or OBV Slope?
    // Let's use OBV ROC (Momentum of OBV).
    const period = factor.parameters.period || 1; // Default to 1-day change
    const obvRaw = computeOBV(closes, volumes);
    if (!obvRaw) return Array(closes.length).fill(null);

    // Normalize to alignment (OBV array matches closes)
    if (period === 0) return obvRaw; // Return raw if period 0

    return obvRaw.map((val, i) => {
      if (i < period) return null;
      const prev = obvRaw[i - period];
      if (prev === 0) return 0; // Avoid div by zero
      return (val - prev) / Math.abs(prev);
    });
  }

  case "KELTNER_POSITION": {
    if (!highs || !lows) return Array(closes.length).fill(null);
    const kpPeriod = factor.parameters.period || 20;
    const kpAtrPeriod = factor.parameters.atrPeriod || 10;
    const kpMult = factor.parameters.multiplier || 1.5;

    const kcArr = computeKeltnerChannelsArray(
      highs, lows, closes, kpPeriod, kpAtrPeriod, kpMult
    );

    return kcArr.map((kc, i) => {
      if (!kc) return null;
      if (kc.upper === kc.lower) return 0;
      return (closes[i] - kc.lower) / (kc.upper - kc.lower);
    });
  }

  case "WILLIAMS_R": {
    if (!highs || !lows) return Array(closes.length).fill(null);
    const period = factor.parameters.period || 14;
    return computeWilliamsRArrayLocal(highs, lows, closes, period);
  }

  case "ROC": {
    const period = factor.parameters.period || 9;
    return computeROCArrayLocal(closes, period);
  }

  case "MFI": {
    if (!highs || !lows || !volumes) return Array(closes.length).fill(null);
    const period = factor.parameters.period || 14;
    return computeMFIArrayLocal(highs, lows, closes, volumes, period);
  }

  default:
    return Array(closes.length).fill(null);
  }
}

// --- Main Cloud Function ---

export const discoverAlphaFactors = onCall(async (request) => {
  // 1. Validate inputs
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be logged in.");
  }

  const {
    symbols = [
      "SPY", "QQQ", "IWM", "AAPL", "MSFT", "NVDA",
      "TSLA", "AMZN", "GOOGL", "META",
    ],
    startDate,
    endDate,
    factors,
    forwardHorizon = 5, // 5 days return
  } = request.data as AlphaDiscoveryRequest;

  // Determine needed range
  let range = "2y";
  if (startDate) {
    const start = new Date(startDate);
    const now = new Date();
    const diffYears = (now.getTime() - start.getTime()) /
      (1000 * 3600 * 24 * 365);
    if (diffYears > 10) range = "max";
    else if (diffYears > 5) range = "10y";
    else if (diffYears > 2) range = "5y";
  }

  logger.info("Starting Alpha Factor Discovery", {
    symbolsCount: symbols.length,
    factorsCount: factors.length,
    startDate,
    endDate,
    range,
  });

  const results: AlphaFactorResult[] = [];

  // Initialize results structure
  for (const factor of factors) {
    results.push({
      config: factor,
      globalIC: 0,
      icStdDev: 0,
      icir: 0,
      symbolBreakdown: [],
      status: "SUCCESS",
    });
  }

  // 2. Iterate Universe in Parallel
  // Rate limiting to 5 concurrent requests to avoid API bans (Yahoo/Plaid etc)
  const CONCURRENT_LIMIT = 5;
  for (let i = 0; i < symbols.length; i += CONCURRENT_LIMIT) {
    // Add delay between batches to throttle API requests
    if (i > 0) {
      await delay(1000);
    }
    const chunk = symbols.slice(i, i + CONCURRENT_LIMIT);
    await Promise.all(chunk.map(async (symbol) => {
      try {
        // 2a. Get Data
        const marketData = await getMarketData(symbol, 50, 200, "1d", range);
        const closes = marketData.closes;
        const highs = marketData.highs;
        const lows = marketData.lows;
        const volumes = marketData.volumes;
        const timestamps = marketData.timestamps;

        if (!closes || closes.length < 100) {
          logger.warn(`Insufficient data for ${symbol}`);
          return;
        }

        // 2b. Compute Forward Returns
        const forwardReturns = calculateForwardReturns(closes, forwardHorizon);

        // 2c. Define Filter Mask
        // We only correlate where timestamp is within requested window
        const startTs = startDate ?
          new Date(startDate).getTime() / 1000 : 0;
        const endTs = endDate ?
          new Date(endDate).getTime() / 1000 : Number.MAX_SAFE_INTEGER;

        const validIndices: number[] = [];
        if (timestamps) {
          for (let t = 0; t < timestamps.length; t++) {
            if (timestamps[t] >= startTs && timestamps[t] <= endTs) {
              validIndices.push(t);
            }
          }
        } else {
          // Fallback if no timestamps
          // (shouldn't happen with valid getMarketData)
          for (let t = 0; t < closes.length; t++) validIndices.push(t);
        }

        if (validIndices.length < 20) {
          // Skip if not enough data in selected window
          return;
        }

        // 2d. Test Factors
        for (let j = 0; j < factors.length; j++) {
          const factor = factors[j];
          let values: (number | null)[] = [];

          try {
            values = computeFactorValues(factor, closes, highs, lows, volumes);
          } catch (e) {
            logger.error(
              `Error computing factor ${factor.name} for ${symbol}`, e
            );
            continue;
          }

          // 2e. Apply Filter and Compute Correlation
          const filteredValues = validIndices.map((idx) => values[idx]);
          const filteredReturns = validIndices.map((idx) =>
            forwardReturns[idx]);

          const ic = calculateCorrelation(filteredValues, filteredReturns);

          if (ic !== null) {
            results[j].symbolBreakdown.push({
              symbol,
              correlation: ic,
              count: filteredValues.filter((v) => v !== null).length,
            });
          }
        }
      } catch (e) {
        logger.error(`Error processing symbol ${symbol}`, e);
      }
    }));
  }

  // 3. Aggregate Results
  for (const result of results) {
    const correlations = result.symbolBreakdown
      .map((s) => s.correlation)
      .filter((c) => c !== null) as number[];

    if (correlations.length > 0) {
      const sum = correlations.reduce((a, b) => a + b, 0);
      const mean = sum / correlations.length;

      // Standard Deviation of IC across symbols (spatial consistency)
      const sqDiffs = correlations.map((c) => Math.pow(c - mean, 2));
      const avgSqDiff =
        sqDiffs.reduce((a, b) => a + b, 0) / correlations.length;
      const stdDev = Math.sqrt(avgSqDiff);

      result.globalIC = mean;
      result.icStdDev = stdDev;
      result.icir = stdDev !== 0 ? mean / stdDev : 0;
    } else {
      result.status = "ERROR";
      result.error = "No valid correlations computed.";
    }
  }

  // 4. Sort by absolute ICIR (strength of signal regardless of direction)
  results.sort((a, b) => Math.abs(b.icir) - Math.abs(a.icir));

  return { results };
});
