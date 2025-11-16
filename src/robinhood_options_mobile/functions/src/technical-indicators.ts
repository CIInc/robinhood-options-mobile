import * as logger from "firebase-functions/logger";

/**
 * Technical Indicators Module
 * Implements various technical analysis indicators for automated trading
 */

export interface IndicatorResult {
  value: number | null;
  signal: "BUY" | "SELL" | "HOLD";
  reason: string;
  metadata?: Record<string, any>;
}

export interface MultiIndicatorResult {
  allGreen: boolean;
  indicators: {
    priceMovement: IndicatorResult;
    momentum: IndicatorResult;
    marketDirection: IndicatorResult;
    volume: IndicatorResult;
  };
  overallSignal: "BUY" | "SELL" | "HOLD";
  reason: string;
}

/**
 * Compute Simple Moving Average (SMA)
 * @param {number[]} prices - Array of prices.
 * @param {number} period - The period for the SMA.
 * @return {number|null} The computed SMA or null if not enough data.
 */
export function computeSMA(prices: number[], period: number): number | null {
  if (!prices || prices.length < period || period <= 0) return null;
  const slice = prices.slice(prices.length - period);
  const sum = slice.reduce((a, b) => a + b, 0);
  return sum / period;
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
  let ema = prices.slice(0, period).reduce((a, b) => a + b, 0) / period;

  for (let i = period; i < prices.length; i++) {
    ema = (prices[i] - ema) * multiplier + ema;
  }

  return ema;
}

/**
 * Compute Relative Strength Index (RSI)
 * @param {number[]} prices - Array of prices.
 * @param {number} period - The period for RSI calculation (default 14).
 * @return {number|null} The computed RSI or null if not enough data.
 */
export function computeRSI(prices: number[], period = 14): number | null {
  if (!prices || prices.length < period + 1) return null;

  const changes: number[] = [];
  for (let i = 1; i < prices.length; i++) {
    changes.push(prices[i] - prices[i - 1]);
  }

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

  // Calculate RSI using smoothed averages
  for (let i = period; i < changes.length; i++) {
    const change = changes[i];
    if (change > 0) {
      avgGain = (avgGain * (period - 1) + change) / period;
      avgLoss = (avgLoss * (period - 1)) / period;
    } else {
      avgGain = (avgGain * (period - 1)) / period;
      avgLoss = (avgLoss * (period - 1) + Math.abs(change)) / period;
    }
  }

  if (avgLoss === 0) return 100;

  const rs = avgGain / avgLoss;
  const rsi = 100 - (100 / (1 + rs));

  return rsi;
}

/**
 * Detect chart patterns for price movement
 * Simplified pattern detection based on recent price action
 * @param {number[]} prices - Array of historical prices.
 * @param {number[]} volumes - Optional array of volumes.
 * @return {IndicatorResult} The pattern detection result.
 */
