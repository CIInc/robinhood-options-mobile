---
name: updateDocs
description: Update markdown documentation based on recent changes.
argument-hint: Provide a version number to base the updates on recent commits since the previous version (e.g., 0.31.6).
---

Update all markdown documentation based on recent commits since the previous version.

## Process:

1. **Fetch Commit Information**: Retrieve details from the commits including:
   - Commit message and description
   - File changes and patches
   - Commit date and author

2. **Identify Documentation Files**: Locate all markdown files in the repository:
   - CHANGELOG.md
   - README.md
   - ROADMAP.md
   - Documentation files (docs/ directory)
   - Developer instruction files (.github/ directory, especially .github/copilot-instructions.md)
   - Any other .md files

3. **Update pubspec.yaml**:
   - Check the current version number in src/robinhood_options_mobile/pubspec.yaml and compare it to the argument provided (if any)
   - If different, update the version in pubspec.yaml based on semantic versioning rules:
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
   - Update .github/copilot-instructions.md with new patterns, file references, or architecture notes
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
   - Verify file paths and code references exist (check src/robinhood_options_mobile/, src/robinhood_options_mobile/functions/, and src/robinhood_options_mobile/firebase/)
   - Check that API parameters match implementation

Provide a summary of all documentation updates made and any consistency issues found.
