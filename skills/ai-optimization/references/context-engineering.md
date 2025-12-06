# Context Engineering for AI Agents

<principle>
Context is finite resource. Goal: smallest set of high-signal tokens maximizing desired outcome.
</principle>

## System Prompt Design

### Balance
- Simple, direct language
- Right altitude for guidance
- Avoid brittle instructions
- Enable autonomous operation

### Structure
```xml
<background_information>
  <!-- Why and what -->
</background_information>

<instructions>
  <!-- How to execute -->
</instructions>

## Tool guidance
  <!-- Tool-specific directives -->

## Output description
  <!-- Expected format -->
```

## Tool Design

### Requirements
- Self-contained
- Error robust
- Extremely clear intended use
- Descriptive, unambiguous parameters

### Avoid
- Bloated tool sets
- Overlapping functionality
- Ambiguous parameter names

## Examples and Demonstrations

### Use
- Diverse, canonical examples
- Effective behavior portrayal
- Core functionality demonstration

### Avoid
- Exhaustive edge case lists
- Redundant examples
- Over-specification

## Context Management

### Compaction
- Summarize conversation history periodically
- Remove low-signal exchanges
- Preserve critical decisions

### Structured Note-taking
- Maintain persistent memory outside context
- Reference notes when needed
- Update incrementally

### Sub-agent Architectures
- Specialized agents for complex tasks
- Return condensed results
- Chain agents for multi-step workflows

## Content Optimization

### High-signal techniques
- XML tags for section delineation
- Markdown headers for hierarchy
- Bullet lists over paragraphs
- Direct imperatives over explanations
- Code examples over prose
- Templates with placeholders

### Token efficiency
- Remove filler words
- One instruction per line
- No redundant context
- Concrete over abstract
- Specific over generic

### Clarity standards
- Unambiguous instructions
- No pronoun ambiguity
- Explicit tool names
- Concrete example values

## Evolution Insight

As models improve: less prescriptive engineering needed, more autonomous operation.

### Future trajectory
- Simpler prompts
- Higher-level abstractions
- Self-directed problem solving
- Adaptive context management
