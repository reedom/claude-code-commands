# Context Engineering for AI Agents

Source: anthropic.com/engineering/effective-context-engineering-for-ai-agents

## Core Principle

Context engineering > prompt engineering. Manage the complete token configuration for optimal model behavior, not just instructions.

## Why Context Matters

**Context rot**: More tokens = reduced recall precision (gradient, not cliff)
**Attention dilution**: n^2 pairwise relationships stretch thin as context grows
**Training bias**: Models trained on shorter sequences perform better there

## Effective Context Anatomy

### System Prompts

Target the Goldilocks zone:
- Specific enough to guide behavior
- Flexible enough to avoid brittle logic

Avoid:
- Hardcoded if-else logic (breaks under variation)
- Vague high-level guidance (assumes shared context)

Structure with XML tags or Markdown headers: `<instructions>`, `## Tool guidance`

### Tools

Well-designed tools are:
- Self-contained
- Robust to error
- Clear about intended use

Failure pattern: Bloated toolsets with overlapping functionality. If humans can't identify which tool to use, neither can agents.

### Examples (Few-Shot)

Don't stuff edge cases. Curate diverse, canonical examples that portray expected behavior. Examples function as powerful visual references for LLMs.

## Context Retrieval

### Just-in-Time (Preferred)

Maintain lightweight identifiers (paths, URLs, queries), retrieve dynamically via tools.

Benefits:
- Progressive disclosure through exploration
- File sizes suggest complexity
- Naming conventions indicate purpose
- Timestamps signal relevance

### Hybrid Strategy

Combine pre-loaded essentials (CLAUDE.md) with autonomous exploration (glob, grep).

## Long-Horizon Techniques

### Compaction

Summarize conversation history approaching limits. Preserve:
- Architectural decisions
- Unresolved bugs
- Implementation details

Discard:
- Redundant tool outputs
- Verbose messages

Approach: Maximize recall first, then optimize precision.

### Structured Note-Taking

Write external persistent notes, pull back as needed. Enables multi-hour coherence without memory prompting.

### Sub-Agent Architecture

Specialized sub-agents handle focused tasks with clean context. Return condensed summaries (1,000-2,000 tokens) not exhaustive output. Achieves clear separation of concerns.

## Key Rules

1. **Context is finite** - Every token depletes attention budget. Curate ruthlessly.
2. **Start minimal** - Test with minimal prompts on best model, add clarity based on failures.
3. **Efficient tools** - Return token-efficient info, encourage efficient behaviors.
4. **Match technique to task**:
   - Compaction: extensive back-and-forth
   - Note-taking: iterative development
   - Multi-agent: parallel exploration
5. **Embrace autonomy** - Let intelligent models act intelligently with less curation.
