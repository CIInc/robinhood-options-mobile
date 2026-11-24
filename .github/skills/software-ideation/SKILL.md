---
name: software-ideation
description: "Generate evidence-backed roadmap proposals and, after selection or under autonomous factory mode, record selected items in ROADMAP.md and link GitHub issues."
---

# Roadmap Ideation

Find useful new roadmap candidates for RealizeAlpha by considering both
the existing `ROADMAP.md` and GitHub issues. Use this workflow when asked to
brainstorm, identify, or propose future roadmap items. This is a planning and
triage task: do not implement the proposals.

## Argument Hint

Optional parameters:
- Product domain or horizon to explore (e.g., "portfolio analytics", "v0.63.0", "cross-broker rebalancing").
- `mode`: `interactive` (default) or `autonomous` (automatically selects and records top proposals meeting the factory rubric without pausing).

## Workflow

1. **Read the current product context.** Read `AGENTS.md`, `PRODUCT.md`, and
   `ROADMAP.md`. Check `git status --short` and preserve existing worktree
   changes. Read relevant nearby code or tests to verify whether an apparent
   gap is already implemented or underway. Keep exploration focused on the
   product area being considered. When surveying large domains, optionally
   delegate read-only exploration to a `research` subagent.

2. **Review GitHub issues.** Determine the repository from its configured Git
   remote rather than guessing. When GitHub CLI access is available, list open
   issues with titles, bodies, labels, URLs, milestones, and update times (for
   example,
   `gh issue list --state open --limit 1000 --json number,title,body,url,labels,milestone,updatedAt`).
   Otherwise use available GitHub issue search/list tools. Read relevant issue
   details and comments to understand the underlying need, constraints,
   frequency, and any existing proposal. Search closed issues when useful to
   avoid resurfacing completed or deliberately rejected work. If GitHub cannot
   be accessed, disclose that limitation and do not imply issue evidence was
   reviewed.

3. **Identify gaps and explore new feature opportunities.** Compare issue
   requests and recurring user problems with existing roadmap entries and
   current behavior, but do not limit ideation to reported problems or known
   gaps. Actively consider useful new capabilities, workflows, and product
   extensions that advance RealizeAlpha's purpose and principles, even
   when no GitHub issue or explicit user request exists. Exclude work already
   shipped, already planned under another name, duplicates, and issues that
   are merely implementation details of an existing item. For a new feature
   without direct issue evidence, state the user benefit and product-context
   rationale, and label material assumptions or strategic hypotheses clearly.
   Do not treat issue volume, age, or reactions alone as proof of priority.

4. **Shape and rank proposals.** Produce a small, prioritized set of distinct
   candidates. For each, provide a concise title, user need and proposed
   outcome, evidence and rationale (with relevant issue links when available),
   suggested milestone or horizon (noting whether it aligns with an existing
   milestone or warrants defining a new milestone / reevaluating the milestone list),
   and a short scope or acceptance outline.
   For issue-independent feature ideas, ground the rationale in the product
   purpose, principles, or verified current capabilities rather than inventing
   user demand. Note dependencies,
   uncertainty, and material privacy, security, platform, or financial/execution risks.
   Prefer clear outcomes that can be broken into deliverable work; avoid vague
   themes, oversized bundles, arbitrary technical work, and unsupported
   promises. Keep proposals consistent with account privacy, data provenance, and
   descriptive non-advisory behavior.

5. **Selection & Decision Gate (Dual-Mode):**
   - **Interactive Mode (Default)**:
     Present candidates with stable identifiers and ask the user which items to record.
     Accept selections by identifier, "all", or "none". Do not edit `ROADMAP.md` or
     create GitHub issues until the user explicitly selects.
   - **Autonomous Factory Mode (`mode=autonomous`)**:
     Evaluate candidates against the **Software Factory Readiness Rubric**:
     1. Clear existing code owner and bounded scope.
     2. Verifiable with unit/widget tests without requiring live production credentials.
     3. Adheres strictly to the 7 core safety invariants.
     Automatically record the top $1-3$ highest-scoring items without pausing.

6. **Record selected proposals and associate GitHub issues.**
   - Search open and closed issues for a matching issue; link existing issues rather than duplicating.
   - Determine milestone placement in `ROADMAP.md`. If a new milestone is warranted, update the Release Cadence table, Table of Contents, and Quick Stats consistently.
   - Add only selected proposals to `ROADMAP.md`, matching its checkbox conventions (`- [ ]`) and keeping entries unchecked.
   - For items needing new issues, create one issue per proposal using `gh issue create` with structured acceptance criteria, invariants, and suggested horizon.
   - Verify every selected proposal appears exactly once in `ROADMAP.md` with its issue link.

## Completion Report

Summarize the proposals and selection outcome. For recorded items, identify
the exact roadmap additions, milestone placement, associated issue links (reused or created),
and execution mode. Confirm that unselected items were not recorded and no implementation
code was modified.
