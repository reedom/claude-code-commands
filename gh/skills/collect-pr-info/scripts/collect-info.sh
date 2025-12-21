#!/usr/bin/env bash
# Collect PR-related information for create-draft-pr command
# Outputs JSON with metadata and writes detailed info to temp files

set -uo pipefail

# Defaults
TARGET_BRANCH="origin/main"
DIFF_SPLIT_THRESHOLD=1000  # Split into per-file diffs if total lines exceed this
LANG_OVERRIDE=""

# Detect system language from LANG env var (e.g., "ja_JP.UTF-8" → "ja")
SYSTEM_LANG=$(echo "${LANG:-en_US}" | cut -d'_' -f1)

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  -a, --against <branch>  Target branch for comparison (default: origin/main)
  --lang <code>           Language code for PR content (default: system detected)
  -h, --help              Show this help
EOF
  exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -a|--against)
      TARGET_BRANCH="${2:?--against requires value}"
      shift 2
      ;;
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
EFFECTIVE_LANG="${LANG_OVERRIDE:-$SYSTEM_LANG}"

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

# Extract owner/repo from git remote
REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
if [[ -z "$REMOTE_URL" ]]; then
  error_json "No remote origin configured" "NO_REMOTE"
fi

if [[ $REMOTE_URL =~ github\.com[:/]([^/]+)/([^/.]+) ]]; then
  OWNER="${BASH_REMATCH[1]}"
  REPO="${BASH_REMATCH[2]}"
else
  error_json "Cannot extract owner/repo from remote URL: $REMOTE_URL" "INVALID_REMOTE"
fi

# Get current branch
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
if [[ -z "$CURRENT_BRANCH" ]]; then
  error_json "Not on a branch (detached HEAD)" "DETACHED_HEAD"
fi

# Create temp directory
TEMP_DIR=$(mktemp -d "/tmp/collect-pr-info-XXXXXX")

# Check working tree status
WORKING_TREE_STATUS=$(git status --porcelain 2>/dev/null)
WORKING_TREE_CLEAN="true"
if [[ -n "$WORKING_TREE_STATUS" ]]; then
  WORKING_TREE_CLEAN="false"
fi

# Check if branch has upstream
HAS_UPSTREAM="false"
if git rev-parse --abbrev-ref "@{upstream}" &>/dev/null; then
  HAS_UPSTREAM="true"
fi

# Get changed files
CHANGED_FILES=$(git diff --name-only "$TARGET_BRANCH"...HEAD 2>/dev/null || echo "")
if [[ -z "$CHANGED_FILES" ]]; then
  CHANGED_FILES=$(git diff --name-only "$TARGET_BRANCH"..HEAD 2>/dev/null || echo "")
fi

# Write changed files to temp file
echo "$CHANGED_FILES" > "$TEMP_DIR/changed_files.txt"

# Count changes
NUM_CHANGED_FILES=0
if [[ -n "$CHANGED_FILES" ]]; then
  NUM_CHANGED_FILES=$(echo "$CHANGED_FILES" | wc -l | tr -d ' ')
fi

HAS_CHANGES="false"
if [[ 0 -lt $NUM_CHANGED_FILES ]]; then
  HAS_CHANGES="true"
fi

# Get commit count
COMMIT_COUNT=$(git rev-list --count "$TARGET_BRANCH"..HEAD 2>/dev/null || echo "0")

# Write full commit messages to temp file
git log --format="commit %H%nAuthor: %an <%ae>%nDate: %ad%n%n%B%n---" "$TARGET_BRANCH"..HEAD > "$TEMP_DIR/commits.txt" 2>/dev/null || echo ""

# Write one-line commit log for quick reference
git log --oneline "$TARGET_BRANCH"..HEAD > "$TEMP_DIR/commits_oneline.txt" 2>/dev/null || echo ""

# Extract issue references from commit messages
ISSUE_REFS=$(grep -oE '(fix(es)?|close[sd]?|resolve[sd]?|refs?):?\s*#[0-9]+' "$TEMP_DIR/commits.txt" 2>/dev/null | grep -oE '#[0-9]+' | sort -u | tr '\n' ' ' || echo "")

