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
    end

    subgraph ReleaseDecisionPhase["6. In-Workflow Release Cadence & Feature Grouping Decision"]
        N --> O{"Release Cadence Evaluation: Milestone Target or Batch Threshold Met?"}
        O -- "Yes" --> P["Stage 6: Group Verified Features & Cut Semantic Release (pubspec/CHANGELOG)"]
        P --> Q["Conclude Release Cycle (Await Human Push Confirmation)"]
        O -- "No (Batch Incomplete & Circuit Breaker Clear)" --> R{"Max Iterations Reached?"}
        R -- "No" --> A
        R -- "Yes" --> P
    end
```

---

## 1.1 Quick-Reference CLI Cheat Sheet

Use these copy-pasteable slash command invocations for common engineering workflows:

| Developer Scenario | Slash Command / CLI Invocation | Description |
|---|---|---|
| **Autonomous Loop Overnight** | `/software-factory mode="autonomous" stages="full" max_iterations=3` | Runs continuous closed loop: ideate, score, triage, parallel implement, verify, reconcile, and commit. |
| **Autonomous Milestone Release** | `/software-factory release_cadence="milestone" release_threshold=3` | Evaluates in-workflow feature grouping and cuts a semantic release when batch threshold is reached. |
| **Simulation / Dry-Run** | `/software-factory dry_run=true stages="full"` | Executes discovery, rubric scoring, partitioning, and test mapping without mutating files or committing. |
| **Single-Item Interactive** | `/software-implementation mode="interactive" focus="<feature_title>"` | Guided Maker-Verifier-Critic loop with human approval checkpoints before staging commits. |
| **Ideation & Backlog Discovery** | `/software-ideation focus="agentic trading"` | Evaluates backlog candidates against the 8-point Readiness Rubric and records qualified proposals. |
| **Release Preparation & Audit** | `/software-release bump="patch"` | Prepares semantic version bump, syncs release notes, audits safety invariants, requiring manual push confirmation. |
| **Documentation Synchronization** | `/update-docs` | Reconciles `ROADMAP.md` Quick Stats, bounds Key Highlights ($\le 5$), and updates `CHANGELOG.md`. |
| **Disaster Recovery (Resume)** | `/software-factory mode="autonomous"` | Automatically reads `.agents/.factory_run_state.json` and resumes from the last completed iteration. |
| **Reset Circuit Breaker** | `rm -f .agents/.factory_run_state.json` | Clears tripped failure counters and unblocks autonomous factory execution. |

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

        Note over SF,Dev: Phase 6: Release Cadence & Grouping Decision
        SF->>SF: Evaluate release cadence (milestone goal or batch threshold met?)
        alt Release Decision Triggered
            SF->>Sync: Group verified features into release notes & bump pubspec.yaml
            Sync-->>SF: Release bundle prepared (vX.Y.Z)
            SF-->>Dev: Conclude Release Cycle (Await human confirmation before push)
        end
    end
    
    SF-->>Dev: Autonomous Loop Completed (Summary report & PR ready)
```

### 2.1 Release Cadence & Feature Grouping: Breaking the Ideation Infinite Loop

#### The Infinite Loop Trap of Continuous Ideation
In an autonomous software factory where **Ideation & Backlog Discovery** runs alongside **Implementation**, a naive termination rule ("wait until all remaining roadmap items are finished") creates an **infinite loop**:
1. Phase 1 discovers 3 new candidate features from open issues and adds them to `ROADMAP.md`.
2. Phase 3 implements 2 features.
3. Next iteration, Phase 1 discovers 3 more candidates.
4. The backlog never empties, and the factory never decides to cut a release!

#### The In-Workflow Release Decision Solution
To prevent infinite backlogs, RealizeAlpha treats **Release Cadence & Feature Grouping as an explicit in-workflow decision** rather than an open-ended wait condition:

