---
description: Orchestrate smart git commits by selecting files and delegating to commit-maker agent
argument-hint: [--staged|-s] [--lang <code>]
allowed-tools: Task, Skill(reedom-git:collect-commit-info), Bash(git commit:*), Bash(git add:*), Bash(git reset:*)
---

This command selects files from **conversation memory** and delegates to the commit-maker agent.

Do NOT run any git commands. Use only your knowledge of what was modified in this conversation.

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

**Step 1: Recall files from conversation**

From your memory of this conversation, list files that were:
- Created by you
- Modified by you
- Discussed with the user

**Step 2: Delegate to agent**

```
Task(
  subagent_type: "reedom-git:commit-maker",
  prompt: "--lang=<lang> --files=<comma-separated-paths>"
)
```

## Example

During conversation, you modified `src/auth/login.ts` and `src/auth/session.ts`.

Delegate with those files:

```
Task(
  subagent_type: "reedom-git:commit-maker",
  prompt: "--files=src/auth/login.ts,src/auth/session.ts"
)
```
