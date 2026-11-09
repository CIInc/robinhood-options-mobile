import { HttpsError } from "firebase-functions/v2/https";

const mockSet = jest.fn().mockResolvedValue({});
const mockDoc = jest.fn().mockReturnValue({ set: mockSet });

// Mock firebase-admin modules before importing functions
jest.mock("firebase-admin/app", () => ({
  getApp: jest.fn(),
  initializeApp: jest.fn(),
}));

jest.mock("firebase-admin/firestore", () => ({
  getFirestore: jest.fn().mockReturnValue({ doc: mockDoc }),
}));

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

describe("getFuturesSignals callable security", () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

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

  it("rejects path traversal attempt in contractId", async () => {
    const traversalRequest = {
      data: {
        symbol: "ES=F",
        contractId: "../users/victim",
      },
      auth: { uid: "user123" } as any,
    };

    await expect(
      (getFuturesSignals as any).run(traversalRequest)
    ).rejects.toThrow(
      new HttpsError(
        "invalid-argument",
        "Invalid or disallowed symbol, contractId, or interval."
      )
    );
  });

  it("rejects reserved system document id futures_watchlist", async () => {
    const reservedDocRequest = {
      data: {
        symbol: "ES=F",
        contractId: "futures_watchlist",
      },
      auth: { uid: "user123" } as any,
    };

    await expect(
      (getFuturesSignals as any).run(reservedDocRequest)
    ).rejects.toThrow(
      new HttpsError(
        "invalid-argument",
        "Invalid or disallowed symbol, contractId, or interval."
      )
    );
  });

  it("rejects unsupported interval string", async () => {
    const invalidIntervalRequest = {
      data: {
        symbol: "ES=F",
        contractId: "ESM24",
        interval: "invalid_interval",
      },
      auth: { uid: "user123" } as any,
    };

    await expect(
      (getFuturesSignals as any).run(invalidIntervalRequest)
    ).rejects.toThrow(
      new HttpsError(
        "invalid-argument",
        "Invalid or disallowed symbol, contractId, or interval."
      )
    );
  });

  it("prevents non-admin callers from updating signals", async () => {
    const nonAdminRequest = {
      data: {
        symbol: "ES=F",
        contractId: "ESM24",
        interval: "1h",
        config: { skipSignalUpdate: false, skipRiskGuard: true },
      },
      auth: { uid: "user123", token: { role: "user" } } as any,
    };

    const result = await (getFuturesSignals as any).run(nonAdminRequest);
    expect(result).toBeDefined();
    expect(result.status).not.toBe("error");
    // Verify Firestore doc.set was NOT called
    expect(mockSet).not.toHaveBeenCalled();
  });

  it("allows admin callers to update signals when not skipped", async () => {
    const adminRequest = {
      data: {
        symbol: "ES=F",
        contractId: "ESM24",
        interval: "1h",
        config: { skipSignalUpdate: false, skipRiskGuard: true },
      },
      auth: { uid: "admin1", token: { role: "admin" } } as any,
    };

    const result = await (getFuturesSignals as any).run(adminRequest);
    expect(result).toBeDefined();
    expect(result.status).not.toBe("error");
    expect(mockDoc).toHaveBeenCalledWith("signals/ESM24_1h");
    expect(mockSet).toHaveBeenCalled();
  });
});
