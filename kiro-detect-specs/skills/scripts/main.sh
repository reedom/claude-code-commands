#!/usr/bin/env bash

set -euo pipefail

# Parse arguments
BRANCH=""
while [[ $# -gt 0 ]]; do
  case $1 in
    -b|--branch)
      BRANCH="$2"
      shift 2
      ;;
    *)
      >&2 echo "Unknown option: $1"
      >&2 echo "Usage: $0 [-b|--branch <branch>]"
      exit 1
      ;;
  esac
done

# Get default branch if not specified
if [ -z "$BRANCH" ]; then
  BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "")
  if [ -z "$BRANCH" ]; then
    BRANCH=$(git remote show origin 2>/dev/null | grep 'HEAD branch' | awk '{print $NF}' || echo "main")
  fi
fi

>&2 echo "[modified-kiro-specs] Comparing against branch: $BRANCH"

# Check if .kiro/specs exists
if [ ! -d ".kiro/specs" ]; then
  >&2 echo "[modified-kiro-specs] No .kiro/specs directory found"
  exit 0
fi

# Get all spec names
SPEC_NAMES=$(ls -1 .kiro/specs 2>/dev/null || echo "")
if [ -z "$SPEC_NAMES" ]; then
  >&2 echo "[modified-kiro-specs] No specs found in .kiro/specs"
  exit 0
fi

# Get modified files
MODIFIED_FILES=$(git diff --name-only "$BRANCH"...HEAD 2>/dev/null || git diff --name-only HEAD 2>/dev/null || echo "")
if [ -z "$MODIFIED_FILES" ]; then
  >&2 echo "[modified-kiro-specs] No modified files found"
  exit 0
fi

>&2 echo "[modified-kiro-specs] Found $(echo "$MODIFIED_FILES" | wc -l | tr -d ' ') modified files"

# Filter specs that have modified files
MODIFIED_SPECS=""
for spec in $SPEC_NAMES; do
  if echo "$MODIFIED_FILES" | grep -q "/${spec}/"; then
    MODIFIED_SPECS="${MODIFIED_SPECS}${spec}"$'\n'
  fi
done

# Output distinct sorted list
if [ -n "$MODIFIED_SPECS" ]; then
  echo "$MODIFIED_SPECS" | sort -u | grep -v '^$'
else
  >&2 echo "[modified-kiro-specs] No specs matched modified files"
fi