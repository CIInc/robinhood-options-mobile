# Databento vs Twelve Data: Can Databento Replace Twelve Data?

Analysis of whether Databento can serve as an alternative (or replacement) for Twelve Data, based on the functional groups defined in `docs/twelve-data-migration.md`.

---

## Executive Summary

Databento is a strong alternative for **market data** (historical OHLCV, real-time quotes, options chains) but **cannot replace Twelve Data for fundamental data** (company profiles, insider transactions, institutional ownership, ESG scores, symbol search). The two providers serve different niches: Databento excels at low-latency, exchange-level tick/bar data; Twelve Data excels at higher-level financial data APIs with fundamentals.

**Verdict:** Databento is a complement to Twelve Data, not a full replacement. However, Databento can replace Twelve Data for specific high-value use cases (options chains, futures data, real-time streaming) while Twelve Data remains necessary for fundamentals.

---

## Functional Group Comparison

### 1. Historical OHLCV Data

| Aspect | Twelve Data | Databento |
|--------|-------------|-----------|
| Endpoint | `GET /time_series` | `GET /v0/timeseries.get_range` (schema: `ohlcv-1d`, `ohlcv-1h`, `ohlcv-1m`) |
| Coverage | Global stocks, ETFs, forex, crypto, commodities | US equities only (20,000+ stocks/ETFs across 15 exchanges) |
| History depth | 30+ years | Up to 7 years (since 2018 for equities) |
| Intervals | 1min to 1month | 1sec, 1min, 1hour, 1day |
| Credit cost | 1 credit/symbol | Usage-based ($/GB) or included in subscription |
| Commercial use | Pro plan ($229/mo) | Standard plan ($199/mo for equities) |

