#!/usr/bin/env bash
# Consume stdin payload
cat > /dev/null

# Move to workspace root (parent of .agents)
WORKSPACE_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$WORKSPACE_DIR" || exit 0

# Run dart format
dart format . > /dev/null 2>&1

# PostToolUse requires empty JSON on stdout
echo "{}"