# Write diff stats to temp file
git diff --stat "$TARGET_BRANCH"...HEAD > "$TEMP_DIR/diff_stat.txt" 2>/dev/null || git diff --stat "$TARGET_BRANCH"..HEAD > "$TEMP_DIR/diff_stat.txt" 2>/dev/null || echo ""

# Get full diff and determine size
FULL_DIFF=$(git diff "$TARGET_BRANCH"...HEAD 2>/dev/null || git diff "$TARGET_BRANCH"..HEAD 2>/dev/null || echo "")
DIFF_LINES=0
if [[ -n "$FULL_DIFF" ]]; then
  DIFF_LINES=$(echo "$FULL_DIFF" | wc -l | tr -d ' ')
fi

# Determine diff structure based on size
DIFF_STRUCTURE="single"
if [[ $DIFF_SPLIT_THRESHOLD -lt $DIFF_LINES ]]; then
  DIFF_STRUCTURE="split"

  # Create diffs directory
  mkdir -p "$TEMP_DIR/diffs"

  # Create manifest
  MANIFEST_ENTRIES="[]"

  # Split diff by file
  while IFS= read -r file; do
    if [[ -n "$file" ]]; then
      # Get diff for this file
      FILE_DIFF=$(git diff "$TARGET_BRANCH"...HEAD -- "$file" 2>/dev/null || git diff "$TARGET_BRANCH"..HEAD -- "$file" 2>/dev/null || echo "")
      FILE_DIFF_LINES=0
      if [[ -n "$FILE_DIFF" ]]; then
        FILE_DIFF_LINES=$(echo "$FILE_DIFF" | wc -l | tr -d ' ')
      fi

      # Determine file type
      FILE_TYPE="source"
      if [[ "$file" =~ _test\.(go|py|js|ts)$ ]] || [[ "$file" =~ \.test\.(js|ts)$ ]] || [[ "$file" =~ ^tests?/ ]]; then
        FILE_TYPE="test"
      elif [[ "$file" =~ \.(md|txt|rst)$ ]] || [[ "$file" =~ ^docs?/ ]]; then
        FILE_TYPE="doc"
      elif [[ "$file" =~ \.(json|ya?ml|toml|ini|cfg)$ ]] || [[ "$file" =~ ^\./ ]]; then
        FILE_TYPE="config"
      elif [[ "$file" =~ ^vendor/ ]] || [[ "$file" =~ ^node_modules/ ]] || [[ "$file" =~ \.lock$ ]]; then
        FILE_TYPE="generated"
      fi

      # Write per-file diff (replace / with __ for filename)
      SAFE_FILENAME=$(echo "$file" | tr '/' '__')
      echo "$FILE_DIFF" > "$TEMP_DIR/diffs/${SAFE_FILENAME}.patch"

      # Add to manifest
      MANIFEST_ENTRIES=$(echo "$MANIFEST_ENTRIES" | jq \
        --arg path "$file" \
        --argjson lines "$FILE_DIFF_LINES" \
        --arg type "$FILE_TYPE" \
        --arg patch_file "diffs/${SAFE_FILENAME}.patch" \
        '. + [{path: $path, lines: $lines, type: $type, patch_file: $patch_file}]')
    fi
  done <<< "$CHANGED_FILES"

  # Write manifest
  jq -n \
    --argjson total_lines "$DIFF_LINES" \
    --argjson files "$MANIFEST_ENTRIES" \
    '{total_lines: $total_lines, files: $files}' > "$TEMP_DIR/manifest.json"
else
  # Write single diff file
  echo "$FULL_DIFF" > "$TEMP_DIR/diff.patch"
fi

# Detect kiro specs
KIRO_SPECS_DIR=".kiro/specs"
MATCHED_SPEC="none"
SPEC_LIST="[]"

