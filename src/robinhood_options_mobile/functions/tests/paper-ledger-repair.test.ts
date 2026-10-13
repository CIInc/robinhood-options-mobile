import { describe, expect, test, jest } from "@jest/globals";

jest.mock("firebase-admin/firestore", () => ({
  getFirestore: () => ({}),
  FieldValue: { serverTimestamp: () => "ts" },
}));

import {
  assertRepairAllowed,
  planPaperRepair,
  planVoidPhantomFills,
  repairPaperLedger,
} from "../src/paper-ledger-repair";

describe("assertRepairAllowed", () => {
  const plan = (cashAfter: number) => ({
    cashBefore: 100,
    cashAfter,
    shorts: [],
    wouldGoNegative: cashAfter < 0,
  });

  test("allows a repair that keeps cash non-negative", () => {
    expect(() => assertRepairAllowed(plan(10), false)).not.toThrow();
  });

  test("refuses negative cash unless overridden", () => {
    expect(() => assertRepairAllowed(plan(-5), false)).toThrow(
      "negative cash"
    );
    expect(() => assertRepairAllowed(plan(-5), true)).not.toThrow();
  });
});

describe("planVoidPhantomFills", () => {
  const fill = (symbol: string, detail: string, type = "STOCK") =>
    ({ id: `${symbol}-${detail}`, type, symbol, detail });

  test("selects short-opening and covering fills for the symbols", () => {
    const orders = [
      fill("BXP", "Sell short | market"),
      fill("BXP", "Buy to cover"),
      fill("BXP", "Margin call: bought to cover at 10.00"),
      fill("BXP", "Type: market"),
      fill("AAPL", "Sell short"),
      fill("BXP", "Sell short", "OPTION"),
    ];
    expect(planVoidPhantomFills(orders, ["bxp"]).map((o) => o.detail)).toEqual([
      "Sell short | market",
      "Buy to cover",
      "Margin call: bought to cover at 10.00",
    ]);
  });
});

const position = (symbol: string, quantity: number, price: number) => ({
  quantity,
  average_buy_price: price,
  instrumentObj: { symbol },
});

describe("planPaperRepair", () => {
  test("removes short positions and their credited proceeds", () => {
    const plan = planPaperRepair({
      cashBalance: 1000,
      positions: [position("BXP", -3, 60), position("AAPL", 5, 100)],
    });
    expect(plan.shorts).toEqual([
      { symbol: "BXP", quantity: -3, averagePrice: 60, proceeds: 180 },
    ]);
    expect(plan.cashAfter).toBe(820);
    expect(plan.wouldGoNegative).toBe(false);
  });

  test("leaves long-only accounts untouched", () => {
    const plan = planPaperRepair({
      cashBalance: 500,
      positions: [position("AAPL", 5, 100)],
    });
    expect(plan.shorts).toHaveLength(0);
    expect(plan.cashAfter).toBe(500);
  });

  test("only repairs the requested symbols", () => {
    const plan = planPaperRepair({
      cashBalance: 1000,
      positions: [position("BXP", -3, 60), position("BG", -2, 100)],
    }, ["bg"]);
    expect(plan.shorts.map((s) => s.symbol)).toEqual(["BG"]);
    expect(plan.cashAfter).toBe(800);
  });

  test("flags a repair that would leave negative cash", () => {
    const plan = planPaperRepair({
      cashBalance: 100,
      positions: [position("BXP", -3, 60)],
    });
    expect(plan.wouldGoNegative).toBe(true);
  });
});

describe("repairPaperLedger access control", () => {
  const call = (request: any) =>
    (repairPaperLedger as any).run(request);

  test("rejects unauthenticated callers", async () => {
    await expect(call({ data: {} })).rejects.toMatchObject({
      code: "unauthenticated",
    });
  });

  test("rejects non-admin callers", async () => {
    await expect(call({
      auth: { uid: "u1", token: { role: "user" } },
      data: {},
    })).rejects.toMatchObject({ code: "permission-denied" });
  });

  test("requires explicit uids to apply a repair", async () => {
    await expect(call({
      auth: { uid: "a1", token: { role: "admin" } },
      data: { dryRun: false },
    })).rejects.toMatchObject({ code: "invalid-argument" });
  });
});
