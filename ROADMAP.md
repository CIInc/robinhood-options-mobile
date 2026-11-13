# Roadmap

This document outlines the planned features, enhancements, and delivery milestones for RealizeAlpha.

## Table of Contents

- [Summary](#summary)
- [Release Cadence & Milestone Overview](#release-cadence--milestone-overview)
- [Planned Enhancements 🚀](#planned-enhancements-)
  - [v0.60.x Close-Out: Platform & Execution Acceptance](#v060x-close-out-platform--execution-acceptance)
  - [v0.61.0: Advanced Derivatives, Walk-Forward Validation & Smart Order Routing](#v0610-advanced-derivatives-walk-forward-validation--smart-order-routing)
  - [v0.62.0+: Multi-Broker Expansion, Quant APIs & Workspace Scaling](#v0620-multi-broker-expansion-quant-apis--workspace-scaling)
  - [Active Risk Register & Safeguards](#active-risk-register--safeguards)
- [Completed Features ✅](#completed-features-)
  - [Portfolio Intelligence, Greeks & Tax Optimization](#portfolio-intelligence-greeks--tax-optimization)
  - [Trading Execution & Order Routing](#trading-execution--order-routing)
  - [Trade Signals & Agentic Trading](#trade-signals--agentic-trading)
  - [Derivatives, Quantitative Research & Backtesting](#derivatives-quantitative-research--backtesting)
  - [Copy Trading & Risk Guardian](#copy-trading--risk-guardian)
  - [Investor Groups & Social Platform](#investor-groups--social-platform)
  - [Market Intelligence, SEC EDGAR & Filings](#market-intelligence-sec-edgar--filings)
  - [Brokerage & Multi-Account Infrastructure](#brokerage--multi-account-infrastructure)
  - [Notifications & Multi-Channel Alerts](#notifications--multi-channel-alerts)
  - [Cash Management, Banking & Retirement](#cash-management-banking--retirement)
  - [Performance, Battery & Security Architecture](#performance-battery--security-architecture)
- [Feedback & Contribution](#feedback--contribution)

---

## Summary

**RealizeAlpha** is a professional-grade mobile trading and analytics platform designed for multi-account investing, quantitative derivatives risk modeling, and safety-first automated execution. This roadmap outlines current development priorities, upcoming release milestones, and completed platform capabilities.

**Last reviewed:** November 13, 2026 · **Current app version:** 0.61.4 (pre-release)

### Quick Stats
- **Completed checklist items:** 64 high-level capability blocks (470+ sub-features)
- **Planned checklist items:** 33 actionable tasks
- **GitHub issues:** 134 total — 42 open and 92 closed (as of November 13, 2026)
- **Planning focus:** Uphold reliability, client-side credential security, and test coverage over speculative breadth; prioritize execution safety, risk circuit breakers, and institutional derivatives analytics.

### Key Highlights
- ✅ **v0.61.4 Patch:** Declared `FLUTTER_NOTIFICATION_CLICK` intent filter in `AndroidManifest.xml` and captured cold-start launch details so notifications reliably launch the app on Android; added `CopyTradeRequestDetailWidget` with full option leg inspection and direct Approve/Reject actions; registered `copy_trades` and `trade_signals` notification channels; and routed trade signal taps to Trade Signals with `InstrumentWidget` / `TradeInstrumentWidget` on action.
- ✅ **v0.61.3 Patch:** Queue Paper TP/SL exits triggered outside market hours and reconcile fills on a later eligible cycle; exits remain simulated and do not reach the brokerage.
- ✅ **v0.61.2 Patch:** Bound app startup waits, hardened auto-trade quote validation against stale and non-finite prices, improved background cycle diagnostics, and normalized Twelve Data intraday timestamps to UTC. Physical-device execution acceptance for [#282](https://github.com/CIInc/robinhood-options-mobile/issues/282) remains open.
- ✅ **v0.61.1 Patch:** Bound and validated `runBacktest` symbol/date inputs ([PR #314](https://github.com/CIInc/robinhood-options-mobile/pull/314)); added local auto-trade lifecycle diagnostics and app-resume schedule reconciliation. Physical-device execution acceptance for [#282](https://github.com/CIInc/robinhood-options-mobile/issues/282) remains open.
- ✅ **v0.59.0-v0.60.10 Code Delivered:** On-device auto-trading across Robinhood and Schwab, including live brokerage switch confirmation, automatic Paper quote selection with optional pinning, Paper TP/SL exits isolated to the per-user simulated ledger, signed long/short stock return percentages, and ticker-based Paper position matching across instrument URLs ([docs](docs/agentic-trading.md), [docs](docs/portfolio-redesign.md), [docs](docs/paper-trading-architecture.md), [#282](https://github.com/CIInc/robinhood-options-mobile/issues/282)); an initial Brinson-Fachler and options Greek Return Attribution implementation ([docs](docs/return-attribution.md), [#278](https://github.com/CIInc/robinhood-options-mobile/issues/278)); Unified AI Conviction ([docs](docs/unified-ai-conviction.md), [#118](https://github.com/CIInc/robinhood-options-mobile/issues/118)); real-time stream throttling ([docs](docs/streaming-performance-and-battery.md), [#124](https://github.com/CIInc/robinhood-options-mobile/issues/124)); Risk Parity ([docs](docs/portfolio-rebalancing.md), [#277](https://github.com/CIInc/robinhood-options-mobile/issues/277)); cross-account wash-sale guardrails ([docs](docs/wash-sale-and-asset-location.md), [#272](https://github.com/CIInc/robinhood-options-mobile/issues/272)); and Options Defense ([docs](docs/options-defense-and-roll-playbook.md), [#271](https://github.com/CIInc/robinhood-options-mobile/issues/271)). Issues #278 and #282 remain open for acceptance.
- ✅ **v0.58.0-v0.58.3 Shipped:** 4-Tier Feature Access Resolution (Admin bypass, Remote Config kill switches, GA rollout, self-serve Beta Labs opt-in) across 7 feature bundles ([docs](docs/feature-access-and-beta-gating.md), [#239](https://github.com/CIInc/robinhood-options-mobile/issues/239)), 5-Tier GEX Sequential Exit Stop Queue, Live-Quote BUY Guards ($\le 3\%$ deviation limit), authoritatively configured Trade Sizing in Reasoning mode, and scalar/date performance hardening.
- 🎯 **Current Focus (v0.60.x close-out):** Complete Return Attribution income/yield coverage and physical-device lifecycle testing, Schwab live account lifecycle verification, and market-calendar acceptance for on-device auto-trading execution modes and EOD exits ([#278](https://github.com/CIInc/robinhood-options-mobile/issues/278), [#282](https://github.com/CIInc/robinhood-options-mobile/issues/282)).
- 🚀 **Next Major Milestone (v0.61.0, Target: Q1/Q2 2027):** Macro Regime & GEX-Conditioned Strategy Backtest Attribution ([#273](https://github.com/CIInc/robinhood-options-mobile/issues/273)), Options Defined-Risk Inverse Guardrails for Copy Trading ([#279](https://github.com/CIInc/robinhood-options-mobile/issues/279)), Automated Earnings Implied Move vs. Realized Move ([#301](https://github.com/CIInc/robinhood-options-mobile/issues/301)), Multi-Account Batch Rebalancing Order Pad ([#302](https://github.com/CIInc/robinhood-options-mobile/issues/302)), Monte Carlo Derivatives & Portfolio Stress Engine ([#303](https://github.com/CIInc/robinhood-options-mobile/issues/303)), Intraday 0DTE Volatility & Net Dealer GEX Radar ([#304](https://github.com/CIInc/robinhood-options-mobile/issues/304)), Multi-Indicator Signal Collinearity Heatmap ([#305](https://github.com/CIInc/robinhood-options-mobile/issues/305)), Smart Order Routing (SOR) & Cross-Broker Margin & Borrow Optimizer ([#108](https://github.com/CIInc/robinhood-options-mobile/issues/108)), Bracket (OTOCO) & OCO Exit Protection Orders ([#108](https://github.com/CIInc/robinhood-options-mobile/issues/108)), and Futures Term Structure & Roll Assistant ([#103](https://github.com/CIInc/robinhood-options-mobile/issues/103), [#104](https://github.com/CIInc/robinhood-options-mobile/issues/104), [#105](https://github.com/CIInc/robinhood-options-mobile/issues/105)).

---

## Release Cadence & Milestone Overview

RealizeAlpha follows semantic versioning with focused minor releases and automated continuous testing. For complete version-by-version release notes and commit history, see [CHANGELOG.md](CHANGELOG.md).

| Version | Status | Primary Focus & Milestones | Reference |
| :--- | :--- | :--- | :--- |
| **v0.58.x** | Shipped ✅ | Feature Access & Beta Labs (4-tier hierarchy), 5-Tier GEX sequential exit stops, live-quote BUY guards, authoritatively configured trade sizing, $O(1)$ scalar technical indicators | [`docs/feature-access-and-beta-gating.md`](docs/feature-access-and-beta-gating.md), [#239](https://github.com/CIInc/robinhood-options-mobile/issues/239) |
| **v0.59.0** | Shipped ✅ | Unified AI Conviction (Gemini 3.1 Flash-Lite), Stream Throttling (250ms), Risk Parity Rebalancing, Cross-Account IRA Wash Sale Guardrails, Options Defense Playbook | [`docs/unified-ai-conviction.md`](docs/unified-ai-conviction.md), [`docs/streaming-performance-and-battery.md`](docs/streaming-performance-and-battery.md), [#272](https://github.com/CIInc/robinhood-options-mobile/issues/272), [#277](https://github.com/CIInc/robinhood-options-mobile/issues/277) |
| **v0.60.0–v0.60.10** | Code delivered; acceptance in progress | On-device auto-trading, active-brokerage selection recovery and Live-mode switch confirmation, automatic Paper quote source with optional pinning, Paper TP/SL exits through the simulated ledger, signed long/short stock return percentages, ticker-based Paper position matching across instrument URLs, initial Return Attribution implementation, iOS `BGTaskScheduler` pre-registration, and Android disk-cleanup build workflow. Physical-device, market-calendar, and remaining attribution acceptance pending | [`docs/agentic-trading.md`](docs/agentic-trading.md), [`docs/portfolio-redesign.md`](docs/portfolio-redesign.md), [`docs/paper-trading-architecture.md`](docs/paper-trading-architecture.md), [`docs/return-attribution.md`](docs/return-attribution.md), [#278](https://github.com/CIInc/robinhood-options-mobile/issues/278), [#282](https://github.com/CIInc/robinhood-options-mobile/issues/282) |
| **v0.61.0** | Pre-release; acceptance in progress (Target: Q1/Q2 2027) | Macro Regime Walk-Forward Backtesting code delivered; acceptance remains open. Other planned work includes Options Copy Defined-Risk Guardrails, Batch Rebalancing Pad, Monte Carlo Stress, 0DTE GEX Radar, Earnings Implied Move, Smart Order Routing & Margin Optimizer, Bracket/OCO Exit Orders, Futures Term Structure | [#273](https://github.com/CIInc/robinhood-options-mobile/issues/273), [#279](https://github.com/CIInc/robinhood-options-mobile/issues/279), [#301](https://github.com/CIInc/robinhood-options-mobile/issues/301), [#302](https://github.com/CIInc/robinhood-options-mobile/issues/302), [#303](https://github.com/CIInc/robinhood-options-mobile/issues/303), [#304](https://github.com/CIInc/robinhood-options-mobile/issues/304), [#305](https://github.com/CIInc/robinhood-options-mobile/issues/305) |
| **v0.61.1** | Pre-release | Backtest input bounds, local auto-trade lifecycle diagnostics, and app-resume Workmanager reconciliation; device-level acceptance remains open | [PR #314](https://github.com/CIInc/robinhood-options-mobile/pull/314), [#282](https://github.com/CIInc/robinhood-options-mobile/issues/282) |
| **v0.61.2** | Pre-release | Bounded startup waits, fresh finite quote checks for automatic BUY and TP/SL paths, expanded cycle diagnostics, and UTC intraday market-data timestamps | [#282](https://github.com/CIInc/robinhood-options-mobile/issues/282) |
| **v0.61.3** | Pre-release | Queue market-closed Paper TP/SL exits in the simulated ledger and reconcile them on a later eligible cycle | [`docs/agentic-trading.md`](docs/agentic-trading.md) |
| **v0.61.4** | Pre-release | Push notification deep linking & intent resolution (`FLUTTER_NOTIFICATION_CLICK`), copy trade request detail view, trade signal routing, and Android channel registration | [`docs/copy-trading.md`](docs/copy-trading.md), [`docs/trade-signal-notifications.md`](docs/trade-signal-notifications.md) |
| **v0.62.0+** | Planned 🚀 (Target: Q2/Q3 2027) | Plaid Multi-Broker Sync, Embedded Quant Webhook & REST API Gateway, Desktop & iPad Multi-Pane Floating Workspace, Dart 3 / Modern Linting Migration | [#15](https://github.com/CIInc/robinhood-options-mobile/issues/15), [#125](https://github.com/CIInc/robinhood-options-mobile/issues/125), [#140](https://github.com/CIInc/robinhood-options-mobile/issues/140) |

---

## Planned Enhancements 🚀

### v0.60.x Close-Out: Platform & Execution Acceptance
- [ ] **Reliable Auto-Trading Execution Modes & EOD Exit Acceptance** (v0.60.4, [docs](docs/agentic-trading.md), [#282](https://github.com/CIInc/robinhood-options-mobile/issues/282)):
  - Foreground execution and on-device Workmanager checks on iOS and Android are implemented.
  - Complete physical-device verification for iOS `BGTaskScheduler` background wakeups and Android battery optimization policies.
  - Execute live session market-calendar acceptance tests and Schwab live account verification for attempted, completed, and missed market-close exits.
- [ ] **Multi-Asset Brinson Performance & Greek Return Attribution** (v0.60.3, [docs](docs/return-attribution.md), [#278](https://github.com/CIInc/robinhood-options-mobile/issues/278)): Initial sector and option attribution, balance masking, CSV export, and tests are implemented. Complete remaining income/yield coverage and verify the full acceptance outline before closing the issue.

---

### v0.61.0: Advanced Derivatives, Walk-Forward Validation & Smart Order Routing (Target: Q1/Q2 2027)

#### Quantitative Research & Strategy Backtesting
- [x] **Macro Regime & GEX-Conditioned Strategy Backtest Attribution (Walk-Forward Validation)** (v0.61.0, [#273](https://github.com/CIInc/robinhood-options-mobile/issues/273), [Tracking: #137](https://github.com/CIInc/robinhood-options-mobile/issues/137)):
  - Tag each simulated trade in `functions/src/backtesting.ts` with its market regime (Bull Low-Vol, Bull High-Vol, Bear Low-Vol, Bear High-Vol) derived from SPY trend and ATR/volatility percentiles in $O(1)$ space.
  - Compute per-regime performance metrics (win rate, profit factor, net profit, max drawdown, trade count).
  - Support an In-Sample / Out-of-Sample (70/30) split returning comparative Sharpe and profit factor degradation to detect curve-fitted parameter configurations.
  - Render an interactive Regime Attribution & Walk-Forward Stability card in `BacktestingWidget` with 1-tap regime filtering.
- [ ] **Monte Carlo Derivatives & Portfolio Stress Engine (Path-Dependent VaR & Ruin Probability)** (v0.61.0, [#303](https://github.com/CIInc/robinhood-options-mobile/issues/303), [Tracking: #137](https://github.com/CIInc/robinhood-options-mobile/issues/137)):
  - Simulate 1,000 to 5,000 synthetic portfolio trajectories over forward horizons (30d, 90d, 180d, 365d) using Geometric Brownian Motion (GBM), Student's t, and historical bootstrap sampling.
  - Compute path-dependent 95% and 99% CVaR (Expected Shortfall), maximum drawdown distributions, and margin breach / ruin probability.
  - Incorporate non-linear options Greek Taylor-series decay ($\Delta, \Gamma, \Theta, \mathcal{V}$) along simulated paths.
  - Render an interactive Monte Carlo Risk Card with fan chart percentiles (5th, 25th, median, 75th, 95th) in the Risk section.
- [ ] **Multi-Indicator Signal Collinearity & Alpha Redundancy Heatmap** (v0.61.0, [#305](https://github.com/CIInc/robinhood-options-mobile/issues/305), [Tracking: #137](https://github.com/CIInc/robinhood-options-mobile/issues/137)):
  - Compute pairwise Pearson correlation matrix and Variance Inflation Factor (VIF) across all 19 technical indicators over historical bars.
  - Surface an interactive $19 \times 19$ Factor Collinearity Heatmap in `BacktestingWidget` and `MacroAssessmentDashboardWidget`.
  - Warn when strategy indicators have correlation $> 0.80$ to eliminate redundant oscillator/trend signals and prevent curve-fitting.

#### Copy Trading Risk & Guardrails
- [ ] **Options Contract Adaptation & Defined-Risk Inverse Guardrails for Copy Trading** (v0.61.0, [#279](https://github.com/CIInc/robinhood-options-mobile/issues/279), [Tracking: #141](https://github.com/CIInc/robinhood-options-mobile/issues/141)):
  - Block naked short option generation in inverse copy mode by mapping short contracts to defined-risk opposite-direction spreads (e.g. short call $\to$ long put or defined bear call spread).
  - Suggest delta/DTE-matched strikes or vertical spreads when a single contract exceeds the follower's configured per-trade capital allocation cap.

#### Execution & Cross-Broker Optimization
- [ ] **Smart Order Routing (SOR) & Cross-Broker Margin & Borrow Optimizer** (v0.61.0, [#108](https://github.com/CIInc/robinhood-options-mobile/issues/108)):
- [ ] **Schwab Market-Data & Order-Lifecycle Parity** ([#138](https://github.com/CIInc/robinhood-options-mobile/issues/138)): Complete the remaining quote, OHLCV, fundamentals, movers, order-preview, margin-check, and in-flight replacement coverage.
- [ ] **Reusable Crypto & Forex Order Templates** ([#116](https://github.com/CIInc/robinhood-options-mobile/issues/116)): Save and reuse instrument-specific order configurations while preserving live price and risk validation.
  - Dynamically evaluate and route equity/option orders between connected brokerages (Robinhood and Schwab) to minimize margin requirements, borrow fees, and maximize uninvested cash yields.
- [ ] **Bracket (OTOCO) & One-Cancels-Other (OCO) Exit Protection Orders** (v0.61.0, [#108](https://github.com/CIInc/robinhood-options-mobile/issues/108)):
  - Attach simultaneous Take-Profit Limit and Stop-Loss exit brackets at order entry or pair existing position exits as OCO orders with live Risk:Reward preview and native Schwab conditional order routing.
- [ ] **Multi-Account Batch Rebalancing Order Pad & Cross-Broker Allocation Executor** (v0.61.0, [#302](https://github.com/CIInc/robinhood-options-mobile/issues/302), [Tracking: #108](https://github.com/CIInc/robinhood-options-mobile/issues/108), [#277](https://github.com/CIInc/robinhood-options-mobile/issues/277)):
  - Convert Risk Parity or custom target weight drift into concrete, validated Buy/Sell limit orders across connected Robinhood and Schwab accounts.
  - Support configurable minimum trade thresholds, cash reserve buffers, and tax-aware lot selection (prioritizing high-cost lots in taxable accounts).
  - Provide a dry-run staging sheet with per-order toggles, estimated execution values, and sequential execution with circuit breaker verification.

#### Derivatives, Options & Futures Analytics
- [ ] **Automated Earnings Implied Move vs. Historical Realized Move & Straddle Mispricing Analyzer** (v0.61.0, [#301](https://github.com/CIInc/robinhood-options-mobile/issues/301), [Tracking: #118](https://github.com/CIInc/robinhood-options-mobile/issues/118), [#137](https://github.com/CIInc/robinhood-options-mobile/issues/137)):
  - Display ATM straddle implied move ($0.84 \times \text{straddle price}$) and expected price range for equities with earnings dates within 30 days.
  - Correlate historical earnings dates with daily bars over prior 8–12 quarters to compute average actual 1-day move, max move, and volatility crush frequency.
  - Surface an Earnings Implied Move Card in `OptionChainWidget` and stock detail pages with historical IV crush metrics and expected value indicators.
- [ ] **Intraday 0DTE Volatility, Net Dealer GEX & Pin Magnetism Radar** (v0.61.0, [#304](https://github.com/CIInc/robinhood-options-mobile/issues/304), [Tracking: #134](https://github.com/CIInc/robinhood-options-mobile/issues/134), [#137](https://github.com/CIInc/robinhood-options-mobile/issues/137)):
  - Isolate 0DTE/1DTE options contracts to compute real-time strike-by-strike Gamma Exposure (GEX) and intraday Zero Gamma / Gamma Flip levels.
  - Pinpoint the 4:00 PM Pin Magnet Strike (highest gamma concentration and open interest driving market-maker hedging compression).
  - Track intraday Charm decay and expected market-maker re-hedging flows over 1–3 hour windows with 250ms stream throttling.
- [ ] **Futures Contract Roll Assistant, Term Structure & Contango/Backwardation Analyzer** (v0.61.0, [#103](https://github.com/CIInc/robinhood-options-mobile/issues/103), [#104](https://github.com/CIInc/robinhood-options-mobile/issues/104), [#105](https://github.com/CIInc/robinhood-options-mobile/issues/105)):
  - Expiration and First Notice countdown alerts, front-to-back contract term-structure curve (contango/backwardation roll yield), contract specifications, and guided calendar roll assistant.
- [ ] **Futures SPAN Margin Health, Liquidation Distance & Intraday Seasonality Analytics** (v0.61.0, [#67](https://github.com/CIInc/robinhood-options-mobile/issues/67), [#106](https://github.com/CIInc/robinhood-options-mobile/issues/106), [#111](https://github.com/CIInc/robinhood-options-mobile/issues/111)):
  - Per-contract and aggregate futures Initial/Maintenance Margin utilization, effective notional leverage, estimated liquidation price / ATR shock cushion, and Action Center low-buffer alerts.

---

### v0.62.0+: Multi-Broker Expansion, Quant APIs & Workspace Scaling (Target: Q2/Q3 2027)

#### Multi-Broker & External Integrations
- [ ] **Plaid Account Linking & Unified Transaction Sync** ([#15](https://github.com/CIInc/robinhood-options-mobile/issues/15), [#92](https://github.com/CIInc/robinhood-options-mobile/issues/92), [#121](https://github.com/CIInc/robinhood-options-mobile/issues/121), [#123](https://github.com/CIInc/robinhood-options-mobile/issues/123)):
  - Secure institutional account linking via Plaid Link for read-only aggregation across external banks, brokerages, and retirement plans.
- [ ] **Direct Fidelity Brokerage API Integration** ([#33](https://github.com/CIInc/robinhood-options-mobile/issues/33)): Add API authentication and direct position streaming beyond the existing Fidelity CSV import/export workflow.
- [ ] **Real-Time Market-Data Subscription Expansion** ([#121](https://github.com/CIInc/robinhood-options-mobile/issues/121)): Extend current Yahoo preset and basic-data support with reliable real-time market-data subscriptions.
- [ ] **Interactive Brokers (IBKR) Integration** ([#30](https://github.com/CIInc/robinhood-options-mobile/issues/30)):
  - Client portal API integration for global multi-currency portfolios and direct routing.

#### Mobile Product Experience & Education
- [ ] **Mobile UX & Platform-Specific Improvements** ([#117](https://github.com/CIInc/robinhood-options-mobile/issues/117)): Add tablet-optimized layouts, haptic feedback, and voice-assistant integration while retaining the existing landscape and dark-mode support.
- [ ] **Investment Education & Learning Platform** ([#119](https://github.com/CIInc/robinhood-options-mobile/issues/119)): Develop strategy guides, options education, interactive tutorials, video explanations, and a glossary.

#### Quant Developer Platform & Multi-Platform Workspace
- [ ] **Developer API & Local OpenAPI Webhook Gateway** ([#137](https://github.com/CIInc/robinhood-options-mobile/issues/137)):
  - Embedded local WebSocket and REST API server in the Flutter client allowing quantitative users to stream live quotes, Greeks, and signals to external Python/Node.js scripts without cloud relay.
- [ ] **Desktop & iPad Multi-Pane Floating Workspace**:
  - Native Flutter Desktop (macOS/Windows) and iPad split-view workspace with floating order pads, live depth, and detachable charts.
- [ ] **Smart Watch & Wearables App**:
  - Apple Watch and Wear OS companion apps with glanceable portfolio P&L, price alerts, and watchlists.

#### Technical Excellence, Security & Documentation
- [ ] **Comprehensive Widget Test Coverage** ([#90](https://github.com/CIInc/robinhood-options-mobile/issues/90)): Expand screen-level interaction, golden, accessibility, and CI-integrated widget testing.
- [ ] **Complete Two-Factor Authentication** ([#89](https://github.com/CIInc/robinhood-options-mobile/issues/89)): Complete TOTP setup, SMS backup and recovery codes, and trusted-device flows.
- [ ] **Code Quality & Maintenance** ([#125](https://github.com/CIInc/robinhood-options-mobile/issues/125)):
  - Complete Dart 3 migration, resolve remaining deprecated member uses, and enforce zero warnings in static analysis.
- [ ] **Documentation & Developer Experience** ([#94](https://github.com/CIInc/robinhood-options-mobile/issues/94), [#95](https://github.com/CIInc/robinhood-options-mobile/issues/95), [#96](https://github.com/CIInc/robinhood-options-mobile/issues/96), [#140](https://github.com/CIInc/robinhood-options-mobile/issues/140)):
  - Complete API reference, developer onboarding guide, and Architecture Decision Records (ADRs).
- [ ] **Security Audit & Infrastructure Roadmap** ([#135](https://github.com/CIInc/robinhood-options-mobile/issues/135)):
  - Third-party security assessment, enterprise MCP server hardening, and zero-knowledge portfolio verification badges.
- [ ] **End-to-End Encryption for Sensitive Metadata**:
  - Encrypt custom user trade notes and private watchlists on-device before writing to Firestore.

#### Selective Long-Term Research (Advisory & Exploratory)
- [ ] **Server-Side Auto-Execute**: Evaluated only if secure cloud key storage (Cloud KMS) and sub-second broker relay can be achieved without compromising client-side token sovereignty.
- [ ] **Live & Social Sentiment Agent** ([Tracking: #118](https://github.com/CIInc/robinhood-options-mobile/issues/118)): Expand sentiment beyond cached news into low-latency earnings-call transcripts and public Fed speeches with strict confidence bounds and non-advisory advisory guardrails.
- [ ] **External Social & Community Features** ([#113](https://github.com/CIInc/robinhood-options-mobile/issues/113)): Explore Reddit and Twitter sentiment, community trade ideas, and broader portfolio-following tools beyond existing investor groups and discussion threads.
- [ ] **Zero-Knowledge Proofs (ZKP) for Private Social Trading**: Verifiable track record badges (Sharpe, win rate, return %) without revealing account equity or dollar trade amounts.

---

### Active Risk Register & Safeguards

| Risk & Area | Impact & Severity | Mitigation Strategy | Owner |
| :--- | :--- | :--- | :--- |
| **OS Background Execution & EOD Timing** | High 🔴 (Auto-Trading Lifecycle) | Foreground execution is authoritative; OS background checks (`Workmanager` / `BGTaskScheduler`) are best effort with persistent attempted/completed/missed state tracking and opt-in missed-exit push notifications. | Mobile Engineering |
| **Cross-Broker Concurrent Authentication** | High 🔴 (Multi-Broker SOR) | Independent token managers with mutex locks, silent refresh before expiry via `SecureTokenStorage`, isolated session failure recovery, and no plaintext token storage. | Backend + Security |
| **Hardware-Backed Credential Protection** | Medium 🟡 (Secure Storage) | `flutter_secure_storage` uses platform Keychain/Keystore storage, but hardware-backed keys and Secure Enclave protection are not guaranteed on every supported device; define and verify stricter platform-specific enforcement ([#88](https://github.com/CIInc/robinhood-options-mobile/issues/88)). | Security Engineering |
| **Live Quote BUY Guard & Execution Drift** | Medium 🟡 (Order Execution) | Mandatory live-quote price check before executing automatic or queued BUYs; abort execution if price deviates $> 3\%$ or quote retrieval fails. | Quant Trading Team |
| **Follower Capital Risk in Copy Trading** | Medium 🟡 (Social Copy Trading) | Strict follower protective guardrails via `CopyTradeRiskGuardianService`: per-trade allocation caps, max slippage abort, and auto-disconnect on leader drawdown divergence. | Social & Trading Team |
| **Firebase Quotas & Cloud Functions Performance** | Low 🟢 (Cloud Infrastructure) | $O(1)$ auxiliary space in technical indicator and backtest loops, client-side query caching, index-bounded loops, and mandatory authentication on all callable Cloud Functions. | Backend Engineering |

---

## Completed Features ✅

### Portfolio Intelligence, Greeks & Tax Optimization
- [x] **Cross-Account & IRA Wash Sale Guardrails & Asset Location Optimizer** (v0.59.0, [#272](https://github.com/CIInc/robinhood-options-mobile/issues/272)): Detect permanent IRS Revenue Ruling 2008-5 wash-sale disallowances across linked taxable and IRA accounts, surface inline pre-trade warnings in order tickets, and score tax-advantaged asset location.
- [x] **Risk Parity & Inverse-Volatility Portfolio Rebalancing Engine** (v0.59.0, [#277](https://github.com/CIInc/robinhood-options-mobile/issues/277)): Realized asset/sector volatility and covariance clusters on-device, Marginal Contribution to Risk (MCR %) vs. Capital Weight %, and 1-tap Equal Risk Contribution target allocations ([docs](docs/portfolio-rebalancing.md)).
- [x] **Tax Optimization Suite & Wash Sale Detector** (v0.48.0, [Tracking: #114](https://github.com/CIInc/robinhood-options-mobile/issues/114)):
  - [x] Rolling 30-Day Wash Sale Window Tracker across equities and options.
  - [x] Automated Tax Loss Harvesting Opportunity Scanner with correlated replacement recommendations.
  - [x] Short-Term vs. Long-Term Capital Gains Breakdown with holding duration timers and tax liability projections.
  - [x] Specific Tax Lot Matching (HIFO/LIFO Order Entry) at order placement.
  - [x] IRS Form 8949 Reconciliation & Schedule D CSV Export with adjustment code `W`.
- [x] **Beta-Weighted Portfolio Delta & Cross-Asset Greeks Engine** (v0.51.0): Portfolio-wide beta-weighting ($\Delta_{\beta-SPY}$) and aggregate Gamma/Vega across stocks, options, crypto, futures, and forex ([Tracking: #137](https://github.com/CIInc/robinhood-options-mobile/issues/137)).
- [x] **Advanced Portfolio Analytics & Custom Benchmarks**: Sharpe ratio, Sortino, Alpha, Beta, Treynor, Information Ratio, and Custom Benchmark comparison against any ticker (SPY, QQQ, DIA, IWM, BTC, etc.) ([#18](https://github.com/CIInc/robinhood-options-mobile/issues/18)).
- [x] **Portfolio Visualization & Heatmaps**: Interactive allocation pie charts (Asset, Position, Sector, Industry) ([#2](https://github.com/CIInc/robinhood-options-mobile/issues/2)), risk exposure treemaps, and correlation matrices.
- [x] **ESG Scoring**: Portfolio Environmental, Social, and Governance scoring and holdings roll-up.
- [x] **Multi-Account Aggregation**: Unified view combining taxable, retirement, and cash accounts into a single portfolio overview.

### Trading Execution & Order Routing
- [x] **Futures Order Entry** ([#72](https://github.com/CIInc/robinhood-options-mobile/issues/72); issue remains open): Market/limit entry, live quotes, confirmation, and position tracking are implemented; the issue remains open in GitHub.
- [x] **5-Tier GEX Sequential Exit Stop Queue** (v0.58.0): Institutional exit hierarchy prioritizing trailing profit stops, breakeven stops, gamma flip alerts, and emergency circuit breakers.
- [x] **Live-Quote BUY Guard & Trade Sizing Validation** (v0.58.1-v0.58.2): Validation against fresh live quotes ($\le 3\%$ deviation) before executing auto or approved BUYs; authoritative configured sizing when dynamic sizing is off.
- [x] **Options Pin Risk, Ex-Dividend Early Assignment & Expiration Guard** (v0.59.0, [#271](https://github.com/CIInc/robinhood-options-mobile/issues/271)): Detect ITM short call early-assignment risk ahead of ex-dividend dates ($\text{Extrinsic Value} \le 1.25 \times \text{Dividend}$), score 0DTE/1DTE expiration pin risk ($\pm 1.0\%$), and project margin shocks with 1-tap roll/close defense actions ([docs](docs/options-defense-and-roll-playbook.md)).
- [x] **Options Strategy Roll Assistant** (v0.49.0, [#157](https://github.com/CIInc/robinhood-options-mobile/issues/157)): 1-tap rolling wizard for covered calls, cash-secured puts, long options, and vertical spreads with automated net credit/debit calculation and breakeven projections.
- [x] **Multi-Leg Options Defense Playbook & Spread Builder** (v0.50.0, [#158](https://github.com/CIInc/robinhood-options-mobile/issues/158)): Automated defensive action recommendations when short legs are tested; quick-entry templates for vertical spreads, straddles, strangles, iron condors, and calendar spreads.
- [x] **Combo Orders Support**: Atomic equity + option order execution and history.
- [x] **Autonomous Risk Circuit Breakers & Cooling-Off Lock** (v0.48.5, [Tracking: #142](https://github.com/CIInc/robinhood-options-mobile/issues/142)): Hard user-defined limits (daily max loss, drawdown limit, consecutive losses, behavioral tilt cooling-off trading suspension).
- [x] **In-App Behavioral Tilt & Overtrading Safeguards** (v0.55.1, [Tracking: #142](https://github.com/CIInc/robinhood-options-mobile/issues/142)): Software-based tilt detection monitoring rapid cancel/replace loops and revenge trading.

### Trade Signals & Agentic Trading
- [x] **19-Indicator Technical Correlation Engine**: Multi-indicator analysis combining RSI, MACD, Bollinger Bands, Stochastic, ATR, ADX, CCI, MFI, OBV, VWAP, Ichimoku, Parabolic SAR, Keltner Channels, Williams %R, Donchian, Pivot Points, and SMA/EMA crossovers in $O(1)$ space.
- [x] **Multi-Timeframe Trade Signals**: 15m, 1h, and 1d signal generation with confidence weighting and market trend filtering.
- [x] **Macro Assessment Regime Conditioning**: Global market direction and volatility regime classification conditioning live signal generation.
- [x] **On-Device Agentic Auto-Trading Engine**: Automated and semi-automated trade generation with Paper Trading simulation, emergency stop persistent sync, and fail-closed leasing.
- [x] **Dual Broker Support (Robinhood & Schwab)**: Selected-broker auto-trading routing orders directly through the active brokerage implementation.

### Derivatives, Quantitative Research & Backtesting
- [x] **0DTE Flow & Intraday Gamma Squeeze Radar** (v0.51.0): Real-time monitoring of 0DTE flow velocity, dealer gamma flip thresholds, and gamma squeeze risk alerts.
- [x] **Implied Volatility Surface 3D Visualizer** (v0.51.5): Interactive 3D surface plot across strikes and expiration dates with regularized grid interpolation and Dupire local volatility.
- [x] **Realized vs. Implied Volatility (IV) Cone & Rank/Percentile** (v0.51.4): Multi-timeframe IV percentiles (30d/60d/90d) and volatility skew surfaces.
- [x] **Earnings IV Crush Probability & Straddle Pricing Estimator** (v0.51.3): Implied earnings move vs. actual historical moves over 12 quarters and expected value straddle pricing distributions.
- [x] **Delta-Neutral Strategy Builder** (v0.51.6): Dynamic delta offsets, automated share/option rebalancing suggestions, and spot-shift scenario simulation.
- [x] **Strategy Validator & Historical Backtesting Engine** ([#136](https://github.com/CIInc/robinhood-options-mobile/issues/136)): Cloud Functions v2 backtest runner evaluating multi-indicator templates over historical OHLCV data.
- [x] **Alpha Factor Discovery & Event Study Analyzer**: Dynamic volatility, beta, and correlation tracking around earnings and catalyst windows.

### Copy Trading & Risk Guardian
- [x] **Copy Trade Request Detail View & Push Deep Linking** (v0.61.4, [docs](docs/copy-trading.md)): Direct notification routing to `CopyTradeRequestDetailWidget`, option leg/stock parameter verification, leader name resolution, and 1-tap Approve/Reject with RiskGuard validation.
- [x] **Trader Comparison & Normalized Analytics** (v0.52.0, [#141](https://github.com/CIInc/robinhood-options-mobile/issues/141)): Side-by-side performance comparison of potential leaders with risk-adjusted metrics.
- [x] **Copy-Trading Slippage & Fill Divergence Analytics** (v0.52.0): Track execution latency (ms), fill price delta vs. leader, and performance drift.
- [x] **Automated Copy-Trading Risk Guardian** (v0.52.0, [#141](https://github.com/CIInc/robinhood-options-mobile/issues/141)): Follower protective guardrails specifying max capital allocation per trade, auto-disconnect on leader drawdown divergence, and max slippage abort.
- [x] **Copy Trade History & Performance Export** (v0.52.0): CSV export and cumulative P&L growth visualization over time.

### Investor Groups & Social Platform
- [x] **Investor Groups 2.0**: Create and manage private/public investor groups with role-based member permissions ([#31](https://github.com/CIInc/robinhood-options-mobile/issues/31)).
- [x] **Real-Time Group Chat & Collaborative Boards**: In-group discussion threads, shared thesis sharing, and target calculations ([#76](https://github.com/CIInc/robinhood-options-mobile/issues/76)).
- [x] **Group Activity Feeds & Shared Watchlists**: Collaborative watchlists and live trade feeds ([#78](https://github.com/CIInc/robinhood-options-mobile/issues/78), [#79](https://github.com/CIInc/robinhood-options-mobile/issues/79)).
- [x] **Verified Track Records & Public Leaderboards**: Cryptographic proof of historical performance and brokerage verification for public profiles ([#26](https://github.com/CIInc/robinhood-options-mobile/issues/26)).
- [x] **Portfolio Following & Discussion Threads** ([#24](https://github.com/CIInc/robinhood-options-mobile/issues/24), [#27](https://github.com/CIInc/robinhood-options-mobile/issues/27)): Follow other users' portfolios, granular discussion threads, author pinned comments, and community sentiment polling.

### Market Intelligence, SEC EDGAR & Filings
- [x] **SEC EDGAR Filing Expansion** ([docs](docs/sec-edgar-integration.md), [#143](https://github.com/CIInc/robinhood-options-mobile/issues/143)): Real-time 13F institutional ownership, Form 4 insider transaction clusters, 8-K material event alerts, and 10-K/10-Q financial statement parsing.
- [x] **Congressional STOCK Act Disclosure Tracker** (v0.53.0, [docs](docs/congress-trading-tracker.md)): Automated monitoring of congressional stock purchases and sales with Action Center alerts.
- [x] **First-Party Institutional, Insider & Retail Flow Tracking**: Direct Robinhood market data integration for hedge fund sentiment, monthly aggregate insider buying, and retail order flow net volume.
- [x] **Short Float & Live Shorting Rates**: Real-time free float short percentage, shares short, borrow inventory levels, and borrow fee rates.
- [x] **News Intelligence & Summarization** (v0.38.0): AI-powered breaking news impact analysis, sentiment scoring, and directional event prediction.

### Brokerage & Multi-Account Infrastructure
- [x] **Charles Schwab Direct API Integration** ([#91](https://github.com/CIInc/robinhood-options-mobile/issues/91), [#93](https://github.com/CIInc/robinhood-options-mobile/issues/93), [#122](https://github.com/CIInc/robinhood-options-mobile/issues/122)): OAuth authentication, multi-account routing, real-time quote/candles retrieval, options chains, and order preview/placement.
- [x] **Schwab Real-Time WebSocket Streamer** ([#145](https://github.com/CIInc/robinhood-options-mobile/issues/145)): Sub-second streaming quotes (`LEVELONE_EQUITIES`), Greeks (`LEVELONE_OPTIONS`), account/order notifications (`ACCT_ACTIVITY`), and futures/forex feeds.
- [x] **Robinhood Native Multi-Account & Retirement**: Traditional & Roth IRAs with annual contribution tracking, Spending accounts, and Robinhood Crypto direct integration ([#65](https://github.com/CIInc/robinhood-options-mobile/issues/65); issue remains open).
- [x] **Fidelity CSV Portfolio & Tax Lot Import**: On-device import and mapping of Fidelity CSV export files into unified portfolio analytics.
- [x] **Paper Trading Ledger**: Full simulated execution engine decoupling paper trades from live margin and circuit breaker constraints.

### Notifications & Multi-Channel Alerts
- [x] **Trade Signal Push Notification Intent & Cold-Start Deep Linking** (v0.61.4, [docs](docs/trade-signal-notifications.md)): Declared `FLUTTER_NOTIFICATION_CLICK` intent filter in Android manifest, captured local notification launch details from terminated state, resolved fallback demo user for unhydrated stores, and routed to Trade Signals tab with `InstrumentWidget` / `TradeInstrumentWidget` on action.
- [x] **Multi-Channel Alert Routing & Custom Sounds** (v0.59.0, [docs](docs/custom-alerts.md), [#115](https://github.com/CIInc/robinhood-options-mobile/issues/115)): Push, In-App, Email, SMS, and Webhook dispatch with critical-only gating, custom audio, quiet hours, and 5 dedicated Android/APNs priority notification channels.
- [x] **Action Center Real-Time Alerts** (`PortfolioAlertService`): Actionable alert engine covering options expiration (0DTE/1DTE/2DTE), early assignment, earnings calendar, dividend reminders, unusual volume, and margin health.
- [x] **Multi-Condition Alert Builder** (v0.38.0): Combine price, volume, RSI, and GEX levels into dynamic triggered notifications.

### Cash Management, Banking & Retirement
- [x] **Retirement Planning & Gold Match Maximizer** (v0.56.0, [docs](docs/multi-account-and-retirement.md), [#139](https://github.com/CIInc/robinhood-options-mobile/issues/139)): Interactive compounding projection calculator and Robinhood Gold IRA 3% match tracking.
- [x] **Stock Lending Program (SLIP) Dashboard** (v0.45.0): Track loaned shares, earned yield payments, and agreement eligibility.
- [x] **Cash Sweeps & APY Rate Monitor** (v0.45.0): Track FDIC sweep balances and multi-tier interest rates.
- [x] **Banking, ACH Transfers & Statements** (v0.45.0): Monitor deposits, withdrawals, clearing status, linked bank accounts, and Form 1099 tax documents.

### Performance, Battery & Security Architecture
- [x] **High-Frequency Stream Throttling & Battery Optimization** (v0.59.0, [docs](docs/streaming-performance-and-battery.md), [#124](https://github.com/CIInc/robinhood-options-mobile/issues/124)): 250ms per-symbol update throttling, viewport-bounded streaming subscriptions, memory optimization, and background stream pausing.
- [x] **Zero Plaintext Credentials (`SecureTokenStorage`)**: Brokerage OAuth tokens and MCP credentials stored in platform Keychain/Keystore via `flutter_secure_storage`; hardware-backed key enforcement remains an open platform-specific requirement ([#88](https://github.com/CIInc/robinhood-options-mobile/issues/88)).
- [x] **4-Tier Feature Access & Beta Labs System** (v0.58.0, [docs](docs/feature-access-and-beta-gating.md), [#239](https://github.com/CIInc/robinhood-options-mobile/issues/239)): Dynamic Remote Config kill switches, per-user feature flags, and self-serve Beta Labs opt-in.
- [x] **Cloud Functions v2 Security**: Strict callable authentication (`request.auth`), admin role verification, and client input sanitization on all backend endpoints.
- [x] **Global Balance Masking (`AccountStore`)**: 1-tap masking (`$••••••`) across hero numbers, position rows, tooltips, and chart components.
- [x] **Screen-Reader Accessibility (Semantics)**: Consolidated financial rows, options flow badges, and attribution tables with comprehensive spoken semantics.

---

## Feedback & Contribution

We value community feedback! If you have suggestions for the roadmap or want to contribute:
1. **Open an Issue**: Submit feature requests or bug reports on GitHub ([Issues](https://github.com/CIInc/robinhood-options-mobile/issues)).
2. **Review Product Principles**: Consult [PRODUCT.md](PRODUCT.md) and [AGENTS.md](AGENTS.md) before proposing significant architectural or algorithmic changes.
3. **Submit a PR**: We welcome focused pull requests that include relevant unit and widget tests.
