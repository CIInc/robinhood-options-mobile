## 2025-03-21 - Missing Input Sanitization and Path Traversal Risk on Futures Signal Endpoint
**Vulnerability:** In `agentic-futures-trading.ts`, callable function `getFuturesSignals` and `performFuturesSignal` accepted `symbol`, `contractId`, and `interval` parameters without format validation or character constraints. Unsanitized `contractId` and `interval` strings were interpolated directly into Firestore document keys (`signals/${contractId}_${interval}`), exposing the backend to path traversal and collection pollution. Furthermore, catch blocks returned raw error messages `(err as Error).message`, leaking internal implementation details.
**Learning:** Document path identifiers composed dynamically from callable user inputs must be constrained via strict alphanumeric regexes (`/^[A-Za-z0-9=.-]{1,20}$/`) and parameter enums whitelisted before querying or writing to Firestore. Exceptions must distinguish expected `HttpsError` instances from unhandled internal errors to prevent leaking database or runtime exceptions.
**Prevention:** Strictly validate string formats against allowed regexes, whitelist interval values, throw structured `HttpsError("invalid-argument", ...)` upon validation failure, and sanitize unexpected errors with `HttpsError("internal", ...)` while re-throwing `HttpsError` instances.

## 2025-03-20 - Unbounded Symbol Array and Generic Error Throwing in Heavy Backtest Callable
**Vulnerability:** In `backtesting.ts`, callable function `runBacktest` accepted an unbounded `symbolFilter` array and unvalidated date strings, throwing unhandled generic `Error` instances instead of structured `HttpsError`s. Malicious or excessive symbol arrays could spawn hundreds of concurrent external market data requests and CPU-intensive simulations, triggering denial of service (DoS) and third-party API quota depletion (Denial of Wallet). Unsanitized exception re-throwing also risked masking intentional error statuses.
**Learning:** Simulation endpoints invoking external market data APIs across array inputs must enforce hard upper bounds on array sizes (e.g. `<= 30`), validate string formats via regex, and throw `HttpsError("invalid-argument", ...)` rather than standard `Error`s. Catch blocks must safely distinguish `HttpsError` from unexpected runtime errors to avoid leaking implementation details.
**Prevention:** Always bound input arrays, validate input schemas, use `HttpsError` for validation failures, and sanitize unexpected errors with `HttpsError("internal", ...)` while re-throwing existing `HttpsError` instances.

## 2025-03-20 - Missing Array Bounds and Input Sanitization on Options Flow Callable
**Vulnerability:** In `options-flow.ts`, callable function `getOptionsFlow` bound secret keys (`TWELVE_DATA_API_KEY`) and accepted `request.data.symbol` or `request.data.symbols` along with an optional `expiration` parameter without input sanitization or array upper bounds. Authenticated callers could supply arbitrary ticker formats or unbounded symbol arrays, triggering extensive upstream API and Firestore queries (Denial of Service / Quota Exhaustion / Resource Starvation).
**Learning:** Callable functions accepting array payloads for external data retrieval or batch processing must enforce strict upper limits (e.g. max 25 symbols), sanitize all ticker strings against regex constraints, and validate parameter enums against whitelists before dispatching third-party API or database queries.
**Prevention:** Strictly enforce array size limits (`Array.isArray(symbols) && symbols.length <= 25`), validate regex conformity on individual string elements, and validate optional filter parameters against enumerated allowlists in callable endpoints.

