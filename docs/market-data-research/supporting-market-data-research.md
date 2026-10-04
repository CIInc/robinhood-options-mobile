# Supporting market-data research

This preserves the detailed research and earlier working release plan. The [executive recommendation](stock-and-options-provider-recommendation.md) is the current decision brief and supersedes earlier packaging recommendations here.

# Stock and options market-data recommendation for RealizeAlpha

Research date: October 4, 2026. Prices are USD. Published prices below were checked against provider websites; custom quotes, exchange charges, taxes, infrastructure, and engineering costs are excluded unless explicitly stated. No paid subscriptions or vendor outreach were performed.

## Recommendation for a small startup

**Release stock/ETF paper trading first, add basic options paper trading second, then connect one approved broker for live stocks and subsequently live options.** Keep commercial research data and account-entitled live trading data separate. Increase data spend when an actual feature needs better inputs, rather than buying a comprehensive live feed for the whole roadmap upfront.

For the first release, evaluate **Twelve Data Venture** because the stock adapter already exists. For options practice, evaluate **Intrinio Startup** as a replacement for the research feed, not an automatic second subscription. Keep that move conditional on contract discovery, simulation rights, quotas and a data-quality pilot. For live execution, start with **Schwab's commercial integration path** because the repository already has account, quote and order adapters; verify partner access before committing to that broker. Its developer portal distinguishes fintech access from personal-account applications. [Schwab developer portal](https://developer.schwab.com/).

This staged plan replaces the earlier two-package recommendation. The expensive full-market vendor stack remains a comparison benchmark, not the startup's target architecture. Paper and live modes can coexist; simulated holdings never become real positions automatically.

## Release heatmap: features and data cost

Legend: **🟩 Include**; **🟨 Limited, estimated, or conditional**; **⬜ Defer**. Colors describe proposed release scope, not verified provider entitlements or completed implementation. Each stage retains earlier paper features unless the table says otherwise.

| Feature / cost | R1: stock/ETF paper MVP | R2: add options paper | R3: live stock/ETF beta | R4: add live options |
| --- | --- | --- | --- | --- |
| Guest account, virtual cash, reset, migration | 🟩 Include | 🟩 Include | 🟩 Paper remains | 🟩 Paper remains |
| Stock/ETF paper orders and P&L | 🟩 Market + validated limits | 🟩 Include | 🟩 Include | 🟩 Include |
| Options paper orders | ⬜ Defer | 🟨 Long calls/puts first | 🟨 Retain estimated fills | 🟨 Retain unless feed upgraded |
| Watchlists and historical stock charts | 🟩 Include | 🟩 Include | 🟩 Research + entitled live | 🟩 Include |
| Paper execution realism | 🟨 Sampled feed/reference model | 🟨 Synthetic/model estimates | 🟨 Paper model remains | 🟨 Broker live data does not upgrade all paper users |
| Options contract selection and Greeks | ⬜ Defer | 🟨 Verify discovery; model Greeks | 🟨 Same paper scope | 🟩 Broker data for entitled users; freshness varies |
| Options OI, volume and spread screening | ⬜ Defer | ⬜ Unless separately verified | ⬜ Unless separately verified | 🟨 Only verified broker fields |
| Single-broker connection | ⬜ Defer | ⬜ Defer | 🟩 Approved account connection | 🟩 Same broker |
| Live account balances and positions | ⬜ Defer | ⬜ Defer | 🟩 Broker is source of truth | 🟩 Broker is source of truth |
| Live stock/ETF orders | ⬜ Defer | ⬜ Defer | 🟩 User-confirmed orders | 🟩 Include |
| Live option orders | ⬜ Defer | ⬜ Defer | ⬜ Defer | 🟨 Approved accounts; basic single-leg first |
| Short options / multi-leg spreads | ⬜ Defer | ⬜ Defer | ⬜ Defer | ⬜ Separate later release |
| Background paper fills | 🟨 Only if scheduled engine is validated | 🟨 Options require lifecycle work | 🟨 Broker owns live execution | 🟨 Broker owns live execution |
| GEX, verified sweeps and full-market scans | ⬜ Defer | ⬜ Defer | ⬜ Defer | ⬜ Revenue-funded later add-ons |
| Autonomous/copy live trading | ⬜ Defer | ⬜ Defer | ⬜ Defer | ⬜ Separate validated scope |
| External AI / raw-data export / onward APIs | 🟨 Only explicitly licensed uses | 🟨 Same restriction | 🟨 Also respect broker agreement | 🟨 Same restriction |
| Preferred company research subscription | Twelve Data Venture | Intrinio Startup **if pilot passes** | Retain R2 research feed | Retain R2 research feed |
| Published recurring data baseline | **From $149/month**; larger selected plan $499 | **$333 → $666 → $999/month** | **R2 baseline + broker-specific quoted costs** | **R2 baseline + broker/entitlement costs** |
| Company-wide consolidated live feed | ⬜ Not required for proposed scope | ⬜ Not required for proposed scope | ⬜ Use account-entitled broker path | ⬜ Use account-entitled broker path |

