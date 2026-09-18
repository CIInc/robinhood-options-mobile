# IRS Form 8949 Reconciliation & CSV Export

RealizeAlpha provides automated **IRS Form 8949 & Schedule D Reconciliation** to help investors reconcile closed capital asset dispositions, track wash sale disallowance codes (`W`), calculate net taxable capital gains, and export IRS-compliant CSV reports directly to tax preparation platforms (e.g. TurboTax, TaxAct, CPA spreadsheets).

## Overview

IRS Form 8949 (*Sales and Other Dispositions of Capital Assets*) is filed alongside **Schedule D (Form 1040)** to report capital gains and losses from stocks, options, and other covered securities.

The reconciliation engine in `TaxOptimizationService`:
1. Aggregates executed sell orders across equities and closed options contracts.
2. Evaluates holding periods based on trade execution dates to categorize transactions into **Part I (Short-Term)** or **Part II (Long-Term)**.
3. Cross-references transactions with the **Rolling 30-Day Wash Sale Window Tracker**. When a loss is disallowed under IRS Section 1091, adjustment code `W` is attached and the disallowed loss is added back into Column (g).
4. Reconciles net gain or loss per IRS instructions: `Column (h) = (d) Proceeds - (e) Cost Basis + (g) Adjustment`.
5. Exports a standardized RFC 4180 CSV with Part I and Part II sections, subtotal lines (Form 8949 Lines 2 and 4), and grand totals for Schedule D (Lines 1b and 8b).

---

## Form 8949 Structure

### Part I: Short-Term Capital Gains & Losses
- **Holding Period**: Assets held **one year or less** (holding period $\le 365$ days).
- **IRS Box**: Box A (Covered securities reported on Form 1099-B with basis reported to the IRS).
- **Subtotal**: Reconciles directly to **Schedule D, Line 1b**.

### Part II: Long-Term Capital Gains & Losses
- **Holding Period**: Assets held **more than one year** (holding period $> 365$ days).
- **IRS Box**: Box D (Covered securities reported on Form 1099-B with basis reported to the IRS).
- **Subtotal**: Reconciles directly to **Schedule D, Line 8b**.

---

## IRS Columns Breakdown

| Column | IRS Label | Description | Calculation in RealizeAlpha |
|---|---|---|---|
| **(a)** | Description of property | Quantity and symbol or contract specification | e.g. `15 sh. AAPL` or `2 SPY 10/16/2026 $550.0 CALL` |
| **(b)** | Date acquired | Timestamp when lot or position was bought | Formatted `MM/dd/yyyy` |
| **(c)** | Date sold or disposed | Timestamp when position was closed | Formatted `MM/dd/yyyy` |
| **(d)** | Proceeds | Gross sales price received | `salePrice * quantity` |
| **(e)** | Cost or other basis | Total purchase cost basis of lot | `buyPrice * quantity` |
| **(f)** | Code(s) from instructions | IRS adjustment codes | `'W'` for wash sale loss disallowed; empty if no adjustment |
| **(g)** | Amount of adjustment | Positive dollar adjustment added back | Disallowed loss from Section 1091 wash sale |
| **(h)** | Gain or loss | Net taxable gain or deductible loss | `(d) Proceeds - (e) Cost + (g) Adjustment` |

### Wash Sale Code `W` Mechanics

Under IRS Section 1091, a loss realized on a stock or option cannot be deducted if a substantially identical security is acquired within a **61-day window** (30 days before the sale, the day of sale, or 30 days after).

**Example**:
- Bought 20 shares of `NVDA` for $\$2,600$ (cost basis: $\$130$/share).
- Sold 20 shares for $\$2,200$ (proceeds: $\$110$/share) $\rightarrow$ tentative loss is $-\$400$.
- Repurchased shares 15 days later $\rightarrow$ $\$400$ loss is disallowed as a wash sale.
- On Form 8949:
  - Proceeds (d): $\$2,200.00$
  - Cost Basis (e): $\$2,600.00$
  - Code (f): `W`
  - Adjustment (g): $+\$400.00$
  - Reconciled Gain/Loss (h): $\$2,200 - \$2,600 + \$400 = \$0.00$
- The $\$400$ disallowed loss is added to the replacement shares' cost basis to defer the tax benefit until the replacement position is ultimately disposed of without a wash sale.

---

## CSV Export Specifications

Tapping **Export Form 8949 CSV** creates a shareable RFC 4180-compliant `.csv` file with the following layout:

```csv
IRS Form 8949 & Schedule D Reconciliation
Tax Year,2026
Generated At,2026-10-01 12:00:00
Source,RealizeAlpha Portfolio & Tax Suite

Part I: Short-Term Capital Gains and Losses - Assets Held One Year or Less (Box A - Covered Securities)
(a) Description of property,(b) Date acquired,(c) Date sold or disposed of,(d) Proceeds (sales price),(e) Cost or other basis,(f) Code(s) from instructions,(g) Amount of adjustment,(h) Gain or loss
15 sh. AAPL,02/10/2026,06/15/2026,3375.00,2850.00,,,525.00
20 sh. NVDA,03/05/2026,05/20/2026,2200.00,2600.00,W,400.00,0.00
Totals for Part I (Short-Term),,,5575.00,5450.00,,400.00,525.00

Part II: Long-Term Capital Gains and Losses - Assets Held More Than One Year (Box D - Covered Securities)
(a) Description of property,(b) Date acquired,(c) Date sold or disposed of,(d) Proceeds (sales price),(e) Cost or other basis,(f) Code(s) from instructions,(g) Amount of adjustment,(h) Gain or loss
25 sh. MSFT,08/15/2024,08/25/2026,11250.00,7750.00,,,3500.00
Totals for Part II (Long-Term),,,11250.00,7750.00,,,3500.00

Grand Totals (Schedule D Net Capital Gain/Loss),,,16825.00,13200.00,,400.00,4025.00
Total Disallowed Wash Sales (Code W),400.00
```

---

## How to Use

1. Navigate to the **Home** tab $\rightarrow$ **Portfolio Analytics** section.
2. Tap the **Tax Loss Harvesting** or **Taxes** card.
3. Select the **Form 8949** tab in the top navigation bar.
4. Select the target **Tax Year** from the dropdown menu (e.g. `2026`, `2025`, or `All Years`).
5. Filter dispositions by tapping:
   - **All**: View all dispositions.
   - **Short-Term**: View Part I dispositions (held $\le 365$ days).
   - **Long-Term**: View Part II dispositions (held $> 365$ days).
   - **Wash Sales**: View only transactions subject to IRS wash sale adjustments (Code `W`).
6. Tap **Export Form 8949 CSV** to open the system share sheet and save or send the CSV to your device, iCloud Drive, email, or tax preparer.
