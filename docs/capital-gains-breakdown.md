# Capital Gains & Holding Period Breakdown

RealizeAlpha includes a comprehensive **Short-Term vs. Long-Term Capital Gains Breakdown** module within the **Tax Optimization** suite. It enables investors to categorize open positions by holding period, track countdown timers toward preferential long-term tax rates, project tax liabilities, and receive proactive alerts before realizing gains prematurely.

---

## Key Features

### 1. Holding Period Tracking & Classification
Under IRS guidelines (IRC § 1222), assets held for **more than one year (366+ days)** qualify for preferential long-term capital gains tax rates, while assets held for one year or less (≤ 365 days) are taxed as short-term capital gains at ordinary income tax rates.

- **Equities (`InstrumentPosition`)**: Evaluates `created_at` timestamp against the current date.
- **Options (`OptionAggregatePosition`)**: Evaluates `created_at` timestamp of the option contract.
- **Classification Categories**:
  - `shortTerm`: Held for 365 days or fewer.
  - `longTerm`: Held for 366 days or more.
  - `approaching`: Short-term profitable positions within **30 days** of crossing the 1-year threshold (336 to 365 days).

---

### 2. Real-Time Holding Duration Countdown Timers
For all short-term winning positions, the interface calculates:
- **Days Held**: Current age of the position in calendar days.
- **Days Until Long-Term**: Countdown timer (`366 - daysHeld`) showing exact days remaining until long-term tax qualification.
- **Approaching Long-Term Banner**: When one or more profitable positions are within 30 days of long-term status, a prominent banner alerts the user of potential tax savings achievable by holding.

---

### 3. Tax Liability & Potential Savings Projections
The breakdown dynamically projects tax liabilities based on user-configurable tax brackets:

- **Configurable Tax Brackets**:
  - **Short-Term / Ordinary Income Rate**: Defaults to **24%** (customizable from 10% to 37%).
  - **Long-Term Capital Gains Rate**: Defaults to **15%** (customizable: 0%, 15%, 20%).
- **Tax Calculations**:
  - **Current Tax Liability**: 
    - Short-term gains: `Gain × Short-Term Rate`
    - Long-term gains: `Gain × Long-Term Rate`
    - Losses: Projected liability is \$0.
  - **Potential Tax Savings**:
    - For short-term gains: `Gain × (Short-Term Rate - Long-Term Rate)`
    - Quantifies exact dollar savings if the position is held until long-term eligibility.

---

### 4. Capital Gains Summary Dashboard
The header section provides immediate portfolio-level tax visibility:
- **Net Unrealized Gains / Losses**: Aggregated dollar return across all positions.
- **Short-Term Unrealized**: Total gain/loss and projected short-term tax liability.
- **Long-Term Unrealized**: Total gain/loss and projected preferential long-term tax liability.
- **Total Projected Tax**: Blended tax bill if all open profitable positions were liquidated today.
- **Total Potential Savings**: Sum of tax dollars saved if all short-term gains are held until qualifying for long-term treatment.
- **Interactive Bracket Editor**: Quick gear action button to update tax brackets and recalculate projections on the fly.

---

### 5. Position Filters & Multi-Factor Sorting
The Capital Gains tab features interactive filter chips and sorting:

- **Filter Chips**:
  - **All**: Complete inventory of open positions with tax attributes.
  - **Short-Term**: Only positions held ≤ 365 days.
  - **Long-Term**: Only positions held > 365 days.
  - **Approaching**: Only profitable positions within 30 days of long-term eligibility.
  - **Gains Only**: Positions with positive unrealized profit.
- **Multi-Factor Sorting**:
  - **Unrealized Gain / Return ($)**
  - **Holding Duration (Days Held)**
  - **Countdown Timer (Days to Long-Term)**
  - **Symbol (Alphabetical)**

---

### 6. Action Center Proactive Alert Integration
The suite integrates directly with `PortfolioAlertService` to surface high-priority insights in the portfolio Action Center:
- **Alert Type**: `capital-gains-approaching`
- **Trigger**: Any open position with `qualifiesForLongTermSoon == true` (held 336–365 days) with potential tax savings of **$25 or greater**.
- **Actionable Notification**: Informs the user of the upcoming qualification date and estimated tax savings, preventing accidental liquidation right before tax rate reduction.

---

## How to Access

1. Open the **RealizeAlpha** app.
2. Navigate to the **Home** tab and scroll to **Portfolio Analytics**.
3. Tap **Tax Optimization** (or the Tax Loss Harvesting card).
4. Select the **Capital Gains** tab (third tab alongside Loss Harvesting and Wash Sales).
5. Tap the **gear icon** to configure your personal federal/state tax brackets.
