import * as logger from "firebase-functions/logger";
import { VertexAI } from "@google-cloud/vertexai";

/**
 * Handle Agentic decision making using a full prompt derived from wip repo.
 * @param {string} symbol - The ticker symbol.
 * @param {string} interval - The chart interval.
 * @param {any} marketData - The market data.
 * @param {any} multiIndicatorResult - The deterministic algo result.
 * @param {any} macroAssessment - The macro market assessment.
 * @param {any} gexData - The gamma exposure data.
 * @param {any} portfolioState - Current portfolio state.
 * @param {any} config - Trading configuration.
 * @return {Promise<any>} The agentic decision result.
 */
export async function handleAgenticDecision(
  symbol: string,
  interval: string,
  marketData: any,
  multiIndicatorResult: any,
  macroAssessment: any,
  gexData: any,
  portfolioState: any,
  config: any
) {
  logger.info(`🤖 Agentic Decision initiated for ${symbol} (${interval})`);

  if (!process.env.GEMINI_API_KEY) {
    throw new Error("GEMINI_API_KEY not found in environment secrets.");
  }

  const vertexAI = new VertexAI({
    project: "realizealpha",
    location: "us-central1",
  });

  const model = vertexAI.getGenerativeModel({
    model: "gemini-3.1-flash-lite",
    generationConfig: {
      responseMimeType: "application/json",
      maxOutputTokens: 250,
      temperature: 0.1,
    },
  });

  const lastPrice = marketData.closes[marketData.closes.length - 1];
  const indicators = multiIndicatorResult.indicators;
  const smaFast = indicators.marketDirection?.metadata?.fastMA?.toFixed(2) ||
    "N/A";
  const smaSlow = indicators.marketDirection?.metadata?.slowMA?.toFixed(2) ||
    "N/A";
  const rsi = indicators.momentum?.value?.toFixed(2) || "N/A";
  const lastVol = marketData.volumes[marketData.volumes.length - 1];
  const vol = lastVol.toLocaleString();

  // Format summaries for the prompt
  const marketSummary = `
    Symbol: ${symbol}
    Current Price: $${lastPrice.toFixed(2)}
    Interval: ${interval}
    SMA Fast (${config.smaPeriodFast}): ${smaFast}
    SMA Slow (${config.smaPeriodSlow}): ${smaSlow}
    RSI (${config.rsiPeriod}): ${rsi}
    Volume: ${vol}
  `;

  const algoSummary = `
    Overall Signal: ${multiIndicatorResult.overallSignal}
    Signal Strength: ${multiIndicatorResult.signalStrength}/100
    Reasoning: ${multiIndicatorResult.reason}
  `;

  const macroSummary = macroAssessment ? `
    Status: ${macroAssessment.status}
    Score: ${macroAssessment.score}
    Reason: ${macroAssessment.reason}
  ` : "N/A";

  const totalOI = gexData?.gexByStrike ?
    gexData.gexByStrike.reduce(
      (sum: number, s: any) => sum + (s.callOI || 0) + (s.putOI || 0),
      0
    ) :
    0;

  const gexSummary = gexData ? `
    Total Call GEX: $${(gexData.totalCallGEX / 1e6).toFixed(2)}M
    Total Put GEX: $${(gexData.totalPutGEX / 1e6).toFixed(2)}M
    Total Net GEX: $${(gexData.totalNetGEX / 1e6).toFixed(2)}M
    Total Open Interest: ${totalOI.toLocaleString()} contracts
    Dealer Positioning: ${gexData.dealerPositioning}
    pTrans: ${gexData.pTrans != null ? `$${gexData.pTrans.toFixed(2)}` : "N/A"}
    nTrans: ${gexData.nTrans != null ? `$${gexData.nTrans.toFixed(2)}` : "N/A"}
    +GEX (T1): ${gexData.plusGex != null ?
    `$${gexData.plusGex.toFixed(2)}` : "N/A"}
    COTMP: ${gexData.cotmp != null ? `$${gexData.cotmp.toFixed(2)}` : "N/A"}
  ` : "N/A (Options/GEX chain data not available for this instrument)";

  const portfolioSummary = `
    Buying Power: $${portfolioState.buyingPower?.toFixed(2) || "0.00"}
    Total Positions: ${portfolioState.positions || 0}
    Current Position in ${symbol}: ${portfolioState[symbol]?.quantity || 0}
  `;

  const fullPrompt = `
You are the GEX Orchestrator, a specialized trading agent for a 
rules-based system.
Your job is to strictly enforce daily scan analysis, grade setups, and track 
positions using exact system mechanics.

### 🛰️ MISSION
Maximize precision, eliminate emotional discretion, and maintain absolute 
quantitative discipline.

### 📊 MARKET CONTEXT
${marketSummary}

### 📏 DETERMINISTIC ALGO FEEDBACK
${algoSummary}

### 🌍 MACRO ASSESSMENT
${macroSummary}

### 🤖 GEX STRUCTURAL LEVELS
${gexSummary}

### 🛡️ PORTFOLIO STATE
${portfolioSummary}

### 📐 THE 11 RULES OF GEX OPTIONS TRADING
1. Total Call GEX exceeds absolute value of Total Put GEX.
2. Underlier Spot price is above Center of Put Mass (COTMP).
3. Largest positive GEX target strike (+GEX / T1 Target) is above stock Spot.
4. Positive transition (pTrans) sits above negative transition (nTrans).
5. Stock Spot price sits above pTrans (entry trigger rule).
6. Total Open Interest (OI) exceeds 10,000 contracts for structural depth.
7. 30-day option IV30 is below historical 90-day realized volatility (HV90).
8. Open Interest depth at the +GEX target strike exceeds all other strikes.
9. Dealer net gamma positioning at the current Spot is net positive.
10. Underlier's 10-day realized volatility (RV10) is compressed (<= 35%).
11. Reward/Risk ratio ( (+GEX - Spot) / (Spot - pTrans) ) >= 2.0.

Analyze the data provided. Decide if we should BUY, SELL, or HOLD.
- CONFIRMED: All filters pass, and spot is above pTrans.
- PENDING: All filters pass, but spot is inside watchdog buffer.
- BLOCKED: One or more filters failed. No action permitted.

Provide your decision in a strict JSON format:
{
  "signal": "BUY" | "SELL" | "HOLD",
  "reason": "Clear explanation of the decision",
  "confidence": 0-100,
  "quantity": number,
  "status": "approved" | "rejected"
}

Ensure the "status" is "approved" only if you want to execute a 
trade (BUY/SELL).
Otherwise, set status to "rejected" and signal to "HOLD".

When GEX Structural Levels are provided:
- Apply the 11 Rules of GEX Options Trading in conjunction with Deterministic
  Algo Feedback, Market Context, and Macro Assessment.
- CONFIRMED: GEX structural rules pass and technicals confirm -> BUY.
- PENDING: GEX rules pass, but spot is inside watchdog buffer -> HOLD.
- BLOCKED: Critical risk or negative gamma rules fail -> HOLD or SELL.

When GEX Structural Levels are NOT provided ("N/A") (e.g., no active options
chain or GEX unavailable):
- Do NOT reject or default to "HOLD" merely because GEX is N/A.
- Instead, perform the analysis using the Deterministic Algo Feedback,
  Technical Indicators (SMA, RSI, Volume), and Macro Assessment.
- If the technical indicators and macro regime are strongly bullish and
  aligned, you may issue a BUY signal based on technical and macro strength,
  noting that GEX was unavailable.

Output ONLY the JSON.
`;

  try {
    const { response } = await model.generateContent({
      contents: [{ role: "user", parts: [{ text: fullPrompt }] }],
      generationConfig: {
        responseMimeType: "application/json",
        maxOutputTokens: 250,
        temperature: 0.1,
      },
    });

    const text = response.candidates?.[0].content.parts[0].text;
    if (!text) {
      logger.error(`Empty response from Gemini for ${symbol}`, {
        response: JSON.stringify(response),
      });
      throw new Error("Empty response from Gemini");
    }

    // Extract JSON from response (handle markdown blocks if any)
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      logger.error(`No JSON found in response for ${symbol}`, {
        rawText: text,
      });
      throw new Error("No JSON found in response");
    }

    let decision;
    try {
      decision = JSON.parse(jsonMatch[0]);
    } catch (e) {
      logger.error(`Failed to parse JSON for ${symbol}`, {
        jsonText: jsonMatch[0],
        error: e,
      });
      throw new Error(`Invalid JSON format in response: ${e}`);
    }

    logger.info(`🤖 Agentic Decision for ${symbol}: ` +
      `${decision.signal} - ${decision.reason}`);

    return {
      ...decision,
      agentic: true,
      rawResponse: text,
    };
  } catch (error) {
    logger.error("Error in handleAgenticDecision", error);
    throw error;
  }
}
