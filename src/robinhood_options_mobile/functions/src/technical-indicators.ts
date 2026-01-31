/**
 * Technical Indicators Module
 * Implements various technical analysis indicators for automated trading
 */

export interface IndicatorResult {
  value: number | null;
  signal: "BUY" | "SELL" | "HOLD";
  reason: string;
  metadata?: Record<string, unknown>;
}

export interface CustomIndicatorConfig {
  id: string;
  name: string;
  type: "SMA" | "EMA" | "RSI" | "MACD" |
  "Bollinger" | "Stochastic" | "ATR" | "OBV" |
  "WilliamsR" | "CCI" | "ROC" | "VWAP" | "ADX";
  parameters: Record<string, number | string | boolean>;
  condition: "GreaterThan" | "LessThan" | "CrossOverAbove" | "CrossOverBelow";
  threshold?: number;
  compareToPrice?: boolean;
  signalType?: "BUY" | "SELL";
}

export interface MultiIndicatorResult {
  allGreen: boolean;
  indicators: {
    priceMovement: IndicatorResult;
    momentum: IndicatorResult;
    marketDirection: IndicatorResult;
    volume: IndicatorResult;
    macd: IndicatorResult;
    bollingerBands: IndicatorResult;
    stochastic: IndicatorResult;
    atr: IndicatorResult;
    obv: IndicatorResult;
    vwap: IndicatorResult;
    adx: IndicatorResult;
    williamsR: IndicatorResult;
    ichimoku: IndicatorResult;
    cci: IndicatorResult;
    parabolicSar: IndicatorResult;
  };
  customIndicators?: Record<string, IndicatorResult>;
  macroAssessment?: {
    status: "RISK_ON" | "RISK_OFF" | "NEUTRAL";
    score: number;
    reason: string;
  };
  overallSignal: "BUY" | "SELL" | "HOLD";
  reason: string;
  signalStrength: number; // 0-100 score based on indicator alignment
}

/**
 * Compute Simple Moving Average (SMA)
 * @param {number[]} prices - Array of prices.
 * @param {number} period - The period for the SMA.
 * @return {number|null} The computed SMA or null if not enough data.
 */
export function computeSMA(prices: number[], period: number): number | null {
  if (!prices || prices.length < period || period <= 0) return null;

  let sum = 0;
  for (let i = prices.length - period; i < prices.length; i++) {
    sum += prices[i];
  }
  return sum / period;
}

/**
 * Compute array of SMA values
 * @param {number[]} prices - Array of prices
 * @param {number} period - SMA period
 * @return {(number|null)[]} Array of SMA values
 */
export function computeSMAArray(
  prices: number[],
  period: number
): (number | null)[] {
  if (!prices || prices.length < period || period <= 0) {
    return Array(prices.length).fill(null);
  }

  const result: (number | null)[] = Array(period - 1).fill(null);
  let sum = 0;

  // First sum
  for (let i = 0; i < period; i++) {
    sum += prices[i];
  }
  result.push(sum / period);

  // Sliding window
  for (let i = period; i < prices.length; i++) {
    sum += prices[i] - prices[i - period];
    result.push(sum / period);
  }

  return result;
}

/**
 * Compute Exponential Moving Average (EMA)
 * @param {number[]} prices - Array of prices.
 * @param {number} period - The period for the EMA.
 * @return {number|null} The computed EMA or null if not enough data.
 */
export function computeEMA(prices: number[], period: number): number | null {
  if (!prices || prices.length < period || period <= 0) return null;

  const multiplier = 2 / (period + 1);
  let sum = 0;
  for (let i = 0; i < period; i++) {
    sum += prices[i];
  }
  let ema = sum / period;

  for (let i = period; i < prices.length; i++) {
    ema = (prices[i] - ema) * multiplier + ema;
  }

  return ema;
}

/**
 * Compute array of EMA values
 * @param {number[]} prices - Array of prices
 * @param {number} period - EMA period
 * @return {(number|null)[]} Array of smoothed EMA values
 */
export function computeEMAArray(
  prices: number[],
  period: number
): (number | null)[] {
  if (!prices || prices.length < period || period <= 0) {
    return Array(prices.length).fill(null);
  }

  const result: (number | null)[] = Array(period - 1).fill(null);

  const multiplier = 2 / (period + 1);
  // Initial SMA
  let ema = prices.slice(0, period).reduce((a, b) => a + b, 0) / period;
  result.push(ema);

  for (let i = period; i < prices.length; i++) {
    ema = (prices[i] - ema) * multiplier + ema;
    result.push(ema);
  }

  return result;
}

/**
 * Compute Relative Strength Index (RSI)
 * @param {number[]} prices - Array of prices.
 * @param {number} period - The period for RSI calculation (default 14).
 * @return {number|null} The computed RSI or null if not enough data.
 */
export function computeRSI(prices: number[], period = 14): number | null {
  const arr = computeRSIArray(prices, period);
  if (arr.length === 0) return null;
  return arr[arr.length - 1];
}

/**
 * Compute array of RSI values
 * @param {number[]} prices - Array of prices
 * @param {number} period - RSI period
 * @return {number[]} Array of RSI values corresponding to prices[period..end]
 */
export function computeRSIArray(prices: number[], period = 14): number[] {
  if (!prices || prices.length < period + 1) return [];

  const changes: number[] = [];
  for (let i = 1; i < prices.length; i++) {
    changes.push(prices[i] - prices[i - 1]);
  }

  const rsiValues: number[] = [];
  let gains = 0;
  let losses = 0;

  // Initial average gains and losses
  for (let i = 0; i < period; i++) {
    if (changes[i] > 0) {
      gains += changes[i];
    } else {
      losses += Math.abs(changes[i]);
    }
  }

  let avgGain = gains / period;
  let avgLoss = losses / period;

  // First RSI
  if (avgLoss === 0) {
    rsiValues.push(100);
  } else {
    rsiValues.push(100 - (100 / (1 + avgGain / avgLoss)));
  }

  // Calculate RSI using smoothed averages
  for (let i = period; i < changes.length; i++) {
    const change = changes[i];
    let currentGain = 0;
    let currentLoss = 0;
    if (change > 0) {
      currentGain = change;
    } else {
      currentLoss = Math.abs(change);
    }

    avgGain = (avgGain * (period - 1) + currentGain) / period;
    avgLoss = (avgLoss * (period - 1) + currentLoss) / period;

    if (avgLoss === 0) {
      rsiValues.push(100);
    } else {
      rsiValues.push(100 - (100 / (1 + avgGain / avgLoss)));
    }
  }

  return rsiValues;
}

/**
 * Compute MACD (Moving Average Convergence Divergence)
 * @param {number[]} prices - Array of prices.
 * @param {number} fastPeriod - Fast EMA period (default 12).
 * @param {number} slowPeriod - Slow EMA period (default 26).
 * @param {number} signalPeriod - Signal line EMA period (default 9).
 * @return {{macd: number, signal: number, histogram: number}|null}
 */
export function computeMACD(
  prices: number[],
  fastPeriod = 12,
  slowPeriod = 26,
  signalPeriod = 9
): { macd: number; signal: number; histogram: number } | null {
  if (!prices || prices.length < slowPeriod + signalPeriod) return null;

  // Optimized computation using arrays O(N) instead of recurring O(N^2)
  const fastEMAs = computeEMAArray(prices, fastPeriod);
  const slowEMAs = computeEMAArray(prices, slowPeriod);

  // We need the sequence of MACD values to compute the Signal line
  // MACD line is valid where both EMAs are valid.
  // Slow EMA is the bottleneck, valid from index (slowPeriod - 1).
  const macdSeries: number[] = [];

  // We align with original prices to pick the last one correctly,
  // but for computeEMAArray(macdSeries) we need a clean array of numbers.

  for (let i = 0; i < prices.length; i++) {
    const fast = fastEMAs[i];
    const slow = slowEMAs[i];
    if (fast !== null && slow !== null) {
      macdSeries.push(fast - slow);
    }
  }

  if (macdSeries.length < signalPeriod) return null;

  const signalLineSeries = computeEMAArray(macdSeries, signalPeriod);

  // Last values
  const macdLine = macdSeries[macdSeries.length - 1];
  const signalLine = signalLineSeries[signalLineSeries.length - 1];

  if (signalLine === null) return null;

  const histogram = macdLine - signalLine;

  return {
    macd: macdLine,
    signal: signalLine,
    histogram,
  };
}

/**
 * Compute Bollinger Bands
 * @param {number[]} prices - Array of prices.
 * @param {number} period - Period for SMA (default 20).
 * @param {number} stdDev - Number of standard deviations (default 2).
 * @return {{upper: number, middle: number, lower: number}|null}
 */
export function computeBollingerBands(
  prices: number[],
  period = 20,
  stdDev = 2
): { upper: number; middle: number; lower: number } | null {
  if (!prices || prices.length < period) return null;

  const middle = computeSMA(prices, period);
  if (!middle) return null;

  const slice = prices.slice(prices.length - period);
  const squaredDiffs = slice.map((p) => Math.pow(p - middle, 2));
  // Use sample standard deviation (N-1) for Bollinger Bands
  const varianceDenom = period > 1 ? (period - 1) : period;
  const varianceSum = squaredDiffs.reduce((a, b) => a + b, 0);
  const variance = varianceSum / varianceDenom;
  const standardDeviation = Math.sqrt(variance);

  const upper = middle + stdDev * standardDeviation;
  const lower = middle - stdDev * standardDeviation;

  return { upper, middle, lower };
}

/**
 * Compute array of Stochastic values
 * @param {number[]} highs - Array of high prices
 * @param {number[]} lows - Array of low prices
 * @param {number[]} closes - Array of close prices
 * @param {number} kPeriod - %K period
 * @param {number} dPeriod - %D period
 * @return {Array<{k: number, d: number}|null>} Array of Stochastic values
 */
export function computeStochasticArray(
  highs: number[],
  lows: number[],
  closes: number[],
  kPeriod = 14,
  dPeriod = 3
): ({ k: number; d: number } | null)[] {
  if (!highs || !lows || !closes ||
    highs.length < kPeriod ||
    lows.length < kPeriod ||
    closes.length < kPeriod) {
    return Array(closes.length).fill(null);
  }

  const result: ({ k: number; d: number } | null)[] =
    Array(kPeriod - 1).fill(null);

  const kValues: number[] = [];

  // Calculate raw K values for the whole series starting from index kPeriod - 1
  for (let i = kPeriod - 1; i < closes.length; i++) {
    let hh = Number.NEGATIVE_INFINITY;
    let ll = Number.POSITIVE_INFINITY;
    // Look back kPeriod bars including current
    for (let j = 0; j < kPeriod; j++) {
      const valH = highs[i - j];
      const valL = lows[i - j];
      if (valH > hh) hh = valH;
      if (valL < ll) ll = valL;
    }

    if (hh !== ll && Number.isFinite(hh) && Number.isFinite(ll)) {
      kValues.push(((closes[i] - ll) / (hh - ll)) * 100);
    } else {
      kValues.push(50); // Default to middle if no range
    }
  }

  // Now calculate D (SMA of K)
  // kValues[0] corresponds to index kPeriod - 1
  // We need dPeriod kValues to calculate first D

  // Align result with input array
  // result has kPeriod - 1 nulls.
  // We can calculate D starting from index (kPeriod - 1) + (dPeriod - 1)

  if (kValues.length < dPeriod) {
    // Fill remaining with nulls or partial K?
    // Usually we just return nulls if we can't compute D
    return Array(closes.length).fill(null);
  }

  // Helper to compute SMA on a slice of K values
  const getSMA = (arr: number[], idx: number, p: number) => {
    let sum = 0;
    for (let j = 0; j < p; j++) {
      sum += arr[idx - j];
    }
    return sum / p;
  };

  // Before we have enough K values for D, we can either put nulls or just K
  // Standard practice: D is valid only after dPeriod K values.

  // Add nulls for the gap where D cannot be calculated yet
  for (let i = 0; i < dPeriod - 1; i++) {
    result.push(null);
  }

  // Calculate D for the rest
  for (let i = dPeriod - 1; i < kValues.length; i++) {
    const k = kValues[i];
    const d = getSMA(kValues, i, dPeriod);
    result.push({ k, d });
  }

  return result;
}

/**
 * Compute Stochastic Oscillator
 * @param {number[]} highs - Array of high prices.
 * @param {number[]} lows - Array of low prices.
 * @param {number[]} closes - Array of close prices.
 * @param {number} kPeriod - %K period (default 14).
 * @param {number} dPeriod - %D period (default 3).
 * @return {{k: number, d: number}|null}
 */
export function computeStochastic(
  highs: number[],
  lows: number[],
  closes: number[],
  kPeriod = 14,
  dPeriod = 3
): { k: number; d: number } | null {
  const arr = computeStochasticArray(
    highs,
    lows,
    closes,
    kPeriod,
    dPeriod
  );
  if (arr.length === 0) return null;
  return arr[arr.length - 1];
}

/**
 * Compute Average True Range (ATR)
 * @param {number[]} highs - Array of high prices.
 * @param {number[]} lows - Array of low prices.
 * @param {number[]} closes - Array of close prices.
 * @param {number} period - Period for ATR (default 14).
 * @return {number|null}
 */
export function computeATR(
  highs: number[],
  lows: number[],
  closes: number[],
  period = 14
): number | null {
  const arr = computeATRArray(highs, lows, closes, period);
  if (arr.length === 0) return null;
  return arr[arr.length - 1];
}

/**
 * Compute array of ATR values
 * @param {number[]} highs
 * @param {number[]} lows
 * @param {number[]} closes
 * @param {number} period
 * @return {(number|null)[]} Array of ATR values aligned with inputs
 */
