# Paper Trade: Twelve Data replacement audit

Reviewed November 16, 2026, against checkout `d4c3a22d` and public provider documentation. This is a static dependency and API-contract review, not an authenticated feed test or vendor licensing determination. No application code or subscriptions were changed.

## Decision

Twelve Data can replace the Yahoo/Fidelity dependencies for a US-listed-stock/ETF educational simulator, including stock order triggers, marks, charts, search and ordinary company fundamentals, after adapter and scheduling changes. It is not a verified complete replacement for everything reachable from the current Paper experience: Yahoo preset screeners, most-active lists, equity ESG, actual index/macro series, options and contract-specific futures require additional work, changed product behavior or another entitled source.

Venture at $149/month, 610 API credits/minute and 500 WS credits is a reasonable pilot/limited-launch configuration **after shared caching, quota control and explicit feature scope**. It is not a validated capacity fit for an unchanged migration of the full application. Upgrading throughput does not establish missing dataset coverage or licensing rights.

## Scope and source map

Paths below are relative to `src/robinhood_options_mobile/` unless prefixed with `docs/`.

Reviewed the complete PaperService method surface, paper ledger quote/trigger/order/lifecycle logic, backend stock order engine and equity/order schedules, Yahoo/Fidelity adapters, the Twelve Data backend adapter and Yahoo proxy, shared Browse/search/presets/benchmark/analytics consumers, paper stock/option/strategy/roll entry points, agentic/background quote selection, futures data/provider paths, and relevant paper tests. Shared optional feature paths are called out separately from core ledger requirements; feature flags can make some unavailable for a particular user.

| Source | Relevant responsibility |
| --- | --- |
| `lib/services/paper_service.dart` | Paper brokerage adapter; stock data, discovery, charts, ledger routing; numerous empty methods |
| `lib/model/paper_trading_store.dart` | Guest/authenticated ledger, stock/options/futures positions, working orders, shorting, margin, expiry/assignment |
| `functions/src/paper-trading-cron.ts` | Daily equity snapshot; ten-minute background stock-order evaluation |
| `functions/src/paper-orders-engine.ts`, `paper-trading-utils.ts` | Pure stock trigger/fill/valuation/session logic |
| `functions/src/market-data.ts` | Twelve Data first, Fidelity/Yahoo fallbacks; shared chart cache and quotes |
| `functions/src/yahoo-proxy.ts` | Web translation of search, quote and chart requests to Twelve Data; Yahoo fallback |
| `lib/services/yahoo_service.dart`, `fidelity_service.dart` | Existing model conversion and native/web fetch paths |
| `lib/widgets/search_widget.dart`, `presets_widget.dart` | Direct/shared Yahoo search and preset discovery |
| `lib/widgets/home_widget.dart`, `home/full_screen_performance_chart_widget.dart` | Index/ETF comparisons, Paper binding and refresh scheduling |
| `lib/model/portfolio_analytics_controller.dart`, `lib/services/esg_service.dart`, `lib/widgets/portfolio/analytics/return_attribution_card.dart` | Benchmark history, ESG, attribution quote fallback |
| `lib/model/agentic_trading_provider.dart`, `lib/services/agentic_trading_background_service.dart`, `agentic_trading_brokerage_service_factory.dart` | Paper auto-trade quote-source eligibility and execution monitoring |
| `lib/model/futures_auto_trading_provider.dart`, `lib/services/futures_market_data_service.dart` | Yahoo continuous-futures/proxy histories and paper futures execution context |
| `functions/src/options-flow-utils.ts`, `gamma-exposure.ts`, `macro-agent.ts`, `riskguard-agent.ts` | Optional options/macro/risk research inputs |
| `functions/src/screener-universe.ts` | Existing Twelve Data fundamentals enrichment; useful foundation, not Yahoo preset parity |

Paper tests establish supported ledger semantics (market/limit/stop/stop-limit/trailing orders, shorting, collateral/margin, option expiry/assignment and guest migration). They do not establish provider entitlements, exchange coverage or live quote freshness.

