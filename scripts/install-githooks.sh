#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")"/.. && pwd)"
HOOKS_DIR="$ROOT_DIR/.githooks"
mkdir -p "$HOOKS_DIR"

cat > "$HOOKS_DIR/pre-commit" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# SwiftFormat (if installed)
if command -v swiftformat >/dev/null 2>&1; then
  echo "Running swiftformat..."
  swiftformat Sources --quiet || true
fi

# SwiftLint (if installed)
if command -v swiftlint >/dev/null 2>&1; then
  echo "Running swiftlint..."
  swiftlint --quiet || true
fi
EOF

chmod +x "$HOOKS_DIR/pre-commit"

git config core.hooksPath "$HOOKS_DIR"
echo "Git hooks installed (pre-commit for SwiftFormat/SwiftLint)."