export function computeATRArray(
  highs: number[],
  lows: number[],
  closes: number[],
  period = 14
): (number | null)[] {
  if (!highs || !lows || !closes ||
    highs.length < period + 1 ||
    lows.length < period + 1 ||
    closes.length < period + 1) {
    return Array(closes.length).fill(null);
  }

  const result: (number | null)[] = Array(period).fill(null);
  const trueRanges: number[] = [];

  // Calculate TRs first (start from index 1)
  // Index 0 has no TR because no prior close.
  // TR[i] corresponds to candle i

  // First TR logic check:
  // computeATR loop: for (let i = 1; i < closes.length; i++)
  // trueRanges has length = closes.length - 1

  for (let i = 1; i < closes.length; i++) {
    const high = highs[i];
    const low = lows[i];
    const prevClose = closes[i - 1];

    const tr = Math.max(
      high - low,
      Math.abs(high - prevClose),
      Math.abs(low - prevClose)
    );
    trueRanges.push(tr);
  }

  // Initial ATR: average of first 'period' TRs
  // These TRs correspond to indices 1 to period
  let atr = trueRanges.slice(0, period).reduce((a, b) => a + b, 0) / period;
  result.push(atr);

  // Smoothed ATR
  // Continue from index = period + 1 (in closes array terms)
  // which is index 'period' in trueRanges
  for (let i = period; i < trueRanges.length; i++) {
    atr = (atr * (period - 1) + trueRanges[i]) / period;
    result.push(atr);
  }

  return result;
}

/**
 * Compute On-Balance Volume (OBV)
 * @param {number[]} closes - Array of close prices.
 * @param {number[]} volumes - Array of volumes.
 * @return {number[]|null} Array of OBV values or null if insufficient data.
 */
export function computeOBV(
  closes: number[],
  volumes: number[]
): number[] | null {
  if (!closes || !volumes || closes.length < 2 || volumes.length < 2 ||
    closes.length !== volumes.length) {
    return null;
  }

  // Start OBV from 0 to avoid scale bias on first bar
  const obv: number[] = [0];

  for (let i = 1; i < closes.length; i++) {
    if (closes[i] > closes[i - 1]) {
      obv.push(obv[obv.length - 1] + volumes[i]);
    } else if (closes[i] < closes[i - 1]) {
      obv.push(obv[obv.length - 1] - volumes[i]);
    } else {
      obv.push(obv[obv.length - 1]);
    }
  }

  return obv;
}

/**
 * Compute Volume Weighted Average Price (VWAP)
 * @param {number[]} highs - Array of high prices.
 * @param {number[]} lows - Array of low prices.
 * @param {number[]} closes - Array of close prices.
 * @param {number[]} volumes - Array of volumes.
 * @return {number|null} The computed VWAP or null if insufficient data.
 */
export function computeVWAP(
  highs: number[],
  lows: number[],
  closes: number[],
  volumes: number[]
): number | null {
  if (!highs || !lows || !closes || !volumes ||
    highs.length < 1 || lows.length < 1 ||
    closes.length < 1 || volumes.length < 1 ||
    highs.length !== lows.length ||
    lows.length !== closes.length ||
    closes.length !== volumes.length) {
    return null;
  }

  let cumulativeTPV = 0; // Typical Price * Volume
  let cumulativeVolume = 0;

  for (let i = 0; i < closes.length; i++) {
    const typicalPrice = (highs[i] + lows[i] + closes[i]) / 3;
    cumulativeTPV += typicalPrice * volumes[i];
    cumulativeVolume += volumes[i];
  }

  if (cumulativeVolume === 0) return null;

  return cumulativeTPV / cumulativeVolume;
}

/**
 * Compute ADX (Average Directional Index)
 * @param {number[]} highs - Array of high prices.
 * @param {number[]} lows - Array of low prices.
 * @param {number[]} closes - Array of close prices.
 * @param {number} period - Period for ADX calculation (default 14).
 * @return {{adx: number, plusDI: number, minusDI: number}|null}
 */
export function computeADX(
  highs: number[],
  lows: number[],
  closes: number[],
  period = 14
): { adx: number; plusDI: number; minusDI: number } | null {
  if (!highs || !lows || !closes ||
    highs.length < period * 2 ||
    lows.length < period * 2 ||
    closes.length < period * 2) {
    return null;
  }

  const plusDM: number[] = [];
  const minusDM: number[] = [];
  const tr: number[] = [];

  // Calculate +DM, -DM, and TR
  for (let i = 1; i < highs.length; i++) {
    const highDiff = highs[i] - highs[i - 1];
    const lowDiff = lows[i - 1] - lows[i];

    if (highDiff > lowDiff && highDiff > 0) {
      plusDM.push(highDiff);
    } else {
      plusDM.push(0);
    }

    if (lowDiff > highDiff && lowDiff > 0) {
      minusDM.push(lowDiff);
    } else {
      minusDM.push(0);
    }

    const trueRange = Math.max(
      highs[i] - lows[i],
      Math.abs(highs[i] - closes[i - 1]),
      Math.abs(lows[i] - closes[i - 1])
    );
    tr.push(trueRange);
  }

  if (plusDM.length < period || minusDM.length < period || tr.length < period) {
    return null;
  }

  // Calculate smoothed values using Wilder's smoothing
  const smoothedPlusDM: number[] = [];
  const smoothedMinusDM: number[] = [];
  const smoothedTR: number[] = [];

  // Initial smoothed values (sum of first 'period' values)
  let sumPlusDM = plusDM.slice(0, period).reduce((a, b) => a + b, 0);
  let sumMinusDM = minusDM.slice(0, period).reduce((a, b) => a + b, 0);
  let sumTR = tr.slice(0, period).reduce((a, b) => a + b, 0);

  smoothedPlusDM.push(sumPlusDM);
  smoothedMinusDM.push(sumMinusDM);
  smoothedTR.push(sumTR);

  // Wilder's smoothing for subsequent values
  for (let i = period; i < plusDM.length; i++) {
    sumPlusDM = sumPlusDM - (sumPlusDM / period) + plusDM[i];
    sumMinusDM = sumMinusDM - (sumMinusDM / period) + minusDM[i];
    sumTR = sumTR - (sumTR / period) + tr[i];

    smoothedPlusDM.push(sumPlusDM);
    smoothedMinusDM.push(sumMinusDM);
    smoothedTR.push(sumTR);
  }

  // Calculate +DI and -DI
  const plusDI: number[] = [];
  const minusDI: number[] = [];
  const dx: number[] = [];

  for (let i = 0; i < smoothedTR.length; i++) {
    if (smoothedTR[i] === 0) {
      plusDI.push(0);
      minusDI.push(0);
      dx.push(0);
      continue;
    }

    const pdi = (smoothedPlusDM[i] / smoothedTR[i]) * 100;
    const mdi = (smoothedMinusDM[i] / smoothedTR[i]) * 100;
    plusDI.push(pdi);
    minusDI.push(mdi);

    const diSum = pdi + mdi;
    if (diSum === 0) {
      dx.push(0);
    } else {
      dx.push((Math.abs(pdi - mdi) / diSum) * 100);
    }
  }

  if (dx.length < period) return null;

  // Calculate ADX (smoothed average of DX)
  let adx = dx.slice(0, period).reduce((a, b) => a + b, 0) / period;
  for (let i = period; i < dx.length; i++) {
    adx = ((adx * (period - 1)) + dx[i]) / period;
  }

  const lastPlusDI = plusDI[plusDI.length - 1];
  const lastMinusDI = minusDI[minusDI.length - 1];

  return {
    adx,
    plusDI: lastPlusDI,
    minusDI: lastMinusDI,
  };
}

/**
 * Compute Williams %R
 * @param {number[]} highs - Array of high prices.
 * @param {number[]} lows - Array of low prices.
 * @param {number[]} closes - Array of close prices.
 * @param {number} period - Period for calculation (default 14).
 * @return {number|null} The computed Williams %R or null if insufficient data.
 */
export function computeWilliamsR(
  highs: number[],
  lows: number[],
  closes: number[],
  period = 14
): number | null {
  if (!highs || !lows || !closes ||
    highs.length < period ||
    lows.length < period ||
    closes.length < period) {
    return null;
  }

  const recentHighs = highs.slice(-period);
  const recentLows = lows.slice(-period);
  const currentClose = closes[closes.length - 1];

  const highestHigh = Math.max(...recentHighs);
  const lowestLow = Math.min(...recentLows);

  if (highestHigh === lowestLow) return null;

  // Williams %R: (Highest High - Close) / (Highest High - Lowest Low) * -100
  const range = highestHigh - lowestLow;
  const williamsR = ((highestHigh - currentClose) / range) * -100;

  return williamsR;
}

/**
 * Detect chart patterns for price movement
 * Simplified pattern detection based on recent price action
 * @param {number[]} prices - Array of historical prices.
 * @param {number[]} volumes - Optional array of volumes.
 * @param {Array<number>} opens - Optional array of open prices for candlestick.
 * @param {Array<number>} highs - Optional array of high prices for candlestick.
 * @param {Array<number>} lows - Optional array of low prices for candlestick.
 * @return {IndicatorResult} The pattern detection result.
 */
