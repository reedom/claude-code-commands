#!/usr/bin/env bash
# Clean up temp directory created by collect-info.sh

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

# Verify it's a collect-commit-info temp directory
if [[ ! "$TEMP_DIR" =~ ^/tmp/collect-commit-info- ]]; then
  echo "Not a collect-commit-info temp directory: $TEMP_DIR" >&2
  exit 1
fi

rm -rf "$TEMP_DIR"
echo "Cleaned up: $TEMP_DIR"
