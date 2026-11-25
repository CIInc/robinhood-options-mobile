# External Context Staging (`.agents/context/`)

This directory serves as the **Staged Context Adapter** for the RealizeAlpha Autonomous AI Software Factory. It allows external signals—production telemetry, end-user feedback, developer team chats, and market events—to feed directly into the factory's **Phase 1: Ideation & Backlog Discovery** and **Phase 2: Incident Triage**.

---

## 1. Directory Schemas & Templates

| File | Template | Source | Ingestion Purpose |
|---|---|---|---|
| `telemetry_crashes.json` | [`telemetry_crashes.template.json`](telemetry_crashes.template.json) | Firebase Crashlytics, Sentry, GCP Cloud Logging | High-velocity error clusters trigger accelerated hotfix tasks with exact stack traces and companion tests. |
| `user_feedback.json` | [`user_feedback.template.json`](user_feedback.template.json) | iOS App Store, Google Play Reviews, Beta Labs Surveys | Natural language sentiment clusters identify repeated friction points and guide UI/UX optimization tasks. |
| `developer_brief.json` | [`developer_brief.template.json`](developer_brief.template.json) | Slack, Microsoft Teams, WhatsApp, Discord Digests | High-priority architectural decisions and feature requests discussed by the engineering team. |
| `market_calendar.json` | [`market_calendar.template.json`](market_calendar.template.json) | Economic Calendar, FOMC, OCC corporate action memos | Prevents deployments during high-volatility events; ensures option contract math remains compliant. |

---

## 2. Privacy & Security Invariants

> [!CAUTION]
> **Zero Plaintext Credentials & PII Invariant:**
> Raw customer identifiers, private account balances, passwords, brokerage OAuth tokens, and sensitive personal data must **NEVER** be written to this directory.
> All external context collectors must scrub PII (anonymizing user IDs and replacing sensitive numbers with placeholders) before writing to `.agents/context/`.

---

## 3. Version Control Policy

- Template files (`*.template.json`) and this `README.md` are checked into git as schema definitions.
- Live context files (`*.json` excluding `*.template.json`) are ignored by `.gitignore` to ensure transient runtime telemetry is never committed to repository history.
