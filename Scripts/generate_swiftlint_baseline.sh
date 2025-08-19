#!/usr/bin/env bash
set -euo pipefail

echo "➡️  Generating SwiftLint baseline (snapshot of current violations)"

if ! command -v swiftlint >/dev/null 2>&1; then
  echo "swiftlint not installed. brew install swiftlint" >&2
  exit 1
fi

BASELINE_FILE=".swiftlint-baseline.yml"

# We create a synthetic baseline by capturing rule:file:line signature set.
TMP_LOG=$(mktemp)
swiftlint --quiet > "$TMP_LOG" 2>&1 || true

echo "# SwiftLint Baseline (auto-generated)" > "$BASELINE_FILE"
echo "# Delete and regenerate after reducing violations." >> "$BASELINE_FILE"
echo "violations:" >> "$BASELINE_FILE"

grep -E ': warning:|: error:' "$TMP_LOG" | \
  sed -E 's#^(.*/)?([^/:]+:[0-9]+:[0-9]+): (warning|error): ([^(]+) \(([^)]+)\).*#- file: \2\n  message: "\4"\n  rule: \5#' \
  >> "$BASELINE_FILE" || true

echo "Baseline stored at $BASELINE_FILE (entries: $(grep -c '^-' "$BASELINE_FILE" || echo 0))"
rm -f "$TMP_LOG"

echo "NOTE: The pre-commit hook only blocks new critical (force_*/fatal) violations; use this baseline as reference for gradual cleanup."
