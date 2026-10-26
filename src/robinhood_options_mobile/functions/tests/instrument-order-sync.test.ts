import { syncInstrumentOrders } from "../src/instrument-order-sync";
import { HttpsError } from "firebase-functions/v2/https";

// Mock firebase-admin/firestore
jest.mock("firebase-admin/firestore", () => {
  const mockSet = jest.fn();
  const mockDoc = jest.fn(() => ({ set: mockSet }));
  const mockSubCollection = jest.fn(() => ({ doc: mockDoc }));
  const mockUserDoc = jest.fn(() => ({ collection: mockSubCollection }));
  const mockRootCollection = jest.fn(() => ({ doc: mockUserDoc }));
  const mockBatch = jest.fn(() => ({
    set: mockSet,
    commit: jest.fn().mockResolvedValue(undefined),
  }));

  return {
    getFirestore: jest.fn(() => ({
      collection: mockRootCollection,
      batch: mockBatch,
    })),
    Timestamp: {
      fromDate: (date: Date) => date,
    },
  };
});

describe("syncInstrumentOrders security & input validation", () => {
  it("rejects unauthenticated requests", async () => {
    const request = {
      auth: null,
      data: { orders: [] },
    } as any;

    const callFn = () => (syncInstrumentOrders as any).run(request);

    await expect(callFn()).rejects.toThrow(HttpsError);
    await expect(callFn()).rejects.toHaveProperty(
      "code",
      "unauthenticated"
    );
  });

  it("rejects non-array orders input", async () => {
    const request = {
      auth: { uid: "user123" },
      data: { orders: "not an array" },
    } as any;

    const callFn = () => (syncInstrumentOrders as any).run(request);

    await expect(callFn()).rejects.toThrow(HttpsError);
    await expect(callFn()).rejects.toHaveProperty(
      "code",
      "invalid-argument"
    );
  });

  it("rejects orders array exceeding MAX_ORDERS limit (2000)", async () => {
    const tooManyOrders = new Array(2001).fill(null).map((_, i) => ({
      id: `order_${i}`,
    }));

    const request = {
      auth: { uid: "user123" },
      data: { orders: tooManyOrders },
    } as any;

    const callFn = () => (syncInstrumentOrders as any).run(request);

    await expect(callFn()).rejects.toThrow(HttpsError);
    await expect(callFn()).rejects.toHaveProperty(
      "code",
      "invalid-argument"
    );
  });

  it("processes valid orders within limit", async () => {
    const validOrders = [
      { id: "order_1", created_at: "2025-01-01T00:00:00Z" },
      { id: "order_2", created_at: "2025-01-02T00:00:00Z" },
    ];

    const request = {
      auth: { uid: "user123" },
      data: { orders: validOrders },
    } as any;

    const result = await (syncInstrumentOrders as any).run(request);
    expect(result).toEqual({ written: 2 });
  });
});
