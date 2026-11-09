import { describe, expect, test, jest, beforeEach } from "@jest/globals";
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
  beforeEach(() => {
    jest.clearAllMocks();
  });

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

  test("rejects missing or empty tokens array", async () => {
    const emptyTokensRequest = {
      auth: { uid: "admin123", token: { role: "admin" } },
      data: {
        title: "Test Title",
        body: "Test Body",
        tokens: [],
      },
    };

    const callFn = () =>
      (sendEachForMulticast as any).run(emptyTokensRequest);

    await expect(callFn()).rejects.toMatchObject({
      code: "invalid-argument",
    });
  });

  test("rejects tokens exceeding 500 count limit", async () => {
    const excessiveTokensRequest = {
      auth: { uid: "admin123", token: { role: "admin" } },
      data: {
        title: "Test Title",
        body: "Test Body",
        tokens: new Array(501).fill("token"),
      },
    };

    const callFn = () =>
      (sendEachForMulticast as any).run(excessiveTokensRequest);

    await expect(callFn()).rejects.toMatchObject({
      code: "invalid-argument",
    });
  });

  test("rejects invalid token elements (non-string or empty)", async () => {
    const invalidTokenRequest = {
      auth: { uid: "admin123", token: { role: "admin" } },
      data: {
        title: "Test Title",
        body: "Test Body",
        tokens: ["token1", ""],
      },
    };

    const callFn = () =>
      (sendEachForMulticast as any).run(invalidTokenRequest);

    await expect(callFn()).rejects.toMatchObject({
      code: "invalid-argument",
    });
  });

  test("rejects missing or empty title/body", async () => {
    const invalidTitleRequest = {
      auth: { uid: "admin123", token: { role: "admin" } },
      data: {
        title: "   ",
        body: "Test Body",
        tokens: ["token1"],
      },
    };

    const callFn = () =>
      (sendEachForMulticast as any).run(invalidTitleRequest);

    await expect(callFn()).rejects.toMatchObject({
      code: "invalid-argument",
    });
  });

  test("rejects oversized imageUrl or route", async () => {
    const oversizedUrlRequest = {
      auth: { uid: "admin123", token: { role: "admin" } },
      data: {
        title: "Test Title",
        body: "Test Body",
        imageUrl: "http://example.com/" + "a".repeat(2048),
        tokens: ["token1"],
      },
    };

    const callFn = () =>
      (sendEachForMulticast as any).run(oversizedUrlRequest);

    await expect(callFn()).rejects.toMatchObject({
      code: "invalid-argument",
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

  test("handles unexpected send errors securely with internal HttpsError",
    async () => {
      mockSendEachForMulticast.mockRejectedValueOnce(
        new Error("FCM network error")
      );

      const adminRequest = {
        auth: { uid: "admin123", token: { role: "admin" } },
        data: {
          title: "Test Title",
          body: "Test Body",
          tokens: ["token1"],
        },
      };

      const callFn = () =>
        (sendEachForMulticast as any).run(adminRequest);

      await expect(callFn()).rejects.toMatchObject({
        code: "internal",
        message: "Failed to deliver multicast notifications.",
      });
    }
  );
});
