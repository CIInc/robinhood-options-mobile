# Twelve Data Migration Plan

## Cost Summary

### Twelve Data Pricing Tiers

| Plan | Price | Credits/min | Credits/day | Best For |
|------|-------|-------------|-------------|----------|
| Basic | Free | 8 | 800 | Development/testing |
| Grow | $79/mo | 55+ | ~5,500 | N/A (personal use only) |
| Pro | $229/mo | 610+ | ~61,000 | Production (commercial OK for US equities) |
| Ultra | $999/mo | 2,584+ | ~258,400 | High-volume production |
| Enterprise | $1,999/mo | 10,000+ | ~1,000,000 | Full-scale commercial |

### Credit Costs Per Endpoint

| Endpoint | Credits | Min Plan |
|----------|---------|----------|
| `/time_series` | 1/symbol | Basic |
| `/quote` | 1/symbol | Basic |
| `/price` | 1/symbol | Basic |
| `/symbol_search` | 1/request | Basic |
| `/profile` | 10/symbol | Grow |
| `/statistics` | 10/symbol | Grow |
| `/insider_transactions` | 200/symbol | Pro |
| `/institutional_holders` | 1500/symbol | Ultra |
| `/mutual_funds/world/sustainability` | 200/request | Ultra |
| WebSocket `/quotes/price` | 1 WS credit/symbol | Grow |

### Commercial Usage Notes

- Pro/Ultra/Enterprise plans allow commercial display of US equities price data
- Basic/Grow plans are personal non-commercial use only
- Redistribution of raw data feeds requires a separate agreement
- ASX (Australian) data is restricted regardless of plan

### Recommended Plan: Pro ($229/mo)

- Covers all core features (historical, quotes, search, profiles, insider transactions)
- Commercial display allowed for US equities
- 610+ credits/min handles typical app usage
- Only gaps: institutional holders (needs Ultra) and ESG (not available for stocks)

---

## Functional Group Mappings

### 1. Historical OHLCV Data

**Current Implementation:**
- Yahoo: `GET https://query2.finance.yahoo.com/v8/finance/chart/{symbol}?interval={interval}&range={range}`
- Fidelity (fallback): `GET https://fastquote.fidelity.com/service/marketdata/historical/chart/json`

**Twelve Data Replacement:**
- `GET https://api.twelvedata.com/time_series?symbol={symbol}&interval={interval}&outputsize={outputsize}`
- Credit cost: 1 credit per symbol per request
- Min plan: Basic

**Interval Mapping:**

| Current (Yahoo) | Twelve Data | Notes |
|-----------------|-------------|-------|
| `1d` | `1day` | |
| `1h` | `1h` | |
| `30m` | `30min` | |
| `15m` | `15min` | |
| `5m` | `5min` | |
| `1m` | `1min` | |
| `1wk` | `1week` | |
| `1mo` | `1month` | |

**Range → outputsize Mapping:**

| Current (Yahoo range) | Twelve Data approach |
|----------------------|---------------------|
| `1d` | `outputsize=1` with intraday interval |
| `5d` | `outputsize=5` with `1day` or use `start_date`/`end_date` |
| `1mo` | `outputsize=22` with `1day` |
| `3mo` | `outputsize=66` with `1day` |
| `6mo` | `outputsize=132` with `1day` |
| `1y` | `outputsize=252` with `1day` |
| `2y` | `outputsize=504` with `1day` |
| `5y` | `outputsize=1260` with `1day` |
| `ytd` | Use `start_date=YYYY-01-01` |
| `max` | `outputsize=5000` (max) |

**Response Format Differences:**
- Yahoo returns: `chart.result[0].indicators.quote[0].{open,high,low,close,volume}` + `chart.result[0].timestamp`
- Twelve Data returns: `values[].{datetime,open,high,low,close,volume}` (array of objects, newest first)
- Twelve Data also returns `meta.{symbol,interval,currency,exchange,type}`

**Files Affected:**
- `src/robinhood_options_mobile/functions/src/market-data.ts` — `getMarketData()` function (primary target)
- `src/robinhood_options_mobile/lib/services/yahoo_service.dart` — `getMarketIndexHistoricals()`, `getHistoricals()`
- `src/robinhood_options_mobile/lib/services/fidelity_service.dart` — `getInstrumentHistoricals()` (delegates to Yahoo)

