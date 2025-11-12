import { onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

/**
 * Assesses a proposed trade against predefined risk parameters.
 * @param {object} proposal - The proposed trade details
 * (symbol, quantity, price, action).
 * @param {object} portfolioState - The current state of
 * the user's portfolio. Expected format:
 *   { cash: number, SYMBOL: number | {quantity: number, price: number}, ... }
 * @param {object} config - Risk configuration parameters
 * (e.g., max position size).
 * @return {Promise<object>} The risk assessment result.
 */
export async function assessTrade(proposal: any,
  portfolioState: any, config: any) {
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
    (proposedPositionValue / totalPortfolioValue) : 1.0;

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

  // Passed basic risk checks
  return { approved: true, reason: "" };
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
