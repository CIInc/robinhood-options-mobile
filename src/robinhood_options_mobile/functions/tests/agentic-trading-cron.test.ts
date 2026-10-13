import { describe, expect, test, jest } from "@jest/globals";
import { HttpsError } from "firebase-functions/v2/https";

jest.mock("firebase-admin/app", () => ({
  initializeApp: jest.fn(),
  getApps: jest.fn(() => [{ name: "default" }]),
}));

jest.mock("firebase-admin/messaging", () => ({
  getMessaging: jest.fn(() => ({
    send: jest.fn(),
  })),
}));

const mockListDocuments = jest.fn(async () => []);
const mockCollection = jest.fn(() => ({ listDocuments: mockListDocuments }));

jest.mock("firebase-admin/firestore", () => ({
  getFirestore: () => ({
    collection: mockCollection,
  }),
}));

import { agenticTradingCronInvoke } from "../src/agentic-trading-cron";

describe("agenticTradingCronInvoke Security Checks", () => {
  test("rejects unauthenticated caller", async () => {
    const unauthenticatedRequest = {
      auth: null,
      data: {},
    };

    const callFn = () =>
      (agenticTradingCronInvoke as any).run(unauthenticatedRequest);

    await expect(callFn()).rejects.toThrow(HttpsError);
    await expect(callFn()).rejects.toMatchObject({
      code: "unauthenticated",
    });
  });

  test("rejects non-admin caller", async () => {
    const nonAdminRequest = {
      auth: { uid: "user123", token: { role: "user" } },
      data: {},
    };

    const callFn = () =>
      (agenticTradingCronInvoke as any).run(nonAdminRequest);

    await expect(callFn()).rejects.toThrow(HttpsError);
    await expect(callFn()).rejects.toMatchObject({
      code: "permission-denied",
    });
  });

  test("allows admin caller to trigger cron invocation", async () => {
    const adminRequest = {
      auth: { uid: "admin123", token: { role: "admin" } },
      data: {},
    };

    const result = await (agenticTradingCronInvoke as any).run(adminRequest);
    expect(mockCollection).toHaveBeenCalledWith("charts");
    expect(result).toHaveProperty("processedCount", 0);
  });
});
