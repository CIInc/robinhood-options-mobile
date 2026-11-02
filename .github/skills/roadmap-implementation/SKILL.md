---
name: roadmap-implementation
description: "Choose and implement the next suitable RealizeAlpha roadmap item by weighing ROADMAP.md against open GitHub issues, then verify the implementation and reconcile local roadmap status."
---

# Roadmap Implementation

Select one valuable, implementable item from the RealizeAlpha roadmap and
open GitHub issues, implement it end to end, and report the evidence for the
selection and verification. Use this workflow when asked to work on the next
roadmap item, pick the next feature, or continue planned product work.

## Workflow

1. **Understand the current worktree and project rules.** Read `AGENTS.md`,
   `PRODUCT.md`, and any domain-specific documentation in `docs/`. Run
   `git status --short` and inspect the current branch. Preserve all existing
   changes; do not overwrite, stage, or revert unrelated work. Note the project layout:
   - Flutter mobile app in `src/robinhood_options_mobile/`
   - Cloud Functions backend in `src/robinhood_options_mobile/functions/`
   - Firestore security rules and configuration in `src/robinhood_options_mobile/firebase/`

2. **Gather GitHub issue candidates.** Determine the repository context
   (`https://github.com/CIInc/robinhood-options-mobile`). When GitHub CLI
   access is available, list open issues with their titles, bodies, labels,
   URLs, milestones, and update times:
   ```bash
   gh issue list --state open --limit 1000 --json number,title,body,url,labels,milestone,updatedAt
   ```
   Otherwise use available GitHub tools. Read candidate issue details and comments
   (e.g., `gh issue view <num>`) to clarify scope, constraints, and dependencies.
   If issues cannot be accessed, state that limitation clearly and proceed using
   `ROADMAP.md`.

3. **Build and rank a small candidate set.** Include unchecked (`[ ]`),
   actionable roadmap tasks and relevant open issues. Treat a roadmap task and
   issue as one candidate when they describe the same work. Exclude completed
   items, closed issues, duplicates, blocked work, and speculative future
   proposals. Prioritize candidates that:
   - Address an active, high-priority open GitHub issue
   - Align with the current milestone or earliest unreleased version
   - Have clear acceptance criteria and code ownership
   - Deliver high user value in a safe, independently testable slice

4. **Choose one item and state the rationale.** Before coding, briefly identify
   the selected roadmap entry and/or issue, its acceptance criteria, relevant
   dependencies, and why it is the best ready candidate. If no candidate is
   actionable, explain the blocker rather than inventing work. Ask the user only
   when a material product, financial safety, risk limit, or broker integration
   decision is required; otherwise make conservative choices consistent with
   `PRODUCT.md` and `AGENTS.md`.

5. **Implement only that item.** Inspect the owning code path and neighboring
   tests, then make the smallest complete change that satisfies the criteria:
   - **Descriptive & Non-Advisory Trading**: Trading suggestions must remain
     descriptive and analytical; manual order tickets require user confirmation,
     and auto-trading must respect all safety gates.
   - **Zero Plaintext Credentials**: Store brokerage tokens exclusively via
     `SecureTokenStorage` (`flutter_secure_storage`). Never write secrets to
     `SharedPreferences` or Firestore.
   - **Auto-Trade & Order Safeguards**: Enforce live-quote BUY guards, dynamic
     sizing limits, circuit breaker lockouts, and aggregate multi-account view locks.
   - **Privacy & Masking**: Respect balance masking across portfolio widgets and
     keep multi-broker tax lots on-device.
   - **Cloud Functions Security & Efficiency**: Authenticate all callables, validate
     client inputs, and maintain $O(1)$ auxiliary space in technical indicator
     and backtest loops.
   - **Accessibility & Responsive UI**: Provide `Semantics` labels on financial rows
     and prevent layout overflows down to `320px` viewports.

   Add or update focused unit and widget tests for the new behavior. Do not commit,
   push, deploy, or mutate GitHub issue states unless explicitly requested.

6. **Reconcile local documentation.** Update `ROADMAP.md` only when the selected
   work corresponds to an entry and its completion is verified. Mark the task
   complete (`[x]`) and ensure the GitHub issue link
   (`[#<num>](https://github.com/CIInc/robinhood-options-mobile/issues/<num>)`)
   is included. Update `CHANGELOG.md` or `docs/` if user-visible behavior or
   configuration changed. Do not mark a parent item complete while child tasks remain.

7. **Verify the change.** Run the narrowest relevant checks first, following `AGENTS.md`:
   - **Flutter Mobile (`src/robinhood_options_mobile`):**
     ```bash
     cd src/robinhood_options_mobile && dart format --output=none --set-exit-if-changed .
     cd src/robinhood_options_mobile && dart analyze
     cd src/robinhood_options_mobile && flutter test test/<specific_test_file>.dart
     ```
   - **Cloud Functions Backend (`src/robinhood_options_mobile/functions`):**
     ```bash
     cd src/robinhood_options_mobile/functions && npm run lint
     cd src/robinhood_options_mobile/functions && npm run build
     cd src/robinhood_options_mobile/functions && npm test
     ```
   - If connected to a running Flutter session, perform hot reload or hot restart
     to verify UI rendering.
   - Review the final diff to ensure unrelated worktree changes remain untouched.

## Completion Report

Report the selected roadmap item and/or issue link, why it was chosen over other
candidates, the files modified and behavior delivered, validation commands run
and test results, and documentation/`ROADMAP.md` updates.