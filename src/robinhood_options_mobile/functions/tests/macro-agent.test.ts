import { describe, expect, test, jest } from "@jest/globals";
import { HttpsError } from "firebase-functions/v2/https";

jest.mock("firebase-admin/firestore", () => ({
  getFirestore: jest.fn(() => ({
    collection: jest.fn(),
  })),
}));

jest.mock("firebase-admin/messaging", () => ({
  getMessaging: jest.fn(() => ({
    sendEachForMulticast: jest.fn(),
  })),
}));

import {
  getMacroAssessmentCall,
  getMacroHistoryCall,
} from "../src/macro-agent";

describe("Macro Agent Cloud Functions Security Checks", () => {
  describe("getMacroAssessmentCall", () => {
    test("rejects unauthenticated requests (null auth)", async () => {
      const unauthReq = {
        auth: null,
        data: { forceRefresh: true },
      };
      const callFn = () => (getMacroAssessmentCall as any).run(unauthReq);
      await expect(callFn()).rejects.toThrow(HttpsError);
      await expect(callFn()).rejects.toMatchObject({
        code: "unauthenticated",
      });
    });

    test("rejects unauthenticated requests (undefined auth)", async () => {
      const unauthReq = {
        data: {},
      };
      const callFn = () => (getMacroAssessmentCall as any).run(unauthReq);
      await expect(callFn()).rejects.toThrow(HttpsError);
      await expect(callFn()).rejects.toMatchObject({
        code: "unauthenticated",
      });
    });
  });

  describe("getMacroHistoryCall", () => {
    test("rejects unauthenticated requests (null auth)", async () => {
      const unauthReq = {
        auth: null,
        data: { limit: 10 },
      };
      const callFn = () => (getMacroHistoryCall as any).run(unauthReq);
      await expect(callFn()).rejects.toThrow(HttpsError);
      await expect(callFn()).rejects.toMatchObject({
        code: "unauthenticated",
      });
    });

    test("rejects unauthenticated requests (undefined auth)", async () => {
      const unauthReq = {
        data: {},
      };
      const callFn = () => (getMacroHistoryCall as any).run(unauthReq);
      await expect(callFn()).rejects.toThrow(HttpsError);
      await expect(callFn()).rejects.toMatchObject({
        code: "unauthenticated",
      });
    });
  });
});
