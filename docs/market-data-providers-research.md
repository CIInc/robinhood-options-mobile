# Market Data Providers Research

Research into available market data providers for options and futures data, evaluated for use in a commercial iOS/Android app distributed via the App Store and Google Play. Key concerns: options chain data, futures quotes, real-time vs. delayed, redistribution licensing, and monthly cost.

> **Current state:** The app uses Yahoo Finance's unofficial API (`query2.finance.yahoo.com`) for options flow data and Robinhood/Schwab brokerage APIs for live positions and orders. Yahoo Finance is a **compliance risk** for commercial app distribution (see below).

---

## ⚠️ Yahoo Finance — Compliance Risk (Current Usage)

Yahoo Finance's unofficial API (`query2.finance.yahoo.com`) is used today for:
- Options chain data → `options_flow_widget.dart`, `options_flow_store.dart`
- Asset profile (sector/industry) → `options_flow_store.dart`

**The problem:** Yahoo Finance shut down its official API in 2017. The `query2.finance.yahoo.com` endpoint is an internal/unofficial API with no public terms of service permitting commercial use. Yahoo's ToS explicitly prohibits scraping or redistributing data for commercial purposes. Distributing an app on the App Store that calls this endpoint is a ToS violation and a legal/compliance risk.

**Recommendation:** Replace Yahoo Finance options data before App Store submission. See provider options below.

---

## ⚠️ OPRA Licensing — Critical Cost Factor for Options Apps

Any app that displays US options data (real-time OR 15-minute delayed) to end users must comply with OPRA (Options Price Reporting Authority) licensing. This is separate from your data provider subscription.

