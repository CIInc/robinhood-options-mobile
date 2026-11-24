"""
Autonomous AI Software Factory Pipeline Script for RealizeAlpha.
Executed by Antigravity's run_workflow tool (top-level execution).
"""

import asyncio
import json

# Arguments passed into run_workflow are injected into the global `args` dict
# In standalone linting, fallback to defaults
try:
    _args = args
except NameError:
    _args = {}

mode = _args.get("mode", "autonomous")  # "autonomous" or "interactive"
stages = _args.get("stages", "full")    # "full", "implement-batch", "single"
max_parallel = int(_args.get("max_parallel", 1))
focus = _args.get("focus", "")


async def run_pipeline():
    log(f"Starting Software Factory pipeline: mode={mode}, stages={stages}, max_parallel={max_parallel}, focus='{focus}'")

    # ==============================================================================
    # Phase 1: Triage & Disjoint Task Partitioning
    # ==============================================================================
    phase("1. Triage & Partition")

    triage_prompt = f"""
You are the Software Factory Triage Coordinator for RealizeAlpha.
Inspect ROADMAP.md and open GitHub issues (using git/gh tools).
Identify up to {max_parallel} actionable, unchecked ('- [ ]') items from ROADMAP.md.
Focus area: '{focus}' (if specified).

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
        log("No actionable tasks identified. Halting pipeline.")
        return

    # ==============================================================================
    # Phase 2: Staged Maker - Verifier - Critic Loop (Parallel or Sequential)
    # ==============================================================================
    phase("2. Maker-Verifier-Critic Execution")

    async def execute_item_loop(task_item):
        title = task_item.get("title")
        issue_no = task_item.get("issue_number")
        targets = task_item.get("target_files", [])
        criteria = task_item.get("acceptance_criteria", [])
        invariants = task_item.get("safety_invariants", [])

        log(f"Starting Maker for: {title} (#{issue_no})")

        # Step 2A: Maker Agent
        maker = agent(
            prompt=f"""
You are an expert Flutter/Dart and Firebase Cloud Functions software engineer working on RealizeAlpha.
Your task: Implement '{title}' (Issue #{issue_no}).
Target files: {targets}
Acceptance criteria:
{json.dumps(criteria, indent=2)}

Safety invariants to uphold:
{json.dumps(invariants, indent=2)}

Instructions:
1. Inspect existing code and write the complete, minimal implementation.
2. Add or update focused unit and widget tests.
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

        # Step 2B: Independent Adversarial Critic
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

    log(f"Execution complete for {len(results)} item(s).")

    # ==============================================================================
    # Phase 3: Documentation & Roadmap Reconciliation
    # ==============================================================================
    phase("3. Reconcile Documentation & Roadmap")

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
        f"Reconcile documentation and roadmap for completed items: {json.dumps(results, indent=2)}",
        {"type": "object", "properties": {"reconciled": {"type": "boolean"}, "summary": {"type": "string"}}, "required": ["reconciled"]}
    )
    del reconciler
    log(f"Reconciliation summary: {reconcile_result.get('summary')}")

    # ==============================================================================
    # Phase 4: Git & Issue Lifecycle (Dual-Mode)
    # ==============================================================================
    phase("4. Git & Release Readiness")

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
            f"Finalize git commits and GitHub issue status for: {json.dumps(results, indent=2)}",
            {"type": "object", "properties": {"completed": {"type": "boolean"}, "details": {"type": "string"}}, "required": ["completed"]}
        )
        del lifecycle
        log(f"Lifecycle result: {lifecycle_result.get('details')}")
    else:
        log("Interactive mode: Git commits, pushes, and issue closures are held for user confirmation.")

    log("Software Factory pipeline finished successfully.")


# Execute the async pipeline in the current event loop
asyncio.run(run_pipeline())
