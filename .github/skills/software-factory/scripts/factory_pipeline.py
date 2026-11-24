"""
Autonomous AI Software Factory Pipeline Script for RealizeAlpha.
Executed by Antigravity's run_workflow tool (top-level execution).

Orchestrates the complete closed-loop software factory lifecycle:
[Phase 1: Ideation & Rubric Scoring] -> [Phase 2: Triage & Partitioning] ->
[Phase 3: Maker - Verifier - Critic Execution] -> [Phase 4: Docs & Roadmap Reconciliation] ->
[Phase 5: Git & Release Readiness] -> Loop iteration if autonomous mode and remaining tasks exist.

Features:
- Transient run state persistence & crash recovery (.agents/.factory_run_state.json)
- Impact-based companion test heuristic mapping
- Repetitive failure circuit breaker (halts after consecutive failures)
"""

import asyncio
import json
import os

# Arguments passed into run_workflow are injected into the global `args` dict
try:
    _args = args
except NameError:
    _args = {}

mode = _args.get("mode", "autonomous")  # "autonomous" or "interactive"
stages = _args.get("stages", "full")    # "full", "ideate", "implement-batch", "single"
max_parallel = int(_args.get("max_parallel", 1))
max_iterations = int(_args.get("max_iterations", 3 if mode == "autonomous" else 1))
consecutive_failure_limit = int(_args.get("failure_limit", 2))
focus = _args.get("focus", "")
auto_ideate = _args.get("auto_ideate", True)

STATE_FILE = ".agents/.factory_run_state.json"


