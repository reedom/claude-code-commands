---
name: finding-evaluator
description: Evaluate review findings and decide which to refactor based on score, severity, and auto-fixability
allowed-tools: Read, Write, Glob
---

Finding evaluator agent. Reads review outputs and filters findings for refactoring.

## Input

Parse from prompt:
- `temp_dir`: Path to the quick-refactor temp directory

## Workflow

### 1. Read Review Files

Read all JSON files from `<temp_dir>/reviews/`:
- `security.json`
- `project-rules.json`
- `redundancy.json`
- `code-quality.json`
- `test-quality.json`
- `performance.json`

Use Glob to find all `*.json` files in reviews directory.

### 2. Evaluate Each Finding

For each finding, apply acceptance criteria:

**Accept if ANY of:**
- `auto_fixable` is true (quick win)
- `score` >= 70 AND `severity` in ["high", "medium"]

**Reject if:**
- Does not meet any acceptance criteria

### 3. Record Decisions

For each finding, record:
- `id`: Finding ID (e.g., "SEC-001")
- `file`: Target file path
- `reason`: Why accepted or rejected

Acceptance reasons:
- "quick win: auto-fixable"
- "high confidence (score >= 70) and high severity"
- "high confidence (score >= 70) and medium severity"

Rejection reasons:
- "low confidence (score < 70)"
- "low severity"
- "low confidence and low severity"

### 4. Write Decisions

Write `<temp_dir>/decisions.json`:

```json
{
  "accepted": [
    {
      "id": "SEC-001",
      "file": "src/auth/login.ts",
      "reviewer": "security",
      "reason": "high confidence (score >= 70) and high severity",
      "finding": { ... }
    }
  ],
  "rejected": [
    {
      "id": "CQ-003",
      "file": "src/utils/format.ts",
      "reviewer": "code-quality",
      "reason": "low severity",
      "finding": { ... }
    }
  ],
  "summary": {
    "total": 15,
    "accepted": 8,
    "rejected": 7,
    "by_reviewer": {
      "security": { "accepted": 2, "rejected": 0 },
      "project-rules": { "accepted": 1, "rejected": 2 },
      "code-quality": { "accepted": 3, "rejected": 3 },
      "test-quality": { "accepted": 2, "rejected": 2 }
    }
  }
}
```

### 5. Report Summary

Output summary to conversation:

```
Finding Evaluation Complete
===========================
Total findings: 15
Accepted: 8
Rejected: 7

By reviewer:
- security: 2 accepted, 0 rejected
- project-rules: 1 accepted, 2 rejected
- code-quality: 3 accepted, 3 rejected
- test-quality: 2 accepted, 2 rejected

Decisions written to: <temp_dir>/decisions.json
```

## Acceptance Criteria Details

| Criterion | Threshold | Rationale |
|-----------|-----------|-----------|
| auto_fixable | true | Low-risk automated fixes |
| score | >= 70 | High confidence findings |
| severity | high, medium | Impactful issues only |

### Priority Order

When evaluating:
1. Check `auto_fixable` first (quick wins always accepted)
2. Then check score AND severity combination

### Edge Cases

- Missing `auto_fixable` field: treat as false
- Missing `score` field: reject with reason "missing score"
- Missing `severity` field: reject with reason "missing severity"
- Empty reviews: write empty accepted/rejected arrays

## Output Schema

The `decisions.json` file contains the full finding object in each entry, allowing the refactorer to process directly from this file.
