---
name: update-docs
description: Update markdown documentation, changelog, roadmap, and app version based on recent changes and commits.
---

# Update Documentation

Update all markdown documentation based on recent commits since the previous version.

## Argument Hint

Provide the next version number to base the updates on recent commits since the previous version (e.g., `0.37.2`). If not provided, inspect recent commit history and calculate the next semantic version based on changes since the last release.

## Workflow

1. **Fetch Commit Information**: Retrieve details from the commits including:
   - Commit message and description
   - File changes and patches
   - Commit date and author
   - GitHub issue references and PR numbers (e.g., `#123`, `fixes #123`, `closes #123`)

2. **Identify Documentation Files**: Locate all markdown files in the repository:
   - `CHANGELOG.md`
   - `README.md`
   - `ROADMAP.md`
   - Documentation files (`docs/` directory)
   - Developer instruction files (`.github/` directory, especially `.github/copilot-instructions.md`)
   - Any other `.md` files

3. **Update pubspec.yaml**:
   - Check the current version number in `src/robinhood_options_mobile/pubspec.yaml` and compare it to the argument provided (if any).
   - If different, update the version in `pubspec.yaml` based on semantic versioning rules:
     - Major version for breaking changes
     - Minor version for new features
     - Patch version for bug fixes
   - Ensure the build number is incremented appropriately only if the version number changes.

4. **Update CHANGELOG.md**:
   - Add a new version section with the current date (using the version defined in `pubspec.yaml`).
   - Create a title for the new version.
   - Document all features added, changed, fixed, removed, and performance improvements.
   - Reference associated GitHub issues `([#<num>](https://github.com/CIInc/robinhood-options-mobile/issues/<num>))` where applicable.
   - Use clear, descriptive bullet points.
   - Group related changes together.

5. **Update Docs Markdown Files**:
   - Add or update sections describing new features in `docs/`.
   - Document new configuration options or settings.
   - Include code examples where applicable.
   - Update technical details sections.
   - Add diagrams or screenshots if relevant.
   - Add future enhancements or TODOs if applicable.

6. **Update Main README.md**:
   - Add mentions of new major features to the features list.
   - Ensure feature descriptions are concise but complete.

7. **Update ROADMAP.md & Synchronize GitHub Issues**:
   - Mark completed features as done (`[x]`) and ensure GitHub issue links are present (`[#<num>](https://github.com/CIInc/robinhood-options-mobile/issues/<num>)`).
   - Query GitHub issues (`gh issue list --state all`) to reconcile open vs closed issues against the roadmap.
   - Add newly created GitHub issues into appropriate roadmap categories.
   - Update the **Quick Stats** section in `ROADMAP.md` (active open issues, completed features count, planned items).
   - Add entry in "Release Versions & Timeline" for the new version.
   - Reorder priorities or milestones if necessary.

8. **Update Developer Instructions**:
   - Update `.github/copilot-instructions.md` with new patterns, file references, or architecture notes.
   - Add references to new providers, services, or components.
   - Update architecture notes with new patterns.
   - Add file references for new modules.
   - Update examples section.

9. **Cross-Check Consistency**:
   - Verify version numbers are consistent across all files.
   - Ensure feature descriptions match across all files.
   - Confirm code references are accurate.
   - Validate internal links and GitHub issue links between documentation files.
   - Verify that all open GitHub issues are reflected in `ROADMAP.md`.
   - Check that configuration files match documentation.

10. **Verify Technical Accuracy**:
    - Ensure any mentioned indexes, configurations, or deployment steps are accurate.
    - Verify file paths and code references exist (check `src/robinhood_options_mobile/`, `src/robinhood_options_mobile/functions/`, and `src/robinhood_options_mobile/firebase/`).
    - Check that API parameters match implementation.

## Completion Report

Provide a summary of all documentation updates made, version bump details, GitHub issues synchronized/closed, and any consistency issues found.
