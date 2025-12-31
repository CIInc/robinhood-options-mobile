import { onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import fetch from "node-fetch";
import { getMarketData } from "./agentic-trading";
import { computeATR } from "./technical-indicators";

/**
 * Fetches symbol information (sector, beta, etc.) from Yahoo Finance.
 * @param {string} symbol - The stock symbol.
 * @return {Promise<object|null>} The symbol info or null.
 */
async function getSymbolInfo(symbol: string):
  Promise<{ sector?: string, beta?: number, trailingPE?: number } | null> {
  try {
    const url = `https://query1.finance.yahoo.com/v8/finance/quote?symbols=${symbol}`;
    const resp = await fetch(url);
    const data: any = await resp.json();
    const result = data?.quoteResponse?.result?.[0];
    if (result) {
      return {
        sector: result.sector,
        beta: result.beta,
        trailingPE: result.trailingPE,
      };
    }
  } catch (err) {
    logger.warn(`Failed to fetch quote for ${symbol}`, err);
  }
  return null;
}

/**
 * Calculates the correlation coefficient between two arrays of numbers.
 * @param {number[]} data1 - First data set.
 * @param {number[]} data2 - Second data set.
 * @return {number} The correlation coefficient (-1 to 1).
 */
function calculateCorrelation(data1: number[], data2: number[]): number {
  if (!data1 || !data2 || data1.length !== data2.length || data1.length === 0) {
    return 0;
  }
  const n = data1.length;
  const mean1 = data1.reduce((a, b) => a + b, 0) / n;
  const mean2 = data2.reduce((a, b) => a + b, 0) / n;
  let num = 0;
  let den1 = 0;
  let den2 = 0;
  for (let i = 0; i < n; i++) {
    const dx = data1[i] - mean1;
    const dy = data2[i] - mean2;
    num += dx * dy;
    den1 += dx * dx;
    den2 += dy * dy;
  }
  if (den1 === 0 || den2 === 0) return 0;
  return num / Math.sqrt(den1 * den2);
}

/**
 * Calculates annualized volatility from price data.
 * @param {number[]} prices - Array of prices.
 * @return {number} Annualized volatility (0-100).
 */
function calculateVolatility(prices: number[]): number {
  if (!prices || prices.length < 2) return 0;
  const returns = [];
  for (let i = 1; i < prices.length; i++) {
    returns.push(Math.log(prices[i] / prices[i - 1]));
  }
  const mean = returns.reduce((a, b) => a + b, 0) / returns.length;
  const variance = returns.reduce((a, b) => a + Math.pow(b - mean, 2), 0) /
    (returns.length - 1);
  const stdDev = Math.sqrt(variance);
  return stdDev * Math.sqrt(252) * 100; // Annualized
}

/**
 * Calculates the total value of the portfolio including cash and positions.
 * @param {any} portfolioState - The portfolio state object.
 * @return {number} The total portfolio value.
 */
export function calculatePortfolioValue(portfolioState: any): number {
  if (!portfolioState) return 0;

  const cash = Number(portfolioState.buyingPower ??
    portfolioState.cashAvailable ?? 0);
  let totalValue = cash;

  for (const [symbol, data] of Object.entries(portfolioState)) {
    if (symbol === "cashAvailable" ||
      symbol === "buyingPower" || symbol === "highWaterMark") continue;

    let quantity = 0;
    let price = 0;

    if (typeof data === "object" && data !== null) {
      quantity = Number((data as any).quantity || 0);
      price = Number((data as any).price || 0);
    } else {
      // If data is just a number, it might be quantity, but we need price.
      // Without price, we can't value it.
      // Assuming simple key-value is not used for valuation without price
      // context or assuming the caller handles it.
      // In assessTrade, it tried to use proposal price if symbol matched.
      // Here we strictly calculate value based on state.
      continue;
    }

    if (quantity !== 0 && price > 0) {
      totalValue += quantity * price;
    }
  }
  return totalValue;
}

/**
 * Calculates the recommended position size based on ATR volatility.
 * Formula: Position Size = (Account Value * Risk %) / (ATR * Multiplier)
 * @param {number} accountValue - Total portfolio value.
 * @param {number} riskPerTrade - Percentage of account to risk (0-1).
 * @param {number} atr - The current ATR value.
 * @param {number} atrMultiplier - Multiplier for ATR (e.g., 2).
 * @return {number} The recommended quantity (number of shares).
 */
export function calculateDynamicPositionSize(
  accountValue: number,
  riskPerTrade: number,
  atr: number,
  atrMultiplier: number
): number {
  if (atr <= 0 || atrMultiplier <= 0) return 0;

  const riskAmount = accountValue * riskPerTrade;
  const stopLossDistance = atr * atrMultiplier;

  // Calculate number of shares
  // Risk Amount = Shares * Stop Loss Distance
  // Shares = Risk Amount / Stop Loss Distance

  const shares = Math.floor(riskAmount / stopLossDistance);

  return shares;
}

/**
 * Helper to extract current position quantity from portfolio state.
 * @param {any} portfolioState - The portfolio state object.
 * @param {string} symbol - The symbol to look up.
 * @return {number} The quantity held.
 */
export function getCurrentPosition(portfolioState: any,
  symbol: string): number {
  if (!portfolioState || !portfolioState[symbol]) return 0;

  if (typeof portfolioState[symbol] === "object" &&
    portfolioState[symbol].quantity !== undefined) {
    return Number(portfolioState[symbol].quantity);
  } else {
    return Number(portfolioState[symbol]);
  }
}

/**
 * Assesses a proposed trade against predefined risk parameters.
 * @param {object} proposal - The proposed trade details
 * (symbol, quantity, price, action).
 * @param {object} portfolioState - The current state of
 * the user's portfolio. Expected format:
 *   { cash: number, SYMBOL: number | {quantity: number, price: number}, ... }
 * @param {object} config - Risk configuration parameters
 * (e.g., max position size).
 * @param {object} marketData - Optional market data for advanced checks.
 * @return {Promise<object>} The risk assessment result.
 */
export async function assessTrade(proposal: any,
  portfolioState: any, config: any, marketData?: any) {
  logger.info("RiskGuard: assessTrade called", {
    proposal,
    portfolioState, config,
  });

  const maxPositionSize = config?.maxPositionSize ?? 100;
  const maxPortfolioConcentration = config?.maxPortfolioConcentration ?? 0.5;

  const symbol = proposal?.symbol;
  const qty = proposal?.quantity || 0;
  const price = proposal?.price || 0;
  const action = proposal?.action || "BUY";

  const metrics: any = {};

  // Check for sufficient funds (Cash Check)
  const cash = Number(portfolioState?.buyingPower ??
    portfolioState?.cashAvailable ?? 0);
  metrics.cashAvailable = cash;

  if (action === "BUY") {
    const tradeCost = Math.abs(qty * price);
    metrics.tradeCost = tradeCost;
    if (tradeCost > cash) {
      return {
        approved: false,
        reason: `Insufficient funds: Cost ${tradeCost.toFixed(2)} > ` +
          `Buying Power ${cash.toFixed(2)}`,
        metrics,
      };
    }
  }

  // Handle SELL actions - quantity should be negative or we need to adjust
  const adjustedQty = action === "SELL" ? -Math.abs(qty) : Math.abs(qty);

  // Extract current position for the symbol being traded
  const currentPosition = getCurrentPosition(portfolioState, symbol);
  metrics.currentPosition = currentPosition;

  // Check max position size (absolute value after trade)
  const proposedPosition = currentPosition + adjustedQty;
  metrics.proposedPosition = proposedPosition;
  metrics.maxPositionSize = maxPositionSize;

  if (Math.abs(proposedPosition) > maxPositionSize) {
    return {
      approved: false,
      reason: `Max position size exceeded: ${Math.abs(proposedPosition)} ` +
        `> ${maxPositionSize}`,
      metrics,
    };
  }

  // Calculate total portfolio value from ALL positions
  // We use the helper but we also need to handle the case where portfolioState
  // entries might not have price, but we have the proposal price for the
  // current symbol.
  let totalPortfolioValue = Number(portfolioState?.buyingPower ??
    portfolioState?.cashAvailable ?? 0);
  const positions: { [key: string]: { quantity: number, price: number } } = {};

  // Iterate through all positions in portfolioState
  for (const [posSymbol, posData] of Object.entries(portfolioState)) {
    if (posSymbol === "cashAvailable" ||
      posSymbol === "buyingPower" || posSymbol === "highWaterMark") continue;

    let posQuantity = 0;
    let posPrice: number | null = null;

    if (typeof posData === "object" && posData !== null) {
      posQuantity = Number((posData as any).quantity || 0);
      posPrice = Number((posData as any).price) || null;
    } else {
      posQuantity = Number(posData || 0);
      // For positions without explicit price, only use if it's the same symbol
      // (we have the proposal price for that symbol)
      if (posSymbol === symbol) {
        posPrice = price;
      }
    }

    // Only include positions with valid prices and non-zero quantities
    if (posQuantity !== 0 && posPrice !== null && posPrice > 0) {
      positions[posSymbol] = { quantity: posQuantity, price: posPrice };
      totalPortfolioValue += posQuantity * posPrice;
    }
  }

  // Calculate proposed position value (use signed value for BUY/SELL)
  const proposedPositionValue = proposedPosition * price;

  // Calculate concentration ratio
  const proposedConcentration = totalPortfolioValue > 0 ?
    (Math.abs(proposedPositionValue) / totalPortfolioValue) : 1.0;

  metrics.totalPortfolioValue = totalPortfolioValue;
  metrics.proposedPositionValue = proposedPositionValue;
  metrics.proposedConcentration = proposedConcentration;
  metrics.maxPortfolioConcentration = maxPortfolioConcentration;

  logger.info("RiskGuard: Portfolio analysis", {
    symbol,
    currentPosition,
    adjustedQty,
    proposedPosition,
    totalPortfolioValue,
    proposedPositionValue,
    proposedConcentration,
    maxPortfolioConcentration,
    positionsCount: Object.keys(positions).length,
  });

  if (proposedConcentration > maxPortfolioConcentration) {
    return {
      approved: false,
      reason: `Proposed concentration ${proposedConcentration.toFixed(2)} ` +
        `exceeds max ${maxPortfolioConcentration}`,
      metrics,
    };
  }

  // --- Advanced Risk Controls ---

  // 1. Sector Limits
  if (config?.enableSectorLimits && config?.maxSectorExposure) {
    const symbolInfo = await getSymbolInfo(symbol);
    if (symbolInfo?.sector) {
      // Note: Full sector exposure check requires fetching sectors for all
      // positions, which is expensive. For now, we check if this single
      // position exceeds the sector limit.
      const sectorExposure = proposedConcentration * 100;
      metrics.sector = symbolInfo.sector;
      metrics.sectorExposure = sectorExposure;
      metrics.maxSectorExposure = config.maxSectorExposure;

      if (sectorExposure > config.maxSectorExposure) {
        return {
          approved: false,
          reason: `Sector exposure ${sectorExposure.toFixed(2)}% for ` +
            `${symbolInfo.sector} exceeds max ${config.maxSectorExposure}%`,
          metrics,
        };
      }
      logger.info(`RiskGuard: Sector check passed for ${symbol} ` +
        `(${symbolInfo.sector})`);
    }
  }

  // 2. Correlation Checks
  if (config?.enableCorrelationChecks && config?.maxCorrelation &&
    marketData?.closes && marketData?.marketIndexCloses) {
    const correlation = calculateCorrelation(marketData.closes,
      marketData.marketIndexCloses);
    metrics.correlation = correlation;
    metrics.maxCorrelation = config.maxCorrelation;

    logger.info(`RiskGuard: Correlation with market: ${correlation}`);
    if (Math.abs(correlation) > config.maxCorrelation) {
      return {
        approved: false,
        reason: `Correlation with market ${correlation.toFixed(2)} ` +
          `exceeds max ${config.maxCorrelation}`,
        metrics,
      };
    }
  }

  // 3. Volatility Filters
  if (config?.enableVolatilityFilters && marketData?.closes) {
    const volatility = calculateVolatility(marketData.closes);
    metrics.volatility = volatility;
    metrics.minVolatility = config.minVolatility;
    metrics.maxVolatility = config.maxVolatility;

    logger.info(`RiskGuard: Volatility: ${volatility}`);
    if (config.minVolatility && volatility < config.minVolatility) {
      return {
        approved: false,
        reason: `Volatility ${volatility.toFixed(2)} is below min ` +
          `${config.minVolatility}`,
        metrics,
      };
    }
    if (config.maxVolatility && volatility > config.maxVolatility) {
      return {
        approved: false,
        reason: `Volatility ${volatility.toFixed(2)} exceeds max ` +
          `${config.maxVolatility}`,
        metrics,
      };
    }
  }

  // 4. Drawdown Protection
  if (config?.enableDrawdownProtection && config?.maxDrawdown) {
    // Check if highWaterMark is available in portfolioState
    if (portfolioState.highWaterMark && portfolioState.highWaterMark > 0) {
      const highWaterMark = Number(portfolioState.highWaterMark);
      const drawdown = (highWaterMark - totalPortfolioValue) /
        highWaterMark * 100;
      metrics.drawdown = drawdown;
      metrics.maxDrawdown = config.maxDrawdown;
      metrics.highWaterMark = highWaterMark;

      if (drawdown > config.maxDrawdown) {
        return {
          approved: false,
          reason: `Portfolio drawdown ${drawdown.toFixed(2)}% exceeds max ` +
            `${config.maxDrawdown}%`,
          metrics,
        };
      }
    }
  }

  // Passed basic risk checks
  return { approved: true, metrics };
}

/**
 * Cloud Function to assess a trade proposal via HTTP trigger.
 * @param {object} request - The request object containing proposal,
 * portfolioState, and config.
 * @returns {Promise<object>} The risk assessment result.
 */
export const riskguardTask = onCall(async (request) => {
  logger.info("RiskGuard task called via onCall", { data: request.data });
  const proposal = request.data.proposal || {};
  const portfolioState = request.data.portfolioState || {};
  const config = request.data.config || {};
  const result = await assessTrade(proposal, portfolioState, config);
  return result;
});

/**
 * Cloud Function to calculate dynamic position size.
 * @param {object} request - The request object containing symbol,
 * portfolioState, and config.
 * @returns {Promise<object>} The calculation result.
 */
export const calculatePositionSize = onCall(async (request) => {
  logger.info("Calculate Position Size called", { data: request.data });
  const symbol = request.data.symbol;
  const portfolioState = request.data.portfolioState || {};
  const config = request.data.config || {};

  if (!symbol) {
    return { status: "error", message: "Symbol is required" };
  }

  // 1. Fetch Market Data for ATR
  // Use 1d interval, 14 period (default)
  const marketData = await getMarketData(symbol, 10, 30, "1d", "3mo");
  const highs = marketData.highs;
  const lows = marketData.lows;
  const closes = marketData.closes;

  if (!closes || closes.length < 15) {
    return {
      status: "error",
      message: "Insufficient price data for ATR calculation",
    };
  }

  // 2. Calculate ATR
  const atr = computeATR(highs, lows, closes, 14);
  if (!atr) {
    return { status: "error", message: "Failed to calculate ATR" };
  }

  // 3. Calculate Portfolio Value
  const accountValue = calculatePortfolioValue(portfolioState);

  // 4. Calculate Dynamic Size
  const riskPerTrade = config.riskPerTrade || 0.01;
  const atrMultiplier = config.atrMultiplier || 2;

  let quantity = calculateDynamicPositionSize(
    accountValue,
    riskPerTrade,
    atr,
    atrMultiplier
  );

  // 5. Apply Caps
  let cappedBy = null;
  const currentPosition = getCurrentPosition(portfolioState, symbol);
  const maxPositionSize = config.maxPositionSize || 100;
  const availableSpace = Math.max(0, maxPositionSize - currentPosition);

  if (quantity > availableSpace) {
    quantity = availableSpace;
    cappedBy = "maxPositionSize";
  }

  const maxPortfolioConcentration = config.maxPortfolioConcentration || 0.5;
  const lastPrice = closes[closes.length - 1];
  if (lastPrice > 0) {
    const maxValue = accountValue * maxPortfolioConcentration;
    const maxTotalQty = Math.floor(maxValue / lastPrice);
    const availableQtyByConc = Math.max(0, maxTotalQty - currentPosition);

    if (quantity > availableQtyByConc) {
      quantity = availableQtyByConc;
      cappedBy = "maxPortfolioConcentration";
    }
  }

  return {
    status: "success",
    quantity,
    details: {
      atr,
      accountValue,
      riskPerTrade,
      atrMultiplier,
      cappedBy,
      lastPrice,
    },
  };
});
