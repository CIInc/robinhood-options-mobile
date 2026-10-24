import { XMLParser } from "fast-xml-parser";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineString } from "firebase-functions/params";
import fetch from "node-fetch";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();
const secUserAgent = defineString("SEC_EDGAR_USER_AGENT");
const cacheTtlMs = 30 * 60 * 1000;
const xmlParser = new XMLParser({
  ignoreAttributes: false,
  attributeNamePrefix: "@_",
  processEntities: false,
  parseTagValue: false,
  trimValues: true,
});

export type SecFilingType = "4" | "8-K" | "13F-HR" | "10-K" | "10-Q";

export type SecMaterialEventSeverity =
  | "critical"
  | "warning"
  | "info"
  | "positive";

export interface SecFinancialStatementSnapshot {
  fiscalYear?: number;
  fiscalPeriod?: string;
  form?: string;
  filedAt?: string;
  periodEnd?: string;
  revenue?: number;
  revenueGrowthYoY?: number;
  netIncome?: number;
  netMargin?: number;
  dilutedEps?: number;
  operatingIncome?: number;
  operatingMargin?: number;
  operatingCashFlow?: number;
  totalAssets?: number;
  totalLiabilities?: number;
  stockholdersEquity?: number;
  cashAndEquivalents?: number;
  debtToEquity?: number;
}

export interface SecFilingResearchBrief {
  symbol: string;
  generatedAt: string;
  headline: string;
  overallTone: "bullish" | "neutral" | "cautious" | "bearish";
  financialHighlights: string[];
  insiderActivitySummary: string;
  materialEventsSummary: string;
  institutionalSummary: string;
  riskFactors: string[];
  answer?: string;
}

export interface SecDisclosure {
  accessionNumber: string;
  form: SecFilingType;
  filedAt: string;
  companyName: string;
  title: string;
  summary: string;
  url: string;
  symbols: string[];
  reportingOwners?: string[];
  officerTitles?: string[];
  transactionCount?: number;
  openMarketBuyCount?: number;
  openMarketSellCount?: number;
  insiderClusterCount?: number;
  insiderSellClusterCount?: number;
  netSharesTransacted?: number;
  netTransactionValue?: number;
  itemCodes?: string[];
  itemDescriptions?: string[];
  materialEventSeverity?: SecMaterialEventSeverity;
  fiscalPeriod?: string;
  riskHighlights?: string[];
  mdaHighlights?: string[];
  holdings?: {
    issuerName: string;
    shares: number;
    valueThousands: number;
  }[];
}

interface SecCompany {
  cik: number;
  name: string;
}

interface SecCompanyTicker {
  cik_str: number;
  ticker: string;
  title: string;
}

interface FilingRow {
  accessionNumber: string;
  filingDate: string;
  form: string;
  primaryDocument: string;
  primaryDocDescription?: string;
}

let companyTickerPromise: Promise<Map<string, SecCompany>> | undefined;
let secRequestQueue: Promise<void> = Promise.resolve();

/** Converts untrusted parsed JSON values into a safe record shape.
 * @param {unknown} value JSON-compatible input.
 * @return {Record<string, any>} A record or an empty object.
 */
function asRecord(value: unknown): Record<string, any> {
  if (value && typeof value === "object" && !Array.isArray(value)) {
    return value as Record<string, any>;
  }
  return {};
}

/** Normalizes a singleton or list to an array.
 * @param {T | T[] | undefined} value The source value.
 * @return {T[]} An array containing the source values.
 */
function asArray<T>(value: T | T[] | undefined): T[] {
  if (value === undefined) return [];
  return Array.isArray(value) ? value : [value];
}

/** Extracts scalar or parsed XML text.
 * @param {unknown} value An XML parser value.
 * @return {string} The normalized text value.
 */
function text(value: unknown): string {
  if (typeof value === "string" || typeof value === "number") {
    return String(value).trim();
  }
  return String(asRecord(value)["#text"] ?? "").trim();
}

/** Builds a canonical SEC Archives URL.
 * @param {number} cik Issuer or filing-manager CIK.
 * @param {string} accessionNumber SEC accession number.
 * @param {string} document Filing document path.
 * @return {string} SEC Archives URL.
 */
function filingUrl(
  cik: number,
  accessionNumber: string,
  document: string
): string {
  const accessionPath = accessionNumber.replace(/-/g, "");
  return `https://www.sec.gov/Archives/edgar/data/${cik}/${accessionPath}/${encodeURIComponent(document)}`;
}

/** Normalizes company names for issuer matching.
 * @param {string} name Company name.
 * @return {string} Normalized company name.
 */
function normalizeName(name: string): string {
  return name
    .toLowerCase()
    .replace(/&amp;/g, "and")
    .replace(/[^a-z0-9]+/g, " ")
    .replace(
      /\b(incorporated|corporation|company|limited|inc|corp|co|ltd)\b/g,
      ""
    )
    .replace(/\s+/g, " ")
    .trim();
}

/** Compares normalized issuer names without accepting partial-name matches.
 * @param {string} left First company name.
 * @param {string} right Second company name.
 * @return {boolean} Whether both names normalize identically.
 */
function namesReferToSameCompany(left: string, right: string): boolean {
  const normalizedLeft = normalizeName(left);
  const normalizedRight = normalizeName(right);
  if (!normalizedLeft || !normalizedRight) return false;
  return normalizedLeft === normalizedRight;
}

const ITEM_8K_DESCRIPTIONS: Record<string, string> = {
  "1.01": "Entry into a Material Definitive Agreement",
  "1.02": "Termination of a Material Definitive Agreement",
  "1.03": "Bankruptcy or Receivership",
  "2.01": "Completion of Acquisition or Disposition of Assets",
  "2.02": "Results of Operations and Financial Condition",
  "2.03": "Creation of a Direct Financial Obligation",
  "2.04": "Triggering Events Accelerating a Financial Obligation",
  "2.05": "Costs Associated with Exit or Disposal Activities",
  "2.06": "Material Impairments",
  "3.01": "Notice of Delisting or Listing Rule Failure",
  "3.02": "Unregistered Sales of Equity Securities",
  "4.01": "Changes in Registrant's Certifying Accountant",
  "4.02": "Non-Reliance on Previously Issued Financial Statements",
  "5.01": "Changes in Control of Registrant",
  "5.02": "Departure or Election of Directors or Principal Officers",
  "5.03": "Amendments to Articles of Incorporation or Bylaws",
  "5.07": "Submission of Matters to a Vote of Security Holders",
  "7.01": "Regulation FD Disclosure",
  "8.01": "Other Material Events",
  "9.01": "Financial Statements and Exhibits",
};

const CRITICAL_8K_ITEMS = new Set(["1.03", "3.01", "4.02"]);
const WARNING_8K_ITEMS = new Set([
  "1.02",
  "2.04",
  "2.05",
  "2.06",
  "4.01",
  "5.02",
]);

/** Extracts a nested `.value` or scalar text from a Form 4 XML node.
 * @param {unknown} node XML node that may wrap a `<value>` tag.
 * @return {string} Normalized text.
 */
