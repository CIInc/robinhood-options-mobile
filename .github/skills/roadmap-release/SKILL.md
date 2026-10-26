---
name: roadmap-release
description: "Use when preparing a RealizeAlpha release: review commits, choose a version, update release documentation and roadmap, reconcile GitHub issues, run project quality gates, and verify the Android/iOS release workflow."
---

# Release

Prepare a RealizeAlpha app release from recent changes. Keep release notes,
version metadata, roadmap status, trading safety invariants, and platform
compliance information aligned with the implementation.

## Arguments

Provide the next semantic app version, optionally followed by a build number
(for example, `0.59.1 186` or `0.60.0`). If no version is provided, inspect the
latest release tag and commits since that tag to recommend a version. Ask before
choosing when the change set does not clearly indicate patch, minor, or major
impact.

## Workflow

1. **Check repository state and release history.** Run `git status --short`,
   inspect the current branch, find the latest version tag with
   `git describe --tags --abbrev=0`, and review commits since that tag. If there
   is no tag, use the current `src/robinhood_options_mobile/pubspec.yaml` version
   and recent history as context; do not invent a previous release boundary.
   Read commit subjects, bodies, changed paths, and relevant diffs. Record dates,
   authors, and issue or PR references when available. Preserve all pre-existing
   worktree changes.

2. **Inventory the documentation.** Review relevant content in:
   - `CHANGELOG.md` — Active history of version additions, changes, and fixes.
   - `ROADMAP.md` — Feature tracking, Quick Stats, and Release Versions & Timeline.
   - `PRODUCT.md` — Core vision, architecture, and capabilities.
   - `README.md` — High-level feature list and user onboarding.
   - `AGENTS.md` and `.github/copilot-instructions.md` — Core architectural rules.
   - `docs/` — Feature specifications, risk models, and backend architecture.

3. **Choose and apply version metadata.** The app version is declared in
   `src/robinhood_options_mobile/pubspec.yaml` as `major.minor.patch+build`
   (e.g., `0.59.0+185`). Use semantic versioning:
   - **Patch (`0.59.1`)**: Backward-compatible bug fixes and minor improvements.
   - **Minor (`0.60.0`)**: New user-facing trading features, screens, or broker support.
   - **Major (`1.0.0`)**: Breaking architectural changes or milestone overhaul.

   Increment the build number monotonically with each release. Keep the version
   consistent with the release tag (e.g., `v0.59.1`) and `CHANGELOG.md`. Do not
   edit generated platform version files directly when they derive from Flutter
   metadata.

4. **Write release notes in CHANGELOG.md.** Add a dated version section at the top
   of `CHANGELOG.md` following the existing format:
   - Group entries into clear categories: **Added**, **Changed**, **Fixed**,
     **Removed**, **Security**, and **Performance**.
   - Reference verified GitHub issues and PRs using full Markdown links:
     `[#<num>](https://github.com/CIInc/robinhood-options-mobile/issues/<num>)`.
   - Use concise, descriptive bullet points highlighting user-visible impact,
     trading safety enhancements, and algorithmic optimizations.

5. **Update product documentation.** Update `README.md` for major feature
   deliveries, and update `PRODUCT.md`, `docs/`, or `.github/copilot-instructions.md`
   when architecture, services, or models have evolved. Keep documentation
   strictly grounded in implemented code; do not document speculative roadmap
   proposals as shipped features.

6. **Reconcile the roadmap and GitHub issues.**
   - Review completed roadmap items against code and mark them complete (`[x]`).
   - Query GitHub issues with `gh issue list --state all --limit 1000 --json number,title,state,url,labels,updatedAt`
     when GitHub CLI is accessible.
   - Ensure linked issues in `ROADMAP.md` are accurate and verified.
   - Update the **Quick Stats** table in `ROADMAP.md` (active open issues, completed
     features count, planned items).
   - Add a new entry to the **Release Versions & Timeline** section in `ROADMAP.md`.
   - Do not close, reopen, or edit GitHub issues unless explicitly requested.

7. **Review agent and developer guidance.** Check `AGENTS.md`, `.agents/`, and
   `.github/` instructions for architecture or workflow notes that recent changes
   affect. Update only relevant guidance; do not duplicate existing rules.

8. **Cross-check trading safety & platform compliance.** Verify:
   - **Zero Plaintext Tokens**: Ensure brokerage OAuth credentials and API tokens
     are stored exclusively via `SecureTokenStorage` (`flutter_secure_storage`).
   - **Trading Invariants**: Confirm auto-trade live-quote BUY guards, risk circuit
     breaker lockouts, dynamic sizing boundaries, and aggregate view order locks
     are maintained.
   - **Privacy & Masking**: Verify balance masking is respected across charts and
     widgets, and private multi-broker tax lots are not leaked to shared collections.
   - **Platform Entitlements**: Review iOS FaceID (`NSFaceIDUsageDescription`),
     push notifications, and Android biometric/network permissions.
   - **Export Compliance**: Verify `ITSAppUsesNonExemptEncryption` declarations
     match the app's cryptographic and HTTPS/TLS usage.

9. **Run project quality gates.** Follow the verification standards in `AGENTS.md`:

   **Flutter Mobile (`src/robinhood_options_mobile`):**
   ```bash
   cd src/robinhood_options_mobile && dart format --output=none --set-exit-if-changed .
   cd src/robinhood_options_mobile && dart analyze
   cd src/robinhood_options_mobile && flutter test test/<impacted_test_file>.dart
   ```
   *(Run targeted tests for impacted components; avoid running the entire test suite at once as it is large.)*

   **Cloud Functions Backend (`src/robinhood_options_mobile/functions`):**
   ```bash
   cd src/robinhood_options_mobile/functions && npm run lint
   cd src/robinhood_options_mobile/functions && npm run build
   cd src/robinhood_options_mobile/functions && npm test
   ```
   *(Functions enforce Google ESLint rules with `max-len <= 80`; use `npm run lint -- --fix` when necessary.)*

   Do not build platform binaries locally for routine release preparation.
   The canonical release builds are produced by GitHub Actions:
   - `.github/workflows/release.yml`: Triggered by `v*.*.*` tags or manual dispatch;
     builds Android APK and iOS IPA, attaching them to draft GitHub Releases.
   - `.github/workflows/cd.yml`: Handles continuous store deployment pipelines.

10. **Ask before committing and triggering deployment.** After release
    preparation and validation checks pass cleanly, summarize the changes and ask
    whether the user wants you to commit, push the release changes, and push a
    `v<major.minor.patch>` tag. Explain that pushing this tag triggers
    `.github/workflows/release.yml`.

    Do not stage, commit, push, or tag until the user explicitly approves.

    If approved:
    - Recheck the branch, worktree, and remote. Ensure `pubspec.yaml` matches the tag.
    - Stage only the changes prepared for this release. Exclude unrelated user changes.
    - Commit and push release changes to the remote branch first. If the branch push
      fails, stop; do not push a tag.
    - Create and push the version tag (`git tag v<version> && git push origin v<version>`).
    - Verify workflow execution on GitHub Actions and report the deployment status.

    If declined, leave changes uncommitted and untagged. Report any missing credentials
    or review steps plainly.

## Completion Report

Summarize the version/build number decision, `CHANGELOG.md` entries, `ROADMAP.md`
reconciliation, quality gates executed (formatting, static analysis, unit tests,
functions build/lint), user approval status, and release workflow execution details.