1. **Decoupled Milestone Horizons**:
   - Ideation categorizes candidate proposals into **Target Milestone Horizons**:
     - *Current Horizon*: Enhancements or bug fixes strictly within the active release scope (e.g., `v0.62.x`).
     - *Future Horizons*: New capabilities queued for future minor/major milestones (e.g., `v0.63.0`, `v0.64.0+`).
   - Discovery of future items expands the long-term roadmap without expanding the completion condition of the current release run.

2. **Configurable Release Cadence Policies (`release_cadence`)**:
   - `milestone` (default): Packages and cuts a release when all actionable items in the active release milestone are satisfied or when the accumulated feature count reaches `release_threshold`.
   - `batch_size`: Groups and releases whenever `release_threshold` (e.g. 2–3 verified features) is reached, cutting regular, incremental patch releases.
   - `manual`: Bypasses automated release decisions, holding version bumps for explicit developer commands.

3. **In-Workflow Release Bundling (`software-release`)**:
   - When the release decision evaluates to `true`, the workflow invokes the Release Specialist agent to:
     - Group newly verified features from the cycle into semantic release notes in `CHANGELOG.md`.
     - Bump semantic versioning in `pubspec.yaml` (`patch` vs `minor`).
     - Move the completed features into `ROADMAP.md` `## Completed Features ✅` and reconcile `Quick Stats`.
     - Conclude the active release cycle gracefully, outputting a complete release summary and awaiting explicit human confirmation before pushing git tags to `main`.

### Full-Cycle Pipeline Chaining
When invoked with `stages="full"`, the factory coordinates six sequential phases:
1. **Ideation & Backlog Discovery**: Scans `PRODUCT.md`, `ROADMAP.md`, and open GitHub issues. Scores candidate proposals against the **Software Factory Readiness Rubric** (bounded scope, testable without external live credentials, compliant with the 7 safety invariants) and automatically records qualified items in `ROADMAP.md` under their appropriate milestone horizon.
2. **Triage & Disjoint Partitioning**: Evaluates unchecked tasks in the active horizon and selects up to `max_parallel` items with mutually disjoint file boundaries.
3. **Implementation & Verification**: Executes the Maker agent and Self-Healing Verifier loop with companion test mapping and up to 3 repair retries.
4. **Adversarial Critique**: Spawns an isolated critic subagent that audits the diff against the 7 Core Safety Invariants without shared author bias, producing a structured `CriticAuditVerdict`.
5. **Reconciliation & Git Lifecycle**: Reconciles documentation, updates `ROADMAP.md` Quick Stats, creates conventional commits (`feat(...): ... (#<num>)`), and closes verified issues (`gh issue close <num>`).
6. **Release Cadence & Grouping Decision**: Evaluates milestone/batch completion criteria. If satisfied, groups completed features, bumps semantic version in `pubspec.yaml`, generates release notes in `CHANGELOG.md`, and concludes the cycle.

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

### Machine-Readable Critic Audit Verdict Schema (`CriticAuditVerdict`)

To ensure deterministic gating without natural language ambiguity, the Adversarial Critic produces a structured JSON verdict:

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
  "audit_notes": "All 7 core trading safety invariants confirmed clean. Live-quote BUY guard verified."
}
```

### Token Cost & Throughput Optimization
- **Tiering Strategy**: Keep high-volume iterative repair loops (format, analyze, fix) on fast, cost-effective models (`flash`), reserving reasoning-dense models (`pro`) for initial architecture specification and independent adversarial safety auditing.
- **Prompt Token Isolation**: Maker subagents execute inside isolated branch workspaces (`workspace="branch"`) with clean context windows, preventing bloated turn histories from degrading analysis speed.

---

## 5.1 Feature Flag & Progressive Rollout Lifecycle (`FeatureAccessService`)

Every new user-facing capability implemented by the Software Factory must integrate into RealizeAlpha's **4-tier progressive rollout architecture** ([`docs/feature-access-and-beta-gating.md`](feature-access-and-beta-gating.md)):

```mermaid
flowchart LR
    A["Tier 1: Remote Config Kill Switch"] --> B["Tier 2: Per-User Feature Flags"]
    B --> C["Tier 3: Admin-Only / Beta Labs Opt-In"]
    C --> D["Tier 4: General Availability (Public)"]
