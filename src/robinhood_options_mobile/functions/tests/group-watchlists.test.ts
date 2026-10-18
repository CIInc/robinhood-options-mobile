import { describe, expect, test, jest, beforeEach } from "@jest/globals";

const deletedRefs: string[] = [];
let batchCommitCount = 0;

const LATENCY_MS = 10;
const NUM_SYMBOLS = 10;
const ALERTS_PER_SYMBOL = 2;

const mockBatch = {
  delete: jest.fn((ref: any) => {
    deletedRefs.push(ref.path || ref.id);
  }),
  commit: jest.fn(async () => {
    batchCommitCount++;
  }),
};

const mockWatchlistDocRef = {
  path: "investor_groups/group1/watchlists/wl1",
  collection: jest.fn((collName: string) => {
    if (collName === "symbols") {
      return {
        get: jest.fn(async () => {
          await new Promise((resolve) => setTimeout(resolve, LATENCY_MS));
          const docs = [];
          for (let i = 0; i < NUM_SYMBOLS; i++) {
            const symbolId = `SYM_${i}`;
            const alertPathPrefix =
              `investor_groups/group1/watchlists/wl1/symbols/${symbolId}`;
            docs.push({
              id: symbolId,
              ref: {
                path: alertPathPrefix,
                collection: jest.fn((subColl: string) => {
                  if (subColl === "alerts") {
                    return {
                      get: jest.fn(async () => {
                        await new Promise((resolve) =>
                          setTimeout(resolve, LATENCY_MS)
                        );
                        const alertDocs = [];
                        for (let j = 0; j < ALERTS_PER_SYMBOL; j++) {
                          const alertId = `ALT_${i}_${j}`;
                          alertDocs.push({
                            id: alertId,
                            ref: {
                              path: `${alertPathPrefix}/alerts/${alertId}`,
                            },
                          });
                        }
                        return { docs: alertDocs };
                      }),
                    };
                  }
                  return { get: jest.fn() };
                }),
              },
            });
          }
          return { docs };
        }),
      };
    }
    return { get: jest.fn() };
  }),
};

const mockWatchlistDoc = {
  exists: true,
  data: () => ({
    createdBy: "user1",
    permissions: {
      user1: "editor",
    },
  }),
  ref: mockWatchlistDocRef,
};

jest.mock("firebase-admin/firestore", () => ({
  getFirestore: jest.fn(() => ({
    collection: jest.fn(() => ({
      doc: jest.fn(() => ({
        collection: jest.fn(() => ({
          doc: jest.fn(() => ({
            get: jest.fn(async () => mockWatchlistDoc),
          })),
        })),
      })),
    })),
    batch: jest.fn(() => mockBatch),
  })),
  FieldValue: {
    serverTimestamp: jest.fn(),
    delete: jest.fn(),
  },
}));

import { deleteGroupWatchlist } from "../src/group-watchlists";

describe("deleteGroupWatchlist function and benchmark", () => {
  beforeEach(() => {
    deletedRefs.length = 0;
    batchCommitCount = 0;
    jest.clearAllMocks();
  });

  test("deletes all symbols, alerts, and watchlist successfully", async () => {
    const request = {
      auth: { uid: "user1" },
      data: { groupId: "group1", watchlistId: "wl1" },
    };

    const startTime = Date.now();
    const result = await (deleteGroupWatchlist as any).run(request);
    const duration = Date.now() - startTime;

    expect(result).toEqual({ success: true });
    expect(batchCommitCount).toBe(1);

    // Should delete 10 symbols + (10 * 2) alerts + 1 watchlist = 31 refs
    const expectedDeletedCount =
      NUM_SYMBOLS + NUM_SYMBOLS * ALERTS_PER_SYMBOL + 1;
    expect(deletedRefs.length).toBe(expectedDeletedCount);

    console.log(
      `[BENCHMARK] deleteGroupWatchlist time (${NUM_SYMBOLS} symbols): ` +
        `${duration} ms`
    );
  });

  test("rejects unauthenticated request", async () => {
    const request = {
      auth: null,
      data: { groupId: "group1", watchlistId: "wl1" },
    };

    await expect(
      (deleteGroupWatchlist as any).run(request)
    ).rejects.toMatchObject({
      code: "unauthenticated",
    });
  });
});
