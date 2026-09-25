import { HttpsError } from "firebase-functions/v2/https";

// Mock firebase-admin modules before importing functions
jest.mock("firebase-admin/app", () => ({
  getApp: jest.fn(),
  initializeApp: jest.fn(),
}));

jest.mock("firebase-admin/firestore", () => {
  const mockSet = jest.fn().mockResolvedValue({});
  const mockDoc = jest.fn().mockReturnValue({ set: mockSet });
  return {
    getFirestore: jest.fn().mockReturnValue({ doc: mockDoc }),
  };
});

jest.mock("../src/market-data", () => ({
  getMarketData: jest.fn().mockResolvedValue({
    opens: [100, 101, 102],
    highs: [105, 106, 107],
    lows: [99, 100, 101],
    closes: [104, 105, 106],
    volumes: [1000, 1100, 1200],
    currentPrice: 106,
  }),
}));

import { getFuturesSignals } from "../src/agentic-futures-trading";

describe("getFuturesSignals callable authentication", () => {
  it("should throw unauthenticated error if auth is missing", async () => {
    const unauthenticatedRequest = {
      data: { symbol: "ES=F", contractId: "ESM24" },
      auth: undefined,
    };

    await expect(
      (getFuturesSignals as any).run(unauthenticatedRequest)
    ).rejects.toThrow(
      new HttpsError(
        "unauthenticated",
        "Authentication is required to get futures signals."
      )
    );
  });

  it("should throw unauthenticated error if auth.uid is missing", async () => {
    const invalidAuthRequest = {
      data: { symbol: "ES=F", contractId: "ESM24" },
      auth: { uid: "" } as any,
    };

    await expect(
      (getFuturesSignals as any).run(invalidAuthRequest)
    ).rejects.toThrow(
      new HttpsError(
        "unauthenticated",
        "Authentication is required to get futures signals."
      )
    );
  });

  it("should proceed if request.auth is valid", async () => {
    const authenticatedRequest = {
      data: {
        symbol: "ES=F",
        contractId: "ESM24",
        config: { skipSignalUpdate: true, skipRiskGuard: true },
      },
      auth: { uid: "user123" } as any,
    };

    const result = await (getFuturesSignals as any).run(authenticatedRequest);
    expect(result).toBeDefined();
    expect(result.status).not.toBe("error");
  });
});
