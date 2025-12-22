# Tasks: Add quick-refactor Plugin

## 1. Plugin Scaffolding

- [x] 1.1 Create `quick-refactor/.claude-plugin/plugin.json` with metadata
- [x] 1.2 Create directory structure: `commands/`, `agents/`, `skills/`

## 2. Collection Skill

- [x] 2.1 Create `skills/collect-commits-and-files/scripts/collect-info.sh`
  - Parse `--against` and `--files` arguments
  - Run `git diff --name-only <branch>...HEAD` for changed files
  - Merge with explicitly specified files
  - Categorize files (source, test, config, docs)
  - Detect project rules paths (CLAUDE.md, .kiro steering) and record in manifest
  - Output JSON manifest with file paths
- [x] 2.2 Create `skills/collect-commits-and-files/scripts/cleanup.sh`
- [x] 2.3 Create `skills/collect-commits-and-files/SKILL.md`
  - Define arguments, workflow, output schema
  - Document error handling

## 3. Entry Command (with Orchestration)

- [x] 3.1 Create `commands/quick-refactor.md`
  - Parse `--against` (default: origin/main), `--files`, `--commit|-c` arguments
  - **Command handles orchestration directly** (no separate orchestrator agent)
  - Pre-review: if `--commit` and uncommitted files exist, invoke `/reedom-git:smart-commit`
  - Phase 1: Invoke collect skill, read manifest
  - Phase 2: Batch files, spawn review agents (parallel via Task tool)
  - Phase 3: Read review results, spawn refactor agents (sequential)
  - Cleanup temp directory on completion

## 4. ~~Orchestrator Agent~~ (Removed)

- [x] ~~4.1 Create `agents/orchestrator.md`~~ **Deleted**
  - **Reason:** Agent-to-agent Task tool spawning proved unreliable (hallucinations)
  - **Solution:** Merged orchestration logic into command (task 3.1)
  - **Pattern:** Follows `pr-review-toolkit:review-pr` approach

## 5. Review Agents

- [x] 5.1 Create `agents/security-reviewer.md` (model: sonnet)
  - Focus: injection, secrets, auth flaws, OWASP top 10
  - Input: temp_dir, file list
  - Output: JSON findings to `reviews/security.json`
- [x] 5.2 Create `agents/project-rules-reviewer.md` (model: sonnet)
  - Focus: CLAUDE.md compliance, .kiro rules
  - Read context from temp directory
- [x] 5.3 Create `agents/redundancy-reviewer.md` (model: sonnet)
  - Focus: DRY violations, duplicate logic, copy-paste code
- [x] 5.4 Create `agents/code-quality-reviewer.md` (model: sonnet)
  - Focus: complexity, readability, SRP violations
- [x] 5.5 Create `agents/test-quality-reviewer.md` (model: sonnet)
  - Focus: meaningless tests, missing assertions, redundant setup
- [x] 5.6 Create `agents/performance-reviewer.md` (model: sonnet)
  - Focus: N+1 queries, memory inefficiencies, blocking I/O

## 6. Refactor Agent

- [x] 6.1 Create `agents/refactorer.md` (model: inherit)
  - Input: finding JSON (includes file, code_snippet, score, why, suggestion), `--commit` flag
  - Read target file first (triggers project rules loading)
  - Search for code_snippet in file (line number is hint only)
  - If not found: skip (code already changed)
  - Validate finding's "why" against actual code and project rules
  - If valid: apply refactoring using Edit tool
  - If invalid: skip with reason
  - If `--commit`: run `git add <file> && git commit -m "refactor(<scope>): <desc>"`
  - Report: applied (+ commit hash if committed), skipped (with reason), or failed

## 7. Integration Testing

- [ ] 7.1 Test with small file set (1-3 files)
- [ ] 7.2 Test with large file set (10+ files) to verify batching
- [ ] 7.3 Test with invalid findings to verify skip logic
- [ ] 7.4 Test cleanup on error and success paths
- [ ] 7.5 Test `--commit` flag
  - Verify pre-review commit of uncommitted files
  - Verify per-refactoring commits with correct message format
  - Verify git log shows expected commit history

## 8. Documentation

- [x] 8.1 Add usage examples to command description
- [x] 8.2 Document review categories and their triggers