**Consumers (server-side via getMarketData):**
- `agentic-trading.ts`, `agentic-trading-cron.ts`, `agentic-trading-intraday-cron.ts`
- `macro-agent.ts`
- `backtesting.ts`
- `alpha-factor-discovery.ts`
- `custom-alerts-cron.ts`, `watchlist-alerts-cron.ts`
- `paper-trading-cron.ts`
- `rebalancing-cron.ts`
- `alpha-agent.ts`
- `riskguard-agent.ts`

---

### 2. Real-Time Quotes

**Current Implementation:**
- Yahoo: `GET https://query2.finance.yahoo.com/v7/finance/quote?symbols={symbols}`
- Fidelity: `GET https://fastquote.fidelity.com/service/quote/json?productid=embeddedquotes&symbols={symbols}`

**Twelve Data Replacement (REST):**
- `GET https://api.twelvedata.com/quote?symbol={symbol}`
- Credit cost: 1 credit per symbol
- Min plan: Basic
- Returns: open, high, low, close, volume, previous_close, change, percent_change, 52-week high/low, etc.

**Twelve Data Replacement (WebSocket for real-time streaming):**
- `wss://ws.twelvedata.com/v1/quotes/price`
- Credit cost: 1 WS credit per symbol
- Min plan: Grow
- Use for features needing sub-minute updates (custom alerts, intraday trading)

**Twelve Data Lightweight Alternative:**
- `GET https://api.twelvedata.com/price?symbol={symbol}`
- Credit cost: 1 credit per symbol
- Returns only the latest price (minimal payload)
- Good for: watchlist alerts, paper trading checks

**Files Affected:**
- `src/robinhood_options_mobile/functions/src/market-data.ts` — `getQuotes()` function
- `src/robinhood_options_mobile/functions/src/riskguard-agent.ts` — `getSymbolInfo()` (uses `/v7/finance/quote` for sector/beta/PE)
- `src/robinhood_options_mobile/lib/services/yahoo_service.dart` — `getQuote()`, `getQuotesByIds()`, `getInstruments()`, `getFundamentals()`
- `src/robinhood_options_mobile/lib/services/fidelity_service.dart` — `getQuotesFromFidelity()`, `getQuoteByIds()`

---

### 3. Options Chains ⚠️ NOT AVAILABLE ON TWELVE DATA

**Current Implementation:**
- Yahoo: `GET https://query2.finance.yahoo.com/v7/finance/options/{symbol}`

**Twelve Data Replacement: NONE**

Twelve Data does NOT have an options chain endpoint. This is the biggest gap in the migration.

**Recommended Alternatives:**
1. **Keep Yahoo Finance** (server-side only) — lowest effort, free, but fragile
2. **Tradier** ($0/mo for delayed, market data API free for developers) — has full options chains
3. **MarketData.app** — options chain API available
4. **CBOE DataShop** — authoritative source but expensive

**Files Affected:**
- `src/robinhood_options_mobile/functions/src/options-flow-utils.ts` — `fetchYahooOptions()` (entire options flow feature)
- `src/robinhood_options_mobile/lib/services/yahoo_service.dart` — `getOptionChain()`

**Features Impacted:**
- Options Flow Analysis (options-flow-cron.ts)
- Options chain display in the app
- Options flow scoring and unusual activity detection

---

### 4. Symbol Search

**Current Implementation:**
- Yahoo: `GET https://query2.finance.yahoo.com/v1/finance/search?q={query}`

**Twelve Data Replacement:**
- `GET https://api.twelvedata.com/symbol_search?symbol={query}`
- Credit cost: 1 credit per request
- Min plan: Basic
- Returns: symbol, instrument_name, exchange, mic_code, country, type

**Differences:**
- Yahoo returns: `quotes[].{symbol, longname, shortname, typeDisp, exchDisp, quoteType}`
- Twelve Data returns: `data[].{symbol, instrument_name, exchange, mic_code, country, type}`
- Twelve Data `type` values: `Common Stock`, `ETF`, `Index`, etc.

**Files Affected:**
- `src/robinhood_options_mobile/lib/services/yahoo_service.dart` — `search()`

---

