# Landscape Charting & Multi-Column Matrix View

The **Landscape Charting & Multi-Column Matrix View** (`MultiLegMatrixOrderEntryWidget`, [#117](https://github.com/CIInc/robinhood-options-mobile/issues/117)) provides a professional-grade widescreen charting and execution environment for tablet, desktop, and mobile landscape orientations.

It combines full-width interactive technical charts with a collapsible, responsive split-screen multi-leg options matrix—allowing options traders to visually identify technical levels (support, resistance, moving averages, and VWAP) while simultaneously configuring and pricing complex multi-leg options orders in real time.

---

## Overview & Motivation

When analyzing charts on standard mobile portrait layouts, options traders frequently experience disjointed context switching:
1. Navigating away from the candlestick chart to view the option chain.
2. Manually calculating spread widths, net debits/credits, and breakeven levels without visual reference to underlying price history.
3. Returning to the chart to re-evaluate key support/resistance levels.

The **Landscape Chart Matrix** eliminates this friction by leveraging the horizontal viewport:
- **Left Panel**: High-resolution interactive candlestick and area price charts with technical indicator overlays (SMA, EMA, VWAP, Bollinger Bands) and benchmark comparisons.
- **Right Panel**: Collapsible multi-leg order matrix with interactive leg builder, live net debit/credit pricing, risk/reward payoff bounds, and 1-tap order submission.

```
+----------------------------------------------------------------------------------------------------+
| FullScreenInstrumentChartWidget (Landscape Mode)                                                   |
+----------------------------------------------------+-----------------------------------------------+
| Left Panel: Technical Chart                        | Right Panel: Multi-Leg Order Matrix           |
|                                                    |                                               |
|  [Symbol: NVDA $128.50 (+3.2%)]                    |  [Strategy: Bull Call Spread] [Presets v]     |
|  ------------------------------------------------  |  -------------------------------------------  |
|  Candlestick / Area Chart with Overlays            |  Leg 1: BUY  CALL $125.00 Exp: Oct 18  $6.20  |
|  - SMA 20 / SMA 50 / VWAP                          |  Leg 2: SELL CALL $135.00 Exp: Oct 18  $2.10  |
|  - Volume Histogram / Time Series Markers          |  -------------------------------------------  |
|                                                    |  Net Debit: $4.10 ($410.00 / contract)        |
|                                                    |  Max Profit: $5.90 ($590.00) | Max Loss: $410 |
|                                                    |  Risk/Reward: 1.44:1 | Breakeven: $129.10     |
|                                                    |  [Qty: 1] [Limit: $4.10] [TIF: GTC]           |
|                                                    |  [====== REVIEW & SUBMIT SPREAD ======]       |
+----------------------------------------------------+-----------------------------------------------+
```

---

## Architecture & Core Components

### 1. Data Models (`lib/model/multi_leg_order_entry.dart`)

The multi-leg execution framework is driven by two primary models:

- **`MultiLegOrderLeg`**: Represents an individual contract leg:
  - `action`: `LegAction.buy` or `LegAction.sell`
  - `type`: `LegType.call` or `LegType.put`
  - `strike`: Contract strike price
  - `expirationDate`: Target expiration date
  - `ratio`: Contract quantity multiplier per strategy unit (default `1`)
  - `premium`: Mark price per share
  - `signedPremium`: Computes net cash flow contribution (negative for buy/outflow, positive for sell/inflow)

- **`MultiLegOrderEntry`**: Strategy container managing aggregate pricing and risk metrics:
  - `strategyType`: `StrategyType.vertical`, `straddle`, `strangle`, `iron_condor`, `custom`, etc.
  - `netPremium`: Sum of signed leg premiums ($\sum \text{signedPremium}$). Positive indicates Net Credit; negative indicates Net Debit.
  - `maxProfitPerContract` & `maxLossPerContract`: Closed-form profit and loss limits based on spread width and debit/credit structure.
  - `breakevenPoints`: Dynamic calculation of underlying prices at expiration where P&L is exactly \$0.
  - `riskRewardRatio`: Ratio of maximum potential profit to maximum potential loss.

### 2. UI Components

- **`MultiLegMatrixOrderEntryWidget` (`lib/widgets/multi_leg_matrix_order_entry_widget.dart`)**:
  - Embedded alongside widescreen landscape charts or displayed as a standalone order sheet.
  - Interactive leg modifier with strike steppers, expiration selectors, and action toggles (Buy/Sell, Call/Put).
  - Strategy preset selector for instant setup:
    - **Bull Call Spread / Bear Put Spread** (Debit Verticals)
    - **Bull Put Spread / Bear Call Spread** (Credit Verticals)
    - **Long Straddle / Strangle** (Volatility Expansion)
    - **Iron Condor** (Range-Bound Credit)
  - Real-time order summary chip row displaying Net Debit/Credit, Max Profit, Max Loss, Breakeven, and Risk/Reward.
  - Quantity controls, order type selection (Limit vs. Market), limit price override, and Time-in-Force (`gtc` / `day`).

- **`FullScreenInstrumentChartWidget` & `InstrumentChartWidget`**:
  - Enhanced with responsive layout detection (`MediaQuery.of(context).orientation == Orientation.landscape` or wide display width).
  - Split-view toggle allowing users to expand or collapse the order matrix without interrupting chart interaction or scrubbing.
  - Preserves chart time series zoom and pan states during order matrix interactions.

---

## Technical Features & Error Resilience

During the development of the Landscape Chart Matrix, several core serialization and type safety hardening measures were implemented:

1. **Defensive Snapshot Serialization**:
   - `OptionChain.expirationDates` serialization converts mapped iterables to a concrete `List<String>` of ISO 8601 strings, preventing lazy `MappedListIterable` serialization failures.
   - `Constants.toEncodable` defensively converts arbitrary Dart `Iterable` instances into JSON-safe lists and formats `DateTime` objects.

2. **Null-Safe Financial Deserialization**:
   - `ForexHolding.fromJson` and `InstrumentPosition.fromJson` robustly handle numeric values passed as either numbers or strings.
   - Guarded getters against null quotes and quantities to prevent null assertion exceptions during position sorting.

3. **Responsive UI Constraints**:
   - Replaced fixed-width `Row` layouts with responsive `Wrap` and flex constraints to eliminate `RenderFlex` overflow errors across various mobile device aspect ratios.

---

## Test Coverage

Comprehensive unit and widget tests are located in `test/landscape_chart_matrix_test.dart`:
- **Multi-Leg Pricing Validation**: Verifies net debit, net credit, even premium, max profit, max loss, and breakeven calculations across vertical spreads, straddles, and iron condors.
- **Serialization Round-Trip Tests**: Validates complete JSON encoding and decoding for multi-leg order configurations.
- **Widget Rendering & Interaction**: Tests split-screen rendering, leg addition/removal, quantity adjustment, and limit price entry.