if [[ -d "$KIRO_SPECS_DIR" ]]; then
  SPEC_NAMES=$(ls -1 "$KIRO_SPECS_DIR" 2>/dev/null | sort || echo "")

  if [[ -n "$SPEC_NAMES" ]] && [[ -n "$CHANGED_FILES" ]]; then
    MODIFIED_SPECS=""
    for spec in $SPEC_NAMES; do
      if echo "$CHANGED_FILES" | grep -q "/${spec}/"; then
        MODIFIED_SPECS="${MODIFIED_SPECS}${spec}"$'\n'
      fi
    done

    MODIFIED_SPECS=$(echo "$MODIFIED_SPECS" | sort -u | grep -v '^$' || echo "")

    if [[ -n "$MODIFIED_SPECS" ]]; then
      SPEC_COUNT=$(echo "$MODIFIED_SPECS" | wc -l | tr -d ' ')
      if [[ $SPEC_COUNT -eq 1 ]]; then
        MATCHED_SPEC=$(echo "$MODIFIED_SPECS" | head -1)
      else
        MATCHED_SPEC="multiple"
      fi
      SPEC_LIST=$(echo "$MODIFIED_SPECS" | jq -R -s 'split("\n") | map(select(length > 0))')
    fi
  fi
fi

# Check for existing PR
EXISTING_PR=$(gh pr list --head "$CURRENT_BRANCH" --json number,url,state --jq '.[0] // empty' 2>/dev/null || echo "")
EXISTING_PR_NUMBER=""
EXISTING_PR_URL=""
EXISTING_PR_STATE=""
HAS_EXISTING_PR="false"

if [[ -n "$EXISTING_PR" ]]; then
  HAS_EXISTING_PR="true"
  EXISTING_PR_NUMBER=$(echo "$EXISTING_PR" | jq -r '.number')
  EXISTING_PR_URL=$(echo "$EXISTING_PR" | jq -r '.url')
  EXISTING_PR_STATE=$(echo "$EXISTING_PR" | jq -r '.state')
fi

# Check PR chain (preceding PR)
HAS_PRECEDING_PR="false"
PRECEDING_PR_NUMBER=""
PRECEDING_PR_URL=""
PRECEDING_PR_BODY=""
PRECEDING_PR_UPDATED_BODY=""
HAS_ORDER_SECTION="false"

# Extract base branch name (remove origin/ prefix if present)
BASE_BRANCH="${TARGET_BRANCH#origin/}"

# Only check for preceding PR if not targeting main/master
if [[ "$BASE_BRANCH" != "main" ]] && [[ "$BASE_BRANCH" != "master" ]]; then
  # Fetch full preceding PR data for updates
  PRECEDING_PR=$(gh pr list --head "$BASE_BRANCH" --state open \
    --json number,url,title,body,state,labels,headRefName,baseRefName \
    --jq '.[0] // empty' 2>/dev/null || echo "")

  if [[ -n "$PRECEDING_PR" ]]; then
    HAS_PRECEDING_PR="true"
    PRECEDING_PR_NUMBER=$(echo "$PRECEDING_PR" | jq -r '.number')
    PRECEDING_PR_URL=$(echo "$PRECEDING_PR" | jq -r '.url')
    PRECEDING_PR_BODY=$(echo "$PRECEDING_PR" | jq -r '.body // ""')

    # Write full preceding PR data to JSON file (for updating)
    echo "$PRECEDING_PR" > "$TEMP_DIR/preceding_pr.json"

    # Write body separately for easy access
    echo "$PRECEDING_PR_BODY" > "$TEMP_DIR/preceding_pr_body.txt"

    if echo "$PRECEDING_PR_BODY" | grep -qE '^## PR (Order|順序)'; then
      HAS_ORDER_SECTION="true"
    fi

    # Prepare updated_body with PR Order section
    # Use Japanese header if effective language is Japanese
    if [[ "$EFFECTIVE_LANG" == "ja" ]]; then
      PR_ORDER_HEADER="## PR順序"
    else
      PR_ORDER_HEADER="## PR Order"
    fi

    # Build updated body: PR Order section + original body
    PRECEDING_PR_UPDATED_BODY="${PR_ORDER_HEADER}
- this PR
- #NEW

${PRECEDING_PR_BODY}"
  fi
fi

# Build files object based on diff structure
if [[ "$DIFF_STRUCTURE" == "split" ]]; then
  FILES_JSON=$(jq -n \
    --arg temp_dir "$TEMP_DIR" \
    '{
      commits: ($temp_dir + "/commits.txt"),
      commits_oneline: ($temp_dir + "/commits_oneline.txt"),
      changed_files: ($temp_dir + "/changed_files.txt"),
      diff_stat: ($temp_dir + "/diff_stat.txt"),
      manifest: ($temp_dir + "/manifest.json"),
      diffs_dir: ($temp_dir + "/diffs")
    }')
