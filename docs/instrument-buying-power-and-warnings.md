# Instrument-Specific Buying Power & Trade Warnings

## Overview

RealizeAlpha integrates first-party brokerage endpoints for **Instrument-Specific Buying Power** (`/accounts/{account}/instrument_buying_power/{instrument_id}/`) and **Trade Warnings & Regulatory Disclosures** (`/instruments/{instrument_id}/v2/warnings/`).

Rather than relying solely on global account-level purchasing power, traders have real-time transparency into how individual security margin haircuts, cash-only rules, and regulatory restrictions affect their available buying power, maximum order size, short-selling capacity, and risk disclosures before submitting orders.

---

## Key Capabilities

### 1. Instrument-Specific Buying Power
- **Precision Purchasing Power:** Displays the true dollar capacity available to buy a specific equity or derivative based on brokerage risk rules, rather than generic portfolio cash or buying power.
- **Margin Requirement Haircuts:**
  - **Standard Marginable Equities:** Standard 50% initial margin and 30%–35% FINRA maintenance margin requirements.
  - **Elevated Margin / Concentrated Positions:** Higher haircuts (e.g. 75% or 100% initial margin) on volatile equities, high short-interest names, or leveraged ETFs.
  - **100% Cash Required:** Non-marginable stocks, penny stocks, and volatile securities requiring 100% settled cash collateral with no margin borrowing permitted.
- **Capacity Calculations:**
  - `maxShares`: Calculated maximum shares purchasable at current price with allocated instrument buying power.
  - `shortBuyingPower` & `maxShortShares`: Dedicated buying power and maximum share allowance for opening short positions.
  - `leverageRatio`: Effective buying power multiplier (e.g., 2.0x for 50% marginable, 1.0x for cash-only).

### 2. Trade Warnings & Risk Disclosures
- **First-Party Robinhood Warnings (`/instruments/{id}/v2/warnings/`):**
  - **High Volatility Warnings:** Alerts when extreme intraday price swings or speculative surges are detected.
  - **Illiquidity & Wide Spreads:** Cautions on low-volume equities or wide bid/ask spreads where market orders risk significant slippage.
  - **Bankruptcy & Delisting:** High-visibility critical alerts when a company files for Chapter 11 or faces delisting.
  - **Reverse Stock Splits:** Notifications for recent or upcoming corporate action splits that may impact position basis and odd lots.
  - **Regulatory Halts:** Immediate trading restriction notices when trading is halted by exchanges or FINRA.
  - **Leveraged & Inverse Products:** FINRA-mandated disclosures regarding daily rebalancing and volatility decay.
- **Severity Hierarchy:**
  - **Critical Risk (Red):** Halts, bankruptcy, or direct trading restrictions.
  - **Warning (Amber):** High volatility, elevated maintenance margin, or wide spreads.
  - **Notice (Blue):** Information on corporate actions or reverse splits.

---

## UI Components & Workflow

### 1. Order Entry Screen (`TradeInstrumentWidget`)
- **Prominent Warnings Banner:** Displayed at the top of the order form and order review screen when any active trade warnings exist for the security.
- **Instrument Buying Power Row:** Replaces generic buying power with the instrument-specific figure, accompanied by a status chip (e.g., `50% Initial Margin` or `100% Cash Required`).
- **Short Buying Power Context:** Automatically adapts when a user selects "Sell" on a symbol they do not hold to indicate shorting capacity.
- **Tap for Inspection:** Tapping the row opens the detailed `InstrumentBuyingPowerSheet`.

### 2. Instrument Details View (`InstrumentWidget`)
- **Post-Chart Warning Banner:** Positioned right beneath the price chart to guarantee immediate visibility before drilling into signals, options, or news.
- **Market Quote Sizing Tile:** Embedded in the Overview and All tabs for fast inspection of purchasing capacity and margin rules.

### 3. Modal Bottom Sheet (`InstrumentBuyingPowerSheet`)
- **Purchasing Capacity Breakdown:** Buying power, estimated max purchasable shares, short buying power, and max short shares.
- **Margin Terms Breakdown:** Initial margin requirement percentage, maintenance margin requirement percentage, and effective leverage.
- **Disclosures & Disclaimers:** Color-coded warning cards with full text, severity badges, and FINRA Rule 4210 explanation footnote.
