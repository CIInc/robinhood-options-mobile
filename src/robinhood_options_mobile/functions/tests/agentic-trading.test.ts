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

  test("seedAgenticTrading allows authenticated request", async () => {
    const authenticatedRequest = {
      auth: { uid: "user123", token: {} },
      data: { symbols: ["AAPL"] },
    };

    const response = await (seedAgenticTrading as any).run(
      authenticatedRequest
    );
    expect(response).toMatchObject({
      status: "success",
      totalProcessed: 1,
    });
  });
});