### 5. Company Profile / Fundamentals

**Current Implementation:**
- Yahoo: `GET https://query2.finance.yahoo.com/v10/finance/quoteSummary/{symbol}?modules=assetProfile`

**Twelve Data Replacement:**
- `GET https://api.twelvedata.com/profile?symbol={symbol}`
- Credit cost: 10 credits per symbol
- Min plan: Grow
- Returns: name, exchange, mic_code, sector, industry, employees, website, description, type, CEO, address, phone

**Additional Fundamentals:**
- `GET https://api.twelvedata.com/statistics?symbol={symbol}`
- Credit cost: 10 credits per symbol
- Min plan: Grow
- Returns: market_cap, shares_outstanding, pe_ratio, eps, dividend_yield, 52_week_high/low, beta, etc.
- Also includes: `percent_held_by_insiders`, `percent_held_by_institutions` (lightweight alternative to full institutional holders)

**Files Affected:**
- `src/robinhood_options_mobile/functions/src/options-flow-utils.ts` — `fetchYahooQuoteSummary()` (sector lookup)
- `src/robinhood_options_mobile/lib/services/yahoo_service.dart` — `getAssetProfile()`

---

### 6. Stock Screeners ⚠️ NOT AVAILABLE ON TWELVE DATA

**Current Implementation:**
- Yahoo: `GET https://query2.finance.yahoo.com/v1/finance/screener/predefined/saved?scrIds={screenerId}`

**Twelve Data Replacement: NONE**

Twelve Data does not have a stock screener API.

**Recommended Alternatives:**
1. **Keep Yahoo Finance** for screeners (server-side) — these are read-only, low-frequency calls
2. **Build custom screeners** using Twelve Data's `/stocks` list endpoint + `/quote` batch calls
3. **Financial Modeling Prep** — has screener API ($29/mo)

**Files Affected:**
- `src/robinhood_options_mobile/lib/services/yahoo_service.dart` — `getStockScreener()`, `getMovers()`

---

### 7. Insider Transactions

**Current Implementation:**
- Yahoo: `GET https://query2.finance.yahoo.com/v10/finance/quoteSummary/{symbol}?modules=insiderTransactions`

**Twelve Data Replacement:**
- `GET https://api.twelvedata.com/insider_transactions?symbol={symbol}`
- Credit cost: 200 credits per symbol
- Min plan: Pro
- Returns: full_name, position, date_reported, transaction_type, shares, value, etc.

**Files Affected:**
- `src/robinhood_options_mobile/lib/services/yahoo_service.dart` — `getInsiderTransactions()`

---

### 8. Institutional Ownership

**Current Implementation:**
- Yahoo: `GET https://query2.finance.yahoo.com/v10/finance/quoteSummary/{symbol}?modules=institutionOwnership,majorHoldersBreakdown`

**Twelve Data Replacement:**
- `GET https://api.twelvedata.com/institutional_holders?symbol={symbol}`
- Credit cost: 1500 credits per symbol ⚠️ Very expensive
- Min plan: Ultra ($999/mo)

**Cost-Effective Alternative:**
- Use `/statistics` endpoint (10 credits, Grow plan) which includes `percent_held_by_insiders` and `percent_held_by_institutions`
- This covers the summary percentages but NOT the detailed holder list
- For detailed holder list, consider keeping Yahoo as fallback or using a cheaper provider

**Files Affected:**
- `src/robinhood_options_mobile/lib/services/yahoo_service.dart` — `getInstitutionalOwnership()`

---

### 9. ESG Scores ⚠️ LIMITED ON TWELVE DATA

**Current Implementation:**
- Yahoo: `GET https://query2.finance.yahoo.com/v10/finance/quoteSummary/{symbol}?modules=esgScores`

**Twelve Data Replacement:**
- `GET https://api.twelvedata.com/mutual_funds/world/sustainability`
- Credit cost: 200 credits per request
- Min plan: Ultra ($999/mo)
- ⚠️ Only available for mutual funds, NOT individual stocks

**Recommended Alternatives:**
1. **Keep Yahoo Finance** for ESG (server-side) — it's the only free source for individual stock ESG
2. **Sustainalytics / MSCI ESG** — commercial ESG data providers (expensive)
3. **Remove feature** if ESG is not a core differentiator