def load_run_state():
    try:
        if os.path.exists(STATE_FILE):
            with open(STATE_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
    except Exception:
        pass
    return {"iteration": 0, "completed_tasks": [], "failed_tasks": []}


def save_run_state(state):
    try:
        os.makedirs(os.path.dirname(STATE_FILE), exist_ok=True)
        with open(STATE_FILE, "w", encoding="utf-8") as f:
            json.dump(state, f, indent=2)
    except Exception as e:
        log(f"Warning: Unable to persist run state: {e}")


def infer_test_files(target_files):
    """Impact-based test companion mapping heuristic."""
    inferred = []
    for f in target_files:
        if f.startswith("src/robinhood_options_mobile/lib/"):
            rel_path = f[len("src/robinhood_options_mobile/lib/"):]
            base, ext = os.path.splitext(rel_path)
            candidate = f"src/robinhood_options_mobile/test/{base}_test{ext}"
            if os.path.exists(candidate):
                inferred.append(candidate)
        elif f.startswith("src/robinhood_options_mobile/functions/src/"):
            rel_path = f[len("src/robinhood_options_mobile/functions/src/"):]
            base, ext = os.path.splitext(rel_path)
            candidate = f"src/robinhood_options_mobile/functions/tests/{base}.test{ext}"
            if os.path.exists(candidate):
                inferred.append(candidate)
    return list(dict.fromkeys(inferred))


async def run_pipeline():
    log(f"Starting Software Factory pipeline: mode={mode}, stages={stages}, max_parallel={max_parallel}, max_iterations={max_iterations}, focus='{focus}'")

    state = load_run_state()
    consecutive_failures = 0
    iteration = state.get("iteration", 0)

    while iteration < max_iterations:
        iteration += 1
        state["iteration"] = iteration
        save_run_state(state)
        log(f"--- Software Factory Cycle Iteration {iteration}/{max_iterations} ---")

        # ==============================================================================
        # Phase 1: Ideation & Factory Rubric Scoring (If full stages or ideate requested)
        # ==============================================================================
        if stages in ("full", "ideate") and auto_ideate:
            phase(f"Iteration {iteration} - 1. Ideation & Backlog Discovery")
            ideation_agent = agent(
                prompt="""
You are the Software Factory Ideation Specialist for RealizeAlpha.
Analyze `PRODUCT.md`, `ROADMAP.md`, and open GitHub issues (`gh issue list`).
Discover candidate features, gaps, or optimizations aligning with the focus area.
Evaluate candidates strictly against the Software Factory Readiness Rubric (0-2 pts per dimension, >=6/8 required):
1. Scope & Boundaries (1-3 files preferred)
2. Testability (hermetic mocks without live credentials)
3. Safety Invariants (complies with all 7 safety invariants)
4. Code Ownership (clear existing ChangeNotifier store or widget)

In autonomous mode, record the top scored candidate(s) directly into ROADMAP.md under the appropriate milestone and associate or create a tracking issue (`gh issue create`).
""",
                role="Ideation Specialist"
            )

            ideation_prompt = f"""
Discover and rank roadmap candidates for focus area: '{focus}'.
Check if existing unreleased milestones have gaps or if new high-value features are ready for autonomous delivery.
Mode: {mode}.
Previously completed tasks in this factory run: {state.get('completed_tasks', [])}.
Return JSON containing:
- proposed_items: array of objects with title, rationale, suggested_milestone, readiness_score (1-10)
- recorded_to_roadmap: boolean indicating whether items were added to ROADMAP.md
"""
            ideation_schema = {
                "type": "object",
                "properties": {
                    "proposed_items": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "title": {"type": "string"},
                                "rationale": {"type": "string"},
                                "suggested_milestone": {"type": "string"},
                                "readiness_score": {"type": "integer"}
                            },
                            "required": ["title", "readiness_score"]
                        }
                    },
                    "recorded_to_roadmap": {"type": "boolean"},
                    "summary": {"type": "string"}
                },
                "required": ["proposed_items", "recorded_to_roadmap"]
            }

            ideation_result = await ideation_agent(ideation_prompt, ideation_schema)
            del ideation_agent
            log(f"Ideation Phase complete: {ideation_result.get('summary', 'Items evaluated')}")

            if stages == "ideate":
                log("Ideate-only stage requested. Ending pipeline.")
                return

        # ==============================================================================
        # Phase 2: Triage & Disjoint Task Partitioning
        # ==============================================================================
        phase(f"Iteration {iteration} - 2. Triage & Partition")

        triage_prompt = f"""
You are the Software Factory Triage Coordinator for RealizeAlpha.
Inspect ROADMAP.md and open GitHub issues (using git/gh tools).
Identify up to {max_parallel} actionable, unchecked ('- [ ]') items from ROADMAP.md.
Focus area: '{focus}' (if specified).
Exclude completed or failed tasks in this run: {state.get('completed_tasks', []) + state.get('failed_tasks', [])}.

Crucial rule: The tasks must have DISJOINT file ownership (i.e. no two tasks touch the same store, service, or widget file) so they can execute safely in parallel without merge conflicts.

Return your plan as JSON matching the schema with:
- items: array of objects containing issue_number, title, target_files, acceptance_criteria, safety_invariants
- rationale: why these items were selected
"""

        triage_schema = {
            "type": "object",
            "properties": {
                "items": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "issue_number": {"type": "integer"},
                            "title": {"type": "string"},
                            "target_files": {"type": "array", "items": {"type": "string"}},
                            "acceptance_criteria": {"type": "array", "items": {"type": "string"}},
                            "safety_invariants": {"type": "array", "items": {"type": "string"}}
                        },
                        "required": ["title", "target_files", "acceptance_criteria"]
                    }
                },
                "rationale": {"type": "string"}
            },
            "required": ["items", "rationale"]
        }

        triage_agent = agent(
            prompt="You are a senior software architect specializing in repository triage and task decomposition.",
            role="Triage Architect"
        )

        plan = await triage_agent(triage_prompt, triage_schema)
        del triage_agent

        items = plan.get("items", [])
        log(f"Triage selected {len(items)} task(s): {[item.get('title') for item in items]}")
        log(f"Triage rationale: {plan.get('rationale')}")

        if not items:
            log("No further actionable tasks identified in backlog. Concluding autonomous loop.")
            break

        # ==============================================================================
        # Phase 3: Staged Maker - Verifier - Critic Loop (Parallel or Sequential)
        # ==============================================================================
        phase(f"Iteration {iteration} - 3. Maker-Verifier-Critic Execution")

        async def execute_item_loop(task_item):
            title = task_item.get("title")
            issue_no = task_item.get("issue_number")
            targets = task_item.get("target_files", [])
            criteria = task_item.get("acceptance_criteria", [])
            invariants = task_item.get("safety_invariants", [])
            suggested_tests = infer_test_files(targets)

            log(f"Starting Maker for: {title} (#{issue_no})")
            if suggested_tests:
                log(f"Impact-mapped companion test files: {suggested_tests}")

            # Step 3A: Maker Agent
            maker = agent(
                prompt=f"""
You are an expert Flutter/Dart and Firebase Cloud Functions software engineer working on RealizeAlpha.
Your task: Implement '{title}' (Issue #{issue_no}).
Target files: {targets}
Companion test candidates: {suggested_tests}
Acceptance criteria:
{json.dumps(criteria, indent=2)}

Safety invariants to uphold:
{json.dumps(invariants, indent=2)}

Instructions:
1. Inspect existing code and write the complete, minimal implementation.
2. Add or update focused unit and widget tests (prioritize companion test files).
3. Run the self-healing gate:
   - For Flutter: `dart format --output=none --set-exit-if-changed .`, `dart analyze`, and `flutter test test/<test_file>.dart`
   - For Functions: `npm run lint`, `npm run build`, `npm test` in `src/robinhood_options_mobile/functions/`
4. If errors occur, diagnose and repair (up to 3 attempts).
5. Call finish with your implementation summary and verification results.
""",
                role=f"Maker: {title[:24]}",
                workspace="branch" if max_parallel > 1 else "inherit"
            )

            maker_result = await maker(
                "Implement the feature and verify all tests pass cleanly.",
                {"type": "object", "properties": {"success": {"type": "boolean"}, "summary": {"type": "string"}}, "required": ["success", "summary"]}
            )
            del maker

            # Step 3B: Independent Adversarial Critic
            critic = agent(
                prompt=f"""
You are an adversarial QA and Security Auditor for RealizeAlpha.
Inspect the git diff created for task '{title}'.
Verify against the acceptance criteria:
{json.dumps(criteria, indent=2)}

Audit strictly against RealizeAlpha's 7 Core Safety Invariants:
1. Zero Plaintext Credentials (SecureTokenStorage exclusively)
2. FeatureAccessService hierarchy respected
3. Live-quote BUY guard (>3% deviation) and Paper TP/SL exit isolation
4. Balance masking across charts/widgets
5. Cloud Functions auth checks and O(1) indicator space
6. UI accessibility (Semantics labels) and 320px responsive layout
7. Clean compile and strict type safety

Output an approval decision and any blocking issues found.
""",
                role=f"Critic: {title[:24]}"
            )

            critic_result = await critic(
                "Review the changes and return your audit verdict.",
                {
                    "type": "object",
                    "properties": {
                        "approved": {"type": "boolean"},
                        "blocking_issues": {"type": "array", "items": {"type": "string"}},
                        "audit_notes": {"type": "string"}
                    },
                    "required": ["approved", "blocking_issues"]
                }
            )
            del critic

            return {
                "title": title,
                "issue_number": issue_no,
                "maker_result": maker_result,
                "critic_result": critic_result
            }

        # Execute tasks concurrently or sequentially
        if len(items) > 1 and max_parallel > 1:
            results = await parallel(items, execute_item_loop)
        else:
            results = await pipeline(items, execute_item_loop)

        # Check approval results
        iteration_successes = 0
        for res in results:
            approved = res.get("critic_result", {}).get("approved", False)
            issue_id = res.get("issue_number")
            if approved:
                iteration_successes += 1
                if issue_id and issue_id not in state["completed_tasks"]:
                    state["completed_tasks"].append(issue_id)
            else:
                if issue_id and issue_id not in state["failed_tasks"]:
                    state["failed_tasks"].append(issue_id)

        save_run_state(state)

        # Circuit breaker logic
        if iteration_successes == 0 and len(results) > 0:
            consecutive_failures += 1
            log(f"Warning: All tasks in iteration {iteration} failed critic review ({consecutive_failures}/{consecutive_failure_limit}).")
            if consecutive_failures >= consecutive_failure_limit:
                log(f"Circuit Breaker Tripped: {consecutive_failures} consecutive failed iterations. Halting autonomous loop to protect repository stability.")
                break
        else:
            consecutive_failures = 0

        # ==============================================================================
        # Phase 4: Documentation & Roadmap Reconciliation
        # ==============================================================================
        approved_results = [r for r in results if r.get("critic_result", {}).get("approved", False)]
        if approved_results:
            phase(f"Iteration {iteration} - 4. Reconcile Documentation & Roadmap")

            reconciler = agent(
                prompt="""
You are the RealizeAlpha Documentation & Roadmap Reconciler.
Given the verified implementations, update:
1. `ROADMAP.md`: Mark items complete ('- [x]'), ensure issue links are present, keep 'Completed Features' bounded, and reconcile Quick Stats.
2. `CHANGELOG.md`: Add categorized entries ('Added', 'Changed', 'Fixed').
3. `PRODUCT.md` and `docs/`: Document new capabilities or architecture as needed.
4. Run `dart format .` and verify formatting.
""",
                role="Docs & Roadmap Reconciler"
            )

            reconcile_result = await reconciler(
                f"Reconcile documentation and roadmap for completed items: {json.dumps(approved_results, indent=2)}",
                {"type": "object", "properties": {"reconciled": {"type": "boolean"}, "summary": {"type": "string"}}, "required": ["reconciled"]}
            )
            del reconciler
            log(f"Reconciliation summary: {reconcile_result.get('summary')}")

            # ==============================================================================
            # Phase 5: Git & Issue Lifecycle (Dual-Mode)
            # ==============================================================================
            phase(f"Iteration {iteration} - 5. Git & Release Readiness")

            if mode == "autonomous":
                lifecycle = agent(
                    prompt="""
You handle Git and GitHub Issue lifecycle in autonomous factory mode.
For each verified item:
1. Commit changes referencing the issue (e.g. `feat(...): ... (#<num>)`).
2. Add a verification comment to the GitHub issue with test evidence and close it (`gh issue close <num>`).
3. Check if release readiness gates are met; do NOT push release commits to main without explicit human confirmation.
""",
                    role="Lifecycle Manager"
                )
                lifecycle_result = await lifecycle(
                    f"Finalize git commits and GitHub issue status for: {json.dumps(approved_results, indent=2)}",
                    {"type": "object", "properties": {"completed": {"type": "boolean"}, "details": {"type": "string"}}, "required": ["completed"]}
                )
                del lifecycle
                log(f"Lifecycle result: {lifecycle_result.get('details')}")
            else:
                log("Interactive mode: Git commits, pushes, and issue closures are held for user confirmation.")
                break

    log(f"Software Factory autonomous loop finished after {iteration} iteration(s). Completed: {state.get('completed_tasks')}, Failed: {state.get('failed_tasks')}.")


# Execute the async pipeline in the current event loop
asyncio.run(run_pipeline())