export function detectChartPattern(
  prices: number[],
  volumes?: number[]
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
    let num = 0;
    let den = 0;
    for (let i = 0; i < n; i++) {
      const x = i;
      const y = recentPrices[i];
      num += (x - xMean) * (y - currentPrice);
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

  // 2. Double Top / Double Bottom (last two peaks/troughs similar height)
  const tolerancePct = 0.01; // 1% tolerance
  if (peaks.length >= 2) {
    const a = px(peaks[peaks.length - 2]);
    const b = px(peaks[peaks.length - 1]);
    const dblTop = Math.abs(a - b) / ((a + b) / 2) < tolerancePct &&
      currentPrice < b * 0.985;
    if (dblTop) {
      patterns.push({
        key: "double_top",
        label: "Double Top",
        direction: "bearish",
        confidence: 0.55,
        details: { peakA: a, peakB: b },
      });
    }
  }
  if (troughs.length >= 2) {
    const a = px(troughs[troughs.length - 2]);
    const b = px(troughs[troughs.length - 1]);
    const dblBottom = Math.abs(a - b) / ((a + b) / 2) < tolerancePct &&
      currentPrice > b * 1.015;
    if (dblBottom) {
      patterns.push({
        key: "double_bottom",
        label: "Double Bottom",
        direction: "bullish",
        confidence: 0.55,
        details: { troughA: a, troughB: b },
      });
    }
  }

  // 3. Head & Shoulders (3 peaks with middle highest and shoulders similar)
  if (peaks.length >= 3) {
    const p1 = px(peaks[peaks.length - 3]);
    const p2 = px(peaks[peaks.length - 2]);
    const p3 = px(peaks[peaks.length - 1]);
    const shouldersClose = Math.abs(p1 - p3) / ((p1 + p3) / 2) < 0.02;
    const headHigher = p2 > p1 * 1.01 && p2 > p3 * 1.01;
    if (shouldersClose && headHigher && currentPrice < p3 * 0.985) {
      patterns.push({
        key: "head_shoulders",
        label: "Head & Shoulders",
        direction: "bearish",
        confidence: 0.6,
        details: { left: p1, head: p2, right: p3 },
      });
    }
  }

  // 4. Triangles (ascending & descending)
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
    if (flatHighs / ((lastPeaks[0] + lastPeaks[2]) / 2) < 0.01 && risingLows) {
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
    const lowFlat = flatLows / ((lastTroughs[0] + lastTroughs[2]) / 2) < 0.01 &&
      fallingHighs;
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
  const asc = isAscendingTriangle();
  if (asc) patterns.push(asc);
  const desc = isDescendingTriangle();
  if (desc) patterns.push(desc);

  // 5. Cup & Handle (retain previous simplified logic)
  const handleSlice = recentPrices.slice(-10, -5);
  const handleLow = Math.min(...handleSlice);
  const recovering = currentPrice > handleLow * 1.05 && ma5 > ma10;
  if (recovering) {
    patterns.push({
      key: "cup_handle",
      label: "Cup & Handle",
      direction: "bullish",
      confidence: 0.5,
      details: { handleLow, currentPrice },
    });
  }

  // 6. Flag (sharp move followed by tight consolidation)
  const flagCandidate = (() => {
    if (recentPrices.length < 15) return null;
    const firstPart = recentPrices.slice(-15, -7);
    const secondPart = recentPrices.slice(-7);
    const movePct = (secondPart[0] - firstPart[0]) / firstPart[0];
    const consolidationRange = (Math.max(...secondPart) -
      Math.min(...secondPart)) / secondPart[0];
    if (Math.abs(movePct) > 0.06 && consolidationRange < 0.015) {
      const dir: "bullish" | "bearish" = movePct > 0 ? "bullish" : "bearish";
      return {
        key: "flag",
        label: dir === "bullish" ? "Bull Flag" : "Bear Flag",
        direction: dir,
        confidence: 0.55,
        details: { movePct, consolidationRange },
      } as PatternCandidate;
    }
    return null;
  })();
  if (flagCandidate) patterns.push(flagCandidate);

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
      reason: `${best.label} (conf ${(best.confidence * 100).toFixed(0)}%)`,
      metadata: {
        selectedPattern: best.key,
        confidence: best.confidence,
        patterns,
        ma5, ma10, ma20,
        slope,
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
      },
    };
  }

  return {
    value: 0,
    signal: "HOLD",
    reason: `No clear pattern. Px ${currentPrice.toFixed(2)}; ` +
      `MA5 ${ma5.toFixed(2)}, MA10 ${ma10.toFixed(2)}, MA20 ${ma20.toFixed(2)}`,
    metadata: { ma5, ma10, ma20, slope, patterns },
  };
}

