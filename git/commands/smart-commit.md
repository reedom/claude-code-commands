---
description: Select files from working tree and delegate to commit-maker agent
argument-hint: [--staged|-s] [--lang <code>]
allowed-tools: Task, Bash(git status:*), Skill(reedom-git:collect-commit-info), Bash(git commit:*), Bash(git add:*), Bash(git reset:*), Bash(${CLAUDE_PLUGIN_ROOT}/skills/collect-commit-info/scripts/collect-info.sh:*), Bash(${CLAUDE_PLUGIN_ROOT}/skills/collect-commit-info/scripts/cleanup.sh:*)
---

<prohibited>

NEVER use these commands:
- `git diff` (any form)
- `git log`
- `git add`
- `git commit`
- Any git command except `git status --porcelain`

NEVER stage files. Agent handles staging.
NEVER pass args other than `--lang`/`--files`.

</prohibited>

## Arguments

| Flag | Default | Description |
|------|---------|-------------|
| `--staged`, `-s` | false | Pass-through to agent (skip file selection) |
| `--lang` | system | Commit message language code |

## Execution

### If `-s` flag present

Delegate immediately. No git commands.

```
Task(subagent_type: "reedom-git:commit-maker", prompt: "--lang=<lang>")
```

### If no `-s` flag

**Step 1: Read working tree**

```bash
git status --porcelain
```

Empty output → report "Nothing to commit" → exit.

**Step 2: Select files**

From `git status --porcelain` output, select files using conversation context.

Include:
- Status `M`, `A`, `D`, `R` (modified/added/deleted/renamed)
- Untracked (`??`) in same directory as changes
- Untracked with related naming (e.g., test file for source)
- Files mentioned in conversation

Exclude:
- Unrelated directories
- Scratch/temp files

**Step 3: Delegate**

```
Task(
  subagent_type: "reedom-git:commit-maker",
  prompt: "--lang=<lang> --files=<comma-separated-paths>"
)
```

## Example

Input:
```
 M src/auth/login.ts
 M src/auth/session.ts
?? src/auth/oauth.ts
?? scratch/notes.txt
```

Decision: auth files related, scratch excluded.

Output:
```
Task(
  subagent_type: "reedom-git:commit-maker",
  prompt: "--files=src/auth/login.ts,src/auth/session.ts,src/auth/oauth.ts"
)
```
