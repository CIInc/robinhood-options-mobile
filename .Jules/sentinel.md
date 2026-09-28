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
