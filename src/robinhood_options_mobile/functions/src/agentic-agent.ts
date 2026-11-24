import * as logger from "firebase-functions/logger";
import { GoogleGenAI } from "@google/genai";

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

  const ai = new GoogleGenAI({
    apiKey: process.env.GEMINI_API_KEY,
  });

  const lastPrice = marketData.closes[marketData.closes.length - 1];
  const indicators = multiIndicatorResult.indicators;
  const smaFast = indicators?.marketDirection?.metadata?.fastMA?.toFixed(2) ||
    "N/A";
  const smaSlow = indicators?.marketDirection?.metadata?.slowMA?.toFixed(2) ||
    "N/A";
  const rsi = indicators?.momentum?.value?.toFixed(2) || "N/A";
  const lastVol = marketData.volumes?.[marketData.volumes.length - 1] ?? 0;
  const vol = lastVol.toLocaleString();

  const rawMacroPolicy = config?.macroRiskOffPolicy;
  const macroPolicy =
    rawMacroPolicy === "ignore" ||
    rawMacroPolicy === "reduceSize" ||
    rawMacroPolicy === "blockEntries" ?
      rawMacroPolicy :
      (config?.reduceSizeOnRiskOff ? "reduceSize" : "ignore");

  const enabledEntries = config?.enabledIndicators ?
    Object.entries(config.enabledIndicators).filter(([, v]) => v === true) :
    [];
  const indicatorBreakdown = enabledEntries.length > 0 ?
    enabledEntries.map(([key]) => {
      const ind = indicators?.[key];
      return ind ?
        `${key}: ${ind.signal} (${ind.reason || "N/A"})` :
        `${key}: N/A`;
    }).join("\n    ") :
    "All default indicators";

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
    User Enabled Indicators:
    ${indicatorBreakdown}
  `;

  const macroSummary = macroAssessment ? `
    Status: ${macroAssessment.status}
    Score: ${macroAssessment.score}
    Reason: ${macroAssessment.reason}
  ` : "N/A";

  const rawReduction = config?.riskOffSizeReduction;
  const reductionPct = typeof rawReduction === "number" &&
    Number.isFinite(rawReduction) ?
    Math.round(Math.min(1, Math.max(0, rawReduction)) * 100) :
    50;

  let macroPolicySection: string;
  if (macroPolicy === "blockEntries") {
    macroPolicySection = `
### 🧭 MACRO RISK POLICY
User Risk Management Policy: Block New Entries on RISK_OFF.
- When Macro Assessment status is RISK_OFF, reject new BUY entries
  (set signal to HOLD and status to rejected).
`;
  } else if (macroPolicy === "reduceSize") {
    macroPolicySection = `
### 🧭 MACRO RISK POLICY
User Risk Management Policy: Reduce Size on RISK_OFF (${reductionPct}% cut).
- Portfolio risk management already scales down BUY position size during
  RISK_OFF downstream.
- Treat RISK_OFF as regime context (favor quality trend or oversold
  mean-reversion setups), NOT as an automatic veto on BUY entries.
`;
  } else {
    macroPolicySection = `
### 🧭 MACRO RISK POLICY
User Risk Management Policy: Ignore Macro RISK_OFF.
- Do NOT veto technically valid BUY setups solely because macro status is
  RISK_OFF.
`;
  }

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

  const useGexRules = Boolean(gexData) &&
    config?.enabledIndicators?.gammaExposure !== false;

  const missionSection = useGexRules ? `
You are the GEX Orchestrator, a specialized trading agent for a
rules-based system.
Your job is to strictly enforce daily scan analysis, grade setups, and track
positions using exact system mechanics.` : `
You are a quantitative equity trading agent for a rules-based system.
Evaluate price action, user-enabled technical indicators, deterministic algo
feedback, and the user's Macro Risk Policy to issue disciplined BUY, SELL, or
HOLD decisions.`;

  const rubricSection = useGexRules ? `
### 📐 THE 11 RULES OF GEX OPTIONS TRADING
1. Total Call GEX is Positive (> 0): Broad dealer gamma positioning is
   positive, confirming a supportive market microstructure.
2. Call GEX > Absolute Put GEX: Bullish upside-hedging flow exceeds bearish
   downside-hedging flow.
3. Spot Price > COTMP: Underlier Spot resides above Center of Put Mass
   (downside hedging firewall).
4. Target +GEX Strike > Spot: Primary +GEX upside target (T1 Target) sits above
   Spot, defining a viable upside trajectory.
5. pTrans > nTrans: Positive Transition boundary sits above Negative Transition
   floor.
6. Spot Price > pTrans: Entry trigger condition. Safe watchdowns allow pending
   triggers near this boundary.
7. Total Open Interest > 10,000: Confirms option chain depth and liquidity to
   avoid wide bid/ask spreads.
8. Implied Volatility (IV30) < Realized Volatility (HV90): Option pricing is
   structurally undervalued relative to historical movement, indicating
   favorable premium entry.