function form4Value(node: unknown): string {
  const record = asRecord(node);
  if (record.value !== undefined) {
    return text(record.value);
  }
  return text(node);
}

/** Parses ownership and transaction data from an SEC Form 4 XML document.
 * @param {string} xml Filing document content.
 * @return {Object} Insider name, transaction counts, and summary.
 */
export function parseForm4Xml(xml: string): {
  filerName: string;
  filerNames: string[];
  officerTitles: string[];
  transactionCount: number;
  openMarketBuyCount: number;
  openMarketSellCount: number;
  netSharesTransacted: number;
  netTransactionValue: number;
  summary: string;
} {
  const document = asRecord(xmlParser.parse(xml).ownershipDocument);
  const owners = asArray(asRecord(document).reportingOwner);
  const names = owners
    .map((owner) => text(asRecord(owner.reportingOwnerId).rptOwnerName))
    .filter(Boolean);
  const officerTitles = owners
    .map((owner) =>
      text(asRecord(owner.reportingOwnerRelationship).officerTitle)
    )
    .filter(Boolean);
  const nonDerivative = asArray(
    asRecord(document.nonDerivativeTable).nonDerivativeTransaction
  );
  const derivative = asArray(
    asRecord(document.derivativeTable).derivativeTransaction
  );
  const transactions = [...nonDerivative, ...derivative];
  let openMarketBuyCount = 0;
  let openMarketSellCount = 0;
  let netSharesTransacted = 0;
  let netTransactionValue = 0;

  for (const transaction of transactions) {
    const txRecord = asRecord(transaction);
    const code = text(asRecord(txRecord.transactionCoding).transactionCode);
    const amounts = asRecord(txRecord.transactionAmounts);
    const shares = Number(form4Value(amounts.transactionShares)) || 0;
    const price = Number(form4Value(amounts.transactionPricePerShare)) || 0;
    const acqDisp = form4Value(
      amounts.transactionAcquiredDisposedCode
    ).toUpperCase();
    const signedShares =
      code === "S" || acqDisp === "D" ? -Math.abs(shares) : Math.abs(shares);
    if (code === "P") {
      openMarketBuyCount += 1;
      netSharesTransacted += Math.abs(shares);
      netTransactionValue += Math.abs(shares) * price;
    } else if (code === "S") {
      openMarketSellCount += 1;
      netSharesTransacted -= Math.abs(shares);
      netTransactionValue -= Math.abs(shares) * price;
    } else if (shares > 0) {
      netSharesTransacted += signedShares;
      netTransactionValue += signedShares * price;
    }
  }

  const filerName = names.join(", ") || "Company insider";
  let summary: string;
  if (openMarketBuyCount > 1) {
    summary = `${openMarketBuyCount} open-market insider purchases reported`;
  } else if (openMarketBuyCount === 1) {
    summary = "Open-market insider purchase reported";
  } else if (openMarketSellCount > 1) {
    summary = `${openMarketSellCount} open-market insider sales reported`;
  } else if (openMarketSellCount === 1) {
    summary = "Open-market insider sale reported";
  } else {
    summary =
      `${transactions.length} insider transaction` +
      `${transactions.length === 1 ? "" : "s"} reported`;
  }

  return {
    filerName,
    filerNames: names,
    officerTitles,
    transactionCount: transactions.length,
    openMarketBuyCount,
    openMarketSellCount,
    netSharesTransacted: Math.round(netSharesTransacted * 100) / 100,
    netTransactionValue: Math.round(netTransactionValue * 100) / 100,
    summary,
  };
}

/** Extracts material event item numbers from an 8-K filing document.
 * @param {string} html Filing document content.
 * @return {Object} Deduplicated item numbers, descriptions, severity, summary.
 */
export function parse8KHtml(html: string): {
  itemCodes: string[];
  itemDescriptions: string[];
  materialEventSeverity: SecMaterialEventSeverity;
  summary: string;
} {
  const plainText = html
    .replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, " ")
    .replace(/<style\b[^>]*>[\s\S]*?<\/style>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;|&#160;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/\s+/g, " ");
  const itemCodes = [...new Set(
    Array.from(plainText.matchAll(/\bItem\s+(\d+\.\d{2})\b/gi), (match) =>
      match[1]
    )
  )].sort();
  const itemDescriptions = itemCodes.map((code) =>
    ITEM_8K_DESCRIPTIONS[code] ?
      `${code}: ${ITEM_8K_DESCRIPTIONS[code]}` :
      `Item ${code}`
  );
  let materialEventSeverity: SecMaterialEventSeverity = "info";
  if (itemCodes.some((code) => CRITICAL_8K_ITEMS.has(code))) {
    materialEventSeverity = "critical";
  } else if (itemCodes.some((code) => WARNING_8K_ITEMS.has(code))) {
    materialEventSeverity = "warning";
  }
  return {
    itemCodes,
    itemDescriptions,
    materialEventSeverity,
    summary: itemCodes.length > 0 ?
      `Material event disclosure: Items ${itemCodes.join(", ")}` :
      "Material event disclosure filed",
  };
}

/** Extracts MD&A and Risk Factor highlights from a 10-K or 10-Q HTML document.
 * @param {string} html Filing HTML or text content.
 * @param {"10-K" | "10-Q"} form Periodic report form type.
 * @return {Object} Parsed fiscal period, risk highlights, MD&A highlights.
 */
export function parse10KOr10QHtml(
  html: string,
  form: "10-K" | "10-Q"
): {
  fiscalPeriod?: string;
  riskHighlights: string[];
  mdaHighlights: string[];
  summary: string;
} {
  const plainText = html
    .replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, " ")
    .replace(/<style\b[^>]*>[\s\S]*?<\/style>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;|&#160;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/\s+/g, " ")
    .trim();

  const periodMatch = plainText.match(
    /(?:period\s+ended|fiscal\s+year\s+ended)\s+([A-Za-z]+\s+\d{1,2},\s+\d{4})/i
  );
  const fiscalPeriod = periodMatch ? periodMatch[1] : undefined;

  const riskCatalog: Array<{ pattern: RegExp; label: string }> = [
    {
      pattern: /\b(supply\s+chain|tariff|geopolitical|export\s+control)\b/i,
      label: "Supply chain, tariff, or geopolitical exposure noted",
    },
    {
      pattern: /\b(going\s+concern|substantial\s+doubt|covenant\s+breach)\b/i,
      label: "Liquidity or going-concern risk language detected",
    },
    {
      pattern: /\b(material\s+weakness|internal\s+control|restatement)\b/i,
      label: "Internal control or financial reporting risk cited",
    },
    {
      pattern:
        /\b(litigation|antitrust|subpoena|regulatory\s+investigation)\b/i,
      label: "Material litigation or regulatory inquiry disclosed",
    },
    {
      pattern: /\b(cybersecurity|data\s+breach|ransomware)\b/i,
      label: "Cybersecurity & data protection risk factors highlighted",
    },
    {
      pattern: /\b(interest\s+rate|inflationary|refinancing\s+risk)\b/i,
      label: "Macroeconomic rate & inflation sensitivity discussed",
    },
  ];

  const mdaCatalog: Array<{ pattern: RegExp; label: string }> = [
    {
      pattern:
        /\b(margin\s+expansion|operating\s+leverage|record\s+revenue)\b/i,
      label: "Operating leverage or margin expansion highlighted in MD&A",
    },
    {
      pattern: /\b(share\s+repurchase|buyback|dividend\s+increase)\b/i,
      label: "Capital return program (buybacks/dividends) detailed in MD&A",
    },
    {
      pattern: /\b(artificial\s+intelligence|cloud\s+growth|backlog)\b/i,
      label: "Strategic growth drivers & demand backlog emphasized",
    },
    {
      pattern: /\b(headwind|margin\s+compression|inventory\s+write-down)\b/i,
      label: "Near-term margin pressure or demand headwinds noted",
    },
  ];

  const riskHighlights = riskCatalog
    .filter((entry) => entry.pattern.test(plainText))
    .map((entry) => entry.label)
    .slice(0, 4);

  const mdaHighlights = mdaCatalog
    .filter((entry) => entry.pattern.test(plainText))
    .map((entry) => entry.label)
    .slice(0, 4);

  const reportLabel = form === "10-K" ? "Annual report" : "Quarterly report";
  const periodSuffix = fiscalPeriod ? ` for period ended ${fiscalPeriod}` : "";
  const highlightCount = riskHighlights.length + mdaHighlights.length;
  const summary = highlightCount > 0 ?
    `${reportLabel}${periodSuffix} (${highlightCount} key filing ` +
      `highlight${highlightCount === 1 ? "" : "s"} extracted)` :
    `${reportLabel}${periodSuffix} filed with SEC`;

  return {
    ...(fiscalPeriod ? { fiscalPeriod } : {}),
    riskHighlights,
    mdaHighlights,
    summary,
  };
}

