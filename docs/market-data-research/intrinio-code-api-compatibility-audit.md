# Intrinio compatibility audit: app code and API

Reviewed October 4, 2026. Prices are USD. Scope: the Flutter app and Firebase functions in `src/robinhood_options_mobile`, with paper trading as the release priority.

## Executive decision

**Intrinio Startup is a credible single-provider candidate for stock/ETF paper trading and basic options practice. It does not cover every existing feature, and the app needs integration work before it can use the data.**

An important correction to the earlier recommendation: Intrinio's current [included-products article](https://help.intrinio.com/what-products-are-included-in-my-intrinio-plan) lists **15-minute delayed options market data** alongside OptionsEdge and options EOD history. Test that bundled entitlement before paying for another options feed. The main pricing plan summary lists delayed stocks but does not explicitly list delayed options; confirm the account's access and commercial display rights rather than assuming either inclusion or exclusion.

Use synthetic prices for clearly labeled estimated practice, or use delayed exchange quotes with the underlying stock on the same delayed timeline. Keep live order pricing and execution with the connected broker. Defer premium news, analyst research, unsupported macro instruments and verified options flow unless their revenue justifies additional data spend.

This is a **static code and public-documentation audit**, not production certification. No authenticated Intrinio calls, entitlement checks, streaming trials or end-to-end app tests were performed. No Intrinio integration was found in the app's `lib` or functions' `src` directories. “Supported” below means the documented data can supply the feature after an adapter and validation; it does not mean the feature works today.

## Feature and cost heatmap

**🟩 Documented core data candidate · 🟨 Conditional, partial or needs verification · 🟥 Additional supplier/product or app/broker capability required.** All rows require integration where Intrinio data is used. Premium prices are not publicly established for our configuration.

| App feature | Startup fit | Data or implementation needed | Cost implication |
| --- | --- | --- | --- |
| Stock quotes and portfolio marks | 🟩 | EquitiesEdge derived prices; label source and freshness | Core subscription |
| ETF quotes and SPY benchmark | 🟨 | Verify launch ETF universe across quote and history feeds; ETF pricing differs from premium ETF holdings data | Core if symbols pass |
| Symbol search and instrument metadata | 🟩 | Security master; map provider IDs and share classes | Core subscription |
| Daily charts and stock backtesting | 🟩 | EOD OHLCV; preserve adjusted/unadjusted meaning | Core subscription |
| Intraday stock charts and indicators | 🟨 | Interval endpoint supports the requested shapes; check source, lookback, session coverage and plan interval access | Core if entitlement passes |
| Stock market/limit/stop/trailing paper orders | 🟨 | Prices available; fill policy, stale-data rejection and calendar remain app work | Core data + engineering |
| Paper P&L, equity history and leaderboards | 🟨 | Fresh marks plus app-owned account calculations; server must refresh option marks too | Core data + engineering |
| Options discovery, expirations and strikes | 🟩 | Contract-list endpoint and paginated Greeks by ticker | Core subscription |
| Options synthetic marks, IV, delta/gamma/theta/vega | 🟩 | OptionsEdge; estimated pricing, not executable quotes | Core subscription |
| Options exchange bid/ask, sizes, volume and OI | 🟨 | Delayed chain endpoint; help center says delayed options included; verify access and rights | Target core subscription; resolve before purchase |
| Long-call/put paper trading | 🟨 | Build currently empty paper chain/quote/history paths; enforce standard contracts initially | Core data + engineering |
| Options intraday price charts and replay | 🟨 | Separate intervals feed exists; Startup entitlement and historical depth unconfirmed; EOD is insufficient | Unconfirmed; quote if excluded |
| Daily options history and EOD research | 🟩 | Options EOD chain/prices; check expired-contract coverage and required dates | Core subscription |
| Break-even, payoff diagrams and spread analysis | 🟨 | App calculations from contract terms and prices; no guaranteed liquidity or broker eligibility | Core inputs + engineering |
| Rho, probability of profit and broker fill-rate estimates | 🟨 | Not supplied by the inspected OptionsEdge schema; hide unavailable values or compute explicitly labeled estimates | Engineering; broker-specific values need broker |
| GEX, call/put walls and OI analytics | 🟨 | Join per-contract Greeks and delayed/EOD OI; ticker totals are insufficient; label timing and model assumptions | Potentially core; validate joins |
| Verified sweeps, blocks and trade-direction flow | 🟥 | Trade-level evidence and relevant trade/UOA entitlement; chain-volume heuristics cannot verify executions | Additional entitlement/quote; defer |
| IV surface, skew and term structure | 🟨 | Sufficient real strike/expiry observations; missing-data fallbacks currently synthesize surfaces | Core inputs + engineering |
| Historical IV rank and earnings IV-crush research | 🟨 | Consistent historical IV series and actual earnings events; premium event/estimate access may be needed | Core history may help; quote gaps |
| Fundamentals, ratios, insider and institutional disclosures | 🟩 | US fundamentals; map tags and distinguish filings from live institutional trading | Core subscription |
| Dividends, splits and account adjustments | 🟨 | History/reference feeds provide inputs; paper service methods are empty and account updates need implementation | Core inputs + engineering |
| Premium ETF holdings, exposures and expense metadata | 🟥 | Specialized ETF product; equity quote coverage does not include fund analytics | Enterprise/custom quote |
| News, analyst ratings/estimates and ESG | 🟥 | Specialized datasets listed outside the core bundle | Enterprise/custom quote or defer |
| Macro regime: VIX, yields, MOVE, DXY and put/call indices | 🟥 | Current macro module needs instruments beyond US stock prices; validate each separately | Other feeds/products; defer for MVP |
| Forex, futures and crypto | 🟥 | Not established by this US stocks/options bundle | Separate coverage; defer for MVP |
| Congress trading and specialized whale research | 🟥 | Existing separate disclosure/data pipelines; fundamentals are not a substitute for every source | Retain separately or defer |
| AI explanations and automated signals | 🟨 | Data inputs only; model runtime and licensed external AI transmission remain separate | Model costs + written usage scope |
| Broker account sync, live orders, cancellations and executions | 🟥 | Broker API, user permissions and commercial approval | Broker arrangement; Intrinio is not an execution service |
| Virtual cash, reset, journal, watchlists, groups and IAP | 🟨 | App/Firestore/store capabilities; no market-data subscription implements these | App work and store costs |

