---
name: update-docs
description: Update markdown documentation, changelog, roadmap, and app version based on recent changes and commits with automated drift verification.
---

# Update Documentation

Update all markdown documentation based on recent commits or verified implementation tasks.
Supports standalone invocation, documentation drift audits, or direct chaining from
`software-implementation` and `software-factory`.

## Argument Hint

Optional parameters:
- `version`: Next semantic version number (e.g., `0.62.1`). If omitted, inspects git tags and recent commits to determine if a version bump is warranted.
- `bump_version`: `true` or `false` (default: `false` for intra-milestone task reconciliation, `true` when cutting a release boundary).
- `mode`: `interactive` (default) or `autonomous` (automatically formats and synchronizes documentation).

## Workflow

1. **Fetch Commit Information**: Retrieve details from commits or current staged changes:
   - Commit message, description, and patches
   - GitHub issue references and PR numbers (`#123`, `fixes #123`, `closes #123`)
   - Authors and dates

2. **Identify Documentation Files**: Locate all markdown and project files:
   - `CHANGELOG.md`
   - `README.md`
   - `ROADMAP.md`
   - `PRODUCT.md`
   - Feature docs (`docs/` directory)
   - Developer instruction files (`.github/` and `AGENTS.md`)
   - `pubspec.yaml`

3. **Version & pubspec.yaml Handling**:
   - If `bump_version: true` or a specific version argument is supplied:
     - Check current version in `src/robinhood_options_mobile/pubspec.yaml`.
     - Increment semantic version (major for breaking, minor for features, patch for fixes).
     - Increment build number monotonically (e.g., `0.62.1+207`).
   - If `bump_version: false`:
     - Maintain existing `pubspec.yaml` version for intra-milestone feature reconciliation.

4. **Update CHANGELOG.md**:
   - For version releases, add a new version section with the current date.
   - For task reconciliation, ensure all new features, fixes, or security improvements have descriptive bullet points under the active unreleased or current version section.
   - Group entries: **Added**, **Changed**, **Fixed**, **Removed**, **Security**, **Performance**.
   - Reference associated GitHub issues `([#<num>](https://github.com/CIInc/robinhood-options-mobile/issues/<num>))`.

5. **Update Feature Docs & PRODUCT.md**:
   - Add or update dedicated feature guides in `docs/` (architecture, algorithms, configuration, operational guides).
   - Update `PRODUCT.md` with new domain models, services, and architectural additions.
   - Update technical parameters, code examples, and mermaid diagrams.

6. **Update ROADMAP.md & Synchronize GitHub Issues**:
   - Mark completed features done (`- [x]`) and ensure GitHub issue links are present.
   - **Automated Roadmap Invariant Check**:
     - Programmatically verify and update **Quick Stats** in `ROADMAP.md` (completed checklist items, planned checklist items per milestone, open/closed issues).
     - Maintain **Key Highlights** as a strictly bounded executive list (maximum 3–5 items); prune older entries as new releases ship.
     - Keep **Completed Features ✅** bounded to high-level capability blocks for recent active minor releases, delegating exhaustive chronological history to `CHANGELOG.md`.

7. **Cross-Check Consistency & Technical Accuracy**:
   - Verify file paths, class names, API signatures, and configuration keys match code across `lib/`, `functions/src/`, and `firebase/`.
   - Validate relative markdown links and section anchors between touched docs.
   - Verify that all open GitHub issues are accurately reflected in `ROADMAP.md`.

8. **Automated Quality & Self-Healing Formatting Gate**:
   - Format Dart code: `cd src/robinhood_options_mobile && dart format .`
   - Verify clean formatting: `cd src/robinhood_options_mobile && dart format --output=none --set-exit-if-changed .`
   - Format Functions code: `cd src/robinhood_options_mobile/functions && npm run lint -- --fix`
   - Verify Functions lint and build: `cd src/robinhood_options_mobile/functions && npm run lint && npm run build`
   - Run affected tests to verify widget titles and assertions align with documentation.

## Completion Report

Summarize all documentation updates made, version bump details (if applied),
roadmap Quick Stats reconciliation, and quality gate check results.
