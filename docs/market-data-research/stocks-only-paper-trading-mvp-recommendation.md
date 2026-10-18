# Stocks-only paper-trading MVP: market-data recommendation

Research date: October 4, 2026. Scenario: remove options from the initial public release and focus on US stock/ETF paper trading. This document proposes release scope and procurement choices; it does not remove app features or purchase a subscription.

## Recommendation

**Evaluate Twelve Data's lowest suitable Venture business configuration first.** The project already integrates its stock quotes and historical bars, so this is likely the lowest-cost combination of subscription and implementation effort. Use a single company-managed feed, a bounded stock/ETF universe, and a simple, explicitly documented simulation model.

**Keep Intrinio Startup as the alternative**, especially if Twelve Data's required coverage, licensing or capacity makes its actual quote substantially more expensive. Intrinio's stock synthetic prices can support an educational simulation, but its broader stocks/options bundle has less value when options are out of scope.

These are evaluation recommendations, not verified all-in procurement offers. Obtain written pricing for the actual commercial mobile app, backend caching and simulation workload, then validate data quality before selecting either vendor.

The default MVP should teach portfolio management and basic order behavior. It should describe fills as estimates based on the selected feed. A simulator promising realistic spreads, intraday liquidity, or professional execution quality would require additional data and a more sophisticated engine.

## What changes when options are removed

The MVP no longer needs options contracts/chains, expirations, Greeks, IV, option OI, OPRA trade feeds, GEX, options flow, option rolling, or exercise/assignment simulation. This removes a major data-cost and engineering burden.

