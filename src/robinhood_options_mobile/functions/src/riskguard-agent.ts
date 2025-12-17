import { onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import fetch from "node-fetch";

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

  // Handle SELL actions - quantity should be negative or we need to adjust
  const adjustedQty = action === "SELL" ? -Math.abs(qty) : Math.abs(qty);

  // Extract current position for the symbol being traded
  let currentPosition = 0;
  if (portfolioState && portfolioState[symbol]) {
    if (typeof portfolioState[symbol] === "object" &&
      portfolioState[symbol].quantity !== undefined) {
      currentPosition = Number(portfolioState[symbol].quantity);
    } else {
      currentPosition = Number(portfolioState[symbol]);
    }
  }

  const cash = portfolioState?.cash ?? 0;

  // Check max position size (absolute value after trade)
  const proposedPosition = currentPosition + adjustedQty;
  if (Math.abs(proposedPosition) > maxPositionSize) {
    return {
      approved: false,
      reason: `Max position size exceeded: 
      ${Math.abs(proposedPosition)} > ${maxPositionSize}`,
    };
  }

  // Calculate total portfolio value from ALL positions
  let totalPortfolioValue = cash;
  const positions: { [key: string]: { quantity: number, price: number } } = {};

  // Iterate through all positions in portfolioState
  for (const [posSymbol, posData] of Object.entries(portfolioState)) {
    if (posSymbol === "cash") continue;

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
      reason: "Proposed concentration " +
        `${proposedConcentration.toFixed(2)} exceeds max ` +
        `${maxPortfolioConcentration}`,
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
      if (sectorExposure > config.maxSectorExposure) {
        return {
          approved: false,
          reason: `Sector exposure ${sectorExposure.toFixed(2)}% ` +
            `for ${symbolInfo.sector} exceeds max ${config.maxSectorExposure}%`,
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
    logger.info(`RiskGuard: Correlation with market: ${correlation}`);
    if (Math.abs(correlation) > config.maxCorrelation) {
      return {
        approved: false,
        reason: `Correlation with market ${correlation.toFixed(2)} ` +
          `exceeds max ${config.maxCorrelation}`,
      };
    }
  }

  // 3. Volatility Filters
  if (config?.enableVolatilityFilters && marketData?.closes) {
    const volatility = calculateVolatility(marketData.closes);
    logger.info(`RiskGuard: Volatility: ${volatility}`);
    if (config.minVolatility && volatility < config.minVolatility) {
      return {
        approved: false,
        reason: `Volatility ${volatility.toFixed(2)} is below min ` +
          `${config.minVolatility}`,
      };
    }
    if (config.maxVolatility && volatility > config.maxVolatility) {
      return {
        approved: false,
        reason: `Volatility ${volatility.toFixed(2)} exceeds max ` +
          `${config.maxVolatility}`,
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
      if (drawdown > config.maxDrawdown) {
        return {
          approved: false,
          reason: `Portfolio drawdown ${drawdown.toFixed(2)}% ` +
            `exceeds max ${config.maxDrawdown}%`,
        };
      }
    }
  }

  // Passed basic risk checks
  return { approved: true };
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
