import { onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

/**
 * Assesses a proposed trade against predefined risk parameters.
 * @param {object} proposal - The proposed trade details
 * (symbol, quantity, price).
 * @param {object} portfolioState - The current state of
 * the user's portfolio.
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

  const currentPosition = (portfolioState && portfolioState[symbol]) ?
    Number(portfolioState[symbol]) : 0;
  const cash = portfolioState?.cash ?? 0;

  // Check max position size
  if ((currentPosition + qty) > maxPositionSize) {
    return {
      approved: false,
      reason: `Max position size exceeded: 
      ${(currentPosition + qty)} > ${maxPositionSize}`,
    };
  }

  // Compute portfolio total value (approx)
  const currentPositionValue = currentPosition * price;
  const proposedPositionValue = (currentPosition + qty) * price;
  const totalPortfolioValue = cash + currentPositionValue;
  const proposedConcentration = totalPortfolioValue > 0 ?
    (proposedPositionValue / totalPortfolioValue) : 1.0;

  if (proposedConcentration > maxPortfolioConcentration) {
    return {
      approved: false,
      reason: `Proposed concentration ${proposedConcentration.toFixed(2)} 
      exceeds max ${maxPortfolioConcentration}`,
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