## Direct PaperService dependency replacement

| Current calls | Twelve Data approach | Result / conditions |
| --- | --- | --- |
| `getQuote`, `getQuoteByIds`, `refreshQuote`, `refreshPositionQuote`: Fidelity fastquote, then Yahoo | `/quote`, optionally shared `/quotes/price` stream | Replaceable for last-price marks/fills. Preserve previous close, provider timestamp, source, extended-hours policy and missing fields. Standard REST quote is not a stock bid/ask/size replacement. |
| `getInstrument`, `getInstrumentBySymbol`, `getInstrumentsByIds`, `getStockPositionStore`: Yahoo quote metadata | `/stocks`, `/etfs`, `/symbol_search`, `/quote`, cached `/profile` | Replaceable for eligible instruments. Explicit exchange/currency/type mapping; preserve stored identity or migrate it. Existing Robinhood-shaped URLs with symbol IDs are local compatibility identifiers, not proof of Robinhood network calls. Legacy brokerage UUIDs require a symbol lookup table. |
| `getFundamentals`, `getFundamentalsById`, holding enrichment | `/quote` + `/profile` + `/statistics` | Broad stock-field replacement: session OHLCV, description, CEO, sector/industry, location/employees, PE, market cap, shares, yield and 52-week metrics. Verify exact response paths, units and ETF nullability; stock profiles/statistics are not ETF holdings/composition coverage. |
| `getInstrumentHistoricals` | `/time_series` | Replaceable, including daily/weekly and intraday bars, with interval/range/date, session, adjustment and pagination fixes. |
| `search` | `/symbol_search` | Replaceable. Debounce, cache and filter to entitled/tradable assets rather than expose the whole catalog as supported. |
| `getMovers` | `/market_movers/stocks` | Gainers/losers replacement exists on Venture; 100 credits/request. Shared cached snapshots are necessary. This corrects older repo claims that Twelve Data has no movers/discovery endpoint. |
| `getTopMovers`, `getListMostPopular` | New discovery policy or own cached ranking | Both currently use Yahoo `most_actives`, despite their method names. Twelve Data gainers/losers is not volume ranking or user popularity. Need an explicit replacement list/universe and labeling; not endpoint parity. |
| `getForexQuote`, `getForexQuoteByIds`, `getForexHistoricals` | `/quote`, `/time_series` for forex/crypto pairs | Basic price/chart replacement; translate Yahoo `=X`, `BTC-USD` and broker pair UUIDs. Bid/ask availability depends on instrument/feed; do not synthesize executable spreads. |
| Account balances, positions, orders, tax lots, histories, guest migration | Existing local/Firestore engine | No market-data provider replacement needed for persistence or simulated execution. |

### Empty methods are not provider gaps

PaperService already returns empty/null/mock values for news, ratings, earnings, similar stocks, dividend/interest history, splits, many advanced broker/account features, option-chain discovery and option histories. Futures quotes/orders are explicitly unsupported there. These must not be counted as working Yahoo/Fidelity functionality lost in a switch.

Conversely, dividends/splits being stubs does not mean corporate actions are handled. Twelve Data offers event endpoints; stock holdings, cost basis and resting orders still need explicit action processing. A split-adjusted chart does not adjust the ledger.

## Broader Paper experience: remaining dependencies

