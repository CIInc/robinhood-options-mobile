/**
 * Server-side trigger evaluation for paper trading resting STOCK orders.
 *
 * A pure TypeScript port of the client engine's stock-order semantics
 * (PaperTradingStore in lib/model/paper_trading_store.dart), so working
 * limit/stop/stop-limit/trailing orders can fill while the app is closed.
 * Option orders are left to the client, which has option market data.
 *
 * Kept free of firebase imports so it can be unit tested directly.
 */

import { tradingDateString } from "./paper-trading-utils";

/* eslint-disable @typescript-eslint/no-explicit-any */

const SHORT_INITIAL_MULTIPLIER = 1.5;
const SHORT_MAINTENANCE_MULTIPLIER = 1.3;
const EPSILON = 0.000001;

/** Result of one evaluation pass over an account document. */
export interface EvaluationResult {
  /** Whether any field changed and the document should be written back. */
  changed: boolean;
  /** Number of orders filled. */
  fills: number;
  /** Updated document fields (only meaningful when changed). */
  data: {
    cashBalance: number;
    positions: any[];
    pendingOrders: any[];
    history: any[];
  };
  /** Entries added this pass, for the durable paper_orders subcollection. */
  newHistory: any[];
}

const num = (v: any): number => Number(v) || 0;

/**
 * Builds a history entry in the client's unified format.
 * @param {Record<string, any>} fields Entry field overrides.
 * @return {Record<string, any>} The entry.
 */
function historyEntry(fields: Record<string, any>): Record<string, any> {
  const nowIso = new Date().toISOString();
  return {
    id: `paper_${Date.now()}`,
    timestamp: nowIso,
    created_at: nowIso,
    updated_at: nowIso,
    type: "STOCK",
    state: "filled",
    paperMode: true,
    ...fields,
  };
}

/**
 * Current trigger price of a trailing stop derived from its watermark.
 * @param {any} order The pending order.
 * @return {number | null} Effective stop, or the static stop price.
 */
export function effectiveStopPrice(order: any): number | null {
  if (
    order.orderType !== "trailing_stop" ||
    order.watermark == null ||
    order.trailValue == null
  ) {
    return order.stopPrice ?? null;
  }
  const base = num(order.watermark);
  const trail = num(order.trailValue);
  const isBuy = order.side === "buy";
  if (order.trailType === "percentage") {
    return isBuy ? base * (1 + trail / 100) : base * (1 - trail / 100);
  }
  return isBuy ? base + trail : base - trail;
}

const reservePrice = (order: any): number =>
  order.limitPrice ?? effectiveStopPrice(order) ?? 0;

const contractMultiplier = (order: any): number =>
  order.assetType === "option" ? 100 : 1;

/**
 * Applies a fill to the position book (port of _updateStockPosition).
 * @param {any[]} positions Position array (mutated).
 * @param {any} instrumentJson Instrument JSON from the pending order.
 * @param {number} quantity Unsigned fill quantity.
 * @param {number} price Execution price.
 * @param {number} sign +1 buys, -1 sells.
 */
function updateStockPosition(
  positions: any[],
  instrumentJson: any,
  quantity: number,
  price: number,
  sign: number,
): void {
  const url = instrumentJson?.url ?? "";
  const index = positions.findIndex((p) => p.instrument === url);

  if (index !== -1) {
    const current = positions[index];
    const currentQty = num(current.quantity);
    const newQty = currentQty + quantity * sign;

    if (Math.abs(newQty) <= EPSILON) {
      positions.splice(index, 1);
      return;
    }
    let newAvg = num(current.average_buy_price);
    const extendsLong = sign > 0 && currentQty >= 0;
    const extendsShort = sign < 0 && currentQty <= 0;
    if (extendsLong || extendsShort) {
      newAvg =
        (Math.abs(currentQty) * num(current.average_buy_price) +
          quantity * price) /
        Math.abs(newQty);
    }
    positions[index] = {
      ...current,
      quantity: newQty,
      average_buy_price: newAvg,
      updated_at: new Date().toISOString(),
    };
    return;
  }

  const signedQty = quantity * sign;
  positions.push({
    url: `paper_pos_${Date.now()}`,
    instrument: url,
    account: "paper_account",
    account_number: "PAPER123",
    average_buy_price: price,
    pending_average_buy_price: 0,
    quantity: signedQty,
    intraday_average_buy_price: price,
    intraday_quantity: signedQty,
    avg_cost_affected: true,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
    instrumentObj: instrumentJson,
  });
}

/**
 * Shares of [symbol] pledged as covered-call collateral.
 * @param {any[]} optionPositions Option positions (read-only).
 * @param {string} symbol Underlying symbol.
 * @return {number} Pledged share count.
 */