export function detectChartPattern(
  prices: number[],
  volumes?: number[],
  opens?: number[],
  highs?: number[],
  lows?: number[]
): IndicatorResult {
  // Expanded multi-pattern heuristic based detection
  // Volumes (if supplied) can confirm breakouts (higher relative volume)
  const minBars = 30; // minimum history for multi-pattern set
  if (!prices || prices.length < minBars) {
    return {
      value: null,
      signal: "HOLD",
      reason: `Need ${minBars}+ bars for pattern scan`,
    };
  }

  const lookback = 60; // maximum historical window inspected
  const windowPrices = prices.slice(-Math.min(lookback, prices.length));
  // Short window for moving averages and breakout checks
  const recentPrices = windowPrices.slice(-30);
  const currentPrice = recentPrices[recentPrices.length - 1];
  const prevPrice = recentPrices[recentPrices.length - 2];

  // Moving averages for trend context
  const ma5 = computeSMA(recentPrices, 5);
  const ma10 = computeSMA(recentPrices, 10);
  const ma20 = computeSMA(recentPrices, 20);
  if (!ma5 || !ma10 || !ma20) {
    return {
      value: null,
      signal: "HOLD",
      reason: "Unable to compute moving averages for pattern detection",
    };
  }

  // Helper: linear regression slope (simplified) for overall trend direction
  const slope = (() => {
    const n = recentPrices.length;
    const xSum = (n * (n - 1)) / 2;
    const xMean = xSum / n;
    const yMean = recentPrices.reduce((a, b) => a + b, 0) / n;
    let num = 0;
    let den = 0;
    for (let i = 0; i < n; i++) {
      const x = i;
      const y = recentPrices[i];
      num += (x - xMean) * (y - yMean);
      den += (x - xMean) * (x - xMean);
    }
    return den === 0 ? 0 : num / den;
  })();

  /**
   * Find local extrema indices using a 2-bar look-back/look-forward.
   * @param {number[]} pr Price array
   * @return {{peaks:number[], troughs:number[]}} Peak & trough indices
   */
  function findExtrema(pr: number[]): { peaks: number[]; troughs: number[] } {
    const peaks: number[] = [];
    const troughs: number[] = [];
    for (let i = 2; i < pr.length - 2; i++) {
      const p = pr[i];
      if (p > pr[i - 1] && p > pr[i - 2] && p > pr[i + 1] && p > pr[i + 2]) {
        peaks.push(i);
      }
      if (p < pr[i - 1] && p < pr[i - 2] && p < pr[i + 1] && p < pr[i + 2]) {
        troughs.push(i);
      }
    }
    return { peaks, troughs };
  }

  const { peaks, troughs } = findExtrema(windowPrices);

  // Utility to get price at index (from full window)
  const px = (i: number) => windowPrices[i];

  interface PatternCandidate {
    key: string;
    label: string;
    direction: "bullish" | "bearish" | "neutral";
    confidence: number; // 0..1
    details?: Record<string, unknown>;
  }

  const patterns: PatternCandidate[] = [];

  // 1. Breakout / Breakdown (price crossing longer MA + momentum)
  const breakout = currentPrice > ma20 * 1.02 &&
    currentPrice > ma10 && prevPrice <= ma20 * 1.02;
  if (breakout) {
    // Volume confirmation
    let volumeBoost = 0;
    if (volumes && volumes.length >= 30) {
      const recentVol = volumes.slice(-30);
      const avgVol = recentVol.reduce((a, b) => a + b, 0) / recentVol.length;
      const lastVol = recentVol[recentVol.length - 1];
      volumeBoost = lastVol > avgVol * 1.3 ? 0.15 : 0;
    }
    patterns.push({
      key: "breakout",
      label: "Price Breakout",
      direction: "bullish",
      confidence: 0.6 + volumeBoost,
      details: { ma10, ma20, currentPrice },
    });
  }
  const breakdown = currentPrice < ma20 * 0.98 &&
    currentPrice < ma10 && prevPrice >= ma20 * 0.98;
  if (breakdown) {
    let volumeBoost = 0;
    if (volumes && volumes.length >= 30) {
      const recentVol = volumes.slice(-30);
      const avgVol = recentVol.reduce((a, b) => a + b, 0) / recentVol.length;
      const lastVol = recentVol[recentVol.length - 1];
      volumeBoost = lastVol > avgVol * 1.3 ? 0.15 : 0;
    }
    patterns.push({
      key: "breakdown",
      label: "Price Breakdown",
      direction: "bearish",
      confidence: 0.6 + volumeBoost,
      details: { ma10, ma20, currentPrice },
    });
  }

  // 2. Double Top / Double Bottom
  const tolerancePct = 0.02; // 2% tolerance for peak/trough height similarity

  // Double Top
  if (peaks.length >= 2) {
    const idxA = peaks[peaks.length - 2];
    const idxB = peaks[peaks.length - 1];
    const valA = px(idxA);
    const valB = px(idxB);

    // Check if peaks are similar in height
    const similarHeight = Math.abs(valA - valB) / ((valA + valB) / 2) <
      tolerancePct;

    if (similarHeight) {
      // Find the neckline (lowest trough between the two peaks)
      const intervalPrices = windowPrices.slice(idxA, idxB);
      const neckline = intervalPrices.length > 0 ?
        Math.min(...intervalPrices) :
        Number.POSITIVE_INFINITY;

      // Confirmation: Price breaks below neckline
      const breakdown = currentPrice < neckline * 0.995;
      // Or forming: Second peak just formed and price dropped slightly
      const forming = currentPrice < valB * 0.98 && currentPrice > neckline;

      if (breakdown || forming) {
        patterns.push({
          key: "double_top",
          label: "Double Top",
          direction: "bearish",
          confidence: breakdown ? 0.7 : 0.5,
          details: { valA, valB, neckline },
        });
      }
    }
  }

  // Double Bottom
  if (troughs.length >= 2) {
    const idxA = troughs[troughs.length - 2];
    const idxB = troughs[troughs.length - 1];
    const valA = px(idxA);
    const valB = px(idxB);

    // Check if troughs are similar in depth
    const similarOne = Math.abs(valA - valB) / ((valA + valB) / 2) <
      tolerancePct;

    if (similarOne) {
      // Find the neckline (highest peak between the two troughs)
      const intervalPrices = windowPrices.slice(idxA, idxB);
      const neckline = intervalPrices.length > 0 ?
        Math.max(...intervalPrices) :
        Number.NEGATIVE_INFINITY;

      // Confirmation: Price breaks above neckline
      const breakout = currentPrice > neckline * 1.005;
      // Or forming: Second trough formed and price rising
      const forming = currentPrice > valB * 1.02 && currentPrice < neckline;

      if (breakout || forming) {
        patterns.push({
          key: "double_bottom",
          label: "Double Bottom",
          direction: "bullish",
          confidence: breakout ? 0.7 : 0.5,
          details: { valA, valB, neckline },
        });
      }
    }
  }

  // 3. Head & Shoulders
  if (peaks.length >= 3) {
    const idx1 = peaks[peaks.length - 3];
    const idx2 = peaks[peaks.length - 2];
    const idx3 = peaks[peaks.length - 1];
    const p1 = px(idx1); // Left Shoulder
    const p2 = px(idx2); // Head
    const p3 = px(idx3); // Right Shoulder

    // Head must be higher than shoulders
    const headHigher = p2 > p1 && p2 > p3;
    // Shoulders should be roughly level
    const shouldersLevel = Math.abs(p1 - p3) / ((p1 + p3) / 2) < 0.05;

    if (headHigher && shouldersLevel) {
      // Neckline: Line connecting the two troughs
      // Trough 1: between Left Shoulder and Head
      const t1Slice = windowPrices.slice(idx1, idx2);
      const t1 = t1Slice.length ? Math.min(...t1Slice) : 0;
      // Trough 2: between Head and Right Shoulder
      const t2Slice = windowPrices.slice(idx2, idx3);
      const t2 = t2Slice.length ? Math.min(...t2Slice) : 0;

      const necklineAvg = (t1 + t2) / 2;

      // Break of neckline
      const breakdown = currentPrice < Math.min(t1, t2) * 0.99;
      // Forming right shoulder decline
      const forming = currentPrice < p3 && currentPrice > necklineAvg;

      if (breakdown || forming) {
        patterns.push({
          key: "head_shoulders",
          label: "Head & Shoulders",
          direction: "bearish",
          confidence: breakdown ? 0.75 : 0.55,
          details: { left: p1, head: p2, right: p3, neckline: necklineAvg },
        });
      }
    }
  }

  // 4. Triangles (ascending, descending, symmetrical)
  /** Detect ascending triangle
   * @return {PatternCandidate|null} Asc triangle or null
   */
  function isAscendingTriangle(): PatternCandidate | null {
    if (peaks.length < 3 || troughs.length < 3) return null;
    const lastPeaks = peaks.slice(-3).map(px);
    const lastTroughs = troughs.slice(-3).map(px);
    const flatHighs = Math.max(...lastPeaks) - Math.min(...lastPeaks);
    const risingLows = lastTroughs[0] < lastTroughs[1] &&
      lastTroughs[1] < lastTroughs[2];
    if (flatHighs / ((lastPeaks[0] + lastPeaks[2]) / 2) < 0.015 && risingLows) {
      const breakoutPending = currentPrice > lastPeaks[2] * 0.995;
      return {
        key: "ascending_triangle",
        label: "Ascending Triangle",
        direction: breakoutPending ? "bullish" : "neutral",
        confidence: breakoutPending ? 0.6 : 0.45,
        details: { highs: lastPeaks, lows: lastTroughs },
      };
    }
    return null;
  }
  /** Detect descending triangle
   * @return {PatternCandidate|null} Desc triangle or null
   */
  function isDescendingTriangle(): PatternCandidate | null {
    if (peaks.length < 3 || troughs.length < 3) return null;
    const lastPeaks = peaks.slice(-3).map(px);
    const lastTroughs = troughs.slice(-3).map(px);
    const flatLows = Math.max(...lastTroughs) - Math.min(...lastTroughs);
    const fallingHighs = lastPeaks[0] > lastPeaks[1] &&
      lastPeaks[1] > lastPeaks[2];
    const lowFlat = flatLows / ((lastTroughs[0] + lastTroughs[2]) / 2) <
      0.015 && fallingHighs;
    if (lowFlat) {
      const breakdownPending = currentPrice < lastTroughs[2] * 1.005;
      return {
        key: "descending_triangle",
        label: "Descending Triangle",
        direction: breakdownPending ? "bearish" : "neutral",
        confidence: breakdownPending ? 0.6 : 0.45,
        details: { highs: lastPeaks, lows: lastTroughs },
      };
    }
    return null;
  }
  /** Detect symmetrical triangle (coiling)
   * @return {PatternCandidate|null} Sym triangle or null
   */
  function isSymmetricalTriangle(): PatternCandidate | null {
    if (peaks.length < 3 || troughs.length < 3) return null;
    const lastPeaks = peaks.slice(-3).map(px);
    const lastTroughs = troughs.slice(-3).map(px);

    // Peaks descending: P1 > P2 > P3
    const fallingHighs = lastPeaks[0] > lastPeaks[1] &&
      lastPeaks[1] > lastPeaks[2];
    // Troughs ascending: T1 < T2 < T3
    const risingLows = lastTroughs[0] < lastTroughs[1] &&
      lastTroughs[1] < lastTroughs[2];

    if (fallingHighs && risingLows) {
      // Check for potential breakout direction
      let dir: "bullish" | "bearish" | "neutral" = "neutral";
      if (currentPrice > lastPeaks[2]) dir = "bullish";
      else if (currentPrice < lastTroughs[2]) dir = "bearish";

      // If price is squeezing tight (last range < first range * 0.5)
      const range1 = lastPeaks[0] - lastTroughs[0];
      const range3 = lastPeaks[2] - lastTroughs[2];
      const coiling = range3 < range1 * 0.6;

      if (coiling) {
        return {
          key: "symmetrical_triangle",
          label: "Symmetrical Triangle",
          direction: dir,
          confidence: dir !== "neutral" ? 0.65 : 0.5,
          details: { highs: lastPeaks, lows: lastTroughs },
        };
      }
    }
    return null;
  }

  const asc = isAscendingTriangle();
  if (asc) patterns.push(asc);
  const desc = isDescendingTriangle();
  if (desc) patterns.push(desc);
  const sym = isSymmetricalTriangle();
  if (sym) patterns.push(sym);

  // 5. Cup & Handle
  const cupHandleCandidate = (() => {
    if (windowPrices.length < 45) return null;
    const len = windowPrices.length;

    // Identify regions for Left Lip, Bottom, Right Lip, and Handle
    const leftSlice = windowPrices.slice(0, Math.floor(len * 0.4));
    const midSlice = windowPrices.slice(
      Math.floor(len * 0.3),
      Math.floor(len * 0.7)
    );
    const rightSlice = windowPrices.slice(
      Math.floor(len * 0.6),
      Math.floor(len * 0.9)
    );
    const handleSlice = windowPrices.slice(Math.floor(len * 0.85));

    const leftHigh = Math.max(...leftSlice);
    const midLow = Math.min(...midSlice);
    const rightHigh = Math.max(...rightSlice);
    const handleLow = Math.min(...handleSlice);

    // Heuristics: Depth > 2%, Rims within 15%, Handle retrace < 60% of depth
    const depth = (rightHigh - midLow) / rightHigh;
    const rimDiff = Math.abs(leftHigh - rightHigh) / rightHigh;
    const handleRetrace = (rightHigh - handleLow) / (rightHigh - midLow);

    if (depth < 0.02 || rimDiff > 0.15 || midLow >= rightHigh * 0.98) {
      return null;
    }
    if (handleRetrace > 0.6 || handleRetrace < 0.0) return null;

    // Trigger: Breakout or recovery in handle
    const breakingOut = currentPrice >= rightHigh * 0.99;
    const recovering = currentPrice > handleLow * 1.01 && ma5 > ma10;

    if (breakingOut || recovering) {
      return {
        key: "cup_handle",
        label: "Cup & Handle",
        direction: "bullish",
        confidence: breakingOut ? 0.75 : 0.6,
        details: { leftHigh, midLow, rightHigh, handleLow },
      } as PatternCandidate;
    }
    return null;
  })();
  if (cupHandleCandidate) patterns.push(cupHandleCandidate);

  // 6. Flag (strong trend followed by consolidation)
  const flagCandidate = (() => {
    if (windowPrices.length < 20) return null;

    // Use last 20 bars: Pole (0-12) and Flag (13-20)
    const set = windowPrices.slice(-20);
    const pole = set.slice(0, 13);
    const flag = set.slice(13);

    const poleStart = pole[0];
    const poleEnd = pole[pole.length - 1];
    const poleMove = (poleEnd - poleStart) / poleStart;

    const flagHigh = Math.max(...flag);
    const flagLow = Math.min(...flag);
    const flagRange = (flagHigh - flagLow) / flagLow;

    // 1. Strong Pole Move (>3% absolute)
    if (Math.abs(poleMove) < 0.03) return null;

    // 2. Tight Flag Consolidation (< 2.5% range)
    if (flagRange > 0.025) return null;

    // 3. Flag should not retrace more than 50% of the pole
    const retrace = Math.abs(flag[flag.length - 1] - poleEnd) /
      Math.abs(poleEnd - poleStart);
    if (retrace > 0.5) return null;

    // Direction based on pole
    const dir = poleMove > 0 ? "bullish" : "bearish";

    // Bull Flag: Pole UP, Flag DRIFT/DOWN
    // Bear Flag: Pole DOWN, Flag DRIFT/UP
    return {
      key: "flag",
      label: dir === "bullish" ? "Bull Flag" : "Bear Flag",
      direction: dir,
      confidence: 0.6, // Reasonably high confidence if structure holds
      details: { poleMove, flagRange, retrace },
    } as PatternCandidate;
  })();
  if (flagCandidate) patterns.push(flagCandidate);

  // 7. Candlestick Patterns (if OHLC data available)
  if (opens && highs && lows && opens.length >= 2) {
    const i = prices.length - 1; // Current (latest) candle
    const open = opens[i];
    const close = prices[i];
    const high = highs[i];
    const low = lows[i];
    const bodySize = Math.abs(close - open);
    const upperShadow = high - Math.max(open, close);
    const lowerShadow = Math.min(open, close) - low;
    const isGreen = close > open;

    const prevOpen = opens[i - 1];
    const prevClose = prices[i - 1];
    const isPrevGreen = prevClose > prevOpen;

    // Bullish Engulfing
    // Previous red, current green completely engulfs previous body
    if (!isPrevGreen && isGreen &&
      close > prevOpen && open < prevClose) {
      patterns.push({
        key: "bullish_engulfing",
        label: "Bullish Engulfing",
        direction: "bullish",
        confidence: 0.65,
        details: { candle: i },
      });
    }

    // Bearish Engulfing
    // Previous green, current red completely engulfs previous body
    if (isPrevGreen && !isGreen &&
      open > prevClose && close < prevOpen) {
      patterns.push({
        key: "bearish_engulfing",
        label: "Bearish Engulfing",
        direction: "bearish",
        confidence: 0.65,
        details: { candle: i },
      });
    }

    // Hammer (Bullish reversal)
    // Small body, long lower shadow, little upper shadow
    // Occurs after downtrend (simplified by checking if price < ma20)
    if (lowerShadow > 2 * bodySize && upperShadow < bodySize &&
      currentPrice < ma20) {
      patterns.push({
        key: "hammer",
        label: "Hammer",
        direction: "bullish",
        confidence: 0.6,
        details: { ratio: lowerShadow / bodySize },
      });
    }

    // Shooting Star (Bearish reversal)
    // Small body, long upper shadow, little lower shadow
    // Occurs after uptrend
    if (upperShadow > 2 * bodySize && lowerShadow < bodySize &&
      currentPrice > ma20) {
      patterns.push({
        key: "shooting_star",
        label: "Shooting Star",
        direction: "bearish",
        confidence: 0.6,
        details: { ratio: upperShadow / bodySize },
      });
    }
  }

  // Aggregate decision
  // Choose highest confidence non-neutral pattern
  const actionable = patterns
    .filter((p) => p.direction !== "neutral")
    .sort((a, b) => b.confidence - a.confidence);
  const best = actionable[0];

  if (best && best.confidence >= 0.6) {
    return {
      value: best.direction === "bullish" ? best.confidence : -best.confidence,
      signal: best.direction === "bullish" ? "BUY" : "SELL",
      reason:
        `${best.label} (confidence ${(best.confidence * 100).toFixed(0)}%)`,
      metadata: {
        selectedPattern: best.key,
        confidence: best.confidence,
        patterns,
        ma5, ma10, ma20,
        slope,
        currentPrice,
      },
    };
  }

  // Moderate confidence patterns present but below action threshold
  if (best) {
    return {
      value: 0,
      signal: "HOLD",
      reason: `${best.label} emerging (${(best.confidence * 100).toFixed(0)}%)`,
      metadata: {
        selectedPattern: best.key,
        confidence: best.confidence,
        patterns,
        ma5, ma10, ma20,
        slope,
        currentPrice,
      },
    };
  }

  return {
    value: 0,
    signal: "HOLD",
    reason: // "No clear pattern.",
      `No clear pattern. Px ${currentPrice.toFixed(2)}; MA5 ` +
      `${ma5.toFixed(2)}, MA10 ${ma10.toFixed(2)}, MA20 ${ma20.toFixed(2)}`,
    metadata: { currentPrice, ma5, ma10, ma20, slope, patterns },
  };
}

