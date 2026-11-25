# ADR-003: In-Workflow Release Cadence & Milestone Horizon Isolation

- **Status:** Accepted
- **Date:** 2026-11-24
- **Context doc:** [Software Factory architecture](../software-factory.md)

## Context & Problem Statement
In an autonomous closed-loop software factory, **Ideation & Backlog Discovery** runs alongside **Maker–Verifier Implementation**. If release cuts depend on backlog exhaustion (i.e. waiting until all roadmap tasks are unchecked and complete), the factory enters an **infinite execution loop**: every iteration discovers and records new qualified feature proposals faster than the implementation phase can ship them. As a result, software is never packaged into a semantic release or promoted to users.

## Decision
1. **In-Workflow Release Decision Phase**: Introduce an explicit **Phase 6: Release Cadence & Grouping Decision** inside the continuous loop rather than treating releases as an external trigger after complete backlog drain.
2. **Configurable Cadence Policies**: Support three release triggering modes:
   - `milestone` (default): Packages and cuts a release when the active release milestone criteria or feature batch threshold (`release_threshold`, default: 2) is reached.
   - `batch_size`: Packages and cuts a release as soon as $N$ verified features have passed Maker-Verifier-Critic gates.
   - `manual`: Bypasses automated releases, holding verified commits on feature branches for developer sign-off.
3. **Milestone Horizon Isolation**: During Phase 1 (Ideation), newly discovered features are classified by horizon. Proposals queued for future releases are tagged with `future_horizon: True` and recorded under future milestone headings in `ROADMAP.md` without expanding the active release milestone scope.
4. **Automated Keep-a-Changelog Categorization**: Automatically parse conventional commit prefixes (`feat`, `fix`, `perf`, `sec`) into standard Keep-a-Changelog sections (`### Added`, `### Fixed`, `### Changed`, `### Security`) during release packaging.
5. **Human Gate for Release Tags**: In-workflow packaging generates release notes, bumps semantic version in `pubspec.yaml`, and creates the release commit, but strictly preserves a human confirmation gate before pushing git tags to `main` or triggering store deployment pipelines.

## Consequences & Benefits
- **Deterministic Release Velocity**: Software is continuously packaged and released in small, verified increments (e.g. 2–3 features per release) rather than accumulating risky, monolithic releases.
- **Backlog Scope Protection**: Ongoing ideation continues to enrich the long-term product roadmap without delaying the current release cycle.
- **Zero Infinite Loop Risk**: The autonomous factory reliably completes cycles and reaches release milestones even with an infinite supply of candidate ideas.
