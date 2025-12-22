# quick-refactor Capability Specification

## ADDED Requirements

### Requirement: Post-Implementation Review Command

The plugin SHALL provide a `/quick-refactor` command that reviews code changes against a target branch and applies automated refactoring.

#### Scenario: Basic invocation with default branch

- **WHEN** user invokes `/quick-refactor` without arguments
- **THEN** the command collects changed files against `origin/main`
- **AND** delegates to the orchestrator agent for review and refactoring

#### Scenario: Custom target branch

- **WHEN** user invokes `/quick-refactor --against develop`
- **THEN** the command collects changed files against `develop` branch

#### Scenario: Explicit file list

- **WHEN** user invokes `/quick-refactor --files src/auth/login.ts,src/auth/session.ts`
- **THEN** the command includes only the specified files for review

#### Scenario: Commit mode enabled

- **WHEN** user invokes `/quick-refactor --commit`
- **THEN** the command passes `--commit` flag to orchestrator agent
- **AND** orchestrator enables per-refactoring commits

### Requirement: Collection Skill

The plugin SHALL provide a skill that collects file information and project context into a temporary directory.

#### Scenario: Temp directory location priority

- **WHEN** `collect-info.sh` is executed inside a git repository
- **THEN** the script creates temp directory at `<git-root>/.tmp/quick-refactor-XXXXXX`
- **AND** falls back to system temp (`/tmp` or `$TMPDIR`) if git root detection fails

#### Scenario: Gitignore protection

- **WHEN** `collect-info.sh` creates or uses `.tmp` directory
- **THEN** the script creates/verifies `.tmp/.gitignore` with content `*`
- **AND** leaves existing `.gitignore` unchanged (idempotent)

#### Scenario: Successful collection

- **WHEN** the skill is invoked with valid branch and file arguments
- **THEN** the script creates a temp directory with manifest, diffs, and project context
- **AND** returns JSON with temp_dir path and file categorization

#### Scenario: File list output format

- **WHEN** the script categorizes files by type
- **THEN** it writes JSON arrays to `files/<category>.json` (e.g., `source.json`, `test.json`)
- **AND** each JSON file contains an array of file paths

#### Scenario: No changed files

- **WHEN** the script finds no changed files against the target branch
- **THEN** it returns an error JSON with code `NO_CHANGED_FILES`

#### Scenario: Project rules detection

- **WHEN** CLAUDE.md or .kiro steering docs exist
- **THEN** the script records their paths in the manifest JSON for reference
- **AND** agents access rules automatically when reading target files

### Requirement: Parallel Specialized Review

The plugin SHALL spawn specialized review agents in parallel to analyze code from multiple perspectives.

#### Scenario: File batching for large sets

- **WHEN** 10 or more files require review
- **THEN** the orchestrator groups files by directory prefix
- **AND** limits each batch to 10 files maximum

#### Scenario: Review category selection

- **WHEN** only test files are changed
- **THEN** the orchestrator spawns only test-quality-reviewer
- **AND** skips source-only reviewers like performance-reviewer

#### Scenario: Review output format

- **WHEN** a review agent completes
- **THEN** it writes findings to `reviews/<reviewer-name>.json` in temp directory
- **AND** findings include file, line, code_snippet, severity, score, description, why, and suggestion

### Requirement: Security Review

The plugin SHALL provide security-focused code review.

#### Scenario: Injection vulnerability detection

- **WHEN** code contains unsanitized user input in SQL queries
- **THEN** security-reviewer reports a high-severity finding with fix suggestion

#### Scenario: Secrets detection

- **WHEN** code contains hardcoded API keys or credentials
- **THEN** security-reviewer reports a high-severity finding

### Requirement: Project Rules Review

The plugin SHALL verify code compliance with project-specific rules.

#### Scenario: CLAUDE.md rule violation

- **WHEN** code uses a forbidden library listed in CLAUDE.md
- **THEN** project-rules-reviewer reports a finding with the violated rule

#### Scenario: Naming convention violation

- **WHEN** code uses abbreviations against project naming rules
- **THEN** project-rules-reviewer reports a finding

### Requirement: Redundancy Review

The plugin SHALL detect DRY violations and duplicate logic.

