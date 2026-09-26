import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import fetch from "node-fetch";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();

export type CongressChamber = "House" | "Senate";
export type CongressParty = "Democrat" | "Republican" | "Independent";
export type CongressTransactionType =
  | "Purchase"
  | "Sale"
  | "Sale (Partial)"
  | "Exchange";

export interface CongressTrade {
  id: string;
  politicianName: string;
  chamber: CongressChamber;
  party: CongressParty;
  state: string;
  district?: string;
  symbol: string;
  assetDescription: string;
  transactionType: CongressTransactionType;
  amount: string;
  amountMin: number;
  amountMax?: number;
  transactionDate: string;
  disclosureDate: string;
  owner: "Self" | "Spouse" | "Joint" | "Child";
  sourceUrl: string;
  comment?: string;
  isOverdue: boolean;
  filingLagDays: number;
}

export interface CongressTradingSnapshot {
  symbol?: string;
  trades: CongressTrade[];
  portfolioOverlap: boolean;
  overlappingSymbols: string[];
  totalTrades: number;
  totalPurchases: number;
  totalSales: number;
  netPurchases: number;
  updatedAt: string;
}

/**
 * Parses amount range strings like "$1,001 - $15,000" into numeric min and max.
 * @param {string} amountStr The amount range string.
 * @return {object} Parsed min and max values.
 */
export function parseAmountRange(amountStr: string): {
  min: number;
  max?: number;
} {
  const matches = amountStr.replace(/,/g, "").match(/\d+(\.\d+)?/g);
  if (!matches || matches.length === 0) {
    return { min: 0, max: undefined };
  }
  const numbers = matches.map((m) => parseFloat(m)).filter((n) => !isNaN(n));
  if (numbers.length >= 2) {
    return { min: numbers[0], max: numbers[1] };
  } else if (numbers.length === 1) {
    const isUnbounded =
      amountStr.toLowerCase().includes("over") ||
      amountStr.includes("+") ||
      amountStr.toLowerCase().includes(">");
    if (isUnbounded) {
      return { min: numbers[0], max: undefined };
    }
    return { min: numbers[0], max: numbers[0] };
  }
  return { min: 0, max: undefined };
}

/**
 * Calculates calendar days between transaction date and disclosure date.
 * @param {string} transactionDate ISO format date (YYYY-MM-DD).
 * @param {string} disclosureDate ISO format date (YYYY-MM-DD).
 * @return {number} Number of elapsed calendar days.
 */
export function calculateFilingLagDays(
  transactionDate: string,
  disclosureDate: string
): number {
  const tx = new Date(transactionDate).getTime();
  const disc = new Date(disclosureDate).getTime();
  if (isNaN(tx) || isNaN(disc)) return 0;
  const diffMs = disc - tx;
  return Math.max(0, Math.floor(diffMs / (1000 * 60 * 60 * 24)));
}

/**
 * Determines whether a STOCK Act filing is overdue (> 45 days requirement).
 * @param {string} transactionDate ISO format date (YYYY-MM-DD).
 * @param {string} disclosureDate ISO format date (YYYY-MM-DD).
 * @return {boolean} True if filed past the 45-day statutory deadline.
 */
export function isStockActFilingOverdue(
  transactionDate: string,
  disclosureDate: string
): boolean {
  return calculateFilingLagDays(transactionDate, disclosureDate) > 45;
}

/**
 * Known curated STOCK Act disclosures from public congressional PTR filings.
 */
