import { describe, it, expect } from "@jest/globals";
import {
  evaluateStockPendingOrders,
  effectiveStopPrice,
} from "../src/paper-orders-engine";
import { isMarketOpen } from "../src/paper-trading-utils";

const AAPL_URL = "https://api.robinhood.com/instruments/AAPL/";

const instrumentJson = (symbol = "AAPL") => ({
  symbol,
  url: `https://api.robinhood.com/instruments/${symbol}/`,
});

const order = (fields: Record<string, unknown>) => ({
  id: `paper_${Math.random()}`,
  assetType: "stock",
  symbol: "AAPL",
  timeInForce: "gtc",
  createdAt: new Date().toISOString(),
  triggered: false,
  instrumentJson: instrumentJson(),
  ...fields,
});

const account = (fields: Record<string, unknown>) => ({
  cashBalance: 100000,
  slippage: 0,
  commission: 0,
  positions: [],
  optionPositions: [],
  pendingOrders: [],
  history: [],
  ...fields,
});

const longPosition = (qty: number, avg: number, symbol = "AAPL") => ({
  instrument: `https://api.robinhood.com/instruments/${symbol}/`,
  quantity: qty,
  average_buy_price: avg,
  instrumentObj: instrumentJson(symbol),
});

describe("isMarketOpen", () => {
  it("is open on a weekday during regular hours (ET)", () => {
    // 2026-07-15 is a Wednesday; 14:30 UTC = 10:30 ET (EDT).
    expect(isMarketOpen(new Date("2026-07-15T14:30:00Z"))).toBe(true);
  });

  it("is closed before the open, after the close, and on weekends", () => {
    // 9:00 ET, 16:30 ET, and Saturday respectively.
    expect(isMarketOpen(new Date("2026-07-15T13:00:00Z"))).toBe(false);
    expect(isMarketOpen(new Date("2026-07-15T20:30:00Z"))).toBe(false);
    expect(isMarketOpen(new Date("2026-07-18T15:00:00Z"))).toBe(false);
  });
});

