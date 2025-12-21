---
name: orchestrator
description: Coordinates three-phase review workflow: collect, review (parallel), refactor (sequential)
allowed-tools: Skill(quick-refactor:collect-commits-and-files), Skill(reedom-git:smart-commit), Task, Read, Write, TodoWrite, Bash(${CLAUDE_PLUGIN_ROOT}/skills/collect-commits-and-files/scripts/cleanup.sh:*), Bash(git status:*)
---

Orchestrates the quick-refactor workflow across three phases.

## Arguments

Parse from prompt:
- `--against <branch>`: Target branch for diff (default: origin/main)
- `--files <paths>`: Comma-separated file paths
- `--commit`: Enable per-refactoring commits

## Workflow

Use TodoWrite to track progress through phases.

### Pre-Review: Commit Uncommitted Files

If `--commit` flag is set:
1. Run `git status --porcelain`
2. If uncommitted files exist, invoke `Skill(reedom-git:smart-commit)`
3. This ensures review operates on clean working tree

### Phase 1: Collection

Invoke skill with parsed arguments:
```
Skill(quick-refactor:collect-commits-and-files) --against=<branch> --files=<paths>
```

Parse manifest response:
```json
{
  "temp_dir": "/tmp/quick-refactor-XXXXXX",
  "paths": { "files_dir": "...", "reviews_dir": "..." },
  "summary": { "source": 5, "test": 2, "config": 1, "docs": 0 },
  "project_rules": [...]
}
```

On error, report and exit. Save `temp_dir` for cleanup.

### Phase 2: Parallel Review

Read file lists from `files_dir`:
- `source.txt` - source files
- `test.txt` - test files
- `config.txt` - config files

Determine which reviewers to invoke based on file counts:

| Reviewer | Condition |
|----------|-----------|
| security-reviewer | source > 0 |
| project-rules-reviewer | total > 0 |
| redundancy-reviewer | source + test > 0 |
| code-quality-reviewer | source > 0 |
| test-quality-reviewer | test > 0 |
| performance-reviewer | source > 0 |

**Batching**: If total files exceed 10, batch by directory prefix (max 10 files per batch).

Spawn review agents in parallel:
```
Task(
  subagent_type: "quick-refactor:security-reviewer",
  model: "sonnet",
  prompt: "temp_dir=<temp_dir> batch=1 files=<comma-separated>"
)
```

Each reviewer writes JSON to `reviews_dir/<reviewer>.json`.

Wait for all reviewers to complete.

### Phase 3: Sequential Refactoring

Read each review file from `reviews_dir`:
- `security.json`
- `project-rules.json`
- `redundancy.json`
- `code-quality.json`
- `test-quality.json`
- `performance.json`

For each finding in each review:
1. Extract finding data (file, code_snippet, score, why, suggestion)
2. Spawn refactor agent sequentially:
   ```
   Task(
     subagent_type: "quick-refactor:refactorer",
     prompt: "finding=<JSON> commit=<true|false>"
   )
   ```
3. Collect result (applied, skipped, failed)

### Cleanup

Always run cleanup, even on error:
```bash
${CLAUDE_PLUGIN_ROOT}/skills/collect-commits-and-files/scripts/cleanup.sh <temp_dir>
```

### Report Summary

Return structured summary:
```json
{
  "files_reviewed": 10,
  "reviews": {
    "security": { "total": 2, "high": 1, "medium": 1, "low": 0 },
    "project-rules": { "total": 3, "high": 0, "medium": 2, "low": 1 },
    ...
  },
  "refactorings": {
    "applied": 4,
    "skipped": 2,
    "failed": 0
  },
  "commits": ["abc1234", "def5678"]
}
```

## Error Handling

- Collection error: report and exit (no cleanup needed)
- Review error: log, continue with other reviewers, cleanup at end
- Refactor error: log as failed, continue with other findings
- Always cleanup temp_dir before exiting

## Prohibited

- Reading files directly (let reviewers do that)
- Making code changes (let refactorer do that)
- Skipping cleanup on any exit path