function coveredCallShares(optionPositions: any[], symbol: string): number {
  let total = 0;
  for (const pos of optionPositions) {
    if (pos.direction !== "credit") continue;
    const leg = Array.isArray(pos.legs) && pos.legs.length > 0 ?
      pos.legs[0] :
      null;
    const type = String(
      leg?.option_type ?? pos.optionInstrument?.type ?? "",
    ).toLowerCase();
    if (type !== "call" || pos.symbol !== symbol) continue;
    total += num(pos.quantity) * 100;
  }
  return total;
}

/**
 * Cash securing written puts: strike x 100 per contract.
 * @param {any[]} optionPositions Option positions (read-only).
 * @return {number} Total put collateral.
 */
function shortPutCollateral(optionPositions: any[]): number {
  let total = 0;
  for (const pos of optionPositions) {
    if (pos.direction !== "credit") continue;
    const leg = Array.isArray(pos.legs) && pos.legs.length > 0 ?
      pos.legs[0] :
      null;
    const type = String(
      leg?.option_type ?? pos.optionInstrument?.type ?? "",
    ).toLowerCase();
    if (type !== "put") continue;
    const strike = num(
      leg?.strike_price ?? pos.optionInstrument?.strike_price);
    total += num(pos.quantity) * strike * 100;
  }
  return total;
}

/**
 * Evaluates an account's resting STOCK orders against fresh prices,
 * mirroring the client engine: GFD expiry (Eastern trading day), limit /
 * stop / stop-limit / trailing-stop triggers with watermark ratchet, and
 * fills through the same position-book math (slippage, commission,
 * averaging, shorts with collateral checks). Orders that trigger but fail
 * validation are rejected, not retried. Option/other orders are untouched.
 *
 * @param {Record<string, any>} data The paper_account/main document data.
 * @param {Record<string, number>} stockPrices Current price per symbol.
 * @param {Date} now Evaluation time (injectable for tests).
 * @return {EvaluationResult} Updated fields and change summary.
 */
