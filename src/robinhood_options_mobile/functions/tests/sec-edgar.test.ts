import { describe, expect, it } from "@jest/globals";
import {
  countInsiderBuyCluster,
  hasPortfolioOverlap,
  parse13FXml,
  parse8KHtml,
  parseForm4Xml,
} from "../src/sec-edgar";

describe("SEC EDGAR filing parsers", () => {
  it(
    "counts open-market Form 4 purchases " +
      "without counting other codes",
    () => {
      const parsed = parseForm4Xml(`
      <ownershipDocument>
        <reportingOwner>
          <reportingOwnerId>
            <rptOwnerName>Jane Doe</rptOwnerName>
          </reportingOwnerId>
        </reportingOwner>
        <nonDerivativeTable>
          <nonDerivativeTransaction>
            <transactionCoding>
              <transactionCode>P</transactionCode>
            </transactionCoding>
          </nonDerivativeTransaction>
          <nonDerivativeTransaction>
            <transactionCoding>
              <transactionCode>S</transactionCode>
            </transactionCoding>
          </nonDerivativeTransaction>
          <nonDerivativeTransaction>
            <transactionCoding>
              <transactionCode>P</transactionCode>
            </transactionCoding>
          </nonDerivativeTransaction>
        </nonDerivativeTable>
      </ownershipDocument>`);

      expect(parsed).toEqual({
        filerName: "Jane Doe",
        filerNames: ["Jane Doe"],
        transactionCount: 3,
        openMarketBuyCount: 2,
        summary: "2 open-market insider purchases reported",
      });
    }
  );

  it("counts distinct Form 4 buyers only within the 30-day window", () => {
    const now = Date.UTC(2026, 8, 24);
    const filing = (
      form: "4" | "8-K" | "13F-HR",
      filedAt: string,
      reportingOwners: string[],
      openMarketBuyCount: number
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
    });
    const recentDate = "2026-09-20";
    const oldDate = "2026-08-01";

    expect(countInsiderBuyCluster([
      filing("4", recentDate, ["Jane Doe"], 1),
      filing("4", recentDate, ["Jane Doe"], 2),
      filing("4", recentDate, ["John Doe"], 1),
      filing("4", oldDate, ["Old Buyer"], 1),
      filing("4", recentDate, ["Seller"], 0),
      filing("8-K", recentDate, ["Not an insider"], 1),
    ], now)).toBe(2);
  });

  it(
    "extracts and deduplicates material 8-K item codes from HTML",
    () => {
      const parsed = parse8KHtml(
        "<html><body><p>Item 2.02 Results of Operations</p>" +
          "<p>Item 5.02 Departure or Appointment</p>" +
          "<p>Item 2.02</p></body></html>"
      );

      expect(parsed.itemCodes).toEqual(["2.02", "5.02"]);
      expect(parsed.summary).toContain("Items 2.02, 5.02");
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
