# Portfolio Rebalancing

The Portfolio Rebalancing tool helps you maintain your desired asset allocation by comparing your current portfolio against your target goals. It provides visual insights and actionable recommendations to keep your portfolio aligned with your investment strategy.

## Key Features

### 1. Dual View Modes
- **Asset Class Allocation**: View and manage your portfolio split across 7 asset classes: **Stocks**, **Options**, **Crypto**, **Forex**, **Futures**, **Fixed Income**, and **Cash**.
  - *Note:* Treasury ETFs, bond funds, and fixed income instruments (e.g., SGOV, BIL, AGG, BND, TLT) are automatically classified as **Fixed Income** to provide accurate allocation tracking of your bond and treasury holdings.
  - *Note:* Currency pairs and futures contracts are natively recognized and categorized under **Forex** and **Futures**.
- **Sector Allocation**: Analyze your exposure across 11 standard market sectors (Technology, Healthcare, Financial Services, etc.).

### 2. Visual Analysis & Risk Contribution
- **Dual Analysis Modes**:
  - **Capital Allocation (%)**: Side-by-side pie charts visualize your "Current" vs "Target" capital weight for quick nominal comparison.
  - **Risk Contribution (MCR %)**: Decomposes portfolio risk using Marginal Contribution to Risk ($\text{MCR}_i = (\Sigma w)_i / \sigma_p$) and Total Risk Contribution ($\text{TRC}_i = w_i \times \text{MCR}_i$). Compares Capital Weight % against Risk Contribution % side-by-side, surfacing outsized risk drivers (e.g., 10% Crypto driving 38% of total portfolio variance).
- **Portfolio Risk Profile Overview**:
  - **Realized Volatility ($\sigma_p$)**: Annualized portfolio standard deviation calculated from on-device return series and covariance matrix.
  - **Risk Concentration (HHI)**: Herfindahl-Hirschman Index scored from $0$ to $100$, categorizing portfolios into "Well Diversified" ($< 35$) vs. "Concentrated Risk" ($> 35$).
  - **Top Risk Driver**: Instantly pinpoints which asset class or sector contributes the highest share of portfolio risk.
  - **Data Provenance**: Clearly discloses when benchmark proxies (`SPY`, `TLT`, `BTC-USD`, etc.) are used for newly acquired or derivative holdings.
- **Progress Bars & Risk Multipliers**: Each card features stacked progress bars showing Capital vs. Risk MCR, along with dynamic risk multiplier badges ($R = \% \text{RC}_i / w_i$).
- **Drift Indicators**: Color-coded indicators (Green check / Orange warning) highlight areas that have drifted from your target.

### 3. Easy Target Editing & Volatility Parity Presets
- **Edit Mode**: Toggle edit mode to adjust your target allocations.
- **Precision Controls**: Use sliders for broad adjustments or the **+ / - buttons** for precise 1% increments.
- **Smart Presets**: Quickly apply standard or quantitative strategies using the preset chips:
  - *Asset Class*: Aggressive, Moderate, Conservative, All Equity, All-Weather, **Inverse-Vol**, and **Risk Parity (ERC)**.
  - *Sector*: Tech Heavy, Balanced, Defensive, **Inverse-Vol**, and **Risk Parity (ERC)**.
  - *Inverse-Vol (Naive Risk Parity)*: Calculates closed-form weights inversely proportional to realized asset/sector volatility ($w_i \propto 1/\sigma_i$), allocating more capital to low-volatility assets like Treasuries and Cash.
  - *Equal Risk Contribution (Full Risk Parity)*: Runs an on-device cyclical coordinate descent solver that equates each asset's Total Risk Contribution ($\text{TRC}_i = \text{TRC}_j = \sigma_p / N$), ensuring every component contributes equally to portfolio variance.
- **AI Optimization**: Tap the sparkles icon ✨ to open the [AI Asset Allocation](ai-asset-allocation.md) tool. Get personalized target recommendations based on your risk profile, time horizon, and investment goals.
- **Normalization**: One-tap "Normalize" button ensures your targets always add up to exactly 100%.

### 4. Actionable Recommendations & Tax-Lot-Aware Hints
- **Drift Threshold**: Set a custom dollar threshold (e.g., $100, $500) to filter out minor fluctuations.
- **Smart Suggestions**: The tool automatically generates a list of "Buy" and "Sell" actions needed to rebalance your portfolio.
- **Tax-Lot-Aware Trade Sizing Hints**:
  - *Loss Harvesting*: Identifies available tax lots with unrealized losses and badges recommendations with potential tax deductions (e.g., `Tax-Loss Harvest: $320 in unrealized losses available to offset gains`).
  - *Capital Gains Alert*: Warns when trimming an overweight asset would trigger short-term capital gains tax, suggesting cash inflows instead.
  - *Tax-Neutral Inflows*: Recommends using incoming cash, dividends, or yield distributions to buy underweight assets without triggering taxable sales.
- **Prioritized List**: Recommendations are sorted by dollar amount, so you can focus on the most impactful trades first.
- **Clear Actions**: Each recommendation shows the exact amount to buy or sell to reach your target.

### 5. Automated Rebalancing Scheduler
- **Scheduled Checks**: Enable periodic drift checks (daily, weekly, or monthly) from the settings sheet.
- **Notifications**: Receive alerts when your portfolio drifts beyond the configured threshold.
- **Auto-Execute (Optional)**: Allow experimental auto-rebalance placement for paper or guided workflows.
- **Macro Guidance**: Built-in macro context provides suggestions on whether to rebalance aggressively or defensively.

## How to Use

1. **Access**: Navigate to the "Allocation" section on the Home screen and tap "Rebalance".
2. **Set Targets**: Tap the "Edit" icon (pencil) to enter edit mode. Targets default to your current allocation on first open. Adjust sliders or apply a preset to define your ideal portfolio. Save your changes.
3. **Review Drift**: Check the "Drift" indicators on each card to see which assets are off-target.
4. **Execute Trades**: Scroll down to the "Rebalancing Recommendations" card to see a prioritized list of trades to execute.
5. **Enable Scheduler**: Open settings (gear icon) to turn on scheduled checks and configure notifications.