1. **Shared screens bypass PaperService.** Search fallback and movers, Yahoo presets, Home/full-screen comparison charts, custom benchmarks, attribution and ESG can instantiate Yahoo directly. Replacing PaperService alone leaves these dependencies alive.
2. **Benchmarks and macro series need individual verification.** Home uses `^GSPC`, `^IXIC`, `^DJI`, IWM; analytics also uses ETF/custom benchmarks. Backend mappings attempt VIX, TNX, IRX, NYA, MOVE, DXY, commodities and put/call series. A mapping string does not establish a valid Twelve Data entitlement. Its indices page is marked coming soon; use an explicit symbol acceptance list. SPY/QQQ/DIA are usable potential ETF substitutes, but change the meaning and must be labeled as ETFs. VIX/yields/MOVE cannot be replaced by an equity ETF without changing the analysis. Put/call already has a separate CBOE path.
3. **Options are not verified REST coverage.** PaperService reads option instruments/marks from Firestore; option tickets, strategy builder and roll assistant also simulate using supplied option data. The backend already ATTEMPTS Twelve Data `/options/expiration` and `/options/chain` in `options-flow-utils.ts`, with Yahoo-related paths around it. The current public REST catalog does not document these routes or their Venture weights/entitlements. Their presence in code is not proof they work. Obtain a successful licensed sample with contract identity, expiry, strike, put/call, bid/ask, marks, volume, OI and IV before removing Yahoo. Greeks may be computed, but OI/IV inputs still have to exist. Older blanket statements that Twelve Data has no options functionality are too strong; verified Venture API parity is the missing evidence.
4. **Futures are a separate gap.** The futures auto-trader uses Yahoo symbols such as ES=F, NQ=F and commodity/FX proxies through FuturesMarketDataService, while the ledger can simulate futures. Commodity coverage does not demonstrate matching dated CME contracts, multipliers, expiry, rolls, sessions or tradable contract quotes. No verified replacement for this entire path was found.
5. **ESG and presets are not equivalent datasets.** The ESG service expects Yahoo equity ESG risk fields; mutual-fund sustainability data is different. Yahoo's extensive preset screener taxonomy is also not reproduced by a gainers/losers endpoint. Rebuild selected screens over an enriched supported universe, defer them or retain another licensed supplier.
6. **Auto-trading is tied to broker quotes.** Paper mode in AgenticTradingProvider resolves linked Robinhood/Schwab users and refuses to proceed when none is available. Its service factory only supports those sources. Background refresh follows that broker context. A standalone Twelve Data mode requires changes to source resolution, eligibility/settings, BUY validation and TP/SL monitoring, not just swapping PaperService calls.
7. **Risk/factor/research consumers share the budget.** RiskGuard still fetches Yahoo quote metadata; macro, backtests, event study, factor discovery and scheduled signal jobs use shared market data. Include enabled optional jobs in capacity and licensing, especially external AI processing. Twelve Data is a data supplier; Gemini/SEC/CBOE and other non-Yahoo sources remain separate services.

## Concrete migration blockers found

| Finding | Evidence / consequence | Required change |
| --- | --- | --- |
| Paper crons do not bind the Twelve Data secret | Both schedules in `paper-trading-cron.ts` omit `secrets`; adapter reads `process.env.TWELVE_DATA_API_KEY`. With normal Secret Manager deployment this path cannot access the key and falls back. Actual deployed environment was not inspected. | Bind secret to both jobs; verify deployed config. |
| Chart metadata and cache validator disagree | `fetchFromTwelveData` emits symbol/price/currency/exchange, but `isCacheStale` immediately rejects charts without `meta.currentTradingPeriod.regular.end`. | Provider-neutral cache TTL/session metadata; avoid perpetual refetching. |
| Working orders use chart-derived prices | Ten-minute cron calls `getMarketData(symbol, 5, 10, "1d")`; currentPrice may be the last daily-bar close or cached/stale chart metadata. | Dedicated fresh timestamped execution quote path; reject stale/invalid/missing prices, separate research/chart caches from fills. |
| Range/interval conversion is incomplete | Paper charts request `1wk`, `max`, `ytd`; backend maps only several minute/day/hour cases and approximates outputsize. One month of 1-minute bars can exceed API's 5000-bar cap. | Map weekly/monthly intervals, date-bound YTD/full-history requests and paginate; explicitly handle pre/post, timezone and adjustment. |
| Proxy loses important model fields | Web quote translation hardcodes bid/ask/sizes to zero and omits much instrument/fundamental metadata, while those callers reuse the Yahoo quote endpoint. Native Yahoo calls usually bypass this translation. | Explicit typed Twelve Data responses/models for all platforms; distinguish unknown fields from real zeros. |
| Mapped single-symbol quotes can be dropped | Quote wrapper keys a single result by original symbol, then reads it by mapped symbol (e.g. BTC-USD vs BTC/USD). | Consistent original-to-provider key mapping; handle partial batch errors per symbol. |
| Order engine does not receive quote age | Client/server trigger inputs are numeric price maps; Yahoo adapter stamps receipt time as updatedAt. PaperService order path can use user order price when market quote is missing. | Carry observation timestamps/source/session into validation and persisted fills. Never use a requested limit as market evidence. |
| Foreground timer is not a Paper refresh loop | Home creates a 15-second timer, but `_refresh` branches cover Robinhood/Schwab/Fidelity, not Paper. Missing-quote refresh runs separately; backend working orders run every ten minutes. | Define and implement Paper marks/order cadence. Buying 500 WS credits adds no streaming behavior by itself. |
| Session rules are incomplete | Backend helper models weekdays 09:30–16:00 and explicitly omits exchange holidays/half-days. | Use validated exchange calendar/schedule and align client/server behavior. |
| Screener enrichment needs schema and rate fixes | Existing `screener-universe.ts` calls profile/statistics/quote concurrently, five symbols at a time, with no per-minute budget. Normalizer expects flat statistics fields whereas current docs nest them under `statistics` with `valuations_metrics`, etc. | Normalize actual payloads, validate against real samples, schedule by credit weight; don't reuse as a finished adapter. |

