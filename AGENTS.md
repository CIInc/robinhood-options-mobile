# AGENTS.md — RealizeAlpha Coding Agent Guide

This file provides essential architectural context, safety invariants, and workflow rules for AI coding agents working in the **RealizeAlpha** (`robinhood-options-mobile`) repository.

For detailed file-by-file references, also consult [`.github/copilot-instructions.md`](.github/copilot-instructions.md), [`PRODUCT.md`](PRODUCT.md), and [`ROADMAP.md`](ROADMAP.md).

---

## 1. Repository Layout

- **`src/robinhood_options_mobile/`** — Flutter mobile & multi-platform application (Dart).
  - `lib/main.dart` — App entrypoint, Firebase initialization, `MultiProvider` wiring, `RemoteConfigService`, and `NavigationStatefulWidget`.
  - `lib/model/` — `ChangeNotifier` state stores (`PortfolioStore`, `OptionPositionStore`, `InstrumentPositionStore`, `FuturesPositionStore`, `ForexHoldingStore`, `AccountStore`, `BrokerageUserStore`, `AgenticTradingProvider`, `FuturesAutoTradingProvider`, `PortfolioAnalyticsController`, `InvestorGroupStore`, `PaperTradingStore`) and data models.
  - `lib/services/` — Brokerage implementations (`RobinhoodService`, `SchwabService`, `SchwabStreamerService`, `PaperService`, `DemoService`, `FidelityService`) behind `IBrokerageService`, plus domain engines (`TaxOptimizationService`, `RiskCircuitBreakerService`, `RiskCopilotService`, `CopyTradeRiskGuardianService`, `FeatureAccessService`, `SecureTokenStorage`, `GenerativeService`).
  - `lib/widgets/` — Screens, slivers, charts, order entry sheets, and progressive portfolio sections (`lib/widgets/portfolio/`).
  - `test/` — Unit and widget tests (`flutter_test`, `fake_cloud_firestore`, `mockito`).
- **`src/robinhood_options_mobile/functions/`** — Firebase Cloud Functions v2 backend (TypeScript, Node.js).
  - `src/` — Agentic trading crons, 19-indicator technical evaluation (`technical-indicators.ts`), backtesting (`backtesting.ts`), GEX calculation (`gamma-exposure.ts`), options flow (`options-flow.ts`), SEC EDGAR (`sec-edgar.ts`), Congress trading (`congress-trading.ts`), copy trading (`copy-trading.ts`), Gemini AI callables (`gemini.ts`), and macro assessment (`macro-agent.ts`).
  - `tests/` — Jest backend unit tests.
- **`src/robinhood_options_mobile/firebase/`** — Firestore security rules (`firestore.rules`), composite indexes (`firestore.indexes.json`), and admin scripts.
- **`docs/`** — Feature documentation, architecture guides, and market data research.

---

## 2. Core Safety, Privacy & Trading Invariants

1. **Zero Plaintext Credentials (`SecureTokenStorage`)**
   - Brokerage OAuth tokens and local MCP credentials must be stored exclusively via `SecureTokenStorage` (`lib/services/secure_token_storage.dart`) backed by `flutter_secure_storage` (iOS/macOS Keychain, Android Keystore).
   - Never write plaintext OAuth tokens, refresh tokens, or API keys to `SharedPreferences`, Firestore documents, or source code. Backend secrets belong in Google Cloud Secret Manager (`firebase functions:secrets:set`).

2. **Feature Access Precedence (`FeatureAccessService`)**
   - Capability resolution follows a strict 4-tier hierarchy (`lib/services/feature_access_service.dart`):
     1. Remote Config `disabled` kill switch denies all users (including admins).
     2. Explicit per-user `User.featureFlags` overrides.
     3. `adminOnly` stage requires admin role **plus** explicit opt-in; `public` defaults on unless opted out; `beta` requires self-serve Beta Labs opt-in (`BetaLabsWidget`).
   - Keep local preferences, the in-memory `User` model, and Firestore synchronized when toggling beta flags.

