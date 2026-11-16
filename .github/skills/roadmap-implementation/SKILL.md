---
name: roadmap-implementation
description: "Choose and implement the next suitable RealizeAlpha roadmap item by weighing ROADMAP.md against open GitHub issues, then verify the implementation and reconcile local roadmap status."
---

# Roadmap Implementation

Select one valuable, implementable item from the RealizeAlpha roadmap and
open GitHub issues, implement it end to end, and report the evidence for the
selection and verification. Use this workflow when asked to work on the next
roadmap item, pick the next feature, or continue planned product work.

## Argument Hint

Optional constraints or a roadmap area to prioritize (for example, "focus on portfolio analytics", "options flow", or "pick the smallest safe item").

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
   proposals. Prioritize candidates in this order:
   - Explicit user constraints supplied with this prompt (e.g., focus area or specific capability)
   - Items tied to an active, high-priority open GitHub issue
   - The earliest unreleased version or active milestone
   - A concrete item with a clear existing code owner and manageable scope
   - Dependencies and safety: prefer work that can be implemented and tested without credentials, production data, or unrelated migrations
   - User value, then smallest independently testable and shippable slice

4. **Choose one item and state the rationale.** Before coding, briefly identify
   the selected roadmap entry and/or issue, its acceptance criteria, relevant
   dependencies, and why it is the best ready candidate. State a short hypothesis
   about the missing behavior and one focused check that could disprove it. If no
   candidate is actionable, explain the blocker rather than inventing work. Ask the user
   only when a material product, financial safety, risk limit, or broker integration
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

   Add or update focused unit and widget tests for the new behavior. Fix
   regressions caused by this change; do not rewrite unrelated failures.
   When requested by the user to commit, reference the associated GitHub issue in
   commit messages (e.g., `feat: ... (#<issue-num>)` or `closes #<issue-num>`).
   Do not commit, push, deploy, or mutate GitHub issue states unless explicitly
   requested.

6. **Reconcile local documentation.**
   - **Update Documentation & PRODUCT.md**: Add or update dedicated feature documentation
     in `docs/` (architecture, algorithms, configuration, or operational guides)
     whenever user-visible behavior, risk models, services, or workflows change.
     Update `PRODUCT.md` to reflect new product capabilities, domain models, or
     architectural additions. Update `README.md`, `.github/copilot-instructions.md`,
     or `CHANGELOG.md` when user-facing features, configuration keys, or developer
     conventions change. When updating `CHANGELOG.md`, group entries into standard
     categories (`Added`, `Changed`, `Fixed`, `Performance`) and link verified GitHub
     issues (`[#<num>](https://github.com/CIInc/robinhood-options-mobile/issues/<num>)`).
   - **Technical Accuracy & Link Consistency**: Verify that documented file paths,
     class names, API signatures, and configuration keys match the implementation
     across `src/robinhood_options_mobile/`, `src/robinhood_options_mobile/functions/`,
     and `src/robinhood_options_mobile/firebase/`. Validate relative markdown links
     and section anchors between touched documentation files.
   - **Firestore Rules & Composite Indexes**: If the feature introduces new Firestore
     collections, schema changes, or complex queries (e.g. multi-field ordering or filtering),
     ensure `src/robinhood_options_mobile/firebase/firestore.rules` is updated
     (delegate authoring to the `firestore-rules-author` subagent) and composite indexes
     are registered in `src/robinhood_options_mobile/firebase/firestore.indexes.json`.
   - **Update ROADMAP.md & Limit Completed Features Size**: Update `ROADMAP.md` only
     when the selected work corresponds to an entry and its completion is verified.
     Mark the task complete (`[x]`) and ensure the GitHub issue link
     (`[#<num>](https://github.com/CIInc/robinhood-options-mobile/issues/<num>)`)
     is included. Do not mark a parent item complete while child tasks remain.
     Keep `## Completed Features ✅` bounded in size: maintain focus on high-level
     capability blocks for recent minor releases, and consolidate or summarize older
     granular historical items so the roadmap remains readable and executive-focused,
     deferring exhaustive chronological version notes to `CHANGELOG.md`. Reconcile
     `Quick Stats` (completed vs planned counts) accordingly.
   - **GitHub Issue Reconciliation**: If explicitly requested by the user, close or
     update the associated GitHub issue (`gh issue close <num>`) once verification passes.

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
     *(Functions enforce Google ESLint rules with `max-len <= 80`; run `npm run lint -- --fix` to auto-resolve mechanical line-length and lint issues.)*
   - If connected to a running Flutter session, perform hot reload or hot restart
     to verify UI rendering.
   - Review the final diff for accidental generated files, secrets, unrelated
     formatting, and incomplete references, ensuring unrelated worktree changes
     remain untouched.

## Completion Report

Report:
- The selected roadmap item and/or issue link, and why it was chosen over other candidates
- Files modified and behavior delivered
- Tests and validation commands run, including any pre-existing failures
- Documentation updates made in `docs/`, `PRODUCT.md`, `README.md`, `.github/copilot-instructions.md`, and `ROADMAP.md` status/reconciliation
- GitHub issue update or closure status (if explicitly requested)
- Any remaining dependency, credential, or follow-up that prevents the item from being fully complete

