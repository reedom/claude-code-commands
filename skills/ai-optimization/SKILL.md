---
name: ai-optimization
description: |
  Optimize content for AI agent consumption. Use when:
  - Creating or revising prompts, commands, specs, documentation for Claude execution
  - User says "optimize for AI", "make AI-friendly", "revise using ai-optimization"
  - Content needs minimal tokens with maximal signal
  - Converting human-readable docs to AI-executable instructions
---

# AI Optimization

Transform content into token-efficient, high-signal format for AI consumption.

## Principle

Context is finite. Goal: smallest high-signal token set maximizing outcome.

## Process

1. Read target file
2. Apply optimization rules below
3. Preserve semantic meaning
4. Output optimized version

## Optimization Rules

### Structure
- XML tags for section delineation
- Markdown headers for hierarchy
- Bullets over paragraphs
- One instruction per line

### XML + Markdown Tables

When XML tags wrap tables, add empty lines after opening tag and before closing tag:

```markdown
<!-- WRONG - table breaks -->
<data>
| Col1 | Col2 |
|------|------|
| A    | B    |
</data>

<!-- CORRECT - table renders -->
<data>

| Col1 | Col2 |
|------|------|
| A    | B    |

</data>
```

### Content
- Direct imperatives only
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

## Reference

For detailed context engineering patterns: [references/context-engineering.md](references/context-engineering.md)

## Examples

<example>
Input (human-readable):
```
This command helps you deploy your application to the staging environment.
It will first run the tests, and then if they pass, it will build the
application and deploy it to staging.
```

Output (AI-optimized):
```
Deploy to staging:
1. Run tests
2. If pass: build application
3. Deploy to staging
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
