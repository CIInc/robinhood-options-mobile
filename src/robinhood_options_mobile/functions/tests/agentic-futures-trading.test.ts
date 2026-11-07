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
  it("rejects when request.auth is missing", async () => {
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

  it("rejects when request.auth.uid is missing", async () => {
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

  it("rejects when symbol is missing or contains invalid characters",
    async () => {
      const invalidSymbols = ["", "   ", "ES/F", "ES..F..INVALID_LONG_TICKER",
        "ES F", "../traversal"];

      for (const symbol of invalidSymbols) {
        const req = {
          data: { symbol, contractId: "ESM24" },
          auth: { uid: "user123" } as any,
        };
        await expect(
          (getFuturesSignals as any).run(req)
        ).rejects.toThrow(
          new HttpsError(
            "invalid-argument",
            "symbol must be 1-20 alphanumeric characters (or =, ., -)."
          )
        );
      }
    });

  it("rejects when contractId is missing or contains invalid characters",
    async () => {
      const invalidContractIds = ["", "   ", "ES/M24", "ESM24#INVALID",
        "../../doc", "A".repeat(25)];

      for (const contractId of invalidContractIds) {
        const req = {
          data: { symbol: "ES=F", contractId },
          auth: { uid: "user123" } as any,
        };
        await expect(
          (getFuturesSignals as any).run(req)
        ).rejects.toThrow(
          new HttpsError(
            "invalid-argument",
            "contractId must be 1-20 alphanumeric characters (or =, ., -)."
          )
        );
      }
    });

  it("rejects when interval is not in allowed intervals whitelist",
    async () => {
      const invalidIntervals = ["5m", "30m", "2h", "1w", "invalid", "../1d"];

      for (const interval of invalidIntervals) {
        const req = {
          data: { symbol: "ES=F", contractId: "ESM24", interval },
          auth: { uid: "user123" } as any,
        };
        await expect(
          (getFuturesSignals as any).run(req)
        ).rejects.toThrow(
          new HttpsError(
            "invalid-argument",
            "interval must be one of: 15m, 1h, 1d."
          )
        );
      }
    });
});
