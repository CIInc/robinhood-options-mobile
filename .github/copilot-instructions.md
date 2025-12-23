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
- App entrypoint: `lib/main.dart` wires Firebase initialization, providers, and `NavigationStatefulWidget` as the main route. Use this file to understand app-wide initializations (Firebase, AdMob, Firestore emulator flag `shouldUseFirestoreEmulator`).
- Features behind backend: Sensitive or broker API logic is intentionally hosted in Firebase Functions (`functions/`) — avoid moving secrets into client code. Use functions for brokerage interactions.
- Generative AI: AI features are proxied through Firebase Functions and the `GenerativeProvider` in `lib/model/generative_provider.dart` (search for `GenerativeProvider`). Prefer server-side usage for API keys and rate-limiting.
- Trade Signals: Agentic trading with 12-indicator correlation system managed by `AgenticTradingProvider` in `lib/model/agentic_trading_provider.dart`. Indicators: Price Movement (multi-pattern), RSI (with divergence detection), Market Direction, Volume, MACD, Bollinger Bands, Stochastic, ATR, OBV, VWAP, ADX, Williams %R. Signal Strength score (0-100) quantifies indicator alignment. User configuration stored in `AgenticTradingConfig` model (`lib/model/agentic_trading_config.dart`) with per-indicator enable/disable controls and paper trading mode support. Trade signals stored in Firestore `agentic_trading/signals_{SYMBOL}` (daily) or `signals_{SYMBOL}_{INTERVAL}` (intraday) with server-side filtering and real-time Firestore snapshot listeners. Automated execution with 5-minute periodic checks, trade-level TP/SL tracking, trailing stops, and Firebase persistence of automated trades. Backend logic in `functions/src/agentic-trading.ts`, `functions/src/agentic-trading-cron.ts`, `functions/src/agentic-trading-intraday-cron.ts`, `functions/src/alpha-agent.ts`, `functions/src/riskguard-agent.ts` (Advanced Risk Controls: sector limits, correlation checks, volatility filters, drawdown protection), and `functions/src/technical-indicators.ts` (12 indicator evaluation functions). Supports multiple intervals (15m, 1h, 1d) with DST-aware market hours detection, visual market status indicators, and push notifications. Advanced analytics in `AgenticTradingPerformanceWidget` with 9 analytics cards: overview, P&L breakdown, trade breakdown, best/worst trades, advanced metrics (Sharpe ratio, average hold time, profit factor, expectancy), risk metrics (streaks, max drawdown), time-of-day performance, indicator combo performance, and symbol performance. Paper Trading Mode simulates trades without real broker API calls for risk-free strategy testing. Order Approval Workflow allows manual review of agent-generated orders before execution. **New:** Custom Indicators support and ML-powered Signal Optimization. **New:** Advanced Exit Strategies including Partial Exits, Time-Based Exits, and Market Close Exits.
- Investor Groups: Collaborative portfolio sharing managed by `InvestorGroupStore` in `lib/model/investor_group_store.dart`. Groups stored in Firestore `investor_groups/{groupId}` with 15+ service methods in `FirestoreService`. Supports public/private groups, member management, real-time invitation system (send/accept/decline/cancel), admin controls (promote/demote/remove), and direct portfolio viewing for private group members. UI includes 3-tab admin interface (Members, Pending, Invite).
- Copy Trading: Integrated with Investor Groups. Settings stored per member via `CopyTradeSettings` map on `InvestorGroup` and configured in `CopyTradeSettingsWidget`. Manual copy trade execution via `CopyTradeButtonWidget` (stocks/options) calls brokerage API client-side. Backend triggers in `functions/src/copy-trading.ts` listen for filled orders, apply quantity/amount limits, create `copy_trades` audit documents, and dispatch FCM push notifications. **New:** Copy Trading Dashboard (`CopyTradingDashboardWidget`) provides trade history and filtering. **New:** Approval Workflow (`CopyTradeRequestsWidget`) allows manual review of auto-generated copy trade requests before execution. **New:** Inverse Copying and Exit Strategies (TP/SL) supported in settings.
- Futures Positions: Enrichment logic in service method (search for futures position stream) fetching aggregated positions then contract/product metadata and quotes. Adds fields: `rootSymbol`, `expiration`, `currency`, `multiplier`, `lastTradePrice`, and computed `openPnlCalc = (lastTradePrice - avgTradePrice) * quantity * multiplier`. UI widget displays Open P&L only (day/realized P&L deferred). Avoid moving margin or risk calc secrets client-side; future advanced analytics should migrate to functions if broker rate limits or sensitive operations emerge.
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
- Trade signals UI: `src/robinhood_options_mobile/lib/widgets/search_widget.dart` (main search & signal filtering), `screener_widget.dart` (stock screener), `presets_widget.dart` (Yahoo presets), `instrument_widget.dart` (single signal view).
- Generative AI UI: `src/robinhood_options_mobile/lib/widgets/generative_actions_widget.dart` (AI-driven actions and insights).
- Agentic Trading Analytics UI: `src/robinhood_options_mobile/lib/widgets/agentic_trading_settings_widget.dart` (auto-trade configuration with real-time countdown, paper trading toggle), `agentic_trading_performance_widget.dart` (9 analytics cards with comprehensive metrics and trade filtering).
- Backtesting UI: `src/robinhood_options_mobile/lib/widgets/backtesting_widget.dart` (3-tab interface with Run/History/Templates tabs, result page with 4 tabs, interactive equity curve chart).
- Investor Groups UI: `src/robinhood_options_mobile/lib/widgets/investor_groups_widget.dart` (main 3-tab layout), `investor_group_detail_widget.dart` (member list, portfolio navigation), `investor_group_manage_members_widget.dart` (admin 3-tab interface: Members/Pending/Invite), `investor_group_create_widget.dart` (creation form).
- Watchlist UI: `src/robinhood_options_mobile/lib/widgets/lists_widget.dart` (main lists view), `list_widget.dart` (individual list details).
- Option Chain & Strategy UI: `src/robinhood_options_mobile/lib/widgets/instrument_option_chain_widget.dart` (option chain with advanced filtering & AI recommendations), `strategy_builder_widget.dart` (multi-leg strategy builder with payoff diagrams).
- Trading UI: `src/robinhood_options_mobile/lib/widgets/trade_instrument_widget.dart` (refactored order placement), `position_order_widget.dart` (order preview).
- Copy Trading UI & Backend: `lib/widgets/copy_trade_settings_widget.dart`, `lib/widgets/copy_trade_button_widget.dart`, `lib/widgets/copy_trading_dashboard_widget.dart` (dashboard & history), `lib/widgets/copy_trade_requests_widget.dart` (approval workflow), model in `lib/model/investor_group_store.dart` (`memberCopyTradeSettings`), functions trigger logic in `functions/src/copy-trading.ts`, audit collection `copy_trades` (see Firestore rules), documentation in `docs/copy-trading.md`.
- Chart widgets: `src/robinhood_options_mobile/lib/widgets/chart_pie_widget.dart` (reusable PieChart with selection handling), `chart_time_series_widget.dart`, `chart_bar_widget.dart`, `instrument_chart_widget.dart` (enhanced instrument charting).
- Firebase Functions entry: `src/robinhood_options_mobile/functions/` (look for `index.ts` or `lib/` depending on TS/JS layout).
- Backend cron jobs: `src/robinhood_options_mobile/functions/src/agentic-trading-cron.ts` (daily EOD with manual callable endpoint), `agentic-trading-intraday-cron.ts` (hourly and 15-min intervals).
- Backtesting function: `src/robinhood_options_mobile/functions/src/backtesting.ts` (runBacktest callable function for historical simulation).
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
