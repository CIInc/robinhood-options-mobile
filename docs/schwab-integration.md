# Schwab Integration

RealizeAlpha has integrated with Charles Schwab to provide users with a broader range of brokerage options. This integration allows Schwab clients to connect their accounts and manage their portfolios directly from the RealizeAlpha app.

## Key Features

- **Account Linking:** Securely link your Schwab account using OAuth authentication.
- **Portfolio Management:** View your Schwab portfolio holdings, including stocks, options, and cash.
- **Order Management:**
    - **View Orders:** Access your history of executed and pending orders.
    - **Option Orders:** Place single-leg and multi-leg option orders through the Schwab brokerage integration. **(Updated v0.37.5)**
- **Multi-Account Position Sync (v0.39.0):** Enhanced Schwab account position mapping, account switching, and multi-account position store synchronization across portfolio and home widgets.
- **Real-Time Data:** Fetch real-time quotes and market data for your holdings.
- **Seamless Navigation:** The app's navigation has been updated to support Schwab accounts, providing a consistent experience across different brokerages.

## Getting Started

1.  **Link Account:** Go to the "Settings" or "Accounts" section in the app.
2.  **Select Schwab:** Choose "Charles Schwab" from the list of available brokerages.
3.  **Authenticate:** You will be redirected to the Schwab login page to authenticate and authorize RealizeAlpha.
4.  **Sync Data:** Once linked, your portfolio and order data will automatically sync with the app.

## Technical Details

- **`SchwabService`:** A dedicated service class handles all interactions with the Schwab API, ensuring secure and efficient data retrieval.
- **Data Models:** New data models (e.g., `Instrument.fromSchwabJson`, `OptionOrder.fromSchwabJson`) have been implemented to parse Schwab-specific data formats.
- **Token Management:** The app handles OAuth token refresh automatically to maintain a secure connection.
- **Options Trading (v0.37.5):** `SchwabService.placeOptionsOrder()` supports single-leg option orders, while `placeMultiLegOptionsOrder()` supports multi-leg strategies. Both methods use the linked Schwab account and preserve the existing order-status workflow.

## API Product Capabilities & Roadmap

