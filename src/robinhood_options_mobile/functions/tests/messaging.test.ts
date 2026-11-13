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

  test("rejects non-array or empty tokens", async () => {
    const adminAuth = { uid: "admin123", token: { role: "admin" } };

    await expect(
      (sendEachForMulticast as any).run({
        auth: adminAuth,
        data: { title: "Title", body: "Body", tokens: [] },
      })
    ).rejects.toMatchObject({ code: "invalid-argument" });

    await expect(
      (sendEachForMulticast as any).run({
        auth: adminAuth,
        data: { title: "Title", body: "Body", tokens: "not-an-array" },
      })
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  test("rejects tokens exceeding 500 count or invalid token items",
    async () => {
      const adminAuth = { uid: "admin123", token: { role: "admin" } };

      const tooManyTokens = Array.from({ length: 501 }, (_, i) => `token_${i}`);
      await expect(
        (sendEachForMulticast as any).run({
          auth: adminAuth,
          data: { title: "Title", body: "Body", tokens: tooManyTokens },
        })
      ).rejects.toMatchObject({ code: "invalid-argument" });

      await expect(
        (sendEachForMulticast as any).run({
          auth: adminAuth,
          data: { title: "Title", body: "Body", tokens: ["valid", ""] },
        })
      ).rejects.toMatchObject({ code: "invalid-argument" });

      await expect(
        (sendEachForMulticast as any).run({
          auth: adminAuth,
          data: { title: "Title", body: "Body", tokens: ["valid", 12345] },
        })
      ).rejects.toMatchObject({ code: "invalid-argument" });
    });

  test("rejects missing, empty, or overly long title and body", async () => {
    const adminAuth = { uid: "admin123", token: { role: "admin" } };

    await expect(
      (sendEachForMulticast as any).run({
        auth: adminAuth,
        data: { title: "   ", body: "Body", tokens: ["token1"] },
      })
    ).rejects.toMatchObject({ code: "invalid-argument" });

    await expect(
      (sendEachForMulticast as any).run({
        auth: adminAuth,
        data: { title: "a".repeat(201), body: "Body", tokens: ["token1"] },
      })
    ).rejects.toMatchObject({ code: "invalid-argument" });

    await expect(
      (sendEachForMulticast as any).run({
        auth: adminAuth,
        data: { title: "Title", body: "   ", tokens: ["token1"] },
      })
    ).rejects.toMatchObject({ code: "invalid-argument" });

    await expect(
      (sendEachForMulticast as any).run({
        auth: adminAuth,
        data: { title: "Title", body: "b".repeat(2001), tokens: ["token1"] },
      })
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  test("rejects invalid route or imageUrl types / bounds", async () => {
    const adminAuth = { uid: "admin123", token: { role: "admin" } };

    await expect(
      (sendEachForMulticast as any).run({
        auth: adminAuth,
        data: {
          title: "Title",
          body: "Body",
          tokens: ["token1"],
          route: 12345,
        },
      })
    ).rejects.toMatchObject({ code: "invalid-argument" });

    await expect(
      (sendEachForMulticast as any).run({
        auth: adminAuth,
        data: {
          title: "Title",
          body: "Body",
          tokens: ["token1"],
          imageUrl: "https://".padEnd(2050, "a"),
        },
      })
    ).rejects.toMatchObject({ code: "invalid-argument" });
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

  test("sanitizes unexpected messaging errors into internal HttpsError",
    async () => {
      mockSendEachForMulticast.mockRejectedValueOnce(
        new Error("FCM service unavailable")
      );

      const adminRequest = {
        auth: { uid: "admin123", token: { role: "admin" } },
        data: {
          title: "Test Title",
          body: "Test Body",
          tokens: ["token1"],
        },
      };

      await expect(
        (sendEachForMulticast as any).run(adminRequest)
      ).rejects.toMatchObject({
        code: "internal",
        message:
          "An unexpected error occurred while sending multicast notifications.",
      });
    });
});
