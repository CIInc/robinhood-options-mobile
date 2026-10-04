# Executive recommendation: paper trading to live trading

Reviewed October 4, 2026. All prices are USD.

## Recommended direction

**Launch stock/ETF paper trading first. Add options practice when customers demonstrate demand. Introduce live trading through one approved broker, starting with stocks and then options.**

Use Twelve Data for the first release if its smallest commercial plan meets our needs. Evaluate Intrinio when adding options; replace the first feed where practical rather than paying for both. For live trading, use each connected customer's entitled broker data. A costly company-wide live feed is not a prerequisite for this path.

Keep the product simple: **Free, Plus and Pro**. Sell better practice and analysis tools through subscriptions. Keep basic account access, order status and cancellation available without a premium subscription.

## Release heatmap

**🟩 Include · 🟨 Limited or conditional · ⬜ Defer.** This is the proposed scope, not a statement that every feature is ready today.

| Feature / cost | R1: stock/ETF paper MVP | R2: add options paper | R3: live stock/ETF beta | R4: add live options |
| --- | --- | --- | --- | --- |
| Virtual cash, guest account and reset | 🟩 | 🟩 | 🟩 Paper remains | 🟩 Paper remains |
| Stock/ETF paper orders and P&L | 🟩 | 🟩 | 🟩 | 🟩 |
| Watchlists, charts and trade history | 🟩 | 🟩 | 🟩 | 🟩 |
| Options paper trading | ⬜ | 🟨 Long calls/puts first | 🟨 Estimated fills | 🟨 Estimated fills |
| Options contract selection and Greeks | ⬜ | 🟨 Validate provider coverage | 🟨 Same paper scope | 🟨 Broker data for eligible users |
| Realistic paper spreads and liquidity | 🟨 Simplified fills | 🟨 Model-based fills | 🟨 Separate feed upgrade | 🟨 Separate feed upgrade |
| Approved broker connection | ⬜ | ⬜ | 🟩 One broker | 🟩 Same broker |
| Live stock/ETF orders | ⬜ | ⬜ | 🟩 User-confirmed | 🟩 |
| Live option orders | ⬜ | ⬜ | ⬜ | 🟨 Eligible accounts, basic orders |
| Short options and multi-leg spreads | ⬜ | ⬜ | ⬜ | ⬜ Later release |
| Options flow, GEX and automated trading | ⬜ | ⬜ | ⬜ | ⬜ Later release |
| Preferred research-data supplier | Twelve Data Venture | Evaluate Intrinio Startup | Retain research feed + broker | Retain research feed + broker |
| Company data subscription | **From $149/month**, configuration pending | **$333 → $666 → $999/month** | **Research baseline + quoted broker costs** | **Research baseline + broker/entitlement costs** |
| Recommended in-app purchase | **Plus: $4.99/month** | **Pro: $9.99/month** | **Keep Plus/Pro prices** | **Keep Plus/Pro prices** |

