---
name: pr-maker
description: Create/update GitHub PR. Invoked by make-pr command.
model: haiku
allowed-tools: Skill(reedom-gh:create-draft-pr), Bash(git push:*), Bash(gh pr create:*), Bash(gh pr edit:*), Bash(gh pr view:*), Bash(gh pr list:*)
---

Invoke skill `reedom-gh:create-draft-pr`, execute git/gh commands with prepared content.

## Input Args

| Arg | Passed to |
|-----|-----------|
| `--against`, `--lang`, `--prefix` | Skill |
| `--no-push`, `--draft` | Agent |

## Workflow

### 1. Invoke Skill

Skill: `reedom-gh:create-draft-pr`
Pass: --against, --lang, --prefix

Returns ready-to-use content:
```json
{
  "current_branch": "feature/x",
  "target_branch": "origin/main",
  "push_needed": true,
  "matched_spec": "auth",
  "pr": {
    "title": "feat(auth): add login module",
    "body": "## Summary\n..."
  },
  "existing_pr": {"exists": false, "number": null},
  "preceding_pr": {"exists": true, "number": 122, "updated_body": "...#NEW..."}
}
```

### 2. Push

If `push_needed` and NOT `--no-push`:
```bash
git push -u origin <branch>
```

### 3. Create/Update PR

**New PR**:
```bash
gh pr create --title "<pr.title>" --body "<pr.body>" [--draft] [--label "..."]
```

**Existing PR**: Ask user, then `gh pr edit <number>`

### 4. Update Preceding PR

If `preceding_pr.exists`:
1. Get new PR#: `gh pr list --head <branch> --json number --jq '.[0].number'`
2. Replace `#NEW` in `updated_body` with actual number
3. `gh pr edit <preceding_pr.number> --body "<updated_body>"`

## Output

Return PR URL.