```

### 1. Progressive Rollout Stages
1. **Stage 1 (Admin Only)**:
   - When a new capability is authored by the Maker agent, it is added to `FeatureBundle` with default stage `adminOnly`.
   - Only admin accounts with explicit opt-in can access the feature, protecting standard users during initial deployment.
2. **Stage 2 (Beta Labs Self-Serve Opt-In)**:
   - Once verified, the feature is promoted to `stage: FeatureStage.beta`.
   - Surfaced inside `BetaLabsWidget` under User Settings, allowing early-adopter traders to voluntarily opt in, test, and provide feedback.
3. **Stage 3 (General Availability)**:
   - Following stable telemetry and zero safety incidents across a release cycle, the feature is promoted to `stage: FeatureStage.public`.
   - Turned on by default for all users, with instant remote kill-switch protection via Firebase Remote Config.

### 2. Maker Agent Implementation Checklist
When authoring a new feature, the Maker agent must:
- Declare the feature bundle in `src/robinhood_options_mobile/lib/model/feature_access.dart` (or corresponding model).
- Wrap UI entry points with `FeatureAccessService.instance.isFeatureEnabled(FeatureBundle.<feature>, userRole: userRole)`.
- Author a dedicated unit test in `test/feature_access_service_test.dart` asserting that unauthenticated or non-beta users cannot access the gated screens.
- Confirm Invariant 2 compliance in the `CriticAuditVerdict` output.

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

## 7. External Context Ingestion & Team Feedback Loops

To prevent operating in an insular vacuum, the Software Factory connects directly to real-world operational context through a **Staged Context Adapter Pattern** ([`.agents/context/`](../.agents/context/README.md)):

```mermaid
flowchart TD
    subgraph ExternalSources["External Context Streams"]
        A["Developer Messaging (Slack, Teams, WhatsApp)"]
        B["Production Telemetry (Crashlytics, Cloud Logging)"]
        C["User Feedback (App Store, Beta Labs Surveys)"]
        D["Market Infrastructure (Economic Calendar, OCC Memos)"]
    end

    subgraph StagingAdapter["Staged Context Adapter (.agents/context/)"]
        E["PII & Sensitive Token Scrubbing"]
        F["Structured Staging (.agents/context/*.json)"]
    end

    subgraph FactoryPipeline["Autonomous Factory Ingestion"]
        G["Phase 1: Context-Enriched Ideation"]
        H["Phase 2: Incident Triage & Hotfix Acceleration"]
        I["Phase 6: In-Workflow Release Decision"]
    end

    subgraph OutboundBroadcast["Bi-Directional Team Notification"]
        J["Slack / Teams / Discord Cycle Summary Cards"]
    end

    ExternalSources --> StagingAdapter
    StagingAdapter --> FactoryPipeline
    FactoryPipeline --> OutboundBroadcast
