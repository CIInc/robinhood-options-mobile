// import * as functions from 'firebase-functions';
import * as https from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
// import {
//   // DynamicRetrievalMode,
//   GoogleGenerativeAI,
// } from "@google/generative-ai";
import { VertexAI, type Tool } from "@google-cloud/vertexai";

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

export const generateContent25 = https.onCall({ secrets: ["GEMINI_API_KEY"] },
  async (request) => {
    logger.info(request.data, { structuredData: true });
    if (process.env.GEMINI_API_KEY == null) {
      throw new https.HttpsError(
        "unavailable", "GEMINI_API_KEY not found.");
    }
    const vertexAI = new VertexAI({
      project: "realizealpha", // process.env.GOOGLE_PROJECT_ID,
      location: "us-central1", // process.env.GOOGLE_VERTEXAI_LOCATION,
    });

    const googleSearchTool = {
      googleSearch: {},
    } as Tool;

    const model = vertexAI.getGenerativeModel({
      model: "gemini-2.5-flash-lite",
      tools: [googleSearchTool],
    });

    const { response } = await model.generateContent({
      contents: [{ role: "user", parts: [{ text: request.data.prompt }] }],
    });
    return response;
  });
