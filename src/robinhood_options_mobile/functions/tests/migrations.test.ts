import { describe, expect, test, jest } from "@jest/globals";
import { HttpsError } from "firebase-functions/v2/https";

const mockGet = jest.fn(async () => ({ docs: [] }));
const mockCollection = jest.fn(() => ({ get: mockGet }));
const mockBatch = jest.fn(() => ({
  update: jest.fn(),
  commit: jest.fn(async () => undefined),
}));

jest.mock("firebase-admin/firestore", () => ({
  getFirestore: () => ({
    collection: mockCollection,
    batch: mockBatch,
  }),
}));

import { migrateSignalsDate } from "../src/migrations";

describe("migrateSignalsDate Security Checks", () => {
  test("rejects unauthenticated caller", async () => {
    const unauthenticatedRequest = {
      auth: null,
      data: {},
    };

    const callFn = () =>
      (migrateSignalsDate as any).run(unauthenticatedRequest);

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

    const callFn = () => (migrateSignalsDate as any).run(nonAdminRequest);

    await expect(callFn()).rejects.toThrow(HttpsError);
    await expect(callFn()).rejects.toMatchObject({
      code: "permission-denied",
    });
  });

  test("allows admin caller to run migration", async () => {
    const adminRequest = {
      auth: { uid: "admin123", token: { role: "admin" } },
      data: {},
    };

    await (migrateSignalsDate as any).run(adminRequest);
    expect(mockCollection).toHaveBeenCalledWith("signals");
  });
});