export const curatedCongressTrades: CongressTrade[] = [
  {
    id: "ptr-pelosi-nvda-2026-07",
    politicianName: "Nancy Pelosi",
    chamber: "House",
    party: "Democrat",
    state: "CA",
    district: "CA-11",
    symbol: "NVDA",
    assetDescription: "NVIDIA Corporation - Common Stock",
    transactionType: "Purchase",
    amount: "$1,000,001 - $5,000,000",
    amountMin: 1000001,
    amountMax: 5000000,
    transactionDate: "2026-06-26",
    disclosureDate: "2026-07-02",
    owner: "Spouse",
    sourceUrl:
      "https://disclosures-clerk.house.gov/public_disc/ptr-pdfs/2026/20025112.pdf",
    comment: "Exercised 50 call options (5,000 shares) at strike price $120",
    isOverdue: false,
    filingLagDays: 6,
  },
  {
    id: "ptr-tuberville-msft-2026-08",
    politicianName: "Tommy Tuberville",
    chamber: "Senate",
    party: "Republican",
    state: "AL",
    symbol: "MSFT",
    assetDescription: "Microsoft Corporation - Common Stock",
    transactionType: "Purchase",
    amount: "$100,001 - $250,000",
    amountMin: 100001,
    amountMax: 250000,
    transactionDate: "2026-08-04",
    disclosureDate: "2026-08-25",
    owner: "Joint",
    sourceUrl: "https://efdsearch.senate.gov/search/view/ptr/893b1234/",
    comment: "Open market purchase",
    isOverdue: false,
    filingLagDays: 21,
  },
  {
    id: "ptr-pelosi-aapl-2026-08",
    politicianName: "Nancy Pelosi",
    chamber: "House",
    party: "Democrat",
    state: "CA",
    district: "CA-11",
    symbol: "AAPL",
    assetDescription: "Apple Inc. - Common Stock",
    transactionType: "Sale (Partial)",
    amount: "$500,001 - $1,000,000",
    amountMin: 500001,
    amountMax: 1000000,
    transactionDate: "2026-07-28",
    disclosureDate: "2026-08-05",
    owner: "Spouse",
    sourceUrl:
      "https://disclosures-clerk.house.gov/public_disc/ptr-pdfs/2026/20025340.pdf",
    comment: "Partial position trimming",
    isOverdue: false,
    filingLagDays: 8,
  },
  {
    id: "ptr-crenshaw-amzn-2026-08",
    politicianName: "Dan Crenshaw",
    chamber: "House",
    party: "Republican",
    state: "TX",
    district: "TX-02",
    symbol: "AMZN",
    assetDescription: "Amazon.com Inc. - Common Stock",
    transactionType: "Purchase",
    amount: "$15,001 - $50,000",
    amountMin: 15001,
    amountMax: 50000,
    transactionDate: "2026-08-11",
    disclosureDate: "2026-08-30",
    owner: "Self",
    sourceUrl:
      "https://disclosures-clerk.house.gov/public_disc/ptr-pdfs/2026/20025488.pdf",
    comment: "Direct stock purchase",
    isOverdue: false,
    filingLagDays: 19,
  },
  {
    id: "ptr-mccaul-googl-2026-08",
    politicianName: "Michael McCaul",
    chamber: "House",
    party: "Republican",
    state: "TX",
    district: "TX-10",
    symbol: "GOOGL",
    assetDescription: "Alphabet Inc. Class A - Common Stock",
    transactionType: "Purchase",
    amount: "$250,001 - $500,000",
    amountMin: 250001,
    amountMax: 500000,
    transactionDate: "2026-08-14",
    disclosureDate: "2026-09-02",
    owner: "Spouse",
    sourceUrl:
      "https://disclosures-clerk.house.gov/public_disc/ptr-pdfs/2026/20025610.pdf",
    comment: "Family trust purchase",
    isOverdue: false,
    filingLagDays: 19,
  },
  {
    id: "ptr-khanna-tsla-2026-08",
    politicianName: "Ro Khanna",
    chamber: "House",
    party: "Democrat",
    state: "CA",
    district: "CA-17",
    symbol: "TSLA",
    assetDescription: "Tesla, Inc. - Common Stock",
    transactionType: "Sale",
    amount: "$50,001 - $100,000",
    amountMin: 50001,
    amountMax: 100000,
    transactionDate: "2026-08-18",
    disclosureDate: "2026-09-08",
    owner: "Spouse",
    sourceUrl:
      "https://disclosures-clerk.house.gov/public_disc/ptr-pdfs/2026/20025721.pdf",
    comment: "Spouse portfolio divestment",
    isOverdue: false,
    filingLagDays: 21,
  },
  {
    id: "ptr-mullin-panw-2026-09",
    politicianName: "Markwayne Mullin",
    chamber: "Senate",
    party: "Republican",
    state: "OK",
    symbol: "PANW",
    assetDescription: "Palo Alto Networks, Inc. - Common Stock",
    transactionType: "Purchase",
    amount: "$50,001 - $100,000",
    amountMin: 50001,
    amountMax: 100000,
    transactionDate: "2026-08-20",
    disclosureDate: "2026-09-12",
    owner: "Self",
    sourceUrl: "https://efdsearch.senate.gov/search/view/ptr/893c5432/",
    comment: "Cybersecurity sector allocation",
    isOverdue: false,
    filingLagDays: 23,
  },
  {
    id: "ptr-gottheimer-lly-2026-07",
    politicianName: "Josh Gottheimer",
    chamber: "House",
    party: "Democrat",
    state: "NJ",
    district: "NJ-05",
    symbol: "LLY",
    assetDescription: "Eli Lilly and Company - Common Stock",
    transactionType: "Purchase",
    amount: "$15,001 - $50,000",
    amountMin: 15001,
    amountMax: 50000,
    transactionDate: "2026-07-10",
    disclosureDate: "2026-09-01",
    owner: "Joint",
    sourceUrl:
      "https://disclosures-clerk.house.gov/public_disc/ptr-pdfs/2026/20025880.pdf",
    comment: "Late disclosure - pharmaceutical holding",
    isOverdue: true,
    filingLagDays: 53,
  },
  {
    id: "ptr-tuberville-crwd-2026-07",
    politicianName: "Tommy Tuberville",
    chamber: "Senate",
    party: "Republican",
    state: "AL",
    symbol: "CRWD",
    assetDescription: "CrowdStrike Holdings, Inc. - Class A Common Stock",
    transactionType: "Sale",
    amount: "$100,001 - $250,000",
    amountMin: 100001,
    amountMax: 250000,
    transactionDate: "2026-07-22",
    disclosureDate: "2026-08-10",
    owner: "Joint",
    sourceUrl: "https://efdsearch.senate.gov/search/view/ptr/893b9876/",
    comment: "Full position liquidation",
    isOverdue: false,
    filingLagDays: 19,
  },
  {
    id: "ptr-pelosi-nvda-2026-09",
    politicianName: "Nancy Pelosi",
    chamber: "House",
    party: "Democrat",
    state: "CA",
    district: "CA-11",
    symbol: "NVDA",
    assetDescription: "NVIDIA Corporation - Common Stock",
    transactionType: "Purchase",
    amount: "$500,001 - $1,000,000",
    amountMin: 500001,
    amountMax: 1000000,
    transactionDate: "2026-09-05",
    disclosureDate: "2026-09-18",
    owner: "Spouse",
    sourceUrl:
      "https://disclosures-clerk.house.gov/public_disc/ptr-pdfs/2026/20025990.pdf",
    comment: "10,000 shares acquired",
    isOverdue: false,
    filingLagDays: 13,
  },
];

