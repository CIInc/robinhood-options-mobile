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
