# Forex Trading

RealizeAlpha now features full **Forex Trading** support for global currency pairs alongside equities, options, futures, and crypto. Users can analyze exchange rates, trade currency pairs with standard lot sizing and risk controls, and practice strategies via Paper Trading.

## Key Features

### 1. Currency Pair Universe
- **Major Pairs:** EUR/USD, USD/JPY, GBP/USD, USD/CHF, AUD/USD, USD/CAD, NZD/USD.
- **Cross Pairs:** EUR/JPY, GBP/JPY, AUD/JPY, NZD/JPY, CAD/JPY, EUR/CHF.
- **Emerging & High-Yield Pairs:** USD/MXN, USD/BRL.

### 2. Standardized Lot Sizing & Pip Calculations
- **Lot Presets:**
  - **Micro Lot:** 1,000 units (standard for retail testing and precise capital management).
  - **Mini Lot:** 10,000 units (standard $1/pip on USD quote pairs).
  - **Standard Lot:** 100,000 units (standard $10/pip on USD quote pairs).
  - **Custom Units:** Fine-grained unit input with dynamic estimation.
- **Live Pip Value Display:** Automatically displays the estimated dollar pip value ($0.0001 for standard quote pairs, $0.01 for JPY quote pairs) based on configured order volume.

### 3. Execution & Risk Controls
- **Order Types:**
  - **Market Orders:** Immediate fill at current prevailing bid/ask.
  - **Limit Orders:** Execution at a specified limit price or better.
  - **Stop Orders:** Risk management orders triggered when the exchange rate reaches a specified stop threshold.
- **RiskGuard Integration:** Validates order notional against account buying power, volatility bands, and macro regime risk.
- **Paper & Demo Trading:** Simulated order routing via `PaperService` and `DemoService` with instant fill confirmation, cash balance adjustment, and order auditing.

### 4. Market Data Sources & Real-Time / Delayed Integration
- **Yahoo Finance Integration:** Direct streaming of real-time and delayed currency pair spot quotes (`EURUSD=X`, `USDJPY=X`, `GBPUSD=X`, etc.) and candlestick bar intervals (1D 5m, 1W 15m, 1M 1h, 1Y 1d).
- **Twelve Data Integration:** Server-side mapping in Cloud Functions (`functions/src/market-data.ts`) supporting Twelve Data's standard `BASE/QUOTE` notation (e.g. `EUR/USD`, `USD/JPY`) with automated caching and fallback.
- **Multi-Broker Fallback:** `PaperService`, `DemoService`, `FidelityService`, `SchwabService`, and `RobinhoodService` utilize unified `YahooService` forex quote and candlestick fetching for currency pairs not served by native brokerage endpoints.

### 5. Integration with Analytics & Optimization
- Quick navigation from any currency pair instrument view (`ForexInstrumentWidget`) directly into the [Carry Trade Optimizer](carry-trade-optimizer.md).
- Native support in Multi-Asset Portfolio Allocation and Rebalancing tools.
