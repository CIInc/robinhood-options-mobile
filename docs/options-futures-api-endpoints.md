# Options & Futures API Endpoints

A comprehensive reference of all Options and Futures API endpoints used across brokerage integrations, mapped to the UI features and widgets that consume them.

---

## Robinhood

Base URL: `https://api.robinhood.com`

### Options — Positions

| Endpoint | Method | Description | UI Feature / Widget |
|----------|--------|-------------|---------------------|
| `/options/positions/` | GET | Fetch option positions | Home (Portfolio Overview) — `home_widget.dart` |
| `/options/aggregate_positions/?nonzero={bool}` | GET | Aggregated option positions, filterable by `chain_ids` | Home (Portfolio Overview) — `home_widget.dart` via `getOptionPositionStore` / `getAggregateOptionPositions` |

### Options — Instruments

| Endpoint | Method | Description | UI Feature / Widget |
|----------|--------|-------------|---------------------|
| `/options/instruments/?ids={ids}` | GET | Fetch option instruments by IDs | Copy Trading — `copy_trade_button_widget.dart`; Home (position enrichment) — `home_widget.dart` |
| `/options/instruments/?chain_id={chainId}&expiration_dates={date}&type={call\|put}&state={state}` | GET | Fetch option instruments by chain, expiration, and type | Option Chain — `option_chain_widget.dart` via `streamOptionInstruments` |

### Options — Chains

| Endpoint | Method | Description | UI Feature / Widget |
|----------|--------|-------------|---------------------|
| `/options/chains/?equity_instrument_id={id}` | GET | Option chain for a single equity instrument | Option Chain — `option_chain_widget.dart`; Strategy Builder — `strategy_builder_widget.dart`; Instrument Detail — `instrument_widget.dart` |
| `/options/chains/?equity_instrument_ids={ids}` | GET | Option chains for multiple equity instruments | Option Chain (batch loading) — `option_chain_widget.dart` |
| `/options/chains/{chainId}/collateral/?account_number={acct}` | GET | Collateral info for a chain | Option Chain (collateral display) — referenced in `robinhood_service.dart` |

### Options — Market Data

| Endpoint | Method | Description | UI Feature / Widget |
|----------|--------|-------------|---------------------|
| `/marketdata/options/?instruments={instrumentUrl}` | GET | Market data for a single option instrument | Option Instrument Detail — `option_instrument_widget.dart` via `getOptionMarketData`; Option Chain — `option_chain_widget.dart` |
| `/marketdata/options/?ids={ids}` | GET | Market data for multiple option instruments by ID | Home (position refresh) — `home_widget.dart` via `refreshOptionMarketData`; Option positions enrichment |
| `/marketdata/options/strategy/historicals/?bounds={bounds}&ids={ids}&interval={interval}&span={span}&types=long&ratios=1` | GET | Option strategy historical price data | Option Instrument Detail (chart) — `option_instrument_widget.dart` via `getOptionHistoricals` |

### Options — Orders

| Endpoint | Method | Description | UI Feature / Widget |
|----------|--------|-------------|---------------------|
| `/options/orders/` | GET | All option orders (paginated) | History — `history_widget.dart` via `streamOptionOrders` |
| `/options/orders/?chain_ids={chainId}` | GET | Option orders filtered by chain | Instrument Detail — `instrument_widget.dart`; Option Instrument Detail — `option_instrument_widget.dart` via `getOptionOrders` |
| `/options/orders/` | POST | Place single-leg option order | Trade Option — `trade_option_widget.dart` via `placeOptionsOrder`; Copy Trading — `copy_trade_button_widget.dart` |
| `/options/orders/` | POST | Place multi-leg option order (different payload with multiple legs) | Strategy Builder — `strategy_builder_widget.dart` via `placeMultiLegOptionsOrder` |

### Options — Events

| Endpoint | Method | Description | UI Feature / Widget |
|----------|--------|-------------|---------------------|
| `/options/events/?page_size={size}` | GET | Option events (assignments, expirations, exercises) | History — `history_widget.dart` via `streamOptionEvents` |
| `/options/events/?equity_instrument_id={instrumentUrl}` | GET | Option events for a specific instrument | Instrument Detail — `instrument_widget.dart` via `getOptionEventsByInstrumentUrl` |

### Options — Strategies (commented/reference only)

| Endpoint | Method | Description | UI Feature / Widget |
|----------|--------|-------------|---------------------|
| `/options/strategies/?strategy_codes={code}` | GET | Strategy details | Referenced in `robinhood_service.dart` (not actively called) |
| `/marketdata/options/strategy/quotes/?ids={id}&ratios=1&types=long` | GET | Strategy quote data | Referenced in `robinhood_service.dart` (not actively called) |

### Futures — Accounts

