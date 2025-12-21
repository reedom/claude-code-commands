# Change: Add quick-refactor plugin for post-implementation review and refactoring

## Why

The existing `~/.claude/commands/after-impl.md` provides post-implementation review but runs in the main conversation context, consuming tokens and lacking structured multi-agent review capabilities. A dedicated plugin with specialized agents can:
- Preserve main conversation context by delegating to subagents
- Run parallel specialized reviews (security, project rules, redundancy, etc.)
- Handle large file sets via intelligent batching
- Automate the review-validate-refactor loop

## What Changes

- **NEW**: `quick-refactor` plugin with:
  - Command: `/quick-refactor [--against <branch>] [--files <paths>] [--commit|-c]`
    - Entry point that collects reviewee files and delegates to orchestrator agent
    - `--against`: target branch for diff comparison (default: origin/main)
    - `--files`: explicit file paths to review (comma-separated)
    - `--commit`: commit after each refactoring (opt-in)
  - Orchestrator Agent: coordinates the three-phase workflow (collect, review, refactor)
  - Skill: `collect-commits-and-files` - gathers diff/file info into temp directory
  - Review Agents (sonnet): specialized reviewers for security, project-rules, redundancy, code-quality, test-quality, performance
  - Refactor Agent (inherit model): applies validated changes per review report; commits if `--commit` flag

- **Plugin Structure**:
  ```
  quick-refactor/
  ├── .claude-plugin/
  │   └── plugin.json
  ├── commands/
  │   └── quick-refactor.md
  ├── agents/
  │   ├── orchestrator.md
  │   ├── security-reviewer.md
  │   ├── project-rules-reviewer.md
  │   ├── redundancy-reviewer.md
  │   ├── code-quality-reviewer.md
  │   ├── test-quality-reviewer.md
  │   ├── performance-reviewer.md
  │   └── refactorer.md
  └── skills/
      └── collect-commits-and-files/
          ├── SKILL.md
          └── scripts/
              ├── collect-info.sh
              └── cleanup.sh
  ```

## Impact

- Affected specs: None (new capability)
- Affected code: None (new plugin)
- Migration: Users of `after-impl.md` can switch to `/quick-refactor` for enhanced functionality
