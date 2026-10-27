import { describe, expect, test, jest, beforeEach } from "@jest/globals";

const mockBatchSet = jest.fn();
const mockBatchCommit = jest.fn<any>();
const mockDoc = jest.fn<any>();

jest.mock("firebase-admin/firestore", () => {
  /** Mock Firestore timestamp implementation. */
  class Timestamp {
    _seconds: number;
    _nanoseconds: number;

    /**
     * Creates a timestamp from seconds and nanoseconds.
     * @param {number} seconds Whole seconds since Unix epoch.
     * @param {number} nanoseconds Additional nanoseconds.
     */
    constructor(seconds: number, nanoseconds: number) {
      this._seconds = seconds;
      this._nanoseconds = nanoseconds;
    }

    /**
     * Creates a timestamp from a Date object.
     * @param {Date} date Date instance.
     * @return {Timestamp} Timestamp instance.
     */
    static fromDate(date: Date) {
      return new Timestamp(Math.floor(date.getTime() / 1000), 0);
    }
  }

  return {
    getFirestore: jest.fn(() => ({
      collection: jest.fn(() => ({
        doc: jest.fn(() => ({
          collection: jest.fn(() => ({
            doc: mockDoc,
          })),
        })),
      })),
      batch: jest.fn(() => ({
        set: mockBatchSet,
        commit: mockBatchCommit,
      })),
    })),
    Timestamp,
  };
});

jest.mock("firebase-functions/v2/https", () => ({
  onCall: (fn: any) => fn,
  HttpsError: class HttpsError extends Error {
    code: string;

    /**
     * Creates a callable error with code and message.
     * @param {string} code Error code string.
     * @param {string} message Error message.
     */
    constructor(code: string, message: string) {
      super(message);
      this.code = code;
    }
  },
}));

import { syncInstrumentOrders } from "../src/instrument-order-sync";

describe("syncInstrumentOrders tests", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockBatchCommit.mockResolvedValue(undefined);
    mockDoc.mockImplementation((id: string) => ({ id }));
  });

  test("rejects unauthenticated request", async () => {
    await expect(
      (syncInstrumentOrders as any)({
        auth: null,
        data: { orders: [] },
      })
    ).rejects.toMatchObject({
      code: "unauthenticated",
    });
  });

  test("rejects non-array orders input", async () => {
    await expect(
      (syncInstrumentOrders as any)({
        auth: { uid: "user123" },
        data: { orders: "not-an-array" },
      })
    ).rejects.toMatchObject({
      code: "invalid-argument",
    });
  });

  test("rejects payload exceeding MAX_ORDERS_PER_SYNC limit", async () => {
    const oversizedOrders = new Array(5001).fill({ id: "ord1" });
    await expect(
      (syncInstrumentOrders as any)({
        auth: { uid: "user123" },
        data: { orders: oversizedOrders },
      })
    ).rejects.toMatchObject({
      code: "invalid-argument",
    });
  });

  test("rejects orders with missing or invalid id", async () => {
    await expect(
      (syncInstrumentOrders as any)({
        auth: { uid: "user123" },
        data: { orders: [{ id: "" }] },
      })
    ).rejects.toMatchObject({
      code: "invalid-argument",
    });
  });

  test("successfully processes and syncs valid order payload", async () => {
    const validOrders = [
      {
        id: "ord_1",
        symbol: "AAPL",
        quantity: 10,
        created_at: "2025-03-01T12:00:00Z",
      },
      {
        id: "ord_2",
        symbol: "TSLA",
        quantity: 5,
        created_at: "2025-03-02T12:00:00Z",
      },
    ];

    const result = await (syncInstrumentOrders as any)({
      auth: { uid: "user123" },
      data: { orders: validOrders },
    });

    expect(result).toEqual({ written: 2 });
    expect(mockBatchSet).toHaveBeenCalledTimes(2);
    expect(mockBatchCommit).toHaveBeenCalledTimes(1);
  });
});