/** Extracts the latest annual/quarterly numeric fact from SEC XBRL facts.
 * @param {Record<string, any>} usGaap The `facts["us-gaap"]` object.
 * @param {string[]} tags Ordered list of candidate US-GAAP concept tags.
 * @param {string} unitKey Preferred unit key (e.g., `"USD"` or `"USD/shares"`).
 * @return {Object | undefined} Latest fact entry and prior-year comparison.
 */
function extractLatestGaapFact(
  usGaap: Record<string, any>,
  tags: string[],
  unitKey: string
): {
  val: number;
  priorVal?: number;
  fy?: number;
  fp?: string;
  form?: string;
  filed?: string;
  end?: string;
} | undefined {
  for (const tag of tags) {
    const concept = asRecord(usGaap[tag]);
    const units = asRecord(concept.units);
    const series = asArray(units[unitKey] as Record<string, any>[]);
    const valid = series
      .map((item) => asRecord(item))
      .filter((item) =>
        typeof item.val === "number" &&
        Number.isFinite(item.val) &&
        typeof item.end === "string" &&
        (!item.form || ["10-K", "10-Q", "20-F", "40-F"].includes(
          String(item.form)
        ))
      )
      .sort((a, b) => String(b.end).localeCompare(String(a.end)));
    if (valid.length === 0) continue;

    // Prefer full-year (10-K) or single-quarter facts with matching frame/fp
    const latest = valid[0];
    const latestFp = String(latest.fp ?? "");
    const latestFy = Number(latest.fy);
    const priorCandidate = valid.find((item, idx) =>
      idx > 0 &&
      String(item.fp ?? "") === latestFp &&
      (Number.isFinite(latestFy) && Number.isFinite(Number(item.fy)) ?
        Number(item.fy) === latestFy - 1 :
        String(item.end) < String(latest.end))
    );

    return {
      val: Number(latest.val),
      priorVal: priorCandidate ? Number(priorCandidate.val) : undefined,
      fy: Number.isFinite(latestFy) ? latestFy : undefined,
      fp: latestFp || undefined,
      form: latest.form ? String(latest.form) : undefined,
      filed: latest.filed ? String(latest.filed) : undefined,
      end: latest.end ? String(latest.end) : undefined,
    };
  }
  return undefined;
}

/** Parses SEC EDGAR XBRL Company Facts JSON into a financial statement summary.
 * @param {Record<string, any>} factsJson Raw SEC `companyfacts` JSON object.
 * @return {SecFinancialStatementSnapshot | undefined} Parsed financial metrics.
 */
export function parseCompanyFactsFinancials(
  factsJson: Record<string, any>
): SecFinancialStatementSnapshot | undefined {
  const facts = asRecord(factsJson.facts);
  const usGaap = asRecord(facts["us-gaap"]);
  if (Object.keys(usGaap).length === 0) return undefined;

  const revenueFact = extractLatestGaapFact(
    usGaap,
    [
      "RevenueFromContractWithCustomerExcludingAssessedTax",
      "Revenues",
      "SalesRevenueNet",
      "RevenueFromContractWithCustomerIncludingAssessedTax",
    ],
    "USD"
  );
  const netIncomeFact = extractLatestGaapFact(
    usGaap,
    ["NetIncomeLoss", "ProfitLoss"],
    "USD"
  );
  const operatingIncomeFact = extractLatestGaapFact(
    usGaap,
    ["OperatingIncomeLoss"],
    "USD"
  );
  const epsFact = extractLatestGaapFact(
    usGaap,
    ["EarningsPerShareDiluted", "EarningsPerShareBasic"],
    "USD/shares"
  );
  const ocfFact = extractLatestGaapFact(
    usGaap,
    ["NetCashProvidedByUsedInOperatingActivities"],
    "USD"
  );
  const assetsFact = extractLatestGaapFact(usGaap, ["Assets"], "USD");
  const liabilitiesFact = extractLatestGaapFact(
    usGaap,
    ["Liabilities"],
    "USD"
  );
  const equityFact = extractLatestGaapFact(
    usGaap,
    [
      "StockholdersEquity",
      "StockholdersEquityIncludingPortionAttributableToNoncontrollingInterest",
    ],
    "USD"
  );
  const cashFact = extractLatestGaapFact(
    usGaap,
    [
      "CashAndCashEquivalentsAtCarryingValue",
      "CashCashEquivalentsRestrictedCashAndRestrictedCashEquivalents",
    ],
    "USD"
  );

  const anchor = revenueFact ?? netIncomeFact ?? assetsFact;
  if (!anchor) return undefined;

  const revenue = revenueFact?.val;
  const priorRevenue = revenueFact?.priorVal;
  const revenueGrowthYoY =
    revenue !== undefined &&
    priorRevenue !== undefined &&
    Math.abs(priorRevenue) > 0 ?
      Math.round(
        ((revenue - priorRevenue) / Math.abs(priorRevenue)) * 1000
      ) / 10 :
      undefined;

  const netIncome = netIncomeFact?.val;
  const netMargin =
    revenue !== undefined && revenue > 0 && netIncome !== undefined ?
      Math.round((netIncome / revenue) * 1000) / 10 :
      undefined;

  const operatingIncome = operatingIncomeFact?.val;
  const operatingMargin =
    revenue !== undefined && revenue > 0 && operatingIncome !== undefined ?
      Math.round((operatingIncome / revenue) * 1000) / 10 :
      undefined;

  const totalLiabilities = liabilitiesFact?.val;
  const stockholdersEquity = equityFact?.val;
  const debtToEquity =
    totalLiabilities !== undefined &&
    stockholdersEquity !== undefined &&
    stockholdersEquity > 0 ?
      Math.round((totalLiabilities / stockholdersEquity) * 100) / 100 :
      undefined;

  return {
    ...(anchor.fy !== undefined ? { fiscalYear: anchor.fy } : {}),
    ...(anchor.fp !== undefined ? { fiscalPeriod: anchor.fp } : {}),
    ...(anchor.form !== undefined ? { form: anchor.form } : {}),
    ...(anchor.filed !== undefined ? { filedAt: anchor.filed } : {}),
    ...(anchor.end !== undefined ? { periodEnd: anchor.end } : {}),
    ...(revenue !== undefined ? { revenue } : {}),
    ...(revenueGrowthYoY !== undefined ? { revenueGrowthYoY } : {}),
    ...(netIncome !== undefined ? { netIncome } : {}),
    ...(netMargin !== undefined ? { netMargin } : {}),
    ...(epsFact?.val !== undefined ? { dilutedEps: epsFact.val } : {}),
    ...(operatingIncome !== undefined ? { operatingIncome } : {}),
    ...(operatingMargin !== undefined ? { operatingMargin } : {}),
    ...(ocfFact?.val !== undefined ? { operatingCashFlow: ocfFact.val } : {}),
    ...(assetsFact?.val !== undefined ? { totalAssets: assetsFact.val } : {}),
    ...(totalLiabilities !== undefined ? { totalLiabilities } : {}),
    ...(stockholdersEquity !== undefined ? { stockholdersEquity } : {}),
    ...(cashFact?.val !== undefined ?
      { cashAndEquivalents: cashFact.val } :
      {}),
    ...(debtToEquity !== undefined ? { debtToEquity } : {}),
  };
}

