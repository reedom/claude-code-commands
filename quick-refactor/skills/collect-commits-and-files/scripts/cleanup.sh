#!/usr/bin/env bash
# Clean up temp directory created by collect-info.sh
# Only removes the quick-refactor-XXXXXX subdirectory, keeps .tmp and .gitignore

set -uo pipefail

TEMP_DIR="${1:-}"

if [[ -z "$TEMP_DIR" ]]; then
  echo "Usage: cleanup.sh <temp_dir>" >&2
  exit 1
fi

if [[ ! -d "$TEMP_DIR" ]]; then
  echo "Directory not found: $TEMP_DIR" >&2
  exit 1
fi

# Verify it's a quick-refactor temp directory (either in .tmp or system temp)
if [[ ! "$TEMP_DIR" =~ /quick-refactor-[A-Za-z0-9]+$ ]]; then
  echo "Not a quick-refactor temp directory: $TEMP_DIR" >&2
  exit 1
fi

rm -rf "$TEMP_DIR"
echo "Cleaned up: $TEMP_DIR"
