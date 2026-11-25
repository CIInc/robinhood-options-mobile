# ADR-002: Staged External Context & Zero-PII Boundary

- **Status:** Accepted
- **Date:** 2026-11-24
- **Context doc:** [Software Factory architecture](../software-factory.md)

## Context & Problem Statement
Autonomous AI coding agents frequently require real-world context—such as sudden production crash spikes from Crashlytics, repeated user review friction points, developer consensus discussions from Slack/Teams, and upcoming macro market announcements (FOMC, quadruple witching)—to prioritize high-impact backlog items and avoid operating in an insular vacuum.

However, granting autonomous agents direct network access or live API credentials to corporate messaging platforms (Slack, Teams, WhatsApp, Discord) or live cloud monitoring consoles (Firebase Crashlytics, GCP Cloud Logging) introduces severe risks:
1. **Accidental Credential & Token Exfiltration**: Live tokens stored in agent execution contexts could leak in error logs or PR artifacts.
2. **Customer PII Exposure**: Raw crash dumps and customer reviews frequently contain personal data (customer names, emails, account numbers, IP addresses).
3. **Flaky & Non-Deterministic Execution**: Direct network dependencies on external APIs cause timeouts and unrepeatable simulation runs.

## Decision
1. **Staged Filesystem Adapter Pattern (`.agents/context/`)**: External signals are staged locally as structured JSON files (`telemetry_crashes.json`, `user_feedback.json`, `developer_brief.json`, `market_calendar.json`) under `.agents/context/`.
2. **Version-Controlled Zero-PII Templates**: Canonical schema templates (`*.template.json`) with sample fixtures are committed to git, while live JSON files remain ignored in `.gitignore`.
3. **Mandatory PII Scrubbing & Schema Enforcement**: Staged files must be sanitized of customer identifiers and tokens prior to ingestion, declare `"pii_scrubbed": true`, and pass validation via `.agents/context/scripts/validate_context.py`.
4. **CI Invariant Enforcement**: GitHub Actions (`software-factory-verify.yml`) automatically blocks pull requests if any non-template `.agents/context/*.json` file is committed, guaranteeing that live external context never pollutes git history.
5. **Outbound-Only Notification Cards**: In lieu of direct two-way chat connections, the factory dispatches structured summary cards via outbound webhook URLs (`SLACK_WEBHOOK_URL`, `TEAMS_WEBHOOK_URL`, `DISCORD_WEBHOOK_URL`) upon cycle completion.

## Consequences & Benefits
- **Hermetic & Deterministic Simulation**: Dry-run simulations seamlessly fall back to canonical template fixtures without requiring network access or external credentials.
- **Strict Privacy Invariant Compliance**: Prevents customer PII and OAuth tokens from ever entering agent prompts or version control.
- **Turnkey Community & Team Integration**: Any external service (CI cron, Sentry webhook, store review scraper) can deliver context by simply writing a scrubbed JSON file to `.agents/context/`.
