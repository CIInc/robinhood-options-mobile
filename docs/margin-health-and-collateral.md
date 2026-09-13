# Unified Risk & Margin Health and Collateral Tracking

## Overview

RealizeAlpha integrates unified account endpoints (`/phoenix/accounts/unified` with fallback to `/accounts/unified/`) to deliver real-time margin risk management, buying power transparency, and collateral tracking across equities, options, and cryptocurrencies.

Active margin traders can monitor their maintenance buffer ratios, view segregated buying powers, inspect collateral holds (options contracts and crypto locks), and receive automated early warning alerts before a maintenance deficit leads to a broker liquidation or FINRA Rule 4210 margin call.

---

## Key Capabilities

1. **Margin Health & Buffer Gauge:**
   - **Healthy ($\ge 25\%$ buffer):** Adequate cushion above maintenance requirement.
   - **Warning ($10\% - 25\%$ buffer):** Buffer narrowing; automated advisory alert triggered.
   - **Critical ($< 10\%$ buffer):** Imminent margin call risk; critical risk banner triggered.
   - **Margin Call (Deficit):** Maintenance margin deficit requiring immediate deposit or liquidation.
   - **Unleveraged / Cash:** Non-margin account with zero liquidation risk.

2. **True Segmented Buying Powers:**
   - **General Account Buying Power:** Available purchasing capacity for equities and standard assets.
   - **Options Buying Power:** Cash or margin available strictly for options strategies.
   - **Crypto Buying Power:** Available buying power for crypto trading (subject to non-margin cash rules).
   - **Day Trading Buying Power:** Real-time intraday purchasing capacity.
   - **Cash Available for Withdrawal:** Unencumbered settled cash.

3. **Collateral & Holds Tracking:**
   - **Options Collateral:** Locked cash or equity collateral backing open short options contracts (cash-secured puts, covered calls, option credit spreads).
   - **Crypto Collateral:** Collateral locked against open cryptocurrency limit orders.
   - **Pending Holds:** Total unsettled or pending execution holds.

4. **Leverage & Maintenance Requirements:**
   - **Total Maintenance Requirement:** Equity required by the broker and FINRA Rule 4210.
   - **Initial Margin Requirement:** Margin needed to open new leveraged positions.
   - **Outstanding Margin Borrowed:** Net margin balance accruing interest.

---

## Action Center Integration & Real-Time Alerts

The `PortfolioAlertService` evaluates unified margin health and generates high-priority notifications:

- **CRITICAL - Margin Call:** Triggered when `marginCallDeficit > 0` or status is `marginCall`.
- **CRITICAL - Margin Buffer < 10%:** High-urgency warning when maintenance cushion drops below 10%.
- **WARNING - Margin Buffer < 25%:** Advisory notice when maintenance cushion drops below 25%.
- **Suppression:** Unleveraged and cash accounts with no margin debit are cleanly suppressed.

---

## UI Access

- **Account Cards (`UserInfoWidget`):** Quick-glance margin health badge with status-coded color indicator and live buffer percentage. Tapping the badge opens the comprehensive Margin Health Dashboard.
- **Features Menu (`UserWidget`):** Direct navigation entry point under *Features* $\rightarrow$ *Margin Health & Collateral*.
- **Margin Health Dashboard (`MarginHealthWidget`):** Responsive multi-card dashboard featuring:
  - Hero buffer status gauge with progress bar.
  - Segmented True Buying Power grid.
  - Collateral & Holds breakdown.
  - Leverage, borrowed balance, and maintenance requirements.
  - Educational FINRA guidance accordion explaining margin mechanics, buffer calculations, and liquidation risks.