export function evaluateStockPendingOrders(
  data: Record<string, any>,
  stockPrices: Record<string, number>,
  now: Date = new Date(),
): EvaluationResult {
  const positions: any[] = (data.positions ?? []).map((p: any) => ({ ...p }));
  const optionPositions: any[] = data.optionPositions ?? [];
  const pendingOrders: any[] = (data.pendingOrders ?? []).map((o: any) => ({
    ...o,
  }));
  const history: any[] = [...(data.history ?? [])];
  let cash = num(data.cashBalance);
  const slippage = num(data.slippage);
  const commission = num(data.commission);

  let changed = false;
  let fills = 0;

  const newHistory: any[] = [];
  const addHistory = (fields: Record<string, any>) => {
    const entry = historyEntry(fields);
    history.unshift(entry);
    newHistory.push(entry);
    if (history.length > 100) history.length = 100;
  };

  const reservedCash = (): number =>
    pendingOrders
      .filter((o) => o.side === "buy")
      .reduce(
        (t, o) =>
          t +
          num(o.quantity) * reservePrice(o) * contractMultiplier(o) +
          commission,
        0,
      );

  const maintenance = (): number =>
    positions
      .filter((p) => num(p.quantity) < 0)
      .reduce((t, p) => {
        const symbol = p.instrumentObj?.symbol;
        const price =
          (symbol ? stockPrices[symbol] : undefined) ??
          num(p.average_buy_price);
        return (
          t + Math.abs(num(p.quantity)) * price * SHORT_MAINTENANCE_MULTIPLIER
        );
      }, 0);

  const available = (): number =>
    cash - reservedCash() - maintenance() - shortPutCollateral(optionPositions);

  /**
   * Fills one order; throws Error(reason) when validation fails.
   * @param {any} order The triggered pending order.
   * @param {number} price Observed market price.
   */
  const fillOrder = (order: any, price: number) => {
    const qty = num(order.quantity);
    const instrumentJson = order.instrumentJson ?? {};
    const url = instrumentJson.url ?? "";
    const symbol = order.symbol ?? instrumentJson.symbol ?? "";
    const index = positions.findIndex((p) => p.instrument === url);
    const heldQty = index >= 0 ? num(positions[index].quantity) : 0;
    const label = String(order.orderType ?? "").replace(/_/g, " ");

    const base = {
      symbol,
      quantity: qty,
      order_type: order.orderType,
      instrument: url,
      detail: `Type: ${label} (server)`,
    };

    if (order.side === "buy") {
      const execPrice = price + slippage;
      const amount = qty * execPrice + commission;
      if (cash < amount) throw new Error("Insufficient buying power.");
      if (heldQty < 0) {
        if (qty > Math.abs(heldQty) + EPSILON) {
          throw new Error(
            "Buy exceeds the short position; cover it before going long.",
          );
        }
        const avgShort = num(positions[index].average_buy_price);
        const profitLoss = (avgShort - execPrice) * qty - commission;
        cash -= amount;
        updateStockPosition(positions, instrumentJson, qty, execPrice, 1);
        addHistory({
          ...base,
          action: "BUY",
          side: "buy",
          price: execPrice,
          profitLoss,
          detail: `Buy to cover | ${label} (server)`,
        });
      } else {
        cash -= amount;
        updateStockPosition(positions, instrumentJson, qty, execPrice, 1);
        addHistory({ ...base, action: "BUY", side: "buy", price: execPrice });
      }
      return;
    }

    // Sell side.
    const execPrice = price - slippage;
    const amount = qty * execPrice - commission;
    if (heldQty > 0) {
      if (heldQty < qty) {
        throw new Error(
          "Sell exceeds the long position; close it before going short.",
        );
      }
      const pledged = coveredCallShares(optionPositions, symbol);
      if (heldQty - pledged < qty) {
        throw new Error(
          "Shares are pledged as covered-call collateral; " +
          "close the call first.",
        );
      }
      const costBasis = num(positions[index].average_buy_price) * qty;
      const profitLoss = amount - costBasis;
      cash += amount;
      updateStockPosition(positions, instrumentJson, qty, execPrice, -1);
      addHistory({
        ...base,
        action: "SELL",
        side: "sell",
        price: execPrice,
        profitLoss,
      });
    } else {
      const addedCollateral = qty * execPrice * SHORT_INITIAL_MULTIPLIER;
      if (available() + amount < addedCollateral) {
        throw new Error(
          "Insufficient buying power to open a short " +
          "(requires 150% collateral).",
        );
      }
      cash += amount;
      updateStockPosition(positions, instrumentJson, qty, execPrice, -1);
      addHistory({
        ...base,
        action: "SELL",
        side: "sell",
        price: execPrice,
        detail: `Sell short | ${label} (server)`,
      });
    }
  };

  for (const order of [...pendingOrders]) {
    if (order.assetType !== "stock") continue;
    const removeOrder = () => {
      const i = pendingOrders.findIndex((o) => o.id === order.id);
      if (i >= 0) pendingOrders.splice(i, 1);
    };

    // Good-for-day orders expire after their Eastern trading day.
    const createdAt = new Date(String(order.createdAt ?? ""));
    if (
      order.timeInForce === "gfd" &&
      !isNaN(createdAt.getTime()) &&
      tradingDateString(createdAt) !== tradingDateString(now)
    ) {
      removeOrder();
      addHistory({
        symbol: order.symbol,
        quantity: num(order.quantity),
        price: reservePrice(order),
        action: String(order.side ?? "").toUpperCase(),
        side: order.side,
        state: "cancelled",
        order_type: order.orderType,
        detail: "GFD order expired unfilled (server)",
      });
      changed = true;
      continue;
    }

    const price = stockPrices[order.symbol];
    if (price == null || price <= 0) continue;
    const isBuy = order.side === "buy";
    let shouldFill = false;

    switch (order.orderType) {
    case "market": {
      // Queued while the market was closed; the cron only runs during
      // market hours, so fill at the first observed price.
      shouldFill = true;
      break;
    }
    case "limit": {
      const limit = num(order.limitPrice);
      shouldFill = isBuy ? price <= limit : price >= limit;
      break;
    }
    case "stop": {
      const stop = num(order.stopPrice);
      shouldFill = isBuy ? price >= stop : price <= stop;
      break;
    }
    case "stop_limit": {
      const stop = num(order.stopPrice);
      if (!order.triggered && (isBuy ? price >= stop : price <= stop)) {
        order.triggered = true;
        const i = pendingOrders.findIndex((o) => o.id === order.id);
        if (i >= 0) pendingOrders[i] = order;
        changed = true;
      }
      if (order.triggered) {
        const limit = num(order.limitPrice);
        shouldFill = isBuy ? price <= limit : price >= limit;
      }
      break;
    }
    case "trailing_stop": {
      const current = order.watermark == null ? null : num(order.watermark);
      let watermark = current;
      if (isBuy) {
        if (watermark == null || price < watermark) watermark = price;
      } else {
        if (watermark == null || price > watermark) watermark = price;
      }
      if (watermark !== current) {
        order.watermark = watermark;
        const i = pendingOrders.findIndex((o) => o.id === order.id);
        if (i >= 0) pendingOrders[i] = order;
        changed = true;
      }
      const stop = effectiveStopPrice(order);
      if (stop != null) {
        shouldFill = isBuy ? price >= stop : price <= stop;
      }
      break;
    }
    default:
      continue;
    }

    if (!shouldFill) continue;

    // Remove before filling so the order's own reservation doesn't count.
    removeOrder();
    try {
      fillOrder(order, price);
      fills += 1;
    } catch (e) {
      addHistory({
        symbol: order.symbol,
        quantity: num(order.quantity),
        price: reservePrice(order),
        action: String(order.side ?? "").toUpperCase(),
        side: order.side,
        state: "rejected",
        order_type: order.orderType,
        detail: `Order rejected on trigger (server): ${
          e instanceof Error ? e.message : e
        }`,
      });
    }
    changed = true;
  }

  return {
    changed,
    fills,
    data: { cashBalance: cash, positions, pendingOrders, history },
    newHistory,
  };
}
