# Autonomous AI Software Factory Architecture, Patterns & Tooling

RealizeAlpha incorporates an **Autonomous AI Software Factory** architecture designed to automate, streamline, and safely scale software engineering, verification, release management, and documentation synchronization across the Flutter, Firebase, and Cloud Functions codebases.

---

## 1. Architectural Overview & Closed-Loop Pattern

The RealizeAlpha Software Factory transitions engineering workflows from manual, single-prompt instructions into a continuous, self-driving **Autonomous Loop** that chains feature discovery, specification, implementation, adversarial verification, and documentation reconciliation:

```mermaid
flowchart TD
    subgraph IdeationPhase["1. Ideation & Backlog Discovery"]
        A["Product Needs & GitHub Issues"] --> B["Ideation Specialist Agent"]
        B --> C["Software Factory Readiness Rubric (>=6/8 pts)"]
        C --> D["Record Proposals to ROADMAP.md & gh issue create"]
    end

    subgraph TriagePhase["2. Triage & Disjoint Partitioning"]
        D --> E["Triage Coordinator Agent"]
        E --> F["Partition Disjoint Task Slices (1..N)"]
    end

    subgraph MakerLoop["3. Maker - Self-Healing Verifier Loop"]
        F --> G["Maker Agent (workspace=branch)"]
        G --> H["Self-Healing Quality Gate (format, analyze, test, lint)"]
        H -- "Failures detected" --> I["Automated Repair Turn (<= 3 retries)"]
        I --> H
    end

    subgraph CriticPhase["4. Independent Adversarial Critic"]
        H -- "Green Gates" --> J["Adversarial Critic Subagent"]
        J -- "Audit 7 Core Safety Invariants" --> K{"Approved?"}
        K -- "Blocking Issues Found" --> G
    end

    subgraph ReconcilePhase["5. Reconciler & Dual-Mode Git Lifecycle"]
        K -- "Passed" --> L["Docs, CHANGELOG & ROADMAP.md Sync"]
        L --> M["Dual-Mode Git Commit & Issue Close"]
        M --> N["software-factory-verify.yml / cd.yml CI Gate"]
        N --> O{"Autonomous Loop Remaining Items?"}
        O -- "Yes (Iterate <= max_iterations & Circuit Breaker Clear)" --> A
        O -- "No / Complete" --> P["Release Readiness Audit"]
    end
```

---

## 2. The Autonomous Loop Engine & Execution Topology

In `mode=autonomous`, the factory operates as a continuous closed loop, driving work forward until the target horizon is completed or maximum iterations are reached.

