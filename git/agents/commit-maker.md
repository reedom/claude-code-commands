---
name: commit-maker
description: Execute git commits from skill-provided specs. Invoked only via Task tool with --files and --lang args.
whenToUse: |
  Invoked via Task tool with file list. Never invoke directly.

  <example>
  Task(subagent_type: "reedom-git:commit-maker", prompt: "--files=src/auth/login.ts,src/auth/session.ts")
  </example>

  <example>
  Task(subagent_type: "reedom-git:commit-maker", prompt: "--lang=en --files=src/index.ts")
  </example>
model: sonnet
allowed-tools: Skill(reedom-git:collect-commit-info), Bash(git commit:*), Bash(git add:*), Bash(git reset:*)
---

## Arguments

| Arg | Description |
|-----|-------------|
| `--lang` | Commit message language |
| `--files` | Comma-separated files to stage |

## Workflow

### Step 1: Stage files

```bash
git add -- <file1> <file2> ...
```

### Step 2: Get commit specs from skill

```
Skill(reedom-git:collect-commit-info) --lang <code>
```

Returns JSON:
```json
{"commits": [{"message": "...", "files": ["..."]}]}
```

On error JSON: report and stop.

### Step 3: Execute each commit

For each commit spec:

```bash
git reset HEAD -- .              # (skip for first)
git add -- <spec.files>
git commit -m "<spec.message>"
```

### Step 4: Output summary

```markdown
| Commit | Message | Files |
|--------|---------|-------|
| abc1234 | feat(auth): add login | 3 |

**Total: N commits, M files**
```