The order cron's ten-minute sampling can miss intervening price crossings. WebSockets can improve observations, but do not supply liquidity/queue simulation. Existing whole-document client writes versus server fills are another persistence concern independent of vendor choice.

## Subscription capacity

Current official pricing confirms the screenshot: Venture $149/month = 610 API credits/minute + 500 WS credits, with no daily API cap. Larger Venture configurations are $299 (1597/1500) and $499 (2584/2500). These are published base prices, not all-in quotes.

| Endpoint/workload | Published weight | Capacity implication |
| --- | --- | --- |
| `/quote`, `/time_series` | 1 per symbol | 200 unique quotes/minute leaves 410 credits before other work. Batch HTTP requests still charge per symbol. |
| `/symbol_search` | 1 per request | Debounce/cache; many distinct queries still add up. |
| `/profile` | 10 per symbol | Cache by symbol; do not load with every mark. |
| `/statistics` | 50 per symbol | Fundamentals are the major peak-load constraint. |
| `/market_movers/{market}` | 100 per request | Gainers + losers fetched once costs 200; share snapshots across users. |
| `/quotes/price` WebSocket | 1 WS per subscribed symbol; no API credits for events | Approximately 500 subscriptions at that weight; shared backend stream required for efficient multi-user use. No Twelve Data stream implementation was found in current source. |

Illustrative calculations, not observed production traffic:

- One uncached 10-stock enrichment using quote+profile+statistics costs `10 × (1+10+50) = 610` credits, leaving no same-minute room for anything else. Existing holding hydration can also request metadata and quotes separately.
- Twenty such stocks cost 1220 credits, exceeding one minute's allocation even for one user if done together.
- A 200-symbol one-credit quote refresh plus two movers requests costs 400 credits, leaving 210 for search/charts/other jobs. This assumes cached fundamentals and no duplicate requests.
- Enriching 200 symbols costs 12,200 credits: at least 20 fully occupied quota windows, with no allowance for other calls; pace it over longer in a real app.
- Enriching 500 symbols through the existing admin seeder costs 30,500 credits: 50 full 610-credit quota windows. Five-symbol concurrency does not enforce this limit.

There is no defensible user-count estimate without simultaneous-user, symbol-overlap, cache-hit, chart-resolution and enabled-job measurements. All functions/instances using the same subscription must share the budget. A per-symbol cache, request coalescing and centralized weighted rate limiter matter more than the HTTP batch count.

## Data quality and rights

