import { describe, expect, it } from "@jest/globals";
import {
  calculateFilingLagDays,
  filterCongressTrades,
  findPortfolioOverlaps,
  isStockActFilingOverdue,
  parseAmountRange,
  normalizeLiveCongressTrade,
  RawTracefourTrade,
  CongressTrade,
} from "../src/congress-trading";

describe("Congress Trading tracker and STOCK Act tests", () => {
  it("parses amount range strings correctly", () => {
    expect(parseAmountRange("$1,001 - $15,000")).toEqual({
      min: 1001,
      max: 15000,
    });
    expect(parseAmountRange("$500,001 - $1,000,000")).toEqual({
      min: 500001,
      max: 1000000,
    });
    expect(parseAmountRange("Over $5,000,000")).toEqual({
      min: 5000000,
      max: undefined,
    });
    expect(parseAmountRange("$50,000")).toEqual({
      min: 50000,
      max: 50000,
    });
  });

  it(
    "calculates filing lag days and identifies overdue STOCK Act filings",
    () => {
    // 20 days: not overdue
      expect(calculateFilingLagDays("2026-08-01", "2026-08-21")).toBe(20);
      expect(isStockActFilingOverdue("2026-08-01", "2026-08-21")).toBe(false);

      // 45 days: on deadline, not overdue
      expect(calculateFilingLagDays("2026-08-01", "2026-09-15")).toBe(45);
      expect(isStockActFilingOverdue("2026-08-01", "2026-09-15")).toBe(false);

      // 53 days: overdue (> 45 days)
      expect(calculateFilingLagDays("2026-07-10", "2026-09-01")).toBe(53);
      expect(isStockActFilingOverdue("2026-07-10", "2026-09-01")).toBe(true);
    });

  const sampleTrades: CongressTrade[] = [
    {
      id: "t1",
      politicianName: "Nancy Pelosi",
      chamber: "House",
      party: "Democrat",
      state: "CA",
      district: "CA-11",
      symbol: "NVDA",
      assetDescription: "NVIDIA Corp",
      transactionType: "Purchase",
      amount: "$1,000,001 - $5,000,000",
      amountMin: 1000001,
      amountMax: 5000000,
      transactionDate: "2026-06-26",
      disclosureDate: "2026-07-02",
      owner: "Spouse",
      sourceUrl: "https://example.com/t1",
      isOverdue: false,
      filingLagDays: 6,
    },
    {
      id: "t2",
      politicianName: "Tommy Tuberville",
      chamber: "Senate",
      party: "Republican",
      state: "AL",
      symbol: "MSFT",
      assetDescription: "Microsoft Corp",
      transactionType: "Purchase",
      amount: "$100,001 - $250,000",
      amountMin: 100001,
      amountMax: 250000,
      transactionDate: "2026-08-04",
      disclosureDate: "2026-08-25",
      owner: "Joint",
      sourceUrl: "https://example.com/t2",
      isOverdue: false,
      filingLagDays: 21,
    },
    {
      id: "t3",
      politicianName: "Nancy Pelosi",
      chamber: "House",
      party: "Democrat",
      state: "CA",
      district: "CA-11",
      symbol: "AAPL",
      assetDescription: "Apple Inc",
      transactionType: "Sale (Partial)",
      amount: "$500,001 - $1,000,000",
      amountMin: 500001,
      amountMax: 1000000,
      transactionDate: "2026-07-28",
      disclosureDate: "2026-08-05",
      owner: "Spouse",
      sourceUrl: "https://example.com/t3",
      isOverdue: false,
      filingLagDays: 8,
    },
    {
      id: "t4",
      politicianName: "Josh Gottheimer",
      chamber: "House",
      party: "Democrat",
      state: "NJ",
      district: "NJ-05",
      symbol: "LLY",
      assetDescription: "Eli Lilly and Company",
      transactionType: "Purchase",
      amount: "$15,001 - $50,000",
      amountMin: 15001,
      amountMax: 50000,
      transactionDate: "2026-07-10",
      disclosureDate: "2026-09-01",
      owner: "Joint",
      sourceUrl: "https://example.com/t4",
      isOverdue: true,
      filingLagDays: 53,
    },
  ];

  it("filters trades by symbol, chamber, party, and transaction type", () => {
    // Filter by symbol
    const nvda = filterCongressTrades(sampleTrades, { symbol: "NVDA" });
    expect(nvda.length).toBe(1);
    expect(nvda[0].politicianName).toBe("Nancy Pelosi");

    // Filter by chamber
    const senate = filterCongressTrades(sampleTrades, { chamber: "Senate" });
    expect(senate.length).toBe(1);
    expect(senate[0].symbol).toBe("MSFT");

    // Filter by party
    const rep = filterCongressTrades(sampleTrades, { party: "Republican" });
    expect(rep.length).toBe(1);
    expect(rep[0].politicianName).toBe("Tommy Tuberville");

    // Filter by transaction type
    const sales = filterCongressTrades(sampleTrades, {
      transactionType: "Sale",
    });
    expect(sales.length).toBe(1);
    expect(sales[0].symbol).toBe("AAPL");

    // Filter by minAmount
    const largeTrades = filterCongressTrades(sampleTrades, {
      minAmount: 500000,
    });
    expect(largeTrades.length).toBe(2); // NVDA ($1M+) and AAPL ($500K+)
  });

  it("identifies portfolio overlaps accurately against user positions", () => {
    // User holds NVDA and TSLA
    const userSymbols1 = new Set(["NVDA", "TSLA"]);
    const overlap1 = findPortfolioOverlaps(sampleTrades, userSymbols1);
    expect(overlap1.portfolioOverlap).toBe(true);
    expect(overlap1.overlappingSymbols).toEqual(["NVDA"]);

    // User holds AAPL and MSFT
    const userSymbols2 = new Set(["AAPL", "MSFT", "GOOGL"]);
    const overlap2 = findPortfolioOverlaps(sampleTrades, userSymbols2);
    expect(overlap2.portfolioOverlap).toBe(true);
    expect(overlap2.overlappingSymbols).toEqual(["AAPL", "MSFT"]);

    // User holds only unmentioned tickers
    const userSymbols3 = new Set(["XYZ", "ABC"]);
    const overlap3 = findPortfolioOverlaps(sampleTrades, userSymbols3);
    expect(overlap3.portfolioOverlap).toBe(false);
    expect(overlap3.overlappingSymbols).toEqual([]);
  });

  it("normalizes live raw disclosure data from public feeds", () => {
    const rawHouseTrade: RawTracefourTrade = {
      memberName: "Nancy Pelosi",
      memberSlug: "nancy-pelosi",
      chamber: "house",
      party: "D",
      district: "CA11",
      ticker: "INTC",
      assetDescription: "Intel Corp",
      assetType: "Stock",
      type: "Purchase",
      amountLabel: "$500,001 - $1,000,000",
      amountMin: 500001,
      amountMax: 1000000,
      transactionDate: "2026-07-24",
      disclosureDate: "2026-08-24",
      owner: "Spouse",
      sourceLink:
        "https://disclosures-clerk.house.gov/public_disc/ptr-pdfs/2026/20035143.pdf",
      filingId: "nancy-pelosi|INTC|2026-07-24|Purchase|Stock",
    };

    const trade = normalizeLiveCongressTrade(rawHouseTrade);
    expect(trade).not.toBeNull();
    expect(trade!.politicianName).toBe("Nancy Pelosi");
    expect(trade!.chamber).toBe("House");
    expect(trade!.party).toBe("Democrat");
    expect(trade!.symbol).toBe("INTC");
    expect(trade!.transactionType).toBe("Purchase");
    expect(trade!.amountMin).toBe(500001);
    expect(trade!.amountMax).toBe(1000000);
    expect(trade!.owner).toBe("Spouse");
    expect(trade!.filingLagDays).toBe(31);
    expect(trade!.isOverdue).toBe(false);
    expect(trade!.sourceUrl).toContain("disclosures-clerk.house.gov");

    const rawSenateTrade: RawTracefourTrade = {
      memberName: "Tommy Tuberville",
      memberSlug: "tommy-tuberville",
      chamber: "senate",
      party: "R",
      district: "AL",
      ticker: "ADBE",
      assetDescription: "Adobe Inc",
      type: "Sale",
      amountLabel: "$15,001 - $50,000",
      amountMin: 15001,
      amountMax: 50000,
      transactionDate: "2024-10-29",
      disclosureDate: "2026-08-05",
      owner: "Joint",
      sourceLink:
        "https://efdsearch.senate.gov/search/view/ptr/2b076d77-6bc1-4b67-8be9-8f45a787479f/",
    };

    const senateTrade = normalizeLiveCongressTrade(rawSenateTrade);
    expect(senateTrade).not.toBeNull();
    expect(senateTrade!.chamber).toBe("Senate");
    expect(senateTrade!.party).toBe("Republican");
    expect(senateTrade!.transactionType).toBe("Sale");
    expect(senateTrade!.isOverdue).toBe(true);
    expect(senateTrade!.sourceUrl).toContain("efdsearch.senate.gov");

    // Rejects invalid or missing tickers
    expect(
      normalizeLiveCongressTrade({ ticker: "--", memberName: "Test" })
    ).toBeNull();
  });
});