The Charles Schwab Developer Portal ([developer.schwab.com](https://developer.schwab.com/)) provides two primary REST products and a high-throughput WebSocket streaming engine:

### 1. Market Data Production API (`/marketdata/v1`) — [Issue #93](https://github.com/CIInc/robinhood-options-mobile/issues/93) (Implemented)
- **Quotes (`GET /marketdata/v1/quotes`):** Real-time bid, ask, size, last trade, 52-week ranges, PE ratio, and dividend yields for individual or batch symbols via `SchwabService.getQuote()` and `refreshQuote()`.
- **Price History (`GET /marketdata/v1/pricehistory`):** Historical OHLCV candlestick bars across multiple intervals (`minute`, `daily`, `weekly`) and spans (`day`, `month`, `year`, `ytd`) with extended-hours support via `SchwabService.getInstrumentHistoricals()`. Backs interactive charts and backtesting.
- **Fundamentals (`GET /marketdata/v1/instruments?projection=fundamental`):** Fundamental statistics including market cap, EPS, shares outstanding, and dividend metrics via `SchwabService.getFundamentals()` and `getFundamentalsById()`.
- **Index Movers & Top Movers (`GET /marketdata/v1/movers/{index}`):** Real-time top gainers/losers by percentage change or volume for `$DJI`, `$COMPX`, `$SPX` via `SchwabService.getMovers()` and screener feed for `SearchWidget` via `SchwabService.getTopMovers()`.
- **Market Hours (`GET /marketdata/v1/markets`):** Operating schedules, pre-market/after-hours states, and market holiday calendars via `SchwabService.getMarketHours()`.
- **Options Expiration Chains & Market Data (`GET /marketdata/v1/chains`):** Fast retrieval of available expiration dates via `SchwabService.getOptionExpirationChain()`, option market quotes and Greeks via `SchwabService.getOptionMarketData()`, and periodic refresh via `SchwabService.refreshOptionMarketData()`.
- **Multi-Leg Strategy Option Chains (`GET /marketdata/v1/chains?strategy=...`):** Full multi-leg strategy chain parsing supporting all 11 strategies (`SINGLE`, `COVERED`, `VERTICAL`, `CALENDAR`, `STRANGLE`, `STRADDLE`, `BUTTERFLY`, `CONDOR`, `DIAGONAL`, `COLLAR`, `ROLL`) via `SchwabService.getStrategyOptionChain()` and `buildStrategyChainUrl()`. Parses `monthlyStrategyList`, composite package pricing (bid, ask, mark), spread widths, net debit/credit classifications, composite Greeks ($\Delta, \Gamma, \Theta, \mathcal{V}, \rho$), and constituent legs via `SchwabStrategyChain`, `SchwabMonthlyStrategy`, `SchwabStrategyPackage`, and `SchwabStrategyLeg`. Interactive viewing and selection provided by `SchwabStrategyChainWidget`.

### 2. Accounts & Trading Production API (`/trader/v1`) — [Issue #91](https://github.com/CIInc/robinhood-options-mobile/issues/91), [Issue #122](https://github.com/CIInc/robinhood-options-mobile/issues/122)
- **Accounts & Balances (`GET /trader/v1/accounts`):** Balances, positions, cash, and margin buying power (Implemented).
- **Account Number Hashing (`GET /trader/v1/accountNumbers`):** Multi-account mapping between masked account numbers and encrypted hash values (Implemented).
- **Order Placement (`POST /trader/v1/accounts/{accountNumber}/orders`):** Single-leg and multi-leg equity and options order routing via `SchwabService.placeInstrumentOrder`, `placeOptionsOrder`, and `placeMultiLegOptionsOrder` (Implemented).
- **Order Preview & Margin Check (`POST /trader/v1/accounts/{accountNumber}/previewOrder`):** Pre-trade validation of buying power impact, estimated commission, regulatory fees (SEC, TAF, Opt Reg), and margin requirements via `SchwabService.previewOrder`, `previewEquityOrder`, `previewOptionsOrder`, and `previewMultiLegOptionsOrder`, integrated into `TradeInstrumentWidget` and `TradeOptionWidget` with `SchwabOrderPreviewCard` (Implemented).
- **In-Flight Order Modification (`PUT /trader/v1/accounts/{accountNumber}/orders/{orderId}`):** In-flight price and contract count adjustments for working orders via `SchwabService.replaceOrder` (Implemented).
- **Order Cancellation (`DELETE /trader/v1/accounts/{accountNumber}/orders/{orderId}`):** Working order cancellation with populated `cancel` and `cancelUrl` links (Implemented).
- **Transaction History & Dividends (`GET /trader/v1/accounts/{accountNumber}/transactions`) — [Issue #91](https://github.com/CIInc/robinhood-options-mobile/issues/91) (Implemented):** Historical executions, dividends, interest credits, cash transfers, and fee audits via `SchwabService.getSchwabTransactions()`, `getSchwabTransaction()`, `getDividends()`, `streamDividends()`, `getInterests()`, and `streamInterests()`. Integrates directly with `DividendStore` and `IncomeTransactionsWidget` for dividend yield and cash flow tracking. Dedicated interactive viewing, filtering (trades, income, cash, fees, symbol, date presets `1M`/`3M`/`6M`/`YTD`/`1Y`/custom), and CSV export provided by `SchwabTransactionsWidget`.
- **User Preferences (`GET /trader/v1/userPreference`) — [Issue #91](https://github.com/CIInc/robinhood-options-mobile/issues/91) (Implemented):** Account defaults, primary account detection, streamer connection credentials, and market data offer permissions via `SchwabService.getUserPreferences()` and `SchwabUserPreference`.

### 3. Schwab Real-Time WebSocket Streamer (`wss://streamer-api.schwab.com/ws`) — [Issue #145](https://github.com/CIInc/robinhood-options-mobile/issues/145) (Implemented)
- **Session Handshake:** Connects to `wss://streamer-api.schwab.com/ws` and issues `ADMIN` `LOGIN` handshake with OAuth access token and correlation metadata from `GET /trader/v1/userPreference` (`schwabClientCustomerId`, `schwabClientCorrelId`, `schwabClientChannel`, `schwabClientFunctionId`).
- **Level 1 Equity Quotes (`LEVELONE_EQUITIES`):** Sub-second streaming quote updates (`SchwabEquityQuoteUpdate`, `Quote.fromSchwabStreamer`) tracking bid, ask, size, last price, volume, day high/low, and 52-week ranges.
- **Level 1 Options & Greeks (`LEVELONE_OPTIONS`):** Streaming option market data and real-time Greeks (`SchwabOptionQuoteUpdate`, `OptionMarketData.fromSchwabStreamer`) tracking Delta, Gamma, Theta, Vega, Rho, and Implied Volatility (IV).
- **Account & Order Activity (`ACCT_ACTIVITY`):** Push-based order fill notifications, cancellations, and execution confirmations via `SchwabAccountActivity`.
- **Live Candle Streaming (`CHART_EQUITY`):** 1-minute OHLCV candlestick bar push feeds for active chart views via `SchwabChartBarUpdate`.
- **Futures & Forex (`LEVELONE_FUTURES`, `LEVELONE_FOREX`):** Real-time streaming for Schwab futures contracts (`/ES`, `/NQ`) and currency pairs (`EUR/USD`).
- **Connection Watchdog & Reconnection:** Built-in heartbeat tracking (`{"notify": [{"heartbeat": "..."}]}`) and exponential backoff auto-reconnect with state preservation (automatically re-subscribes all active tickers upon reconnect).
