# Testing Standards

This document outlines the required testing patterns and development standards for the RealizeAlpha codebase.

## 1. UI Testing Requirement (Integration Tests)
- **Rule**: ALL changes must be UI tested. 
- **Guideline**: Do not stop at unit tests; verify the end-to-end user experience (UX) to ensure no regressions in visual feedback, navigation, or state synchronization.
- **Scope**: Integration tests should cover:
    - UI component behavior, animations, and responsiveness.
    - User journey transitions (e.g., Guest to Authenticated).
    - Data persistence and state synchronization across views (Search, Portfolio, Settings).
    - Multi-account aggregation and switching states.
- **Reference**: See existing integration tests in [integration_test/](integration_test/) for implementation patterns.

## 2. Handling State & Race Conditions
- **Persistence & Identity**: Features requiring persistent storage (Firestore) must ensure a valid identity exists. When bootstrapping new sessions, use mechanisms like `ensureFirebaseUserSession` to avoid silent data loss for guests.
- **Race Condition Resilience**: Services and state stores should be resilient to race conditions during session initialization. 
    - **Pattern**: Always check for document existence or catch `not-found` exceptions during initial background sync tasks (e.g., updating `lastVisited` or fetching preference subsets).
- **Trigger Logic**: Strategy-specific initialization logic (like paper trading startup) should be placed in navigation or feature-specific callbacks rather than global utilities to avoid side effects for ephemeral states (Demo).

## 3. Data Integrity & Security Patterns
- **User Root Match**: Follow the consolidated hierarchical pattern in `firestore.rules` for the user tree to ensure consistent access control across all sub-collections:
    ```javascript
    match /user/{uid} {
      match /{collectionId}/{id} {
        allow read: if request.auth.uid != null;
        allow write: if request.auth.uid == uid || request.auth.token.role == 'admin';
      }
    }
    ```
- **Permission Mapping**: Identity-specific sub-collections (notes, alerts, private notifications) must be strictly matched to `request.auth.uid == uid`. Shared or position-related data should follow the broader authenticated read pattern to support multi-account and group features.

## 4. Documentation & Lessons Learned
- **Rule**: When resolving a significant logic flaw or race condition, document the "Error Pattern" and "Lesson Learned" here or in relevant feature docs to prevent regressions.
- **Verification**: New features must include a corresponding test file in `integration_test/` or `test/` that exercises the fix under simulated constraints (e.g., guest state, network delays).