**Files Affected:**
- `src/robinhood_options_mobile/lib/services/yahoo_service.dart` — `getESGScores()`

---

### 10. Put/Call Ratios (CBOE) — NO CHANGE NEEDED

**Current Implementation:**
- CBOE: `GET https://cdn.cboe.com/data/us/options/market_statistics/daily/{date}_daily_options`

**Migration:** None required. CBOE is a free public endpoint and is independent of Yahoo/Fidelity.

**Files Affected:**
- `src/robinhood_options_mobile/functions/src/market-data.ts` — `fetchFromCBOE()`

---

### 11. Auth / Session (Yahoo Crumb)

**Current Implementation:**
- Yahoo: `GET https://query2.finance.yahoo.com/v1/test/getcrumb` (with cookie from `fc.yahoo.com` or `finance.yahoo.com`)

**Twelve Data Replacement:**
- Simple API key authentication via query parameter: `?apikey={your_api_key}`
- No cookie/crumb dance needed
- Much simpler and more reliable

**Files Affected:**
- `src/robinhood_options_mobile/functions/src/options-flow-utils.ts` — `fetchCrumb()`
- `src/robinhood_options_mobile/lib/services/yahoo_service.dart` — `_fetchCrumb()`, `getJson()`

---

## Migration Summary Table

| Functional Group | Yahoo Endpoint | Twelve Data Endpoint | Credits | Plan | Status |
|-----------------|---------------|---------------------|---------|------|--------|
| Historical OHLCV | `/v8/finance/chart` | `/time_series` | 1 | Basic | ✅ Direct replacement |
| Real-Time Quotes | `/v7/finance/quote` | `/quote` or `/price` | 1 | Basic | ✅ Direct replacement |
| Real-Time Streaming | N/A | WebSocket `/quotes/price` | 1 WS | Grow | ✅ Upgrade |
| Options Chains | `/v7/finance/options` | — | — | — | ❌ Not available |
| Symbol Search | `/v1/finance/search` | `/symbol_search` | 1 | Basic | ✅ Direct replacement |
| Company Profile | `/v10/.../assetProfile` | `/profile` | 10 | Grow | ✅ Direct replacement |
| Statistics | `/v7/finance/quote` (partial) | `/statistics` | 10 | Grow | ✅ Direct replacement |
| Stock Screeners | `/v1/.../screener` | — | — | — | ❌ Not available |
| Insider Transactions | `/v10/.../insiderTransactions` | `/insider_transactions` | 200 | Pro | ✅ Direct replacement |
| Institutional Holders | `/v10/.../institutionOwnership` | `/institutional_holders` | 1500 | Ultra | ⚠️ Very expensive |
| ESG Scores | `/v10/.../esgScores` | `/mutual_funds/.../sustainability` | 200 | Ultra | ⚠️ Mutual funds only |
| Put/Call Ratios | CBOE (free) | Keep CBOE | 0 | — | ✅ No change |
| Auth/Session | Crumb + Cookie | API Key param | 0 | — | ✅ Simpler |

---

## Credit Budget Estimation (Pro Plan — 610 credits/min, ~61,000/day)

### Server-Side (Cloud Functions)

| Feature | Frequency | Symbols | Credits/Run | Daily Credits |
|---------|-----------|---------|-------------|---------------|
| Agentic Trading Cron | 1x/day (4PM) | ~50 | 50 | 50 |
| Agentic Intraday Cron | Every 15min (market hours) | ~50 | 50 | 1,400 |
| Macro Agent | 1x/day | ~10 | 10 | 10 |
| Options Flow Cron | Every 15min | ~100 | 100 | 2,800 |
| Custom Alerts Cron | Every 5min | ~200 | 200 | 11,200 |
| Watchlist Alerts Cron | Hourly (market hours) | ~100 | 100 | 700 |
| Rebalancing Cron | 1x/day | ~30 | 30 | 30 |
| Paper Trading Cron | 1x/day | ~20 | 20 | 20 |
| Alpha Agent | On-demand | ~20 | 20 | ~100 |
| RiskGuard Agent | On-demand | ~5 | 5 | ~50 |
| **Server Total** | | | | **~16,360** |

### Client-Side (Mobile App)