```mermaid
sequenceDiagram
    autonumber
    actor Dev as Developer / Scheduled Trigger
    participant SF as Software Factory Orchestrator
    participant State as Run State (.factory_run_state.json)
    participant Ideate as Ideation Specialist Agent
    participant Triage as Triage & Planner Agent
    participant Maker as Maker Agent (workspace=branch)
    participant Gate as Self-Healing Quality Gate
    participant Critic as Adversarial Critic Agent
    participant Sync as Reconciler Agent
    participant Git as Git & GitHub Lifecycle

    Dev->>SF: Trigger Autonomous Loop (mode=autonomous, stages=full, max_iterations=3)
    SF->>State: Load / Initialize Run State
    
    loop Autonomous Cycle Iteration (1..max_iterations)
        Note over SF,Ideate: Phase 1: Ideation & Backlog Discovery
        SF->>Ideate: Scan PRODUCT.md, ROADMAP.md, and open issues
        Ideate->>Ideate: Score candidates against Factory Readiness Rubric (>=6/8)
        Ideate-->>SF: Record qualified items in ROADMAP.md & create tracking issues

        Note over SF,Triage: Phase 2: Triage & Disjoint Partitioning
        SF->>Triage: Triage unchecked roadmap tasks
        Triage-->>SF: Selected Disjoint Task Slices (1..N)

        Note over SF,Gate: Phase 3: Maker - Verifier - Critic Execution
        loop For Each Disjoint Slice (Parallel or Pipeline)
            SF->>Maker: Spawn Maker with Criteria, Suggested Tests & 7 Invariants
            Maker->>Maker: Author code and unit/widget tests
            Maker->>Gate: Execute verification commands
            alt Test / Lint Failure
                Gate-->>Maker: Error Diagnostics
                Maker->>Maker: Apply self-healing fix (up to 3 retries)
            end
            Gate-->>SF: Verification Green
            SF->>Critic: Spawn fresh Adversarial Critic Subagent
            Critic->>Critic: Audit git diff against 7 Safety Invariants
            alt Safety Violation
                Critic-->>Maker: Rejection & remediation items
                Maker->>Maker: Remediate violation
            end
            Critic-->>SF: Approval Verdict
        end

        SF->>State: Update completed/failed tasks (Circuit Breaker check)

        Note over SF,Git: Phase 4 & 5: Reconciliation & Git Lifecycle
        SF->>Sync: Reconcile ROADMAP.md, CHANGELOG.md, PRODUCT.md & docs/
        Sync-->>SF: Documentation synchronized & Quick Stats verified
        SF->>Git: Stage files, commit with feat(#num), close GitHub issue
        Git-->>SF: Iteration complete (commit hash, issue closed)
    end
    
    SF-->>Dev: Autonomous Loop Completed (Summary report & PR ready)
```

### Full-Cycle Pipeline Chaining
When invoked with `stages="full"`, the factory coordinates five sequential phases:
1. **Ideation & Backlog Discovery**: Scans `PRODUCT.md`, `ROADMAP.md`, and open GitHub issues. Scores candidate proposals against the **Software Factory Readiness Rubric** (bounded scope, testable without external live credentials, compliant with the 7 safety invariants) and automatically records qualified items in `ROADMAP.md` with associated issues.
2. **Triage & Disjoint Partitioning**: Evaluates unchecked tasks and selects up to `max_parallel` items with mutually disjoint file boundaries.
3. **Implementation & Verification**: Executes the Maker agent and Self-Healing Verifier loop with companion test mapping and up to 3 repair retries.
4. **Adversarial Critique**: Spawns an isolated critic subagent that audits the diff against the 7 Core Safety Invariants without shared author bias.
5. **Reconciliation & Git Lifecycle**: Reconciles documentation, updates `ROADMAP.md` Quick Stats, creates conventional commits (`feat(...): ... (#<num>)`), and closes verified issues (`gh issue close <num>`). The loop continues to the next cycle iteration if more items remain.

### Disjoint Ownership Partitioning Rule
When running multiple tasks in parallel (`max_parallel > 1` via `workspace="branch"` or `workspace="share"`):
- Workers may only touch **mutually disjoint source files** in `src/robinhood_options_mobile/lib/` and `src/robinhood_options_mobile/functions/src/`. For example, Task A modifying `portfolio_analytics_controller.dart` cannot run concurrently with Task B modifying the same controller.
- Shared top-level files (`ROADMAP.md`, `CHANGELOG.md`, `PRODUCT.md`, `pubspec.yaml`) are **never edited by concurrent workers**. Instead, the coordinator reconciles shared files once in the final aggregation phase to eliminate git merge conflicts.

---

## 3. Software Factory Readiness Rubric Matrix

Candidate items discovered during ideation or pulled from GitHub issues must be evaluated against this 4-dimension scoring rubric before autonomous implementation:

| Rubric Dimension | 0 Points (Disqualified) | 1 Point (Marginal) | 2 Points (Factory-Ready) |
|---|---|---|---|
| **Scope & Boundaries** | Crosses multiple platform layers or repositories | Touches $>5$ major state stores or screens | Isolated to $1-3$ related files with clear interfaces |
| **Hermetic Testability** | Requires live brokerage OAuth credentials or real money | Requires complex external server emulation | Fully testable with `fake_cloud_firestore`, `package:test`, and mocks |
| **Safety Invariants** | Violates or bypasses core risk controls | Requires elevated human admin override | Strictly complies with all 7 safety invariants |
| **Code Ownership** | Unclear architecture or brand-new tech stack | Extends legacy unmaintained components | Clear existing `ChangeNotifier` store, widget, or service owner |