describe("evaluateStockPendingOrders", () => {
  it("does nothing without prices or matching orders", () => {
    const data = account({
      pendingOrders: [
        order({
          side: "buy", orderType: "limit", limitPrice: 140, quantity: 10,
        }),
      ],
    });
    const result = evaluateStockPendingOrders(data, {});
    expect(result.changed).toBe(false);
    expect(result.fills).toBe(0);
  });

  it("fills a limit buy when the price crosses the limit", () => {
    const data = account({
      pendingOrders: [
        order({
          side: "buy", orderType: "limit", limitPrice: 140, quantity: 10,
        }),
      ],
    });

    // Above the limit: rests.
    expect(evaluateStockPendingOrders(data, { AAPL: 145 }).changed).toBe(false);

    // Crosses: fills at the observed price.
    const result = evaluateStockPendingOrders(data, { AAPL: 139 });
    expect(result.fills).toBe(1);
    expect(result.data.pendingOrders).toHaveLength(0);
    expect(result.data.cashBalance).toBe(100000 - 1390);
    const pos = result.data.positions[0];
    expect(pos.quantity).toBe(10);
    expect(pos.average_buy_price).toBe(139);
    expect(pos.instrument).toBe(AAPL_URL);
    expect(result.data.history[0].state).toBe("filled");
    expect(result.data.history[0].side).toBe("buy");
  });

  it("applies slippage and commission on fills", () => {
    const data = account({
      slippage: 0.5,
      commission: 1,
      pendingOrders: [
        order({
          side: "buy", orderType: "limit", limitPrice: 140, quantity: 10,
        }),
      ],
    });
    const result = evaluateStockPendingOrders(data, { AAPL: 139 });
    // Fills at 139.50 x 10 + $1 commission.
    expect(result.data.cashBalance).toBe(100000 - 1396);
    expect(result.data.positions[0].average_buy_price).toBe(139.5);
  });

  it("fills a stop-loss sell and realizes P&L", () => {
    const data = account({
      positions: [longPosition(10, 150)],
      pendingOrders: [
        order({
          side: "sell", orderType: "stop", stopPrice: 140, quantity: 10,
        }),
      ],
    });

    expect(evaluateStockPendingOrders(data, { AAPL: 145 }).changed).toBe(false);

    const result = evaluateStockPendingOrders(data, { AAPL: 138 });
    expect(result.fills).toBe(1);
    expect(result.data.positions).toHaveLength(0);
    expect(result.data.cashBalance).toBe(100000 + 1380);
    expect(result.data.history[0].profitLoss).toBe(1380 - 1500);
  });

  it("arms a stop-limit on the stop and fills on the limit leg", () => {
    const data = account({
      positions: [longPosition(10, 150)],
      pendingOrders: [
        order({
          side: "sell",
          orderType: "stop_limit",
          stopPrice: 140,
          limitPrice: 141,
          quantity: 10,
        }),
      ],
    });

    // Breach the stop but stay below the limit: armed, not filled.
    const armed = evaluateStockPendingOrders(data, { AAPL: 140 });
    expect(armed.changed).toBe(true);
    expect(armed.fills).toBe(0);
    expect(armed.data.pendingOrders[0].triggered).toBe(true);

    // Recover past the limit: fills.
    const filled = evaluateStockPendingOrders(armed.data as never, {
      AAPL: 141.5,
    });
    expect(filled.fills).toBe(1);
    expect(filled.data.positions).toHaveLength(0);
  });

  it("ratchets a trailing stop watermark and fills on the retrace", () => {
    const data = account({
      positions: [longPosition(10, 150)],
      pendingOrders: [
        order({
          side: "sell",
          orderType: "trailing_stop",
          trailType: "amount",
          trailValue: 5,
          watermark: 150,
          quantity: 10,
        }),
      ],
    });

    // Run-up moves the watermark (persisted change, no fill).
    const up = evaluateStockPendingOrders(data, { AAPL: 160 });
    expect(up.changed).toBe(true);
    expect(up.fills).toBe(0);
    expect(up.data.pendingOrders[0].watermark).toBe(160);
    expect(effectiveStopPrice(up.data.pendingOrders[0])).toBe(155);

    // Retrace through the trail: fills at market.
    const filled = evaluateStockPendingOrders(up.data as never, {
      AAPL: 154.5,
    });
    expect(filled.fills).toBe(1);
    expect(filled.data.cashBalance).toBe(100000 + 1545);
  });

  it("expires GFD orders after their Eastern trading day", () => {
    const yesterday = new Date(Date.now() - 24 * 3600 * 1000).toISOString();
    const data = account({
      pendingOrders: [
        order({
          side: "buy",
          orderType: "limit",
          limitPrice: 140,
          quantity: 10,
          timeInForce: "gfd",
          createdAt: yesterday,
        }),
      ],
    });
    const result = evaluateStockPendingOrders(data, { AAPL: 139 });
    expect(result.fills).toBe(0);
    expect(result.data.pendingOrders).toHaveLength(0);
    expect(result.data.history[0].state).toBe("cancelled");
  });

  it("rejects an unfundable trigger instead of retrying", () => {
    const data = account({
      cashBalance: 500,
      pendingOrders: [
        order({
          side: "buy", orderType: "limit", limitPrice: 140, quantity: 10,
        }),
      ],
    });
    const result = evaluateStockPendingOrders(data, { AAPL: 139 });
    expect(result.fills).toBe(0);
    expect(result.data.pendingOrders).toHaveLength(0);
    expect(result.data.history[0].state).toBe("rejected");
    expect(result.data.cashBalance).toBe(500);
  });

  it("opens a short via a triggered sell stop with collateral check", () => {
    const data = account({
      pendingOrders: [
        order({
          side: "sell", orderType: "stop", stopPrice: 140, quantity: 10,
        }),
      ],
    });
    const result = evaluateStockPendingOrders(data, { AAPL: 139 });
    expect(result.fills).toBe(1);
    expect(result.data.positions[0].quantity).toBe(-10);
    expect(result.data.cashBalance).toBe(100000 + 1390);
  });

  it("blocks selling shares pledged to covered calls", () => {
    const data = account({
      positions: [longPosition(100, 150)],
      optionPositions: [
        {
          direction: "credit",
          symbol: "AAPL",
          quantity: 1,
          legs: [{ option_type: "call", strike_price: 160 }],
        },
      ],
      pendingOrders: [
        order({
          side: "sell", orderType: "limit", limitPrice: 155, quantity: 100,
        }),
      ],
    });
    const result = evaluateStockPendingOrders(data, { AAPL: 156 });
    expect(result.fills).toBe(0);
    expect(result.data.history[0].state).toBe("rejected");
    expect(result.data.positions[0].quantity).toBe(100);
  });

  it("fills queued market orders at the observed price", () => {
    const data = account({
      pendingOrders: [
        order({ side: "buy", orderType: "market", quantity: 10 }),
      ],
    });
    const result = evaluateStockPendingOrders(data, { AAPL: 152 });
    expect(result.fills).toBe(1);
    expect(result.data.positions[0].quantity).toBe(10);
    expect(result.data.positions[0].average_buy_price).toBe(152);
    expect(result.data.cashBalance).toBe(100000 - 1520);
  });

  it("leaves option orders untouched", () => {
    const data = account({
      pendingOrders: [
        order({
          assetType: "option",
          side: "buy",
          orderType: "limit",
          limitPrice: 5,
          quantity: 1,
        }),
      ],
    });
    const result = evaluateStockPendingOrders(data, { AAPL: 1 });
    expect(result.changed).toBe(false);
    expect(result.data.pendingOrders).toHaveLength(1);
  });
});
