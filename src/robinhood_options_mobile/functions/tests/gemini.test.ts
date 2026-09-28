import { describe, expect, test, jest } from "@jest/globals";
import { HttpsError } from "firebase-functions/v2/https";

jest.mock("firebase-admin/firestore", () => ({
  getFirestore: jest.fn(() => ({
    collection: jest.fn(),
  })),
}));

jest.mock("@google/genai", () => ({
  GoogleGenAI: jest.fn().mockImplementation(() => ({
    models: {
      generateContent: jest.fn(),
    },
  })),
}));

import {
  generateContent31,
  generateContent25,
  analyzePriceTargets,
  stressTestTradeThesis,
} from "../src/gemini";

describe("Gemini Cloud Functions Security Checks", () => {
  describe("generateContent31", () => {
    test("rejects unauthenticated requests (null auth)", async () => {
      const unauthReq = {
        auth: null,
        data: { prompt: "Test prompt" },
      };
      const callFn = () => (generateContent31 as any).run(unauthReq);
      await expect(callFn()).rejects.toThrow(HttpsError);
      await expect(callFn()).rejects.toMatchObject({
        code: "unauthenticated",
      });
    });

    test("rejects unauthenticated requests (undefined auth)", async () => {
      const unauthReq = {
        data: { prompt: "Test prompt" },
      };
      const callFn = () => (generateContent31 as any).run(unauthReq);
      await expect(callFn()).rejects.toThrow(HttpsError);
      await expect(callFn()).rejects.toMatchObject({
        code: "unauthenticated",
      });
    });
  });

  describe("generateContent25", () => {
    test("rejects unauthenticated requests", async () => {
      const unauthReq = {
        auth: null,
        data: { prompt: "Test prompt" },
      };
      const callFn = () => (generateContent25 as any).run(unauthReq);
      await expect(callFn()).rejects.toThrow(HttpsError);
      await expect(callFn()).rejects.toMatchObject({
        code: "unauthenticated",
      });
    });
  });

  describe("analyzePriceTargets", () => {
    test("rejects unauthenticated requests", async () => {
      const unauthReq = {
        auth: null,
        data: { symbol: "AAPL" },
      };
      const callFn = () => (analyzePriceTargets as any).run(unauthReq);
      await expect(callFn()).rejects.toThrow(HttpsError);
      await expect(callFn()).rejects.toMatchObject({
        code: "unauthenticated",
      });
    });
  });

  describe("stressTestTradeThesis", () => {
    test("rejects unauthenticated requests (null auth)", async () => {
      const unauthReq = {
        auth: null,
        data: { symbol: "TSLA", direction: "Bullish" },
      };
      const callFn = () => (stressTestTradeThesis as any).run(unauthReq);
      await expect(callFn()).rejects.toThrow(HttpsError);
      await expect(callFn()).rejects.toMatchObject({
        code: "unauthenticated",
      });
    });

    test("rejects unauthenticated requests (undefined auth)", async () => {
      const unauthReq = {
        data: { symbol: "TSLA" },
      };
      const callFn = () => (stressTestTradeThesis as any).run(unauthReq);
      await expect(callFn()).rejects.toThrow(HttpsError);
      await expect(callFn()).rejects.toMatchObject({
        code: "unauthenticated",
      });
    });

    test("rejects missing symbol when authenticated", async () => {
      const authReq = {
        auth: { uid: "test-user-123" },
        data: {},
      };
      process.env.GEMINI_API_KEY = "dummy-key";
      const callFn = () => (stressTestTradeThesis as any).run(authReq);
      await expect(callFn()).rejects.toThrow(HttpsError);
      await expect(callFn()).rejects.toMatchObject({
        code: "invalid-argument",
      });
    });
  });
});