/**
 * Evaluate momentum using RSI with divergence detection
 * @param {number[]} prices - Array of historical prices.
 * @param {number} rsiPeriod - RSI calculation period (default 14).
 * @return {IndicatorResult} The momentum evaluation result.
 */
export function evaluateMomentum(
  prices: number[],
  rsiPeriod = 14
): IndicatorResult {
  if (!prices || prices.length < rsiPeriod + 1) {
    const requiredPeriods = rsiPeriod + 1;
    return {
      value: null,
      signal: "HOLD",
      reason: "Insufficient data for RSI calculation " +
        `(need at least ${requiredPeriods} periods)`,
    };
  }

  // Optimized to calculate RSI once
  const rsiSeries = computeRSIArray(prices, rsiPeriod);

  if (rsiSeries.length === 0) {
    return {
      value: null,
      signal: "HOLD",
      reason: "Unable to compute RSI",
    };
  }

  const rsi = rsiSeries[rsiSeries.length - 1];

  // RSI thresholds
  const oversoldThreshold = 30;
  const overboughtThreshold = 70;
  const neutralLower = 40;
  const neutralUpper = 60;

  // Calculate RSI values for divergence detection (need at least 20 periods)
  let divergenceType: "bullish" | "bearish" | "none" = "none";
  let rsiTrend = 0;
  let priceTrend = 0;

  if (prices.length >= 30) {
    // RSI Series: indices 0..N correspond to prices[rsiPeriod..end]
    // already computed above

    // Look at last 30 bars (or fewer)
    const lookback = 30;
    const startIdx = Math.max(0, rsiSeries.length - lookback);
    const recentRSI = rsiSeries.slice(startIdx);

    // Map recentRSI index k to prices index
    const getPriceIdx = (k: number) => rsiPeriod + startIdx + k;

    // 1. Identify RSI Extrema
    const rsiPeaks: number[] = [];
    const rsiTroughs: number[] = [];
    for (let i = 1; i < recentRSI.length - 1; i++) {
      if (recentRSI[i] > recentRSI[i - 1] && recentRSI[i] > recentRSI[i + 1]) {
        rsiPeaks.push(i);
      }
      if (recentRSI[i] < recentRSI[i - 1] && recentRSI[i] < recentRSI[i + 1]) {
        rsiTroughs.push(i);
      }
    }

    // 2. Check Divergence
    // Bullish Divergence: Price = Lower Lows, RSI = Higher Lows
    if (rsiTroughs.length >= 2) {
      const t2 = rsiTroughs[rsiTroughs.length - 1]; // recent
      const t1 = rsiTroughs[rsiTroughs.length - 2]; // older

      // RSI Higher Low?
      if (recentRSI[t2] > recentRSI[t1] && recentRSI[t2] < 50) {
        // Price Lower Low?
        const p2 = prices[getPriceIdx(t2)];
        const p1 = prices[getPriceIdx(t1)];
        if (p2 < p1) {
          divergenceType = "bullish";
        }
      }
    }

    // Bearish Divergence: Price = Higher Highs, RSI = Lower Highs
    if (rsiPeaks.length >= 2) {
      const p2 = rsiPeaks[rsiPeaks.length - 1]; // recent
      const p1 = rsiPeaks[rsiPeaks.length - 2]; // older

      // RSI Lower High?
      if (recentRSI[p2] < recentRSI[p1] && recentRSI[p2] > 50) {
        // Price Higher High?
        const price2 = prices[getPriceIdx(p2)];
        const price1 = prices[getPriceIdx(p1)];
        if (price2 > price1) {
          divergenceType = "bearish";
        }
      }
    }

    // Simplified Trend Fallback (Visual Metadata)
    const recentAvg = recentRSI.slice(-3).reduce((a, b) => a + b, 0) / 3;
    const olderAvg = recentRSI.slice(0, 3).reduce((a, b) => a + b, 0) / 3;
    rsiTrend = recentAvg - olderAvg;

    const recentP = prices.slice(-5).reduce((a, b) => a + b, 0) / 5;
    const olderP = prices.slice(-10, -5).reduce((a, b) => a + b, 0) / 5;
    priceTrend = ((recentP - olderP) / olderP) * 100;
  }

  // Prioritize divergence signals
  if (divergenceType === "bullish") {
    return {
      value: rsi,
      signal: "BUY",
      reason: "RSI bullish divergence " +
        `(RSI ${rsi.toFixed(1)} rising while price falling)`,
      metadata: {
        rsi,
        interpretation: "bullish_divergence",
        rsiTrend: rsiTrend.toFixed(2),
        priceTrend: priceTrend.toFixed(2),
      },
    };
  }

  if (divergenceType === "bearish") {
    return {
      value: rsi,
      signal: "SELL",
      reason: "RSI bearish divergence " +
        `(RSI ${rsi.toFixed(1)} falling while price rising)`,
      metadata: {
        rsi,
        interpretation: "bearish_divergence",
        rsiTrend: rsiTrend.toFixed(2),
        priceTrend: priceTrend.toFixed(2),
      },
    };
  }

  if (rsi < oversoldThreshold) {
    return {
      value: rsi,
      signal: "BUY",
      reason: "RSI indicates oversold condition " +
        `(${rsi.toFixed(2)} < ${oversoldThreshold})`,
      metadata: { rsi, interpretation: "oversold" },
    };
  }

  if (rsi > overboughtThreshold) {
    return {
      value: rsi,
      signal: "SELL",
      reason: "RSI indicates overbought condition " +
        `(${rsi.toFixed(2)} > ${overboughtThreshold})`,
      metadata: { rsi, interpretation: "overbought" },
    };
  }

  // Bullish momentum (above neutral, not overbought)
  if (rsi > neutralUpper && rsi <= overboughtThreshold) {
    return {
      value: rsi,
      signal: "BUY",
      reason: `RSI shows strong bullish momentum (${rsi.toFixed(2)})`,
      metadata: { rsi, interpretation: "bullish" },
    };
  }

  // Bearish momentum (below neutral, not oversold)
  if (rsi < neutralLower && rsi >= oversoldThreshold) {
    return {
      value: rsi,
      signal: "SELL",
      reason: `RSI shows bearish momentum (${rsi.toFixed(2)})`,
      metadata: { rsi, interpretation: "bearish" },
    };
  }

  return {
    value: rsi,
    signal: "HOLD",
    reason: `RSI in neutral zone (${rsi.toFixed(2)})`,
    metadata: { rsi, interpretation: "neutral" },
  };
}

/**
 * Evaluate overall market direction using SPY or QQQ
 * @param {number[]} marketPrices - Array of market index prices.
 * @param {number} fastPeriod - Fast moving average period (default 10).
 * @param {number} slowPeriod - Slow moving average period (default 30).
 * @return {IndicatorResult} The market direction evaluation result.
 */
export function evaluateMarketDirection(
  marketPrices: number[],
  fastPeriod = 10,
  slowPeriod = 30
): IndicatorResult {
  if (!marketPrices || marketPrices.length < slowPeriod) {
    return {
      value: null,
      signal: "HOLD",
      reason: `Insufficient market data (need at least ${slowPeriod} periods)`,
    };
  }

  const fastMAs = computeSMAArray(marketPrices, fastPeriod);
  const slowMAs = computeSMAArray(marketPrices, slowPeriod);

  const fastMA = fastMAs[fastMAs.length - 1];
  const slowMA = slowMAs[slowMAs.length - 1];

  // Previous MAs for crossover detection
  const fastPrevMA = fastMAs.length >= 2 ? fastMAs[fastMAs.length - 2] : null;
  const slowPrevMA = slowMAs.length >= 2 ? slowMAs[slowMAs.length - 2] : null;

  if (fastMA === null || slowMA === null) {
    return {
      value: null,
      signal: "HOLD",
      reason: "Unable to compute market moving averages",
    };
  }

  const currentPrice = marketPrices[marketPrices.length - 1];
  const trendStrength = ((fastMA - slowMA) / slowMA) * 100;

  // Detect crossovers
  if (fastPrevMA && slowPrevMA) {
    if (fastMA > slowMA && fastPrevMA <= slowPrevMA) {
      return {
        value: trendStrength,
        signal: "BUY",
        reason: `Market bullish: ${fastPeriod}-day MA ` +
          `crossed above ${slowPeriod}-day MA ` +
          `(${fastMA.toFixed(2)} > ${slowMA.toFixed(2)})`,
        metadata: {
          fastMA,
          slowMA,
          currentPrice,
          trendStrength,
          crossover: "bullish",
        },
      };
    } else if (fastMA < slowMA && fastPrevMA >= slowPrevMA) {
      return {
        value: trendStrength,
        signal: "SELL",
        reason: `Market bearish: ${fastPeriod}-day MA ` +
          `crossed below ${slowPeriod}-day MA ` +
          `(${fastMA.toFixed(2)} < ${slowMA.toFixed(2)})`,
        metadata: {
          fastMA,
          slowMA,
          currentPrice,
          trendStrength,
          crossover: "bearish",
        },
      };
    }
  }

  // Strong uptrend (fast significantly above slow)
  if (fastMA > slowMA && trendStrength > 2) {
    return {
      value: trendStrength,
      signal: "BUY",
      reason: "Market in strong uptrend " +
        `(${trendStrength.toFixed(2)}% spread)`,
      metadata: { fastMA, slowMA, currentPrice, trendStrength },
    };
  }

  // Strong downtrend (fast significantly below slow)
  if (fastMA < slowMA && trendStrength < -2) {
    return {
      value: trendStrength,
      signal: "SELL",
      reason: "Market in strong downtrend " +
        `(${trendStrength.toFixed(2)}% spread)`,
      metadata: { fastMA, slowMA, currentPrice, trendStrength },
    };
  }

  return {
    value: trendStrength,
    signal: "HOLD",
    reason: "Market direction neutral " +
      `(${trendStrength.toFixed(2)}% spread)`,
    metadata: { fastMA, slowMA, currentPrice, trendStrength },
  };
}

/**
 * Evaluate Macro Assessment based on market direction
 * @param {IndicatorResult} marketDirection - Market direction result
 * @return {object} The macro assessment result
 */
export function evaluateMacroAssessment(
  marketDirection: IndicatorResult
): MultiIndicatorResult["macroAssessment"] {
  if (marketDirection.signal === "BUY") {
    return {
      status: "RISK_ON",
      score: 1.0,
      reason: `Market trend is bullish (${marketDirection.reason})`,
    };
  } else if (marketDirection.signal === "SELL") {
    return {
      status: "RISK_OFF",
      score: -1.0,
      reason: `Market trend is bearish (${marketDirection.reason})`,
    };
  } else {
    // Check value/strength if available for more nuance
    const strength = marketDirection.value || 0;
    if (strength > 0.5) {
      return {
        status: "RISK_ON",
        score: 0.5,
        reason: "Market is neutral with positive bias",
      };
    } else if (strength < -0.5) {
      return {
        status: "RISK_OFF",
        score: -0.5,
        reason: "Market is neutral with negative bias",
      };
    }
    return {
      status: "NEUTRAL",
      score: 0,
      reason: "Market trend is neutral",
    };
  }
}

/**
 * Evaluate volume indicators
 * @param {number[]} volumes - Array of volume data.
 * @param {number[]} prices - Array of price data.
 * @return {IndicatorResult} The volume evaluation result.
 */
export function evaluateVolume(
  volumes: number[],
  prices: number[]
): IndicatorResult {
  if (!volumes || volumes.length < 20 || !prices || prices.length < 20) {
    return {
      value: null,
      signal: "HOLD",
      reason: "Insufficient data for volume analysis " +
        "(need at least 20 periods)",
    };
  }

  const recentVolumes = volumes.slice(-20);
  const recentPrices = prices.slice(-20);

  const currentVolume = recentVolumes[recentVolumes.length - 1];
  const volSum = recentVolumes.reduce((a, b) => a + b, 0);
  const avgVolume = volSum / recentVolumes.length;

  const currentPrice = recentPrices[recentPrices.length - 1];
  const previousPrice = recentPrices[recentPrices.length - 2];
  const priceDiff = currentPrice - previousPrice;
  const priceChange = (priceDiff / previousPrice) * 100;

  if (avgVolume === 0) {
    return {
      value: 0,
      signal: "HOLD",
      reason: "Volume data unavailable, price change " +
        `${priceChange.toFixed(2)}%`,
      metadata: { currentVolume, avgVolume, volumeRatio: 0, priceChange },
    };
  }

  const volumeRatio = currentVolume / avgVolume;

  // High volume with price increase = bullish
  if (volumeRatio > 1.5 && priceChange > 0.5) {
    const volPct = (volumeRatio * 100).toFixed(0);
    return {
      value: volumeRatio,
      signal: "BUY",
      reason: `High volume (${volPct}% of avg) ` +
        `with price increase (${priceChange.toFixed(2)}%)`,
      metadata: {
        currentVolume,
        avgVolume,
        volumeRatio,
        priceChange,
        interpretation: "accumulation",
      },
    };
  }

  // High volume with price decrease = bearish
  if (volumeRatio > 1.5 && priceChange < -0.5) {
    const volPct = (volumeRatio * 100).toFixed(0);
    return {
      value: volumeRatio,
      signal: "SELL",
      reason: `High volume (${volPct}% of avg) ` +
        `with price decrease (${priceChange.toFixed(2)}%)`,
      metadata: {
        currentVolume,
        avgVolume,
        volumeRatio,
        priceChange,
        interpretation: "distribution",
      },
    };
  }

  // Low volume - caution
  if (volumeRatio < 0.7) {
    const volPct = (volumeRatio * 100).toFixed(0);
    return {
      value: volumeRatio,
      signal: "HOLD",
      reason: `Low volume (${volPct}% of avg) - lack of conviction`,
      metadata: { currentVolume, avgVolume, volumeRatio, priceChange },
    };
  }

  // Normal volume with positive price action
  if (priceChange > 1 && volumeRatio >= 0.9) {
    return {
      value: volumeRatio,
      signal: "BUY",
      reason: `Price increasing (${priceChange.toFixed(2)}%) ` +
        "on normal volume",
      metadata: { currentVolume, avgVolume, volumeRatio, priceChange },
    };
  }

  const volPct = (volumeRatio * 100).toFixed(0);
  return {
    value: volumeRatio,
    signal: "HOLD",
    reason: `Volume neutral (${volPct}% of avg), ` +
      `price change ${priceChange.toFixed(2)}%`,
    metadata: { currentVolume, avgVolume, volumeRatio, priceChange },
  };
}