The plan prices are published reference points. Twelve Data's exact configuration and rights need confirmation; Intrinio's pricing increases with time since subscription, not when the app moves between release stages. Stock options here mean equity/ETF options; index options and index levels require separate coverage validation. [Twelve Data business pricing](https://twelvedata.com/pricing-business), [Intrinio pricing](https://intrinio.com/pricing).

## Cost ladder and purchasing rules

All figures are USD provider subscriptions, excluding taxes, Firebase/storage/egress, implementation, support, broker partner fees and any additional licensing charges. **Live-stage total costs remain quote-dependent.** A price for an individual developer account is not a commercial app price.

| Stage / upgrade | Published baseline or calculation | Spending recommendation | What is compromised |
| --- | --- | --- | --- |
| R1 stock/ETF paper | Twelve Data floor: $149/month, $1,788/year at monthly rates; page also displays a larger $499/month configuration | Seek the smallest configuration that passes the pilot; verify it before treating $149 as committed cost | Partial-market/sampled data and estimated fills; no claim of full consolidated liquidity |
| R2 options paper | Intrinio: months 1–6 $333/month; months 7–12 $666; thereafter $999. First subscription year $5,994; later $11,988/year | Replace R1 feed only if Intrinio meets stock-chart and options needs; budget renewal before launching | Synthetic prices; advanced execution/flow/OI analytics deferred |
| Temporary overlap during R2 migration | $149 + $333 = $482/month initially at the advertised minimums; $149 + $999 = $1,148/month later | Keep overlap short, unless a specific missing stock feature justifies both | Extra integration and spend; two feeds may differ in timestamps/semantics |
| Optional realistic options-paper upgrade | R2 baseline **plus a scoped delayed exchange-feed quote**, or a replacement package quote; no verified incremental price | Obtain Intrinio and MarketData.app commercial quotes; buy only the fields/features users need | 15-minute delay; quote-based fills still cannot reproduce queue position or actual execution |
| R3 live stocks | Retained research subscription **plus commercial broker costs quoted for this app** | Use one approved broker; do not buy a separate market-wide live vendor feed just to route orders | Users must connect that broker; broker outages, account permissions and coverage constrain access |
| R4 live options | Retained research subscription **plus broker/option entitlement charges, if any** | Add only after order reconciliation and broker options approval work | Eligibility constraints and limited strategy scope; premium analytics remain deferred |

Twelve Data's standard real-time US feed represents roughly 5% of trading volume; full listed-symbol coverage is not consolidated volume or NBBO. That tradeoff can fit an educational paper MVP. [US feed coverage](https://support.twelvedata.com/en/articles/9935903-us-equities-market-data).

Intrinio Startup has commercial display rights, but synthetic prices do not establish tradable spreads. Raw-data redistribution and external AI transmission need the applicable contractual rights. [License scope](https://help.intrinio.com/licensing-data-usage-requirements), [AI/data terms](https://data.intrinio.com/terms).

Do not count the advertised Intrinio ramp as a discount lasting throughout R2–R4. For example, an account opened six months before live beta may already cost $666/month when that beta launches. Negotiate scope and renewal economics; remain on R1 longer if paid demand does not justify the options subscription.

## What ships at each stage, and the release gates

### R1 — stock/ETF paper MVP

Launch a bounded universe of liquid US stocks/ETFs, virtual cash, market/validated limit orders, holdings/P&L, watchlists, daily charts and trade history. Include session/freshness labels, split handling and an explicit dividend policy. Avoid shorting, margin and advanced order types at first. Gate options at the UI, order API/tool boundary and scheduled jobs.

**Gate:** the commercial stock configuration covers client display and backend simulation/caching; timestamp-aligned quotes and corporate actions pass the pilot; cash, order deduplication, stale-price rejection and guest migration work reliably. Assess background fills explicitly: if evaluation occurs only while the app is open, say so rather than promising continuous execution.

**Business purpose:** validate activation, repeat usage and willingness to pay before paying for options. Expand symbols or refresh frequency only when traffic and retention justify them. The detailed [stocks-only MVP report](stocks-only-paper-trading-mvp-recommendation.md) covers this stage.

### R2 — basic options paper trading

Add long calls/puts on a small liquid equity/ETF universe, contract selection, modeled Greeks, expiration handling and simulated option P&L. Intrinio Startup is the first evaluation candidate; verify contract metadata and chart coverage before replacing Twelve Data. An assumed spread/slippage model is acceptable only when the experience explains that fills are estimates.

**Gate:** correct call/put, expiry, multiplier, exercise/settlement style and quote/reference age; lifecycle behavior for expiration and exercise; coherent stock/options valuation; verified simulation license and quotas. Do not hard-code 100 shares for adjusted contracts. Unsupported exercise/expiration scenarios should block that instrument or have a disclosed simplified rule.

**Business purpose:** offer a paid educational options feature, while deferring short options, spreads, 0DTE execution-realism claims, verified flow and GEX. This narrows both data and support obligations.

### Optional R2 upgrade — delayed quote-based paper execution

If users need credible spread-aware simulation, request delayed exchange stock/options quotes with required sizes, volume/OI and Greeks. Upgrade the affected feature inputs rather than purchasing every analytics dataset. Use a common delayed market clock for order activation, triggers, fills and P&L; observations from before an order's activation must not fill it.

**Gate:** written incremental price and rights, working quote-based fill engine, and demonstrated demand for better simulation. This upgrade can happen before or after live beta. It is not a prerequisite for broker-connected live orders, whose price checks come from the broker.

### R3 — broker-connected live stock/ETF beta

Introduce one commercially approved broker integration. Start with account connection and read-only balance/position/order reconciliation, then enable manually confirmed stock/ETF orders. Refresh the user's entitled broker quote at order review, use broker buying power, and record broker order IDs. Handle rejection, partial fill, cancellation and ambiguous submission responses; query status before retrying an uncertain order.

**Gate:** approved third-party access, authenticated account permissions, disconnect/reconnect behavior, freshness checks and reliable order lifecycle reconciliation. Existing code is a starting point, not proof of production readiness. Schwab's commercial API price and market-data rights were not verified publicly here. If unavailable, compare a scoped Tradier or Alpaca partner route rather than treating their personal plans as interchangeable commercial access.

**Business purpose:** let validated paper users connect their existing supported account; avoid the additional scope of becoming a brokerage platform. Data partners alone do not execute trades. Broker authorization and account eligibility are separate from the app's research subscription.

### R4 — live options for eligible broker accounts

Enable manual single-leg option orders after the stock beta's lifecycle is stable. Check options approval level, account permissions, buying power, contract identity, current entitled bid/ask and the broker's supported preview/validation workflow. Initially restrict to supported long calls/puts; closing imported existing positions needs its own validated handling. Defer short-option openings and spreads until collateral, exercise/assignment and multi-leg behavior are ready.

**Gate:** broker-specific options integration and account entitlements; rejection/partial-fill/cancel reconciliation; accurate positions and lifecycle events. Greeks and quote freshness differ by broker: Tradier, for example, documents hourly Greeks and account-holder-only real-time access. [Tradier data limitations](https://docs.tradier.com/docs/market-data).

**Business purpose:** graduate eligible users into manual live options without financing a shared real-time OPRA feed for every guest. Broker data must remain within permitted user/account contexts, not be cached as a general feed for unrelated paper users.

## How paper progresses to live technically

| Concern | Paper mode | Live mode | Required transition |
| --- | --- | --- | --- |
| Money and positions | App-maintained virtual ledger | Broker-held cash, holdings and buying power | Keep separate ledgers and explicit mode/account badges |
| Price source | Licensed research feed/model | User's entitled broker quotes | Identify source/time; prevent synthetic paper marks from authorizing live orders |
| Fill authority | Simulation engine | Broker executions | Never label submission acceptance as a fill |
| Order ID and retry behavior | Internal stable IDs | Internal intent + broker ID/status | Reconcile unknown results before resubmission |
| Permissions | App's simulation feature scope | Broker account and trading approval | Recheck on account switches and token reconnects |
| Progress/history | Simulated performance and learning | Separate actual fills and performance | Preserve paper history; distinguish track records |
| “Move to live” action | User can review a practice idea | Fresh user-confirmed live order | Reprice/revalidate and require explicit live intent; never transfer virtual holdings |
| Data cost | Shared research subscription | Research baseline + contracted broker costs | Entitled live data is not a blanket redistribution license |

The [brokerage interface](../../src/robinhood_options_mobile/lib/services/ibrokerage_service.dart), [Schwab adapter](../../src/robinhood_options_mobile/lib/services/schwab_service.dart), [paper service](../../src/robinhood_options_mobile/lib/services/paper_service.dart) and [paper engine](../../src/robinhood_options_mobile/lib/model/paper_trading_store.dart) already provide separation points. Add normalized feed metadata and order intents while preserving different execution authorities. Review credentials, entitlements and all entry paths rather than only enabling existing screens.

Shared backend analytics, cross-user research, raw exports and AI data delivery still need commercial permission. Adding a broker account does not extend that user's data entitlement to all app users. Autonomous trading, copy trading and public live-data redistribution are separate later releases, each with their own requirements and cost assessment.

## Upgrade triggers and startup economics

Use gates rather than promised calendar dates. Advance from R1 when retained users request options and prospective revenue supports the recurring plan. Advance from R2 to live when broker access is approved and manually initiated orders reconcile reliably. Upgrade paper data fidelity only when users need it; live orders can use the broker path independently.

For an illustrative **$10 net monthly contribution per paying customer**, a $149 feed requires 15 paying customers to cover its subscription alone; $333 requires 34; $666 requires 67; $999 requires 100. At $20 net contribution, the counts are 8, 17, 34 and 50. These are rounded-up arithmetic examples, excluding all other costs; they are not suggested pricing or demand forecasts.

Buy a market-wide exchange feed later only for an explicitly monetized feature, such as a commercially licensed shared options scanner. Obtain quotes from Intrinio, MarketData.app, ThetaData and Databento for that narrow workload. Massive's published full stack is useful as a ceiling comparison, not a mandatory graduation step. Broker-connected trading and a company-wide live data platform are different purchasing decisions.

## Wider project requirements and provider research

The sections below describe the larger existing app and provider catalog. Their broad datasets and costly benchmark scenarios are not all required by R1–R4.

The app is a Flutter client with Firebase/TypeScript backend functions, brokerage integrations, paper trading, portfolio analytics, option strategy building, GEX, alerts, signals, and backtesting. These create several distinct data workloads.

| Workload | Required data | Cost-conscious launch choice |
| --- | --- | --- |
| Stock watchlists, portfolio marks, paper trading | Prices, timestamps, bid/ask when available, market session | Broker quotes for connected users; labeled commercial delayed/synthetic prices for research |
| Charts, indicators, benchmark comparisons, backtesting | Daily and intraday OHLCV, adjustment policy, splits/dividends, expired/delisted coverage where needed | Shared licensed historical stock bars; request intraday only for relevant symbols |
| Options chains, strategies, rolling, liquidity checks | Contracts, expirations, strikes, call/put, exercise/settlement details, multiplier, bid/ask and sizes, last, volume, OI | On-demand chains and selected expirations; broker quote refresh at order entry |
| Portfolio Greeks, IV surfaces, GEX, 0DTE tools | Synchronized underlying prices and option quotes, IV/Greeks, OI with effective date | Delayed research with clear age; fresh entitled inputs for live decisions |
| Options activity rankings | Chain volume/OI changes, IV, quote context | Snapshot-based unusual activity with transparent methodology |
| Verified trade/sweep analytics | Individual trade price/size/time, venue, conditions, contemporaneous quotes, corrections | Separate premium phase; not achievable from chain snapshots alone |
| Background signals and notifications | Licensed backend inputs, predictable quotas and freshness | Small deduplicated symbol universe, market-hours scheduling |

### Code evidence and implications

- [`market-data.ts`](../../src/robinhood_options_mobile/functions/src/market-data.ts) uses Twelve Data `/quote` and `/time_series`, Firestore chart caching, and Fidelity/Yahoo fallback paths. Provider responses are converted to legacy-compatible shapes. A new provider therefore needs an adapter, not a new UI for every feature.
- `functions/src/options-flow-utils.ts` calls Twelve Data `/options/expiration` and `/options/chain`, initially takes four expirations, maps calls/puts, and rejects chains without usable OI on both sides before falling back to Yahoo. The existence of these calls is evidence of implementation intent, not proof of the provider's actual plan coverage or response schema.
- The same file sets the options-chain cache TTL to **24 hours** and derives activity premium using **last price × cumulative volume × 100**. That is an activity estimate, not the premium of a specific observed trade. A better data feed alone will not turn these records into verified sweeps.
- `functions/src/options-flow-cron.ts` runs every **15 minutes**. `functions/src/gamma-exposure.ts` caches GEX for **four hours** and calculates gamma exposure from gamma, OI, and spot. Such ages need product-specific freshness handling, particularly for 0DTE.
- `lib/services/paper_service.dart` uses Fidelity/Yahoo paths; migrating only the backend leaves this dependency intact.
- `lib/services/ibrokerage_service.dart` already separates brokerage operations. `lib/model/option_marketdata.dart` includes bid/ask, sizes, mark, volume, OI, IV, Greeks, OCC identity, and update time. It also includes brokerage-specific probabilities/fill estimates that a generic feed should leave unavailable rather than fabricate.

This assessment is static code inspection. Credentials, account entitlements, production traffic, and successful provider responses were not tested. Stock/options research is the focus; futures, crypto, global markets, fundamentals, news, and index levels may require separate products.

## Provider comparison and pricing

Personal/internal pricing is shown to prevent confusing inexpensive development access with customer-facing commercial rights.

| Provider | Published pricing checked | Stocks and options fit | Commercial implication |
| --- | --- | --- | --- |
| **Intrinio** | Startup: $333/month for first six months, $666/month for next six, $999/month thereafter; quarterly billing. Enterprise from $1,250/month. Individual $150/month | Startup includes stock/option history and synthetic live prices; exchange options products also available | Startup explicitly includes commercial display; actual live/delayed OPRA feed requires scoped confirmation. [Pricing](https://intrinio.com/pricing) |
| **Twelve Data** | Venture advertised **from $149/month**; page's selected larger configuration shows $499/month or $4,990/year. Enterprise from $1,099/month | Existing stock adapter; app has options calls but this research could not verify their official schema/entitlement | Business display tier needed; do not assume advertised starting price includes required options data. [Business pricing](https://twelvedata.com/pricing-business) |
| **MarketData.app** | Starter $30/month or $144/year; Trader $75/month or $360/year; Quant $125/month; Prime $250/month; Commercial custom with annual commitment | Chains, IV, Greeks, OI, stock/option history | Standard plans are internal use; commercial redistribution has a separate plan. Direct-device BYOK is an alternative. [Pricing](https://www.marketdata.app/pricing/) |
| **Massive (formerly Polygon)** | Stocks Business $2,499/month; Options Business $1,999/month; combined **$4,498/month** | Broad history, snapshots, derived live valuations; raw intraday exchange feeds are expansions | Base business pricing is not a complete live consolidated quotes package. [Stocks](https://massive.com/business-stocks), [options](https://www.massive.com/business-options) |
| **Alpaca** | Personal Algo Trader Plus $99/month; free Basic. Broker plans: Standard equities included with indicative options +$1,000/month; higher tiers $500–$2,000/month with differing option inclusion | Personal paid plan includes consolidated stocks and OPRA options | Broker tiers are for Alpaca brokerage partners; their standard feeds are IEX/delayed SIP and indicative options. Obtain a quote for this independent app's live commercial requirements. [Data plans](https://docs.alpaca.markets/us/docs/about-market-data-api) |
| **Tradier** | Market data available to brokerage account holders; commercial partner pricing not publicly established here | Consolidated live stocks/options; Greeks updated hourly; sandbox delayed | Useful if users connect Tradier; not a shared feed for unrelated brokerage customers. [Market data](https://docs.tradier.com/docs/market-data), [fintech program](https://production.tradier.com/businesses/fintechs) |
| **ThetaData** | Retail options Value $40/month, Standard $80/month, Pro $160/month; commercial price needs quote; stocks/indices separate | Strong option history, NBBO/trades and chain snapshots, tier-dependent | Retail rates explicitly say individual use; budget commercial rights and terminal hosting separately. [Pricing](https://www.thetadata.net/subscribe), [subscriptions](https://thetadata.net/docs/Articles/Getting-Started/Subscriptions.html) |
| **Databento** | OPRA Standard introduced at $199/month; historical usage-based pricing; external-distribution cost needs dataset-specific quote | Raw trades/quotes, instrument definitions, bars; analytics adapter required | Do not interpret Standard as a turnkey customer redistribution license. Current pricing separates distribution and license terms. [OPRA announcement](https://databento.com/blog/introducing-new-opra-pricing-plans), [pricing](https://databento.com/pricing) |

### Pros, cons, and selection rationale

**Intrinio — best first commercial evaluation.** Pros: published startup ramp, display rights, one supplier for stocks/options, and a path to exchange feeds. Cons: first-year pricing increases; synthetic OptionsEdge is not OPRA NBBO; required chain/OI fields, delayed options inclusion, quotas, and later costs must be confirmed. Its separate delayed options product documents quotes, volume, OI, IV, and Greeks; request that product explicitly. [Startup and feed details](https://intrinio.com/pricing), [options FAQ](https://help.intrinio.com/options-faqs).

**Twelve Data — potentially lowest migration cost.** Pros: existing backend adapter, business display tier, broad asset coverage, startup discount program. Cons: credit weights depend on endpoint and symbol; options inclusion is unverified here; partial current integration does not prove suitability for GEX. Ask for documented expiration/chain schemas, bid/ask/OI/Greeks coverage and update cadence, and exact commercial quote. The page advertises a 20% eligible startup discount; do not assume it applies to every configuration. [Business pricing and credit rules](https://twelvedata.com/pricing-business), [commercial usage](https://support.twelvedata.com/en/articles/5332349-commercial-and-personal-usage).

**MarketData.app — cheapest company-funded optional route.** Pros: explicit mobile BYOK support; user-paid plans; chains/history useful for local tools. Cons: its BYOK rules require device-only requests, processing, keys and storage; no server relay, shared scans, cloud-derived results, data export, or onward delivery. This conflicts with Firebase analytics, exports and potentially MCP data delivery. Keep any BYOK feature isolated from those paths. Commercial terms need a quote. [BYOK rules](https://www.marketdata.app/education/licensing/bring-your-own-key/). Its pricing table distinguishes API stock quote delay from SmartMid synthetic pricing, so verify endpoint freshness. [Pricing details](https://www.marketdata.app/pricing/).

**Massive — strong technical benchmark, expensive launch choice.** Pros: broad stocks/options, Greeks/OI, snapshots, unlimited calls. Cons: two base subscriptions; FMV differs from exchange bid/ask. Options expansions cost +$499/month delayed or +$1,999/month live; exchange fees may apply. Stocks have equivalent full-market expansion prices. Both classes with delayed expansions total **$5,496/month**; live expansions total **$8,496/month**, before applicable exchange charges. Qualifying startups may get 25% or more off year one; request eligibility. [Options business details](https://www.massive.com/business-options), [stocks business details](https://massive.com/business-stocks).

**Alpaca — excellent personal prototype, conditional commercial fit.** Pros: stock/options REST and WebSockets, low personal development price. Cons: Basic options are indicative rather than executable exchange quotes; broker partnership changes scope; $99 does not establish commercial redistribution rights. Its paid personal options stream supports 1,000 quote subscriptions, making full-chain universe streaming a capacity concern. [Official plans](https://docs.alpaca.markets/us/docs/about-market-data-api).

**Tradier — good broker-connected alternative.** Pros: consolidated account-holder data and options integration. Cons: new brokerage onboarding, hourly Greeks unsuitable as a universal fresh 0DTE input, and no general real-time solution for non-account holders in the documented offering. [Official market-data limitations](https://docs.tradier.com/docs/market-data).

**ThetaData — shortlist for options research.** Pros: detailed history and trade/quote access. Cons: commercial rate unknown, separate underlying/index products, and Theta Terminal requirement creates an operational service rather than a simple stateless function call. Its pricing and subscription docs differ in some tier details; validate current access in a trial account. [Retail pricing](https://www.thetadata.net/subscribe), [terminal/access requirements](https://thetadata.net/docs/Articles/Getting-Started/Subscriptions.html).

**Databento — shortlist for a future verified flow pipeline.** Pros: normalized event data, historical pay-as-you-go purchasing, multiple asset classes. Cons: build chains, Greeks/IV calculations or supplements, trade attribution, and stream infrastructure; total commercial cost is not the $199 OPRA headline. Buy small historical samples before subscribing to a broad live feed. [Products and licensing dimensions](https://databento.com/pricing).

**Yahoo/Fidelity public endpoints — current dependencies to replace or contractually validate.** Pros: already implemented and no configured subscription cost. Cons: the repository does not establish commercial redistribution permission, guaranteed access, or contractual reliability. Do not count public accessibility as authorization or call a fallback “real-time” without checking timestamps. This is a code/dependency finding, not a legal determination about every use of either service.

## Budget scenarios

| Launch scenario | Known subscription arithmetic | What it can realistically support |
| --- | --- | --- |
| Broker-connected users plus optional direct-device BYOK | $0 incremental company feed subscription for that optional route; user pays own provider plan | Personal live brokerage UI and local research, contingent on agreements; shared Firebase analytics still need another feed |
| Intrinio commercial research evaluation | Year one: `6 × $333 + 6 × $666 = $5,994`, average $499.50/month; later $11,988/year | Synthetic/history research package; required delayed exchange chains may increase this budget |
| Retain Twelve Data with minimum business display package | Advertised floor $149/month = $1,788/year at that monthly rate | Stock research if required coverage is included; options and capacity may require upgrades |
| Massive both asset classes, base only | $4,498/month = $53,976/year | Commercial history/derived data; raw live execution quotes require expansions |
| Full commercial live exchange stack | Vendor base + both exchange feed products + usage/display/non-display/distribution fees, if applicable + infrastructure | Requires a written all-in quote; no defensible cheap all-in figure established |

The BYOK route transfers subscription cost and onboarding effort to users; it is not free total customer cost. The lower commercial scenarios also carry feature limitations. These are procurement comparisons, not equivalent product bundles.

Use this cost model:

`monthly total = vendor subscription + feed add-ons + licensed user fees + distribution/non-display charges + historical usage + backend compute/storage/egress`

Ask each vendor who handles each licensing obligation and whether it is included. Delayed, synthetic and historical are different products. A 15-minute delay does not by itself establish free redistribution, and an options contract feed does not automatically include the underlying index level. Do not copy a blanket OPRA fee estimate across every provider arrangement.

## Reduce costs before increasing the plan

1. **Measure unique symbols, not just users.** Example assumptions: 100 daily active users × 20 watched stocks = 2,000 user-symbol requests per refresh. If overlap leaves 200 unique stocks, one shared licensed refresh reduces upstream demand tenfold. Only share results when the contract permits it.
2. **Batch without assuming free credits.** For a 6.5-hour regular session and five-minute sampling: `200 × 78 = 15,600` symbol refreshes/day. A 20-symbol batch reduces HTTP requests to 780, but a per-symbol billing model can still charge 15,600 units.
3. **Load options on demand.** Twenty active underlyings × four expirations × 26 fifteen-minute refreshes = 2,080 chain requests/day, before pagination, expiration discovery, or retries. At an illustrative 200 contracts per response, per-contract charging can mean 416,000 units/day. These are workload assumptions, not any vendor's promised quotas.
4. **Separate daily OI from changing quotes.** Cache contract metadata and OI according to their effective dates; refresh prices/IV more frequently only where required. Keep derived GEX freshness tied to the oldest material input.
5. **Stop broad polling after hours.** Use exchange calendars and asset-specific hours, deduplicate users' scheduled scans, and refresh only subscribed instruments.
6. **Bound historical downloads.** Cache licensed adjusted bars, fetch incremental changes, and purchase tick samples for selected symbols/date windows. Verify rights to retain data after cancellation.
7. **Separate order-entry needs from research.** Revalidate quotes through the user's entitled broker before orders. Prevent synthetic or stale marks from silently feeding execution decisions.
8. **Add quota and freshness telemetry.** Track cost units, cache hit rate, latency, missing fields, fallback count, and age by provider. Use backoff and request coalescing to avoid quota exhaustion and cache stampedes.

These changes also reduce Firebase invocations and reads/writes. Shared WebSocket ingestion may eventually be cheaper for sustained demand, but requires a persistent backend service; assess it after measuring polling traffic.

## Concrete evaluation and migration plan

### First: obtain comparable quotes and validate coverage

Send vendors a scope covering a commercial iOS/Android multi-broker app, guest paper trading, stock/options displays, Firebase caching and derived analytics, background jobs, AI processing, and exports/group sharing where required. Request prices at **100, 1,000 and 10,000 active users**, initially assuming mostly non-professional US users, and ask how professional users change the price.

Evaluate **Intrinio and Twelve Data first**, with **MarketData.app Commercial** as a competitive quote. Ask for an actual delayed exchange-options package containing OI and Greeks, not just a synthetic price feed. Use Massive as a published commercial cost benchmark. Request ThetaData/Databento quotes only if historical tick research or verified trade flow is a near-term requirement.

For every quote, require an itemized first-year and renewal total, user/connection/symbol/credit limits, annual commitment, startup eligibility, exchange fees, and exact permitted display, backend analysis, AI, retention, export, and redistribution uses. Do not assume derived metrics have unrestricted distribution rights.

### Second: run a small data-quality pilot

Use AAPL, SPY, QQQ, an illiquid stock/option, and BRK.B; add SPX/SPXW if index options are intended. Check expirations, weeklies/0DTE, LEAPS, OCC identity, adjusted contracts, multiplier, time zones, pagination, missing Greeks, and stale/crossed quotes. Compare timestamp-aligned quotes with an entitled broker during market hours; include expiration day and market open.

For GEX, require meaningful OI on both sides, effective date, and coherent spot/IV/Greek units. Treat GEX as a model estimate of positioning, not observed dealer inventory. For backtesting, check adjustment policy, expired options, delisted stocks, quote history and historical OI separately: historical bars do not imply historical full-chain snapshots.

For any flow feed, verify trade timestamps, price/size, conditions, venue and matching quote context; document sweep classification uncertainty. Never infer a verified sweep from daily cumulative contract volume.

### Third: integrate only the chosen launch scope

Introduce a market-data provider interface separate from brokerage execution. Normalize `source`, `feedType` (exchange/synthetic), `asOf`, `receivedAt`, `delaySeconds`, entitlement, OI effective date, and field availability. Preserve option symbols, adjustment information and multipliers; do not universally assume 100 shares.

Replace backend and paper-account public-endpoint paths, preserve permitted broker-specific data, and separate quote caches from metadata/OI caches. Support delayed/synthetic/stale labels and reject unusable execution inputs. Remove fallback providers lacking required permission. For BYOK, use a separate device-only service and prevent data from reaching cloud analytics, exports or onward APIs.

No app changes are included in this research deliverable. The next purchasing decision is conditional on the quote and pilot, rather than selecting a plan based only on a headline price.

## Relationship to the existing report

The earlier [market-data providers report](../market-data-providers-research.md) covers options/futures but should not be used as the current procurement price list. This research updates several decision-critical points: Twelve Data has a separate business display tier; MarketData.app now advertises a commercial plan and a constrained BYOK route; Intrinio publishes a startup ramp; Massive prices stock and option business products separately with exchange expansions; Databento's Standard headline is not sufficient evidence of external distribution rights. Existing implementations and marketing claims still need endpoint-level verification.

## Implementation references

Paths below are relative to this report's directory.

- [Backend stock quotes and bars](../../src/robinhood_options_mobile/functions/src/market-data.ts)
- [Option chain adapters, caching and activity estimates](../../src/robinhood_options_mobile/functions/src/options-flow-utils.ts)
- [Scheduled options scanning](../../src/robinhood_options_mobile/functions/src/options-flow-cron.ts)
- [Backend GEX calculations](../../src/robinhood_options_mobile/functions/src/gamma-exposure.ts)
- [Brokerage interface](../../src/robinhood_options_mobile/lib/services/ibrokerage_service.dart)
- [Paper trading data dependencies](../../src/robinhood_options_mobile/lib/services/paper_service.dart)
- [Option market-data model](../../src/robinhood_options_mobile/lib/model/option_marketdata.dart)

Provider links throughout this report point to the primary sources reviewed on the research date. Advertised capabilities, price selections, and licensing terms can change; record the final contracted scope before implementation.
