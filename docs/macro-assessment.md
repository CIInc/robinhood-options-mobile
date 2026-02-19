# Macro Assessment

## Overview

The Macro Assessment engine provides a real-time, quantitative evaluation of the overall market environment. It analyzes key macroeconomic indicators to determine the current risk regime: **RISK_ON**, **RISK_OFF**, or **NEUTRAL**. This assessment is used to inform trading decisions, adjust risk parameters, and provide context for automated strategies.

## Core Components

The assessment algorithm aggregates data from three primary pillars:

### 1. Volatility (VIX)
We analyze the CBOE Volatility Index (VIX) to gauge market fear and sentiment.
*   **Low VIX (< 20):** Suggests a stable environment favorable for equities (Bullish).
*   **High VIX (> 30):** Indicates high stress and potential downside risk (Bearish).
*   **Trend:** Rising VIX is a leading indicator of market corrections.

### 2. Market Breadth & Sentiment
We monitor internal market dynamics to identify strength and exhaustion.
*   **Put/Call Ratio:** Gauges option market sentiment. Extreme levels signal potential reversals.
*   **Advance/Decline (A/D):** Measures the number of advancing vs. declining stocks to confirm trend strength.
*   **Risk Appetite:** A synthetic indicator derived from high-beta vs. low-beta asset performance.

### 3. Bond Yields (TNX)
We monitor the 10-Year Treasury Yield (TNX) to understand the interest rate environment.
*   **Rapidly Rising Yields:** Often headwinds for growth stocks and equities (Bearish).
*   **Stable/Falling Yields:** generally supportive of equity valuations (Bullish).

### 4. Market Trend (Market Width)
We analyze the price action of major indices (SPY, QQQ) against their long-term Moving Averages (SMA 200, SMA 50).
*   **Price > SMA 200:** Long-term uptrend.
*   **Price < SMA 50:** Short-term weakness.

## Scoring System

The engine computes a **Macro Score (0-100)**:
*   **80-100 (Strong Risk On):** All systems go. Aggressive strategies favored.
*   **60-79 (Risk On):** Constructive market. Standard sizing.
*   **40-59 (Neutral):** Mixed signals. Caution advised.
*   **20-39 (Risk Off):** Defensive posture. Reduce exposure.
*   **0-19 (Strong Risk Off):** High danger. Capital preservation mode.

## Historical Tracking

The **AgenticTradingProvider** now maintains a history of previous macro assessments. This enables:
*   **Trend Visualization:** Displaying whether the market regime is improving or deteriorating.
*   **Signal Correlation:** Analyzing how indicator changes correspond to past performance.
*   **Regime Transition Alerts:** Notifications when the macro score crosses key thresholds (e.g., crossing from Neutral to Risk Off).

## Integration

### Macro Widget
The **Macro Market State** card provides an at-a-glance view of the current status, score, trend icons, and additional indicators (Put/Call, A/D, Risk Appetite).

### Automated Trading
*   **Position Sizing:** In `RISK_OFF` environments, automated agents (and manual RiskGuard) can automatically reduce position sizes (e.g., cutting allocation by 50%) to preserve capital.
*   **Strategy Selection:** Certain strategies may be disabled or prioritized based on the macro regime.