/** Formats a USD figure in compact notation (e.g., `$1.25B`, `$450.0M`).
 * @param {number} amount Dollar value.
 * @return {string} Compact currency string.
 */
function formatCompactUsd(amount: number): string {
  const sign = amount < 0 ? "-" : "";
  const abs = Math.abs(amount);
  if (abs >= 1e12) return `${sign}$${(abs / 1e12).toFixed(2)}T`;
  if (abs >= 1e9) return `${sign}$${(abs / 1e9).toFixed(2)}B`;
  if (abs >= 1e6) return `${sign}$${(abs / 1e6).toFixed(1)}M`;
  if (abs >= 1e3) return `${sign}$${(abs / 1e3).toFixed(1)}K`;
  return `${sign}$${abs.toFixed(0)}`;
}

/** Synthesizes an automated 10-K/10-Q & EDGAR filing research brief.
 * @param {string} symbol Ticker symbol.
 * @param {SecDisclosure[]} disclosures Recent SEC disclosures.
 * @param {SecFinancialStatementSnapshot | undefined} financials XBRL metrics.
 * @param {string | undefined} question Optional user question to answer.
 * @return {SecFilingResearchBrief} Structured research assistant brief.
 */
export function buildSecFilingResearchBrief(
  symbol: string,
  disclosures: SecDisclosure[],
  financials?: SecFinancialStatementSnapshot,
  question?: string
): SecFilingResearchBrief {
  const cleanSymbol = symbol.trim().toUpperCase();
  const financialHighlights: string[] = [];
  const riskFactors: string[] = [];
  let toneScore = 0;

  if (financials) {
    const periodTag = [financials.fiscalPeriod, financials.fiscalYear]
      .filter(Boolean)
      .join(" ");
    if (financials.revenue !== undefined) {
      const growthStr = financials.revenueGrowthYoY !== undefined ?
        ` (${financials.revenueGrowthYoY >= 0 ? "+" : ""}` +
          `${financials.revenueGrowthYoY.toFixed(1)}% YoY)` :
        "";
      financialHighlights.push(
        `Revenue${periodTag ? ` (${periodTag})` : ""}: ` +
          `${formatCompactUsd(financials.revenue)}${growthStr}`
      );
      if ((financials.revenueGrowthYoY ?? 0) >= 10) toneScore += 1;
      if ((financials.revenueGrowthYoY ?? 0) < 0) toneScore -= 1;
    }
    if (financials.netIncome !== undefined) {
      const marginStr = financials.netMargin !== undefined ?
        ` (${financials.netMargin.toFixed(1)}% net margin)` :
        "";
      financialHighlights.push(
        `Net Income: ${formatCompactUsd(financials.netIncome)}${marginStr}`
      );
      if (financials.netIncome > 0) toneScore += 1;
      if (financials.netIncome < 0) {
        toneScore -= 1;
        riskFactors.push(
          `Negative net income (${formatCompactUsd(financials.netIncome)}) ` +
            "in latest parsed period"
        );
      }
    }
    if (financials.dilutedEps !== undefined) {
      financialHighlights.push(
        `Diluted EPS: $${financials.dilutedEps.toFixed(2)}`
      );
    }
    if (financials.operatingCashFlow !== undefined) {
      financialHighlights.push(
        "Operating Cash Flow: " +
          `${formatCompactUsd(financials.operatingCashFlow)}`
      );
    }
    if (
      financials.cashAndEquivalents !== undefined ||
      financials.debtToEquity !== undefined
    ) {
      const parts: string[] = [];
      if (financials.cashAndEquivalents !== undefined) {
        parts.push(`Cash: ${formatCompactUsd(financials.cashAndEquivalents)}`);
      }
      if (financials.debtToEquity !== undefined) {
        parts.push(
          `Liabilities/Equity: ${financials.debtToEquity.toFixed(2)}x`
        );
        if (financials.debtToEquity > 2.5) {
          riskFactors.push(
            "Elevated leverage (Liabilities/Equity " +
              `${financials.debtToEquity.toFixed(2)}x)`
          );
        }
      }
      financialHighlights.push(parts.join(" · "));
    }
  }

  const periodicFilings = disclosures.filter(
    (d) => d.form === "10-K" || d.form === "10-Q"
  );
  for (const filing of periodicFilings) {
    for (const risk of filing.riskHighlights ?? []) {
      if (!riskFactors.includes(risk)) riskFactors.push(risk);
    }
    for (const mda of filing.mdaHighlights ?? []) {
      if (!financialHighlights.includes(mda)) financialHighlights.push(mda);
    }
  }

  const form4s = disclosures.filter((d) => d.form === "4");
  const totalBuys = form4s.reduce(
    (sum, d) => sum + (d.openMarketBuyCount ?? 0),
    0
  );
  const totalSells = form4s.reduce(
    (sum, d) => sum + (d.openMarketSellCount ?? 0),
    0
  );
  const buyCluster = Math.max(
    0,
    ...form4s.map((d) => d.insiderClusterCount ?? 0)
  );
  const sellCluster = Math.max(
    0,
    ...form4s.map((d) => d.insiderSellClusterCount ?? 0)
  );
  let insiderActivitySummary: string;
  if (form4s.length === 0) {
    insiderActivitySummary = "No recent Form 4 insider transactions filed.";
  } else {
    const clusterNotes: string[] = [];
    if (buyCluster > 1) {
      clusterNotes.push(`${buyCluster} distinct buyers in 30d`);
      toneScore += 1;
    }
    if (sellCluster > 1) {
      clusterNotes.push(`${sellCluster} distinct sellers in 30d`);
      toneScore -= 1;
      riskFactors.push(
        `Insider selling cluster: ${sellCluster} insiders sold within 30 days`
      );
    }
    const suffix = clusterNotes.length > 0 ?
      ` (${clusterNotes.join(", ")})` :
      "";
    insiderActivitySummary =
      `${form4s.length} Form 4 filing${form4s.length === 1 ? "" : "s"}: ` +
      `${totalBuys} open-market buy${totalBuys === 1 ? "" : "s"}, ` +
      `${totalSells} open-market sale${totalSells === 1 ? "" : "s"}${suffix}.`;
  }

  const eightKs = disclosures.filter((d) => d.form === "8-K");
  let materialEventsSummary: string;
  if (eightKs.length === 0) {
    materialEventsSummary = "No recent Form 8-K material events filed.";
  } else {
    const allItems = [...new Set(eightKs.flatMap((d) => d.itemCodes ?? []))];
    const hasCritical = eightKs.some(
      (d) => d.materialEventSeverity === "critical"
    );
    const hasWarning = eightKs.some(
      (d) => d.materialEventSeverity === "warning"
    );
    if (hasCritical) {
      toneScore -= 2;
      riskFactors.push(
        `Critical Form 8-K disclosure filed (Items ${allItems.join(", ")})`
      );
    } else if (hasWarning) {
      toneScore -= 1;
    }
    materialEventsSummary =
      `${eightKs.length} recent Form 8-K filing` +
      `${eightKs.length === 1 ? "" : "s"}` +
      (allItems.length > 0 ? ` covering Items ${allItems.join(", ")}.` : ".");
  }

  const thirteenFs = disclosures.filter((d) => d.form === "13F-HR");
  const totalInstShares = thirteenFs.reduce(
    (sum, d) =>
      sum +
      (d.holdings ?? []).reduce((hSum, h) => hSum + (h.shares || 0), 0),
    0
  );
  const institutionalSummary = thirteenFs.length > 0 ?
    `${thirteenFs.length} institutional 13F-HR filing` +
      `${thirteenFs.length === 1 ? "" : "s"} reporting ` +
      `${totalInstShares.toLocaleString("en-US")} aggregate shares.` :
    "No recent 13F-HR institutional filings matched in current window.";

  let overallTone: "bullish" | "neutral" | "cautious" | "bearish" = "neutral";
  if (toneScore >= 2) overallTone = "bullish";
  else if (toneScore <= -2) overallTone = "bearish";
  else if (toneScore < 0) overallTone = "cautious";

  const headline =
    `${cleanSymbol} SEC Filing Brief: ` +
    `${financialHighlights[0] ?? `${disclosures.length} recent filings`} · ` +
    `Tone: ${overallTone.toUpperCase()}`;

  let answer: string | undefined;
  const trimmedQ = (question ?? "").trim();
  if (trimmedQ.length > 0) {
    const qLower = trimmedQ.toLowerCase();
    if (/(revenue|margin|eps|income|cash|debt|10-k|10-q|financial)/i.test(
      qLower
    )) {
      answer = financialHighlights.length > 0 ?
        `10-K/10-Q Financial Analysis for ${cleanSymbol}: ` +
          `${financialHighlights.join("; ")}.` :
        "No XBRL 10-K/10-Q financial statement facts are cached for " +
          `${cleanSymbol} yet.`;
    } else if (/(insider|form 4|buy|sell|cluster|officer)/i.test(qLower)) {
      answer = `Insider Trading Analysis for ${cleanSymbol}: ` +
        `${insiderActivitySummary}`;
    } else if (/(8-k|catalyst|material|event|risk)/i.test(qLower)) {
      const riskStr = riskFactors.length > 0 ?
        ` Key Risks: ${riskFactors.join("; ")}.` :
        " No critical risk flags triggered.";
      answer = `Material Events & Risk Factors for ${cleanSymbol}: ` +
        `${materialEventsSummary}${riskStr}`;
    } else if (/(13f|institution|whale|fund|ownership)/i.test(qLower)) {
      answer = `Institutional 13F Ownership for ${cleanSymbol}: ` +
        `${institutionalSummary}`;
    } else {
      answer =
        `${headline}. ${insiderActivitySummary} ${materialEventsSummary}` +
        (riskFactors.length > 0 ?
          ` Risks noted: ${riskFactors.join("; ")}.` :
          "");
    }
  }

  return {
    symbol: cleanSymbol,
    generatedAt: new Date().toISOString(),
    headline,
    overallTone,
    financialHighlights,
    insiderActivitySummary,
    materialEventsSummary,
    institutionalSummary,
    riskFactors,
    ...(answer ? { answer } : {}),
  };
}

