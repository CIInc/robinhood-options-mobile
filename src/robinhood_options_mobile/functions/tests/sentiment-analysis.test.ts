import { describe, expect, test, jest, beforeEach } from "@jest/globals";

const mockGetAll = jest.fn<any>();
const mockDocGet = jest.fn<any>();

const mockDoc = jest.fn((path: any) => ({
  get: mockDocGet,
  path: String(path),
}));

jest.mock("firebase-admin", () => {
  const apps: any[] = [];
  return {
    apps,
    initializeApp: jest.fn(() => {
      apps.push({});
    }),
    firestore: Object.assign(
      jest.fn(() => ({
        doc: mockDoc,
        getAll: mockGetAll,
      })),
      {
        DocumentSnapshot: class {},
      }
    ),
  };
});

jest.mock("firebase-functions/v2/https", () => ({
  onCall: (fn: any) => fn,
}));

jest.mock("firebase-functions/logger", () => ({
  info: jest.fn(),
  error: jest.fn(),
  warn: jest.fn(),
}));

import {
  getSentimentAnalysis,
  calculateMarketSentiment,
  calculateTrendingSentiment,
  generateSentimentFeed,
  POPULAR_SYMBOLS,
} from "../src/sentiment-analysis";

describe("sentiment-analysis tests", () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  /**
   * Helper function to create mock Firestore DocumentSnapshot.
   * @param {string} symbol
   * @param {number} signalStrength
   * @param {string} [reason]
   * @return {object} Mock document snapshot.
   */
  function createMockSnapshot(
    symbol: string,
    signalStrength: number,
    reason?: string
  ) {
    return {
      exists: true,
      data: () => ({
        symbol,
        multiIndicatorResult: { signalStrength },
        reason: reason || `${symbol} technical signal details.`,
        timestamp: new Date("2025-01-01T00:00:00Z").toISOString(),
      }),
    };
  }

  test("getSentimentAnalysis runs batched getAll and calculates metrics",
    async () => {
      mockGetAll.mockImplementation(async (...refs: any[]) => {
        return refs.map((ref) => {
          const pathParts = ref.path ? ref.path.split("/") : [];
          const symbol = pathParts[pathParts.length - 1] || "UNKNOWN";
          if (symbol === "SPY") {
            return createMockSnapshot("SPY", 80, "Bullish Trend.");
          }
          if (symbol === "QQQ") {
            return createMockSnapshot("QQQ", 70, "Moving Average Crossover.");
          }
          if (symbol === "NVDA") {
            return createMockSnapshot("NVDA", 85, "Strong Momentum.");
          }
          if (symbol === "TSLA") {
            return createMockSnapshot("TSLA", 20, "Bearish Divergence.");
          }
          return createMockSnapshot(symbol, 50, "Neutral Signal.");
        });
      });

      const result = await (getSentimentAnalysis as any)({ data: {} });

      // Ensure getAll was called exactly once for getSentimentAnalysis
      expect(mockGetAll).toHaveBeenCalledTimes(1);

      // Verify Market Sentiment
      expect(result.market).toBeDefined();
      expect(result.market.score).toBeGreaterThan(50);
      expect(result.market.summary).toContain("Bullish");

      // Verify Trending Sentiment
      expect(result.trending).toBeDefined();
      expect(result.trending.length).toBeGreaterThan(0);
      expect(result.trending[0].symbol).toBe("NVDA");

      // Verify Feed Items
      expect(result.feed).toBeDefined();
      expect(result.feed.length).toBeGreaterThan(0);
      expect(
        result.feed.some((f: any) => f.relatedSymbols.includes("NVDA"))
      ).toBe(true);
    });

  test("helper functions fall back to batched getAll without snapshotMap",
    async () => {
      mockGetAll.mockImplementation(async (...refs: any[]) => {
        return refs.map((ref) => {
          const symbol = ref.path.split("/").pop();
          return createMockSnapshot(symbol, 70, "Slightly Bullish.");
        });
      });

      const market = await calculateMarketSentiment();
      expect(mockGetAll).toHaveBeenCalledTimes(1);
      expect(market.score).toBe(70);

      mockGetAll.mockClear();
      const trending = await calculateTrendingSentiment();
      expect(mockGetAll).toHaveBeenCalledTimes(1);
      expect(trending.length).toBe(10);

      mockGetAll.mockClear();
      const feed = await generateSentimentFeed();
      expect(mockGetAll).toHaveBeenCalledTimes(1);
      expect(feed.length).toBe(20);

      expect(POPULAR_SYMBOLS.length).toBe(20);
    });
});
