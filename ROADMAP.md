# Roadmap

This document outlines the planned features and enhancements for RealizeAlpha.

## Table of Contents

- [Summary](#summary)
- [Release Versions & Timeline](#release-versions--timeline)
- [Risks & Blockers](#risks--blockers)
- [Completed Features ✅](#completed-features-)
  - [Investor Groups & Social Platform](#investor-groups--social-platform)
  - [Trade Signals & AI Trading](#trade-signals--ai-trading)
  - [Quantitative Research](#quantitative-research)
  - [Backtesting](#backtesting)
  - [Copy Trading](#copy-trading)
  - [Futures Trading](#futures-trading)
  - [Data Persistence](#data-persistence)
  - [Portfolio Visualization](#portfolio-visualization)
  - [Trading & Execution](#trading--execution)
  - [Brokerage & Asset Expansion](#brokerage--asset-expansion)
  - [AI & Insights](#ai--insights)
  - [Notifications & Smart Alerts](#notifications--smart-alerts)
  - [Cash Management, Banking & Retirement](#cash-management-banking--retirement)
  - [Infrastructure & Security](#infrastructure--security)
- [Planned Enhancements 🚀](#planned-enhancements-)
  - [Delivery Priorities](#delivery-priorities)
  - [Portfolio & Analysis](#portfolio--analysis)
  - [Trading & Automation](#trading--automation)
  - [Social & Community](#social--community)
- [Platform Foundation & Operations](#platform-foundation--operations)
  - [App Experience](#app-experience)
  - [Infrastructure & Security](#infrastructure--security)
  - [Data & Integration](#data--integration)
  - [Technical Excellence](#technical-excellence)
- [Future Horizons](#future-horizons)
  - [Advanced Derivatives](#advanced-derivatives)
  - [Quantitative & Strategy](#quantitative--strategy)
  - [Social & Education](#social--education)
  - [Frontier Tech](#frontier-tech)
- [Feedback & Contribution](#feedback--contribution)

## Summary

**RealizeAlpha** is a mobile trading platform for multi-account investing, trading, and options analytics. This roadmap separates delivered work from planned milestones and longer-term ideas. Check marks indicate implementation status; future dates are targets and may change. GitHub issues hold detailed requirements and discussion.

**Last reviewed:** September 23, 2026 · **Current app version:** 0.52.0 (development version)

### Quick Stats
- **Completed checklist items:** 361
- **Planned checklist items:** 82
- **Open GitHub issues:** 37 (as of September 23, 2026)
- **Planning focus:** Address high-priority reliability and test gaps, then deliver copy-trading transparency and safeguards; scope community work only after trust, moderation, and measurement criteria are defined.

### Key Highlights
- ✅ **Recently Completed (v0.51.0-v0.52.0):** Beta-weighted portfolio Greeks, automated DRIP thresholds, 0DTE gamma squeeze radar, earnings IV crush analysis, IV cone and surface, Delta-Neutral Strategy Builder, Copy-Trading Slippage & Fill Divergence Analytics, Automated Copy-Trading Risk Guardian, Side-by-Side Multi-Trader Portfolio Comparison, and Social Discussion & Comment Threads. See the release timeline for issue links and details.
- **Next proposed milestone:** **v0.52.0 (target: December 2026; tentative)** — copy-trading transparency and safeguards, with social discussion delivered and verified. Tournaments remain exploratory until separately defined.
- **Later candidates (v0.53.0+):** Schwab execution and account-history improvements, multi-broker routing, SEC disclosures, and expanded AI research. These are planning targets, not release commitments.
- **Longer-term exploration:** Desktop workflows, privacy-preserving performance proofs, wearable clients, and spatial interfaces remain exploratory until scoped and prioritized.

## Release Versions & Timeline

Mapping features to specific versions helps users anticipate releases and understand what's coming:

### v0.29.2 ✅ (Released Jan 20, 2026)
**Instrument Notes, AI Asset Allocation & Strategy Optimization**
- ✅ **Instrument Notes**: Private, markdown-formatted instrument notes with AI drafting.
- ✅ **AI Asset Allocation**: Risk-profile based portfolio weighting recommendations in Rebalancing tool.
- ✅ **Natural Language Portfolio Construction**: Chat-based portfolio requests ("Build me a growth portfolio") via Market Assistant.
- ✅ **Strategy Optimization**: Backtesting engine enhancement to refine strategy parameters.
- ✅ **Market Assistant**: Improved chat prompts and structured responses.
- ✅ **Portfolio Calculation**: Refined cumulative return logic for accuracy.

### v0.30.0 ✅ (Released Jan 22, 2026)
**Portfolio Analytics & Custom Benchmarks**
- ✅ **Custom Benchmarks:** Compare portfolio against any ticker (e.g. BTC-USD, AAPL, NVDA)
- ✅ **Improved Benchmark Selector:** Quick chips for standard and custom indices
- ✅ **Analytics Fixes:** Correct data syncing for custom timeframes
- ✅ **Cash Allocation:** Enhanced handling of short-term treasuries as cash equivalents

### v0.30.1 ✅ (Released Jan 24, 2026)
**Trade Signals & In-App Subscriptions**
- ✅ **Trade Signals Widget:** Dedicated widget for displaying and filtering trade signals
- ✅ **In-App Purchases:** Integrated subscription support for premium features
- ✅ **Enhanced Signal Search:** Filter signals by specific indicators and strategy templates
- ✅ **Strategy Enhancements:** Refactored configuration for better template management
- ✅ **Chat Improvements:** Smoother scrolling and message handling

### v0.31.0 ✅ (Released Jan 28, 2026)
**Macro Logic, Paper Trading & Biometrics**
- ✅ **Macro Assessment:** Integrated macro assessment logic into trading engine.
- ✅ **Paper Trading:** Expanded paper trading functionality across various widgets.
- ✅ **Group Messaging:** Notifications and read receipts for Investor Groups.
- ✅ **Biometrics:** FaceID/TouchID authentication support.
- ✅ **Testing & CI:** Integration tests and improved CI/CD workflows.

### v0.31.1 ✅ (Released Jan 28, 2026)
**Futures Enhancements & Auto-Trade History**
- ✅ **Futures Positions:** Historical data fetching and display.
- ✅ **Futures P&L:** Realized P&L and Day P&L calculations.
- ✅ **Agentic Trading:** Auto-trade history loading from Firestore.

### v0.31.2 ✅ (Released Jan 29, 2026)
**Options Flow & Agentic Filtering**
- ✅ **Options Flow:** Added 0DTE/1DTE expiration filtering.
- ✅ **Agentic Experience:** Paper mode filtering in performance widget.

### v0.31.3 ✅ (Released Jan 31, 2026)
**New Indicators & Risk Off**
- ✅ **New Indicators:** ROC, Chaikin Money Flow, Fibonacci Retracements.
- ✅ **Strategies:** MACD Zero Line Cross, Bollinger Squeeze.
- ✅ **Risk Guard:** `skipRiskGuard` support and macro-based position sizing.

### v0.31.4 ✅ (Released Feb 1, 2026)
**Paper Portfolio AI & Alpha Discovery**
- ✅ **Paper Trading Dashboard:** AI Portfolio Analysis and Allocation Charts.
- ✅ **Alpha Factor Discovery:** Research engine for signal correlation analysis.
- ✅ **Pivot Points:** Support for Classic, Fibonacci, Woodie, Camarilla.
- ✅ **Charts:** TTM Squeeze visualization.
- ✅ **iOS:** Build process enhancements.

### v0.31.5 ✅ (Released Feb 1, 2026)
**Backtest Filtering & CI Enhancements**
- ✅ **Backtesting:** Advanced filtering options for backtest results.
- ✅ **Backtesting:** Improved UI layout for results.
- ✅ **Charts:** Enhanced layout for portfolio metrics.
- ✅ **CI/CD:** Infrastructure improvements.

### v0.31.6 ✅ (Released Feb 06, 2026)
**Multi-Account Aggregation & Fidelity Import**
- ✅ **Multi-Account Aggregation:** View and manage positions across multiple accounts simultaneously with aggregate trading controls.
- ✅ **Fidelity Integration:** Import positions and history via CSV.
- ✅ **Analytics Export:** Export portfolio analytics to CSV.
- ✅ **Asset Allocation:** Enhanced color mapping and Cash ETF support.

### v0.31.7 ✅ (Released Feb 06, 2026)
**Investor Groups & Rich Notifications**
- ✅ **Investor Groups:** Group Watchlists for collaborative instrument tracking.
- ✅ **Group Analytics:** Performance analytics and leaderboards for investor groups.
- ✅ **Rich Notifications:** Actionable push notifications for Agentic Trading and signals.

### v0.32.0 ✅ (Released Feb 11, 2026)
**Home Widgets & Custom Alerts**
- ✅ **Home Screen Widgets:** iOS widgets for portfolio, watchlists, and trade signals with deep linking.
- ✅ **Custom Alerts:** Configurable price and event-based alerts for instruments and portfolio.
- ✅ **Trade Notifications:** Enhanced with Firestore storage and search/filter functionality.
- ✅ **Options Flow:** Improved minimum premium filtering and loading mechanism.
- ✅ **CI/CD:** Xcode setup enhancements for iOS builds.

### v0.33.0 ✅ (Released Feb 18, 2026)
**Macro Assessment & Paper Trading Robustness**
- ✅ **Macro Assessment:** Enhanced tracking for previous assessments and new indicators (Put/Call, A/D, Risk Appetite).
- ✅ **Paper Trading:** Robust `PaperService` for simulated order execution and offline portfolio management.
- ✅ **Deep Linking:** Implemented sharing functionality for instruments and referral codes.
- ✅ **Mobile CI/CD:** Detailed documentation and standardized setup for iOS/Android configurations.
- ✅ **Testing:** Integrated `fake_cloud_firestore` for improved service-layer unit testing.

### v0.33.1 ✅ (Released Feb 22, 2026)
**Rebalancing Automation & Option Flow Alerts**
- ✅ **Rebalancing Scheduler:** Automated drift checks with configurable frequency and notifications.
- ✅ **Rebalancing UX:** Macro guidance, fixed income presets, and initial allocation defaults.
- ✅ **Option Flow Alerts:** Targeted notifications for flow criteria with a dedicated notifications UI.
- ✅ **Macro Assessment:** Expanded dashboard experience and navigation support.
- ✅ **History Widget:** Loading skeleton and shimmer state for smoother loading.

### v0.34.0 ✅ (Released Mar 6, 2026)
**Futures Auto-Trading & Signal Visualization**
- Futures auto-trading provider, settings UI, performance dashboard, and home cards
- Agentic futures trading backend and cron scheduling
- Weighted signal strength alignment (70/30 thresholds) and signal sparklines
- Subscription paywall reliability improvements (startup init, restore/purchase feedback)

### v0.34.1 ✅ (Released Mar 19, 2026)
**Twelve Data Integration & Whale Watch Features**
- ✅ **Whale Watch Tracker:** Institutional accumulation and large transaction dashboard.
- ✅ **Twelve Data Integration:** Real-time options and market data fetching from Twelve Data.
- ✅ **Market Sentiment:** Enhanced dashboard and card widgets for market-wide and trending sentiment.
- ✅ **Macro Assessment Dash:** Signal breadth distribution and divergence detection.
- ✅ **Backend Improvements:** Firebase functions v7.1.1 and Twelve Data fallback to Fidelity.

### v0.34.2 ✅ (Released Mar 23, 2026)
**Trade Signal Metadata & Position Stability Fixes**
- ✅ **Signal Date Metadata:** Added `date` field to trade signals for improved tracking and sorting.
- ✅ **Signal Migration:** Backend utility to backfill `date` field for existing Firestore signals.
- ✅ **Position Stability:** Resolved runtime crashes when updating positions from quote store.
- ✅ **Backend Improvements:** Upgraded `firebase-functions` to v7.2.2.

### v0.34.3 ✅ (Released Mar 25, 2026)
**Advanced Macro Analysis & Strategy Precision**
- ✅ **Macro Multi-Index:** Implemented 19-indicator weighted scoring (MOVE, KRE, Credit Spreads, Breadth).
- ✅ **Regime Logic:** Enhanced signal-regime alignment for regime-aware position sizing.
- ✅ **UI Pulse:** Redesigned Macro Dashboard with indicator detail sheets and weighted heatmaps.
- ✅ **Search Stability:** Fixed navigation issues in Search widget when filtering signals.
- ✅ **Cron Efficiency:** Added weekend-aware skipping for macro refresh jobs.

### v0.35.3 ✅ (Released Jun 10, 2026)
**GEX Sensitivity Dashboard & Workflow Polish**
- ✅ **GEX Sensitivity Dashboard:** Added spot-shift stress testing with a visual curve and summary breakdown for changing dealer exposure regimes.
- ✅ **Pinning Gauge:** Added a market maker pinning gauge tied to Call Wall, Put Wall, Gamma Flip, and current spot.
- ✅ **GEX Navigation Improvements:** Added instrument preview/navigation shortcuts and expandable top-N leader controls in the dashboard.
- ✅ **Login Reliability:** Added prompt challenge polling to improve brokerage authentication flow recovery.
- ✅ **Compatibility & Test Updates:** Updated Android compatibility/version metadata and improved GEX and integration test coverage.

### v0.35.0 ✅ (Released Jun 7, 2026)
**Advanced Gamma Exposure (GEX) Pro**
- ✅ **On-Device GEX Calculations:** Built standard mathematical failover engine in Dart to run Black-Scholes gamma derivations locally during server-side limit thresholds.
- ✅ **Interactive GEX Coordinate Charts:** Custom horizontal bar plots with vertical translate touch points, highlighting specified strike details and Call/Put wall margins.
- ✅ **Top GEX Leaders Panel:** High-liquidity contract ranking board visualizing structural dealer volume bias.
- ✅ **Responsive Strike Card Headers:** Corrected layout overflows on the strike tracking detail panels.

### v0.36.0 ✅ (Released Jul 7, 2026)
** Robinhood Model Context Protocol (MCP) Client, Interactive Conversational Trade Boards, & Selected Account Sync**
- ✅ **Native Local MCP Client:** Integrated `package:mcp_dart` in the generative service for secure broker-actions tool calling.
- ✅ **MCP OAuth Flow Webview:** Secure web-based authentication flow for brokerage-connected AI execution.
- ✅ **Interactive Toolboard Trace Cards:** Built collapsible, detail-oriented inline tool execution components with Json pretty-formatting and paging controls.
- ✅ **Conversational Trading Proposals:** Implemented automated proposal parsing (`[TRADE_PROPOSAL]`) into native order cards with reviewer controls and live API execution checks.
- ✅ **Multi-Account Selector & Active Sync:** Created global account choice state synced to SharedPreferences and mapped to interactive checkable list controls under User Settings.
- ✅ **Platform Compliance & Cleanup:** Registered hardware permission descriptions in plist files, upgraded native compilation dependencies, and removed legacy Plaid library remnants.

### v0.36.1 ✅ (Released July 24, 2026)
**GEX Strategy Suite & Technical Exits**
- ✅ **GEX Strategy Suite**: Professional templates for Mean Reversion, Trend Acceleration, and Intraday Scalping using dealer gamma.
- ✅ **Technical Exit Engine**: Automated closing of positions based on RSI overbought, Signal Strength decay, or GEX regime shifts.
- ✅ **Backtesting Simulation Upgrades**: Historical validation for technical exit triggers.
- ✅ **GEX Documentation**: Detailed theory integration for pinning, walls, and flips in app help sections.
- ✅ **UX Polishing**: Login carousel indicators and terminology alignment ("Auto-Trading").

### v0.37.0 ✅ (Released July 29, 2026)
**Agentic Reasoning Mode, Balance Privacy, and Advanced Account Orchestration**
- ✅ **Agentic Reasoning Mode**: Introduced "Reasoning Mode" for the AI Alpha Agent enabling deep, multi-step analysis.
- ✅ **Balance Visibility Toggle**: Global privacy switch to mask P&L and equity values across Home and Portfolio.
- ✅ **Advanced GEX Orchestrator**: Integrated institutional-grade GEX data into Agentic lifecycle and signal filtering.
- ✅ **Scroll-to-Top**: Improved navigation across all major list views (Search, History, Trade Signals).
- ✅ **iOS Build Modernization**: Migration to CocoaPods and CI/CD hardening for reliability.
- ✅ **Generative Service Resilience**: Enhanced MCP client with dynamic casting and safer parsing.

### v0.37.1 ✅ (Released August 9, 2026)
**Progressive Portfolio, Signal Diagnostics, and Trading Reliability**
- ✅ **AI Portfolio Architect:** Natural-language portfolio construction with risk-optimized asset allocation.
- ✅ **Progressive Portfolio:** Decision-focused overview with hero statistics, movers, capped holdings summaries, and six dedicated drill-down sections.
- ✅ **Portfolio Action Center:** Ranked, account-aware alerts for concentration, cash, drawdown, volatility, benchmark performance, movers, and tax opportunities.
- ✅ **Shared Analytics Controller:** Cached metrics, benchmark selection, CSV export, AI insights, ESG analysis, and consistent Performance/Risk periods.
- ✅ **Trade Signal Diagnostics:** Instrument details expose calculation timing, data freshness, source, stale-cache use, status, interval, and evaluated bar count.
- ✅ **Paper Portfolio Reliability:** Corrected account aggregation, option data, and historical chart intervals.
- ✅ **Macro Regime Consistency:** Unified weighted scores, regime thresholds, guidance, history, and gauge colors.
- ✅ **TestFlight Reliability:** Hardened validation, archive preparation, retry behavior, and version rollback.

### v0.37.2 ✅ (Released August 9, 2026)
**Portfolio Gamma Intelligence & GEX Precision**
- ✅ **Portfolio GEX Dashboard:** Holdings-only aggregate gamma, gross/net exposure, breadth, concentration, top drivers, and symbol drill-downs.
- ✅ **Actionable GEX Levels:** Volatility regime, nearest levels, Gamma Flip, Call/Put Walls, transition map, Put Mass, and +GEX targets.
- ✅ **GEX Risk Triage:** Exposure/proximity sorting, amplifying-risk filtering, freshness labels, retry handling, and portfolio empty states.
- ✅ **Standardized GEX Units:** Backend and on-device engines now calculate dollar exposure for a 1% underlying move.
- ✅ **Portfolio Strategy Navigation:** Added GEX to the Strategies section and stabilized responsive browse-card sizing.

### v0.37.3 ✅ (Released August 10, 2026)
**Whale Watch Accuracy, Signal Reliability, and Responsive Research**
- ✅ **Institutional Snapshot Ranking:** Compare current holdings with the prior snapshot and label holdings fallback separately from measured accumulation.
- ✅ **Bounded Signal Schedulers:** Use cached bars/GEX and persisted macro context for daily, hourly, and 15-minute bulk generation.
- ✅ **Signal Freshness Semantics:** Refresh successful calculation time independently from recommendation-change time.
- ✅ **Reliable Signal Persistence:** Omit undefined Firestore fields, preserve prior signals when cached bars are unavailable, and report partial failures accurately.
- ✅ **Research & Navigation Polish:** Stabilize research cards, History account selection, portfolio section layouts, chart labels, and Trade Signals scroll-to-top behavior.

### v0.37.4 ✅ (Released August 13, 2026)
**Interpretable Options Flow, Private Portfolio Charts, and Trading Reliability**
- ✅ **Options Flow Guidance:** Added recommendations for every supported smart flag, trade-specific detection reasons, and prioritized interpretation checklists.
- ✅ **Portfolio Chart Privacy:** Extended balance masking to chart values, axes, annotations, tooltips, and summary metrics.
- ✅ **Portfolio Chart Context:** Added active date-span labels to change metrics and selected-point annotations.
- ✅ **Android Google Sign-In:** Added Firebase configuration, initialization, cancellation handling, and actionable authentication errors.
- ✅ **Trading Reliability:** Standardized rejection messages, deduplicated activity logs, validated two-sided options-chain open interest, and sanitized non-finite macro values.
- ✅ **Google Play Delivery:** Changed Android CD uploads from draft to completed releases.

### v0.37.5 ✅ (Released August 15, 2026)
**Quantitative Research, Stock Screening, and Portfolio Risk Analytics**
- ✅ **Options order placement on Schwab** ([Tracking: #138](https://github.com/CIInc/robinhood-options-mobile/issues/138))
- ✅ **Event Study Analyzer:** Analyze stock performance around earnings, FDA decisions, and other event windows.
- ✅ **Rolling Statistics Dashboard:** Track dynamic volatility, beta, and correlation.
- ✅ **Custom Screener Builder:** Build complex multi-factor screens through a dedicated UI.
- ✅ **QQQ Macro Context:** Added technology-leadership context to macro assessment.
- ✅ **Futures Margin Analytics:** Added margin calculations and expanded futures position charting.
- ✅ **Responsive Risk Heatmap:** Improved risk visualization across screen sizes.

### v0.38.0 ✅ (Released August 27, 2026)
**News Intelligence & Smart Alerts**
- ✅ **Real-Time News Integration:** AI-powered summarization and structured catalyst extraction for watchlist and instrument views.
- ✅ **Smart Alerts:** Multi-condition alerts correlated with technical indicators, moving averages, RSI, and Gamma Exposure (GEX).
- ✅ **Sentiment Scoring:** Automated sentiment scoring, impact classification (High/Medium/Low), and bullish/bearish driver analysis.
- ✅ **Dynamic Alert Thresholds:** AI- and ATR-calculated dynamic volatility bands and threshold breakouts.

### v0.39.0 ✅ (Released September 05, 2026)
**Custom Benchmarks, Portfolio Stress Testing, Aggregate Option Greeks, News Signal Multipliers, and Forex View Modernization**
- ✅ **Custom Benchmark Comparisons:** Dynamic custom symbol benchmarking in full-screen and standard performance charts.
- ✅ **Portfolio Stress Testing:** `PortfolioStressTestCard` simulating macro shocks (Market Crash -20%, Rate Spike +150bps, Tech Selloff -15%, Inflation Shock +200bps, Recession, Volatility Spike +50%).
- ✅ **Aggregate Option Greeks:** `PortfolioGreeksCard` displaying portfolio-wide Delta, Gamma, Theta, Vega, and Rho sensitivities.
- ✅ **Tail Risk & Liquidity Scoring:** `TailRiskCard` with VaR (95%/99%), Conditional VaR, Cornish-Fisher VaR, skewness, kurtosis, weighted liquidity scoring, and time-to-liquidate.
- ✅ **News Sentiment Signal Multiplier:** Real-time news sentiment multipliers automatically scaling trade signal confidence scores.
- ✅ **Event Impact Prediction:** AI-driven prediction model (`news-intelligence.ts`) and UI card (`NewsIntelligenceWidget`) for upcoming catalysts.
- ✅ **Schwab Integration Enhancements:** Enhanced Schwab account position mapping, position store syncing, and multi-account navigation.
- ✅ **Consolidated Group Performance Analytics & Order Sync:** Consolidated group analytics execution and member order synchronization.
- ✅ **Forex & Crypto Instrument Modernization:** Redesigned Forex view with technical analysis card and modal sheet, candlestick charts, preset tools menu, and haptic date filters.

### v0.40.0 ✅ (Released September 07, 2026)
**Forex Trading, Carry Trade Optimizer & Multi-Asset Portfolio Allocation**
- ✅ **Forex Trading (currency pairs):** Global currency pair order routing (`TradeForexWidget`) with Micro/Mini/Standard lot sizing, live pip calculation, Stop orders, and paper/demo execution ([Tracking: #116](https://github.com/CIInc/robinhood-options-mobile/issues/116)).
- ✅ **Forex Charting & Analysis:** Candlestick charts, multi-oscillator technical analysis bottom sheets, and haptic date filters.
- ✅ **Multi-Asset Portfolio Allocation:** Unified multi-asset allocation spanning Stocks, Options, Crypto, Forex, Futures, Fixed Income, and Cash across Home charts and the Rebalancing tool with All-Weather preset.
- ✅ **Carry Trade Optimizer:** Interest rate differential matrix, Central Bank policy rate monitor, Carry-to-Risk ratio scoring, unwind risk analysis, and automated basket optimizer.

### v0.41.0 ✅ (Released September 07, 2026)
**AI Trading Coach & Behavioral Finance**
- ✅ **Personalized Trading Pattern Analysis:** Win/loss duration asymmetry, time-of-day tilt detection, trade clustering, and sizing variance tracking ([Tracking: #118](https://github.com/CIInc/robinhood-options-mobile/issues/118)).
- ✅ **Behavioral Coaching & Bias Detection:** Dedicated cognitive bias identification (FOMO, Revenge Trading, Disposition Effect, Overconfidence, Gambler's Fallacy, Anchoring) with severity ratings and actionable antidotes.
- ✅ **Emotion Tracking & Journaling:** Pre/post-trade emotion check-ins, confidence & energy levels, emotion journal persistence in Firestore, and emotional performance correlation.
- ✅ **Trading Psychology Score:** Comprehensive psychology score (0-100) with four-pillar breakdown (Emotional Stability, Discipline & Patience, Bias Resistance, Risk Temperament) and psychological profile assessment.

### v0.42.0 ✅ (Released September 08, 2026)
**Pattern Day Trader (PDT) Protection & Counter**
- ✅ **Pattern Day Trader (PDT) Protection & Counter:** Real-time rolling 5-day day-trade counter for equities and options to prevent regulatory PDT restrictions (`/accounts/{account}/recent_day_trades/`).
- ✅ **Day Trade & Summary Models:** 5-business-day roll-off calculation, FINRA Rule 4210 risk levels, and $25,000 equity exemption logic.
- ✅ **Action Center PDT Alerts:** Critical and warning risk alerts in `PortfolioAlertService` with automatic $25k equity suppression.
- ✅ **Day Trade & PDT Monitor:** Visual 4-segment gauge, FINRA threshold progress, buying power & protection panel, filterable trade ledger, and FINRA 4210 FAQ.
- ✅ **Responsive & Overflow Hardening:** Clean responsive layout supporting narrow viewports (320px–360px) and full-width trade filtering.

### v0.43.0 ✅ (Released September 12, 2026)
**Robinhood Market Data & Institutional Intelligence**
- ✅ **First-Party Institutional & Hedge Fund Tracking:** Real-time hedge fund sentiment, quarterly manager holdings, and transaction history directly from Robinhood marketdata endpoints (`/marketdata/hedgefunds/`).
- ✅ **First-Party Insider Sentiment & Activity:** Monthly aggregate insider transactions, net sentiment scoring, and director/officer Form 4 tracking (`/marketdata/insiders/`).
- ✅ **Retail Order Flow & Robinhood Sentiment:** First-party net buy/sell percentage and volume percentage changes over time (`/marketdata/equities/summary/robinhood/`).
- ✅ **Short Float & Live Borrow Availability:** Real-time short interest (`pc_freefloat`, days to cover) and live borrow availability and fee rates (`/marketdata/fundamentals/short/v1/`, `/instruments/{id}/shorting/`).
- ✅ **Robinhood Curated Screener Presets & Layouts:** Native server-side screener presets (`/screeners/presets/`, `/screeners`) and Robinhood Legend workspaces (`/hippo/bw/layouts`).

### v0.44.0 ✅ (Released September 13, 2026)
**Unified Margin Health, Collateral & Advanced Order Execution**
- ✅ **Unified Risk & Margin Health:** Unified accounts endpoint integration (`/phoenix/accounts/unified`) for `margin_health`, `margin_buffer`, true options/crypto/account buying powers, and collateral holds.
- ✅ **Margin Calls & Financing Costs:** Real-time margin call deficit demands and monthly margin interest debit history (`/margin/calls/`, `/cash_journal/margin_interest_charges/`).
- ✅ **Instrument-Specific Buying Power & Trade Warnings:** Real-time buying power per instrument and risk/volatility warnings (`/accounts/{account}/instrument_buying_power/{id}/`, `/instruments/{id}/v2/warnings/`).
- ✅ **Options Collateral & Tier Upgrades:** Chain-level cash/equity collateral breakdown (`/options/chains/{id}/collateral/`) and upgrade eligibility (`/options/should_show_options_upgrade_on_sdp/`).
- ✅ **Combo Orders (Stock + Option Packages):** Execution and order history for multi-leg equity and option packages (`/combo/orders/`).
- ✅ **Instrument Previous Positions & Cost Basis Lookback:** Ability to look back on previous closed and historical positions within an instrument, displaying historical average buy and sell prices, realized P&L, hold duration, and round-trip execution metrics.

### v0.45.0 ✅ (Released September 14, 2026)
**Cash Management, Banking, Retirement & Tax Documents**
- ✅ **Securities Lending (SLIP) & Cash Sweeps:** Fully Paid Stock Loan income tracking (`/accounts/stock_loan_payments/`), SLIP status, and high-yield cash sweeps APY & tier tracking (`/accounts/sweeps/interest/`).
- ✅ **Banking, ACH & Cash Movement:** Monitor bank deposits, withdrawals, clearing status, and linked bank accounts (`/ach/transfers/`, `/ach/relationships/`).
- ✅ **Corporate Action Splits & Cash-in-Lieu:** Stock split cash-in-lieu adjustments, ratio tracking, and tax basis reporting (`/corp_actions/v2/split_payments/`).
- ✅ **Shareholder Say Q&A Engagement:** Say Technologies earnings Q&A participation (`/qa/events-section/`).
- ✅ **Multi-Account & Retirement Expansion:** Full multi-account hydration including Traditional/Roth IRAs (`ira_traditional`, `ira_roth`), contribution history (`/retirement/history/`), spending accounts (`/rhy/accounts/`), and connected agent management (`/oauth2/list_external_tokens/`).
- ✅ **Tax Documents & Statements:** Direct access and download for 1099 tax documents, monthly statements, ADR fees, and foreign tax withholding (`/documents/?type=1099`, `/corp_actions/adr_fees/`, `/tax_info/`).

### v0.46.0 ✅ (Released September 16, 2026)
**Investor Groups 2.0 & Collaborative Analytics**
- ✅ **Group Activity Feed:** Real-time feed of member trades and actions with member/type filtering, trade details sheet, and privacy controls ([#78](https://github.com/CIInc/robinhood-options-mobile/issues/78), [Tracking: #113](https://github.com/CIInc/robinhood-options-mobile/issues/113))
- ✅ **Group Chat (real-time messaging):** Real-time messaging with message history, read receipts, and unread badges ([#76](https://github.com/CIInc/robinhood-options-mobile/issues/76), [Tracking: #113](https://github.com/CIInc/robinhood-options-mobile/issues/113))
- ✅ **Performance Leaderboards & Shared Analysis Boards:** Member rankings, Sharpe/win rate metrics, and collaborative thesis sharing with price targets and discussions ([#77](https://github.com/CIInc/robinhood-options-mobile/issues/77), [Tracking: #113](https://github.com/CIInc/robinhood-options-mobile/issues/113))
- ✅ **Verified Track Records for Public Group Leaders:** Brokerage-audited return and win-rate verification badges for public group leaders ([Tracking: #113](https://github.com/CIInc/robinhood-options-mobile/issues/113))
- ✅ **Schwab API Market Data & Order Parsing:** Comprehensive response parsing for single/multi-leg option chains, equity quotes, and price history with dedicated test coverage ([#122](https://github.com/CIInc/robinhood-options-mobile/issues/122), [#145](https://github.com/CIInc/robinhood-options-mobile/issues/145))
- ✅ **Copy-Trading Functions Query Optimization:** Cache source user document lookup in copy-trading triggers to eliminate N+1 Firestore queries ([#146](https://github.com/CIInc/robinhood-options-mobile/pull/146))

### v0.47.0 ✅ (Released Sep 16, 2026)
**Social Platform & Performance Following**
- ✅ **Follow Portfolios:** Follow and unfollow traders with real-time Firestore sync and dynamic counters ([#27](https://github.com/CIInc/robinhood-options-mobile/issues/27))
- ✅ **Portfolio Privacy Controls:** Granular settings (`isPublic`, `showTradeAmounts`, `showHoldings`, `showTrades`, `allowFollowers`)
- ✅ **Masked Public Portfolios:** Privacy-first public profile view with dollar masking (`$***`), verified track record badge, and 1-tap copy trading
- ✅ **Following Activity Feed:** Real-time trade activity feed for followed traders with filtering and copy-trading dialog
- ✅ **Trade Notification Controls:** Per-trader notification mute/unmute toggle in user profile and follow lists
- ✅ **Top Portfolios Leaderboard & User Reputation System:** Showcase top-performing portfolios with time-period filters (1W, 1M, 3M, 1Y, ALL), 0-100 credibility scoring, and 1-tap follow ([#26](https://github.com/CIInc/robinhood-options-mobile/issues/26))
- ✅ **Social Feed for Shared Trade Ideas & Strategy Cloning:** Unified multi-stream social feed (All, Trade Ideas, Trades, Community) with sentiment filtering, dynamic risk/reward metrics, 1-tap strategy cloning, and community idea publishing sheet ([#24](https://github.com/CIInc/robinhood-options-mobile/issues/24))

### v0.47.1 ✅ (Released Sep 17, 2026)
**Instrument Custom Alerts & Social Feed Polish**
- ✅ **Instrument-Level Custom Alerts:** Embedded `InstrumentAlertsWidget` directly into stock and option detail pages (Overview, Signals & Tech, and All tabs) with inline active/pause toggles, pre-filled symbol alert creation, and alert status counters ([#81](https://github.com/CIInc/robinhood-options-mobile/issues/81), [Tracking: #115](https://github.com/CIInc/robinhood-options-mobile/issues/115)).
- ✅ **Direct Price & Technical Alerts Navigation:** Added direct alert actions in instrument app bars and embedded cards for streamlined monitoring.
- ✅ **Social Feed & Leaderboard Polish:** Refined trade idea card layout, verified trader reputation badges, and seamless copy-trading dialog integration ([#24](https://github.com/CIInc/robinhood-options-mobile/issues/24), [#26](https://github.com/CIInc/robinhood-options-mobile/issues/26)).

### v0.48.0 ✅ (Completed Sep 18, 2026)
**Tax Optimization, Wash Sale Detection & Capital Gains Suite ([Tracking: #114](https://github.com/CIInc/robinhood-options-mobile/issues/114))**
- ✅ **Rolling 30-Day Wash Sale Detector:** Real-time monitoring across closed loss positions (equities and substantially identical options) to alert users before triggering disallowed tax loss penalties.
- ✅ **Tax-Loss Harvesting Scanner:** Portfolio Action Center scanner identifying unrealized loss positions suitable for harvesting against realized capital gains, complete with replacement ticker suggestions.
- ✅ **Capital Gains & Holding Period Breakdown:** Short-Term vs. Long-Term capital gains projection, holding period duration timers, and estimated tax bracket liability calculations.
- ✅ **Specific Tax Lot Matching (HIFO/LIFO):** Select specific tax lots or tax-loss optimization rules during order entry to systematically minimize capital gains impact.
- ✅ **IRS Form 8949 Preview & CSV Export:** Export structured realized transactions formatted for Schedule D / Form 8949 with wash sale adjustment codes (`W`).

### v0.48.5 ✅ (Completed Sep 18, 2026)
**Risk Guardrails, Brokerage Streaming & Synchronized Position Scrolling**
- ✅ **Autonomous Account Risk Circuit Breakers & Tilt Guardrails:** User-configurable account safety thresholds (daily max loss limit, portfolio drawdown limit, margin buffer lock, consecutive loss limit, and mandatory cooling-off trading suspension to prevent tilt and revenge trading) ([Tracking: #142](https://github.com/CIInc/robinhood-options-mobile/issues/142)).
- ✅ **Schwab Real-Time WebSocket Streamer:** Secure handshake, token refresh, sub-second streaming quotes (`LEVELONE_EQUITIES`), real-time options & Greeks (`LEVELONE_OPTIONS`), account activity notifications (`ACCT_ACTIVITY`), chart candle updates (`CHART_EQUITY`), futures, forex, and connection watchdog with exponential backoff ([#145](https://github.com/CIInc/robinhood-options-mobile/issues/145)).
- ✅ **Synchronized Position Scroll:** Synchronized multi-column scrolling for position detail rows across Equities, Options, Forex, and Futures positions with late-mount auto-alignment ([#7](https://github.com/CIInc/robinhood-options-mobile/issues/7)).
- ✅ **Trade Notification Authorization Guard:** Authentication and cross-user authorization enforcement for agentic notifications ([#152](https://github.com/CIInc/robinhood-options-mobile/pull/152)).
- ✅ **Technical Indicator Optimization:** Algorithmic pass and slicing optimization for MACD, ADX, and Williams %R ([#153](https://github.com/CIInc/robinhood-options-mobile/pull/153)).
- ✅ **Search Clear Accessibility:** Tooltip and screen-reader accessibility for search clear action ([#154](https://github.com/CIInc/robinhood-options-mobile/pull/154)).

### v0.49.0 ✅ (Released Sep 19, 2026)
**Options Strategy Roll Assistant, Dual-Value Position Bar Charts & Platform Polish**
- ✅ **Options Strategy Roll Assistant:** 1-tap rolling wizard for covered calls, cash-secured puts, long options, and vertical spreads with automated net credit/debit calculation, updated breakeven projections, Greeks shift comparison, and multi-leg order execution ([#157](https://github.com/CIInc/robinhood-options-mobile/issues/157)).
- ✅ **Position Bar Chart Values:** Dual-axis bar charts combining both \$ and % values, interactive selection tooltips, responsive controls, and CSV export ([#19](https://github.com/CIInc/robinhood-options-mobile/issues/19)).
- ✅ **Multi-Axis Zero-Baseline Alignment:** Dynamically synchronized primary and secondary axis viewports so $0 and 0% ticks align horizontally ([#19](https://github.com/CIInc/robinhood-options-mobile/issues/19)).
- ✅ **Android Adaptive Splash Screen Brand Parity:** Aligned Android launch screen and Android 12+ splash screens with iOS design, dark theme background (`#1C1B1F`), emblem, title, and subtitle typography.
- ✅ **Multi-Symbol Equity Curve Backtest Optimization:** Optimized parallel equity curve merging and interval caching, eliminating O(N^2) timeline re-computation ([#155](https://github.com/CIInc/robinhood-options-mobile/pull/155)).
- ✅ **Firebase Role Authorization & Input Validation:** Hardened `changeUserRole` callable function with strict group admin verification and input validation ([#156](https://github.com/CIInc/robinhood-options-mobile/pull/156)).
- ✅ **Paper Trading Risk Circuit Breaker Decoupling:** Bypassed live circuit breaker checks for simulated paper trades so users can test strategies freely.

### v0.50.0 ✅ (Released Sep 19, 2026)
**Mobile Excellence, Live Activities, Landscape Chart Matrix & Strategy Defense**
- ✅ **iOS Live Activities & Dynamic Island Widget:** Real-time lock screen widget for active option positions, P&L status, and 0DTE trailing stops during market hours ([#160](https://github.com/CIInc/robinhood-options-mobile/issues/160)).
- ✅ **Landscape Charting & Multi-Column Matrix View:** Full-width widescreen charting mode with collapsible multi-leg order entry for tablet and mobile devices ([#117](https://github.com/CIInc/robinhood-options-mobile/issues/117)).
- ✅ **Offline Mode & Resilient Caching:** Encrypted local cache for portfolio holdings, watchlists, quotes, and AI trade signals with background sync and status banner ([#87](https://github.com/CIInc/robinhood-options-mobile/issues/87)).
- ✅ **Multi-Leg Options Defense & Roll Playbook:** Automated defensive action recommendations and tactical playbook when short legs are tested (e.g. rolling out in time, widening spreads, inverted strangles, converting to iron condors) ([#158](https://github.com/CIInc/robinhood-options-mobile/issues/158)).

### v0.51.x (Current development version: 0.51.6)
**Options Analytics Pro, 0DTE Squeeze Radar & Volatility Surfaces**
- ✅ **0DTE Flow & Intraday Gamma Squeeze Radar:** Real-time 0DTE call/put flow volume, dealer gamma flip velocity, and gamma squeeze probability gauge ([Tracking: #115](https://github.com/CIInc/robinhood-options-mobile/issues/115)).
- ✅ **Earnings IV Crush Probability & Straddle Pricing Estimator:** Implied earnings move vs. actual historical moves over 12 quarters, post-earnings IV crush calculation, and expected value (EV) straddle pricing distributions ([Tracking: #137](https://github.com/CIInc/robinhood-options-mobile/issues/137)).
- ✅ **Beta-Weighted Portfolio Delta & Cross-Asset Greeks Engine:** Portfolio-wide beta-weighting ($\Delta_{\beta-SPY}$) and aggregate Gamma/Vega across stocks, options, crypto, futures, and forex to quantify true market-move dollar risk ([Tracking: #137](https://github.com/CIInc/robinhood-options-mobile/issues/137)).
- ✅ **Realized vs. Implied Volatility (IV) Cone & Rank/Percentile:** Multi-timeframe IV percentiles (30d/60d/90d), rolling realized volatility cones (10d to 252d), strike skew surfaces ($25\Delta$ Risk Reversal), term structure curvature, and pre-earnings IV crush indicators ([Tracking: #137](https://github.com/CIInc/robinhood-options-mobile/issues/137), v0.51.4).
- ✅ **Implied Volatility Surface 3D Visualizer:** Interactive 3D surface plot across strikes and expiration dates with strike interpolation, Dupire local volatility calculations, arbitrage violation checks, and 2D cross-sectional slice analysis ([Tracking: #137](https://github.com/CIInc/robinhood-options-mobile/issues/137), v0.51.5).
- ✅ **Delta-Neutral Strategy Builder:** Multi-leg hedging tool calculating dynamic delta offsets, automated share/option rebalancing suggestions, and spot-shift scenario modeling ([Tracking: #137](https://github.com/CIInc/robinhood-options-mobile/issues/137), [Tracking: #108](https://github.com/CIInc/robinhood-options-mobile/issues/108), v0.51.6).

### v0.52.0 (Tentative target: December 2026)
**Copy-Trading Transparency & Social Foundations**
- ✅ **Copy-Trading Slippage & Divergence Analytics:** Audit report showing follower fill latency (ms), price slippage vs. leader, and net return tracking ([Tracking: #141](https://github.com/CIInc/robinhood-options-mobile/issues/141)).
- ✅ **Automated Copy-Trading Risk Guardian:** Follower protective guardrails specifying max capital allocation per trade, auto-disconnect on leader drawdown divergence, and max slippage abort ([Tracking: #141](https://github.com/CIInc/robinhood-options-mobile/issues/141), v0.52.0).
- ✅ **Side-by-Side Multi-Trader Portfolio Comparison:** Benchmark risk-adjusted performance across 2 to 4 potential leaders with timeframe normalization (`1W`, `1M`, `3M`, `1Y`, `ALL`), 5-dimensional relative strength scoring, metric winner highlights, privacy masking, and 1-tap copy integration ([Tracking: #141](https://github.com/CIInc/robinhood-options-mobile/issues/141), [Tracking: #113](https://github.com/CIInc/robinhood-options-mobile/issues/113), v0.52.0).
- ✅ **Social Discussion & Comment Threads:** Granular discussions on shared trade ideas and public portfolios with author-pinned comments, community sentiment polling (Bullish, Bearish, Neutral), comment upvoting, and moderation reporting controls ([Tracking: #113](https://github.com/CIInc/robinhood-options-mobile/issues/113), v0.52.0).
- **Trading Arenas & Verified Paper Tournaments (exploratory):** Keep paper-only; define fair scoring, anti-abuse controls, and a separate tracked issue before assigning a release.

### v0.53.0 (2027 Q1 - January)
**Institutional Multi-Brokerage, Smart Order Routing & SEC Disclosures**
- **Schwab Advanced Execution & Order Replacement:** In-flight order replacement and modification (`PUT /trader/v1/accounts/{account}/orders/{id}`), margin preview validation (`previewOrder`), and multi-leg option chains ([#122](https://github.com/CIInc/robinhood-options-mobile/issues/122)).
- **Schwab Account Activity & Historical Cash Transactions:** Sync historical dividends, margin interest charges, and cash movements (`GET /trader/v1/accounts/{account}/transactions`) ([#91](https://github.com/CIInc/robinhood-options-mobile/issues/91)).
- **Smart Order Routing (SOR) & Cross-Broker Margin & Borrow Optimizer:** Dynamically evaluate and route equity/option orders between connected brokerages (Robinhood and Schwab) to minimize margin requirements and borrow rates ([#108](https://github.com/CIInc/robinhood-options-mobile/issues/108)).
- **SEC EDGAR Real-Time 13F & Form 4 Insider Whales Ingestion:** Automated streaming parsing of 13F institutional disclosures, Form 4 insider cluster buys, and 8-K material events with portfolio overlap alerts ([Tracking: #143](https://github.com/CIInc/robinhood-options-mobile/issues/143)).
- **Congress & Political Trading Tracker:** Automatic monitoring and alerts for congressional disclosures (STOCK Act filings) with portfolio overlap matching.

### v0.54.0 (2027 Q1 - February)
**Multi-Model AI Consensus Engine, Devil's Advocate & Biometric Tilt**
- **Multi-Model AI Consensus Engine:** Ensemble trading conviction grades combining Gemini 3.1 Flash-Lite, deep reasoning agents, and quantitative factor scores ([Tracking: #118](https://github.com/CIInc/robinhood-options-mobile/issues/118)).
- **AI Devil's Advocate & Trade Thesis Stress Tester:** Automated adversarial critique generating objective Bear vs. Bull counter-arguments, skew risks, and event hazards before entering trades.
- **Biometric Tilt & Panic Trading Guardian:** Extends risk circuit breakers with Apple HealthKit / Wear OS biometric data (heart rate spikes) and rapid erratic order tapping to detect emotional tilt and enforce cooling-off locks.
- **Autonomous Agentic Risk Copilot:** Continuous background monitor assessing overnight gap risk, earnings hazard warnings for open positions, and suggested delta hedges.
- **Algorithmic Strategy Marketplace:** Community strategy sharing with audited performance proofs, strategy rental/subscriptions, and automated creator royalty distribution ([Tracking: #141](https://github.com/CIInc/robinhood-options-mobile/issues/141)).
- **AI Trade Post-Mortem & Behavioral Journal Auto-Tagger:** Automated post-trade diagnostic identifying cognitive biases (FOMO, disposition effect) and execution mistakes upon position closing.

### v0.55.0+ (2027 Q2+)
**Frontier Horizons, Desktop Pro & Privacy-Preserving Social Trading**
- **Zero-Knowledge Proofs (ZKP) for Private Social Trading:** Cryptographically verifiable track record badges (Sharpe, win rate, return %) without revealing account equity or dollar trade amounts.
- **Desktop & iPad Multi-Pane Floating Workspace:** Native Flutter Desktop (macOS/Windows) and iPad split-view workspace with floating order pads, live depth, and detachable charts.
- **Local OpenAPI & Quant Webhook Gateway:** Local WebSocket and REST API server embedded in the app allowing quant traders to stream market data, Greeks, and signals to Python/Node.js scripts.
- **Hands-Free Voice-Activated Trade Drafting:** On-device speech recognition for conversational trade setup ("Roll my AAPL call up \$5 for net credit") with one-touch biometric confirmation.
- **Retirement Planning & Gold Match Maximizer:** Interactive projection calculator for IRA compounding, tax advantages, and Robinhood Gold IRA 3% match optimization ([Tracking: #139](https://github.com/CIInc/robinhood-options-mobile/issues/139)).
- **Immersive Spatial Trading Interfaces (AR/VR):** Multidimensional market data visualization for spatial computing devices (VisionOS / Quest).

### v0.56.0 (2027 Q3+)
**Apple Watch & Wear OS Companion**
- **Apple Watch & Wear OS Companion App:** Glanceable portfolio P&L, price alerts, and watchlists on wearables.

## Risks & Blockers

### Risk Register

**High Risk 🔴**

1. **On-Device Options Analytics Performance** (Impacts: current v0.51.x development build)
    - **Challenge**: Implemented 0DTE analytics, 3D IV surfaces, and sub-second quote streaming may induce thermal throttling or battery drain on mobile devices
    - **Mitigation**: Profile representative iOS and Android devices; use on-demand mesh downsampling, viewport-aware updates, background stream pausing, and compute isolation where measurements justify it
    - **Timeline Impact**: Validate on target devices before treating performance as production-ready
   - **Mitigation Owner**: Mobile Engineering + Performance Team

2. **Cross-Broker Concurrent Authentication & Token Orchestration** (Impacts: Q1 2027 - Multi-Broker & Smart Order Routing)
   - **Challenge**: Concurrently orchestrating OAuth2 token rotation, session handshakes, and secure keychain storage across multiple live brokerages (Schwab, Robinhood) without desync or auth loops
   - **Mitigation**: Independent broker token managers with dedicated mutex locks, silent background token refresh before expiration, and isolated session failure recovery
   - **Timeline Impact**: Adds 1-2 weeks to multi-broker smart routing integration
   - **Mitigation Owner**: Backend + Security Engineering Team

3. **Real-Time Data Streaming & Mobile Battery Consumption** (Impacts: Q4 2026 - Platform Scale & UX)
   - **Challenge**: Continuous sub-second WebSocket streaming over cellular networks can rapidly drain battery and exceed data bandwidth
   - **Mitigation**: Viewport-aware streaming subscriptions (subscribe only to active visible tickers), auto-pause when backgrounded, fallback to throttled snapshot polling
   - **Timeline Impact**: Requires 1 week of battery benchmark profiling
   - **Mitigation Owner**: Mobile Engineering + DevOps

4. **Copy Trading Execution Latency & Brokerage Key Security** (Impacts: Q4 2026 - Trading Automation)
   - **Challenge**: Server-side auto-execution requires sub-second latency across copying members without compromising user brokerage OAuth credentials
   - **Mitigation**: Cloud KMS encryption for OAuth tokens; Firestore user caching (delivered in [#146](https://github.com/CIInc/robinhood-options-mobile/pull/146)); asynchronous worker queues
   - **Timeline Impact**: Could add 2-3 weeks for secure server-side execution pipeline
   - **Mitigation Owner**: Backend + Security Engineering Team

**Medium Risk 🟡**

5. **LLM Reasoning Latency & Cost Optimization** (Impacts: Q4 2026 - AI Personalization)
   - **Challenge**: Multi-step Agentic Reasoning mode can introduce latency and escalate Firebase AI token consumption
   - **Mitigation**: Migrated to Gemini 3.1 Flash-Lite with structured caching and concise prompt schemas; monitor daily quota usage
   - **Timeline Impact**: Largely mitigated; ongoing budget monitoring
   - **Mitigation Owner**: AI Engineering Team

6. **Firebase Quotas & Costs** (Impacts: Q3-Q4 2026 - Infrastructure)
   - **Challenge**: High-frequency social feeds, leaderboards, and market alerts could increase Firestore read/write costs
   - **Mitigation**: Implement client-side query caching; batch write operations; optimize Firestore security rule evaluations
   - **Timeline Impact**: Ongoing maintenance (1-2 weeks per quarter)
   - **Mitigation Owner**: Backend Engineering + DevOps

7. **Cross-Platform Consistency (iOS/Android/Web)** (Impacts: Q4 2026 - Cross-Platform)
   - **Challenge**: Ensuring rich chart interactions, home widgets, and haptics behave consistently across platforms
   - **Mitigation**: Automated CI testing workflows; platform-specific UI adaptations; automated golden/widget tests
   - **Timeline Impact**: Adds 1 week of QA per major release
   - **Mitigation Owner**: QA + Mobile Engineering

8. **Generative AI Hallucinations** (Impacts: Q4 2026 - AI Trust)
   - **Challenge**: AI models may synthesize misleading market interpretations or unsupported trade ideas
   - **Mitigation**: Structured trade proposal validation schema (`[TRADE_PROPOSAL]`), explicit risk disclaimers, and mandatory user manual trade confirmation
   - **Timeline Impact**: Ongoing guardrail testing
   - **Mitigation Owner**: AI Engineering + Product + Legal

**Low Risk 🟢**

9. **Third-Party API Changes** (Impacts: All Quarters)
   - **Challenge**: Brokerage/market data APIs (Schwab, Twelve Data, Yahoo Finance) may change payload schemas without notice
   - **Mitigation**: Monitor API changelogs; implement schema fallback parsers; maintain comprehensive integration test suites
   - **Timeline Impact**: Quick fixes (1-3 days) but won't block main roadmap
   - **Mitigation Owner**: Backend Engineering Team

10. **Team Scaling** (Impacts: Q4 2026 - 2027)
    - **Challenge**: Maintaining high code quality and test coverage as team velocity scales
    - **Mitigation**: Comprehensive GitHub Actions CI checks, strict linter rules, and Architecture Decision Records (ADRs)
    - **Timeline Impact**: Minimal impact on delivery velocity
    - **Mitigation Owner**: Engineering Leads

### Mitigation Strategies

**Proactive Measures:**
1. ✅ Complete IRS Rule 1091 wash sale test suite with synthetic option and stock loss scenarios
2. ✅ Implement WebSocket connection watchdog with exponential backoff for Schwab streamer
3. ✅ Leverage Gemini 3.1 Flash-Lite for cost-effective agentic reasoning
4. ✅ Enforce feature flags and client-side caching for gradual rollout of social and streaming features
5. ✅ Maintain comprehensive CI/CD test automation covering unit, widget, and mock Firestore tests

**Fallback Plans:**
- If brokerage integration slips: Pivot to more comprehensive Robinhood API features (already available)
- If ML optimization delays: Launch with template-based strategies instead of ML
- If compliance delays Q4: Release to limited jurisdictions first (CA, NY); expand in 2027
- If Firebase costs spike: Migrate specific services to self-hosted alternatives

## Completed Features ✅

### Investor Groups & Social Platform
- [x] Create and manage investor groups ([#31](https://github.com/CIInc/robinhood-options-mobile/issues/31))
- [x] Public and private group options
- [x] Portfolio sharing within groups
- [x] Admin controls and member management
- [x] Invitation system with accept/decline workflow
- [x] Direct portfolio viewing for private group members
- [x] Member list with avatars and role indicators
- [x] Real-time group activity feed with filtering & details ([#78](https://github.com/CIInc/robinhood-options-mobile/issues/78), [Tracking: #113](https://github.com/CIInc/robinhood-options-mobile/issues/113))
- [x] Group chat with real-time messaging, unread counts & message history ([#76](https://github.com/CIInc/robinhood-options-mobile/issues/76), [Tracking: #113](https://github.com/CIInc/robinhood-options-mobile/issues/113))
- [x] Performance leaderboards and shared analysis boards with thesis tracking ([#77](https://github.com/CIInc/robinhood-options-mobile/issues/77), [Tracking: #113](https://github.com/CIInc/robinhood-options-mobile/issues/113))
- [x] Verified track records & audit verification badges for group leaders ([Tracking: #113](https://github.com/CIInc/robinhood-options-mobile/issues/113))
- [x] **Follow Portfolios** ([#27](https://github.com/CIInc/robinhood-options-mobile/issues/27)):
    - [x] Follow/unfollow users with real-time Firestore sync and follower/following counters
    - [x] Granular portfolio privacy settings (`PortfolioPrivacySettings`)
    - [x] Masked public portfolio profile with dollar masking (`$***`), verified track record badge, and 1-tap copy trading
    - [x] Following activity feed widget (`FollowingActivityFeedWidget`) with trade filtering and copy dialog
    - [x] Per-followed-user trade notification toggle
- [x] **Top Portfolios Leaderboard & User Reputation System** ([#26](https://github.com/CIInc/robinhood-options-mobile/issues/26)):
    - [x] Olympic-style top 3 podium and ranked leaderboard cards with time-period filters (1W, 1M, 3M, 1Y, ALL)
    - [x] Objective 0–100 user reputation scoring algorithm across 5 tiers with badges
    - [x] Direct 1-tap follow actions and privacy safeguards
- [x] **Social Feed for Shared Trade Ideas & Strategy Cloning** ([#24](https://github.com/CIInc/robinhood-options-mobile/issues/24)):
    - [x] Unified multi-stream social feed (All, Trade Ideas, Trades, Community) with sentiment filtering
    - [x] Interactive trade idea publishing sheet (`ShareTradeIdeaSheet`) with dynamic risk/reward preview
    - [x] 1-tap strategy cloning directly preparing copy-trade orders


### Trade Signals & AI Trading
- [x] Multi-indicator correlation system ([#32](https://github.com/CIInc/robinhood-options-mobile/issues/32))
- [x] Intraday signals - 15m, 1h, daily ([#48](https://github.com/CIInc/robinhood-options-mobile/issues/48))
- [x] Server-side filtering for trade signals ([#46](https://github.com/CIInc/robinhood-options-mobile/issues/46))
- [x] On-demand trade signal generation
- [x] **Agentic Trading** ([#109](https://github.com/CIInc/robinhood-options-mobile/issues/109), [#126](https://github.com/CIInc/robinhood-options-mobile/issues/126)):
    - [x] Fully autonomous execution with 5-minute periodic checks
    - [x] Trade-level TP/SL tracking with entry price accuracy
    - [x] Firebase persistence for cross-device continuity
    - [x] Emergency stop for immediate halt
    - [x] UI for configuring agentic trading parameters
    - [x] Risk management controls (daily limit, cooldown, loss threshold)
    - [x] **Agentic Reasoning Mode** (v0.37.0): Multi-step analysis workflow with deep market inspection
- [x] **Advanced Performance Analytics** ([#131](https://github.com/CIInc/robinhood-options-mobile/pull/131)):
    - [x] 9 comprehensive analytics cards (overview, P&L, breakdown, best/worst, advanced metrics, risk metrics, time-of-day, indicator combo, symbol)
    - [x] Sharpe Ratio calculation (risk-adjusted returns)
    - [x] Profit Factor analysis (gross profit / gross loss)
    - [x] Expectancy calculation (expected profit per trade)
    - [x] Max Drawdown tracking (peak-to-trough decline)
    - [x] Win/Loss streak monitoring
    - [x] Performance by time of day analysis
    - [x] Performance by indicator combination analysis
    - [x] Performance by symbol tracking (top 10)
- [x] **Paper Trading Mode** ([#73](https://github.com/CIInc/robinhood-options-mobile/issues/73), [#131](https://github.com/CIInc/robinhood-options-mobile/pull/131), [#144](https://github.com/CIInc/robinhood-options-mobile/issues/144)):
    - [x] Risk-free strategy testing with simulated execution
    - [x] Paper vs real trade filtering and comparison
    - [x] Visual indicators (PAPER badges throughout UI)
- [x] **Trailing Stop Loss** ([#131](https://github.com/CIInc/robinhood-options-mobile/pull/131)):
    - [x] Dynamic stop loss adjustment as profit increases
    - [x] Peak price tracking for each trade
    - [x] Configurable trailing distance
- [x] **Trade Approval Workflow** ([#112](https://github.com/CIInc/robinhood-options-mobile/issues/112)):
    - [x] Review-before-execute mode for semi-automatic trading
- [x] **Advanced Risk Controls** ([#112](https://github.com/CIInc/robinhood-options-mobile/issues/112)):
    - [x] Sector limits, correlation checks, volatility filters, drawdown protection
- [x] **RiskGuard Manual Protection** ([#142](https://github.com/CIInc/robinhood-options-mobile/issues/142)):
    - [x] Extended automated risk controls (max drawdown, sector exposure) to manual trading activities
- [x] **Advanced Exit Strategies** ([#112](https://github.com/CIInc/robinhood-options-mobile/issues/112)):
    - [x] Partial Position Exits (staged take profit)
    - [x] Time-Based Exits (duration limits)
    - [x] Market Close Exits (avoid overnight risk)
- [x] **Signal Optimization** ([#112](https://github.com/CIInc/robinhood-options-mobile/issues/112)):
    - [x] Machine learning-based signal optimization
- [x] **Custom Indicators** ([#112](https://github.com/CIInc/robinhood-options-mobile/issues/112)):
    - [x] Create and use custom technical indicators
- [x] **Performance Dashboard** ([#112](https://github.com/CIInc/robinhood-options-mobile/issues/112)):
    - [x] Track signal performance metrics (Signal Strength & Indicator Performance)
- [x] **Trade Signal Notifications** ([#80](https://github.com/CIInc/robinhood-options-mobile/issues/80), [#115](https://github.com/CIInc/robinhood-options-mobile/issues/115)):
    - [x] Configurable push notifications for trade signals
    - [x] Filtering by signal type, symbol, and confidence
    - [x] Deep linking to instrument details
    - [x] **Rich Notifications**: Charts and data in push notifications ([#80](https://github.com/CIInc/robinhood-options-mobile/issues/80))
- [x] **Options Flow Analysis** ([#83](https://github.com/CIInc/robinhood-options-mobile/issues/83), [#134](https://github.com/CIInc/robinhood-options-mobile/issues/134)):
    - [x] Enhanced smart flags (Cheap Vol, High Premium, Large Block, etc.)
    - [x] Improved detection algorithms (Whale, LEAPS)
    - [x] Comprehensive in-app definitions
    - [x] UI polish and better tooltips
    - [x] **New:** Advanced filtering (Expiration Date, Premium, etc.)
- [x] **Macro Risk Assessment**:
    - [x] Institutional-grade 19-indicator weighted scoring system (MOVE, Credit Spreads, Market Breadth, Volatility indices) mapping dynamic Risk-On/Off regimes to automated sizes
- [x] **Gamma Exposure (GEX) Pro** ([#149](https://github.com/CIInc/robinhood-options-mobile/pull/149)):
    - [x] On-device Black-Scholes mathematical engine for gamma derivation
    - [x] Interactive GEX coordinate charts with strike detail panels
    - [x] Market maker pinning gauge (Put/Call walls, Gamma Flip)
    - [x] Spot-shift sensitivity dashboard (stress testing)
    - [x] **Advanced GEX Orchestrator** (v0.37.0): AI-aligned regime filtering for signals
- [x] **Trade Signals Widget**:
    - [x] Dedicated home screen widget for viewing and filtering real-time signals

### Quantitative Research
- [x] **Alpha Factor Discovery** ([#137](https://github.com/CIInc/robinhood-options-mobile/issues/137)):
    - [x] Signal correlation analysis engine
    - [x] Information Coefficient (IC) metrics
    - [x] Symbol breakdown and stability analysis

### Backtesting
- [x] **Backtesting Engine** ([#84](https://github.com/CIInc/robinhood-options-mobile/issues/84)):
    - [x] 3-tab interface (Run, History, Templates)
    - [x] Historical data testing (5 days to 5 years)
    - [x] Multiple time intervals (15m, 1h, 1d)
    - [x] All 9 technical indicators supported
    - [x] Advanced risk parameters (TP, SL, Trailing Stop)
    - [x] Comprehensive performance metrics (Sharpe, drawdown, profit factor)
    - [x] Interactive equity curve with trade markers
    - [x] 4-tab result page (Overview, Trades, Equity, Details)
    - [x] Template system to save/reuse configurations
    - [x] Enhanced Strategy Templates (Library Expansion)
    - [x] Export and share backtest results
    - [x] Real-time Firestore integration
    - [x] User backtest history (last 50 runs)
    - [x] **Multi-Symbol Equity Curve Optimization** ([#155](https://github.com/CIInc/robinhood-options-mobile/pull/155), v0.49.0): Optimized parallel equity curve merging and interval caching, eliminating O(N^2) timeline re-computation

### Copy Trading
- [x] Manual order execution for copied trades ([#28](https://github.com/CIInc/robinhood-options-mobile/issues/28))
- [x] Push notifications for copyable trades
- [x] Selection-based UI for batch copying
- [x] Quantity and amount limits
- [x] **Copy Trading Dashboard** ([#71](https://github.com/CIInc/robinhood-options-mobile/issues/71)):
    - [x] Trade history and filtering
    - [x] Performance metrics
- [x] **Approval Workflow** ([#97](https://github.com/CIInc/robinhood-options-mobile/issues/97)):
    - [x] Review and approve auto-copied trades
- [x] **Auto-Execute** ([#66](https://github.com/CIInc/robinhood-options-mobile/issues/66)):
    - [x] Client-side automatic execution for flagged copy trades
- [x] **Copy Trading Enhancements** ([#110](https://github.com/CIInc/robinhood-options-mobile/issues/110)):
    - [x] **Performance Tracking**: Track success rate of copied trades ([#98](https://github.com/CIInc/robinhood-options-mobile/issues/98))
    - [x] **Partial Copying**: Support copying a percentage of the original trade ([#99](https://github.com/CIInc/robinhood-options-mobile/issues/99))
    - [x] **Advanced Filtering**: Filter by symbol, time, or sector ([#101](https://github.com/CIInc/robinhood-options-mobile/issues/101))
    - [x] **Exit Strategy**: Automatically copy stop loss/take profit ([#100](https://github.com/CIInc/robinhood-options-mobile/issues/100))
    - [x] **Inverse Copying**: Contra-trading functionality ([#110](https://github.com/CIInc/robinhood-options-mobile/issues/110))
    - [x] **Query Optimization** ([#146](https://github.com/CIInc/robinhood-options-mobile/pull/146)): Cache source user lookup in order event triggers to eliminate N+1 Firestore queries across copying members
    - [x] **Automated Copy-Trading Risk Guardian** ([#141](https://github.com/CIInc/robinhood-options-mobile/issues/141), v0.52.0): Follower protective guardrails specifying max capital allocation per trade, auto-disconnect on leader drawdown divergence, and max slippage abort

### Futures Trading
- [x] Futures accounts handling and UI integration ([#39](https://github.com/CIInc/robinhood-options-mobile/issues/39))
- [x] Live futures position enrichment with contract metadata
- [x] Real-time quote integration and Open P/L calculation
- [x] **Futures Auto-Trading**: Settings configuration, performance logging, custom activity timeline cards, and backend cron jobs
- [x] **Futures Historical Metrics**: Realized P&L and Day P&L calculations matching real-time contract streams ([#102](https://github.com/CIInc/robinhood-options-mobile/issues/102))

### Data Persistence
- [x] Firestore persisted portfolios, positions, and transactions ([#16](https://github.com/CIInc/robinhood-options-mobile/issues/16), [#29](https://github.com/CIInc/robinhood-options-mobile/issues/29))

### Portfolio Visualization
- [x] Portfolio allocation pie charts (Asset, Position, Sector, Industry) ([#2](https://github.com/CIInc/robinhood-options-mobile/issues/2), [#127](https://github.com/CIInc/robinhood-options-mobile/pull/127))
- [x] Interactive carousel with page indicators
- [x] Bidirectional highlighting between chart slices and legend entries
- [x] Top 5 holdings display with percentage labels
- [x] "Others" grouping for remaining positions
- [x] **Risk Heatmap**: Interactive treemap visualization with Sector/Symbol grouping
- [x] **Portfolio Analytics**: Comprehensive dashboard with risk/return metrics, Custom Benchmarks, and Health Score
- [x] **Custom Benchmarks**: Compare portfolio performance against any ticker (e.g., BTC, NVDA)
- [x] **Enhanced Cash Allocation**: Intelligent handling of short-term treasury ETFs as cash equivalents
- [x] **Correlation Matrix**: Multi-asset correlation heatmap with filtering and detailed tooltips
- [x] **UX & Navigation Enhancements**:
    - [x] **Scroll-to-Top**: Quick return to top for major list views (v0.37.0)
    - [x] **Responsive Appbar**: Sliver-based architecture for smooth scrolling
    - [x] **Home Screen Widgets** ([#86](https://github.com/CIInc/robinhood-options-mobile/issues/86)): iOS widgets for portfolio, watchlists, and trade signals with deep linking
    - [x] **Deep Linking** ([#85](https://github.com/CIInc/robinhood-options-mobile/issues/85)): Universal links and sharing functionality for instruments and referral codes
- [x] **Dual-Value Position Bar Charts** ([#19](https://github.com/CIInc/robinhood-options-mobile/issues/19), v0.49.0):
    - [x] Dual-axis and combined metric bar charts in `InstrumentPositionsWidget` and `OptionPositionsWidget`
    - [x] Secondary target line renderer (`BarTargetLineRendererConfig`) overlaying primary bars
    - [x] Multi-axis zero-tick alignment (`AlignedAxisExtents`) synchronizing $0 and 0% baselines
    - [x] Interactive bar tooltips with symbol badges, return metrics, share counts, and detail navigation

### Trading & Execution
- [x] **Options Strategy Roll Assistant** ([#157](https://github.com/CIInc/robinhood-options-mobile/issues/157), v0.49.0):
    - [x] 1-tap rolling wizard for covered calls, cash-secured puts, long options, and vertical spreads
    - [x] Automated net credit/debit calculation and total cash impact
    - [x] Strategy-aware updated breakeven projections taking into account cost basis and net credits
    - [x] Greeks shift comparison ($\Delta$, $\Gamma$, $\theta$, $\nu$, IV) and DTE extension
    - [x] 1-tap roll presets (`Roll Out`, `Roll Up & Out`, `Roll Down & Out`, `Custom`)
    - [x] Paper trading simulation and live 2-leg atomic order placement (`placeMultiLegOptionsOrder`)
- [x] **Option Chain Screener** ([#12](https://github.com/CIInc/robinhood-options-mobile/issues/12)):
    - [x] Advanced filtering (Delta, Theta, Gamma, IV, etc.)
    - [x] AI-powered "Find Best Contract" recommendations
    - [x] Filter presets (save/load/reset)
- [x] **Multi-Leg Strategy Builder** ([#68](https://github.com/CIInc/robinhood-options-mobile/issues/68)):
    - [x] Support for Spreads, Straddles, Iron Condors, Custom
    - [x] Visual payoff diagrams and risk/reward analysis
- [x] **Advanced Order Types** ([#108](https://github.com/CIInc/robinhood-options-mobile/issues/108)):
    - [x] Trailing Stop and Stop-Limit orders
    - [x] Time in Force support (GTC, GFD, IOC, OPG)
    - [x] **Order Templates**: Save and reuse complex order configurations
- [x] **Trading UI Refactor**:
    - [x] Improved order preview and placement flow
- [x] **Stock Orders** ([#107](https://github.com/CIInc/robinhood-options-mobile/issues/107)):
    - [x] Place stock orders directly from the app
- [x] **Dynamic Position Sizing**:
    - [x] Automatically calculate trade size based on risk parameters
- [x] **Pattern Day Trader (PDT) Protection & Counter** (v0.42.0):
    - [x] Real-time rolling 5-day counter for equities and options (`/accounts/{account}/recent_day_trades/`)
    - [x] FINRA Rule 4210 $25,000 equity threshold tracking and live deficit calculations
    - [x] Action Center critical and warning risk alerts in `PortfolioAlertService` with $25k equity exemption suppression
    - [x] `DayTradeMonitorWidget` dashboard with 4-segment visual counter and segmented filters

### Brokerage & Asset Expansion
- [x] **Crypto Trading** ([#116](https://github.com/CIInc/robinhood-options-mobile/issues/116)):
    - [x] Dedicated widgets for placing and managing crypto orders
    - [x] Integrated into main trading interface
    - [x] Modernized Forex & Crypto Instrument View (Technical Analysis Card, Bottom Sheet, Candlesticks, and Controls)
- [x] **Forex Trading** ([#116](https://github.com/CIInc/robinhood-options-mobile/issues/116)):
    - [x] Currency pairs trading (EUR/USD, USD/JPY, GBP/USD, etc.) with lot sizing presets
    - [x] Stop order protection and live pip value calculations
    - [x] Carry Trade Optimizer with interest rate differential matrix and basket builder
    - [x] Multi-Asset Portfolio Allocation across Stocks, Options, Crypto, Forex, Futures, Fixed Income, and Cash
- [x] **Schwab Integration** ([#4](https://github.com/CIInc/robinhood-options-mobile/issues/4), [#8](https://github.com/CIInc/robinhood-options-mobile/issues/8), [#122](https://github.com/CIInc/robinhood-options-mobile/issues/122)):
    - [x] Native Schwab brokerage support
    - [x] Enhanced option order handling

### AI & Insights
- [x] **Generative AI Assistant** ([#74](https://github.com/CIInc/robinhood-options-mobile/issues/74)):
    - [x] Integrate `firebase_ai` for natural language queries
    - [x] Implement portfolio insights and summaries (via GenerativeActionsWidget)
- [x] **Model Context Protocol (MCP)** (v0.36.0):
    - [x] Native local MCP client (`package:mcp_dart`) for secure broker tool execution
    - [x] Interactive tool execution visualboards (trace cards) in chat
    - [x] Conversational trading proposal parsing and native order approval sheets
    - [x] On-device sandboxed execution of brokerage tools (positions, watchlists, quotes)
    - [x] Integrated OAuth2 PKCE authentication flow for secure tools access
- [x] **Investment Profile** ([#128](https://github.com/CIInc/robinhood-options-mobile/issues/128)):
    - [x] User settings for Investment Goals, Time Horizon, Risk Tolerance
    - [x] Integration with AI prompts for personalized advice
- [x] **Market Sentiment Tracking**:
    - [x] Real-time sentiment scoring (Bullish/Bearish/Neutral) visualized via a dedicated market dashboard and home screen card
- [x] **AI Trading Coach**:
    - [x] Behavioral modeling assigning a Discipline Score and Trader Archetype based on historical executions, featuring custom personas, streak tracking, and accountability challenges
- [x] **Price Targets & Instrument Notes**:
    - [x] Persistent trading journals with Markdown support and AI drafting alongside quantitative target estimations

### Notifications & Smart Alerts
- [x] **Custom Alerts**: Multi-condition price, volume, and volatility alerts with trigger history ([#81](https://github.com/CIInc/robinhood-options-mobile/issues/81))
- [x] **Instrument-Level Custom Alerts** (v0.47.1): Direct embedded alert creation and toggles in stock/option detail pages ([#81](https://github.com/CIInc/robinhood-options-mobile/issues/81), [Tracking: #115](https://github.com/CIInc/robinhood-options-mobile/issues/115))
- [x] **Rich Trade Notifications**: Actionable push notifications with charts, options flow flags, and deep linking ([#80](https://github.com/CIInc/robinhood-options-mobile/issues/80))
- [x] **Dynamic Alert Thresholds**: AI- and ATR-calculated volatility breakout bands (v0.38.0)
- [x] **Notification History**: Filterable in-app audit ledger of past notifications ([#82](https://github.com/CIInc/robinhood-options-mobile/issues/82))

### Cash Management, Banking & Retirement
- [x] **Securities Lending (SLIP)**: Fully Paid Stock Loan income tracking and agreement management (`/accounts/stock_loan_payments/`)
- [x] **High-Yield Cash Sweeps**: FDIC cash sweep balance monitoring and multi-tier APY interest rate tracking (`/accounts/sweeps/interest/`)
- [x] **Banking & ACH Transfers**: Monitor bank deposits, withdrawals, clearing status, and linked accounts (`/ach/transfers/`, `/ach/relationships/`)
- [x] **Corporate Action Splits**: Stock split payments, cash-in-lieu adjustments, and tax basis tracking (`/corp_actions/v2/split_payments/`)
- [x] **Multi-Account & Retirement Expansion**: Traditional and Roth IRA account hydration with annual contribution tracking
- [x] **Tax Documents & Account Statements**: Direct in-app download and review of Form 1099, monthly statements, and withholding status (`/documents/`, `/tax_info/`)
- [x] **Shareholder Say Q&A Engagement**: Verified shareholder Q&A submission and voting for earnings calls (`/qa/events-section/`)

### Infrastructure & Security
- [x] **User Authentication** ([#22](https://github.com/CIInc/robinhood-options-mobile/issues/22)): Robust user authentication system
- [x] **OAuth2 Refresh** ([#14](https://github.com/CIInc/robinhood-options-mobile/issues/14)): Handle token refresh seamlessly
- [x] **Secure Storage** ([#88](https://github.com/CIInc/robinhood-options-mobile/issues/88)): Secure storage for OAuth tokens
- [x] **Apple Silicon Support** ([#11](https://github.com/CIInc/robinhood-options-mobile/issues/11)): Fix ITMS-90899 for Macs with Apple silicon
- [x] **iOS Entitlements** ([#10](https://github.com/CIInc/robinhood-options-mobile/issues/10)): Fix ITMS-90078 missing potentially required entitlement
- [x] **In-App Purchases**: Subscription infrastructure for premium features (Trade Signals)
- [x] **Security & Privacy Enhancements**:
    - [x] **Balance Visibility Toggle** (v0.37.0): Global privacy mask for P&L and equity
    - [x] **Multi-Account Selection & Sync** (v0.36.0): Persistent SharedPreferences-backed account state
    - [x] **Secure Toolboards**: Local-only execution of brokerage actions via MCP
    - [x] **Firebase Role Authorization & Input Validation** ([#156](https://github.com/CIInc/robinhood-options-mobile/pull/156), v0.49.0): Hardened `changeUserRole` callable function with strict group admin verification and input validation
    - [x] **Android Adaptive Splash Screen Brand Parity** (v0.49.0): Aligned Android launch screen and Android 12+ splash screens with iOS design, dark theme background (`#1C1B1F`), emblem, title, and subtitle typography
    - [x] **Paper Trading Circuit Breaker Decoupling** (v0.49.0): Bypassed live risk circuit breaker checks for simulated paper trades so users can test strategies freely

## Planned Enhancements 🚀

### Delivery Priorities

This sequence is the planning order; version dates below are tentative, not release commitments. GitHub issue labels establish urgency, while unchecked roadmap items remain candidates until their acceptance criteria and dependencies are clear.

1. **Reliability and execution safety:** Prioritize technical debt and performance ([#124](https://github.com/CIInc/robinhood-options-mobile/issues/124)), widget coverage ([#90](https://github.com/CIInc/robinhood-options-mobile/issues/90)), and Schwab order preview/margin verification ([#122](https://github.com/CIInc/robinhood-options-mobile/issues/122)); all carry high-priority labels. Resolve the deferred MFA provider and cost decision ([#89](https://github.com/CIInc/robinhood-options-mobile/issues/89)) before scheduling implementation.
2. **Copy-trading transparency and safeguards:** For the proposed v0.52 work ([#141](https://github.com/CIInc/robinhood-options-mobile/issues/141)), establish fill/slippage measurement, follower exposure limits, and clear stop/disconnect behavior before expanding automation. Keep server-side execution gated on a security and credential-custody design.
3. **Social foundations:** Scope discussion and portfolio comparison under the social tracker ([#113](https://github.com/CIInc/robinhood-options-mobile/issues/113)) with moderation, privacy, and reporting requirements. Tournaments are exploratory until scoring integrity and abuse controls are specified.
4. **Research and new integrations:** Revisit SEC/EDGAR ingestion ([#143](https://github.com/CIInc/robinhood-options-mobile/issues/143)) after data-source terms, update cadence, provenance, and operating cost are validated. Keep multimodal sentiment and other provider-dependent work behind measurable evaluation plans.


### Portfolio & Analysis

**Strategic Rationale:**
Prioritize analytical correctness, understandable risk presentation, and evidence-backed alerts. New model-based recommendations should include source/freshness context and be evaluated before they influence execution.

**Technical Complexity:** High (AI integration, real-time data, complex calculations)
**User Impact:** Very High (daily use features)
**Revenue Impact:** High (AI insights enable premium tier)

#### Portfolio Management ([Tracking: #114](https://github.com/CIInc/robinhood-options-mobile/issues/114))
- [x] **Advanced Portfolio Analytics**: Sharpe ratio, alpha, beta calculations - **Medium** (2-3 weeks)
- [x] **Risk Exposure Heatmaps**: Visualize portfolio risk distribution - **Medium** (2-3 weeks)
- [x] **Dividend Tracking**: Track and project dividend income - **Small** (1-2 weeks)
- [x] **Portfolio Rebalancing**: Rebalancing recommendations - **Medium** (2-3 weeks)
- [x] **Tax Loss Harvesting (Basic)**: Tax optimization suggestions - **Medium** (2-3 weeks)
- [x] **Tax Optimization Suite & Wash Sale Detector** (v0.48.0, [Tracking: #114](https://github.com/CIInc/robinhood-options-mobile/issues/114)):
    - [x] **Rolling 30-Day Wash Sale Window Tracker**: Proactive cross-instrument alerts across equities and options before triggering disallowed loss repurchases - **Medium** (2-3 weeks)
    - [x] **Automated Tax Loss Harvesting Opportunity Scanner**: Scan unrealized losses against realized capital gains with correlated replacement recommendations - **Medium** (2 weeks)
    - [x] **Short-Term vs. Long-Term Capital Gains Breakdown**: Real-time holding duration timers and tax liability projections - **Small** (1-2 weeks)
    - [x] **Specific Tax Lot Matching (HIFO/LIFO Order Entry)** (v0.48.0, [Tracking: #114](https://github.com/CIInc/robinhood-options-mobile/issues/114)): Select specific tax lots or tax-minimization sorting rules at order placement to minimize taxable gains - **Small** (1-2 weeks)
    - [x] **IRS Form 8949 Reconciliation & CSV Export**: Schedule D export with wash sale adjustment codes (`W`) - **Small** (1 week)
- [x] **ESG Scoring**: Portfolio Environmental, Social, and Governance analysis - **Small** (1-2 weeks)
- [x] **Multi-Account Aggregation**: View all accounts together - **Medium** (2-3 weeks)
- [x] **Import/Export**: Fidelity CSV import, CSV export for portfolio analytics - **Small** (1-2 weeks)
- [x] **AI Portfolio Architect (Alpha)** (v0.37.1): Natural language portfolio construction - **Large** (4-6 weeks)
- [x] **Unified Margin Health & Collateral Tracking** (v0.44.0): Monitor margin buffers, warning states, and option/crypto collateral allocations (`/phoenix/accounts/unified`) - **Medium** (2-3 weeks)
- [x] **Pattern Day Trader (PDT) Protection & Counter** (v0.42.0): Real-time rolling 5-day day-trade counter for equities and options to prevent regulatory PDT restrictions (`/accounts/{account}/recent_day_trades/`) - **Small** (1-2 weeks)
- [x] **Margin Calls & Financing Costs** (v0.44.0): Real-time margin call deficit notifications and monthly margin interest debit history (`/margin/calls/`, `/cash_journal/margin_interest_charges/`) - **Small** (1-2 weeks)
- [x] **Instrument-Specific Buying Power & Trade Warnings** (v0.44.0): Real-time buying power per instrument and risk/volatility warnings (`/accounts/{account}/instrument_buying_power/{id}/`, `/instruments/{id}/v2/warnings/`) - **Small** (1-2 weeks)
- [x] **Options Collateral & Tier Upgrades** (v0.44.0): Chain-level cash/equity collateral breakdown (`/options/chains/{id}/collateral/`) and upgrade eligibility (`/options/should_show_options_upgrade_on_sdp/`) - **Small** (1-2 weeks)
- [x] **Instrument Previous Positions & Cost Basis Lookback** (v0.44.0): Historical round-trip position reconstruction, FIFO cost basis lookback, realized P&L, hold duration, and order audit trail - **Small** (1-2 weeks)
- [x] **Stock Lending Program (SLIP) Dashboard** (v0.45.0): Track loaned shares, earned yield payments, and agreement eligibility (`/accounts/stock_loan_payments/`, `/slip/eligibility/`) - **Small** (1-2 weeks)
- [x] **Cash Sweeps & APY Rate Monitor** (v0.45.0): Track FDIC sweep balances and multi-tier interest rates (`/accounts/sweeps/interest/`) - **Small** (1 week)
- [x] **Banking & ACH Transfers** (v0.45.0): Monitor bank deposits, withdrawals, clearing status, and linked accounts (`/ach/transfers/`, `/ach/relationships/`) - **Small** (1-2 weeks)
- [x] **Tax Documents & Account Statements** (v0.45.0): In-app download and review of Form 1099, monthly statements, and withholding status (`/documents/`, `/tax_info/`) - **Small** (1 week)
- [x] **Corporate Action Split Adjustments** (v0.45.0): Stock split payments, cash-in-lieu tracking, and ratio adjustments (`/corp_actions/v2/split_payments/`) - **Small** (1 week)
- [x] **Shareholder Say Q&A Engagement** (v0.45.0): Verified shareholder Q&A viewing and submission for upcoming earnings calls (`/qa/events-section/`) - **Small** (1-2 weeks)
- [x] **Multi-Account & Retirement Expansion** (v0.45.0): Full multi-account hydration including Traditional/Roth IRAs, annual contribution limits, Robinhood Gold match tracker, spending accounts, connected external OAuth agents, and notification center - **Medium** (2 weeks)
- [x] **Automated DRIP with Threshold** ([#23](https://github.com/CIInc/robinhood-options-mobile/issues/23)): Dividend reinvestment at price thresholds - **Small** (1 week)
- [x] **Benchmark Comparison** ([#18](https://github.com/CIInc/robinhood-options-mobile/issues/18)): Compare against market indices - **Small** (1 week)
- [x] **Beta-Weighted Portfolio Delta & Cross-Asset Greeks Engine** (v0.51.0): Portfolio-wide beta-weighting ($\Delta_{\beta-SPY}$) and aggregate Gamma/Vega across stocks, options, crypto, futures, and forex to quantify true market-move dollar risk ([Tracking: #137](https://github.com/CIInc/robinhood-options-mobile/issues/137)) - **Medium** (2-3 weeks)

#### Research & Quantitative ([Tracking: #137](https://github.com/CIInc/robinhood-options-mobile/issues/137))
- [x] **Alpha Factor Discovery**: Research engine for signal correlation - **Medium** (3-4 weeks)
- [x] **Event Study Analyzer** (v0.37.5): Stock performance around specific event windows
- [x] **Rolling Statistics Dashboard** (v0.37.5): Dynamic volatility, beta, and correlation tracking
- [x] **Custom Screener Builder** (v0.37.5): Advanced multi-factor filtering UI - **Medium** (3-4 weeks)
- [x] **First-Party Institutional & Hedge Fund Tracking**: Real-time hedge fund sentiment, quarterly manager holdings, and transaction history directly from Robinhood marketdata endpoints (`/marketdata/hedgefunds/`) - **Small** (1-2 weeks)
- [x] **First-Party Insider Sentiment & Activity**: Monthly aggregate insider transactions and director/officer Form 4 tracking (`/marketdata/insiders/`) - **Small** (1-2 weeks)
- [x] **Robinhood Retail Flow & Sentiment**: Net buy/sell percentage and order volume trends (`/marketdata/equities/summary/robinhood/`) - **Small** (1-2 weeks)
- [x] **Short Float & Live Shorting Rates**: Real-time free float short percentage, shares short, borrow inventory levels, and borrow fee rates (`/marketdata/fundamentals/short/v1/`, `/instruments/{id}/shorting/`) - **Small** (1-2 weeks)
- [x] **Robinhood Curated Screener Presets**: Backend screener presets integration (`/screeners/presets/`, `/screeners`) - **Small** (1 week)
- [x] **Income View NAV** ([#20](https://github.com/CIInc/robinhood-options-mobile/issues/20)): Net Asset Value tracking - **Small** (1 week)
- [x] **Income Chart** ([#17](https://github.com/CIInc/robinhood-options-mobile/issues/17)): Portfolio income visualization - **Small** (1 week)
- [x] **Dividend History** ([#3](https://github.com/CIInc/robinhood-options-mobile/issues/3)): Historical dividend tracking - **Small** (1 week)
- [x] **Income Interest List** ([#6](https://github.com/CIInc/robinhood-options-mobile/issues/6)): Interest payment tracking - **Small** (1 week)
- [ ] **SEC EDGAR Real-Time 13F & Form 4 Insider Whales Ingestion** (v0.53.0, [Tracking: #143](https://github.com/CIInc/robinhood-options-mobile/issues/143)): Automated streaming ingestion of Form 4 insider cluster purchases and 13F institutional disclosures with portfolio overlap alerts - **Large** (4-5 weeks)

#### Analytics & Insights ([Tracking: #118](https://github.com/CIInc/robinhood-options-mobile/issues/118))
- [x] **Generative AI Assistant**: Natural language portfolio insights ([#74](https://github.com/CIInc/robinhood-options-mobile/issues/74))
    - [x] Add chat interface for market questions
    - [x] **Agentic Reasoning Mode** (v0.37.0): Deep multi-step analysis for trade generation
    - [x] **Personalized AI Coach**: Analyze user's manual trading history to identify biases and suggest improvements (v0.28.0) - **Large** (5-7 weeks)
    - [ ] **Natural Language Interface**: "Chat with your Portfolio" feature to ask questions about performance and risk - **Large** (6-8 weeks)
- [x] **News Intelligence & Summarization** (v0.38.0):
    - [x] **AI News Summarizer**: Breaking news impact analysis and catalyst extraction for instruments and watchlists
    - [x] **Real-time Sentiment Scoring**: Quantifying news and catalyst impact on specific tickers
    - [x] **Event Impact Prediction**: Transparent baseline modeling of directional price responses to news events
- [ ] **Sentiment Analysis 2.0**: Real-time video/audio sentiment analysis (e.g., Fed speeches) - **Large** (4-5 weeks)
- [x] **Macro-Economic Indicators**: Incorporate interest rates, inflation, and economic calendar events into the "Market Direction" indicator - **Medium** (3-4 weeks)
- [ ] **Specialized AI Agents**:
    - [x] **Sentiment Agent**: Cache-only agent analyzing news sentiment and adjusting trade confidence - **Medium** (3-4 weeks)
    - [x] **Macro Agent**: Agent that monitors economic calendar and adjusts global risk parameters - **Medium** (3-4 weeks)
    - [ ] **Live & Social Sentiment Agent**: Expand sentiment beyond cached news into low-latency social, audio, and video signals. This agent must remain an advisory confidence input until source quality and financial-safety validation are established - **Large** (8-12 weeks)
        - [ ] **Source Adapters**: Add authenticated, rate-limited connectors for supported social feeds, earnings-call transcripts, and public Fed speeches
        - [ ] **Streaming Ingestion**: Normalize events into a durable queue with deduplication, symbol/entity resolution, timestamps, and replay support
        - [ ] **Multimodal Scoring**: Score text, transcript, and audio/video-derived sentiment with confidence, source quality, bot/spam likelihood, and event impact
        - [ ] **Cross-Source Fusion**: Combine news, social, options flow, and macro sentiment while preserving per-source attribution and disagreement signals
        - [ ] **Freshness & Degradation Controls**: Expire stale scores, cap source influence, detect provider outages, and fall back to cached news or technical signals
        - [ ] **User Experience**: Add live sentiment timelines, source-level explanations, confidence bands, and opt-in alerts for holdings and watchlists
        - [ ] **Validation & Safety**: Backtest event reactions, measure precision/recall by source and regime, audit false positives, and prevent sentiment alone from authorizing trades
- [ ] **Congress Trading Tracker**: Automatic monitoring of congressional stock disclosures with alerts - **Medium** (3-4 weeks)
- [ ] **Institutional Flow Tracker**: Track 13F filings and large institutional position changes - **Large** (4-5 weeks)
- [ ] **AI-Powered Research Reports**: Auto-generate comprehensive research reports for holdings - **Large** (5-6 weeks)
- [ ] **Multi-Model AI Consensus Engine** (v0.54.0, [Tracking: #118](https://github.com/CIInc/robinhood-options-mobile/issues/118)): Synthesize multiple AI models (Gemini 3.1 Flash-Lite, local factor engines, deep reasoning agents) to generate high-conviction trade consensus ratings - **Medium** (3-4 weeks)
- [ ] **AI Devil's Advocate & Trade Thesis Stress Tester** (v0.54.0, [Tracking: #118](https://github.com/CIInc/robinhood-options-mobile/issues/118)): Automated adversarial critique generating objective Bear vs. Bull counter-arguments, skew traps, and event hazards before entering trades - **Medium** (3-4 weeks)
- [ ] **Autonomous Agentic Risk Copilot** (v0.54.0, [Tracking: #118](https://github.com/CIInc/robinhood-options-mobile/issues/118)): Continuous background monitor assessing overnight gap risk, earnings hazard warnings for open positions, and suggested delta hedges - **Medium** (3-4 weeks)
- [ ] **AI Trade Post-Mortem & Behavioral Journal Auto-Tagger** (v0.54.0, [Tracking: #118](https://github.com/CIInc/robinhood-options-mobile/issues/118)): Automated diagnostic review upon position exit analyzing cognitive biases, execution flaws, and tactical lessons - **Medium** (2-3 weeks)
- [x] **Autonomous Risk Circuit Breakers** (v0.48.5, [Tracking: #142](https://github.com/CIInc/robinhood-options-mobile/issues/142)): Hard user-defined limits (max daily loss, drawdown limit, cooling-off trading suspension) that proactively lock execution to protect capital - **Medium** (2-3 weeks)

#### Notifications & Alerts ([Tracking: #115](https://github.com/CIInc/robinhood-options-mobile/issues/115))
- [x] **Custom Alerts**: Price, volume, and volatility alerts ([#81](https://github.com/CIInc/robinhood-options-mobile/issues/81))
- [x] **Instrument-Level Custom Alerts** (v0.47.1): Direct alert creation and management embedded within instrument detail views ([#81](https://github.com/CIInc/robinhood-options-mobile/issues/81), [Tracking: #115](https://github.com/CIInc/robinhood-options-mobile/issues/115))
- [x] **Notification History**: In-app log of past notifications ([#82](https://github.com/CIInc/robinhood-options-mobile/issues/82))
- [ ] **Email/SMS Channels**: Critical signal notifications via multiple channels
- [ ] **Alert Customization**: Custom sounds and per-signal preferences
- [ ] **Earnings Calendar Notifications**: Earnings date alerts
- [ ] **Options Expiration Alerts**: Contract expiration reminders
- [ ] **News Alerts**: News notifications for holdings
- [ ] **Unusual Activity Alerts**: Unusual volume/price movement detection
- [ ] **Group Activity Notifications**: Investor group trade updates
- [x] **Multi-Condition Alert Builder** (v0.38.0): Combine multiple conditions (price + volume + RSI + GEX) - **Medium** (3-4 weeks)
- [x] **Dynamic Alert Thresholds**: AI-calculated levels based on trailing volatility - **Small** (1-2 weeks)
- [ ] **Earnings Surprise Predictor**: Machine learning model to predict earnings beats/misses - **Large** (5-6 weeks)
- [ ] **Dark Pool Activity Alerts**: Monitor off-exchange trading anomalies - **Medium** (3-4 weeks)
- [ ] **Insider Trading Pattern Recognition**: Detect significant insider buying/selling - **Medium** (3-4 weeks)
- [x] **0DTE Flow & Intraday Gamma Squeeze Radar** (v0.51.0, [Tracking: #115](https://github.com/CIInc/robinhood-options-mobile/issues/115)): Real-time monitoring of 0DTE flow velocity, dealer gamma flip thresholds, and gamma squeeze risk alerts - **Medium** (3-4 weeks)
- [x] **Earnings IV Crush Probability & Straddle Pricing Estimator** (v0.51.3, [Tracking: #137](https://github.com/CIInc/robinhood-options-mobile/issues/137)): Implied earnings move vs. actual historical moves over 12 quarters, post-earnings IV crush calculation, and expected value (EV) straddle pricing distributions - **Medium** (2-3 weeks)
- [x] **Realized vs. Implied Volatility (IV) Cone & Rank/Percentile** (v0.51.4, [Tracking: #137](https://github.com/CIInc/robinhood-options-mobile/issues/137)): Multi-timeframe IV percentiles (30d/60d/90d), volatility skew surfaces, and pre-earnings IV crush indicators - **Medium** (2-3 weeks)
- [x] **Implied Volatility Surface 3D Visualizer** (v0.51.5, [Tracking: #137](https://github.com/CIInc/robinhood-options-mobile/issues/137)): Interactive 3D surface plot across strikes and expiration dates with regularized grid interpolation, Dupire local volatility, and arbitrage checks - **Medium** (2-3 weeks)
- [x] **Delta-Neutral Strategy Builder** (v0.51.6, [Tracking: #137](https://github.com/CIInc/robinhood-options-mobile/issues/137), [Tracking: #108](https://github.com/CIInc/robinhood-options-mobile/issues/108)): Multi-leg hedging tool calculating dynamic delta offsets, automated share/option rebalancing suggestions, and interactive spot-shift scenario simulation - **Medium** (2-3 weeks)

### Trading & Automation

**Target:** Advanced execution, algorithmic trading, and copy trading evolution.

**Strategic Rationale:**
Improve copy-trade transparency and follower controls before increasing automation. Execution changes must preserve explicit user approval, account isolation, and credential security.

#### Copy Trading Evolution ([Tracking: #141](https://github.com/CIInc/robinhood-options-mobile/issues/141))
- [x] **Trader Comparison** (v0.52.0, [Tracking: #141](https://github.com/CIInc/robinhood-options-mobile/issues/141), [Tracking: #113](https://github.com/CIInc/robinhood-options-mobile/issues/113)): Side-by-side performance comparison of potential leaders with normalized timeframes and risk-adjusted metrics - **Medium** (2-3 weeks)
- [ ] **Time-Based Analysis**: Cumulative P&L growth visualization over time - **Medium** (2-3 weeks)
- [ ] **Export History**: CSV export of copy trade history and performance - **Small** (1 week)
- [x] **Copy-Trading Slippage & Fill Divergence Analytics** (v0.52.0, [Tracking: #141](https://github.com/CIInc/robinhood-options-mobile/issues/141)): Track execution latency (ms), fill price delta vs. leader, and performance drift - **Small** (1-2 weeks)
- [x] **Automated Copy-Trading Risk Guardian** (v0.52.0, [Tracking: #141](https://github.com/CIInc/robinhood-options-mobile/issues/141)): Follower protective guardrails specifying max capital allocation per trade, auto-disconnect on leader drawdown divergence, and max slippage abort - **Medium** (2-3 weeks)
- [ ] **Server-Side Auto-Execute**: Secure server-side execution to reduce latency and remove client dependency (requires secure key management) - **Large** (4-6 weeks)

#### Strategy Automation
- [x] **Options Strategy Roll Assistant** (v0.49.0, [#157](https://github.com/CIInc/robinhood-options-mobile/issues/157)): 1-tap rolling wizard for covered calls, cash-secured puts, and credit spreads with automated net credit/debit calculation and new breakeven projections - **Small** (1-2 weeks)
- [x] **Multi-Leg Options Defense & Roll Playbook** (v0.50.0, [#158](https://github.com/CIInc/robinhood-options-mobile/issues/158)): Automated defensive action recommendations when short legs are tested (e.g. rolling out in time, widening spreads, inverted strangles, converting to iron condors) - **Small** (1-2 weeks)
- [ ] **Strategy Marketplace**: Platform for users to share, rate, and clone successful Agentic Trading configurations - **Large** (6-8 weeks)
- [ ] **Multi-Leg Order Templates**: Quick-entry templates for complex spreads - **Small** (1-2 weeks)
- [x] **Combo Orders Support**: Stock + Option atomic order execution and history (`/combo/orders/`) - **Medium** (2-3 weeks)
- [ ] **Smart Order Routing (SOR) & Cross-Broker Margin & Borrow Optimizer** (v0.53.0): Dynamically evaluate and route equity/option orders between connected brokerages (Schwab and Robinhood) to minimize margin requirements, borrow fees, and maximize uninvested cash yields - **Large** (6-8 weeks)

#### Behavioral & Tilt Guardrails ([Tracking: #142](https://github.com/CIInc/robinhood-options-mobile/issues/142))
- [x] **Autonomous Risk Circuit Breakers & Cooling-Off Lock** (v0.48.5, [Tracking: #142](https://github.com/CIInc/robinhood-options-mobile/issues/142)): Daily max loss, portfolio drawdown, and consecutive loss guardrails
- [ ] **Biometric Tilt & Panic Trading Guardian** (v0.54.0, [Tracking: #142](https://github.com/CIInc/robinhood-options-mobile/issues/142)): Integrates with Apple HealthKit / Wear OS biometric data (heart rate spikes) and rapid erratic order tapping to detect emotional tilt and enforce cooling-off locks - **Medium** (2-3 weeks)

### Social & Community

**Strategic Rationale:**
Social features already delivered include groups, following, feeds, and leaderboards. Remaining work should focus on useful discussion and privacy-respecting comparisons; defer growth mechanics until moderation and fair-performance measurement are specified.

**Technical Complexity:** Medium (real-time messaging, social APIs)
**User Impact:** High (engagement features)
**Revenue Impact:** High (network effects drive adoption)

#### Investor Groups ([Tracking: #113](https://github.com/CIInc/robinhood-options-mobile/issues/113))
- [x] **Group Chat**: Real-time messaging within groups ([#76](https://github.com/CIInc/robinhood-options-mobile/issues/76)) - **Large** (3-4 weeks)
- [x] **Performance Analytics**: Group leaderboards and performance tracking ([#77](https://github.com/CIInc/robinhood-options-mobile/issues/77)) - **Medium** (2-3 weeks)
- [x] **Activity Feed**: Real-time feed of member trades ([#78](https://github.com/CIInc/robinhood-options-mobile/issues/78)) - **Medium** (2-3 weeks)
- [x] **Shared Watchlists**: Collaborative watchlists for groups ([#79](https://github.com/CIInc/robinhood-options-mobile/issues/79)) - **Small** (1-2 weeks)
- [ ] **Public Leaderboards**: Ranked lists of top-performing public investor groups and strategies - **Medium** (2-3 weeks)
- [x] **Verified Track Records**: Cryptographic proof of historical performance and brokerage verification for public profiles ([Tracking: #113](https://github.com/CIInc/robinhood-options-mobile/issues/113)) - **Medium** (3-4 weeks)
- [ ] **Video Rooms**: Live video chat for group strategy discussions - **Large** (4-5 weeks)
- [x] **Collaborative Analysis Boards**: Shared thesis sharing, price targets, risk/reward calculations, and idea discussion ([Tracking: #113](https://github.com/CIInc/robinhood-options-mobile/issues/113)) - **Medium** (3-4 weeks)
- [ ] **Trading Arenas & Verified Paper Tournaments** (v0.52.0, [Tracking: #113](https://github.com/CIInc/robinhood-options-mobile/issues/113)): Weekly/monthly trading challenges with live leaderboards, verifiable track records, and milestone achievement badges - **Medium** (3-4 weeks)
- [ ] **Group Challenges & Competitions**: Gamified trading competitions with prizes - **Medium** (3-4 weeks)

#### Social Feed & Engagement ([Tracking: #113](https://github.com/CIInc/robinhood-options-mobile/issues/113))
- [ ] **Social Signal Sharing**: Share strategies with community - **Medium** (2-3 weeks)
- [x] **Follow Portfolios** ([#27](https://github.com/CIInc/robinhood-options-mobile/issues/27)): Follow other users' portfolios, privacy controls, activity feed, and trade alerts - **Small** (1-2 weeks)
- [x] **Portfolio Comparison Tools** (v0.52.0, [Tracking: #113](https://github.com/CIInc/robinhood-options-mobile/issues/113), [Tracking: #141](https://github.com/CIInc/robinhood-options-mobile/issues/141)): Side-by-side multi-trader portfolio comparison across returns, risk, execution, and reputation - **Medium** (2-3 weeks)
- [x] **Top Portfolios Leaderboard** ([#26](https://github.com/CIInc/robinhood-options-mobile/issues/26)): Showcase top-performing portfolios - **Medium** (2-3 weeks)
- [x] **Social Discussion & Comment Threads** (v0.52.0, [Tracking: #113](https://github.com/CIInc/robinhood-options-mobile/issues/113)): Granular discussions on shared trade ideas and portfolios with author pinned comments, community sentiment polling, and upvoting - **Small** (1-2 weeks)
- [x] **Social Feed**: Trade notifications, shared ideas, and portfolio updates ([#24](https://github.com/CIInc/robinhood-options-mobile/issues/24))
- [x] **User Reputation System**: Community credibility tracking - **Medium** (2-3 weeks)
- [ ] **Achievement Badges**: Gamification elements - **Small** (1 week)
- [ ] **Reddit Integration**: Trending ticker information - **Small** (1-2 weeks)
- [ ] **Twitter Sentiment**: Market sentiment tracking - **Medium** (2-3 weeks)
- [x] **Community Trade Ideas**: Crowdsourced trade suggestions and strategy cloning ([#24](https://github.com/CIInc/robinhood-options-mobile/issues/24))
- [x] **RealizeAlpha Social Platform** ([#24](https://github.com/CIInc/robinhood-options-mobile/issues/24)): Comprehensive social features with following, leaderboards, feeds, and copy trading
- [x] **Share Portfolio** ([#25](https://github.com/CIInc/robinhood-options-mobile/issues/25)): Share portfolio performance via deep links and Investor Groups
- [ ] **Zero-Knowledge Proofs (ZKP) for Private Social Trading** (v0.55.0+): Cryptographically verifiable track record badges (Sharpe, win rate, return %) without revealing account equity or dollar trade amounts - **Large** (4-6 weeks)

### Platform Foundation & Operations

**Strategic Rationale:**
Keep reliability, account security, and test coverage ahead of feature breadth. Define measurable performance budgets and focused acceptance criteria for platform work before assigning release targets.

**Technical Complexity:** High (DevOps, cryptography, legacy refactoring)
**User Impact:** Indirect but critical (speed, uptime, trust)
**Revenue Impact:** Medium (enables growth, prevents churn)

#### App Experience
- [ ] **Smart Watch App & Wearables**: Apple Watch and Wear OS companion apps with glanceable portfolio P&L, price alerts, and watchlists (v0.56.0) - **Medium** (2-3 weeks)
- [x] **iOS Live Activities & Dynamic Island Widget** (v0.50.0, [#160](https://github.com/CIInc/robinhood-options-mobile/issues/160)): Real-time lock screen position tracking, P&L status, and 0DTE trailing stop alerts - **Small** (1-2 weeks)
- [x] **Offline Mode & Resilient Caching** (v0.50.0, [#87](https://github.com/CIInc/robinhood-options-mobile/issues/87)): Encrypted local cache for portfolio holdings, watchlists, and recent charts with background sync - **Medium** (2-3 weeks)
- [x] **Landscape Charting & Multi-Column Matrix View** (v0.50.0, [#117](https://github.com/CIInc/robinhood-options-mobile/issues/117)): Full-width widescreen charting mode with collapsible multi-leg order entry for tablet and mobile devices - **Small** (1-2 weeks)
- [ ] **Desktop & iPad Multi-Pane Floating Workspace** (v0.55.0+): Native Flutter Desktop (macOS/Windows) and iPad split-view workspace with floating order pads, live depth, and detachable charts - **Large** (4-6 weeks)
- [ ] **Hands-Free Voice-Activated Trade Drafting** (v0.55.0+): On-device speech recognition for conversational trade setup ("Roll my AAPL call up $5 for net credit") with one-touch biometric confirmation - **Medium** (2-3 weeks)
- [ ] **Accessibility**: Voice/Assistant integrations, dynamic type, haptic feedback
- [x] **Synchronized Position Scroll** ([#7](https://github.com/CIInc/robinhood-options-mobile/issues/7)): Synchronized scroll across portfolio position detail rows
- [x] **Position Bar Chart Values** ([#19](https://github.com/CIInc/robinhood-options-mobile/issues/19)): Combined display of both $ and % values in stock and option bar charts

#### Infrastructure & Security
- [x] **Biometric Authentication**: Face/fingerprint login ([#69](https://github.com/CIInc/robinhood-options-mobile/issues/69))
- [ ] **End-to-End Encryption**: Sensitive data encryption
- [x] **CI/CD Pipeline**: Automated testing and deployment ([#70](https://github.com/CIInc/robinhood-options-mobile/issues/70))
- [ ] **Performance & Technical Debt Optimization** ([#124](https://github.com/CIInc/robinhood-options-mobile/issues/124)): App size, market data batching, viewport fixes, and list scrolling performance
- [ ] **Security Audit & Infrastructure Roadmap** ([#135](https://github.com/CIInc/robinhood-options-mobile/issues/135)): Third-party security assessment, enterprise MCP hub, and zero-knowledge portfolio sharing

#### Data & Integration
- [ ] **Schwab Integration Expansion & Real-Time Streaming** ([#91](https://github.com/CIInc/robinhood-options-mobile/issues/91), [#93](https://github.com/CIInc/robinhood-options-mobile/issues/93), [#122](https://github.com/CIInc/robinhood-options-mobile/issues/122), [#145](https://github.com/CIInc/robinhood-options-mobile/issues/145)):
    - [x] Schwab Auth & Portfolio Sync (Phase 1)
    - [x] Schwab Options Order Placement (Phase 2, v0.37.5) - [Tracking: #138](https://github.com/CIInc/robinhood-options-mobile/issues/138)
    - [x] Schwab Multi-Account Support (Phase 3): Preserve Schwab account hash IDs and route orders to the selected account
    - [x] **Schwab Market Data Parity** ([#93](https://github.com/CIInc/robinhood-options-mobile/issues/93)):
        - [x] Real-time quote retrieval (`GET /marketdata/v1/quotes`) replacing stubbed `getQuote`/`refreshQuote`
        - [x] Historical OHLCV price candles (`GET /marketdata/v1/pricehistory`) for interactive charts and backtesting
        - [x] Fundamental equity data (`GET /marketdata/v1/instruments?projection=fundamental`) for market cap, PE, EPS, dividend yields
        - [x] Market Movers index data (`GET /marketdata/v1/movers/{index}`) for `$DJI`, `$COMPX`, `$SPX`
        - [x] Market operating hours and trading session status (`GET /marketdata/v1/markets`)
        - [x] Options expiration chains (`GET /marketdata/v1/expirationchain`) for fast expiration selectors
    - [ ] **Schwab Advanced Trading & Execution** ([#122](https://github.com/CIInc/robinhood-options-mobile/issues/122)):
        - [x] Order preview and margin validation (`POST /trader/v1/accounts/{accountNumber}/previewOrder`) for pre-trade buying power and commission check
        - [x] In-flight order replacement and modification (`PUT /trader/v1/accounts/{accountNumber}/orders/{orderId}`)
        - [ ] Multi-leg strategy options chains (`GET /marketdata/v1/chains?strategy=...`)
    - [ ] **Schwab Account Activity & Transactions** ([#91](https://github.com/CIInc/robinhood-options-mobile/issues/91)):
        - [ ] Historical trade transactions, dividends, and cash movements (`GET /trader/v1/accounts/{accountNumber}/transactions`) for realized P&L and dividend tracking
        - [ ] User preferences synchronization (`GET /trader/v1/userPreference`)
    - [x] **Schwab Real-Time WebSocket Streamer** ([#145](https://github.com/CIInc/robinhood-options-mobile/issues/145)):
        - [x] Streamer authentication and session handshake via `GET /trader/v1/userPreference` (`wss://streamer-api.schwab.com/ws`)
        - [x] Sub-second streaming quotes (`LEVELONE_EQUITIES`) and options Greeks (`LEVELONE_OPTIONS`)
        - [x] Real-time account and order activity notifications (`ACCT_ACTIVITY`)
        - [x] Streaming chart candle updates (`CHART_EQUITY`)
        - [x] Streaming futures (`LEVELONE_FUTURES`) and forex (`LEVELONE_FOREX`) feeds
- [x] **Robinhood Native Multi-Account & Retirement Support**:
    - [x] IRA Traditional & Roth Account support (`ira_traditional`, `ira_roth`) with contribution tracking
    - [x] Connected Agents & External Tokens management (`/oauth2/list_external_tokens/`)
    - [x] First-Party In-App Notifications & Stack announcements (`/inbox/threads/`, `/midlands/notifications/stack/`)
    - [x] Robinhood Crypto Direct Integration (native service complete; external API [#65](https://github.com/CIInc/robinhood-options-mobile/issues/65) wontfix)
- [x] **Yahoo Finance**: Real-time news and charting ([#121](https://github.com/CIInc/robinhood-options-mobile/issues/121))
- [ ] **Plaid Integration**: Full account linking, options support, and transaction sync ([#15](https://github.com/CIInc/robinhood-options-mobile/issues/15), [#92](https://github.com/CIInc/robinhood-options-mobile/issues/92), [#123](https://github.com/CIInc/robinhood-options-mobile/issues/123))
- [ ] **Multi-Broker**: Unified view across Fidelity (CSV import complete; direct API [#33](https://github.com/CIInc/robinhood-options-mobile/issues/33) invalid), Interactive Brokers ([#30](https://github.com/CIInc/robinhood-options-mobile/issues/30)), and others
- [ ] **Developer API & Local OpenAPI Webhook Gateway** (v0.55.0+): Embedded WebSocket and REST server allowing quant users to stream data and signals to external scripts - **Medium** (3-4 weeks)
- [ ] **SEC & EDGAR Data**: Direct access to regulatory filings and financial data ([Tracking: #143](https://github.com/CIInc/robinhood-options-mobile/issues/143))
    - [ ] Real-time 13F filings (Institutional Ownership)
    - [ ] Form 4 data (Insider Trading)
    - [ ] 10-K/10-Q Financial Statements parsing
    - [ ] 8-K Material Events alerts

#### Technical Excellence
- [x] **Testing**: Comprehensive unit, widget, and integration test coverage ([#75](https://github.com/CIInc/robinhood-options-mobile/issues/75), [#90](https://github.com/CIInc/robinhood-options-mobile/issues/90))
- [ ] **Code Quality & Maintenance** ([#125](https://github.com/CIInc/robinhood-options-mobile/issues/125)): Stricter linting (Dart 3 migration), resolving deprecations, and technical debt reduction
- [ ] **Documentation & Developer Experience** ([#94](https://github.com/CIInc/robinhood-options-mobile/issues/94), [#95](https://github.com/CIInc/robinhood-options-mobile/issues/95), [#96](https://github.com/CIInc/robinhood-options-mobile/issues/96), [#140](https://github.com/CIInc/robinhood-options-mobile/issues/140)): Complete API reference, developer onboarding guide, and Architecture Decision Records (ADRs)
- [x] **Monetization**: AdMob integration ([#120](https://github.com/CIInc/robinhood-options-mobile/issues/120)) and subscription management

### Future Horizons

**Target:** Long-term innovation and market leadership.

**Strategic Rationale:**
Staying ahead of the curve requires exploring frontier technologies. Decentralized identity and zero-knowledge proofs allow for privacy-preserving social trading. Multi-agent systems represent the next evolution of algorithmic trading. Innovation ensures long-term relevancy. Strategic importance: **Innovation & Future-Proofing**

#### Advanced Derivatives
- [ ] **Futures Trading**: Full lifecycle management, SPAN margin, and roll automation ([#67](https://github.com/CIInc/robinhood-options-mobile/issues/67), [#72](https://github.com/CIInc/robinhood-options-mobile/issues/72), [#103](https://github.com/CIInc/robinhood-options-mobile/issues/103), [#104](https://github.com/CIInc/robinhood-options-mobile/issues/104))
- [ ] **Risk Analytics**: Greeks, volatility surfaces, VaR adjustments, and seasonality analysis ([#105](https://github.com/CIInc/robinhood-options-mobile/issues/105), [#106](https://github.com/CIInc/robinhood-options-mobile/issues/106), [#111](https://github.com/CIInc/robinhood-options-mobile/issues/111))
- [x] **Forex Integration**: Multi-currency account support, FX trading, and Carry Trade Optimizer ([#116](https://github.com/CIInc/robinhood-options-mobile/issues/116))

#### Quantitative & Strategy
- [x] **Strategy Validator & Backtesting Engine** ([#136](https://github.com/CIInc/robinhood-options-mobile/issues/136)): Strategy template validation and historical backtesting engine
- [ ] **Advanced Monte Carlo Simulations**: Walk-forward analysis and multi-regime stress validation
- [ ] **Alpha Discovery**: Custom factor testing and correlation matrices ([#137](https://github.com/CIInc/robinhood-options-mobile/issues/137))
- [ ] **Smart Order Routing**: Execution optimization across venues ([#108](https://github.com/CIInc/robinhood-options-mobile/issues/108))

#### Social & Education
- [ ] **Education & Learning Platform** ([#119](https://github.com/CIInc/robinhood-options-mobile/issues/119)): Interactive tutorials, strategy guides, options education modules, and video explanations
- [ ] **Gamified Learning**: Trading challenges, XP systems, and certifications
- [ ] **Social Sentiment**: Crowdsourced trade ideas and sentiment tracking
- [ ] **Mentorship**: Community Q&A and verified expert badges

#### Frontier Tech
- [ ] **Multi-Agent Systems**: Autonomous DAO trading and strategy negotiation
- [ ] **Zero-Knowledge Proofs**: Privacy-preserving portfolio verification
- [ ] **Immersive Interfaces**: AR/VR visualization for multidimensional market data

#### Deferred Infrastructure
- [ ] **Two-Factor Authentication (2FA / MFA)** ([#89](https://github.com/CIInc/robinhood-options-mobile/issues/89)): Deferred pending Google Cloud Identity Platform infrastructure evaluation and pricing tier review.


## Feedback & Contribution

We value community feedback! If you have suggestions for the roadmap or want to contribute:
1. **Open an Issue**: Submit feature requests or bug reports on GitHub.
2. **Join the Discussion**: Participate in our community forums (coming soon).
3. **Submit a PR**: We welcome focused pull requests that include relevant tests and documentation.


