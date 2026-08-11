import { InstitutionalAccumulation } from "./whale-watch-models";

export type InstitutionalRankingMode = "accumulation" | "holdings";

export interface InstitutionalRanking {
  topSymbols: { symbol: string; score: number }[];
  currentHoldings: Record<string, number>;
  mode: InstitutionalRankingMode;
}

/**
 * Ranks symbols by newly reported institutional shares. Yahoo's ownership
 * module only returns current positions, so changes must be derived from the
 * previous snapshot rather than a nonexistent positionChange field.
 * @param {InstitutionalAccumulation[]} ownership Current holder positions.
 * @param {Record<string, number>} previousHoldings Prior totals by symbol.
 * @return {InstitutionalRanking} Ranked symbols and the next snapshot.
 */
export function rankInstitutionalActivity(
  ownership: InstitutionalAccumulation[],
  previousHoldings: Record<string, number> = {},
): InstitutionalRanking {
  const currentHoldings: Record<string, number> = {};
  for (const position of ownership) {
    const shares = Number(position.sharesHeld);
    if (!position.symbol || !Number.isFinite(shares) || shares <= 0) continue;
    currentHoldings[position.symbol] =
      (currentHoldings[position.symbol] ?? 0) + shares;
  }

  const changes = Object.entries(currentHoldings)
    .filter(([symbol]) => Object.hasOwn(previousHoldings, symbol))
    .map(([symbol, shares]) => ({
      symbol,
      score: shares - previousHoldings[symbol],
    }))
    .filter(({ score }) => score > 0)
    .sort((a, b) => b.score - a.score);

  const mode: InstitutionalRankingMode =
    changes.length > 0 ? "accumulation" : "holdings";
  const ranked = changes.length > 0 ? changes : Object.entries(currentHoldings)
    .map(([symbol, score]) => ({ symbol, score }))
    .sort((a, b) => b.score - a.score);

  return {
    topSymbols: ranked.slice(0, 10),
    currentHoldings,
    mode,
  };
}