> [!IMPORTANT]
> **Promotion Threshold**: An item must achieve a total score $\ge 6/8$ points with **0 points in zero categories** to be automatically added to `ROADMAP.md` and scheduled for execution in autonomous mode.

---

## 4. The 5-Stage State Machine

### Stage 1: Specification, Ideation & Triage
- **Source of Truth**: `ROADMAP.md` and open GitHub issues (`gh issue list --state open --limit 1000 --json number,title,body,labels,milestone,updatedAt`).
- **Ideation Discovery**: Identifies unaddressed gaps, validates proposals against the Software Factory Readiness Rubric, and creates structured tracking issues.
- **Triage**: Actionable unchecked items (`- [ ]`) are filtered by milestone, priority, and clear code ownership.
- **Safety Invariant Extraction**: Extracts the applicable RealizeAlpha core safety invariants from `AGENTS.md` before writing code.

### Stage 2: Maker (Code & Tests)
- Implements the minimal, complete change satisfying the criteria.
- Adheres to repository architectural patterns:
  - Mobile app: `src/robinhood_options_mobile/lib/`
  - Cloud Functions: `src/robinhood_options_mobile/functions/src/`
  - Firestore security rules: `src/robinhood_options_mobile/firebase/firestore.rules`
- Authors focused unit and widget tests covering standard flows, edge cases, and regression boundaries using impact-based companion test mapping.

### Stage 3: Self-Healing Verification Gate
The agent automatically executes targeted verification with an automated repair loop (up to 3 bounded retries):
1. **Dart Code Formatting**:
   ```bash
   cd src/robinhood_options_mobile && dart format --output=none --set-exit-if-changed .
   ```
2. **Strict Dart Static Analysis**:
   ```bash
   cd src/robinhood_options_mobile && dart analyze
   ```
3. **Targeted Flutter Tests**:
   ```bash
   cd src/robinhood_options_mobile && flutter test test/<impacted_test_file>.dart
   ```
4. **Cloud Functions Lint, Build & Tests**:
   ```bash
   cd src/robinhood_options_mobile/functions && npm run lint && npm run build && npm test
   ```
If any check fails, the agent inspects the stack trace, diagnoses root causes, applies a targeted patch, and re-tests.

### Stage 4: Independent Adversarial Critic (7 Core Safety Invariants)
Before concluding any implementation task, the changes are audited against RealizeAlpha's 7 Core Safety Invariants (either via a dedicated critic subagent or an explicit adversarial audit table):

| # | Invariant | Verification Standard |
|---|---|---|
| **1** | **Zero Plaintext Credentials** | Brokerage OAuth tokens and API secrets must be stored exclusively via `SecureTokenStorage` (`flutter_secure_storage`). Never write secrets to `SharedPreferences` or Firestore. |
| **2** | **Feature Access Hierarchy** | Precedence follows Remote Config `disabled` kill switch $\to$ explicit per-user overrides $\to$ `adminOnly` / `beta` / `public` stage in `FeatureAccessService`. |
| **3** | **Trading Safeguards & Quote Isolation** | Live-quote BUY guard ($> 3\%$ deviation block), Paper TP/SL exits isolated through simulated ledger (`account == null`), and dynamic sizing boundaries respected. |
| **4** | **Balance Masking & Privacy** | Masked portfolio balances (`AccountStore`) respected across all charts, widgets, and tooltips; multi-broker tax lots stay on-device. |
| **5** | **Cloud Functions Security & $O(1)$ Space** | All callables authenticate `request.auth` and validate inputs; technical indicator and backtest loops maintain $O(1)$ auxiliary space without slicing arrays per bar. |
| **6** | **UI Polish & Accessibility** | Financial rows consolidate spoken screen-reader text via `Semantics(label: ...)`; layouts do not overflow down to `320px` viewports. |
| **7** | **Zero Compile Errors & Strict Types** | Verification with `dart analyze` and `npm run build` shows zero warnings treated as errors or type mismatches. |

