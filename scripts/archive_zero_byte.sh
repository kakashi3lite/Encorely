#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ARCHIVE_DIR="$ROOT_DIR/archive/zero-byte-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$ARCHIVE_DIR"

echo "Scanning for zero-byte .swift files under $ROOT_DIR ..."
mapfile -t files < <(find "$ROOT_DIR" -type f -name "*.swift" -size 0)
count=${#files[@]}

echo "Found $count zero-byte Swift files"
if [[ $count -eq 0 ]]; then
  exit 0
fi

echo "Archiving to $ARCHIVE_DIR"
for f in "${files[@]}"; do
  rel="${f#$ROOT_DIR/}"
  dst_dir="$ARCHIVE_DIR/$(dirname "$rel")"
  mkdir -p "$dst_dir"
  mv "$f" "$dst_dir/"
  echo "  moved: $rel"
done

echo "Done. Review and commit removals if desired."
