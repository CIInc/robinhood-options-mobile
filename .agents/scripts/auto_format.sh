#!/usr/bin/env bash
# Consume stdin payload
cat > /dev/null

# Move to workspace root (parent of .agents)
WORKSPACE_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$WORKSPACE_DIR" || exit 0

# Run dart format if executable
if dart --version > /dev/null 2>&1; then
  dart format . > /dev/null 2>&1
fi

# PostToolUse requires empty JSON on stdout
echo "{}"
