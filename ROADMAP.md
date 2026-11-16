# Roadmap

This document outlines the planned features, enhancements, and delivery milestones for RealizeAlpha.

## Table of Contents

- [Summary](#summary)
- [Release Cadence & Milestone Overview](#release-cadence--milestone-overview)
- [Planned Enhancements 🚀](#planned-enhancements-)
  - [v0.62.0: Execution Safety, Resilient Exits & Simplified Auto-Trading (Target: Q1 2027)](#v0620-execution-safety-resilient-exits--simplified-auto-trading-target-q1-2027)
  - [v0.63.0: Advanced Derivatives, Institutional Flow & Cross-Broker Rebalancing (Target: Q2 2027)](#v0630-advanced-derivatives-institutional-flow--cross-broker-rebalancing-target-q2-2027)
  - [v0.64.0+: Multi-Broker Expansion, Market-Neutral StatArb & Quant Platform (Target: Q3/Q4 2027)](#v0640-multi-broker-expansion-market-neutral-statarb--quant-platform-target-q3q4-2027)
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

**Last reviewed:** November 14, 2026 · **Current app version:** 0.61.8 (pre-release)

### Quick Stats
- **Completed checklist items:** 75 high-level capability blocks (500+ sub-features)
- **Planned checklist items:** 38 actionable tasks across 3 milestone horizons (v0.62.0: 10, v0.63.0: 12, v0.64.0+: 16)
- **GitHub issues:** 150 total — 58 open and 92 closed (as of November 14, 2026)
- **Planning focus:** Uphold reliability, client-side credential security, and test coverage over speculative breadth; prioritize execution safety, risk circuit breakers, and institutional derivatives analytics.

### Key Highlights
- ✅ **v0.62.0 Feature:** 1-Tap Curated Strategy Archetypes (*Conservative Core*, *Momentum Breakout*, *Options Income Harvester*, *Reasoning AI Agent*) with Walk-Forward Performance Badges, empirical 1-year validation, and 1-tap preset cloning ([docs](docs/agentic-trading.md), [#343](https://github.com/CIInc/robinhood-options-mobile/issues/343)).
- ✅ **v0.61.8 Patch:** Dedicated Automated Trading Pending Approvals & Batch Review Center (`AutomatedTradingApprovalsWidget`, `AutomatedTradeProposalDetailWidget`, batch actions, rejection audit history, live-quote BUY guards, balance masking) ([docs](docs/agentic-trading.md), [#282](https://github.com/CIInc/robinhood-options-mobile/issues/282), [#137](https://github.com/CIInc/robinhood-options-mobile/issues/137)).
- ✅ **v0.61.7 Patch:** Implemented closed-form higher-order portfolio Greeks (Vanna $\partial\Delta/\partial\sigma$, Charm $-\partial\Delta/\partial\tau$ daily & weekend bleed, and Vomma $\partial\mathcal{V}/\partial\sigma$), interactive 2D Spot $\times$ IV Cross-Shock Stress Matrix with P&L and Net Delta toggles, and privacy balance masking ([#335](https://github.com/CIInc/robinhood-options-mobile/issues/335)).
- ✅ **v0.61.6 Patch:** Added on-device Monte Carlo Derivatives & Portfolio Stress Engine with GBM, Student's $t$, and historical bootstrap fan charts, non-linear Greek Taylor-series decay, and path-dependent VaR/CVaR & ruin probability ([#303](https://github.com/CIInc/robinhood-options-mobile/issues/303)); enforced defined-risk inverse option guardrails and small-account option contract adaptation in Copy Trading ([#279](https://github.com/CIInc/robinhood-options-mobile/issues/279)).
- 🚀 **Next Major Milestone (v0.62.0, Target: Q1 2027):** Execution Safety, Resilient Exits & Simplified Auto-Trading (Progressive Disclosure UI [[#344](https://github.com/CIInc/robinhood-options-mobile/issues/344)], Pre-Flight Safe Start Wizard [[#345](https://github.com/CIInc/robinhood-options-mobile/issues/345)], Broker-Native Bracket OTOCO/OCO Orders & Authoritative Live Account Pinning [[#108](https://github.com/CIInc/robinhood-options-mobile/issues/108), [#282](https://github.com/CIInc/robinhood-options-mobile/issues/282)], Strategy Backtest-to-Live Execution Drift Monitor & Promotion Gate [[#337](https://github.com/CIInc/robinhood-options-mobile/issues/337)], Trade Lifecycle Timeline & Auditor [[#339](https://github.com/CIInc/robinhood-options-mobile/issues/339)], and Automated Earnings Blackout Gate [[#340](https://github.com/CIInc/robinhood-options-mobile/issues/340)]).

---

## Release Cadence & Milestone Overview

RealizeAlpha follows semantic versioning with focused minor releases and automated continuous testing. For complete version-by-version release notes and commit history, see [CHANGELOG.md](CHANGELOG.md).

| Version | Status | Primary Focus & Milestones | Reference |
| :--- | :--- | :--- | :--- |
| **v0.58.x** | Shipped ✅ | Feature Access & Beta Labs (4-tier hierarchy), 5-Tier GEX sequential exit stops, live-quote BUY guards, authoritatively configured trade sizing, $O(1)$ scalar technical indicators | [`docs/feature-access-and-beta-gating.md`](docs/feature-access-and-beta-gating.md), [#239](https://github.com/CIInc/robinhood-options-mobile/issues/239) |
| **v0.59.0** | Shipped ✅ | Unified AI Conviction (Gemini 3.1 Flash-Lite), Stream Throttling (250ms), Risk Parity Rebalancing, Cross-Account IRA Wash Sale Guardrails, Options Defense Playbook | [`docs/unified-ai-conviction.md`](docs/unified-ai-conviction.md), [`docs/streaming-performance-and-battery.md`](docs/streaming-performance-and-battery.md), [#272](https://github.com/CIInc/robinhood-options-mobile/issues/272), [#277](https://github.com/CIInc/robinhood-options-mobile/issues/277) |
| **v0.60.0–v0.60.10** | Shipped ✅ | On-device auto-trading, active-brokerage selection recovery and Live-mode switch confirmation, automatic Paper quote source with optional pinning, Paper TP/SL exits through the simulated ledger, signed long/short stock return percentages, ticker-based Paper position matching across instrument URLs, Multi-Asset Brinson & Greek Return Attribution with disaggregated Dividends, Cash Sweeps & SLIP lending yield coverage (`#278`), native iOS `BGTaskScheduler` / Android OEM battery readiness diagnostics & settings deep-linking (`com.realizealpha.background_execution`), Workmanager & market-calendar Schwab/Paper EOD exit acceptance tests (`#282`), and Android disk-cleanup build workflow | [`docs/agentic-trading.md`](docs/agentic-trading.md), [`docs/portfolio-redesign.md`](docs/portfolio-redesign.md), [`docs/paper-trading-architecture.md`](docs/paper-trading-architecture.md), [`docs/return-attribution.md`](docs/return-attribution.md), [#278](https://github.com/CIInc/robinhood-options-mobile/issues/278), [#282](https://github.com/CIInc/robinhood-options-mobile/issues/282) |
| **v0.61.x (v0.61.0–v0.61.8)** | Pre-release Delivered ✅; acceptance in progress | **Quantitative Derivatives & Execution Hardening:** Macro Regime Walk-Forward Backtesting (`#273`), Options Copy Defined-Risk Guardrails (`#279`), Monte Carlo Derivatives Stress Engine (`#303`), Closed-Form Higher-Order Greeks (Vanna, Charm, Vomma) & 2D Spot × IV Cross-Shock Stress Matrix (`#335`), Dedicated Automated Trading Pending Approvals & Batch Review Center (`#282`), Bounded Startup Waits & Fresh Quote Validation, Market Close Cutoff Safeguards, and Paper Market-Close Exit Reconciliation | [#273](https://github.com/CIInc/robinhood-options-mobile/issues/273), [#279](https://github.com/CIInc/robinhood-options-mobile/issues/279), [#282](https://github.com/CIInc/robinhood-options-mobile/issues/282), [PR #314](https://github.com/CIInc/robinhood-options-mobile/pull/314), [#303](https://github.com/CIInc/robinhood-options-mobile/issues/303), [#335](https://github.com/CIInc/robinhood-options-mobile/issues/335) |
| **v0.62.0** | Planned 🚀 (Target: Q1 2027) | **Execution Safety, Resilient Exits & Simplified Auto-Trading:** 1-Tap Strategy Archetypes (`#343`), Progressive Disclosure UI (`#344`), Pre-Flight Safe Start Wizard (`#345`), Broker-Native Bracket (OTOCO) & OCO Exit Orders & Authoritative Live Account Pinning (`#108`, `#282`), Strategy Backtest-to-Paper-to-Live Drift Monitor & Promotion Gate (`#337`), Trade Lifecycle Timeline & Auditor (`#339`), Automated Earnings Blackout Gate (`#340`), Dynamic ATR Trailing Stops & Profit Ratchet (`#347`), Firebase App Check Production Attestation Transition (`#350`), Schwab Market-Data Parity (`#138`), Reusable Order Templates (`#116`) | [#108](https://github.com/CIInc/robinhood-options-mobile/issues/108), [#116](https://github.com/CIInc/robinhood-options-mobile/issues/116), [#138](https://github.com/CIInc/robinhood-options-mobile/issues/138), [#282](https://github.com/CIInc/robinhood-options-mobile/issues/282), [#337](https://github.com/CIInc/robinhood-options-mobile/issues/337), [#339](https://github.com/CIInc/robinhood-options-mobile/issues/339), [#340](https://github.com/CIInc/robinhood-options-mobile/issues/340), [#343](https://github.com/CIInc/robinhood-options-mobile/issues/343), [#344](https://github.com/CIInc/robinhood-options-mobile/issues/344), [#345](https://github.com/CIInc/robinhood-options-mobile/issues/345), [#347](https://github.com/CIInc/robinhood-options-mobile/issues/347), [#350](https://github.com/CIInc/robinhood-options-mobile/issues/350) |
| **v0.63.0** | Planned 🚀 (Target: Q2 2027) | **Advanced Derivatives, Institutional Flow & Cross-Broker Rebalancing:** Automated Options Yield Harvesting (Covered Calls & CSPs) (`#338`), Autonomous Portfolio Delta-Neutral Hedging & Tail-Risk Armor (`#341`), Automated Gamma Scalping & Delta Rebalancer (`#349`), Market Breadth & Sector Velocity Pre-Entry Gate (`#348`), Multi-Indicator Collinearity & VIF Heatmap (`#305`), Institutional Smart Money vs. Retail Divergence Heatmap (`#336`), Intraday 0DTE Volatility & Net Dealer GEX Radar (`#304`), Automated Earnings Implied Move (`#301`), Batch Rebalancing Order Pad (`#302`), Smart Order Routing (`#108`), Futures Term Structure & SPAN Margin (`#103`, [#104](https://github.com/CIInc/robinhood-options-mobile/issues/104), [#105](https://github.com/CIInc/robinhood-options-mobile/issues/105), [#67](https://github.com/CIInc/robinhood-options-mobile/issues/67), [#106](https://github.com/CIInc/robinhood-options-mobile/issues/106), [#111](https://github.com/CIInc/robinhood-options-mobile/issues/111)) | [#67](https://github.com/CIInc/robinhood-options-mobile/issues/67), [#103](https://github.com/CIInc/robinhood-options-mobile/issues/103), [#104](https://github.com/CIInc/robinhood-options-mobile/issues/104), [#105](https://github.com/CIInc/robinhood-options-mobile/issues/105), [#106](https://github.com/CIInc/robinhood-options-mobile/issues/106), [#108](https://github.com/CIInc/robinhood-options-mobile/issues/108), [#111](https://github.com/CIInc/robinhood-options-mobile/issues/111), [#301](https://github.com/CIInc/robinhood-options-mobile/issues/301), [#302](https://github.com/CIInc/robinhood-options-mobile/issues/302), [#304](https://github.com/CIInc/robinhood-options-mobile/issues/304), [#305](https://github.com/CIInc/robinhood-options-mobile/issues/305), [#336](https://github.com/CIInc/robinhood-options-mobile/issues/336), [#338](https://github.com/CIInc/robinhood-options-mobile/issues/338), [#341](https://github.com/CIInc/robinhood-options-mobile/issues/341), [#348](https://github.com/CIInc/robinhood-options-mobile/issues/348), [#349](https://github.com/CIInc/robinhood-options-mobile/issues/349) |
| **v0.64.0+** | Planned 🚀 (Target: Q3/Q4 2027) | **Multi-Broker Expansion, Market-Neutral StatArb & Quant Platform:** Cointegrated Sector Pairs Arbitrage (`#342`), Natural Language AI Strategy Copilot (`#346`), Plaid Account Linking (`#15`, [#92](https://github.com/CIInc/robinhood-options-mobile/issues/92), [#121](https://github.com/CIInc/robinhood-options-mobile/issues/121)), Fidelity API (`#33`), IBKR (`#30`), OpenAPI Webhook Gateway (`#137`), Desktop/iPad Floating Workspace, Comprehensive Test Coverage (`#90`), 2FA & Hardware Security Enclave (`#88`, [#89](https://github.com/CIInc/robinhood-options-mobile/issues/89)) | [#15](https://github.com/CIInc/robinhood-options-mobile/issues/15), [#30](https://github.com/CIInc/robinhood-options-mobile/issues/30), [#33](https://github.com/CIInc/robinhood-options-mobile/issues/33), [#88](https://github.com/CIInc/robinhood-options-mobile/issues/88), [#89](https://github.com/CIInc/robinhood-options-mobile/issues/89), [#90](https://github.com/CIInc/robinhood-options-mobile/issues/90), [#125](https://github.com/CIInc/robinhood-options-mobile/issues/125), [#137](https://github.com/CIInc/robinhood-options-mobile/issues/137), [#140](https://github.com/CIInc/robinhood-options-mobile/issues/140), [#342](https://github.com/CIInc/robinhood-options-mobile/issues/342), [#346](https://github.com/CIInc/robinhood-options-mobile/issues/346) |

---

## Planned Enhancements 🚀

### v0.62.0: Execution Safety, Resilient Exits & Simplified Auto-Trading (Target: Q1 2027)

#### Auto-Trading Experience & Workflow Simplification
- [x] **1-Tap Curated Strategy Archetypes (Presets) with Walk-Forward Performance Badges** (v0.62.0, [#343](https://github.com/CIInc/robinhood-options-mobile/issues/343), [Tracking: #84](https://github.com/CIInc/robinhood-options-mobile/issues/84), [#109](https://github.com/CIInc/robinhood-options-mobile/issues/109)):
  - Provide 4 curated strategy archetypes (*Conservative Core*, *Momentum Breakout*, *Options Income Harvester*, *Reasoning AI Agent*) that pre-configure all 35 underlying indicators, stops, and risk bounds with a single tap.
  - Surface empirical Walk-Forward Performance Badges (historical 1-year win rate, profit factor, max drawdown) and allow 1-tap cloning to custom presets.
- [ ] **Progressive Disclosure UI (Simplified Mode vs. Quant Pro Mode)** (v0.62.0, [#344](https://github.com/CIInc/robinhood-options-mobile/issues/344), [Tracking: #117](https://github.com/CIInc/robinhood-options-mobile/issues/117), [#282](https://github.com/CIInc/robinhood-options-mobile/issues/282)):
  - Streamline `AgenticTradingSettingsWidget` by introducing a Simplified Mode default showing only 4 essential controls: Strategy Archetype selector, Capital Allocation budget slider, 3-position Risk Comfort toggle (Conservative/Balanced/Aggressive), and Master Emergency Stop.
  - Provide a single-tap Quant Pro Mode toggle expanding granular indicator weights, custom indicators, GEX structural stop thresholds, and OEM background journals.
- [ ] **Pre-Flight "Safe Start" Readiness Wizard & Automated Health Check** (v0.62.0, [#345](https://github.com/CIInc/robinhood-options-mobile/issues/345), [Tracking: #282](https://github.com/CIInc/robinhood-options-mobile/issues/282)):
  - Guide users through a 4-step interactive onboarding flow upon enabling auto-trading: Account & Mode selection $\to$ Capital allocation $\to$ Live pre-flight health validation (OAuth token, cash buffer, quote feed, background task registration, and OEM battery guidance) $\to$ 1-click dry-run simulation cycle.
- [ ] **Auto-Trading Interactive Trade Lifecycle Timeline & Execution Auditor** (v0.62.0, [#339](https://github.com/CIInc/robinhood-options-mobile/issues/339), [Tracking: #282](https://github.com/CIInc/robinhood-options-mobile/issues/282)):
  - Render an interactive, step-by-step decision audit card in `AgenticTradingPerformanceWidget` and trade detail screens tracking the complete order lifecycle: Signal & 19-Indicator convergence $\to$ Macro Regime & GEX context $\to$ Gemini Chain of Thought $\to$ RiskGuard portfolio validation $\to$ Live Quote vs. Execution Fill (slippage in bps) $\to$ Active Bracket Status.
  - Add actionable interactive push notifications for semi-automated (`requireApproval: true`) mode with 1-tap Approve & Submit / Reject actions and mini-sparkline preview.

#### Execution Safety, Drift Protection & Order Parity
- [ ] **Broker-Native Bracket (OTOCO) & One-Cancels-Other (OCO) Exit Protection Orders & Authoritative Account Pinning** (v0.62.0, [#108](https://github.com/CIInc/robinhood-options-mobile/issues/108), [Tracking: #282](https://github.com/CIInc/robinhood-options-mobile/issues/282)):
  - Attach simultaneous Take-Profit Limit and Stop-Loss exit brackets at order entry or pair existing position exits as OCO orders with live Risk:Reward preview and native Schwab conditional order routing.
  - Enforce explicit authoritative live account pinning (`liveAccountPin`) in `AgenticTradingConfig` when multiple brokerages (Robinhood and Schwab) are linked, ensuring orders execute strictly through the user's chosen primary brokerage rather than arbitrary routing.
  - Eliminate vulnerable client-polling TP/SL exits by deploying broker-native stop orders on Robinhood and atomic OTOCO simulated resting orders in the Cloud Functions paper orders engine.
- [ ] **Strategy Backtest-to-Paper-to-Live Execution Drift Monitor & Promotion Readiness Gate** (v0.62.0, [#337](https://github.com/CIInc/robinhood-options-mobile/issues/337), [Tracking: #282](https://github.com/CIInc/robinhood-options-mobile/issues/282), [#137](https://github.com/CIInc/robinhood-options-mobile/issues/137)):
  - Compare realized Paper and Live auto-trading win rate, profit factor, average fill slippage, and max drawdown in `AgenticTradingPerformanceWidget` against the active strategy template's walk-forward backtest baseline.
  - Enforce a configurable Paper-to-Live Promotion Readiness Gate in `AgenticTradingSettingsWidget` (requiring $\ge 25$ completed simulated trades, Profit Factor $\ge 1.35$, Win Rate $\ge 50\%$, and Max Drawdown $\le 10\%$, with an explicit 2-step user safety override).
  - Require the user to pin an authoritative live account (`liveAccountPin`) when enabling Live auto-trading, preventing accidental cross-broker order dispersion while preserving multi-broker balance awareness.
  - Support an optional `autoDemoteToPaperOnDrift` safeguard in `AgenticTradingProvider` that automatically reverts live execution to simulated Paper mode if realized live drawdown or win-rate degradation breaches $2\sigma$ of walk-forward expectation.
- [ ] **Automated Earnings Blackout Gate & Pre-Earnings IV Expansion Harvester** (v0.62.0, [#340](https://github.com/CIInc/robinhood-options-mobile/issues/340), [Tracking: #301](https://github.com/CIInc/robinhood-options-mobile/issues/301), [#137](https://github.com/CIInc/robinhood-options-mobile/issues/137)):
  - Automatically pause automated equity entries for symbols with corporate earnings announcements within a configurable pre-earnings window (default: 3–5 days) to eliminate binary gap and IV crush risk.
  - Surface an opt-in Pre-Earnings IV Expansion Harvester strategy entering calendar or straddle positions 10–14 days prior to earnings and closing them 24 hours before the release.
- [ ] **Schwab Market-Data & Order-Lifecycle Parity** (v0.62.0, [#138](https://github.com/CIInc/robinhood-options-mobile/issues/138)): Complete the remaining quote, OHLCV, fundamentals, movers, order-preview, margin-check, and in-flight replacement coverage.
- [ ] **Reusable Crypto & Forex Order Templates** (v0.62.0, [#116](https://github.com/CIInc/robinhood-options-mobile/issues/116)): Save and reuse instrument-specific order configurations while preserving live price and risk validation.
- [ ] **Volatility-Adaptive Dynamic ATR Trailing Stops & Profit Ratchet** (v0.62.0, [#347](https://github.com/CIInc/robinhood-options-mobile/issues/347), [Tracking: #282](https://github.com/CIInc/robinhood-options-mobile/issues/282)):
  - Dynamically scale ATR stop-loss and take-profit multipliers based on the asset's realized volatility percentile and ATR expansion/contraction.
  - Implement a dynamic ratchet mechanism in `AgenticTradingProvider` widening stops during volatility compression to prevent whipsaws and tightening trailing stops when ATR expands.
  - Surface active dynamic ATR trailing stop levels and profit targets in `AutomatedTradeProposalDetailWidget` and position order cards.

#### Infrastructure, Security & Platform Attestation
- [ ] **Firebase App Check Production Attestation & Enforcement Transition (Target Due Date: January 21, 2027)** (v0.62.0, [#350](https://github.com/CIInc/robinhood-options-mobile/issues/350)):
  - Transition Firebase Vertex AI / Agent Platform (`firebase_ai`) from temporary monitoring to full hardware-backed device attestation prior to the January 21, 2027 enforcement deadline.
  - Implement Apple App Attest with DeviceCheck fallback (`AppleAppAttestWithDeviceCheckFallbackProvider()`) for iOS/macOS production builds with registered Apple Developer `.p8` signing keys and Team IDs in Firebase Console.
  - Link Google Cloud Project `realizealpha` to Google Play Integrity API and register release signing SHA-256 certificate fingerprints in Firebase Console.
  - Establish friction-free local developer/simulator workflows using Xcode Scheme launch arguments (`-FIRDebugTestingToken <DEBUG_TOKEN>`) and registered debug tokens.
  - Track verified vs. unverified request ratios in Firebase App Check API metrics until reaching $\ge 99\%$ verified traffic before toggling production enforcement.

---

### v0.63.0: Advanced Derivatives, Institutional Flow & Cross-Broker Rebalancing (Target: Q2 2027)

#### Derivatives, Options & Futures Analytics
- [ ] **Automated Systematic Options Yield Harvesting (Covered Calls & Cash-Secured Puts)** (v0.63.0, [#338](https://github.com/CIInc/robinhood-options-mobile/issues/338), [Tracking: #109](https://github.com/CIInc/robinhood-options-mobile/issues/109), [#137](https://github.com/CIInc/robinhood-options-mobile/issues/137)):
  - Scan held equity inventory ($\ge 100$ shares) for technical overbought extremes ($RSI > 70$) to automatically write delta $0.20-0.30$ covered calls ($21-45$ DTE, annualized yield $\ge 12\%$).
  - Systematically evaluate cash-secured put (CSP) writing at key support / Pivot levels on qualified BUY setups when cash balance supports full assignment.
  - Enforce automated defensive roll triggers if short legs are tested, integrating with the Multi-Leg Options Defense Playbook.
- [ ] **Autonomous Portfolio Delta-Neutral Hedging & Tail-Risk Armor** (v0.63.0, [#341](https://github.com/CIInc/robinhood-options-mobile/issues/341), [Tracking: #303](https://github.com/CIInc/robinhood-options-mobile/issues/303), [#335](https://github.com/CIInc/robinhood-options-mobile/issues/335), [#158](https://github.com/CIInc/robinhood-options-mobile/issues/158)):
  - Calculate real-time portfolio Beta-Weighted Net Delta ($\Delta_{\text{SPY}}$) and Monte Carlo path-dependent 95% CVaR across all held stock and options positions.
  - Automatically evaluate and deploy defined-risk index put vertical spreads or inverse ETF hedges when macro regime shifts to Bear High-Vol or dealer positioning flips negative, capped by a strict `maxHedgingBudgetPercent` (1–2% of portfolio equity).
- [ ] **Automated Earnings Implied Move vs. Historical Realized Move & Straddle Mispricing Analyzer** (v0.63.0, [#301](https://github.com/CIInc/robinhood-options-mobile/issues/301), [Tracking: #118](https://github.com/CIInc/robinhood-options-mobile/issues/118), [#137](https://github.com/CIInc/robinhood-options-mobile/issues/137)):
  - Display ATM straddle implied move ($0.84 \times \text{straddle price}$) and expected price range for equities with earnings dates within 30 days.
  - Correlate historical earnings dates with daily bars over prior 8–12 quarters to compute average actual 1-day move, max move, and volatility crush frequency.
  - Surface an Earnings Implied Move Card in `OptionChainWidget` and stock detail pages with historical IV crush metrics and expected value indicators.
- [ ] **Intraday 0DTE Volatility, Net Dealer GEX & Pin Magnetism Radar** (v0.63.0, [#304](https://github.com/CIInc/robinhood-options-mobile/issues/304), [Tracking: #134](https://github.com/CIInc/robinhood-options-mobile/issues/134), [#137](https://github.com/CIInc/robinhood-options-mobile/issues/137)):
  - Isolate 0DTE/1DTE options contracts to compute real-time strike-by-strike Gamma Exposure (GEX) and intraday Zero Gamma / Gamma Flip levels.
  - Pinpoint the 4:00 PM Pin Magnet Strike (highest gamma concentration and open interest driving market-maker hedging compression).
  - Track intraday Charm decay and expected market-maker re-hedging flows over 1–3 hour windows with 250ms stream throttling.
- [ ] **Futures Contract Roll Assistant, Term Structure & Contango/Backwardation Analyzer** (v0.63.0, [#103](https://github.com/CIInc/robinhood-options-mobile/issues/103), [#104](https://github.com/CIInc/robinhood-options-mobile/issues/104), [#105](https://github.com/CIInc/robinhood-options-mobile/issues/105)):
  - Expiration and First Notice countdown alerts, front-to-back contract term-structure curve (contango/backwardation roll yield), contract specifications, and guided calendar roll assistant.
- [ ] **Futures SPAN Margin Health, Liquidation Distance & Intraday Seasonality Analytics** (v0.63.0, [#67](https://github.com/CIInc/robinhood-options-mobile/issues/67), [#106](https://github.com/CIInc/robinhood-options-mobile/issues/106), [#111](https://github.com/CIInc/robinhood-options-mobile/issues/111)):
  - Per-contract and aggregate futures Initial/Maintenance Margin utilization, effective notional leverage, estimated liquidation price / ATR shock cushion, and Action Center low-buffer alerts.
- [ ] **Automated Options Gamma Scalping & Dynamic Delta Rebalancing** (v0.63.0, [#349](https://github.com/CIInc/robinhood-options-mobile/issues/349), [Tracking: #335](https://github.com/CIInc/robinhood-options-mobile/issues/335), [#341](https://github.com/CIInc/robinhood-options-mobile/issues/341)):
  - Automate rule-based gamma scalping on held long option volatility positions (straddles, strangles, vertical spreads) by submitting offsetting underlying equity share orders when net position delta drifts beyond a configurable threshold ($|\Delta_{\text{net}}| \ge 25$).
  - Systematically capture intraday underlying share oscillations to offset option theta decay while resetting net delta to neutral ($|\Delta_{\text{net}}| \le 5$).
  - Surface a real-time Gamma Scalp Ledger in `AgenticTradingPerformanceWidget` tracking round-trip equity scalp cash flow against option decay.

#### Quantitative Research & Institutional Flow
- [ ] **Multi-Indicator Signal Collinearity & Alpha Redundancy Heatmap** (v0.63.0, [#305](https://github.com/CIInc/robinhood-options-mobile/issues/305), [Tracking: #137](https://github.com/CIInc/robinhood-options-mobile/issues/137)):
  - Compute pairwise Pearson correlation matrix and Variance Inflation Factor (VIF) across all 19 technical indicators over historical bars.
  - Group indicators into 5 orthogonal clusters (Trend, Momentum, Volatility, Volume, Structure) and apply VIF weighting in `agentic-trading.ts` so collinear oscillators do not artificially inflate signal confidence.
  - Surface an interactive $19 \times 19$ Factor Collinearity Heatmap in `BacktestingWidget` and `MacroAssessmentDashboardWidget`.
  - Warn when strategy indicators have correlation $> 0.80$ to eliminate redundant oscillator/trend signals and prevent curve-fitting.
- [ ] **Institutional "Smart Money" vs. Retail Positioning Divergence Heatmap & Multi-Signal Convergence Scorer** (v0.63.0, [#336](https://github.com/CIInc/robinhood-options-mobile/issues/336), [Tracking: #137](https://github.com/CIInc/robinhood-options-mobile/issues/137)):
  - Contrast normalized institutional/insider flow (13F whale accumulation, SEC Form 4 open-market cluster buys, Congressional STOCK Act disclosures, unusual options sweeps) against Retail Net Buy/Sell Order Flow across portfolio and watchlist symbols.
  - Compute a deterministic Multi-Signal Convergence Score when $\ge 2$ independent institutional datasets align within a rolling 30-day window, with explicit filing-lag provenance badges (`T+0` Options Sweep, `T+2` Form 4, `T+30` STOCK Act, `T+45` 13F).
  - Integrate institutional-vs-retail divergence into `FactorAlignmentService` and `PortfolioAlertService`.
- [ ] **Cross-Asset Market Breadth & Sector Velocity Pre-Entry Gate** (v0.63.0, [#348](https://github.com/CIInc/robinhood-options-mobile/issues/348), [Tracking: #137](https://github.com/CIInc/robinhood-options-mobile/issues/137)):
  - Compute sector ETF relative momentum (5-day and 20-day return vs. SPY) and breadth metrics across the 11 major SPDR sector ETFs.
  - In `agentic-trading.ts` and `AgenticTradingProvider`, evaluate sector momentum before qualifying individual stock proposals, suppressing BUY proposals in decaying sectors and prioritizing leading sectors.
  - Display a Sector Alignment Badge (`Sector Leading 🟢`, `Sector Neutral ⚪`, `Sector Lagging 🔴`) in the Pending Approvals review interface.

#### Execution & Cross-Broker Optimization
- [ ] **Multi-Account Batch Rebalancing Order Pad & Cross-Broker Allocation Executor** (v0.63.0, [#302](https://github.com/CIInc/robinhood-options-mobile/issues/302), [Tracking: #108](https://github.com/CIInc/robinhood-options-mobile/issues/108), [#277](https://github.com/CIInc/robinhood-options-mobile/issues/277)):
  - Convert Risk Parity or custom target weight drift into concrete, validated Buy/Sell limit orders across connected Robinhood and Schwab accounts.
  - Support configurable minimum trade thresholds, cash reserve buffers, and tax-aware lot selection (prioritizing high-cost lots in taxable accounts).
  - Provide a dry-run staging sheet with per-order toggles, estimated execution values, and sequential execution with circuit breaker verification.
- [ ] **Smart Order Routing (SOR) & Cross-Broker Margin & Borrow Optimizer** (v0.63.0, [#108](https://github.com/CIInc/robinhood-options-mobile/issues/108)):
  - Dynamically evaluate and route equity/option orders between connected brokerages (Robinhood and Schwab) to minimize margin requirements, borrow fees, and maximize uninvested cash yields.

---

### v0.64.0+: Multi-Broker Expansion, Market-Neutral StatArb & Quant Platform (Target: Q3/Q4 2027)

#### Quantitative Research & Algorithmic Trading
- [ ] **Cointegrated Sector Pairs & Market-Neutral Statistical Arbitrage Engine** (v0.64.0+, [#342](https://github.com/CIInc/robinhood-options-mobile/issues/342), [Tracking: #305](https://github.com/CIInc/robinhood-options-mobile/issues/305), [#137](https://github.com/CIInc/robinhood-options-mobile/issues/137)):
  - Compute rolling Engle-Granger cointegration tests and Augmented Dickey-Fuller (ADF) statistics across liquid sector equity and ETF pairs.
  - Execute atomic dual-leg entry (Long Asset A + Short Asset B) when the normalized spread diverges by $\ge 2.0\sigma$, with automatic mean-reversion unwinds ($Z \to 0.0$) and divergence stop-losses ($Z \ge 3.5\sigma$).
- [ ] **Natural Language AI Strategy Copilot & Instant Mini-Backtest Tuning** (v0.64.0+, [#346](https://github.com/CIInc/robinhood-options-mobile/issues/346), [Tracking: #84](https://github.com/CIInc/robinhood-options-mobile/issues/84), [#109](https://github.com/CIInc/robinhood-options-mobile/issues/109)):
  - Conversational Gemini-powered strategy designer translating plain-English trader requests into strictly validated `TradeStrategyConfig` schemas with parameter diff cards.
  - Run instant on-device 60-day mini-backtests over cached S&P 500 bars to provide immediate win rate, profit factor, and drawdown feedback before applying.

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
- [x] **Multi-Asset Brinson Performance & Greek Return Attribution** (v0.60.3, [docs](docs/return-attribution.md), [#278](https://github.com/CIInc/robinhood-options-mobile/issues/278)): On-device Brinson-Fachler sector attribution (allocation, selection, interaction), second-order option Greek Taylor expansion ($\Delta, \Gamma, \Theta, \nu$), disaggregated income & yield attribution (paid dividends, cash sweeps & interest with daily sweep accrual estimates, and SLIP securities lending with daily lending accrual estimates), balance masking, and CSV export.
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
- [x] **Curated Strategy Archetypes & Walk-Forward Performance Badges** (v0.62.0, [docs](docs/agentic-trading.md), [#343](https://github.com/CIInc/robinhood-options-mobile/issues/343)): 4 professionally curated strategy presets (*Conservative Core*, *Momentum Breakout*, *Options Income Harvester*, *Reasoning AI Agent*) pre-configuring 35 underlying indicators, stops, and risk bounds with empirical 1-year walk-forward backtest win rate, profit factor, max drawdown badges, and 1-tap custom preset cloning.
- [x] **Automated Trading Pending Approvals Dedicated View & Batch Review Center** (v0.61.8, [#282](https://github.com/CIInc/robinhood-options-mobile/issues/282), [Tracking: #137](https://github.com/CIInc/robinhood-options-mobile/issues/137)): Standalone review interface (`AutomatedTradingApprovalsWidget`) with Pending and History tabs, action and qualification filtering, multi-field sorting, and summary metrics with balance masking; deep proposal inspection (`AutomatedTradeProposalDetailWidget`) with AI conviction quotes, institutional GEX levels, macro regime status, RiskGuard compliance, and live chart links; multi-selection batch approval and rejection (`AgenticTradingProvider.batchApproveOrders`, `batchRejectOrders`) with individual live-quote deviation guards and confirmation sheets; rejection audit tracking in Firestore (`auto_trade_history`); and push notification deep linking (`agentic_approval`, `pending_approval`).
- [x] **Reliable Auto-Trading Execution Modes & EOD Exit Acceptance** (v0.60.4, [docs](docs/agentic-trading.md), [#282](https://github.com/CIInc/robinhood-options-mobile/issues/282)): Foreground execution, Paper/Live quote-source isolation, market-calendar & Schwab/Paper EOD exit acceptance tests (`attempted`, `completed`, and `missed` across regular, early-close, and holiday sessions), `AgenticTradingBackgroundService.runOnce` lifecycle harness tests, native `com.realizealpha.background_execution` iOS `BGTaskScheduler` / Android OEM battery readiness checks, and 1-tap Settings deep-linking in `AgenticTradingSettingsWidget`.
- [x] **19-Indicator Technical Correlation Engine**: Multi-indicator analysis combining RSI, MACD, Bollinger Bands, Stochastic, ATR, ADX, CCI, MFI, OBV, VWAP, Ichimoku, Parabolic SAR, Keltner Channels, Williams %R, Donchian, Pivot Points, and SMA/EMA crossovers in $O(1)$ space.
- [x] **Multi-Timeframe Trade Signals**: 15m, 1h, and 1d signal generation with confidence weighting and market trend filtering.
- [x] **Macro Assessment Regime Conditioning**: Global market direction and volatility regime classification conditioning live signal generation.
- [x] **On-Device Agentic Auto-Trading Engine**: Automated and semi-automated trade generation with Paper Trading simulation, emergency stop persistent sync, and fail-closed leasing.
- [x] **Dual Broker Support (Robinhood & Schwab)**: Selected-broker auto-trading routing orders directly through the active brokerage implementation.

### Derivatives, Quantitative Research & Backtesting
- [x] **Higher-Order Portfolio Greeks (Vanna, Charm & Vomma) & 2D Spot $\times$ IV Cross-Shock Stress Matrix** (v0.61.7, [#335](https://github.com/CIInc/robinhood-options-mobile/issues/335), [Tracking: #137](https://github.com/CIInc/robinhood-options-mobile/issues/137)): Closed-form Black-Scholes second-order cross-Greeks (`Vanna` $\partial \Delta / \partial \sigma$, `Charm` $-\partial \Delta / \partial \tau$, and `Vomma` $\partial \mathcal{V} / \partial \sigma$) in `AnalyticsUtils` and `DeltaNeutralService`, interactive 2D Spot $\times$ IV Cross-Shock Stress Matrix ($\Delta S \in [-10\%, +10\%] \times \Delta \text{IV} \in [-20\%, +20\%]$) in `PortfolioGreeksCard` and `DeltaNeutralBuilderWidget` toggling between projected P&L and post-shock Net Delta, and 24h / Weekend Charm Delta-Drift net delta bleed indicator.
- [x] **Monte Carlo Derivatives & Portfolio Stress Engine** (v0.61.6, [#303](https://github.com/CIInc/robinhood-options-mobile/issues/303), [Tracking: #137](https://github.com/CIInc/robinhood-options-mobile/issues/137)): 1,000 to 5,000 synthetic forward paths (30d–365d) via GBM, Student's t, and historical bootstrap, path-dependent 95% and 99% CVaR (Expected Shortfall), maximum drawdown distributions, margin breach / ruin probability, non-linear options Greek Taylor decay along paths, and fan chart percentiles card in Risk section.
- [x] **Macro Regime & GEX-Conditioned Strategy Backtest Attribution (Walk-Forward Validation)** (v0.61.0, [#273](https://github.com/CIInc/robinhood-options-mobile/issues/273), [Tracking: #137](https://github.com/CIInc/robinhood-options-mobile/issues/137)): Tag simulated trades in `backtesting.ts` with market regime (Bull/Bear $\times$ Low/High-Vol) derived from SPY trend and ATR percentiles in $O(1)$ space, per-regime performance metrics, 70/30 in-sample/out-of-sample split detecting curve-fitting, and interactive Regime Attribution card with 1-tap filtering.
- [x] **0DTE Flow & Intraday Gamma Squeeze Radar** (v0.51.0): Real-time monitoring of 0DTE flow velocity, dealer gamma flip thresholds, and gamma squeeze risk alerts.
- [x] **Implied Volatility Surface 3D Visualizer** (v0.51.5): Interactive 3D surface plot across strikes and expiration dates with regularized grid interpolation and Dupire local volatility.
- [x] **Realized vs. Implied Volatility (IV) Cone & Rank/Percentile** (v0.51.4): Multi-timeframe IV percentiles (30d/60d/90d) and volatility skew surfaces.
- [x] **Earnings IV Crush Probability & Straddle Pricing Estimator** (v0.51.3): Implied earnings move vs. actual historical moves over 12 quarters and expected value straddle pricing distributions.
- [x] **Delta-Neutral Strategy Builder** (v0.51.6): Dynamic delta offsets, automated share/option rebalancing suggestions, and spot-shift scenario simulation.
- [x] **Strategy Validator & Historical Backtesting Engine** ([#136](https://github.com/CIInc/robinhood-options-mobile/issues/136)): Cloud Functions v2 backtest runner evaluating multi-indicator templates over historical OHLCV data.
- [x] **Alpha Factor Discovery & Event Study Analyzer**: Dynamic volatility, beta, and correlation tracking around earnings and catalyst windows.

### Copy Trading & Risk Guardian
- [x] **Options Contract Adaptation & Defined-Risk Inverse Guardrails for Copy Trading** (v0.61.6, [#279](https://github.com/CIInc/robinhood-options-mobile/issues/279), [Tracking: #141](https://github.com/CIInc/robinhood-options-mobile/issues/141)): Block naked short option generation in inverse copy mode by mapping short contracts to defined-risk opposite-direction spreads (e.g. short call $\to$ long put or defined bear call spread), and suggest delta/DTE-matched strikes or vertical spreads when single contract exceeds follower capital allocation cap.
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
