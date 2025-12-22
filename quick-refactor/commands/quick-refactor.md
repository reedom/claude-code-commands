---
description: Post-implementation review and refactoring with specialized multi-agent architecture
argument-hint: "[--against|-a <branch>] [--files|-f <paths>] [--commit|-c]"
allowed-tools: Task, Read, Write, TodoWrite, Ls, Find, Bash(cat:*), Bash(sed:*), Bash(tr:*), Bash(git status:*), Bash(git rev-parse:*), Skill(reedom-quick-refactor:collect-commits-and-files), Skill(reedom-git:smart-commit), Bash(${CLAUDE_PLUGIN_ROOT}/skills/collect-commits-and-files/scripts/collect-info.sh:*), Bash(${CLAUDE_PLUGIN_ROOT}/skills/collect-commits-and-files/scripts/cleanup.sh:*)
---

Entry point for post-implementation review. Collects file info and delegates to `quick-refactor:quick-refactor-orchestrator` agent.

## Arguments

| Flag | Default | Description |
|------|---------|-------------|
| `--against`, `-a` | origin/main | Target branch for diff comparison |
| `--files`, `-f` | (none) | Comma-separated file paths to review |
| `--commit`, `-c` | false | Commit after each successful refactoring |

## Examples

```bash
# Review changes against origin/main
/quick-refactor

# Review against a specific branch
/quick-refactor --against feature/auth

# Review specific files only
/quick-refactor --files src/auth/login.ts,src/auth/session.ts

# Review and commit each refactoring
/quick-refactor --commit

# Combine options
/quick-refactor --against develop --commit
```

## Workflow

### 1. Parse Arguments

Extract from command args:
- `--against <branch>`: Target branch (default: `origin/main`)
- `--files <paths>`: Comma-separated paths (optional)
- `--commit` or `-c`: Enable per-refactoring commits (default: false)

### 2. Quick Validation

Run `git status --porcelain` to verify:
- Working directory is a git repo
- Target branch is valid

If validation fails, report error and exit.

### 3. Delegate to Orchestrator

Invoke orchestrator agent with all flags:

```
Task(
  subagent_type: "reedom-quick-refactor:quick-refactor-orchestrator",
  prompt: "--against=<branch> --files=<paths> --commit"
)
```

Pass only flags that were provided. Example prompts:
- No flags: `""`
- Branch only: `"--against=develop"`
- Files only: `"--files=src/auth/login.ts,src/auth/session.ts"`
- With commit: `"--against=develop --commit"`

### 4. Report Results

Orchestrator returns summary. Report to user:
- Files reviewed
- Findings by category
- Refactorings applied vs skipped
- Commits created (if `--commit` enabled)

## Review Categories

| Agent | Focus | Triggers |
|-------|-------|----------|
| security-reviewer | Vulnerabilities, secrets, injection | All source files |
| project-rules-reviewer | CLAUDE.md, .kiro rules compliance | All files |
| redundancy-reviewer | DRY violations, duplicate logic | Source + test files |
| code-quality-reviewer | Complexity, readability, SRP | Source files |
| test-quality-reviewer | Meaningless tests, coverage gaps | Test files only |
| performance-reviewer | N+1 queries, memory leaks | Source files |