The default US real-time feed covers listed symbols but about 5% of US trading volume; it is not consolidated NBBO, full-market volume or order-book data. Official history/EOD guidance describes full-market volume after its publication cutoff. Store feed identity and do not silently combine these as a single homogeneous execution/backtest dataset. REST quote does not document US bid/ask/sizes; WS has a bid/ask example for gold/FX where available, not a promise of equity NBBO. Existing last-price simulation can work within this limitation.

Venture permits external display, temporary caching and portfolio calculations, but provider guidance separately calls out redistribution agreements/add-ons. The business pricing page lists a US Equities external-distribution add-on from $2400/year ($200/month equivalent); that would make the base arithmetic $349/month if applicable. This is a conditional illustration, not a determination that the app requires it or that it covers every use.

Request written classification for the exact architecture: commercial mobile/web display; company-owned backend feed/fanout; permitted cache retention and historical storage; non-display simulation, short/margin checks and background fills; derived portfolio history; attribution; external AI processing and any exports. Confirm actual US ETF/symbol coverage and any non-US permissions separately. The documentation's student-competition example is not blanket approval of this commercial app.

## Recommended implementation sequence

1. Agree on launch scope and obtain the licensing/coverage response; retain the $149 Venture configuration as the pilot target.
2. Implement server-owned typed quote/search/chart/reference/fundamentals endpoints with secret binding, authentication supporting the chosen guest model, symbol eligibility, timestamp validation, shared cache/coalescing and weighted quota limits. No company API key in Flutter.
3. Fix the existing adapters/cache/intervals before removing fallbacks. Preserve instrument identity and previous-close/adjustment semantics.
4. Route PaperService and every included shared screen through that boundary. Cache fundamentals separately from quote cadence. Rebuild/rename most-active/preset behavior deliberately.
5. Add standalone provider selection to paper auto-trading and background monitoring. Use the same timestamped quote model for placement, triggers, marks and TP/SL. Decide polling versus a persistent shared stream.
6. Gate unsupported optional features at both UI and execution/job boundaries; preserve stored positions. Do not interpret hiding an options tab as disabling all strategy/roll paths.
7. Pilot AAPL, SPY, QQQ, BRK.B, a low-liquidity symbol and a split case; validate missing/partial responses, quota reset/429s, holidays/half-days, history ranges, adjustment, guest access and quote age. Then remove Yahoo/Fidelity only from proven migrated paths.

Required verification for that implementation includes meaningful adapter contract tests using provider samples, timestamp/session/partial-batch tests, existing paper ledger tests, chart range tests, and a multi-user load pilot. No runtime tests were run for this documentation-only audit; no paid/authenticated provider calls were made.

## Official sources checked

- [Exact published business configurations](https://twelvedata.com/pricing.md)
- [Business pricing, credit rules and add-ons](https://twelvedata.com/pricing-business)
- [Quote](https://twelvedata.com/docs/market-data/quote), [time series](https://twelvedata.com/docs/market-data/time-series), [market movers](https://twelvedata.com/docs/market-data/market-movers)
- [Symbol search](https://twelvedata.com/docs/discovery/symbol-search), [profile](https://twelvedata.com/docs/fundamentals/profile), [statistics](https://twelvedata.com/docs/fundamentals/statistics)
- [WebSocket schema and weights](https://twelvedata.com/docs/websocket/websocket-getting-started)
- [US coverage and distribution rights](https://support.twelvedata.com/en/articles/9935903-us-equities-market-data)
- [Commercial usage](https://support.twelvedata.com/en/articles/5332349-commercial-and-personal-usage)
- [Unsupported data types](https://support.twelvedata.com/en/articles/5179078-unsupported-data-types), [indices status](https://twelvedata.com/indices), [current REST catalog](https://twelvedata.com/docs/llms.txt)

This audit supersedes older migration-document assumptions about personal Pro commercial rights, endpoint costs, movers availability and verified options/index coverage for this purchase decision. It does not claim to replace every Yahoo/Fidelity usage in unrelated live-broker features.
