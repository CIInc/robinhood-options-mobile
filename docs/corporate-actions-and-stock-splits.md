# Corporate Action Stock Splits & Cash-in-Lieu Tracking

## Overview

RealizeAlpha provides complete visibility and auditability into stock splits, reverse splits, position share adjustments, and fractional share cash-in-lieu disbursements via the **Corporate Action Splits & Cash-in-Lieu Dashboard** (`/corp_actions/v2/split_payments/` and `/instruments/{id}/splits/`).

Stock splits and reverse splits significantly alter share count and per-share cost basis while keeping total invested capital neutral (except for fractional share liquidation). This feature ensures investors understand their post-split tax lot basis, tracks cash received for fractional shares, and explains Form 1099-B tax reporting implications.

---

## Key Capabilities

### 1. Stock Split Tracking & Adjustment Factors
- **Forward Splits & Reverse Splits:** Automatic detection and labeling of forward splits (e.g., NVIDIA `10:1`, Tesla `3:1`, Apple `4:1`) and reverse splits (e.g., Biora Therapeutics `1:25`).
- **Split Ratio Calculation:** Formatted ratio representations (`newShares : oldShares`) and mathematical adjustment multiplier factors ($oldShares / newShares$) for historical per-share prices and cost basis adjustments.
- **Pre- & Post-Split Share Reconciliation:** Precise tracking of shares held before execution and shares received or consolidated post-effective date.

### 2. Cash-in-Lieu (CIL) Disbursements & Tracking
- **Fractional Share Liquidation:** When a reverse or forward split results in a fractional remaining share, clearing houses liquidate the fraction into cash. RealizeAlpha records the exact cash payout amount, per-share liquidation rate, and fractional quantity.
- **Hero Metrics:** Total lifetime cash-in-lieu received across all accounts and total completed corporate split actions.
- **Direct Payout Date Records:** Clear recording of payment execution dates and settlement timestamps.

### 3. Tax Lot Cost Basis & Form 1099-B Transparency
- **Tax Neutrality Education:** Highlights that stock splits are non-taxable events under IRC Section 305(a), where the original cost basis is spread across new shares without realizing capital gains or losses.
- **Cash-in-Lieu Tax Reporting (Form 1099-B Box 1d):** Explains how cash-in-lieu payments represent a taxable disposition of fractional shares reported on IRS Form 1099-B (Box 1d), requiring capital gain/loss calculation against the fractional allocated basis.
- **Adjusted Cost Basis Formula:** In-app inspection cards showing how original cost per share is adjusted by the split factor.

### 4. Search, Filtering & Deep Linking
- **Filter Chips:** Instant filtering between `All`, `Forward Splits`, `Reverse Splits`, and splits with `Cash-in-Lieu`.
- **Search Bar:** Real-time query matching across symbol, company name, and ratio description.
- **Instrument SDP Integration:** Seamless one-tap deep linking from the "Stock Splits" section header on any stock's detail page (`InstrumentWidget`) straight into the Corporate Actions dashboard with pre-filtered symbol context.

---

## Architecture & Data Flow

```
Robinhood API Endpoints
  ├── /corp_actions/v2/split_payments/      (Account-specific split payments & CIL cash)
  └── /instruments/{id}/splits/             (Instrument-level historical split records)
           │
           ▼
IBrokerageService / RobinhoodService / DemoService
  ├── getSplitPayments()                        ──► Raw API response
  ├── getSplitPaymentsModel()                   ──► List<SplitPayment>
  └── getCorporateActionSplitsSummary()         ──► CorporateActionSplitsSummary
           │
           ▼
CorporateActionsWidget (Dashboard & Detail Sheet)
  ├── Hero Summary Card (Total Cash-in-Lieu, Completed Splits)
  ├── Search Bar & Filter Chips (All, Forward, Reverse, Cash-in-Lieu)
  ├── Split Payment Cards
  │     ├── Ticker symbol & Company name
  │     ├── Forward / Reverse split badge & ratio
  │     ├── Pre-split shares ➔ Post-split shares
  │     ├── Cash-in-Lieu payment badge
  │     └── Effective execution date
  ├── Split Detail Modal Bottom Sheet
  │     ├── Execution summary & status
  │     ├── Share count reconciliation
  │     ├── Cost basis adjustment factor & formula
  │     ├── Cash-in-Lieu breakdown (rate, fractional quantity)
  │     └── Tax treatment info (IRC Sec. 305(a), Form 1099-B Box 1d)
  └── Educational FAQ Modal Dialog
```

