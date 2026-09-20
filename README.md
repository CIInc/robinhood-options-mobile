# RealizeAlpha

RealizeAlpha is a professional-grade Flutter mobile app for multi-account brokerage management (Robinhood, Schwab, Fidelity), featuring AI-powered trade signals, automated agentic trading, and institutional-grade options analytics including Gamma Exposure (GEX) and institutional flow tracking.

## Getting Started

See our [docs](https://ciinc.github.io/robinhood-options-mobile/) for use cases and application requirements.

## Features

*   **Brokerage Integration:** Connects securely to brokerage accounts (e.g., Robinhood) to fetch real-time data. **New:** Native Robinhood first-party API extensions for institutional hedge fund holdings, officer/director insider trades, retail order flow, short interest/borrow availability, unified accounts margin health, stock lending payments (SLIP), high-yield cash sweeps, ACH transfers & banking, 1099 tax documents & statements, corporate action split adjustments, Say Technologies shareholder Q&A, and Traditional/Roth IRAs (`ira_traditional`, `ira_roth`). **New:** Fidelity Account data import via CSV (positions & history) and Schwab integration enhancements. **Multi-Account Aggregation & Persistent Swapping:** View and manage positions across multiple accounts simultaneously with aggregate trading controls, and set a persistent active account inside the app with immediate workspace synchronization.
*   **Model Context Protocol (MCP) Client:** Secure, local MCP Dart client enabling conversational AI agents to discover, inspect, and execute real-time brokerage actions (fetching balances, positions, orders, or watchlists) through local model-called tools directly within the device.
*   **Options Chain Viewing:** Displays detailed options chains for various underlying assets.
*   **Historical Data Analysis:** Fetches and visualizes historical price data for instruments. **New:** Benchmark Chart with Date Range Selection (1W, 1M, 3M, YTD, 1Y, ALL) for performance comparison. Supports major indices including S&P 500, Nasdaq 100, Dow Jones, and Russell 2000 (IWM).
*   **Market Intelligence:**
    *   **[Whale Watch Tracker](docs/whale-watch.md):** Track insider transactions and institutional ownership. Snapshot comparisons distinguish measured accumulation from current-holdings fallback rankings.
    *   **Insider Activity:** Track officer and director trading with detailed Buy/Sell transaction logs.
    *   **Institutional Ownership:** Monitor top institutional holders and position changes to gauge "smart money" sentiment.
    *   **Twelve Data Integration:** Integrated Twelve Data API for real-time options and market data fetching, including support for `TWELVE_DATA_API_KEY` secret management.
    *   **Options Flow Analysis:** Real-time detection of significant option trades with "Whale", "Sweep", and "Steamroller" flags, plus trade-specific interpretation checklists and verification guidance for every supported flag.
    *   **[Gamma Exposure (GEX) Analysis](docs/gamma-exposure-analysis.md):** Market maker positioning tracker featuring portfolio-wide net/gross gamma and concentration, actionable transition levels, volatility-regime context, interactive strike charts, a Market Maker Pinning Gauge, Spot-Shift sensitivity, and a real-time on-device Black-Scholes fallback engine in Dart.
    *   **[Instrument Notes](docs/instrument-notes.md):** Private, persistent trading journal per instrument with **Markdown support** and **AI-Assisted Drafting**.
*   **[Progressive Portfolio](docs/portfolio-redesign.md):** Decision-focused overview answering what happened and what needs attention through hero statistics, an account-aware Action Center, movers, and capped holdings summaries. Dedicated Performance, Positions, Risk, Insights, Taxes, and Strategies sections share one analytics controller with custom benchmarks, health and ESG scoring, risk metrics, AI insights, correlation analysis, **Portfolio Stress Testing**, **Aggregate Option Greeks**, **Tail Risk & Liquidity Scoring**, and CSV export.
*   **Portfolio Allocation Visualization:** Interactive carousel of pie charts showing portfolio allocation breakdown across all 7 asset classes (Stocks, Options, Crypto, Forex, Futures, Fixed Income, and Cash), individual positions (top 5 holdings), sector, and industry. Features bidirectional highlighting between chart slices and legend entries with visual page indicators. **New:** Multi-asset allocation modeling with dedicated support for Fixed Income instruments (treasury ETFs, bonds, etc.), currency pairs, and futures, plus an All-Weather allocation preset.
*   **Stock Screener:** Advanced stock filtering by sector, market cap, P/E ratio, dividend yield, price, and volume with quick presets, sorting, custom criteria, and a seeded Firestore instrument universe.
*   **[Event Study Analyzer](docs/event-study.md):** Measure asset, benchmark, and abnormal returns around earnings, FDA decisions, product launches, guidance changes, and other events with configurable trading-day windows and rolling risk statistics.
*   **Trade Signals:** AI-powered agentic trading with 19-indicator correlation system (Price Movement, RSI with divergence, Market Direction, Volume, MACD, Bollinger Bands, Stochastic, ATR, OBV, VWAP, ADX, Williams %R, Ichimoku Cloud, CCI, Parabolic SAR, ROC, Chaikin Money Flow, Fibonacci Retracements, Pivot Points) for automatic trade detection and execution. Fully autonomous operation with 5-minute periodic checks, trade-level take profit/stop loss tracking, trailing stops, and Firebase persistence. User-configurable settings with per-indicator enable/disable controls and in-app documentation widget. Supports both daily and intraday signals (15-minute, hourly, and daily intervals) with real-time Firestore updates, market status indicators, **weighted signal strength (0-100)**, sparkline previews, and push notifications. Includes comprehensive performance analytics with 9 analytics cards tracking Sharpe ratio, profit factor, expectancy, streaks, drawdown, time-of-day performance, indicator combination effectiveness, and symbol-specific win rates. **New:** Signals now include **date field metadata** and support advanced sorting in Firestore. **New:** Auto-trade history loading from Firestore ensuring cross-session persistence. Paper Trading Mode enables risk-free strategy testing with simulated order execution. **Advanced Macro Assessment:** AI-powered engine analyzing 19 institutional indicators (VIX, MOVE, Yield Curve, Breadth, Credit Spreads, etc.) to determine the global **Risk Regime** (RISK_ON, RISK_OFF, NEUTRAL). Features a dedicated dashboard with heatmaps, weighted scoring (0-100), detailed indicator analysis, and regime-based strategy guidance. **New:** Advanced filtering by Signal Strength (Strong/Moderate/Weak) and 4-way Indicator states (Off/BUY/SELL/HOLD) with server-side optimization. **New:** Advanced Risk Controls (Sector Limits, Correlation Checks, Volatility Filters, Drawdown Protection) and Order Approval Workflow. **New:** Custom Indicators support and ML-powered Signal Optimization. **New:** Advanced Exit Strategies (Technical Exits) including **Gamma Exposure (GEX)**, RSI overbought, and Signal Strength decay filters. **New:** Professional Trading Strategy Templates (GEX Mean Reversion, Trend Accelerator, Scalp). **New:** Emergency Stop functionality (long-press auto-trade toggle) and improved status display. **New:** Enhanced "Processed Signals" UI with detailed inspection dialogs and robust signal deduplication for improved reliability. **New:** Dedicated **Trading Strategies Page** for managing templates and **Entry Strategies UI** for configuration. **New:** Dedicated **Trade Signals Widget** for focused signal exploration and **In-App Purchases** integration for premium access. **New (v0.37.0):** **Agentic Reasoning Mode** enabling deep, multi-step analysis and institutional-grade GEX orchestration for signal generation.
*   **Privacy & Navigation:** **Balance Visibility Toggle** to mask sensitive P&L, equity, chart axes, tooltips, and portfolio-chart annotations in public settings. **Scroll-to-Top** navigation across all major list views for streamlined browsing.
*   **Paper Trading Dashboard:** Comprehensive simulator for risk-free trading practice. **New:** Enhanced with **AI Portfolio Analysis** for instant insights on performance and risk, plus interactive **Asset Allocation** pie charts (Stocks/Options/Fixed Income/Cash) to visualize capital distribution.
*   **[Sentiment Analysis](docs/sentiment-analysis.md):** Retained for evolution into a distinct news, social, and community Alpha Feed; its aggregate market card remains hidden so Macro Assessment is the single risk-regime score.
*   **[AI Trading Coach](docs/ai-trading-coach.md):** Your personal trading mentor. Analyzes your trading behavior, tracks discipline with **Streak Tracking**, and provides actionable feedback. Features **Session Journaling**, **Challenge Adherence Verification**, **Hidden Risk Detection**, and a real-time **Market Assistant** chat for instant insights.
*   **Expanded Technical Indicators:** Now supports 19 indicators including Pivot Points, ROC, Chaikin Money Flow, and Fibonacci Retracements, fully integrated into charts and the strategy engine. Charts now feature TTM Squeeze visualization.
*   **Instrument Chart Indicators:** Interactive instrument charts now feature configurable overlays for SMA (10, 20, 50, 200), EMA (12, 26), VWAP, and Bollinger Bands. Toggle candles, volume, and legend visibility with persistent settings.
*   **Backtesting Interface:** Test trading strategies on historical data using the same 15-indicator system as live trading. Configure symbols, date ranges, intervals, and risk parameters. Analyze comprehensive metrics including Sharpe ratio, max drawdown, win rates, and profit factors. **New:** Advanced filtering options for backtest results (by outcome, direction, etc.) and improved UI layout. View trade-by-trade breakdowns with interactive equity curves, save reusable configuration templates, and compare multiple backtest results. Supports daily, hourly, and 15-minute intervals with template management and result export.
*   **[Alpha Factor Discovery](docs/alpha-factor-discovery.md):** Research engine to discover predictive alpha factors (RSI, Moving Averages, Volatility, etc.) by analyzing their correlation with future returns. Features Information Coefficient (IC) analysis, symbol breakdowns, and global stability metrics (ICIR).
*   **AI-Powered Insights & Local MCP Tooling:** Leverages Generative AI (upgraded to **Gemini 3.1 Flash-Lite** for lowest token cost, low latency, and high-throughput execution) to provide analysis on market data (e.g., chart trends) with personalized investment profile integration. Now includes **Local Model Context Protocol (MCP) tool support** allowing direct, real-time brokerage queries, **Challenge Adherence Verification** to track progress on coaching tasks, and **Hidden Risk Detection** for deeper portfolio safety analysis.
*   **Generative Actions:** Context-aware AI actions and insights integrated directly into the UI for streamlined decision-making.
*   **Watchlist Management:** Create and manage custom watchlists, add/remove instruments, and view real-time data for tracked assets. Now features **Watchlist Streaming** for real-time updates directly in the search interface.
*   **[Investor Groups 2.0](docs/investor-groups-2.md):** Create and join investor groups to share portfolios and collaborate with other investors. Includes comprehensive member management with invitation system, admin controls for promoting/demoting members, and direct portfolio viewing for private group members. Features real-time user search and 3-tab admin interface (Members, Pending, Invite). **New (v0.46.0):** **Group Activity Feed** with real-time trade event broadcasting, type/member filtering, privacy controls (amount masking, anonymity), and trade detail sheets. **Group Chat** with Firestore live streaming and unread badges. **Shared Analysis Boards** with structured investment theses, automated risk/reward and return calculations, like counters, and threaded comments. **Verified Track Records** with dynamic performance audits and leader tier badges. **Group Watchlists** and **Group Performance Analytics** for visual leaderboards.
*   **Copy Trading:** Per-group settings to copy filled stock/ETF and option trades from a selected member with immediate manual execution via brokerage API, quantity/amount limits, audit trail in `copy_trades`, and push notifications. Features a dedicated **Copy Trading Dashboard** with trade history, filtering, and a request approval workflow. Includes **Inverse Copying** (contrarian mode) and **Exit Strategies** (Take Profit/Stop Loss) for better risk management. Auto-execute supported. **New (v0.46.0):** High-performance trigger handlers caching source user lookups to eliminate N+1 Firestore queries across copying group members.
*   **Futures Positions:** Live futures position enrichment with contract & product metadata (root symbol, expiration, currency, multiplier) plus real-time quote integration. Now features **Historical Data Visualization**, **margin requirement calculations**, and calculations for **Open P&L, Day P&L, and Realized P&L** for comprehensive position tracking. Contract roll detection remains planned.
*   **Futures Auto-Trading:** Automated futures strategy execution with configurable settings, performance tracking, activity logs, and emergency stop controls.
*   **[Crypto Trading](docs/crypto-trading.md):** Dedicated widgets for placing and managing crypto orders, integrated into the main trading interface. **New:** Modernized Forex & Crypto Instrument View with a technical analysis summary card, interactive modal bottom sheet indicator breakdown, candlestick charts, preset tools menu, and haptic date filter chips.
*   **[Forex Trading](docs/forex-trading.md):** Comprehensive currency pair trading (EUR/USD, USD/JPY, GBP/USD, etc.) with standardized lot sizing (Micro 1k, Mini 10k, Standard 100k), Stop orders, live pip value calculations, and simulated Paper/Demo trading support.
*   **[Carry Trade Optimizer](docs/carry-trade-optimizer.md):** Advanced quantitative tool analyzing global interest rate differentials, monitoring 10 central bank benchmark policy rates, calculating daily rollover swap income, ranking currency pairs by Carry-to-Risk ratio, detecting carry unwind risks, and optimizing multi-funding currency baskets.
*   **[Robinhood Market Intelligence](docs/index.md#robinhood-market-intelligence):** First-party instrument research covering short float and live borrow availability, retail order flow, insider activity, and institutional hedge fund sentiment.
*   **[Curated Screener Presets & Legend Layouts](docs/screener-presets-and-legend-layouts.md):** Browse Robinhood's server-side screener presets and retrieve saved Legend layouts; the full Legend workspace UI remains planned.
*   **[Trading Psychology & Emotion Journal](docs/ai-trading-coach.md#8-emotion-tracking--mindset-journal):** Track emotional check-ins, behavioral biases, trading patterns, and psychology scores alongside AI coaching.
*   **[Unified Risk & Margin Health](docs/margin-health-and-collateral.md):** Real-time maintenance buffer tracking, segregated buying powers (equities, options, crypto), locked collateral breakdown, FINRA Rule 4210 guidance, and Action Center margin alerts.
*   **[Margin Calls & Financing Costs](docs/margin-calls-and-financing.md):** Real-time margin call deficit tracking and resolution workflows (`/margin/calls/`) with monthly margin interest debit history and borrowing APR transparency (`/cash_journal/margin_interest_charges/`).
*   **[Instrument-Specific Buying Power & Trade Warnings](docs/instrument-buying-power-and-warnings.md):** Real-time buying power per instrument (`/accounts/{account}/instrument_buying_power/{id}/`) with margin requirement tags (50% Marginable, 100% Cash Required), short-selling limits, and regulatory trade warnings (`/instruments/{id}/v2/warnings/`).
*   **[Options Collateral & Tier Upgrades](docs/options-collateral-and-tier-upgrades.md):** Chain-level cash and equity collateral breakdown (`/options/chains/{id}/collateral/`) and upgrade eligibility (`/options/should_show_options_upgrade_on_sdp/`) with interactive metrics and Level 3 upgrade application.
*   **[Combo Orders (Stock + Option Packages)](docs/combo-orders.md):** Execution, tracking, and cancellation for multi-leg equity and option packages (Covered Calls, Collars, Married Puts, Straddles, Spreads) via `/combo/orders/`.
*   **[Instrument Previous Positions & Cost Basis Lookback](docs/instrument-cost-basis-lookback.md):** Historical trading cycles and round-trip performance analysis reconstructed via FIFO lot matching directly from filled orders, with win rates, holding period metrics, and execution spread bars.
*   **[Stock Lending Program (SLIP) & Cash Sweeps](docs/stock-lending-and-cash-sweeps.md):** Track loaned securities, earned yield payments, 102% cash collateral backing, and agreement eligibility (`/accounts/stock_loan_payments/`, `/slip/eligibility/`) alongside high-yield cash sweeps APY rate monitoring with multi-bank FDIC insurance and interactive yield projections (`/accounts/sweeps/interest/`).
*   **[Banking, ACH Transfers & Linked Accounts](docs/banking-and-transfers.md):** Complete ACH transfer tracking (deposits, withdrawals, clearing timelines, and cancellation) alongside linked bank accounts with verification status and primary designations (`/ach/transfers/`, `/ach/relationships/`).
*   **[Tax Documents, Account Statements & ADR Fees](docs/tax-documents-and-statements.md):** In-app download and review of Form 1099 tax packages, monthly account statements, trade confirmations, ADR pass-through fee tracking, and foreign tax withholding treaty rates (`/documents/`, `/corp_actions/adr_fees/`, `/tax_info/`).
*   **[Corporate Action Splits & Cash-in-Lieu](docs/corporate-actions-and-stock-splits.md):** Comprehensive tracking of stock splits, reverse splits, adjusted cost basis formulas, and fractional share cash-in-lieu payments with Form 1099-B tax reporting transparency (`/corp_actions/v2/split_payments/`).
*   **[Shareholder Say Q&A Engagement](docs/shareholder-say-qa.md):** Verified shareholder Q&A viewing, question submission, and share-weighted voting for upcoming earnings calls and shareholder meetings via Say Technologies (`/instruments/{id}/qa/events-section/`).
*   **[Multi-Account, Retirement & Connected Agents](docs/multi-account-and-retirement.md):** Native support for Traditional/Roth IRAs (`ira_traditional`, `ira_roth`), annual IRS contribution limits and Robinhood Gold match calculations (`/retirement/history/`), spending accounts (`/rhy/accounts/`), connected external OAuth agents (`/oauth2/list_external_tokens/`), and Midlands Notification Center (`/midlands/notifications/stack/`, `/inbox/threads/`).
*   **[Schwab Integration](docs/schwab-integration.md):** OAuth account linking, portfolio and order history, stock and option order placement, multi-leg option order support, robust API response parsing, and **Real-Time WebSocket Streamer (`wss://streamer-api.schwab.com/ws`)** delivering sub-second streaming quotes (`LEVELONE_EQUITIES`), live option market data & Greeks (`LEVELONE_OPTIONS`), account/order activity notifications (`ACCT_ACTIVITY`), chart candle updates (`CHART_EQUITY`), futures & forex feeds, and connection watchdog auto-reconnect.
*   **[Option Chain Screener](docs/option-strategy-builder.md#option-chain-screener):** Advanced filtering capabilities for option chains including Delta, Theta, Gamma, Vega, Implied Volatility, and more. Features AI-powered "Find Best Contract" suggestions based on risk tolerance and strategy.
*   **[Options Flow Analysis](docs/options-flow-analysis.md):** Track institutional sentiment with real-time monitoring of large option orders (sweeps, blocks), unusual volume detection, and dark pool activity analysis. Includes 30+ smart flags, 0DTE/1DTE expiration filters, alerts, and structured guidance that explains each flag, why the trade triggered it, and what to verify before acting.
*   **[Strategy Builder](docs/option-strategy-builder.md#multi-leg-strategy-builder):** Multi-leg options strategy builder supporting Spreads, Straddles, Iron Condors, and custom combinations with visual payoff diagrams and risk/reward analysis.
*   **[Options Strategy Roll Assistant](docs/options-strategy-roll-assistant.md):** 1-tap rolling wizard for covered calls, cash-secured puts, long options, and vertical spreads with automated net credit/debit calculation, updated breakeven projections, Greeks shift comparison ($\Delta$, $\Gamma$, $\theta$, $\nu$, IV), 1-tap roll presets (Roll Out, Roll Up & Out, Roll Down & Out, Custom), and multi-leg atomic order execution across paper and live trading.
*   **[Multi-Leg Options Defense & Roll Playbook](docs/options-defense-and-roll-playbook.md):** Automated threat detection engine and tactical advisory playbook for tested options positions, short legs, and credit spreads with 1-tap transfer to the Roll Assistant.
*   **[Landscape Charting & Multi-Column Matrix View](docs/landscape-chart-matrix.md):** Full-width widescreen charting mode with collapsible multi-leg order entry for tablet and mobile landscape orientations, featuring live net debit/credit pricing and closed-form risk/reward bounds.
*   **[iOS Live Activities & Dynamic Island Widget](docs/ios-live-activities-and-dynamic-island.md):** Real-time lock screen widget and Dynamic Island presentation for active option positions, mark price updates, P&L status, and intraday 0DTE trailing stop alerts.
*   **[Offline Mode & Resilient Caching](docs/offline-mode-and-resilient-caching.md):** Encrypted local cache for portfolio holdings, accounts, watchlists, quotes, and AI trade signals with background sync, staleness thresholds, and contextual status banners.
*   **[Advanced Order Types](docs/advanced-order-types.md):** Support for Trailing Stop, Stop-Limit, and Time-in-Force (GTC, IOC, etc.) orders for both stocks and options. Also includes **Order Templates** to save and reuse complex order configurations.
*   **[Pattern Day Trader (PDT) Protection & Counter](docs/pdt-protection.md):** Real-time rolling 5-business-day equity and option day-trade counter, visual 4-segment meter, FINRA Rule 4210 $25,000 equity threshold tracking with deficit calculations, Robinhood Day Trade Protection monitoring, and automated Action Center risk alerts.
*   **[RiskGuard](docs/risk-guard.md):** Advanced risk validation for manual and automated trading. Enforces portfolio safety rules (concentration, sector limits) with warning dialogs and override capabilities for manual trades. Now includes **Dynamic Position Sizing** to automatically calculate trade size based on risk parameters, and support for **skipRiskGuard** in automated strategies.
*   **[Autonomous Account Risk Circuit Breakers & Tilt Guardrails](docs/risk-circuit-breakers.md):** User-configurable automated account protection against emotional and revenge trading. Enforces hard stops based on daily maximum dollar and percentage loss limits, peak-to-trough portfolio drawdown, consecutive losing trade streaks, and minimum margin buffer requirements. Actively blocks order placement during mandatory cooling-off periods with live Action Center alerts and test trip simulation.
*   **Security:** Integrated **Biometric Authentication** (FaceID/TouchID) for secure app access and strictly protected brokerage interactions.
*   **[Trade Signal Notifications](docs/trade-signal-notifications.md):** Configurable push notifications for trade signals with granular filtering by signal type (BUY/SELL/HOLD), symbol, interval, and confidence threshold. Includes rich notification content and deep linking for immediate analysis. **New:** **Rich Push Notifications** for Agentic Trading, Chat, and Copy Trading with actionable data and expanded context. **New:** Enhanced with Firestore storage and advanced search/filter functionality.
*   **[Custom Alerts](docs/custom-alerts.md):** Configurable price and event-based alerts for stocks, options, crypto, and portfolio events with real-time notifications.
*   **[Tax Optimization & Loss Harvesting Suite](docs/tax-loss-harvesting.md):** Comprehensive tax-management engine featuring **Automated Tax Loss Harvesting** with correlated replacement suggestions (SPY ↔ VOO/IVV, QQQ ↔ QQQM, NVDA ↔ AMD/SMH), a **Rolling 30-Day Wash Sale Window Tracker** with disallowed loss adjustments, **[Capital Gains & Holding Period Breakdown](docs/capital-gains-breakdown.md)** with duration countdown timers and tax liability projections, **[Specific Tax Lot Matching](docs/tax-lot-matching.md)** (FIFO, LIFO, HIFO, Low Cost, Tax Minimizer, and custom lot allocation) at order entry, and **[IRS Form 8949 / Schedule D Reconciliation](docs/form-8949-export.md)** with CSV export.
*   **[Portfolio Rebalancing](docs/portfolio-rebalancing.md):** Interactive tool to manage asset and sector allocation with visual drift analysis, precision target editing, and actionable buy/sell recommendations. **New:** **[AI Asset Allocation](docs/ai-asset-allocation.md)** providing personalized portfolio weighting recommendations based on user risk profiles. Enhanced UI with dual views (Asset/Sector), smart presets, drift indicators, theme-aware charts, plus a scheduled rebalancing engine with macro guidance, fixed income presets, and notifications.
*   **[Option Instrument Position UI](docs/ui-improvements.md#option-instrument-position-ui):** Redesigned position card in `OptionInstrumentWidget` with clear ITM/OTM badges, large P&L display, and comprehensive statistics grid (IV, Greeks, Break-even, etc.) for better position management.
*   **[Home Screen Widgets](docs/home-widgets.md):** iOS Home Screen widgets providing quick access to portfolio data, watchlists, and trade signals with deep linking support.
*   **[Deep Linking & Referrals](docs/deep-linking.md):** Support for `realizealpha://` and `https` universal links for seamless app navigation and a referral tracking system.
*   **UI Enhancements:** Modernized navigation with Material 3 NavigationBar, **Dual-Value Position Bar Charts** with synchronized zero-baseline tick alignment and interactive detail tooltips, **Synchronized Horizontal Scrolling** across position detail rows (Equities, Options, Forex, Futures), aligned Android adaptive splash branding, integrated ad banners for sustainability, and streamlined order management workflows.
*   **Cross-Platform:** Built with Flutter for a consistent experience on both Android and iOS.


## Architecture Overview

RealizeAlpha utilizes a combination of technologies:

*   **Mobile App:** Developed using the Flutter SDK and Dart for cross-platform deployment (iOS, Android).
*   **Backend Services:** Firebase Functions (written in TypeScript/JavaScript) are used for:
    *   Securely interacting with brokerage APIs.
    *   Handling business logic that shouldn't reside on the client.
    *   Integrating with AI services (e.g., Google AI Gemini API).
*   **Authentication:** Firebase Authentication manages user sign-in and security.
*   **Database/Storage:** Firestore or other Firebase services might be used for storing user preferences or other relevant data (if applicable).
*   **Hosting:** Firebase Hosting is used for deploying web-related components or documentation sites.


### Latest Release

- [RealizeAlpha | Apple App Store](https://testflight.apple.com/join/ARmsGSN8): TestFlight only, production release coming soon.
- [RealizeAlpha | Google Play Store](https://play.google.com/apps/internaltest/4701722902176245187): Internal testing only, production release coming soon.

<!--
## Usage

TODO
-->

## Build

### Dependencies

In order to build and debug locally, you must install the following dependencies:

- Android Studio (for Android deployment)
- XCode (for iOS deployment)
- Flutter SDK
- VS Code
- Dart & Flutter VS Code extensions

To ensure your installation was successful, run this command: 
```
flutter doctor -v
```

Once you see a "No issues found!" message, you are ready to start running the application.  

## Run & Debug

In VS Code, ```F5``` key, the ```Run``` icon, or from the ```Run``` menu to start debugging.
If prompted choose the ```Flutter``` configuration.

### Android Device

1. Enable USB debugging on your Android device.
2. Plug in your device. 
3. Open the command palette (```Ctrl+Shift+P```) and enter ```Flutter: Select Device```  
Or  
Navigate to the project directory and run the flutter command.
    ```bash
    flutter run
    ```

#### Debugging Notes

##### Wireless debugging

- On device, open Settings > System > Developer options.
    - Enable USB debugging & Wireless debugging.
- Connect device to computer over USB. Accept pairing notification on device.
- Open Android Studio > Tools > Device Manager and pair device.
- Run these commands to connect wirelessly:
    ```bash
    $ ${HOME}/AppData/Local/Android/Sdk/platform-tools/adb tcpip 5555
    restarting in TCP mode port: 5555
    $ ${HOME}/AppData/Local/Android/Sdk/platform-tools/adb connect 192.168.86.36
    connected to 192.168.86.36:5555
    ```
- Unplug device and start debugging.

### iOS Device

1. Enable developer on your iOS device.
2. Open ```Devices and Simulators``` window in XCode and ensure that your device is paired and connected. 
3. Open the command palette (```Ctrl+Shift+P```) and enter ```Flutter: Select Device```  
Or  
Navigate to the project directory and run the flutter command.
    ```bash
    flutter run --release
    ```

**Debugging Notes**
- For error `Exception: Error running pod install`, run the following commands:
    ```bash
    rm -rf ./ios/Pods;rm ./ios/Podfile.lock;flutter clean;flutter pub get
    flutter build ios
    # or flutter run
    ```

    If that doesn't work try a pod repo update.
    ```bash
    cd ios
    pod repo update
    flutter build ios
    ```

    If that doesn't work try a `pod update` in `ios`.
    Then in Xcode clean build folder, and build again.

### Web

Select a browser from the device selector. *Note that this is not working due to CORS.*

### Emulator 

Select a mobile emulator from the device selector. *Note that this is not working due to ?*

## Install

### Device

1. Connect your Android device to your computer with a USB cable.
2. Navigate to the project directory and run the flutter command.
    ```bash
    flutter install
    ```

    The response should contain the following status message.

    ```bash
    Installing app.apk to Pixel 5...
    Uninstalling old version...
    Installing build\app\outputs\flutter-apk\app.apk...                 5.2s
    ```

## Maintain

### Upgrade dependencies

#### Flutter upgrades

To ensure you are using the latest packages, run these commands to check and upgrade them: 
```bash
flutter pub outdated
flutter pub upgrade --major-versions
flutter pub upgrade --tighten
```

#### Firebase upgrades

Run these commands in both `functions` and `firebase` folders for Firebase function deployment and running admin tools respectively.
```bash
npm install -g npm-check-updates
ncu -u
npm install
```

### Generate App Icons & Launch Images

1. Replace src/robinhood_options_mobile/icon.png with latest icon PNG image at the maximum possible resolution (1024x1024?).
2. Run `dart run flutter_launcher_icons` in the project directory to generate all icons for iOS and Android.
3. Run `dart run flutter_native_splash:create` in the project directoru to generate all splash screens for iOS, Android and Web.

### Linting (javascript & typescript)

To fix issues with code formatting such as:
> 10 errors and 0 warnings potentially fixable with the `--fix` option.
> Error: functions predeploy error: Command terminated with non-zero exit code 1

Run the following command in the `functions` directory.

```bash
npm run lint -- --fix
```

_You can do this automatically in VS Code by installing the eslint plugin._

### Manage Firebase Auth Claims

#### Change a user role to admin

- Download Service Account private key from [https://console.firebase.google.com/project/realizealpha/settings/serviceaccounts/adminsdk](https://console.firebase.google.com/project/realizealpha/settings/serviceaccounts/adminsdk)
- Open `src/firebase-admin.js` Node.js file.
    - Change the path of the downloaded file at the following line: `var serviceAccount = require("/Users/aymericgrassart/Downloads/realizealpha-firebase-adminsdk-uzw9z-8cb065ac38.json");`
    - Change the id of the user that you want to add the role to at the following line.
        ```js
        admin.credential.setCustomUserClaims('exKIqutDIgWmPs6FDXEWMHJYdam1', {
            role: 'admin'
        });
        ```
- Save and execute the Node.js script from the src folder.
    ```bash
    node firebase-admin.js
    ```

### Seed Agentic Trading Data
To seed initial data for the Agentic Trading feature, run the following command in the `functions` directory:

```bash
firebase functions:call seedAgenticTrading
```
or
```bash
firebase functions:shell
> seedAgenticTrading({data:{full:true}})
```

#### Invoke Agentic Trading Cron Job Manually
To manually invoke the Agentic Trading cron job, run the following command in the `functions` directory:

```bash
# firebase functions:call agenticTradingCronInvoke
firebase functions:shell
> agenticTradingCronInvoke({data:null})
```

## Publish

### Firebase Hosting

`firebase.json` was changed to modify the `hosting` property `"source": "."` to `"public": "build/web"` in order to deploy custom builds.

```bash
#flutter build web --web-renderer html
flutter build web --release
firebase deploy --only hosting
```

Previously, the public folder was deployed with this configuration:
```json
{
  "hosting": {
    "public": "public",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ]
  }
}
```

### Firebase Functions

Functions will automatically deploy with hosting deployments with `firebase deploy`. To deploy only the functions, use the following command.

```bash
firebase deploy --only functions
```

The following secrets should be configured to prevent storing sensitive passwords and tokens in source control.

```bash
# Change the value of an existing secret
firebase functions:secrets:set GEMINI_API_KEY
# View the value of a secret
firebase functions:secrets:access GEMINI_API_KEY
```

### Firebase Firestore

To deploy the Firestore rules and indexes, use the following command.

```bash
firebase deploy --only firestore
```

To export the current Firestore indexes to the local files, use the following command.

```bash
firebase firestore:indexes > ./firebase/firestore.indexes.json
# firebase firestore:indexes --export
#firebase firestore:rules > ./firebase/firestore.rules
```

### Android Play Store

#### Build app bundle

```bash
flutter build appbundle --release
```

#### Generate APKs

This command generates an .apk file used to publish an installation file.

```bash
flutter build apk --release
```

### Apple App Store

#### Build IPA

```bash
flutter build ipa --release
```

If you get an error, see Debugging Notes section above to clean the project.

#### Upload to App Store

1. Install [Transporter App](https://apps.apple.com/us/app/transporter/id1450874784)
2. Add ipa file from `./build/ios/ipa/`
3. `Verify` and `Deliver`

## Test

### Unit & Widget Tests
```bash
flutter test
```

### Integration Tests
To run the end-to-end integration tests:
```bash
flutter test integration_test/app_test.dart
```

## Contribute

### Automated Documentation Updates

RealizeAlpha provides automated documentation update workflows to increment the app version and update `CHANGELOG.md`, `ROADMAP.md`, and other documentation files based on recent commit history:

- **Antigravity / Agent Skill:** Use the [update-docs](.agents/skills/update-docs/SKILL.md) skill:
  > /update-docs [nextversion]

- **GitHub Copilot Chat Prompt:** In VS Code with GitHub Copilot:
  > /updateDocs [nextversion]

This will trigger the agent to:
- Determine the next version (e.g., `0.37.2`) based on commit impact (Features vs. Bug Fixes).
- Update `pubspec.yaml` with the new version and incremented build number.
- Generate a new entry in `CHANGELOG.md` summarizing features, changes, and fixes.
- Mark completed items in `ROADMAP.md` and add the new release entry.
- Synchronize architectural notes and file references in `.github/copilot-instructions.md`.

## Future Enhancements

This project is actively evolving. For a comprehensive roadmap of planned features and enhancements, see [ROADMAP.md](ROADMAP.md).

Key areas of planned development include:
- **Portfolio & Analysis**: User Intelligence, AI Assistant, and advanced alerting.
- **Trading & Automation**: Algorithmic strategy marketplace, copy trading evolution, and smart routing.
- **Social & Community**: Viral growth features, leaderboards, and verified track records.
- **Platform Foundation**: Reliability, security, CI/CD, and app store polish.
- **Future Horizons**: Frontier tech, decentralized finance, and multi-agent systems.

See the [full documentation](docs/index.md) for detailed descriptions of each planned enhancement.
