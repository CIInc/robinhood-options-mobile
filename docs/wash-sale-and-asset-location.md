# Cross-Account Wash Sale Guardrails & Asset Location Optimizer

Comprehensive tax protection for multi-account traders, covering IRS Section 1091, IRS Revenue Ruling 2008-5 permanent IRA wash sale disallowances, inline order ticket pre-trade warnings, and the Asset Location Optimizer.

---

## 1. IRS Revenue Ruling 2008-5 Cross-Account IRA Wash Sale Guardrails

### Background & The "IRA Wash Sale Trap"

Under **IRC Section 1091**, a wash sale occurs when an investor disposes of stock or securities at a loss and within a 61-day period (30 days before through 30 days after the sale) acquires substantially identical stock or securities (or enters into a contract or option to acquire them).

In a single taxable brokerage account or across multiple taxable accounts:
- The loss on the sale is disallowed for the current tax year.
- The disallowed loss is **added to the cost basis** of the newly acquired replacement position.
- Consequently, the tax deduction is not permanently lost—it is merely **deferred** until the replacement position is sold.

However, under **IRS Revenue Ruling 2008-5**:
- If an investor sells stock or securities at a loss in a **taxable brokerage account** and within the 61-day window purchases substantially identical stock or securities in an **IRA or Roth IRA**, the loss is disallowed under Section 1091.
- Crucially, the cost basis of the shares inside the IRA is **NOT increased**.
- Because retirement accounts have separate tax rules and Roth accounts are tax-exempt on qualified distributions, the basis step-up mechanism is unavailable.
- **The tax loss deduction is permanently extinguished and forfeited forever.**

### RealizeAlpha Implementation

1. **Cross-Account Provenance Tracking**:
   - `WashSaleRecord` tracks `saleAccountId`, `saleAccountType`, `replacementAccountId`, `replacementAccountType`, and `isPermanentIraDisallowance`.
   - `detectWashSales` evaluates order history across all linked taxable and retirement accounts.
   - When a sale in a taxable account is replaced by a purchase in a Traditional IRA or Roth IRA, `isPermanentIraDisallowance` is flagged `true`.
   - Under Rev. Rul. 2008-5, replacement cost basis remains unadjusted (`adjustedCostBasis: unadjustedPrice * qty`) rather than stepping up.

2. **Visual Indicators & Alert Banners**:
   - In the **Wash Sales** tab of the Tax Optimization module, disallowed wash sales resulting from IRA repurchases are labeled with a bold red tag:
     `Permanent Loss (Rev. Rul. 2008-5)`.
   - The card displays the account routing (`Individual (Taxable) → Roth IRA`) and clarifies that the loss was permanently forfeited.
   - `PortfolioAlertService` generates a critical priority portfolio alert:
     `IRS Rev. Rul. 2008-5 Permanent Wash Sale Disallowed`.

---

## 2. Inline Pre-Trade Wash Sale Warnings

To prevent wash sale violations before orders are executed, RealizeAlpha provides real-time pre-trade wash sale evaluation in order entry tickets:
- **`TradeInstrumentWidget`** (Equity orders)
- **`TradeOptionWidget`** (Option contract orders)

### Pre-Trade Evaluation Flow

When preparing a `Buy` or `Debit` order:
1. `TaxOptimizationService.evaluatePreTradeWashSale(...)` inspects the target symbol against active 30-day wash sale restriction windows and past filled loss sales.
2. If the user is purchasing in an **IRA or Roth IRA** following a taxable loss sale within the past 30 days:
   - Displays a prominent red **Critical Hazard Banner**:
     > **IRS Rev. Rul. 2008-5: Permanent Tax Loss Forfeiture**
     > Buying SYMBOL in your IRA within 30 days of a loss sale in your taxable account will permanently forfeit up to \$X.XX in tax deductions. Cost basis cannot be increased in retirement accounts.
3. If the user is purchasing in a **Taxable Account** following a loss sale:
   - Displays an amber **Wash Sale Warning Banner**:
     > **Wash Sale Restriction Window Active (IRC §1091)**
     > Repurchasing SYMBOL (X days remaining until M/D/Y) will trigger an IRS §1091 wash sale. The realized loss of \$X.XX will be disallowed and added to your replacement cost basis.
4. Includes a 1-tap **Info Sheet** detailing the IRS 61-day window rules and safe repurchase countdown date.

---

## 3. Asset Location Optimizer

Asset location refers to placing specific investments in the optimal account type to minimize lifetime taxes without changing the overall portfolio asset allocation.

### Account Tax Classifications

| Account Classification | Tax Treatment | Ideal Asset Placement |
|---|---|---|
| **Taxable Brokerage** | Capital gains taxed upon realization (0%/15%/20%); qualified dividends taxed preferentially; annual 1099 drag | Broad market index ETFs (SPY, VOO, VTI, QQQ), low-dividend growth equities (<1.5%), municipal bonds |
| **Traditional IRA** | Contributions pre-tax; growth tax-deferred; withdrawals taxed as ordinary income | Taxable bond funds (BND, AGG, HYG), REITs (O, PLD, AMT), high-yield dividend stocks (>3%) |
| **Roth IRA** | Contributions post-tax; compound growth & qualified withdrawals 100% tax-free forever | Highest expected return assets (high-beta tech, aggressive growth equities), active options trading / short-term capital gains |

### Efficiency Score & Recommendations

In the **Asset Location** tab of `TaxOptimizationWidget`:
- **Asset Location Efficiency Score (0–100%)**:
  $$\text{Score} = \max\left(0, 100 - \frac{\text{Misplaced Asset Value}}{\text{Total Multi-Account Portfolio Value}} \times 100\right)$$
  - **$\ge 85\%$**: Optimal Tax Placement
  - **$70\% - 84\%$**: Good Placement
  - **$50\% - 69\%$**: Suboptimal Placement
  - **$< 50\%$**: Needs Rebalancing
- **Multi-Account Breakdown**: Side-by-side totals across Taxable, Traditional IRA, and Roth IRA.
- **Top Tax Relocation Recommendations**: Concrete actionable moves with estimated annual tax drag savings (e.g. *"Relocate O from Taxable to Traditional IRA to shield ordinary income dividends"*).
- **Holdings Efficiency Table**: Granular list of every position with badges indicating `[Tax-Efficient]`, `[Moderate]`, or `[Tax-Inefficient]`, plus optimal destination accounts.
