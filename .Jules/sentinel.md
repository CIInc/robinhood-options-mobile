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
