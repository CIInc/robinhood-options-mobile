/**
 * Formats an Agentic proposal rejection without contradictory status text.
 * @param {string} agenticReason Reason returned by the Agentic decision.
 * @param {boolean} rejectedByAgent Whether the Agentic decision was HOLD.
 * @param {string | undefined} riskGuardReason RiskGuard rejection reason.
 * @return {string} User-facing rejection message.
 */
export function formatAgenticProposalRejection(
  agenticReason: string,
  rejectedByAgent: boolean,
  riskGuardReason?: string
): string {
  const reason = rejectedByAgent ? agenticReason :
    riskGuardReason || "Trade rejected by RiskGuard";
  const normalizedReason = reason.trim().replace(/[.!?]+$/, "");
  const source = rejectedByAgent ? "Agentic" : "RiskGuard";
  return `${source}: ${normalizedReason}.`;
}
