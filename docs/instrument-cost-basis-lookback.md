# Instrument Previous Positions & Cost Basis Lookback

## Overview

RealizeAlpha provides complete historical visibility into previously held and closed positions for any instrument. Instead of only displaying active open holdings or fragmented raw orders, the **Instrument Previous Positions & Cost Basis Lookback** engine reconstructs complete historical trading cycles (round trips) directly from filled order records (`/orders/`, `/positions/?nonzero=false`, and Paper Trading stores).

Traders can audit their historical performance per ticker, analyze entry/exit execution quality, track realized P&L, evaluate holding period lengths, and examine win/loss ratios across every historical round trip.

---

## Key Capabilities

### 1. FIFO Lot-Matching & Cycle Reconstruction
- **Automated Round-Trip Detection:** Scans chronological filled buy and sell orders. When a user begins accumulating shares from a zero balance, a new position cycle is initiated.
- **Accurate Cost Basis Allocation:** Applies First-In, First-Out (FIFO) tax lot matching across multiple partial fills and incremental adds.
- **Cycle Closure:** When net share inventory returns to zero, the position cycle is closed, timestamped, and evaluated for net realized P&L, hold duration, and return percentage.
- **Concurrent Active Position Handling:** If the user currently holds shares in the instrument, prior completed cycles are classified as closed historical positions, while the ongoing cycle reflects active holding metrics.

### 2. Historical Round-Trip Metrics
For each historical position cycle:
- **Date Range & Holding Period:** Exact opening fill date, closing fill date, and elapsed duration (e.g. `15 days`, `2.3 mos`).
- **Average Buy Price (Cost Basis):** Total capital committed divided by total shares bought:
  $$\text{Average Buy Price} = \frac{\sum (\text{Shares}_{\text{buy}} \times \text{Price}_{\text{buy}})}{\sum \text{Shares}_{\text{buy}}}$$
- **Average Sell Price (Exit Price):** Total gross proceeds received divided by total shares sold:
  $$\text{Average Sell Price} = \frac{\sum (\text{Shares}_{\text{sell}} \times \text{Price}_{\text{sell}})}{\sum \text{Shares}_{\text{sell}}}$$
- **Realized P&L:**
  $$\text{Realized P\&L} = \text{Total Proceeds} - \text{Total Cost Basis}$$
- **Realized Return Percentage:**
  $$\text{Return \%} = \frac{\text{Realized P\&L}}{\text{Total Cost Basis}} \times 100$$
- **Order Audit Trail:** Complete list of all constituent orders within the cycle, displaying side, fill quantity, average execution price, fill timestamp, and order total.

### 3. Aggregate Lookback Summary
- **Total Realized P&L:** Net dollar profit/loss realized across all completed cycles for this ticker.
- **Win Rate:** Percentage of historical cycles closed with positive P&L:
  $$\text{Win Rate} = \frac{\text{Winning Cycles}}{\text{Total Completed Cycles}} \times 100$$
- **Average Hold Duration:** Mean holding time across historical cycles.
- **Historical Execution Spread:** Visual bar comparing Volume-Weighted Average Buy Price vs. Volume-Weighted Average Sell Price with net dollar and percentage spread.
- **Total Volume & Shares Traded:** Cumulative volume and turnover executed in this instrument.

---

## UI Components

### `InstrumentHistoricalPositionsWidget` (`lib/widgets/instrument_historical_positions_widget.dart`)
- **Hero Card:** Placed in the Instrument Details page (`instrument_widget.dart`) across Overview, Activity, and All tabs.
- **Summary Metrics Grid:** Fast-glance chips for Win Rate, Average Hold Duration, Volume-Weighted Average Buy Price, and Average Sell Price.
- **Execution Spread Bar:** Visual representation of entry cost vs exit proceeds with color-coded spread indication (green for positive, red for negative).
- **Historical Cycles List:** Chronologically sorted list of closed cycles with date spans, total shares, buy $\to$ sell prices, realized P&L badges, and hold duration chips.
- **Round-Trip Detail Modal:** Interactive bottom sheet opened by tapping any cycle, displaying comprehensive holding period details, cost basis metrics, and an itemized ledger of filled orders.

---

## Testing & Verification

- **Unit Tests (`test/instrument_historical_position_test.dart`):**
  - Empty orders edge-case handling.
  - Single profitable round-trip FIFO verification.
  - Multi-lot buys and staggered sells matching.
  - Fractional share trading precision.
  - Active unclosed position handling alongside historical closed cycles.
  - Filter validation (ignoring cancelled and rejected orders).
- **Widget Tests (`test/instrument_historical_positions_widget_test.dart`):**
  - Clean omission when no historical trades exist.
  - Render validation for summary chips, P&L badges, and spread bars.
  - Interaction test for bottom sheet modal opening and order display.
