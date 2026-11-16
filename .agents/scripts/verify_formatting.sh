#!/usr/bin/env bash
# Consume stdin payload
cat > /dev/null

# Move to workspace root (parent of .agents)
WORKSPACE_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$WORKSPACE_DIR" || exit 0

# Check formatting if dart is executable
if dart --version > /dev/null 2>&1; then
  if ! dart format --output=none --set-exit-if-changed . > /dev/null 2>&1; then
    echo '{"decision": "continue", "reason": "Dart formatting verification failed. Unformatted Dart code detected. Please run `dart format .` before finishing."}'
    exit 0
  fi
fi

# Check static analysis if flutter is executable
if flutter --version > /dev/null 2>&1; then
  cd "$WORKSPACE_DIR/src/robinhood_options_mobile" || exit 0
  if ! flutter analyze --no-fatal-infos > /dev/null 2>&1; then
    echo '{"decision": "continue", "reason": "Flutter analyze check failed with errors. Please run `flutter analyze` in src/robinhood_options_mobile and fix issues before finishing."}'
    exit 0
  fi
fi

echo "{}"