/**
 * Evaluate momentum using RSI and other momentum indicators
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

  const rsi = computeRSI(prices, rsiPeriod);

  if (rsi === null) {
    return {
      value: null,
      signal: "HOLD",
      reason: "Unable to compute RSI",
    };
  }

  // RSI thresholds
  const oversoldThreshold = 30;
  const overboughtThreshold = 70;
  const neutralLower = 40;
  const neutralUpper = 60;

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

  const fastMA = computeSMA(marketPrices, fastPeriod);
  const slowMA = computeSMA(marketPrices, slowPeriod);

  // Previous MAs for crossover detection
  const fastPrevMA = marketPrices.length > fastPeriod ?
    computeSMA(marketPrices.slice(0, -1), fastPeriod) : null;
  const slowPrevMA = marketPrices.length > slowPeriod ?
    computeSMA(marketPrices.slice(0, -1), slowPeriod) : null;

  if (!fastMA || !slowMA) {
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
  const volumeRatio = currentVolume / avgVolume;

  const currentPrice = recentPrices[recentPrices.length - 1];
  const previousPrice = recentPrices[recentPrices.length - 2];
  const priceDiff = currentPrice - previousPrice;
  const priceChange = (priceDiff / previousPrice) * 100;

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
 * Evaluate all 4 indicators and determine if all are "green" meeting criteria
 * @param {object} symbolData - Symbol price and volume data.
 * @param {object} marketData - Market index price and volume data.
 * @param {object} config - Configuration for indicator parameters.
 * @return {MultiIndicatorResult} Combined result from all indicators.
 */
export function evaluateAllIndicators(
  symbolData: { prices: number[]; volumes?: number[] },
  marketData: { prices: number[]; volumes?: number[] },
  config: {
    rsiPeriod?: number;
    marketFastPeriod?: number;
    marketSlowPeriod?: number;
  } = {}
): MultiIndicatorResult {
  logger.info("Evaluating all technical indicators", {
    symbolDataLength: symbolData.prices.length,
    marketDataLength: marketData.prices.length,
    config,
  });

  // 1. Price Movement (chart patterns)
  const priceMovement = detectChartPattern(
    symbolData.prices,
    symbolData.volumes
  );

  // 2. Momentum (RSI)
  const momentum = evaluateMomentum(
    symbolData.prices,
    config.rsiPeriod || 14
  );

  // 3. Market Direction (SPY/QQQ moving averages)
  const marketDirection = evaluateMarketDirection(
    marketData.prices,
    config.marketFastPeriod || 10,
    config.marketSlowPeriod || 30
  );

  // 4. Volume
  const volume = evaluateVolume(
    symbolData.volumes || [],
    symbolData.prices
  );

  const indicators = {
    priceMovement,
    momentum,
    marketDirection,
    volume,
  };

  // Check if all 4 indicators are "green" (BUY signal)
  const allGreen =
    priceMovement.signal === "BUY" &&
    momentum.signal === "BUY" &&
    marketDirection.signal === "BUY" &&
    volume.signal === "BUY";

  // Check if all 4 indicators are "red" (SELL signal)
  const allRed =
    priceMovement.signal === "SELL" &&
    momentum.signal === "SELL" &&
    marketDirection.signal === "SELL" &&
    volume.signal === "SELL";

  let overallSignal: "BUY" | "SELL" | "HOLD";
  let reason: string;

  if (allGreen) {
    overallSignal = "BUY";
    reason = "All 4 indicators are GREEN - Strong BUY signal";
  } else if (allRed) {
    overallSignal = "SELL";
    reason = "All 4 indicators are RED - Strong SELL signal";
  } else {
    overallSignal = "HOLD";
    const vals = Object.values(indicators);
    const buyCount = vals.filter((i) => i.signal === "BUY").length;
    const sellCount = vals.filter((i) => i.signal === "SELL").length;
    const holdCount = vals.filter((i) => i.signal === "HOLD").length;

    reason = `Mixed signals - BUY: ${buyCount}, ` +
      `SELL: ${sellCount}, HOLD: ${holdCount}. ` +
      "Need all 4 indicators aligned for action.";
  }

  logger.info("Multi-indicator evaluation complete", {
    allGreen,
    overallSignal,
    indicators: {
      priceMovement: priceMovement.signal,
      momentum: momentum.signal,
      marketDirection: marketDirection.signal,
      volume: volume.signal,
    },
  });

  return {
    allGreen,
    indicators,
    overallSignal,
    reason,
  };
}
