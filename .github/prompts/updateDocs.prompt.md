---
name: updateDocs
description: Update markdown documentation based on recently closed or merged pull requests, or the latest commits if none specified.
argument-hint: PR numbers or "latest" to use most recent closed PRs, or the new version number.
---

Update all markdown documentation based on recently closed or merged pull requests. If a version number is specified, use the recent commits since the previous version.

## Process:

1. **Fetch PR or Commit Information**: Retrieve details from the specified pull requests or commits including:
   - PR title and description
   - File changes and patches
   - Merge date and author

2. **Identify Documentation Files**: Locate all markdown files in the repository:
   - CHANGELOG.md
   - README.md
   - ROADMAP.md
   - Documentation files (docs/ directory)
   - Developer instruction files (.github/ directory)
   - Any other .md files

3. **Update pubspec.yaml**:
   - Check the current version number compared the argument provided (if any)
   - If different, increment a new version in pubspec.yaml based on semantic versioning rules:
     - Major version for breaking changes
     - Minor version for new features
     - Patch version for bug fixes
   - Ensure the build number is incremented appropriately only if the version number changes

4. **Update CHANGELOG.md**:
   - Add a new version section with the current date (using the version defined in pubspec.yaml)
   - Create a title for the new version
   - Document all features added, changed, fixed, removed, and performance improvements
   - Use clear, descriptive bullet points
   - Group related changes together

5. **Update docs markdown files**:
   - Add or update sections describing new features
   - Document new configuration options or settings
   - Include code examples where applicable
   - Update technical details sections
   - Add diagrams or screenshots if relevant
   - Add future enhancements or TODOs if applicable

6. **Update Main README.md**:
   - Add mentions of new major features to the features list
   - Ensure feature descriptions are concise but complete

7. **Update ROADMAP.md**:
   - Mark completed features as done (check off items)
   - Add new planned features based on PR discussions or future enhancements mentioned
   - Add entry in "Release Versions & Timeline" for the new version
   - Reorder priorities if necessary

8. **Update Developer Instructions**:
   - Add references to new providers, services, or components
   - Update architecture notes with new patterns
   - Add file references for new modules
   - Update examples section

9. **Cross-Check Consistency**:
   - Verify version numbers are consistent
   - Ensure feature descriptions match across all files
   - Confirm code references are accurate
   - Validate internal links between documentation files
   - Check that configuration files match documentation

10. **Verify Technical Accuracy**:
   - Ensure any mentioned indexes, configurations, or deployment steps are accurate
   - Verify file paths and code references exist
   - Check that API parameters match implementation

11. **Tag release**:
   - Create a new git tag for the updated version
   - Push changes and tags to the repository

Provide a summary of all documentation updates made and any consistency issues found.
