---
name: autopilot
description: Autonomous software factory agent: analyze codebase, open issues, and ROADMAP.md to implement the best next feature end to end through a Maker-Verifier-Critic loop.
argument-hint: Optional domain focus, specific issue number, or milestone (e.g. "agentic trading", "#344", or "v0.62.x").
---

# Autopilot: Autonomous Software Factory Agent

Execute an autonomous software factory iteration following `.github/skills/software-factory/SKILL.md` and `.github/skills/roadmap-implementation/SKILL.md`:

1. **Analyze & Triage**: Read `ROADMAP.md`, recent commits, and open GitHub issues (`gh issue list`) to identify the highest-priority actionable improvement or feature.
2. **Spec & Invariants**: Formulate acceptance criteria and identify the applicable safety invariants from `AGENTS.md`.
3. **Stage 1 (Maker)**: Implement the feature or improvement with focused tests, keeping changes aligned with existing Flutter/Dart and Firebase patterns.
4. **Stage 2 (Self-Healing Gate)**: Run `dart format`, `dart analyze`, and `flutter test` (and `npm run lint && npm run build && npm test` for Cloud Functions). Fix any issues automatically (up to 3 retries).
5. **Stage 3 (Adversarial Critic)**: Audit the changes against the 7 core safety invariants (credentials, feature gating, buy guards, balance masking, O(1) indicators, accessibility, typing).
6. **Stage 4 (Reconciler)**: Update documentation (`docs/`, `PRODUCT.md`, `CHANGELOG.md`), mark the task complete in `ROADMAP.md` with issue links, and reconcile Quick Stats.
7. **Stage 5 (Lifecycle)**: In autonomous mode, commit with conventional format referencing `#<num>`, comment verification evidence on the issue, and close it (`gh issue close <num>`).