/** Parses issuer positions from a 13F information-table XML document.
 * @param {string} xml Filing information-table content.
 * @return {Object[]} Issuer name, share count, and reported value.
 */
export function parse13FXml(xml: string): {
  issuerName: string;
  shares: number;
  valueThousands: number;
}[] {
  const parsed = asRecord(xmlParser.parse(xml));
  const root = asRecord(parsed.informationTable ?? parsed);
  const rows = asArray(root.infoTable);
  return rows.map((rowValue) => {
    const row = asRecord(rowValue);
    const amount = asRecord(row.shrsOrPrnAmt);
    return {
      issuerName: text(row.nameOfIssuer),
      shares: Number(text(amount.sshPrnamt)) || 0,
      valueThousands: Number(text(row.value)) || 0,
    };
  }).filter((holding) => holding.issuerName.length > 0);
}

/** Counts distinct reporting owners with recent open-market purchases.
 * @param {SecDisclosure[]} disclosures Recent issuer disclosures.
 * @param {number} referenceTimeMs Reference time in Unix milliseconds.
 * @return {number} Unique insider buyers reported in the last 30 days.
 */
export function countInsiderBuyCluster(
  disclosures: SecDisclosure[],
  referenceTimeMs: number = Date.now()
): number {
  const cutoff = referenceTimeMs - 30 * 24 * 60 * 60 * 1000;
  const buyers = new Set(disclosures
    .filter((disclosure) =>
      disclosure.form === "4" &&
      (disclosure.openMarketBuyCount ?? 0) > 0 &&
      new Date(disclosure.filedAt).getTime() >= cutoff
    )
    .flatMap((disclosure) => disclosure.reportingOwners ?? []));
  return buyers.size;
}

/** Counts distinct reporting owners with recent open-market sales.
 * @param {SecDisclosure[]} disclosures Recent issuer disclosures.
 * @param {number} referenceTimeMs Reference time in Unix milliseconds.
 * @return {number} Unique insider sellers reported in the last 30 days.
 */
