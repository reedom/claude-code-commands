---
description: Post-implementation review and refactoring with specialized multi-agent architecture
argument-hint: "[--against|-a <branch>] [--files|-f <paths>] [--commit|-c]"
allowed-tools: Task, TaskOutput, Read, Write, TodoWrite, Bash(cat:*), Bash(git status:*), Bash(${CLAUDE_PLUGIN_ROOT}/skills/collect-commits-and-files/scripts/cleanup.sh:*), Skill(reedom-quick-refactor:collect-commits-and-files), Skill(reedom-git:smart-commit)
---

Post-implementation review and refactoring. Spawns specialized reviewer agents in parallel, then applies refactorings sequentially.

## Arguments

| Flag | Default | Description |
|------|---------|-------------|
| `--against`, `-a` | origin/main | Target branch for diff comparison |
| `--files`, `-f` | (none) | Comma-separated file paths to review |
| `--commit`, `-c` | false | Commit after each successful refactoring |

## Workflow

### Step 0: Create Todos

Create todo list to track progress:

```
1. [if --commit] Pre-review: commit uncommitted files
2. Phase 1: Collect files
3. Phase 2: Run parallel reviews
4. Phase 3: Process review results
5. Cleanup
6. Report summary
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

### Step 4: Phase 3 - Process Results (MANDATORY)

Execute even if no findings.

1. Read all JSON files from `reviews_dir`
2. For each finding, spawn refactorer sequentially:

```
Task(
  subagent_type: "reedom-quick-refactor:refactorer",
  prompt: "finding={...} commit=true|false"
)
```

Wait for each refactorer to complete before spawning next.

3. If no findings: log "No findings to refactor"

### Step 5: Cleanup

Run cleanup script:

```bash
${CLAUDE_PLUGIN_ROOT}/skills/collect-commits-and-files/scripts/cleanup.sh <temp_dir>
```

### Step 6: Report Summary

Output final summary:

```json
{
  "files_reviewed": N,
  "reviews": {
    "security": {"findings": N},
    "project-rules": {"findings": N},
    ...
  },
  "refactorings": {
    "applied": N,
    "skipped": N,
    "failed": N
  }
}
```

## Review Categories

| Agent | Focus | Triggers |
|-------|-------|----------|
| security-reviewer | Vulnerabilities, secrets, injection | Source files |
| project-rules-reviewer | CLAUDE.md, .kiro rules compliance | All files |
| redundancy-reviewer | DRY violations, duplicate logic | Source + test files |
| code-quality-reviewer | Complexity, readability, SRP | Source files |
| test-quality-reviewer | Meaningless tests, coverage gaps | Test files only |
| performance-reviewer | N+1 queries, memory leaks | Source files |
