# Agent Hooks Architecture & Archival Record

This document explains the architecture of agent hooks in RealizeAlpha, why fine-grained per-tool formatting hooks were retired, and how code formatting and verification are authoritatively enforced.

---

## 1. Background & Why File-Level Hooks Were Retired

Previously, `.agents/hooks.json` configured automatic shell hooks executed by agent harnesses:
- **`PostToolUse`** on `write_file|write_to_file|edit_file|...`: Ran `.agents/scripts/auto_format.sh` (`dart format` and `npm run lint:fix`).
- **`Stop`**: Ran `.agents/scripts/verify_formatting.sh` (`dart format --output=none --set-exit-if-changed .` and `npm run lint`).

### Critical Problems Encountered:
1. **Severe Turn Latency (15–25s per edit):** Running repository-wide `dart format` on every single file write or edit caused severe multi-second delays across turns, drastically degrading interactive developer workflows.
2. **Premature Formatting During Multi-File Edits:** Formatting intermediate or half-written code often broke AST parsing or reformatted files outside the immediate edit context.
3. **Flaky Command Locks:** Multiple concurrent tool calls could trigger race conditions or lock errors on `pubspec.lock` or temporary files.

---

## 2. Current Architecture: Staged Verification Gates

Quality gates, formatting, and linting are now authoritatively enforced at structured boundaries rather than per-tool-use:

1. **Maker–Verifier–Critic Loop (`.github/skills/software-factory/` & `.github/skills/roadmap-implementation/`):**
   - Formatting and static analysis run once at the completion of an implementation slice (Stage 3: Self-Healing Verification Gate) instead of on every file write.
   - Self-healing repair loops (up to 3 retries) diagnose and fix issues deterministically.
2. **Fast Pre-Merge Verification (`.github/workflows/software-factory-verify.yml`):**
   - Runs `dart format --output=none --set-exit-if-changed .`, `flutter analyze --no-fatal-infos`, and Cloud Functions `npm run lint && npm run build && npm test` on PRs and branches.
3. **Continuous Deployment Gate (`.github/workflows/cd.yml`):**
   - Auto-formats clean changes on push and strictly gates releases on zero analyzer errors.

---

## 3. Archived Configuration

The original hook configuration is preserved for historical reference in:
- [`.agents/archive/hooks.disabled.json`](hooks.disabled.json)
- Active `.agents/hooks.json` remains set to `{}` (clean no-op).
- Supporting scripts remain in `.agents/scripts/auto_format.sh` and `.agents/scripts/verify_formatting.sh` for manual execution.

## Removed Scripts

The no-op hook scripts `.agents/scripts/auto_format.sh` and `.agents/scripts/verify_formatting.sh` were deleted (they only printed `{}`). `.agents/hooks.json` is kept as an empty `{}` placeholder. See [ADR-001](../../docs/adr/0001-stage-boundary-gates.md).
