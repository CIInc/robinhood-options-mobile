import { describe, it, expect, jest, beforeEach } from "@jest/globals";

let docCallCount = 0;
let getAllCallCount = 0;

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

jest.mock("firebase-functions/v2/scheduler", () => ({
  onSchedule: jest.fn(),
}));

jest.mock("firebase-functions/v2/https", () => ({
  onRequest: jest.fn(),
  onCall: jest.fn(),
}));

import {
  getUserFCMTokens,
  getUsersFCMTokens,
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
