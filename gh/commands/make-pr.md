---
description: Make a new GitHub pull request.
argument-hint: [--against|-a <branch>] [--lang <ja|en>] [--no-push|--np] [--draft|-d] [--skip-ai-review|-q]
allowed-tools: Task, Skill(reedom-gh:collect-pr-info), Bash(git push:*), Bash(gh pr create:*), Bash(gh pr edit:*), Bash(gh pr view:*), Bash(gh pr list:*)
---

Invoke `reedom-gh:pr-maker` agent with the parsed arguments IMMEDIATELY.
DO NOT explain how this works.
DO NOT analyze the plugin structure.
JUST INVOKE THE AGENT.

## Arguments

| Flag             | Short | Default | Description             |
|------------------|-------|---------|-------------------------|
| --against        | -a    | origin/main | Target branch       |
| --lang           |       | infer   | PR language (en/ja/...) |
| --no-push        | --np  | false   | Skip git push           |
| --draft          | -d    | false   | Create draft PR         |
| --skip-ai-review | -q    | false   | Add [!ai-review] prefix |

## Language Detection

When `--lang` not specified:

1. Check explicit user config (CLAUDE.md, system rules) for language preference
2. If found → use that language code
3. If not found → pass `system` (script detects from LANG env var)

## Execution

1. Parse args
2. Resolve language: explicit arg > user config > `system`
3. Translate: `--skip-ai-review` → `--prefix "[!ai-review]"`
4. Invoke agent:

```
Task(
  subagent_type: "reedom-gh:pr-maker",
  prompt: "--against=<val>, --lang=<val>, --prefix=<val>, --no-push, --draft"
)
```

5. Return PR URL
