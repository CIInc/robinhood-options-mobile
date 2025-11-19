### Purpose
This file tells AI coding agents how to be immediately productive in the RealizeAlpha (robinhood-options-mobile) codebase.

Keep guidance concise and actionable. Only change behavior when confident and follow the repository conventions below.

Key facts (quick):
- Flutter mobile app (Dart) in `src/robinhood_options_mobile/`.
- Backend helpers and server code live under `src/robinhood_options_mobile/functions/` and `src/robinhood_options_mobile/firebase/` (Firebase Functions + admin tooling).
- Firebase is heavily used: `firebase_core`, `firebase_auth`, `cloud_firestore`, `cloud_functions`, `firebase_analytics`, and `firebase_ai`.

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
- Trade Signals: Agentic trading with multi-indicator correlation managed by `AgenticTradingProvider` in `lib/model/agentic_trading_provider.dart`. Trade signals stored in Firestore `agentic_trading/signals_{SYMBOL}` (daily) or `signals_{SYMBOL}_{INTERVAL}` (intraday) with server-side filtering and real-time Firestore snapshot listeners. Backend logic in `functions/src/agentic-trading.ts`, `functions/src/agentic-trading-cron.ts`, `functions/src/agentic-trading-intraday-cron.ts`, `functions/src/alpha-agent.ts`, and `functions/src/riskguard-agent.ts`. Supports multiple intervals (15m, 1h, 1d) with DST-aware market hours detection and visual market status indicators.
- Investor Groups: Collaborative portfolio sharing managed by `InvestorGroupStore` in `lib/model/investor_group_store.dart`. Groups stored in Firestore `investor_groups/{groupId}` with 15+ service methods in `FirestoreService`. Supports public/private groups, member management, real-time invitation system (send/accept/decline/cancel), admin controls (promote/demote/remove), and direct portfolio viewing for private group members. UI includes 3-tab admin interface (Members, Pending, Invite).

Patterns & conventions (concrete examples):
- State containers are `ChangeNotifier` classes under `lib/model` and provided via `MultiProvider` in `main.dart`. Example: `PortfolioHistoricalsStore` and its selection store `PortfolioHistoricalsSelectionStore` are paired.
- Naming: files and classes follow lower_snake_case for filenames and UpperCamelCase for Dart classes; maintain this convention.
- Firestore: the app sometimes uses the Firestore emulator flag `shouldUseFirestoreEmulator` (in `main.dart`) — if you add local-only rules or tests, toggle that flag or wire a configuration value.
- Real-time subscriptions: Use `StreamSubscription` for Firestore snapshot listeners and always implement `dispose()` in providers to cancel subscriptions (see `AgenticTradingProvider` for reference pattern).
- Ads & analytics: AdMob and FirebaseAnalytics are initialized in `main.dart` — changes to analytics events should reuse `FirebaseAnalytics.instance`.

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
- State & model examples: `src/robinhood_options_mobile/lib/model/portfolio_store.dart`, `option_position_store.dart`, `generative_provider.dart`, `agentic_trading_provider.dart` (includes real-time Firestore subscriptions), `investor_group_store.dart`.
- Trade signals UI: `src/robinhood_options_mobile/lib/widgets/search_widget.dart` (filter chips, signal display, market status indicator), `instrument_widget.dart` (single signal view, interval selector, market status banner).
- Investor Groups UI: `src/robinhood_options_mobile/lib/widgets/investor_groups_widget.dart` (main 3-tab layout), `investor_group_detail_widget.dart` (member list, portfolio navigation), `investor_group_manage_members_widget.dart` (admin 3-tab interface: Members/Pending/Invite), `investor_group_create_widget.dart` (creation form).
- Firebase Functions entry: `src/robinhood_options_mobile/functions/` (look for `index.ts` or `lib/` depending on TS/JS layout).
- Backend cron jobs: `src/robinhood_options_mobile/functions/src/agentic-trading-cron.ts` (daily EOD with manual callable endpoint), `agentic-trading-intraday-cron.ts` (hourly and 15-min intervals).
- Firestore indexes: `src/robinhood_options_mobile/firebase/firestore.indexes.json` (deploy with `firebase deploy --only firestore:indexes`).
- Firestore rules: `src/robinhood_options_mobile/firebase/firestore.rules` (includes investor_groups rules for public/private access, invitation permissions).

Quick safety checklist before proposing changes:
1. Does the change expose secrets or API keys? If yes, move to `functions/` + use `firebase secrets`.
2. Does the change modify provider/state classes? Add/update unit tests.
3. Is this change for native iOS/Android platform code? Verify `flutter build <platform>` and check README notes.
4. Avoid editing generated files under `build/`.

If you need more context, open these files first:
- `src/robinhood_options_mobile/lib/main.dart`
- `src/robinhood_options_mobile/pubspec.yaml`
- `src/robinhood_options_mobile/README.md`
- `src/robinhood_options_mobile/functions/package.json`
- `src/robinhood_options_mobile/firebase/firebase-admin.js`

If anything here is unclear or you'd like additional project-specific rules (testing patterns, CI instructions, or preferred branching), ask the maintainer and include a short proposed change for review.
