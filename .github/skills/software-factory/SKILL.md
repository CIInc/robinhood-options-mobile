---
name: software-factory
description: "Orchestrate autonomous AI software factory cycles for RealizeAlpha: specification, parallel or staged Maker-Verifier-Critic loops, self-healing quality gates, and documentation reconciliation."
---

# Autonomous Software Factory

Orchestrate end-to-end or multi-item autonomous software factory cycles across
the RealizeAlpha codebase. In autonomous mode, the software factory operates as a
continuous closed loop: **Ideate & Discover $\to$ Triage & Partition $\to$ Maker Implementation $\to$
Self-Healing Quality Gate $\to$ Adversarial Critic $\to$ Docs & Roadmap Reconciliation $\to$ Git & Issue Lifecycle**,
repeating iteratively across backlog slices until the target horizon is completed or maximum iterations are reached.

## Arguments

Optional parameters passed as text or key-value pairs:
- `mode`: `autonomous` (default) or `interactive`
  - In `autonomous` mode, the factory runs continuously as a closed loop: high-confidence ideation items are discovered, scored against the Factory Readiness Rubric, and recorded in `ROADMAP.md`; implementation tasks run through Maker-Verifier-Critic loops; commits are created automatically referencing `#<issue-num>`; and verified issues are closed. Production release deployment (`software-release` pushing to `main` / `promote.yml`) preserves an explicit confirmation gate unless `confirm_release_push=true` is set.
  - In `interactive` mode, the factory stops and presents decisions to the user before recording proposals, staging commits, or closing issues.
- `stages`: `full` (`ideate -> triage -> implement -> docs -> release-check`), `implement-batch` (implement $N$ items), or `single` (one item end-to-end). Defaults to `single` when an explicit item or constraint is provided, or `full` when unconstrained.
- `max_parallel`: `1..4` concurrent worker items (default: `1`).
  - **Disjoint Ownership Partitioning Rule**: Concurrent workers (`workspace="branch"` or `"share"`) may only implement items whose modified source files in `lib/` and `functions/src/` are disjoint so workers never collide on shared state stores or widgets. Shared repository files (`ROADMAP.md`, `CHANGELOG.md`, `PRODUCT.md`) must be reconciled once in the aggregation phase by the coordinator.
- `max_iterations`: Maximum continuous loop iterations in autonomous mode (default: `3` in `autonomous`, `1` in `interactive`).
- `failure_limit`: Number of consecutive failed iterations before the Repetitive Failure Circuit Breaker trips and halts the loop (default: `2`).
- `focus`: Optional product or architectural area (e.g., `"agentic trading"`, `"portfolio greeks"`, `"v0.62.x"`).
- `auto_ideate`: `true` (default) or `false`. When enabled, the factory automatically discovers and ranks candidate features from open issues and backlog gaps prior to implementation.
- `dry_run`: `true` or `false` (default: `false`). Simulates a cycle without writing files, run state, metrics, issues, or commits. Under `run_workflow` the dry-run logs candidate tasks, target files, companion tests, and applicable invariants; standalone (`./scripts/factory.sh dry-run`) agents are stubbed, so only control flow and context loading are exercised.
- `release_cadence`: `milestone` (default), `batch_size`, or `manual`. Determines when to trigger release packaging and cut a release, rather than waiting for an empty backlog (which creates an infinite loop with ongoing ideation).
- `release_threshold`: Number of verified features required to trigger a release packaging decision (default: `2`).

---

## Architecture: Staged Maker–Verifier–Critic Loop

Every implementation task moves through a deterministic 5-stage state machine:

```
[Stage 1: Spec & Invariants] -> [Stage 2: Maker (Code + Tests)] -> [Stage 3: Self-Healing Gate]
                                                                          |
                                                                Pass / Fix (<=3)
                                                                          v
[Stage 5: Reconciler & Git]  <-  [Stage 4: Adversarial Critic Subagent (Audits 7 Invariants)]
```

### Stage 1: Spec, Triage & Invariant Extraction
- Parse `ROADMAP.md` and open GitHub issues (`gh issue list --state open --limit 1000 --json number,title,body,labels,milestone,updatedAt`).
- Identify unchecked actionable tasks (`- [ ]`). Filter out speculative or blocked work.
- Extract concrete acceptance criteria, files to touch, and the applicable **RealizeAlpha Safety Invariants** from `AGENTS.md`.

### Stage 2: Maker Implementation
- Implement the minimal, complete change satisfying the criteria.
- Adhere strictly to the project layout:
  - Mobile app: `src/robinhood_options_mobile/lib/`
  - Cloud Functions: `src/robinhood_options_mobile/functions/src/`
  - Firestore rules: `src/robinhood_options_mobile/firebase/firestore.rules`
- Add or update focused unit and widget tests covering positive behavior, edge cases, and regression boundaries.

### Stage 3: Self-Healing Verification Gate
Execute the narrowest relevant checks with an automated repair loop (up to 3 bounded retries):
1. **Flutter / Dart Quality Gate:**
   ```bash
   cd src/robinhood_options_mobile && dart format --output=none --set-exit-if-changed .
   cd src/robinhood_options_mobile && dart analyze
   cd src/robinhood_options_mobile && flutter test test/<specific_test_file>.dart
   ```
