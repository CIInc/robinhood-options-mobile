import { describe, expect, test, jest, beforeEach } from "@jest/globals";

type DocumentCreatedHandler = (event: unknown) => unknown;

let sourceUserGetCount = 0;

const mockUserDoc = jest.fn((docId: string) => {
  return {
    get: jest.fn(async () => {
      if (docId === "user1") {
        sourceUserGetCount++;
        return {
          exists: true,
          data: () => ({ name: "Trader Joe", devices: [] }),
        };
      }

      return {
        exists: true,
        data: () => ({ name: "Follower", devices: [] }),
      };
    }),
  };
});

const mockInstrumentGet = jest.fn(async () => ({
  exists: true,
  data: () => ({
    symbol: "AAPL",
    fundamentalsObj: { sector: "Tech", market_cap: 1000 },
  }),
}));

const mockInstrumentQueryGet = jest.fn(async () => ({
  empty: false,
  docs: [
    {
      data: () => ({
        symbol: "AAPL",
        fundamentalsObj: { sector: "Tech", market_cap: 1000 },
      }),
    },
  ],
}));

const mockGroupDocs = [
  {
    id: "group1",
    data: () => ({
      id: "group1",
      name: "Group 1",
      members: ["user1", "member1", "member2"],
      memberCopyTradeSettings: {
        member1: { enabled: true, targetUserId: "user1", autoExecute: true },
        member2: { enabled: true, targetUserId: "user1", autoExecute: true },
      },
    }),
  },
  {
    id: "group2",
    data: () => ({
      id: "group2",
      name: "Group 2",
      members: ["user1", "member3", "member4"],
      memberCopyTradeSettings: {
        member3: { enabled: true, targetUserId: "user1", autoExecute: true },
        member4: { enabled: true, targetUserId: "user1", autoExecute: true },
      },
    }),
  },
];

const mockGroupsQueryGet = jest.fn(async () => ({
  empty: false,
  docs: mockGroupDocs,
}));

const mockCopyTradesAdd = jest.fn(async () => ({ id: "ct1" }));

jest.mock("firebase-functions/v2/firestore", () => ({
  onDocumentCreated:
    (_path: string, handler: DocumentCreatedHandler) => handler,
}));

jest.mock("firebase-admin/firestore", () => {
  return {
    getFirestore: () => ({
      collection: (collName: string) => {
        if (collName === "user") {
          return {
            doc: mockUserDoc,
          };
        }
        if (collName === "instrument") {
          return {
            doc: () => ({
              get: mockInstrumentGet,
            }),
            where: () => ({
              limit: () => ({
                get: mockInstrumentQueryGet,
              }),
            }),
          };
        }
        if (collName === "investor_groups") {
          return {
            where: () => ({
              get: mockGroupsQueryGet,
            }),
          };
        }
        if (collName === "copy_trades") {
          return {
            add: mockCopyTradesAdd,
          };
        }
        return {
          doc: () => ({ get: jest.fn() }),
        };
      },
    }),
    FieldValue: {
      serverTimestamp: () => "TIMESTAMP",
    },
  };
});

jest.mock("firebase-admin/messaging", () => ({
  getMessaging: () => ({
    sendEachForMulticast: jest.fn(async () => ({
      successCount: 1,
      failureCount: 0,
      responses: [],
    })),
  }),
}));

import {
  onInstrumentOrderCreated,
  onOptionOrderCreated,
} from "../src/copy-trading";

describe("Copy Trading N+1 query benchmark/test", () => {
  beforeEach(() => {
    sourceUserGetCount = 0;
    mockUserDoc.mockClear();
    mockInstrumentGet.mockClear();
    mockInstrumentQueryGet.mockClear();
    mockGroupsQueryGet.mockClear();
    mockCopyTradesAdd.mockClear();
  });

  test("onInstrumentOrderCreated source user lookup count", async () => {
    const event = {
      params: { userId: "user1", orderId: "order1" },
      data: {
        data: () => ({
          state: "filled",
          quantity: 10,
          price: 150,
          side: "buy",
          instrument_id: "inst1",
          type: "market",
          instrumentObj: { symbol: "AAPL" },
        }),
      },
    };

    await (onInstrumentOrderCreated as any)(event);

    expect(mockCopyTradesAdd).toHaveBeenCalledTimes(4);
    expect(sourceUserGetCount).toBe(1);
  });

  test("onOptionOrderCreated source user lookup count", async () => {
    const event = {
      params: { userId: "user1", orderId: "order1" },
      data: {
        data: () => ({
          state: "filled",
          quantity: 2,
          price: 5.5,
          direction: "debit",
          chain_symbol: "AAPL",
          type: "limit",
          legs: [{ side: "buy", ratio_quantity: 1 }],
        }),
      },
    };

    await (onOptionOrderCreated as any)(event);

    expect(mockCopyTradesAdd).toHaveBeenCalledTimes(4);
    expect(sourceUserGetCount).toBe(1);
  });
});
