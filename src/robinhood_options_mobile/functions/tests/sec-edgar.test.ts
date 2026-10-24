import { describe, expect, it } from "@jest/globals";
import {
  buildSecFilingResearchBrief,
  countInsiderBuyCluster,
  countInsiderSellCluster,
  hasPortfolioOverlap,
  parse10KOr10QHtml,
  parse13FXml,
  parse8KHtml,
  parseCompanyFactsFinancials,
  parseForm4Xml,
} from "../src/sec-edgar";

describe("SEC EDGAR filing parsers", () => {
  it(
    "counts open-market Form 4 purchases and sales with net share/value totals",
    () => {
      const parsed = parseForm4Xml(`
      <ownershipDocument>
        <reportingOwner>
          <reportingOwnerId>
            <rptOwnerName>Jane Doe</rptOwnerName>
          </reportingOwnerId>
          <reportingOwnerRelationship>
            <officerTitle>Chief Financial Officer</officerTitle>
          </reportingOwnerRelationship>
        </reportingOwner>
        <nonDerivativeTable>
          <nonDerivativeTransaction>
            <transactionCoding>
              <transactionCode>P</transactionCode>
            </transactionCoding>
            <transactionAmounts>
              <transactionShares><value>1000</value></transactionShares>
              <transactionPricePerShare>
                <value>150</value>
              </transactionPricePerShare>
              <transactionAcquiredDisposedCode>
                <value>A</value>
              </transactionAcquiredDisposedCode>
            </transactionAmounts>
          </nonDerivativeTransaction>
          <nonDerivativeTransaction>
            <transactionCoding>
              <transactionCode>S</transactionCode>
            </transactionCoding>
            <transactionAmounts>
              <transactionShares><value>200</value></transactionShares>
              <transactionPricePerShare>
                <value>150</value>
              </transactionPricePerShare>
              <transactionAcquiredDisposedCode>
                <value>D</value>
              </transactionAcquiredDisposedCode>
            </transactionAmounts>
          </nonDerivativeTransaction>
          <nonDerivativeTransaction>
            <transactionCoding>
              <transactionCode>P</transactionCode>
            </transactionCoding>
            <transactionAmounts>
              <transactionShares><value>500</value></transactionShares>
              <transactionPricePerShare>
                <value>160</value>
              </transactionPricePerShare>
              <transactionAcquiredDisposedCode>
                <value>A</value>
              </transactionAcquiredDisposedCode>
            </transactionAmounts>
          </nonDerivativeTransaction>
        </nonDerivativeTable>
      </ownershipDocument>`);

      expect(parsed).toEqual({
        filerName: "Jane Doe",
        filerNames: ["Jane Doe"],
        officerTitles: ["Chief Financial Officer"],
        transactionCount: 3,
        openMarketBuyCount: 2,
        openMarketSellCount: 1,
        netSharesTransacted: 1300,
        netTransactionValue: 200000,
        summary: "2 open-market insider purchases reported",
      });
    }
  );

  it(
    "counts distinct Form 4 buyers and sellers only within the 30-day window",
    () => {
      const now = Date.UTC(2026, 8, 24);
      const filing = (
        form: "4" | "8-K" | "13F-HR",
        filedAt: string,
        reportingOwners: string[],
        openMarketBuyCount: number,
        openMarketSellCount = 0
      ) => ({
        accessionNumber: `${form}-${filedAt}`,
        form,
        filedAt,
        companyName: "Example Inc.",
        title: "Example filing",
        summary: "Example summary",
        url: "https://www.sec.gov/example",
        symbols: ["EXM"],
        reportingOwners,
        openMarketBuyCount,
        openMarketSellCount,
      });
      const recentDate = "2026-09-20";
      const oldDate = "2026-08-01";

      const sample = [
        filing("4", recentDate, ["Jane Doe"], 1, 0),
        filing("4", recentDate, ["Jane Doe"], 2, 0),
        filing("4", recentDate, ["John Doe"], 1, 0),
        filing("4", oldDate, ["Old Buyer"], 1, 0),
        filing("4", recentDate, ["Seller One"], 0, 2),
        filing("4", recentDate, ["Seller Two"], 0, 1),
        filing("4", oldDate, ["Old Seller"], 0, 3),
        filing("8-K", recentDate, ["Not an insider"], 1, 1),
      ];

      expect(countInsiderBuyCluster(sample, now)).toBe(2);
      expect(countInsiderSellCluster(sample, now)).toBe(2);
    }
  );

  it(
    "extracts and deduplicates material 8-K item codes and severity from HTML",
    () => {
      const parsed = parse8KHtml(
        "<html><body><p>Item 2.02 Results of Operations</p>" +
          "<p>Item 5.02 Departure or Appointment</p>" +
          "<p>Item 2.02</p></body></html>"
      );

      expect(parsed.itemCodes).toEqual(["2.02", "5.02"]);
      expect(parsed.materialEventSeverity).toBe("warning");
      expect(parsed.itemDescriptions).toEqual([
        "2.02: Results of Operations and Financial Condition",
        "5.02: Departure or Election of Directors or Principal Officers",
      ]);
      expect(parsed.summary).toContain("Items 2.02, 5.02");

      const critical8K = parse8KHtml("<p>Item 4.02 Non-Reliance</p>");
      expect(critical8K.materialEventSeverity).toBe("critical");
    }
  );

  it("extracts 10-K/10-Q fiscal period, risk factors, and MD&A themes", () => {
    const parsed = parse10KOr10QHtml(
      "<html><body>" +
        "<p>For the fiscal year ended September 26, 2026</p>" +
        "<p>Item 1A. Risk Factors: Supply chain and tariff pressures as well " +
        "as cybersecurity risks may impact operations.</p>" +
        "<p>Item 7. MD&A: Record revenue and margin expansion driven by " +
        "artificial intelligence and share repurchase activity.</p>" +
        "</body></html>",
      "10-K"
    );

    expect(parsed.fiscalPeriod).toBe("September 26, 2026");
    expect(parsed.riskHighlights.length).toBeGreaterThanOrEqual(2);
    expect(parsed.mdaHighlights.length).toBeGreaterThanOrEqual(2);
    expect(parsed.summary).toContain("Annual report for period ended");
  });

  it("parses XBRL companyfacts into a financial statement snapshot", () => {
    const snapshot = parseCompanyFactsFinancials({
      facts: {
        "us-gaap": {
          Revenues: {
            units: {
              USD: [
                {
                  val: 400000000000,
                  fy: 2026,
                  fp: "FY",
                  form: "10-K",
                  filed: "2026-10-30",
                  end: "2026-09-26",
                },
                {
                  val: 350000000000,
                  fy: 2025,
                  fp: "FY",
                  form: "10-K",
                  filed: "2025-10-31",
                  end: "2025-09-27",
                },
              ],
            },
          },
          NetIncomeLoss: {
            units: {
              USD: [
                {
                  val: 100000000000,
                  fy: 2026,
                  fp: "FY",
                  form: "10-K",
                  filed: "2026-10-30",
                  end: "2026-09-26",
                },
              ],
            },
          },
          EarningsPerShareDiluted: {
            units: {
              "USD/shares": [
                {
                  val: 6.5,
                  fy: 2026,
                  fp: "FY",
                  form: "10-K",
                  filed: "2026-10-30",
                  end: "2026-09-26",
                },
              ],
            },
          },
          Liabilities: {
            units: {
              USD: [
                {
                  val: 120000000000,
                  fy: 2026,
                  fp: "FY",
                  form: "10-K",
                  filed: "2026-10-30",
                  end: "2026-09-26",
                },
              ],
            },
          },
          StockholdersEquity: {
            units: {
              USD: [
                {
                  val: 80000000000,
                  fy: 2026,
                  fp: "FY",
                  form: "10-K",
                  filed: "2026-10-30",
                  end: "2026-09-26",
                },
              ],
            },
          },
        },
      },
    });

    expect(snapshot).toBeDefined();
    expect(snapshot?.revenue).toBe(400000000000);
    expect(snapshot?.revenueGrowthYoY).toBe(14.3);
    expect(snapshot?.netIncome).toBe(100000000000);
    expect(snapshot?.netMargin).toBe(25);
    expect(snapshot?.dilutedEps).toBe(6.5);
    expect(snapshot?.debtToEquity).toBe(1.5);
  });

  it(
    "builds an automated SEC filing research brief and answers questions",
    () => {
      const brief = buildSecFilingResearchBrief(
        "AAPL",
        [
          {
            accessionNumber: "0001-26-000001",
            form: "4",
            filedAt: "2026-09-20",
            companyName: "Apple Inc.",
            title: "Jane Doe - Form 4",
            summary: "2 open-market insider purchases reported",
            url: "https://www.sec.gov/example",
            symbols: ["AAPL"],
            openMarketBuyCount: 2,
            insiderClusterCount: 2,
          },
        ],
        {
          fiscalYear: 2026,
          fiscalPeriod: "FY",
          revenue: 400000000000,
          revenueGrowthYoY: 14.3,
          netIncome: 100000000000,
          netMargin: 25,
          dilutedEps: 6.5,
        },
        "What is the revenue and margin trend?"
      );

      expect(brief.symbol).toBe("AAPL");
      expect(brief.overallTone).toBe("bullish");
      expect(brief.financialHighlights[0]).toContain("$400.00B");
      expect(brief.answer).toContain("10-K/10-Q Financial Analysis for AAPL");
    }
  );

  it(
    "parses institutional 13F holdings and flags actual portfolio overlap",
    () => {
      const holdings = parse13FXml(`
      <informationTable>
        <infoTable>
          <nameOfIssuer>Apple Inc</nameOfIssuer>
          <value>125000</value>
          <shrsOrPrnAmt>
            <sshPrnamt>500000</sshPrnamt>
            <sshPrnamtType>SH</sshPrnamtType>
          </shrsOrPrnAmt>
        </infoTable>
      </informationTable>`);

      expect(holdings).toEqual([{
        issuerName: "Apple Inc",
        shares: 500000,
        valueThousands: 125000,
      }]);
      expect(hasPortfolioOverlap([
        { quantity: "4", instrument_obj: { symbol: "AAPL" } },
      ], "AAPL")).toBe(true);
      expect(hasPortfolioOverlap([
        { quantity: "0", instrument_obj: { symbol: "AAPL" } },
      ], "AAPL")).toBe(false);
    }
  );
});
