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

export type SecFilingType = "4" | "8-K" | "13F-HR";

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
  transactionCount?: number;
  openMarketBuyCount?: number;
  insiderClusterCount?: number;
  itemCodes?: string[];
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

/** Parses ownership and transaction data from an SEC Form 4 XML document.
 * @param {string} xml Filing document content.
 * @return {Object} Insider name, transaction counts, and summary.
 */
export function parseForm4Xml(xml: string): {
  filerName: string;
  filerNames: string[];
  transactionCount: number;
  openMarketBuyCount: number;
  summary: string;
} {
  const document = asRecord(xmlParser.parse(xml).ownershipDocument);
  const owners = asArray(asRecord(document.reportingOwner));
  const names = owners
    .map((owner) => text(asRecord(owner.reportingOwnerId).rptOwnerName))
    .filter(Boolean);
  const nonDerivative = asArray(
    asRecord(document.nonDerivativeTable).nonDerivativeTransaction
  );
  const derivative = asArray(
    asRecord(document.derivativeTable).derivativeTransaction
  );
  const transactions = [...nonDerivative, ...derivative];
  const openMarketBuyCount = transactions.filter((transaction) =>
    text(asRecord(transaction.transactionCoding).transactionCode) === "P"
  ).length;
  const filerName = names.join(", ") || "Company insider";
  const summary = openMarketBuyCount > 1 ?
    `${openMarketBuyCount} open-market insider purchases reported` :
    (openMarketBuyCount === 1 ?
      "Open-market insider purchase reported" :
      `${transactions.length} insider transaction` +
      `${transactions.length === 1 ? "" : "s"} reported`);

  return {
    filerName,
    filerNames: names,
    transactionCount: transactions.length,
    openMarketBuyCount,
    summary,
  };
}

/** Extracts material event item numbers from an 8-K filing document.
 * @param {string} html Filing document content.
 * @return {Object} Deduplicated item numbers and summary.
 */
export function parse8KHtml(html: string): {
  itemCodes: string[];
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
  return {
    itemCodes,
    summary: itemCodes.length > 0 ?
      `Material event disclosure: Items ${itemCodes.join(", ")}` :
      "Material event disclosure filed",
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

/** Parses recent Form 4 and 8-K issuer submissions.
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
  ].sort((a, b) => b.filingDate.localeCompare(a.filingDate));
  const results: SecDisclosure[] = [];
  for (const filing of forms) {
    const url = filingUrl(
      company.cik,
      filing.accessionNumber,
      filing.primaryDocument
    );
    const body = await fetchSecText(url);
    const isForm4 = filing.form === "4";
    const parsedForm4 = isForm4 ? parseForm4Xml(body) : undefined;
    const parsed8K = isForm4 ? undefined : parse8KHtml(body);
    results.push({
      accessionNumber: filing.accessionNumber,
      form: filing.form as "4" | "8-K",
      filedAt: filing.filingDate,
      companyName: company.name,
      title: isForm4 ?
        `${parsedForm4!.filerName} - Form 4` :
        `${company.name} — Form 8-K`,
      summary: parsedForm4?.summary ?? parsed8K!.summary,
      url,
      symbols: [symbol],
      ...(isForm4 ? {
        reportingOwners: parsedForm4!.filerNames,
        transactionCount: parsedForm4!.transactionCount,
        openMarketBuyCount: parsedForm4!.openMarketBuyCount,
      } : { itemCodes: parsed8K!.itemCodes }),
    });
  }
  const clusterCount = countInsiderBuyCluster(results);
  return results.map((result) =>
    result.form === "4" && (result.openMarketBuyCount ?? 0) > 0 ?
      { ...result, insiderClusterCount: clusterCount } :
      result
  );
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

/** Retrieves all supported recent disclosures for an issuer.
 * @param {string} symbol Ticker symbol.
 * @return {Promise<SecDisclosure[]>} Sorted disclosure records.
 */
async function fetchDisclosuresForSymbol(
  symbol: string
): Promise<SecDisclosure[]> {
  const companies = await getCompanyTickerMap();
  const company = companies.get(symbol);
  if (!company) {
    throw new HttpsError(
      "not-found",
      `SEC company mapping not found for ${symbol}.`
    );
  }
  const [companyDisclosures, institutionalDisclosures] = await Promise.all([
    getCompanyDisclosures(symbol, company),
    get13FDisclosures(symbol, company),
  ]);
  return [...companyDisclosures, ...institutionalDisclosures]
    .sort((a, b) => b.filedAt.localeCompare(a.filedAt));
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
        const disclosures = await fetchDisclosuresForSymbol(symbol);
        await db.collection("sec_disclosures").doc(symbol).set({
          disclosures,
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
      let updatedAt: string;
      const cacheData = cacheSnapshot.data();
      const cacheTime = cacheData?.updatedAt?.toMillis?.() ?? 0;
      if (cacheSnapshot.exists && Date.now() - cacheTime < cacheTtlMs) {
        disclosures = cacheData?.disclosures as SecDisclosure[] ?? [];
        updatedAt = cacheData?.updatedAt?.toDate?.().toISOString() ??
          new Date().toISOString();
      } else {
        disclosures = await fetchDisclosuresForSymbol(symbol);
        await cacheRef.set({
          disclosures,
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