**Key OPRA costs ([source: MarketData.app](https://www.marketdata.app/education/options/opra-fees/)):**
- **Redistributor fee:** $1,500/month flat — required for ANY app showing OPRA data externally, even delayed data
- **Per-user display fees (real-time only):**
  - Non-professional: starts at $1.25/month per user (volume discounts available)
  - Professional: $31.50/month per user
- **Non-display use fee:** $2,000/month per category — applies if you use OPRA data for backend calculations (e.g., computing Greeks for users)
- **Delayed/historical data:** No per-user fees, but the $1,500/month redistributor fee still applies

**OPRA compliance requirements:**
- Every user must sign an OPRA Subscriber Agreement
- Users must be classified as professional or non-professional
- Monthly reporting to OPRA required
- Simultaneous login controls required for real-time data
- Records must be retained for 3+ years

**Cost-saving strategies:**
- Launch with 15-minute delayed data to avoid per-user fees and non-display fees
- Use historical data (1+ trading day old) during development — completely exempt from OPRA
- Some providers (Polygon.io, Databento) bundle OPRA licensing into their plan price, handling the vendor agreement on your behalf

**Important:** Some providers handle OPRA licensing for you (Polygon.io Business, Databento Standard+), while others require you to obtain your own OPRA Vendor Agreement. This is a significant operational difference.

---

## Provider Comparison Table

| Provider | Options Chains | Futures Quotes | Real-Time | Delayed | App Store Redistribution | Est. Monthly Cost | Pricing Verified |
|----------|---------------|----------------|-----------|---------|--------------------------|-------------------|-----------------|
| **Yahoo Finance** | ✅ | ❌ | ✅ (unofficial) | ✅ | ❌ ToS violation | $0 | N/A |
| **Polygon.io** | ✅ OPRA | ✅ CME/CBOT/NYMEX | ✅ | ✅ | ✅ Business plan | $1,999/mo (startup: ~$1,000/mo) | ✅ polygon.io/business |
| **Alpaca Markets** | ✅ OPRA | ⚠️ Limited | ✅ (paid) | ✅ indicative (free) | ✅ Broker API only | $1,000–$2,000/mo | ✅ alpaca.markets/docs |
| **Intrinio** | ✅ | ❌ | ✅ (Gold) | ✅ (Silver) | ✅ Silver+ | ~$150–$1,600/mo | ⚠️ G2 listing (contact for exact) |
| **Tradier** | ✅ | ❌ | ✅ (account holders) | ✅ (sandbox) | ⚠️ Fintech partner agreement | Contact sales | ✅ tradier.com |
| **MarketData.app** | ✅ | ❌ | ✅ | ✅ | ❌ Explicitly prohibited | $0–$75/mo (personal only) | ✅ marketdata.app/terms |
| **Databento** | ✅ OPRA | ✅ CME | ✅ | ❌ | ✅ Standard+ | $199/mo OPRA + $179/mo CME | ✅ databento.com/blog |
| **Twelve Data** | ❌ | ⚠️ Commodities only | ✅ (Pro+) | ✅ | ✅ Pro plan (equities only) | $229/mo | ✅ twelvedata.com/pricing |
| **Tastytrade API** | ✅ | ✅ | ✅ | N/A | ⚠️ Partner program only | Contact sales | ✅ tastytrade.com |
| **TradeStation API** | ✅ | ✅ | ✅ | N/A | ✅ with API agreement | Contact sales | ✅ tradestation.com |

---

## Detailed Provider Profiles

### 1. Polygon.io

**Website:** [polygon.io](https://polygon.io)

**Coverage:**
- Options: Full OPRA feed — real-time quotes, greeks (delta, gamma, theta, vega, IV), historical, open interest, volume
- Futures: CME, CBOT, NYMEX, COMEX — real-time and historical

**Pricing (verified from [polygon.io/business](https://www.polygon.io/business)):**

| Plan | Price | Use Case | Redistribution |
|------|-------|----------|----------------|
| Individual (personal) | $29–$79/mo | Personal projects, no redistribution | ❌ Personal use only |
| Business | **$1,999/mo** | Commercial apps, redistribution | ✅ Includes OPRA, no exchange fees |
| Enterprise | Custom | Large-scale commercial | ✅ Custom SLAs, dedicated support |
| Startup discount | Up to 50% off year 1 | Startups | ✅ ~$1,000/mo effective |

**Business plan includes:** Unlimited API calls, 20+ years historical data, no exchange fees or approvals needed, real-time streaming, snapshots, trades, quotes, financials & ratios.

**Exchange feed expansions (additional):**
- Cboe EDGX: +$1,999/mo
- Nasdaq Basic: +$1,999/mo
- Full Market (all US exchanges): contact sales

**Redistribution:** Business plan handles OPRA vendor agreement on your behalf. No separate exchange approvals needed.

**Options API endpoints:**
- `GET /v3/snapshot/options/{underlyingAsset}` — full chain snapshot
- `GET /v2/last/trade/{optionsTicker}` — last trade
- `GET /v3/trades/{optionsTicker}` — trade history
- `GET /v2/aggs/ticker/{optionsTicker}/range/{multiplier}/{timespan}/{from}/{to}` — OHLCV bars
- `GET /v3/snapshot/options/{underlyingAsset}/{optionsTicker}` — single contract snapshot with greeks

**Futures API endpoints:**
- `GET /v3/snapshot/futures` — futures snapshots
- `GET /v2/aggs/ticker/{futuresTicker}/range/{multiplier}/{timespan}/{from}/{to}` — OHLCV bars

**Fit for this app:**
- ✅ Best all-in-one replacement for Yahoo Finance options + futures
- ✅ OPRA licensing handled by Polygon — no separate vendor agreement needed
- ✅ Startup discount available (up to 50% off year 1)
- ❌ $1,999/mo is expensive for an early-stage app
- ⚠️ Individual plans ($29–$79) do NOT allow redistribution

---

### 2. Alpaca Markets

**Website:** [alpaca.markets](https://alpaca.markets)

**Coverage:**
- Options: Full OPRA feed on paid plans; indicative (non-OPRA) feed on free tier
- Futures: Not prominently documented for market data API

**Pricing (verified from [alpaca.markets/docs/market-data](https://alpaca.markets/docs/market-data)):**

**Trading API (individual use):**

| Plan | Price | Stocks | Options | Redistribution |
|------|-------|--------|---------|----------------|
| Basic | Free | IEX only | Indicative feed only | ❌ |
| Algo Trader Plus | $99/mo | All US exchanges | Full OPRA | ❌ Personal use |

**Broker API (commercial redistribution):**

| Plan | Price | Options | Notes |
|------|-------|---------|-------|
| Standard | Included | +$1,000/mo add-on | IEX or 15-min delayed SIP |
| StandardPlus3000 | $500/mo | +$1,000/mo add-on | IEX or 15-min delayed SIP |
| StandardPlus5000 | $1,000/mo | Included | IEX or 15-min delayed SIP |
| StandardPlus10000 | $2,000/mo | Included | IEX or 15-min delayed SIP |

**Redistribution:** Requires Broker API partnership. Standard plans provide IEX or 15-min delayed SIP data. Custom pricing available for full real-time SIP.

**Options API endpoints:**
- `GET /v2/options/snapshots/{symbol}` — option chain snapshot
- `GET /v2/options/trades/{symbol}` — options trades
- `GET /v2/options/quotes/{symbol}` — options quotes
- `GET /v2/options/bars/{symbol}` — OHLCV bars

**Fit for this app:**
- ✅ Good options coverage with OPRA feed
- ❌ Futures data not well-documented
- ⚠️ Commercial redistribution requires Broker API ($1,000–$2,000/mo with options)
- ⚠️ Standard Broker plans only provide IEX or delayed SIP, not full real-time

---

### 3. Intrinio

**Website:** [intrinio.com](https://intrinio.com)

**Coverage:**
- Options: US equity options — EOD (Bronze), 15-min delayed (Silver), real-time (Gold)
- Futures: Not prominently featured

**Pricing (from [G2 listing](https://www.g2.com/products/intrinio-financial-data-api/pricing) — contact Intrinio for exact quotes):**

| Tier | Approx. Price | Options | Display Allowed | Exchange Fees |
|------|--------------|---------|-----------------|---------------|
| Bronze | ~$150/mo | EOD only | ✅ | None |
| Silver | ~$400/mo | 15-min delayed | ✅ | None |
| Gold | ~$1,600/mo | Real-time | ✅ | Required (passed through) |

**Redistribution:** Display allowed on Silver and Gold tiers. Silver tier avoids exchange fees by using 15-min delayed data. Gold tier requires OPRA exchange fee agreements (passed through to customer).

**Options API endpoints:**
- `GET /options/chain/{symbol}/{expiration}` — option chain
- `GET /options/prices/{identifier}` — option prices
- `GET /options/greeks/{identifier}` — greeks
- `GET /options/unusual_activity/{symbol}` — unusual activity / flow

**Fit for this app:**
- ✅ Has unusual activity / options flow endpoint (directly relevant to `options_flow_widget.dart`)
- ✅ Silver tier ($400/mo) with 15-min delay avoids exchange fees
- ❌ No futures data
- ⚠️ Real-time Gold tier is expensive ($1,600/mo) and requires separate OPRA agreements
- ⚠️ Pricing is approximate — must contact sales for exact quotes

---

### 4. Tradier

**Website:** [tradier.com](https://tradier.com)

**Coverage:**
- Options: Full US options chains, real-time quotes, greeks, historical
- Futures: Available via Tradier Futures (separate entity)

**Pricing (verified from [tradier.com](https://tradier.com)):**

| Plan | Price | Notes |
|------|-------|-------|
| Developer sandbox | Free | Delayed data, paper trading only |
| Standard (brokerage) | Free | Commission-free stocks; $0.35/contract options |
| Pro | $10/mo | Unlimited commission-free stock + options trading |
| Pro Plus | $35/mo | Advanced features, commission-free |
| Fintech/Partner | Contact sales | Third-party app redistribution |

**API access:** Free for all Tradier brokerage account holders. Handles 2.6 billion+ API calls per month. REST + streaming WebSocket.

**Redistribution:** Tradier actively supports fintech integrations ([tradier.com/businesses/fintechs](https://production.tradier.com/businesses/fintechs)). For third-party app redistribution (displaying data to users who are not Tradier account holders), a fintech/partner agreement is required. No public pricing for this tier.

**Options API endpoints:**
- `GET /v1/markets/options/chains?symbol={symbol}&expiration={date}` — option chain
- `GET /v1/markets/options/expirations?symbol={symbol}` — expiration dates
- `GET /v1/markets/options/strikes?symbol={symbol}&expiration={date}` — strikes
- `GET /v1/markets/quotes?symbols={optionSymbols}` — real-time quotes
- `GET /v1/markets/history?symbol={optionSymbol}` — historical prices

**Fit for this app:**
- ✅ Strong options coverage, well-documented API, battle-tested infrastructure
- ✅ Could serve as a third brokerage integration (alongside Robinhood and Schwab)
- ❌ Redistribution in a third-party app requires fintech partner agreement (contact sales)
- ⚠️ OPRA licensing implications unclear — need to confirm if Tradier handles this for partners
- ⚠️ No public pricing for fintech/partner tier

---

### 5. MarketData.app

**Website:** [marketdata.app](https://marketdata.app)

**Coverage:**
- Options: Full US options chains, real-time + historical, greeks
- Futures: Not available

**Pricing (verified from [marketdata.app/pricing](https://marketdata.app/pricing)):**

| Plan | Monthly (annual) | Monthly (monthly) | API Credits/Day |
|------|-----------------|-------------------|-----------------|
| Free Forever | $0 | $0 | Limited |
| Starter | $12/mo | $30/mo | Moderate |
| Trader | $30/mo | $75/mo | 100,000 |
| Quant / Commercial | Contact | Contact | Unlimited |

**⚠️ CRITICAL — NOT ELIGIBLE FOR APP STORE DISTRIBUTION:**

MarketData.app's [Professional Use Addendum](https://www.marketdata.app/terms/professional-use/) explicitly states:

> "The Professional Use license does not permit external redistribution of the Data under any circumstances. The Data may not be made available on public-facing websites, applications, or platforms accessible to clients, customers, or the general public."

This means **no self-serve MarketData.app plan can be used in an App Store app**. Their self-serve plans are for personal/internal use only. A custom Commercial plan would need to be negotiated directly.

Additionally, MarketData.app's self-serve plans do not include OPRA redistribution rights. You would need your own OPRA Vendor Agreement ($1,500/mo minimum) on top of any data subscription.

**Fit for this app:**
- ❌ Cannot be used for App Store distribution on any self-serve plan
- ❌ Would require custom Commercial agreement + separate OPRA vendor agreement
- ✅ Good for personal development/prototyping during development phase

---

### 6. Databento

**Website:** [databento.com](https://databento.com)

**Coverage:**
- Options: Full OPRA feed — real-time, historical, greeks
- Futures: CME, CBOT, NYMEX, COMEX — real-time and historical

**Pricing (verified from [databento.com/blog](https://databento.com/blog/introducing-new-opra-pricing-plans)):**

| Plan | Price | Coverage | Notes |
|------|-------|----------|-------|
| OPRA Standard | **$199/mo** | Live OPRA options + free historical | Unlimited access |
| CME Standard | **$179/mo** | Live CME futures + free historical | Unlimited access |
| OPRA + CME combined | **$378/mo** | Both options and futures | Two separate subscriptions |
| Plus / Unlimited | Enterprise | Enhanced features | Contact sales |
| Historical only | Pay-as-you-go ($/GB) | Historical data | No monthly minimum |

**Recent changes (2025):**
- Usage-based pricing for live data discontinued as of June 2025
- Standard plans now include unlimited live data access + free historical data
- Existing users grandfathered at old rates

**Redistribution:** Allowed on Standard and higher plans. Databento is designed for professional/commercial use. Handles exchange licensing (OPRA, CME) on behalf of customers.

**Key differentiator:** Databento uses a normalized data format (DBN) and supports both REST and streaming (WebSocket).

**Options API endpoints:**
- `GET /v0/timeseries.get_range` — historical options data
- `GET /v0/metadata.list_datasets` — available datasets
- WebSocket streaming for real-time OPRA feed

**Futures API endpoints:**
- Same REST/WebSocket API, different dataset (e.g., `GLBX.MDP3` for CME Globex)

**Fit for this app:**
- ✅ Most affordable option for both options AND futures with redistribution rights
- ✅ OPRA + CME licensing handled by Databento
- ✅ $378/mo combined is significantly cheaper than Polygon.io Business ($1,999/mo)
- ⚠️ More complex integration (DBN format, streaming-first design)
- ⚠️ Newer provider — less community resources than Polygon.io

---

### 7. Tastytrade API

**Website:** [tastytrade.com/api](https://tastytrade.com/api/)

**Coverage:**
- Options: Full options chains, real-time quotes, greeks, multi-leg strategies
- Futures: Full futures support (CME products)
- Crypto: Supported

**Pricing:**
- Free for tastytrade account holders (read + write access)
- Partner program for third-party app integration (contact sales)

**Redistribution:** Partner program required for third-party app display. The partner program provides "seamless onboarding, shared support channels, and access to tech and engineer teams."

**API capabilities:**
- Read: account balances, positions, open orders, transaction history, real-time quotes, option chains, market metrics (equities, options, futures, crypto), order chains
- Write: submit/modify/cancel orders (equity, crypto, options, futures), multi-leg option strategies, watchlist sync
- Sandbox environment available for testing

**Fit for this app:**
- ✅ Covers both options AND futures in one API
- ✅ Sandbox for development
- ⚠️ Requires tastytrade account for users OR partner program for third-party display
- ⚠️ Not suitable as a pure market data provider — tied to tastytrade brokerage
- ✅ Best considered as a third brokerage integration (alongside Robinhood and Schwab)

---

### 8. TradeStation API

**Website:** [tradestation.com/platforms-and-tools/trading-api](https://www.tradestation.com/platforms-and-tools/trading-api/)

**Coverage:**
- Options: Full options chains, real-time quotes, market depth
- Futures: Full futures support
- Equities: Full coverage

**Pricing:**
- Free API access for TradeStation account holders
- No subscription cost for API access
- Partner/institutional program for third-party apps (contact institutional sales)

**Redistribution:** TradeStation actively supports third-party platform integrations (TradingView and Option Alpha are cited examples). Redistribution in a third-party app requires an API agreement. Contact `institutionalsales@tradestation.com`.

**API capabilities:**
- Streaming endpoints: options chains, market depth, quotes, orders, positions
- Advanced order types: bracket, OCO, OSO, multi-leg options
- Direct market access

**Fit for this app:**
- ✅ Covers both options AND futures
- ✅ Proven third-party integration track record
- ⚠️ Requires TradeStation account for users OR institutional agreement
- ⚠️ Not a standalone market data API — tied to TradeStation brokerage
- ✅ Could be a third brokerage integration

---

### 9. Twelve Data (Current Partial Usage)

**Website:** [twelvedata.com](https://twelvedata.com)

**Coverage:**
- Options: ❌ No options chain API
- Futures: ⚠️ Commodities (gold, oil, etc.) via `/commodities` — NOT CME futures contracts
- Equities: ✅ Full coverage (historical, real-time, fundamentals)

**Pricing (verified from [twelvedata.com/pricing](https://twelvedata.com/pricing)):**

| Plan | Price | Credits/min | Commercial Use | Notes |
|------|-------|-------------|---------------|-------|
| Basic | Free | 8 | ❌ Personal only | Dev/testing |
| Grow | $79/mo | 55+ | ❌ Personal only | |
| Pro | **$229/mo** | 610+ | ✅ US equities | Recommended for production |
| Ultra | $999/mo | 2,584+ | ✅ | High volume |
| Enterprise | From $1,999/mo | 10,000+ | ✅ | Full scale |

**Redistribution:** Pro plan and above allow commercial display of US equities data. Raw data feed redistribution requires a separate agreement. Startup and student discounts available.

**Fit for this app:**
- ✅ Already in use / migration planned (see `docs/twelve-data-migration.md`)
- ❌ Cannot replace Yahoo Finance for options chains
- ⚠️ Commodities data is not the same as CME futures contracts used in the app
- ✅ Good for equities, historicals, quotes, fundamentals

---

## App Store Eligibility Summary

| Provider | Self-Serve App Store OK? | What's Required | OPRA Handled? |
|----------|--------------------------|-----------------|---------------|
| **Polygon.io** | ✅ Business plan | $1,999/mo (or ~$1,000 startup) | ✅ Yes, bundled |
| **Alpaca Markets** | ✅ Broker API | $1,000–$2,000/mo + partner agreement | ⚠️ Unclear |
| **Intrinio** | ✅ Silver+ | ~$400–$1,600/mo + contact sales | ⚠️ Gold requires separate OPRA |
| **Tradier** | ⚠️ Partner agreement | Contact sales | ⚠️ Unclear |
| **MarketData.app** | ❌ No | Explicitly prohibited on self-serve plans | ❌ No |
| **Databento** | ✅ Standard plan | $199/mo OPRA + $179/mo CME | ✅ Yes, bundled |
| **Twelve Data** | ✅ Pro plan (equities only) | $229/mo — no options data | N/A (no options) |
| **Tastytrade** | ⚠️ Partner program | Contact sales | ⚠️ Unclear |
| **TradeStation** | ⚠️ Institutional agreement | Contact sales | ⚠️ Unclear |
| **Yahoo Finance** | ❌ No | ToS violation | N/A |

---

## Recommendations by Use Case

### Replace Yahoo Finance for Options Flow Analysis

**Best options (ranked by cost-effectiveness for App Store distribution):**

1. **Databento OPRA Standard ($199/mo)** — most affordable option with confirmed redistribution rights and OPRA licensing handled. Covers full OPRA feed.
2. **Intrinio Silver (~$400/mo)** — has dedicated unusual activity endpoint relevant to options flow. 15-min delayed avoids per-user OPRA fees. Contact for exact pricing.
3. **Polygon.io Business ($1,999/mo, or ~$1,000 startup)** — best all-in-one solution but expensive. Includes everything with no exchange fee headaches.
4. **Tradier (fintech partner, contact sales)** — strong API, but redistribution terms and pricing unknown until you contact sales.

### Replace Yahoo Finance for Options + Add Futures Data (Single Provider)

1. **Databento ($378/mo combined)** — OPRA Standard ($199) + CME Standard ($179). Most cost-effective for both. More complex integration.
2. **Polygon.io Business ($1,999/mo)** — covers both in one plan. Simpler integration, higher cost.

### Add as Third Brokerage Integration (Trading + Data)

1. **Tastytrade** — options + futures + crypto, sandbox available, partner program
2. **TradeStation** — options + futures, proven third-party integrations, institutional program

---

## Recommended Migration Path

Given the app's current state (Robinhood + Schwab integrations, Yahoo Finance for options flow, Twelve Data migration in progress):

### Phase 1 — Immediate (Pre-App Store Submission)
Replace Yahoo Finance options chain usage with a compliant provider:
- **Option A (most affordable):** Databento OPRA Standard ($199/mo) — integrate their API to replace `yahoo_service.dart` `getOptionChain()` and `options_flow_store.dart`
- **Option B (best all-in-one):** Polygon.io Business ($1,999/mo, or ~$1,000/mo with startup discount) — replaces both options chains and futures market data

### Phase 2 — Options Flow Enhancement
The `options_flow_widget.dart` currently uses Yahoo for unusual activity detection. Providers with dedicated flow/unusual activity endpoints:
- **Intrinio** — `/options/unusual_activity/{symbol}` endpoint
- **Databento / Polygon.io** — high-volume/OI filtering via snapshot API

### Phase 3 — Futures Data (If Expanding Beyond Robinhood)
Currently futures data comes exclusively from Robinhood's private API. If adding Schwab futures or a standalone futures data source:
- **Databento CME Standard ($179/mo)** — add to existing OPRA subscription
- **Polygon.io Business** — already included if using their plan

---

## Summary Cost Comparison (Verified Pricing)

| Scenario | Provider | Est. Monthly Cost |
|----------|----------|-------------------|
| Options only (delayed, App Store OK) | Databento OPRA Standard | **$199/mo** |
| Options only (delayed, display allowed) | Intrinio Silver | **~$400/mo** |
| Options + Futures (App Store OK) | Databento OPRA + CME Standard | **$378/mo** |
| Options + Futures (all-in-one) | Polygon.io Business | **$1,999/mo** |
| Options + Futures (startup discount) | Polygon.io Business (year 1) | **~$1,000/mo** |
| Equities/historicals (current migration) | Twelve Data Pro | **$229/mo** |
| **Realistic combined (options + equities)** | Databento OPRA + Twelve Data Pro | **~$428/mo** |
| **Realistic combined (options + futures + equities)** | Databento OPRA + CME + Twelve Data Pro | **~$607/mo** |
| **Premium all-in-one (options + futures + equities)** | Polygon.io Business + Twelve Data Pro | **~$2,228/mo** |

---

## Sources

- [Polygon.io Business Pricing](https://www.polygon.io/business) — verified $1,999/mo Business plan
- [Alpaca Markets Data Docs](https://alpaca.markets/docs/market-data) — verified Trading API and Broker API pricing
- [Intrinio Pricing (G2)](https://www.g2.com/products/intrinio-financial-data-api/pricing) — approximate $150–$1,600/mo range
- [Tradier Developer API](https://trade.tradier.com/developer-api/) — verified Pro $10/mo, Pro Plus $35/mo
- [Tradier Fintechs](https://production.tradier.com/businesses/fintechs) — fintech partner program
- [MarketData.app Professional Use Addendum](https://www.marketdata.app/terms/professional-use/) — verified redistribution prohibition
- [MarketData.app OPRA Fees Guide](https://www.marketdata.app/education/options/opra-fees/) — OPRA licensing costs and requirements
- [Databento OPRA Pricing Blog](https://databento.com/blog/introducing-new-opra-pricing-plans) — verified $199/mo Standard plan
- [Databento CME Pricing Blog](https://databento.com/blog/introducing-new-cme-pricing-plans) — verified $179/mo Standard plan
- [Tastytrade API](https://tastytrade.com/api/) — partner program details
- [TradeStation Trading API](https://www.tradestation.com/platforms-and-tools/trading-api/) — institutional program
- [Twelve Data Pricing](https://twelvedata.com/pricing) — verified plan pricing
- [CME licensing changes 2025 — risk.net](https://www.risk.net/markets/7963143/cme-rankles-market-data-users-with-licensing-changes)
- [docs/twelve-data-migration.md](twelve-data-migration.md) — existing migration plan