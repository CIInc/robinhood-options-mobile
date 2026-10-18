# Tax Documents, Account Statements & ADR Fees

## Overview

RealizeAlpha provides a unified, compliant, and accessible interface for reviewing tax forms, monthly brokerage statements, trade confirmations, pass-through ADR fees, and foreign tax withholding classifications through the **Tax Documents & Statements Dashboard** (`/documents/`, `/corp_actions/adr_fees/`, `/tax_info/`).

---

## Key Capabilities

### 1. Tax Forms & Consolidated Form 1099
- **Consolidated 1099 Access:** Direct download and review of annual Form 1099 statements combining Forms 1099-B (Broker Transactions & Capital Gains), 1099-DIV (Dividends & Capital Gain Distributions), 1099-INT (Interest Income from cash balances), and 1099-MISC (Stock Lending SLIP payments and bonus credits).
- **Tax Year Filtering:** Quick chips to filter tax forms by filing year (e.g. `2025`, `2024`, `2023`, `All Years`).
- **Document Metadata & Audit Details:** Bottom sheet inspection detailing Document ID, account number, issue date, tax year, file size, and Portable Document Format (PDF) delivery status.
- **Tax Notice & Educational Disclaimers:** In-app informational modal explaining IRS form breakdowns and advising users on CPA and tax software (TurboTax, TaxAct, H&R Block) integration.

### 2. Monthly Brokerage Statements & Trade Confirmations
- **Account Statements:** Complete archive of monthly account statements with period date, issuing entity, file size, and download link.
- **Trade Confirmations:** Instant verification records for executed stock, ETF, and options orders.
- **Segmented Type Filtering:** Toggle between `All`, `Statements`, and `Trade Confirms` with real-time text search across statement names, dates, and execution tickers.

### 3. ADR Pass-Through Fees & Foreign Tax Withholding
- **ADR Pass-Through Fee Ledger:** Detailed itemization of depository bank custody fees (e.g. BNY Mellon, Citi, JPMorgan) assessed on American Depositary Receipts (e.g., `BABA`, `TSM`, `BTI`, `ASML`).
- **Fee Rate & Quantity Metrics:** Per-share fee rates (typically \$0.01 – \$0.03/share), shares held, transaction dates, and cumulative lifetime ADR fee totals.
- **Foreign Tax Withholding Rates:** Lookups for foreign equity holdings showing country of incorporation, statutory dividend withholding rates, US Double Taxation Treaty rates, and exemption status (e.g. UK 0% treaty exempt, Netherlands 15% reduced treaty rate, Cayman Islands tax-exempt).

---

## Architecture & Data Flow

```
Robinhood API Endpoints
  ├── /documents/?type=1099
  ├── /documents/?type=account_statement
  ├── /corp_actions/adr_fees/
  └── /tax_info/instrument/{id}/withholding_status/
           │
           ▼
IBrokerageService / RobinhoodService / DemoService
  ├── getAccountDocumentsModel()       ──► List<AccountDocument>
  ├── getAdrFeesModel()                ──► List<AdrFee>
  ├── getTaxWithholdingStatusModel()   ──► TaxWithholdingStatus
  └── TaxDocumentsSummary              ──► Aggregated summary
           │
           ▼
TaxDocumentsWidget (3-Tab Dashboard)
  ├── Tab 1: Tax Forms (1099)
  │     ├── Hero Summary Card (Latest tax year, 1099-B/DIV/INT/MISC tips)
  │     ├── Search & Tax Year Filter Chips (All Years, 2025, 2024, 2023)
  │     ├── Document Cards (Title, date, file size, PDF badge, download)
  │     └── Document Details Bottom Sheet (ID, account, year, download action)
  ├── Tab 2: Statements & Trade Confirms
  │     ├── Segmented Filter (All, Statements, Trade Confirms)
  │     ├── Search Bar
  │     └── Statement Cards (Monthly statements & trade execution confirmations)
  └── Tab 3: ADR Fees & Withholding
        ├── Hero Summary Card (Total ADR fees paid, foreign holdings count)
        ├── ADR Pass-Through Fee Ledger (Symbol, fee amount, rate/sh, shares, date)
        └── Foreign Tax Withholding Rates (Country, statutory rate, treaty rate, exemption)
```

---

## UI Components & Navigation

### `TaxDocumentsWidget` (`lib/widgets/tax_documents_widget.dart`)
- Accessible from:
  1. **User Settings (`user_widget.dart`)**: Under the User profile options via the "Tax Documents & Statements" ListTile.
  2. **Account Badges (`user_info_widget.dart`)**: Directly from the account header via the "Tax Documents" action badge.
- Fully supports pull-to-refresh (`RefreshIndicator`), tax year filtering, segmented statement categorization, live search, and modal inspection sheets.