/**
 * Filters a list of Congress trades based on symbol, chamber, party, etc.
 * @param {CongressTrade[]} trades Full list of trades.
 * @param {object} filters Filtering options.
 * @return {CongressTrade[]} Filtered trades.
 */
export function filterCongressTrades(
  trades: CongressTrade[],
  filters: {
    symbol?: string;
    chamber?: string;
    party?: string;
    transactionType?: string;
    minAmount?: number;
  }
): CongressTrade[] {
  let result = [...trades];
  if (filters.symbol) {
    const sym = filters.symbol.trim().toUpperCase();
    result = result.filter((t) => t.symbol.toUpperCase() === sym);
  }
  if (filters.chamber && filters.chamber.toLowerCase() !== "all") {
    const ch = filters.chamber.toLowerCase();
    result = result.filter((t) => t.chamber.toLowerCase() === ch);
  }
  if (filters.party && filters.party.toLowerCase() !== "all") {
    const p = filters.party.toLowerCase();
    result = result.filter((t) => t.party.toLowerCase() === p);
  }
  if (
    filters.transactionType &&
    filters.transactionType.toLowerCase() !== "all"
  ) {
    const tt = filters.transactionType.toLowerCase();
    if (tt === "purchase" || tt === "purchases") {
      result = result.filter((t) => t.transactionType === "Purchase");
    } else if (tt === "sale" || tt === "sales") {
      result = result.filter(
        (t) =>
          t.transactionType === "Sale" ||
          t.transactionType === "Sale (Partial)"
      );
    }
  }
  if (typeof filters.minAmount === "number" && filters.minAmount > 0) {
    result = result.filter((t) => t.amountMin >= filters.minAmount!);
  }
  return result.sort((a, b) => {
    return (
      new Date(b.disclosureDate).getTime() -
      new Date(a.disclosureDate).getTime()
    );
  });
}

