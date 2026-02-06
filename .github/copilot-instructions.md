### Purpose
This file tells AI coding agents how to be immediately productive in the RealizeAlpha (robinhood-options-mobile) codebase.

Keep guidance concise and actionable. Only change behavior when confident and follow the repository conventions below.

Key facts (quick):
- Flutter mobile app (Dart) in `src/robinhood_options_mobile/`.
- Backend helpers and server code live under `src/robinhood_options_mobile/functions/` and `src/robinhood_options_mobile/firebase/` (Firebase Functions + admin tooling).
- Firebase is heavily used: `firebase_core`, `firebase_auth`, `cloud_firestore`, `cloud_functions`, `firebase_analytics`, and `firebase_ai`.
- Futures support: service-layer enrichment only (no secrets) adding contract & product metadata + quotes and computing Open P&L per contract.

Quick-start commands an agent can recommend or run (macOS / zsh):
- Install and verify environment: `flutter doctor -v`.
- Get packages: from repo root run `flutter pub get` (or cd into `src/robinhood_options_mobile` and run it there).
- Run app on device/emulator: `flutter run` or use VS Code Flutter debug (F5).
- Run tests: `flutter test`.
- Build iOS: `flutter build ios` (may require `pod repo update` and `flutter clean` if pod errors).
- Deploy Firebase functions: `cd src/robinhood_options_mobile/functions && npm install && firebase deploy --only functions`.