/**
 * Evaluate MACD indicator
 * @param {number[]} prices - Array of historical prices.
 * @param {number} fastPeriod - Fast EMA period (default 12).
 * @param {number} slowPeriod - Slow EMA period (default 26).
 * @param {number} signalPeriod - Signal line period (default 9).
 * @return {IndicatorResult} The MACD evaluation result.
 */
export function evaluateMACD(
  prices: number[],
  fastPeriod = 12,
  slowPeriod = 26,
  signalPeriod = 9
): IndicatorResult {
  const minPeriods = slowPeriod + signalPeriod;
  if (!prices || prices.length < minPeriods) {
    return {
      value: null,
      signal: "HOLD",
      reason: `Insufficient data for MACD (need ${minPeriods} periods)`,
    };
  }

  const macd = computeMACD(prices, fastPeriod, slowPeriod, signalPeriod);
  if (!macd) {
    return {
      value: null,
      signal: "HOLD",
      reason: "Unable to compute MACD",
    };
  }

  const { histogram } = macd;

  // Compute previous MACD for crossover detection
  let prevHistogram: number | null = null;
  if (prices.length > minPeriods + 1) {
    const prevMACD = computeMACD(
      prices.slice(0, -1),
      fastPeriod,
      slowPeriod,
      signalPeriod
    );
    if (prevMACD) prevHistogram = prevMACD.histogram;
  }

  // Bullish crossover: histogram crosses above zero
  if (prevHistogram !== null && histogram > 0 && prevHistogram <= 0) {
    return {
      value: histogram,
      signal: "BUY",
      reason: `MACD bullish crossover (hist: ${histogram.toFixed(4)})`,
      metadata: { ...macd, crossover: "bullish" },
    };
  }

  // Bearish crossover: histogram crosses below zero
  if (prevHistogram !== null && histogram < 0 && prevHistogram >= 0) {
    return {
      value: histogram,
      signal: "SELL",
      reason: `MACD bearish crossover (hist: ${histogram.toFixed(4)})`,
      metadata: { ...macd, crossover: "bearish" },
    };
  }

  // Strong positive histogram (bullish momentum)
  if (histogram > 0) {
    return {
      value: histogram,
      signal: "BUY",
      reason: `MACD bullish momentum (hist: ${histogram.toFixed(4)})`,
      metadata: macd,
    };
  }

  // Strong negative histogram (bearish momentum)
  if (histogram < 0) {
    return {
      value: histogram,
      signal: "SELL",
      reason: `MACD bearish momentum (hist: ${histogram.toFixed(4)})`,
      metadata: macd,
    };
  }

  return {
    value: histogram,
    signal: "HOLD",
    reason: "MACD neutral",
    metadata: macd,
  };
}

/**
 * Evaluate Bollinger Bands indicator
 * @param {number[]} prices - Array of historical prices.
 * @param {number} period - Period for calculation (default 20).
 * @param {number} stdDev - Standard deviation multiplier (default 2).
 * @return {IndicatorResult} The Bollinger Bands evaluation result.
 */
export function evaluateBollingerBands(
  prices: number[],
  period = 20,
  stdDev = 2
): IndicatorResult {
  if (!prices || prices.length < period) {
    return {
      value: null,
      signal: "HOLD",
      reason: `Insufficient data for Bollinger Bands (need ${period})`,
    };
  }

  const bb = computeBollingerBands(prices, period, stdDev);
  if (!bb) {
    return {
      value: null,
      signal: "HOLD",
      reason: "Unable to compute Bollinger Bands",
    };
  }

  const currentPrice = prices[prices.length - 1];
  const bandwidth = (bb.upper - bb.lower) / bb.middle;
  const position = (currentPrice - bb.lower) / (bb.upper - bb.lower);

  // Price at or below lower band (oversold)
  if (currentPrice <= bb.lower * 1.005) {
    const cp = currentPrice.toFixed(2);
    const low = bb.lower.toFixed(2);
    return {
      value: position,
      signal: "BUY",
      reason: `Price at lower BB (${cp} ≤ ${low})`,
      metadata: { ...bb, currentPrice, bandwidth, position },
    };
  }

  // Price at or above upper band (overbought)
  if (currentPrice >= bb.upper * 0.995) {
    const cp = currentPrice.toFixed(2);
    const up = bb.upper.toFixed(2);
    return {
      value: position,
      signal: "SELL",
      reason: `Price at upper BB (${cp} ≥ ${up})`,
      metadata: { ...bb, currentPrice, bandwidth, position },
    };
  }

  // Price in lower third (potential buy)
  if (position < 0.3) {
    const pos = (position * 100).toFixed(0);
    return {
      value: position,
      signal: "BUY",
      reason: `Price in lower BB region (${pos}%)`,
      metadata: { ...bb, currentPrice, bandwidth, position },
    };
  }

  // Price in upper third (potential sell)
  if (position > 0.7) {
    const pos = (position * 100).toFixed(0);
    return {
      value: position,
      signal: "SELL",
      reason: `Price in upper BB region (${pos}%)`,
      metadata: { ...bb, currentPrice, bandwidth, position },
    };
  }

  const pos = (position * 100).toFixed(0);
  return {
    value: position,
    signal: "HOLD",
    reason: `Price in middle BB region (${pos}%)`,
    metadata: { ...bb, currentPrice, bandwidth, position },
  };
}

/**
 * Evaluate Stochastic Oscillator
 * @param {number[]} highs - Array of high prices.
 * @param {number[]} lows - Array of low prices.
 * @param {number[]} closes - Array of close prices.
 * @param {number} kPeriod - %K period (default 14).
 * @param {number} dPeriod - %D period (default 3).
 * @return {IndicatorResult} The Stochastic evaluation result.
 */
export function evaluateStochastic(
  highs: number[],
  lows: number[],
  closes: number[],
  kPeriod = 14,
  dPeriod = 3
): IndicatorResult {
  if (!highs || !lows || !closes || closes.length < kPeriod) {
    return {
      value: null,
      signal: "HOLD",
      reason: `Insufficient data for Stochastic (need ${kPeriod})`,
    };
  }

  // Optimized to use Array computation once
  const stochArray = computeStochasticArray(
    highs,
    lows,
    closes,
    kPeriod,
    dPeriod
  );

  const stoch = stochArray[stochArray.length - 1];

  if (!stoch) {
    return {
      value: null,
      signal: "HOLD",
      reason: "Unable to compute Stochastic",
    };
  }

  const { k, d } = stoch;
  const oversoldThreshold = 20;
  const overboughtThreshold = 80;

  // Detect crossovers
  let prevStoch: { k: number; d: number } | null = null;
  if (stochArray.length >= 2) {
    prevStoch = stochArray[stochArray.length - 2];
  }

  // Bullish crossover in oversold region
  const bullishCross = prevStoch && k > d &&
    prevStoch.k <= prevStoch.d && k < oversoldThreshold;
  if (bullishCross) {
    const kStr = k.toFixed(1);
    const dStr = d.toFixed(1);
    return {
      value: k,
      signal: "BUY",
      reason: `Stochastic bullish cross oversold (K:${kStr}, D:${dStr})`,
      metadata: { k, d, crossover: "bullish" },
    };
  }

  // Bearish crossover in overbought region
  const bearishCross = prevStoch && k < d &&
    prevStoch.k >= prevStoch.d && k > overboughtThreshold;
  if (bearishCross) {
    const kStr = k.toFixed(1);
    const dStr = d.toFixed(1);
    return {
      value: k,
      signal: "SELL",
      reason: `Stochastic bearish cross overbought (K:${kStr}, D:${dStr})`,
      metadata: { k, d, crossover: "bearish" },
    };
  }

  // Oversold condition
  if (k < oversoldThreshold && d < oversoldThreshold) {
    const kStr = k.toFixed(1);
    const dStr = d.toFixed(1);
    return {
      value: k,
      signal: "BUY",
      reason: `Stochastic oversold (K:${kStr}, D:${dStr})`,
      metadata: { k, d, interpretation: "oversold" },
    };
  }

  // Overbought condition
  if (k > overboughtThreshold && d > overboughtThreshold) {
    const kStr = k.toFixed(1);
    const dStr = d.toFixed(1);
    return {
      value: k,
      signal: "SELL",
      reason: `Stochastic overbought (K:${kStr}, D:${dStr})`,
      metadata: { k, d, interpretation: "overbought" },
    };
  }

  const kStr = k.toFixed(1);
  const dStr = d.toFixed(1);
  return {
    value: k,
    signal: "HOLD",
    reason: `Stochastic neutral (K:${kStr}, D:${dStr})`,
    metadata: { k, d },
  };
}

/**
 * Evaluate ATR for volatility context
 * @param {number[]} highs - Array of high prices.
 * @param {number[]} lows - Array of low prices.
 * @param {number[]} closes - Array of close prices.
 * @param {number} period - Period for ATR (default 14).
 * @return {IndicatorResult} The ATR evaluation result.
 */
export function evaluateATR(
  highs: number[],
  lows: number[],
  closes: number[],
  period = 14
): IndicatorResult {
  if (!highs || !lows || !closes || closes.length < period + 1) {
    return {
      value: null,
      signal: "HOLD",
      reason: `Insufficient data for ATR (need ${period + 1})`,
    };
  }

  // Optimized to use O(N) array computation
  const fullATRSeries = computeATRArray(highs, lows, closes, period);
  const atr = fullATRSeries[fullATRSeries.length - 1];

  if (atr === null) {
    return {
      value: null,
      signal: "HOLD",
      reason: "Unable to compute ATR",
    };
  }

  const currentPrice = closes[closes.length - 1];
  const atrPercent = (atr / currentPrice) * 100;

  // Collect historical ATR values for comparison
  const atrValues: number[] = [];
  for (const val of fullATRSeries) {
    if (val !== null) atrValues.push(val);
  }

  if (atrValues.length < 10) {
    const atrStr = atr.toFixed(2);
    const pct = atrPercent.toFixed(2);
    return {
      value: atr,
      signal: "HOLD",
      reason: `ATR: ${atrStr} (${pct}% of price)`,
      metadata: { atr, atrPercent, currentPrice },
    };
  }

  const avgATR = atrValues.length > 0 ?
    atrValues.reduce((a, b) => a + b, 0) / atrValues.length : 0;
  const atrRatio = avgATR > 0 ? atr / avgATR : 1.0;

  // High volatility (expanding ranges) - caution
  if (atrRatio > 1.5) {
    const atrStr = atr.toFixed(2);
    const pct = (atrRatio * 100).toFixed(0);
    return {
      value: atr,
      signal: "HOLD",
      reason: `High volatility (ATR: ${atrStr}, ${pct}% of avg)`,
      metadata: {
        atr, atrPercent, avgATR, atrRatio,
        interpretation: "high_volatility",
      },
    };
  }

  // Low volatility (contracting ranges) - potential breakout
  if (atrRatio < 0.6) {
    const atrStr = atr.toFixed(2);
    const pct = (atrRatio * 100).toFixed(0);
    return {
      value: atr,
      signal: "BUY",
      reason: `Low volatility - breakout setup (ATR: ${atrStr}, ${pct}%)`,
      metadata: {
        atr, atrPercent, avgATR, atrRatio,
        interpretation: "low_volatility",
      },
    };
  }

  const atrStr = atr.toFixed(2);
  const pct = atrPercent.toFixed(2);
  return {
    value: atr,
    signal: "HOLD",
    reason: `Normal volatility (ATR: ${atrStr}, ${pct}%)`,
    metadata: { atr, atrPercent, avgATR, atrRatio },
  };
}

/**
 * Evaluate OBV (On-Balance Volume) indicator
 * @param {number[]} closes - Array of close prices.
 * @param {number[]} volumes - Array of volumes.
 * @return {IndicatorResult} The OBV evaluation result.
 */
export function evaluateOBV(
  closes: number[],
  volumes: number[]
): IndicatorResult {
  if (!closes || !volumes || closes.length < 20 || volumes.length < 20) {
    return {
      value: null,
      signal: "HOLD",
      reason: "Insufficient data for OBV (need 20+ periods)",
    };
  }

  const obv = computeOBV(closes, volumes);
  if (!obv || obv.length < 20) {
    return {
      value: null,
      signal: "HOLD",
      reason: "Unable to compute OBV",
    };
  }

  const currentOBV = obv[obv.length - 1];
  const recentOBV = obv.slice(-10);
  const olderOBV = obv.slice(-20, -10);

  const recentAvg = recentOBV.reduce((a, b) => a + b, 0) / recentOBV.length;
  const olderAvg = olderOBV.reduce((a, b) => a + b, 0) / olderOBV.length;
  // Guard against division by zero when olderAvg is ~0
  const denom = Math.abs(olderAvg);
  const obvTrend = denom > 1e-9 ?
    ((recentAvg - olderAvg) / denom) * 100 :
    0;

  const currentPrice = closes[closes.length - 1];
  const priceChange = closes.length >= 10 ?
    ((currentPrice - closes[closes.length - 10]) /
      closes[closes.length - 10]) * 100 : 0;

  // Bullish divergence: OBV rising while price falling
  if (obvTrend > 5 && priceChange < 0) {
    const obvStr = obvTrend.toFixed(1);
    const prStr = priceChange.toFixed(1);
    return {
      value: currentOBV,
      signal: "BUY",
      reason: `OBV bullish divergence (OBV +${obvStr}%, price ${prStr}%)`,
      metadata: {
        currentOBV, obvTrend, priceChange,
        interpretation: "bullish_divergence",
      },
    };
  }

  // Bearish divergence: OBV falling while price rising
  if (obvTrend < -5 && priceChange > 0) {
    const obvStr = obvTrend.toFixed(1);
    const prStr = priceChange.toFixed(1);
    return {
      value: currentOBV,
      signal: "SELL",
      reason: `OBV bearish divergence (OBV ${obvStr}%, price +${prStr}%)`,
      metadata: {
        currentOBV, obvTrend, priceChange,
        interpretation: "bearish_divergence",
      },
    };
  }

  // Strong OBV uptrend with price confirmation
  if (obvTrend > 10 && priceChange > 0) {
    const obvStr = obvTrend.toFixed(1);
    return {
      value: currentOBV,
      signal: "BUY",
      reason: `Strong OBV uptrend (+${obvStr}%) confirms price rise`,
      metadata: {
        currentOBV, obvTrend, priceChange,
        interpretation: "confirmed_uptrend",
      },
    };
  }

  // Strong OBV downtrend with price confirmation
  if (obvTrend < -10 && priceChange < 0) {
    const obvStr = obvTrend.toFixed(1);
    return {
      value: currentOBV,
      signal: "SELL",
      reason: `Strong OBV downtrend (${obvStr}%) confirms decline`,
      metadata: {
        currentOBV, obvTrend, priceChange,
        interpretation: "confirmed_downtrend",
      },
    };
  }

  const obvStr = obvTrend.toFixed(1);
  return {
    value: currentOBV,
    signal: "HOLD",
    reason: `OBV neutral (trend: ${obvStr}%)`,
    metadata: { currentOBV, obvTrend, priceChange },
  };
}

