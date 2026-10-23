## 2025-03-18 - Missing Input Array Bounds and Object Type Validation on Heavy Analysis Callable
**Vulnerability:** `discoverAlphaFactors` in `alpha-factor-discovery.ts` was an `onCall` Cloud Function with 512MiB memory and 300s timeout that accepted `request.data.factors` and `request.data.symbols` without bounds checking or array validation. Passing non-array values caused unhandled `TypeError` exceptions, while passing arbitrarily large arrays caused CPU/Memory exhaustion and Denial of Service (DoS) / Denial of Wallet.
**Learning:** High-memory computation functions accepting complex nested arrays must strictly validate array types (`Array.isArray`), non-emptiness, and cap element limits (e.g. `factors.length <= 50`, `symbols.length <= 50`).
**Prevention:** Validate input array types and enforce hard upper bounds on element counts before iterating or spawning concurrent sub-tasks in Cloud Functions.

## 2025-03-17 - Missing Input Length Validation on HTTP Proxy Endpoint
**Vulnerability:** `yahooProxy` in `yahoo-proxy.ts` validated domain origin for proxied URLs but allowed arbitrarily long query parameters (`req.query.url`). Extremely large URL inputs could lead to excessive memory allocation during SHA-256 hashing, caching, and upstream proxying (DoS / Resource Exhaustion risk).
**Learning:** Proxy endpoints accepting external URL target strings must constrain input string lengths in addition to hostname whitelisting to mitigate memory bloat and hash computation DoS.
**Prevention:** Enforce a hard maximum input length limit (e.g. `MAX_URL_LENGTH = 2048`) on target URL strings before parsing or processing upstream proxy requests.

## 2025-03-16 - Missing Authentication & Admin Authorization on Watchlist Alerts Cron Endpoint
**Vulnerability:** `checkWatchlistAlerts` in `watchlist-alerts-cron.ts` was an unauthenticated `onRequest` Cloud Function that allowed public HTTP callers to manually trigger watchlist alert scans, triggering external market data API calls, multi-user FCM notification dispatches, and Firestore state updates (`lastTriggered`).
**Learning:** `onRequest` HTTP functions exposing ad-hoc cron triggers or notification dispatching must verify Firebase Auth Bearer ID tokens and admin custom claims (`role === "admin"`).
**Prevention:** Verify `request.headers.authorization` with `getAuth().verifyIdToken(token)` and `role === "admin"` on all ad-hoc cron or administrative HTTP `onRequest` endpoints.

## 2025-03-15 - Missing Authorization and Information Disclosure on Signal Diagnostics HTTP Endpoint
**Vulnerability:** `signalDiagnostics` in `signal-diagnostics.ts` was an unauthenticated `onRequest` Cloud Function that allowed public HTTP callers to inspect internal Firestore trade signals and chart cache data, and leaked internal stack traces/database error details on exception via `String(error)`.
**Learning:** `onRequest` functions exposing internal technical diagnostic data must verify Firebase Auth Bearer ID tokens and admin claims (`role === "admin"`). Additionally, 500 exception handlers on HTTP Cloud Functions must sanitize error payloads to prevent sensitive database details or stack traces from reaching clients.
**Prevention:** Verify `request.headers.authorization` with `getAuth().verifyIdToken(token)` and `role === "admin"` on all diagnostic `onRequest` functions, and catch errors securely with sanitized static response payloads.

## 2025-03-14 - Missing Authentication & Admin Authorization on HTTP Diagnostic and Ad-Hoc Cron Endpoints
**Vulnerability:** `cronDiagnostics` in `cron-diagnostics.ts` and `agenticTradingCronInvoke` in `agentic-trading-cron.ts` were public unauthenticated `onRequest` Cloud Functions. Unauthenticated callers could view sensitive internal Firestore diagnostic counts, system configuration parameters, or trigger resource-intensive multi-document EOD agentic trading cron jobs.
**Learning:** Firebase v2 `onRequest` Cloud Functions do not parse or enforce `request.auth` automatically unlike `onCall` functions. HTTP endpoints exposing administrative diagnostics or ad-hoc cron triggers must manually parse `request.headers.authorization` Bearer tokens, verify them using `getAuth().verifyIdToken(token)`, and check custom claim roles (`role === "admin"`).
**Prevention:** For all `onRequest` HTTP endpoints performing administrative functions or exposing internal state, manually extract and verify the Authorization Bearer header with `getAuth().verifyIdToken(token)` and enforce `decodedToken.role === "admin"` before executing handler logic.

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
