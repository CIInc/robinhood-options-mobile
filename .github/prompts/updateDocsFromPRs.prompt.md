---
name: updateDocsFromPRs
description: Update markdown documentation based on recently closed or merged pull requests
argument-hint: PR numbers or "latest" to use most recent closed PRs
---

Update all markdown documentation based on recently closed or merged pull requests.

## Process:

1. **Fetch PR Information**: Retrieve details from the specified pull requests including:
   - PR title and description
   - File changes and patches
   - Merge date and author

2. **Identify Documentation Files**: Locate all markdown files in the repository:
   - CHANGELOG.md
   - README.md
   - Documentation files (docs/ directory)
   - Developer instruction files (.github/ directory)
   - Any other .md files

3. **Update CHANGELOG.md**:
   - Add a new version section with the current date
   - Document all features added, changed, fixed, removed, and performance improvements
   - Use clear, descriptive bullet points
   - Group related changes together

4. **Update Feature Documentation**:
   - Add or update sections describing new features
   - Document new configuration options or settings
   - Include code examples where applicable
   - Update technical details sections

5. **Update Main README.md**:
   - Add mentions of new major features to the features list
   - Ensure feature descriptions are concise but complete

6. **Update Developer Instructions**:
   - Add references to new providers, services, or components
   - Update architecture notes with new patterns
   - Add file references for new modules
   - Update examples section

7. **Cross-Check Consistency**:
   - Verify version numbers are consistent
   - Ensure feature descriptions match across all files
   - Confirm code references are accurate
   - Validate internal links between documentation files
   - Check that configuration files match documentation

8. **Verify Technical Accuracy**:
   - Ensure any mentioned indexes, configurations, or deployment steps are accurate
   - Verify file paths and code references exist
   - Check that API parameters match implementation

Provide a summary of all documentation updates made and any consistency issues found.