### Stage 5: Reconciler & Dual-Mode Git Lifecycle
- Synchronizes documentation across `docs/`, `PRODUCT.md`, `CHANGELOG.md`, and `ROADMAP.md`.
- Maintains `ROADMAP.md` invariants: bounded `Key Highlights` ($\le 5$ items), bounded `Completed Features ✅` focused on recent minor releases, and verified `Quick Stats`.
- **Dual-Mode Execution**:
  - **Interactive Mode**: Presents all diffs, tests, and documentation updates to the developer. Does not commit, push, or close GitHub issues unless requested.
  - **Autonomous / Factory Mode (`mode=autonomous`)**: Creates conventional commits (`feat(<scope>): <summary> (#<issue-num>)`), adds test evidence to the GitHub issue, and closes the issue with `gh issue close <num>`. Continues to the next iteration of the loop until `max_iterations`, backlog exhaustion, or circuit breaker trip.

---

## 5. Agent Roles & Model Topology

To balance reasoning capability, latency, and token efficiency, the Software Factory assigns specific models to distinct subagent roles:

| Agent Role | Model Recommendation | Tooling Mode | Primary Focus |
|---|---|---|---|
| **Ideation Specialist** | Pro / High-Reasoning | Read-only + GitHub CLI | Backlog discovery, product principle alignment, rubric scoring |
| **Triage Coordinator** | Pro / High-Reasoning | Read-only | Disjoint file partitioning, dependency resolution, acceptance spec |
| **Maker Agent** | Flash / Balanced Coding | Read-Write (`workspace="branch"`) | Minimal complete implementation, unit/widget test authoring |
| **Adversarial Critic** | Flash / Pro (Isolated Context) | Read-only | Diff inspection, 7-invariant checklist enforcement, edge-case probing |
| **Docs Reconciler** | Flash / Balanced | Read-Write | Documentation sync, `ROADMAP.md` formatting, Quick Stats arithmetic |
| **Lifecycle Manager** | Flash_Lite / Fast | Read-Write | Conventional commits, GitHub issue closing comments |

---

## 6. Operational Runbook & Troubleshooting

### Handling Self-Healing Gate Exhaustion (3 Failed Retries)
When a task fails verification 3 times consecutively:
1. The Maker agent halts and logs the diagnostic failure stack trace.
2. The orchestrator records the task ID in `.agents/.factory_run_state.json` under `failed_tasks`.
3. If parallel workers are active, other disjoint tasks continue unaffected.
4. The task is preserved in `ROADMAP.md` as unchecked (`- [ ]`) and the GitHub issue remains open with failure details.

### Circuit Breaker Trip Recovery
If 2 consecutive iterations fail all scheduled tasks, the **Repetitive Failure Circuit Breaker** trips and halts the loop:
1. Inspect `.agents/.factory_run_state.json` to view `iteration` and `failed_tasks`.
2. Review the last error output in the workflow logs.
3. Reset run state by removing the state file:
   ```bash
   rm -f .agents/.factory_run_state.json
   ```
4. Address the underlying issue (e.g. broken dependency or environment lock) and resume with:
   ```bash
   /software-factory mode="autonomous" max_iterations=2
   ```

### Cleaning Up Temporary Parallel Workspaces
Parallel agents run in isolated clones (`workspace="branch"`). Antigravity automatically manages these workspaces. To manually inspect or clean up stale worktrees:
```bash
git worktree list
git worktree prune
```

---

## 7. Tooling & Skills Directory

