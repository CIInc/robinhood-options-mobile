# Pattern Day Trader (PDT) Protection & Counter

## Overview

Under **FINRA Rule 4210**, a trader who executes **four or more day trades within five business days** in a margin account is designated as a **Pattern Day Trader (PDT)**, provided the number of day trades represents more than 6% of the customer's total trades in that margin account for that period.

When designated as a Pattern Day Trader:
- The account must maintain a **minimum equity of $25,000** at the close of every business day.
- If equity drops below $25,000, day trading is restricted, or the account is limited to closing transactions only for 90 days (unless a broker one-time reset is granted).
- Cash accounts are not subject to PDT restrictions, though they must abide by standard cash settlement rules.

The **Pattern Day Trader (PDT) Protection & Counter** feature provides real-time monitoring of rolling 5-business-day day trades, visual countdown meters, FINRA threshold tracking, and automated risk alerts to safeguard traders from unexpected account restrictions.

---

## Core Architecture & Components

```
┌─────────────────────────────────────────────────────────────┐
│                      Robinhood API / Brokerage               │
│  • /accounts/{account}/recent_day_trades/                   │
│  • /accounts/ margin_balances (day_trades_protection, dtbp)  │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                     Service Layer                           │
│  • RobinhoodService.getRecentDayTrades()                    │
│  • DemoService.getRecentDayTrades() (Mock for testing/demo) │
│  • IBrokerageService contract                               │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                     Data Models                             │
│  • DayTrade: Equity & Option executions with drop-off dates  │
│  • DayTradeSummary: Rolling count, DTBP, FINRA risk level   │
│  • PdtRiskLevel: safe | warning | danger | flagged | exempt │
│  • Account: Parsed margin balances & protection flags        │
└──────────────────────────────┬──────────────────────────────┘
                               │
              ┌────────────────┴────────────────┐
              ▼                                 ▼
┌───────────────────────────┐     ┌───────────────────────────┐
│  PortfolioAlertService    │     │   DayTradeMonitorWidget   │
│  • Action Center alerts   │     │  • 4-segment visual meter │
│  • Critical: 0 left / PDT │     │  • $25k equity progress   │
│  • Warning: 1 left        │     │  • Filterable trade list  │
│  • Exempt if $25k+ equity │     │  • FINRA Rule 4210 FAQ    │
└───────────────────────────┘     └───────────────────────────┘
```

---

## Data Models

### `DayTrade` (`lib/model/day_trade.dart`)
Represents an individual equity or option day trade:
- `symbol`: Ticker or option contract (e.g. `AAPL`, `TSLA 260327C00220000`)
- `type`: `'equity'` or `'option'`
- `executionDate`: Calendar date of execution
- `timestamp`: Precise execution timestamp
- `direction`: e.g. `buy_then_sell`
- `price` & `quantity`: Execution price and share/contract volume
- `dropOffDate`: Automatically computed as **5 business days** following execution (skipping weekends and market holidays)
- `remainingTradingDays`: Number of business days before the trade rolls out of the rolling window
- `isExpired`: Whether 5 business days have elapsed

### `DayTradeSummary` (`lib/model/day_trade.dart`)
Aggregates rolling day trade activity for an account:
- `activeDayTradeCount`: Sum of non-expired trades in the 5-day window
- `remainingDayTrades`: Number of day trades remaining before hitting the 3-trade ceiling (or -1 if exempt)
- `isPdtExempt`: `true` if `portfolioEquity >= $25,000` or if the account is a cash account
- `riskLevel`:
  - `safe`: 0 or 1 trade used (2 or 3 trades remaining)
  - `warning`: 2 trades used (1 trade remaining)
  - `danger`: 3 trades used (0 trades remaining; next trade triggers PDT designation)
  - `flagged`: 4+ trades used or marked PDT with equity under $25,000
  - `exempt`: Account equity $\ge \$25,000$ or cash account
- `equityDeficitTo25k`: Dollar amount required to reach the $25,000 exemption threshold

---

## User Interface: `DayTradeMonitorWidget`

Accessible via **User Profile $\rightarrow$ Features $\rightarrow$ Day Trade & PDT Monitor** and through the account details chip in **User Info**:

1. **Header & 4-Segment Visual Counter**:
   - Visual color-coded gauge representing the 3 allowable day trades and the 4th restriction trigger.
   - Dynamic badges displaying risk status (`Safe`, `Warning`, `PDT Limit Reached`, `Pattern Day Trader Flagged`, `PDT Exempt`).
2. **FINRA $25,000 Equity Threshold Progress**:
   - Visual progress bar toward the $25,000 benchmark.
   - Live calculation of equity deficit required to unlock unlimited day trades.
3. **Protection & Buying Power Panel**:
   - Robinhood Day Trade Protection status chip (blocks orders that would trigger PDT).
   - Day Trade Buying Power (DTBP) with margin ratio leverage display (e.g., 25% margin / 4x leverage).
   - PDT Restriction Expiry date if under a 90-day cooldown.
4. **Recent Day Trades List**:
   - Filterable by `All`, `Stocks`, and `Options`.
   - Per-trade card with symbol, execution timestamp, trade direction, and drop-off countdown (e.g. `Rolls off in 2 days • Mon, Oct 19`).
5. **FINRA Rule 4210 FAQ & Guidance Accordion**:
   - In-app explainer covering FINRA requirements, margin rules, and roll-off calculations.

---

## Action Center Integration

`PortfolioAlertService` evaluates day trade status:
- **Critical Alert (`pdt-limit-reached`)**: Surfaced when 3 of 3 trades have been executed and equity is under $25,000.
- **Critical Alert (`pdt-flagged`)**: Surfaced when the account has been marked as PDT and equity is under $25,000.
- **Warning Alert (`pdt-warning`)**: Surfaced when 2 of 3 trades have been executed (1 trade remaining).
- **Auto-Suppression**: Alerts are automatically suppressed if the account maintains $\ge \$25,000$ equity or is a cash account.