9. OI Depth at Target Strike: Open Interest at targeted +GEX strike is maximal
   relative to nearby option strikes.
10. Net Spot Gamma is Positive: Dealer positioning at the underlier's
    closest-to-the-money strike is net positive.
11. 10-day Realized Volatility <= 35%: Confirms volatility compression on the
    underlier, laying groundwork for clean breakouts.

### 🎯 SETUP QUALIFICATION & STATUS CRITERIA
- CONFIRMED (BUY): All 11 rules pass, Reward-to-Risk ratio
  ( (+GEX - Spot) / (Spot - pTrans) ) >= 2.0, and spot is above pTrans.
- PENDING (HOLD): All filters pass, but spot is inside watchdog buffer near
  pTrans.
- BLOCKED (HOLD / SELL): One or more filters or risk gates failed. No buy entry
  permitted.` : `
### 🎯 TECHNICAL & PRICE-ACTION EVALUATION CRITERIA
- Do NOT reject or default to "HOLD" because GEX or options-chain data is
  unavailable.
- Base your decision on price trend relative to SMAs, momentum/oscillator
  readings, the user's enabled indicators, and the user's Macro Risk Policy.
- CONFIRMED (BUY): Bullish technical alignment, breakout/continuation, or
  compelling oversold mean-reversion setup supported by enabled indicators and
  permitted by the Macro Risk Policy.
- PENDING (HOLD): Mixed or inconclusive technical setup with insufficient edge.
- BLOCKED (HOLD / SELL): Strong bearish trend breakdown with no reversal setup,
  or blocked by the user's Macro Risk Policy.`;

  const ruleEvalSchema = useGexRules ? `{
    "rule1_call_gex_positive": boolean,
    "rule2_call_exceeds_put": boolean,
    "rule3_spot_above_cotmp": boolean,
    "rule4_target_above_spot": boolean,
    "rule5_ptrans_above_ntrans": boolean,
    "rule6_spot_above_ptrans": boolean,
    "rule7_oi_above_10k": boolean,
    "rule8_iv_below_rv": boolean,
    "rule9_oi_depth_target": boolean,
    "rule10_net_spot_gamma_positive": boolean,
    "rule11_rv10_compressed": boolean
  }` : "null";

  const closingGuidance = useGexRules ? `
When GEX Structural Levels are provided:
- Apply the 11 Rules of GEX Options Trading in conjunction with Deterministic
  Algo Feedback, Market Context, and Macro Assessment.
- CONFIRMED: GEX structural rules pass and technicals confirm -> BUY.
- PENDING: GEX rules pass, but spot is inside watchdog buffer -> HOLD.
- BLOCKED: Critical risk or negative gamma rules fail -> HOLD or SELL.` : `
Evaluate setups using the User Enabled Indicators, Deterministic Algo Feedback,
Market Context, and the Macro Risk Policy above without requiring GEX data.`;

  const fullPrompt = `${missionSection}

### 🛰️ MISSION
Maximize precision, eliminate emotional discretion, and maintain absolute
quantitative discipline.

### 📊 MARKET CONTEXT
${marketSummary}

### 📏 DETERMINISTIC ALGO FEEDBACK
${algoSummary}

### 🌍 MACRO ASSESSMENT
${macroSummary}
${macroPolicySection}
### 🤖 GEX STRUCTURAL LEVELS
${gexSummary}

### 🛡️ PORTFOLIO STATE
${portfolioSummary}
${rubricSection}

Provide your decision in a strict JSON format:
{
  "signal": "BUY" | "SELL" | "HOLD",
  "reason": "Clear explanation of the decision",
  "confidence": 0-100,
  "quantity": number,
  "status": "approved" | "rejected",
  "qualification": "CONFIRMED" | "PENDING" | "BLOCKED",
  "rewardRiskRatio": number | null,
  "ruleEvaluation": ${ruleEvalSchema}
}

Ensure the "status" is "approved" only if you want to execute a
trade (BUY/SELL).
Otherwise, set status to "rejected" and signal to "HOLD".
${closingGuidance}

Output ONLY the JSON.
`;

  try {
    const primaryModel = process.env.AI_MODEL_NAME || "gemini-3.1-flash-lite";
    let response;
    try {
      response = await ai.models.generateContent({
        model: primaryModel,
        contents: fullPrompt,
        config: {
          responseMimeType: "application/json",
          maxOutputTokens: 600,
          temperature: 0.1,
        },
      });
    } catch (modelErr) {
      if (primaryModel !== "gemini-2.5-flash-lite") {
        logger.warn(
          `Model ${primaryModel} failed in agentic decision, ` +
          "falling back to gemini-2.5-flash-lite",
          modelErr,
        );
        response = await ai.models.generateContent({
          model: "gemini-2.5-flash-lite",
          contents: fullPrompt,
          config: {
            responseMimeType: "application/json",
            maxOutputTokens: 600,
            temperature: 0.1,
          },
        });
      } else {
        throw modelErr;
      }
    }

    const text = response.text ||
      response.candidates?.[0]?.content?.parts?.[0]?.text;
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
