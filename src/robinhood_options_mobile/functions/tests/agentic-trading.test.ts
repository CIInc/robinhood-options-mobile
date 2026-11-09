import { describe, expect, test, jest } from "@jest/globals";
import { HttpsError } from "firebase-functions/v2/https";

jest.mock("firebase-admin/firestore", () => ({
  getFirestore: () => ({
    doc: jest.fn(() => ({
      get: jest.fn(async () => ({ exists: false })),
      set: jest.fn(async () => ({})),
      update: jest.fn(async () => ({})),
    })),
  }),
  FieldValue: {
    serverTimestamp: () => "TIMESTAMP",
  },
}));

jest.mock("../src/alpha-agent", () => ({
  handleAlphaTask: jest.fn(async () => ({ status: "success" })),
}));

jest.mock("../src/market-data", () => ({
  getMarketData: jest.fn(async () => ({ closes: [100, 101, 102] })),
}));

import {
  logAgenticTradingCycle,
  initiateTradeProposal,
  seedAgenticTrading,
} from "../src/agentic-trading";

describe("agentic-trading callable functions auth checks", () => {
  test("initiateTradeProposal rejects unauthenticated request", async () => {
    const unauthenticatedRequest = {
      auth: null,
      data: { symbol: "AAPL" },
    };

    const callFn = () =>
      (initiateTradeProposal as any).run(unauthenticatedRequest);

    await expect(callFn()).rejects.toThrow(HttpsError);
    await expect(callFn()).rejects.toMatchObject({
      code: "unauthenticated",
    });
  });

  test("seedAgenticTrading rejects unauthenticated request", async () => {
    const unauthenticatedRequest = {
      auth: null,
      data: { symbols: ["AAPL"] },
    };

    const callFn = () =>
      (seedAgenticTrading as any).run(unauthenticatedRequest);

    await expect(callFn()).rejects.toThrow(HttpsError);
    await expect(callFn()).rejects.toMatchObject({
      code: "unauthenticated",
    });
  });

  test("initiateTradeProposal allows authenticated request", async () => {
    const authenticatedRequest = {
      auth: { uid: "user123", token: {} },
      data: { symbol: "SPY", interval: "1d" },
    };

    const response = await (initiateTradeProposal as any).run(
      authenticatedRequest
    );
    expect(response).toEqual({ status: "success" });
  });

  test("logAgenticTradingCycle rejects unauthenticated requests", async () => {
    await expect(
      (logAgenticTradingCycle as any).run({
        auth: null,
        data: {
          cycleId: "cycle_12345678",
          phase: "started",
          trigger: "background",
          reason: "cycle_started",
        },
      })
    ).rejects.toMatchObject({ code: "unauthenticated" });
  });

  test("logAgenticTradingCycle records a safe summary", async () => {
    const response = await (logAgenticTradingCycle as any).run({
      auth: { uid: "user123", token: {} },
      data: {
        cycleId: "cycle_12345678",
        phase: "blocked",
        trigger: "background",
        reason: "cycle_blocked",
        paperMode: true,
        tradingMode: "reasoning",
        quoteSource: "robinhood",
        signalsFetched: 0,
      },
    });

    expect(response).toEqual({ recorded: true });
  });

  test("logAgenticTradingCycle accepts signal fetch failures", async () => {
    const response = await (logAgenticTradingCycle as any).run({
      auth: { uid: "user123", token: {} },
      data: {
        cycleId: "cycle_12345678",
        phase: "failed",
        trigger: "foreground",
        reason: "signal_fetch_failed",
      },
    });

    expect(response).toEqual({ recorded: true });
  });

  test.each([
    "lease_held",
    "lease_claim_failed",
    "missing_user_document",
  ])("logAgenticTradingCycle accepts lease result %s", async (reason) => {
    const response = await (logAgenticTradingCycle as any).run({
      auth: { uid: "user123", token: {} },
      data: {
        cycleId: "cycle_12345678",
        phase: "blocked",
        trigger: "background",
        reason,
      },
    });

    expect(response).toEqual({ recorded: true });
  });

  test("logAgenticTradingCycle rejects invalid input", async () => {
    const callFn = () =>
      (logAgenticTradingCycle as any).run({
        auth: { uid: "user123", token: {} },
        data: {
          cycleId: "cycle_12345678",
          phase: "blocked",
          trigger: "background",
          reason: "some raw error with private data",
          signalsFetched: 10001,
        },
      });

    await expect(callFn()).rejects.toMatchObject({ code: "invalid-argument" });
  });

  test("seedAgenticTrading rejects non-admin user", async () => {
    const nonAdminRequest = {
      auth: { uid: "user123", token: { role: "user" } },
      data: { symbols: ["AAPL"] },
    };

    const callFn = () =>
      (seedAgenticTrading as any).run(nonAdminRequest);

    await expect(callFn()).rejects.toThrow(HttpsError);
    await expect(callFn()).rejects.toMatchObject({
      code: "permission-denied",
    });
  });

  test("seedAgenticTrading allows authenticated admin request", async () => {
    const adminRequest = {
      auth: { uid: "admin123", token: { role: "admin" } },
      data: { symbols: ["AAPL"] },
    };

    const response = await (seedAgenticTrading as any).run(
      adminRequest
    );
    expect(response).toMatchObject({
      status: "success",
      totalProcessed: 1,
    });
  });
});