/**
 * Evaluate VWAP (Volume Weighted Average Price)
 * @param {number[]} highs - Array of high prices.
 * @param {number[]} lows - Array of low prices.
 * @param {number[]} closes - Array of close prices.
 * @param {number[]} volumes - Array of volumes.
 * @return {IndicatorResult} The VWAP evaluation result.
 */
export function evaluateVWAP(
  highs: number[],
  lows: number[],
  closes: number[],
  volumes: number[]
): IndicatorResult {
  if (!highs || !lows || !closes || !volumes ||
    closes.length < 20 || volumes.length < 20) {
    return {
      value: null,
      signal: "HOLD",
      reason: "Insufficient data for VWAP (need 20+ periods)",
    };
  }

  const vwap = computeVWAP(highs, lows, closes, volumes);
  if (vwap === null || vwap === 0) {
    return {
      value: null,
      signal: "HOLD",
      reason: "Unable to compute VWAP (or VWAP is 0)",
    };
  }

  const currentPrice = closes[closes.length - 1];
  const deviation = ((currentPrice - vwap) / vwap) * 100;

  // Calculate VWAP bands (1 and 2 standard deviations)
  const typicalPrices: number[] = [];
  for (let i = 0; i < closes.length; i++) {
    typicalPrices.push((highs[i] + lows[i] + closes[i]) / 3);
  }
  const squaredDiffs = typicalPrices.map((tp) => Math.pow(tp - vwap, 2));
  const varianceSum = squaredDiffs.reduce((a, b) => a + b, 0);
  const variance = varianceSum / (typicalPrices.length - 1);
  const stdDev = Math.sqrt(variance);

  const upperBand1 = vwap + stdDev;
  const lowerBand1 = vwap - stdDev;
  const upperBand2 = vwap + 2 * stdDev;
  const lowerBand2 = vwap - 2 * stdDev;

  // Price significantly below VWAP (potential buy)
  if (currentPrice <= lowerBand2) {
    return {
      value: vwap,
      signal: "BUY",
      reason: `Price below VWAP -2σ (${deviation.toFixed(2)}% below VWAP)`,
      metadata: {
        vwap, currentPrice, deviation,
        upperBand1, lowerBand1, upperBand2, lowerBand2,
        interpretation: "oversold_vwap",
      },
    };
  }

  if (currentPrice <= lowerBand1 && currentPrice > lowerBand2) {
    return {
      value: vwap,
      signal: "BUY",
      reason: `Price below VWAP -1σ (${deviation.toFixed(2)}% below VWAP)`,
      metadata: {
        vwap, currentPrice, deviation,
        upperBand1, lowerBand1, upperBand2, lowerBand2,
        interpretation: "below_vwap",
      },
    };
  }

  // Price significantly above VWAP (potential sell)
  if (currentPrice >= upperBand2) {
    return {
      value: vwap,
      signal: "SELL",
      reason: `Price above VWAP +2σ (${deviation.toFixed(2)}% above VWAP)`,
      metadata: {
        vwap, currentPrice, deviation,
        upperBand1, lowerBand1, upperBand2, lowerBand2,
        interpretation: "overbought_vwap",
      },
    };
  }

  if (currentPrice >= upperBand1 && currentPrice < upperBand2) {
    return {
      value: vwap,
      signal: "SELL",
      reason: `Price above VWAP +1σ (${deviation.toFixed(2)}% above VWAP)`,
      metadata: {
        vwap, currentPrice, deviation,
        upperBand1, lowerBand1, upperBand2, lowerBand2,
        interpretation: "above_vwap",
      },
    };
  }

  return {
    value: vwap,
    signal: "HOLD",
    reason: `Price near VWAP (${deviation.toFixed(2)}% deviation)`,
    metadata: {
      vwap, currentPrice, deviation,
      upperBand1, lowerBand1, upperBand2, lowerBand2,
    },
  };
}

/**
 * Evaluate ADX (Average Directional Index)
 * @param {number[]} highs - Array of high prices.
 * @param {number[]} lows - Array of low prices.
 * @param {number[]} closes - Array of close prices.
 * @param {number} period - Period for calculation (default 14).
 * @return {IndicatorResult} The ADX evaluation result.
 */
export function evaluateADX(
  highs: number[],
  lows: number[],
  closes: number[],
  period = 14
): IndicatorResult {
  if (!highs || !lows || !closes || closes.length < period * 2) {
    return {
      value: null,
      signal: "HOLD",
      reason: `Insufficient data for ADX (need ${period * 2} periods)`,
    };
  }

  const adxResult = computeADX(highs, lows, closes, period);
  if (!adxResult) {
    return {
      value: null,
      signal: "HOLD",
      reason: "Unable to compute ADX",
    };
  }

  const { adx, plusDI, minusDI } = adxResult;

  // Strong trend with bullish direction (+DI > -DI and ADX > 25)
  if (adx > 25 && plusDI > minusDI) {
    const strength = adx > 40 ? "very strong" : "strong";
    const adxStr = adx.toFixed(1);
    const pdiStr = plusDI.toFixed(1);
    const mdiStr = minusDI.toFixed(1);
    return {
      value: adx,
      signal: "BUY",
      reason: `${strength} bullish trend ` +
        `(ADX: ${adxStr}, +DI: ${pdiStr} > -DI: ${mdiStr})`,
      metadata: {
        adx, plusDI, minusDI,
        trendStrength: strength,
        interpretation: "bullish_trend",
      },
    };
  }

  // Strong trend with bearish direction (-DI > +DI and ADX > 25)
  if (adx > 25 && minusDI > plusDI) {
    const strength = adx > 40 ? "very strong" : "strong";
    const adxStr = adx.toFixed(1);
    const pdiStr = plusDI.toFixed(1);
    const mdiStr = minusDI.toFixed(1);
    return {
      value: adx,
      signal: "SELL",
      reason: `${strength} bearish trend ` +
        `(ADX: ${adxStr}, -DI: ${mdiStr} > +DI: ${pdiStr})`,
      metadata: {
        adx, plusDI, minusDI,
        trendStrength: strength,
        interpretation: "bearish_trend",
      },
    };
  }

  // Weak trend (ADX < 20) - potential reversal or range-bound
  if (adx < 20) {
    return {
      value: adx,
      signal: "HOLD",
      reason: `Weak/no trend (ADX: ${adx.toFixed(1)}) - range-bound market`,
      metadata: {
        adx, plusDI, minusDI,
        trendStrength: "weak",
        interpretation: "range_bound",
      },
    };
  }

  return {
    value: adx,
    signal: "HOLD",
    reason: `Moderate trend (ADX: ${adx.toFixed(1)})`,
    metadata: { adx, plusDI, minusDI, trendStrength: "moderate" },
  };
}

/**
 * Evaluate Williams %R
 * @param {number[]} highs - Array of high prices.
 * @param {number[]} lows - Array of low prices.
 * @param {number[]} closes - Array of close prices.
 * @param {number} period - Period for calculation (default 14).
 * @return {IndicatorResult} The Williams %R evaluation result.
 */
export function evaluateWilliamsR(
  highs: number[],
  lows: number[],
  closes: number[],
  period = 14
): IndicatorResult {
  if (!highs || !lows || !closes || closes.length < period) {
    return {
      value: null,
      signal: "HOLD",
      reason: `Insufficient data for Williams %R (need ${period} periods)`,
    };
  }

  const williamsR = computeWilliamsR(highs, lows, closes, period);
  if (williamsR === null) {
    return {
      value: null,
      signal: "HOLD",
      reason: "Unable to compute Williams %R",
    };
  }

  // Calculate previous Williams %R for momentum detection
  let prevWilliamsR: number | null = null;
  if (closes.length > period) {
    prevWilliamsR = computeWilliamsR(
      highs.slice(0, -1),
      lows.slice(0, -1),
      closes.slice(0, -1),
      period
    );
  }

  const oversoldThreshold = -80;
  const overboughtThreshold = -20;

  // Oversold with upward momentum (potential buy)
  if (williamsR <= oversoldThreshold) {
    const risingFromOversold = prevWilliamsR !== null &&
      williamsR > prevWilliamsR && prevWilliamsR <= oversoldThreshold;

    if (risingFromOversold) {
      return {
        value: williamsR,
        signal: "BUY",
        reason: `Williams %R rising from oversold (${williamsR.toFixed(1)} ↑)`,
        metadata: {
          williamsR, prevWilliamsR,
          interpretation: "oversold_reversal",
        },
      };
    }

    return {
      value: williamsR,
      signal: "BUY",
      reason: "Williams %R oversold " +
        `(${williamsR.toFixed(1)} ≤ ${oversoldThreshold})`,
      metadata: {
        williamsR,
        interpretation: "oversold",
      },
    };
  }

  // Overbought with downward momentum (potential sell)
  if (williamsR >= overboughtThreshold) {
    const fallingFromOverbought = prevWilliamsR !== null &&
      williamsR < prevWilliamsR && prevWilliamsR >= overboughtThreshold;

    if (fallingFromOverbought) {
      return {
        value: williamsR,
        signal: "SELL",
        reason: "Williams %R falling from overbought " +
          `(${williamsR.toFixed(1)} ↓)`,
        metadata: {
          williamsR, prevWilliamsR,
          interpretation: "overbought_reversal",
        },
      };
    }

    return {
      value: williamsR,
      signal: "SELL",
      reason: "Williams %R overbought " +
        `(${williamsR.toFixed(1)} ≥ ${overboughtThreshold})`,
      metadata: {
        williamsR,
        interpretation: "overbought",
      },
    };
  }

  return {
    value: williamsR,
    signal: "HOLD",
    reason: `Williams %R neutral (${williamsR.toFixed(1)})`,
    metadata: { williamsR },
  };
}

/**
 * Compute Ichimoku Cloud
 * @param {number[]} highs - Array of high prices.
 * @param {number[]} lows - Array of low prices.
 * @param {number[]} closes - Array of close prices.
 * @param {number} conversionPeriod - Tenkan-sen period (default 9).
 * @param {number} basePeriod - Kijun-sen period (default 26).
 * @param {number} spanBPeriod - Senkou Span B period (default 52).
 * @param {number} displacement - Displacement for Chikou Span (default 26).
 * @return {object|null} The computed Ichimoku components or null.
 */
export function computeIchimokuCloud(
  highs: number[],
  lows: number[],
  closes: number[],
  conversionPeriod = 9,
  basePeriod = 26,
  spanBPeriod = 52,
  displacement = 26
): {
  conversionLine: number;
  baseLine: number;
  spanA: number;
  spanB: number;
  laggingSpan: number;
} | null {
  if (!highs || !lows || !closes ||
    highs.length < spanBPeriod ||
    lows.length < spanBPeriod ||
    closes.length < spanBPeriod) {
    return null;
  }

  const currentIdx = closes.length - 1;

  // Helper to calculate midpoint of high and low over a period
  const getMidpoint = (p: number, idx: number) => {
    const start = idx - p + 1;
    if (start < 0) return null;
    const periodHighs = highs.slice(start, idx + 1);
    const periodLows = lows.slice(start, idx + 1);
    const maxH = Math.max(...periodHighs);
    const minL = Math.min(...periodLows);
    return (maxH + minL) / 2;
  };

  const conversionLine = getMidpoint(conversionPeriod, currentIdx);
  const baseLine = getMidpoint(basePeriod, currentIdx);

  // Span A: (Conversion Line + Base Line) / 2, shifted forward by displacement
  // To get the CURRENT Span A value, we need the calculation
  // from 'displacement' periods ago
  const idxAgo = currentIdx - displacement;
  if (idxAgo < 0) return null;

  const convAgo = getMidpoint(conversionPeriod, idxAgo);
  const baseAgo = getMidpoint(basePeriod, idxAgo);

  if (convAgo === null || baseAgo === null) return null;
  const spanA = (convAgo + baseAgo) / 2;

  // Span B: (52-period high + low) / 2, shifted forward
  const spanBAgo = getMidpoint(spanBPeriod, idxAgo);
  const spanB = spanBAgo; // If null, return null

  // Lagging Span: Current closing price, shifted back.
  // In real-time context, we look at where today's price is
  // relative to price 26 periods ago
  const laggingSpan = closes[currentIdx];

  if (conversionLine === null || baseLine === null ||
    spanA === null || spanB === null) {
    return null;
  }

  return {
    conversionLine,
    baseLine,
    spanA,
    spanB,
    laggingSpan,
  };
}

/**
 * Evaluate Ichimoku Cloud
 * @param {number[]} highs - Array of high prices.
 * @param {number[]} lows - Array of low prices.
 * @param {number[]} closes - Array of close prices.
 * @return {IndicatorResult} The Ichimoku Cloud evaluation result.
 */