The core-data classification follows [Intrinio's product-to-feed mapping](https://help.intrinio.com/how-products-map-to-data-feeds). Specialized categories follow the [included-products article](https://help.intrinio.com/what-products-are-included-in-my-intrinio-plan). Endpoint existence is not proof of account entitlement.

## API mapping and the important field gaps

| App input | Intrinio API candidate | Adapter requirement |
| --- | --- | --- |
| Stock quote | `GET /securities/{identifier}/prices/realtime` | Normalize last price, timestamp and available quote fields; select the entitled source explicitly |
| Daily stock candles | `GET /securities/{identifier}/prices` | Map candles to existing chart contracts; keep raw prices for fills and consistent adjusted series for returns |
| Intraday stock candles | `GET /securities/{identifier}/prices/intervals` | Map interval/timezone/session, paginate and verify source history |
| Option contract discovery | `GET /options/{symbol}/realtime` | Map code, strike, type, expiry and expiration time; this is a contract list, not a price feed |
| OptionsEdge by underlying | `GET /options/greeks/by_ticker/{identifier}/realtime` | Paginate `contracts`; map `synthetic_price`, IV and four Greeks |
| OptionsEdge by contract | `GET /options/greeks/{contract}/realtime` | Refresh held contracts using stable contract codes |
| Delayed exchange chain | `GET /options/chain/{symbol}/{expiration}/realtime?source=delayed&show_stats=true` | Explicitly choose an entitled underlying source; maintain matching quote times and record OI's as-of date where available |
| EOD options chain | `GET /options/chain/{symbol}/{expiration}/eod?date=YYYY-MM-DD` | Join daily contract prices, OI and Greeks; never present EOD data as a current executable quote |

References: [stock quotes](https://docs.intrinio.com/documentation/web_api/get_security_realtime_price_v2), [stock intervals](https://docs.intrinio.com/documentation/web_api/get_security_interval_prices_v2), [contract discovery](https://docs.intrinio.com/documentation/web_api/get_options_by_symbol_realtime_v2), [OptionsEdge guide](https://intrinio.com/how-to/get-started-with-options-edge), [Greeks by ticker](https://docs.intrinio.com/documentation/web_api/get_options_greeks_by_ticker_v2), [delayed/realtime chain](https://docs.intrinio.com/documentation/web_api/get_options_chain_realtime_v2), [EOD chain](https://docs.intrinio.com/documentation/web_api/get_options_chain_eod_v2).

**OptionsEdge is not a direct replacement for the app's option quote object.** Its inspected Greeks response supplies derived price and analytics, but does not show bid/ask sizes, last execution, volume, OI, rho, probability-of-profit or broker fill-rate estimates. It also does not show a quote-event timestamp in that response. Record retrieval time separately; it cannot prove the market observation is fresh. [Greeks schema](https://docs.intrinio.com/documentation/web_api/get_options_greeks_by_ticker_v2).

The delayed chain is a better fit for spread-aware simulation: it documents bid/ask prices, sizes and timestamps, last trade, volume, OI and optional Greeks. These are top-of-book observations, not a guarantee an order would fill. `show_stats` defaults to false. Neither inspected chain schema establishes adjusted-contract deliverables or a universal multiplier; exclude nonstandard contracts until authoritative terms are available. [Chain schema](https://docs.intrinio.com/documentation/web_api/get_options_chain_realtime_v2).

The EOD chain includes daily prices, bid/ask, OI and Greeks and can support slower analytics. Combining yesterday's OI with current Greeks can support an explicitly dated GEX estimate; it cannot identify actual dealer inventory. [EOD schema](https://docs.intrinio.com/documentation/web_api/get_options_chain_eod_v2).

EquitiesEdge prices are derived rather than consolidated exchange executions. Its own product has no history, but Startup separately bundles historical products. Treat those feeds as distinct sources when combining charts and marks. [EquitiesEdge](https://intrinio.com/financial-market-data/equitiesedge).

## Code findings that affect release readiness

| Evidence in repository | Finding and required change |
| --- | --- |
| [PaperService](../../src/robinhood_options_mobile/lib/services/paper_service.dart), lines 441–529 | Option instrument stream returns an empty list; chain lookup returns empty/mock data; quote reads use Firestore. Implement provider-backed discovery and refresh; existing stored broker-shaped data is not an Intrinio integration. |
| Same service, lines 568–650 and 902 onward | Quotes use Fidelity/Yahoo, fundamentals use Yahoo and stock history uses Yahoo. Replace these frontend paths as well as backend data fetching. |
| Same service, line 872 | Option historicals return no candles. Shipping intraday charts requires both an entitled feed and implementation. |
| Same service, lines 960–1009 and 1090–1128 | Several dividend/news/earnings methods return empty results; paper brokerage-list methods are empty or throw. Trace each MVP screen's actual path; group watchlist services do not establish paper brokerage-list readiness. |
| Same service, lines 1441 and 1513 | Order submission can fall back from an observed mark to the supplied order price. Require a separately fetched valid quote; a customer's limit price is not market evidence. |
| [OptionMarketData](../../src/robinhood_options_mobile/lib/model/option_marketdata.dart), lines 115 onward | JSON parser expects broker-shaped fields and assigns several nonnullable integers/strings directly. Passing Intrinio JSON through unchanged can fail. Normalize unavailable fields and update UI semantics; never invent bid/ask or OI to satisfy the parser. |
| [Option instrument UI](../../src/robinhood_options_mobile/lib/widgets/option_instrument_widget.dart), lines 640–771 | Spread/volume/OI displays depend on fields absent from the inspected OptionsEdge response. Disable unsupported metrics for synthetic-only mode. |
| [Paper trading store](../../src/robinhood_options_mobile/lib/model/paper_trading_store.dart), lines 131, 1301 and 2150 onward | Fills evaluate one scalar price; multiplier is hardcoded to 100. Expired long options cash-settle intrinsic value using a later refresh's underlying price, while short positions have assignment logic. Define educational settlement rules and use an appropriate expiry-time price; this is not complete physical-delivery simulation. |
| [Paper cron](../../src/robinhood_options_mobile/functions/src/paper-trading-cron.ts), lines 19–83 and 127–189 | Daily marks fetch stock symbols; resting stock orders evaluate every ten minutes. Options remain client-evaluated. Add server contract refresh/valuation if paper accounts must remain accurate while the app is closed. |
| [Paper valuation](../../src/robinhood_options_mobile/functions/src/paper-trading-utils.ts), lines 9–29 and 100 onward | Calendar excludes weekends but not exchange holidays; option valuation reads saved marks or entry prices. Add freshness rules, holidays/half-days and explicit unavailable-mark behavior. |
| [Backend market data](../../src/robinhood_options_mobile/functions/src/market-data.ts) and [benchmark parsing](../../src/robinhood_options_mobile/lib/services/portfolio_benchmark_service.dart) | Provider-specific symbol mapping and Yahoo-shaped chart consumers require normalization. Replacing one URL is insufficient. |
| [GEX](../../src/robinhood_options_mobile/functions/src/gamma-exposure.ts) and [options flow](../../src/robinhood_options_mobile/functions/src/options-flow-utils.ts) | GEX needs per-contract OI; flow uses chain statistics and bid/ask heuristics. Neither ticker-level aggregates nor synthetic marks can verify sweeps/blocks. |
| [IV surface](../../src/robinhood_options_mobile/lib/services/iv_surface_service.dart), lines 40–43 and 287 onward; [earnings analysis](../../src/robinhood_options_mobile/lib/services/earnings_iv_crush_service.dart), lines 168 onward | Missing observations produce assumed IV/surfaces and synthesized historical quarters. Preserve explicit model/demo labels or suppress results; subscribing does not make these outputs empirical. |
| [Macro agent](../../src/robinhood_options_mobile/functions/src/macro-agent.ts), lines 277–375; [futures service](../../src/robinhood_options_mobile/lib/services/futures_market_data_service.dart), line 111 | Existing consumers require indices, futures and other instruments beyond the proposed US stock/options MVP. Keep these outside the migration scope or provide separately licensed coverage. |

## Small-startup rollout and budget

| Stage | Recommendation | Data budget |
| --- | --- | --- |
| Stock/ETF paper MVP | Retain the stock-only recommendation while validating the cheapest licensed stock feed. Intrinio becomes attractive if reducing provider integrations is worth the higher baseline. | Intrinio alternative: $333/month initially |
| Add basic options paper | Trial Startup's synthetic and included delayed options feeds. Prefer delayed spreads for a coherent delayed simulation; synthetic mode remains an estimated-price experience. Start with standard long calls/puts. | Same Startup subscription if entitlements pass |
| Improve options analytics | Reuse verified delayed/EOD OI and Greeks before purchasing another feed. Defer verified flow and unsupported intraday replay. | No assumed add-on; quote only identified gaps |
| Live stock/ETF, then live options | Broker handles account eligibility, order quotes, execution and reconciliation. Intrinio remains research/paper data. | Research subscription + separately confirmed broker costs |

Startup is advertised at **$333/month for six months, $666/month for the next six, then $999/month**, billed quarterly. That is **$999**, then **$1,998**, then **$2,997** per three-month period; first-year subscription cost is **$5,994**. Timing follows subscription age, not releases. [Current pricing](https://intrinio.com/pricing).

Optimize consumption through a backend cache shared across users, batching where available, active-symbol subscriptions and on-demand chain slices. As a planning example, polling 200 symbols once per minute across a 390-minute session produces 78,000 requests per day before histories or options pagination. This is workload arithmetic, not a statement of Startup's quota. Verify actual request and WebSocket limits before committing.

Commercial in-app display is supported by Startup, while raw-data resale/export is restricted. The app's external AI calls need the applicable rights: the terms explicitly address transmission to third-party model providers. Confirm the executed order's scope for Gemini, caching and user exports, rather than relying on general AI marketing. [Licensing guidance](https://help.intrinio.com/licensing-data-usage-requirements), [terms, sections 2.2–2.4](https://data.intrinio.com/terms).

## Acceptance checks before we call the provider sufficient

1. **Entitlements and cost:** check account access for equities, security master, EOD stocks/options, delayed options, stock intervals and streaming. Obtain written scope for commercial display and AI usage, quotas and any additional fees. Resolve the delayed-options difference between the help center and pricing summary.
2. **Universe:** verify AAPL, MSFT, a share-class symbol such as BRK.B, SPY, QQQ and IWM plus the actual launch watchlist. Test ETF quotes/history separately from premium fund analytics, and an unsupported/delisted symbol.
3. **Options:** fetch standard calls and puts across weekly/monthly expiries; exhaust pagination; join contract codes across synthetic, delayed and EOD sources. Check missing quotes, zero bids, illiquid contracts, expiration times and Greek units. Exclude adjusted contracts until deliverables are known.
4. **Timing:** observe market-open, closed and reconnect behavior; verify quote-event timestamps, delay, staleness and compatible underlying prices. Never join a current underlying with a delayed option to imply a coherent executable quote. Define order activation on the delayed timeline so pre-order market observations cannot fill a newly submitted order.
5. **History:** verify required date depth and each chart interval, including the app's five-minute views; check session boundaries, splits/dividends and expired-contract history. Hide any view whose source does not pass.
6. **App integration:** exercise discovery, charting, orders, cash reservation, partial position closes, P&L and expiry through the paper adapter. Validate stale/missing-data rejection, server/client agreement and closed-app account updates.
7. **Capacity:** measure REST usage, chain pagination and streaming subscriptions under the planned beta load; test throttling, outage and reconnect handling without silently switching data semantics.

Until these pass, the purchasing decision is **conditional approval for the scoped paper MVP**, not confirmation of every feature in the repository. See the [executive release heatmap](stock-and-options-provider-recommendation.md) for release scope and IAP proposals.
