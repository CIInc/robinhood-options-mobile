# Macro Assessment

## Overview

The Macro Assessment engine provides a real-time, quantitative evaluation of the overall market environment. It analyzes 19 institutional-grade macroeconomic indicators to determine the current risk regime: **RISK_ON**, **RISK_OFF**, or **NEUTRAL**. This assessment is used to inform trading decisions, adjust risk parameters, and provide context for automated strategies.

## Core Components

The assessment algorithm aggregates data from 19 indicators across four primary pillars:

### 1. Volatility (VIX & MOVE)
*   **VIX (Equities):** We analyze the CBOE Volatility Index to gauge market fear. Low VIX (< 20) is constructive, while spikes above 30 indicate high stress.
*   **MOVE (Bonds):** The Treasury Volatility Index measures stability in the bond market. Elevated MOVE readings often precede equity de-risking.

### 2. Credit & Liquidity
*   **Yield Curve (10Y-3M):** Monitors growth expectations. Inversions (negative values) are primary recession warnings.
*   **Credit Health (HYG):** Tracks high-yield corporate bonds. Weakness often precedes broad equity sell-offs.
*   **Credit Spreads (LQD):** Comparing investment-grade bonds against Treasuries reveals corporate borrowing stress.
*   **Banking Health (KRE):** Regional banks act as the primary transmission mechanism for domestic liquidity.

### 3. Market Internals & Breadth
*   **Market Trend (SPY):** Analyzes the S&P 500 against its 200-day moving average to define the primary trend.
*   **Advance/Decline (NYA):** Measures the net number of stocks rising versus falling to confirm trend quality.
*   **Breadth Quality (RSP/SPY):** Compares equal-weight vs. cap-weight performance to detect high-concentration fragility.
*   **Small Caps (IWM):** Outperformance in small caps is a key sign of "risk-on" rotation.

### 4. Global Context & Sentiment
*   **Put/Call Ratio (PCCR):** Extremes act as powerful contrarian signals for market reversals.
*   **Global Risk (EEM):** Monitors stress in emerging markets and global liquidity.
*   **Global Leadership (FXI):** China's credit cycle often leads global risk sentiment.
*   **Commodities (Copper, Gold, Oil):** Dr. Copper tracks industrial demand, while Gold serves as a safe haven and inflation hedge.
*   **Risk Appetite (BTC):** Bitcoin acts as a leading indicator for global speculative liquidity.

## Scoring & Weighting System

The engine computes a **Weighted Macro Score (0-100)** using specific importance factors for each indicator:

| Indicator | Weight | Pillar |
| :--- | :--- | :--- |
| **VIX** | 15% | Volatility |
| **Market Trend (SPY)** | 15% | Trend |
| **TNX / Yield Curve** | 20% | Rates |
| **Credit (HYG/LQD)** | 13% | Credit |
| **Breadth (NYA/RSP)** | 7% | Internals |
| **Others (BTC, Commodities, DXY)** | 30% | Macro Context |

### Status Thresholds:
*   **65-100 (RISK ON):** Constructive environment. Standard or aggressive sizing favored.
*   **36-64 (NEUTRAL):** Mixed signals. Caution and selective rotation advised.
*   **0-35 (RISK OFF):** Defensive posture. Focus on capital preservation and hedging.

## Integration

### Macro Widget
The **Macro Market State** card provides an at-a-glance view of the current status, score, trend icons, and additional indicators (Put/Call, A/D, Risk Appetite).

### Macro Assessment Dashboard
A dedicated dashboard view (`MacroAssessmentDashboardWidget`) expands the assessment into detailed panels:
- **Indicators Pulse:** A 19-pillar heatmap providing a real-time snapshot of every indicator's signal and trend.
- **Detailed Indicator Sheets:** Tap any pillar to see its current value, momentum tracking, weighted impact, and descriptive analysis.
- **Regime Transition Matrices:** Visualization of "Signal Breadth" to see if the majority of indicators confirm the current status.
- **Dynamic Charting:** Interactive gauge with a multi-color progress gradient representing the current Macro Score.

## Automated Trading Integration

*   **Adaptive Position Sizing:** In `RISK_OFF` regimes, automated agents are programmed to automatically reduce position sizes (e.g., 50% reduction).
*   **Regime-Aware Strategy Selection:**
    *   **Risk-On:** Priority on Bull Call Spreads, Long Calls, and Cash Secured Puts.
    *   **Risk-Off:** Priority on Bear Put Spreads, Long Puts, and Covered Calls.
    *   **Neutral:** Priority on Iron Condors, Calendar Spreads, and Butterfly Spreads.
*   **RiskGuard Enforcement:** Advanced risk controls use macro status as a multiplier for sector limits and drawdown protection.

## Historical Tracking

The **AgenticTradingProvider** now maintains a history of previous macro assessments. This enables:
*   **Trend Visualization:** Displaying whether the market regime is improving or deteriorating.
*   **Signal Correlation:** Analyzing how indicator changes correspond to past performance.
*   **Regime Transition Alerts:** Notifications when the macro score crosses key thresholds (e.g., crossing from Neutral to Risk Off).