RealizeAlpha organizes its software factory capabilities into modular skills located in `.github/skills/`:

### 1. `software-factory`
- **Location**: [`.github/skills/software-factory/SKILL.md`](../.github/skills/software-factory/SKILL.md)
- **Workflow Script**: [`.github/skills/software-factory/scripts/factory_pipeline.py`](../.github/skills/software-factory/scripts/factory_pipeline.py)
- **Role**: Top-level autonomous closed-loop factory orchestrator. Runs the closed loop: Ideate $\to$ Triage $\to$ Parallel Maker/Critic Implementation $\to$ Docs Sync $\to$ Git Lifecycle across multiple iterations.

### 2. `software-implementation`
- **Location**: [`.github/skills/software-implementation/SKILL.md`](../.github/skills/software-implementation/SKILL.md)
- **Role**: Single-item focused implementation engine. Executes the 5-stage Maker-Verifier-Critic loop, self-healing quality gates, invariant audits, and Dual-Mode git lifecycle.

### 3. `software-ideation`
- **Location**: [`.github/skills/software-ideation/SKILL.md`](../.github/skills/software-ideation/SKILL.md)
- **Role**: Discovers, shapes, and ranks candidate roadmap proposals by cross-referencing `ROADMAP.md` and GitHub issues. Evaluates proposals against the **Software Factory Readiness Rubric** (bounded scope, testable without external live credentials, adheres to 7 safety invariants).

### 4. `update-docs`
- **Location**: [`.github/skills/update-docs/SKILL.md`](../.github/skills/update-docs/SKILL.md)
- **Role**: Automated documentation synchronization and roadmap invariant checking. Verifies `Quick Stats`, caps `Key Highlights` at $3-5$ items, and ensures `pubspec.yaml` semantic version consistency.

### 5. `software-release`
- **Location**: [`.github/skills/software-release/SKILL.md`](../.github/skills/software-release/SKILL.md)
- **Role**: Prepares semantic releases (`pubspec.yaml`, `CHANGELOG.md`, `ROADMAP.md`), verifies all claimed `[x]` items have tests, runs quality gates, and handles release tagging while strictly preserving human confirmation before pushing release commits to `main`.

---

## 8. CI/CD Integration & Automated Gates

The Software Factory integrates directly into GitHub Actions workflows:

1. **`software-factory-verify.yml`**:
   - Fast PR and branch verification workflow with concurrency cancellation and path-filtered execution.
   - Runs static safety invariant checks (e.g. scanning for plaintext tokens written to `SharedPreferences`), validates workflow YAML files, verifies Python script syntax, and checks `ROADMAP.md` structural invariants.
   - Executes strict `dart format`, `flutter analyze --no-fatal-infos`, impacted tests, and Cloud Functions `npm run lint && npm run build && npm test`.

2. **`cd.yml`**:
   - Enforces strict static analysis (with `continue-on-error: true` removed from `flutter analyze`) and Cloud Functions TypeScript compilation on all pushes to `main` and release builds.
   - Automatically extracts categorized release notes from `CHANGELOG.md` for Google Play (`distribution/whatsnew/whatsnew-en-US`) and TestFlight (`WhatToTest.en-US.txt`).

---

## 9. Execution Examples

### Running an Autonomous Continuous Loop
```text
/software-factory mode="autonomous" stages="full" max_iterations=3 focus="agentic trading"
```

### Running Parallel Multi-Item Execution via `run_workflow`
```python
call_tool("run_workflow",
  ScriptPath=".github/skills/software-factory/scripts/factory_pipeline.py",
  Description="Execute autonomous software factory loop for v0.62.x",
  Args={
    "mode": "autonomous",
    "stages": "full",
    "max_parallel": 2,
    "max_iterations": 3,
    "failure_limit": 2,
    "focus": "v0.62.x"
  }
)
```

### Interactive Software Implementation
```text
/software-implementation focus="progressive disclosure UI" mode="interactive"
```
