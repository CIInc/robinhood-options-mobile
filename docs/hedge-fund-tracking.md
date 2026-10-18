# Institutional & Hedge Fund Tracking

RealizeAlpha integrates first-party Robinhood market data endpoints to provide real-time institutional hedge fund sentiment, quarterly manager holdings, and transaction history directly within the instrument detail view.

## Overview

Hedge funds and institutional asset managers control trillions in assets and report their long equity holdings to the SEC on Form 13F within 45 days of the end of each calendar quarter. Tracking aggregate institutional manager accumulation versus distribution offers key insights into smart money conviction and long-term capital flows.

## Features

### First-Party Market Data Endpoints
- **Quarterly Summary**: `GET /marketdata/hedgefunds/summary/{instrument_id}/` provides aggregate net sentiment score (e.g., `Positive Sentiment`), overall holdings, quarterly manager buying vs. selling breakdown, and multi-quarter transaction aggregates.
- **Detailed Transactions & Holdings**: `GET /marketdata/hedgefunds/transactions/{instrument_id}/` returns itemized institutional hedge fund positions with manager names, firm/institution names, actions (`Added`, `Reduced`, `Opened Position`, `Closed Position`, `No Change`), shares traded, total shares held, market values, change percentages, and portfolio allocation percentages.

### Sentiment & Manager Positioning UI
- **Net Sentiment Badge**: Dynamic color-coded badge indicating `Accumulation` (green), `Distribution` (red), or `Neutral` (grey).
- **Buyers vs. Sellers Split Bar**: Two-tone visual progress bar contrasting the percentage and count of funds buying versus selling the stock.
- **Key Metrics Grid**:
  - **Net Flow**: Net quarterly capital flow (+/-) and net shares transacted.
  - **Held Value**: Estimated market value of all shares held by tracked funds.
  - **Total Funds**: Total count of active institutional funds covering the stock.
  - **Ownership %**: Percentage of shares held by institutions when available.
- **Quarterly Manager Trends**: Horizontal scrollable chips illustrating multi-quarter net institutional flows (e.g., `Q2 2026: +$5.5B, 184B / 86S`).
- **Top Institutional Filings**: Itemized list of premier hedge funds (e.g., Berkshire Hathaway, Bridgewater Associates, Coatue Management, Appaloosa Management) displaying manager name, action badge, shares held, and position value.
- **Detailed Holdings Modal**: Full-screen bottom sheet with scrollable access to all tracked institutional hedge fund positions and trade actions.

## Architecture & Integration

- **Model**: [src/robinhood_options_mobile/lib/model/hedge_fund_sentiment.dart](../src/robinhood_options_mobile/lib/model/hedge_fund_sentiment.dart)
  - `HedgeFundSummary`: Aggregate sentiment, buyer/seller counts, net capital flows, and quarterly trend list.
  - `QuarterlyHedgeFundActivity`: Quarter-by-quarter aggregate metrics.
  - `HedgeFundTransactionRecord`: Itemized fund filing data matching `/marketdata/hedgefunds/transactions/`.
- **Service Layer**: [src/robinhood_options_mobile/lib/services/ibrokerage_service.dart](../src/robinhood_options_mobile/lib/services/ibrokerage_service.dart)
  - `getHedgeFundSummary(BrokerageUser user, String instrumentId)`
  - `getHedgeFundTransactions(BrokerageUser user, String instrumentId)`
  - Implemented in `RobinhoodService` (live API) and `DemoService` (deterministic mock data for AAPL, TSLA, GME).
- **UI Widget**: [src/robinhood_options_mobile/lib/widgets/hedge_fund_activity_widget.dart](../src/robinhood_options_mobile/lib/widgets/hedge_fund_activity_widget.dart)
  - Integrated into [src/robinhood_options_mobile/lib/widgets/instrument_widget.dart](../src/robinhood_options_mobile/lib/widgets/instrument_widget.dart) sliver list alongside Short Interest, Retail Order Flow, and Insider Sentiment.