3. **Auto-Trade & Order Execution Safeguards**
   - **Live-Quote BUY Guard:** `AgenticTradingProvider` validates stored signal prices against a fresh live quote before executing automatic or approved BUYs. Price deviations $> 3\%$ or quote-fetch failures block execution.
   - **Authoritative Trade Sizing:** In Reasoning mode, when `enableDynamicPositionSizing` is `false`, the user's configured `tradeQuantity` is authoritative; AI-suggested sizing is used only when dynamic sizing is enabled, and `RiskGuard` limits always apply.
   - **Config Persistence Isolation:** `FirestoreService.updateUser` intentionally omits `agenticTradingConfig` and `futuresTradingConfig` so profile updates never overwrite trading settings with stale in-memory objects. Save trading configs only through their respective providers.
   - **Aggregate View Trading Block:** When viewing aggregated multi-account positions (`disableNavigation: true`), order placement and roll actions must remain disabled with a clear explanatory `SnackBar`.
   - **Risk Circuit Breakers:** Manual and semi-automated order tickets (`TradeInstrumentWidget`, `TradeOptionWidget`, `PositionOrderWidget`) must respect `RiskCircuitBreakerService` lockouts (daily max loss, drawdown limit, consecutive losses, and behavioral tilt cooling-off periods), while simulated paper trades bypass live account lockouts.

4. **Balance Visibility & Social Privacy**
   - Respect `AccountStore` balance masking across all portfolio hero numbers, position rows, and chart components (`portfolio_chart_widget.dart` axes, range annotations, tooltips, and summary metrics).
   - Cross-account tax and wash-sale correlation must run on-device over hydrated stores without leaking private multi-broker tax lots to shared Firestore collections.

5. **Backend Security & Algorithmic Efficiency**
   - Every callable Cloud Function (`onCall`) and HTTP cron endpoint in `functions/src/` must verify `request.auth` (and `request.auth.token.role === 'admin'` for admin/diagnostic endpoints) and validate all client inputs (identifiers, symbols, positive finite numbers, date strings) before reading or writing Firestore.
   - Technical indicator evaluations in `functions/src/technical-indicators.ts` and backtest loops in `functions/src/backtesting.ts` must preserve $O(1)$ auxiliary space using index-bounded loops (`endIndex`) and scalar state rather than allocating intermediate `.slice()` arrays or transient `Date` objects per bar.

6. **Accessibility & UI Polish**
   - Consolidate complex financial rows (options flow items, retirement projections, slippage cards, animated prices) into natural spoken screen-reader announcements using `Semantics` and `semanticsLabel`.
   - Maintain responsive layouts down to `320px`–`360px` viewports without `RenderFlex` overflows.

---

## 3. Build, Test & Verification Commands

- **Run targeted Flutter tests (preferred):**
  ```bash
  cd src/robinhood_options_mobile && flutter test test/<specific_test_file>.dart
  ```
  *(Avoid running the full `flutter test` suite at once, as it is large and slow; run only impacted test files.)*
- **Static analysis & formatting (Flutter/Dart):**
  ```bash
  cd src/robinhood_options_mobile && dart analyze && dart format --output=none --set-exit-if-changed .
  ```
- **Cloud Functions lint, build & test:**
  ```bash
  cd src/robinhood_options_mobile/functions && npm run lint && npm run build && npm test
  ```
  *(Note: `functions/` enforces Google ESLint rules including `max-len <= 80`; use `npm run lint -- --fix` when needed.)*

---

## 4. Planning, Roadmap & Documentation Workflows

- **Roadmap Ideation (`.github/skills/roadmap-ideation/SKILL.md`):** Compare `ROADMAP.md`, `PRODUCT.md`, and open/closed GitHub issues (`gh issue list`) to propose evidence-backed roadmap items. Record user-selected items in `ROADMAP.md` before creating/linking GitHub issues, and never implement features during ideation.
- **Roadmap Execution (`.agents/skills/roadmap/SKILL.md`):** Pick the highest-priority actionable unchecked (`- [ ]`) item from `ROADMAP.md`, inspect linked GitHub issues (`gh issue view <num>`), implement end-to-end with unit/widget tests, update docs, and mark `[x]` when verified.
- **Documentation Sync (`.agents/skills/update-docs/SKILL.md`):** Reconcile `ROADMAP.md`, `CHANGELOG.md`, `README.md`, `docs/`, `.github/copilot-instructions.md`, and `pubspec.yaml` with recent commits and GitHub issue states.
