import { describe, expect, test, jest } from "@jest/globals";
import { HttpsError } from "firebase-functions/v2/https";

const mockSendEachForMulticast = jest.fn(async () => ({
  successCount: 1,
  failureCount: 0,
  responses: [],
}));

jest.mock("firebase-admin/messaging", () => ({
  getMessaging: () => ({
    sendEachForMulticast: mockSendEachForMulticast,
  }),
}));

import { sendEachForMulticast } from "../src/messaging";

describe("sendEachForMulticast Security Checks", () => {
  test("rejects unauthenticated caller", async () => {
    const unauthenticatedRequest = {
      auth: null,
      data: {
        title: "Test Title",
        body: "Test Body",
        tokens: ["token1"],
      },
    };

    const callFn = () =>
      (sendEachForMulticast as any).run(unauthenticatedRequest);

    await expect(callFn()).rejects.toThrow(HttpsError);
    await expect(callFn()).rejects.toMatchObject({
      code: "unauthenticated",
    });
  });

  test("rejects non-admin caller", async () => {
    const nonAdminRequest = {
      auth: { uid: "user123", token: { role: "user" } },
      data: {
        title: "Test Title",
        body: "Test Body",
        tokens: ["token1"],
      },
    };

    const callFn = () =>
      (sendEachForMulticast as any).run(nonAdminRequest);

    await expect(callFn()).rejects.toThrow(HttpsError);
    await expect(callFn()).rejects.toMatchObject({
      code: "permission-denied",
    });
  });

  test("allows admin caller to send multicast message", async () => {
    const adminRequest = {
      auth: { uid: "admin123", token: { role: "admin" } },
      data: {
        title: "Test Title",
        body: "Test Body",
        imageUrl: "http://example.com/image.png",
        tokens: ["token1"],
        route: "/home",
      },
    };

    const result = await (sendEachForMulticast as any).run(adminRequest);

    expect(mockSendEachForMulticast).toHaveBeenCalledWith({
      tokens: ["token1"],
      data: {
        route: "/home",
      },
      notification: {
        title: "Test Title",
        body: "Test Body",
        imageUrl: "http://example.com/image.png",
      },
    });
    expect(result).toEqual({
      successCount: 1,
      failureCount: 0,
      responses: [],
    });
  });

  test("rejects request if tokens is not an array or is empty", async () => {
    const adminAuth = { uid: "admin123", token: { role: "admin" } };

    const invalidRequests = [
      { auth: adminAuth, data: { tokens: null } },
      { auth: adminAuth, data: { tokens: "not-an-array" } },
      { auth: adminAuth, data: { tokens: [] } },
    ];

    for (const req of invalidRequests) {
      const callFn = () => (sendEachForMulticast as any).run(req);
      await expect(callFn()).rejects.toThrow(HttpsError);
      await expect(callFn()).rejects.toMatchObject({
        code: "invalid-argument",
      });
    }
  });

  test("rejects request if tokens exceeds 500 limit", async () => {
    const adminAuth = { uid: "admin123", token: { role: "admin" } };
    const oversizedTokens = Array.from({ length: 501 }, (_, i) => `token_${i}`);

    const req = {
      auth: adminAuth,
      data: {
        tokens: oversizedTokens,
      },
    };

    const callFn = () => (sendEachForMulticast as any).run(req);
    await expect(callFn()).rejects.toThrow(HttpsError);
    await expect(callFn()).rejects.toMatchObject({
      code: "invalid-argument",
    });
  });

  test("rejects request if tokens contains invalid entries", async () => {
    const adminAuth = { uid: "admin123", token: { role: "admin" } };

    const invalidTokenEntries = [
      { auth: adminAuth, data: { tokens: ["token1", ""] } },
      { auth: adminAuth, data: { tokens: ["token1", 12345] } },
      { auth: adminAuth, data: { tokens: ["token1", "   "] } },
    ];

    for (const req of invalidTokenEntries) {
      const callFn = () => (sendEachForMulticast as any).run(req);
      await expect(callFn()).rejects.toThrow(HttpsError);
      await expect(callFn()).rejects.toMatchObject({
        code: "invalid-argument",
      });
    }
  });

  test("handles unexpected FCM failure with internal error", async () => {
    mockSendEachForMulticast.mockImplementationOnce(() => {
      throw new Error("FCM exploded");
    });

    const adminRequest = {
      auth: { uid: "admin123", token: { role: "admin" } },
      data: {
        tokens: ["token1"],
      },
    };

    const callFn = (sendEachForMulticast as any).run(adminRequest);
    await expect(callFn).rejects.toThrow(HttpsError);
    await expect(callFn).rejects.toMatchObject({
      code: "internal",
    });
  });
});
