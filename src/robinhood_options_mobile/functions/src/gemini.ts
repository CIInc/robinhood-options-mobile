// import * as functions from 'firebase-functions';
import * as https from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { getFirestore } from "firebase-admin/firestore";
import { GoogleGenAI } from "@google/genai";

// export const generateContent = https.onCall({ secrets: ["GEMINI_API_KEY"] },
//   async (request) => {
//     logger.info(request.data, { structuredData: true });
//     if (process.env.GEMINI_API_KEY == null) {
//       throw new https.HttpsError(
//         "unavailable", "GEMINI_API_KEY not found.");
//     }
//     const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
//     const model = genAI.getGenerativeModel(
//       {
//         model: "models/gemini-1.5-flash",
//         tools: [
//           {
//             googleSearchRetrieval: {
//               // dynamicRetrievalConfig: {
//               //   mode: DynamicRetrievalMode.MODE_DYNAMIC,
//               //   dynamicThreshold: 0.7,
//               // },
//             },
//           },
//         ],
//       },
//       { apiVersion: "v1beta" },
//     );

//     // const prompt = "Who won Wimbledon this year?";
//     const result = await model.generateContent(request.data.prompt);
//     console.log(result);
//     return result;
//   });

// export const generateContent2 = https.onCall({ secrets: ["GEMINI_API_KEY"] },
//   async (request) => {
//     logger.info(request.data, { structuredData: true });
//     if (process.env.GEMINI_API_KEY == null) {
//       throw new https.HttpsError(
//         "unavailable", "GEMINI_API_KEY not found.");
//     }
//     const vertexAI = new VertexAI({
//       project: "realizealpha", // process.env.GOOGLE_PROJECT_ID,
//       location: "us-central1", // process.env.GOOGLE_VERTEXAI_LOCATION,
//     });

//     const googleSearchTool = {
//       googleSearch: {},
//     } as Tool;

//     const model = vertexAI.getGenerativeModel({
//       model: "gemini-2.0-flash-001",
//       tools: [googleSearchTool],
//     });

//     const { response } = await model.generateContent({
//       contents: [{ role: "user", parts: [{ text: request.data.prompt }] }],
//     });
//     return response;
//   });

export const generateContent31 = https.onCall({ secrets: ["GEMINI_API_KEY"] },
  async (request) => {
    if (!request.auth) {
      throw new https.HttpsError(
        "unauthenticated",
        "Authentication is required to use Gemini content generation.",
      );
    }
    logger.info(request.data, { structuredData: true });
    if (process.env.GEMINI_API_KEY == null) {
      throw new https.HttpsError(
        "unavailable", "GEMINI_API_KEY not found.");
    }
    const ai = new GoogleGenAI({
      apiKey: process.env.GEMINI_API_KEY,
    });
    const primaryModel = process.env.AI_MODEL_NAME || "gemini-3.1-flash-lite";

    let response;
    try {
      response = await ai.models.generateContent({
        model: primaryModel,
        contents: request.data.prompt,
        config: {
          tools: [{ googleSearch: {} }],
          maxOutputTokens: 800,
          temperature: 0.4,
        },
      });
    } catch (modelErr) {
      if (primaryModel !== "gemini-2.5-flash-lite") {
        logger.warn(
          `Model ${primaryModel} failed in generateContent, ` +
          "falling back to gemini-2.5-flash-lite",
          modelErr,
        );
        response = await ai.models.generateContent({
          model: "gemini-2.5-flash-lite",
          contents: request.data.prompt,
          config: {
            tools: [{ googleSearch: {} }],
            maxOutputTokens: 800,
            temperature: 0.4,
          },
        });
      } else {
        throw modelErr;
      }
    }

    return {
      candidates: response.candidates,
      text: response.text,
      modelVersion: response.modelVersion,
    };
  });

export const generateContent35 = generateContent31;
export const generateContent38 = generateContent31;
export const generateContent3 = generateContent31;

