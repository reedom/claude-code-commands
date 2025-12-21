---
name: reedom-git:collect-commit-info
description: Collect staged files, group them, generate commit messages, and return commit specs.
allowed-tools: Read, Bash(${CLAUDE_PLUGIN_ROOT}/skills/collect-commit-info/scripts/collect-info.sh:*), Bash(${CLAUDE_PLUGIN_ROOT}/skills/collect-commit-info/scripts/cleanup.sh:*)
---

Heavy lifter skill: collect staged file info, group files, generate commit messages, cleanup, return specs.
NEVER invoke `/reedom-git:smart-commit`.

## Arguments

| Arg | Default | Description |
|-----|---------|-------------|
| `--lang` | system | Language for commit messages |

## Workflow

### 1. Collect Staged File Info

Run:
```bash
${CLAUDE_PLUGIN_ROOT}/skills/collect-commit-info/scripts/collect-info.sh --lang <code>
```

Returns JSON:
```json
{
  "temp_dir": "/tmp/collect-commit-info-XXXXXX",
  "repo_root": "/path/to/repo",
  "lang": {"system": "en", "effective": "ja"},
  "paths": {
    "staged_list": "<temp_dir>/staged_files.txt",
    "diff_content": "<temp_dir>/diff_content.txt",
    "file_stats": "<temp_dir>/file_stats.txt"
  },
  "summary": {
    "staged_count": 5,
    "total_additions": 120,
    "total_deletions": 30
  },
  "files": [
    {"file": "package.json", "category": "deps", "additions": 10, "deletions": 2},
    {"file": "src/auth/login.ts", "category": "source", "additions": 80, "deletions": 15}
  ]
}
```

### 2. Handle Errors

If script returns error, report to caller and exit:
```json
{"error": "No staged files to commit", "error_code": "NO_STAGED_FILES"}
```

### 3. Read Diff Content

Read `diff_content` file to understand what changed for message generation.

### 4. Group Files by Category

Group files from the `files` array by category. Commit order:
1. `deps` - Dependencies
2. `ci` - CI/CD
3. `config` - Configuration
4. `source` - Source code
5. `test` - Tests
6. `docs` - Documentation

### 5. Generate Commit Message Per Group

For each group, analyze the diff content and generate a conventional commit message:

**Format:**
```
type(scope): imperative subject under 50 chars

Optional body explaining what and why.
```

**Type mapping:**
| Category | Type |
|----------|------|
| deps | chore |
| ci | ci |
| config | chore |
| source | feat/fix/refactor (analyze diff) |
| test | test |
| docs | docs |

**For source files, determine type by analyzing diff:**
- New files with new functionality → `feat`
- Bug fixes (fix patterns, error handling) → `fix`
- Code restructuring without behavior change → `refactor`
- Mostly deletions/cleanup → `refactor`

**Scope:** Derive from file paths (e.g., `src/auth/*` → `auth`)

**Language:** Use `lang.effective` for message language.

### 6. Cleanup Temp Directory

Run:
```bash
${CLAUDE_PLUGIN_ROOT}/skills/collect-commit-info/scripts/cleanup.sh <temp_dir>
```

### 7. Return Commit Specs

Return JSON array of commit specs:

```json
{
  "commits": [
    {
      "message": "chore(deps): update dependencies\n\nBump package versions for security patches.",
      "files": ["package.json", "pnpm-lock.yaml"]
    },
    {
      "message": "feat(auth): add OAuth2 login support\n\nImplement OAuth2 flow with Google provider.",
      "files": ["src/auth/login.ts", "src/auth/oauth.ts"]
    }
  ],
  "summary": {
    "total_commits": 2,
    "total_files": 4
  }
}
```

## Single Commit Case

If all files belong to one category (or splitting not needed), return single commit:

```json
{
  "commits": [
    {
      "message": "feat(auth): implement user authentication",
      "files": ["src/auth/login.ts", "src/auth/session.ts"]
    }
  ],
  "summary": {
    "total_commits": 1,
    "total_files": 2
  }
}
```

## Error Response

If error occurs, return:

```json
{
  "error": "Error description",
  "error_code": "ERROR_CODE"
}
```