```

### 1. Ingested External Streams
1. **Developer & Team Messaging Digests (`developer_brief.json`)**:
   - Integrates conversation digests from Slack, Microsoft Teams, WhatsApp, and Discord.
   - Converts high-priority architectural discussions and temporary workarounds into structured candidate proposals.
2. **Production Crash Telemetry (`telemetry_crashes.json`)**:
   - Ingests high-velocity crash and exception clusters from Firebase Crashlytics and GCP Cloud Logging.
   - High-severity crashes automatically bypass normal backlog sequencing, generating accelerated **hotfix tasks** with exact stack traces, reproduction breadcrumbs, and companion tests.
3. **End-User Feedback & Beta Labs Voice (`user_feedback.json`)**:
   - Ingests App Store reviews, Google Play user comments, and Beta Labs surveys.
   - Sentiment clustering groups repeated user friction points to guide targeted UI polish and accessibility enhancements.
4. **Market Calendar & Economic Infrastructure (`market_calendar.json`)**:
   - Staged macro dates (FOMC rate decisions, CPI releases, quadruple witching, exchange holidays) and OCC corporate action memos.
   - Enforces the **Market Stability Invariant**: halts production releases and trading engine alterations during high-volatility macro announcements.

### 2. Privacy & PII Scrubbing Rules
- External context collectors must scrub customer identifiers, private account balances, passwords, and brokerage OAuth credentials before writing to `.agents/context/`.
- Live context files (`.agents/context/*.json`) are ignored by `.gitignore`, ensuring transient runtime telemetry is never committed to repository history.

### 3. Bi-Directional Team Webhooks
Upon cycle completion or release cut in GitHub Actions (`software-factory-dispatch.yml`), the factory dispatches an interactive notification card to the team's messaging channel via `SLACK_WEBHOOK_URL`, `TEAMS_WEBHOOK_URL`, or `DISCORD_WEBHOOK_URL`.

---

## 8. Tooling & Skills Directory

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

## 9. CI/CD Integration & Automated Gates

The Software Factory integrates directly into GitHub Actions workflows:

1. **`software-factory-verify.yml`**:
   - Fast PR and branch verification workflow with concurrency cancellation and path-filtered execution (`dorny/paths-filter@v3`).
   - Runs static safety invariant checks (e.g. scanning for plaintext tokens written to `SharedPreferences`), validates workflow YAML files, verifies Python script syntax, and checks `ROADMAP.md` structural invariants.
   - Executes strict `dart format`, `flutter analyze --no-fatal-infos`, impacted tests, and Cloud Functions `npm run lint && npm run build && npm test`.

2. **`software-factory-dispatch.yml`**:
   - On-demand and scheduled `workflow_dispatch` trigger supporting parameters: `mode`, `stages`, `dry_run`, `max_iterations`, `failure_limit`, and `focus`.
   - Executes verification gates, outputs GITHUB_STEP_SUMMARY tables, and archives `.agents/.factory_*.json` run state and metrics as job artifacts.

3. **`cd.yml`**:
   - Enforces strict static analysis (with `continue-on-error: true` removed from `flutter analyze`) and Cloud Functions TypeScript compilation on all pushes to `main` and release builds.
   - Automatically extracts categorized release notes from `CHANGELOG.md` for Google Play (`distribution/whatsnew/whatsnew-en-US`) and TestFlight (`WhatToTest.en-US.txt`).

---

## 10. Execution Examples

### Running an Autonomous Continuous Loop
```text
/software-factory mode="autonomous" stages="full" max_iterations=3 focus="agentic trading"
```

### Running Simulation / Dry-Run Mode
```text
/software-factory dry_run=true stages="full" focus="derivatives"
```

### Running Parallel Multi-Item Execution via `run_workflow`
```python
call_tool("run_workflow",
  ScriptPath=".github/skills/software-factory/scripts/factory_pipeline.py",
  Description="Execute autonomous software factory loop for v0.62.x",
  Args={
    "mode": "autonomous",
    "stages": "full",
    "dry_run": False,
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

---

## 11. Step-by-Step Execution Walkthrough Case Study

The following concrete case study illustrates how a candidate feature (*"Option Volatility Skew Real-Time Alert"*) progresses through all 5 phases of the Software Factory:

### Phase 1: Ideation & Rubric Scoring
- **Discovery**: The Ideation agent scans `PRODUCT.md` and discovers that while higher-order Greeks (Charm, Vanna) exist, traders lack automated push notifications when 30-day IV skew diverges past historical percentiles.
- **Rubric Evaluation**:
  - *Scope & Boundaries*: Touches `PortfolioAlertService` and `OptionPositionStore` (2 files) $\to$ **2 pts**.
  - *Testability*: Deterministic math tested with fake quotes in `test/portfolio_alert_service_test.dart` $\to$ **2 pts**.
  - *Safety Invariants*: No token storage, respects balance masking, $O(1)$ scalar calculation $\to$ **2 pts**.
  - *Code Ownership*: Clear ownership under `lib/services/portfolio_alert_service.dart` $\to$ **1 pt**.
  - **Total Score**: **7/8 (Qualified $\ge 6$)**.
- **Backlog Recording**: The agent appends the item to `ROADMAP.md` under `v0.62.x` and creates GitHub issue `#354`.

### Phase 2: Triage & Disjoint Partitioning
- **Coordinator Assignment**: Triage selects `#354` and maps disjoint files:
  - Source: `src/robinhood_options_mobile/lib/services/portfolio_alert_service.dart`
  - Inferred Companion Test: `src/robinhood_options_mobile/test/portfolio_alert_service_test.dart`
- **Isolation**: Work is partitioned to an isolated branch workspace (`workspace="branch"`).

### Phase 3: Maker – Verifier – Critic Execution
- **Maker Agent**: Implements skew threshold calculations in `portfolio_alert_service.dart` and authors 3 unit tests in `portfolio_alert_service_test.dart`.
- **Self-Healing Verification Gate**:
  - *Attempt 1*: `dart format --set-exit-if-changed` fails due to trailing comma placement on line 84.
  - *Repair Turn*: The Maker agent parses the diagnostic output, formats the block, and re-executes.
  - *Attempt 2*: `dart format`, `dart analyze`, and `flutter test test/portfolio_alert_service_test.dart` all return exit code 0 (**Green Gate**).
- **Adversarial Critic Subagent**: An independent fresh-context agent reviews `git diff`, confirms zero credential leakage, validates alert throttling, and outputs `approved: true` with all 7 invariant checks marked `true`.

### Phase 4: Reconciliation
- The Reconciler agent updates `ROADMAP.md` marking the checklist item complete (`- [x] ... (#354)`), increments `Quick Stats` completed count, appends an entry to `CHANGELOG.md` under `### Added`, and updates `docs/custom-alerts.md`.

### Phase 5: Git Lifecycle
- In autonomous mode, the Lifecycle agent commits the changes (`feat(alerts): add option volatility skew real-time notifications (#354)`), posts the verification summary and test logs as a comment on GitHub issue `#354`, and closes the issue (`gh issue close 354`).
- Cycle metrics are saved to `.agents/.factory_metrics.json`, and the loop iterates to the next backlog item.

---

## 12. ADR-001: Architecture Decision Record

### Context & Problem Statement
Earlier iterations of agent tooling in RealizeAlpha relied on fine-grained, per-tool-use hooks (e.g. running linters or checks on every file write tool call) and thin wrapper prompts (`roadmap.prompt.md`, `autopilot.prompt.md`). In practice, per-tool hooks introduced prohibitive latency (re-running analyzers on intermediate edits), triggered false positives during multi-file refactors, and fragmented instructions across multiple non-canonical files.

### Decision
1. **Retire Per-Tool Hooks**: Move disabled per-tool hooks to `.agents/archive/hooks.disabled.json` and document the rationale in `.agents/archive/README.md`.
2. **Standardize Stage-Boundary Quality Gates**: Consolidate automated verification into deterministic stage boundaries (at the conclusion of the Maker phase and within GitHub Actions CI).
3. **Consolidate Canonical `software-*` Skills**: Unify all engineering skills under `.github/skills/` (`software-factory`, `software-ideation`, `software-implementation`, `software-release`, `update-docs`) as the single sources of truth.
4. **Structured Critic Verdict Contract**: Standardize the adversarial review into a machine-readable JSON schema (`CriticAuditVerdict`) verifying the 7 Core Safety Invariants.

### Consequences & Benefits
- **Zero Inter-Turn Tool Lag**: Agents can perform multi-file edits and intermediate refactoring without interrupted tool calls.
- **Deterministic CI Parity**: The exact commands executed by the self-healing gate match GitHub Actions (`software-factory-verify.yml`).
- **Resilient Multi-Iteration Autonomy**: Interrupted workflows recover seamlessly via `.agents/.factory_run_state.json` without duplicating work or tripping merge conflicts.
