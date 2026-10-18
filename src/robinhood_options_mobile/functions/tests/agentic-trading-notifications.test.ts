import { describe, expect, test, jest } from "@jest/globals";
import { HttpsError } from "firebase-functions/v2/https";

jest.mock("firebase-admin/firestore", () => ({
  getFirestore: () => ({
    collection: () => ({
      doc: () => ({
        get: jest.fn(async () => ({
          exists: true,
          data: () => ({
            agenticTradingConfig: { notifyOnBuy: true },
            devices: [{ fcmToken: "fcm_token_123" }],
          }),
        })),
        collection: () => ({
          add: jest.fn(async () => ({ id: "notif_123" })),
        }),
      }),
    }),
  }),
  FieldValue: {
    serverTimestamp: () => "TIMESTAMP",
  },
}));

jest.mock("firebase-admin/messaging", () => ({
  getMessaging: () => ({
    sendEachForMulticast: jest.fn(async () => ({
      successCount: 1,
      failureCount: 0,
      responses: [{ success: true }],
    })),
  }),
}));

// Import function under test after mocks
import { sendAgenticTradeNotification } from
  "../src/agentic-trading-notifications";

describe("sendAgenticTradeNotification Security Checks", () => {
  test("rejects unauthenticated request", async () => {
    const unauthenticatedRequest = {
      auth: null,
      data: { userId: "user1", type: "buy" },
    };

    const callFn = () =>
      (sendAgenticTradeNotification as any).run(unauthenticatedRequest);

    await expect(callFn()).rejects.toThrow(HttpsError);
    await expect(callFn()).rejects.toMatchObject({
      code: "unauthenticated",
    });
  });

  test("rejects request with missing required fields", async () => {
    const invalidRequest = {
      auth: { uid: "user1", token: {} },
      data: { userId: "user1" }, // missing type
    };

    const callFn = () =>
      (sendAgenticTradeNotification as any).run(invalidRequest);

    await expect(callFn()).rejects.toMatchObject({
      code: "invalid-argument",
    });
  });

  test("rejects non-admin cross-user notification attempt", async () => {
    const crossUserRequest = {
      auth: { uid: "user1", token: {} },
      data: {
        userId: "user2",
        type: "buy",
        symbol: "AAPL",
        price: 150,
        quantity: 10,
      },
    };

    const callFn = () =>
      (sendAgenticTradeNotification as any).run(crossUserRequest);

    await expect(callFn()).rejects.toMatchObject({
      code: "permission-denied",
    });
  });

  test("allows user to trigger notification for own account", async () => {
    const validRequest = {
      auth: { uid: "user1", token: {} },
      data: {
        userId: "user1",
        type: "buy",
        symbol: "AAPL",
        price: 150,
        quantity: 10,
      },
    };

    const response = await (sendAgenticTradeNotification as any).run(
      validRequest
    );

    expect(response).toEqual({
      success: true,
      successCount: 1,
      failureCount: 0,
    });
  });

  test("allows admin to trigger notification for another user", async () => {
    const adminRequest = {
      auth: { uid: "admin1", token: { role: "admin" } },
      data: {
        userId: "user2",
        type: "buy",
        symbol: "AAPL",
        price: 150,
        quantity: 10,
      },
    };

    const response = await (sendAgenticTradeNotification as any).run(
      adminRequest
    );

    expect(response).toEqual({
      success: true,
      successCount: 1,
      failureCount: 0,
    });
  });
});
