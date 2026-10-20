import { describe, it, expect, jest, beforeEach } from "@jest/globals";

let docCallCount = 0;
let getAllCallCount = 0;

const mockVerifyIdToken = jest.fn() as jest.Mock<any>;

jest.mock("firebase-admin/firestore", () => {
  return {
    getFirestore: jest.fn(() => ({
      collection: jest.fn(() => ({
        doc: jest.fn((docId: string) => ({
          get: jest.fn(async () => {
            docCallCount++;
            // Simulate 10ms network I/O latency per Firestore query
            await new Promise((resolve) => setTimeout(resolve, 10));
            return {
              exists: true,
              id: docId,
              data: () => ({
                devices: [{ fcmToken: `token-${docId}` }],
              }),
            };
          }),
        })),
      })),
      getAll: jest.fn(async (...docRefs: any[]) => {
        getAllCallCount++;
        // Simulate 10ms network I/O latency for 1 batch Firestore query
        await new Promise((resolve) => setTimeout(resolve, 10));
        return docRefs.map((ref) => ({
          exists: true,
          id: ref.id || "mock-id",
          data: () => ({
            devices: [{ fcmToken: `token-${ref.id || "mock-id"}` }],
          }),
        }));
      }),
    })),
    FieldValue: {
      serverTimestamp: jest.fn(),
    },
  };
});

jest.mock("firebase-admin/messaging", () => {
  return {
    getMessaging: jest.fn(() => ({
      sendEachForMulticast: jest.fn(),
    })),
  };
});

jest.mock("firebase-admin/auth", () => ({
  getAuth: () => ({
    verifyIdToken: mockVerifyIdToken,
  }),
}));

jest.mock("firebase-functions/v2/scheduler", () => ({
  onSchedule: jest.fn(),
}));

jest.mock("firebase-functions/v2/https", () => ({
  onRequest: jest.fn((handler: any) => handler),
  onCall: jest.fn((handler: any) => handler),
}));

import {
  getUserFCMTokens,
  getUsersFCMTokens,
  checkWatchlistAlerts,
} from "../src/watchlist-alerts-cron";

describe("Watchlist Alerts FCM Token Fetching Benchmark", () => {
  beforeEach(() => {
    docCallCount = 0;
    getAllCallCount = 0;
  });

  it("compares single sequential fetching vs batch fetching performance",
    async () => {
      const memberIds = Array.from(
        { length: 50 },
        (_, i) => `user_${i + 1}`
      );

      // Sequential single fetching (Baseline)
      const startTimeSeq = Date.now();
      const sequentialTokens: string[] = [];
      for (const id of memberIds) {
        const tokens = await getUserFCMTokens(id);
        sequentialTokens.push(...tokens);
      }
      const durationSeq = Date.now() - startTimeSeq;
      const seqCalls = getAllCallCount + docCallCount;

      // Reset counter
      docCallCount = 0;
      getAllCallCount = 0;

      // Batch fetching (Optimized)
      const startTimeBatch = Date.now();
      const batchTokens = await getUsersFCMTokens(memberIds);
      const durationBatch = Date.now() - startTimeBatch;
      const batchCalls = getAllCallCount;

      expect(sequentialTokens.length).toBe(50);
      expect(batchTokens.length).toBe(50);
      expect(batchTokens).toEqual(sequentialTokens);

      console.log(
        `Baseline (Sequential): ${durationSeq}ms across ` +
        `${seqCalls} db calls`
      );
      console.log(
        `Optimized (Batch): ${durationBatch}ms across ` +
        `${batchCalls} db calls`
      );
    });
});

describe("checkWatchlistAlerts security tests", () => {
  it("rejects unauthenticated requests with 401", async () => {
    let responseStatus: number | null = null;
    let responseJsonData: any = null;

    const mockReq = { headers: {} } as any;
    const mockRes = {
      status: jest.fn().mockImplementation((...args: any[]) => {
        responseStatus = args[0] as number;
        return mockRes;
      }),
      json: jest.fn().mockImplementation((...args: any[]) => {
        responseJsonData = args[0];
        return mockRes;
      }),
    } as any;

    await (checkWatchlistAlerts as any)(mockReq, mockRes);

    expect(responseStatus).toBe(401);
    expect(responseJsonData).toEqual({
      error: "Unauthorized: Admin privileges required.",
    });
  });

  it("rejects non-admin users with 401", async () => {
    mockVerifyIdToken.mockResolvedValueOnce({
      uid: "regularUser",
      role: "user",
    });

    let responseStatus: number | null = null;
    let responseJsonData: any = null;

    const mockReq = {
      headers: { authorization: "Bearer valid-user-token" },
    } as any;
    const mockRes = {
      status: jest.fn().mockImplementation((...args: any[]) => {
        responseStatus = args[0] as number;
        return mockRes;
      }),
      json: jest.fn().mockImplementation((...args: any[]) => {
        responseJsonData = args[0];
        return mockRes;
      }),
    } as any;

    await (checkWatchlistAlerts as any)(mockReq, mockRes);

    expect(responseStatus).toBe(401);
    expect(responseJsonData).toEqual({
      error: "Unauthorized: Admin privileges required.",
    });
  });
});
