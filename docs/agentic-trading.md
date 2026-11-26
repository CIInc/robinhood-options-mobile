# Agentic Trading Documentation

## Overview

The Agentic Trading system provides autonomous, AI-powered trading capabilities for RealizeAlpha. It combines multi-indicator technical analysis with risk management controls to execute trades automatically based on qualified trading signals.

**Auto-Execution:** Auto-trading uses the configured foreground interval (five minutes by default) and requests a device-local background check about every 15 minutes while enabled and eligible. Live orders use the active account. Paper mode automatically uses the active account when it is Robinhood or Schwab; otherwise it uses the first linked Robinhood or Schwab account. When multiple supported brokerages are linked, users can optionally pin Paper quotes to one source. Simulated fills remain in the separate Paper ledger. The operating system controls background timing; checks may be delayed or skipped. Users remain responsible for monitoring open positions.

`BrokerageUserStore.currentUser` remains the active account. Live auto-trading requires that active account to be Robinhood or Schwab. Paper auto-trading uses the saved `paperQuoteSource`: the default `selectedBrokerage` mode prefers the active account when supported, then falls back to the first linked Robinhood or Schwab account. Explicit Robinhood or Schwab selections pin quotes to a linked account of that brokerage type, independent of the account being viewed; if multiple logins exist for a pinned source, the first linked login is used. Without any linked supported account, Paper cycles are blocked. The settings screen only offers the pin override when multiple supported brokerages are linked (or to recover an unavailable saved pin). The store normalizes stale saved selections after loading or removing brokerage accounts. If auto-trading is enabled in Live mode, switching the active brokerage from the account picker or brokerage profile requires confirmation. Switching does not place an order immediately, but future eligible cycles may use the newly selected account; Paper mode and disabled auto-trading do not prompt.

In Paper mode, the configured quote-source account supplies market data only. Simulated cash, positions, and fills stay in the user's separate Paper account, which is not partitioned by brokerage. Paper orders do not execute at the brokerage.

## Execution Modes and Lifecycle Guarantees

User-specific strategy cycles and brokerage orders run on-device in the foreground or through an OS-managed background worker. Brokerage credentials remain in platform-secure local storage; there is no server-side strategy executor or server-side use of brokerage tokens. Existing server jobs generate shared signals and evaluate resting paper stock orders, but do not execute a user's agentic strategy.

| App or network state | iOS | Android | Behavior |
| --- | --- | --- | --- |
| App open and connected | Supported | Supported | The foreground timer attempts cycles at the configured interval (5 minutes by default). |
| App backgrounded or suspended | Best effort | Best effort | Workmanager requests periodic checks about every 15 minutes. Android's periodic-work minimum is 15 minutes; iOS schedules opportunistically and may delay or skip work. Neither platform guarantees exact cadence or an EOD run. |
| App force-quit | Not supported | Not supported | The operating system may stop background execution until the app is opened again. |
| Offline or fresh quote unavailable | Skipped | Skipped | Background BUYs fail closed unless the selected Robinhood or Schwab quote has a valid timestamp and is no more than 5 minutes old. There is no delayed-data or stored-price fallback for background orders. |
| App restarted | Best effort | Best effort | Scheduling is restored for a signed-in user with auto-trading enabled. The worker reports missing account or quote-source prerequisites; missed entry cycles are not replayed. |

Scheduling follows the signed-in user's auto-trading toggle, independently of quote-source readiness. Keeping the task registered lets later OS-granted runs recheck recoverable prerequisites; it does not bypass them or guarantee execution. The app reconciles the desired periodic task when it resumes because a background worker runs in a separate engine and may cancel the OS task after finding missing auth or disabled configuration. The worker loads the saved source account for quotes and fails closed if it is unavailable. Paper orders go through the simulated ledger and never reach the broker. Background execution uses network, market-data, and AI services on the device. Provider costs and rate limits must be monitored; execution is not guaranteed. Brokerage credentials are never sent to a server.

On iOS, `AppDelegate` pre-registers the Workmanager periodic task identifier with `BGTaskScheduler` before Dart submits the first request. The identifier must match `BGTaskSchedulerPermittedIdentifiers` in `ios/Runner/Info.plist` and `AgenticTradingBackgroundService.taskName`; registering only previously scheduled handlers is insufficient on a fresh install.

### Native Background Readiness & Remediation

To help users diagnose OS throttling before a trading session starts, RealizeAlpha exposes a `com.realizealpha.background_execution` `MethodChannel` queried by `AgenticTradingBackgroundService.inspectPlatformReadiness()` and parsed into `BackgroundExecutionReadiness`:

- **iOS (`ios/Runner/AppDelegate.swift`):** Verifies `BGTaskSchedulerPermittedIdentifiers` registration for `com.cidevelop.robinhoodOptionsMobile.agenticTrading`, `UIBackgroundModes` (`fetch`), `UIApplication.shared.backgroundRefreshStatus` (`available` vs. `denied` / `restricted`), and `ProcessInfo.processInfo.isLowPowerModeEnabled`.
- **Android (`android/app/src/main/kotlin/com/cidevelop/robinhood_options_mobile/MainActivity.kt`):** Inspects `PowerManager.isIgnoringBatteryOptimizations`, `PowerManager.isPowerSaveMode`, `ActivityManager.isBackgroundRestricted`, and `Build.MANUFACTURER` / `Build.MODEL` to produce OEM-specific remediation hints for **Samsung One UI**, **Xiaomi / MIUI / HyperOS**, **OnePlus / OPPO / Realme**, **Huawei / Honor**, and **Google Pixel**.
- **In-App Background Activity Panel (`AgenticTradingSettingsWidget`):** Expanding **Background activity** under Execution Settings displays the live readiness card (`background-platform-readiness-card`), OS warnings, OEM battery guidance, the recent background run journal, and a 1-tap **Configure Background Settings** button (`openPlatformBackgroundSettings()`) that deep-links directly into iOS App Settings or Android Battery Optimization Settings (with fallback to App Details).
- **Safe Fallback:** Unsupported platforms, web builds, and test environments without a bound native channel fall back cleanly to `BackgroundExecutionReadiness.unsupported(...)` so headless workers and widget tests never throw `MissingPluginException`.

### Scheduling Scope and Market Data

The background worker is one periodic task per app installation, not one scheduled job per user position. Each run loads the selected account's state and evaluates the user's strategy locally. The existing `agenticTrading15mCronJob` scans shared chart documents to generate signals; it does not load user portfolios or submit user orders. EOD status is recorded per user, tracked automated trade, and Eastern session date.

Background BUY validation refreshes a quote from the configured Robinhood or Schwab source and accepts only a positive, finite executable price with a timestamp no older than 5 minutes. It prefers the ask and falls back to a valid last-trade or extended-hours price. TP/SL monitoring also refreshes quotes, prefers the bid for exits, and skips stale, missing, or non-finite prices. If either check fails, the order is skipped. Signal-generation providers and fallback data are not substitutes for a background execution quote. For Paper auto-trading, the configured source supplies quotes while the Paper ledger simulates fills. Brokerage API cost, rate-limit headroom, and background reliability need production monitoring; no exact daily lookup allowance is assumed here.

### Market-Close Exit Limitations

Market-close exits can be evaluated by a foreground cycle or a background check that runs during the configured pre-close window. Background scheduling is best effort, so an exit can still be missed and the position may remain open overnight. After the market closes, the next eligible worker checks current positions without requesting quotes or submitting orders and reconciles overdue status. Each tracked trade/session records one of these states:

When Market Close Exit is enabled, new automated entries are blocked once its configured pre-close window begins and during after-hours trading. This is checked again immediately before order submission, including pending BUY approvals, while SELL exits remain available. A proposal that reaches the cutoff before submission is rejected without consuming its signal, so it remains eligible for a later cycle. The cycle can still proceed to monitor and submit exits for existing positions. With Market Close Exit disabled, existing overnight-entry behavior is unchanged.

- **Attempted:** The app claimed the session's exit record before submitting the order. The claim prevents a duplicate cycle from submitting the same EOD exit twice. A rejected or unconfirmed submission remains attempted until reconciliation.
- **Completed:** The brokerage accepted the order request. This confirms submission, not a fill or a closed position.
- **Missed:** No accepted submission was recorded after the market-close window while the tracked position remains open. The next eligible foreground or background reconciliation records the status; if enabled, it requests a missed-exit push. A force-quit or paused worker can delay reconciliation. Inspect the position and manage it manually.

The session date uses Eastern Time and handles DST, standard NYSE holidays, and recurring 1:00 p.m. early closes on July 3, Christmas Eve, and the day after Thanksgiving. Unscheduled exchange closures are not represented and require manual verification. Status records are stored per user, tracked trade, and session date. Missed exits are not retried after the market closes. The emergency stop is stored on the user document and checked before each order submission; if its state cannot be loaded or the user-document reference is unavailable, the auto-trade cycle fails closed. A request already submitted to a brokerage cannot be recalled by activating the stop.

## Cycle Diagnostics

Foreground and Workmanager cycles keep separate bounded journals (up to 40 records per trigger) in device preferences; the settings activity panel displays the latest eight background events. Background records include task entry, auth restoration, loaded brokerage source types, cycle outcome, and whether a terminal diagnostic was uploaded. They contain no account names, user IDs, credentials, symbols, prices, or quantities. Sanitized terminal summaries can also be sent through the authenticated `logAgenticTradingCycle` callable; the server validates phase, trigger, reason, execution mode, quote source, and bounded counters before writing a structured Cloud Logging entry. Repeated background reasons are coalesced to at most one upload per hour; a changed reason uploads immediately. Cloud events include the authenticated user ID and per-cycle ID, but never symbols, prices, quantities, portfolio data, brokerage credentials, or raw exception messages.

Background start events are recorded locally before Firebase initialization; foreground `started` events remain best-effort. The local journal records the start and completion of the user-document read and stores a sanitized platform exception code without its message. Terminal events distinguish blocked, failed, and completed cycles; `lease_held`, `lease_claim_failed`, and `missing_user_document` distinguish cycle overlap from a Firestore lease error or missing execution context. A cycle that cannot start because it is already running or cannot claim the shared lease records `cycle_not_started` and returns a retryable task result. Once the cycle owns the lease, the task is not reported retryable because a brokerage submission may have an unknown outcome. `signal_fetch_failed` identifies a failed Firestore signal query separately from a successful query with no signals. Diagnostic delivery is best-effort and must not be used as an execution or order-state source of truth.

## Architecture

### Components

1. **AgenticTradingConfig** (`lib/model/agentic_trading_config.dart`)
   - User configuration model
   - Stores all trading parameters and risk controls
   - Persisted in Firestore User documents

2. **AgenticTradingProvider** (`lib/model/agentic_trading_provider.dart`)
   - Core state management and trading execution logic.
   - **Agentic Reasoning Orchestrator:** Manages the multi-step reasoning flow, integrating technical indicators, macro regime, and institutional GEX data.
   - Implements `ChangeNotifier` for reactive UI updates.
   - Manages trade execution, TP/SL monitoring, and safety checks.
   - Handles automated buy trades tracking and Firebase persistence.
   - Loads auto-trade history from Firestore ensuring persistence across app restarts.
   - Mirrors backend decision and rejection messages into a bounded activity log while suppressing duplicate messages received within a short interval.
   - **Systematic Mode Rule Enforcement:** Strict BUY signal validation rejecting non-BUY signals during systematic symbol evaluations (`Signal is <type>, not BUY`), comprehensive custom indicator validation under `requireAllIndicatorsGreen`, and calibrated default 50% minimum signal strength.

3. **TradeSignalsProvider** (`lib/model/trade_signals_provider.dart`) *[NEW]*
   - Centralized trade signal management
   - Fetches signals from Firestore with real-time listeners
   - Provides indicator documentation for all 19 indicators (Price Movement, RSI, Market Direction, Volume, MACD, Bollinger Bands, Stochastic, ATR, OBV, VWAP, ADX, Williams %R, Ichimoku Cloud, CCI, Parabolic SAR, ROC, Chaikin Money Flow, Fibonacci Retracements, Pivot Points)
   - Used across InstrumentWidget, SearchWidget for consistent signal display
   - **Signal Date Metadata:** Signals are enriched with a `date` field for enhanced sorting in Firestore and historical tracking.
   - Separates signal management from execution logic

4. **FuturesAutoTradingProvider** (`lib/model/futures_auto_trading_provider.dart`) *[NEW]*
  - Futures-specific auto-trading state, timers, and activity logging
  - Handles emergency stop, countdown timers, and history tracking
  - Powers `FuturesTradingSettingsWidget` and `FuturesTradingPerformanceWidget`

5. **MarketHours Utility** (`lib/utils/market_hours.dart`) *[NEW]*
   - Reusable DST-aware market hours checking
   - Handles Eastern Time conversion (EDT/EST)
   - Comprehensive debug logging for troubleshooting
   - Used by providers and widgets for consistent market status

6. **AgenticTradingSettingsWidget** (`lib/widgets/agentic_trading_settings_widget.dart`)
   - User interface for configuration
   - Real-time status monitoring with countdown timer, market analysis status, and emergency stop indicators
   - Auto-save functionality (no manual save button)
   - **Manual Execution:** Use the "Run Now" button to immediately trigger a market analysis and trade execution cycle.
   - **Emergency Stop:** Use the "Emergency Stop" button to immediately stop all automated trading activities. You can also **long-press the auto-trade status badge** in the app bar to quickly toggle the emergency stop.
   - **Entry Readiness Setup UI:** Warning card displayed when Systematic mode is active without any enabled indicators, notifying users that signals cannot qualify. Offers a 1-tap "Apply balanced setup" action activating core indicators (`priceMovement`, `marketDirection`, `macd`) and a 50% minimum signal strength while keeping auto-trading disabled.
   - Integration with both AgenticTradingProvider and TradeSignalsProvider
   - **Paper Trading:** Expanded paper trading functionality allows validatation of strategies across various widgets without risking real capital. Supports TP/SL monitoring in paper mode.

7. **Backend Functions** (`functions/src/`)
   - `riskguardTask`: Advanced risk assessment and validation engine (powers both Agentic and [Manual Trading](risk-guard.md) protection)
   - `RiskGuardAgent`: Implements sector limits, correlation checks, and volatility filters
   - `MacroAssessment`: Integrates broader market conditions into trading logic for enhanced decision making
   - Trade signal generation cron jobs (daily, hourly, 15-min)
   - `seedAgenticTrading` function: Initializes monitored stocks (supports batch processing)
   - `stock-list.ts`: Source of S&P 500 symbols
  - `agentic-proposal-message.ts`: Produces consistent HOLD and RiskGuard rejection messages for agent proposals.
  - `json-sanitizer.ts`: Recursively replaces non-finite numbers with `null` before macro data is written to Firestore or returned to clients.

8. **TradeSignalsWidget** (`lib/widgets/trade_signals_widget.dart`) *[NEW]*
   - Dedicated home screen widget for trade signals
   - Provides a streamlined view of active auto-trading signals
   - Supports filtering by signal source (Strategy vs. Indicator)
   - Direct navigation to instrument details

9. **Search & Discovery Widgets** (`lib/widgets/search_widget.dart`, `screener_widget.dart`, `presets_widget.dart`) *[NEW]*
   - **SearchWidget**: Main entry point for trade signal discovery. Features advanced filtering for signal strength and individual indicators.
   - **ScreenerWidget**: Dedicated stock screener interface for fundamental analysis (Market Cap, P/E, Dividend, etc.).
   - **PresetsWidget**: Quick access to pre-defined Yahoo Finance screeners (e.g., "Undervalued Growth", "Day Gainers").

## Agentic Reasoning Mode

RealizeAlpha v0.37.0 introduces **Agentic Reasoning Mode**, a sophisticated operational state for the AI Alpha Agent that mimics professional institutional analysis.

### How it Works
When Reasoning Mode is enabled, the agent does not immediately generate a BUY or SELL signal. Instead, it follows a structured sequence:
1. **Regime Identification:** Analyzes broad market conditions (VIX, Trend, Breadth) to set the context.
2. **GEX Analysis:** Evaluates dealer positioning, Call/Put walls, and potential Gamma Squeeze thresholds.
3. **Indicator Synthesis:** Cross-correlates the 19 technical indicators to find high-probability convergence.
4. **Step-by-Step Reasoning:** Generates a textual "train of thought" that explains the logic behind the final decision.