Architecture notes (what matters to code changes):
- UI / App state: The app uses `provider` extensively. Look in `src/robinhood_options_mobile/lib/model/` — most business state lives in ChangeNotifier stores (e.g. `PortfolioStore`, `OptionPositionStore`, `QuoteStore`, `AgenticTradingProvider`, `InvestorGroupStore`). Edits to stateful logic should update unit tests where available.
- App entrypoint: `lib/main.dart` wires Firebase initialization, providers, `RemoteConfigService`, and `NavigationStatefulWidget` as the main route. Use this file to understand app-wide initializations (Firebase, AdMob, Firestore emulator flag `shouldUseFirestoreEmulator`).
- Features behind backend: Sensitive or broker API logic is intentionally hosted in Firebase Functions (`functions/`) — avoid moving secrets into client code. Use functions for brokerage interactions.
- Generative AI: AI features are proxied through Firebase Functions and the `GenerativeProvider` in `lib/model/generative_provider.dart` (search for `GenerativeProvider`). Prefer server-side usage for API keys and rate-limiting. **Note:** Uses `gemini-2.5-flash-lite` for improved performance.
- Trade Signals: Agentic trading with 19-indicator correlation system managed by `AgenticTradingProvider` in `lib/model/agentic_trading_provider.dart` and `TradeSignalsProvider` in `lib/model/trade_signals_provider.dart`. Indicators: Price Movement (multi-pattern), RSI (with divergence detection), Market Direction, Volume, MACD, Bollinger Bands, Stochastic, ATR, OBV, VWAP, ADX, Williams %R, Ichimoku Cloud, CCI, Parabolic SAR, ROC, Chaikin Money Flow, Fibonacci Retracements, Pivot Points. Signal Strength score (0-100) quantifies indicator alignment. User configuration stored in `AgenticTradingConfig` model (`lib/model/agentic_trading_config.dart`) with per-indicator enable/disable controls and paper trading mode support. Trade signals stored in Firestore `agentic_trading/signals_{SYMBOL}` (daily) or `signals_{SYMBOL}_{INTERVAL}` (intraday) with server-side filtering and real-time Firestore snapshot listeners. Automated execution with 5-minute periodic checks, trade-level TP/SL tracking, trailing stops, and Firebase persistence of automated trades. **Note:** Auto-trading calls use `skipSignalUpdate: true` to prevent server-side timestamp updates during routine checks. Backend logic in `functions/src/agentic-trading.ts`, `functions/src/agentic-trading-cron.ts`, `functions/src/agentic-trading-intraday-cron.ts`, `functions/src/alpha-agent.ts`, `functions/src/riskguard-agent.ts` (Advanced Risk Controls: sector limits, correlation checks, volatility filters, drawdown protection; **Now also protects manual trading** with optional `skipRiskGuard` for agents), and `functions/src/technical-indicators.ts` (19 indicator evaluation functions). Supports multiple intervals (15m, 1h, 1d) with DST-aware market hours detection, visual market status indicators, and push notifications. Advanced analytics in `AgenticTradingPerformanceWidget` with 9 analytics cards: overview, P&L breakdown, trade breakdown, best/worst trades, advanced metrics (Sharpe ratio, average hold time, profit factor, expectancy), risk metrics (streaks, max drawdown), time-of-day performance, indicator combo performance, and symbol performance. Paper Trading Mode simulates trades without real broker API calls for risk-free strategy testing. Order Approval Workflow allows manual review of agent-generated orders before execution. **New:** Custom Indicators support and ML-powered Signal Optimization. **New:** Advanced Exit Strategies including Partial Exits, Time-Based Exits, and Market Close Exits. **New:** Trading Strategy Templates managed in `TradeStrategiesPage` and `EntryStrategiesWidget`.
- Investor Groups: Collaborative portfolio sharing managed by `InvestorGroupStore` in `lib/model/investor_group_store.dart`. Groups stored in Firestore `investor_groups/{groupId}` with 15+ service methods in `FirestoreService`. Supports public/private groups, member management, real-time invitation system (send/accept/decline/cancel), admin controls (promote/demote/remove), direct portfolio viewing for private group members, and **Group Messaging** (notifications & read receipts). UI includes 3-tab admin interface (Members, Pending, Invite).
- Copy Trading: Integrated with Investor Groups. Settings stored per member via `CopyTradeSettings` map on `InvestorGroup` and configured in `CopyTradeSettingsWidget`. Manual copy trade execution via `CopyTradeButtonWidget` (stocks/options) calls brokerage API client-side. Backend triggers in `functions/src/copy-trading.ts` listen for filled orders, apply quantity/amount limits, create `copy_trades` audit documents, and dispatch FCM push notifications. **New:** Copy Trading Dashboard (`CopyTradingDashboardWidget`) provides trade history and filtering. **New:** Approval Workflow (`CopyTradeRequestsWidget`) allows manual review of auto-generated copy trade requests before execution. **New:** Inverse Copying and Exit Strategies (TP/SL) supported in settings.
- Options Flow: Real-time analysis of large option trades. Backend logic in `functions/src/options-flow-utils.ts` detects 30+ smart flags like "Whale" (>$1M), "Golden Sweep", "Steamroller", "Cheap Vol", "High Premium", etc. UI in `lib/widgets/options_flow_widget.dart` displays these with specific badges, supports filtering by flag types **and expiration dates**, and provides detailed in-app definitions.
- Trade Signal Notifications: Configurable push notifications for trade signals managed by `TradeSignalNotificationSettingsWidget`. Settings stored in user document. Backend triggers in `functions/src/trade-signal-notifications.ts` listen for signal updates and dispatch FCM notifications based on user preferences (signal type, symbol, interval, confidence). Deep linking handled in `NavigationStatefulWidget`.
- Futures Positions: Enrichment logic in service method (search for futures position stream) fetching aggregated positions then contract/product metadata and quotes. Adds fields: `rootSymbol`, `expiration`, `currency`, `multiplier`, `lastTradePrice`, and computed `openPnlCalc = (lastTradePrice - avgTradePrice) * quantity * multiplier`. UI widget displays Open, Day, and Realized P&L. Avoid moving margin or risk calc secrets client-side; future advanced analytics should migrate to functions if broker rate limits or sensitive operations emerge.
- **Multi-Account Aggregation:** Enabled by `BrokerageUserStore` supporting multiple `BrokerageUser` instances. Users can switch between individual accounts or view aggregated positions/history across all accounts. Navigation controls (`disableNavigation` parameter) prevent trading on aggregate views. UI components (`InstrumentPositionsWidget`, `OptionPositionsWidget`, `FuturesPositionsWidget`, `HistoryWidget`) render differently based on aggregation context. **Note:** Aggregate trading feature (#114) restricts order placement until a specific account is selected.
- **Fidelity CSV Import:** Integration with `FidelityService` in `lib/services/fidelity_service.dart` and generic `CsvImportService` in `lib/services/csv_import_service.dart`. Parses CSV files from Fidelity exports and merges position data with existing brokerage instruments. CSV export functionality available for portfolio analytics via `PortfolioAnalyticsWidget`. Services handle file parsing, validation, and data reconciliation with existing portfolio models.
- Backtesting: Historical strategy testing managed by `BacktestingProvider` in `lib/model/backtesting_provider.dart`. Models in `backtesting_models.dart` (BacktestConfig, BacktestTrade, BacktestResult, BacktestTemplate). UI in `backtesting_widget.dart` with 3-tab interface (Run, History, Templates). Backend function `runBacktest` in `functions/src/backtesting.ts` handles historical simulation using same `evaluateAllIndicators()` logic as live trading. Bar-by-bar processing with entry/exit tracking, equity curve computation, and performance metrics (Sharpe ratio, max drawdown, profit factor, win rate). Firestore storage: `backtest_history` and `backtest_templates` per user with history limit of 50 runs. Results page has 4 tabs: Overview (metrics), Trades (list), Equity (chart with markers), Details (config & stats). Interactive equity curve with clickable trade markers and linked statistics list.

Patterns & conventions (concrete examples):
- State containers are `ChangeNotifier` classes under `lib/model` and provided via `MultiProvider` in `main.dart`. Example: `PortfolioHistoricalsStore` and its selection store `PortfolioHistoricalsSelectionStore` are paired.
- Naming: files and classes follow lower_snake_case for filenames and UpperCamelCase for Dart classes; maintain this convention.
- Firestore: the app sometimes uses the Firestore emulator flag `shouldUseFirestoreEmulator` (in `main.dart`) — if you add local-only rules or tests, toggle that flag or wire a configuration value.
- Real-time subscriptions: Use `StreamSubscription` for Firestore snapshot listeners and always implement `dispose()` in providers to cancel subscriptions (see `AgenticTradingProvider` for reference pattern).
- Ads & analytics: AdMob and FirebaseAnalytics are initialized in `main.dart` — changes to analytics events should reuse `FirebaseAnalytics.instance`.
- **User Context Threading:** Navigation widgets use `brokerageUser` for brokerage operations and `userDocRef` (optional `DocumentReference<User>?`) for Firestore user document access. Pass both through navigation chains: `ChildWidget(brokerageUser, service, data, user: widget.user, userDocRef: widget.userDocRef)`. This enables user-specific settings, generative features, and investor group functionality throughout the app.
- **App Badging:** Uses `app_badge_plus` to manage app icon badges.

Developer workflows (notes an agent should surface when changing code):
- Pod / iOS problems: if `pod install` fails, the README instructs `rm -rf ./ios/Pods; rm ./ios/Podfile.lock; flutter clean; flutter pub get; flutter build ios` and/or `pod repo update`.
- Linting & functions: JS/TS linting runs in `functions` with `npm run lint`. Use `-- --fix` to autoapply fixable rules.
- Secrets: do NOT add API keys to the repo. Use `firebase functions:secrets:set` or the `firebase` project secret manager as used in README.

What to change vs what to avoid (safety/side-effects):
- Make UI/logic changes in Dart files under `lib/` and update corresponding stores in `lib/model/`.
- Put server-side or secret-dependent logic into `functions/` and reference them via `cloud_functions` from the app.
- Avoid editing generated or build artifacts under `build/`.

Where to look for tests and minimal verification:
- Unit tests: `src/robinhood_options_mobile/test/` — run `flutter test` from `src/robinhood_options_mobile`.

Examples of specific file references an agent can use in patches:
- App initialization: `src/robinhood_options_mobile/lib/main.dart` (providers, Firebase init, AdMob).
- State & model examples: `src/robinhood_options_mobile/lib/model/portfolio_store.dart`, `option_position_store.dart`, `generative_provider.dart`, `agentic_trading_provider.dart` (includes real-time Firestore subscriptions), `agentic_trading_config.dart` (user configuration model), `backtesting_provider.dart` (backtesting state management), `investor_group_store.dart`.
- Portfolio allocation UI: `src/robinhood_options_mobile/lib/widgets/home_widget.dart` (carousel with 4 pie charts: Asset, Position, Sector, Industry; uses `ValueNotifier` for page indicators, `CarouselView` with scroll listener, and `community_charts_flutter` with bidirectional selection between slices and legend).
- Portfolio Rebalancing UI: `src/robinhood_options_mobile/lib/widgets/rebalancing_widget.dart` (interactive allocation tool with dual views, precision editing, drift analysis, actionable recommendations, and **AI Asset Allocation** based on user risk profiles).
- Trade signals UI: `src/robinhood_options_mobile/lib/widgets/search_widget.dart` (main search & signal filtering), `screener_widget.dart` (stock screener), `presets_widget.dart` (Yahoo presets), `instrument_widget.dart` (single signal view), `trade_signals_widget.dart` (dedicated signal filtering & viewing).
- **Sentiment UI:** `src/robinhood_options_mobile/lib/widgets/home/market_sentiment_card_widget.dart` (home screen card), `src/robinhood_options_mobile/lib/widgets/sentiment_analysis_dashboard_widget.dart` (dashboard).
- **Instrument Notes UI:** `src/robinhood_options_mobile/lib/widgets/instrument_note_widget.dart` (private Markdown notes with AI drafting per instrument).
- **Generative AI UI:** `src/robinhood_options_mobile/lib/widgets/generative_actions_widget.dart` (AI-driven actions and insights), `personalized_coaching_widget.dart` (AI Trading Coach with **Challenge Adherence Verification**, **Hidden Risks Detection**, **Streak Tracking**, **Market Assistant**, and optimized data fetching), `paper_trading_dashboard_widget.dart` (AI Portfolio Analysis and Insights).
- Portfolio Analytics UI: `src/robinhood_options_mobile/lib/widgets/portfolio_analytics_widget.dart` (comprehensive dashboard with risk/return metrics, health score, ESG scoring, **Custom Benchmarks support**, **Performance Overview Card for benchmark-relative tracking**, **enhanced tooltips and help dialogs**), `correlation_matrix_widget.dart` (interactive asset correlation heatmap).
- Tax Optimization UI: `src/robinhood_options_mobile/lib/widgets/tax_optimization_widget.dart` (Tax Loss Harvesting tool).
- ESG Services: `src/robinhood_options_mobile/lib/services/esg_service.dart` (ESG data fetching).
- Analytics Utils: `src/robinhood_options_mobile/lib/utils/analytics_utils.dart` (Advanced portfolio metrics calculation).
- Agentic Trading Analytics UI: `src/robinhood_options_mobile/lib/widgets/agentic_trading_settings_widget.dart` (auto-trade configuration with real-time countdown, paper trading toggle, emergency stop), `agentic_trading_performance_widget.dart` (9 analytics cards with comprehensive metrics and trade filtering).
- Backtesting UI: `src/robinhood_options_mobile/lib/widgets/backtesting_widget.dart` (3-tab interface with Run/History/Templates tabs, result page with 4 tabs, advanced results filtering, interactive equity curve chart).
- **Research UI:** `src/robinhood_options_mobile/lib/widgets/alpha_factor_discovery_widget.dart` (Alpha Factor Discovery), `macro_assessment_widget.dart` (Macro Economic Dashboard).
- Strategy Management UI: `src/robinhood_options_mobile/lib/widgets/trading_strategies_page.dart` (Strategy listing, sorting, and template management), `src/robinhood_options_mobile/lib/widgets/shared/entry_strategies_widget.dart` (visual entry strategy configuration).
- Investor Groups UI: `src/robinhood_options_mobile/lib/widgets/investor_groups_widget.dart` (main 3-tab layout), `investor_group_detail_widget.dart` (member list, portfolio navigation), `investor_group_manage_members_widget.dart` (admin 3-tab interface: Members/Pending/Invite), `investor_group_create_widget.dart` (creation form).
- Watchlist UI: `src/robinhood_options_mobile/lib/widgets/lists_widget.dart` (main lists view), `list_widget.dart` (individual list details).
- Option Chain & Strategy UI: `src/robinhood_options_mobile/lib/widgets/instrument_option_chain_widget.dart` (option chain with advanced filtering & AI recommendations), `option_instrument_widget.dart` (redesigned position detail card with P&L/Greeks), `strategy_builder_widget.dart` (multi-leg strategy builder with payoff diagrams), `options_flow_widget.dart` (options flow analysis with filtering).
- Trading UI: `src/robinhood_options_mobile/lib/widgets/trade_instrument_widget.dart` (refactored order placement), `position_order_widget.dart` (order preview).
- Crypto/Forex Trading UI: `src/robinhood_options_mobile/lib/widgets/trade_forex_widget.dart` (crypto/forex order placement), `forex_orders_widget.dart` (order management).
- Copy Trading UI & Backend: `lib/widgets/copy_trade_settings_widget.dart`, `lib/widgets/copy_trade_button_widget.dart`, `lib/widgets/copy_trading_dashboard_widget.dart` (dashboard & history), `lib/widgets/copy_trade_requests_widget.dart` (approval workflow), model in `lib/model/investor_group_store.dart` (`memberCopyTradeSettings`), functions trigger logic in `functions/src/copy-trading.ts`, audit collection `copy_trades` (see Firestore rules), documentation in `docs/copy-trading.md`.
- Chart widgets: `src/robinhood_options_mobile/lib/widgets/chart_pie_widget.dart` (reusable PieChart with selection handling), `chart_time_series_widget.dart`, `chart_bar_widget.dart`, `instrument_chart_widget.dart` (enhanced instrument charting with benchmark comparison supporting SPY, QQQ, DIA, IWM).
- Common UI Components: `src/robinhood_options_mobile/lib/widgets/animated_price_text.dart` (dynamic price display with color animations).
- Schwab Integration: `src/robinhood_options_mobile/lib/services/schwab_service.dart` (Schwab API integration).
- **Fidelity & Import Services:** `src/robinhood_options_mobile/lib/services/fidelity_service.dart` (Fidelity CSV parsing), `csv_import_service.dart` (Generic CSV handling).
- **Multi-Account Management:** `src/robinhood_options_mobile/lib/model/brokerage_user_store.dart` (manages multiple `BrokerageUser` instances), `lib/model/brokerage_user.dart` (user account model with aggregation support). UI components like `home_widget.dart` and position widgets (`instrument_positions_widget.dart`, `option_positions_widget.dart`, `futures_positions_widget.dart`) handle aggregate view rendering with navigation controls.
- Monetization: `src/robinhood_options_mobile/lib/services/subscription_service.dart` (In-App Purchases management), `paywall_widget.dart` (premium feature gating).
- Firebase Functions entry: `src/robinhood_options_mobile/functions/` (look for `index.ts` or `lib/` depending on TS/JS layout).
- Backend cron jobs: `src/robinhood_options_mobile/functions/src/agentic-trading-cron.ts` (daily EOD with manual callable endpoint), `agentic-trading-intraday-cron.ts` (hourly and 15-min intervals).
- Backtesting function: `src/robinhood_options_mobile/functions/src/backtesting.ts` (runBacktest callable function for historical simulation).
- Macro & Research functions: `src/robinhood_options_mobile/functions/src/macro-agent.ts` (Macro Assessment logic), `alpha-factor-discovery.ts` (Alpha Factor research engine).
- Firestore indexes: `src/robinhood_options_mobile/firebase/firestore.indexes.json` (deploy with `firebase deploy --only firestore:indexes`).
- Firestore rules: `src/robinhood_options_mobile/firebase/firestore.rules` (includes investor_groups rules for public/private access, invitation permissions, backtest collections rules).

Quick safety checklist before proposing changes:
1. Does the change expose secrets or API keys? If yes, move to `functions/` + use `firebase secrets`.
2. Does the change modify provider/state classes? Add/update unit tests.
3. Is this change for native iOS/Android platform code? Verify `flutter build <platform>` and check README notes.
4. Avoid editing generated files under `build/`.
5. For futures enhancements (margin, realized/day P&L, roll detection) ensure calculations are test-covered; keep sensitive brokerage interactions in functions.

If you need more context, open these files first:
- `src/robinhood_options_mobile/lib/main.dart`
- `src/robinhood_options_mobile/pubspec.yaml`
- `src/robinhood_options_mobile/README.md`
- `src/robinhood_options_mobile/functions/package.json`
- `src/robinhood_options_mobile/firebase/firebase-admin.js`

If anything here is unclear or you'd like additional project-specific rules (testing patterns, CI instructions, or preferred branching), ask the maintainer and include a short proposed change for review.
