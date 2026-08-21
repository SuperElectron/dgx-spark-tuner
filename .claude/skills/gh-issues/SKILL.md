---
name: gh-issues
description: Required body structure for GitHub issues in this repo and the rules for closing them. Use whenever creating, editing, or closing a GitHub issue here.
---

# GitHub issues

Every issue MUST use this body structure, in this order:

```markdown
## Feature
<one short paragraph: what this delivers>

## Requirements
<bullet list: constraints, dependencies on other feature groups, integrations touched>

## Objectives
<bullet list: measurable outcomes — what is true when this closes>

## Tasklist
- [ ] task 1
- [ ] task 2
```

Rules:

- One issue per feature group.
- Close via its PR merge into staging (manual close with comment — auto-close
  only fires on default-branch merges).
- Before closing, edit the body so every completed Tasklist item is checked
  (`- [x]`). Never close an issue with unchecked boxes for work that was done.
