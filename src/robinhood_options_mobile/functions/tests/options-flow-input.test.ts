import { describe, expect, test, jest } from "@jest/globals";
import { HttpsError } from "firebase-functions/v2/https";

jest.mock("../src/options-flow-utils", () => ({
  fetchOptionsFlowForSymbols: jest.fn(async (symbols: string[]) => {
    return symbols.map((s) => ({
      symbol: s,
      premium: 100000,
    }));
  }),
}));

import { getOptionsFlow } from "../src/options-flow";

describe("getOptionsFlow Security & Input Bounds Validation", () => {
  test("rejects unauthenticated request", async () => {
    const unauthenticatedRequest = {
      auth: null,
      data: { symbol: "AAPL" },
    };

    const callFn = () =>
      (getOptionsFlow as any).run(unauthenticatedRequest);

    await expect(callFn()).rejects.toThrow(HttpsError);
    await expect(callFn()).rejects.toMatchObject({
      code: "unauthenticated",
    });
  });

  test("rejects missing symbol and symbols payload", async () => {
    const request = {
      auth: { uid: "user123" },
      data: {},
    };

    const callFn = () => (getOptionsFlow as any).run(request);

    await expect(callFn()).rejects.toThrow(HttpsError);
    await expect(callFn()).rejects.toMatchObject({
      code: "invalid-argument",
    });
  });

  test("rejects empty symbols array", async () => {
    const request = {
      auth: { uid: "user123" },
      data: { symbols: [] },
    };

    const callFn = () => (getOptionsFlow as any).run(request);

    await expect(callFn()).rejects.toThrow(HttpsError);
    await expect(callFn()).rejects.toMatchObject({
      code: "invalid-argument",
    });
  });

  test("rejects oversized symbols array (> 100 items)", async () => {
    const largeSymbols = Array.from({ length: 101 }, (_, i) => `SYM${i}`);
    const request = {
      auth: { uid: "user123" },
      data: { symbols: largeSymbols },
    };

    const callFn = () => (getOptionsFlow as any).run(request);

    await expect(callFn()).rejects.toThrow(HttpsError);
    await expect(callFn()).rejects.toMatchObject({
      code: "invalid-argument",
    });
  });

  test("rejects array with invalid elements", async () => {
    const request = {
      auth: { uid: "user123" },
      data: { symbols: ["AAPL", 123, "   "] },
    };

    const callFn = () => (getOptionsFlow as any).run(request);

    await expect(callFn()).rejects.toThrow(HttpsError);
    await expect(callFn()).rejects.toMatchObject({
      code: "invalid-argument",
    });
  });

  test("accepts valid single symbol request", async () => {
    const request = {
      auth: { uid: "user123" },
      data: { symbol: "aapl" },
    };

    const response = await (getOptionsFlow as any).run(request);
    expect(response).toHaveProperty("items");
    expect(response.items).toHaveLength(1);
    expect(response.items[0].symbol).toBe("AAPL");
  });

  test("accepts valid multiple symbols request", async () => {
    const request = {
      auth: { uid: "user123" },
      data: { symbols: ["SPY", "QQQ"] },
    };

    const response = await (getOptionsFlow as any).run(request);
    expect(response).toHaveProperty("items");
    expect(response.items).toHaveLength(2);
  });
});