export function evaluateIchimokuCloud(
  highs: number[],
  lows: number[],
  closes: number[]
): IndicatorResult {
  const ichimoku = computeIchimokuCloud(highs, lows, closes);

  if (!ichimoku) {
    return {
      value: null,
      signal: "HOLD",
      reason: "Insufficient data for Ichimoku Cloud",
    };
  }

  const { conversionLine, baseLine, spanA, spanB } = ichimoku;
  const currentPrice = closes[closes.length - 1];

  // Cloud (Kumo) Analysis
  const aboveCloud = currentPrice > Math.max(spanA, spanB);
  const belowCloud = currentPrice < Math.min(spanA, spanB);
  const inCloud = currentPrice >= Math.min(spanA, spanB) &&
    currentPrice <= Math.max(spanA, spanB);

  const greenCloud = spanA > spanB; // Bullish Kumo
  const tkCrossBullish = conversionLine > baseLine;
  const tkCrossBearish = conversionLine < baseLine;

  // Strong Bullish Signal (TK Cross + Price > Cloud)
  if (tkCrossBullish && aboveCloud && greenCloud) {
    return {
      value: currentPrice,
      signal: "BUY",
      reason: "Strong Ichimoku Bullish (Price > Cloud, TK Cross, Green Cloud)",
      metadata: { ...ichimoku, interpretation: "strong_bullish" },
    };
  }

  // Strong Bearish Signal (TK Cross + Price < Cloud)
  if (tkCrossBearish && belowCloud && !greenCloud) {
    return {
      value: currentPrice,
      signal: "SELL",
      reason: "Strong Ichimoku Bearish (Price < Cloud, TK Cross, Red Cloud)",
      metadata: { ...ichimoku, interpretation: "strong_bearish" },
    };
  }

  // TK Cross (Bullish)
  if (tkCrossBullish && aboveCloud) {
    return {
      value: currentPrice,
      signal: "BUY",
      reason: "Ichimoku Bullish TK Cross above Cloud",
      metadata: { ...ichimoku, interpretation: "bullish_tk_cross" },
    };
  }

  // TK Cross (Bearish)
  if (tkCrossBearish && belowCloud) {
    return {
      value: currentPrice,
      signal: "SELL",
      reason: "Ichimoku Bearish TK Cross below Cloud",
      metadata: { ...ichimoku, interpretation: "bearish_tk_cross" },
    };
  }

  // Kumo Breakout (Bullish)
  if (aboveCloud) {
    // Check previous candle to confirm breakout
    const prevPrice = closes[closes.length - 2];
    if (prevPrice <= Math.max(spanA, spanB)) {
      return {
        value: currentPrice,
        signal: "BUY",
        reason: "Ichimoku Cloud Breakout (Bullish)",
        metadata: { ...ichimoku, interpretation: "cloud_breakout_bullish" },
      };
    }
  }

  // Kumo Breakout (Bearish)
  if (belowCloud) {
    const prevPrice = closes[closes.length - 2];
    if (prevPrice >= Math.min(spanA, spanB)) {
      return {
        value: currentPrice,
        signal: "SELL",
        reason: "Ichimoku Cloud Breakdown (Bearish)",
        metadata: { ...ichimoku, interpretation: "cloud_breakout_bearish" },
      };
    }
  }

  if (inCloud) {
    return {
      value: currentPrice,
      signal: "HOLD",
      reason: "Price inside Ichimoku Cloud (Neutral/Volatile)",
      metadata: { ...ichimoku, interpretation: "neutral_in_cloud" },
    };
  }

  return {
    value: currentPrice,
    signal: "HOLD",
    reason: "Ichimoku Neutral",
    metadata: { ...ichimoku, interpretation: "neutral" },
  };
}

/**
 * Compute Commodity Channel Index (CCI)
 * @param {number[]} prices - Typical prices preferably
 * @param {number} period - The period (default 20).
 * @return {number|null} The computed CCI or null.
 */
export function computeCCI(prices: number[], period = 20): number | null {
  if (!prices || prices.length < period) return null;

  const currentPrices = prices.slice(prices.length - period);
  const sma = currentPrices.reduce((a, b) => a + b, 0) / period;

  const meanDeviation = currentPrices.reduce((acc, price) =>
    acc + Math.abs(price - sma), 0) / period;

  if (meanDeviation === 0) return 0;

  const currentPrice = currentPrices[currentPrices.length - 1];
  return (currentPrice - sma) / (0.015 * meanDeviation);
}

/**
 * Evaluate CCI
 * @param {number[]} highs - High prices
 * @param {number[]} lows - Low prices
 * @param {number[]} closes - Close prices
 * @param {number} [period=20] - Period for CCI (default 20)
 * @return {IndicatorResult} IndicatorResult
 */
export function evaluateCCI(
  highs: number[],
  lows: number[],
  closes: number[],
  period = 20
): IndicatorResult {
  if (!highs || !lows || !closes || closes.length < period) {
    return {
      value: null,
      signal: "HOLD",
      reason: `Insufficient data (need ${period})`,
    };
  }

  // Calculate Typical Prices
  const typicalPrices: number[] = [];
  for (let i = 0; i < closes.length; i++) {
    typicalPrices.push((highs[i] + lows[i] + closes[i]) / 3);
  }

  const cci = computeCCI(typicalPrices, period);
  if (cci === null) {
    return {
      value: null,
      signal: "HOLD",
      reason: "Unable to compute CCI",
    };
  }

  // CCI Strategies
  // Bullish: > 100 (Strong Trend) or rising from oversold < -100
  // Bearish: < -100 (Strong Trend) or falling from overbought > 100

  if (cci > 100) {
    return {
      value: cci,
      signal: "BUY",
      reason: `CCI indicating strong uptrend (${cci.toFixed(0)} > 100)`,
      metadata: { cci },
    };
  }

  if (cci < -100) {
    return {
      value: cci,
      signal: "SELL",
      reason: `CCI indicating strong downtrend (${cci.toFixed(0)} < -100)`,
      metadata: { cci },
    };
  }

  return {
    value: cci,
    signal: "HOLD",
    reason: `CCI neutral (${cci.toFixed(0)})`,
    metadata: { cci },
  };
}

/**
 * Compute Parabolic SAR
 * @param {number[]} highs - High prices
 * @param {number[]} lows - Low prices
 * @param {number[]} closes - Close prices
 * @param {number} [startStep=0.02] - Start step (default 0.02)
 * @param {number} [maxStep=0.2] - Max step (default 0.2)
 * @return {Object|null} SAR value and trend direction
 */
export function computeParabolicSAR(
  highs: number[],
  lows: number[],
  closes: number[],
  startStep = 0.02,
  maxStep = 0.2
): { sar: number; isUptrend: boolean } | null {
  if (!highs || !lows || highs.length < 2) return null;

  let isUptrend = true;
  let ep = highs[0]; // Extreme Point
  let sar = lows[0]; // Starting SAR
  let af = startStep; // Acceleration Factor

  for (let i = 1; i < closes.length; i++) {
    const prevSar = sar;
    sar = prevSar + af * (ep - prevSar);

    if (isUptrend) {
      if (i >= 1) sar = Math.min(sar, lows[i - 1]);
      if (i >= 2) sar = Math.min(sar, lows[i - 2]);

      if (lows[i] < sar) {
        isUptrend = false;
        sar = ep;
        ep = lows[i];
        af = startStep;
      } else {
        if (highs[i] > ep) {
          ep = highs[i];
          af = Math.min(af + startStep, maxStep);
        }
      }
    } else {
      if (i >= 1) sar = Math.max(sar, highs[i - 1]);
      if (i >= 2) sar = Math.max(sar, highs[i - 2]);

      if (highs[i] > sar) {
        isUptrend = true;
        sar = ep;
        ep = highs[i];
        af = startStep;
      } else {
        if (lows[i] < ep) {
          ep = lows[i];
          af = Math.min(af + startStep, maxStep);
        }
      }
    }
  }

  return { sar, isUptrend };
}

/**
 * Evaluate Parabolic SAR
 * @param {number[]} highs - High prices
 * @param {number[]} lows - Low prices
 * @param {number[]} closes - Close prices
 * @param {number} [step=0.02] - Acceleration factor step (default 0.02)
 * @param {number} [max=0.2] - Max acceleration factor (default 0.2)
 * @return {IndicatorResult} IndicatorResult
 */
export function evaluateParabolicSAR(
  highs: number[],
  lows: number[],
  closes: number[],
  step = 0.02,
  max = 0.2
): IndicatorResult {
  const result = computeParabolicSAR(highs, lows, closes, step, max);
  if (!result) {
    return {
      value: null,
      signal: "HOLD",
      reason: "Cannot calculate SAR",
    };
  }

  const { sar, isUptrend } = result;

  if (isUptrend) {
    return {
      value: sar,
      signal: "BUY",
      reason: `Parabolic SAR below price (${sar.toFixed(2)})`,
      metadata: { sar, isUptrend: true },
    };
  } else {
    return {
      value: sar,
      signal: "SELL",
      reason: `Parabolic SAR above price (${sar.toFixed(2)})`,
      metadata: { sar, isUptrend: false },
    };
  }
}

/**
 * Evaluate all 12 indicators and determine if all are "green" meeting criteria
 * @param {object} symbolData - Symbol OHLCV data.
 * @param {object} marketData - Market index price and volume data.
 * @param {object} config - Configuration for indicator parameters.
 * @return {MultiIndicatorResult} Combined result from all indicators.
 */
