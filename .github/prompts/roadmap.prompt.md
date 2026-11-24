---
name: roadmap
description: Select the highest-priority actionable feature from ROADMAP.md and implement it end to end with tests, documentation, and roadmap updates through a staged Maker-Verifier-Critic loop.
argument-hint: Optional constraints or a roadmap area to prioritize (e.g., "focus on portfolio analytics", "mode=autonomous", or "pick the smallest safe item").
---

# Roadmap Implementation

Use the repository roadmap as the source of truth for the next implementation task, executing via a staged Maker-Verifier-Critic loop. For autonomous multi-item execution, refer to the `software-factory` skill (`.github/skills/software-factory/SKILL.md`).

## Workflow

1. Read `ROADMAP.md` and identify unchecked (`[ ]`) implementation items, cross-referencing with open GitHub issues (`gh issue list`). Treat items already marked complete, release notes, risks, and speculative future vision as context rather than work to implement.
2. Choose one item using this priority order:
   - Explicit user constraints supplied with this prompt
   - Items tied to an active, high-priority open GitHub issue
   - The earliest unreleased version or active milestone
   - A concrete item with a clear existing code owner and manageable scope
   - Dependencies and safety: prefer work that can be implemented and tested without credentials, production data, or unrelated migrations
   - User value, then smallest independently shippable slice
3. Before editing, inspect the owning implementation, nearby tests, relevant repository instructions, and any linked GitHub issue (e.g., via `gh issue view <number>`). Note the issue's acceptance criteria, constraints, and discussions. State a short hypothesis about the missing behavior and one focused check that could disprove it.
4. **Stage 1 (Maker):** Implement the selected item end to end, keeping the change focused and following existing Flutter, Dart, Firebase, and TypeScript patterns. Add or update focused tests for the changed behavior.
5. **Stage 2 (Self-Healing Quality Gate):** Run the narrowest useful validation first, then required formatters, analyzers, and linters:
   - Flutter: `dart format --output=none --set-exit-if-changed .`, `dart analyze`, and `flutter test test/<impacted_test>.dart`
   - Functions: `npm run lint`, `npm run build`, and `npm test` in `src/robinhood_options_mobile/functions/`
   Apply automated self-healing fixes for regressions caused by this change (up to 3 retries).
6. **Stage 3 (Adversarial Critic):** Audit the changes against RealizeAlpha's 7 Core Safety Invariants (Zero Plaintext Credentials, FeatureAccess hierarchy, Live-quote BUY guard & Paper isolation, Balance masking, Cloud Functions $O(1)$ space, Accessibility & 320px responsive UI, Clean compile & strict typing).
7. **Stage 4 (Reconciler):** Update documentation when the feature changes user-visible behavior, configuration, architecture, or operational steps:
   - Add or update dedicated feature documentation in `docs/` and update `PRODUCT.md` with new capabilities, domain models, or architecture. Update `README.md`, `CHANGELOG.md`, or `.github/copilot-instructions.md` as needed.
   - Mark the selected roadmap item complete (`[x]`) in `ROADMAP.md` only when the implementation is actually validated, and ensure the GitHub issue link (`[#<num>](https://github.com/CIInc/robinhood-options-mobile/issues/<num>)`) is present.
   - Keep `## Completed Features ✅` and `### Key Highlights` bounded in size in `ROADMAP.md`: maintain focus on high-level capability blocks for recent active minor releases, and consolidate or summarize older historical entries so the document remains concise and executive-focused, deferring exhaustive chronological version notes to `CHANGELOG.md`. Reconcile `Quick Stats` accordingly.
8. **Stage 5 (Git & Issue Lifecycle):**
   - In `interactive` mode (default): review the final diff for accidental generated files, secrets, unrelated formatting, and present to the user without committing or closing issues.
   - In `autonomous` mode: create a conventional commit referencing the issue (e.g. `feat: ... (#<issue-num>)`), add test evidence to the GitHub issue, and close it (`gh issue close <num>`).

## Completion Report

Report:
- The roadmap item and associated GitHub issue(s) selected, and why it was the best actionable choice
- Execution mode (`interactive` vs. `autonomous`)
- Files changed and the behavior delivered
- Tests and validation commands run, including self-healing retry count
- Adversarial critic invariant checklist confirmation
- Documentation updates made in `docs/`, `PRODUCT.md`, and other markdown files, as well as `ROADMAP.md` and GitHub issue status updates
- Any remaining dependency, credential, or follow-up that prevents the item from being fully complete
