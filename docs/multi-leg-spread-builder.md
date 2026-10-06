# Multi-Leg Order Templates & Spread Builder

## Overview

The **Multi-Leg Order Templates & Spread Builder** (`MultiLegSpreadBuilderSheet`, `MultiLegMatrixOrderEntryWidget`, and `MultiLegOrderEntry`) provides pre-configured structural order entry pads and an interactive spread builder for complex multi-leg options strategies across Schwab, Robinhood, and simulated paper accounts.

Traders can configure, inspect, and execute multi-leg orders with real-time net credit/debit calculation, dynamic breakeven points, max profit/loss risk metrics, and direct brokerage execution via `IBrokerageService.placeMultiLegOptionsOrder`.

---

## Supported Strategies & Templates

The Spread Builder provides 1-tap template configurations:

| Strategy | Structure | Direction / Type | Risk Profile |
| :--- | :--- | :--- | :--- |
| **Bull Call Spread** | Buy lower Call + Sell higher Call | Net Debit | Defined Risk / Defined Profit |
| **Bear Put Spread** | Buy higher Put + Sell lower Put | Net Debit | Defined Risk / Defined Profit |
| **Bull Put Spread** | Sell higher Put + Buy lower Put | Net Credit | Defined Risk / Defined Profit |
| **Bear Call Spread** | Sell lower Call + Buy higher Call | Net Credit | Defined Risk / Defined Profit |
| **Long Straddle** | Buy ATM Call + Buy ATM Put | Net Debit | Defined Risk / Unlimited Profit |
| **Short Straddle** | Sell ATM Call + Sell ATM Put | Net Credit | Unlimited Risk / Defined Profit |
| **Long Strangle** | Buy OTM Put + Buy OTM Call | Net Debit | Defined Risk / Unlimited Profit |
| **Short Strangle** | Sell OTM Put + Sell OTM Call | Net Credit | Unlimited Risk / Defined Profit |
| **Iron Condor** | Long Put + Short Put + Short Call + Long Call | Net Credit | Defined Risk / Defined Profit |
| **Call Calendar Spread** | Sell front-month Call + Buy back-month Call | Net Debit | Time-decay / Volatility Defined Risk |
| **Put Calendar Spread** | Sell front-month Put + Buy back-month Put | Net Debit | Time-decay / Volatility Defined Risk |
| **Custom Multi-Leg** | User-defined custom legs (up to 4 legs) | Debit / Credit | Dynamic |

---

## Core Capabilities

### 1. Real-Time Net Debit / Credit Calculation
- Calculates aggregate net premium across all legs:
  $$\text{Net Premium} = \sum_{\text{legs}} \text{signedPremium}$$
  where sell legs contribute positive credit and buy legs contribute negative debit.
- Automatically labels the order as `NET CREDIT` or `NET DEBIT`.
- Computes total estimated order cash requirement based on selected quantity:
  $$\text{Estimated Total} = \text{effectivePrice} \times \text{quantity} \times 100$$

### 2. Comprehensive Risk & Reward Metrics
- **Max Profit**: Accurately modeled for debit spreads (spread width minus debit paid), credit spreads (net credit collected), calendars, and unlimited strategies.
- **Max Loss**: Accurately modeled for debit spreads (net debit paid), credit spreads (spread width minus net credit), iron condors (max wing width minus net credit), and unlimited risk short positions.
- **Breakevens**: Automatically calculates single or dual upper/lower breakeven price levels:
  - Vertical Spreads: $\text{Strike}_{\text{long}} \pm \text{Net Premium}$
  - Straddles / Strangles: $\text{Strike}_{\text{put}} - \text{Net Premium}$ and $\text{Strike}_{\text{call}} + \text{Net Premium}$
  - Iron Condors: $\text{Short Put} - \text{Net Credit}$ and $\text{Short Call} + \text{Net Credit}$
- **Risk / Reward Ratio**: Normalized risk-to-reward ratio string (e.g. `1 : 2.50`) displayed prominently.

### 3. Interactive Leg Configuration Card
Each leg within the builder provides:
- **Buy / Sell Action Segmented Button**: Instant toggle between Long and Short positioning with real-time recalculation.
- **Call / Put Type Segmented Button**: Instant switch between option contract types.
- **Strike Stepper**: Increment or decrement strike based on underlying spot step sizes ($0.50, $1.00, $2.50, $5.00).
- **Expiration Date Picker**: Tap to inspect or adjust individual leg expirations (critical for Calendar and Diagonal spreads).
- **Mark Premium & Signed Impact**: Shows individual contract premium and signed portfolio dollar impact.
- **Ratio / Multiplier**: Multi-contract ratio modeling per leg.

### 4. Brokerage Execution Integration (`IBrokerageService`)
- Maps internal `MultiLegOrderLeg` objects into brokerage-compatible leg payloads:
  - Robinhood format (`side`, `position_effect`, `option_id`, `ratio_quantity`)
  - Schwab format (`instruction` BUY_TO_OPEN / SELL_TO_OPEN, `symbol`, `quantity`)
- Modal Review & Confirmation Dialog (`confirm-spread-order`):
  - Displays selected account, order type (Limit / Market), quantity, limit price, net direction, and leg summary.
  - Submits via `service.placeMultiLegOptionsOrder(user, account, ...)`.
  - Surfaces brokerage errors (e.g., option level permissions, insufficient collateral, margin requirement).

### 5. Access Points
- **Option Chain App Bar**: Quick launch button (`spread-builder-appbar-btn` with icon `Icons.layers_outlined`) inside `OptionChainWidget`.
- **Multi-Leg Matrix View**: Expandable side/bottom sheet (`MultiLegMatrixOrderEntryWidget`) for desktop/tablet and power users.

---

## Technical Architecture

```
┌────────────────────────────────────────────────────────┐
│               MultiLegOrderEntry (Model)               │
│  - Vertical, Straddle, Strangle, Condor, Calendar      │
│  - Max Profit / Loss, Breakevens, Debit/Credit Math    │
│  - toBrokerageLegs(), toJson(), fromJson()             │
└──────────────────────────┬─────────────────────────────┘
                           │
         ┌─────────────────┴─────────────────┐
         ▼                                   ▼
┌───────────────────────────────┐ ┌───────────────────────────────┐
│  MultiLegSpreadBuilderSheet   │ │ MultiLegMatrixOrderEntryWidget│
│  - Modal bottom sheet UI      │ │ - Desktop matrix pad view     │
│  - 1-tap template ChoiceChips │ │ - Real-time strike stepper    │
│  - Risk/reward analytics card │ │ - Direct order execution      │
│  - Brokerage submission modal │ │                               │
└───────────────────────────────┘ └───────────────────────────────┘
```

## Testing & Quality Assurance

Unit and widget tests located in `test/multi_leg_spread_builder_test.dart`:
- Verified mathematical properties for all standard templates (Bull Call, Bull Put, Bear Call, Bear Put, Iron Condor, Calendar Spread, Short Straddle, Short Strangle).
- Verified JSON serialization and deserialization.
- Verified brokerage leg formatting and parameter mapping.
- Verified widget rendering, template switching, interactive adjustments, and order submission flows.
