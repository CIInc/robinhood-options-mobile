# Insider Activity & Sentiment

RealizeAlpha provides detailed tracking of corporate insider transactions and net sentiment using first-party Robinhood market data endpoints to help investors understand how company executives and directors are positioning themselves.

## Overview

Insider activity refers to stock transactions made by company officers, directors, and $>10\%$ beneficial owners reported on SEC Form 4 filings within two business days. While executives frequently sell shares for diversification, tax planning, or under pre-scheduled Rule 10b5-1 plans, open-market insider purchases historically signal strong executive conviction in the company's future prospects.

## Features

### First-Party Market Data Endpoints
- **Monthly Summary**: `GET /marketdata/insiders/summary/{instrument_id}/` provides net sentiment classification, numeric sentiment scores, aggregate buy/sell shares, aggregate buy/sell values, transaction counts, and monthly breakdown.
- **Form 4 Transactions**: `GET /marketdata/insiders/transactions/{instrument_id}/` returns itemized officer and director transactions with trade dates, filing dates, Form 4 transaction codes (`P`, `S`, `M`, `A`), share amounts, execution prices, total transaction values, shares held after trade, and direct/indirect ownership status.

### Transaction Activity & Sentiment
- **Net Sentiment Badge**: Dynamic color-coded badge indicating `Net Buying` (green), `Net Selling` (red), or `Neutral` (grey).
- **Buy / Sell Volume Ratio Split Bar**: Two-tone visual progress bar contrasting total insider purchase value against total insider sale value with exact percentages and dollar totals.
- **Primary Metrics**:
  - **Net Bias**: Net dollar value (+/-) and net shares transacted.
  - **Purchases**: Total buy volume, transaction count, and total shares bought.
  - **Sales**: Total sell volume, transaction count, and total shares sold.
- **Monthly Aggregate Trend**: Horizontal scrollable badges illustrating month-by-month net insider capital flows (e.g. Aug 2026: +$9.7M, Jul 2026: +$4.1M).
- **Recent Form 4 Transactions**: Itemized list of recent filings featuring:
  - Filer name and executive title (e.g., CEO, CFO, Director).
  - Transaction type chip with color-coded icons:
    - **Purchase (Code P)**: Green (`Icons.trending_up`)
    - **Sale (Code S)**: Red (`Icons.trending_down`)
    - **Option Exercise (Code M)**: Orange (`Icons.timelapse`)
    - **Grant / Award (Code A)**: Blue (`Icons.card_giftcard`)
  - Shares transacted, execution price, total dollar value, and trade date.
- **Full History Modal**: Expandable sheet with category filtering (`All`, `Purchases`, `Sales`, `Options`, `Grants`) and detailed post-trade holdings and SEC Form 4 EDGAR links.
- **Educational Context**: Explains Rule 10b5-1 scheduled sales versus open-market purchases.

## Architecture

- **Models**: [src/robinhood_options_mobile/lib/model/insider_sentiment.dart](../src/robinhood_options_mobile/lib/model/insider_sentiment.dart)
  - `InsiderSentimentSummary`: Aggregate metrics, buy/sell ratios, and classification.
  - `MonthlyInsiderActivity`: Monthly time-series data.
  - `InsiderTransactionRecord`: Individual SEC Form 4 transaction parsing.
  - `InsiderTransaction`: Legacy Yahoo bridge in [src/robinhood_options_mobile/lib/model/insider_transaction.dart](../src/robinhood_options_mobile/lib/model/insider_transaction.dart).
- **Service Layer**: [src/robinhood_options_mobile/lib/services/ibrokerage_service.dart](../src/robinhood_options_mobile/lib/services/ibrokerage_service.dart)
  - `getInsiderSummary(BrokerageUser user, String instrumentId)`
  - `getInsiderTransactions(BrokerageUser user, String instrumentId)`
  - Implemented in `RobinhoodService` and `DemoService` (realistic data for AAPL, TSLA, GME).
- **UI Widget**: [src/robinhood_options_mobile/lib/widgets/insider_activity_widget.dart](../src/robinhood_options_mobile/lib/widgets/insider_activity_widget.dart)
  - Embedded in [src/robinhood_options_mobile/lib/widgets/instrument_widget.dart](../src/robinhood_options_mobile/lib/widgets/instrument_widget.dart) under the stock Market Intelligence section.

## How to Use
1. Navigate to a stock's instrument detail page.
2. Scroll to the **Market Intelligence** section (below Retail Order Flow and Short Interest).
3. Review the **Insider Sentiment & Activity** card.
4. Tap **View All** to inspect the full list of SEC Form 4 transactions with category filtering.
