---
name: roadmap
description: Select the highest-priority actionable feature from ROADMAP.md and implement it end to end with tests, documentation, and roadmap updates.
argument-hint: Optional constraints or a roadmap area to prioritize (for example, "focus on portfolio analytics" or "pick the smallest safe item").
---

Use the repository roadmap as the source of truth for the next implementation task.

## Workflow

1. Read `ROADMAP.md` and identify unchecked (`[ ]`) implementation items. Treat items already marked complete, release notes, risks, and speculative future vision as context rather than work to implement.
2. Choose one item using this priority order:
   - Explicit user constraints supplied with this prompt
   - The earliest unreleased version or active milestone
   - A concrete item with a clear existing code owner and manageable scope
   - Dependencies and safety: prefer work that can be implemented and tested without credentials, production data, or unrelated migrations
   - User value, then smallest independently shippable slice
3. Before editing, inspect the owning implementation, nearby tests, and relevant repository instructions. State a short hypothesis about the missing behavior and one focused check that could disprove it.
4. Implement the selected item end to end, keeping the change focused and following existing Flutter, Dart, Firebase, and TypeScript patterns. Do not implement multiple unrelated roadmap items in one run.
5. Add or update focused tests for the changed behavior. Keep secrets, brokerage credentials, and sensitive operations server-side where the repository requires it.
6. Run the narrowest useful validation first, then any required formatter, analyzer, lint, or build command for the touched code. Fix regressions caused by this change; do not rewrite unrelated failures.
7. Update documentation when the feature changes user-visible behavior, configuration, architecture, or operational steps. Mark the selected roadmap item complete only when the implementation is actually validated. Preserve the roadmap's existing wording and checkbox style.
8. Review the final diff for accidental generated files, secrets, unrelated formatting, and incomplete references.

## Completion Report

Report:

- The roadmap item selected and why it was the best actionable choice
- Files changed and the behavior delivered
- Tests and validation commands run, including any pre-existing failures
- Documentation and `ROADMAP.md` updates
- Any remaining dependency, credential, or follow-up that prevents the item from being fully complete
