import { onRequest } from "firebase-functions/v2/https";
import { getFirestore } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import { logger } from "firebase-functions";

const db = getFirestore();
const auth = getAuth();

/**
 * Diagnostic endpoint to check cron job configuration and Firestore data
 * Call this to debug why cron jobs might not be running
 *
 * REQUIRES AUTHENTICATION: Admin users only
 *
 * Usage:
 *   const token = await firebase.auth().currentUser.getIdToken();
 *   fetch('https://us-central1-<project-id>.cloudfunctions.net/cronDiagnostics', {
 *     headers: { 'Authorization': `Bearer ${token}` }
 *   })
 */
export const cronDiagnostics = onRequest(async (request, response) => {
  // Verify authentication
  const authHeader = request.headers.authorization;
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    logger.warn("Unauthorized access attempt to cronDiagnostics");
    response.status(401).json({
      error: "Unauthorized - Missing or invalid token",
    });
    return;
  }

  try {
    // Verify the Firebase ID token
    const token = authHeader.split("Bearer ")[1];
    const decodedToken = await auth.verifyIdToken(token);

    // Check if user has admin role (required for access)
    if (!decodedToken.role || decodedToken.role !== "admin") {
      logger.warn(
        `Non-admin user ${decodedToken.uid} attempted to access cronDiagnostics`
      );
      response.status(403).json({
        error: "Forbidden - Admin access required",
      });
      return;
    }

    logger.info(
      `Admin user ${decodedToken.uid} running cron diagnostics...`
    );
  } catch (authError) {
    logger.error("Token verification failed:", authError);
    response.status(401).json({
      error: "Unauthorized - Invalid token",
    });
    return;
  }

  try {
    interface DiagnosticsData {
      timestamp: string;
      timezone: string;
      currentTime: {
        utc: string;
        est: string;
      };
      firestoreData: Record<string, unknown>;
      issues: string[];
      recommendations: string[];
      cronSchedules?: Record<string, unknown>;
      summary?: Record<string, unknown>;
    }

    const diagnostics: DiagnosticsData = {
      timestamp: new Date().toISOString(),
      timezone: new Intl.DateTimeFormat().resolvedOptions().timeZone,
      currentTime: {
        utc: new Date().toISOString(),
        est: new Date().toLocaleString(
          "en-US",
          { timeZone: "America/New_York" }
        ),
      },
      firestoreData: {},
      issues: [],
      recommendations: [],
    };

    // Check Firestore collection
    const snapshot = await db.collection("agentic_trading").get();
    diagnostics.firestoreData.totalDocuments = snapshot.docs.length;

    if (snapshot.empty) {
      diagnostics.issues.push(
        "❌ No documents found in agentic_trading collection!"
      );
      diagnostics.recommendations.push(
        "Ensure you have chart documents " +
        "(e.g., chart_AAPL, chart_SPY) in " +
        "the agentic_trading collection"
      );
    } else {
      // Categorize documents
      const dailyCharts = [];
      const hourlyCharts = [];
      const fifteenMinCharts = [];
      const signalDocs = [];
      const otherDocs = [];

      for (const doc of snapshot.docs) {
        if (doc.id.startsWith("chart_")) {
          if (doc.id.endsWith("_1h")) {
            hourlyCharts.push(doc.id);
          } else if (doc.id.endsWith("_15m")) {
            fifteenMinCharts.push(doc.id);
          } else if (doc.id.endsWith("_30m")) {
            otherDocs.push(doc.id);
          } else {
            // Daily chart (no suffix)
            dailyCharts.push(doc.id);
          }
        } else if (doc.id.startsWith("signals_")) {
          signalDocs.push(doc.id);
        } else {
          otherDocs.push(doc.id);
        }
      }

      diagnostics.firestoreData.dailyCharts = {
        count: dailyCharts.length,
        examples: dailyCharts.slice(0, 5),
      };
      diagnostics.firestoreData.hourlyCharts = {
        count: hourlyCharts.length,
        examples: hourlyCharts.slice(0, 5),
      };
      diagnostics.firestoreData.fifteenMinCharts = {
        count: fifteenMinCharts.length,
        examples: fifteenMinCharts.slice(0, 5),
      };
      diagnostics.firestoreData.signalDocs = {
        count: signalDocs.length,
        examples: signalDocs.slice(0, 5),
      };
      diagnostics.firestoreData.otherDocs = {
        count: otherDocs.length,
        examples: otherDocs.slice(0, 5),
      };

      // Check for issues
      if (dailyCharts.length === 0) {
        diagnostics.issues.push(
          "⚠️ No daily chart documents found " +
          "(chart_SYMBOL without _1h/_15m suffix)"
        );
        diagnostics.recommendations.push(
          "The EOD cron job (4pm ET) requires daily chart " +
          "documents like 'chart_AAPL', 'chart_SPY', etc."
        );
      } else {
        diagnostics.recommendations.push(
          `✅ Found ${dailyCharts.length} daily charts that ` +
          "will be processed by EOD cron"
        );
      }

      if (hourlyCharts.length === 0 && fifteenMinCharts.length === 0) {
        diagnostics.recommendations.push(
          "ℹ️ No intraday chart documents found. " +
          "Intraday crons will process daily charts."
        );
      }

      // Check config document
      const configDoc = await db.doc("agentic_trading/config").get();
      if (configDoc.exists) {
        diagnostics.firestoreData.config = configDoc.data();
        diagnostics.recommendations.push(
          "✅ Config document exists"
        );
      } else {
        diagnostics.issues.push(
          "⚠️ No config document found at agentic_trading/config"
        );
        diagnostics.recommendations.push(
          "Create a config document with trading parameters " +
          "(smaPeriodFast, smaPeriodSlow, etc.)"
        );
      }

      // Check recent signal updates
      const recentSignals = await db
        .collection("agentic_trading")
        .where(
          "timestamp",
          ">",
          Date.now() - 24 * 60 * 60 * 1000
        ) // Last 24 hours
        .orderBy("timestamp", "desc")
        .limit(5)
        .get();

      diagnostics.firestoreData.recentSignals = {
        count: recentSignals.docs.length,
        examples: recentSignals.docs.map(
          (doc) => ({
            id: doc.id,
            timestamp: doc.data().timestamp,
            signal: doc.data().signal,
            symbol: doc.data().symbol,
          })
        ),
      };

      if (recentSignals.docs.length === 0) {
        diagnostics.issues.push(
          "⚠️ No trade signals updated in the last 24 hours"
        );
        diagnostics.recommendations.push(
          "Check if cron jobs are running. Try manually invoking: " +
          "https://us-central1-<project-id>.cloudfunctions.net/" +
          "agenticTradingCronInvoke"
        );
      } else {
        diagnostics.recommendations.push(
          `✅ Found ${recentSignals.docs.length} signals ` +
          "updated in last 24 hours"
        );
      }
    }

    // Cron schedule info
    diagnostics.cronSchedules = {
      eodDaily: {
        schedule: "0 16 * * 1-5",
        timezone: "America/New_York",
        description: "4:00 PM ET, Monday-Friday",
        nextRun: "Calculated by Cloud Scheduler (check Firebase Console)",
      },
      intraday1h: {
        schedule: "30 9-16 * * 1-5",
        timezone: "America/New_York",
        description: "Every hour at :30, 9:30 AM - 4:30 PM ET, Monday-Friday",
      },
      intraday15m: {
        schedule: "15,30,45,0 9-16 * * 1-5",
        timezone: "America/New_York",
        description: "Every 15 minutes, 9:15 AM - 4:45 PM ET, Monday-Friday",
      },
    };

    // Summary
    diagnostics.summary = {
      totalIssues: diagnostics.issues.length,
      status: diagnostics.issues.length === 0 ? "✅ HEALTHY" : "⚠️ ISSUES FOUND",
    };

    response.json(diagnostics);
  } catch (error) {
    logger.error("Error running diagnostics:", error);
    response.status(500).json({
      error: "Failed to run diagnostics",
      message: error instanceof Error ? error.message : String(error),
    });
  }
});
