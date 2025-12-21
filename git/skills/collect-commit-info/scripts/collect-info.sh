#!/usr/bin/env bash
# Collect information about STAGED files for commit
# Outputs JSON with file stats and categories (no grouping - skill handles that)

set -uo pipefail

# Defaults
LANG_OVERRIDE=""

# Detect system language from LANG env var (e.g., "ja_JP.UTF-8" -> "ja")
SYSTEM_LANG=$(echo "${LANG:-en_US}" | cut -d'_' -f1)

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --lang <code>     Language for commit messages (default: system detected)
  -h, --help        Show this help
EOF
  exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --lang)
      LANG_OVERRIDE="${2:?--lang requires value}"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Error: Unknown option $1" >&2
      usage
      ;;
  esac
done

# Determine effective language
if [[ "$LANG_OVERRIDE" == "system" ]] || [[ -z "$LANG_OVERRIDE" ]]; then
  EFFECTIVE_LANG="$SYSTEM_LANG"
else
  EFFECTIVE_LANG="$LANG_OVERRIDE"
fi

# Helper to output error JSON and exit
error_json() {
  jq -n \
    --arg error "$1" \
    --arg code "$2" \
    '{error: $error, error_code: $code}'
  exit 0
}

# Check if in git repo
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  error_json "Not inside a git repository" "NOT_GIT_REPO"
fi

# Get repo root
REPO_ROOT=$(git rev-parse --show-toplevel)

# Get staged files only
STAGED_FILES=$(git diff --name-only --cached 2>/dev/null || echo "")

if [[ -z "$STAGED_FILES" ]]; then
  error_json "No staged files to commit" "NO_STAGED_FILES"
fi

# Create temp directory
TEMP_DIR=$(mktemp -d "/tmp/collect-commit-info-XXXXXX")

# Save staged file list
echo "$STAGED_FILES" > "$TEMP_DIR/staged_files.txt"

# Save full diff content
git diff --cached > "$TEMP_DIR/diff_content.txt"

# Function to categorize a file
categorize_file() {
  local file="$1"

  # Dependencies
  if [[ "$file" =~ (package\.json|package-lock\.json|pnpm-lock\.yaml|yarn\.lock|requirements\.txt|Pipfile|Pipfile\.lock|Cargo\.toml|Cargo\.lock|go\.mod|go\.sum|Gemfile|Gemfile\.lock)$ ]]; then
    echo "deps"
    return
  fi

  # CI
  if [[ "$file" =~ ^\.github/ ]]; then
    echo "ci"
    return
  fi

  # Config
  if [[ "$file" =~ \.(ya?ml|toml|ini|cfg)$ ]] || [[ "$file" =~ ^\..*rc$ ]] || [[ "$file" =~ (tsconfig|\.eslintrc|\.prettierrc|jest\.config) ]]; then
    echo "config"
    return
  fi

  # Tests
  if [[ "$file" =~ _test\.(go|py|js|ts|jsx|tsx)$ ]] || \
     [[ "$file" =~ \.test\.(js|ts|jsx|tsx)$ ]] || \
     [[ "$file" =~ \.spec\.(js|ts|jsx|tsx)$ ]] || \
     [[ "$file" =~ ^tests?/ ]] || \
     [[ "$file" =~ __tests__/ ]]; then
    echo "test"
    return
  fi

  # Documentation
  if [[ "$file" =~ \.(md|txt|rst|adoc)$ ]] || [[ "$file" =~ ^docs?/ ]]; then
    echo "docs"
    return
  fi

  # Source code (default)
  echo "source"
}

# Collect file stats and categories
TOTAL_ADDITIONS=0
TOTAL_DELETIONS=0
STAGED_COUNT=0

# Build categories JSON
CATEGORIES_JSON="[]"

while IFS= read -r file; do
  [[ -z "$file" ]] && continue
  STAGED_COUNT=$((STAGED_COUNT + 1))

  # Get diff stats for this file
  STATS=$(git diff --cached --numstat -- "$file" 2>/dev/null | head -1 || echo "0	0	$file")
  ADDITIONS=$(echo "$STATS" | cut -f1)
  DELETIONS=$(echo "$STATS" | cut -f2)
  [[ "$ADDITIONS" == "-" ]] && ADDITIONS=0
  [[ "$DELETIONS" == "-" ]] && DELETIONS=0

  TOTAL_ADDITIONS=$((TOTAL_ADDITIONS + ADDITIONS))
  TOTAL_DELETIONS=$((TOTAL_DELETIONS + DELETIONS))

  # Categorize
  CATEGORY=$(categorize_file "$file")

  # Save to file stats
  echo -e "${ADDITIONS}\t${DELETIONS}\t${file}\t${CATEGORY}" >> "$TEMP_DIR/file_stats.txt"

  # Add to categories JSON
  CATEGORIES_JSON=$(echo "$CATEGORIES_JSON" | jq \
    --arg file "$file" \
    --arg category "$CATEGORY" \
    --argjson additions "$ADDITIONS" \
    --argjson deletions "$DELETIONS" \
    '. + [{
      file: $file,
      category: $category,
      additions: $additions,
      deletions: $deletions
    }]')
done <<< "$STAGED_FILES"

# Build final JSON output
jq -n \
  --arg temp_dir "$TEMP_DIR" \
  --arg repo_root "$REPO_ROOT" \
  --arg system_lang "$SYSTEM_LANG" \
  --arg effective_lang "$EFFECTIVE_LANG" \
  --arg staged_list "$TEMP_DIR/staged_files.txt" \
  --arg diff_content "$TEMP_DIR/diff_content.txt" \
  --arg file_stats "$TEMP_DIR/file_stats.txt" \
  --argjson staged_count "$STAGED_COUNT" \
  --argjson total_additions "$TOTAL_ADDITIONS" \
  --argjson total_deletions "$TOTAL_DELETIONS" \
  --argjson files "$CATEGORIES_JSON" \
  '{
    temp_dir: $temp_dir,
    repo_root: $repo_root,
    lang: {
      system: $system_lang,
      effective: $effective_lang
    },
    paths: {
      staged_list: $staged_list,
      diff_content: $diff_content,
      file_stats: $file_stats
    },
    summary: {
      staged_count: $staged_count,
      total_additions: $total_additions,
      total_deletions: $total_deletions
    },
    files: $files
  }'
