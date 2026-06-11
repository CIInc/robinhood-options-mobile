/**
 * Integration & Unit Tests for Gamma Exposure GEX data validation
 */

import { initializeApp } from "firebase-admin/app";
initializeApp({ projectId: "demo-project" });

import { describe, it, expect } from "@jest/globals";
import {
  computeGammaExposure,
  evaluateGammaExposure,
  GammaExposureData,
} from "../src/gamma-exposure";

describe("Gamma Exposure (GEX) Data Validation", () => {
  const mockOptionsChain = {
    options: [
      {
        calls: [
          {
            strike: 100,
            impliedVolatility: 0.25,
            openInterest: 1000,
          },
          {
            strike: 105,
            impliedVolatility: 0.22,
            openInterest: 5000, // Call Wall target
          },
        ],
        puts: [
          {
            strike: 95,
            impliedVolatility: 0.28,
            openInterest: 3000, // Put Wall target
          },
          {
            strike: 100,
            impliedVolatility: 0.26,
            openInterest: 800,
          },
        ],
      },
    ],
  };

  it("should correctly compute total Net GEX and positioning", () => {
    const symbol = "AAPL";
    const spotPrice = 101.5;

    const gexData: GammaExposureData = computeGammaExposure(
      symbol,
      spotPrice,
      mockOptionsChain
    );

    expect(gexData.symbol).toBe(symbol);
    expect(gexData.spotPrice).toBe(spotPrice);
    expect(gexData.gexByStrike.length).toBeGreaterThan(0);

    // Call and Put Walls validation
    expect(gexData.callWall).toBe(105);
    expect(gexData.putWall).toBe(95);

    // net GEX and ratio validation
    expect(gexData.gexRatio).toBeGreaterThanOrEqual(0.0);
    expect(gexData.gexRatio).toBeLessThanOrEqual(1.0);
    expect(gexData.totalCallGEX).toBeDefined();
    expect(gexData.totalPutGEX).toBeDefined();
    expect(gexData.totalNetGEX).toBe(
      gexData.totalCallGEX - gexData.totalPutGEX
    );
  });

  it("should evaluate Gamma Exposure trading signal context", () => {
    // A mock of extremely high long gamma (net long gamma)
    const longGexData: GammaExposureData = {
      symbol: "TSLA",
      spotPrice: 205,
      totalCallGEX: 50000000,
      totalPutGEX: 20000000,
      totalNetGEX: 30000000, // > 1e6
      gammaFlip: 200,
      maxGammaStrike: 205,
      gexByStrike: [],
      dealerPositioning: "long_gamma",
      signalStrength: 80,
      updatedAt: Date.now(),
      callWall: 210,
      putWall: 190,
      gexRatio: 0.71,
      riskFreeRate: 0.05,
    };

    const result = evaluateGammaExposure(longGexData);
    expect(result.signal).toBe("BUY");
    expect(result.reason).toContain("dealers long gamma");
    expect(result.metadata?.dealerPositioning).toBe("long_gamma");
  });

  it("should evaluate short gamma and price below flip context", () => {
    const shortGexData: GammaExposureData = {
      symbol: "NVDA",
      spotPrice: 90,
      totalCallGEX: 10000000,
      totalPutGEX: 40000000,
      totalNetGEX: -30000000, // < -1e6
      gammaFlip: 100,
      maxGammaStrike: 95,
      gexByStrike: [],
      dealerPositioning: "short_gamma",
      signalStrength: 50,
      updatedAt: Date.now(),
      callWall: 110,
      putWall: 80,
      gexRatio: 0.2,
      riskFreeRate: 0.05,
    };

    const result = evaluateGammaExposure(shortGexData);
    expect(result.signal).toBe("SELL");
    expect(result.reason).toContain("dealers short gamma");
    expect(result.metadata?.dealerPositioning).toBe("short_gamma");
  });

  it("should return HOLD for neutral positioning below threshold", () => {
    const neutralGexData: GammaExposureData = {
      symbol: "SPY",
      spotPrice: 500,
      totalCallGEX: 300000,
      totalPutGEX: 200000,
      totalNetGEX: 100000, // < 1e6 threshold
      gammaFlip: 500,
      maxGammaStrike: 500,
      gexByStrike: [],
      dealerPositioning: "neutral",
      signalStrength: 2,
      updatedAt: Date.now(),
      callWall: 505,
      putWall: 495,
      gexRatio: 0.6,
      riskFreeRate: 0.05,
    };

    const result = evaluateGammaExposure(neutralGexData);
    expect(result.signal).toBe("HOLD");
    expect(result.reason).toContain("neutral dealer positioning");
  });
});
