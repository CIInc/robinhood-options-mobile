# AI Devil's Advocate & Trade Thesis Stress Tester

Automated adversarial critique generating objective Bear vs. Bull counter-arguments, skew traps, and event hazards before entering trades.

## Overview

Traders frequently fall prey to confirmation bias—seeking only data points and narratives that validate their directional view. The **AI Devil's Advocate & Trade Thesis Stress Tester** acts as an adversarial quantitative risk manager embedded directly into the trading workflow.

Before entering a stock, option, or spread order, users can submit their trade direction (Bullish, Bearish, or Neutral) and optional trade thesis to receive a rigorous, objective adversarial critique that highlights blind spots, tail risks, options volatility skew hazards, and imminent event risks.

## Key Capabilities

### 1. Categorical Resilience Score (0–100)
- **Fragile (0–49)**: Severe structural headwinds, elevated volatility skew hazards, or imminent calendar catalysts disproportionately skew the trade against the user.
- **Moderate (50–74)**: Viable thesis with manageable risks, but clear counter-arguments or event hazards require defined stop-loss or hedge protection.
- **Resilient (75–100)**: Asymmetric favorable risk-reward where the prevailing thesis demonstrates high durability against adversarial scenarios.

### 2. The Killer Question (Stress Point)
A provocative, single-sentence stress point designed to pinpoint the greatest vulnerability in the proposed trade (e.g. *"If hyperscaler capex cycles normalize in Q4, how does multiple compression affect Blackwell margins?"*).

### 3. Objective Counter-Arguments
Presents 2–4 detailed arguments directly challenging the user's premise with explicit risk severity ratings (`High`, `Medium`, `Low`).
- For **Bullish** theses: Evaluates valuation multiples, deceleration in growth metrics, supply chain dependencies, and macroeconomic headwinds.
- For **Bearish** theses: Evaluates short squeeze potential, recurring cash flows, margin expansion catalysts, and downside multiple support.
- For **Neutral** theses: Evaluates breakout/breakdown volatility triggers that threaten range-bound strategies.

### 4. Skew Traps & Options Volatility Hazards
Specifically analyzes derivatives pricing hazards:
- **Implied Volatility (IV) Skew Inversion**: Detects whether out-of-the-money options carry punitive volatility premia.
- **IV Crush Vulnerabilities**: Flags elevated percentile IV (e.g., 85th+ percentile) where time decay and post-catalyst IV collapse degrade contract value.
- **Negative Gamma Regimes**: Assesses dealer gamma exposure ($-\text{GEX}$) that may exacerbate adverse moves against the position.

### 5. Event Hazards & Calendar Traps
Extracts imminent event risks:
- **Earnings Announcements**: Historical 1-day earnings move vs. straddle pricing.
- **Macroeconomic & Central Bank Decisions**: FOMC announcements, CPI prints, rate decisions.
- **Ex-Dividend Dates**: Early option assignment risk on short calls.
- **Corporate & Regulatory Actions**: FDA approval deadlines, antitrust rulings, insider sales.

### 6. Stress Scenario Matrix
Projects estimated price and P&L impacts under standardized market shock scenarios:
- Broad Market Selloff ($-5\%$ SPY drop)
- Volatility Shock ($+30\%$ VIX surge)
- Interest Rate Spikes or Tech Multiple Compression

## Architecture & Integration

```
┌─────────────────────────────────┐
│     Client UI Layer             │
│  - InstrumentWidget (Research)  │
│  - TradeInstrumentWidget        │
│  - TradeOptionWidget            │
│  - DevilsAdvocateWidget         │
└────────────────┬────────────────┘
                 │
                 ▼
┌─────────────────────────────────┐
│     GenerativeService (Dart)    │
│  - analyzeDevilsAdvocate()      │
└────────────────┬────────────────┘
                 │
                 ▼
┌─────────────────────────────────┐
│  Firebase Cloud Functions (v2)  │
│  - stressTestTradeThesis        │
│  - GoogleGenAI (Gemini 3.1)     │
│  - Fallback: Gemini 2.5 Flash   │
│  - Firestore Cache:             │
│    ai_thesis_stress/{key}       │
└─────────────────────────────────┘
```

### Access Points
1. **Instrument Details (`InstrumentWidget`)**: Embedded in the Research section alongside `PriceTargetsWidget`.
2. **Equity Order Entry (`TradeInstrumentWidget`)**: Dedicated "Devil's Advocate (Stress Test Thesis)" button launching a modal review before placing market/limit orders.
3. **Options Order Entry (`TradeOptionWidget`)**: Integrated pre-trade modal automatically configured for Calls vs. Puts.