export function countInsiderSellCluster(
  disclosures: SecDisclosure[],
  referenceTimeMs: number = Date.now()
): number {
  const cutoff = referenceTimeMs - 30 * 24 * 60 * 60 * 1000;
  const sellers = new Set(disclosures
    .filter((disclosure) =>
      disclosure.form === "4" &&
      (disclosure.openMarketSellCount ?? 0) > 0 &&
      new Date(disclosure.filedAt).getTime() >= cutoff
    )
    .flatMap((disclosure) => disclosure.reportingOwners ?? []));
  return sellers.size;
}

/** Fetches one SEC resource while serializing and spacing requests.
 * @param {string} url SEC resource URL.
 * @return {Promise<string>} Response content.
 */
async function fetchSecText(url: string): Promise<string> {
  const previousRequest = secRequestQueue;
  let releaseRequest!: () => void;
  secRequestQueue = new Promise<void>((resolve) => {
    releaseRequest = resolve;
  });
  await previousRequest;
  try {
    const userAgent = secUserAgent.value().trim();
    if (!/\S+@\S+\.\S+/.test(userAgent)) {
      throw new Error(
        "SEC_EDGAR_USER_AGENT must include a monitored contact email."
      );
    }
    const minimumSpacingMs = 125;
    const rateLimitRef = db.collection("sec_edgar_control").doc("rate_limit");
    const slotAt = await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(rateLimitRef);
      const now = Date.now();
      const nextAllowedAt =
        snapshot.data()?.nextAllowedAt?.toMillis?.() ?? now;
      const reservedAt = Math.max(now, nextAllowedAt);
      transaction.set(rateLimitRef, {
        nextAllowedAt: admin.firestore.Timestamp.fromMillis(
          reservedAt + minimumSpacingMs
        ),
      });
      return reservedAt;
    });
    const waitMs = Math.max(0, slotAt - Date.now());
    if (waitMs > 0) {
      await new Promise((resolve) => setTimeout(resolve, waitMs));
    }
    const response = await fetch(url, {
      headers: {
        "User-Agent": userAgent,
        "Accept-Encoding": "gzip, deflate",
      },
      timeout: 15000,
    });
    if (!response.ok) {
      throw new Error(`SEC request failed with HTTP ${response.status}`);
    }
    return await response.text();
  } finally {
    releaseRequest();
  }
}

/** Fetches and decodes a SEC JSON resource.
 * @param {string} url SEC JSON URL.
 * @return {Promise<Record<string, any>>} Decoded payload.
 */
async function fetchSecJson(url: string): Promise<Record<string, any>> {
  return JSON.parse(await fetchSecText(url)) as Record<string, any>;
}

/** Loads and memoizes SEC's public ticker-to-CIK mapping.
 * @return {Promise<Map<string, SecCompany>>} Ticker keyed issuer map.
 */
async function getCompanyTickerMap(): Promise<Map<string, SecCompany>> {
  if (!companyTickerPromise) {
    companyTickerPromise = fetchSecJson(
      "https://www.sec.gov/files/company_tickers.json"
    ).then((payload) => {
      const companies = new Map<string, SecCompany>();
      Object.values(payload).forEach((value) => {
        const entry = value as SecCompanyTicker;
        if (entry.ticker && Number.isFinite(entry.cik_str)) {
          companies.set(entry.ticker.toUpperCase(), {
            cik: entry.cik_str,
            name: entry.title,
          });
        }
      });
      return companies;
    }).catch((error) => {
      companyTickerPromise = undefined;
      throw error;
    });
  }
  return companyTickerPromise;
}

/** Selects recent matching filings from SEC submissions data.
 * @param {Record<string, unknown>} recent SEC recent-filings object.
 * @param {string} form SEC filing form.
 * @param {number} limit Maximum number of returned filings.
 * @return {FilingRow[]} Recent filings with primary documents.
 */
function rowsFromSubmissions(
  recent: Record<string, unknown>,
  form: string,
  limit: number
): FilingRow[] {
  const forms = asArray(recent.form as string[]);
  const accessions = asArray(recent.accessionNumber as string[]);
  const filingDates = asArray(recent.filingDate as string[]);
  const documents = asArray(recent.primaryDocument as string[]);
  const descriptions = asArray(recent.primaryDocDescription as string[]);
  return forms
    .map((candidate, index) => ({
      accessionNumber: accessions[index] || "",
      filingDate: filingDates[index] || "",
      form: candidate,
      primaryDocument: documents[index] || "",
      primaryDocDescription: descriptions[index] || "",
    }))
    .filter((row) => row.form === form && row.accessionNumber &&
      row.primaryDocument)
    .slice(0, limit);
}

/** Parses recent Form 4, 8-K, 10-K, and 10-Q issuer submissions.
 * @param {string} symbol Listed-company ticker.
 * @param {SecCompany} company SEC issuer identity.
 * @return {Promise<SecDisclosure[]>} Normalized issuer disclosures.
 */
async function getCompanyDisclosures(
  symbol: string,
  company: SecCompany
): Promise<SecDisclosure[]> {
  const cikPadded = String(company.cik).padStart(10, "0");
  const submissions = await fetchSecJson(
    `https://data.sec.gov/submissions/CIK${cikPadded}.json`
  );
  const recent = asRecord(asRecord(submissions.filings).recent);
  const forms = [
    ...rowsFromSubmissions(recent, "4", 12),
    ...rowsFromSubmissions(recent, "8-K", 12),
    ...rowsFromSubmissions(recent, "10-K", 2),
    ...rowsFromSubmissions(recent, "10-Q", 4),
  ].sort((a, b) => b.filingDate.localeCompare(a.filingDate));
  const results: SecDisclosure[] = [];
  for (const filing of forms) {
    const url = filingUrl(
      company.cik,
      filing.accessionNumber,
      filing.primaryDocument
    );
    const body = await fetchSecText(url);
    if (filing.form === "4") {
      const parsedForm4 = parseForm4Xml(body);
      results.push({
        accessionNumber: filing.accessionNumber,
        form: "4",
        filedAt: filing.filingDate,
        companyName: company.name,
        title: `${parsedForm4.filerName} - Form 4`,
        summary: parsedForm4.summary,
        url,
        symbols: [symbol],
        reportingOwners: parsedForm4.filerNames,
        ...(parsedForm4.officerTitles.length > 0 ?
          { officerTitles: parsedForm4.officerTitles } :
          {}),
        transactionCount: parsedForm4.transactionCount,
        openMarketBuyCount: parsedForm4.openMarketBuyCount,
        openMarketSellCount: parsedForm4.openMarketSellCount,
        netSharesTransacted: parsedForm4.netSharesTransacted,
        netTransactionValue: parsedForm4.netTransactionValue,
      });
    } else if (filing.form === "8-K") {
      const parsed8K = parse8KHtml(body);
      results.push({
        accessionNumber: filing.accessionNumber,
        form: "8-K",
        filedAt: filing.filingDate,
        companyName: company.name,
        title: `${company.name} — Form 8-K`,
        summary: parsed8K.summary,
        url,
        symbols: [symbol],
        itemCodes: parsed8K.itemCodes,
        itemDescriptions: parsed8K.itemDescriptions,
        materialEventSeverity: parsed8K.materialEventSeverity,
      });
    } else if (filing.form === "10-K" || filing.form === "10-Q") {
      const parsedPeriodic = parse10KOr10QHtml(
        body,
        filing.form as "10-K" | "10-Q"
      );
      results.push({
        accessionNumber: filing.accessionNumber,
        form: filing.form as "10-K" | "10-Q",
        filedAt: filing.filingDate,
        companyName: company.name,
        title: `${company.name} — Form ${filing.form}`,
        summary: parsedPeriodic.summary,
        url,
        symbols: [symbol],
        ...(parsedPeriodic.fiscalPeriod ?
          { fiscalPeriod: parsedPeriodic.fiscalPeriod } :
          {}),
        ...(parsedPeriodic.riskHighlights.length > 0 ?
          { riskHighlights: parsedPeriodic.riskHighlights } :
          {}),
        ...(parsedPeriodic.mdaHighlights.length > 0 ?
          { mdaHighlights: parsedPeriodic.mdaHighlights } :
          {}),
      });
    }
  }
  const buyClusterCount = countInsiderBuyCluster(results);
  const sellClusterCount = countInsiderSellCluster(results);
  return results.map((result) => {
    if (result.form !== "4") return result;
    return {
      ...result,
      ...((result.openMarketBuyCount ?? 0) > 0 ?
        { insiderClusterCount: buyClusterCount } :
        {}),
      ...((result.openMarketSellCount ?? 0) > 0 ?
        { insiderSellClusterCount: sellClusterCount } :
        {}),
    };
  });
}