---

## Data Models (`lib/model/split.dart`)

### `Split`
Represents an individual stock split corporate action for an equity instrument:
- `id`: Unique corporate action identifier.
- `instrument`: Instrument resource URL.
- `executionDate`: Effective date of the split.
- `divisor` & `multiplier`: Split terms (e.g. multiplier 10, divisor 1 for a 10:1 split).
- `ratio`: Formatted ratio string (e.g. `10:1`).
- `isReverseSplit` / `isForwardSplit`: Directional helper flags.
- `adjustmentFactor`: Price multiplier factor ($divisor / multiplier$).

### `SplitPayment`
Represents the actual split execution and cash disbursement for a specific user holding:
- `id`: Unique payment record ID.
- `account`: Account number or identifier.
- `symbol`: Equity ticker symbol.
- `instrumentName`: Full company or instrument name.
- `ratio`: Split ratio string.
- `splitMultiplier` & `splitDivisor`: Term factors.
- `oldShares` & `newShares`: Shares held before and after split execution.
- `cashInLieu`: Dollar amount received for liquidated fractional shares.
- `cashInLieuRate`: Per-share rate at which fractional shares were liquidated.
- `cashInLieuShares`: Exact fractional share quantity liquidated.
- `hasCashInLieu`: Convenience boolean check.
- `effectiveDate`: Settlement / payment date.

### `CorporateActionSplitsSummary`
Aggregated overview across corporate action history:
- `totalCashInLieu`: Cumulative cash-in-lieu dollars received.
- `totalSplitsCount`: Total number of corporate actions recorded.
- `forwardSplitsCount`: Count of forward splits.
- `reverseSplitsCount`: Count of reverse splits.
- `splitsWithCashInLieuCount`: Number of splits resulting in cash compensation.

---

## UI Components & Integration Points

1. **`CorporateActionsWidget` (`lib/widgets/corporate_actions_widget.dart`):**
   - Main dashboard widget supporting symbol filter pre-selection, live keyword search, dynamic chips, empty states, pull-to-refresh, detail modal sheets, and FAQ dialogs.
2. **User Settings (`lib/widgets/user_widget.dart`):**
   - Added under "Banking & Documents" as "Corporate Actions & Splits" navigation `ListTile`.
3. **Account Header (`lib/widgets/user_info_widget.dart`):**
   - Added "Corporate Actions" actionable badge chip in the account summary header.
4. **Instrument Detail Page (`lib/widgets/instrument_widget.dart`):**
   - Added "Adjustments" trailing text button to the "Stock Splits" section header, deep-linking into `CorporateActionsWidget(filterSymbol: instrument.symbol)`.

---

## Testing & Quality Assurance

- **Unit Tests (`test/split_test.dart`):**
  - Validation of forward and reverse split models, ratio formatting, adjustment factors, and JSON roundtrip serialization.
  - Validation of `CorporateActionSplitsSummary` mathematical aggregations.
  - Service testing with `DemoService` ensuring realistic fixtures (`NVDA`, `TSLA`, `AAPL`, `BIOR`).
- **Widget Tests (`test/corporate_actions_widget_test.dart`):**
  - Render verification of hero cards, metric counters, and payment cards.
  - Search and filter chip interaction tests.
  - Modal bottom sheet inspection and tax basis breakdown display.
  - Educational FAQ dialog verification.
