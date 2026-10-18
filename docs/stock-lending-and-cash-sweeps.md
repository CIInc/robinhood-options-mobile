# Stock Lending Program (SLIP) & Cash Sweeps APY Monitor

## Overview

RealizeAlpha provides complete visibility into passive yield generation across account assets through the **Stock Lending Program (SLIP) Dashboard & Cash Sweeps APY Monitor**. Traders can track shares loaned to institutional borrowers, review historical yield payouts, verify 102% cash collateral protections, check program agreement eligibility, and monitor multi-tier high-yield cash sweep interest rates (Gold vs. Standard APY) backed by FDIC partner banks.

---

## Key Capabilities

### 1. Securities Lending Income Program (SLIP)
- **Automated Yield Tracking:** Robinhood's Fully Paid Securities Lending Program borrows fully paid equities from participating accounts and lends them to institutional counterparties.
- **102% Cash Collateral Protection:** While shares are out on loan, cash collateral equal to at least 102% of the shares' market value is placed in custody at a third-party bank to protect the owner against borrower default.
- **Unrestricted Trading Freedom:** Users retain 100% economic ownership and can sell loaned securities at any time without waiting for loans to be recalled or settled.
- **Dividend Equivalents (Cash-in-Lieu):** If a loaned security pays a dividend, the user receives manufactured payments equal to 100% of the dividend value.
- **Payment History Ledger:** Monthly and periodic payouts with itemized line items showing symbol, quantity loaned, annualized borrow rate, collateral backing, and interest earned.

### 2. High-Yield Cash Sweeps & APY Rate Monitor
- **Multi-Tier Rate Monitoring:** Real-time visibility into current effective APY, Robinhood Gold rate (e.g., 5.00% APY), Standard rate (e.g., 1.50% APY), and promotional boost rates.
- **FDIC Insurance Network:** Tracks uninvested cash swept into partner banks, providing up to \$2,250,000 in aggregate FDIC insurance coverage.
- **Interactive Yield Calculator:** Dynamic simulator estimating monthly and annual passive cash income based on slider-selected cash reserves.
- **Partner Banks Directory:** Comprehensive list of FDIC-insured network banks (Citibank, Goldman Sachs Bank USA, Wells Fargo, JPMorgan Chase, etc.).

---

## Architecture & Data Flow

```
Robinhood API / Bonfire Endpoints
  ├── /accounts/stock_loan_payments/ (or /stock_loan/payments/)
  ├── /slip/eligibility/
  └── /accounts/sweeps/interest/
           │
           ▼
IBrokerageService / RobinhoodService / DemoService
  ├── getStockLoanPaymentsModel() ──► List<StockLoanPayment>
  ├── getSlipEligibilityModel()   ──► SlipEligibility
  └── getSweepsInterestModel()    ──► SweepsInterest
           │
           ▼
StockLoanWidget (Two-Tab Dashboard)
  ├── Tab 1: Securities Lending (SLIP)
  │     ├── Hero Summary (Status badge, YTD/All-time earnings, agreement date)
  │     ├── Securities on Loan (Shares, 102% collateral, borrow rates)
  │     ├── Payment Ledger (Expandable payout history with symbol breakdown)
  │     └── Investor Protections Guide (SIPC vs FDIC collateral FAQ)
  └── Tab 2: Cash Sweeps & APY Monitor
        ├── APY Hero (Current effective rate, swept balance, monthly/yearly estimates)
        ├── Rate Tiers Comparison (Gold 5.00% vs Standard 1.50% APY)
        ├── Interactive Yield Calculator (Slider estimating interest on uninvested cash)
        └── FDIC Partner Banks Directory
```

---

## UI Components

### `StockLoanWidget` (`lib/widgets/stock_loan_widget.dart`)
- Accessible from **User Settings** (`user_widget.dart`) via the "Stock Lending & Cash Sweeps" tile, and from the **Account Badges** row in `user_info_widget.dart` via the quick "Stock Lending & Sweeps" badge.
- Supports pull-to-refresh (`RefreshIndicator`), fast keyword filtering by ticker or payment status, and responsive layouts across phone and tablet screens.

---

## Testing & Validation

- **Unit Tests (`test/stock_loan_test.dart`):**
  - Robust JSON parsing and serialization for `StockLoanPosition`, `StockLoanPayment`, `SlipEligibility`, and `SweepsInterest`.
  - Fallback key handling and graceful default values for missing data.
  - Verification of annual and monthly interest calculations.
  - Integration with `DemoService` fixtures.
- **Widget Tests (`test/stock_loan_widget_test.dart`):**
  - Renders Securities Lending (SLIP) tab with metrics, loaned securities, and payment ledger.
  - Tests search filter interaction on the payment ledger.
  - Switches to Cash Sweeps & APY tab and validates APY metrics, rate tier comparison, yield calculator, and partner banks.