## 2025-03-19 - Missing Input Constraints and Authorization Error Masking on Options Flow Alert Callables
**Vulnerability:** In `options-flow.ts`, callable functions `createOptionAlert`, `toggleOptionAlert`, and `deleteOptionAlert` lacked input sanitization (allowing arbitrary symbols, negative/non-finite alert thresholds, non-string IDs, and non-boolean toggle states). Furthermore, catch blocks intercepted all errors and re-threw generic `internal` `HttpsError`s, masking `not-found` and `permission-denied` authorization status codes.
**Learning:** Catch-all exception handling in Firebase callable Cloud Functions inadvertently converts intentional security status codes (`permission-denied`, `not-found`, `invalid-argument`) into `internal` 500 errors, obfuscating access control violations from client audit logs.
**Prevention:** Strictly validate string formats/lengths, positive finite numbers, and primitive types prior to Firestore interactions, and always re-throw `if (error instanceof HttpsError)` in callable exception blocks.

## 2025-03-19 - Missing Admin Authorization on Administrative Chart Seeding Callable
**Vulnerability:** `seedAgenticTrading` in `agentic-trading.ts` was an `onCall` Cloud Function that verified `request.auth` but lacked admin custom claim authorization (`role === "admin"`). Authenticated non-admin callers could trigger batch document creations in the top-level `/charts` collection and force chart document re-seeding across popular stock symbols.
**Learning:** Administrative utility callables that perform batch collection modifications or seed system resources must verify `request.auth.token?.role === "admin"` in addition to basic authentication (`request.auth`).
**Prevention:** Always enforce `if (request.auth.token?.role !== "admin")` on administrative seeding and setup callable functions.

## 2025-03-19 - Missing Array Bounds Validation on Order Sync Callable
**Vulnerability:** `syncInstrumentOrders` in `instrument-order-sync.ts` accepted `request.data.orders` without validating upper bounds on array length. An authenticated user could supply an arbitrarily large array of orders, triggering high memory consumption, long execution times, and excessive batch Firestore write operations (Denial of Service / Resource Exhaustion).
**Learning:** Callable Cloud Functions accepting arrays of items to write to Firestore in batch operations must bound input array lengths to prevent memory bloat, long execution, and database write exhaustion.
**Prevention:** Enforce a hard maximum upper bound on array parameters (e.g. `MAX_ORDERS_PER_SYNC = 500`) in callable functions before iterating or processing batch database writes.

## 2025-03-18 - Missing Input Array Bounds and Object Type Validation on Heavy Analysis Callable
**Vulnerability:** `discoverAlphaFactors` in `alpha-factor-discovery.ts` was an `onCall` Cloud Function with 512MiB memory and 300s timeout that accepted `request.data.factors` and `request.data.symbols` without bounds checking or array validation. Passing non-array values caused unhandled `TypeError` exceptions, while passing arbitrarily large arrays caused CPU/Memory exhaustion and Denial of Service (DoS) / Denial of Wallet.
**Learning:** High-memory computation functions accepting complex nested arrays must strictly validate array types (`Array.isArray`), non-emptiness, and cap element limits (e.g. `factors.length <= 50`, `symbols.length <= 50`).
**Prevention:** Validate input array types and enforce hard upper bounds on element counts before iterating or spawning concurrent sub-tasks in Cloud Functions.

## 2025-03-18 - Missing Active Group Membership Verification on Group Watchlist Operations
**Vulnerability:** Group watchlist management functions (`deleteGroupWatchlist`, `addSymbolToWatchlist`, `removeSymbolFromWatchlist`, `createPriceAlert`, `deletePriceAlert`, `setWatchlistMemberPermission`, `removeWatchlistMemberPermission`) in `group-watchlists.ts` checked watchlist-level creator/editor permissions but failed to verify active membership in the parent `investor_groups` group. Removed or former group members retained persistent ability to alter symbols, alerts, permissions, or delete watchlists.
**Learning:** Subcollection resource permission checks (e.g. `watchlists.permissions[uid]`) must always validate active membership in the parent entity (`investor_groups.members.includes(uid)`). Stale permissions stored on child documents can lead to privilege retention when users leave or are removed from parent groups.
**Prevention:** Enforce a parent group membership check (`ensureGroupMember(groupId, userId)`) on all callable functions accessing or modifying group subcollection resources.

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
