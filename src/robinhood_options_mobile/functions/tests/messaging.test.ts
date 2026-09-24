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
});
