# Portfolio Redesign

Reorganizes the Portfolio experience around how traders think — *what happened?
→ why? → what should I do? → dive deeper* — instead of around the shape of the
data model. No analytics were removed; everything moved.

## The problem

The Portfolio page rendered ~37 cards in one scroll: 20 slivers in
`home_widget.dart` plus 17 more inside `PortfolioAnalyticsWidget`. Related
concepts were spread apart (Performance, Portfolio Health, Risk Adjusted Return,
Market Comparison, Risk Metrics, and Advanced Edge were six separate cards), and
three AI entry points sat at three different scroll depths. The heatmap, one of
the most legible visualizations in the app, was near the bottom.

## Information architecture

```
Portfolio (nav tab)
├── Overview          ← the only page in the tab
│   ├── Hero          portfolio value, chart, vs SPY / buying power / cash %
│   ├── Action Center ranked alerts — "what should I do today?"
│   ├── Movers        today's largest contributors and detractors
│   ├── Holdings      one summary card per asset class → its own full ledger
│   └── Browse grid   six tiles, each with a live summary value
├── Positions         movers · heatmap · allocation
├── Performance       analytics suite · benchmarks · monthly returns · income
├── Risk              concentration score · heatmap · correlation matrix
├── Insights          market assistant · AI trading coach
├── Taxes             loss harvesting (TaxOptimizationWidget)
└── Strategies        agentic · futures auto · options flow · portfolio GEX · rebalance · paper
```

## Progressive disclosure

Three tiers, enforced by `MetricDisclosureCard`:

1. **Headline** — one number and a qualitative status ("64", "Moderate Risk").
2. **Tiles** — up to three supporting figures.
3. **Advanced** — the full quantitative battery, collapsed by default.

The advanced tier is built **only while expanded**, so a collapsed card never
pays to construct the charts and matrices inside it. `initiallyExpanded` is the
hook for a future experience-level preference, letting advanced users skip the
tap without a second code path.

`PortfolioRiskSummaryWidget` is the reference implementation: it leads with a
0-100 concentration score derived from HHI and hides the top-N weights and the
index itself behind the disclosure.

## Holdings on the overview

The first cut pushed every position list into the Positions section, which put
that section back to the long scroll the redesign existed to remove — the
ledgers are the one part of the app whose height grows with the account.

The overview now carries a *summary* per asset class instead: title, total
market value, the return strip, and a bar chart, via `showList: false` on the
existing `InstrumentPositionsWidget` / `OptionPositionsWidget` /
`FuturesPositionsWidget` / `ForexPositionsWidget`. The chevron each grows in
that mode opens `*PositionsPageWidget`, the per-asset-class full ledger those
widgets have always had. The overview's length is therefore bounded by the
number of asset classes, not the number of positions.

The charts size themselves at 26px a row, so a large account could still make
one summary taller than the screen. `chartRowLimit` caps the bars — 8 from the
overview — and the header says `charting top 8` so the missing bars do not read
as missing positions. The cap keeps the user's own sort rather than imposing
"largest first": it takes the first rows of the list they asked for.

`navigateToFullPage` deliberately skips `_handleNavigation`. Reading a position
list is not a trade action, and gating it would leave aggregate-mode users with
no way to see the holdings the cap hides. `disableNavigation` is forwarded to
the page instead, so the trade-bearing rows inside it stay disabled.

## Action Center

`PortfolioAlertService` is a rules engine producing `PortfolioAlert` values —
data, not widgets, so the overview can rank, cap, and summarize them. Rules
degrade independently: those needing computed analytics are skipped when the
metrics have not been calculated, so the overview renders from the position
stores alone on first paint.

| Rule | Source | Severity |
|---|---|---|
| Tax-loss opportunities | `TaxOptimizationService` | critical in season, else warning |
| Concentration | position weights | critical >30%, warning >20% |
| High cash | account cash / equity | info >30% |
| Largest daily mover | position day P/L | positive or warning, >5% move |
| Benchmark delta | `PortfolioBenchmarkService` | warning when trailing >2% |
| Drawdown | analytics metrics | critical >20% |
| Volatility vs benchmark | analytics metrics | warning at 1.5× |

Alerts sort most-severe-first and route through `PortfolioNavigator`, which is
also what the Browse grid uses — so a tapped alert and a tapped tile always land
on the same screen.

## Benchmark on first paint

The full analytics suite only runs when the user opens Performance, but the hero
needs "vs SPY" immediately. `PortfolioBenchmarkService` does the minimum work:
align the portfolio and index series on trading days, take each one's
first-to-last cumulative return. That figure feeds both the hero stat strip and
the benchmark alert rule.

## The analytics controller

`PortfolioAnalyticsWidget` was a 5,099-line `StatefulWidget` that owned both the
metric computation and seventeen cards. It is gone, replaced by
`PortfolioAnalyticsController` — a `ChangeNotifier` created once by the Portfolio
page and passed to the sections through `PortfolioSectionContext`.

```
PortfolioAnalyticsController
├── ensureLoaded()      first section to open pays; the rest read the cache
├── updateInputs()      new historicals/period → recompute in place
├── refresh()           forces a recompute
├── selectBenchmark()   recomputes against the new index
├── addCustomBenchmark()
└── loadEsg(positions)  separate, since ESG depends on holdings not historicals
```

Sections read it through a `ListenableBuilder`, so Performance, Risk, Insights,
and Taxes all show the same numbers without four computations.

### One instance, mutable inputs

