---
name: ai-optimization
description: |
  Optimize content for AI agent consumption. Use when:
  - Creating/revising prompts, commands, specs, docs for Claude execution
  - User says "optimize for AI", "make AI-friendly", "revise using ai-optimization"
  - Content needs minimal tokens with maximal signal
  - Converting human-readable docs to AI-executable instructions
allowed-tools: Read, Write, TodoWrite
---

# AI Optimization

Transform content into token-efficient, high-signal format.

<principle>
Context is finite. Goal: smallest high-signal token set maximizing outcome.
</principle>

## Process

1. Read target file
2. Apply optimization rules
3. Preserve semantic meaning
4. Output optimized version

## Structure Rules

### Format hierarchy
- XML tags: section delineation
- Markdown headers: hierarchy
- Bullets: over paragraphs
- One instruction per line

### XML + Markdown tables

```markdown
<!-- WRONG -->
<data>
| Col | Val |
|-----|-----|
| A   | B   |
</data>

<!-- CORRECT - empty lines required -->
<data>

| Col | Val |
|-----|-----|
| A   | B   |

</data>
```

## Content Rules

### Include
- Direct imperatives
- Concrete examples over abstractions
- Code examples over prose
- Templates with placeholders
- Specific over generic

### Eliminate
- Filler words
- Redundant context
- Explanatory prose
- Pronoun ambiguity
- Abstract descriptions

### Clarity standards
- Unambiguous instructions
- Explicit tool names
- Concrete example values
- No implicit references

### Diagrams & tables
Remove if:
- Illustrates obvious concepts (e.g., trivial data flows, self-evident relationships)
- Duplicates information already clear from text/code

Compress if:
- Contains redundant rows/columns
- Verbose labels replaceable with concise terms
- Structure conveys less information than inline text

### Language
- English no matter the original language unless otherwise specified through prompt
- Most token-efficient for current models
- Preserves technical terminology accuracy

## System Prompt Design

### Structure template
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

### Balance
- Simple, direct language
- Right altitude for guidance
- Avoid brittle instructions
- Enable autonomous operation

## Tool Design

### Requirements
- Self-contained
- Error robust
- Clear intended use
- Descriptive, unambiguous parameters

### Avoid
- Bloated tool sets
- Overlapping functionality
- Ambiguous parameter names

## Examples Design

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
- Summarize history periodically
- Remove low-signal exchanges
- Preserve critical decisions

### Structured notes
- Maintain persistent memory outside context
- Reference when needed
- Update incrementally

### Sub-agents
- Specialized agents for complex tasks
- Return condensed results
- Chain for multi-step workflows

## Evolution

As models improve: less prescriptive engineering needed.

Trajectory:
- Simpler prompts
- Higher-level abstractions
- Self-directed problem solving
- Adaptive context management

## Examples

<example>
Input:
```
This command helps you deploy your application to the staging environment.
It will first run the tests, and then if they pass, it will build the
application and deploy it to staging.
```

Output:
```
Deploy to staging:
1. Run tests
2. If pass: build
3. Deploy
```
</example>

<example>
Input:
```
When you need to create a new user, you should make sure to validate
the email address first, then check if the username is available,
and finally create the user account.
```

Output:
```
Create user:
- Validate email
- Check username availability
- Create account
```
</example>