export const generateContent25 = https.onCall({ secrets: ["GEMINI_API_KEY"] },
  async (request) => {
    if (!request.auth) {
      throw new https.HttpsError(
        "unauthenticated",
        "Authentication is required to use Gemini content generation.",
      );
    }
    logger.info(request.data, { structuredData: true });
    if (process.env.GEMINI_API_KEY == null) {
      throw new https.HttpsError(
        "unavailable", "GEMINI_API_KEY not found.");
    }
    const ai = new GoogleGenAI({
      apiKey: process.env.GEMINI_API_KEY,
    });
    const primaryModel = process.env.AI_MODEL_NAME || "gemini-3.1-flash-lite";

    let response;
    try {
      response = await ai.models.generateContent({
        model: primaryModel,
        contents: request.data.prompt,
        config: {
          tools: [{ googleSearch: {} }],
          maxOutputTokens: 800,
          temperature: 0.4,
        },
      });
    } catch (modelErr) {
      if (primaryModel !== "gemini-2.5-flash-lite") {
        logger.warn(
          `Model ${primaryModel} failed in generateContent25, ` +
          "falling back to gemini-2.5-flash-lite",
          modelErr,
        );
        response = await ai.models.generateContent({
          model: "gemini-2.5-flash-lite",
          contents: request.data.prompt,
          config: {
            tools: [{ googleSearch: {} }],
            maxOutputTokens: 800,
            temperature: 0.4,
          },
        });
      } else {
        throw modelErr;
      }
    }

    return {
      candidates: response.candidates,
      text: response.text,
      modelVersion: response.modelVersion,
    };
  });

export const analyzePriceTargets = https.onCall({ secrets: ["GEMINI_API_KEY"] },
  async (request) => {
    if (!request.auth) {
      throw new https.HttpsError(
        "unauthenticated",
        "Authentication is required to analyze price targets.",
      );
    }
    logger.info(request.data, { structuredData: true });
    if (process.env.GEMINI_API_KEY == null) {
      throw new https.HttpsError(
        "unavailable", "GEMINI_API_KEY not found.");
    }
    const symbol = request.data.symbol;
    if (!symbol) {
      throw new https.HttpsError(
        "invalid-argument",
        "The function must be called with a 'symbol' argument.");
    }

    const db = getFirestore();
    const docRef = db.collection("ai_analysis").doc(symbol);
    const doc = await docRef.get();

    if (doc.exists) {
      const data = doc.data();
      if (data && data.last_updated) {
        const lastUpdated = new Date(data.last_updated);
        const now = new Date();
        const diffHours =
          Math.abs(now.getTime() - lastUpdated.getTime()) / 36e5;
        // Return cached data if less than 24 hours old
        if (diffHours < 24) {
          logger.info(`Returning cached analysis for ${symbol}`);
          return {
            candidates: [{
              content: {
                parts: [{
                  text: JSON.stringify(data),
                }],
              },
            }],
          };
        }
      }
    }

    const prompt = `
    Analyze the stock/option for symbol ${symbol}.
    Provide the following price targets and levels based on recent market data
    and technical analysis:
    1. Three support levels.
    2. Three resistance levels.
    3. One bullish price target for the next month with reasoning.
    4. One bearish price target for the next month with reasoning.
    5. A short analysis summary.
    6. A confidence score (0-100) for the analysis.
    7. A suggested investment horizon (e.g., "Short-term", "Long-term").
    8. Three key risks monitoring points.
    9. A fair value estimate with a low and high range, and the valuation
       method used.

    Return the response in strict JSON format with the following schema:
    {
      "support_levels": [{"price": number, "description": string}],
      "resistance_levels": [{"price": number, "description": string}],
      "bullish_target": {"price": number, "reasoning": string},
      "bearish_target": {"price": number, "reasoning": string},
      "summary": string,
      "confidence_score": number,
      "investment_horizon": string,
      "key_risks": [string],
      "fair_value": {
        "price": number,
        "high": number,
        "low": number,
        "method": string,
        "currency": "USD"
      },
      "last_updated": string (ISO date)
    }
    Do not include markdown code blocks (like \`\`\`json). Just the raw JSON.
    `;

    const ai = new GoogleGenAI({
      apiKey: process.env.GEMINI_API_KEY,
    });
    const primaryModel = process.env.AI_MODEL_NAME || "gemini-3.1-flash-lite";

    let response;
    try {
      response = await ai.models.generateContent({
        model: primaryModel,
        contents: prompt,
        config: {
          tools: [{ googleSearch: {} }],
          responseMimeType: "application/json",
          maxOutputTokens: 1200,
          temperature: 0.2,
        },
      });
    } catch (modelErr) {
      if (primaryModel !== "gemini-2.5-flash-lite") {
        logger.warn(
          `Model ${primaryModel} failed in analyzePriceTargets, ` +
          "falling back to gemini-2.5-flash-lite",
          modelErr,
        );
        response = await ai.models.generateContent({
          model: "gemini-2.5-flash-lite",
          contents: prompt,
          config: {
            tools: [{ googleSearch: {} }],
            responseMimeType: "application/json",
            maxOutputTokens: 1200,
            temperature: 0.2,
          },
        });
      } else {
        throw modelErr;
      }
    }

    // Cache the result
    const textContent = response.text ||
      response.candidates?.[0]?.content?.parts?.[0]?.text;
    if (textContent) {
      try {
        let text = textContent;
        // Strip markdown code blocks if present
        text = text.replace(/^```json\s*/, "").replace(/\s*```$/, "");
        const json = JSON.parse(text);
        // Ensure last_updated is set to now
        json.last_updated = new Date().toISOString();

        await docRef.set(json);
      } catch (e) {
        logger.error("Failed to parse or save AI response", e);
      }
    }

    return {
      candidates: response.candidates,
      text: response.text,
      modelVersion: response.modelVersion,
    };
  });

