# RealizeAlpha

RealizeAlpha is a professional-grade Flutter mobile app for multi-account brokerage management (Robinhood, Schwab, Fidelity), featuring AI-powered trade signals, automated agentic trading, and institutional-grade options analytics including Gamma Exposure (GEX) and institutional flow tracking.

## Getting Started

*   **Product Overview & Scope:** [PRODUCT.md](PRODUCT.md) — Target personas, core product principles, capability pillars, and strategic scope boundaries.
*   **Documentation Site:** [RealizeAlpha Docs](https://ciinc.github.io/robinhood-options-mobile/) ([`docs/index.md`](docs/index.md)) — Detailed feature guides, architecture references, and API research.
*   **Roadmap & Release History:** [ROADMAP.md](ROADMAP.md) & [CHANGELOG.md](CHANGELOG.md) — Active development priorities and release notes.
*   **Coding Agent & Contributor Guide:** [AGENTS.md](AGENTS.md) — Repository layout, safety invariants, and verification commands.

## Features

For full product context and architectural boundaries, see [PRODUCT.md](PRODUCT.md). For recent release highlights, see [CHANGELOG.md](CHANGELOG.md).

### Multi-Brokerage, Banking & Retirement
*   **[Multi-Brokerage Connectivity](docs/schwab-integration.md):** Connect live **Robinhood** and **Charles Schwab** accounts alongside **[Fidelity CSV imports](docs/fidelity-integration.md)** (positions & transaction history), a full-featured **[Paper Trading Simulator](docs/paper-trading.md)** (with guest-to-authenticated account migration), and instant Demo mode.
*   **[Schwab Real-Time Streamer](docs/schwab-integration.md):** Sub-second WebSocket streaming (`wss://streamer-api.schwab.com/ws`) for equities (`LEVELONE_EQUITIES`), options & Greeks (`LEVELONE_OPTIONS`), account/order activity (`ACCT_ACTIVITY`), chart candles (`CHART_EQUITY`), futures, and forex with automatic watchdog reconnection.
*   **[Multi-Account Aggregation & Retirement](docs/multi-account-and-retirement.md):** Unified cross-account portfolio view with persistent active-account switching, Traditional/Roth IRA support (`ira_traditional`, `ira_roth`), annual IRS contribution tracking, **Robinhood Gold Match Maximizer**, spending accounts, and connected OAuth agent management.
*   **[Stock Lending (SLIP), Cash Sweeps & Banking](docs/stock-lending-and-cash-sweeps.md):** Track loaned securities, 102% collateral backing, and monthly SLIP payments alongside high-yield cash sweep APY projections and multi-bank FDIC coverage, plus **[ACH Transfers & Linked Bank Accounts](docs/banking-and-transfers.md)**.
*   **[Tax Documents, Statements & Corporate Actions](docs/tax-documents-and-statements.md):** In-app Form 1099 packages, monthly statements, ADR fee tracking, foreign tax withholding rates, and **[Corporate Action Split & Cash-in-Lieu Tracking](docs/corporate-actions-and-stock-splits.md)**.

### Progressive Portfolio, Risk & Tax Optimization
*   **[Progressive Portfolio & Action Center](docs/portfolio-redesign.md):** Decision-focused workspace with hero P&L metrics, an account-aware Action Center with context-first deep-linking, top movers, and dedicated Performance, Positions, Risk, Insights, Taxes, and Strategies tabs powered by a unified **[Portfolio Analytics Controller](docs/portfolio-analytics.md)**.
*   **[Multi-Asset Allocation & Rebalancing](docs/portfolio-rebalancing.md):** Interactive allocation charts across all 7 asset classes (Stocks, Options, Crypto, Forex, Futures, Fixed Income, Cash), sector/industry breakdowns, drift analysis, **[AI Asset Allocation](docs/ai-asset-allocation.md)** (including All-Weather presets), and scheduled rebalancing.
*   **[Quantitative Risk, Margin & Circuit Breakers](docs/margin-health-and-collateral.md):** **[Beta-Weighted Portfolio Greeks](docs/beta-weighted-portfolio-greeks.md)**, **[Correlation Matrix](docs/correlation-analysis.md)**, portfolio stress testing, tail-risk & liquidity scoring, **[ESG Scoring](docs/esg-scoring.md)**, **[Margin Calls & Financing Costs](docs/margin-calls-and-financing.md)**, **[Instrument-Specific Buying Power & Trade Warnings](docs/instrument-buying-power-and-warnings.md)**, **[Pattern Day Trader (PDT) Protection](docs/pdt-protection.md)**, **[RiskGuard](docs/risk-guard.md)** pre-trade checks, **[Autonomous Agentic Risk Copilot](docs/agentic-risk-copilot.md)**, and **[Account Risk Circuit Breakers & Tilt Guardrails](docs/risk-circuit-breakers.md)**.
*   **[Tax Optimization & Loss Harvesting Suite](docs/tax-loss-harvesting.md):** Automated tax-loss harvesting with correlated replacement pairs, rolling 30-day wash-sale detection, **[Capital Gains & Holding Period Breakdown](docs/capital-gains-breakdown.md)**, **[Specific Tax Lot Matching](docs/tax-lot-matching.md)** (FIFO, LIFO, HIFO, Tax Minimizer), **[FIFO Round-Trip Cost Basis Lookback](docs/instrument-cost-basis-lookback.md)**, and **[IRS Form 8949 / Schedule D Export](docs/form-8949-export.md)**.

### Options, Futures, Crypto & Forex Trading
*   **[Option Chain Screener & Strategy Builder](docs/option-strategy-builder.md):** Filter option chains by Delta, Gamma, Theta, Vega, and IV with AI "Find Best Contract" suggestions, visual payoff diagrams, **[Options Collateral & Tier Upgrades](docs/options-collateral-and-tier-upgrades.md)**, and redesigned **[Option Instrument Position Cards](docs/ui-improvements.md#option-instrument-position-ui)**.
*   **[Multi-Leg Spreads, Combo Orders & Roll Assistant](docs/multi-leg-spread-builder.md):** Structural order templates for Verticals, Straddles, Strangles, Iron Condors, and Calendars; **[Combo Orders (Stock + Option Packages)](docs/combo-orders.md)**; **[Options Strategy Roll Assistant](docs/options-strategy-roll-assistant.md)**; **[Multi-Leg Options Defense & Roll Playbook](docs/options-defense-and-roll-playbook.md)**; and **[Landscape Charting & Matrix View](docs/landscape-chart-matrix.md)**.
*   **[Advanced Order Types & Templates](docs/advanced-order-types.md):** Trailing Stop, Stop-Limit, and Time-in-Force (GTC, IOC) orders across equities and options with reusable **[Order Templates](docs/order-templates.md)**.
*   **[Futures, Crypto & Forex Execution](docs/futures.md):** Live futures position tracking, margin calculations, **[Futures Order Entry](docs/futures.md#futures-order-entry)**, and **[Futures Auto-Trading](docs/futures.md#futures-auto-trading)**; dedicated **[Crypto Trading](docs/crypto-trading.md)** and **[Forex Trading](docs/forex-trading.md)** (Micro/Mini/Standard lots, live pip values); plus the quantitative **[Carry Trade Optimizer](docs/carry-trade-optimizer.md)**.

### Trade Signals, Backtesting & Agentic Trading
*   **[Multi-Indicator Agentic Trading](docs/agentic-trading.md):** Autonomous and semi-autonomous trading powered by a **[19-Indicator Technical Evaluation System](docs/multi-indicator-trading.md)** across 15m, 1h, and 1d intervals, **Agentic Reasoning Mode**, live-quote BUY price validation, authoritative dynamic/fixed position sizing, **[Custom Indicators](docs/agentic-trading.md#custom-indicators)**, strategy templates, and a **5-Tier GEX Sequential Stop Queue** with trailing stops and emergency kill switches.
*   **[Macro Regime Assessment](docs/macro-assessment.md):** 19-indicator institutional macro engine (VIX, MOVE, Yield Curve, Credit Spreads, Market Breadth) classifying global market regimes (`RISK_ON`, `RISK_OFF`, `NEUTRAL`) with weighted 0–100 scoring and strategy guidance.
*   **[Historical Backtesting & Alpha Discovery](docs/backtesting.md):** Test multi-indicator strategies across custom date ranges and intervals with equity curves, Sharpe ratio, profit factor, drawdown analytics, reusable templates, **[Alpha Factor Discovery](docs/alpha-factor-discovery.md)** (Information Coefficient & ICIR), and **[Event Study Analyzer](docs/event-study.md)**.

### Quantitative Derivatives & Market Intelligence
*   **[Gamma Exposure (GEX) Analysis](docs/gamma-exposure-analysis.md):** Portfolio-wide and per-symbol net/gross gamma profiling, gamma flip transition levels, call/put walls, Market Maker Pinning Gauge, spot-shift sensitivity, and an on-device Dart Black-Scholes fallback engine.
*   **[Options Flow Analysis](docs/options-flow-analysis.md):** Real-time institutional sweep, block, whale, and 0DTE/1DTE flow detection with 30+ smart flags and trade-specific verification checklists.
*   **[Smart Money, Insider & Political Disclosures](docs/whale-watch.md):** Track institutional accumulation and officer activity via **[Whale Watch](docs/whale-watch.md)**, **[Insider Activity](docs/insider-activity.md)**, **[Institutional Ownership](docs/institutional-ownership.md)**, **[SEC EDGAR Filings (13F, Form 4, 8-K)](docs/sec-edgar-integration.md)**, **[Congress & STOCK Act Filings](docs/congress-trading-tracker.md)**, **[Short Interest & Borrow Availability](docs/short-interest.md)**, and **[Retail Order Flow](docs/retail-order-flow.md)**.
*   **[Screeners, Charting & Market Data](docs/market-data-providers-research.md):** Multi-benchmark historical charts, **[Instrument Chart Overlays](docs/index.md#instrument-charting)** (SMA, EMA, VWAP, Bollinger Bands, TTM Squeeze), **[Stock Screener](docs/screener-presets-and-legend-layouts.md)**, and **[Twelve Data Integration](docs/twelve-data-migration.md)**.

### AI Copilot, Behavioral Coaching & Local MCP
*   **[Local Model Context Protocol (MCP) Client](docs/mcp-integration.md):** On-device Dart MCP client paired with **Gemini** to inspect live balances, positions, orders, and watchlists, generate **[AI Price Targets](docs/price-targets.md)**, and draft Markdown **[Instrument Notes](docs/instrument-notes.md)**.
*   **[AI Devil's Advocate & Thesis Stress Tester](docs/devils-advocate.md):** Pre-trade adversarial critique computing a 0–100 Resilience Score (`Fragile`, `Moderate`, `Resilient`), surfacing the "Killer Question" vulnerability, options skew traps, event hazards, and shock scenarios directly inside research and order sheets.
*   **[AI Trade Post-Mortem & Trading Coach](docs/trade-post-mortem.md):** Post-trade execution grading (0–100, A–F) separating decision quality from outcome luck (`goodWin`, `badWin`, `goodLoss`, `badLoss`), automatic cognitive bias tagging into the **[Trading Psychology & Emotion Journal](docs/ai-trading-coach.md#8-emotion-tracking--mindset-journal)**, streak tracking, challenge verification, and **[Sentiment Analysis](docs/sentiment-analysis.md)** foundations.

### Social, Investor Groups 2.0 & Protected Copy Trading
*   **[Investor Groups 2.0](docs/investor-groups-2.md):** Private and public groups with member roles, real-time **Group Activity Feeds**, **Group Chat**, **[Shared Analysis Boards](docs/social-discussion-threads.md)**, **Verified Track Records**, and collaborative **[Group Watchlists](docs/group-watchlists.md)**.
*   **[Protected Copy Trading](docs/copy-trading.md):** Mirror or inverse-copy stock and option trades from group leaders with manual approval or auto-execution, position/notional caps, take-profit/stop-loss rules, and a pre-trade **Copy Trade Risk Guardian**.

### Platform, Security & Mobile Experience
*   **[Zero-Plaintext Security & Feature Gating](docs/secure-token-storage.md):** Hardware-backed credential encryption via `flutter_secure_storage` (iOS Keychain / Android Keystore), biometric authentication (FaceID/TouchID), **[Balance Visibility Masking](docs/ui-improvements.md#balance-privacy--navigation-v0370)**, and **[Feature Access & Beta Labs Gating](docs/feature-access-and-beta-gating.md)**.
*   **[Native Mobile Experience & Offline Resilience](docs/offline-mode-and-resilient-caching.md):** Encrypted **[Offline Mode & Resilient Caching](docs/offline-mode-and-resilient-caching.md)**, **[iOS Live Activities & Dynamic Island](docs/ios-live-activities-and-dynamic-island.md)**, **[Home Screen Widgets](docs/home-widgets.md)**, **[Trade Signal Push Notifications](docs/trade-signal-notifications.md)**, **[Custom Price & Event Alerts](docs/custom-alerts.md)**, **[Universal Deep Linking & Referrals](docs/deep-linking.md)**, and **[Material 3 UI & Accessibility Polish](docs/ui-improvements.md)**.


## Architecture Overview

RealizeAlpha utilizes a combination of technologies:

*   **Mobile App:** Developed using the Flutter SDK and Dart for cross-platform deployment (iOS, Android).
*   **Backend Services:** Firebase Functions (written in TypeScript/JavaScript) are used for:
    *   Securely interacting with brokerage APIs (see [Brokerage Endpoints](docs/options-futures-api-endpoints.md)).
    *   Handling business logic that shouldn't reside on the client.
    *   Integrating with AI services (e.g., Google AI Gemini API via [MCP Integration](docs/mcp-integration.md)).
*   **Authentication:** Firebase Authentication manages user sign-in and security with encrypted on-device token storage (see [Secure Token Storage](docs/secure-token-storage.md)).
*   **Database/Storage:** Cloud Firestore stores user documents, preferences, and portfolio telemetry (see [Entity-Relationship Diagram](docs/er-diagram.md)).
*   **Hosting & CI/CD:** Firebase Hosting is used for web components, with GitHub Actions CI/CD automation (see [Mobile CI Setup](docs/mobile-ci-setup.md)).


### Latest Release

- [RealizeAlpha | Apple App Store](https://testflight.apple.com/join/ARmsGSN8): TestFlight only, production release coming soon. (See [TestFlight Deployment Guide](docs/TESTFLIGHT_DEPLOYMENT.md)).
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

Select a browser from the device selector. *Note: Direct client-side brokerage requests in the browser are restricted by CORS unless routed through backend Cloud Functions.*

### Emulator

Select an iOS Simulator or Android Emulator from the device selector and run `flutter run`.

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

1. Replace `src/robinhood_options_mobile/icon.png` with the latest icon PNG image at the maximum possible resolution (`1024x1024`).
2. Run `dart run flutter_launcher_icons` in the project directory to generate all icons for iOS and Android.
3. Run `dart run flutter_native_splash:create` in the project directory to generate all splash screens for iOS, Android, and Web.

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
- Open `src/robinhood_options_mobile/firebase/firebase-admin.js` Node.js file.
    - Change the path of the downloaded file at the following line: `var serviceAccount = require("/path/to/service-account-key.json");`
    - Change the UID of the user that you want to grant the `admin` role to:
        ```js
        admin.credential.setCustomUserClaims('<USER_UID>', {
            role: 'admin'
        });
        ```
- Save and execute the Node.js script from the `firebase` folder.
    ```bash
    node firebase-admin.js
    ```

### Seed Agentic Trading Data
To seed initial data for the [Agentic Trading](docs/agentic-trading.md) feature, run the following command in the `functions` directory:

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

For complete App Store Connect and TestFlight build instructions, see [TestFlight Deployment](docs/TESTFLIGHT_DEPLOYMENT.md).

## Test

For testing standards, architecture patterns, and regression test conventions, see [Testing Standards](docs/testing-standards.md).

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

Before contributing or running coding agents in this repository, review [AGENTS.md](AGENTS.md) for architectural guidelines, security/trading invariants, and verification commands, and [PRODUCT.md](PRODUCT.md) for product principles and scope boundaries.

### Agent Skills & Workflows

RealizeAlpha provides structured agent skills for roadmap planning, implementation, and documentation synchronization:

- **Roadmap Ideation ([`.github/skills/roadmap-ideation/SKILL.md`](.github/skills/roadmap-ideation/SKILL.md)):** Propose evidence-backed roadmap items and link GitHub issues (`> /roadmap-ideation`).
- **Roadmap Execution ([`.agents/skills/roadmap/SKILL.md`](.agents/skills/roadmap/SKILL.md)):** Implement the highest-priority actionable feature from [ROADMAP.md](ROADMAP.md) end-to-end with tests and docs (`> /roadmap`).
- **Automated Documentation Sync ([`.agents/skills/update-docs/SKILL.md`](.agents/skills/update-docs/SKILL.md)):** Increment the app version and synchronize `CHANGELOG.md`, `ROADMAP.md`, `README.md`, and `.github/copilot-instructions.md` (`> /update-docs [nextversion]`).

## Future Enhancements

This project is actively evolving. For the product vision and strategic scope boundaries, see [PRODUCT.md](PRODUCT.md). For the prioritized backlog of planned features and enhancements, see [ROADMAP.md](ROADMAP.md).

Key areas of planned development include:
- **Portfolio, Tax & Risk Analytics**: Multi-asset Brinson & Greek return attribution, Risk Parity & inverse-volatility rebalancing, and cross-account tax optimization.
- **Derivatives & Execution**: Futures SPAN margin health & intraday seasonality, 0DTE regime playbooks, and advanced multi-leg strategy automation.
- **Social & Copy Trading**: Options contract adaptation and defined-risk guardrails for group copy trading, verified track records, and collaborative research.
- **Platform Foundation**: Offline resilience, accessibility, security hardening, and App Store / Play Store production readiness.

See the [full documentation](docs/index.md) for detailed descriptions of each feature and planned enhancement.