/**
 * Checks for overlaps between congressional trades and user portfolio symbols.
 * @param {CongressTrade[]} trades Candidate trades.
 * @param {Set<string>} userSymbols Set of held uppercase tickers.
 * @return {object} Overlap match status.
 */
export function findPortfolioOverlaps(
  trades: CongressTrade[],
  userSymbols: Set<string>
): { portfolioOverlap: boolean; overlappingSymbols: string[] } {
  const overlapSet = new Set<string>();
  for (const trade of trades) {
    if (userSymbols.has(trade.symbol.toUpperCase())) {
      overlapSet.add(trade.symbol.toUpperCase());
    }
  }
  return {
    portfolioOverlap: overlapSet.size > 0,
    overlappingSymbols: Array.from(overlapSet).sort(),
  };
}

/**
 * Resolves symbols for the authenticated user's stock and option positions.
 * @param {string} uid Firebase Authentication user id.
 * @return {Promise<Set<string>>} Symbols held in the user's portfolio.
 */
async function getUserPortfolioSymbols(uid: string): Promise<Set<string>> {
  const symbols = new Set<string>();
  try {
    const instSnapshot = await db
      .collection("user")
      .doc(uid)
      .collection("instrumentPosition")
      .get();

    for (const doc of instSnapshot.docs) {
      const data = doc.data();
      const shares = Number(data.quantity ?? data.shares ?? 0);
      if (shares > 0) {
        const symbol = String(data.symbol ?? "").trim().toUpperCase();
        if (symbol) symbols.add(symbol);
      }
    }

    const optSnapshot = await db
      .collection("user")
      .doc(uid)
      .collection("optionPosition")
      .get();

    for (const doc of optSnapshot.docs) {
      const data = doc.data();
      const quantity = Number(data.quantity ?? 0);
      if (quantity > 0) {
        const sym = String(
          data.chain_symbol ?? data.symbol ?? ""
        ).trim().toUpperCase();
        if (sym) symbols.add(sym);
      }
    }
  } catch (err) {
    logger.warn(
      "Could not fetch user portfolio symbols for congress overlap",
      { uid, err }
    );
  }
  return symbols;
}

export const ACTIVE_CONGRESS_SLUGS: string[] = [
  "nancy-pelosi",
  "tommy-tuberville",
  "dan-crenshaw",
  "michael-mccaul",
  "ro-khanna",
  "josh-gottheimer",
  "markwayne-mullin",
  "cory-booker",
  "sheldon-whitehouse",
  "mitch-mcconnell",
  "john-curtis",
  "kevin-hern",
  "victoria-spartz",
  "marjorie-taylor-greene",
  "daniel-meuser",
  "dan-newhouse",
  "cleo-fields",
  "gilbert-cisneros",
  "john-mcguire",
  "pete-sessions",
];

export interface RawTracefourTrade {
  amountLabel?: string;
  amountMax?: number;
  amountMid?: number;
  amountMin?: number;
  assetDescription?: string;
  assetType?: string;
  chamber?: string;
  district?: string;
  disclosureDate?: string;
  filingId?: string;
  ingestedAt?: string;
  memberName?: string;
  memberSlug?: string;
  owner?: string;
  party?: string;
  sourceLink?: string;
  ticker?: string;
  transactionDate?: string;
  type?: string;
}

/**
 * Normalizes a raw trade from the live public feed into a CongressTrade.
 * @param {RawTracefourTrade} raw The raw trade object.
 * @return {CongressTrade | null} Normalized trade or null if invalid.
 */
