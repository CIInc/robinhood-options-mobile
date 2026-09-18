# Specific Tax Lot Matching & Order Entry (HIFO/LIFO)

RealizeAlpha includes an institutional-grade **Specific Tax Lot Matching & Accounting Method Selection** system integrated directly into equity trade execution and the **Tax Optimization** suite. It allows investors to choose their disposition strategy (FIFO, LIFO, HIFO, Low Cost, Tax Minimizer) or manually specify exact tax lots before routing sell orders, maximizing tax efficiency and capital loss realization.

---

## Overview

When selling shares of an asset acquired across multiple purchases at different prices and dates, the order in which those shares are sold determines the realized capital gain or loss. By default, most brokerages use **First In, First Out (FIFO)**, which often triggers larger taxable capital gains by selling the oldest (frequently lowest cost basis) lots first.

RealizeAlpha provides:
1. **Automated Lot Disposition Strategies**: Choose high-level optimization rules at order entry (HIFO, LIFO, FIFO, Low Cost, Tax Minimizer).
2. **Interactive Specific Lot Allocation Modal**: Visually allocate shares lot-by-lot with live cost basis, unrealized P&L, holding duration, and tax savings feedback.
3. **Multi-Brokerage Order Strategy Propagation**: Supported brokerages (Robinhood, Schwab, Fidelity, Paper Trading) receive the corresponding tax lot parameters or preserve manual allocations.

---

## Supported Tax Lot Strategies

| Strategy | Display Label | API Key | Description |
|---|---|---|---|
| **FIFO** | First In, First Out | `fifo` | Oldest acquired shares sold first (standard brokerage default). |
| **LIFO** | Last In, First Out | `lifo` | Most recently acquired shares sold first. Useful in rising markets to minimize gains when recent lots have higher cost bases. |
| **HIFO** | Highest In, First Out | `hifo` | Highest cost basis shares sold first. Maximizes realized capital losses or minimizes taxable gains. Recommended for tax-loss harvesting. |
| **Low Cost (LOFO)** | Lowest In, First Out | `lofo` | Lowest cost basis shares sold first. Maximizes realized capital gains (e.g., to absorb expiring capital loss carryforwards or take advantage of low income years). |
| **Tax Minimizer** | Tax Minimizer | `tax_optimizer` | Multi-pass algorithm: prioritizes short-term losses first (offsetting high ordinary income tax), then long-term losses, then long-term gains (preferential 15-20% rates), and short-term gains last. |
| **Specified Lots** | Specific Lot Selection | `custom` | Manually specify exact lot allocations and share quantities using the interactive bottom sheet. |

---

## Interactive Lot Selection Sheet (`TaxLotSelectionSheet`)

When selling equity positions in `TradeInstrumentWidget`, users can tap the **Tax Lot Strategy** selector:

1. **Strategy Selection**: Choose between automatic rules (FIFO, LIFO, HIFO, Low Cost, Tax Minimizer) or tap **Specified Lots**.
2. **Granular Lot Breakdown**:
   - Displays each open lot with acquisition date, share count, per-share cost basis, total cost, current market value, and unrealized gain/loss ($ and %).
   - Holding duration badges: `Short-Term` (held $\le 365$ days) vs. `Long-Term` (held $> 365$ days).
   - Approaching Long-Term alert badge for lots within 30 days of crossing 1 year.
3. **Allocation Controls**:
   - Quick "Select All" / "Max" button per lot.
   - Stepper and numeric input for exact share counts.
   - Remaining shares counter ensuring the total allocated quantity matches the sell order quantity.
   - Live summary metrics: **Total Proceeds**, **Blended Cost Basis**, and **Estimated Realized Gain/Loss**.

---

## Tax Minimizer Algorithm Mechanics

The `TaxOptimizationService.matchTaxLots()` engine evaluates open lots through a 4-tier hierarchy:

1. **Tier 1: Short-Term Capital Losses**: Sorted from highest loss per share to lowest. Realizing short-term losses offers the highest tax shield against ordinary income (up to 37% tax bracket).
2. **Tier 2: Long-Term Capital Losses**: Sorted from highest loss per share to lowest. Offsets capital gains dollar-for-dollar.
3. **Tier 3: Long-Term Capital Gains**: Sorted from lowest gain per share to highest. Benefits from preferential 0%/15%/20% federal capital gains rates.
4. **Tier 4: Short-Term Capital Gains**: Sold last, sorted from lowest gain to highest, minimizing immediate ordinary income tax liabilities.

---

## Brokerage & Order Integration

- **Order Routing**: `IBrokerageService.placeInstrumentOrder` passes `taxLotStrategy` and `taxLotAllocations`.
- **Robinhood Service**: Maps disposition method to Robinhood order parameters.
- **Schwab Service**: Injects tax lot disposition instructions (`specialInstruction`) into Schwab order requests.
- **Paper & Demo Trading**: Fully simulates specific tax lot depletion, preserving individual lot balances, tracking modified cost bases, and updating realized P&L accurately.

---

## How to Use

1. Navigate to any stock position you hold in your portfolio.
2. Tap **Trade** $\rightarrow$ **Sell**.
3. In the order entry form, locate the **Tax Lot Strategy** tile.
4. Select **HIFO** to automatically maximize capital losses, or tap **Select Specific Lots** to open the allocation modal.
5. Allocate the desired shares to specific tax lots and confirm the order.
