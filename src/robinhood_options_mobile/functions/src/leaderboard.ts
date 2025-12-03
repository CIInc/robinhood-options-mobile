import * as admin from "firebase-admin";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onCall, HttpsError } from "firebase-functions/v2/https";

const db = admin.firestore();

interface PerformanceData {
  userName: string;
  userAvatarUrl: string | null;
  totalReturn: number;
  returnPercentage: number;
  portfolioValue: number;
  dayReturn: number;
  dayReturnPercentage: number;
  weekReturn: number;
  weekReturnPercentage: number;
  monthReturn: number;
  monthReturnPercentage: number;
  threeMonthReturn: number;
  threeMonthReturnPercentage: number;
  yearReturn: number;
  yearReturnPercentage: number;
  allTimeReturn: number;
  allTimeReturnPercentage: number;
  totalTrades: number;
  winningTrades: number;
  losingTrades: number;
  winRate: number;
  sharpeRatio: number;
  maxDrawdown: number;
  isPublic: boolean;
}

/**
 * Calculate portfolio performance metrics and update leaderboard
 * Runs daily at 6 PM ET
 */
export const calculateLeaderboard = onSchedule(
  {
    schedule: "0 18 * * *",
    timeZone: "America/New_York",
  },
  async () => {
    try {
      console.log("Starting leaderboard calculation...");

      // Get all users with public portfolios
      const usersSnapshot = await db
        .collection("user")
        .where("portfolioPublic", "==", true)
        .get();

      const performances: Array<{
        userId: string;
        data: PerformanceData;
        returnPercentage: number;
      }> = [];

      // Calculate performance for each user
      for (const userDoc of usersSnapshot.docs) {
        const userId = userDoc.id;
        const userData = userDoc.data();

        try {
          const performance = await calculateUserPerformance(
            userId,
            userData
          );
          if (performance) {
            performances.push({
              userId,
              data: performance,
              returnPercentage: performance.returnPercentage,
            });
          }
        } catch (error) {
          console.error(`Error calculating performance for ${userId}:`, error);
        }
      }

      // Sort by return percentage descending
      performances.sort((a, b) => b.returnPercentage - a.returnPercentage);

      // Get previous rankings for rank change calculation
      const previousRankings = await getPreviousRankings();

      // Write to leaderboard collection with ranks
      const batch = db.batch();
      performances.forEach((perf, index) => {
        const rank = index + 1;
        const previousRank = previousRankings.get(perf.userId);

        const docRef = db
          .collection("portfolio_leaderboard")
          .doc(perf.userId);
        batch.set(docRef, {
          ...perf.data,
          rank,
          // Firestore doesn't allow undefined; store null when absent
          previousRank: previousRank ?? null,
          lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      await batch.commit();

      console.log(
        `Leaderboard updated with ${performances.length} portfolios`
      );
    } catch (error) {
      console.error("Error calculating leaderboard:", error);
      throw error;
    }
  }
);

/**
 * Get previous rankings for comparison
 * @return {Promise<Map<string, number>>} Map of user IDs to ranks
 */
async function getPreviousRankings(): Promise<Map<string, number>> {
  const rankingsMap = new Map<string, number>();

  try {
    const snapshot = await db.collection("portfolio_leaderboard").get();

    snapshot.forEach((doc) => {
      const data = doc.data();
      if (data.rank !== undefined) {
        rankingsMap.set(doc.id, data.rank);
      }
    });
  } catch (error) {
    console.error("Error fetching previous rankings:", error);
  }

  return rankingsMap;
}

/**
 * Calculate performance metrics for a single user
 * @param {string} userId - The user ID
 * @param {FirebaseFirestore.DocumentData} userData - User data
 * @return {Promise<PerformanceData | null>} Performance metrics
 */
async function calculateUserPerformance(
  userId: string,
  userData: FirebaseFirestore.DocumentData
): Promise<PerformanceData | null> {
  try {
    // Get portfolio historicals for various time periods
    const historicals = await getPortfolioHistoricals(userId);
    if (!historicals || historicals.length === 0) {
      return null;
    }

    // Get current portfolio value
    const currentValue = await getCurrentPortfolioValue(userId);
    if (!currentValue) {
      return null;
    }

    // Calculate returns for different time periods
    const now = new Date();
    const oneDayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    const oneWeekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    const oneMonthAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
    const threeMonthsAgo = new Date(now.getTime() - 90 * 24 * 60 * 60 * 1000);
    const oneYearAgo = new Date(now.getTime() - 365 * 24 * 60 * 60 * 1000);

    const dayReturn = calculateReturn(historicals, oneDayAgo, currentValue);
    const weekReturn = calculateReturn(historicals, oneWeekAgo, currentValue);
    const monthReturn = calculateReturn(historicals, oneMonthAgo, currentValue);
    const threeMonthReturn = calculateReturn(
      historicals,
      threeMonthsAgo,
      currentValue
    );
    const yearReturn = calculateReturn(historicals, oneYearAgo, currentValue);
    const allTimeReturn = calculateReturn(
      historicals,
      new Date(0),
      currentValue
    );

    // Get trading statistics
    const tradingStats = await getTradingStatistics(userId);

    // Calculate risk metrics
    const riskMetrics = calculateRiskMetrics(historicals);

    return {
      userName: userData.displayName || userData.email || "Anonymous",
      userAvatarUrl: userData.photoURL || null,
      totalReturn: allTimeReturn.absolute,
      returnPercentage: allTimeReturn.percentage,
      portfolioValue: currentValue,
      dayReturn: dayReturn.absolute,
      dayReturnPercentage: dayReturn.percentage,
      weekReturn: weekReturn.absolute,
      weekReturnPercentage: weekReturn.percentage,
      monthReturn: monthReturn.absolute,
      monthReturnPercentage: monthReturn.percentage,
      threeMonthReturn: threeMonthReturn.absolute,
      threeMonthReturnPercentage: threeMonthReturn.percentage,
      yearReturn: yearReturn.absolute,
      yearReturnPercentage: yearReturn.percentage,
      allTimeReturn: allTimeReturn.absolute,
      allTimeReturnPercentage: allTimeReturn.percentage,
      totalTrades: tradingStats.totalTrades,
      winningTrades: tradingStats.winningTrades,
      losingTrades: tradingStats.losingTrades,
      winRate: tradingStats.winRate,
      sharpeRatio: riskMetrics.sharpeRatio,
      maxDrawdown: riskMetrics.maxDrawdown,
      isPublic: userData.portfolioPublic || false,
    };
  } catch (error) {
    console.error(`Error in calculateUserPerformance for ${userId}:`, error);
    return null;
  }
}

/**
 * Get portfolio historicals for a user
 * @param {string} userId - The user ID
 * @return {Promise<Array>} Historical portfolio data
 */
async function getPortfolioHistoricals(
  userId: string
): Promise<Array<{ date: Date; value: number }>> {
  try {
    const snapshot = await db
      .collection("portfolio_historicals")
      .where("userId", "==", userId)
      .orderBy("date", "asc")
      .get();

    return snapshot.docs.map((doc) => {
      const data = doc.data();
      return {
        date: data.date.toDate(),
        value: data.portfolioValue || 0,
      };
    });
  } catch (error) {
    console.error(`Error fetching historicals for ${userId}:`, error);
    return [];
  }
}

/**
 * Get current portfolio value
 * @param {string} userId - The user ID
 * @return {Promise<number | null>} Current portfolio value or null
 */
async function getCurrentPortfolioValue(
  userId: string
): Promise<number | null> {
  try {
    const userDoc = await db.collection("user").doc(userId).get();
    const userData = userDoc.data();
    return userData?.portfolioValue || null;
  } catch (error) {
    console.error(`Error fetching portfolio value for ${userId}:`, error);
    return null;
  }
}

/**
 * Calculate return for a specific time period
 * @param {Array} historicals - Historical portfolio values
 * @param {Date} startDate - Start date for calculation
 * @param {number} currentValue - Current portfolio value
 * @return {Object} Return metrics with absolute and percentage
 */
function calculateReturn(
  historicals: Array<{ date: Date; value: number }>,
  startDate: Date,
  currentValue: number
): { absolute: number; percentage: number } {
  // Find the closest historical data point to the start date
  let startValue = currentValue;
  for (let i = historicals.length - 1; i >= 0; i--) {
    if (historicals[i].date <= startDate) {
      startValue = historicals[i].value;
      break;
    }
  }

  const absolute = currentValue - startValue;
  const percentage = startValue > 0 ? (absolute / startValue) * 100 : 0;

  return { absolute, percentage };
}

/**
 * Get trading statistics for a user
 * @param {string} userId - The user ID
 * @return {Promise<Object>} Trading statistics
 */
async function getTradingStatistics(userId: string): Promise<{
  totalTrades: number;
  winningTrades: number;
  losingTrades: number;
  winRate: number;
}> {
  try {
    // This would query historical orders
    // For now, return placeholder values
    const ordersSnapshot = await db
      .collection("orders")
      .where("userId", "==", userId)
      .where("state", "==", "filled")
      .get();

    const totalTrades = ordersSnapshot.size;

    // Calculate wins/losses (simplified)
    let winningTrades = 0;
    let losingTrades = 0;

    ordersSnapshot.forEach((doc) => {
      const data = doc.data();
      // This is simplified - proper implementation would track
      // closed positions and their P&L
      if (data.side === "sell") {
        const pl = data.price - (data.averageCost || 0);
        if (pl > 0) {
          winningTrades++;
        } else if (pl < 0) {
          losingTrades++;
        }
      }
    });

    const winRate = totalTrades > 0 ? (winningTrades / totalTrades) * 100 : 0;

    return {
      totalTrades,
      winningTrades,
      losingTrades,
      winRate,
    };
  } catch (error) {
    console.error(`Error calculating trading stats for ${userId}:`, error);
    return {
      totalTrades: 0,
      winningTrades: 0,
      losingTrades: 0,
      winRate: 0,
    };
  }
}

/**
 * Calculate risk metrics from historicals
 * @param {Array} historicals - Historical portfolio values
 * @return {Object} Risk metrics with sharpeRatio and maxDrawdown
 */
function calculateRiskMetrics(
  historicals: Array<{ date: Date; value: number }>
): { sharpeRatio: number; maxDrawdown: number } {
  if (historicals.length < 2) {
    return { sharpeRatio: 0, maxDrawdown: 0 };
  }

  // Calculate daily returns
  const returns: number[] = [];
  for (let i = 1; i < historicals.length; i++) {
    const prevValue = historicals[i - 1].value;
    const currValue = historicals[i].value;
    if (prevValue > 0) {
      returns.push((currValue - prevValue) / prevValue);
    }
  }

  // Calculate Sharpe Ratio (simplified)
  const avgReturn = returns.reduce((a, b) => a + b, 0) / returns.length;
  const stdDev = Math.sqrt(
    returns.reduce((sq, n) => sq + Math.pow(n - avgReturn, 2), 0) /
    returns.length
  );
  const sharpeRatio = stdDev > 0 ? (avgReturn / stdDev) * Math.sqrt(252) : 0;

  // Calculate Maximum Drawdown
  let maxDrawdown = 0;
  let peak = historicals[0].value;

  for (const point of historicals) {
    if (point.value > peak) {
      peak = point.value;
    }
    const drawdown = ((peak - point.value) / peak) * 100;
    if (drawdown > maxDrawdown) {
      maxDrawdown = drawdown;
    }
  }

  return {
    sharpeRatio: Math.round(sharpeRatio * 100) / 100,
    maxDrawdown: Math.round(maxDrawdown * 100) / 100,
  };
}

/**
 * Manual callable function to trigger leaderboard calculation
 */
export const calculateLeaderboardManual = onCall(async (request) => {
  // Require authentication
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated");
  }

  try {
    // Call the scheduled function logic directly
    console.log("Starting manual leaderboard calculation...");

    // Get all users with public portfolios
    const usersSnapshot = await db
      .collection("user")
      .where("portfolioPublic", "==", true)
      .get();

    const performances: Array<{
      userId: string;
      data: PerformanceData;
      returnPercentage: number;
    }> = [];

    // Calculate performance for each user
    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;
      const userData = userDoc.data();

      try {
        const performance = await calculateUserPerformance(userId, userData);
        if (performance) {
          performances.push({
            userId,
            data: performance,
            returnPercentage: performance.returnPercentage,
          });
        }
      } catch (error) {
        console.error(`Error calculating performance for ${userId}:`, error);
      }
    }

    // Sort by return percentage descending
    performances.sort((a, b) => b.returnPercentage - a.returnPercentage);

    // Get previous rankings for rank change calculation
    const previousRankings = await getPreviousRankings();

    // Write to leaderboard collection with ranks
    const batch = db.batch();
    performances.forEach((perf, index) => {
      const rank = index + 1;
      const previousRank = previousRankings.get(perf.userId);

      const docRef = db.collection("portfolio_leaderboard").doc(perf.userId);
      batch.set(docRef, {
        ...perf.data,
        rank,
        // Firestore doesn't allow undefined; store null when absent
        previousRank: previousRank ?? null,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    await batch.commit();

    console.log(
      `Leaderboard updated with ${performances.length} portfolios`
    );

    return { success: true, count: performances.length };
  } catch (error) {
    console.error("Error in manual leaderboard calculation:", error);
    throw new HttpsError("internal", "Failed to calculate leaderboard");
  }
});

/**
 * Update user's portfolio public status
 */
export const updatePortfolioPublicStatus = onCall<{ isPublic: boolean }>(
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const userId = request.auth.uid;
    const { isPublic } = request.data;

    try {
      await db.collection("user").doc(userId).update({
        portfolioPublic: isPublic,
        portfolioPublicUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // If making private, remove from leaderboard
      if (!isPublic) {
        await db.collection("portfolio_leaderboard").doc(userId).delete();
      }

      return { success: true };
    } catch (error) {
      console.error("Error updating portfolio public status:", error);
      throw new HttpsError("internal", "Failed to update portfolio status");
    }
  }
);
