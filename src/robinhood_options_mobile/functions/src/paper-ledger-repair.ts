/**
 * Admin-only repair for paper accounts corrupted by the auto-trade exit bug.
 *
 * The exit monitor used to sell more shares than a position held. The paper
 * store treats that as opening a short, crediting the proceeds to cash, so
 * affected accounts hold net-short stock positions and inflated cash.
 *
 * Dry run is the default and changes nothing. Applying requires an explicit
 * list of user ids and writes an audit record holding the before state.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";

/** A net-short stock position that the repair would remove. */
export interface ShortPosition {
  symbol: string;
  quantity: number;
  averagePrice: number;
  proceeds: number;
}

/** What a repair would change for one paper account. */
export interface PaperRepairPlan {
  cashBefore: number;
  cashAfter: number;
  shorts: ShortPosition[];
  wouldGoNegative: boolean;
}

/**
 * Plans the removal of net-short stock positions and the cash credited when
 * they were opened. A short's average price is its entry average, so
 * |quantity| x average price is the unreversed proceeds.
 * @param {Record<string, any>} account The paper_account/main document data.
 * @param {string[]} [symbols] Only repair these symbols when given.
 * @return {PaperRepairPlan} The planned change.
 */
export function planPaperRepair(
  account: Record<string, any>,
  symbols?: string[]
): PaperRepairPlan {
  const wanted = (symbols ?? []).map((s) => s.toUpperCase());
  const positions: any[] = Array.isArray(account.positions) ?
    account.positions : [];

  const shorts: ShortPosition[] = [];
  for (const position of positions) {
    const quantity = Number(position?.quantity ?? 0);
    if (!(quantity < 0)) continue;
    const symbol = String(position?.instrumentObj?.symbol ?? "").toUpperCase();
    if (!symbol) continue;
    if (wanted.length > 0 && !wanted.includes(symbol)) continue;
    const averagePrice = Number(position?.average_buy_price ?? 0);
    shorts.push({
      symbol,
      quantity,
      averagePrice,
      proceeds: Math.abs(quantity) * averagePrice,
    });
  }

  const cashBefore = Number(account.cashBalance ?? 0);
  const removedProceeds = shorts.reduce((sum, s) => sum + s.proceeds, 0);
  const cashAfter = cashBefore - removedProceeds;
  return { cashBefore, cashAfter, shorts, wouldGoNegative: cashAfter < 0 };
}

/** Detail prefixes the paper store writes for short-opening/covering fills. */
const SHORT_FILL_PREFIXES = [
  "sell short",
  "buy to cover",
  "margin call: bought to cover",
];

/**
 * Picks the stock fills that only exist because of phantom shorts: the sells
 * that opened them and the buys that covered them.
 * @param {Array<Record<string, any>>} orders paper_orders documents (with id).
 * @param {string[]} symbols Symbols whose short fills should be voided.
 * @return {Array<Record<string, any>>} The fills to void.
 */
export function planVoidPhantomFills(
  orders: Array<Record<string, any>>,
  symbols: string[]
): Array<Record<string, any>> {
  const wanted = new Set(symbols.map((s) => s.toUpperCase()));
  return orders.filter((order) => {
    if (String(order.type ?? "").toUpperCase() !== "STOCK") return false;
    if (!wanted.has(String(order.symbol ?? "").toUpperCase())) return false;
    const detail = String(order.detail ?? "").toLowerCase();
    return SHORT_FILL_PREFIXES.some((prefix) => detail.startsWith(prefix));
  });
}

/**
 * Admin callable. Archives the short-related fills left behind by a ledger
 * repair into paper_orders_voided and removes them from paper_orders and the
 * embedded history. Input: { dryRun?: boolean (default true), uids: string[],
 * symbols?: string[] } where symbols default to those removed by earlier
 * repairs recorded in paper_repairs.
 */