### GEX Orchestrator
The reasoning engine is powered by a **GEX Orchestrator** on the backend. This component adjusts signal confidence based on Gamma levels:
- **Positive GEX (Pinning):** Tightens SL/TP levels to account for lower volatility.
- **Negative GEX (Acceleration):** Widens buffers to capture explosive moves while increasing risk monitoring.

### Configuration
Users can enable Reasoning Mode globally or per-account in the **Agentic Trading Settings**. Note that reasoning mode may increase the time required for a market analysis cycle due to the depth of the LLM processing.

### Macro `RISK_OFF` Policy & Strategy Alignment
Risk Management exposes a unified 3-option **Macro `RISK_OFF` Policy** (`MacroRiskOffPolicy`: `ignore`, `reduceSize`, `blockEntries`) stored on `TradeStrategyConfig` alongside backwards-compatible `reduceSizeOnRiskOff` (`policy == reduceSize`):

- **Ignore (`ignore`)**: Evaluates BUY entries normally during `RISK_OFF` regimes (default).
- **Reduce Size (`reduceSize`)**: Scales down BUY position size by `riskOffSizeReduction` (clamping positive orders to at least 1 share unless reduction is `100%`) consistently across both Deterministic (`systematic`) and Probabilistic (`reasoning`) pipelines. In Reasoning mode, the prompt explicitly tells Gemini that downstream sizing handles `RISK_OFF` risk so macro caution is not treated as an automatic BUY veto.
- **Block Entries (`blockEntries`)**: Deterministically blocks new `BUY` entries during `RISK_OFF` (skipping the LLM call in Reasoning mode when flat) while keeping `SELL` exits active.

When `gammaExposure` is disabled or GEX cache is unavailable, Reasoning mode evaluates technical price action and user-enabled indicators directly rather than gating on the 11-rule GEX options rubric.

On the client, Reasoning mode ranks candidate signals across the user's enabled indicators before applying the 15-proposal per-cycle cap; signals beyond the top 15 are marked `Deferred` instead of consumed for 24 hours, and `autoTrade` validates the fresh `proposal['price']` against the 3% live-quote BUY guard.

## Stock Universe & Seeding

The system monitoring is driven by a seeded list of documents in the `charts` collection.

### Seeding the Database
To initialize or expand the list of monitored stocks, use the `seedAgenticTrading` Firebase Cloud Function.

**Usage:**
Call the function with a JSON body to seed the `charts` collection.

**Options:**
- **Default (Popular Only):**
  ```json
  {}
  ```
  Seeds only the default popular symbols (Indices + High Volume: SPY, QQQ, NVDA, TSLA, AAPL, etc.).

- **Full S&P 500:**
  ```json
  {
    "full": true
  }
  ```
  Seeds the full S&P 500 list plus popular symbols (approx. 500+ stocks).
  *Note: The function processes writes in batches of 50 to respect Firestore limits.*

- **Custom List:**
  ```json
  {
    "symbols": ["AAPL", "MSFT", "GOOGL"]
  }
  ```
  Seeds only the specified symbols.

### Scheduled Signal Data Policy

Daily, hourly, and 15-minute bulk jobs set `marketDataCacheOnly` and `gexCacheOnly` when calling `performTradeProposal`. This policy keeps a full-universe run bounded and prevents hundreds of concurrent fallback requests when an upstream provider is unavailable or rate limited.

