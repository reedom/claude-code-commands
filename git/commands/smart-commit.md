---
description: Create conventional commits from staged changes or intelligently select from working tree with automatic splitting
argument-hint: [--staged|-s] [--lang <code>]
allowed-tools: Read, TodoWrite, Bash(awk:*), Bash(grep:*), Bash(ls:*), Bash(sed:*), Bash(sort:*), Bash(tr:*), Bash(uniq:*), Bash(wc:*), Bash(git add:*), Bash(git commit:*), Bash(git config:*), Bash(git diff:*), Bash(git log:*), Bash(git ls-files:*), Bash(git reset:*), Bash(git restore:*), Bash(git rev-parse:*), Bash(git status:*)
---

# Git Commit Command

## Objective

Create one or more conventional commits following the Conventional Commits specification. Automatically split large or mixed changesets into logical, atomic commits.

## Operating Modes

### Staged Mode (`--staged` flag present)
- Process only currently staged files
- Preserve the original staged set
- Re-stage files by group for each commit
- Leave any remaining files staged after processing

### Language in commit title and body (`--lang` flag present)
default: en, accepts any language code (e.g., ja, de, fr, zh)

### Smart Mode (default)
- Automatically stage new and modified files from working tree
- Exclude temporary artifacts and ignored files
- Process all eligible changes

## Exclusion Patterns (Smart Mode Only)

Automatically exclude these file types:
- Files matching `.gitignore` patterns
- Cache directories (`node_modules/`, `.cache/`, `__pycache__/`)
- Lock files and temporary files (`.tmp`, `.lock`, `.DS_Store`)
- Build artifacts (`dist/`, `build/`, `target/`)

## Pre-execution Analysis

Run these commands to gather context:
```bash
git rev-parse --show-toplevel 2>/dev/null || echo "Not a git repo"
git status -sb || true
git diff --cached --shortstat || true
git diff --shortstat || true
```

## Execution Steps

### 1. Initialize Task Tracking
- Use TodoWrite to create task list with all required steps
- Mark current task as in_progress

### 2. Determine Operating Mode
- Check if `$ARGUMENTS` contains `--staged` flag
- Set mode accordingly

### 3. Collect File Candidates
Staged Mode:
```bash
git diff --name-only --cached -z
```

Smart Mode:
```bash
git status --porcelain -z
```
- Keep files with status: `M`, `A`, `AM`, `MM`, `??`
- Filter out exclusion patterns
- Stage the filtered files

### 4. Analyze Staged Changes
```bash
git diff --cached --numstat || true
```

Categorize files by:
- Dependencies: `package.json`, `.lock`, `requirements.txt`, `Cargo.toml`
- Build/CI/Config: `.github/`, `.yml`, `.yaml`, `.toml`, `.json` (config)
- Source Code: Group by module/directory
- Tests: `test`, `spec`, `__tests__/`
- Documentation: `.md`, `docs/`
- Style-only: Changes with no functional impact (check with `git diff -w`)

### 5. Commit Splitting Logic

Create multiple commits if ANY condition is met:
- ≥15 files changed
- ≥500 lines changed total
- Multiple categories present
- Multiple scopes within same category

### 6. Commit Creation Order

Process groups in this sequence:
1. Dependencies (`chore(deps):`)
2. Build/CI/Config (`build:`, `ci:`, `chore:`)
3. Source Code by module (`feat:`, `fix:`, `refactor:`)
4. Tests (`test:`)
5. Documentation (`docs:`)
6. Style-only (`style:`)

### 7. Commit Message Format

```
type(scope): imperative subject under 50 chars

Optional body explaining what and why, wrapped at 72 chars.
Use bullets if multiple changes:
- First change
- Second change

BREAKING CHANGE: Description if applicable
```

Commit Types:
- `feat`: New feature
- `fix`: Bug fix
- `refactor`: Code restructuring
- `perf`: Performance improvement
- `docs`: Documentation changes
- `style`: Code style/formatting
- `test`: Test changes
- `build`: Build system changes
- `chore`: Maintenance tasks
- `ci`: CI/CD changes

## Success Criteria

Each commit must:
- Follow Conventional Commits specification exactly
- Have a clear, imperative subject line
- Be atomic (single logical change)
- Include appropriate scope when applicable
- Have descriptive body for complex changes

## Output Report

Display:
- Mode Used: `staged` or `smart`
- Commits Created: `<hash7> type(scope): subject (+additions -deletions, N files)`
- Split Status: Whether changes were split across multiple commits
- Excluded Files: Count and patterns (Smart mode only)
- Breaking Changes: Summary if any were detected
