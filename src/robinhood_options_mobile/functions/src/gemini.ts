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