export function evaluateAllIndicators(
  symbolData: {
    opens?: number[];
    highs?: number[];
    lows?: number[];
    closes: number[];
    volumes?: number[];
  },
  marketData: { closes: number[]; volumes?: number[] },
  config: {
    rsiPeriod?: number;
    marketFastPeriod?: number;
    marketSlowPeriod?: number;
    customIndicators?: CustomIndicatorConfig[];
    enabledIndicators?: string[];
  } = {}
): MultiIndicatorResult {
  // Optimization: Reduce logging spam in loops
  // logger.info("Evaluating all technical indicators", { ... });

  const isEnabled = (key: string) => {
    if (!config.enabledIndicators || config.enabledIndicators.length === 0) {
      return true;
    }
    return config.enabledIndicators.includes(key);
  };

  const disabledResult: IndicatorResult = {
    value: null,
    signal: "HOLD",
    reason: "Disabled",
  };

  // Pre-process: Filter out zero-volume data points (market closed/bad data)
  // This prevents skewing averages and triggering "Low volume (0% of avg)"
  if (symbolData.volumes && symbolData.volumes.length > 0) {
    const validIndices: number[] = [];
    const limit = Math.min(symbolData.volumes.length, symbolData.closes.length);
    let hasZeroVolume = false;

    for (let i = 0; i < limit; i++) {
      if (symbolData.volumes[i] > 0) {
        validIndices.push(i);
      } else {
        hasZeroVolume = true;
      }
    }

    // Only filter if we have some valid volumes.
    // If ALL volumes are zero (e.g. Index like ^VIX), keep the data.
    if (hasZeroVolume && validIndices.length > 0) {
      const v = symbolData.volumes;
      symbolData.closes = validIndices.map((i) => symbolData.closes[i]);
      symbolData.volumes = validIndices.map((i) => v[i]);
      if (symbolData.opens && symbolData.opens.length >= limit) {
        const o = symbolData.opens;
        symbolData.opens = validIndices.map((i) => o[i]);
      }
      if (symbolData.highs && symbolData.highs.length >= limit) {
        const h = symbolData.highs;
        symbolData.highs = validIndices.map((i) => h[i]);
      }
      if (symbolData.lows && symbolData.lows.length >= limit) {
        const l = symbolData.lows;
        symbolData.lows = validIndices.map((i) => l[i]);
      }
    }
  }

  const highs = symbolData.highs || symbolData.closes;
  const lows = symbolData.lows || symbolData.closes;
  const volumes = symbolData.volumes || [];

  // 1. Price Movement (chart patterns)
  const priceMovement = isEnabled("priceMovement") ?
    detectChartPattern(
      symbolData.closes,
      volumes,
      symbolData.opens,
      highs,
      lows
    ) :
    disabledResult;

  // 2. Momentum (RSI)
  const momentum = isEnabled("momentum") ?
    evaluateMomentum(symbolData.closes, config.rsiPeriod || 14) :
    disabledResult;

  // 3. Market Direction (SPY/QQQ moving averages)
  const marketDirection = isEnabled("marketDirection") ?
    evaluateMarketDirection(
      marketData.closes,
      config.marketFastPeriod || 10,
      config.marketSlowPeriod || 30
    ) :
    disabledResult;

  // 4. Volume
  const volume = isEnabled("volume") ?
    evaluateVolume(volumes, symbolData.closes) :
    disabledResult;

  // 5. MACD
  const macd = isEnabled("macd") ?
    evaluateMACD(symbolData.closes) :
    disabledResult;

  // 6. Bollinger Bands
  const bollingerBands = isEnabled("bollingerBands") ?
    evaluateBollingerBands(symbolData.closes) :
    disabledResult;

  // 7. Stochastic
  const stochastic = isEnabled("stochastic") ?
    evaluateStochastic(highs, lows, symbolData.closes) :
    disabledResult;

  // 8. ATR (volatility)
  const atr = isEnabled("atr") ?
    evaluateATR(highs, lows, symbolData.closes) :
    disabledResult;

  // 9. OBV
  const obv = isEnabled("obv") ?
    evaluateOBV(symbolData.closes, volumes) :
    disabledResult;

  // 10. VWAP (Volume Weighted Average Price)
  const vwap = isEnabled("vwap") ?
    evaluateVWAP(highs, lows, symbolData.closes, volumes) :
    disabledResult;

  // 11. ADX (Average Directional Index)
  const adx = isEnabled("adx") ?
    evaluateADX(highs, lows, symbolData.closes) :
    disabledResult;

  // 12. Williams %R
  const williamsR = isEnabled("williamsR") ?
    evaluateWilliamsR(highs, lows, symbolData.closes) :
    disabledResult;

  // 13. Ichimoku Cloud
  const ichimoku = isEnabled("ichimoku") ?
    evaluateIchimokuCloud(highs, lows, symbolData.closes) :
    disabledResult;

  // 14. CCI
  const cci = isEnabled("cci") ?
    evaluateCCI(highs, lows, symbolData.closes) :
    disabledResult;

  // 15. Parabolic SAR
  const parabolicSar = isEnabled("parabolicSar") ?
    evaluateParabolicSAR(highs, lows, symbolData.closes) :
    disabledResult;

  // Custom Indicators
  const customResults: Record<string, IndicatorResult> = {};
  if (config.customIndicators) {
    for (const customConfig of config.customIndicators) {
      // Assuming custom indicators are always enabled if present in this list
      // Or we can filter them out before passing
      customResults[customConfig.id] = evaluateCustomIndicator(
        customConfig,
        symbolData.closes,
        highs,
        lows,
        volumes
      );
    }
  }

  const indicators = {
    priceMovement,
    momentum,
    marketDirection,
    volume,
    macd,
    bollingerBands,
    stochastic,
    atr,
    obv,
    vwap,
    adx,
    williamsR,
    ichimoku,
    cci,
    parabolicSar,
  };

  // Calculate weighted signal strength (0-100)
  // Weight distribution:
  // - High (1.5): Price Movement (Patterns)
  // - Medium (1.2): Momentum (RSI, Stochastic),
  //   Trend (MACD, ADX, Market Direction)
  // - Low (1.0): Others
  const weights: Record<string, number> = {
    priceMovement: 1.5,
    momentum: 1.2,
    marketDirection: 1.2,
    macd: 1.2,
    adx: 1.2,
    // Default others to 1.0
  };

  let totalWeight = 0;
  let weightedScore = 0;
  // Filter active valid values for calculation
  const standardVals = Object.entries(indicators)
    .filter(([k]) => isEnabled(k))
    .map(([, v]) => v);

  const customVals = Object.values(customResults);
  const allVals = [...standardVals, ...customVals];

  const buyCount = allVals.filter((i) => i.signal === "BUY").length;
  const sellCount = allVals.filter((i) => i.signal === "SELL").length;
  const holdCount = allVals.filter((i) => i.signal === "HOLD").length;
  const totalIndicators = allVals.length;

  // Process standard indicators
  for (const [key, indicator] of Object.entries(indicators)) {
    if (!isEnabled(key)) continue;

    const weight = weights[key] || 1.0;
    totalWeight += weight;
    if (indicator.signal === "BUY") {
      weightedScore += weight;
    } else if (indicator.signal === "SELL") {
      weightedScore -= weight;
    }
    // HOLD adds 0
  }

  // Process custom indicators (weight 1.0)
  for (const indicator of customVals) {
    totalWeight += 1.0;
    if (indicator.signal === "BUY") {
      weightedScore += 1.0;
    } else if (indicator.signal === "SELL") {
      weightedScore -= 1.0;
    }
  }

  // Normalize to 0-100 range
  // Range of weightedScore is [-totalWeight, +totalWeight]
  // Shift to [0, 2*totalWeight] then divide by 2*totalWeight
  const normalizedScore = totalWeight > 0 ?
    (weightedScore + totalWeight) / (2 * totalWeight) :
    0.5;
  const signalStrength = Math.round(normalizedScore * 100);

  // Check if all indicators are "green" (BUY signal)
  const allGreen = allVals.length > 0 &&
    allVals.every((ind) => ind.signal === "BUY");

  // Check if all indicators are "red" (SELL signal)
  const allRed = allVals.length > 0 &&
    allVals.every((ind) => ind.signal === "SELL");

  const macroAssessment = isEnabled("marketDirection") ?
    evaluateMacroAssessment(marketDirection) :
    undefined;

  let overallSignal: "BUY" | "SELL" | "HOLD";
  let reason: string;

  if (allGreen) {
    overallSignal = "BUY";
    reason = `All ${totalIndicators} indicators are GREEN - ` +
      `Strong BUY signal (strength: ${signalStrength})`;
  } else if (signalStrength >= 75) {
    overallSignal = "BUY";
    reason = `Strong BUY signal (strength: ${signalStrength}). ` +
      `BUY: ${buyCount}, SELL: ${sellCount}, HOLD: ${holdCount}.`;
  } else if (allRed) {
    overallSignal = "SELL";
    reason = `All ${totalIndicators} indicators are RED - ` +
      `Strong SELL signal (strength: ${signalStrength})`;
  } else if (signalStrength <= 25) {
    overallSignal = "SELL";
    reason = `Strong SELL signal (strength: ${signalStrength}). ` +
      `BUY: ${buyCount}, SELL: ${sellCount}, HOLD: ${holdCount}.`;
  } else {
    overallSignal = "HOLD";
    reason = `BUY: ${buyCount}, ` + // Removed 'Mixed signals' it was redundant
      `SELL: ${sellCount}, HOLD: ${holdCount}. ` +
      `Signal strength: ${signalStrength}/100.`;
  }

  if (macroAssessment && macroAssessment.status !== "NEUTRAL") {
    reason += ` Market: ${macroAssessment.status}.`;
  }

  // Optimized: Removed dense logging per evaluation
  /*
  logger.info("Multi-indicator evaluation complete", {
    allGreen,
    overallSignal,
    signalStrength,
    ...
  });
  */

  return {
    allGreen,
    indicators,
    customIndicators: customResults,
    macroAssessment,
    overallSignal,
    reason,
    signalStrength,
  };
}


/**
 * Compute Rate of Change (ROC)
 * @param {number[]} prices - Array of prices.
 * @param {number} period - The lookback calculation period.
 * @return {number|null} The computed ROC or null.
 */
export function computeROC(prices: number[], period = 9): number | null {
  if (!prices || prices.length < period + 1) return null;
  const currentPrice = prices[prices.length - 1];
  const prevPrice = prices[prices.length - 1 - period];

  if (prevPrice === 0) return 0;
  return ((currentPrice - prevPrice) / prevPrice) * 100;
}

/**
 * Evaluate ROC (Rate of Change)
 * @param {number[]} prices - Array of close prices.
 * @param {number} period - ROC period (default 9).
 * @return {IndicatorResult} The ROC evaluation result.
 */
export function evaluateROC(
  prices: number[],
  period = 9
): IndicatorResult {
  const roc = computeROC(prices, period);
  if (roc === null) {
    return {
      value: null,
      signal: "HOLD",
      reason: `Insufficient data for ROC (need ${period + 1})`,
    };
  }

  // Basic interpretation: > 0 implies upward momentum, < 0 implies downward
  // Strong moves might be > 10 or < -10 depending on asset/timeframe

  if (roc > 5) {
    return {
      value: roc,
      signal: "BUY",
      reason: `ROC bullish momentum (+${roc.toFixed(2)}%)`,
    };
  }

  if (roc < -5) {
    return {
      value: roc,
      signal: "SELL",
      reason: `ROC bearish momentum (${roc.toFixed(2)}%)`,
    };
  }

  return {
    value: roc,
    signal: "HOLD",
    reason: `ROC neutral (${roc.toFixed(2)}%)`,
  };
}

/**
 * Evaluate a custom indicator based on configuration.
 * @param {CustomIndicatorConfig} config - The indicator configuration.
 * @param {number[]} prices - Array of close prices.
 * @param {number[]} highs - Array of high prices.
 * @param {number[]} lows - Array of low prices.
 * @param {number[]} volumes - Array of volumes.
 * @return {IndicatorResult} The evaluation result.
 */
export function evaluateCustomIndicator(
  config: CustomIndicatorConfig,
  prices: number[],
  highs: number[],
  lows: number[],
  volumes: number[]
): IndicatorResult {
  let value: number | null = null;
  let prevValue: number | null = null;
  let signal: "BUY" | "SELL" | "HOLD" = "HOLD";
  let reason = "";

  try {
    const getNumberParam = (
      val: unknown,
      defaultVal: number,
      isFloat = false
    ): number => {
      if (typeof val === "number") return val;
      if (typeof val === "string") {
        const parsed = isFloat ? parseFloat(val) : parseInt(val, 10);
        return Number.isFinite(parsed) ? parsed : defaultVal;
      }
      return defaultVal;
    };

    const getStringParam = (val: unknown, defaultVal: string): string => {
      if (typeof val === "string") return val;
      return defaultVal;
    };

    // Helper to calculate indicator value for a given set of data
    const calculateValue = (
      p: number[],
      h: number[],
      l: number[],
      v: number[]
    ): number | null => {
      switch (config.type) {
      case "SMA":
        return computeSMA(
          p,
          getNumberParam(config.parameters.period, 14)
        );
      case "EMA":
        return computeEMA(
          p,
          getNumberParam(config.parameters.period, 14)
        );
      case "RSI":
        return computeRSI(
          p,
          getNumberParam(config.parameters.period, 14)
        );
      case "MACD": {
        const macdRes = computeMACD(
          p,
          getNumberParam(config.parameters.fastPeriod, 12),
          getNumberParam(config.parameters.slowPeriod, 26),
          getNumberParam(config.parameters.signalPeriod, 9)
        );
        if (!macdRes) return null;
        const comp = getStringParam(config.parameters.component, "histogram");
        if (comp === "macd") return macdRes.macd;
        if (comp === "signal") return macdRes.signal;
        return macdRes.histogram;
      }
      case "Bollinger": {
        const bbRes = computeBollingerBands(
          p,
          getNumberParam(config.parameters.period, 20),
          getNumberParam(config.parameters.stdDev, 2, true)
        );
        if (!bbRes) return null;
        const comp = getStringParam(config.parameters.component, "middle");
        if (comp === "upper") return bbRes.upper;
        if (comp === "lower") return bbRes.lower;
        return bbRes.middle;
      }
      case "Stochastic": {
        const stochRes = computeStochastic(
          h,
          l,
          p,
          getNumberParam(config.parameters.kPeriod, 14),
          getNumberParam(config.parameters.dPeriod, 3)
        );
        if (!stochRes) return null;
        const comp = getStringParam(config.parameters.component, "k");
        if (comp === "d") return stochRes.d;
        return stochRes.k;
      }
      case "ATR":
        return computeATR(
          h,
          l,
          p,
          getNumberParam(config.parameters.period, 14)
        );
      case "OBV": {
        const obvRes = computeOBV(p, v);
        return obvRes && obvRes.length > 0 ?
          obvRes[obvRes.length - 1] : null;
      }
      case "WilliamsR":
        return computeWilliamsR(
          h,
          l,
          p,
          getNumberParam(config.parameters.period, 14)
        );
      case "CCI": {
        // CCI requires Typical Prices: (High + Low + Close) / 3
        const period = getNumberParam(config.parameters.period, 20);
        if (
          h.length >= period &&
          l.length >= period &&
          p.length >= period
        ) {
          const typicalPrices: number[] = [];
          const len = Math.min(h.length, l.length, p.length);
          for (let i = 0; i < len; i++) {
            typicalPrices.push((h[i] + l[i] + p[i]) / 3);
          }
          return computeCCI(typicalPrices, period);
        }
        return null;
      }
      case "ROC":
        return computeROC(
          p,
          getNumberParam(config.parameters.period, 9)
        );
      case "VWAP":
        return computeVWAP(h, l, p, v);
      case "ADX": {
        const adxRes = computeADX(
          h,
          l,
          p,
          getNumberParam(config.parameters.period, 14)
        );
        if (!adxRes) return null;
        const comp = getStringParam(config.parameters.component, "adx");
        if (comp === "plusDI") return adxRes.plusDI;
        if (comp === "minusDI") return adxRes.minusDI;
        return adxRes.adx;
      }
      default:
        return null;
      }
    };

    // 1. Calculate current value
    value = calculateValue(prices, highs, lows, volumes);

    if (value === null) {
      return {
        value: null,
        signal: "HOLD",
        reason: `Could not compute ${config.name}`,
      };
    }

    // 2. Determine Comparison Value (Current)
    const currentPrice = prices[prices.length - 1];
    const compareValue = config.compareToPrice ?
      currentPrice : config.threshold;

    if (compareValue === undefined || compareValue === null) {
      return {
        value,
        signal: "HOLD",
        reason: `No comparison value for ${config.name}`,
      };
    }

    // 3. Check Condition
    let conditionMet = false;
    const isCrossover = config.condition.startsWith("CrossOver");

    if (isCrossover) {
      // Calculate Previous Value
      // We slice the arrays to simulate "previous candle stick" state
      if (prices.length > 1) {
        prevValue = calculateValue(
          prices.slice(0, -1),
          highs.slice(0, -1),
          lows.slice(0, -1),
          volumes.slice(0, -1)
        );
      }

      const prevPrice = prices.length > 1 ? prices[prices.length - 2] : null;

      // Ensure we have previous data
      if (prevValue !== null && prevPrice !== null) {
        const prevCompareValue = config.compareToPrice ?
          prevPrice : config.threshold;

        if (prevCompareValue !== undefined && prevCompareValue !== null) {
          if (config.condition === "CrossOverAbove") {
            // Crossed ABOVE: Previous was <=, Current is >
            if (prevValue <= prevCompareValue && value > compareValue) {
              conditionMet = true;
            }
          } else if (config.condition === "CrossOverBelow") {
            // Crossed BELOW: Previous was >=, Current is <
            if (prevValue >= prevCompareValue && value < compareValue) {
              conditionMet = true;
            }
          }
        }
      }
    } else {
      // Standard GreaterThan / LessThan
      if (config.condition === "GreaterThan") {
        if (value > compareValue) conditionMet = true;
      } else if (config.condition === "LessThan") {
        if (value < compareValue) conditionMet = true;
      }
    }

    if (conditionMet) {
      signal = config.signalType || "BUY";
      reason = `${config.name} (${signal}): ${value.toFixed(2)} ` +
        `met condition ${config.condition} ` +
        `${compareValue.toFixed(2)}`;
    } else {
      signal = "HOLD";
      reason = `${config.name}: ${value.toFixed(2)} ` +
        `did not meet condition ${config.condition} ` +
        `${compareValue.toFixed(2)}`;
    }

    const metadata: Record<string, unknown> = {
      condition: config.condition,
      threshold: config.threshold,
      compareToPrice: config.compareToPrice,
      signalType: config.signalType,
    };
    if (prevValue !== null) metadata.prevValue = prevValue;

    return { value, signal, reason, metadata };
  } catch (e) {
    return {
      value: null,
      signal: "HOLD",
      reason: `Error computing ${config.name}: ${e}`,
    };
  }
}
