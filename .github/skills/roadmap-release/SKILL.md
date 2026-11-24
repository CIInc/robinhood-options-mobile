---
name: roadmap-release
description: "Prepare and audit a RealizeAlpha release: review changes, bump versions, audit safety invariants and roadmap completion, run quality gates, and verify the CI/CD deployment pipeline."
---

# Release

Prepare a RealizeAlpha app release from recent changes. Keep release notes,
version metadata, roadmap status, trading safety invariants, and platform
compliance information aligned with the implementation.

## Arguments

Optional parameters:
- Version string and build number (e.g., `0.63.0 207`). If omitted, inspects recent commits and tags to recommend the next semantic version.
- `confirm_release_push`: `true` or `false` (default: `false`).
  - To protect production stores (Google Play and Apple TestFlight), pushing the release commit to `main` requires explicit human approval unless `confirm_release_push=true` is explicitly provided.

## Workflow

1. **Check repository state and release history.** Run `git status --short`,
   inspect the current branch, find the latest version tag with
   `git describe --tags --abbrev=0`, and review commits since that tag. Read
   commit subjects, changed paths, and issue/PR references. Preserve all pre-existing
   worktree changes.

2. **Inventory documentation & roadmap state.**
   - Review `CHANGELOG.md`, `ROADMAP.md`, `PRODUCT.md`, `README.md`, `AGENTS.md`, and `docs/`.
   - Verify that all claimed `[x]` items for this version in `ROADMAP.md` have
     passing unit/widget tests and corresponding `docs/` feature notes.

3. **Choose and apply version metadata.**
   - Update `src/robinhood_options_mobile/pubspec.yaml` with `version: major.minor.patch+build`
     (e.g., `0.63.0+207`). Follow semantic versioning.
   - Increment the build number monotonically.

4. **Write release notes in CHANGELOG.md & ROADMAP.md.**
   - Add a dated version section at the top of `CHANGELOG.md` with categories:
     **Added**, **Changed**, **Fixed**, **Removed**, **Security**, **Performance**.
   - Reference verified GitHub issues and PRs with Markdown links.
   - Add or update the version entry in the **Release Cadence & Milestone Overview**
     table in `ROADMAP.md`.
   - Ensure release note formatting enables `.github/workflows/cd.yml` to extract
     clean release notes for Google Play (whatsnew-en-US) and TestFlight (WhatToTest.en-US.txt).

5. **Reconcile roadmap invariants.**
   - Update the **Quick Stats** table in `ROADMAP.md`.
   - Prune **Key Highlights** to a bounded list of at most 3–5 high-impact items.
   - Ensure **Completed Features ✅** remains bounded to recent active minor releases,
     summarizing older historical items into `CHANGELOG.md`.

6. **Cross-check trading safety & platform compliance.**
   Audit against RealizeAlpha's core invariants:
   - Zero plaintext credentials stored in unencrypted storage (`SecureTokenStorage` exclusively).
   - Auto-trade live-quote BUY guards, risk circuit breaker lockouts, and dynamic sizing bounds verified.
   - Balance masking respected across charts and widgets; multi-broker tax lots stay on-device.
   - iOS entitlements (`NSFaceIDUsageDescription`, `ITSAppUsesNonExemptEncryption`) and Android permissions validated.

7. **Run project quality gates.**
   - **Flutter Mobile (`src/robinhood_options_mobile`):**
     ```bash
     cd src/robinhood_options_mobile && dart format --output=none --set-exit-if-changed .
     cd src/robinhood_options_mobile && dart analyze
     cd src/robinhood_options_mobile && flutter test test/<impacted_test_file>.dart
     ```
   - **Cloud Functions Backend (`src/robinhood_options_mobile/functions`):**
     ```bash
     cd src/robinhood_options_mobile/functions && npm run lint
     cd src/robinhood_options_mobile/functions && npm run build
     cd src/robinhood_options_mobile/functions && npm test
     ```

8. **Human Confirmation & Deployment Trigger.**
   - Present the complete release package (version, changelog notes, quality check output).
   - If `confirm_release_push` is `false`, pause and ask whether the user wants you
     to commit and push to `main`.
   - If approved:
     - Stage only release-prepared changes.
     - Commit and push to `main`. Pushing a new version in `pubspec.yaml` triggers
       `.github/workflows/cd.yml`, building signed Android (`.aab`/`.apk`) and iOS (`.ipa`)
       artifacts and deploying Firebase resources.
     - Monitor workflow execution with `gh run list --workflow=cd.yml` and report progress.

## Completion Report

Summarize the version decision, `CHANGELOG.md` notes, `ROADMAP.md` reconciliation,
quality gates output, user confirmation status, and CI/CD workflow status.