| Endpoint | Method | Description | UI Feature / Widget |
|----------|--------|-------------|---------------------|
| `/ceres/v1/accounts?rhsAccountNumber={accountNumber}` | GET | Futures account details | Home (futures initialization) — `home_widget.dart` via `getFuturesAccounts` |

### Futures — Metadata

| Endpoint | Method | Description | UI Feature / Widget |
|----------|--------|-------------|---------------------|
| `/arsenal/v1/futures/products/{productId}` | GET | Single futures product metadata | Futures Positions (enrichment) — `futures_positions_widget.dart` via `streamFuturePositions` |
| `/arsenal/v1/futures/products?productIds={ids}` | GET | Multiple futures products metadata | Futures Positions (enrichment) — `futures_positions_widget.dart` via `streamFuturePositions` |
| `/arsenal/v1/futures/contracts?contractIds={contractId}` | GET | Single futures contract metadata | Futures Positions (enrichment) — `futures_positions_widget.dart` via `streamFuturePositions` |
| `/arsenal/v1/futures/contracts?contractIds={ids}` | GET | Multiple futures contracts metadata | Futures Positions (enrichment) — `futures_positions_widget.dart` via `streamFuturePositions` |

### Futures — Market Data

| Endpoint | Method | Description | UI Feature / Widget |
|----------|--------|-------------|---------------------|
| `/marketdata/futures/quotes/v1/?ids={contractIds}` | GET | Real-time futures quotes (last trade price) | Futures Positions (Open P&L, Day P&L) — `futures_positions_widget.dart` via `streamFuturePositions` / `getFuturesPositions` |
| `/marketdata/futures/closes/v1/?ids={contractIds}` | GET | Previous close/settlement prices | Futures Positions (Day P&L) — `futures_positions_widget.dart` via `streamFuturePositions` / `getFuturesPositions` |
| `/marketdata/futures/historicals/contracts/v1/?ids={id}&interval={interval}&start={isoDate}` | GET | Futures historical price data | Futures Instrument Detail (chart) — `future_instrument_widget.dart` via `getFuturesHistoricals` |

### Futures — Positions & Orders

| Endpoint | Method | Description | UI Feature / Widget |
|----------|--------|-------------|---------------------|
| `/ceres/v1/accounts/{account}/aggregated_positions` | GET | Aggregated futures positions | Futures Positions — `futures_positions_widget.dart`; Home — `home_widget.dart` via `streamFuturePositions` / `getFuturesPositions` |
| `/ceres/v1/accounts/{account}/orders?orderState={states}` | GET | Futures orders by state | Futures Positions (order history) — `futures_positions_widget.dart` via `getFuturesOrders` |

### Futures — Margin (reference only)

| Endpoint | Method | Description | UI Feature / Widget |
|----------|--------|-------------|---------------------|
| `/ceres/v1/futures/margin_requirement?contractId={id}&marginType=MARGIN_TYPE_OVERNIGHT&accountType=ACCOUNT_TYPE_MARGIN_LIMITED` | GET | Margin requirements | Referenced in `robinhood_service.dart` (not actively called — planned feature) |

---

## Schwab

Base URL: `https://api.schwabapi.com`

### Options — Chains & Market Data

| Endpoint | Method | Description | UI Feature / Widget |
|----------|--------|-------------|---------------------|
| `/marketdata/v1/chains?symbol={symbol}&contractType=ALL&includeUnderlyingQuote=true&strategy=SINGLE` | GET | Full option chain for a symbol | Option Chain — `option_chain_widget.dart` via `getOptionChains` |
| `/marketdata/v1/chains?symbol={symbol}&contractType={type}&includeUnderlyingQuote=true&strategy=SINGLE&strike={strike}&fromDate={date}&toDate={date}` | GET | Filtered option chain by strike/date/type | Option Instrument Detail — `option_instrument_widget.dart` via `getOptionMarketData`; Option Chain — `option_chain_widget.dart` via `streamOptionInstruments` |

### Options — Positions

| Endpoint | Method | Description | UI Feature / Widget |
|----------|--------|-------------|---------------------|
| `/trader/v1/accounts?fields=positions` | GET | Account positions including options (positions embedded in account response) | Home (Portfolio Overview) — `home_widget.dart` via `getAccounts` |

### Options — Orders

| Endpoint | Method | Description | UI Feature / Widget |
|----------|--------|-------------|---------------------|
| `/trader/v1/orders?fromEnteredTime={from}&toEnteredTime={to}` | GET | All orders (filtered client-side for option orders) | History — `history_widget.dart` via `streamOptionOrders`; Option Instrument Detail — `option_instrument_widget.dart` via `getOptionOrders` |
| `/trader/v1/accounts/{accountNumber}/orders` | POST | Place single-leg option order | Trade Option — `trade_option_widget.dart` via `placeOptionsOrder` |
| `/trader/v1/accounts/{accountNumber}/orders` | POST | Place multi-leg option order (different payload) | Strategy Builder — `strategy_builder_widget.dart` via `placeMultiLegOptionsOrder` |