export const stressTestTradeThesis = https.onCall(
  { secrets: ["GEMINI_API_KEY"] },
  async (request) => {
    if (!request.auth) {
      throw new https.HttpsError(
        "unauthenticated",
        "Authentication is required to stress test trade thesis.",
      );
    }
    logger.info(request.data, { structuredData: true });
    if (process.env.GEMINI_API_KEY == null) {
      throw new https.HttpsError(
        "unavailable", "GEMINI_API_KEY not found.");
    }
    const symbol = request.data.symbol;
    if (!symbol) {
      throw new https.HttpsError(
        "invalid-argument",
        "The function must be called with a 'symbol' argument.");
    }
    const direction = (request.data.direction || "Bullish").trim();
    const thesis = request.data.thesis ?
      String(request.data.thesis).trim() : "";
    const currentPrice = request.data.currentPrice != null ?
      Number(request.data.currentPrice) : null;

    const cacheKey = `${symbol.toUpperCase()}_${direction.toLowerCase()}`;
    const db = getFirestore();
    const docRef = db.collection("ai_thesis_stress").doc(cacheKey);
    const doc = await docRef.get();

    if (doc.exists) {
      const data = doc.data();
      if (data && data.last_updated && !thesis) {
        const lastUpdated = new Date(data.last_updated);
        const now = new Date();
        const diffHours =
          Math.abs(now.getTime() - lastUpdated.getTime()) / 36e5;
        // Return cached data if less than 24 hours old and no custom user
        // thesis
        if (diffHours < 24) {
          logger.info(`Returning cached thesis stress test for ${cacheKey}`);
          return {
            candidates: [{
              content: {
                parts: [{
                  text: JSON.stringify(data),
                }],
              },
            }],
          };
        }
      }
    }

    const priceContext = currentPrice ?
      ` Current reference price: $${currentPrice.toFixed(2)}.` : "";
    const thesisContext = thesis ?
      ` Trader's expressed rationale: "${thesis}".` : "";

    const prompt = `
    You are an elite quantitative hedge fund risk manager and institutional
    Devil's Advocate for RealizeAlpha.
    Your mission is to perform a rigorous adversarial critique and stress test
    against a proposed ${direction} trading thesis on
    ${symbol}.${priceContext}${thesisContext}
    Actively counter confirmation bias. Highlight asymmetric downside risks,
    options volatility skew traps, upcoming event hazards, and macro
    vulnerabilities that the trader might be ignoring.

    Provide an adversarial stress test with:
    1. A Resilience Score from 0 to 100 (0-49: Fragile, 50-74: Moderate,
       75-100: Resilient).
    2. A categorical verdict: "Fragile", "Moderate", or "Resilient".
    3. A single, sharp "Killer Question" exposing the trade's greatest single
       vulnerability.
    4. 2-4 objective Counter-Arguments challenging the ${direction} thesis
       with severity ("High", "Medium", or "Low").
    5. 2-3 Skew Traps identifying options volatility skew, high IV
       percentile / post-earnings IV crush hazards, or negative gamma regime
       amplification.
    6. 2-3 Event Hazards identifying upcoming earnings, FOMC/macro catalysts,
       dividend ex-dates, or insider selling with timing, risk, and hazard
       level ("High", "Medium", or "Low").
    7. 2-3 Stress Scenarios modeling projected impact under market shocks
       (e.g. -5% SPY drop, +30% VIX surge, rate rise).
    8. A concise summary synthesizing the adversarial critique.

    Return the response in strict JSON format with the following schema:
    {
      "symbol": "${symbol.toUpperCase()}",
      "direction": "${direction}",
      "resilience_score": number,
      "verdict": "Fragile" | "Moderate" | "Resilient",
      "killer_question": string,
      "counter_arguments": [
        {
          "title": string,
          "argument": string,
          "severity": "High" | "Medium" | "Low"
        }
      ],
      "skew_traps": [
        {
          "title": string,
          "description": string,
          "severity": "High" | "Medium" | "Low"
        }
      ],
      "event_hazards": [
        {
          "event": string,
          "timing": string,
          "risk": string,
          "hazard_level": "High" | "Medium" | "Low"
        }
      ],
      "stress_scenarios": [
        {"scenario": string, "projected_impact": string, "assessment": string}
      ],
      "summary": string,
      "last_updated": string
    }
    Do not include markdown code blocks. Just the raw JSON.
    `;

    const ai = new GoogleGenAI({
      apiKey: process.env.GEMINI_API_KEY,
    });
    const primaryModel = process.env.AI_MODEL_NAME || "gemini-3.1-flash-lite";

    let response;
    try {
      response = await ai.models.generateContent({
        model: primaryModel,
        contents: prompt,
        config: {
          tools: [{ googleSearch: {} }],
          responseMimeType: "application/json",
          maxOutputTokens: 1400,
          temperature: 0.2,
        },
      });
    } catch (modelErr) {
      if (primaryModel !== "gemini-2.5-flash-lite") {
        logger.warn(
          `Model ${primaryModel} failed in stressTestTradeThesis, ` +
          "falling back to gemini-2.5-flash-lite",
          modelErr,
        );
        response = await ai.models.generateContent({
          model: "gemini-2.5-flash-lite",
          contents: prompt,
          config: {
            tools: [{ googleSearch: {} }],
            responseMimeType: "application/json",
            maxOutputTokens: 1400,
            temperature: 0.2,
          },
        });
      } else {
        throw modelErr;
      }
    }

    const textContent = response.text ||
      response.candidates?.[0]?.content?.parts?.[0]?.text;
    if (textContent) {
      try {
        let text = textContent;
        text = text.replace(/^```json\s*/, "").replace(/\s*```$/, "");
        const json = JSON.parse(text);
        json.last_updated = new Date().toISOString();
        if (!thesis) {
          await docRef.set(json);
        }
      } catch (e) {
        logger.error("Failed to parse or save AI response", e);
      }
    }

    return {
      candidates: response.candidates,
      text: response.text,
      modelVersion: response.modelVersion,
    };
  });

