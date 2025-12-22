---
description: Orchestrate smart git commits by selecting files and delegating to commit-maker agent
argument-hint: [--staged|-s] [--lang <code>]
allowed-tools: Task, Bash(git commit:*), Bash(git add:*), Bash(git reset:*), Bash(git status:*), Skill(reedom-git:collect-commit-info)
---

This command selects files and delegates to the commit-maker agent.

## Arguments

| Flag | Default | Description |
|------|---------|-------------|
| `--staged`, `-s` | false | Commit already-staged files (skip file selection) |
| `--lang` | context | Commit message language |

## Workflow

### With `--staged` flag

Delegate immediately:

```
Task(subagent_type: "reedom-git:commit-maker", prompt: "--lang=<lang>")
```

### Without `--staged` flag

**Step 1: Recall files from conversation memory**

List files that were created or modified by you in this conversation.

If you have memory of files → go to Step 3.

**Step 2: Fallback to git status (only if no memory)**

If you have no memory of modified files:

```bash
git status --porcelain
```

Select files based on:
- Modified/added/deleted files (`M`, `A`, `D`, `R`)
- Related untracked files (`??`) in same directory
- Exclude: IDE config (.idea/, .vscode/), temp files

**Step 3: Delegate to agent**

```
Task(
  subagent_type: "reedom-git:commit-maker",
  prompt: "--lang=<lang> --files=<comma-separated-paths>"
)
```