Published data prices: [Twelve Data business plans](https://twelvedata.com/pricing-business), [Intrinio plans](https://intrinio.com/pricing). Twelve Data also displays a larger $499/month configuration; $149 is an advertised starting price, not a confirmed total. Intrinio rises after six and twelve subscription months, regardless of our release schedule. Its first subscription year totals **$5,994**, then **$11,988/year**. Broker costs require a quote. Taxes, hosting, development and additional licensing are excluded.

## In-app purchase recommendation by release

The prices and feature packages below are **proposals to test**, not existing store configurations. Keep one subscription per customer: Pro includes Plus, and upgrades replace the lower tier rather than adding a second charge.

| Release | Free experience | Paid package | Proposed price | Business objective |
| --- | --- | --- | --- | --- |
| **R1** | One paper portfolio, basic stock/ETF practice, charts, history and a small watchlist | **Plus:** additional practice portfolios, larger watchlists, trade journal and performance breakdowns | **$4.99/month**; add **$39.99/year** after retention is demonstrated | Prove users return and will pay for better practice tools |
| **R2** | Retain free stock practice; offer a limited options demo | **Pro:** full supported options practice, Greeks explanations and strategy/performance review; includes Plus | **$9.99/month**; later **$79.99/year** | Fund options data with a clear educational premium |
| **R3** | Approved broker connection, basic live account access and manual stock orders | Keep Plus/Pro; extend paid journal and performance tools to live accounts | **Same prices** | Improve retention without making connection itself the paywall |
| **R4** | Basic manual options trading for broker-approved accounts | Pro adds supported options learning and portfolio review tools across paper/live | **Same prices initially** | Grow Pro adoption before adding more tiers or fees |

Only sell features that have shipped and whose data usage is licensed. Keep basic quote checks needed for orders, order status, cancellation and existing positions accessible after a subscription expires. Preserve user trade history on downgrade; restrict new premium activity rather than deleting records.

Start with monthly subscriptions. Add annual plans after retention and renewal costs are understood. Use a limited demo before testing a clearly disclosed store-managed trial. Avoid lifetime purchases, paid virtual-cash top-ups and per-trade app charges: they complicate a product with recurring data costs.

Use Apple/Google billing for the proposed paid digital tools, subject to applicable storefront rules. Broker deposits, securities transactions and brokerage fees remain separate. Confirm the live-app distribution arrangement with the broker before release; Apple's financial-trading rules apply in addition to its subscription rules. [Apple review guidelines, sections 3.1 and 3.2.1(viii)](https://developer.apple.com/app-store/review/guidelines/), [Google Play payment guidance](https://support.google.com/googleplay/android-developer/answer/10281818?hl=en).

## What we give up to keep costs low

| Decision | Tradeoff | When to upgrade |
| --- | --- | --- |
| Basic stock feed | Prices may cover part of the market; fills are estimates | Customers need more realistic trading practice |
| Synthetic options prices | Do not reproduce actual spreads or available liquidity | Paid demand supports a quoted delayed exchange feed |
| One live broker | Customers must use the supported broker and have required permissions | Demand justifies a second integration |
| Defer advanced analytics | No verified sweeps, market-wide GEX or autonomous trading at launch | A specific paid feature can fund its data and support costs |

If realistic options simulation becomes essential, request a focused delayed exchange-data quote before buying a broad live stack. Keep all simulated prices and fills on the same market timeline. Live broker quotes do not automatically improve paper data for unrelated users.

## When to move to the next release

| Transition | Executive release gate |
| --- | --- |
| **Launch R1** | Licensed data, reliable cash/P&L, sensible fills, working purchase/restore flow and returning beta users |
| **R1 → R2** | Customers request options; paid demand supports the recurring cost; contract and expiration behavior are validated |
| **R2 → R3** | Broker commercial access and store distribution are approved; account connection and order reconciliation are reliable |
| **R3 → R4** | Live stock beta is stable; options permissions, pricing, lifecycle and order handling pass validation |

Use demand and readiness gates rather than fixed launch dates. Live trading uses real broker balances and executions; paper balances remain virtual. Switching to live requires a separate, freshly reviewed order—paper holdings never transfer automatically.

## Subscription economics

For planning only, assume **30% of the subscription price is withheld for store fees**. This is a conservative scenario, not a statement of our actual fee rate. The following covers the data subscription alone, excluding taxes, refunds, hosting, support and development; annual discounts reduce monthly revenue further.

| Monthly data expense | Subscription used in example | Paying monthly subscribers needed |
| --- | --- | ---: |
| $149 | Plus at $4.99 | **43** |
| $333 | Pro at $9.99 | **48** |
| $666 | Pro at $9.99 | **96** |
| $999 | Pro at $9.99 | **143** |

Aim for revenue above these thresholds before committing to higher recurring spend. The examples do not predict conversion or prove profitability.

## Delivery notes

The app currently has one monthly product, `trade_signals_monthly`, with backend receipt verification. Plus/Pro and annual plans require new store products, entitlement mapping and verification support; they are not configuration-only changes. Validate upgrades, restores, expiration, refunds and access after downgrade. See the [subscription service](../../src/robinhood_options_mobile/lib/services/subscription_service.dart) and [backend verification](../../src/robinhood_options_mobile/functions/src/subscriptions.ts).

Research display, backend processing, external AI and market-data exports need the appropriate rights. Purchase entitlement does not replace data licensing or broker approval. Provider capabilities and costs remain subject to a written quote and pilot.

Detailed provider evidence and technical considerations are retained in [supporting research](supporting-market-data-research.md). The [stocks-only MVP brief](stocks-only-paper-trading-mvp-recommendation.md) provides additional R1 detail. No subscriptions, store products or app behavior were changed by this document.
