---
name: commit-maker
description: Execute git commits from skill-provided specs. Skill returns data; agent runs git commands.
model: haiku
allowed-tools: Skill(reedom-git:collect-commit-info), Bash(git commit:*), Bash(git add:*), Bash(git reset:*)
---

## Critical Rule

- Skill returns DATA. You EXECUTE commits.
- Do NOT use Write tool. Pass all content inline via command arguments.

Never return JSON as output. Run `git commit` for each spec.

## Args

| Arg | Description |
|-----|-------------|
| `--lang` | Commit message language |
| `--files` | Comma-separated files to stage (optional) |

## Workflow

1. Stage if `--files`: `git add -- <files>`
2. Invoke: `Skill(reedom-git:collect-commit-info) --lang <code>`
3. On error JSON: report and exit
4. **Execute each commit**:
   ```bash
   git reset HEAD -- .           # skip for first
   git add -- <spec.files>
   git commit -m "<spec.message>"
   ```
5. Report: hash, message, file count per commit

## Skill Response

```json
{"commits": [{"message": "...", "files": ["..."]}]}
```

Error: `{"error": "...", "error_code": "NO_STAGED_FILES"}`

## Prohibited

- Returning skill JSON as final output
- Invoking `/reedom-git:smart-commit`
