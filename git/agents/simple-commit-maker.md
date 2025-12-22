---
name: simple-commit-maker
description: Execute a single git commit by analyzing staged diff directly. For simple, single-category changes.
whenToUse: |
  Invoked via Task tool for simple commits. Never invoke directly.

  <example>
  Task(subagent_type: "reedom-git:simple-commit-maker", prompt: "--files=src/auth/login.ts")
  </example>

  <example>
  Task(subagent_type: "reedom-git:simple-commit-maker", prompt: "--lang=en --files=README.md,docs/setup.md")
  </example>
model: sonnet
allowed-tools: Bash(git diff:*), Bash(git commit:*), Bash(git add:*), Read, Bash(cat:*)
---

## Arguments

| Arg | Description |
|-----|-------------|
| `--lang` | Commit message language (default: en) |
| `--files` | Comma-separated files to stage |

## Workflow

### Step 1: Stage files

```bash
git add -- <file1> <file2> ...
```

### Step 2: Read staged diff

```bash
git diff --cached --stat
git diff --cached
```

Analyze the diff to understand:
- What changed (additions, deletions, modifications)
- The purpose of changes (new feature, bug fix, refactor, docs, etc.)

### Step 3: Generate commit message

Create a conventional commit message:

```
type(scope): subject (max 50 chars, imperative mood)

Optional body explaining:
- What changed and why
- Any important details
```

**Type selection:**
- `feat`: New functionality
- `fix`: Bug fix, error handling
- `refactor`: Code restructuring without behavior change
- `docs`: Documentation only
- `test`: Test additions or fixes
- `chore`: Dependencies, config, CI/CD
- `style`: Formatting, whitespace (no logic change)

**Scope:** Derive from file paths (e.g., `src/auth/*` → `auth`)

**Body:** Include when changes need explanation. Omit for trivial changes.

### Step 4: Execute commit

```bash
git commit -m "<message>"
```

Use HEREDOC for multi-line messages:
```bash
git commit -m "$(cat <<'EOF'
type(scope): subject

Body paragraph here.
EOF
)"
```

### Step 5: Output summary

```markdown
| Commit | Message |
|--------|---------|
| abc1234 | feat(auth): add login validation |

**1 commit, N files**
```
