# ADR-001: Stage-Boundary Quality Gates & Canonical `software-*` Skills

- **Status:** Accepted
- **Date:** 2026-11-24
- **Context doc:** [Software Factory architecture](../software-factory.md)

## Context & Problem Statement
Earlier iterations of agent tooling in RealizeAlpha relied on fine-grained, per-tool-use hooks (e.g. running linters or checks on every file write tool call) and thin wrapper prompts (`roadmap.prompt.md`, `autopilot.prompt.md`). In practice, per-tool hooks introduced prohibitive latency (re-running analyzers on intermediate edits), triggered false positives during multi-file refactors, and fragmented instructions across multiple non-canonical files.

## Decision
1. **Retire Per-Tool Hooks**: Move disabled per-tool hooks to `.agents/archive/hooks.disabled.json` and document the rationale in `.agents/archive/README.md`.
2. **Standardize Stage-Boundary Quality Gates**: Consolidate automated verification into deterministic stage boundaries (at the conclusion of the Maker phase and within GitHub Actions CI).
3. **Consolidate Canonical `software-*` Skills**: Unify all engineering skills under `.github/skills/` (`software-factory`, `software-ideation`, `software-implementation`, `software-release`, `update-docs`) as the single sources of truth.
4. **Structured Critic Verdict Contract**: Standardize the adversarial review into a machine-readable JSON schema (`CriticAuditVerdict`) verifying the 7 Core Safety Invariants.

## Consequences & Benefits
- **Zero Inter-Turn Tool Lag**: Agents can perform multi-file edits and intermediate refactoring without interrupted tool calls.
- **Deterministic CI Parity**: The exact commands executed by the self-healing gate match GitHub Actions (`software-factory-verify.yml`).
- **Resilient Multi-Iteration Autonomy**: Interrupted workflows recover seamlessly via `.agents/.factory_run_state.json` without duplicating work or tripping merge conflicts.
