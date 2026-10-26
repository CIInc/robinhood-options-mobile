# PRODUCT.md — RealizeAlpha Product Overview & Principles

**RealizeAlpha** (`robinhood-options-mobile`) is a multi-account mobile investing, options analytics, and agentic trading platform built with Flutter and Firebase. It connects self-directed investors and quantitative traders with institutional-grade portfolio analytics, derivatives risk modeling, multi-indicator trade signals, and safety-first automation across Robinhood, Charles Schwab, Fidelity (CSV), and Paper Trading accounts.

---

## 1. Product Purpose & Vision

Retail and semi-professional traders often manage fragmented accounts (taxable brokerage, Traditional/Roth IRAs, futures, crypto/forex) without unified risk visibility, tax-lot coordination, or disciplined execution guardrails. RealizeAlpha bridges that gap by combining:

1. **Unified Multi-Account Portfolio Intelligence:** Real-time aggregation, progressive disclosure, benchmark-relative performance attribution, and cross-account tax optimization.
2. **Institutional Derivatives & Quantitative Research:** On-device and cloud-backed Gamma Exposure (GEX), 3D Implied Volatility surfaces, 0DTE squeeze radar, options flow smart flags, event studies, and multi-regime strategy backtesting.
3. **Disciplined, Human-Centered Automation & AI Coaching:** A 19-indicator signal correlation engine, autonomous/semi-autonomous agentic trading with 5-tier GEX sequential exits, adversarial thesis stress-testing (AI Devil's Advocate), post-trade behavioral diagnostics, and hard account risk circuit breakers.

---

## 2. Core Product Principles

1. **Progressive Disclosure & Actionable Clarity**
   - Answer *"What happened?"* and *"What needs my attention?"* first. The Portfolio tab leads with hero metrics, a prioritized **Action Center** (`PortfolioAlertService`), and top movers, while deep analytical tools live in six dedicated drill-down sections (`Performance`, `Positions`, `Risk`, `Insights`, `Taxes`, `Strategies`) backed by a single shared `PortfolioAnalyticsController`.

2. **Safety, Explicit Consent & Capital Protection First**
   - Automation never bypasses risk controls. Auto-trading enforces live-quote price validation ($\le 3\%$ deviation), explicit fixed vs. dynamic position sizing, `RiskGuard` portfolio concentration checks, and a 5-tier sequential stop queue.
   - Manual and copied trades are protected by `RiskCircuitBreakerService` (daily loss limits, drawdown locks, behavioral tilt cooling-off periods), `CopyTradeRiskGuardianService` (allocation clamping, slippage aborts, leader drawdown auto-disconnect), and pre-trade pin/assignment/wash-sale warnings.
   - High-risk or experimental capabilities are partitioned behind a 4-tier **Feature Access & Beta Labs** gate (`FeatureAccessService`) with remote kill switches and explicit safety disclaimers.

3. **Provenance, Freshness & Descriptive Non-Advisory Behavior**
   - Every quantitative metric, trade signal, AI critique, and regulatory disclosure (SEC EDGAR 13F/Form 4/8-K/10-K, Congressional STOCK Act filings, Whale Watch institutional snapshots) must surface its **data source, calculation timestamp, staleness/cache status, and approximation assumptions**.
   - Model outputs and AI insights are descriptive analytical tools and adversarial critiques—never unverified promises of return or personalized fiduciary/tax/legal advice.

4. **Privacy-First Multi-Account & Social Architecture**
   - Brokerage and MCP OAuth tokens are encrypted in platform hardware/keychain storage (`SecureTokenStorage`).
   - Sensitive dollar balances, P&L, and chart axes/tooltips can be masked globally with 1 tap (`AccountStore` balance visibility toggle) and in public social profiles (`$***`).
   - Cross-account tax and wash-sale detection executes locally in Dart over hydrated account stores without exposing raw multi-broker tax lots to shared cloud collections.

5. **Mobile Performance & Battery Discipline**
   - Complex quantitative workloads (19-indicator evaluations, Black-Scholes GEX fallbacks, Dupire local volatility surfaces, multi-symbol backtests) must run within strict CPU, memory ($O(1)$ scalar indicator passes), and battery budgets using lazy sliver rendering and viewport-aware WebSocket streaming.

---

## 3. Target Personas

- **The Options Strategist:** Trades covered calls, cash-secured puts, vertical spreads, iron condors, and 0DTE contracts; relies on the Options Strategy Roll Assistant, Multi-Leg Defense Playbook, Pin/Assignment Guard, GEX levels, and IV cones/surfaces.
- **The Multi-Account Portfolio Manager:** Holds taxable and IRA accounts across Robinhood, Schwab, and Fidelity; relies on Multi-Account Aggregation, Cross-Account Wash Sale & Tax-Loss Harvesting guardrails, Retirement Match Maximizer, and Rebalancing.
- **The Systematic / Quant Trader:** Builds and validates multi-indicator templates in the Backtesting Engine and Alpha Factor Discovery before deploying them to Paper Trading or live Stocks/Futures Auto-Trading.
- **The Collaborative Group Investor:** Shares trade theses, watchlists, and verified track records in Investor Groups 2.0, or follows top-ranked leaders with Copy-Trading Risk Guardian protections.

---

## 4. Product Pillars & Capability Map

| Pillar | Key Capabilities | Primary Code & Docs |
| :--- | :--- | :--- |
| **Portfolio, Risk & Taxes** | Progressive Portfolio, Action Center, Stress Testing, Tail Risk/VaR, Beta-Weighted Greeks, Rebalancing, Wash Sale & Tax-Loss Harvesting, Form 8949 Export, Retirement & Gold Match | `lib/widgets/portfolio/`, `lib/services/tax_optimization_service.dart`, [`docs/portfolio-redesign.md`](docs/portfolio-redesign.md), [`docs/tax-loss-harvesting.md`](docs/tax-loss-harvesting.md) |
| **Options, Futures & Forex** | Option Chain Screener, Multi-Leg Spread Builder, Roll Assistant, Defense Playbook, Pin/Early-Assignment Guard, GEX Pro, 3D IV Surface, Futures Order Entry & Auto-Trading, Forex & Carry Trade Optimizer | `lib/widgets/option_roll_assistant_widget.dart`, `lib/widgets/gamma_exposure_widget.dart`, [`docs/gamma-exposure-analysis.md`](docs/gamma-exposure-analysis.md), [`docs/futures.md`](docs/futures.md) |
| **Signals, Backtesting & Agentic Trading** | 19-Indicator Correlation Engine, 15m/1h/1d Signals, Macro Assessment (19-indicator regime score), 5-Tier GEX Exit Queue, Paper Trading Simulator, Walk-Forward Backtesting | `lib/model/agentic_trading_provider.dart`, `functions/src/technical-indicators.ts`, [`docs/agentic-trading.md`](docs/agentic-trading.md), [`docs/backtesting.md`](docs/backtesting.md) |
| **AI Copilot, Coaching & MCP** | AI Devil's Advocate (Thesis Stress Tester), Autonomous Agentic Risk Copilot, AI Trade Post-Mortem, Trading Psychology & Emotion Journal, Local MCP Client (`package:mcp_dart`) | `lib/widgets/devils_advocate_widget.dart`, `lib/widgets/risk_copilot_widget.dart`, [`docs/devils-advocate.md`](docs/devils-advocate.md), [`docs/mcp-integration.md`](docs/mcp-integration.md) |
| **Market Intelligence & Filings** | SEC EDGAR (13F, Form 4, 8-K, 10-K/10-Q), Congress Trading Tracker, Whale Watch, Robinhood Short Interest/Borrow, Retail Order Flow, News Intelligence & Event Study Analyzer | `functions/src/sec-edgar.ts`, `functions/src/congress-trading.ts`, [`docs/sec-edgar-integration.md`](docs/sec-edgar-integration.md), [`docs/congress-trading-tracker.md`](docs/congress-trading-tracker.md) |
| **Social & Copy Trading** | Investor Groups 2.0, Group Chat & Watchlists, Shared Analysis Boards, Verified Track Records, Trader Comparison, Copy-Trading Risk Guardian & Slippage Analytics | `lib/model/investor_group_store.dart`, `lib/services/copy_trade_risk_guardian_service.dart`, [`docs/investor-groups-2.md`](docs/investor-groups-2.md), [`docs/copy-trading.md`](docs/copy-trading.md) |

---

## 5. Strategic Scope Boundaries & Non-Goals

When evaluating or proposing new roadmap candidates (see [`ROADMAP.md`](ROADMAP.md)):
- **Prioritize reliability, analytical accuracy, and risk transparency** over speculative breadth.
- **Avoid regulatory or platform anti-patterns:** Features requiring investment-adviser/broker-dealer licensing (e.g., paid strategy marketplace royalties), intrusive OS health permissions with high false-positive rates (e.g., HealthKit heart-rate tilt triggers), or unauthenticated server-side credential pooling are intentionally demoted to exploratory horizons.
- **Require testable, modular deliverables:** Every roadmap candidate should map to clear user value, verifiable data sources, explicit safety/privacy guardrails, and focused unit/widget test coverage.
