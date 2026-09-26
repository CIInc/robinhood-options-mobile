import { afterEach, describe, expect, jest, test } from "@jest/globals";

const cachedFlows = {
  items: [],
  lastUpdated: Date.now(),
};

jest.mock("firebase-admin/firestore", () => ({
  getFirestore: () => ({
    collection: (name: string) => ({
      doc: () => ({
        get: async () => name === "option_flows" ?
          { exists: true, data: () => cachedFlows } :
          { exists: false },
        set: async () => undefined,
        collection: () => ({
          get: async () => ({ empty: true, docs: [] }),
          doc: () => ({}),
        }),
      }),
    }),
    batch: () => ({
      set: () => undefined,
      commit: async () => undefined,
    }),
  }),
}));

const mockFetchWithRetry = jest.fn(async (url: string) => {
  const expiresAt = Math.floor(
    (Date.now() + 30 * 24 * 60 * 60 * 1000) / 1000
  );
  const quote = {
    regularMarketPrice: 100,
    regularMarketChangePercent: 0,
    sector: "Technology",
  };
  const chain = {
    optionChain: {
      result: [{
        expirationDates: [expiresAt],
        quote,
        options: [{
          expirationDate: expiresAt,
          calls: [{
            strike: 105,
            volume: 100,
            openInterest: 500,
            impliedVolatility: 0.25,
          }],
          puts: [{
            strike: 95,
            volume: 100,
            openInterest: 500,
            impliedVolatility: 0.25,
          }],
        }],
      }],
    },
  };

  return {
    ok: true,
    status: 200,
    statusText: "OK",
    headers: {
      get: () => "session=test;",
    },
    text: async () => "crumb",
    json: async () => url.includes("query2.finance.yahoo.com") ? chain : {},
  };
});

jest.mock("../src/utils", () => ({
  fetchWithRetry: (url: string) => mockFetchWithRetry(url),
}));

import { fetchOptionsFlowForSymbols } from "../src/options-flow-utils";

describe("fetchOptionsFlowForSymbols cache refresh", () => {
  const previousApiKey = process.env.TWELVE_DATA_API_KEY;

  afterEach(() => {
    if (previousApiKey === undefined) {
      delete process.env.TWELVE_DATA_API_KEY;
    } else {
      process.env.TWELVE_DATA_API_KEY = previousApiKey;
    }
    mockFetchWithRetry.mockClear();
  });

  test("refreshes the options chain despite a fresh " +
    "option-flow cache", async () => {
    delete process.env.TWELVE_DATA_API_KEY;

    await fetchOptionsFlowForSymbols(["AAPL"], "all", true);

    expect(
      mockFetchWithRetry.mock.calls.some(([url]) =>
        url.includes("query2.finance.yahoo.com/v7/finance/options/AAPL")
      )
    ).toBe(true);
  });
});
