---
name: roadmap-ideation
description: "Generate evidence-backed roadmap proposals and, after the user selects them, record selected items in ROADMAP.md and link GitHub issues."
---

# Roadmap Ideation

Find useful new roadmap candidates for Clinical Assistant by considering both
the existing `ROADMAP.md` and GitHub issues. Use this workflow when asked to
brainstorm, identify, or propose future roadmap items. This is a planning task:
do not implement the proposals.

## Workflow

1. **Read the current product context.** Read `AGENTS.md`, `PRODUCT.md`, and
   `ROADMAP.md`. Check `git status --short` and preserve existing worktree
   changes. Read relevant nearby code or tests to verify whether an apparent
   gap is already implemented or underway. Keep exploration focused on the
   product area being considered.

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
   extensions that advance Clinical Assistant's purpose and principles, even
   when no GitHub issue or explicit user request exists. Exclude work already
   shipped, already planned under another name, duplicates, and issues that
   are merely implementation details of an existing item. For a new feature
   without direct issue evidence, state the user benefit and product-context
   rationale, and label material assumptions or strategic hypotheses clearly.
   Do not treat issue volume, age, or reactions alone as proof of priority.

4. **Shape and rank proposals.** Produce a small, prioritized set of distinct
   candidates. For each, provide a concise title, user need and proposed
   outcome, evidence and rationale (with relevant issue links when available),
   suggested milestone or horizon, and a short scope or acceptance outline.
   For issue-independent feature ideas, ground the rationale in the product
   purpose, principles, or verified current capabilities rather than inventing
   user demand. Note dependencies,
   uncertainty, and material privacy, security, platform, or clinical risks.
   Prefer clear outcomes that can be broken into deliverable work; avoid vague
   themes, oversized bundles, arbitrary technical work, and unsupported
   promises. Keep proposals consistent with patient privacy, provenance, and
   descriptive non-diagnostic behavior. Present the candidates with stable
   numbers or identifiers and ask which ones the user wants recorded. Accept a
   selection by identifier, "all", or "none". If the user already specified
   their selection, use it; otherwise do not edit `ROADMAP.md` or create GitHub
   issues until they choose. If they choose none, finish with the proposals
   only.

5. **Record selected proposals and associate GitHub issues.** Process only
   recommendations the user selected. For each, search open and closed issues
   for a matching issue. Link the existing issue when one already tracks the
   same outcome; do not create duplicates. Choose the most appropriate
   existing roadmap milestone, then immediately add only the selected
   recommendations to `ROADMAP.md`, matching its checkbox and nesting
   conventions and keeping entries unchecked. Avoid duplicating roadmap
   entries. This roadmap edit is mandatory and must happen before any issue
   creation call; do not defer it because GitHub requires confirmation or
   presents an interactive form.

   For an existing matching issue, include its link in the roadmap entry. For
   a proposal that needs a new issue, add the roadmap entry first and include
   the issue link as soon as creation succeeds. Create one issue per proposal
   using its concise title and a body describing the user need, evidence,
   proposed outcome, acceptance outline, suggested roadmap horizon,
   dependencies, and material risks. Use the configured repository and
   available GitHub issue creation tools (or `gh issue create` when
   appropriate); do not create a PR, invent labels, or create milestones. If
   issue creation pauses for user confirmation, leave the roadmap entry in
   place and resume afterward to add the resulting link. If GitHub is
   unavailable or issue creation fails, keep the roadmap entry without a
   fabricated link and clearly report which issue could not be associated.

   Before finishing, verify that every selected proposal appears exactly once
   as an unchecked item in the intended `ROADMAP.md` milestone and that every
   successfully matched or created issue is linked there. Report any item
   whose issue could not be associated. Never implement the proposed work as
   part of this ideation task.

## Completion Report

Summarize the proposals and the user's selection. For selected items, identify
the exact roadmap additions, placement, evidence, associated issue links, and
whether each issue was reused or created. State whether roadmap or GitHub data
could not be reviewed, or any issue could not be associated. Confirm that
unselected items were not recorded and no implementation or PR was created.