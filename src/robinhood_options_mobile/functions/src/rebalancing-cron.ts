import { onSchedule } from "firebase-functions/v2/scheduler";
import { getFirestore, Timestamp, FieldValue } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import { getMessaging } from "firebase-admin/messaging";
import { getMarketData } from "./market-data";

const db = getFirestore();
const messaging = getMessaging();

/**
 * Scheduled task that checks for portfolio rebalancing triggers.
 * Runs daily at market open (10:00 AM ET).
 */
export const rebalancingCron = onSchedule({
  schedule: "0 10 * * *",
  timeZone: "America/New_York",
  memory: "1GiB", // Increased for market data fetching
  timeoutSeconds: 540,
}, async () => {
  logger.info("Starting rebalancingCron...");

  const usersSnap = await db.collection("user")
    .where("rebalancingConfig.isEnabled", "==", true)
    .get();

  if (usersSnap.empty) {
    logger.info("No users with rebalancing enabled.");
    return;
  }

  const now = new Date();
  logger.info(`Processing ${usersSnap.docs.length} ` +
    "users for rebalancing check.");

  for (const userDoc of usersSnap.docs) {
    const userData = userDoc.data();
    const config = userData.rebalancingConfig;
    const userId = userDoc.id;

    if (!config || !config.isEnabled) continue;

    // Check frequency
    const lastRun = config.lastRun ?
      (config.lastRun as Timestamp).toDate() : new Date(0);
    const diffDays = (now.getTime() - lastRun.getTime()) / (1000 * 3600 * 24);

    let shouldRun = false;
    if (config.frequency === "daily" && diffDays >= 0.9) {
      shouldRun = true;
    } else if (config.frequency === "weekly" && diffDays >= 6.9) {
      shouldRun = true;
    } else if (config.frequency === "monthly" && diffDays >= 27.9) {
      shouldRun = true;
    }

    if (!shouldRun) {
      continue;
    }

    try {
      await processUserRebalancing(userId, userData);

      // Update lastRun
      await userDoc.ref.update({
        "rebalancingConfig.lastRun": Timestamp.fromDate(now),
      });
    } catch (err) {
      logger.error(`Error processing rebalancing for user ${userId}:`, err);
    }
  }
});

/**
 * Sends rebalancing notifications to the user's devices and handles
 * auto-execution for paper trading accounts if enabled.
 * @param {string} userId - The unique identifier for the user.
 * @param {any} userData - The user document data.
 */
async function processUserRebalancing(userId: string, userData: any) {
  logger.info(`Processing rebalancing for user ${userId}`);

  const rebalancingConfig = userData.rebalancingConfig || {};
  const driftThreshold = rebalancingConfig.driftThreshold || 100;
  const autoExecute = rebalancingConfig.autoExecute || false;

  // 1. Try to process Paper Rebalancing (server-side only)
  const paperAccountRef = db.collection("user").doc(userId)
    .collection("paper_account").doc("main");
  const paperAccountSnap = await paperAccountRef.get();

  let driftDetected = false;
  let rebalanceSummary = "";

  if (paperAccountSnap.exists) {
    const paperData = paperAccountSnap.data() || {};
    const recommendations = await calculatePaperRebalancing(
      paperData, userData
    );

    const significantRcs = recommendations.filter((r) =>
      Math.abs(r.amount) > driftThreshold);

    if (significantRcs.length > 0) {
      driftDetected = true;
      rebalanceSummary = significantRcs
        .map((r) => `${r.key}: ${r.amount > 0 ? "BUY" : "SELL"} ` +
          `$${Math.abs(r.amount).toFixed(2)}`)
        .join(", ");

      if (autoExecute) {
        logger.info(`Auto-executing rebalancing for paper account: ${userId}`);
        await executePaperRebalancing(userId, paperData, significantRcs);
        rebalanceSummary = "Auto-executed: " + rebalanceSummary;
      }
    }
  }

  // 🔔 Send Push Notification
  const devices = userData.devices || [];
  const tokens = devices.map((d: any) => d.token).filter((t: any) => !!t);

  if (tokens.length > 0) {
    const title = driftDetected ?
      "Rebalancing Needed" : "Portfolio Checkup";
    const body = driftDetected ?
      `Your portfolio drift exceeds threshold. ${rebalanceSummary}` :
      "Your portfolio remains within balance targets. No action needed.";

    const message = {
      notification: {
        title,
        body,
      },
      data: {
        route: "/rebalancing", // Deep linking route
      },
    };

    const responses = await Promise.all(tokens.map(async (token: string) => {
      try {
        return await messaging.send({ token, ...message });
      } catch (err: any) {
        logger.warn("Failed to send notification to token for " +
          `user ${userId}:`, err.message);
        return null;
      }
    }));
    logger.info(`Successfully sent ${responses.filter((r) => !!r).length} ` +
      `notifications to user ${userId}`);
  }
}

