import { handleAgenticDecision } from "../src/agentic-agent";

// Mock @google/genai
const mockGenerateContent = jest.fn();

jest.mock("@google/genai", () => {
  return {
    GoogleGenAI: jest.fn().mockImplementation(() => ({
      models: {
        generateContent: mockGenerateContent,
      },
    })),
  };
});

describe("handleAgenticDecision", () => {
  const originalEnv = process.env;

  beforeEach(() => {
    jest.clearAllMocks();
    process.env = { ...originalEnv, GEMINI_API_KEY: "test-api-key" };
  });

  afterAll(() => {
    process.env = originalEnv;
  });

  const mockMarketData = {
    closes: [150.0, 151.0, 152.0],
    volumes: [1000000, 1100000, 1200000],
    currentPrice: 152.0,
  };

  const mockMultiIndicatorResult = {
    overallSignal: "BUY",
    signalStrength: 85,
    reason: "Trend and momentum are strongly aligned",
    indicators: {
      marketDirection: {
        metadata: { fastMA: 151.0, slowMA: 148.0 },
      },
      momentum: { value: 62.5 },
    },
  };

  const mockMacroAssessment = {
    status: "RISK_ON",
    score: 80,
    reason: "Low volatility and credit spread stability",
  };

  const mockGexData = {
    totalCallGEX: 250000000,
    totalPutGEX: 120000000,
    totalNetGEX: 130000000,
    dealerPositioning: "long_gamma",
    pTrans: 150.0,
    nTrans: 145.0,
    plusGex: 160.0,
    cotmp: 146.0,
    gexByStrike: [
      { strike: 145.0, callOI: 500, putOI: 4000 },
      { strike: 150.0, callOI: 2000, putOI: 3000 },
      { strike: 160.0, callOI: 8000, putOI: 500 },
    ],
  };

  const mockPortfolioState = {
    buyingPower: 25000.0,
    positions: 3,
  };

  const mockConfig = {
    smaPeriodFast: 10,
    smaPeriodSlow: 50,
    rsiPeriod: 14,
    tradeQuantity: 1,
  };

  it("successfully parses CONFIRMED decision with 11-rule evaluation", async () => {
    const mockDecisionJson = {
      signal: "BUY",
      reason: "All 11 GEX rules pass, Spot above pTrans, and R/R ratio is 4.0",
      confidence: 90,
      quantity: 1,
      status: "approved",
      qualification: "CONFIRMED",
      rewardRiskRatio: 4.0,
      ruleEvaluation: {
        rule1_call_gex_positive: true,
        rule2_call_exceeds_put: true,
        rule3_spot_above_cotmp: true,
        rule4_target_above_spot: true,
        rule5_ptrans_above_ntrans: true,
        rule6_spot_above_ptrans: true,
        rule7_oi_above_10k: true,
        rule8_iv_below_rv: true,
        rule9_oi_depth_target: true,
        rule10_net_spot_gamma_positive: true,
        rule11_rv10_compressed: true,
      },
    };

    mockGenerateContent.mockResolvedValueOnce({
      text: JSON.stringify(mockDecisionJson),
    });

    const result = await handleAgenticDecision(
      "AAPL",
      "1d",
      mockMarketData,
      mockMultiIndicatorResult,
      mockMacroAssessment,
      mockGexData,
      mockPortfolioState,
      mockConfig
    );

    expect(result.signal).toBe("BUY");
    expect(result.status).toBe("approved");
    expect(result.qualification).toBe("CONFIRMED");
    expect(result.ruleEvaluation.rule1_call_gex_positive).toBe(true);
    expect(result.ruleEvaluation.rule6_spot_above_ptrans).toBe(true);
    expect(result.agentic).toBe(true);

    // Verify prompt contains the 11 Rules of GEX Options Trading
    const callArgs = mockGenerateContent.mock.calls[0][0];
    expect(callArgs.contents).toContain("THE 11 RULES OF GEX OPTIONS TRADING");
    expect(callArgs.contents).toContain("1. Total Call GEX is Positive (> 0)");
    expect(callArgs.contents).toContain("2. Call GEX > Absolute Put GEX");
    expect(callArgs.contents).toContain("3. Spot Price > COTMP");
    expect(callArgs.contents).toContain("5. pTrans > nTrans");
    expect(callArgs.contents).toContain("6. Spot Price > pTrans");
    expect(callArgs.contents).toContain("11. 10-day Realized Volatility <= 35%");
  });

  it("correctly handles BLOCKED decision when negative gamma or filters fail", async () => {
    const mockDecisionJson = {
      signal: "HOLD",
      reason: "Blocked: Spot is below pTrans ($150) and below COTMP ($146)",
      confidence: 30,
      quantity: 0,
      status: "rejected",
      qualification: "BLOCKED",
      rewardRiskRatio: 0.5,
      ruleEvaluation: {
        rule1_call_gex_positive: true,
        rule2_call_exceeds_put: false,
        rule3_spot_above_cotmp: false,
        rule4_target_above_spot: true,
        rule5_ptrans_above_ntrans: true,
        rule6_spot_above_ptrans: false,
        rule7_oi_above_10k: true,
        rule8_iv_below_rv: false,
        rule9_oi_depth_target: true,
        rule10_net_spot_gamma_positive: false,
        rule11_rv10_compressed: true,
      },
    };

    mockGenerateContent.mockResolvedValueOnce({
      text: JSON.stringify(mockDecisionJson),
    });

    const result = await handleAgenticDecision(
      "AAPL",
      "1d",
      mockMarketData,
      mockMultiIndicatorResult,
      mockMacroAssessment,
      mockGexData,
      mockPortfolioState,
      mockConfig
    );

    expect(result.signal).toBe("HOLD");
    expect(result.status).toBe("rejected");
    expect(result.qualification).toBe("BLOCKED");
    expect(result.ruleEvaluation.rule6_spot_above_ptrans).toBe(false);
  });
});