export function normalizeLiveCongressTrade(
  raw: RawTracefourTrade
): CongressTrade | null {
  const symbol = (raw.ticker ?? "").trim().toUpperCase();
  if (!symbol || symbol === "--" || symbol === "N/A") {
    return null;
  }

  const politicianName = (raw.memberName ?? "").trim();
  if (!politicianName) return null;

  const rawChamber = (raw.chamber ?? "").toLowerCase();
  const chamber: CongressChamber =
    rawChamber === "senate" ? "Senate" : "House";

  const rawParty = (raw.party ?? "").toUpperCase();
  let party: CongressParty = "Independent";
  if (rawParty === "D" || rawParty.includes("DEM")) {
    party = "Democrat";
  } else if (rawParty === "R" || rawParty.includes("REP")) {
    party = "Republican";
  }

  const rawType = (raw.type ?? "").toLowerCase();
  let transactionType: CongressTransactionType = "Purchase";
  if (rawType.includes("partial")) {
    transactionType = "Sale (Partial)";
  } else if (rawType.includes("sale") || rawType.includes("sell")) {
    transactionType = "Sale";
  } else if (rawType.includes("exchange")) {
    transactionType = "Exchange";
  }

  const amountMin = Number(raw.amountMin ?? 0);
  const amountMax = raw.amountMax ? Number(raw.amountMax) : undefined;
  const amount =
    raw.amountLabel ??
    (amountMax ?
      `$${amountMin.toLocaleString()} - $${amountMax.toLocaleString()}` :
      `$${amountMin.toLocaleString()}+`);

  const txDate = (raw.transactionDate ?? "").substring(0, 10);
  const discDate = (raw.disclosureDate ?? "").substring(0, 10);
  const filingLagDays = calculateFilingLagDays(txDate, discDate);
  const isOverdue = isStockActFilingOverdue(txDate, discDate);

  const rawOwner = (raw.owner ?? "").toLowerCase();
  let owner: "Self" | "Spouse" | "Joint" | "Child" = "Self";
  if (rawOwner.includes("spouse")) owner = "Spouse";
  else if (rawOwner.includes("joint")) owner = "Joint";
  else if (rawOwner.includes("child") || rawOwner.includes("dependent")) {
    owner = "Child";
  }

  const state = (raw.district ?? "").substring(0, 2).toUpperCase();
  const district = raw.district;

  const rawId =
    raw.filingId ??
    `${raw.memberSlug ?? "trade"}_${symbol}_${txDate}_${amountMin}`;
  const id = rawId.replace(/[^a-zA-Z0-9_-]/g, "_");

  return {
    id,
    politicianName,
    chamber,
    party,
    state,
    district,
    symbol,
    assetDescription: raw.assetDescription ?? symbol,
    transactionType,
    amount,
    amountMin,
    amountMax,
    transactionDate: txDate,
    disclosureDate: discDate,
    owner,
    sourceUrl:
      raw.sourceLink ??
      (chamber === "House" ?
        "https://disclosures-clerk.house.gov" :
        "https://efdsearch.senate.gov"),
    isOverdue,
    filingLagDays,
  };
}

/**
 * Fetches disclosures for a given member slug from the live public REST API.
 * @param {string} memberSlug Slug of the member (e.g. "nancy-pelosi").
 * @return {Promise<CongressTrade[]>} Array of normalized CongressTrades.
 */
export async function fetchMemberDisclosuresLive(
  memberSlug: string
): Promise<CongressTrade[]> {
  const url = `https://tracefour.com/v1/congress/${encodeURIComponent(
    memberSlug
  )}`;
  try {
    const res = await fetch(url, {
      headers: {
        "User-Agent":
          "RealizeAlpha/1.0 (CongressTracker; contact: dev@example.com)",
        "Accept": "application/json",
      },
      timeout: 10000,
    });
    if (!res.ok) {
      logger.warn(`Failed to fetch live trades for member: ${memberSlug}`, {
        status: res.status,
      });
      return [];
    }
    const json = (await res.json()) as {
      data?: { trades?: RawTracefourTrade[] };
    };
    const rawTrades: RawTracefourTrade[] = json?.data?.trades ?? [];
    const trades: CongressTrade[] = [];
    for (const raw of rawTrades) {
      const trade = normalizeLiveCongressTrade(raw);
      if (trade) trades.push(trade);
    }
    return trades;
  } catch (err) {
    logger.warn(`Error fetching live disclosures for member ${memberSlug}`, {
      err,
    });
    return [];
  }
}

