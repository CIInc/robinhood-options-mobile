import { describe, expect, test, jest, beforeEach } from "@jest/globals";

const mockGroupDoc = jest.fn<any>();
const mockUserDoc = jest.fn<any>();
const mockOrderQuery = jest.fn<any>();

jest.mock("firebase-admin/firestore", () => {
  class Timestamp {
    _seconds: number;
    _nanoseconds: number;
    constructor(seconds: number, nanoseconds: number) {
      this._seconds = seconds;
      this._nanoseconds = nanoseconds;
    }
    toDate() {
      return new Date(this._seconds * 1000);
    }
    static fromDate(date: Date) {
      return new Timestamp(Math.floor(date.getTime() / 1000), 0);
    }
  }

  return {
    getFirestore: jest.fn(() => ({
      collection: jest.fn((collName: string) => {
        if (collName === "investor_groups") {
          return {
            doc: jest.fn(() => ({
              get: mockGroupDoc,
            })),
          };
        }
        if (collName === "user") {
          return {
            doc: jest.fn((userId: string) => ({
              get: () => mockUserDoc(userId),
              collection: jest.fn((subColl: string) => {
                if (subColl === "instrumentOrder") {
                  return {
                    where: jest.fn(() => ({
                      orderBy: jest.fn(() => ({
                        get: () => mockOrderQuery(userId),
                      })),
                    })),
                  };
                }
                return {};
              }),
            })),
          };
        }
        return {};
      }),
    })),
    Timestamp,
  };
});

jest.mock("firebase-functions/v2/https", () => ({
  onCall: (fn: any) => fn,
  HttpsError: class HttpsError extends Error {
    code: string;
    constructor(code: string, message: string) {
      super(message);
      this.code = code;
    }
  },
}));

import { getGroupPerformanceAnalytics } from "../src/group-performance-analytics";

describe("group-performance-analytics tests", () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test("rejects unauthenticated request", async () => {
    await expect(
      (getGroupPerformanceAnalytics as any)({
        auth: null,
        data: { groupId: "group123" },
      })
    ).rejects.toMatchObject({
      code: "unauthenticated",
    });
  });

  test("rejects request missing groupId", async () => {
    await expect(
      (getGroupPerformanceAnalytics as any)({
        auth: { uid: "user1" },
        data: {},
      })
    ).rejects.toMatchObject({
      code: "invalid-argument",
    });
  });

  test("rejects non-existent group", async () => {
    mockGroupDoc.mockResolvedValueOnce({
      exists: false,
    });

    await expect(
      (getGroupPerformanceAnalytics as any)({
        auth: { uid: "user1" },
        data: { groupId: "non_existent" },
      })
    ).rejects.toMatchObject({
      code: "not-found",
    });
  });

  test("rejects request when caller is not a group member", async () => {
    mockGroupDoc.mockResolvedValueOnce({
      exists: true,
      data: () => ({
        members: ["user1", "user2"],
      }),
    });

    await expect(
      (getGroupPerformanceAnalytics as any)({
        auth: { uid: "user3" },
        data: { groupId: "group123" },
      })
    ).rejects.toMatchObject({
      code: "permission-denied",
    });
  });

  test("calculates analytics successfully with valid/invalid dates", async () => {
    mockGroupDoc.mockResolvedValueOnce({
      exists: true,
      data: () => ({
        members: ["user1"],
      }),
    });

    mockUserDoc.mockImplementation((userId: string) => {
      return Promise.resolve({
        exists: true,
        data: () => ({
          name: "Test User 1",
          photoUrl: "https://example.com/photo.jpg",
        }),
      });
    });

    mockOrderQuery.mockImplementation((userId: string) => {
      return Promise.resolve({
        docs: [
          {
            data: () => ({
              instrument_id: "inst1",
              side: "buy",
              state: "filled",
              cumulative_quantity: 10,
              average_price: 100,
              fees: 0,
              created_at: "2025-01-01T00:00:00Z",
            }),
          },
          {
            data: () => ({
              instrument_id: "inst1",
              side: "sell",
              state: "filled",
              cumulative_quantity: 10,
              average_price: 120,
              fees: 0,
              created_at: "2025-01-02T00:00:00Z",
            }),
          },
        ],
      });
    });

    const result = await (getGroupPerformanceAnalytics as any)({
      auth: { uid: "user1" },
      data: {
        groupId: "group123",
        startDate: "invalid-date-string",
        endDate: "2025-12-31T23:59:59Z",
      },
    });

    expect(result).toBeDefined();
    expect(result.groupMetrics).toBeDefined();
    expect(result.groupMetrics.groupId).toBe("group123");
    expect(result.groupMetrics.totalGroupTrades).toBe(1);
    expect(result.groupMetrics.groupTotalReturnDollars).toBe(200);
    expect(result.memberMetrics.length).toBe(1);
    expect(result.memberMetrics[0].memberName).toBe("Test User 1");
    expect(result.memberMetrics[0].totalReturnDollars).toBe(200);
  });
});