export const voidPaperPhantomFills = onCall({
  memory: "512MiB",
  timeoutSeconds: 540,
}, async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError(
      "unauthenticated",
      "Authentication is required to void paper fills."
    );
  }
  if (request.auth.token?.role !== "admin") {
    throw new HttpsError(
      "permission-denied",
      "Only admin users can void paper fills."
    );
  }

  const dryRun = request.data?.dryRun !== false;
  const uids: string[] = Array.isArray(request.data?.uids) ?
    request.data.uids.filter((u: unknown) => typeof u === "string") : [];
  if (uids.length === 0) {
    throw new HttpsError("invalid-argument", "A list of uids is required.");
  }
  const explicitSymbols: string[] = Array.isArray(request.data?.symbols) ?
    request.data.symbols.filter((s: unknown) => typeof s === "string") : [];

  const db = getFirestore();
  const results: Array<Record<string, unknown>> = [];

  for (const uid of uids) {
    const userRef = db.doc(`user/${uid}`);
    let symbols = explicitSymbols;
    if (symbols.length === 0) {
      const repairs = await userRef.collection("paper_repairs").get();
      symbols = Array.from(new Set(repairs.docs.flatMap((d) =>
        ((d.data().removedPositions ?? []) as any[])
          .map((p) => String(p?.instrumentObj?.symbol ?? "").toUpperCase())
          .filter(Boolean))));
    }

    const snapshot = await userRef.collection("paper_orders").get();
    const orders = snapshot.docs.map((d) => ({ ...d.data(), id: d.id }));
    const phantom = planVoidPhantomFills(orders, symbols);

    const bySymbol: Record<string, number> = {};
    for (const order of phantom) {
      const symbol = String(order.symbol).toUpperCase();
      bySymbol[symbol] = (bySymbol[symbol] ?? 0) + 1;
    }
    const summary = {
      uid,
      symbols,
      totalOrders: orders.length,
      voidCount: phantom.length,
      bySymbol,
    };

    if (dryRun || phantom.length === 0) {
      results.push(summary);
      continue;
    }

    const refs = phantom.map((o) => String(o.id));
    const byId = new Map(phantom.map((o) => [String(o.id), o]));
    for (let offset = 0; offset < refs.length; offset += 200) {
      const batch = db.batch();
      for (const id of refs.slice(offset, offset + 200)) {
        const original = byId.get(id) ?? {};
        batch.set(userRef.collection("paper_orders_voided").doc(id), {
          ...original,
          voidedAt: FieldValue.serverTimestamp(),
          voidedBy: request.auth.uid,
          voidedReason: "Phantom short from auto-trade exit oversell",
        });
        batch.delete(userRef.collection("paper_orders").doc(id));
      }
      await batch.commit();
    }

    const accountRef = userRef.collection("paper_account").doc("main");
    const account = await accountRef.get();
    const history: any[] = Array.isArray(account.data()?.history) ?
      account.data()?.history : [];
    const voidedIds = new Set(refs);
    await accountRef.update({
      history: history.filter((h) => !voidedIds.has(String(h?.id))),
    });

    logger.info("Voided phantom paper fills", summary);
    results.push(summary);
  }

  return { dryRun, results };
});

/**
 * Admin callable. Input: { dryRun?: boolean (default true), uids?: string[],
 * symbols?: string[] }. A dry run scans every paper account and reports the
 * affected ones. Applying needs a non-empty uids list.
 */
export const repairPaperLedger = onCall({
  memory: "512MiB",
  timeoutSeconds: 540,
}, async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError(
      "unauthenticated",
      "Authentication is required to repair paper accounts."
    );
  }
  if (request.auth.token?.role !== "admin") {
    throw new HttpsError(
      "permission-denied",
      "Only admin users can repair paper accounts."
    );
  }

  const dryRun = request.data?.dryRun !== false;
  const uids: string[] = Array.isArray(request.data?.uids) ?
    request.data.uids.filter((u: unknown) => typeof u === "string") : [];
  const symbols: string[] = Array.isArray(request.data?.symbols) ?
    request.data.symbols.filter((s: unknown) => typeof s === "string") : [];

  if (!dryRun && uids.length === 0) {
    throw new HttpsError(
      "invalid-argument",
      "Applying a repair requires an explicit list of uids."
    );
  }

  const db = getFirestore();
  const accountRefs = uids.length > 0 ?
    uids.map((uid) => db.doc(`user/${uid}/paper_account/main`)) :
    (await db.collectionGroup("paper_account").get()).docs
      .filter((d) => d.id === "main")
      .map((d) => d.ref);

  const results: Array<Record<string, unknown>> = [];
  let scanned = 0;

  for (const ref of accountRefs) {
    scanned++;
    const uid = ref.parent.parent?.id ?? "unknown";
    try {
      if (dryRun) {
        const snapshot = await ref.get();
        if (!snapshot.exists) continue;
        const plan = planPaperRepair(snapshot.data() ?? {}, symbols);
        if (plan.shorts.length > 0) results.push({ uid, ...plan });
        continue;
      }

      const outcome = await db.runTransaction(async (tx) => {
        const snapshot = await tx.get(ref);
        if (!snapshot.exists) return null;
        const account = snapshot.data() ?? {};
        const plan = planPaperRepair(account, symbols);
        if (plan.shorts.length === 0) return null;

        const removed = new Set(plan.shorts.map((s) => s.symbol));
        const positions: any[] = Array.isArray(account.positions) ?
          account.positions : [];
        const kept = positions.filter((p) => {
          const symbol = String(p?.instrumentObj?.symbol ?? "").toUpperCase();
          return !(Number(p?.quantity ?? 0) < 0 && removed.has(symbol));
        });

        tx.set(db.collection(`user/${uid}/paper_repairs`).doc(), {
          createdAt: FieldValue.serverTimestamp(),
          adminUid: request.auth?.uid,
          reason: "Auto-trade exit oversell opened phantom shorts",
          cashBefore: plan.cashBefore,
          cashAfter: plan.cashAfter,
          removedPositions: positions.filter((p) => !kept.includes(p)),
        });
        tx.update(ref, { cashBalance: plan.cashAfter, positions: kept });
        return plan;
      });
      if (outcome) results.push({ uid, ...outcome });
    } catch (error) {
      logger.error("Paper ledger repair failed", { uid, error });
      results.push({ uid, error: String(error) });
    }
  }

  logger.info("Paper ledger repair finished", {
    dryRun,
    scanned,
    affected: results.length,
  });
  return { dryRun, scanned, affected: results.length, results };
});