2. **Cloud Functions Backend Gate:**
   ```bash
   cd src/robinhood_options_mobile/functions && npm run lint
   cd src/robinhood_options_mobile/functions && npm run build
   cd src/robinhood_options_mobile/functions && npm test
   ```
   *(Google ESLint `max-len <= 80` is strictly enforced; run `npm run lint -- --fix` to auto-resolve mechanical formatting issues.)*
3. If analysis or tests fail, diagnose the error output, apply targeted corrections, and re-run. If unresolved after 3 attempts, halt and report the failure.

### Stage 4: Independent Adversarial Critic
Before marking any task ready, invoke a dedicated critic subagent or execute an explicit adversarial review against the 7 core invariants in `AGENTS.md`:
1. **Zero Plaintext Credentials**: OAuth tokens and API secrets stored exclusively via `SecureTokenStorage` (`flutter_secure_storage`). Never in `SharedPreferences` or Firestore.
2. **Feature Access Hierarchy**: Precedence strictly follows Remote Config kill switch $\to$ per-user flags $\to$ `adminOnly` / `beta` / `public`.
3. **Trading Safeguards & Quote Isolation**: Live-quote BUY guard ($>3\%$ deviation block), Paper TP/SL exits isolated through the simulated ledger (`account == null`), and dynamic sizing boundaries respected.
4. **Balance Masking & Privacy**: Masked portfolio values honored across charts and widgets; multi-broker tax lots remain on-device.
5. **Cloud Functions Security & $O(1)$ Space**: All callables authenticated and inputs validated; technical indicator and backtest loops maintain $O(1)$ auxiliary space without slicing per bar.
6. **UI Polish & Accessibility**: Financial rows have natural `Semantics(label: ...)`; layouts do not overflow down to `320px` viewports.
7. **Zero Compile Errors & Strict Types**: Verification with `dart analyze` and `tsc` shows zero errors or type mismatches.

The critic returns a machine-readable `CriticAuditVerdict` JSON payload:
```json
{
  "approved": true,
  "invariants": {
    "zero_plaintext_credentials": true,
    "feature_access_precedence": true,
    "trading_safeguards": true,
    "balance_visibility_privacy": true,
    "backend_security_complexity": true,
    "accessibility_ui_polish": true,
    "zero_compile_errors_integrity": true
  },
  "blocking_issues": [],
  "audit_notes": "All checks verified clean."
}
```

If the critic identifies blocking issues or missing tests, return to **Stage 2 (Maker)** for remediation.

### Stage 5: Reconciler, Documentation & Git Lifecycle
- Update dedicated feature documentation in `docs/` and `PRODUCT.md` for new architectural capabilities or services.
- Record completed features (`[x]`) in `ROADMAP.md` with issue links, keeping `## Completed Features ✅` bounded to recent minor releases and `### Key Highlights` capped at 3–5 items. Reconcile `Quick Stats`.
- Update `CHANGELOG.md` with categorized bullet points (`Added`, `Changed`, `Fixed`, `Performance`).
- In `autonomous` mode:
  - Create a clean git commit: `git commit -m "feat(<scope>): <summary> (#<issue-num>)"`.
  - Add verification notes to the GitHub issue and close it with `gh issue close <num>`.

### Stage 6: Release Cadence & Feature Grouping Decision
To break the infinite loop where ongoing ideation continuously adds new backlog items, the workflow evaluates release packaging inside the cycle:
- **Feature Grouping**: Groups verified features from the current cycle into a coherent release package.
- **Cadence Evaluation**: Checks if `release_cadence == "batch_size"` meets `release_threshold` or if active milestone tasks are satisfied.
- **Release Packaging**: Runs `software-release` to bump `pubspec.yaml`, audit safety invariants, generate release notes, and conclude the release cycle (requiring manual push confirmation before pushing tags to `main`).

---

## Workflow Script Execution (`run_workflow`)

For multi-item parallel execution or staged pipeline chaining, run the Python workflow script located at:
```
.github/skills/software-factory/scripts/factory_pipeline.py
```

Pass arguments via `Args`:
```python
# Example run_workflow invocation
call_tool("run_workflow",
  ScriptPath=".github/skills/software-factory/scripts/factory_pipeline.py",
  Description="Execute autonomous software factory pipeline for v0.62.x",
  Args={
    "mode": "autonomous",
    "max_parallel": 2,
    "focus": "v0.62.x"
  }
)
```

---

## Completion Report

The software factory completes with a structured summary containing:
- Selected roadmap items and associated GitHub issue links
- Execution mode (`autonomous` vs. `interactive`) and worker topology (sequential or parallel fan-out)
- Files modified and behavior delivered
- Self-healing gate results (Dart format, analyzer, Flutter tests, Cloud Functions lint/build/tests)
- Adversarial critic audit report verifying the 7 safety invariants
- Documentation and roadmap reconciliation summary (`docs/`, `PRODUCT.md`, `CHANGELOG.md`, `ROADMAP.md`)
- Git commit hashes and GitHub issue status updates
