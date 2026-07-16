/**
 * Pure valuation helpers for the paper trading equity cron.
 * Kept free of firebase imports so they can be unit tested directly.
 */

/* eslint-disable @typescript-eslint/no-explicit-any */

/**
 * Returns true when [date] falls on a weekday in the given IANA time zone.
 * Used to skip equity snapshots on non-trading days. (Exchange holidays are
 * not modeled; a flat point on a holiday is acceptable.)
 * @param {Date} date Moment to test.
 * @param {string} timeZone IANA zone the trading calendar runs in.
 * @return {boolean} Whether the date is a weekday in that zone.
 */
export function isTradingDay(
  date: Date,
  timeZone = "America/New_York",
): boolean {
  const weekday = new Intl.DateTimeFormat("en-US", {
    timeZone,
    weekday: "short",
  }).format(date);
  return weekday !== "Sat" && weekday !== "Sun";
}

/**
 * Values a paper account document, mirroring the client engine
 * (PaperTradingStore) rules:
 * - stocks: signed quantity (shorts are negative) x current price, falling
 *   back to the average entry price when no quote is available;
 * - options: 100x multiplier; written positions (direction "credit") are
 *   liabilities and subtract from equity;
 * - futures: open P&L = (lastPrice - avgPrice) x quantity x multiplier.
 * @param {Record<string, any>} data The paper_account/main document data.
 * @param {Record<string, number>} symbolPrices Current price per symbol.
 * @return {number} Total account equity (cash + positions value).
 */
export function computePaperAccountEquity(
  data: Record<string, any>,
  symbolPrices: Record<string, number>,
): number {
  const cashBalance = Number(data.cashBalance) || 0;
  let positionsValue = 0;

  if (Array.isArray(data.positions)) {
    for (const pos of data.positions) {
      const symbol = pos.instrumentObj?.symbol;
      const price =
        (symbol ? symbolPrices[symbol] : undefined) ||
        Number(pos.average_buy_price) ||
        0;
      positionsValue += (Number(pos.quantity) || 0) * price;
    }
  }

  if (Array.isArray(data.optionPositions)) {
    for (const pos of data.optionPositions) {
      const mktData =
        pos.optionInstrument?.optionMarketData ??
        pos.optionInstrument?.option_market_data;
      const price =
        Number(mktData?.adjustedMarkPrice ?? mktData?.adjusted_mark_price) ||
        Number(pos.average_open_price) ||
        0;
      const sign = pos.direction === "credit" ? -1 : 1;
      positionsValue += sign * (Number(pos.quantity) || 0) * price * 100;
    }
  }

  if (Array.isArray(data.futuresPositions)) {
    for (const pos of data.futuresPositions) {
      const lastPrice = Number(pos.lastPrice) || 0;
      const avgPrice = Number(pos.avgPrice) || 0;
      const quantity = Number(pos.quantity) || 0;
      const multiplier = Number(pos.multiplier) || 1;
      positionsValue += (lastPrice - avgPrice) * quantity * multiplier;
    }
  }

  return cashBalance + positionsValue;
}
