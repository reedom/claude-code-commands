---
description: Post-implementation review and refactoring with specialized multi-agent architecture
argument-hint: "[--against|-a <branch>] [--files|-f <paths>] [--commit|-c] [--cleanup]"
allowed-tools: Task, TaskOutput, Read, Write, TodoWrite, Bash(cat:*), Bash(git status:*), Skill(reedom-quick-refactor:collect-commits-and-files), Skill(reedom-git:smart-commit)
---

Post-implementation review and refactoring. Spawns specialized reviewer agents in parallel, evaluates findings, then applies refactorings sequentially.

## Arguments

| Flag | Default | Description |
|------|---------|-------------|
| `--against`, `-a` | origin/main | Target branch for diff comparison |
| `--files`, `-f` | (none) | Comma-separated file paths to review |
| `--commit`, `-c` | false | Commit after each successful refactoring |
| `--cleanup` | false | Remove temp directory after completion (preserved by default) |

## Workflow

### Step 0: Create Todos

Create todo list to track progress:

```
1. [if --commit] Pre-review: commit uncommitted files
2. Phase 1: Collect files
3. Phase 2: Run parallel reviews
4. Phase 3: Evaluate findings
5. Phase 4: Process accepted findings
6. [if --cleanup] Cleanup temp directory
7. Report summary
```

### Step 1: Pre-Review (if --commit)

If `--commit` flag is set:
1. Run `git status --porcelain`
2. If non-empty output: invoke `Skill(reedom-git:smart-commit)`

### Step 2: Phase 1 - Collection

Invoke the collection skill:

```
Skill(reedom-quick-refactor:collect-commits-and-files) --against=<branch> --files=<paths>
```

Store from response:
- `temp_dir`: Base temporary directory
- `paths.files_dir`: Directory containing file lists
- `paths.reviews_dir`: Directory for review outputs
- `summary`: File count summary

### Step 3: Phase 2 - Parallel Review

1. Read JSON files from `files_dir`:
   - `source.json`: Source file list
   - `test.json`: Test file list
   - `config.json`: Config file list

2. Spawn reviewer agents (max 2 concurrent) using Task tool:

| Agent | Condition |
|-------|-----------|
| `reedom-quick-refactor:security-reviewer` | 0 < source count |
| `reedom-quick-refactor:project-rules-reviewer` | 0 < total count |
| `reedom-quick-refactor:redundancy-reviewer` | 0 < source + test count |
| `reedom-quick-refactor:code-quality-reviewer` | 0 < source count |
| `reedom-quick-refactor:test-quality-reviewer` | 0 < test count |
| `reedom-quick-refactor:performance-reviewer` | 0 < source count |

3. Spawn first batch (2 agents) with `run_in_background: true`:

```
Task(
  subagent_type: "reedom-quick-refactor:security-reviewer",
  prompt: "temp_dir=<path>",
  run_in_background: true
)
Task(
  subagent_type: "reedom-quick-refactor:project-rules-reviewer",
  prompt: "temp_dir=<path>",
  run_in_background: true
)
```

4. Wait for batch completion with `TaskOutput`, then spawn next batch of 2
5. Continue until all applicable reviewers complete

### Step 4: Phase 3 - Evaluate Findings

Spawn finding-evaluator agent:

```
Task(
  subagent_type: "reedom-quick-refactor:finding-evaluator",
  prompt: "temp_dir=<path>"
)
```

The agent:
1. Reads all review JSON files from `reviews_dir`
2. Filters findings by acceptance criteria:
   - Accept if `auto_fixable` = true (quick wins)
   - Accept if `score` >= 70 AND `severity` in [high, medium]
   - Reject otherwise
3. Writes `decisions.json` to temp directory
4. Reports summary counts

### Step 5: Phase 4 - Process Accepted Findings (MANDATORY)

Execute even if no accepted findings.

1. Read `<temp_dir>/decisions.json`
2. For each finding in `accepted` array, spawn refactorer sequentially:

```
Task(
  subagent_type: "reedom-quick-refactor:refactorer",
  prompt: "finding={...} commit=true|false"
)
```

Wait for each refactorer to complete before spawning next.

3. If no accepted findings: log "No findings to refactor"

### Step 6: Cleanup (if --cleanup)

Only if `--cleanup` flag is set, run cleanup script:

```bash
${CLAUDE_PLUGIN_ROOT}/skills/collect-commits-and-files/scripts/cleanup.sh <temp_dir>
```

If `--cleanup` is not set:
- Keep temp directory for user review
- Log temp directory path: "Review results preserved at: <temp_dir>"

### Step 7: Report Summary

Output final summary:

```json
{
  "files_reviewed": N,
  "reviews": {
    "security": {"findings": N},
    "project-rules": {"findings": N},
    ...
  },
  "evaluation": {
    "total": N,
    "accepted": N,
    "rejected": N
  },
  "refactorings": {
    "applied": N,
    "skipped": N,
    "failed": N
  },
  "temp_dir": "<path>"
}
```

Include `temp_dir` in summary so user knows where to find review results.

## Review Categories

| Agent | Focus | Triggers |
|-------|-------|----------|
| security-reviewer | Vulnerabilities, secrets, injection | Source files |
| project-rules-reviewer | CLAUDE.md, .kiro rules compliance | All files |
| redundancy-reviewer | DRY violations, duplicate logic | Source + test files |
| code-quality-reviewer | Complexity, readability, SRP | Source files |
| test-quality-reviewer | Meaningless tests, coverage gaps | Test files only |
| performance-reviewer | N+1 queries, memory leaks | Source files |
