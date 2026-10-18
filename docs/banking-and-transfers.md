# Banking, ACH Transfers & Linked Accounts

## Overview

RealizeAlpha provides full native visibility and management for capital flows through the **Banking & Transfers Dashboard**. Users can monitor bank deposits, withdrawals, clearing and settlement timelines, cancel pending transfers, and review linked bank accounts and verification states (`/ach/transfers/`, `/ach/relationships/`).

---

## Key Capabilities

### 1. ACH Transfers & Capital Movement
- **Net Cash Movement Tracking:** Automated calculation of net capital inflow/outflow, total lifetime and period deposits, and total withdrawals.
- **Deposit & Withdrawal Monitoring:** Complete ledger of all inbound deposits and outbound withdrawals with timestamps, reference IDs, and status.
- **Clearing & Settlement Timelines:** Real-time visibility into expected landing and clearing dates for pending transfers (e.g. "Clearing estimated Sep 15").
- **Pending Transfer Management:** Prominent alert banner highlighting pending transfers in flight, with one-tap cancellation dialog for eligible pending orders.
- **Transfer Details Audit Trail:** Bottom sheet inspection providing Transfer ID, Reference ID, linked bank account, fee breakdown (\$0.00 standard ACH), scheduled status, and clearing states.

### 2. Linked Bank Accounts & Verification
- **Connected Institutions Directory:** View all verified and pending bank relationships (Checking / Savings).
- **Primary & Default Accounts:** Clear indicators for default bank routing (`PRIMARY` badge).
- **Sensitive Data Masking:** Compliant masking of account numbers (`****1234`) and secure display of routing numbers and account holder names.
- **Verification Lifecycle:** Status chips indicating account verification (`Verified`, `Pending`, `Unlinked`, `Rejected`).
- **ACH Policy Guidance:** Transparent reference cards explaining standard 3-5 business day settlement windows, instant deposit availability limits, and cancellation criteria.

---

## Architecture & Data Flow

```
Robinhood API Endpoints
  ├── /ach/transfers/
  └── /ach/relationships/
           │
           ▼
IBrokerageService / RobinhoodService / DemoService
  ├── getAchTransfersModel()      ──► List<AchTransfer>
  ├── getAchRelationshipsModel()  ──► List<AchRelationship>
  ├── cancelAchTransfer()         ──► Future<bool>
  └── AchSummary.fromTransfersAndRelationships() ──► AchSummary
           │
           ▼
BankingWidget (Two-Tab Dashboard)
  ├── Tab 1: Transfers
  │     ├── Net Cash Flow Hero Card (Net movement, total deposits, total withdrawals)
  │     ├── Pending Transfers In-Flight Banner (Expected settlement dates)
  │     ├── Filter & Search Bar (All, Deposits, Withdrawals, Pending, Completed, search)
  │     ├── Interactive Transfer Cards (Direction icon, amount, status badge, arrival date)
  │     └── Transfer Details Bottom Sheet (Timeline, reference IDs, cancellation action)
  └── Tab 2: Linked Accounts
        ├── Connected Banks Count & Verification Summary
        ├── Bank Cards (Institution nickname, type, masked account, routing, verified badge)
        └── ACH Transfer Guidelines Card
```

---

## UI Components & Navigation

### `BankingWidget` (`lib/widgets/banking_widget.dart`)
- Accessible from:
  1. **User Settings (`user_widget.dart`)**: Under Account controls via the "Banking & Transfers" list item.
  2. **Account Badges (`user_info_widget.dart`)**: Quick access via the "Banking & Transfers" action badge.
- Fully supports pull-to-refresh (`RefreshIndicator`), fast filtering chips (Deposits, Withdrawals, Pending, Completed), live keyword search across bank nicknames and transaction IDs, and responsive design for narrow and large viewports.
