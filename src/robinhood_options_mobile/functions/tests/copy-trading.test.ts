import { describe, it, expect, jest, beforeEach } from "@jest/globals";

const mockCollection = jest.fn();
const mockAdd = jest.fn();
const mockSendEachForMulticast = jest.fn();

jest.mock("firebase-admin/firestore", () => {
  return {
    getFirestore: () => ({
      collection: mockCollection,
    }),
    FieldValue: {
      serverTimestamp: () => "MOCK_TIMESTAMP",
    },
  };
});

jest.mock("firebase-admin/messaging", () => {
  return {
    getMessaging: () => ({
      sendEachForMulticast: mockSendEachForMulticast,
    }),
  };
});

// Capture handler functions passed to onDocumentCreated
let instrumentOrderHandler: any = null;
let optionOrderHandler: any = null;

jest.mock("firebase-functions/v2/firestore", () => {
  return {
    onDocumentCreated: (path: string, handler: any) => {
      if (path.includes("instrumentOrder")) {
        instrumentOrderHandler = handler;
      } else if (path.includes("optionOrder")) {
        optionOrderHandler = handler;
      }
      return handler;
    },
  };
});

jest.mock("firebase-functions/logger", () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
}));

// Import module under test after setting up mocks
import "../src/copy-trading";

describe("Copy Trading Cloud Functions User Query Optimization", () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it("fetches source user doc once across multiple groups", async () => {
    const userId = "source_user_123";
    const orderId = "order_456";

    const userDocCount = { count: 0 };

    mockCollection.mockImplementation((collectionName: unknown) => {
      if (collectionName === "user") {
        return {
          doc: (docId: string) => {
            if (docId === userId) {
              userDocCount.count++;
              return {
                get: jest.fn().mockResolvedValue({
                  exists: true,
                  data: () => ({
                    name: "Trader Joe",
                    devices: [{ fcmToken: "token_1" }],
                  }),
                } as never),
              };
            }
            return {
              get: jest.fn().mockResolvedValue({
                exists: true,
                data: () => ({
                  name: "Target Member",
                  devices: [{ fcmToken: "token_2" }],
                }),
              } as never),
            };
          },
        };
      }
      if (collectionName === "instrument") {
        return {
          doc: () => ({
            get: jest.fn().mockResolvedValue({
              exists: true,
              data: () => ({
                symbol: "AAPL",
                fundamentalsObj: {
                  sector: "Technology",
                  market_cap: 3000000000000,
                },
              }),
            } as never),
          }),
        };
      }
      if (collectionName === "investor_groups") {
        return {
          where: () => ({
            get: jest.fn().mockResolvedValue({
              empty: false,
              docs: [
                {
                  data: () => ({
                    id: "group_1",
                    name: "Group 1",
                    members: [userId, "member_A", "member_B"],
                    memberCopyTradeSettings: {
                      member_A: {
                        enabled: true,
                        targetUserId: userId,
                        autoExecute: true,
                      },
                      member_B: {
                        enabled: true,
                        targetUserId: userId,
                        autoExecute: false,
                      },
                    },
                  }),
                },
                {
                  data: () => ({
                    id: "group_2",
                    name: "Group 2",
                    members: [userId, "member_C"],
                    memberCopyTradeSettings: {
                      member_C: {
                        enabled: true,
                        targetUserId: userId,
                        autoExecute: true,
                      },
                    },
                  }),
                },
              ],
            } as never),
          }),
        };
      }
      if (collectionName === "copy_trades") {
        return {
          add: mockAdd.mockResolvedValue({ id: "copy_rec_id" } as never),
        };
      }
      return {};
    });

    mockSendEachForMulticast.mockResolvedValue({
      successCount: 1,
      failureCount: 0,
      responses: [{ success: true }],
    } as never);

    const event = {
      params: { userId, orderId },
      data: {
        data: () => ({
          state: "filled",
          side: "buy",
          quantity: 10,
          price: 150,
          type: "market",
          instrument_id: "inst_123",
          instrumentObj: { symbol: "AAPL" },
        }),
      },
    };

    await instrumentOrderHandler(event);

    // Expect source user doc to be fetched exactly once
    expect(userDocCount.count).toBe(1);
  });

  it("fetches source user document for option orders", async () => {
    const userId = "source_user_123";
    const orderId = "order_789";

    const userDocCount = { count: 0 };

    mockCollection.mockImplementation((collectionName: unknown) => {
      if (collectionName === "user") {
        return {
          doc: (docId: string) => {
            if (docId === userId) {
              userDocCount.count++;
              return {
                get: jest.fn().mockResolvedValue({
                  exists: true,
                  data: () => ({
                    name: "Trader Joe",
                    devices: [{ fcmToken: "token_1" }],
                  }),
                } as never),
              };
            }
            return {
              get: jest.fn().mockResolvedValue({
                exists: true,
                data: () => ({
                  name: "Target Member",
                  devices: [{ fcmToken: "token_2" }],
                }),
              } as never),
            };
          },
        };
      }
      if (collectionName === "instrument") {
        return {
          where: () => ({
            limit: () => ({
              get: jest.fn().mockResolvedValue({
                empty: false,
                docs: [
                  {
                    data: () => ({
                      symbol: "TSLA",
                      fundamentalsObj: {
                        sector: "Automotive",
                        market_cap: 800000000000,
                      },
                    }),
                  },
                ],
              } as never),
            }),
          }),
        };
      }
      if (collectionName === "investor_groups") {
        return {
          where: () => ({
            get: jest.fn().mockResolvedValue({
              empty: false,
              docs: [
                {
                  data: () => ({
                    id: "group_1",
                    name: "Group 1",
                    members: [userId, "member_A", "member_B"],
                    memberCopyTradeSettings: {
                      member_A: {
                        enabled: true,
                        targetUserId: userId,
                        autoExecute: true,
                      },
                      member_B: {
                        enabled: true,
                        targetUserId: userId,
                        autoExecute: false,
                      },
                    },
                  }),
                },
              ],
            } as never),
          }),
        };
      }
      if (collectionName === "copy_trades") {
        return {
          add: mockAdd.mockResolvedValue({ id: "copy_rec_id" } as never),
        };
      }
      return {};
    });

    mockSendEachForMulticast.mockResolvedValue({
      successCount: 1,
      failureCount: 0,
      responses: [{ success: true }],
    } as never);

    const event = {
      params: { userId, orderId },
      data: {
        data: () => ({
          state: "filled",
          direction: "debit",
          quantity: 2,
          price: 5.5,
          type: "limit",
          chain_symbol: "TSLA",
          legs: [{ side: "buy", option_type: "call", strike_price: 250 }],
        }),
      },
    };

    await optionOrderHandler(event);

    // Expect source user doc to be fetched exactly once
    expect(userDocCount.count).toBe(1);
  });
});