**Can Databento replace Twelve Data?** Partially.
- ✅ US equities OHLCV — yes, with better granularity (tick-level available)
- ❌ Global stocks — no, Databento only covers US exchanges
- ❌ Forex — no
- ❌ Crypto — no
- ❌ Commodities — no (Databento has CME futures, but not the same as Twelve Data's commodity indices)
- ⚠️ History depth — Databento has ~7 years vs Twelve Data's 30+ years

**Verdict:** ⚠️ Partial replacement for US equities only. Twelve Data still needed for global coverage and deep history.

---

### 2. Real-Time Quotes

| Aspect | Twelve Data | Databento |
|--------|-------------|-----------|
| REST endpoint | `GET /quote` or `GET /price` | `GET /v0/timeseries.get_range` with recent range |
| WebSocket | `wss://ws.twelvedata.com/v1/quotes/price` | Native WebSocket streaming API |
| Latency | Not specified | 590 μs median latency |
| Coverage | Global stocks, forex, crypto | US equities, options, futures |
| Credit cost | 1 credit/symbol (REST), 1 WS credit/symbol | Included in subscription |

**Can Databento replace Twelve Data?** Partially.
- ✅ US equities real-time — yes, with significantly lower latency
- ✅ Options real-time — yes (OPRA feed, $199/mo)
- ✅ Futures real-time — yes (CME feed, $179/mo)
- ❌ Forex — no
- ❌ Crypto — no
- ❌ Global stocks — no

**Verdict:** ⚠️ Superior for US market data, but cannot cover forex/crypto/global.

---

### 3. Options Chains ⭐ KEY ADVANTAGE

| Aspect | Twelve Data | Databento |
|--------|-------------|-----------|
| Options chain | ❌ NOT AVAILABLE | ✅ Full OPRA feed |
| Greeks | ❌ | ✅ (via instrument definitions) |
| Real-time quotes | ❌ | ✅ |
| Historical | ❌ | ✅ (since 2019) |
| Unusual activity | ❌ | ⚠️ Can be derived from volume/OI data |
| Cost | N/A | $199/mo (OPRA Standard) |

**Can Databento replace Twelve Data?** N/A — Twelve Data doesn't have options.

**Verdict:** ✅ Databento fills the biggest gap in Twelve Data's coverage. This is the primary reason to add Databento.

---

### 4. Symbol Search

| Aspect | Twelve Data | Databento |
|--------|-------------|-----------|
| Endpoint | `GET /symbol_search?symbol={query}` | `GET /v0/metadata.list_publishers` + symbology API |
| Fuzzy search | ✅ | ❌ No fuzzy text search |
| Returns | symbol, name, exchange, country, type | instrument_id, raw_symbol, dataset |
| Coverage | Global | US only |

**Can Databento replace Twelve Data?** No.
- ❌ Databento's symbology API is designed for instrument ID resolution, not user-facing search
- ❌ No fuzzy/text search capability
- ❌ US only

**Verdict:** ❌ Twelve Data (or another provider) needed for symbol search.

---

### 5. Company Profile / Fundamentals

| Aspect | Twelve Data | Databento |
|--------|-------------|-----------|
| Company profile | `GET /profile` — name, sector, industry, CEO, description | ❌ NOT AVAILABLE |
| Statistics | `GET /statistics` — market cap, PE, EPS, beta, 52-week | ❌ NOT AVAILABLE |
| Credit cost | 10 credits/symbol | N/A |

**Can Databento replace Twelve Data?** No.
- ❌ Databento is a market data provider, not a fundamentals provider
- ❌ No company profiles, financial ratios, or fundamental metrics

**Verdict:** ❌ Twelve Data (or another fundamentals provider) required.

---

### 6. Stock Screeners

| Aspect | Twelve Data | Databento |
|--------|-------------|-----------|
| Screener | ❌ NOT AVAILABLE | ❌ NOT AVAILABLE |
| Alternative | Build custom with `/stocks` + `/quote` | Build custom with real-time screener (see their blog tutorial) |

**Can Databento replace Twelve Data?** Neither has a screener API.
- ✅ Databento has a blog tutorial for building a real-time stock screener using their tick data
- ⚠️ Both require custom implementation

**Verdict:** ➖ Neither provider has this. Both require custom work.

---

### 7. Insider Transactions

| Aspect | Twelve Data | Databento |
|--------|-------------|-----------|
| Endpoint | `GET /insider_transactions` | ❌ NOT AVAILABLE |
| Credit cost | 200 credits/symbol | N/A |

**Can Databento replace Twelve Data?** No.
- ❌ Databento does not provide SEC filing data or insider transaction data

**Verdict:** ❌ Twelve Data required.

---

### 8. Institutional Ownership

| Aspect | Twelve Data | Databento |
|--------|-------------|-----------|
| Endpoint | `GET /institutional_holders` | ❌ NOT AVAILABLE |
| Credit cost | 1,500 credits/symbol (Ultra plan) | N/A |

**Can Databento replace Twelve Data?** No.

**Verdict:** ❌ Twelve Data required (or keep Yahoo Finance for this).

---

### 9. ESG Scores

| Aspect | Twelve Data | Databento |
|--------|-------------|-----------|
| Endpoint | `GET /mutual_funds/world/sustainability` | ❌ NOT AVAILABLE |
| Coverage | Mutual funds only (not stocks) | N/A |

**Can Databento replace Twelve Data?** No. Neither provider has good stock ESG coverage.

**Verdict:** ❌ Neither provider covers this well.

---

### 10. Put/Call Ratios (CBOE)

| Aspect | Twelve Data | Databento |
|--------|-------------|-----------|
| Source | N/A (uses CBOE directly) | ❌ NOT AVAILABLE |

**Can Databento replace Twelve Data?** N/A — this uses CBOE's free public endpoint directly.

**Verdict:** ➖ No change needed. Keep CBOE.

---

### 11. Futures Data ⭐ KEY ADVANTAGE

| Aspect | Twelve Data | Databento |
|--------|-------------|-----------|
| Coverage | ⚠️ Commodities only (gold, oil via `/commodities`) | ✅ Full CME, CBOT, NYMEX, COMEX |
| Contracts | Generic commodity symbols | Actual futures contract IDs (ES, CL, NQ, etc.) |
| Real-time | ✅ (Pro+) | ✅ ($179/mo CME Standard) |
| Historical | ✅ | ✅ (since 2010 for CME) |
| Order book | ❌ | ✅ Full book depth |

**Can Databento replace Twelve Data?** Yes, and it's significantly better.
- ✅ Actual CME futures contracts vs generic commodity prices
- ✅ Full order book depth
- ✅ 15+ years of history

**Verdict:** ✅ Databento is far superior for futures data.

---

### 12. Corporate Actions / Reference Data

| Aspect | Twelve Data | Databento |
|--------|-------------|-----------|
| Corporate actions | ❌ | ✅ 215 exchanges, 310,000+ securities, 60+ event types |
| Security master | ❌ | ✅ Security identifiers and mappings |

**Can Databento replace Twelve Data?** Yes, for corporate actions specifically.

**Verdict:** ✅ Databento has corporate actions that Twelve Data lacks.

---

## Coverage Gap Summary

| Functional Group | Twelve Data | Databento | Winner | Notes |
|-----------------|-------------|-----------|--------|-------|
| Historical OHLCV (US) | ✅ | ✅ | Databento | Lower latency, tick-level, but shorter history |
| Historical OHLCV (Global) | ✅ | ❌ | Twelve Data | Databento is US-only |
| Real-Time Quotes (US) | ✅ | ✅ | Databento | 590 μs median latency |
| Real-Time Quotes (Global/Forex/Crypto) | ✅ | ❌ | Twelve Data | Databento is US-only |
| Options Chains | ❌ | ✅ | **Databento** | Twelve Data's biggest gap |
| Futures (CME) | ⚠️ Commodities | ✅ | **Databento** | Actual contracts vs generic |
| Symbol Search | ✅ | ❌ | Twelve Data | Databento has no text search |
| Company Profile | ✅ | ❌ | Twelve Data | Fundamentals not in Databento |
| Statistics / Ratios | ✅ | ❌ | Twelve Data | |
| Insider Transactions | ✅ | ❌ | Twelve Data | |
| Institutional Ownership | ✅ | ❌ | Twelve Data | |
| ESG Scores | ⚠️ Mutual funds only | ❌ | Neither | |
| Stock Screeners | ❌ | ❌ | Neither | |
| Corporate Actions | ❌ | ✅ | Databento | |
| WebSocket Streaming | ✅ | ✅ | Databento | Native, lower latency |

---

## Pricing Comparison

| Scenario | Twelve Data | Databento | Savings |
|----------|-------------|-----------|---------|
| US equities (historical + real-time) | $229/mo (Pro) | $199/mo (Equities Standard) | $30/mo |
| Options chains | ❌ Not available | $199/mo (OPRA Standard) | N/A |
| Futures (CME) | ⚠️ Commodities only | $179/mo (CME Standard) | N/A |
| All three combined | $229/mo (no options/futures) | $577/mo (Equities + OPRA + CME) | N/A |
| Fundamentals + search + insider | ✅ Included in Pro | ❌ Not available | N/A |

---

## Pros and Cons of Databento as Alternative

### Pros

1. **Fills Twelve Data's biggest gaps** — options chains (OPRA) and real-time CME futures are exactly what Twelve Data cannot provide
2. **OPRA licensing handled** — Databento manages the OPRA vendor agreement, eliminating the $1,500/mo redistributor fee and compliance burden
3. **CME licensing handled** — same for futures, no separate CME data license needed
4. **App Store redistribution confirmed** — Standard plans explicitly allow commercial redistribution
5. **Lower latency** — 590 μs median vs unspecified for Twelve Data; direct exchange feeds vs aggregated
6. **No exchange license fees** — US Equities Mini dataset allows real-time stock data redistribution without per-user exchange fees
7. **Tick-level granularity** — full order book depth available (L1/L2/L3), not just OHLCV bars
8. **Pay-as-you-go historical** — only pay for historical data you actually download, no monthly minimum
9. **Corporate actions** — covers 215 exchanges, 60+ event types (Twelve Data doesn't have this)
10. **Normalized data format** — single API for equities, options, and futures with consistent schema

### Cons

1. **No fundamentals data** — no company profiles, financial ratios, PE, EPS, market cap, beta, sector/industry
2. **No insider transactions** — SEC filing data not available
3. **No institutional ownership** — holder data not available
4. **No symbol search** — no user-facing fuzzy text search API
5. **No ESG data** — not available
6. **US-only coverage** — no global stocks, forex, or crypto
7. **Shorter history** — ~7 years for equities (since 2018) vs 30+ years on Twelve Data
8. **More complex integration** — DBN (Databento Binary Notation) format requires their SDK; not simple JSON REST like Twelve Data
9. **Higher combined cost** — if you need equities + options + futures, it's $577/mo vs $229/mo for Twelve Data Pro (but Twelve Data doesn't cover options/futures properly)
10. **Newer provider** — less community resources, tutorials, and third-party integrations compared to Twelve Data
11. **No simple REST quote endpoint** — getting a single stock price requires understanding datasets, schemas, and symbology (vs Twelve Data's simple `GET /price?symbol=AAPL`)

---

## Recommended Strategy: Use Both

Rather than replacing Twelve Data with Databento, use them together for complementary coverage:

| Data Need | Provider | Cost |
|-----------|----------|------|
| US equities historicals, quotes, search | Twelve Data Pro | $229/mo |
| Company profiles, fundamentals, statistics | Twelve Data Pro | (included) |
| Insider transactions | Twelve Data Pro | (included) |
| Institutional ownership (summary) | Twelve Data Pro | (included) |
| **Options chains (OPRA)** | **Databento OPRA Standard** | **$199/mo** |
| **CME Futures** | **Databento CME Standard** | **$179/mo** |
| Put/Call ratios | CBOE (free) | $0 |
| ESG scores | Keep Yahoo (server-side) or remove | $0 |
| Stock screeners | Keep Yahoo (server-side) or build custom | $0 |

**Total estimated cost: ~$607/mo**

### Alternative: Databento for Everything (Drop Twelve Data)

If you wanted to consolidate on Databento only:

| Data Need | Databento | Gap? |
|-----------|-----------|------|
| US equities historicals | ✅ Equities Standard ($199/mo) | Shorter history (7yr vs 30yr) |
| Real-time quotes | ✅ Equities Mini (included) | ✅ |
| Options chains | ✅ OPRA Standard ($199/mo) | ✅ |
| CME Futures | ✅ CME Standard ($179/mo) | ✅ |
| Symbol search | ❌ | Need alternative (build custom or keep Yahoo) |
| Company profiles | ❌ | Need alternative |
| Insider transactions | ❌ | Need alternative |
| Institutional ownership | ❌ | Need alternative |
| ESG | ❌ | Need alternative |

**Total Databento cost: ~$577/mo** (but you'd still need another provider for fundamentals, search, etc.)

This approach saves ~$30/mo over the combined strategy but creates gaps that would need to be filled by yet another provider (e.g., Financial Modeling Prep at $29/mo, or EODHD at $60/mo for fundamentals).

---

## Impact on Twelve Data Migration Plan

If Databento is adopted alongside Twelve Data, the migration plan in `docs/twelve-data-migration.md` would change as follows:

| Migration Phase | Original Plan | With Databento |
|----------------|---------------|----------------|
| Phase 1: Server-side historicals | Twelve Data `/time_series` | No change — keep Twelve Data |
| Phase 2: Server-side quotes | Twelve Data `/quote` | No change — keep Twelve Data |
| Phase 3: Client-side migration | Create `twelve_data_service.dart` | No change — keep Twelve Data |
| Phase 4: Cleanup | Remove Yahoo where possible | **Remove Yahoo for options chains → use Databento OPRA** |
| **NEW: Options chains** | Keep Yahoo (fragile) or Tradier | **Databento OPRA Standard ($199/mo)** |
| **NEW: Futures data** | Robinhood API only | **Databento CME Standard ($179/mo) for standalone futures** |

The key change: instead of keeping Yahoo Finance for options chains (as noted in the "Endpoints That Must Stay on Yahoo" section), Databento replaces Yahoo entirely for options data with a compliant, App Store-ready solution.

---

## Sources

- [Databento Stocks](https://databento.com/stocks) — US equities coverage and features
- [Databento US Equities Mini](https://databento.com/blog/databento-us-equities-mini-now-available) — no-license-fee real-time equities
- [Databento US Equities Service](https://databento.com/blog/introducing-databento-us-equities) — $199/mo Standard plan, 15 exchanges
- [Databento OPRA Pricing](https://databento.com/blog/introducing-new-opra-pricing-plans) — $199/mo Standard plan
- [Databento CME Pricing](https://databento.com/blog/introducing-new-cme-pricing-plans) — $179/mo Standard plan
- [Databento Corporate Actions](https://www.prnewswire.com/news-releases/databento-releases-corporate-actions-dataset-and-reference-data-api-302231578.html) — 215 exchanges, 60+ event types
- [Twelve Data Pricing](https://twelvedata.com/pricing) — verified plan pricing
- [docs/twelve-data-migration.md](twelve-data-migration.md) — existing migration plan