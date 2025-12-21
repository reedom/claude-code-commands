# Design: quick-refactor Plugin Multi-Agent Architecture

## Context

This plugin implements a three-phase post-implementation review and refactoring workflow using specialized agents. The design follows the proven pattern from `reedom-git` plugin (command → agent → skill with temp directory).

Key stakeholders:
- Developers who want automated code review after implementing features
- The main Claude conversation that should not be burdened with review details

## Goals / Non-Goals

**Goals:**
- Preserve main conversation context by delegating heavy work to subagents
- Run specialized reviews in parallel for efficiency
- Handle large file sets via intelligent batching
- Auto-validate review findings before applying refactoring
- Follow existing plugin patterns (git plugin architecture)

**Non-Goals:**
- Replace CI/CD linting tools
- Provide exhaustive security auditing (only surface-level review)
- Support non-git repositories
- Interactive approval for each change (automatic mode)

## Decisions

### Decision: Three-Phase Architecture

**Phase 1: Collection** (orchestrator invokes skill)
- Orchestrator agent invokes `collect-commits-and-files` skill
- Skill script collects: commit diffs against target branch, specified files, project rules
- Writes structured data to temp directory
- Returns JSON manifest with file paths to orchestrator

**Phase 2: Review** (orchestrator spawns parallel sonnet agents)
- Orchestrator batches files intelligently (by directory or size)
- Orchestrator spawns up to 6 specialized review agents (model: sonnet)
- Each agent writes its report to temp directory (unique filename)
- Review categories selected dynamically based on file types

**Phase 3: Refactoring** (orchestrator spawns sequential agents, model: inherit)
- Orchestrator reads each review report
- For each finding, spawns refactor agent with finding data (inline in prompt)
- Refactor agent reads target file (triggers project rules loading)
- Refactor agent validates finding against actual code + rules (full delegation)
- Refactor agent applies changes or skips with reason
- If `--commit` flag: refactor agent commits after each successful change

**Alternatives considered:**
- Single monolithic agent: rejected due to context limits and lack of specialization
- Per-file agents: rejected due to excessive overhead with many files
- Interactive mode: rejected per user preference for automatic operation

### Decision: Review Agent Categories

Six specialized agents, each with focused expertise:

| Agent | Focus | Triggers |
|-------|-------|----------|
| `security-reviewer` | Vulnerabilities, secrets, injection | All source files |
| `project-rules-reviewer` | CLAUDE.md, .kiro rules, conventions | All files |
| `redundancy-reviewer` | DRY violations, duplicate logic | Source and test files |
| `code-quality-reviewer` | Complexity, readability, SRP | Source files |
| `test-quality-reviewer` | Meaningless tests, coverage gaps | Test files only |
| `performance-reviewer` | N+1 queries, memory leaks, inefficiencies | Source files |

**Selection logic:** Orchestrator determines which reviewers to invoke based on file categories (source, test, config, etc.) from the collection manifest.

### Decision: Temp Directory Structure

```
/tmp/quick-refactor-XXXXXX/
├── manifest.json           # Collection output (includes project_rules paths)
├── diff/                   # Individual file diffs
│   └── <hash>.diff
├── files/                  # File paths by category
│   ├── source.txt
│   ├── test.txt
│   └── config.txt
└── reviews/                # Review agent outputs
    ├── security.json
    ├── project-rules.json
    ├── redundancy.json
    ├── code-quality.json
    ├── test-quality.json
    └── performance.json
```

### Decision: File Batching Strategy

When 10 or more files need review:
1. Group files by directory prefix
2. Limit each batch to 10 files maximum
3. Spawn review agents per batch in parallel
4. Each batch gets all applicable reviewer types

This prevents agents from being overwhelmed while maximizing parallelism.

### Decision: Report Schema

Each review agent outputs JSON:

```json
{
  "reviewer": "security-reviewer",
  "batch": 1,
  "findings": [
    {
      "id": "SEC-001",
      "file": "src/auth/login.ts",
      "line": 42,
      "code_snippet": "const query = `SELECT * FROM users WHERE id = ${req.query.id}`",
      "severity": "high|medium|low",
      "score": 85,
      "category": "injection|secrets|...",
      "description": "SQL injection vulnerability",
      "why": "User input from req.query.id is concatenated into SQL string without sanitization",
      "suggestion": "Use parameterized queries",
      "auto_fixable": true
    }
  ],
  "summary": {
    "total": 3,
    "high": 1,
    "medium": 2,
    "low": 0
  }
}
```

**Field definitions:**
- `code_snippet`: The actual code identified (refactor agent searches for this, not line number)
- `score`: Confidence score 0-100 (reviewer's certainty about the finding)
- `line`: Hint only, may drift after earlier refactors

### Decision: Validation by Refactor Agent

Refactor agent validates each finding after reading target file (full delegation):
1. Read target file (triggers automatic project rules loading)
2. Evaluate finding's "why" against actual code and project rules
3. Check if target code still exists (not changed by another refactor)
4. Skip if finding is invalid or conflicts with project rules
5. Apply partial correction if finding is partially valid

Refactor agent reports validation outcome (applied/skipped with reason).

### Decision: Commit Flag (`--commit|-c`)

Opt-in flag to commit after each refactoring. When enabled:

**Pre-review commit check:**
1. Before Phase 2 (review), orchestrator checks for uncommitted changes
2. If uncommitted files exist, invoke `/reedom-git:smart-commit` to commit them
3. This ensures review operates on clean working tree

**Per-refactoring commits:**
1. After each successful refactoring, refactor agent commits the change
2. Commit message format: `refactor(<scope>): <short-description>`
3. Example: `refactor(auth): use parameterized queries`

**Flag propagation:**
- Command passes `--commit` to orchestrator agent
- Orchestrator passes flag to refactor agent via prompt args
- Refactor agent uses `git add <file> && git commit -m "..."` after Edit

**Alternatives considered:**
- Batch commits at end: rejected for granular history preference
- Per-category commits: rejected as too coarse-grained
- Always commit (opt-out): rejected to avoid unexpected commits

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| False positives in reviews | Validation phase filters invalid findings |
| Agent context limits | Batching limits files per agent; findings are concise JSON |
| Temp directory cleanup | Explicit cleanup script; orchestrator ensures cleanup on exit |
| Model cost (sonnet agents) | Use haiku for simple collection; sonnet only for review |
| Conflicting refactors | Sequential application; each refactor re-reads current file state |

## Migration Plan

1. Implement plugin without removing `after-impl.md`
2. Users can test `/quick-refactor` alongside existing command
3. Once stable, users can delete their local `after-impl.md`
4. No breaking changes required

## Open Questions

- Should we support `--dry-run` flag to preview changes without applying?
- Should findings be exportable to JSON for CI integration?
- Should we cache project rules between runs?