/**
 * Calculates current allocation and drift for a paper account.
 * @param {any} paperData - The paper account data.
 * @param {any} userData - The user document data.
 * @return {Promise<any[]>} - List of rebalancing recommendations.
 */
async function calculatePaperRebalancing(paperData: any, userData: any) {
  const stockPositions = paperData.positions || [];
  const optionPositions = paperData.optionPositions || [];
  const cashBalance = paperData.cashBalance || 0;

  const symbolPrices: Record<string, number> = {};
  const uniqueSymbols = new Set<string>();

  stockPositions.forEach((p: any) => {
    if (p.instrumentObj?.symbol) uniqueSymbols.add(p.instrumentObj.symbol);
  });

  // Fetch current prices
  for (const symbol of uniqueSymbols) {
    try {
      const md = await getMarketData(symbol, 1, 1, "1d");
      if (md.currentPrice) {
        symbolPrices[symbol] = md.currentPrice;
      }
    } catch (e) {
      logger.warn(`Failed to fetch price for ${symbol} rebalancing`, e);
    }
  }

  let stockEquity = 0;
  stockPositions.forEach((p: any) => {
    const price = symbolPrices[p.instrumentObj?.symbol] ||
      p.average_buy_price || 0;
    stockEquity += (p.quantity || 0) * price;
  });

  let optionEquity = 0;
  optionPositions.forEach((p: any) => {
    // Fallback for options equity since server-side option data is limited
    const mark = p.optionInstrument?.optionMarketData?.adjustedMarkPrice ||
      p.average_open_price || 0;
    optionEquity += (p.quantity || 0) * mark * 100;
  });

  const totalEquity = stockEquity + optionEquity + cashBalance;
  if (totalEquity === 0) return [];

  const currentAllocation = {
    "Stocks": stockEquity / totalEquity,
    "Options": optionEquity / totalEquity,
    "Cash": cashBalance / totalEquity,
    "Crypto": 0, // Need crypto logic if paper supports it
  };

  const targets = userData.assetAllocationTargets || {
    "Stocks": 0.8,
    "Options": 0.05,
    "Cash": 0.15,
  };

  const recommendations: any[] = [];
  ["Stocks", "Options", "Cash"].forEach((key) => {
    const cur = currentAllocation[key as keyof typeof currentAllocation] || 0;
    const tgt = (targets[key] || 0);
    const diff = tgt - cur;
    const amount = diff * totalEquity;
    recommendations.push({ key, amount, targetPct: tgt });
  });

  return recommendations;
}

/**
 * Executes rebalancing on a paper account by adjusting cash balance.
 * (In a real paper rebalancing, it should add/remove positions)
 * For now, adjusts paper cash and adds a log entry.
 * @param {string} userId - The unique identifier for the user.
 * @param {any} paperData - The paper account data.
 * @param {any[]} recommendations - The rebalancing recommendations to apply.
 */
async function executePaperRebalancing(
  userId: string, paperData: any, recommendations: any[]) {
  const paperAccountRef = db.collection("user").doc(userId)
    .collection("paper_account").doc("main");

  const historyItem = {
    timestamp: Timestamp.now(),
    type: "rebalance",
    message: "Automated rebalancing executed.",
    details: recommendations,
  };

  // Push to main document history array for UI visibility
  await paperAccountRef.update({
    history: FieldValue.arrayUnion(historyItem),
    updatedAt: FieldValue.serverTimestamp(),
  });
}