export const analyzeTradePostMortem = https.onCall(
  { secrets: ["GEMINI_API_KEY"] },
  async (request) => {
    if (!request.auth) {
      throw new https.HttpsError(
        "unauthenticated",
        "Authentication is required to perform trade post-mortem analysis.",
      );
    }
    logger.info(request.data, { structuredData: true });
    if (process.env.GEMINI_API_KEY == null) {
      throw new https.HttpsError("unavailable", "GEMINI_API_KEY not found.");
    }
    const symbol = request.data.symbol;
    if (!symbol) {
      throw new https.HttpsError(
        "invalid-argument",
        "The function must be called with a 'symbol' argument.",
      );
    }

    const tradeType = (request.data.tradeType || "Stock").trim();
    const side = (request.data.side || "Sell / Exit").trim();
    const entryPrice = request.data.entryPrice != null ?
      Number(request.data.entryPrice) : null;
    const exitPrice = request.data.exitPrice != null ?
      Number(request.data.exitPrice) : null;
    const realizedPnl = request.data.realizedPnl != null ?
      Number(request.data.realizedPnl) : null;
    const realizedPnlPercent = request.data.realizedPnlPercent != null ?
      Number(request.data.realizedPnlPercent) : null;
    const entryThesis = request.data.entryThesis ?
      String(request.data.entryThesis).trim() : "";
    const exitReason = request.data.exitReason ?
      String(request.data.exitReason).trim() : "";
    const holdingPeriod = request.data.holdingPeriod ?
      String(request.data.holdingPeriod).trim() : "";
    const orderHistory = request.data.orderHistory ?
      String(request.data.orderHistory).trim() : "";

    const ai = new GoogleGenAI({
      apiKey: process.env.GEMINI_API_KEY,
    });

    const primaryModel = process.env.GEMINI_MODEL || "gemini-3.1-flash-lite";

    const prompt = `
    You are an elite institutional trading psychologist, quantitative risk director, and behavioral trading coach for RealizeAlpha.
    Your mission is to perform a rigorous post-mortem analysis on a closed trade to evaluate execution quality, cognitive biases, and strategic alignment against the initial entry thesis.

    Trade Parameters:
    - Symbol: ${symbol.toUpperCase()}
    - Asset Type: ${tradeType}
    - Exit Action: ${side}
    ${entryPrice != null ? `- Entry Price: $${entryPrice.toFixed(2)}` : ""}
    ${exitPrice != null ? `- Exit Price: $${exitPrice.toFixed(2)}` : ""}
    ${realizedPnl != null ? `- Realized P&L: $${realizedPnl.toFixed(2)}` : ""}
    ${realizedPnlPercent != null ? `- Realized Return: ${realizedPnlPercent.toFixed(2)}%` : ""}
    ${holdingPeriod ? `- Holding Period / Duration: ${holdingPeriod}` : ""}
    ${entryThesis ? `- Original Entry Thesis: "${entryThesis}"` : "- Original Entry Thesis: (None specified / discretionary)"}
    ${exitReason ? `- Trader's Stated Exit Reason: "${exitReason}"` : "- Exit Reason: (Discretionary close / stop triggered)"}
    ${orderHistory ? `- Associated Execution Flow: ${orderHistory}` : ""}

    Conduct an in-depth post-mortem and provide:
    1. An Execution Quality Score (0 to 100):
       - 80-100: "Flawless Execution" (Disciplined plan execution regardless of outcome)
       - 60-79: "Acceptable Execution" (Minor timing or sizing imperfections)
       - 40-59: "Suboptimal Execution" (Hesitation, premature exit, or chased entry)
       - 0-39: "Disciplined Failure / Tilt" (FOMO entry, revenge exit, ignored stops)
    2. An Execution Grade: "A", "B", "C", "D", or "F".
    3. An Outcome Verdict: Categorize the trade outcome:
       - "Good Win" (Process followed, positive outcome)
       - "Bad Win" (Lucky outcome, flawed process / rules broken)
       - "Good Loss" (Disciplined loss, stop adhered to, good risk/reward)
       - "Bad Loss" (Disciplined failure, revenge trade, or oversized loser)
    4. Thesis Alignment Score (0 to 100): Did the actual trade play out the way the thesis predicted?
    5. Primary Cognitive Biases Detected (1 to 3 items):
       - Bias name (e.g., "FOMO / Chasing", "Disposition Effect", "Loss Aversion", "Revenge Trading", "Overconfidence", "Anchoring", "Premature Profit Taking", "None Detected")
       - Severity ("Low", "Moderate", "High", "Critical")
       - Evidence from the trade prices, duration, or thesis
       - Actionable Antidote / Behavioral Rx
    6. Execution Flaws (0 to 3 items): Specific mechanical flaws (e.g., "Slippage on Market Exit", "Held Past Invalidation Point", "No Hard Stop Placed", "Oversized Sizing Spikes") with severity ("High", "Medium", "Low")
    7. Tactical Lessons Learned: 2-3 concise, bulleted rules for future trades.
    8. Recommended Journal Tags: 3-5 tags for automatic behavioral tagging (e.g. ["#LossAversion", "#GoodLoss", "#EarningsTrade", "#StoppedOut", "#RuleFollowed"]).
    9. Coach Summary: 2-3 sentences synthesizing the diagnostic takeaway in an encouraging but uncompromising tone.

    Return the response in strict JSON format matching this schema:
    {
      "symbol": "${symbol.toUpperCase()}",
      "execution_score": number,
      "execution_grade": "A" | "B" | "C" | "D" | "F",
      "outcome_verdict": "Good Win" | "Bad Win" | "Good Loss" | "Bad Loss",
      "thesis_alignment_score": number,
      "detected_biases": [
        {
          "name": string,
          "severity": "Low" | "Moderate" | "High" | "Critical",
          "evidence": string,
          "mitigation": string
        }
      ],
      "execution_flaws": [
        {
          "title": string,
          "description": string,
          "severity": "High" | "Medium" | "Low"
        }
      ],
      "tactical_lessons": [
        string
      ],
      "auto_tags": [
        string
      ],
      "coach_summary": string
    }
    `;

    let response;
    try {
      response = await ai.models.generateContent({
        model: primaryModel,
        contents: prompt,
        config: {
          responseMimeType: "application/json",
          maxOutputTokens: 1400,
          temperature: 0.2,
        },
      });
    } catch (modelErr) {
      if (primaryModel !== "gemini-2.5-flash-lite") {
        logger.warn(
          `Model ${primaryModel} failed in analyzeTradePostMortem, ` +
          "falling back to gemini-2.5-flash-lite",
          modelErr,
        );
        response = await ai.models.generateContent({
          model: "gemini-2.5-flash-lite",
          contents: prompt,
          config: {
            responseMimeType: "application/json",
            maxOutputTokens: 1400,
            temperature: 0.2,
          },
        });
      } else {
        throw modelErr;
      }
    }

    return {
      candidates: response.candidates,
      text: response.text,
      modelVersion: response.modelVersion,
    };
  });


