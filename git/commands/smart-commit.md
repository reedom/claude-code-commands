---
description: Orchestrate smart git commits by selecting files and delegating to appropriate agent
argument-hint: [--staged|-s] [--single] [--lang <code>]
allowed-tools: Task, Bash(cat:*), Bash(git diff:*), Bash(git commit:*), Bash(git add:*), Bash(git reset:*), Bash(git status:*), Skill(reedom-git:collect-commit-info)
---

This command selects files, determines complexity, and delegates to the appropriate agent.

## Arguments

| Flag | Default | Description |
|------|---------|-------------|
| `--staged`, `-s` | false | Commit already-staged files (skip file selection) |
| `--single` | false | Force simple single-commit mode |
| `--lang` | context | Commit message language |

## Agent Selection

Two agents are available:

| Agent | Use Case |
|-------|----------|
| `simple-commit-maker` | Single commit for single-category changes |
| `commit-maker` | Multiple commits for mixed-category changes |

**Auto-detection logic:**
- Categorize files into: deps, ci, config, source, test, docs
- All files in same category → `simple-commit-maker`
- Mixed categories → `commit-maker`

**Override:**
- `--single` flag forces `simple-commit-maker` regardless of categories

## File Categories

| Category | Pattern |
|----------|---------|
| deps | package.json, *-lock.*, requirements.txt, Cargo.toml, go.mod, Gemfile |
| ci | .github/*, .gitlab-ci.yml, Jenkinsfile |
| config | *.yml, *.yaml, *.toml, .*rc, tsconfig.*, jest.config.* |
| test | *_test.*, *.test.*, *.spec.*, tests/*, __tests__/* |
| docs | *.md, *.rst, docs/* |
| source | Everything else |

## Workflow

### With `--staged` flag

Skip file selection. Categorize already-staged files:

```bash
git diff --cached --name-only
```

Then proceed to agent selection.

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

**Step 3: Categorize files**

For each selected file, assign a category based on the patterns above.

Count distinct categories.

**Step 4: Select agent and delegate**

If `--single` flag OR only one distinct category:

```
Task(
  subagent_type: "reedom-git:simple-commit-maker",
  prompt: "--lang=<lang> --files=<comma-separated-paths>"
)
```

Otherwise (multiple categories):

```
Task(
  subagent_type: "reedom-git:commit-maker",
  prompt: "--lang=<lang> --files=<comma-separated-paths>"
)
```