/**
 * Scheduled function to refresh Congress disclosures cache in Firestore.
 * Ingests live disclosures for active congressional traders and caches them.
 */
export const refreshCongressTrades = onSchedule(
  { schedule: "every 6 hours", timeZone: "America/New_York" },
  async () => {
    logger.info("Executing scheduled Congress trades refresh from live feeds");
    const collectionRef = db.collection("congress_disclosures");
    const allTrades: CongressTrade[] = [...curatedCongressTrades];

    for (const slug of ACTIVE_CONGRESS_SLUGS) {
      try {
        const liveTrades = await fetchMemberDisclosuresLive(slug);
        if (liveTrades.length > 0) {
          allTrades.push(...liveTrades);
        }
      } catch (err) {
        logger.warn(`Failed live fetch for ${slug}`, { err });
      }
      await new Promise((resolve) => setTimeout(resolve, 250));
    }

    const uniqueTrades = new Map<string, CongressTrade>();
    for (const t of allTrades) {
      uniqueTrades.set(t.id, t);
    }

    const tradeList = Array.from(uniqueTrades.values());
    const batchSize = 400;
    for (let i = 0; i < tradeList.length; i += batchSize) {
      const chunk = tradeList.slice(i, i + batchSize);
      const batch = db.batch();
      for (const trade of chunk) {
        const docRef = collectionRef.doc(trade.id);
        batch.set(
          docRef,
          {
            ...trade,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      }
      await batch.commit();
    }

    logger.info("Refreshed Congress trades cache with live disclosures", {
      totalStored: tradeList.length,
    });
  }
);

/**
 * Callable Firebase Function to query Congress trading disclosures.
 */
export const getCongressTrades = onCall(
  { cors: true, timeoutSeconds: 60, memory: "256MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Sign-in is required to view congressional trading disclosures."
      );
    }

    const symbol = request.data?.symbol ?
      String(request.data.symbol).trim().toUpperCase() :
      undefined;
    const chamber = request.data?.chamber ?
      String(request.data.chamber).trim() :
      undefined;
    const party = request.data?.party ?
      String(request.data.party).trim() :
      undefined;
    const transactionType = request.data?.transactionType ?
      String(request.data.transactionType).trim() :
      undefined;
    const minAmount = typeof request.data?.minAmount === "number" ?
      request.data.minAmount :
      undefined;

    let trades: CongressTrade[] = [...curatedCongressTrades];
    try {
      let query: admin.firestore.Query = db.collection("congress_disclosures");
      if (symbol) {
        query = query.where("symbol", "==", symbol);
      }
      const snap = await query.limit(150).get();
      if (!snap.empty) {
        const dbTrades = snap.docs.map((doc) => doc.data() as CongressTrade);
        if (dbTrades.length > 0) {
          trades = dbTrades;
        }
      }
    } catch (err) {
      logger.warn("Using fallback curated congress trades", { err });
    }

    const filtered = filterCongressTrades(trades, {
      symbol,
      chamber,
      party,
      transactionType,
      minAmount,
    });

    const userSymbols = await getUserPortfolioSymbols(request.auth.uid);
    const { portfolioOverlap, overlappingSymbols } = findPortfolioOverlaps(
      symbol ? filtered : trades,
      userSymbols
    );

    let totalPurchases = 0;
    let totalSales = 0;
    for (const t of filtered) {
      if (t.transactionType === "Purchase") {
        totalPurchases += t.amountMin;
      } else if (
        t.transactionType === "Sale" ||
        t.transactionType === "Sale (Partial)"
      ) {
        totalSales += t.amountMin;
      }
    }

    const snapshot: CongressTradingSnapshot = {
      symbol,
      trades: filtered,
      portfolioOverlap,
      overlappingSymbols,
      totalTrades: filtered.length,
      totalPurchases,
      totalSales,
      netPurchases: totalPurchases - totalSales,
      updatedAt: new Date().toISOString(),
    };

    return snapshot;
  }
);
