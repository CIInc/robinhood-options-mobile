#!/usr/bin/env bash
# Disabled: Per-tool auto-formatting hooks caused 6-8s latency per edit.
# Formatting is authoritatively handled during skill verification steps
# ('dart format .' in src/robinhood_options_mobile) and CI/CD pipelines.

# Consume any stdin without hanging
if [ ! -t 0 ]; then
  cat > /dev/null
fi

echo "{}"