### Futures

Schwab does not have dedicated futures endpoints implemented in the codebase. `getFuturesHistoricals` throws `UnimplementedError`.

---

## Yahoo Finance (Options Flow Analysis)

Base URL: `https://query2.finance.yahoo.com`

| Endpoint | Method | Description | UI Feature / Widget |
|----------|--------|-------------|---------------------|
| `/v7/finance/options/{symbol}?formatted=true&lang=en-US&region=US&date={epochDate}` | GET | Option chain data (calls/puts, volume, OI, greeks, bid/ask) | Options Flow Analysis — `options_flow_widget.dart`; Options Flow Card — `options_flow_card_widget.dart`; Option Flow Detail — `option_flow_detail_widget.dart`; Option Instrument Detail (flow section) — `option_instrument_widget.dart` via `OptionsFlowStore.fetchYahooFlowItems` |
| `/v10/finance/quoteSummary/{symbol}?modules=assetProfile` | GET | Asset profile (sector, industry) for flow enrichment | Options Flow Analysis (sector tagging) — `options_flow_store.dart` via `YahooService.getAssetProfile` |

---

## Firebase Cloud Functions (Options Flow Alerts)

| Function | Description | UI Feature / Widget |
|----------|-------------|---------------------|
| `getOptionsFlow` | Fetch options flow data (deprecated — client now loads via Yahoo) | Options Flow Analysis — `options_flow_widget.dart` (commented out) |
| `createOptionAlert` | Create a custom flow alert | Options Flow Analysis (alert creation) — `options_flow_widget.dart` |
| `getOptionAlerts` | Retrieve saved flow alerts | Options Flow Analysis (alert list) — `options_flow_widget.dart` |
| `deleteOptionAlert` | Delete a flow alert | Options Flow Analysis (alert management) — `options_flow_widget.dart` |
| `toggleOptionAlert` | Enable/disable a flow alert | Options Flow Analysis (alert management) — `options_flow_widget.dart` |

---

## UI Feature → Endpoint Cross-Reference

| UI Feature | Endpoints Used |
|------------|----------------|
| **Home / Portfolio Overview** | RH: `/options/aggregate_positions/`, `/options/instruments/`, `/marketdata/options/` (refresh); Schwab: `/trader/v1/accounts?fields=positions`; RH Futures: `/ceres/v1/accounts`, `/ceres/v1/accounts/{acct}/aggregated_positions`, `/arsenal/v1/futures/*`, `/marketdata/futures/quotes/v1/`, `/marketdata/futures/closes/v1/` |
| **Option Chain** | RH: `/options/chains/`, `/options/instruments/?chain_id=`, `/marketdata/options/`; Schwab: `/marketdata/v1/chains` |
| **Option Instrument Detail** | RH: `/marketdata/options/?instruments=`, `/marketdata/options/strategy/historicals/`, `/options/orders/?chain_ids=`; Schwab: `/marketdata/v1/chains` (filtered) |
| **Strategy Builder** | RH: `/options/chains/`, `/options/orders/` (POST multi-leg); Schwab: `/trader/v1/accounts/{acct}/orders` (POST multi-leg) |
| **Trade Option** | RH: `/options/orders/` (POST single-leg); Schwab: `/trader/v1/accounts/{acct}/orders` (POST single-leg) |
| **History** | RH: `/options/orders/`, `/options/events/`; Schwab: `/trader/v1/orders` |
| **Instrument Detail** | RH: `/options/chains/`, `/options/orders/?chain_ids=`, `/options/events/?equity_instrument_id=` |
| **Copy Trading** | RH: `/options/instruments/?ids=`, `/options/orders/` (POST); Schwab: `/trader/v1/accounts/{acct}/orders` (POST) |
| **Options Flow Analysis** | Yahoo: `/v7/finance/options/`, `/v10/finance/quoteSummary/`; Firebase: `createOptionAlert`, `getOptionAlerts`, `deleteOptionAlert`, `toggleOptionAlert` |
| **Futures Positions** | RH: `/ceres/v1/accounts/{acct}/aggregated_positions`, `/arsenal/v1/futures/contracts`, `/arsenal/v1/futures/products`, `/marketdata/futures/quotes/v1/`, `/marketdata/futures/closes/v1/` |
| **Futures Instrument Detail** | RH: `/marketdata/futures/historicals/contracts/v1/` |
| **Futures Orders** | RH: `/ceres/v1/accounts/{acct}/orders` |
