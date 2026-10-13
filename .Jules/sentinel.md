## 2025-03-14 - Missing Role-Based Authorization on Screener Universe Seeding Function
**Vulnerability:** `seedScreenerUniverseCall` in `screener-universe.ts` was an `onCall` Cloud Function with 1GiB memory, 540s timeout, and batch write privileges to the `instrument` Firestore collection that only checked `request.auth`, allowing any non-admin authenticated user to trigger heavy background processing and consume Twelve Data API credits.
**Learning:** Seeding and maintenance callable functions in Firebase v2 `onCall` require both `request.auth` and `request.auth.token?.role === "admin"` authorization checks to prevent regular users from triggering bulk database mutations and quota depletion.
**Prevention:** Always verify `request.auth.token?.role === "admin"` at the beginning of all batch seeding and administrative setup callable functions.

## 2025-03-13 - Missing Authentication on News Intelligence and Market Data Callable Functions
**Vulnerability:** `getNewsIntelligence` and `getWatchlistNewsIntelligence` in `news-intelligence.ts` and `getQuotesCall` in `market-data.ts` were `onCall` Cloud Functions that lacked `request.auth` checks. Unauthenticated callers could invoke these endpoints to execute database operations (`instrument_news` collection) and query Twelve Data market quotes API secrets.
**Learning:** Firebase v2 `onCall` functions default to unauthenticated access. Market data proxy endpoints and news sentiment aggregation functions writing or reading Firestore documents must enforce authentication checks to prevent unauthorized access and API quota consumption.
**Prevention:** Always validate `if (!request.auth || !request.auth.uid)` at the entry point of all market data and news analysis callable functions before querying external APIs or reading/writing Firestore documents.

## 2025-03-12 - Missing Authentication on Macro Agent Callable Functions
**Vulnerability:** `getMacroAssessmentCall` and `getMacroHistoryCall` in `macro-agent.ts` were `onCall` Cloud Functions binding `GEMINI_API_KEY` and `TWELVE_DATA_API_KEY` secrets without checking `request.auth`, allowing unauthenticated public callers to trigger LLM macro analysis, consume API tokens, and write macro assessments to Firestore.
**Learning:** Callable functions performing macroeconomic aggregation and Gemini AI analysis with persistent Firestore writes (`macro_assessments` collection) must strictly check `request.auth` to prevent unauthorized generation and API quota exhaustion.
**Prevention:** Always enforce `if (!request.auth || !request.auth.uid)` at the start of all macro agent callable functions before invoking LLM generation or reading/writing persistent assessments.

## 2025-03-11 - Missing Authentication on Heavy Compute & API Secret Callable Functions
**Vulnerability:** `runBacktest` in `backtesting.ts` was an unauthenticated `onCall` Cloud Function configured with high memory (`512MiB`), long timeout (`300s`), and access to `TWELVE_DATA_API_KEY` secrets. Unauthenticated callers could invoke compute-heavy backtesting simulations and deplete third-party API quotas.
**Learning:** High-memory and high-timeout callable functions using third-party API key secrets default to allowing public access in Firebase v2 `onCall` unless `if (!request.auth)` is explicitly enforced.
**Prevention:** Always validate `if (!request.auth)` at the entry point of all simulation or backtesting callable functions before calling external data providers or starting resource-intensive computations.

## 2025-03-10 - Missing Authentication on Gemini LLM Callable Functions
**Vulnerability:** `generateContent31`, `generateContent25`, and `analyzePriceTargets` in `gemini.ts` were `onCall` Cloud Functions binding `GEMINI_API_KEY` secrets without checking `request.auth`, enabling unauthenticated public callers to consume paid Gemini API tokens and write unverified AI analysis payloads to Firestore.
**Learning:** Functions exposing LLM generation APIs using paid key secrets (`GEMINI_API_KEY`) and writing to Firestore documents (`ai_analysis`) are high-value targets for quota depletion and data corruption if not protected by `request.auth`.
**Prevention:** Always enforce `if (!request.auth)` at the entry point of all LLM/generative callable functions before making third-party API calls or persisting documents.

## 2025-03-09 - Missing Authentication & Role Authorization on Callable Migration Functions
**Vulnerability:** `migrateSignalsDate` in `migrations.ts` was an unauthenticated `onCall` Cloud Function with batch Firestore write privileges and high timeout/memory limits, making it vulnerable to unauthorized execution and Denial of Wallet / DoS attacks.
**Learning:** Migration and administrative batch functions implemented as Firebase `onCall` Cloud Functions must check both `request.auth` and admin role (`request.auth.token?.role === "admin"`).
**Prevention:** Always enforce `request.auth` and custom claim checks (`role === 'admin'`) at the entry point of all system/migration maintenance functions.

## 2025-03-08 - Authentication checks on Callable Firebase Functions with API Secrets
**Vulnerability:** `initiateTradeProposal` and `seedAgenticTrading` in `agentic-trading.ts` did not verify `request.auth`, allowing unauthenticated public callers to invoke third-party APIs (Twelve Data / Gemini) using secret keys and mutate Firestore documents.
**Learning:** Firebase `onCall` Cloud Functions default to allowing unauthenticated invocation unless explicitly checked via `request.auth`.
**Prevention:** Always validate `if (!request.auth)` at the beginning of any callable function using secrets or performing sensitive updates.