/** Fetches and parses XBRL companyfacts financial statements for an issuer.
 * @param {SecCompany} company SEC issuer identity.
 * @return {Promise<SecFinancialStatementSnapshot | undefined>} Parsed snapshot.
 */
async function getCompanyFinancials(
  company: SecCompany
): Promise<SecFinancialStatementSnapshot | undefined> {
  const cikPadded = String(company.cik).padStart(10, "0");
  try {
    const facts = await fetchSecJson(
      `https://data.sec.gov/api/xbrl/companyfacts/CIK${cikPadded}.json`
    );
    return parseCompanyFactsFinancials(facts);
  } catch (error) {
    logger.warn("SEC XBRL companyfacts unavailable", {
      cik: company.cik,
      error: error instanceof Error ? error.message : String(error),
    });
    return undefined;
  }
}

/** Finds 13F filings that report the requested issuer as a holding.
 * @param {string} symbol Listed-company ticker.
 * @param {SecCompany} company SEC issuer identity.
 * @return {Promise<SecDisclosure[]>} Matching institutional holdings.
 */
async function get13FDisclosures(
  symbol: string,
  company: SecCompany
): Promise<SecDisclosure[]> {
  const query = new URLSearchParams({
    q: `"${company.name}"`,
    forms: "13F-HR",
  });
  const search = await fetchSecJson(
    `https://efts.sec.gov/LATEST/search-index?${query.toString()}`
  );
  const searchHits = Array.isArray(asRecord(search.hits).hits) ?
    asRecord(search.hits).hits as Record<string, any>[] :
    [];
  const disclosures: SecDisclosure[] = [];
  for (const hit of searchHits.slice(0, 8)) {
    const source = asRecord(hit._source);
    const ciks = asArray(source.ciks as string[] | string);
    const cik = Number(String(ciks[0] ?? "").replace(/\D/g, ""));
    const accession = String(source.adsh ?? hit._id ?? "");
    const filingDate = String(source.file_date ?? "");
    if (!Number.isFinite(cik) || !accession || !filingDate) continue;
    const accessionPath = accession.replace(/-/g, "");
    const index = await fetchSecJson(
      `https://www.sec.gov/Archives/edgar/data/${cik}/${accessionPath}/index.json`
    );
    const directoryItems = asArray(asRecord(index.directory).item)
      .map((item) => String(asRecord(item).name ?? item));
    const infoTableFile = directoryItems.find((name) =>
      /infotable.*\.xml$/i.test(name)
    );
    if (!infoTableFile) continue;
    const holdings = parse13FXml(await fetchSecText(
      `https://www.sec.gov/Archives/edgar/data/${cik}/${accessionPath}/${encodeURIComponent(infoTableFile)}`
    ));
    const matchedHoldings = holdings.filter((holding) =>
      namesReferToSameCompany(holding.issuerName, company.name)
    );
    if (matchedHoldings.length === 0) continue;
    disclosures.push({
      accessionNumber: accession,
      form: "13F-HR",
      filedAt: filingDate,
      companyName: company.name,
      title: `${String(
        asArray(source.display_names as string[] | string)[0] ?? "Institution"
      )} - 13F`,
      summary: `Institutional holding reported for ${company.name}`,
      url: `https://www.sec.gov/Archives/edgar/data/${cik}/${accessionPath}/`,
      symbols: [symbol],
      holdings: matchedHoldings,
    });
  }
  return disclosures;
}

/** Retrieves supported recent disclosures and XBRL financials for an issuer.
 * @param {string} symbol Ticker symbol.
 * @return {Promise<Object>} Sorted disclosure records and financial statement.
 */
async function fetchDisclosuresForSymbol(
  symbol: string
): Promise<{
  disclosures: SecDisclosure[];
  financials?: SecFinancialStatementSnapshot;
}> {
  const companies = await getCompanyTickerMap();
  const company = companies.get(symbol);
  if (!company) {
    throw new HttpsError(
      "not-found",
      `SEC company mapping not found for ${symbol}.`
    );
  }
  const [companyDisclosures, institutionalDisclosures, financials] =
    await Promise.all([
      getCompanyDisclosures(symbol, company),
      get13FDisclosures(symbol, company),
      getCompanyFinancials(company),
    ]);
  const disclosures = [...companyDisclosures, ...institutionalDisclosures]
    .sort((a, b) => b.filedAt.localeCompare(a.filedAt));
  return {
    disclosures,
    ...(financials ? { financials } : {}),
  };
}

/** Checks whether the caller has a nonzero position in a symbol.
 * @param {Record<string, any>[]} positionRows User position documents.
 * @param {string} symbol Target ticker symbol.
 * @return {boolean} Whether a matching position exists.
 */
export function hasPortfolioOverlap(
  positionRows: Record<string, any>[],
  symbol: string
): boolean {
  const normalized = symbol.toUpperCase();
  return positionRows.some((position) => {
    if (Number(position.quantity ?? position.qty ?? 0) === 0) return false;
    const instrument = asRecord(
      position.instrument_obj ?? position.instrumentObj ?? position.instrument
    );
    return String(instrument.symbol ?? position.symbol ?? "")
      .toUpperCase() === normalized;
  });
}

/** Resolves symbols for the authenticated user's nonzero stock positions.
 * @param {string} uid Firebase Authentication user id.
 * @return {Promise<Set<string>>} Symbols held in the user's portfolio.
 */
