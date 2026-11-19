#!/usr/bin/env bash
# Disabled: Stop hooks caused 10-15s per-turn latency and false positive blockages.
# Analysis and formatting verification are authoritatively handled during skill verification steps
# ('dart analyze' and 'dart format --set-exit-if-changed .') and CI/CD pipelines.

# Consume any stdin without hanging
if [ ! -t 0 ]; then
  cat > /dev/null
fi

echo "{}"