| Feature | Frequency | Credits/User/Day | Est. Users | Daily Credits |
|---------|-----------|-----------------|------------|---------------|
| Home Widget (quotes) | App open | ~10 | 100 | 1,000 |
| Instrument Detail | Per view | ~5 | 100 | 500 |
| Search | Per query | 1 | 100 | 100 |
| Portfolio Analytics | Per view | ~20 | 50 | 1,000 |
| Insider Activity | Per view | 200 | 20 | 4,000 |
| **Client Total** | | | | **~6,600** |

### Total Estimated: ~23,000 credits/day (Pro plan provides ~61,000/day — comfortable headroom)

---

## 4-Phase Migration Plan

### Phase 1: Server-Side Historical Data (Lowest Risk)

**Target:** `market-data.ts` → `getMarketData()`
**Effort:** 1-2 days

**Steps:**
1. Add Twelve Data as the primary provider in the existing fallback chain
2. Map Yahoo interval/range params to Twelve Data interval/outputsize
3. Transform Twelve Data response to match existing Yahoo-compatible format (so all consumers work unchanged)
4. Keep Yahoo as first fallback, Fidelity as second fallback
5. Keep CBOE handler unchanged for put/call ratios
6. Add API key to Firebase environment config

### Phase 2: Server-Side Quotes + Fundamentals

**Target:** `market-data.ts` → `getQuotes()`, `riskguard-agent.ts` → `getSymbolInfo()`
**Effort:** 1-2 days

**Steps:**
1. Replace Fidelity `getQuotes()` with Twelve Data `/quote` endpoint
2. Update `getSymbolInfo()` in riskguard-agent to use Twelve Data `/quote` or `/profile`
3. Keep Fidelity as fallback for quotes

### Phase 3: Client-Side Migration (Dart)

**Target:** `yahoo_service.dart`, `fidelity_service.dart`
**Effort:** 3-5 days

**Steps:**
1. Create `twelve_data_service.dart` implementing the same interface
2. Migrate `getHistoricals()`, `getMarketIndexHistoricals()` → `/time_series`
3. Migrate `getQuote()`, `getQuotesByIds()` → `/quote`
4. Migrate `search()` → `/symbol_search`
5. Migrate `getAssetProfile()` → `/profile`
6. Migrate `getInsiderTransactions()` → `/insider_transactions`
7. Migrate `getInstitutionalOwnership()` → `/statistics` (summary only) or keep Yahoo for detailed list
8. Keep Yahoo for: ESG scores, stock screeners, options chains
9. Update `fidelity_service.dart` to use new Twelve Data service instead of Yahoo as fallback

### Phase 4: Cleanup + Optimization

**Effort:** 1-2 days

**Steps:**
1. Remove Yahoo crumb/cookie logic from server-side code (if fully migrated)
2. Remove Fidelity historical chart fallback (if Twelve Data is stable)
3. Add credit usage monitoring/alerting
4. Consider WebSocket for real-time features (custom alerts, intraday trading)
5. Evaluate if Yahoo can be fully removed or if it stays for: options chains, ESG, screeners

---

## Endpoints That Must Stay on Yahoo (or Other Provider)

| Feature | Reason | Recommendation |
|---------|--------|----------------|
| Options Chains | Twelve Data has no options API | Keep Yahoo (server-side) or switch to Tradier |
| ESG Scores | Twelve Data only covers mutual funds | Keep Yahoo |
| Stock Screeners | Twelve Data has no screener API | Keep Yahoo or build custom |
| Institutional Holders (detailed) | 1500 credits/symbol on Ultra plan | Use `/statistics` for summary, keep Yahoo for detail |

---

## Key Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Twelve Data rate limits | Cron jobs fail | Existing Firestore cache layer absorbs most load; keep Yahoo/Fidelity as fallbacks |
| Credit budget exceeded | API calls rejected | Monitor usage; upgrade plan if needed; optimize with `/price` instead of `/quote` where possible |
| Options chain gap | Options flow feature breaks | Keep Yahoo for options or add Tradier as dedicated options provider |
| Response format differences | Data parsing errors | Transform Twelve Data responses to Yahoo-compatible format in adapter layer |
| Commercial licensing issues | App store rejection | Confirm with Twelve Data sales before launch; Pro plan should cover US equities |