- Fresh cache entries are used normally (daily cache staleness checks Eastern Time market hours and the latest bar's UTC date against `America/New_York` trading sessions, with a 15-minute refetch cooldown and a post-close refresh after 16:00 ET; Twelve Data and Fidelity responses preserve the latest bar timestamp in `meta.currentTradingPeriod.regular.end`).
- Cached and provider bars are normalized together by source index; incomplete timestamp/OHLC rows are dropped as a whole, and missing volume is zero-filled to preserve alignment.
- Stale OHLCV cache entries are accepted and surfaced through `diagnostics.usedStaleCache` and the user-facing stale-data warning.
- Missing/empty cached bars fail that symbol's calculation without replacing its previous signal.
- Cached GEX is used when available; bulk jobs do not initiate live options-chain fetches.
- The latest persisted macro assessment and shared market-index data are reused across adjacent calculations.
- Cron summaries count returned calculation failures in `errorCount` instead of reporting them as processed.
- Cache-only GEX returns `null` when neither fresh matching exposure nor usable cached options data is available; it does not fall back to expired GEX.
- The authenticated `initiateTradeProposal` callable forces cache-only GEX, even if a client requests live GEX. It may still use live market data unless `marketDataCacheOnly` is set. The separate GEX research callable retains its live options fallback.
- Intraday schedules run hourly at :40 and 15-minute at :00, :15, :30, and :50. The :45 evaluation is delayed five minutes; scheduled starts are at least 10 minutes apart, with a nine-minute function timeout.
- `fetchWithRetry` redacts credential-like query parameters from URLs in retry logs and omits raw network error messages.

Other explicitly requested calculations retain normal provider fallback behavior unless their cache-only flags are supplied.

## Features

### Trade Signals Widget

The dedicated **Trade Signals Widget** offers a focused view of all active trading signals generated by the system.

- **Unified View**: See all BUY/SELL signals in one place.
- **Source Filtering**: Toggle between signals generated by **Strategies** or individual **Indicators**.
- **Real-Time Updates**: Signals update automatically as market conditions change.
- **Quick Navigation**: Tap any signal to jump to the instrument details for in-depth analysis.
- **Sparkline Context**: Each signal card can display a mini trend line derived from recent price data.
- **Weighted Strength**: Badges reflect weighted signal strength scores consistent with backend scoring.

### Trade Signal Discovery

The Search tab provides powerful tools to discover and filter trade signals generated by the Agentic Trading system.

**Filtering Capabilities:**
- **Signal Strength Filtering:** Filter signals by overall strength category:
  - **Strong (70-100):** High-confidence setups with multiple confirming indicators.
  - **Moderate (50-69):** Good setups with solid support but fewer confirmations.
  - **Weak (0-49):** Low-confidence or conflicting signals (often used for contrarian analysis).
- **Strategy Template Filtering:** Filter signals to only show those that align with specific pre-defined strategies (e.g., "Momentum Master", "Mean Reversion").
  - This allows you to focus on signals that match your preferred trading style.
- **Indicator-Specific Filtering:** Granular control over all 19 indicators. Each indicator chip supports a 4-way toggle:
  - **Off:** No filter applied.
  - **BUY:** Show only signals where this indicator is bullish.
  - **SELL:** Show only signals where this indicator is bearish.
  - **HOLD:** Show only signals where this indicator is neutral.

**Exclusive Filtering Logic:**
To prevent conflicting queries, the system enforces exclusivity between high-level strength filters and granular indicator filters:
- Selecting a **Signal Strength** category (e.g., "Strong") automatically clears any active indicator filters.
- Activating an **Indicator Filter** (e.g., "RSI: BUY") automatically clears the Signal Strength selection.

**Performance Optimization:**
- **Server-Side Filtering:** All filtering logic (strength ranges, indicator states, date ranges) is executed on Firestore to minimize data transfer and client-side processing.
- **Efficient Indexing:** Custom composite indexes support complex queries like "Show me all signals where RSI is BUY and MACD is BUY, sorted by time."

### Signal Processing & Deduplication

To ensure reliability and prevent duplicate trades, the system implements robust signal processing logic:

- **Local Persistence:** The IDs of processed signals are saved locally to the device. This ensures that even if the app is restarted, the system remembers which signals have already been acted upon (or rejected) for the current day.
- **Proposal Retry:** Transient trade-proposal callable failures are marked `Retry`, not consumed. Their persisted Firestore signals remain eligible for the next cycle when the app receives execution time. Permanent callable failures are marked rejected; proposal generation retries never blindly repeat a brokerage order.
- **Server-Side Safety:** Routine auto-trading checks use `skipSignalUpdate` so checking an opportunity does not regenerate its signal. Scheduled calculation runs update calculation freshness even when the recommendation is unchanged.
- **Order Submission Claims:** Signal claims are persisted per user to prevent duplicate submissions across cycles. A submission with an ambiguous result is not automatically retried because the brokerage may have accepted it; inspect brokerage orders before relying on a later refreshed signal.
- **Detailed Inspection:** You can view the history of processed signals in the **Agentic Trading Settings**. Tapping on any processed signal reveals a detailed dialog showing:
  - The full AI reasoning for the decision.
  - Specific rejection reasons (if applicable).
  - Timestamp of processing.

### Signal Calculation Diagnostics

Instrument signal details expose backend calculation metadata for a recommendation: last attempt, last successful calculation, signal-change time, market-data timestamp, stale-cache use, data source, status, interval, and bars evaluated. Warnings distinguish stale or failed calculations from a current successful result without replacing the persisted recommendation.

On a successful unchanged calculation, the backend refreshes the top-level `timestamp`, `date`, `currentPrice`, and `diagnostics.lastSuccessfulCalculationAt`. It preserves `diagnostics.signalChangedAt`, which is the authoritative time at which the recommendation content last changed. Notification triggers compare signal values, so this diagnostic-only freshness update does not create a new actionable-signal notification.

### Paper Trading Mode

New configurations default to Paper execution. Existing saved configurations keep their stored execution mode.

The system includes a fully functional **Paper Trading Mode** for risk-free strategy testing and validation.

**Paper Quote Source:** The default **Automatic** setting prefers the active Robinhood or Schwab account and falls back to the first linked supported account when the active account cannot supply quotes. If multiple supported brokerages are linked, users can optionally pin Paper quotes to Robinhood or Schwab; pinning does not switch the active account. Live execution remains tied to the active account. The setting is saved in `AgenticTradingConfig.paperQuoteSource`; older configurations keep their saved source, and missing values use Automatic.

**Paper TP/SL Exits:** Exit monitoring reads simulated positions from `PaperTradingStore` and routes triggered exits through the Paper execution path. If an exit is triggered while the market is closed, the simulated sell is retained as a pending Paper order rather than recorded as an immediate fill. A later eligible cycle evaluates pending Paper orders and reconciles completed exits into automated trade history and staged-exit tracking. Paper mode intentionally has no selected Live account, so exit monitoring requires the Paper ledger and configured quote source but not a brokerage account object. Live exit monitoring continues to require the selected account; Paper exits never reach the brokerage.

**Key Features:**
- **Risk-Free Simulation:** Execute trades without using real capital or making broker API calls.
- **Realistic Execution:** Simulates realistic order responses, including fills and status updates.
- **Identical Analytics:** Paper trades are tracked with the same precision as real trades, allowing for direct performance comparison.
- **Visual Indicators:** "PAPER" badges appear on trade cards and in analytics to clearly distinguish simulated trades.
- **Separate Tracking:** Paper trades are stored with a `paperMode: true` flag, allowing them to be filtered separately in the analytics dashboard.
- **Strategy Validation:** Perfect for testing new indicator combinations or risk parameters before going live.

**How to Enable:**
1. Go to **Agentic Trading Settings**.
2. Toggle **Paper Trading Mode** to ON.
3. Configure your trading parameters as usual.
4. Enable **Auto-Trade**.

*Note: When Paper Trading is enabled, NO real orders will be sent to your brokerage.*

### Trading Strategy Management

> **Updated in v0.62.0**

The system provides centralized management for trading strategies, allowing users to switch between different trading styles and risk profiles instantly.

#### Curated Strategy Archetypes (Walk-Forward Badges)

To eliminate the friction of configuring 35+ granular parameters (indicator weights, sequential stops, risk limits, and position sizing), RealizeAlpha introduces **4 Curated Strategy Archetypes** directly in the Agentic Trading settings. Each archetype is backed by empirical 1-year out-of-sample walk-forward backtest metrics:

1. **Conservative Core** (`archetype_conservative_core`):
   - **Tag & Philosophy:** *Capital Preservation*. High-probability trend-following with tight structural risk bounds, strict 20% sector exposure caps, and defined GEX stops.
   - **Trading Mode:** Systematic (`TradingMode.systematic`).
   - **Target Market Regime:** Low Volatility Bull / Neutral.
   - **Key Indicators:** Market Direction (SMA 50/200), Bollinger Bands, RSI momentum, Volume confirmation, Floor Pivot Points, and ATR sizing.
   - **Risk & Stops:** 1.0% risk per trade, 20% max portfolio concentration, 8% max drawdown limit, +6% take profit, -3% stop loss, 2% trailing stop, 15% trailing peak stop, GEX structural stop, and 20% catastrophic stop.
   - **Walk-Forward Performance Badges:**
     - 🟢 **Win Rate:** 68.5%
     - 🔵 **Profit Factor:** 1.88
     - 🟠 **Max Drawdown:** 5.4%
     - 🟣 **Sharpe Ratio:** 1.72 (24.5% 1-Yr Return, 52 sample trades)

2. **Momentum Breakout** (`archetype_momentum_breakout`):
   - **Tag & Philosophy:** *Directional Expansion*. Aggressive trend capture on volume expansion, MACD histogram crossovers, and VWAP trend confirmation with dynamic ATR trailing stops.
   - **Trading Mode:** Systematic (`TradingMode.systematic`).
   - **Target Market Regime:** High Volatility Expansion / Bull.
   - **Key Indicators:** Price Action patterns, Momentum (RSI), MACD, Volume, ADX trend strength (> 25), VWAP anchor, Chaikin Money Flow, and ATR.
   - **Risk & Stops:** 2.0% risk per trade, 30% max portfolio concentration, 15% max drawdown limit, +12% take profit, -4.5% stop loss, 3.5% trailing stop, 20% trailing peak stop, and 25% catastrophic stop.
   - **Walk-Forward Performance Badges:**
     - 🟢 **Win Rate:** 57.8%
     - 🔵 **Profit Factor:** 2.14
     - 🟠 **Max Drawdown:** 10.8%
     - 🟣 **Sharpe Ratio:** 1.58 (42.1% 1-Yr Return, 86 sample trades)

3. **Options Income Harvester** (`archetype_options_income_harvester`):
   - **Tag & Philosophy:** *High-Yield Premium*. Systematic premium selling and range-bound mean reversion exploiting dealer gamma pinning, Stochastic oscillators, and 5-tier GEX sequential stops.
   - **Trading Mode:** Systematic (`TradingMode.systematic`).
   - **Target Market Regime:** Range-Bound / Low-to-Moderate Volatility.
   - **Key Indicators:** Gamma Exposure (GEX pinning & flip level), Bollinger Bands, Stochastic, RSI, Williams %R, Pivot Points, and ATR buffer.
   - **Risk & Stops:** 1.5% risk per trade, 25% max portfolio concentration, 12% max drawdown limit, +15% take profit, -18% stop loss, 4% trailing stop, GEX structural stop, Time-Theta stop (min 14 DTE, 5 stalled sessions limit), and 35% catastrophic stop.
   - **Walk-Forward Performance Badges:**
     - 🟢 **Win Rate:** 76.2%
     - 🔵 **Profit Factor:** 1.95
     - 🟠 **Max Drawdown:** 7.2%
     - 🟣 **Sharpe Ratio:** 1.84 (31.8% 1-Yr Return, 64 sample trades)

4. **Reasoning AI Agent** (`archetype_reasoning_ai_agent`):
   - **Tag & Philosophy:** *Autonomous Gemini AI*. Multimodal Gemini AI reasoning synthesizing technical convergence across all 19 indicators, macro regime context, and chain-of-thought verification.
   - **Trading Mode:** Reasoning (`TradingMode.reasoning`).
   - **Target Market Regime:** All Regimes / Adaptive.
   - **Key Indicators:** All 19 technical indicators enabled with analytical reasonings + GEX + Macro regime filter (min signal strength 75.0%).
   - **Risk & Stops:** 2.0% risk per trade, dynamic position sizing, 25% max portfolio concentration, 10% max drawdown limit, +10% take profit, -5% stop loss, 3% trailing stop, 20% trailing peak stop, Macro regime defensive stop, and 30% catastrophic stop.
   - **Walk-Forward Performance Badges:**
     - 🟢 **Win Rate:** 64.6%
     - 🔵 **Profit Factor:** 1.82
     - 🟠 **Max Drawdown:** 8.6%
     - 🟣 **Sharpe Ratio:** 1.65 (28.4% 1-Yr Return, 58 sample trades)

#### Strategy Application & Preset Cloning

- **Apply Archetype:** Selecting an archetype opens the detail sheet dialog showing complete strategy philosophy, walk-forward validation matrix, and risk parameter breakdown. Tapping "Apply Archetype" confirms changes and immediately updates the active `AgenticTradingConfig` (including setting the corresponding `TradingMode`), syncing to Firestore without requiring manual entry of 35+ parameters.
- **Clone to Custom Preset:** Tapping "Clone Preset" generates an editable user template (`TradeStrategyTemplate`) saved in the user's custom template library (`BacktestingProvider.saveTemplate`), allowing unrestricted customization and multi-timeframe backtesting.

**Strategies Page:**
- **Access:** Navigate to the new "Trading Strategies" page from the Agentic Trading Settings.
- **Library:** Browse a collection of pre-defined strategies (e.g., "Momentum Master", "Mean Reversion", "Conservative Income").
- **Search:** Quickly find strategies by name or description.
- **Activation:** Tap "Use Template" to instantly apply the strategy's configuration (indicators, intervals, risk settings) to your active trading agent.

**Entry Strategies:**
- **Visual Configuration:** New dedicated UI for configuring entry conditions.
- **Pattern Recognition:** Toggle specific chart patterns and entry triggers directly.
- **Integration:** Seamlessly integrated with the main configuration flow.

**Default Strategies:**
The system comes with a library of professionally designed templates to get you started:

1.  **Momentum Master** (Trend): Captures strong price moves by combining RSI and CCI momentum with MACD confirmation and Volume validation.
2.  **Mean Reversion** (Reversal): Identifies overbought/oversold reversals using Bollinger Bands, CCI, and RSI extremes.
3.  **Trend Follower** (Swing): Rides established trends using Moving Averages, Ichimoku Cloud, ADX trend strength, and OBV flow.
4.  **Volatility Breakout (1h)** (Intraday): Exploits explosive moves from squeeze conditions using Bollinger Bands, CCI, ATR, and VWAP.
5.  **Intraday Scalper (15m)** (Scalping): Short-term scalping via CCI/Stochastic with strict risk management (partial exits, tight stops).
6.  **GEX Mean Reversion** (Regime): Exploits "Pinning" regimes when dealer gamma is positive, using Bollinger Bands and Stochastic for entry in a low-volatility environment.
7.  **GEX Trend Accelerator** (Momentum): Rides high-volatility "Trend" regimes when GEX is negative, using MACD and ADX to confirm directional acceleration.
8.  **GEX Intraday Scalp** (15m): Rapid scalping leveraging GEX magnitude and VWAP value levels for quick intraday turns.
6.  **Custom EMA Trend** (Custom): Automatically engages when Price crosses above the 21-period EMA.
7.  **Crypto Proxy Momentum** (Crypto): High-volatility momentum strategy (CCI, RSI) designed for crypto-correlated stocks.
8.  **Golden Cross & RSI Filter** (Classic): Classic 50/200 SMA Cross combined with RSI < 70 to avoid buying tops.
9.  **Range Bound Income** (Income): Ideal for sideways markets. Profitable when Price Movement and CCI Impulse are low.
10. **Strict Confluence** (Conservative): High conviction entries requiring ALL enabled indicators (Momentum, Moving Avg, MACD) to agree.
11. **Risk-Managed Growth** (Position Sizing): Uses dynamic position sizing to risk exactly 1% of account equity per trade.
12. **MACD Histogram Reversal** (Reversal): Trades when MACD histogram flips positive while RSI is oversold (< 40).
13. **Bollinger Band Squeeze** (Breakout): Breakout strategy. Low volatility period (ATR) followed by price piercing Upper Band.
14. **VWAP Pullback Entry** (Intraday): Intraday trend is UP (Price > SMA), but entry is a pullback to VWAP.
15. **0DTE Scalper (5m)** (High Frequency): SPY 5m chart, riding rapid momentum (CCI/RSI) bursts with tight risk.
16. **Tech Sector Swing** (Sector): Trend following on XLK (Tech Sector). Captures multi-day moves.
17. **Defensive Value** (Low Beta): Low-beta strategy on SCHD. Buys dips (RSI < 30) in uptrends with CCI oversold confirmation.
18. **Ichimoku Cloud Breakout** (Trend): Trend-following strategy utilizing the Ichimoku Cloud for support/resistance.
19. **Triple Screen Simulation** (System): Simulates Elder's Triple Screen: Trend (MACD/SMA) + Oscillator (Stochastic/Williams) + Breakout.
20. **Opening Range Breakout** (Morning): Exploits early market volatility (9:30-10:30 AM). Uses VWAP as anchor.
21. **Turtle Trend Follower** (Long Term): Long-term breakout strategy inspired by Turtle Traders. Buys new highs.
22. **RSI Fade** (Contrarian): Fades overextended moves. Sells when RSI > 75 and price hits upper Bollinger Band.

### Automatic Execution

The system automatically executes trades when auto-trading is enabled:

**Timer-Based Execution:**
- Periodic checks every 5 minutes
- Automatically starts when app loads with user data
- Runs continuously while app is active
- Checks `autoTradeEnabled` configuration flag
- Only executes during market hours (validated via MarketHours utility)
- Real-time countdown timer displayed in settings UI

**Execution Cycle:**
1. Timer triggers every 5 minutes
2. Checks if auto-trading is enabled in config
3. Validates market hours using MarketHours.isMarketOpen()
4. Validates required data (user, account, portfolio)
5. Builds current portfolio state
6. Calls `autoTrade()` with all parameters
7. Calls `monitorTakeProfitStopLoss()` for automated trades
8. Updates countdown timer for next cycle
9. Logs execution results

**Location:** `AgenticTradingProvider` (`lib/model/agentic_trading_provider.dart`) - Centralized provider managing trading state and execution logic.

**UI Integration:**
- Settings widget shows real-time countdown to next check
- App bar displays auto-trade status badge when active
- Status updates propagate via ChangeNotifier pattern

### Auto-Trade Logic

The `autoTrade()` method orchestrates automatic trade execution:

```dart
Future<Map<String, dynamic>> autoTrade({
  required Map<String, dynamic> portfolioState,
}) async
```

**Process Flow:**
1. **Pre-flight Checks** (`_canAutoTrade()`)
   - Verify auto-trade is enabled
   - Check emergency stop status
   - Validate market hours
   - Enforce daily trade limit
   - Verify cooldown period has elapsed
   - Check daily loss limit

2. **Signal Processing**
   - Fetch current trade signals from Firestore
   - Filter for BUY signals
   - Validate signal quality

3. **Trade Execution**
   - Call `initiateTradeProposal()` for each qualified signal
   - Assess risk with `riskguardTask`
   - Track execution history
   - Update counters and timestamps

4. **Post-Trade Actions**
   - Log analytics events
   - Update UI state
   - Enforce rate limiting between trades
   - **Record enabledIndicators snapshot for performance analysis**
   - **Mark trade as real or paper mode**

### Advanced Risk Controls

The system now includes a sophisticated `RiskGuardAgent` that enforces portfolio-level risk management rules before any trade is executed. These controls are configurable in the Agentic Trading Settings.

**Partial Position Exits:**
- **Staged Profit Taking:** Configure multiple exit stages to lock in profits incrementally.
- **Flexible Configuration:** Define profit targets (e.g., +5%, +10%) and the percentage of the position to sell at each stage (e.g., 50%).
- **Example Strategy:** Sell 50% of position at +5% profit, then sell the remaining 50% at +10% profit.
- **Persistence:** Partial exit state is saved to Firestore, ensuring stages are tracked correctly even if the app is restarted.
- **Legacy Support:** Works seamlessly with existing positions (backfills tracking data).

**Stop Loss & Take Profit:**
- **Stop Loss:** Automatically sells position if loss exceeds configured percentage (e.g., -5%).
- **Take Profit:** Automatically sells position if profit exceeds configured percentage (e.g., +10%).
- **Trailing Stop Loss:** Optional dynamic stop loss that follows the price up. If enabled, the stop price is calculated as `Highest Price - Trailing %`. Locks in profits as the stock rises.

**Advanced Risk Controls:**
- **Sector Exposure Limits:** Cap allocation to specific sectors (e.g., max 20% in Technology).
- **Correlation Checks:** Prevent opening new positions that are highly correlated with existing holdings (max correlation coefficient 0.7).
- **Volatility Filters:** Filter trades based on Implied Volatility (IV) rank (min/max thresholds).
- **Drawdown Protection:** Halt trading if portfolio drawdown exceeds a specified percentage.

**Safety Checks:**
- **Daily Trade Limit:** Maximum number of automated trades per day.
- **Cooldown Period:** Minimum time between trades (default 60 mins).
- **Max Daily Loss:** Stops trading if daily loss exceeds threshold.
- **Emergency Stop:** Manual override to immediately halt all auto-trading.
- **Market Hours:** Only trades during regular market hours (9:30 AM - 4:00 PM ET).

**Key Risk Features:**
- **Sector Exposure Limits:** Prevents over-concentration in a single sector.
  - Configurable `maxSectorExposure` (default 20%).
  - Checks current portfolio allocation before approving new trades.
- **Correlation Checks:** Avoids adding positions that are highly correlated with existing holdings.
  - Configurable `maxCorrelation` coefficient (default 0.7).
  - Helps maintain portfolio diversification.
- **Volatility Filters:** Ensures trades are only taken within acceptable volatility ranges.
  - Configurable `minVolatility` and `maxVolatility` (IV Rank).
  - Prevents trading in extremely low or high volatility environments.
- **Drawdown Protection:** Halts trading if the portfolio experiences significant drawdown.
  - Configurable `maxDrawdown` percentage.
  - Acts as a circuit breaker for the entire trading system.

### Custom Indicators

Users can now define their own technical indicators to be used alongside the standard 15-indicator system.

- **Creation:** Define custom logic based on price action, volume, or other available data points.
- **Integration:** Custom indicators are evaluated as part of the signal generation process.
- **Weighting:** Assign specific weights to custom indicators to influence the overall signal strength.
- **Flexibility:** Supports a wide range of mathematical functions and logic operators.

### ML Optimization

Machine Learning models are integrated to continuously optimize trade signals, leveraging Google's **Vertex AI Gemini 3.1 Flash-Lite** model for high-speed, cost-effective analysis.

- **Signal Refinement:** ML algorithms analyze historical performance to adjust indicator weights and thresholds.
- **Accuracy Improvement:** Reduces false positives by learning from past market conditions.
- **Adaptive Logic:** The system adapts to changing market volatility and trends.
- **Continuous Learning:** The models are retrained periodically with new market data to ensure relevance.
- **Cost Efficiency:**
  - **Signal Gating:** Intelligent filtering only invokes AI optimization for high-potential setups (Signal Strength > 25), significantly reducing API costs by skipping analysis of weak signals.
  - **Optimized Prompts:** Utilizes minified and structured prompts to minimize token usage while maintaining analytical depth.
  - **Model Selection:** Uses the `gemini-3.1-flash-lite` model, which offers the lowest inference costs ($0.25 / $1.50 per 1M tokens), high rate limits, and sub-second latency without compromising on structured analysis capabilities.

### Advanced Exit Strategies

In addition to standard Stop Loss and Take Profit, the system supports sophisticated exit strategies:

- **Partial Exits:** Configure multiple exit targets (e.g., sell 50% at +10% profit, sell remaining 50% at +20%). This allows locking in profits while keeping a portion of the position open for potential further gains.
- **Time-Based Exits:** Automatically close positions after a specified duration (e.g., 2 hours) if profit targets haven't been met. This helps free up capital from stagnant trades.
- **Market Close Exits:** A foreground cycle attempts to exit positions a configured number of minutes before the market closes. If the app cannot run a cycle in that window, the exit can be missed and the position may remain open overnight; see [Execution Modes and Lifecycle Guarantees](#execution-modes-and-lifecycle-guarantees).
- **5-Tier Sequential Exit Stop Priority Queue:** Institutional-grade multi-tier exit framework located at the bottom of the **Exit Strategies** view. To keep standard trading intuitive and avoid unexpected early exits in Simplified or classic bracket setups, all 5 tiers default to **off** in custom configurations (curated Strategy Archetypes explicitly configure their own opt-ins). When enabled, tiers evaluate in sequential priority order:
  1. **Tier 1 (GEX Structural Stop):** Closes positions when dealer positioning flips into negative gamma acceleration (`enableGexStructuralStops`).
  2. **Tier 2 (Trailing Peak Stop):** High-water mark trailing stop that locks in profits when price pulls back by a set percentage from peak unrealized gains (`enableTrailingPeakStop`, default 20%).
  3. **Tier 3 (Time & Theta Decay Stop):** Mitigates theta burn and opportunity cost by exiting when contract DTE drops below a threshold (`minDteStopDays`, default 14) or a trade remains stalled across consecutive trading sessions (`stalledSessionsStopLimit`, default 10).
  4. **Tier 4 (Macro Risk-Off Stop):** Exits open risk when market-wide macro assessment shifts to `RISK_OFF` or Defensive (`enableMacroRegimeStop`). Features **transition awareness**: trades intentionally entered during `RISK_OFF` (via `reduceSize` or `ignore` policies) are not immediately liquidated on the next cycle, whereas trades opened during `RISK_ON` that experience a subsequent macro shift into `RISK_OFF` (or any `RISK_OFF` holding under `blockEntries`) exit promptly.
  5. **Tier 5 (Catastrophic Hard Stop):** Non-negotiable max loss circuit breaker per trade preventing catastrophic account drawdowns (`enableCatastrophicStop`, default 50%).
- **Volatility-Adaptive Dynamic ATR Trailing Stops & Profit Ratchet (#347):** Calibrates stop-loss and profit target levels dynamically to the asset's current volatility environment using 14-period Average True Range (ATR):
  - **Dynamic ATR Stop-Loss:** Calculated as $\text{Entry Price} - (\text{ATR} \times \text{atrStopMultiplier})$ (default: $1.5\times$ ATR).
  - **Dynamic ATR Profit Target:** Calculated as $\text{Entry Price} + (\text{ATR} \times \text{atrProfitMultiplier})$ (default: $3.0\times$ ATR), establishing a default $2.0:1$ reward-to-risk ratio.
  - **Dynamic ATR Trailing Stop:** When enabled alongside trailing stops, trails from the position's high-water mark price: $\text{Highest Price} - (\text{ATR} \times \text{atrStopMultiplier})$.
  - **Adaptive Volatility Ratchet:**
    - **Volatility Compression ($\text{NATR} < 1.0\%$):** Automatically widens stop distance by $1.25\times$ to avoid premature shakeouts during tight low-volatility consolidations.
    - **Volatility Expansion ($\text{NATR} > 3.0\%$):** Automatically tightens trailing stops to $0.75\times$ base distance as momentum accelerates, locking in gains.
  - **Diagnostic Visibility:** Surfaced in `AutomatedTradeProposalDetailWidget` with live ATR distance, calculated dollar stop/target levels, volatility regime indicator, and reward-to-risk ratio.

### Order Approval Workflow & Pending Approvals Center

For users who want the benefits of AI signal generation but prefer manual oversight before capital is committed, the system offers an **Order Approval Workflow** backed by a dedicated review interface (`AutomatedTradingApprovalsWidget`).

**How it works:**
1. **Enable Approval:** Toggle `requireApproval` in Agentic Trading Settings.
2. **Signal Generation:** The system evaluates market data, macro regimes, and multi-indicator technical signals to generate proposals.
3. **Pending Queue:** Instead of executing automatically, proposals are persisted to the user's `pending_orders` Firestore subcollection and represented as typed `AutomatedTradeProposal` objects.
4. **Push Notification:** The user receives a high-priority push notification (`agentic_approval`) containing the proposal ID.
5. **Contextual Discovery:**
   - **Home Screen Banner:** A high-visibility amber action banner appears on the `AgenticTradingCardWidget` displaying pending proposal counts and aggregate capital impact.
   - **Status Badge:** The `AutoTradeStatusBadgeWidget` renders an amber `Review` badge state (`$pendingCount PENDING`).
   - **Settings Button:** `AgenticTradingSettingsWidget` features an `Open Full Approvals View` button.
   - **Deep Linking:** Tapping the notification opens `AutomatedTradingApprovalsWidget` and automatically pops the specific proposal's detail inspection sheet.

**Dedicated Approvals Center (`AutomatedTradingApprovalsWidget`):**
- **Dual Tabs:**
  - **Pending:** Real-time view of active proposals awaiting action.
  - **History:** Searchable audit trail of past approvals, executions, and rejections.
- **Summary Metrics Header:** Displays total pending count, aggregate capital commitment (with strict `AccountStore.showBalances` `$••••••` masking), average AI conviction score, active execution mode (Live vs. Paper), and warning banners for Emergency Stop lockouts or Market Close cutoffs.
- **Search & Filtering:** Text search by ticker symbol or strategy name, segmented action chips (`ALL`, `BUY`, `SELL`), qualification filter (`ALL`, `CONFIRMED`, `PENDING WATCH`), and sorting (`Newest First`, `Highest Confidence`, `Largest Capital`, `Symbol A-Z`).
- **Batch Actions (`batchApproveOrders`, `batchRejectOrders`):** Interactive multi-selection mode with checkboxes allowing users to `Select All`, `Approve Selected`, `Reject Selected`, `Approve All`, and `Reject All` with confirmation dialogs.
- **Deep Inspection Sheet (`AutomatedTradeProposalDetailWidget`):**
  - Order parameters: Symbol, Action, Quantity, Execution Type, Limit/Signal Price, Estimated Total Cost.
  - AI Conviction: Confidence score pill, signal provenance breakdown, and generative reasoning thesis.
  - RiskGuard Audit: Volatility filter, sector concentration, correlation limits.
  - GEX Levels & Macro Regime: Positive transition (`pTrans`), negative transition (`nTrans`), gamma flip levels, macro regime status, and direct link to interactive candlestick charts (`InstrumentWidget`).
- **Safety Invariants During Approval:**
  - **Live-Quote BUY Guard:** Approving an order validates the proposal against fresh live quotes; price deviations $> 3\%$ block execution.
  - **Rejection Audit Trail:** Rejections append an entry with `status: 'rejected'` to `autoTradeHistory` and persist to Firestore `auto_trade_history` for compliance.
  - **Paper Mode Isolation:** Paper approvals execute exclusively through the local simulated paper trading store without broker interaction.

### Advanced Performance Analytics

The `AgenticTradingPerformanceWidget` provides comprehensive trading insights across 9 analytics cards:

**1. Performance Overview**
- Total trades executed
- Win/loss counts and success rate
- Average P&L per trade
- Total P&L summary

**2. Profit & Loss**
- Total P&L amount
- Average P&L per trade
- Winning trades total
- Losing trades total
- Breakdown by entry/exit type

**3. Trade Breakdown**
- Entry counts (BUY orders)
- Take Profit exits
- Stop Loss exits
- **Trailing Stop exits**
- Distribution visualization

**4. Best & Worst Trades**
- Best performing trade details
- Worst performing trade details
- P&L amounts
- Entry/exit prices
- Hold duration

**5. Advanced Analytics (4-Metric Grid)**
- **Sharpe Ratio**: Risk-adjusted returns (Good >1, Fair 0-1, Poor <0)
  - Calculates annualized return / volatility
  - Indicates quality of returns per unit of risk
- **Average Hold Time**: Position duration in hours and minutes
  - Tracks from BUY to SELL
  - Helps optimize exit timing strategies
- **Profit Factor**: Gross profit / Gross loss ratio
  - Values > 1 indicate profitable system
  - Higher values show better profitability
- **Expectancy**: Expected profit per trade (in dollars)
  - Formula: (Avg Win × Win Rate) - (Avg Loss × Loss Rate)
  - Critical metric for strategy validation

**6. Risk Metrics**
- **Longest Win Streak**: Best consecutive winning trades
- **Longest Loss Streak**: Worst consecutive losing trades  
- **Max Drawdown**: Peak-to-trough equity decline
  - Helps assess portfolio risk
  - Important for risk management

**7. Performance by Time of Day**
- Morning (9am-12pm): Win rates, trade counts, avg P&L
- Afternoon (12pm-3pm): Win rates, trade counts, avg P&L
- Late Day (3pm-4pm): Win rates, trade counts, avg P&L
- **Color-coded**: Green (≥60%), Orange (40-59%), Red (<40%)
- Helps identify optimal trading windows

**8. Performance by Indicator Combo** *(v1.3)*
- Tracks active indicators at execution time
- Groups trades by unique indicator combination
- Win/loss rate for each combination
- Shows which indicator sets are most effective
- Top 8 combinations displayed
- Abbreviated names: Price, RSI, Market, Volume, MACD, BB, Stoch, ATR, OBV
- Enables strategy optimization

**9. Performance by Symbol**
- Top 10 traded symbols
- Win rate per symbol
- Trade counts
- Total P&L by symbol
- Average hold time
- Identifies best and worst performing stocks

**Paper vs Real Performance Tracking** *(v1.3)*
- **Filter chips**: All Trades / Paper Mode / Real Trades
- **Paper trades**: Simulated execution without broker API calls
- **Real trades**: Actual executed orders
- **Same analytics**: Both modes calculated identically
- **Comparison**: Validate strategies in paper mode before going live
- **Visual indicators**: PAPER badges on paper mode trades

### Multi-Account Aggregation & Active Switching

Users with multiple investment strategies can set up several different sub-accounts on Robinhood (e.g. Traditional IRA, Roth IRA, and a dedicated individual Margin account for AI-Execution). The mobile app bridges and maps all connected portfolios.

**Selected Account Trackability (`AccountStore`)**:
- **Persistent Choice**: Instead of defaulting to the first fetched account, users can manually select their active portfolio inside their User Settings page. This choice is stored globally in the `AccountStore` via `selectedAccountNumber`.
- **Intelligent Fallbacks**: If no dedicated selection has been made, the app defaults to evaluating any connected **Agentic** account (since it is flagged for isolated automated executions), before falling back to the first available individual account.
- **Home & Execution Sync**: Changing the active account instantly modifies displayed cash balances, updates chart indicators, feeds context into rebalancing recommendation algorithms, and shifts the target of conversational drafts or manual orders made under the Chat assistant widget.

### Conversational Chat Assistant

The app includes a fully contextualized conversational Gemini assistant with seamless portfolio integration.

**Proposal Parsing & Flow**:
- **Automatic Drafts**: When you ask the chat helper to place a trade, suggest rebalancing assets, or research ideas, it prepares a standard custom code sequence matching:
  - Stock Trades: `[TRADE_PROPOSAL: Action Stock Symbol Qty Quantity Type market/limit Price LimitPrice]`
  - Options Trades: `[TRADE_PROPOSAL_OPTION: Action Stock Symbol Call/Put Exp ExpiryDate Strike StrikePrice Qty Quantity Type limit Price LimitPrice]`
- **Native Cards**: The application intercepts these codeblocks before compiling message bubbles, transforming the raw text into neat, interactive **Interactive Proposal Card overlays**.
- **Secure Native Flow**:
  - **Verify Limits**: Tapping "Review Order" on a card computes the total estimated cost, fetches real-time quotes, and warns if configured funds or buying power limits are violated.
  - **Execute Natively**: Tapping "Execute Trade" dispatches an order request to the active account on the Robinhood API securely from client code, locking in the transaction instantenously.

**Key Metrics Explained:**

*Sharpe Ratio*
- Measures return vs volatility
- Higher = better risk-adjusted returns
- Used to compare different strategies fairly
- Good >1, Fair 0-1, Poor <0

*Profit Factor*
- Simple profitability measure
- PF > 1 = profitable
- PF > 2 = excellent (2:1 or better win/loss)
- PF < 1 = money losing strategy

*Expectancy*
- Average profit per trade
- Positive expectancy = strategy is profitable
- Crucial for validating trading system
- (Winning trades × Win rate) - (Losing trades × Loss rate)

*Max Drawdown*
- Largest peak-to-trough decline
- Important risk metric
- Helps set stop-loss levels
- Shows portfolio volatility

The `monitorTakeProfitStopLoss()` method automatically exits positions when targets are met:

```dart
Future<Map<String, dynamic>> monitorTakeProfitStopLoss({
  required List<dynamic> positions,
  required brokerageUser,
  required account,
  required brokerageService,
  required instrumentStore,
}) async
```

**Monitoring Flow:**
1. **Position Filtering**
   - Check only positions created by automated trading
   - Positions tracked in `_automatedBuyTrades` list
   - Manual trades and pre-existing positions are NOT monitored

2. **Position Analysis**
   - Iterate through automated trade records
   - Extract entry price and current price
   - Calculate profit/loss percentage using trade record's entry price
   - **Update highestPrice for trailing stop tracking**

3. **Threshold Checks**
   - If P/L >= `takeProfitPercent`: Trigger Take Profit exit
   - If P/L <= -`stopLossPercent`: Trigger Stop Loss exit
   - **If Trailing Stop enabled: Check if price dropped below (highestPrice - trailingStopPercent)**

4. **Order Execution**
   - **Check `paperTradingMode`: Simulate or execute real order**
   - Fetch instrument data for the symbol
   - Place SELL order through brokerage service (or simulate in paper mode)
   - Validate order response (200/201 status)
   - Remove trade record from `_automatedBuyTrades`
   - Track exit in history with reason and P/L%

5. **Analytics & Logging**
   - Log exit execution events
   - Track failures separately
   - Update trade history with paper/real indicator
   - Record exit reason (Take Profit/Stop Loss/Trailing Stop)

6. **Persistence**
   - **Save updated trades list to Firebase after exits**
   - Ensures accuracy across sessions

**Integration:**
- Runs every 5 minutes as part of auto-trade timer
- Executes after checking for new trade entry signals
- Only monitors positions opened by automated trading
- Manual trades remain under user control
- Positions opened before auto-trading was enabled are not affected

**Trade-Level Tracking:**
- When automated BUY order executes: Trade record added to `_automatedBuyTrades`
- Record contains: `{symbol, quantity, entryPrice, timestamp, enabledIndicators, paperMode, highestPrice}`
- When TP/SL/Trailing Stop exit executes: Specific trade record removed
- Manual trades: Never added to tracking, never monitored for TP/SL
- **Stored in Firebase**: `users/{userId}/automated_buy_trades` subcollection
- **Persists across**: App restarts and device changes

**Trailing Stop Loss:**
- **Activated when**: `trailingStopEnabled = true` and `trailingStopPercent` configured
- **Tracks**: `highestPrice` for each automated trade
- **Exits when**: Current price drops more than `trailingStopPercent` below peak
- **Benefit**: Locks in gains while allowing further upside
- **Example**: Entry $100, peak $120, trailing stop 5% → Exit trigger at $114

**Paper Trading Simulation:**
- **`paperTradingMode = true`**: Calls `_simulatePaperOrder()` instead of broker API
- **Creates realistic response**: With all expected fields (id, status, executions)
- **Tracks identically**: Same P/L, analytics, exit reasons
- **Persists to Firebase**: Marked with `paperMode: true` flag
- **Filtered in analytics**: Paper vs real trade comparison available

**Example - Automated Position:**
```
Auto-trade buys: 10 AAPL at $150 → Trade record created
Record: {symbol: 'AAPL', quantity: 10, entryPrice: 150.00, timestamp: '...', enabledIndicators: ['momentum', 'macd'], paperMode: false, highestPrice: 150.00}
Current price: $165 → highestPrice updated to 165.00
P/L = ((165 - 150) / 150) * 100 = 10%

Scenario 1 - Take Profit:
If takeProfitPercent = 10%: Trigger SELL 10 shares
After exit: Trade record removed, analytics updated

Scenario 2 - Trailing Stop:
If trailingStopEnabled = true, trailingStopPercent = 3%
Price rises to $170 (highestPrice = 170.00)
Price drops to $165 (drop = 2.9%, below 3% threshold)
No exit yet

Price drops to $164.80 (drop = 3.05%, exceeds 3% threshold)
Trigger SELL 10 shares at $164.80
Locked in profit from $150 to $164.80
```

**Example - Manual + Automated Same Symbol:**
```
User owns: 100 AAPL at $140 (manual, not tracked)
Auto-trade buys: 10 AAPL at $150 (tracked separately)
Current price: $165

For automated trade:
P/L = ((165 - 150) / 150) * 100 = 10%
Action: SELL 10 shares (from automated trade)
Result: Manual 100 shares @ $140 remain untouched
```

**Example - Multiple Automated Trades:**
```
Auto-trade 1: Buy 10 AAPL @ $150 (tracked)
Auto-trade 2: Buy 5 AAPL @ $160 (tracked separately)
Current price: $165

Trade 1 P/L: ((165-150)/150)*100 = 10% → Triggers TP, SELL 10 shares
Trade 2 P/L: ((165-160)/160)*100 = 3.1% → No trigger
Result: Two separate entries, tracked and managed independently
```

### Firebase Persistence

**Automated Buy Trades Storage:**
- **Collection Path**: `users/{userId}/automated_buy_trades`
- **Document Structure**: Each trade as a separate document
- **Fields**: 
  - `symbol`: Stock symbol (string)
  - `quantity`: Number of shares (int)
  - `entryPrice`: Entry price per share (double)
  - `timestamp`: Execution time (ISO string)
  - `enabledIndicators`: Active indicators at trade time (List<String>) *(v1.3)*
  - `paperMode`: Whether trade was simulated (bool) *(v1.3)*
  - `highestPrice`: Peak price for trailing stop tracking (double) *(v1.3)*
- **Security Rules**: Updated firestore.rules to allow read/write for authenticated users

**Automatic Saving:**
- Trades saved immediately after BUY order execution
- Trades removed immediately after TP/SL/Trailing Stop exit
- Ensures data integrity across app restarts
- Field validation on load for data integrity
- **Paper trades**: Persisted identically to real trades (marked with `paperMode: true`)

**Loading:**
- Trades loaded on user login (via `loadAutomatedBuyTradesFromFirestore`)
- Automatic sync across devices
- Enables continuous TP/SL monitoring across sessions
- Try-catch error handling for robustness
- Validates all required fields when loading

**Benefits:**
- **Persistence**: Survives app crashes and restarts
- **Cross-Device**: User logs in on different device, trades sync
- **Reliability**: Firebase ensures data availability
- **History**: Complete audit trail of automated trades
- **Security**: Firestore rules protect user data
- **Analytics**: enabledIndicators enable performance analysis by indicator combination
- **Paper Tracking**: Separates paper and real trades for comparison

**Example Workflow:**
```
Session 1:
- User enables auto-trading in Paper Mode
- Auto-trade buys 3 positions
- Trades saved to Firebase with paperMode: true and enabledIndicators snapshot

App restart:
- User logs in
- Trades loaded from Firebase automatically
- TP/SL monitoring resumes seamlessly
- Analytics filters show Paper trades separately

Switch to Real Mode:
- User disables Paper Mode
- Next trades execute with paperMode: false
- Analytics now show both paper and real performance
- Can compare strategy effectiveness

Device switch:
- User logs in on new device (tablet)
- All trades sync from Firebase
- Full functionality restored instantly
- Analytics updated with latest metrics
```

**Trade Record Example:**
```json
{
  "symbol": "AAPL",
  "quantity": 10,
  "entryPrice": 150.25,
  "timestamp": "2025-12-13T14:30:45.123Z",
  "enabledIndicators": ["momentum", "macd", "volume"],
  "paperMode": false,
  "highestPrice": 155.50
}
```

### Provider Architecture

**Separation of Concerns:**

The recent refactoring (commit 861f2bc) introduced a cleaner architecture with separated responsibilities:

1. **TradeSignalsProvider**:
   - **Purpose**: Centralized signal management
   - **Responsibilities**:
     - Fetch trade signals from Firestore
     - Real-time signal listeners
     - Provide indicator documentation
     - Market status checking
   - **Usage**: InstrumentWidget, SearchWidget, etc.

2. **AgenticTradingProvider**:
   - **Purpose**: Trade execution and automation
   - **Responsibilities**:
     - Auto-trade execution logic
     - TP/SL monitoring
     - Trade tracking (automated buy trades)
     - Firebase persistence
     - Risk management
   - **Usage**: NavigationWidget (timer), SettingsWidget

3. **MarketHours Utility**:
   - **Purpose**: Consistent market hours checking
   - **Functionality**:
     - DST-aware Eastern Time conversion
     - Weekend detection
     - Market hours validation (9:30 AM - 4:00 PM ET)
   - **Usage**: Both providers and widgets

**Benefits of Refactoring:**
- **Modularity**: Each provider has a single, clear purpose
- **Reusability**: TradeSignalsProvider used across multiple widgets
- **Maintainability**: Easier to modify signal fetching without affecting execution
- **Testability**: Unit test individual components in isolation
- **Performance**: Optimized signal subscriptions and market checks

### Risk Management Controls

#### Daily Trade Limit
- **Config Field**: `dailyTradeLimit` (default: 5)
- **Purpose**: Prevents over-trading and excessive market exposure
- **Reset**: Automatically resets at market open each trading day

#### Cooldown Period
- **Config Field**: `autoTradeCooldownMinutes` (default: 60)
- **Purpose**: Enforces minimum time between trades
- **Behavior**: Trades are blocked until cooldown expires

#### Emergency Stop
- **Activation**: Via UI button or API call
- **Effect**: Immediately halts all auto-trading
- **Persistence**: Remains active until manually deactivated
- **Use Case**: Market volatility, system issues, or user intervention

#### Position Size Limits
- **Config Field**: `maxPositionSize` (default: 100 shares)
- **Purpose**: Caps individual position sizes
- **Integration**: Used by risk assessment functions

#### Portfolio Concentration
- **Config Field**: `maxPortfolioConcentration` (default: 50%)
- **Purpose**: Prevents over-concentration in single positions
- **Calculation**: Position value / total portfolio value

#### Take Profit
- **Config Field**: `takeProfitPercent` (default: 10.0%)
- **Purpose**: Automatically exits positions when profit target is reached
- **Calculation**: `((currentPrice - entryPrice) / entryPrice) * 100`
- **Behavior**: When position P/L >= takeProfitPercent, system executes SELL order
- **Scope**: Only applies to positions opened by automated trading
- **Use Case**: Lock in profits automatically without manual monitoring

#### Stop Loss
- **Config Field**: `stopLossPercent` (default: 5.0%)
- **Purpose**: Automatically exits positions to limit losses
- **Calculation**: `((currentPrice - entryPrice) / entryPrice) * 100`
- **Behavior**: When position P/L <= -stopLossPercent, system executes SELL order
- **Scope**: Only applies to positions opened by automated trading
- **Use Case**: Protect capital by automatically cutting losing positions

### The Complete Automated Trading Configuration Handbook

The RealizeAlpha Automated Trading engine exposes over 45 fine-grained parameters spanning execution safety, strategy design, portfolio risk containment (RiskGuard), technical indicators, custom quantitative formulas, multi-tier sequential stops, and backtesting.

In the mobile application, settings are organized via **Progressive Disclosure**:
- **Simplified Mode (`simplified`)**: A clean 4-card interface for everyday investors providing one-tap Strategy Archetypes, a continuous Capital Budget allocation slider, and 3-state Risk Comfort presets.
- **Quant Pro Mode (`quantPro`)**: An exhaustive institutional control matrix unlocking raw mathematical indicator inputs, custom formula syntax, 5-tier GEX stops, sector caps, and OEM background execution journals.

Below is the authoritative, beginner-friendly handbook documenting every configuration setting across 6 operational chapters.

---

#### Chapter 1: Master Controls, Execution Timing & Platform Scheduling

Master controls govern the operational lifecycle of automated trading, isolating simulated paper testing from live capital, enforcing human-in-the-loop review when desired, and scheduling execution loops across foreground and background threads.

| Configuration Key | JSON / Model Key | Type & Range | Default | UI Mode | Summary |
| --- | --- | --- | --- | --- | --- |
| **Auto-Trading Master Switch** | `autoTradeEnabled` | `bool` | `false` | Both | Master system toggle that activates foreground scans and background timers. |
| **Paper Trading Mode** | `paperTradingMode` | `bool` | `true` | Both | Isolates simulated paper trades from real brokerage balances. |
| **Require Approval** | `requireApproval` | `bool` | `false` | Both | Stages proposals in a pending tray for manual one-tap execution review. |
| **Emergency Stop** | `emergencyStopActivated` | `bool` | `false` | Both | Immediate manual circuit breaker halting all evaluations and executions. |
| **Paper Quote Source** | `paperQuoteSource` | `PaperQuoteSource` enum | `selectedBrokerage` | Quant Pro | Selects the connected account providing live quotes for paper orders. |
| **Foreground Check Frequency** | `checkIntervalMinutes` | `int` (1–60) | `5 min` | Quant Pro | Scan frequency while the application is active in the foreground. |
| **Cooldown Period** | `autoTradeCooldownMinutes` | `int` (1–1440) | `60 min` | Quant Pro | Mandatory rest interval between consecutive automated trades. |
| **Daily Trade Limit** | `dailyTradeLimit` | `int` (1–100) | `5 trades` | Both | Daily ceiling on automated BUY orders (resets each morning at market open). |

##### In-Depth Operational Breakdown

1. **Auto-Trading Master Switch (`autoTradeEnabled`)**
   - **What it does:** Serves as the primary power switch for algorithmic execution. When enabled, the app initializes the foreground evaluation timer and registers OS background tasks. When disabled, all evaluation cycles halt immediately, resting limit orders are canceled or left unmonitored, and no new proposals are formulated.
   - **Interactions & Overrides:** Cannot be enabled if no supported brokerage is linked or if zero entry indicators are selected in Systematic mode. Overridden unconditionally by `emergencyStopActivated`.
   - **Pro Tips:**
     - *Beginners:* Always leave Auto-Trading in **Paper Trading Mode** (`paperTradingMode: true`) for at least 10 trading sessions to observe how signals behave across different market sessions.
     - *Advanced Quants:* Toggling the master switch off does *not* liquidate existing positions; it merely stops the scanner. Use the 5-Tier Stop Queue or Emergency Stop if immediate liquidation or halt is required.

2. **Paper Trading Mode (`paperTradingMode`)**
   - **What it does:** Diverts all order fills into a localized virtual ledger. Uses live streaming quotes from your linked broker, but commits zero real money. Paper cash, virtual positions, realized P&L, and performance statistics stay completely separate from live accounts.
   - **Interactions & Overrides:** Switching from Paper to Live prompts a safety confirmation modal. In Paper mode, account equity checks use the virtual paper balance rather than your real cash.
   - **Pro Tips:**
     - *Beginners:* Use Paper mode to build confidence with automated stops without emotional stress.
     - *Advanced Quants:* Paper fills execute at current live bid/ask quotes, providing realistic slippage simulation for backtesting validation.

3. **Require Approval (`requireApproval`)**
   - **What it does:** Toggles semi-autonomous order staging. When enabled (`true`), high-conviction signals generate a trade proposal with an AI rationale and stage it in the **Pending Approvals** tray. Orders require a physical tap on "Approve" to execute. When disabled (`false`), orders execute automatically without user intervention.
   - **Interactions & Overrides:** If a proposal sits unapproved for longer than 3 minutes, `AgenticTradingProvider` re-verifies the live quote before execution. If price has deviated by $> 3\%$, the order is automatically rejected to protect against slippage.
   - **Pro Tips:**
     - *Beginners:* Enable Require Approval when getting started. It allows you to see the exact reasoning behind every trade before money is committed.
     - *Advanced Quants:* Disable Require Approval for high-speed systematic scalping where sub-minute fills are essential.

4. **Emergency Stop (`emergencyStopActivated`)**
   - **What it does:** An unbypassable kill switch. Immediately halts all foreground timers, rejects any pending proposals, and prevents any automated order from submitting.
   - **Interactions & Overrides:** Overrides `autoTradeEnabled`. Can be triggered from the settings header, the Simplified view button, or by long-pressing the auto-trade app bar pill.
   - **Pro Tips:**
     - *Universal:* If market-wide volatility spikes unexpectedly (e.g., sudden geopolitical announcements or exchange connectivity issues), activate Emergency Stop to freeze all activity instantly.

5. **Paper Quote Source (`paperQuoteSource`)**
   - **What it does:** Designates which brokerage connection supplies live market prices for virtual paper trades (`selectedBrokerage`, `robinhood`, or `schwab`).
   - **Interactions & Overrides:** If set to `selectedBrokerage`, it dynamically uses whichever broker is currently active. If pinned to a specific broker, that account must remain authenticated.

6. **Foreground Check Frequency (`checkIntervalMinutes`)**
   - **What it does:** Sets how frequently (in minutes) the app scans your watchlist while running in the foreground.
   - **Interactions & Overrides:** Only governs active foreground app sessions. When the app is closed or backgrounded, mobile operating systems schedule background tasks every ~15 minutes via Android WorkManager or iOS BackgroundTasks.

7. **Cooldown Period (`autoTradeCooldownMinutes`)**
   - **What it does:** Enforces a minimum resting time between consecutive automated trades.
   - **Interactions & Overrides:** Prevents whipsaw losses during sudden market crashes where multiple symbols trigger buy signals simultaneously in rapid succession.

---

#### Chapter 2: Strategy Selection, Archetypes & Progressive Disclosure

This layer controls how trading decisions are generated—from mathematical rules to autonomous LLM reasoning—and allows users to seamlessly switch between Simplified and Quant Pro interfaces without losing settings.

| Configuration Key | JSON / Model Key | Type & Range | Default | UI Mode | Summary |
| --- | --- | --- | --- | --- | --- |
| **Interface Mode** | `uiMode` | `AgenticTradingUiMode` | `simplified` | Both | Toggles between Simplified 4-control view and Quant Pro parameter matrix. |
| **Strategy Style** | `tradingMode` | `TradingMode` enum | `systematic` | Both | Selects between deterministic `systematic` rules and Gemini `reasoning`. |
| **Strategy Archetype** | `selectedTemplateId` | `String` ID | Curated | Simplified | Walk-forward verified archetype packages (e.g., Momentum, Swing, Value). |
| **Capital Budget** | `maxPortfolioConcentration`| `double` (0.05–1.0) | `0.20` (20%) | Simplified | Maximum percentage of portfolio equity allocated across all auto-trades. |
| **Risk Comfort Level** | `RiskComfortLevel` | `conservative`, `balanced`, `aggressive` | `balanced` | Simplified | 3-state preset auto-tuning stop-loss, profit target, and trade quantity. |

##### In-Depth Operational Breakdown

1. **Interface Mode (`uiMode`)**
   - **What it does:** Persisted locally in device preferences (`agentic_trading_ui_mode`), this toggle switches between the streamlined **Simplified View** and the comprehensive **Quant Pro View**.
   - **Interactions & Overrides:** Switching modes *never* mutates or resets your underlying custom parameters. All customized technical indicators, custom formulas, and advanced stops remain perfectly preserved in memory and Firestore.

2. **Strategy Style (`tradingMode`)**
   - **Systematic Rules (`systematic`):** Deterministic mathematical execution. The engine evaluates technical indicators (RSI, MACD, Moving Averages) and custom quantitative formulas. Zero AI latency, zero model hallucinations, and 100% reproducible backtests.
   - **Agentic Reasoning (`reasoning`):** Autonomous AI decision engine powered by Google Gemini. Ingests real-time market data, technical indicator consensus, options Gamma Exposure (GEX), broad market macro regimes, news sentiment, and SEC insider filings. Gemini outputs an explicit step-by-step chain-of-thought rationale before generating an order proposal.
   - **Interactions & Overrides:** Reasoning mode requires enabling "Autonomous Agentic Trading" in Beta Labs. Both styles are strictly bound by RiskGuard safeguards.
   - **Pro Tips:**
     - *Beginners:* Start with Systematic Rules using curated archetypes.
     - *Advanced Quants:* Use Agentic Reasoning for multi-factor swing trading where macro context and options flow matter as much as technical levels.

3. **Strategy Archetypes (`StrategyArchetypes`)**
   - **What it does:** Curated, out-of-the-box strategy packages tested across multi-year historical walk-forward windows:
     - **Conservative Core:** Low-volatility trend following using 50/200 SMA golden crosses and 1% risk allocation.
     - **Momentum Breakout:** High-momentum setups combining RSI pullbacks, MACD histogram crossovers, and volume expansion.
     - **Options Income Harvester:** High IV Rank credit setups targeting range-bound underlyings.
     - **Reasoning AI Agent:** Autonomous institutional synthesis leveraging Gemini reasoning and GEX structural levels.
   - **Interactions & Overrides:** Tapping an archetype opens the interactive `StrategyArchetypeDetailBottomSheet`, allowing you to inspect win rates, maximum historical drawdown, and full indicator parameters before applying or cloning to a custom template.

4. **Capital Budget Allocation Slider**
   - **What it does:** Sets the global ceiling on the fraction of your total portfolio that auto-trading can deploy across all open positions combined.
   - **Interactions & Overrides:** The UI computes a real-time dollar estimate based on current portfolio equity (e.g., 25% on a \$10,000 account = up to \$2,500 total exposure). Once total open market value reaches this budget, all new entry proposals are blocked until existing positions are closed.
   - **Pro Tips:**
     - *Preservation:* The unallocated portion of your portfolio is preserved and never touched by auto-trading, protecting cash for long-term investments.

5. **Risk Comfort Level (`RiskComfortLevel`)**
   - **What it does:** A 3-state selector that instantly harmonizes Stop Loss, Profit Target, and default Trade Size to mathematically proven risk-to-reward ratios:
     - **🛡️ Conservative:** 3.0% Stop Loss, 6.0% Profit Target (2:1 reward/risk), 1 share per trade (1.0% account risk).
     - **⚖️ Balanced:** 5.0% Stop Loss, 10.0% Profit Target (2:1 reward/risk), 2 shares per trade (2.0% account risk).
     - **⚡ Aggressive:** 10.0% Stop Loss, 20.0% Profit Target (2:1 reward/risk), 5 shares per trade (3.0% account risk).
   - **Interactions & Overrides:** If custom Quant Pro stop parameters are configured that do not match these exact presets, the segmented button clears selection and displays a custom parameters banner without overriding your custom values.

---

#### Chapter 3: Portfolio Risk Safeguards & Position Sizing (RiskGuard)

RiskGuard is RealizeAlpha's pre-trade risk engine. Before any BUY proposal can reach the broker, it must pass through an institutional battery of risk checks.

| Configuration Key | JSON / Model Key | Type & Range | Default | UI Mode | Summary |
| --- | --- | --- | --- | --- | --- |
| **Trade Sizing Mode** | `positionSizingMode` | `PositionSizingMode` | `fixedShares` | Quant Pro | 3-way per-order sizing selector: `fixedShares`, `targetDollar`, or `dynamicRisk`. |
| **Trade Quantity** | `tradeQuantity` | `int` ($\ge 1$) | `1 share` | Both | Fixed share count per order when Trade Sizing is `fixedShares`. |
| **Target Dollar Allocation** | `targetDollarAllocation` | `double` ($\ge \$10$) | `\$500.0` | Quant Pro | Fixed dollar target per order ($\lfloor \text{Target} / \text{Price} \rfloor$, min 1 share). |
| **Risk Per Trade %** | `riskPerTrade` | `double` (0.01–100%)| `1.0%` | Quant Pro | Fraction of portfolio equity risked between entry and stop-loss price under `dynamicRisk`. |
| **ATR Multiplier** | `atrMultiplier` | `double` (0.1–10.0) | `2.0x` | Quant Pro | Stop loss distance in multiples of 14-period Average True Range for dynamic sizing. |
| **Position Limit Mode** | `positionLimitMode` | `PositionLimitMode` | `maxShares` | Quant Pro | Binary option selector for cumulative position ceiling: `maxShares` or `maxPercent`. |
| **Max Position Size** | `maxPositionSize` | `int` ($\ge 1$) | `100 shares`| Quant Pro | Active when Position Sizing is `maxShares`: cumulative share ceiling per stock. |
| **Max Single-Stock Concentration %** | `maxPortfolioConcentration` | `double` (1–100%) | `20.0%` | Quant Pro | Active when Position Sizing is `maxPercent`: cumulative portfolio equity % ceiling per stock. |
| **Total Capital Budget %** | `totalCapitalBudgetPercent` | `double` (5–100%) | `50.0%` | Both | Global account budget: max portfolio equity allocated to automated trading across all positions combined. |
| **Daily Trade Limit** | `dailyTradeLimit` | `int` (1–100) | `5` | Quant Pro | Maximum number of automated BUY orders permitted per day. |
| **Sector Exposure Limits** | `enableSectorLimits` | `bool` | `false` | Quant Pro | Caps cumulative capital allocation to any single GICS market sector. |
| **Max Sector Exposure %**| `maxSectorExposure` | `double` (1–100%) | `20.0%` | Quant Pro | Maximum portfolio percentage allowed in one sector (e.g. Technology). |
| **Correlation Checks** | `enableCorrelationChecks` | `bool` | `false` | Quant Pro | Rejects new trades that are heavily correlated with existing holdings. |
| **Max Correlation** | `maxCorrelation` | `double` (0.0–1.0) | `0.70` | Quant Pro | Correlation threshold above which candidate trades are rejected. |
| **Volatility Filters** | `enableVolatilityFilters` | `bool` | `false` | Quant Pro | Restricts entries based on Implied Volatility (IV Rank). |
| **Min Volatility (IV Rank)**| `minVolatility` | `double` (0–100%) | `10.0%` | Quant Pro | Minimum IV Rank required (filters out dead, unmoving tickers). |
| **Max Volatility (IV Rank)**| `maxVolatility` | `double` (0–100%) | `80.0%` | Quant Pro | Maximum IV Rank allowed (filters out dangerous binary events / meme spikes). |
| **Drawdown Protection** | `enableDrawdownProtection` | `bool` | `false` | Quant Pro | Global circuit breaker halting trading if account drawdown exceeds limit. |
| **Max Drawdown %** | `maxDrawdown` | `double` (1–100%) | `10.0%` | Quant Pro | Peak-to-trough account drawdown percentage that halts auto-trading. |
| **Macro Risk-Off Policy** | `macroRiskOffPolicy` | `MacroRiskOffPolicy`| `ignore` | Both | Action taken during defensive macro regimes: `ignore`, `reduceSize`, `blockEntries`. |
| **Risk-Off Size Reduction**| `riskOffSizeReduction`| `double` (0.05–0.95)| `0.50` (50%) | Quant Pro | Sizing haircut applied when macro regime is `RISK_OFF` under `reduceSize`. |

##### In-Depth Operational Breakdown

1. **Trade Sizing (Per-Order Sizing Modes)**
   - **Mode 1: Fixed Shares (`fixedShares`):** The engine buys exactly `tradeQuantity` shares (default 1–5 shares) per order. Recommended for index ETFs and predictable recurring entries.
   - **Mode 2: Target Dollar Allocation (`targetDollar`):** The engine targets an exact capital allocation per order (e.g. \$500 per entry):
     $$\text{Shares} = \max\left(1, \left\lfloor \frac{\text{Target Dollar Allocation}}{\text{Last Price}} \right\rfloor\right)$$
     This normalizes position size across varying stock prices (e.g. 3 shares of \$140 NVDA vs. 1 share of \$420 MSFT) without complex volatility calculations.
   - **Mode 3: Dynamic ATR Risk Sizing (`dynamicRisk`):** The engine calculates shares based on distance to the volatility stop loss:
     $$\text{Stop Distance} = \text{ATR}_{14} \times \text{atrMultiplier}$$
     $$\text{Shares} = \max\left(1, \left\lfloor \frac{\text{Portfolio Equity} \times \text{riskPerTrade}}{\text{Stop Distance}} \right\rfloor\right)$$
     Dynamic sizing ensures higher-volatility stocks receive smaller share allocations while low-volatility stocks receive larger allocations, equalizing total dollar risk per trade.
   - **Legibility & Styling:** Sizing options are presented via a high-contrast segmented control with full-size typography (no cramped icons or shrinking text) for effortless readability.

2. **Position Sizing (Binary Option Cumulative Ceilings)**
   - RiskGuard provides a binary option selector to control cumulative single-stock exposure:
     - **Option A: Max Shares (`maxShares`):** Sets an absolute ceiling on the cumulative number of shares you may hold in any single symbol (e.g. 100 shares). Useful when you have fixed lot sizes.
     - **Option B: Max Portfolio % (`maxPercent`):** Sets a relative ceiling as a percentage of your total portfolio equity (e.g. 20% max in NVDA). Adapts automatically as your account equity grows.
   - **Decline Rather than Silently Mutate:** If a proposed order would cause cumulative holdings in a symbol to breach the selected ceiling, RiskGuard *declines* the order with an explicit explanatory audit trail (e.g. `Order of 15 shares would bring AAPL position to 110 shares, exceeding Max Position Size limit of 100 shares`) rather than silently clipping or modifying order quantity.

3. **Account Safety Limits (Global Controls)**
   - **Total Automated Capital Budget %:** Caps cumulative equity across *all* active automated positions combined (default 50% of account equity), ensuring automated trading never exhausts account liquidity or leverage.
   - **Daily Trade Limit:** Maximum automated trades allowed per market day.

4. **Position Sizing Simulator & Pre-Flight Checks**
   - An interactive simulator card directly inside the Risk Management section allows you to test any stock price and ATR against your active Trade Sizing mode and Position Sizing ceiling.
   - Provides immediate real-time feedback displaying calculated order shares, notional dollar value, position concentration percentage, and dollar risk at stop, accompanied by an instant `RiskGuard Pre-Flight: APPROVED` or `DECLINED` breakdown.

5. **Strategy Archetypes & Templates**
   - Curated archetypes pre-configure both Trade Sizing and Position Sizing for institutional coherence:
     - **Conservative Core:** Dynamic ATR risk sizing (1% risk) paired with a 20% portfolio concentration ceiling (`maxPercent`).
     - **Momentum Breakout:** Dynamic ATR risk sizing (2% risk) paired with a 30% portfolio concentration ceiling (`maxPercent`).
     - **Options Income Harvester:** Target Dollar sizing (\$1,000 target) paired with a 75-share ceiling (`maxShares`).
     - **Reasoning AI Agent:** Dynamic ATR risk sizing (2% risk) paired with a 25% portfolio concentration ceiling (`maxPercent`).
   - Tapping **Apply Archetype** presents a side-by-side comparison modal with a **"Keep personal Safety Limits"** checkbox preserving your custom Position Sizing ceiling and Total Capital Budget.

2. **Sector Exposure Limits (`enableSectorLimits`, `maxSectorExposure`)**
   - **What it does:** Prevents over-concentration in a single industry. Uses GICS sector classifications (Technology, Financials, Healthcare, Energy, etc.).
   - **Behavior:** If you own Apple and Nvidia, and Technology currently constitutes 19.5% of your portfolio, a new BUY proposal in AMD will be rejected if `maxSectorExposure` is set to 20%.

3. **Correlation Checks (`enableCorrelationChecks`, `maxCorrelation`)**
   - **What it does:** Calculates 60-day price return correlation between the candidate symbol and all currently open positions.
   - **Behavior:** If correlation exceeds `maxCorrelation` (default 0.70), the candidate trade is rejected to maintain true portfolio diversification.

4. **Volatility Filters (`enableVolatilityFilters`, `minVolatility`, `maxVolatility`)**
   - **What it does:** Restricts trade entries based on 52-week Implied Volatility Rank (IV Rank).
   - **Behavior:**
     - *Min Volatility (10%):* Ensures the stock has enough price action and liquidity to hit profit targets.
     - *Max Volatility (80%):* Protects against entering ahead of erratic earnings binary events or distressed biotech swings.

5. **Drawdown Protection Circuit Breaker (`enableDrawdownProtection`, `maxDrawdown`)**
   - **What it does:** Acts as an account-level circuit breaker. Tracks your portfolio's high-water mark equity. If the decline from the peak reaches `maxDrawdown` (e.g. 10%), all automated trading halts immediately.

6. **Macro Risk-Off Policy (`macroRiskOffPolicy`)**
   - Controls how the system behaves when the macroeconomic cycle evaluates to `RISK_OFF` (Defensive / High Market Risk):
     - `ignore`: Proceeds with technical trading regardless of macro backdrop.
     - `reduceSize`: Cuts trade size by `riskOffSizeReduction` (e.g. 50% fewer shares), allowing high-conviction trades with smaller risk exposure.
     - `blockEntries`: Completely halts new BUY orders until the macro environment returns to `RISK_ON` or `NEUTRAL`.

---

#### Chapter 4: Entry Strategies, Technical Indicators & Consensus Scoring

The Entry Engine evaluates market data to detect high-probability technical setups. Users can require 100% indicator consensus or establish weighted multi-indicator thresholds.

| Configuration Key | JSON / Model Key | Type & Range | Default | UI Mode | Summary |
| --- | --- | --- | --- | --- | --- |
| **Symbol Filter** | `symbolFilter` | `List<String>` | `[]` (Empty) | Quant Pro | Specific tickers to scan. When empty, scans liquid S&P 500 universe. |
| **Trading Interval** | `interval` | `'15m'`, `'1h'`, `'1d'` | `'1d'` | Quant Pro | Candle resolution used for indicator calculations and holding horizons. |
| **Strict Entry Mode** | `requireAllIndicatorsGreen`| `bool` | `false` | Quant Pro | When enabled, requires 100% of enabled indicators to signal BUY. |
| **Min Signal Strength** | `minSignalStrength` | `double` (0–100%) | `50%` | Quant Pro | Weighted consensus score required for entry when Strict Mode is off. |
| **RSI Period** | `rsiPeriod` | `int` (2–100) | `14` | Quant Pro | Lookback candles for Relative Strength Index calculation. |
| **ROC Period** | `rocPeriod` | `int` (1–100) | `12` | Quant Pro | Lookback candles for Rate of Change momentum calculation. |
| **Fast SMA Period** | `smaPeriodFast` | `int` (2–200) | `20` | Quant Pro | Period for the fast Simple Moving Average. |
| **Slow SMA Period** | `smaPeriodSlow` | `int` (5–500) | `50` | Quant Pro | Period for the slow Simple Moving Average. |
| **Market Index Benchmark** | `marketIndexSymbol` | `String` | `'SPY'` | Quant Pro | Benchmark index symbol used for market direction and regime analysis. |
| **Custom Indicators** | `customIndicators` | `List<CustomIndicatorConfig>` | `[]` | Quant Pro | User-defined quantitative formulas and threshold conditions. |

##### The 19 Built-In Technical Indicators

The engine features 19 institutional-grade technical indicators that can be independently toggled:

| Indicator Key | Display Label | Description & Default Condition |
| --- | --- | --- |
| `priceMovement` | Price Movement | Moving average crossover and short-term price trend confirmation. |
| `momentum` | Momentum (RSI) | Relative Strength Index (14-period). Bullish when oversold or crossing above 50. |
| `marketDirection` | Market Direction | 50 SMA vs 200 SMA trend alignment on benchmark index (`SPY`). |
| `volume` | Volume Confirmation | Current bar volume $> 1.2\times$ 20-period Average Volume. |
| `macd` | MACD | MACD line crossing above signal line with positive histogram expansion. |
| `bollingerBands` | Bollinger Bands | Price bouncing off lower 2-SD band or breaking out of a low-volatility squeeze. |
| `stochastic` | Stochastic Oscillator | %K crossing above %D from oversold territory ($< 20$). |
| `atr` | Average True Range | Volatility expansion threshold ensuring sufficient price movement. |
| `obv` | On-Balance Volume | Rising cumulative volume trend confirming upward price trajectory. |
| `vwap` | VWAP | Intraday institutional benchmark; bullish when price crosses above VWAP. |
| `adx` | Average Directional Index | Trend strength gauge; signals active trend when ADX $> 25$. |
| `williamsR` | Williams %R | Fast momentum oscillator; signals recovery from oversold levels ($< -80$). |
| `ichimoku` | Ichimoku Cloud | Price above Kumo Cloud with Tenkan-sen above Kijun-sen. |
| `cci` | Commodity Channel Index | Cyclical trend indicator; bullish when crossing above $-100$ or $+100$. |
| `parabolicSar` | Parabolic SAR | Trailing trend reversal; bullish when SAR dots flip below price candles. |
| `roc` | Rate of Change | Momentum velocity; percentage price change over lookback window is positive. |
| `chaikinMoneyFlow` | Chaikin Money Flow | Institutional accumulation; CMF $> 0.05$ indicates continuous buying pressure. |
| `fibonacciRetracements`| Fibonacci Retracements | Price finding support at key mathematical ratios (38.2%, 50.0%, 61.8%). |
| `pivotPoints` | Pivot Points | Daily structural support/resistance levels calculated from prior session data. |
| `gammaExposure` | Gamma Exposure (GEX) | Net dealer gamma positioning; positive GEX pins volatility; negative GEX accelerates breakouts. |

##### Strict Consensus vs. Weighted Signal Strength
- **Strict Entry Mode (`requireAllIndicatorsGreen = true`):** Demands 100% unanimous agreement. If you enable 5 indicators, all 5 must register a green BUY signal on the same candle. This produces very few, exceptionally high-conviction trades.
- **Weighted Signal Strength (`requireAllIndicatorsGreen = false`):** Each enabled indicator contributes points toward an aggregate score from 0 to 100. When the composite score meets or exceeds `minSignalStrength` (default 50%), the trade qualifies.
- **Pro Tip:** For daily swing trading, a `minSignalStrength` of 60–70% with 4–6 complimentary indicators (e.g. RSI + MACD + Volume + Market Direction) provides an optimal balance between opportunity frequency and win rate.

---

#### Chapter 5: 5-Tier Sequential Stop Queue & Multi-Stage Exit Strategies

Exiting winning and losing trades with mathematical discipline is the foundation of long-term profitability. RealizeAlpha provides both primary bracket targets and an institutional 5-Tier Sequential Stop Queue.

| Configuration Key | JSON / Model Key | Type & Range | Default | UI Mode | Summary |
| --- | --- | --- | --- | --- | --- |
| **Take Profit Target** | `takeProfitPercent` | `double` (0.5–500%)| `10.0%` | Both | Fixed percentage profit target above entry price. |
| **Stop Loss Limit** | `stopLossPercent` | `double` (0.5–100%)| `5.0%` | Both | Fixed percentage stop loss below entry price. |
| **Dynamic ATR Stops** | `dynamicAtrStopsEnabled` | `bool` | `false` | Quant Pro | Sets stop-loss and profit targets using 14-period ATR multiples. |
| **ATR Stop Multiplier** | `atrStopMultiplier` | `double` (0.5–10.0) | `1.5x ATR` | Quant Pro | Multiplier for ATR stop distance (e.g. $1.5 \times \text{ATR}$). |
| **ATR Target Multiplier**| `atrProfitMultiplier` | `double` (1.0–20.0) | `3.0x ATR` | Quant Pro | Multiplier for ATR profit target (e.g. $3.0 \times \text{ATR}$ = 2:1 R/R). |
| **Adaptive ATR Ratchet** | `atrRatchetEnabled` | `bool` | `true` | Quant Pro | Automatically widens stops in compression ($1.25\times$) and tightens in expansion ($0.75\times$). |
| **Trailing Stop** | `trailingStopEnabled` | `bool` | `false` | Both | Trails the highest observed price, locking in gains. |
| **Trailing Stop Offset** | `trailingStopPercent` | `double` (0.5–50%) | `3.0%` | Both | Percentage pullback from high-water mark that triggers exit. |
| **Partial Exits** | `enablePartialExits` | `bool` | `false` | Quant Pro | Enables multi-stage scaling out (e.g. sell 50% at +5%, remainder at +10%). |
| **Intraday Scalp Timer** | `timeBasedExitEnabled` | `bool` | `false` | Quant Pro | Closes positions after a fixed holding duration (`timeBasedExitMinutes`). |
| **Market Close Exit** | `marketCloseExitEnabled`| `bool` | `false` | Quant Pro | Closes day trades before market close to eliminate overnight gap risk. |
| **Pre-Close Cutoff Window**| `marketCloseExitMinutes`| `int` (1–120) | `15 min` | Quant Pro | Minutes before 4:00 PM ET close to execute market close exits. |
| **RSI Overbought Exit** | `rsiExitEnabled` | `bool` | `false` | Quant Pro | Exits when RSI crosses above threshold (e.g. 75). |
| **Signal Degradation Exit**| `signalStrengthExitEnabled`| `bool` | `false` | Quant Pro | Exits if composite technical signal score falls below minimum threshold. |

##### The 5-Tier Sequential Exit Stop Priority Queue

Located at the bottom of the Exit Strategies panel, this priority queue processes stops sequentially to protect capital against both sudden market structure failures and slow decay:

```
┌─────────────────────────────────────────────────────────────┐
│             5-TIER SEQUENTIAL STOP PRIORITY QUEUE           │
├───────┬───────────────────────────────┬─────────────────────┤
│ TIER  │ STOP MECHANISM                │ PRIMARY OBJECTIVE   │
├───────┼───────────────────────────────┼─────────────────────┤
│ Tier 1│ Stop 1: GEX Structural Stop   │ Market Maker Shift  │
│ Tier 2│ Stop 2: Trailing Peak Drawdown│ Profit Lock-In      │
│ Tier 3│ Stop 3: Time & Theta Decay    │ Stagnation Burn     │
│ Tier 4│ Stop 4: Macro Regime Stop     │ Broad Market Shift  │
│ Tier 5│ Stop 5: Catastrophic Loss     │ Account Fail-Safe   │
└───────┴───────────────────────────────┴─────────────────────┘
```

1. **Stop 1: GEX Structural Stop (`enableGexStructuralStops`)**
   - **Trigger:** Evaluates options market Gamma Exposure (GEX). If the underlying stock price breaches the Net GEX Flip level (`nTrans`) or Key Call Resistance, options dealers transition from volatility dampening (long gamma) to volatility amplification (short gamma).
   - **Action:** Exits the position immediately before dealer hedging triggers rapid cascade selling.

2. **Stop 2: Trailing Peak Drawdown Stop (`enableTrailingPeakStop`, `trailingPeakStopPercent`)**
   - **Trigger:** Tracks the position's highest observed unrealized profit. If the position retreats by `trailingPeakStopPercent` (default 20%) from that peak gain, the stop triggers.
   - **Example:** A position rises to +25% profit. A 20% giveback triggers an exit at +20% net profit, guaranteeing that a large winning trade never turns into a loss.

3. **Stop 3: Time & Theta Decay Stop (`enableTimeThetaStop`, `minDteStopDays`, `stalledSessionsStopLimit`)**
   - **Trigger:** Dual time-decay gate designed for options and capital efficiency:
     - *Options DTE Cutoff:* Closes option contracts when Days to Expiration (DTE) falls below `minDteStopDays` (default 14 days), avoiding the exponential theta decay curve.
     - *Stalled Sessions Limit:* Liquidates equity or option trades that stay flat within a tight range for `stalledSessionsStopLimit` consecutive days (default 10 sessions), freeing up capital from dead money.

4. **Stop 4: Macro Regime Stop (`enableMacroRegimeStop`)**
   - **Trigger:** Transition-aware macroeconomic defense. If the broad market shifts into a Defensive (`RISK_OFF`) regime while you are holding an open position that was entered during `RISK_ON`, the system liquidates the position to prevent holding through bear market drawdowns.
   - **Transition Awareness:** Trades intentionally entered during `RISK_OFF` (via the `reduceSize` policy) are not immediately dumped; only positions whose macro thesis has deteriorated post-entry are liquidated.

5. **Stop 5: Catastrophic Loss Cutoff (`enableCatastrophicStop`, `catastrophicStopPercent`)**
   - **Trigger:** Unconditional catastrophic emergency floor (default -50% for options, -15% for stocks).
   - **Action:** If all previous technical indicators, ATR stops, and trailing stops fail due to an overnight gap-down or black swan event, Stop 5 unconditionally liquidates the position at market open to prevent total capital wipeout.

---

#### Chapter 6: Notification Triggers, Extended Hours & Historical Backtesting

The final chapter covers system observability, off-hours session execution, and historical strategy validation.

| Configuration Key | JSON / Model Key | Type & Range | Default | UI Mode | Summary |
| --- | --- | --- | --- | --- | --- |
| **Notify on Buy** | `notifyOnBuy` | `bool` | `true` | Quant Pro | Push notification when a new BUY order is placed or staged. |
| **Notify on Take Profit** | `notifyOnTakeProfit` | `bool` | `true` | Quant Pro | Push notification when a position successfully hits profit target. |
| **Notify on Stop Loss** | `notifyOnStopLoss` | `bool` | `true` | Quant Pro | Push notification when a position stops out to contain loss. |
| **Notify on Emergency Stop**| `notifyOnEmergencyStop`| `bool` | `true` | Quant Pro | Critical alert when an automated emergency circuit breaker trips. |
| **Notify on Missed Exit** | `notifyOnMissedExit` | `bool` | `true` | Quant Pro | Alert when a scheduled market-close or bracket exit cannot fill. |
| **Daily Activity Summary**| `notifyDailySummary` | `bool` | `false` | Quant Pro | End-of-day portfolio digest recapping trades, P&L, and win rates. |
| **Pre-Market Trading** | `allowPreMarketTrading`| `bool` | `false` | Quant Pro | Enables order submission during pre-market (4:00 AM – 9:30 AM ET). |
| **After-Hours Trading** | `allowAfterHoursTrading`| `bool` | `false` | Quant Pro | Enables order submission during after-hours (4:00 PM – 8:00 PM ET). |
| **Backtest Initial Capital**| `initialCapital` | `double` ($\ge \$100$)| `\$10,000` | Quant Pro | Starting simulated portfolio equity for historical walk-forward backtests.|
| **Backtest Date Range** | `startDate`, `endDate` | `DateTime` range | 1 Year | Quant Pro | Historical time window over which candles and indicators are simulated. |

##### Extended Hours Trading Guidance
- **Liquidity Risks:** Pre-market (4:00 AM – 9:30 AM ET) and After-Hours (4:00 PM – 8:00 PM ET) sessions suffer from significantly lower market liquidity than regular market hours. Bid-ask spreads are frequently much wider, and market orders are not permitted by brokerages (orders must be submitted as Limit Orders).
- **Pro Tip:** Keep extended hours disabled unless executing earnings announcements on mega-cap equities where high off-hours volume exists.

##### Historical Backtesting Engine
- The built-in backtest runner simulates your exact configured parameters (including dynamic ATR stops, sector limits, and custom indicators) against up to 5 years of historical split- and dividend-adjusted OHLCV price candles.
- Produces institutional metrics: Total Cumulative Return, Annualized Return (CAGR), Sharpe Ratio, Sortino Ratio, Maximum Drawdown (MDD), Win Rate %, and Profit Factor.
- Validate your parameters in the backtester and run 10 sessions in Paper Trading mode before toggling real-money execution.

---

---

## Macro Assessment

The RealizeAlpha system integrates a high-level macroeconomic analysis engine that continuously evaluates broad market conditions. By evaluating market regimes alongside individual stock charts, the agent avoids aggressive buying during broad market downturns and maximizes capital efficiency during healthy bull trends.

### Understanding Market Regimes: Risk-On vs. Risk-Off

To many traders, terms like `RISK_ON` and `RISK_OFF` can sound like financial jargon. In simple terms, market regimes describe the **overall mood and risk appetite of institutional investors** across global markets.

```
       ┌────────────────────────────────────────────────────────┐
       │                 MARKET REGIME SPECTRUM                 │
       ├─────────────────────────┬──────────────────────────────┤
       │  BULLISH / CONSTRUCTIVE │    DEFENSIVE / HIGH RISK     │
       │       [ RISK_ON ]       │         [ RISK_OFF ]         │
       ├─────────────────────────┼──────────────────────────────┤
       │ • Low Volatility (VIX)  │ • High Volatility (VIX Spike)│
       │ • Expanding Breadth     │ • Contracting Breadth        │
       │ • Normal Yield Curve    │ • Inverted Yield Curve       │
       │ • Growth Stocks Lead    │ • Safe Havens Lead (Cash/Gold)│
       │ • Aggressive Entries    │ • Reduced Sizing or Block    │
       └─────────────────────────┴──────────────────────────────┘
                               ▲
                               │
                      [ NEUTRAL / MIXED ]
                      • Diverging signals
                      • Sector rotation
                      • Balanced sizing
```

#### Regime Comparison Matrix

| Market Regime | Friendly Display Title | Market Environment & Asset Flow | Volatility (VIX) | Yield Curve | Automated Trading Behavior |
| --- | --- | --- | --- | --- | --- |
| **`RISK_ON`** | **Bullish / Constructive** | Investors are optimistic. Capital flows freely into equities, technology, and growth stocks. Market breadth is healthy and pullbacks are bought aggressively. | Subdued ($< 18$) | Normal upward slope | **Full Trading Mode:** Operates at 100% configured position size. High confidence setups execute normally across all supported sectors. |
| **`RISK_OFF`** | **Defensive / High Market Risk** | Investors are cautious or fearful. Capital flees risky assets into safe havens (cash, short-term Treasuries, gold, utilities). Market breadth is narrow and volatility is elevated. | Elevated ($> 22$) or spiking | Inverted or rapidly steepening from inversion | **Capital Preservation Mode:** Dependent on configured `macroRiskOffPolicy`: ignores, reduces position size, or completely halts new BUY entries. |
| **`NEUTRAL`** | **Neutral / Transition** | Mixed macroeconomic indicators. Cross-currents exist between strong earnings and inflation fears, or cyclical rotation between sectors without clear broad market leadership. | Moderate ($18 - 22$) | Flat or mixed | **Balanced Stance:** Standard position sizing with standard indicator thresholds. The engine requires normal signal conviction. |

#### What Happens in a `RISK_ON` (Bullish / Constructive) Regime?
- **Economic Backdrop:** Corporate earnings are solid, credit spreads are tight, inflation is predictable, and central bank policy is supportive or neutral.
- **Investor Psychology:** Fear of missing out (FOMO) exceeds fear of loss. Equities and risk-bearing assets outperform fixed income.
- **Trading Implication:** Breakouts tend to follow through, dip-buying strategies succeed, and technical momentum indicators generate fewer false signals. The auto-trading engine executes normal position sizes without artificial headwinds.

#### What Happens in a `RISK_OFF` (Defensive / High Market Risk) Regime?
- **Economic Backdrop:** Heightened geopolitical tension, unexpected interest rate shocks, recessionary warning signs, or liquidity crunches.
- **Investor Psychology:** Preservation of principal is paramount. Liquidity demands spike, leading to broad selling across both winning and losing stocks.
- **Trading Implication:** Breakouts frequently fail into "bull traps", market correlations approach 1.0 (everything falls together), and price swings are erratic. Without risk controls, automated trading systems can suffer rapid drawdown during these regimes.

#### Choosing Your Macro `RISK_OFF` Policy

Under **Agentic Trading Settings → Risk Management**, the **Macro Risk-Off Policy** controls how the auto-trader responds when the macro engine detects a `RISK_OFF` environment:

1. **Ignore (`ignore`)**:
   - *Behavior:* Continues evaluating and executing BUY signals normally, regardless of the macro regime.
   - *Best For:* Systematic strategies with tight, fixed technical stop losses, or long-term swing traders who only care about single-stock chart setups.
2. **Reduce Size (`reduceSize`)** *(Recommended for active traders)*:
   - *Behavior:* Allows high-probability trades to execute, but cuts position sizing by the configured `riskOffSizeReduction` (default 50%). If a normal trade buys 10 shares, it will only buy 5 shares during `RISK_OFF`. In Reasoning mode, Gemini is explicitly notified that downstream risk controls handle position scaling so that strong ideas are not unnecessarily vetoed.
   - *Best For:* Traders who want to stay engaged in the market during choppy periods while actively limiting downside dollar risk.
3. **Block Entries (`blockEntries`)** *(Recommended for conservative traders & beginners)*:
   - *Behavior:* Completely halts all new BUY orders while `RISK_OFF` is active. No new stock positions will be opened. Existing open positions continue to be actively monitored for Stop Loss and Take Profit exits.
   - *Best For:* Capital preservation and peace of mind. Avoids entering new positions during market pullbacks and corrections.

### Core Metrics & Data Ingestion

The macro engine evaluates several quantitative pillars to classify the global regime:

*   **Global Risk Status:** Synthesis of volatility, breadth, and macroeconomic trend into `RISK_ON`, `RISK_OFF`, or `NEUTRAL`.
*   **Yield Curve (10Y - 13W & 10Y - 2Y):** Monitors Treasury spreads for inversions (a classic leading indicator of economic slowdown and recession).
*   **Sector Momentum & Rotation:** Dynamically evaluates relative strength across all 11 GICS sectors to determine which sectors are Bullish (e.g., Technology, Consumer Discretionary) versus Defensive/Bearish (e.g., Utilities, Consumer Staples).
*   **Recommended Asset Allocation:** Provides a reference institutional split between Equity, Fixed Income, Cash, and Commodities tailored to the current point in the economic cycle.

### Integration with Trading Pipelines

*   **Systematic Pipeline:** When evaluating a symbol for trade entry, if `macroRiskOffPolicy` is `blockEntries` and the regime is `RISK_OFF`, the proposal is rejected before order formulation. If `reduceSize` is active, the share quantity is scaled down accordingly.
*   **Agentic Reasoning Pipeline:** The full macro assessment JSON (regime, yield curve, sector momentum) is injected into Gemini's reasoning prompt. Gemini evaluates macro risk as part of its step-by-step institutional synthesis. When `reduceSize` is active, Gemini is informed that risk is managed via position sizing, allowing it to recommend high-conviction ideas without being artificially constrained.
*   **Macro Exit (Stop 4 in Exit Queue):** If `exitOnRiskOff` is enabled, open positions are automatically liquidated if the macro status transitions from `RISK_ON` or `NEUTRAL` into `RISK_OFF` while the trade is active.

---

## User Interface

### Settings Screen

Access via: 
- User Menu → Automated Trading
- App Bar → Auto-trade status badge (when active)

#### Progressive Disclosure UI (Simplified Mode vs. Quant Pro Mode)

`AgenticTradingSettingsWidget` supports a two-tier progressive disclosure experience persisted locally via `SharedPreferences` (`agentic_trading_ui_mode`, exposed via `AgenticTradingProvider.uiMode` / `setUiMode`) with a top `SegmentedButton<AgenticTradingUiMode>` selector:

1. **Simplified Mode (`AgenticTradingUiMode.simplified`, Default):** Rendered via `SimplifiedTradingControlsWidget` (`lib/widgets/simplified_trading_controls_widget.dart`), surfacing 4 essential controls for everyday traders:
   - **Master Control & Emergency Stop:** Primary Auto-Trading toggle, Paper vs. Live mode switcher (with confirmation guardrails), `Require Approval` badge (`AUTO`/`REVIEW`), and an always-available Emergency Stop button (`simplified-emergency-stop-button`).
   - **Strategy Selection:** Curated Strategy Archetypes (`Conservative Core`, `Momentum Breakout`, `Options Income Harvester`, `Reasoning AI Agent`) with walk-forward performance badges, interactive detail bottom sheet dialog (`StrategyArchetypeDetailBottomSheet`), and inline `BETA` card lock indicators (opening the bottom sheet to unlock in Beta Labs when disabled). Tapping any archetype always opens the detail dialog to inspect full parameters and walk-forward statistics before applying or cloning.
   - **Capital Budget Slider:** Continuous slider (`5%–100%` of portfolio equity, `maxPortfolioConcentration`) with horizontally scrollable single-row quick-preset chips (`10%`, `25%`, `50%`, `75%`, `100%`) and an `AccountStore.showBalances`-aware dollar allocation preview.
   - **3-State Risk Comfort Level (`RiskComfortLevel`):** Smoothly tunes `stopLossPercent`, `takeProfitPercent`, `tradeQuantity`, and `riskPerTrade` via `AgenticTradingProvider.applyRiskComfortLevel`:

| Risk Comfort Level | Stop Loss | Take Profit | Trade Quantity | Risk Per Trade |
| :--- | :---: | :---: | :---: | :---: |
| **Conservative** | `3.0%` | `6.0%` | `1` share | `1.0%` |
| **Balanced** | `5.0%` | `10.0%` | `2` shares | `2.0%` |
| **Aggressive** | `10.0%` | `20.0%` | `5` shares | `3.0%` |

   - If custom Quant Pro risk parameters are active that do not match a preset, Simplified Mode displays an informational badge and leaves custom stops untouched unless the user explicitly taps a preset.

2. **Quant Pro Mode (`AgenticTradingUiMode.quantPro`):** Rendered via `QuantProSettingsView` (`lib/widgets/quant_pro_settings_view.dart`), unlocking strategy templates, execution timing and extended-hours controls, Risk Management (including the aligned `Capital Budget (Max Concentration %)` field with live `AccountStore.showBalances`-aware dollar cap helper), sector/correlation/drawdown caps, 5-tier GEX & Dynamic ATR stops, all 19 technical indicator checkboxes, custom indicator formulas, exit strategies, notifications, backtesting, and OEM background execution journals.

**Strict State Preservation:** Switching between Simplified and Quant Pro modes never overwrites or resets underlying `AgenticTradingConfig` / `TradeStrategyConfig` values. Deep links specifying `initialSection` (`entryStrategies` or `riskManagement`) automatically open Quant Pro Mode and scroll to the target section.

**Recent UI Improvements (commit 861f2bc):**
- **Auto-Save**: Settings automatically saved on every change (no manual save button)
- **Countdown Timer**: Real-time countdown to next auto-trade check
- **Enhanced Status**: Daily count, last trade time, next trade time all displayed
- **App Bar Integration**: Status badge in SliverAppBar shows auto-trade active state
- **Better UX**: Cleaner layout, better visual feedback, intuitive controls

**Sections:**
1. **Master Toggle**
   - Enable/disable agentic trading system
   - Shows current status with descriptive subtitle
   - Auto-saves on toggle

2. **Automated Trading**
   - Auto-trade toggle
   - **Real-time countdown timer** (shows seconds until next check)
   - Status indicators (active, daily count, last trade time, next trade time)
   - Emergency stop button with confirmation dialog
   - Auto-saves on toggle

3. **Auto-Trade Configuration**
   - Daily trade limit (auto-saves on change)
   - Cooldown period (auto-saves on change)
   - Max daily loss percentage (auto-saves on change)
   - Take profit percentage (auto-saves on change)
   - Stop loss percentage (auto-saves on change)

4. **Risk Management Rules**
   - Trade quantity
   - Max position size
   - Portfolio concentration limit

5. **Technical Indicators**
   - Individual indicator toggles
   - Inline documentation
   - Configuration parameters (RSI period, SMA periods, etc.)

### Status Indicators

**Auto-Trading Active:**
```
🔄 Auto-trading in progress...
```

**Normal Status:**
```
Daily Trades: 3/5
Last Trade: 2h ago
```

**Emergency Stop:**
```
⚠️ Emergency Stop Activated [Resume]
```

## Integration Points

### Trade Signal Generation
- Backend cron jobs generate signals periodically
- Stored in Firestore `agentic_trading/` collection
- Support for multiple intervals (1d, 1h, 15m)
- Real-time updates via Firestore listeners

### Risk Assessment
- Cloud Function: `riskguardTask`
- Evaluates proposals against portfolio state
- Returns approval/rejection with reasoning

### Brokerage Integration
- Executes approved trades via brokerage service
- Supports multiple brokers (Robinhood, Plaid, Schwab)
- Handles order placement and tracking

## Safety Features

### Market Hours Detection
- **MarketHours Utility**: Centralized DST-aware market hours checking
- Automatic DST adjustment (EDT/EST conversion)
- Only trades during regular market hours (9:30 AM - 4:00 PM ET)
- Weekend trading blocked
- Comprehensive debug logging for troubleshooting
- Used consistently across all providers and widgets

### Rate Limiting
- 2-second delay between trade attempts
- Cooldown period enforcement
- Daily limit caps

### Error Handling
- Graceful degradation on API failures
- Comprehensive error logging
- Analytics tracking for all events

### Audit Trail
- Last 100 trades stored in memory
- Analytics events for all actions
- Timestamps and execution details

## Testing

### Unit Tests
Location: `test/agentic_trading_*_test.dart`

**Test Files:**
1. `agentic_trading_config_test.dart` - Configuration model tests
2. `agentic_trading_provider_test.dart` - Provider logic tests  
3. `agentic_trading_settings_widget_test.dart` - UI widget tests *[NEW]*

**Coverage:**
- Configuration serialization/deserialization
- Backward compatibility with old configs
- State management and change notifications
- Risk control enforcement (limits, cooldowns)
- Emergency stop functionality
- Daily limit tracking
- **Auto-save functionality in settings widget** *[NEW]*
- **Indicator toggle persistence** *[NEW]*
- **UI state updates and validation** *[NEW]*

**Run Tests:**
```bash
# All agentic trading tests
flutter test test/agentic_trading_config_test.dart
flutter test test/agentic_trading_provider_test.dart
flutter test test/agentic_trading_settings_widget_test.dart

# Or run all at once
flutter test test/ --name="agentic"
```

**New Widget Tests (commit 861f2bc):**
- Tests auto-save behavior when toggling indicators
- Validates settings persistence to Firestore
- Tests UI rendering with different provider states
- Validates form field updates and validation

### Integration Testing
Recommended approach:
1. Use paper trading mode
2. Test with small position sizes
3. Monitor execution closely
4. Validate risk controls
5. Test emergency stop

## Security Considerations

### Configuration Storage
- User configs stored in Firestore
- Access controlled by security rules
- No sensitive API keys in client code
- **Updated Firestore rules** for `automated_buy_trades` collection *[NEW]*

### Trade Execution
- Server-side validation required (initiateTradeProposal, riskguardTask)
- Risk assessment before execution
- Emergency stop accessible from client
- All trades authenticated and authorized

### Firebase Security Rules
```
// New rules for automated buy trades (commit 861f2bc)
match /users/{userId}/automated_buy_trades/{tradeId} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}
```

### Rate Limiting
- Backend rate limiting on Cloud Functions
- Client-side cooldowns (2-second delay between trades)
- Daily limits prevent runaway trading
- Market hours enforcement prevents off-hours trading

## Best Practices

### Initial Setup
1. Start with conservative limits (1-2 trades/day)
2. Use longer cooldown periods (60+ minutes)
3. Set tight loss limits (1-2%)
4. Monitor closely for first week

### Risk Management
1. Never risk more than 2% of portfolio per day
2. Keep position sizes small relative to portfolio
3. Maintain portfolio diversification
4. Use emergency stop if uncertain

### Monitoring
1. Check trade history daily
2. Review rejected proposals
3. Adjust indicators based on performance
4. Monitor analytics events

### Emergency Procedures
1. **Market Volatility**: Activate emergency stop
2. **System Issues**: Disable auto-trade, investigate
3. **Unexpected Behavior**: Stop immediately, review logs

## Analytics Events

The system logs the following events:

- `agentic_trading_toggled`: Master switch changed
- `agentic_trading_auto_executed`: Auto-trade completed
- `agentic_trading_auto_error`: Auto-trade failed
- `agentic_trading_auto_failed`: System error
- `agentic_trading_emergency_stop`: Emergency stop activated
- `agentic_trading_emergency_stop_deactivated`: Resumed
- `agentic_trading_trade_approved`: Manual proposal approved
- `agentic_trading_trade_rejected`: Manual proposal rejected

## Future Enhancements

### Planned Features
1. **Push Notifications**: Alert on auto-trade executions
2. **Performance Tracking**: Win/loss ratio, P&L analytics
3. **Backtesting**: Historical strategy simulation
4. **Machine Learning**: Adaptive indicator weighting
5. **Advanced Orders**: Stop-loss, take-profit automation
6. **Portfolio Rebalancing**: Automatic position adjustment

### Under Consideration
- Multi-asset support (options, crypto, futures)
- Strategy templates (conservative, aggressive, balanced)
- Social trading integration (copy successful traders)
- Custom indicator creation
- Strategy sharing with investor groups

## Troubleshooting

### Auto-Trade Not Executing

**Check:**
1. Is `autoTradeEnabled` true in settings?
2. Is emergency stop activated?
3. Is market currently open?
4. Have you reached daily trade limit?
5. Is cooldown period active?
6. Are there any BUY signals available?

**Debug Steps:**
1. Check provider state: `provider.isAutoTrading`
2. Review `_canAutoTrade()` conditions
3. Verify trade signals: `provider.tradeSignals`
4. Check analytics logs for error events

### Trades Being Rejected

**Common Causes:**
1. Risk assessment failure (position too large)
2. Portfolio concentration limit exceeded
3. Insufficient funds
4. Invalid price data
5. Brokerage API errors

**Resolution:**
1. Review `lastAssessment` for rejection reason
2. Adjust position sizes or limits
3. Check brokerage account status
4. Verify market data availability

### Emergency Stop Not Working

**Verification:**
1. Check `provider.emergencyStopActivated` state
2. Verify UI shows emergency status
3. Test with manual toggle in settings

**If Issue Persists:**
1. Restart app
2. Check Firestore config sync
3. Review error logs

## API Reference

### AgenticTradingProvider Methods

#### `autoTrade({required Map<String, dynamic> portfolioState, required brokerageUser, required account, required brokerageService, required instrumentStore})`
Executes automatic trading based on current signals and places orders through the brokerage.

**Parameters:**
- `portfolioState`: Current portfolio state for risk assessment
- `brokerageUser`: BrokerageUser instance for authentication
- `account`: Account to trade in
- `brokerageService`: IBrokerageService instance for order execution
- `instrumentStore`: InstrumentStore for fetching instrument data

**Returns:** `Map<String, dynamic>`
- `success`: bool - Whether any trades were executed
- `tradesExecuted`: int - Number of trades completed
- `message`: String - Status message
- `trades`: List - Details of executed trades including order responses

#### `activateEmergencyStop()`
Immediately halts all auto-trading.

#### `deactivateEmergencyStop()`
Resumes auto-trading functionality.

#### `loadConfigFromUser(dynamic agenticTradingConfig)`
Loads configuration from User model.

#### `updateConfig(Map<String, dynamic> newConfig, DocumentReference userDocRef)`
Updates configuration and saves to Firestore.

#### `monitorTakeProfitStopLoss({required List positions, required brokerageUser, required account, required brokerageService, required instrumentStore})`
Monitors positions and executes take profit or stop loss orders.

**Parameters:**
- `positions`: List of current InstrumentPosition objects
- `brokerageUser`: BrokerageUser instance for authentication
- `account`: Account to trade in
- `brokerageService`: IBrokerageService instance for order execution
- `instrumentStore`: InstrumentStore for fetching instrument data

**Returns:** `Map<String, dynamic>`
- `success`: bool - Whether any exits were executed
- `exitsExecuted`: int - Number of exit orders placed
- `message`: String - Status message
- `exits`: List - Details of executed exits with P/L% and reason

**Process:**
1. Calculates P/L percentage for each position
2. Triggers SELL when P/L >= takeProfitPercent
3. Triggers SELL when P/L <= -stopLossPercent
4. Places orders and tracks exits

### Static Methods

#### `TradeSignalsProvider.indicatorDocumentation(String key)` *[MOVED]*
Returns documentation for a given indicator.

**Note:** This method was moved from AgenticTradingProvider to TradeSignalsProvider in commit 861f2bc as part of the architecture refactoring.

**Parameters:**
- `key`: Indicator identifier (e.g., 'priceMovement', 'momentum')

**Returns:** `Map<String, String>`
- `title`: Display name
- `documentation`: Detailed description

**Usage:**
```dart
final docInfo = TradeSignalsProvider.indicatorDocumentation('priceMovement');
print(docInfo['title']);         // "Price Movement"
print(docInfo['documentation']); // Full description
```

## Support

For issues or questions:
1. Review this documentation
2. Check unit tests for examples
3. Consult `multi-indicator-trading.md` for signal details
4. Review Firebase Analytics for system events
5. File a GitHub issue with detailed logs

## Integration Examples

### Basic Setup (New Architecture)

**In main.dart:**
```dart
MultiProvider(
  providers: [
    // New: TradeSignalsProvider for signal management
    ChangeNotifierProvider(
      create: (context) => TradeSignalsProvider(),
    ),
    // Existing: AgenticTradingProvider for execution
    ChangeNotifierProvider(
      create: (context) => AgenticTradingProvider(),
    ),
    // ... other providers
  ],
  child: MaterialApp(/* ... */),
)
```

### Fetching Trade Signals (TradeSignalsProvider)

**In any widget:**
```dart
// Access the provider
final tradeSignalsProvider = Provider.of<TradeSignalsProvider>(context);

// Fetch signals for a symbol
await tradeSignalsProvider.fetchTradeSignals(
  symbol: 'AAPL',
  interval: '1d',
  userDocRef: userDocRef,
);

// Access the signals
final signals = tradeSignalsProvider.signals;
```

### Executing Auto-Trade (AgenticTradingProvider)

**From navigation widget (timer integration):**
```dart
final agenticProvider = Provider.of<AgenticTradingProvider>(context, listen: false);
final accountStore = Provider.of<AccountStore>(context, listen: false);
final instrumentStore = Provider.of<InstrumentStore>(context, listen: false);

final result = await agenticProvider.autoTrade(
  portfolioState: {
    'equity': portfolioStore.equity,
    'cash': accountStore.items.first.portfolioCash,
    // ... other portfolio data
  },
  brokerageUser: currentUser,
  account: accountStore.items.first,
  brokerageService: brokerageService,
  instrumentStore: instrumentStore,
  userDocRef: userDocRef,  // For Firebase persistence
);
```

### Monitoring TP/SL

**From navigation widget (timer integration):**
```dart
final positions = portfolioStore.positions;

final result = await agenticProvider.monitorTakeProfitStopLoss(
  positions: positions,
  brokerageUser: currentUser,
  account: accountStore.items.first,
  brokerageService: brokerageService,
  instrumentStore: instrumentStore,
  userDocRef: userDocRef,  // For Firebase persistence
);
```

### Checking Market Hours

**Using MarketHours utility:**
```dart
import 'package:robinhood_options_mobile/utils/market_hours.dart';

if (MarketHours.isMarketOpen()) {
  // Market is open, proceed with trading
  print('✅ Market is open');
} else {
  // Market is closed
  print('❌ Market is closed');
}
```

### Settings Widget Integration

**Navigate to settings:**
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => AgenticTradingSettingsWidget(
      user: currentUser,
      userDocRef: userDocRef,
    ),
  ),
);
```

**Settings now auto-save** - no manual save button needed. Every change is persisted immediately to Firestore.

### SliverAppBar Status Badge

**The refactored SliverAppBar now shows auto-trade status:**
```dart
// Automatically displays when auto-trading is active
// Shows countdown timer
// Tapping navigates to settings
// No manual integration needed - built into SliverAppBar
```

## Version History

- **v1.7** (2026-06-11): Chat Integration & Selected Account Syncing
  - **In-App Chat Integration**: Merged the conversational Vertex AI models with native execution support using parsed standard proposal syntax structures.
  - **Responsive Layout Design**: Handled layout constraints inside the main overview sheets and the proposal tiles, incorporating text wrap dynamics to clear collision errors.
  - **Multi-Account Selector Support**: Extended target API wrappers with fallback tries to handle nested multiple portfolios, adding selected account trackability inside the global `AccountStore` with reactive sync loops.
  - **Conversational Assistant Guides**: Redesigned help menu pages inside the chat module to focus on assistant proposal cards, prompt triggers, account scopes, and native reviews.

- **v1.6** (2026-01-24): Strategy & Signal Enhancements
  - **Trade Signals Widget**: Dedicated interface for filtering and viewing signals.
  - **Strategy Templates**: Improved management and filtering by strategy configuration.
  - **Premium Access**: Integration with In-App Purchases for premium signal features.
  - **Custom Benchmarks**: Support for custom benchmarking in Portfolio Analytics.

- **v1.5** (2025-12-30): Intraday Data & Sorting Fixes
  - Enhanced market data fetching logic to ensure sufficient historical data for MACD.
  - Improved trade signal sorting functionality and reliability.

- **v1.5** (2026-01-29): Performance Optimization & Flow Filtering
  - Enhanced paper mode filtering in performance widget
  - Optimized backend cron jobs using listDocuments
  - Explicit paper trade indication in notifications

- **v1.4** (2025-12-19): Signal Performance Metrics
  - Added Signal Strength Performance Card (Win Rate by strength bucket)
  - Added Individual Indicator Performance Card (Win Rate by indicator)
  - Enhanced analytics calculation logic
  - Improved performance dashboard UI

- **v1.3** (2025-12-13): Advanced analytics and paper trading
  - Added Paper Trading Mode for risk-free strategy testing
  - Added 9 comprehensive analytics cards in Performance Widget
  - Added advanced metrics: Sharpe Ratio, Profit Factor, Expectancy
  - Added risk metrics: Win/Loss Streaks, Max Drawdown
  - Added Performance by Time of Day analysis
  - Added Performance by Indicator Combo tracking
  - Added trailing stop loss support
  - Added filter chips for paper vs real trade performance
  - Enhanced trade records with enabledIndicators snapshot
  - Color-coded performance indicators (green/orange/red)

- **v1.2** (2025-12-10): Architecture refactoring (commit 861f2bc)
  - Added TradeSignalsProvider for centralized signal management
  - Added MarketHours utility for DST-aware market checks
  - Enhanced settings UI with auto-save and countdown timer
  - Added unit tests for settings widget
  - Updated Firestore security rules
  - Integrated status display in SliverAppBar
  - Improved provider separation and modularity

- **v1.1** (2025-12-09): Trade-level tracking
  - Replaced symbol-based tracking with trade records
  - Added Firebase persistence for automated trades
  - Accurate P/L calculations using entry prices
  - Support for mixed manual + automated positions

- **v1.0** (2025-12-08): Initial implementation
  - Core auto-trade logic
  - Risk management controls
  - Settings UI
  - Unit tests
