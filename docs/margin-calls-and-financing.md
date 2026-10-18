# Margin Calls & Financing Costs

## Overview

RealizeAlpha provides comprehensive visibility into regulatory and broker margin call demands (`/margin/calls/`) and monthly margin interest debits (`/cash_journal/margin_interest_charges/`).

Active margin traders can monitor open deficit demands, review deadlines, explore step-by-step resolution pathways (cash deposits vs. marginable stock liquidation), and audit their monthly borrowing costs, effective annual interest rates, and historical financing expenses.

---

## Key Capabilities

### 1. Real-Time Margin Call Deficit Tracking
- **Call Types**:
  - **Maintenance Calls (FINRA Rule 4210):** Issued when account equity falls below the mandatory 25% minimum or broker house maintenance requirements (typically 30%–50%).
  - **Federal Regulation T Calls:** Issued when initial margin deposit requirements (50% for standard equities) are not satisfied by settlement date (T+1).
  - **Day Trade Calls:** Regulatory demands issued when exceeding Day Trading Buying Power (DTBP) without adequate equity.
  - **House & Exchange Calls:** Specific heightened maintenance demands on volatile, concentrated, or leveraged instruments.
- **Deficit Demand Metrics**:
  - Exact cash deficit demand required to clear the call.
  - Required equity liquidation amount (typically $3\times$ to $4\times$ cash deficit depending on maintenance percentage).
  - Call issue timestamp, deadline / due date, and satisfied timestamp.
- **Resolution Pathways**:
  - Deposit settled cash (clears deficit 1:1 immediately).
  - Deposit fully paid marginable securities.
  - Close or trim existing positions to free maintenance margin requirements.
  - Automatic broker liquidation notice if unresolved by deadline.

### 2. Financing Costs & Margin Interest Debits
- **Monthly Cash Journal Debits**:
  - Direct integration with `/cash_journal/margin_interest_charges/` tracking debits posted to the account.
  - Effective debit date, billing period, and status (`posted` vs. `pending`).
- **Rate & Borrowing Metrics**:
  - Effective borrowing annual percentage rate (e.g., 6.50% APR).
  - Average daily settled margin borrowing balance for the billing cycle.
  - Total financing costs debited Year-to-Date (YTD).
  - Historical comparison across previous billing periods.
- **Calculation Transparency**:
  $$\text{Daily Interest} = \frac{\text{Settled Margin Borrowed Balance} \times \text{Annual Interest Rate}}{360}$$
  Accrued daily and debited monthly against the account cash balance.

---

## Action Center Integration & Real-Time Alerts

The `PortfolioAlertService` evaluates active margin calls and generates high-priority notifications:

- **CRITICAL - Margin Call Active:** Triggered immediately when an open margin deficit exists (`isOpen == true`), displaying call type, exact dollar demand, and deadline.
- **Resolution Guidance:** Detailed alert message directing the trader to immediate cash deposit or position liquidation.
- **Automatic Suppression:** Satisfied, closed, or waived calls produce no active alerts.

---

## UI Access

- **Account Badges (`UserInfoWidget`):** Direct "Margin Calls" badge in the account header row opening the dedicated financing dashboard.
- **Margin Health Dashboard (`MarginHealthWidget`):** Action card with live call count and deficit status linking directly into `MarginFinancingWidget`.
- **Margin Calls & Financing Dashboard (`MarginFinancingWidget`):**
  - **Hero Status Card:** Live account status (Good Standing vs. Active Margin Deficit with deadline countdown).
  - **Metrics Row:** Active calls count, total deficit demand, YTD interest, and average borrowing APR.
  - **Margin Calls Tab:** Filterable list (All / Active / Resolved) with call cards and expandable resolution guide.
  - **Financing Costs Tab:** Overview card, monthly debits history with average daily balances, and FINRA margin interest calculation guide.
