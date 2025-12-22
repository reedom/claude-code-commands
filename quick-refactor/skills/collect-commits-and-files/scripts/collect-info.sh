#!/usr/bin/env bash
# Collect changed files for review: git diff against target branch + explicit files
# Outputs JSON manifest with file paths categorized by type

set -uo pipefail

# Defaults
AGAINST_BRANCH="origin/main"
EXPLICIT_FILES=""

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --against <branch>    Target branch for diff (default: origin/main)
  --files <paths>       Comma-separated file paths to include
  -h, --help            Show this help
EOF
  exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --against)
      AGAINST_BRANCH="${2:?--against requires value}"
      shift 2
      ;;
    --files)
      EXPLICIT_FILES="${2:?--files requires value}"
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

# Check if target branch exists
if ! git rev-parse --verify "$AGAINST_BRANCH" &>/dev/null; then
  error_json "Branch not found: $AGAINST_BRANCH" "BRANCH_NOT_FOUND"
fi

# Create temp directory: prefer git-root/.tmp, fallback to system temp
TMP_BASE=""
if [[ -n "$REPO_ROOT" ]]; then
  TMP_BASE="$REPO_ROOT/.tmp"
  mkdir -p "$TMP_BASE"
  # Ensure .gitignore exists with * to ignore all temp files (idempotent)
  if [[ ! -f "$TMP_BASE/.gitignore" ]]; then
    echo "*" > "$TMP_BASE/.gitignore"
  fi
else
  TMP_BASE="${TMPDIR:-/tmp}"
fi

TEMP_DIR=$(mktemp -d "$TMP_BASE/quick-refactor-XXXXXX")
mkdir -p "$TEMP_DIR/diff" "$TEMP_DIR/files" "$TEMP_DIR/reviews"

# Collect changed files from git diff
DIFF_FILES=$(git diff --name-only "$AGAINST_BRANCH"...HEAD 2>/dev/null || echo "")

# Merge with explicit files (remove duplicates)
ALL_FILES="$DIFF_FILES"
if [[ -n "$EXPLICIT_FILES" ]]; then
  # Convert comma-separated to newline-separated and merge
  EXPLICIT_NEWLINE=$(echo "$EXPLICIT_FILES" | tr ',' '\n')
  ALL_FILES=$(printf "%s\n%s" "$DIFF_FILES" "$EXPLICIT_NEWLINE" | sort -u | grep -v '^$')
fi

if [[ -z "$ALL_FILES" ]]; then
  error_json "No files to review" "NO_FILES"
fi

# Function to categorize a file
categorize_file() {
  local file="$1"

  # Config files
  if [[ "$file" =~ \.(ya?ml|toml|ini|cfg)$ ]] || \
     [[ "$file" =~ ^\..*rc$ ]] || \
     [[ "$file" =~ (tsconfig|\.eslintrc|\.prettierrc|jest\.config) ]] || \
     [[ "$file" =~ ^\.github/ ]]; then
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

# Detect project rules paths
PROJECT_RULES="[]"
if [[ -f "$REPO_ROOT/CLAUDE.md" ]]; then
  PROJECT_RULES=$(echo "$PROJECT_RULES" | jq --arg path "$REPO_ROOT/CLAUDE.md" '. + [$path]')
fi
if [[ -d "$REPO_ROOT/.kiro" ]]; then
  # Add all .md files in .kiro directory
  while IFS= read -r kiro_file; do
    PROJECT_RULES=$(echo "$PROJECT_RULES" | jq --arg path "$kiro_file" '. + [$path]')
  done < <(find "$REPO_ROOT/.kiro" -name "*.md" -type f 2>/dev/null)
fi

# Process files and categorize
SOURCE_FILES=""
TEST_FILES=""
CONFIG_FILES=""
DOCS_FILES=""
FILE_COUNT=0

while IFS= read -r file; do
  [[ -z "$file" ]] && continue

  # Skip if file doesn't exist (deleted files)
  if [[ ! -f "$REPO_ROOT/$file" ]]; then
    continue
  fi

  FILE_COUNT=$((FILE_COUNT + 1))
  CATEGORY=$(categorize_file "$file")

  case "$CATEGORY" in
    source) SOURCE_FILES+="$file"$'\n' ;;
    test) TEST_FILES+="$file"$'\n' ;;
    config) CONFIG_FILES+="$file"$'\n' ;;
    docs) DOCS_FILES+="$file"$'\n' ;;
  esac

  # Save individual diff for each file
  FILE_HASH=$(echo "$file" | md5sum | cut -d' ' -f1)
  git diff "$AGAINST_BRANCH"...HEAD -- "$file" > "$TEMP_DIR/diff/${FILE_HASH}.diff" 2>/dev/null || true
done <<< "$ALL_FILES"

if [[ $FILE_COUNT -eq 0 ]]; then
  rm -rf "$TEMP_DIR"
  error_json "No existing files to review (all files may be deleted)" "NO_EXISTING_FILES"
fi

# Helper to convert newline-separated list to JSON array
to_json_array() {
  local input="$1"
  if [[ -z "$input" ]]; then
    echo "[]"
  else
    echo -n "$input" | grep -v '^$' | jq -R -s 'split("\n") | map(select(length > 0))'
  fi
}

# Write categorized file lists as JSON arrays
to_json_array "$SOURCE_FILES" > "$TEMP_DIR/files/source.json"
to_json_array "$TEST_FILES" > "$TEMP_DIR/files/test.json"
to_json_array "$CONFIG_FILES" > "$TEMP_DIR/files/config.json"
to_json_array "$DOCS_FILES" > "$TEMP_DIR/files/docs.json"

# Count files by category (handle empty strings properly)
if [[ -n "$SOURCE_FILES" ]]; then
  SOURCE_COUNT=$(echo -n "$SOURCE_FILES" | grep -c '^' 2>/dev/null || echo 0)
else
  SOURCE_COUNT=0
fi
if [[ -n "$TEST_FILES" ]]; then
  TEST_COUNT=$(echo -n "$TEST_FILES" | grep -c '^' 2>/dev/null || echo 0)
else
  TEST_COUNT=0
fi
if [[ -n "$CONFIG_FILES" ]]; then
  CONFIG_COUNT=$(echo -n "$CONFIG_FILES" | grep -c '^' 2>/dev/null || echo 0)
else
  CONFIG_COUNT=0
fi
if [[ -n "$DOCS_FILES" ]]; then
  DOCS_COUNT=$(echo -n "$DOCS_FILES" | grep -c '^' 2>/dev/null || echo 0)
else
  DOCS_COUNT=0
fi

# Build manifest JSON
jq -n \
  --arg temp_dir "$TEMP_DIR" \
  --arg repo_root "$REPO_ROOT" \
  --arg against_branch "$AGAINST_BRANCH" \
  --argjson file_count "$FILE_COUNT" \
  --argjson source_count "$SOURCE_COUNT" \
  --argjson test_count "$TEST_COUNT" \
  --argjson config_count "$CONFIG_COUNT" \
  --argjson docs_count "$DOCS_COUNT" \
  --argjson project_rules "$PROJECT_RULES" \
  '{
    temp_dir: $temp_dir,
    repo_root: $repo_root,
    against_branch: $against_branch,
    paths: {
      diff_dir: ($temp_dir + "/diff"),
      files_dir: ($temp_dir + "/files"),
      reviews_dir: ($temp_dir + "/reviews")
    },
    summary: {
      total_files: $file_count,
      source: $source_count,
      test: $test_count,
      config: $config_count,
      docs: $docs_count
    },
    project_rules: $project_rules
  }'