async function getUserPortfolioSymbols(uid: string): Promise<Set<string>> {
  const snapshot = await db
    .collection("user")
    .doc(uid)
    .collection("instrumentPosition")
    .get();
  const symbols = new Set<string>();
  const instrumentReferences: Array<{
    reference: FirebaseFirestore.DocumentReference;
  }> = [];
  for (const positionDocument of snapshot.docs) {
    const position = positionDocument.data();
    if (Number(position.quantity ?? position.qty ?? 0) === 0) continue;
    const embeddedInstrument = asRecord(
      position.instrument_obj ?? position.instrumentObj ?? position.instrument
    );
    const symbol = String(embeddedInstrument.symbol ?? position.symbol ?? "")
      .toUpperCase();
    if (symbol) {
      symbols.add(symbol);
      continue;
    }
    const instrumentUrl = String(position.instrument ?? "");
    const instrumentId = instrumentUrl.split("/").filter(Boolean).pop();
    if (instrumentId) {
      instrumentReferences.push({
        reference: db.collection("instrument").doc(instrumentId),
      });
    }
  }
  if (instrumentReferences.length > 0) {
    const instruments = await db.getAll(
      ...instrumentReferences.map((entry) => entry.reference)
    );
    instruments.forEach((instrument) => {
      const symbol = String(instrument.data()?.symbol ?? "").toUpperCase();
      if (symbol) symbols.add(symbol);
    });
  }
  return symbols;
}

/** Refreshes a bounded set of recently requested symbols from SEC EDGAR.
 * @return {Object} Scheduled Firebase Function.
 */
export const refreshTrackedSecDisclosures = onSchedule(
  {
    schedule: "every 60 minutes",
    timeoutSeconds: 540,
    memory: "1GiB",
  },
  async () => {
    const tracked = await db.collection("sec_tracked_symbols")
      .orderBy("lastRequestedAt", "desc")
      .limit(10)
      .get();
    for (const trackedSymbol of tracked.docs) {
      const symbol = trackedSymbol.id;
      try {
        const { disclosures, financials } =
          await fetchDisclosuresForSymbol(symbol);
        const researchBrief = buildSecFilingResearchBrief(
          symbol,
          disclosures,
          financials
        );
        await db.collection("sec_disclosures").doc(symbol).set({
          disclosures,
          ...(financials ? { financials } : {}),
          researchBrief,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        await trackedSymbol.ref.set({
          lastPolledAt: admin.firestore.FieldValue.serverTimestamp(),
          lastError: admin.firestore.FieldValue.delete(),
        }, { merge: true });
      } catch (error) {
        logger.error("Scheduled SEC filing refresh failed", { symbol, error });
        await trackedSymbol.ref.set({
          lastPolledAt: admin.firestore.FieldValue.serverTimestamp(),
          lastError: error instanceof Error ? error.message : String(error),
        }, { merge: true });
      }
    }
  }
);

/** Returns cached SEC disclosures and whether the symbol is held by the caller.
 * @return {Object} Callable Firebase Function.
 */
export const getSecDisclosures = onCall(
  { cors: true, timeoutSeconds: 180, memory: "512MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Sign-in is required to view SEC disclosures."
      );
    }
    const symbol = String(request.data?.symbol ?? "").trim().toUpperCase();
    if (!/^[A-Z][A-Z0-9.-]{0,9}$/.test(symbol)) {
      throw new HttpsError(
        "invalid-argument",
        "A valid stock symbol is required."
      );
    }

    const cacheRef = db.collection("sec_disclosures").doc(symbol);
    try {
      const cacheSnapshot = await cacheRef.get();
      let disclosures: SecDisclosure[];
      let financials: SecFinancialStatementSnapshot | undefined;
      let researchBrief: SecFilingResearchBrief;
      let updatedAt: string;
      const cacheData = cacheSnapshot.data();
      const cacheTime = cacheData?.updatedAt?.toMillis?.() ?? 0;
      if (cacheSnapshot.exists && Date.now() - cacheTime < cacheTtlMs) {
        disclosures = cacheData?.disclosures as SecDisclosure[] ?? [];
        financials = cacheData?.financials as
          SecFinancialStatementSnapshot | undefined;
        researchBrief = (cacheData?.researchBrief as
          SecFilingResearchBrief | undefined) ??
          buildSecFilingResearchBrief(symbol, disclosures, financials);
        updatedAt = cacheData?.updatedAt?.toDate?.().toISOString() ??
          new Date().toISOString();
      } else {
        const fetched = await fetchDisclosuresForSymbol(symbol);
        disclosures = fetched.disclosures;
        financials = fetched.financials;
        researchBrief = buildSecFilingResearchBrief(
          symbol,
          disclosures,
          financials
        );
        await cacheRef.set({
          disclosures,
          ...(financials ? { financials } : {}),
          researchBrief,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        updatedAt = new Date().toISOString();
      }

      const portfolioSymbols = await getUserPortfolioSymbols(request.auth.uid);
      await db.collection("sec_tracked_symbols").doc(symbol).set({
        lastRequestedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      return {
        symbol,
        disclosures,
        ...(financials ? { financials } : {}),
        researchBrief,
        portfolioOverlap: portfolioSymbols.has(symbol),
        updatedAt,
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      logger.error("Failed to retrieve SEC disclosures", { symbol, error });
      throw new HttpsError("internal", "Failed to retrieve SEC disclosures.");
    }
  }
);

/** Generates an automated 10-K/10-Q & EDGAR filing research brief for a symbol.
 * @return {Object} Callable Firebase Function.
 */
export const analyzeSecFiling = onCall(
  { cors: true, timeoutSeconds: 120, memory: "512MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Sign-in is required to analyze SEC filings."
      );
    }
    const symbol = String(request.data?.symbol ?? "").trim().toUpperCase();
    if (!/^[A-Z][A-Z0-9.-]{0,9}$/.test(symbol)) {
      throw new HttpsError(
        "invalid-argument",
        "A valid stock symbol is required."
      );
    }
    const rawQuestion = request.data?.question;
    const question = typeof rawQuestion === "string" ?
      rawQuestion.trim().slice(0, 500) :
      undefined;

    const cacheRef = db.collection("sec_disclosures").doc(symbol);
    try {
      const cacheSnapshot = await cacheRef.get();
      let disclosures: SecDisclosure[];
      let financials: SecFinancialStatementSnapshot | undefined;
      const cacheData = cacheSnapshot.data();
      const cacheTime = cacheData?.updatedAt?.toMillis?.() ?? 0;
      if (cacheSnapshot.exists && Date.now() - cacheTime < cacheTtlMs) {
        disclosures = cacheData?.disclosures as SecDisclosure[] ?? [];
        financials = cacheData?.financials as
          SecFinancialStatementSnapshot | undefined;
      } else {
        const fetched = await fetchDisclosuresForSymbol(symbol);
        disclosures = fetched.disclosures;
        financials = fetched.financials;
        await cacheRef.set({
          disclosures,
          ...(financials ? { financials } : {}),
          researchBrief: buildSecFilingResearchBrief(
            symbol,
            disclosures,
            financials
          ),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      return buildSecFilingResearchBrief(
        symbol,
        disclosures,
        financials,
        question
      );
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      logger.error("Failed to analyze SEC filings", { symbol, error });
      throw new HttpsError("internal", "Failed to analyze SEC filings.");
    }
  }
);
