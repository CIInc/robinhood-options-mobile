import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, Timestamp } from "firebase-admin/firestore";

const db = getFirestore();

type Trade = {
  side?: string;
  state?: string;
  instrument_id?: string;
  cumulative_quantity?: number;
  average_price?: number;
  fees?: number;
  created_at?: Timestamp | Date;
};

const dateValue = (value: unknown): Date | null => {
  if (value instanceof Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  if (typeof value === "string") {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  return null;
};

const iso = (value: Date | null): string | null => value?.toISOString() ?? null;

/**
 * Build performance metrics for one group member.
 * @param {string} memberId Member user ID.
 * @param {Date | null} startDate Inclusive start of the reporting period.
 * @param {Date} endDate Inclusive end of the reporting period.
 * @return {Promise<Record<string, unknown>>} Member performance metrics.
 */
async function getMemberMetrics(memberId: string, startDate: Date | null,
  endDate: Date): Promise<Record<string, unknown>> {
  const userSnapshot = await db.collection("user").doc(memberId).get();
  const user = userSnapshot.data() ?? {};
  const orderQuery = db.collection("user").doc(memberId)
    .collection("instrumentOrder").where("created_at", "<=", endDate);
  const orderSnapshot = await orderQuery.orderBy("created_at").get();
  const byInstrument = new Map<string, Trade[]>();

  for (const document of orderSnapshot.docs) {
    const order = document.data() as Trade;
    const instrumentId = order.instrument_id;
    const state = order.state?.toLowerCase();
    if ((state !== "filled" && state !== "executed") ||
      !instrumentId) continue;
    const orders = byInstrument.get(instrumentId) ?? [];
    orders.push(order);
    byInstrument.set(instrumentId, orders);
  }

  let totalTrades = 0;
  let winningTrades = 0;
  let losingTrades = 0;
  let totalReturnDollars = 0;
  let totalWinAmount = 0;
  let totalLossAmount = 0;
  let sumReturns = 0;
  let sumReturnsSquared = 0;
  let totalHoldTime = 0;
  let firstTradeDate: Date | null = null;
  let lastTradeDate: Date | null = null;

  for (const orders of byInstrument.values()) {
    const buyQueue: Array<{
      price: number;
      quantity: number;
      fees: number;
      date: Date | null;
    }> = [];
    for (const order of orders) {
      const quantity = order.cumulative_quantity ?? 0;
      const price = order.average_price ?? 0;
      const fees = order.fees ?? 0;
      const createdAt = dateValue(order.created_at);
      if (!quantity) continue;
      if (createdAt && (!firstTradeDate || createdAt < firstTradeDate)) {
        firstTradeDate = createdAt;
      }
      const side = order.side?.toLowerCase();
      if (side === "buy") {
        buyQueue.push({ price, quantity, fees, date: createdAt });
        continue;
      }
      if (side !== "sell") continue;
      let remaining = quantity;
      while (remaining > 0 && buyQueue.length > 0) {
        const buy = buyQueue[0];
        const matched = Math.min(remaining, buy.quantity);
        const pnl = (price - buy.price) * matched -
          fees * (matched / quantity) - buy.fees * (matched / buy.quantity);
        const isInPeriod = !startDate ||
          (createdAt !== null && createdAt >= startDate);
        if (!isInPeriod) {
          remaining -= matched;
          buy.quantity -= matched;
          if (buy.quantity <= 0) buyQueue.shift();
          continue;
        }
        const costBasis = buy.price * matched;
        const pnlPercent = costBasis > 0 ? (pnl / costBasis) * 100 : 0;
        totalTrades++;
        totalReturnDollars += pnl;
        sumReturns += pnlPercent;
        sumReturnsSquared += pnlPercent * pnlPercent;
        if (pnl > 0) {
          winningTrades++;
          totalWinAmount += pnl;
        } else if (pnl < 0) {
          losingTrades++;
          totalLossAmount += Math.abs(pnl);
        }
        if (buy.date && createdAt) {
          totalHoldTime += Math.floor(
            (createdAt.getTime() - buy.date.getTime()) / (60 * 60 * 1000));
        }
        if (createdAt) lastTradeDate = createdAt;
        remaining -= matched;
        buy.quantity -= matched;
        if (buy.quantity <= 0) buyQueue.shift();
      }
    }
  }

  const totalReturnPercent = totalTrades > 0 ? sumReturns / totalTrades : 0;
  const variance = totalTrades > 1 ?
    (sumReturnsSquared / totalTrades) - totalReturnPercent ** 2 : 0;
  const standardDeviation = variance > 0 ? Math.sqrt(variance) : 0;
  const sharpeRatio = standardDeviation > 0 ?
    (totalReturnPercent / standardDeviation) * Math.sqrt(252) : 0;
  const profitFactor = totalLossAmount > 0 ? totalWinAmount / totalLossAmount :
    0;

  return {
    memberId,
    memberName: user.name ?? "Unknown",
    memberPhotoUrl: user.photoUrl ?? null,
    totalReturnPercent,
    totalReturnDollars,
    winRate: totalTrades > 0 ? (winningTrades / totalTrades) * 100 : 0,
    totalTrades,
    winningTrades,
    losingTrades,
    averageWin: winningTrades > 0 ? totalWinAmount / winningTrades : 0,
    averageLoss: losingTrades > 0 ? totalLossAmount / losingTrades : 0,
    profitFactor,
    sharpeRatio,
    maxDrawdownPercent: totalTrades > 0 && totalLossAmount > 0 ?
      (totalLossAmount / (totalWinAmount + totalLossAmount)) * 100 : 0,
    avgHoldTimeHours: totalTrades > 0 ? totalHoldTime / totalTrades : null,
    firstTradeDate: iso(firstTradeDate),
    lastTradeDate: iso(lastTradeDate),
  };
}

export const getGroupPerformanceAnalytics = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated");
  }
  const groupId = request.data?.groupId;
  if (typeof groupId !== "string" || !groupId) {
    throw new HttpsError("invalid-argument", "groupId is required");
  }
  const groupSnapshot = await db.collection("investor_groups")
    .doc(groupId).get();
  if (!groupSnapshot.exists) {
    throw new HttpsError("not-found", "Group not found");
  }
  const group = groupSnapshot.data() ?? {};
  const members = Array.isArray(group.members) ?
    group.members as string[] : [];
  if (!members.includes(request.auth.uid)) {
    throw new HttpsError(
      "permission-denied", "You must be a member of this group");
  }

  const startDate = request.data.startDate ?
    new Date(request.data.startDate) : null;
  const endDate = request.data.endDate ?
    new Date(request.data.endDate) : new Date();
  const memberMetrics = await Promise.all(
    members.map((memberId) => getMemberMetrics(memberId, startDate, endDate)));
  const traded = memberMetrics.filter((member) =>
    (member.totalTrades as number) > 0);
  const totalTrades = traded.reduce(
    (sum, member) => sum + (member.totalTrades as number), 0);
  const totalWinningTrades = traded.reduce(
    (sum, member) => sum + (member.winningTrades as number), 0);
  const averageReturn = traded.length > 0 ?
    traded.reduce((sum, member) =>
      sum + (member.totalReturnPercent as number), 0) / traded.length : 0;
  const totalDollars = traded.reduce(
    (sum, member) => sum + (member.totalReturnDollars as number), 0);
  const averageSharpe = traded.length > 0 ?
    traded.reduce((sum, member) => sum + (member.sharpeRatio as number), 0) /
    traded.length : 0;
  const top = traded.reduce<Record<string, unknown> | null>((best, member) =>
    !best || (member.totalReturnPercent as number) >
      (best.totalReturnPercent as number) ? member : best, null);

  return {
    groupMetrics: {
      groupId,
      groupTotalReturnPercent: averageReturn,
      groupTotalReturnDollars: totalDollars,
      groupAverageReturnPercent: averageReturn,
      groupAverageReturnDollars: traded.length > 0 ?
        totalDollars / traded.length : 0,
      totalMembersTraded: traded.length,
      totalGroupTrades: totalTrades,
      groupWinRate: totalTrades > 0 ?
        (totalWinningTrades / totalTrades) * 100 : 0,
      groupAverageSharpeRatio: averageSharpe,
      topPerformerReturnPercent: (top?.totalReturnPercent as number) ?? 0,
      topPerformerId: (top?.memberId as string) ?? null,
      membersWithPositiveReturn: traded.filter((m) =>
        (m.totalReturnPercent as number) > 0).length,
      membersWithNegativeReturn: traded.filter((m) =>
        (m.totalReturnPercent as number) < 0).length,
      timeRangeStart: iso(startDate),
      timeRangeEnd: iso(endDate),
    },
    memberMetrics,
  };
});
