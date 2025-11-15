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
  // Future enhancement: use volumes for pattern confirmation
  void volumes;

  if (!prices || prices.length < 20) {
    return {
      value: null,
      signal: "HOLD",
      reason: "Insufficient data for pattern detection " +
        "(need at least 20 periods)",
    };
  }

  const recentPrices = prices.slice(-20);
  const currentPrice = recentPrices[recentPrices.length - 1];
  const previousPrice = recentPrices[recentPrices.length - 2];

  // Calculate short-term and medium-term trends
  const shortMA = computeSMA(recentPrices, 5);
  const mediumMA = computeSMA(recentPrices, 10);
  const longMA = computeSMA(recentPrices, 20);

  if (!shortMA || !mediumMA || !longMA) {
    return {
      value: null,
      signal: "HOLD",
      reason: "Unable to compute moving averages for pattern detection",
    };
  }

  // Detect bullish patterns
  const isBullishTrend = shortMA > mediumMA && mediumMA > longMA;
  const isBullishBreakout = currentPrice > previousPrice &&
    currentPrice > longMA * 1.02; // 2% above long MA

  // Detect bearish patterns
  const isBearishTrend = shortMA < mediumMA && mediumMA < longMA;
  const isBearishBreakdown = currentPrice < previousPrice &&
    currentPrice < longMA * 0.98; // 2% below long MA

  // Cup and Handle pattern (simplified)
  const prices10to5 = recentPrices.slice(-10, -5);
  const lowest = Math.min(...prices10to5);
  const isRecovering = currentPrice > lowest * 1.05;

  if (isBullishTrend && (isBullishBreakout || isRecovering)) {
    const patternType = isBullishBreakout ?
      "Breakout" : "Cup & Handle formation";
    const patternKey = isBullishBreakout ? "breakout" : "cup_handle";
    return {
      value: 1,
      signal: "BUY",
      reason: `Bullish pattern detected: ${patternType}, ` +
        `price ${currentPrice.toFixed(2)} above key MAs`,
      metadata: { shortMA, mediumMA, longMA, pattern: patternKey },
    };
  }

  if (isBearishTrend && isBearishBreakdown) {
    return {
      value: -1,
      signal: "SELL",
      reason: "Bearish pattern detected: Breakdown, " +
        `price ${currentPrice.toFixed(2)} below key MAs`,
      metadata: { shortMA, mediumMA, longMA, pattern: "breakdown" },
    };
  }

  return {
    value: 0,
    signal: "HOLD",
    reason: "No clear pattern detected. " +
      `Current price: ${currentPrice.toFixed(2)}, ` +
      `5-MA: ${shortMA.toFixed(2)}, ` +
      `10-MA: ${mediumMA.toFixed(2)}, ` +
      `20-MA: ${longMA.toFixed(2)}`,
    metadata: { shortMA, mediumMA, longMA },
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
