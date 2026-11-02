import { describe, expect, test, jest } from "@jest/globals";
import { HttpsError } from "firebase-functions/v2/https";

const mockSet = jest.fn();
const mockBatchCommit = jest.fn(async () => Promise.resolve());
const mockOrderDoc = jest.fn((id: string) => ({ id }));
const mockOrderCollection = jest.fn(() => ({
  doc: mockOrderDoc,
}));
const mockUserDoc = jest.fn(() => ({
  collection: () => mockOrderCollection(),
}));
const mockUserCollection = jest.fn(() => ({
  doc: mockUserDoc,
}));

jest.mock("firebase-admin/firestore", () => ({
  getFirestore: () => ({
    collection: () => mockUserCollection(),
    doc: () => ({
      collection: () => mockOrderCollection(),
    }),
    batch: () => ({
      set: mockSet,
      commit: mockBatchCommit,
    }),
  }),
  Timestamp: {
    fromDate: (d: Date) => d.toISOString(),
  },
}));

import { syncInstrumentOrders } from "../src/instrument-order-sync";

describe("syncInstrumentOrders Security and Bounds Validation", () => {
  test("rejects unauthenticated caller", async () => {
    const req = {
      auth: null,
      data: { orders: [] },
    };

    const callFn = () => (syncInstrumentOrders as any).run(req);
    await expect(callFn()).rejects.toThrow(HttpsError);
    await expect(callFn()).rejects.toMatchObject({
      code: "unauthenticated",
    });
  });

  test("rejects non-array orders input", async () => {
    const req = {
      auth: { uid: "user123" },
      data: { orders: "not-an-array" },
    };

    const callFn = () => (syncInstrumentOrders as any).run(req);
    await expect(callFn()).rejects.toThrow(HttpsError);
    await expect(callFn()).rejects.toMatchObject({
      code: "invalid-argument",
    });
  });

  test("rejects orders array exceeding MAX_ORDERS_PER_SYNC (500)", async () => {
    const largeOrders = Array.from({ length: 501 }, (_, i) => ({
      id: `order_${i}`,
    }));
    const req = {
      auth: { uid: "user123" },
      data: { orders: largeOrders },
    };

    const callFn = () => (syncInstrumentOrders as any).run(req);
    await expect(callFn()).rejects.toThrow(HttpsError);
    await expect(callFn()).rejects.toMatchObject({
      code: "invalid-argument",
    });
  });

  test("rejects orders missing valid id", async () => {
    const req = {
      auth: { uid: "user123" },
      data: { orders: [{ id: "" }] },
    };

    const callFn = () => (syncInstrumentOrders as any).run(req);
    await expect(callFn()).rejects.toThrow(HttpsError);
    await expect(callFn()).rejects.toMatchObject({
      code: "invalid-argument",
    });
  });

  test("accepts valid orders within bounds", async () => {
    const validOrders = [
      { id: "order_1", symbol: "AAPL", created_at: "2025-01-01T00:00:00Z" },
      { id: "order_2", symbol: "TSLA", created_at: "2025-01-02T00:00:00Z" },
    ];
    const req = {
      auth: { uid: "user123" },
      data: { orders: validOrders },
    };

    const result = await (syncInstrumentOrders as any).run(req);
    expect(result).toEqual({ written: 2 });
  });
});
