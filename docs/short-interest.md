# Short Float & Live Borrow Availability

RealizeAlpha integrates first-party Robinhood market data to provide real-time short interest fundamentals, live borrow availability, fee rates, and short squeeze risk modeling directly within the instrument view.

## Overview

Short selling data is a critical component of institutional risk assessment, sentiment analysis, and short squeeze trade setups. High short interest relative to free float, coupled with high Days to Cover (DTC) and spiking borrow fee rates, creates asymmetric upside volatility when positive catalysts force short sellers to cover simultaneously.

## Core Features

### 1. Short Float & Squeeze Metrics
- **Short % of Free Float (`pc_freefloat`):** The proportion of tradeable public shares currently sold short. Levels exceeding 10% represent elevated crowding; levels above 20% signal extreme squeeze vulnerability.
- **Days to Cover (DTC / Short Ratio):** The ratio of aggregate short interest to average daily trading volume ($\frac{\text{Shares Short}}{\text{Average Daily Volume}}$). Values above 4–5 days indicate illiquid covering conditions that exacerbate price spikes.
- **Current vs Prior Shares Short:** Total shares currently shorted compared to the previous settlement cycle, displaying net share change and percentage change.
- **Free Float & Average Volume:** Total public float and 30-day average daily volume providing context on equity liquidity.
- **FINRA Settlement Date:** The official regulatory reporting date for the short position baseline.

### 2. Real-Time Shorting & Borrow Rates
- **Live Borrow Inventory:** Real-time broker availability tiers (`HIGH`, `MEDIUM`, `LOW`, `NONE`) indicating immediate shorting capacity.
- **Annualized Borrow Fee Rate:** The current annual interest rate charged by lenders to borrow shares for short sales. Low rates (0.25%–1.0%) reflect Easy to Borrow (ETB) conditions; elevated rates (>5%) or spikes (>15%) reflect scarce supply.
- **Hard to Borrow (HTB) Status & Reason:** Explicit alerts when an equity is subject to borrow restrictions, high borrowing fees, or strict locate requirements.
- **Margin Requirement:** Maintenance and initial margin requirement percentage for short positions (e.g., 150%–200%).
- **Locate Requirement:** Real-time verification of whether a locate pre-check is mandated prior to order submission.

### 3. Automated Short Squeeze Risk Scoring

The system computes a multi-factor `ShortSqueezeRisk` rating (`Low`, `Moderate`, `Elevated`, `High`, `Extreme`) based on three pillars:

1. **Float Congestion:** Scaled from free float short percentage (<5% = Low, 5–10% = Moderate, 10–20% = Elevated, 20–30% = High, >30% = Extreme).
2. **Cover Illiquidity:** Boosted when Days to Cover $\ge 4.0$ (liquidity friction) or $\ge 8.0$ (severe congestion).
3. **Borrow Scarcity:** Boosted when Hard to Borrow status is active, inventory is `LOW`, or borrow fee rate $\ge 5\%$ / $\ge 15\%$.

Each tier provides actionable risk descriptions and color-coded status badges.

## Architecture & Data Flow

### Endpoints
- **Short Interest Fundamentals:** `https://api.robinhood.com/marketdata/fundamentals/short/v1/?ids={instrument_id}&start_date={startDate}`
- **Live Shorting Availability & Borrow Fees:** `https://api.robinhood.com/instruments/{instrument_id}/shorting/`

### Service Interface
- `IBrokerageService.getShortInterest(BrokerageUser user, String instrumentId, {String? startDate})`
- `IBrokerageService.getShortingAvailability(BrokerageUser user, String instrumentId)`
- Implemented in `RobinhoodService` (live production endpoints) and `DemoService` (deterministic mock environment for offline and testing workflows).

### Models & Widgets
- **Models:** [lib/model/short_interest.dart](src/robinhood_options_mobile/lib/model/short_interest.dart) (`ShortInterest`, `ShortingAvailability`, `ShortInterestSummary`, `ShortSqueezeRisk`, `BorrowCostLevel`).
- **UI Component:** [lib/widgets/short_interest_widget.dart](src/robinhood_options_mobile/lib/widgets/short_interest_widget.dart) (`ShortInterestWidget`).
- **Instrument Integration:** Embedded in [lib/widgets/instrument_widget.dart](src/robinhood_options_mobile/lib/widgets/instrument_widget.dart) CustomScrollView slivers for equity instruments.

## Testing & Verification

Unit and widget tests validate model parsing, risk scoring, demo responses, and responsive layout across standard and compact screen sizes:

```sh
flutter test test/short_interest_test.dart test/short_interest_widget_test.dart
```