The controller lives for the whole Portfolio page and only its *inputs* are
replaced. This matters because the sections are **pushed routes**: each captured
its `PortfolioSectionContext` when it opened. Swapping the controller instance
on a period change would dispose the notifier a visible Performance or Risk page
is listening to — stranding it on stale numbers and throwing on the next notify.
Changing the period from those very pages is what triggers it, so the failure
mode lands exactly where it is least acceptable.

The same reasoning applies to the selected period. `controller.span` is the
source of truth; `PortfolioSectionContext.benchmarkChartDateSpanFilter` is only
a first-frame fallback, because the copy captured at push time goes stale the
moment the user taps a different period.

`metrics` gains `benchmarkSymbol`, `periodDays`, `excessReturn`,
`excessReturnHistory`, `monthlyReturns`, and the three aligned series the CSV
export needs, on top of everything `AnalyticsUtils.calculatePortfolioMetrics`
produces.

## One period, both pages

Performance and Risk share the controller, and `controller.span` is already the
single source of truth — but the period chips only rendered on Performance. Risk
therefore showed volatility, max drawdown, beta and Sharpe computed over a window
its reader could neither see nor change. Beta and correlation depend on the
benchmark the same way, and that picker was also Performance-only.

Both controls now live in the section scaffold's `bottom` slot and app-bar
`actions` on *both* pages: `AnalyticsPeriodBar` for the period, and
`BenchmarkMenuButton` — a menu rather than a second chip row, since the
benchmark changes far less often. Changing either from Risk runs the same path
as changing it from Performance: `onBenchmarkFilterChanged` reloads the
historicals, `_refreshAnalyticsController` calls `updateInputs`, and every
listening section rebuilds on the one recomputation.

`AnalyticsPeriodBar.preferredSize` collapses to zero height when no period is
known yet, so a section opened before the historicals resolve does not reserve a
strip the chips never fill.

## Risk consolidation

Four sibling cards — Risk Metrics, Risk-Adjusted Return, Market Comparison, and
Advanced Edge — showed eighteen numbers with no ordering. `RiskAnalyticsCard`
replaces them with one score and keeps all eighteen, grouped as before, behind
the disclosure.

The score is deliberately simple and inspectable, blending the three quantities
a non-specialist can reason about:

| Component | Weight | Ceiling |
|---|---|---|
| Volatility | 40 | 40% annualized |
| Max drawdown | 40 | 50% |
| Beta deviation from 1.0 | 20 | ±1.0 |

Bands are <33 Low, <66 Moderate, else High. The result is rescaled by the
weights actually present, so a portfolio missing a component is not scored as
low-risk by omission.

## Files

| File | Role |
|---|---|
| `model/portfolio_alert.dart` | Alert value type, severity, routing target |
| `model/portfolio_analytics_controller.dart` | Metric computation, shared |
| `services/portfolio_alert_service.dart` | Alert rules engine |
| `services/portfolio_benchmark_service.dart` | Lightweight vs-benchmark return |
| `widgets/portfolio/portfolio_section.dart` | The six sections and their metadata |
| `widgets/portfolio/portfolio_section_context.dart` | Shared dependency bundle |
| `widgets/portfolio/portfolio_section_scaffold.dart` | Common page shell |
| `widgets/portfolio/portfolio_navigator.dart` | Single routing table |
| `widgets/portfolio/metric_disclosure_card.dart` | Progressive-disclosure primitive |
| `widgets/portfolio/action_center_widget.dart` | Ranked alert feed |
| `widgets/portfolio/portfolio_hero_stats_widget.dart` | Hero stat strip |
| `widgets/portfolio/portfolio_movers_widget.dart` | Winners / losers |
| `widgets/portfolio/portfolio_section_grid_widget.dart` | Browse grid |
| `widgets/portfolio_gex_dashboard_widget.dart` | Holdings-only aggregate GEX, regime breadth, concentration, and symbol drill-downs |
| `widgets/portfolio/portfolio_risk_summary_widget.dart` | Concentration score |
| `widgets/portfolio/*_section_page.dart` | The six section pages |
| `widgets/portfolio/analytics/metric_presentation.dart` | Stat tiles, definitions, explainer dialogs |
| `widgets/portfolio/analytics/risk_analytics_card.dart` | Risk score + the eighteen metrics |
| `widgets/portfolio/analytics/performance_overview_card.dart` | Cumulative return, benchmark bars, excess curve |
| `widgets/portfolio/analytics/monthly_returns_card.dart` | Calendar of monthly returns |
| `widgets/portfolio/analytics/daily_stats_card.dart` | Win rate, profit factor, streaks |
| `widgets/portfolio/analytics/ai_insights_card.dart` | Prioritized observations + AI handoff |
| `widgets/portfolio/analytics/portfolio_health_card.dart` | Health-score breakdown dialog |
| `widgets/portfolio/analytics/esg_card.dart` | ESG roll-up |
| `widgets/portfolio/analytics/analytics_filter_bar.dart` | Shared period chips + benchmark menu |
| `widgets/portfolio/analytics/analytics_csv_export.dart` | CSV export |

## Gotcha: date alignment

The controller keys the portfolio and benchmark series by calendar date.
Robinhood `begins_at` values parse as UTC, while Yahoo timestamps deserialize to
local time via `DateTime.fromMillisecondsSinceEpoch`. Real data carries
market-hours timestamps so the two agree, but a fixture built at midnight UTC
will silently misalign by one day in any timezone behind UTC — which is why the
controller tests use local mid-day timestamps.