else
  FILES_JSON=$(jq -n \
    --arg temp_dir "$TEMP_DIR" \
    '{
      commits: ($temp_dir + "/commits.txt"),
      commits_oneline: ($temp_dir + "/commits_oneline.txt"),
      changed_files: ($temp_dir + "/changed_files.txt"),
      diff_stat: ($temp_dir + "/diff_stat.txt"),
      diff: ($temp_dir + "/diff.patch")
    }')
fi

# Add preceding PR file if exists
if [[ "$HAS_PRECEDING_PR" == "true" ]]; then
  FILES_JSON=$(echo "$FILES_JSON" | jq \
    --arg temp_dir "$TEMP_DIR" \
    '. + {preceding_pr: ($temp_dir + "/preceding_pr.json")}')
fi

# Build JSON output
jq -n \
  --arg temp_dir "$TEMP_DIR" \
  --argjson files "$FILES_JSON" \
  --arg system_lang "$SYSTEM_LANG" \
  --arg lang "$EFFECTIVE_LANG" \
  --arg diff_structure "$DIFF_STRUCTURE" \
  --argjson diff_lines "$DIFF_LINES" \
  --arg owner "$OWNER" \
  --arg repo "$REPO" \
  --arg current_branch "$CURRENT_BRANCH" \
  --arg target_branch "$TARGET_BRANCH" \
  --argjson working_tree_clean "$WORKING_TREE_CLEAN" \
  --argjson has_upstream "$HAS_UPSTREAM" \
  --argjson has_changes "$HAS_CHANGES" \
  --argjson num_changed_files "$NUM_CHANGED_FILES" \
  --argjson commit_count "$COMMIT_COUNT" \
  --arg issue_refs "$ISSUE_REFS" \
  --arg matched_spec "$MATCHED_SPEC" \
  --argjson spec_list "$SPEC_LIST" \
  --argjson has_existing_pr "$HAS_EXISTING_PR" \
  --arg existing_pr_number "$EXISTING_PR_NUMBER" \
  --arg existing_pr_url "$EXISTING_PR_URL" \
  --arg existing_pr_state "$EXISTING_PR_STATE" \
  --argjson has_preceding_pr "$HAS_PRECEDING_PR" \
  --arg preceding_pr_number "$PRECEDING_PR_NUMBER" \
  --arg preceding_pr_url "$PRECEDING_PR_URL" \
  --arg preceding_pr_body "$PRECEDING_PR_BODY" \
  --arg preceding_pr_updated_body "$PRECEDING_PR_UPDATED_BODY" \
  --argjson has_order_section "$HAS_ORDER_SECTION" \
  '{
    temp_dir: $temp_dir,
    files: $files,
    lang: {
      system: $system_lang,
      effective: $lang
    },
    diff_info: {
      structure: $diff_structure,
      total_lines: $diff_lines
    },
    repository: {
      owner: $owner,
      repo: $repo
    },
    git: {
      current_branch: $current_branch,
      target_branch: $target_branch,
      working_tree_clean: $working_tree_clean,
      has_upstream: $has_upstream,
      has_changes: $has_changes,
      num_changed_files: $num_changed_files,
      commit_count: $commit_count,
      issue_refs: ($issue_refs | split(" ") | map(select(length > 0)))
    },
    kiro: {
      matched_spec: $matched_spec,
      spec_list: $spec_list
    },
    existing_pr: {
      exists: $has_existing_pr,
      number: (if $existing_pr_number == "" then null else ($existing_pr_number | tonumber) end),
      url: (if $existing_pr_url == "" then null else $existing_pr_url end),
      state: (if $existing_pr_state == "" then null else $existing_pr_state end)
    },
    pr_chain: {
      has_preceding_pr: $has_preceding_pr,
      preceding_pr_number: (if $preceding_pr_number == "" then null else ($preceding_pr_number | tonumber) end),
      preceding_pr_url: (if $preceding_pr_url == "" then null else $preceding_pr_url end),
      preceding_pr_body: (if $preceding_pr_body == "" then null else $preceding_pr_body end),
      updated_body: (if $preceding_pr_updated_body == "" then null else $preceding_pr_updated_body end),
      has_order_section: $has_order_section
    }
  }'