#### Scenario: Duplicate test setup

- **WHEN** multiple test files contain identical setup code
- **THEN** redundancy-reviewer suggests extracting to shared helper

#### Scenario: Copy-paste code detection

- **WHEN** similar code blocks appear in multiple locations
- **THEN** redundancy-reviewer reports with consolidation suggestion

### Requirement: Code Quality Review

The plugin SHALL evaluate code for maintainability and readability.

#### Scenario: Single Responsibility violation

- **WHEN** a function exceeds 50 lines or handles multiple concerns
- **THEN** code-quality-reviewer suggests splitting

#### Scenario: Complex conditional

- **WHEN** nested conditionals exceed 3 levels
- **THEN** code-quality-reviewer suggests guard clauses

### Requirement: Test Quality Review

The plugin SHALL evaluate test files for meaningfulness and coverage.

#### Scenario: Meaningless test detection

- **WHEN** a test has no assertions or only checks existence
- **THEN** test-quality-reviewer suggests removal or improvement

#### Scenario: Hardcoded value assertion

- **WHEN** a test asserts against hardcoded values instead of model values
- **THEN** test-quality-reviewer reports as DRY violation

### Requirement: Performance Review

The plugin SHALL identify common performance anti-patterns.

#### Scenario: N+1 query detection

- **WHEN** code queries inside a loop
- **THEN** performance-reviewer suggests batch fetching

#### Scenario: Blocking I/O in async context

- **WHEN** synchronous I/O is used in async function
- **THEN** performance-reviewer suggests async alternative

### Requirement: Finding Validation

The refactor agent SHALL validate each finding after reading the target file.

#### Scenario: Finding validation workflow

- **WHEN** refactor agent receives a finding
- **THEN** it reads the target file first (triggers project rules loading)
- **AND** searches for the code_snippet in current file state
- **AND** evaluates the finding's "why" against actual code and rules

#### Scenario: Invalid finding skip

- **WHEN** a finding conflicts with project rules or is based on incorrect assumptions
- **THEN** the refactor agent skips the finding with reason reported

#### Scenario: Stale finding skip

- **WHEN** code_snippet is not found in target file
- **THEN** the refactor agent skips the finding (code already changed)

### Requirement: Automated Refactoring

The plugin SHALL apply validated refactoring suggestions automatically.

#### Scenario: Successful refactoring

- **WHEN** a finding is validated and auto_fixable is true
- **THEN** refactorer agent applies the change using Edit tool
- **AND** reports the applied change summary

#### Scenario: Refactoring failure handling

- **WHEN** refactoring fails due to file conflicts
- **THEN** refactorer agent reports failure without crashing

### Requirement: Commit Mode

The plugin SHALL support opt-in automatic commits when `--commit` flag is provided.

#### Scenario: Pre-review commit of uncommitted files

- **WHEN** `--commit` flag is enabled and uncommitted files exist
- **THEN** orchestrator invokes `/reedom-git:smart-commit` before starting review
- **AND** ensures working tree is clean for review phase

#### Scenario: Per-refactoring commit

- **WHEN** `--commit` flag is enabled and refactoring succeeds
- **THEN** refactorer agent stages the changed file
- **AND** commits with message format `refactor(<scope>): <description>`

#### Scenario: Commit message format

- **WHEN** a security finding in `src/auth/login.ts` is fixed
- **THEN** commit message is `refactor(auth): use parameterized queries`

#### Scenario: No commit without flag

- **WHEN** `--commit` flag is not provided
- **THEN** refactorer agent applies changes without committing
- **AND** leaves files as uncommitted modifications

### Requirement: Cleanup

The plugin SHALL clean up temporary files after completion.

#### Scenario: Normal completion cleanup

- **WHEN** all refactoring completes successfully
- **THEN** orchestrator invokes cleanup script to remove `quick-refactor-XXXXXX` subdirectory
- **AND** keeps `.tmp` directory and `.gitignore` for future runs

#### Scenario: Error path cleanup

- **WHEN** an error occurs during review or refactoring
- **THEN** orchestrator still invokes cleanup to remove `quick-refactor-XXXXXX` subdirectory before exiting
