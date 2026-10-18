# Tax Loss Harvesting

RealizeAlpha includes a sophisticated **Tax Loss Harvesting** tool designed to help you optimize your tax liability by identifying opportunities to realize losses in your portfolio. This feature is integrated directly into the Portfolio Analytics dashboard and provides actionable, seasonality-aware insights.

## Key Features

### 1. Intelligent Opportunity Detection
The system automatically scans your entire portfolio (both Stocks and Options) to identify positions that are currently at a loss.

- **Stocks**: Identifies long positions where the current market value is lower than your cost basis.
- **Options**: Handles both Long (Debit) and Short (Credit) positions.
  - *Long Options*: Identifies when the current value is lower than the premium paid.
  - *Short Options*: Identifies when the cost to close (buy back) is higher than the premium received.

### 2. Seasonality Awareness
The feature understands the calendar and adjusts its urgency level based on the time of year, helping you prioritize tax planning when it matters most.

- **High Urgency (December)**:
  - **Status**: `URGENT` (Red Badge)
  - **Message**: "End of tax year approaching. Harvest losses now to offset this year's gains."
  - **Action**: Highly recommended to review all opportunities before Dec 31st.

- **Medium Urgency (October - November)**:
  - **Status**: `SEASON` (Orange Badge)
  - **Message**: "Tax season is approaching. Consider harvesting losses to optimize your tax liability."
  - **Action**: Start planning your end-of-year moves.

- **Low Urgency (January - September)**:
  - **Status**: Standard monitoring.
  - **Message**: "Monitor these positions for potential tax loss harvesting opportunities throughout the year."

### 3. Smart Visibility
To keep your dashboard clean and focused, the Tax Loss Harvesting card uses "Smart Visibility" logic:

- **During Tax Season (Oct-Dec)**: The card appears for any potential loss greater than **$10**.
- **Off-Season (Jan-Sep)**: The card remains hidden unless you have a significant potential loss (greater than **$100**).

### 4. Automated Opportunity Scanner & Schedule D Mechanics
The upgraded scanner models comprehensive tax mechanics under IRS Schedule D and Section 1211:
- **Capital Gains 1:1 Offset**: Unrealized capital losses are modeled against current-year realized capital gains to offset taxable gains dollar-for-dollar.
- **Ordinary Income Deduction Limit**: Excess net capital losses are automatically applied to offset up to **$3,000** (\$1,500 if married filing separately) of ordinary earned income per tax year.
- **Capital Loss Carryforward**: Any remaining unused losses beyond the $3,000 ordinary income cap are accurately accumulated into an indefinite **Tax Loss Carryforward** pool to offset future tax years.
- **Scanner Filters & Controls**:
  - **Asset Class Filter**: Seamlessly filter opportunities between All, Stocks only, or Options only.
  - **Minimum Loss Threshold**: Filter out micro-losses with quick thresholds (\$0, \$100, \$500, \$1,000).
  - **Multi-Factor Sorting**: Sort opportunities dynamically by dollar loss, percentage loss, or estimated tax savings.

### 5. Correlated Replacement Recommendations (Wash Sale Safe)
To maintain target market and sector exposure without triggering IRS Section 1091 Wash Sale disallowance, the scanner generates curated, non-substantially identical correlated replacement suggestions:
- **Index ETF Substitutes**:
  - `SPY` ↔ `VOO`, `IVV`, `SPLG` (different index providers and fund sponsors).
  - `QQQ` ↔ `QQQM`, `VGT` (separate legal entities and tracking methodologies).
  - `IWM` ↔ `VB`, `SCHA` (small-cap core exposure without identical CUSIPs).
- **Sector & Industry Competitors**:
  - `NVDA` ↔ `AMD`, `SMH`, `AVGO` (semiconductor peers and diversified sector baskets).
  - `AAPL` ↔ `MSFT`, `XLK` (tech sector proxies).
  - `TSLA` ↔ `RIVN`, `IDRV` (EV and future mobility peers).
- **Correlation Metrics & Rationales**: Each replacement displays estimated correlation coefficients (`~98% corr`), legal rationales, and 1-tap navigation directly to the instrument's quote and trade entry page.

### 6. Wash Sale Rule Warning & Tracker
The tool includes a built-in educational warning and tight integration with the **Rolling 30-Day Wash Sale Window Tracker**. If you repurchase a substantially identical security within 30 days before or after realizing a loss, the loss deduction is disallowed and added to the cost basis of the replacement asset.

### 7. Direct Trading Integration
The interface is designed for action:
- **Top Opportunity**: The dashboard card highlights your single largest tax loss opportunity immediately.
- **One-Tap Execution & Replacement**: Tapping on any opportunity in the detailed list navigates directly to the instrument's trading page. Tapping any correlated replacement suggestion navigates immediately to the replacement's detail page to re-establish market exposure safely.
  - *Stocks*: Navigates directly to the stock page.
  - *Options*: Fetches the underlying instrument and navigates to it, allowing you to manage the option position.

## How to Use

1.  Navigate to the **Home** tab.
2.  Scroll down to the **Portfolio Analytics** section.
3.  Look for the **Tax Loss Harvesting** card (if visible based on Smart Visibility rules).
4.  Tap the card to view the detailed **Tax Optimization** screen.
5.  Review the list of opportunities, sorted by the size of the potential loss.
6.  Tap on a specific item to go to the trading screen and close the position if desired.
