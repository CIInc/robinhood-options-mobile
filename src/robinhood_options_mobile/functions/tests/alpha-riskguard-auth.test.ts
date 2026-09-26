import { describe, expect, test, jest } from "@jest/globals";
import { HttpsError } from "firebase-functions/v2/https";

// Mock dependencies before importing functions
jest.mock("firebase-admin/messaging", () => ({
  getMessaging: () => ({
    sendEachForMulticast: jest.fn(async () => ({})),
  }),
}));

jest.mock("firebase-admin/firestore", () => {
  const mockSet = jest.fn(async () => ({}));
  const mockGet = jest.fn(async () => ({
    exists: false,
    data: () => ({}),
  }));
  const mockDoc = jest.fn().mockReturnValue({ set: mockSet, get: mockGet });
  const mockCollection = jest.fn().mockReturnValue({
    orderBy: jest.fn().mockReturnValue({
      limit: jest.fn().mockReturnValue({
        get: jest.fn(async () => ({ empty: true, docs: [] })),
      }),
    }),
    doc: mockDoc,
  });
  return {
    getFirestore: jest.fn().mockReturnValue({
      doc: mockDoc,
      collection: mockCollection,
    }),
  };
});

jest.mock("../src/market-data", () => ({
  getMarketData: jest.fn(async () => ({
    opens: [100, 101, 102],
    highs: [105, 106, 107],
    lows: [99, 100, 101],
    closes: [104, 105, 106],
    volumes: [1000, 1100, 1200],
    currentPrice: 106,
  })),
}));

import { alphabotTask } from "../src/alpha-agent";
import { riskguardTask, calculatePositionSize } from "../src/riskguard-agent";

describe("Alpha & RiskGuard callable authentication", () => {
  test("alphabotTask rejects unauthenticated call", async () => {
    const unauthenticatedRequest = {
      auth: null,
      data: {},
    };

    const callFn = () => (alphabotTask as any).run(unauthenticatedRequest);

    await expect(callFn()).rejects.toThrow(HttpsError);
    await expect(callFn()).rejects.toMatchObject({
      code: "unauthenticated",
    });
  });

  test("riskguardTask rejects unauthenticated call", async () => {
    const unauthenticatedRequest = {
      auth: null,
      data: {},
    };

    const callFn = () => (riskguardTask as any).run(unauthenticatedRequest);

    await expect(callFn()).rejects.toThrow(HttpsError);
    await expect(callFn()).rejects.toMatchObject({
      code: "unauthenticated",
    });
  });

  test("calculatePositionSize rejects unauthenticated call", async () => {
    const unauthenticatedRequest = {
      auth: null,
      data: { symbol: "AAPL" },
    };

    const callFn = () =>
      (calculatePositionSize as any).run(unauthenticatedRequest);

    await expect(callFn()).rejects.toThrow(HttpsError);
    await expect(callFn()).rejects.toMatchObject({
      code: "unauthenticated",
    });
  });
});