OPRA-related options requirements fall outside this release. Stock-data licenses still apply: paper trading and delayed prices do not automatically permit commercial display, server processing or redistribution. Twelve Data says business commercial usage is subject to exchange requirements. [Commercial usage guidance](https://support.twelvedata.com/en/articles/5332349-commercial-and-personal-usage).

Broker connections can be deferred because the MVP does not send orders to a real brokerage. Users should be able to start with a guest or authenticated paper account without creating a brokerage or separate data-provider account.

### Proposed launch scope

| Include | Defer |
| --- | --- |
| Virtual cash, account reset and guest-to-account migration | Live brokerage execution and account aggregation |
| US listed stocks and ETFs in a supported universe | Options, futures, forex and crypto |
| Buy/sell market orders; limit orders after fill validation | Stops, trailing stops, shorting and margin unless explicitly validated |
| Holdings, realized/unrealized P&L and order history | Options flow, GEX, IV analytics and roll assistants |
| Search, watchlists and daily price charts | Full-market continuous scans and tick-level strategy backtesting |
| Clear quote age, session and simulation explanation | Market-data exports, public data APIs and external AI data processing until licensed |
| Split handling and explicit dividend policy | Advanced corporate actions and institutional analytics |

This scope includes ETFs as exchange-listed securities; it does not require an ETF composition/fundamentals dataset. Use an ETF such as SPY as a benchmark if appropriate and label it accurately; an ETF return is not identical to an index return.

## Minimum data requirements

| Data | Needed for | MVP expectation |
| --- | --- | --- |
| Symbol, name, exchange, currency and active status | Search and selecting eligible instruments | USD-denominated supported stocks/ETFs; avoid unsupported symbols |
| Price and provider timestamp | Marks and estimated fills | Consistent feed type, known delay and bounded staleness |
| Daily OHLCV | Charts and basic history | Adjustment policy and enough history for chosen chart ranges |
| Splits and dividend events | Correct holdings and returns | Adjust quantities/cost basis on splits; define whether dividends are simulated |
| Market calendar and sessions | Order eligibility | Regular-hours trading first; explicit treatment of holidays and half days |
| Bid/ask and sizes | More realistic execution | Optional for educational MVP; required if marketing realistic spread-aware fills |
| Intraday bars | Intraday charts and order evaluation | Purchase only when the release actually needs them |

A chart's adjusted history and the current tradable share price serve different purposes. Split handling must update simulated positions and resting orders without applying the same adjustment twice.

## Provider comparison

Prices below are USD and exclude taxes, engineering, infrastructure and unconfirmed add-ons.

| Provider | Published pricing | Pros for this release | Cons / decision gate |
| --- | --- | --- | --- |
| **Twelve Data Venture** | Advertised from **$149/month**; selected larger configuration shows **$499/month** | Existing stock adapter; business display tier; quotes and charts through one supplier | Confirm actual configuration, coverage, usage rights and capacity; starting price is not a guaranteed launch total. [Business pricing](https://twelvedata.com/pricing-business) |
| **Intrinio Startup** | **$333/month** for six months, **$666/month** for six, **$999/month** thereafter; quarterly billing | Commercial display package, synthetic stock prices, stock history | Scheduled price ramp; synthetic values do not represent executable quotes; pays for a broader bundle. [Pricing](https://intrinio.com/pricing) |
| **MarketData.app Commercial** | **Custom**, annual commitment | Stock data and commercial redistribution option | No comparable public commercial price; request a quote. [Pricing](https://www.marketdata.app/pricing/) |
| **MarketData.app direct-device BYOK** | User Starter **$30/month** or **$144/year** | Company avoids funding that user's feed subscription | Separate signup/key creates onboarding friction; device-only processing conflicts with shared backend functionality. [BYOK architecture](https://www.marketdata.app/education/licensing/bring-your-own-key/) |
| **Alpaca personal data plans** | Free Basic; **$99/month** Algo Trader Plus | Useful technical prototype and stock API benchmark | Personal prices do not establish rights for a commercial multi-user app; obtain business terms. [Official plans](https://docs.alpaca.markets/us/docs/about-market-data-api) |
| **Massive Stocks Business** | **$2,499/month** base | Broad stock history and derived live valuations | Higher launch cost; exchange-feed expansions may be additional. [Business stocks](https://massive.com/business-stocks) |

### Twelve Data: first evaluation choice

Retaining the existing adapter reduces migration effort. The pricing page advertises a Venture floor but displays a higher selected configuration; obtain the checkout or written quote for required credits and rights. It also advertises eligible startup discounts, which should remain outside the committed budget until approved. [Business configuration and pricing](https://twelvedata.com/pricing-business).

Its standard real-time US coverage represents about **5% of total trading volume**. Coverage of listed symbols does not imply full-market consolidated quotes or volume. That can be acceptable for basic practice, but should not be described as comprehensive execution-quality data. Ask about delayed full-market access if realism becomes necessary. [US equities coverage](https://support.twelvedata.com/en/articles/9935903-us-equities-market-data).

### Intrinio: alternative if the actual Twelve Data quote disappoints

Intrinio Startup packages EquitiesEdge synthetic pricing, historical stocks and delayed Cboe One data with commercial display rights. Choose it if the pilot and licensing are a better fit at the quoted total. Synthetic values need an explicit fill model; delayed Cboe One is not full consolidated market coverage. [Package contents](https://intrinio.com/pricing).

Startup display rights do not automatically permit raw-data exports or onward APIs. External AI processing also needs the applicable contractual rights. [Licensing overview](https://help.intrinio.com/licensing-data-usage-requirements), [terms](https://data.intrinio.com/terms).

## Budget comparison

| Scenario | Subscription arithmetic | Interpretation |
| --- | --- | --- |
| Twelve Data advertised minimum | `$149 × 12 = $1,788/year` | Conditional floor; confirm the configuration supports this MVP |
| Twelve Data page's larger monthly configuration | `$499 × 12 = $5,988/year` | More expensive capacity example, not the mandatory MVP plan |
| Intrinio Startup year one | `6 × $333 + 6 × $666 = $5,994` | Average $499.50/month; quarterly payments |
| Intrinio after year one | `$999 × 12 = $11,988/year` | Budget renewal economics before choosing the introductory rate |
| Massive stock business base | `$2,499 × 12 = $29,988/year` | Published base before applicable expansions |

At the advertised Twelve Data floor, the first-year subscription difference from Intrinio is **$4,206**. At Twelve Data's $499 configuration, first-year subscription totals are nearly equal. Compare actual coverage, renewal price and engineering cost rather than introductory rates alone. All totals above are arithmetic based on the cited pricing pages, not vendor quotes.

Suggested procurement target: try to secure a suitable commercial stock feed near the advertised $149/month floor. Treat this as a negotiation/evaluation target, not a user-approved spending limit or a proven all-in budget.

## Cost-efficient architecture

Use the existing Firebase stock-data boundary with a provider adapter, subject to permitted caching and display rights. Share licensed responses across users by symbol, interval and feed entitlement. Separate the simulation ledger from market-data caches so fills and balances remain auditable when a cache expires.

Start with approximately 100–200 supported liquid stocks/ETFs as a planning assumption. Expand based on demand. Refresh visible quotes and instruments with working orders more often than inactive watchlists. Use daily bars by default, fetch incrementally, coalesce duplicate requests, and limit retries during quota errors.

Illustrative load: 200 unique symbols refreshed once per minute for a 390-minute regular session produce **78,000 symbol refreshes/day**. At five-minute refreshes, that becomes **15,600**. These are load estimates, not provider billable credits. Batch calls can reduce HTTP overhead while still charging per symbol. Size the plan for peak requests, chart loads and retries, not just daily averages.

Foreground-only order evaluation is cheaper but means resting orders may not execute while the app is closed. If background fills are part of the MVP promise, use one deduplicated server scheduler over instruments with active orders; confirm the contract covers that non-display workload. A server cache alone does not create a reliable background execution engine.

## Fill policy and implementation implications

The current [paper service](../../src/robinhood_options_mobile/lib/services/paper_service.dart) passes a stock's last-trade price into the [paper trading store](../../src/robinhood_options_mobile/lib/model/paper_trading_store.dart). The engine also supports options/futures and richer order types. A stocks-only MVP should explicitly restrict allowed asset/order types at the trading boundary, with UI gating and background-job gating; hiding options tabs alone leaves other entry paths.

The [backend stock adapter](../../src/robinhood_options_mobile/functions/src/market-data.ts) already uses Twelve Data quotes/bars. Paper-account quote fetching also has Fidelity/Yahoo dependencies. Replace or contractually validate those paths so failure does not silently switch to an unapproved feed with different freshness.

Before release:

1. Choose a single fill reference policy: fresh last-price, synthetic estimate, or delayed bid/ask. Identify it in the app.
2. Evaluate order placement, triggering, fills and P&L on the same market timeline. Persist quote time, provider, feed type and fill assumptions with fills.
3. Reject missing, zero or stale prices. The paper-service adapter currently permits an order price fallback when a quote is absent; review that path so the user's requested limit cannot become market evidence for a fill.
4. If delayed data is used, define order activation on the delayed timeline so pre-order observations cannot fill a newly submitted order. Describe performance as simulated and delayed.
5. If using bars for limit triggers, document intrabar ambiguity. A high/low crossing does not establish queue position, available size or that a real order would have filled.
6. Set regular-hours rules, pending-order cancellation behavior, cash constraints, split adjustments and dividend treatment. Defer unsupported shorting/margin semantics.
7. Disable option/futures order entry, related MCP/tool actions, premium analytics and scheduled scanners for the release scope. Preserve existing stored accounts safely; do not delete historical options positions as part of feature gating.

These are follow-up implementation tasks, not changes performed by this document.

## Purchase and release decision

Request a **stocks/ETFs-only commercial paper-simulation quote** from Twelve Data first. Specify client display, Firebase cache duration, simulated order evaluation, background fills if included, account valuation, expected unique symbols/concurrency, and any external AI or exports. Ask what exact US venues and volume the price/bar feed represents and whether splits/dividends and chosen chart resolutions are included.

Run a pilot with AAPL, SPY, QQQ, BRK.B and a supported low-liquidity symbol. Check timestamp age, missing bars, symbol mapping, market-open behavior, holidays, splits, quotas, and quote consistency between order and portfolio screens. Compare timestamp-aligned prices against an entitled reference feed. Use mocked time/quotes for meaningful fill-engine verification.

**Select Twelve Data if its verified configuration meets those needs at a lower total cost. Select Intrinio if Twelve Data's actual price or required rights undermine that advantage and Intrinio passes the same pilot.** If both are expensive, narrow the release further to daily-price portfolio practice or historical replay and obtain the corresponding commercial terms. Do not substitute a personal/free plan without appropriate rights.

For the wider app's future requirements, see the [stocks-and-options research](stock-and-options-provider-recommendation.md). This stocks-only recommendation is the relevant procurement starting point for the narrowed MVP.
